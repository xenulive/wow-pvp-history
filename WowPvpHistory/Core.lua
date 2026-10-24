-- WowPvpHistory 0.70.16
-- Author:  Xenu-Sentinels
-- Project: wow-pvp-history
--          https://github.com/xenulive/wow-pvp-history
-- License: MIT, see LICENSE
local ADDON,A=...

A.name=ADDON

local function readField(field)
	local api=C_AddOns and C_AddOns.GetAddOnMetadata
	if type(api)~="function"then
		return nil
	end
	local ok,value=pcall(api,ADDON,field)
	if ok and type(value)=="string"and value~=""then
		return value
	end
	return nil
end

A.version=readField("Version")

A.license=readField("X-License")
A.website=readField("X-Website")

A.debugDefault=readField("X-Debug-Default")=="on"

A.description=readField("Notes")

A.ICON_TEXTURE="Interface\\AddOns\\WowPvpHistory\\textures\\minimap"

A.schema=3

A.ROUND_MATES=2

A.FIXTURE_KEY="fixture"

local HEX="0123456789abcdef"

function A.hex8(value)
	local out={}
	for i=8,1,-1 do
		local nibble=value%16
		out[i]=HEX:sub(nibble+1,nibble+1)
		value=(value-nibble)/16
	end
	return table.concat(out)
end

A.guard=(canaccessvalue and"canaccessvalue")or(issecretvalue and"issecretvalue")or"none"

function A.index(tbl,key)
	return tbl[key]
end

function A.canRead(value)
	if type(value)=="nil"then
		return false
	end
	local canaccess,issecret=canaccessvalue,issecretvalue
	if canaccess then
		local ok,res=pcall(canaccess,value)
		return ok and res==true
	end
	if issecret then
		local ok,res=pcall(issecret,value)
		return ok and res~=true
	end
	return true
end

function A.readableString(value)
	if type(value)~="string"or not A.canRead(value)or value==""then
		return nil
	end
	return value
end

function A.put(record,key,value)
	if A.canRead(value)then
		record[key]=value
		return true
	end
	return false
end

local db

local sandbox

function A.db()
	return sandbox or db
end

function A.sandboxed()
	return sandbox~=nil
end

local function deepCopy(value)
	if type(value)~="table"then
		return value
	end
	local copy={}
	for key,inner in pairs(value)do
		copy[key]=deepCopy(inner)
	end
	return copy
end

function A.storeReplaced()
	local steps={
		{"notes","resetNotesPane"},
		{"notesindex","dropNotesIndex"},
		{"size","dropHeldStoredSize"},
		{"aftermatch","dropAfterMatch"},
		{"finder","dropFinderWalk"},
		{"folds","dropHeldSessionFolds"},
		{"lobby","dropLobbyClaims"},
		{"compare","dropCompareSet"},
		{"window","refreshWindow"},
		{"overlay","overlayRepaint","stored","replaced"},
		{"store","refreshStoreWindow"},
	}
	for _,step in ipairs(steps)do
		local run=A[step[2]]
		if type(run)=="function"then
			local ran,err=pcall(run,step[3],step[4])
			if not ran then
				A.noteError(err,"replaced."..step[1])
			end
		end
	end
end

function A.recordStored(source)
	source=tostring(source or"store")
	if type(A.finderRecordStored)=="function"then
		local repainted,err=pcall(A.finderRecordStored)
		if not repainted then
			A.noteError(err,source..".finder")
		end
	end
	if type(A.overlayRecordStored)=="function"then
		local repainted,err=pcall(A.overlayRecordStored)
		if not repainted then
			A.noteError(err,source..".overlay")
		end
	end
	if type(A.storeWindowShown)=="function"and A.storeWindowShown()then
		local repainted,err=pcall(A.refreshStoreWindow)
		if not repainted then
			A.noteError(err,source..".store")
		end
	end
end

function A.startSandbox()
	local ui=deepCopy(type(db)=="table"and type(db.ui)=="table"and db.ui or{})
	sandbox={
		schema=A.schema,matches={},nextMatchId=1,nextFixtureId=1,dropped={},
		dropEvents={},incomplete={},nextIncompleteId=1,players={},ui=ui,
		arenaMapRefiled=true,
	}
	A.storeReplaced()
	return sandbox
end

function A.endSandbox()
	local was=sandbox~=nil
	sandbox=nil
	if was then
		A.storeReplaced()
	end
	return was
end

function A.savedDB()
	return db
end

