





local _, A = ...



local SESSION_GAP_MINUTES = 60


local TREND_COUNT = 30


function A.sessionGapMinutes()
	return SESSION_GAP_MINUTES
end


function A.standingTrendCount()
	return TREND_COUNT
end






local function startEpoch(subject)
	if type(subject) ~= "table" then
		return nil
	end
	local opened = A.stampEpoch(subject.openedAt)
	if opened ~= nil then
		return opened
	end
	local ended = A.stampEpoch(subject.completedAt) or A.stampEpoch(subject.endedAt)
	if ended ~= nil then
		local length = type(subject.duration) == "number" and subject.duration
			or type(subject.seconds) == "number" and subject.seconds or 0
		return ended - length
	end
	return nil
end


local function endEpoch(subject)
	if type(subject) ~= "table" then
		return nil
	end
	local ended = A.stampEpoch(subject.completedAt) or A.stampEpoch(subject.endedAt)
	if ended ~= nil then
		return ended
	end
	local opened = A.stampEpoch(subject.openedAt)
	if opened == nil then
		return nil
	end
	local length = type(subject.duration) == "number" and subject.duration
		or type(subject.seconds) == "number" and subject.seconds or 0
	return opened + length
end



local function entryKey(entry)
	local subject = entry and entry.subject
	if type(subject) ~= "table" or subject.id == nil then
		return nil
	end
	if entry.kind == "incomplete" then
		return "i" .. tostring(subject.id)
	end
	return subject.id
end
A.sessionEntryKey = entryKey


local function ownRow(record)
	local participants = type(record) == "table" and record.participants or nil
	if type(participants) ~= "table" or record.character == nil then
		return nil
	end
	local row = participants[record.character]
	return type(row) == "table" and row or nil
end



function A.recordLadderPair(record)
	if type(record) ~= "table" or not A.movesRating(record.format) or not A.oneLadder(record.format) then
		return nil
	end
	if record.rated == false then
		return nil
	end
	local row = ownRow(record)
	if row == nil or A.ladderSilent(row) or type(row.rating) ~= "number" then
		return nil
	end
	local change = type(row.ratingChange) == "number" and row.ratingChange or 0
	local out = row.rating + change
	if out <= 0 then
		return nil
	end
	return row.rating, out, change
end







