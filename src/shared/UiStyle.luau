--!strict
-- Shared look for every screen (NPC buyer, trade window, Bag, Gear, Build, Raid,
-- HUD): rounded panels, cards, chips, progress bars, one palette. Builders
-- only; no game logic and no server data. Every value is in Config.UiStyle
-- (look only), so a UI template pass can restyle everything from one place.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local style = Config.UiStyle
local colors = style.Colors

local UiStyle = {}

export type ButtonKind = "neutral" | "primary" | "danger" | "chip" | "disabled" | "info" | "special"

function UiStyle.corner(parent: Instance, radius: number?): UICorner
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius or style.CardCorner)
	corner.Parent = parent
	return corner
end

function UiStyle.stroke(parent: Instance, color: Color3?, thickness: number?): UIStroke
	local stroke = Instance.new("UIStroke")
	stroke.Color = color or colors.CardStroke
	stroke.Thickness = thickness or style.StrokeThickness
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = parent
	return stroke
end

function UiStyle.padding(parent: Instance, px: number): UIPadding
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, px)
	pad.PaddingBottom = UDim.new(0, px)
	pad.PaddingLeft = UDim.new(0, px)
	pad.PaddingRight = UDim.new(0, px)
	pad.Parent = parent
	return pad
end

-- A list layout (vertical by default) sorted by LayoutOrder.
function UiStyle.list(parent: Instance, horizontal: boolean?, gap: number?): UIListLayout
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = if horizontal then Enum.FillDirection.Horizontal else Enum.FillDirection.Vertical
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, gap or style.Gap)
	if horizontal then
		layout.VerticalAlignment = Enum.VerticalAlignment.Center
	end
	layout.Parent = parent
	return layout
end

-- The big rounded window. Starts hidden; the caller shows it.
function UiStyle.panel(parent: Instance, widthScale: number, heightScale: number, maxSize: Vector2?): Frame
	local panel = Instance.new("Frame")
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.fromScale(widthScale, heightScale)
	panel.BackgroundColor3 = colors.Panel
	panel.BackgroundTransparency = 0.03
	panel.Visible = false
	panel.Parent = parent
	if maxSize then
		local limit = Instance.new("UISizeConstraint")
		limit.MaxSize = maxSize
		limit.Parent = panel
	end
	UiStyle.corner(panel, style.Corner)
	UiStyle.stroke(panel, colors.PanelStroke, style.StrokeThickness)
	return panel
end

-- A text label. Default: full width, grows taller as the text wraps.
function UiStyle.label(parent: Instance, text: string, textSize: number?, color: Color3?, bold: boolean?): TextLabel
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.new(1, 0, 0, 0)
	label.AutomaticSize = Enum.AutomaticSize.Y
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextYAlignment = Enum.TextYAlignment.Center
	label.TextWrapped = true
	label.Font = if bold then style.FontBold else style.Font
	label.TextSize = textSize or style.TextSize.Body
	label.TextColor3 = color or colors.Text
	label.Text = text
	label.Parent = parent
	return label
end

function UiStyle.title(parent: Instance, text: string): TextLabel
	return UiStyle.label(parent, text, style.TextSize.Title, colors.Text, true)
end

local function kindColor(kind: ButtonKind): Color3
	if kind == "primary" then
		return colors.ButtonPrimary
	elseif kind == "danger" then
		return colors.ButtonDanger
	elseif kind == "chip" then
		return colors.ButtonChip
	elseif kind == "disabled" then
		return colors.ButtonDisabled
	elseif kind == "info" then
		return colors.ButtonInfo
	elseif kind == "special" then
		return colors.ButtonSpecial
	end
	return colors.ButtonNeutral
end

-- Re-colors an existing button (Confirm changes between ready / locked / done).
function UiStyle.setButtonKind(button: TextButton, kind: ButtonKind)
	button.BackgroundColor3 = kindColor(kind)
	button.TextColor3 = if kind == "disabled" then colors.TextDim else colors.Text
end

function UiStyle.button(parent: Instance, text: string, kind: ButtonKind, width: number?, height: number?): TextButton
	local button = Instance.new("TextButton")
	button.Size = UDim2.fromOffset(width or 100, height or style.MinTap)
	button.AutoButtonColor = true
	button.BorderSizePixel = 0
	button.Font = style.FontBold
	button.TextSize = style.TextSize.Body
	button.Text = text
	UiStyle.setButtonKind(button, kind)
	UiStyle.corner(button, style.CardCorner)
	if kind == "chip" then
		UiStyle.stroke(button, colors.CardStroke, 1)
	end
	button.Parent = parent
	return button
end

-- A card: a padded, rounded box that grows with what's inside (vertical list).
function UiStyle.card(parent: Instance, order: number?): Frame
	local card = Instance.new("Frame")
	card.LayoutOrder = order or 0
	card.Size = UDim2.new(1, 0, 0, 0)
	card.AutomaticSize = Enum.AutomaticSize.Y
	card.BackgroundColor3 = colors.Card
	card.BorderSizePixel = 0
	card.Parent = parent
	UiStyle.corner(card, style.CardCorner)
	UiStyle.stroke(card, colors.CardStroke, 1)
	UiStyle.padding(card, style.Pad)
	UiStyle.list(card, false, 6)
	return card
