-- Outils des aperçus d'interface (tools/luau_tests/p_<domaine>_<sujet>.luau, lancés par ui_preview.py) :
--   local P = require("./previewkit")
--   local player = P.setup()                  -- joueur local, côté client, écran PC ou téléphone (--phone)
--   local UIKit = P.env.module("src/client/UI/UIKit")
--   ... construire l'écran ...
--   P.settle(1)                               -- laisse finir les animations
--   P.page("shop_open")                       -- une image : tout l'écran du joueur
-- Chaque page est écrite entre les lignes « @@HTML nom » et « @@END » ; ui_preview.py en fait des .html et des .png.

local env = require("./env")
local Render = require("./ui_render")

-- (écrit par ui_preview.py : { Phone = true/false })
local okOptions, options = pcall(require, "./preview_options")
if not okOptions or type(options) ~= "table" then
	options = { Phone = false }
end

-- (écrit par ui_preview.py --icons dossier : images locales des icônes du pack, { ["rbxassetid://..."] = "<img ...>" })
local okIcons, icons = pcall(require, "./preview_icons")
if okIcons and type(icons) == "table" then
	for image, html in icons do
		Render.Art.Icons[image] = html
	end
end

local P = {}
P.env = env
P.Render = Render
P.Phone = options.Phone == true
P.Width = if P.Phone then 844 else 1280
P.Height = if P.Phone then 390 else 720

-- Joueur local côté client, écran simulé (à appeler avant de requérir le code client : UIKit.Touch se lit au chargement)
function P.setup(opts: any?): any
	env.quiet = true
	env.touch = P.Phone
	env.setViewport(P.Width, P.Height)
	local player = env.addPlayer({ Local = true, Name = "Snaky", DisplayName = "Snaky" })
	env.setSide("client", player)
	return player
end

-- Avance le temps (animations, tweens) puis quelques images
function P.settle(seconds: number?)
	env.advance(seconds or 1)
end

-- Une image de tout l'écran du joueur local
function P.page(name: string)
	print("@@HTML " .. name)
	print(Render.Screen(env.localPlayer.PlayerGui, P.Width, P.Height))
	print("@@END")
end

-- Une image d'un seul élément (hauteur du contenu si `height` est nil ; fullScroll : listes dépliées)
function P.element(name: string, gui: any, width: number, height: number?, fullScroll: boolean?)
	print("@@HTML " .. name)
	print(Render.Element(gui, width, height, { fullScroll = fullScroll == true }))
	print("@@END")
end

return P
