
















local ADDON, A = ...



local card



local waiting = setmetatable({}, { __mode = "k" })
local hooked = setmetatable({}, { __mode = "k" })



local installed, pending = false, false


local last = { state = "none" }


local GRID = { "With you", "Against", "Met" }


local function text(parent, role)
	local fs = parent:CreateFontString(nil, "OVERLAY")
	A.style(fs, role)
	fs:SetJustifyH("LEFT")
	fs:SetWordWrap(false)
	return fs
end


local function edges(parent)
	local held = {}
	for i = 1, 4 do
		held[i] = parent:CreateTexture(nil, "BORDER")
	end
	return held
end


local function outline(held, owner, thick, colorName)
	local r, g, b, a = A.color(colorName)
	local top, bottom, left, right = held[1], held[2], held[3], held[4]
	for i = 1, 4 do
		held[i]:ClearAllPoints()
		held[i]:SetColorTexture(r, g, b, a)
		held[i]:Show()
	end
	top:SetPoint("TOPLEFT", owner, "TOPLEFT", 0, 0)
	top:SetPoint("TOPRIGHT", owner, "TOPRIGHT", 0, 0)
	top:SetHeight(thick)
	bottom:SetPoint("BOTTOMLEFT", owner, "BOTTOMLEFT", 0, 0)
	bottom:SetPoint("BOTTOMRIGHT", owner, "BOTTOMRIGHT", 0, 0)
	bottom:SetHeight(thick)
	left:SetPoint("TOPLEFT", owner, "TOPLEFT", 0, 0)
	left:SetPoint("BOTTOMLEFT", owner, "BOTTOMLEFT", 0, 0)
	left:SetWidth(thick)
	right:SetPoint("TOPRIGHT", owner, "TOPRIGHT", 0, 0)
	right:SetPoint("BOTTOMRIGHT", owner, "BOTTOMRIGHT", 0, 0)
	right:SetWidth(thick)
end


A.cardEdges = edges
A.cardOutline = outline

local function hideAll(list)
	for i = 1, #list do
		list[i]:Hide()
	end
end


local function cardOrNil()
	if card then
		return card
	end
	local ok, made = pcall(function()
		local f = CreateFrame("Frame", ADDON .. "NameCard", UIParent)
		f:SetFrameStrata("TOOLTIP")
		f:SetClampedToScreen(true)
		f:Hide()
		f.ground = f:CreateTexture(nil, "BACKGROUND")
		f.ground:SetAllPoints(f)
		f.edges = edges(f)
		f.head = text(f, "cardHead")
		f.chip = CreateFrame("Frame", nil, f)
		f.chip.ground = f.chip:CreateTexture(nil, "BACKGROUND")
		f.chip.ground:SetAllPoints(f.chip)
		f.chip.label = text(f.chip, "cardHead")
		f.chip.dashes = {}
		f.name = text(f, "cardName")
		f.meta = text(f, "cardText")
		f.line = text(f, "cardText")
		f.labels, f.values = {}, {}
		for i = 1, #GRID do
			f.labels[i] = text(f, "cardLabel")
			f.values[i] = text(f, "cardValue")
		end

		f.metLast = text(f, "cardLabel")
		f.rule = f:CreateTexture(nil, "ARTWORK")
		f.note = text(f, "cardText")
		f.note:SetWordWrap(true)
		f.tags = {}
		return f
	end)
	if ok and type(made) == "table" then
		card = made
	end
	return card
end


local function dashes(chip, w, h)
	local dash, gap = A.metric("nameCardDash"), A.metric("nameCardDashGap")
	local thick = A.metric("nameCardChipEdge")
	local r, g, b, a = A.color("dimmer")
	local used = 0
	local function put(x, y, dw, dh)
		used = used + 1
		local t = chip.dashes[used]
		if not t then
			t = chip:CreateTexture(nil, "BORDER")
			chip.dashes[used] = t
		end
		t:ClearAllPoints()
		t:SetPoint("TOPLEFT", chip, "TOPLEFT", x, -y)
		t:SetSize(dw, dh)
		t:SetColorTexture(r, g, b, a)
		t:Show()
	end
	local x = 0
	while x < w do
		local length = math.min(dash, w - x)
		put(x, 0, length, thick)
		put(x, h - thick, length, thick)
		x = x + dash + gap
	end
	local y = 0
	while y < h do
		local length = math.min(dash, h - y)
		put(0, y, thick, length)
		put(w - thick, y, thick, length)
		y = y + dash + gap
	end
	for i = used + 1, #chip.dashes do
		chip.dashes[i]:Hide()
	end
	return used
