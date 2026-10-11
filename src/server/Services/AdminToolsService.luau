--!strict
-- Commandes d'admin en plus de celles des domaines (menu d'admin, AdminController côté client) :
--   resetdata <player> confirm   remet la sauvegarde du joueur à zéro et l'expulse (il revient comme un nouveau joueur)
--   goto <player>                se téléporter à côté d'un joueur
--   bring <player>               amener un joueur à côté de soi
-- Le droit est vérifié par AdminService.Run, comme pour toutes les commandes.

local Players = game:GetService("Players")

local AdminService = require(script.Parent.AdminService)
local DataService = require(script.Parent.DataService)

local AdminToolsService = {}

local function root(player: Player): BasePart?
	local character = player.Character
	local part = character and character:FindFirstChild("HumanoidRootPart")
	return if part and part:IsA("BasePart") then part else nil
end

-- Pose le personnage de `mover` à côté de celui de `anchor`
local function moveNextTo(mover: Player, anchor: Player): boolean
	local character = mover.Character
	local target = root(anchor)
	if not (character and target) then
		return false
	end
	character:PivotTo(target.CFrame * CFrame.new(0, 0, 4))
	return true
end

function AdminToolsService.Init()
	AdminService.RegisterCommand("resetdata", {
		Description = "Wipe a player's save and kick them (they come back as a new player)",
		Usage = "resetdata <player> confirm",
		Run = function(caller: Player, args: { string })
			local target = if args[1] then AdminService.FindPlayer(caller, args[1]) else nil
			if not target or string.lower(args[2] or "") ~= "confirm" then
				return false, "Usage: resetdata <player> confirm"
			end
			if not DataService.Reset(target) then
				return false, "Save not writable here (Studio never saves: use tutorial 0 instead)"
			end
			local name = target.Name
			-- (l'expulsion déclenche la dernière sauvegarde, qui écrit les données neuves)
			task.defer(function()
				if target.Parent == Players then
					target:Kick("Your data was reset by an admin. Rejoin to start over!")
				end
			end)
			return true, name .. "'s data was reset"
		end,
	})
	AdminService.RegisterCommand("goto", {
		Description = "Teleport next to a player",
		Usage = "goto <player>",
		Run = function(caller: Player, args: { string })
			local target = if args[1] then AdminService.FindPlayer(caller, args[1]) else nil
			if not target or target == caller then
				return false, "Usage: goto <player>"
			end
			if not moveNextTo(caller, target) then
				return false, "No character"
			end
			return true, "Teleported to " .. target.Name
		end,
	})
	AdminService.RegisterCommand("bring", {
		Description = "Bring a player next to you",
		Usage = "bring <player>",
		Run = function(caller: Player, args: { string })
			local target = if args[1] then AdminService.FindPlayer(caller, args[1]) else nil
			if not target or target == caller then
				return false, "Usage: bring <player>"
			end
			if not moveNextTo(target, caller) then
				return false, "No character"
			end
			return true, target.Name .. " brought to you"
		end,
	})
end

return AdminToolsService
