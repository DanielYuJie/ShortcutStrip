# HANDOFF —— 桌面快捷方式启动器（Rainmeter）交接日志

> 写给下一个 agent / 未来的自己。最后更新：2026-11-20（已按用户要求回退为**稳定常显版**；自动隐藏版备份保留）。
> 用户语言：中文。用户机器：Windows 11 26H2，屏幕 2560×1440 @150% 缩放。

## 1. 用户最初的问题

桌面图标太乱，而且**每次远程（RDP / 向日葵等）之后图标位置都会变**。
一路迭代后，用户的真实诉求：

1. 桌面图标不要再占桌面 → 用 Rainmeter 面板替代；
2. 面板要好看，参考用户自己下载的 Verticons（白图标、无背景、大间距）；
3. **分类要清楚**（用户反复强调：「还是要把分类做好啊」）；
4. **像 QQ 那样贴边自动隐藏**（默认收起、鼠标碰边缘滑出、移开自动缩回）。

## 2. 当前状态

| 项目 | 状态 |
|---|---|
| `ShortcutStrip`（分类竖条，常显） | ✅ 可用，**当前激活**（Active=1，常显位 X=1337 Y=30） |
| 自动隐藏 | ↩️ **已按用户要求回退**；备份：`Generate-ShortcutStrip.autohide.ps1.bak` / `ShortcutStrip.autohide.ini.bak` |
| `ShortcutDock`（旧卡片版） | ✅ 可用，已停用（Active=0），随时可切回 |
| `EdgeTab`（旧双皮肤手柄） | ⛔ 已停用（Active=0），代码已从生成器移除，**目录可删** |
| `Logging` | 0 |
| Rainmeter | 正在运行，v4.5.28.3936 64-bit |
| 桌面图标 | 已隐藏（`HideIcons=1`），面板就是唯一入口 |

**接手第一件事**：跑一次 `刷新面板.bat` 确认流水线还通（见 §9），再看 §7 的坑。

## 3. 环境事实（已验证，不要重新探测）

- Rainmeter 安装：`D:\Program Files\Rainmeter\Rainmeter.exe`
- 皮肤目录（SkinPath）：`D:\Users\lyj\Documents\Rainmeter\Skins\`
- 设置文件：`C:\Users\lyj\AppData\Roaming\Rainmeter\Rainmeter.ini`（**UTF-16LE + BOM**，改前必须先 `!Quit`）
- 用户桌面：`D:\Users\lyj\Desktop`（46 个 .lnk）；公共桌面：`C:\Users\Public\Desktop`（36 个 .lnk）
- 去重后 **78 个条目**
- 工作区（脚本源码 + 预览图 + 交接）：`C:\Users\lyj\Documents\deepseek-harness\default-workspace\ShortcutDock\`

### DPI / 坐标系（**最容易踩的坑**）

- Windows 缩放 150%，`AppliedDPI=144`（`HKCU\Control Panel\Desktop\WindowMetrics`）。
- **Rainmeter 的 `WindowX/WindowY` 和 `!Move` 都用「逻辑像素」**：物理 = 逻辑 × 1.5。
- 逻辑屏幕 = 1707×960（物理 2560×1440 ÷ 1.5）。
- **怎么算逻辑尺寸**：`[System.Windows.Forms.Screen]::PrimaryScreen.Bounds` 在 pwsh 里返回的是**物理** 2560×1440；`GetDpiForSystem()` 在 pwsh 里返回 96（被虚拟化，不可信）。所以生成器用 `AppliedDPI` 自己算：`logical = physical / (AppliedDPI/96)`。
- pwsh 里 `Cursor.Position` / `SetCursorPos` 的入参是**逻辑**坐标（悬停物理 2550,720 要设 1700,480）。
- `GetWindowRect`（在 pwsh 里枚举 `RainmeterMeterWindow` 拿到的）返回的也是**逻辑**坐标，可以直接和 `!Move` 的值对照。
- 皮肤窗口类名 `RainmeterMeterWindow`，标题 = ini 完整路径。
- 当前实际数值：展开位 X=1337（1337+370=1707 贴右缘）、收起位 X=1693（露 14 逻辑像素 = 21 物理）、手柄 14×160 @ Y=370（屏幕正中间）。

## 4. 目录与数据流

```
桌面 *.lnk（用户桌面 + 公共桌面，按 TargetPath 去重 → 78）
  │ Generate-ShortcutDock.ps1        ← 分类 $GroupList、改名 $Rename、卡片版皮肤
  ├─→ Skins\ShortcutDock\@Resources\Links\01..78.lnk    （快捷方式副本，编号=展示顺序）
  ├─→ Skins\ShortcutDock\ShortcutDock.ini               （卡片版，UTF-16LE）
  │ Make-BadgeIcons.ps1               ← 白圆底图标（有缓存，删 Badges 才全量重画）
  ├─→ Skins\ShortcutDock\@Resources\Badges\B01..78.png  （96×96）
  │ Generate-ShortcutStrip.ps1        ← 读卡片版 ini 拿「名字+分类」，生成竖条 + 素材
  └─→ Skins\ShortcutStrip\ShortcutStrip.ini（含自动隐藏状态机）
      Skins\ShortcutStrip\@Resources\(Links,Badges 副本, stripbg.png, line.png, handle.png, handle_hot.png)
