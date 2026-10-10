










































local _, A = ...


local ATTACH_TIMEOUT = 60




local TYPES = {
	{ key = "seen", name = "DamageDone" },
	{ key = "dispels", name = "Dispels" },
}



local waiters = {}






local watches = setmetatable({}, { __mode = "k" })


local function lockdown()
	if type(InCombatLockdown) ~= "function" then
		return false
	end
	local ok, value = pcall(InCombatLockdown)
	return ok and value == true
end


local function enumValue(enumName, key)
	local enum = type(Enum) == "table" and Enum[enumName] or nil
	local value = type(enum) == "table" and enum[key] or nil
	if type(value) == "number" then
		return value
	end
	return nil
end


function A.meterAvailable()
	if type(C_DamageMeter) ~= "table" or type(C_DamageMeter.GetCombatSessionFromType) ~= "function" then
		return false
	end
	if enumValue("DamageMeterSessionType", "Overall") == nil
		or enumValue("DamageMeterSessionType", "Current") == nil then
		return false
	end
	for i = 1, #TYPES do
		if enumValue("DamageMeterType", TYPES[i].name) == nil then
			return false
		end
	end
	return true
end









local function readSession(sessionName)
	local out = { byGuid = {}, sources = 0, unread = 0 }
	local sessionType = enumValue("DamageMeterSessionType", sessionName)
	if sessionType == nil then
		return out
	end
	for i = 1, #TYPES do
		local kind = TYPES[i]
		local meterType = enumValue("DamageMeterType", kind.name)
		local list = nil
		if meterType ~= nil then
			local ok, session = pcall(C_DamageMeter.GetCombatSessionFromType, sessionType, meterType)
			if ok and type(session) == "table" then
				local got, sources = pcall(A.index, session, "combatSources")
				if got and type(sources) == "table" then
					list = sources
				end
			end
		end
		local n = 0
		if list then
			local counted, length = pcall(function() return #list end)
			if counted and type(length) == "number" then
				n = length
			end
		end
		for s = 1, n do
			local got, source = pcall(A.index, list, s)
			if got and type(source) == "table" then
				out.sources = out.sources + 1


				local gotGuid, guid = pcall(A.index, source, "sourceGUID")
				if gotGuid and A.canRead(guid) and type(guid) == "string" then
					local entry = out.byGuid[guid]
					if entry == nil then
						entry = {}
						out.byGuid[guid] = entry
					end
					if kind.key == "seen" then
						entry.seen = true
					else
						local gotAmount, amount = pcall(A.index, source, "totalAmount")
						if gotAmount and A.canRead(amount) and type(amount) == "number" then
							entry[kind.key] = amount
						else
							entry[kind.key .. "Secret"] = true
						end
					end
				else
					out.unread = out.unread + 1
				end
			end
		end
	end
	return out
end


local function allWithheld(read)
	return read.unread > 0 and next(read.byGuid) == nil
end





local function figure(entry, key)
	if entry == nil then
		return nil, "no-source"
	end
	if entry[key .. "Secret"] then
		return nil, "secret"
	end
	if type(entry[key]) == "number" then
		return entry[key]
	end
	if entry.seen then
		return 0
	end
	return nil, "no-source"
end


local function figures(entry)
	return figure(entry, "dispels")
end


local function figureMap(read)
	local out = {}
	for guid, entry in pairs(read.byGuid) do
		local dispels = figures(entry)
		if dispels ~= nil then
			out[guid] = { dispels = dispels }
		end
	end
	return out
end


local function waitedSince(since)
	if type(since) ~= "number" or type(A.precise) ~= "function" then
		return nil
	end
	local now = A.precise()
	if type(now) ~= "number" then
		return nil
	end
	return A.unitFigure(now - since)
end










local function traceMeter(w, sources, matched, unmatched, reason)
	A.trace("meter", {
		source = w.kind,
		id = w.record and w.record.id or nil,
		n = w.index,
		lockdown = w.lockdown,
		seconds = waitedSince(w.since),
		sources = sources,
		matched = matched,
		unmatched = unmatched,
		reason = reason,
		regen = w.regen,
		storeLockdown = w.storeLockdown,
		early = w.early,
	})
end


local function settle(w)
	if w.done then
		return false
	end
	w.done = true
	for i = #waiters, 1, -1 do
		if waiters[i] == w then
			table.remove(waiters, i)
		end
	end
	return true
end





local function giveUp(w, stored, why)
	if not settle(w) then
		return
	end
	local record = w.record
	record.meter = { reason = stored, waited = waitedSince(w.since) }
	if type(record.participants) == "table" then
		for _, p in pairs(record.participants) do
			if type(p) == "table" then
				p.dispels = nil
				p.meterReason = stored
			end
		end
	end
	traceMeter(w, nil, nil, nil, why)
end





local function writeAttach(w, read, readAt, waited)
	if not settle(w) then
		return
	end
	local record = w.record
	local participants = type(record.participants) == "table" and record.participants or {}

	local matched, unmatched = 0, read.unread
	for guid in pairs(read.byGuid) do
		if participants[guid] ~= nil then
			matched = matched + 1
		else
			unmatched = unmatched + 1
		end
	end

	local withheld = allWithheld(read)
	for guid, p in pairs(participants) do
		if type(p) == "table" then
			if withheld then
				p.dispels, p.meterReason = nil, "secret"
			else
				p.dispels, p.meterReason = figures(read.byGuid[guid])
			end
		end
	end
	record.meter = { readAt = readAt, waited = waited }
	traceMeter(w, read.sources, matched, unmatched, withheld and "secret" or nil)
end


local function readAttach(w)
	if w.done then
		return
	end
	writeAttach(w, readSession("Overall"), time(), waitedSince(w.since))
end


local function newMatch(w)
	local db = A.db()
	if not db then
		return false
	end
	if db.active ~= nil and db.active ~= w.record then
		return true
	end
	return type(w.nextId) == "number" and type(db.nextMatchId) == "number" and db.nextMatchId > w.nextId
end


function A.meterComplete(record)
	if type(record) == "table" then
		watches[record] = {
			lockdown = lockdown(),
			regen = false,
			resets = 0,
			at = type(A.precise) == "function" and A.precise() or nil,
		}
	end
end










function A.meterAttach(record, since, superseded)
	if type(record) ~= "table" then
		return
	end
	local watch = watches[record]
	watches[record] = nil
	record.meter = { pending = true }

	local db = A.db()
	local locked = lockdown()




	local atComplete = locked
	if watch then
		atComplete = watch.lockdown
	end
	local w = {
		kind = "attach",
		record = record,
		since = since,
		lockdown = atComplete,
		nextId = db and db.nextMatchId or nil,
		regen = watch and watch.regenAt or nil,
		storeLockdown = locked,
		early = watch and watch.read == "withheld" and "withheld" or nil,
	}

	if superseded then
		giveUp(w, "not-reached", "superseded")
		return
	end
	if not A.meterAvailable() then
		giveUp(w, "not-reached", "no-meter")
		return
	end


	if watch and type(watch.read) == "table" then
		w.early = true
		writeAttach(w, watch.read, watch.readAt, watch.regenAt)
		return
	end
	if watch and watch.resets > 0 then
		giveUp(w, "reset", "reset")
		return
	end
	if not locked then
		readAttach(w)
		return
	end



	if watch and watch.regen then
		giveUp(w, "not-reached", "combat-again")
		return
	end

	waiters[#waiters + 1] = w
	if C_Timer and C_Timer.After then
		local left = ATTACH_TIMEOUT
		local waited = waitedSince(since)
		if type(waited) == "number" then
			left = math.max(0, ATTACH_TIMEOUT - waited)
		end
		C_Timer.After(left, function()
			giveUp(w, "not-reached", "timeout")
		end)
	end
end





local function refuseRound(w, reason)
	if not settle(w) then
		return
	end
	w.round.meterPending = { reason = reason }
	traceMeter(w, nil, nil, nil, reason)
end






local function readRound(w)
	if not settle(w) then
		return
	end
	local current = readSession("Current")
	if allWithheld(current) then
		w.round.meterPending = { reason = "secret" }
		traceMeter(w, current.sources, 0, current.unread, "secret")
		return
	end
	local overall = readSession("Overall")
	local map = figureMap(current)
	local kept = 0
	for _ in pairs(map) do
		kept = kept + 1
	end
	w.round.meterPending = {
		cur = map,
		overall = figureMap(overall),
		resets = type(w.record.meterResets) == "number" and w.record.meterResets or 0,
	}


	traceMeter(w, current.sources, kept, current.unread, nil)
end


function A.meterRoundBoundary(record, round, index)
	if type(record) ~= "table" or type(round) ~= "table" then
		return
	end
	local w = {
		kind = "round",
		record = record,
		round = round,
		index = index,
		since = type(A.precise) == "function" and A.precise() or nil,
		lockdown = lockdown(),
	}
	if not A.meterAvailable() then
		w.done = true
		traceMeter(w, nil, nil, nil, "no-meter")
		return
	end
	if not w.lockdown then
		readRound(w)
		return
	end
	waiters[#waiters + 1] = w
end









function A.meterStateChanged(record, name)
	local due = {}
	for i = 1, #waiters do
		due[i] = waiters[i]
	end
	for i = 1, #due do
		local w = due[i]
		if w.kind == "round" and w.record == record
			and (name == "Engaged" or name == "PostRound" or name == "Complete") then
			refuseRound(w, "round-began")
		elseif w.kind == "attach" and newMatch(w) then
			giveUp(w, "not-reached", "new-match")
		end
	end
end






function A.meterResolveRounds(record, participants)
	local resets = type(record.meterResets) == "number" and record.meterResets or 0
	record.meterResets = nil
	local rounds = record.rounds
	if type(rounds) ~= "table" or #rounds < 1 or type(participants) ~= "table" then
		return
	end

	local function seated(map)
		local out, any, matched, unmatched = {}, false, 0, 0
		for guid, f in pairs(map) do
			local p = participants[guid]
			local seat = type(p) == "table" and p.seat or nil
			if type(seat) == "number" then
				out[seat] = { dispels = f.dispels }
				any = true
				matched = matched + 1
			else
				unmatched = unmatched + 1
			end
		end
		return any and out or nil, matched, unmatched
	end

	local last = #rounds - 1
	local kept, matchedAll, unmatchedAll = 0, 0, 0
	for i = 1, #rounds do
		local round = rounds[i]
		if type(round) == "table" then
			local pending = round.meterPending
			round.meterPending = nil
			if type(pending) == "table" then
				if pending.reason ~= nil then
					round.meter = { reason = pending.reason }
				else
					local meter, matched, unmatched = seated(type(pending.cur) == "table" and pending.cur or {})
					matchedAll, unmatchedAll = matchedAll + matched, unmatchedAll + unmatched
					if meter then
						round.meter = meter
						kept = kept + 1
					else
						round.meter = { reason = "no-source" }
					end
					if i == last and pending.resets == resets and type(pending.overall) == "table" then
						round.meterOverall = seated(pending.overall)
					end
				end
			end
		end
	end
	A.trace("meter", { source = "rounds", id = record.id, n = #rounds, kept = kept,
		matched = matchedAll, unmatched = unmatchedAll })
end










local function holdRegen()
	for _, watch in pairs(watches) do
		if not watch.regen then
			watch.regen = true
			watch.regenAt = waitedSince(watch.at)
			if watch.lockdown and watch.resets == 0 and A.meterAvailable() then
				local read = readSession("Overall")
				if allWithheld(read) then
					watch.read = "withheld"
				else
					watch.read, watch.readAt = read, time()
				end
			end
		end
	end
end

local function onRegen()
	holdRegen()
	local due = {}
	for i = 1, #waiters do
		due[i] = waiters[i]
	end
	local db = A.db()
	for i = 1, #due do
		local w = due[i]
		if w.kind == "attach" then
			if newMatch(w) then
				giveUp(w, "not-reached", "new-match")
			else
				readAttach(w)
			end
		elseif not db or db.active ~= w.record then


			if settle(w) then
				traceMeter(w, nil, nil, nil, "replaced")
			end
		elseif type(w.record.rounds) == "table" and #w.record.rounds ~= w.index then
			refuseRound(w, "round-began")
		else
			readRound(w)
		end
	end
end








local function onReset()
	for _, watch in pairs(watches) do
		watch.resets = watch.resets + 1
	end
	local db = A.db()
	if db and type(db.active) == "table" then
		db.active.meterResets = (type(db.active.meterResets) == "number" and db.active.meterResets or 0) + 1
	end
	local due = {}
	for i = 1, #waiters do
		due[i] = waiters[i]
	end
	for i = 1, #due do
		local w = due[i]
		if w.kind == "attach" then
			giveUp(w, "reset", "reset")
		else
			refuseRound(w, "reset")
		end
	end
end

A.on("PLAYER_REGEN_ENABLED", onRegen)
A.on("DAMAGE_METER_RESET", onReset)









function A.meterState(record)
	local meter = type(record) == "table" and record.meter or nil
	if type(meter) ~= "table" then
		return nil
	end
	if meter.pending then
		for i = 1, #waiters do
			if waiters[i].record == record and not waiters[i].done then
				return "pending"
			end
		end
		return "not-reached"
	end
	if meter.reason ~= nil then
		return meter.reason
	end
	return "read"
end






function A.participantMeter(record, guid)
	local participants = type(record) == "table" and record.participants or nil
	local p = type(participants) == "table" and participants[guid] or nil
	if type(p) ~= "table" then
		return nil, nil
	end
	local state = A.meterState(record)
	local dispels = type(p.dispels) == "number" and p.dispels or nil
	if state == nil then


		if dispels ~= nil then
			return dispels, nil
		end
		return nil, "unrecorded"
	end
	if state == "pending" or state == "not-reached" then
		return nil, state
	end
	return dispels, p.meterReason
end







function A.roundMeter(record, index)
	local rounds = type(record) == "table" and record.rounds or nil
	if type(rounds) ~= "table" then
		return nil, false, nil
	end
	local round = rounds[index]
	if type(round) ~= "table" then
		return nil, false, nil
	end
	if type(round.meter) == "table" then
		if round.meter.reason ~= nil then
			return nil, false, round.meter.reason
		end
		return round.meter, false, nil
	end
	if index ~= #rounds or index < 2 then
		return nil, false, nil
	end

	local base = type(rounds[index - 1]) == "table" and rounds[index - 1].meterOverall or nil
	if type(base) ~= "table" then
		return nil, true, nil
	end
	local state = A.meterState(record)
	if state ~= "read" then
		return nil, true, state
	end

	local out, any = {}, false
	for _, p in pairs(record.participants or {}) do
		local seat = type(p) == "table" and p.seat or nil
		local held = type(seat) == "number" and base[seat] or nil
		if type(seat) == "number" and type(held) == "table" then
			local function less(total, before)
				if type(total) ~= "number" or type(before) ~= "number" or total < before then
					return nil
				end
				return total - before
			end
			local dispels = less(p.dispels, held.dispels)
			if dispels ~= nil then
				out[seat] = { dispels = dispels }
				any = true
			end
		end
	end
	return any and out or nil, true, nil
end


local REASON_WORDS = {
	["no-source"] = "the meter listed no source for this player",
	secret = "the client withheld the figure when it was read",
	reset = "the meter was reset before it was read",
	["not-reached"] = "the meter was not read before combat, a new match or the timeout",
	["round-began"] = "the next round began before the read",
	pending = "waiting for combat to end before reading",
	unrecorded = "this match was stored before dispels were read",
}


function A.meterReasonWords(reason)
	return REASON_WORDS[reason] or tostring(reason)
end





function A.roundMeterLines(record, guid, index)
	local participants = type(record) == "table" and record.participants or nil
	local p = type(participants) == "table" and participants[guid] or nil
	local seat = type(p) == "table" and p.seat or nil
	local byseat = A.roundMeter(record, index)


	local lines = { ("Round %d"):format(index) }
	local held = type(byseat) == "table" and type(seat) == "number" and byseat[seat] or nil
	if type(held) == "table" then
		lines[#lines + 1] = { key = "DISPELS", text = held.dispels ~= nil and tostring(held.dispels) or "-" }
		return lines
	end
	return nil
end


function A.roundMeterCells(record, participant, index)
	local seat = type(participant) == "table" and participant.seat or nil
	if type(seat) ~= "number" then
		return nil
	end
	local byseat, derived = A.roundMeter(record, index)
	local held = type(byseat) == "table" and byseat[seat] or nil
	if type(held) ~= "table" then
		return nil
	end
	local function cellOf(value)
		if type(value) ~= "number" then
			return nil
		end
		if derived then
			return ("%d (worked out)"):format(value)
		end
		return tostring(value)
	end
	return cellOf(held.dispels)
end


function A.meterLines(record)
	local out = {}
	if type(record) ~= "table" then
		out[1] = "no such match"
		return out
	end
	local state = A.meterState(record)
	local head = ("match %s meter: "):format(tostring(record.id))
	local meter = record.meter
	if state == nil then
		out[1] = head .. A.meterReasonWords("unrecorded")
		return out
	end
	if state == "read" then
		head = head .. ("read at %s"):format(A.stampAt and A.stampAt(meter.readAt) or tostring(meter.readAt))
	elseif state == "pending" or state == "not-reached" then
		head = head .. state
	else
		head = head .. "gave up: " .. tostring(state)
	end
	if type(meter.waited) == "number" then
		head = head .. (", %.2f s after Complete"):format(meter.waited)
	end
	out[1] = head

	local rows = {}
	for guid, p in pairs(record.participants or {}) do
		if type(p) == "table" then
			rows[#rows + 1] = { guid = guid, name = tostring(p.name or guid), seat = p.seat }
		end
	end
	table.sort(rows, function(a, b) return a.name < b.name end)
	local names = {}
	for i = 1, #rows do
		local row = rows[i]
		if type(row.seat) == "number" then
			names[row.seat] = row.name
		end
		local dispels, reason = A.participantMeter(record, row.guid)
		local text = ("  %s  dispels %s"):format(row.name, dispels ~= nil and tostring(dispels) or "-")
		if reason ~= nil then
			text = text .. "  (" .. tostring(reason) .. ")"
		end
		out[#out + 1] = text
	end

	local rounds = type(record.rounds) == "table" and record.rounds or {}
	for r = 1, #rounds do
		local byseat, derived, reason = A.roundMeter(record, r)
		local label = ("  round %d%s: "):format(r, derived and " (worked out)" or "")
		if type(byseat) == "table" then
			local parts = {}
			for seat = 1, #rows do
				local held = byseat[seat]
				if type(held) == "table" then
					parts[#parts + 1] = ("%s %s"):format(names[seat] or ("seat " .. seat),
						held.dispels ~= nil and tostring(held.dispels) or "-")
				end
			end
			out[#out + 1] = label .. table.concat(parts, ", ")
		else
			out[#out + 1] = label .. (reason ~= nil and tostring(reason) or "no reading")
		end
	end
	return out
end
