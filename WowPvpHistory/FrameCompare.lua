-- WowPvpHistory 0.70.7
-- Author:  Xenu-Sentinels
-- Project: wow-pvp-history
--          https://github.com/xenulive/wow-pvp-history
-- License: MIT, see LICENSE
local _,A=...

local FRAME_NAME="WowPvpHistoryCompareFrame"

local BASE_LINE="+N is set against the base, the leftmost match"

local window

if type(A.registerWindowKind)=="function"then
	A.registerWindowKind("compare",{
		label="compare",
		authored=function()
			return A.metric("compareWidth"),A.metric("compareHeight")
		end,
		floor=function()
			return A.metric("compareFloorWidth"),A.metric("compareFloorHeight")
		end,
		fits=true,
		point="CENTER",
		x=A.metric("compareOffsetX"),
		y=A.metric("compareOffsetY"),
	})
end

local function surface()
	return type(CreateFrame)=="function"
end

local function text(parent,layer)
	local fs=parent:CreateFontString(nil,layer or"ARTWORK","GameFontHighlightSmall")
	fs:SetJustifyH("LEFT")
	fs:SetWordWrap(false)
	return fs
end

local function hoverLine(owner,line)
	if not(GameTooltip and type(line)=="string")then
		return
	end
	pcall(function()
		GameTooltip:SetOwner(owner,"ANCHOR_TOP")
		if type(A.styleTooltip)=="function"then
			A.styleTooltip(GameTooltip)
		end
		local r,g,b=A.color("text")
		GameTooltip:SetText(line,r,g,b,1,true)
		GameTooltip:Show()
	end)
end

local function cursorX(frame)
	if type(GetCursorPosition)~="function"then
		return nil
	end
	local ok,x=pcall(GetCursorPosition)
	local okScale,scale=pcall(frame.GetEffectiveScale,frame)
	if not(ok and okScale and type(x)=="number"and type(scale)=="number"and scale>0)then
		return nil
	end
	return x/scale
end

local function buildHead(frame,index)
	local card=CreateFrame("Button",nil,frame.body)
	card:SetHeight(A.metric("compareHead"))
	card.ground=card:CreateTexture(nil,"BACKGROUND")
	card.ground:SetAllPoints(card)
	card.edges={}
	for side=1,4 do
		card.edges[side]=card:CreateTexture(nil,"BORDER")
	end
	card.edges[1]:SetPoint("TOPLEFT",card,"TOPLEFT",0,0)
	card.edges[1]:SetPoint("TOPRIGHT",card,"TOPRIGHT",0,0)
	card.edges[1]:SetHeight(1)
	card.edges[2]:SetPoint("BOTTOMLEFT",card,"BOTTOMLEFT",0,0)
	card.edges[2]:SetPoint("BOTTOMRIGHT",card,"BOTTOMRIGHT",0,0)
	card.edges[2]:SetHeight(1)
	card.edges[3]:SetPoint("TOPLEFT",card,"TOPLEFT",0,0)
	card.edges[3]:SetPoint("BOTTOMLEFT",card,"BOTTOMLEFT",0,0)
	card.edges[3]:SetWidth(3)
	card.edges[4]:SetPoint("TOPRIGHT",card,"TOPRIGHT",0,0)
	card.edges[4]:SetPoint("BOTTOMRIGHT",card,"BOTTOMRIGHT",0,0)
	card.edges[4]:SetWidth(1)

	local pad=A.metric("paneGap")
	card.id=text(card)
	card.id:SetPoint("TOPLEFT",card,"TOPLEFT",pad+3,-pad)
	card.map=text(card)
	card.map:SetPoint("TOPLEFT",card.id,"BOTTOMLEFT",0,-2)
	card.map:SetPoint("RIGHT",card,"RIGHT",-pad,0)
	card.day=text(card)
	card.day:SetPoint("TOPLEFT",card.map,"BOTTOMLEFT",0,-2)
	card.tag=text(card,"OVERLAY")
	card.tag:SetPoint("TOPRIGHT",card,"TOPRIGHT",-pad,-pad)
	card.tag:SetJustifyH("RIGHT")
	card.tagHover=CreateFrame("Frame",nil,card)
	card.tagHover:SetPoint("TOPRIGHT",card.tag,"TOPRIGHT",0,0)
	card.tagHover:SetPoint("BOTTOMRIGHT",card.tag,"BOTTOMRIGHT",0,0)
	card.tagHover:EnableMouse(true)
	card.tagHover:SetScript("OnEnter",function(self)
		self.shownLine=BASE_LINE
		hoverLine(self,BASE_LINE)
	end)
	card.tagHover:SetScript("OnLeave",function(self)
		A.hideOwnedTooltip(self)
	end)
	card.tagHover:Hide()

	card.drop=CreateFrame("Button",nil,card)
	card.drop:SetSize(16,16)
	card.drop:SetPoint("TOPRIGHT",card,"TOPRIGHT",-2,-2)
	card.drop.label=text(card.drop,"OVERLAY")
	card.drop.label:SetPoint("CENTER",card.drop,"CENTER",0,0)
	card.drop.label:SetJustifyH("CENTER")
	card.drop.label:SetText("x")
	card.drop:SetScript("OnClick",function()
		if card.matchId~=nil then
			A.compareDrop(card.matchId)
		end
	end)
	card.drop:SetScript("OnEnter",function(self)
		hoverLine(self,"Take this match out")
	end)
	card.drop:SetScript("OnLeave",function(self)
		A.hideOwnedTooltip(self)
	end)
	card.drop:Show()

	card:RegisterForDrag("LeftButton")
	card:SetScript("OnDragStart",function(self)
		self.dragging=true
	end)
	card:SetScript("OnDragStop",function(self)
		self.dragging=nil
		local first=frame.heads[1]
		local x=cursorX(self)
		local okRight,right=pcall(first.GetRight,first)
		if self.column~=nil and self.column>1 and x~=nil and okRight and type(right)=="number"and x<right then
			A.compareMoveBase(self.column,"drag")
		end
	end)
	card:Hide()
	frame.heads[index]=card
	return card
