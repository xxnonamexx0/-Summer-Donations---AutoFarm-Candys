local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CONFIG = {
	Title = "Candy Teleporter",
	Version = "v1.0",
	FolderName = "ActiveCandies",
	IdleDelay = 0.25,
	HitboxName = "ColorHitbox",
	HeightOffset = 0,
	ClaimTimeout = 4.1,
	NextDelay = 0.15,
	BlockedGuiName = "UiBackroundAnimGui",
	ToggleKey = Enum.KeyCode.T,
	Credits = {
		Creator = "xx_userhackxx",
	},
}

local THEME = {
	Background = Color3.fromRGB(24, 24, 30),
	Header = Color3.fromRGB(34, 34, 43),
	Stroke = Color3.fromRGB(60, 60, 75),
	Text = Color3.fromRGB(235, 235, 245),
	SubText = Color3.fromRGB(150, 150, 170),
	Off = Color3.fromRGB(70, 70, 85),
	On = Color3.fromRGB(88, 214, 141),
	Accent = Color3.fromRGB(255, 120, 170),
	TabActive = Color3.fromRGB(255, 111, 0),
	TabIdle = Color3.fromRGB(52, 52, 64),
	TabHover = Color3.fromRGB(72, 72, 88),
	Danger = Color3.fromRGB(150, 55, 65),
	Error = Color3.fromRGB(235, 100, 100),
	Knob = Color3.fromRGB(255, 255, 255),
}

local TAB_ORDER = { "Candy", "Settings", "Credits" }
local WINDOW_WIDTH = 300
local WINDOW_HEIGHT = 250
local HEADER_HEIGHT = 38
local WINDOW_MARGIN = 12
local MIN_SCALE = 0.4
local TWEEN_FAST = TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local player = Players.LocalPlayer
local connections = {}
local suppressionConnections = {}
local runId = 0
local running = false
local claimed = false
local collectedCount = 0
local listeningForKey = false
local destroyArmed = false
local destroyed = false
local minimized = false
local selectedTab = nil
local currentScale = 1
local windowPixelPosition = nil

local function track(connection)
	table.insert(connections, connection)
	return connection
end

local function create(className, properties, children)
	local instance = Instance.new(className)
	for key, value in pairs(properties) do
		instance[key] = value
	end
	for _, child in ipairs(children or {}) do
		child.Parent = instance
	end
	return instance
end

local function corner(radius)
	return create("UICorner", { CornerRadius = UDim.new(0, radius) })
end

