-- ==========================================
-- AuroraX UI Library v2.0
-- 现代化Roblox UI库，支持通知系统、多种控件、手风琴等
-- ==========================================

local AuroraX = {}
AuroraX.__index = AuroraX

-- 服务引用
local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local CoreGui = game:GetService("CoreGui")
local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")

-- ==========================================
-- 内部工具函数
-- ==========================================
local function deepCopy(tbl)
	if type(tbl) ~= "table" then return tbl end
	local copy = {}
	for k, v in pairs(tbl) do
		copy[deepCopy(k)] = deepCopy(v)
	end
	return copy
end

local function safeDestroy(obj)
	pcall(function()
		if obj and obj.Parent then
			obj:Destroy()
		end
	end)
end

-- ==========================================
-- 默认配色方案
-- ==========================================
local DefaultTheme = {
	Background = Color3.fromRGB(20, 20, 30),
	Sidebar = Color3.fromRGB(16, 16, 24),
	Accent = Color3.fromRGB(99, 102, 241),
	AccentHover = Color3.fromRGB(129, 140, 248),
	Inactive = Color3.fromRGB(45, 45, 60),
	InactiveHover = Color3.fromRGB(55, 55, 75),
	Text = Color3.fromRGB(240, 240, 250),
	TextDim = Color3.fromRGB(140, 140, 160),
	CardBackground = Color3.fromRGB(28, 28, 40),
	BorderSubtle = Color3.fromRGB(40, 40, 55),
	Success = Color3.fromRGB(52, 211, 153),
	Warning = Color3.fromRGB(251, 191, 36),
	Error = Color3.fromRGB(239, 68, 68),
}

-- ==========================================
-- 通知系统类
-- ==========================================
local NotificationSystem = {}
NotificationSystem.__index = NotificationSystem

function NotificationSystem.new(gui, config)
	local self = setmetatable({}, NotificationSystem)
	self.Gui = gui
	self.Config = config or {}
	self.ActiveNotifications = {}
	self.MaxVisible = self.Config.MaxNotifications or 5
	self.DefaultDuration = self.Config.DefaultDuration or 3
	
	self.Types = {
		Success = {
			Color = Color3.fromRGB(52, 211, 153),
			Icon = "[OK]"
		},
		Warning = {
			Color = Color3.fromRGB(251, 191, 36),
			Icon = "[!]"
		},
		Error = {
			Color = Color3.fromRGB(239, 68, 68),
			Icon = "[X]"
		},
		Info = {
			Color = Color3.fromRGB(99, 102, 241),
			Icon = "[i]"
		}
	}
	
	-- 创建通知容器
	self.Container = Instance.new("Frame")
	self.Container.Name = "NotificationContainer"
	self.Container.Size = UDim2.new(0, 300, 0, 0)
	self.Container.Position = UDim2.new(1, -320, 1, -20)
	self.Container.BackgroundTransparency = 1
	self.Container.AnchorPoint = Vector2.new(0, 1)
	self.Container.ZIndex = 1000
	self.Container.Parent = self.Gui
	
	local list = Instance.new("UIListLayout", self.Container)
	list.Padding = UDim.new(0, 8)
	list.HorizontalAlignment = Enum.HorizontalAlignment.Right
	list.VerticalAlignment = Enum.VerticalAlignment.Bottom
	list.SortOrder = Enum.SortOrder.LayoutOrder
	
	return self
end

function NotificationSystem:Send(title, message, notificationType, duration)
	notificationType = notificationType or "Info"
	duration = duration or self.DefaultDuration
	
	local typeConfig = self.Types[notificationType] or self.Types.Info
	
	-- 限制数量
	while #self.ActiveNotifications >= self.MaxVisible do
		local oldest = self.ActiveNotifications[1]
		if oldest and oldest.Frame and oldest.Frame.Parent then
			if oldest.ProgressTween then
				oldest.ProgressTween:Cancel()
			end
			TweenService:Create(oldest.Frame, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
				Size = UDim2.new(0, 280, 0, 0),
				BackgroundTransparency = 1
			}):Play()
			task.delay(0.3, function()
				safeDestroy(oldest.Frame)
			end)
		end
		table.remove(self.ActiveNotifications, 1)
	end
	
	-- 创建通知卡片
	local frame = Instance.new("Frame")
	frame.Size = UDim2.new(0, 280, 0, 0)
	frame.BackgroundColor3 = Color3.fromRGB(24, 24, 36)
	frame.BorderSizePixel = 0
	frame.ClipsDescendants = true
	frame.ZIndex = 1000
	frame.LayoutOrder = #self.ActiveNotifications + 1
	frame.Parent = self.Container
	
	local corner = Instance.new("UICorner", frame)
	corner.CornerRadius = UDim.new(0, 10)
	
	local stroke = Instance.new("UIStroke", frame)
	stroke.Color = Color3.fromRGB(40, 40, 55)
	stroke.Thickness = 1
	stroke.Transparency = 0.3
	
	-- 彩色指示条
	local colorBar = Instance.new("Frame", frame)
	colorBar.Size = UDim2.new(0, 4, 1, 0)
	colorBar.BackgroundColor3 = typeConfig.Color
	colorBar.BorderSizePixel = 0
	colorBar.ZIndex = 1001
	Instance.new("UICorner", colorBar).CornerRadius = UDim.new(1, 0)
	
	-- 图标
	local icon = Instance.new("TextLabel", frame)
	icon.Size = UDim2.new(0, 36, 0, 20)
	icon.Position = UDim2.new(0, 14, 0, 12)
	icon.BackgroundTransparency = 1
	icon.Text = typeConfig.Icon
	icon.Font = Enum.Font.GothamBold
	icon.TextSize = 11
	icon.TextColor3 = typeConfig.Color
	icon.TextXAlignment = Enum.TextXAlignment.Left
	icon.ZIndex = 1002
	
	-- 标题
	local titleLabel = Instance.new("TextLabel", frame)
	titleLabel.Size = UDim2.new(1, -60, 0, 18)
	titleLabel.Position = UDim2.new(0, 56, 0, 8)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Text = title
	titleLabel.Font = Enum.Font.GothamBold
	titleLabel.TextSize = 13
	titleLabel.TextColor3 = Color3.fromRGB(240, 240, 250)
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	titleLabel.ZIndex = 1002
	
	-- 消息
	local messageLabel = Instance.new("TextLabel", frame)
	messageLabel.Size = UDim2.new(1, -60, 0, 16)
	messageLabel.Position = UDim2.new(0, 56, 0, 26)
	messageLabel.BackgroundTransparency = 1
	messageLabel.Text = message
	messageLabel.Font = Enum.Font.Gotham
	messageLabel.TextSize = 11
	messageLabel.TextColor3 = Color3.fromRGB(140, 140, 160)
	messageLabel.TextXAlignment = Enum.TextXAlignment.Left
	messageLabel.ZIndex = 1002
	messageLabel.TextTruncate = Enum.TextTruncate.AtEnd
	
	-- 进度条
	local progressBG = Instance.new("Frame", frame)
	progressBG.Size = UDim2.new(1, 0, 0, 2)
	progressBG.Position = UDim2.new(0, 0, 1, -2)
	progressBG.BackgroundColor3 = Color3.fromRGB(45, 45, 60)
	progressBG.BorderSizePixel = 0
	progressBG.ZIndex = 1001
	
	local progressFill = Instance.new("Frame", progressBG)
	progressFill.Size = UDim2.fromScale(1, 1)
	progressFill.BackgroundColor3 = typeConfig.Color
	progressFill.BorderSizePixel = 0
	progressFill.ZIndex = 1002
	
	-- 入场动画
	TweenService:Create(frame, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = UDim2.new(0, 280, 0, 52)
	}):Play()
	
	-- 进度条动画
	local progressTween = TweenService:Create(progressFill, TweenInfo.new(duration, Enum.EasingStyle.Linear, Enum.EasingDirection.Out), {
		Size = UDim2.fromScale(0, 1)
	})
	progressTween:Play()
	
	local notifData = {
		Frame = frame,
		ProgressTween = progressTween
	}
	
	-- 自动移除
	task.spawn(function()
		task.wait(duration)
		pcall(function()
			if frame.Parent then
				progressTween:Cancel()
				local exitTween = TweenService:Create(frame, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
					Size = UDim2.new(0, 280, 0, 0),
					BackgroundTransparency = 1
				})
				exitTween:Play()
				exitTween.Completed:Wait()
				frame:Destroy()
			end
		end)
		
		for i, n in ipairs(self.ActiveNotifications) do
			if n == notifData then
				table.remove(self.ActiveNotifications, i)
				break
			end
		end
		
		for i, n in ipairs(self.ActiveNotifications) do
			if n.Frame and n.Frame.Parent then
				n.Frame.LayoutOrder = i
			end
		end
	end)
	
	table.insert(self.ActiveNotifications, notifData)
