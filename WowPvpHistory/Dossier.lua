-- WowPvpHistory 0.70.16
-- Author:  Xenu-Sentinels
-- Project: wow-pvp-history
--          https://github.com/xenulive/wow-pvp-history
-- License: MIT, see LICENSE
local _,A=...

local SUGGEST_SLOTS=4

local ROUND_MARKS=6

function A.repLabelColumn()
	return A.headerFloor("REP")+A.metric("paneGap")
end

function A.buildRepControl(parent,onPick)
	local control=CreateFrame("Frame",nil,parent)
	control:SetHeight(A.metric("controlHeight"))
	control.label=control:CreateFontString(nil,"ARTWORK","GameFontDisableSmall")
	control.label:SetPoint("LEFT",control,"LEFT",0,0)
	control.label:SetJustifyH("LEFT")
	control.label:SetWordWrap(false)

	control.steps={}
	for i,step in ipairs(A.ratingRamp())do
		local button=CreateFrame("Button",nil,control)
		button:SetHeight(A.metric("controlHeight"))
		button:RegisterForClicks("LeftButtonUp")
		button.edge=button:CreateTexture(nil,"BACKGROUND")
		button.edge:SetAllPoints(button)
		button.ground=button:CreateTexture(nil,"BORDER")
		button.ground:SetPoint("TOPLEFT",button,"TOPLEFT",1,-1)
		button.ground:SetPoint("BOTTOMRIGHT",button,"BOTTOMRIGHT",-1,1)
		button.hover=button:CreateTexture(nil,"HIGHLIGHT")
		button.hover:SetAllPoints(button)
		button.word=button:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
		button.word:SetPoint("CENTER",button,"CENTER",0,0)
		button.word:SetWordWrap(false)
		button.ratingValue=step.rating
		button.ratingMark=step.mark
		button:SetScript("OnClick",function(self)
			if onPick then
				onPick(self.ratingValue)
			end
		end)
		control.steps[i]=button
	end
	return control
end

function A.paintRepControl(control,rating,width,enabled)
	if type(control)~="table"or type(control.steps)~="table"then
		return false
	end
	A.style(control.label,"label","dim")
	control.label:SetText("REP")
	local column=A.repLabelColumn()
	local count=#control.steps
	local gap=A.metric("repStepGap")
	local room=(type(width)=="number"and width>0)and width or(column+count*60)
	local step=math.floor((room-column-gap*(count-1))/count)
	if step<1 then
		step=1
	end
	for i=1,count do
		local button=control.steps[i]
		local chosen=button.ratingValue==rating
		button:ClearAllPoints()
		button:SetPoint("LEFT",control,"LEFT",column+(i-1)*(step+gap),0)
		button:SetWidth(step)
		button.edge:SetColorTexture(A.color(chosen and button.ratingMark or"hairline"))
		button.ground:SetColorTexture(A.color(chosen and button.ratingMark or"panelDeep"))
		button.hover:SetColorTexture(A.color("hover"))
		A.style(button.word,"bodyText",chosen and"menuGround"or button.ratingMark)
		button.word:SetText((A.repLabel(button.ratingValue)))
		button.repChosen=chosen
		pcall(button.SetEnabled,button,enabled~=false)
	end
	return true
end

function A.repControlFloor()
	local widest=0
	local ramp=A.ratingRamp()
	for _,step in ipairs(ramp)do
		local room=A.headerFloor((A.repLabel(step.rating)))+A.metric("pillGap")
		if room>widest then
			widest=room
		end
	end
	local count=#ramp
	return A.repLabelColumn()+count*widest+(count-1)*A.metric("repStepGap")
end

function A.sideCardHeight()
	return A.metric("sideCardPad")*2+A.fontSize("label")+A.fontSize("number")+A.fontSize("note")+4
end

