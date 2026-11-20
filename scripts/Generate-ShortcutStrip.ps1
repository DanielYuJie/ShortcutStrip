# 生成「分类竖条 + 贴边自动隐藏」启动器（v3 单皮肤版）
# 由 Generate-ShortcutDock.ps1 产生的 Links/Badges/分组信息驱动
# 自动隐藏：同一个皮肤在「展开位」和「贴边收起位」之间 !Move；手柄是皮肤里的一个 meter
param(
    [string]$SrcSkin = 'D:\Users\lyj\Documents\Rainmeter\Skins\ShortcutDock',
    [string]$SkinDir = 'D:\Users\lyj\Documents\Rainmeter\Skins\ShortcutStrip'
)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Windows.Forms
$enc16 = New-Object System.Text.UnicodeEncoding($false, $true)

$srcLinks  = Join-Path $SrcSkin '@Resources\Links'
$srcBadges = Join-Path $SrcSkin '@Resources\Badges'
if (-not (Test-Path $srcLinks))  { throw "找不到 $srcLinks，请先运行 Generate-ShortcutDock.ps1" }
if (-not (Test-Path $srcBadges)) { throw "找不到 $srcBadges，请先运行 Make-BadgeIcons.ps1" }

# ---------- 1. 从卡片版 ini 读回「显示名 + 分类」 ----------
$cardIni = Join-Path $SrcSkin 'ShortcutDock.ini'
$lines = [System.IO.File]::ReadAllLines($cardIni, [System.Text.Encoding]::Unicode)
$items = New-Object System.Collections.ArrayList
$curGroup = '其他'; $curId = $null
foreach ($line in $lines) {
    if ($line -match '^; -+ (.+) -+$') { $curGroup = $Matches[1] }
    elseif ($line -match '^\[mT(\d+)\]$') { $curId = $Matches[1] }
    elseif ($line -match '^Text=(.+)$' -and $curId) {
        [void]$items.Add([pscustomobject]@{ Name = $Matches[1]; Group = $curGroup }); $curId = $null
    }
}
if ($items.Count -eq 0) { throw '没能从卡片版 ini 解析出条目' }
$linkIds = @(Get-ChildItem $srcLinks -Filter *.lnk | Sort-Object Name | ForEach-Object { $_.BaseName })
if ($linkIds.Count -ne $items.Count) { throw "数量不一致：Links=$($linkIds.Count) 条目=$($items.Count)" }
for ($k = 0; $k -lt $items.Count; $k++) {
    $items[$k] | Add-Member -NotePropertyName Id -NotePropertyValue $linkIds[$k] -Force
}

# ---------- 2. 复制 Links / Badges ----------
$linksDir  = Join-Path $SkinDir '@Resources\Links'
$badgesDir = Join-Path $SkinDir '@Resources\Badges'
Remove-Item $linksDir, $badgesDir -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force -Path $linksDir, $badgesDir | Out-Null
Copy-Item (Join-Path $srcLinks '*')  $linksDir  -Force
Copy-Item (Join-Path $srcBadges '*') $badgesDir -Force

# ---------- 3. 版式 ----------
$badge = 36; $gapX = 62; $gapY = 44; $margin = 20; $headerH = 28; $groupGap = 22; $rowMax = 18

$byGroup = [ordered]@{}
foreach ($it in $items) {
    if (-not $byGroup.Contains($it.Group)) { $byGroup[$it.Group] = New-Object System.Collections.ArrayList }
    [void]$byGroup[$it.Group].Add($it)
}
$groups = New-Object System.Collections.ArrayList
foreach ($g in $byGroup.Keys) {
    $list = $byGroup[$g]
    $cols = [int][Math]::Ceiling($list.Count / [double]$rowMax)
    $perCol = [int][Math]::Ceiling($list.Count / [double]$cols)
    [void]$groups.Add([pscustomobject]@{ Title = $g; Items = $list; Cols = $cols; PerCol = $perCol })
}

