-- WowPvpHistory 0.75.26
-- Author:  Xenu-Sentinels
-- Project: wow-pvp-history
--          https://github.com/xenulive/wow-pvp-history
-- License: MIT, see LICENSE
local _,A=...

local RECAP_CELLS_FLOOR=3

function A.recapCardHeight()
	return A.fontSize("label")+A.metric("roundCardLine")+A.outingCellsHeight()
end

function A.recapCardBand()
	return A.recapCardHeight()+A.metric("paneGap")
end

function A.recapBandDrawn(frame)
	return(type(frame)=="table"and frame.recapDrawn)and A.recapCardBand()or 0
end

function A.recapCellFloor(index)
	local label=A.sessionRecapLabels()[index]
	return label and(A.headerFloor(label)+A.metric("roundCardPad")*2)or 0
end

function A.recapCellsNeed(count)
	local need=A.metric("roundCardGap")*(count-1)
	for i=1,count do
		need=need+A.recapCellFloor(i)
	end
	return need
end

function A.recapCellsFit(width)
	local count=#A.sessionRecapLabels()
	while count>RECAP_CELLS_FLOOR and A.recapCellsNeed(count)>(tonumber(width)or 0)do
		count=count-1
	end
	return count
end

function A.recapIconSize(count,room)
	local size=A.metric("compSwatch")
	if type(count)~="number"or count<1 or type(room)~="number"then
		return size
	end
	local gap=A.metric("compChipInner")
	if count*size+gap*(count-1)>room then
		size=math.max(1,math.floor((room-gap*(count-1))/count))
	end
	return size
end

local function showCompTooltip(self)
	A.keyedTooltip(self,self.lines,"ANCHOR_TOP","recap")
end

local function hideCompTooltip(self)
	A.hideOwnedTooltip(self)
end

local function buildCard(frame)
	if frame.recapCard~=nil then
		return frame.recapCard
	end
	local card=CreateFrame("Frame",nil,frame)
	card:Hide()
	card.heading=card:CreateFontString(nil,"ARTWORK","GameFontHighlightSmall")
	card.span=card:CreateFontString(nil,"ARTWORK","GameFontHighlightSmall")
	card.measure=card:CreateFontString(nil,"ARTWORK","GameFontHighlightSmall")
	card.measure:Hide()
	card.cells={}
	for i=1,#A.sessionRecapLabels()do
		local cell={}
		cell.bg=card:CreateTexture(nil,"BACKGROUND")
		cell.edge=card:CreateTexture(nil,"BORDER")
		cell.title=card:CreateFontString(nil,"ARTWORK","GameFontHighlightSmall")
		cell.value=card:CreateFontString(nil,"ARTWORK","GameFontHighlightSmall")
		cell.value:SetWordWrap(false)
		cell.comp={}
		cell.hit=CreateFrame("Frame",nil,card)
		cell.hit:EnableMouse(true)
		cell.hit:SetScript("OnEnter",showCompTooltip)
		cell.hit:SetScript("OnLeave",hideCompTooltip)
		cell.hit:Hide()
		card.cells[i]=cell
	end
	frame.recapCard=card
	return card
end

local function hideComp(cell)
	for _,pair in ipairs(cell.comp)do
		pair.icon:Hide()
		pair.name:Hide()
	end
	cell.hit:Hide()
end

local function hideCell(cell)
	cell.bg:Hide()
	cell.edge:Hide()
	cell.title:Hide()
	cell.value:Hide()
	hideComp(cell)
end