end

-- A horizontal row of fixed height (children are laid out left to right).
function UiStyle.row(parent: Instance, height: number, order: number?): Frame
	local row = Instance.new("Frame")
	row.LayoutOrder = order or 0
	row.Size = UDim2.new(1, 0, 0, height)
	row.BackgroundTransparency = 1
	row.Parent = parent
	UiStyle.list(row, true, 6)
	return row
end

-- A scrolling column. Children go straight in; it lists them top to bottom.
function UiStyle.scroller(parent: Instance, position: UDim2, size: UDim2): ScrollingFrame
	local scroller = Instance.new("ScrollingFrame")
	scroller.Position = position
	scroller.Size = size
	scroller.BackgroundTransparency = 1
	scroller.BorderSizePixel = 0
	scroller.ScrollBarThickness = 4
	scroller.ScrollBarImageColor3 = colors.PanelStroke
	scroller.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroller.CanvasSize = UDim2.new()
	scroller.Parent = parent
	UiStyle.list(scroller, false, style.Gap)
	UiStyle.padding(scroller, 2)
	return scroller
end

-- A small rounded tag that sizes itself to its text ("CONFIRMED", "Credits 40").
function UiStyle.pill(parent: Instance, text: string, textColor: Color3?, fill: Color3?): TextLabel
	local pill = Instance.new("TextLabel")
	pill.AutomaticSize = Enum.AutomaticSize.XY
	pill.Size = UDim2.fromOffset(0, 0)
	pill.BackgroundColor3 = fill or colors.BarTrack
	pill.BorderSizePixel = 0
	pill.Font = style.FontBold
	pill.TextSize = style.TextSize.Small
	pill.TextColor3 = textColor or colors.Text
	pill.Text = text
	UiStyle.corner(pill, 999)
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 10)
	pad.PaddingRight = UDim.new(0, 10)
	pad.PaddingTop = UDim.new(0, 4)
	pad.PaddingBottom = UDim.new(0, 4)
	pad.Parent = pill
	pill.Parent = parent
	return pill
end

-- A progress bar: a dark track with a "Fill" child sized by `fraction` (0..1).
function UiStyle.bar(parent: Instance, height: number, fraction: number, color: Color3): Frame
	local track = Instance.new("Frame")
	track.Size = UDim2.new(1, 0, 0, height)
	track.BackgroundColor3 = colors.BarTrack
	track.BorderSizePixel = 0
	track.Parent = parent
	UiStyle.corner(track, 999)
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.BorderSizePixel = 0
	fill.Parent = track
	UiStyle.corner(fill, 999)
	UiStyle.setBar(track, fraction, color)
	return track
end

function UiStyle.setBar(track: Frame, fraction: number, color: Color3?)
	local fill = track:FindFirstChild("Fill")
	if fill and fill:IsA("Frame") then
		fill.Size = UDim2.new(math.clamp(fraction, 0, 1), 0, 1, 0)
		if color then
			fill.BackgroundColor3 = color
		end
	end
end

function UiStyle.gradeColor(grade: string): Color3
	local byGrade: { [string]: Color3 } = style.GradeColors :: any
	return byGrade[grade] or colors.Text
end

