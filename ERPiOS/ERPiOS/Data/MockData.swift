import Foundation

// 本地种子数据：确定性生成，保证每次冷启动演示内容一致。
// 联云后本文件仅保留为「离线演示/单测」用途。
enum Seed {

    static func customers() -> [Customer] {
        let raw: [(String, String, String, String, String, Double)] = [
            ("华为技术有限公司", "陈立", "138****2201", "深圳", "战略客户", 1_286_400),
            ("比亚迪股份有限公司", "刘敏", "139****8872", "深圳", "战略客户", 986_200),
            ("海尔智家", "王建国", "137****4410", "青岛", "重要客户", 452_800),
            ("格力电器", "赵雪", "136****9032", "珠海", "重要客户", 318_500),
            ("宁德时代", "周涛", "135****6621", "宁德", "战略客户", 1_542_000),
            ("联想集团", "孙悦", "188****1134", "北京", "普通客户", 126_700),
            ("小米科技", "吴凡", "186****7745", "北京", "重要客户", 267_300),
            ("京东世纪贸易", "郑楠", "185****3390", "北京", "普通客户", 89_600),
            ("顺丰速运", "何俊", "133****5567", "深圳", "普通客户", 74_200),
            ("美的集团", "林妍", "189****2288", "佛山", "重要客户", 391_400),
            ("三一重工", "马超", "150****9911", "长沙", "普通客户", 208_900),
            ("TCL 科技", "徐静", "151****4432", "惠州", "普通客户", 63_800)
        ]
        return raw.enumerated().map { i, r in
            Customer(id: "C\(1001 + i)", name: r.0, contact: r.1, phone: r.2,
                     city: r.3, level: r.4, receivable: r.5,
                     createdAt: "2026-0\(1 + i % 9)-\(10 + i % 18)")
        }
    }

    static func suppliers() -> [Supplier] {
        let raw: [(String, String, String, String, Int, Double)] = [
            ("宝钢股份", "李工", "021****6621", "原材料", 5, 682_000),
            ("立讯精密", "张经理", "0755****2208", "电子元件", 5, 421_300),
            ("京东方科技", "钱总", "010****5580", "显示模组", 4, 356_800),
            ("万华化学", "孙工", "0535****7712", "化工材料", 4, 198_400),
            ("富士康工业互联网", "刘主管", "0755****3301", "代工服务", 5, 512_600),
            ("紫金矿业", "陈经理", "0597****8842", "金属材料", 3, 143_200),
            ("汇川技术", "周工", "0755****9903", "伺服驱动", 5, 287_900),
            ("中航光电", "吴经理", "0379****1124", "连接器", 4, 96_500),
            ("浙江中控", "郑工", "0571****4430", "控制系统", 4, 178_300),
            ("施耐德电气", "冯总", "021****7756", "低压电气", 5, 233_700)
        ]
        return raw.enumerated().map { i, r in
            Supplier(id: "S\(2001 + i)", name: r.0, contact: r.1, phone: r.2,
                     category: r.3, rating: r.4, payable: r.5,
                     createdAt: "2026-0\(1 + i % 9)-\(5 + i % 20)")
        }
    }

    static func products() -> [Product] {
        let raw: [(String, String, String, String, Double, Double, Int, Int, String)] = [
            ("IS-200", "工业传感器 IS-200", "传感与检测", "件", 1280, 742, 1860, 500, "sensor"),
            ("SM-750", "伺服电机 SM-750", "驱动与传动", "台", 4680, 2910, 342, 120, "motor"),
            ("PLC-1200", "PLC 控制器 S7-1200", "控制系统", "台", 3250, 1980, 88, 150, "cpu"),
            ("AL-6063", "铝合金型材 6063", "原材料", "米", 86, 42, 12800, 3000, "square"),
            ("BR-6204", "精密轴承 6204", "机械零件", "套", 156, 78, 4200, 1000, "circle"),
            ("HP-32", "液压泵 HP-32", "液压气动", "台", 2860, 1640, 96, 80, "drop"),
            ("GW-4G", "工业网关 GW-4G", "通讯模块", "台", 1980, 1050, 512, 200, "network"),
            ("HMI-10", "触摸屏 HMI-10", "人机界面", "台", 2380, 1320, 274, 180, "display"),
            ("CB-3P", "断路器 CB-3P", "低压电气", "只", 320, 168, 2100, 600, "bolt"),
            ("WH-18", "线束 WH-18", "辅材", "套", 96, 38, 8600, 2000, "cable"),
            ("EN-45", "编码器 EN-45", "传感与检测", "只", 890, 510, 640, 300, "dial"),
            ("VL-25", "电磁阀 VL-25", "液压气动", "只", 460, 235, 1180, 400, "valve")
        ]
        return raw.enumerated().map { i, r in
            Product(id: "P\(3001 + i)", sku: r.0, name: r.1, category: r.2, unit: r.3,
                    price: r.4, cost: r.5, stock: r.6, safetyStock: r.7, symbol: r.8)
        }
    }

