-- AuroraLib (纯 UI 组件库，无任何功能逻辑)
local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local AuroraLib = {}
AuroraLib.__index = AuroraLib

local THEME = {
    Bg = Color3.fromRGB(25, 25, 45),
    Sidebar = Color3.fromRGB(20, 20, 35),
    Card = Color3.fromRGB(35, 35, 60),
    Accent = Color3.fromRGB(124, 108, 255),
    Off = Color3.fromRGB(70, 70, 70),
    Text = Color3.new(1, 1, 1),
}

local function corner(p, r) local c = Instance.new("UICorner", p) c.CornerRadius = UDim.new(0, r) return c end

local function makeDraggable(frame, handle, onClick)
    handle = handle or frame
    local dragging, dragStart, startPos, moved = false, nil, nil, false
    handle.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            dragging, moved = true, false
            dragStart, startPos = i.Position, frame.Position
        end
    end)
    UIS.InputChanged:Connect(function(i)
        if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
            local d = i.Position - dragStart
            if d.Magnitude > 4 then moved = true end
            frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
        end
    end)
    UIS.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            if dragging and not moved and onClick then onClick() end
            dragging = false
        end
    end)
end

-- ========== 创建窗口 ==========
function AuroraLib:CreateWindow(titleText)
    local gui = Instance.new("ScreenGui")
    gui.Name = "AuroraX"
    gui.ResetOnSpawn = false
    gui.IgnoreGuiInset = true
    gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

    local main = Instance.new("Frame")
    main.Parent = gui
    main.Size = UDim2.fromOffset(580, 360)
    main.AnchorPoint = Vector2.new(.5, .5)
    main.Position = UDim2.fromScale(.5, .5)
    main.BackgroundColor3 = THEME.Bg
    main.Active = true
    corner(main, 18)
    local stroke = Instance.new("UIStroke", main)
    stroke.Color = THEME.Accent; stroke.Thickness = 1.5

    local topBar = Instance.new("Frame")
    topBar.Parent = main
    topBar.Size = UDim2.new(1, 0, 0, 45)
    topBar.BackgroundTransparency = 1

    local title = Instance.new("TextLabel")
    title.Parent = topBar
    title.BackgroundTransparency = 1
    title.Position = UDim2.new(0, 15, 0, 0)
    title.Size = UDim2.new(0, 200, 1, 0)
    title.Text = titleText or "Aurora X"
    title.Font = Enum.Font.GothamBold
    title.TextSize = 22
    title.TextColor3 = THEME.Text
    title.TextXAlignment = Enum.TextXAlignment.Left

    local closeBtn = Instance.new("TextButton")
    closeBtn.Parent = topBar
    closeBtn.Size = UDim2.fromOffset(28, 28)
    closeBtn.Position = UDim2.new(1, -38, .5, -14)
    closeBtn.Text = "−"
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.TextSize = 16
    closeBtn.TextColor3 = THEME.Text
    closeBtn.BackgroundColor3 = THEME.Accent
    corner(closeBtn, 14)

    local openBtn = Instance.new("TextButton")
    openBtn.Parent = gui
    openBtn.Size = UDim2.fromOffset(45, 45)
    openBtn.Position = UDim2.new(0, 20, 0, 20)
    openBtn.BackgroundColor3 = THEME.Accent
    openBtn.Text = "⚙"
    openBtn.Font = Enum.Font.GothamBold
    openBtn.TextSize = 22
    openBtn.TextColor3 = THEME.Text
    openBtn.Visible = false
    openBtn.Active = true
    openBtn.AutoButtonColor = false
    corner(openBtn, 12)

    local collapsed, origPos = false, main.Position
    local function toggleUI()
        collapsed = not collapsed
        if collapsed then
            origPos = main.Position
            main:TweenPosition(UDim2.new(.5, 0, -0.5, 0), "Out", "Quad", 0.3, true)
            task.wait(0.3)
            main.Visible = false; openBtn.Visible = true
        else
            main.Visible = true; openBtn.Visible = false
            main:TweenPosition(origPos, "Out", "Quad", 0.3, true)
        end
    end
    closeBtn.MouseButton1Click:Connect(toggleUI)
    makeDraggable(openBtn, openBtn, toggleUI)
    makeDraggable(main, topBar)

    local sidebar = Instance.new("Frame")
    sidebar.Parent = main
    sidebar.Position = UDim2.new(0, 0, 0, 45)
    sidebar.Size = UDim2.new(0, 70, 1, -45)
    sidebar.BackgroundColor3 = THEME.Sidebar
    corner(sidebar, 18)

    local content = Instance.new("Frame")
    content.Parent = main
    content.Position = UDim2.new(0, 80, 0, 55)
    content.Size = UDim2.new(1, -90, 1, -65)
    content.BackgroundTransparency = 1

    local window = setmetatable({
        _gui = gui, _main = main, _sidebar = sidebar,
        _content = content, _tabs = {}, _navY = 15, _title = title,
    }, {__index = AuroraLib})
    return window