-- Green while the price is healthy, amber, then red (the buyer's price bar).
function UiStyle.priceColor(fraction: number): Color3
	if fraction >= style.PriceBar.GoodFrom then
		return colors.Good
	elseif fraction >= style.PriceBar.WarnFrom then
		return colors.Warn
	end
	return colors.Bad
end

-- "12345" -> "12,345"
function UiStyle.money(n: number): string
	local text = tostring(math.floor(n))
	local formatted = text:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (formatted:gsub("^,", ""))
end

-- ── Layout helpers ───────────────────────────────────────────────────────

-- Wide window = two columns; narrow (phone portrait) = one. Short window =
-- phone landscape: drop status lines and other extras. Pass the window frame.
function UiStyle.isWide(gui: GuiObject): boolean
	return gui.AbsoluteSize.X >= style.WideBreakpoint
end

function UiStyle.isShort(gui: GuiObject): boolean
	return gui.AbsoluteSize.Y > 0 and gui.AbsoluteSize.Y < style.ShortWindowHeight
end

-- A thin divider line between groups inside a list.
function UiStyle.divider(parent: Instance, order: number?): Frame
	local line = Instance.new("Frame")
	line.LayoutOrder = order or 0
	line.Size = UDim2.new(1, 0, 0, 1)
	line.BackgroundColor3 = colors.CardStroke
	line.BorderSizePixel = 0
	line.Parent = parent
	return line
end

-- Two side-by-side columns on a wide window, stacked on a narrow one. Put
-- cards in `left` / `right`, then call setColumns(cols, UiStyle.isWide(window))
-- whenever the window's size changes.
export type Columns = { root: Frame, left: Frame, right: Frame, layout: UIListLayout }

function UiStyle.columns(parent: Instance, order: number?): Columns
	local root = Instance.new("Frame")
	root.LayoutOrder = order or 0
	root.Size = UDim2.new(1, 0, 0, 0)
	root.AutomaticSize = Enum.AutomaticSize.Y
	root.BackgroundTransparency = 1
	root.Parent = parent
	local layout = UiStyle.list(root, false, style.Gap)
	local function side(index: number): Frame
		local frame = Instance.new("Frame")
		frame.LayoutOrder = index
		frame.Size = UDim2.new(1, 0, 0, 0)
		frame.AutomaticSize = Enum.AutomaticSize.Y
		frame.BackgroundTransparency = 1
		frame.Parent = root
		UiStyle.list(frame, false, style.Gap)
		return frame
	end
	local cols: Columns = { root = root, left = side(1), right = side(2), layout = layout }
	UiStyle.setColumns(cols, false)
	return cols
end

function UiStyle.setColumns(cols: Columns, wide: boolean)
	cols.layout.FillDirection = if wide then Enum.FillDirection.Horizontal else Enum.FillDirection.Vertical
	cols.layout.VerticalAlignment = Enum.VerticalAlignment.Top
	local size = if wide then UDim2.new(0.5, -style.Gap / 2, 0, 0) else UDim2.new(1, 0, 0, 0)
	cols.left.Size = size
	cols.right.Size = size
end

-- ── Windows ──────────────────────────────────────────────────────────────

-- The close "X": a red MinTap square in the panel's top-right corner (always
-- red, so it is easy to find). The caller connects Activated.
function UiStyle.closeButton(parent: Instance): TextButton
	local close = UiStyle.button(parent, "X", "neutral", style.MinTap, style.MinTap)
	close.BackgroundColor3 = colors.ButtonClose
	close.AnchorPoint = Vector2.new(1, 0)
	close.Position = UDim2.new(1, -style.Window.HeaderInset, 0, style.Window.HeaderPad)
	return close
end

-- A full menu window: panel (hidden), a filled header strip with the title (and
-- pills), a red close button in the corner (outside the row, so a narrow phone
-- can never push it off) and a scrolling body sitting in a darker inset "well".
export type Window = { panel: Frame, header: Frame, title: TextLabel, close: TextButton, content: ScrollingFrame, well: Frame }

function UiStyle.window(parent: Instance, titleText: string, widthScale: number, heightScale: number, maxSize: Vector2?): Window
	local w = style.Window
	local panel = UiStyle.panel(parent, widthScale, heightScale, maxSize)
	local stripHeight = style.MinTap + 2 * w.HeaderPad
	-- Header strip: rounded on top only (the square filler covers its bottom corners).
	local strip = Instance.new("Frame")
	strip.Name = "HeaderStrip"
	strip.Size = UDim2.new(1, 0, 0, stripHeight)
	strip.BackgroundColor3 = colors.HeaderFill
	strip.BorderSizePixel = 0
	strip.Parent = panel
	UiStyle.corner(strip, style.Corner)
	local filler = Instance.new("Frame")
	filler.Position = UDim2.new(0, 0, 1, -style.Corner)
	filler.Size = UDim2.new(1, 0, 0, style.Corner)
	filler.BackgroundColor3 = colors.HeaderFill
	filler.BorderSizePixel = 0
	filler.Parent = strip
	local header = Instance.new("Frame")
	header.Position = UDim2.fromOffset(w.HeaderInset, w.HeaderPad)
	header.Size = UDim2.new(1, -2 * w.HeaderInset - style.MinTap - w.BodyGap, 0, style.MinTap)
	header.BackgroundTransparency = 1
	header.Parent = panel
	UiStyle.list(header, true, w.HeaderGap)
	local title = UiStyle.title(header, titleText)
	title.AutomaticSize = Enum.AutomaticSize.XY
	title.Size = UDim2.fromOffset(0, 0)
	title.LayoutOrder = 1
	local close = UiStyle.closeButton(panel)
	local top = stripHeight + w.BodyGap
	local bodyPos = UDim2.fromOffset(w.EdgePad, top)
	local bodySize = UDim2.new(1, -2 * w.EdgePad, 1, -(top + w.EdgePad))
	local well = Instance.new("Frame") -- made before the scroller so it draws behind it
	well.Name = "Well"
	well.Position = bodyPos
	well.Size = bodySize
	well.BackgroundColor3 = colors.BarTrack
	well.BackgroundTransparency = w.WellTransparency
	well.BorderSizePixel = 0
	well.Parent = panel
	UiStyle.corner(well, style.CardCorner)
	local content = UiStyle.scroller(panel, bodyPos, bodySize)
	return { panel = panel, header = header, title = title, close = close, content = content, well = well }
end

