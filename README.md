# 微信多开 Mac

> 在 Mac 上实现微信多开，同时登录多个微信，并且不会相互顶掉。

## 解决什么

一台电脑想同时登录多个微信，例如工作微信、生活微信和其他小号。

官方微信只允许登录一个账号：扫码登录第二个，第一个就会被顶下线。

这个仓库可以让多个微信相互独立、同时在线。

**理论上可以无限制开启（只要内存够大），亲测可以同时开启 10 个以上的微信且互不顶号。**

仅限 macOS，支持 Apple 芯片和 Intel 芯片。

## 使用方法

这个仓库是写给 AI Agent 读的，你不用自己敲命令。

把仓库交给你的 Agent（Claude Code、Codex 等），告诉它：

> 读这个仓库的 `GUIDE.md`，帮我在 Mac 上装好微信多开。

接下来，Agent 会询问你想开几个微信、每个微信叫什么名字，以及是否需要更换图标。

## 自由定制

每个多开的微信都可以自由设置名称，例如「微信工作」「微信生活」「微信小号」。

图标也可以重新选择，让不同的微信在程序坞里一眼就能区分。

点击下面的图标可以查看原图。

### 基础风格

| 手绘插画 | 赛博朋克 | 炫彩渐变 |
|:---:|:---:|:---:|
| [<img src="./icons/basic/hand-drawn.png" width="220" alt="手绘插画">](./icons/basic/hand-drawn.png) | [<img src="./icons/basic/cyberpunk.png" width="220" alt="赛博朋克">](./icons/basic/cyberpunk.png) | [<img src="./icons/basic/color-gradient.png" width="220" alt="炫彩渐变">](./icons/basic/color-gradient.png) |

### IP 联名风格

| 《鬼灭之刃》 | 《咒术回战》 | 《进击的巨人》 |
|:---:|:---:|:---:|
| [<img src="./icons/ip-collaboration/demon-slayer.png" width="220" alt="鬼灭之刃">](./icons/ip-collaboration/demon-slayer.png) | [<img src="./icons/ip-collaboration/jujutsu-kaisen.png" width="220" alt="咒术回战">](./icons/ip-collaboration/jujutsu-kaisen.png) | [<img src="./icons/ip-collaboration/attack-on-titan.png" width="220" alt="进击的巨人">](./icons/ip-collaboration/attack-on-titan.png) |

| 《死神》 | 《海贼王》 | 《我独自升级》 |
|:---:|:---:|:---:|
| [<img src="./icons/ip-collaboration/bleach.png" width="220" alt="死神">](./icons/ip-collaboration/bleach.png) | [<img src="./icons/ip-collaboration/one-piece-gear-five.png" width="220" alt="海贼王">](./icons/ip-collaboration/one-piece-gear-five.png) | [<img src="./icons/ip-collaboration/solo-leveling.png" width="220" alt="我独自升级">](./icons/ip-collaboration/solo-leveling.png) |

更多图标说明见 [`icons/`](./icons/)。

## 性能说明

微信多开主要占用内存，通常不是芯片性能不够。

每个微信都是一个完整应用，开启数量越多，占用的内存就越大。

| 内存 | 使用体验 |
|---|---|
| 16 GB | 可以多开，但同时运行多个微信时可能出现卡顿。 |
| 24 GB | 双开比较顺畅，推荐起步。 |
| 32 GB 以上 | 同时运行三个以上微信更加从容。 |

如果已经出现卡顿，可以按下面的顺序处理：

1. 不用的微信及时退出，需要时再打开。
2. 关闭占用内存较多的浏览器标签、Slack、VS Code 等应用。
3. 在微信的存储空间管理中清理缓存和大文件，并关闭不需要的自动下载。
4. 尽量减少连续拖拽和缩放微信窗口。

也可以把下面这句话发给你的 Agent：

> 读这个仓库 `GUIDE.md` 的「§6.6 安全瘦身」，先帮我检查内存占用，再指导我给主微信瘦身。不要删除任何聊天数据。

## 想看细节

完整的安装原理、操作命令、名称修改、图标更换、性能优化、故障排查和卸载方法，见 [`GUIDE.md`](./GUIDE.md)。
