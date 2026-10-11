--!strict
-- Tests FossilDebug du domaine Core (brief 1) : sauvegarde, argent, achats, remotes, admin, format.
-- Lancer pendant un Play (barre de commande, vue serveur) : game.ServerScriptService.FossilDebug:Invoke("all")

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Format = require(ReplicatedStorage.Shared.Format)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Services = script.Parent.Parent.Services
local AdminService = require(Services.AdminService)
local DataService = require(Services.DataService)
local DebugService = require(Services.DebugService)
local MoneyService = require(Services.MoneyService)
local ReceiptService = require(Services.ReceiptService)

type Tester = DebugService.Tester

-- Produit de test, jamais en vente (Id = 0) : compte combien de fois il est donné
local granted = 0
ReceiptService.Register("DebugTestProduct", 0, function()
	granted += 1
	return true
end)

return {
	data = function(t: Tester)
		local player = t:Player()
		if not t:Check(player, "a player is loaded") then
			return
		end
		local data = DataService.Get(player :: Player) :: DataService.Data
		local defaults = DataService.Defaults()
		for field in defaults do
			t:Check(data[field] ~= nil, "field " .. field)
		end
		t:Equal(data.Version, DataService.SchemaVersion, "schema version")
		for _, domain in DataService.Domains() do
			t:Check(type(data.Domains[domain]) == "number", "domain version " .. domain)
		end
		local problems = DataService.Problems(data)
		t:Equal(#problems, 0, "data can be saved")
		if #problems > 0 then
			t:Note(table.concat(problems, ", "))
		end
	end,

	money = function(t: Tester)
		local player = t:Player()
		if not t:Check(player, "a player is loaded") then
			return
		end
		local target = player :: Player
		local start = MoneyService.Get(target)
		t:Check(MoneyService.Add(target, 100, "Debug"), "add 100")
		t:Equal(MoneyService.Get(target), start + 100, "money went up")
		t:Check(not MoneyService.Add(target, 0 / 0, "Debug"), "NaN refused")
		t:Check(not MoneyService.Add(target, math.huge, "Debug"), "infinity refused")
		t:Check(not MoneyService.Add(target, -5, "Debug"), "negative refused")
		t:Check(not MoneyService.Spend(target, start + 1000, "Debug"), "cannot spend more than owned")
		t:Check(MoneyService.Spend(target, 100, "Debug"), "spend 100")
		t:Equal(MoneyService.Get(target), start, "money back to start")
		local stat = target:FindFirstChild("leaderstats") and (target :: any).leaderstats:FindFirstChild("Money")
		t:Check(stat and stat.Value == Format.Money(start), "leaderstats shows money")
	end,

	receipts = function(t: Tester)
		local player = t:Player()
		if not t:Check(player, "a player is loaded") then
			return
		end
		local target = player :: Player
		local before = granted
		local purchaseId = "DEBUG-" .. os.clock()
		local ok = ReceiptService.Simulate(target, "DebugTestProduct", purchaseId)
		t:Check(ok, "simulated purchase granted")
		t:Equal(granted, before + 1, "product given once")
		ReceiptService.Simulate(target, "DebugTestProduct", purchaseId)
		t:Equal(granted, before + 1, "same purchase not given twice")
		t:Check(ReceiptService.HasProcessed(target, purchaseId), "purchase remembered")
		t:Check(not ReceiptService.IsOnSale("DebugTestProduct"), "Id 0 product not on sale")
		t:Check(not (ReceiptService.Simulate(target, "NoSuchProduct")), "unknown product refused")
	end,

	remotes = function(t: Tester)
		local folder = ReplicatedStorage:FindFirstChild("Remotes")
		if not t:Check(folder, "Remotes folder exists") then
			return
		end
		local classes = { Event = "RemoteEvent", Function = "RemoteFunction", Unreliable = "UnreliableRemoteEvent" }
		for _, declaration in Remotes.List() do
			local remote = (folder :: Instance):FindFirstChild(declaration.Name)
			t:Check(remote and remote.ClassName == classes[declaration.Kind], declaration.Name .. " (" .. declaration.Domain .. ")")
		end
	end,

	admin = function(t: Tester)
		local player = t:Player()
		if not t:Check(player, "a player is loaded") then
			return
		end
		local target = player :: Player
		t:Check(AdminService.IsAdmin(target), "test player is admin in Studio")
		t:Equal(target:GetAttribute("Admin"), true, "Admin attribute")
		local ok = AdminService.Run(target, "help", {})
		t:Check(ok, "help runs")
		t:Check(not (AdminService.Run(target, "nosuchcommand", {})), "unknown command refused")
		t:Check(not (AdminService.Run(target, "money", { "nan" })), "bad amount refused")
		t:Check(not (AdminService.Run(target, { "not a name" }, nil)), "bad command name refused")
	end,

	format = function(t: Tester)
		t:Equal(Format.Number(1500), "1.5K", "1500")
		t:Equal(Format.Money(2500000), "$2.5M", "money 2.5M")
		t:Equal(Format.Duration(200), "3m 20s", "duration 200 s")
		t:Equal(Format.Clock(65), "1:05", "clock 65 s")
	end,
}