-- A menu that sizes itself to what's inside (Gear menu, Build panel): rounded
-- panel, padded, vertical list, hidden until the caller shows it.
function UiStyle.dockPanel(parent: Instance): Frame
	local dock = Instance.new("Frame")
	dock.AutomaticSize = Enum.AutomaticSize.XY
	dock.Size = UDim2.fromOffset(0, 0)
	dock.BackgroundColor3 = colors.Panel
	dock.BackgroundTransparency = 0.03
	dock.BorderSizePixel = 0
	dock.Visible = false
	dock.Parent = parent
	UiStyle.corner(dock, style.Corner)
	UiStyle.stroke(dock, colors.PanelStroke, style.StrokeThickness)
	UiStyle.padding(dock, style.Pad)
	UiStyle.list(dock, false, style.Gap).HorizontalAlignment = Enum.HorizontalAlignment.Center
	return dock
end

-- ── Tabs, headings, rows, tiles ──────────────────────────────────────────

-- A row of tab buttons that size to their text. Hidden tabs (Visible = false)
-- leave no gap. The caller connects Activated on each button.
export type TabBar = { frame: Frame, buttons: { [string]: TextButton } }

function UiStyle.tabBar(parent: Instance, names: { string }, order: number?): TabBar
	local frame = Instance.new("Frame")
	frame.LayoutOrder = order or 0
	frame.Size = UDim2.new(1, 0, 0, style.MinTap)
	frame.BackgroundTransparency = 1
	frame.Parent = parent
	UiStyle.list(frame, true, 6)
	local buttons: { [string]: TextButton } = {}
	for index, name in names do
		local button = UiStyle.button(frame, name, "chip", 0, style.MinTap)
		button.LayoutOrder = index
		button.AutomaticSize = Enum.AutomaticSize.X
		button.Size = UDim2.fromOffset(0, style.MinTap)
		button.TextWrapped = false
		local pad = Instance.new("UIPadding")
		pad.PaddingLeft = UDim.new(0, style.Tab.PadX)
		pad.PaddingRight = UDim.new(0, style.Tab.PadX)
		pad.Parent = button
		local limit = Instance.new("UISizeConstraint")
		limit.MinSize = Vector2.new(style.Tab.MinWidth, 0)
		limit.Parent = button
		buttons[name] = button
	end
	return { frame = frame, buttons = buttons }
end

-- The active tab is a light fill with dark text, never the green of an action
-- button, so "selected" and "tap to do this" look different.
function UiStyle.setActiveTab(bar: TabBar, active: string)
	for name, button in bar.buttons do
		if name == active then
			button.BackgroundColor3 = colors.TabActive
			button.TextColor3 = colors.TabActiveText
		else
			UiStyle.setButtonKind(button, "chip")
		end
	end
end

-- Small dim ALL-CAPS heading over a group of rows ("SAFE", "ARMOR", "CRAFT"),
-- with an optional dim summary on the right ("3 pieces"). Only summarise what
-- the player already has (never "x/total": that would reveal locked content, R4).
function UiStyle.sectionHeader(parent: Instance, text: string, order: number?, color: Color3?, summary: string?): TextLabel
	local header = UiStyle.label(parent, string.upper(text), style.TextSize.Small, color or colors.TextDim, true)
	header.LayoutOrder = order or 0
	header.Size = UDim2.new(1, 0, 0, style.Section.Height)
	header.AutomaticSize = Enum.AutomaticSize.None
	header.TextYAlignment = Enum.TextYAlignment.Bottom
	header.TextWrapped = false
	header.TextTruncate = Enum.TextTruncate.AtEnd
	local right = UiStyle.label(header, summary or "", style.TextSize.Small, colors.TextDim, false)
	right.Name = "Summary"
	right.Size = UDim2.fromScale(1, 1)
	right.AutomaticSize = Enum.AutomaticSize.None
	right.TextXAlignment = Enum.TextXAlignment.Right
	right.TextYAlignment = Enum.TextYAlignment.Bottom
	right.TextWrapped = false
	right.Visible = summary ~= nil and summary ~= ""
	return header
end

function UiStyle.setSectionSummary(header: TextLabel, text: string)
	local right = header:FindFirstChild("Summary")
	if right and right:IsA("TextLabel") then
		right.Text = text
		right.Visible = text ~= ""
	end
end

-- One list row: a name (with an optional dim detail line under it) that takes
-- all the spare width, and a `trailing` frame on the right for pills, counts
-- and buttons (add them there; they sit MinTap tall inside the row). Tappable
-- rows are a TextButton (the caller connects Activated on `root`). `stripe`
-- adds a thin colour strip on the left.
export type ItemRow = { root: GuiObject, title: TextLabel, detail: TextLabel, trailing: Frame }