local function stroke(color, thickness)
	return create("UIStroke", {
		Color = color,
		Thickness = thickness,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
end

local function textLabel(properties)
	local merged = {
		BackgroundTransparency = 1,
		Font = Enum.Font.Gotham,
		TextColor3 = THEME.Text,
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Left,
	}
	for key, value in pairs(properties) do
		merged[key] = value
	end
	return create("TextLabel", merged)
end

local function textButton(properties, children)
	local merged = {
		AutoButtonColor = true,
		Font = Enum.Font.GothamMedium,
		TextColor3 = THEME.Text,
		TextSize = 13,
		BorderSizePixel = 0,
	}
	for key, value in pairs(properties) do
		merged[key] = value
	end
	return create("TextButton", merged, children)
end

local function buildHeader(main)
	local header = create("Frame", {
		Name = "Header",
		Size = UDim2.new(1, 0, 0, HEADER_HEIGHT),
		BackgroundColor3 = THEME.Header,
		BorderSizePixel = 0,
		Parent = main,
	}, { corner(12) })

	create("Frame", {
		Name = "HeaderFill",
		Size = UDim2.new(1, 0, 0, 12),
		Position = UDim2.new(0, 0, 1, -12),
		BackgroundColor3 = THEME.Header,
		BorderSizePixel = 0,
		Parent = header,
	})

	create("Frame", {
		Name = "Accent",
		Size = UDim2.fromOffset(4, 16),
		Position = UDim2.fromOffset(14, 11),
		BackgroundColor3 = THEME.Accent,
		BorderSizePixel = 0,
		Parent = header,
	}, { corner(2) })

	textLabel({
		Name = "Title",
		Size = UDim2.new(1, -90, 1, 0),
		Position = UDim2.fromOffset(28, 0),
		Font = Enum.Font.GothamBold,
		Text = CONFIG.Title,
		TextSize = 15,
		Parent = header,
	})

	local minimize = textButton({
		Name = "Minimize",
		Size = UDim2.fromOffset(26, 26),
		Position = UDim2.new(1, -36, 0, 6),
		BackgroundColor3 = THEME.Background,
		Font = Enum.Font.GothamBold,
		Text = "–",
		TextColor3 = THEME.SubText,
		TextSize = 16,
		Parent = header,
	}, { corner(6) })

	return header, minimize
end

local function buildTabBar(body)
	local tabBar = create("Frame", {
		Name = "TabBar",
		Size = UDim2.new(1, -20, 0, 26),
		Position = UDim2.fromOffset(10, 6),
		BackgroundTransparency = 1,
		Parent = body,
	}, {
		create("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, 4),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})

	local tabButtons = {}
	for index, name in ipairs(TAB_ORDER) do
		tabButtons[name] = textButton({
			Name = name .. "Tab",
			LayoutOrder = index,
			Size = UDim2.new(1 / 3, -3, 1, 0),
			BackgroundColor3 = THEME.TabIdle,
			AutoButtonColor = false,
			Text = name,
			TextColor3 = THEME.SubText,
			Parent = tabBar,
		}, { corner(6) })
	end

	return tabButtons
end

local function buildCandyPage(pages)
	local page = create("Frame", {
		Name = "CandyPage",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Parent = pages,
	})

	textLabel({
		Name = "SwitchLabel",
		Size = UDim2.new(1, -90, 0, 26),
		Position = UDim2.fromOffset(16, 8),
		Font = Enum.Font.GothamMedium,
		Text = "Auto Candy",
		TextSize = 14,
		Parent = page,
	})

	local switch = textButton({
		Name = "Switch",
		Size = UDim2.fromOffset(52, 26),
		Position = UDim2.new(1, -68, 0, 8),
		BackgroundColor3 = THEME.Off,
		AutoButtonColor = false,
		Text = "",
		Parent = page,
	}, { corner(13) })

	local knob = create("Frame", {
		Name = "Knob",
		Size = UDim2.fromOffset(20, 20),
		Position = UDim2.fromOffset(3, 3),
		BackgroundColor3 = THEME.Knob,
		BorderSizePixel = 0,
		Parent = switch,
	}, { corner(10) })

	local status = textLabel({
		Name = "Status",
		Size = UDim2.new(1, -32, 0, 18),
		Position = UDim2.fromOffset(16, 46),
		Text = "Idle",
		TextColor3 = THEME.SubText,
		Parent = page,
	})

	local track = create("Frame", {
		Name = "Track",
		Size = UDim2.new(1, -32, 0, 8),
		Position = UDim2.fromOffset(16, 70),
		BackgroundColor3 = THEME.Off,
		BorderSizePixel = 0,
		Parent = page,
	}, { corner(4) })

	local fill = create("Frame", {
		Name = "Fill",
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = THEME.Accent,
		BorderSizePixel = 0,
		Parent = track,
	}, { corner(4) })

	textLabel({
		Name = "Description",
		Size = UDim2.new(1, -32, 0, 36),
		Position = UDim2.fromOffset(16, 90),
		Text = "Teleports to every candy in ActiveCandies and moves on as soon as it is collected.",
		TextColor3 = THEME.SubText,
		TextSize = 12,
		TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Top,
		Parent = page,
	})

	local keybindHint = textLabel({
		Name = "KeybindHint",
		Size = UDim2.new(1, -32, 0, 14),
		Position = UDim2.new(0, 16, 1, -22),
		TextColor3 = THEME.SubText,
		TextSize = 11,
		Parent = page,
	})

	return page, switch, knob, status, fill, keybindHint
end

local function buildSettingsPage(pages)
	local page = create("Frame", {
		Name = "SettingsPage",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Parent = pages,
	})

	textLabel({
		Name = "KeybindLabel",
		Size = UDim2.new(1, -130, 0, 28),
		Position = UDim2.fromOffset(16, 10),
		Font = Enum.Font.GothamMedium,
		Text = "Toggle keybind",
		TextSize = 14,
		Parent = page,
	})

	local keybindButton = textButton({
		Name = "KeybindButton",
		Size = UDim2.fromOffset(100, 28),
		Position = UDim2.new(1, -116, 0, 10),
		BackgroundColor3 = THEME.Header,
		Text = "",
		Parent = page,
	}, { corner(6), stroke(THEME.Stroke, 1) })

	textLabel({
		Name = "KeybindNote",
		Size = UDim2.new(1, -32, 0, 30),
		Position = UDim2.fromOffset(16, 44),
		Text = "Click the button, then press a key. Esc cancels.",
		TextColor3 = THEME.SubText,
		TextSize = 11,
		TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Top,
		Parent = page,
	})

	create("Frame", {
		Name = "Divider",
		Size = UDim2.new(1, -32, 0, 1),
		Position = UDim2.fromOffset(16, 82),
		BackgroundColor3 = THEME.Stroke,
		BorderSizePixel = 0,
		Parent = page,
	})

	local destroyButton = textButton({
		Name = "DestroyButton",
		Size = UDim2.new(1, -32, 0, 32),
		Position = UDim2.fromOffset(16, 96),
		BackgroundColor3 = THEME.Danger,
		Text = "Destroy GUI",
		Parent = page,
	}, { corner(8) })

	textLabel({
		Name = "DestroyNote",
		Size = UDim2.new(1, -32, 0, 14),
		Position = UDim2.fromOffset(16, 134),
		Text = "Stops the script and removes the interface.",
		TextColor3 = THEME.SubText,
		TextSize = 11,
		Parent = page,
	})

	return page, keybindButton, destroyButton
end

local function buildCreditsPage(pages)
	local page = create("Frame", {
		Name = "CreditsPage",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Parent = pages,
	})

	textLabel({
		Name = "CreatorTitle",
		Size = UDim2.new(1, -32, 0, 16),
		Position = UDim2.fromOffset(16, 12),
		Text = "Made by",
		TextColor3 = THEME.SubText,
		TextSize = 12,
		Parent = page,
	})

	textLabel({
		Name = "CreatorName",
		Size = UDim2.new(1, -32, 0, 28),
		Position = UDim2.fromOffset(16, 30),
		Font = Enum.Font.GothamBold,
		Text = CONFIG.Credits.Creator,
		TextColor3 = THEME.Accent,
		TextSize = 20,
		Parent = page,
	})

	textLabel({
		Name = "Version",
		Size = UDim2.new(1, -32, 0, 14),
		Position = UDim2.new(0, 16, 1, -22),
		Text = CONFIG.Title .. " " .. CONFIG.Version,
		TextColor3 = THEME.SubText,
		TextSize = 11,
		Parent = page,
	})

	return page
end

local function buildGui()
	local screenGui = create("ScreenGui", {
		Name = "CandyTeleporter",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	})

	local main = create("Frame", {
		Name = "Main",
		Size = UDim2.fromOffset(WINDOW_WIDTH, WINDOW_HEIGHT),
		Position = UDim2.fromScale(0, 0),
		BackgroundColor3 = THEME.Background,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		Parent = screenGui,
	}, { corner(12), stroke(THEME.Stroke, 1.5), create("UIScale", { Name = "Scale" }) })

	local header, minimize = buildHeader(main)

	local body = create("Frame", {
		Name = "Body",
		Size = UDim2.new(1, 0, 1, -HEADER_HEIGHT),
		Position = UDim2.fromOffset(0, HEADER_HEIGHT),
		BackgroundTransparency = 1,
		Parent = main,
	})

	local tabButtons = buildTabBar(body)

	local pages = create("Frame", {
		Name = "Pages",
		Size = UDim2.new(1, 0, 1, -38),
		Position = UDim2.fromOffset(0, 38),
		BackgroundTransparency = 1,
		Parent = body,
	})

	local candyPage, switch, knob, status, fill, keybindHint = buildCandyPage(pages)
	local settingsPage, keybindButton, destroyButton = buildSettingsPage(pages)
	local creditsPage = buildCreditsPage(pages)

	return {
		ScreenGui = screenGui,
		Main = main,
		Scale = main:FindFirstChildOfClass("UIScale"),
		Header = header,
		Body = body,
		Minimize = minimize,
		TabButtons = tabButtons,
		Pages = {
			Candy = candyPage,
			Settings = settingsPage,
			Credits = creditsPage,
		},
		Switch = switch,
		Knob = knob,
		Status = status,
		Fill = fill,
		KeybindHint = keybindHint,
		KeybindButton = keybindButton,
		DestroyButton = destroyButton,
	}
end

local function makeDraggable(handle, getPosition, onDrag)
	local dragging = false
	local dragStart
	local startPosition

	track(handle.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			dragStart = input.Position
			startPosition = getPosition()
			input.Changed:Connect(function()
				if input.UserInputState == Enum.UserInputState.End then
					dragging = false
				end
			end)
		end
	end))

	track(UserInputService.InputChanged:Connect(function(input)
		if not dragging then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
			local delta = input.Position - dragStart
			onDrag(startPosition + Vector2.new(delta.X, delta.Y))
		end
	end))
end

local ui = buildGui()

local function getViewportSize()
	local size = ui.ScreenGui.AbsoluteSize
	if size.X > 0 and size.Y > 0 then
		return size
	end

	local camera = workspace.CurrentCamera
	if camera then
		return camera.ViewportSize
	end
	return nil
end

local function computeScale(viewport)
	local fitScale = math.min(
		(viewport.X - WINDOW_MARGIN * 2) / WINDOW_WIDTH,
		(viewport.Y - WINDOW_MARGIN * 2) / WINDOW_HEIGHT
	)
	local preferredScale = UserInputService.TouchEnabled and 1.15 or 1
	return math.clamp(math.min(preferredScale, fitScale), MIN_SCALE, 2)
end

local function applyLayout()
	local viewport = getViewportSize()
	if not viewport then
		return
	end

	currentScale = computeScale(viewport)
	ui.Scale.Scale = currentScale

	local width = WINDOW_WIDTH * currentScale
	local height = (minimized and HEADER_HEIGHT or WINDOW_HEIGHT) * currentScale
	local position = windowPixelPosition or Vector2.new(WINDOW_MARGIN, (viewport.Y - height) / 2)

	windowPixelPosition = Vector2.new(
		math.clamp(position.X, 0, math.max(0, viewport.X - width)),
		math.clamp(position.Y, 0, math.max(0, viewport.Y - height))
	)
	ui.Main.Position = UDim2.fromScale(windowPixelPosition.X / viewport.X, windowPixelPosition.Y / viewport.Y)
end

local function setStatus(text, color)
	ui.Status.Text = text
	ui.Status.TextColor3 = color or THEME.SubText
end

local function setProgress(ratio)
	TweenService:Create(ui.Fill, TWEEN_FAST, { Size = UDim2.fromScale(math.clamp(ratio, 0, 1), 1) }):Play()
end

local function setSwitchVisual(enabled)
	TweenService:Create(ui.Switch, TWEEN_FAST, {
		BackgroundColor3 = enabled and THEME.On or THEME.Off,
	}):Play()
	TweenService:Create(ui.Knob, TWEEN_FAST, {
		Position = enabled and UDim2.fromOffset(29, 3) or UDim2.fromOffset(3, 3),
	}):Play()
end

local function setTab(name)
	selectedTab = name
	for tabName, page in pairs(ui.Pages) do
		page.Visible = tabName == name
	end
	for tabName, button in pairs(ui.TabButtons) do
		local active = tabName == name
		button.BackgroundColor3 = active and THEME.TabActive or THEME.TabIdle
		button.TextColor3 = active and THEME.Background or THEME.SubText
	end
end

local function updateKeybindLabels()
	local keyName = CONFIG.ToggleKey.Name
	ui.KeybindButton.Text = listeningForKey and "Press a key…" or keyName
	ui.KeybindHint.Text = "Keybind: " .. keyName
end

local function toggleMinimize()
	minimized = not minimized
	applyLayout()
	ui.Body.Visible = not minimized
	ui.Minimize.Text = minimized and "+" or "–"
	TweenService:Create(ui.Main, TWEEN_FAST, {
		Size = UDim2.fromOffset(WINDOW_WIDTH, minimized and HEADER_HEIGHT or WINDOW_HEIGHT),
	}):Play()
end

local function getVisibilityProperty(gui)
	if gui:IsA("ScreenGui") then
		return "Enabled"
	end
	if gui:IsA("GuiObject") then
		return "Visible"
	end
	return nil
end

local function suppressGui(gui)
	local property = getVisibilityProperty(gui)
	if not property then
		return
	end

	gui[property] = false
	table.insert(suppressionConnections, gui:GetPropertyChangedSignal(property):Connect(function()
		if gui[property] then
			gui[property] = false
		end
	end))
end

local function stopSuppression()
	for _, connection in ipairs(suppressionConnections) do
		connection:Disconnect()
	end
	table.clear(suppressionConnections)
end

local function startSuppression()
	stopSuppression()

	local playerGui = player:WaitForChild("PlayerGui")
	local existing = playerGui:FindFirstChild(CONFIG.BlockedGuiName, true)
	if existing then
		suppressGui(existing)
	end

	table.insert(suppressionConnections, playerGui.DescendantAdded:Connect(function(descendant)
		if descendant.Name == CONFIG.BlockedGuiName then
			suppressGui(descendant)
		end
	end))
end

local function isCandyNotification(message, kind)
	if kind == "candy" then
		return true
	end
	return typeof(message) == "string" and message:lower():find("candy") ~= nil
end

local function listenForNotifications()
	local notificationEvent = ReplicatedStorage
		:WaitForChild("Network")
		:WaitForChild("RemoteEvents")
		:WaitForChild("NotificationEvent")

	if destroyed then
		return
	end

	track(notificationEvent.OnClientEvent:Connect(function(message, kind)
		if isCandyNotification(message, kind) then
			claimed = true
		end
	end))
end

local function getRootPart()
	local character = player.Character or player.CharacterAdded:Wait()
	return character:WaitForChild("HumanoidRootPart")
end

local function getNextCandy(visited)
	local folder = workspace:FindFirstChild(CONFIG.FolderName)
	if not folder then
		return nil, false
	end

	for _, candy in ipairs(folder:GetChildren()) do
		if candy:IsA("PVInstance") and not visited[candy] then
			return candy, true
		end
	end
	return nil, true
end

local function getCandyCFrame(candy)
	local hitbox = candy:FindFirstChild(CONFIG.HitboxName, true)
	if hitbox and hitbox:IsA("BasePart") then
		return hitbox.CFrame
	end
	return candy:GetPivot()
end

local function teleportTo(candy)
	local root = getRootPart()
	root.CFrame = getCandyCFrame(candy) + Vector3.new(0, CONFIG.HeightOffset, 0)
	root.AssemblyLinearVelocity = Vector3.zero
end

local function stop(message, color)
	running = false
	runId += 1
	stopSuppression()
	setSwitchVisual(false)
	setStatus(message or "Stopped", color)
end

local function waitForClaim(myId, candy)
	local elapsed = 0
	while not claimed and candy.Parent and elapsed < CONFIG.ClaimTimeout do
		if myId ~= runId then
			return false
		end
		setStatus(("Collected %d · waiting for candy %.1fs"):format(collectedCount, elapsed), THEME.Text)
		setProgress(elapsed / CONFIG.ClaimTimeout)
		task.wait(0.1)
		elapsed += 0.1
	end

	if myId ~= runId then
		return false
	end

	if claimed then
		collectedCount += 1
		setStatus(("Collected %d · candy collected"):format(collectedCount), THEME.On)
		setProgress(1)
		task.wait(CONFIG.NextDelay)
	elseif not candy.Parent then
		setStatus(("Collected %d · candy gone, skipping"):format(collectedCount), THEME.SubText)
	else
		setStatus(("Collected %d · no notification, skipping"):format(collectedCount), THEME.SubText)
	end

	return myId == runId
end

local function tour(myId)
	local visited = setmetatable({}, { __mode = "k" })

	while myId == runId do
		local candy, folderExists = getNextCandy(visited)

		if not folderExists then
			stop("Folder " .. CONFIG.FolderName .. " not found", THEME.Error)
			return
		end

		if candy then
			visited[candy] = true
			claimed = false
			teleportTo(candy)
			if not waitForClaim(myId, candy) then
				return
			end
		else
			setStatus(("Collected %d · waiting for new candies…"):format(collectedCount), THEME.SubText)
			setProgress(0)
			task.wait(CONFIG.IdleDelay)
		end
	end
end

local function start()
	runId += 1
	running = true
	collectedCount = 0
	startSuppression()
	setProgress(0)
	setSwitchVisual(true)
	setStatus("Starting…", THEME.Text)
	task.spawn(tour, runId)
end

local function toggle()
	if running then
		stop("Stopped")
	else
		start()
	end
end

local function beginKeybindCapture()
	listeningForKey = true
	updateKeybindLabels()
end

local function handleKeybindCapture(input)
	if input.UserInputType ~= Enum.UserInputType.Keyboard or input.KeyCode == Enum.KeyCode.Unknown then
		return
	end

	listeningForKey = false
	if input.KeyCode ~= Enum.KeyCode.Escape then
		CONFIG.ToggleKey = input.KeyCode
	end
	updateKeybindLabels()
end

local function destroyGui()
	destroyed = true
	running = false
	runId += 1
	stopSuppression()
	for _, connection in ipairs(connections) do
		connection:Disconnect()
	end
	table.clear(connections)
	ui.ScreenGui:Destroy()
end

local function requestDestroy()
	if destroyArmed then
		destroyGui()
		return
	end

	destroyArmed = true
	ui.DestroyButton.Text = "Click again to confirm"
	task.delay(3, function()
		if destroyed then
			return
		end
		destroyArmed = false
		ui.DestroyButton.Text = "Destroy GUI"
	end)
end

track(ui.Switch.MouseButton1Click:Connect(toggle))
track(ui.Minimize.MouseButton1Click:Connect(toggleMinimize))
track(ui.KeybindButton.MouseButton1Click:Connect(beginKeybindCapture))
track(ui.DestroyButton.MouseButton1Click:Connect(requestDestroy))

for _, name in ipairs(TAB_ORDER) do
	local button = ui.TabButtons[name]

	track(button.Activated:Connect(function()
		setTab(name)
	end))

	track(button.MouseEnter:Connect(function()
		if selectedTab ~= name then
			button.BackgroundColor3 = THEME.TabHover
		end
	end))

	track(button.MouseLeave:Connect(function()
		if selectedTab ~= name then
			button.BackgroundColor3 = THEME.TabIdle
		end
	end))
end

track(UserInputService.InputBegan:Connect(function(input, processed)
	if listeningForKey then
		handleKeybindCapture(input)
		return
	end
	if processed then
		return
	end
	if input.KeyCode == CONFIG.ToggleKey then
		toggle()
	end
end))

makeDraggable(ui.Header, function()
	return windowPixelPosition or Vector2.zero
end, function(position)
	windowPixelPosition = position
	applyLayout()
end)
task.spawn(listenForNotifications)

setTab("Candy")
updateKeybindLabels()
applyLayout()
ui.ScreenGui.Parent = player:WaitForChild("PlayerGui")
applyLayout()
track(ui.ScreenGui:GetPropertyChangedSignal("AbsoluteSize"):Connect(applyLayout))