local function paintComp(card,cell,held,width)
	local members=held.members
	local pad,inner=A.metric("roundCardPad"),A.metric("compChipInner")
	local lead=A.textRoom(cell.value,held.text)
	local leadGap=A.metric("chipGap")
	local room=math.max(0,width-pad*2-lead-leadGap)
	for i=#cell.comp+1,#members do
		local name=card:CreateFontString(nil,"ARTWORK","GameFontHighlightSmall")
		name:SetWordWrap(false)
		cell.comp[i]={icon=card:CreateTexture(nil,"ARTWORK"),name=name}
	end
	local first=cell.comp[1].icon
	first:ClearAllPoints()
	first:SetPoint("LEFT",cell.value,"LEFT",lead+leadGap,0)
	local size=A.recapIconSize(#members,room)
	local drawRoom=held.form=="icons"and math.min(room,#members*size+inner*(#members-1))or room
	A.drawComp(cell.comp,members,drawRoom,{size=size,between=inner,short=held.form=="short"})
	local drawn,named=0,0
	local lines={held.label}
	for i=1,#members do
		local pair,m=cell.comp[i],members[i]
		if pair.icon:IsShown()then
			drawn=drawn+1
		end
		if pair.name:IsShown()then
			named=named+1
		end
		lines[#lines+1]=A.channelEscape(A.classColor(m.classToken))..A.chipText(m).."|r"
	end
	local from=held.match~=nil and A.matchLineText(held.match)or nil
	if from~=nil then
		lines[#lines+1]={gap=true}
		lines[#lines+1]=from
	end
	cell.hit.lines=lines
	cell.hit:ClearAllPoints()
	cell.hit:SetPoint("TOPLEFT",cell.bg,"TOPLEFT",0,0)
	cell.hit:SetPoint("BOTTOMRIGHT",cell.bg,"BOTTOMRIGHT",0,0)
	cell.hit:Show()
	return drawn,named
end

local CHIP_FORMS={"full","short","icons"}

local function compCellNeed(card,cell,held,form)
	local members=held.members
	local size=A.metric("compSwatch")
	local each=size
	if form~="icons"then
		A.style(card.measure,"bodyText","text")
		local widest=0
		for i=1,#members do
			widest=math.max(widest,A.textRoom(card.measure,A.chipFormText(members[i],form)))
		end
		each=size+A.metric("chipGap")+widest
	end
	return A.metric("roundCardPad")*2+A.textRoom(cell.value,held.text)+A.metric("chipGap")
		+#members*each+A.metric("compChipInner")*(#members-1)
end

local function recapCellWidths(card,cells,count,width)
	local pad=A.metric("roundCardPad")
	local widths,comps,chips={},{},{}
	local plain=A.metric("roundCardGap")*(count-1)
	for i=1,count do
		local cell,held=card.cells[i],cells[i]
		A.style(cell.value,held.role or"number",held.tone)
		if type(held.members)=="table"and#held.members>0 then
			comps[#comps+1]=i
		else
			widths[i]=math.max(A.recapCellFloor(i),pad*2+A.textRoom(cell.value,held.text))
			plain=plain+widths[i]
		end
	end
	local step,needs={},{}
	local function needAt(i)
		return math.max(A.recapCellFloor(i),compCellNeed(card,card.cells[i],cells[i],CHIP_FORMS[step[i]]))
	end
	for _,i in ipairs(comps)do
		step[i]=1
		needs[i]=needAt(i)
	end
	while true do
		local need,widest=plain,nil
		for _,i in ipairs(comps)do
			need=need+needs[i]
			if step[i]<#CHIP_FORMS and(widest==nil or needs[i]>needs[widest])then
				widest=i
			end
		end
		if need<=width then
			for _,i in ipairs(comps)do
				widths[i]=needs[i]
				cells[i].form=CHIP_FORMS[step[i]]
				chips[cells[i].key]=cells[i].form
			end
			return widths,"content",chips
		end
		if widest==nil then
			break
		end
		step[widest]=step[widest]+1
		needs[widest]=needAt(widest)
	end
	local keep=plain
	for _,i in ipairs(comps)do
		keep=keep+A.recapCellFloor(i)
		cells[i].form="icons"
		chips[cells[i].key]="icons"
	end
	for i=1,count do
		if keep>width or widths[i]==nil then
			widths[i]=A.recapCellFloor(i)
		end
	end
	return widths,"floors",chips
end

local function paintCell(card,cell,held,x,width)
	local pad,edge=A.metric("roundCardPad"),A.metric("roundCardEdge")
	local top=-(A.fontSize("label")+A.metric("roundCardLine"))
	cell.bg:ClearAllPoints()
	cell.bg:SetPoint("TOPLEFT",card,"TOPLEFT",x,top)
	cell.bg:SetSize(width,A.outingCellsHeight())
	cell.bg:SetColorTexture(A.color("panelDeep"))
	cell.bg:Show()
	cell.edge:ClearAllPoints()
	cell.edge:SetPoint("TOPLEFT",cell.bg,"TOPLEFT",0,0)
	cell.edge:SetSize(width,edge)
	cell.edge:SetColorTexture(A.color(held.tone))
	cell.edge:Show()
	local y=-(edge+pad)
	A.style(cell.title,"label","dim")
	cell.title:SetText(held.label)
	cell.title:ClearAllPoints()
	cell.title:SetPoint("TOPLEFT",cell.bg,"TOPLEFT",pad,y)
	cell.title:Show()
	A.style(cell.value,held.role or"number",held.tone)
	cell.value:SetText(held.text)
	cell.value:ClearAllPoints()
	cell.value:SetPoint("TOPLEFT",cell.bg,"TOPLEFT",pad,y-A.fontSize("label")-A.metric("roundCardLine"))
	cell.value:Show()
	if type(held.members)~="table"or#held.members==0 then
		cell.value:SetWidth(math.max(1,width-pad*2))
		hideComp(cell)
		if held.key=="best"or held.key=="worst"then
			return 0,0
		end
		return nil
	end
	cell.value:SetWidth(0)
	return paintComp(card,cell,held,width)
end

function A.paintRecapCard(frame,format,history,sessions,character,now)
	if type(frame)~="table"then
		return nil
	end
	local card=buildCard(frame)
	frame.recapDrawn=false
	if not history then
		card:Hide()
		return nil
	end
	local session=type(sessions)=="table"and sessions[1]or nil
	local recap,reason=nil,nil
	if not A.recapReads(format)then
		reason="no-format"
	elseif session==nil then
		reason="no-session"
	else
		recap=A.sessionRecap(session,format,character)
		if recap==nil then
			reason="one-match"
		elseif not A.sessionOpen(session.key,true)then
			reason="folded"
		end
	end
	local key=session and session.key~=nil and tostring(session.key)or nil
	if reason~=nil or recap==nil then
		card:Hide()
		A.trace("recap",{key=key,matches=recap and recap.matches or(session and session.matches)or nil,
			reason=reason},"ui")
		return nil
	end

	local width=A.listHostWidth(false)
	card:ClearAllPoints()
	card:SetPoint("TOPLEFT",frame.summary or frame.filterRow,"BOTTOMLEFT",0,-A.metric("paneGap"))
	card:SetSize(width,A.recapCardHeight())

	A.style(card.heading,"label","bright")
	card.heading:SetText(A.sessionRecapHeading(session,now)or"SESSION")
	card.heading:ClearAllPoints()
	card.heading:SetPoint("TOPLEFT",card,"TOPLEFT",0,0)
	card.heading:Show()
	A.style(card.span,"label","dim")
	card.span:SetText(A.sessionSpanText(session)or"")
	card.span:ClearAllPoints()
	card.span:SetPoint("LEFT",card.heading,"RIGHT",A.metric("rowCellGap"),0)
	card.span:Show()

	local cells=A.sessionRecapCells(recap)
	local count=math.min(#cells,A.recapCellsFit(width))
	local gap=A.metric("roundCardGap")
	local widths,fit,chips=recapCellWidths(card,cells,count,width)
	local need=gap*(count-1)
	for i=1,count do
		need=need+widths[i]
	end
	local share=math.max(0,math.floor((width-need)/count))
	local x=0
	local drawn,named={},{}
	for i=1,#card.cells do
		if i<=count then
			local cellWidth=widths[i]+share
			drawn[cells[i].key],named[cells[i].key]=paintCell(card,card.cells[i],cells[i],x,cellWidth)
			x=x+cellWidth+gap
		else
			hideCell(card.cells[i])
		end
	end
	card:Show()
	frame.recapDrawn=true

	A.trace("recap",{key=key,matches=recap.matches,record=A.sessionRecapRecordText(recap.record),
		change=recap.change,cells=count,reason="none",bestMembers=drawn.best,bestNames=named.best,
		worstMembers=drawn.worst,worstNames=named.worst,fit=fit,bestChips=chips.best,
		worstChips=chips.worst},"ui")
	return count
end
