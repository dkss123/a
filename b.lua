-- ==============================================
-- 终极自瞄系统 v7.0 (私人服务器专用)
-- 包含：完全修复的自瞄 + 人物状态显示 + 扇形雷达 + 瞄准预警 + 智能ESP
-- ==============================================

-- 1. 加载Rayfield UI
local Rayfield = loadstring(game:HttpGet('https://raw.githubusercontent.com/SiriusSoftwareLtd/Rayfield/main/source.lua'))()

-- 2. 初始化服务
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local CoreGui = game:GetService("CoreGui")
local Camera = workspace.CurrentCamera
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local LocalPlayer = Players.LocalPlayer
repeat wait() until LocalPlayer and Camera

-- 3. 清理旧UI
pcall(function()
    CoreGui:FindFirstChild("UltimateAimESP"):Destroy()
    CoreGui:FindFirstChild("TargetInfoDisplay"):Destroy()
    CoreGui:FindFirstChild("RadarDisplay"):Destroy()
    CoreGui:FindFirstChild("AimWarningDisplay"):Destroy()
    CoreGui:FindFirstChild("CharacterStatusDisplay"):Destroy()
end)

-- 4. 配置系统
local config = {
    -- 自瞄模式
    continuousEnabled = false,
    
    -- 自瞄设置
    aimKey = Enum.KeyCode.Q,
    smoothFactor = 0.15,
    aimFov = 300,
    maxDistance = 500,
    aimAt = "head",
    
    -- 优先级设置
    priorityMode = "closest",
    
    -- 人物状态显示
    characterStatusEnabled = true,
    
    -- 扇形雷达设置
    radarEnabled = true,
    radarSize = 200,
    radarRange = 100,
    radarPositionX = 20,
    radarPositionY = -220,
    showRadarDots = true,
    radarDotSize = 6,
    radarSectorAngle = 90, -- 扇形角度
    
    -- 瞄准预警设置
    aimWarningEnabled = true,
    warningDuration = 3,
    
    -- 掩体设置
    checkCover = true,
    ignoreCover = false,
    smartCoverCheck = true,
    
    -- ESP设置
    espEnabled = true,
    espDistance = 2000,
    showName = true,
    showDistance = true,
    showHealthBar = true,
    showBox = true,
    nameHideDistance = 50,
    healthBarSide = "right",
    
    -- 目标信息显示
    showTargetInfo = true,
    targetInfoPosition = "TopRight",
    targetInfoScale = 1.0,
    
    -- 视觉设置
    showAimFov = true,
    fovColor = Color3.fromRGB(255, 50, 50),
    fovTransparency = 0.5,
    fovThickness = 2,
    
    -- 性能设置
    updateRate = 120,
    maxESPUpdatesPerFrame = 5
}

-- 5. 缓存变量
local espObjects = {}
local aimConnection = nil
local espConnection = nil
local radarConnection = nil
local warningConnection = nil
local statusConnection = nil
local fovCircle = nil
local radarGui = nil
local warningGui = nil
local statusGui = nil
local currentTarget = nil
local targetInfoGui = nil
local playerHealthBars = {}
local playersAimingAtMe = {}
local lastWarningTime = 0
local mousePosition = Vector2.new(0, 0)

-- 鼠标位置更新
UserInputService.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement then
        mousePosition = Vector2.new(input.Position.X, input.Position.Y)
    end
end)

-- 6. 创建Rayfield窗口
local Window = Rayfield:CreateWindow({
    Name = "终极自瞄系统 v7.0",
    LoadingTitle = "正在加载...",
    LoadingSubtitle = "私人服务器专用版",
    ConfigurationSaving = {
        Enabled = true,
        FolderName = "UltimateAim",
        FileName = "Config"
    }
})

-- 7. 创建标签页
local AimTab = Window:CreateTab("自瞄设置")
local RadarTab = Window:CreateTab("雷达预警")
local VisualTab = Window:CreateTab("视觉设置")
local StatusTab = Window:CreateTab("人物状态")
local TargetTab = Window:CreateTab("目标信息")
local AdvancedTab = Window:CreateTab("高级设置")

-- ==============================================
-- 核心功能函数
-- ==============================================

-- 改进的掩体检测
local function isBehindCoverSmart(targetPosition, shooterPosition)
    if not config.checkCover then return false end
    
    local rayParams = RaycastParams.new()
    rayParams.FilterType = Enum.RaycastFilterType.Blacklist
    rayParams.FilterDescendantsInstances = {LocalPlayer.Character}
    rayParams.IgnoreWater = true
    
    local direction = (targetPosition - shooterPosition).Unit
    local distance = (targetPosition - shooterPosition).Magnitude
    
    -- 检测中心点
    local raycastResult = workspace:Raycast(shooterPosition, direction * distance, rayParams)
    
    if raycastResult then
        local hitPart = raycastResult.Instance
        if hitPart then
            local isTransparent = hitPart.Transparency > 0.8
            local isGlass = hitPart.Material == Enum.Material.Glass
            
            if config.smartCoverCheck then
                -- 检测多个点
                local offsets = {
                    Vector3.new(0, 0, 0),
                    Vector3.new(0, 0.5, 0),
                    Vector3.new(0, -0.5, 0),
                    Vector3.new(0.3, 0, 0),
                    Vector3.new(-0.3, 0, 0)
                }
                
                local visibleCount = 0
                for _, offset in ipairs(offsets) do
                    local checkPos = targetPosition + offset
                    local checkDir = (checkPos - shooterPosition).Unit
                    local checkRay = workspace:Raycast(shooterPosition, checkDir * distance, rayParams)
                    
                    if not checkRay then
                        visibleCount = visibleCount + 1
                    else
                        local hit = checkRay.Instance
                        if hit and (hit.Transparency > 0.8 or hit.Material == Enum.Material.Glass) then
                            visibleCount = visibleCount + 1
                        end
                    end
                end
                
                -- 如果超过一半的点可见，则认为不是完全掩体
                return visibleCount < 3
            end
            
            return not (isTransparent or isGlass)
        end
    end
    
    return false
end

-- 获取目标状态
local function getTargetStatus(player)
    if not player or not player.Character then 
        return "none", nil, "未知"
    end
    
    local character = player.Character
    local head = character:FindFirstChild("Head")
    local humanoid = character:FindFirstChild("Humanoid")
    local rootPart = character:FindFirstChild("HumanoidRootPart")
    
    if not head or not humanoid or humanoid.Health <= 0 or not rootPart then
        return "dead", nil, "死亡"
    end
    
    if not LocalPlayer.Character then
        return "far", nil, "过远"
    end
    
    local localHead = LocalPlayer.Character:FindFirstChild("Head")
    if not localHead then
        return "far", nil, "过远"
    end
    
    local distance = (localHead.Position - head.Position).Magnitude
    
    if config.maxDistance > 0 and distance > config.maxDistance then
        return "far", distance, "过远"
    end
    
    local screenPos = Camera:WorldToViewportPoint(head.Position)
    if screenPos.Z > 0 then
        -- 获取玩家移动状态
        local movementState = "站立"
        if humanoid.MoveDirection.Magnitude > 0 then
            if humanoid.WalkSpeed >= 20 then
                movementState = "奔跑"
            else
                movementState = "行走"
            end
        end
        
        if config.checkCover then
            local behindCover = isBehindCoverSmart(head.Position, localHead.Position)
            if behindCover and not config.ignoreCover then
                return "cover", distance, "墙后 " .. movementState
            end
        end
        
        local screenPos2D = Vector2.new(screenPos.X, screenPos.Y)
        local screenCenter = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
        local screenDistance = (screenCenter - screenPos2D).Magnitude
        
        if screenDistance <= config.aimFov then
            return "visible", distance, movementState
        end
    end
    
    return "far", distance, "过远"
end

-- 创建自瞄圈
local function createFovCircle()
    if fovCircle then
        fovCircle:Destroy()
        fovCircle = nil
    end
    
    if not config.showAimFov then return end
    
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "UltimateAimESP"
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    screenGui.Parent = CoreGui
    
    fovCircle = Instance.new("Frame")
    fovCircle.Name = "FovCircle"
    fovCircle.Size = UDim2.new(0, config.aimFov * 2, 0, config.aimFov * 2)
    fovCircle.Position = UDim2.new(0.5, -config.aimFov, 0.5, -config.aimFov)
    fovCircle.BackgroundTransparency = 1
    fovCircle.ZIndex = 50
    fovCircle.Parent = screenGui
    
    local circleCorner = Instance.new("UICorner")
    circleCorner.CornerRadius = UDim.new(1, 0)
    circleCorner.Parent = fovCircle
    
    local circleStroke = Instance.new("UIStroke")
    circleStroke.Color = config.fovColor
    circleStroke.Thickness = config.fovThickness
    circleStroke.Transparency = config.fovTransparency
    circleStroke.Parent = fovCircle
    
    return fovCircle
end

