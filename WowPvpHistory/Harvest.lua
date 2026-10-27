-- WowPvpHistory 0.70.33
-- Author:  Xenu-Sentinels
-- Project: wow-pvp-history
--          https://github.com/xenulive/wow-pvp-history
-- License: MIT, see LICENSE
local ADDON,A=...

local FIRST_READ=3
local RETRY_EVERY=2
local MAX_ATTEMPTS=4

local STASH_READ=1

local STASH_ATTEMPT=0

local ROW_FIELDS={
	{"name","name"},
	{"faction","faction"},
	{"raceName","race"},
	{"className","class"},
	{"classToken","classToken"},
	{"talentSpec","spec"},
	{"roleAssigned","role"},
	{"honorLevel","honorLevel"},
	{"killingBlows","killingBlows"},
	{"honorableKills","honorableKills"},
	{"deaths","deaths"},
	{"honorGained","honor"},
	{"damageDone","damage"},
	{"healingDone","healing"},
	{"rating","rating"},
	{"ratingChange","ratingChange"},
	{"prematchMMR","mmrPre"},
	{"postmatchMMR","mmrPost"},
}

local TEAM_FIELDS={
	{"ratingMMR","mmr",true},
	{"rating","rating",false},
	{"ratingNew","ratingNew",false},
}

local COLUMN_FIELDS={
	{"pvpStatID","id"},
	{"name","name"},
	{"orderIndex","order"},
}

