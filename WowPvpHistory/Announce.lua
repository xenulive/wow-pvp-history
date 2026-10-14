-- WowPvpHistory 0.68.21
-- Author:  Xenu-Sentinels
-- Project: wow-pvp-history
--          https://github.com/xenulive/wow-pvp-history
-- License: MIT, see LICENSE
local _,A=...
local GetNumBattlefieldScores=GetNumBattlefieldScores
local SCREEN_UNITS=768
local TOP_DROP=SCREEN_UNITS/6
local RISE_SECONDS=0.5
local FALL_SECONDS=0.5
local BASE_SECONDS=4
local LINE_SECONDS=1
local SECONDS_LINE_CEILING=15
local FIRST_READ=2
local RETRY_EVERY=3
local SETTLE_READS=3
local MAX_ATTEMPTS=20
local firedFor
local reported=false
local banner
function A.announceEnabled()
local db=A.db()
if not db then
return false
end
db.ui=db.ui or{}
return db.ui.announce~=false
end
function A.setAnnounce(enabled)
local db=A.db()
if not db then
return false
end
db.ui=db.ui or{}
if enabled==false then
db.ui.announce=false
else
db.ui.announce=nil
end
if A.notifyAnnounceSetting then
A.notifyAnnounceSetting()
end
return true
end
local TIME_MIN,TIME_MAX,TIME_STEP,TIME_DEFAULT=50,300,10,100
local SIZE_MIN,SIZE_MAX,SIZE_STEP,SIZE_DEFAULT=75,150,5,100
local OPACITY_MIN,OPACITY_MAX,OPACITY_STEP,OPACITY_DEFAULT=0,100,5,85
local FIT_FLOOR=50
local function percentage(value,min,max,step)
if type(value)~="number"or value~=value then
return nil
end
if value~=math.floor(value)or value<min or value>max then
return nil
end
if(value-min)%step~=0 then
return nil
end
return value
end
local function rounded(value,min,max,step)
if type(value)~="number"or value~=value
or value==math.huge or value==-math.huge
then
return nil
end
return percentage(math.floor(value+0.5),min,max,step)
end
function A.announceTime()
local db=A.db()
if not db or type(db.ui)~="table"then
return TIME_DEFAULT
end
return percentage(db.ui.announceTime,TIME_MIN,TIME_MAX,TIME_STEP)or TIME_DEFAULT
end
function A.announceTimeRange()
return TIME_MIN,TIME_MAX,TIME_STEP,TIME_DEFAULT
end
function A.setAnnounceTime(value)
local db=A.db()
if not db then
return false
end
local want=rounded(value,TIME_MIN,TIME_MAX,TIME_STEP)
if want==nil then
return false
end
db.ui=db.ui or{}
db.ui.announceTime=want~=TIME_DEFAULT and want or nil
if A.notifyAnnounceTimeSetting then
A.notifyAnnounceTimeSetting()
end
return true
end
function A.announceSize()
local db=A.db()
if not db or type(db.ui)~="table"then
return SIZE_DEFAULT
end
return percentage(db.ui.announceSize,SIZE_MIN,SIZE_MAX,SIZE_STEP)or SIZE_DEFAULT
end
function A.announceSizeRange()
return SIZE_MIN,SIZE_MAX,SIZE_STEP,SIZE_DEFAULT
end
function A.setAnnounceSize(value)
local db=A.db()
if not db then
return false
end
local want=rounded(value,SIZE_MIN,SIZE_MAX,SIZE_STEP)
if want==nil then
return false
end
db.ui=db.ui or{}
db.ui.announceSize=want~=SIZE_DEFAULT and want or nil
if A.notifyAnnounceSizeSetting then
A.notifyAnnounceSizeSetting()
end
if A.announcePreviewActive and A.announcePreviewActive()then
pcall(A.announcePreview)
end
return true
end
function A.announceOpacity()
local db=A.db()
if not db or type(db.ui)~="table"then
return OPACITY_DEFAULT
end
return percentage(db.ui.announceOpacity,OPACITY_MIN,OPACITY_MAX,OPACITY_STEP)or OPACITY_DEFAULT
end
function A.announceOpacityRange()
return OPACITY_MIN,OPACITY_MAX,OPACITY_STEP,OPACITY_DEFAULT
end
function A.setAnnounceOpacity(value)
local db=A.db()
if not db then
return false
end
local want=rounded(value,OPACITY_MIN,OPACITY_MAX,OPACITY_STEP)
if want==nil then
return false
end
db.ui=db.ui or{}
db.ui.announceOpacity=want~=OPACITY_DEFAULT and want or nil
if A.notifyAnnounceOpacitySetting then
A.notifyAnnounceOpacitySetting()
end
if A.announcePreviewActive and A.announcePreviewActive()then
pcall(A.announcePreview)
end
return true
end
local SHAPES={
{value="split",label="Side by side",said="side by side"},
{value="stacked",label="One column",said="in one column"},
}
local SHAPE_DEFAULT="split"
local function isShape(value)
for i=1,#SHAPES do
if SHAPES[i].value==value then
return true
end
end
return false
end
local heldShape
function A.announceShape()
if heldShape~=nil then
return heldShape
end
return A.announceStoredShape()
end
function A.announceStoredShape()
local db=A.db()
if not db or type(db.ui)~="table"then
return SHAPE_DEFAULT
end
local held=db.ui.announceShape
if isShape(held)then
return held
end
return SHAPE_DEFAULT
end
function A.announceShapeChoices()
local out={}
for i=1,#SHAPES do
out[i]={value=SHAPES[i].value,label=SHAPES[i].label,said=SHAPES[i].said}
end
return out
end
function A.setAnnounceShape(value)
local db=A.db()
if not db or not isShape(value)then
return false
end
db.ui=db.ui or{}
db.ui.announceShape=value~=SHAPE_DEFAULT and value or nil
heldShape=nil
if A.notifyAnnounceShapeSetting then
A.notifyAnnounceShapeSetting()
end
if A.announcePreviewActive and A.announcePreviewActive()then
pcall(A.announcePreview)
end
return true
end
function A.holdAnnounceShape(value)
if value~=nil and not isShape(value)then
return false
end
heldShape=value
if A.announcePreviewActive and A.announcePreviewActive()then
pcall(A.announcePreview)
end
A.trace("view",{source="typed-shape",shape=A.announceShape(),state=A.announceStoredShape()},
"ui")
return true
end
function A.announceHeldShape()
return heldShape
end
local heldLocked
local reconsider
function A.announceLocked()
if heldLocked~=nil then
return heldLocked
end
return A.announceStoredLocked()
end
function A.announceStoredLocked()
local db=A.db()
if not db or type(db.ui)~="table"then
return true
end
return db.ui.announceUnlocked~=true
end
function A.setAnnounceLocked(on)
local db=A.db()
if not db then
return false
end
db.ui=db.ui or{}
db.ui.announceUnlocked=(not on)and true or nil
heldLocked=nil
if A.notifyAnnounceLockSetting then
A.notifyAnnounceLockSetting()
end
reconsider(on and"locked"or"unlocked")
return true
end
function A.holdAnnounceLocked(value)
if value~=nil and type(value)~="boolean"then
return false
end
heldLocked=value
if type(A.refreshOptionsWindow)=="function"then
pcall(A.refreshOptionsWindow)
end
A.trace("view",{source="typed-lock",unlocked=not A.announceLocked(),held=heldLocked~=nil},
"ui")
reconsider(A.announceLocked()and"locked"or"unlocked")
return true
end
function A.announceHeldLocked()
return heldLocked
end
local function timedLines(composed)
local lines=0
if type(composed)=="table"then
if type(composed.names)=="table"then
lines=#composed.names
end
if type(composed.tagLines)=="number"then
lines=lines+composed.tagLines
end
end
return lines
end
function A.announceSeconds(composed)
local seconds=BASE_SECONDS+math.min(timedLines(composed),SECONDS_LINE_CEILING)*LINE_SECONDS
return seconds*A.announceTime()/100
end
function A.announceFullSeconds()
local names={}
for i=1,SECONDS_LINE_CEILING do
names[i]=true
end
return A.announceSeconds({names=names,tagLines=0})
end
function A.announceFit(width,room,chosen)
if type(chosen)~="number"then
chosen=SIZE_DEFAULT
end
if type(width)~="number"or width<=0 or type(room)~="number"or room<=0 then
return chosen
end
local fits=math.floor(room*100/width)
if fits>=chosen then
return chosen
end
if fits<FIT_FLOOR then
return FIT_FLOOR
end
return fits
end
local DEFAULT_POINT="TOP"
local DEFAULT_X=0
local DEFAULT_Y=-TOP_DROP
local function whole(value)
if type(value)~="number"then
return nil
end
return math.floor(value+0.5)
end
function A.announcePosition()
local db=A.db()
if not db or type(db.ui)~="table"then
return nil
end
local held=db.ui.announcePosition
if type(held)~="table"or type(held.point)~="string"then
return nil
end
local x,y=whole(held.x),whole(held.y)
if x==nil or y==nil then
return nil
end
return{point=held.point,x=x,y=y}
end
function A.setAnnouncePosition(geometry)
local db=A.db()
if not db then
return false
end
db.ui=db.ui or{}
local point=type(geometry)=="table"and geometry.point or nil
local x=type(geometry)=="table"and whole(geometry.x)or nil
local y=type(geometry)=="table"and whole(geometry.y)or nil
if type(point)~="string"or x==nil or y==nil
or(point==DEFAULT_POINT and x==whole(DEFAULT_X)and y==whole(DEFAULT_Y))
then
db.ui.announcePosition=nil
return true
end
db.ui.announcePosition={point=point,x=x,y=y}
return true
end
local function contained(fn,...)
local ok,err=pcall(fn,...)
if ok then
return
end
A.noteError(err,"announce")
if not reported then
reported=true
A.say("the roster announcement stopped: "..tostring(err)
..". /pvph announce off silences it")
end
end
local SIDES={
{side="against",label="VS",tone="loss"},
{side="with",label="WITH",tone="win"},
}
local NO_RECORD="-"
local RECORD_BUCKETS={
against={"against"},
with={"with"},
summed={"against","with"},
}
local function recordText(held,side)
if type(held)~="table"then
return NO_RECORD
end
local wins,decided,draws=0,0,0
for _,key in ipairs(RECORD_BUCKETS[side]or RECORD_BUCKETS.summed)do
local bucket=held[key]
if type(bucket)=="table"then
wins=wins+(tonumber(bucket.wins)or 0)
decided=decided+(tonumber(bucket.decided)or 0)
draws=draws+(tonumber(bucket.draws)or 0)
end
end
if decided<=0 then
return NO_RECORD
end
return A.winRecordText({wins=wins,decided=decided,draws=draws})or NO_RECORD
end
local function worstFirst(a,b)
local ra,rb=a.rating,b.rating
if ra~=rb then
if ra==nil then
return false
end
if rb==nil then
return true
end
return ra<rb
end
if ra==nil then
local ta,tb=a.text~=nil,b.text~=nil
if ta~=tb then
return ta
end
local ma,mb=a.met or 0,b.met or 0
if ma~=mb then
return ma>mb
end
end
return a.name<b.name
end
local function isNoted(it)
return type(it.text)=="string"and it.text~=""
end
local function notedFirst(a,b)
local na,nb=isNoted(a),isNoted(b)
if na~=nb then
return na
end
return worstFirst(a,b)
end
local function sideOf(selfFaction,faction)
if selfFaction==nil or faction==nil then
return nil
end
if faction==selfFaction then
return"with"
end
return"against"
end
local function compose(found,selfFaction,everyoneWith)
if#found==0 then
return nil
end
table.sort(found,notedFirst)
local noted=0
for i=1,#found do
if found[i].text~=nil or found[i].rating~=nil then
noted=noted+1
end
end
local names={}
local read={against=0,with=0,summed=0}
for i=1,#found do
local it=found[i]
local side=everyoneWith and"with"or sideOf(selfFaction,it.faction)
read[side or"summed"]=read[side or"summed"]+1
names[i]={
name=it.name,
classToken=it.classToken,
rating=it.rating,
mark=it.mark,
side=side,
record=recordText(it.held,side),
tags=type(it.tags)=="table"and it.tags or{},
noted=isNoted(it),
}
end
local runs={}
for s=1,#SIDES+1 do
local want=SIDES[s]and SIDES[s].side or nil
local members={}
for i=1,#names do
if names[i].side==want then
members[#members+1]=names[i]
end
end
if#members>0 then
runs[#runs+1]={
side=want,
label=SIDES[s]and SIDES[s].label or nil,
tone=SIDES[s]and SIDES[s].tone or nil,
names=members,
}
end
end
local tagLines=0
for i=1,#names do
if#names[i].tags>0 then
tagLines=tagLines+1
end
end
return{
count=#found,
noted=noted,
tagLines=tagLines,
readAgainst=read.against,
readWith=read.with,
readSummed=read.summed,
names=names,
runs=runs,
}
end
function A.announceKnown(rows,selfName,selfQualified,nameIndex)
if type(rows)~="table"or#rows==0 then
return nil
end
local db=A.db()
local players=(db and type(db.players)=="table")and db.players or{}
local index=type(nameIndex)=="table"and nameIndex or A.playerNameIndex()
local found,seen={},{}
for i=1,#rows do
local row=rows[i]
local name=type(row)=="table"and row.name or nil
if type(name)=="string"and name~=""
and name~=selfName and name~=selfQualified
then
local guid=A.playerByName(index,name)
if guid and not seen[guid]then
seen[guid]=true
local note=A.noteFor(guid)
local text=type(note)=="table"and note.text or nil
local rating=type(note)=="table"and note.rating or nil
local tags=type(note)=="table"and note.tags or nil
local held=players[guid]
local met=(type(held)=="table"and type(held.matches)=="number")
and held.matches or 0
if text~=nil or rating~=nil or met>0 then
found[#found+1]={
guid=guid,
name=name,
classToken=row.classToken,
faction=row.faction,
rating=rating,
mark=A.ratingMark(rating),
text=text,
tags=tags,
met=met,
held=held,
}
end
end
end
end
local selfFaction=nil
for i=1,#rows do
local row=rows[i]
local name=type(row)=="table"and row.name or nil
if name~=nil and(name==selfName or name==selfQualified)then
selfFaction=row.faction
break
end
end
return compose(found,selfFaction)
end
local function classFor(guid)
local fn=GetPlayerInfoByGUID
if type(fn)~="function"then
return nil
end
local ok,_,token=pcall(fn,guid)
if ok and type(token)=="string"and A.canRead(token)and token~=""then
return token
end
return nil
end
function A.announceGroup(guids,selfGuid)
if type(guids)~="table"or#guids==0 then
return nil,{}
end
local db=A.db()
local players=(db and type(db.players)=="table")and db.players or{}
local found,seen,qualified={},{},{}
for i=1,#guids do
local guid=guids[i]
if type(guid)=="string"and guid~=""and guid~=selfGuid and not seen[guid]then
seen[guid]=true
local held=players[guid]
if type(held)~="table"then
held=nil
end
local note=A.noteFor(guid)
local text=type(note)=="table"and note.text or nil
local rating=type(note)=="table"and note.rating or nil
local tags=type(note)=="table"and note.tags or nil
local met=(held and type(held.matches)=="number")and held.matches or 0
local name=held and type(held.names)=="table"and held.names[1]or nil
if type(name)~="string"or name==""then
name=type(note)=="table"and note.name or nil
end
if(text~=nil or rating~=nil or met>0)and type(name)=="string"and name~=""then
qualified[#qualified+1]=guid
found[#found+1]={
guid=guid,
name=name,
classToken=classFor(guid),
rating=rating,
mark=A.ratingMark(rating),
text=text,
tags=tags,
met=met,
held=held,
}
end
end
end
return compose(found,nil,true),qualified
end
local previewUp=false
local plateUp=false
local PLATE_WORD="Announcement"
local FRAME_NAME="WowPvpHistoryAnnounce"
local drawnScale=1
local fadeStarted
local dragFrom
local NOTHING_READ={}
local drawnPercent
local ANCHOR_X={
TOPLEFT="left",LEFT="left",BOTTOMLEFT="left",
TOPRIGHT="right",RIGHT="right",BOTTOMRIGHT="right",
TOP="centre",BOTTOM="centre",CENTER="centre",
}
local ANCHOR_Y={
TOPLEFT="top",TOP="top",TOPRIGHT="top",
LEFT="middle",CENTER="middle",RIGHT="middle",
BOTTOMLEFT="bottom",BOTTOM="bottom",BOTTOMRIGHT="bottom",
}
local function screenWidth()
if type(UIParent)~="table"or type(UIParent.GetWidth)~="function"then
return nil
end
local ok,width=pcall(UIParent.GetWidth,UIParent)
if not ok or type(width)~="number"or width<=0 then
return nil
end
return width
end
local function screenRoom()
local width=screenWidth()
if width==nil then
return nil
end
local stored=A.announcePosition()
local point=stored and stored.point or DEFAULT_POINT
local x=stored and stored.x or DEFAULT_X
local side=ANCHOR_X[point]
if side==nil then
return nil
end
local centre
if side=="left"then
centre=x+SCREEN_UNITS/2
elseif side=="right"then
centre=width+x-SCREEN_UNITS/2
else
centre=width/2+x
end
local near=math.min(centre,width-centre)
if near<=0 then
return nil
end
return near*2
end
local function screenBelow()
local stored=A.announcePosition()
local point=stored and stored.point or DEFAULT_POINT
local y=stored and stored.y or DEFAULT_Y
local edge=ANCHOR_Y[point]
if edge==nil then
return nil
end
local frameHeight=SCREEN_UNITS/6
local top
if edge=="top"then
top=SCREEN_UNITS+y
elseif edge=="middle"then
top=SCREEN_UNITS/2+y+frameHeight/2
else
top=y+frameHeight
end
if top<=0 then
return nil
end
return math.min(top,SCREEN_UNITS)
end
local function placeAt(frame,scale)
local stored=A.announcePosition()
local point=stored and stored.point or DEFAULT_POINT
local x=stored and stored.x or DEFAULT_X
local y=stored and stored.y or DEFAULT_Y
pcall(frame.ClearAllPoints,frame)
pcall(frame.SetPoint,frame,point,UIParent,point,x/scale,y/scale)
end
local function applyScale(frame,percent)
local scale=percent/100
drawnScale=scale
drawnPercent=percent
pcall(frame.SetScale,frame,scale)
pcall(frame.SetSize,frame,SCREEN_UNITS/scale,(SCREEN_UNITS/6)/scale)
placeAt(frame,scale)
end
local function escapeList(on)
if type(UISpecialFrames)~="table"then
return
end
for i=#UISpecialFrames,1,-1 do
if UISpecialFrames[i]==FRAME_NAME then
if on then
return
end
table.remove(UISpecialFrames,i)
end
end
if on then
UISpecialFrames[#UISpecialFrames+1]=FRAME_NAME
end
end
local function release(frame)
previewUp=false
plateUp=false
if type(frame)=="table"and frame.word then
pcall(frame.word.Hide,frame.word)
end
dragFrom=nil
escapeList(false)
if type(A.refreshOptionsWindow)=="function"then
pcall(A.refreshOptionsWindow)
end
if type(frame)~="table"then
return
end
pcall(frame.EnableMouse,frame,false)
pcall(frame.SetMovable,frame,false)
end
local function hold(frame)
frame:SetScript("OnUpdate",nil)
fadeStarted=nil
dragFrom=nil
frame:SetMovable(true)
frame:EnableMouse(true)
frame:SetAlpha(1)
previewUp=true
escapeList(true)
frame:Show()
if type(A.refreshOptionsWindow)=="function"then
pcall(A.refreshOptionsWindow)
end
end
reconsider=function(cause,deferred)
local windowUp=type(A.optionsWindowShown)=="function"and A.optionsWindowShown()
if not plateUp and not windowUp then
return
end
if deferred and type(C_Timer)=="table"and type(C_Timer.After)=="function"then
C_Timer.After(0,function()
A.announcePlateRefresh(cause)
end)
return
end
A.announcePlateRefresh(cause)
end
local GROUND={0.055,0.059,0.071}
local GROUND_EDGE={1,1,1,0.1}
local TAG_EDGE={1,1,1,0.2}
local SIDE_RULE={1,1,1,0.25}
local NOTE_MARK="N"
local function edgeAlpha(opacity)
return math.min(1,GROUND_EDGE[4]*(opacity/OPACITY_DEFAULT))
end
local function colourEdges(edges,r,g,b,a)
for i=1,#edges do
edges[i]:SetColorTexture(r,g,b,a)
end
end
local function applyOpacity(frame,opacity)
local rim=edgeAlpha(opacity)
frame.plate:SetColorTexture(GROUND[1],GROUND[2],GROUND[3],opacity/100)
colourEdges(frame.edges,GROUND_EDGE[1],GROUND_EDGE[2],GROUND_EDGE[3],rim)
for i=1,#frame.pills do
local pill=frame.pills[i]
pill.ground:SetColorTexture(GROUND[1],GROUND[2],GROUND[3],opacity/100)
colourEdges(pill.edges,GROUND_EDGE[1],GROUND_EDGE[2],GROUND_EDGE[3],rim)
end
end
local function fourEdges(frame,layer)
local out={}
for i=1,4 do
out[i]=frame:CreateTexture(nil,layer)
end
return out
end
local function box(edges,origin,x,y,w,h)
local top,bottom,left,right=edges[1],edges[2],edges[3],edges[4]
for i=1,4 do
edges[i]:ClearAllPoints()
edges[i]:Show()
end
top:SetPoint("TOPLEFT",origin,"TOPLEFT",x,-y)
top:SetSize(w,1)
bottom:SetPoint("TOPLEFT",origin,"TOPLEFT",x,-(y+h-1))
bottom:SetSize(w,1)
left:SetPoint("TOPLEFT",origin,"TOPLEFT",x,-y)
left:SetSize(1,h)
right:SetPoint("TOPLEFT",origin,"TOPLEFT",x+w-1,-y)
right:SetSize(1,h)
end
local function hideAll(list)
for i=1,#list do
list[i]:Hide()
end
end
local function text(frame,role,colorName)
local fs=frame:CreateFontString(nil,"OVERLAY")
A.style(fs,role,colorName)
fs:SetJustifyH("LEFT")
fs:SetWordWrap(false)
return fs
end
local function build()
if banner then
return banner
end
if type(CreateFrame)~="function"then
return nil
end
local frame=CreateFrame("Frame",FRAME_NAME,UIParent)
if type(frame)~="table"or type(frame.EnableMouse)~="function"then
return nil
end
frame:EnableMouse(false)
placeAt(frame,drawnScale)
frame:SetSize(SCREEN_UNITS,SCREEN_UNITS/6)
frame:SetScript("OnHide",function(self)
local was=plateUp and"plate"or(previewUp and"preview"or"banner")
local readable,stillShown=pcall(self.IsShown,self)
if readable and stillShown then
A.trace("view",{source="banner-hide",state="ignored",kind=was},"ui")
return
end
release(self)
if was~="plate"then
reconsider(was=="preview"and"preview-ended"or"banner-ended",true)
end
end)
frame:SetClampedToScreen(true)
frame:SetMovable(false)
frame:RegisterForDrag("LeftButton")
frame:SetScript("OnDragStart",function(self)
if not pcall(self.StartMoving,self)then
return
end
if fadeStarted~=nil and not previewUp and type(GetTime)=="function"then
dragFrom=GetTime()
self:SetAlpha(1)
end
end)
frame:SetScript("OnDragStop",function(self)
pcall(self.StopMovingOrSizing,self)
local paused
if dragFrom~=nil and fadeStarted~=nil then
local now=GetTime()
paused=now-dragFrom
fadeStarted=now-math.max(dragFrom-fadeStarted,RISE_SECONDS)
end
dragFrom=nil
local read=A.frameGeometry(self)
if read and read.point then
read.x=read.x*drawnScale
read.y=read.y*drawnScale
A.setAnnouncePosition(read)
end
local at=read or NOTHING_READ
A.trace("announce",{
reason="moved",
held=previewUp,
drag=plateUp and"plate"or(previewUp and"preview"or"banner"),
point=at.point,
x=A.unitFigure(at.x),
y=A.unitFigure(at.y),
paused=A.unitFigure(paused),
})
end)
frame:Hide()
frame.plate=frame:CreateTexture(nil,"BACKGROUND")
frame.plate:SetPoint("TOP",frame,"TOP",0,0)
frame.plate:Hide()
frame.edges=fourEdges(frame,"BORDER")
frame.edges[1]:SetPoint("TOPLEFT",frame.plate,"TOPLEFT",0,0)
frame.edges[1]:SetPoint("TOPRIGHT",frame.plate,"TOPRIGHT",0,0)
frame.edges[1]:SetHeight(1)
frame.edges[2]:SetPoint("BOTTOMLEFT",frame.plate,"BOTTOMLEFT",0,0)
frame.edges[2]:SetPoint("BOTTOMRIGHT",frame.plate,"BOTTOMRIGHT",0,0)
frame.edges[2]:SetHeight(1)
frame.edges[3]:SetPoint("TOPLEFT",frame.plate,"TOPLEFT",0,0)
frame.edges[3]:SetPoint("BOTTOMLEFT",frame.plate,"BOTTOMLEFT",0,0)
frame.edges[3]:SetWidth(1)
frame.edges[4]:SetPoint("TOPRIGHT",frame.plate,"TOPRIGHT",0,0)
frame.edges[4]:SetPoint("BOTTOMRIGHT",frame.plate,"BOTTOMRIGHT",0,0)
frame.edges[4]:SetWidth(1)
hideAll(frame.edges)
frame.labels={}
for i=1,#SIDES do
local label=text(frame,"announceLabel",SIDES[i].tone)
label:SetText(SIDES[i].label)
label:Hide()
frame.labels[SIDES[i].side]=label
end
frame.divider=frame:CreateTexture(nil,"ARTWORK")
frame.divider:SetColorTexture(SIDE_RULE[1],SIDE_RULE[2],SIDE_RULE[3],SIDE_RULE[4])
frame.divider:Hide()
frame.pills={}
frame.word=frame:CreateFontString(nil,"OVERLAY")
A.style(frame.word,"label","text")
frame.word:SetJustifyH("CENTER")
frame.word:SetWordWrap(false)
frame.word:SetPoint("CENTER",frame.plate,"CENTER",0,0)
frame.word:Hide()
banner=frame
return banner
end
local function pillAt(frame,i)
local pill=frame.pills[i]
if pill then
return pill
end
pill={chips={}}
pill.ground=frame:CreateTexture(nil,"BACKGROUND")
pill.edges=fourEdges(frame,"BORDER")
pill.bar=frame:CreateTexture(nil,"ARTWORK")
pill.name=text(frame,"announceName","bright")
pill.record=text(frame,"announceRecord","dim")
pill.mark=frame:CreateTexture(nil,"ARTWORK")
pill.mark:SetColorTexture(A.color("noteWord"))
pill.markText=text(frame,"announceMark")
pill.markText:SetJustifyH("CENTER")
pill.markText:SetText(NOTE_MARK)
local r,g,b=A.color("panelDeep")
pill.markText:SetTextColor(r,g,b,1)
pill.markText:SetPoint("CENTER",pill.mark,"CENTER",0,0)
frame.pills[i]=pill
return pill
end
local function chipAt(frame,pill,j)
local chip=pill.chips[j]
if chip then
return chip
end
chip={edges=fourEdges(frame,"BORDER"),label=text(frame,"announceTag","chipText")}
pill.chips[j]=chip
return chip
end
local function hideChip(chip)
hideAll(chip.edges)
chip.label:Hide()
end
local function hidePill(pill)
pill.ground:Hide()
hideAll(pill.edges)
pill.bar:Hide()
pill.name:Hide()
pill.record:Hide()
pill.mark:Hide()
pill.markText:Hide()
for j=1,#pill.chips do
hideChip(pill.chips[j])
end
end
local function pillName(name)
local bare=A.nameParts(name,name)
return bare
end
local function paint(frame,composed,shape)
local cap=A.metric("announceStripWidth")
local edgeWidth=A.metric("announcePillEdge")
local padLeft,padRight=A.metric("announcePillPadLeft"),A.metric("announcePillPadRight")
local padY,lineHeight=A.metric("announcePillPadY"),A.metric("announcePillLine")
local partGap,rowGap=A.metric("announcePillPartGap"),A.metric("announcePillRowGap")
local markSide=A.metric("announceNoteMark")
local tagHeight,tagPad,tagGap=A.metric("announceTagHeight"),A.metric("announceTagPad"),
A.metric("announceTagGap")
local pillGap,labelGap=A.metric("announcePillGap"),A.metric("announceLabelGap")
local stripGap,sideGap=A.metric("announceStripLineGap"),A.metric("announceSideGap")
local ruleWidth,ruleHeight=A.metric("announceSideRule"),A.metric("announceSideRuleHeight")
local oneLine=padY*2+lineHeight
local origin=frame.plate
local names=composed.names
local sized,indexOf={},{}
for i=1,#names do
local it=names[i]
indexOf[it]=i
local pill=pillAt(frame,i)
local shown=pillName(it.name)
pill.name:SetText(shown)
pill.name:SetTextColor(A.classColor(it.classToken))
pill.record:SetText(it.record)
local chipWidths,tagsWidth={},0
for j=1,#it.tags do
local chip=chipAt(frame,pill,j)
local word=tostring(it.tags[j])
chip.label:SetText(word)
chipWidths[j]=A.textRoom(chip.label,word)+tagPad*2
tagsWidth=tagsWidth+chipWidths[j]+(j>1 and tagGap or 0)
end
local nameWidth=A.textRoom(pill.name,shown)
local recordWidth=A.textRoom(pill.record,it.record)
local top=padLeft+nameWidth+partGap+recordWidth+(it.noted and(partGap+markSide)or 0)
+padRight
local width=top
if#it.tags>0 then
width=math.max(top,padLeft+tagsWidth+padRight)
end
sized[i]={
it=it,
pill=pill,
nameWidth=nameWidth,
recordWidth=recordWidth,
chipWidths=chipWidths,
width=width,
height=oneLine+(#it.tags>0 and(rowGap+tagHeight)or 0),
}
end
for i=#names+1,#frame.pills do
hidePill(frame.pills[i])
end
local groups,bySide={},{}
for r=1,#(composed.runs or{})do
local run=composed.runs[r]
local items={}
for k=1,#run.names do
items[k]=sized[indexOf[run.names[k]]]
end
local group={side=run.side,label=run.label,items=items}
groups[#groups+1]=group
if run.side~=nil then
bySide[run.side]=group
end
end
local function labelWidth(group)
if group.label==nil then
return 0
end
return A.textRoom(frame.labels[group.side],group.label)
end
local function oneLineWidth(group)
local width=labelWidth(group)+labelGap
for k=1,#group.items do
width=width+group.items[k].width+(k>1 and pillGap or 0)
end
return width
end
local against,with=bySide.against,bySide.with
local shared=nil
if against~=nil and with~=nil then
shared=shape=="split"
and oneLineWidth(against)+sideGap*2+ruleWidth+oneLineWidth(with)<=cap
end
local cut,marks,nameCut=0,0,0
local pills={against=0,with=0,unsided=0}
local lineCounts={against=0,with=0,unsided=0}
local lines={}
local function newLine()
local last=lines[#lines]
local top=last and(last.top+last.height+stripGap)or 0
local line={top=top,height=0,right=0}
lines[#lines+1]=line
return line
end
local function placeLabel(group,x,line)
local label=frame.labels[group.side]
label:ClearAllPoints()
label:SetPoint("LEFT",origin,"TOPLEFT",x,-(line.top+padY+lineHeight/2))
label:Show()
end
local function placePill(item,x,line,room)
local pill,it=item.pill,item.it
local width=math.min(item.width,room)
local top=line.top
pill.ground:ClearAllPoints()
pill.ground:SetPoint("TOPLEFT",origin,"TOPLEFT",x,-top)
pill.ground:SetSize(width,item.height)
pill.ground:Show()
box(pill.edges,origin,x,top,width,item.height)
pill.bar:ClearAllPoints()
pill.bar:SetPoint("TOPLEFT",origin,"TOPLEFT",x,-top)
pill.bar:SetSize(edgeWidth,item.height)
pill.bar:SetColorTexture(A.color(it.mark))
pill.bar:Show()
local after=partGap+item.recordWidth+(it.noted and(partGap+markSide)or 0)
local nameRoom=math.max(width-padLeft-padRight-after,1)
local nameWidth=math.min(item.nameWidth,nameRoom)
if nameWidth<item.nameWidth then
nameCut=nameCut+1
end
local middle=-(top+padY+lineHeight/2)
pill.name:ClearAllPoints()
pill.name:SetPoint("LEFT",origin,"TOPLEFT",x+padLeft,middle)
pill.name:SetWidth(nameWidth)
pill.name:Show()
local at=x+padLeft+nameWidth+partGap
pill.record:ClearAllPoints()
pill.record:SetPoint("LEFT",origin,"TOPLEFT",at,middle)
pill.record:Show()
if it.noted then
at=at+item.recordWidth+partGap
pill.mark:ClearAllPoints()
pill.mark:SetPoint("TOPLEFT",origin,"TOPLEFT",at,-(top+padY+(lineHeight-markSide)/2))
pill.mark:SetSize(markSide,markSide)
pill.mark:Show()
pill.markText:Show()
marks=marks+1
else
pill.mark:Hide()
pill.markText:Hide()
end
local tagTop=top+oneLine-padY+rowGap
local tagRoom=width-padLeft-padRight
local cx,wasCut=0,false
for j=1,#pill.chips do
local chip=pill.chips[j]
local chipWidth=item.chipWidths[j]
if chipWidth==nil or wasCut then
hideChip(chip)
else
if cx+chipWidth>tagRoom then
wasCut=true
chipWidth=tagRoom-cx
end
if chipWidth<tagPad*2+1 then
hideChip(chip)
else
local chipX=x+padLeft+cx
box(chip.edges,origin,chipX,tagTop,chipWidth,tagHeight)
colourEdges(chip.edges,TAG_EDGE[1],TAG_EDGE[2],TAG_EDGE[3],TAG_EDGE[4])
chip.label:ClearAllPoints()
chip.label:SetPoint("LEFT",origin,"TOPLEFT",chipX+tagPad,-(tagTop+tagHeight/2))
chip.label:SetWidth(wasCut and(chipWidth-tagPad*2)or 0)
chip.label:Show()
cx=cx+chipWidth+tagGap
end
end
end
if wasCut then
cut=cut+1
end
local side=it.side or"unsided"
pills[side]=pills[side]+1
line.height=math.max(line.height,item.height)
line.right=math.max(line.right,x+width)
return width
end
frame.labels.against:Hide()
frame.labels.with:Hide()
frame.divider:Hide()
local flowing=groups
if shared then
local line=newLine()
local x=0
for _,group in ipairs({against,with})do
if group==with then
x=x+sideGap
frame.divider:ClearAllPoints()
frame.divider:SetPoint("TOPLEFT",origin,"TOPLEFT",x,-(line.top+(oneLine-ruleHeight)/2))
frame.divider:SetSize(ruleWidth,ruleHeight)
frame.divider:Show()
x=x+ruleWidth+sideGap
end
placeLabel(group,x,line)
x=x+labelWidth(group)+labelGap
for k=1,#group.items do
if k>1 then
x=x+pillGap
end
x=x+placePill(group.items[k],x,line,cap)
end
lineCounts[group.side]=1
end
flowing={}
for g=1,#groups do
if groups[g].side==nil then
flowing[#flowing+1]=groups[g]
end
end
end
local indent=0
if not shared then
for g=1,#groups do
if groups[g].label~=nil then
indent=math.max(indent,labelWidth(groups[g])+labelGap)
end
end
end
local room=math.max(cap-indent,1)
for g=1,#flowing do
local group=flowing[g]
local key=group.side or"unsided"
local line=newLine()
lineCounts[key]=lineCounts[key]+1
if group.label~=nil then
placeLabel(group,indent-labelGap-labelWidth(group),line)
end
local x,first=indent,true
for k=1,#group.items do
local item=group.items[k]
local width=math.min(item.width,room)
if not first and x+pillGap+width>cap then
line=newLine()
lineCounts[key]=lineCounts[key]+1
x,first=indent,true
end
if not first then
x=x+pillGap
end
x=x+placePill(item,x,line,room)
first=false
end
end
local width,tall=0,0
for i=1,#lines do
width=math.max(width,lines[i].right)
tall=lines[i].top+lines[i].height
end
local drawnSides={}
for g=1,#groups do
drawnSides[g]=groups[g].side or"unsided"
end
origin:SetSize(width,tall)
origin:Hide()
hideAll(frame.edges)
return{
width=width,
tall=tall,
sides=table.concat(drawnSides,","),
tagCut=cut,
nameCut=nameCut,
noteMarks=marks,
pillsAgainst=pills.against,
pillsWith=pills.with,
pillsUnsided=pills.unsided,
linesAgainst=lineCounts.against,
linesWith=lineCounts.with,
linesUnsided=lineCounts.unsided,
shared=shared,
}
end
local function fitTo(width,tall)
local chosen=A.announceSize()
local room=screenRoom()
local below=screenBelow()
local fitted=math.min(A.announceFit(width,room,chosen),A.announceFit(tall,below,chosen))
return chosen,room,below,fitted
end
local function fade(frame,total)
fadeStarted=(type(GetTime)=="function")and GetTime()or nil
dragFrom=nil
if fadeStarted==nil then
frame:SetAlpha(1)
frame:Show()
return
end
frame:SetAlpha(0)
frame:Show()
frame:SetScript("OnUpdate",function(self)
if dragFrom~=nil or fadeStarted==nil then
return
end
local at=GetTime()-fadeStarted
if at>=total then
self:SetScript("OnUpdate",nil)
fadeStarted=nil
self:SetAlpha(0)
self:Hide()
return
end
if at<RISE_SECONDS then
self:SetAlpha(at/RISE_SECONDS)
elseif at<total-FALL_SECONDS then
self:SetAlpha(1)
else
self:SetAlpha((total-at)/FALL_SECONDS)
end
end)
end
function A.announceShow(composed,held)
if type(composed)~="table"or type(composed.names)~="table"or#composed.names==0 then
return false
end
local frame=build()
if not frame then
return false
end
local tookPlate=plateUp
plateUp=false
if not held then
release(frame)
end
local shape=A.announceShape()
local drew=paint(frame,composed,shape)
frame.word:Hide()
local chosen,room,below,fitted=fitTo(drew.width,drew.tall)
applyScale(frame,fitted)
local opacity=A.announceOpacity()
applyOpacity(frame,opacity)
local seconds=A.announceSeconds(composed)
local unlocked=nil
if held then
hold(frame)
else
unlocked=not A.announceLocked()
if unlocked then
frame:SetMovable(true)
frame:EnableMouse(true)
end
fade(frame,seconds)
end
if tookPlate then
A.trace("view",{source="plate",state="hidden",reason=held and"preview"or"banner"},"ui")
end
return true,{
seconds=seconds,
timedLines=timedLines(composed),
scale=chosen,
fitted=fitted,
width=drew.width,
room=room,
tall=drew.tall,
below=below,
shape=shape,
sides=drew.sides,
shared=drew.shared,
tagLines=composed.tagLines or 0,
tagCut=drew.tagCut,
nameCut=drew.nameCut,
noteMarks=drew.noteMarks,
pillsAgainst=drew.pillsAgainst,
pillsWith=drew.pillsWith,
pillsUnsided=drew.pillsUnsided,
linesAgainst=drew.linesAgainst,
linesWith=drew.linesWith,
linesUnsided=drew.linesUnsided,
unlocked=unlocked,
opacity=opacity,
}
end
local NOTHING_DRAWN={}
function A.announceFrame()
return banner
end
function A.announceDrawnSize()
if drawnPercent==nil then
return nil
end
return drawnPercent
end
local SAMPLE_SIZE=8
local SAMPLE_FULL=15
local fullSample=false
local SAMPLE_CLASS={"PRIEST","DRUID","WARRIOR","MAGE","ROGUE","HUNTER","PALADIN","WARLOCK"}
local SAMPLE_RECORD={{0,2},{1,1},{1,1},{1,0},{2,0},{3,4},{0,0},{2,1}}
local SAMPLE_WITH={{2,1},{0,3},{2,2},{0,1},{1,1},{1,0},{0,0},{3,0}}
local SAMPLE_TAGS={
[1]={"healer","duo"},
[2]={"focus"},
[3]={"flag carrier","peels","swaps early","calls targets","duo"},
[4]={"healer","calls targets"},
}
local SAMPLE_NOTED={[1]=true,[2]=true,[5]=true,[6]=true}
function A.announceSample(count)
local total=type(count)=="number"and count or SAMPLE_SIZE
if type(A.fixtureNames)~="function"then
return nil
end
local names=A.fixtureNames(total)
if type(names)~="table"or#names<total then
return nil
end
local rating={-2,-1,0,1,2}
local found={}
for i=1,total do
local record=SAMPLE_RECORD[((i-1)%#SAMPLE_RECORD)+1]
local with=SAMPLE_WITH[((i-1)%#SAMPLE_WITH)+1]
found[i]={
met=record[1]+record[2]+with[1]+with[2]+1,
name=names[i],
classToken=SAMPLE_CLASS[((i-1)%#SAMPLE_CLASS)+1],
faction=(i%2==0)and 1 or 0,
rating=rating[i],
mark=A.ratingMark(rating[i]),
text=SAMPLE_NOTED[i]and"a note the banner does not draw"or nil,
tags=SAMPLE_TAGS[i],
held={
against={wins=record[1],decided=record[1]+record[2]},
with={wins=with[1],decided=with[1]+with[2]},
},
}
end
return compose(found,1)
end
function A.announcePreviewActive()
return previewUp
end
function A.announcePreview()
local composed=A.announceSample(fullSample and SAMPLE_FULL or SAMPLE_SIZE)
if composed==nil then
A.trace("announce",{source="preview",reason="no-sample"})
return false
end
local drawn,drawing=A.announceShow(composed,true)
local did=drawing or NOTHING_DRAWN
A.trace("announce",{
source="preview",
reason=drawn and"previewed"or"no-frame",
shown=#composed.names,
seconds=A.unitFigure(did.seconds),
timedLines=did.timedLines,
scale=did.scale,
fitted=did.fitted,
width=A.unitFigure(did.width),
tall=A.unitFigure(did.tall),
shape=did.shape,
sides=did.sides,
shared=did.shared,
pillsAgainst=did.pillsAgainst,
pillsWith=did.pillsWith,
pillsUnsided=did.pillsUnsided,
linesAgainst=did.linesAgainst,
linesWith=did.linesWith,
linesUnsided=did.linesUnsided,
tagLines=did.tagLines,
tagCut=did.tagCut,
nameCut=did.nameCut,
noteMarks=did.noteMarks,
readAgainst=composed.readAgainst,
readWith=composed.readWith,
readSummed=composed.readSummed,
})
return drawn,drawing
end
function A.announcePreviewFull(on)
fullSample=on==true
return fullSample
end
function A.announcePreviewFullHeld()
return fullSample
end
function A.announcePreviewEnd()
if not previewUp or not banner then
return false
end
pcall(banner.Hide,banner)
return true
end
function A.announcePreviewToggle()
if previewUp and banner then
A.announcePreviewEnd()
return"ended"
end
if A.announcePreview()then
return"shown"
end
return false
end
function A.announcePlateActive()
return plateUp
end
local function drawPlate()
local frame=build()
if not frame then
return false,"no-frame"
end
local composed=A.announceSample(SAMPLE_SIZE)
if composed==nil then
return false,"no-sample"
end
local drew=paint(frame,composed,A.announceShape())
for i=1,#frame.pills do
hidePill(frame.pills[i])
end
frame.labels.against:Hide()
frame.labels.with:Hide()
frame.divider:Hide()
frame.plate:Show()
for i=1,#frame.edges do
frame.edges[i]:Show()
end
local _,_,_,fitted=fitTo(drew.width,drew.tall)
applyScale(frame,fitted)
applyOpacity(frame,A.announceOpacity())
frame.word:SetText(PLATE_WORD)
frame.word:Show()
frame:SetScript("OnUpdate",nil)
fadeStarted=nil
dragFrom=nil
plateUp=true
frame:SetMovable(true)
frame:EnableMouse(true)
frame:SetAlpha(1)
frame:Show()
return true
end
function A.announcePlateRefresh(cause)
local blocked
if type(A.optionsWindowShown)~="function"or not A.optionsWindowShown()then
blocked="window"
elseif A.announceLocked()then
blocked="locked"
elseif previewUp then
blocked="preview"
elseif banner and not plateUp then
local ok,shown=pcall(banner.IsShown,banner)
if ok and shown then
blocked="banner"
end
end
if blocked then
if plateUp and banner then
pcall(banner.Hide,banner)
A.trace("view",{source="plate",state="hidden",reason=cause,kind=blocked},"ui")
return false
end
A.trace("view",{source="plate",state="absent",reason=cause,kind=blocked},"ui")
return false
end
if plateUp then
A.trace("view",{source="plate",state="kept",reason=cause},"ui")
return true
end
local drawn,why=drawPlate()
A.trace("view",{source="plate",state=drawn and"shown"or"failed",reason=cause,kind=why},
"ui")
return drawn
end
function A.resetAnnouncePosition()
local stored=A.setAnnouncePosition(nil)
if banner then
pcall(banner.Hide,banner)
placeAt(banner,drawnScale)
end
reconsider("reset")
return stored
end
local function readRows()
if type(GetNumBattlefieldScores)~="function"
or type(C_PvP)~="table"or type(C_PvP.GetScoreInfo)~="function"
then
return{}
end
local ok,count=pcall(GetNumBattlefieldScores)
if not ok or not A.canRead(count)or type(count)~="number"or count<1 then
return{}
end
local rows={}
for i=1,count do
local gotRow,row=pcall(C_PvP.GetScoreInfo,i)
if gotRow and type(row)=="table"then
local gotName,name=pcall(A.index,row,"name")
if gotName and A.canRead(name)then
local out={name=name}
local gotClass,class=pcall(A.index,row,"classToken")
if gotClass and A.canRead(class)then
out.classToken=class
end
local gotFaction,faction=pcall(A.index,row,"faction")
if gotFaction and A.canRead(faction)then
out.faction=faction
end
rows[#rows+1]=out
end
end
end
return rows
end
local function ownNames()
if type(UnitName)~="function"then
return nil,nil
end
local ok,own,realm=pcall(UnitName,"player")
if not(ok and type(own)=="string"and A.canRead(own)and own~="")then
return nil,nil
end
if type(realm)=="string"and A.canRead(realm)and realm~=""then
return own,own.."-"..realm
end
return own,nil
end
local function settled(fill)
if#fill<SETTLE_READS then
return false
end
for i=#fill-SETTLE_READS+2,#fill do
if fill[i]~=fill[i-1]then
return false
end
end
return true
end
local function attempt(ladder,n)
local record=ladder.record
if A.db()==nil or A.db().active~=record then
return
end
local rows=readRows()
if A.requestScores then
A.requestScores()
end
local canWait=C_Timer and C_Timer.After
if#rows==0 then
if n>=MAX_ATTEMPTS or not canWait then
A.trace("announce",{reason="no-rows",attempt=n})
return
end
C_Timer.After(RETRY_EVERY,function()contained(attempt,ladder,n+1)end)
return
end
local fill=ladder.fill
fill[#fill+1]=#rows
local state=A.stateName(A.matchState())
if state=="StartUp"and not settled(fill)and n<MAX_ATTEMPTS and canWait then
C_Timer.After(RETRY_EVERY,function()contained(attempt,ladder,n+1)end)
return
end
local fillText=table.concat(fill,",")
local own,qualified=ownNames()
local nameIndex,yielded=nil,nil
if ladder.banner or(type(A.alertsEnabled)=="function"and A.alertsEnabled())then
local built,made,gave=pcall(A.playerNameIndex)
nameIndex=built and type(made)=="table"and made or nil
yielded=nameIndex and type(gave)=="number"and gave or nil
end
if A.alertGatesGroup then
A.alertGatesGroup(rows,own,qualified,nameIndex)
end
if not ladder.banner then
return
end
local composed=A.announceKnown(rows,own,qualified,nameIndex)
if composed==nil then
A.trace("announce",{reason="nobody",n=#rows,attempt=n,state=state,
fill=fillText,yielded=yielded})
return
end
local drawn,drawing=A.announceShow(composed)
local did=drawing or NOTHING_DRAWN
A.trace("announce",{
reason=drawn and"announced"or"no-frame",
n=#rows,
found=composed.count,
noted=composed.noted,
shown=#composed.names,
yielded=yielded,
attempt=n,
state=state,
fill=fillText,
seconds=A.unitFigure(did.seconds),
scale=did.scale,
fitted=did.fitted,
width=A.unitFigure(did.width),
room=A.unitFigure(did.room),
tall=A.unitFigure(did.tall),
below=A.unitFigure(did.below),
shape=did.shape,
sides=did.sides,
timedLines=did.timedLines,
shared=did.shared,
pillsAgainst=did.pillsAgainst,
pillsWith=did.pillsWith,
pillsUnsided=did.pillsUnsided,
linesAgainst=did.linesAgainst,
linesWith=did.linesWith,
linesUnsided=did.linesUnsided,
tagLines=did.tagLines,
tagCut=did.tagCut,
nameCut=did.nameCut,
noteMarks=did.noteMarks,
readAgainst=composed.readAgainst,
readWith=composed.readWith,
readSummed=composed.readSummed,
unlocked=did.unlocked,
opacity=did.opacity,
})
end
local START_STATES={StartUp=true,Engaged=true}
function A.announceRoster(record,state)
if type(record)~="table"or not START_STATES[state]then
return false
end
if firedFor==record then
return false
end
local bannerOn=A.announceEnabled()
if not bannerOn then
A.trace("announce",{reason="switch"})
if not A.alertsEnabled()then
firedFor=record
return false
end
end
local noted=A.notedCount()
local db=A.db()
local indexed=db and type(db.players)=="table"and next(db.players)~=nil
if(type(noted)~="number"or noted<1)and not indexed then
A.trace("announce",{reason="nothing-known",noted=0})
firedFor=record
return false
end
firedFor=record
local ladder={record=record,banner=bannerOn,fill={}}
if not(C_Timer and C_Timer.After)then
contained(attempt,ladder,MAX_ATTEMPTS)
return true
end
C_Timer.After(FIRST_READ,function()contained(attempt,ladder,1)end)
return true
end
local groupSeen={}
local function groupDecision(guids,selfGuid)
local composed,qualified=A.announceGroup(guids,selfGuid)
local now,arrived={},false
for i=1,#qualified do
now[qualified[i]]=true
if not groupSeen[qualified[i]]then
arrived=true
end
end
groupSeen=now
if composed==nil then
A.trace("announce",{source="group",reason="nobody",n=#guids})
return false
end
if not arrived then
A.trace("announce",{source="group",reason="seen",n=#guids,found=composed.count})
return false
end
local drawn,drawing=A.announceShow(composed)
local did=drawing or NOTHING_DRAWN
A.trace("announce",{
source="group",
reason=drawn and"announced"or"no-frame",
n=#guids,
found=composed.count,
noted=composed.noted,
shown=#composed.names,
seconds=A.unitFigure(did.seconds),
scale=did.scale,
fitted=did.fitted,
width=A.unitFigure(did.width),
room=A.unitFigure(did.room),
tall=A.unitFigure(did.tall),
below=A.unitFigure(did.below),
shape=did.shape,
sides=did.sides,
timedLines=did.timedLines,
shared=did.shared,
pillsAgainst=did.pillsAgainst,
pillsWith=did.pillsWith,
pillsUnsided=did.pillsUnsided,
linesAgainst=did.linesAgainst,
linesWith=did.linesWith,
linesUnsided=did.linesUnsided,
tagLines=did.tagLines,
tagCut=did.tagCut,
nameCut=did.nameCut,
noteMarks=did.noteMarks,
readAgainst=composed.readAgainst,
readWith=composed.readWith,
readSummed=composed.readSummed,
unlocked=did.unlocked,
opacity=did.opacity,
})
return drawn
end
function A.announceGroupRoster(guids,selfGuid)
if type(guids)~="table"or not A.announceEnabled()then
return false
end
local drawn=false
contained(function()
drawn=groupDecision(guids,selfGuid)
end)
return drawn
end
function A.recordRows(record)
local rows={}
local participants=type(record)=="table"and record.participants or nil
if type(participants)~="table"then
return rows,nil
end
for _,p in pairs(participants)do
if type(p)=="table"and type(p.name)=="string"and p.name~=""then
rows[#rows+1]={name=p.name,classToken=p.classToken,faction=p.faction}
end
end
table.sort(rows,function(a,b)return a.name<b.name end)
local own=record.character and participants[record.character]
return rows,type(own)=="table"and own.name or nil
end
function A.announceFromRecord(record)
local rows,own=A.recordRows(record)
local composed=A.announceKnown(rows,own,nil)
local switch=A.announceEnabled()and"on"or"off"
if composed==nil then
A.trace("announce",{source="sample",reason="nobody",id=record.id,n=#rows,switch=switch})
return false
end
local drawn,drawing=A.announceShow(composed)
local did=drawing or NOTHING_DRAWN
A.trace("announce",{
source="sample",
reason=drawn and"announced"or"no-frame",
id=record.id,
n=#rows,
found=composed.count,
noted=composed.noted,
shown=#composed.names,
seconds=A.unitFigure(did.seconds),
width=A.unitFigure(did.width),
tall=A.unitFigure(did.tall),
shape=did.shape,
sides=did.sides,
timedLines=did.timedLines,
shared=did.shared,
pillsAgainst=did.pillsAgainst,
pillsWith=did.pillsWith,
pillsUnsided=did.pillsUnsided,
linesAgainst=did.linesAgainst,
linesWith=did.linesWith,
linesUnsided=did.linesUnsided,
tagLines=did.tagLines,
tagCut=did.tagCut,
nameCut=did.nameCut,
noteMarks=did.noteMarks,
switch=switch,
})
return drawn
end
function A.announceGroupLeft()
groupSeen={}
end