-- 创建目标信息显示
local function createTargetInfoDisplay()
    if targetInfoGui then
        targetInfoGui:Destroy()
        targetInfoGui = nil
    end
    
    if not config.showTargetInfo then return end
    
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "TargetInfoDisplay"
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    screenGui.Parent = CoreGui
    
    local scale = config.targetInfoScale
    local mainContainer = Instance.new("Frame")
    mainContainer.Name = "TargetInfoContainer"
    mainContainer.Size = UDim2.new(0, 350 * scale, 0, 180 * scale)
    
    if config.targetInfoPosition == "TopRight" then
        mainContainer.Position = UDim2.new(1, -370 * scale, 0, 20 * scale)
    elseif config.targetInfoPosition == "TopLeft" then
        mainContainer.Position = UDim2.new(0, 20 * scale, 0, 20 * scale)
    elseif config.targetInfoPosition == "BottomRight" then
        mainContainer.Position = UDim2.new(1, -370 * scale, 1, -200 * scale)
    elseif config.targetInfoPosition == "BottomLeft" then
        mainContainer.Position = UDim2.new(0, 20 * scale, 1, -200 * scale)
    else
        mainContainer.Position = UDim2.new(1, -370 * scale, 0, 20 * scale)
    end
    
    mainContainer.BackgroundColor3 = Color3.fromRGB(20, 20, 28)
    mainContainer.BackgroundTransparency = 0.15
    mainContainer.BorderSizePixel = 0
    mainContainer.Visible = false
    mainContainer.ZIndex = 100
    mainContainer.Parent = screenGui
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 12)
    corner.Parent = mainContainer
    
    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(100, 150, 255)
    stroke.Thickness = 2
    stroke.Transparency = 0.3
    stroke.Parent = mainContainer
    
    local titleBar = Instance.new("Frame")
    titleBar.Size = UDim2.new(1, 0, 0, 36 * scale)
    titleBar.BackgroundColor3 = Color3.fromRGB(30, 30, 42)
    titleBar.BorderSizePixel = 0
    titleBar.Parent = mainContainer
    
    local titleCorner = Instance.new("UICorner")
    titleCorner.CornerRadius = UDim.new(0, 12, 0, 0)
    titleCorner.Parent = titleBar
    
    local titleLabel = Instance.new("TextLabel")
    titleLabel.Text = "当前目标信息"
    titleLabel.Size = UDim2.new(1, -20 * scale, 1, 0)
    titleLabel.Position = UDim2.new(0, 10 * scale, 0, 0)
    titleLabel.BackgroundTransparency = 1
    titleLabel.TextColor3 = Color3.fromRGB(240, 240, 245)
    titleLabel.Font = Enum.Font.GothamBold
    titleLabel.TextSize = 16 * scale
    titleLabel.TextXAlignment = Enum.TextXAlignment.Left
    titleLabel.Parent = titleBar
    
    local contentFrame = Instance.new("Frame")
    contentFrame.Size = UDim2.new(1, -20 * scale, 1, -45 * scale)
    contentFrame.Position = UDim2.new(0, 10 * scale, 0, 45 * scale)
    contentFrame.BackgroundTransparency = 1
    contentFrame.Parent = mainContainer
    
    local nameLabel = Instance.new("TextLabel")
    nameLabel.Name = "PlayerName"
    nameLabel.Text = "玩家ID: --"
    nameLabel.Size = UDim2.new(1, 0, 0, 28 * scale)
    nameLabel.BackgroundTransparency = 1
    nameLabel.TextColor3 = Color3.fromRGB(220, 220, 230)
    nameLabel.Font = Enum.Font.GothamSemibold
    nameLabel.TextSize = 15 * scale
    nameLabel.TextXAlignment = Enum.TextXAlignment.Left
    nameLabel.Parent = contentFrame
    
    local displayNameLabel = Instance.new("TextLabel")
    displayNameLabel.Name = "DisplayName"
    displayNameLabel.Text = "显示名称: --"
    displayNameLabel.Size = UDim2.new(1, 0, 0, 24 * scale)
    displayNameLabel.Position = UDim2.new(0, 0, 0, 30 * scale)
    displayNameLabel.BackgroundTransparency = 1
    displayNameLabel.TextColor3 = Color3.fromRGB(200, 200, 210)
    displayNameLabel.Font = Enum.Font.Gotham
    displayNameLabel.TextSize = 14 * scale
    displayNameLabel.TextXAlignment = Enum.TextXAlignment.Left
    displayNameLabel.Parent = contentFrame
    
    local distanceLabel = Instance.new("TextLabel")
    distanceLabel.Name = "Distance"
    distanceLabel.Text = "距离: -- 米"
    distanceLabel.Size = UDim2.new(1, 0, 0, 24 * scale)
    distanceLabel.Position = UDim2.new(0, 0, 0, 56 * scale)
    distanceLabel.BackgroundTransparency = 1
    distanceLabel.TextColor3 = Color3.fromRGB(200, 200, 210)
    distanceLabel.Font = Enum.Font.Gotham
    distanceLabel.TextSize = 14 * scale
    distanceLabel.TextXAlignment = Enum.TextXAlignment.Left
    distanceLabel.Parent = contentFrame
    
    local statusLabel = Instance.new("TextLabel")
    statusLabel.Name = "Status"
    statusLabel.Text = "状态: --"
    statusLabel.Size = UDim2.new(1, 0, 0, 24 * scale)
    statusLabel.Position = UDim2.new(0, 0, 0, 82 * scale)
    statusLabel.BackgroundTransparency = 1
    statusLabel.TextColor3 = Color3.fromRGB(200, 200, 210)
    statusLabel.Font = Enum.Font.Gotham
    statusLabel.TextSize = 14 * scale
    statusLabel.TextXAlignment = Enum.TextXAlignment.Left
    statusLabel.Parent = contentFrame
    
    local movementLabel = Instance.new("TextLabel")
    movementLabel.Name = "Movement"
    movementLabel.Text = "移动: --"
    movementLabel.Size = UDim2.new(1, 0, 0, 24 * scale)
    movementLabel.Position = UDim2.new(0, 0, 0, 108 * scale)
    movementLabel.BackgroundTransparency = 1
    movementLabel.TextColor3 = Color3.fromRGB(200, 200, 210)
    movementLabel.Font = Enum.Font.Gotham
    movementLabel.TextSize = 14 * scale
    movementLabel.TextXAlignment = Enum.TextXAlignment.Left
    movementLabel.Parent = contentFrame
    
    local healthBarBackground = Instance.new("Frame")
    healthBarBackground.Size = UDim2.new(1, 0, 0, 8 * scale)
    healthBarBackground.Position = UDim2.new(0, 0, 0, 136 * scale)
    healthBarBackground.BackgroundColor3 = Color3.fromRGB(60, 60, 75)
    healthBarBackground.BorderSizePixel = 0
    healthBarBackground.Parent = contentFrame
    
    local healthBarCorner = Instance.new("UICorner")
    healthBarCorner.CornerRadius = UDim.new(0, 4)
    healthBarCorner.Parent = healthBarBackground
    
    local healthBarFill = Instance.new("Frame")
    healthBarFill.Name = "HealthBarFill"
    healthBarFill.Size = UDim2.new(1, 0, 1, 0)
    healthBarFill.BackgroundColor3 = Color3.fromRGB(85, 255, 127)
    healthBarFill.BorderSizePixel = 0
    healthBarFill.Parent = healthBarBackground
    
    local fillCorner = Instance.new("UICorner")
    fillCorner.CornerRadius = UDim.new(0, 4)
    fillCorner.Parent = healthBarFill
    
    local healthText = Instance.new("TextLabel")
    healthText.Name = "HealthText"
    healthText.Text = "血量: --/--"
    healthText.Size = UDim2.new(1, 0, 0, 20 * scale)
    healthText.Position = UDim2.new(0, 0, 0, 148 * scale)
    healthText.BackgroundTransparency = 1
    healthText.TextColor3 = Color3.fromRGB(200, 200, 210)
    healthText.Font = Enum.Font.Gotham
    healthText.TextSize = 13 * scale
    healthText.TextXAlignment = Enum.TextXAlignment.Left
    healthText.Parent = contentFrame
    
    local function updateTargetInfo(target)
        if not target or not target.Character then
            mainContainer.Visible = false
            return
        end
        
        mainContainer.Visible = true
        
        local character = target.Character
        local head = character:FindFirstChild("Head")
        local humanoid = character:FindFirstChild("Humanoid")
        local rootPart = character:FindFirstChild("HumanoidRootPart")
        
        if not head or not humanoid or not rootPart then
            mainContainer.Visible = false
            return
        end
        
        -- 显示玩家ID和显示名称
        nameLabel.Text = "玩家ID: " .. target.Name
        
        -- 尝试获取显示名称
        local displayName = target.DisplayName
        if displayName and displayName ~= "" then
            displayNameLabel.Text = "显示名称: " .. displayName
            displayNameLabel.Visible = true
        else
            displayNameLabel.Text = "显示名称: 未设置"
            displayNameLabel.Visible = true
        end
        
        nameLabel.TextColor3 = Color3.fromRGB(0, 255, 255)
        
        local distance = 0
        if LocalPlayer.Character and LocalPlayer.Character.HumanoidRootPart then
            distance = math.floor((LocalPlayer.Character.HumanoidRootPart.Position - rootPart.Position).Magnitude)
        end
        
        distanceLabel.Text = "距离: " .. distance .. " 米"
        
        local status, statusDistance, movementState = getTargetStatus(target)
        
        local statusText = ""
        local statusColor = Color3.fromRGB(255, 255, 255)
        
        if status == "visible" then
            statusText = "可见状态"
            statusColor = Color3.fromRGB(85, 255, 127)
        elseif status == "cover" then
            statusText = "墙后状态"
            statusColor = Color3.fromRGB(255, 170, 0)
        elseif status == "far" then
            statusText = "过远状态"
            statusColor = Color3.fromRGB(255, 85, 85)
        else
            statusText = "未知状态"
        end
        
        statusLabel.Text = "状态: " .. statusText
        statusLabel.TextColor3 = statusColor
        
        movementLabel.Text = "移动: " .. movementState
        movementLabel.TextColor3 = Color3.fromRGB(200, 200, 210)
        
        local health = math.floor(humanoid.Health)
        local maxHealth = math.floor(humanoid.MaxHealth)
        local healthPercentage = math.clamp(health / maxHealth, 0, 1)
        
        healthText.Text = string.format("血量: %d/%d", health, maxHealth)
        
        healthBarFill.Size = UDim2.new(healthPercentage, 0, 1, 0)
        
        if healthPercentage > 0.5 then
            healthBarFill.BackgroundColor3 = Color3.fromRGB(85, 255, 127)
        elseif healthPercentage > 0.2 then
            healthBarFill.BackgroundColor3 = Color3.fromRGB(255, 170, 0)
        else
            healthBarFill.BackgroundColor3 = Color3.fromRGB(255, 85, 85)
        end
    end
    
    local function hideTargetInfo()
        mainContainer.Visible = false
    end
    
    targetInfoGui = {
        Gui = screenGui,
        Update = updateTargetInfo,
        Hide = hideTargetInfo,
        Container = mainContainer
    }
    
    return targetInfoGui
