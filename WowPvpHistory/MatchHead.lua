






local _, A = ...












function A.matchRatingParts(format, from, to)
	if type(from) ~= "number" or type(to) ~= "number" then
		return nil, "no-rating"
	end
	local ladder, reason = A.ratingLadder(format)
	if ladder == nil then
		return nil, reason
	end
	local tiers = ladder.tiers
	local function tierAt(rating)
		for i = #tiers, 1, -1 do
			if tiers[i].entry <= rating then
				return i
			end
		end
		return nil
	end
	local atFrom, atTo = tierAt(from), tierAt(to)
	if atFrom == nil or atTo == nil then
		return nil, "out-of-range"
	end

	local _, _, why, r, g, b = A.ratingColour(format, to)
	if r == nil then
		return nil, why
	end
	local word, wordWhy = A.tierWord(tiers[atTo].enum, tiers[atTo].name)
	if word == nil then
		return nil, wordWhy
	end
	local chip = { word = word, r = r, g = g, b = b, reached = atFrom ~= atTo and to > from }

	local low = math.max(1, math.min(atFrom, atTo) - 1)
	local high = math.min(#tiers, math.max(atFrom, atTo) + 1)
	local bars = {}
	for i = low, high do
		local tier = tiers[i]
		local upper = tiers[i + 1] and tiers[i + 1].entry or nil
		if upper == nil then
			local below = tiers[i - 1]
			upper = below and (tier.entry + tier.entry - below.entry) or tier.entry
		end
		local _, _, _, tr, tg, tb = A.ratingColour(format, tier.entry)
		bars[#bars + 1] = {
			word = A.tierWord(tier.enum, tier.name), entry = tier.entry, upper = upper,
			r = tr, g = tg, b = tb, here = i == atTo,
		}
	end
	local span = { bars = bars, low = bars[1].entry, high = bars[#bars].upper, from = from, to = to }
	if span.high <= span.low then
		span = nil
	end
	return { chip = chip, ladder = span }
end






function A.matchRoundCards(record)
	local table_ = type(A.roundTable) == "function" and A.roundTable(record) or nil
	if type(table_) ~= "table" or type(table_.rounds) ~= "table" then
		return nil
	end
	local own = type(record.participants) == "table" and record.character
		and record.participants[record.character] or nil
	local cards = {}
	for i = 1, #record.rounds do
		local row = table_.rounds[i] or {}
		local mates, foes = {}, {}
		for _, cell in ipairs(row.mates or {}) do
			if not cell.self then
				mates[#mates + 1] = cell
			end
		end
		for _, cell in ipairs(row.foes or {}) do
			foes[#foes + 1] = cell
		end
		cards[i] = {
			n = i, word = row.result or "-", tone = row.tone or "dim",
			classToken = type(own) == "table" and own.classToken or nil,
			spec = type(own) == "table" and own.spec or nil,
			mates = mates, foes = foes,
		}
	end
	return cards
end



function A.matchTitleStamp(record)
	local stamp = type(record) == "table" and (record.openedAt or record.completedAt) or nil
	if stamp == nil then
		return nil
	end
	local day, minute = tostring(stamp):match("^(%d%d%d%d%-%d%d%-%d%d)[ T](%d%d:%d%d)")
	if day then
		return day .. " " .. minute
	end
	return tostring(stamp)
end





function A.matchBannerHeight()
	local left = A.fontSize("heading") + A.fontSize("note") + A.metric("headPad")
	local right = A.fontSize("headingLarge")
	return math.max(left, right) + A.metric("bannerPad") * 2
end


function A.ladderHeight()
	return A.metric("ladderPad") * 2 + A.metric("ladderMark") + A.metric("ladderGap")
		+ A.fontSize("label")
end



function A.roundCardsHeight(cards)
	local names = 1
	for _, card in ipairs(type(cards) == "table" and cards or {}) do
		local held = 1 + #card.mates + #card.foes
		if held > names then
			names = held
		end
	end
	local line = A.fontSize("note") + A.metric("roundCardLine")
	return A.metric("roundCardPad") * 2 + A.metric("roundCardEdge") + A.fontSize("label")
		+ A.metric("roundCardLine") + names * line + A.metric("roundCardLine") * 2
end






local LADDER_SLOTS = 10
local CARD_SLOTS = 6
local CARD_NAMES = 6


local function outline(line, layer)
	local box = {}
	for i = 1, 4 do
		box[i] = line:CreateTexture(nil, layer or "ARTWORK")
	end
	return box
end


local function placeOutline(box, parent, x, y, w, h, r, g, b, a)
	local edges = {
		{ x, y, w, 1 }, { x, y - h + 1, w, 1 },
		{ x, y, 1, h }, { x + w - 1, y, 1, h },
	}
	for i = 1, 4 do
		local edge, at = box[i], edges[i]
		edge:ClearAllPoints()
		edge:SetPoint("TOPLEFT", parent, "TOPLEFT", at[1], at[2])
		edge:SetSize(at[3], at[4])
		edge:SetColorTexture(r, g, b, a or 1)
		edge:Show()
	end
end



function A.buildMatchHeadParts(line)
	local regions = line.headRegions
	local function keep(region)
		regions[#regions + 1] = region
		return region
	end
	local function text(template, justify)
		local fs = keep(line:CreateFontString(nil, "ARTWORK", template or "GameFontHighlightSmall"))
		fs:SetJustifyH(justify or "LEFT")
		fs:SetWordWrap(false)
		return fs
	end

	line.headPips = {}
	for i = 1, CARD_SLOTS do
		line.headPips[i] = keep(line:CreateTexture(nil, "ARTWORK"))
	end
	line.headChip = outline(line)
	for i = 1, 4 do
		keep(line.headChip[i])
	end
	line.headChipText = text("GameFontHighlightSmall", "CENTER")
	line.headMmr = text("GameFontHighlightSmall", "RIGHT")

	line.bannerBg = keep(line:CreateTexture(nil, "BACKGROUND"))
	line.bannerPlace = text("GameFontNormal")
	line.bannerNote = text("GameFontDisableSmall")
	line.bannerVerdict = text("GameFontNormalLarge", "RIGHT")

	line.ladderBars, line.ladderWords, line.ladderEntries = {}, {}, {}
	for i = 1, LADDER_SLOTS do
		line.ladderBars[i] = keep(line:CreateTexture(nil, "ARTWORK"))
		line.ladderWords[i] = text("GameFontDisableSmall")
		line.ladderEntries[i] = text("GameFontHighlightSmall")
	end
	line.ladderMarks = { keep(line:CreateTexture(nil, "OVERLAY")), keep(line:CreateTexture(nil, "OVERLAY")) }

	line.roundCards = {}
	for c = 1, CARD_SLOTS do
		local card = {}
		card.bg = keep(line:CreateTexture(nil, "BACKGROUND"))
		card.edge = keep(line:CreateTexture(nil, "BORDER"))
		card.title = text("GameFontDisableSmall")
		card.word = text("GameFontDisableSmall", "RIGHT")
		card.rule = keep(line:CreateTexture(nil, "ARTWORK"))
		card.names, card.icons = {}, {}
		for n = 1, CARD_NAMES + 1 do
			card.icons[n] = keep(line:CreateTexture(nil, "ARTWORK"))
			card.names[n] = text("GameFontHighlightSmall")
		end
		line.roundCards[c] = card
	end



	line.lobbyIcon = keep(line:CreateTexture(nil, "ARTWORK"))
	line.legendMarks = {
		keep(line:CreateTexture(nil, "ARTWORK")), keep(line:CreateTexture(nil, "ARTWORK")),
	}
	line.legendBox = outline(line)
	for i = 1, 4 do
		keep(line.legendBox[i])
	end
	line.legendWords = { text("GameFontDisableSmall"), text("GameFontDisableSmall"), text("GameFontDisableSmall") }



	for _, parts in pairs(line.lobbyRounds or {}) do
		parts.box = outline(line)
		for i = 1, 4 do
			keep(parts.box[i])
		end
	end
end





function A.matchHeadGame()
	return A.theme() ~= "flat"
end



local function detailText(h, skipPlace)
	local parts = {}
	for _, part in ipairs(h.details or {}) do
		if not (skipPlace and part.place) then
			parts[#parts + 1] = A.colorEscape(part.tone or "dim") .. part.text .. "|r"
		end
	end
	return table.concat(parts, " " .. A.colorEscape("dimmer") .. A.HEAD_DOT .. "|r ")
end



local function ratingsText(h)
	if h.ratingFrom == nil or h.ratingTo == nil then
		return ""
	end
	local function rating(text, fallback)
		local value = tonumber(text)
		if value == nil then
			return A.colorEscape(fallback) .. text .. "|r"
		end
		local _, _, reason = A.ratingColour(h.format, value)
		if reason == "unheard" then
			A.ratingAsk()
		end
		return A.tierRatingText(h.format, value, fallback)
	end
	return ("%s %s%s|r %s"):format(rating(h.ratingFrom, "dim"), A.colorEscape("dimmer"),
		A.HEAD_ARROW, rating(h.ratingTo, "bright"))
end




local function paintChip(line, h, width, game)
	if h.chipWhy == "unheard" then
		A.ratingAsk()
	end
	local right = width - A.metric("rowCellGap")
	if h.mmr then
		local text = "mmr " .. h.mmr
		A.style(line.headMmr, "numberSmall", "dim")
		line.headMmr:SetText(text)
		line.headMmr:ClearAllPoints()
		line.headMmr:SetPoint("RIGHT", line, "LEFT", right, 0)
		line.headMmr:Show()
		right = right - A.textRoom(line.headMmr, text) - A.metric("headGap")
	end
	local chip = h.chip
	if chip then
		local word = chip.word .. (chip.reached and " reached" or "")
		if not game then
			word = word:upper()
		end
		local pad = A.metric("headChipPad")
		A.style(line.headChipText, "label", "text")
		line.headChipText:SetTextColor(chip.r, chip.g, chip.b, 1)
		line.headChipText:SetText(word)
		local room = A.textRoom(line.headChipText, word)
		local w, ht = room + pad * 2, A.fontSize("label") + pad
		local x = right - w
		line.headChipText:ClearAllPoints()
		line.headChipText:SetPoint("LEFT", line, "LEFT", x + pad, 0)
		line.headChipText:SetWidth(room)
		line.headChipText:Show()

		local edges = { { x, ht / 2, w, 1 }, { x, -ht / 2, w, 1 }, { x, 0, 1, ht }, { x + w - 1, 0, 1, ht } }
		for i = 1, 4 do
			local edge, at = line.headChip[i], edges[i]
			edge:ClearAllPoints()
			edge:SetPoint("LEFT", line, "LEFT", at[1], at[2])
			edge:SetSize(at[3], at[4])
			edge:SetColorTexture(chip.r, chip.g, chip.b, 1)
			edge:Show()
		end
		right = x - A.metric("headGap")
	end
	return right
end




local function paintPips(line, h, after)
	local pips = h.pips or {}
	local count = type(pips.n) == "number" and pips.n or 0
	local width, height, gap = A.metric("headPipWidth"), A.metric("headPipHeight"), A.metric("headPipGap")
	for i = 1, #line.headPips do
		local pip = line.headPips[i]
		if i <= count then
			pip:ClearAllPoints()
			pip:SetPoint("LEFT", after, "RIGHT", A.metric("headGap") + (i - 1) * (width + gap), 0)
			pip:SetSize(width, height)
			local tone = pips[i] == true and "win" or pips[i] == false and "dimmer" or "dim"
			local r, g, b = A.color(tone)
			pip:SetColorTexture(r, g, b, 1)
			pip:Show()
		end
	end
end





local function paintHeading(line, h, paintCrest, game)
	if game then
		line.headCrest:Hide()
		line.bannerBg:SetAllPoints(line)
		line.bannerBg:SetColorTexture(A.color("panelDeep"))
		line.bannerBg:Show()
		local pad = A.metric("bannerPad")
		A.style(line.bannerVerdict, "headingLarge", h.resultTone or "text")
		line.bannerVerdict:SetText(h.result or "")
		line.bannerVerdict:ClearAllPoints()
		line.bannerVerdict:SetPoint("BOTTOMRIGHT", line, "BOTTOMRIGHT", -pad, pad)
		line.bannerVerdict:Show()
		A.style(line.bannerPlace, "heading", "bright")
		line.bannerPlace:SetText(h.place or "")
		line.bannerPlace:ClearAllPoints()
		line.bannerPlace:SetPoint("TOPLEFT", line, "TOPLEFT", pad, -pad)
		line.bannerPlace:SetPoint("RIGHT", line.bannerVerdict, "LEFT", -A.metric("headGap"), 0)
		line.bannerPlace:Show()
		A.style(line.bannerNote, "note", "dim")
		line.bannerNote:SetText(detailText(h, true))
		line.bannerNote:ClearAllPoints()
		line.bannerNote:SetPoint("BOTTOMLEFT", line, "BOTTOMLEFT", pad, pad)
		line.bannerNote:SetPoint("RIGHT", line.bannerVerdict, "LEFT", -A.metric("headGap"), 0)
		line.bannerNote:Show()
		return
	end

	line.headResult:Show()
	paintCrest(line, h.faction)
	A.style(line.headResult, "headingLarge", h.resultTone or "text")
	line.headResult:SetText(h.result or "")
	paintPips(line, h, line.headResult)

	line.headDelta:ClearAllPoints()
	line.headDelta:SetPoint("RIGHT", line, "RIGHT", -A.metric("rowCellGap"), 0)
	A.style(line.headDelta, "number", h.deltaTone or "dim")
	line.headDelta:SetText(h.delta or "")
	line.headDelta:Show()
	line.headRatings:ClearAllPoints()
	line.headRatings:SetPoint("RIGHT", line.headDelta, "LEFT", -A.metric("headGap"), 0)
	A.style(line.headRatings, "numberSmall", "dim")
	line.headRatings:SetText(ratingsText(h))
	line.headRatings:Show()
end




local function paintHeadline(line, h, game)
	local width = type(h.available) == "number" and h.available or A.detailWindowBody()
	local left = paintChip(line, h, width, game)
	if game then
		line.headRatings:ClearAllPoints()
		line.headRatings:SetPoint("LEFT", line, "LEFT", A.metric("rowCellGap"), 0)
		A.style(line.headRatings, "numberSmall", "dim")
		line.headRatings:SetText(ratingsText(h))
		line.headRatings:Show()
		line.headDelta:ClearAllPoints()
		line.headDelta:SetPoint("LEFT", line.headRatings, "RIGHT", A.metric("headGap"), 0)
		A.style(line.headDelta, "number", h.deltaTone or "dim")
		line.headDelta:SetText(h.delta or "")
		line.headDelta:Show()
		return
	end
	A.style(line.headDetails, "bodyText", "dim")
	line.headDetails:SetText(detailText(h, false))
	line.headDetails:ClearAllPoints()
	line.headDetails:SetPoint("LEFT", line, "LEFT", 0, 0)
	line.headDetails:SetWidth(math.max(1, left))
	line.headDetails:SetJustifyH("LEFT")
	line.headDetails:Show()
end


local function ladderX(ladder, rating, width)
	local share = (rating - ladder.low) / (ladder.high - ladder.low)
	if share < 0 then
		share = 0
	elseif share > 1 then
		share = 1
	end
	return math.floor(share * width + 0.5)
end





local function paintLadder(line, h)
	local ladder = h.ladder
	local width = type(h.available) == "number" and h.available or A.detailWindowBody()
	local pad, bar, gap = A.metric("ladderPad"), A.metric("ladderBar"), A.metric("ladderGap")
	local top = -(pad + (A.metric("ladderMark") - bar) / 2)
	for i = 1, #line.ladderBars do
		local held = ladder.bars[i]
		if held then
			local x = ladderX(ladder, held.entry, width)
			local right = ladderX(ladder, held.upper, width)
			local w = math.max(1, right - x - gap)
			local dr, dg, db = A.color("dim")
			local r, g, b = held.r or dr, held.g or dg, held.b or db
			local barTex = line.ladderBars[i]
			barTex:ClearAllPoints()
			barTex:SetPoint("TOPLEFT", line, "TOPLEFT", x, top)
			barTex:SetSize(w, bar)
			barTex:SetColorTexture(r, g, b, held.here and 1 or 0.35)
			barTex:Show()
			local word, entry = line.ladderWords[i], line.ladderEntries[i]
			A.style(word, "label", "text")
			word:SetTextColor(r, g, b, 1)
			word:SetAlpha(held.here and 1 or 0.7)
			word:SetText(held.word or "")
			word:ClearAllPoints()
			word:SetPoint("TOPLEFT", line, "TOPLEFT", x, top - bar - gap - (A.metric("ladderMark") - bar) / 2)
			word:Show()
			A.style(entry, "numberSmall", "dim")
			entry:SetText(tostring(held.entry))
			entry:ClearAllPoints()
			entry:SetPoint("LEFT", word, "RIGHT", A.metric("headCrestGap"), 0)
			entry:Show()
		end
	end
	local marks = { { ladder.from, "dim" }, { ladder.to, "bright" } }
	for i = 1, 2 do
		local mark = line.ladderMarks[i]
		mark:ClearAllPoints()
		mark:SetPoint("TOPLEFT", line, "TOPLEFT", ladderX(ladder, marks[i][1], width) - 1, -pad)
		mark:SetSize(2, A.metric("ladderMark"))
		mark:SetColorTexture(A.color(marks[i][2]))
		mark:Show()
	end
end



local function paintCardName(card, n, x, y, width, label, classToken, spec, faint)
	local size = A.metric("compSwatch")
	local icon, name = card.icons[n], card.names[n]
	local found = type(A.specIcon) == "function" and A.specIcon(classToken, spec) or nil
	icon:ClearAllPoints()
	icon:SetPoint("TOPLEFT", card.bg, "TOPLEFT", x, y - (A.fontSize("note") - size) / 2)
	icon:SetSize(size, size)
	if found ~= nil then
		icon:SetVertexColor(1, 1, 1, 1)
		icon:SetTexture(found)
	else
		icon:SetColorTexture(A.classColor(classToken))
	end
	icon:SetAlpha(faint and 0.6 or 1)
	icon:Show()
	A.style(name, "note", "text")
	name:SetTextColor(A.classColor(classToken))
	name:SetAlpha(faint and 0.6 or 1)
	name:SetText(label)
	name:ClearAllPoints()
	name:SetPoint("TOPLEFT", card.bg, "TOPLEFT", x + size + A.metric("headCrestGap"), y)
	name:SetWidth(math.max(1, width - size - A.metric("headCrestGap")))
	name:Show()
end


local function shortName(cell)
	local name = tostring(cell.name or "-")
	return name:match("^([^%-]+)") or name
end



local function paintCards(line, h)
	local cards = h.cards or {}
	local width = type(h.available) == "number" and h.available or A.detailWindowBody()
	local gap, pad = A.metric("roundCardGap"), A.metric("roundCardPad")
	local count = math.min(#cards, #line.roundCards)
	local cardWidth = count > 0 and math.floor((width - gap * (count - 1)) / count) or 0
	local step = A.fontSize("note") + A.metric("roundCardLine")
	local height = A.roundCardsHeight(cards)
	for c = 1, count do
		local card, held = line.roundCards[c], cards[c]
		local x = (c - 1) * (cardWidth + gap)
		card.bg:ClearAllPoints()
		card.bg:SetPoint("TOPLEFT", line, "TOPLEFT", x, 0)
		card.bg:SetSize(cardWidth, height)
		card.bg:SetColorTexture(A.color("panelDeep"))
		card.bg:Show()
		card.edge:ClearAllPoints()
		card.edge:SetPoint("TOPLEFT", card.bg, "TOPLEFT", 0, 0)
		card.edge:SetSize(cardWidth, A.metric("roundCardEdge"))
		card.edge:SetColorTexture(A.color(held.tone))
		card.edge:Show()
		local y = -(A.metric("roundCardEdge") + pad)
		A.style(card.title, "label", "dim")
		card.title:SetText(("R%d"):format(held.n))
		card.title:ClearAllPoints()
		card.title:SetPoint("TOPLEFT", card.bg, "TOPLEFT", pad, y)
		card.title:Show()
		A.style(card.word, "label", held.tone)
		card.word:SetText(held.word)
		card.word:ClearAllPoints()
		card.word:SetPoint("TOPRIGHT", card.bg, "TOPRIGHT", -pad, y)
		card.word:Show()
		y = y - A.fontSize("label") - A.metric("roundCardLine")
		local inner = cardWidth - pad * 2
		local n = 1
		paintCardName(card, n, pad, y, inner, "You", held.classToken, held.spec, false)
		for _, cell in ipairs(held.mates) do
			n, y = n + 1, y - step
			paintCardName(card, n, pad, y, inner, shortName(cell), cell.classToken, cell.spec, false)
		end
		y = y - step + A.metric("roundCardLine")
		card.rule:ClearAllPoints()
		card.rule:SetPoint("TOPLEFT", card.bg, "TOPLEFT", pad, y)
		card.rule:SetSize(inner, 1)
		card.rule:SetColorTexture(A.color("hairline"))
		card.rule:SetShown(#held.mates + #held.foes > 0)
		y = y - A.metric("roundCardLine")
		for _, cell in ipairs(held.foes) do
			n = n + 1
			paintCardName(card, n, pad, y, inner, shortName(cell), cell.classToken, cell.spec, true)
			y = y - step
		end
	end
end


function A.paintMatchHead(line, h, paintCrest)
	local game = A.matchHeadGame()
	if h.kind == "heading" then
		paintHeading(line, h, paintCrest, game)
	elseif h.kind == "headline" then
		paintHeadline(line, h, game)
	elseif h.kind == "ladder" and type(h.ladder) == "table" then
		paintLadder(line, h)
	elseif h.kind == "cards" then
		paintCards(line, h)
	end
end









function A.paintRoundCellMark(line, parts, cell, x, width, word, result)
	local typed = type(word) == "string" and word:sub(-1) == "*"
	local bare = typed and word:sub(1, -2) or word
	local size = A.metric("roundCellMark")
	local left = x + math.floor((width - size) / 2)
	local top = -math.floor((A.metric("rowHeight") - size) / 2)
	parts.ground:Hide()
	for i = 1, 4 do
		parts.box[i]:Hide()
	end
	local tone = nil
	if bare == "WITH" then
		tone = result == true and "win" or (result == false and "loss" or "dimmer")
	elseif bare == "WON" then
		tone = "win"
	elseif bare == "LOST" then
		tone = "loss"
	end
	cell:SetText("")
	if tone then
		parts.ground:ClearAllPoints()
		parts.ground:SetPoint("TOPLEFT", line, "TOPLEFT", left, top)
		parts.ground:SetSize(size, size)
		parts.ground:SetColorTexture(A.color(tone))
		parts.ground:Show()
		if typed then
			A.style(cell, "bodyText", "dim")
			cell:SetText("*")
			cell:SetJustifyH("RIGHT")
		end
	elseif bare == "VS" then
		local r, g, b = A.color("dimmer")
		placeOutline(parts.box, line, left, top, size, size, r, g, b, 1)
	else
		A.style(cell, "bodyText", "dimmer")
		cell:SetText(word or "-")
	end
	cell:Show()
	return tone or (bare == "VS" and "outline") or "dash"
end



function A.paintNameIcon(line, cell, x, width, classToken, spec)
	local size = A.metric("compSwatch")
	local icon = type(A.specIcon) == "function" and A.specIcon(classToken, spec) or nil
	line.lobbyIcon:ClearAllPoints()
	line.lobbyIcon:SetPoint("LEFT", line, "LEFT", x, 0)
	line.lobbyIcon:SetSize(size, size)
	if icon ~= nil then
		line.lobbyIcon:SetVertexColor(1, 1, 1, 1)
		line.lobbyIcon:SetTexture(icon)
	else
		line.lobbyIcon:SetColorTexture(A.classColor(classToken))
	end
	line.lobbyIcon:Show()
	local shift = size + A.metric("headCrestGap")
	cell:ClearAllPoints()
	cell:SetPoint("LEFT", line, "LEFT", x + shift, 0)
	cell:SetWidth(math.max(1, width - shift))
	return icon ~= nil
end


local LEGEND = { "on your side, won", "on your side, lost", "against you" }



function A.paintRoundLegend(line)
	local size = A.metric("roundCellMark")
	local top = -math.floor((A.metric("rowHeight") - size) / 2)
	local x = 0
	for i = 1, 3 do
		if i < 3 then
			local mark = line.legendMarks[i]
			mark:ClearAllPoints()
			mark:SetPoint("TOPLEFT", line, "TOPLEFT", x, top)
			mark:SetSize(size, size)
			mark:SetColorTexture(A.color(i == 1 and "win" or "loss"))
			mark:Show()
		else
			local r, g, b = A.color("dimmer")
			placeOutline(line.legendBox, line, x, top, size, size, r, g, b, 1)
		end
		local word = line.legendWords[i]
		A.style(word, "note", "dim")
		word:SetText(LEGEND[i])
		word:ClearAllPoints()
		word:SetPoint("LEFT", line, "LEFT", x + size + A.metric("headCrestGap"), 0)
		word:Show()
		x = x + size + A.metric("headCrestGap") + A.textRoom(word, LEGEND[i]) + A.metric("headGap") * 2
	end
	return x
end







function A.traceMatchHead(id, rows, height)
	if type(A.trace) ~= "function" then
		return false
	end
	local heading, headline, ladder, cards = nil, nil, nil, false
	for _, row in ipairs(type(rows) == "table" and rows or {}) do
		local h = type(row) == "table" and row.head or nil
		if type(h) == "table" then
			if h.kind == "heading" then
				heading = h
			elseif h.kind == "headline" then
				headline = h
			elseif h.kind == "ladder" then
				ladder = h.ladder
			elseif h.kind == "cards" then
				cards = true
			end
		end
	end
	local parts = heading or headline or {}
	local chip = parts.chip
	A.trace("match-head", {
		id = id,
		verdict = parts.result or "none",
		chip = chip and chip.word or parts.chipWhy or "no-head",
		reached = chip ~= nil and chip.reached == true,
		markFrom = ladder and ladder.from or "none",
		markTo = ladder and ladder.to or "none",
		cards = cards,
		height = height,
	}, "ui")
	return true
end