end

-- ========== 创建标签页 ==========
function AuroraLib:CreateTab(icon)
    local page = Instance.new("ScrollingFrame")
    page.Parent = self._content
    page.Size = UDim2.fromScale(1, 1)
    page.BackgroundTransparency = 1
    page.ScrollBarThickness = 4
    page.CanvasSize = UDim2.new()
    page.AutomaticCanvasSize = Enum.AutomaticSize.Y
    page.Visible = (#self._tabs == 0)

    local layout = Instance.new("UIListLayout", page)
    layout.Padding = UDim.new(0, 8)
    layout.SortOrder = Enum.SortOrder.LayoutOrder

    local btn = Instance.new("TextButton")
    btn.Parent = self._sidebar
    btn.Size = UDim2.new(1, -10, 0, 45)
    btn.Position = UDim2.new(0, 5, 0, self._navY)
    btn.Text = icon or "•"
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 16
    btn.TextColor3 = THEME.Text
    btn.BackgroundColor3 = (#self._tabs == 0) and THEME.Accent or Color3.fromRGB(35, 35, 55)
    corner(btn, 12)
    self._navY = self._navY + 55

    local tabs = self._tabs
    btn.MouseButton1Click:Connect(function()
        for _, t in ipairs(tabs) do
            t.page.Visible = false
            TweenService:Create(t.btn, TweenInfo.new(.15), {BackgroundColor3 = Color3.fromRGB(35, 35, 55)}):Play()
        end
        page.Visible = true
        TweenService:Create(btn, TweenInfo.new(.15), {BackgroundColor3 = THEME.Accent}):Play()
    end)

    local tab = setmetatable({page = page, btn = btn}, {__index = AuroraLib})
    table.insert(tabs, tab)
    return tab
end

-- ========== 标题 ==========
function AuroraLib:AddLabel(text)
    local l = Instance.new("TextLabel")
    l.Parent = self.page
    l.Size = UDim2.new(1, 0, 0, 30)
    l.BackgroundTransparency = 1
    l.Text = text
    l.Font = Enum.Font.GothamBold
    l.TextSize = 16
    l.TextColor3 = THEME.Text
    return self
end

-- ========== 按钮 ==========
function AuroraLib:AddButton(text, callback)
    callback = callback or function() end
    local btn = Instance.new("TextButton")
    btn.Parent = self.page
    btn.Size = UDim2.new(1, 0, 0, 34)
    btn.BackgroundColor3 = THEME.Accent
    btn.Text = text
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 14
    btn.TextColor3 = THEME.Text
    btn.AutoButtonColor = false
    corner(btn, 8)
    btn.MouseEnter:Connect(function()
        TweenService:Create(btn, TweenInfo.new(.15), {BackgroundColor3 = Color3.fromRGB(140, 125, 255)}):Play()
    end)
    btn.MouseLeave:Connect(function()
        TweenService:Create(btn, TweenInfo.new(.15), {BackgroundColor3 = THEME.Accent}):Play()
    end)
    btn.MouseButton1Click:Connect(callback)
    return self
end

-- ========== 开关 ==========
function AuroraLib:AddToggle(text, callback)
    callback = callback or function() end
    local state = false
    local holder = Instance.new("Frame")
    holder.Parent = self.page
    holder.Size = UDim2.new(1, 0, 0, 30)
    holder.BackgroundTransparency = 1

    local label = Instance.new("TextLabel")
    label.Parent = holder
    label.BackgroundTransparency = 1
    label.Size = UDim2.new(1, -60, 1, 0)
    label.Text = text
    label.TextColor3 = THEME.Text
    label.Font = Enum.Font.Gotham
    label.TextSize = 14
    label.TextXAlignment = Enum.TextXAlignment.Left

    local toggle = Instance.new("TextButton")
    toggle.Parent = holder
    toggle.Size = UDim2.fromOffset(45, 20)
    toggle.Position = UDim2.new(1, -50, .5, -10)
    toggle.Text = ""
    toggle.BackgroundColor3 = THEME.Off
    corner(toggle, 10)

    local dot = Instance.new("Frame")
    dot.Parent = toggle
    dot.Size = UDim2.fromOffset(14, 14)
    dot.Position = UDim2.new(0, 3, .5, -7)
    dot.BackgroundColor3 = THEME.Text
    corner(dot, 7)

    toggle.MouseButton1Click:Connect(function()
        state = not state
        callback(state)
        TweenService:Create(toggle, TweenInfo.new(.2), {BackgroundColor3 = state and THEME.Accent or THEME.Off}):Play()
        TweenService:Create(dot, TweenInfo.new(.2), {Position = state and UDim2.new(1, -17, .5, -7) or UDim2.new(0, 3, .5, -7)}):Play()
    end)
    return self
end

-- ========== 拖动条 ==========
function AuroraLib:AddSlider(text, min, max, default, callback)
    callback = callback or function() end
    local holder = Instance.new("Frame")
    holder.Parent = self.page
    holder.Size = UDim2.new(1, 0, 0, 45)
    holder.BackgroundTransparency = 1

    local label = Instance.new("TextLabel")
    label.Parent = holder
    label.BackgroundTransparency = 1
    label.Size = UDim2.new(1, -50, 0, 20)
    label.Text = text
    label.TextColor3 = THEME.Text
    label.Font = Enum.Font.Gotham
    label.TextSize = 13
    label.TextXAlignment = Enum.TextXAlignment.Left

    local valueLabel = Instance.new("TextLabel")
    valueLabel.Parent = holder
    valueLabel.BackgroundTransparency = 1
    valueLabel.Position = UDim2.new(1, -45, 0, 0)
    valueLabel.Size = UDim2.new(0, 45, 0, 20)
    valueLabel.Text = tostring(default)
    valueLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
    valueLabel.Font = Enum.Font.Code
    valueLabel.TextSize = 12
    valueLabel.TextXAlignment = Enum.TextXAlignment.Right

    local bar = Instance.new("TextButton")
    bar.Parent = holder
    bar.Size = UDim2.new(1, 0, 0, 6)
    bar.Position = UDim2.new(0, 0, 0, 26)
    bar.BackgroundColor3 = Color3.fromRGB(60, 60, 80)
    bar.Text = ""
    bar.AutoButtonColor = false
    corner(bar, 3)

    local progress = Instance.new("Frame")
    progress.Parent = bar
    progress.Size = UDim2.fromScale((default - min) / (max - min), 1)
    progress.BackgroundColor3 = THEME.Accent
    corner(progress, 3)

    local knob = Instance.new("Frame")
    knob.Parent = progress
    knob.Size = UDim2.fromOffset(14, 14)
    knob.AnchorPoint = Vector2.new(.5, .5)
    knob.Position = UDim2.fromScale(1, .5)
    knob.BackgroundColor3 = THEME.Text
    corner(knob, 7)

    local dragging = false
    local function update(input)
        local p = math.clamp((input.Position.X - bar.AbsolutePosition.X) / bar.AbsoluteSize.X, 0, 1)
        local v = math.floor(min + (max - min) * p)
        valueLabel.Text = tostring(v)
        progress.Size = UDim2.fromScale(p, 1)
        callback(v)
    end
    bar.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            dragging = true; update(i)
        end
    end)
    UIS.InputChanged:Connect(function(i)
        if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then update(i) end
    end)
    UIS.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then dragging = false end
    end)
    return self