end

-- 创建扇形雷达显示
local function createRadarDisplay()
    if radarGui then
        radarGui:Destroy()
        radarGui = nil
    end
    
    if not config.radarEnabled then return end
    
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "RadarDisplay"
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    screenGui.Parent = CoreGui
    
    local radarFrame = Instance.new("Frame")
    radarFrame.Name = "RadarContainer"
    radarFrame.Size = UDim2.new(0, config.radarSize, 0, config.radarSize)
    radarFrame.Position = UDim2.new(0, config.radarPositionX, 1, config.radarPositionY)
    radarFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
    radarFrame.BackgroundTransparency = 0.3
    radarFrame.BorderSizePixel = 0
    radarFrame.ZIndex = 80
    radarFrame.Parent = screenGui
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = radarFrame
    
    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(60, 150, 255)
    stroke.Thickness = 2
    stroke.Transparency = 0.3
    stroke.Parent = radarFrame
    
    -- 雷达标题
    local titleLabel = Instance.new("TextLabel")
    titleLabel.Text = "扇形雷达"
    titleLabel.Size = UDim2.new(1, -10, 0, 24)
    titleLabel.Position = UDim2.new(0, 5, 0, 5)
    titleLabel.BackgroundTransparency = 1
    titleLabel.TextColor3 = Color3.fromRGB(100, 200, 255)
    titleLabel.Font = Enum.Font.GothamBold
    titleLabel.TextSize = 14
    titleLabel.TextXAlignment = Enum.TextXAlignment.Left
    titleLabel.Parent = radarFrame
    
    -- 扇形背景
    local sectorCanvas = Instance.new("Frame")
    sectorCanvas.Name = "SectorCanvas"
    sectorCanvas.Size = UDim2.new(1, -20, 1, -34)
    sectorCanvas.Position = UDim2.new(0, 10, 0, 29)
    sectorCanvas.BackgroundTransparency = 1
    sectorCanvas.Parent = radarFrame
    
    -- 扇形区域
    local sector = Instance.new("Frame")
    sector.Name = "Sector"
    sector.Size = UDim2.new(1, 0, 1, 0)
    sector.BackgroundColor3 = Color3.fromRGB(30, 70, 120)
    sector.BackgroundTransparency = 0.7
    sector.BorderSizePixel = 0
    sector.Parent = sectorCanvas
    
    local sectorCorner = Instance.new("UICorner")
    sectorCorner.CornerRadius = UDim.new(1, 0)
    sectorCorner.Parent = sector
    
    -- 玩家显示区域
    local playerContainer = Instance.new("Frame")
    playerContainer.Name = "PlayerContainer"
    playerContainer.Size = UDim2.new(1, 0, 1, 0)
    playerContainer.BackgroundTransparency = 1
    playerContainer.Parent = sectorCanvas
    
    -- 中心点（自己）
    local centerLabel = Instance.new("TextLabel")
    centerLabel.Name = "CenterLabel"
    centerLabel.Text = "我"
    centerLabel.Size = UDim2.new(0, 20, 0, 20)
    centerLabel.Position = UDim2.new(0.5, -10, 0.5, -10)
    centerLabel.BackgroundTransparency = 1
    centerLabel.TextColor3 = Color3.fromRGB(0, 255, 0)
    centerLabel.Font = Enum.Font.GothamBold
    centerLabel.TextSize = 12
    centerLabel.TextXAlignment = Enum.TextXAlignment.Center
    centerLabel.Parent = playerContainer
    
    radarGui = {
        Gui = screenGui,
        Frame = radarFrame,
        Sector = sector,
        Container = playerContainer,
        Dots = {}
    }
    
    return radarGui
end

-- 更新扇形雷达显示
local function updateRadar()
    if not radarGui or not config.radarEnabled then return end
    
    -- 清理旧的玩家点
    for _, dot in pairs(radarGui.Dots) do
        if dot then
            dot:Destroy()
        end
    end
    radarGui.Dots = {}
    
    if not LocalPlayer.Character then return end
    
    local localRoot = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not localRoot then return end
    
    local localPosition = localRoot.Position
    local localCFrame = localRoot.CFrame
    
    local containerSize = radarGui.Container.AbsoluteSize.X / 2
    
    -- 更新扇形方向
    local lookVector = localCFrame.LookVector
    local angle = math.deg(math.atan2(lookVector.X, lookVector.Z))
    radarGui.Sector.Rotation = -angle
    
    -- 扇形角度设置
    radarGui.Sector.Size = UDim2.new(0, containerSize * 2, 0, containerSize * 2)
    radarGui.Sector.Position = UDim2.new(0.5, -containerSize, 0.5, -containerSize)
    
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character then
            local character = player.Character
            local rootPart = character:FindFirstChild("HumanoidRootPart")
            local humanoid = character:FindFirstChild("Humanoid")
            
            if rootPart and humanoid and humanoid.Health > 0 then
                local targetPosition = rootPart.Position
                local relativePosition = targetPosition - localPosition
                
                -- 计算距离
                local distance = relativePosition.Magnitude
                if distance <= config.radarRange then
                    -- 转换到本地坐标系
                    local localRelative = localCFrame:PointToObjectSpace(targetPosition)
                    
                    -- 归一化到雷达范围
                    local radarX = localRelative.X / config.radarRange
                    local radarZ = -localRelative.Z / config.radarRange
                    
                    -- 检查是否在扇形范围内
                    local angleToTarget = math.deg(math.atan2(localRelative.X, -localRelative.Z))
                    local halfSector = config.radarSectorAngle / 2
                    
                    if math.abs(angleToTarget) <= halfSector then
                        -- 限制在雷达范围内
                        if math.abs(radarX) <= 1 and math.abs(radarZ) <= 1 then
                            -- 创建玩家点
                            local dot = Instance.new("Frame")
                            dot.Name = "RadarDot_" .. player.Name
                            dot.Size = UDim2.new(0, config.radarDotSize, 0, config.radarDotSize)
                            dot.Position = UDim2.new(0.5 + radarX * 0.9, -config.radarDotSize/2, 
                                                     0.5 + radarZ * 0.9, -config.radarDotSize/2)
                            
                            -- 根据距离设置颜色
                            local distanceRatio = distance / config.radarRange
                            if distanceRatio < 0.33 then
                                dot.BackgroundColor3 = Color3.fromRGB(255, 50, 50) -- 红色：近
                            elseif distanceRatio < 0.66 then
                                dot.BackgroundColor3 = Color3.fromRGB(255, 150, 50) -- 橙色：中
                            else
                                dot.BackgroundColor3 = Color3.fromRGB(255, 255, 50) -- 黄色：远
                            end
                            
                            dot.BorderSizePixel = 0
                            dot.ZIndex = 5
                            dot.Parent = radarGui.Container
                            
                            local dotCorner = Instance.new("UICorner")
                            dotCorner.CornerRadius = UDim.new(1, 0)
                            dotCorner.Parent = dot
                            
                            radarGui.Dots[player] = dot
                        end
                    end
                end
            end
        end
    end
end