function UiStyle.itemRow(parent: Instance, titleText: string, detailText: string?, order: number?, tappable: boolean?, stripe: Color3?): ItemRow
	local root: GuiObject
	if tappable then
		local button = Instance.new("TextButton")
		button.Text = ""
		button.AutoButtonColor = false
		root = button
	else
		root = Instance.new("Frame")
	end
	root.LayoutOrder = order or 0
	root.Size = UDim2.new(1, 0, 0, style.Item.RowHeight)
	root.BackgroundColor3 = colors.Card
	root.BorderSizePixel = 0
	root.Parent = parent
	UiStyle.corner(root, style.CardCorner)
	UiStyle.stroke(root, colors.CardStroke, 1)
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 6)
	pad.PaddingBottom = UDim.new(0, 6)
	pad.PaddingLeft = UDim.new(0, style.Pad)
	pad.PaddingRight = UDim.new(0, style.Pad)
	pad.Parent = root
	UiStyle.list(root, true, style.Gap)

	if stripe then -- a thin colour strip down the left edge (Grade colour)
		local bar = Instance.new("Frame")
		bar.Name = "Stripe"
		bar.LayoutOrder = 0
		bar.Size = UDim2.new(0, style.RowStripe, 1, 0)
		bar.BackgroundColor3 = stripe
		bar.BorderSizePixel = 0
		bar.Parent = root
		UiStyle.corner(bar, 2)
	end

	local info = Instance.new("Frame")
	info.LayoutOrder = 1
	info.Size = UDim2.fromScale(0, 1)
	info.BackgroundTransparency = 1
	info.Parent = root
	local flex = Instance.new("UIFlexItem")
	flex.FlexMode = Enum.UIFlexMode.Fill
	flex.Parent = info
	local infoList = UiStyle.list(info, false, 2)
	infoList.VerticalAlignment = Enum.VerticalAlignment.Center

	local function line(text: string, size: number, color: Color3, bold: boolean, lineOrder: number): TextLabel
		local label = UiStyle.label(info, text, size, color, bold)
		label.LayoutOrder = lineOrder
		label.Size = UDim2.new(1, 0, 0, size + 5)
		label.AutomaticSize = Enum.AutomaticSize.None
		label.TextWrapped = false
		label.TextTruncate = Enum.TextTruncate.AtEnd
		return label
	end
	local title = line(titleText, style.TextSize.Body, colors.Text, true, 1)
	local detail = line(detailText or "", style.TextSize.Small, colors.TextDim, false, 2)
	detail.Visible = detailText ~= nil and detailText ~= ""

	local trailing = Instance.new("Frame")
	trailing.LayoutOrder = 2
	trailing.Size = UDim2.fromScale(0, 1)
	trailing.AutomaticSize = Enum.AutomaticSize.X
	trailing.BackgroundTransparency = 1
	trailing.Parent = root
	UiStyle.list(trailing, true, 6)
	return { root = root, title = title, detail = detail, trailing = trailing }
end

-- A tappable tile for grids (build pieces, gadgets): a name over a small dim
-- line (cost, count). The caller connects Activated on `button`.
export type Tile = { button: TextButton, title: TextLabel, sub: TextLabel }
export type TileState = "normal" | "selected" | "disabled"

function UiStyle.tile(parent: Instance, titleText: string, subText: string?, order: number?): Tile
	local button = Instance.new("TextButton")
	button.Name = "Tile"
	button.LayoutOrder = order or 0
	button.Size = UDim2.fromOffset(style.Tile.Width, style.Tile.Height)
	button.Text = ""
	button.AutoButtonColor = true
	button.BorderSizePixel = 0
	button.Parent = parent
	UiStyle.corner(button, style.CardCorner)
	local stroke = UiStyle.stroke(button, colors.CardStroke, 1)
	stroke.Name = "Stroke"
	UiStyle.padding(button, 4)
	local list = UiStyle.list(button, false, 2)
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.VerticalAlignment = Enum.VerticalAlignment.Center
	local function line(text: string, size: number, color: Color3, bold: boolean, lineOrder: number): TextLabel
		local label = UiStyle.label(button, text, size, color, bold)
		label.LayoutOrder = lineOrder
		label.Size = UDim2.new(1, 0, 0, size + 5)
		label.AutomaticSize = Enum.AutomaticSize.None
		label.TextXAlignment = Enum.TextXAlignment.Center
		label.TextWrapped = false
		label.TextTruncate = Enum.TextTruncate.AtEnd
		return label
	end
	local title = line(titleText, style.TextSize.Small, colors.Text, true, 1)
	local sub = line(subText or "", style.TextSize.Tiny, colors.TextDim, false, 2)
	sub.Visible = subText ~= nil and subText ~= ""
	local tile: Tile = { button = button, title = title, sub = sub }
	UiStyle.setTileState(tile, "normal")
	return tile
end

function UiStyle.setTileState(tile: Tile, state: TileState)
	local stroke = tile.button:FindFirstChild("Stroke")
	-- Selected = a thick Accent outline (green is only for buttons that do something).
	tile.button.BackgroundColor3 = if state == "selected"
		then colors.ButtonNeutral
		elseif state == "disabled" then colors.ButtonDisabled
		else colors.ButtonChip
	tile.title.TextColor3 = if state == "disabled" then colors.TextDim else colors.Text
	if stroke and stroke:IsA("UIStroke") then
		stroke.Color = if state == "selected" then colors.Accent else colors.CardStroke
		stroke.Thickness = if state == "selected" then 2.5 else 1
	end
end

