-- WowPvpHistory 0.68.21
-- Author:  Xenu-Sentinels
-- Project: wow-pvp-history
--          https://github.com/xenulive/wow-pvp-history
-- License: MIT, see LICENSE
local ADDON,A=...
local NO_SEASON=0
A.SEASON_LABEL_MAX=40
function A.arenaSeasonNow()
if type(GetCurrentArenaSeason)~="function"then
return nil
end
local ok,value=pcall(GetCurrentArenaSeason)
if not ok or not A.canRead(value)or type(value)~="number"then
return nil
end
return value
end
function A.displaySeasonNow()
local value=A.pvpCall("GetUIDisplaySeason")
if not A.canRead(value)or type(value)~="number"then
return nil
end
return value
end
local function seasonPair()
local game=A.arenaSeasonNow()
if game==nil or game==NO_SEASON then
return nil,nil
end
local display=A.displaySeasonNow()
if display==nil or display<=NO_SEASON then
return nil,nil
end
return game,display
end
function A.seasonNow()
local _,display=seasonPair()
return display
end
function A.gameSeasonNow()
local game=seasonPair()
return game
end
local function store(create,db)
db=db or A.db()
if not db then
return nil
end
if type(db.seasons)~="table"then
if not create then
return nil
end
db.seasons={}
end
return db.seasons
end
local function stampOf(text)
if type(text)~="string"then
return nil
end
local trimmed=text:match("^%s*(.-)%s*$")
local year,month,day=trimmed:match("^(%d%d%d%d)%-(%d%d)%-(%d%d)")
year,month,day=tonumber(year),tonumber(month),tonumber(day)
if year==nil or month<1 or month>12 or day<1 then
return nil
end
local leap=(year%4==0 and year%100~=0)or year%400==0
local length=({31,leap and 29 or 28,31,30,31,30,31,31,30,31,30,31})[month]
if day>length then
return nil
end
if trimmed:match("^%d%d%d%d%-%d%d%-%d%d$")then
return trimmed.." 00:00:00"
end
if trimmed:match("^%d%d%d%d%-%d%d%-%d%d %d%d:%d%d:%d%d$")then
return trimmed
end
return nil
end
A.seasonStamp=stampOf
local function byStart(a,b)
return tostring(a.startedAt)<tostring(b.startedAt)
end
function A.seasonBoundaries()
return store(false)or{}
end
function A.seasonEntry(number)
if type(number)~="number"then
return nil
end
local list=store(false)
if not list then
return nil
end
for i=#list,1,-1 do
if list[i].season==number then
return list[i]
end
end
return nil
end
local function openEntry(list)
for i=#list,1,-1 do
if list[i].endedAt==nil then
return list[i]
end
end
return nil
end
function A.seasonNewest()
local list=store(false)
if not(list and#list>0)then
return nil
end
return list[#list].season
end
function A.seasonAt(stamp)
if type(stamp)~="string"then
return nil
end
local list=store(false)
if not list then
return nil
end
for i=#list,1,-1 do
local entry=list[i]
local from,to=entry.startedAt,entry.endedAt
if type(from)=="string"and stamp>=from then
if to==nil or stamp<to then
return entry.season
end
return nil
end
end
return nil
end
function A.recordSeason(record)
if type(record)~="table"then
return nil
end
if type(record.season)=="number"then
return record.season,"client"
end
local stamp=record.completedAt
if type(stamp)~="string"then
stamp=record.openedAt
end
local resolved=A.seasonAt(stamp)
if resolved==nil then
return nil
end
return resolved,"boundary"
end
function A.recordGameSeason(record)
if type(record)~="table"or type(record.gameSeason)~="number"then
return nil
end
return record.gameSeason,"client"
end
local function traceTyped(n,reason)
A.trace("season",{source="typed",n=type(n)=="number"and n or nil,reason=reason},"data")
end
local function refuseTyped(typed,n,token,text)
if typed then
traceTyped(n,token)
end
return nil,text
end
function A.seasonOpen(number,when,source,game,db)
local typed=source~="client"
if type(number)~="number"or number~=math.floor(number)or number<=0
or number==math.huge then
return refuseTyped(typed,nil,"bad-number","a season is a whole number above zero")
end
local at=when==nil and A.stamp()or stampOf(when)
if at==nil then
return refuseTyped(typed,number,"bad-date","a date reads YYYY-MM-DD, or leave it out for now")
end
local list=store(true,db)
if not list then
return refuseTyped(typed,number,"no-database","no database")
end
local taken=false
if type(game)=="number"then
local newest=list[#list]
taken=type(newest)=="table"and newest.gameSeason==nil and newest.season==number
for i=1,#list do
if list[i].gameSeason==game then
taken=true
end
end
else
for i=1,#list do
if list[i].season==number then
taken=true
end
end
end
if taken then
return refuseTyped(typed,number,"already-declared",("season %d is already declared"):format(number))
end
local entry={
season=number,
gameSeason=type(game)=="number"and game or nil,
startedAt=at,
source=(source=="client")and"client"or"manual",
}
list[#list+1]=entry
table.sort(list,byStart)
local index
for i=1,#list do
if list[i]==entry then
index=i
break
end
end
local closed
local before=list[index-1]
if type(before)=="table"and before.endedAt==nil then
before.endedAt=at
closed=before.season
end
local after=list[index+1]
if type(after)=="table"then
entry.endedAt=after.startedAt
end
if typed then
traceTyped(number,"opened")
end
return entry,closed
end
function A.seasonClose(when)
local at=when==nil and A.stamp()or stampOf(when)
if at==nil then
return refuseTyped(true,nil,"bad-date","a date reads YYYY-MM-DD, or leave it out for now")
end
local list=store(false)
if not(list and#list>0)then
return refuseTyped(true,nil,"nothing-declared","nothing is declared")
end
local open=openEntry(list)
if not open then
return refuseTyped(true,nil,"none-open","no season is open")
end
if at<tostring(open.startedAt)then
return refuseTyped(true,open.season,"before-start",
("season %d opened at %s, so it cannot end before that"):format(open.season,tostring(open.startedAt)))
end
open.endedAt=at
traceTyped(open.season,"closed")
return open
end
function A.seasonSetLabel(number,text)
local entry=A.seasonEntry(number)
if not entry then
return refuseTyped(true,number,"not-declared","that season is not declared")
end
if type(text)~="string"or text:match("^%s*$")then
entry.label=nil
traceTyped(number,"unlabelled")
return entry
end
local trimmed=text:match("^%s*(.-)%s*$")
if#trimmed>A.SEASON_LABEL_MAX then
return refuseTyped(true,number,"too-long",
("a label is at most %d bytes and that one is %d"):format(A.SEASON_LABEL_MAX,#trimmed))
end
entry.label=trimmed
traceTyped(number,"labelled")
return entry
end
local function removeAt(list,index)
local entry=list[index]
local prev=list[index-1]
if type(entry)=="table"and type(prev)=="table"and prev.endedAt==entry.startedAt then
prev.endedAt=entry.endedAt
end
table.remove(list,index)
end
function A.seasonForget(number)
local list=store(false)
if not list then
return refuseTyped(true,number,"nothing-declared","nothing is declared")
end
for i=#list,1,-1 do
if list[i].season==number then
removeAt(list,i)
traceTyped(number,"forgot")
return number
end
end
return refuseTyped(true,number,"not-declared","that season is not declared")
end
local function remember(db,season)
local seen=db.seasonSeen
db.seasonSeen=season
if type(seen)~="number"then
return nil
end
return seen
end
local function onSeasonState()
local season=A.seasonNow()
if season==nil then
A.trace("season",{source="client",reason="no-answer"},"data")
return
end
local db=A.savedDB()
if not db then
A.trace("season",{source="client",n=season,reason="no-database"},"data")
return
end
local game=A.gameSeasonNow()
local seenGame=type(db.gameSeasonSeen)=="number"and db.gameSeasonSeen or nil
db.gameSeasonSeen=game
local seen=remember(db,season)
local changed
if seenGame~=nil then
changed=seenGame~=game
else
changed=seen~=nil and seen~=season
end
if seen==nil and seenGame==nil then
A.trace("season",{source="client",n=season,game=game,reason="first-sighting"},"data")
return
end
if not changed then
return
end
local entry,closed=A.seasonOpen(season,nil,"client",game,db)
if not entry then
A.trace("season",{source="client",n=season,game=game,reason="open-refused"},"data")
return
end
A.trace("season",{
source="client",
n=season,
game=game,
reason=closed and"closed-previous"or"opened",
},"data")
end
A.on("ARENA_SEASON_WORLD_STATE",function()
local ok,err=pcall(onSeasonState)
if not ok then
A.noteError(err,"season")
end
end)
local function forgetFabricated()
local db=A.db()
if not db or type(db.seasonSeen)=="number"then
return
end
local list=db.seasons
if type(list)~="table"or#list==0 then
return
end
local dropped=0
for i=#list,1,-1 do
local entry=list[i]
if type(entry)=="table"and entry.source=="client"then
removeAt(list,i)
dropped=dropped+1
end
end
if dropped==0 then
return
end
if#list==0 then
db.seasons=nil
end
A.trace("season",{source="client",n=dropped,reason="dropped-fabricated"},"data")
A.say(("dropped %d season %s the previous version recorded at a login rather than at a "):format(
dropped,dropped==1 and"boundary"or"boundaries")
.."season change. /pvph season start <n> <date> declares the real one")
end
local function backfillGameSeason()
local db=A.db()
if not db or db.gameSeasonFilled then
return
end
local game,display=A.gameSeasonNow(),A.seasonNow()
if game==nil or display==nil then
return
end
local list=db.matches
if type(list)~="table"then
db.gameSeasonFilled=true
return
end
local filled,left=0,0
for i=1,#list do
local record=list[i]
if type(record)=="table"and record.gameSeason==nil and type(record.season)=="number"then
if record.season==display then
record.gameSeason=game
filled=filled+1
else
left=left+1
end
end
end
db.gameSeasonFilled=true
A.trace("season",{
reason="backfill-game-season",
n=filled,
left=left,
arena=game,
season=display,
},"data")
if filled>0 then
A.say(("filled the game season on %d stored %s from the client's own reading of season %d")
:format(filled,filled==1 and"match"or"matches",game))
end
end
A.on("ADDON_LOADED",function(_,name)
if name==ADDON then
forgetFabricated()
backfillGameSeason()
end
end)
local RATED_INDEX={shuffle=7,blitz=9,arena2=1,arena3=2}
local RATED_ORDER={"shuffle","blitz","arena2","arena3"}
local WEEK=604800
function A.ratedIndex(format)
return RATED_INDEX[format]
end
function A.ratedFormats()
local out={}
for i=1,#RATED_ORDER do
out[i]=RATED_ORDER[i]
end
return out
end
local function counter(value)
if not A.canRead(value)or type(value)~="number"then
return nil
end
return value
end
function A.ratedCountersNow(format)
local index=RATED_INDEX[format]
if index==nil or type(GetPersonalRatedInfo)~="function"then
return nil
end
local ok,_,_,_,seasonPlayed,seasonWon,weeklyPlayed,weeklyWon,_,_,_,_,
roundsSeasonPlayed,roundsSeasonWon,roundsWeeklyPlayed,roundsWeeklyWon=
pcall(GetPersonalRatedInfo,index)
if not ok then
return nil
end
local out={
seasonPlayed=counter(seasonPlayed),
seasonWon=counter(seasonWon),
weeklyPlayed=counter(weeklyPlayed),
weeklyWon=counter(weeklyWon),
}
if format=="shuffle"then
out.roundsSeasonPlayed=counter(roundsSeasonPlayed)
out.roundsSeasonWon=counter(roundsSeasonWon)
out.roundsWeeklyPlayed=counter(roundsWeeklyPlayed)
out.roundsWeeklyWon=counter(roundsWeeklyWon)
end
return out
end
function A.weekStartEpoch()
local api=C_DateAndTime
local reader=type(api)=="table"and api.GetSecondsUntilWeeklyReset or nil
if type(reader)~="function"then
return nil
end
local ok,seconds=pcall(reader)
if not ok or not A.canRead(seconds)or type(seconds)~="number"or seconds<0 or seconds>WEEK then
return nil
end
return time()+seconds-WEEK
end
local TIER_QUALITY={[0]=0,[1]=1,[6]=1,[2]=2,[7]=2,[3]=3,[8]=3,[4]=4,[5]=5}
local LADDER_STEPS=32
local heardRated=false
local ratedAsked,ratedWaiting=false,false
local ladders={}
local ladderTraced={}
local function tierNumber(info,key)
local value=info[key]
if not A.canRead(value)or type(value)~="number"then
return nil
end
return value
end
local function tierInfo(lookup,tierID)
local ok,info=pcall(lookup,tierID)
if not ok then
return nil,"threw"
end
if type(info)~="table"then
return nil,"no-info"
end
local enum=info.pvpTierEnum
if type(enum)=="nil"then
return nil,"no-info"
end
if not A.canRead(enum)then
return nil,"secret"
end
if type(enum)~="number"then
return nil,"no-info"
end
return info
end
local function linkOf(info,key)
local id=info[key]
if type(id)=="nil"or not A.canRead(id)or type(id)~="number"or id<=0 then
return nil
end
return id
end
local function walk(lookup,seed,key,seen)
local out={}
local info=seed
for _=1,LADDER_STEPS do
local nextID=linkOf(info,key)
if nextID==nil then
return out
end
if seen[nextID]then
return nil,"loop"
end
local nextInfo,reason=tierInfo(lookup,nextID)
if nextInfo==nil then
if reason=="no-info"then
return out
end
return nil,reason
end
seen[nextID]=true
out[#out+1]=nextInfo
info=nextInfo
end
return nil,"loop"
end
local function buildLadder(format)
local index=A.ratedIndex(format)
if index==nil then
return nil,"unrated"
end
local pvp=C_PvP
local lookup=type(pvp)=="table"and pvp.GetPvpTierInfo or nil
if type(GetPersonalRatedInfo)~="function"or type(lookup)~="function"then
return nil,"no-call"
end
local ok,_,_,_,_,_,_,_,_,_,seedID=pcall(GetPersonalRatedInfo,index)
if not ok then
return nil,"threw"
end
if type(seedID)=="nil"then
return nil,"no-tier"
end
if not A.canRead(seedID)then
return nil,"secret"
end
if type(seedID)~="number"then
return nil,"no-tier"
end
local seed,reason=tierInfo(lookup,seedID)
if seed==nil then
return nil,reason
end
local seen={[seedID]=true}
local below,belowReason=walk(lookup,seed,"descendTier",seen)
if below==nil then
return nil,belowReason
end
local above,aboveReason=walk(lookup,seed,"ascendTier",seen)
if above==nil then
return nil,aboveReason
end
local order={}
for i=#below,1,-1 do
order[#order+1]=below[i]
end
order[#order+1]=seed
for i=1,#above do
order[#order+1]=above[i]
end
local tiers={}
for i=1,#order do
local entry=i>1 and tierNumber(order[i-1],"ascendRating")or nil
if i==1 then
entry=0
elseif entry==nil then
return nil,"no-info"
end
local name=order[i].name
if not A.canRead(name)or type(name)~="string"then
name=nil
end
tiers[i]={enum=order[i].pvpTierEnum,entry=entry,name=name}
end
return{tiers=tiers}
end
local function ladderText(ladder)
local parts={}
for i=1,#ladder.tiers do
parts[i]=ladder.tiers[i].enum..":"..ladder.tiers[i].entry
end
return table.concat(parts,",")
end
function A.ratingLadder(format)
if not heardRated then
return nil,"unheard"
end
local held=ladders[format]
if held==nil then
local ladder,reason=buildLadder(format)
held=ladder or{reason=reason}
ladders[format]=held
if not ladderTraced[format]then
ladderTraced[format]=true
A.trace("tiers",{
format=format,
ladder=ladder and ladderText(ladder)or nil,
reason=reason,
},"data")
end
end
if held.tiers==nil then
return nil,held.reason
end
return held
end
local function component(value)
if not A.canRead(value)or type(value)~="number"or value<0 or value>1 then
return nil
end
return value
end
function A.ratingColour(format,rating)
if type(rating)~="number"then
return nil,nil,"no-rating"
end
local ladder,reason=A.ratingLadder(format)
if ladder==nil then
return nil,nil,reason
end
local enum
for i=#ladder.tiers,1,-1 do
if ladder.tiers[i].entry<=rating then
enum=ladder.tiers[i].enum
break
end
end
local quality=enum~=nil and TIER_QUALITY[enum]or nil
if quality==nil then
return nil,nil,"out-of-range"
end
local item=C_Item
local colour=type(item)=="table"and item.GetItemQualityColor or nil
if type(colour)~="function"then
return nil,nil,"no-call"
end
local ok,r,g,b=pcall(colour,quality)
if not ok then
return nil,nil,"threw"
end
r,g,b=component(r),component(g),component(b)
if r==nil or g==nil or b==nil then
return nil,nil,"no-colour"
end
return enum,("|cff%02x%02x%02x"):format(
math.floor(r*255+0.5),math.floor(g*255+0.5),math.floor(b*255+0.5)),nil,r,g,b
end
function A.ratingTierName(format,rating)
if type(rating)~="number"then
return nil,"no-rating"
end
local ladder,reason=A.ratingLadder(format)
if ladder==nil then
return nil,reason
end
for i=#ladder.tiers,1,-1 do
if ladder.tiers[i].entry<=rating then
return A.tierWord(ladder.tiers[i].enum,ladder.tiers[i].name)
end
end
return nil,"out-of-range"
end
function A.ratingTierEnum(format,rating)
if type(rating)~="number"then
return nil,"no-rating"
end
local ladder,reason=A.ratingLadder(format)
if ladder==nil then
return nil,reason
end
for i=#ladder.tiers,1,-1 do
if ladder.tiers[i].entry<=rating then
return ladder.tiers[i].enum
end
end
return nil,"out-of-range"
end
function A.tierWord(enum,raw)
if type(enum)=="number"then
local ok,word=pcall(rawget,_G,("PVP_RANK_%d_NAME"):format(enum))
if ok and type(word)=="string"and word~=""then
return word
end
end
if type(raw)~="string"or raw==""then
return nil,"no-name"
end
return raw:match(".* %- (.+)$")or raw
end
function A.tierRatingText(format,rating,fallback)
local text=tostring(rating)
local _,escape=A.ratingColour(format,rating)
if escape then
return escape..text.."|r"
end
if fallback then
return A.colorEscape(fallback)..text.."|r"
end
return text
end
function A.ratedHeard()
return heardRated
end
function A.ratingAsk()
if heardRated or ratedAsked then
return false
end
ratedAsked=true
if type(RequestRatedInfo)~="function"then
return false
end
ratedWaiting=true
pcall(RequestRatedInfo)
return true
end
function A.ratingTakeWaiting()
local was=ratedWaiting
ratedWaiting=false
return was
end
function A.ratingTierLines()
local lines={}
lines[#lines+1]=("rated info: %s%s"):format(heardRated and"heard"or"not heard yet",
ratedAsked and", asked by the window"or"")
local formats=A.ratedFormats()
for i=1,#formats do
local format=formats[i]
local ladder,reason=A.ratingLadder(format)
if ladder==nil then
lines[#lines+1]=("%s: no ladder (%s)"):format(A.formatLabel(format),tostring(reason))
else
lines[#lines+1]=("%s: %d tiers"):format(A.formatLabel(format),#ladder.tiers)
for j=1,#ladder.tiers do
local tier=ladder.tiers[j]
lines[#lines+1]=("  %s   enum %d   from %d"):format(tier.name or"unnamed",
tier.enum,tier.entry)
end
end
end
return lines
end
A.on("PVP_RATED_STATS_UPDATE",function()
heardRated=true
ladders={}
end)