function A.buildSideCards(parent)
	local row=CreateFrame("Frame",nil,parent)
	row:SetHeight(A.sideCardHeight())
	row.cards={}
	for i=1,3 do
		local card=CreateFrame("Frame",nil,row)
		card:SetHeight(A.sideCardHeight())
		card.edge=card:CreateTexture(nil,"BACKGROUND")
		card.edge:SetAllPoints(card)
		card.ground=card:CreateTexture(nil,"BORDER")
		card.ground:SetPoint("TOPLEFT",card,"TOPLEFT",1,-1)
		card.ground:SetPoint("BOTTOMRIGHT",card,"BOTTOMRIGHT",-1,1)
		local pad=A.metric("sideCardPad")
		card.label=card:CreateFontString(nil,"ARTWORK","GameFontDisableSmall")
		card.label:SetPoint("TOPLEFT",card,"TOPLEFT",pad+2,-pad)
		card.label:SetPoint("TOPRIGHT",card,"TOPRIGHT",-pad,-pad)
		card.label:SetJustifyH("LEFT")
		card.label:SetWordWrap(false)
		card.figure=card:CreateFontString(nil,"ARTWORK","GameFontNormalLarge")
		card.figure:SetPoint("TOPLEFT",card.label,"BOTTOMLEFT",0,-2)
		card.figure:SetPoint("TOPRIGHT",card.label,"BOTTOMRIGHT",0,-2)
		card.figure:SetJustifyH("LEFT")
		card.figure:SetWordWrap(false)
		card.sub=card:CreateFontString(nil,"ARTWORK","GameFontDisableSmall")
		card.sub:SetPoint("TOPLEFT",card.figure,"BOTTOMLEFT",0,-2)
		card.sub:SetPoint("TOPRIGHT",card.figure,"BOTTOMRIGHT",0,-2)
		card.sub:SetJustifyH("LEFT")
		card.sub:SetWordWrap(false)
		row.cards[i]=card
	end
	return row
end

local SIDE_UNSETTLED="met, no round settled"

function A.sideCardWords(parts,never,unsettled)
	local lead,tone,rest=A.sideWords(parts)
	if rest==nil then
		return"-","dimmer",unsettled and SIDE_UNSETTLED or never
	end
	if lead==nil then
		return"-","dimmer",rest
	end
	return lead,tone,rest
end

function A.paintSideCards(row,dossier,width)
	if type(row)~="table"or type(row.cards)~="table"then
		return nil
	end
	local gap=A.metric("sideCardGap")
	local room=(type(width)=="number"and width>0)and width or 3*120+2*gap
	local each=math.floor((room-2*gap)/3)
	local withFigure,withTone,withWords=A.sideCardWords(dossier and dossier.with,"never on your side",
		dossier and dossier.withUnsettled)
	local againstFigure,againstTone,againstWords=A.sideCardWords(dossier and dossier.against,
		"never against you",dossier and dossier.againstUnsettled)
	local metFigure,metWords=A.metWords(dossier)
	local said={
		{"WITH YOU",withFigure,withTone,withWords},
		{"AGAINST YOU",againstFigure,againstTone,againstWords},
		{"MET",metFigure or"-",metFigure and"bright"or"dimmer",metWords},
	}
	for i=1,3 do
		local card=row.cards[i]
		card:ClearAllPoints()
		card:SetPoint("TOPLEFT",row,"TOPLEFT",(i-1)*(each+gap),0)
		card:SetWidth(each)
		card.edge:SetColorTexture(A.color("hairline"))
		card.ground:SetColorTexture(A.color("panelDeep"))
		A.style(card.label,"label","dim")
		card.label:SetText(said[i][1])
		A.style(card.figure,"number",said[i][3])
		card.figure:SetText(said[i][2])
		A.style(card.sub,"note","dim")
		card.sub:SetText(said[i][4]or"")
	end
	return{with=withFigure,withWords=withWords,against=againstFigure,
		againstWords=againstWords,met=metFigure}
end

function A.buildNoteRow(parent)
	local row=CreateFrame("Frame",nil,parent)
	row:SetHeight(A.metric("controlHeight"))
	row.label=row:CreateFontString(nil,"ARTWORK","GameFontDisableSmall")
	row.label:SetPoint("LEFT",row,"LEFT",0,0)
	row.label:SetWidth(A.repLabelColumn())
	row.label:SetJustifyH("LEFT")
	row.label:SetWordWrap(false)
	row.count=row:CreateFontString(nil,"ARTWORK","GameFontDisableSmall")
	row.count:SetPoint("RIGHT",row,"RIGHT",0,0)
	row.count:SetJustifyH("RIGHT")
	row.count:SetWordWrap(false)
	A.style(row.count,"note","dimmer")
	row.count:SetWidth(A.textRoom(row.count,"200 left"))
	row.box=A.entry(row)
	row.box:SetHeight(A.metric("controlHeight"))
	row.box:SetPoint("LEFT",row,"LEFT",A.repLabelColumn(),0)
	row.box:SetPoint("RIGHT",row.count,"LEFT",-A.metric("rowCellGap"),0)
	return row
