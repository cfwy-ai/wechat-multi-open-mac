# macOS 微信双开（同时登录两个微信账号）完整方法

> 面向「读完即可独立复现」的运行手册（runbook）。
> 读者既可以是人，也可以是另一个 AI agent。
> 本文所有结论都经过在一台真实 Mac（Apple M2 Pro / arm64，SIP 开启，Gatekeeper 启用）上的逐项实测核验。

---

## 1. TL;DR / 一句话结论

双开的唯一关键，是给微信的**副本**改掉 `CFBundleIdentifier`（顶层 bundle id），再做一次 ad-hoc 深度重签——**而不是**在 Finder 里把 App 改个名。

只要 bundle id 变了（例如 `com.tencent.xinWeChat` → `com.tencent.xinWeChat2`），副本就会拿到**独立的数据目录**和**独立的设备身份**。
腾讯服务器据此把两个副本当成两台不同的设备，于是两个账号可以同时在线、互不顶下线。

改文件名、用 `open -n` 打开同一个 App，都**不改 bundle id**，所以必然失败——这正是过去几次尝试「扫码登录把另一个顶下线」的根因。

> 想直接执行：见 [`clone-wechat-dual.sh`](./clone-wechat-dual.sh)（幂等脚本，封装了第 4 章全部步骤）。
> 想理解为什么、以便跨版本举一反三：请读第 3 章「核心原理」。

---

## 2. 适用环境

本方案在 macOS 上通用，Apple Silicon（本机为 M2 Pro / arm64）与 Intel 没有任何步骤差异。

微信本体是 universal binary（同一个二进制内含 x86_64 + arm64 两个 slice），`codesign --force --deep --sign -` 会一次把两个 slice 都重签好，因此**不需要**按架构分别处理。

本机实测版本：微信 4.1.10（build 268851）。

本方案**不依赖任何特定版本号，也不依赖任何二进制偏移量**。
已证明副本二进制相对原版**没有任何功能补丁**（详见第 9 章附录）。
所以微信升级到新版本后，同样的步骤依然适用，只需在原版升级后重做一遍副本（见 6.2）。

---

## 3. 核心原理（重点，必须理解）

### 3.1 微信的设备身份是怎么来的

微信遵循「一台设备同时只能登录一个账号」的规则。

判定「是不是同一台设备」，落到本机就是两个东西：

1. **数据目录**：每个微信实例把自己的全部数据（账号、消息库、配置）放在 `~/Library/Containers/<CFBundleIdentifier>/Data/…` 下。
   目录名里的 `<CFBundleIdentifier>` 就是该实例的 bundle id。
2. **设备 ID**：微信在自己的数据目录里写一个随机生成的 16 字节 ASCII 设备 ID（路径 `Data/Documents/app_data/radium/device_uuid_0`），并把它连同登录态一起上报腾讯服务器。

关键事实：微信在**运行时**是从自己的 `Info.plist` 读取 `CFBundleIdentifier`，再据此拼出数据目录路径与上报身份。
本机抓到的运行参数可证实（原版进程携带，副本同理但路径里是 `xinWeChat2`）：

```text
--bundle-id=5A4RE8SF68.com.tencent.xinWeChat
--wechat-files-path=/Users/<you>/Library/Containers/com.tencent.xinWeChat/Data/Documents/xwechat_files
--wmpf_root_dir=/Users/<you>/Library/Containers/com.tencent.xinWeChat/Data/Documents/app_data/radium
```

### 3.2 为什么会被顶下线

如果两个微信实例的 `CFBundleIdentifier` **相同**，它们就会指向**同一个**数据目录 `~/Library/Containers/com.tencent.xinWeChat`，读到**同一个** `device_uuid_0`。
于是上报给服务器的是同一台设备 → 服务器执行「一台设备一个登录」→ 新登录把旧登录挤下线。

这就是过去失败的全部原因——两个实例共用了同一个 bundle id，因而共用了同一个数据目录与设备 ID。

### 3.3 为什么改 bundle id 就能共存

把副本的 `CFBundleIdentifier` 改成 `com.tencent.xinWeChat2` 后：

- 副本运行时读到的是新 bundle id，于是把数据路径拼成 `~/Library/Containers/com.tencent.xinWeChat2/…`，并自己创建这整棵目录树。
- 副本**首次启动**时，在新目录里**新铸一个**随机设备 ID（本机实测：原版与副本的 `device_uuid_0` 逐字节不同）。
- 不同目录 → 不同 `device_uuid_0` → 上报的是两台不同设备 → 服务器允许两个账号同时在线、互不顶下线。