end

function NotificationSystem:Destroy()
	safeDestroy(self.Container)
	self.ActiveNotifications = {}
end

-- ==========================================
-- UI库主类
-- ==========================================
function AuroraX.new(config)
	config = config or {}
	
	local self = setmetatable({}, AuroraX)
	self.Config = config
	self.Theme = config.Theme or deepCopy(DefaultTheme)
	self.GuiName = config.Name or "AuroraX_UI"
	self.Player = Players.LocalPlayer
	
	-- 存储引用
	self.Tabs = {}
	self.Pages = {}
	self.CurrentTab = nil
	self.isFolded = false
	self.dragging = false
	self.dragMoved = false
	self.dragStart = nil
	self.startPos = nil
	self.savedMiniPosition = UDim2.fromScale(0.5, 0.5)
	
	-- 初始化
	self:_cleanup()
	self:_createCore()
	self:_createNotificationSystem()
	self:_createMainPanel()
	self:_setupDragLogic()
	
	-- 入场动画
	self.Main.Size = UDim2.new(0, 0, 0, 0)
	self.Main.Position = UDim2.fromScale(0.5, 0.5)
	self.Main.AnchorPoint = Vector2.new(0.5, 0.5)
	TweenService:Create(self.Main, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Size = UDim2.new(0.65, 0, 0.6, 0)
	}):Play()
	
	task.delay(0.5, function()
		self:Notify("Welcome", "AuroraX UI loaded", "Success")
	end)
	
	return self
end

-- ==========================================
-- 内部方法：清理旧UI
-- ==========================================
function AuroraX:_cleanup()
	local guiName = self.GuiName
	pcall(function()
		if CoreGui:FindFirstChild(guiName) then
			CoreGui[guiName]:Destroy()
		end
		if self.Player.PlayerGui:FindFirstChild(guiName) then
			self.Player.PlayerGui[guiName]:Destroy()
		end
		if Lighting:FindFirstChild(guiName .. "_Blur") then
			Lighting[guiName .. "_Blur"]:Destroy()
		end
	end)
end

-- ==========================================
-- 内部方法：创建核心容器
-- ==========================================
function AuroraX:_createCore()
	-- ScreenGui
	self.Gui = Instance.new("ScreenGui")
	self.Gui.Name = self.GuiName
	self.Gui.ResetOnSpawn = false
	self.Gui.IgnoreGuiInset = true
	
	pcall(function()
		self.Gui.Parent = CoreGui
	end)
	
	if not self.Gui.Parent then
		self.Gui.Parent = self.Player:WaitForChild("PlayerGui")
	end
	
	-- 模糊效果
	self.Blur = Instance.new("BlurEffect")
	self.Blur.Name = self.GuiName .. "_Blur"
	self.Blur.Size = 16
	self.Blur.Enabled = true
	self.Blur.Parent = Lighting
end

-- ==========================================
-- 内部方法：创建通知系统
-- ==========================================
function AuroraX:_createNotificationSystem()
	local notifConfig = {
		MaxNotifications = self.Config.MaxNotifications or 5,
		DefaultDuration = self.Config.NotificationDuration or 3
	}
	self.NotificationSystem = NotificationSystem.new(self.Gui, notifConfig)
end

-- ==========================================
-- 内部方法：创建主面板
-- ==========================================
function AuroraX:_createMainPanel()
	local theme = self.Theme
	
	-- 主框架
	self.Main = Instance.new("Frame")
	self.Main.Parent = self.Gui
	self.Main.Size = UDim2.new(0.65, 0, 0.6, 0)
	self.Main.Position = UDim2.fromScale(0.5, 0.5)
	self.Main.AnchorPoint = Vector2.new(0.5, 0.5)
	self.Main.BackgroundColor3 = theme.Background
	self.Main.BorderSizePixel = 0
	self.Main.ClipsDescendants = true
	
	local border = Instance.new("UIStroke", self.Main)
	border.Color = theme.BorderSubtle
	border.Thickness = 1.5
	border.Transparency = 0.5
	
	local corner = Instance.new("UICorner", self.Main)
	corner.CornerRadius = UDim.new(0, 16)
	
	self.SizeConstraint = Instance.new("UISizeConstraint", self.Main)
	self.SizeConstraint.MaxSize = Vector2.new(700, 450)
	self.SizeConstraint.MinSize = Vector2.new(480, 300)
	
	-- 阴影
	local shadow = Instance.new("Frame", self.Main)
	shadow.Size = UDim2.new(1, 20, 1, 20)
	shadow.Position = UDim2.new(0, -10, 0, -10)
	shadow.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	shadow.BackgroundTransparency = 0.7
	shadow.ZIndex = -1
	shadow.BorderSizePixel = 0
	Instance.new("UICorner", shadow).CornerRadius = UDim.new(0, 20)
	self.Shadow = shadow
	
	-- 顶栏
	self:_createTopBar()
	
	-- 侧边栏
	self:_createSidebar()
	
	-- 内容区域
	self:_createPageContainer()
	
	-- 用户卡片
	self:_createProfileCard()
