--[[
	ZiniroxUI
	Librairie d'interface modulaire pour Roblox.

	Idée : ajouter un bouton, un indicateur (FPS, Ping...) ou un contrôle
	dans un onglet se fait en un seul appel de fonction, et l'affichage
	se met à jour tout seul (aucune position en dur à recalculer).
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer

local Theme = {
	RED = Color3.fromRGB(255, 23, 68),
	DARK = Color3.fromRGB(7, 7, 10),
	PANEL = Color3.fromRGB(14, 14, 19),
	PANEL2 = Color3.fromRGB(19, 19, 25),
	TEXT = Color3.fromRGB(247, 247, 250),
	MUTED = Color3.fromRGB(132, 132, 145),
	LINE = Color3.fromRGB(43, 43, 53),
}

local function new(className, props, parent)
	local obj = Instance.new(className)
	for k, v in pairs(props or {}) do obj[k] = v end
	obj.Parent = parent
	return obj
end

local function corner(parent, radius)
	return new("UICorner", {CornerRadius = UDim.new(0, radius)}, parent)
end

local function stroke(parent, color, transparency, thickness)
	return new("UIStroke", {
		Color = color or Theme.LINE,
		Transparency = transparency or 0,
		Thickness = thickness or 1,
	}, parent)
end

local function tween(obj, info, props)
	local t = TweenService:Create(obj, info, props)
	t:Play()
	return t
end

local Library = {}
Library.__index = Library

--============================================================
-- Construction de la fenêtre
--============================================================

function Library.new(config)
	config = config or {}
	local self = setmetatable({}, Library)

	self.Theme = Theme
	self._tabs = {}
	self._topWidgets = {}

	local playerGui = player:WaitForChild("PlayerGui")

	local gui = new("ScreenGui", {
		Name = config.Name or "ZiniroxUI",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = 50,
	}, playerGui)
	self.Gui = gui

	local overlay = new("Frame", {
		Name = "Overlay",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(0, 0, 0),
		BackgroundTransparency = 0.35,
		BorderSizePixel = 0,
	}, gui)
	self.Overlay = overlay

	local main = new("Frame", {
		Name = "Main",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(0, config.Width or 1000, 0, config.Height or 620),
		BackgroundColor3 = Theme.DARK,
		BorderSizePixel = 0,
	}, overlay)
	corner(main, 22)
	stroke(main, Color3.fromRGB(70, 70, 82), 0.45, 1)
	self.Main = main
	self._openSize = main.Size

	local scale = new("UIScale", {Scale = 0.94}, main)
	tween(scale, TweenInfo.new(0.55, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {Scale = 1})
	self.Scale = scale

	-- Barre du haut
	local top = new("Frame", {
		Size = UDim2.new(1, 0, 0, 92),
		BackgroundColor3 = Color3.fromRGB(9, 9, 13),
		BorderSizePixel = 0,
	}, main)
	corner(top, 22)
	self.Top = top

	local brandIcon = new("TextLabel", {
		Position = UDim2.new(0, 22, 0, 17),
		Size = UDim2.new(0, 55, 0, 55),
		BackgroundColor3 = Theme.RED,
		Text = config.Icon or "♛",
		TextColor3 = Theme.TEXT,
		TextSize = 31,
		Font = Enum.Font.GothamBold,
	}, top)
	corner(brandIcon, 15)

	new("TextLabel", {
		Position = UDim2.new(0, 90, 0, 17),
		Size = UDim2.new(0, 300, 0, 34),
		BackgroundTransparency = 1,
		Text = config.Title or "ZINIROX VN",
		TextColor3 = Theme.TEXT,
		TextSize = 27,
		Font = Enum.Font.GothamBlack,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, top)

	new("TextLabel", {
		Position = UDim2.new(0, 91, 0, 51),
		Size = UDim2.new(0, 300, 0, 20),
		BackgroundTransparency = 1,
		Text = config.Subtitle or "RED EDITION  •  1.0",
		TextColor3 = Theme.MUTED,
		TextSize = 9,
		Font = Enum.Font.GothamBold,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, top)

	-- Conteneur des boutons/stats du haut : UIListLayout = ajout automatique
	local topRight = new("Frame", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -18, 0, 26),
		Size = UDim2.new(0, 0, 0, 40),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundTransparency = 1,
	}, top)
	new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Right,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, topRight)
	self._topRight = topRight

	-- Barre latérale (onglets) : UIListLayout = ajout automatique
	local sidebar = new("Frame", {
		Position = UDim2.new(0, 0, 0, 92),
		Size = UDim2.new(0, 225, 1, -92),
		BackgroundColor3 = Color3.fromRGB(8, 8, 12),
		BorderSizePixel = 0,
	}, main)
	self.Sidebar = sidebar

	new("UIPadding", {
		PaddingTop = UDim.new(0, 18),
		PaddingLeft = UDim.new(0, 13),
		PaddingRight = UDim.new(0, 13),
	}, sidebar)

	new("UIListLayout", {
		Padding = UDim.new(0, 7),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, sidebar)

	-- Zone de contenu (une page par onglet)
	local content = new("Frame", {
		Position = UDim2.new(0, 225, 0, 92),
		Size = UDim2.new(1, -225, 1, -92),
		BackgroundColor3 = Color3.fromRGB(6, 6, 9),
		BorderSizePixel = 0,
	}, main)
	self.Content = content

	-- Boutons système, ajoutés via l'API pour rester dans le même layout
	self:AddTopButton("close", "×", {Width = 40, OnClick = function() self:Close() end})
	self:AddTopButton("minimize", "−", {Width = 40, OnClick = function() self:ToggleMinimize() end})

	self._minimized = false
	self._dragging = false
	self:_setupDrag()

	return self
end

--============================================================
-- Barre du haut : boutons et indicateurs (FPS, Ping, ...)
--============================================================

-- Ajoute un bouton dans la barre du haut. Chaque appel se place
-- automatiquement à gauche des boutons déjà présents.
function Library:AddTopButton(id, text, opts)
	opts = opts or {}
	local width = opts.Width or 90
	local red = opts.Red or false

	local b = new("TextButton", {
		Name = id,
		LayoutOrder = opts.Order or (#self._topWidgets + 1),
		Size = UDim2.new(0, width, 1, 0),
		BackgroundColor3 = red and Theme.RED or Theme.PANEL2,
		Text = text,
		TextColor3 = Theme.TEXT,
		TextSize = 11,
		Font = Enum.Font.GothamBold,
		AutoButtonColor = false,
		BorderSizePixel = 0,
	}, self._topRight)
	corner(b, 11)
	stroke(b, red and Color3.fromRGB(255, 80, 105) or Theme.LINE, 0.35, 1)

	b.MouseEnter:Connect(function()
		tween(b, TweenInfo.new(.15), {
			BackgroundColor3 = red and Color3.fromRGB(255, 48, 86) or Color3.fromRGB(29, 29, 38),
		})
	end)
	b.MouseLeave:Connect(function()
		tween(b, TweenInfo.new(.15), {BackgroundColor3 = red and Theme.RED or Theme.PANEL2})
	end)
	b.MouseButton1Down:Connect(function()
		tween(b, TweenInfo.new(.08), {Size = UDim2.new(0, width - 4, 1, -3)})
	end)
	b.MouseButton1Up:Connect(function()
		tween(b, TweenInfo.new(.12), {Size = UDim2.new(0, width, 1, 0)})
	end)
	if opts.OnClick then
		b.MouseButton1Click:Connect(function()
			opts.OnClick(b)
		end)
	end

	table.insert(self._topWidgets, b)
	return b
end

-- Indicateur générique (ex: FPS, Ping, Score...) : renvoie un objet avec
-- :Set(texte) pour le mettre à jour depuis n'importe quelle boucle.
function Library:AddStat(id, label, opts)
	opts = opts or {}
	local widget = self:AddTopButton(id, label, {Width = opts.Width or 90, Order = opts.Order})
	return {
		Set = function(_, text)
			widget.Text = text
		end,
	}
end

-- Compteur FPS prêt à l'emploi, se met à jour tout seul.
function Library:AddFPSCounter(opts)
	opts = opts or {}
	local stat = self:AddStat("fps", "FPS  --", opts)
	local frames, elapsed = 0, 0
	RunService.Heartbeat:Connect(function(dt)
		frames += 1
		elapsed += dt
		if elapsed >= (opts.Interval or 1) then
			stat:Set("FPS  " .. tostring(math.floor(frames / elapsed)))
			frames, elapsed = 0, 0
		end
	end)
	return stat
end

-- Compteur de ping prêt à l'emploi. Roblox ne fournit pas de ping "officiel"
-- côté client : passe ta propre fonction `opts.Provider()` (par exemple une
-- mesure d'aller-retour via RemoteEvent) si tu en as une ; sinon une valeur
-- de démonstration aléatoire est utilisée.
function Library:AddPingCounter(opts)
	opts = opts or {}
	local stat = self:AddStat("ping", "PING  --", opts)
	task.spawn(function()
		while self.Gui.Parent do
			local ms = opts.Provider and opts.Provider() or math.random(35, 65)
			stat:Set("PING  " .. tostring(ms) .. "ms")
			task.wait(opts.Interval or 1.8)
		end
	end)
	return stat
end

--============================================================
-- Onglets / pages
--============================================================

Library.Tab = {}
Library.Tab.__index = Library.Tab

function Library:AddTab(name, icon)
	local order = 0
	for _ in pairs(self._tabs) do order += 1 end
	order += 1

	local button = new("TextButton", {
		Size = UDim2.new(1, 0, 0, 68),
		BackgroundColor3 = Color3.fromRGB(8, 8, 12),
		Text = "",
		AutoButtonColor = false,
		LayoutOrder = order,
		BorderSizePixel = 0,
	}, self.Sidebar)
	corner(button, 15)

	local iconBox = new("TextLabel", {
		Position = UDim2.new(0, 7, 0.5, -24),
		Size = UDim2.new(0, 48, 0, 48),
		BackgroundColor3 = Color3.fromRGB(18, 18, 24),
		Text = icon or "◆",
		TextColor3 = Theme.MUTED,
		TextSize = 25,
		Font = Enum.Font.GothamBold,
	}, button)
	corner(iconBox, 13)
	stroke(iconBox, Theme.LINE, 0.2, 1)

	local label = new("TextLabel", {
		Position = UDim2.new(0, 68, 0, 0),
		Size = UDim2.new(1, -75, 1, 0),
		BackgroundTransparency = 1,
		Text = name,
		TextColor3 = Theme.MUTED,
		TextSize = 13,
		Font = Enum.Font.GothamBold,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, button)

	local page = new("Frame", {
		Name = name,
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Visible = false,
	}, self.Content)

	local tab = setmetatable({
		_lib = self,
		Name = name,
		Page = page,
		Button = button,
		Icon = iconBox,
		Label = label,
		_y = 0,
	}, Library.Tab)

	self._tabs[name] = tab

	button.MouseButton1Click:Connect(function()
		self:ShowTab(name)
	end)

	if order == 1 then
		self:ShowTab(name)
	end

	return tab
end

function Library:ShowTab(name)
	for tabName, tab in pairs(self._tabs) do
		local active = tabName == name
		tab.Page.Visible = active
		tween(tab.Button, TweenInfo.new(.2), {
			BackgroundColor3 = active and Color3.fromRGB(47, 9, 18) or Color3.fromRGB(8, 8, 12),
		})
		tween(tab.Icon, TweenInfo.new(.2), {
			BackgroundColor3 = active and Color3.fromRGB(63, 12, 23) or Color3.fromRGB(18, 18, 24),
			TextColor3 = active and Theme.TEXT or Theme.MUTED,
		})
		tween(tab.Label, TweenInfo.new(.2), {TextColor3 = active and Theme.TEXT or Theme.MUTED})
	end
end

function Library.Tab:Header(title, subtitle)
	new("TextLabel", {
		Position = UDim2.new(0, 32, 0, 29),
		Size = UDim2.new(1, -64, 0, 44),
		BackgroundTransparency = 1,
		Text = title,
		TextColor3 = Theme.TEXT,
		TextSize = 36,
		Font = Enum.Font.GothamBlack,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, self.Page)
	new("TextLabel", {
		Position = UDim2.new(0, 33, 0, 74),
		Size = UDim2.new(1, -66, 0, 24),
		BackgroundTransparency = 1,
		Text = subtitle or "",
		TextColor3 = Theme.MUTED,
		TextSize = 12,
		Font = Enum.Font.Gotham,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, self.Page)
	local line = new("Frame", {
		Position = UDim2.new(0, 33, 0, 105),
		Size = UDim2.new(0, 50, 0, 3),
		BackgroundColor3 = Theme.RED,
		BorderSizePixel = 0,
	}, self.Page)
	corner(line, 3)
	self._y = 128
end

-- Place le prochain contrôle sous le précédent automatiquement.
function Library.Tab:_nextY(height)
	local y = self._y
	self._y = self._y + height + 18
	return y
end

function Library.Tab:AddToggle(title, description, default, onChanged)
	local y = self:_nextY(82)
	local card = new("Frame", {
		Position = UDim2.new(0, 32, 0, y),
		Size = UDim2.new(1, -64, 0, 82),
		BackgroundColor3 = Theme.PANEL,
		BorderSizePixel = 0,
	}, self.Page)
	corner(card, 16)
	stroke(card, Theme.LINE, 0.15, 1)

	local ico = new("TextLabel", {
		Position = UDim2.new(0, 13, 0.5, -25),
		Size = UDim2.new(0, 50, 0, 50),
		BackgroundColor3 = Color3.fromRGB(27, 12, 17),
		Text = "◆",
		TextColor3 = Theme.RED,
		TextSize = 22,
		Font = Enum.Font.GothamBold,
	}, card)
	corner(ico, 14)

	new("TextLabel", {
		Position = UDim2.new(0, 78, 0, 19),
		Size = UDim2.new(1, -155, 0, 22),
		BackgroundTransparency = 1,
		Text = title,
		TextColor3 = Theme.TEXT,
		TextSize = 15,
		Font = Enum.Font.GothamBold,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, card)

	new("TextLabel", {
		Position = UDim2.new(0, 78, 0, 43),
		Size = UDim2.new(1, -155, 0, 20),
		BackgroundTransparency = 1,
		Text = description or "",
		TextColor3 = Theme.MUTED,
		TextSize = 10,
		Font = Enum.Font.Gotham,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, card)

	local toggle = new("TextButton", {
		AnchorPoint = Vector2.new(1, .5),
		Position = UDim2.new(1, -17, .5, 0),
		Size = UDim2.new(0, 54, 0, 30),
		BackgroundColor3 = default and Theme.RED or Color3.fromRGB(38, 38, 46),
		Text = "",
		AutoButtonColor = false,
		BorderSizePixel = 0,
	}, card)
	corner(toggle, 20)

	local knob = new("Frame", {
		Position = default and UDim2.new(1, -27, .5, 0) or UDim2.new(0, 3, .5, 0),
		AnchorPoint = Vector2.new(0, .5),
		Size = UDim2.new(0, 24, 0, 24),
		BackgroundColor3 = Color3.fromRGB(250, 250, 252),
		BorderSizePixel = 0,
	}, toggle)
	corner(knob, 20)

	local state = default and true or false
	local api = {}

	local function apply(animated)
		local ti = animated and TweenInfo.new(.22, Enum.EasingStyle.Quint, Enum.EasingDirection.Out) or TweenInfo.new(0)
		local ki = animated and TweenInfo.new(.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out) or TweenInfo.new(0)
		tween(toggle, ti, {BackgroundColor3 = state and Theme.RED or Color3.fromRGB(38, 38, 46)})
		tween(knob, ki, {Position = state and UDim2.new(1, -27, .5, 0) or UDim2.new(0, 3, .5, 0)})
	end

	toggle.MouseButton1Click:Connect(function()
		state = not state
		apply(true)
		if onChanged then onChanged(state) end
	end)

	function api:Set(value)
		state = value
		apply(true)
	end
	function api:Get()
		return state
	end

	return api
end

function Library.Tab:AddTextInput(title, defaultValue, onChanged)
	local y = self:_nextY(82)
	local card = new("Frame", {
		Position = UDim2.new(0, 32, 0, y),
		Size = UDim2.new(1, -64, 0, 82),
		BackgroundColor3 = Theme.PANEL,
		BorderSizePixel = 0,
	}, self.Page)
	corner(card, 16)
	stroke(card, Theme.LINE, .15, 1)

	new("TextLabel", {
		Position = UDim2.new(0, 18, 0, 14),
		Size = UDim2.new(1, -36, 0, 20),
		BackgroundTransparency = 1,
		Text = title,
		TextColor3 = Theme.TEXT,
		TextSize = 13,
		Font = Enum.Font.GothamBold,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, card)

	local box = new("TextBox", {
		Position = UDim2.new(0, 18, 0, 40),
		Size = UDim2.new(1, -36, 0, 29),
		BackgroundColor3 = Color3.fromRGB(9, 9, 13),
		Text = defaultValue or "",
		TextColor3 = Theme.TEXT,
		TextSize = 11,
		Font = Enum.Font.Gotham,
		ClearTextOnFocus = false,
		PlaceholderText = defaultValue or "",
		BorderSizePixel = 0,
	}, card)
	corner(box, 9)
	stroke(box, Theme.LINE, .1, 1)

	if onChanged then
		box.FocusLost:Connect(function()
			onChanged(box.Text)
		end)
	end

	return box
end

--============================================================
-- Fenêtre : drag / minimize / close
--============================================================

function Library:_setupDrag()
	local top = self.Top
	local main = self.Main
	local dragStart, startPos

	top.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			self._dragging = true
			dragStart = input.Position
			startPos = main.Position
		end
	end)

	top.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			self._dragging = false
		end
	end)

	UserInputService.InputChanged:Connect(function(input)
		if self._dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			local delta = input.Position - dragStart
			main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
		end
	end)
end

function Library:ToggleMinimize()
	self._minimized = not self._minimized
	if self._minimized then
		tween(self.Main, TweenInfo.new(.3, Enum.EasingStyle.Quint), {Size = UDim2.new(0, 520, 0, 92)})
	else
		tween(self.Main, TweenInfo.new(.4, Enum.EasingStyle.Quint), {Size = self._openSize})
	end
end

function Library:Close()
	tween(self.Scale, TweenInfo.new(.28, Enum.EasingStyle.Quint), {Scale = .88})
	tween(self.Overlay, TweenInfo.new(.28), {BackgroundTransparency = 1})
	task.wait(.3)
	self.Gui:Destroy()
end

return Library
