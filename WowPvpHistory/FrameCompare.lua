-- WowPvpHistory 0.70.27
-- Author:  Xenu-Sentinels
-- Project: wow-pvp-history
--          https://github.com/xenulive/wow-pvp-history
-- License: MIT, see LICENSE
local _,A=...

local FRAME_NAME="WowPvpHistoryCompareFrame"

local BASE_LINE="+N is set against the base, the leftmost match"

local SWING_LINE="Swing is your win rate with that spec less your win rate against it"

local HEADING_ROLE="section"

local BASE_WASH=0.05
local BEST_WASH=0.10
local CHIP_WASH=0.22
local OUTLINE_WASH=0.45

local window

local lobbyScrolls=0
local LOBBY_SCROLL_TRACES=20

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

local function wash(texture,tone,alpha)
	local r,g,b=A.color(tone)
	texture:SetColorTexture(r,g,b,alpha)
end

local function hoverSurface(parent)
	local hover=CreateFrame("Frame",nil,parent)
	hover:EnableMouse(true)
	hover:SetScript("OnEnter",function(self)
		if self.line~=nil then
			self.shownLine=self.line
			A.hoverLine(self,self.line)
		end
	end)
	hover:SetScript("OnLeave",function(self)
		A.hideOwnedTooltip(self)
	end)
	hover:Hide()
	return hover
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