end

function A.paintNoteRow(row,held)
	A.style(row.label,"label","noteWord")
	row.label:SetText("NOTE")
	A.style(row.count,"note","dimmer")
	row.count:SetText(A.noteCountText(held,A.PLAYER_NOTE_MAX)or"")
end

function A.buildTagRow(parent,onRemove,onSuggest,onCommit)
	local row=CreateFrame("Frame",nil,parent)
	row:SetHeight(A.metric("tagRow"))
	row.tagButtons={}
	for i=1,A.PLAYER_MAX_TAGS do
		local button=A.pill(row,nil,onRemove)
		button:SetHeight(A.metric("tagButton"))
		button:Hide()
		row.tagButtons[i]=button
	end
	row.suggestButtons={}
	for i=1,SUGGEST_SLOTS do
		local button=A.pill(row,nil,onSuggest)
		button:SetHeight(A.metric("tagButton"))
		A.setControlTone(button,"dim")
		button:Hide()
		row.suggestButtons[i]=button
	end
	row.box=A.entry(row)
	row.box:SetHeight(A.metric("tagButton"))
	A.entryPlaceholder(row.box,"add a tag, Enter saves")
	if onCommit then
		row.box:SetScript("OnEnterPressed",onCommit)
	end
	row.box:SetScript("OnEscapePressed",function(self)
		pcall(self.SetText,self,"")
		pcall(self.ClearFocus,self)
		local read,changed=pcall(self.GetScript,self,"OnTextChanged")
		if read and type(changed)=="function"then
			pcall(changed,self,true)
		end
	end)
	return row
end

function A.paintTagRow(row,note,width)
	local tags=(note and type(note.tags)=="table")and note.tags or{}
	local held={}
	for i=1,#tags do
		held[tags[i]]=true
	end
	local typed
	local read,box=pcall(row.box.GetText,row.box)
	if read and type(box)=="string"then
		typed=box:match("^%s*(.-)%s*$")
		if typed==""then
			typed=nil
		end
	end
	local vocabulary={}
	if#tags<A.PLAYER_MAX_TAGS and type(A.tagVocabulary)=="function"then
		local ok,listed=pcall(A.tagVocabulary,typed)
		if ok and type(listed)=="table"then
			vocabulary=listed
		end
	end

	local available=(type(width)=="number"and width>0)and width or 300
	local x,rows=0,1
	local function place(button,text)
		button:SetText(text)
		local wide=A.fitControl(button,A.metric("tagMin"),A.metric("tagPad"))
		if x>0 and x+wide>available then
			x,rows=0,rows+1
		end
		button:ClearAllPoints()
		button:SetPoint("TOPLEFT",row,"TOPLEFT",x,-(rows-1)*A.metric("tagRow"))
		button:Show()
		x=x+wide+A.metric("pillGap")
	end

	for i=1,#row.tagButtons do
		local button=row.tagButtons[i]
		local tag=tags[i]
		button.tagValue=tag
		if tag==nil then
			button:Hide()
		else
			place(button,tag.."  x")
		end
	end

	local offered,taken=0,1
	for i=1,#row.suggestButtons do
		local button=row.suggestButtons[i]
		local tag
		while taken<=#vocabulary do
			local candidate=vocabulary[taken]
			taken=taken+1
			if type(candidate)=="table"and candidate.tag~=nil and not held[candidate.tag]then
				tag=candidate.tag
				break
			end
		end
		button.tagValue=tag
		if tag==nil then
			button:Hide()
		else
			place(button,"+ "..tag)
			offered=offered+1
		end
	end

	local free=available-x
	if free<A.metric("tagBoxMin")then
		x,rows,free=0,rows+1,available
	end
	row.box:ClearAllPoints()
	row.box:SetPoint("TOPLEFT",row,"TOPLEFT",x,-(rows-1)*A.metric("tagRow"))
	row.box:SetWidth(free)
	row:SetHeight(rows*A.metric("tagRow"))
	return rows,offered
