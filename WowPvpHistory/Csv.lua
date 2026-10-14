-- WowPvpHistory 0.68.22
-- Author:  Xenu-Sentinels
-- Project: wow-pvp-history
--          https://github.com/xenulive/wow-pvp-history
-- License: MIT, see LICENSE
local _,A=...
local SIGNATURE="WPHCSV"
local FORMAT_VERSION=6
local SOURCE="csv"
local ENTRY_SEPARATOR=";"
local FIELD_SEPARATOR=":"
local function packEncode(value)
local text=tostring(value)
text=text:gsub("%%","%%25")
text=text:gsub("|","%%7C")
text=text:gsub(";","%%3B")
text=text:gsub(":","%%3A")
return text
end
local function textEncode(value)
local text=tostring(value)
text=text:gsub("%%","%%25")
text=text:gsub("|","%%7C")
local first=text:sub(1,1)
if first=="="or first=="+"or first=="-"or first=="@"then
text=string.format("%%%02X",first:byte())..text:sub(2)
end
return text
end
local function packDecode(text)
local out=text:gsub("%%(%x%x)",function(pair)
return string.char(tonumber(pair,16))
end)
return out
end
local function packJoin(entries)
if not entries or#entries==0 then
return nil
end
local rendered={}
for i=1,#entries do
local fields=entries[i]
local parts={}
for j=1,#fields do
parts[j]=packEncode(fields[j])
end
rendered[i]=table.concat(parts,FIELD_SEPARATOR)
end
return table.concat(rendered,ENTRY_SEPARATOR)
end
local function packSplit(cell)
local entries={}
for entry in tostring(cell):gmatch("[^"..ENTRY_SEPARATOR.."]+")do
local fields={}
local from=1
while true do
local at=entry:find(FIELD_SEPARATOR,from,true)
if not at then
fields[#fields+1]=packDecode(entry:sub(from))
break
end
fields[#fields+1]=packDecode(entry:sub(from,at-1))
from=at+1
end
entries[#entries+1]=fields
end
return entries
end
local FNV_OFFSET=2166136261
local FNV_PRIME=16777619
local WORD=4294967296
local xorRows={}
local function xorByte(a,b)
local row=xorRows[a]
if not row then
row={}
for other=0,255 do
local out,place,left,right=0,1,a,other
for _=1,8 do
local p,q=left%2,right%2
if p~=q then
out=out+place
end
left,right,place=(left-p)/2,(right-q)/2,place*2
end
row[other]=out
end
xorRows[a]=row
end
return row[b]
end
local HEX="0123456789abcdef"
local function hex8(value)
local out={}
for i=8,1,-1 do
local nibble=value%16
out[i]=HEX:sub(nibble+1,nibble+1)
value=(value-nibble)/16
end
return table.concat(out)
end
local function fnv1a(text)
local hash=FNV_OFFSET
for i=1,#text do
local low=hash%256
hash=hash-low+xorByte(low,text:byte(i))
local hi=(hash-hash%65536)/65536
local lo=hash%65536
hash=(((hi*FNV_PRIME)%65536)*65536+lo*FNV_PRIME)%WORD
end
return hex8(hash)
end
function A.csvChecksum(text)
return fnv1a(tostring(text))
end
local FIELD_MARK="\31"
local ROW_MARK="\30"
local function normalize(rows,from)
local parts={}
for i=from,#rows do
parts[#parts+1]=table.concat(rows[i],FIELD_MARK)
end
return table.concat(parts,ROW_MARK)
end
local function escape(value)
if value==nil then
return""
end
local text=tostring(value)
if text:find('[",\r\n]')or text:find("^%s")or text:find("%s$")then
local quoted=text:gsub('"','""')
return'"'..quoted..'"'
end
return text
end
local function parseCsv(text)
local rows,row,pos,size={},{},1,#text
while true do
local field
if text:sub(pos,pos)=='"'then
local buf,at={},pos+1
while true do
local quote=text:find('"',at,true)
if not quote then
return nil,"unreadable"
end
buf[#buf+1]=text:sub(at,quote-1)
if text:sub(quote+1,quote+1)=='"'then
buf[#buf+1]='"'
at=quote+2
else
at=quote+1
break
end
end
field=table.concat(buf)
pos=at
else
local stop=text:find('[,\r\n]',pos)or(size+1)
field=text:sub(pos,stop-1)
pos=stop
end
row[#row+1]=field
local here=text:sub(pos,pos)
if here==","then
pos=pos+1
elseif here=="\r"or here=="\n"or pos>size then
if here=="\r"and text:sub(pos+1,pos+1)=="\n"then
pos=pos+2
elseif here~=""then
pos=pos+1
end
rows[#rows+1]=row
row={}
if pos>size then
break
end
else
return nil,"unreadable"
end
end
if#rows>0 then
local last=rows[#rows]
if#last==1 and last[1]==""then
rows[#rows]=nil
end
end
return rows
end
local function top(name,kind,key)
key=key or name
return{
name=name,
kind=kind,
get=function(record)return record[key]end,
set=function(record,value)record[key]=value end,
}
end
local function under(container,name,kind,key)
return{
name=name,
kind=kind,
get=function(record)
local held=record[container]
if type(held)~="table"then
return nil
end
return held[key]
end,
set=function(record,value)
local held=record[container]
if type(held)~="table"then
held={}
record[container]=held
end
held[key]=value
end,
}
end
local function closed(column,allows)
column.allows=allows
return column
end
local function free(column)
column.free=true
return column
end
local function inSet(set)
return function(value)
return set[value]==true
end
end
local function namedFormat(value)
return A.formatLabel(value)~=value
end
local MATCH_SURFACES={agreed=true,latched=true,harvest=true,disagreed=true,absent=true}
local GUARDS={canaccessvalue=true,issecretvalue=true,none=true}
local OUTCOMES={knockout=true,retreat=true}
local SIDES={with=true,against=true}
local MATCH_COLUMNS={
{
name="matchId",
kind="number",
get=function(record)return record.id end,
},
closed(top("format","text"),namedFormat),
top("rated","flag"),
top("fixture","flag"),
top("bracket","number"),
top("season","number"),
top("gameSeason","number"),
free(top("openedAt","text")),
top("openedEpoch","number"),
free(top("openedState","text")),
free(top("completedAt","text")),
top("completedEpoch","number"),
top("duration","number"),
free(under("map","mapName","text","name")),
free(under("map","mapInstanceType","text","instanceType")),
under("map","mapInstanceId","number","instanceId"),
top("winnerFaction","number"),
top("selfFaction","number"),
closed(top("result","text"),inSet(A.RESULT_SET)),
closed(top("outcome","text"),inSet(OUTCOMES)),
free(top("opponentName","text")),
top("duelToTheDeath","flag"),
{
name="roundEnds",
kind="packed",
get=function(record)
local rounds=record.rounds
if type(rounds)~="table"then
return nil
end
local entries={}
for i=1,#rounds do
local round=rounds[i]
local mates=""
if type(round.mates)=="table"and#round.mates>0 then
local parts={}
for m=1,#round.mates do
parts[m]=tostring(round.mates[m])
end
mates=table.concat(parts,",")
end
entries[i]={
round.endedEpoch,
round.won==nil and""or(round.won and"true"or"false"),
round.ratingPost==nil and""or round.ratingPost,
mates,
}
local typed=A.typedRound(record,i)
if typed~=nil then
entries[i][5]=typed
end
end
return packJoin(entries)
end,
set=function(record,cell)
local rounds={}
local entries=packSplit(cell)
for i=1,#entries do
local fields=entries[i]
local epoch=tonumber(fields[1])
if epoch==nil then
return false
end
local round={endedEpoch=epoch}
local won=fields[2]
if won=="true"then
round.won=true
elseif won=="false"then
round.won=false
elseif won~=nil and won~=""then
return false
end
local rating=fields[3]
if rating~=nil and rating~=""then
round.ratingPost=tonumber(rating)
if round.ratingPost==nil then
return false
end
end
local mates=fields[4]
if mates~=nil and mates~=""then
local seats={}
for part in mates:gmatch("[^,]+")do
local seat=tonumber(part)
if seat==nil then
return false
end
seats[#seats+1]=seat
end
round.mates=seats
end
local typed=fields[5]
if typed=="win"or typed=="loss"then
local manual=type(record.manual)=="table"and record.manual or{}
record.manual=manual
manual.rounds=type(manual.rounds)=="table"and manual.rounds or{}
manual.rounds[i]={result=typed}
elseif typed~=nil and typed~=""then
return false
end
rounds[i]=round
end
record.rounds=rounds
return true
end,
},
{
name="objectiveColumns",
kind="packed",
get=function(record)
local columns=record.columns
if type(columns)~="table"then
return nil
end
local entries={}
for i=1,#columns do
local column=columns[i]
entries[i]={column.id,column.order==nil and""or column.order,column.name}
end
return packJoin(entries)
end,
set=function(record,cell)
local columns={}
local entries=packSplit(cell)
for i=1,#entries do
local fields=entries[i]
local id,order=tonumber(fields[1]),tonumber(fields[2])
if id==nil or(fields[2]~=nil and fields[2]~=""and order==nil)then
return false
end
columns[i]={id=id,order=order,name=fields[3]}
end
record.columns=columns
return true
end,
},
top("participantCount","number"),
free(top("character","text")),
under("harvest","harvestAttempts","number","attempts"),
under("harvest","harvestRows","number","rows"),
under("harvest","harvestReadSeconds","number","readSeconds"),
under("harvest","harvestReadAt","number","readAt"),
closed(under("harvest","harvestMatchSurface","text","matchSurface"),inSet(MATCH_SURFACES)),
closed(under("harvest","harvestGuard","text","guard"),inSet(GUARDS)),
under("harvest","harvestRestriction","number","restriction"),
free(under("harvest","harvestVersion","text","version")),
free(under("harvest","harvestBuild","text","build")),
closed(under("manual","manualResult","text","result"),inSet(A.RESULT_SET)),
closed(under("manual","manualReason","text","reason"),inSet(A.REASON_SET)),
free(under("manual","manualNote","text","note")),
under("manual","edits","number","edits"),
free(under("manual","manualFirstAt","text","firstAt")),
under("manual","manualFirstEpoch","number","firstEpoch"),
free(under("manual","manualLastAt","text","lastAt")),
under("manual","manualLastEpoch","number","lastEpoch"),
free(under("talents","talentsLoadout","text","loadout")),
free(under("talents","talentsString","text","string")),
}
for i=1,#MATCH_COLUMNS do
local name=MATCH_COLUMNS[i].name
if name=="format"or name=="completedEpoch"or name=="character"then
MATCH_COLUMNS[i].key=true
end
end
local PARTICIPANT_COLUMNS={
{name="guid",kind="text",free=true},
free(top("name","text")),
closed(top("side","text"),inSet(SIDES)),
top("faction","number"),
free(top("race","text")),
free(top("class","text")),
free(top("classToken","text")),
free(top("spec","text")),
top("role","number"),
top("honorLevel","number"),
top("killingBlows","number"),
top("honorableKills","number"),
top("deaths","number"),
top("honor","number"),
top("damage","number"),
top("healing","number"),
top("rating","number"),
top("ratingChange","number"),
top("mmrPre","number"),
top("mmrPost","number"),
top("seat","number"),
top("dispels","number"),
{
name="objectiveStats",
kind="packed",
get=function(participant)
local stats=participant.stats
if type(stats)~="table"then
return nil
end
local ids={}
for id in pairs(stats)do
ids[#ids+1]=id
end
table.sort(ids)
local entries={}
for i=1,#ids do
entries[i]={ids[i],stats[ids[i]]}
end
return packJoin(entries)
end,
set=function(participant,cell)
local stats={}
local entries=packSplit(cell)
for i=1,#entries do
local id,value=tonumber(entries[i][1]),tonumber(entries[i][2])
if id==nil or value==nil then
return false
end
stats[id]=value
end
participant.stats=stats
return true
end,
},
}
for r=1,6 do
PARTICIPANT_COLUMNS[#PARTICIPANT_COLUMNS+1]={
name=("r%dDispels"):format(r),
kind="text",
get=function(participant,record)
if type(A.roundMeterCells)~="function"then
return nil
end
return A.roundMeterCells(record,participant,r)
end,
}
end
function A.csvColumns()
return MATCH_COLUMNS,PARTICIPANT_COLUMNS
end
local function headerRow()
local names={}
for i=1,#MATCH_COLUMNS do
names[#names+1]=MATCH_COLUMNS[i].name
end
for i=1,#PARTICIPANT_COLUMNS do
names[#names+1]=PARTICIPANT_COLUMNS[i].name
end
return names
end
local function number(value)
local text=("%.14g"):format(value)
if tonumber(text)~=value then
text=("%.17g"):format(value)
end
return text
end
local function cell(column,subject,record)
local value=nil
if column.get then
value=column.get(subject,record)
end
if value==nil then
return""
end
if column.kind=="number"then
if type(value)~="number"then
return""
end
return number(value)
end
if column.kind=="flag"then
return value and"true"or"false"
end
if column.kind=="packed"then
return tostring(value)
end
return textEncode(value)
end
local function fill(column,subject,text)
if text==""or column.set==nil then
return true
end
if column.kind=="number"then
local value=tonumber(text)
if value==nil then
return false
end
column.set(subject,value)
return true
end
if column.kind=="flag"then
if text=="true"then
column.set(subject,true)
elseif text=="false"then
column.set(subject,false)
else
return false
end
return true
end
if column.kind=="packed"then
return column.set(subject,text)~=false
end
local value=packDecode(text)
if column.allows and not column.allows(value)then
return true,true
end
column.set(subject,value)
return true
end
local PART_LIMIT=25000
local function matchRows(record,into)
local head,thin={},{}
for i=1,#MATCH_COLUMNS do
local column=MATCH_COLUMNS[i]
head[i]=cell(column,record)
thin[i]=column.key and head[i]or""
end
local participants=record.participants
local guids={}
if type(participants)=="table"then
for guid in pairs(participants)do
guids[#guids+1]=guid
end
table.sort(guids)
end
if#guids==0 then
local row={}
for i=1,#head do
row[i]=head[i]
end
for i=1,#PARTICIPANT_COLUMNS do
row[#head+i]=""
end
into[#into+1]=row
return
end
for g=1,#guids do
local guid=guids[g]
local participant=participants[guid]
local row={}
local from=g==1 and head or thin
for i=1,#head do
row[i]=from[i]
end
for i=1,#PARTICIPANT_COLUMNS do
local column=PARTICIPANT_COLUMNS[i]
if column.name=="guid"then
row[#head+i]=guid
else
row[#head+i]=cell(column,participant,record)
end
end
into[#into+1]=row
end
end
local function renderRow(row)
local fields={}
for i=1,#row do
fields[i]=escape(row[i])
end
return table.concat(fields,",")
end
local function recordDate(record)
if type(record.completedEpoch)~="number"then
return nil
end
local ok,rendered=pcall(date,"%Y-%m-%d",record.completedEpoch)
if ok and type(rendered)=="string"then
return rendered
end
return nil
end
local function selected(db,filter)
local format=filter and filter.format
local since=filter and filter.since
local last=filter and filter.last
local out={}
local list=db.matches
for i=1,#list do
local record=list[i]
local keep=format==nil or record.format==format
if keep and since~=nil then
local at=recordDate(record)
keep=at~=nil and at>=since
end
if keep then
out[#out+1]=record
end
end
if type(last)=="number"and last>=0 and#out>last then
local trimmed={}
for i=#out-last+1,#out do
trimmed[#trimmed+1]=out[i]
end
return trimmed
end
return out
end
local function buildParts(db,filter)
local header=renderRow(headerRow())
local parts={}
local current
local function open()
current={rows={},lines={},matches=0,bytes=#header}
parts[#parts+1]=current
end
local list=selected(db,filter)
for i=1,#list do
local record=list[i]
do
local rows={}
matchRows(record,rows)
local lines,cost={},0
for j=1,#rows do
lines[j]=renderRow(rows[j])
cost=cost+#lines[j]+1
end
if not current or(current.bytes+cost>PART_LIMIT and#current.rows>0)then
open()
end
for j=1,#rows do
current.rows[#current.rows+1]=rows[j]
current.lines[#current.lines+1]=lines[j]
end
current.matches=current.matches+1
current.bytes=current.bytes+cost
end
end
if#parts==0 then
open()
end
return parts,header
end
function A.csvExport(filter,part)
if A.sandboxed()then
A.trace("csv-export",{state="refused",reason="sandbox"},"data")
return nil,A.refusalText("sandbox")
end
local db=A.db()
if not db then
return nil,"no database"
end
local last=filter and filter.last
if last~=nil and(type(last)~="number"or last<0 or last%1~=0)then
return nil,("last takes a whole number of matches, not %s"):format(tostring(last))
end
local since=filter and filter.since
if since~=nil and(type(since)~="string"or not since:match("^%d%d%d%d%-%d%d%-%d%d$"))then
return nil,("a date reads YYYY-MM-DD, so since %s selects nothing"):format(tostring(since))
end
local parts,header=buildParts(db,filter)
part=part or 1
if type(part)~="number"or part<1 or part>#parts or part%1~=0 then
return nil,("this export has %d %s, so there is no part %s")
:format(#parts,#parts==1 and"part"or"parts",tostring(part))
end
local held=parts[part]
local rows={headerRow()}
for i=1,#held.rows do
rows[i+1]=held.rows[i]
end
local dataRows=#held.rows
local checksum=fnv1a(normalize(rows,1))
local lines={renderRow({
SIGNATURE,
tostring(FORMAT_VERSION),
tostring(dataRows),
checksum,
tostring(A.version or"unknown"),
tostring(A.stamp()),
}),header}
for i=1,#held.lines do
lines[i+2]=held.lines[i]
end
A.trace("csv-export",{
format=(filter and filter.format)or"all",
rows=dataRows,
n=held.matches,
},"data")
return table.concat(lines,"\n"),dataRows,held.matches,part,#parts
end
local REFUSAL={
["nothing"]="nothing was pasted",
["not-ours"]="this text did not come from PvP History",
["newer"]="this was written by a newer version of the addon. Update, then import it",
["unreadable"]="this text is not a readable CSV file",
["empty"]="this file holds no matches",
["count"]="this file has been altered since it was exported: it holds a different number "
.."of rows than it says it does",
["checksum"]="this file has been altered since it was exported: its contents do not match "
.."what it says they are",
["no-database"]="no database",
["disagree"]="a row carries the same time, format and character as the row above it but "
.."different match details, so the file was changed after export and nothing was imported",
}
function A.csvRefusalText(token)
return REFUSAL[token]or"this text could not be imported"
end
local function naturalKey(record)
return table.concat({
record.completedEpoch~=nil and number(record.completedEpoch)or"",
record.format~=nil and tostring(record.format)or"",
record.character~=nil and tostring(record.character)or"",
},"\1")
end
function A.csvRemapRows(rows)
local wanted=headerRow()
local held=type(rows)=="table"and rows[2]or nil
if type(held)~="table"then
return rows
end
local same=#held==#wanted
local known={}
for i=1,#wanted do
known[wanted[i]]=true
if held[i]~=wanted[i]then
same=false
end
end
if same then
return rows
end
for i=1,#held do
if not known[tostring(held[i])]then
return rows
end
end
local positions,seen={},{}
for i=1,#held do
local name=tostring(held[i])
seen[name]=(seen[name]or 0)+1
positions[name.."\1"..seen[name]]=i
end
local from,counted={},{}
for i=1,#wanted do
local name=wanted[i]
counted[name]=(counted[name]or 0)+1
from[i]=positions[name.."\1"..counted[name]]
end
local out={rows[1],wanted}
for r=3,#rows do
local row,built=rows[r],{}
for i=1,#wanted do
built[i]=from[i]and row[from[i]]or""
end
out[r]=built
end
return out
end
function A.csvPreview(text,forced)
if type(text)~="string"then
return nil,A.csvRefusalText("nothing"),"nothing"
end
local trimmed=text:gsub("^%s+",""):gsub("%s+$","")
if trimmed==""then
return nil,A.csvRefusalText("nothing"),"nothing"
end
local rows,why=parseCsv(trimmed)
if not rows then
return nil,A.csvRefusalText(why),why
end
if#rows<1 or rows[1][1]~=SIGNATURE then
return nil,A.csvRefusalText("not-ours"),"not-ours"
end
local version=tonumber(rows[1][2])
if version==nil then
return nil,A.csvRefusalText("not-ours"),"not-ours"
end
if version>FORMAT_VERSION then
local sentence=A.csvRefusalText("newer")
..(" (it is format %d and this addon reads %d)"):format(version,FORMAT_VERSION)
return nil,sentence,"newer",version
end
if#rows<2 then
return nil,A.csvRefusalText("unreadable"),"unreadable"
end
local dataRows=#rows-2
if dataRows<1 then
return nil,A.csvRefusalText("empty"),"empty"
end
local claimed=tonumber(rows[1][3])
if claimed~=dataRows and not forced then
return nil,A.csvRefusalText("count"),"count"
end
local checksum=fnv1a(normalize(rows,2))
if checksum~=rows[1][4]and not forced then
return nil,A.csvRefusalText("checksum"),"checksum"
end
local remapped=A.csvRemapRows(rows)
return{
rows=remapped,
dataRows=dataRows,
version=version,
remapped=remapped~=rows or nil,
checksum=checksum,
claimedRows=claimed,
claimedChecksum=rows[1][4],
addon=rows[1][5],
exportedAt=rows[1][6],
}
end
local function readRow(row,width)
if#row~=width then
return nil
end
local dropped=0
local record={}
local continuation=true
for i=1,#MATCH_COLUMNS do
local column=MATCH_COLUMNS[i]
local ok,outside=fill(column,record,row[i])
if not ok then
return nil
end
if outside then
dropped=dropped+1
end
if not column.key and row[i]~=""then
continuation=false
end
end
local offset=#MATCH_COLUMNS
local guid=row[offset+1]
if guid==""then
for i=2,#PARTICIPANT_COLUMNS do
if row[offset+i]~=""then
return nil
end
end
return record,nil,nil,continuation,dropped
end
local participant={}
for i=2,#PARTICIPANT_COLUMNS do
local ok,outside=fill(PARTICIPANT_COLUMNS[i],participant,row[offset+i])
if not ok then
return nil
end
if outside then
dropped=dropped+1
end
end
return record,guid,participant,continuation,dropped
end
function A.csvImport(text,forced)
local preview,why,token=A.csvPreview(text,forced)
if not preview then
A.trace("csv-import",{state="refused",reason=token},"data")
return nil,why,token
end
if A.sandboxed()then
A.trace("csv-import",{state="refused",reason="sandbox"},"data")
return nil,A.refusalText("sandbox"),"sandbox"
end
local db=A.db()
if not db then
A.trace("csv-import",{state="refused",reason="no-database"},"data")
return nil,A.csvRefusalText("no-database"),"no-database"
end
if db.active~=nil then
A.trace("csv-import",{state="refused",reason="in-flight"},"data")
return nil,A.refusalText("in-flight"),"in-flight"
end
local held={}
for i=1,#db.matches do
held[naturalKey(db.matches[i])]=true
end
local rows=preview.rows
local width=#MATCH_COLUMNS+#PARTICIPANT_COLUMNS
local added,skipped,refused=0,0,0
local addedIds={}
local refiledIds={}
local roundsDropped=0
local resultDropped=0
local cellsDropped=0
local droppedBy={}
local fixtureHeld=A.fixtureCount(db)
local fixtureCeiling=type(A.fixtureCeiling)=="function"and A.fixtureCeiling()or 0
local fixtureDropped=0
local function commit(record)
local refiled=A.arenaMapBattleground(record)
if refiled then
record.format="bg"
end
local key=naturalKey(record)
if held[key]then
skipped=skipped+1
return
end
if record[A.FIXTURE_KEY]then
if fixtureHeld>=fixtureCeiling then
fixtureDropped=fixtureDropped+1
return
end
fixtureHeld=fixtureHeld+1
end
held[key]=true
cellsDropped=cellsDropped+(droppedBy[record]or 0)
local manual=record.manual
if type(manual)=="table"and type(manual.rounds)=="table"then
for index in pairs(manual.rounds)do
local typed=manual.rounds[index]
if A.roundTypedRefusal(record,index,type(typed)=="table"and typed.result or nil)then
manual.rounds[index]=nil
roundsDropped=roundsDropped+1
end
end
if next(manual.rounds)==nil then
manual.rounds=nil
end
end
if type(manual)=="table"and manual.result~=nil and not A.resultOfferable(record)then
manual.result=nil
resultDropped=resultDropped+1
end
if record[A.FIXTURE_KEY]then
db.nextFixtureId=type(db.nextFixtureId)=="number"and db.nextFixtureId or 1
record.id=("F%d"):format(db.nextFixtureId)
db.nextFixtureId=db.nextFixtureId+1
else
record.id=db.nextMatchId
db.nextMatchId=db.nextMatchId+1
end
if refiled then
refiledIds[#refiledIds+1]=tostring(record.id)
end
record.imported={at=A.stamp(),source=SOURCE,forced=forced or nil}
db.matches[#db.matches+1]=record
added=added+1
addedIds[#addedIds+1]="match:"..record.id
A.trace("csv-record",{state=forced and"forced"or"added"},"data")
end
local function sameMatch(first,row)
for c=1,#MATCH_COLUMNS do
if MATCH_COLUMNS[c].name=="matchId"and first[c]~=""and row[c]~=""and first[c]~=row[c]then
return"other"
end
end
for c=1,#MATCH_COLUMNS do
if not MATCH_COLUMNS[c].key and row[c]~=""and row[c]~=first[c]then
return"differs"
end
end
return"same"
end
local pending={}
local i=3
local current,currentKey,currentRow
local function close()
if current then
pending[#pending+1]=current
end
current,currentKey,currentRow=nil,nil,nil
end
while i<=#rows do
local row=rows[i]
local record,guid,participant,continuation,dropped=readRow(row,width)
local key=record and naturalKey(record)or nil
local joins=record~=nil and current~=nil and key==currentKey
if joins and not continuation then
local verdict=sameMatch(currentRow,row)
if verdict=="other"then
joins=false
elseif verdict=="differs"then
A.trace("csv-import",{state="refused",reason="disagree"},"data")
return nil,A.csvRefusalText("disagree")..(" (line %d)"):format(i),"disagree"
end
end
if record and continuation and not joins then
record=nil
end
if not record then
refused=refused+1
else
if not joins then
close()
current,currentKey,currentRow=record,key,row
current.participants={}
end
if current and guid~=nil then
current.participants[guid]=participant
end
if current then
droppedBy[current]=(droppedBy[current]or 0)+(dropped or 0)
end
end
i=i+1
end
close()
for p=1,#pending do
commit(pending[p])
end
local moved
if added>0 then
moved=A.orderByCompletion(db.matches)
local rebuilt,rebuildError=pcall(A.rebuildIndex)
if not rebuilt then
A.noteError(rebuildError,"csv-index")
A.say(("the records are stored and the player index was not rebuilt: %s. /pvph rebuild")
:format(tostring(rebuildError)))
end
pcall(A.notePrune,"csv",#db.matches-added)
pcall(A.storeReplaced)
end
A.trace("csv-import",{
state=forced and"forced"or"applied",
rows=preview.dataRows,
n=added,
skipped=skipped,
refusals=refused,
moved=moved,
records=#addedIds>0 and table.concat(addedIds,"+")or nil,
ids=#refiledIds>0 and table.concat(refiledIds,",")or nil,
roundsDropped=roundsDropped,
resultDropped=resultDropped,
cellsDropped=cellsDropped,
fixtureDropped=fixtureDropped,
},"data")
return{added=added,skipped=skipped,refused=refused,roundsDropped=roundsDropped,
resultDropped=resultDropped,cellsDropped=cellsDropped,fixtureDropped=fixtureDropped}
end
local sheet
local function buildFrame()
local frame=CreateFrame("Frame","WowPvpHistoryCsvFrame",UIParent,
"BasicFrameTemplateWithInset")
frame:SetSize(A.metric("sheetWidth"),A.metric("sheetHeight"))
frame:SetPoint("CENTER")
A.registerPlacedWindow(frame,"CENTER",0,0)
frame:SetFrameStrata("DIALOG")
frame:SetClampedToScreen(true)
frame:SetMovable(true)
frame:EnableMouse(true)
frame:RegisterForDrag("LeftButton")
frame:SetScript("OnDragStart",frame.StartMoving)
frame:SetScript("OnDragStop",frame.StopMovingOrSizing)
frame:Hide()
local title=A.windowTitle(frame)
title:SetPoint("TOP",frame,"TOP",0,-6)
A.style(title,"heading","bright")
frame.title=title
local note=frame:CreateFontString(nil,"ARTWORK","GameFontHighlightSmall")
note:SetPoint("TOPLEFT",frame,"TOPLEFT",16,-34)
note:SetPoint("TOPRIGHT",frame,"TOPRIGHT",-16,-34)
note:SetJustifyH("LEFT")
A.style(note,"bodyText","text")
frame.note=note
local scroll=CreateFrame("ScrollFrame","WowPvpHistoryCsvScroll",frame,
"ScrollFrameTemplate")
scroll:SetPoint("TOPLEFT",note,"BOTTOMLEFT",6,-12)
scroll:SetPoint("BOTTOMRIGHT",frame,"BOTTOMRIGHT",-34,46)
frame.scroll=scroll
local box=CreateFrame("EditBox","WowPvpHistoryCsvBox",scroll)
box:SetMultiLine(true)
box:SetAutoFocus(false)
box:SetFontObject("ChatFontNormal")
box:SetMaxLetters(0)
box:SetWidth(620)
box:SetScript("OnEscapePressed",function()frame:Hide()end)
scroll:SetScrollChild(box)
frame.box=box
local confirm=A.pill(frame,nil,nil,A.metric("sheetButton"))
confirm:SetPoint("BOTTOMRIGHT",frame,"BOTTOMRIGHT",-16,14)
frame.confirm=confirm
A.registerChrome(frame)
return frame
end
local function frameOrNil()
if sheet then
return sheet
end
local ok,built=pcall(buildFrame)
if not ok or not built then
return nil
end
sheet=built
return sheet
end
function A.showCsvSheet(title,note,text,confirmText,onConfirm)
local frame=frameOrNil()
if not frame then
return false
end
local ok=pcall(function()
frame.title:SetText(title)
frame.note:SetText(note)
frame.box:SetText(text or"")
if onConfirm then
frame.confirm:SetText(confirmText)
A.fitControl(frame.confirm,A.metric("sheetButton"))
frame.confirm:SetScript("OnClick",function()
local clicked,done=pcall(onConfirm,frame.box:GetText())
if not clicked then
A.say("the CSV window failed: "..tostring(done))
return
end
if done then
frame:Hide()
end
end)
frame.confirm:Show()
else
frame.confirm:Hide()
end
frame:Show()
frame.box:SetFocus()
if text then
frame.box:HighlightText()
end
end)
return ok
end
