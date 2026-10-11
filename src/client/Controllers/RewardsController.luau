--!strict
-- Côté client des récompenses (Config.Daily) : trois boutons à gauche de l'écran (Daily, Spin, Gifts), avec une
-- pastille rouge quand quelque chose attend, et leurs menus :
--   * Daily Rewards : calendrier de 14 jours, bouton Claim, série en cours. S'ouvre tout seul à l'arrivée quand la
--     récompense du jour attend (Config.Daily.Login.AutoOpen) ; pour un nouveau joueur, juste après son premier dino.
--   * Lucky Spin : vraie roue de 8 parts qui tourne, tableau de leurs chances (toute chance payante affiche ses probas), tour gratuit du jour,
--     tours en réserve, tours à acheter en Robux (seulement si le serveur les permet à ce joueur).
--   * Free Gifts : cadeaux de temps de jeu avec leur compte à rebours.
-- Le client ne décide rien : il lit les clés replica « Daily », « Spins », « Gifts », « RewardScale » et demande au
-- serveur (ClaimDaily, Spin, ClaimGift, GetSpinOffers, BuySpins).
-- API (HUD du brief 12) : RewardsController.Open("Daily" | "Spin" | "Gifts"), Close(nom?), SetButtonsVisible(bool),
-- RewardsController.Badge(nom) -> nombre de la pastille ; ClaimDaily(), Spin(), ClaimGift(n) font la demande et
-- renvoient la réponse du serveur.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local DailyConfig = require(ReplicatedStorage.Shared.Config.Daily)
local Format = require(ReplicatedStorage.Shared.Format)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local UIKit = require(script.Parent.Parent.UI.UIKit)
local NotifyController = require(script.Parent.NotifyController)
local ReplicaController = require(script.Parent.ReplicaController)

type Reward = DailyConfig.Reward
type Panel = UIKit.Panel

local RewardsController = {}

local Colors = UIKit.Colors
local new = UIKit.new
local DAYS = DailyConfig.Login.Days
local PRIZES = DailyConfig.Spins.Prizes
local GIFTS = DailyConfig.Gifts
local REFRESH = 0.25 -- secondes entre deux mises à jour des comptes à rebours et des pastilles
local AUTO_OPEN_DELAY = 2.5 -- secondes après l'arrivée avant d'ouvrir le calendrier tout seul
local FIRST_DINO_DELAY = 3 -- nouveau joueur : secondes après son premier dino avant d'ouvrir le calendrier
local NEW_PLAYER_WAIT = 30 * 60 -- au plus, secondes d'attente du premier dino (ensuite plus d'ouverture toute seule)
local Z = 23 -- (contenu des panneaux : au-dessus du corps, ZIndex 22)

local KIND_COLOR: { [string]: Color3 } = {
	Money = Colors.Money,
	Speed = Colors.Cyan,
	Spins = Colors.Pink,
	BearTraps = Colors.Orange,
}
-- Icône du pack de chaque genre de récompense (UIKit.Icons)
local KIND_ICON: { [string]: string } = {
	Money = "coins",
	Speed = "speed",
	Spins = "wheel",
	BearTraps = "shield",
	Block = "egg",
}

type Ui = {
	Root: Frame,
	Buttons: Frame,
	Badges: { [string]: { Frame: Frame, Label: TextLabel } },
	Panels: { [string]: Panel },
	Refreshers: { [string]: () -> () },
}

local ui: Ui? = nil
local spinning = false
-- Animation de la roue (posée par le menu de la roue) : tourne jusqu'à la case donnée puis appelle la fonction
local animateSpin: ((number, () -> ()) -> ())? = nil

local function serverNow(): number
	return Workspace:GetServerTimeNow()
end

local function scale(): DailyConfig.Scale?
	local value = ReplicaController.Get("RewardScale")
	if type(value) == "table" and type(value.Income) == "number" and type(value.Speed) == "number" then
		return value :: DailyConfig.Scale
	end
	return nil
end

local function rewardColor(reward: Reward): (Color3, boolean)
	if reward.Kind == "Block" then
		local colors = UIKit.Rarity[reward.Rarity or ""] or UIKit.Rarity.Common
		return colors.Fill, colors.Rainbow == true
	end
	return KIND_COLOR[reward.Kind] or Colors.Slate, false
end

local function tableOr(key: string): { [string]: any }?
	local value = ReplicaController.Get(key)
	return if type(value) == "table" then value else nil
end

-- ===================================================================== état lu dans le Replica

-- Temps de jeu du jour (secondes), avec le temps écoulé depuis le dernier envoi du serveur
local function giftSeconds(gifts: { [string]: any }): number
	local seconds = if type(gifts.Seconds) == "number" then gifts.Seconds else 0
	local at = if type(gifts.At) == "number" then gifts.At else serverNow()
	return seconds + math.max(0, serverNow() - at)
end

local function giftClaimed(gifts: { [string]: any }, index: number): boolean
	local claimed = gifts.Claimed
	return type(claimed) == "table" and table.find(claimed, index) ~= nil
end

function RewardsController.Badge(name: string): number
	if name == "Daily" then
		local daily = tableOr("Daily")
		return if daily and daily.CanClaim == true then 1 else 0
	elseif name == "Spin" then
		local spins = tableOr("Spins")
		if not spins then
			return 0
		end
		return (tonumber(spins.Free) or 0) + (tonumber(spins.Stored) or 0)
	elseif name == "Gifts" then
		local gifts = tableOr("Gifts")
		if not gifts then
			return 0
		end
		local seconds = giftSeconds(gifts)
		local count = 0
		for index, gift in GIFTS do
			if seconds >= gift.Minutes * 60 and not giftClaimed(gifts, index) then
				count += 1
			end
		end
		return count
	end
	return 0