local function readStats(row)
	local ok,arr=pcall(A.index,row,"stats")
	if not ok or type(arr)~="table"then
		return nil
	end

	if canaccesstable then
		local queried,accessible=pcall(canaccesstable,arr)
		if not(queried and accessible==true)then
			return nil
		end
	end

	local sized,n=pcall(function()return#arr end)
	if not sized or type(n)~="number"or n==0 then
		return nil
	end

	local out,kept={},0
	for i=1,n do
		local indexed,item=pcall(A.index,arr,i)
		if indexed and type(item)=="table"then
			local gotId,id=pcall(A.index,item,"pvpStatID")
			local gotValue,value=pcall(A.index,item,"pvpStatValue")
			if gotId and gotValue and A.canRead(id)and A.canRead(value)then
				out[id]=value
				kept=kept+1
			end
		end
	end

	if kept==0 then
		return nil
	end
	return out
end

local function readRow(index)
	local ok,row=pcall(C_PvP.GetScoreInfo,index)
	if not ok or type(row)~="table"then
		return nil,nil,"noRow"
	end

	local gotGuid,guid=pcall(A.index,row,"guid")
	if not gotGuid or type(guid)~="string"then
		return nil,nil,"noGuid"
	end
	if not A.canRead(guid)then
		return nil,nil,"secretGuid"
	end

	local participant={}
	for i=1,#ROW_FIELDS do
		local field=ROW_FIELDS[i]
		local source,key=field[1],field[2]
		local gotField,value=pcall(A.index,row,source)
		if gotField then
			A.put(participant,key,value)
		end
	end

	local stats=readStats(row)
	if stats then
		participant.stats=stats
	end

	return guid,participant
end

local function readColumns()
	if not(C_PvP and C_PvP.GetMatchPVPStatColumns)then
		return nil
	end

	local ok,cols=pcall(C_PvP.GetMatchPVPStatColumns)
	if not ok or type(cols)~="table"then
		return nil
	end

	if canaccesstable then
		local queried,accessible=pcall(canaccesstable,cols)
		if not(queried and accessible==true)then
			return nil
		end
	end

	local sized,n=pcall(function()return#cols end)
	if not sized or type(n)~="number"or n==0 then
		return nil
	end

	local out={}
	for i=1,n do
		local indexed,item=pcall(A.index,cols,i)
		if indexed and type(item)=="table"then
			local column={}
			for f=1,#COLUMN_FIELDS do
				local field=COLUMN_FIELDS[f]
				local source,key=field[1],field[2]
				local gotField,value=pcall(A.index,item,source)
				if gotField then
					A.put(column,key,value)
				end
			end
			if column.id then
				out[#out+1]=column
			end
		end
	end

	if#out==0 then
		return nil
	end
	return out
end

local function readMap()
	local map={}
	local located,named,instanceType=pcall(function()
		local name,instanceType,_,_,_,_,_,instanceId=GetInstanceInfo()
		if A.canRead(name)then
			map.name=name
		end
		if A.canRead(instanceType)then
			map.instanceType=instanceType
		end
		if A.canRead(instanceId)then
			map.instanceId=instanceId
		end
		return map.name~=nil and map.name~=false,map.instanceType
	end)
	if located and named then
		return map,instanceType
	end
	return nil,instanceType
end

local function ratedArenaFormat()
	local size
	if type(GetNumArenaOpponentSpecs)=="function"then
		local ok,res=pcall(GetNumArenaOpponentSpecs)
		if ok and A.canRead(res)then
			size=res
		end
	end
	if size==2 or size==3 then
		return"arena"..size
	end
	return"arena"
end

local RATED_LADDER={
	{"IsRatedSoloShuffle","shuffle"},
	{"IsRatedSoloRBG","blitz"},
	{"IsRatedBattleground","rbg"},
	{"IsRatedArena",ratedArenaFormat},
}

local UNRATED_LADDER={
	{"IsSoloShuffle","shuffle-unrated"},
	{"IsSoloRBG","blitz-unrated"},
	{"IsArena","arena-unrated"},
	{"IsBattleground","bg"},
}

local function arenaOnBattlegroundMap(name,instanceType)
	return name=="IsArena"and instanceType=="pvp"
end
A.arenaOnBattlegroundMap=arenaOnBattlegroundMap

local function walk(ladder,instanceType)
	for i=1,#ladder do
		local name,answer=ladder[i][1],ladder[i][2]
		local value=nil
		if not arenaOnBattlegroundMap(name,instanceType)then
			value=A.pvpCall(name)
		end
		if A.canRead(value)and value==true then
			if type(answer)=="function"then
				return answer()
			end
			return answer
		end
	end
	return nil
end

local function classify(rated,instanceType)
	if rated==true then
		return walk(RATED_LADDER,instanceType)or"unknown"
	end
	if rated==false then
		return walk(UNRATED_LADDER,instanceType)or"unknown"
	end
	return walk(RATED_LADDER,instanceType)or walk(UNRATED_LADDER,instanceType)or"unknown"
end

local function ratedFlag()
	local value=A.pvpCall("DoesMatchOutcomeAffectRating")
	if not A.canRead(value)then
		return nil
	end
	return value
end

local function surfaceSample()
	local bracket=A.pvpCall("GetActiveMatchBracket")
	if not A.canRead(bracket)then
		return nil,"unreadable"
	end
	if type(bracket)~="number"then
		return nil,"no-answer"
	end
	if bracket<0 then
		return nil,"unpopulated",bracket
	end
	local rated=ratedFlag()
	local _,instanceType=readMap()
	return{bracket=bracket,rated=rated,format=classify(rated,instanceType)},
		nil,bracket
end

function A.readMatchSurface()
	return(surfaceSample())
end

function A.sampleLiveSurface(record,state)
	local sample,reason,bracket=surfaceSample()
	if sample then
		record.liveFormat=sample.format
		record.liveFormatState=state
	end
	A.trace("surface",{
		state=state,
		bracket=bracket,
		reason=reason,
		format=sample and sample.format or nil,
	})
	return sample
end

local NO_WINNER=4294967295

function A.readMatchWinner()
	local winner=A.pvpCall("GetActiveMatchWinner")
	if not A.canRead(winner)or winner==NO_WINNER then
		return nil
	end
	return winner
end

function A.requestScores()
	if type(RequestBattlefieldScoreData)=="function"then
		pcall(RequestBattlefieldScoreData)
	end
end

local function precise()
	if type(GetTimePreciseSec)~="function"then
		return nil
	end
	local ok,seconds=pcall(GetTimePreciseSec)
	if ok and type(seconds)=="number"then
		return seconds
	end
	return nil
end

A.precise=precise

local function sweepTimes(record,startedAt,finishedAt)
	local readSeconds
	if startedAt and finishedAt then
		readSeconds=finishedAt-startedAt
	end
	local readAt
	if startedAt and type(record.completedPrecise)=="number"then
		readAt=startedAt-record.completedPrecise
	end
	return readSeconds,readAt
end

local function sinceComplete(record)
	local now=precise()
	if type(now)=="number"and type(record.completedPrecise)=="number"then
		return now-record.completedPrecise
	end
	return nil
end

A.readMap=readMap
A.ratedFlag=ratedFlag

local function sweep()
	if type(SetBattlefieldScoreFaction)=="function"then
		pcall(SetBattlefieldScoreFaction,-1)
	end

	local ok,rows=pcall(GetNumBattlefieldScores)
	if not ok or not A.canRead(rows)or type(rows)~="number"then
		return nil,0,nil,{},0
	end

	local participants,kept,duplicates={},0,0
	local refused={}
	for i=1,rows do
		local guid,participant,why=readRow(i)
		if guid then
			if participants[guid]==nil then
				kept=kept+1
			else
				duplicates=duplicates+1
			end
			participants[guid]=participant
		elseif why then
			refused[why]=(refused[why]or 0)+1
		end
	end

	return participants,kept,rows,refused,duplicates
end

local function readOwnRating()
	if type(UnitName)~="function"then
		return nil
	end
	local gotSelf,own,realm=pcall(UnitName,"player")
	if not(gotSelf and type(own)=="string"and A.canRead(own)and own~="")then
		return nil
	end
	local qualified=nil
	if type(realm)=="string"and A.canRead(realm)and realm~=""then
		qualified=own.."-"..realm
	end

	local ok,rows=pcall(GetNumBattlefieldScores)
	if not ok or not A.canRead(rows)or type(rows)~="number"then
		return nil
	end

	for i=1,rows do
		local gotRow,row=pcall(C_PvP.GetScoreInfo,i)
		if gotRow and type(row)=="table"then
			local gotName,name=pcall(A.index,row,"name")
			if gotName and A.canRead(name)and(name==own or name==qualified)then
				local gotRating,rating=pcall(A.index,row,"rating")
				if gotRating and A.canRead(rating)and type(rating)=="number"then
					return rating
				end
				return nil
			end
		end
	end
	return nil
end

function A.readRoundBoundary(final)
	local guids,own=A.groupGuids()
	local size=(type(guids)=="table")and#guids or 0

	local mates,reason
	if size==0 then
		reason="no-group"
	elseif type(own)~="string"then
		reason="no-self"
	else
		mates={}
		for i=1,size do
			local guid=guids[i]
			if guid~=own then
				mates[#mates+1]=guid
			end
		end
		if#mates~=A.ROUND_MATES then
			mates,reason=nil,"group-size"
		else
			table.sort(mates)
		end
	end

	local rating=(not final)and readOwnRating()or nil
	if mates==nil and rating==nil then
		return nil,size,reason
	end
	return{guids=mates,rating=rating},size,reason
end

local ROUND_WINS_WIDGET=4457

local ROUND_WINS_STATE_CEILING=3

function A.readRoundWins()
	local manager=C_UIWidgetManager
	local getter=type(manager)=="table"and manager.GetIconAndTextWidgetVisualizationInfo or nil
	if type(getter)~="function"then
		return nil,nil,"no-getter"
	end

	local ok,info=pcall(getter,ROUND_WINS_WIDGET)
	if not ok then
		return nil,nil,"threw"
	end
	if type(info)~="table"then
		return nil,nil,"absent"
	end

	local gotState,state=pcall(A.index,info,"state")
	local widget=nil
	if gotState and A.canRead(state)and type(state)=="number"then
		widget=state
	end

	local gotText,text=pcall(A.index,info,"text")
	if not gotText or not A.canRead(text)or type(text)~="string"then
		return nil,widget,"text"
	end

	local first,last=text:find("%d+")
	if first==nil then
		return nil,widget,"no-digits"
	end
	if text:find("%d",last+1)~=nil then
		return nil,widget,"digits"
	end
	local wins=tonumber(text:sub(first,last))
	if wins==nil then
		return nil,widget,"no-digits"
	end

	if wins<=ROUND_WINS_STATE_CEILING and widget~=wins then
		return nil,widget,"state"
	end
	return wins,widget,nil
end

local function assignSeats(participants)
	local guids={}
	for guid in pairs(participants)do
		guids[#guids+1]=guid
	end
	table.sort(guids)

	for i=1,#guids do
		participants[guids[i]].seat=i
	end
	return guids
end

local function resolveRounds(record,participants)
	local rounds=record.rounds
	if type(rounds)~="table"or#rounds<1 then
		return
	end

	local seated=assignSeats(participants)
	local own=record.character~=nil and participants[record.character]or nil

	local function seats(guids)
		if type(seated)~="table"or type(guids)~="table"or#guids<1 then
			return nil
		end
		local out={}
		for i=1,#guids do
			local participant=participants[guids[i]]
			local seat=type(participant)=="table"and participant.seat or nil
			if type(seat)~="number"then
				return nil
			end
			out[i]=seat
		end
		return out
	end

	local filled,lost=0,0
	for i=1,#rounds do
		local round=rounds[i]
		if type(round)=="table"then
			local pending=round.pending
			round.pending=nil

			if type(pending)=="table"then
				local mates=seats(pending.guids)
				if mates then
					round.mates=mates
					filled=filled+1
				else
					lost=lost+1
				end
				if type(pending.rating)=="number"then
					round.ratingPost=pending.rating
				end
			end
		end
	end

	local last=rounds[#rounds]
	if type(last)=="table"and last.ratingPost==nil and type(own)=="table"
		and not A.ladderSilent(own)and type(own.rating)=="number"
		and type(own.ratingChange)=="number"then
		last.ratingPost=own.rating+own.ratingChange
	end

	return#rounds,filled,lost
end

local function endSandboxForMatch()
	if A.sandboxed()and A.endSandbox()then
		A.trace("sandbox",{state="ended",reason="match"},"data")
	end
end

local function release(record)
	local db=A.db()
	if db and db.active==record then
		db.active=nil
	end
end

local function readTeams()
	local call=C_PvP and C_PvP.GetTeamInfo
	local teams,reasons,any={},{},false
	for index=0,1 do
		local team,refused,zero,nonZero={},false,false,false
		local ok,info=false,nil
		if type(call)=="function"then
			ok,info=pcall(call,index)
		end
		if not ok then
			reasons[index]="call-failed"
		elseif type(info)~="table"then
			reasons[index]="nil-info"
		elseif not A.canRead(info)then
			reasons[index]="secret"
		else
			for i=1,#TEAM_FIELDS do
				local field=TEAM_FIELDS[i]
				local source,key,dropZero=field[1],field[2],field[3]
				local got,value=pcall(A.index,info,source)
				if not got or(type(value)~="nil"and not A.canRead(value))then
					refused=true
				elseif type(value)=="number"then
					if value~=0 then
						team[key]=value
						nonZero=true
					else
						zero=true
						if not dropZero then
							team[key]=value
						end
					end
				end
			end
			if not nonZero then
				team={}
			end
			if next(team)==nil then
				reasons[index]=refused and"secret"or(zero and"zero"or"nil-info")
			end
		end
		if next(team)~=nil then
			teams[index]=team
			any=true
		end
	end
	return any and teams or nil,reasons
end

local function store(record,participants,kept,rows,attempt,readSeconds,readAt,stash,superseded,
	announce)
	endSandboxForMatch()
	local db=A.db()

	record.participants=participants
	record.participantCount=kept

	local latched=type(record.surface)=="table"and record.surface or nil
	local live
	if not superseded then
		live=A.readMatchSurface()
	end
	local surface,source
	if latched then
		surface=latched
		if not live then
			source="latched"
		elseif live.bracket==latched.bracket then
			source="agreed"
		else
			source="disagreed"
		end
	elseif live then
		surface,source=live,"harvest"
	else
		source="absent"
	end

	if surface then
		record.format=type(surface.format)=="string"and surface.format or"unknown"
		A.put(record,"bracket",surface.bracket)
		A.put(record,"rated",surface.rated)
	else
		record.format="unknown"
	end

	A.trace("classify",{
		source=source,
		format=record.format,
		rated=record.rated,
		bracket=record.bracket,
	})

	if type(UnitGUID)=="function"then
		local ok,guid=pcall(UnitGUID,"player")
		if ok then
			A.put(record,"character",guid)
		end
	end

	local okRounds,roundCount,roundsKept,roundsLost=pcall(resolveRounds,record,participants)
	if not okRounds then
		A.noteError(roundCount,"harvest.rounds")
		roundCount=nil
	end

	if A.meterResolveRounds then
		local metered,err=pcall(A.meterResolveRounds,record,participants)
		if not metered then
			A.noteError(err,"harvest.meter")
		end
	end
	record.meterResets=nil

	local map=stash and stash.map
	if map==nil and not superseded then
		map=readMap()
	end
	if map then
		record.map=map
	end

	if live and A.put(record,"winnerFaction",A.readMatchWinner())then
		record.winnerReadAt=sinceComplete(record)
	end
	if record.selfFaction==nil and not superseded then
		A.put(record,"selfFaction",A.selfFaction())
	end

	local teamReasons=nil
	if record.rated==true then
		if superseded then
			teamReasons={[0]="superseded",[1]="superseded"}
		else
			local readOk,teams,reasons=pcall(readTeams)
			if readOk then
				record.teams,teamReasons=teams,reasons
			else
				A.noteError(teams,"harvest.teams")
				teamReasons={[0]="call-failed",[1]="call-failed"}
			end
		end
	end

	local winner,side=record.winnerFaction,record.selfFaction
	local roundList=A.roundList(record)
	local rounds=roundList and#roundList or 0
	local classified=record.format~="unknown"
	local isShuffle=(record.format=="shuffle"or record.format=="shuffle-unrated"
		or rounds>0)
	if classified and not isShuffle and type(winner)=="number"and type(side)=="number"then
		if winner==side then
			record.result="win"
		elseif winner==(side+1)%2 then
			record.result="loss"
		else
			A.trace("harvest",{format=record.format,winnerOdd=winner})
		end
	end

	local result=record.result
	local own=record.character~=nil and type(record.participants)=="table"
		and record.participants[record.character]or nil
	local withheld=false
	if record.rated==true and(result=="win"or result=="loss")and type(own)=="table"
		and type(own.ratingChange)=="number"and own.ratingChange~=0
		and not A.ladderSilent(own)
		and(own.ratingChange>0)~=(result=="win")
	then
		record.result=nil
		withheld=true
	end

	local columns=stash and stash.columns
	if columns==nil and not superseded then
		columns=readColumns()
	end
	if columns then
		record.columns=columns
		A.forgetRoundOutcomes(record)
	end

	if type(roundCount)=="number"then
		local applied,written,refused=pcall(A.applyRoundWins,record)
		if not applied then
			A.noteError(written,"harvest.roundwins")
			written,refused=nil,"threw"
		end
		A.trace("rounds",{n=roundCount,kept=roundsKept,dropped=roundsLost,won=written,
			refused=refused})
	end

	if type(record.openedEpoch)=="number"and type(record.completedEpoch)=="number"then
		record.duration=record.completedEpoch-record.openedEpoch
	end

	local version,build=GetBuildInfo()
	local restriction
	if not superseded then
		restriction=A.pvpRestriction()
	end
	record.harvest={
		attempts=attempt,
		rows=rows,
		readSeconds=readSeconds,
		readAt=readAt,
		winnerAt=record.winnerReadAt,
		matchSurface=source,
		guard=A.guard,
		restriction=restriction,
		version=version,
		build=build,
	}

	record.harvesting=nil
	record.state=nil
	local scheduler=record.harvestSource
	record.harvestSource=nil
	record.surface=nil
	record.openRated=nil
	record.openMap=nil
	record.liveFormat=nil
	record.liveFormatState=nil
	local completedPrecise=record.completedPrecise
	record.completedPrecise=nil
	record.winnerReadAt=nil
	record.fallback=nil

	if source=="absent"then
		local bots,roster=0,0
		for guid in pairs(record.participants or{})do
			roster=roster+1
			if A.isBotGuid(guid)then
				bots=bots+1
			end
		end

		if bots>0 then
			A.drop("bot-roster",A.dropContext(record,{
				map=record.map and record.map.name,
				instanceType=record.map and record.map.instanceType,
				duration=record.duration,
				rows=rows,
				kept=kept,
				bots=bots,
				roster=roster,
			}))
			release(record)
			A.say(("match not recorded: the match-level surface read nothing and %d of %d in the "
				.."roster are bots (%s)")
				:format(bots,roster,record.map and record.map.name or"no map"))
			return false
		end
	end

	local talents,talentsRead
	if superseded then
		talents,talentsRead={reason="superseded"},{state="superseded"}
	else
		local talentsOk
		talentsOk,talents,talentsRead=pcall(A.readTalents)
		if not talentsOk or type(talents)~="table"then
			A.noteError(talents,"harvest.talents")
			talents,talentsRead={reason="error"},{state="error"}
		end
	end
	record.talents=talents

	record.id=db.nextMatchId
	db.nextMatchId=db.nextMatchId+1
	db.matches[#db.matches+1]=record
	if announce then
		local announced,announceError=pcall(A.say,announce)
		if not announced then
			A.noteError(announceError,"harvest.announce")
		end
	end
	release(record)

	A.trace("talents",{id=record.id,state=talentsRead.state,pvpTalents=talentsRead.pvpTalents,
		loadoutRead=talentsRead.loadoutRead,heroRead=talentsRead.heroRead})

	if teamReasons then
		pcall(A.traceTeams,record,teamReasons)
	end

	if withheld then
		A.trace("result",{id=record.id,state="withheld",reason="rating-disagrees",
			format=record.format},"capture")
	end

	A.trace("stored",{
		id=record.id,
		kept=kept,
		rows=rows,
		attempt=attempt,
		format=record.format,
		source=scheduler,
	})

	if A.perfStored then
		local measured,err=pcall(A.perfStored,record)
		if not measured then
			A.noteError(err,"harvest.perf")
		end
	end

	if A.meterAttach then
		local armed,err=pcall(A.meterAttach,record,completedPrecise,superseded)
		if not armed then
			A.noteError(err,"harvest.meter-attach")
		end
	end

	local knownOk,knownClause=pcall(A.matchKnownClause,record)
	if not knownOk then
		knownClause=nil
	end

	local indexed,folded=pcall(A.indexMatch,record)
	if not indexed then
		A.noteError(folded,"harvest-index")
		A.say("the match is stored and the player index was not updated: "..tostring(folded)
			..". /pvph rebuild")
	end

	A.trace("index",{n=indexed and folded or nil,id=record.id})

	local folded2,why2=pcall(A.mergeNamedPlayers,record)
	if not folded2 then
		A.noteError(why2,"harvest-merge")
	end

	local noted,notedError=pcall(A.noteCanary)
	if not noted then
		A.noteError(notedError,"harvest-canary")
	end

	A.recordStored("harvest")

	local bestsOk,bestsSet,bestsEarlier,bestsState=pcall(A.newBests,record)
	if not bestsOk then
		A.noteError(bestsSet,"harvest.bests")
		bestsSet,bestsEarlier,bestsState={},nil,"error"
	end
	local setKeys={}
	local keysOk,keysError=pcall(function()
		for i=1,(type(bestsSet)=="table"and#bestsSet or 0)do
			setKeys[i]=bestsSet[i].key
		end
	end)
	if not keysOk then
		A.noteError(keysError,"harvest.bests-keys")
	end
	A.trace("bests",{id=record.id,state=bestsState,earlier=bestsEarlier,
		bestsSet=#setKeys>0 and table.concat(setKeys,",")or nil})

	local line="switch"
	local rateClause,rateSign=false,nil
	local said,chatErr=pcall(function()
		if not A.postGameEnabled()then
			return
		end
		line="recorded"
		local clause,sign=A.ratingClause(record)
		rateClause,rateSign=clause~=nil,sign
		A.say(("recorded match %d: %s, %d %s%s%s")
			:format(record.id,A.formatLabel(record.format),kept,
				kept==1 and"participant"or"participants",knownClause or"",
				clause and(", "..clause)or""))
		line="bests"
		local bestLine=A.newBestLine(bestsSet)
		if bestLine then
			A.say(bestLine)
		end
		line="pending"
		local pendingOk,pendingLine=pcall(A.pendingLine)
		if pendingOk and pendingLine then
			A.say(pendingLine)
		end
		line="link"
		local linkOk,linkLine=pcall(A.matchLinkLine,record)
		if linkOk and linkLine then
			A.say(linkLine)
		end
	end)
	if not said then
		pcall(A.trace,"chat-line",{source="harvest",state=line,id=record.id,err=chatErr,
			rateClause=rateClause,rateSign=rateSign})
	else
		pcall(A.trace,"chat-line",{source="harvest",state=line=="switch"and"switch"or"said",
			id=record.id,rateClause=rateClause,rateSign=rateSign})
	end

	local heldOk,heldErr=pcall(A.holdAfterMatch,record.id)
	if not heldOk then
		A.noteError(heldErr,"after-match")
	end
	return true
end

function A.storeFallback(record,attempt,superseded)
	local fallback=record.fallback
	if not(type(fallback)=="table"and type(fallback.kept)=="number"and fallback.kept>0)then
		return false,false
	end

	local why=("scoreboard gone after %s"):format(attempt and(attempt.." attempts")or"no scheduled read")
	if superseded then
		why="a new match opened before the scoreboard was read"
	end
	local announce=("%s, storing the roster read at %s: %d rows")
		:format(why,
			fallback.readAt and("+"..string.format("%.1f",fallback.readAt).." s")or"the transition",
			fallback.kept)

	local stored=store(record,fallback.participants,fallback.kept,fallback.rows,
		STASH_ATTEMPT,fallback.readSeconds,fallback.readAt,fallback,superseded,announce)
	return stored==true,stored~=true
end

local function supersede(record,attempt,opened,current)
	local fallback=record.fallback
	local kept=type(fallback)=="table"and type(fallback.kept)=="number"and fallback.kept or 0
	local stored,refused=A.storeFallback(record,attempt,true)
	A.trace("superseded",{
		attempt=attempt,
		openedGen=opened,
		currentGen=current,
		kept=kept,
		source=stored and"stash"or(refused and"refused"or"drop"),
	})
	if stored or refused then
		return
	end
	A.drop("superseded",A.dropContext(record,{attempts=attempt}))
	release(record)
	A.say(("match not recorded: a new match opened before its scoreboard was read (attempt %d)")
		:format(attempt))
end

local function runHarvest(record,attempt)
	endSandboxForMatch()
	local db=A.db()
	if not db then
		return
	end

	if A.harvestGeneration then
		local opened,current=A.harvestGeneration(record)
		if type(opened)=="number"and type(current)=="number"and opened<current then
			supersede(record,attempt,opened,current)
			return
		end
	end

	local startedAt=precise()
	local participants,kept,rows,refused,duplicates=sweep()
	local finishedAt=precise()

	local readSeconds,readAt=sweepTimes(record,startedAt,finishedAt)

	A.trace("harvest",{attempt=attempt,rows=rows,kept=kept,off=A.unitFigure(readAt),
		duplicate=duplicates>0 and duplicates or nil})

	if type(rows)=="number"and kept<rows and next(refused)~=nil then
		A.trace("refused",{
			rows=rows,
			kept=kept,
			noRow=refused.noRow,
			noGuid=refused.noGuid,
			secretGuid=refused.secretGuid,
			restriction=A.pvpRestriction(),
		})
	end

	if kept==0 then
		if attempt<MAX_ATTEMPTS then
			A.requestScores()
			A.scheduleHarvest(record,attempt+1)
			return
		end

		local stored,stashRefused=A.storeFallback(record,attempt)
		if stored or stashRefused then
			return
		end

		local reason="no-readable-guid"
		if rows==nil then
			reason="scoreboard-unreadable"
		elseif rows==0 then
			reason="window-closed"
		end
		A.drop(reason,A.dropContext(record,{rows=rows,readAt=readAt,attempts=attempt}))
		release(record)
		A.say(("match not recorded after %d attempts: %s (%s rows, read at %s, PvPMatch restriction %s)")
			:format(attempt,reason,tostring(rows),tostring(readAt),tostring(A.pvpRestriction())))
		return
	end

	store(record,participants,kept,rows,attempt,readSeconds,readAt)
end

function A.stashRoster(record)
	local startedAt=precise()
	local participants,kept,rows,_,duplicates=sweep()
	local finishedAt=precise()

	local readSeconds,readAt=sweepTimes(record,startedAt,finishedAt)

	local winner
	if A.readMatchSurface()then
		winner=A.readMatchWinner()
		local winnerAt=sinceComplete(record)
		if A.put(record,"winnerFaction",winner)then
			record.winnerReadAt=winnerAt
		end
	end

	A.trace("sweep",{rows=rows,kept=kept,off=A.unitFigure(readAt),winner=winner,
		duplicate=duplicates>0 and duplicates or nil})

	if kept==0 then
		return
	end

	local held=record.fallback
	if type(held)=="table"and type(held.kept)=="number"and held.kept>kept then
		return
	end

	record.fallback={
		participants=participants,
		kept=kept,
		rows=rows,
		readAt=readAt,
		readSeconds=readSeconds,
		columns=readColumns(),
		map=readMap(),
	}
end

function A.stashAtTransition(record)
	local swept,err=pcall(A.stashRoster,record)
	if not swept then
		A.noteError(err,"stash-transition")
	end

	if C_Timer and C_Timer.After then
		C_Timer.After(STASH_READ,function()
			local db=A.db()
			if db and db.active==record and record.harvesting then
				local ok,why=pcall(A.stashRoster,record)
				if not ok then
					A.noteError(why,"stash-sweep")
				end
			end
		end)
	end
end

local pendingReads=setmetatable({},{__mode="k"})

function A.harvestsPending()
	local n=0
	for _ in pairs(pendingReads)do
		n=n+1
	end
	return n
end

function A.matchInFlight(db)
	if type(db)=="table"and db.active~=nil then
		return true
	end
	return A.harvestsPending()>0
end

function A.scheduleHarvest(record,attempt)
	attempt=attempt or 1

	if not(C_Timer and C_Timer.After)then
		local stored,refused=A.storeFallback(record,nil)
		if stored or refused then
			return
		end
		A.drop("no-timer",A.dropContext(record))
		release(record)
		A.say("match not recorded: C_Timer.After is unavailable and the read cannot be inline")
		return
	end

	local delay=(attempt==1)and FIRST_READ or RETRY_EVERY
	pendingReads[record]=(pendingReads[record]or 0)+1
	C_Timer.After(delay,function()
		local left=(pendingReads[record]or 1)-1
		pendingReads[record]=left>0 and left or nil
		local ok,err=pcall(runHarvest,record,attempt)
		if not ok then
			local db=A.db()
			A.drop("harvest-threw",A.dropContext(record,{attempts=attempt}))
			if db then
				A.noteError(err,"harvest")
			end
			release(record)
			A.say("harvest failed on attempt "..tostring(attempt)..": "..tostring(err))
		end
	end)
end

function A.arenaMapBattleground(record)
	return type(record)=="table"and record.format=="arena-unrated"and type(record.map)=="table"
		and record.map.instanceType=="pvp"
end

function A.refileArenaMapBattlegrounds()
	local db=A.db()
	if not db or db.arenaMapRefiled then
		return nil
	end
	local ids={}
	for _,record in ipairs(type(db.matches)=="table"and db.matches or{})do
		if A.arenaMapBattleground(record)then
			record.format="bg"
			ids[#ids+1]=tostring(record.id)
		end
	end
	db.arenaMapRefiled=true
	if#ids>0 then
		db.playerIndexVersion=nil
		A.trace("refile",{
			reason="arena-map-battleground",
			n=#ids,
			ids=table.concat(ids,","),
		},"capture")
		A.say(("filed %d stored %s played on a battleground map as %s, not Skirmish: #%s")
			:format(#ids,#ids==1 and"match"or"matches",A.formatLabel("bg"),table.concat(ids,", #")))
	end
	return#ids
end

A.on("ADDON_LOADED",function(_,name)
	if name==ADDON then
		A.refileArenaMapBattlegrounds()
	end
end)