end

-- ========== 复选框 (已优化：更大、对勾、动画、整行悬停) ==========
function AuroraLib:AddCheckbox(text, callback)
    callback = callback or function() end
    local checked = false

    local holder = Instance.new("TextButton")  -- 整行可点击
    holder.Parent = self.page
    holder.Size = UDim2.new(1, 0, 0, 36)
    holder.BackgroundColor3 = Color3.fromRGB(40, 40, 62)
    holder.AutoButtonColor = false
    holder.Text = ""
    corner(holder, 10)

    local box = Instance.new("Frame")
    box.Parent = holder
    box.Size = UDim2.fromOffset(24, 24)            -- 比原来的 16 更大
    box.Position = UDim2.new(0, 8, .5, -12)
    box.BackgroundColor3 = Color3.fromRGB(50, 50, 72)
    corner(box, 7)
    local bs = Instance.new("UIStroke", box)
    bs.Color = Color3.fromRGB(100, 100, 130)
    bs.Thickness = 1.5

    local tick = Instance.new("TextLabel")        -- 用对勾代替小方块
    tick.Parent = box
    tick.Size = UDim2.fromScale(1, 1)
    tick.BackgroundTransparency = 1
    tick.Text = "✓"
    tick.Font = Enum.Font.GothamBold
    tick.TextSize = 16
    tick.TextColor3 = THEME.Text
    tick.TextTransparency = 1                       -- 默认隐藏

    local label = Instance.new("TextLabel")
    label.Parent = holder
    label.BackgroundTransparency = 1
    label.Position = UDim2.new(0, 42, 0, 0)
    label.Size = UDim2.new(1, -50, 1, 0)
    label.Text = text
    label.TextColor3 = THEME.Text
    label.Font = Enum.Font.Gotham
    label.TextSize = 14
    label.TextXAlignment = Enum.TextXAlignment.Left

    local function setVisual()
        local goalBox = checked and THEME.Accent or Color3.fromRGB(50, 50, 72)
        local goalStroke = checked and THEME.Accent or Color3.fromRGB(100, 100, 130)
        TweenService:Create(box, TweenInfo.new(.18), {BackgroundColor3 = goalBox}):Play()
        TweenService:Create(bs, TweenInfo.new(.18), {Color = goalStroke}):Play()
        TweenService:Create(tick, TweenInfo.new(.18), {TextTransparency = checked and 0 or 1}):Play()
        -- 勾选时小弹一下
        if checked then
            box.Size = UDim2.fromOffset(20, 20)
            TweenService:Create(box, TweenInfo.new(.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
                {Size = UDim2.fromOffset(24, 24)}):Play()
        end
    end

    holder.MouseEnter:Connect(function()
        TweenService:Create(holder, TweenInfo.new(.15), {BackgroundColor3 = Color3.fromRGB(48, 48, 72)}):Play()
    end)
    holder.MouseLeave:Connect(function()
        TweenService:Create(holder, TweenInfo.new(.15), {BackgroundColor3 = Color3.fromRGB(40, 40, 62)}):Play()
    end)
    holder.MouseButton1Click:Connect(function()
        checked = not checked
        setVisual()
        callback(checked)
    end)
    return self
end

-- ========== 输入框 ==========
function AuroraLib:AddInput(placeholder, callback)
    callback = callback or function() end
    local box = Instance.new("TextBox")
    box.Parent = self.page
    box.Size = UDim2.new(1, 0, 0, 32)
    box.BackgroundColor3 = Color3.fromRGB(50, 50, 70)
    box.PlaceholderText = placeholder
    box.Text = ""
    box.Font = Enum.Font.Gotham
    box.TextSize = 13
    box.TextColor3 = THEME.Text
    box.ClearTextOnFocus = false
    corner(box, 8)
    local pad = Instance.new("UIPadding", box)
    pad.PaddingLeft = UDim.new(0, 10)
    box.FocusLost:Connect(function() callback(box.Text) end)
    return self
end

-- ========== 手风琴折叠 ==========
function AuroraLib:AddAccordion(title, buildFn)
    local header = Instance.new("TextButton")
    header.Parent = self.page
    header.Size = UDim2.new(1, 0, 0, 32)
    header.BackgroundColor3 = Color3.fromRGB(50, 50, 75)
    header.Text = "  ▶  " .. title
    header.TextXAlignment = Enum.TextXAlignment.Left
    header.Font = Enum.Font.GothamBold
    header.TextSize = 13
    header.TextColor3 = THEME.Text
    header.AutoButtonColor = false
    corner(header, 8)

    local body = Instance.new("Frame")
    body.Parent = self.page
    body.Size = UDim2.new(1, 0, 0, 0)
    body.BackgroundColor3 = Color3.fromRGB(40, 40, 60)
    body.ClipsDescendants = true
    corner(body, 8)

    local bl = Instance.new("UIListLayout", body)
    bl.Padding = UDim.new(0, 6)
    local pad = Instance.new("UIPadding", body)
    pad.PaddingTop = UDim.new(0, 6); pad.PaddingBottom = UDim.new(0, 6)
    pad.PaddingLeft = UDim.new(0, 8); pad.PaddingRight = UDim.new(0, 8)

    local sub = setmetatable({page = body}, {__index = AuroraLib})
    if buildFn then buildFn(sub) end

    local open = false
    header.MouseButton1Click:Connect(function()
        open = not open
        header.Text = (open and "  ▼  " or "  ▶  ") .. title
        local target = open and (bl.AbsoluteContentSize.Y + 12) or 0
        TweenService:Create(body, TweenInfo.new(.2), {Size = UDim2.new(1, 0, 0, target)}):Play()
    end)
    return self
end

return AuroraLib
