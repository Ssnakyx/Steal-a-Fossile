--!strict
-- Côté client des récompenses (Config.Daily) : trois boutons à gauche de l'écran (Daily, Spin, Gifts), avec une
-- pastille rouge quand quelque chose attend, et leurs menus :
--   * Daily Rewards : calendrier de 14 jours, bouton Claim, série en cours. S'ouvre tout seul à l'arrivée quand la
--     récompense du jour attend (Config.Daily.Login.AutoOpen).
--   * Lucky Spin : roue de 8 cases avec leurs chances (toute chance payante affiche ses probas), tour gratuit du jour,
--     tours en réserve, tours à acheter en Robux (seulement si le serveur les permet à ce joueur).
--   * Free Gifts : cadeaux de temps de jeu avec leur compte à rebours.
-- Le client ne décide rien : il lit les clés replica « Daily », « Spins », « Gifts », « RewardScale » et demande au
-- serveur (ClaimDaily, Spin, ClaimGift, GetSpinOffers, BuySpins).
-- API (HUD du brief 12) : RewardsController.Open("Daily" | "Spin" | "Gifts"), RewardsController.SetButtonsVisible(bool),
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
local Z = 23 -- (contenu des panneaux : au-dessus du corps, ZIndex 22)

local KIND_COLOR: { [string]: Color3 } = {
	Money = Colors.Money,
	Speed = Colors.Cyan,
	Spins = Colors.Purple,
	BearTraps = Colors.Orange,
}
local KIND_NAME: { [string]: string } = {
	Money = "CASH",
	Speed = "SPEED",
	Spins = "SPINS",
	BearTraps = "TRAPS",
	Block = "FOSSIL",
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

-- Case de récompense : carte de la couleur de la récompense, valeur au milieu, genre en dessous
local function rewardTile(parent: GuiObject, name: string, reward: Reward, size: UDim2, position: UDim2): (Frame, TextLabel, TextLabel)
	local color, rainbow = rewardColor(reward)
	local tile = UIKit.card({ Name = name, Color = color, Rainbow = rainbow, Size = size, Position = position, ZIndex = Z, Parent = parent })
	local value = text({
		Name = "Value",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.45),
		Size = UDim2.fromScale(0.9, 0.26),
		Text = DailyConfig.Label(reward, scale()),
		Parent = tile,
	})
	local kind = text({
		Name = "Kind",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.66),
		Size = UDim2.fromScale(0.8, 0.13),
		Text = KIND_NAME[reward.Kind] or "",
		TextColor3 = Colors.Muted,
		Parent = tile,
	})
	return tile, value, kind
end

-- Voile sombre sur une case (déjà prise)
local function shade(tile: Frame): Frame
	return new("Frame", {
		Name = "Shade",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.5,
		BorderSizePixel = 0,
		Visible = false,
		ZIndex = Z + 4,
		Parent = tile,
	})
end

-- Contour lumineux autour d'une case (jour à prendre, case de la roue)
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

-- ===================================================================== calendrier