一句话因果链：**不同 bundle id → 不同数据目录 → 不同设备身份 → 服务器视作两台设备 → 同时在线。**

### 3.4 一个必须澄清的机制误区（别被旧说法带偏）

一种常见但**错误**的解释是：「微信是沙盒 App，容器由 `app-sandbox` entitlement 锁定，所以换 bundle id 就换容器。」

这个说法对**副本**不成立，必须纠正：

- 原版微信确实带 App Sandbox（17 条 entitlements，含 `com.apple.security.app-sandbox`），由操作系统强制做容器隔离。
- 但 `codesign --force --deep --sign -` 这步 ad-hoc 重签会把原版**全部 entitlements 一并丢弃**（包括 `app-sandbox`）。
  本机实测：原版 entitlements 约 1.4 KB / 17 条，副本为 **0 字节**。
- 因此副本 WeChat2 **运行时其实是非沙盒的**。
  实证：副本的崩溃上报进程把数据库指向了 `~/Documents/app_data/crashinfo`（真实家目录，未被虚拟化进沙盒容器），而原版指向的是容器内路径——说明副本没有被 OS 沙盒重定向。

结论：对副本而言，**没有「OS 沙盒层」在起作用**。
真正起隔离作用的只有**应用层一层**——微信自己读 `CFBundleIdentifier`、自己选数据路径、自己铸设备身份。
`~/Library/Containers/com.tencent.xinWeChat2` 这个目录是**微信按 macOS 容器布局自建的**，并非 OS 强制的沙盒容器。

这对执行 agent 很重要：**隔离的开关只有一个，就是 `CFBundleIdentifier`。**
不要试图通过「保留 `app-sandbox` entitlement」来实现隔离——ad-hoc 签名下，`app-sandbox` + app-group `5A4RE8SF68.*` 与新 bundle id 不匹配，反而容易导致副本启动失败。这很可能正是本机这份能用的副本最终是「entitlements 全剥离」状态的原因。

### 3.5 明确点出过去失败的根因

过去「扫码登录把另一个顶下线」的失败，根因几乎都是 **bundle id 没变**：

- 只在 Finder 里把 `WeChat.app` 改名为 `WeChat2.app`——文件名变了，但 `Contents/Info.plist` 里的 `CFBundleIdentifier` 仍是 `com.tencent.xinWeChat`，共享同一目录与设备身份。
- 用 `open -n /Applications/WeChat.app` 强开第二个实例——还是同一个 bundle、同一个目录、同一个 `device_uuid_0`，服务器照样判为一台设备。

记住：**Finder 改名 ≠ 改 bundle id；`open -n` ≠ 改 bundle id。**
只有改 `Info.plist` 里的 `CFBundleIdentifier` 才有效。

---

## 4. 完整复现步骤

下面命令已参数化，可直接套用变量；也可直接跑 [`clone-wechat-dual.sh`](./clone-wechat-dual.sh)。
脚本设计为**幂等**：重复运行会先清掉旧副本壳再重建（不碰数据目录）。

```bash
# ---- 可调参数 ----
SRC_APP="/Applications/WeChat.app"        # 原版微信（保持不动）
DST_APP="/Applications/WeChat2.app"       # 要生成的副本
SECOND_ID="com.tencent.xinWeChat2"        # 副本的新 bundle id（与原版不同即可）
SECOND_NAME="WeChat2"                     # 副本的 CFBundleName（仅用于区分显示）
```

### 步骤 0：前置检查与退出副本进程（幂等前置）

```bash
# 0a. 确认 codesign 可用（一台没装开发者工具的普通 Mac 需要先装 Command Line Tools）
command -v codesign >/dev/null 2>&1 || xcode-select --install

# 0b. 若副本正在运行，先退干净，否则覆盖文件 / 重签会失败。
#     只杀副本路径下的进程，绝不动原版，以免顶掉你正在用的账号。
pkill -f "${DST_APP}/Contents/MacOS/WeChat" 2>/dev/null || true
```

为什么必要：`codesign` 是这套方法的核心工具，普通用户 Mac 上可能尚未安装。
正在运行的可执行文件无法被安全覆盖或重签，所以幂等脚本必须先确保副本已退出。

### 步骤 1：完整复制 App 包

