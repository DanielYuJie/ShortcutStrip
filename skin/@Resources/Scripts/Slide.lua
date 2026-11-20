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