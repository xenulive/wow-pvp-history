-- WowPvpHistory 0.75.26
-- Author:  Xenu-Sentinels
-- Project: wow-pvp-history
--          https://github.com/xenulive/wow-pvp-history
-- License: MIT, see LICENSE
local _,A=...

local scheduled=setmetatable({},{__mode="k"})

local generation=0
local openedUnder=setmetatable({},{__mode="k"})

function A.harvestGeneration(record)
	return openedUnder[record],generation
end

local function claimHarvest(record,source)
	if scheduled[record]then
		A.trace("reschedule",{source=source,state=record.state})
		return false
	end
	scheduled[record]=true
	record.harvestSource=source
	return true
end

local PAUSE_MINUTES,PAUSE_MINUTES_MAX=60,24*60

local pauseCall=0

function A.worldEnabled()
	local db=A.db()
	if not db then
		return false
	end
	return not(type(db.ui)=="table"and db.ui.world==false)
end

function A.setWorld(enabled)
	local db=A.db()
	if not db then
		return false
	end
	if type(db.ui)~="table"then
		db.ui={}
	end
	if enabled==false then
		db.ui.world=false
		if A.closeWorldSession then
			local closed,err=pcall(A.closeWorldSession,"switch")
			if not closed then
				A.noteError(err,"world-switch")
			end
		end
	else
		db.ui.world=nil
	end
	if A.notifyWorldSetting then
		A.notifyWorldSetting()
	end
	return true
end

function A.characterRecorded(guid)
	guid=guid or A.ownGuid()
	local db=A.db()
	if guid==nil or not db or type(db.ui)~="table"or type(db.ui.mute)~="table"then
		return true
	end
	return db.ui.mute[guid]~=true
end

function A.setCharacterRecorded(enabled,guid)
	guid=guid or A.ownGuid()
	local db=A.db()
	if not db or guid==nil then
		return false
	end
	if type(db.ui)~="table"then
		db.ui={}
	end
	if enabled==false then
		if type(db.ui.mute)~="table"then
			db.ui.mute={}
		end
		db.ui.mute[guid]=true
	elseif type(db.ui.mute)=="table"then
		db.ui.mute[guid]=nil
		if next(db.ui.mute)==nil then
			db.ui.mute=nil
		end
	end
	if A.notifyCharacterRecordedSetting then
		A.notifyCharacterRecordedSetting()
	end
	return true
end

function A.recordingName(guid)
	guid=guid or A.ownGuid()
	local db=A.db()
	local held=guid and db and type(db.characters)=="table"and db.characters[guid]or nil
	if type(held)~="table"or type(held.name)~="string"or held.name==""then
		return nil
	end
	if type(held.realm)=="string"and held.realm~=""then
		return held.name.."-"..held.realm
	end
	return held.name
end

