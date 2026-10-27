-- WowPvpHistory 0.70.33
-- Author:  Xenu-Sentinels
-- Project: wow-pvp-history
--          https://github.com/xenulive/wow-pvp-history
-- License: MIT, see LICENSE
local _,A=...

function A.canary()
	local canary=WowPvpHistoryCanaryDB
	if type(canary)~="table"then
		return nil
	end
	return canary
end

function A.noteCanary(constants)
	if type(A.sandboxed)=="function"and A.sandboxed()then
		return nil
	end
	local db=A.db()
	if not db then
		return nil
	end

	local canary=A.canary()
	if not canary then
		canary={}
		WowPvpHistoryCanaryDB=canary
	end

	canary.matches=#db.matches
	local ok,stamp=pcall(A.stamp)
	canary.at=ok and stamp or nil
	local okEpoch,epoch=pcall(time)
	canary.epoch=okEpoch and epoch or nil

	if type(constants)=="number"then
		canary.constants=constants
		canary.constantsAt=ok and stamp or nil
	end

	return canary
end

local PRUNE_LOG_BOUND=8

function A.notePrune(op,before)
	local db=A.db()
	if not db then
		return nil
	end

	local log=db.pruneLog
	if type(log)~="table"then
		log={}
		db.pruneLog=log
	end

	local ok,epoch=pcall(time)
	log[#log+1]={
		op=op,
		epoch=ok and epoch or nil,
		before=before,
		after=#db.matches,
	}
	while#log>PRUNE_LOG_BOUND do
		table.remove(log,1)
	end

	return A.noteCanary()
end

local PRUNE_WORDS={
	fixture="generated-record run",
	["fixture-clear"]="generated-record clear",
	reset="reset",
	import="import",
	restore="restore",
	csv="CSV import",
}

local function pruneWord(op)
	return PRUNE_WORDS[op]or"deliberate change"
end

function A.canaryState()
	local db=A.savedDB()
	if not db then
		return{state="absent"}
	end

	local stored=#db.matches
	local canary=A.canary()
	local seen=canary and canary.matches
	local held=seen

	local stampedAt=canary and canary.epoch
	local via,undated
	local log=db.pruneLog
	local newest=type(log)=="table"and log[#log]or nil
	if type(seen)=="number"and type(newest)=="table"and type(newest.after)=="number"then
		if type(newest.epoch)~="number"then
			undated=true
		elseif type(stampedAt)~="number"or newest.epoch>stampedAt then
			held=newest.after
			via=newest.op
		end
	end

	local result={
		stored=stored,
		held=held,
		seen=seen,
		via=via,
		at=canary and canary.at,
		constants=canary and canary.constants,
		constantsAt=canary and canary.constantsAt,
		lost=canary and canary.lost,
	}

	if type(held)~="number"then
		result.state="absent"
	elseif stored>=held then
		result.state="agreeing"
	elseif undated then
		result.state="unknown"
	elseif stored==0 then
		result.state="lost"
	else
		result.state="short"
	end

	return result
end

function A.canaryLossLines(state)
	local lines={}

	local held=("%d %s"):format(state.held,state.held==1 and"match"or"matches")
	local now=state.stored==0 and"empty"or("down to "..state.stored)
	if state.via then
		lines[#lines+1]=("the stored history is %s and held %s after the last %s")
			:format(now,held,pruneWord(state.via))
	else
		lines[#lines+1]=("the stored history is %s and this character last saw %s")
			:format(now,held)
	end

	if state.state=="short"then
		lines[#lines+1]="the saved-variables file loaded, holding fewer matches than this "
			.."character last saw. Nothing stored separates records removed on purpose from "
			.."records the client dropped"
		lines[#lines+1]="the previous save is still at WTF\\Account\\<id>\\SavedVariables\\"
			.."WowPvpHistory.lua.bak until the next clean exit writes over it"
	else
		lines[#lines+1]="the saved-variables file did not load. Its chunk exceeding the Lua "
			.."constant ceiling does this, and the client overwrites the file and its backup"
		lines[#lines+1]="check _retail_\\Logs\\FrameXML.log for a constant table overflow "
			.."line. Nothing is recoverable from in game"

		lines[#lines+1]="the client keeps one previous copy. WTF\\Account\\<id>\\"
			.."SavedVariables\\WowPvpHistory.lua.bak still holds it until the next clean exit "
			.."writes over it: exit now and copy that file out"
	end

	local restorable=A.backupLossLine()
	if restorable then
		lines[#lines+1]=restorable
	end

	return lines
end

function A.canaryReading(state)
	if state.state=="absent"then
		return"none on this character yet, so a load failure here would not be caught"
	end

	local text
	if state.state=="agreeing"then
		text=("%d %s, agreeing"):format(state.held,
			state.held==1 and"match"or"matches")
		if state.at then
			text=text..(", stamped %s"):format(tostring(state.at))
		end
	elseif state.state=="short"then
		text=("%d %s held against %d stored, which is short rather than lost. The file loaded "
			.."and holds fewer matches than %s")
			:format(state.held,state.held==1 and"match"or"matches",state.stored,
				state.via and("the last "..pruneWord(state.via).." left")
					or"this character last saw")
	elseif state.state=="unknown"then
		text=("%d %s held against %d stored, beside a deliberate change to the history that "
			.."carries no time. Whether it came after this character's count cannot be told, so "
			.."neither a loss nor agreement is claimed")
			:format(state.held,state.held==1 and"match"or"matches",state.stored)
	else
		text=("%d %s held against %d stored. THE HISTORY WAS LOST")
			:format(state.held,state.held==1 and"match"or"matches",state.stored)
	end

	if state.lost and state.state~="lost"and state.state~="short"then
		text=text..(". A loss of %d %s was recorded %s"):format(state.lost.matches,
			state.lost.matches==1 and"match"or"matches",
			state.lost.at and tostring(state.lost.at)or"at a login whose clock did not answer")
	end

	return text
end

function A.canaryLine(state)
	return"canary: "..A.canaryReading(state)
end

function A.canaryWillAnnounce()
	local state=A.canaryState()
	return state.state=="lost"or state.state=="short"
end

local announcedThisLogin=false

function A.canaryAnnouncedThisLogin()
	return announcedThisLogin
end

local function check()
	local state=A.canaryState()

	A.trace("canary",{
		state=state.state,
		n=state.stored,
		kept=state.seen,
		heldCount=state.via and state.held or nil,
		via=state.via,
	})

	if state.state=="lost"or state.state=="short"then
		announcedThisLogin=true
		local lines=A.canaryLossLines(state)
		for i=1,#lines do
			A.say(lines[i],"fault")
		end
	end

	local canary=A.noteCanary()
	if canary and(state.state=="lost"or state.state=="short")then
		canary.lost={matches=state.held,at=canary.at}
	end
end

A.on("PLAYER_LOGIN",check)