end

-- ==========================================
-- 内部方法：创建顶栏
-- ==========================================
function AuroraX:_createTopBar()
	local theme = self.Theme
	
	self.TopBar = Instance.new("Frame", self.Main)
	self.TopBar.Size = UDim2.new(1, 0, 0, 55)
	self.TopBar.BackgroundTransparency = 1
	
	self.Title = Instance.new("TextLabel", self.TopBar)
	self.Title.BackgroundTransparency = 1
	self.Title.Position = UDim2.new(0, 30, 0, 0)
	self.Title.Size = UDim2.new(0, 200, 1, 0)
	self.Title.Text = self.Config.Title or "AURORAX"
	self.Title.Font = Enum.Font.GothamBold
	self.Title.TextSize = 20
	self.Title.TextColor3 = theme.Text
	self.Title.TextXAlignment = Enum.TextXAlignment.Left
	
	self.SubTitle = Instance.new("TextLabel", self.TopBar)
	self.SubTitle.BackgroundTransparency = 1
	self.SubTitle.Position = UDim2.new(0, 30, 0, 28)
	self.SubTitle.Size = UDim2.new(0, 200, 0, 20)
	self.SubTitle.Text = self.Config.Subtitle or "Settings"
	self.SubTitle.Font = Enum.Font.Gotham
	self.SubTitle.TextSize = 12
	self.SubTitle.TextColor3 = theme.TextDim
	self.SubTitle.TextXAlignment = Enum.TextXAlignment.Left
	
	-- 折叠按钮
	self.FoldBtn = Instance.new("TextButton", self.TopBar)
	self.FoldBtn.Size = UDim2.fromOffset(30, 30)
	self.FoldBtn.Position = UDim2.new(1, -45, 0.5, -15)
	self.FoldBtn.Text = "_"
	self.FoldBtn.Font = Enum.Font.GothamBold
	self.FoldBtn.TextSize = 16
	self.FoldBtn.TextColor3 = theme.Text
	self.FoldBtn.BackgroundColor3 = theme.Inactive
	self.FoldBtn.BorderSizePixel = 0
	Instance.new("UICorner", self.FoldBtn).CornerRadius = UDim.new(0, 8)
	
	self.FoldBtn.MouseEnter:Connect(function()
		TweenService:Create(self.FoldBtn, TweenInfo.new(0.2), {
			BackgroundColor3 = theme.InactiveHover
		}):Play()
	end)
	
	self.FoldBtn.MouseLeave:Connect(function()
		TweenService:Create(self.FoldBtn, TweenInfo.new(0.2), {
			BackgroundColor3 = theme.Inactive
		}):Play()
	end)
	
	self.FoldBtn.MouseButton1Click:Connect(function()
		if not self.isFolded then
			self:_toggleFold()
		end
	end)
end

-- ==========================================
-- 内部方法：创建侧边栏
-- ==========================================
function AuroraX:_createSidebar()
	local theme = self.Theme
	
	self.Sidebar = Instance.new("Frame", self.Main)
	self.Sidebar.Size = UDim2.new(0, 170, 1, -55)
	self.Sidebar.Position = UDim2.new(0, 0, 0, 55)
	self.Sidebar.BackgroundColor3 = theme.Sidebar
	self.Sidebar.BorderSizePixel = 0
	
	Instance.new("UICorner", self.Sidebar).CornerRadius = UDim.new(0, 16)
	
	local fix = Instance.new("Frame", self.Sidebar)
	fix.Size = UDim2.fromOffset(20, 20)
	fix.Position = UDim2.new(1, -20, 0, 0)
	fix.BackgroundColor3 = theme.Sidebar
	fix.BorderSizePixel = 0
	
	self.TabContainer = Instance.new("Frame", self.Sidebar)
	self.TabContainer.Size = UDim2.new(1, 0, 1, -85)
	self.TabContainer.Position = UDim2.new(0, 0, 0, 10)
	self.TabContainer.BackgroundTransparency = 1
	
	local list = Instance.new("UIListLayout", self.TabContainer)
	list.Padding = UDim.new(0, 4)
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.SortOrder = Enum.SortOrder.LayoutOrder
end

-- ==========================================
-- 内部方法：创建页面容器
-- ==========================================
function AuroraX:_createPageContainer()
	self.PageContainer = Instance.new("Frame", self.Main)
	self.PageContainer.Size = UDim2.new(1, -195, 1, -75)
	self.PageContainer.Position = UDim2.new(0, 185, 0, 60)
	self.PageContainer.BackgroundTransparency = 1
end

-- ==========================================
-- 内部方法：创建用户卡片
-- ==========================================
function AuroraX:_createProfileCard()
	local theme = self.Theme
	
	self.ProfileFrame = Instance.new("Frame", self.Sidebar)
	self.ProfileFrame.Size = UDim2.new(1, 0, 0, 75)
	self.ProfileFrame.Position = UDim2.new(0, 0, 1, -75)
	self.ProfileFrame.BackgroundTransparency = 1
	
	local avatar = Instance.new("ImageLabel", self.ProfileFrame)
	avatar.Size = UDim2.fromOffset(44, 44)
	avatar.Position = UDim2.new(0, 16, 0.5, -22)
	avatar.BackgroundColor3 = theme.Inactive
	avatar.BorderSizePixel = 0
	Instance.new("UICorner", avatar).CornerRadius = UDim.new(1, 0)
	
	local stroke = Instance.new("UIStroke", avatar)
	stroke.Color = theme.Accent
	stroke.Thickness = 2
	stroke.Transparency = 0.3
	
	task.spawn(function()
		pcall(function()
			local content, isReady = Players:GetUserThumbnailAsync(
				self.Player.UserId,
				Enum.ThumbnailType.HeadShot,
				Enum.ThumbnailSize.Size100x100
			)
			if isReady then
				avatar.Image = content
			end
		end)
	end)
	
	local nameLabel = Instance.new("TextLabel", self.ProfileFrame)
	nameLabel.Size = UDim2.new(1, -75, 0, 18)
	nameLabel.Position = UDim2.new(0, 75, 0.5, -18)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text = self.Player.DisplayName
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.TextSize = 13
	nameLabel.TextColor3 = theme.Text
	nameLabel.TextXAlignment = Enum.TextXAlignment.Left
	nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
	
	local timeLabel = Instance.new("TextLabel", self.ProfileFrame)
	timeLabel.Size = UDim2.new(1, -75, 0, 14)
	timeLabel.Position = UDim2.new(0, 75, 0.5, 2)
	timeLabel.BackgroundTransparency = 1
	timeLabel.Text = os.date("%H:%M")
	timeLabel.Font = Enum.Font.Gotham
	timeLabel.TextSize = 11
	timeLabel.TextColor3 = theme.TextDim
	timeLabel.TextXAlignment = Enum.TextXAlignment.Left
	
	task.spawn(function()
		while true do
			timeLabel.Text = os.date("%H:%M")
			task.wait(30)
		end
	end)