function A.mutedCharacters()
	local out={}
	local db=A.db()
	local mute=db and type(db.ui)=="table"and db.ui.mute or nil
	if type(mute)~="table"then
		return out
	end
	for guid,on in pairs(mute)do
		if on==true and type(guid)=="string"then
			out[#out+1]=guid
		end
	end
	table.sort(out)
	return out
end

function A.pausedUntil(now)
	local db=A.db()
	local ui=db and type(db.ui)=="table"and db.ui or nil
	if ui==nil or ui.pausedUntil==nil then
		return nil
	end
	local at=tonumber(ui.pausedUntil)
	now=now or time()
	if at==nil or at~=at or at==math.huge or at<=now then
		ui.pausedUntil=nil
		A.trace("pause",{state="ended",source="clock"})
		if A.notifyPauseSetting then
			A.notifyPauseSetting()
		end
		return nil
	end
	return at
end

function A.pauseClock(at)
	return A.clockWords(at)
end

function A.pauseRange()
	return 1,PAUSE_MINUTES_MAX,PAUSE_MINUTES
end

function A.setPause(minutes)
	local db=A.db()
	local figure=minutes==nil and PAUSE_MINUTES or tonumber(minutes)
	if not db or figure==nil or figure~=math.floor(figure)or figure<1 or figure>PAUSE_MINUTES_MAX then
		return false
	end
	if type(db.ui)~="table"then
		db.ui={}
	end
	local at=time()+figure*60
	db.ui.pausedUntil=at
	A.trace("pause",{state="started",n=figure})
	pauseCall=pauseCall+1
	local call=pauseCall
	local after=C_Timer and C_Timer.After
	if type(after)=="function"then
		pcall(after,figure*60+1,function()
			if call==pauseCall then
				A.pausedUntil()
			end
		end)
	end
	if A.notifyPauseSetting then
		A.notifyPauseSetting()
	end
	return at
end

function A.resumeRecording()
	local running=A.pausedUntil()~=nil
	pauseCall=pauseCall+1
	if running then
		A.db().ui.pausedUntil=nil
		A.trace("pause",{state="ended",source="resume"})
		if A.notifyPauseSetting then
			A.notifyPauseSetting()
		end
	end
	return running
end

function A.captureRefusal(kind)
	local reason
	if not A.characterRecorded()then
		reason="muted"
	elseif A.pausedUntil()~=nil then
		reason="paused"
	end
	if reason then
		A.trace("skip",{reason=reason,kind=kind})
	end
	return reason
end

function A.pauseLoginLine()
	local at=A.pausedUntil()
	if at==nil then
		return nil
	end
	return("recording is paused until %s. /pvph resume starts it again"):format(A.pauseClock(at))
end

local function openMatch(stateName)
	if A.sandboxed()and A.endSandbox()then
		A.trace("sandbox",{state="ended",reason="match"},"data")
	end
	local db=A.db()
	if not db or db.active then
		return
	end
	if A.captureRefusal("match")then
		return
	end
	local record={
		openedAt=A.stamp(),
		openedEpoch=time(),
		openedState=stateName,
		rounds={},
	}

	local opener=A.ownGuid()
	if opener~=nil then
		record.character=opener
	end

	pcall(function()
		local rated=A.ratedFlag()
		if rated~=nil then
			record.openRated=rated
		end
		local map=A.readMap()
		if map then
			record.openMap=map
		end
	end)

	generation=generation+1
	openedUnder[record]=generation
	db.active=record

	if A.perfOpen then
		local opened,err=pcall(A.perfOpen,record)
		if not opened then
			A.noteError(err,"perf-open")
		end
	end
end

local ROUND_WINS_DELAY=2

local function scheduleRoundWins(record,round,index)
	if not(C_Timer and C_Timer.After)then
		A.trace("roundwins",{n=index,reason="no-timer"})
		return
	end
	C_Timer.After(ROUND_WINS_DELAY,function()
		local db=A.db()
		if not db or db.active~=record then
			A.trace("roundwins",{n=index,reason="replaced"})
			return
		end
		local ok,wins,widget,reason=pcall(A.readRoundWins)
		if not ok then
			wins,widget,reason=nil,nil,"threw"
		end
		if type(wins)=="number"then
			round.winsPost=wins
		end
		A.trace("roundwins",{n=index,wins=wins,widget=widget,reason=reason})
		if A.tallyWins then
			A.tallyWins(record)
		end
	end)
end

local function addRound(record)
	local rounds=A.roundList(record)
	if not rounds then
		rounds={}
		record.rounds=rounds
	end
	local round={endedEpoch=time()}
	rounds[#rounds+1]=round

	local final=record.state=="Complete"
	local ok,read,size,reason=pcall(A.readRoundBoundary,final)
	if ok and type(read)=="table"then
		round.pending=read
	end
	if not ok then
		size,reason=nil,"threw"
	end

	if not final then
		local armed=pcall(scheduleRoundWins,record,round,#rounds)
		if not armed then
			A.trace("roundwins",{n=#rounds,reason="threw"})
		end
		if A.meterRoundBoundary then
			local metered,err=pcall(A.meterRoundBoundary,record,round,#rounds)
			if not metered then
				A.noteError(err,"meter-round")
			end
		end
	end

	local winnerSeen
	local gotWinner,winner=pcall(A.readMatchWinner)
	if gotWinner and A.canRead(winner)then
		winnerSeen=winner
	end

	A.trace("round",{
		n=#rounds,
		state=record.state,
		rows=size,
		kept=round.pending~=nil and type(round.pending.guids)=="table"
			and#round.pending.guids or 0,
		rating=round.pending~=nil and round.pending.rating~=nil or nil,
		winner=winnerSeen,
		reason=reason,
	})
end

local function sampleSeason(record)
	local arena,display=A.arenaSeasonNow(),A.displaySeasonNow()
	local game,season=A.seasonPairOf(arena,display)
	local stored=A.put(record,"season",season)
	A.put(record,"gameSeason",game)
	local fields={arena=arena,season=display}
	if stored then
		fields.source="client"
	else
		fields.reason="no-season"
	end
	A.trace("season",fields,"data")
end

local function onComplete(record)
	if not claimHarvest(record,"complete")then
		if record.completedEpoch==nil then
			local held=A.roundList(record)
			if held and#held>0 then
				addRound(record)
			end
			record.completedEpoch=time()
		end
		if record.winnerFaction==nil and A.readMatchSurface()then
			A.put(record,"winnerFaction",A.readMatchWinner())
		end
		if record.season==nil then
			sampleSeason(record)
		end
		if record.surface==nil then
			record.surface=A.readMatchSurface()
		end
		return
	end

	local held=A.roundList(record)
	if held and#held>0 then
		addRound(record)
	end

	record.completedEpoch=time()
	record.harvesting=true

	record.completedPrecise=A.precise()

	if A.meterComplete then
		local metered,err=pcall(A.meterComplete,record)
		if not metered then
			A.noteError(err,"meter-complete")
		end
	end

	A.put(record,"winnerFaction",A.readMatchWinner())
	A.put(record,"selfFaction",A.selfFaction())

	sampleSeason(record)

	record.surface=A.readMatchSurface()

	A.stashAtTransition(record)

	A.holdAtTransition(record)

	A.requestScores()

	if A.postGameEnabled()then
		A.say("match complete, reading the scoreboard in a few seconds")
	end
	A.scheduleHarvest(record)
end

local function noteEntry(kind,record,errorSource)
	local ok,noted=pcall(A.noteIncomplete,kind,record)
	if ok and type(noted)=="table"then
		A.say(A.incompleteLine(noted),"event")
	elseif not ok then
		A.noteError(noted,errorSource)
	end
end

local function onState(event)
	local db=A.db()
	if not db then
		A.trace("transition",{reason="no-database",source=event})
		return
	end

	local name=A.stateName(A.matchState())
	local record=db.active

	if record~=nil and type(record)~="table"then
		A.drop("abandoned-across-session",A.dropContext(record))
		db.active=nil
		record=nil
	end

	if name==nil or name=="Inactive"then
		if A.perfHalt then
			A.perfHalt()
		end
		if record and not record.harvesting then
			A.drop("left-before-complete",A.dropContext(record))
			noteEntry("left",record,"incomplete-left")
			db.active=nil
			if A.perfDiscard then
				A.perfDiscard()
			end
		end
		local why="no-record"
		if record then
			why=record.harvesting and"harvesting"or"left"
		end
		A.trace("transition",{state="Inactive",reason=why,source=event,
			rounds=record and A.roundList(record)and#record.rounds or nil})
		if A.tallyMatchState then
			A.tallyMatchState(record,"Inactive")
		end
		return
	end

	if record and record.harvesting and name~="Complete"then
		local age
		if type(record.completedPrecise)=="number"then
			local now=A.precise()
			if now then
				age=now-record.completedPrecise
			end
		end
		A.trace("release",{
			state=name,
			source=record.harvestSource,
			rounds=A.roundList(record)and#record.rounds or nil,
			off=A.unitFigure(age),
		})
		db.active=nil
		record=nil
	end

	if not record then
		if name=="Complete"then
			A.trace("transition",{state=name,reason="unopened",source=event})
			return
		end
		openMatch(name)
		db=A.db()
		record=db and db.active
		if not record then
			A.trace("transition",{state=name,reason="not-opened",source=event})
			return
		end
	end

	if name==record.state then
		A.trace("transition",{state=name,reason="same-state",source=event})
		return
	end
	record.state=name

	A.trace("transition",{state=name,restriction=A.pvpRestriction(),source=event})

	if A.meterStateChanged then
		local changed,err=pcall(A.meterStateChanged,record,name)
		if not changed then
			A.noteError(err,"meter-state")
		end
	end

	if name=="Engaged"or name=="PostRound"then
		local sampled,err=pcall(A.sampleLiveSurface,record,name)
		if not sampled then
			A.noteError(err,"surface-sample")
		end
	end

	if name=="PostRound"then
		addRound(record)
	elseif name=="Complete"then
		onComplete(record)
	end

	if A.announceRoster then
		A.announceRoster(record,name)
	end
	if A.tallyMatchState then
		A.tallyMatchState(record,name)
	end
end

local function abandon(db)
	A.drop("abandoned-across-session",A.dropContext(db.active))
	noteEntry("abandoned",db.active,"incomplete-abandoned")
	db.active=nil
end

local function resume()
	local db=A.db()
	if not db then
		A.trace("resume",{state="refused",reason="no-database"})
		return
	end
	if not db.active then
		A.trace("resume",{state="skipped",reason="nothing-open"})
		return
	end
	if type(db.active)~="table"then
		abandon(db)
		A.trace("resume",{state="abandoned",reason="damaged"})
		return
	end

	if openedUnder[db.active]==nil then
		openedUnder[db.active]=generation
	end

	local name=A.stateName(A.matchState())

	if name==nil or name=="Inactive"then
		abandon(db)
		A.trace("resume",{state="abandoned",reason="inactive"})
		return
	end

	if name=="Complete"then
		if not claimHarvest(db.active,"resume")then
			A.trace("resume",{state=name,reason="claimed"})
			return
		end

		db.active.completedPrecise=nil
		db.active.harvesting=true
		A.stashAtTransition(db.active)
		A.scheduleHarvest(db.active)
		A.trace("resume",{state=name,rounds=A.roundList(db.active)and#db.active.rounds or nil})
		return
	end

	if db.active.harvesting and not scheduled[db.active]then
		abandon(db)
		A.trace("resume",{state=name,reason="harvest-left"})
		return
	end

	db.active.completedPrecise=nil
	local resumedRounds=A.roundList(db.active)
	A.trace("resume",{state=name,rounds=resumedRounds and#resumedRounds or nil})
	A.say("resumed a match in progress, "..tostring(resumedRounds and#resumedRounds or 0).." rounds so far")

	if name=="StartUp"and A.announceRoster then
		A.announceRoster(db.active,name)
	end
	if A.tallyMatchState then
		A.tallyMatchState(db.active,name)
	end
end

A.on("PLAYER_LOGIN",resume)

A.on("PVP_MATCH_STATE_CHANGED",onState)
A.on("PVP_MATCH_COMPLETE",onState)
A.on("PVP_MATCH_INACTIVE",onState)

local function onActive(event)
	local name=A.stateName(A.matchState())
	if name=="Waiting"then
		A.trace("active",{state=name,reason="waiting"})
		return
	end
	onState(event)
end

A.on("PVP_MATCH_ACTIVE",onActive)

A.on("PLAYER_ENTERING_WORLD",onState)
