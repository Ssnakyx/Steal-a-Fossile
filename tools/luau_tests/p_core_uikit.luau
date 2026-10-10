-- Aperçu du UIKit de base (brief 1) : HUD d'exemple, cartes des 7 raretés, boutons, barre, panneau ouvert, messages.
-- python3 tools/luau_tests/ui_preview.py core_uikit [--phone]
local P = require("./previewkit")
local env = P.env
local UDim2 = env.UDim2
local Vector2 = env.Vector2

P.setup()
local UIKit = env.module("src/client/UI/UIKit")
local Colors = UIKit.Colors

local _, root = UIKit.Root("Preview", 1)

-- HUD d'exemple : argent en haut à gauche, boutons de menu à gauche
local money = UIKit.card({ Name = "Money", Color = Colors.Money, Position = UDim2.fromOffset(20, 20), Size = UDim2.fromOffset(240, 64), Parent = root })
UIKit.label({ Text = "$12.5K", Position = UDim2.fromScale(0.08, 0.15), Size = UDim2.fromScale(0.84, 0.7), ZIndex = money.ZIndex + 2, Parent = money })
for index, entry in { { "Shop", Colors.Orange }, { "Index", Colors.Blue }, { "Trails", Colors.Purple } } do
	UIKit.button({
		Name = entry[1],
		Text = entry[1],
		Color = entry[2],
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 20, 0.5, (index - 2) * 84),
		Size = UDim2.fromOffset(150, 72),
		Parent = root,
	})
end
local _, setBar = UIKit.progressBar({ AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -24), Size = UDim2.fromOffset(420, 34), Parent = root })
setBar(0.62, "Speed 62 / 100")
UIKit.toast("Fossil found!", "success")
P.settle(1)
P.page("core_uikit_hud")

-- Panneau ouvert : une carte par rareté, avec un bouton d'achat
local panel = UIKit.panel(root, "Shop", Colors.Orange, Vector2.new(760, 470))
local grid = env.Instance.new("UIGridLayout")
grid.CellSize = UDim2.fromOffset(160, 180)
grid.CellPadding = UDim2.fromOffset(14, 14)
grid.SortOrder = env.Enum.SortOrder.LayoutOrder
grid.Parent = panel.Content
for index, rarity in { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic", "Secret" } do
	local colors = UIKit.Rarity[rarity]
	local card = UIKit.card({ Name = rarity, Color = colors.Fill, Rainbow = colors.Rainbow, LayoutOrder = index, Parent = panel.Content })
	UIKit.rarityTag(rarity, { Position = UDim2.new(0.5, 0, 0, 10), AnchorPoint = Vector2.new(0.5, 0), Size = UDim2.new(0.86, 0, 0, 30), ZIndex = card.ZIndex + 3, Parent = card })
	UIKit.button({
		Text = "$" .. tostring(index * 150),
		Color = Colors.Green,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -10),
		Size = UDim2.new(0.86, 0, 0, 46),
		ZIndex = card.ZIndex + 3,
		Parent = card,
	})
end
local disabled = UIKit.button({ Text = "Owned", Color = Colors.Green, Size = UDim2.fromOffset(160, 180), LayoutOrder = 8, Parent = panel.Content })
disabled:SetAttribute("Disabled", true)
panel.Open()
P.settle(1)
P.page("core_uikit_panel")
