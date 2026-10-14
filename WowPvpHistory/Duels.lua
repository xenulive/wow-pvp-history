-- WowPvpHistory 0.68.22
-- Author:  Xenu-Sentinels
-- Project: wow-pvp-history
--          https://github.com/xenulive/wow-pvp-history
-- License: MIT, see LICENSE
local _,A=...
local STORE_DELAY=1.0
local REQUEST_STALE_SECONDS=15*60
local OUTCOME_STALE_SECONDS=30
local TOKENS={"target","mouseover","focus"}
local request
local outcome
local reported=false
local refusedLines=0
function A.duelsEnabled()
local db=A.db()
if not db then
return false
end
if type(db.ui)~="table"then
db.ui={}
end
return db.ui.duels~=false
end
function A.setDuels(enabled)
local db=A.db()
if not db then
return false
end
if type(db.ui)~="table"then
db.ui={}
end
if enabled==false then
db.ui.duels=false
else
db.ui.duels=nil
end
if A.notifyDuelsSetting then
A.notifyDuelsSetting()
end
return true
end
local function contained(fn,...)
local ok,err=pcall(fn,...)
if ok then
return
end
A.noteError(err,"duel-line")
if not reported then
reported=true
A.say("duel recording stopped: "..tostring(err)..". /pvph duel off silences it")
end
end
local function guarded(fn,...)
if type(fn)~="function"then
return nil
end
local ok,res=pcall(fn,...)
if not ok then
return nil
end
return res
end
local function restricted()
return(A.pvpRestricted())
end
local MAGIC="([%^%$%(%)%%%.%[%]%*%+%-%?])"
local function escape(text)
return(text:gsub(MAGIC,"%%%1"))
end
local function build(text)
if type(text)~="string"or text==""then
return nil
end
local parts,args={},{}
local pos=1
while true do
local from,to,index=text:find("%%(%d)%$s",pos)
if not from then
break
end
parts[#parts+1]=escape(text:sub(pos,from-1))
parts[#parts+1]="(.+)"
args[#args+1]=tonumber(index)
pos=to+1
end
if#args~=2 then
return nil
end
if not((args[1]==1 and args[2]==2)or(args[1]==2 and args[2]==1))then
return nil
end
parts[#parts+1]=escape(text:sub(pos))
local winner=(args[1]==1)and 1 or 2
return{pattern="^"..table.concat(parts).."$",winner=winner,loser=3-winner}
end
local built
local function patterns()
if built then
return built
end
built={}
local sources={
{kind="knockout",text=DUEL_WINNER_KNOCKOUT},
{kind="retreat",text=DUEL_WINNER_RETREAT},
}
for i=1,#sources do
local made=build(sources[i].text)
if made then
made.kind=sources[i].kind
built[#built+1]=made
end
end
return built
end
local function isNamed(names,wanted)
for i=1,#names do
if names[i]==wanted then
return true
end
end
return false
end
local function tokenMatches(token,wanted)
local isPlayer=guarded(UnitIsPlayer,token)
if not(A.canRead(isPlayer)and isPlayer==true)then
return false
end
return isNamed(A.unitNames(token),wanted)
end
local function resolveOpponent(wanted)
if type(wanted)~="string"or wanted==""then
return nil,"no name"
end
if restricted()then
return nil,"restricted"
end
local tokens={}
for i=1,#TOKENS do
tokens[#tokens+1]=TOKENS[i]
end
local plates=A.nameplateTokens()
for i=1,#plates do
tokens[#tokens+1]=plates[i]
end
for i=1,#tokens do
local token=tokens[i]
if tokenMatches(token,wanted)then
local guid=guarded(UnitGUID,token)
if type(guid)=="string"and A.canRead(guid)then
local source=(i<=#TOKENS)and token or"nameplate"
return guid,source
end
end
end
return nil,"unmatched"
end
local function storeDuel(opened,result,ended)
local db=A.db()
if not(db and A.duelsEnabled())then
A.trace("duel",{state="refused",reason=db and"switch"or"no-database"})
return
end
if not result then
A.trace("duel",{state="refused",reason="no-winner-line"})
return
end
if A.sandboxed()and A.endSandbox()then
A.trace("sandbox",{state="ended",reason="duel"},"data")
db=A.db()
if not db then
A.trace("duel",{state="refused",reason="no-database"})
return
end
end
local record={
format="duel",
rated=false,
completedEpoch=ended,
}
local stamped,at=pcall(A.stamp)
if stamped then
record.completedAt=at
end
if opened then
record.openedEpoch=opened.epoch
record.openedAt=opened.at
record.duelToTheDeath=opened.toTheDeath or nil
if type(opened.epoch)=="number"then
record.duration=ended-opened.epoch
end
end
record.outcome=result.kind
record.result=result.selfWon and"win"or"loss"
record.opponentName=result.opponent
local map=A.readMap()
if map then
record.map=map
end
local side=A.playerFaction()
if side~=nil then
record.duelFaction=side
end
local participants={}
local kept=0
local selfGuid=guarded(UnitGUID,"player")
if type(selfGuid)=="string"and A.canRead(selfGuid)then
record.character=selfGuid
participants[selfGuid]={name=A.unitNames("player")[1],side="with"}
kept=kept+1
end
local guid,source=resolveOpponent(record.opponentName)
if not guid and type(record.opponentName)=="string"and record.opponentName~=""then
local read,held=pcall(function()
return A.playerByName(A.playerNameIndex(),record.opponentName)
end)
if read and type(held)=="string"and held~=""then
guid,source=held,"index"
end
end
local key=guid
if key==nil and type(record.opponentName)=="string"and record.opponentName~=""then
key,source=record.opponentName,"name"
end
if key and key~=selfGuid then
participants[key]={name=record.opponentName,side="against"}
kept=kept+1
end
record.participants=participants
record.participantCount=kept
record.id=db.nextMatchId
db.nextMatchId=db.nextMatchId+1
db.matches[#db.matches+1]=record
A.trace("duel",{
id=record.id,
format=record.format,
state=record.outcome,
source=tostring(source),
n=kept,
faction=record.duelFaction,
})
local indexed,folded=pcall(A.indexMatch,record)
if not indexed then
A.noteError(folded,"duel-index")
A.say("the duel is stored and the player index was not updated: "..tostring(folded)
..". /pvph rebuild")
end
A.recordStored("duel")
A.trace("index",{n=indexed and folded or nil,id=record.id})
local folded2,why2=pcall(A.mergeNamedPlayers,record)
if not folded2 then
A.noteError(why2,"duel-merge")
end
pcall(A.noteCanary)
local line="switch"
local said,chatErr=pcall(function()
if not A.postGameEnabled()then
return
end
line="recorded"
A.say(("recorded duel %d: %s, %s, %d %s"):format(record.id,record.outcome,
A.resultCellText(record)or"-",
kept,kept==1 and"participant"or"participants"))
line="link"
local linkOk,linkLine=pcall(A.matchLinkLine,record)
if linkOk and linkLine then
A.say(linkLine)
end
end)
if not said then
pcall(A.trace,"chat-line",{source="duel",state=line,id=record.id,err=chatErr})
end
end
local function onRequested(event,playerName)
if not A.duelsEnabled()then
A.trace("duelrequest",{state="refused",reason="switch"})
return
end
local name=(type(playerName)=="string"and A.canRead(playerName))and playerName or nil
local at
local stamped,value=pcall(A.stamp)
if stamped then
at=value
end
request={
name=name,
epoch=time(),
at=at,
toTheDeath=event=="DUEL_TO_THE_DEATH_REQUESTED",
}
A.trace("duelrequest",{state=name and"read"or"unread",source=event})
end
local function onSystem(_,message)
if not A.duelsEnabled()then
return
end
if not A.canRead(message)then
refusedLines=refusedLines+1
A.trace("duel",{state="refused",reason="secret-system-line",
restriction=A.pvpRestriction()})
return
end
if type(message)~="string"then
return
end
local list=patterns()
for i=1,#list do
local entry=list[i]
local first,second=message:match(entry.pattern)
if first and second then
local winner=(entry.winner==1)and first or second
local loser=(entry.winner==1)and second or first
local mine=A.unitNames("player")
local selfWon,selfLost=isNamed(mine,winner),isNamed(mine,loser)
if selfWon or selfLost then
outcome={
kind=entry.kind,
selfWon=selfWon,
opponent=selfWon and loser or winner,
epoch=time(),
}
A.trace("duelline",{state=entry.kind,source=selfWon and"won"or"lost"})
end
return
end
end
end
local function onFinished()
if not A.duelsEnabled()then
A.trace("duelend",{state="refused",reason="switch"})
return
end
local ended=time()
local opened=request
request=nil
if opened and(type(opened.epoch)~="number"
or ended-opened.epoch>REQUEST_STALE_SECONDS)then
opened=nil
end
A.trace("duelend",{state=opened and"requested"or"unrequested"})
local function run()
local result=outcome
outcome=nil
if result and(type(result.epoch)~="number"
or time()-result.epoch>OUTCOME_STALE_SECONDS)then
result=nil
end
contained(storeDuel,opened,result,ended)
end
local after=C_Timer and C_Timer.After
if type(after)~="function"then
run()
return
end
if not pcall(after,STORE_DELAY,run)then
run()
end
end
function A.duelState()
return{
enabled=A.duelsEnabled(),
patterns=#patterns(),
expected=2,
pending=request~=nil,
refused=refusedLines,
}
end
A.on("DUEL_REQUESTED",function(event,playerName)
contained(onRequested,event,playerName)
end)
A.on("DUEL_TO_THE_DEATH_REQUESTED",function(event,playerName)
contained(onRequested,event,playerName)
end)
A.on("CHAT_MSG_SYSTEM",function(event,message)
contained(onSystem,event,message)
end)
A.on("DUEL_FINISHED",function()
contained(onFinished)
end)
