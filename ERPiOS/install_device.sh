#!/bin/bash
# 真机签名 + 安装 + 启动（一键）
#
# 前置条件（各做一次）：
#   1. Xcode → Settings → Accounts 登录 Apple ID（免费账号即可），在 Xcode 里把工程签名团队改成你自己的（免费个人团队即可）
#   2. iPhone 解锁并点「信任此电脑」；设置 → 隐私与安全性 → 开发者模式 打开
#   3. 首次安装后，在 iPhone 上信任开发者证书（脚本启动失败时会给出路径）
#
# 用法：
#   ./install_device.sh                  完整构建 + 安装 + 启动
#   ./install_device.sh --launch-only     仅启动（在手机上点完「信任」后用）
set -euo pipefail

DEFAULT_DEVICE="你的设备UDID（xcrun devicectl list devices 查看）"
BUNDLE="com.workbuddy.erpdemo"
DD="/tmp/erp_derived_device"
cd "$(dirname "$0")"

LAUNCH_ONLY=0
case "${1:-}" in
  --launch-only) DEVICE="$DEFAULT_DEVICE"; LAUNCH_ONLY=1 ;;
  *) DEVICE="${1:-$DEFAULT_DEVICE}" ;;
esac

if [ "$LAUNCH_ONLY" -eq 0 ]; then
  echo "1/3  构建签名设备包..."
  xcodebuild -project ERPiOS.xcodeproj \
    -scheme ERPiOS -configuration Debug \
    -sdk iphoneos -destination 'generic/platform=iOS' \
    -derivedDataPath "$DD" -allowProvisioningUpdates build > /tmp/erp_device_install.log 2>&1 || {
      echo "构建失败，日志尾部："; tail -30 /tmp/erp_device_install.log; exit 1;
    }

  APP="$DD/Build/Products/Debug-iphoneos/ERPiOS.app"
  echo "     签名包: $APP"

  echo "2/3  安装到 $DEVICE ..."
  xcrun devicectl device install app --device "$DEVICE" "$APP"
fi

echo "启动 App ..."
set +e   # 启动失败时不要因 set -e 直接退出，需要走到下面的提示分支
LAUNCH_OUT=$(xcrun devicectl device process launch --device "$DEVICE" "$BUNDLE" 2>&1)
LAUNCH_CODE=$?
set -e
echo "$LAUNCH_OUT"
if [ "$LAUNCH_CODE" -eq 0 ]; then
  echo "完成：云智 ERP 已运行在 iPhone 上。"
  exit 0
fi

if echo "$LAUNCH_OUT" | grep -qiE "Locked|not, or could not be, unlocked"; then
  cat <<'HINT'

启动被拒绝：iPhone 当前处于锁定状态（与签名/信任无关）。
请解锁手机并保持亮屏，然后执行： ./install_device.sh --launch-only
也可以直接点主屏幕的「云智 ERP」图标打开。
HINT
else
  cat <<'HINT'

启动被 iOS 拒绝：免费个人团队签名的 App 需要在 iPhone 上手动信任一次开发者证书。
请在手机上操作（任一方式）：
  A. 设置 → 通用 → VPN 与设备管理 → 「开发者 App」
     点 "Apple Development: ... (kouh jmgwt)" → 点「信任」
  B. 直接点主屏幕的「云智 ERP」图标，按「不受信任的开发者」弹窗指引前往设置
信任完成后执行： ./install_device.sh --launch-only
HINT
fi
exit 1