$skinW = $margin
foreach ($g in $groups) { $skinW += (($g.Cols - 1) * $gapX + $badge) + $groupGap }
$skinW = $skinW - $groupGap + $margin
# 最高一行 = 各分组「实际每列行数」的最大值（旧版错用了 Min(rowMax, 条目数)，会把面板画高）
$maxRows = 0
foreach ($g in $groups) { $maxRows = [Math]::Max($maxRows, $g.PerCol) }
$contentBottom = $margin + $headerH + ($maxRows - 1) * $gapY + $badge
$skinH = $contentBottom + 10 + 16 + $margin

# ---------- 3b. 屏幕与自动隐藏坐标（Rainmeter 的 WindowX/!Move 用「逻辑像素」） ----------
$appliedDpi = 96
try { $appliedDpi = [int](Get-ItemProperty 'HKCU:\Control Panel\Desktop\WindowMetrics' -Name AppliedDPI -ErrorAction Stop).AppliedDPI } catch { }
if ($appliedDpi -le 0) { $appliedDpi = 96 }
$scale = $appliedDpi / 96.0
$physW = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds.Width
$physH = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds.Height
# 实测：本机物理 3840×2160 @150%，Rainmeter 用逻辑坐标（= 物理/1.5）；DPI-unaware 进程读到的 Bounds 已是逻辑值
$logW = $physW
$logH = $physH

$topY    = 30
$peek    = 14          # 收起时露出的窄条厚度（逻辑像素）
# 下面只是「默认贴右边」的初始值；真正贴哪条边由皮肤启动时按窗口实际位置自适应（Slide.lua 的 Setup）
$expX    = $logW - $skinW
$colX    = $logW - $peek
$expY    = $topY
$colY    = $topY

# ---------- 4. 生成素材 ----------
$resDir = Join-Path $SkinDir '@Resources'
New-Item -ItemType Directory -Force -Path $resDir | Out-Null

# 淡色圆角底
$bgBmp = New-Object System.Drawing.Bitmap -ArgumentList $skinW, $skinH
$bgg = [System.Drawing.Graphics]::FromImage($bgBmp)
$bgg.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$gp = New-Object System.Drawing.Drawing2D.GraphicsPath
$r = 16; $d = $r * 2
$gp.AddArc(0, 0, $d, $d, 180, 90)
$gp.AddArc($skinW - $d - 1, 0, $d, $d, 270, 90)
$gp.AddArc($skinW - $d - 1, $skinH - $d - 1, $d, $d, 0, 90)
$gp.AddArc(0, $skinH - $d - 1, $d, $d, 90, 90)
$gp.CloseFigure()
$bgg.FillPath((New-Object System.Drawing.SolidBrush -ArgumentList ([System.Drawing.Color]::FromArgb(115, 12, 14, 19))), $gp)
$bgg.DrawPath((New-Object System.Drawing.Pen -ArgumentList ([System.Drawing.Color]::FromArgb(90, 255, 255, 255)), 1), $gp)
$bgg.Dispose(); $gp.Dispose()
$bgBmp.Save((Join-Path $resDir 'stripbg.png'), [System.Drawing.Imaging.ImageFormat]::Png); $bgBmp.Dispose()

# 分类分隔细线
$lb = New-Object System.Drawing.Bitmap -ArgumentList 1, 1
$lb.SetPixel(0, 0, [System.Drawing.Color]::FromArgb(46, 255, 255, 255))
$lb.Save((Join-Path $resDir 'line.png'), [System.Drawing.Imaging.ImageFormat]::Png); $lb.Dispose()