```

一键刷新：`Skins\ShortcutDock\刷新面板.bat`（跑上面三个脚本 + `Rainmeter.exe !RefreshApp`），
开始菜单里有快捷方式「刷新快捷方式面板」。**三个脚本以工作区目录为准，再同步到 `@Resources\Scripts`**（脚本会把自己复制过去，但从 Scripts 里跑时不会自我覆盖，见 §7）。

### 分类（写死在 `Generate-ShortcutDock.ps1` 的 `$GroupList`）

| 分类 | 数量 | 列数 × 行数 |
|---|---|---|
| 游戏 | 17 | 1 × 17 |
| 开发 / AI | 20 | 2 × 10 |
| 工程 / 工具 | 13 | 1 × 13 |
| 日常 / 媒体 | 16 | 1 × 16 |
| 聊天 / 娱乐 / 系统 | 12 | 1 × 12 |

竖条显示时标题会截成 `" / "` 前的一段（开发 / AI → 开发）。

### 竖条版版式参数（`Generate-ShortcutStrip.ps1` 顶部）

`$badge=36`、`$gapX=62`、`$gapY=44`、`$margin=20`、`$headerH=28`、`$groupGap=22`、`$rowMax=18`
→ 面板 370×834。背景透明度：`FromArgb(115,12,14,19)` 的 115，改成 0 即无背景。

## 5. 自动隐藏（已回退，备份保留）

当前 `ShortcutStrip.ini` 是**稳定常显版**：`Update=1000`、`DynamicWindowSize=1`、无 `OnRefreshAction`、无任何 `Calc` 计时器 / `mHandle` / `mFrame` / `Group=Panel`，位置由 `Rainmeter.ini` 的 `WindowX=1337 Y=30` 决定。

之前那版 v3 自动隐藏（单皮肤状态机）**已实测通过**，但按用户要求回退。完整文件在：
- `Generate-ShortcutStrip.autohide.ps1.bak`
- `ShortcutStrip.autohide.ini.bak`

想切回去：把 `.bak` 重命名回 `Generate-ShortcutStrip.ps1` 再跑 `刷新面板.bat`（并把 `Rainmeter.ini` 的 `WindowX` 改回 1693 或 1337 都行，皮肤自己会 `!Move`）。那套实现长这样：

```ini
[Rainmeter]
Update=250                       ; 1 tick = 0.25s（必须有 Update，计时器才跑）
DynamicWindowSize=0
OnRefreshAction=[!SetVariable Shown 0]...[!Move 1693 30]   ; 启动即收起

[Variables] Shown=0 Hovered=0 HandleHover=0 Lock=1