end


local function tagChip(f, index)
	local chip = f.tags[index]
	if not chip then
		chip = CreateFrame("Frame", nil, f)
		chip.edges = edges(chip)
		chip.label = text(chip, "bodyText")
		f.tags[index] = chip
	end
	return chip
end



local function layoutHeader(f, said, inner, padX, padY)
	local headSize = A.fontSize("cardHead")
	local chipH = A.metric("nameCardChipHeight")
	local rowH = math.max(headSize, chipH)

	A.style(f.head, "cardHead", "accent")
	f.head:SetText(A.displayName():upper())
	f.head:ClearAllPoints()
	f.head:SetPoint("TOPLEFT", f, "TOPLEFT", padX, -(padY + math.floor((rowH - headSize) / 2)))
	f.head:Show()

	local chip = f.chip
	local filled = said.kind == "met" and said.rated == true
	local word = filled and said.rep or (A.repLabel(nil))
	local pad = A.metric("nameCardChipPad")
	A.style(chip.label, "cardHead")
	local chipW = math.min(inner, A.textRoom(chip.label, word) + 2 * pad)
	chip:SetSize(chipW, chipH)
	chip.top = padY + math.floor((rowH - chipH) / 2)
	chip.label:SetText(word)


	chip.label:SetWidth(math.max(0, chipW - 2 * pad))
	chip.label:SetJustifyH("CENTER")
	chip.label:ClearAllPoints()
	chip.label:SetPoint("CENTER", chip, "CENTER", 0, 0)
	if filled then
		chip.ground:SetColorTexture(A.color(said.repMark or "dim"))
		chip.ground:Show()



		local r, g, b = A.color("panelDeep")
		A.style(chip.label, "cardHead")
		chip.label:SetTextColor(r, g, b, 1)
		hideAll(chip.dashes)
	else
		chip.ground:Hide()
		A.style(chip.label, "cardHead", "dim")
		dashes(chip, chipW, chipH)
	end
	chip.label:Show()
	chip:Show()
	return rowH
end



local function placeChip(f)
	local chip = f.chip
	chip:ClearAllPoints()
	chip:SetPoint("TOPRIGHT", f, "TOPRIGHT", -A.metric("nameCardChipInset"), -(chip.top or 0))
end



local function nameClass(said, finderClass)


	if A.canRead(finderClass) and type(finderClass) == "string" and finderClass ~= "" then
		return finderClass, "finder"
	end
	if type(said.classToken) == "string" and said.classToken ~= "" then
		return said.classToken, "record"
	end
	return nil, "none"
end


