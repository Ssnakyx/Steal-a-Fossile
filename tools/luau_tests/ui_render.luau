-- Aperçu de l'interface (outil de développement, repris de Pet Lab Fusion et adapté) : transforme les ScreenGui du faux
-- Roblox (env.luau) en page HTML, que tools/luau_tests/ui_preview.py photographie avec Chromium. Gère les positions
-- (échelle, décalage, ancre), UIListLayout, UIGridLayout, UIPadding, AutomaticSize, UISizeConstraint, UICorner, UIStroke,
-- UIGradient, UIScale, rotation, ZIndex, rognage, texte ajusté et les plots du UIKit (dessinés en CSS).
-- Approximations : polices et largeurs de texte, contours des textes, rotation des dégradés. Ce n'est pas le rendu de
-- Roblox, mais les tailles, les positions, les chevauchements et les débordements sont ceux du code.

local env = require("./env")

local Render = {}

-- Dessins à la place des repères : Icons[id d'image] et Viewports[nom du modèle] = morceau de HTML (SVG, <img>)
Render.Art = { Icons = {} :: { [string]: string }, Viewports = {} :: { [string]: string } }

local studTexture: string? = nil
local function studImage(): string
	if studTexture == nil then
		studTexture = env.module("src/client/UI/UIKit").StudTexture
	end
	return studTexture :: string
end

local function esc(text: string): string
	text = string.gsub(text, "&", "&amp;")
	text = string.gsub(text, "<", "&lt;")
	text = string.gsub(text, ">", "&gt;")
	return text
end

local function num(n: number): string
	return string.format("%.2f", n)
end

local function rgba(color: any, transparency: number?): string
	return string.format("rgba(%d,%d,%d,%.3f)", math.floor(color.R * 255 + 0.5), math.floor(color.G * 255 + 0.5), math.floor(color.B * 255 + 0.5), 1 - (transparency or 0))
end

local function firstOf(node: any, className: string): any
	return node:FindFirstChildOfClass(className)
end

local function allOf(node: any, className: string): { any }
	local list = {}
	for _, child in node:GetChildren() do
		if child.ClassName == className then
			table.insert(list, child)
		end
	end
	return list
end

local function enumName(value: any, default: string): string
	return if value ~= nil then value.Name else default
end

-- ===== dégradés =====
local function sampleSequence(keypoints: { any }, t: number, isColor: boolean): any
	local first, last = keypoints[1], keypoints[#keypoints]
	if t <= first.Time then
		return first.Value
	end
	if t >= last.Time then
		return last.Value
	end
	for i = 1, #keypoints - 1 do
		local a, b = keypoints[i], keypoints[i + 1]
		if t >= a.Time and t <= b.Time then
			local k = if b.Time == a.Time then 0 else (t - a.Time) / (b.Time - a.Time)
			if isColor then
				return a.Value:Lerp(b.Value, k)
			end
			return a.Value + (b.Value - a.Value) * k
		end
	end
	return last.Value
end

local function activeGradient(node: any): any
	local gradient = nil
	for _, g in allOf(node, "UIGradient") do
		if g.Enabled ~= false then
			gradient = g
		end
	end
	return gradient
end

-- dégradé CSS : couleur `base` multipliée par le UIGradient (couleur et transparence)
local function gradientCss(gradient: any, base: any, transparency: number): string
	local colorKeys = gradient.Color.Keypoints
	local alphaKeys = gradient.Transparency.Keypoints
	local times: { number } = {}
	local seen: { [number]: boolean } = {}
	for _, k in colorKeys do
		if not seen[k.Time] then
			seen[k.Time] = true
			table.insert(times, k.Time)
		end
	end
	for _, k in alphaKeys do
		if not seen[k.Time] then
			seen[k.Time] = true
			table.insert(times, k.Time)
		end
	end
	table.sort(times)
	local stops = {}
	for _, t in times do
		local c = sampleSequence(colorKeys, t, true)
		local a = sampleSequence(alphaKeys, t, false)
		local mixed = env.Color3.new(base.R * c.R, base.G * c.G, base.B * c.B)
		local alpha = (1 - transparency) * (1 - a)
		table.insert(stops, string.format("%s %.1f%%", rgba(mixed, 1 - alpha), t * 100))
	end
	return string.format("linear-gradient(%ddeg,%s)", math.floor(90 + (gradient.Rotation or 0)), table.concat(stops, ","))
end

-- background CSS d'un cadre : couleur de fond x dégradé
local function backgroundCss(node: any, transparency: number): string?
	local gradient = activeGradient(node)
	if not gradient then
		if transparency >= 1 then
			return nil
		end
		return rgba(node.BackgroundColor3, transparency)
	end
	if transparency >= 1 then
		return nil
	end
	return gradientCss(gradient, node.BackgroundColor3, transparency)
end

-- plots du UIKit : texture grise en mosaïque teintée par son UIGradient -> pastilles CSS sur le dégradé
local function studCss(node: any): string?
	if node.ImageTransparency >= 1 then
		return nil
	end
	local gradient = activeGradient(node)
	local light = env.Color3.new(0.9, 0.9, 0.9)
	local base = if gradient then gradientCss(gradient, light, node.ImageTransparency) else rgba(light, node.ImageTransparency)
	local tile = node.TileSize
	local px = math.max(4, tile.X.Offset)
	local dots = "radial-gradient(circle at 50% 46%,rgba(255,255,255,.22) 0 30%,rgba(0,0,0,.16) 31% 36%,transparent 37%)"
	return string.format("%s,%s;background-size:%dpx %dpx,100%% 100%%", dots, base, px, px)
end

-- ===== mise en page =====
local function resolveUDim(u: any, ref: number): number
	return u.Scale * ref + u.Offset
end

local layoutNode: (node: any, pw: number, ph: number, forceW: number?, forceH: number?) -> any
local fullScrollMode = false

local function layoutChildren(rec: any): (number, number)
	local node = rec.Node
	local pad = firstOf(node, "UIPadding")
	local padL, padR, padT, padB = 0, 0, 0, 0
	if pad then
		padL = resolveUDim(pad.PaddingLeft, rec.W)
		padR = resolveUDim(pad.PaddingRight, rec.W)
		padT = resolveUDim(pad.PaddingTop, rec.H)
		padB = resolveUDim(pad.PaddingBottom, rec.H)
	end
	rec.PadL, rec.PadT = padL, padT
	local cw, ch = rec.W - padL - padR, rec.H - padT - padB
	local list, grid = firstOf(node, "UIListLayout"), firstOf(node, "UIGridLayout")
	local kids: { any } = {}
	for index, child in node:GetChildren() do
		if child:IsA("GuiObject") and child.Visible ~= false then
			table.insert(kids, { Node = child, Index = index })
		end
	end
	rec.Kids = {}
	local extentW, extentH = padL + padR, padT + padB
	if list or grid then
		table.sort(kids, function(a, b)
			local la, lb = a.Node.LayoutOrder, b.Node.LayoutOrder
			if la ~= lb then
				return la < lb
			end
			return a.Index < b.Index
		end)
	end
	if grid then
		local cell = grid.CellSize
		local gap = grid.CellPadding
		local cellW, cellH = resolveUDim(cell.X, cw), resolveUDim(cell.Y, ch)
		local gapX, gapY = resolveUDim(gap.X, cw), resolveUDim(gap.Y, ch)
		local perRow = math.max(1, math.floor((cw + gapX) / (cellW + gapX) + 1e-6))
		local x, y, count = padL, padT, 0
		for _, entry in kids do
			local kid = layoutNode(entry.Node, cw, ch, cellW, cellH)
			kid.X, kid.Y = x, y
			table.insert(rec.Kids, kid)
			count += 1
			if count % perRow == 0 then
				x = padL
				y += cellH + gapY
			else
				x += cellW + gapX
			end
		end
		local rows = math.ceil(count / perRow)
		extentH = padT + padB + (if rows > 0 then rows * cellH + (rows - 1) * gapY else 0)
		extentW = padL + padR + math.min(count, perRow) * cellW + math.max(0, math.min(count, perRow) - 1) * gapX
	elseif list then
		local vertical = enumName(list.FillDirection, "Vertical") == "Vertical"
		local spacing = resolveUDim(list.Padding, if vertical then ch else cw)
		local hAlign, vAlign = enumName(list.HorizontalAlignment, "Left"), enumName(list.VerticalAlignment, "Top")
		if vertical then
			local y = padT
			for _, entry in kids do
				local kid = layoutNode(entry.Node, cw, ch)
				kid.Y = y
				kid.X = padL + (if hAlign == "Center" then (cw - kid.W) / 2 elseif hAlign == "Right" then cw - kid.W else 0)
				table.insert(rec.Kids, kid)
				y += kid.H + spacing
				extentW = math.max(extentW, padL + kid.W + padR)
			end
			extentH = (if #kids > 0 then y - spacing else padT) + padB
		else
			local wraps = list.Wraps == true
			local lines: { { Kids: { any }, W: number, H: number } } = { { Kids = {}, W = 0, H = 0 } }
			for _, entry in kids do
				local kid = layoutNode(entry.Node, cw, ch)
				local line = lines[#lines]
				if wraps and #line.Kids > 0 and line.W + spacing + kid.W > cw + 0.01 then
					line = { Kids = {}, W = 0, H = 0 }
					table.insert(lines, line)
				end
				line.W += (if #line.Kids > 0 then spacing else 0) + kid.W
				line.H = math.max(line.H, kid.H)
				table.insert(line.Kids, kid)
			end
			local y = padT
			for _, line in lines do
				local x = padL + (if hAlign == "Center" then (cw - line.W) / 2 elseif hAlign == "Right" then cw - line.W else 0)
				for _, kid in line.Kids do
					kid.X = x
					kid.Y = y + (if vAlign == "Center" then (line.H - kid.H) / 2 elseif vAlign == "Bottom" then line.H - kid.H else 0)
					table.insert(rec.Kids, kid)
					x += kid.W + spacing
				end
				extentW = math.max(extentW, padL + line.W + padR)
				y += line.H + (if wraps then spacing else 0)
			end
			extentH = (if #kids > 0 then y - (if wraps then spacing else 0) else padT) + padB
		end
	else
		for _, entry in kids do
			local child = entry.Node
			local kid = layoutNode(child, cw, ch)
			local p, a = child.Position, child.AnchorPoint
			kid.X = padL + p.X.Scale * cw + p.X.Offset - a.X * kid.W
			kid.Y = padT + p.Y.Scale * ch + p.Y.Offset - a.Y * kid.H
			table.insert(rec.Kids, kid)
			extentW = math.max(extentW, kid.X + kid.W + padR)
			extentH = math.max(extentH, kid.Y + kid.H + padB)
		end
	end
	return extentW, extentH
end

function layoutNode(node: any, pw: number, ph: number, forceW: number?, forceH: number?): any
	local s = node.Size
	local constraint = enumName(node.SizeConstraint, "RelativeXY")
	local refX, refY = pw, ph
	if constraint == "RelativeXX" then
		refY = pw
	elseif constraint == "RelativeYY" then
		refX = ph
	end
	local w, h = resolveUDim(s.X, refX), resolveUDim(s.Y, refY)
	if forceW then
		w = forceW
	end
	if forceH then
		h = forceH
	end
	local limit = firstOf(node, "UISizeConstraint")
	if limit then
		local maxSize, minSize = limit.MaxSize, limit.MinSize
		w, h = math.min(w, maxSize.X), math.min(h, maxSize.Y)
		w, h = math.max(w, minSize.X), math.max(h, minSize.Y)
	end
	local aspect = firstOf(node, "UIAspectRatioConstraint")
	if aspect and aspect.AspectRatio > 0 then
		-- (approximation : la dimension la plus petite décide)
		if w / h > aspect.AspectRatio then
			w = h * aspect.AspectRatio
		else
			h = w / aspect.AspectRatio
		end
	end
	local rec: any = { Node = node, X = 0, Y = 0, W = w, H = h, Kids = {}, PadL = 0, PadT = 0 }
	local auto = enumName(node.AutomaticSize, "None")
	local scrolls = node.ClassName == "ScrollingFrame"
	local canvasAuto = fullScrollMode and scrolls and enumName(node.AutomaticCanvasSize, "None") ~= "None"
	local extentW, extentH = layoutChildren(rec)
	local changed = false
	if auto == "Y" or auto == "XY" or canvasAuto then
		if extentH ~= rec.H then
			rec.H = extentH
			changed = true
		end
	end
	if auto == "X" or auto == "XY" then
		if extentW ~= rec.W then
			rec.W = extentW
			changed = true
		end
	end
	if changed then
		layoutChildren(rec)
	end
	return rec
end

-- ===== texte =====
local function wrapLines(text: string, width: number, size: number): number
	local charW = size * 0.56
	local lines, line = 1, 0
	for word in string.gmatch(text, "%S+") do
		local w = #word * charW
		if line > 0 and line + charW + w > width then
			lines += 1
			line = w
		else
			line += (if line > 0 then charW else 0) + w
		end
	end
	return lines
end

local function fontSize(node: any, w: number, h: number): number
	local text = node.Text
	if not node.TextScaled then
		return node.TextSize
	end
	local maxSize, minSize = 100, 1
	local constraint = firstOf(node, "UITextSizeConstraint")
	if constraint then
		maxSize = constraint.MaxTextSize
		minSize = constraint.MinTextSize
	end
	local size = math.min(maxSize, math.floor(h), 100)
	while size > minSize do
		local lines = if node.TextWrapped then wrapLines(text, w, size) else 1
		local textW = #text * size * 0.56
		if lines * size * 1.08 <= h and (node.TextWrapped or textW <= w) then
			break
		end
		size -= 1
	end
	return math.max(size, minSize)
end

local function strokeShadow(thickness: number, color: string): string
	local t = math.max(1, thickness)
	local parts = {}
	for _, d in { { -1, 0 }, { 1, 0 }, { 0, -1 }, { 0, 1 }, { -0.7, -0.7 }, { 0.7, -0.7 }, { -0.7, 0.7 }, { 0.7, 0.7 } } do
		table.insert(parts, string.format("%.1fpx %.1fpx 0 %s", d[1] * t, d[2] * t, color))
	end
	return table.concat(parts, ",")
end

local function fontFamily(node: any): string
	local face = node.FontFace
	local family = if face then tostring(face.Family) else ""
	if string.find(family, "Fredoka", 1, true) or string.find(family, "FredokaOne", 1, true) then
		return "'Fredoka One','Fredoka','Arial Rounded MT Bold','Arial Black',sans-serif"
	end
	return "'Inter','DejaVu Sans',sans-serif"
end

-- ===== HTML =====
local function emit(rec: any, out: { string }, options: any)
	local node = rec.Node
	local style: { string } = {
		string.format("left:%spx", num(rec.X)),
		string.format("top:%spx", num(rec.Y)),
		string.format("width:%spx", num(rec.W)),
		string.format("height:%spx", num(rec.H)),
		string.format("z-index:%d", node.ZIndex),
	}
	local transform: { string } = {}
	if node.Rotation ~= 0 then
		table.insert(transform, string.format("rotate(%.2fdeg)", node.Rotation))
	end
	local uiScale = firstOf(node, "UIScale")
	if uiScale and uiScale.Scale ~= 1 then
		table.insert(transform, string.format("scale(%.3f)", uiScale.Scale))
		-- (dans Roblox un UIScale agrandit ou réduit autour du point d'ancrage de l'objet)
		local anchor = node.AnchorPoint
		table.insert(style, string.format("transform-origin:%.1f%% %.1f%%", anchor.X * 100, anchor.Y * 100))
	end
	if #transform > 0 then
		table.insert(style, "transform:" .. table.concat(transform, " "))
	end
	local corner = firstOf(node, "UICorner")
	if corner then
		local radius = math.min(corner.CornerRadius.Scale * math.min(rec.W, rec.H) + corner.CornerRadius.Offset, math.min(rec.W, rec.H) / 2)
		table.insert(style, string.format("border-radius:%spx", num(radius)))
	end
	local isText = node.ClassName == "TextLabel" or node.ClassName == "TextButton" or node.ClassName == "TextBox"
	local isImage = node.ClassName == "ImageLabel" or node.ClassName == "ImageButton"
	local background = backgroundCss(node, node.BackgroundTransparency)
	local studs = isImage and node.Image ~= "" and node.Image == studImage()
	if studs then
		background = studCss(node)
	end
	if background then
		table.insert(style, "background:" .. background)
	end
	if node.ClipsDescendants or node.ClassName == "CanvasGroup" or (node.ClassName == "ScrollingFrame" and not options.fullScroll) then
		table.insert(style, "overflow:hidden")
	end
	-- contours des cadres (hors texte) : un anneau à l'extérieur
	local shadows: { string } = {}
	for _, stroke in allOf(node, "UIStroke") do
		if stroke.Enabled ~= false and stroke.Thickness > 0 and not (isText and enumName(stroke.ApplyStrokeMode, "Contextual") == "Contextual") then
			local color = if firstOf(stroke, "UIGradient") then "#ffb52e" else rgba(stroke.Color, stroke.Transparency)
			table.insert(shadows, string.format("0 0 0 %spx %s", num(stroke.Thickness), color))
		end
	end
	if #shadows > 0 then
		table.insert(style, "box-shadow:" .. table.concat(shadows, ","))
	end
	table.insert(out, string.format('<div class="n" data-name="%s" style="%s">', esc(node.Name), table.concat(style, ";")))
	if isText and node.Text ~= "" and node.TextTransparency < 1 then
		local size = fontSize(node, rec.W, rec.H)
		local align = enumName(node.TextXAlignment, "Center")
		local vAlign = enumName(node.TextYAlignment, "Center")
		local justify = if align == "Left" then "flex-start" elseif align == "Right" then "flex-end" else "center"
		local alignItems = if vAlign == "Top" then "flex-start" elseif vAlign == "Bottom" then "flex-end" else "center"
		local stroke = nil
		for _, s in allOf(node, "UIStroke") do
			if s.Enabled ~= false and s.Thickness > 0 then
				stroke = s
			end
		end
		local gradient = activeGradient(node)
		local shadow = if stroke then strokeShadow(math.min(stroke.Thickness, 4) * 0.55, rgba(stroke.Color, stroke.Transparency)) else "none"
		local function layer(color: string, extra: string)
			table.insert(
				out,
				string.format(
					'<span class="t" style="justify-content:%s;align-items:%s;font-size:%dpx;font-family:%s;color:%s;%s;white-space:%s;text-align:%s">%s</span>',
					justify,
					alignItems,
					size,
					fontFamily(node),
					color,
					extra,
					if node.TextWrapped then "pre-wrap" else "nowrap",
					string.lower(align),
					esc(node.Text)
				)
			)
		end
		if gradient then
			layer("transparent", "text-shadow:" .. shadow)
			local stops = {}
			for _, k in gradient.Color.Keypoints do
				table.insert(stops, string.format("%s %.0f%%", rgba(k.Value, 0), k.Time * 100))
			end
			layer(
				"transparent",
				string.format(
					"background:linear-gradient(%ddeg,%s);-webkit-background-clip:text;background-clip:text;-webkit-text-fill-color:transparent",
					math.floor(90 + (gradient.Rotation or 0)),
					table.concat(stops, ",")
				)
			)
		else
			layer(rgba(node.TextColor3, node.TextTransparency), "text-shadow:" .. shadow)
		end
	elseif isImage and not studs and node.Image ~= "" and node.ImageTransparency < 1 then
		local art = Render.Art.Icons[node.Image]
		if art then
			-- (image teintée en noir : ombre des icônes du UIKit)
			local tint = node.ImageColor3
			local dark = tint.R + tint.G + tint.B < 0.3
			local style = if dark then string.format(' style="filter:brightness(0);opacity:%.2f"', 1 - node.ImageTransparency) else ""
			table.insert(out, '<div class="art"' .. style .. ">" .. art .. "</div>")
		else
			local id = string.match(node.Image, "%d+") or "?"
			table.insert(out, string.format('<div class="icon" style="background:%s">%s</div>', rgba(node.ImageColor3, 0), esc(string.sub(id, -4))))
		end
	elseif node.ClassName == "ViewportFrame" then
		local label = "3D"
		for _, child in node:GetDescendants() do
			if child.ClassName == "Model" then
				label = child.Name
				break
			end
		end
		local art = Render.Art.Viewports[label]
		if art then
			table.insert(out, '<div class="art">' .. art .. "</div>")
		else
			table.insert(out, string.format('<div class="vp">%s</div>', esc(label)))
		end
	end
	if node.ClassName == "ScrollingFrame" and not options.fullScroll then
		table.insert(out, string.format('<div class="n" style="left:0;top:%spx;width:%spx;height:%spx">', num(-node.CanvasPosition.Y), num(rec.W), num(rec.H)))
	end
	for _, kid in rec.Kids do
		emit(kid, out, options)
	end
	if node.ClassName == "ScrollingFrame" and not options.fullScroll then
		table.insert(out, "</div>")
	end
	table.insert(out, "</div>")
end

local function pageStart(out: { string }, width: number, height: number)
	table.insert(out, '<!doctype html><html><head><meta charset="utf-8"><style>')
	table.insert(out, "html,body{margin:0;padding:0}body{background:linear-gradient(#9fd4ff,#d9f0c4);font-weight:900;width:" .. num(width) .. "px}")
	table.insert(out, ".n{position:absolute;box-sizing:border-box}.t{position:absolute;left:0;top:0;width:100%;height:100%;display:flex;box-sizing:border-box;line-height:1.05;letter-spacing:-0.01em;overflow:visible}")
	table.insert(out, ".icon{position:absolute;inset:8%;border-radius:22%;box-shadow:0 0 0 2px #0e0c18;color:#0e0c18;font:900 10px sans-serif;display:flex;align-items:center;justify-content:center;overflow:hidden}")
	table.insert(out, ".vp{position:absolute;inset:4%;border:2px dashed #52d6c8;color:#1d6e66;border-radius:12%;font:900 11px sans-serif;display:flex;align-items:center;justify-content:center;text-align:center;background:rgba(255,255,255,.25);overflow:hidden}")
	table.insert(out, ".art{position:absolute;inset:0;display:flex;align-items:center;justify-content:center}.art>svg,.art>img{width:100%;height:100%;object-fit:contain}")
	table.insert(out, '</style></head><body><div style="position:relative;width:' .. num(width) .. "px;height:" .. num(height) .. 'px;overflow:hidden">')
end

-- Page HTML de tout l'écran d'un joueur : chaque ScreenGui activé de son PlayerGui, dans l'ordre de DisplayOrder
function Render.Screen(playerGui: any, width: number, height: number): string
	fullScrollMode = false
	local guis = {}
	for _, gui in playerGui:GetChildren() do
		if gui:IsA("ScreenGui") and gui.Enabled then
			table.insert(guis, gui)
		end
	end
	table.sort(guis, function(a, b)
		return a.DisplayOrder < b.DisplayOrder
	end)
	local out: { string } = {}
	pageStart(out, width, height)
	for index, gui in guis do
		table.insert(out, string.format('<div class="n" data-name="%s" style="left:0;top:0;width:%spx;height:%spx;z-index:%d">', esc(gui.Name), num(width), num(height), index))
		local rec: any = { Node = gui, X = 0, Y = 0, W = width, H = height, Kids = {} }
		layoutChildren(rec)
		for _, kid in rec.Kids do
			emit(kid, out, {})
		end
		table.insert(out, "</div>")
	end
	table.insert(out, "</div></body></html>")
	return table.concat(out)
end

-- Page HTML d'un seul élément (`root`, un GuiObject) en `width` x `height` (hauteur du contenu si nil, fullScroll :
-- les ScrollingFrame sont dépliés)
function Render.Element(root: any, width: number, height: number?, options: any?): string
	local opts = options or {}
	fullScrollMode = opts.fullScroll == true
	local rec = layoutNode(root, width, height or 100000, width, height)
	local out: { string } = {}
	pageStart(out, width, height or rec.H)
	rec.X, rec.Y = 0, 0
	emit(rec, out, opts)
	table.insert(out, "</div></body></html>")
	return table.concat(out)
end

return Render