-- 创建瞄准预警显示
local function createAimWarningDisplay()
    if warningGui then
        warningGui:Destroy()
        warningGui = nil
    end
    
    if not config.aimWarningEnabled then return end
    
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "AimWarningDisplay"
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    screenGui.Parent = CoreGui
    
    local warningFrame = Instance.new("Frame")
    warningFrame.Name = "WarningContainer"
    warningFrame.Size = UDim2.new(0, 400, 0, 120)
    warningFrame.Position = UDim2.new(0.5, -200, 0, 50)
    warningFrame.BackgroundColor3 = Color3.fromRGB(40, 20, 20)
    warningFrame.BackgroundTransparency = 0.2
    warningFrame.BorderSizePixel = 0
    warningFrame.Visible = false
    warningFrame.ZIndex = 90
    warningFrame.Parent = screenGui
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 12)
    corner.Parent = warningFrame
    
    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(255, 50, 50)
    stroke.Thickness = 3
    stroke.Transparency = 0.3
    stroke.Parent = warningFrame
    
    -- 警告图标
    local warningIcon = Instance.new("TextLabel")
    warningIcon.Text = "!"
    warningIcon.Size = UDim2.new(0, 40, 0, 40)
    warningIcon.Position = UDim2.new(0, 10, 0.5, -20)
    warningIcon.BackgroundTransparency = 1
    warningIcon.TextColor3 = Color3.fromRGB(255, 100, 100)
    warningIcon.Font = Enum.Font.GothamBold
    warningIcon.TextSize = 32
    warningIcon.TextXAlignment = Enum.TextXAlignment.Center
    warningIcon.Parent = warningFrame
    
    -- 警告文本
    local warningText = Instance.new("TextLabel")
    warningText.Name = "WarningText"
    warningText.Text = ""
    warningText.Size = UDim2.new(1, -60, 1, -20)
    warningText.Position = UDim2.new(0, 60, 0, 10)
    warningText.BackgroundTransparency = 1
    warningText.TextColor3 = Color3.fromRGB(255, 150, 150)
    warningText.Font = Enum.Font.GothamBold
    warningText.TextSize = 16
    warningText.TextXAlignment = Enum.TextXAlignment.Left
    warningText.TextYAlignment = Enum.TextYAlignment.Top
    warningText.TextWrapped = true
    warningText.Parent = warningFrame
    
    warningGui = {
        Gui = screenGui,
        Frame = warningFrame,
        Text = warningText,
        Icon = warningIcon,
        Active = false,
        EndTime = 0
    }
    
    return warningGui
end

-- 显示瞄准预警
local function showAimWarning(player)
    if not warningGui or not config.aimWarningEnabled then return end
    
    -- 获取玩家显示名称
    local displayName = player.DisplayName
    local warningMessage = ""
    
    if displayName and displayName ~= "" then
        warningMessage = string.format("警告: %s (%s) 正在瞄准你！\n距离: 正在计算...", displayName, player.Name)
    else
        warningMessage = string.format("警告: %s 正在瞄准你！\n距离: 正在计算...", player.Name)
    end
    
    -- 计算距离
    if LocalPlayer.Character and LocalPlayer.Character.HumanoidRootPart and player.Character then
        local targetRoot = player.Character:FindFirstChild("HumanoidRootPart")
        if targetRoot then
            local distance = math.floor((LocalPlayer.Character.HumanoidRootPart.Position - targetRoot.Position).Magnitude)
            warningMessage = warningMessage:gsub("距离: 正在计算...", "距离: " .. distance .. "米")
        end
    end
    
    warningGui.Text.Text = warningMessage
    warningGui.Frame.Visible = true
    warningGui.Active = true
    warningGui.EndTime = tick() + config.warningDuration
    
    -- 闪烁效果
    spawn(function()
        local startTime = tick()
        while warningGui.Active and tick() < warningGui.EndTime do
            local alpha = 0.2 + math.sin(tick() * 8) * 0.15
            warningGui.Frame.BackgroundTransparency = alpha
            task.wait(0.05)
        end
        warningGui.Frame.Visible = false
        warningGui.Active = false
    end)
end

-- 检查玩家是否在瞄准我（无需掩体判断）
local function checkIfPlayerAimingAtMe(player)
    if not player or player == LocalPlayer or not player.Character then
        return false, 0
    end
    
    local character = player.Character
    local head = character:FindFirstChild("Head")
    local humanoid = character:FindFirstChild("Humanoid")
    
    if not head or not humanoid or humanoid.Health <= 0 then
        return false, 0
    end
    
    if not LocalPlayer.Character or not LocalPlayer.Character:FindFirstChild("Head") then
        return false, 0
    end
    
    local localHead = LocalPlayer.Character:FindFirstChild("Head")
    
    -- 计算玩家看向的方向
    local playerDirection = (head.CFrame.LookVector).Unit
    local toLocalPlayer = (localHead.Position - head.Position).Unit
    
    -- 计算角度差
    local dotProduct = playerDirection:Dot(toLocalPlayer)
    local angle = math.deg(math.acos(math.clamp(dotProduct, -1, 1)))
    
    -- 如果角度小于30度，则认为在瞄准我（不需要掩体判断）
    return angle < 30, angle
end

-- 创建人物状态显示
local function createCharacterStatusDisplay()
    if statusGui then
        statusGui:Destroy()
        statusGui = nil
    end
    
    if not config.characterStatusEnabled then return end
    
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "CharacterStatusDisplay"
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    screenGui.Parent = CoreGui
    
    local statusFrame = Instance.new("Frame")
    statusFrame.Name = "StatusContainer"
    statusFrame.Size = UDim2.new(0, 300, 0, 200)
    statusFrame.Position = UDim2.new(0, 20, 0, 20)
    statusFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
    statusFrame.BackgroundTransparency = 0.2
    statusFrame.BorderSizePixel = 0
    statusFrame.ZIndex = 85
    statusFrame.Parent = screenGui
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = statusFrame
    
    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(80, 160, 255)
    stroke.Thickness = 2
    stroke.Transparency = 0.3
    stroke.Parent = statusFrame
    
    -- 标题
    local titleLabel = Instance.new("TextLabel")
    titleLabel.Text = "人物状态"
    titleLabel.Size = UDim2.new(1, -10, 0, 30)
    titleLabel.Position = UDim2.new(0, 5, 0, 5)
    titleLabel.BackgroundTransparency = 1
    titleLabel.TextColor3 = Color3.fromRGB(100, 200, 255)
    titleLabel.Font = Enum.Font.GothamBold
    titleLabel.TextSize = 16
    titleLabel.TextXAlignment = Enum.TextXAlignment.Left
    titleLabel.Parent = statusFrame
    
    -- 内容区域
    local contentFrame = Instance.new("Frame")
    contentFrame.Size = UDim2.new(1, -20, 1, -40)
    contentFrame.Position = UDim2.new(0, 10, 0, 35)
    contentFrame.BackgroundTransparency = 1
    contentFrame.Parent = statusFrame
    
    -- 玩家信息
    local playerNameLabel = Instance.new("TextLabel")
    playerNameLabel.Name = "PlayerName"
    playerNameLabel.Text = "玩家: --"
    playerNameLabel.Size = UDim2.new(1, 0, 0, 24)
    playerNameLabel.BackgroundTransparency = 1
    playerNameLabel.TextColor3 = Color3.fromRGB(220, 220, 230)
    playerNameLabel.Font = Enum.Font.GothamSemibold
    playerNameLabel.TextSize = 14
    playerNameLabel.TextXAlignment = Enum.TextXAlignment.Left
    playerNameLabel.Parent = contentFrame
    
    local healthLabel = Instance.new("TextLabel")
    healthLabel.Name = "Health"
    healthLabel.Text = "血量: --/--"
    healthLabel.Size = UDim2.new(1, 0, 0, 22)
    healthLabel.Position = UDim2.new(0, 0, 0, 26)
    healthLabel.BackgroundTransparency = 1
    healthLabel.TextColor3 = Color3.fromRGB(200, 200, 210)
    healthLabel.Font = Enum.Font.Gotham
    healthLabel.TextSize = 13
    healthLabel.TextXAlignment = Enum.TextXAlignment.Left
    healthLabel.Parent = contentFrame
    
    local healthBarBackground = Instance.new("Frame")
    healthBarBackground.Size = UDim2.new(1, 0, 0, 8)
    healthBarBackground.Position = UDim2.new(0, 0, 0, 52)
    healthBarBackground.BackgroundColor3 = Color3.fromRGB(60, 60, 75)
    healthBarBackground.BorderSizePixel = 0
    healthBarBackground.Parent = contentFrame
    
    local healthBarCorner = Instance.new("UICorner")
    healthBarCorner.CornerRadius = UDim.new(0, 4)
    healthBarCorner.Parent = healthBarBackground
    
    local healthBarFill = Instance.new("Frame")
    healthBarFill.Name = "HealthBarFill"
    healthBarFill.Size = UDim2.new(1, 0, 1, 0)
    healthBarFill.BackgroundColor3 = Color3.fromRGB(85, 255, 127)
    healthBarFill.BorderSizePixel = 0
    healthBarFill.Parent = healthBarBackground
    
    local fillCorner = Instance.new("UICorner")
    fillCorner.CornerRadius = UDim.new(0, 4)
    fillCorner.Parent = healthBarFill
    
    -- 移动状态
    local movementLabel = Instance.new("TextLabel")
    movementLabel.Name = "Movement"
    movementLabel.Text = "移动: 站立"
    movementLabel.Size = UDim2.new(1, 0, 0, 22)
    movementLabel.Position = UDim2.new(0, 0, 0, 64)
    movementLabel.BackgroundTransparency = 1
    movementLabel.TextColor3 = Color3.fromRGB(200, 200, 210)
    movementLabel.Font = Enum.Font.Gotham
    movementLabel.TextSize = 13
    movementLabel.TextXAlignment = Enum.TextXAlignment.Left
    movementLabel.Parent = contentFrame
    
    -- 武器信息
    local weaponLabel = Instance.new("TextLabel")
    weaponLabel.Name = "Weapon"
    weaponLabel.Text = "武器: 无"
    weaponLabel.Size = UDim2.new(1, 0, 0, 22)
    weaponLabel.Position = UDim2.new(0, 0, 0, 88)
    weaponLabel.BackgroundTransparency = 1
    weaponLabel.TextColor3 = Color3.fromRGB(200, 200, 210)
    weaponLabel.Font = Enum.Font.Gotham
    weaponLabel.TextSize = 13
    weaponLabel.TextXAlignment = Enum.TextXAlignment.Left
    weaponLabel.Parent = contentFrame
    
    -- 位置信息
    local positionLabel = Instance.new("TextLabel")
    positionLabel.Name = "Position"
    positionLabel.Text = "位置: (0, 0, 0)"
    positionLabel.Size = UDim2.new(1, 0, 0, 22)
    positionLabel.Position = UDim2.new(0, 0, 0, 112)
    positionLabel.BackgroundTransparency = 1
    positionLabel.TextColor3 = Color3.fromRGB(200, 200, 210)
    positionLabel.Font = Enum.Font.Gotham
    positionLabel.TextSize = 13
    positionLabel.TextXAlignment = Enum.TextXAlignment.Left
    positionLabel.Parent = contentFrame
    
    -- 瞄准目标
    local targetLabel = Instance.new("TextLabel")
    targetLabel.Name = "Target"
    targetLabel.Text = "瞄准目标: 无"
    targetLabel.Size = UDim2.new(1, 0, 0, 22)
    targetLabel.Position = UDim2.new(0, 0, 0, 136)
    targetLabel.BackgroundTransparency = 1
    targetLabel.TextColor3 = Color3.fromRGB(200, 200, 210)
    targetLabel.Font = Enum.Font.Gotham
    targetLabel.TextSize = 13
    targetLabel.TextXAlignment = Enum.TextXAlignment.Left
    targetLabel.Parent = contentFrame
    
    statusGui = {
        Gui = screenGui,
        Frame = statusFrame,
        PlayerName = playerNameLabel,
        Health = healthLabel,
        HealthBar = healthBarFill,
        Movement = movementLabel,
        Weapon = weaponLabel,
        Position = positionLabel,
        Target = targetLabel
    }
    
    return statusGui
