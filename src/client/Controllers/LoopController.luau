--!strict
-- Côté client de la boucle (brief 3 « boucle ») :
--   * comptes à rebours dans le monde : chaque TextLabel tagué « LoopCountdown » avec l'attribut EndsAt (heure serveur,
--     Workspace:GetServerTimeNow() ou os.time() du serveur) affiche Format (« Refill in %s ») tant qu'il reste du
--     temps, puis Done (« READY! »). Sans EndsAt, le texte posé par le serveur reste tel quel. Cuves et gisements.
--   * barres de progression : chaque GuiObject tagué « LoopProgress » avec StartedAt et EndsAt (heures serveur) prend
--     la largeur du temps écoulé (Size = UDim2.fromScale(progression, 1)). Minuteurs des cuves.
--   * annonces de la boucle (bloc Secret...) : message système dans le chat (LoopAnnounce).
-- L'interface (HUD, écran de révélation...) est faite par le brief 12 avec les clés replica de la boucle.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService = game:GetService("TextChatService")
local Workspace = game:GetService("Workspace")

local Format = require(ReplicatedStorage.Shared.Format)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local LoopController = {}

local TAG = "LoopCountdown"
local PROGRESS_TAG = "LoopProgress"
local UPDATE_INTERVAL = 0.25
local MAX_ANNOUNCE = 200

local labels: { [TextLabel]: boolean } = {}
local bars: { [GuiObject]: boolean } = {}

-- Texte d'un compte à rebours à l'instant `now` (heure serveur)
function LoopController.CountdownText(label: TextLabel, now: number): string?
	local endsAt = label:GetAttribute("EndsAt")
	if type(endsAt) ~= "number" or endsAt ~= endsAt then
		return nil
	end
	local left = endsAt - now
	if left <= 0 then
		local done = label:GetAttribute("Done")
		return if type(done) == "string" then done else "Ready!"
	end
	local format = label:GetAttribute("Format")
	local clock = Format.Clock(math.ceil(left))
	if type(format) == "string" and string.find(format, "%s", 1, true) then
		return (string.gsub(format, "%%s", clock, 1))
	end
	return clock
end

-- Progression (0 à 1) d'une barre à l'instant `now` (heure serveur), nil sans StartedAt / EndsAt valides
-- (StartedAt nul ou après EndsAt : début inconnu, la barre garde la largeur posée par le serveur)
function LoopController.Progress(bar: GuiObject, now: number): number?
	local startedAt, endsAt = bar:GetAttribute("StartedAt"), bar:GetAttribute("EndsAt")
	if type(startedAt) ~= "number" or type(endsAt) ~= "number" or startedAt ~= startedAt or endsAt ~= endsAt then
		return nil
	end
	if startedAt <= 0 or startedAt > endsAt then
		return nil
	end
	if endsAt == startedAt or now >= endsAt then
		return 1
	end
	return math.clamp((now - startedAt) / (endsAt - startedAt), 0, 1)
end

local function refresh()
	local now = Workspace:GetServerTimeNow()
	for label in labels do
		local text = LoopController.CountdownText(label, now)
		if text and label.Text ~= text then
			label.Text = text
		end
	end
	for bar in bars do
		local progress = LoopController.Progress(bar, now)
		if progress then
			local size = UDim2.fromScale(progress, 1)
			if bar.Size ~= size then
				bar.Size = size
			end
		end
	end
end

local function track(instance: Instance)
	if instance:IsA("TextLabel") then
		labels[instance] = true
	end
end

local function trackBar(instance: Instance)
	if instance:IsA("GuiObject") then
		bars[instance] = true
	end
end

-- Message système dans le chat (TextChatService) ; rien si le canal général n'existe pas (ancien chat, tests)
function LoopController.Announce(text: string)
	local channels = TextChatService:FindFirstChild("TextChannels")
	local general = channels and channels:FindFirstChild("RBXGeneral")
	if general and general:IsA("TextChannel") then
		pcall(function()
			general:DisplaySystemMessage(text)
		end)
	end
end

function LoopController.Init()
	for _, instance in CollectionService:GetTagged(TAG) do
		track(instance)
	end
	CollectionService:GetInstanceAddedSignal(TAG):Connect(track)
	CollectionService:GetInstanceRemovedSignal(TAG):Connect(function(instance)
		if instance:IsA("TextLabel") then
			labels[instance] = nil
		end
	end)
	for _, instance in CollectionService:GetTagged(PROGRESS_TAG) do
		trackBar(instance)
	end
	CollectionService:GetInstanceAddedSignal(PROGRESS_TAG):Connect(trackBar)
	CollectionService:GetInstanceRemovedSignal(PROGRESS_TAG):Connect(function(instance)
		if instance:IsA("GuiObject") then
			bars[instance] = nil
		end
	end)
	Remotes.Event("LoopAnnounce").OnClientEvent:Connect(function(text: any)
		if type(text) == "string" and text ~= "" then
			LoopController.Announce(string.sub(text, 1, MAX_ANNOUNCE))
		end
	end)
end

function LoopController.Start()
	while true do
		refresh()
		task.wait(UPDATE_INTERVAL)
	end
end

return LoopController
