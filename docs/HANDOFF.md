# HANDOFF —— 桌面快捷方式启动器（Rainmeter）交接日志

> 写给下一个 agent / 未来的自己。最后更新：2026-11-20（**已验收：QQ 式平滑滑动可用**）。
> 用户语言：中文。用户机器：Windows 11 26H2，显示器 **物理 3840×2160 @150%**，Rainmeter 用**逻辑 2560×1440**。

## 0. 2026-11-20 最新结论（覆盖下文所有旧描述，先看这里）

**当前状态：`ShortcutStrip` 已实现 QQ 式贴边自动隐藏，且**任意边自适应**，全部实测通过。**

- **贴哪条边就往哪条边藏**：右边→向左滑出、左边→向右滑出、顶边→向下滑出；**顶边与左右重合（角落）时优先按顶边**。
- 方向判定在 `Slide.lua` 的 `Setup(cx,cy)`：容差 16px；`dTop<=16 → top`，否则 `dLeft<=16 → left`，否则 `dRight<=16 → right`，都不贴边则按最近的左/右。
- 收起时露 **14px 深灰圆角窄条**，随方向自动换成 竖条(‹ / ›) 或 横条(︿)，**不使用蓝色手柄**。
- 展开/收起是 **Lua 逐帧缓动滑动**（约 300ms），不是瞬移。
- `Draggable=1`：把面板拖到任意边，松手后 `#CURRENTCONFIGX/Y#`（运行中确为动态值）会检测到位移，自动重新贴边并收起。
- 面板 370×834（逻辑像素），78 项 / 5 分类。

**坐标体系（本轮踩坑的根因）**

- 物理 3840×2160，Rainmeter 按 150% 渲染 → 使用**逻辑坐标 2560×1440**（物理 = 逻辑 × 1.5）。
- 生成器是 DPI-unaware 的 PowerShell，`Screen.Bounds` 读出来**已经是逻辑 2560×1440**，直接用，**不要再除 DPI**（旧文档里 1707 / 1337 / 1693 都是多除了一次 1.5 的错值）。
- 右边：展开 `ExpX=2190`、收起 `ColX=2546`；顶边：展开 `ExpY=0`、收起 `ColY=-(834-14)=-820`；左边：收起 `ColX=-(370-14)=-356`。

**Rainmeter.ini 的 [ShortcutStrip] 必须是这样（当前=顶右角）**

```
WindowX=2190
WindowY=0
Draggable=1        ← 允许拖动换边
KeepOnScreen=0     ← 关键：设 1 会把窗口钉死在屏内、永远展开，看起来就是“假隐藏”
AlwaysOnTop=1
SavePosition=0
```

> **`AlwaysOnTop` 必须是 1**：设成 `-2` 就是 Rainmeter 的 “On Desktop”，皮肤会被画在桌面层——开任何窗口就看不见了，表现得像“重启后不见了”。2026-11-20 就踩过这个：位置正常（2190,-820）、窄条也画了，只是被压到所有窗口下面。

**机制**：`[mHideTick]` 鼠标离开 70 tick（≈1.4s）后收起；`[mShowTick]` 悬停 `mHandle` 展开；`[mSlide]` = `@Resources\Scripts\Slide.lua`，`Update()` 里 `cur += (tgt-cur)*0.28` 再 `!Move`；滑到位才隐藏 Panel 组并显示窄条（所以滑动过程面板可见）。

**验收数据（物理像素窗口左边缘 X）**：右边 收起 3801 → 展开 `3552→3477→3423→3386→3357→3323→3312→3305→3299→3296→3293→3290→3288→3285` → 移开 `3285→3429→3534→3609→3663→3701→3729→3749→3764→3774→3801`。顶边（Y）：`-1230 → -885 → -638 → -459 → -330 → -239 → -171 → … → 0`。