end

-- ==========================================
-- 内部方法：设置拖拽逻辑
-- ==========================================
function AuroraX:_setupDragLogic()
	self.Main.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			self.dragging = true
			self.dragMoved = false
			self.dragStart = input.Position
			self.startPos = self.Main.Position
		end
	end)
	
	UIS.InputChanged:Connect(function(input)
		if self.dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			if self.isFolded then
				local delta = input.Position - self.dragStart
				if delta.Magnitude > 5 then
					self.dragMoved = true
				end
				local newPos = UDim2.new(
					self.startPos.X.Scale,
					self.startPos.X.Offset + delta.X,
					self.startPos.Y.Scale,
					self.startPos.Y.Offset + delta.Y
				)
				self.Main.Position = newPos
				self.savedMiniPosition = newPos
			end
		end
	end)
	
	UIS.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			if self.dragging then
				self.dragging = false
				if self.isFolded and not self.dragMoved then
					self:_toggleFold()
				end
			end
		end
	end)
end

-- ==========================================
-- 内部方法：折叠/展开
-- ==========================================
function AuroraX:_toggleFold()
	self.isFolded = not self.isFolded
	local theme = self.Theme
	
	if self.isFolded then
		self.Sidebar.Visible = false
		self.PageContainer.Visible = false
		self.Title.Visible = false
		self.SubTitle.Visible = false
		
		self.SizeConstraint.MaxSize = Vector2.new(9999, 9999)
		self.SizeConstraint.MinSize = Vector2.new(0, 0)
		
		self.FoldBtn.AnchorPoint = Vector2.new(0.5, 0.5)
		self.FoldBtn.Position = UDim2.fromScale(0.5, 0.5)
		self.FoldBtn.Size = UDim2.fromScale(1, 1)
		self.FoldBtn.Text = "*"
		self.FoldBtn.TextSize = 24
		self.FoldBtn.BackgroundColor3 = theme.Accent
		self.FoldBtn.Active = false
		
		self.Main.AnchorPoint = Vector2.new(0.5, 0.5)
		TweenService:Create(self.Main, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = UDim2.fromOffset(55, 55),
			Position = self.savedMiniPosition
		}):Play()
		TweenService:Create(self.Shadow, TweenInfo.new(0.3), {BackgroundTransparency = 1}):Play()
		TweenService:Create(self.Blur, TweenInfo.new(0.3), {Size = 0}):Play()
	else
		self.SizeConstraint.MaxSize = Vector2.new(700, 450)
		self.SizeConstraint.MinSize = Vector2.new(480, 300)
		
		self.FoldBtn.AnchorPoint = Vector2.new(0, 0)
		self.FoldBtn.Position = UDim2.new(1, -45, 0.5, -15)
		self.FoldBtn.Size = UDim2.fromOffset(30, 30)
		self.FoldBtn.Text = "_"
		self.FoldBtn.TextSize = 16
		self.FoldBtn.BackgroundColor3 = theme.Inactive
		self.FoldBtn.Active = true
		
		self.Main.AnchorPoint = Vector2.new(0.5, 0.5)
		TweenService:Create(self.Main, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Size = UDim2.new(0.65, 0, 0.6, 0),
			Position = UDim2.fromScale(0.5, 0.5)
		}):Play()
		TweenService:Create(self.Shadow, TweenInfo.new(0.3), {BackgroundTransparency = 0.7}):Play()
		TweenService:Create(self.Blur, TweenInfo.new(0.3), {Size = 16}):Play()
		
		task.wait(0.4)
		if not self.isFolded then
			self.Sidebar.Visible = true
			self.PageContainer.Visible = true
			self.Title.Visible = true
			self.SubTitle.Visible = true
		end
	end
end

-- ==========================================
-- 公共方法：切换Tab
-- ==========================================
function AuroraX:_switchTab(tabIndex)
	if self.CurrentTab == tabIndex then return end
	
	local oldTab = self.Tabs[self.CurrentTab]
	local newTab = self.Tabs[tabIndex]
	
	if oldTab then
		-- 隐藏旧页面
		oldTab.Page.Visible = false
		
		-- 动画：旧Tab退出
		TweenService:Create(oldTab.Button, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			BackgroundTransparency = 1,
			TextColor3 = self.Theme.TextDim
		}):Play()
	end
	
	if newTab then
		-- 显示新页面
		newTab.Page.Visible = true
		newTab.Page.CanvasPosition = Vector2.new(0, 0)
		
		-- 动画：新Tab进入
		TweenService:Create(newTab.Button, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			BackgroundTransparency = 0,
			TextColor3 = self.Theme.Text
		}):Play()
	end
	
	self.CurrentTab = tabIndex
end

-- ==========================================
-- 公共方法：发送通知
-- ==========================================
function AuroraX:Notify(title, message, notificationType, duration)
	self.NotificationSystem:Send(title, message, notificationType, duration)
end