-- The wrapping grid that tiles go in (Config.UiStyle.Tile cell size). Grows
-- taller as tiles wrap, so it lives inside a scroller or a dock panel.
function UiStyle.tileGrid(parent: Instance, order: number?): Frame
	local frame = Instance.new("Frame")
	frame.LayoutOrder = order or 0
	frame.Size = UDim2.new(1, 0, 0, 0)
	frame.AutomaticSize = Enum.AutomaticSize.Y
	frame.BackgroundTransparency = 1
	frame.Parent = parent
	local grid = Instance.new("UIGridLayout")
	grid.CellSize = UDim2.fromOffset(style.Tile.Width, style.Tile.Height)
	grid.CellPadding = UDim2.fromOffset(style.Gap, style.Gap)
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.Parent = frame
	return frame
end

-- ── HUD ──────────────────────────────────────────────────────────────────

-- A HUD button over the 3D world: never under MinTap in either direction;
-- `round` makes it a circle (Attack, Build) of the larger side.
function UiStyle.hudButton(parent: Instance, text: string, kind: ButtonKind, width: number, height: number, round: boolean?): TextButton
	local w = math.max(width, style.MinTap)
	local h = math.max(height, style.MinTap)
	if round then
		w = math.max(w, h)
		h = w
	end
	local button = UiStyle.button(parent, text, kind, w, h)
	button.TextWrapped = true
	button.BackgroundTransparency = style.Hud.Transparency
	local corner = button:FindFirstChildOfClass("UICorner")
	if corner then
		corner.CornerRadius = UDim.new(0, if round then 999 else style.Corner)
	end
	if kind ~= "chip" then -- chip buttons already have their stroke
		UiStyle.stroke(button, colors.PanelStroke, 1)
	end
	return button
end

-- The one row of menu buttons on the left edge (Raids / Bag / Trade / Gear).
-- Any script may call this; the first creates it. A hidden button
-- (Visible = false) leaves no gap, so the new-player reveal (R4) still works.
function UiStyle.dock(playerGui: Instance): Frame
	local existing = playerGui:FindFirstChild("HudDock")
	if existing then
		return existing:FindFirstChild("Row") :: Frame
	end
	local cfg = style.Dock
	local gui = Instance.new("ScreenGui")
	gui.Name = "HudDock"
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.DisplayOrder = cfg.DisplayOrder
	local row = Instance.new("Frame")
	row.Name = "Row"
	row.Position = UDim2.fromOffset(cfg.X, cfg.Y)
	row.AutomaticSize = Enum.AutomaticSize.XY
	row.Size = UDim2.fromOffset(0, 0)
	row.BackgroundTransparency = 1
	row.Parent = gui
	UiStyle.list(row, true, cfg.Gap)
	gui.Parent = playerGui
	return row
end

