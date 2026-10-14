-- WowPvpHistory 0.68.21
-- Author:  Xenu-Sentinels
-- Project: wow-pvp-history
--          https://github.com/xenulive/wow-pvp-history
-- License: MIT, see LICENSE
local ADDON,A=...
local SAMPLE_SECONDS=5
local LOOP=100
local COUNTS={
{key="over1",metric="CountTimeOver1Ms",ms=1},
{key="over5",metric="CountTimeOver5Ms",ms=5},
{key="over10",metric="CountTimeOver10Ms",ms=10},
{key="over50",metric="CountTimeOver50Ms",ms=50},
{key="over100",metric="CountTimeOver100Ms",ms=100},
{key="over500",metric="CountTimeOver500Ms",ms=500},
{key="over1000",metric="CountTimeOver1000Ms",ms=1000},
}
local function profiler()
local api=C_AddOnProfiler
if type(api)~="table"or type(api.GetAddOnMetric)~="function"or type(api.IsEnabled)~="function"then
return nil,"absent"
end
local ok,enabled=pcall(api.IsEnabled)
if not ok or enabled~=true then
return nil,"disabled"
end
if type(Enum)~="table"or type(Enum.AddOnProfilerMetric)~="table"then
return nil,"no-enum"
end
return api
end
local function metric(api,name)
local id=Enum.AddOnProfilerMetric[name]
if type(id)~="number"then
return nil
end
local ok,value=pcall(api.GetAddOnMetric,ADDON,id)
if not ok or type(value)~="number"or not A.canRead(value)then
return nil
end
if value~=value then
return nil
end
return value
end
local window
local token=0
local function sample(mine)
if mine~=token or not window then
return
end
local api=profiler()
local value=api and metric(api,"RecentAverageTime")
if value then
window.sum=window.sum+value
window.samples=window.samples+1
if window.max==nil or value>window.max then
window.max=value
end
end
C_Timer.After(SAMPLE_SECONDS,function()
sample(mine)
end)
end
function A.perfHalt()
token=token+1
end
function A.perfOpen(record)
A.perfHalt()
window={record=record,counts={},sum=0,samples=0}
local api=profiler()
if not api then
return
end
for i=1,#COUNTS do
window.counts[COUNTS[i].key]=metric(api,COUNTS[i].metric)
end
if C_Timer and C_Timer.After then
local mine=token
C_Timer.After(SAMPLE_SECONDS,function()
sample(mine)
end)
end
end
function A.perfDiscard()
A.perfHalt()
window=nil
end
function A.perfFields(record,held)
local fields={id=record and record.id}
local api,why=profiler()
if not api then
fields.reason=why
return fields
end
if held==nil or held.record~=record then
fields.window="none"
else
local diffs,lower={},false
for i=1,#COUNTS do
local key=COUNTS[i].key
local before,now=held.counts[key],metric(api,COUNTS[i].metric)
if before~=nil and now~=nil then
if now<before then
lower=true
else
diffs[key]=now-before
end
end
end
if lower then
fields.window="none"
else
for key,value in pairs(diffs)do
fields[key]=A.unitFigure(value)
end
end
fields.samples=held.samples
if held.samples>0 then
fields.drainMean=A.unitFigure(held.sum/held.samples)
fields.drainMax=A.unitFigure(held.max)
end
end
fields.peak=A.unitFigure(metric(api,"PeakTime"))
fields.session=A.unitFigure(metric(api,"SessionAverageTime"))
return fields
end
function A.perfStored(record)
local held=window
if held~=nil and held.record==record then
A.perfDiscard()
end
local f=A.perfFields(record,held)
A.trace("perf",{
id=f.id,
reason=f.reason,
window=f.window,
over1=f.over1,
over5=f.over5,
over10=f.over10,
over50=f.over50,
over100=f.over100,
over500=f.over500,
over1000=f.over1000,
drainMean=f.drainMean,
drainMax=f.drainMax,
samples=f.samples,
peak=f.peak,
session=f.session,
})
end
local function shown(value,unit)
local figure=A.unitFigure(value)
if figure==nil then
return"no answer"
end
return("%.2f%s"):format(figure,unit or"")
end
local function reportNow()
local api,why=profiler()
if not api then
A.say(("perf: the client's addon profiler is unavailable (%s), so there is no figure"):format(why))
return
end
A.say(("perf: last 60 frames %s average, last frame %s"):format(
shown(metric(api,"RecentAverageTime")," ms"),shown(metric(api,"LastTime")," ms")))
A.say(("perf since client startup: average %s, slowest frame %s"):format(
shown(metric(api,"SessionAverageTime")," ms"),shown(metric(api,"PeakTime")," ms")))
local parts={}
for i=1,#COUNTS do
local count=metric(api,COUNTS[i].metric)
parts[i]=("over %d ms %s"):format(COUNTS[i].ms,count==nil and"no answer"or("%d"):format(count))
end
A.say("perf frames since client startup: "..table.concat(parts,", "))
if window then
A.say(("perf: a match is open, %d reads of the 60-frame average so far"):format(window.samples))
end
end
local lastCalls
local function timeLoop(api,fresh)
local function loop()
for i=1,LOOP do
A.trace("perf-sample",{
source="results",
via="store",
state="shown",
format="arena2",
records="12+11+10",
n=fresh and i or 3,
},"ui")
end
end
local aside,ok,results=A.debugIsolated(function()
return pcall(api.MeasureCall,loop)
end)
if not ok or type(results)~="table"then
return nil
end
local ring=aside.rings and aside.rings.ui
local left=ring and type(ring.current)=="table"and#ring.current or 0
return results,left
end
local function perCall(results,left,wanted)
if left~=wanted then
return nil
end
local ms=results.elapsedMilliseconds
local bytes=results.allocatedBytes
local us=type(ms)=="number"and A.unitFigure(ms*1000/LOOP)or nil
return us,type(bytes)=="number"and A.unitFigure(bytes/LOOP)or nil
end
local function reportTrace()
if not A.debugEnabled()then
A.say("perf trace: the debug ring is off, so a write returns at once and there is nothing to time. "
.."/pvph debug on first")
return
end
local api,why=profiler()
if not api or type(api.MeasureCall)~="function"then
A.say(("perf trace: the client's addon profiler is unavailable (%s), so there is no figure")
:format(why or"absent"))
return
end
local between
if lastCalls~=nil then
between=A.debugCalls("ui")-lastCalls-1
end
local fields={calls=LOOP,between=between}
local foldResults,foldLeft=timeLoop(api,false)
local newResults,newLeft=timeLoop(api,true)
if foldResults then
fields.foldUs,fields.foldBytes=perCall(foldResults,foldLeft,1)
end
if newResults then
fields.newUs,fields.newBytes=perCall(newResults,newLeft,LOOP)
end
local function figure(value,unit)
return value==nil and"no figure"or("%.2f %s"):format(value,unit)
end
A.say(("perf trace, per write over %d: fold %s and %s, new entry %s and %s"):format(LOOP,
figure(fields.foldUs,"us"),figure(fields.foldBytes,"bytes"),
figure(fields.newUs,"us"),figure(fields.newBytes,"bytes")))
if between==nil then
A.say("perf trace: type it again after a window switch to count the ui writes the switch asked for")
else
A.say(("perf trace: %d ui writes since the previous perf trace"):format(between))
end
A.trace("perf-trace",{
calls=fields.calls,
between=fields.between,
foldUs=fields.foldUs,
foldBytes=fields.foldBytes,
newUs=fields.newUs,
newBytes=fields.newBytes,
},"ui")
lastCalls=A.debugCalls("ui")
end
function A.reportPerf(word)
if word==nil then
reportNow()
return
end
if word=="trace"then
reportTrace()
return
end
A.say(("unknown perf word %q: trace, or nothing for the figures now"):format(word))
end
