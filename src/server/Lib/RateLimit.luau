--!strict
-- Limite de fréquence par joueur et par action (seau à jetons, reprise de Steal a Snack) : le spam de remotes ne sert
-- à rien. Net.Function / Net.Event l'appliquent tout seuls ; à appeler à la main pour un handler posé autrement.

local Players = game:GetService("Players")

local RateLimit = {}

type Bucket = { Tokens: number, Last: number, Blocked: number }

local buckets: { [Player]: { [string]: Bucket } } = {}

-- perSecond : appels permis par seconde en moyenne ; burst : rafale maximale (par défaut max(1, perSecond))
function RateLimit.Allow(player: Player, key: string, perSecond: number, burst: number?): boolean
	local playerBuckets = buckets[player]
	if not playerBuckets then
		playerBuckets = {}
		buckets[player] = playerBuckets
	end
	local now = os.clock()
	local capacity = burst or math.max(1, perSecond)
	local bucket = playerBuckets[key]
	if not bucket then
		bucket = { Tokens = capacity, Last = now, Blocked = 0 }
		playerBuckets[key] = bucket
	end
	bucket.Tokens = math.min(capacity, bucket.Tokens + (now - bucket.Last) * perSecond)
	bucket.Last = now
	if bucket.Tokens >= 1 then
		bucket.Tokens -= 1
		return true
	end
	bucket.Blocked += 1
	if bucket.Blocked % 200 == 1 then
		warn(string.format("[RateLimit] %s (%d) sends too many '%s' (%d refused)", player.Name, player.UserId, key, bucket.Blocked))
	end
	return false
end

-- Oublie les compteurs d'un joueur (tests, debug)
function RateLimit.Reset(player: Player)
	buckets[player] = nil
end

Players.PlayerRemoving:Connect(function(player)
	buckets[player] = nil
end)

return RateLimit
