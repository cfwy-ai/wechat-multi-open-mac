#!/usr/bin/env bash
#
# clone-wechat-dual.sh —— macOS 微信双开：从原版克隆一个独立 bundle id 的副本
#
# 原理（详见 GUIDE.md 第 3 章）：
#   微信运行时从自己的 Info.plist 读取 CFBundleIdentifier，据此选数据目录、铸设备身份并上报腾讯。
#   改副本的 CFBundleIdentifier -> 独立数据目录 -> 独立 device_uuid_0 -> 服务器视作两台设备 -> 两账号同时在线。
#   唯一在功能上起作用的改动就是 CFBundleIdentifier；ad-hoc 重签只是因为改了 Info.plist 必须重签才能启动。
#
# 本脚本是幂等的：重复运行会先退出并删除旧副本「壳」，再从原版重建；
# 副本的数据目录 ~/Library/Containers/<SECOND_ID> 不会被本脚本删除，第二账号的会话因此得以保留。
#
# 用法:
#   ./clone-wechat-dual.sh                       # 用默认参数
#   SECOND_ID=com.tencent.xinWeChat3 \
#   DST_APP=/Applications/WeChat3.app \
#   SECOND_NAME=WeChat3 ./clone-wechat-dual.sh   # 再开一个（第三个）
#
set -euo pipefail

# ---------------- 可调参数 ----------------
SRC_APP="${SRC_APP:-/Applications/WeChat.app}"        # 原版微信（保持不动）
DST_APP="${DST_APP:-/Applications/WeChat2.app}"       # 要生成的副本
SECOND_ID="${SECOND_ID:-com.tencent.xinWeChat2}"      # 副本的新 bundle id（必须与原版不同）
SECOND_NAME="${SECOND_NAME:-WeChat2}"                 # 副本 CFBundleName；单独改它不改程序坞显示名（微信本地化 InfoPlist.strings 会盖掉），真正改名见 GUIDE §10
DISABLE_AUTOUPDATE="${DISABLE_AUTOUPDATE:-1}"         # 1=尽力关闭副本 Sparkle 自动检查（见 GUIDE §6.2）

PLIST="${DST_APP}/Contents/Info.plist"

echo "==> 源:    ${SRC_APP}"
echo "==> 副本:  ${DST_APP}"
echo "==> 新 id: ${SECOND_ID}  (CFBundleName=${SECOND_NAME})"

# ---------------- 步骤 0：前置检查 ----------------
if [[ ! -d "${SRC_APP}" ]]; then
  echo "!! 找不到原版微信: ${SRC_APP}" >&2; exit 1
fi
SRC_ID="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "${SRC_APP}/Contents/Info.plist")"
if [[ "${SECOND_ID}" == "${SRC_ID}" ]]; then
  echo "!! SECOND_ID 不能与原版 (${SRC_ID}) 相同，否则会共享设备身份、互相顶下线。" >&2; exit 1
fi
if ! command -v codesign >/dev/null 2>&1; then
  echo "!! 未找到 codesign，正在尝试安装 Command Line Tools（按系统弹窗完成后重跑本脚本）..." >&2
  xcode-select --install || true
  exit 1
fi

# 退出可能正在运行的「副本」进程（绝不动原版）
echo "==> 退出旧副本进程（若有）..."
pkill -f "${DST_APP}/Contents/MacOS/WeChat" 2>/dev/null || true
sleep 1

# ---------------- 步骤 1：整包复制 ----------------
echo "==> 删除旧副本壳并重新复制..."
rm -rf "${DST_APP}"
cp -R "${SRC_APP}" "${DST_APP}"

# ---------------- 步骤 2：改 bundle id 与 name ----------------
echo "==> 改写 CFBundleIdentifier / CFBundleName..."
/usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier ${SECOND_ID}" "${PLIST}"
/usr/libexec/PlistBuddy -c "Set :CFBundleName ${SECOND_NAME}" "${PLIST}"

# ---------------- 步骤 3：ad-hoc 深度重签 ----------------
echo "==> ad-hoc 深度重签（--force --deep --sign -）..."
codesign --force --deep --sign - "${DST_APP}"
codesign --verify --deep --strict "${DST_APP}" && echo "    签名校验通过"

# ---------------- 步骤 4：清除 quarantine ----------------
echo "==> 清除 quarantine 属性（若有）..."
xattr -dr com.apple.quarantine "${DST_APP}" 2>/dev/null || true

# ---------------- 可选：尽力关闭副本自动更新 ----------------
if [[ "${DISABLE_AUTOUPDATE}" == "1" ]]; then
  echo "==> 尽力关闭副本 Sparkle 自动检查（不保证，微信可能程序内自管）..."
  defaults write "${SECOND_ID}" SUEnableAutomaticChecks -bool NO 2>/dev/null || true
  defaults write "${SECOND_ID}" SUAutomaticallyUpdate   -bool NO 2>/dev/null || true
fi

# ---------------- 步骤 5：启动 ----------------
echo "==> 启动副本..."
open "${DST_APP}"

cat <<EOF

完成。接下来：
  1. 副本会显示一个全新的扫码登录界面，用一个【新的、未在本机登录过的】微信号扫码登录（不会顶掉其它已登录的微信）。
  2. 首次使用麦克风 / 摄像头 / 文件等会各弹一次系统权限申请，逐个点「允许」。
  3. 若副本带 quarantine 被 Gatekeeper 拦：右键 App ->「打开」一次，或到 系统设置 > 隐私与安全性 点「仍要打开」。

验证（只读，无需登录）：
  ps -Ao command | grep -- --bundle-id | grep -i wechat | grep -v grep
  xxd ~/Library/Containers/${SRC_ID}/Data/Documents/app_data/radium/device_uuid_0
  xxd ~/Library/Containers/${SECOND_ID}/Data/Documents/app_data/radium/device_uuid_0   # 应与上面不同

注意：原版微信升级后副本可能失效（详见 GUIDE §6.2），届时重跑本脚本即可，数据目录不受影响。
EOF