```bash
rm -rf "${DST_APP}"                # 幂等：清掉上一次的副本壳
cp -R "${SRC_APP}" "${DST_APP}"    # 整包复制，保留全部嵌套 helper / framework 结构
```

为什么必要：双开靠的是两份**独立的 App 包**，不是同一个包开两次。
`cp -R` 保留 49 个嵌套 `Info.plist` 与全部 helper、framework、xpc 的目录结构，后面才能整包重签。

> 重要：副本的数据目录（`~/Library/Containers/com.tencent.xinWeChat2`）必须由副本**首次启动时自行新建**。
> **严禁**从原版数据目录往副本目录里拷任何内容——尤其是 `app_data/radium/device_uuid_0`。
> 一旦把原版的设备 ID 拷进副本目录，两个实例又会共享同一设备身份，双开立刻失效、重新互相顶下线。

### 步骤 2：改副本的 CFBundleIdentifier 与 CFBundleName

```bash
PLIST="${DST_APP}/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier ${SECOND_ID}" "${PLIST}"
/usr/libexec/PlistBuddy -c "Set :CFBundleName ${SECOND_NAME}" "${PLIST}"
```

为什么必要：这是整个方案里**唯一在功能上起作用**的改动。
`CFBundleIdentifier` 决定副本的数据目录路径和上报给腾讯的设备身份；不改它，做再多别的都白搭。
`CFBundleName` 改成 `WeChat2` 只是为了在系统里区分显示，非功能必需，但建议改以免混淆。

> 只改顶层 `Contents/Info.plist` 的这**一个** bundle id 即可。
> 本机实测，能正常工作的副本里 48 个嵌套 helper / framework 的 bundle id 全部与原版逐字节相同（包括两个 PlugIn 扩展仍带 `com.tencent.xinWeChat.*` 前缀）。
> **不需要、也不要**去改嵌套 bundle id——改了反而可能破坏 helper 树。

### 步骤 3：ad-hoc 整包深度重签

```bash
codesign --force --deep --sign - "${DST_APP}"
codesign --verify --deep --strict "${DST_APP}" && echo "sign OK"
```

为什么必要：改完 `Info.plist` 后，原来的 Tencent Developer-ID 签名已与内容不匹配而失效，App 无法启动。
`--sign -` 表示 ad-hoc（无证书）签名；`--deep` 让全部嵌套组件（WeChatAppEx、renderer / GPU helper、DebugHelper.xpc、各 framework）一并重新封印，否则 helper 树会因签名不一致而起不来。

代价（可接受）：ad-hoc 重签会丢掉原版的 17 条 entitlements、hardened runtime 与 app-sandbox。
副本因此以非沙盒方式运行——这**不影响启动，也不影响双开**（本机副本就是这样长期在线的）。

### 步骤 4：清除 quarantine（隔离属性）

```bash
xattr -dr com.apple.quarantine "${DST_APP}" 2>/dev/null || true
```

为什么必要：`cp -R` 出来的副本通常本就没有 quarantine 属性（quarantine 只来自下载、压缩包、AirDrop 等）。
但如果这个包被压缩、AirDrop 或从别处搬来，就可能带 quarantine，导致 Gatekeeper 弹窗拦截。
`xattr -dr` 把它递归清掉，让首次启动确定性放行。

### 步骤 5：首次启动（必要时手动放行 Gatekeeper）

```bash
open "${DST_APP}"
```

为什么必要：ad-hoc 签名的包 `spctl --assess` 会一直显示 `rejected`，但**对没有 quarantine 属性的包，双击 / `open` 启动不会被这个 rejection 拦住**。

只有在包带 quarantine 时才会弹 Gatekeeper 对话框；此时任选其一放行即可（不必三个都做）：

- 已执行步骤 4 的 `xattr -dr com.apple.quarantine`；或
- 右键点 App →「打开」，在弹窗里确认一次；或
- 系统设置 → 隐私与安全性 → 在底部点「仍要打开」。

首次启动后，副本会显示一个全新的微信扫码登录界面。
用**第二个**账号扫码登录即可，**不会**把原版那个账号顶下线。

> 前提提醒：要让副本能登录另一个账号，请确保用一个与原版当前账号**不同**的微信号扫码。
> 在干净的 Mac 上副本目录是首启新建的，通常不会有残留登录态；若早先做过实验，见第 7 章先清掉旧目录。

---

## 5. 验证是否成功

以下全是**只读**检查，不需要任何登录操作。

### 5.1 两个实例都在运行，且各自绑定不同 bundle id 与目录

