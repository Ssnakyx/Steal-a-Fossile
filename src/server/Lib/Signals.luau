--!strict
-- Petit bus d'événements entre services serveur (reprise de Steal a Snack) : un service annonce ce qui arrive, les
-- autres écoutent sans se requérir en cercle (quêtes, analytics, sons...).
--   Signals.Fire("DinoRevived", player, dino)
--   Signals.Connect("DinoRevived", function(player, dino) ... end)
-- Chaque fonction branchée tourne dans son propre fil. Les signaux d'un domaine sont listés en tête de son service.
--
-- Signaux du domaine Core (brief 1) :
--   PlayerReady(player, data)                     données chargées, services prêts (après les OnPlayerReady)
--   MoneyChanged(player, delta, reason, total)    argent gagné (delta > 0) ou dépensé (delta < 0), raison en texte
--   PurchaseGranted(player, productKey, robux)    produit Robux donné et sauvegardé

local Signals = {}

local handlers: { [string]: { (...any) -> () } } = {}

function Signals.Connect(name: string, handler: (...any) -> ()): () -> ()
	local list = handlers[name]
	if not list then
		list = {}
		handlers[name] = list
	end
	table.insert(list, handler)
	-- renvoie de quoi se débrancher
	return function()
		local current = handlers[name]
		local index = current and table.find(current, handler)
		if current and index then
			table.remove(current, index)
		end
	end
end

function Signals.Fire(name: string, ...: any)
	local list = handlers[name]
	if not list then
		return
	end
	for _, handler in table.clone(list) do
		task.spawn(handler, ...)
	end
end

return Signals