end

-- ===================================================================== demandes au serveur

function RewardsController.ClaimDaily(): (boolean, string)
	local ok, text = Remotes.Function("ClaimDaily"):InvokeServer()
	local message = if type(text) == "string" then text else "Try again"
	if not ok then
		NotifyController.Show(message, "error")
	end
	return ok == true, message
end

function RewardsController.ClaimGift(index: number): (boolean, string)
	local ok, text = Remotes.Function("ClaimGift"):InvokeServer(index)
	local message = if type(text) == "string" then text else "Try again"
	if not ok then
		NotifyController.Show(message, "error")
	end
	return ok == true, message
end

-- ===================================================================== éléments communs

local function text(props: { [string]: any }): TextLabel
	props.ZIndex = props.ZIndex or Z + 2
	return UIKit.label(props)
end

-- Voile sombre sur une case (déjà prise), avec une coche du pack au milieu
local function shade(tile: Frame): Frame
	local veil: Frame = new("Frame", {
		Name = "Shade",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.45,
		BorderSizePixel = 0,
		Visible = false,
		ZIndex = Z + 4,
		Parent = tile,
	})
	UIKit.icon("check", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.45),
		Size = UDim2.fromOffset(64, 64),
		ZIndex = Z + 5,
		Parent = veil,
	})
	return veil
end

-- Contour lumineux autour d'une case (jour à prendre, cadeau prêt)
local function glow(tile: GuiObject, color: Color3): Frame
	return new("Frame", {
		Name = "Glow",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1, 12, 1, 12),
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = Z + 5,
		Parent = tile,
	}, { new("UIStroke", { Color = color, Thickness = 5, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }) })
end

-- Petit rebond d'une case qui attend le joueur (jour du calendrier, cadeau prêt)
local function pulse(target: GuiObject): UIScale
	local existing = target:FindFirstChild("Pulse")
	return if existing and existing:IsA("UIScale") then existing else new("UIScale", { Name = "Pulse", Parent = target })
end

local function setPulse(scaleObject: UIScale, on: boolean)
	local want = if on then 1.06 else 1
	if on then
		-- (va et vient doux : 1 -> 1.06 -> 1 en 0,8 s)
		local beat = math.floor(os.clock() / 0.8) % 2 == 0
		want = if beat then 1.06 else 1
	end
	if math.abs(scaleObject.Scale - want) > 0.001 then
		UIKit.tween(scaleObject, 0.4, { Scale = want }, Enum.EasingStyle.Sine)
	end
end

-- ===================================================================== calendrier