local function layoutName(f, said, inner, padX, top, classToken)
	local nameText = tostring(said.name or "")
	local where = {}
	if said.realm then
		where[#where + 1] = said.realm
	end
	if said.spec then
		where[#where + 1] = said.spec
	end
	A.style(f.name, "cardName")
	f.name:SetTextColor(A.classColor(classToken))
	f.name:SetText(nameText)
	local nameW = math.min(inner, A.textRoom(f.name, nameText))
	f.name:SetWidth(nameW)
	f.name:ClearAllPoints()
	f.name:SetPoint("TOPLEFT", f, "TOPLEFT", padX, -top)
	f.name:Show()

	local metaRoom = inner - nameW - A.metric("nameCardNameGap")
	if #where > 0 and metaRoom > 0 then
		A.style(f.meta, "cardText", "dim")
		f.meta:SetText(table.concat(where, ", "))

		f.meta:SetWidth(metaRoom)
		f.meta:ClearAllPoints()
		f.meta:SetPoint("BOTTOMLEFT", f.name, "BOTTOMRIGHT", A.metric("nameCardNameGap"), 0)
		f.meta:Show()
	else
		f.meta:Hide()
	end
	return A.fontSize("cardName")
end



local function gridColumns(f, inner)
	local floors, need = {}, 0
	for i = 1, #GRID do
		floors[i] = A.textRoom(f.labels[i], GRID[i])
		need = need + floors[i]
	end
	local share = math.floor(inner / #GRID)
	local widths = {}
	local fits = true
	for i = 1, #GRID do
		if floors[i] > share then
			fits = false
		end
	end
	for i = 1, #GRID do
		widths[i] = fits and share or (floors[i] + math.max(0, math.floor((inner - need) / #GRID)))
	end
	return widths, need
end


function A.cardMetLast(said)
	local day = type(said) == "table" and said.last ~= nil and A.shortDayText(said.last) or nil
	return day and ("last %s"):format(day) or nil
end



local function layoutGrid(f, said, inner, padX, top)
	local widths = gridColumns(f, inner)
	local values = { A.sideShortMarkup(said.with), A.sideShortMarkup(said.against), tostring(said.met or 0) }
	local labelH = A.fontSize("cardLabel")
	local x = padX
	for i = 1, #GRID do
		local label, value = f.labels[i], f.values[i]
		A.style(label, "cardLabel", "dim")
		label:SetText(GRID[i])
		label:SetWidth(widths[i])
		label:ClearAllPoints()
		label:SetPoint("TOPLEFT", f, "TOPLEFT", x, -top)
		label:Show()
		A.style(value, "cardValue", "text")
		value:SetText(values[i])
		value:SetWidth(widths[i])
		value:ClearAllPoints()
		value:SetPoint("TOPLEFT", f, "TOPLEFT", x, -(top + labelH))
		value:Show()
		x = x + widths[i]
	end
	local height = labelH + A.fontSize("cardValue")
	local lastText = A.cardMetLast(said)
	local metValue = f.values[#GRID]
	if lastText then
		A.style(f.metLast, "cardLabel", "dim")
		f.metLast:SetText(lastText)
		f.metLast:SetWidth(widths[#GRID])
		f.metLast:ClearAllPoints()
		f.metLast:SetPoint("TOPLEFT", metValue, "BOTTOMLEFT", 0, 0)
		f.metLast:Show()
		height = height + A.fontSize("cardLabel")
	else
		f.metLast:SetText("")
		f.metLast:Hide()
	end
	return height, lastText
end


local function layoutNote(f, said, inner, padX, top)
	local rule = A.metric("nameCardChipEdge")
	f.rule:ClearAllPoints()
	f.rule:SetPoint("TOPLEFT", f, "TOPLEFT", padX, -top)
	f.rule:SetSize(inner, rule)
	f.rule:SetColorTexture(A.color("hairline"))
	f.rule:Show()
	local below = top + rule + A.metric("nameCardRulePad")
	A.style(f.note, "cardText", "text")
	f.note:SetWidth(inner)
	f.note:SetText(A.colorEscape("noteWord") .. "Note|r " .. said.note)
	f.note:ClearAllPoints()
	f.note:SetPoint("TOPLEFT", f, "TOPLEFT", padX, -below)
	f.note:Show()
	local height = f.note:GetStringHeight()
	if type(height) ~= "number" or height <= 0 then
		height = A.fontSize("cardText")
	end
	return (below - top) + math.ceil(height)
end



local function layoutTags(f, tags, inner, padX, top)
	local pad, gap = A.metric("nameCardTagPad"), A.metric("nameCardTagGap")
	local tagH = A.metric("nameCardTagHeight")
	local x, line = 0, 0
	for i = 1, #tags do
		local chip = tagChip(f, i)
		local word = tostring(tags[i])
		A.style(chip.label, "bodyText", "chipText")
		chip.label:SetText(word)
		local w = math.min(inner, A.textRoom(chip.label, word) + 2 * pad)
		if x > 0 and x + w > inner then
			line, x = line + 1, 0
		end
		chip:ClearAllPoints()
		chip:SetPoint("TOPLEFT", f, "TOPLEFT", padX + x, -(top + line * (tagH + gap)))
		chip:SetSize(w, tagH)
		chip.label:SetWidth(w - 2 * pad)
		chip.label:ClearAllPoints()
		chip.label:SetPoint("LEFT", chip, "LEFT", pad, 0)
		chip.label:Show()
		outline(chip.edges, chip, A.metric("nameCardChipEdge"), "chipEdge")
		chip:Show()
		chip.line = line + 1
		x = x + w + gap
	end
	for i = #tags + 1, #f.tags do
		f.tags[i]:Hide()
	end
	return (line + 1) * tagH + line * gap, line + 1
end




local function layout(f, said, finderClass)
	local padX, padY, gap = A.metric("nameCardPadX"), A.metric("nameCardPadY"), A.metric("nameCardGap")



	local base, cap = A.metric("nameCardWidth"), A.metric("nameCardWidthMax")
	A.style(f.name, "cardName")
	local nameNeed = A.textRoom(f.name, tostring(said.name or ""))
	local _, labelsNeed = gridColumns(f, base - 2 * padX)
	local width = math.max(base, math.min(cap, math.max(nameNeed, labelsNeed) + 2 * padX))
	local inner = width - 2 * padX

	f.ground:SetColorTexture(A.color("cardPanel"))
	f.ground:Show()
	outline(f.edges, f, A.metric("nameCardEdge"), "cardBorder")

	local y = padY
	y = y + layoutHeader(f, said, inner, padX, padY) + gap
	local classToken, classFrom = nameClass(said, finderClass)
	y = y + layoutName(f, said, inner, padX, y, classToken)

	local drew = { note = false, tags = 0, tagLines = 0, nameClass = classFrom }
	if said.kind == "stranger" then
		y = y + gap
		A.style(f.line, "cardText", "dim")
		f.line:SetText("Not met before.")
		f.line:ClearAllPoints()
		f.line:SetPoint("TOPLEFT", f, "TOPLEFT", padX, -y)
		f.line:Show()
		y = y + A.fontSize("cardText")
		hideAll(f.labels)
		hideAll(f.values)
		f.metLast:Hide()
		f.rule:Hide()
		f.note:Hide()
		hideAll(f.tags)
	else
		f.line:Hide()
		y = y + gap
		local gridH, metLast = layoutGrid(f, said, inner, padX, y)
		y = y + gridH
		drew.metLast = metLast
		if said.note then
			y = y + gap
			y = y + layoutNote(f, said, inner, padX, y)
			drew.note = true
		else
			f.rule:Hide()
			f.note:Hide()
		end
		local tags = type(said.tags) == "table" and said.tags or {}
		if #tags > 0 then
			y = y + gap
			local height, lines = layoutTags(f, tags, inner, padX, y)
			y = y + height
			drew.tags, drew.tagLines = #tags, lines
		else
			hideAll(f.tags)
		end
	end
	y = y + padY

	f:SetSize(width, y)
	placeChip(f)
	drew.w, drew.h = f:GetWidth(), f:GetHeight()
	return drew
end





local function chipEdges(f, width)
	local okL, left = pcall(f.GetLeft, f)
	local okR, right = pcall(f.GetRight, f)
	local okC, chipRight = pcall(f.chip.GetRight, f.chip)
	local function number(ok, v)
		return ok and A.canRead(v) and type(v) == "number"
	end
	if number(okL, left) and number(okR, right) and number(okC, chipRight) then
		return A.unitFigure(chipRight - left), A.unitFigure(right - left), "rect"
	end
	return A.unitFigure(width - A.metric("nameCardChipInset")), A.unitFigure(width), "anchor"
end




local function draw(said, owner, under, finderClass)
	if said.kind ~= "met" and said.kind ~= "stranger" then
		if card then
			pcall(card.Hide, card)
		end
		return nil
	end
	local f = cardOrNil()
	if not f then
		return nil
	end
	local ok, drew = pcall(function()
		local laid = layout(f, said, finderClass)
		f:ClearAllPoints()
		if under ~= nil then
			f:SetPoint("TOPLEFT", under, "BOTTOMLEFT", 0, -2)
		elseif owner ~= nil and owner ~= UIParent then
			f:SetPoint("TOPLEFT", owner, "TOPRIGHT", 4, 0)
		else
			f:SetPoint("TOP", UIParent, "TOP", 0, -160)
		end
		f:Show()
		laid.chipRight, laid.cardRight, laid.chipFrom = chipEdges(f, laid.w)
		return laid
	end)
	if not ok then
		A.noteError(drew, "card-draw")
		pcall(f.Hide, f)
		return nil
	end
	return drew
end







local function traceCard(said, source, drew)
	local ids = nil
	if said.kind == "met" and type(said.ids) == "table" then
		local held = {}
		for i = 1, #said.ids do
			held[i] = tostring(said.ids[i])
		end
		ids = table.concat(held, ",")
	end
	local repStep = nil
	if drew then
		repStep = said.rating ~= nil and said.rating or "none"
	end
	pcall(A.trace, "card", {
		source = source,
		state = said.kind,
		reason = said.why,
		via = said.via,
		cardIndex = said.indexed,
		cardNames = said.nameIndex,
		n = said.met,
		with = A.sideShortText(said.with),
		against = A.sideShortText(said.against),
		ids = ids,
		repStep = repStep,
		cardNote = drew and drew.note,
		cardTags = drew and drew.tags,
		cardTagLines = drew and drew.tagLines,
		cardMetLast = drew and drew.metLast,
		cardW = drew and drew.w,
		cardH = drew and drew.h,
		chipRight = drew and drew.chipRight,
		cardRight = drew and drew.cardRight,
		chipFrom = drew and drew.chipFrom,
		nameClass = drew and drew.nameClass,
	}, "ui")
end




function A.showNameCard(name, owner, source, under, finderClass)
	local ok, said = pcall(A.nameCard, name, time(), A.ownRealm())
	if not ok or type(said) ~= "table" then
		said = { kind = "unresolved", why = "no name" }
	end
	local drew = draw(said, owner, under, finderClass)
	last = { state = said.kind, reason = said.why,
		name = (said.kind == "met" or said.kind == "stranger" or said.kind == "self") and said.name or nil,
		source = source, w = drew and drew.w, h = drew and drew.h }
	traceCard(said, source, drew)
	return said
end


function A.hideNameCard()
	if not card then
		return false
	end
	local ok, shown = pcall(card.IsShown, card)
	pcall(card.Hide, card)
	return ok and shown == true
end


function A.nameCardFrame()
	return card
end



function A.nameCardState()
	return last
end








local function onEnter(member)
	local parent = type(member.GetParent) == "function" and member:GetParent() or nil
	local applicantID = type(parent) == "table" and parent.applicantID or nil
	local memberIdx = member.memberIdx
	local name, classToken = nil, nil
	if applicantID ~= nil and memberIdx ~= nil and type(C_LFGList) == "table"
		and type(C_LFGList.GetApplicantMemberInfo) == "function" then
		local ok, held, class = pcall(C_LFGList.GetApplicantMemberInfo, applicantID, memberIdx)
		if ok then
			name, classToken = held, class
		end
	end

	local under = nil
	if GameTooltip and type(GameTooltip.IsShown) == "function" then
		local okShown, shown = pcall(GameTooltip.IsShown, GameTooltip)
		local okOwner, owner = pcall(GameTooltip.GetOwner, GameTooltip)
		if okShown and shown and okOwner and owner == member then
			under = GameTooltip
		end
	end
	A.showNameCard(name, member, "finder", under, classToken)
end

local function onLeave()
	A.hideNameCard()
end


local function pass()
	for member in pairs(waiting) do
		waiting[member] = nil
		if not hooked[member] and type(member.HookScript) == "function" then
			hooked[member] = true
			member:HookScript("OnEnter", onEnter)
			member:HookScript("OnLeave", onLeave)
		end
	end
end


local function schedule()
	if pending or not (C_Timer and type(C_Timer.After) == "function") then
		return
	end
	pending = true
	C_Timer.After(0, function()
		pending = false
		local ok, err = pcall(pass)
		if not ok then
			A.noteError(err, "card-pass")
		end
	end)
end


local function install()
	if installed or type(hooksecurefunc) ~= "function"
		or type(LFGListApplicationViewer_UpdateApplicantMember) ~= "function" then
		return
	end
	installed = true
	hooksecurefunc("LFGListApplicationViewer_UpdateApplicantMember", function(member)
		if type(member) == "table" and not hooked[member] then
			waiting[member] = true
			schedule()
		end
	end)
end

A.on("PLAYER_LOGIN", function()
	local ok, err = pcall(install)
	if not ok then
		A.noteError(err, "card-install")
	end
end)

A.on("ADDON_LOADED", function(_, name)
	if name == "Blizzard_GroupFinder" then
		local ok, err = pcall(install)
		if not ok then
			A.noteError(err, "card-install")
		end
	end
end)


function A.nameCardInstalled()
	return installed
end
