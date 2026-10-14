-- WowPvpHistory 0.68.21
-- Author:  Xenu-Sentinels
-- Project: wow-pvp-history
--          https://github.com/xenulive/wow-pvp-history
-- License: MIT, see LICENSE
local _,A=...
local WORLD_GAP_MINUTES=15
local GAP_SECONDS=WORLD_GAP_MINUTES*60
local baseline
local current,currentIndex
local reported=false
local function contained(fn,...)
local ok,err=pcall(fn,...)
if ok then
return
end
A.noteError(err,"world")
if not reported then
reported=true
A.say("world PvP recording stopped: "..tostring(err))
end
end
local function readable(fn,...)
if type(fn)~="function"then
return nil
end
local ok,res=pcall(fn,...)
if not ok or not A.canRead(res)then
return nil
end
return res
end
local function readCounter()
local kills=readable(GetPVPSessionStats)
if type(kills)~="number"then
return nil
end
return kills
end
local function inInstance()
return readable(IsInInstance)==true
end
local function pvpFlag(name)
local pvp=C_PvP
return type(pvp)=="table"and readable(pvp[name])==true
end
local function restricted()
return(A.pvpRestricted())
end
local function refusal()
if inInstance()then
return"instance"
end
if pvpFlag("IsMatchActive")then
return"match"
end
if restricted()then
return"restricted"
end
if not pvpFlag("IsWarModeActive")then
return"warmode"
end
return nil
end
local function openRecord(db)
db=db or A.db()
if not(db and type(db.matches)=="table")then
current,currentIndex=nil,nil
return nil
end
if current and currentIndex and db.matches[currentIndex]==current and current.worldOpen then
return current
end
current,currentIndex=nil,nil
for i=#db.matches,1,-1 do
local record=db.matches[i]
if type(record)=="table"and record.format=="world"and record.worldOpen then
current,currentIndex=record,i
return record
end
end
return nil
end
local function close(record,reason,db)
record.worldOpen=nil
if type(record.completedEpoch)=="number"and type(record.openedEpoch)=="number"then
record.duration=record.completedEpoch-record.openedEpoch
end
if record==current then
current,currentIndex=nil,nil
end
local indexed,folded=pcall(A.indexMatch,record,db)
if not indexed then
A.noteError(folded,"world-index")
end
local merged,err=pcall(A.mergeNamedPlayers,record,db)
if not merged then
A.noteError(err,"world-merge")
end
A.trace("world",{id=record.id,state="close",reason=reason,n=record.kills,d=record.deaths})
baseline=readCounter()
end
local function open(db,now)
local record={
format="world",
rated=false,
openedEpoch=now,
completedEpoch=now,
duration=0,
warMode=true,
kills=0,
deaths=0,
worldOpen=true,
}
local stamped,at=pcall(A.stamp)
if stamped then
record.openedAt=at
record.completedAt=at
end
local map=A.readMap()
if map then
record.map=map
end
local participants,kept={},0
local selfGuid=A.ownGuid()
if selfGuid then
record.character=selfGuid
local ok,name=pcall(UnitName,"player")
participants[selfGuid]={
name=(ok and A.canRead(name)and type(name)=="string"and name~="")and name or nil,
side="with",
}
kept=1
end
record.participants=participants
record.participantCount=kept
record.id=db.nextMatchId
db.nextMatchId=db.nextMatchId+1
db.matches[#db.matches+1]=record
current,currentIndex=record,#db.matches
A.recordStored("world")
pcall(A.noteCanary)
return record
end
local function closeIfStale(now)
local db=A.savedDB()
local record=openRecord(db)
if record and type(record.completedEpoch)=="number"and now-record.completedEpoch>=GAP_SECONDS then
close(record,"gap",db)
return true
end
return false
end
local function armGap()
local after=C_Timer and C_Timer.After
if type(after)~="function"then
return
end
pcall(after,GAP_SECONDS+1,function()
contained(closeIfStale,time())
end)
end
local function touch(record,now)
record.completedEpoch=now
local stamped,at=pcall(A.stamp)
if stamped then
record.completedAt=at
end
if type(record.openedEpoch)=="number"then
record.duration=now-record.openedEpoch
end
end
local function recordFor(now)
if A.sandboxed()and A.endSandbox()then
A.trace("sandbox",{state="ended",reason="world"},"data")
end
local db=A.db()
if not(db and type(db.matches)=="table")then
return nil
end
closeIfStale(now)
local record=openRecord()
if record then
return record,false
end
return open(db,now),true
end
local function count(kills,deaths,delta)
local now=time()
local db=A.db()
if not(db and type(db.matches)=="table")then
A.trace("world",{state="refused",reason="no-database"})
return
end
local record,opened=recordFor(now)
if not record then
return
end
record.kills=(record.kills or 0)+kills
record.deaths=(record.deaths or 0)+deaths
touch(record,now)
A.trace("world",{id=record.id,state=opened and"open"or"count",n=record.kills,
d=record.deaths,honorDelta=delta})
armGap()
end
local NAME_RETRIES=4
local RETRY_SECONDS=0.5
local VICTIM_TOKENS={"target","mouseover","focus"}
local function readableGuid(value)
if type(value)=="string"and A.canRead(value)and value~=""then
return value
end
return nil
end
local function guidFields(guid)
local fields=0
for _ in guid:gmatch("[^%-]+")do
fields=fields+1
end
return fields
end
local function victimToken(guid)
for i=1,#VICTIM_TOKENS do
local token=VICTIM_TOKENS[i]
if readableGuid(readable(UnitGUID,token))==guid then
return token,token
end
end
local plates=A.nameplateTokens()
for i=1,#plates do
if readableGuid(readable(UnitGUID,plates[i]))==guid then
return plates[i],"nameplate"
end
end
return nil
end
local function unitString(value)
if type(value)=="string"and A.canRead(value)and value~=""then
return value
end
return nil
end
local function readTraits(row,guid)
if row.class~=nil and row.classToken~=nil and row.race~=nil and row.faction~=nil then
return nil
end
local token,word=victimToken(guid)
if not token then
return nil
end
if type(UnitClass)=="function"then
local ok,className,classToken=pcall(UnitClass,token)
if ok then
row.class=row.class or unitString(className)
row.classToken=row.classToken or unitString(classToken)
end
end
if row.race==nil and type(UnitRace)=="function"then
local ok,raceName=pcall(UnitRace,token)
if ok then
row.race=unitString(raceName)
end
end
if row.faction==nil then
row.faction=A.unitFaction(token)
end
return word
end
local function pendingRow(record,guid)
if openRecord(A.savedDB())~=record or type(record.participants)~="table"then
return nil
end
local row=record.participants[guid]
return type(row)=="table"and row or nil
end
local function traceKill(record,state,source,tries,row,tok)
A.trace("worldkill",{id=record.id,state=state,source=source,tries=tries,
n=record.participantCount,cls=row.class~=nil,tok=tok})
end
local function resolve(record,guid,tries,tok)
local row=pendingRow(record,guid)
if not row then
A.trace("worldkill",{id=record.id,state="refused",reason="closed",tries=tries})
return
end
tries=tries+1
tok=readTraits(row,guid)or tok
local name=A.unitNameFromGuid(guid)
if name then
row.name=name
traceKill(record,"named","guid",tries,row,tok)
return
end
local after=C_Timer and C_Timer.After
if tries<=NAME_RETRIES and type(after)=="function"then
local scheduled=pcall(after,RETRY_SECONDS,function()
contained(resolve,record,guid,tries,tok)
end)
if scheduled then
return
end
end
local token,word=victimToken(guid)
local names=token and A.unitNames(token)or{}
if names[1]then
row.name=names[#names]
traceKill(record,"named",word,tries,row,tok)
return
end
traceKill(record,"nameless",nil,tries,row,tok)
end
local function onPartyKill(attackerGuid,targetGuid)
local why=refusal()
if why then
A.trace("worldkill",{state="refused",reason=why})
return
end
local attacker=readableGuid(attackerGuid)
if not attacker then
A.trace("worldkill",{state="refused",reason="secret-attacker"})
return
end
local selfGuid=A.ownGuid()
if attacker~=selfGuid then
A.trace("worldkill",{state="refused",reason="other-attacker"})
return
end
local target=readableGuid(targetGuid)
if not target then
A.trace("worldkill",{state="refused",reason="secret-target"})
return
end
if target:sub(1,7)~="Player-"or guidFields(target)<3 then
A.trace("worldkill",{state="refused",reason="not-player"})
return
end
if A.isBotGuid(target)then
A.trace("worldkill",{state="refused",reason="bot"})
return
end
local now=time()
local record,opened=recordFor(now)
if not record then
A.trace("worldkill",{state="refused",reason="no-database"})
return
end
touch(record,now)
local participants=record.participants
if type(participants)~="table"then
participants={}
record.participants=participants
end
local row=participants[target]
if type(row)=="table"then
row.deaths=(row.deaths or 0)+1
else
row={side="against",deaths=1}
participants[target]=row
end
local own=participants[selfGuid]
if type(own)~="table"then
own={side="with"}
participants[selfGuid]=own
end
own.killingBlows=(own.killingBlows or 0)+1
local kept=0
for _ in pairs(participants)do
kept=kept+1
end
record.participantCount=kept
if opened then
A.trace("world",{id=record.id,state="open",source="partykill",n=record.kills,
d=record.deaths})
end
armGap()
if row.name~=nil then
traceKill(record,"named",nil,0,row,readTraits(row,target))
return
end
resolve(record,target,0,nil)
end
local function onKillsChanged()
local reading=readCounter()
if reading==nil or baseline==nil then
baseline=reading
A.trace("world",{state="refused",reason="no-baseline"})
return
end
local delta=reading-baseline
if delta==0 then
return
end
baseline=reading
if delta<0 then
A.trace("world",{state="refused",reason="rebased",honorDelta=delta})
return
end
local why=refusal()
if why then
A.trace("world",{state="refused",reason=why,honorDelta=delta})
return
end
count(delta,0,delta)
end
local function onDead()
local why=refusal()
if why then
A.trace("world",{state="refused",reason=why,d=1})
return
end
count(0,1,nil)
end
local function onEnteringWorld()
if inInstance()then
local db=A.savedDB()
local record=openRecord(db)
if record then
close(record,"instance",db)
end
end
baseline=readCounter()
if baseline==nil then
A.trace("world",{state="baseline",source="entering",reason="unread"})
else
A.trace("world",{state="baseline",source="entering",baseline=baseline})
end
end
local function onLogin()
local db=A.savedDB()
if not(db and type(db.matches)=="table")then
return
end
current,currentIndex=nil,nil
for i=1,#db.matches do
local record=db.matches[i]
if type(record)=="table"and record.format=="world"and record.worldOpen then
close(record,"login",db)
end
end
end
function A.closeWorldSession(reason)
local db=A.savedDB()
local record=openRecord(db)
if not record then
return false
end
close(record,reason,db)
return true
end
local function onLogout()
A.closeWorldSession("logout")
end
A.on("PLAYER_PVP_KILLS_CHANGED",function()
contained(onKillsChanged)
end)
A.on("PARTY_KILL",function(_,attackerGuid,targetGuid)
contained(onPartyKill,attackerGuid,targetGuid)
end)
A.on("PLAYER_DEAD",function()
contained(onDead)
end)
A.on("PLAYER_ENTERING_WORLD",function()
contained(onEnteringWorld)
end)
A.on("PLAYER_LOGIN",function()
contained(onLogin)
end)
A.on("PLAYER_LOGOUT",function()
contained(onLogout)
end)