```bash
# 用 ps -Ao command（或 ps auxww）避免 ps aux 默认列宽截断导致 --bundle-id 看不到
ps -Ao command | grep -- "--bundle-id" | grep -i wechat | grep -v grep
```

预期能看到两组进程，分别携带：

```text
--bundle-id=5A4RE8SF68.com.tencent.xinWeChat   ...Containers/com.tencent.xinWeChat/...
--bundle-id=5A4RE8SF68.com.tencent.xinWeChat2  ...Containers/com.tencent.xinWeChat2/...
```

两组 `--bundle-id` 与 `--wechat-files-path` 路径不同，即证明第二个实例是被 macOS 按新 bundle id 路由到了独立目录，而不是 `open -n` 开的同一个包。

### 5.2 两个数据目录已物理分离（不是软链接、各自有真实数据）

```bash
ls -ld ~/Library/Containers/com.tencent.xinWeChat ~/Library/Containers/com.tencent.xinWeChat2
du -sh ~/Library/Containers/com.tencent.xinWeChat2
find ~/Library/Containers/com.tencent.xinWeChat2 -type l   # 期望：无任何输出（没有软链接）
```

本机实测：两个目录各自装着**不同账号**的真实数据（不同 `wxid_*` 子目录），`com.tencent.xinWeChat2` 目录约 134 MB，`find -type l` 返回零条软链接，证明是独立 profile 而非共享。

### 5.3 两个设备 ID 不同（双开的「证据本身」）

```bash
xxd ~/Library/Containers/com.tencent.xinWeChat/Data/Documents/app_data/radium/device_uuid_0
xxd ~/Library/Containers/com.tencent.xinWeChat2/Data/Documents/app_data/radium/device_uuid_0
```

两个文件都是 16 字节 ASCII 设备 ID，内容应当**不同**（本机实测确为两个互不相同的随机串）。
不同 = 服务器眼里两台设备 = 双开成立。

### 5.4 确认副本的签名身份

```bash
codesign -dvvv "/Applications/WeChat2.app" 2>&1 | grep -E "Identifier|Signature|flags"
```

预期：`Identifier=com.tencent.xinWeChat2`、`Signature=adhoc`、`flags=0x2(adhoc)`。
原版对照应为 `Identifier=com.tencent.xinWeChat`、`flags=0x10000(runtime)`、Authority 为 Tencent Developer ID。

---

## 6. 常见坑与排错

### 6.1 Gatekeeper 拦截 ad-hoc 包

现象：`spctl --assess /Applications/WeChat2.app` 永远显示 `rejected`（因为 ad-hoc、未公证）。

要点：这个 `rejected` **本身不阻止双击启动**，只要包没有 quarantine 属性即可正常打开。
真正会弹窗拦截的是 quarantine 属性。
处理：执行步骤 4 的 `xattr -dr com.apple.quarantine`，或右键「打开」一次，或系统设置里「仍要打开」。
不要因为看到 `spctl rejected` 就以为方案失败。

### 6.2 微信自动更新与副本的关系（重要，注意理解）

事实核验（本机实测）：副本 `WeChat2.app` **保留了完整的 Sparkle 自动更新框架**（`Contents/Frameworks/Sparkle.framework` 约 2.8 MB，含 `Autoupdate` 可执行体与 `Updater.app`，`Info.plist` 里仍带 `SUPublicEDKey`），与原版一致。
换言之，副本**具备**自更新能力——不要假设它「不会更新」。

风险方向：副本是 ad-hoc 签名的。
一旦 Sparkle 触发更新并成功，它会用从腾讯下载来的**官方包**替换 `WeChat2.app`——而官方包的 bundle id 是 `com.tencent.xinWeChat`。
这会把副本的 bundle id **悄悄改回原版**，于是两个实例又共享同一身份，双开失效、重新互相顶下线。
（也可能因为 ad-hoc 签名 / 特权安装服务校验失败而更新中断——具体行为本机未实测，属不确定区间。）

稳妥策略（推荐组合）：

1. **可选的尽力加固**：在副本的偏好域里关掉自动检查（不改动包、不影响签名）：

   ```bash
   defaults write com.tencent.xinWeChat2 SUEnableAutomaticChecks -bool NO
   defaults write com.tencent.xinWeChat2 SUAutomaticallyUpdate   -bool NO
   ```

   注意：微信可能在程序内自行管理 Sparkle 而忽略这些键，所以这只是「尽力而为」，不保证一定拦住。

