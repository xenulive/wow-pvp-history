-- WowPvpHistory 0.68.22
-- Author:  Xenu-Sentinels
-- Project: wow-pvp-history
--          https://github.com/xenulive/wow-pvp-history
-- License: MIT, see LICENSE
local _,A=...
local specs={}
local order={}
local placedWindows={}
local queued={}
local SIZE_STEPS=8
local buildFailed={}
function A.buildWindowOnce(kind,build,...)
if buildFailed[kind]~=nil then
buildFailed[kind]=buildFailed[kind]+1
A.trace("build",{kind=kind,state="held",n=buildFailed[kind]},"ui")
return nil
end
local ok,built=pcall(build,...)
if ok and built then
return built
end
buildFailed[kind]=0
A.trace("build",{kind=kind,state="failed",err=not ok and built or nil},"ui")
return nil,not ok and tostring(built)or nil
end
function A.registerWindowKind(kind,spec)
if type(kind)~="string"or kind==""or type(spec)~="table"then
return false
end
if specs[kind]then
return false
end
if type(spec.authored)~="function"or type(spec.floor)~="function"then
return false
end
specs[kind]={
label=type(spec.label)=="string"and spec.label or kind,
authored=spec.authored,
floor=spec.floor,
pooled=spec.pooled==true or nil,
newest=type(spec.newest)=="function"and spec.newest or nil,
sized=type(spec.sized)=="function"and spec.sized or nil,
ceiling=type(spec.ceiling)=="function"and spec.ceiling or nil,
shares=type(spec.shares)=="string"and spec.shares~=kind and spec.shares or nil,
point=type(spec.point)=="string"and spec.point or"CENTER",
x=type(spec.x)=="number"and spec.x or 0,
y=type(spec.y)=="number"and spec.y or 0,
}
order[#order+1]=kind
return true
end
local function ownerOf(kind)
local spec=specs[kind]
if spec and spec.shares and specs[spec.shares]then
return spec.shares
end
return kind
end
local function groupOf(kind)
local owner=ownerOf(kind)
local out={owner}
for i=1,#order do
local other=order[i]
if other~=owner and ownerOf(other)==owner then
out[#out+1]=other
end
end
return out
end
function A.windowShares(kind)
local owner=ownerOf(kind)
if owner==kind then
return nil
end
return owner
end
function A.windowLabel(kind)
local spec=specs[kind]
return spec and spec.label or nil
end
function A.windowFrameOf(kind)
local spec=specs[kind]
if not spec then
return nil
end
if spec.pooled then
if not spec.newest then
return nil
end
local ok,frame=pcall(spec.newest)
return ok and type(frame)=="table"and frame or nil
end
return spec.frame
end
function A.authoredGeometry(kind)
local spec=specs[kind]
if not spec then
return nil
end
local owner=ownerOf(kind)
if owner~=kind then
return A.authoredGeometry(owner)
end
local ok,width,height=pcall(spec.authored)
if not ok or type(width)~="number"or type(height)~="number"then
return nil
end
return width,height,spec.point,spec.x,spec.y
end
local function ownFloor(kind)
local ok,width,height=pcall(specs[kind].floor)
if ok and type(width)=="number"and type(height)=="number"then
return width,height
end
return A.authoredGeometry(kind)
end
function A.windowFloor(kind)
if not specs[kind]then
return nil
end
local width,height
local group=groupOf(kind)
for i=1,#group do
local w,h=ownFloor(group[i])
if type(w)=="number"and(width==nil or w>width)then
width=w
end
if type(h)=="number"and(height==nil or h>height)then
height=h
end
end
if width==nil or height==nil then
return nil
end
return width,height
end
local function ownCeiling(kind)
local spec=specs[kind]
if not spec.ceiling then
return nil
end
local ok,width=pcall(spec.ceiling)
if not(ok and type(width)=="number"and width>0)then
return nil
end
local authored=A.authoredGeometry(kind)
if type(authored)=="number"and authored>width then
return authored
end
return width
end
function A.windowCeiling(kind)
if not specs[kind]then
return nil
end
local narrowest
local group=groupOf(kind)
for i=1,#group do
local width=ownCeiling(group[i])
if type(width)=="number"and(narrowest==nil or width<narrowest)then
narrowest=width
end
end
return narrowest
end
function A.registerPlacedWindow(frame,point,x,y)
if type(frame)~="table"or type(point)~="string"or point==""then
return false
end
for i=1,#placedWindows do
if placedWindows[i].frame==frame then
return false
end
end
local name
local okName,given=pcall(frame.GetName,frame)
if okName and type(given)=="string"and given~=""then
name=given
end
placedWindows[#placedWindows+1]={
frame=frame,
point=point,
x=type(x)=="number"and x or 0,
y=type(y)=="number"and y or 0,
name=name,
}
return true
end
function A.placedWindows()
local out={}
for i=1,#placedWindows do
local held=placedWindows[i]
out[i]={frame=held.frame,point=held.point,x=held.x,y=held.y,name=held.name}
end
return out
end
function A.replacePlacedWindows()
local names,refused={},0
for i=1,#placedWindows do
local held=placedWindows[i]
local ok=pcall(held.frame.ClearAllPoints,held.frame)
if ok then
ok=pcall(held.frame.SetPoint,held.frame,held.point,UIParent,held.point,held.x,held.y)
end
if ok then
names[#names+1]=held.name or("window "..i)
else
refused=refused+1
end
end
return names,refused
end
local function screenSize()
local width,height
if type(GetScreenWidth)=="function"then
local ok,value=pcall(GetScreenWidth)
if ok and type(value)=="number"and value>0 then
width=value
end
end
if type(GetScreenHeight)=="function"then
local ok,value=pcall(GetScreenHeight)
if ok and type(value)=="number"and value>0 then
height=value
end
end
return width,height
end
A.screenSize=screenSize
local function fit(value,floor,ceiling)
if type(value)~="number"then
value=floor
end
if type(ceiling)=="number"and value>ceiling then
value=ceiling
end
if value<floor then
value=floor
end
return value
end
function A.clampGeometry(kind,geometry)
local floorW,floorH=A.windowFloor(kind)
if type(floorW)~="number"or type(floorH)~="number"then
return nil
end
if type(geometry)~="table"then
return nil
end
local screenW,screenH=screenSize()
local maxW=A.windowCeiling(kind)
if type(screenW)=="number"and(maxW==nil or screenW<maxW)then
maxW=screenW
end
local out={
width=fit(geometry.width,floorW,maxW),
height=fit(geometry.height,floorH,screenH),
}
if type(geometry.point)=="string"then
out.point=geometry.point
out.x=type(geometry.x)=="number"and geometry.x or 0
out.y=type(geometry.y)=="number"and geometry.y or 0
end
return out
end
local function store(create)
local db=A.db()
if not db then
return nil
end
db.ui=db.ui or{}
if create then
db.ui.geometry=db.ui.geometry or{}
end
return db.ui.geometry
end
function A.storedGeometry(kind)
if not specs[kind]then
return nil
end
local held=store(false)
local entry=type(held)=="table"and held[ownerOf(kind)]or nil
if type(entry)~="table"then
return nil
end
if type(entry.width)~="number"or type(entry.height)~="number"then
return nil
end
local out={width=entry.width,height=entry.height}
if type(entry.point)=="string"then
out.point=entry.point
out.x=type(entry.x)=="number"and entry.x or 0
out.y=type(entry.y)=="number"and entry.y or 0
end
return out
end
local function isAuthored(kind,geometry)
local width,height,point,x,y=A.authoredGeometry(kind)
if type(width)~="number"then
return false
end
if math.abs(geometry.width-width)>1 or math.abs(geometry.height-height)>1 then
return false
end
if geometry.point==nil then
return true
end
return geometry.point==point and math.abs(geometry.x-x)<=1 and math.abs(geometry.y-y)<=1
end
local function sizeState(geometry)
local width,height=A.unitFigure(geometry.width),A.unitFigure(geometry.height)
if width==nil or height==nil then
return nil
end
return A.ringNumber(width).."x"..A.ringNumber(height)
end
function A.setStoredGeometry(kind,geometry)
if not specs[kind]then
return false
end
local db=A.db()
if not db then
return false
end
local key=ownerOf(kind)
local cleared=geometry==nil or isAuthored(kind,geometry)
if cleared then
local held=store(false)
if type(held)=="table"then
held[key]=nil
if next(held)==nil then
db.ui.geometry=nil
end
end
else
local held=store(true)
if type(held)~="table"then
return false
end
held[key]={
width=geometry.width,
height=geometry.height,
point=geometry.point,
x=geometry.x,
y=geometry.y,
}
end
A.trace("view",{
source="geometry",
state=cleared and"cleared"or sizeState(geometry),
kind=kind,
},"ui")
return true
end
function A.retireSharedGeometry()
local held=store(false)
if type(held)~="table"then
return 0
end
local removed=0
for i=1,#order do
local kind=order[i]
local entry=held[kind]
if entry~=nil and ownerOf(kind)~=kind then
held[kind]=nil
removed=removed+1
local size
if type(entry)=="table"and type(entry.width)=="number"and type(entry.height)=="number"then
size=sizeState(entry)
end
A.trace("window/retire",{kind=kind,state=size or"unsized"},"ui")
end
end
if removed>0 and next(held)==nil then
local db=A.db()
if db and db.ui then
db.ui.geometry=nil
end
end
return removed
end
if type(A.on)=="function"then
A.on("PLAYER_LOGIN",function()
pcall(A.retireSharedGeometry)
end)
end
local ROOM_BRANCHES={
["absent"]=true,
["invalid-rect"]=true,
["no-value"]=true,
["read"]=true,
}
function A.roomBranchKnown(branch)
return type(branch)=="string"and ROOM_BRANCHES[branch]==true
end
function A.rectUnresolved(frame)
if type(frame)~="table"or type(frame.IsRectValid)~="function"then
return false
end
local asked,valid=pcall(frame.IsRectValid,frame)
return asked and valid==false
end
function A.roomBelow(region,host)
if type(region)~="table"or type(host)~="table"then
return nil,"absent"
end
for _,frame in ipairs({region,host})do
if A.rectUnresolved(frame)then
return nil,"invalid-rect"
end
end
local okR,lower=pcall(region.GetBottom,region)
local okH,floor=pcall(host.GetBottom,host)
if not okR or not okH or type(lower)~="number"or type(floor)~="number"then
return nil,"no-value"
end
local room=A.unitFigure(lower-floor)
if room==nil then
return nil,"no-value"
end
if room<0 then
room=0
end
return room,"read"
end
function A.bandHeight(frame)
if not frame then
return nil,"absent"
end
if A.rectUnresolved(frame)then
return nil,"invalid-rect"
end
local ok,height=pcall(frame.GetHeight,frame)
if not ok or type(height)~="number"or height<0 then
return nil,"no-value"
end
return height,"read"
end
function A.roomsAgree(composed,rect)
if type(composed)~="number"or type(rect)~="number"then
return false
end
local gap=composed-rect
if gap<0 then
gap=-gap
end
return gap<1
end
local roomReads={}
function A.noteRoomRead(name,branch,room,region,host,less)
if type(name)~="string"or name==""then
return false
end
roomReads[name]={
branch=A.roomBranchKnown(branch)and branch or"absent",
room=type(room)=="number"and room or nil,
at=select(2,pcall(A.stamp)),
region=type(region)=="table"and region or nil,
host=type(host)=="table"and host or nil,
less=type(less)=="number"and less or 0,
}
return true
end
function A.roomReadNow(name)
local held=type(name)=="string"and roomReads[name]or nil
if not held or not held.region or not held.host then
return nil
end
for _,frame in ipairs({held.region,held.host})do
if type(frame.IsVisible)=="function"then
local ok,up=pcall(frame.IsVisible,frame)
if ok and up==false then
return"unshown",nil
end
end
end
local room,branch=A.roomBelow(held.region,held.host)
if type(room)=="number"then
room=room-held.less
if room<0 then
room=0
end
end
return branch,room
end
function A.lastRoomRead(name)
local held=type(name)=="string"and roomReads[name]or nil
if not held then
return nil
end
return held.branch,held.room,held.at
end
function A.frameGeometry(frame)
if type(frame)~="table"then
return nil
end
local okW,width=pcall(frame.GetWidth,frame)
local okH,height=pcall(frame.GetHeight,frame)
if not okW or not okH or type(width)~="number"or type(height)~="number"then
return nil
end
local out={width=width,height=height}
local ok,point,relativeTo,_,x,y=pcall(frame.GetPoint,frame,1)
if ok and type(point)=="string"and(relativeTo==nil or relativeTo==UIParent)then
out.point=point
out.x=type(x)=="number"and x or 0
out.y=type(y)=="number"and y or 0
end
return out
end
local function place(frame,geometry)
local ok=pcall(frame.SetSize,frame,geometry.width,geometry.height)
if geometry.point then
pcall(frame.ClearAllPoints,frame)
pcall(frame.SetPoint,frame,geometry.point,UIParent,geometry.point,geometry.x,geometry.y)
end
return ok
end
function A.applyStoredGeometry(kind)
local spec=specs[kind]
if not(spec and spec.frame)then
return false
end
local stored=A.storedGeometry(kind)
if not stored then
return false
end
local clamped=A.clampGeometry(kind,stored)
if not clamped then
return false
end
return place(spec.frame,clamped)and true or false
end
function A.applyWindowGeometry()
for i=1,#order do
local kind=order[i]
local spec=specs[kind]
if spec and spec.frame then
local width,height,point,x,y=A.authoredGeometry(kind)
if type(width)=="number"then
place(spec.frame,{width=width,height=height,point=point,x=x,y=y})
end
end
end
return true
end
function A.resetWindowGeometry()
local db=A.db()
if not db then
return false
end
for i=1,#order do
if ownerOf(order[i])==order[i]then
A.setStoredGeometry(order[i],nil)
end
end
A.applyWindowGeometry()
return true
end
function A.replaceOtherWindows()
local names,refused=A.replacePlacedWindows()
if type(A.overlayReplaced)=="function"then
pcall(A.overlayReplaced)
end
local records={}
if type(A.recascadeMatchWindows)=="function"then
local ok,moved=pcall(A.recascadeMatchWindows)
if ok and type(moved)=="table"then
records=moved
end
end
if type(A.trace)=="function"then
local anchors,keys={},{}
for i=1,#records do
keys[#keys+1]=records[i].key or"?"
if records[i].frame and type(A.anchorState)=="function"then
local state=A.anchorState(records[i].frame)
anchors[#anchors+1]=(records[i].key or"?").."="..(state or"unread")
end
end
A.trace("window/replace",{
windowsReset=#names>0 and table.concat(names,"+")or nil,
refusals=refused,
records=#keys>0 and table.concat(keys,"+")or nil,
anchors=#anchors>0 and table.concat(anchors," ")or nil,
},"ui")
end
return names,refused,records
end
function A.resetGeometryLines()
local held=0
for i=1,#order do
if ownerOf(order[i])==order[i]and A.storedGeometry(order[i])~=nil then
held=held+1
end
end
if not A.resetWindowGeometry()then
return{"nothing is stored, so no window geometry could be forgotten"}
end
local out={}
if held==0 then
out[1]="no window geometry was stored, so every window is already at its authored size"
else
out[1]=("%d window%s back at %s authored size and nothing is stored for any window"):format(
held,held==1 and" is"or"s are",held==1 and"its"or"their")
end
local names,refused,records=A.replaceOtherWindows()
local clauses={}
if#names>0 then
clauses[#clauses+1]=("%d other window%s put back"):format(#names,#names==1 and""or"s")
end
if#records>0 then
clauses[#clauses+1]=("%d match window%s re-cascaded")
:format(#records,#records==1 and""or"s")
end
if refused>0 then
clauses[#clauses+1]=("%d refused"):format(refused)
end
if#clauses>0 then
out[#out+1]=table.concat(clauses,", ")
else
out[#out+1]="no other window was open, so there was nothing else to put back"
end
return out
end
local function anchorPoints(frame)
local okN,count=pcall(frame.GetNumPoints,frame)
if not okN or type(count)~="number"then
return nil,nil
end
if count==0 then
return nil,0
end
local names={}
for i=1,count do
local ok,point,_,_,x,y=pcall(frame.GetPoint,frame,i)
if ok and type(point)=="string"then
local atX,atY=A.unitFigure(x),A.unitFigure(y)
if atX and atY then
names[#names+1]=point.."@"..A.ringNumber(atX)..","..A.ringNumber(atY)
else
names[#names+1]=point
end
else
names[#names+1]="unread"
end
end
return names,count
end
function A.anchorState(frame)
local names,count=anchorPoints(frame)
if not names then
return nil,count
end
return table.concat(names,"+"),count
end
local anchorState=A.anchorState
local function rectState(frame)
local ok,left,bottom,width,height=pcall(frame.GetRect,frame)
if not ok then
return nil
end
local atL,atB=A.unitFigure(left),A.unitFigure(bottom)
local size=sizeState({width=width,height=height})
if atL==nil or atB==nil or size==nil then
return nil
end
return A.ringNumber(atL)..","..A.ringNumber(atB)..","..size
end
local function givenState(frame)
local okW,width=pcall(frame.GetWidth,frame,true)
local okH,height=pcall(frame.GetHeight,frame,true)
if not okW or not okH then
return nil
end
return sizeState({width=width,height=height})
end
local function boundsState(frame)
local ok,minW,minH,maxW,maxH=pcall(frame.GetResizeBounds,frame)
if not ok then
return nil
end
local low=sizeState({width=minW,height=minH})
local high=sizeState({width=maxW,height=maxH})
if not(low and high)then
return nil
end
return low.."-"..high
end
local function screenState()
local width,height=screenSize()
return sizeState({width=width,height=height})
end
local function cursorState()
if type(GetCursorPosition)~="function"then
return nil
end
local ok,x,y=pcall(GetCursorPosition)
if not ok then
return nil
end
local scale=1
if UIParent and type(UIParent.GetEffectiveScale)=="function"then
local okS,value=pcall(UIParent.GetEffectiveScale,UIParent)
if okS and type(value)=="number"and value>0 then
scale=value
end
end
local atX,atY=A.unitFigure(x/scale),A.unitFigure(y/scale)
if atX==nil or atY==nil then
return nil
end
return A.ringNumber(atX)..","..A.ringNumber(atY)
end
local function placedState(frame)
if type(frame.IsUserPlaced)~="function"then
return nil
end
local ok,placed=pcall(frame.IsUserPlaced,frame)
if not ok or type(placed)~="boolean"then
return nil
end
return tostring(placed)
end
local function traceGrip(frame,kind,source,step,total,repaint,stored)
local live=A.frameGeometry(frame)
local names,count=anchorState(frame)
A.trace("view",{
source=source,
state=live and sizeState(live)or nil,
n=count,
anchors=names,
rect=rectState(frame),
given=givenState(frame),
bounds=boundsState(frame),
screen=screenState(),
placed=placedState(frame),
cursor=cursorState(),
step=step,
total=total,
repaint=repaint,
releaseStored=stored,
kind=kind,
},"ui")
end
function A.attachResize(frame,kind,onResize)
local spec=specs[kind]
if not(spec and type(frame)=="table")then
return false
end
spec.frame=frame
local floorW,floorH=A.windowFloor(kind)
if type(floorW)~="number"then
return false
end
local screenW,screenH=screenSize()
local maxW=A.windowCeiling(kind)
if type(screenW)=="number"and(maxW==nil or screenW<maxW)then
maxW=screenW
end
if type(maxW)=="number"and maxW<floorW then
maxW=floorW
end
local ok=pcall(frame.SetResizable,frame,true)
if ok then
pcall(frame.SetResizeBounds,frame,floorW,floorH,maxW,screenH)
end
local pressed,steps,resizedInPress=false,0,false
local function queueRepaint()
if queued[kind]then
return
end
queued[kind]=true
local after=C_Timer and C_Timer.After
if type(after)~="function"then
queued[kind]=nil
if onResize then
pcall(onResize)
end
return
end
after(0,function()
queued[kind]=nil
if onResize then
pcall(onResize)
end
end)
end
frame:SetScript("OnSizeChanged",function()
if pressed and type(IsMouseButtonDown)=="function"then
local read,down=pcall(IsMouseButtonDown,"LeftButton")
if read and down==false then
pressed=false
end
end
if pressed then
steps=steps+1
if steps<=SIZE_STEPS then
pcall(traceGrip,frame,kind,"grip-size",steps)
end
resizedInPress=true
return
end
queueRepaint()
end)
local function remember()
local geometry=A.frameGeometry(frame)
if geometry then
A.setStoredGeometry(kind,geometry)
end
end
spec.remember=remember
if type(A.grip)=="function"then
local function released()
pressed=false
pcall(traceGrip,frame,kind,"grip-release",nil,steps,tostring(resizedInPress))
remember()
if resizedInPress then
resizedInPress=false
queueRepaint()
end
end
local function pressedDown()
steps=0
resizedInPress=false
pcall(traceGrip,frame,kind,"grip-press")
pressed=true
end
local function sizingStarted()
pcall(traceGrip,frame,kind,"grip-started")
end
local built,grip=pcall(A.grip,frame,released,pressedDown,sizingStarted)
if built and grip then
frame.grip=grip
grip:SetPoint("BOTTOMRIGHT",frame,"BOTTOMRIGHT",
-A.metric("gripInset"),A.metric("gripInset"))
end
end
A.applyStoredGeometry(kind)
return true
end
function A.attachPooledResize(frame,kind,hooks)
local spec=specs[kind]
if not(spec and spec.pooled and type(frame)=="table"and type(hooks)=="table")then
return false
end
local floorW,floorH=A.windowFloor(kind)
if type(floorW)~="number"then
return false
end
local screenW,screenH=screenSize()
if not pcall(frame.SetResizable,frame,true)then
return false
end
pcall(frame.SetResizeBounds,frame,floorW,floorH,screenW,screenH)
local pressed,steps,resized,before=false,0,false,nil
frame:SetScript("OnSizeChanged",function()
if pressed and type(IsMouseButtonDown)=="function"then
local read,down=pcall(IsMouseButtonDown,"LeftButton")
if read and down==false then
pressed=false
end
end
if not pressed then
return
end
steps=steps+1
if steps<=SIZE_STEPS then
pcall(traceGrip,frame,kind,"grip-size",steps)
end
resized=true
end)
local function repaint()
if type(hooks.repaint)~="function"then
return
end
local after=C_Timer and C_Timer.After
if type(after)~="function"then
pcall(hooks.repaint,frame)
return
end
after(0,function()
pcall(hooks.repaint,frame)
end)
end
local function released()
pressed=false
local stored
if type(hooks.release)=="function"then
local ok,held=pcall(hooks.release,frame,before)
stored=ok and tostring(held==true)or"unread"
end
pcall(traceGrip,frame,kind,"grip-release",nil,steps,tostring(resized),stored)
if resized then
resized=false
repaint()
end
end
local function pressedDown()
steps=0
resized=false
before=A.frameGeometry(frame)
pcall(traceGrip,frame,kind,"grip-press")
pressed=true
end
local function sizingStarted()
pcall(traceGrip,frame,kind,"grip-started")
end
if type(A.grip)~="function"then
return false
end
local built,grip=pcall(A.grip,frame,released,pressedDown,sizingStarted)
if not(built and grip)then
return false
end
frame.grip=grip
grip:SetPoint("BOTTOMRIGHT",frame,"BOTTOMRIGHT",-A.metric("gripInset"),A.metric("gripInset"))
return true
end
function A.pooledOpenSize(kind)
local stored=A.storedGeometry(kind)
if not stored then
return nil
end
return A.clampGeometry(kind,{width=stored.width,height=stored.height})
end
local function sizeFigure(kind,word,axis,current)
local number=tonumber(word)
if number then
return number
end
local floorW,floorH=A.windowFloor(kind)
local authoredW,authoredH=A.authoredGeometry(kind)
if word=="min"then
return axis=="width"and floorW or floorH
elseif word=="authored"then
return axis=="width"and authoredW or authoredH
elseif word=="same"then
return current
elseif word=="max"then
local screenW,screenH=screenSize()
if axis=="height"then
return screenH
end
return A.windowCeiling(kind)or screenW
end
return nil
end
function A.sizeWindow(kind,widthWord,heightWord)
local spec=specs[kind]
if not spec then
return nil,"kind"
end
local target=A.windowFrameOf(kind)
if not target then
return nil,"not built"
end
local live=A.frameGeometry(target)
if not live then
return nil,"unread"
end
local width=sizeFigure(kind,widthWord,"width",live.width)
if width==nil then
return nil,"width"
end
local height=sizeFigure(kind,heightWord or widthWord,"height",live.height)
if height==nil then
return nil,"height"
end
local clamped=A.clampGeometry(kind,{width=width,height=height})
if not clamped then
return nil,"unread"
end
if spec.pooled and spec.sized then
pcall(spec.sized,target,clamped)
else
pcall(target.SetSize,target,clamped.width,clamped.height)
end
local applied=A.frameGeometry(target)
A.trace("view",{
source="typed-size",
state=applied and sizeState(applied)or nil,
kind=kind,
},"ui")
return applied
end
function A.rememberWindow(kind)
local spec=specs[kind]
if not(spec and spec.remember)then
return false
end
spec.remember()
return true
end
local HALVES={"matches","players","stats"}
local RIGHT_HALVES={"settings","about"}
local HALF_WORDS={matches="History",stats="Stats",players="Players",settings="Settings",
about="About"}
local OTHER_HALF={matches="players",players="matches"}
local lastHalf=nil
function A.shareCorner(from,kind)
local source,target=A.windowFrameOf(from),A.windowFrameOf(kind)
if type(source)~="table"or type(target)~="table"or type(UIParent)~="table"then
return false,false
end
local ok,left,bottom,width,height=pcall(source.GetRect,source)
local okParent,parentHeight=pcall(UIParent.GetHeight,UIParent)
if not ok or type(left)~="number"or type(bottom)~="number"or type(height)~="number"
or not okParent or type(parentHeight)~="number"
then
return false,false
end
local sized=false
if type(width)=="number"then
sized=pcall(target.SetSize,target,width,height)
end
pcall(target.ClearAllPoints,target)
pcall(target.SetPoint,target,"TOPLEFT",UIParent,"TOPLEFT",left,bottom+height-parentHeight)
return true,sized,rectState(source)
end
local function carryHidden(from,kind)
local source,target=A.windowFrameOf(from),A.windowFrameOf(kind)
if type(source)~="table"or type(target)~="table"then
return false
end
local geometry=A.frameGeometry(source)
if not geometry then
return false
end
return place(target,geometry)
end
function A.takeHalf(kind)
local other=OTHER_HALF[kind]
local from=other and A.windowFrameOf(other)
if type(from)~="table"then
if other then
lastHalf=kind
end
return false
end
local ok,shown=pcall(from.IsShown,from)
if not(ok and shown)then
if lastHalf==other then
local carried=carryHidden(other,kind)
A.trace("half",{source=kind,format=other,state=carried and"carried"or"uncarried"},
"ui")
end
lastHalf=kind
return false
end
local cornered,sized,rect=A.shareCorner(other,kind)
pcall(from.Hide,from)
local state="unmoved"
if cornered then
state=sized and"moved"or"cornered"
end
A.trace("half",{source=kind,format=other,state=state,rect=rect},"ui")
lastHalf=kind
return true
end
function A.openHalf(kind)
if kind=="players"then
return A.showNotes and A.showNotes()or false
end
if kind=="settings"then
local where,why=A.openSettings()
if not where and type(A.settingsRefused)=="function"then
A.say(A.settingsRefused(why))
end
return where~=nil
end
if kind=="about"then
return A.showAboutBody and A.showAboutBody()or false
end
if type(A.showWindowBody)=="function"then
return A.showWindowBody(kind=="stats"and"stats"or"history")
end
return A.showWindow and A.showWindow()or false
end
function A.setHalfTabsChosen(tabs,chosen)
if type(tabs)~="table"then
return false
end
local held=false
for i=1,#tabs do
local tab=tabs[i]
if type(tab)=="table"then
A.setPanelTabSelected(tab,tab.halfKind==chosen)
held=held or tab.halfKind==chosen
end
end
return held
end
function A.halfTabs(frame,chosen)
local tabs={}
local function build(kind)
local tab=A.panelTab(frame,HALF_WORDS[kind],function()
A.openHalf(kind)
end)
tab.halfKind=kind
A.setPanelTabSelected(tab,kind==chosen)
tab:Show()
return tab
end
for i=1,#HALVES do
local tab=build(HALVES[i])
if i==1 then
tab:SetPoint("TOPLEFT",frame,"BOTTOMLEFT",A.metric("panelTabInset"),
A.metric("panelTabOverlap"))
else
tab:SetPoint("TOPLEFT",tabs[i-1],"TOPRIGHT",A.metric("panelTabGap"),0)
end
tabs[i]=tab
end
local right={}
for i=1,#RIGHT_HALVES do
local tab=build(RIGHT_HALVES[i])
if i==1 then
tab:SetPoint("TOPRIGHT",frame,"BOTTOMRIGHT",-A.metric("panelTabInset"),
A.metric("panelTabOverlap"))
else
tab:SetPoint("TOPRIGHT",right[i-1],"TOPLEFT",-A.metric("panelTabGap"),0)
end
right[i]=tab
end
for i=#right,1,-1 do
tabs[#tabs+1]=right[i]
end
return tabs
end
function A.halfTabsClear(tabs,width)
if type(tabs)~="table"or type(width)~="number"then
return nil
end
local inset,gap=A.metric("panelTabInset"),A.metric("panelTabGap")
local leftEdge,rightEdge=inset,width-inset
local leftCount=0
for i=1,#tabs do
local tab=tabs[i]
local okWidth,tabWidth=pcall(tab.GetWidth,tab)
if not(okWidth and type(tabWidth)=="number")then
return nil
end
local onRight=tab.halfKind=="settings"or tab.halfKind=="about"
if onRight then
rightEdge=rightEdge-tabWidth
else
leftEdge=leftEdge+tabWidth
leftCount=leftCount+1
end
end
leftEdge=leftEdge+gap*math.max(leftCount-1,0)
rightEdge=rightEdge-gap*math.max(#tabs-leftCount-1,0)
return leftEdge<rightEdge,leftEdge,rightEdge
end
local function whole(value)
if type(value)~="number"then
return"unknown"
end
return tostring(math.floor(value+0.5))
end
local function anchorClause(frame)
local names,count=anchorPoints(frame)
if type(count)~="number"then
return"anchors unread"
end
if count==0 or not names then
return"on no point"
end
local bare={}
for i=1,#names do
bare[i]=names[i]:match("^([^@]+)")or names[i]
end
if count==1 then
return"on one point, "..bare[1]
end
return("on %d points, %s"):format(count,table.concat(bare," and "))
end
function A.geometryLines()
local out={}
for i=1,#order do
local kind=order[i]
local spec=specs[kind]
local width,height=A.authoredGeometry(kind)
local floorW,floorH=A.windowFloor(kind)
local ceiling=A.windowCeiling(kind)
out[#out+1]=("%s  authored %sx%s, smallest %sx%s, largest %s")
:format(spec.label,whole(width),whole(height),whole(floorW),whole(floorH),
ceiling and(whole(ceiling).." wide, the screen tall")or"the screen")
local ownW=ownFloor(kind)
local binder
if type(ownW)=="number"and type(floorW)=="number"and ownW<floorW then
local group=groupOf(kind)
for g=1,#group do
if group[g]~=kind and ownFloor(group[g])==floorW then
binder=group[g]
break
end
end
end
local why=type(A.matchFloorReason)=="function"and kind=="matches"and A.matchFloorReason()
or nil
if binder and why then
out[#out+1]=("    smallest because the %s half needs it; alone this stops at %s because %s")
:format(A.windowLabel(binder)or binder,whole(ownW),why)
elseif binder then
out[#out+1]=("    smallest because the %s half needs it; alone this stops at %s")
:format(A.windowLabel(binder)or binder,whole(ownW))
elseif why then
out[#out+1]="    smallest because "..why
end
local shares=A.windowShares(kind)
if shares then
out[#out+1]=("    one size and place with the %s, stored under its entry")
:format(A.windowLabel(shares)or shares)
end
local stored=A.storedGeometry(kind)
if stored then
local where=stored.point
and(" at %s %d, %d"):format(stored.point,stored.x,stored.y)
or", no stored position"
out[#out+1]=("    stored %sx%s%s"):format(whole(stored.width),whole(stored.height),where)
else
out[#out+1]="    stored nothing, so it opens at the authored size"
end
local shown=A.windowFrameOf(kind)
local live=shown and A.frameGeometry(shown)or nil
if shown and live then
local okW,givenW=pcall(shown.GetWidth,shown,true)
local okH,givenH=pcall(shown.GetHeight,shown,true)
local given=(okW and okH and type(givenW)=="number"and type(givenH)=="number")
and(", given %sx%s"):format(whole(givenW),whole(givenH))or", given size unread"
out[#out+1]=("    applied %sx%s %s%s%s"):format(whole(live.width),whole(live.height),
anchorClause(shown),given,spec.pooled and", on the newest one open"or"")
elseif spec.pooled then
out[#out+1]=("    applied nothing, no %s being open"):format(spec.label)
else
out[#out+1]="    applied nothing, the window not having been built this session"
end
end
local rows=A.placedWindows()
if#rows>0 then
out[#out+1]=("%d window%s carry one authored place and store nothing")
:format(#rows,#rows==1 and""or"s")
for i=1,#rows do
local row=rows[i]
local live=row.frame and A.frameGeometry(row.frame)or nil
local size=live and("applied %sx%s"):format(whole(live.width),whole(live.height))
or"size unread"
out[#out+1]=("    %s  authored at %s %s, %s, %s")
:format(row.name or("window "..i),row.point,whole(row.x)..", "..whole(row.y),
size,row.frame and anchorClause(row.frame)or"anchors unread")
end
else
out[#out+1]="no window with one authored place has been built this session"
end
return out
end