end

local ENCOUNTER_COLUMNS={
	{key="id",name="MATCH",metric="encColMatch"},
	{key="when",name="WHEN",metric="encColWhen"},
	{key="where",name="WHERE",metric="encColWhereMin"},
	{key="side",name="SIDE",metric="encColSide"},
	{key="result",name="RESULT",metric="encColResult"},
	{key="change",name="CHANGE",metric="encColChange",align="RIGHT"},
}

function A.encounterColumns()
	return ENCOUNTER_COLUMNS
end

function A.encounterWidths(span)
	local widths={}
	local used=A.metric("rowLabelPad")*2-A.metric("rowCellGap")
	local where=nil
	for i,column in ipairs(ENCOUNTER_COLUMNS)do
		local width=A.metric(column.metric)
		local header=A.headerFloor(column.name)
		if header>width then
			width=header
		end
		widths[i]=width
		used=used+width+A.metric("rowCellGap")
		if column.key=="where"then
			where=i
		end
	end
	if where and type(span)=="number"and span>used then
		widths[where]=widths[where]+(span-used)
	end
	return widths,used
end

local function columnStarts(widths)
	local starts={}
	local at=A.metric("rowLabelPad")
	for i=1,#widths do
		starts[i]=at
		at=at+widths[i]+A.metric("rowCellGap")
	end
	return starts
end

function A.buildEncounterHeader(parent)
	local header=CreateFrame("Frame",nil,parent)
	header:SetHeight(A.fontSize("label")+A.metric("headingPad"))
	header.labels={}
	for i=1,#ENCOUNTER_COLUMNS do
		local label=header:CreateFontString(nil,"ARTWORK","GameFontDisableSmall")
		label:SetWordWrap(false)
		header.labels[i]=label
	end
	header.rule=header:CreateTexture(nil,"ARTWORK")
	header.rule:SetPoint("BOTTOMLEFT",header,"BOTTOMLEFT",0,0)
	header.rule:SetPoint("BOTTOMRIGHT",header,"BOTTOMRIGHT",0,0)
	header.rule:SetHeight(1)
	return header
end

function A.paintEncounterHeader(header,widths)
	local starts=columnStarts(widths)
	for i,column in ipairs(ENCOUNTER_COLUMNS)do
		local label=header.labels[i]
		A.style(label,"label","dimmer")
		label:ClearAllPoints()
		label:SetPoint("LEFT",header,"LEFT",starts[i],0)
		label:SetWidth(widths[i])
		label:SetJustifyH(column.align or"LEFT")
		label:SetText(column.name)
	end
	header.rule:SetColorTexture(A.color("hairline"))
end

local function buildMark(parent)
	local mark=CreateFrame("Frame",nil,parent)
	mark:SetSize(A.metric("roundMark"),A.metric("roundMarkHeight"))
	mark.fill=mark:CreateTexture(nil,"ARTWORK")
	mark.fill:SetAllPoints(mark)
	mark.edges={}
	for i=1,4 do
		mark.edges[i]=mark:CreateTexture(nil,"ARTWORK")
	end
	mark.edges[1]:SetPoint("TOPLEFT")
	mark.edges[1]:SetPoint("TOPRIGHT")
	mark.edges[1]:SetHeight(1)
	mark.edges[2]:SetPoint("BOTTOMLEFT")
	mark.edges[2]:SetPoint("BOTTOMRIGHT")
	mark.edges[2]:SetHeight(1)
	mark.edges[3]:SetPoint("TOPLEFT")
	mark.edges[3]:SetPoint("BOTTOMLEFT")
	mark.edges[3]:SetWidth(1)
	mark.edges[4]:SetPoint("TOPRIGHT")
	mark.edges[4]:SetPoint("BOTTOMRIGHT")
	mark.edges[4]:SetWidth(1)
	return mark
end

