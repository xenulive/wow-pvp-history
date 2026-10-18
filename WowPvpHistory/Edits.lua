-- WowPvpHistory 0.68.47
-- Author:  Xenu-Sentinels
-- Project: wow-pvp-history
--          https://github.com/xenulive/wow-pvp-history
-- License: MIT, see LICENSE
local _,A=...
A.MANUAL_NOTE_MAX=200
local RESULTS={win=true,loss=true,draw=true}
A.RESULT_SET=RESULTS
local REASONS={"disconnect","crash","client-closed","chose-to-leave","kicked"}
local REASON_SET={}
for i=1,#REASONS do
REASON_SET[REASONS[i]]=true
end
A.REASON_SET=REASON_SET
function A.manualReasons()
local out={}
for i=1,#REASONS do
out[i]=REASONS[i]
end
return out
end
local function block(subject)
local manual=subject.manual
if type(manual)~="table"then
manual={edits=0}
subject.manual=manual
end
return manual
end
local function count(manual)
manual.edits=(manual.edits or 0)+1
local ok,stamp=pcall(A.stamp)
local read,epoch=pcall(time)
if ok then
manual.firstAt=manual.firstAt or stamp
manual.lastAt=stamp
end
if read and type(epoch)=="number"then
manual.firstEpoch=manual.firstEpoch or epoch
manual.lastEpoch=epoch
end
end
local function traceEdit(source,subject,state,reason)
A.trace("edit",{
source=source,
id=type(subject)=="table"and subject.id or nil,
state=state,
reason=reason,
n=type(subject)=="table"and type(subject.manual)=="table"
and subject.manual.edits or nil,
},"data")
end
local function typedValue(subject,key)
local manual=subject.manual
return type(manual)=="table"and manual[key]or nil
end
local function clearsNothing(source,subject,held)
if held~=nil then
return false
end
traceEdit(source,subject,"cleared","nothing-stored")
return true
end
local function fillsNothing(source,subject,held,incoming)
if incoming==nil or held~=incoming then
return false
end
traceEdit(source,subject,"filled","unchanged")
return true
end
local function writeNote(subject,text,source)
if type(subject)~="table"then
traceEdit(source,subject,"refused","no-subject")
return false,nil,"no-subject"
end
if text~=nil and#text>A.MANUAL_NOTE_MAX then
traceEdit(source,subject,"refused","too-long")
return false,nil,"too-long",#text,A.MANUAL_NOTE_MAX
end
local cleared=text==nil or text==""
if cleared and clearsNothing(source,subject,typedValue(subject,"note"))then
return true,nil
end
local held=typedValue(subject,"note")
if not cleared and fillsNothing(source,subject,held,text)then
return true,held
end
local manual=block(subject)
local was=manual.note
if cleared then
manual.note=nil
else
manual.note=text
end
count(manual)
traceEdit(source,subject,cleared and"cleared"or"filled")
return true,was
end
function A.editResult(record,value)
if type(record)~="table"then
traceEdit("result",record,"refused","no-record")
return false,nil,"no-record"
end
if record.result~=nil then
traceEdit("result",record,"refused","captured")
return false,nil,"captured",record.result
end
if value~=nil and type(A.carriesResult)=="function"and not A.carriesResult(record)then
traceEdit("result",record,"refused","no-result")
return false,nil,"no-result"
end
if value~=nil and type(A.resultCaptured)=="function"and A.resultCaptured(record)then
traceEdit("result",record,"refused","captured")
local held=type(A.capturedResultText)=="function"and A.capturedResultText(record)or nil
return false,nil,"captured",held
end
if value~=nil and not RESULTS[value]then
traceEdit("result",record,"refused","bad-result")
return false,nil,"bad-result"
end
if value==nil and clearsNothing("result",record,typedValue(record,"result"))then
return true,nil
end
if fillsNothing("result",record,typedValue(record,"result"),value)then
return true,value
end
local manual=block(record)
local was=manual.result
manual.result=value
count(manual)
traceEdit("result",record,value==nil and"cleared"or"filled")
local rebuilt,rebuildError=pcall(A.rebuildIndex)
if not rebuilt then
A.noteError(rebuildError,"edit-index")
end
if type(A.overlayRepaint)=="function"then
A.overlayRepaint("stored","result")
end
if type(A.dropFinderWalk)=="function"then
A.dropFinderWalk()
end
if not rebuilt then
return true,was,"rebuild-failed",tostring(rebuildError)
end
return true,was
end
function A.editNote(record,text)
return writeNote(record,text,"note")
end
function A.roundTypedRefusal(record,index,value)
local outcomes=type(A.roundOutcomes)=="function"and A.roundOutcomes(record)or nil
local captured=type(outcomes)=="table"and outcomes[index]or nil
if type(captured)=="table"and type(captured.won)=="boolean"then
return"captured",captured.won and"win"or"loss"
end
if value~=nil and type(A.roundTypedFits)=="function"
and A.roundTypedFits(record,index,value=="win")==false then
return"totals"
end
return nil
end
function A.editRound(record,index,value)
if type(record)~="table"then
traceEdit("round",record,"refused","no-record")
return false,nil,"no-record"
end
local rounds=type(record.rounds)=="table"and record.rounds or nil
if not rounds or type(index)~="number"or index~=math.floor(index)
or index<1 or index>#rounds then
traceEdit("round",record,"refused","no-round")
return false,nil,"no-round"
end
if value~=nil and value~="win"and value~="loss"then
traceEdit("round",record,"refused","bad-result")
return false,nil,"bad-result"
end
local refusal,blocking=A.roundTypedRefusal(record,index,value)
if refusal then
traceEdit("round",record,"refused",refusal)
return false,nil,refusal,blocking
end
local typedRounds=typedValue(record,"rounds")
local typedRound=type(typedRounds)=="table"and typedRounds[index]or nil
if value==nil and clearsNothing("round",record,typedRound)then
return true,nil
end
local heldResult=type(typedRound)=="table"and typedRound.result or nil
if fillsNothing("round",record,heldResult,value)then
return true,heldResult
end
local manual=block(record)
local typed=type(manual.rounds)=="table"and manual.rounds or{}
local held=typed[index]
local was=type(held)=="table"and held.result or nil
if value==nil then
typed[index]=nil
else
typed[index]={result=value}
end
manual.rounds=next(typed)~=nil and typed or nil
count(manual)
traceEdit("round",record,value==nil and"cleared"or"filled")
if type(A.overlayRepaint)=="function"then
A.overlayRepaint("stored","round")
end
if type(A.dropFinderWalk)=="function"then
A.dropFinderWalk()
end
return true,was
end
function A.incompleteById(id)
local db=A.db()
if not(db and type(db.incomplete)=="table"and type(id)=="number")then
return nil
end
local list=db.incomplete
for i=#list,1,-1 do
if type(list[i])=="table"and list[i].id==id then
return list[i]
end
end
return nil
end
function A.currentEditSubject(held,isLeft)
if type(held)~="table"then
return nil
end
if isLeft then
return A.incompleteById(held.id)
end
return A.match(held.id)
end
function A.editReason(entry,token)
if type(entry)~="table"then
traceEdit("reason",entry,"refused","no-entry")
return false,nil,"no-entry"
end
if token~=nil and not REASON_SET[token]then
traceEdit("reason",entry,"refused","bad-reason")
return false,nil,"bad-reason"
end
if token==nil and clearsNothing("reason",entry,typedValue(entry,"reason"))then
return true,nil
end
if fillsNothing("reason",entry,typedValue(entry,"reason"),token)then
return true,token
end
local manual=block(entry)
local was=manual.reason
manual.reason=token
count(manual)
traceEdit("reason",entry,token==nil and"cleared"or"filled")
return true,was
end
function A.editIncompleteNote(entry,text)
return writeNote(entry,text,"incomplete-note")
end