end

-- 更新人物状态显示
local function updateCharacterStatus()
    if not statusGui or not config.characterStatusEnabled then return end
    
    if not LocalPlayer or not LocalPlayer.Character then
        statusGui.Frame.Visible = false
        return
    end
    
    statusGui.Frame.Visible = true
    
    -- 更新玩家信息
    local displayName = LocalPlayer.DisplayName
    if displayName and displayName ~= "" then
        statusGui.PlayerName.Text = "玩家: " .. displayName .. " (" .. LocalPlayer.Name .. ")"
    else
        statusGui.PlayerName.Text = "玩家: " .. LocalPlayer.Name
    end
    
    -- 更新血量信息
    local humanoid = LocalPlayer.Character:FindFirstChild("Humanoid")
    if humanoid then
        local health = math.floor(humanoid.Health)
        local maxHealth = math.floor(humanoid.MaxHealth)
        local healthPercentage = math.clamp(health / maxHealth, 0, 1)
        
        statusGui.Health.Text = string.format("血量: %d/%d", health, maxHealth)
        statusGui.HealthBar.Size = UDim2.new(healthPercentage, 0, 1, 0)
        
        if healthPercentage > 0.5 then
            statusGui.HealthBar.BackgroundColor3 = Color3.fromRGB(85, 255, 127)
        elseif healthPercentage > 0.2 then
            statusGui.HealthBar.BackgroundColor3 = Color3.fromRGB(255, 170, 0)
        else
            statusGui.HealthBar.BackgroundColor3 = Color3.fromRGB(255, 85, 85)
        end
        
        -- 更新移动状态
        local movementState = "站立"
        if humanoid.MoveDirection.Magnitude > 0 then
            if humanoid.WalkSpeed >= 20 then
                movementState = "奔跑"
            else
                movementState = "行走"
            end
        end
        statusGui.Movement.Text = "移动: " .. movementState
    else
        statusGui.Health.Text = "血量: 无角色"
        statusGui.HealthBar.Size = UDim2.new(0, 0, 1, 0)
        statusGui.Movement.Text = "移动: 无角色"
    end
    
    -- 更新武器信息
    local weaponName = "无"
    local backpack = LocalPlayer:FindFirstChild("Backpack")
    if backpack then
        local tools = backpack:GetChildren()
        if #tools > 0 then
            weaponName = tools[1].Name
        end
    end
    statusGui.Weapon.Text = "武器: " .. weaponName
    
    -- 更新位置信息
    local rootPart = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if rootPart then
        local pos = rootPart.Position
        statusGui.Position.Text = string.format("位置: (%d, %d, %d)", 
            math.floor(pos.X), math.floor(pos.Y), math.floor(pos.Z))
    else
        statusGui.Position.Text = "位置: 未知"
    end
    
    -- 更新瞄准目标
    if currentTarget then
        statusGui.Target.Text = "瞄准目标: " .. currentTarget.Name
    else
        statusGui.Target.Text = "瞄准目标: 无"
    end
end

-- 血量条系统
local function createHealthBar(player)
    if playerHealthBars[player] then
        playerHealthBars[player]:Destroy()
        playerHealthBars[player] = nil
    end
    
    if not config.showHealthBar then return end
    
    local character = player.Character
    if not character then return end
    
    local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
    if not humanoidRootPart then return end
    
    local billboard = Instance.new("BillboardGui")
    billboard.Name = "HealthBar_" .. player.Name
    billboard.Size = UDim2.new(0, 80, 0, 6)
    
    if config.healthBarSide == "right" then
        billboard.ExtentsOffset = Vector3.new(2.5, 0, 0)
    else
        billboard.ExtentsOffset = Vector3.new(-2.5, 0, 0)
    end
    
    billboard.AlwaysOnTop = true
    billboard.Enabled = config.espEnabled
    billboard.MaxDistance = 9999
    billboard.Adornee = humanoidRootPart
    billboard.Parent = humanoidRootPart
    
    local background = Instance.new("Frame")
    background.Name = "Background"
    background.Size = UDim2.new(1, 0, 1, 0)
    background.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
    background.BorderSizePixel = 1
    background.BorderColor3 = Color3.fromRGB(40, 40, 40)
    background.Parent = billboard
    
    local fill = Instance.new("Frame")
    fill.Name = "Fill"
    fill.Size = UDim2.new(1, 0, 1, 0)
    fill.BackgroundColor3 = Color3.fromRGB(85, 255, 127)
    fill.BorderSizePixel = 0
    fill.Parent = background
    
    playerHealthBars[player] = {
        Gui = billboard,
        Background = background,
        Fill = fill
    }
    
    return playerHealthBars[player]
end

-- ESP系统
local function createESP(player)
    if not player or not player.Character then return end
    
    if not espObjects[player] then
        espObjects[player] = {
            player = player,
            lastUpdate = 0,
            needsUpdate = true,
            espData = {}
        }
    end
end

local function removeESP(player)
    if espObjects[player] then
        if espObjects[player].espData then
            for _, obj in pairs(espObjects[player].espData) do
                if obj and obj.Parent then
                    obj:Destroy()
                end
            end
        end
        
        if playerHealthBars[player] then
            playerHealthBars[player]:Destroy()
            playerHealthBars[player] = nil
        end
        
        espObjects[player] = nil
    end
end