local function edgesAround(owner,region,layer,out)
	local edges={}
	for side=1,4 do
		edges[side]=owner:CreateTexture(nil,layer)
	end
	edges[1]:SetPoint("TOPLEFT",region,"TOPLEFT",-out,out)
	edges[1]:SetPoint("TOPRIGHT",region,"TOPRIGHT",out,out)
	edges[1]:SetHeight(1)
	edges[2]:SetPoint("BOTTOMLEFT",region,"BOTTOMLEFT",-out,-out)
	edges[2]:SetPoint("BOTTOMRIGHT",region,"BOTTOMRIGHT",out,-out)
	edges[2]:SetHeight(1)
	edges[3]:SetPoint("TOPLEFT",region,"TOPLEFT",-out,out)
	edges[3]:SetPoint("BOTTOMLEFT",region,"BOTTOMLEFT",-out,-out)
	edges[3]:SetWidth(1)
	edges[4]:SetPoint("TOPRIGHT",region,"TOPRIGHT",out,out)
	edges[4]:SetPoint("BOTTOMRIGHT",region,"BOTTOMRIGHT",out,-out)
	edges[4]:SetWidth(1)
	return edges
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
	card.outline=edgesAround(card,card,"BACKGROUND",2)

	local pad=A.metric("paneGap")
	card.id=text(card)
	card.id:SetPoint("TOPLEFT",card,"TOPLEFT",pad+3,-pad)
	card.map=text(card)
	card.map:SetPoint("TOPLEFT",card.id,"BOTTOMLEFT",0,-2)
	card.day=text(card)
	card.day:SetPoint("TOPLEFT",card.map,"BOTTOMLEFT",0,-2)
	card.tag=text(card,"OVERLAY")
	card.tag:SetPoint("TOPRIGHT",card,"TOPRIGHT",-pad,-pad)
	card.tag:SetJustifyH("RIGHT")
	card.result=text(card,"OVERLAY")
	card.result:SetPoint("RIGHT",card,"RIGHT",-pad,0)
	card.result:SetJustifyH("RIGHT")
	card.rating=text(card,"OVERLAY")
	card.rating:SetPoint("BOTTOMRIGHT",card,"BOTTOMRIGHT",-pad,pad-2)
	card.rating:SetJustifyH("RIGHT")
	card.score=text(card,"OVERLAY")
	card.score:SetJustifyH("RIGHT")
	card.tagHover=CreateFrame("Frame",nil,card)
	card.tagHover:SetPoint("TOPRIGHT",card.tag,"TOPRIGHT",0,0)
	card.tagHover:SetPoint("BOTTOMRIGHT",card.tag,"BOTTOMRIGHT",0,0)
	card.tagHover:EnableMouse(true)
	card.tagHover:SetScript("OnEnter",function(self)
		self.shownLine=BASE_LINE
		A.hoverLine(self,BASE_LINE)
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
		A.hoverLine(self,"Take this match out")
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

local function buildTab(frame,key)
	local tab=CreateFrame("Button",nil,frame.body)
	tab:SetHeight(A.metric("compareTab"))
	tab.key=key
	tab.label=text(tab,"OVERLAY")
	tab.label:SetPoint("LEFT",tab,"LEFT",A.metric("compareTabPad"),0)
	tab.rule=tab:CreateTexture(nil,"OVERLAY")
	tab.rule:SetPoint("BOTTOMLEFT",tab,"BOTTOMLEFT",0,0)
	tab.rule:SetPoint("BOTTOMRIGHT",tab,"BOTTOMRIGHT",0,0)
	tab.rule:SetHeight(2)
	tab:SetScript("OnClick",function(self)
		A.compareSetTab(self.key,"click")
	end)
	tab:Hide()
	return tab
end

local function buildRow(frame,index)
	local row={cells={}}
	row.label=text(frame.body)
	row.group=text(frame.body)
	for c=1,4 do
		local cell={}
		cell.bestFill=frame.body:CreateTexture(nil,"BACKGROUND",nil,2)
		cell.bestEdge=frame.body:CreateTexture(nil,"BORDER")
		cell.chip=frame.body:CreateTexture(nil,"BORDER")
		cell.value=text(frame.body)
		cell.diff=text(frame.body,"OVERLAY")
		cell.squares={}
		for s=1,6 do
			cell.squares[s]=frame.body:CreateTexture(nil,"ARTWORK")
			cell.squares[s]:Hide()
		end
		row.cells[c]=cell
	end
	frame.rows[index]=row
	return row
end

local function buildRoundLine(frame,index)
	local line={cards={}}
	line.id=text(frame.body)
	line.word=text(frame.body)
	for r=1,6 do
		local card={}
		card.ground=frame.body:CreateTexture(nil,"BACKGROUND",nil,2)
		card.top=frame.body:CreateTexture(nil,"BORDER")
		card.n=text(frame.body)
		card.letter=text(frame.body)
		card.icons={frame.body:CreateTexture(nil,"ARTWORK"),frame.body:CreateTexture(nil,"ARTWORK")}
		line.cards[r]=card
	end
	frame.roundLines[index]=line
	return line
end

local function buildLobbyRow(frame,index)
	local row={cells={}}
	row.icon=frame.body:CreateTexture(nil,"ARTWORK")
	row.name=text(frame.body)
	for c=1,4 do
		row.cells[c]={text=text(frame.body),hover=hoverSurface(frame.body)}
	end
	frame.lobbyRows[index]=row
	return row
end

local function buildWindow()
	local frame=CreateFrame("Frame",FRAME_NAME,UIParent,"BasicFrameTemplateWithInset")
	frame:SetSize(A.metric("compareWidth"),A.metric("compareHeight"))
	frame:SetPoint("CENTER",UIParent,"CENTER",A.metric("compareOffsetX"),A.metric("compareOffsetY"))
	A.standMovableWindow(frame)
	frame:SetScript("OnDragStop",function(self)
		A.stopDrag(self)
		if type(A.rememberWindow)=="function"then
			pcall(A.rememberWindow,"compare")
		end
	end)
	frame:Hide()
	frame.windowName=FRAME_NAME

	A.registerChrome(frame)

	A.placeWindowHeading(frame)

	frame.body=CreateFrame("Frame",nil,frame)
	frame.body:SetPoint("TOPLEFT",frame,"TOPLEFT",A.metric("margin"),-A.metric("headerHeight"))
	frame.body:SetPoint("BOTTOMRIGHT",frame,"BOTTOMRIGHT",-A.metric("margin"),
		A.metric("margin")+A.metric("compareFoot"))
	frame.body:Show()

	frame.heads,frame.rows,frame.roundLines,frame.lobbyRows={},{},{},{}
	for i=1,4 do
		buildHead(frame,i)
	end
	frame.tabs={figures=buildTab(frame,"figures"),rounds=buildTab(frame,"rounds")}
	frame.tabRule=frame.body:CreateTexture(nil,"BORDER")
	frame.tabRule:SetHeight(1)

	frame.baseFill=frame.body:CreateTexture(nil,"BACKGROUND",nil,1)
	frame.foldLabel=text(frame.body)
	frame.foldText=text(frame.body)

	frame.lobbyHeading=text(frame.body)
	frame.lobbyHeadingHover=hoverSurface(frame.body)
	frame.specHead=text(frame.body)
	frame.lobbyHeads,frame.shared={},{}
	for c=1,4 do
		frame.lobbyHeads[c]=text(frame.body)
		frame.shared[c]=text(frame.body)
	end
	frame.sharedLabel=text(frame.body)
	frame.lobbyOffset=0
	frame.lobbyBox=CreateFrame("Frame",nil,frame.body)
	frame.lobbyBox:SetScript("OnMouseWheel",function(_,delta)
		A.compareScrollLobby(-(delta or 0))
	end)
	frame.lobbyBox:Hide()

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

	A.closeOnEscape(FRAME_NAME)

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

local function specArt(texture,classToken,spec)
	local art=type(A.specIcon)=="function"and A.specIcon(classToken,spec)or nil
	if art~=nil then
		texture:SetTexture(art)
		texture:SetVertexColor(1,1,1)
	else
		texture:SetColorTexture(A.classColor(classToken))
	end
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
		wash(card.outline[side],"accent",OUTLINE_WASH)
		card.outline[side]:SetShown(column==1)
	end
	local id,map,day=A.compareHeadLines(record)
	card.id:SetText(id)
	A.style(card.id,"bodyMedium","bright")
	card.day:SetText(day)
	A.style(card.day,"rowNote","dim")

	local pad=A.metric("paneGap")
	local word,wordTone=A.compareResultWord(record)
	card.result:SetText(word or"")
	A.style(card.result,"headingLarge",wordTone or"dim")
	card.result:SetShown(word~=nil)
	local wordRoom=word~=nil and A.textRoom(card.result,word)+pad or 0
	local rating,ratingTone=A.compareRatingText(record)
	card.rating:SetText(rating or"")
	A.style(card.rating,"cardValue",ratingTone or"dim")
	card.rating:SetShown(rating~=nil)
	local score=A.compareScoreText(record)
	card.score:SetText(score or"")
	A.style(card.score,"cardValue","text")
	card.score:ClearAllPoints()
	if rating~=nil then
		card.score:SetPoint("BOTTOMRIGHT",card.rating,"BOTTOMLEFT",-pad,0)
	else
		card.score:SetPoint("BOTTOMRIGHT",card,"BOTTOMRIGHT",-pad,pad-2)
	end
	card.score:SetShown(score~=nil)
	card.map:SetText(map)
	A.style(card.map,"bodyText","text")
	card.map:SetWidth(math.max(1,width-pad*2-3-wordRoom))

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
		cell.chip:Hide()
		cell.bestFill:Hide()
		cell.bestEdge:Hide()
		for _,square in ipairs(cell.squares)do
			square:Hide()
		end
	end
end

local function hideRoundLine(line)
	line.id:Hide()
	line.word:Hide()
	for _,card in ipairs(line.cards)do
		card.ground:Hide()
		card.top:Hide()
		card.n:Hide()
		card.letter:Hide()
		card.icons[1]:Hide()
		card.icons[2]:Hide()
	end
end

local function hideLobbyRow(row)
	row.icon:Hide()
	row.name:Hide()
	for _,cell in ipairs(row.cells)do
		cell.text:Hide()
		cell.hover.line=nil
		cell.hover:Hide()
	end
end

local function hideSecond()
	for _,line in ipairs(window.roundLines)do
		hideRoundLine(line)
	end
	for _,row in ipairs(window.lobbyRows)do
		hideLobbyRow(row)
	end
	window.lobbyHeading:Hide()
	window.lobbyHeadingHover:Hide()
	window.specHead:Hide()
	window.sharedLabel:Hide()
	for c=1,4 do
		window.lobbyHeads[c]:Hide()
		window.shared[c]:Hide()
	end
	window.lobbyBox:Hide()
end

local function hideFigures()
	for _,row in ipairs(window.rows)do
		hideRow(row)
	end
	window.baseFill:Hide()
	window.foldLabel:Hide()
	window.foldText:Hide()
end

local function valueTone(cell)
	if cell.best then
		return"accent"
	end
	if cell.text=="-"then
		return"dim"
	end
	return"text"
end

local function paintCell(row,cell,data,x,y,width)
	local height=A.metric("compareRow")
	if data.best then
		cell.bestFill:ClearAllPoints()
		cell.bestFill:SetPoint("TOPLEFT",window.body,"TOPLEFT",x,y)
		cell.bestFill:SetSize(width,height)
		wash(cell.bestFill,"accent",BEST_WASH)
		cell.bestFill:Show()
		cell.bestEdge:ClearAllPoints()
		cell.bestEdge:SetPoint("TOPLEFT",window.body,"TOPLEFT",x,y)
		cell.bestEdge:SetSize(2,height)
		cell.bestEdge:SetColorTexture(A.color("accent"))
		cell.bestEdge:Show()
	end
	local offset=data.best and 6 or 4
	if data.squares~=nil then
		local side,gap=A.metric("compareSquare"),A.metric("compareSquareGap")
		for s=1,6 do
			local square=cell.squares[s]
			square:ClearAllPoints()
			square:SetPoint("TOPLEFT",window.body,"TOPLEFT",x+offset+(s-1)*(side+gap),y-6)
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
		offset=offset+6*(side+gap)+4
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
	local pad=data.chip and A.metric("compareChipPad")or 0
	local diffWidth=A.textRoom(cell.diff,data.diffText)
	local valueWidth=math.max(1,math.min(A.textRoom(cell.value,data.text),room-gap-diffWidth-pad*2))
	cell.value:SetWidth(valueWidth)
	cell.diffAt=x+offset+valueWidth+gap+pad
	cell.diff:ClearAllPoints()
	cell.diff:SetPoint("TOPLEFT",window.body,"TOPLEFT",cell.diffAt,y-5)
	cell.diff:SetJustifyH("LEFT")
	cell.diff:SetWidth(math.max(1,diffWidth))
	cell.diff:Show()
	if data.chip then
		cell.chip:ClearAllPoints()
		cell.chip:SetPoint("TOPLEFT",window.body,"TOPLEFT",cell.diffAt-pad,y-3)
		cell.chip:SetSize(diffWidth+pad*2,height-6)
		wash(cell.chip,data.diffTone or"dim",CHIP_WASH)
		cell.chip:Show()
	end
end

local function figuresNeed(rows,folded)
	local need,group=0,nil
	for _,data in ipairs(rows)do
		if data.group~=group then
			group=data.group
			need=need+A.metric("compareGroupRow")
		end
		need=need+A.metric("compareRow")
	end
	if#folded>0 then
		need=need+A.metric("compareRow")
	end
	return need
end

local function secondNeed(reading)
	if reading==nil then
		return 0
	end
	local need=0
	if#reading.lines>0 then
		need=#reading.lines*A.metric("compareRoundLine")+A.metric("paneGap")
	end
	need=need+A.metric("compareGroupRow")+A.metric("compareLobbyRow")
		+math.min(reading.lobbyRows,A.compareLobbyMost())*A.metric("compareLobbyRow")
	if reading.lobby.shared~=nil then
		need=need+A.metric("compareLobbyRow")
	end
	return need
end

local function paintFigures(rows,folded,count,y,columnX,columnWidth,labelWidth)
	local top=y
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
			A.style(row.group,HEADING_ROLE,"dim")
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
	if used>0 then
		window.baseFill:ClearAllPoints()
		window.baseFill:SetPoint("TOPLEFT",window.body,"TOPLEFT",columnX(1),top)
		window.baseFill:SetSize(columnWidth,top-y)
		wash(window.baseFill,"accent",BASE_WASH)
		window.baseFill:Show()
	end
	local same=A.compareFoldText(folded)
	if same~=nil then
		local label=A.compareFoldLabel(count)
		window.foldLabel:ClearAllPoints()
		window.foldLabel:SetPoint("TOPLEFT",window.body,"TOPLEFT",0,y-5)
		window.foldLabel:SetText(label)
		A.style(window.foldLabel,"label","dim")
		window.foldLabel:Show()
		window.foldText:ClearAllPoints()
		window.foldText:SetPoint("TOPLEFT",window.body,"TOPLEFT",columnX(1),y-4)
		window.foldText:SetText(same)
		A.style(window.foldText,"bodyText","text")
		window.foldText:SetWidth(math.max(1,widthOf(window.body)-columnX(1)))
		window.foldText:Show()
		y=y-A.metric("compareRow")
	end
	return y
end

local function paintSecond(reading,records,y,columnX,columnWidth,labelWidth,body)
	local gap=A.metric("compareColumnGap")
	for index,line in ipairs(reading.lines)do
		local drawn=window.roundLines[index]or buildRoundLine(window,index)
		hideRoundLine(drawn)
		local height=A.metric("compareRoundLine")-4
		drawn.id:ClearAllPoints()
		drawn.id:SetPoint("TOPLEFT",window.body,"TOPLEFT",0,y-4)
		drawn.id:SetText(line.id)
		A.style(drawn.id,"bodyMedium","bright")
		drawn.id:Show()
		drawn.word:ClearAllPoints()
		drawn.word:SetPoint("TOPLEFT",drawn.id,"BOTTOMLEFT",0,-2)
		drawn.word:SetText(line.word or"-")
		A.style(drawn.word,"bodyMedium",line.word and line.tone or"dim")
		drawn.word:Show()
		local cards=math.max(6,#line.rounds)
		local left=labelWidth+gap
		local cardWidth=math.floor((body-left-gap*(cards-1))/cards)
		local side=A.metric("compareRoundIcon")
		for r,round in ipairs(line.rounds)do
			local card=drawn.cards[r]
			if card~=nil then
				local x=left+(r-1)*(cardWidth+gap)
				card.ground:ClearAllPoints()
				card.ground:SetPoint("TOPLEFT",window.body,"TOPLEFT",x,y)
				card.ground:SetSize(cardWidth,height)
				card.ground:SetColorTexture(A.color("panelDeep"))
				card.ground:Show()
				card.top:ClearAllPoints()
				card.top:SetPoint("TOPLEFT",window.body,"TOPLEFT",x,y)
				card.top:SetSize(cardWidth,2)
				card.top:SetColorTexture(A.color(round.tone))
				card.top:Show()
				card.n:ClearAllPoints()
				card.n:SetPoint("TOPLEFT",window.body,"TOPLEFT",x+4,y-5)
				card.n:SetText("R"..round.n)
				A.style(card.n,"rowNote","dim")
				card.n:Show()
				card.letter:ClearAllPoints()
				card.letter:SetPoint("TOPRIGHT",window.body,"TOPLEFT",x+cardWidth-4,y-4)
				card.letter:SetJustifyH("RIGHT")
				card.letter:SetText(round.letter)
				A.style(card.letter,"bodyMedium",round.tone)
				card.letter:Show()
				for m=1,2 do
					local mate=round.mates[m]
					local icon=card.icons[m]
					if mate~=nil then
						icon:ClearAllPoints()
						icon:SetPoint("BOTTOMLEFT",window.body,"TOPLEFT",x+4+(m-1)*(side+2),y-height+3)
						icon:SetSize(side,side)
						specArt(icon,mate.classToken,mate.spec)
						icon:Show()
					end
				end
			end
		end
		y=y-A.metric("compareRoundLine")
	end
	for i=#reading.lines+1,#window.roundLines do
		hideRoundLine(window.roundLines[i])
	end
	if#reading.lines>0 then
		y=y-A.metric("paneGap")
	end

	local lobby=reading.lobby
	local heading=lobby.swing and"SWING"or"SPECS MET"
	window.lobbyHeading:ClearAllPoints()
	window.lobbyHeading:SetPoint("TOPLEFT",window.body,"TOPLEFT",0,y-4)
	window.lobbyHeading:SetText(heading)
	A.style(window.lobbyHeading,HEADING_ROLE,"dim")
	window.lobbyHeading:Show()
	if lobby.swing then
		window.lobbyHeadingHover:ClearAllPoints()
		window.lobbyHeadingHover:SetPoint("TOPLEFT",window.lobbyHeading,"TOPLEFT",0,0)
		window.lobbyHeadingHover:SetPoint("BOTTOMLEFT",window.lobbyHeading,"BOTTOMLEFT",0,0)
		window.lobbyHeadingHover:SetWidth(math.max(1,A.textRoom(window.lobbyHeading,heading)))
		window.lobbyHeadingHover.line=SWING_LINE
		window.lobbyHeadingHover:Show()
	end
	y=y-A.metric("compareGroupRow")
	window.specHead:ClearAllPoints()
	window.specHead:SetPoint("TOPLEFT",window.body,"TOPLEFT",0,y-4)
	window.specHead:SetText("SPEC")
	A.style(window.specHead,"label","dim")
	window.specHead:Show()
	for c,record in ipairs(records)do
		local head=window.lobbyHeads[c]
		head:ClearAllPoints()
		head:SetPoint("TOPLEFT",window.body,"TOPLEFT",columnX(c)+4,y-4)
		head:SetText("#"..A.matchIdText(record.id))
		A.style(head,"label",c==1 and"accent"or"dim")
		head:Show()
	end
	y=y-A.metric("compareLobbyRow")

	local most=A.compareLobbyMost()
	local total=#lobby.rows
	local offset=math.max(0,math.min(window.lobbyOffset or 0,total-most))
	window.lobbyOffset=offset
	local rowTop=y
	local side=A.metric("compareIcon")
	local drawn=0
	for i=offset+1,math.min(total,offset+most)do
		local data=lobby.rows[i]
		drawn=drawn+1
		local row=window.lobbyRows[drawn]or buildLobbyRow(window,drawn)
		hideLobbyRow(row)
		row.icon:ClearAllPoints()
		row.icon:SetPoint("TOPLEFT",window.body,"TOPLEFT",0,y-3)
		row.icon:SetSize(side,side)
		specArt(row.icon,data.classToken,data.spec)
		row.icon:Show()
		row.name:ClearAllPoints()
		row.name:SetPoint("TOPLEFT",window.body,"TOPLEFT",side+4,y-4)
		row.name:SetWidth(math.max(1,labelWidth-side-4))
		row.name:SetText(data.spec)
		A.style(row.name,"bodyText","text")
		row.name:SetTextColor(A.classColor(data.classToken))
		row.name:Show()
		for c=1,#records do
			local cell=data.cells[c]
			local drawnCell=row.cells[c]
			if cell~=nil then
				drawnCell.text:ClearAllPoints()
				drawnCell.text:SetPoint("TOPLEFT",window.body,"TOPLEFT",columnX(c)+4,y-4)
				drawnCell.text:SetWidth(math.max(1,columnWidth-4))
				drawnCell.text:SetText(cell.text)
				A.style(drawnCell.text,"bodyText",cell.tone or"text")
				drawnCell.text:Show()
				local line=A.compareLobbyTooltip(data,cell)
				if line~=nil then
					drawnCell.hover:ClearAllPoints()
					drawnCell.hover:SetPoint("TOPLEFT",window.body,"TOPLEFT",columnX(c),y)
					drawnCell.hover:SetSize(columnWidth,A.metric("compareLobbyRow"))
					drawnCell.hover.line=line
					drawnCell.hover:Show()
				end
			end
		end
		y=y-A.metric("compareLobbyRow")
	end
	for i=drawn+1,#window.lobbyRows do
		hideLobbyRow(window.lobbyRows[i])
	end
	if total>most then
		window.lobbyBox:ClearAllPoints()
		window.lobbyBox:SetPoint("TOPLEFT",window.body,"TOPLEFT",0,rowTop)
		window.lobbyBox:SetSize(body,rowTop-y)
		pcall(window.lobbyBox.EnableMouseWheel,window.lobbyBox,true)
		window.lobbyBox:Show()
	end

	if lobby.shared~=nil then
		window.sharedLabel:ClearAllPoints()
		window.sharedLabel:SetPoint("TOPLEFT",window.body,"TOPLEFT",0,y-5)
		window.sharedLabel:SetWidth(labelWidth)
		window.sharedLabel:SetText("shared with base")
		A.style(window.sharedLabel,"rowNote","dim")
		window.sharedLabel:Show()
		for c=1,#records do
			local shared=window.shared[c]
			shared:ClearAllPoints()
			shared:SetPoint("TOPLEFT",window.body,"TOPLEFT",columnX(c)+4,y-5)
			shared:SetText(lobby.shared[c]or"-")
			A.style(shared,"rowNote","dim")
			shared:Show()
		end
		y=y-A.metric("compareLobbyRow")
	end
	return y,drawn
end

local function paintTabs(second,tab,y,body)
	local figures,rounds=window.tabs.figures,window.tabs.rounds
	if second==nil then
		figures:Hide()
		rounds:Hide()
		window.tabRule:Hide()
		return 0
	end
	local x=0
	for _,entry in ipairs({{figures,"Figures"},{rounds,second}})do
		local button,name=entry[1],entry[2]
		local open=button.key==tab
		button.label:SetText(name)
		A.style(button.label,"bodyMedium",open and"accent"or"dim")
		local width=A.textRoom(button.label,name)+A.metric("compareTabPad")*2
		button:ClearAllPoints()
		button:SetPoint("TOPLEFT",window.body,"TOPLEFT",x,y)
		button:SetWidth(width)
		button.rule:SetColorTexture(A.color("accent"))
		button.rule:SetShown(open)
		button:Show()
		x=x+width+A.metric("paneGap")
	end
	window.tabRule:ClearAllPoints()
	window.tabRule:SetPoint("TOPLEFT",window.body,"TOPLEFT",0,y-A.metric("compareTab"))
	window.tabRule:SetWidth(body)
	window.tabRule:SetColorTexture(A.color("hairline"))
	window.tabRule:Show()
	return A.metric("compareTab")+A.metric("paneGap")
end

local function fitHeight(height)
	local held=A.storedGeometry("compare")
	if held~=nil and held.sized then
		return"stored"
	end
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
	local rows,hidden,folded=A.compareRows(records)
	local second=A.compareSecondTab(records[1].format)
	local tab=A.compareTab()
	local reading=second~=nil and A.compareSecondReading(records)or nil
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
	local okTabs,strip=pcall(paintTabs,second,tab,y,body)
	y=y-(okTabs and strip or 0)
	hideFigures()
	hideSecond()
	window.lobbyDrawn=0
	if tab=="rounds"and reading~=nil then
		local ok,_,drawn=pcall(paintSecond,reading,records,y,columnX,columnWidth,labelWidth,body)
		window.lobbyDrawn=ok and drawn or 0
	else
		pcall(paintFigures,rows,folded,#records,y,columnX,columnWidth,labelWidth)
	end
	local need=math.max(figuresNeed(rows,folded),secondNeed(reading))
	window.fit=fitHeight(A.metric("headerHeight")-y+need+A.metric("compareFoot")+A.metric("margin"))
	window.drawnRows=rows
	window.drawnFolded=folded
	window.drawnRecords=records
	window.drawnReading=reading
	window.drawnTab=tab
	return rows,hidden,folded
end

function A.compareScrollLobby(step)
	if not window then
		return 0
	end
	window.lobbyOffset=math.max(0,(window.lobbyOffset or 0)+(step or 0))
	A.refreshCompareWindow()
	lobbyScrolls=lobbyScrolls+1
	if lobbyScrolls<=LOBBY_SCROLL_TRACES then
		A.trace("compare/scroll",{offset=window.lobbyOffset,rows=window.lobbyDrawn,n=lobbyScrolls},
			"ui")
	end
	return window.lobbyOffset
end

function A.showCompareWindow()
	if A.compareCount()<2 then
		return false
	end
	local frame=windowOrNil()
	if not frame then
		return false
	end
	frame.lobbyOffset=0
	local rows,hidden,folded=A.refreshCompareWindow()
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
		foldedRows=A.compareKeysText(A.compareFoldedKeys(folded)),
		tab=frame.drawnTab,tabs=A.compareSecondTab(A.compareFormat())~=nil and 2 or 1,
		fit=frame.fit,height=okHeight and A.unitFigure(height)or nil,
		headRole=HEADING_ROLE,
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
