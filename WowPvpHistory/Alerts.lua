








local _, A = ...



local SETTLE_SECONDS = 1



local announced
local token = 0



local announcedChat = false
local announcedBanner = false


local reported = false





function A.alertsEnabled()
	local db = A.db()
	if not db then
		return false
	end
	db.ui = db.ui or {}
	return db.ui.alerts ~= false
end



function A.setAlerts(enabled)
	local db = A.db()
	if not db then
		return false
	end
	db.ui = db.ui or {}
	if enabled == false then
		db.ui.alerts = false
	else
		db.ui.alerts = nil
	end


	if A.notifyAlertsSetting then
		A.notifyAlertsSetting()
	end
	return true
end






function A.postGameEnabled()
	local db = A.db()
	if not db then
		return false
	end
	db.ui = db.ui or {}
	return db.ui.postGame ~= false
end


function A.setPostGame(enabled)
	local db = A.db()
	if not db then
		return false
	end
	db.ui = db.ui or {}
	if enabled == false then
		db.ui.postGame = false
	else
		db.ui.postGame = nil
	end

	if A.notifyPostGameSetting then
		A.notifyPostGameSetting()
	end
	return true
end


function A.openAfterMatchEnabled()
	local db = A.db()
	if not db then
		return false
	end
	db.ui = db.ui or {}
	return db.ui.openAfterMatch ~= false
end


function A.setOpenAfterMatch(enabled)
	local db = A.db()
	if not db then
		return false
	end
	db.ui = db.ui or {}
	if enabled == false then
		db.ui.openAfterMatch = false
	else
		db.ui.openAfterMatch = nil
	end

	if A.notifyOpenAfterMatchSetting then
		A.notifyOpenAfterMatchSetting()
	end
	return true
end


function A.groupNotesEnabled()
	local db = A.db()
	if not db then
		return false
	end
	db.ui = db.ui or {}
	return db.ui.groupNotes ~= false
end


function A.setGroupNotes(enabled)
	local db = A.db()
	if not db then
		return false
	end
	db.ui = db.ui or {}
	if enabled == false then
		db.ui.groupNotes = false
	else
		db.ui.groupNotes = nil
	end

	if A.notifyGroupNotesSetting then
		A.notifyGroupNotesSetting()
	end
	return true
end



function A.groupNotesAvailable()
	return A.alertsEnabled()
end






local function contained(fn)
	local ok, err = pcall(fn)
	if ok then
		return
	end

	A.noteError(err, "alert")

	if not reported then
		reported = true
		A.say("the group and match alerts stopped: " .. tostring(err)
			.. ". /pvph alert off silences them")
	end
end





local function guarded(fn, ...)
	if type(fn) ~= "function" then
		return nil
	end
	local ok, res = pcall(fn, ...)
	if not ok then
		return nil
	end
	return res
end





function A.inMatchInstance()
	if type(GetInstanceInfo) ~= "function" then
		return false
	end
	local ok, _, instanceType = pcall(GetInstanceInfo)
	return ok and (instanceType == "pvp" or instanceType == "arena")
end



local function traceAlert(reason, n, restriction, noted, found)
	A.trace("alert", { reason = reason, n = n, restriction = restriction, noted = noted,
		found = found })
end








