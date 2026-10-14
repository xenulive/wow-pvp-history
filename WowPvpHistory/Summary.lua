-- WowPvpHistory 0.68.22
-- Author:  Xenu-Sentinels
-- Project: wow-pvp-history
--          https://github.com/xenulive/wow-pvp-history
-- License: MIT, see LICENSE
local _,A=...
local LABELS={
bg="Unrated Battleground",
rbg="Rated Battleground",
blitz="Battleground Blitz",
["blitz-unrated"]="Blitz Brawl",
["arena-unrated"]="Skirmish",
arena2="Arena (2v2)",
arena3="Arena (3v3)",
arena="Arena",
shuffle="Solo Shuffle",
["shuffle-unrated"]="Shuffle Brawl",
duel="Duel",
world="World PvP",
unknown="Other",
}
local SHORT_LABELS={
bg="Unrated BG",
rbg="Rated BG",
blitz="Blitz",
["blitz-unrated"]="Blitz Brawl",
["arena-unrated"]="Skirmish",
arena2="2v2",
arena3="3v3",
arena="Arena",
shuffle="Shuffle",
["shuffle-unrated"]="Shuffle Brawl",
duel="Duel",
world="World",
unknown="Other",
}
local ALL_LABEL="All"
function A.formatShortLabel(format)
if format==nil then
return ALL_LABEL
end
return SHORT_LABELS[format]or tostring(format)
end
function A.formatLabel(format)
if format==nil then
return ALL_LABEL
end
return LABELS[format]or tostring(format)
end
function A.formatLabelList()
local out={}
for _,label in pairs(LABELS)do
out[#out+1]=label
end
table.sort(out)
return out
end
function A.storesResult(format)
return not(format=="shuffle"or format=="shuffle-unrated"or format=="world")
end
function A.formatHasOutcome(format)
return format~="world"
end
function A.carriesResult(record)
if type(record)~="table"then
return false
end
if A.storesResult(record.format)then
return true
end
return type(record.rounds)=="table"and#record.rounds>0
end
local LADDERLESS={
bg=true,
["blitz-unrated"]=true,
["arena-unrated"]=true,
["shuffle-unrated"]=true,
duel=true,
world=true,
unknown=true,
}
function A.movesRating(format)
if format==nil then
return true
end
return LADDERLESS[format]~=true
end
function A.oneLadder(format)
return format~=nil and format~="unknown"
end
function A.recordOnLadder(format,record)
if type(record)~="table"then
return false
end
if not A.movesRating(format)then
return true
end
return record.rated~=false
end
local MEMO_WALKERS={
summarize=true,
compTally=true,
specTally=true,
formatCounts=true,
cardTrend=true,
}
local paintMemo=nil
function A.openPaintMemo()
if paintMemo~=nil then
return false
end
paintMemo={walks={},held={}}
return true
end
function A.closePaintMemo()
paintMemo=nil
end
function A.paintMemoOpen()
return paintMemo~=nil
end
local function packed(...)
return{n=select("#",...),...}
end
local function keyPart(value)
local kind=type(value)
if kind=="nil"then
return"-"
elseif kind=="number"then
return"n"..("%.17g"):format(value)
elseif kind=="string"then
return"s"..#value..":"..value
end
return kind..":"..tostring(value)
end
local function memoKey(name,...)
local n=select("#",...)
while n>0 and select(n,...)==nil do
n=n-1
end
local parts={name}
for i=1,n do
parts[i+1]=keyPart((select(i,...)))
end
return table.concat(parts,"|")
end
function A.paintWalk(name,...)
local walker=A[name]
if paintMemo==nil or not MEMO_WALKERS[name]then
return walker(...)
end
local key=memoKey(name,...)
local held=paintMemo.walks[key]
if held==nil then
held=packed(walker(...))
paintMemo.walks[key]=held
end
return unpack(held,1,held.n)
end
function A.paintMemoSeed(name,values,...)
if paintMemo==nil or not MEMO_WALKERS[name]or type(values)~="table"then
return
end
paintMemo.walks[memoKey(name,...)]={n=values.n or#values,unpack(values,1,values.n or#values)}
end
function A.paintHeld(name,compute,...)
if paintMemo==nil then
return compute(...)
end
local key=memoKey(name,...)
local held=paintMemo.held[key]
if held==nil then
held=packed(compute(...))
paintMemo.held[key]=held
end
return unpack(held,1,held.n)
end
local ORDER={
"arena2","arena3","arena","shuffle","shuffle-unrated","arena-unrated",
"blitz","blitz-unrated","rbg","bg",
"duel","world","unknown",
}
local RANK={}
for i=1,#ORDER do
RANK[ORDER[i]]=i
end
local UNLISTED_RANK=#ORDER
local UNKNOWN_RANK=#ORDER+1
function A.recordedBy(record,character)
if character==nil then
return true
end
return type(record)=="table"and record.character==character
end
function A.formatCounts(character)
local counts={}
local db=A.db()
if not(db and type(db.matches)=="table")then
return counts
end
for i=1,#db.matches do
local record=db.matches[i]
local format=type(record)=="table"and record.format or nil
if format~=nil and A.recordedBy(record,character)then
counts[format]=(counts[format]or 0)+1
end
end
return counts
end
local function allCountWalk(character)
local matches=0
for _,count in pairs(A.paintWalk("formatCounts",character))do
matches=matches+count
end
local fixtures=0
local db=A.db()
if db and type(db.matches)=="table"then
for i=1,#db.matches do
local record=db.matches[i]
if type(record)=="table"and record.format~=nil and record[A.FIXTURE_KEY]==true
and A.recordedBy(record,character)then
fixtures=fixtures+1
end
end
end
local held=0
if type(A.incompleteList)=="function"then
local ok,list=pcall(A.incompleteList,character)
if ok and type(list)=="table"then
held=#list
end
end
return matches+held,held,fixtures
end
function A.allCount(character)
return A.paintHeld("allCount",allCountWalk,character)
end
local function characterListWalk()
local db=A.db()
if not(db and type(db.matches)=="table")then
return{},0
end
local seen={}
local function entry(guid)
local held=seen[guid]
if not held then
held={guid=guid,matches=0,left=0,generated=0}
seen[guid]=held
end
return held
end
for i=1,#db.matches do
local record=db.matches[i]
if type(record)=="table"and type(record.character)=="string"and record.character~=""then
local held=entry(record.character)
held.matches=held.matches+1
if record.fixture==true then
held.generated=held.generated+1
end
end
end
local unattributed=0
local unfinished=type(db.incomplete)=="table"and db.incomplete or{}
for i=1,#unfinished do
local left=unfinished[i]
if type(left)=="table"then
if type(left.character)=="string"and left.character~=""then
local owner=entry(left.character)
owner.left=owner.left+1
else
unattributed=unattributed+1
end
end
end
local registry=type(db.characters)=="table"and db.characters or{}
for guid,held in pairs(registry)do
if type(guid)=="string"and type(held)=="table"then
entry(guid)
end
end
local out={}
for guid,held in pairs(seen)do
local stored=registry[guid]
if type(stored)=="table"and type(stored.name)=="string"and stored.name~=""then
held.name=stored.name
held.realm=type(stored.realm)=="string"and stored.realm or nil
held.label=held.realm and(held.name.."-"..held.realm)or held.name
else
held.label="unresolved"
held.unresolved=true
end
held.total=held.matches+held.left
out[#out+1]=held
end
table.sort(out,function(a,b)
if a.total~=b.total then
return a.total>b.total
end
return a.guid<b.guid
end)
return out,unattributed
end
function A.characterList()
return A.paintHeld("characterList",characterListWalk)
end
function A.tabList(character)
local counts=A.paintWalk("formatCounts",character)
local present={}
local total=0
for format,count in pairs(counts)do
present[#present+1]=format
total=total+count
end
table.sort(present,function(a,b)
local ar=(a=="unknown"and UNKNOWN_RANK)or RANK[a]or UNLISTED_RANK
local br=(b=="unknown"and UNKNOWN_RANK)or RANK[b]or UNLISTED_RANK
if ar~=br then
return ar<br
end
return a<b
end)
local list={{format=nil,label=A.formatLabel(nil),matches=total}}
for i=1,#present do
list[#list+1]={
format=present[i],
label=A.formatLabel(present[i]),
matches=counts[present[i]],
}
end
return list
end
local LADDER_CONTINUITY=1000
local function ownRow(record)
local participants=record.participants
if type(participants)~="table"then
return nil
end
local guid=record.character
if guid==nil then
return nil
end
local row=participants[guid]
if type(row)~="table"then
return nil
end
return row
end
function A.recordVerdict(record,roundVerdict)
if type(record)~="table"then
return nil,false,false
end
local outcome=record.result
if outcome~=nil then
return outcome,false,false
end
local manual=record.manual
if type(manual)=="table"and manual.result~=nil and A.carriesResult(record)then
return manual.result,true,false
end
local verdict=roundVerdict
if verdict==nil then
verdict=A.roundsOutcome(record)
end
if verdict~=nil then
return verdict,false,true
end
return nil,false,false
end
function A.recordLevel(record,outcome,derived)
if outcome=="draw"then
return true
end
if not derived or type(A.roundsVerdict)~="function"then
return false
end
local ok,face=pcall(A.roundsVerdict,record)
return ok and face=="draw"
end
function A.roundsOutcome(record)
if type(A.roundsVerdict)~="function"then
return nil
end
local ok,face,won,played=pcall(A.roundsVerdict,record)
if not ok or face==nil or face=="unsummed"then
return nil
end
if face=="count"and won*2>played then
return"win",won,played
end
return"loss",won,played
end
function A.mapTally(format,season,character,bound,comp)
local rows,order={},{}
local considered,decided,unplaced=0,0,0
local db=A.db()
if not(db and type(db.matches)=="table")then
return order,considered,decided,unplaced
end
local function rowFor(name)
local row=rows[name]
if not row then
row={map=name,played=0,decided=0,wins=0,draws=0,ids={}}
rows[name]=row
order[#order+1]=row
end
return row
end
for i=1,#db.matches do
local record=db.matches[i]
local admitted=type(record)=="table"and(format==nil or record.format==format)
and(season==nil or A.recordSeason(record)==season)
and A.recordedBy(record,character)and A.recordSince(record,bound)
if admitted and comp~=nil then
local name=type(record.map)=="table"and record.map.name or nil
local outcomes=nil
if type(A.roundOutcomes)=="function"then
local answered,got=pcall(A.roundOutcomes,record)
outcomes=answered and got or nil
end
local listed=false
for r=1,(type(record.rounds)=="table"and#record.rounds or 0)do
local round=record.rounds[r]
if type(round)=="table"and A.roundCompKey(record,round)==comp then
considered=considered+1
if type(name)~="string"or name==""then
unplaced=unplaced+1
else
local row=rowFor(name)
row.played=row.played+1
if record.id~=nil and not listed then
listed=true
row.ids[#row.ids+1]=record.id
end
local won=nil
if type(outcomes)=="table"and type(outcomes[r])=="table"then
won=outcomes[r].won
end
if type(won)=="boolean"then
decided=decided+1
row.decided=row.decided+1
if won then
row.wins=row.wins+1
end
end
end
end
end
elseif admitted then
considered=considered+1
local name=type(record.map)=="table"and record.map.name or nil
if type(name)~="string"or name==""then
unplaced=unplaced+1
else
local row=rowFor(name)
row.played=row.played+1
if record.id~=nil then
row.ids[#row.ids+1]=record.id
end
local outcome,_,derived=A.recordVerdict(record)
if outcome~=nil then
decided=decided+1
row.decided=row.decided+1
if outcome=="win"then
row.wins=row.wins+1
elseif A.recordLevel(record,outcome,derived)then
row.draws=row.draws+1
end
end
end
end
end
for i=1,#order do
local row=order[i]
row.winRate=select(4,A.winRecord(row))
end
table.sort(order,function(a,b)
if a.played~=b.played then
return a.played>b.played
end
return a.map<b.map
end)
return order,considered,decided,unplaced
end
function A.lastMatch(format,season,character,bound,outcome)
local db=A.db()
if not(db and type(db.matches)=="table")then
return nil
end
local held,heldAt,heldClass,heldNumber=nil,nil,-1,0
for i=1,#db.matches do
local record=db.matches[i]
if type(record)=="table"and(format==nil or record.format==format)
and not(outcome and not A.formatHasOutcome(record.format))
and(season==nil or A.recordSeason(record)==season)
and A.recordedBy(record,character)and A.recordSince(record,bound)then
local at=A.recordEpoch(record)
local class,number=A.matchIdRank(record.id)
if at~=nil and(heldAt==nil or at>heldAt
or(at==heldAt and(class>heldClass or(class==heldClass and number>heldNumber))))then
held,heldAt,heldClass,heldNumber=record,at,class,number
end
end
end
return held
end
local TREND_WEEKS=12
local WEEK=7*86400
local TREND_KEYS={"winRate","matches","avgLength"}
local function trendPoints(key,buckets,seed)
local running={wins=seed.wins,decided=seed.decided,draws=seed.draws}
local points,lowest,highest={},nil,nil
for slot=1,TREND_WEEKS do
local bucket=buckets[slot]
local value=nil
if key=="winRate"then
if bucket then
running.wins=running.wins+bucket.wins
running.decided=running.decided+bucket.decided
running.draws=running.draws+bucket.draws
end
if bucket~=nil then
value=select(4,A.winRecord(running))
end
elseif bucket~=nil and key=="matches"then
value=bucket.count
elseif bucket~=nil and key=="avgLength"and bucket.timed>0 then
value=bucket.seconds/bucket.timed
end
if value~=nil then
points[#points+1]={at=(slot-1)/(TREND_WEEKS-1),value=value}
if lowest==nil or value<lowest then
lowest=value
end
if highest==nil or value>highest then
highest=value
end
end
end
if#points<2 then
return nil
end
local span=(highest or 0)-(lowest or 0)
for i=1,#points do
if key=="winRate"then
points[i].value=math.max(0,math.min(1,points[i].value))
elseif key=="matches"then
points[i].value=(highest or 0)>0 and points[i].value/highest or 0.5
elseif span>0 then
points[i].value=(points[i].value-lowest)/span
else
points[i].value=0.5
end
end
return points
end
function A.cardTrend(key,format,season,character,bound)
if key~=nil and key~="winRate"and key~="matches"and key~="avgLength"then
return nil
end
local db=A.db()
if not(db and type(db.matches)=="table")then
return nil
end
local newest=nil
local held={}
for i=1,#db.matches do
local record=db.matches[i]
if type(record)=="table"and(format==nil or record.format==format)
and(season==nil or A.recordSeason(record)==season)
and A.recordedBy(record,character)and A.recordSince(record,bound)then
local at=A.recordEpoch(record)
if at~=nil then
held[#held+1]={at=at,record=record}
if newest==nil or at>newest then
newest=at
end
end
end
end
if newest==nil then
return nil
end
local buckets={}
local running={wins=0,decided=0,draws=0}
for i=1,#held do
local back=math.floor((newest-held[i].at)/WEEK)
local record=held[i].record
local bucket=running
if back<TREND_WEEKS then
local slot=TREND_WEEKS-back
bucket=buckets[slot]
if not bucket then
bucket={count=0,decided=0,wins=0,draws=0,seconds=0,timed=0}
buckets[slot]=bucket
end
bucket.count=bucket.count+1
end
local outcome,_,derived=A.recordVerdict(record)
if outcome~=nil then
bucket.decided=bucket.decided+1
if outcome=="win"then
bucket.wins=bucket.wins+1
elseif A.recordLevel(record,outcome,derived)then
bucket.draws=bucket.draws+1
end
end
if back<TREND_WEEKS then
local seconds=type(record.duration)=="number"and record.duration or nil
if seconds~=nil and seconds>0 then
bucket.seconds=bucket.seconds+seconds
bucket.timed=bucket.timed+1
end
end
end
if key~=nil then
return trendPoints(key,buckets,running)
end
local out={}
for _,each in ipairs(TREND_KEYS)do
out[each]=trendPoints(each,buckets,running)
end
return out
end
function A.winRecord(held)
if type(held)~="table"or type(held.wins)~="number"or type(held.decided)~="number"then
return nil
end
local wins=held.wins
local draws=type(held.draws)=="number"and held.draws or 0
local losses=math.max(0,held.decided-wins-draws)
local rate=nil
if wins+losses>0 then
rate=wins/(wins+losses)
end
return wins,losses,draws,rate
end
function A.drawWord(format)
if format~=nil and not A.storesResult(format)then
return"at 3-3"
end
return"drawn"
end
function A.winRecordText(held,format)
local wins,losses,draws=A.winRecord(held)
if wins==nil or held.decided<=0 then
return nil
end
local text=("%d-%d"):format(wins,losses)
if draws>0 then
text=("%s, %d %s"):format(text,draws,A.drawWord(format))
end
return text
end
function A.summarize(format,season,character,bound)
local summary={
format=format,
season=season,
bound=bound,
character=character,
undated=0,
label=A.formatLabel(format),
matches=0,
decided=0,
wins=0,
draws=0,
manualDecided=0,
manualWon=0,
derivedDecided=0,
derivedWon=0,
skipped=0,
rejected=0,
zeroed=0,
durationCount=0,
roundsWon=0,
roundsPlayed=0,
roundLobbies=0,
roundShuffles=0,
lobbiesWon=0,
series={},
ladder=A.oneLadder(format),
}
local db=A.db()
if not(db and type(db.matches)=="table")then
return summary
end
local durationTotal,durationCount=0,0
local sides={[0]={decided=0,wins=0,draws=0},[1]={decided=0,wins=0,draws=0}}
local factionDecided,factionNoSide=0,0
local factionWins,factionDraws=0,0
local shortest,longest
local chainOut,chainSeason=nil,nil
local mmrFrom,mmrDropped=nil,nil
local verdicts,heldFirst,heldLast={},nil,nil
for i=1,#db.matches do
local record=db.matches[i]
local held=(season==nil or(A.recordSeason(record)==season))
and A.recordedBy(record,character)
if held and bound~=nil and(format==nil or record.format==format)
and A.recordEpoch(record)==nil then
summary.undated=summary.undated+1
end
held=held and A.recordSince(record,bound)
if held and(format==nil or record.format==format)then
summary.matches=summary.matches+1
if format==nil and record.format~=nil then
summary.formatMatches=summary.formatMatches or{}
summary.formatMatches[record.format]=(summary.formatMatches[record.format]or 0)+1
end
if format==nil then
local at=A.recordEpoch(record)
if at~=nil then
heldFirst=(heldFirst==nil or at<heldFirst)and at or heldFirst
heldLast=(heldLast==nil or at>heldLast)and at or heldLast
end
end
if type(record.duration)=="number"then
durationTotal=durationTotal+record.duration
durationCount=durationCount+1
if shortest==nil or record.duration<shortest then
shortest=record.duration
end
if longest==nil or record.duration>longest then
longest=record.duration
end
end
local roundVerdict,won,played=A.roundsOutcome(record)
if record.format=="shuffle"then
summary.roundShuffles=summary.roundShuffles+1
end
if roundVerdict~=nil then
summary.roundsWon=summary.roundsWon+won
summary.roundsPlayed=summary.roundsPlayed+played
summary.roundLobbies=summary.roundLobbies+1
if roundVerdict=="win"then
summary.lobbiesWon=summary.lobbiesWon+1
end
local threshold=math.floor(played/2)+1
if summary.roundThreshold==nil then
summary.roundThreshold=threshold
elseif summary.roundThreshold~=threshold then
summary.roundThreshold=false
end
end
local outcome,byHand,derived=A.recordVerdict(record,roundVerdict)
if outcome~=nil then
summary.decided=summary.decided+1
local level=A.recordLevel(record,outcome,derived)
if level then
summary.draws=summary.draws+1
end
if format==nil then
verdicts[#verdicts+1]={at=A.recordEpoch(record),won=outcome=="win",
level=level,format=record.format}
end
if byHand then
summary.manualDecided=summary.manualDecided+1
elseif derived then
summary.derivedDecided=summary.derivedDecided+1
end
if outcome=="win"then
summary.wins=summary.wins+1
if byHand then
summary.manualWon=summary.manualWon+1
elseif derived then
summary.derivedWon=summary.derivedWon+1
end
end
local side,onBattleground=A.recordFaction(record)
if onBattleground then
factionDecided=factionDecided+1
if outcome=="win"then
factionWins=factionWins+1
elseif level then
factionDraws=factionDraws+1
end
if side==nil then
factionNoSide=factionNoSide+1
else
sides[side].decided=sides[side].decided+1
if outcome=="win"then
sides[side].wins=sides[side].wins+1
elseif level then
sides[side].draws=sides[side].draws+1
end
end
end
end
local onLadder=summary.ladder and A.recordOnLadder(summary.format,record)
local row=onLadder and ownRow(record)or nil
local rating=row and row.rating
local change=row and type(row.ratingChange)=="number"and row.ratingChange or nil
local mmrAfter=type(row)=="table"and type(row.mmrPost)=="number"and row.mmrPost or 0
local silent=A.ladderSilent(row)
if row and type(rating)=="number"and change~=nil and not silent then
local out=rating+change
local mmr=mmrAfter~=0 and mmrAfter or nil
local pointSeason=A.recordSeason(record)
local gap=nil
if chainOut~=nil and pointSeason==chainSeason and rating~=0 then
gap=math.abs(rating-chainOut)
end
if out==0 then
summary.skipped=summary.skipped+1
summary.zeroed=summary.zeroed+1
A.trace("ladder/reject",{
format=format,
id=record.id,
ratingFigure=rating,
out=out,
mmr=mmrAfter,
from=chainOut,
season=pointSeason,
reason="zero-rating",
},"data")
chainOut,chainSeason=out,pointSeason
elseif gap~=nil and gap>LADDER_CONTINUITY then
summary.skipped=summary.skipped+1
summary.rejected=summary.rejected+1
A.trace("ladder/reject",{
format=format,
id=record.id,
ratingFigure=rating,
out=out,
mmr=mmrAfter,
from=chainOut,
gap=gap,
season=pointSeason,
reason="departure",
},"data")
else
chainOut,chainSeason=out,pointSeason
summary.lastFrom=rating
local measured=change
if measured==0 and mmrAfter==0
and(type(row.mmrPre)~="number"or row.mmrPre==0)then
measured=nil
end
summary.ratingChange=measured
summary.rating=out
if mmr~=nil then
summary.mmr=mmr
local before=type(row.mmrPre)=="number"and row.mmrPre~=0
and row.mmrPre or nil
if before~=nil then
summary.mmrChange=mmr-before
else
summary.mmrChange=nil
end
mmrFrom,mmrDropped=record.id,nil
else
if summary.mmr~=nil then
mmrDropped={id=record.id,from=mmrFrom}
end
summary.mmr,summary.mmrChange,mmrFrom=nil,nil,nil
end
if summary.peak==nil or out>summary.peak then
summary.peak=out
end
summary.series[#summary.series+1]={
id=record.id,
rating=out,
mmr=mmr,
season=pointSeason,
at=record.openedAt or record.completedAt,
from=rating,
}
end
elseif onLadder then
summary.skipped=summary.skipped+1
end
end
end
summary.durationCount=durationCount
summary.shortest=shortest
summary.longest=longest
if durationCount>0 then
summary.avgDuration=math.floor(durationTotal/durationCount)
end
if#summary.series>0 then
summary.ratingFrom=summary.series[1].rating
summary.ratingFromReset=summary.series[1].from==0
end
local _,_,_,rate=A.winRecord(summary)
summary.winRate=rate
if factionDecided>0 then
summary.factions=sides
summary.factionDecided=factionDecided
summary.factionNoSide=factionNoSide
summary.factionWins=factionWins
summary.factionDraws=factionDraws
end
if summary.roundsPlayed>0 then
summary.roundRate=summary.roundsWon/summary.roundsPlayed
end
if summary.roundLobbies>0 then
summary.lobbyRate=summary.lobbiesWon/summary.roundLobbies
end
if summary.mmr~=nil and summary.rating~=nil then
summary.mmrGap=summary.mmr-summary.rating
end
if mmrDropped~=nil then
A.trace("summary/mmr",{format=summary.format,id=mmrDropped.id,fromId=mmrDropped.from,
reason="no-mmr"},"data")
end
if format==nil then
summary.verdicts=verdicts
end
if format==nil and#verdicts>0 then
local from=heldFirst
if bound~=nil and(from==nil or bound>from)then
from=bound
end
local to=heldLast or time()
if from~=nil then
summary.winLoss=A.winLossColumns(verdicts,from,to)
end
end
return summary
end
local function dayOpening(at)
local t=date("*t",at)
return time({year=t.year,month=t.month,day=t.day,hour=0,min=0,sec=0})
end
local function columnOpening(at,per)
local t=date("*t",at)
local day,month=t.day,t.month
if per=="week"then
day=day-(t.wday+5)%7
elseif per=="month"then
day=1
end
local open=time({year=t.year,month=month,day=day,hour=0,min=0,sec=0})
local nextDay,nextMonth=day+1,month
if per=="week"then
nextDay=day+7
elseif per=="month"then
nextDay,nextMonth=1,month+1
end
return open,time({year=t.year,month=nextMonth,day=nextDay,hour=0,min=0,sec=0})
end
local DAYS_TO_WEEKS=91
local WEEKS_TO_MONTHS=27
function A.winLossColumns(verdicts,from,to)
local first,last=dayOpening(from),dayOpening(to)
local days=math.floor((last-first)/86400+0.5)+1
local per="week"
if days<DAYS_TO_WEEKS then
per="day"
elseif days>WEEKS_TO_MONTHS*7 then
per="month"
end
local out={per=per,columns={},won=0,lost=0,drawn=0,tallest=0,undated=0,
firstDay=first,lastDay=last}
local open=columnOpening(first,per)
local byOpening={}
while open<=last and#out.columns<4000 do
local _,after=columnOpening(open,per)
local column={from=open,to=dayOpening(after-43200),won=0,lost=0,drawn=0}
out.columns[#out.columns+1]=column
byOpening[open]=column
open=after
end
for i=1,#verdicts do
local verdict=verdicts[i]
local column=verdict.at~=nil and byOpening[(columnOpening(verdict.at,per))]or nil
if column==nil then
out.undated=out.undated+1
elseif verdict.won then
column.won=column.won+1
out.won=out.won+1
elseif verdict.level then
column.drawn=column.drawn+1
out.drawn=out.drawn+1
else
column.lost=column.lost+1
out.lost=out.lost+1
end
end
for i=1,#out.columns do
local column=out.columns[i]
out.tallest=math.max(out.tallest,column.won,column.lost)
end
return out
end
function A.winLossEnds(held)
local columns=type(held)=="table"and held.columns or nil
if type(columns)~="table"or#columns==0 then
return nil
end
local from,to=columns[1].from,columns[#columns].to
if type(held.firstDay)=="number"and held.firstDay>from then
from=held.firstDay
end
if type(held.lastDay)=="number"and held.lastDay<to then
to=held.lastDay
end
return from,to
end
function A.winLossDayText(at,withYear)
if type(at)~="number"then
return nil
end
local text=("%d %s"):format(tonumber(date("%d",at)),date("%b",at))
if withYear then
text=("%s %s"):format(text,date("%Y",at))
end
return text
end
function A.winLossSpanText(column)
if type(column)~="table"or type(column.from)~="number"then
return nil
end
local day=A.winLossDayText
if type(column.to)~="number"or dayOpening(column.to)==dayOpening(column.from)then
return day(column.from)
end
return("%s to %s"):format(day(column.from),day(column.to))
end
function A.winLossHoverText(column)
local span=A.winLossSpanText(column)
if span==nil then
return nil
end
local text=("%s, %d-%d"):format(span,column.won or 0,column.lost or 0)
if(column.drawn or 0)>0 then
text=("%s, %d drawn"):format(text,column.drawn)
end
return text
end
local HEAT_BLOCKS={
{from=2,to=12,label="02-12"},
{from=12,to=16,label="12-16"},
{from=16,to=19,label="16-19"},
{from=19,to=21,label="19-21"},
{from=21,to=23,label="21-23"},
{from=23,to=2,label="23-02"},
}
local WEEKDAYS={"Mon","Tue","Wed","Thu","Fri","Sat","Sun"}
local LAST_RESULTS=20
function A.heatBlocks()
local out={}
for i=1,#HEAT_BLOCKS do
out[i]=HEAT_BLOCKS[i].label
end
return out
end
function A.heatDays()
local out={}
for i=1,#WEEKDAYS do
out[i]=WEEKDAYS[i]
end
return out
end
function A.heatCell(at)
if type(at)~="number"then
return nil
end
local t=date("*t",at)
local day=(t.wday+5)%7+1
local hour=t.hour
for i=1,#HEAT_BLOCKS do
local block=HEAT_BLOCKS[i]
if block.from<block.to then
if hour>=block.from and hour<block.to then
return day,i
end
elseif hour>=block.from or hour<block.to then
return day,i
end
end
return nil
end
function A.weekLabel(monday)
if type(monday)~="number"then
return nil
end
return("w/c %d %s"):format(tonumber(date("%d",monday)),date("%b",monday))
end
function A.weekOpening(at)
if type(at)~="number"then
return nil
end
return(columnOpening(at,"week"))
end
local function resultMark(verdict)
if verdict.level then
return"D"
end
return verdict.won and"W"or"L"
end
function A.allOverview(season,character,bound,now)
local ok,summary=pcall(A.paintWalk,"summarize",nil,season,character,bound)
if not ok or type(summary)~="table"then
return nil
end
local verdicts=type(summary.verdicts)=="table"and summary.verdicts or{}
local floor=A.rankFloor("cells")or 0
local wins,losses,draws=A.winRecord(summary)
local out={
record={
matches=summary.matches,
wins=wins,
losses=losses,
draws=draws,
undecided=summary.matches-summary.decided,
},
formats={},
unplaced=0,
weeks={},
cells={},
undated=0,
floor=floor,
}
local tabs=A.tabList(character)
local byFormat={}
for i=1,#tabs do
local format=tabs[i].format
if format~=nil then
local row={format=format,label=tabs[i].label,played=0,wins=0,losses=0,
draws=0,results={}}
out.formats[#out.formats+1]=row
byFormat[format]=row
end
end
local played=type(summary.formatMatches)=="table"and summary.formatMatches or{}
for format,count in pairs(played)do
if byFormat[format]~=nil then
byFormat[format].played=count
end
end
local first,last=nil,nil
for i=1,#verdicts do
local at=verdicts[i].at
if type(at)=="number"then
first=(first==nil or at<first)and at or first
last=(last==nil or at>last)and at or last
end
end
local newest=type(now)=="number"and now or time()
if season~=nil and type(A.seasonNewest)=="function"and season~=A.seasonNewest()and last~=nil then
newest=last
end
local byWeek={}
if first~=nil then
local open=columnOpening(bound~=nil and math.max(bound,0)or first,"week")
local stop=columnOpening(newest,"week")
while open<=stop and#out.weeks<520 do
local week={from=open,label=A.weekLabel(open),won=0,lost=0,draws=0}
out.weeks[#out.weeks+1]=week
byWeek[open]=week
local _,after=columnOpening(open,"week")
open=after
end
end
for d=1,#WEEKDAYS do
local row={}
for b=1,#HEAT_BLOCKS do
row[b]={won=0,lost=0,draws=0,decided=0}
end
out.cells[d]=row
end
for i=1,#verdicts do
local verdict=verdicts[i]
local row=verdict.format~=nil and byFormat[verdict.format]or nil
if row==nil then
out.unplaced=out.unplaced+1
else
if verdict.level then
row.draws=row.draws+1
elseif verdict.won then
row.wins=row.wins+1
else
row.losses=row.losses+1
end
row.results[#row.results+1]=resultMark(verdict)
end
local week=type(verdict.at)=="number"and byWeek[(columnOpening(verdict.at,"week"))]or nil
local day,block=A.heatCell(verdict.at)
if week==nil or day==nil then
out.undated=out.undated+1
end
if week~=nil then
if verdict.level then
week.draws=week.draws+1
elseif verdict.won then
week.won=week.won+1
else
week.lost=week.lost+1
end
end
if day~=nil then
local cell=out.cells[day][block]
if verdict.level then
cell.draws=cell.draws+1
elseif verdict.won then
cell.won=cell.won+1
else
cell.lost=cell.lost+1
end
end
end
for _,week in ipairs(out.weeks)do
week.rate=select(4,A.winRecord({wins=week.won,decided=week.won+week.lost+week.draws,
draws=week.draws}))
end
for d=1,#out.cells do
for b=1,#out.cells[d]do
local cell=out.cells[d][b]
cell.decided=cell.won+cell.lost
if cell.decided>=floor and cell.decided>0 then
cell.rate=cell.won/cell.decided
end
end
end
for _,row in ipairs(out.formats)do
row.rate=select(4,A.winRecord({wins=row.wins,decided=row.wins+row.losses+row.draws,
draws=row.draws}))
local kept={}
for i=math.max(1,#row.results-LAST_RESULTS+1),#row.results do
kept[#kept+1]=row.results[i]
end
row.last=kept
row.results=nil
local read,own=false,nil
if A.movesRating(row.format)then
read,own=pcall(A.paintWalk,"summarize",row.format,season,character,bound)
end
if read and type(own)=="table"and own.rating~=nil then
row.rating=own.rating
row.peak=own.peak
if own.ratingFromReset~=true then
row.from=own.ratingFrom
end
if type(A.ratingTierName)=="function"then
row.tier=A.ratingTierName(row.format,own.rating)
end
end
end
return out
end
function A.overviewSeasonText(row)
if type(row)~="table"or row.rating==nil then
return""
end
local parts={}
if row.from~=nil and row.from~=row.rating then
parts[#parts+1]=("from %d"):format(math.floor(row.from))
end
if row.peak~=nil and row.peak~=row.rating then
parts[#parts+1]=("peak %d"):format(math.floor(row.peak))
end
return table.concat(parts,", ")
end
function A.opponentTally(format,character,season,bound)
local rows,missing={},0
local db=A.db()
if not(db and type(db.matches)=="table")then
return rows,missing
end
local byName={}
for i=1,#db.matches do
local record=db.matches[i]
if type(record)=="table"and(format==nil or record.format==format)
and A.recordedBy(record,character)
and(season==nil or A.recordSeason(record)==season)and A.recordSince(record,bound)then
local name=record.opponentName
if type(name)=="string"and name~=""then
local row=byName[name]
if not row then
row={name=name,matches=0,wins=0,losses=0,order=#rows+1}
row.bare,row.realm=A.nameParts(name)
byName[name]=row
rows[#rows+1]=row
end
row.matches=row.matches+1
local stamp=record.completedAt or record.openedAt
if type(stamp)=="string"and(row.lastAt==nil or stamp>row.lastAt)then
row.lastAt=stamp
end
if row.key==nil then
row.key=A.duelOpponentKey(record)
end
local outcome=A.recordVerdict(record)
if outcome=="win"then
row.wins=row.wins+1
elseif outcome=="loss"then
row.losses=row.losses+1
end
elseif format~=nil then
missing=missing+1
end
end
end
table.sort(rows,function(a,b)
if a.matches~=b.matches then
return a.matches>b.matches
end
return a.order<b.order
end)
return rows,missing
end
function A.duelOpponentKey(record)
local participants=type(record)=="table"and record.participants or nil
if type(participants)~="table"then
return nil
end
local name=record.opponentName
for key,p in pairs(participants)do
if type(key)=="string"and type(p)=="table"and p.side=="against"and key~=record.character
and key~=name and key~=A.bareName(name)then
return key
end
end
return nil
end
function A.duelHow(record)
if type(record)~="table"then
return nil
end
if record.outcome=="knockout"then
return"knockout"
end
if record.outcome=="retreat"then
local verdict=A.recordVerdict(record)
if verdict=="win"then
return"they fled"
elseif verdict=="loss"then
return"you fled"
end
end
return nil
end
function A.classTokens(keys)
local out,wanted={},0
local need={}
for key in pairs(type(keys)=="table"and keys or{})do
need[key]=true
wanted=wanted+1
end
local db=A.db()
if wanted==0 or not(db and type(db.matches)=="table")then
return out
end
for i=#db.matches,1,-1 do
local participants=type(db.matches[i])=="table"and db.matches[i].participants or nil
if type(participants)=="table"then
for key in pairs(need)do
local p=participants[key]
if type(p)=="table"and type(p.classToken)=="string"and p.classToken~=""then
out[key]=p.classToken
need[key]=nil
wanted=wanted-1
end
end
if wanted==0 then
break
end
end
end
return out
end
local COMP_FORMATS={arena=true,arena2=true,arena3=true,shuffle=true}
local ROUND_FORMATS={shuffle=true}
local ROUND_ENEMIES=3
local function keyMembers(members)
if type(members)~="table"or#members==0 then
return nil
end
table.sort(members,function(a,b)
if a.spec~=b.spec then
return a.spec<b.spec
end
return tostring(a.classToken)<tostring(b.classToken)
end)
local parts={}
for m=1,#members do
local member=members[m]
if type(member)~="table"or type(member.spec)~="string"then
return nil
end
parts[m]=member.spec.."/"..tostring(member.classToken)
end
return table.concat(parts,"+")
end
local function enemyComp(record)
if type(A.rosterSplit)~="function"then
return nil
end
local split=A.rosterSplit(record)
if not(split and#split.enemy>0)then
return nil
end
if type(A.botCount)=="function"then
local _,allBots=A.botCount(split.enemy)
if allBots then
return nil
end
end
local members={}
for i=1,#split.enemy do
local p=split.enemy[i].p
local spec=type(p.spec)=="string"and p.spec~=""and p.spec or nil
if spec==nil then
return nil
end
members[i]={spec=spec,classToken=p.classToken,class=p.class,
damage=type(p.damage)=="number"and p.damage or nil}
end
return members
end
function A.compKey(record)
local members=enemyComp(record)
if members==nil then
return nil
end
local key=keyMembers(members)
if key==nil then
return nil
end
return key,members
end
function A.roundCompKey(record,round)
if type(A.roundSides)~="function"then
return nil
end
local _,foes=A.roundSides(record,round)
if type(foes)~="table"or#foes~=ROUND_ENEMIES then
return nil
end
if type(A.botCount)=="function"then
local _,allBots=A.botCount(foes)
if allBots then
return nil
end
end
local members={}
for i=1,#foes do
local p=foes[i].p
local spec=type(p)=="table"and type(p.spec)=="string"and p.spec~=""and p.spec or nil
if spec==nil then
return nil
end
members[i]={spec=spec,classToken=p.classToken,class=p.class}
end
local key=keyMembers(members)
if key==nil then
return nil
end
return key,members
end
local function compWinRate(row)
local draws=row.draws or 0
return select(4,A.winRecord({wins=row.wins,decided=row.wins+row.losses+draws,draws=draws}))
end
function A.compRecordText(row)
if type(row)~="table"or type(row.wins)~="number"or type(row.losses)~="number"then
return nil
end
local text=("%d-%d"):format(row.wins,row.losses)
local draws=tonumber(row.draws)or 0
if draws>0 then
text=text..(", %d drawn"):format(draws)
end
return text
end
function A.compAllDrawnText(format,count)
count=tonumber(count)or 0
local rounds=A.compRounds(format)
return("%d %s%s drawn in every %s, not ranked"):format(count,rounds and"composition"or"comp",
count==1 and""or"s",rounds and"round"or"game")
end
function A.compShareText(row)
if type(row)~="table"or type(row.members)~="table"then
return nil
end
local parts={}
for i=1,#row.members do
local m=row.members[i]
if type(m)=="table"and type(m.share)=="number"then
parts[#parts+1]=("%s %d%%"):format(tostring(m.spec),
math.floor(m.share*100+0.5))
end
end
if#parts==0 then
return nil
end
return"who does the damage: "..table.concat(parts,", ")
end
function A.compFormat(format)
return type(format)=="string"and COMP_FORMATS[format]==true
end
function A.compRounds(format)
return type(format)=="string"and ROUND_FORMATS[format]==true
end
function A.compCountName(format)
return A.compRounds(format)and"RDS"or"GAMES"
end
function A.compUnit(format)
return A.compRounds(format)and"round"or"record"
end
local function tallyRow(byKey,ranked,key,members)
local row=byKey[key]
if row then
return row
end
local kept={}
for m=1,#members do
kept[m]={spec=members[m].spec,classToken=members[m].classToken,
class=members[m].class}
end
row={
key=key,members=kept,
memberDamage={},damageTotal=0,
games=0,wins=0,losses=0,draws=0,
ratingDelta=0,durationTotal=0,durationCount=0,
order=#ranked+1,
}
byKey[key]=row
ranked[#ranked+1]=row
return row
end
local function tallyRounds(record,byKey,ranked)
local stored=type(record.rounds)=="table"and record.rounds or nil
if not stored or#stored==0 then
return 0,0,0
end
local mine=ownRow(record)
local previousRating=nil
if type(mine)=="table"and type(A.ladderSilent)=="function"and not A.ladderSilent(mine)
and type(mine.rating)=="number"then
previousRating=mine.rating
end
local previousEpoch=type(record.openedEpoch)=="number"and record.openedEpoch or nil
local outcomes=nil
if type(A.roundOutcomes)=="function"then
local ok,answered=pcall(A.roundOutcomes,record)
if ok then
outcomes=answered
end
end
local seen,missed,undecided=0,0,0
for i=1,#stored do
local round=stored[i]
seen=seen+1
local key,members=nil,nil
if type(round)=="table"then
key,members=A.roundCompKey(record,round)
end
local won=nil
if type(outcomes)=="table"and type(outcomes[i])=="table"then
won=outcomes[i].won
end
if key==nil or members==nil then
missed=missed+1
elseif type(won)~="boolean"then
undecided=undecided+1
else
local row=tallyRow(byKey,ranked,key,members)
row.games=row.games+1
row.rounds=row.rounds or{}
row.rounds[#row.rounds+1]={id=record.id,round=i,won=won}
row.ids=row.ids or{}
if row.ids[#row.ids]~=record.id then
row.ids[#row.ids+1]=record.id
end
if won==true then
row.wins=row.wins+1
else
row.losses=row.losses+1
end
if type(round.ratingPost)=="number"and type(previousRating)=="number"then
row.ratingDelta=row.ratingDelta+(round.ratingPost-previousRating)
end
if type(round.endedEpoch)=="number"and type(previousEpoch)=="number"then
local seconds=round.endedEpoch-previousEpoch
if seconds>=0 then
row.durationTotal=row.durationTotal+seconds
row.durationCount=row.durationCount+1
end
end
end
if type(round)=="table"and type(round.ratingPost)=="number"then
previousRating=round.ratingPost
else
previousRating=nil
end
if type(round)=="table"then
if type(round.endedEpoch)=="number"then
previousEpoch=round.endedEpoch
end
end
end
return seen,missed,undecided
end
function A.compTally(format,season,character,bound)
local rows,skipped,belowFloor,considered,undecided,rankedCount={},0,0,0,0,0
local allDrawn=0
if not A.compFormat(format)then
return rows,skipped,belowFloor,considered,undecided,rankedCount,allDrawn
end
local db=A.db()
if not(db and type(db.matches)=="table")then
return rows,skipped,belowFloor,considered,undecided,rankedCount,allDrawn
end
local roundFormat=A.compRounds(format)
local byKey,ranked={},{}
for i=1,#db.matches do
local record=db.matches[i]
local held=type(record)=="table"
and(season==nil or A.recordSeason(record)==season)
and A.recordedBy(record,character)
and A.recordSince(record,bound)
if held and record.format==format and roundFormat then
local seen,missed,unrated=tallyRounds(record,byKey,ranked)
considered=considered+seen
skipped=skipped+missed
undecided=undecided+unrated
elseif held and record.format==format then
considered=considered+1
local key,members=A.compKey(record)
local decided=record.result=="win"or record.result=="loss"or record.result=="draw"
if key==nil or members==nil then
skipped=skipped+1
elseif not decided then
undecided=undecided+1
else
local row=tallyRow(byKey,ranked,key,members)
row.games=row.games+1
row.ids=row.ids or{}
row.ids[#row.ids+1]=record.id
if record.result=="win"then
row.wins=row.wins+1
elseif record.result=="draw"then
row.draws=row.draws+1
else
row.losses=row.losses+1
end
for m=1,#members do
local member=members[m]
local d=type(member)=="table"and member.damage or nil
if type(d)=="number"then
row.memberDamage[m]=(row.memberDamage[m]or 0)+d
row.damageTotal=row.damageTotal+d
end
end
local mine=ownRow(record)
if mine and type(mine.ratingChange)=="number"then
row.ratingDelta=row.ratingDelta+mine.ratingChange
end
if type(record.duration)=="number"then
row.durationTotal=row.durationTotal+record.duration
row.durationCount=row.durationCount+1
end
end
end
end
local floor=A.rankFloor("comps")
local listFloor=A.metric("compListGames")
for i=1,#ranked do
local row=ranked[i]
local rate=row.games>0 and compWinRate(row)or nil
local decided=row.wins+row.losses
if rate==nil and decided==0 and row.draws>0 then
allDrawn=allDrawn+1
end
if rate~=nil and decided<floor then
belowFloor=belowFloor+1
end
if rate~=nil and row.games>=listFloor then
row.ranked=decided>=floor
if row.ranked then
rankedCount=rankedCount+1
end
row.winRate=rate
if row.damageTotal>0 then
for m=1,#row.members do
local d=row.memberDamage[m]
if type(d)=="number"then
row.members[m].share=d/row.damageTotal
end
end
end
if row.durationCount>0 then
row.avgDuration=math.floor(row.durationTotal/row.durationCount)
end
rows[#rows+1]=row
end
end
table.sort(rows,function(a,b)
if a.ranked~=b.ranked then
return a.ranked==true
end
if not a.ranked then
if a.games~=b.games then
return a.games>b.games
end
return a.order<b.order
end
local ar,br=a.winRate,b.winRate
if ar~=br then
if ar==nil then
return false
end
if br==nil then
return true
end
return ar<br
end
if a.games~=b.games then
return a.games>b.games
end
return a.order<b.order
end)
return rows,skipped,belowFloor,considered,undecided,rankedCount,allDrawn
end
function A.compText(members)
if type(members)~="table"or#members==0 then
return nil
end
local parts={}
for i=1,#members do
local m=members[i]
local who=tostring(m.spec)
if type(m.class)=="string"and m.class~=""then
who=who.." "..m.class
end
parts[i]=who
end
return table.concat(parts," + ")
end
function A.specTally(format,season,character,bound,comp)
local against,alongside,readable,undecided={},{},0,0
if not(A.compFormat(format)and A.compRounds(format))then
return against,alongside,readable,undecided
end
local db=A.db()
if not(db and type(db.matches)=="table")then
return against,alongside,readable,undecided
end
local byKey={against={},alongside={}}
local order={against=against,alongside=alongside}
local metIn,unsettled={},{}
local function specKeys(entries,into)
for i=1,#entries do
local p=entries[i].p
local spec=type(p)=="table"and type(p.spec)=="string"and p.spec~=""and p.spec
or nil
if spec~=nil then
into[spec.."/"..tostring(p.classToken)]=true
end
end
end
local function fold(side,entries,won,seen)
for i=1,#entries do
local p=entries[i].p
local spec=type(p)=="table"and type(p.spec)=="string"and p.spec~=""and p.spec
or nil
if spec~=nil then
local key=spec.."/"..tostring(p.classToken)
if not seen[key]then
seen[key]=true
local row=byKey[side][key]
if not row then
row={key=key,spec=spec,classToken=p.classToken,class=p.class,
rounds=0,wins=0,losses=0,order=#order[side]+1}
byKey[side][key]=row
order[side][#order[side]+1]=row
end
row.rounds=row.rounds+1
if won==true then
row.wins=row.wins+1
elseif won==false then
row.losses=row.losses+1
end
end
end
end
end
for i=1,#db.matches do
local record=db.matches[i]
local held=type(record)=="table"
and(season==nil or A.recordSeason(record)==season)
and A.recordedBy(record,character)
and A.recordSince(record,bound)
if held and record.format==format and type(record.rounds)=="table"then
local outcomes=nil
if type(A.roundOutcomes)=="function"then
local answered,got=pcall(A.roundOutcomes,record)
if answered then
outcomes=got
end
end
for r=1,#record.rounds do
local round=record.rounds[r]
local key=type(round)=="table"and A.roundCompKey(record,round)or nil
if key~=nil and(comp==nil or key==comp)then
local mates,foes=A.roundSides(record,round)
if type(mates)=="table"and type(foes)=="table"then
local won=nil
if type(outcomes)=="table"and type(outcomes[r])=="table"then
won=outcomes[r].won
end
local inRound={}
specKeys(foes,inRound)
specKeys(mates,inRound)
if type(won)~="boolean"then
undecided=undecided+1
for specKey in pairs(inRound)do
unsettled[specKey]=(unsettled[specKey]or 0)+1
end
else
readable=readable+1
fold("against",foes,won,{})
fold("alongside",mates,won,{})
for specKey in pairs(inRound)do
local met=metIn[specKey]
if not met then
met={ids={},seen={}}
metIn[specKey]=met
end
if record.id~=nil and not met.seen[record.id]then
met.seen[record.id]=true
met.ids[#met.ids+1]=record.id
end
end
end
end
end
end
end
end
local function rate(row)
local decided=row.wins+row.losses
if decided==0 then
return nil
end
return row.wins/decided
end
for _,list in ipairs({against,alongside})do
for i=1,#list do
list[i].winRate=rate(list[i])
end
end
table.sort(against,function(a,b)
if a.winRate~=b.winRate then
if a.winRate==nil then return false end
if b.winRate==nil then return true end
return a.winRate<b.winRate
end
if a.rounds~=b.rounds then return a.rounds>b.rounds end
return a.order<b.order
end)
table.sort(alongside,function(a,b)
if a.winRate~=b.winRate then
if a.winRate==nil then return false end
if b.winRate==nil then return true end
return a.winRate>b.winRate
end
if a.rounds~=b.rounds then return a.rounds>b.rounds end
return a.order<b.order
end)
return against,alongside,readable,undecided,metIn,unsettled
end
local ROUND_CELL={
id=function(row)
if row.id==nil then
return"-"
end
return("#%s"):format(tostring(row.id))
end,
round=function(row)
return("R%d"):format(row.round)
end,
pair=function(row)
return tostring(row.pair or"-")
end,
result=function(row)
return row.won and"WON"or"LOST"
end,
delta=function(row)
return row.delta or"-"
end,
rating=function(row)
if type(row.ratingPost)~="number"then
return"-"
end
return tostring(row.ratingPost)
end,
}
local SPEC_ABSENT={
against="never yet against you",
alongside="never yet alongside you",
}
local SPEC_CELL={
spec=function(row)
return A.chipText(row)
end,
againstRounds=function(row)
if row.against==nil then
return SPEC_ABSENT.against
end
return tostring(row.against.rounds)
end,
againstRecord=function(row)
if row.against==nil then
return""
end
return("%d-%d"):format(row.against.wins,row.against.losses)
end,
againstRate=function(row)
if row.against==nil then
return""
end
return A.percentText(row.against.winRate)or"-"
end,
alongRounds=function(row)
if row.alongside==nil then
return SPEC_ABSENT.alongside
end
return tostring(row.alongside.rounds)
end,
alongRecord=function(row)
if row.alongside==nil then
return""
end
return("%d-%d"):format(row.alongside.wins,row.alongside.losses)
end,
alongRate=function(row)
if row.alongside==nil then
return""
end
return A.percentText(row.alongside.winRate)or"-"
end,
}
function A.compRoundRows(format,key,season,character,bound)
local out={}
if not(A.compRounds(format)and type(key)=="string")then
return out
end
local db=A.db()
if not(db and type(db.matches)=="table")then
return out
end
for i=1,#db.matches do
local record=db.matches[i]
if type(record)=="table"and record.format==format and type(record.rounds)=="table"
and(season==nil or A.recordSeason(record)==season)
and A.recordedBy(record,character)and A.recordSince(record,bound)then
local mine=ownRow(record)
local previous=nil
if type(mine)=="table"and type(A.ladderSilent)=="function"and not A.ladderSilent(mine)
and type(mine.rating)=="number"then
previous=mine.rating
end
local outcomes=nil
if type(A.roundOutcomes)=="function"then
local answered,got=pcall(A.roundOutcomes,record)
if answered then
outcomes=got
end
end
for r=1,#record.rounds do
local round=record.rounds[r]
local roundKey=type(round)=="table"and A.roundCompKey(record,round)or nil
local won=nil
if type(outcomes)=="table"and type(outcomes[r])=="table"then
won=outcomes[r].won
end
if roundKey==key and type(won)=="boolean"then
local mates=A.roundSides(record,round)
local who={}
if type(mates)=="table"then
for m=1,#mates do
who[m]=A.chipText(mates[m].p)
end
end
local delta=nil
if type(round.ratingPost)=="number"and type(previous)=="number"then
delta=A.signedText(round.ratingPost-previous)
end
local subject={
id=record.id,
round=r,
pair=#who>0 and table.concat(who," + ")or"-",
won=won,
delta=delta,
ratingPost=round.ratingPost,
}
local columns=A.rowColumns("round")
local cells=A.columnCells(subject,columns,ROUND_CELL)
out[#out+1]={
id=record.id,round=r,
cells=cells,columns=columns,
text=table.concat(cells,"  "),
}
end
if type(round)=="table"and type(round.ratingPost)=="number"then
previous=round.ratingPost
end
end
end
end
return out
end
function A.paneFillers(which)
if which=="round"then
return ROUND_CELL
end
if which=="specpair"then
return SPEC_CELL
end
return nil
end
local RANK_FLOORS={
specs=20,
comps=10,
maps=8,
players=6,
cells=4,
}
function A.rankFloor(kind)
return RANK_FLOORS[kind]
end
function A.specCardFloor()
return A.rankFloor("specs")
end
function A.specMerged(format,season,character,bound,comp)
local against,alongside,readable,undecided,metIn,unsettled=
A.paintWalk("specTally",format,season,character,bound,comp)
local byKey,out={},{}
local function slot(row)
local held=byKey[row.key]
if not held then
local met=type(metIn)=="table"and metIn[row.key]or nil
held={key=row.key,spec=row.spec,class=row.class,
classToken=row.classToken,matches=met and met.ids or{},
unsettled=type(unsettled)=="table"and unsettled[row.key]or 0}
byKey[row.key]=held
out[#out+1]=held
end
return held
end
for i=1,#against do
slot(against[i]).against=against[i]
end
for i=1,#alongside do
slot(alongside[i]).alongside=alongside[i]
end
return out,readable,undecided
end
local SPEC_SORTS={
spec={field="name",
ascending="by name",descending="by name, last first"},
againstRounds={side="against",field="rounds",
ascending="fewest met against you first",descending="most met against you first"},
againstRecord={side="against",field="record",
ascending="fewest won against you first",descending="most won against you first"},
againstRate={side="against",field="winRate",
ascending="hardest first",descending="easiest first"},
alongRounds={side="alongside",field="rounds",
ascending="fewest met alongside you first",descending="most met alongside you first"},
alongRecord={side="alongside",field="record",
ascending="fewest won alongside you first",descending="most won alongside you first"},
alongRate={side="alongside",field="winRate",
ascending="worst alongside you first",descending="best alongside you first"},
}
function A.specSideRanked(side)
return type(side)=="table"and side.winRate~=nil
and(side.rounds or 0)>=(A.rankFloor("specs")or 0)
end
local SPEC_SORT_DEFAULT="againstRate"
function A.specSortKnown(key)
return type(key)=="string"and SPEC_SORTS[key]~=nil
end
function A.specSortDefault()
return SPEC_SORT_DEFAULT,true
end
function A.specSortWords(key,ascending)
local sort=SPEC_SORTS[key]or SPEC_SORTS[SPEC_SORT_DEFAULT]
return ascending==true and sort.ascending or sort.descending
end
function A.specSortOpens(key)
local columns=A.rowColumns("specpair")
if type(columns)=="table"then
for i=1,#columns do
if columns[i].sort==key then
return columns[i].first~="descending"
end
end
end
return true
end
function A.specSorted(rows,key,ascending)
local sort=SPEC_SORTS[key]or SPEC_SORTS[SPEC_SORT_DEFAULT]
local up=ascending==true
local out={}
if type(rows)~="table"then
return out
end
for i=1,#rows do
out[i]=rows[i]
end
local function valueOf(row)
if sort.field=="name"then
return A.chipText(row)
end
local side=row[sort.side]
if type(side)~="table"then
return nil
end
if sort.field=="record"then
return(side.wins or 0)*100000-(side.losses or 0)
end
return side[sort.field]
end
table.sort(out,function(a,b)
local sideA,sideB=a[sort.side],b[sort.side]
if sort.side~=nil then
local tierA,tierB=A.specSideRanked(sideA),A.specSideRanked(sideB)
if tierA~=tierB then
return tierA
end
end
local valueA,valueB=valueOf(a),valueOf(b)
if valueA~=valueB then
if valueA==nil then
return false
end
if valueB==nil then
return true
end
if up then
return valueA<valueB
end
return valueA>valueB
end
local roundsA=sideA and sideA.rounds or 0
local roundsB=sideB and sideB.rounds or 0
if roundsA~=roundsB then
return roundsA>roundsB
end
return tostring(a.key)<tostring(b.key)
end)
return out
end
local CARD_KINDS={"hardest","best","swing"}
local CARD_TITLES={
hardest="HARDEST OPPONENT",
best="BEST TEAMMATE",
swing="WORTH HAVING",
}
local MERGED_TITLES={
["hardest+best"]="HARDEST OPPONENT AND BEST TEAMMATE",
["hardest+swing"]="HARDEST OPPONENT AND WORTH HAVING",
["best+swing"]="BEST TEAMMATE AND WORTH HAVING",
["hardest+best+swing"]="ONE SPEC TOPS ALL THREE",
}
local CARD_NONE_NAME="Nothing qualified"
local function cardEvidence(kind,row)
if kind=="hardest"then
return row.against and row.against.rounds or 0
end
if kind=="best"then
return row.alongside and row.alongside.rounds or 0
end
local against=row.against and row.against.rounds or 0
local alongside=row.alongside and row.alongside.rounds or 0
return against<alongside and against or alongside
end
local function cardScore(kind,row,floor)
if kind=="hardest"then
local side=row.against
if not(side and side.winRate~=nil)then
return nil
end
return-side.winRate,side.rounds>=floor
end
if kind=="best"then
local side=row.alongside
if not(side and side.winRate~=nil)then
return nil
end
return side.winRate,side.rounds>=floor
end
local against,alongside=row.against,row.alongside
if not(against and alongside and against.winRate~=nil and alongside.winRate~=nil)then
return nil
end
return alongside.winRate-against.winRate,
against.rounds>=floor and alongside.rounds>=floor
end
local function cardTops(kind,row,score,best,bestScore)
if best==nil then
return true
end
if score~=bestScore then
return score>bestScore
end
local mine,theirs=cardEvidence(kind,row),cardEvidence(kind,best)
if mine~=theirs then
return mine>theirs
end
return tostring(row.key)<tostring(best.key)
end
function A.mergedCardTitle(kinds)
if type(kinds)~="table"or#kinds<2 then
return nil
end
return MERGED_TITLES[table.concat(kinds,"+")]
end
local function collapseCards(cards)
local order,groups={},{}
for i=1,#cards do
local key=tostring(cards[i].key)
if groups[key]==nil then
groups[key]={}
order[#order+1]=key
end
local group=groups[key]
group[#group+1]=cards[i]
end
local out={}
for i=1,#order do
local group=groups[order[i]]
if#group==1 then
out[#out+1]=group[1]
else
local kinds={}
local lead=group[1]
for g=1,#group do
kinds[g]=group[g].kind
end
local card={
kind="collapsed",
kinds=kinds,
title=A.mergedCardTitle(kinds),
key=lead.key,
spec=lead.spec,
class=lead.class,
classToken=lead.classToken,
name=lead.name,
floor=lead.floor,
againstRounds=lead.againstRounds,
alongRounds=lead.alongRounds,
rounds=math.min(lead.againstRounds or 0,lead.alongRounds or 0),
folded=group,
}
out[#out+1]=card
end
end
return out
end
local function noneCard(kind,floor)
return{
kind="none",
kinds={kind},
title=CARD_TITLES[kind],
name=CARD_NONE_NAME,
floor=floor,
rounds=0,
}
end
local function cardRowOf(cards,missing)
local merged=collapseCards(cards)
if#merged==0 then
return{}
end
local placed,out={},{}
for _,kind in ipairs(CARD_KINDS)do
local found=nil
for i=1,#merged do
if not placed[i]then
for k=1,#merged[i].kinds do
if merged[i].kinds[k]==kind then
found=i
end
end
end
end
if found~=nil then
placed[found]=true
out[#out+1]=merged[found]
elseif missing[kind]~=nil then
out[#out+1]=missing[kind]
end
end
return out
end
function A.specCards(format,season,character,bound,comp)
local rows,readable,undecided=A.specMerged(format,season,character,bound,comp)
local floor=A.specCardFloor()
local out,missing={},{}
for _,kind in ipairs(CARD_KINDS)do
local best,bestScore=nil,nil
for i=1,#rows do
local row=rows[i]
local score,qualified=cardScore(kind,row,floor)
if score~=nil and qualified and cardTops(kind,row,score,best,bestScore)then
best,bestScore=row,score
end
end
if best~=nil then
local card={
kind=kind,
kinds={kind},
title=CARD_TITLES[kind],
key=best.key,
spec=best.spec,
class=best.class,
classToken=best.classToken,
name=A.chipText(best),
floor=floor,
rounds=cardEvidence(kind,best),
againstRounds=best.against and best.against.rounds or nil,
alongRounds=best.alongside and best.alongside.rounds or nil,
}
if kind=="hardest"then
card.rate=A.percentText(best.against.winRate)
elseif kind=="best"then
card.rate=A.percentText(best.alongside.winRate)
else
card.rate=A.signedText(A.swingPoints(best.against,best.alongside))
end
out[#out+1]=card
else
missing[kind]=noneCard(kind,floor)
end
end
return cardRowOf(out,missing),floor,rows,readable,undecided
end
local SPEC_ENDS={
{kind="hardest",title="HARDEST AGAINST YOU",side="against",sort="againstRate",up=true},
{kind="easiest",title="EASIEST AGAINST YOU",side="against",sort="againstRate",up=false},
{kind="best",title="BEST WITH YOU",side="alongside",sort="alongRate",up=false},
{kind="worst",title="WORST WITH YOU",side="alongside",sort="alongRate",up=true},
}
function A.specEnds(rows)
local out={}
for i=1,#SPEC_ENDS do
local held=SPEC_ENDS[i]
local card={kind=held.kind,title=held.title}
local sorted=A.specSorted(rows,held.sort,held.up)
local top=sorted[1]
local side=type(top)=="table"and top[held.side]or nil
if type(side)=="table"and A.specSideRanked(side)then
card.key=top.key
card.name=A.chipText(top)
card.spec=top.spec
card.class=top.class
card.classToken=top.classToken
card.winRate=side.winRate
card.rate=A.percentText(side.winRate)
card.tone=A.winRateTone(side.winRate)
card.record=("%d-%d over %d"):format(side.wins or 0,side.losses or 0,side.rounds or 0)
end
out[i]=card
end
return out
end
local function specPaneSide(side)
if type(side)~="table"then
return nil
end
return("%d %s   %d-%d   %s"):format(side.rounds,side.rounds==1 and"round"or"rounds",
side.wins,side.losses,A.percentText(side.winRate)or"-")
end
function A.specPaneSentence(row)
if type(row)~="table"then
return""
end
local floor=A.specCardFloor()
local against,alongside=row.against,row.alongside
local said=""
if against and alongside and against.winRate~=nil and alongside.winRate~=nil then
if against.rounds>=floor and alongside.rounds>=floor then
local points=A.swingPoints(against,alongside)
if points>0 then
said=("Your rounds go %d %s better with it on your side than with it against you.")
:format(points,points==1 and"point"or"points")
elseif points<0 then
said=("Your rounds go %d %s better with it against you than on your side.")
:format(-points,points==-1 and"point"or"points")
else
said="Your rounds go the same with it on your side as with it against you."
end
end
end
return said
end
function A.matchRowLook(id)
local record=type(A.match)=="function"and A.match(id)or nil
if type(record)~="table"then
return nil
end
local columns=A.flatRowColumns(record.format,{record})
local cells=type(columns)=="table"and A.rowColumnCells(record,record.format,nil,columns)or nil
local held={}
if type(cells)=="table"then
for c=1,#columns do
held[columns[c].key]=cells[c]
end
end
if held.day==nil then
local stamp=A.flatRowCells(record,nil,{{key="day"}})
held.day=type(stamp)=="table"and stamp[1]or nil
end
local verdict,won,played=A.roundsVerdict(record)
local _,changeTone=A.ratingDelta(record)
local _,out=A.recordLadderPair(record)
return{
cells=held,
id=("#%s"):format(tostring(record.id)),
rounds=(verdict~=nil and verdict~="unsummed"and type(played)=="number"and played>0)
and{won=won,played=played}or nil,
resultTone=A.resultTone(record),
changeTone=changeTone,
ratingOut=out,
format=record.format,
}
end
function A.metNamesLine(met)
local names={kind="specMetNames",wheres={},whens={}}
local any=false
for i=1,#(type(met)=="table"and met or{})do
local look=type(met[i])=="table"and met[i].look or nil
if type(look)=="table"then
any=true
met[i].names=names
local cells=type(look.cells)=="table"and look.cells or{}
if type(cells.where)=="string"then
names.wheres[#names.wheres+1]=cells.where
end
if type(cells.day)=="string"then
names.whens[#names.whens+1]=cells.day
end
end
end
return any and names or nil
end
function A.matchLineText(id)
local record=type(A.match)=="function"and A.match(id)or nil
if type(record)~="table"then
return nil
end
local columns=A.rowColumns(record.format,{record})
local cells=type(columns)=="table"and A.rowColumnCells(record,record.format,nil,columns)
or nil
local held={}
if type(cells)=="table"then
for c=1,#columns do
held[columns[c].key]=cells[c]
end
end
local parts={("#%s"):format(tostring(record.id))}
for _,key in ipairs({"map","result"})do
if type(held[key])=="string"and held[key]~=""then
parts[#parts+1]=held[key]
end
end
return table.concat(parts,"   ")
end
function A.specPaneLines(row,picked)
local lines={}
if type(row)~="table"then
return lines
end
lines[#lines+1]={kind="specHead",text=A.chipText(row),classToken=row.classToken,
sub=picked==false and"your hardest opponent"or nil}
lines[#lines+1]={kind="specSide",key="AGAINST YOU",text=specPaneSide(row.against),
absent=SPEC_ABSENT.against}
lines[#lines+1]={kind="specSide",key="ALONGSIDE YOU",text=specPaneSide(row.alongside),
absent=SPEC_ABSENT.alongside}
local say=A.specPaneSentence(row)
if say~=""then
lines[#lines+1]={kind="specSay",text=say}
end
local ids=type(row.matches)=="table"and row.matches or{}
local met={}
for i=#ids,1,-1 do
local text=A.matchLineText(ids[i])
if text then
met[#met+1]={kind="specMet",id=ids[i],text=text,look=A.matchRowLook(ids[i])}
end
end
lines[#lines+1]={kind="specMetHead",key="MET IN",
text=("%d %s"):format(#met,#met==1 and"match"or"matches")}
lines[#lines+1]=A.metNamesLine(met)
for i=1,#met do
lines[#lines+1]=met[i]
end
return lines
end
local SPEC_STANDING={hardest="your hardest opponent",best="your best teammate"}
function A.specStanding(cards,key)
if type(cards)~="table"or key==nil then
return nil
end
for i=1,#cards do
local card=cards[i]
if card.kind~="none"and card.key==key and type(card.kinds)=="table"then
for k=1,#card.kinds do
if SPEC_STANDING[card.kinds[k]]then
return SPEC_STANDING[card.kinds[k]]
end
end
end
end
return nil
end
function A.specDetailLines(row,standing)
local out={}
if type(row)~="table"then
return out
end
if type(standing)=="string"and standing~=""then
out[#out+1]={kind="specNote",text=standing,stay=true}
end
local lines=A.specPaneLines(row,true)
for i=1,#lines do
local line=lines[i]
if line.kind~="specHead"and line.kind~="specSide"then
line.stay=true
out[#out+1]=line
end
end
return out
end
function A.specRows(format,season,character,sort,ascending,bound)
local merged,readable,undecided=A.specMerged(format,season,character,bound)
local rows=A.specSorted(merged,sort,ascending)
return A.specElements(rows),readable,undecided,rows
end
function A.specElements(rows)
local columns=A.rowColumns("specpair")
local out={}
if type(rows)~="table"then
return out
end
for i=1,#rows do
local row=rows[i]
local cells=A.columnCells(row,columns,SPEC_CELL)
local spans,style=nil,nil
for _,pair in ipairs({{"against","againstRounds"},{"alongside","alongRounds"}})do
local side,opening=pair[1],pair[2]
if row[side]==nil then
local group=nil
for c=1,#columns do
if columns[c].key==opening then
group=columns[c].group
end
end
local wide=0
if group~=nil then
for c=1,#columns do
if columns[c].group==group then
wide=wide+1
end
end
end
if wide>1 then
spans=spans or{}
spans[opening]=wide
style=style or{}
style[opening]={role="rowNote",tone="dimmer"}
end
end
end
local ranks=0
for _,pair in ipairs({{"against","againstRounds","againstRecord","againstRate"},
{"alongside","alongRounds","alongRecord","alongRate"}})do
local side=row[pair[1]]
if side~=nil then
style=style or{}
if A.specSideRanked(side)then
ranks=ranks+1
style[pair[4]]={role="bodyText",tone=A.winRateTone(side.winRate)or"dim"}
else
for p=2,4 do
style[pair[p]]={role="bodyText",tone="underText"}
end
end
end
end
local tint=nil
if ranks==0 then
style=style or{}
style.spec={role="bodyText",tone="underText"}
elseif type(A.classColor)=="function"then
local read,r,g,b,alpha=pcall(A.classColor,row.classToken)
if read and type(r)=="number"then
tint={spec={r,g,b,alpha}}
end
end
local said={}
for c=1,#cells do
if cells[c]~=nil and cells[c]~=""then
said[#said+1]=cells[c]
end
end
out[#out+1]={
cells=cells,
columns=columns,
spans=spans,
cellTint=tint,
cellStyle=style,
text=table.concat(said,"  "),
specKey=row.key,
specIcon=type(A.specIcon)=="function"and A.specIcon(row.classToken,row.spec)or nil,
classToken=row.classToken,
faint=ranks==0 or nil,
}
end
return out
end
local function lobbyRate(side)
local decided=side.wins+side.losses
if decided==0 then
return nil
end
return side.wins/decided
end
function A.lobbyTally(record)
local rows,byGuid={},{}
if type(record)~="table"then
return rows,0,0
end
local rounds=type(record.rounds)=="table"and record.rounds or nil
if not rounds then
return rows,0,0
end
if type(A.roundCompKey)~="function"or type(A.roundSides)~="function"then
return rows,0,#rounds
end
local function slot(entry)
local guid=type(entry)=="table"and entry.guid or nil
if type(guid)~="string"then
return nil
end
local row=byGuid[guid]
if not row then
local p=type(entry.p)=="table"and entry.p or{}
row={
key=guid,
guid=guid,
spec=type(p.spec)=="string"and p.spec~=""and p.spec or nil,
class=p.class,
classToken=p.classToken,
order=#rows+1,
with={rounds=0,wins=0,losses=0,at={}},
against={rounds=0,wins=0,losses=0,at={}},
seats={},
}
byGuid[guid]=row
rows[#rows+1]=row
end
return row
end
local function fold(side,entries,won,at)
for i=1,#entries do
local row=slot(entries[i])
local held=row and row[side]or nil
if held then
held.rounds=held.rounds+1
held.at[at]=true
if won then
held.wins=held.wins+1
else
held.losses=held.losses+1
end
end
end
end
local function seat(entries,side,at)
for i=1,#entries do
local row=slot(entries[i])
if row then
row.seats[at]=side
end
end
end
local read,typed=0,0
for r=1,#rounds do
local round=rounds[r]
local key=type(round)=="table"and A.roundCompKey(record,round)or nil
if key~=nil then
local mates,foes=A.roundSides(record,round)
if type(mates)=="table"and type(foes)=="table"then
seat(mates,"with",r)
seat(foes,"against",r)
local won,byHand=nil,nil
if type(A.roundResult)=="function"then
local answered,got,_,hand=pcall(A.roundResult,record,r)
if answered then
won,byHand=got,hand
end
end
if type(won)=="boolean"then
read=read+1
if byHand==true then
typed=typed+1
end
fold("with",mates,won,r)
fold("against",foes,won,r)
end
end
end
end
for i=1,#rows do
local row=rows[i]
row.with.winRate=lobbyRate(row.with)
row.against.winRate=lobbyRate(row.against)
row.swing=A.lobbySwing(row)
end
return rows,read,#rounds,typed
end
function A.lobbySwing(row)
if type(row)~="table"or type(row.with)~="table"or type(row.against)~="table"then
return nil
end
local with=A.percentPoints(row.with.winRate)
local against=A.percentPoints(row.against.winRate)
if with==nil or against==nil then
return nil
end
return with-against
end
local LOBBY_SORTS={
withRate={side="with",field="winRate",column="WITH WON"},
againstRate={side="against",field="winRate",column="AGAINST WON"},
swing={field="swing",column="SWING"},
damage={cell="damage",column="DAMAGE"},
wins={objective=1,column="WINS"},
kb={cell="kb",column="KB"},
dispels={cell="dispels",column="DISP"},
}
local function lobbyReading(row,sort)
if type(row)~="table"then
return nil
end
local value
if sort.cell~=nil or sort.objective~=nil then
local cells=type(row.joined)=="table"and type(row.joined.cells)=="table"and row.joined.cells or nil
if cells==nil then
return nil
end
if sort.cell~=nil then
value=cells[sort.cell]
else
value=type(cells.objectiveValues)=="table"and cells.objectiveValues[sort.objective]or nil
end
elseif sort.side==nil then
value=row[sort.field]
else
local side=row[sort.side]
value=side and side[sort.field]or nil
end
if type(value)~="number"or value~=value then
return nil
end
return value
end
function A.lobbySortValue(row,key)
return lobbyReading(row,LOBBY_SORTS[key]or LOBBY_SORTS.swing)
end
local LOBBY_SORT_DEFAULT="swing"
function A.lobbySortKnown(key)
return type(key)=="string"and LOBBY_SORTS[key]~=nil
end
function A.lobbySortDefault()
return LOBBY_SORT_DEFAULT,false
end
function A.lobbySortWords(key,ascending)
local sort=LOBBY_SORTS[key]or LOBBY_SORTS[LOBBY_SORT_DEFAULT]
return("by %s, %s"):format(sort.column,ascending==true and"low to high"or"high to low")
end
function A.lobbySortOpens(key)
for _,which in ipairs({"lobby","lobbyPane"})do
local columns=A.rowColumns(which)
if type(columns)=="table"then
for i=1,#columns do
if columns[i].sort==key then
return columns[i].first~="descending"
end
end
end
end
return true
end
function A.lobbySorted(rows,key,ascending)
local sort=LOBBY_SORTS[key]or LOBBY_SORTS[LOBBY_SORT_DEFAULT]
local up=ascending==true
local out={}
if type(rows)~="table"then
return out
end
for i=1,#rows do
out[i]=rows[i]
end
local function reading(row)
return lobbyReading(row,sort)
end
local function evidence(row)
if sort.cell~=nil or sort.objective~=nil then
return 0
end
if sort.side==nil then
local with=row.with and row.with.rounds or 0
local against=row.against and row.against.rounds or 0
return with<against and with or against
end
local side=row[sort.side]
return side and side.rounds or 0
end
table.sort(out,function(a,b)
local valueA,valueB=reading(a),reading(b)
if valueA~=valueB then
if valueA==nil then return false end
if valueB==nil then return true end
return up and valueA<valueB or(not up and valueA>valueB)
end
local roundsA,roundsB=evidence(a),evidence(b)
if roundsA~=roundsB then
return roundsA>roundsB
end
return tostring(a.key)<tostring(b.key)
end)
return out
end
local LOBBY_CELL={
spec=function(row)
return A.chipText(row)
end,
withRecord=function(row)
if row.with.rounds==0 then
return"-"
end
return("%d-%d"):format(row.with.wins,row.with.losses)
end,
withRate=function(row)
return A.percentText(row.with.winRate)or"-"
end,
againstRecord=function(row)
if row.against.rounds==0 then
return"-"
end
return("%d-%d"):format(row.against.wins,row.against.losses)
end,
againstRate=function(row)
return A.percentText(row.against.winRate)or"-"
end,
swing=function(row)
return A.signedText(row.swing)or"-"
end,
}
local function joinedCell(field)
return function(row)
local joined=type(row.joined)=="table"and row.joined or nil
local value=joined and joined[field]or nil
if value==nil then
return"-"
end
return tostring(value)
end
end
LOBBY_CELL.name=joinedCell("name")
LOBBY_CELL.damage=joinedCell("damage")
LOBBY_CELL.wins=joinedCell("wins")
LOBBY_CELL.kb=joinedCell("kb")
LOBBY_CELL.dispels=joinedCell("dispels")
local LOBBY_ROUND_LANES=6
local SEAT_WORD={with="WITH",against="VS"}
for r=1,LOBBY_ROUND_LANES do
LOBBY_CELL["round"..r]=function(row)
local seat=type(row.seats)=="table"and row.seats[r]or nil
return SEAT_WORD[seat]or"-"
end
end
local function withStoredRounds(set,record)
if type(set)~="table"then
return nil
end
local rounds=type(record)=="table"and type(record.rounds)=="table"and#record.rounds or 0
local lanes=0
for i=1,#set do
if set[i].lane=="round"then
lanes=lanes+1
end
end
local out={}
for i=1,#set do
local column=set[i]
if column.lane~="round"or(rounds<=lanes and column.round<=rounds)then
out[#out+1]=column
end
end
return out
end
function A.lobbyColumns(record)
return withStoredRounds(A.rowColumns("lobby"),record)
end
function A.lobbyPaneColumns(record,count)
local set=withStoredRounds(A.rowColumns("lobbyPane"),record)
if set==nil then
return nil
end
local objective=nil
if type(A.objectiveColumns)=="function"then
local columns=A.objectiveColumns(record)
objective=type(columns)=="table"and columns[1]or nil
end
local out={}
for i=1,#set do
local column={}
for key,value in pairs(set[i])do
column[key]=value
end
if column.lane=="name"and type(count)=="number"then
column.name=("ROSTER %d"):format(count)
end
if column.key=="wins"then
if type(objective)=="table"and type(objective.short)=="string"then
column.name=objective.short
out[#out+1]=column
end
else
out[#out+1]=column
end
end
return out
end
function A.lobbyPaneDraws(record)
if type(record)~="table"or A.lobbyPaneColumns(record)==nil then
return false
end
local rows=A.lobbyTally(record)
return type(rows)=="table"and#rows>0
end
function A.lobbyYou(record,columns)
local table_=type(A.roundTable)=="function"and A.roundTable(record)or nil
local cells,rounds,words={},{},{}
for i=1,type(columns)=="table"and#columns or 0 do
local column=columns[i]
if column.lane=="spec"then
cells[i]="YOU"
words[#words+1]="YOU"
elseif column.lane=="round"then
local row=table_ and type(table_.rounds)=="table"and table_.rounds[column.round]or nil
local entry
if type(row)=="table"and row.result~=nil then
entry={round=column.round,won=row.won,tone=row.tone,
word=row.result..(row.byHand and"*"or""),
state=row.byHand and"typed"or"captured"}
else
entry={round=column.round,word="-",state="open"}
end
if type(A.roundMeterLines)=="function"and type(record)=="table"
and type(record.character)=="string"then
entry.meter=A.roundMeterLines(record,record.character,column.round)
end
rounds[i]=entry
cells[i]=entry.word
words[#words+1]=entry.word
else
cells[i]=""
end
end
return{key="you",cells=cells,rounds=rounds,text=table.concat(words,"  ")}
end
function A.lobbyFillers(which)
if which=="lobby"or which=="lobbyPane"then
return LOBBY_CELL
end
return nil
end
function A.lobbyRows(record,sort,ascending,columns,joined)
local tally,read,total,typed=A.lobbyTally(record)
for i=1,type(tally)=="table"and#tally or 0 do
local row=tally[i]
row.joined=type(joined)=="table"and type(row.guid)=="string"and joined[row.guid]or nil
end
local rows=A.lobbySorted(tally,sort,ascending)
if type(columns)~="table"then
columns=A.lobbyColumns(record)
end
local out={}
if type(columns)~="table"then
return out,read,total,tally,typed
end
for i=1,#rows do
local row=rows[i]
local cells=A.columnCells(row,columns,LOBBY_CELL)
local tint=nil
if type(A.classColor)=="function"then
local got,r,g,b,alpha=pcall(A.classColor,row.classToken)
if got and type(r)=="number"then
tint={spec={r,g,b,alpha}}
end
end
local meter=nil
local lanes=type(columns)=="table"and columns or{}
if type(A.roundMeterLines)=="function"and type(row.guid)=="string"then
for c=1,#lanes do
local round=lanes[c].lane=="round"and lanes[c].round or nil
local lines=round and A.roundMeterLines(record,row.guid,round)or nil
if lines and round then
local held=meter or{}
held[round]=lines
meter=held
end
end
end
out[#out+1]={
key=row.key,
cells=cells,
columns=columns,
cellTint=tint,
meter=meter,
joined=row.joined,
text=table.concat(cells or{},"  "),
}
end
return out,read,total,tally,typed
end
function A.lobbyDrawn(rows,columns)
local out={}
if type(rows)~="table"or type(columns)~="table"then
return out
end
local at={}
for i=1,#columns do
if type(columns[i])=="table"and columns[i].key then
at[columns[i].key]=i
end
end
local function counted(cells,key)
local index=at[key]
local text=index and cells and cells[index]or nil
if type(text)~="string"then
return nil
end
if text=="-"then
return 0
end
local wins,losses=text:match("^(%d+)%-(%d+)$")
if wins==nil then
return nil
end
return tonumber(wins)+tonumber(losses)
end
for i=1,#rows do
local cells=type(rows[i])=="table"and rows[i].cells or nil
local label=at.spec and cells and cells[at.spec]or nil
out[i]={
spec=type(label)=="string"and label or nil,
with=counted(cells,"withRecord"),
against=counted(cells,"againstRecord"),
}
end
return out
end
local LOBBY_ROTATIONS={
{
seat="damage",
pairs={{with=2,against=4,count=3},{with=3,against=3,count=2}},
said="The format gave you each damage spec twice and each healer three times, "
.."so nothing here waits on a count.",
},
{
seat="healer",
pairs={{with=3,against=3,count=4},{with=0,against=6,count=1}},
said="The format gave you each damage spec three times each way and the other healer "
.."against you in every round, so nothing here waits on a count.",
},
}
function A.lobbyClaim(rows,read,total)
if type(rows)~="table"or type(read)~="number"or type(total)~="number"then
return nil
end
if read<=0 or read~=total then
return nil
end
for i=1,#LOBBY_ROTATIONS do
local rotation=LOBBY_ROTATIONS[i]
local want,held=0,{}
for p=1,#rotation.pairs do
want=want+rotation.pairs[p].count
held[p]=0
end
if want==#rows then
local matched=0
for r=1,#rows do
local row=rows[r]
local with=type(row.with)=="table"and row.with.rounds or nil
local against=type(row.against)=="table"and row.against.rounds or nil
for p=1,#rotation.pairs do
local pair=rotation.pairs[p]
if with==pair.with and against==pair.against
and held[p]<pair.count then
held[p]=held[p]+1
matched=matched+1
break
end
end
end
if matched==want then
return rotation
end
end
end
return nil
end
function A.lobbyOpposites(rows,read)
if type(rows)~="table"or type(read)~="number"or read<=0 then
return nil
end
for i=1,#rows do
for j=i+1,#rows do
local one,two=rows[i],rows[j]
local atOne=type(one.with)=="table"and one.with.at or nil
local atTwo=type(two.with)=="table"and two.with.at or nil
if type(atOne)=="table"and type(atTwo)=="table"
and one.with.rounds+two.with.rounds==read then
local overlap=false
for at in pairs(atOne)do
if atTwo[at]then
overlap=true
break
end
end
if not overlap then
return one,two
end
end
end
end
return nil
end
local LOBBY_OWN_RATE="Both figures are your own win rate, never theirs."
function A.lobbyOwnRate()
return LOBBY_OWN_RATE
end
local REFUSAL_CLAUSE={
tally="the results read did not fit the scoreboard's rounds won, so none was kept",
untotalled="the scoreboard recorded no rounds won, so nothing could be checked",
difference="a reading moved backwards or by more rounds than were played",
["summed-over"]="a round was missed, so the rounds do not sum",
["summed-short"]="the scoreboard's rounds won fall short of the rounds played, so the rounds do not sum",
}
function A.lobbyCaption(claim,read,total,opposites,typed,opts)
opts=type(opts)=="table"and opts or{}
if opts.pane==true then
return{}
end
local out={}
local hand=type(typed)=="number"and typed>0 and typed or nil
local handWords=hand and(hand==1 and"1 round was entered by hand."
or("%d rounds were entered by hand."):format(hand))or nil
local function handSentence(said)
if handWords==nil then
return said
end
return said.." "..handWords
end
local held=type(claim)=="table"and type(claim.said)=="string"
if held then
out[#out+1]=handSentence(claim.said)
elseif type(read)=="number"and type(total)=="number"and total>0 then
if read<total then
local missing=total-read
local entered=hand and(", %d entered by hand"):format(hand)or""
local reason=REFUSAL_CLAUSE[opts.refusal]
if reason~=nil then
out[#out+1]=("%d of %d rounds recorded no winner%s: %s."):format(missing,total,
entered,reason)
else
out[#out+1]=("%d of %d rounds recorded no winner%s, so these counts are what was "
.."recorded rather than what the format dealt."):format(missing,total,entered)
end
else
out[#out+1]=handSentence(
"These counts are what was recorded rather than what the format dealt.")
end
end
out[#out+1]=LOBBY_OWN_RATE
if held and opposites then
out[#out+1]="The two healers are opposites by construction, one on each side "
.."every round."
end
return out
end
function A.lobbyClaimFaults(claim,drawn)
local out={}
if type(claim)~="table"or type(claim.pairs)~="table"or type(drawn)~="table"then
return out
end
local left={}
local want=0
for p=1,#claim.pairs do
left[p]=claim.pairs[p].count
want=want+claim.pairs[p].count
end
for i=1,#drawn do
local row=type(drawn[i])=="table"and drawn[i]or{}
local matched=false
for p=1,#claim.pairs do
local pair=claim.pairs[p]
if row.with==pair.with and row.against==pair.against and left[p]>0 then
left[p]=left[p]-1
matched=true
break
end
end
if not matched then
out[#out+1]={
what="caption-contradicted",
where=tostring(row.spec or"an unnamed row"),
why=("the record claims the %s rotation and this row reads %s with you and %s "
.."against"):format(tostring(claim.seat),tostring(row.with),
tostring(row.against)),
}
end
end
if#drawn~=want then
out[#out+1]={
what="caption-contradicted",
where="the table",
why=("the record claims the %s rotation, which is %d rows, and the table drew %d")
:format(tostring(claim.seat),want,#drawn),
}
end
return out
end
local lobbyClaims={}
function A.noteLobbyClaim(id,claim,drawn)
if type(drawn)~="table"then
return false
end
lobbyClaims[tostring(id)]={
id=id,
claim=type(claim)=="table"and claim or nil,
drawn=drawn,
}
return true
end
function A.recordedLobbyClaims()
local out={}
for _,held in pairs(lobbyClaims)do
out[#out+1]=held
end
table.sort(out,function(one,two)
local oneClass,oneRank=A.matchIdRank(one.id)
local twoClass,twoRank=A.matchIdRank(two.id)
if oneClass~=twoClass then
return oneClass<twoClass
end
if oneRank~=twoRank then
return oneRank<twoRank
end
return tostring(one.id)<tostring(two.id)
end)
return out
end
function A.compHeading(format,drawn,sort,ascending,count)
if drawn=="spec"then
if type(count)=="number"and count>0 then
return("%s: %d %s, %s"):format(A.formatLabel(format),count,
count==1 and"spec"or"specs",A.specSortWords(sort,ascending))
end
return("%s: every spec you have met, %s"):format(A.formatLabel(format),
A.specSortWords(sort,ascending))
end
local order=(count==0)and""or", worst first"
local listFloor=A.metric("compListGames")
if A.compRounds(format)then
return("%s: the compositions you faced in at least %d rounds%s"):format(
A.formatLabel(format),listFloor,order)
end
return("%s: your matchups met at least %d times%s"):format(A.formatLabel(format),listFloor,order)
end
function A.compDivider(format)
return("UNDER %d %s"):format(A.rankFloor("comps"),A.compRounds(format)and"ROUNDS"or"DECIDED"),
"not ranked, most met first"
end
function A.compLines(format,season,character,bound)
local rows,skipped,belowFloor,considered,undecided,rankedCount,allDrawn=
A.compTally(format,season,character,bound)
allDrawn=tonumber(allDrawn)or 0
if#rows==0 and skipped==0 and belowFloor==0 and undecided==0 and allDrawn==0 then
return{}
end
local lines={
A.compHeading(format,"comp",nil,nil,rankedCount),
}
for i=1,#rows do
local row=rows[i]
if i==rankedCount+1 then
local key,clause=A.compDivider(format)
lines[#lines+1]=("  %s: %s"):format(key:lower(),clause)
end
local rate=row.winRate and("%d%%"):format(math.floor(row.winRate*100+0.5))or"no result"
local delta=A.signedText(row.ratingDelta)or"0"
local length=row.avgDuration and A.clockText(row.avgDuration)or"unknown"
lines[#lines+1]=("  %d. %s -- %d %ss, %s, %s, rating %s, avg %s"):format(
i,A.compText(row.members)or"unknown comp",
row.games,A.compRounds(format)and"round"or"game",
A.compRecordText(row)or"-",rate,delta,length)
end
local unlisted=belowFloor-(#rows-rankedCount)
local listFloor=A.metric("compListGames")
if A.compRounds(format)and#rows==0 and unlisted>0 then
lines[#lines+1]=("  no composition has reached %d rounds yet; %d %s so far"):format(
listFloor,unlisted,unlisted==1 and"is being counted"or"are being counted")
elseif unlisted>0 then
if A.compRounds(format)then
lines[#lines+1]=("  %d composition%s met fewer than %d rounds, not listed"):format(
unlisted,unlisted==1 and""or"s",listFloor)
else
lines[#lines+1]=("  %d comp%s met fewer than %d times, not listed"):format(
unlisted,unlisted==1 and""or"s",listFloor)
end
end
if allDrawn>0 then
lines[#lines+1]="  "..A.compAllDrawnText(format,allDrawn)
end
if skipped>0 then
if A.compRounds(format)and considered>0 then
lines[#lines+1]=("  %d of %d rounds recorded who shared the side; "
.."the rest were played before that was stored"):format(
considered-skipped,considered)
else
lines[#lines+1]=("  %d %s%s had no readable enemy team"):format(
skipped,A.compUnit(format),skipped==1 and""or"s")
end
end
if undecided>0 then
lines[#lines+1]=A.compUnratedLine(format,undecided)
end
return lines
end
function A.compUnratedLine(format,undecided)
if A.compRounds(format)then
return("%d round%s named a composition and recorded no result, so %s not rated: "
.."the scoreboard totals did not settle a winner."):format(
undecided,undecided==1 and""or"s",undecided==1 and"it is"or"they are")
end
return("%d %s%s recorded no result, so %s not rated."):format(
undecided,A.compUnit(format),undecided==1 and""or"s",
undecided==1 and"it is"or"they are")
end
function A.percentText(rate)
local points=A.percentPoints(rate)
if points==nil then
return nil
end
return("%d%%"):format(points)
end
function A.percentPoints(rate)
if type(rate)~="number"then
return nil
end
return math.floor(rate*100+0.5)
end
function A.winRateTone(rate)
local points=A.percentPoints(rate)
if points==nil then
return nil
end
if points>50 then
return"win"
elseif points<50 then
return"loss"
end
return"dim"
end
function A.swingPoints(against,alongside)
return A.percentPoints(alongside.winRate)-A.percentPoints(against.winRate)
end
function A.signedText(n)
if type(n)~="number"then
return nil
end
if n==0 then
return"0"
end
if n~=math.floor(n)then
return("%+.1f"):format(n)
end
return("%+d"):format(n)
end
function A.clockText(seconds)
if type(seconds)~="number"or seconds<0 then
return nil
end
local whole=math.floor(seconds)
if whole<60 then
return("%ds"):format(whole)
end
return("%d:%02d"):format(math.floor(whole/60),whole%60)
end
local PLOT_STEPS={5,10,20,25,50,100,200,250,500,1000,2000,2500,5000}
function A.plotScale(lo,hi,maxTicks)
if type(lo)~="number"or type(hi)~="number"or hi<=lo then
return nil
end
if type(maxTicks)~="number"or maxTicks<0 then
maxTicks=4
end
for i=1,#PLOT_STEPS do
local step=PLOT_STEPS[i]
local first=math.floor(lo/step)*step
local last=math.ceil(hi/step)*step
local inner=math.floor((last-first)/step)-1
if inner<0 then
inner=0
end
if inner<=maxTicks then
local ticks={}
for value=first,last,step do
ticks[#ticks+1]=value
end
return{lo=first,hi=last,step=step,ticks=ticks}
end
end
return nil
end
function A.plotExtent(series,first,last)
local lo,hi
local function reach(value)
if type(value)~="number"then
return
end
if lo==nil or value<lo then
lo=value
end
if hi==nil or value>hi then
hi=value
end
end
for i=first or 1,last or#series do
reach(series[i].rating)
reach(series[i].mmr)
end
return lo,hi
end
function A.dayText(stamp)
if type(stamp)~="string"then
return nil
end
local day=stamp:match("^(%d%d%d%d%-%d%d%-%d%d)")
return day
end
function A.shortDayText(stamp)
local key=A.dayText(stamp)
if key==nil then
return nil
end
local y,m,d=key:match("^(%d+)%-(%d+)%-(%d+)$")
local ok,text=pcall(function()
local noon=time({year=tonumber(y),month=tonumber(m),day=tonumber(d),hour=12})
return("%d %s"):format(tonumber(date("%d",noon)),date("%b",noon))
end)
if not ok or type(text)~="string"then
return nil
end
return text
end
function A.plotSpanText(series)
if type(series)~="table"or#series==0 then
return nil
end
local from=type(series[1])=="table"and A.dayText(series[1].at)or nil
local to=type(series[#series])=="table"and A.dayText(series[#series].at)or nil
if from==nil or to==nil then
return from or to
end
if from==to then
return from
end
return("%s to %s"):format(from,to)
end
function A.figureText(n)
if type(n)~="number"or n<0 then
return nil
end
if n<1000 then
return("%d"):format(math.floor(n))
end
if n<1000000 then
return("%.1fK"):format(n/1000)
end
return("%.1fM"):format(n/1000000)
end
function A.mmrGapText(gap,subject,short)
if type(gap)~="number"then
return nil
end
if short then
if gap==0 then
return"0"
end
return("%+d"):format(gap)
end
subject=type(subject)=="string"and subject or"rating"
if gap==0 then
return"level with "..subject
end
return("%d %s %s"):format(math.abs(gap),gap<0 and"below"or"above",subject)
end
function A.mmrCoverage(summary)
if type(summary)~="table"or type(summary.series)~="table"then
return nil
end
local total=#summary.series
if total<1 then
return nil
end
local carried=0
for i=1,total do
if type(summary.series[i].mmr)=="number"then
carried=carried+1
end
end
return carried,total
end
function A.mmrCoverageFull(summary)
local carried,points=A.mmrCoverage(summary)
if carried==nil then
return nil
end
return carried==points
end
function A.mmrLineOffered(summary)
local carried,points=A.mmrCoverage(summary)
if carried==nil or points<A.metric("plotPointMin")then
return nil
end
if carried>=points*A.metric("plotMmrShare")then
return true
end
return false
end
function A.plotReason(summary)
if type(summary)~="table"then
return nil
end
if not summary.ladder then
if summary.format==nil then
return nil
end
return("%s holds more than one ladder, so there is no rating to draw")
:format(summary.label)
end
local points=#summary.series
if points>=A.metric("plotPointMin")then
return nil
end
if points>0 then
return("%s has %d rating %s in this scope, so there is no curve to draw")
:format(summary.label,points,points==1 and"point"or"points")
end
if type(A.movesRating)=="function"and not A.movesRating(summary.format)then
return("%s moves no rating, so there is no curve to draw"):format(summary.label)
end
if summary.matches==0 then
return"no match in this scope, so there is no curve to draw"
end
return"no match in this scope carried a rating, so there is no curve to draw"
end
local ROUND_ORDINAL={"first","second","third","fourth","fifth","sixth","seventh",
"eighth","ninth","tenth"}
function A.tileTooltip(summary,key)
if type(summary)~="table"or type(key)~="string"then
return nil
end
local clause,entry={},{}
if type(A.readingLines)=="function"then
local ok,lines=pcall(A.readingLines,summary,nil,true)
if ok and type(lines)=="table"then
for i=1,#lines do
clause[lines[i].key]=lines[i].text
entry[lines[i].key]=lines[i]
end
end
end
local body={}
local function say(text)
if type(text)=="string"and text~=""then
body[#body+1]=text
end
end
if key=="ROUNDS WON"then
say(clause["ROUNDS"])
end
if key=="WIN RATE"or key=="MATCHES WON"then
say(clause["WIN RATE"])
local split=entry["FACTION"]
if type(split)=="table"and type(split.sides)=="table"and#split.sides>0 then
body[#body+1]={gap=true}
for i=1,#split.sides do
local side=split.sides[i]
body[#body+1]={key=side.word,text=side.text,tone=A.factionTone(side.side)}
end
say(split.denominator)
end
elseif key=="MATCHES"then
say(clause["MATCHES"])
elseif key=="MMR"then
if summary.mmr~=nil then
local head=tostring(summary.mmr)
local moved=A.signedText(summary.mmrChange)
if moved~=nil then
head=head.."   "..moved.." last match"
end
say(head)
end
say(A.mmrGapText(summary.mmrGap,"your rating"))
elseif key=="AVG LENGTH"then
say(clause["AVG LENGTH"])
local short,long=A.clockText(summary.shortest),A.clockText(summary.longest)
if short~=nil and long~=nil then
say(("shortest %s, longest %s"):format(short,long))
end
end
if#body==0 then
return nil
end
table.insert(body,1,key)
return body
end
function A.wholeAvgDuration(summary)
if type(summary)~="table"or summary.avgDuration==nil or type(summary.matches)~="number"
or summary.matches<=0 or summary.durationCount~=summary.matches then
return nil
end
return summary.avgDuration
end
function A.lengthBasis(summary)
if type(summary)~="table"or summary.avgDuration==nil or type(summary.durationCount)~="number"
or type(summary.matches)~="number"or summary.durationCount>=summary.matches then
return nil
end
return("over %d of %d"):format(summary.durationCount,summary.matches)
end
local FACTION_JOIN=" \194\183 "
function A.readingLines(summary,notRated,pane)
local out={}
if type(summary)~="table"then
return out
end
local function put(key,text)
out[#out+1]={key=key,text=text}
end
local pair=A.winRecordText(summary,summary.format)
if pair~=nil and select(4,A.winRecord(summary))~=nil then
local text
if summary.decided<summary.matches then
text=("%s over %d of %d matches"):format(pair,summary.decided,summary.matches)
else
text=("%s over all %d %s"):format(pair,summary.matches,
summary.matches==1 and"match"or"matches")
end
local byHand=summary.manualDecided or 0
if byHand>0 and not pane then
text=text..(", %s %s entered by hand"):format(
byHand==1 and"one"or tostring(byHand),
byHand==1 and"result"or"results")
end
put("WIN RATE",text)
end
if summary.factions~=nil and(summary.factionDecided or 0)>0 then
local parts,sides={},{}
for side=0,1 do
local held=summary.factions[side]
local word=A.factionWord(side)
local figure
local sidePair=type(held)=="table"and A.winRecordText(held,summary.format)or nil
if sidePair==nil then
figure="none"
else
figure=("%s, %s"):format(sidePair,A.percentText(select(4,A.winRecord(held)))or"-")
end
parts[#parts+1]=word.." "..figure
sides[#sides+1]={side=side,word=word,text=figure}
end
local text=table.concat(parts,FACTION_JOIN)
local denominator
local rateWins,rateLosses=A.winRecord(summary)
local bgWins,bgLosses=A.winRecord({wins=summary.factionWins or 0,decided=summary.factionDecided,
draws=summary.factionDraws or 0})
local covered=(bgWins or 0)+(bgLosses or 0)
if covered<(rateWins or 0)+(rateLosses or 0)then
denominator=("over %d battleground %s"):format(covered,covered==1 and"match"or"matches")
text=text..FACTION_JOIN..denominator
end
local noSide=summary.factionNoSide or 0
if noSide>0 and not pane then
text=text..FACTION_JOIN..("%s with no side recorded"):format(noSide==1 and"one"or tostring(noSide))
end
out[#out+1]={key="FACTION",text=text,sides=sides,denominator=denominator}
end
if summary.roundRate~=nil then
local text=("%d of %d won, %s"):format(summary.roundsWon,summary.roundsPlayed,
A.percentText(summary.roundRate))
local lobbies,shuffles=summary.roundLobbies or 0,summary.roundShuffles or 0
if lobbies>0 and shuffles>lobbies then
text=text..(" over %d of %d matches"):format(lobbies,shuffles)
end
if(summary.roundLobbies or 0)>0 then
local bar
if type(summary.roundThreshold)=="number"then
bar=ROUND_ORDINAL[summary.roundThreshold]
and("reached a "..ROUND_ORDINAL[summary.roundThreshold])
or("reached %d rounds"):format(summary.roundThreshold)
else
bar="won most of their rounds"
end
text=text..(", and %d of %d matches %s")
:format(summary.lobbiesWon,summary.roundLobbies,bar)
end
put("ROUNDS",text)
end
local narrowed=nil
if pane then
narrowed=nil
elseif summary.season~=nil then
narrowed="this season"
elseif summary.bound~=nil and type(A.scopePhrase)=="function"
and type(A.summaryScope)=="function"then
narrowed=A.scopePhrase(A.summaryScope())
end
if narrowed~=nil and type(A.formatCounts)=="function"then
local ok,counts=pcall(A.paintWalk,"formatCounts",summary.character)
if ok and type(counts)=="table"then
local whole=0
if summary.format~=nil then
whole=counts[summary.format]or 0
else
for _,n in pairs(counts)do
whole=whole+n
end
end
if whole~=summary.matches then
put("MATCHES",("%s only, of %d stored on this tab"):format(narrowed,whole))
end
end
end
if(summary.format==nil or summary.format=="unknown")and type(A.incompleteList)=="function"then
local ok,held=pcall(A.incompleteList,summary.character)
local left=0
for _,entry in ipairs(ok and type(held)=="table"and held or{})do
local inSeason=true
if summary.season~=nil and type(A.recordSeason)=="function"then
local seasonOk,resolved=pcall(A.recordSeason,entry)
inSeason=seasonOk and resolved==summary.season
end
if inSeason and(summary.bound==nil or A.recordSince(entry,summary.bound))then
left=left+1
end
end
if left>0 then
put("LEFT EARLY",("%d left early, not counted"):format(left))
end
end
local gapText=A.mmrGapText(summary.mmrGap)
if gapText~=nil then
put("MMR",gapText)
end
local basis=A.lengthBasis(summary)
if basis~=nil then
put("AVG LENGTH",pane and basis or("the mean is over %d of %d matches, the rest recording no duration")
:format(summary.durationCount,summary.matches))
end
if not pane and type(notRated)=="number"and notRated>0 then
put("NOT RATED",("%d %s named a composition and settled no winner")
:format(notRated,notRated==1 and"round"or"rounds"))
end
return out
end
function A.specNoteText(opts)
opts=type(opts)=="table"and opts or{}
local readable=type(opts.readable)=="number"and opts.readable or 0
local counts="the two ROUNDS columns"
if type(opts.columns)=="table"then
local against,along
for i=1,#opts.columns do
if opts.columns[i].key=="againstRounds"then
against=opts.columns[i].name
elseif opts.columns[i].key=="alongRounds"then
along=opts.columns[i].name
end
end
if against~=nil and along~=nil and against~=along then
counts=("%s and %s"):format(against,along)
end
end
return("WON is your own win rate over these, not theirs. "
.."A spec counts once per round, so %s do not add up. "
.."%d rated round%s counted."):format(counts,readable,readable==1 and""or"s")
end
function A.readingContext(format,season,character,bound)
local notRated,drawn=nil,false
local got,against,alongside,_,undecided=
pcall(A.paintWalk,"specTally",format,season,character,bound)
if got and type(against)=="table"and type(alongside)=="table"then
notRated=undecided
drawn=#against>0 or#alongside>0
end
return notRated,drawn
end
function A.figureLines(summary)
local lines={}
local scope=summary.label
if summary.season~=nil then
scope=("%s, season %d"):format(scope,summary.season)
end
lines[#lines+1]=("%s: %d stored %s"):format(scope,summary.matches,
summary.matches==1 and"match"or"matches")
local length=A.clockText(summary.avgDuration)
if length then
local over=""
if summary.durationCount<summary.matches then
over=(" over %d of %d"):format(summary.durationCount,summary.matches)
end
lines[#lines+1]=("  average length %s%s"):format(length,over)
end
local wins,losses,draws,rate=A.winRecord(summary)
local drawText=(draws or 0)>0 and(", %d %s"):format(draws,A.drawWord(summary.format))or""
if rate~=nil then
lines[#lines+1]=("  won %d of %d decided, %s%s")
:format(wins,wins+losses,A.percentText(rate),drawText)
if summary.roundRate~=nil then
local bar="most"
if type(summary.roundThreshold)=="number"then
bar=("%d+"):format(summary.roundThreshold)
end
lines[#lines+1]=("  won %d of %d rounds, %s; %s rounds in %d of %d %s")
:format(summary.roundsWon,summary.roundsPlayed,A.percentText(summary.roundRate),
bar,summary.lobbiesWon,summary.roundLobbies,
summary.roundLobbies==1 and"match"or"matches")
end
elseif(draws or 0)>0 then
lines[#lines+1]=("  no win rate: every decided match here ended level%s"):format(drawText)
elseif summary.roundLobbies==0 and not A.storesResult(summary.format)then
lines[#lines+1]="  no win rate: no "..summary.label
.." here recorded a round boundary, and none was entered by hand"
else
lines[#lines+1]="  no win rate: nothing stored here carries a decided result"
end
if summary.manualDecided>0 then
lines[#lines+1]=("  %d of those entered by hand, %d of them wins")
:format(summary.manualDecided,summary.manualWon)
end
if summary.derivedDecided>0 then
lines[#lines+1]=("  %d of those decided on rounds, %d of them wins")
:format(summary.derivedDecided,summary.derivedWon)
end
local function own(value)
return A.tierRatingText(summary.format,math.floor(value))
end
local ladder={}
if summary.rating~=nil then
ladder[#ladder+1]="rating "..own(summary.rating)
if summary.ratingChange~=nil and summary.lastFrom~=nil then
ladder[#ladder+1]=("last %s from %s")
:format(A.signedText(summary.ratingChange),own(summary.lastFrom))
end
end
if summary.peak~=nil then
ladder[#ladder+1]="peak "..own(summary.peak)
end
if summary.mmr~=nil then
local mmr=("mmr %d"):format(summary.mmr)
if summary.mmrGap~=nil then
mmr=mmr..(" (%s)"):format(A.signedText(summary.mmrGap))
end
ladder[#ladder+1]=mmr
end
local carried,points=A.mmrCoverage(summary)
if carried~=nil then
ladder[#ladder+1]=("mmr on %d of %d %s")
:format(carried,points,points==1 and"point"or"points")
end
if#ladder>0 then
lines[#lines+1]="  "..table.concat(ladder,"  ")
end
if not summary.ladder then
lines[#lines+1]="  no rating figures: "..(A.plotReason(summary)or"no ladder")
else
local skips=("%d skipped where no rating read")
:format(summary.skipped-summary.rejected-summary.zeroed)
if summary.rejected>0 then
skips=skips..(", %d refused for leaving the ladder"):format(summary.rejected)
end
if summary.zeroed>0 then
skips=skips..(", %d at a rating of zero"):format(summary.zeroed)
end
lines[#lines+1]=("  %d rating %s, %s")
:format(#summary.series,#summary.series==1 and"point"or"points",skips)
end
return lines
end
