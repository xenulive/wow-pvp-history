











local _, A = ...






local BOUNDS = {
	capture = 500,
	data = 250,
	ui = 125,
	error = 50,
}


local BOUND_DEFAULT = 125


local CATEGORY = "capture"



local CATEGORIES = { "capture", "data", "ui", "error" }

local CATEGORY_SET = {}
for i = 1, #CATEGORIES do
	CATEGORY_SET[CATEGORIES[i]] = true
end


local BAD_CATEGORY = "unknown-category"


function A.debugCategories()
	local out = {}
	for i = 1, #CATEGORIES do
		out[i] = CATEGORIES[i]
	end
	return out
end


function A.debugCategory(word)
	return type(word) == "string" and CATEGORY_SET[word] == true
end




local FIELDS = {
	"state", "restriction", "rounds", "rows", "kept", "attempt", "off",
	"format", "rated", "bracket", "source", "reason", "id", "n", "build", "version",
	"season", "arena",

	"ids",

	"rating", "winner",

	"out", "from", "gap", "mmr",

	"noRow", "noGuid", "secretGuid",

	"left",

	"seg", "mid", "thick", "cap",

	"capped",

	"hairline", "least", "gapFrom", "gapTo",

	"total", "strip", "plot",

	"head", "tiles", "note",

	"reading", "lines",

	"noteAt",

	"noted",

	"named",
	"players", "notes", "incomplete", "drops", "pinned",

	"stored",

	"evicted",

	"shown",

	"tagLines", "tagCut", "noteMarks",

	"readAgainst", "readWith", "readSummed",

	"offered",

	"found",

	"repaired",

	"folded",

	"ceiling",


	"tagged", "untagged", "unchanged", "atCap", "bots", "pruned",

	"handed",

	"seat",

	"gridOpen",

	"roundsLeft", "roundsPartial",

	"list", "met", "dossier", "panel", "listUp", "metUp", "listW", "listH", "metW", "metH",

	"bandH", "bandUp",

	"short", "bare",

	"room",

	"tones",

	"ground",

	"longest", "width",

	"angle",

	"wins", "widget", "won", "refused",

	"seconds", "scale", "fitted",

	"atlas",


	"anchors", "bounds", "screen", "placed", "cursor", "step", "repaint",

	"rect", "given",

	"windows", "records", "refusals",

	"fill",

	"typed", "drafts",

	"shape", "sides",

	"tall", "below",


	"pillsAgainst", "pillsWith", "pillsUnsided", "linesAgainst", "linesWith", "linesUnsided",
	"shared", "timedLines",


	"err",

	"section", "deepest",

	"column",

	"viewport", "panes", "checks",

	"kind",

	"side",

	"faction",

	"bytes", "letters", "bound",

	"theme", "air",

	"loaded", "nextId",

	"ringFrom", "ringDefault",

	"target", "range", "scroll",


	"held", "point", "x", "y", "paused", "unlocked",

	"lockdown", "sources", "matched", "unmatched",

	"unfinished", "comp",

	"opacity",


	"regen", "storeLockdown", "early",

	"drag",

	"entries", "text", "saved",


	"route", "to", "via", "mode", "choices", "tally", "summary", "page", "options",
	"frame1", "frame2", "frame3", "summaryCached", "windowsSkipped", "stylesSkipped", "stylesApplied",

	"filters", "region", "view", "foot", "size", "unbracketed", "tallyCached",

	"hero",


	"losses", "duels", "knockout", "fled", "resolved", "nameOnly", "leftEarly", "unset", "others", "token",


	"card", "key", "opened", "bars", "per", "lost", "drawn", "anchor", "formats",

	"check", "bottom", "top",

	"header", "pairs", "noteLine", "tagLine", "lastSeen",

	"terms", "excluding", "scoped",

	"filter", "choice",

	"drew", "withdrawn",

	"tiers",

	"groups", "rule",

	"dock", "dockFrom", "move",

	"body",

	"moved",

	"roundsDropped",

	"resultDropped",

	"ladder",

	"unplaced",

	"with", "against", "matchWith", "matchAgainst",

	"marked",

	"sort", "repStep", "fmt", "sections",

	"tileForms", "lead", "ratedPlayers", "unratedPlayers", "repBars",

	"search", "empty",

	"last", "lastFit",

	"rounded", "breaks",

	"result", "stripRoom",

	"heads",

	"listHead", "namesRows",

	"headColor", "namesColor",

	"grid", "gridFold", "line",


	"delta", "offset", "landed", "first", "firstAfter", "content", "extent", "snapTo", "wheelN",

	"d",

	"tries", "cls", "tok",

	"measured", "drawnWidth", "reserved", "drawn",

	"cols",

	"height", "srcBottom",


	"floor", "ranked", "under", "shownUnder", "spec", "class", "ends",

	"weeks", "cells", "blank", "draws",


	"labels", "widths", "rules", "rate", "centre", "shed", "edge", "trend", "inset", "barWidth",

	"asides", "moment",

	"overGap", "overGapFrom",

	"chips", "need",

	"rowHeights", "nameForm", "ratingForm", "chart", "cell",

	"statsView",

	"seasonBreaks", "icons", "squares",

	"stripSeason",

	"stripFloor", "widthFrom",

	"record",

	"over1", "over5", "over10", "over50", "over100", "over500", "over1000",

	"drainMean", "drainMax", "samples",

	"peak", "session",

	"window",

	"foldUs", "newUs", "foldBytes", "newBytes", "calls", "between",

	"cardNote", "cardTags", "cardTagLines", "cardW", "cardH",

	"cardMetLast",

	"chipRight", "cardRight", "chipFrom", "nameClass",

	"cardIndex",

	"cardNames",

	"unmet",

	"game",

	"verdict", "chip", "reached", "markFrom", "markTo", "cards",

	"switch", "alerts", "groupNotes",


	"today", "todayN", "tileX", "title", "ruleWidth",

	"counts", "find", "meter", "band", "slot", "columns",

	"meterRoom",

	"bests", "firstWeek", "lastWeek", "dropped", "undated", "chars", "segments", "copy",

	"fontRole", "created", "gameFaces", "ownFaces",

	"nameCut",

	"baseline",
}


