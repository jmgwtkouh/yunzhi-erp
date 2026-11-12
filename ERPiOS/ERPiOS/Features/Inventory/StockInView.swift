import SwiftUI
import UIKit
import Vision

// ============================================================
// 拍照入库（手机端）
// ------------------------------------------------------------
// 流程：拍摄到货单/箱标 → Vision OCR 识别文字 → 自动匹配商品
// 与数量 → 人工核对 → 提交服务端生成入库流水（含照片）。
// 相机不可用（如模拟器）时自动退回相册选择。
// ============================================================

// MARK: - 相机 / 相册取图

struct CameraPicker: UIViewControllerRepresentable {
    enum Source: String, Identifiable {
        case camera, library
        var id: String { rawValue }
    }

    let source: Source
    let onPick: (UIImage) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        let cameraReady = UIImagePickerController.isSourceTypeAvailable(.camera)
        picker.sourceType = (source == .camera && cameraReady) ? .camera : .photoLibrary
        picker.allowsEditing = false
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        private let parent: CameraPicker
        init(_ parent: CameraPicker) { self.parent = parent }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage { parent.onPick(image) }
            picker.dismiss(animated: true)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
        }
    }
}

// MARK: - 票面文字识别

enum StockInOCR {

    /// 离线识别图片中的文字（中英文），返回按行拼接的文本
    static func recognize(_ image: UIImage) async -> String {
        guard let cgImage = image.cgImage else { return "" }
        return await Task.detached(priority: .userInitiated) { () -> String in
            var lines: [String] = []
            let request = VNRecognizeTextRequest { request, _ in
                let observations = request.results as? [VNRecognizedTextObservation] ?? []
                lines = observations.compactMap { $0.topCandidates(1).first?.string }
            }
            request.recognitionLevel = .accurate
            request.recognitionLanguages = ["zh-Hans", "en-US"]
            request.usesLanguageCorrection = true
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            try? handler.perform([request])
            return lines.joined(separator: "\n")
        }.value
    }

    /// 在票面文字中匹配商品：优先 SKU 精确命中，其次商品名包含
    static func matchProduct(_ text: String, in products: [Product]) -> Product? {
        guard !text.isEmpty, !products.isEmpty else { return nil }
        let compact = text.uppercased().replacingOccurrences(of: " ", with: "")
        if let bySku = products.first(where: {
            compact.contains($0.sku.uppercased().replacingOccurrences(of: " ", with: ""))
        }) { return bySku }
        if let byName = products.first(where: { text.contains($0.name) }) { return byName }
        // 型号片段匹配，例如 "SM-750" 中的 750
        return products.first { product in
            guard let tail = product.sku.split(separator: "-").last, tail.count >= 2 else { return false }
            return text.uppercased().contains(tail.uppercased())
        }
    }

    /// 提取数量：优先「数量/共/合计 + 数字」，其次「数字 + 计量单位」
    static func matchQuantity(_ text: String) -> Int? {
        let patterns = [
            "(?:数量|共|合计|总计|小计|QTY|Qty|qty)\\D{0,6}(\\d{1,5})",
            "(\\d{1,5})\\s*(?:件|箱|台|套|只|个|米|支|桶|PCS|pcs|Pcs)"
        ]
        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }
            let range = NSRange(text.startIndex..., in: text)
            guard let match = regex.firstMatch(in: text, range: range),
                  let valueRange = Range(match.range(at: 1), in: text),
                  let value = Int(text[valueRange]), value > 0, value < 100_000 else { continue }
            return value
        }
        return nil
    }
}

// MARK: - 拍照入库页面

struct StockInView: View {
    @EnvironmentObject private var env: AppEnvironment
    @Environment(\.dismiss) private var dismiss