function A.groupGuids()
	local count = guarded(GetNumGroupMembers)
	if type(count) ~= "number" or count < 1 then
		return {}, nil
	end

	local selfGuid = guarded(UnitGUID, "player")
	if not (type(selfGuid) == "string" and A.canRead(selfGuid)) then
		selfGuid = nil
	end

	local prefix = (guarded(IsInRaid) == true) and "raid" or "party"

	local guids = {}
	for i = 1, count do
		local guid = guarded(UnitGUID, prefix .. i)

		if type(guid) == "string" and A.canRead(guid) and guid ~= selfGuid then
			guids[#guids + 1] = guid
		end
	end

	return guids, selfGuid
end





local function signature(guids)
	local sorted = {}
	for i = 1, #guids do
		sorted[i] = guids[i]
	end
	table.sort(sorted)
	return table.concat(sorted, "|")
end


local function surfaces()
	local banner = type(A.announceEnabled) == "function" and type(A.announceGroupRoster) == "function"
		and A.announceEnabled() == true
	return A.alertsEnabled(), banner
end


local function owed(sig)
	local chat, banner = surfaces()
	local same = sig == announced
	return chat and not (same and announcedChat), banner and not (same and announcedBanner)
end


local function forget()
	announced = nil
	announcedChat, announcedBanner = false, false
	if type(A.announceGroupLeft) == "function" then
		A.announceGroupLeft()
	end
end



local function announce()
	local chatOn, bannerOn = surfaces()
	if not (chatOn or bannerOn) then
		traceAlert("switch")
		return
	end
	local suppressed, reading = A.pvpRestricted()
	if suppressed then
		traceAlert("restriction", nil, reading)
		return
	end
	if A.inMatchInstance() then
		traceAlert("instance")
		return
	end

	local guids, selfGuid = A.groupGuids()
	if #guids == 0 then
		forget()
		traceAlert("no-group", 0)
		return
	end

	local sig = signature(guids)
	local chatDue, bannerDue = owed(sig)
	if not (chatDue or bannerDue) then
		traceAlert("unchanged", #guids)
		return
	end
	if sig ~= announced then
		announced = sig
		announcedChat, announcedBanner = false, false
	end


	local known, noted
	if chatDue then
		announcedChat = true
		known, noted = A.sayGroupLines(guids, selfGuid, A.groupNotesEnabled())
	else
		known = A.knownPlayers(guids, selfGuid)
	end

	if bannerDue then
		announcedBanner = true
		A.announceGroupRoster(guids, selfGuid)
	end

	traceAlert("announced", #guids, nil, noted, known and known.found or 0)
end



function A.sayGroupLines(guids, selfGuid, withNotes)
	local known = A.knownPlayers(guids, selfGuid)
	local line = A.knownLine(known, "group")
	if line then
		A.say(line)
	end



	local noted = 0
	if withNotes then
		contained(function()
			local found = A.authoredInGroup(guids, selfGuid)
			noted = #found
			for _, written in ipairs(A.authoredGroupLines(found)) do
				A.say(written)
			end
		end)
	end
	return known, noted, line ~= nil
end


local function schedule()
	token = token + 1
	local mine = token

	local after = C_Timer and C_Timer.After
	if type(after) ~= "function" then
		announce()
		return
	end

	pcall(after, SETTLE_SECONDS, function()

		if mine ~= token then
			return
		end
		contained(announce)
	end)
end





local function onRoster()
	local chatOn, bannerOn = surfaces()
	if not (chatOn or bannerOn) then
		traceAlert("switch")
		return
	end
	local suppressed, reading = A.pvpRestricted()
	if suppressed then
		traceAlert("restriction", nil, reading)
		return
	end


	if A.inMatchInstance() then
		traceAlert("instance")
		return
	end

	local guids = A.groupGuids()
	if #guids == 0 then
		forget()
		traceAlert("no-group", 0)
		return
	end

	local chatDue, bannerDue = owed(signature(guids))
	if not (chatDue or bannerDue) then
		traceAlert("unchanged", #guids)
		return
	end

	schedule()
end

A.on("GROUP_ROSTER_UPDATE", function()
	contained(onRoster)
end)











function A.alertGatesGroup(rows, selfName, selfQualified, nameIndex)
	if not A.alertsEnabled() then
		A.trace("alert", { source = "gates", reason = "switch" })
		return false
	end

	local said = false
	contained(function()
		local withNotes = A.groupNotesEnabled()
		local known, resolved, noted, printed = A.sayGatesLines(rows, selfName, selfQualified, nameIndex,
			withNotes)
		if not known then
			A.trace("alert", { source = "gates", reason = resolved,
				n = type(rows) == "table" and #rows or nil })
			return
		end
		said = printed == true
		A.trace("alert", { source = "gates", reason = "announced", n = known.offered,
			found = known.found, noted = withNotes and noted or nil })
	end)
	return said
end





function A.sayGatesLines(rows, selfName, selfQualified, nameIndex, withNotes)
	local known, resolved = A.knownOnOwnSide(rows, selfName, selfQualified, nameIndex)
	if not known then
		return nil, resolved
	end

	local line = A.knownLine(known, "group")
	if line then
		A.say(line)
	end


	local noted = 0
	if withNotes then
		contained(function()
			local found = A.authoredInGroup(resolved, nil)
			noted = #found
			for _, written in ipairs(A.authoredGroupLines(found)) do
				A.say(written)
			end
		end)
	end
	return known, resolved, noted, line ~= nil
end








function A.matchKnownClause(record)
	if not (A.alertsEnabled() and type(record) == "table") then
		return nil
	end

	local participants = record.participants
	if type(participants) ~= "table" then
		return nil
	end

	local guids = {}
	for guid in pairs(participants) do
		if type(guid) == "string" then
			guids[#guids + 1] = guid
		end
	end

	local known = A.knownPlayers(guids, record.character)
	if (known.offered or 0) == 0 then
		return nil
	end
	local found = known.found or 0
	return (", %d met before"):format(found), found
end






function A.matchLinkLine(record)
	if type(record) ~= "table" or type(record.id) ~= "number" or not A.linksAvailable() then
		return nil
	end
	return A.matchLink(record.id,
		("Open match #%s to rate and note players"):format(A.matchIdText(record.id)))
end









local pendingId
local waitedOn


local function traceAfterMatch(state, id, reason)
	A.trace("after-match", { state = state, id = id, reason = reason }, "ui")
end





local function inPvpInstance()
	if type(IsInInstance) ~= "function" then
		return false
	end
	local ok, _, kind = pcall(IsInInstance)
	return ok and (kind == "pvp" or kind == "arena")
end


local function inCombat()
	if type(InCombatLockdown) ~= "function" then
		return false
	end
	local ok, value = pcall(InCombatLockdown)
	return ok and value == true
end






local function attempt()
	local id = pendingId
	if id == nil then
		return nil
	end
	if not A.openAfterMatchEnabled() then
		pendingId, waitedOn = nil, nil
		traceAfterMatch("off", id)
		return "off"
	end

	local held
	if inPvpInstance() then
		held = "instance"
	elseif inCombat() then
		held = "combat"
	end
	if held then

		if waitedOn ~= held then
			waitedOn = held
			traceAfterMatch("waiting", id, held)
		end
		return "waiting"
	end

	pendingId, waitedOn = nil, nil
	local _, outcome = A.raiseMatchWindow("match", id, "aftermatch")
	return outcome
end



function A.holdAfterMatch(id)
	if type(id) ~= "number" then
		return nil
	end
	pendingId, waitedOn = id, nil
	traceAfterMatch("pending", id)
	return attempt()
end


function A.afterMatchPending()
	return pendingId
end






function A.dropAfterMatch()
	local id = pendingId
	pendingId, waitedOn = nil, nil
	if id ~= nil then
		traceAfterMatch("dropped", id, "replaced")
	end
	return id ~= nil
end



function A.reportAfterMatch(word)
	if word == "on" or word == "off" then
		local wanted = word == "on"
		if not A.setOpenAfterMatch(wanted) then
			A.say("no database, so the setting could not be stored")
			return
		end
		A.say("the window after a match " .. (wanted and "on" or "off"))
		return
	end

	if word then
		A.say(("unknown aftermatch command %q. on or off"):format(word))
		return
	end

	local state = A.openAfterMatchEnabled() and "on" or "off"
	if pendingId ~= nil then
		A.say(("the window after a match %s, match #%s pending")
			:format(state, A.matchIdText(pendingId)))
	else
		A.say(("the window after a match %s, nothing pending"):format(state))
	end
end


local function onLift()
	if pendingId == nil then
		return
	end
	local ok, err = pcall(attempt)
	if not ok then
		A.noteError(err, "after-match")
	end
end

A.on("PLAYER_ENTERING_WORLD", onLift)
A.on("PLAYER_REGEN_ENABLED", onLift)
