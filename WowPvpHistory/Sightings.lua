-- WowPvpHistory 0.68.21
-- Author:  Xenu-Sentinels
-- Project: wow-pvp-history
--          https://github.com/xenulive/wow-pvp-history
-- License: MIT, see LICENSE
local _,A=...
local SIGHT_REPEAT_MINUTES=10
local SIGHT_QUIET_SECONDS=20
local SIGHT_MEMORY=64
local MARK_SIZE=14
local marks={}
local plateOf={}
local namedAt={}
local namedOrder={}
local lastLine
local reported=false
function A.sightEnabled()
local db=A.db()
if not db then
return false
end
db.ui=db.ui or{}
return db.ui.sight~=false
end
local function hideAll()
for _,mark in pairs(marks)do
pcall(mark.Hide,mark)
end
end
function A.setSight(enabled)
local db=A.db()
if not db then
return false
end
db.ui=db.ui or{}
if enabled==false then
db.ui.sight=false
hideAll()
else
db.ui.sight=nil
end
if A.notifySightSetting then
A.notifySightSetting()
end
return true
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
local function plateFrame(token)
local plates=C_NamePlate
return guarded(plates and plates.GetNamePlateForUnit,token)
end
local function clock()
local now=guarded(GetTime)
if type(now)=="number"then
return now
end
return guarded(time)or 0
end
local function markedCount()
local n=0
for _,mark in pairs(marks)do
local ok,shown=pcall(mark.IsShown,mark)
if ok and shown then
n=n+1
end
end
return n
end
local function traceSight(state,reason,source,noted)
A.trace("sight",{state=state,reason=reason,source=source,n=markedCount(),
carriesNote=noted})
end
local function contained(fn,...)
local ok,err=pcall(fn,...)
if ok then
return
end
A.noteError(err,"sight")
if not reported then
reported=true
A.say("marking people you have written about stopped: "..tostring(err)
..". /pvph sight off silences it")
end
end
local function writtenAbout(guid)
local note=A.noteFor(guid)
if note and A.writtenAbout(note)then
return note
end
return nil
end
local function examine(token,source)
if not A.sightEnabled()then
traceSight("refused","switch",source)
return nil
end
if A.inMatchInstance()then
traceSight("refused","instance",source)
return nil
end
if A.pvpRestricted()then
traceSight("refused","restricted",source)
return nil
end
local isPlayer=guarded(UnitIsPlayer,token)
if not(A.canRead(isPlayer)and isPlayer==true)then
traceSight("refused","not-player",source)
return nil
end
local guid=guarded(UnitGUID,token)
if not(type(guid)=="string"and A.canRead(guid))then
traceSight("refused","secret",source)
return nil
end
local own=guarded(UnitGUID,"player")
if type(own)=="string"and A.canRead(own)and own==guid then
traceSight("refused","self",source)
return nil
end
local note=writtenAbout(guid)
if not note then
traceSight("refused","unwritten",source)
return nil
end
local group=A.groupGuids()
for i=1,#group do
if group[i]==guid then
traceSight("refused","group",source,note.text~=nil)
return nil
end
end
return guid,note
end
local function remember(guid,now)
for i=#namedOrder,1,-1 do
if namedOrder[i]==guid then
table.remove(namedOrder,i)
end
end
namedOrder[#namedOrder+1]=guid
namedAt[guid]=now
while#namedOrder>SIGHT_MEMORY do
local oldest=table.remove(namedOrder,1)
namedAt[oldest]=nil
end
end
local function speak(guid,note,source)
local now=clock()
local at=namedAt[guid]
if at~=nil and now-at<SIGHT_REPEAT_MINUTES*60 then
traceSight("refused","repeat",source,note.text~=nil)
return
end
if lastLine~=nil and now-lastLine<SIGHT_QUIET_SECONDS then
traceSight("refused","quiet",source,note.text~=nil)
return
end
remember(guid,now)
lastLine=now
A.say(A.sightLine(guid))
traceSight("said",nil,source,note.text~=nil)
end
local function hideMark(frame)
local mark=marks[frame]
if mark then
pcall(mark.Hide,mark)
end
end
local function showMark(frame)
local mark=marks[frame]
if not mark then
local ok,made=pcall(frame.CreateTexture,frame,nil,"OVERLAY")
if not(ok and type(made)=="table")then
return false
end
made:SetSize(MARK_SIZE,MARK_SIZE)
made:SetPoint("TOPRIGHT",frame,"TOPRIGHT",0,0)
made:SetTexture(A.ICON_TEXTURE)
marks[frame]=made
mark=made
end
mark:Show()
return true
end
local function onPlateAdded(token)
local frame=type(token)=="string"and plateFrame(token)or nil
if frame then
hideMark(frame)
plateOf[token]=frame
end
local guid,note=examine(token,"plate")
if not(guid and note)then
return
end
if frame and showMark(frame)then
traceSight("marked",nil,"plate",note.text~=nil)
else
traceSight("refused","no-plate","plate",note.text~=nil)
end
speak(guid,note,"plate")
end
local function onPlateRemoved(token)
if type(token)~="string"then
return
end
local frame=plateFrame(token)or plateOf[token]
plateOf[token]=nil
if frame then
hideMark(frame)
end
end
local function onTarget()
local guid,note=examine("target","target")
if guid and note then
speak(guid,note,"target")
end
end
A.on("NAME_PLATE_UNIT_ADDED",function(_,token)
contained(onPlateAdded,token)
end)
A.on("NAME_PLATE_UNIT_REMOVED",function(_,token)
contained(onPlateRemoved,token)
end)
A.on("PLAYER_TARGET_CHANGED",function()
contained(onTarget)
end)
function A.reportSight(word)
if word=="on"or word=="off"then
local wanted=word=="on"
if not A.setSight(wanted)then
A.say("no database, so the setting could not be stored")
return
end
A.say("marking people you have written about "..(wanted and"on"or"off"))
return
end
if word then
A.say(("unknown sight command %q. on or off"):format(word))
return
end
A.say(("marking people you have written about %s, %d %s marked")
:format(A.sightEnabled()and"on"or"off",markedCount(),
markedCount()==1 and"plate"or"plates"))
end
