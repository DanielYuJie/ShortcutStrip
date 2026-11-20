<#
  Generate-ShortcutDock.ps1  (v2)
  作用：把桌面（当前用户 + 公共桌面）上的所有 .lnk 快捷方式，同步生成一个 Rainmeter 启动面板。
  用法：powershell -NoProfile -ExecutionPolicy Bypass -File .\Generate-ShortcutDock.ps1
  说明：新增/删除桌面快捷方式后，重新运行本脚本即可刷新面板。
  生成物：ShortcutDock.ini + @Resources\{bg,pill,accent}.png + @Resources\Links + @Resources\Icons
#>
param(
    [string]$SkinDir = 'D:\Users\lyj\Documents\Rainmeter\Skins\ShortcutDock'
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing | Out-Null
$shell = New-Object -ComObject WScript.Shell

# ================= 1. 面板显示名（键 = 桌面快捷方式文件名，不含 .lnk） =================
$Rename = @{
    '原神'                             = '米哈游启动器'
    '崩坏：星穹铁道'                   = '米哈游启动器'
    'launcher - 快捷方式'              = '米哈游启动器'
    'March7th Launcher.exe - 快捷方式' = '三月七助手'
    'OneDragon-Launcher.exe'           = 'OneDragon'
    'Plain Craft Launcher 2.exe'       = 'PCL2'
    'Visual Studio Code'               = 'VS Code'
    'Ultimate Vocal Remover'           = 'UVR'
    '图灵完备TuringComplete'           = '图灵完备'
    '嘉立创EDA(专业版)'                = '嘉立创EDA'
    '鸿图对战平台(红警战网)'           = '鸿图对战平台'
    '鸿图对战平台(红警战网)2025'       = '鸿图电竞 2025'
    '2025-2026学年文件'                = '学年文件'
    'Photoshop.exe'                    = 'Photoshop'
    'updream.exe'                      = 'updream'
    'OpenRGB - 快捷方式'               = 'OpenRGB'
    '豆包浏览器'                       = '豆包'
    # ---- 公共桌面 ----
    'SOLIDWORKS 2025'                  = 'SOLIDWORKS'
    'SOLIDWORKS Composer 2025'         = 'SW Composer'
    'SOLIDWORKS Composer Player 2025'  = 'SW Composer Player'
    'SOLIDWORKS Composer Sync 2025'    = 'SW Composer Sync'
    'SOLIDWORKS Electrical'            = 'SW Electrical'
    'SOLIDWORKS Inspection 2025'       = 'SW Inspection'
    'SOLIDWORKS Visualize 2025'        = 'SW Visualize'
    'SOLIDWORKS Visualize Boost 2025'  = 'SW Visualize Boost'
    'eDrawings 2025 x64 Edition'       = 'eDrawings'
    'IntelliJ IDEA 2020.1 x64'         = 'IntelliJ IDEA'
    'PyCharm 2024.1'                   = 'PyCharm'
    'VMware Workstation Pro'           = 'VMware'
    'TechPowerUp GPU-Z'                = 'GPU-Z'
    'PotPlayer 64 bit'                 = 'PotPlayer'
    '分区助手 10.10.0'                 = '分区助手'
    'Epic Games Launcher'              = 'Epic'
}

# ================= 2. 分组（每组一列） =================
$GroupList = [ordered]@{
    '游戏' = @(
        '米哈游启动器', 'PCL2', 'Steam', 'Epic', '鹰角启动器', '明日方舟：终末地', 'BetterGI',
        '三月七助手', 'OneDragon', 'ok-ef', 'gamebox', '雷电模拟器9', '雷电多开器',
        '鸿图对战平台', '鸿图电竞 2025', '图灵完备', 'Paradox Launcher v2', 'UU加速器'
    )
    '开发 / AI' = @(
        'VS Code', 'GitHub Desktop', 'IntelliJ IDEA', 'PyCharm', 'Arduino IDE', '微信开发者工具',
        '嘉立创EDA', 'Comfy Desktop', 'Chatbox', 'Cherry Studio', 'DeepSeek Harness', '扣子',
        'Xiaomi MiMo', '豆包', 'Ninja Client', 'ODE 多功能助手', 'updream', 'LM Studio', 'Zotero', 'VMware'
    )
    '工程 / 工具' = @(
        'SOLIDWORKS', 'SW Composer', 'SW Composer Player', 'SW Composer Sync', 'SW Electrical',
        'SW Inspection', 'SW Visualize', 'SW Visualize Boost', 'eDrawings', 'Bambu Studio',
        '图吧工具箱CE', 'GPU-Z', '分区助手'
    )
    '日常 / 媒体' = @(
        '学年文件', 'Tabbit Browser', '星愿浏览器', '夸克', 'WPS Office', '飞书', '百度网盘', '迅雷',
        '学习通', 'PixPin', '剪映专业版', 'Photoshop', 'Blender 3.6', 'UVR', 'OpenRGB', 'UU远程'
    )
    '聊天 / 娱乐 / 系统' = @(
        'Microsoft Edge', 'QQ', '微信', '元宝', '网易云音乐', '哔哩哔哩', '哔哩哔哩直播姬',
        'PotPlayer', '爱思助手', '互传', '笔吧验机'
    )
}

# ================= 3. 收集桌面快捷方式 =================
$items = New-Object System.Collections.ArrayList
$seen = @{}
$deskDirs = @([Environment]::GetFolderPath('Desktop'), (Join-Path $env:PUBLIC 'Desktop'))

foreach ($dir in $deskDirs) {
    if (-not (Test-Path -LiteralPath $dir)) { continue }
    Get-ChildItem -LiteralPath $dir -Filter '*.lnk' -File -ErrorAction SilentlyContinue | ForEach-Object {
        $lnk = $_
        if ($Rename.ContainsKey($lnk.BaseName)) {
            $label = $Rename[$lnk.BaseName]
        } else {
            $label = ($lnk.BaseName -replace ' - 快捷方式$', '') -replace '\.exe$', ''
        }
        $sc = $shell.CreateShortcut($lnk.FullName)
        $target = $sc.TargetPath
        $key = if ($target) { $target.ToLowerInvariant() } else { $lnk.FullName.ToLowerInvariant() }
        if ($seen.ContainsKey($key)) { return }        # 同一程序多个快捷方式只留一个
        $seen[$key] = $true
        [void]$items.Add([pscustomobject]@{
            Label      = $label
            Original   = $lnk.BaseName
            Target     = $target
            Lnk        = $lnk.FullName
            IconSource = $sc.IconLocation
        })
    }
}

# ================= 4. 分组 =================
$order = @{}
$groupOf = @{}
$i = 0
foreach ($g in $GroupList.Keys) {
    foreach ($n in $GroupList[$g]) { $groupOf[$n] = $g; $order[$n] = $i; $i++ }
}
$buckets = @{}
foreach ($g in $GroupList.Keys) { $buckets[$g] = New-Object System.Collections.ArrayList }
$other = New-Object System.Collections.ArrayList
foreach ($it in $items) {
    if ($groupOf.ContainsKey($it.Label)) { [void]$buckets[$groupOf[$it.Label]].Add($it) }
    else { [void]$other.Add($it) }
}

$cols = @()
foreach ($g in $GroupList.Keys) {
    $cols += @{ Title = $g; Items = @($buckets[$g] | Sort-Object { $order[$_.Label] }) }
}
$cols[$cols.Count - 1].Items = @($cols[$cols.Count - 1].Items) + @($other | Sort-Object Label)

# ================= 5. 复制快捷方式 + 提取图标 =================
$SkinDir  = $SkinDir.TrimEnd('\')
$linksDir = Join-Path $SkinDir '@Resources\Links'
$iconsDir = Join-Path $SkinDir '@Resources\Icons'
Remove-Item -LiteralPath $linksDir, $iconsDir -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force -Path $linksDir, $iconsDir | Out-Null

function Get-IconSource($it) {
    $raw = [string]$it.IconSource
    if ($raw) {
        $p = ($raw -split ',')[0].Trim().Trim('"')
        $p = [Environment]::ExpandEnvironmentVariables($p)
        if ($p -and (Test-Path -LiteralPath $p)) { return $p }
    }
    if ($it.Target -and (Test-Path -LiteralPath $it.Target)) {
        if ($it.Target -match '\.(exe|dll|ico)$') { return $it.Target }
        return 'C:\Windows\explorer.exe'
    }
    return $null
}

$n = 0
foreach ($c in $cols) {
    foreach ($it in $c.Items) {
        $n++
        $id = '{0:D2}' -f $n
        $it | Add-Member -NotePropertyName Id -NotePropertyValue $id -Force
        Copy-Item -LiteralPath $it.Lnk -Destination (Join-Path $linksDir "$id.lnk") -Force
        $src = Get-IconSource $it
        if ($src) {
            try {
                $ico = [System.Drawing.Icon]::ExtractAssociatedIcon($src)
                if ($ico) {
                    $bmp = $ico.ToBitmap()
                    $bmp.Save((Join-Path $iconsDir "I$id.png"), [System.Drawing.Imaging.ImageFormat]::Png)
                    $bmp.Dispose(); $ico.Dispose()
                }
            } catch { }
        }
    }
}

# ================= 6. 版式参数 =================
$padX     = 16    # 左右内边距
$padTop   = 14
$padBot   = 16
$headH    = 46    # 标题区高度
$groupH   = 30    # 分组标题高度
$rowH     = 26
$iconSize = 20
$textOffX = 26
$colW     = 210
$padOut   = 10    # 投影留白

$colX = @(0..($cols.Count - 1) | ForEach-Object { $padX + $padOut + $_ * $colW })
$maxRows = ($cols | ForEach-Object { $_.Items.Count } | Measure-Object -Maximum).Maximum
$skinW = $padX * 2 + $padOut * 2 + $cols.Count * $colW
$skinH = $padTop + $headH + $groupH + $maxRows * $rowH + $padBot + $padOut * 2
$off   = $padOut

# 圆角路径
function New-RoundPath([int]$X, [int]$Y, [int]$W, [int]$H, [int]$Radius) {
    $gp = New-Object System.Drawing.Drawing2D.GraphicsPath
    $d  = [Math]::Min($Radius * 2, [Math]::Min($W, $H) - 1)
    $gp.AddArc($X, $Y, $d, $d, 180, 90)
    $gp.AddArc($X + $W - $d - 1, $Y, $d, $d, 270, 90)
    $gp.AddArc($X + $W - $d - 1, $Y + $H - $d - 1, $d, $d, 0, 90)
    $gp.AddArc($X, $Y + $H - $d - 1, $d, $d, 90, 90)
    $gp.CloseFigure()
    return $gp
}

function New-RoundedPng {
    param([int]$W, [int]$H, [int]$Radius, [int]$R, [int]$G, [int]$B, [int]$A, [string]$Path)
    $bmp = New-Object System.Drawing.Bitmap -ArgumentList $W, $H
    $gr  = [System.Drawing.Graphics]::FromImage($bmp)
    $gr.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $gp  = New-RoundPath 0 0 $W $H $Radius
    $br  = New-Object System.Drawing.SolidBrush -ArgumentList ([System.Drawing.Color]::FromArgb($A, $R, $G, $B))
    $gr.FillPath($br, $gp); $br.Dispose()
    $gr.Dispose(); $gp.Dispose()
    $bmp.Save($Path, [System.Drawing.Imaging.ImageFormat]::Png); $bmp.Dispose()
}

# 卡片：投影 + 垂直渐变 + 1px 描边
function New-PanelBg {
    param([int]$W, [int]$H, [int]$Inset, [string]$Path)
    $bmp = New-Object System.Drawing.Bitmap -ArgumentList $W, $H
    $gr  = [System.Drawing.Graphics]::FromImage($bmp)
    $gr.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    for ($i = 7; $i -ge 1; $i--) {
        $p = New-RoundPath ($Inset - $i) ($Inset - $i) ($W - 2 * ($Inset - $i)) ($H - 2 * ($Inset - $i)) (16 + $i)
        $b = New-Object System.Drawing.SolidBrush -ArgumentList ([System.Drawing.Color]::FromArgb(6, 0, 0, 0))
        $gr.FillPath($b, $p); $b.Dispose(); $p.Dispose()
    }
    $cw = $W - 2 * $Inset
    $ch = $H - 2 * $Inset
    $card = New-RoundPath $Inset $Inset $cw $ch 16
    $rect = New-Object System.Drawing.Rectangle -ArgumentList $Inset, $Inset, $cw, $ch
    $grad = New-Object System.Drawing.Drawing2D.LinearGradientBrush -ArgumentList $rect,
        ([System.Drawing.Color]::FromArgb(255, 24, 27, 35)), ([System.Drawing.Color]::FromArgb(255, 13, 15, 20)), 90
    $gr.FillPath($grad, $card); $grad.Dispose()
    $pen = New-Object System.Drawing.Pen -ArgumentList ([System.Drawing.Color]::FromArgb(190, 80, 88, 106)), 1
    $gr.DrawPath($pen, $card); $pen.Dispose()
    $gr.Dispose(); $card.Dispose()
    $bmp.Save($Path, [System.Drawing.Imaging.ImageFormat]::Png); $bmp.Dispose()
}

$resDir = Join-Path $SkinDir '@Resources'
New-Item -ItemType Directory -Force -Path $resDir | Out-Null
New-PanelBg -W $skinW -H $skinH -Inset $padOut -Path (Join-Path $resDir 'bg.png')
New-RoundedPng -W ($colW - 12) -H ($rowH - 6) -Radius 7 -R 255 -G 255 -B 255 -A 18 -Path (Join-Path $resDir 'pill.png')
New-RoundedPng -W 4 -H 16 -Radius 2 -R 96 -G 180 -B 255 -A 255 -Path (Join-Path $resDir 'accent.png')

# ================= 7. 生成 ShortcutDock.ini =================
$fontFace  = 'Microsoft YaHei UI'
$generated = Get-Date -Format 'yyyy-MM-dd HH:mm'

$sb = New-Object System.Text.StringBuilder
function L { param([string]$s = '') [void]$sb.AppendLine($s) }

L '; =================================================================='
L "; 由 Generate-ShortcutDock.ps1 自动生成（$generated），共 $n 项"
L '; 想改分组/名字：改 @Resources\Scripts\Generate-ShortcutDock.ps1 后重新运行'
L '; =================================================================='
L ''
L '[Rainmeter]'
L 'Update=1000'
L 'AccurateText=1'
L 'DynamicWindowSize=1'
L 'BackgroundMode=1'
L ''
L '[Metadata]'
L 'Name=ShortcutDock'
L "Author=$env:USERNAME"
L 'Version=2.0'
L 'Information=桌面快捷方式启动面板（脚本自动生成）。右键 -> 编辑皮肤 可手动微调；重新生成运行 @Resources\Scripts\Generate-ShortcutDock.ps1'
L ''
L '[Variables]'
L "FontFace=$fontFace"
L 'FontSize=9.5'
L 'TextColor=222,226,234,255'
L 'HoverColor=255,255,255,255'
L 'AccentColor=96,180,255,255'
L 'MutedColor=138,146,162,255'
L ''
L '; ---------------- 背景 ----------------'
L '[mBg]'
L 'Meter=Image'
L 'ImageName=#@#bg.png'
L 'X=0'
L 'Y=0'
L ''
L '; ---------------- 标题 ----------------'
L '[mAccent]'
L 'Meter=Image'
L "ImageName=#@#accent.png"
L "X=$($padX + $off)"
L "Y=$($padTop + $off + 3)"
L ''
L '[mTitle]'
L 'Meter=String'
L 'Text=快捷方式'
L "X=$($padX + $off + 12)"
L "Y=$($padTop + $off)"
L 'FontFace=#FontFace#'
L 'FontSize=13'
L 'FontWeight=600'
L 'FontColor=#TextColor#'
L 'AntiAlias=1'
L ''
L '[mSub]'
L 'Meter=String'
L "Text=共 $n 项 · 自动同步自桌面"
L "X=$($padX + $off)"
L "Y=$($padTop + $off + 21)"
L 'FontFace=#FontFace#'
L 'FontSize=8'
L 'FontColor=#MutedColor#'
L 'AntiAlias=1'
L ''

$m = 0
for ($ci = 0; $ci -lt $cols.Count; $ci++) {
    $x = $colX[$ci]
    $y = $padTop + $headH + $padOut
    $title = $cols[$ci].Title
    $m++
    L "; ---------------- $title ----------------"
    L "[mG$m]"
    L 'Meter=String'
    L "Text=$title"
    L "X=$x"
    L "Y=$y"
    L 'FontFace=#FontFace#'
    L 'FontSize=10'
    L 'FontWeight=600'
    L 'FontColor=#AccentColor#'
    L 'AntiAlias=1'
    L ''
    $y += $groupH

    foreach ($it in $cols[$ci].Items) {
        $m++
        $txt = [string]$it.Label
        if ($txt.Length -gt 19) { $txt = $txt.Substring(0, 18) + '…' }
        $action = '["#@#Links\' + $it.Id + '.lnk"]'
        $mOn  = '[!ShowMeter mP{0}][!SetOption mT{0} FontColor "#HoverColor#"][!UpdateMeter mT{0}][!Redraw]' -f $m
        $mOff = '[!HideMeter mP{0}][!SetOption mT{0} FontColor "#TextColor#"][!UpdateMeter mT{0}][!Redraw]' -f $m

        # 悬停胶囊（默认隐藏）
        L "[mP$m]"
        L 'Meter=Image'
        L 'ImageName=#@#pill.png'
        L "X=$($x + 4)"
        L "Y=$($y + 3)"
        L "W=$($colW - 12)"
        L "H=$($rowH - 6)"
        L 'Hidden=1'
        L "LeftMouseUpAction=$action"
        L "MouseOverAction=$mOn"
        L "MouseLeaveAction=$mOff"
        L ''
        # 图标
        L "[mI$m]"
        L 'Meter=Image'
        L "ImageName=#@#Icons\I$($it.Id).png"
        L "X=$x"
        L "Y=$($y + 3)"
        L "W=$iconSize"
        L "H=$iconSize"
        L "LeftMouseUpAction=$action"
        L "ToolTipText=$($it.Original)"
        L "MouseOverAction=$mOn"
        L "MouseLeaveAction=$mOff"
        L ''
        # 文字
        L "[mT$m]"
        L 'Meter=String'
        L "Text=$txt"
        L "X=$($x + $textOffX)"
        L "Y=$($y + 6)"
        L 'FontFace=#FontFace#'
        L 'FontSize=#FontSize#'
        L 'FontColor=#TextColor#'
        L 'AntiAlias=1'
        L "LeftMouseUpAction=$action"
        L "ToolTipText=$($it.Original)"
        L "MouseOverAction=$mOn"
        L "MouseLeaveAction=$mOff"
        L ''
        $y += $rowH
    }
}

$iniPath = Join-Path $SkinDir 'ShortcutDock.ini'
$enc = New-Object System.Text.UnicodeEncoding($false, $true)   # UTF-16 LE + BOM
[System.IO.File]::WriteAllText($iniPath, $sb.ToString(), $enc)

# ================= 8. 脚本自身复制到皮肤目录 =================
$scriptDir = Join-Path $SkinDir '@Resources\Scripts'
New-Item -ItemType Directory -Force -Path $scriptDir | Out-Null
if ($PSCommandPath -and (Test-Path -LiteralPath $PSCommandPath)) {
    $selfCopyDst = Join-Path $scriptDir 'Generate-ShortcutDock.ps1'
    $selfCopySrc = [System.IO.Path]::GetFullPath($PSCommandPath)
    if ($selfCopySrc -ne [System.IO.Path]::GetFullPath($selfCopyDst)) {
        Copy-Item -LiteralPath $selfCopySrc -Destination $selfCopyDst -Force
    }
}

"已生成: $iniPath  ($skinW x $skinH, $n 项)"
"快捷方式副本: $linksDir"
"图标: $iconsDir"