-- ==========================================
-- 公共方法：创建Tab页面
-- ==========================================
function AuroraX:CreateTab(tabName, tabIcon)
	tabIcon = tabIcon or "+"
	
	local theme = self.Theme
	local tabIndex = #self.Tabs + 1
	
	-- 创建滚动页面
	local page = Instance.new("ScrollingFrame", self.PageContainer)
	page.Size = UDim2.fromScale(1, 1)
	page.BackgroundTransparency = 1
	page.ScrollBarThickness = 3
	page.ScrollBarImageColor3 = theme.Accent
	page.ScrollBarImageTransparency = 0.7
	page.Visible = false
	page.ScrollingDirection = Enum.ScrollingDirection.Y
	page.AutomaticCanvasSize = Enum.AutomaticSize.Y
	page.CanvasSize = UDim2.fromScale(0, 0)
	page.BottomImage = "rbxasset://textures/ui/Scroll/scroll-middle.png"
	page.TopImage = "rbxasset://textures/ui/Scroll/scroll-middle.png"
	page.ElasticBehavior = Enum.ElasticBehavior.Never
	
	local pageLayout = Instance.new("UIListLayout", page)
	pageLayout.Padding = UDim.new(0, 6)
	pageLayout.SortOrder = Enum.SortOrder.LayoutOrder
	
	local pagePadding = Instance.new("UIPadding", page)
	pagePadding.PaddingRight = UDim.new(0, 10)
	pagePadding.PaddingTop = UDim.new(0, 4)
	pagePadding.PaddingBottom = UDim.new(0, 12)
	
	-- 创建Tab按钮
	local tabBtn = Instance.new("TextButton", self.TabContainer)
	tabBtn.Size = UDim2.new(0, 150, 0, 42)
	tabBtn.Text = "   " .. tabIcon .. "  " .. tabName
	tabBtn.Font = Enum.Font.GothamBold
	tabBtn.TextSize = 13
	tabBtn.TextColor3 = theme.TextDim
	tabBtn.BackgroundColor3 = theme.Accent
	tabBtn.BackgroundTransparency = 1
	tabBtn.TextXAlignment = Enum.TextXAlignment.Left
	tabBtn.AutoButtonColor = false
	Instance.new("UICorner", tabBtn).CornerRadius = UDim.new(0, 10)
	
	tabBtn.MouseEnter:Connect(function()
		if self.CurrentTab ~= tabIndex then
			TweenService:Create(tabBtn, TweenInfo.new(0.2), {BackgroundTransparency = 0.85}):Play()
		end
	end)
	
	tabBtn.MouseLeave:Connect(function()
		if self.CurrentTab ~= tabIndex then
			TweenService:Create(tabBtn, TweenInfo.new(0.2), {BackgroundTransparency = 1}):Play()
		end
	end)
	
	tabBtn.MouseButton1Click:Connect(function()
		self:_switchTab(tabIndex)
	end)
	
	-- 存储Tab数据
	local tabData = {
		Button = tabBtn,
		Page = page,
		Index = tabIndex,
		Name = tabName
	}
	
	table.insert(self.Tabs, tabData)
	
	-- 如果是第一个Tab，默认激活
	if tabIndex == 1 then
		self.CurrentTab = 1
		page.Visible = true
		tabBtn.BackgroundTransparency = 0
		tabBtn.TextColor3 = theme.Text
	end
	
	-- 返回页面对象用于添加控件
	return {
		Page = page,
		TabIndex = tabIndex,
		TabName = tabName,
		Library = self
	}
end

-- ==========================================
-- 控件工厂函数
-- ==========================================

-- 分区标题
function AuroraX:CreateSection(pageObj, text)
	local parent = pageObj.Page
	local theme = self.Theme
	
	local label = Instance.new("TextLabel", parent)
	label.BackgroundTransparency = 1
	label.Size = UDim2.new(1, 0, 0, 24)
	label.Text = text
	label.Font = Enum.Font.GothamBold
	label.TextSize = 11
	label.TextColor3 = theme.Accent
	label.TextXAlignment = Enum.TextXAlignment.Left
	
	return label
end

-- 间距器
function AuroraX:CreateSpacer(pageObj, height)
	local parent = pageObj.Page
	
	local spacer = Instance.new("Frame", parent)
	spacer.BackgroundTransparency = 1
	spacer.Size = UDim2.new(1, 0, 0, height or 6)
	
	return spacer
end

-- 滑块
function AuroraX:CreateSlider(pageObj, config)
	config = config or {}
	local parent = pageObj.Page
	local theme = self.Theme
	
	local text = config.Text or "Slider"
	local defaultPercent = config.Default or 0.5
	local callback = config.Callback
	
	local container = Instance.new("Frame", parent)
	container.BackgroundTransparency = 1
	container.Size = UDim2.new(1, 0, 0, 48)
	
	local label = Instance.new("TextLabel", container)
	label.BackgroundTransparency = 1
	label.Size = UDim2.new(0, 110, 0, 20)
	label.Position = UDim2.new(0, 0, 0, 0)
	label.Text = text
	label.Font = Enum.Font.Gotham
	label.TextSize = 12
	label.TextColor3 = theme.Text
	label.TextXAlignment = Enum.TextXAlignment.Left
	
	local valueLabel = Instance.new("TextLabel", container)
	valueLabel.BackgroundTransparency = 1
	valueLabel.Size = UDim2.new(0, 45, 0, 20)
	valueLabel.Position = UDim2.new(0, 115, 0, 0)
	valueLabel.Text = math.round(defaultPercent * 100) .. "%"
	valueLabel.Font = Enum.Font.GothamBold
	valueLabel.TextSize = 12
	valueLabel.TextColor3 = theme.Accent
	valueLabel.TextXAlignment = Enum.TextXAlignment.Left
	
	local barBG = Instance.new("Frame", container)
	barBG.BackgroundColor3 = theme.Inactive
	barBG.Size = UDim2.new(1, -10, 0, 8)
	barBG.Position = UDim2.new(0, 0, 1, -14)
	barBG.BorderSizePixel = 0
	Instance.new("UICorner", barBG).CornerRadius = UDim.new(1, 0)
	
	local fill = Instance.new("Frame", barBG)
	fill.BackgroundColor3 = theme.Accent
	fill.Size = UDim2.fromScale(defaultPercent, 1)
	fill.BorderSizePixel = 0
	Instance.new("UICorner", fill).CornerRadius = UDim.new(1, 0)
	
	local knob = Instance.new("Frame", fill)
	knob.BackgroundColor3 = theme.Text
	knob.Size = UDim2.fromOffset(18, 18)
	knob.Position = UDim2.new(1, -9, 0.5, -9)
	knob.BorderSizePixel = 0
	Instance.new("UICorner", knob).CornerRadius = UDim.new(1, 0)
	
	local currentPercent = defaultPercent
	local draggingSlider = false
	
	local function updateVisual(percent)
		currentPercent = percent
		TweenService:Create(fill, TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = UDim2.fromScale(percent, 1)
		}):Play()
		valueLabel.Text = math.round(percent * 100) .. "%"
		if callback then callback(percent) end
	end
	
	barBG.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			draggingSlider = true
			local mouseX = input.Position.X
			local barPos = barBG.AbsolutePosition.X
			local barSize = barBG.AbsoluteSize.X
			local percent = math.clamp((mouseX - barPos) / barSize, 0, 1)
			updateVisual(percent)
		end
	end)
	
	UIS.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			draggingSlider = false
		end
	end)
	
	UIS.InputChanged:Connect(function(input)
		if draggingSlider and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			local mouseX = input.Position.X
			local barPos = barBG.AbsolutePosition.X
			local barSize = barBG.AbsoluteSize.X
			local percent = math.clamp((mouseX - barPos) / barSize, 0, 1)
			updateVisual(percent)
		end
	end)
	
	return {
		Container = container,
		SetValue = function(newPercent)
			updateVisual(math.clamp(newPercent, 0, 1))
		end,
		GetValue = function()
			return currentPercent
		end
	}