function A.orderByCompletion(list)
	local keyed={}
	local carried=nil
	for i=1,#list do
		local record=list[i]
		if type(record)=="table"and type(record.completedEpoch)=="number"then
			carried=record.completedEpoch
		end
		keyed[i]={record=record,at=carried,index=i}
	end

	table.sort(keyed,function(a,b)
		if a.at~=b.at then
			if a.at==nil then
				return true
			end
			if b.at==nil then
				return false
			end
			return a.at<b.at
		end
		return a.index<b.index
	end)

	local moved=0
	for i=1,#keyed do
		local record=keyed[i].record
		if list[i]~=record then
			moved=moved+1
		end
		list[i]=record
	end
	return moved
end

function A.matchIdRank(id)
	if type(id)=="number"then
		return 1,id
	end
	if type(id)=="string"then
		local n=tonumber(id:match("^F(%d+)$"))
		if n then
			return 0,n
		end
	end
	return 0,0
end

function A.newerMatchId(a,b)
	local ak,an=A.matchIdRank(a)
	local bk,bn=A.matchIdRank(b)
	if ak~=bk then
		return ak>bk
	end
	return an>bn
end

local onDiskAtLoad=setmetatable({},{__mode="k"})

function A.pendingMatches()
	if db==nil or type(db.matches)~="table"then
		return 0
	end
	local pending=0
	for i=1,#db.matches do
		if not onDiskAtLoad[db.matches[i]]then
			pending=pending+1
		end
	end
	return pending
end

local MAX_DROP_EVENTS=50

function A.roundList(record)
	if type(record)~="table"or type(record.rounds)~="table"then
		return nil
	end
	return record.rounds
end

function A.dropContext(record,extra)
	local context={}
	if type(record)=="table"then
		context.openedState=record.openedState
		local rounds=A.roundList(record)
		if rounds then
			context.rounds=#rounds
		end
		if type(record.surface)=="table"then
			context.format=record.surface.format
		end
		if type(record.fallback)=="table"and record.fallback.kept then
			context.fallbackRows=record.fallback.kept
		end
	end
	for key,value in pairs(extra or{})do
		context[key]=value
	end
	return context
end