# 收起态可见窄条（QQ 式）：深灰半透明圆角条 + 浅色描边 + 牵引箭头；不使用蓝色。
# 生成 4 个方向（right/left/top/bottom），由皮肤按当前贴边方向自动选用。
function New-Tab([string]$file, [int]$w, [int]$h, [string]$dir) {
    $bmp = New-Object System.Drawing.Bitmap -ArgumentList $w, $h
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $g.Clear([System.Drawing.Color]::Transparent)
    $p = New-Object System.Drawing.Drawing2D.GraphicsPath
    $r = [Math]::Min(9, [int]([Math]::Min($w, $h) / 2)); $d = $r * 2
    $p.AddArc(0, 0, $d, $d, 180, 90)
    $p.AddArc($w - $d - 1, 0, $d, $d, 270, 90)
    $p.AddArc($w - $d - 1, $h - $d - 1, $d, $d, 0, 90)
    $p.AddArc(0, $h - $d - 1, $d, $d, 90, 90)
    $p.CloseFigure()
    $g.FillPath((New-Object System.Drawing.SolidBrush -ArgumentList ([System.Drawing.Color]::FromArgb(206, 21, 24, 30))), $p)
    $g.DrawPath((New-Object System.Drawing.Pen -ArgumentList ([System.Drawing.Color]::FromArgb(100, 172, 178, 190)), 1), $p)
    $penA = New-Object System.Drawing.Pen -ArgumentList ([System.Drawing.Color]::FromArgb(185, 208, 212, 222)), 1.4
    $cx = [int]($w / 2); $cy = [int]($h / 2); $s = 5
    switch ($dir) {
        'right'  { $g.DrawLine($penA, $cx + 2, $cy - $s, $cx - $s + 2, $cy); $g.DrawLine($penA, $cx - $s + 2, $cy, $cx + 2, $cy + $s) }
        'left'   { $g.DrawLine($penA, $cx - 2, $cy - $s, $cx + $s - 2, $cy); $g.DrawLine($penA, $cx + $s - 2, $cy, $cx - 2, $cy + $s) }
        'top'    { $g.DrawLine($penA, $cx - $s, $cy + 2, $cx, $cy - $s + 2); $g.DrawLine($penA, $cx, $cy - $s + 2, $cx + $s, $cy + 2) }
        'bottom' { $g.DrawLine($penA, $cx - $s, $cy - 2, $cx, $cy + $s - 2); $g.DrawLine($penA, $cx, $cy + $s - 2, $cx + $s, $cy - 2) }
    }
    $g.Dispose(); $p.Dispose()
    $bmp.Save((Join-Path $resDir $file), [System.Drawing.Imaging.ImageFormat]::Png); $bmp.Dispose()
}
New-Tab 'handle-right.png'  $peek  $skinH 'right'
New-Tab 'handle-left.png'   $peek  $skinH 'left'
New-Tab 'handle-top.png'    $skinW $peek  'top'
New-Tab 'handle-bottom.png' $skinW $peek  'bottom'

# ---------- 5. 面板 ini ----------
$sb = New-Object System.Text.StringBuilder
function L { param([string]$s = '') [void]$sb.AppendLine($s) }