end

-- 开关
function AuroraX:CreateToggle(pageObj, config)
	config = config or {}
	local parent = pageObj.Page
	local theme = self.Theme
	
	local text = config.Text or "Toggle"
	local defaultState = config.Default or false
	local callback = config.Callback
	
	local state = defaultState
	
	local container = Instance.new("Frame", parent)
	container.BackgroundTransparency = 1
	container.Size = UDim2.new(1, 0, 0, 40)
	
	local label = Instance.new("TextLabel", container)
	label.BackgroundTransparency = 1
	label.Size = UDim2.new(0, 140, 0, 20)
	label.Position = UDim2.new(0, 0, 0.5, -10)
	label.Text = text
	label.Font = Enum.Font.Gotham
	label.TextSize = 12
	label.TextColor3 = theme.Text
	label.TextXAlignment = Enum.TextXAlignment.Left
	
	local toggleBtn = Instance.new("TextButton", container)
	toggleBtn.Size = UDim2.fromOffset(48, 26)
	toggleBtn.Position = UDim2.new(1, -48, 0.5, -13)
	toggleBtn.Text = ""
	toggleBtn.BackgroundColor3 = state and theme.Accent or theme.Inactive
	toggleBtn.AutoButtonColor = false
	toggleBtn.BorderSizePixel = 0
	Instance.new("UICorner", toggleBtn).CornerRadius = UDim.new(1, 0)
	
	local knob = Instance.new("Frame", toggleBtn)
	knob.Size = UDim2.fromOffset(20, 20)
	knob.Position = state and UDim2.new(1, -23, 0.5, -10) or UDim2.new(0, 3, 0.5, -10)
	knob.BackgroundColor3 = theme.Text
	knob.BorderSizePixel = 0
	Instance.new("UICorner", knob).CornerRadius = UDim.new(1, 0)
	
	toggleBtn.MouseButton1Click:Connect(function()
		state = not state
		local goalPos = state and UDim2.new(1, -23, 0.5, -10) or UDim2.new(0, 3, 0.5, -10)
		local goalColor = state and theme.Accent or theme.Inactive
		
		TweenService:Create(knob, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Position = goalPos
		}):Play()
		
		TweenService:Create(toggleBtn, TweenInfo.new(0.25), {
			BackgroundColor3 = goalColor
		}):Play()
		
		self:Notify(text, "Turned " .. (state and "ON" or "OFF"), state and "Success" or "Info")
		
		if callback then callback(state) end
	end)
	
	return {
		Container = container,
		SetState = function(newState)
			state = newState
			local goalPos = state and UDim2.new(1, -23, 0.5, -10) or UDim2.new(0, 3, 0.5, -10)
			local goalColor = state and theme.Accent or theme.Inactive
			knob.Position = goalPos
			toggleBtn.BackgroundColor3 = goalColor
		end,
		GetState = function()
			return state
		end
	}
end

-- 分段控制器
function AuroraX:CreateSegment(pageObj, config)
	config = config or {}
	local parent = pageObj.Page
	local theme = self.Theme
	
	local text = config.Text or "Segment"
	local options = config.Options or {"Option 1", "Option 2"}
	local callback = config.Callback
	
	local currentIndex = 1
	
	local container = Instance.new("Frame", parent)
	container.BackgroundTransparency = 1
	container.Size = UDim2.new(1, 0, 0, 52)
	
	local label = Instance.new("TextLabel", container)
	label.BackgroundTransparency = 1
	label.Size = UDim2.new(1, 0, 0, 20)
	label.Position = UDim2.new(0, 0, 0, 0)
	label.Text = text
	label.Font = Enum.Font.Gotham
	label.TextSize = 12
	label.TextColor3 = theme.Text
	label.TextXAlignment = Enum.TextXAlignment.Left
	
	local segmentBG = Instance.new("Frame", container)
	segmentBG.Size = UDim2.new(1, -10, 0, 32)
	segmentBG.Position = UDim2.new(0, 0, 1, -32)
	segmentBG.BackgroundColor3 = theme.Inactive
	segmentBG.BorderSizePixel = 0
	Instance.new("UICorner", segmentBG).CornerRadius = UDim.new(0, 8)
	
	local optCount = #options
	local optWidth = 1 / optCount
	
	local slider = Instance.new("Frame", segmentBG)
	slider.Size = UDim2.fromScale(optWidth - 0.04, 0.78)
	slider.Position = UDim2.fromScale(0.02, 0.11)
	slider.BackgroundColor3 = theme.Accent
	slider.BorderSizePixel = 0
	slider.ZIndex = 1
	Instance.new("UICorner", slider).CornerRadius = UDim.new(0, 6)
	
	local buttons = {}
	for i, opt in ipairs(options) do
		local btn = Instance.new("TextButton", segmentBG)
		btn.Size = UDim2.fromScale(optWidth, 1)
		btn.Position = UDim2.fromScale((i - 1) * optWidth, 0)
		btn.Text = opt
		btn.Font = Enum.Font.GothamBold
		btn.TextSize = 11
		btn.TextColor3 = (i == 1) and theme.Text or theme.TextDim
		btn.BackgroundTransparency = 1
		btn.BorderSizePixel = 0
		btn.ZIndex = 2
		btn.AutoButtonColor = false
		table.insert(buttons, btn)
		
		btn.MouseButton1Click:Connect(function()
			if currentIndex == i then return end
			currentIndex = i
			
			TweenService:Create(slider, TweenInfo.new(0.3, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out), {
				Position = UDim2.fromScale((i - 1) * optWidth + 0.02, 0.11)
			}):Play()
			
			for idx, b in ipairs(buttons) do
				local targetColor = (idx == i) and theme.Text or theme.TextDim
				TweenService:Create(b, TweenInfo.new(0.2), {TextColor3 = targetColor}):Play()
			end
			
			self:Notify(text, "Set to " .. opt, "Info")
			
			if callback then callback(opt, i) end
		end)
	end
	
	return {
		Container = container,
		SetIndex = function(index)
			if index >= 1 and index <= #options and index ~= currentIndex then
				currentIndex = index
				slider.Position = UDim2.fromScale((index - 1) * optWidth + 0.02, 0.11)
				for idx, b in ipairs(buttons) do
					b.TextColor3 = (idx == index) and theme.Text or theme.TextDim
				end
			end
		end,
		GetIndex = function()
			return currentIndex
		end,
		GetValue = function()
			return options[currentIndex]
		end
	}
