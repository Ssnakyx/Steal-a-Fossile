--!strict
-- Étiquette au-dessus des dinos des parcs (brief 12 « ui-ux ») : le serveur pose un BillboardGui « Label » (nom et revenu,
-- EnclosureService) sur la pièce Root de chaque dino ; le client lui donne le style du jeu : rareté en couleur (arc-en-ciel
-- pour Secret), nom (doré pour Golden, bleu glacier pour Diamond) et revenu en vert, police du jeu cernée de noir.
-- Seulement chez le client : rien ne change côté serveur. Les gardiens (sans DinoId) n'ont pas d'étiquette.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local DinoBuilder = require(ReplicatedStorage.Shared.DinoBuilder)
local UIKit = require(script.Parent.Parent.UI.UIKit)

local DinoLabelController = {}

local Colors = UIKit.Colors
local new = UIKit.new
local SIZE = UDim2.fromScale(9, 3.2) -- studs
local LIFT = 0.6 -- studs plus haut que l'étiquette du serveur (une ligne de plus)

local function rarityOf(model: Model): string?
	local attr = model:GetAttribute("Rarity")
	if type(attr) == "string" then
		return attr
	end
	local species = model:GetAttribute("Species")
	if type(species) ~= "string" then
		return nil
	end
	local def = Config.Species.ByModel[species] or Config.Species.ByName[species]
	local rarity = Config.Rarity.Species[if def then def.Name else species]
	return if type(rarity) == "string" then rarity else nil
end

local function line(gui: BillboardGui, name: string, y: number, height: number, color: Color3, textValue: string): TextLabel
	local label: TextLabel = new("TextLabel", {
		Name = name,
		BackgroundTransparency = 1,
		Position = UDim2.fromScale(0, y),
		Size = UDim2.fromScale(1, height),
		FontFace = UIKit.TitleFont,
		TextScaled = true,
		TextColor3 = color,
		Text = textValue,
		Parent = gui,
	})
	new("UIStroke", { Thickness = 2, Color = Colors.Ink, Parent = label })
	return label
end

-- Donne le style du jeu à l'étiquette d'un dino (une seule fois)
function DinoLabelController.Style(model: Model, gui: BillboardGui)
	if gui:GetAttribute("Styled") then
		return
	end
	gui:SetAttribute("Styled", true)
	local oldName = gui:FindFirstChild("Name")
	local oldIncome = gui:FindFirstChild("Income")
	local nameText = if oldName and oldName:IsA("TextLabel") then oldName.Text else tostring(model.Name)
	local incomeText = if oldIncome and oldIncome:IsA("TextLabel") then oldIncome.Text else ""
	for _, old in { oldName, oldIncome } do
		if old and old:IsA("GuiObject") then
			old.Visible = false
		end
	end
	gui.Size = SIZE
	gui.StudsOffset += Vector3.new(0, LIFT, 0)
	local rarity = rarityOf(model)
	local colors = if rarity then UIKit.Rarity[rarity] else nil
	if rarity and colors then
		local tag = line(gui, "Rarity", 0, 0.3, if colors.Rainbow then Colors.Text else colors.Tag, string.upper(rarity))
		if colors.Rainbow then
			new("UIGradient", { Color = UIKit.RainbowSequence, Parent = tag })
		end
	end
	local level = model:GetAttribute("Level")
	local nameColor = if level == DinoBuilder.Levels[2] then Colors.Yellow elseif level == DinoBuilder.Levels[3] then Colors.Cyan else Colors.Text
	line(gui, "Title", 0.3, 0.38, nameColor, nameText)
	line(gui, "Rate", 0.68, 0.32, Colors.GreenText, incomeText)
	-- (le serveur peut changer ses textes : on les suit)
	if oldName and oldName:IsA("TextLabel") then
		oldName:GetPropertyChangedSignal("Text"):Connect(function()
			local title = gui:FindFirstChild("Title")
			if title and title:IsA("TextLabel") then
				title.Text = oldName.Text
			end
		end)
	end
	if oldIncome and oldIncome:IsA("TextLabel") then
		oldIncome:GetPropertyChangedSignal("Text"):Connect(function()
			local rate = gui:FindFirstChild("Rate")
			if rate and rate:IsA("TextLabel") then
				rate.Text = oldIncome.Text
			end
		end)
	end
end

local function onLabel(model: Model, child: Instance)
	if child.Name == "Label" and child:IsA("BillboardGui") then
		DinoLabelController.Style(model, child)
	end
end

local function onDino(instance: Instance)
	if not instance:IsA("Model") or instance:GetAttribute("DinoId") == nil then
		return
	end
	local model = instance
	local function watchRoot(root: Instance)
		local label = root:FindFirstChild("Label")
		if label then
			onLabel(model, label)
		else
			root.ChildAdded:Connect(function(child)
				onLabel(model, child)
			end)
		end
	end
	local root = model:FindFirstChild("Root")
	if root then
		watchRoot(root)
	else
		local connection: RBXScriptConnection? = nil
		connection = model.ChildAdded:Connect(function(child)
			if child.Name == "Root" then
				if connection then
					connection:Disconnect()
				end
				watchRoot(child)
			end
		end)
	end
end

function DinoLabelController.Init()
	CollectionService:GetInstanceAddedSignal(DinoBuilder.Tag):Connect(onDino)
	for _, instance in CollectionService:GetTagged(DinoBuilder.Tag) do
		onDino(instance)
	end
end

return DinoLabelController
