# icons/ — 多开微信的可选图标

把给各个微信实例用的图标放这里，让多个微信在程序坞里一眼区分。

## 图标分类

### 基础风格

位于 [`basic/`](./basic/)：

| 图标 | 文件 |
|---|---|
| 手绘插画 | [`hand-drawn.png`](./basic/hand-drawn.png) |
| 赛博朋克 | [`cyberpunk.png`](./basic/cyberpunk.png) |
| 炫彩渐变 | [`color-gradient.png`](./basic/color-gradient.png) |

### IP 联名风格

位于 [`ip-collaboration/`](./ip-collaboration/)：

| 风格 | 文件 |
|---|---|
| 《鬼灭之刃》 | [`demon-slayer.png`](./ip-collaboration/demon-slayer.png) |
| 《咒术回战》 | [`jujutsu-kaisen.png`](./ip-collaboration/jujutsu-kaisen.png) |
| 《进击的巨人》 | [`attack-on-titan.png`](./ip-collaboration/attack-on-titan.png) |
| 《死神》 | [`bleach.png`](./ip-collaboration/bleach.png) |
| 《海贼王》五档尼卡 | [`one-piece-gear-five.png`](./ip-collaboration/one-piece-gear-five.png) |
| 《我独自升级》 | [`solo-leveling.png`](./ip-collaboration/solo-leveling.png) |

全部图标均为 1024×1024 PNG。

也可以继续添加 `.png` 或 `.icns` 文件，文件名应能直接看出图标风格或用途。

## 怎么用上

见 [`../GUIDE.md`](../GUIDE.md) 第 11 章「换图标」：替换目标副本的 `Contents/Resources/AppIcon.icns` → 重签 → 刷新图标缓存。
脚本会把 `.png` 自动转成 `.icns`。

## 给执行 Agent

装好实例后，**反过来问用户**用这里的哪张图标（或让用户新给一张），再按 GUIDE §11 应用。
不要自作主张选图标。