function A.paintRoundMark(mark,pip)
	local side=pip and pip.side or nil
	local tone=pip and pip.tone or"faint"
	if side==nil then
		tone="faint"
	end
	mark.fill:SetColorTexture(A.color(tone))
	mark.fill:SetShown(side=="with")
	for i=1,4 do
		mark.edges[i]:SetColorTexture(A.color(tone))
		mark.edges[i]:SetShown(side~="with")
	end
	mark:Show()
end

A.buildRoundMark=buildMark

function A.buildEncounterLine(row)
	row.highlight=row:CreateTexture(nil,"BACKGROUND")
	row.highlight:SetAllPoints(row)
	row.highlight:Hide()
	row.hover=row:CreateTexture(nil,"HIGHLIGHT")
	row.hover:SetAllPoints(row)
	row.rule=row:CreateTexture(nil,"ARTWORK")
	row.rule:SetPoint("BOTTOMLEFT",row,"BOTTOMLEFT",0,0)
	row.rule:SetPoint("BOTTOMRIGHT",row,"BOTTOMRIGHT",0,0)
	row.rule:SetHeight(1)
	local function text(template)
		local region=row:CreateFontString(nil,"ARTWORK",template or"GameFontHighlightSmall")
		region:SetJustifyH("LEFT")
		region:SetWordWrap(false)
		return region
	end
	row.id=text("GameFontDisableSmall")
	row.day=text()
	row.clock=text("GameFontDisableSmall")
	row.map=text()
	row.format=text("GameFontDisableSmall")
	row.side=text()
	row.result=text()
	row.change=text()
	row.change:SetJustifyH("RIGHT")
	row.marks={}
	for i=1,ROUND_MARKS do
		row.marks[i]=buildMark(row)
	end
	return row
end

function A.paintEncounterLine(row,line,widths,highlighted)
	local regions={row.id,row.day,row.clock,row.map,row.format,row.side,row.result,row.change}
	if type(line)~="table"or type(widths)~="table"then
		for _,region in ipairs(regions)do
			region:Hide()
		end
		for i=1,#row.marks do
			row.marks[i]:Hide()
		end
		row.highlight:Hide()
		row.rule:Hide()
		row.matchId=nil
		return false
	end
	local starts=columnStarts(widths)
	local top,second=-4,-4-A.fontSize("bodyText")-2

	local function at(region,column,y,role,tone,value)
		A.style(region,role,tone)
		region:ClearAllPoints()
		if y==nil then
			region:SetPoint("LEFT",row,"LEFT",starts[column],0)
		else
			region:SetPoint("TOPLEFT",row,"TOPLEFT",starts[column],y)
		end
		region:SetWidth(widths[column])
		region:SetText(value or"")
		region:Show()
	end
	at(row.id,1,nil,"numberMicro","dim",line.id)
	at(row.day,2,top,"bodyText","text",line.day)
	at(row.clock,2,second,"rowClock","dimmer",line.clock)
	at(row.map,3,top,"bodyText","text",line.map or"-")
	at(row.format,3,second,"rowNote","dim",line.format)
	at(row.result,5,nil,"bodyMedium",line.resultTone,line.result)
	at(row.change,6,nil,"numberSmall",line.changeTone,line.change)

	if type(line.pips)=="table"then
		row.side:Hide()
		local x=starts[4]
		for i=1,#row.marks do
			local mark=row.marks[i]
			local pip=line.pips[i]
			if pip then
				mark:ClearAllPoints()
				mark:SetPoint("LEFT",row,"LEFT",x,0)
				A.paintRoundMark(mark,pip)
				x=x+A.metric("roundMark")+A.metric("roundMarkGap")
			else
				mark:Hide()
			end
		end
	else
		for i=1,#row.marks do
			row.marks[i]:Hide()
		end
		at(row.side,4,nil,"rowNote",line.sideTone or"dim",line.side or"-")
	end

	row.highlight:SetColorTexture(A.color("selection"))
	row.highlight:SetShown(highlighted==true)
	row.hover:SetColorTexture(A.color("hover"))
	row.rule:SetColorTexture(A.color("divider"))
	row.rule:Show()
	row.matchId=line.matchId
	return true
end

function A.encounterFloor()
	local _,used=A.encounterWidths(nil)
	return used
end
