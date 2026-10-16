-- WowPvpHistory 0.68.35
-- Author:  Xenu-Sentinels
-- Project: wow-pvp-history
--          https://github.com/xenulive/wow-pvp-history
-- License: MIT, see LICENSE
local _,A=...
local registered=false
function A.tooltipEnabled()
local db=A.db()
if not db then
return false
end
db.ui=db.ui or{}
return db.ui.tooltip~=false
end
function A.setTooltip(enabled)
local db=A.db()
if not db then
return false
end
db.ui=db.ui or{}
if enabled==false then
db.ui.tooltip=false
else
db.ui.tooltip=nil
end
if A.notifyTooltipSetting then
A.notifyTooltipSetting()
end
return true
end
function A.tooltipAvailable()
return registered
end
local function tooltipGuid(tooltip)
if type(tooltip)~="table"and type(tooltip)~="userdata"then
return nil
end
local ok,data=pcall(function()
return tooltip:GetPrimaryTooltipData()
end)
if not(ok and type(data)=="table")then
return nil
end
local guid=data.guid
if type(guid)~="string"or not A.canRead(guid)then
return nil
end
if guid==""then
return nil
end
return guid
end
function A.tooltipBlock(tooltip,guid)
if A.playerSummary(guid)==nil then
return 0,nil
end
local now=time()
local index=A.hoverEncounterIndex(now)
local items,facts=A.playerTooltipLines(guid,now,index)
if#items==0 or facts==nil then
return 0,nil
end
tooltip:AddLine(" ")
local hr,hg,hb=A.color("accent")
local rr,rg,rb=A.color(facts.rated and(facts.repMark or"dim")or"dimmer")
tooltip:AddDoubleLine(A.displayName(),facts.rated and facts.rep or"Not rated",hr,hg,hb,rr,rg,rb)
local drew={header=facts.rated and"rated"or"unrated",pairs=0,noteLine=false,
tagLine=false,lastSeen=false}
for i=1,#items do
local item=items[i]
if item.kind=="pair"then
local lr,lg,lb=A.color(item.leftColor)
local vr,vg,vb=A.color(item.rightColor)
tooltip:AddDoubleLine(item.left,item.right,lr,lg,lb,vr,vg,vb)
drew.pairs=drew.pairs+1
else
local r,g,b=A.color(item.color)
tooltip:AddLine(item.text,r,g,b,item.wrap==true)
end
if item.part=="note"then
drew.noteLine=true
elseif item.part=="tags"then
drew.tagLine=true
elseif item.part=="lastSeen"then
drew.lastSeen=true
end
end
return#items,drew
end
local function append(tooltip)
if not A.tooltipEnabled()then
return
end
local suppressed,reading=A.pvpRestricted()
if suppressed then
A.trace("tooltip",{reason="restriction",restriction=reading},"data")
return
end
local guid=tooltipGuid(tooltip)
if not guid then
return
end
if A.isOwnCharacter(guid)then
A.trace("tooltip",{reason="self"},"data")
return
end
local n,drew=A.tooltipBlock(tooltip,guid)
if n>0 and drew then
A.trace("tooltip",{reason="appended",n=n,header=drew.header,pairs=drew.pairs,
noteLine=drew.noteLine,tagLine=drew.tagLine,lastSeen=drew.lastSeen},"data")
return
end
if guid:find("^Player%-")then
A.trace("tooltip",{reason="none",n=0},"data")
end
end
local sample={frame=nil,up=false}
local function sampleFrame()
if sample.frame==nil and type(CreateFrame)=="function"then
local ok,frame=pcall(CreateFrame,"GameTooltip","WowPvpHistorySampleTooltip",UIParent,
"GameTooltipTemplate")
if ok and type(frame)=="table"and type(frame.SetOwner)=="function"then
sample.frame=frame
end
end
return sample.frame
end
function A.tooltipSampleShown()
return sample.up and sample.frame or nil
end
function A.tooltipSample(guid,name)
local tooltip=sampleFrame()
if tooltip==nil then
return nil
end
tooltip:SetOwner(UIParent,"ANCHOR_NONE")
if type(tooltip.ClearAllPoints)=="function"and type(tooltip.SetPoint)=="function"then
tooltip:ClearAllPoints()
tooltip:SetPoint("CENTER",UIParent,"CENTER",0,0)
end
tooltip:SetText(name,1,1,1,1,false)
local n,drew=A.tooltipBlock(tooltip,guid)
tooltip:Show()
sample.up=true
A.trace("tooltip",{source="sample",reason=n>0 and"appended"or"none",n=n,
switch=A.tooltipEnabled()and"on"or"off",header=drew and drew.header,
pairs=drew and drew.pairs,noteLine=drew and drew.noteLine,tagLine=drew and drew.tagLine,
lastSeen=drew and drew.lastSeen},"data")
return n
end
function A.tooltipSampleHide()
local was=sample.up
sample.up=false
if was and sample.frame~=nil then
sample.frame:Hide()
end
return was
end
local function register()
local processor=TooltipDataProcessor
if type(processor)~="table"or type(processor.AddTooltipPostCall)~="function"then
return false
end
local kind=Enum and Enum.TooltipDataType and Enum.TooltipDataType.Unit
if kind==nil then
return false
end
return(pcall(processor.AddTooltipPostCall,kind,function(tooltip)
pcall(append,tooltip)
end))
end
registered=register()==true
