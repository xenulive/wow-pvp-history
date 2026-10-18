-- WowPvpHistory 0.68.47
-- Author:  Xenu-Sentinels
-- Project: wow-pvp-history
--          https://github.com/xenulive/wow-pvp-history
-- License: MIT, see LICENSE
local _,A=...
A.indexVersion=8
local function newEntry()
return{
names={},
matches=0,
formats={},
with={count=0,wins=0,decided=0,manualDecided=0,draws=0},
against={count=0,wins=0,decided=0,manualDecided=0,draws=0},
undetermined=0,
ratings={},
fixture=0,
}
end
local function ratingReading(participant)
local rating=type(participant.rating)=="number"and participant.rating or 0
local change=type(participant.ratingChange)=="number"and participant.ratingChange or 0
local mmrPre=type(participant.mmrPre)=="number"and participant.mmrPre or 0
local mmrPost=type(participant.mmrPost)=="number"and participant.mmrPost or 0
if rating==0 and change==0 and mmrPre==0 and mmrPost==0 then
return nil
end
local out=type(participant.ratingChange)=="number"and rating+change or nil
local mmr=mmrPost~=0 and mmrPost or nil
if out==nil and mmr==nil then
return nil
end
return{
rating=out,
mmr=mmr,
}
end
local function noteRating(entry,record,participant,format)
if format==nil then
return
end
local reading=ratingReading(participant)
if not reading then
return
end
local epoch=record.completedEpoch
local stamp=record.completedAt or record.openedAt
if type(epoch)~="number"then
epoch=record.openedEpoch
end
if type(epoch)~="number"then
return
end
local ratings=entry.ratings
if type(ratings)~="table"then
ratings={}
entry.ratings=ratings
end
local held=ratings[format]
if type(held)=="table"and type(held.epoch)=="number"and held.epoch>epoch then
return
end
ratings[format]={
rating=reading.rating,
mmr=reading.mmr,
at=stamp,
epoch=epoch,
}
end
local function noteName(entry,name)
if type(name)~="string"or name==""then
return
end
local names=entry.names
if names[1]==name then
return
end
for i=#names,1,-1 do
if names[i]==name then
table.remove(names,i)
end
end
table.insert(names,1,name)
end
local function noteSeen(entry,record)
local epoch=record.openedEpoch
local stamp=record.openedAt
if type(epoch)~="number"then
epoch=record.completedEpoch
stamp=stamp or record.completedAt
end
if type(epoch)~="number"then
if entry.firstEpoch==nil and entry.firstSeen==nil then
entry.firstSeen=stamp
end
if entry.lastEpoch==nil and entry.lastSeen==nil then
entry.lastSeen=stamp
end
return
end
if entry.firstEpoch==nil or epoch<entry.firstEpoch then
entry.firstEpoch=epoch
entry.firstSeen=stamp
end
if entry.lastEpoch==nil or epoch>=entry.lastEpoch then
entry.lastEpoch=epoch
entry.lastSeen=stamp
end
end
local WITH,AGAINST="with","against"
local function side(selfFaction,participant)
local explicit=participant.side
if explicit==WITH or explicit==AGAINST then
return explicit
end
if selfFaction==nil or participant.faction==nil then
return nil
end
if(selfFaction~=0 and selfFaction~=1)or(participant.faction~=0 and participant.faction~=1)then
return nil
end
if participant.faction==selfFaction then
return WITH
end
return AGAINST
end
local NO_MATCH_SIDE={shuffle=true,["shuffle-unrated"]=true}
local function recordSelfFaction(record)
if NO_MATCH_SIDE[record.format]then
return nil
end
local selfRow=record.character~=nil and record.participants[record.character]or nil
return type(selfRow)=="table"and selfRow.faction or nil
end
function A.matchSide(record,guid)
if type(record)~="table"or type(record.participants)~="table"then
return nil
end
local participant=record.participants[guid]
if type(participant)~="table"then
return nil
end
return side(recordSelfFaction(record),participant)
end
function A.bareName(name)
if type(name)~="string"or name==""then
return nil
end
local at=name:find("-",1,true)
if not at then
return name
end
if at<=1 then
return nil
end
return name:sub(1,at-1)
end
function A.playerNameIndex(ordered)
local byGuid,byName={},{}
local index,yielded={},{}
local count=0
local function claim(name,key,named)
if name==nil or name==""then
return
end
local held=named and byName or byGuid
local was=held[name]
if was==nil then
held[name]=key
elseif was~=key then
held[name]=false
end
local guid=byGuid[name]
if guid~=nil then
index[name]=guid
else
index[name]=byName[name]
end
local yields=type(guid)=="string"and byName[name]~=nil
if yields~=(yielded[name]==true)then
yielded[name]=yields or nil
count=count+(yields and 1 or-1)
end
end
local function walk(key,entry)
local names=type(entry)=="table"and entry.names or nil
if type(key)~="string"or type(names)~="table"then
return
end
local named=names[1]==key
for i=1,#names do
local name=names[i]
if type(name)=="string"and name~=""then
claim(name,key,named)
local bare=A.bareName(name)
if bare~=name then
claim(bare,key,named)
end
end
end
end
if type(ordered)=="table"then
for i=1,#ordered do
local pair=ordered[i]
if type(pair)=="table"then
walk(pair[1],pair[2])
end
end
else
local db=A.db()
local players=(db and type(db.players)=="table")and db.players or{}
for key,entry in pairs(players)do
walk(key,entry)
end
end
return index,count
end
function A.playerByName(index,name)
local held=index[name]
if held then
return held
end
if held==false then
return nil
end
local bare=A.bareName(name)
if bare==nil or bare==name then
return nil
end
held=index[bare]
if held then
return held
end
return nil
end
local function placeholder()
local text=UNKNOWNOBJECT
if type(text)=="string"and A.canRead(text)and text~=""then
return text
end
return nil
end
local function usableName(name)
if type(name)~="string"or not A.canRead(name)or name==""then
return false
end
return name~=placeholder()
end
function A.unitNames(token)
local names={}
if type(UnitName)~="function"then
return names
end
local ok,bare,realm=pcall(UnitName,token)
if not(ok and usableName(bare))then
return names
end
names[1]=bare
if type(realm)=="string"and A.canRead(realm)and realm~=""then
names[2]=bare.."-"..realm
end
return names
end
function A.unitNameFromGuid(guid)
if type(UnitNameFromGUID)~="function"or type(guid)~="string"or not A.canRead(guid)then
return nil
end
local ok,bare,realm=pcall(UnitNameFromGUID,guid)
if not(ok and usableName(bare))then
return nil
end
if realm==nil then
return bare
end
if type(realm)~="string"or not A.canRead(realm)then
return nil
end
realm=(realm:gsub("%s",""))
if realm==""or realm==A.ownRealm()then
return bare
end
return bare.."-"..realm
end
function A.nameplateTokens()
local plates=C_NamePlate and C_NamePlate.GetNamePlates
if type(plates)~="function"then
return{}
end
local ok,list=pcall(plates)
if not(ok and type(list)=="table")then
return{}
end
local tokens={}
for i=1,#list do
local plate=list[i]
if type(plate)=="table"then
local token=plate.namePlateUnitToken
if type(token)=="string"and token~=""then
tokens[#tokens+1]=token
end
end
end
return tokens
end
function A.indexMatch(record,db)
db=db or A.db()
if not(db and type(db.players)=="table"and type(record)=="table")then
return 0
end
local participants=record.participants
if type(participants)~="table"then
return 0
end
local players=db.players
local selfFaction=recordSelfFaction(record)
local outcome,byHand=record.result,false
if outcome==nil and type(record.manual)=="table"and record.manual.result~=nil then
outcome=record.manual.result
byHand=true
end
local decided=(outcome~=nil)and 1 or 0
local manualDecided=byHand and 1 or 0
local won=(outcome=="win")and 1 or 0
local drawn=(outcome=="draw")and 1 or 0
local format=record.format~=nil and tostring(record.format)or nil
local generated=record[A.FIXTURE_KEY]==true
local counted=0
for guid,participant in pairs(participants)do
if type(guid)=="string"and type(participant)=="table"then
local entry=players[guid]
if type(entry)~="table"then
entry=newEntry()
players[guid]=entry
end
entry.matches=(entry.matches or 0)+1
if generated then
entry.fixture=(entry.fixture or 0)+1
end
noteName(entry,participant.name)
noteSeen(entry,record)
if format then
entry.formats[format]=(entry.formats[format]or 0)+1
noteRating(entry,record,participant,format)
end
local which=side(selfFaction,participant)
if which==nil then
entry.undetermined=(entry.undetermined or 0)+1
else
local bucket=entry[which]
bucket.count=bucket.count+1
bucket.decided=bucket.decided+decided
bucket.wins=bucket.wins+won
bucket.manualDecided=(bucket.manualDecided or 0)+manualDecided
bucket.draws=(bucket.draws or 0)+drawn
end
counted=counted+1
end
end
return counted
end
function A.repairDuelRecord(record)
if type(record)~="table"or record.format~="duel"then
return false
end
local name=record.opponentName
if type(name)~="string"or name==""then
return false
end
local participants=record.participants
if type(participants)~="table"then
return false
end
for _,participant in pairs(participants)do
if type(participant)=="table"and participant.side=="against"then
return false
end
end
participants[name]={name=name,side="against"}
record.participantCount=(tonumber(record.participantCount)or 0)+1
return true
end
function A.indexCensus(db)
db=db or A.db()
local out={players=0,encounters=0,version=nil}
if type(db)~="table"or type(db.players)~="table"then
return out
end
for _,entry in pairs(db.players)do
out.players=out.players+1
if type(entry)=="table"and type(entry.matches)=="number"then
out.encounters=out.encounters+entry.matches
end
end
out.version=db.playerIndexVersion
return out
end
function A.indexReading(db)
db=db or A.db()
if type(db)~="table"then
return"no database, so there is no index to read"
end
local census=A.indexCensus(db)
local held=("%d %s"):format(census.encounters,
census.encounters==1 and"encounter"or"encounters")
local stamped=census.version
if type(stamped)~="number"then
return("not stamped, %s, so it rebuilds at the next login"):format(held)
end
if stamped<A.indexVersion then
return("v%d against v%d, %s, so it rebuilds at the next login")
:format(stamped,A.indexVersion,held)
end
return("v%d, stamped, %s"):format(stamped,held)
end
function A.reportRebuild()
local said={}
local function say(line)
said[#said+1]=line
A.say(line)
end
local walked=A.rebuildIndex()
if not walked then
say("no database. nothing was rebuilt")
return said
end
local line=("rebuilt the player index from %d stored %s: %d players, %d encounters")
:format(walked.matches,walked.matches==1 and"match"or"matches",
walked.players,walked.encounters)
if walked.stored~=walked.encounters then
line=line..(", against %d participants counted on the records"):format(walked.stored)
end
say(line)
if walked.matches==0 then
say("nothing is stored, so the index version stays unstamped and this runs again at login")
end
return said
end
local function guidKeyed(key,participant)
return type(key)=="string"and key~=""and key~=participant.name
end
local function namedEntryFor(players,name,guid)
if type(name)~="string"or name==""then
return nil,"no-name"
end
local entry=players[name]
if type(entry)~="table"or type(entry.names)~="table"or entry.names[1]~=name then
return nil,"no-entry"
end
for key,other in pairs(players)do
if key~=name and key~=guid and type(other)=="table"and type(other.names)=="table"then
for i=1,#other.names do
if other.names[i]==name then
return nil,"ambiguous"
end
end
end
end
return name
end
local function retargetRefusal(matches,nameKey,guid,character)
local bare=not nameKey:find("-",1,true)
for i=1,#matches do
local record=matches[i]
if type(record)=="table"and type(record.participants)=="table"
and type(record.participants[nameKey])=="table"
then
if type(record.participants[guid])=="table"then
return"same-record"
end
if bare and record.character~=character then
return"other-recorder"
end
end
end
return nil
end
local function retarget(matches,nameKey,guid)
local moved=0
for i=1,#matches do
local record=matches[i]
if type(record)=="table"and type(record.participants)=="table"then
local participants=record.participants
local row=participants[nameKey]
if type(row)=="table"then
participants[nameKey]=nil
if type(participants[guid])=="table"then
if type(record.participantCount)=="number"then
record.participantCount=record.participantCount-1
end
else
participants[guid]=row
end
moved=moved+1
end
end
end
return moved
end
local function mergeNotes(notes,nameKey,guid)
local from=notes[nameKey]
if type(from)~="table"then
return false
end
notes[nameKey]=nil
local into=notes[guid]
if type(into)~="table"then
notes[guid]=from
if type(A.dropTagVocabulary)=="function"then
A.dropTagVocabulary()
end
return true
end
local kept={name=nameKey}
local keeping=false
if from.rating~=nil then
if into.rating==nil then
into.rating=from.rating
else
kept.rating=from.rating
keeping=true
end
end
if from.text~=nil then
if into.text==nil then
into.text=from.text
else
kept.text=from.text
keeping=true
end
end
if type(from.tags)=="table"and#from.tags>0 then
local tags=type(into.tags)=="table"and into.tags or{}
local held={}
for i=1,#tags do
held[tags[i]]=true
end
for i=1,#from.tags do
local tag=from.tags[i]
if not held[tag]then
held[tag]=true
if#tags<A.PLAYER_MAX_TAGS then
tags[#tags+1]=tag
else
kept.tags=kept.tags or{}
kept.tags[#kept.tags+1]=tag
keeping=true
end
end
end
into.tags=tags
if type(A.dropTagVocabulary)=="function"then
A.dropTagVocabulary()
end
end
if type(from.comments)=="table"and#from.comments>0 then
local comments=type(into.comments)=="table"and into.comments or{}
for i=1,#from.comments do
comments[#comments+1]=from.comments[i]
end
table.sort(comments,function(a,b)
return(tonumber(a.epoch)or 0)<(tonumber(b.epoch)or 0)
end)
into.comments=comments
end
if keeping then
into.merged=type(into.merged)=="table"and into.merged or{}
into.merged[#into.merged+1]=kept
end
return true
end
local function holdsNamedEntry(players)
for key,entry in pairs(players)do
if type(entry)=="table"and type(entry.names)=="table"and entry.names[1]==key then
return true
end
end
return false
end
local function foldRecord(db,record)
local participants=type(record)=="table"and record.participants or nil
if type(participants)~="table"then
return 0
end
local players=db.players
local matches=type(db.matches)=="table"and db.matches or{}
local merged=0
for key,participant in pairs(participants)do
if type(participant)=="table"and guidKeyed(key,participant)and key~=record.character
and type(participant.name)=="string"and participant.name~=""
then
local nameKey,missed=namedEntryFor(players,participant.name,key)
local refused=missed=="ambiguous"and missed or nil
if nameKey~=nil then
refused=retargetRefusal(matches,nameKey,key,record.character)
end
if refused then
A.trace("merge",{state="refused",reason=refused,id=record.id},"data")
elseif nameKey~=nil and nameKey~=key then
local moved=retarget(matches,nameKey,key)
if type(db.notes)=="table"then
mergeNotes(db.notes,nameKey,key)
end
players[nameKey]=nil
if moved>0 then
merged=merged+1
end
end
end
end
return merged
end
function A.mergeNamedPlayers(record,db)
db=db or A.db()
if not(db and type(db.players)=="table"and type(record)=="table")then
return 0
end
local merged=foldRecord(db,record)
if merged>0 then
A.rebuildIndex(db)
A.trace("merge",{n=merged,id=record.id},"data")
end
return merged
end
function A.playerHistories(entry)
local held=type(entry)=="table"and entry.merged or nil
if type(held)~="table"then
return 0
end
return#held
end
function A.rebuildIndex(db)
db=db or A.db()
if not db then
return nil
end
db.playerIndexVersion=nil
local list=db.matches or{}
local walked,stored,repaired
local function walk()
db.players={}
walked,stored,repaired=0,0,0
for i=1,#list do
local record=list[i]
if type(record)=="table"then
walked=walked+1
if A.repairDuelRecord(record)then
repaired=repaired+1
end
if not record.worldOpen then
A.indexMatch(record,db)
if type(record.participantCount)=="number"then
stored=stored+record.participantCount
end
end
end
end
end
walk()
local folded=0
if holdsNamedEntry(db.players)then
for i=1,#list do
folded=folded+foldRecord(db,list[i])
end
if folded>0 then
local firstRepaired=repaired
walk()
repaired=firstRepaired
end
end
local census=A.indexCensus(db)
local people,encounters=census.players,census.encounters
if walked>0 then
db.playerIndexVersion=A.indexVersion
end
A.trace("rebuild",{n=people,rows=walked,repaired=repaired>0 and repaired or nil,
folded=folded>0 and folded or nil},"data")
return{
matches=walked,
players=people,
encounters=encounters,
stored=stored,
repaired=repaired,
folded=folded,
}
end
local function backfill()
local db=A.db()
if not db then
A.trace("rebuild",{state="refused",reason="no-database",source="login"},"data")
return
end
local stamped=db.playerIndexVersion
if type(stamped)=="number"and stamped>=A.indexVersion then
return
end
local walked=A.rebuildIndex()
if walked and walked.matches>0 then
A.say(("built the player index from %d stored %s: %d players, %d encounters")
:format(walked.matches,walked.matches==1 and"match"or"matches",
walked.players,walked.encounters))
end
end
A.on("PLAYER_LOGIN",backfill)
