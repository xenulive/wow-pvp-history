

























local _, A = ...





local COUNT_MIN, COUNT_MAX, COUNT_DEFAULT = 4, 10, 5


local OPACITY_MIN, OPACITY_MAX, OPACITY_STEP, OPACITY_DEFAULT = 0, 100, 10, 70






local DEFAULT_POINT, DEFAULT_X, DEFAULT_Y = "TOP", 0, -72






local PAD, SQUARE, DELTA_GAP, CELL_GAP, BLOCK_GAP = 6, 30, 2, 5, 10
local LINE_GAP, TODAY_GAP = 1, 6





local TITLE_TEXT = "PVP HISTORY"
local TITLE_GAP, RULE_GAP, RULE_SHORT = 2, 2, 12


local DELTA_FLOOR_TEXT = "+999"





local frame
local cells = {}


local previewUp = false




local previewFormat
local previewOpacity



local hovered



local inCombat = false



local last = { state = "hidden", ids = {} }












local painted



local midnightCall = 0





local function clamp(value, min, max)
	local figure = tonumber(value)
	if figure == nil or figure ~= figure or figure == math.huge or figure == -math.huge then
		return nil
	end
	if figure < min then
		return min
	end
	if figure > max then
		return max
	end
	return figure
end



local function whole(value)
	if type(value) ~= "number" then
		return nil
	end
	return math.floor(value + 0.5)
end








function A.overlayEnabled()
	local db = A.db()
	if not db or type(db.ui) ~= "table" then
		return false
	end
	return db.ui.overlayShown == true
end





function A.setOverlay(enabled)
	local db = A.db()
	if not db then
		return false
	end
	db.ui = db.ui or {}
	if enabled == true then
		db.ui.overlayShown = true
	else
		db.ui.overlayShown = nil
	end
	if A.notifyOverlaySetting then
		A.notifyOverlaySetting()
	end
	A.overlayRepaint("setting", "shown")
	return true
end





function A.overlayCount()
	local db = A.db()
	if not db or type(db.ui) ~= "table" then
		return COUNT_DEFAULT
	end
	local figure = clamp(db.ui.overlayCount, COUNT_MIN, COUNT_MAX)
	if figure == nil then
		return COUNT_DEFAULT
	end
	return math.floor(figure)
end



function A.overlayCountRange()
	return COUNT_MIN, COUNT_MAX, 1, COUNT_DEFAULT
end



function A.setOverlayCount(value)
	local db = A.db()
	if not db then
		return false
	end
	local figure = clamp(value, COUNT_MIN, COUNT_MAX)
	if figure == nil then
		return false
	end
	local want = math.floor(figure)
	db.ui = db.ui or {}
	db.ui.overlayCount = want ~= COUNT_DEFAULT and want or nil
	if A.refreshOptionsWindow then
		pcall(A.refreshOptionsWindow)
	end
	A.overlayRepaint("setting", "count")
	return true
end






function A.overlayOpacity()
	local db = A.db()
	if not db or type(db.ui) ~= "table" then
		return OPACITY_DEFAULT
	end
	local figure = clamp(db.ui.overlayOpacity, OPACITY_MIN, OPACITY_MAX)
	if figure == nil then
		return OPACITY_DEFAULT
	end
	return math.floor(figure / OPACITY_STEP + 0.5) * OPACITY_STEP
end


function A.overlayOpacityRange()
	return OPACITY_MIN, OPACITY_MAX, OPACITY_STEP, OPACITY_DEFAULT
end




function A.setOverlayOpacity(value)
	local db = A.db()
	if not db then
		return false
	end
	local figure = clamp(value, OPACITY_MIN, OPACITY_MAX)
	if figure == nil then
		return false
	end
	local want = math.floor(figure / OPACITY_STEP + 0.5) * OPACITY_STEP
	db.ui = db.ui or {}
	db.ui.overlayOpacity = want ~= OPACITY_DEFAULT and want or nil
	if A.refreshOptionsWindow then
		pcall(A.refreshOptionsWindow)
	end
	A.overlayRepaint("setting", "opacity")
	return true