2. **真正可靠的兜底**：把「重做副本」当成常规运维。
   原版每次升级后，或一旦发现副本被改回原 bundle id / 拒绝登录，就重跑一次幂等脚本：

   ```bash
   pkill -f "/Applications/WeChat2.app/Contents/MacOS/WeChat" 2>/dev/null || true
   rm -rf /Applications/WeChat2.app
   # 然后重新执行第 4 章步骤 1~5（或直接跑 clone-wechat-dual.sh）
   ```

   `~/Library/Containers/com.tencent.xinWeChat2` 里的第二账号数据 / 会话**不随副本删除而丢失**，重建副本壳后第二个 profile 依旧在。
   所以「重做」只是把 App 壳换成新版的壳，不会清空聊天记录。

### 6.3 `--deep` 重签注意点

必须用 `--deep`，让全部嵌套 helper / framework / xpc 一并重签；只签顶层会让 helper 树签名不一致而无法拉起子进程。

不要试图用 `--entitlements` 保留原版 entitlements 来「维持沙盒」：ad-hoc 签名下，`app-sandbox` + app-group `5A4RE8SF68.com.tencent.xinWeChat` 与新 bundle id 不匹配，反而会导致启动失败。
本机能稳定工作的副本，正是 entitlements 被全部剥离的**非沙盒**版本——这是已验证可行的路径。

### 6.4 新 bundle id 会重新触发 TCC 权限申请

因为 `com.tencent.xinWeChat2` 是一个全新的 TCC 主体（bundle id 不同、cdhash 也不同），macOS 视它为陌生 App。
首次使用以下能力时会各自弹一次系统授权对话框，需要用户点「允许」：麦克风（语音消息 / 语音通话）、摄像头（视频通话）、屏幕录制、照片、本地网络、文件 / 下载、辅助功能 / 自动化。

原版微信已有的授权**不会**继承到副本。
若早先实验残留了脏的 TCC 状态，可先重置：

```bash
tccutil reset All com.tencent.xinWeChat2
```

提醒：执行 agent 应提前告知用户「会陆续弹若干权限申请，逐个点允许即可」。

附带说明：副本的 Finder「共享」扩展和「文件提供者」扩展仍沿用原版的 `com.tencent.xinWeChat.*` bundle id（未改名），在 ad-hoc、entitlements 被剥离的状态下大概率不会注册，所以副本这两个系统集成功能可能不可用——但这不影响聊天主功能与双开。

### 6.5 不要走的弯路

- 不要用 `open -n /Applications/WeChat.app` 开第二个——同一 bundle id、同一目录、同一设备身份，必被顶下线。
- 不要只在 Finder 改 App 文件名——`CFBundleIdentifier` 不会因改文件名而改变。
- 不要去改嵌套 helper 的 bundle id——本机可用副本只改了顶层一个 id。
- 不要把原版数据目录的内容（尤其 `device_uuid_0`）拷进副本目录——会让两者共享设备身份。

---

## 7. 卸载 / 回退

彻底删除副本及其数据：

```bash
# 1. 退出副本进程
pkill -f "/Applications/WeChat2.app/Contents/MacOS/WeChat" 2>/dev/null || true

# 2. 删除副本 App
rm -rf /Applications/WeChat2.app

# 3. 删除副本数据目录（注意：会清空第二账号在本机的聊天记录 / 缓存）
rm -rf ~/Library/Containers/com.tencent.xinWeChat2

# 4.（可选）清理早期实验残留的陈旧目录
rm -rf ~/Library/Containers/com.tencent.xinWeChat.dup
rm -rf ~/Library/Containers/com.tencent.xinWeChat.color

# 5.（可选）副本的崩溃数据写在非容器路径 ~/Documents/app_data/crashinfo，彻底清理时一并删
rm -rf ~/Documents/app_data/crashinfo

# 6.（可选）重置副本的 TCC 授权记录
tccutil reset All com.tencent.xinWeChat2
```

回退原则：以上操作**只动副本相关路径**，原版 `/Applications/WeChat.app` 与 `~/Library/Containers/com.tencent.xinWeChat` 完全不受影响。
若只想暂时停用副本而保留数据，删第 2 步的 App、保留第 3 步的目录即可，日后重建副本数据仍在。

---

## 8. 给执行 agent 的注意事项