    static func salesOrders() -> [SalesOrder] {
        let names = customers().map(\.name)
        let owners = ["陈曦", "刘洋", "王倩", "赵鹏", "林晓", "周宇"]
        let statuses: [OrderStatus] = [.pending, .confirmed, .shipping, .completed,
                                       .confirmed, .shipping, .completed, .draft,
                                       .completed, .pending, .confirmed, .completed]
        let products = self.products()
        return (0..<24).map { i in
            let p1 = products[i % products.count]
            let p2 = products[(i + 5) % products.count]
            let q1 = 20 + (i * 7) % 180
            let q2 = 5 + (i * 3) % 40
            let lines = [
                OrderLine(id: "L\(i)-1", productName: p1.name, quantity: q1, unitPrice: p1.price),
                OrderLine(id: "L\(i)-2", productName: p2.name, quantity: q2, unitPrice: p2.price)
            ]
            let amount = lines.reduce(0) { $0 + $1.amount }
            return SalesOrder(
                id: "SO\(4001 + i)",
                code: String(format: "SO-2026-%04d", 1024 + i),
                customerName: names[i % names.count],
                date: "2026-11-\(String(format: "%02d", 1 + i % 7))",
                amount: amount,
                status: statuses[i % statuses.count],
                owner: owners[i % owners.count],
                items: lines,
                remark: i % 3 == 0 ? "客户要求分批交付，优先安排华东仓发货。" : "按标准交期执行"
            )
        }
    }

    static func purchaseOrders() -> [PurchaseOrder] {
        let names = suppliers().map(\.name)
        let statuses: [PurchaseStatus] = [.pending, .ordered, .receiving, .completed,
                                          .ordered, .receiving, .draft, .completed]
        let products = self.products()
        return (0..<16).map { i in
            let p = products[(i * 2) % products.count]
            let qty = 100 + (i * 37) % 900
            let lines = [OrderLine(id: "PL\(i)", productName: p.name, quantity: qty, unitPrice: p.cost)]
            return PurchaseOrder(
                id: "PO\(5001 + i)",
                code: String(format: "PO-2026-%04d", 2048 + i),
                supplierName: names[i % names.count],
                date: "2026-10-\(String(format: "%02d", 20 + i % 10))",
                eta: "2026-11-\(String(format: "%02d", 8 + i % 20))",
                amount: lines.reduce(0) { $0 + $1.amount },
                status: statuses[i % statuses.count],
                owner: ["采购一部", "采购二部", "供应链中心"][i % 3],
                items: lines
            )
        }
    }

    static func inventory() -> [InventoryItem] {
        let products = self.products()
        let warehouses = ["华东主仓", "华南分仓", "华北备件仓"]
        var out: [InventoryItem] = []
        for (i, p) in products.enumerated() {
            for (j, w) in warehouses.enumerated() where (i + j) % 3 != 1 {
                let qty = max(0, p.stock / (j + 2) - (i * 13) % 60)
                out.append(InventoryItem(
                    id: "IV\(6000 + i * 10 + j)", sku: p.sku, productName: p.name,
                    warehouse: w, quantity: qty, safetyStock: max(20, p.safetyStock / 2),
                    unit: p.unit, updatedAt: "2026-11-0\(1 + (i + j) % 7)"
                ))
            }
        }
        return out
    }