end





function A.overlayCombat()
	local db = A.db()
	if not db or type(db.ui) ~= "table" then
		return true
	end
	return db.ui.overlayCombat ~= false
end


function A.setOverlayCombat(enabled)
	local db = A.db()
	if not db then
		return false
	end
	db.ui = db.ui or {}
	if enabled == false then
		db.ui.overlayCombat = false
	else
		db.ui.overlayCombat = nil
	end
	if A.refreshOptionsWindow then
		pcall(A.refreshOptionsWindow)
	end
	A.overlayRepaint("setting", "combat")
	return true
end









function A.overlayPosition()
	local db = A.db()
	if not db or type(db.ui) ~= "table" then
		return nil
	end
	local held = db.ui.overlayPosition
	if type(held) ~= "table" or type(held.point) ~= "string" then
		return nil
	end
	local x, y = whole(held.x), whole(held.y)
	if x == nil or y == nil then
		return nil
	end
	return { point = held.point, x = x, y = y }
end




function A.setOverlayPosition(geometry)
	local db = A.db()
	if not db then
		return false
	end
	db.ui = db.ui or {}
	local point = type(geometry) == "table" and geometry.point or nil
	local x = type(geometry) == "table" and whole(geometry.x) or nil
	local y = type(geometry) == "table" and whole(geometry.y) or nil
	if type(point) ~= "string" or x == nil or y == nil
		or (point == DEFAULT_POINT and x == DEFAULT_X and y == DEFAULT_Y)
	then
		db.ui.overlayPosition = nil
		return true
	end
	db.ui.overlayPosition = { point = point, x = x, y = y }
	return true
end


local function placeAt(made)
	local stored = A.overlayPosition()
	local point = stored and stored.point or DEFAULT_POINT
	local x = stored and stored.x or DEFAULT_X
	local y = stored and stored.y or DEFAULT_Y
	pcall(made.ClearAllPoints, made)
	pcall(made.SetPoint, made, point, UIParent, point, x, y)
end






local function recordById(id)
	local db = A.db()
	if id == nil or not (db and type(db.matches) == "table") then
		return nil
	end
	for i = 1, #db.matches do
		local record = db.matches[i]
		if type(record) == "table" and record.id == id then
			return record
		end
	end
	return nil
end



local SANDBOX_READER = "the sandbox's generated character"







function A.barCharacter()
	if A.sandboxed() then
		return SANDBOX_READER
	end
	return A.ownGuid()
end






function A.barRecorder(character)
	if character == SANDBOX_READER then
		return nil
	end
	return character
end