**幂等性**：把第 4 章封装成脚本时，务必保留步骤 0 的 `pkill 副本` 和步骤 1 的 `rm -rf "${DST_APP}"`，使脚本可重复运行、每次都从干净的副本壳重建。
脚本只能 `pkill` **副本路径**下的进程，**绝不能** `pkill` 原版进程，否则会顶掉用户正在用的账号。

**不要做破坏性「顶下线」测试**：用户当前两个账号都在线时，不要为了「验证机制」去拿已登录账号反复扫码、试图复现顶下线——那会真实打断用户会话。
验证用第 5 章的只读检查（`ps` / `ls` / `xxd` / `codesign -dvvv`）即可。

**不要硬编码版本号或偏移量**：本方案不依赖任何二进制偏移。
已证明副本二进制与原版**没有任何功能补丁**（见第 9 章）；微信换版本时，唯一要做的仍是「改 bundle id + ad-hoc 重签」。

**bundle id 可自由取**：`SECOND_ID` 不必是 `com.tencent.xinWeChat2`，任何与原版不同、形态合法的反向域名都行；想开第三个就再换一个新 id、新副本目录、新数据目录。
关键不在于叫什么，而在于**与原版不同**。

---

## 9. 附录 · 本机实测取证

以下为本机（macOS / Apple M2 Pro / arm64，SIP 开启，Gatekeeper 启用）确切事实，作为可信度背书（个人账号标识已脱敏）：

| 项目 | 原版 WeChat.app | 副本 WeChat2.app |
|---|---|---|
| CFBundleIdentifier | `com.tencent.xinWeChat` | `com.tencent.xinWeChat2` |
| CFBundleName | `WeChat` | `WeChat2` |
| 签名类型 | Developer ID（Tencent，Team `5A4RE8SF68`），flags `0x10000` hardened runtime | ad-hoc，flags `0x2`，TeamIdentifier 未设置 |
| entitlements | 17 条（含 app-sandbox、app-group、camera/mic/location 等），约 1442 字节 | **0 条 / 0 字节**（已全部剥离，非沙盒运行） |
| spctl 评估 | accepted（Notarized Developer ID） | rejected（ad-hoc，未公证） |
| 数据目录 | `~/Library/Containers/com.tencent.xinWeChat`（含数 GB 消息库） | `~/Library/Containers/com.tencent.xinWeChat2`（约 134 MB 独立 profile） |
| 登录账号 | 账号 A（某 `wxid_…`） | 账号 B（**不同** `wxid_…`） |
| 设备 ID（`device_uuid_0`） | 16 字节随机串 | **与原版逐字节不同**的另一个 16 字节随机串（副本首启新铸） |
| Sparkle 自动更新 | 完整（2.8 MB） | **同样完整（2.8 MB，含 Autoupdate + Updater.app）** —— 见 6.2 风险 |

核验要点：

- 二者均为 universal binary（x86_64 + arm64），微信版本 4.1.10（build 268851）。
- 嵌套 bundle id：两包各 49 个 `Info.plist`，逐一比对 `CFBundleIdentifier`，**仅顶层 1 处不同**，其余 48 个嵌套 id 完全一致。
- 数据隔离：两个目录为各自独立的真实数据目录，非软链接、非共享（`find -type l` 零条软链接），分属两个不同的 `wxid`。
- 设备身份：两个目录里的 `device_uuid_0` 逐字节不同——这是「服务器视作两台设备」最直接的证据。
- 共享的 Group Container `~/Library/Group Containers/5A4RE8SF68.com.tencent.xinWeChat` 仅约 4 KB，只含骨架目录与一个元数据 plist，不承载任何账号 / 设备状态，**不会**造成两个账号串台。
- 二进制结论：副本**无任何功能补丁**，等价于「原版 ad-hoc 重签」。
  做法是把原版与副本各自剥掉签名后逐字节比较——每个架构**仅差 1 字节**，且该字节是 `__LINKEDIT` 段的 `vmsize` 字段（`0x4000` 之差，纯属「大体积 Developer-ID 签名换成小体积 ad-hoc 签名、少占一个 16 KB 页」的副产物）。
  把原版重新 ad-hoc 签名再剥离，即可逐字节复现副本，证明双开靠的是 **bundle id / 目录 / 设备身份的隔离**，而非改动微信代码。

---

*本手册由对单机现状的逆向核验得出，所有关键事实经多路独立核查交叉验证。*
*微信为腾讯的产品；本方法仅用于在自有设备上同时使用本人的两个账号，请遵守微信用户协议与当地法律。*