end

-- 多选框
function AuroraX:CreateCheckbox(pageObj, config)
	config = config or {}
	local parent = pageObj.Page
	local theme = self.Theme
	
	local text = config.Text or "Checkbox"
	local defaultState = config.Default or false
	local callback = config.Callback
	
	local state = defaultState
	
	local container = Instance.new("Frame", parent)
	container.BackgroundTransparency = 1
	container.Size = UDim2.new(1, 0, 0, 36)
	
	local checkFrame = Instance.new("Frame", container)
	checkFrame.Size = UDim2.fromOffset(22, 22)
	checkFrame.Position = UDim2.new(0, 0, 0.5, -11)
	checkFrame.BackgroundColor3 = state and theme.Accent or theme.Inactive
	checkFrame.BorderSizePixel = 0
	Instance.new("UICorner", checkFrame).CornerRadius = UDim.new(0, 5)
	
	local checkMark = Instance.new("TextLabel", checkFrame)
	checkMark.Size = UDim2.fromScale(1, 1)
	checkMark.BackgroundTransparency = 1
	checkMark.Text = "V"
	checkMark.Font = Enum.Font.GothamBold
	checkMark.TextSize = 14
	checkMark.TextColor3 = theme.Text
	checkMark.TextTransparency = state and 0 or 1
	
	local label = Instance.new("TextLabel", container)
	label.BackgroundTransparency = 1
	label.Size = UDim2.new(1, -35, 0, 22)
	label.Position = UDim2.new(0, 35, 0.5, -11)
	label.Text = text
	label.Font = Enum.Font.Gotham
	label.TextSize = 12
	label.TextColor3 = theme.Text
	label.TextXAlignment = Enum.TextXAlignment.Left
	
	local button = Instance.new("TextButton", container)
	button.Size = UDim2.fromScale(1, 1)
	button.BackgroundTransparency = 1
	button.Text = ""
	button.ZIndex = 5
	
	button.MouseButton1Click:Connect(function()
		state = not state
		TweenService:Create(checkMark, TweenInfo.new(0.2), {TextTransparency = state and 0 or 1}):Play()
		TweenService:Create(checkFrame, TweenInfo.new(0.2), {BackgroundColor3 = state and theme.Accent or theme.Inactive}):Play()
		if callback then callback(state) end
	end)
	
	return {
		Container = container,
		SetState = function(newState)
			state = newState
			checkMark.TextTransparency = state and 0 or 1
			checkFrame.BackgroundColor3 = state and theme.Accent or theme.Inactive
		end,
		GetState = function()
			return state
		end
	}
end

-- 输入框
function AuroraX:CreateInput(pageObj, config)
	config = config or {}
	local parent = pageObj.Page
	local theme = self.Theme
	
	local labelText = config.Text or "Input"
	local placeholder = config.Placeholder or "Enter text..."
	local defaultText = config.Default or ""
	local callback = config.Callback
	
	local container = Instance.new("Frame", parent)
	container.BackgroundTransparency = 1
	container.Size = UDim2.new(1, 0, 0, 58)
	
	local label = Instance.new("TextLabel", container)
	label.BackgroundTransparency = 1
	label.Size = UDim2.new(1, 0, 0, 18)
	label.Text = labelText
	label.Font = Enum.Font.Gotham
	label.TextSize = 12
	label.TextColor3 = theme.Text
	label.TextXAlignment = Enum.TextXAlignment.Left
	
	local inputBG = Instance.new("Frame", container)
	inputBG.Size = UDim2.new(1, -10, 0, 34)
	inputBG.Position = UDim2.new(0, 0, 1, -34)
	inputBG.BackgroundColor3 = theme.Inactive
	inputBG.BorderSizePixel = 0
	Instance.new("UICorner", inputBG).CornerRadius = UDim.new(0, 6)
	
	local inputStroke = Instance.new("UIStroke", inputBG)
	inputStroke.Color = theme.Accent
	inputStroke.Thickness = 1.5
	inputStroke.Transparency = 1
	
	local textBox = Instance.new("TextBox", inputBG)
	textBox.Size = UDim2.new(1, -20, 1, 0)
	textBox.Position = UDim2.new(0, 10, 0, 0)
	textBox.BackgroundTransparency = 1
	textBox.PlaceholderText = placeholder
	textBox.Text = defaultText
	textBox.Font = Enum.Font.Gotham
	textBox.TextSize = 12
	textBox.TextColor3 = theme.Text
	textBox.PlaceholderColor3 = theme.TextDim
	textBox.TextXAlignment = Enum.TextXAlignment.Left
	textBox.ClearTextOnFocus = false
	
	textBox.Focused:Connect(function()
		TweenService:Create(inputStroke, TweenInfo.new(0.3), {Transparency = 0}):Play()
	end)
	
	textBox.FocusLost:Connect(function(enterPressed)
		TweenService:Create(inputStroke, TweenInfo.new(0.3), {Transparency = 1}):Play()
		if callback then callback(textBox.Text, enterPressed) end
	end)
	
	return {
		Container = container,
		SetText = function(newText)
			textBox.Text = newText
		end,
		GetText = function()
			return textBox.Text
		end,
		TextBox = textBox
	}
end