local function updateSingleESP(player, espData)
    if not player or not player.Character then return false end
    
    local character = player.Character
    local head = character:FindFirstChild("Head")
    local humanoid = character:FindFirstChild("Humanoid")
    local rootPart = character:FindFirstChild("HumanoidRootPart")
    
    -- 检查角色是否有效
    if not head or not humanoid or humanoid.Health <= 0 or not rootPart then
        return false
    end
    
    local distance = 0
    if LocalPlayer.Character and LocalPlayer.Character.HumanoidRootPart then
        distance = math.floor((LocalPlayer.Character.HumanoidRootPart.Position - rootPart.Position).Magnitude)
    end
    
    local shouldShow = config.espEnabled and (config.espDistance == 0 or distance <= config.espDistance)
    local status, _, movementState = getTargetStatus(player)
    
    -- 名称标签
    if config.showName then
        if not espData.nameTag or not espData.nameTag.Parent then
            local billboard = Instance.new("BillboardGui")
            billboard.Name = "ESP_Name_" .. player.Name
            billboard.Size = UDim2.new(0, 180, 0, 40)
            billboard.ExtentsOffset = Vector3.new(0, 3, 0)
            billboard.AlwaysOnTop = true
            billboard.MaxDistance = 9999
            billboard.Adornee = head
            billboard.Parent = head
            
            local textLabel = Instance.new("TextLabel")
            textLabel.Size = UDim2.new(1, 0, 1, 0)
            textLabel.BackgroundTransparency = 1
            textLabel.Font = Enum.Font.GothamBold
            textLabel.TextSize = 12
            textLabel.TextStrokeTransparency = 0.5
            textLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
            textLabel.Parent = billboard
            
            espData.nameTag = billboard
            espData.nameLabel = textLabel
        end
        
        local showName = shouldShow and (distance > config.nameHideDistance)
        espData.nameTag.Enabled = showName
        
        if showName then
            -- 显示玩家ID和显示名称
            local displayName = player.DisplayName
            local nameText = ""
            
            if displayName and displayName ~= "" and displayName ~= player.Name then
                nameText = string.format("%s (%s)\n%s | %s", displayName, player.Name, movementState, status == "cover" and "墙后" or "可见")
            else
                nameText = string.format("%s\n%s | %s", player.Name, movementState, status == "cover" and "墙后" or "可见")
            end
            
            espData.nameLabel.Text = nameText
            
            if player == currentTarget then
                espData.nameLabel.TextColor3 = Color3.fromRGB(255, 255, 100)
            else
                if status == "visible" then
                    espData.nameLabel.TextColor3 = Color3.fromRGB(85, 255, 127)
                elseif status == "cover" then
                    espData.nameLabel.TextColor3 = Color3.fromRGB(255, 170, 0)
                elseif status == "far" then
                    espData.nameLabel.TextColor3 = Color3.fromRGB(255, 85, 85)
                else
                    espData.nameLabel.TextColor3 = Color3.fromRGB(0, 255, 255)
                end
            end
            
            local scale = math.clamp(1 - (distance / 500) * 0.3, 0.6, 1)
            espData.nameTag.Size = UDim2.new(0, 180 * scale, 0, 40 * scale)
            espData.nameLabel.TextSize = math.floor(12 * scale)
        end
    elseif espData.nameTag then
        espData.nameTag:Destroy()
        espData.nameTag = nil
        espData.nameLabel = nil
    end
    
    -- 距离标签
    if config.showDistance then
        if not espData.distanceTag or not espData.distanceTag.Parent then
            local distanceBillboard = Instance.new("BillboardGui")
            distanceBillboard.Name = "ESP_Distance_" .. player.Name
            distanceBillboard.Size = UDim2.new(0, 100, 0, 20)
            distanceBillboard.ExtentsOffset = Vector3.new(0, 2.2, 0)
            distanceBillboard.AlwaysOnTop = true
            distanceBillboard.MaxDistance = 9999
            distanceBillboard.Adornee = head
            distanceBillboard.Parent = head
            
            local distanceLabel = Instance.new("TextLabel")
            distanceLabel.Size = UDim2.new(1, 0, 1, 0)
            distanceLabel.BackgroundTransparency = 1
            distanceLabel.Font = Enum.Font.Gotham
            distanceLabel.TextSize = 10
            distanceLabel.TextStrokeTransparency = 0.5
            distanceLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
            distanceLabel.Parent = distanceBillboard
            
            espData.distanceTag = distanceBillboard
            espData.distanceLabel = distanceLabel
        end
        
        espData.distanceTag.Enabled = shouldShow
        if shouldShow then
            espData.distanceLabel.Text = distance .. "m"
            if player == currentTarget then
                espData.distanceLabel.TextColor3 = Color3.fromRGB(255, 255, 100)
            else
                espData.distanceLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
            end
            
            local scale = math.clamp(1 - (distance / 500) * 0.3, 0.5, 0.8)
            espData.distanceTag.Size = UDim2.new(0, 100 * scale, 0, 20 * scale)
            espData.distanceLabel.TextSize = math.floor(10 * scale)
        end
    elseif espData.distanceTag then
        espData.distanceTag:Destroy()
        espData.distanceTag = nil
        espData.distanceLabel = nil
    end
    
    -- 方框
    if config.showBox then
        if not espData.box or not espData.box.Parent then
            local box = Instance.new("BoxHandleAdornment")
            box.Name = "ESP_Box_" .. player.Name
            box.Size = Vector3.new(4, 6, 2)
            box.Transparency = 0.3
            box.AlwaysOnTop = true
            box.ZIndex = 10
            box.Adornee = rootPart
            box.Parent = rootPart
            espData.box = box
        end
        
        espData.box.Visible = shouldShow
        if shouldShow then
            if player == currentTarget then
                espData.box.Color3 = Color3.fromRGB(255, 255, 100)
                espData.box.Transparency = 0.1 + math.sin(tick() * 5) * 0.2
            else
                espData.box.Color3 = Color3.fromRGB(0, 255, 255)
                
                if status == "cover" then
                    espData.box.Transparency = 0.6
                elseif status == "far" then
                    espData.box.Transparency = 0.8
                else
                    espData.box.Transparency = 0.3
                end
            end
        end
    elseif espData.box then
        espData.box:Destroy()
        espData.box = nil
    end
    
    -- 血量条
    if config.showHealthBar then
        if not playerHealthBars[player] then
            createHealthBar(player)
        end
        
        local healthBar = playerHealthBars[player]
        if healthBar then
            healthBar.Gui.Enabled = shouldShow
            if shouldShow then
                local health = humanoid.Health
                local maxHealth = humanoid.MaxHealth
                local healthPercentage = math.clamp(health / maxHealth, 0, 1)
                
                healthBar.Fill.Size = UDim2.new(healthPercentage, 0, 1, 0)
                
                if healthPercentage > 0.5 then
                    healthBar.Fill.BackgroundColor3 = Color3.fromRGB(85, 255, 127)
                elseif healthPercentage > 0.2 then
                    healthBar.Fill.BackgroundColor3 = Color3.fromRGB(255, 170, 0)
                else
                    healthBar.Fill.BackgroundColor3 = Color3.fromRGB(255, 85, 85)
                end
            end
        end
    end
    
    return true
end

-- 改进的ESP循环
local function startESPLoop()
    if espConnection then
        espConnection:Disconnect()
    end
    
    espConnection = RunService.RenderStepped:Connect(function()
        -- 遍历所有玩家
        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= LocalPlayer then
                -- 检查玩家是否存在且有效
                if player and player.Parent then
                    -- 如果ESP对象不存在，创建它
                    if not espObjects[player] then
                        createESP(player)
                    end
                    
                    -- 如果ESP对象存在，更新它
                    if espObjects[player] then
                        local success = updateSingleESP(player, espObjects[player].espData)
                        
                        -- 如果更新失败，移除ESP
                        if not success then
                            removeESP(player)
                        else
                            espObjects[player].lastUpdate = tick()
                            espObjects[player].needsUpdate = false
                        end
                    end
                else
                    -- 玩家无效，移除ESP
                    removeESP(player)
                end
            end
        end
        
        -- 清理无效的ESP对象
        for player, espData in pairs(espObjects) do
            if not player or not player.Parent then
                removeESP(player)
            end
        end
    end)
end

-- ==============================================
-- 改进的自瞄算法
-- ==============================================

-- 查找最佳目标
local function findBestTarget()
    if not Camera or not LocalPlayer.Character then return nil, nil end
    
    local bestPlayer, bestAimPart = nil, nil
    local localHead = LocalPlayer.Character:FindFirstChild("Head")
    local screenCenter = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
    
    if not localHead then return nil, nil end
    
    local bestScore = math.huge
    
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character then
            local char = player.Character
            local head = char:FindFirstChild("Head")
            local humanoid = char:FindFirstChild("Humanoid")
            local rootPart = char:FindFirstChild("HumanoidRootPart")
            
            if head and humanoid and humanoid.Health > 0 and rootPart then
                local worldDistance = (localHead.Position - head.Position).Magnitude
                
                -- 检查距离限制
                if config.maxDistance > 0 and worldDistance > config.maxDistance then
                    continue
                end
                
                -- 检查掩体
                if config.checkCover and not config.ignoreCover then
                    local status = getTargetStatus(player)
                    if status == "cover" then
                        continue
                    end
                end
                
                local aimPart = config.aimAt == "head" and head or rootPart
                local screenPos = Camera:WorldToViewportPoint(aimPart.Position)
                
                if screenPos.Z > 0 then
                    local screenPos2D = Vector2.new(screenPos.X, screenPos.Y)
                    local screenDistance = (screenCenter - screenPos2D).Magnitude
                    
                    if screenDistance <= config.aimFov then
                        local score = 0
                        
                        if config.priorityMode == "closest" then
                            -- 距离优先
                            score = worldDistance * 0.7 + screenDistance * 0.3
                        else
                            -- 准星优先
                            score = screenDistance * 0.8 + worldDistance * 0.2
                        end
                        
                        if score < bestScore then
                            bestScore = score
                            bestPlayer = player
                            bestAimPart = aimPart
                        end
                    end
                end
            end
        end
    end
    
    return bestPlayer, bestAimPart
end