    static func movements() -> [StockMovement] {
        let products = self.products()
        let types: [MovementType] = [.inbound, .outbound, .outbound, .transfer, .inbound]
        return (0..<18).map { i in
            let p = products[(i * 3) % products.count]
            return StockMovement(
                id: "MV\(7001 + i)",
                code: String(format: "MV-2026-%04d", 3300 + i),
                productName: p.name, type: types[i % types.count],
                quantity: 20 + (i * 17) % 460,
                warehouse: ["华东主仓", "华南分仓", "华北备件仓"][i % 3],
                date: "2026-11-\(String(format: "%02d", 1 + i % 7))",
                operatorName: ["张伟", "李娜", "王强", "陈静"][i % 4]
            )
        }
    }

    static func workOrders() -> [WorkOrder] {
        let products = self.products()
        let statuses: [WorkOrderStatus] = [.producing, .producing, .scheduled, .checking,
                                           .completed, .paused, .producing, .completed]
        return (0..<12).map { i in
            let plan = 200 + (i * 80) % 1200
            let done = statuses[i % statuses.count] == .scheduled ? 0 :
                       statuses[i % statuses.count] == .completed ? plan :
                       Int(Double(plan) * (0.2 + Double(i % 7) * 0.1))
            return WorkOrder(
                id: "WO\(8001 + i)",
                code: String(format: "MO-2026-%04d", 4400 + i),
                productName: products[i % products.count].name,
                planQty: plan, doneQty: min(done, plan),
                line: ["A 线（总装）", "B 线（精密）", "C 线（包装）"][i % 3],
                startDate: "2026-10-\(String(format: "%02d", 20 + i % 10))",
                dueDate: "2026-11-\(String(format: "%02d", 10 + i % 18))",
                status: statuses[i % statuses.count]
            )
        }
    }

    static func invoices() -> [Invoice] {
        let customers = self.customers().map(\.name)
        let suppliers = self.suppliers().map(\.name)
        let statuses: [InvoiceStatus] = [.open, .partial, .settled, .overdue, .open, .settled]
        return (0..<16).map { i in
            let type: InvoiceType = i % 2 == 0 ? .receivable : .payable
            let amount = Double(38_000 + (i * 27_350) % 620_000)
            let st = statuses[i % statuses.count]
            let settled = st == .settled ? amount : st == .partial ? amount * 0.45 : st == .overdue ? 0 : 0
            return Invoice(
                id: "IN\(9001 + i)",
                code: String(format: "%@-2026-%04d", type == .receivable ? "AR" : "AP", 5500 + i),
                counterparty: type == .receivable ? customers[i % customers.count] : suppliers[i % suppliers.count],
                type: type, amount: amount, settled: settled,
                dueDate: "2026-11-\(String(format: "%02d", 8 + i % 22))",
                status: st
            )
        }
    }

    static func salesTrend() -> [ReportPoint] {
        let values: [Double] = [286, 312, 268, 358, 402, 376, 448, 492, 466, 528, 574, 612]
        let labels = ["12月", "1月", "2月", "3月", "4月", "5月", "6月", "7月", "8月", "9月", "10月", "11月"]
        return zip(labels, values).map { ReportPoint(label: $0.0, value: $0.1) }
    }

    static func purchaseTrend() -> [ReportPoint] {
        let values: [Double] = [168, 182, 155, 206, 231, 218, 264, 288, 271, 305, 332, 358]
        let labels = ["12月", "1月", "2月", "3月", "4月", "5月", "6月", "7月", "8月", "9月", "10月", "11月"]
        return zip(labels, values).map { ReportPoint(label: $0.0, value: $0.1) }
    }

    static func categoryShare() -> [CategoryShare] {
        [CategoryShare(name: "控制系统", value: 32, tone: .info),
         CategoryShare(name: "驱动与传动", value: 25, tone: .accent),
         CategoryShare(name: "传感与检测", value: 18, tone: .success),
         CategoryShare(name: "原材料", value: 14, tone: .warning),
         CategoryShare(name: "其他", value: 11, tone: .neutral)]
    }

    static func warehouseShare() -> [CategoryShare] {
        [CategoryShare(name: "华东主仓", value: 52, tone: .info),
         CategoryShare(name: "华南分仓", value: 31, tone: .accent),
         CategoryShare(name: "华北备件仓", value: 17, tone: .success)]
    }

    /// 仅用于界面显示的占位账号，不属于业务单据数据
    static func currentUser() -> AppUser {
        AppUser(id: "U001", name: "管理员", role: "系统管理员",
                department: "运营部", employeeNo: "—")
    }
}