-- 按钮
function AuroraX:CreateButton(pageObj, config)
	config = config or {}
	local parent = pageObj.Page
	local theme = self.Theme
	
	local text = config.Text or "Button"
	local buttonType = config.Type or "Primary"
	local callback = config.Callback
	
	local styles = {
		Primary = {
			BG = theme.Accent,
			HoverBG = Color3.fromRGB(129, 140, 248),
			TextColor = theme.Text
		},
		Secondary = {
			BG = theme.Inactive,
			HoverBG = theme.InactiveHover,
			TextColor = theme.Text
		},
		Danger = {
			BG = Color3.fromRGB(239, 68, 68),
			HoverBG = Color3.fromRGB(248, 113, 113),
			TextColor = theme.Text
		}
	}
	
	local style = styles[buttonType] or styles.Primary
	
	local container = Instance.new("Frame", parent)
	container.BackgroundTransparency = 1
	container.Size = UDim2.new(1, 0, 0, 44)
	
	local btnFrame = Instance.new("TextButton", container)
	btnFrame.Size = UDim2.new(0, 200, 0, 36)
	btnFrame.Position = UDim2.new(0, 0, 0.5, -18)
	btnFrame.Text = ""
	btnFrame.BackgroundColor3 = style.BG
	btnFrame.AutoButtonColor = false
	btnFrame.BorderSizePixel = 0
	Instance.new("UICorner", btnFrame).CornerRadius = UDim.new(0, 8)
	
	local btnLabel = Instance.new("TextLabel", btnFrame)
	btnLabel.Size = UDim2.fromScale(1, 1)
	btnLabel.BackgroundTransparency = 1
	btnLabel.Text = text
	btnLabel.Font = Enum.Font.GothamBold
	btnLabel.TextSize = 13
	btnLabel.TextColor3 = style.TextColor
	
	btnFrame.MouseEnter:Connect(function()
		TweenService:Create(btnFrame, TweenInfo.new(0.2), {BackgroundColor3 = style.HoverBG}):Play()
	end)
	
	btnFrame.MouseLeave:Connect(function()
		TweenService:Create(btnFrame, TweenInfo.new(0.2), {BackgroundColor3 = style.BG}):Play()
	end)
	
	btnFrame.MouseButton1Click:Connect(function()
		TweenService:Create(btnFrame, TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = UDim2.new(0, 190, 0, 34)
		}):Play()
		
		task.wait(0.1)
		
		TweenService:Create(btnFrame, TweenInfo.new(0.15, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Size = UDim2.new(0, 200, 0, 36)
		}):Play()
		
		self:Notify(text, "Action completed", "Success")
		
		if callback then callback() end
	end)
	
	return {
		Container = container,
		Click = function()
			if callback then callback() end
		end
	}
end

-- 手风琴
function AuroraX:CreateAccordion(pageObj, config)
	config = config or {}
	local parent = pageObj.Page
	local theme = self.Theme
	
	local title = config.Text or "Accordion"
	
	local mainContainer = Instance.new("Frame", parent)
	mainContainer.BackgroundTransparency = 1
	mainContainer.Size = UDim2.new(1, -10, 0, 40)
	mainContainer.ClipsDescendants = false
	
	local headerBtn = Instance.new("TextButton", mainContainer)
	headerBtn.Size = UDim2.new(1, 0, 0, 40)
	headerBtn.BackgroundColor3 = theme.CardBackground
	headerBtn.BorderSizePixel = 0
	headerBtn.Text = ""
	headerBtn.AutoButtonColor = false
	headerBtn.ZIndex = 10
	Instance.new("UICorner", headerBtn).CornerRadius = UDim.new(0, 8)
	
	local titleLabel = Instance.new("TextLabel", headerBtn)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Size = UDim2.new(1, -40, 1, 0)
	titleLabel.Position = UDim2.new(0, 15, 0, 0)
	titleLabel.Text = title
	titleLabel.Font = Enum.Font.GothamBold
	titleLabel.TextSize = 12
	titleLabel.TextColor3 = theme.Text
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	titleLabel.ZIndex = 11
	
	local arrowIcon = Instance.new("TextLabel", headerBtn)
	arrowIcon.BackgroundTransparency = 1
	arrowIcon.Size = UDim2.fromOffset(20, 20)
	arrowIcon.Position = UDim2.new(1, -35, 0.5, -10)
	arrowIcon.Text = ">"
	arrowIcon.Font = Enum.Font.Gotham
	arrowIcon.TextSize = 12
	arrowIcon.TextColor3 = theme.TextDim
	arrowIcon.Rotation = 90
	arrowIcon.ZIndex = 11
	
	local contentArea = Instance.new("Frame", mainContainer)
	contentArea.BackgroundTransparency = 1
	contentArea.Size = UDim2.new(1, 0, 0, 0)
	contentArea.Position = UDim2.new(0, 0, 0, 44)
	contentArea.Visible = false
	contentArea.ClipsDescendants = false
	
	local contentList = Instance.new("UIListLayout", contentArea)
	contentList.Padding = UDim.new(0, 4)
	
	local isOpen = false
	local isAnimating = false
	
	local function findParentScrollingFrame(obj)
		local current = obj
		while current do
			if current:IsA("ScrollingFrame") then
				return current
			end
			current = current.Parent
		end
		return nil
	end
	
	local function updateCanvasSize()
		local scrollFrame = findParentScrollingFrame(mainContainer)
		if scrollFrame then
			scrollFrame.CanvasSize = UDim2.fromScale(0, 0)
			scrollFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
		end
	end
	
	headerBtn.MouseButton1Click:Connect(function()
		if isAnimating then return end
		isAnimating = true
		isOpen = not isOpen
		
		local totalContentHeight = 0
		for _, item in ipairs(contentArea:GetChildren()) do
			if item:IsA("GuiObject") and item ~= contentList then
				totalContentHeight = totalContentHeight + item.Size.Y.Offset + contentList.Padding.Offset
			end
		end
		totalContentHeight = totalContentHeight + 8
		
		if isOpen then
			contentArea.Visible = true
			contentArea.Size = UDim2.new(1, 0, 0, totalContentHeight)
			
			TweenService:Create(mainContainer, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Size = UDim2.new(1, -10, 0, 40 + totalContentHeight + 4)
			}):Play()
			
			TweenService:Create(arrowIcon, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Rotation = 270
			}):Play()
		else
			TweenService:Create(mainContainer, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Size = UDim2.new(1, -10, 0, 40)
			}):Play()
			
			TweenService:Create(arrowIcon, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Rotation = 90
			}):Play()
			
			task.delay(0.3, function()
				contentArea.Visible = false
				contentArea.Size = UDim2.new(1, 0, 0, 0)
			end)
		end
		
		task.delay(0.35, function()
			updateCanvasSize()
			isAnimating = false
		end)
	end)
	
	-- 返回内容区域和主容器，方便添加控件
	return {
		Content = contentArea,
		Container = mainContainer,
		IsOpen = function() return isOpen end,
		Toggle = function()
			-- 可以手动切换
			if not isAnimating then
				-- 模拟点击
				headerBtn.MouseButton1Click:Fire()
			end
		end
	}
end

-- ==========================================
-- 公共方法：切换Tab（高级）
-- ==========================================
function AuroraX:SwitchTab(tabIndex)
	self:_switchTab(tabIndex)
end

-- ==========================================
-- 公共方法：设置主题
-- ==========================================
function AuroraX:SetTheme(newTheme)
	for k, v in pairs(newTheme) do
		self.Theme[k] = v
	end
end

-- ==========================================
-- 公共方法：销毁UI
-- ==========================================
function AuroraX:Destroy()
	safeDestroy(self.Blur)
	self.NotificationSystem:Destroy()
	safeDestroy(self.Gui)
	
	self.Tabs = {}
	self.Pages = {}
end

-- ==========================================
-- 导出库
-- ==========================================
return AuroraX