local function buildDaily(root: Frame): (Panel, () -> ())
	local panel = UIKit.panel(root, "Daily Rewards", Colors.Yellow, Vector2.new(960, 566))
	local content = panel.Content
	local columns = 7
	local gap = 10
	local width = 928
	local tileW = math.floor((width - (columns - 1) * gap) / columns)
	local tileH = 172
	type Cell = { Tile: Frame, Value: TextLabel, Status: TextLabel, Shade: Frame, Glow: Frame, Pulse: UIScale }
	local cells: { Cell } = {}
	for index, reward in DAYS do
		local column = (index - 1) % columns
		local row = (index - 1) // columns
		local color, rainbow = rewardColor(reward)
		local tile = UIKit.card({
			Name = "Day" .. index,
			Color = color,
			Rainbow = rainbow,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset(column * (tileW + gap) + tileW / 2, row * (tileH + gap) + tileH / 2),
			Size = UDim2.fromOffset(tileW, tileH),
			ZIndex = Z,
			Parent = content,
		})
		text({
			Name = "Day",
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, 7),
			Size = UDim2.new(0.86, 0, 0, 24),
			Text = "DAY " .. index,
			TextColor3 = Colors.Yellow,
			Parent = tile,
		})
		UIKit.icon(KIND_ICON[reward.Kind] or "gift", {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, 34),
			Size = UDim2.fromOffset(76, 76),
			ZIndex = Z + 2,
			Parent = tile,
		})
		local value = text({
			Name = "Value",
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, 112),
			Size = UDim2.new(0.92, 0, 0, 26),
			Text = DailyConfig.Label(reward, scale()),
			Parent = tile,
		})
		local status = text({
			Name = "Status",
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -8),
			Size = UDim2.new(0.9, 0, 0, 22),
			Text = "",
			ZIndex = Z + 6,
			Parent = tile,
		})
		table.insert(cells, {
			Tile = tile,
			Value = value,
			Status = status,
			Shade = shade(tile),
			Glow = glow(tile, Colors.Yellow),
			Pulse = pulse(tile),
		})
	end
	local bottom = 2 * tileH + gap + 16
	local streak = text({
		Name = "Streak",
		Position = UDim2.fromOffset(0, bottom),
		Size = UDim2.fromOffset(460, 40),
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "",
		Parent = content,
	})
	text({
		Name = "Hint",
		Position = UDim2.fromOffset(0, bottom + 46),
		Size = UDim2.fromOffset(520, 40),
		TextXAlignment = Enum.TextXAlignment.Left,
		Body = true,
		MaxTextSize = 20,
		Text = "Come back every day for bigger rewards. Miss a day and you restart at Day 1!",
		TextColor3 = Colors.Muted,
		TextWrapped = true,
		Parent = content,
	})
	local claim = UIKit.button({
		Name = "Claim",
		Text = "CLAIM",
		Color = Colors.Green,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, bottom + 4),
		Size = UDim2.fromOffset(320, 78),
		MaxTextSize = 34,
		ZIndex = Z,
		Parent = content,
	}, function()
		task.spawn(RewardsController.ClaimDaily)
	end)

	local function refresh()
		local daily = tableOr("Daily")
		local currentScale = scale()
		for index, cell in cells do
			cell.Value.Text = DailyConfig.Label(DAYS[index], currentScale)
		end
		if not daily then
			return
		end
		local nextDay = tonumber(daily.Next) or 1
		local canClaim = daily.CanClaim == true
		local claimedUpTo = if canClaim then nextDay - 1 else nextDay
		local tomorrow = if canClaim then 0 else (nextDay % #DAYS) + 1
		for index, cell in cells do
			local done = index <= claimedUpTo
			local today = canClaim and index == nextDay
			cell.Shade.Visible = done
			cell.Glow.Visible = today
			setPulse(cell.Pulse, today)
			cell.Status.Text = if done then "CLAIMED" elseif today then "TODAY" elseif index == tomorrow then "TOMORROW" else ""
			cell.Status.TextColor3 = if done then Colors.GreenText elseif today then Colors.Yellow else Colors.Text
		end
		local days = tonumber(daily.Streak) or 0
		streak.Text = string.format("Streak: %d day%s   Best: %d", days, if days == 1 then "" else "s", tonumber(daily.Best) or 0)
		if canClaim then
			claim.Text = "CLAIM DAY " .. nextDay
			claim:SetAttribute("Disabled", false)
		else
			local left = (tonumber(daily.NextReset) or 0) - serverNow()
			claim.Text = "NEXT IN " .. Format.Clock(math.max(0, left))
			claim:SetAttribute("Disabled", true)
		end
	end
	return panel, refresh
end

-- ===================================================================== roue de la chance

local WHEEL_RADIUS = 214
local SPIN_TIME = 3.6 -- secondes de rotation (le serveur attend Config.Daily.Spins.Cooldown = 4 s entre deux tours)
local SPIN_TURNS = 5 -- tours complets avant de s'arrêter

-- Couleur d'une case de la roue : celle de la récompense, une case sur deux un peu plus claire
local function wedgeColor(index: number): Color3
	local reward = PRIZES[index].Reward
	local color = rewardColor(reward)
	if reward.Kind == "Money" and (reward.IncomeMinutes or 0) >= 30 then
		color = UIKit.Darken(color, 0.18) -- (gros gain : vert plus profond que l'argent simple)
	end
	return if index % 2 == 0 then UIKit.Lighten(color, 0.1) else color
end

-- Texte court d'une case de la roue (« +$300 », « +300 », « x3 », « EPIC »)
local function wedgeText(reward: Reward, currentScale: DailyConfig.Scale?): string
	local amount = DailyConfig.Amount(reward, currentScale)
	if reward.Kind == "Money" then
		return "+$" .. Format.Number(amount)
	elseif reward.Kind == "Speed" then
		return "+" .. Format.Number(amount)
	elseif reward.Kind == "Spins" then
		return "+" .. amount
	elseif reward.Kind == "BearTraps" then
		return "x" .. amount
	elseif reward.Kind == "Block" then
		return string.upper(tostring(reward.Rarity))
	end
	return reward.Kind
end

export type Wheel = {
	Labels: { TextLabel },
	Angle: () -> number,
	SetAngle: (number) -> (),
}

-- Dessine la roue. Les parts de couleur sont peintes dans quatre quarts fixes (cadres carrés qui rognent) : chaque quart
-- reçoit au plus trois couches (la part qui couvre son début, puis celles qui commencent dans le quart), chacune un
-- disque dont un dégradé de transparence à bord franc efface ce qui est avant la limite de la part. SetAngle(degrés)
-- repeint les quarts et tourne le reste (traits, clous, icônes, gains) : la roue tourne sans CanvasGroup (un
-- CanvasGroup tourné ne tourne pas les rognages ni les dégradés).
local function buildWheel(parent: GuiObject, center: Vector2): Wheel
	local r = WHEEL_RADIUS
	local count = #PRIZES
	local step = 360 / count
	local holder: Frame = new("Frame", {
		Name = "Wheel",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(center.X, center.Y),
		Size = UDim2.fromOffset(2 * r, 2 * r),
		BackgroundTransparency = 1,
		ZIndex = Z,
		Parent = parent,
	})
	-- (bord : anneau doré cerné de noir, plus large que la roue)
	new("Frame", {
		Name = "Rim",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1, 26, 1, 26),
		BackgroundColor3 = Colors.Yellow,
		BorderSizePixel = 0,
		ZIndex = Z,
		Parent = holder,
	}, {
		new("UICorner", { CornerRadius = UDim.new(0.5, 0) }),
		new("UIStroke", { Color = Colors.Ink, Thickness = 5, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
		new("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(255, 236, 120), Color3.fromRGB(240, 150, 20)) }),
	})
	-- coin de chaque quart (haut-droite, bas-droite, bas-gauche, haut-gauche) et place du disque dans ce quart
	local quarters = {
		{ Clip = Vector2.new(r, 0), Disc = Vector2.new(-r, 0) },
		{ Clip = Vector2.new(r, r), Disc = Vector2.new(-r, -r) },
		{ Clip = Vector2.new(0, r), Disc = Vector2.new(0, -r) },
		{ Clip = Vector2.new(0, 0), Disc = Vector2.new(0, 0) },
	}
	local cut = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.5, 1),
		NumberSequenceKeypoint.new(0.502, 0),
		NumberSequenceKeypoint.new(1, 0),
	})
	type Layer = { Disc: Frame, Gradient: UIGradient }
	local layers: { { Layer } } = {}
	for index, quarter in quarters do
		local clip: Frame = new("Frame", {
			Name = "Quarter" .. index,
			Position = UDim2.fromOffset(quarter.Clip.X, quarter.Clip.Y),
			Size = UDim2.fromOffset(r, r),
			BackgroundTransparency = 1,
			ClipsDescendants = true,
			ZIndex = Z + 1,
			Parent = holder,
		})
		local list = {}
		for depth = 1, 3 do
			local disc: Frame = new("Frame", {
				Name = "Layer" .. depth,
				Position = UDim2.fromOffset(quarter.Disc.X, quarter.Disc.Y),
				Size = UDim2.fromOffset(2 * r, 2 * r),
				BackgroundColor3 = Color3.new(1, 1, 1),
				BorderSizePixel = 0,
				ZIndex = Z + depth,
				Parent = clip,
			}, { new("UICorner", { CornerRadius = UDim.new(0.5, 0) }) })
			local gradient: UIGradient = new("UIGradient", { Transparency = cut, Enabled = depth > 1, Parent = disc })
			table.insert(list, { Disc = disc, Gradient = gradient })
		end
		table.insert(layers, list)
	end
	local colors: { Color3 } = {}
	for index = 1, count do
		colors[index] = wedgeColor(index)
	end

	-- ce qui tourne tel quel : traits blancs entre les parts, clous du bord, icône et gain de chaque part
	local turning: { { Frame: GuiObject, Base: number } } = {}
	local function spinner(frame: GuiObject, base: number)
		table.insert(turning, { Frame = frame, Base = base })
	end
	for line = 0, count / 2 - 1 do
		spinner(new("Frame", {
			Name = "Line" .. line,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(5, 2 * r),
			BackgroundColor3 = Color3.new(1, 1, 1),
			BorderSizePixel = 0,
			ZIndex = Z + 5,
			Parent = holder,
		}), line * step)
	end
	local labels: { TextLabel } = {}
	for index, prize in PRIZES do
		local middle = (index - 0.5) * step
		local spoke: Frame = new("Frame", {
			Name = "Prize" .. index,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(110, 2 * r),
			BackgroundTransparency = 1,
			ZIndex = Z + 6,
			Parent = holder,
		})
		spinner(spoke, middle)
		UIKit.icon(KIND_ICON[prize.Reward.Kind] or "gift", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset(55, r * 0.2),
			Size = UDim2.fromOffset(52, 52),
			ZIndex = Z + 6,
			Parent = spoke,
		})
		-- (gain écrit le long du rayon, du moyeu vers le bord)
		local value = text({
			Name = "Value",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset(55, r * 0.53),
			Size = UDim2.fromOffset(r * 0.36, 28),
			Text = wedgeText(prize.Reward, nil),
			ZIndex = Z + 7,
			Parent = spoke,
		})
		table.insert(labels, value)
		local arm: Frame = new("Frame", {
			Name = "PegArm" .. index,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(20, 2 * r),
			BackgroundTransparency = 1,
			ZIndex = Z + 7,
			Parent = holder,
		})
		spinner(arm, index * step)
		new("Frame", {
			Name = "Peg",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, 0, 0, 9),
			Size = UDim2.fromOffset(12, 12),
			BackgroundColor3 = Color3.new(1, 1, 1),
			BorderSizePixel = 0,
			ZIndex = Z + 7,
			Parent = arm,
		}, {
			new("UICorner", { CornerRadius = UDim.new(0.5, 0) }),
			new("UIStroke", { Color = Colors.Ink, Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
		})
	end
	-- flèche rouge en haut (losange cerné de noir qui mord sur la roue)
	new("Frame", {
		Name = "Pointer",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0, -6),
		Size = UDim2.fromOffset(40, 40),
		Rotation = 45,
		BackgroundColor3 = Colors.Tomato,
		BorderSizePixel = 0,
		ZIndex = Z + 8,
		Parent = holder,
	}, {
		new("UIStroke", { Color = Colors.Ink, Thickness = 4, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
		new("UIGradient", { Rotation = 45, Color = ColorSequence.new(Color3.fromRGB(255, 130, 130), Colors.Tomato) }),
	})

	local angle = 0
	local function setAngle(degrees: number)
		angle = degrees
		local turn = degrees % 360
		for quarterIndex, list in layers do
			local start = (quarterIndex - 1) * 90
			-- part qui couvre le début du quart, puis les limites des parts suivantes dans le quart
			local into = (start - turn) % 360
			local first = math.floor(into / step)
			local edge = (first + 1) * step - into -- (degrés entre le début du quart et la limite suivante)
			for depth, layer in list do
				local part = (first + depth - 1) % count + 1
				local limit = start + edge + (depth - 2) * step
				local shown = depth == 1 or (limit < start + 90 - 0.01)
				layer.Disc.Visible = shown
				if shown then
					layer.Disc.BackgroundColor3 = colors[part]
					if depth > 1 then
						-- (garde ce qui est après la limite, dans le sens des aiguilles d'une montre)
						layer.Gradient.Rotation = limit
					end
				end
			end
		end
		for _, item in turning do
			item.Frame.Rotation = item.Base + degrees
		end
		-- (gains sur la moitié gauche : retournés pour ne jamais se lire la tête en bas)
		for index, label in labels do
			label.Rotation = if ((index - 0.5) * step + degrees) % 360 > 180 then 90 else -90
		end
	end
	setAngle(0)

	return {
		Labels = labels,
		Angle = function(): number
			return angle
		end,
		SetAngle = setAngle,
	}
end

local function buildSpin(root: Frame): (Panel, () -> ())
	local panel = UIKit.panel(root, "Lucky Spin", Colors.Purple, Vector2.new(940, 590))
	local content = panel.Content
	local center = Vector2.new(250, 248)
	local wheel = buildWheel(content, center)
	local wedgeLabels = wheel.Labels

	-- bouton SPIN rond au milieu de la roue (il ne tourne pas)
	local spinButton: TextButton = new("TextButton", {
		Name = "SpinButton",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(center.X, center.Y),
		Size = UDim2.fromOffset(118, 118),
		BackgroundColor3 = Colors.Green,
		AutoButtonColor = false,
		Text = "",
		ZIndex = Z + 9,
		Parent = content,
	}, {
		new("UICorner", { CornerRadius = UDim.new(0.5, 0) }),
		new("UIStroke", { Color = Colors.Ink, Thickness = 5, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
	})
	local hubGradient: UIGradient = new("UIGradient", { Rotation = 90, Parent = spinButton })
	local spinLabel = text({
		Name = "Label",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.48),
		Size = UDim2.fromScale(0.78, 0.4),
		Text = "SPIN",
		ZIndex = Z + 10,
		Parent = spinButton,
	})
	UIKit.packHover(spinButton)
	spinButton.Activated:Connect(function()
		UIKit.Sound("Click")
		task.spawn(RewardsController.Spin)
	end)
	local function paintHub(on: boolean)
		local color = if on then Colors.Green else Colors.Disabled
		spinButton.BackgroundColor3 = color
		hubGradient.Color = UIKit.ButtonSequence(color)
		spinLabel.TextTransparency = if on then 0 else 0.3
	end

	-- Colonne de droite : tours, tour gratuit, chances, tours à acheter
	local sideX = 2 * center.X + 24
	local side: Frame = new("Frame", {
		Name = "Side",
		Position = UDim2.fromOffset(sideX, 0),
		Size = UDim2.new(1, -sideX, 1, 0),
		BackgroundTransparency = 1,
		ZIndex = Z,
		Parent = content,
	}, {
		new("UIListLayout", {
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Padding = UDim.new(0, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	local sideW = 940 - 32 - sideX
	local count = text({ Name = "Count", LayoutOrder = 1, Size = UDim2.fromOffset(sideW, 44), Text = "", Parent = side })
	local free = text({ Name = "Free", LayoutOrder = 2, Size = UDim2.fromOffset(sideW, 26), Text = "", TextColor3 = Colors.GreenText, Parent = side })
	UIKit.sectionTitle({ Name = "ChancesTitle", Text = "CHANCES", Color = Colors.Yellow, Width = sideW, Size = UDim2.fromOffset(sideW, 36), LayoutOrder = 3, ZIndex = Z, Parent = side })
	local legend: Frame = new("Frame", {
		Name = "Chances",
		LayoutOrder = 4,
		Size = UDim2.fromOffset(sideW, 4 * 36 + 3 * 6),
		BackgroundTransparency = 1,
		ZIndex = Z,
		Parent = side,
	}, {
		new("UIGridLayout", {
			CellSize = UDim2.fromOffset((sideW - 8) / 2, 36),
			CellPadding = UDim2.fromOffset(8, 6),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	local legendValues: { TextLabel } = {}
	for index, prize in PRIZES do
		local row = UIKit.card({ Name = "Chance" .. index, Color = Colors.SlateDark, LayoutOrder = index, ZIndex = Z, Parent = legend })
		new("Frame", {
			Name = "Dot",
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 6, 0.5, 0),
			Size = UDim2.fromOffset(8, 24),
			BackgroundColor3 = wedgeColor(index),
			BorderSizePixel = 0,
			ZIndex = Z + 2,
			Parent = row,
		})
		UIKit.icon(KIND_ICON[prize.Reward.Kind] or "gift", {
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 18, 0.5, 0),
			Size = UDim2.fromOffset(28, 28),
			ZIndex = Z + 2,
			Parent = row,
		})
		table.insert(legendValues, text({
			Name = "Prize",
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 50, 0.5, 0),
			Size = UDim2.new(1, -104, 0, 22),
			TextXAlignment = Enum.TextXAlignment.Left,
			Text = DailyConfig.Label(prize.Reward, nil),
			Parent = row,
		}))
		text({
			Name = "Chance",
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -8, 0.5, 0),
			Size = UDim2.fromOffset(50, 22),
			TextXAlignment = Enum.TextXAlignment.Right,
			Text = Format.Percent(DailyConfig.Chance(index)),
			TextColor3 = Colors.Yellow,
			Parent = row,
		})
	end
	local offersTitle = UIKit.sectionTitle({ Name = "OffersTitle", Text = "MORE SPINS", Color = Colors.GreenText, Width = sideW, Size = UDim2.fromOffset(sideW, 36), LayoutOrder = 5, ZIndex = Z, Parent = side })
	local ways = text({
		Name = "Ways",
		LayoutOrder = 6,
		Size = UDim2.fromOffset(sideW, 44),
		Body = true,
		MaxTextSize = 18,
		TextWrapped = true,
		Text = "1 free spin every day. More spins in Free Gifts and Daily Rewards.",
		TextColor3 = Colors.Muted,
		Parent = side,
	})
	local offers: Frame = new("Frame", {
		Name = "Offers",
		LayoutOrder = 7,
		Size = UDim2.fromOffset(sideW, 2 * 56 + 8),
		BackgroundTransparency = 1,
		ZIndex = Z,
		Parent = side,
	}, {
		new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	local loadedOffers = false

	local function loadOffers()
		if loadedOffers then
			return
		end
		loadedOffers = true
		local list = Remotes.Function("GetSpinOffers"):InvokeServer()
		if type(list) ~= "table" then
			loadedOffers = false
			return
		end
		for _, child in offers:GetChildren() do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
		for order, offer in list do
			if type(offer) ~= "table" or type(offer.Key) ~= "string" then
				continue
			end
			local row = UIKit.card({ Name = offer.Key, Color = Colors.Pink, LayoutOrder = order, Size = UDim2.fromOffset(sideW, 56), ZIndex = Z, Parent = offers })
			UIKit.icon("wheel", {
				AnchorPoint = Vector2.new(0, 0.5),
				Position = UDim2.new(0, 8, 0.5, 0),
				Size = UDim2.fromOffset(42, 42),
				ZIndex = Z + 2,
				Parent = row,
			})
			text({
				Name = "Name",
				AnchorPoint = Vector2.new(0, 0.5),
				Position = UDim2.new(0, 58, 0.5, 0),
				Size = UDim2.new(1, -220, 0, 28),
				TextXAlignment = Enum.TextXAlignment.Left,
				Text = string.upper(tostring(offer.Name)),
				Parent = row,
			})
			UIKit.button({
				Name = "Buy",
				Text = if type(offer.Price) == "number" then "R$ " .. Format.Number(offer.Price) else "R$ ...",
				Color = Colors.Green,
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -6, 0.5, 0),
				Size = UDim2.fromOffset(150, 46),
				MaxTextSize = 26,
				ZIndex = Z + 2,
				Parent = row,
			}, function()
				task.spawn(function()
					local ok, message = Remotes.Function("BuySpins"):InvokeServer(offer.Key)
					if not ok then
						NotifyController.Show(if type(message) == "string" then message else "Try again", "error")
					end
				end)
			end)
		end
	end
	panel.OnOpen = function()
		local spins = tableOr("Spins")
		if spins and spins.CanBuy == true then
			task.spawn(loadOffers)
		end
	end

	-- Fait tourner la roue jusqu'à la part `target` (plusieurs tours, ralentit à la fin), puis appelle `finished`
	local function animate(target: number, finished: () -> ())
		local step = 360 / #PRIZES
		local current = wheel.Angle() % 360
		wheel.SetAngle(current)
		-- (la part `target` doit finir sous la flèche du haut, un peu décalée de son milieu pour faire vrai)
		local jitter = (math.random() - 0.5) * step * 0.6
		local goal = (-((target - 0.5) * step) + jitter) % 360
		local final = current + (goal - current) % 360 + 360 * SPIN_TURNS
		local value: NumberValue = new("NumberValue", { Value = current })
		local link = value:GetPropertyChangedSignal("Value"):Connect(function()
			wheel.SetAngle(value.Value)
		end)
		UIKit.tween(value, SPIN_TIME, { Value = final }, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
		task.delay(SPIN_TIME, function()
			link:Disconnect()
			value:Destroy()
			wheel.SetAngle(final)
			local pop = pulse(spinButton)
			UIKit.tween(pop, 0.12, { Scale = 1.15 })
			task.delay(0.14, function()
				UIKit.tween(pop, 0.25, { Scale = 1 }, Enum.EasingStyle.Back)
			end)
			finished()
		end)
	end
	animateSpin = animate

	local function refresh()
		local spins = tableOr("Spins")
		local currentScale = scale()
		for index, label in wedgeLabels do
			label.Text = wedgeText(PRIZES[index].Reward, currentScale)
		end
		for index, label in legendValues do
			label.Text = DailyConfig.Label(PRIZES[index].Reward, currentScale)
		end
		if not spins then
			return
		end
		local freeCount = tonumber(spins.Free) or 0
		local stored = tonumber(spins.Stored) or 0
		local total = freeCount + stored
		count.Text = string.format("%d SPIN%s", total, if total == 1 then "" else "S")
		if freeCount > 0 then
			free.Text = "Free spin ready!"
			free.TextColor3 = Colors.GreenText
		else
			free.Text = "Free spin in " .. Format.Clock(math.max(0, (tonumber(spins.NextFree) or 0) - serverNow()))
			free.TextColor3 = Colors.Muted
		end
		local ready = not spinning and total > 0
		spinButton:SetAttribute("Disabled", not ready)
		paintHub(ready)
		spinLabel.Text = if spinning then "..." else "SPIN"
		local canBuy = spins.CanBuy == true
		offers.Visible = canBuy
		offersTitle.Visible = canBuy
		ways.Visible = canBuy
	end
	paintHub(false)
	return panel, refresh
end

-- Fait tourner la roue (le serveur tire la case) ; le gain s'affiche quand la roue s'arrête
function RewardsController.Spin(): (boolean, string)
	if spinning then
		return false, "The wheel is still spinning!"
	end
	spinning = true
	local ok, message, index = Remotes.Function("Spin"):InvokeServer()
	local textOut = if type(message) == "string" then message else "Try again"
	local animate = animateSpin
	if not ok or type(index) ~= "number" or not PRIZES[index] then
		spinning = false
		NotifyController.Show(textOut, "error")
		return false, textOut
	end
	local function finished()
		spinning = false
		NotifyController.Show("You won " .. textOut .. "!", "success")
	end
	if animate then
		animate(index, finished)
	else
		finished()
	end
	return true, textOut
end

-- ===================================================================== cadeaux

local function buildGifts(root: Frame): (Panel, () -> ())
	local panel = UIKit.panel(root, "Free Gifts", Colors.Pink, Vector2.new(800, 590))
	local content = panel.Content
	local resets = text({
		Name = "Resets",
		Size = UDim2.fromScale(1, 0.8),
		TextXAlignment = Enum.TextXAlignment.Right,
		Text = "",
		Parent = panel.HeaderRight,
	})
	local playtime = text({
		Name = "Playtime",
		Size = UDim2.fromOffset(520, 34),
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "",
		Parent = content,
	})
	local width = 768
	local columns = 3
	local gap = 12
	local top = 44
	local tileW = math.floor((width - (columns - 1) * gap) / columns)
	local tileH = math.floor((488 - top - 2 * gap) / 3)
	type Cell = { Tile: Frame, Box: Frame, Prize: Frame, Status: TextLabel, Claim: TextButton, Shade: Frame, Glow: Frame, Pulse: UIScale, Value: TextLabel }
	local cells: { Cell } = {}
	for index, gift in GIFTS do
		local column = (index - 1) % columns
		local row = (index - 1) // columns
		local color, rainbow = rewardColor(gift.Reward)
		local tile = UIKit.card({
			Name = "Gift" .. index,
			Color = color,
			Rainbow = rainbow,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset(column * (tileW + gap) + tileW / 2, top + row * (tileH + gap) + tileH / 2),
			Size = UDim2.fromOffset(tileW, tileH),
			ZIndex = Z,
			Parent = content,
		})
		-- grande boîte cadeau tant que le cadeau est fermé, l'image du gain une fois ouvert
		local box = UIKit.icon("gift", {
			Name = "Box",
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 8, 0.5, 0),
			Size = UDim2.fromOffset(tileH - 26, tileH - 26),
			ZIndex = Z + 2,
			Parent = tile,
		})
		local prizeIcon = UIKit.icon(KIND_ICON[gift.Reward.Kind] or "gift", {
			Name = "Prize",
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 14, 0.5, 0),
			Size = UDim2.fromOffset(tileH - 40, tileH - 40),
			Visible = false,
			ZIndex = Z + 2,
			Parent = tile,
		})
		local left = tileH - 6
		text({
			Name = "Kind",
			Position = UDim2.fromOffset(left, 10),
			Size = UDim2.new(1, -(left + 8), 0, 20),
			TextXAlignment = Enum.TextXAlignment.Left,
			Text = "GIFT " .. index,
			TextColor3 = Colors.Yellow,
			Parent = tile,
		})
		local value = text({
			Name = "Value",
			Position = UDim2.fromOffset(left, 32),
			Size = UDim2.new(1, -(left + 8), 0, 28),
			TextXAlignment = Enum.TextXAlignment.Left,
			Text = DailyConfig.Label(gift.Reward, scale()),
			Parent = tile,
		})
		local status = text({
			Name = "Status",
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.new(0, left, 1, -12),
			Size = UDim2.new(1, -(left + 8), 0, 30),
			TextXAlignment = Enum.TextXAlignment.Left,
			Text = "",
			ZIndex = Z + 6,
			Parent = tile,
		})
		local claim = UIKit.button({
			Name = "Claim",
			Text = "OPEN",
			Color = Colors.Green,
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.new(0, left, 1, -10),
			Size = UDim2.new(1, -(left + 10), 0, 48),
			MaxTextSize = 28,
			Visible = false,
			ZIndex = Z + 6,
			Parent = tile,
		}, function()
			task.spawn(RewardsController.ClaimGift, index)
		end)
		table.insert(cells, {
			Tile = tile,
			Box = box,
			Prize = prizeIcon,
			Value = value,
			Status = status,
			Claim = claim,
			Shade = shade(tile),
			Glow = glow(tile, Colors.GreenText),
			Pulse = pulse(box),
		})
	end

	local function refresh()
		local gifts = tableOr("Gifts")
		local currentScale = scale()
		for index, cell in cells do
			cell.Value.Text = DailyConfig.Label(GIFTS[index].Reward, currentScale)
		end
		if not gifts then
			return
		end
		local seconds = giftSeconds(gifts)
		playtime.Text = "Playtime today: " .. Format.Duration(seconds)
		resets.Text = "New gifts in " .. Format.Clock(math.max(0, (tonumber(gifts.NextReset) or 0) - serverNow()))
		for index, cell in cells do
			local opened = giftClaimed(gifts, index)
			local left = GIFTS[index].Minutes * 60 - seconds
			local ready = not opened and left <= 0
			cell.Shade.Visible = opened
			cell.Glow.Visible = ready
			cell.Claim.Visible = ready
			cell.Box.Visible = not opened
			cell.Prize.Visible = opened
			setPulse(cell.Pulse, ready)
			cell.Status.Visible = not ready
			cell.Status.Text = if opened then "OPENED" else Format.Clock(math.max(0, math.ceil(left)))
			cell.Status.TextColor3 = if opened then Colors.GreenText else Colors.Text
		end
	end
	return panel, refresh
end

-- ===================================================================== boutons et cycle de vie

local function badgeOn(button: GuiObject): { Frame: Frame, Label: TextLabel }
	local frame: Frame = new("Frame", {
		Name = "Badge",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(1, -6, 0, 6),
		Size = UDim2.fromOffset(32, 32),
		BackgroundColor3 = Colors.Tomato,
		BorderSizePixel = 0,
		Visible = false,
		ZIndex = 8,
		Parent = button,
	}, {
		new("UICorner", { CornerRadius = UDim.new(1, 0) }),
		new("UIStroke", { Color = Colors.Ink, Thickness = 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
	})
	local label = UIKit.label({
		Name = "Count",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.8, 0.7),
		Text = "",
		StrokeThickness = 0,
		ZIndex = 9,
		Parent = frame,
	})
	return { Frame = frame, Label = label }
end

function RewardsController.Open(name: string)
	local current = ui
	local panel = current and current.Panels[name]
	if panel then
		panel.Open()
	end
end

-- Ferme un menu des récompenses (tous sans nom)
function RewardsController.Close(name: string?)
	local current = ui
	if not current then
		return
	end
	for key, panel in current.Panels do
		if (name == nil or key == name) and panel.IsOpen() then
			panel.Close()
		end
	end
end

function RewardsController.SetButtonsVisible(visible: boolean)
	local current = ui
	if current then
		current.Buttons.Visible = visible
	end
end

local function refreshAll()
	local current = ui
	if not current then
		return
	end
	for name, badge in current.Badges do
		local count = RewardsController.Badge(name)
		badge.Frame.Visible = count > 0
		badge.Label.Text = if name == "Daily" then "!" elseif count > 99 then "99+" else tostring(count)
	end
	for name, panel in current.Panels do
		if panel.IsOpen() then
			current.Refreshers[name]()
		end
	end
end

function RewardsController.Init()
	local _, root = UIKit.Root("Rewards", 5)
	local buttons: Frame = new("Frame", {
		Name = "RewardButtons",
		AnchorPoint = Vector2.new(0, 0),
		-- (boutons larges en colonne, du milieu - 33 vers le bas : Shop et Index du HUD, brief 12, sont juste au-dessus,
		-- les 5 centrés ensemble)
		Position = UDim2.new(0, 16, 0.5, -33),
		Size = UDim2.fromOffset(196, 3 * 64 + 2 * 10),
		BackgroundTransparency = 1,
		Parent = root,
	}, {
		new("UIListLayout", { Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	local dailyPanel, dailyRefresh = buildDaily(root)
	local spinPanel, spinRefresh = buildSpin(root)
	local giftsPanel, giftsRefresh = buildGifts(root)
	local current: Ui = {
		Root = root,
		Buttons = buttons,
		Badges = {},
		Panels = { Daily = dailyPanel, Spin = spinPanel, Gifts = giftsPanel },
		Refreshers = { Daily = dailyRefresh, Spin = spinRefresh, Gifts = giftsRefresh },
	}
	ui = current
	local entries: { { Name: string, Color: Color3, Icon: string } } = {
		{ Name = "Daily", Color = Colors.Yellow, Icon = "calendar" },
		{ Name = "Spin", Color = Colors.Purple, Icon = "wheel" },
		{ Name = "Gifts", Color = Colors.Pink, Icon = "gift" },
	}
	for order, entry in entries do
		local name = entry.Name
		local button = UIKit.menuButton({
			Name = name,
			Text = name,
			Icon = entry.Icon,
			Color = entry.Color,
			LayoutOrder = order,
			Size = UDim2.fromOffset(196, 64),
			Parent = buttons,
		}, function()
			current.Panels[name].Toggle()
		end)
		current.Badges[name] = badgeOn(button)
	end
	UIKit.PanelsChanged:Connect(function()
		refreshAll()
	end)

	Remotes.Event("RewardGranted").OnClientEvent:Connect(function(source: any, granted: any, rarity: any)
		if type(granted) ~= "string" or source == "Spin" then
			return -- (la roue montre son gain quand elle s'arrête)
		end
		local message = if type(rarity) == "string" then granted .. " added to your revival tanks!" else granted .. "!"
		NotifyController.Show(string.sub(message, 1, 120), "success")
	end)
end

-- Ouvre le calendrier tout seul quand une récompense attend : à l'arrivée, ou pour un nouveau joueur juste après son
-- premier dino (avant, le guide des premières minutes a la place)
local function autoOpenDaily()
	if not DailyConfig.Login.AutoOpen or not ReplicaController.WaitReady(60) then
		return
	end
	local tutorial = tonumber(ReplicaController.Get("Tutorial"))
	if tutorial and tutorial < 3 then
		local deadline = os.clock() + NEW_PLAYER_WAIT
		while (tonumber(ReplicaController.Get("Tutorial")) or 0) < 3 do
			if os.clock() > deadline then
				return
			end
			task.wait(0.5)
		end
		task.wait(FIRST_DINO_DELAY)
	else
		task.wait(AUTO_OPEN_DELAY)
	end
	-- (un menu déjà ouvert : on attend qu'il se ferme, un peu)
	local deadline = os.clock() + 30
	while UIKit.AnyPanelOpen() and os.clock() < deadline do
		task.wait(0.5)
	end
	local daily = tableOr("Daily")
	if daily and daily.CanClaim == true and not UIKit.AnyPanelOpen() then
		RewardsController.Open("Daily")
	end
end

function RewardsController.Start()
	task.spawn(autoOpenDaily)
	while true do
		refreshAll()
		task.wait(REFRESH)
	end
end

return RewardsController
