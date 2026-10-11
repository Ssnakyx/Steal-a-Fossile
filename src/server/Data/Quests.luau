--!strict
-- Données du joueur, domaine Quests : les 3 quêtes du jour.
-- Fichier posé par le brief 1 « fondations » ; appartient au brief 13 « quotidien-quetes ».
-- Format d'un domaine : voir src/server/Services/DataService.luau.

local Guard = require(script.Parent.Parent.Lib.Guard)

type Data = { [string]: any }

return {
	Version = 1,
	Defaults = {
		Quests = {
			Day = 0, -- jour des quêtes en cours (os.time() // 86400), 0 = pas encore tirées
			List = {}, -- { { Id = "...", Progress = 0, Claimed = false } } (3 quêtes)
		},
	},

	Sanitize = function(data: Data)
		data.Quests.Day = Guard.IntegerOr(data.Quests.Day, 0, 0)
		local list = {}
		for _, quest in data.Quests.List do
			if type(quest) == "table" and type(quest.Id) == "string" then
				quest.Progress = Guard.NumberOr(quest.Progress, 0, 0)
				quest.Claimed = quest.Claimed == true
				table.insert(list, quest)
			end
		end
		data.Quests.List = list
	end,
}