local function sessionLadders(entries)
	local order, by = {}, {}

	for i = 1, #entries do
		local entry = entries[i]
		if entry.kind ~= "incomplete" then
			local record = entry.subject
			local from, out = A.recordLadderPair(record)
			if from ~= nil then
				local held = by[record.format]
				if held == nil then
					held = { format = record.format, to = out }
					by[record.format] = held
					order[#order + 1] = held
				end
				held.from = from
			end
		end
	end
	for i = 1, #order do
		order[i].change = order[i].to - order[i].from
	end
	return order
end




function A.buildSessions(entries)
	local sessions, unplaced = {}, 0
	if type(entries) ~= "table" then
		return sessions, unplaced
	end
	local gap = SESSION_GAP_MINUTES * 60
	local current, previousStart = nil, nil
	for i = 1, #entries do
		local entry = entries[i]
		local subject = entry and entry.subject
		local started, ended = startEpoch(subject), endEpoch(subject)
		if started == nil or ended == nil then
			unplaced = unplaced + 1
			current, previousStart = nil, nil
		else

			if current == nil or previousStart == nil or previousStart - ended > gap then
				current = { entries = {}, endEpoch = ended, endStamp = subject.completedAt or subject.endedAt }
				sessions[#sessions + 1] = current
			end
			current.entries[#current.entries + 1] = entry
			current.startEpoch = started
			current.startStamp = subject.openedAt or subject.completedAt or subject.endedAt
			current.key = entryKey(entry)
			previousStart = started
		end
	end

	for i = 1, #sessions do
		local session = sessions[i]
		session.count = #session.entries
		local leftEarly = 0
		for _, entry in ipairs(session.entries) do
			if entry.kind == "incomplete" then
				leftEarly = leftEarly + 1
			end
		end
		session.leftEarly = leftEarly
		session.matches = session.count - leftEarly
		session.ladders = sessionLadders(session.entries)
	end
	return sessions, unplaced
end


function A.sessionsFlat(sessions)
	if type(sessions) ~= "table" then
		return true
	end
	for i = 1, #sessions do
		if sessions[i].count > 1 then
			return false
		end
	end
	return true
end





local EVENING_HOUR = 17



function A.sessionDayLabel(stamp, now)
	local key = A.dayKey(stamp)
	if key == nil then
		return nil
	end
	if type(now) == "number" then
		local okToday, today = pcall(date, "%Y-%m-%d", now)
		if okToday and today == key then
			local hour = tonumber(tostring(A.clockKey(stamp)):match("^(%d%d):"))
			return (hour ~= nil and hour < EVENING_HOUR) and "Today" or "Tonight"
		end

		local okY, y, m, d = pcall(function()
			local text = date("%Y-%m-%d", now)
			return text:match("^(%d+)%-(%d+)%-(%d+)$")
		end)
		if okY and y then
			local okAt, noon = pcall(time, { year = tonumber(y), month = tonumber(m), day = tonumber(d), hour = 12 })
			if okAt and type(noon) == "number" then
				local okPrev, previous = pcall(date, "%Y-%m-%d", noon - 86400)
				if okPrev and previous == key then
					return "Yesterday"
				end
			end
		end
	end
	return A.dayLabel(stamp) or key
end



function A.sessionDayForms(stamp, now)
	local long = A.sessionDayLabel(stamp, now)
	if long == nil then
		return nil
	end
	if long == "Today" or long == "Tonight" or long == "Yesterday" then
		return { long }
	end
	local forms = { long }
	local y, m, d = tostring(A.dayKey(stamp)):match("^(%d+)%-(%d+)%-(%d+)$")
	local okAt, noon = pcall(time, { year = tonumber(y), month = tonumber(m), day = tonumber(d), hour = 12 })
	if y and okAt and type(noon) == "number" then


		local okParts, weekday, day, month = pcall(function()
			return date("%a", noon), tonumber(date("%d", noon)), date("%b", noon)
		end)
		if okParts and type(day) == "number" then
			for _, short in ipairs({ ("%s %d %s"):format(weekday, day, month), ("%d %s"):format(day, month) }) do
				if short ~= forms[#forms] then
					forms[#forms + 1] = short
				end
			end
		end
	end
	return forms
end



local DAY_PARTS = {
	{ from = 5, part = "morning" },
	{ from = 12, part = "afternoon" },
	{ from = 17, part = "evening" },
	{ from = 21, part = "night" },
}


function A.sessionDayParts()
	local out = {}
	for i = 1, #DAY_PARTS do
		out[i] = { from = DAY_PARTS[i].from, part = DAY_PARTS[i].part }
	end
	return out
end




local function sessionDayPart(stamp)
	local key = A.dayKey(stamp)
	local hour = tonumber(tostring(A.clockKey(stamp)):match("^(%d%d):"))
	if key == nil or hour == nil then
		return nil
	end
	local y, m, d = key:match("^(%d+)%-(%d+)%-(%d+)$")
	local okAt, noon = pcall(time, { year = tonumber(y), month = tonumber(m), day = tonumber(d), hour = 12 })
	if not okAt or type(noon) ~= "number" then
		return nil
	end
	if hour < DAY_PARTS[1].from then
		return noon - 86400, "night"
	end
	local part = DAY_PARTS[1].part
	for i = 1, #DAY_PARTS do
		if hour >= DAY_PARTS[i].from then
			part = DAY_PARTS[i].part
		end
	end
	return noon, part
end


local TODAY_WORDS = { morning = "This morning", afternoon = "This afternoon", evening = "This evening",
	night = "Tonight" }
local YESTERDAY_WORDS = { morning = "Yesterday morning", afternoon = "Yesterday afternoon",
	evening = "Yesterday evening", night = "Last night" }




function A.sessionHeadForms(stamp, now)
	local day, part = sessionDayPart(stamp)
	if day == nil then
		return nil
	end
	local okKey, dayKey = pcall(date, "%Y-%m-%d", day)
	if type(now) == "number" and okKey then
		local okToday, today = pcall(date, "%Y-%m-%d", now)
		local okY, yesterday = pcall(function()
			local text = date("%Y-%m-%d", now)
			local y, m, d = text:match("^(%d+)%-(%d+)%-(%d+)$")
			return date("%Y-%m-%d", time({ year = tonumber(y), month = tonumber(m), day = tonumber(d), hour = 12 }) - 86400)
		end)
		if okToday and dayKey == today then
			return { TODAY_WORDS[part] }
		end
		if okY and dayKey == yesterday then
			return { YESTERDAY_WORDS[part] }
		end
	end
	local okParts, long, weekday, dayOfMonth, month, short = pcall(function()
		return date("%A", day), date("%a", day), tonumber(date("%d", day)), date("%B", day), date("%b", day)
	end)
	if not okParts or type(dayOfMonth) ~= "number" then
		return nil
	end
	return {
		("%s %d %s, %s"):format(long, dayOfMonth, month, part),
		("%s %d %s, %s"):format(weekday, dayOfMonth, short, part),
		("%d %s, %s"):format(dayOfMonth, short, part),
	}
end




function A.sessionGridLabelForms(stamp, now)
	local forms = A.sessionHeadForms(stamp, now)
	if forms == nil or #forms < 2 then
		return forms
	end
	local day, part = sessionDayPart(stamp)
	local ok, weekday, dayOfMonth, month = pcall(function()
		return date("%a", day), tonumber(date("%d", day)), date("%b", day)
	end)
	if not ok or type(dayOfMonth) ~= "number" then
		return forms
	end
	local out = { ("%s %d %s, %s"):format(weekday, dayOfMonth, month, part) }
	for i = 2, #forms do
		if forms[i] ~= out[#out] then
			out[#out + 1] = forms[i]
		end
	end
	return out
end



function A.sessionHeadList(sessions, now)
	local out = {}
	for _, session in ipairs(type(sessions) == "table" and sessions or {}) do
		out[session] = A.sessionHeadForms(session.startStamp, now) or {}
	end
	return out
end



function A.sessionSpanText(session)
	if type(session) ~= "table" then
		return nil
	end
	local from = A.clockKey(session.startStamp)
	if from == nil and type(session.startEpoch) == "number" then
		local ok, text = pcall(date, "%H:%M", session.startEpoch)
		from = ok and text or nil
	end
	local to = nil
	if type(session.endEpoch) == "number" then
		local ok, text = pcall(date, "%H:%M", session.endEpoch)
		to = ok and text or nil
	end
	if from == nil then
		return to
	end
	if to == nil or to == from then
		return from
	end
	return from .. " - " .. to
end





function A.seasonPart(newer, older, crossed)
	if type(newer) ~= "table" or type(older) ~= "table" then
		return nil
	end
	if type(newer.gameSeason) == "number" and type(older.gameSeason) == "number" then
		return newer.gameSeason ~= older.gameSeason and "season" or nil
	end
	if type(newer.season) == "number" and type(older.season) == "number" then
		return newer.season ~= older.season and "season" or nil
	end
	local newerSeason = type(A.recordSeason) == "function" and A.recordSeason(newer) or nil
	local olderSeason = type(A.recordSeason) == "function" and A.recordSeason(older) or nil
	if newerSeason ~= nil and olderSeason ~= nil then
		return newerSeason ~= olderSeason and "season" or nil
	end
	if not crossed or newer.format ~= older.format then
		return nil
	end
	local newerFrom = A.recordLadderPair(newer)
	local _, olderOut = A.recordLadderPair(older)
	if newerFrom == 0 and type(olderOut) == "number" and olderOut > 0 then
		return "rating"
	end
	return nil
end






function A.withSeasonBreaks(rows, rowEntries, selectedAt, lineRecords)
	if type(rows) ~= "table" or type(rowEntries) ~= "table" then
		return rows, rowEntries, selectedAt
	end
	lineRecords = type(lineRecords) == "table" and lineRecords or {}
	local out, entries, at = {}, {}, nil
	local previous = nil

	local crossed = false
	for i = 1, #rows do
		local entry = rowEntries[i]
		local line = lineRecords[i]
		local record = entry ~= nil and entry.kind ~= "incomplete" and entry.subject or nil
		local oldest = record
		if record == nil and type(line) == "table" and type(line.newest) == "table" then
			record, oldest = line.newest, type(line.oldest) == "table" and line.oldest or line.newest
		end
		if type(rows[i]) == "table" and rows[i].separator then
			crossed = true
		end
		local newer = previous
		if record ~= nil and newer ~= nil then
			local part = A.seasonPart(newer.record, record, crossed)
			if part ~= nil then

				local text = type(A.seasonText) == "function" and A.seasonText(record, true) or nil
				table.insert(out, newer.index + 1, {
					separator = true,
					seasonBreak = true,
					seasonPart = part,
					text = text and text:upper() or "PREVIOUS SEASON",
					height = A.metric("rowHeadRow"),
				})

				for k = #out, newer.index + 2, -1 do
					entries[k] = entries[k - 1]
				end
				entries[newer.index + 1] = nil
				if at ~= nil and at > newer.index then
					at = at + 1
				end
			end
		end
		out[#out + 1] = rows[i]
		entries[#out] = entry
		if selectedAt == i then
			at = #out
		end
		if record ~= nil then
			previous = { record = oldest, index = #out }
			crossed = false
		end
	end
	return out, entries, at
end








local GRID_FORMATS = { "shuffle", "blitz", "arena2", "arena3", "rbg" }

local GRID_NAMES = {
	shuffle = "SOLO SHUFFLE",
	blitz = "BLITZ",
	arena2 = "ARENA (2V2)",
	arena3 = "ARENA (3V3)",
	rbg = "RATED BG",
	arena = "ARENA",
}


local GRID_COLUMNS_MAX = 4


local GRID_TICKS_MAX = 20


function A.sessionGridCaps()
	return GRID_TICKS_MAX, GRID_COLUMNS_MAX
end


function A.sessionGridName(format)
	return GRID_NAMES[format] or (A.formatLabel(format) or tostring(format)):upper()
end


local function gridFormatOf(entry)
	if type(entry) ~= "table" or entry.kind == "incomplete" then
		return nil
	end
	local record = entry.subject
	if type(record) ~= "table" or record.rated == false or GRID_NAMES[record.format] == nil then
		return nil
	end
	return record.format
end




function A.sessionGridFormats(entries)
	local present = {}
	for _, entry in ipairs(type(entries) == "table" and entries or {}) do
		local format = gridFormatOf(entry)
		if format ~= nil then
			present[format] = true
		end
	end
	local held = {}
	for _, format in ipairs(GRID_FORMATS) do
		if present[format] then
			held[#held + 1] = format
		end
	end
	if #held <= GRID_COLUMNS_MAX then
		return held, {}
	end
	local shown, rest = {}, {}
	for i = 1, #held do
		if i < GRID_COLUMNS_MAX then
			shown[#shown + 1] = held[i]
		else
			rest[#rest + 1] = held[i]
		end
	end
	return shown, rest
end



function A.sessionGridCell(listed, format)
	local matches, from, to = 0, nil, nil
	for _, entry in ipairs(type(listed) == "table" and listed or {}) do
		if gridFormatOf(entry) == format then
			matches = matches + 1
			local inRating, outRating = A.recordLadderPair(entry.subject)
			if inRating ~= nil then
				if to == nil then
					to = outRating
				end
				from = inRating
			end
		end
	end
	if matches == 0 then
		return nil
	end
	return { format = format, matches = matches, from = from, to = to, change = to and (to - from) or nil }
end



function A.sessionGridCellText(cell)
	if type(cell) ~= "table" then
		return nil
	end
	if cell.to == nil then
		return A.colorEscape("dim") .. "-|r"
	end
	local tone = cell.change > 0 and "win" or cell.change < 0 and "loss" or "dim"
	return ("%s %s%s|r"):format(A.tierRatingText(cell.format, cell.to, "bright"), A.colorEscape(tone),
		A.signedText(cell.change) or "0")
end



function A.sessionGridHoverLine(cell)
	if type(cell) ~= "table" then
		return nil
	end
	local count = ("%d %s"):format(cell.matches, cell.matches == 1 and "match" or "matches")
	if cell.to == nil then
		return count
	end
	return ("%d to %d %s, %s"):format(cell.from, cell.to, A.signedText(cell.change) or "0", count)
end



function A.sessionTickTone(entry)
	if type(entry) ~= "table" then
		return "dim"
	end
	if entry.kind == "incomplete" then
		return "caveat"
	end
	return A.resultTone(entry.subject) or "dim"
end



function A.sessionTicks(listed)
	local tones = {}
	listed = type(listed) == "table" and listed or {}
	for i = #listed, 1, -1 do
		tones[#tones + 1] = A.sessionTickTone(listed[i])
	end
	local over = math.max(0, #tones - GRID_TICKS_MAX)
	if over == 0 then
		return tones, 0
	end
	local kept = {}
	for i = over + 1, #tones do
		kept[#kept + 1] = tones[i]
	end
	return kept, over
end



function A.sessionGridSummaryName(format)
	if format == nil then
		return nil
	end
	return format == "shuffle" and "ROUNDS" or "RECORD"
end






function A.sessionGridSummary(listed, format)
	local out = { kind = "matches", won = 0, lost = 0, any = false, out = 0, counted = 0, shuffles = 0 }
	if format == "shuffle" then
		out.kind = "rounds"
	elseif format == "world" then
		out.kind = "kills"
	end
	for _, entry in ipairs(type(listed) == "table" and listed or {}) do
		local record = entry.kind ~= "incomplete" and entry.subject or nil
		if type(record) == "table" then
			if out.kind == "rounds" then
				local verdict, won, played = A.roundsVerdict(record)
				out.shuffles = out.shuffles + 1
				if verdict == nil or verdict == "unsummed" then
					out.out = out.out + 1
				else
					out.won, out.lost, out.any = out.won + won, out.lost + (played - won), true
					out.counted = out.counted + 1
				end
			elseif out.kind == "kills" then
				if type(record.kills) == "number" or type(record.deaths) == "number" then
					out.won = out.won + (type(record.kills) == "number" and record.kills or 0)
					out.lost = out.lost + (type(record.deaths) == "number" and record.deaths or 0)
					out.any = true
				end
			else
				local tone = A.resultTone(record)
				if tone == "win" then
					out.won, out.any = out.won + 1, true
				elseif tone == "loss" then
					out.lost, out.any = out.lost + 1, true
				end
			end
		end
	end

	if out.kind == "matches" and not out.any then
		for _, entry in ipairs(type(listed) == "table" and listed or {}) do
			if entry.kind ~= "incomplete" then
				out.any = true
				break
			end
		end
	end
	return out
end



function A.sessionGridSummaryPartial(summary)
	return type(summary) == "table" and summary.kind == "rounds" and summary.any == true
		and (summary.out or 0) > 0 and (summary.counted or 0) > 0
end


function A.sessionGridSummaryHover(summary)
	if not A.sessionGridSummaryPartial(summary) then
		return nil
	end
	return ("%d-%d over %d of %d matches"):format(summary.won, summary.lost, summary.counted,
		summary.shuffles)
end



function A.sessionGridSummaryText(summary)
	if type(summary) ~= "table" or not summary.any then
		return A.colorEscape("dim") .. "-|r"
	end
	local tone = summary.won > summary.lost and "win" or summary.won < summary.lost and "loss" or "dim"
	if A.sessionGridSummaryPartial(summary) then
		tone = "dim"
	end
	local text = ("%s%d-%d|r"):format(A.colorEscape(tone), summary.won, summary.lost)
	if summary.kind == "rounds" then
		text = text .. A.colorEscape("dim") .. " rds|r"
	end
	return text
end





function A.sessionGrid(entries, room, format)
	local shown, rest = {}, {}
	if format == nil then
		shown, rest = A.sessionGridFormats(entries)
	end
	local summaryName = A.sessionGridSummaryName(format)
	local function fixed(metric, name)
		return math.max(A.metric(metric), A.headerFloor(name))
	end
	local function build(fold)
		local columns = { { key = "session", name = "SESSION", width = fixed("gridSession", "SESSION") } }
		if not fold then
			columns[#columns + 1] = { key = "time", name = "TIME", width = fixed("gridTime", "TIME") }
		end
		for _, played in ipairs(shown) do
			local name = A.sessionGridName(played)
			columns[#columns + 1] = { key = "format", format = played, name = name, width = fixed("gridFormat", name) }
		end
		if #rest > 0 then
			local name = ("+%d"):format(#rest)
			columns[#columns + 1] = { key = "more", name = name, width = fixed("gridFormat", name) }
		end
		if format ~= nil and A.movesRating(format) then
			columns[#columns + 1] = { key = "format", format = format, name = "RATING",
				width = fixed("gridRating", "RATING") }
		end
		columns[#columns + 1] = { key = "results", name = "RESULTS", width = 0 }
		if summaryName ~= nil then
			columns[#columns + 1] = { key = "summary", name = summaryName, width = fixed("gridRecord", summaryName) }
		end
		columns[#columns + 1] = { key = "matches", name = "MATCHES", align = "RIGHT",
			width = fixed("gridMatches", "MATCHES") }

		local used = A.metric("rowLabelPad") * 2 + A.metric("rowCellGap") * (#columns - 1)
		for i = 1, #columns do
			used = used + columns[i].width
		end
		local floor = fixed("gridResultsFloor", "RESULTS")
		local left = type(room) == "number" and (room - used) or floor
		for i = 1, #columns do
			if columns[i].key == "results" then
				columns[i].width = math.max(0, math.floor(left))
			end
		end
		return columns, left >= floor
	end
	local columns, fits = build(false)
	if fits then
		return columns, rest, false
	end
	columns = build(true)
	return columns, rest, true
end





local function storedFolds()
	local db = A.db and A.db()
	local folds = db and db.ui and db.ui.sessionFolds
	return type(folds) == "table" and folds or nil
end



local heldFolds = {}


function A.holdSessionOpen(key, open)
	if key ~= nil then
		heldFolds[key] = open == true
	end
end



function A.sessionOpen(key, newest)

	if key ~= nil and type(heldFolds[key]) == "boolean" then
		return heldFolds[key], "held"
	end
	local folds = storedFolds()
	local held = nil
	if folds ~= nil and key ~= nil then
		held = folds[key]
	end
	if type(held) == "boolean" then
		return held, "stored"
	end
	return newest == true, "default"
end



function A.setSessionOpen(key, open, newest)
	if key == nil then
		return nil
	end
	local db = A.db and A.db()
	if not (db and db.ui) then
		return nil
	end

	heldFolds[key] = nil
	open = open == true
	local default = newest == true
	if open == default then
		if type(db.ui.sessionFolds) == "table" then
			db.ui.sessionFolds[key] = nil
			if next(db.ui.sessionFolds) == nil then
				db.ui.sessionFolds = nil
			end
		end
	else
		db.ui.sessionFolds = type(db.ui.sessionFolds) == "table" and db.ui.sessionFolds or {}
		db.ui.sessionFolds[key] = open
	end
	return open
end


function A.toggleSession(key, newest)
	local open = A.sessionOpen(key, newest)
	return A.setSessionOpen(key, not open, newest)
end



function A.pruneSessionFolds()
	local db = A.db and A.db()
	local folds = db and db.ui and db.ui.sessionFolds
	if type(folds) ~= "table" then
		return 0
	end
	local matches, unfinished = {}, {}
	for _, record in ipairs(type(db.matches) == "table" and db.matches or {}) do
		if type(record) == "table" and record.id ~= nil then
			matches[record.id] = true
		end
	end
	for _, entry in ipairs(type(db.incomplete) == "table" and db.incomplete or {}) do
		if type(entry) == "table" and entry.id ~= nil then
			unfinished["i" .. tostring(entry.id)] = true
		end
	end
	local gone = {}
	for key in pairs(folds) do

		local held = matches[key] or (type(key) == "string" and unfinished[key])
		if not held then
			gone[#gone + 1] = key
		end
	end
	for i = 1, #gone do
		folds[gone[i]] = nil
	end
	if next(folds) == nil then
		db.ui.sessionFolds = nil
	end
	return #gone
end





local function scopedRecords(format, season, character, bound)
	local out = {}
	local list = A.matches(format, character)
	for i = 1, #list do
		local record = list[i]
		local held = season == nil
		if not held then
			local ok, resolved = pcall(A.recordSeason, record)
			held = ok and resolved == season
		end
		if held and A.recordSince(record, bound) then
			out[#out + 1] = record
		end
	end
	return out
end



function A.standingShape(format)
	if format == nil then
		return "all"
	end
	if A.movesRating(format) and A.oneLadder(format) then
		return "rated"
	end
	return "ladderless"
end


local DUEL_SQUARES = 10


local function pairText(wins, losses)
	return ("%d-%d"):format(wins or 0, losses or 0)
end




function A.duelReading(records, character, season, bound)
	local hero = { wins = 0, losses = 0, duels = #records,
		knockout = { wins = 0, losses = 0 }, fled = { wins = 0, losses = 0 }, squares = {} }
	for i = 1, #records do
		local record = records[i]
		local verdict = A.recordVerdict(record)
		local row = record.outcome == "knockout" and hero.knockout
			or record.outcome == "retreat" and hero.fled or nil
		if verdict == "win" then
			hero.wins = hero.wins + 1
			if row then
				row.wins = row.wins + 1
			end
		elseif verdict == "loss" then
			hero.losses = hero.losses + 1
			if row then
				row.losses = row.losses + 1
			end
		end
	end
	local decided = hero.wins + hero.losses
	hero.rate = decided > 0 and hero.wins / decided or nil
	hero.record = pairText(hero.wins, hero.losses)
	hero.knockout.text = pairText(hero.knockout.wins, hero.knockout.losses)
	hero.fled.text = pairText(hero.fled.wins, hero.fled.losses)

	for i = 1, #records do
		if #hero.squares >= DUEL_SQUARES then
			break
		end
		local tone = A.resultTone(records[i])
		if tone ~= nil then
			table.insert(hero.squares, 1, tone)
		end
	end

	local tally = A.opponentTally("duel", character, season, bound)
	hero.opponents = tally
	hero.players = #tally
	local keys = {}
	hero.resolved, hero.nameOnly = 0, 0
	for _, row in ipairs(tally) do
		if row.key ~= nil then
			keys[row.key] = true
			hero.resolved = hero.resolved + 1
		else
			hero.nameOnly = hero.nameOnly + 1
		end
	end
	hero.classes = A.classTokens(keys)

	local last = records[1]
	if last then
		local bare, realm = A.nameParts(last.opponentName)
		local key = A.duelOpponentKey(last)
		local stamp = last.completedAt or last.openedAt
		local verdict = A.recordVerdict(last)


		local how, parts = {}, { A.duelHow(last), last.map and last.map.name or nil, A.lengthText(last.duration) }
		for i = 1, 3 do
			if type(parts[i]) == "string" and parts[i] ~= "" then
				how[#how + 1] = parts[i]
			end
		end
		hero.last = {
			result = verdict == "win" and "won" or verdict == "loss" and "lost" or nil,
			tone = A.resultTone(last),
			name = bare ~= "" and bare or nil,
			realm = realm,
			classToken = key and hero.classes[key] or nil,
			how = #how > 0 and table.concat(how, ", ") or nil,
			when = (A.shortDayText(stamp) and A.clockKey(stamp))
				and (A.shortDayText(stamp) .. " " .. A.clockKey(stamp)) or nil,
		}
	end
	return hero
end



function A.otherReading(records, entries, now)
	local hero = { others = #records, wins = 0, losses = 0, leftEarly = #entries, unset = 0, reasons = {} }
	for i = 1, #records do
		local verdict = A.recordVerdict(records[i])
		if verdict == "win" then
			hero.wins = hero.wins + 1
		elseif verdict == "loss" then
			hero.losses = hero.losses + 1
		end
	end
	hero.record = pairText(hero.wins, hero.losses)
	local counts = {}
	local newest, newestMap = nil, nil
	local function consider(stamp, map)
		if type(stamp) == "string" and (newest == nil or stamp > newest) then
			newest, newestMap = stamp, map
		end
	end
	for i = 1, #entries do
		local entry = entries[i]
		local token = type(entry.manual) == "table" and entry.manual.reason or nil
		if token == nil then
			hero.unset = hero.unset + 1
		else
			counts[token] = (counts[token] or 0) + 1
		end
		consider(entry.openedAt or entry.endedAt, entry.map and entry.map.name)
	end
	for i = 1, #records do
		consider(records[i].openedAt or records[i].completedAt, records[i].map and records[i].map.name)
	end
	for _, token in ipairs(A.manualReasons()) do
		if counts[token] then
			hero.reasons[#hero.reasons + 1] = { label = A.reasonLabel(token), count = counts[token] }
		end
	end
	if hero.unset > 0 then
		hero.reasons[#hero.reasons + 1] = { label = "Not set", count = hero.unset, unset = true }
	end
	if newest then
		hero.lastPlayed = A.sessionDayLabel(newest, now)
		hero.lastForms = A.sessionDayForms(newest, now)
		local clock = A.clockKey(newest)
		hero.lastSub = clock and newestMap and (clock .. ", " .. newestMap) or clock
	end
	return hero
end



function A.seasonHigh(format, season, character)
	local high = nil
	for _, record in ipairs(scopedRecords(format, season, character, nil)) do
		local from, out = A.recordLadderPair(record)
		if from ~= nil then
			local top = math.max(from, out)
			if high == nil or top > high then
				high = top
			end
		end
	end
	return high
end



local function trendBars(records, newestKeys)
	local bars = {}
	local first = math.min(#records, TREND_COUNT)
	for i = first, 1, -1 do
		local record = records[i]
		local _, _, change = A.recordLadderPair(record)
		bars[#bars + 1] = {
			id = record.id,
			change = change,
			tone = A.resultTone(record),
			day = A.dayKey(record.openedAt or record.completedAt),
			newest = newestKeys[record.id] == true,
		}
	end
	return bars
end



function A.standingReading(format, season, character, bound, summary, now)
	summary = type(summary) == "table" and summary or A.summarize(format, season, character, bound)
	local shape = A.standingShape(format)
	local records = scopedRecords(format, season, character, bound)
	local entries = {}
	for i = 1, #records do
		entries[i] = { kind = "match", subject = records[i] }
	end
	local sessions = A.buildSessions(entries)
	local newestKeys = {}
	if sessions[1] then
		for _, entry in ipairs(sessions[1].entries) do
			newestKeys[entry.subject.id] = true
		end
	end
	local reading = { shape = shape, format = format, season = season, matches = #records }



	local stripSeason = season
	for i = 1, #records do
		if stripSeason ~= nil then
			break
		end
		local ok, resolved = pcall(A.recordSeason, records[i])
		stripSeason = ok and resolved or nil
	end
	reading.stripSeason = stripSeason

	local avg = A.wholeAvgDuration(summary)
	local avgText = avg and ("avg " .. A.clockText(avg)) or nil

	if shape == "rated" then
		reading.label = A.formatLabel(format):upper()
		if stripSeason ~= nil then
			reading.label = reading.label .. "  " .. ("Season %d"):format(stripSeason):upper()
		end
		reading.rating = summary.rating
		local ladder = sessions[1] and sessions[1].ladders and sessions[1].ladders[1] or nil
		reading.sessionChange = ladder and ladder.change or nil
		reading.high = A.seasonHigh(format, stripSeason, character)

		local bars, moved = trendBars(records, newestKeys), 0
		for i = 1, #bars do
			if bars[i].change ~= nil then
				moved = moved + 1
			end
		end
		reading.bars = moved >= 2 and bars or {}


		local rate = select(4, A.winRecord(summary))
		if format == "shuffle" then
			reading.figures = {

				{ label = "ROUNDS WON", value = A.percentText(summary.roundRate),
					sub = summary.roundsPlayed and summary.roundsPlayed > 0
						and ("%d-%d"):format(summary.roundsWon, summary.roundsPlayed - summary.roundsWon) or nil,
					tone = A.winRateTone(summary.roundRate) },
			}
		else
			reading.figures = {
				{ label = "WIN RATE", value = A.percentText(rate), sub = A.winRecordText(summary, format),
					tone = A.winRateTone(rate) },
			}
		end


		local gap = summary.mmrGap
		local gapTone = "dim"
		if type(gap) == "number" and gap > 0 then
			gapTone = "win"
		elseif type(gap) == "number" and gap < 0 then
			gapTone = "loss"
		end
		reading.figures[2] = { label = "MATCHES", value = tostring(summary.matches or 0), sub = avgText,
			tone = "text" }
		if summary.mmr == nil then
			reading.figures[3] = { label = "MMR GAP", value = "-", sub = "no MMR read", tone = "dimmer",
				subTone = "dimmer" }
		else
			reading.figures[3] = { label = "MMR GAP", value = A.signedText(gap),
				sub = "MMR " .. tostring(summary.mmr), tone = gapTone }
		end
	elseif shape == "all" then


		local tiles = {}
		local formats = type(A.ratedFormats) == "function" and A.ratedFormats() or {}
		local seasonRecords = scopedRecords(nil, stripSeason, character, nil)
		local newestFormats = {}
		local newestLadders = {}
		if sessions[1] then
			for _, ladder in ipairs(sessions[1].ladders or {}) do
				newestFormats[ladder.format] = true
				newestLadders[ladder.format] = ladder.change
			end
		end
		for _, rated in ipairs(formats) do
			local newest = nil
			for _, record in ipairs(seasonRecords) do
				if record.format == rated then
					local _, out = A.recordLadderPair(record)
					if out ~= nil then
						newest = out
						break
					end
				end
			end
			if newest ~= nil then
				tiles[#tiles + 1] = {
					format = rated,
					label = A.formatLabel(rated):upper(),
					rating = newest,
					change = newestLadders[rated],
					played = newestFormats[rated] == true,
				}
			end
		end
		reading.tiles = tiles
		local rate = select(4, A.winRecord(summary))
		reading.figures = {
			{ label = "WIN RATE", value = A.percentText(rate), sub = A.winRecordText(summary, format),
				tone = A.winRateTone(rate) },
		}
	else
		local rate = select(4, A.winRecord(summary))
		reading.record = A.winRecordText(summary, format)

		if reading.record == nil and #records > 0 then
			reading.record = ("%d %s"):format(#records, #records == 1 and "match" or "matches")
			reading.recordKind = "matches"
		end
		reading.rate = A.percentText(rate)
		reading.rateTone = A.winRateTone(rate)


		local bars = {}
		for _, bar in ipairs(trendBars(records, newestKeys)) do
			if bar.tone ~= nil then
				bars[#bars + 1] = bar
			end
		end
		reading.bars = bars
		local last = records[1]
		local lastStamp = last and (last.openedAt or last.completedAt) or nil
		reading.figures = {
			{ label = "MATCHES", value = tostring(summary.matches or 0),
				sub = avgText },

			{ label = "LAST PLAYED", value = lastStamp and A.sessionDayLabel(lastStamp, now) or "-",
				forms = lastStamp and A.sessionDayForms(lastStamp, now) or nil,
				sub = lastStamp and A.clockKey(lastStamp) or nil },
		}

		if format == "duel" then
			reading.hero = A.duelReading(records, character, season, bound)
			reading.hero.kind = "duel"
		elseif format == "unknown" then

			local left = {}
			local ok, held = pcall(A.incompleteList, character)
			for _, entry in ipairs(ok and type(held) == "table" and held or {}) do
				local inScope = season == nil
				if not inScope then
					local okSeason, resolved = pcall(A.recordSeason, entry)
					inScope = okSeason and resolved == season
				end
				if inScope and A.recordSince(entry, bound) then
					left[#left + 1] = entry
				end
			end
			reading.hero = A.otherReading(records, left, now)
			reading.hero.kind = "other"
		end
	end
	return reading
end