local REFUSED = "refused"



local reported = false



local tracing = false



local SIGNATURE_ALLOWANCE = 1


function A.debugAllowance()
	return SIGNATURE_ALLOWANCE
end


local CENSUS_SHARE = 0.5


function A.debugCensusShare()
	return CENSUS_SHARE
end



local memo = {}


local calls = {}


function A.debugCalls(cat)
	return calls[cat or CATEGORY] or 0
end


local function forget(category)
	if category == nil then
		memo = {}
		return
	end
	memo[category] = nil
end



local function signature(entry)
	local parts = { tostring(entry.ev) }
	for i = 1, #FIELDS do
		local key = FIELDS[i]
		local value = entry[key]
		if value ~= nil then
			parts[#parts + 1] = key .. "\1" .. type(value) .. "\1" .. tostring(value)
		end
	end
	return table.concat(parts, "\2")
end






local function refreshSettingsWindow()
	if A.refreshOptionsWindow then
		pcall(A.refreshOptionsWindow)
	end
end




local function uiState()
	local db = A.db()
	if not db then
		return nil
	end
	if type(db.ui) ~= "table" then
		db.ui = {}
	end
	return db.ui
end


function A.debugEnabled()
	local ui = uiState()
	if ui == nil then
		return false
	end
	if ui.debug == true or ui.debug == false then
		return ui.debug
	end
	return A.debugDefault == true
end


function A.debugTextEnabled()
	local ui = uiState()
	return ui ~= nil and ui.debugText == true
end



function A.setDebug(enabled)
	local ui = uiState()
	if not ui then
		return false
	end
	ui.debug = enabled == true
	refreshSettingsWindow()
	return true
end



function A.setDebugText(enabled)
	local ui = uiState()
	if not ui then
		return false
	end
	if enabled == true then
		ui.debugText = true
	else
		ui.debugText = nil
	end
	A.trace("setting", {
		source = "debug-text",
		state = tostring(A.debugTextEnabled()),
	}, "data")
	refreshSettingsWindow()
	return true
end





local function store()
	local held = WowPvpHistoryDebugDB
	if type(held) ~= "table" then
		held = {}
		WowPvpHistoryDebugDB = held
	end
	if type(held.rings) ~= "table" then
		held.rings = {}
	end
	return held
end


local function ringFor(held, category)
	local ring = held.rings[category]
	if type(ring) ~= "table" then
		ring = {}
		held.rings[category] = ring
	end
	if type(ring.current) ~= "table" then
		ring.current = {}

		forget(category)
	end
	return ring
end


function A.debugStore()
	local held = WowPvpHistoryDebugDB
	if type(held) ~= "table" then
		return nil
	end
	return held
end





function A.debugEntries()
	local held = A.debugStore()
	if not held then
		return {}
	end

	local out = {}
	local function gather(list)
		if type(list) ~= "table" then
			return
		end
		for i = 1, #list do
			out[#out + 1] = list[i]
		end
	end

	gather(held.previous)
	gather(held.current)

	if type(held.rings) == "table" then

		for i = 1, #CATEGORIES do
			local ring = held.rings[CATEGORIES[i]]
			if type(ring) == "table" then
				gather(ring.previous)
				gather(ring.current)
			end
		end
		local marked = held.rings[BAD_CATEGORY]
		if type(marked) == "table" then
			gather(marked.previous)
			gather(marked.current)
		end
	end

	table.sort(out, function(a, b)
		return (a.seq or 0) < (b.seq or 0)
	end)
	return out
end


local function latestStamp(entry)
	local latest = entry.at
	local function later(stamp)
		if type(stamp) == "string" and (type(latest) ~= "string" or stamp > latest) then
			latest = stamp
		end
	end
	later(entry.lastAt)
	later(entry.againAt)
	return latest
end




function A.lastRingError()
	local entries = A.debugEntries()
	local best, bestAt = nil, nil
	for i = 1, #entries do
		local entry = entries[i]
		if type(entry) == "table" and entry.ev == "error" and entry.err ~= nil then
			local closedAt = latestStamp(entry)

			if best == nil or (type(closedAt) == "string" and (type(bestAt) ~= "string"
				or closedAt >= bestAt)) or (closedAt == nil and bestAt == nil) then
				best, bestAt = entry, closedAt
			end
		end
	end
	if best == nil then
		return nil
	end
	local rep = (type(best.rep) == "number" and best.rep or 1)
		+ (type(best.again) == "number" and best.again or 0)
	return {
		err = best.err,
		source = best.source,
		at = best.at,
		rep = rep,
		closedAt = bestAt,
	}
end




local function identityShaped(text)
	return text:match("^%a+%-%d") ~= nil or text:match("^%u[%w']*%-%u") ~= nil
end


local ERROR_MAX = 240


local ERROR_NAME = "<name>"


local ERROR_GUID = "<guid>"



local function errorText(value)
	local text = tostring(value)


	text = text:gsub("^Interface[\\/]+AddOns[\\/]+", "")


	text = text:gsub("[Pp]layer%-%d+%-%w+", ERROR_GUID)


	text = text:gsub("(%u[%w']*%w)%-(%u[%w']*%w)", ERROR_NAME)

	if #text > ERROR_MAX then
		text = text:sub(1, ERROR_MAX) .. "..."
	end
	return text
end




local function same(last, entry)
	if last.ev ~= entry.ev then
		return false
	end
	for i = 1, #FIELDS do
		local key = FIELDS[i]
		if last[key] ~= entry[key] then
			return false
		end
	end
	return true
end


local function scalar(value)
	local kind = type(value)
	if kind == "number" or kind == "boolean" then
		return value
	end
	if kind ~= "string" then
		return nil
	end
	if identityShaped(value) then
		return REFUSED
	end
	return value
end



function A.trace(ev, fields, cat)
	if not A.debugEnabled() or tracing then
		return
	end
	tracing = true
	local counted = cat or CATEGORY
	calls[counted] = (calls[counted] or 0) + 1

	local ok, err = pcall(function()
		local held = store()

		local category = CATEGORY
		if cat ~= nil then
			category = A.debugCategory(cat) and cat or BAD_CATEGORY
		end

		held.seq = (held.seq or 0) + 1
		local entry = { seq = held.seq, cat = category, ev = tostring(ev) }

		local stamped, at = pcall(A.stamp)
		if stamped then
			entry.at = at
		end

		if type(fields) == "table" then
			for i = 1, #FIELDS do
				local key = FIELDS[i]
				local kept
				if key == "err" then

					if fields.err ~= nil then
						kept = errorText(fields.err)
					end
				else
					kept = scalar(fields[key])
				end
				if kept ~= nil then
					entry[key] = kept
				end
			end
		end

		local ring = ringFor(held, category)
		local list = ring.current

		local last = list[#list]
		if last and same(last, entry) then

			held.seq = held.seq - 1
			last.rep = (last.rep or 1) + 1
			last.lastAt = entry.at
			return
		end



		local seen = memo[category]
		if seen == nil then
			seen = {}
			memo[category] = seen
		end

		local key = signature(entry)
		local stands = seen[key]


		if stands and list[stands.index] ~= stands.entry then
			stands = nil
		end

		if stands and stands.written >= SIGNATURE_ALLOWANCE then


			held.seq = held.seq - 1
			stands.entry.again = (stands.entry.again or 0) + 1
			if entry.at ~= nil then
				stands.entry.againAt = entry.at
			end
			return
		end

		list[#list + 1] = entry
		seen[key] = {
			index = #list,
			entry = entry,
			written = ((stands and stands.written) or 0) + 1,
		}

		if #list >= (BOUNDS[category] or BOUND_DEFAULT) then
			ring.previous = list
			ring.current = {}
			forget(category)
		end
	end)

	if ok then
		tracing = false
		return
	end



	pcall(function()
		A.noteError(err, "debug-ring")

		if not reported then
			reported = true
			A.say("the debug ring stopped recording: " .. tostring(err)
				.. ". /pvph debug off silences it")
		end
	end)

	tracing = false
end



function A.debugClear(cat)
	local held = A.debugStore()
	if not held then
		return 0
	end


	local cleared = A.debugHeld(cat)

	local function empty(ring)
		if type(ring) == "table" then
			ring.previous = nil
			ring.current = {}
		end
	end


	forget(cat)

	if cat ~= nil then
		if type(held.rings) == "table" then
			empty(held.rings[cat])
		end

		local function drain(list)
			if type(list) ~= "table" then
				return list
			end
			local kept = {}
			for i = 1, #list do
				if list[i].cat ~= cat then
					kept[#kept + 1] = list[i]
				end
			end
			return kept
		end
		held.previous = held.previous and drain(held.previous) or nil
		held.current = drain(held.current)
		return cleared
	end

	held.previous = nil
	held.current = {}
	if type(held.rings) == "table" then
		for i = 1, #CATEGORIES do
			empty(held.rings[CATEGORIES[i]])
		end
		empty(held.rings[BAD_CATEGORY])
	end
	return cleared
end






function A.debugIsolated(fn)
	local held, keptMemo, keptCalls = WowPvpHistoryDebugDB, memo, calls
	local aside = { rings = {} }
	WowPvpHistoryDebugDB = aside
	memo = {}
	calls = {}
	local ok, a, b = pcall(fn)
	WowPvpHistoryDebugDB, memo, calls = held, keptMemo, keptCalls
	if not ok then
		error(a, 0)
	end
	return aside, a, b
end







local function number(value)
	if value % 1 == 0 then
		return ("%d"):format(value)
	end
	local text = ("%.6f"):format(value):gsub("0+$", "")
	if text:sub(-1) == "." then
		return text .. "0"
	end
	return text
end
A.ringNumber = number


function A.debugLine(entry)
	local parts = {}
	for i = 1, #FIELDS do
		local key = FIELDS[i]
		local value = entry[key]
		if value ~= nil then
			if type(value) == "number" then
				value = number(value)
			else
				value = tostring(value)
			end
			parts[#parts + 1] = key .. "=" .. value
		end
	end

	local line = ("#%s %s %s/%s"):format(tostring(entry.seq), tostring(entry.at),
		tostring(entry.cat), tostring(entry.ev))


	if type(entry.rep) == "number" and entry.rep > 1 then
		line = line .. (" x%d"):format(entry.rep)
		if entry.lastAt ~= nil then
			line = line .. " to " .. tostring(entry.lastAt)
		end
	end


	if type(entry.again) == "number" and entry.again > 0 then
		line = line .. (" again%d"):format(entry.again)

		if entry.againAt ~= nil then
			line = line .. " last " .. tostring(entry.againAt)
		end
	end

	if #parts > 0 then
		line = line .. " " .. table.concat(parts, " ")
	end
	return line
end


local function filtered(cat)
	local entries = A.debugEntries()
	if cat == nil then
		return entries
	end

	local kept = {}
	for i = 1, #entries do
		if entries[i].cat == cat then
			kept[#kept + 1] = entries[i]
		end
	end
	return kept
end


function A.debugHeld(cat)
	return #filtered(cat)
end



function A.debugCensus()
	local out = {}
	for i = 1, #CATEGORIES do
		local name = CATEGORIES[i]
		local entries = filtered(name)

		local counts, top = {}, nil
		for j = 1, #entries do
			local ev = tostring(entries[j].ev)
			counts[ev] = (counts[ev] or 0) + 1

			if top == nil or counts[ev] > counts[top] then
				top = ev
			end
		end

		out[i] = {
			cat = name,
			held = #entries,
			bound = (BOUNDS[name] or BOUND_DEFAULT) * 2,
			top = top,
			topHeld = top and counts[top] or 0,
			names = top ~= nil and #entries > 0 and (counts[top] / #entries) > CENSUS_SHARE or false,
		}
	end
	return out
end


function A.debugCensusLine()
	local census = A.debugCensus()
	local parts = {}
	for i = 1, #census do
		local row = census[i]
		parts[i] = ("%s %d/%d"):format(row.cat, row.held, row.bound)
		if row.names then
			parts[i] = parts[i] .. (" %s %d"):format(row.top, row.topHeld)
		end
	end
	return table.concat(parts, ", ")
end





function A.debugLines(limit, cat)
	local entries = filtered(cat)


	if type(limit) == "number" then
		limit = math.floor(limit)
	end
	local from = 1
	if type(limit) == "number" and limit > 0 and #entries > limit then
		from = #entries - limit + 1
	end

	local lines = {}
	for i = from, #entries do
		lines[#lines + 1] = A.debugLine(entries[i])
	end
	return lines
end


local EXPORT_PREFIX = "WPHD!1!"


function A.debugExport()
	local lines = A.debugLines()
	if #lines == 0 then
		return nil, "the debug ring holds nothing"
	end
	return EXPORT_PREFIX .. table.concat(lines, " | "), nil, #lines
end



function A.openDebugExport()
	local said = {}
	local function say(line)
		said[#said + 1] = line
		A.say(line)
	end

	local text, why, entries = A.debugExport()
	if not text then
		say("debug export: " .. tostring(why))
		return false, said
	end

	say(("debug export is %d characters, holding %d %s")
		:format(#text, entries, entries == 1 and "entry" or "entries"))

	if not A.showTransfer("PvP history debug ring",
			"Ctrl+C copies it. There is no import: this describes one character's sessions.",
			text, nil, nil) then

		say("the copy window could not be opened, so the ring cannot be reached from here")
		return false, said
	end

	return true, said
end







A.on("PLAYER_LOGIN", function()
	local version, build
	local ok, one, two = pcall(GetBuildInfo)
	if ok then
		version, build = one, two
	end


	local db = A.db()
	local held = db and type(db.matches) == "table" and #db.matches or nil


	local ui = uiState()
	local stored = ui ~= nil and (ui.debug == true or ui.debug == false)

	A.trace("session", {
		version = A.version,
		build = (version and build) and (version .. "." .. build) or build,
		loaded = held,
		nextId = db and db.nextMatchId or nil,
		ringFrom = stored and "stored" or "default",
		ringDefault = A.debugDefault and "on" or "off",
	})
end)