end

local function buildRow(frame,index)
	local row={cells={}}
	row.label=text(frame.body)
	row.group=text(frame.body)
	for c=1,4 do
		local cell={}
		cell.value=text(frame.body)
		cell.diff=text(frame.body)
		cell.squares={}
		for s=1,6 do
			cell.squares[s]=frame.body:CreateTexture(nil,"ARTWORK")
			cell.squares[s]:Hide()
		end
		cell.icons={}
		cell.more=text(frame.body)
		row.cells[c]=cell
	end
	frame.rows[index]=row
	return row
end

local function buildWindow()
	local frame=CreateFrame("Frame",FRAME_NAME,UIParent,"BasicFrameTemplateWithInset")
	frame:SetSize(A.metric("compareWidth"),A.metric("compareHeight"))
	frame:SetPoint("CENTER",UIParent,"CENTER",A.metric("compareOffsetX"),A.metric("compareOffsetY"))
	frame:SetFrameStrata("MEDIUM")
	frame:SetToplevel(true)
	frame:SetClampedToScreen(true)
	frame:SetMovable(true)
	frame:EnableMouse(true)
	frame:RegisterForDrag("LeftButton")
	frame:SetScript("OnDragStart",frame.StartMoving)
	frame:SetScript("OnDragStop",function(self)
		A.stopDrag(self)
		if type(A.rememberWindow)=="function"then
			pcall(A.rememberWindow,"compare")
		end
	end)
	frame:Hide()
	frame.windowName=FRAME_NAME

	A.registerChrome(frame)

	frame.heading=A.windowTitle(frame)
	frame.heading:SetPoint("TOPLEFT",frame,"TOPLEFT",A.metric("titleInset"),-A.metric("titleTop"))
	frame.heading:SetPoint("TOPRIGHT",frame,"TOPRIGHT",-A.metric("titleInset"),-A.metric("titleTop"))
	frame.heading:SetJustifyH("CENTER")
	frame.heading:SetWordWrap(false)

	frame.body=CreateFrame("Frame",nil,frame)
	frame.body:SetPoint("TOPLEFT",frame,"TOPLEFT",A.metric("margin"),-A.metric("headerHeight"))
	frame.body:SetPoint("BOTTOMRIGHT",frame,"BOTTOMRIGHT",-A.metric("margin"),
		A.metric("margin")+A.metric("compareFoot"))
	frame.body:Show()

	frame.heads,frame.rows={},{}
	for i=1,4 do
		buildHead(frame,i)
	end

	frame.addMatch=A.pill(frame,"Add a match",function()
		if type(A.showWindowBody)=="function"then
			A.showWindowBody("history")
		end
	end,A.metric("actionMin"))
	frame.addMatch:SetPoint("BOTTOMLEFT",frame,"BOTTOMLEFT",A.metric("margin"),A.metric("margin"))
	frame.openEach=A.pill(frame,"Open each window",function()
		for _,id in ipairs(A.compareIds())do
			A.raiseMatchWindow("match",id,"compare")
		end
	end,A.metric("actionMin"))
	frame.openEach:SetPoint("LEFT",frame.addMatch,"RIGHT",A.metric("paneGap"),0)

	if type(UISpecialFrames)=="table"then
		local seen=false
		for i=1,#UISpecialFrames do
			if UISpecialFrames[i]==FRAME_NAME then
				seen=true
				break
			end
		end
		if not seen then
			UISpecialFrames[#UISpecialFrames+1]=FRAME_NAME
		end
	end

	window=frame
	if type(A.attachResize)=="function"then
		pcall(A.attachResize,frame,"compare",function()
			A.refreshCompareWindow()
		end)
	end
	return frame
end

local function windowOrNil()
	if window then
		return window
	end
	if not surface()then
		return nil
	end
	local built=A.buildWindowOnce("compare",buildWindow)
	if not built then
		window=nil
		return nil
	end
	window=built
	return window
end

local function widthOf(frame)
	local ok,width=pcall(frame.GetWidth,frame)
	if ok and type(width)=="number"and width>0 then
		return width
	end
	return A.metric("compareWidth")
end

local function paintHead(card,record,column,x,width)
	card.matchId=record.id
	card.column=column
	card:ClearAllPoints()
	card:SetPoint("TOPLEFT",window.body,"TOPLEFT",x,0)
	card:SetWidth(width)
	card.ground:SetColorTexture(A.color("panelDeep"))
	local tone=A.resultTone(record)or"hairline"
	for side=1,4 do
		card.edges[side]:SetColorTexture(A.color(tone))
	end
	local id,map,day=A.compareHeadLines(record)
	card.id:SetText(id)
	A.style(card.id,"bodyMedium","bright")
	card.map:SetText(map)
	A.style(card.map,"bodyText","text")
	card.day:SetText(day)
	A.style(card.day,"rowNote","dim")
	if column==1 then
		card.tag:SetText("BASE")
		A.style(card.tag,"label","accent")
		card.tag:Show()
		card.tagHover:SetWidth(math.max(1,A.textRoom(card.tag,"BASE")))
		card.tagHover:Show()
		card.drop:Hide()
	else
		card.tag:Hide()
		card.tagHover:Hide()
		A.style(card.drop.label,"bodyMedium","dim")
		card.drop:Show()
	end
	card:Show()
end

local function hideRow(row)
	row.label:Hide()
	row.group:Hide()
	for _,cell in ipairs(row.cells)do
		cell.value:Hide()
		cell.diff:Hide()
		cell.more:Hide()
		for _,square in ipairs(cell.squares)do
			square:Hide()
		end
		for _,icon in ipairs(cell.icons)do
			icon:Hide()
		end
	end
end

local function valueTone(cell)
	if cell.best then
		return"accent"
	end
	if cell.base or cell.text=="-"then
		return"dim"
	end
	return"text"
end

local function paintIcons(cell,data,x,y,width)
	local side=A.metric("compareIcon")
	local step=side+2
	local total=#(data.icons or{})
	A.style(cell.more,"rowNote","dim")
	local moreRoom=A.textRoom(cell.more,("+%d"):format(total))+A.metric("chipGap")
	local room=total
	if total*step>width then
		room=math.max(1,math.floor((width-moreRoom)/step))
	end
	local drawn=0
	for i,entry in ipairs(data.icons or{})do
		if i>room then
			break
		end
		local icon=cell.icons[i]
		if icon==nil then
			icon=window.body:CreateTexture(nil,"ARTWORK")
			cell.icons[i]=icon
		end
		icon:ClearAllPoints()
		icon:SetPoint("TOPLEFT",window.body,"TOPLEFT",x+(i-1)*step,y)
		icon:SetSize(side,side)
		local art=type(A.specIcon)=="function"and A.specIcon(entry.classToken,entry.spec)or nil
		if art~=nil then
			icon:SetTexture(art)
			icon:SetVertexColor(1,1,1)
		else
			icon:SetColorTexture(A.classColor(entry.classToken))
		end
		icon:Show()
		drawn=drawn+1
	end
	local rest=#(data.icons or{})-drawn
	if rest>0 then
		cell.more:ClearAllPoints()
		cell.more:SetPoint("TOPLEFT",window.body,"TOPLEFT",x+drawn*step,y)
		cell.more:SetText(("+%d"):format(rest))
		cell.more:Show()
		return drawn,A.textRoom(cell.more,("+%d"):format(rest))+A.metric("chipGap")
	end
	return drawn,0
end

local function paintCell(row,cell,data,x,y,width)
	local offset=0
	if data.squares~=nil then
		local side,gap=A.metric("compareSquare"),A.metric("compareSquareGap")
		for s=1,6 do
			local square=cell.squares[s]
			square:ClearAllPoints()
			square:SetPoint("TOPLEFT",window.body,"TOPLEFT",x+(s-1)*(side+gap),y-6)
			square:SetSize(side,side)
			local tone="faint"
			if s<=data.squares.won then
				tone="win"
			elseif s<=data.squares.played then
				tone="loss"
			end
			square:SetColorTexture(A.color(tone))
			square:Show()
		end
		offset=6*(side+gap)+4
	elseif data.icons~=nil and#data.icons>0 and not data.base then
		local drew,moreWidth=paintIcons(cell,data,x,y-3,width)
		offset=drew*(A.metric("compareIcon")+2)+moreWidth
		if row.key~="swing"then
			cell.value:Hide()
			return
		end
	end
	local room=math.max(1,width-offset)
	cell.value:ClearAllPoints()
	cell.value:SetPoint("TOPLEFT",window.body,"TOPLEFT",x+offset,y-4)
	cell.value:SetText(data.text)
	A.style(cell.value,"bodyText",valueTone(data))
	if row.tier and type(data.tier)=="table"then
		cell.value:SetTextColor(data.tier[1],data.tier[2],data.tier[3])
	end
	cell.value:Show()
	cell.diffAt=nil
	if data.diffText==nil then
		cell.value:SetWidth(room)
		return
	end
	cell.diff:SetText(data.diffText)
	A.style(cell.diff,"rowNote",data.diffTone or"dim")
	local gap=A.metric("compareDiffGap")
	local diffWidth=A.textRoom(cell.diff,data.diffText)
	local valueWidth=math.max(1,math.min(A.textRoom(cell.value,data.text),room-gap-diffWidth))
	cell.value:SetWidth(valueWidth)
	cell.diffAt=x+offset+valueWidth+gap
	cell.diff:ClearAllPoints()
	cell.diff:SetPoint("TOPLEFT",window.body,"TOPLEFT",cell.diffAt,y-4)
	cell.diff:SetJustifyH("LEFT")
	cell.diff:SetWidth(math.max(1,diffWidth))
	cell.diff:Show()
end

local function fittedHeight(y)
	return A.metric("headerHeight")-y+A.metric("compareFoot")+A.metric("margin")
end

local function fitHeight(y)
	local held=A.storedGeometry("compare")
	if held~=nil and held.sized then
		return"stored"
	end
	local height=fittedHeight(y)
	local _,screenH=A.screenSizeFor(window)
	if type(screenH)=="number"and screenH>0 and height>screenH then
		height=screenH
	end
	local ok,current=pcall(window.GetHeight,window)
	if not(ok and type(current)=="number"and math.abs(current-height)<0.5)then
		pcall(window.SetHeight,window,height)
	end
	return"rows"
end

function A.refreshCompareWindow()
	if not window then
		return nil
	end
	local records=A.compareRecords()
	if#records<2 then
		return nil
	end
	local rows,hidden=A.compareRows(records)
	pcall(function()
		window.heading:SetText(A.compareTitle(#records,records[1].format))
		A.style(window.heading,"heading","bright")
		A.fitControl(window.addMatch,A.metric("actionMin"))
		A.fitControl(window.openEach,A.metric("actionMin"))
	end)

	local body=widthOf(window)-A.metric("margin")*2
	local labelWidth=A.metric("compareLabel")
	local gap=A.metric("compareColumnGap")
	local columnWidth=math.floor((body-labelWidth-gap*#records)/#records)
	local function columnX(c)
		return labelWidth+gap+(c-1)*(columnWidth+gap)
	end

	for c=1,4 do
		local card=window.heads[c]
		if records[c]then
			pcall(paintHead,card,records[c],c,columnX(c),columnWidth)
		else
			card:Hide()
		end
	end

	local y=-(A.metric("compareHead")+A.metric("paneGap"))
	local used,group=0,nil
	for _,data in ipairs(rows)do
		used=used+1
		local row=window.rows[used]or buildRow(window,used)
		hideRow(row)
		if data.group~=group then
			group=data.group
			row.group:ClearAllPoints()
			row.group:SetPoint("TOPLEFT",window.body,"TOPLEFT",0,y-4)
			row.group:SetText(group)
			A.style(row.group,"label","dim")
			row.group:Show()
			y=y-A.metric("compareGroupRow")
		end
		row.key=data.key
		row.tier=data.tier
		row.label:ClearAllPoints()
		row.label:SetPoint("TOPLEFT",window.body,"TOPLEFT",0,y-4)
		row.label:SetWidth(labelWidth)
		row.label:SetText(data.label)
		A.style(row.label,"bodyText","dim")
		row.label:Show()
		for c,cellData in ipairs(data.cells)do
			pcall(paintCell,row,row.cells[c],cellData,columnX(c),y,columnWidth)
		end
		y=y-A.metric("compareRow")
	end
	for i=used+1,#window.rows do
		hideRow(window.rows[i])
	end
	window.fit=fitHeight(y)
	window.drawnRows=rows
	window.drawnRecords=records
	return rows,hidden
end

function A.showCompareWindow()
	if A.compareCount()<2 then
		return false
	end
	local frame=windowOrNil()
	if not frame then
		return false
	end
	local rows,hidden=A.refreshCompareWindow()
	if rows==nil then
		return false
	end
	local shown=pcall(frame.Show,frame)
	pcall(frame.Raise,frame)
	local keys={}
	for i=1,#rows do
		keys[i]=rows[i].key
	end
	local okHeight,height=pcall(frame.GetHeight,frame)
	A.trace("compare/open",{
		count=A.compareCount(),format=A.compareFormat(),
		rowKeys=A.compareKeysText(keys),hiddenRows=A.compareKeysText(hidden),
		sameRows=A.compareKeysText(A.compareSameKeys(rows)),
		fit=frame.fit,height=okHeight and A.unitFigure(height)or nil,
	},"ui")
	return shown
end

function A.compareWindowShown()
	if not window then
		return false
	end
	local ok,shown=pcall(window.IsShown,window)
	return ok and shown==true
end

function A.hideCompareWindow()
	if not A.compareWindowShown()then
		return false
	end
	return(pcall(window.Hide,window))
end

function A.compareFrame()
	return window
end

function A.compareSetChanged()
	if not A.compareWindowShown()then
		return
	end
	if A.compareCount()<2 then
		A.hideCompareWindow()
		return
	end
	A.refreshCompareWindow()
end