-- The right-thumb column (bottom right, above Roblox's jump button). `main` is
-- the bottom row (Attack, Build/Done); `context` sits above it (Breach, Sabotage)
-- and its list can be flipped to a row on a short window. Any script may call
-- this; the first creates it. Hidden buttons leave no gap.
export type ThumbColumn = { context: Frame, contextList: UIListLayout, main: Frame }

function UiStyle.thumbColumn(playerGui: Instance): ThumbColumn
	local existing = playerGui:FindFirstChild("ThumbColumn")
	if existing then
		local root = existing:FindFirstChild("Root") :: Frame
		local context = root:FindFirstChild("Context") :: Frame
		return { context = context, contextList = context:FindFirstChildOfClass("UIListLayout") :: UIListLayout, main = root:FindFirstChild("Main") :: Frame }
	end
	local cfg = style.Thumb
	local gui = Instance.new("ScreenGui")
	gui.Name = "ThumbColumn"
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.DisplayOrder = cfg.DisplayOrder
	local root = Instance.new("Frame")
	root.Name = "Root"
	root.AnchorPoint = Vector2.new(1, 1)
	root.Position = UDim2.new(1, -cfg.Margin, 1, -(cfg.Margin + Config.Combat.Ui.ButtonSize * cfg.JumpClearance))
	root.AutomaticSize = Enum.AutomaticSize.XY
	root.Size = UDim2.fromOffset(0, 0)
	root.BackgroundTransparency = 1
	root.Parent = gui
	UiStyle.list(root, false, cfg.Gap).HorizontalAlignment = Enum.HorizontalAlignment.Right
	local context = Instance.new("Frame")
	context.Name = "Context"
	context.LayoutOrder = 1
	context.AutomaticSize = Enum.AutomaticSize.XY
	context.Size = UDim2.fromOffset(0, 0)
	context.BackgroundTransparency = 1
	context.Parent = root
	local contextList = UiStyle.list(context, false)
	contextList.HorizontalAlignment = Enum.HorizontalAlignment.Right
	contextList.VerticalAlignment = Enum.VerticalAlignment.Bottom
	local main = Instance.new("Frame")
	main.Name = "Main"
	main.LayoutOrder = 2
	main.AutomaticSize = Enum.AutomaticSize.XY
	main.Size = UDim2.fromOffset(0, 0)
	main.BackgroundTransparency = 1
	main.Parent = root
	UiStyle.list(main, true, cfg.Gap)
	gui.Parent = playerGui
	return { context = context, contextList = contextList, main = main }
end

-- A dock button: same size and look for every menu button. `order` sets its slot.
function UiStyle.dockButton(playerGui: Instance, text: string, kind: ButtonKind, order: number): TextButton
	local button = UiStyle.hudButton(UiStyle.dock(playerGui), text, kind, style.Dock.ButtonWidth, style.MinTap)
	button.LayoutOrder = order
	return button
end

-- A translucent info box on the HUD (vault meter). Auto-sizes to its content;
-- set Size / AutomaticSize to fix the width. `interactive` = tappable (the
-- caller connects Activated); otherwise touches pass straight through.
function UiStyle.hudPanel(parent: Instance, interactive: boolean?): TextButton
	local panel = Instance.new("TextButton")
	panel.Text = ""
	panel.AutoButtonColor = false
	panel.Active = interactive == true
	panel.Selectable = false
	panel.AutomaticSize = Enum.AutomaticSize.XY
	panel.Size = UDim2.fromOffset(0, 0)
	panel.BackgroundColor3 = colors.Panel
	panel.BackgroundTransparency = style.Hud.PanelTransparency
	panel.BorderSizePixel = 0
	panel.Parent = parent
	UiStyle.corner(panel, style.CardCorner)
	UiStyle.stroke(panel, colors.CardStroke, 1)
	UiStyle.padding(panel, style.Pad)
	UiStyle.list(panel, false, style.Hud.PanelGap)
	return panel
end

-- ── Messages ─────────────────────────────────────────────────────────────

export type Tone = "info" | "good" | "warn" | "bad" | "critical" | "muted" | "special"

-- Banner fill for a tone (alerts, announcements, raid status).
function UiStyle.tone(tone: Tone): Color3
	local tones = colors.Tones
	if tone == "good" then
		return tones.Good
	elseif tone == "warn" then
		return tones.Warn
	elseif tone == "bad" then
		return tones.Bad
	elseif tone == "critical" then
		return tones.Critical
	elseif tone == "muted" then
		return tones.Muted
	elseif tone == "special" then
		return tones.Special
	end
	return tones.Info
end

-- A short message that hides itself. show(text, seconds, tone?): the newest
-- message wins; the old one's timer can't hide it. One spot for the HUD (just
-- under the banner stack) and one inside a window (`inWindow`: bottom centre of
-- the window frame you pass as `parent`).
export type ToastTone = "neutral" | "good" | "warn" | "bad"
export type Toast = { frame: TextLabel, show: (text: string, seconds: number, tone: ToastTone?) -> () }

function UiStyle.toast(parent: Instance, inWindow: boolean?): Toast
	local toastCfg = style.Toast
	local frame = UiStyle.pill(parent, "", colors.Text, toastCfg.Fill)
	if inWindow then
		frame.AnchorPoint = Vector2.new(0.5, 1)
		frame.Position = UDim2.new(0.5, 0, 1, -style.Window.EdgePad)
	else
		frame.AnchorPoint = Vector2.new(0.5, 0)
		frame.Position = UDim2.new(0.5, 0, 0, toastCfg.HudTopOffset)
	end
	frame.BackgroundTransparency = toastCfg.FillTransparency
	frame.TextWrapped = true
	frame.TextSize = style.TextSize.Body
	frame.Visible = false
	frame.ZIndex = toastCfg.ZIndex
	local corner = frame:FindFirstChildOfClass("UICorner")
	if corner then
		corner.CornerRadius = UDim.new(0, style.Corner) -- a pill would balloon on wrapped text
	end
	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize = Vector2.new(toastCfg.MaxWidth, math.huge)
	limit.Parent = frame
	local stroke = UiStyle.stroke(frame, colors.PanelStroke, 1)

	local token = 0
	local function show(text: string, seconds: number, tone: ToastTone?)
		token += 1
		local mine = token
		local color = if tone == "good" then colors.Good elseif tone == "warn" then colors.Warn elseif tone == "bad" then colors.Bad else colors.Text
		frame.Text = text
		frame.TextColor3 = color
		stroke.Color = if tone == nil or tone == "neutral" then colors.PanelStroke else color
		frame.Visible = true
		task.delay(seconds, function()
			if token == mine then
				frame.Visible = false
			end
		end)
	end
	return { frame = frame, show = show }
end

-- A coloured status bar across the top (announcements, base alerts, raid
-- status): wrapped bold text on a tone fill. The caller sets Position, Text and
-- BackgroundColor3 (UiStyle.tone or a Config colour) and toggles Visible.
function UiStyle.banner(parent: Instance, widthScale: number?, order: number?): TextLabel
	local cfg = style.Banner
	local banner = UiStyle.label(parent, "", style.TextSize.Body, colors.Text, true)
	banner.AnchorPoint = Vector2.new(0.5, 0)
	banner.Position = UDim2.new(0.5, 0, 0, style.Window.EdgePad)
	banner.Size = UDim2.new(widthScale or cfg.WidthScale, 0, 0, 0)
	banner.TextXAlignment = Enum.TextXAlignment.Center
	banner.BackgroundTransparency = cfg.Transparency
	banner.BackgroundColor3 = UiStyle.tone("muted")
	banner.BorderSizePixel = 0
	banner.Visible = false
	banner.LayoutOrder = order or 0
	local limit = Instance.new("UISizeConstraint")
	limit.MinSize = Vector2.new(0, cfg.MinHeight)
	limit.MaxSize = Vector2.new(cfg.MaxWidth, math.huge)
	limit.Parent = banner
	UiStyle.corner(banner, style.CardCorner)
	UiStyle.stroke(banner, colors.BarTrack, 1)
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 6)
	pad.PaddingBottom = UDim.new(0, 6)
	pad.PaddingLeft = UDim.new(0, style.Pad)
	pad.PaddingRight = UDim.new(0, style.Pad)
	pad.Parent = banner
	return banner