L '; =================================================================='
L '; 分类竖条（Generate-ShortcutStrip.ps1 生成）：分类标题 + 贴边自动隐藏'
L '; 自动隐藏全部在这一个皮肤里：展开位 ExpX / 收起位 ColX，透明感应区 mHandle'
L '; =================================================================='
L ''
L '[Rainmeter]'
L 'Update=20'
L 'AccurateText=1'
L 'DynamicWindowSize=0'
L 'BackgroundMode=1'
L "OnRefreshAction=[!SetVariable Shown 0][!SetVariable Hovered 0][!SetVariable HandleHover 0][!SetVariable Lock 1][!SetVariable Moving 0][!HideMeterGroup Panel][!HideMeter mLbl][!ShowMeter mHandle][!CommandMeasure mSlide `"Setup(#CURRENTCONFIGX#,#CURRENTCONFIGY#)`"][!Redraw]"
L ''
L '[Metadata]'
L 'Name=ShortcutStrip'
L "Author=$env:USERNAME"
L 'Version=3.2'
L 'Information=白圆图标 + 分类标题 + 贴边自动隐藏（单皮肤）'
L ''
L '[Variables]'
L 'FontFace=Microsoft YaHei UI'
L 'FontSize=9'
L 'LabelColor=255,255,255,255'
L 'TitleColor=255,255,255,235'
L "TopY=$topY"
L "ExpX=$expX"
L "ColX=$colX"
L "ExpY=$expY"
L "ColY=$colY"
L "SkinW=$skinW"
L "SkinH=$skinH"
L "Peek=$peek"
L "ScreenW=$logW"
L "ScreenH=$logH"
L 'Shown=0'
L 'Hovered=0'
L 'HandleHover=0'
L 'Lock=1'
L 'Moving=0'
L ''
L '; ---------------- 自动隐藏状态机（Update=250，1 tick = 0.25 秒） ----------------'
L '; 显示中 + 鼠标不在面板上 满 8 tick（2 秒）→ 收起'
L '[mHideTick]'
L 'Measure=Calc'
L 'DynamicVariables=1'
L 'Formula=((#Shown#=1) && (#Hovered#=0) && (#Moving#=0)) ? (mHideTick+1) : 0'
L 'IfCondition=mHideTick>=70'
L "IfTrueAction=[!SetVariable Shown 0][!SetVariable Lock 1][!SetVariable Moving 1][!CommandMeasure mSlide `"GoTo(#ColX#,#ColY#)`"]"
L ''
L '; 收起中 + 手柄被悬停 + 冷却结束 → 展开（1 tick 内响应）'
L '[mShowTick]'
L 'Measure=Calc'
L 'DynamicVariables=1'
L 'Formula=((#Shown#=0) && (#HandleHover#=1) && (#Lock#=0) && (#Moving#=0)) ? 1 : 0'
L 'IfCondition=mShowTick>=1'
L 'IfTrueAction=[!ShowMeterGroup Panel][!HideMeter mHandle][!SetVariable Shown 1][!SetVariable Hovered 1][!SetVariable HandleHover 0][!SetVariable Moving 1][!CommandMeasure mSlide "GoTo(#ExpX#,#ExpY#)"]'
L ''
L '; 刚收起后的 3 tick（0.75 秒）冷却：鼠标正好停在边缘时不至于反复开合'
L '[mUnlock]'
L 'Measure=Calc'
L 'DynamicVariables=1'
L 'Formula=(#Lock#=1) ? (mUnlock+1) : 0'
L 'IfCondition=mUnlock>=35'
L 'IfTrueAction=[!SetVariable Lock 0]'
L ''
L '; ---------------- 隐形满幅底：锁住窗口尺寸（收起时窗口不会缩） ----------------'
L '[mFrame]'
L 'Meter=Image'
L 'X=0'
L 'Y=0'
L "W=$skinW"
L "H=$skinH"
L 'SolidColor=0,0,0,1'
L ''
L '; ---------------- 背景（整块都能接住鼠标，图标之间的空隙也算面板内） ----------------'
L '[mBg]'
L 'Meter=Image'
L 'ImageName=#@#stripbg.png'
L 'X=0'
L 'Y=0'
L 'Group=Panel'
L 'SolidColor=0,0,0,1'
L 'MouseOverAction=[!SetVariable Hovered 1]'
L 'MouseLeaveAction=[!SetVariable Hovered 0]'
L ''

$x = $margin
$gi = 0
foreach ($g in $groups) {
    $gi++
    $bw = ($g.Cols - 1) * $gapX + $badge
    $cx = $x + [int]($bw / 2)
    $title = ($g.Title -split ' / ')[0].Trim()
    L "; ---------------- $title ----------------"
    L "[mH$gi]"
    L 'Meter=String'
    L "Text=$title"
    L "X=$cx"
    L "Y=$margin"
    L 'StringAlign=Center'
    L 'FontFace=#FontFace#'
    L 'FontSize=#FontSize#'
    L 'FontColor=#TitleColor#'
    L 'StringEffect=Shadow'
    L 'FontEffectColor=0,0,0,220'
    L 'AntiAlias=1'
    L 'Group=Panel'
    L 'MouseOverAction=[!SetVariable Hovered 1]'
    L 'MouseLeaveAction=[!SetVariable Hovered 0]'
    L ''
    L "[mLine$gi]"
    L 'Meter=Image'
    L 'ImageName=#@#line.png'
    L "X=$x"
    L "Y=$($margin + $headerH - 7)"
    L "W=$bw"
    L 'H=1'
    L 'Group=Panel'
    L 'MouseOverAction=[!SetVariable Hovered 1]'
    L 'MouseLeaveAction=[!SetVariable Hovered 0]'
    L ''
    for ($c = 0; $c -lt $g.Cols; $c++) {
        $colItems = @($g.Items | Select-Object -Skip ($c * $g.PerCol) -First $g.PerCol)
        $ix = $x + $c * $gapX
        for ($rr = 0; $rr -lt $colItems.Count; $rr++) {
            $it = $colItems[$rr]
            $iy = $margin + $headerH + $rr * $gapY
            $x2 = $ix - 3; $y2 = $iy - 3
            $action = '["#@#Links\' + $it.Id + '.lnk"]'
            $esc = $it.Name -replace '"', ''
            $on  = "[!SetVariable Hovered 1][!SetOption mI$($it.Id) X $x2][!SetOption mI$($it.Id) Y $y2][!SetOption mI$($it.Id) W 42][!SetOption mI$($it.Id) H 42][!SetOption mLbl Text `"$esc`"][!ShowMeter mLbl][!UpdateMeter mI$($it.Id)][!UpdateMeter mLbl][!Redraw]"
            $off = "[!SetVariable Hovered 0][!SetOption mI$($it.Id) X $ix][!SetOption mI$($it.Id) Y $iy][!SetOption mI$($it.Id) W $badge][!SetOption mI$($it.Id) H $badge][!HideMeter mLbl][!UpdateMeter mI$($it.Id)][!UpdateMeter mLbl][!Redraw]"
            L "[mI$($it.Id)]"
            L 'Meter=Image'
            L "ImageName=#@#Badges\B$($it.Id).png"
            L "X=$ix"
            L "Y=$iy"
            L "W=$badge"
            L "H=$badge"
            L 'Group=Panel'
            L "LeftMouseUpAction=$action"
            L "ToolTipText=$($it.Name)"
            L "MouseOverAction=$on"
            L "MouseLeaveAction=$off"
            L ''
        }
    }
    $x += $bw + $groupGap
}

L '; ---------------- 悬停名字（不属于 Panel 组：收起时一起隐藏，展开时不强行显示） ----------------'
L '[mLbl]'
L 'Meter=String'
L 'Text= '
L "X=$([int]($skinW / 2))"
L "Y=$($contentBottom + 10)"
L 'StringAlign=Center'
L 'FontFace=#FontFace#'
L 'FontSize=#FontSize#'
L 'FontColor=#LabelColor#'
L 'StringEffect=Shadow'
L 'FontEffectColor=0,0,0,230'
L 'AntiAlias=1'
L 'Hidden=1'
L ''

L '; ---------------- 收起态窄条：贴哪条边就显示对应方向的条（位置/图片由 Slide.lua 的 Setup 决定） ----------------'
L '[mHandle]'
L 'Meter=Image'
L 'ImageName=#@#handle-right.png'
L 'X=0'
L 'Y=0'
L "W=$peek"
L "H=$skinH"
L 'SolidColor=0,0,0,1'
L 'ToolTipText=快捷方式面板：鼠标碰到窄条即滑出'
L 'MouseOverAction=[!SetVariable HandleHover 1][!UpdateMeter mHandle][!Redraw]'
L 'MouseLeaveAction=[!SetVariable HandleHover 0][!UpdateMeter mHandle][!Redraw]'
L 'LeftMouseUpAction=[!SetVariable HandleHover 1]'
L ''
L '; ---------------- 平滑滑动驱动（Lua 逐帧 !Move）：展开/收起都经过它 ----------------'
L '[mSlide]'
L 'Measure=Script'
L 'ScriptFile=#@#Scripts\Slide.lua'

$iniPath = Join-Path $SkinDir 'ShortcutStrip.ini'
[System.IO.File]::WriteAllText($iniPath, $sb.ToString(), $enc16)

# ---------- 6. 脚本自身副本 ----------
$scriptDir = Join-Path $SkinDir '@Resources\Scripts'
New-Item -ItemType Directory -Force -Path $scriptDir | Out-Null
$selfCopyDst = Join-Path $scriptDir 'Generate-ShortcutStrip.ps1'
if ([System.IO.Path]::GetFullPath($PSCommandPath) -ne [System.IO.Path]::GetFullPath($selfCopyDst)) {
    Copy-Item -LiteralPath $PSCommandPath -Destination $selfCopyDst -Force
}

# 写 Lua 滑片脚本 Slide.lua（UTF-8 无 BOM）
$lua = @'
-- ShortcutStrip：贴哪条边就往哪条边藏（顶边优先于左右）+ 逐帧平滑滑动 + 收起只剩窄条
local tick = 0
local W, H, PEEK, SW, SH

function Initialize()
    W = tonumber(SKIN:GetVariable('SkinW')) or 370
    H = tonumber(SKIN:GetVariable('SkinH')) or 834
    PEEK = tonumber(SKIN:GetVariable('Peek')) or 14
    SW = tonumber(SKIN:GetVariable('ScreenW')) or 2560
    SH = tonumber(SKIN:GetVariable('ScreenH')) or 1440
    curX = nil; curY = nil; tgtX = nil; tgtY = nil
    tick = 0
end

local function clamp(v, lo, hi)
    if v < lo then return lo elseif v > hi then return hi else return v end
end

local function isCollapsedTarget()
    local cx = tonumber(SKIN:GetVariable('ColX'))
    local cy = tonumber(SKIN:GetVariable('ColY'))
    return cx ~= nil and cy ~= nil and math.abs(tgtX - cx) < 1 and math.abs(tgtY - cy) < 1
end

local function finishCollapse()
    SKIN:Bang('!HideMeterGroup', 'Panel')
    SKIN:Bang('!HideMeter', 'mLbl')
    SKIN:Bang('!ShowMeter', 'mHandle')
    SKIN:Bang('!SetVariable', 'Shown', '0')
    SKIN:Bang('!SetVariable', 'Moving', '0')
end

local function finishExpand()
    SKIN:Bang('!SetVariable', 'Shown', '1')
    SKIN:Bang('!SetVariable', 'Moving', '0')
end

function Setup(cx, cy)
    cx = tonumber(cx) or 0
    cy = tonumber(cy) or 0
    local tol = 16
    local dTop  = cy
    local dLeft = cx
    local dRight = SW - (cx + W)
    local edge
    if dTop <= tol then
        edge = 'top'                      -- 顶边优先：顶边与左/右重合（角落）时也走这里
    elseif dLeft <= tol then
        edge = 'left'
    elseif dRight <= tol then
        edge = 'right'
    else
        -- 没有真正贴边：按最近的左/右吸附（竖向条更适合左右贴）
        if math.abs(dLeft) <= math.abs(dRight) then edge = 'left' else edge = 'right' end
    end

    local exX, exY, coX, coY
    if edge == 'top' then
        exX = clamp(math.floor(cx), 0, SW - W); exY = 0
        coX = exX; coY = -(H - PEEK)
        SKIN:Bang('!SetOption', 'mHandle', 'ImageName', '#@#handle-top.png')
        SKIN:Bang('!SetOption', 'mHandle', 'X', '0')
        SKIN:Bang('!SetOption', 'mHandle', 'Y', tostring(H - PEEK))
        SKIN:Bang('!SetOption', 'mHandle', 'W', tostring(W))
        SKIN:Bang('!SetOption', 'mHandle', 'H', tostring(PEEK))
    elseif edge == 'left' then
        exX = 0; exY = clamp(math.floor(cy), 0, SH - H)
        coX = -(W - PEEK); coY = exY
        SKIN:Bang('!SetOption', 'mHandle', 'ImageName', '#@#handle-left.png')
        SKIN:Bang('!SetOption', 'mHandle', 'X', tostring(W - PEEK))
        SKIN:Bang('!SetOption', 'mHandle', 'Y', '0')
        SKIN:Bang('!SetOption', 'mHandle', 'W', tostring(PEEK))
        SKIN:Bang('!SetOption', 'mHandle', 'H', tostring(H))
    else
        exX = SW - W; exY = clamp(math.floor(cy), 0, SH - H)
        coX = SW - PEEK; coY = exY
        SKIN:Bang('!SetOption', 'mHandle', 'ImageName', '#@#handle-right.png')
        SKIN:Bang('!SetOption', 'mHandle', 'X', '0')
        SKIN:Bang('!SetOption', 'mHandle', 'Y', '0')
        SKIN:Bang('!SetOption', 'mHandle', 'W', tostring(PEEK))
        SKIN:Bang('!SetOption', 'mHandle', 'H', tostring(H))
    end

    SKIN:Bang('!SetVariable', 'ExpX', tostring(exX))
    SKIN:Bang('!SetVariable', 'ExpY', tostring(exY))
    SKIN:Bang('!SetVariable', 'ColX', tostring(coX))
    SKIN:Bang('!SetVariable', 'ColY', tostring(coY))
    SKIN:Bang('!SetVariable', 'Edge', edge)
    SKIN:Bang('!UpdateMeter', 'mHandle')
    Jump(coX, coY)
end

local function step(cur, tgt)
    local d = tgt - cur
    if math.abs(d) <= 2 then return tgt end
    return cur + d * 0.28
end

function Update()
    tick = tick + 1
    if curX == nil then return end
    if tgtX == nil then tgtX, tgtY = curX, curY end
    if curX ~= tgtX or curY ~= tgtY then
        curX = step(curX, tgtX)
        curY = step(curY, tgtY)
        SKIN:Bang('!Move', tostring(math.floor(curX + 0.5)), tostring(math.floor(curY + 0.5)))
        if curX == tgtX and curY == tgtY then
            if isCollapsedTarget() then finishCollapse() else finishExpand() end
        end
    end
    -- 用户把面板拖到别处后自动重新贴边（静止时检查实际窗口位置；#CURRENTCONFIGX# 是动态值）
    if tick % 10 == 0 and curX == tgtX and curY == tgtY then
        local ax = tonumber(SKIN:GetVariable('CURRENTCONFIGX'))
        local ay = tonumber(SKIN:GetVariable('CURRENTCONFIGY'))
        if ax and ay and (math.abs(ax - curX) > 6 or math.abs(ay - curY) > 6) then
            Setup(ax, ay)
        end
    end
end

function GoTo(x, y)
    if curX == nil then
        curX = tonumber(SKIN:GetVariable('ColX')) or 0
        curY = tonumber(SKIN:GetVariable('ColY')) or 0
    end
    if x ~= nil then tgtX = tonumber(x) end
    if y ~= nil then tgtY = tonumber(y) end
end

function Jump(x, y)
    cx = tonumber(x) or 0
    cy = tonumber(y) or 0
    curX = cx; curY = cy
    tgtX = cx; tgtY = cy
    SKIN:Bang('!Move', tostring(math.floor(curX + 0.5)), tostring(math.floor(curY + 0.5)))
    if isCollapsedTarget() then finishCollapse() else finishExpand() end
end
'@
$luaPath = Join-Path $scriptDir 'Slide.lua'
[System.IO.File]::WriteAllText($luaPath, $lua, (New-Object System.Text.UTF8Encoding($false)))

"已生成: $iniPath  ($skinW x $skinH, $($items.Count) 个)"
"屏幕: 物理 ${physW}x${physH} @ $appliedDpi dpi → 逻辑 ${logW}x${logH}"
"默认展开位: X=$expX Y=$expY   收起位: X=$colX Y=$colY   窄条厚度: ${peek}px（贴哪条边由皮肤启动时自适应）"
"分类: $($groups.Count) 个"
foreach ($g in $groups) { "  {0,-14} {1} 个，{2} 列 ×{3} 行" -f $g.Title, $g.Items.Count, $g.Cols, $g.PerCol }
