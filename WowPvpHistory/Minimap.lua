-- WowPvpHistory 0.68.47
-- Author:  Xenu-Sentinels
-- Project: wow-pvp-history
--          https://github.com/xenulive/wow-pvp-history
-- License: MIT, see LICENSE
local _,A=...
local BUTTON_NAME="WowPvpHistoryMinimapButton"
local DEFAULT_ANGLE=205
local RADIUS_PADDING=5
local FALLBACK_MINIMAP_SIZE=140
local button
local function uiState()
local db=A.db()
if not db then
return nil
end
db.ui=db.ui or{}
return db.ui
end
local function storedAngle()
local ui=uiState()
local angle=ui and tonumber(ui.minimapAngle)
if not angle then
return DEFAULT_ANGLE
end
return angle%360
end
local function storedFree()
local ui=uiState()
local held=ui and ui.minimapFree
if type(held)~="table"then
return nil
end
local x,y=tonumber(held.x),tonumber(held.y)
if not(x and y)then
return nil
end
return x,y
end
local function storedShown()
local ui=uiState()
if not ui then
return true
end
return ui.minimapShown~=false
end
local function place()
if not(button and Minimap)then
return false
end
return(pcall(function()
local x,y=storedFree()
if x and UIParent then
button:ClearAllPoints()
button:SetPoint("CENTER",UIParent,"BOTTOMLEFT",x,y)
return
end
local width=Minimap:GetWidth()or FALLBACK_MINIMAP_SIZE
local height=Minimap:GetHeight()or FALLBACK_MINIMAP_SIZE
local radius=(math.min(width,height)*0.5)+RADIUS_PADDING
local radians=math.rad(storedAngle())
button:ClearAllPoints()
button:SetPoint("CENTER",Minimap,"CENTER",
math.cos(radians)*radius,math.sin(radians)*radius)
end))
end
local function dragged()
if not(button and Minimap and GetCursorPosition)then
return
end
pcall(function()
local scale=Minimap:GetEffectiveScale()or 1
if scale==0 then
return
end
local cursorX,cursorY=GetCursorPosition()
local centerX,centerY=Minimap:GetCenter()
if not(cursorX and cursorY and centerX and centerY)then
return
end
local ui=uiState()
if not ui then
return
end
ui.minimapFree=nil
ui.minimapAngle=math.deg(math.atan2((cursorY/scale)-centerY,
(cursorX/scale)-centerX))%360
place()
end)
end
local function draggedFree()
if not(button and Minimap and GetCursorPosition)then
return
end
pcall(function()
local scale=Minimap:GetEffectiveScale()or 1
if scale==0 then
return
end
local cursorX,cursorY=GetCursorPosition()
if not(cursorX and cursorY)then
return
end
local ui=uiState()
if not ui then
return
end
ui.minimapFree={x=cursorX/scale,y=cursorY/scale}
place()
end)
end
local function shiftHeld()
if type(IsShiftKeyDown)~="function"then
return false
end
local ok,held=pcall(IsShiftKeyDown)
return ok and held==true
end
local function traceDrag(free)
if free then
local x,y=storedFree()
A.trace("minimap/drag",{state="free",x=A.unitFigure(x),y=A.unitFigure(y)},"ui")
return
end
A.trace("minimap/drag",{state="circle",angle=A.unitFigure(storedAngle())},"ui")
end
local MENU_ENTRIES={
{kind="title",text=A.displayName()},
{kind="button",text="Match history",run=function()A.toggleWindow()end},
{kind="button",text="Players",count="players",run=function()A.toggleNotes()end},
{kind="button",text="Stats",run=function()A.showWindowState({body="stats",view="ask"})end},
{kind="divider"},
{kind="button",text="Settings",run=function()A.toggleSettings()end},
{kind="divider"},
{kind="button",text="Reset button position",run=function()A.resetMinimap()end},
{
kind="button",
text="Hide this button",
run=function()
A.setMinimapShown(false)
A.say("minimap button hidden. /pvph minimap shows it again")
end,
},
}
local function clickable()
local n=0
for i=1,#MENU_ENTRIES do
if MENU_ENTRIES[i].kind=="button"then
n=n+1
end
end
return n
end
local function playersMet()
local ok,view=pcall(A.playersView,{})
if not ok or type(view)~="table"or type(view.strip)~="table"then
return nil
end
local count=view.strip.players
if type(count)~="number"then
return nil
end
return count
end
local function rightFigure(text)
return function(row)
pcall(function()
local right=row:AttachFontString()
right:SetPoint("RIGHT",row,"RIGHT",0,0)
right:SetJustifyH("RIGHT")
right:SetText(text)
local r,g,b=A.color("dimmer")
right:SetTextColor(r,g,b)
end)
end
end
local function menuOwner(region)
if not region then
return nil
end
local ok,visible=pcall(region.IsVisible,region)
if not ok or not visible then
return nil
end
return region
end
local function buildRows(root)
local built,players={},nil
local canDivide=type(root.CreateDivider)=="function"
for i=1,#MENU_ENTRIES do
local entry=MENU_ENTRIES[i]
if entry.kind=="title"then
root:CreateTitle(entry.text)
built[#built+1]=entry.text
elseif entry.kind=="divider"then
if canDivide then
root:CreateDivider()
built[#built+1]="-"
end
else
local description=root:CreateButton(entry.text,entry.run)
built[#built+1]=entry.text
if entry.count=="players"and type(description)=="table"
and type(description.AddInitializer)=="function"then
local count=playersMet()
if count~=nil then
description:AddInitializer(rightFigure(A.groupedCount(count)))
players=count
end
end
end
end
return built,players
end
local function openMenu(owner)
if type(MenuUtil)~="table"or type(MenuUtil.CreateContextMenu)~="function"then
return false,"no-menuutil"
end
local built,players
local ok,menu=pcall(MenuUtil.CreateContextMenu,menuOwner(owner),function(_,root)
built,players=buildRows(root)
end)
if ok and menu~=nil then
return true,nil,built,players
end
return false,"no-menu",built,players
end
local function escapeOf(r,g,b)
return("|cff%02x%02x%02x"):format(math.floor(r*255+0.5),math.floor(g*255+0.5),
math.floor(b*255+0.5))
end
local function headlineOf(record)
local ok,lines,_,_,heads=pcall(A.detailLines,record)
if not ok or type(lines)~="table"or type(heads)~="table"then
return nil
end
for i=1,#lines do
local head=heads[i]
if type(head)=="table"and head.kind=="headline"then
return head
end
end
return nil
end
local function showTooltip(owner)
GameTooltip:SetOwner(owner,"ANCHOR_LEFT")
if type(GameTooltip.ClearLines)=="function"then
GameTooltip:ClearLines()
end
local ar,ag,ab=A.color("accent")
local dr,dg,db=A.color("dim")
local mr,mg,mb=A.color("dimmer")
local tr,tg,tb=A.color("text")
local hint="Click: match history "..A.HEAD_DOT.." Right click: menu"
local character=A.barCharacter()
local newest=character~=nil and A.lastMatch(nil,nil,A.barRecorder(character),nil,true)or nil
if newest==nil or newest.format==nil then
GameTooltip:AddLine(A.displayName(),ar,ag,ab)
GameTooltip:AddLine(hint,mr,mg,mb)
GameTooltip:Show()
A.trace("minimap/tooltip",{state="empty"},"ui")
return
end
local drawn=0
local function line(text,r,g,b)
GameTooltip:AddLine(text,r,g,b)
drawn=drawn+1
end
local function double(left,right,lr,lg,lb,rr,rg,rb)
GameTooltip:AddDoubleLine(left,right,lr,lg,lb,rr,rg,rb)
drawn=drawn+1
end
local format=newest.format
local formatText=A.formatLabel(format)
double(A.displayName(),formatText,ar,ag,ab,dr,dg,db)
local figures=A.todayFigures(format,character)or{}
local drawnRating,drawnChange
if figures.rating~=nil or figures.change~=nil then
local parts={}
if figures.rating~=nil then
local rr,rg,rb=A.ratingTint(format,figures.rating)
parts[#parts+1]=escapeOf(rr,rg,rb)..tostring(figures.rating).."|r"
drawnRating=figures.rating
end
if figures.change~=nil then
parts[#parts+1]=A.colorEscape(figures.changeTone or"dim")..figures.change.." today|r"
drawnChange=figures.change
end
double("Rating",table.concat(parts," "),dr,dg,db,tr,tg,tb)
end
if figures.record~=nil then
local rr,rg,rb=A.color(figures.recordTone or"dim")
double("Today",figures.record,dr,dg,db,rr,rg,rb)
end
line(" ")
local clock=A.clockKey(newest.openedAt or newest.completedAt)
if clock~=nil then
double("Last match",clock,dr,dg,db,dr,dg,db)
else
line("Last match",dr,dg,db)
end
local drawnFaction
local head=headlineOf(newest)
if head~=nil then
local result=head.result
if result~=nil and head.mark~=nil then
result=result.." "..A.colorEscape("dim")..head.mark.."|r"
end
local er,eg,eb=A.color(head.resultTone or"text")
local cr,cg,cb=A.color(head.deltaTone or"text")
if result~=nil and head.delta~=nil then
double(result,head.delta,er,eg,eb,cr,cg,cb)
elseif result~=nil then
line(result,er,eg,eb)
elseif head.delta~=nil then
line(head.delta,cr,cg,cb)
end
local side=A.factionWord(head.faction)
if side~=nil then
local sr,sg,sb=A.color(A.factionTone(head.faction))
if head.place~=nil then
double(side,head.place,sr,sg,sb,tr,tg,tb)
else
line(side,sr,sg,sb)
end
drawnFaction=head.faction
elseif head.place~=nil then
line(head.place,tr,tg,tb)
end
end
line(" ")
line(hint,mr,mg,mb)
GameTooltip:Show()
A.trace("minimap/tooltip",{
format=format,
ratingFigure=drawnRating,
today=drawnChange,
record=figures.record,
id=newest.id,
faction=drawnFaction,
lines=drawn,
},"ui")
end
local function buildButton()
local made=CreateFrame("Button",BUTTON_NAME,Minimap)
made:SetSize(31,31)
made:SetFrameStrata("MEDIUM")
made:SetFrameLevel((Minimap:GetFrameLevel()or 1)+8)
made:RegisterForClicks("LeftButtonUp","RightButtonUp")
made:RegisterForDrag("LeftButton")
made:SetClampedToScreen(true)
local background=made:CreateTexture(nil,"BACKGROUND")
background:SetSize(20,20)
background:SetPoint("CENTER")
background:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
background:SetVertexColor(0,0,0,0.6)
local icon=made:CreateTexture(nil,"ARTWORK")
icon:SetSize(19,19)
icon:SetPoint("CENTER")
icon:SetTexture(A.ICON_TEXTURE)
local border=made:CreateTexture(nil,"OVERLAY")
border:SetSize(52,52)
border:SetPoint("TOPLEFT")
border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
made:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
made:SetScript("OnClick",function(self,mouseButton)
if mouseButton=="RightButton"then
local opened,refused,built,players=openMenu(self)
A.trace("minimap/menu",{state=opened and"opened"or"fallback",reason=refused,
n=clickable(),entries=built and table.concat(built,"+")or nil,
players=players},"ui")
if opened then
return
end
local where,why=A.openSettings()
if not where then
if why=="combat"then
A.say("no menu, and the client's settings panel cannot be opened in combat. "
.."/pvph opens the window and /pvph minimap sets this button")
else
A.say("no menu and no settings surface on this client. /pvph opens the window "
.."and /pvph minimap sets this button")
end
end
return
end
A.toggleWindow()
end)
made:SetScript("OnDragStart",function(self)
self.dragging=true
self.dragFree=shiftHeld()or nil
self:SetScript("OnUpdate",self.dragFree and draggedFree or dragged)
end)
made:SetScript("OnDragStop",function(self)
local free=self.dragFree
self.dragging=nil
self.dragFree=nil
self:SetScript("OnUpdate",nil)
traceDrag(free)
end)
made:SetScript("OnHide",function(self)
self.dragging=nil
self.dragFree=nil
self:SetScript("OnUpdate",nil)
end)
made:SetScript("OnEnter",function(self)
if not GameTooltip then
return
end
local ok,err=pcall(showTooltip,self)
if not ok then
A.noteError(err,"minimap-tooltip")
end
end)
made:SetScript("OnLeave",function(self)
A.hideOwnedTooltip(self)
end)
return made
end
local function buttonOrNil()
if button then
return button
end
if not Minimap then
return nil
end
local ok,made=pcall(buildButton)
if not ok or not made then
button=nil
return nil
end
button=made
place()
return button
end
local function notifySetting()
if A.notifyMinimapSetting then
A.notifyMinimapSetting()
end
end
function A.setMinimapShown(shown)
local ui=uiState()
if ui then
if shown then
ui.minimapShown=nil
else
ui.minimapShown=false
end
end
notifySetting()
if not shown then
if button then
pcall(button.Hide,button)
end
return true
end
if not buttonOrNil()then
return false
end
place()
return(pcall(button.Show,button))
end
function A.minimapShown()
return storedShown()
end
function A.resetMinimap()
local ui=uiState()
if ui then
ui.minimapAngle=nil
ui.minimapFree=nil
ui.minimapShown=nil
end
notifySetting()
if not buttonOrNil()then
return false
end
place()
return(pcall(button.Show,button))
end
function A.applyMinimapState()
if not storedShown()then
if button then
return(pcall(button.Hide,button))
end
return true
end
if not buttonOrNil()then
return false
end
place()
return(pcall(button.Show,button))
end
function A.minimapAvailable()
return Minimap~=nil
end
function A.minimapState()
local x,y=storedFree()
return{
shown=storedShown(),
angle=storedAngle(),
free=x and{x=x,y=y}or nil,
built=button~=nil,
available=A.minimapAvailable(),
}
end
A.on("PLAYER_LOGIN",function()
local ok,placed=pcall(A.applyMinimapState)
if not ok then
A.noteError(placed,"minimap-login")
elseif not placed then
A.trace("minimap",{state="unbuilt",reason="login"},"ui")
end
end)