end

-- The one shared column every top banner goes in (raid status, base alerts,
-- announcements): they push each other down instead of overlapping. Any script
-- may call this; the first creates it, the rest get the same frame. Pass it to
-- UiStyle.banner as the parent, with an order from Config.UiStyle.TopStack.Order.
function UiStyle.topStack(playerGui: Instance): Frame
	local existing = playerGui:FindFirstChild("TopStack")
	if existing then
		return existing:FindFirstChild("Stack") :: Frame
	end
	local cfg = style.TopStack
	local gui = Instance.new("ScreenGui")
	gui.Name = "TopStack"
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.DisplayOrder = cfg.DisplayOrder
	local stack = Instance.new("Frame")
	stack.Name = "Stack"
	stack.Position = UDim2.fromOffset(0, cfg.Y)
	stack.Size = UDim2.new(1, 0, 0, 0)
	stack.AutomaticSize = Enum.AutomaticSize.Y
	stack.BackgroundTransparency = 1
	stack.Parent = gui
	UiStyle.list(stack, false, cfg.Gap).HorizontalAlignment = Enum.HorizontalAlignment.Center
	gui.Parent = playerGui
	return stack
end

-- ── Meters, empty states ─────────────────────────────────────────────────

-- A labeled bar: name on the left, value text on the right, bar underneath.
export type Meter = { root: Frame, label: TextLabel, value: TextLabel, bar: Frame }

function UiStyle.meter(parent: Instance, labelText: string, fraction: number, color: Color3, order: number?): Meter
	local cfg = style.Meter
	local root = Instance.new("Frame")
	root.LayoutOrder = order or 0
	root.Size = UDim2.new(1, 0, 0, 0)
	root.AutomaticSize = Enum.AutomaticSize.Y
	root.BackgroundTransparency = 1
	root.Parent = parent
	UiStyle.list(root, false, 4)
	local top = UiStyle.row(root, cfg.LabelHeight, 1)
	local label = UiStyle.label(top, labelText, style.TextSize.Small, colors.Text, true)
	label.Size = UDim2.new(0.6, 0, 1, 0)
	label.AutomaticSize = Enum.AutomaticSize.None
	label.TextWrapped = false
	label.TextTruncate = Enum.TextTruncate.AtEnd
	local value = UiStyle.label(top, "", style.TextSize.Small, colors.TextDim, false)
	value.Size = UDim2.new(0.4, -6, 1, 0)
	value.AutomaticSize = Enum.AutomaticSize.None
	value.TextXAlignment = Enum.TextXAlignment.Right
	value.TextWrapped = false
	value.TextTruncate = Enum.TextTruncate.AtEnd
	local bar = UiStyle.bar(root, cfg.BarHeight, fraction, color)
	bar.LayoutOrder = 2
	return { root = root, label = label, value = value, bar = bar }
end

function UiStyle.setMeter(meter: Meter, fraction: number, valueText: string?, color: Color3?)
	UiStyle.setBar(meter.bar, fraction, color)
	if valueText then
		meter.value.Text = valueText
	end
end

-- Text centred inside a bar ("120/300 XP"), readable over both track and fill.
function UiStyle.barLabel(track: Frame, text: string): TextLabel
	local label = UiStyle.label(track, text, style.TextSize.Tiny, colors.Text, true)
	label.Size = UDim2.fromScale(1, 1)
	label.AutomaticSize = Enum.AutomaticSize.None
	label.TextXAlignment = Enum.TextXAlignment.Center
	label.TextWrapped = false
	label.TextTruncate = Enum.TextTruncate.AtEnd
	label.TextStrokeTransparency = 0.6
	label.ZIndex = 3
	return label
end

-- "Nothing here yet" card: a title and one line saying what to do about it.
function UiStyle.emptyState(parent: Instance, titleText: string, hint: string?, order: number?): Frame
	local card = UiStyle.card(parent, order)
	local title = UiStyle.label(card, titleText, style.TextSize.Title, colors.Text, true)
	title.LayoutOrder = 1
	title.TextXAlignment = Enum.TextXAlignment.Center
	if hint and hint ~= "" then
		local body = UiStyle.label(card, hint, style.TextSize.Body, colors.TextDim, false)
		body.LayoutOrder = 2
		body.TextXAlignment = Enum.TextXAlignment.Center
	end
	return card
end

return UiStyle