[mHideTick]  Formula=((#Shown#=1) && (#Hovered#=0)) ? (mHideTick+1) : 0
             IfCondition=mHideTick>=8        → 收起：HideMeterGroup Panel / ShowMeter mHandle / !Move #ColX# #TopY# / Lock=1
[mShowTick]  Formula=((#Shown#=0) && (#HandleHover#=1) && (#Lock#=0)) ? (mShowTick+1) : 0
             IfCondition=mShowTick>=1        → 展开：ShowMeterGroup Panel / HideMeter mHandle / !Move #ExpX# #TopY#
[mUnlock]    Formula=(#Lock#=1) ? (mUnlock+1) : 0
             IfCondition=mUnlock>=3          → Lock=0（0.75 秒冷却）
```

- `[mFrame]`：满幅透明 meter（`SolidColor=0,0,0,1`，370×834），**锁死窗口尺寸**，否则收起时窗口会缩成 320×798 这种怪尺寸（实测）。
- `[mBg]`：面板背景，`SolidColor=0,0,0,1` + `MouseOverAction=[!SetVariable Hovered 1]`，让图标之间的空隙也算"在面板内"。
- `[mHandle]`：14×160 手柄，`X=0`、`Y=370`；`MouseOverAction` 换 `handle_hot.png` 并置 `HandleHover=1`，`MouseLeaveAction` 换回并置 0，`LeftMouseUpAction` 也置 1（点击兜底）。收起时它正好露在屏幕右缘。
- 每个面板 meter 都带 `Group=Panel` + over/leave 置 `Hovered`。

## 6. 已经做过、失败过的事（别重做）

1. 诊断「远程后图标乱位」：根因是「自动排列图标」开着 + 远程分辨率/DPI 与本地不一致 → 给了注册表备份脚本 + 隐藏桌面图标脚本。
2. 卡片面板 `ShortcutDock`：GDI+ 渐变圆角卡片 + 悬停胶囊，5 列分组，能用但用户嫌丑。
3. 解包 `Verticons_1.0.rmskin` 学格式（`Update=-1`、`SolidColor=0,0,0,1` 点击 hack、变量化尺寸）。
4. **把 78 个 exe 图标转纯白剪影：失败**（只有 21/78 可用，多数 exe 图标是满幅不透明方块）→ 改「白圆底 + 原色图标」。
5. 竖条版 v1 无背景 6×13 网格 → 用户「还是要把分类做好啊」→ v2 分类区块。
6. 自动隐藏 v1（单皮肤计时器 + 手柄 + `!Move` 移出屏幕）→ 收起能work，展开不可靠。
7. 自动隐藏 v2（双皮肤 EdgeTab + 停用/激活）→ 竞态，两个皮肤都 Active=0，最终停在 1337。
8. **自动隐藏 v3（本次）**：单皮肤 + `!Move` 在两个位置切换 + 手柄在皮肤内 + 三个 Calc 计时器 + Lock 冷却 → 全部实测通过。

## 7. 坑与排查记录（**接手必读**）

已验证的 Rainmeter 事实：

1. `Update=-1` 时鼠标动作可用，但 **Calc/Time 计时器不会跑** → 自动隐藏必须有 `Update`。
2. `IfCondition` 里**必须引用 measure 自己的名字**（`IfCondition=mHideTick>=8`），写成 `Measure` 会报 `"Measure" is unknown`。
3. `Formula` 里引用 `#变量#` 必须 `DynamicVariables=1`，否则变量变了不重算。
4. 对**已激活**的 config 执行 `!ActivateConfig` 不会重跑 `OnRefreshAction`，要 `!DeactivateConfig` 再 `!ActivateConfig`。
5. `DynamicWindowSize=0` 并不能真的锁尺寸（隐藏 meter 后窗口会缩，实测 370×834 → 320×798）→ 用满幅透明 `[mFrame]` 锁。
6. 「全屏背景 meter 在图标下面时收不到 enter/leave」**只对"被别的 meter 盖住的地方"成立**：空隙、边距、底部空白处 mBg 能吃事件（6 个采样点里 5 个正常、1 个偶发丢失），所以每个 meter 都要自带 over/leave，别指望一块全屏底就够。
7. 窗口只露边缘 14px 时，`SetCursorPos` 模拟悬停**偶发丢 enter**（6 次里 1 次）→ 真人连续移动不受影响；测试时同一坐标多试几次。
8. `!Move` 可靠，CLI `Rainmeter.exe !Move 1337 30` 立即生效；被 `!Move` 过的位置在 Rainmeter 退出时会写回 `Rainmeter.ini`，所以靠 `OnRefreshAction` 兜底。
9. **收起→立即展开的死循环不会发生**：展开位 1337..1707 完全覆盖收起时露出的 1693..1707，鼠标停在那里属于"在面板内"，不会触发收起；另外 `mUnlock` 还有 0.75 秒冷却。
10. **`.bat` 必须 CRLF**：`刷新面板.bat` 原来是 LF，cmd 直接报 `'��数据...' is not recognized`（每行被劈开）。已重写为 UTF-8(无BOM)+CRLF，末尾 `pause` 只在双击（无参数）时触发。
11. **脚本自我复制**：`Copy-Item $PSCommandPath → 同目录同名` 在从 `@Resources\Scripts` 里跑时会报 `Cannot overwrite the item with itself`，整个 bat 断在第 1 步。三个脚本都已加"源和目标是同一路径就跳过"的判断。
12. 排版 bug：`$maxRows` 曾用 `Min(rowMax, 条目数)`，把 20 个的「开发」当成 18 行 → 面板白多 44px 高；已改为各分组 `PerCol` 的最大值。
13. 测试时开 `Logging=1` 看 `%APPDATA%\Rainmeter\Rainmeter.log`（NOTE 级也会记）。验收完成后记得改回 0 并重启。
14. 改 `.ini` 前先 `!Quit`，否则 Rainmeter 退出时会用内存状态覆盖你的改动。

## 8. 建议的下一步

1. 桌面图标已隐藏（`HKCU\...\Explorer\Advanced\HideIcons=1`）；要恢复就右键桌面 → 查看 → 勾「显示桌面图标」，或再跑一次 `隐藏或显示桌面图标.ps1`。
2. 删掉 `Skins\EdgeTab\`（v2 遗留，已停用、生成器也不再生成）。
3. 可选：给展开/收起加滑出动画（现在 `!Move` 是瞬移；Rainmeter 没有内置补间，只能靠连续 bang 或 Lua 硬做，性价比低）。
4. 可选：面板里加「固定展开」开关（现在想常显得手改 ini，见 README）。
5. 图标悬停的放大效果目前只放大 6px 并上移 3px，用户没提意见，别乱动。

## 9. 常用操作/命令

```powershell
# 重启 Rainmeter（改 ini 前先退出，否则会被覆盖）
Start-Process 'D:\Program Files\Rainmeter\Rainmeter.exe' -ArgumentList '!Quit'
Start-Sleep -Milliseconds 2000
Start-Process 'D:\Program Files\Rainmeter\Rainmeter.exe'

# 全流程重生成（推荐：直接跑 bat，它自己会做 !RefreshApp；带参数 nopause 可免 pause）
& 'D:\Users\lyj\Documents\Rainmeter\Skins\ShortcutDock\刷新面板.bat'

# 只重生成竖条
powershell -NoProfile -ExecutionPolicy Bypass -File "C:\Users\lyj\Documents\deepseek-harness\default-workspace\ShortcutDock\Generate-ShortcutStrip.ps1"

# 查询皮肤窗口 rect（逻辑坐标）
# EnumWindows + 类名 'RainmeterMeterWindow' + GetWindowRect，标题以 ShortcutStrip.ini 结尾

# 模拟鼠标（逻辑坐标 = 物理 / 1.5）
[System.Windows.Forms.Cursor]::Position = New-Object System.Drawing.Point 1700, 480   # 物理 2550,720
```

验收脚本（逻辑坐标）：
```
鼠标 (1700,480) 2s → 窗口 X 应为 1337（展开）
鼠标 (1500,400) 4s → 仍 1337（面板内停留不关）
鼠标 (1000,700) 3s → 变 1693（收回）
```

## 10. 文件清单

工作区 `C:\Users\lyj\Documents\deepseek-harness\default-workspace\ShortcutDock\`：

| 文件 | 说明 |
|---|---|
| `Generate-ShortcutDock.ps1` | 主生成器：扫桌面、分类、改名、生成 Links + 卡片版 ini |
| `Make-BadgeIcons.ps1` | 提取 256px 图标 → 白圆底徽章（带缓存） |
| `Generate-ShortcutStrip.ps1` | 生成竖条皮肤 + 自动隐藏状态机 + stripbg/handle 素材 |
| `刷新面板.bat` | 与皮肤目录里那份同步的副本 |
| `README.md` | 面向用户的说明（已含自动隐藏章节） |
| `HANDOFF.md` | 本文件 |
| `preview-strip.png` | 展开态实拍（370×834 全幅） |
| `preview-hidden.png` | 收起态实拍（右缘蓝手柄） |
| `preview-panel.png` | 旧卡片版效果图（历史） |
| `badges-sheet.png` | 78 个徽章拼图预览 |
| `ShortcutStrip.ini.bak-*` / `Rainmeter.ini.bak-*` | 本次改造前的备份 |

用户侧：

| 路径 | 说明 |
|---|---|
| `Skins\ShortcutStrip\` | 竖条版皮肤（当前启用） |
| `Skins\ShortcutDock\` | 卡片版皮肤 + `@Resources\{Links,Badges,Icons,Scripts,bg.png}` |
| `Skins\ShortcutDock\刷新面板.bat` | 一键刷新 |
| `Skins\EdgeTab\` | v2 遗留，已停用，可删 |
| `Skins\Verticons\` | 用户自己装的参考皮肤（未激活） |

## 11. 编码/写文件的硬性注意

- 所有 `.ps1` 必须 **UTF-8 with BOM**（无 BOM 时 Windows PowerShell 5.1 会把中文读成乱码）。
- 所有 Rainmeter `.ini` 必须 **UTF-16LE + BOM**。
- `.bat` 必须 **CRLF**（`chcp 65001` + UTF-8 无 BOM，别加 BOM）。
- 生成器里别写裸的 `;` 注释行（PowerShell 语法错误）。
- here-string 嵌套会提前终止，内嵌 ini 一律用字符串数组 `-join` 或逐行 `L` 拼。
- Markdown / 预览图直接用 UTF-8 即可。
