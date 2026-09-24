--!strict
-- Shared look for the step 9 screens (NPC buyer, trade window, the Bag's Level
-- block): rounded panels, cards, chips, progress bars, one palette. Builders
-- only; no game logic and no server data. Every value is in Config.UiStyle
-- (look only), so a UI template pass can restyle everything from one place.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local style = Config.UiStyle
local colors = style.Colors

local UiStyle = {}

export type ButtonKind = "neutral" | "primary" | "danger" | "chip" | "disabled"

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

return UiStyle