local function newestOf(format, character, count)
	local rows = {}
	local db = A.db()
	if not (db and type(db.matches) == "table") then
		return rows
	end
	local recorder = A.barRecorder(character)
	for i = 1, #db.matches do
		local record = db.matches[i]
		if type(record) == "table" and record.format == format
			and A.recordedBy(record, recorder) and A.recordEpoch(record) ~= nil then
			rows[#rows + 1] = record
		end
	end
	table.sort(rows, function(a, b)
		local at, bt = A.recordEpoch(a), A.recordEpoch(b)
		if at ~= bt then
			return at > bt
		end


		local ak, an = A.matchIdRank(a.id)
		local bk, bn = A.matchIdRank(b.id)
		if ak ~= bk then
			return ak > bk
		end
		return an > bn
	end)
	for i = #rows, count + 1, -1 do
		rows[i] = nil
	end
	return rows
end






local function subject()
	local character = A.barCharacter()
	if character == nil then
		return nil, nil, {}
	end
	if previewFormat ~= nil then
		local rows = newestOf(previewFormat, character, A.overlayCount())
		if #rows == 0 then
			return character, nil, rows
		end
		return character, previewFormat, rows
	end

	local newest = A.lastMatch(nil, nil, A.barRecorder(character), nil, true)
	if newest == nil then
		return character, nil, {}
	end
	return character, newest.format, newestOf(newest.format, character, A.overlayCount())
end







local function dayOf(record)
	return A.dayKey(record.openedAt or record.completedAt or record.endedAt)
end


local function todaysMatches(format, character)
	local out = {}
	local db = A.db()
	local today = A.dayKey(A.stamp())
	if today == nil or not (db and type(db.matches) == "table") then
		return out
	end
	for i = 1, #db.matches do
		local record = db.matches[i]
		if type(record) == "table" and record.format == format and A.recordedBy(record, A.barRecorder(character))
			and dayOf(record) == today then
			out[#out + 1] = record
		end
	end
	return out
end






















function A.todayFigures(format, character)
	if format == nil or character == nil then
		return nil
	end
	local list = todaysMatches(format, character)
	local figures = { n = #list, changeN = 0, decided = 0 }

	if A.movesRating(format) then
		local summary = A.summarize(format, nil, A.barRecorder(character))
		local rating = type(summary) == "table" and tonumber(summary.rating) or nil
		if rating ~= nil then
			figures.rating = math.floor(rating)
		end
		local sum = 0
		for i = 1, #list do
			local record = list[i]
			if A.ratingDelta(record) ~= nil then
				local own = record.participants[record.character]
				sum = sum + own.ratingChange
				figures.changeN = figures.changeN + 1
			end
		end
		if #list == 0 or figures.changeN > 0 then
			if sum > 0 then
				figures.change, figures.changeTone = ("%+d"):format(sum), "win"
			elseif sum < 0 then
				figures.change, figures.changeTone = ("%+d"):format(sum), "loss"
			else
				figures.change, figures.changeTone = "0", "dim"
			end
		end
	end

	local tally = { wins = 0, decided = 0, draws = 0 }
	for i = 1, #list do
		local outcome, _, derived = A.recordVerdict(list[i])
		if outcome ~= nil then
			tally.decided = tally.decided + 1
			if A.recordLevel(list[i], outcome, derived) then
				tally.draws = tally.draws + 1
			end
			if outcome == "win" then
				tally.wins = tally.wins + 1
			end
		end
	end
	figures.decided = tally.decided
	figures.record = A.winRecordText(tally, format)
	if figures.record ~= nil then
		local _, _, _, rate = A.winRecord(tally)
		figures.recordTone = A.winRateTone(rate) or "dim"
	end
	return figures
end




function A.ratingTint(format, rating)
	local _, _, reason, r, g, b = A.ratingColour(format, rating)
	if reason == "unheard" then
		A.ratingAsk()
	end
	if r ~= nil then
		return r, g, b
	end
	local br, bg, bb = A.color("bright")
	return br, bg, bb
end












local function secondLine(format, character)
	local figures = A.todayFigures(format, character)
	if figures == nil then
		return nil
	end
	if A.movesRating(format) then
		local change = figures.change ~= "0" and figures.change or nil
		local line = { todayN = figures.changeN, rating = figures.rating, today = change,
			todayTone = change and figures.changeTone or nil }
		if figures.rating ~= nil then
			line.primary = tostring(figures.rating)
		end
		if line.primary == nil and line.today == nil then
			return nil
		end
		return line
	end


	if figures.record == nil then
		return nil
	end
	return { primary = figures.record, primaryTone = "text", today = figures.record, todayN = figures.decided }
end






local function columnWidth()
	local floor = A.headerFloor(DELTA_FLOOR_TEXT)
	if floor > SQUARE then
		return floor
	end
	return SQUARE
end


local function tileHeight()
	return SQUARE + DELTA_GAP + A.fontSize("numberSmall")
end



local function blockHeight(withLine)
	local height = A.fontSize("label") + TITLE_GAP + 1 + RULE_GAP + A.fontSize("label")
	if withLine then
		height = height + LINE_GAP + A.fontSize("number")
	end
	return height
end



local function barHeight()
	local tiles, block = tileHeight(), blockHeight(true)
	if block > tiles then
		return PAD * 2 + block
	end
	return PAD * 2 + tiles
end


local function centredTop(own)
	return math.floor((barHeight() - own) / 2)
end



local function ratingLine(record, head)
	if type(head) ~= "table" or head.ratingFrom == nil or head.ratingTo == nil then
		return nil
	end
	local from, to = tonumber(head.ratingFrom), tonumber(head.ratingTo)

	local _, _, reason = A.ratingColour(record.format, to)
	if reason == "unheard" then
		A.ratingAsk()
	end
	local line = A.tierRatingText(record.format, from, "bright") .. " " .. A.colorEscape("dim") .. "to|r "
		.. A.tierRatingText(record.format, to, "bright")
	if head.delta ~= nil then
		line = line .. " " .. A.colorEscape(head.deltaTone or "dim") .. head.delta .. "|r"
	end
	return line
end







local function whenLine(record)
	local parts = {}
	local day = A.dayText(record.openedAt) or A.dayText(record.completedAt)
	if day ~= nil then
		parts[#parts + 1] = day
	end
	local length = A.lengthText(record.duration)
	if length ~= nil then
		parts[#parts + 1] = length
	end
	local season = A.seasonText(record, true)
	if season ~= nil then
		parts[#parts + 1] = season
	end
	if #parts == 0 then
		return nil
	end
	return table.concat(parts, "  ")
end





local function hoverAnchor(cell)
	return {
		point = "TOP", relativeTo = cell.delta, relativePoint = "BOTTOM", x = 0, y = -DELTA_GAP,
		name = "change",
		flip = { point = "BOTTOM", relativeTo = cell.square, relativePoint = "TOP", x = 0, y = DELTA_GAP,
			name = "square" },
	}
end





local function hover(cell)
	hovered = { id = cell.matchId, text = cell.letterText }
	local record = recordById(cell.matchId)
	if record == nil then
		return false
	end
	local ok, lines, _, _, heads = pcall(A.detailLines, record)
	if not ok or type(lines) ~= "table" or type(heads) ~= "table" then
		return false
	end
	local out = {}
	local headline
	for i = 1, #lines do
		local head = heads[i]
		if type(head) == "table" and head.kind == "headline" and type(lines[i]) == "string" then
			out[#out + 1] = (lines[i]:gsub("^%s+", ""))
			headline = head
			break
		end
	end
	if #out == 0 then
		return false
	end
	local when = whenLine(record)
	if when ~= nil then
		out[#out + 1] = when
	end
	local rated = ratingLine(record, headline)
	if rated ~= nil then
		out[#out + 1] = rated
	end
	return A.keyedTooltip(cell, out, hoverAnchor(cell))
end


local function cellAt(i)
	local held = cells[i]
	if held then
		return held
	end
	held = CreateFrame("Button", nil, frame)
	held:SetSize(columnWidth(), tileHeight())

	held.square = held:CreateTexture(nil, "ARTWORK")
	held.square:SetSize(SQUARE, SQUARE)
	held.square:SetPoint("TOP", held, "TOP", 0, 0)


	held.letter = held:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	held.letter:SetPoint("CENTER", held.square, "CENTER", 0, 0)
	held.letter:SetJustifyH("CENTER")
	held.letter:SetWordWrap(false)

	held.delta = held:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
	held.delta:SetPoint("TOP", held.square, "BOTTOM", 0, -DELTA_GAP)
	held.delta:SetWidth(columnWidth())
	held.delta:SetJustifyH("CENTER")
	held.delta:SetWordWrap(false)



	held:SetScript("OnClick", function(self)
		if self.matchId ~= nil then
			A.showMatchWindow("match", self.matchId, "overlay")
		end
	end)
	held:SetScript("OnEnter", function(self)
		hover(self)
	end)
	held:SetScript("OnLeave", function()
		A.hideTooltip()
	end)
	held:Hide()
	cells[i] = held
	return held
end


local function build()
	if frame then
		return frame
	end
	if type(CreateFrame) ~= "function" or UIParent == nil then
		return nil
	end
	local made = CreateFrame("Frame", "WowPvpHistoryOverlay", UIParent)
	made:SetFrameStrata("MEDIUM")
	made:SetClampedToScreen(true)
	made:SetMovable(true)
	made:EnableMouse(true)
	made:RegisterForDrag("LeftButton")
	made:SetSize(columnWidth(), barHeight())
	made:SetPoint(DEFAULT_POINT, UIParent, DEFAULT_POINT, DEFAULT_X, DEFAULT_Y)


	A.registerPlacedWindow(made, DEFAULT_POINT, DEFAULT_X, DEFAULT_Y)
	made:Hide()


	made.ground = made:CreateTexture(nil, "BACKGROUND")
	made.ground:SetAllPoints(made)



	made.title = made:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
	made.title:SetJustifyH("LEFT")
	made.title:SetWordWrap(false)
	made.rule = made:CreateTexture(nil, "ARTWORK")


	made.label = made:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
	made.label:SetJustifyH("LEFT")
	made.label:SetWordWrap(false)


	made.rating = made:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
	made.rating:SetJustifyH("LEFT")
	made.rating:SetWordWrap(false)
	made.today = made:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
	made.today:SetJustifyH("LEFT")
	made.today:SetWordWrap(false)


	made.divider = made:CreateTexture(nil, "ARTWORK")

	made:SetScript("OnDragStart", function(self)
		pcall(self.StartMoving, self)
	end)
	made:SetScript("OnDragStop", function(self)
		pcall(self.StopMovingOrSizing, self)



		local read = A.frameGeometry(self)
		if read and read.point then
			A.setOverlayPosition(read)
		end

		local stored = A.overlayPosition()
		A.trace("overlay/move", {
			point = read and read.point or nil,
			x = read and whole(read.x) or nil,
			y = read and whole(read.y) or nil,
			state = stored ~= nil and "stored" or "default",
		}, "ui")
	end)

	frame = made
	placeAt(made)
	return made
end



local function drawnOpacity()
	if previewOpacity ~= nil then
		return previewOpacity
	end
	return A.overlayOpacity()
end



local function tintRating(fontString, format, rating)
	local r, g, b = A.ratingTint(format, rating)
	fontString:SetTextColor(r, g, b)
end





local function nameFloor()
	local widest = 0
	local names = type(A.formatLabelList) == "function" and A.formatLabelList() or {}
	for i = 1, #names do
		local need = A.headerFloor(names[i])
		local drawn = A.textRoom(frame.label, names[i])
		if drawn > need then
			need = drawn
		end
		if need > widest then
			widest = need
		end
	end
	return widest
end












local function paintBlock(text, tone, format, line, floored)
	frame.title:SetText(TITLE_TEXT)
	A.style(frame.title, "label", "accent")
	local titleWidth = A.headerFloor(TITLE_TEXT)
	frame.title:SetWidth(titleWidth)
	frame.title:ClearAllPoints()
	frame.title:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD, -centredTop(blockHeight(line ~= nil)))
	frame.title:Show()

	frame.rule:ClearAllPoints()
	frame.rule:SetPoint("TOPLEFT", frame.title, "BOTTOMLEFT", 0, -TITLE_GAP)
	frame.rule:SetColorTexture(A.color("accent"))
	frame.rule:Show()

	frame.label:SetText(text)
	A.style(frame.label, "label", tone)


	local labelWidth = A.headerFloor(text)
	frame.label:SetWidth(labelWidth)
	frame.label:ClearAllPoints()
	frame.label:SetPoint("TOPLEFT", frame.rule, "BOTTOMLEFT", 0, -RULE_GAP)
	if floored then
		local floor = nameFloor()
		if floor > labelWidth then
			labelWidth = floor
		end
	end
	if titleWidth > labelWidth then
		labelWidth = titleWidth
	end


	local function finish(blockWidth)
		local ruleWidth = blockWidth + BLOCK_GAP - RULE_SHORT
		frame.rule:SetSize(ruleWidth, 1)
		return blockWidth, ruleWidth
	end

	if line == nil then
		frame.rating:SetText("")
		frame.rating:Hide()
		frame.today:SetText("")
		frame.today:Hide()
		return finish(labelWidth)
	end

	local lineWidth = 0
	frame.rating:ClearAllPoints()
	frame.rating:SetPoint("TOPLEFT", frame.label, "BOTTOMLEFT", 0, -LINE_GAP)
	if line.primary ~= nil then
		frame.rating:SetText(line.primary)
		A.style(frame.rating, "number", line.primaryTone or "bright")
		if line.rating ~= nil then
			tintRating(frame.rating, format, line.rating)
		end
		local width = A.textRoom(frame.rating, line.primary)
		frame.rating:SetWidth(width)
		frame.rating:Show()
		lineWidth = width
	else
		frame.rating:SetText("")
		frame.rating:SetWidth(0)
		frame.rating:Hide()
	end



	local todayText
	if line.today ~= nil then
		if line.primary ~= nil and line.rating == nil then
			todayText = "today"
		else
			todayText = line.today .. " today"
		end
	end
	frame.today:ClearAllPoints()
	if todayText then
		frame.today:SetText(todayText)

		A.style(frame.today, "numberSmall", line.rating ~= nil and line.todayTone or "dim")
		local width = A.textRoom(frame.today, todayText)
		frame.today:SetWidth(width)
		if lineWidth > 0 then
			frame.today:SetPoint("BOTTOMLEFT", frame.rating, "BOTTOMRIGHT", TODAY_GAP, 0)
			lineWidth = lineWidth + TODAY_GAP + width
		else
			frame.today:SetPoint("TOPLEFT", frame.label, "BOTTOMLEFT", 0, -LINE_GAP)
			lineWidth = width
		end
		frame.today:Show()
	else
		frame.today:SetText("")
		frame.today:Hide()
	end

	if lineWidth > labelWidth then
		return finish(lineWidth)
	end
	return finish(labelWidth)
end





local function paint(character, format, rows)
	local text = "No matches yet."
	local tone = "dim"
	if character ~= nil and format ~= nil then
		text = A.formatLabel(format)
		tone = "text"
	end
	local line = (#rows > 0) and secondLine(format, character) or nil
	local blockWidth, ruleWidth = paintBlock(text, tone, format, line, #rows > 0)

	local height = barHeight()

	local tileTop = centredTop(tileHeight())
	local column = columnWidth()
	local x = PAD + blockWidth
	if #rows > 0 then
		frame.divider:ClearAllPoints()
		frame.divider:SetPoint("TOPLEFT", frame, "TOPLEFT", x + BLOCK_GAP, -tileTop)
		frame.divider:SetSize(1, tileHeight())
		frame.divider:SetColorTexture(A.color("hairline"))
		frame.divider:Show()
		x = x + BLOCK_GAP + 1 + BLOCK_GAP
	else
		frame.divider:Hide()
	end

	local tileX = #rows > 0 and x or nil

	local ids, texts = {}, {}
	local ink = { A.color("panelDeep") }
	for i = 1, #rows do
		local record = rows[i]
		local cell = cellAt(i)
		cell.matchId = record.id
		ids[i] = record.id
		cell:ClearAllPoints()
		cell:SetPoint("TOPLEFT", frame, "TOPLEFT", x, -tileTop)


		local resultTone = A.resultTone(record)
		local r, g, b = A.color(resultTone or "dim")
		cell.square:SetColorTexture(r, g, b, 1)


		local letter = A.resultLetter(record)
		cell.letterText = letter
		texts[i] = letter
		cell.letter:SetText(letter)
		A.style(cell.letter, "number")
		cell.letter:SetTextColor(ink[1], ink[2], ink[3], 1)

		local delta, deltaTone = A.ratingDelta(record)
		cell.delta:SetText(delta or "")
		A.style(cell.delta, "numberSmall", deltaTone or "dim")
		cell:Show()
		x = x + column + CELL_GAP
	end
	for i = #rows + 1, #cells do
		cells[i].matchId = nil
		cells[i].letterText = nil
		cells[i]:Hide()
	end

	local width
	if #rows > 0 then
		width = x - CELL_GAP + PAD
	else
		width = PAD + blockWidth + PAD
	end
	frame:SetSize(width, height)


	local r, g, b = A.color("panel")
	frame.ground:SetColorTexture(r, g, b, drawnOpacity() / 100)
	return ids, line, texts, tileX, ruleWidth, height
end






local function secondsToMidnight()
	local ok, parts = pcall(date, "*t")
	if not ok or type(parts) ~= "table" then
		return nil
	end

	local okNext, nextDay = pcall(time, { year = parts.year, month = parts.month, day = parts.day + 1,
		hour = 0, min = 0, sec = 0 })
	local now = time()
	if not okNext or type(nextDay) ~= "number" or type(now) ~= "number" or nextDay <= now then
		return nil
	end
	return nextDay - now + 1
end



local function armMidnight(wanted)
	midnightCall = midnightCall + 1
	if not wanted then
		return
	end
	local after = C_Timer and C_Timer.After
	local delay = secondsToMidnight()
	if type(after) ~= "function" or delay == nil then
		return
	end
	local call = midnightCall
	pcall(after, delay, function()
		if call == midnightCall then
			A.overlayRepaint("day")
		end
	end)
end


















function A.overlayRepaint(source, via)
	local ok, err = pcall(function()
		local wanted = A.overlayEnabled() or previewUp
		local reason
		if not wanted then
			reason = source == "preview" and "preview" or "off"
		elseif inCombat and A.overlayCombat() then
			reason = "combat"
		end

		local format, ids = nil, {}
		local line, texts, tileX = nil, {}, nil
		local ruleWidth, height
		local kept
		if reason == nil then
			local db = A.db()
			local matches = db and type(db.matches) == "table" and db.matches or nil
			local count = matches and #matches or nil
			local character = A.barCharacter()


			local day = A.dayKey(A.stamp())
			if source == "combat" and frame ~= nil and painted ~= nil and painted.db == db
				and painted.matches == matches and painted.count == count
				and painted.character == character and painted.day == day then
				kept = "kept"
				ids, format = painted.ids, painted.format
				line, texts, tileX = painted.line, painted.texts, painted.tileX
				ruleWidth, height = painted.ruleWidth, painted.height
			else
				if source == "combat" then
					kept = "drawn"
				end
				local held, rows
				character, held, rows = subject()
				if build() == nil then
					return
				end
				ids, line, texts, tileX, ruleWidth, height = paint(character, held, rows)
				format = held
				painted = { character = character, db = db, matches = matches, count = count, day = day,
					format = format, ids = ids, line = line, texts = texts, tileX = tileX,
					ruleWidth = ruleWidth, height = height }
				armMidnight(line ~= nil)
			end
			if #ids == 0 then
				reason = "empty"
			end
			frame:Show()
		else



			if source ~= "combat" then
				painted = nil
			end
			if frame then
				frame:Hide()
			end
		end

		local state = (reason == nil or reason == "empty") and "shown" or "hidden"

		local pairsDrawn = {}
		for i = 1, #ids do
			pairsDrawn[i] = tostring(ids[i]) .. ":" .. tostring(texts[i])
		end
		local title = ruleWidth ~= nil and TITLE_TEXT or nil
		last = { state = state, reason = reason, source = source, format = format, ids = ids,
			line = line, texts = texts, tileX = tileX, title = title, ruleWidth = ruleWidth, height = height }
		A.trace("overlay", {
			source = source,
			via = via or kept,
			state = state,
			reason = reason,
			format = format,
			records = #ids > 0 and table.concat(ids, "+") or nil,
			n = #ids,
			rating = line and line.rating or nil,
			today = line and line.today or nil,
			todayN = line and line.todayN or nil,
			cells = #pairsDrawn > 0 and table.concat(pairsDrawn, "+") or nil,
			tileX = tileX,
			title = title,
			ruleWidth = ruleWidth,
			height = height,
		}, "ui")
	end)
	if not ok then
		A.noteError(err, "overlay")
	end
end



function A.overlayRecordStored()
	A.overlayRepaint("stored")
end




function A.overlayReplaced()
	A.setOverlayPosition(nil)
	painted = nil
	if frame then
		A.overlayRepaint("reset")
	end
end









function A.overlayPreview(on)
	if on == false then
		if not previewUp then
			return false
		end
		previewUp = false

		previewFormat = nil
		previewOpacity = nil
		A.overlayRepaint("preview")
		return "ended"
	end
	if previewUp then
		return "held"
	end
	previewUp = true
	A.overlayRepaint("preview")
	return "shown"
end


function A.overlayPreviewActive()
	return previewUp
end





function A.overlayPreviewFormat(format)
	if type(format) ~= "string" or format == "" or A.formatShortLabel(format) == format then
		return false
	end
	previewFormat = format
	previewUp = true
	A.overlayRepaint("preview", "format")
	return true
end





function A.overlayPreviewOpacity(value)
	local figure = tonumber(value)
	if figure == nil or figure ~= figure or figure < OPACITY_MIN or figure > OPACITY_MAX then
		return false
	end
	previewOpacity = math.floor(figure / OPACITY_STEP + 0.5) * OPACITY_STEP
	A.overlayRepaint("preview", "opacity")
	return previewOpacity
end



function A.overlayPreviewHeld()
	return previewFormat, previewOpacity
end






function A.overlayHover(index)
	if index == nil then
		A.hideTooltip()
		return "hidden"
	end
	if frame == nil or not frame:IsShown() then
		return false, "no-bar"
	end
	local cell = cells[index]
	if cell == nil or not cell:IsShown() or cell.matchId == nil then
		return false, "no-tile"
	end
	if not hover(cell) then
		return false, "no-hover"
	end
	return "shown", cell.matchId
end







function A.overlayReadout()
	local lines = {
		("overlay: %s, %d matches, opacity %d%%, hide in combat %s, preview %s"):format(
			A.overlayEnabled() and "on" or "off", A.overlayCount(), A.overlayOpacity(),
			A.overlayCombat() and "on" or "off", previewUp and "shown" or "none"),
	}
	local character, format, rows = subject()
	if character == nil then
		lines[#lines + 1] = "no readable character, so nothing to draw"
	elseif format == nil then
		lines[#lines + 1] = ("no stored match for %s, so the bar reads No matches yet."):format(character)
	else
		local ids = {}
		for i = 1, #rows do
			ids[i] = tostring(rows[i].id)
		end
		lines[#lines + 1] = ("%s for %s, newest first: %s"):format(A.formatLabel(format), character,
			table.concat(ids, ", "))
	end
	lines[#lines + 1] = ("drawn: %s%s"):format(last.state,
		last.reason and (", " .. last.reason) or "")
	if last.title ~= nil then
		lines[#lines + 1] = ("header: %s, rule %d wide, bar %d high"):format(last.title, last.ruleWidth,
			last.height)
	end
	if previewFormat ~= nil or previewOpacity ~= nil then
		lines[#lines + 1] = ("held for this session: format %s, opacity %s"):format(
			previewFormat or "none", previewOpacity and (previewOpacity .. "%") or "none")
	end
	if hovered ~= nil and hovered.id ~= nil then
		lines[#lines + 1] = ("hovered: #%s, %s"):format(tostring(hovered.id), tostring(hovered.text))
	else
		lines[#lines + 1] = "hovered: none"
	end
	return lines
end


function A.overlayFrame()
	return frame
end


function A.overlayCells()
	return cells
end



function A.overlayState()
	return last
end




A.on("PLAYER_LOGIN", function()
	local ok, locked = pcall(InCombatLockdown)
	inCombat = ok and locked == true
	A.overlayRepaint("login")
end)



A.on("PLAYER_REGEN_DISABLED", function()
	inCombat = true
	A.overlayRepaint("combat")
end)

A.on("PLAYER_REGEN_ENABLED", function()
	inCombat = false
	A.overlayRepaint("combat")
end)
