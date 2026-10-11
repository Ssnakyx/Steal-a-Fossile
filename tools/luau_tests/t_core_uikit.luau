-- UIKit (base) : écran mis à l'échelle, boutons, cartes, barres, raretés, panneaux, messages
local T = require("./testkit")
local env = T.env

local player = env.addPlayer({ Local = true, Name = "Me" })
env.setSide("client", player)
local UIKit = T.module("src/client/UI/UIKit")
local Enum = env.Enum
local Vector2 = env.Vector2

T.section("écran")
local screen, root = UIKit.Root("TestUI", 7)
T.check(screen:IsA("ScreenGui") and screen.Parent == player.PlayerGui, "ScreenGui dans le PlayerGui")
T.eq(screen.DisplayOrder, 7, "DisplayOrder")
T.eq(screen.ResetOnSpawn, false, "ne disparaît pas à la mort")
local scale = root:FindFirstChildOfClass("UIScale")
T.near(scale.Scale, 1, 1e-6, "échelle 1 sur un écran 1280x720")
env.setViewport(640, 360)
T.near(scale.Scale, 0.5, 1e-6, "échelle 0.5 sur un petit écran")
env.setViewport(2560, 1080)
T.near(scale.Scale, 1.5, 1e-6, "écran large : l'axe le plus serré donne l'échelle")
T.near(root.Size.X.Offset, 2560 / 1.5, 1e-3, "le cadre s'allonge sur l'autre axe")
env.setViewport(1280, 720)
local again = UIKit.Root("TestUI")
T.eq(again, screen, "Root réutilise le ScreenGui existant")

T.section("bouton")
local clicks = 0
local button = UIKit.button({ Text = "Buy", Color = UIKit.Colors.Green, Size = env.UDim2.fromOffset(200, 60), Parent = root }, function()
	clicks += 1
end)
T.eq(button.Parent, root, "bouton placé")
T.eq(button:FindFirstChild("Label", true).Text, "Buy", "texte du bouton")
env.fire(env.signal(button, "Activated"))
T.eq(clicks, 1, "clic")
button.Text = "Sold"
T.eq(button:FindFirstChild("Label", true).Text, "Sold", "texte mis à jour")
button:SetAttribute("Disabled", true)
T.near(button:FindFirstChild("Label", true).TextTransparency, 0.35, 1e-6, "bouton grisé")
env.fire(env.signal(button, "Activated"))
T.eq(clicks, 2, "un bouton grisé reste cliquable (le serveur explique)")
local closed = false
local close = UIKit.closeButton({ Size = env.UDim2.fromOffset(40, 40), Parent = root }, function()
	closed = true
end)
env.fire(env.signal(close, "Activated"))
T.check(closed, "croix de fermeture")

T.section("composants")
local card = UIKit.card({ Color = UIKit.Colors.Blue, Size = env.UDim2.fromOffset(100, 100), Parent = root })
T.check(card:IsA("Frame") and card.Parent == root, "carte")
local bar, setBar = UIKit.progressBar({ Size = env.UDim2.fromOffset(300, 30), Parent = root })
setBar(0.5, "50%")
env.advance(1)
T.near(bar.Fill.Size.X.Scale, 0.5, 1e-6, "barre à moitié")
T.eq(bar:FindFirstChild("Label").Text, "50%", "texte de la barre")
setBar(0 / 0)
env.advance(1)
T.near(bar.Fill.Size.X.Scale, 0, 1e-6, "barre NaN -> 0")
T.eq(bar.Fill.Visible, false, "barre vide cachée")
setBar(5)
env.advance(1)
T.near(bar.Fill.Size.X.Scale, 1, 1e-6, "barre bornée à 1")
for _, rarity in { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic", "Secret" } do
	T.check(UIKit.Rarity[rarity] ~= nil, "couleur de rareté " .. rarity)
	local tag = UIKit.rarityTag(rarity, { Size = env.UDim2.fromOffset(120, 30), Parent = root })
	T.eq(tag:FindFirstChild("Text", true).Text, string.upper(rarity), "étiquette " .. rarity)
end
T.check(UIKit.Rarity.Secret.Rainbow == true, "Secret en arc-en-ciel")
local label = UIKit.label({ Text = "Hello", Parent = root })
T.eq(label.Text, "Hello", "label")
T.check(label:FindFirstChildOfClass("UIStroke") ~= nil, "texte cerné de noir")

T.section("panneaux")
local panelEvents = {}
UIKit.PanelsChanged:Connect(function(open)
	table.insert(panelEvents, open)
end)
local panel = UIKit.panel(root, "Shop", UIKit.Colors.Orange, Vector2.new(700, 450))
T.check(not panel.IsOpen(), "fermé au départ")
T.check(not UIKit.AnyPanelOpen(), "aucun panneau ouvert")
panel.Open()
env.advance(1)
T.check(panel.IsOpen(), "ouvert")
T.check(UIKit.AnyPanelOpen(), "AnyPanelOpen")
T.check(panel.Frame.Visible, "visible")
T.check(panel.Content ~= nil and panel.HeaderRight ~= nil, "Content et HeaderRight")
local other = UIKit.panel(root, "Index", UIKit.Colors.Blue, Vector2.new(2000, 2000))
other.Open()
env.advance(1)
T.check(not panel.IsOpen(), "ouvrir un panneau ferme l'autre")
other.Toggle()
env.advance(1)
T.check(not UIKit.AnyPanelOpen(), "Toggle ferme")
T.check(#panelEvents >= 2 and panelEvents[1] == true and panelEvents[#panelEvents] == false, "PanelsChanged")

T.section("messages")
local toast = UIKit.toast("Saved", "success")
T.eq(toast:FindFirstChild("Text", true).Text, "Saved", "toast")
env.advance(4)
T.eq(toast.Parent, nil, "toast disparu")

T.section("textes")
-- (pas d'emoji : les textes affichés sont en ASCII)
local function ascii(text: string): boolean
	return not string.find(text, "[\128-\255]")
end
local bad = {}
for _, item in player.PlayerGui:GetDescendants() do
	if (item:IsA("TextLabel") or item:IsA("TextButton")) and not ascii(item.Text) then
		table.insert(bad, item.Text)
	end
end
T.eq(#bad, 0, "aucun caractère spécial dans les textes " .. table.concat(bad, ", "))
T.eq(UIKit.TitleFont.Family ~= nil, true, "police des titres")
T.check(Enum.Font.FredokaOne ~= nil, "Fredoka One")

T.section("aperçu HTML (ui_render.luau)")
local Render = require("./ui_render")
local html = Render.Screen(player.PlayerGui, 1280, 720)
T.check(string.find(html, 'data-name="TestUI"', 1, true) ~= nil, "écran rendu en HTML")
T.check(string.find(html, "SECRET", 1, true) ~= nil, "textes dans l'aperçu")

T.done("core_uikit")
