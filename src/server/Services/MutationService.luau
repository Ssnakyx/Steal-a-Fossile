--!strict
-- Mutations côté serveur (docs/MUTATIONS.md). Le tirage est fait à la réanimation par ReviveService.Roll avec
-- Config.Economy.RollMutation (mutations de toutes les zones + celle du biome du bloc, chance du pass VIP). Ici :
--   * annonce à tout le serveur (chat + message à l'écran) quand une mutation rare sort d'une cuve
--     (Chance <= Config.Economy.MutationAnnounce) ;
--   * commande admin « mutations [zone] » : probas des mutations d'une zone, avec la chance du joueur.
-- Signal : MutationRevealed(player, id, dino, info) à chaque dino réanimé avec une mutation (info : Economy.MutationInfo).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Economy = require(ReplicatedStorage.Shared.Config.Economy)
local Zones = require(ReplicatedStorage.Shared.Config.Zones)
local Format = require(ReplicatedStorage.Shared.Format)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Notify = require(script.Parent.Parent.Lib.Notify)
local Signals = require(script.Parent.Parent.Lib.Signals)
local AdminService = require(script.Parent.AdminService)
local EnclosureService = require(script.Parent.EnclosureService)
local ReviveService = require(script.Parent.ReviveService)

local MutationService = {}

local function number(value: number): string
	local text = string.format("%.2f", value)
	text = string.gsub(text, "0+$", "")
	text = string.gsub(text, "%.$", "")
	return text
end

-- « 1 in 200 » : chance de base d'une mutation (sans bonus)
function MutationService.Odds(info: Economy.MutationInfo): string
	return "1 in " .. tostring(math.floor(100 / info.Chance + 0.5))
end

-- Texte d'annonce d'un dino réanimé (nil si sa mutation n'est pas assez rare pour être annoncée)
function MutationService.AnnounceText(player: Player, dino: EnclosureService.Dino): string?
	local info = Economy.Mutation(dino.Mutation)
	if not info or info.Chance > Economy.MutationAnnounce then
		return nil
	end
	local name = EnclosureService.DisplayName(dino)
	return string.format(
		"%s revived %s %s! %s mutation: %s, x%s income",
		player.DisplayName,
		Format.Article(name),
		name,
		info.Name,
		MutationService.Odds(info),
		number(info.Income)
	)
end

-- Zone d'après un numéro (1 à 8) ou un nom (sans faire attention aux majuscules)
function MutationService.FindZone(text: string?): string?
	if type(text) ~= "string" or text == "" then
		return nil
	end
	local index = tonumber(text)
	if index then
		local zone = Zones.List[index]
		return if zone then zone.Name else nil
	end
	local wanted = string.lower(text)
	for _, zone in Zones.List do
		if string.lower(zone.Name) == wanted or string.lower((string.gsub(zone.Name, " ", ""))) == wanted then
			return zone.Name
		end
	end
	return nil
end

-- Probas affichables d'une zone pour ce joueur (pass VIP compris) : voir Economy.MutationChances
function MutationService.Chances(player: Player, zoneName: string): { Economy.MutationChance }
	return Economy.MutationChances(zoneName, ReviveService.MutationLuck(player))
end

local function onRevived(player: Player, id: string, dino: EnclosureService.Dino)
	if type(dino) ~= "table" then
		return
	end
	local info = Economy.Mutation(dino.Mutation)
	if not info then
		return
	end
	Signals.Fire("MutationRevealed", player, id, dino, info)
	local text = MutationService.AnnounceText(player, dino)
	if text then
		Remotes.Event("LoopAnnounce"):FireAllClients(text)
		Notify.All(text, "success")
	end
end

function MutationService.Init()
	Signals.Connect("DinoRevived", onRevived)
	AdminService.RegisterCommand("mutations", {
		Description = "Mutation odds of a zone, with your luck",
		Usage = "mutations [zone 1-8 or name]",
		Run = function(player: Player, args: { string })
			local zone = MutationService.FindZone(args[1]) or (if args[1] then nil else Zones.List[1].Name)
			if not zone then
				return false, "Usage: mutations [zone 1-8 or name]"
			end
			local parts = {}
			for _, chance in MutationService.Chances(player, zone) do
				local name = if chance.Name == "" then "None" else chance.Name
				table.insert(parts, string.format("%s %s%% (x%s)", name, number(chance.Chance * 100), number(chance.Income)))
			end
			return true, zone .. ": " .. table.concat(parts, ", ")
		end,
	})
end

return MutationService