local function buildDaily(root: Frame): (Panel, () -> ())
	local panel = UIKit.panel(root, "Daily Rewards", Colors.Yellow, Vector2.new(900, 540))
	local content = panel.Content
	local columns = 7
	local gap = 10
	local width = 868
	local tileW = math.floor((width - (columns - 1) * gap) / columns)
	local tileH = 150
	type Cell = { Tile: Frame, Value: TextLabel, Status: TextLabel, Shade: Frame, Glow: Frame }
	local cells: { Cell } = {}
	for index, reward in DAYS do
		local column = (index - 1) % columns
		local row = (index - 1) // columns
		local tile, value = rewardTile(
			content,
			"Day" .. index,
			reward,
			UDim2.fromOffset(tileW, tileH),
			UDim2.fromOffset(column * (tileW + gap), row * (tileH + gap))
		)
		text({
			Name = "Day",
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, 8),
			Size = UDim2.fromScale(0.86, 0.16),
			Text = "DAY " .. index,
			TextColor3 = Colors.Yellow,
			Parent = tile,
		})
		local status = text({
			Name = "Status",
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -8),
			Size = UDim2.fromScale(0.9, 0.15),
			Text = "",
			ZIndex = Z + 6,
			Parent = tile,
		})
		table.insert(cells, { Tile = tile, Value = value, Status = status, Shade = shade(tile), Glow = glow(tile, Colors.Yellow) })
	end
	local bottom = 2 * tileH + gap + 18
	local streak = text({
		Name = "Streak",
		Position = UDim2.fromOffset(0, bottom),
		Size = UDim2.fromOffset(420, 40),
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "",
		Parent = content,
	})
	text({
		Name = "Hint",
		Position = UDim2.fromOffset(0, bottom + 46),
		Size = UDim2.fromOffset(460, 40),
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
		Size = UDim2.fromOffset(300, 76),
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
			cell.Shade.Visible = done
			cell.Glow.Visible = canClaim and index == nextDay
			cell.Status.Text = if done then "CLAIMED" elseif canClaim and index == nextDay then "TODAY" elseif index == tomorrow then "TOMORROW" else ""
			cell.Status.TextColor3 = if done then Colors.GreenText else Colors.Text
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

local function buildSpin(root: Frame): (Panel, () -> ())
	local panel = UIKit.panel(root, "Lucky Spin", Colors.Purple, Vector2.new(840, 560))
	local content = panel.Content
	local center = Vector2.new(250, 229)
	local radius = Vector2.new(178, 162)
	local tileSize = Vector2.new(132, 80)
	type Cell = { Tile: Frame, Value: TextLabel, Glow: Frame }
	local cells: { Cell } = {}
	for index, prize in PRIZES do
		local angle = math.rad(-90 + (index - 1) * 360 / #PRIZES)
		local x = center.X + math.cos(angle) * radius.X - tileSize.X / 2
		local y = center.Y + math.sin(angle) * radius.Y - tileSize.Y / 2
		local tile, value, kind = rewardTile(content, "Prize" .. index, prize.Reward, UDim2.fromOffset(tileSize.X, tileSize.Y), UDim2.fromOffset(x, y))
		value.Position = UDim2.fromScale(0.5, 0.42)
		kind.Text = string.upper(prize.Name)
		kind.Position = UDim2.fromScale(0.5, 0.15)
		kind.Size = UDim2.fromScale(0.88, 0.2)
		text({
			Name = "Chance",
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -6),
			Size = UDim2.fromScale(0.6, 0.22),
			Text = Format.Percent(DailyConfig.Chance(index)),
			TextColor3 = Colors.Yellow,
			Parent = tile,
		})
		table.insert(cells, { Tile = tile, Value = value, Glow = glow(tile, Colors.Yellow) })
	end
	local count = text({
		Name = "Count",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(center.X, center.Y - 66),
		Size = UDim2.fromOffset(200, 34),
		Text = "",
		Parent = content,
	})
	local spinButton = UIKit.button({
		Name = "SpinButton",
		Text = "SPIN",
		Color = Colors.Green,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(center.X, center.Y),
		Size = UDim2.fromOffset(170, 74),
		MaxTextSize = 40,
		ZIndex = Z,
		Parent = content,
	}, function()
		task.spawn(RewardsController.Spin)
	end)
	local free = text({
		Name = "Free",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(center.X, center.Y + 62),
		Size = UDim2.fromOffset(220, 26),
		Text = "",
		TextColor3 = Colors.GreenText,
		Parent = content,
	})

	-- Colonne de droite : comment gagner des tours, tours à acheter
	local side = new("Frame", {
		Name = "Side",
		Position = UDim2.fromOffset(530, 6),
		Size = UDim2.new(1, -530, 1, -6),
		BackgroundTransparency = 1,
		ZIndex = Z,
		Parent = content,
	}, {
		new("UIListLayout", {
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Padding = UDim.new(0, 10),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	text({ Name = "Title", LayoutOrder = 1, Size = UDim2.new(1, 0, 0, 34), Text = "GET MORE SPINS", TextColor3 = Colors.Yellow, Parent = side })
	text({
		Name = "Ways",
		LayoutOrder = 2,
		Size = UDim2.new(1, 0, 0, 96),
		Body = true,
		MaxTextSize = 20,
		TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Top,
		Text = "1 free spin every day.\nMore spins in Free Gifts and Daily Rewards.",
		TextColor3 = Colors.Muted,
		Parent = side,
	})
	local offers = new("Frame", {
		Name = "Offers",
		LayoutOrder = 3,
		Size = UDim2.new(1, 0, 0, 200),
		BackgroundTransparency = 1,
		ZIndex = Z,
		Parent = side,
	}, {
		new("UIListLayout", {
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Padding = UDim.new(0, 10),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
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
			if child:IsA("GuiButton") then
				child:Destroy()
			end
		end
		for order, offer in list do
			if type(offer) ~= "table" or type(offer.Key) ~= "string" then
				continue
			end
			local price = if type(offer.Price) == "number" then "R$" .. Format.Number(offer.Price) else "R$ ..."
			UIKit.button({
				Name = offer.Key,
				Text = string.format("%s  %s", tostring(offer.Name), price),
				Color = Colors.Robux,
				LayoutOrder = order,
				Size = UDim2.new(1, -10, 0, 62),
				MaxTextSize = 26,
				ZIndex = Z,
				Parent = offers,
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

	local selected = 0
	local function selectCell(index: number)
		selected = index
		for other, cell in cells do
			cell.Glow.Visible = other == index
		end
	end

	-- Fait tourner la sélection jusqu'à la case `target` (plusieurs tours, de plus en plus lentement)
	local function animate(target: number, finished: () -> ())
		local start = if selected > 0 then selected else 1
		local steps = #PRIZES * 3 + ((target - start) % #PRIZES)
		task.spawn(function()
			for step = 1, steps do
				selectCell(((start + step - 1) % #PRIZES) + 1)
				local t = step / steps
				task.wait(0.035 + 0.22 * t ^ 2.5)
			end
			selectCell(target)
			UIKit.tween(cells[target].Tile, 0.12, { Rotation = 4 })
			task.wait(0.12)
			UIKit.tween(cells[target].Tile, 0.2, { Rotation = 0 }, Enum.EasingStyle.Back)
			finished()
		end)
	end
	animateSpin = animate

	local function refresh()
		local spins = tableOr("Spins")
		local currentScale = scale()
		for index, cell in cells do
			cell.Value.Text = DailyConfig.Label(PRIZES[index].Reward, currentScale)
		end
		if not spins then
			return
		end
		local freeCount = tonumber(spins.Free) or 0
		local stored = tonumber(spins.Stored) or 0
		local total = freeCount + stored
		count.Text = string.format("%d spin%s", total, if total == 1 then "" else "s")
		if freeCount > 0 then
			free.Text = "Free spin ready!"
			free.TextColor3 = Colors.GreenText
		else
			free.Text = "Free spin in " .. Format.Clock(math.max(0, (tonumber(spins.NextFree) or 0) - serverNow()))
			free.TextColor3 = Colors.Muted
		end
		spinButton:SetAttribute("Disabled", spinning or total <= 0)
		spinButton.Text = if spinning then "..." else "SPIN"
		offers.Visible = spins.CanBuy == true
	end
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
	local panel = UIKit.panel(root, "Free Gifts", Colors.Pink, Vector2.new(720, 560))
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
		Size = UDim2.fromOffset(500, 34),
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "",
		Parent = content,
	})
	local columns = 3
	local gap = 12
	local top = 44
	local tileW = math.floor((688 - (columns - 1) * gap) / columns)
	local tileH = math.floor((448 - top - 2 * gap) / 3)
	type Cell = { Tile: Frame, Value: TextLabel, Status: TextLabel, Claim: TextButton, Shade: Frame, Glow: Frame }
	local cells: { Cell } = {}
	for index, gift in GIFTS do
		local column = (index - 1) % columns
		local row = (index - 1) // columns
		local tile, value, kind = rewardTile(
			content,
			"Gift" .. index,
			gift.Reward,
			UDim2.fromOffset(tileW, tileH),
			UDim2.fromOffset(column * (tileW + gap), top + row * (tileH + gap))
		)
		value.Position = UDim2.fromScale(0.5, 0.36)
		kind.Position = UDim2.fromScale(0.5, 0.12)
		kind.Text = string.format("GIFT %d - %s", index, KIND_NAME[gift.Reward.Kind] or "")
		local status = text({
			Name = "Status",
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -10),
			Size = UDim2.fromScale(0.8, 0.26),
			Text = "",
			ZIndex = Z + 6,
			Parent = tile,
		})
		local claim = UIKit.button({
			Name = "Claim",
			Text = "OPEN",
			Color = Colors.Green,
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -8),
			Size = UDim2.fromScale(0.7, 0.34),
			MaxTextSize = 28,
			Visible = false,
			ZIndex = Z + 6,
			Parent = tile,
		}, function()
			task.spawn(RewardsController.ClaimGift, index)
		end)
		table.insert(cells, { Tile = tile, Value = value, Status = status, Claim = claim, Shade = shade(tile), Glow = glow(tile, Colors.GreenText) })
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
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 16, 0.5, 0),
		Size = UDim2.fromOffset(136, 3 * 68 + 2 * 14),
		BackgroundTransparency = 1,
		Parent = root,
	}, {
		new("UIListLayout", { Padding = UDim.new(0, 14), SortOrder = Enum.SortOrder.LayoutOrder }),
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
	local entries: { { Name: string, Color: Color3 } } = {
		{ Name = "Daily", Color = Colors.Yellow },
		{ Name = "Spin", Color = Colors.Purple },
		{ Name = "Gifts", Color = Colors.Pink },
	}
	for order, entry in entries do
		local name = entry.Name
		local button = UIKit.button({
			Name = name,
			Text = name,
			Color = entry.Color,
			LayoutOrder = order,
			Size = UDim2.fromOffset(136, 68),
			MaxTextSize = 30,
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

function RewardsController.Start()
	task.spawn(function()
		if not ReplicaController.WaitReady(60) then
			return
		end
		task.wait(AUTO_OPEN_DELAY)
		local daily = tableOr("Daily")
		if DailyConfig.Login.AutoOpen and daily and daily.CanClaim == true and not UIKit.AnyPanelOpen() then
			RewardsController.Open("Daily")
		end
	end)
	while true do
		refreshAll()
		task.wait(REFRESH)
	end
end

return RewardsController
