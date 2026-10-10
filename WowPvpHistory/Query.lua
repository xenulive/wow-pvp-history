





local _, A = ...








function A.matches(format, character)
	local db = A.db()
	if not db then
		return {}
	end

	local out = {}
	local list = db.matches
	for i = #list, 1, -1 do
		local record = list[i]
		if (format == nil or record.format == format) and A.recordedBy(record, character) then
			out[#out + 1] = record
		end
	end
	return out
end




function A.matchIdFromWord(word)
	if type(word) ~= "string" then
		return nil
	end
	local digits = word:match("^#?(%d+)$")
	if digits then
		return tonumber(digits)
	end
	local generated = word:match("^#?[Ff](%d+)$")
	if generated then
		return "F" .. (generated:gsub("^0+(%d)", "%1"))
	end
	return nil
end




function A.matchIdText(id)
	return tostring(id)
end




function A.match(id)
	local db = A.db()
	if not (db and (type(id) == "number" or type(id) == "string")) then
		return nil
	end

	local list = db.matches
	for i = #list, 1, -1 do
		if list[i].id == id then
			return list[i]
		end
	end
	return nil
end


function A.formats()
	local db = A.db()
	if not db then
		return {}
	end

	local seen, out = {}, {}
	for i = 1, #db.matches do
		local format = db.matches[i].format
		if format ~= nil and not seen[format] then
			seen[format] = true
			out[#out + 1] = format
		end
	end
	table.sort(out)
	return out
end













local EOL = 2
local COMMA = 1
local QUOTES = 2
local OPEN = 1
local CLOSE = 2
local STRING_KEY = 7
local NUMBER_KEY = 5




local SAVED_VARIABLE = "WowPvpHistoryDB"
local FILE_BYTES = EOL + #SAVED_VARIABLE + #(" = {") + EOL + #("}") + EOL




local CONSTANT_CEILING = 262143



local WARN_CONSTANTS = math.floor(CONSTANT_CEILING / 2)
local ALARM_CONSTANTS = math.floor(CONSTANT_CEILING * 0.8)



local DENSITY_FLOOR = 20


local function scalarBytes(value)
	local kind = type(value)
	if kind == "string" then
		return #value + QUOTES
	elseif kind == "number" then
		return #tostring(value)
	elseif kind == "boolean" then
		return value and 4 or 5
	end
	return nil
end




local function constantSet()
	return { set = {}, n = 0 }
end




local function constant(constants, value)
	if not constants then
		return
	end
	local kind = type(value)
	if kind ~= "string" and kind ~= "number" then
		return
	end
	if constants.set[value] == nil then
		constants.set[value] = true
		constants.n = constants.n + 1
	end
end


local function keyBytes(key)
	local kind = type(key)
	if kind == "string" then
		return #key + STRING_KEY
	elseif kind == "number" then
		return #tostring(key) + NUMBER_KEY
	end
	return nil
end



local EACH = {}






local function tableBytes(subject, constants, tap)
	local bytes = 0
	local count = #subject

	for i = 1, count do
		local value = subject[i]
		if type(value) == "table" then
			bytes = bytes + OPEN + EOL + tableBytes(value, constants, tap and tap[EACH]) + CLOSE + EOL
		else
			local width = scalarBytes(value)
			if width then
				bytes = bytes + width + COMMA + EOL
				constant(constants, value)
			end
		end
	end

	for key, value in pairs(subject) do
		local array = type(key) == "number" and key == math.floor(key)
			and key >= 1 and key <= count
		if not array then
			local width = keyBytes(key)
			if width then
				if type(value) == "table" then
					local watch = tap and type(key) == "string" and tap[key] or nil
					local block = width + OPEN + EOL
						+ tableBytes(value, constants, type(watch) == "table" and watch or nil)
						+ CLOSE + EOL
					if type(watch) == "function" then
						watch(block)
					end
					bytes = bytes + block
					constant(constants, key)
				else
					local scalar = scalarBytes(value)
					if scalar then
						bytes = bytes + width + scalar + COMMA + EOL
						constant(constants, key)
						constant(constants, value)
					end
				end
			end
		end
	end

	return bytes
end






local function walkStoredSize()
	local db = A.db()
	if not db then
		return { total = 0, matches = 0, generated = 0, real = 0,
			participants = 0, participantBytes = 0,
			participantShare = 0, indexBytes = 0, indexShare = 0,
			constants = 0, ceiling = CONSTANT_CEILING, headroom = CONSTANT_CEILING,
			density = nil, headroomMatches = nil }
	end


	local constants = constantSet()
	constant(constants, SAVED_VARIABLE)

	local participantBytes, indexBytes = 0, 0
	local tap = {
		matches = {
			[EACH] = {
				participants = function(block)
					participantBytes = participantBytes + block
				end,
			},
		},
		players = function(block)
			indexBytes = indexBytes + block
		end,
	}
	local total = tableBytes(db, constants, tap) + FILE_BYTES

	local list = type(db.matches) == "table" and db.matches or {}
	local participants = 0

	local generated = 0
	for i = 1, #list do
		local record = list[i]
		if type(record) == "table" and record[A.FIXTURE_KEY] == true then
			generated = generated + 1
		end
		local roster = type(record) == "table" and record.participants or nil
		if type(roster) == "table" then


			for _ in pairs(roster) do
				participants = participants + 1
			end
		end
	end


	local matches = #list

	local real = matches - generated

	local realConstants = constants
	if generated > 0 then
		local view = {}
		for key, value in pairs(db) do
			view[key] = value
		end
		local kept = {}
		for i = 1, #list do
			local record = list[i]
			if not (type(record) == "table" and record[A.FIXTURE_KEY] == true) then
				kept[#kept + 1] = record
			end
		end
		view.matches = kept
		if type(db.players) == "table" then
			local players = {}
			for guid, entry in pairs(db.players) do
				local only = type(entry) == "table" and type(entry.fixture) == "number"
					and type(entry.matches) == "number" and entry.fixture >= entry.matches
				if not only then
					players[guid] = entry
				end
			end
			view.players = players
		end
		realConstants = constantSet()
		constant(realConstants, SAVED_VARIABLE)
		tableBytes(view, realConstants)
	end
	local density, headroomMatches
	local headroom = CONSTANT_CEILING - constants.n
	if headroom < 0 then
		headroom = 0
	end
	if real >= DENSITY_FLOOR and realConstants.n > 0 then
		density = realConstants.n / real
		headroomMatches = math.floor(headroom / density)
	end

	return {
		total = total,
		matches = matches,
		generated = generated,
		real = real,
		participants = participants,
		participantBytes = participantBytes,

		participantShare = total > 0 and participantBytes / total or 0,
		indexBytes = indexBytes,
		indexShare = total > 0 and indexBytes / total or 0,
		constants = constants.n,
		ceiling = CONSTANT_CEILING,
		headroom = headroom,

		density = density,
		headroomMatches = headroomMatches,
	}
end


function A.storedSize()
	local started = type(A.switchClock) == "function" and A.switchClock() or nil
	local size = walkStoredSize()
	if started ~= nil then
		A.switchPhase("size", started)
	end
	return size
end


local function bytesText(bytes)
	if bytes < 1024 then
		return ("%d bytes"):format(bytes)
	end

	local scaled = bytes >= 1024 * 1024
		and ("%.1f MB"):format(bytes / (1024 * 1024))
		or ("%.1f KB"):format(bytes / 1024)
	return ("%s (%d bytes)"):format(scaled, bytes)
end


local function headroomText(size)
	if size.headroomMatches then

		return ("room for about %d more %s, at this history's %.0f values per match")
			:format(size.headroomMatches, size.headroomMatches == 1 and "match" or "matches",
				size.density)
	end

	return ("room for %d more distinct values. Too few matches stored to say what that is in "
		.. "matches"):format(size.headroom)
end



function A.sizeLines(size)
	local lines = {}

	lines[#lines + 1] = headroomText(size)
	local stored = ("  %d stored %s, %d participant %s")
		:format(size.matches, size.matches == 1 and "match" or "matches",
			size.participants, size.participants == 1 and "row" or "rows")

	if (size.generated or 0) > 0 then
		stored = stored .. (". %d of those %s generated, and /pvph debug fixture clear removes them")
			:format(size.generated, size.generated == 1 and "is" or "are")
	end
	lines[#lines + 1] = stored
	lines[#lines + 1] = ("  %d of %d distinct values used. Past that the client cannot load the "
		.. "file and the history is lost"):format(size.constants, size.ceiling)


	if type(A.debugTextEnabled) == "function" and A.debugTextEnabled() then
		lines[#lines + 1] = ("  %s total"):format(bytesText(size.total))
		lines[#lines + 1] = ("  rosters %s, %.0f%% of the total bytes")
			:format(bytesText(size.participantBytes), size.participantShare * 100)
		lines[#lines + 1] = ("  player index %s, %.0f%% of the total bytes")
			:format(bytesText(size.indexBytes), size.indexShare * 100)
	end

	return lines
end




function A.sizeReadings(size)
	local rows = {}

	if size.headroomMatches then
		rows[#rows + 1] = { key = "ROOM", clause = ("about %d more %s"):format(size.headroomMatches,
			size.headroomMatches == 1 and "match" or "matches") }
	end

	local stored = ("%d %s, %d participant %s"):format(size.matches,
		size.matches == 1 and "match" or "matches",
		size.participants, size.participants == 1 and "row" or "rows")

	if (size.generated or 0) > 0 then
		stored = stored .. (", %d generated"):format(size.generated)
	end
	rows[#rows + 1] = { key = "STORED", clause = stored }

	rows[#rows + 1] = {
		key = "USED",
		clause = ("%d of %d values"):format(size.constants, size.ceiling),
	}

	if type(A.debugTextEnabled) == "function" and A.debugTextEnabled() then
		rows[#rows + 1] = { key = "BYTES", clause = bytesText(size.total) }
		rows[#rows + 1] = {
			key = "ROSTERS",
			clause = ("%s, %.0f%% of the file"):format(bytesText(size.participantBytes),
				size.participantShare * 100),
		}
		rows[#rows + 1] = {
			key = "INDEX",
			clause = ("%s, %.0f%% of the file"):format(bytesText(size.indexBytes),
				size.indexShare * 100),
		}
	end

	return rows
end









function A.historyFigures()
	local rows = {}
	local db = A.db()
	local function put(key, value, sub, withdrawn)
		rows[#rows + 1] = { key = key, value = value, sub = sub, withdrawn = withdrawn }
		return rows[#rows]
	end

	local function counted(key, read)
		local ok, value, sub = pcall(read)
		if ok and (type(value) == "number" or type(value) == "string") then
			return put(key, tostring(value), sub)
		end
		return put(key, "-")
	end

	if not (db and type(db.matches) == "table") then
		for _, key in ipairs({ "MATCHES", "PLAYERS MET", "NOTES WRITTEN", "CHARACTERS", "FIRST MATCH",
			"SIZE" }) do
			put(key, nil, nil, "no-store")
		end
		return rows
	end

	local first = nil
	local function earliest(item)
		local stamp = item.openedAt or item.completedAt or item.endedAt
		if A.dayText(stamp) ~= nil and (first == nil or stamp < first) then
			first = stamp
		end
	end
	for i = 1, #db.matches do
		local record = db.matches[i]
		if type(record) == "table" and record.format ~= nil then
			earliest(record)
		end
	end
	for _, entry in ipairs(A.incompleteList()) do
		if type(entry) == "table" then
			earliest(entry)
		end
	end


	local okTotal, total = pcall(A.allCount)
	local empty = okTotal and total == 0
	if empty then
		for _, key in ipairs({ "MATCHES", "PLAYERS MET", "NOTES WRITTEN", "CHARACTERS" }) do
			put(key, nil, nil, "no-match")
		end
	end

	if not empty then

		counted("MATCHES", function()
			local count, left = A.allCount()
			return count, left > 0 and ("and %d left early"):format(left) or nil
		end)

		local okIndex, built = pcall(A.encounterIndex)
		local index = (okIndex and type(built) == "table") and built or nil
		local okView, view = pcall(A.playersView, { index = index })
		local strip = okView and type(view) == "table" and view.strip or nil
		counted("PLAYERS MET", function()


			local held = assert(index, "the encounter index did not build")
			local met = A.playersMet(held)
			local again = 0
			for i = 1, #met do
				if #(held[met[i].guid] or {}) > 1 then
					again = again + 1
				end
			end
			return #met, ("%d met again"):format(again)
		end)
		counted("NOTES WRITTEN", function()
			local held = assert(strip, "the Players strip did not read")
			return held.notes, ("on %d %s"):format(held.noted, held.noted == 1 and "player" or "players")
		end)
		counted("CHARACTERS", function()
			local list = A.characterList()
			local realms, seen = 0, {}
			for _, held in ipairs(list) do
				if type(held.realm) == "string" and held.realm ~= "" and not seen[held.realm] then
					seen[held.realm] = true
					realms = realms + 1
				end
			end
			return #list, realms > 0 and ("on %d %s"):format(realms, realms == 1 and "realm" or "realms") or nil
		end)
	end

	if first then
		put("FIRST MATCH", A.dayText(first)).stamp = first
	else
		put("FIRST MATCH", nil, nil, "no-dated-record")
	end

	if type(A.debugTextEnabled) == "function" and A.debugTextEnabled() then
		local ok, bytes = pcall(function()
			for _, reading in ipairs(A.sizeReadings(A.storedSize())) do
				if reading.key == "BYTES" then
					return reading.clause
				end
			end
			return nil
		end)
		if ok and type(bytes) == "string" then
			put("SIZE", bytes)
		else
			put("SIZE", "-")
		end
	else
		put("SIZE", nil, nil, "switch-off")
	end
	return rows
end





function A.sizeBand(size)
	local used = type(size) == "table" and tonumber(size.constants) or 0
	if used >= ALARM_CONSTANTS then
		return "loss"
	elseif used >= WARN_CONSTANTS then
		return "caution"
	end
	return "ok"
end



function A.sizeShare(size)
	local used = type(size) == "table" and tonumber(size.constants) or 0
	local ceiling = type(size) == "table" and tonumber(size.ceiling) or 0
	if ceiling <= 0 or used <= 0 then
		return "0%", 0
	end
	local share = used / ceiling
	local percent = math.floor(share * 100 + 0.5)
	if percent < 1 then
		return "<1%", share
	end
	return ("%d%%"):format(percent), share
end


function A.sizeNoticeLine(size)
	local band = A.sizeBand(size)
	if band == "ok" then
		return nil
	end

	local left = size.headroomMatches
		and ("about %d more %s"):format(size.headroomMatches,
			size.headroomMatches == 1 and "match" or "matches")
		or ("%d constants"):format(size.headroom)

	if band == "loss" then


		return ("stored history is %d constants of %d. Past the limit the client cannot load it "
			.. "and the history is lost. Room for %s. /pvph size")
			:format(size.constants, size.ceiling, left)
	end

	return ("stored history is past half the %d constant limit. Room for %s. /pvph size")
		:format(size.ceiling, left)
end









function A.playerAllGenerated(entry)
	if type(entry) ~= "table" then
		return false
	end
	local matches = entry.matches
	if type(matches) ~= "number" or matches <= 0 then
		return false
	end
	local fixture = entry.fixture
	return type(fixture) == "number" and fixture >= matches
end



local function entryCount(entry)
	local n = entry.matches
	return (type(n) == "number" and n == n) and n or 0
end

local function entryName(entry)
	local names = entry.names
	local first = type(names) == "table" and names[1] or nil
	return type(first) == "string" and first or nil
end




local function playerOrder(a, b)
	local ag, bg = A.playerAllGenerated(a.entry), A.playerAllGenerated(b.entry)
	if ag ~= bg then
		return bg
	end

	local am, bm = entryCount(a.entry), entryCount(b.entry)
	if am ~= bm then
		return am > bm
	end

	local an, bn = entryName(a.entry), entryName(b.entry)
	if an ~= bn then
		if an == nil then
			return false
		end
		if bn == nil then
			return true
		end
		return an < bn
	end

	return tostring(a.guid) < tostring(b.guid)
end


local function notedNames(note)
	local names = {}
	if type(note) == "table" and type(note.name) == "string" and note.name ~= "" then
		names[1] = note.name
	end
	return names
end





function A.playerEntry(guid)
	if type(guid) ~= "string" or guid == "" then
		return nil
	end

	local db = A.db()
	if not db then
		return nil
	end

	local index = type(db.players) == "table" and db.players or {}
	if type(index[guid]) == "table" then
		return { guid = guid, entry = index[guid], indexed = true }, true
	end

	local note = A.noteFor(guid)
	local names = notedNames(note)

	if names[1] == nil and type(A.clientPlayerName) == "function" then
		local ok, name = pcall(A.clientPlayerName, guid)
		if ok and name then
			names[1] = name
		end
	end
	return { guid = guid, entry = { names = names }, indexed = false }, note ~= nil
end




function A.players()
	local db = A.db()
	if not db then
		return {}
	end

	local index = type(db.players) == "table" and db.players or {}

	local out = {}
	for guid, entry in pairs(index) do
		if type(entry) == "table" then
			out[#out + 1] = { guid = guid, entry = entry, indexed = true }
		end
	end

	local notes = type(db.notes) == "table" and db.notes or {}
	for guid, note in pairs(notes) do
		if type(note) == "table" and type(index[guid]) ~= "table" then
			out[#out + 1] = { guid = guid, entry = { names = notedNames(note) }, indexed = false }
		end
	end

	table.sort(out, playerOrder)
	return out
end








local function twoByte(code)
	return string.char(0xC0 + math.floor(code / 64), 0x80 + code % 64)
end




local FOLD = {}
do
	local function pair(upper, lower)
		FOLD[twoByte(upper)] = lower < 0x80 and string.char(lower) or twoByte(lower)
	end

	for code = 0xC0, 0xDE do
		if code ~= 0xD7 then
			pair(code, code + 0x20)
		end
	end
	for code = 0x100, 0x136, 2 do
		pair(code, code + 1)
	end
	pair(0x130, 0x69)
	for code = 0x139, 0x147, 2 do
		pair(code, code + 1)
	end
	for code = 0x14A, 0x176, 2 do
		pair(code, code + 1)
	end
	pair(0x178, 0xFF)
	for code = 0x179, 0x17D, 2 do
		pair(code, code + 1)
	end

	for code = 0x410, 0x42F do
		pair(code, code + 0x20)
	end
	for code = 0x400, 0x40F do
		pair(code, code + 0x50)
	end
end




function A.foldText(text)
	if type(text) ~= "string" then
		return text
	end
	local lowered = text:lower()
	if not lowered:find("[\128-\255]") then
		return lowered
	end
	return (lowered:gsub("[\192-\223][\128-\191]", FOLD))
end




local function nameMatches(entry, needle)
	local names = entry and entry.names or {}
	for i = 1, #names do
		if type(names[i]) == "string" and A.foldText(names[i]):find(needle, 1, true) then
			return true
		end
	end
	return false
end



function A.findPlayers(text)
	if type(text) ~= "string" or text == "" then
		return {}
	end

	local needle = A.foldText(text)
	local out = {}
	for _, item in ipairs(A.players()) do
		if nameMatches(item.entry, needle) then
			out[#out + 1] = item
		end
	end
	return out
end




local function searchTrim(text)
	return (text:gsub("^%s+", ""):gsub("%s+$", ""))
end



function A.searchTerms(text)
	local out = {}
	if type(text) ~= "string" then
		return out
	end
	for piece in (text .. ","):gmatch("([^,]*),") do
		local term = searchTrim(piece)
		local lead = term:sub(1, 1)
		local exclude = lead == "-" or lead == "!"
		if exclude then
			term = searchTrim(term:sub(2))
		end
		if term ~= "" then
			out[#out + 1] = { text = A.foldText(term), exclude = exclude }
		end
	end
	return out
end



local function searchFields(record)
	local fields = {}
	if type(record) ~= "table" then
		return fields
	end
	local function add(value)
		if type(value) == "string" and value ~= "" then
			fields[#fields + 1] = A.foldText(value)
		end
	end
	if type(record.map) == "table" then
		add(record.map.name)
	end

	add(record.opponentName)
	if type(record.participants) == "table" then
		for _, p in pairs(record.participants) do
			if type(p) == "table" then
				add(p.name)
				local spec = type(p.spec) == "string" and p.spec ~= "" and p.spec or nil
				local class = type(p.class) == "string" and p.class ~= "" and p.class or nil
				if spec and class then
					add(("%s %s"):format(spec, class))
				else
					add(spec or class)
				end
			end
		end
	end
	return fields
end



function A.searchMatches(record, terms)
	if type(terms) ~= "table" or #terms == 0 then
		return true
	end
	local fields = searchFields(record)
	for i = 1, #terms do
		local term = terms[i]
		local found = false
		for j = 1, #fields do
			if fields[j]:find(term.text, 1, true) then
				found = true
				break
			end
		end
		if found == term.exclude then
			return false
		end
	end
	return true
end




function A.resultFilterPasses(record, choice)
	if choice == nil then
		return true
	end
	if type(record) ~= "table" then
		return false
	end
	local tone = A.resultTone(record)
	if choice == "won" then
		return tone == "win"
	end
	if choice == "lost" then
		return tone == "loss"
	end
	if choice ~= "even" or tone ~= nil then
		return false
	end
	local stored = record.result
	if stored == nil and type(record.manual) == "table" then
		stored = record.manual.result
	end
	if stored ~= nil then
		return stored == "draw"
	end
	return A.roundsVerdict(record) == "draw"
end



function A.specFilterPasses(record, choice)
	if choice == nil then
		return true
	end
	local own = A.rowSelfSpec(record)
	return own ~= nil and own:lower() == tostring(choice):lower()
end




function A.playedSpecs(format, character, scope)
	local season = type(scope) == "table" and scope.season or nil
	local bound = type(scope) == "table" and scope.bound or nil
	local counts, order = {}, {}
	local matches = A.matches(format, character)
	for i = 1, #matches do
		local record = matches[i]
		local held = A.recordSince(record, bound)
		if held and season ~= nil then
			held = type(A.recordSeason) ~= "function" or A.recordSeason(record) == season
		end
		if held then
			local spec = A.rowSelfSpec(record)
			if spec ~= nil then
				if counts[spec] == nil then
					counts[spec] = 0
					order[#order + 1] = spec
				end
				counts[spec] = counts[spec] + 1
			end
		end
	end
	table.sort(order, function(a, b)
		if counts[a] ~= counts[b] then
			return counts[a] > counts[b]
		end
		return a < b
	end)
	local out = {}
	for i = 1, #order do
		out[i] = { spec = order[i], count = counts[order[i]] }
	end
	return out
end








function A.matchRoster(record, text)
	if type(record) ~= "table" or type(record.participants) ~= "table" then
		return {}
	end

	local db = A.db()
	local index = (db and type(db.players) == "table") and db.players or {}
	local needle = (type(text) == "string" and text ~= "") and A.foldText(text) or nil

	local out = {}
	for guid, participant in pairs(record.participants) do
		if type(guid) == "string" and type(participant) == "table" and guid ~= record.character then
			local entry, indexed = index[guid], true
			if type(entry) ~= "table" then
				indexed = false
				entry = { names = {} }
				if type(participant) == "table" and type(participant.name) == "string" then
					entry.names[1] = participant.name
				end
			end
			if not needle or nameMatches(entry, needle) then
				out[#out + 1] = {
					guid = guid,
					entry = entry,

					name = entryName(entry) or guid,
					indexed = indexed,
				}
			end
		end
	end


	table.sort(out, playerOrder)
	return out
end



function A.rosterPlayers(record)
	local out = {}
	for _, item in ipairs(A.matchRoster(record)) do
		if not A.isBotGuid(item.guid) then
			out[#out + 1] = item
		end
	end
	return out
end








A.KNOWN_NAME_CAP = 5
local KNOWN_NAME_CAP = A.KNOWN_NAME_CAP





function A.knownPlayers(guids, selfGuid)
	local known = { offered = 0, found = 0, with = 0, against = 0, names = {} }
	if type(guids) ~= "table" then
		return known
	end

	local db = A.db()
	local players = (db and type(db.players) == "table") and db.players or {}

	local seen, hits = {}, {}
	for i = 1, #guids do
		local guid = guids[i]
		if type(guid) == "string" and guid ~= "" and guid ~= selfGuid and not seen[guid] then
			seen[guid] = true
			known.offered = known.offered + 1

			local entry = players[guid]
			if type(entry) == "table" then
				known.found = known.found + 1
				known.with = known.with + ((entry.with and entry.with.count) or 0)
				known.against = known.against + ((entry.against and entry.against.count) or 0)
				hits[#hits + 1] = { guid = guid, entry = entry }
			end
		end
	end


	table.sort(hits, playerOrder)


	known.guids = {}
	for i = 1, #hits do
		local names = hits[i].entry.names
		known.names[i] = tostring((names and names[1]) or hits[i].guid)
		known.guids[i] = hits[i].guid
	end

	return known
end












function A.knownOnOwnSide(rows, selfName, selfQualified, nameIndex)
	if type(rows) ~= "table" then
		return nil, "no-self"
	end

	local selfFaction
	local factions, distinct = {}, 0
	for i = 1, #rows do
		local row = rows[i]
		local name = type(row) == "table" and row.name or nil
		local faction = type(row) == "table" and row.faction or nil
		if name ~= nil and (name == selfName or name == selfQualified) then
			selfFaction = faction
		end
		if faction ~= nil and not factions[faction] then
			factions[faction] = true
			distinct = distinct + 1
		end
	end
	if selfFaction == nil then
		return nil, "no-self"
	end
	if distinct < 2 then
		return nil, "one-side"
	end

	local index = type(nameIndex) == "table" and nameIndex or A.playerNameIndex()
	local guids, seen, offered = {}, {}, 0
	for i = 1, #rows do
		local row = rows[i]
		local name = row.name
		if type(name) == "string" and name ~= "" and name ~= selfName and name ~= selfQualified
			and row.faction == selfFaction and not seen[name]
		then
			seen[name] = true
			offered = offered + 1
			local guid = A.playerByName(index, name)
			if guid then
				guids[#guids + 1] = guid
			end
		end
	end

	local known = A.knownPlayers(guids, nil)
	known.offered = offered
	return known, guids
end


local function matchNoun(count)
	return ("%d %s"):format(count, count == 1 and "match" or "matches")
end






local SIDE_WORDS = { with = "together", against = "against" }
local SIDES = { "with", "against" }




local KNOWN_CONTEXTS = {
	group = {
		"in this group is in your history",
		"in this group are in your history",
	},
	match = {
		"in that match was in your history before it",
		"in that match were in your history before it",
	},
}


local function knownClause(context, found)
	local pair = KNOWN_CONTEXTS[context] or KNOWN_CONTEXTS.group
	return found == 1 and pair[1] or pair[2]
end





function A.knownLine(known, context)
	if type(known) ~= "table" or (known.offered or 0) == 0 then
		return nil
	end

	local found = known.found or 0
	if found == 0 and context == "group" then
		return nil
	end
	local sentence = ("%d of %d %s"):format(found, known.offered, knownClause(context, found))

	local names = known.names or {}
	if #names > 0 then
		local shown = {}


		local guids = known.guids or {}
		for i = 1, math.min(#names, KNOWN_NAME_CAP) do
			shown[i] = guids[i] and A.playerLink(guids[i], names[i]) or names[i]
		end
		sentence = sentence .. ": " .. table.concat(shown, ", ")
		local rest = #names - #shown
		if rest > 0 then
			sentence = sentence .. (" and %d more"):format(rest)
		end
		sentence = sentence .. "."
	end


	local sides = {}
	if (known.with or 0) > 0 then
		sides[#sides + 1] = ("%d %s"):format(known.with, SIDE_WORDS.with)
	end
	if (known.against or 0) > 0 then
		sides[#sides + 1] = ("%d %s"):format(known.against, SIDE_WORDS.against)
	end


	return A.joinSentences({ sentence, table.concat(sides, ", ") })
end


function A.pendingLine()
	local pending = A.pendingMatches and A.pendingMatches() or 0
	if pending < 1 then

		return nil
	end
	return ("%s %s disk on /reload or logout. /pvph to check what is held.")
		:format(matchNoun(pending), pending == 1 and "reaches" or "reach")
end






local function put(parts, text)
	if text ~= nil then
		parts[#parts + 1] = text
	end
end




local function clause(parts, value, form)
	if value == nil then
		return
	end
	parts[#parts + 1] = form and form:format(tostring(value)) or tostring(value)
end









local function ratedFormat(entry)
	local ratings = type(entry) == "table" and entry.ratings or nil
	if type(ratings) ~= "table" then
		return nil
	end

	local formats = type(entry.formats) == "table" and entry.formats or {}
	local best, bestCount
	for format, reading in pairs(ratings) do
		if type(reading) == "table" then
			local count = type(formats[format]) == "number" and formats[format] or 0
			if best == nil or count > bestCount or (count == bestCount and format < best) then
				best, bestCount = format, count
			end
		end
	end
	return best
end




function A.playerSummary(guid)
	if type(guid) ~= "string" or guid == "" then
		return nil
	end

	local db = A.db()
	if not db then
		return nil
	end

	local index = type(db.players) == "table" and db.players or {}
	local entry = index[guid]
	if type(entry) ~= "table" then
		entry = nil
	end

	local note = A.noteFor(guid)
	if not (entry or note) then
		return nil
	end

	local out = { guid = guid, indexed = entry ~= nil }

	if entry then
		out.name = type(entry.names) == "table" and entry.names[1] or nil
		out.matches = entry.matches
		out.with = entry.with
		out.against = entry.against
		out.undetermined = entry.undetermined
		out.lastSeen = entry.lastSeen

		local format = ratedFormat(entry)
		if format then
			out.format = format
			out.rating = entry.ratings[format]
		end
	end

	if note then
		out.name = out.name or (type(note.name) == "string" and note.name or nil)
		out.rated = note.rating
		out.tags = note.tags
		out.text = note.text
	end

	return out
end




local function tooltipSide(key, bucket, whole)
	if type(bucket) ~= "table" or (bucket.count or 0) == 0 then
		return nil
	end
	local head = whole and matchNoun(bucket.count) or tostring(bucket.count)
	local text = ("%s %s"):format(head, SIDE_WORDS[key] or key)
	local decided = bucket.decided or 0
	if decided == 0 then
		return text
	end
	return ("%s, won %d of %d decided"):format(text, bucket.wins or 0, decided)
end



local function soleSide(summary)
	local matches = tonumber(summary.matches)
	if not matches or matches <= 0 then
		return nil
	end
	for i = 1, #SIDES do
		local bucket = summary[SIDES[i]]
		if type(bucket) == "table" and (bucket.count or 0) == matches then
			return SIDES[i]
		end
	end
	return nil
end




function A.playerRecordText(guid)
	local summary = A.playerSummary(guid)
	if not (summary and summary.indexed) then
		return nil
	end

	local record = {}
	local sole = soleSide(summary)
	if sole then
		record[1] = tooltipSide(sole, summary[sole], true)

		if A.playerAllGenerated(summary) then
			record[#record + 1] = "all generated"
		end
	else
		record[1] = A.matchCountText(summary)
		put(record, tooltipSide("with", summary.with))
		put(record, tooltipSide("against", summary.against))
	end
	return table.concat(record, ", ")
end












function A.playerTooltipLines(guid, now, index)
	local summary = A.playerSummary(guid)
	if not summary then
		return {}, nil
	end
	local facts = A.playerCardFacts(guid, now, index)
	if not facts then
		return {}, nil
	end

	local dash = A.colorEscape("dimmer") .. "-|r"
	local met = dash
	if (facts.met or 0) > 0 then
		met = tostring(facts.met)
		if facts.ago then
			met = ("%s, last %s"):format(met, facts.ago)
		end
	end


	local items = {
		{ kind = "pair", part = "with", left = "With you", right = A.sideShortMarkup(facts.with),
			leftColor = "dim", rightColor = "text" },
		{ kind = "pair", part = "against", left = "Against", right = A.sideShortMarkup(facts.against),
			leftColor = "dim", rightColor = "text" },
		{ kind = "pair", part = "met", left = "Met", right = met, leftColor = "dim", rightColor = "text" },
	}

	if facts.note then
		items[#items + 1] = { kind = "line", part = "note",
			text = A.colorEscape("noteWord") .. "Note|r " .. facts.note, color = "text", wrap = true }
	end

	if #facts.tags > 0 then
		items[#items + 1] = { kind = "line", part = "tags", text = table.concat(facts.tags, ", "),
			color = "dim", wrap = true }
	end

	local reading = summary.rating
	if type(reading) == "table" and type(reading.rating) == "number" then
		local _, escape = A.ratingColour(summary.format, reading.rating)
		local figure = tostring(reading.rating)
		if escape then
			figure = escape .. figure .. "|r"
		end
		items[#items + 1] = { kind = "pair", part = "lastSeen", left = "Last seen at",
			right = ("%s %s"):format(figure, A.formatLabel(summary.format)),
			leftColor = "dimmer", rightColor = "text" }
	end

	return items, facts
end







local NOTED_LINE_CAP = 5


local function notedName(entry, note, guid)
	local names = entry and entry.names
	if type(names) == "table" and type(names[1]) == "string" and names[1] ~= "" then
		return names[1]
	end
	if note and type(note.name) == "string" and note.name ~= "" then
		return note.name
	end
	return tostring(guid)
end






function A.authoredInGroup(guids, selfGuid)
	local out = {}
	if type(guids) ~= "table" then
		return out
	end

	local db = A.db()
	local players = (db and type(db.players) == "table") and db.players or {}

	local seen = {}
	for i = 1, #guids do
		local guid = guids[i]
		if type(guid) == "string" and guid ~= "" and guid ~= selfGuid and not seen[guid] then
			seen[guid] = true
			local digest = A.authoredDigest(guid)
			if digest then
				local entry = players[guid]
				if type(entry) ~= "table" then
					entry = { names = {} }
				end
				out[#out + 1] = { guid = guid, entry = entry, note = A.noteFor(guid) }
			end
		end
	end

	table.sort(out, playerOrder)
	return out
end



local function commentCount(note)
	local n = type(note.comments) == "table" and #note.comments or 0
	if n == 0 then
		return nil
	end
	return ("%d %s"):format(n, n == 1 and "comment" or "comments")
end



function A.authoredClause(note)
	if type(note) ~= "table" then
		return nil
	end
	local parts = {}
	put(parts, A.ratingText(note.rating))
	if type(note.tags) == "table" and #note.tags > 0 then
		put(parts, table.concat(note.tags, ", "))
	end
	if note.text ~= nil then
		put(parts, tostring(note.text))
	end
	put(parts, commentCount(note))
	if #parts == 0 then
		return nil
	end
	return table.concat(parts, "  ")
end



function A.sightLine(guid)
	local db = A.db()
	local players = (db and type(db.players) == "table") and db.players or {}
	local note = A.noteFor(guid)
	local name = notedName(players[guid], note, guid)
	local parts = { A.playerLink(guid, name) .. " is here" }
	put(parts, A.authoredClause(note))
	return table.concat(parts, "  ")
end



function A.authoredGroupLines(noted)
	if type(noted) ~= "table" or #noted == 0 then
		return {}
	end

	local shown = #noted
	if shown > NOTED_LINE_CAP then
		shown = NOTED_LINE_CAP
	end

	local lines = {}
	for i = 1, shown do
		local item = noted[i]
		local note = item.note or {}
		local name = notedName(item.entry, note, item.guid)

		local parts = { A.playerLink(item.guid, name) }
		put(parts, A.authoredClause(note))
		lines[#lines + 1] = "  " .. table.concat(parts, "  ")
	end

	local rest = #noted - shown
	if rest > 0 then
		lines[#lines + 1] = ("  and %d more with something written. /pvph notes"):format(rest)
	end

	return lines
end










function A.incompleteList(character)
	local db = A.db()
	if not (db and type(db.incomplete) == "table") then
		return {}
	end

	local out = {}
	for i = #db.incomplete, 1, -1 do
		if A.recordedBy(db.incomplete[i], character) then
			out[#out + 1] = db.incomplete[i]
		end
	end
	return out
end



function A.incompleteCounts(entries)
	local counts = { left = 0, abandoned = 0, rated = 0, total = 0 }
	for _, entry in ipairs(type(entries) == "table" and entries or A.incompleteList()) do
		counts.total = counts.total + 1
		if entry.reason == "left" then
			counts.left = counts.left + 1
		elseif entry.reason == "abandoned" then
			counts.abandoned = counts.abandoned + 1
		end

		if entry.rated == true then
			counts.rated = counts.rated + 1
		end
	end
	return counts
end


local function spanText(seconds)
	if type(seconds) ~= "number" or seconds < 0 then
		return nil
	end
	if seconds < 60 then
		return ("%ds"):format(seconds)
	end
	return ("%dm%02ds"):format(math.floor(seconds / 60), seconds % 60)
end


function A.lengthText(seconds)
	return spanText(seconds)
end



local REASON_TEXT = {
	["disconnect"] = "Disconnect",
	["crash"] = "Crash",
	["client-closed"] = "Game closed",
	["chose-to-leave"] = "Chose to leave",
	["kicked"] = "Kicked",
}

function A.reasonLabel(token)
	if token == nil then
		return nil
	end
	return REASON_TEXT[token] or tostring(token)
end




function A.reasonChoices()
	local out = {}
	for _, token in ipairs(A.manualReasons()) do
		out[#out + 1] = { reason = token, label = A.reasonLabel(token) }
	end
	out[#out + 1] = { label = "Not set" }
	return out
end



local function capturedCells(entry, pane)
	local parts = {}


	clause(parts, entry.id, "#%s")

	put(parts, entry.reason == "abandoned" and "abandoned" or "left")


	if entry.rated == true then
		put(parts, "RATED")
	elseif entry.rated == false then
		put(parts, "unrated")
	elseif not pane then
		put(parts, "rated state unknown")
	end

	if type(entry.surfaceFormat) == "string" then
		put(parts, A.formatLabel(entry.surfaceFormat))
	end

	clause(parts, entry.map and entry.map.name)
	put(parts, spanText(entry.seconds))
	if (entry.rounds or 0) > 0 then
		put(parts, ("%d rounds"):format(entry.rounds))
	end
	clause(parts, entry.openedAt, "opened %s")


	if entry.openedState ~= nil and entry.openedState ~= "StartUp" then
		put(parts, ("seen from %s"):format(tostring(entry.openedState)))
	end

	return parts
end



local function authoredCells(entry)
	local parts = {}
	local manual = type(entry) == "table" and entry.manual or nil
	if type(manual) ~= "table" then
		return parts
	end
	clause(parts, A.reasonLabel(manual.reason), "reason %s")
	clause(parts, manual.note, "note: %s")
	return parts
end


function A.incompleteLine(entry)
	local parts = capturedCells(entry)
	for _, text in ipairs(authoredCells(entry)) do
		put(parts, text)
	end
	return table.concat(parts, "  ")
end



function A.incompleteDigest(entry)
	local manual = type(entry) == "table" and entry.manual or nil
	if type(manual) ~= "table" then
		return nil
	end

	local parts = {}
	put(parts, A.reasonLabel(manual.reason))
	if manual.note ~= nil then
		put(parts, "note")
	end

	if #parts == 0 then

		return "edited"
	end
	return table.concat(parts, ", ")
end



function A.incompleteRowText(entry)
	local cells = capturedCells(entry, true)
	local digest = A.incompleteDigest(entry)
	if digest then
		local manual = type(entry) == "table" and entry.manual or nil
		local marked = ("[%s]"):format(digest)


		local word = entry.reason == "abandoned" and "abandoned" or "left"
		local placed = false
		if A.reasonLabel(type(manual) == "table" and manual.reason or nil) then
			for i = 1, #cells do
				if cells[i] == word then
					cells[i] = marked
					placed = true
					break
				end
			end
		end
		if not placed then
			table.insert(cells, 3, marked)
		end
	end
	return table.concat(cells, "  ")
end


function A.incompleteDetailLines(entry)
	local lines = {}

	local head = {}
	clause(head, entry.id, "#%s")
	put(head, entry.reason == "abandoned" and "abandoned" or "left")
	if entry.rated == true then
		put(head, "RATED")
	elseif entry.rated == false then
		put(head, "unrated")
	end
	if type(entry.surfaceFormat) == "string" then
		put(head, A.formatLabel(entry.surfaceFormat))
	end
	clause(head, entry.map and entry.map.name)
	lines[#lines + 1] = table.concat(head, "  ")

	local when = {}
	clause(when, entry.openedAt, "opened %s")
	local span = spanText(entry.seconds)
	clause(when, span, "ran %s")

	put(when, A.durationCaveat(entry.openedState))


	clause(when, entry.endedAt, entry.reason == "abandoned" and "noticed %s" or "ended %s")
	if (entry.rounds or 0) > 0 then
		put(when, ("%d rounds"):format(entry.rounds))
	end
	if #when > 0 then
		lines[#lines + 1] = "  " .. table.concat(when, "  ")
	end

	local reason = A.reasonLabel(type(entry.manual) == "table" and entry.manual.reason or nil)
	if reason then
		lines[#lines + 1] = "  reason " .. reason
	end



	return lines
end



function A.incompleteNoticeLine()
	local counts = A.incompleteCounts()
	if counts.total == 0 then
		return nil
	end

	local text = ("%d incomplete: %d left, %d abandoned")
		:format(counts.total, counts.left, counts.abandoned)
	if counts.rated > 0 then
		text = text .. (", %d of them rated"):format(counts.rated)
	end
	return text .. ". /pvph left"
end





function A.duelPatternLine(state)
	if type(state) ~= "table" then
		return nil
	end
	local read, expected = tonumber(state.patterns) or 0, tonumber(state.expected) or 0
	return ("%d of %d winner lines readable%s"):format(read, expected,
		read < expected and ", so a duel decided that way stores no result" or "")
end




function A.fontsLine(loaded, gated, whole)
	if type(gated) == "string" and whole == true then
		return ("fonts: the client's own, because the shipped faces do not carry the script a %s "
			.. "client draws its names in"):format(gated)
	end
	if type(gated) == "string" then
		local scriptClause = ("names and text draw in the client's own, because the shipped text "
			.. "face does not carry the script a %s client draws its names in"):format(gated)
		if loaded == nil then
			return "fonts: " .. scriptClause .. ". Nothing else has drawn yet, so whether the "
				.. "figures' face loads is unanswered"
		end
		if loaded then
			return "fonts: the figures' shipped face loaded, and " .. scriptClause
		end
		return "fonts: the figures' shipped face did not load, so the window is drawing in the "
			.. "client's own, and " .. scriptClause
	end
	if loaded == nil then
		return "fonts: nothing has drawn yet, so whether the shipped faces load is unanswered"
	end
	if loaded then
		return "fonts: the shipped faces loaded"
	end
	return "fonts: the shipped faces did not load, so the window is drawing in the client's own"
end



function A.linksLine(available)
	if available then
		return "links: the link after a match and a name in an alert can be clicked"
	end
	return "links: this client has no link surface, so no link prints after a match"
end



function A.tooltipLine(available)
	if available then
		return "tooltip: a player already recorded carries their record on their unit tooltip"
	end
	return "tooltip: this client has no tooltip surface, so no unit tooltip carries a record"
end




function A.menuLine(took, offered)
	took = type(took) == "number" and took or 0
	offered = type(offered) == "number" and offered or 0

	if offered == 0 then
		return "menu: no tag is offered, so a right-click carries no entry"
	end
	if took == 0 then
		return ("menu: this client took none of the %d registrations, so a right-click carries no "
			.. "entry"):format(offered)
	end
	if took < offered then
		return ("menu: %d of %d registrations took. /pvph debug show ui says which reached a menu")
			:format(took, offered)
	end
	return ("menu: all %d registrations took. /pvph debug show ui says which reached a menu")
		:format(offered)
end






function A.harvestLine(record)
	local harvest = record.harvest

	if type(harvest) ~= "table" then
		return nil
	end

	local parts = {}



	if harvest.attempts ~= nil then
		local attempt = harvest.attempts == 0 and "stash"
			or ("attempt " .. tostring(harvest.attempts))
		if type(harvest.readAt) == "number" then
			attempt = attempt .. (" at %.1fs"):format(harvest.readAt)
		end
		put(parts, attempt)
	end



	if harvest.rows ~= nil then
		local rows = tostring(harvest.rows) .. " rows"
		if type(harvest.readSeconds) == "number" then
			rows = rows .. (" in %.2fms"):format(harvest.readSeconds * 1000)
		end
		put(parts, rows)
	end

	clause(parts, harvest.guard, "guard=%s")


	clause(parts, harvest.matchSurface, "surface=%s")
	clause(parts, harvest.restriction, "PvPMatch restriction %s")


	if harvest.version ~= nil then
		local build = tostring(harvest.version)
		if harvest.build ~= nil then
			build = build .. "." .. tostring(harvest.build)
		end
		put(parts, "build " .. build)
	end

	return "harvest: " .. table.concat(parts, ", ")
end




function A.lastLines(record)
	local lines = {}


	lines[#lines + 1] = ("last: #%s %s bracket=%s rated=%s result=%s participants=%s")
		:format(tostring(record.id or 0), tostring(record.format), tostring(record.bracket),
			tostring(record.rated), tostring(record.result), tostring(record.participantCount))
	lines[#lines + 1] = ("      %s  %s  duration=%ss  rounds=%s  columns=%s")
		:format(tostring(record.openedAt or record.completedAt),
			tostring(record.map and record.map.name),
			tostring(record.duration), tostring(record.rounds and #record.rounds or 0),
			tostring(record.columns and #record.columns or 0))


	local harvest = A.harvestLine(record)
	if harvest then
		lines[#lines + 1] = "      " .. harvest
	end

	return lines
end







local function effectiveResult(record)
	if record.result ~= nil then
		return record.result, false
	end

	local manual = record.manual
	if type(manual) == "table" and manual.result ~= nil and A.carriesResult(record) then
		return manual.result, true
	end
	return nil, false
end



function A.worldTally(record)
	if type(record) ~= "table" or record.format ~= "world" then
		return nil
	end
	if type(record.kills) ~= "number" and type(record.deaths) ~= "number" then
		return nil
	end
	local kills = type(record.kills) == "number" and record.kills or 0
	local deaths = type(record.deaths) == "number" and record.deaths or 0
	return ("%d %s, %d %s"):format(kills, kills == 1 and "kill" or "kills", deaths,
		deaths == 1 and "death" or "deaths")
end


local NOTE_LEAD_MAX = 48




function A.noteLead(text, bound)
	if type(text) ~= "string" then
		return nil
	end
	local trimmed = text:match("^%s*(.-)%s*$")
	if trimmed == "" then
		return nil
	end

	local max = type(bound) == "number" and bound or NOTE_LEAD_MAX
	if max < 1 then
		max = 1
	end
	if #trimmed <= max then
		return trimmed
	end

	local cut = trimmed:sub(1, max)

	local word
	if trimmed:sub(max + 1, max + 1):match("%s") then
		word = cut
	else
		word = cut:match("^(.*)%s%S*$")
	end
	if word == nil or word == "" then
		word = cut
	end
	return (word:gsub("%s+$", "")) .. "..."
end




local function editedLine(subject, noteShown)
	local manual = type(subject) == "table" and subject.manual or nil
	if type(manual) ~= "table" then
		return nil
	end

	local parts = {}
	local edits = manual.edits or 0
	put(parts, ("edited by hand, %d %s"):format(edits, edits == 1 and "time" or "times"))
	clause(parts, manual.firstAt, "first %s")

	if manual.lastAt ~= nil and manual.lastAt ~= manual.firstAt then
		put(parts, ("last %s"):format(tostring(manual.lastAt)))
	end


	if not noteShown and A.noteLead(manual.note) ~= nil then
		put(parts, "has a note")
	end


	return table.concat(parts, "  "), parts
end


function A.editedSummary(subject, noteShown)
	return (editedLine(subject, noteShown))
end






function A.rowCells(record, room)
	local cells = {}

	clause(cells, record.id, "#%s")



	if record.format ~= nil then
		put(cells, A.formatLabel(record.format))
	end

	clause(cells, record.openedAt or record.completedAt)

	local before = #cells
	clause(cells, record.map and record.map.name)
	local mapAt = #cells > before and #cells or nil

	local outcome, byHand = effectiveResult(record)
	clause(cells, outcome, byHand and "%s*" or nil)
	clause(cells, record.participantCount, "%sp")

	put(cells, spanText(record.duration))
	if type(record.manual) == "table" then
		put(cells, "edited")
	end



	if type(room) == "number" and mapAt then
		local name = cells[mapAt]
		local over = #table.concat(cells, "  ") - room
		if over > 0 then


			local keep = #name - over - 3
			local floor = A.metric("rowMapMin")
			if keep < floor then
				keep = floor
			end
			if keep < #name then
				cells[mapAt] = (name:sub(1, keep):gsub("%s+$", "")) .. "..."
			end
		end
	end

	return cells
end



local TABLE_FIELDS = {


	"faction",
	"spec", "class", "classToken", "race", "role", "seat",
	"damage", "healing", "killingBlows", "honorableKills", "deaths", "honor", "honorLevel",
	"rating", "ratingChange", "mmrPre", "mmrPost", "stats",
}





function A.recordHasTable(subject, kind)
	if kind == "incomplete" or type(subject) ~= "table" then
		return false
	end


	if type(subject.rounds) == "table" and #subject.rounds > 0 then
		return true
	end
	if type(subject.objectiveColumns) == "table" and next(subject.objectiveColumns) ~= nil then
		return true
	end

	local participants = subject.participants
	if type(participants) ~= "table" then
		return false
	end
	for _, row in pairs(participants) do
		if type(row) == "table" then
			for i = 1, #TABLE_FIELDS do
				if row[TABLE_FIELDS[i]] ~= nil then
					return true
				end
			end
		end
	end
	return false
end




local ROW_COLUMN_SETS = {
	duel = {
		{ key = "id", name = "MATCH", metric = "rowColMatch" },
		{ key = "opponent", name = "OPPONENT", metric = "rowColOpponent" },
		{ key = "map", name = "WHERE", metric = "rowColWhere" },



		{ key = "length", name = "LENGTH", metric = "rowColLength", whenPresent = "duration" },
		{ key = "result", name = "RESULT", metric = "rowColResult" },
	},





	round = {
		{ key = "id", name = "MATCH", metric = "rowColMatch" },
		{ key = "round", name = "ROUND", metric = "rowColSize" },
		{ key = "pair", name = "YOUR TWO", metric = "rowColPair" },
		{ key = "result", name = "RESULT", metric = "rowColResult" },
	},





	specpair = {
		{ key = "spec", name = "SPEC", metric = "rowSpec", sort = "spec", first = "ascending" },
		{ key = "againstRounds", name = "ROUNDS", metric = "rowColLength", align = "RIGHT",
			group = "AGAINST YOU", groupTone = "loss", sort = "againstRounds", first = "descending" },
		{ key = "againstRecord", name = "W-L", metric = "rowColRecord", align = "RIGHT",
			group = "AGAINST YOU", groupTone = "loss", sort = "againstRecord", first = "descending" },
		{ key = "againstRate", name = "YOU WON", metric = "rowColResult", align = "RIGHT",
			group = "AGAINST YOU", groupTone = "loss", sort = "againstRate", first = "ascending" },
		{ key = "alongRounds", name = "ROUNDS", metric = "rowColLength", align = "RIGHT",
			group = "WITH YOU", groupTone = "win", sort = "alongRounds", first = "descending" },
		{ key = "alongRecord", name = "W-L", metric = "rowColRecord", align = "RIGHT",
			group = "WITH YOU", groupTone = "win", sort = "alongRecord", first = "descending" },
		{ key = "alongRate", name = "YOU WON", metric = "rowColResult", align = "RIGHT",
			group = "WITH YOU", groupTone = "win", sort = "alongRate", first = "descending" },
	},




	askBeats = {
		{ key = "name", name = "SPEC", metric = "askName" },
		{ key = "met", name = "ROUNDS", metric = "askMet", align = "RIGHT",
			sort = "met", first = "descending" },
		{ key = "record", name = "W-L", metric = "askRecord" },
		{ key = "rate", name = "YOU WON", metric = "askRate", align = "RIGHT",
			sort = "rate", first = "ascending" },
	},
	askWhere = {
		{ key = "name", name = "MAP", metric = "askName" },
		{ key = "met", name = "DECIDED", metric = "askMet", align = "RIGHT",
			sort = "met", first = "descending" },
		{ key = "record", name = "W-L", metric = "askRecord" },
		{ key = "rate", name = "YOU WON", metric = "askRate", align = "RIGHT",
			sort = "rate", first = "ascending" },
	},
	askWorth = {
		{ key = "name", name = "SPEC", metric = "askName" },
		{ key = "met", name = "ROUNDS", metric = "askMet", align = "RIGHT",
			sort = "met", first = "descending" },
		{ key = "record", name = "W-L", metric = "askRecord" },
		{ key = "rate", name = "YOU WON", metric = "askRate", align = "RIGHT",
			sort = "rate", first = "descending" },
	},





	lobby = {
		{ key = "spec", name = "SPEC", metric = "rowSpec", lane = "spec" },
		{ key = "round1", name = "R1", metric = "lobbyRound", lane = "round", round = 1, group = "ROUNDS",
			align = "CENTER" },
		{ key = "round2", name = "R2", metric = "lobbyRound", lane = "round", round = 2, group = "ROUNDS",
			align = "CENTER" },
		{ key = "round3", name = "R3", metric = "lobbyRound", lane = "round", round = 3, group = "ROUNDS",
			align = "CENTER" },
		{ key = "round4", name = "R4", metric = "lobbyRound", lane = "round", round = 4, group = "ROUNDS",
			align = "CENTER" },
		{ key = "round5", name = "R5", metric = "lobbyRound", lane = "round", round = 5, group = "ROUNDS",
			align = "CENTER" },
		{ key = "round6", name = "R6", metric = "lobbyRound", lane = "round", round = 6, group = "ROUNDS",
			align = "CENTER" },
		{ key = "withRecord", name = "W-L", metric = "lobbyFigure", lane = "figure",
			align = "RIGHT", group = "WITH" },
		{ key = "withRate", name = "WON", metric = "lobbyFigure", lane = "figure",
			align = "RIGHT", group = "WITH", sort = "withRate", first = "descending" },
		{ key = "againstRecord", name = "W-L", metric = "lobbyFigure", lane = "figure",
			align = "RIGHT", group = "AGAINST" },
		{ key = "againstRate", name = "WON", metric = "lobbyFigure", lane = "figure",
			align = "RIGHT", group = "AGAINST", sort = "againstRate", first = "ascending" },

		{ key = "swing", name = "SWING", metric = "lobbySwing", lane = "figure",
			align = "RIGHT", sort = "swing", first = "descending" },
	},


	lobbyPane = {
		{ key = "name", name = "ROSTER", metric = "rowName", lane = "name" },
		{ key = "spec", name = "SPEC", metric = "rowSpec", lane = "spec" },
		{ key = "round1", name = "R1", metric = "lobbyRound", lane = "round", round = 1, group = "ROUNDS",
			align = "CENTER" },
		{ key = "round2", name = "R2", metric = "lobbyRound", lane = "round", round = 2, group = "ROUNDS",
			align = "CENTER" },
		{ key = "round3", name = "R3", metric = "lobbyRound", lane = "round", round = 3, group = "ROUNDS",
			align = "CENTER" },
		{ key = "round4", name = "R4", metric = "lobbyRound", lane = "round", round = 4, group = "ROUNDS",
			align = "CENTER" },
		{ key = "round5", name = "R5", metric = "lobbyRound", lane = "round", round = 5, group = "ROUNDS",
			align = "CENTER" },
		{ key = "round6", name = "R6", metric = "lobbyRound", lane = "round", round = 6, group = "ROUNDS",
			align = "CENTER" },
		{ key = "withRecord", name = "W-L", metric = "lobbyFigure", lane = "figure",
			align = "RIGHT", group = "WITH" },
		{ key = "againstRecord", name = "W-L", metric = "lobbyFigure", lane = "figure",
			align = "RIGHT", group = "VS" },
		{ key = "swing", name = "SWING", metric = "lobbySwing", lane = "figure",
			align = "RIGHT", sort = "swing", first = "descending" },
		{ key = "damage", name = "DAMAGE", metric = "rowDamageValue", lane = "figure", align = "RIGHT" },
		{ key = "wins", name = "WINS", metric = "rowHeal", lane = "figure", align = "RIGHT" },
		{ key = "kb", name = "KB", metric = "rowKb", lane = "figure", align = "RIGHT" },
		{ key = "dispels", name = "DISP", metric = "rowDispels", lane = "figure", align = "RIGHT" },
	},
	unknown = {
		{ key = "id", name = "MATCH", metric = "rowColMatch" },
		{ key = "map", name = "WHERE", metric = "rowColWhere" },
		{ key = "kind", name = "TYPE", metric = "rowColKind" },
		{ key = "size", name = "SIZE", metric = "rowColSize" },
		{ key = "length", name = "LENGTH", metric = "rowColLength" },
		{ key = "result", name = "RESULT", metric = "rowColResult" },
	},
}




local function withPresentColumns(set, subjects)
	local gated = false
	for i = 1, #set do
		if set[i].whenPresent then
			gated = true
			break
		end
	end
	if not gated or type(subjects) ~= "table" then
		return set
	end

	local held = {}
	for i = 1, #subjects do
		local entry = subjects[i]
		local subject = type(entry) == "table" and (entry.subject or entry) or nil
		if type(subject) == "table" then
			for key in pairs(subject) do
				held[key] = true
			end
		end
	end

	local out = {}
	for i = 1, #set do
		local column = set[i]
		if not column.whenPresent or held[column.whenPresent] then
			out[#out + 1] = column
		end
	end
	return out
end





function A.columnSetUnfillable(set, fillers)
	if type(set) ~= "table" or type(fillers) ~= "table" then
		return "no set"
	end
	for i = 1, #set do
		local column = set[i]
		if type(column) ~= "table" or type(column.key) ~= "string" then
			return tostring(type(column) == "table" and column.name or i) .. " names no accessor"
		end
		if type(fillers[column.key]) ~= "function" then
			return tostring(column.name) .. " reads " .. column.key .. ", which nothing fills"
		end
	end
	return nil
end






local MATCH_COLUMNS = {


	{ key = "crest", name = "", metric = "rowColCrest", whenAny = "crest" },
	{ key = "id", name = "MATCH", metric = "rowColMatch" },

	{ key = "kind", name = "FORMAT", heldName = "TYPE", metric = "rowColFormat",
		single = "format" },
	{ key = "map", name = "WHERE", metric = "rowColWhere" },
	{ key = "size", name = "SIZE", metric = "rowColSize", single = "size" },
	{ key = "length", name = "LENGTH", metric = "rowColLength" },
	{ key = "result", name = "RESULT", metric = "rowColResult" },


	{ key = "rating", name = "CHANGE", metric = "rowColRating", align = "RIGHT" },
	{ key = "ratingOut", name = "RATING", metric = "rowColRating", align = "RIGHT" },
}



local PLAYED_ON_COLUMNS = {
	{ key = "id", name = "MATCH", metric = "rowColMatch" },
	{ key = "when", name = "WHEN", metric = "rowColStamp" },
	{ key = "map", name = "WHERE", metric = "rowColWhere" },
	{ key = "length", name = "LENGTH", metric = "rowColLength" },
	{ key = "result", name = "RESULT", metric = "rowColResult" },
	{ key = "rating", name = "CHANGE", metric = "rowColRating", align = "RIGHT" },
	{ key = "ratingOut", name = "RATING", metric = "rowColRating", align = "RIGHT" },
}


function A.playedOnColumns()
	return PLAYED_ON_COLUMNS
end



local function columnSpread(subject, kind, seen)
	if kind == "incomplete" then
		seen.held = true
		return
	end
	if subject.format ~= nil then
		seen.format[tostring(subject.format)] = true
	end
	if subject.participantCount ~= nil then
		seen.size[tostring(subject.participantCount)] = true
	end


	if A.recordFaction(subject) ~= nil then
		seen.crest = true
	end
end

local function distinctKeys(set)
	local n = 0
	for _ in pairs(set) do
		n = n + 1
	end
	return n
end



local function matchColumnsFor(varied, sizesVary, held, crest, ladderless, sizeless)
	local out = {}
	for i = 1, #MATCH_COLUMNS do
		local column = MATCH_COLUMNS[i]
		local draws = true
		if column.single == "format" then
			draws = varied
		elseif column.single == "size" then
			draws = varied == false and sizesVary and not sizeless
		elseif column.whenAny == "crest" then
			draws = crest
		elseif column.key == "rating" or column.key == "ratingOut" then
			draws = not ladderless
		end
		if draws then


			local name = column.name
			if varied and held and column.heldName ~= nil then
				name = column.heldName
			end
			out[#out + 1] = { name = name, metric = column.metric, key = column.key, align = column.align }
		end
	end
	return out
end





local function matchColumns(subjects, format)
	local seen = { format = {}, size = {}, held = false, crest = false }
	for i = 1, #subjects do
		local entry = subjects[i]
		local subject = type(entry) == "table" and (entry.subject or entry) or nil
		if type(subject) == "table" then
			columnSpread(subject, type(entry) == "table" and entry.kind or nil, seen)
		end
	end


	local formats = distinctKeys(seen.format) + (seen.held and 1 or 0)
	local ladderless = format ~= nil and A.standingShape(format) == "ladderless"
	local out = matchColumnsFor(formats > 1, distinctKeys(seen.size) > 1, seen.held, seen.crest, ladderless,
		format == "arena-unrated")


	if format == "world" then
		for i = 1, #out do
			if out[i].key == "result" then
				out[i].metric = "rowColWhere"
			end
		end
	end
	return out
end



function A.rowColumns(format, subjects)
	if type(format) == "string" then
		local set = ROW_COLUMN_SETS[format]
		if set then
			return withPresentColumns(set, subjects)
		end
	end

	if type(subjects) == "table" then
		return matchColumns(subjects, type(format) == "string" and format or nil)
	end
	return nil
end





function A.listColumnSets()
	local out = {
		{ name = "the Duel set", columns = A.rowColumns("duel") },
		{ name = "the Duel set with no duration", columns = A.rowColumns("duel", {}) },
		{ name = "the Other set", columns = A.rowColumns("unknown") },
		{ name = "the World PvP set", columns = A.rowColumns("world", {}) },
	}
	local shapes = {
		{ name = "a tab of one format", varied = false, sizesVary = false },
		{ name = "a tab of one format whose rosters differ", varied = false, sizesVary = true },
		{ name = "a tab of several formats", varied = true, sizesVary = false },
		{ name = "a tab with no ladder", varied = false, sizesVary = false, ladderless = true },
		{ name = "a tab with no ladder whose rosters differ", varied = false, sizesVary = true,
			ladderless = true },
	}
	for i = 1, #shapes do
		local shape = shapes[i]
		for _, crest in ipairs({ false, true }) do
			out[#out + 1] = {
				name = crest and (shape.name .. ", with a crest lane") or shape.name,
				columns = matchColumnsFor(shape.varied, shape.sizesVary, false, crest, shape.ladderless),
			}
		end
	end
	return out
end





local FLAT_COLUMN = {
	chip = { key = "chip", name = "", metric = "rowColChip" },
	id = { key = "id", name = "MATCH", metric = "rowColMatch" },
	day = { key = "day", name = "WHEN", metric = "rowColWhen" },
	kind = { key = "kind", name = "FORMAT", heldName = "TYPE", metric = "rowColFormat" },
	size = { key = "size", name = "SIZE", metric = "rowColSize" },
	rounds = { key = "rounds", name = "ROUNDS", metric = "rowColRounds" },
	result = { key = "result", name = "RESULT", metric = "rowColResult" },
	where = { key = "where", name = "WHERE", metric = "rowColWhere" },
	lobby = { key = "lobby", name = "LOBBY", metric = "rowColLobby" },
	against = { key = "against", name = "AGAINST", metric = "rowColLobby" },
	length = { key = "length", name = "LENGTH", metric = "rowColLength" },
	change = { key = "change", name = "CHANGE", metric = "rowColChange", align = "RIGHT" },
	ratingOut = { key = "ratingOut", name = "RATING", metric = "rowColRating", align = "RIGHT" },

	time = { key = "time", name = "TIME", metric = "rowColMatch" },
	verdict = { key = "verdict", name = "RESULT", metric = "rowColResult" },
	span = { key = "span", name = "LENGTH", metric = "rowColLength", align = "RIGHT" },
	opponent = { key = "opponent", name = "OPPONENT", metric = "rowColWhere" },
	how = { key = "how", name = "HOW", metric = "rowColOpponent" },
	entry = { key = "entry", name = "TYPE", metric = "rowColOpponent" },
	why = { key = "why", name = "WHY YOU LEFT", metric = "rowColWhere", align = "RIGHT" },
}


local function flatColumn(key, name)
	local out = {}
	for field, value in pairs(FLAT_COLUMN[key]) do
		out[field] = value
	end
	if name ~= nil then
		out.name = name
	end
	out.heldName = nil
	return out
end





function A.flatRowColumns(format, subjects, flat)
	local formats, sizes, held, opponents = {}, {}, false, false
	for _, entry in ipairs(type(subjects) == "table" and subjects or {}) do
		local subject = type(entry) == "table" and (entry.subject or entry) or nil
		local kind = type(entry) == "table" and entry.kind or nil
		if type(subject) == "table" then
			if kind == "incomplete" then
				held = true
			else
				if subject.format ~= nil then
					formats[tostring(subject.format)] = true
				end
				if subject.participantCount ~= nil then
					sizes[tostring(subject.participantCount)] = true
				end
				if A.rowChips(subject, kind) ~= nil
					or (subject.format == "duel" and type(subject.opponentName) == "string") then
					opponents = true
				end
			end
		end
	end
	local function count(set)
		local n = 0
		for _ in pairs(set) do
			n = n + 1
		end
		return n
	end
	local varied = count(formats) + (held and 1 or 0) > 1

	local out = {}
	local function add(key, name)
		out[#out + 1] = flatColumn(key, name)
	end

	local function lead()
		add("id")
		if flat then
			add("day")
		end
	end
	local shape = type(A.standingShape) == "function" and A.standingShape(format) or "ladderless"
	if shape == "rated" and (format == "shuffle") then
		add("chip"); lead(); add("rounds"); add("where"); add("lobby"); add("length"); add("change")
		add("ratingOut")
	elseif shape == "rated" then
		add("chip"); lead(); add("result"); add("where"); add("against"); add("length"); add("change")
		add("ratingOut")
	elseif shape == "all" then
		add("chip"); lead()
		if varied then
			add("kind", held and "TYPE" or "FORMAT")
		end
		add("result"); add("where"); add("against"); add("length"); add("change"); add("ratingOut")
	elseif format == "duel" then

		add("time")
		if flat then
			add("day")
		end
		add("verdict"); add("opponent"); add("how"); add("where"); add("span")
	elseif format == "unknown" then

		lead(); add("entry"); add("verdict"); add("where"); add("span"); add("why")
	elseif format == "world" then


		lead(); add("result"); out[#out].metric = "rowColWhere"; add("where"); add("length")
	else
		lead()

		if count(sizes) > 1 and format ~= "arena-unrated" then
			add("size")
		end
		add("result"); add("where")
		if opponents then
			add("against")
		end
		add("length")
	end
	return out
end




function A.askColumnFloors()
	local met, record, rate = 0, 0, 0
	if type(A.askQuestions) ~= "function" or type(A.headerFloor) ~= "function" then
		return met, record, rate
	end
	for _, question in ipairs(A.askQuestions()) do
		local columns = ROW_COLUMN_SETS[question.columns]
		if type(columns) == "table" and #columns == 4 then
			met = math.max(met, A.headerFloor(columns[2].name))
			record = math.max(record, A.headerFloor(columns[3].name))
			rate = math.max(rate, A.headerFloor(columns[4].name))
		end
	end
	return met, record, rate
end



function A.rowIdText(subject, kind)
	if type(subject) ~= "table" or subject.id == nil then
		return "-"
	end
	if kind == "incomplete" then
		return ("L%s"):format(tostring(subject.id))
	end
	return ("#%s"):format(tostring(subject.id))
end



local DUEL_CELL = {
	id = function(record)
		if record.id == nil then
			return "-"
		end
		return ("#%s"):format(tostring(record.id))
	end,
	opponent = function(record)
		return tostring(record.opponentName or "-")
	end,
	map = function(record)
		return tostring(record.map and record.map.name or "-")
	end,
	length = function(record)
		return spanText(record.duration) or "-"
	end,
	result = function(record)
		local outcome, byHand = effectiveResult(record)
		if outcome == nil then
			return "-"
		end
		if byHand then
			return outcome .. "*"
		end
		return outcome
	end,
}


local BUCKET_CELL = {
	id = function(subject, kind)
		return A.rowIdText(subject, kind)
	end,
	map = function(subject)
		return tostring(subject.map and subject.map.name or "-")
	end,
	kind = function(subject, kind)

		if kind == "incomplete" then
			return subject.reason == "abandoned" and "Abandoned" or "Left early"
		end
		if subject.format == nil then
			return "-"
		end
		return A.formatLabel(subject.format)
	end,
	size = function(subject, kind)


		if kind == "incomplete" or subject.participantCount == nil then
			return "-"
		end
		return ("%sp"):format(tostring(subject.participantCount))
	end,
	length = function(subject, kind)
		if kind == "incomplete" then
			return spanText(subject.seconds) or "-"
		end
		return spanText(subject.duration) or "-"
	end,
	result = function(subject, kind)


		if kind == "incomplete" then
			return "-"
		end
		local outcome, byHand = effectiveResult(subject)
		if outcome == nil then
			return "-"
		end
		if byHand then
			return outcome .. "*"
		end
		return outcome
	end,
}




local MATCH_CELL = {

	crest = function()
		return ""
	end,
	id = function(subject, kind)
		return A.rowIdText(subject, kind)
	end,
	kind = function(subject, kind)
		if kind == "incomplete" then
			return subject.reason == "abandoned" and "Abandoned" or "Left early"
		end
		if subject.format == nil then
			return "-"
		end
		return A.formatLabel(subject.format)
	end,


	map = function(subject, kind)
		if kind ~= "incomplete" and subject.format == "duel" then
			return tostring(subject.opponentName or "-")
		end
		return tostring(subject.map and subject.map.name or "-")
	end,
	size = function(subject, kind)
		if kind == "incomplete" or subject.participantCount == nil then
			return "-"
		end
		return ("%sp"):format(tostring(subject.participantCount))
	end,


	rating = function(subject, kind)
		if kind == "incomplete" then
			return "-"
		end
		return (A.ratingDelta(subject)) or "-"
	end,

	when = function(subject)
		local at = subject.openedAt or subject.completedAt or subject.endedAt
		return type(at) == "string" and A.minuteStamp(at) or "-"
	end,


	chip = function()
		return ""
	end,

	day = function(subject)
		return A.dayKey(subject.openedAt or subject.completedAt or subject.endedAt) or "-"
	end,

	where = function(subject)
		return tostring(subject.map and subject.map.name or "-")
	end,

	rounds = function(subject, kind)
		if kind == "incomplete" then
			return "-"
		end

		local verdict, won, played = A.roundsVerdict(subject)
		if verdict == nil then
			return "-"
		elseif verdict == "unsummed" then
			return "?"
		end
		return ("%d of %d"):format(won, played)
	end,

	lobby = function(subject, kind)
		local chips = A.rowChips(subject, kind)
		return chips and chips.text or ""
	end,
	against = function(subject, kind)
		if kind ~= "incomplete" and subject.format == "duel" then
			return tostring(subject.opponentName or "")
		end
		local chips = A.rowChips(subject, kind)
		return chips and chips.text or ""
	end,

	change = function(subject, kind)
		if kind == "incomplete" then
			return ""
		end
		return (A.ratingDelta(subject)) or ""
	end,

	ratingOut = function(subject, kind)
		if kind == "incomplete" then
			return "-"
		end
		local _, out = A.recordLadderPair(subject)
		return out ~= nil and tostring(out) or "-"
	end,


	time = function(subject)
		return A.clockKey(subject.openedAt or subject.completedAt or subject.endedAt) or "-"
	end,

	verdict = function(subject, kind)
		if kind == "incomplete" then
			return "-"
		end
		local outcome, byHand = effectiveResult(subject)
		local word = outcome == "win" and "won" or outcome == "loss" and "lost" or outcome
		if word == nil then
			return "-"
		end
		return byHand and (word .. "*") or word
	end,

	span = function(subject, kind)
		if kind == "incomplete" then
			return spanText(subject.seconds) or ""
		end
		return spanText(subject.duration) or ""
	end,

	opponent = function(subject)
		local bare, realm = A.nameParts(subject.opponentName)
		if bare == "" then
			return "-"
		end
		return realm and (bare .. "  " .. realm) or bare
	end,
	how = function(subject)
		return A.duelHow and A.duelHow(subject) or ""
	end,

	entry = function(subject, kind)
		if kind == "incomplete" then
			return "Left early"
		end
		return subject.format ~= nil and A.formatLabel(subject.format) or "-"
	end,

	why = function()
		return ""
	end,
	length = function(subject, kind)
		if kind == "incomplete" then
			return spanText(subject.seconds) or "-"
		end
		return spanText(subject.duration) or "-"
	end,
	result = function(subject, kind)
		if kind == "incomplete" then

			return "-"
		end

		if subject.format == "world" then
			return A.worldTally(subject) or "-"
		end
		local outcome, byHand = effectiveResult(subject)
		if outcome == nil then





			local verdict, won, played = A.roundsVerdict(subject)
			if verdict == nil then
				return "-"
			elseif verdict == "unsummed" then
				return "?"
			end
			return ("%d of %d"):format(won, played)
		end
		if byHand then
			return outcome .. "*"
		end
		return outcome
	end,
}




function A.columnCells(subject, columns, fillers, kind)
	if type(subject) ~= "table" or type(columns) ~= "table" or type(fillers) ~= "table" then
		return nil
	end
	local cells = {}
	for i = 1, #columns do
		local filler = columns[i].key and fillers[columns[i].key] or nil
		cells[i] = filler and filler(subject, kind) or "-"
	end
	return cells
end

local function keyedCells(subject, columns, fillers, kind)
	return A.columnCells(subject, columns, fillers, kind)
end


function A.columnFillers(format)
	if format == "duel" then
		return DUEL_CELL
	end
	if format == "unknown" then
		return BUCKET_CELL
	end
	if format == nil then
		return MATCH_CELL
	end
	return nil
end



function A.rowColumnCells(subject, format, kind, columns)
	if type(subject) ~= "table" then
		return nil
	end



	local named = format
	if type(named) ~= "string" or not ROW_COLUMN_SETS[named] then
		if type(columns) ~= "table" then
			local own = subject.format
			if type(own) == "string" and ROW_COLUMN_SETS[own] then
				named = own
			end
		end
	end

	local set = columns
	local fillers
	if type(named) == "string" and ROW_COLUMN_SETS[named] then

		fillers = A.columnFillers(named == "duel" and "duel" or "unknown")
		if type(set) ~= "table" then
			set = A.rowColumns(named)
		end
	else
		fillers = MATCH_CELL
		if type(set) ~= "table" then
			set = A.rowColumns(format, { subject })
		end
	end

	if type(set) ~= "table" or type(fillers) ~= "table" then
		return nil
	end
	return keyedCells(subject, set, fillers, kind)
end




function A.flatColumnFillers()
	return MATCH_CELL
end


function A.flatRowCells(subject, kind, columns)
	if type(subject) ~= "table" or type(columns) ~= "table" then
		return nil
	end
	return A.columnCells(subject, columns, MATCH_CELL, kind)
end




function A.flatRowSubs(subject, kind, columns)
	if type(subject) ~= "table" or type(columns) ~= "table" then
		return nil
	end
	local has = {}
	for _, column in ipairs(columns) do
		has[column.key] = true
	end
	if not has.entry then
		return nil
	end
	local subs = {}
	if has.id then
		subs.id = A.clockKey(subject.openedAt or subject.completedAt or subject.endedAt)
	end
	if kind == "incomplete" then
		subs.entry = subject.reason == "abandoned" and "found at next login" or "you left"
	end
	if has.where and subject.rated == true then
		subs.where = "rated"
	end
	return subs
end



function A.dayKey(stamp)
	if type(stamp) ~= "string" then
		return nil
	end
	return stamp:match("^(%d%d%d%d%-%d%d%-%d%d)")
end



function A.clockKey(stamp)
	if type(stamp) ~= "string" then
		return nil
	end
	return stamp:match("^%d%d%d%d%-%d%d%-%d%d (%d%d:%d%d)")
end





function A.dayLabel(stamp)
	local key = A.dayKey(stamp)
	if key == nil then
		return nil
	end
	local year, month, day = key:match("^(%d%d%d%d)%-(%d%d)%-(%d%d)$")
	local y, m, d = tonumber(year), tonumber(month), tonumber(day)

	if not (y and m and d) then
		return key
	end
	local okAt, at = pcall(time, { year = y, month = m, day = d, hour = 12 })
	if not okAt or type(at) ~= "number" then
		return key
	end
	local okText, text = pcall(date, "%A %d %B", at)
	if not okText or type(text) ~= "string" or text == "" then
		return key
	end

	return (text:gsub("^(%a+) 0", "%1 "))
end




function A.rowExpansion(subject, kind)
	if type(subject) ~= "table" then
		return {}
	end

	local lines = {}

	if kind == "incomplete" then

		local manual = type(subject.manual) == "table" and subject.manual or nil
		clause(lines, A.reasonLabel(manual and manual.reason), "reason %s")

		if subject.rated == true then
			put(lines, "cost rating")
		elseif subject.rated == false then
			put(lines, "no rating at stake")
		end
		clause(lines, subject.endedAt, "ended %s")
		clause(lines, subject.rounds, "%s rounds")
	else

		clause(lines, subject.outcome)
		if subject.duelToTheDeath then
			put(lines, "to the death")
		end
		put(lines, A.durationCaveat(subject.openedState))
	end

	put(lines, A.seasonText(subject, true))


	return lines
end


function A.summaryLine(record)
	return table.concat(A.rowCells(record), "  ")
end





local function lessThan(a, b)
	if a == b then
		return false
	end
	if a == nil then
		return false
	end
	if b == nil then
		return true
	end

	local ta, tb = type(a), type(b)
	if ta ~= tb then
		return ta < tb
	end

	if ta == "number" and (a ~= a or b ~= b) then
		return a == a
	end
	if ta == "number" or ta == "string" then
		return a < b
	end

	return false
end




local function orderedColumns(record)
	local columns = record.columns
	if not columns then
		return nil
	end


	local out = {}
	for i = 1, #columns do
		if type(columns[i]) == "table" then
			out[#out + 1] = columns[i]
		end
	end

	table.sort(out, function(a, b)
		if a.order ~= b.order then
			return lessThan(a.order, b.order)
		end
		return lessThan(a.id, b.id)
	end)

	return out
end



function A.columnName(column)
	local name = column and column.name
	if type(name) ~= "string" or name == "" then
		return tostring(column and column.id or "unnamed")
	end

	return (name:gsub("|n", " "))
end







local OBJECTIVE_SHORT = {
	["Bases Assaulted"]     = "TAKEN",
	["Bases Defended"]      = "HELD",
	["Flag Captures"]       = "CAPS",
	["Flag Returns"]        = "RETURNS",
	["Orb Possessions"]     = "ORBS",
	["Victory Points"]      = "POINTS",
	["Carts Controlled"]    = "CARTS",


	["Artifacts Collected"] = "RELICS",


	["Crystal Captures"]    = "CRYSTAL",


	["Rounds Won"]          = "WINS",
}




local function columnCarried(record, column)
	local participants = type(record) == "table" and record.participants or nil
	if type(participants) ~= "table" then
		return false
	end
	for _, p in pairs(participants) do
		local stats = type(p) == "table" and p.stats or nil
		local value = type(stats) == "table" and stats[column.id] or nil
		if type(value) == "number" and value ~= 0 then
			return true
		end
	end
	return false
end



function A.objectiveColumns(record)
	local columns = type(record) == "table" and orderedColumns(record) or nil
	if not columns then
		return {}
	end

	local out = {}
	for i = 1, #columns do
		local long = A.columnName(columns[i])
		local short = OBJECTIVE_SHORT[long]

		if short ~= nil and columnCarried(record, columns[i]) then
			out[#out + 1] = { id = columns[i].id, short = short, long = long }
		end
	end
	return out
end





local function objectives(record, participant)
	local columns, stats = orderedColumns(record), participant.stats
	if not (columns and stats) then
		return nil
	end

	local parts = {}
	for i = 1, #columns do
		local column = columns[i]
		local value = stats[column.id]
		if value ~= nil then
			parts[#parts + 1] = A.columnName(column) .. " " .. tostring(value)
		end
	end

	if #parts == 0 then
		return nil
	end
	return table.concat(parts, ", ")
end




local function rosterOrder(a, b)
	if a.p.faction ~= b.p.faction then
		return lessThan(a.p.faction, b.p.faction)
	end
	if a.p.name ~= b.p.name then
		return lessThan(a.p.name, b.p.name)
	end
	return lessThan(a.guid, b.guid)
end






local function ownSideFirst(roster, sides)
	if not sides then
		return roster
	end

	local own, other, unnamed = {}, {}, {}
	for i = 1, #roster do
		local faction = roster[i].p.faction
		local bucket = unnamed
		if faction ~= nil then
			bucket = (faction == sides.own) and own or other
		end
		bucket[#bucket + 1] = roster[i]
	end

	local out = {}
	for _, bucket in ipairs({ own, other, unnamed }) do
		for i = 1, #bucket do
			out[#out + 1] = bucket[i]
		end
	end
	return out
end




local function rosterEntries(record)
	local participants = record.participants
	if not participants then
		return {}
	end



	local out = {}
	for guid, participant in pairs(participants) do
		if type(guid) == "string" and type(participant) == "table" then
			out[#out + 1] = { guid = guid, p = participant }
		end
	end
	table.sort(out, rosterOrder)
	return out
end




local ROLE_BITS = {
	{ bit = 8, text = "DMG" },
	{ bit = 4, text = "HEAL" },
	{ bit = 2, text = "TANK" },
	{ bit = 1, text = "LEAD" },
}


local LEAD_BIT = 1




function A.roleParts(mask)
	if type(mask) ~= "number" or mask < 0 then
		return nil, false, nil
	end

	local words, lead, rest = {}, false, math.floor(mask)
	for i = 1, #ROLE_BITS do
		local entry = ROLE_BITS[i]
		if rest % (entry.bit * 2) >= entry.bit then
			if entry.bit == LEAD_BIT then
				lead = true
			else
				words[#words + 1] = entry.text
			end
			rest = rest - entry.bit
		end
	end

	local unknown = nil
	if rest > 0 then
		unknown = ("role %d"):format(math.floor(mask))
	end
	return (#words > 0) and table.concat(words, " ") or nil, lead, unknown
end


function A.roleText(mask)
	local role, lead, unknown = A.roleParts(mask)



	local parts = {}
	if role then
		parts[#parts + 1] = role
	end
	if lead then
		parts[#parts + 1] = "LEAD"
	end
	if unknown then
		parts[#parts + 1] = unknown
	end
	if #parts == 0 then
		return nil
	end
	return table.concat(parts, " ")
end



local DURATION_CAVEAT = {
	Waiting = "includes pre-match wait",
	Engaged = "partial timing",
}


local DURATION_CAVEAT_LONG = {
	Waiting = "includes the wait before the gates",
	Engaged = "measured from when this addon loaded, part way in",
}



function A.durationCaveat(openedState)
	if type(openedState) ~= "string" then
		return nil
	end
	return DURATION_CAVEAT[openedState]
end


function A.durationCaveatLong(openedState)
	if type(openedState) ~= "string" then
		return nil
	end
	return DURATION_CAVEAT_LONG[openedState]
end




local function rosterSides(record, roster)
	local own = record.selfFaction
	local seen, distinct = {}, 0
	for i = 1, #roster do
		local p = roster[i].p
		if p.faction ~= nil then
			if not seen[p.faction] then
				seen[p.faction] = true
				distinct = distinct + 1
			end
			if roster[i].guid == record.character then
				own = p.faction
			end
		end
	end

	if distinct < 2 or own == nil then
		return nil
	end
	return { own = own }
end





function A.rosterSplit(record)
	if type(record) ~= "table" or type(record.participants) ~= "table" then
		return nil
	end

	local roster = rosterEntries(record)
	local sides = rosterSides(record, roster)
	if not sides then
		return nil
	end

	local own, enemy = {}, {}
	for i = 1, #roster do
		local p = roster[i].p
		if type(p) == "table" and p.faction ~= nil then
			if p.faction == sides.own then
				own[#own + 1] = roster[i]
			else
				enemy[#enemy + 1] = roster[i]
			end
		end
	end
	return { own = own, enemy = enemy }
end



local ROW_MARK_LIMIT = 6








function A.rowLobby(subject, kind)
	if kind == "incomplete" or type(subject) ~= "table" then
		return nil
	end
	if subject.format == "duel" or subject.format == "world" then
		local place = subject.map and subject.map.name or nil
		if type(place) ~= "string" or place == "" then
			return nil
		end
		return { kind = "place", text = place }
	end
	if type(subject.participants) ~= "table" then
		return nil
	end

	local roster = rosterEntries(subject)
	local sides = rosterSides(subject, roster)
	local others = 0
	for i = 1, #roster do
		if roster[i].guid ~= subject.character then
			others = others + 1
		end
	end
	if others <= 0 then
		return nil
	end


	if others >= ROW_MARK_LIMIT then
		if sides then
			local mine, theirs = 0, 0
			for i = 1, #roster do
				local p = roster[i].p
				if type(p) == "table" and p.faction ~= nil then
					if p.faction == sides.own then
						mine = mine + 1
					else
						theirs = theirs + 1
					end
				end
			end
			if mine > 0 and theirs > 0 then
				return { kind = "count",
					text = ("%d %s %d"):format(mine, SIDE_WORDS.against, theirs) }
			end
		end

		local whole = #roster
		return { kind = "count",
			text = ("%d %s"):format(whole, whole == 1 and "player" or "players") }
	end

	local marks, split = {}, nil
	if sides then
		split = 0
		for i = 1, #roster do
			local entry = roster[i]
			local p = entry.p
			if entry.guid ~= subject.character and type(p) == "table" and p.faction == sides.own then
				marks[#marks + 1] = { classToken = p.classToken }
				split = split + 1
			end
		end
		for i = 1, #roster do
			local entry = roster[i]
			local p = entry.p
			if entry.guid ~= subject.character and type(p) == "table" and p.faction ~= nil
				and p.faction ~= sides.own then
				marks[#marks + 1] = { classToken = p.classToken }
			end
		end
	end


	if not sides or split == nil or split == 0 or split >= #marks then
		marks, split = {}, nil
		for i = 1, #roster do
			local entry = roster[i]
			if entry.guid ~= subject.character and type(entry.p) == "table" then
				marks[#marks + 1] = { classToken = entry.p.classToken }
			end
		end
	end
	if #marks == 0 then
		return nil
	end
	return { kind = split and "sides" or "marks", marks = marks, split = split,
		word = split and SIDE_WORDS.against or nil }
end


local ROW_CHIP_LIMIT = 5



function A.chipLetters(spec)
	if type(spec) ~= "string" or spec == "" then
		return nil
	end
	local out, n = {}, 0
	for char in spec:gmatch("[%z\1-\127\194-\244][\128-\191]*") do
		n = n + 1
		out[n] = char
		if n == 3 then
			break
		end
	end
	return table.concat(out)
end



local function chipOf(p)
	if type(p) ~= "table" then
		return nil
	end


	local icon = type(A.specIcon) == "function" and p.spec ~= nil and A.specIcon(p.classToken, p.spec) or nil
	return { classToken = p.classToken, text = A.chipLetters(p.spec) or "", spec = p.spec, icon = icon }
end


function A.rowSelfChip(subject)
	local own = type(subject) == "table" and subject.character ~= nil
		and type(subject.participants) == "table" and subject.participants[subject.character] or nil
	if type(own) ~= "table" or type(own.spec) ~= "string" or own.spec == "" then
		return nil
	end
	return chipOf(own)
end






function A.rowChips(subject, kind)
	if kind == "incomplete" or type(subject) ~= "table" or subject.format == "duel"
		or subject.format == "world" or type(subject.participants) ~= "table" then
		return nil
	end
	local roster = rosterEntries(subject)
	local sides = rosterSides(subject, roster)
	local picked = {}
	for i = 1, #roster do
		local entry = roster[i]
		local p = entry.p
		if entry.guid ~= subject.character and type(p) == "table" then
			if sides == nil or (p.faction ~= nil and p.faction ~= sides.own) then
				picked[#picked + 1] = p
			end
		end
	end
	if #picked == 0 then
		return nil
	end
	if #picked > ROW_CHIP_LIMIT then
		local lobby = A.rowLobby(subject, kind)
		local text = lobby and lobby.text or ("%d players"):format(#roster)
		return { text = text }
	end
	local chips = {}
	for i = 1, #picked do
		chips[i] = chipOf(picked[i])
	end
	return { chips = chips }
end


function A.rowChipLimit()
	return ROW_CHIP_LIMIT
end



function A.rowSelfSpec(subject)
	local own = type(subject) == "table" and subject.character ~= nil
		and type(subject.participants) == "table" and subject.participants[subject.character] or nil
	if type(own) ~= "table" or type(own.spec) ~= "string" or own.spec == "" then
		return nil
	end
	return A.chipText({ spec = own.spec, class = own.class })
end





function A.rowSecondLine(subject, kind, stamp, cells)
	if type(subject) ~= "table" then
		return nil
	end
	local out = {
		clock = A.clockKey(stamp),
		spec = kind ~= "incomplete" and A.rowSelfSpec(subject) or nil,
		lobby = A.rowLobby(subject, kind),
	}
	if type(out.lobby) == "table" and out.lobby.kind == "place" and type(cells) == "table" then
		for i = 1, #cells do
			if cells[i] == out.lobby.text then
				out.lobby = nil
				break
			end
		end
	end
	if out.clock == nil and out.spec == nil and out.lobby == nil then
		return nil
	end
	return out
end







function A.lastMatchCard(format, season, character, bound)
	if type(A.lastMatch) ~= "function" then
		return nil
	end
	local record = A.lastMatch(format, season, character, bound)
	if type(record) ~= "table" then
		return nil
	end



	local by = {}
	local columns = A.rowColumns(format, { record })
	if type(columns) == "table" then
		local cells = A.rowColumnCells(record, format, nil, columns)
		if type(cells) == "table" then
			for i = 1, #columns do
				local key = columns[i].key
				if key ~= nil then
					by[key] = cells[i]
				end
			end
		end
	end

	local stamp = type(record.openedAt) == "string" and record.openedAt or nil
	local label = stamp and A.dayLabel(stamp) or nil


	local place = by.map
	if record.format == "duel" then
		place = type(record.map) == "table" and record.map.name or nil
	end
	if type(place) ~= "string" or place == "" or place == "-" then
		place = nil
	end
	local clock = stamp and A.clockKey(stamp) or nil
	local weekday = type(label) == "string" and label:match("^(%a+)") or nil
	local moment, abbr, shorter = nil, nil, nil
	if weekday and clock then

		moment, abbr, shorter = ("%s %s"):format(weekday, clock), ("%s %s"):format(weekday:sub(1, 3), clock), clock
	elseif clock then
		moment = clock
	end

	return {
		id = record.id,

		kind = "match",
		result = type(by.result) == "string" and by.result or "-",
		tone = A.resultTone(record),
		place = place,
		moment = moment,
		momentAbbr = abbr,
		clock = shorter,
	}
end





function A.objectiveTotals(record)
	local columns = A.objectiveColumns(record)
	if #columns == 0 then
		return nil
	end

	local split = type(A.rosterSplit) == "function" and A.rosterSplit(record) or nil
	if not split then
		return nil
	end

	local function total(entries)
		local out = {}
		for c = 1, #columns do
			local sum, read = 0, false
			for i = 1, #entries do
				local stats = entries[i].p and entries[i].p.stats or nil
				local value = stats and stats[columns[c].id] or nil
				if type(value) == "number" then
					sum = sum + value
					read = true
				end
			end


			if read then
				out[c] = sum
			end
		end
		return out
	end

	local yours, theirs = total(split.own), total(split.enemy)



	local anything = false
	for c = 1, #columns do
		if (yours[c] or 0) ~= 0 or (theirs[c] or 0) ~= 0 then
			anything = true
			break
		end
	end
	if not anything then
		return nil
	end

	return { columns = columns, yours = yours, theirs = theirs }
end







local function qualifiedName(record, guid, name)
	local mine = guid ~= nil and guid == record.character

	if type(name) ~= "string" or name == "" then
		return name
	end
	if name:find("-", 1, true) then
		if mine then
			A.trace("realm", { id = record.id, state = "qualified", reason = "already-qualified" },
				"ui")
		end
		return name
	end
	if not mine or guid ~= A.ownGuid() then
		if mine then
			A.trace("realm", { id = record.id, state = "bare", reason = "not-reader" }, "ui")
		end
		return name
	end
	local realm = A.ownRealm()
	if not realm then
		A.trace("realm", { id = record.id, state = "bare", reason = "no-realm" }, "ui")
		return name
	end

	A.trace("realm", { id = record.id, state = "qualified", reason = "appended" }, "ui")
	return name .. "-" .. realm
end



local function columnValues(participant, columns)
	local stats = type(participant) == "table" and participant.stats or nil
	local out = {}
	for c = 1, #columns do
		local value = stats and stats[columns[c].id] or nil
		if type(value) == "number" then
			out[c] = value
		end
	end
	return out
end



local SHARED_SPECS = {
	frost = true, holy = true, protection = true, restoration = true,
}




function A.chipText(cell)
	if type(cell) ~= "table" then
		return "?"
	end
	local spec = cell.spec
	if type(spec) ~= "string" or spec == "" then
		return tostring(cell.name or "?")
	end
	if SHARED_SPECS[spec:lower()] and type(cell.class) == "string" and cell.class ~= "" then
		return ("%s %s"):format(spec, cell.class)
	end
	return spec
end



function A.participantCells(record, entry, sides, columns)
	local guid, p = entry.guid, entry.p





	local roleMask = p.role
	if A.isBotGuid(guid) then
		roleMask = nil
	end



	local dispels, meterReason
	if type(A.participantMeter) == "function" then
		dispels, meterReason = A.participantMeter(record, guid)
	end

	return {
		guid = guid,
		self = guid == record.character,

		name = qualifiedName(record, guid, p.name) or guid,

		side = (sides and p.faction ~= nil)
			and (p.faction == sides.own and "yours" or "theirs") or nil,
		classToken = p.classToken, class = p.class, spec = p.spec, race = p.race,



		specLabel = (type(p.spec) == "string" and p.spec ~= "")
			and A.chipText({ spec = p.spec, class = p.class }) or nil,


		role = A.roleText(roleMask),
		roleWord = select(1, A.roleParts(roleMask)),
		lead = select(2, A.roleParts(roleMask)) or nil,
		kb = p.killingBlows, hk = p.honorableKills, d = p.deaths,
		damage = p.damage, healing = p.healing,
		dispels = dispels, meterReason = meterReason,
		honor = p.honor, honorLevel = p.honorLevel,
		rating = p.rating, ratingChange = p.ratingChange,
		mmrPre = p.mmrPre, mmrPost = p.mmrPost,
		objectives = objectives(record, p),

		objectiveValues = columns and columnValues(p, columns) or nil,

		objectiveColumns = columns,
	}
end



local function participantLine(record, entry, sides, precomputed)

	local c = precomputed or A.participantCells(record, entry, sides)
	local parts = {}


	local identity = tostring(c.name)
	if c.side then
		identity = ("[%s] %s"):format(c.side, identity)
	end
	put(parts, identity)

	local who = {}
	clause(who, c.race)
	clause(who, c.class)
	clause(who, c.spec)
	if #who > 0 then
		put(parts, table.concat(who, " "))
	end

	put(parts, c.role)

	local fought = {}
	clause(fought, c.kb, "kb %s")
	clause(fought, c.hk, "hk %s")
	clause(fought, c.d, "d %s")
	if #fought > 0 then
		put(parts, table.concat(fought, " "))
	end

	local output = {}
	clause(output, c.damage, "dmg %s")
	clause(output, c.healing, "heal %s")
	if #output > 0 then
		put(parts, table.concat(output, " "))
	end

	local honor = {}
	clause(honor, c.honor, "honor %s")

	clause(honor, c.honorLevel, "honorlevel %s")
	if #honor > 0 then
		put(parts, table.concat(honor, " "))
	end

	local ladder = {}
	clause(ladder, c.rating, "rating %s")
	clause(ladder, c.ratingChange, "change %s")
	if c.mmrPre ~= nil and c.mmrPost ~= nil then
		ladder[#ladder + 1] = ("mmr %s to %s"):format(tostring(c.mmrPre), tostring(c.mmrPost))
	else
		clause(ladder, c.mmrPre, "mmr pre %s")
		clause(ladder, c.mmrPost, "mmr post %s")
	end
	if #ladder > 0 then
		put(parts, table.concat(ladder, " "))
	end

	put(parts, c.objectives)

	return (c.self and "* " or "  ") .. table.concat(parts, "  ")
end








function A.seasonText(record, pane)
	if type(A.recordSeason) ~= "function" then
		return nil
	end
	local season, source = A.recordSeason(record)
	if season == nil then
		return nil
	end
	local entry = A.seasonEntry and A.seasonEntry(season) or nil
	local named = entry and entry.label
	local text = named and ("season %d, %s"):format(season, named) or ("season %d"):format(season)
	if source == "client" or pane then
		return text
	end

	return text .. " (boundary declared)"
end


function A.seasonLines()
	local lines = {}

	local arena = A.arenaSeasonNow and A.arenaSeasonNow() or nil
	local display = A.displaySeasonNow and A.displaySeasonNow() or nil
	local now = A.seasonNow and A.seasonNow() or nil
	if now ~= nil then


		lines[#lines + 1] = ("the client reports season %s, shown in this expansion as season %d")
			:format(arena == nil and "unread" or tostring(arena), now)
	else

		lines[#lines + 1] = ("the client reports no season: arena %s, display %s")
			:format(arena == nil and "no answer" or tostring(arena),
				display == nil and "no answer" or tostring(display))
	end

	local list = A.seasonBoundaries and A.seasonBoundaries() or {}
	if #list == 0 then
		lines[#lines + 1] = "  nothing is declared. /pvph season start <n> [YYYY-MM-DD] opens one"
		return lines
	end

	for i = 1, #list do
		local entry = list[i]
		local parts = {}
		parts[#parts + 1] = ("season %d"):format(entry.season)
		parts[#parts + 1] = ("from %s"):format(tostring(entry.startedAt))

		parts[#parts + 1] = entry.endedAt and ("to %s"):format(tostring(entry.endedAt)) or "open"
		parts[#parts + 1] = tostring(entry.source or "manual")
		if entry.label then
			parts[#parts + 1] = entry.label
		end
		lines[#lines + 1] = "  " .. table.concat(parts, "  ")
	end

	return lines
end









function A.seasonCounterLines(counters)
	counters = type(counters) == "table" and counters or {}
	local lines = { "rated matches, the client's own counters against the history, for this character:" }

	local character = A.ownGuid()
	if character == nil then
		lines[#lines + 1] = "  the logged-in character could not be read, so no record is counted"
		return lines
	end
	local game = type(A.gameSeasonNow) == "function" and A.gameSeasonNow() or nil
	if game == nil then
		lines[#lines + 1] = "  the client reports no game season, so no record is counted against the counters"
		return lines
	end
	local weekStart = type(A.weekStartEpoch) == "function" and A.weekStartEpoch() or nil

	local formats = type(A.ratedFormats) == "function" and A.ratedFormats() or {}
	local held = {}
	for i = 1, #formats do
		held[formats[i]] = { records = 0, ids = {}, idCount = 0, wins = 0, week = 0, weekIds = {},
			weekWins = 0, rounds = 0, roundsWon = 0, weekRounds = 0, weekRoundsWon = 0, untotalled = 0 }
	end

	local unsized = 0
	local db = A.db()
	local matches = db and type(db.matches) == "table" and db.matches or {}
	for i = 1, #matches do
		local record = matches[i]
		if type(record) == "table" and record.character == character and record.rated == true
			and record.fixture == nil and A.recordGameSeason(record) == game then
			local bucket = held[record.format]
			if record.format == "arena" then
				unsized = unsized + 1
			elseif bucket then
				bucket.records = bucket.records + 1



				local id = record.id
				local first = id ~= nil and not bucket.ids[id]
				if first then
					bucket.ids[id] = true
					bucket.idCount = bucket.idCount + 1
				end
				local inWeek = first and weekStart ~= nil and A.recordSince(record, weekStart)
				if inWeek then
					bucket.weekIds[id] = true
					bucket.week = bucket.week + 1
				end
				if first and record.result == "win" then
					bucket.wins = bucket.wins + 1
					if inWeek then
						bucket.weekWins = bucket.weekWins + 1
					end
				end
				if first and record.format == "shuffle" then
					local won, played = nil, nil
					if type(A.roundsRecord) == "function" then
						local ok, got, count = pcall(A.roundsRecord, record)
						if ok then
							won, played = got, count
						end
					end
					if type(won) == "number" and type(played) == "number" then
						bucket.rounds = bucket.rounds + played
						bucket.roundsWon = bucket.roundsWon + won
						if inWeek then
							bucket.weekRounds = bucket.weekRounds + played
							bucket.weekRoundsWon = bucket.weekRoundsWon + won
						end
					else
						bucket.untotalled = bucket.untotalled + 1
					end
				end
			end
		end
	end

	local function gap(client, history)
		if client > history then
			return ("%d not in the history"):format(client - history)
		elseif client < history then
			return ("the history holds %d more"):format(history - client)
		end
		return "the same"
	end
	local function figure(label, client, history)
		if type(client) ~= "number" then
			return ("%s client unread, history %d"):format(label, history)
		end
		return ("%s client %d, history %d, %s"):format(label, client, history, gap(client, history))
	end

	if weekStart == nil then
		lines[#lines + 1] = "  the client did not say when this week began, so no weekly figure is printed"
	end

	for i = 1, #formats do
		local format = formats[i]
		local bucket = held[format]
		local client = type(counters[format]) == "table" and counters[format] or {}
		local label = A.formatLabel(format)
		local clientNothing = true
		for _, key in ipairs({ "seasonPlayed", "seasonWon", "weeklyPlayed", "weeklyWon", "roundsSeasonPlayed",
			"roundsSeasonWon", "roundsWeeklyPlayed", "roundsWeeklyWon" }) do
			if type(client[key]) == "number" and client[key] ~= 0 then
				clientNothing = false
			end
		end

		if clientNothing and bucket.idCount == 0 then

		elseif clientNothing then
			lines[#lines + 1] = ("  %s: the client reports nothing for this bracket against %d in the history "
				.. "this season, so it is not compared"):format(label, bucket.idCount)
		elseif format == "shuffle" then
			lines[#lines + 1] = ("  %s this season: %s; %s; %s"):format(label,
				figure("matches", client.seasonPlayed, bucket.idCount),
				figure("rounds played", client.roundsSeasonPlayed, bucket.rounds),
				figure("rounds won", client.roundsSeasonWon, bucket.roundsWon))
			if weekStart ~= nil then
				lines[#lines + 1] = ("  %s this week: %s; %s; %s"):format(label,
					figure("matches", client.weeklyPlayed, bucket.week),
					figure("rounds played", client.roundsWeeklyPlayed, bucket.weekRounds),
					figure("rounds won", client.roundsWeeklyWon, bucket.weekRoundsWon))
			end
		else
			lines[#lines + 1] = ("  %s this season: %s; %s"):format(label,
				figure("played", client.seasonPlayed, bucket.idCount),
				figure("won", client.seasonWon, bucket.wins))
			if weekStart ~= nil then
				lines[#lines + 1] = ("  %s this week: %s; %s"):format(label,
					figure("played", client.weeklyPlayed, bucket.week),
					figure("won", client.weeklyWon, bucket.weekWins))
			end
		end

		if bucket.records ~= bucket.idCount then
			lines[#lines + 1] = ("  %s holds %d records this season under %d distinct match ids")
				:format(label, bucket.records, bucket.idCount)
		end
		if format == "shuffle" and bucket.untotalled > 0 then
			lines[#lines + 1] = ("  %d %s stored no Rounds Won column and %s left out of the round figures")
				:format(bucket.untotalled, bucket.untotalled == 1 and "shuffle" or "shuffles",
					bucket.untotalled == 1 and "is" or "are")
		end
	end

	if unsized > 0 then
		lines[#lines + 1] = ("  %d rated arena %s this season stored no size and %s in neither arena bracket")
			:format(unsized, unsized == 1 and "match" or "matches", unsized == 1 and "is" or "are")
	end

	if weekStart ~= nil and db and type(db.incomplete) == "table" then
		local left = 0
		for i = 1, #db.incomplete do
			local entry = db.incomplete[i]
			if type(entry) == "table" and entry.character == character and entry.rated == true
				and A.recordSince(entry, weekStart) then
				left = left + 1
			end
		end
		if left > 0 then
			lines[#lines + 1] = ("  %d rated %s left before completing this week %s added to no bracket, "
				.. "whether the client counts one being unmeasured"):format(left,
				left == 1 and "match" or "matches", left == 1 and "is" or "are")
		end
	end

	return lines
end



local FACTION_WORD = { [0] = "Horde", [1] = "Alliance" }





function A.recordFaction(record)
	if type(record) ~= "table" or type(record.map) ~= "table" or record.map.instanceType ~= "pvp" then
		return nil, false
	end
	local side = record.selfFaction
	if side == 0 or side == 1 then
		return side, true
	end
	return nil, true
end





function A.duelFaction(record)
	if type(record) ~= "table" or record.format ~= "duel" then
		return nil
	end
	local side = record.duelFaction
	if side == 0 or side == 1 then
		return side
	end
	if record.character ~= nil and record.character == A.ownGuid() then
		return A.playerFaction()
	end
	return nil
end





A.HEAD_ARROW = "\226\134\146"
A.HEAD_DOT = "\194\183"


function A.factionWord(side)
	return FACTION_WORD[side]
end



function A.factionTone(side)
	if side == 0 then
		return "horde"
	elseif side == 1 then
		return "alliance"
	end
	return nil
end


local RESULT_WORD = {
	match = { win = "VICTORY", loss = "DEFEAT", draw = "DRAW" },
	duel  = { win = "WON",     loss = "LOST",   draw = "DRAW" },
}
local RESULT_TONE = { win = "win", loss = "loss" }




function A.resultTone(record)
	if type(record) ~= "table" then
		return nil
	end
	local decided = effectiveResult(record)
	if decided ~= nil then
		return RESULT_TONE[decided]
	end

	local verdict, won, played = A.roundsVerdict(record)
	if verdict ~= "count" then
		return nil
	end
	if won * 2 > played then
		return "win"
	end
	return "loss"
end


local RESULT_LETTER = { win = "W", loss = "L", draw = "D" }



function A.resultLetter(record)
	if type(record) ~= "table" then
		return "-"
	end
	if not A.storesResult(record.format) then
		local verdict, won = A.roundsVerdict(record)
		if verdict == "unsummed" then
			return "?"
		elseif verdict ~= nil then
			return tostring(won)
		end
	end
	local decided = effectiveResult(record)
	return RESULT_LETTER[decided] or "-"
end


local VERDICT_WORD = { win = "WON", loss = "LOST", draw = "DRAW" }






function A.matchVerdict(record)
	if type(record) ~= "table" then
		return nil
	end

	if record.format == "world" then
		local tally = A.worldTally(record)
		return { words = tally or "-", tone = tally and "text" or "dim" }
	end
	local words
	local decided = effectiveResult(record)
	if decided ~= nil then
		words = VERDICT_WORD[decided] or tostring(decided):upper()
	else
		local verdict, won, played = A.roundsVerdict(record)
		if verdict == "draw" then
			words = ("DRAW %d OF %d"):format(won, played)
		elseif verdict == "unsummed" then
			words = "RESULT NOT KNOWN"
		elseif verdict == "count" then
			words = (won * 2 > played and "WON %d OF %d" or "LOST, WON %d OF %d"):format(won, played)
		end
	end
	if words == nil then
		return nil
	end
	local pips = nil
	local rounds = type(record.rounds) == "table" and record.rounds or nil
	if rounds and #rounds > 0 then
		pips = { n = #rounds }
		local known = 0
		for i = 1, #rounds do
			local ok, won = pcall(A.roundResult, record, i)
			if ok and type(won) == "boolean" then
				pips[i] = won
				known = known + 1
			end
		end

		if known == 0 then
			local ok, face, won, played = pcall(A.roundsVerdict, record)
			if ok and (face == "count" or face == "draw") and type(won) == "number" and type(played) == "number" then
				pips.n = played
				for i = 1, played do
					pips[i] = i <= won
				end
			end
		end
	end
	return { words = words, tone = A.resultTone(record) or "dim", pips = pips }
end




function A.ladderSilent(row)
	if type(row) ~= "table" then
		return true
	end

	local function quiet(value)
		return type(value) ~= "number" or value == 0
	end
	return quiet(row.rating) and quiet(row.ratingChange)
		and quiet(row.mmrPre) and quiet(row.mmrPost)
end



function A.ratingDelta(record)
	if type(record) ~= "table" then
		return nil
	end
	local own = record.character and type(record.participants) == "table"
		and record.participants[record.character] or nil


	if A.ladderSilent(own) then
		return nil
	end
	local change = type(own) == "table" and own.ratingChange or nil
	if type(change) ~= "number" then
		return nil
	end
	if change < 0 then
		return ("%+d"):format(change), "loss"
	end
	if change > 0 then
		return ("%+d"):format(change), "win"
	end
	return "0", nil
end


function A.sideWord(side)
	if side == "yours" then
		return "your team"
	end
	if side == "theirs" then
		return "their team"
	end
	return tostring(side)
end



function A.roundsRecord(record)
	local rounds = type(record) == "table" and record.rounds or nil
	if type(rounds) ~= "table" or #rounds < 1 then
		return nil
	end

	local own = record.character and type(record.participants) == "table"
		and record.participants[record.character] or nil
	local stats = type(own) == "table" and own.stats or nil
	if type(stats) ~= "table" then
		return nil
	end



	local columns = orderedColumns(record)
	if not columns then
		return nil
	end

	local won
	for i = 1, #columns do
		if A.columnName(columns[i]) == "Rounds Won" then
			local value = stats[columns[i].id]
			if type(value) == "number" then
				won = value
			end
			break
		end
	end

	if won == nil then
		return nil
	end
	return won, #rounds
end




function A.roundPacing(record)
	local rounds = type(record) == "table" and record.rounds or nil
	if type(rounds) ~= "table" or #rounds < 2 then
		return nil
	end

	local previous = record.openedEpoch
	if type(previous) ~= "number" then
		return nil
	end

	local out, longest = {}, 0
	for i = 1, #rounds do
		local ended = type(rounds[i]) == "table" and rounds[i].endedEpoch or nil
		if type(ended) ~= "number" then
			return nil
		end
		local seconds = ended - previous
		if seconds < 0 then
			return nil
		end
		out[i] = seconds
		if seconds > longest then
			longest = seconds
		end
		previous = ended
	end


	if longest <= 0 then
		return nil
	end

	return { rounds = out, longest = longest }
end



function A.roundSides(record, round)
	if type(record) ~= "table" or type(round) ~= "table" then
		return nil
	end
	local stored = round.mates
	if type(stored) ~= "table" or #stored == 0 then
		return nil
	end

	local participants = type(record.participants) == "table" and record.participants or nil
	if not participants then
		return nil
	end

	local bySeat, seats = {}, 0
	for guid, participant in pairs(participants) do
		if type(guid) == "string" and type(participant) == "table"
			and type(participant.seat) == "number" then
			bySeat[participant.seat] = { guid = guid, p = participant }
			if participant.seat > seats then
				seats = participant.seat
			end
		end
	end

	local mates, seen = {}, {}
	for m = 1, #stored do
		local seat = stored[m]
		local entry = type(seat) == "number" and bySeat[seat] or nil
		if not entry then
			return nil
		end
		seen[entry.guid] = true
		mates[#mates + 1] = entry
	end

	local foes = {}
	for seat = 1, seats do
		local entry = bySeat[seat]
		if entry and not seen[entry.guid] and entry.guid ~= record.character then
			foes[#foes + 1] = entry
		end
	end

	return mates, foes
end


local MAX_SOLVE_ROUNDS = 16




local function roundsWonTotals(record)
	local columns = orderedColumns(record)
	if not columns then
		return nil
	end

	local id
	for i = 1, #columns do
		if A.columnName(columns[i]) == "Rounds Won" then
			id = columns[i].id
			break
		end
	end
	if id == nil then
		return nil
	end

	local participants = type(record.participants) == "table" and record.participants or nil
	if not participants then
		return nil
	end

	local totals, seen, sum = {}, 0, 0
	for guid, participant in pairs(participants) do
		if type(guid) == "string" and type(participant) == "table" then
			local stats = type(participant.stats) == "table" and participant.stats or nil
			local value = stats and stats[id] or nil
			if type(value) ~= "number" then
				return nil
			end
			totals[guid] = value
			seen = seen + 1
			sum = sum + value
		end
	end
	if seen == 0 then
		return nil
	end
	return totals, sum
end



local function roundSideGuids(record)
	local rounds = type(record.rounds) == "table" and record.rounds or nil
	if not rounds or #rounds == 0 then
		return nil
	end
	if record.character == nil then
		return nil
	end

	local sides = {}
	for i = 1, #rounds do
		local mates, foes = A.roundSides(record, rounds[i])
		if not (mates and foes) then
			return nil
		end
		local mine = { record.character }
		for m = 1, #mates do
			mine[#mine + 1] = mates[m].guid
		end
		local theirs = {}
		for f = 1, #foes do
			theirs[#theirs + 1] = foes[f].guid
		end

		if #mine == 0 or #mine ~= #theirs then
			return nil
		end
		sides[i] = { mine = mine, theirs = theirs, size = #mine }
	end
	return sides
end



local function fitAssignments(n, fixed, sides, totals, mineTotal)
	local fits, agree = 0, nil
	local last = (2 ^ n) - 1
	for mask = 0, last do
		local take, wins, ok = {}, 0, true
		for i = 1, n do
			local won = math.floor(mask / (2 ^ (i - 1))) % 2 == 1
			if fixed[i] ~= nil and fixed[i] ~= won then
				ok = false
				break
			end
			take[i] = won
			if won then
				wins = wins + 1
			end
		end
		if ok and wins == mineTotal then
			local tally = {}
			for guid in pairs(totals) do
				tally[guid] = 0
			end
			for i = 1, n do
				local side = take[i] and sides[i].mine or sides[i].theirs
				for s = 1, #side do
					if tally[side[s]] == nil then

						ok = false
					else
						tally[side[s]] = tally[side[s]] + 1
					end
				end
			end
			if ok then
				for guid, want in pairs(totals) do
					if tally[guid] ~= want then
						ok = false
						break
					end
				end
			end
			if ok then
				fits = fits + 1
				if agree == nil then
					agree = take
				else

					for i = 1, n do
						if agree[i] ~= nil and agree[i] ~= take[i] then
							agree[i] = nil
						end
					end
				end
			end
		end
	end
	return fits, agree
end




function A.roundTypedFits(record, index, won)
	local rounds = {}
	if type(record) == "table" and type(record.rounds) == "table" then
		rounds = record.rounds
	end
	local n = #rounds
	if n == 0 or n > MAX_SOLVE_ROUNDS or type(index) ~= "number" or type(won) ~= "boolean" then
		return nil
	end
	local sides = roundSideGuids(record)
	local totals, sum = nil, nil
	if sides then
		totals, sum = roundsWonTotals(record)
	end
	if not (sides and totals) then
		return nil
	end
	local expect = 0
	for i = 1, n do
		expect = expect + sides[i].size
	end
	local mineTotal = totals[record.character]
	if sum ~= expect or type(mineTotal) ~= "number" then
		return nil
	end

	local fixed = {}
	for i = 1, n do
		local round = rounds[i]
		if type(round) == "table" and type(round.won) == "boolean" then
			fixed[i] = round.won
		end
	end
	if fitAssignments(n, fixed, sides, totals, mineTotal) == 0 then
		return nil
	end

	for i = 1, n do
		if fixed[i] == nil and i ~= index then
			local typed = A.typedRound(record, i)
			if typed ~= nil then
				fixed[i] = typed == "win"
			end
		end
	end
	if fixed[index] ~= nil and fixed[index] ~= won then
		return false
	end
	fixed[index] = won
	return fitAssignments(n, fixed, sides, totals, mineTotal) > 0
end



function A.roundsFit(record, won)
	if type(record) ~= "table" or type(record.rounds) ~= "table" or type(won) ~= "table" then
		return nil
	end
	local n = #record.rounds
	if n == 0 or n > MAX_SOLVE_ROUNDS then
		return nil
	end
	local sides = roundSideGuids(record)
	if not sides then
		return nil
	end
	local totals, sum = roundsWonTotals(record)
	if not totals then
		return nil
	end
	local expect = 0
	for i = 1, n do
		expect = expect + sides[i].size
	end
	local mineTotal = totals[record.character]
	if sum ~= expect or type(mineTotal) ~= "number" then
		return nil
	end
	local fixed = {}
	for i = 1, n do
		if type(won[i]) == "boolean" then
			fixed[i] = won[i]
		end
	end
	return fitAssignments(n, fixed, sides, totals, mineTotal) > 0
end


local ROUND_SIDE = A.ROUND_MATES + 1



function A.roundsSummed(record)
	if type(record) ~= "table" or type(record.rounds) ~= "table" or #record.rounds == 0 then
		return nil
	end
	local totals, sum = roundsWonTotals(record)
	if not totals then
		return nil
	end
	local seats = 0
	for _ in pairs(totals) do
		seats = seats + 1
	end
	if seats ~= 2 * ROUND_SIDE then
		return nil
	end
	return sum == ROUND_SIDE * #record.rounds
end








function A.roundsVerdict(record)
	local won, played = A.roundsRecord(record)
	if won == nil or type(played) ~= "number" or played <= 0 then
		return nil
	end
	if A.roundsSummed(record) == false then

		local _, sum = roundsWonTotals(record)
		local scored = type(sum) == "number" and sum % ROUND_SIDE == 0 and sum / ROUND_SIDE or nil
		if not (scored and scored > 0 and scored <= played and won <= scored) then
			return "unsummed", won, played
		end
		played = scored
	end
	if won * 2 == played then
		return "draw", won, played
	end
	return "count", won, played
end







function A.applyRoundWins(record)
	local proposed, refusal = A.proposeRoundWins(record)
	if proposed == nil then
		if refusal == nil then
			return nil, nil
		end
		return 0, refusal
	end

	local written = 0
	for i = 1, #record.rounds do
		local round = record.rounds[i]
		if type(round) == "table" and type(proposed[i]) == "boolean" then
			round.won = proposed[i]
			written = written + 1
		end
	end


	if written > 0 then
		A.forgetRoundOutcomes(record)
	end
	return written, nil
end




function A.proposeRoundWins(record)
	if type(record) ~= "table" or type(record.rounds) ~= "table" or #record.rounds == 0 then
		return nil, nil
	end
	local rounds = record.rounds
	local n = #rounds

	local totals, sum = roundsWonTotals(record)
	local mineTotal = totals and totals[record.character] or nil
	if not totals or type(mineTotal) ~= "number" then
		return nil, "untotalled"
	end


	local anchors = { { at = 0, count = 0 } }
	for i = 1, n - 1 do
		local round = rounds[i]
		if type(round) == "table" and type(round.winsPost) == "number" then
			anchors[#anchors + 1] = { at = i, count = round.winsPost }
		end
	end
	anchors[#anchors + 1] = { at = n, count = mineTotal }


	local proposed = {}
	for a = 2, #anchors do
		local from, to = anchors[a - 1], anchors[a]
		local span = to.at - from.at
		local difference = to.count - from.count
		if difference < 0 or difference > span then
			return nil, "difference"
		end
		if difference == 0 then
			for i = from.at + 1, to.at do
				proposed[i] = false
			end
		elseif difference == span then
			for i = from.at + 1, to.at do
				proposed[i] = true
			end
		end
	end

	if sum ~= ROUND_SIDE * n then
		return nil, "unsummable"
	end

	if A.roundsFit(record, proposed) == false then
		return nil, "tally"
	end

	return proposed, nil
end




function A.roundWinsRefusal(record)
	if type(record) ~= "table" or type(record.rounds) ~= "table" then
		return nil
	end
	local read = false
	for i = 1, #record.rounds do
		local round = record.rounds[i]
		if type(round) == "table" and type(round.winsPost) == "number" then
			read = true
			break
		end
	end
	if not read then
		return nil
	end
	local ok, _, refusal = pcall(A.proposeRoundWins, record)
	if not ok then
		return nil
	end
	return refusal
end








function A.roundWinners(record)
	if type(record) ~= "table" then
		return nil, "unreadable", 0, 0
	end
	local rounds = type(record.rounds) == "table" and record.rounds or nil
	if not rounds or #rounds == 0 then
		return nil, "unreadable", 0, 0
	end
	local n = #rounds



	local fixed, stored = {}, 0
	for i = 1, n do
		local round = rounds[i]
		if type(round) == "table" and type(round.won) == "boolean" then
			fixed[i] = round.won
			stored = stored + 1
		end
	end
	if stored == n then
		local outcomes = {}
		for i = 1, n do
			outcomes[i] = { won = fixed[i], derived = false }
		end
		return outcomes, "stored", n, n, 1
	end



	local function keptStored()
		if stored == 0 then
			return nil, 0
		end
		local out = {}
		for i = 1, n do
			if fixed[i] ~= nil then
				out[i] = { won = fixed[i], derived = false }
			end
		end
		return out, stored
	end



	if n > MAX_SOLVE_ROUNDS then
		local kept, keptN = keptStored()
		return kept, "unbounded", keptN, n
	end

	local sides = roundSideGuids(record)
	if not sides then
		local kept, keptN = keptStored()
		return kept, "unreadable", keptN, n
	end

	local totals, sum = roundsWonTotals(record)
	if not totals then
		local kept, keptN = keptStored()
		return kept, "untotalled", keptN, n
	end


	local expect = 0
	for i = 1, n do
		expect = expect + sides[i].size
	end
	if sum ~= expect then
		local kept, keptN = keptStored()
		return kept, "unsummable", keptN, n
	end

	local mineTotal = totals[record.character]
	if type(mineTotal) ~= "number" or mineTotal < 0 or mineTotal > n then
		local kept, keptN = keptStored()
		return kept, "unsummable", keptN, n
	end

	local fits, agree = fitAssignments(n, fixed, sides, totals, mineTotal)

	if fits == 0 or agree == nil then
		local kept, keptN = keptStored()
		return kept, "none", keptN, n
	end

	local outcomes, settled = {}, 0
	for i = 1, n do
		if agree[i] ~= nil then
			outcomes[i] = { won = agree[i], derived = fixed[i] == nil }
			settled = settled + 1
		end
	end
	return outcomes, (fits == 1) and "solved" or "partial", settled, n, fits
end




local winnersCache = setmetatable({}, { __mode = "k" })


function A.forgetRoundOutcomes(record)
	if type(record) == "table" then
		winnersCache[record] = nil
	end
end




function A.roundOutcomes(record)
	if type(record) ~= "table" then
		return nil, "unreadable", 0, 0
	end
	local rounds = type(record.rounds) == "table" and record.rounds or nil
	local n = rounds and #rounds or 0

	local hit = winnersCache[record]
	if hit and hit.n == n and hit.rounds == rounds then
		return hit.outcomes, hit.state, hit.settled, hit.considered, hit.fits
	end

	local outcomes, state, settled, considered, fits = A.roundWinners(record)
	winnersCache[record] = { n = n, rounds = rounds, outcomes = outcomes, state = state,
		settled = settled, considered = considered, fits = fits }
	return outcomes, state, settled, considered, fits
end


function A.typedRound(record, index)
	local manual = type(record) == "table" and record.manual or nil
	local rounds = type(manual) == "table" and manual.rounds or nil
	local entry = type(rounds) == "table" and type(index) == "number" and rounds[index] or nil
	local result = type(entry) == "table" and entry.result or nil
	if result == "win" or result == "loss" then
		return result
	end
	return nil
end



function A.roundResult(record, index)
	local outcomes = A.roundOutcomes(record)
	local entry = type(outcomes) == "table" and type(index) == "number" and outcomes[index] or nil
	if type(entry) == "table" and type(entry.won) == "boolean" then
		return entry.won, entry.derived == true, false
	end
	local typed = A.typedRound(record, index)
	if typed ~= nil then
		return typed == "win", false, true
	end
	return nil
end





function A.roundTable(record)
	local rounds = type(record) == "table" and record.rounds or nil
	if type(rounds) ~= "table" or #rounds < 1 then
		return nil
	end
	local participants = type(record.participants) == "table" and record.participants or nil
	if not participants then
		return nil
	end

	local cells = function(entry)
		if type(entry) ~= "table" then
			return nil
		end
		local ok, cell = pcall(A.participantCells, record, entry, nil, nil)
		return ok and cell or nil
	end

	local own = record.character ~= nil and participants[record.character] or nil

	local previous = nil
	if type(own) == "table" and not A.ladderSilent(own) and type(own.rating) == "number" then
		previous = own.rating
	end

	local out, read, won = {}, 0, nil
	for i = 1, #rounds do
		local stored = rounds[i]
		local row = { n = i }
		if type(stored) == "table" then

			local outcome, derived, byHand = A.roundResult(record, i)
			if type(outcome) == "boolean" then
				row.won = outcome
				row.derived = derived
				row.byHand = byHand
				row.result = outcome and "WON" or "LOST"
				row.tone = outcome and "win" or "loss"
				won = (won or 0) + (outcome and 1 or 0)
			end


			local mateEntries, foeEntries = A.roundSides(record, stored)
			if mateEntries and foeEntries then
				local mates, whole = {}, true



				local ownEntry = record.character ~= nil and type(own) == "table"
					and { guid = record.character, p = own } or nil
				if ownEntry then
					local cell = cells(ownEntry)
					if cell then
						mates[#mates + 1] = cell
					else


						whole = false
					end
				end
				for m = 1, whole and #mateEntries or 0 do
					local cell = cells(mateEntries[m])
					if not cell then
						whole = false
						break
					end
					mates[#mates + 1] = cell
				end
				if whole then
					row.mates = mates
					local foes = {}
					for f = 1, #foeEntries do
						local cell = cells(foeEntries[f])
						if cell then
							foes[#foes + 1] = cell
						end
					end
					row.foes = foes
				end
			end

			if type(stored.ratingPost) == "number" then
				row.rating = stored.ratingPost
				if type(previous) == "number" then
					row.delta = stored.ratingPost - previous
				end
				previous = stored.ratingPost
			end
		end

		if row.result ~= nil or row.mates ~= nil or row.rating ~= nil then
			read = read + 1
		end
		out[i] = row
	end

	if read == 0 then
		return nil
	end


	local decided = nil
	for i = 1, #out do
		if out[i].result ~= nil then
			decided = true
			break
		end
	end
	return { rounds = out, read = read, total = #rounds, won = won, decided = decided }
end




function A.roundHiddenWins(record, table_)
	if type(table_) ~= "table" or type(table_.rounds) ~= "table" then
		return nil
	end



	local unsettled = 0
	for i = 1, #table_.rounds do
		local row = table_.rounds[i]
		if type(row) ~= "table" or row.result == nil then
			unsettled = unsettled + 1
		end
	end
	if unsettled < 1 then
		return nil
	end

	local won = A.roundsRecord(record)
	if type(won) ~= "number" then
		return nil
	end

	local shown = type(table_.won) == "number" and table_.won or 0
	local hidden = won - shown
	if hidden < 1 then
		return nil
	end

	return hidden, unsettled
end





function A.windowHeadLines(record, head, provenance)
	local duel = record.format == "duel"
	local game = A.theme() ~= "flat"
	local own = record.character and type(record.participants) == "table"
		and record.participants[record.character] or nil
	own = type(own) == "table" and own or nil

	local details = {}
	local function detail(text, tone, place)
		if text ~= nil then
			details[#details + 1] = { text = tostring(text), tone = tone, place = place }
		end
	end
	detail(head.place, "text", true)
	if duel and record.map then
		detail(record.map.name, "dim")
	end
	detail(spanText(record.duration), "dim")
	if own and type(own.spec) == "string" and own.spec ~= "" then
		detail(type(own.class) == "string" and own.class ~= "" and (own.spec .. " " .. own.class)
			or own.spec, "dim")
	end
	detail(A.durationCaveat(record.openedState), "caveat")
	detail(record.outcome, "caveat")
	if record.duelToTheDeath then
		detail("to the death", "caveat")
	end
	if record.map and provenance then
		local where = {}
		clause(where, record.map.instanceType, "instance type %s")
		clause(where, record.map.instanceId, "instance id %s")
		if #where > 0 then
			detail(table.concat(where, ", "), "dim")
		end
	end

	local verdict = A.matchVerdict(record)
	local parts = {
		place = head.place, faction = head.faction, details = details,
		result = verdict and verdict.words or nil, resultTone = verdict and verdict.tone or nil,
		pips = verdict and verdict.pips or nil,
		ratingFrom = head.ratingFrom, ratingTo = head.ratingTo,
		delta = head.delta, deltaTone = head.deltaTone, format = record.format,
	}


	local ladder = nil
	if duel or record.rated ~= true then
		parts.chipWhy = "unrated"
	elseif parts.ratingFrom == nil or parts.ratingTo == nil then
		parts.chipWhy = "no-rating"
	else
		local rating, why = A.matchRatingParts(record.format, tonumber(parts.ratingFrom),
			tonumber(parts.ratingTo))
		if rating then
			parts.chip = rating.chip
			ladder = rating.ladder
		else
			parts.chipWhy = why or "no-ladder"
		end
	end

	if not duel and own and type(own.mmrPost) == "number" and own.mmrPost > 0 then
		parts.mmr = ("%d"):format(own.mmrPost)
	end

	local function with(kind)
		local out = { kind = kind }
		for key, value in pairs(parts) do
			out[key] = value
		end
		return out
	end
	local top, sub = with("heading"), with("headline")

	local function ratingWords(words)
		if parts.ratingFrom ~= nil and parts.ratingTo ~= nil then
			put(words, parts.ratingFrom .. " " .. A.HEAD_ARROW .. " " .. parts.ratingTo)
		end
		put(words, parts.delta)
	end
	local function chipWords(words)
		if parts.chip then
			put(words, parts.chip.word .. (parts.chip.reached and " reached" or ""))
		end
		if parts.mmr then
			put(words, "mmr " .. parts.mmr)
		end
	end
	local function detailWords(words, skipPlace)
		for i = 1, #details do
			if not (skipPlace and details[i].place) then
				put(words, details[i].text)
			end
		end
	end
	local topWords, subWords = {}, {}
	if game then
		put(topWords, parts.place)
		detailWords(topWords, true)
		put(topWords, parts.result)
		ratingWords(subWords)
		chipWords(subWords)
	else
		put(topWords, parts.result)
		ratingWords(topWords)
		detailWords(subWords, false)
		chipWords(subWords)
	end
	top.text = #topWords > 0 and table.concat(topWords, "  ") or nil
	sub.text = #subWords > 0 and table.concat(subWords, "  ") or nil

	local ladderHead = nil
	if ladder then
		local words = {}
		for i = 1, #ladder.bars do
			put(words, ladder.bars[i].word)
		end
		ladderHead = { kind = "ladder", ladder = ladder, text = table.concat(words, "  ") }
	end

	local cardsHead = nil
	if game then
		local cards = A.matchRoundCards(record)
		if cards then
			local words = {}
			for i = 1, #cards do
				put(words, ("R%d %s"):format(cards[i].n, cards[i].word))
			end
			cardsHead = { kind = "cards", cards = cards, text = table.concat(words, "  ") }
		end
	end

	return top.text and top or nil, sub.text and sub or nil, ladderHead, cardsHead
end






function A.detailLines(record, pane)
	local lines, heads = {}, {}

	local duel = record.format == "duel"

	local head = { kind = "headline" }


	local decided, byHand = effectiveResult(record)
	if decided ~= nil then
		local words = RESULT_WORD[duel and "duel" or "match"]
		head.result = words[decided] or tostring(decided):upper()
		head.resultTone = A.resultTone(record)

		head.mark = (byHand and not pane) and "(entered by hand)" or nil
	end


	local roundsWon, roundsPlayed
	if head.result == nil then
		local verdict
		verdict, roundsWon, roundsPlayed = A.roundsVerdict(record)
		if verdict == "draw" then
			head.result = RESULT_WORD.match.draw
			head.resultTone = A.resultTone(record)
		elseif verdict == "unsummed" then
			head.result = "RESULT NOT KNOWN"
			head.resultTone = A.resultTone(record)
		elseif verdict == "count" then


			head.result = ("WON %d OF %d"):format(roundsWon, roundsPlayed)
			head.resultTone = A.resultTone(record)
		end
	end


	if head.result == nil and record.format == "world" then
		head.result = A.worldTally(record) or "-"
	end


	head.badge = record.format ~= nil and A.formatLabel(record.format) or nil


	if duel then
		head.place = record.opponentName
	elseif record.map then
		head.place = record.map.name
	end


	if not duel then
		head.delta, head.deltaTone = A.ratingDelta(record)
	end


	if head.delta ~= nil then
		local own = record.character and type(record.participants) == "table"
			and record.participants[record.character] or nil
		if type(own) == "table" and type(own.rating) == "number"
			and type(own.ratingChange) == "number" then
			head.ratingFrom = ("%d"):format(own.rating)
			head.ratingTo = ("%d"):format(own.rating + own.ratingChange)
		end
	end


	if duel then
		head.faction = A.duelFaction(record)
	else
		head.faction = A.recordFaction(record)
	end


	local headParts = {}
	put(headParts, A.factionWord(head.faction))
	put(headParts, head.result and (head.mark and (head.result .. " " .. head.mark) or head.result))
	put(headParts, head.badge)
	put(headParts, head.place)
	put(headParts, head.delta)
	if #headParts > 0 and not pane then
		lines[#lines + 1] = table.concat(headParts, "  ")
		heads[#lines] = head
	end




	local provenance = type(A.debugTextEnabled) == "function" and A.debugTextEnabled() == true

	local when = {}
	if not pane then
		clause(when, record.id, "match #%s")
	end

	if record.rated ~= nil then
		put(when, record.rated and "rated" or "unrated")
	end
	clause(when, record.outcome)
	if record.duelToTheDeath then
		put(when, "to the death")
	end
	put(when, spanText(record.duration))

	put(when, A.durationCaveat(record.openedState))

	if record.rounds and #record.rounds > 0 and roundsWon == nil then
		put(when, ("%d rounds"):format(#record.rounds))
	end


	put(when, A.seasonText(record, pane))
	if record.openedAt ~= nil then

		local stamp = tostring(record.openedAt)
		if spanText(record.duration) ~= nil then
			stamp = stamp:match("^(%d%d%d%d%-%d%d%-%d%d)") or stamp
		end
		put(when, "opened " .. stamp)
	else
		clause(when, record.completedAt, "ended %s")
	end
	if duel and record.map then
		clause(when, record.map.name)
	end


	if record.map and provenance then
		local where = {}
		clause(where, record.map.instanceType, "instance type %s")
		clause(where, record.map.instanceId, "instance id %s")
		if #where > 0 then
			put(when, table.concat(where, ", "))
		end
	end
	if pane then
		local top, sub, ladder, cards = A.windowHeadLines(record, head, provenance)

		local both = { top, sub, ladder, cards }
		for i = 1, 4 do
			local part = both[i]
			if part ~= nil then
				lines[#lines + 1] = part.text
				heads[#lines] = part
			end
		end
	elseif #when > 0 then
		lines[#lines + 1] = "  " .. table.concat(when, "  ")


		heads[#lines] = { kind = "stamps", parts = when }
	end



	local edited, editedParts = nil, nil
	if not pane then
		edited, editedParts = editedLine(record, pane)
	end
	if edited then
		lines[#lines + 1] = "  " .. edited
		heads[#lines] = { kind = "edited", parts = editedParts }
	end



	if provenance then
		local harvest = A.harvestLine(record)
		if harvest then
			lines[#lines + 1] = "  " .. harvest
		end
	end

	local columns = provenance and orderedColumns(record) or nil
	if columns then
		local named = {}
		for i = 1, #columns do

			named[i] = A.columnName(columns[i]):upper()
		end
		lines[#lines + 1] = "  columns: " .. table.concat(named, ", ")
	end


	local objColumns = A.objectiveColumns(record)


	local totals = A.objectiveTotals(record)
	if totals then
		local parts = { "objectives" }

		for _, side in ipairs({ { A.sideWord("yours"):upper(), totals.yours },
			{ A.sideWord("theirs"):upper(), totals.theirs } }) do
			local cells = { side[1] }
			for c = 1, #totals.columns do
				local value = side[2][c]
				cells[#cells + 1] = ("%s %s"):format(
					value ~= nil and tostring(value) or "-", totals.columns[c].short)
			end
			parts[#parts + 1] = table.concat(cells, "  ")
		end
		lines[#lines + 1] = "  " .. table.concat(parts, "  ")
		heads[#lines] = { kind = "objectives", totals = totals }
	end



	local lobbySort, lobbyAscending = nil, nil
	if type(A.lobbySort) == "function" then
		lobbySort, lobbyAscending = A.lobbySort()
	end


	local merged = nil
	if pane and type(A.lobbyPaneDraws) == "function" and A.lobbyPaneDraws(record) then
		local entries = rosterEntries(record)
		local entrySides = rosterSides(record, entries)
		local joined, own = {}, nil
		for i = 1, #entries do
			local c = A.participantCells(record, entries[i], entrySides, objColumns)
			local values = c.objectiveValues
			local figures = {
				cells = c,
				name = c.name,
				specLabel = c.specLabel,
				damage = A.figureText(c.damage),
				wins = type(values) == "table" and values[1] or nil,
				kb = c.kb,
				dispels = c.dispels,
			}
			if type(entries[i].guid) == "string" then
				joined[entries[i].guid] = figures
			end
			if c.self then
				own = figures
			end
		end
		local paneColumns = A.lobbyPaneColumns(record, #entries)
		if type(paneColumns) == "table" then
			merged = { columns = paneColumns, joined = joined, own = own }
		end
	end

	local lobbyRows, lobbyRead, lobbyTotal, lobbyTally, lobbyTyped = nil, 0, 0, nil, 0
	if type(A.lobbyRows) == "function" then
		local got, rows, read, total, tally, typed =
			pcall(A.lobbyRows, record, lobbySort, lobbyAscending, merged and merged.columns or nil,
				merged and merged.joined or nil)
		if got and type(rows) == "table" then
			lobbyRows, lobbyRead, lobbyTotal, lobbyTally = rows, read, total, tally
			lobbyTyped = type(typed) == "number" and typed or 0
		end
	end
	local lobbyColumns = type(A.lobbyColumns) == "function" and A.lobbyColumns(record) or nil
	if merged then
		lobbyColumns = merged.columns
	end
	local drewTable = false

	local lobbyGuids = {}
	if lobbyRows and #lobbyRows > 0 and type(lobbyColumns) == "table" then
		drewTable = true
		local claim = A.lobbyClaim(lobbyTally, lobbyRead, lobbyTotal)
		local opposites = nil
		if claim ~= nil then
			opposites = A.lobbyOpposites(lobbyTally, lobbyRead)
		end


		local refusal = type(A.roundWinsRefusal) == "function" and A.roundWinsRefusal(record) or nil
		for _, said in ipairs(A.lobbyCaption(claim, lobbyRead, lobbyTotal, opposites, lobbyTyped,
			{ refusal = refusal, pane = pane == true })) do
			lines[#lines + 1] = "  " .. said
		end


		local labels = {}
		for i = 1, #lobbyRows do
			labels[i] = lobbyRows[i].cells and lobbyRows[i].cells[1] or nil
		end
		local shared = { columns = lobbyColumns, sort = lobbySort, ascending = lobbyAscending,
			labels = labels, record = record.id, merged = merged ~= nil }

		lines[#lines + 1] = ""
		heads[#lines] = { kind = "lobbyGroup", columns = lobbyColumns, table = shared }
		local names = {}
		for c = 1, #lobbyColumns do
			names[c] = lobbyColumns[c].name
		end
		lines[#lines + 1] = "    " .. table.concat(names, "  ")
		heads[#lines] = { kind = "lobbyHead", columns = lobbyColumns, sort = lobbySort,
			ascending = lobbyAscending, table = shared }
		for i = 1, #lobbyRows do
			local row = lobbyRows[i]
			lines[#lines + 1] = "    " .. tostring(row.text or "")
			heads[#lines] = { kind = "lobbyRow", columns = lobbyColumns, row = row, table = shared }
			if merged and type(row.key) == "string" then
				lobbyGuids[#lines] = row.key
			end
		end

		local you = A.lobbyYou(record, lobbyColumns)

		shared.results = {}
		for c = 1, #lobbyColumns do
			local entry = type(you.rounds) == "table" and you.rounds[c] or nil
			if type(entry) == "table" and type(entry.won) == "boolean" then
				shared.results[entry.round] = entry.won
			end
		end

		if merged then
			local own = merged.own
			you.joined = own
			for c = 1, #lobbyColumns do
				local key = lobbyColumns[c].key
				if key == "name" then
					you.cells[c] = own and own.name or "-"
				elseif key == "spec" then
					you.cells[c] = own and own.specLabel or "-"
				elseif key == "damage" or key == "wins" or key == "kb" or key == "dispels" then
					local value = own and own[key] or nil
					you.cells[c] = value ~= nil and tostring(value) or "-"
				end
			end
			if own and type(own.cells) == "table" and type(own.cells.guid) == "string" then
				lobbyGuids[#lines + 1] = own.cells.guid
			end
		end
		lines[#lines + 1] = "    " .. tostring(you.text)
		heads[#lines] = { kind = "lobbyYou", columns = lobbyColumns, row = you, table = shared }

		local words = A.lobbySortWords(lobbySort, lobbyAscending)
		lines[#lines + 1] = ("    sorted %s"):format(words)
		heads[#lines] = { kind = "lobbyFoot", columns = lobbyColumns, words = words, table = shared }


		if type(A.noteLobbyClaim) == "function" then
			A.noteLobbyClaim(record.id, claim, A.lobbyDrawn(lobbyRows, lobbyColumns))
		end
	end

	if not drewTable then
		local pacing = A.roundPacing(record)
		if pacing then
			local parts = {}
			for i = 1, #pacing.rounds do
				parts[#parts + 1] = ("R%d %s"):format(i, spanText(pacing.rounds[i]) or "-")
			end
			lines[#lines + 1] = "  rounds  " .. table.concat(parts, "  ")
			heads[#lines] = { kind = "pacing", pacing = pacing }
		end
	end


	if merged and drewTable then
		return lines, lobbyGuids, {}, heads
	end

	local roster = rosterEntries(record)




	if (record.format == "duel" or record.format == "world") and #roster < 2 then
		return lines, {}, {}, heads
	end

	local sides = rosterSides(record, roster)


	roster = ownSideFirst(roster, sides)


	local maxDamage = 0





	local filled = {}
	for i = 1, #roster do
		local p = roster[i].p
		local d = p.damage
		if type(d) == "number" and d > maxDamage then
			maxDamage = d
		end
		if p.spec ~= nil then filled.spec = true end
		if p.role ~= nil then filled.role = true end
		if type(d) == "number" then filled.damage = true end
		if type(p.healing) == "number" then filled.healing = true end
		if type(p.killingBlows) == "number" then filled.kb = true end
	end

	if filled.damage or filled.healing or filled.kb then
		filled.dispels = true
	end

	local heading = ("  %d participants"):format(#roster)

	local stored = nil
	if record.participantCount ~= nil and record.participantCount ~= #roster then
		stored = record.participantCount
		heading = heading .. (", stored count %s"):format(tostring(stored))
	end
	lines[#lines + 1] = heading


	heads[#lines] = { kind = "roster", count = #roster, stored = stored, columns = objColumns,
		filled = filled }




	local guids, cells = {}, {}



	local sideCount = {}
	local sideBots = {}
	if sides then
		for i = 1, #roster do
			local faction = roster[i].p.faction
			if faction ~= nil then
				local which = faction == sides.own and "yours" or "theirs"
				sideCount[which] = (sideCount[which] or 0) + 1
				if type(A.isBotGuid) == "function" and A.isBotGuid(roster[i].guid) then
					sideBots[which] = (sideBots[which] or 0) + 1
				end
			end
		end
	end


	local lastSide = nil

	for i = 1, #roster do
		local c = A.participantCells(record, roster[i], sides, objColumns)

		if c.side ~= nil and c.side ~= lastSide then
			lastSide = c.side

			local sideSize = sideCount[c.side] or 0
			local bots = sideBots[c.side] or 0
			local sideLine = ("  %d %s"):format(sideSize, A.sideWord(c.side))
			if bots > 0 then
				sideLine = sideLine .. (bots == sideSize and ", all bots"
					or (", %d %s"):format(bots, bots == 1 and "bot" or "bots"))
			end
			lines[#lines + 1] = sideLine
			heads[#lines] = { kind = "roster", side = c.side, count = sideSize, bots = bots }
		end

		lines[#lines + 1] = participantLine(record, roster[i], sides, c)
		guids[#lines] = roster[i].guid

		c.share = (type(c.damage) == "number" and maxDamage > 0)
			and (c.damage / maxDamage) or nil
		c.filled = filled
		cells[#lines] = c
	end

	return lines, guids, cells, heads
end





function A.matchCountText(entry, pane)
	local matches = type(entry) == "table" and entry.matches or nil
	if type(matches) ~= "number" then
		return "no recorded match"
	end
	local text = matchNoun(matches)


	if A.playerAllGenerated(entry) and not pane then
		text = text .. ", all generated"
	end
	return text
end



local function sideText(key, bucket, pane)
	if type(bucket) ~= "table" or (bucket.count or 0) == 0 then
		return nil
	end

	local label = SIDE_WORDS[key] or key
	local count, decided, wins = bucket.count, bucket.decided or 0, bucket.wins or 0
	if decided == 0 then
		return ("%d %s, no decided result"):format(count, label)
	end

	local text = ("%d %s, won %d of %d decided"):format(count, label, wins, decided)
	local byHand = bucket.manualDecided or 0
	if byHand > 0 and not pane then
		text = text .. (", %d entered by hand"):format(byHand)
	end
	return text
end




function A.isSelfPlayer(guid)
	if type(guid) ~= "string" or guid == "" then
		return false
	end
	if type(UnitGUID) ~= "function" then
		return false
	end
	local ok, own = pcall(UnitGUID, "player")
	return ok and own == guid
end



local function foldsIntoSides(entry, guid, counted)
	local matches = tonumber(entry.matches)
	if not matches or matches <= 0 then
		return false
	end
	return counted == matches and not A.isSelfPlayer(guid)
end


local function countClause(entry, guid, counted, pane)
	if foldsIntoSides(entry, guid, counted) then
		return (A.playerAllGenerated(entry) and not pane) and "all generated" or nil
	end
	return A.matchCountText(entry, pane)
end


local function splitParts(entry, guid, pane)
	local parts = {}
	local counted = 0

	if A.isSelfPlayer(guid) then
		local bucket = entry.with
		if type(bucket) == "table" and (bucket.decided or 0) > 0 then
			local text = ("won %d of %d decided"):format(bucket.wins or 0, bucket.decided)
			local byHand = bucket.manualDecided or 0
			if byHand > 0 and not pane then
				text = text .. (", %d entered by hand"):format(byHand)
			end
			put(parts, text)
		end

		return parts, 0
	end
	for _, key in ipairs(SIDES) do
		local bucket = entry[key]
		local text = sideText(key, bucket, pane)
		if text ~= nil then
			put(parts, text)
			counted = counted + ((type(bucket) == "table" and bucket.count) or 0)
		end
	end
	local undetermined = entry.undetermined or 0
	if undetermined > 0 then
		put(parts, ("%d undetermined"):format(undetermined))
		counted = counted + undetermined
	end
	return parts, counted
end


local function formatText(entry)
	local formats = entry.formats
	if type(formats) ~= "table" then
		return nil
	end

	local counted = {}
	for name, count in pairs(formats) do
		counted[#counted + 1] = { label = A.formatLabel(name), count = count }
	end
	if #counted == 0 then
		return nil
	end

	table.sort(counted, function(a, b) return a.label < b.label end)


	if #counted == 1 then
		return counted[1].label
	end

	local parts = {}
	for i = 1, #counted do
		parts[i] = ("%s %s"):format(counted[i].label, tostring(counted[i].count))
	end
	return table.concat(parts, ", ")
end


local function botText(guid)
	if A.isBotGuid(guid) then
		return "practice bot"
	end
	return nil
end

local function summaryCells(guid, entry)
	local names = entry.names or {}

	local parts = { tostring(names[1] or guid) }

	put(parts, A.matchCountText(entry))
	put(parts, botText(guid))
	for _, text in ipairs(splitParts(entry, guid)) do
		put(parts, text)
	end
	clause(parts, entry.lastSeen, "last %s")

	return parts
end


function A.playerSummaryLine(guid, entry)
	return table.concat(summaryCells(guid, entry), "  ")
end



function A.playerDetailLines(guid, entry, withKey, dossier)
	local lines = {}
	local names = entry.names or {}



	local provenance = withKey == true
		or (type(A.debugTextEnabled) == "function" and A.debugTextEnabled() == true)

	local named = names[1]
	local first = tostring(named or guid)
	lines[#lines + 1] = (provenance and named ~= nil)
		and ("%s  %s"):format(first, tostring(guid)) or first


	if #names > 1 then
		local older = {}
		for i = 2, #names do
			older[#older + 1] = tostring(names[i])
		end
		lines[#lines + 1] = "  also known as " .. table.concat(older, ", ")
	end

	if type(dossier) == "table" then
		for _, line in ipairs(A.playerDossierLines(dossier)) do
			lines[#lines + 1] = line
		end
		local heldFormats = formatText(entry)
		if heldFormats then
			lines[#lines + 1] = "  formats: " .. heldFormats
		end
		for _, line in ipairs(A.noteLines(guid)) do
			lines[#lines + 1] = line
		end
		return lines
	end



	local split, counted = splitParts(entry, guid)

	local when = {}
	put(when, countClause(entry, guid, counted))
	put(when, botText(guid))
	if entry.firstSeen ~= nil and entry.firstSeen == entry.lastSeen then
		clause(when, entry.lastSeen, "seen %s")
	else
		clause(when, entry.firstSeen, "first %s")
		clause(when, entry.lastSeen, "last %s")
	end

	if #when > 0 then
		lines[#lines + 1] = "  " .. table.concat(when, "  ")
	end

	if #split > 0 then
		lines[#lines + 1] = "  " .. table.concat(split, "  ")
	end

	local formats = formatText(entry)
	if formats then
		lines[#lines + 1] = "  formats: " .. formats
	end



	for _, line in ipairs(A.noteLines(guid)) do
		lines[#lines + 1] = line
	end

	return lines
end



function A.playerDossierLines(dossier)
	local lines = {}
	if type(dossier) ~= "table" or (dossier.met or 0) == 0 then
		lines[1] = "  never met in a match"
		return lines
	end

	local when = { ("met %d %s"):format(dossier.met, dossier.met == 1 and "match" or "matches") }
	if dossier.first ~= nil and dossier.first == dossier.last then
		clause(when, dossier.last, "seen %s")
	else
		clause(when, dossier.first, "first %s")
		clause(when, dossier.last, "last %s")
	end
	lines[#lines + 1] = "  " .. table.concat(when, "  ")

	local sides = {}
	local with, against = A.sideLine(dossier.with), A.sideLine(dossier.against)
	put(sides, with and ("with you " .. with) or nil)
	put(sides, against and ("against you " .. against) or nil)


	local undetermined, byHand = 0, 0
	for _, encounter in ipairs(dossier.encounters or {}) do
		if type(encounter.rounds) ~= "table" and encounter.side ~= "with" and encounter.side ~= "against" then
			undetermined = undetermined + 1
		end
		local record = encounter.record
		if type(record) == "table" and record.result == nil and type(record.manual) == "table"
			and record.manual.result ~= nil and (encounter.side == "with" or encounter.side == "against") then
			byHand = byHand + 1
		end
	end
	if undetermined > 0 then
		put(sides, ("%d undetermined"):format(undetermined))
	end
	if byHand > 0 then
		put(sides, ("%d entered by hand"):format(byHand))
	end
	if #sides > 0 then
		lines[#lines + 1] = "  " .. table.concat(sides, "  ")
	end
	return lines
end







local RATING_TEXT = {
	[2] = "strong", [1] = "positive", [0] = "neutral", [-1] = "negative", [-2] = "bad",
}




local RATING_MARK = {
	[2] = "ok", [1] = "regard", [0] = "dim", [-1] = "caution", [-2] = "loss",
}
local UNRATED_MARK = "faint"


function A.ratingText(value)
	return RATING_TEXT[value]
end




function A.ratingMark(value)
	if value == nil then
		return UNRATED_MARK
	end
	return RATING_MARK[value]
end



function A.ratingChoices()
	return {
		{ rating = -2, label = RATING_TEXT[-2], mark = RATING_MARK[-2] },
		{ rating = -1, label = RATING_TEXT[-1], mark = RATING_MARK[-1] },
		{ rating = 0, label = RATING_TEXT[0], mark = RATING_MARK[0] },
		{ rating = 1, label = RATING_TEXT[1], mark = RATING_MARK[1] },
		{ rating = 2, label = RATING_TEXT[2], mark = RATING_MARK[2] },
		{ label = "not rated", mark = UNRATED_MARK },
	}
end


function A.ratingRamp()
	local out = {}
	for _, choice in ipairs(A.ratingChoices()) do
		if choice.rating ~= nil then
			out[#out + 1] = choice
		end
	end
	return out
end


function A.ratingRampLabel(rating)
	for _, choice in ipairs(A.ratingChoices()) do
		if choice.rating == rating then
			return choice.label, choice.mark
		end
	end
	local last = A.ratingChoices()
	last = last[#last]
	return last.label, last.mark
end


function A.noteLines(guid)
	local entry = A.noteFor(guid)
	if not entry then
		return {}
	end

	local lines = {}

	local head = {}
	clause(head, A.ratingText(entry.rating), "rated %s")
	if type(entry.tags) == "table" and #entry.tags > 0 then
		put(head, "tags: " .. table.concat(entry.tags, ", "))
	end
	if #head > 0 then
		lines[#lines + 1] = "  " .. table.concat(head, "  ")
	end

	if entry.text ~= nil then
		local note = "  note: " .. tostring(entry.text)
		if entry.updatedAt ~= nil then
			note = note .. ("  (%s)"):format(tostring(entry.updatedAt))
		end
		lines[#lines + 1] = note
	end


	for _, held in ipairs(type(entry.merged) == "table" and entry.merged or {}) do
		local older = {}
		clause(older, A.ratingText(held.rating), "rated %s")
		if held.text ~= nil then
			put(older, "note: " .. tostring(held.text))
		end
		if type(held.tags) == "table" and #held.tags > 0 then
			put(older, "tags: " .. table.concat(held.tags, ", "))
		end
		if #older > 0 then
			lines[#lines + 1] = "  also written under a name:  " .. table.concat(older, "  ")
		end
	end

	return lines
end


function A.authoredDigest(guid)
	local entry = A.noteFor(guid)
	if not (entry and A.writtenAbout(entry)) then
		return nil
	end

	local parts = {}
	put(parts, A.ratingText(entry.rating))
	if type(entry.tags) == "table" and #entry.tags > 0 then
		put(parts, ("%d %s"):format(#entry.tags, #entry.tags == 1 and "tag" or "tags"))
	end
	if entry.text ~= nil then
		put(parts, "note")
	end
	put(parts, commentCount(entry))

	if #parts == 0 then
		return nil
	end
	return table.concat(parts, ", ")
end


A.UNKNOWN_PLAYER = "Unknown player"




function A.nameParts(name, fallback)
	if type(name) ~= "string" or name == "" then
		return tostring(fallback or ""), nil
	end
	local at = name:find("-", 1, true)
	if not at or at <= 1 then
		return name, nil
	end
	local realm = name:sub(at + 1)
	return name:sub(1, at - 1), (realm ~= "" and realm or nil)
end





function A.playerIdentity(guid, entry)
	local names = (type(entry) == "table" and entry.names) or {}
	local full = tostring(names[1] or A.UNKNOWN_PLAYER)
	local bare, realm = A.nameParts(names[1], A.UNKNOWN_PLAYER)

	local classToken, specLabel
	local db = A.db()
	if db and type(db.matches) == "table" and type(guid) == "string" then
		for i = #db.matches, 1, -1 do
			local record = db.matches[i]
			local p = (type(record) == "table" and type(record.participants) == "table")
				and record.participants[guid] or nil
			if type(p) == "table" then
				if type(p.classToken) == "string" and p.classToken ~= "" then
					classToken = p.classToken
				end
				if type(p.spec) == "string" and p.spec ~= "" then
					specLabel = A.chipText({ spec = p.spec, class = p.class })
				end
				if classToken ~= nil or specLabel ~= nil then
					break
				end
			end
		end
	end

	return {
		guid = guid,
		name = full,
		bare = bare,
		realm = realm,
		unnamed = names[1] == nil or nil,
		classToken = classToken,
		specLabel = specLabel,
	}
end




function A.noteCountText(text, bound)
	if type(text) ~= "string" or text == "" then
		return nil
	end
	if type(bound) ~= "number" or bound <= 0 then
		return nil
	end
	local left = bound - #text
	if left < 0 then
		left = 0
	end
	return ("%d left"):format(left)
end



local MURLOK_REGIONS = { "us", "kr", "eu", "tw" }




function A.murlokRealm(realm)
	if type(realm) ~= "string" or realm == "" then
		return nil
	end
	local slug = realm:gsub("(%l)(%u)", "%1-%2"):gsub("(%a)(%d)", "%1-%2")
	slug = slug:gsub("'", ""):gsub("%s+", "-"):lower()
	if slug == "" then
		return nil
	end
	return slug
end


function A.murlokAddress(name, realm, region)
	local code = type(region) == "number" and MURLOK_REGIONS[region] or nil
	local slug = A.murlokRealm(realm)
	if not (code and slug and type(name) == "string" and name ~= "") then
		return nil
	end
	return ("https://murlok.io/character/%s/%s/%s/pvp"):format(code, slug, name:lower())
end







function A.repLabel(rating)
	local label, mark = A.ratingRampLabel(rating)
	return (tostring(label):gsub("^%l", string.upper)), mark
end



local function shuffleSeats(record)
	local seats, results = {}, {}
	local count = type(record.rounds) == "table" and #record.rounds or 0
	if type(A.lobbyTally) ~= "function" then
		return seats, results, count
	end
	local ok, rows = pcall(A.lobbyTally, record)
	if not ok or type(rows) ~= "table" then
		return seats, results, count
	end
	for i = 1, #rows do
		local row = rows[i]
		if type(row) == "table" and type(row.guid) == "string" and type(row.seats) == "table" then
			seats[row.guid] = row.seats
		end
	end
	if type(A.roundResult) == "function" then
		for r = 1, count do
			local answered, won = pcall(A.roundResult, record, r)
			if answered and type(won) == "boolean" then
				results[r] = won
			end
		end
	end
	return seats, results, count
end




function A.encounterIndex()
	local out = {}
	local db = A.db()
	local matches = (db and type(db.matches) == "table") and db.matches or {}
	for i = #matches, 1, -1 do
		local record = matches[i]
		if type(record) == "table" and type(record.participants) == "table" then
			local shuffle = record.format == "shuffle"
			local seats, results, count
			if shuffle then
				seats, results, count = shuffleSeats(record)
			end

			local verdict = nil
			if not shuffle and type(A.recordVerdict) == "function" then
				verdict = A.recordVerdict(record)
			end
			local at = record.openedAt or record.completedAt



			for guid, participant in pairs(record.participants) do
				if type(guid) == "string" and guid ~= record.character and type(participant) == "table"
					and not A.isBotGuid(guid) then
					local encounter = {
						id = record.id,
						record = record,
						format = record.format,
						at = at,
						epoch = A.stampEpoch(at),
						p = participant,
					}
					if shuffle then
						local held = seats[guid] or {}
						local rounds = {}
						for r = 1, count do
							rounds[r] = { side = held[r], won = results[r] }
						end
						encounter.rounds = rounds
					else
						encounter.side = A.matchSide(record, guid)
						encounter.verdict = verdict
					end
					local list = out[guid]
					if not list then
						list = {}
						out[guid] = list
					end
					list[#list + 1] = encounter
				end
			end
		end
	end
	return out
end



local HOVER_INDEX_AGE = 60

local hoverIndex = nil




function A.hoverEncounterIndex(now)
	local db = A.db()
	local matches = (db and type(db.matches) == "table") and db.matches or nil
	local count = matches and #matches or 0
	local newest = matches and matches[count] or nil
	local held = hoverIndex
	local clock = type(now) == "number" and now or time()
	if held and held.db == db and held.matches == matches and held.count == count
		and held.newest == newest and clock >= held.at and clock - held.at < HOVER_INDEX_AGE then
		return held.index, "kept"
	end
	local index = A.encounterIndex()
	hoverIndex = { db = db, matches = matches, count = count, newest = newest, at = clock, index = index }
	return index, "walked"
end


local function emptySide()
	return {
		rounds = { won = 0, lost = 0 },
		matches = { won = 0, lost = 0, drawn = 0, open = 0 },
	}
end



function A.sideRecord(encounters)
	local out = { with = emptySide(), against = emptySide(), met = 0, ids = {} }
	if type(encounters) ~= "table" then
		return out
	end
	for i = 1, #encounters do
		local encounter = encounters[i]
		out.met = out.met + 1
		out.ids[#out.ids + 1] = encounter.id
		if encounter.at ~= nil then
			if out.first == nil or encounter.at < out.first then
				out.first = encounter.at
			end
			if out.last == nil or encounter.at > out.last then
				out.last = encounter.at
				out.lastEpoch = encounter.epoch
			end
		end
		if type(encounter.rounds) == "table" then
			for r = 1, #encounter.rounds do
				local seat = encounter.rounds[r]
				local side = seat and out[seat.side or ""] or nil
				if side and type(seat.won) == "boolean" then
					if seat.won then
						side.rounds.won = side.rounds.won + 1
					else
						side.rounds.lost = side.rounds.lost + 1
					end
				end
			end
		elseif encounter.side == "with" or encounter.side == "against" then
			local held = out[encounter.side].matches
			if encounter.verdict == "win" then
				held.won = held.won + 1
			elseif encounter.verdict == "loss" then
				held.lost = held.lost + 1
			elseif encounter.verdict == "draw" then
				held.drawn = held.drawn + 1
			else
				held.open = held.open + 1
			end
		end
	end
	return out
end


local function recordTone(won, lost)
	if won > lost then
		return "win"
	end
	if lost > won then
		return "loss"
	end
	return "dim"
end



function A.sideParts(side)
	if type(side) ~= "table" then
		return nil
	end
	local parts = {}
	local rounds = side.rounds
	if type(rounds) == "table" and rounds.won + rounds.lost > 0 then
		parts[#parts + 1] = {
			unit = "rounds",
			figure = ("%d-%d"):format(rounds.won, rounds.lost),
			tone = recordTone(rounds.won, rounds.lost),
			count = rounds.won + rounds.lost,
		}
	end
	local matches = side.matches
	if type(matches) == "table" then
		local decided = matches.won + matches.lost + matches.drawn
		if decided + matches.open > 0 then
			parts[#parts + 1] = {
				unit = "matches",
				figure = decided > 0 and ("%d-%d"):format(matches.won, matches.lost) or nil,
				tone = decided > 0 and recordTone(matches.won, matches.lost) or "dim",
				count = decided + matches.open,
				drawn = matches.drawn,
				open = matches.open,
			}
		end
	end
	if #parts == 0 then
		return nil
	end
	return parts
end


local function matchExtras(part)
	local out = ""
	if (part.drawn or 0) > 0 then
		out = out .. (", %d drawn"):format(part.drawn)
	end
	if (part.open or 0) > 0 then
		out = out .. (", %d with no result"):format(part.open)
	end
	return out
end


function A.sideWords(parts)
	if type(parts) ~= "table" or #parts == 0 then
		return nil
	end
	local first = parts[1]
	local bits = {}
	if first.unit == "rounds" then
		bits[1] = ("over %d %s"):format(first.count, first.count == 1 and "round" or "rounds")
	elseif first.figure then
		bits[1] = ("over %d %s"):format(first.count, first.count == 1 and "match" or "matches")
			.. matchExtras(first)
	else
		bits[1] = ("%d %s, none with a result"):format(first.count,
			first.count == 1 and "match" or "matches")
	end
	local second = parts[2]
	if second then
		if second.figure then
			bits[#bits + 1] = ("and %s in matches"):format(second.figure) .. matchExtras(second)
		else
			bits[#bits + 1] = ("and %d %s with no result"):format(second.count,
				second.count == 1 and "match" or "matches")
		end
	end
	return first.figure, first.tone, table.concat(bits, ", ")
end


function A.sideLine(parts)
	local lead, _, rest = A.sideWords(parts)
	if rest == nil then
		return nil
	end
	if lead == nil then
		return rest
	end
	return lead .. " " .. rest
end


function A.sideShort(parts)
	if type(parts) ~= "table" or #parts == 0 then
		return nil
	end
	local out = {}
	for i = 1, #parts do
		local part = parts[i]
		if part.unit == "rounds" then
			out[#out + 1] = { text = part.figure .. " rds", tone = part.tone }
		elseif part.figure then
			out[#out + 1] = { text = part.figure, tone = part.tone }
		elseif #parts == 1 then
			out[#out + 1] = { text = "no result", tone = "dim" }
		end
	end
	if #out == 0 then
		return nil
	end
	return out
end


function A.sideShortMarkup(pieces)
	if type(pieces) ~= "table" or #pieces == 0 then
		return A.colorEscape("dimmer") .. "-|r"
	end
	local out = {}
	for i = 1, #pieces do
		out[i] = A.colorEscape(pieces[i].tone or "dim") .. pieces[i].text .. "|r"
	end
	return table.concat(out, ", ")
end


function A.sideShortText(pieces)
	if type(pieces) ~= "table" or #pieces == 0 then
		return nil
	end
	local texts = {}
	for i = 1, #pieces do
		texts[i] = pieces[i].text
	end
	return table.concat(texts, ", ")
end


function A.groupedCount(count)
	if type(count) ~= "number" then
		return tostring(count)
	end
	local text = tostring(math.floor(count))
	local sign, digits = text:match("^(%-?)(%d+)$")
	if not digits then
		return text
	end
	local grouped = digits:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
	return sign .. grouped
end



function A.agoText(epoch, now)
	if type(epoch) ~= "number" or type(now) ~= "number" or epoch > now then
		return nil
	end
	local seconds = now - epoch
	if seconds < 60 then
		return "now"
	end
	if seconds < 3600 then
		return ("%dm"):format(math.floor(seconds / 60))
	end
	if seconds < 86400 then
		return ("%dh"):format(math.floor(seconds / 3600))
	end
	if seconds < 86400 * 14 then
		return ("%dd"):format(math.floor(seconds / 86400))
	end
	if seconds < 86400 * 60 then
		return ("%dw"):format(math.floor(seconds / (86400 * 7)))
	end
	return ("%dmo"):format(math.floor(seconds / (86400 * 30)))
end


function A.shortDay(stamp)
	local y, m, d = tostring(A.dayKey(stamp)):match("^(%d+)%-(%d+)%-(%d+)$")
	if not y then
		return nil
	end
	local okAt, noon = pcall(time, { year = tonumber(y), month = tonumber(m), day = tonumber(d), hour = 12 })
	if not okAt or type(noon) ~= "number" then
		return A.dayKey(stamp)
	end
	local ok, text = pcall(date, "%a %d %b", noon)
	if not ok or type(text) ~= "string" then
		return A.dayKey(stamp)
	end
	return (text:gsub(" 0(%d)", " %1"))
end



local function rowIdentity(_, entry, encounters)
	local names = (type(entry) == "table" and entry.names) or {}
	local bare, realm = A.nameParts(names[1], A.UNKNOWN_PLAYER)
	local out = { bare = bare, realm = realm, full = tostring(names[1] or A.UNKNOWN_PLAYER), also = {},
		unnamed = names[1] == nil or nil }
	local seen = {}
	for i = 1, #(encounters or {}) do
		local p = encounters[i].p
		if type(p) == "table" then
			if out.classToken == nil and type(p.classToken) == "string" and p.classToken ~= "" then
				out.classToken = p.classToken
			end
			if type(p.spec) == "string" and p.spec ~= "" then
				if out.spec == nil then
					out.spec = p.spec
					out.specLabel = A.chipText({ spec = p.spec, class = p.class })
					out.mark = p.spec:sub(1, 3)
				elseif p.spec ~= out.spec and not seen[p.spec] then
					out.also[#out.also + 1] = p.spec
				end
				seen[p.spec] = true
			end
		end
	end
	return out
end


function A.specLine(identity)
	if type(identity) ~= "table" or identity.specLabel == nil then
		return nil
	end
	if #identity.also == 0 then
		return identity.specLabel
	end
	return ("%s, also seen as %s"):format(identity.specLabel, table.concat(identity.also, ", "))
end




local function searchHit(guid, entry, encounters, note, needle)
	local function has(text)
		return type(text) == "string" and A.foldText(text):find(needle, 1, true) ~= nil
	end
	local names = (type(entry) == "table" and entry.names) or {}
	for _, name in ipairs(names) do
		if has(name) then
			return true
		end
	end

	if names[1] == nil and (has(guid) or has(A.UNKNOWN_PLAYER)) then
		return true
	end
	for i = 1, #(encounters or {}) do
		local p = encounters[i].p
		if type(p) == "table" and (has(p.spec) or has(p.class)) then
			return true
		end
	end
	if type(note) == "table" then
		if has(note.text) then
			return true
		end
		for _, tag in ipairs(type(note.tags) == "table" and note.tags or {}) do
			if has(tag) then
				return true
			end
		end
	end
	return false
end



function A.newestSession()
	local db = A.db()
	local matches = (db and type(db.matches) == "table") and db.matches or {}
	local entries = {}
	for i = #matches, 1, -1 do
		if type(matches[i]) == "table" then
			entries[#entries + 1] = { kind = "match", subject = matches[i] }
		end
	end
	table.sort(entries, function(a, b)
		local as = tostring(a.subject.openedAt or a.subject.completedAt or "")
		local bs = tostring(b.subject.openedAt or b.subject.completedAt or "")
		if as ~= bs then
			return as > bs
		end
		return tostring(a.subject.id) > tostring(b.subject.id)
	end)
	local ids = {}
	if type(A.buildSessions) ~= "function" then
		return ids, nil
	end
	local sessions = A.buildSessions(entries)
	local newest = sessions[1]
	if newest then
		for _, entry in ipairs(newest.entries) do
			ids[entry.subject.id] = true
		end
	end
	return ids, newest
end


local SORTS = { recent = true, met = true, rep = true }


function A.playerSorts()
	return {
		{ value = "recent", label = "Recent" },
		{ value = "met", label = "Most met" },
		{ value = "rep", label = "Rep" },
	}
end


function A.playerSideChoices()
	return {
		{ value = nil, label = "With or against" },
		{ value = "with", label = "With you" },
		{ value = "against", label = "Against you" },
	}
end


function A.playerFormatChoices()
	local out = { { value = nil, label = "Every format" } }
	local seen = {}
	local db = A.db()
	local matches = (db and type(db.matches) == "table") and db.matches or {}
	local found = {}
	for i = 1, #matches do
		local format = type(matches[i]) == "table" and matches[i].format or nil
		if type(format) == "string" and not seen[format] then
			seen[format] = true
			found[#found + 1] = { value = format, label = A.formatLabel(format) }
		end
	end
	table.sort(found, function(a, b)
		return a.label < b.label
	end)
	for i = 1, #found do
		out[#out + 1] = found[i]
	end
	return out
end


local function repValue(value)
	if value == "none" then
		return true
	end
	return type(value) == "number" and A.ratingText(value) ~= nil
end


function A.repFromWord(word)
	if type(word) ~= "string" then
		return nil
	end
	local lowered = word:lower()
	if lowered == "none" or lowered == "not rated" or lowered == "unrated" then
		return "none"
	end
	for _, choice in ipairs(A.ratingChoices()) do
		if choice.rating ~= nil and choice.label == lowered then
			return choice.rating
		end
	end
	return nil
end


local function repHit(row, rep)
	if rep == nil then
		return true
	end
	if rep == "none" then
		return row.rating == nil
	end
	return row.rating == rep
end


local function recorderSet()
	local recorders = {}
	local db = A.db()
	for _, record in ipairs((db and type(db.matches) == "table") and db.matches or {}) do
		if type(record) == "table" and type(record.character) == "string" then
			recorders[record.character] = true
		end
	end
	return recorders
end



local function listedPlayer(guid, recorders, unscoped)
	if type(guid) ~= "string" or A.isBotGuid(guid) then
		return false
	end
	if unscoped and (recorders[guid] or A.isSelfPlayer(guid)) then
		return false
	end
	return true
end



function A.playersMet(index)
	index = type(index) == "table" and index or A.encounterIndex()
	local recorders = recorderSet()
	local met, noted = {}, {}
	for _, item in ipairs(A.players()) do
		if listedPlayer(item.guid, recorders, true) then
			if #(index[item.guid] or {}) > 0 then
				met[#met + 1] = item
			elseif item.indexed == false then
				noted[#noted + 1] = item
			end
		end
	end
	return met, noted
end




function A.playersView(state)
	state = type(state) == "table" and state or {}
	local now = type(state.now) == "number" and state.now or time()
	local sort = SORTS[state.sort] and state.sort or "recent"
	local needle = (type(state.text) == "string" and state.text ~= "") and A.foldText(state.text) or nil
	local rep = repValue(state.rep) and state.rep or nil
	local index = type(state.index) == "table" and state.index or A.encounterIndex()
	local sessionIds, session = A.newestSession()

	local base, scoped
	if state.scope ~= nil then
		scoped = A.match(state.scope)
		base = scoped and A.rosterPlayers(scoped) or {}
	else
		base = A.players()
	end

	local recorders = recorderSet()


	local function consider(item)
		local guid = item.guid
		if not listedPlayer(guid, recorders, scoped == nil) then
			return nil
		end
		local encounters = {}
		for _, encounter in ipairs(index[guid] or {}) do
			if state.format == nil or encounter.format == state.format then
				encounters[#encounters + 1] = encounter
			end
		end
		if state.format ~= nil and #encounters == 0 then
			return nil
		end
		local note = A.noteFor(guid)

		local searched = needle == nil or searchHit(guid, item.entry, index[guid], note, needle)
		local record = A.sideRecord(encounters)
		local with = A.sideParts(record.with)
		local against = A.sideParts(record.against)
		if (state.side == "with" and with == nil) or (state.side == "against" and against == nil) then
			return nil
		end
		local tonight, before = false, false
		for i = 1, #encounters do
			if sessionIds[encounters[i].id] then
				tonight = true
			else
				before = true
			end
		end
		local entry = item.entry
		local last = record.last or (type(entry) == "table" and entry.lastSeen) or nil
		return {
			guid = guid,
			entry = entry,
			identity = rowIdentity(guid, entry, encounters),
			rating = note and A.ratingText(note.rating) ~= nil and note.rating or nil,
			noted = note ~= nil and type(note.text) == "string" and note.text ~= "",
			comments = type(A.playerComments) == "function" and #A.playerComments(guid) or 0,
			tag = note and type(note.tags) == "table" and note.tags[1] or nil,
			met = record.met,
			with = with,
			against = against,
			last = last,
			lastEpoch = record.lastEpoch or A.stampEpoch(last),
			tonight = tonight,
			before = before,
			ids = record.ids,
			searched = searched,
		}
	end

	local rows = {}
	for _, item in ipairs(base) do
		local row = consider(item)
		if row then
			rows[#rows + 1] = row
		end
	end



	local strip = { players = 0, unmet = 0, encounters = 0, matches = 0, metAgain = 0, notes = 0,
		noted = 0, tonight = 0, tonightBefore = 0, rated = 0, steps = {}, notRated = 0 }
	local matchSeen = {}
	local stepCounts = {}
	for i = 1, #rows do
		local row = rows[i]
		if row.met > 0 then
			strip.players = strip.players + 1
		else
			strip.unmet = strip.unmet + 1
		end
		strip.encounters = strip.encounters + row.met
		for _, id in ipairs(row.ids) do
			if not matchSeen[id] then
				matchSeen[id] = true
				strip.matches = strip.matches + 1
			end
		end
		if row.met > 1 then
			strip.metAgain = strip.metAgain + 1
		end
		local written = (row.noted and 1 or 0) + row.comments
		if written > 0 then
			strip.notes = strip.notes + written
			strip.noted = strip.noted + 1
		end
		if row.tonight then
			strip.tonight = strip.tonight + 1
			if row.before then
				strip.tonightBefore = strip.tonightBefore + 1
			end
		end
		if row.rating ~= nil then
			strip.rated = strip.rated + 1
			stepCounts[row.rating] = (stepCounts[row.rating] or 0) + 1
		else
			strip.notRated = strip.notRated + 1
		end
	end
	for _, step in ipairs(A.ratingRamp()) do
		local label = A.repLabel(step.rating)
		strip.steps[#strip.steps + 1] = { rating = step.rating, label = label, mark = step.mark,
			count = stepCounts[step.rating] or 0 }
	end
	strip.metAgainShare = strip.players > 0 and math.floor(strip.metAgain * 100 / strip.players + 0.5) or nil
	strip.session = session

	if session and type(A.sessionDayForms) == "function" then
		local okForms, forms = pcall(A.sessionDayForms, session.startStamp or session.endStamp, now)
		strip.sessionDay = okForms and type(forms) == "table" and forms[math.min(2, #forms)] or nil
	end


	local shown = {}
	for i = 1, #rows do
		if rows[i].searched and repHit(rows[i], rep) then
			shown[#shown + 1] = rows[i]
		end
	end

	local function byLast(a, b)
		local ae, be = a.lastEpoch or 0, b.lastEpoch or 0
		if ae ~= be then
			return ae > be
		end
		return tostring(a.identity.bare) < tostring(b.identity.bare)
	end

	local sections = {}
	if sort == "met" then
		table.sort(shown, function(a, b)
			if a.met ~= b.met then
				return a.met > b.met
			end
			return byLast(a, b)
		end)
		sections[1] = { key = "met", label = "Met most often", rows = shown }
	elseif sort == "rep" then
		local buckets = {}
		for _, choice in ipairs(A.ratingChoices()) do
			local key = choice.rating ~= nil and choice.rating or "none"
			buckets[#buckets + 1] = { key = key, label = (A.repLabel(choice.rating)), rows = {} }
		end
		for i = 1, #shown do
			local key = shown[i].rating ~= nil and shown[i].rating or "none"
			for b = 1, #buckets do
				if buckets[b].key == key then
					local held = buckets[b].rows
					held[#held + 1] = shown[i]
					break
				end
			end
		end
		for b = 1, #buckets do
			table.sort(buckets[b].rows, byLast)
			if #buckets[b].rows > 0 then
				sections[#sections + 1] = buckets[b]
			end
		end
	else
		local week = now - 7 * 86400
		local buckets = {
			{ key = "tonight", label = strip.sessionDay or "Tonight", rows = {} },
			{ key = "week", label = "This week", rows = {} },
			{ key = "earlier", label = "Earlier", rows = {} },
		}
		for i = 1, #shown do
			local row = shown[i]
			local at
			if row.tonight then
				at = buckets[1]
			elseif type(row.lastEpoch) == "number" and row.lastEpoch >= week then
				at = buckets[2]
			else
				at = buckets[3]
			end
			at.rows[#at.rows + 1] = row
		end
		for b = 1, #buckets do
			table.sort(buckets[b].rows, byLast)
			if #buckets[b].rows > 0 then
				sections[#sections + 1] = buckets[b]
			end
		end
	end

	local ordered = {}
	for s = 1, #sections do
		sections[s].count = #sections[s].rows
		for i = 1, #sections[s].rows do
			ordered[#ordered + 1] = sections[s].rows[i]
		end
	end

	return {
		rows = ordered,
		sections = sections,
		strip = strip,
		shown = #ordered,
		sort = sort,
		rep = rep,
		scope = scoped,
		scopeId = state.scope,
	}
end



function A.encounterLine(encounter)
	if type(encounter) ~= "table" then
		return nil
	end
	local record = encounter.record
	local out = {
		id = encounter.id ~= nil and ("#%s"):format(tostring(encounter.id)) or "-",
		matchId = encounter.id,
		day = A.shortDay(encounter.at) or "-",
		clock = A.clockKey(encounter.at),
		map = type(record) == "table" and type(record.map) == "table" and record.map.name or nil,
		format = encounter.format ~= nil and A.formatLabel(encounter.format) or nil,
	}
	if type(encounter.rounds) == "table" then
		out.pips = {}
		for r = 1, #encounter.rounds do
			local seat = encounter.rounds[r]
			local tone = "dim"
			if seat.won == true then
				tone = "win"
			elseif seat.won == false then
				tone = "loss"
			end
			out.pips[r] = { side = seat.side, tone = tone }
		end
		local verdict, won, played = nil, nil, nil
		if type(A.roundsOutcome) == "function" then
			verdict, won, played = A.roundsOutcome(record)
		end
		if verdict ~= nil and type(won) == "number" and type(played) == "number" then
			out.result = ("%d of %d"):format(won, played)
			if won * 2 > played then
				out.resultTone = "win"
			elseif won * 2 < played then
				out.resultTone = "loss"
			else
				out.resultTone = "dim"
			end
		end
	else
		if encounter.side == "with" then
			out.side, out.sideTone = "with you", "win"
		elseif encounter.side == "against" then
			out.side, out.sideTone = "against you", "loss"
		end
		local words = { win = "won", loss = "lost", draw = "draw" }
		out.result = words[encounter.verdict]
		out.resultTone = (encounter.verdict == "win" and "win") or (encounter.verdict == "loss" and "loss")
			or "dim"
	end
	out.result = out.result or "-"
	out.resultTone = out.resultTone or "dim"
	local change, tone = nil, nil
	if type(record) == "table" and type(A.ratingDelta) == "function" then
		change, tone = A.ratingDelta(record)
	end
	out.change = change or "-"
	out.changeTone = tone or "dim"
	return out
end



function A.playerEncounters(guid, format, index)
	local out = {}
	for _, encounter in ipairs((index or A.encounterIndex())[guid] or {}) do
		if format == nil or encounter.format == format then
			out[#out + 1] = encounter
		end
	end
	return out
end




function A.playerDossier(guid, index)
	if type(guid) ~= "string" or guid == "" then
		return nil
	end
	local listed = A.playerEntry(guid)
	local entry = listed and listed.entry or nil
	local encounters = A.playerEncounters(guid, nil, index)
	local record = A.sideRecord(encounters)
	local note = A.noteFor(guid)
	local rating = note and A.ratingText(note.rating) ~= nil and note.rating or nil
	local identity = rowIdentity(guid, entry, encounters)
	return {
		guid = guid,
		entry = entry,
		identity = identity,
		specLine = A.specLine(identity),
		rating = rating,
		note = note,
		record = record,
		with = A.sideParts(record.with),
		against = A.sideParts(record.against),
		met = record.met,
		first = record.first,
		last = record.last,
		lastEpoch = record.lastEpoch,
		encounters = encounters,
	}
end



function A.metWords(dossier)
	if type(dossier) ~= "table" or (dossier.met or 0) == 0 then
		return nil, "never met in a match"
	end
	local figure = ("%d %s"):format(dossier.met, dossier.met == 1 and "match" or "matches")
	local day = A.shortDay(dossier.first)
	if dossier.met == 1 then
		return figure, day
	end
	return figure, day and ("since %s"):format(day) or nil
end



function A.playerInMatch(guid, record, index)
	if type(record) ~= "table" or type(record.participants) ~= "table"
		or type(record.participants[guid]) ~= "table" then
		return nil
	end
	local encounter = nil
	for _, held in ipairs((index or A.encounterIndex())[guid] or {}) do
		if held.record == record then
			encounter = held
			break
		end
	end
	if not encounter then
		return nil
	end
	local line = A.encounterLine(encounter)
	if not line then
		return nil
	end
	local own = A.sideRecord({ encounter })
	return {
		id = record.id,
		line = line,
		map = line.map,
		format = line.format,
		pips = line.pips,
		side = line.side,
		sideTone = line.sideTone,
		result = line.result,
		resultTone = line.resultTone,
		with = A.sideParts(own.with),
		against = A.sideParts(own.against),
	}
end



local function storedBareNames(players)
	local out = {}
	for guid, entry in pairs(players) do
		local names = type(entry) == "table" and entry.names or nil
		if type(names) == "table" then
			for i = 1, #names do
				local name = names[i]
				if type(name) == "string" and name ~= "" and not name:find("-", 1, true) then
					local held = out[name]
					if held == nil then
						out[name] = guid
					elseif held ~= guid then
						out[name] = false
					end
				end
			end
		end
	end
	return out
end


local cardNames = nil





local function cardNameIndex(now)
	local db = A.db()
	local players = (db and type(db.players) == "table") and db.players or nil
	local matches = (db and type(db.matches) == "table") and db.matches or nil
	local count = matches and #matches or 0
	local newest = matches and matches[count] or nil
	local held = cardNames
	local clock = type(now) == "number" and now or time()
	if held and held.db == db and held.players == players and held.count == count
		and held.newest == newest and clock >= held.at and clock - held.at < HOVER_INDEX_AGE then
		return held.index, held.bare, "kept"
	end
	local index = A.playerNameIndex()
	local bare = storedBareNames(players or {})
	cardNames = { db = db, players = players, count = count, newest = newest, at = clock,
		index = index, bare = bare }
	return index, bare, "walked"
end







function A.nameCard(name, now, homeRealm)
	if type(name) == "nil" then
		return { kind = "unresolved", why = "no name" }
	end
	if not A.canRead(name) then
		return { kind = "unresolved", why = "secret" }
	end
	if type(name) ~= "string" or name == "" then
		return { kind = "unresolved", why = "no name" }
	end


	if type(UnitName) == "function" then
		local ok, own, ownRealm = pcall(UnitName, "player")
		if ok and type(own) == "string" and A.canRead(own) and own ~= "" then
			if not (type(ownRealm) == "string" and A.canRead(ownRealm) and ownRealm ~= "") then
				ownRealm = A.ownRealm()
			end
			if name == own or (ownRealm ~= nil and name == own .. "-" .. ownRealm) then
				return { kind = "self", name = own, via = "own-name" }
			end
		end
	end

	local key, via = name, "full"
	if not name:find("-", 1, true) then
		if type(homeRealm) == "string" and A.canRead(homeRealm) and homeRealm ~= "" then
			key, via = name .. "-" .. homeRealm, "home"
		else
			via = "bare"
		end
	end



	local byName, storedBare, names = cardNameIndex(now)
	local held = byName[key]
	if held == nil and via == "home" then
		local stored = storedBare[name]
		if stored ~= nil then
			held, via = stored, "stored-bare"
		end
	end
	if held == false then
		return { kind = "unresolved", why = "ambiguous", name = name, via = via, nameIndex = names }
	end

	local bare, realm = A.nameParts(name, name)
	if not held then
		return { kind = "stranger", name = bare, realm = realm or homeRealm, via = via, nameIndex = names }
	end
	local guid = held
	if A.isOwnCharacter(guid) then
		return { kind = "self", name = bare, guid = guid, via = via, nameIndex = names }
	end



	local index, indexed = A.hoverEncounterIndex(now)
	local facts = A.playerCardFacts(guid, now, index)
	if not facts then
		return { kind = "stranger", name = bare, realm = realm or homeRealm, via = via, nameIndex = names }
	end
	facts.kind = "met"
	facts.via = via
	facts.indexed = indexed
	facts.nameIndex = names
	return facts
end



function A.playerCardFacts(guid, now, index)
	local dossier = A.playerDossier(guid, index)
	if not dossier then
		return nil
	end
	local label, mark = A.repLabel(dossier.rating)
	local note = dossier.note
	return {
		guid = guid,
		name = dossier.identity.bare,
		realm = dossier.identity.realm,
		classToken = dossier.identity.classToken,
		spec = dossier.identity.spec,
		rep = label,
		repMark = mark,
		rating = dossier.rating,
		rated = dossier.rating ~= nil,
		with = A.sideShort(dossier.with),
		against = A.sideShort(dossier.against),
		met = dossier.met,
		ago = A.agoText(dossier.lastEpoch, now),
		last = dossier.last,
		note = note and type(note.text) == "string" and note.text ~= "" and note.text or nil,
		tags = note and type(note.tags) == "table" and note.tags or {},

		ids = type(dossier.record) == "table" and dossier.record.ids or nil,
	}
end


function A.minuteStamp(value)
	if type(value) ~= "string" then
		return value
	end
	local minute = value:match("^(%d%d%d%d%-%d%d%-%d%d %d%d:%d%d):%d%d$")
	return minute or value
end



function A.playerChoiceLine(index, guid, entry)
	local names = entry.names or {}
	local name = tostring(names[1] or guid)
	local parts = { index ~= nil and ("%d  %s"):format(index, name) or name }
	put(parts, A.matchCountText(entry))
	clause(parts, entry.lastSeen, "last seen %s")
	return table.concat(parts, "  ")
end




function A.rosterWriteLine(summary, adding)
	if type(summary) ~= "table" then
		return nil
	end

	local addressed = summary.addressed or 0
	local moved = (adding and summary.tagged or summary.untagged) or 0
	local parts = {
		("%d of %d %s %s"):format(moved, addressed,
			addressed == 1 and "player" or "players",
			adding and "tagged" or "untagged"),
	}

	if (summary.unchanged or 0) > 0 then
		parts[#parts + 1] = ("%d already %s"):format(summary.unchanged,
			adding and "carried every one" or "carried none of them")
	end
	if (summary.atCap or 0) > 0 then
		parts[#parts + 1] = ("%d at the %d-tag bound"):format(summary.atCap, A.PLAYER_MAX_TAGS)
	end

	if (summary.pruned or 0) > 0 then
		parts[#parts + 1] = ("%d left the listing carrying nothing else"):format(summary.pruned)
	end
	if (summary.bots or 0) > 0 then
		parts[#parts + 1] = ("%d bot %s skipped"):format(summary.bots,
			summary.bots == 1 and "row" or "rows")
	end

	return table.concat(parts, ", ")
end


function A.tagLines()
	local vocabulary = A.tagVocabulary()
	if #vocabulary == 0 then
		return {}
	end

	local lines = {}
	for i = 1, #vocabulary do
		lines[i] = ("  %s  %d"):format(vocabulary[i].tag, vocabulary[i].count)
	end
	return lines
end









function A.resultCaptured(record)
	if type(record) ~= "table" then
		return false
	end
	if record.result ~= nil then
		return true
	end
	if type(record.rounds) ~= "table" or #record.rounds == 0 or type(A.roundsOutcome) ~= "function" then
		return false
	end
	return A.roundsOutcome(record) ~= nil
end




function A.resultOfferable(record)
	if type(record) ~= "table" or not A.carriesResult(record) then
		return false
	end
	return not A.resultCaptured(record)
end


function A.capturedResultText(record)
	if type(record) ~= "table" then
		return nil
	end
	if record.result ~= nil then
		return tostring(record.result)
	end
	if type(A.roundsOutcome) == "function" then
		local outcome, won, played = A.roundsOutcome(record)
		if outcome ~= nil then
			return ("%d of %d rounds"):format(won, played)
		end
	end
	return nil
end


local MENU_RESULTS = { "win", "loss", "draw" }


local function matchWindowOpen(id)
	if type(A.matchWindowsOpen) ~= "function" then
		return false
	end
	local ok, rows = pcall(A.matchWindowsOpen)
	if not ok or type(rows) ~= "table" then
		return false
	end
	for i = 1, #rows do
		if rows[i].kind == "match" and rows[i].id == id then
			return true
		end
	end
	return false
end




function A.matchMenuEntries(record, kind)
	if kind == "incomplete" or type(record) ~= "table" or record.id == nil then
		return {}
	end
	local out = {
		{ key = "open", label = matchWindowOpen(record.id) and "Close" or "Open" },
		{ key = "note", label = "Write a note" },
		{ key = "roster", label = A.recordHasTable(record, "match") and "Note this roster" or "Note this duel" },
		{ key = "print", label = "Print in chat" },
	}
	if A.resultOfferable(record) then
		local choices = {}
		for i = 1, #MENU_RESULTS do
			choices[i] = MENU_RESULTS[i]
		end
		out[#out + 1] = { key = "result", label = "Enter result", choices = choices }
	end
	return out
end



function A.matchMenuOffers(record, key, kind)
	local entries = A.matchMenuEntries(record, kind)
	for i = 1, #entries do
		if entries[i].key == key then
			return true, nil
		end
	end
	if key == "result" and kind ~= "incomplete" and type(record) == "table" and record.id ~= nil then
		if not A.carriesResult(record) then
			return false, "no-result"
		end
		return false, "captured"
	end
	return false, "not-offered"
end


local function classEscape(token)
	if type(A.classColor) ~= "function" then
		return nil
	end
	local ok, r, g, b = pcall(A.classColor, token)
	if not ok or type(r) ~= "number" then
		return nil
	end
	return ("|cff%02x%02x%02x"):format(
		math.floor(r * 255 + 0.5), math.floor((g or 1) * 255 + 0.5), math.floor((b or 1) * 255 + 0.5))
end


local function tooltipRosterLine(record, entry, sides)
	local c = A.participantCells(record, entry, sides, nil)
	local name = tostring(c.name)
	local escape = classEscape(c.classToken)
	if escape then
		name = escape .. name .. "|r"
	end
	local parts = { name, c.specLabel or "-", A.figureText(c.damage) or "-",
		A.figureText(c.healing) or "-", c.dispels ~= nil and tostring(c.dispels) or "-" }
	return { kind = "roster", text = table.concat(parts, "  "), self = c.self == true, side = c.side }
end




function A.matchTooltipLines(record)
	if type(record) ~= "table" or record.format == "duel" or record.format == "world" then
		return nil
	end

	local lines = {}
	local kinds = { roster = 0, rounds = 0, objectives = 0 }


	local head = {}
	local decided = effectiveResult(record)
	if decided ~= nil then
		put(head, RESULT_WORD.match[decided] or tostring(decided):upper())
	else
		local verdict, won, played = A.roundsVerdict(record)
		if verdict == "draw" then
			put(head, RESULT_WORD.match.draw)
		elseif verdict == "unsummed" then
			put(head, "RESULT NOT KNOWN")
		elseif verdict == "count" then
			put(head, ("WON %d OF %d"):format(won, played))
		end
	end
	put(head, record.format ~= nil and A.formatLabel(record.format) or nil)
	put(head, record.map and record.map.name or nil)
	put(head, (A.ratingDelta(record)))
	lines[1] = {
		kind = "head",
		text = #head > 0 and table.concat(head, "  ") or ("Match #%s"):format(A.matchIdText(record.id)),
		tone = A.resultTone(record),
	}

	local roster = rosterEntries(record)
	local sides = rosterSides(record, roster)
	roster = ownSideFirst(roster, sides)


	local totals = A.objectiveTotals(record)
	if totals then
		for _, side in ipairs({ { "yours", totals.yours, "win" }, { "theirs", totals.theirs, "loss" } }) do
			local cells = { A.sideWord(side[1]):upper() }
			for c = 1, #totals.columns do
				local value = side[2][c]
				cells[#cells + 1] = ("%s %s"):format(value ~= nil and tostring(value) or "-",
					totals.columns[c].short)
			end
			lines[#lines + 1] = { kind = "objectives", text = table.concat(cells, "  "), tone = side[3] }
			kinds.objectives = kinds.objectives + 1
		end
		for i = 1, #roster do
			if roster[i].guid == record.character then
				lines[#lines + 1] = tooltipRosterLine(record, roster[i], sides)
				kinds.roster = kinds.roster + 1
			end
		end
		return lines, kinds
	end

	for i = 1, #roster do
		lines[#lines + 1] = tooltipRosterLine(record, roster[i], sides)
		kinds.roster = kinds.roster + 1
	end


	local rounds = type(record.rounds) == "table" and record.rounds or nil
	for i = 1, rounds and #rounds or 0 do
		local won, _, byHand = A.roundResult(record, i)
		local word, tone = "-", nil
		if won == true then
			word, tone = "WON", "win"
		elseif won == false then
			word, tone = "LOST", "loss"
		end
		if byHand then
			word = word .. "*"
		end
		lines[#lines + 1] = { kind = "round", text = ("Round %d  %s"):format(i, word), tone = tone }
		kinds.rounds = kinds.rounds + 1
	end

	return lines, kinds
end