    @State private var products: [Product] = []
    @State private var photo: UIImage?
    @State private var ocrText = ""
    @State private var sku = ""
    @State private var productName = ""
    @State private var quantity = 1
    @State private var quantityText = "1"
    @State private var warehouse = "主仓"
    @State private var note = ""
    @State private var pickingSource: CameraPicker.Source?
    @State private var scanning = false
    @State private var submitting = false
    @State private var errorMessage: String?
    @State private var finished: StockMovement?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    if let movement = finished {
                        successCard(movement)
                    } else {
                        photoCard
                        if scanning || !ocrText.isEmpty { ocrCard }
                        fieldsCard
                        if let errorMessage {
                            Text(errorMessage)
                                .font(.caption)
                                .foregroundStyle(ERPTheme.danger)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(10)
                                .background(ERPTheme.danger.opacity(0.10),
                                            in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                        }
                        submitButton
                        Text("照片与识别结果会随入库流水一起保存，可在「出入库记录」中回看。")
                            .font(.caption2)
                            .foregroundStyle(ERPTheme.textTertiary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.top, 2)
                    }
                }
                .padding(.horizontal, ERPTheme.pagePadding)
                .padding(.top, 12)
                .padding(.bottom, 32)
            }
            .background(ERPTheme.background.ignoresSafeArea())
            .navigationTitle(finished == nil ? "拍照入库" : "入库完成")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(finished == nil ? "取消" : "完成") { dismiss() }
                }
            }
            .sheet(item: $pickingSource) { source in
                CameraPicker(source: source) { image in
                    handle(image, fromCamera: source == .camera)
                }
                .ignoresSafeArea()
            }
            .task { await loadProducts() }
        }
    }

    // MARK: 拍照区

    private var photoCard: some View {
        VStack(spacing: 12) {
            if let photo {
                ZStack(alignment: .topTrailing) {
                    Image(uiImage: photo)
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity)
                        .frame(height: 208)
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    Button {
                        pickingSource = .camera
                    } label: {
                        Label("重拍", systemImage: "camera.rotate")
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 11).padding(.vertical, 7)
                            .background(.ultraThinMaterial, in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .padding(10)
                }
            } else {
                Button {
                    pickingSource = .camera
                } label: {
                    VStack(spacing: 9) {
                        Image(systemName: "camera.viewfinder")
                            .font(.system(size: 36, weight: .light))
                            .foregroundStyle(ERPTheme.brand)
                        Text("拍摄到货单 / 箱标")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(ERPTheme.textPrimary)
                        Text("自动识别商品编码与数量，核对后一键入库")
                            .font(.caption)
                            .foregroundStyle(ERPTheme.textTertiary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 34)
                    .background(ERPTheme.brand.opacity(0.05),
                                in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(ERPTheme.brand.opacity(0.35),
                                          style: StrokeStyle(lineWidth: 1.4, dash: [7, 5]))
                    )
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: 10) {
                sourceButton("拍照", symbol: "camera.fill", primary: true) { pickingSource = .camera }
                sourceButton("从相册选", symbol: "photo.on.rectangle", primary: false) { pickingSource = .library }
            }
        }
        .padding(14)
        .background(ERPTheme.card, in: RoundedRectangle(cornerRadius: ERPTheme.cardRadius, style: .continuous))
    }

    private func sourceButton(_ title: String, symbol: String, primary: Bool,
                              action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: symbol).font(.caption.weight(.semibold))
                Text(title).font(.subheadline.weight(.medium))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 11)
            .background(primary ? ERPTheme.brand : ERPTheme.brand.opacity(0.10),
                        in: RoundedRectangle(cornerRadius: 11, style: .continuous))
            .foregroundStyle(primary ? Color.white : ERPTheme.brand)
        }
        .buttonStyle(.plain)
    }

    // MARK: 识别结果

    private var ocrCard: some View {
        ERPCard(padding: 14) {
            HStack(spacing: 10) {
                IconTile(symbol: scanning ? "sparkles" : "text.viewfinder",
                         tone: scanning ? .info : .success, size: 36)
                VStack(alignment: .leading, spacing: 3) {
                    Text(scanning ? "正在识别票面信息…" : "已识别票面信息")
                        .font(.subheadline.weight(.medium))
                    Text(scanning ? "本地离线识别，不会上传原图" :
                            "\(ocrLineCount) 行文字 · 已自动填入选中的商品与数量")
                        .font(.caption2)
                        .foregroundStyle(ERPTheme.textTertiary)
                }
                Spacer()
                if scanning { ProgressView() }
            }
            if !ocrText.isEmpty && !scanning {
                Text(String(ocrText.prefix(160)))
                    .font(.caption2.monospaced())
                    .foregroundStyle(ERPTheme.textTertiary)
                    .lineLimit(4)
                    .padding(.top, 9)
                HStack(spacing: 14) {
                    Button("重新识别") { if let photo { handle(photo, fromCamera: false) } }
                    Button("清空文字") { ocrText = "" }
                }
                .font(.caption.weight(.medium))
                .padding(.top, 8)
            }
        }
    }

    private var ocrLineCount: Int {
        ocrText.split(separator: "\n").count
    }

    // MARK: 入库信息

    private var fieldsCard: some View {
        ERPCard(padding: 14) {
            HStack {
                Text("入库信息").font(.subheadline.weight(.semibold))
                Spacer()
                if !products.isEmpty {
                    Menu {
                        ForEach(products) { product in
                            Button {
                                sku = product.sku
                                productName = product.name
                            } label: {
                                Text("\(product.sku) · \(product.name)")
                            }
                        }
                    } label: {
                        Label("选择商品", systemImage: "list.bullet.rectangle")
                            .font(.caption.weight(.medium))
                    }
                }
            }
            .padding(.bottom, 10)

            fieldLabel("商品编码 / SKU")
            TextField("如 SM-750", text: $sku)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
                .font(.subheadline.monospaced())
                .padding(11)
                .background(ERPTheme.background, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .onChange(of: sku) { _, newValue in
                    let code = newValue.trimmingCharacters(in: .whitespaces)
                    if let match = products.first(where: {
                        $0.sku.caseInsensitiveCompare(code) == .orderedSame
                    }) {
                        productName = match.name
                    }
                }

            if !productName.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.seal.fill").font(.caption2)
                    Text(productName).font(.caption)
                }
                .foregroundStyle(ERPTheme.success)
                .padding(.top, 6)
            }

            Divider().padding(.vertical, 12)

            HStack {
                Text("入库数量").font(.subheadline)
                Spacer()
                HStack(spacing: 12) {
                    Button {
                        quantity = max(1, quantity - 1); quantityText = "\(quantity)"
                    } label: {
                        Image(systemName: "minus.circle.fill").font(.title3)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(quantity <= 1 ? ERPTheme.textTertiary : ERPTheme.brand)

                    TextField("1", text: $quantityText)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.center)
                        .frame(width: 52)
                        .padding(.vertical, 7)
                        .background(ERPTheme.background, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .onChange(of: quantityText) { _, newValue in
                            quantity = max(1, Int(newValue.filter(\.isNumber)) ?? 1)
                        }

                    Button {
                        quantity += 1; quantityText = "\(quantity)"
                    } label: {
                        Image(systemName: "plus.circle.fill").font(.title3)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(ERPTheme.brand)
                }
            }

            Divider().padding(.vertical, 12)

            fieldLabel("仓库")
            TextField("主仓", text: $warehouse)
                .font(.subheadline)
                .padding(11)
                .background(ERPTheme.background, in: RoundedRectangle(cornerRadius: 10, style: .continuous))

            fieldLabel("备注（选填）").padding(.top, 12)
            TextField("如：供应商 / 到货批次", text: $note)
                .font(.subheadline)
                .padding(11)
                .background(ERPTheme.background, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
    }

    private func fieldLabel(_ text: String) -> some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(ERPTheme.textSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.bottom, 6)
    }

    private var submitButton: some View {
        Button {
            submit()
        } label: {
            HStack(spacing: 8) {
                if submitting { ProgressView().tint(.white) }
                Text(submitting ? "入库中…" : "确认入库")
                    .font(.subheadline.weight(.semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(ERPTheme.brand, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
            .foregroundStyle(.white)
            .shadow(color: ERPTheme.brand.opacity(0.28), radius: 12, y: 6)
        }
        .buttonStyle(.plain)
        .disabled(submitting)
        .opacity(submitting ? 0.7 : 1)
    }

    // MARK: 完成态

    private func successCard(_ movement: StockMovement) -> some View {
        VStack(spacing: 14) {
            ZStack {
                Circle().fill(ERPTheme.success.opacity(0.13)).frame(width: 76, height: 76)
                Image(systemName: "checkmark")
                    .font(.system(size: 32, weight: .semibold))
                    .foregroundStyle(ERPTheme.success)
            }
            .padding(.top, 8)

            Text("入库成功").font(.title3.weight(.semibold))

            if let photo {
                Image(uiImage: photo)
                    .resizable()
                    .scaledToFill()
                    .frame(height: 150)
                    .frame(maxWidth: .infinity)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }

            VStack(spacing: 0) {
                InfoRow(label: "入库单号", value: movement.code, monoAmount: true)
                Divider()
                InfoRow(label: "商品", value: movement.productName)
                Divider()
                InfoRow(label: "数量", value: "\(movement.quantity) \(unitFor(movement.productName))")
                Divider()
                InfoRow(label: "仓库", value: movement.warehouse)
                Divider()
                InfoRow(label: "操作人", value: movement.operatorName)
                if let photoURL = movement.photoUrl, !photoURL.isEmpty {
                    Divider()
                    InfoRow(label: "照片", value: "已随流水保存")
                }
            }
            .padding(.horizontal, 14)
            .background(ERPTheme.card, in: RoundedRectangle(cornerRadius: ERPTheme.cardRadius, style: .continuous))

            Button("完成") { dismiss() }
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .background(ERPTheme.brand, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 2)
    }

    private func unitFor(_ productName: String) -> String {
        products.first { $0.name == productName }?.unit ?? "件"
    }

    // MARK: 逻辑

    private func loadProducts() async {
        products = (try? await env.repositories.masters.products()) ?? []
    }

    private func handle(_ image: UIImage, fromCamera: Bool) {
        photo = image
        scanning = true
        errorMessage = nil
        Task {
            let text = await StockInOCR.recognize(image)
            ocrText = text
            if let product = StockInOCR.matchProduct(text, in: products) {
                sku = product.sku
                productName = product.name
            }
            if let matched = StockInOCR.matchQuantity(text) {
                quantity = matched
                quantityText = "\(matched)"
            }
            scanning = false
            if text.isEmpty {
                errorMessage = fromCamera
                    ? "未能识别到文字，请正对票面重新拍摄，或手动填写商品与数量"
                    : "未能识别到文字，可手动填写商品与数量"
            }
        }
    }

    private func submit() {
        let code = sku.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !code.isEmpty else {
            errorMessage = "请填写或选择商品编码"
            return
        }
        guard quantity > 0 else {
            errorMessage = "入库数量需大于 0"
            return
        }
        submitting = true
        errorMessage = nil
        let draft = StockInDraft(
            sku: code,
            quantity: quantity,
            warehouse: warehouse.trimmingCharacters(in: .whitespaces).isEmpty ? "主仓" : warehouse,
            note: note.trimmingCharacters(in: .whitespacesAndNewlines),
            photoJPEG: photo.flatMap { compressedJPEG($0) },
            ocrText: ocrText,
            fromCamera: photo != nil
        )
        Task {
            do {
                let movement = try await env.repositories.inventory.createInbound(draft)
                env.refresh()
                finished = movement
            } catch {
                errorMessage = error.localizedDescription
            }
            submitting = false
        }
    }

    /// 压缩到最长边 1280、质量 0.72，兼顾清晰度与上传体积
    private func compressedJPEG(_ image: UIImage) -> Data? {
        let longest = max(image.size.width, image.size.height)
        let scale = longest > 1280 ? 1280 / longest : 1
        let target = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: target)
        let resized = renderer.image { _ in image.draw(in: CGRect(origin: .zero, size: target)) }
        return resized.jpegData(compressionQuality: 0.72)
    }
}