**已踩死的坑**：① 外部 CLI bang（`Rainmeter.exe !Move/!Quit`）无效，改 ini 必须 `Stop-Process -Name Rainmeter -Force` + `Start-Process` 重启；② `Meter=Shape` 缺 `W/H` 不渲染也不可点，用 `Meter=Image`；③ `SetCursorPos` 单跳不触发悬停事件，测试要 `mouse_event` 绝对坐标多步扫入；④ 窄条做太薄（8px）时面板左边缘是圆角透明，等于全隐身（“软件看不见了”），14px 才看得见；⑤ PowerShell 里函数名不能叫 `R`（`r` 是 `Invoke-History` 别名）。

---

以下为早期历史（部分结论已被上面覆盖，谨慎引用）。


## 1. 用户最初的问题

桌面图标太乱，而且**每次远程（RDP / 向日葵等）之后图标位置都会变**。
一路迭代后，用户的真实诉求变成：

1. 桌面图标不要再占桌面 → 用 Rainmeter 面板替代；
2. 面板要好看，参考用户自己下载的 Verticons（白图标、无背景、大间距）；
3. **分类要清楚**（这是用户反复强调的：「还是要把分类做好啊」）；
4. 最后追加需求：**像 QQ 那样贴边自动隐藏**（默认收起、鼠标碰边缘滑出、移开自动缩回）。

## 2. 当前状态（重要）

| 项目 | 状态 |
|---|---|
| `ShortcutDock`（卡片版） | ✅ 可用，已停用（Active=0），随时可切回 |
| `ShortcutStrip`（分类竖条版） | ✅ 可用，当前激活（Active=1，位于 X=1337 Y=30） |
| `EdgeTab`（贴边手柄） | ⚠️ 半成品，Active=0；自动隐藏逻辑**未验收通过** |
| 自动隐藏 | ⚠️ 收起基本可用，展开不稳定（详见 §7） |
| `Logging` | 已还原为 0 |
| Rainmeter | 正在运行，v4.5.28.3936 64-bit |

**下一个 agent 的第一件事**：先读 §7（自动隐藏的坑），再决定是修（方案 A/C）还是退回稳定版（方案 D）。

## 3. 环境事实（不要重新探测，已验证）