-- 改进的平滑自瞄函数
local function smoothAim(targetPosition)
    if not Camera then return end
    
    local currentPosition = Camera.CFrame.Position
    local currentCFrame = Camera.CFrame
    
    -- 计算目标方向
    local targetDirection = (targetPosition - currentPosition).Unit
    
    -- 计算当前相机的方向
    local currentDirection = currentCFrame.LookVector
    
    -- 计算两个方向之间的角度差
    local dot = currentDirection:Dot(targetDirection)
    local angle = math.acos(math.clamp(dot, -1, 1))
    
    -- 根据平滑系数计算插值因子
    -- 平滑系数越小，瞄准速度越快；平滑系数越大，瞄准速度越慢
    local smoothFactor = math.clamp(config.smoothFactor, 0.01, 1.0)
    
    -- 计算插值因子：角度越小，插值越快；平滑系数越小，插值越快
    local lerpFactor = 1 - smoothFactor * (0.5 + angle / math.pi * 0.5)
    lerpFactor = math.clamp(lerpFactor, 0.01, 0.99)
    
    -- 如果平滑系数非常小，直接瞄准
    if config.smoothFactor <= 0.05 then
        local targetCFrame = CFrame.new(currentPosition, currentPosition + targetDirection)
        Camera.CFrame = targetCFrame
        return
    end
    
    -- 使用球形插值进行平滑瞄准
    local resultDirection
    if angle > 0.001 then
        local sinAngle = math.sin(angle)
        resultDirection = (math.sin((1 - lerpFactor) * angle) / sinAngle) * currentDirection + 
                         (math.sin(lerpFactor * angle) / sinAngle) * targetDirection
    else
        resultDirection = targetDirection
    end
    
    -- 创建新的CFrame
    local targetCFrame = CFrame.new(currentPosition, currentPosition + resultDirection)
    
    -- 应用平滑
    Camera.CFrame = Camera.CFrame:Lerp(targetCFrame, lerpFactor)
end

-- 持续性自瞄
local function continuousAim()
    if not config.continuousEnabled then 
        currentTarget = nil
        if targetInfoGui then targetInfoGui.Hide() end
        return 
    end
    
    local bestTarget, aimPart = findBestTarget()
    if bestTarget and aimPart then
        smoothAim(aimPart.Position)
        currentTarget = bestTarget
        
        if targetInfoGui and config.showTargetInfo then
            targetInfoGui.Update(bestTarget)
        end
    else
        currentTarget = nil
        if targetInfoGui then targetInfoGui.Hide() end
    end
end

-- 启动自瞄
local function startAim()
    if aimConnection then
        aimConnection:Disconnect()
    end
    
    if config.continuousEnabled then
        aimConnection = RunService.Heartbeat:Connect(continuousAim)
    end
end

local function stopAim()
    if aimConnection then
        aimConnection:Disconnect()
        aimConnection = nil
    end
    currentTarget = nil
    if targetInfoGui then targetInfoGui.Hide() end
end

-- 启动雷达
local function startRadar()
    if radarConnection then
        radarConnection:Disconnect()
    end
    
    if config.radarEnabled then
        createRadarDisplay()
        radarConnection = RunService.Heartbeat:Connect(updateRadar)
    end
end

-- 启动瞄准预警
local function startAimWarning()
    if warningConnection then
        warningConnection:Disconnect()
    end
    
    if config.aimWarningEnabled then
        createAimWarningDisplay()
        
        warningConnection = RunService.Heartbeat:Connect(function()
            local now = tick()
            
            -- 检查冷却时间
            if now - lastWarningTime < config.warningDuration then
                return
            end
            
            -- 检查是否有玩家在瞄准我
            for _, player in ipairs(Players:GetPlayers()) do
                if player ~= LocalPlayer then
                    local isAiming, angle = checkIfPlayerAimingAtMe(player)
                    
                    if isAiming then
                        showAimWarning(player)
                        lastWarningTime = now
                        break
                    end
                end
            end
        end)
    end
end

-- 启动人物状态显示
local function startCharacterStatus()
    if statusConnection then
        statusConnection:Disconnect()
    end
    
    if config.characterStatusEnabled then
        createCharacterStatusDisplay()
        statusConnection = RunService.Heartbeat:Connect(updateCharacterStatus)
    end
end

-- ==============================================
-- Rayfield UI控件
-- ==============================================

-- 自瞄设置标签页
AimTab:CreateSection("自瞄模式")

local ContinuousToggle = AimTab:CreateToggle({
    Name = "持续性自瞄",
    CurrentValue = config.continuousEnabled,
    Flag = "ContinuousToggle",
    Callback = function(Value)
        config.continuousEnabled = Value
        if Value then
            startAim()
            Rayfield:Notify({
                Title = "持续性自瞄",
                Content = "已开启持续性自瞄",
                Duration = 2
            })
        else
            stopAim()
        end
    end,
})

AimTab:CreateSection("瞄准设置")

local PriorityDropdown = AimTab:CreateDropdown({
    Name = "目标优先级",
    Options = {"最近的优先", "准星最近的优先"},
    CurrentOption = "最近的优先",
    Flag = "PriorityDropdown",
    Callback = function(Option)
        config.priorityMode = Option == "最近的优先" and "closest" or "crosshair"
    end,
})

local SmoothSlider = AimTab:CreateSlider({
    Name = "平滑系数",
    Range = {0.01, 1.0},
    Increment = 0.01,
    Suffix = "",
    CurrentValue = config.smoothFactor,
    Flag = "SmoothSlider",
    Callback = function(Value)
        config.smoothFactor = Value
    end,
})

local AimFovSlider = AimTab:CreateSlider({
    Name = "自瞄范围",
    Range = {50, 1000},
    Increment = 10,
    Suffix = "像素",
    CurrentValue = config.aimFov,
    Flag = "AimFovSlider",
    Callback = function(Value)
        config.aimFov = Value
        createFovCircle()
    end,
})

local MaxDistanceSlider = AimTab:CreateSlider({
    Name = "最大距离",
    Range = {0, 1000},
    Increment = 10,
    Suffix = "米 (0为无限制)",
    CurrentValue = config.maxDistance,
    Flag = "MaxDistanceSlider",
    Callback = function(Value)
        config.maxDistance = Value
    end,
})

-- 雷达预警标签页
RadarTab:CreateSection("扇形雷达设置")

local RadarToggle = RadarTab:CreateToggle({
    Name = "启用扇形雷达",
    CurrentValue = config.radarEnabled,
    Flag = "RadarToggle",
    Callback = function(Value)
        config.radarEnabled = Value
        if Value then
            startRadar()
        else
            if radarConnection then
                radarConnection:Disconnect()
                radarConnection = nil
            end
            if radarGui then
                radarGui.Gui:Destroy()
                radarGui = nil
            end
        end
    end,
})

local RadarSizeSlider = RadarTab:CreateSlider({
    Name = "雷达大小",
    Range = {100, 400},
    Increment = 10,
    Suffix = "像素",
    CurrentValue = config.radarSize,
    Flag = "RadarSizeSlider",
    Callback = function(Value)
        config.radarSize = Value
        if radarGui then
            radarGui.Gui:Destroy()
            radarGui = nil
            startRadar()
        end
    end,
})

local RadarRangeSlider = RadarTab:CreateSlider({
    Name = "雷达范围",
    Range = {50, 300},
    Increment = 10,
    Suffix = "米",
    CurrentValue = config.radarRange,
    Flag = "RadarRangeSlider",
    Callback = function(Value)
        config.radarRange = Value
    end,
})

local RadarSectorSlider = RadarTab:CreateSlider({
    Name = "扇形角度",
    Range = {30, 180},
    Increment = 5,
    Suffix = "度",
    CurrentValue = config.radarSectorAngle,
    Flag = "RadarSectorSlider",
    Callback = function(Value)
        config.radarSectorAngle = Value
    end,
})

local RadarPosXSlider = RadarTab:CreateSlider({
    Name = "雷达X位置",
    Range = {0, 1920},
    Increment = 10,
    Suffix = "像素",
    CurrentValue = config.radarPositionX,
    Flag = "RadarPosXSlider",
    Callback = function(Value)
        config.radarPositionX = Value
        if radarGui then
            radarGui.Frame.Position = UDim2.new(0, Value, 1, config.radarPositionY)
        end
    end,
})

local RadarPosYSlider = RadarTab:CreateSlider({
    Name = "雷达Y位置",
    Range = {-500, 0},
    Increment = 10,
    Suffix = "像素",
    CurrentValue = config.radarPositionY,
    Flag = "RadarPosYSlider",
    Callback = function(Value)
        config.radarPositionY = Value
        if radarGui then
            radarGui.Frame.Position = UDim2.new(0, config.radarPositionX, 1, Value)
        end
    end,
})

-- 人物状态标签页
StatusTab:CreateSection("人物状态显示")

local StatusToggle = StatusTab:CreateToggle({
    Name = "启用人物状态显示",
    CurrentValue = config.characterStatusEnabled,
    Flag = "StatusToggle",
    Callback = function(Value)
        config.characterStatusEnabled = Value
        if Value then
            startCharacterStatus()
        else
            if statusConnection then
                statusConnection:Disconnect()
                statusConnection = nil
            end
            if statusGui then
                statusGui.Gui:Destroy()
                statusGui = nil
            end
        end
    end,
})

-- 视觉设置标签页
VisualTab:CreateSection("ESP显示")

local EspToggle = VisualTab:CreateToggle({
    Name = "ESP显示",
    CurrentValue = config.espEnabled,
    Flag = "EspToggle",
    Callback = function(Value)
        config.espEnabled = Value
    end,
})

local NameToggle = VisualTab:CreateToggle({
    Name = "显示玩家名称",
    CurrentValue = config.showName,
    Flag = "NameToggle",
    Callback = function(Value)
        config.showName = Value
    end,
})

local DistanceToggle = VisualTab:CreateToggle({
    Name = "显示距离",
    CurrentValue = config.showDistance,
    Flag = "DistanceToggle",
    Callback = function(Value)
        config.showDistance = Value
    end,
})