function A.drop(reason,context)
	if not db then
		return
	end
	local counters=db.dropped
	if type(counters)=="table"then
		local count=counters[reason]
		if count==nil or type(count)=="number"then
			counters[reason]=(count or 0)+1
		end
	end

	local event={reason=reason}

	local ok,stamp=pcall(A.stamp)
	if ok then
		event.at=stamp
	end

	for key,value in pairs(context or{})do
		event[key]=value
	end

	local events=db.dropEvents
	local evicted
	if type(events)=="table"then
		events[#events+1]=event
		if#events>MAX_DROP_EVENTS then
			table.remove(events,1)
			evicted=true
		end
	end

	local offOk,off=pcall(A.unitFigure,context and context.readAt)

	pcall(A.trace,"drop",{
		reason=reason,
		state=context and context.openedState,
		rounds=context and context.rounds,
		format=context and context.format,
		rows=context and context.rows,
		off=offOk and off or nil,
		attempt=context and context.attempts,
		evicted=evicted,
	})
end

local MAX_INCOMPLETE=200

function A.noteIncomplete(reason,record)
	if not db then
		return nil
	end
	if type(record)~="table"then
		A.trace("incomplete",{source=reason,reason="no-record"})
		return nil
	end

	local entry={reason=reason}

	if type(db.nextIncompleteId)=="number"then
		entry.id=db.nextIncompleteId
		db.nextIncompleteId=db.nextIncompleteId+1
	end

	local ok,stamp=pcall(A.stamp)
	if ok then
		entry.endedAt=stamp
	end

	entry.openedAt=record.openedAt
	entry.openedState=record.openedState
	local rounds=A.roundList(record)
	if rounds then
		entry.rounds=#rounds
	end

	local opener=record.character
	if type(opener)=="string"and A.canRead(opener)and opener~=""then
		entry.character=opener
	end

	if record.openRated~=nil then
		entry.rated=record.openRated
	end
	if record.openMap then
		entry.map=record.openMap
	end
	if type(record.liveFormat)=="string"then
		entry.surfaceFormat=record.liveFormat
	end

	if reason=="left"and type(record.openedEpoch)=="number"then
		entry.seconds=time()-record.openedEpoch
	end

	local list=db.incomplete
	if type(list)~="table"then
		A.trace("incomplete",{source=reason,reason="no-list"})
		return nil
	end
	list[#list+1]=entry
	local evicted
	if#list>MAX_INCOMPLETE then
		table.remove(list,1)
		evicted=true
	end

	A.trace("incomplete",{
		source=reason,
		reason="stored",
		id=entry.id,
		rounds=entry.rounds,
		rated=entry.rated,
		format=entry.surfaceFormat,
		evicted=evicted,
	})

	return entry
end

function A.assignIncompleteIds(list)
	local nextId=1
	for i=1,#list do
		local entry=list[i]
		if type(entry)=="table"and type(entry.id)=="number"and entry.id>=nextId then
			nextId=entry.id+1
		end
	end
	for i=1,#list do
		local entry=list[i]
		if type(entry)=="table"and entry.id==nil then
			entry.id=nextId
			nextId=nextId+1
		end
	end
	return nextId
end

local loadRepairs={}

function A.loadRepairs()
	return loadRepairs
end

local function keepOriginal(store,field,held)
	if type(store.repaired)~="table"then
		store.repaired={}
	end
	if store.repaired[field]==nil then
		store.repaired[field]=held
	end
end

local function repairField(store,repairs,field,wanted,fresh)
	local held=store[field]
	if held==nil or type(held)==wanted then
		return
	end
	keepOriginal(store,field,held)
	store[field]=fresh
	repairs[#repairs+1]={field=field,foundType=type(held)}
end

local function repairEntries(store,repairs,field)
	local list=store[field]
	if type(list)~="table"then
		return
	end
	for i=#list,1,-1 do
		local entry=list[i]
		if entry~=nil and type(entry)~="table"then
			if type(store.repaired)~="table"then
				store.repaired={}
			end
			local kept=store.repaired.entries
			if type(kept)~="table"then
				kept={}
				store.repaired.entries=kept
			end
			kept[#kept+1]={field=field,position=i,value=entry}
			table.remove(list,i)
			repairs[#repairs+1]={field=field,foundType=type(entry),position=i}
		end
	end
end

local function raiseCounter(store,repairs,field,largest)
	local wanted=math.floor(largest)+1
	local held=store[field]
	if type(held)=="number"and held>=wanted then
		return
	end
	if held==nil and largest==0 then
		store[field]=wanted
		return
	end
	if held~=nil and type(held)~="number"then
		keepOriginal(store,field,held)
	end
	store[field]=wanted
	repairs[#repairs+1]={field=field,foundType=type(held)}
end

local function repairNextIds(store,repairs)
	local largestMatch,largestFixture=0,0
	if type(store.matches)=="table"then
		for _,match in ipairs(store.matches)do
			local id=type(match)=="table"and match.id or nil
			if type(id)=="number"and id>largestMatch then
				largestMatch=id
			elseif type(id)=="string"then
				local n=tonumber(id:match("^F(%d+)$"))
				if n and n>largestFixture then
					largestFixture=n
				end
			end
		end
	end
	raiseCounter(store,repairs,"nextMatchId",largestMatch)
	raiseCounter(store,repairs,"nextFixtureId",largestFixture)

	local largestIncomplete=0
	if type(store.incomplete)=="table"then
		if store.nextIncompleteId==nil then
			store.nextIncompleteId=A.assignIncompleteIds(store.incomplete)
		end
		for _,entry in ipairs(store.incomplete)do
			if type(entry)=="table"and type(entry.id)=="number"and entry.id>largestIncomplete then
				largestIncomplete=entry.id
			end
		end
	end
	raiseCounter(store,repairs,"nextIncompleteId",largestIncomplete)
end

function A.repairStore(store)
	local repairs={}
	if type(store)~="table"then
		return repairs
	end
	repairField(store,repairs,"matches","table",{})
	repairEntries(store,repairs,"matches")
	repairField(store,repairs,"incomplete","table",{})
	repairEntries(store,repairs,"incomplete")
	repairField(store,repairs,"dropped","table",{})
	repairField(store,repairs,"dropEvents","table",{})
	repairEntries(store,repairs,"dropEvents")
	repairField(store,repairs,"players","table",{})
	repairField(store,repairs,"ui","table",{})
	repairField(store,repairs,"characters","table",{})
	repairField(store,repairs,"notes","table",{})
	repairField(store,repairs,"seasons","table",{})
	repairField(store,repairs,"pruneLog","table",{})
	repairEntries(store,repairs,"seasons")
	repairNextIds(store,repairs)
	for i=1,#repairs do
		local repair=repairs[i]
		if repair.field=="players"and repair.position==nil then
			store.playerIndexVersion=nil
		end
	end
	return repairs
end

local function initDB()
	WowPvpHistoryDB=WowPvpHistoryDB or{}
	db=WowPvpHistoryDB

	if type(db.schema)~="number"or db.schema<A.schema then
		db.schema=A.schema
	end
	loadRepairs=A.repairStore(db)
	db.matches=db.matches or{}
	for i=1,#db.matches do
		local record=db.matches[i]
		if type(record)=="table"then
			onDiskAtLoad[record]=true
		end
	end
	db.nextMatchId=db.nextMatchId or 1
	db.nextFixtureId=db.nextFixtureId or 1
	db.dropped=db.dropped or{}
	db.dropEvents=db.dropEvents or{}
	db.incomplete=db.incomplete or{}
	if db.nextIncompleteId==nil then
		db.nextIncompleteId=A.assignIncompleteIds(db.incomplete)
	end
	db.players=db.players or{}
	db.ui=db.ui or{}
end

function A.byteCut(text,bound)
	if#text<=bound then
		return text
	end
	local stop=bound
	while stop>0 do
		local following=text:byte(stop+1)
		if following==nil or following<128 or following>191 then
			break
		end
		stop=stop-1
	end
	return text:sub(1,stop)
end

local function joinTrimmed(parts,glue)
	if type(parts)~="table"then
		return nil
	end
	local kept={}
	for i=1,#parts do
		local piece=parts[i]
		if type(piece)=="string"then
			piece=piece:gsub("^%s+",""):gsub("%s+$","")
			if piece~=""then
				kept[#kept+1]=piece
			end
		end
	end
	if#kept==0 then
		return nil
	end
	return table.concat(kept,glue)
end

function A.joinSentences(parts)
	return joinTrimmed(parts," ")
end

function A.joinAnd(parts)
	return joinTrimmed(parts," and ")
end

function A.chatCollector()
	local said={}
	return said,function(line)
		said[#said+1]=line
		A.say(line)
	end
end

function A.say(msg,register)
	local prefix=A.chatPrefix and A.chatPrefix()or"|cff00ff00PvPHistory:|r "
	local text=tostring(msg)

	if register~=nil and type(A.registerEscape)=="function"then
		local ok,escape=pcall(A.registerEscape,register)
		if ok and type(escape)=="string"then
			text=escape..text.."|r"
		end
	end

	print(prefix..text)
end

function A.stamp()
	return date("%Y-%m-%d %H:%M:%S")
end

function A.stampAt(epoch)
	if type(epoch)~="number"then
		return nil
	end
	local ok,text=pcall(date,"%Y-%m-%d %H:%M:%S",epoch)
	if ok and type(text)=="string"then
		return text
	end
	return nil
end

function A.stampEpoch(text)
	if type(text)~="string"then
		return nil
	end
	local y,mo,d,h,mi,s=text:match("^(%d%d%d%d)%-(%d%d)%-(%d%d) (%d%d):(%d%d):(%d%d)$")
	if y==nil then
		return nil
	end
	local ok,epoch=pcall(time,{year=tonumber(y)or 0,month=tonumber(mo)or 0,
		day=tonumber(d)or 0,hour=tonumber(h)or 0,min=tonumber(mi)or 0,sec=tonumber(s)or 0})
	if ok and type(epoch)=="number"then
		return epoch
	end
	return nil
end

function A.recordEpoch(record)
	if type(record)~="table"then
		return nil
	end
	if type(record.completedEpoch)=="number"then
		return record.completedEpoch
	end
	if record.format~=nil then
		return nil
	end
	if record.reason=="abandoned"then
		if type(record.openedEpoch)=="number"then
			return record.openedEpoch
		end
		if type(record.openedAt)=="string"then
			return A.stampEpoch(record.openedAt)
		end
		return nil
	end
	if type(record.endedAt)=="string"then
		return A.stampEpoch(record.endedAt)
	end
	return nil
end

function A.recordSince(record,bound)
	if bound==nil then
		return true
	end
	local at=A.recordEpoch(record)
	return at~=nil and at>=bound
end

function A.lastErrorState(store)
	local ring=nil
	if type(A.lastRingError)=="function"then
		local ok,held=pcall(A.lastRingError)
		if ok and type(held)=="table"then
			ring=held
		end
	end

	local held=type(store)=="table"and store.lastError or nil
	if held~=nil then
		local state={text=tostring(held),when=store.lastErrorAt,fromRing=false}
		if ring and ring.rep>1 and state.when~=nil and ring.closedAt==state.when then
			state.rep=ring.rep
			state.closedAt=ring.closedAt
		end
		return state
	end

	if ring then
		return{
			text=tostring(ring.err),
			when=ring.at,
			rep=ring.rep>1 and ring.rep or nil,
			closedAt=ring.rep>1 and ring.closedAt or nil,
			fromRing=true,
		}
	end
	return nil
end

function A.lastErrorWhen(state)
	if type(state)~="table"then
		return nil
	end
	local when=state.when and("stored "..tostring(state.when))
		or"stored before this version recorded when"
	if state.rep then
		when=("%s, %d times to %s"):format(when,state.rep,tostring(state.closedAt))
	end
	return when
end

function A.lastErrorLines(store)
	local state=A.lastErrorState(store)
	if not state then
		return nil
	end
	local forget=state.fromRing
		and"/pvph debug clear error forgets it"
		or"/pvph error clear forgets it"
	return{
		("last error, %s:"):format(A.lastErrorWhen(state)),
		"  "..state.text,
		"it is what threw at that moment, not what is wrong now. "..forget,
	}
end

function A.noteError(err,where,handed)
	pcall(A.trace,"error",{err=err,source=where,handed=handed},"error")

	if not db then
		return false
	end

	db.lastError=tostring(err)
	local ok,at=pcall(A.stamp)
	db.lastErrorAt=ok and at or nil
	return true
end

function A.clearError()
	if not db then
		return nil
	end
	local held,at=db.lastError,db.lastErrorAt
	db.lastError=nil
	db.lastErrorAt=nil
	return held,at
end

local frame=CreateFrame("Frame")
local handlers={}
local refusedEvents={}
local refusalsTraced=false

function A.noteRefusedEvent(event)
	for i=1,#refusedEvents do
		if refusedEvents[i]==event then
			return
		end
	end
	refusedEvents[#refusedEvents+1]=event
	if refusalsTraced and type(A.trace)=="function"then
		A.trace("event-refused",{clientEvent=event})
	end
end

function A.traceRefusedEvents()
	refusalsTraced=true
	if type(A.trace)~="function"then
		return
	end
	for i=1,#refusedEvents do
		A.trace("event-refused",{clientEvent=refusedEvents[i]})
	end
end

function A.on(event,fn)
	local list=handlers[event]
	if not list then
		list={}
		handlers[event]=list
		if not pcall(frame.RegisterEvent,frame,event)then
			A.noteRefusedEvent(event)
		end
	end
	list[#list+1]=fn
end

function A.refusedEvents()
	return refusedEvents
end

local MATCH_EVENTS={
	PVP_MATCH_STATE_CHANGED=true,
	PVP_MATCH_COMPLETE=true,
	PVP_MATCH_INACTIVE=true,
	PVP_MATCH_ACTIVE=true,
	PLAYER_ENTERING_WORLD=true,
}

frame:SetScript("OnEvent",function(_,event,...)
	local list=handlers[event]
	if not list then
		return
	end
	for i=1,#list do
		local ok,err=pcall(list[i],event,...)
		if not ok then
			local open=type(db)=="table"and db.active~=nil
			if open or MATCH_EVENTS[event]then
				local read,context=pcall(A.dropContext,db and db.active)
				if not read then
					context=nil
				end
				A.drop("handler-error",context)
			end
			A.noteError(err,tostring(event))
			A.say("handler error on "..tostring(event)..": "..tostring(err))
		end
	end
end)

function A.wholeOffset(value)
	if type(value)~="number"or value~=value or value==math.huge or value==-math.huge then
		return nil
	end
	return math.floor(value+0.5)
end

function A.storedPosition(key)
	local store=A.db()
	if not store or type(store.ui)~="table"then
		return nil
	end
	local held=store.ui[key]
	if type(held)~="table"or type(held.point)~="string"then
		return nil
	end
	local x,y=A.wholeOffset(held.x),A.wholeOffset(held.y)
	if x==nil or y==nil then
		return nil
	end
	return{point=held.point,x=x,y=y}
end

function A.storePosition(key,geometry,defaults)
	local store=A.db()
	if not store then
		return false
	end
	store.ui=store.ui or{}
	local point=type(geometry)=="table"and geometry.point or nil
	local x=type(geometry)=="table"and A.wholeOffset(geometry.x)or nil
	local y=type(geometry)=="table"and A.wholeOffset(geometry.y)or nil
	local defaultPoint,defaultX,defaultY=defaults()
	if type(point)~="string"or x==nil or y==nil
		or(point==defaultPoint and x==A.wholeOffset(defaultX)and y==A.wholeOffset(defaultY))
	then
		store.ui[key]=nil
		return true
	end
	store.ui[key]={point=point,x=x,y=y}
	return true
end

function A.guardedCall(fn,...)
	if type(fn)~="function"then
		return nil
	end
	local ok,res=pcall(fn,...)
	if not ok then
		return nil
	end
	return res
end

function A.inCombatLockdown()
	if type(InCombatLockdown)~="function"then
		return false
	end
	local ok,value=pcall(InCombatLockdown)
	return ok and value==true
end

function A.pvpCall(name,...)
	return A.guardedCall(C_PvP and C_PvP[name],...)
end

local stateNames

function A.stateName(value)
	if type(value)~="number"then
		return nil
	end
	if not stateNames then
		stateNames={}
		if Enum and Enum.PvPMatchState then
			pcall(function()
				for k,v in pairs(Enum.PvPMatchState)do
					if type(k)=="string"and type(v)=="number"then
						stateNames[v]=k
					end
				end
			end)
		end
	end
	return stateNames[value]
end

function A.matchState()
	local state=A.pvpCall("GetActiveMatchState")
	if not A.canRead(state)then
		return nil
	end
	return state
end

function A.selfFaction()
	if type(GetBattlefieldArenaFaction)~="function"then
		return nil
	end
	local ok,res=pcall(GetBattlefieldArenaFaction)
	if ok then
		return res
	end
	return nil
end

local FACTION_INDEX={Horde=0,Alliance=1}

function A.playerFaction()
	return A.unitFaction("player")
end

function A.unitFaction(token)
	if type(UnitFactionGroup)~="function"then
		return nil
	end
	local ok,group=pcall(UnitFactionGroup,token)
	if not ok or not A.canRead(group)or type(group)~="string"then
		return nil
	end
	return FACTION_INDEX[group]
end

function A.ownGuid()
	if type(UnitGUID)~="function"then
		return nil
	end
	local ok,guid=pcall(UnitGUID,"player")
	if ok and A.canRead(guid)and type(guid)=="string"and guid~=""then
		return guid
	end
	return nil
end

function A.isOwnCharacter(guid)
	if type(guid)~="string"or not A.canRead(guid)or guid==""then
		return false
	end
	if guid==A.ownGuid()then
		return true
	end

	local store=A.db()
	if not store or type(store.characters)~="table"then
		return false
	end
	return store.characters[guid]~=nil
end

function A.isBotGuid(guid)
	if type(guid)~="string"then
		return false
	end
	local fields=0
	for _ in guid:gmatch("[^%-]+")do
		fields=fields+1
	end
	return fields>3
end

function A.botCount(entries)
	if type(entries)~="table"or#entries==0 then
		return 0,false
	end
	local bots=0
	for i=1,#entries do
		local entry=entries[i]
		if type(entry)=="table"and A.isBotGuid(entry.guid)then
			bots=bots+1
		end
	end
	return bots,bots==#entries
end

function A.ownRealm()
	if type(GetNormalizedRealmName)~="function"then
		return nil
	end
	local ok,realm=pcall(GetNormalizedRealmName)
	if ok and type(realm)=="string"and A.canRead(realm)and realm~=""then
		return realm
	end
	return nil
end

function A.pvpRestriction()
	local restricted=C_RestrictedActions
	if not(restricted and restricted.GetAddOnRestrictionState)then
		return nil
	end
	local scope=Enum and Enum.AddOnRestrictionType and Enum.AddOnRestrictionType.PvPMatch
	if type(scope)~="number"then
		return nil
	end
	local ok,state=pcall(restricted.GetAddOnRestrictionState,scope)
	if ok and A.canRead(state)then
		return state
	end
	return nil
end

function A.pvpRestricted()
	local state=A.pvpRestriction()
	if not A.canRead(state)then
		return false,nil
	end
	if type(state)~="number"then
		return false,state
	end

	local levels=Enum and Enum.AddOnRestrictionState
	local activating=levels and levels.Activating
	local active=levels and levels.Active
	if type(activating)~="number"then
		activating=1
	end
	if type(active)~="number"then
		active=2
	end

	return state==activating or state==active,state
end

A.on("ADDON_LOADED",function(_,name)
	if name==ADDON then
		initDB()
	end
end)