- Rainmeter 安装：`D:\Program Files\Rainmeter\Rainmeter.exe`
- 皮肤目录（SkinPath）：`D:\Users\lyj\Documents\Rainmeter\Skins\`
- 设置文件：`C:\Users\lyj\AppData\Roaming\Rainmeter\Rainmeter.ini`（**UTF-16LE + BOM**，改前必须先 `!Quit`，改完再启动）
- 用户桌面：`D:\Users\lyj\Desktop`（46 个 .lnk）
- 公共桌面：`C:\Users\Public\Desktop`（36 个 .lnk）
- 去重后 **78 个条目**
- 工作区：`C:\Users\lyj\Documents\deepseek-harness\default-workspace\ShortcutDock\`
- Verticons 样本解包在：`...\default-workspace\Verticons\extracted\`（仅参考，用户已自己装了一份到 Skins\Verticons，现在 Active=0）

### DPI 换算（**最容易踩的坑**）

- Windows 缩放 150%，`AppliedDPI=144`，逻辑分辨率 = 1707×960。
- `Rainmeter.ini` 里的 `WindowX/WindowY` 是**逻辑像素**，实际物理坐标 = 值 × 1.5。
  - 实测：`WindowX=(#SCREENAREAWIDTH#-1010)` 得到 1550 → 窗口物理 L=2325。
  - `#SCREENAREAWIDTH#` 返回 2560（物理），但 WindowX 会被乘 1.5，混用会算错。
- **pwsh 进程 DPI 不感知**：`[System.Windows.Forms.Cursor]::Position` / `SetCursorPos` 的入参是逻辑坐标。
  要悬停物理 (2553,705) 的点，必须设 logical `(1702, 470)`。
- `GetWindowRect` 返回的也是逻辑坐标；枚举窗口后要 ×1.5 才是物理位置。

## 4. 目录与数据流

```
桌面 *.lnk（用户桌面 + 公共桌面，按 TargetPath 去重 → 78）
  │ Generate-ShortcutDock.ps1        ← 分类 $GroupList、改名 $Rename、卡片版皮肤
  ├─→ Skins\ShortcutDock\@Resources\Links\01..78.lnk    （快捷方式副本，编号=展示顺序）
  ├─→ Skins\ShortcutDock\ShortcutDock.ini               （卡片版，UTF-16LE）
  │ Make-BadgeIcons.ps1               ← 白圆底图标（有缓存，删除 Badges 才全量重画）
  ├─→ Skins\ShortcutDock\@Resources\Badges\B01..78.png  （96×96）
  │ Generate-ShortcutStrip.ps1        ← 读卡片版 ini 拿「名字+分类」，生成竖条与手柄
  ├─→ Skins\ShortcutStrip\ShortcutStrip.ini + Links/Badges 副本 + stripbg/line/handle.png
  └─→ Skins\EdgeTab\EdgeTab.ini + @Resources\tab.png
```

一键刷新：`Skins\ShortcutDock\刷新面板.bat`（跑上面三个脚本 + `Rainmeter.exe !RefreshApp`），
开始菜单里也有快捷方式「刷新快捷方式面板」。

### 分类（写死在 `Generate-ShortcutDock.ps1` 的 `$GroupList`）

| 分类 | 数量 | 列数 |
|---|---|---|
| 游戏 | 17 | 1 |
| 开发 / AI | 20 | 2（均分 10+10） |
| 工程 / 工具 | 13 | 1 |
| 日常 / 媒体 | 16 | 1 |
| 聊天 / 娱乐 / 系统 | 12 | 1 |

竖条显示时标题会截成 `" / "` 前的一段（开发 / AI → 开发）。改分类只改 `$GroupList`（组名+组内顺序）和 `$Rename`（显示名），然后跑 `刷新面板.bat`。

### 竖条版版式参数（`Generate-ShortcutStrip.ps1` 顶部）

`$badge=36`、`$gapX=62`、`$gapY=44`、`$margin=20`、`$headerH=28`、`$groupGap=22`、`$rowMax=18`
背景透明度：脚本里 `FromArgb(115, 12,14,19)` 的 115，改成 0 即 Verticons 原味无背景（但用户当前壁纸偏亮，115 是为了可读性）。

### 图标生成策略（`Make-BadgeIcons.ps1`）

用 `SHGetFileInfo + SHGetImageList(SHIL_JUMBO)` 拿 **256px** 图标（比 `ExtractAssociatedIcon` 32px 清晰），按类型自动选模式：

- A：白圆底 + 原色图标（71/78）
- B：白圆底 + 深灰字形（白字形透明底）
- C：白圆底 + 按亮度反推的字形（白底深字）
- E：深色圆底 + 原图
- F：白圆底 + 名字首字（信息量太低时兜底，例：雷 / 鸿 / SO）

缓存规则：`B*.png` 比对应 `.lnk` 新就跳过；想重画删掉对应 png 再刷新。

## 5. 已完成的工作（按时间线）

1. 诊断「远程后图标乱位」：根因是 `自动排列图标` 开着 + 远程分辨率/DPI 与本地不一致；给了注册表备份脚本（`保存图标布局.ps1` / `恢复图标布局.ps1`）和「隐藏桌面图标」脚本（`隐藏或显示桌面图标.ps1`）。
2. 做过一版**卡片面板**（`ShortcutDock`）：GDI+ 画渐变圆角卡片 + 悬停胶囊，5 列分组，已可用但用户嫌丑 → 转向 Verticons 风格。
3. 分析用户下载的 `Verticons_1.0.rmskin`：解包 → `RMSKIN.ini` + 64 行 `Icons.ini`，学到 `Update=-1`、`SolidColor=0,0,0,1` 点击 hack、变量化尺寸/间距。文件有 Mark-of-the-Web，装前建议 `Unblock-File`。
4. 尝试把 78 个 exe 图标转纯白剪影：**失败**，只有 21/78 可用（多数 exe 图标是满幅不透明方块）→ 改为「白圆底 + 原色图标」。
5. 竖条版 v1：无背景 6×13 网格 → 用户反馈「还是要把分类做好啊」。
6. 竖条版 v2：5 个分类区块（标题+细线+图标列），开发 20 个自动均分 2 列；加淡色圆角底（解决亮壁纸看不清）；加首字兜底徽章；修了 Links 编号与图标错位问题（编号必须用 Links 文件名 `01..78`，不能用卡片 ini 的 `mT1..mT78`）。
7. 自动隐藏第一版（单皮肤）：计时器 + 手柄 + `!Move` 移出屏幕。**结论：收起能work，展开不可靠**。
8. 自动隐藏第二版（双皮肤 EdgeTab + 停用/激活）：hover 展开时好时坏，最后状态：面板停在 1337 常显、EdgeTab Active=0。

## 6. 自动隐藏当前实现（半成品，供接手者判断）

`ShortcutStrip.ini`：

```ini
[Rainmeter]
Update=1000
OnRefreshAction=[!SetVariable Hovered 1][!SetVariable Shown 1][!Move 1337 30][!DeactivateConfig "EdgeTab"]

[Variables]
Hovered=0
Shown=1

[mHideTimer]
Measure=Calc
DynamicVariables=1
Formula=#Hovered# * 10 + #Shown#
UpdateDivider=1
IfCondition=mHideTimer = 1
IfTrueAction=[!Move 2400 30][!ActivateConfig "EdgeTab" "EdgeTab.ini"]

[mBg]  ... MouseOverAction=[!SetVariable Hovered 1]
[每个图标]  MouseOverAction 里带 [!SetVariable Hovered 1]，MouseLeaveAction 里带 [!SetVariable Hovered 0]
```

`EdgeTab.ini`（10×140 蓝色圆角条，贴右边缘）：

```ini
[mTab]
Meter=Image
ImageName=#@#tab.png
SolidColor=0,0,0,120
W=10
H=140
MouseOverAction=[!DeactivateConfig "ShortcutStrip"][!ActivateConfig "ShortcutStrip" "ShortcutStrip.ini"]
```

`Rainmeter.ini` 中的位置（**当前值**）：

```ini
[ShortcutStrip]  Active=1  WindowX=1337  WindowY=30   KeepOnScreen=0  Draggable=0  AlwaysOnTop=1
[EdgeTab]        Active=0  WindowX=1697  WindowY=410  KeepOnScreen=0  Draggable=0  AlwaysOnTop=1
```

- 展开位置 1337 → 物理 2005，面板右边缘正好贴屏幕右边缘（2560）。
- 收起位置 2400（完全移出屏幕外）。
- 手柄 1697 → 物理 2545.5，宽 10 逻辑 = 15 物理。

## 7. 自动隐藏的坑与排查记录（**接手必读**）

已验证的 Rainmeter 事实：

1. `Update=-1` 时鼠标动作仍可用，但 **Calc/Time 计时器不会跑** → 自动隐藏必须有 `Update=1000`。
2. `IfCondition=Measure = 1` 会报 `"Measure" is unknown`；**必须写成 `IfCondition=mHideTimer = 1`**（引用 measure 自己的名字）。
3. `Formula` 里引用 `#Hovered#`/`#Shown#` 必须加 `DynamicVariables=1`，否则变量变化不会重算。
4. 对**已经激活**的 config 执行 `!ActivateConfig` **不会**刷新/重跑 `OnRefreshAction`（实测：面板停在 2400 不动）。要重载得先 `!DeactivateConfig` 再 `!ActivateConfig`。
5. 在同一个皮肤里「激活别的皮肤 + 停用自己」有竞态：实测出现过两个皮肤都 Active=0、什么都不显示。当前版本把「停用自己」改成「把自己 `!Move` 到屏幕外」，以此规避。
6. **`MouseLeaveAction` 用在整块全屏 meter 上不可靠**：Rainmeter 只把鼠标事件派发给「最上层被悬停的 meter」，全屏背景 meter 埋在图标下面时永远收不到 enter/leave；给它加 `SolidColor=0,0,0,1` 也没用。所以「鼠标离开panel就收起」只能靠每个 meter 的 leave 更新 `Hovered` 变量 + 计时器兜底。
7. 窗口只露边缘几像素时，`Cursor.Position` 模拟悬停**时灵时不灵**（部分是我测试坐标没除 1.5 造成的假象，但也确有丢失 enter 的情况）。真实人类连续移动鼠标会好些，但不能作为验收依据。
8. `!Move` 本身是可靠的：CLI `Rainmeter.exe !Move 1200 30` 立即生效。
9. 测试时开 `Logging=1` 看 `%APPDATA%\Rainmeter\Rainmeter.log`，能抓到 ini/bang 错误（例如 `IfCondition` 报错就是这么发现的）。

## 8. 建议的下一步（按优先级）

**A. 单皮肤方案（推荐，改动小）**
把 EdgeTab 去掉，全部在一个皮肤里：`WindowX` 用 `!Move` 在「展开 1337」和「收起 2400」间切换；边缘触发用皮肤内一个 12×140 的 meter 放在 `X=0`（收起时它正好露在屏幕右缘）；展开时把它 `!HideMeter`；收起时 `!ShowMeter`。关键：收起后**不要移动窗口到完全屏幕外**，保留 14~16 逻辑像素让手柄可见可点。`MouseOverAction` 里 `[!Move 1337 30][!HideMeter mTab]`。
（这套之前试过，hover 偶发丢失；可再加 `LeftMouseUpAction` 作为点击兜底。）

**B. 双皮肤修正版**
保持 EdgeTab，但：面板收起 = `!DeactivateConfig "ShortcutStrip"`（不再自己移出屏幕）；EdgeTab 常驻 Active=1；EdgeTab 的 hover 里先 `!Refresh "ShortcutStrip"` 再 `!ActivateConfig`；面板 `OnRefreshAction` 负责 `!DeactivateConfig "EdgeTab"`，而收起时由 `mHideTimer` 先 `!ActivateConfig "EdgeTab"` 再 `!DeactivateConfig` 自己。注意 bang 顺序与竞态，建议每次动作后加 100~200ms 延迟（可用 `!Delay` 若存在，或拆成两次鼠标事件）。

**C. Lua 脚本（最稳，工作量最大）**
`Measure=Script` 用 Lua 定时读鼠标位置（`GetCursorPos` 需要插件或 `SKIN:Bang` 循环），实现真正的「鼠标离开面板 → 收起」。Rainmeter 自带 Lua 支持但 API 有限，需确认能否取鼠标坐标；不能则放弃。

**D. 退回稳定版（兜底方案）**
用户如果不想再折腾：删掉 `[mHideTimer]` 与 `OnRefreshAction` 两段（生成脚本里各一处），让 `ShortcutStrip` 常显在 1337；删除/停用 EdgeTab；把 `AlwaysOnTop` 保持 1 或改 0 由用户喜好。当前状态其实已经接近这个（面板就在 1337 常显）。

**E. 收尾别忘了**
- 用户桌面图标还没隐藏（右键桌面 → 查看 → 显示桌面图标，取消勾选）；隐藏后此面板就是唯一入口。
- 交付前确认 `Logging=0`、`Rainmeter.ini` 里各皮肤 Active 状态符合预期。
- 更新 `README.md`（已写，但自动隐藏章节还没写）。

## 9. 常用操作/命令

```powershell
# 重启 Rainmeter（改 ini 前先退出，否则会被覆盖）
Start-Process 'D:\Program Files\Rainmeter\Rainmeter.exe' -ArgumentList '!Quit'
Start-Sleep -Milliseconds 1500
Start-Process 'D:\Program Files\Rainmeter\Rainmeter.exe'

# 重新生成全部（链接 → 图标 → 竖条）
powershell -NoProfile -ExecutionPolicy Bypass -File "...\Skins\ShortcutDock\@Resources\Scripts\Generate-ShortcutDock.ps1"
powershell -NoProfile -ExecutionPolicy Bypass -File "...\Skins\ShortcutDock\@Resources\Scripts\Make-BadgeIcons.ps1"
powershell -NoProfile -ExecutionPolicy Bypass -File "...\Skins\ShortcutDock\@Resources\Scripts\Generate-ShortcutStrip.ps1"
Start-Process 'D:\Program Files\Rainmeter\Rainmeter.exe' -ArgumentList '!RefreshApp'

# 查询皮肤窗口 rect（记住返回的是逻辑坐标）
# 见下方 C# 片段：EnumWindows + GetClassName=='RainmeterMeterWindow' + GetWindowRect

# 模拟鼠标（逻辑坐标 = 物理 / 1.5）
[System.Windows.Forms.Cursor]::Position = New-Object System.Drawing.Point 1702, 470   # 物理 (2553,705)
```

窗口枚举 C# 片段（可直接 Add-Type）：

```csharp
public delegate bool EnumProc(IntPtr h, IntPtr l);
[DllImport("user32.dll")] public static extern bool EnumWindows(EnumProc cb, IntPtr l);
[DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern int GetClassName(IntPtr h, StringBuilder s, int n);
[DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern int GetWindowText(IntPtr h, StringBuilder s, int n);
[DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out R r);
// 类名 == "RainmeterMeterWindow" 的就是皮肤窗口，标题 = ini 完整路径
```

## 10. 文件清单

工作区 `...\default-workspace\ShortcutDock\`：

| 文件 | 说明 |
|---|---|
| `Generate-ShortcutDock.ps1` | 主生成器：扫桌面、分类、改名、生成 Links + 卡片版 ini |
| `Make-BadgeIcons.ps1` | 提取 256px 图标 → 白圆底徽章（A/B/C/E/F 模式，带缓存） |
| `Generate-ShortcutStrip.ps1` | 生成竖条版 ini + EdgeTab ini + 素材（背景/细线/手柄） |
| `README.md` | 面向用户的说明（自动隐藏章节待补） |
| `HANDOFF.md` | 本文件 |
| `preview-strip.png` | 分类竖条效果图（当前主交付外观） |
| `preview-hidden.png` | 收起时右边缘手柄效果 |
| `preview-panel.png` | 旧卡片版效果图 |
| `badges-sheet.png` | 78 个徽章图标的拼图预览 |

用户侧：

| 路径 | 说明 |
|---|---|
| `Skins\ShortcutDock\` | 卡片版皮肤 + `@Resources\{Links,Badges,Scripts,bg.png}` |
| `Skins\ShortcutStrip\` | 竖条版皮肤 + `@Resources\{Links,Badges,Scripts,stripbg,line,handle}.png` |
| `Skins\EdgeTab\` | 贴边手柄皮肤（半成品） |
| `Skins\Verticons\` | 用户自己装的参考皮肤（未激活） |
| `Skins\ShortcutDock\刷新面板.bat` | 一键刷新（三步生成 + RefreshApp） |
| 开始菜单「刷新快捷方式面板」 | 指向上面 bat 的快捷方式 |

## 11. 编码/写文件的硬性注意

- 所有 `.ps1` 必须存成 **UTF-8 with BOM**，否则 Windows PowerShell 5.1 会把中文读成乱码（踩过：`'宕╁潖锛氭槦绌归搧閬?`）。
- 所有 Rainmeter `.ini` 必须存成 **UTF-16LE + BOM**，否则中文不显示。
- 生成器里不要写裸的 `;` 注释行（会被 PowerShell 当语法错误，踩过）。
- 用 `@' ... '@` here-string 嵌套时会提前终止，内嵌 ini 用字符串数组 `-join` 拼。