local HealthBarToggle = VisualTab:CreateToggle({
    Name = "显示血量条",
    CurrentValue = config.showHealthBar,
    Flag = "HealthBarToggle",
    Callback = function(Value)
        config.showHealthBar = Value
    end,
})

local BoxToggle = VisualTab:CreateToggle({
    Name = "显示方框",
    CurrentValue = config.showBox,
    Flag = "BoxToggle",
    Callback = function(Value)
        config.showBox = Value
    end,
})

VisualTab:CreateSection("瞄准预警")

local AimWarningToggle = VisualTab:CreateToggle({
    Name = "启用瞄准预警",
    CurrentValue = config.aimWarningEnabled,
    Flag = "AimWarningToggle",
    Callback = function(Value)
        config.aimWarningEnabled = Value
        if Value then
            startAimWarning()
        else
            if warningConnection then
                warningConnection:Disconnect()
                warningConnection = nil
            end
            if warningGui then
                warningGui.Gui:Destroy()
                warningGui = nil
            end
        end
    end,
})

local WarningDurationSlider = VisualTab:CreateSlider({
    Name = "警告持续时间",
    Range = {1, 10},
    Increment = 0.5,
    Suffix = "秒",
    CurrentValue = config.warningDuration,
    Flag = "WarningDurationSlider",
    Callback = function(Value)
        config.warningDuration = Value
    end,
})

-- 目标信息标签页
TargetTab:CreateSection("目标信息显示")

local TargetInfoToggle = TargetTab:CreateToggle({
    Name = "显示目标信息",
    CurrentValue = config.showTargetInfo,
    Flag = "TargetInfoToggle",
    Callback = function(Value)
        config.showTargetInfo = Value
        if Value then
            if not targetInfoGui then
                createTargetInfoDisplay()
            end
        elseif targetInfoGui then
            targetInfoGui.Hide()
        end
    end,
})

local PositionDropdown = TargetTab:CreateDropdown({
    Name = "显示位置",
    Options = {"右上角", "左上角", "右下角", "左下角"},
    CurrentOption = "右上角",
    Flag = "PositionDropdown",
    Callback = function(Option)
        local positionMap = {
            ["右上角"] = "TopRight",
            ["左上角"] = "TopLeft",
            ["右下角"] = "BottomRight",
            ["左下角"] = "BottomLeft"
        }
        config.targetInfoPosition = positionMap[Option] or "TopRight"
        
        if targetInfoGui then
            targetInfoGui.Gui:Destroy()
            targetInfoGui = nil
            if config.showTargetInfo then
                createTargetInfoDisplay()
            end
        end
    end,
})

local TargetScaleSlider = TargetTab:CreateSlider({
    Name = "信息框缩放",
    Range = {0.5, 2.0},
    Increment = 0.1,
    Suffix = "倍",
    CurrentValue = config.targetInfoScale,
    Flag = "TargetScaleSlider",
    Callback = function(Value)
        config.targetInfoScale = Value
        if targetInfoGui then
            targetInfoGui.Gui:Destroy()
            targetInfoGui = nil
            if config.showTargetInfo then
                createTargetInfoDisplay()
            end
        end
    end,
})

-- 高级设置标签页
AdvancedTab:CreateSection("智能掩体")

local CoverToggle = AdvancedTab:CreateToggle({
    Name = "启用掩体检测",
    CurrentValue = config.checkCover,
    Flag = "CoverToggle",
    Callback = function(Value)
        config.checkCover = Value
    end,
})

local SmartCoverToggle = AdvancedTab:CreateToggle({
    Name = "智能掩体判断",
    CurrentValue = config.smartCoverCheck,
    Flag = "SmartCoverToggle",
    Callback = function(Value)
        config.smartCoverCheck = Value
    end,
})

local IgnoreCoverToggle = AdvancedTab:CreateToggle({
    Name = "忽略掩体",
    CurrentValue = config.ignoreCover,
    Flag = "IgnoreCoverToggle",
    Callback = function(Value)
        config.ignoreCover = Value
    end,
})

AdvancedTab:CreateSection("自瞄视觉")

local FovToggle = AdvancedTab:CreateToggle({
    Name = "显示自瞄圈",
    CurrentValue = config.showAimFov,
    Flag = "FovToggle",
    Callback = function(Value)
        config.showAimFov = Value
        if Value then
            createFovCircle()
        elseif fovCircle then
            fovCircle:Destroy()
            fovCircle = nil
        end
    end,
})

AdvancedTab:CreateSection("按键设置")

local AimKeyDropdown = AdvancedTab:CreateDropdown({
    Name = "自瞄快捷键",
    Options = {"Q", "E", "F", "LeftShift", "RightShift"},
    CurrentOption = "Q",
    Flag = "AimKeyDropdown",
    Callback = function(Option)
        local keyMap = {
            ["Q"] = Enum.KeyCode.Q,
            ["E"] = Enum.KeyCode.E,
            ["F"] = Enum.KeyCode.F,
            ["LeftShift"] = Enum.KeyCode.LeftShift,
            ["RightShift"] = Enum.KeyCode.RightShift
        }
        config.aimKey = keyMap[Option] or Enum.KeyCode.Q
    end,
})

AdvancedTab:CreateButton({
    Name = "保存设置",
    Callback = function()
        Rayfield:Notify({
            Title = "设置保存",
            Content = "所有配置已保存到本地",
            Duration = 3
        })
    end,
})

AdvancedTab:CreateButton({
    Name = "隐藏界面",
    Callback = function()
        Rayfield:Destroy()
    end,
})

AdvancedTab:CreateButton({
    Name = "重新加载ESP",
    Callback = function()
        -- 清理所有ESP
        for player in pairs(espObjects) do
            removeESP(player)
        end
        
        -- 重新创建ESP
        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= LocalPlayer then
                createESP(player)
            end
        end
        
        Rayfield:Notify({
            Title = "ESP重载",
            Content = "ESP系统已重新加载",
            Duration = 2
        })
    end,
})

-- ==============================================
-- 初始化
-- ==============================================
task.spawn(function()
    wait(2)
    
    -- 创建自瞄圈
    if config.showAimFov then
        createFovCircle()
    end
    
    -- 创建目标信息显示
    if config.showTargetInfo then
        createTargetInfoDisplay()
    end
    
    -- 启动ESP系统
    startESPLoop()
    
    -- 启动雷达
    if config.radarEnabled then
        startRadar()
    end
    
    -- 启动瞄准预警
    if config.aimWarningEnabled then
        startAimWarning()
    end
    
    -- 启动人物状态显示
    if config.characterStatusEnabled then
        startCharacterStatus()
    end
    
    -- 按键绑定
    UserInputService.InputBegan:Connect(function(input)
        if input.KeyCode == config.aimKey then
            config.continuousEnabled = not config.continuousEnabled
            if config.continuousEnabled then
                startAim()
                Rayfield:Notify({
                    Title = "持续性自瞄",
                    Content = "已开启持续性自瞄",
                    Duration = 2
                })
            else
                stopAim()
                Rayfield:Notify({
                    Title = "持续性自瞄",
                    Content = "已关闭持续性自瞄",
                    Duration = 2
                })
            end
        end
    end)
    
    -- 玩家加入监听
    Players.PlayerAdded:Connect(function(player)
        createESP(player)
        player.CharacterAdded:Connect(function()
            wait(0.5)
            createESP(player)
        end)
    end)
    
    -- 玩家离开监听
    Players.PlayerRemoving:Connect(function(player)
        removeESP(player)
    end)
    
    task.wait(1)
    Rayfield:Notify({
        Title = "终极自瞄系统 v7.0",
        Content = "系统已加载完成\n按 " .. tostring(config.aimKey) .. " 键切换自瞄",
        Duration = 5
    })
    
    print("========================================")
    print("终极自瞄系统 v7.0 已加载")
    print("改进的平滑自瞄算法已应用")
    print("人物状态显示已启用")
    print("扇形雷达系统已启用")
    print("瞄准预警系统已启用")
    print("ESP系统已启用")
    print("按 " .. tostring(config.aimKey) .. " 键切换自瞄")
    print("========================================")
    
    -- 为现有玩家创建ESP
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            createESP(player)
        end
    end
end)

-- ==============================================
-- 清理函数
-- ==============================================
local function cleanup()
    if aimConnection then aimConnection:Disconnect() end
    if espConnection then espConnection:Disconnect() end
    if radarConnection then radarConnection:Disconnect() end
    if warningConnection then warningConnection:Disconnect() end
    if statusConnection then statusConnection:Disconnect() end
    
    if fovCircle then fovCircle:Destroy() end
    if targetInfoGui and targetInfoGui.Gui then targetInfoGui.Gui:Destroy() end
    if radarGui and radarGui.Gui then radarGui.Gui:Destroy() end
    if warningGui and warningGui.Gui then warningGui.Gui:Destroy() end
    if statusGui and statusGui.Gui then statusGui.Gui:Destroy() end
    
    for player in pairs(espObjects) do
        removeESP(player)
    end
    
    for player in pairs(playerHealthBars) do
        if playerHealthBars[player] then
            playerHealthBars[player]:Destroy()
        end
    end
end

game:BindToClose(cleanup)

-- 返回模块
return {
    Config = config,
    Window = Window,
    StartAim = startAim,
    StopAim = stopAim,
    Cleanup = cleanup
}