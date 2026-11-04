-- WowPvpHistory 0.75.26
-- Author:  Xenu-Sentinels
-- Project: wow-pvp-history
--          https://github.com/xenulive/wow-pvp-history
-- License: MIT, see LICENSE
local _,A=...

local FRAME_NAME="WowPvpHistoryNotesFrame"

local window

local selectedGuid

local searchText
local sortWord="recent"
local sortDir
local repFilter
local attitudeFilter
local formatFilter
local sideFilter

local stagedFault=false

local scopeMatchId

local scopeTidy

local pendingReveal

local requestedGuid

local paintingToShow=false

local function refreshToShow()
	paintingToShow=true
	local ok,painted=pcall(A.refreshNotes)
	paintingToShow=false
	if not ok then
		error(painted,0)
	end
	return painted
end

local function setSelected(guid)
	if guid==selectedGuid then
		return
	end
	selectedGuid=guid
	requestedGuid=nil
	local box=window and window.tagRow and window.tagRow.box
	if box then
		pcall(box.SetText,box,"")
		pcall(box.ClearFocus,box)
	end
end

local lastRows=0

local tracedOrder="recent"

local DETAIL_SUBJECT="the player detail pane"

local function listSubject()
	return(window.list and window.list.subject)or"the player list"
end

local ROSTER_SLOTS=8

function A.notesWindowTitle()
	return("%s: players and notes"):format(A.displayName())
end

local function surface()
	if type(CreateFrame)~="function"
		or type(CreateScrollBoxListLinearView)~="function"
		or type(CreateDataProvider)~="function"
		or type(A.buildScroller)~="function"
		or type(ScrollUtil)~="table"
		or type(ScrollUtil.InitScrollBoxListWithScrollBar)~="function"then
		return false
	end
	return true
end

local function figureColumns()
	return{
		{key="met",name="MET",width=A.metric("playerColMet"),justify="RIGHT"},
		{key="trend",name="TREND",width=math.max(A.metric("playerColTrend"),A.headerFloor("TREND")),
			justify="RIGHT"},
		{key="record",name="RECORD",width=A.metric("playerColSide")*2+A.metric("rowCellGap"),
			justify="LEFT"},
	}
end

local SIDE_WORDS={with="with",against="vs"}

function A.recordCellText(withParts,againstParts)
	local out,plain={},{}
	local comma=A.colorEscape("dim")..", |r"
	for _,side in ipairs({{"with",withParts},{"against",againstParts}})do
		local pieces=A.sideShort(side[2])
		if pieces then
			local figures,texts={},{}
			for i=1,#pieces do
				figures[i]=A.colorEscape(pieces[i].tone or"dim")..pieces[i].text.."|r"
				texts[i]=pieces[i].text
			end
			local word=SIDE_WORDS[side[1]]
			out[#out+1]=table.concat(figures,comma).." "
				..A.colorEscape("text")..word.."|r"
			plain[#plain+1]=table.concat(texts,", ").." "..word
		end
	end
	if#out==0 then
		return A.colorEscape("dimmer").."-|r","-"
	end
	return table.concat(out,comma),table.concat(plain,", ")
end

A.TREND_FLOOR=100

function A.trendCellText(trend)
	if type(trend)~="table"or type(trend.change)~="number"then
		return"","dimmer"
	end
	local change=trend.change
	if change>=A.TREND_FLOOR then
		return("+%d"):format(change),"win"
	end
	if change<=-A.TREND_FLOOR then
		return("%d"):format(change),"loss"
	end
	return"\194\183","dimmer"
end

local function figureEdges()
	local columns=figureColumns()
	local edges={}
	local at=A.metric("rowLabelPad")
	local gap=A.metric("rowCellGap")
	for i=#columns,1,-1 do
		edges[i]=at
		at=at+columns[i].width+gap
	end
	return edges,at
end

function A.fitNameHead(fontString,bare,realm,realmTone,after)
	if fontString==nil then
		return nil
	end
	local forms={}
	if type(realm)=="string"and realm~=""then
		forms[1]=bare.."  "..A.colorEscape(realmTone or"dim")..realm.."|r"..(after or"")
	end
	forms[#forms+1]=bare..(after or"")
	fontString.headForms=forms
	return A.refitNameHead(fontString,true)
end

function A.refitNameHead(fontString,retry)
	local forms=fontString and fontString.headForms
	if type(forms)~="table"or#forms==0 then
		return nil
	end
	local ok,room=pcall(fontString.GetWidth,fontString)
	local text,index,measured=nil,nil,false
	local roomRead=ok and type(room)=="number"and room>0
	if roomRead then
		text,index,measured=A.fittedForm(fontString,room,forms)
	end
	if text==nil then
		text=measured and forms[#forms]or forms[1]
		index=measured and#forms or nil
		if retry and#forms>1 and type(C_Timer)=="table"
			and type(C_Timer.After)=="function"then
			C_Timer.After(0,function()
				if fontString.headForms==forms then
					A.refitNameHead(fontString,false)
					if type(fontString.onRefit)=="function"then
						pcall(fontString.onRefit,fontString.headFit)
					end
				end
			end)
		end
	end
	local form="unmeasured"
	if#forms==1 then
		form="alone"
	elseif index==1 then
		form="realm"
	elseif index~=nil then
		form="bare"
	end
	fontString.headFit={
		room=roomRead and A.unitFigure(room)or 0,
		need=#forms>1 and A.unitFigure(A.textRoom(fontString,forms[1]))or nil,
		form=form,
	}
	fontString:SetText(text)
	return text
end

function A.playersIconSize()
	return A.fontSize("bodyMedium")+2+A.fontSize("note")
end

local function initRow(row,data)
	if not row.built then
		row.built=true
		row:RegisterForClicks("LeftButtonUp")

		row.ground=row:CreateTexture(nil,"BACKGROUND")
		row.ground:SetAllPoints(row)
		row.selection=row:CreateTexture(nil,"BORDER")
		row.selection:SetAllPoints(row)
		row.selection:Hide()
		row.hover=row:CreateTexture(nil,"HIGHLIGHT")
		row.hover:SetAllPoints(row)
		row.rule=row:CreateTexture(nil,"ARTWORK")
		row.rule:SetPoint("BOTTOMLEFT",row,"BOTTOMLEFT",0,0)
		row.rule:SetPoint("BOTTOMRIGHT",row,"BOTTOMRIGHT",0,0)
		row.rule:SetHeight(1)

		row.lane=row:CreateTexture(nil,"ARTWORK")
		row.lane:SetPoint("TOPLEFT",row,"TOPLEFT",0,0)
		row.lane:SetPoint("BOTTOMLEFT",row,"BOTTOMLEFT",0,1)
		row.lane:SetWidth(A.metric("playerLane"))

		local edges,used=figureEdges()
		row.figures={}
		for i,column in ipairs(figureColumns())do
			local cell=row:CreateFontString(nil,"ARTWORK","GameFontHighlightSmall")
			cell:SetPoint("RIGHT",row,"RIGHT",-edges[i],0)
			cell:SetWidth(column.width)
			cell:SetJustifyH(column.justify)
			cell:SetWordWrap(false)
			row.figures[i]=cell
		end

		local left=A.metric("playerLane")+A.metric("playerLaneGap")
		row.specIcon=row:CreateTexture(nil,"ARTWORK")
		row.specIcon:SetPoint("TOPLEFT",row,"TOPLEFT",left,-4)
		row.specIcon:Hide()

		row.label=row:CreateFontString(nil,"ARTWORK","GameFontHighlightSmall")
		row.label:SetJustifyH("LEFT")
		row.label:SetWordWrap(false)

		row.spec=row:CreateFontString(nil,"ARTWORK","GameFontDisableSmall")
		row.spec:SetPoint("TOPLEFT",row.label,"BOTTOMLEFT",0,-2)
		row.spec:SetPoint("RIGHT",row,"RIGHT",-used,0)
		row.spec:SetJustifyH("LEFT")
		row.spec:SetWordWrap(false)

		row.heading=row:CreateFontString(nil,"ARTWORK","GameFontHighlightSmall")
		row.heading:SetPoint("LEFT",row,"LEFT",A.metric("rowLabelPad")*3,0)
		row.heading:SetJustifyH("LEFT")
		row.heading:SetWordWrap(false)
		row.headCount=row:CreateFontString(nil,"ARTWORK","GameFontDisableSmall")
		row.headCount:SetPoint("RIGHT",row,"RIGHT",-A.metric("rowLabelPad")*3,0)
		row.headCount:SetJustifyH("RIGHT")
		row.headCount:SetWordWrap(false)

		row:SetScript("OnClick",function(self)
			if self.playerGuid~=nil then
				A.clickPlayersRow(self.playerGuid)
			end
		end)
		row:SetScript("OnEnter",function(self)
			if self.fullName~=nil then
				A.keyedTooltip(self,{self.fullName},"ANCHOR_RIGHT","players-name")
			end
		end)
		row:SetScript("OnLeave",A.hideTooltip)
	end

	row.hover:SetColorTexture(A.color("hover"))
	row.selection:SetColorTexture(A.color("selection"))
	row.rule:SetColorTexture(A.color("divider"))

	if data.section~=nil then
		row.playerGuid=nil
		row.fullName=nil
		row:EnableMouse(false)
		row.hover:Hide()
		row.selection:Hide()
		row.lane:Hide()
		row.label:Hide()
		row.specIcon:Hide()
		row.spec:Hide()
		for i=1,#row.figures do
			row.figures[i]:Hide()
		end
		row.ground:SetColorTexture(A.color("sessionGround"))
		row.ground:Show()
		A.style(row.heading,"bodyMedium","accent")
		row.heading:SetText(data.section)
		row.heading:Show()
		A.style(row.headCount,"numberMicro","dim")
		row.headCount:SetText(data.count or"")
		row.headCount:Show()
		return
	end

	row.heading:Hide()
	row.headCount:Hide()
	row.ground:Hide()
	row.hover:Show()
	row:EnableMouse(true)
	local item=data.row
	row.playerGuid=item.guid

	row.lane:SetColorTexture(A.color(item.mark))
	row.lane:Show()

	local identity=item.identity
	row.label:ClearAllPoints()
	row.label:SetPoint("TOPLEFT",row,"TOPLEFT",
		A.metric("playerLane")+A.metric("playerLaneGap")+A.playersIconSize()+A.metric("chipGap"),-4)
	row.label:SetPoint("RIGHT",row,"RIGHT",-select(2,figureEdges()),0)
	A.style(row.label,"bodyMedium")
	row.label:SetTextColor(A.classColor(identity.classToken))
	local realm=A.realmDrawn(identity.realm,data.realmKept)
	row.fullName=(realm==nil and identity.realm~=nil)and identity.full or nil
	A.fitNameHead(row.label,identity.bare or A.UNKNOWN_PLAYER,realm,"dimmer",
		item.noted and("  "..A.colorEscape("noteWord").."note|r")or nil)
	row.label:Show()

	A.drawSpec({icon=row.specIcon},identity.classToken,identity.spec,nil,{size=A.playersIconSize()})
	local sub=identity.specLabel or""
	if item.tag then
		sub=sub..(sub~=""and"  "or"")..A.colorEscape("text")..item.tag.."|r"
	end
	A.style(row.spec,"rowNote","dim")
	row.spec:SetText(sub)
	row.spec:Show()

	local met,trend,record=row.figures[1],row.figures[2],row.figures[3]
	A.style(met,"numberSmall",item.met>1 and"text"or"dimmer")
	met:SetText(("x%d"):format(item.met))
	local trendText,trendTone=A.trendCellText(item.trend)
	A.style(trend,"numberSmall",trendTone)
	trend:SetText(trendText)
	A.style(record,"numberSmall","text")
	record:SetText((A.recordCellText(item.with,item.against)))
	for i=1,#row.figures do
		row.figures[i]:Show()
	end

	row.selection:SetShown(item.guid==selectedGuid)
end

local function rowExtent(_,data)
	if type(data)=="table"and data.section~=nil then
		return A.metric("playerSection")
	end
	return A.metric("playerRow")
end

function A.applyNoteTemplate(box,guid,template)
	if type(template)~="string"or template==""then
		return nil,"empty"
	end
	local read,typed=pcall(box.GetText,box)
	local base=(read and type(typed)=="string"and typed or""):gsub("^%s+",""):gsub("%s+$","")
	local function trace(state,reason,text)
		A.trace("edit",{field="note",via="template",state=state,reason=reason,
			bytes=text and#text or nil,bound=text and A.PLAYER_NOTE_MAX or nil},"data")
	end
	if base:find(template,1,true)then
		trace("unchanged","present")
		return"present"
	end
	local joined=base==""and template or(base..", "..template)
	if#joined>A.PLAYER_NOTE_MAX then
		A.say(("that note would be %d bytes and the bound is %d bytes. Nothing written")
			:format(#joined,A.PLAYER_NOTE_MAX))
		trace("refused","too-long",joined)
		return nil,"too-long"
	end
	local held=A.noteFor(guid)
	local stored=type(held)=="table"and type(held.text)=="string"and held.text or""
	if base~=stored then
		pcall(box.SetText,box,joined)
		trace("drafted",nil,joined)
		return"drafted"
	end
	local saved,_,why=A.setPlayerNote(guid,joined)
	if not saved then
		A.say(("%s, so the note could not be stored"):format(A.noteRefusalText(why)))
		trace("refused",why,joined)
		return nil,why
	end
	pcall(box.SetText,box,joined)
	trace("filled",nil,joined)
	return"saved"
end

function A.commitNoteBox(box,guid)
	local ok,text=pcall(box.GetText,box)
	if not ok then
		return
	end

	local cleared=text==nil or text:gsub("%s","")==""
	local stored,was,why,length,bound=A.setPlayerNote(guid,not cleared and text or nil)
	if stored and cleared and was~=nil then
		A.sayRemoved(guid,"note",was)
	end
	if not stored then
		if why=="too-long"then
			A.say(("that note is %d bytes and the bound is %d bytes. Nothing written")
				:format(tonumber(length)or 0,tonumber(bound)or A.PLAYER_NOTE_MAX))
		else
			A.say(("%s, so the note could not be stored"):format(A.noteRefusalText(why)))
		end
		return
	end

	pcall(box.ClearFocus,box)
end

local function commitNote()
	if not(window and selectedGuid)then
		return
	end
	A.commitNoteBox(window.noteRow.box,selectedGuid)
end

function A.paintNoteBox(box,owner,guid,stored)
	stored=type(stored)=="string"and stored or""
	local ok,held=pcall(box.GetText,box)
	held=(ok and type(held)=="string")and held or""
	if owner.notePaintedFor==guid and held~=owner.notePainted and held~=stored then
		return held,true
	end
	box:SetText(stored)
	owner.notePainted,owner.notePaintedFor=stored,guid
	return stored,false
end

function A.discardTypedNote(box,owner)
	local ok,held=pcall(box.GetText,box)
	owner.notePainted=(ok and type(held)=="string")and held or""
end

function A.pickNoteStep(guid,scale,wanted)
	local field=scale=="attitude"and"attitude"or"rating"
	local held=A.noteFor(guid)
	if held~=nil and held[field]==wanted then
		wanted=nil
	end
	local set=scale=="attitude"and A.setPlayerAttitude or A.setPlayerRating
	local stored,was,why=set(guid,wanted)
	if not stored then
		A.say(("%s, so the %s could not be stored"):format(A.noteRefusalText(why),scale))
	elseif wanted==nil and was~=nil then
		A.sayRemoved(guid,field,was)
	end
end

local function scalePicked(scale,wanted)
	if selectedGuid then
		A.pickNoteStep(selectedGuid,scale,wanted)
	end
end

local function repPicked(wanted)
	scalePicked("skill",wanted)
end

local function attitudePicked(wanted)
	scalePicked("attitude",wanted)
end

function A.sayTagRefusal(why,offender,bound)
	if why=="tag-too-long"then
		A.say(("%q is longer than %d bytes, so nothing was added")
			:format(tostring(offender),tonumber(bound)or A.PLAYER_TAG_MAX))
	elseif why=="too-many"then
		A.say(("that is past %d tags, so %q and the rest were not added. Nothing written")
			:format(tonumber(bound)or A.PLAYER_MAX_TAGS,tostring(offender)))
	else
		A.say(("%s, so the tags could not be stored"):format(A.noteRefusalText(why)))
	end
end

local function boxWords(text)
	local tags={}
	for word in tostring(text or""):gmatch("%S+")do
		tags[#tags+1]=word
	end
	return tags
end

function A.commitTagBox(box,guid)
	local ok,text=pcall(box.GetText,box)
	if not ok then
		return
	end
	local tags=boxWords(text)
	if#tags==0 then
		return
	end
	pcall(box.SetText,box,"")
	local stored,added,why,offender,bound=A.addPlayerTags(guid,tags)
	if not stored then
		pcall(box.SetText,box,text)
		A.sayTagRefusal(why,offender,bound)
		return
	end
	if type(added)=="table"and#added==0 then
		A.say("every one of those tags was already there. Nothing written")
	end
	pcall(box.ClearFocus,box)
end

local function commitTags()
	if not(window and selectedGuid)then
		return
	end
	A.commitTagBox(window.tagRow.box,selectedGuid)
end

function A.removeShownTag(guid,tag)
	local stored,removed,why=A.removePlayerTags(guid,{tag})
	if not stored then
		A.say(("%s, so the tag could not be removed"):format(A.noteRefusalText(why)))
	elseif type(removed)=="table"and#removed>0 then
		A.sayRemoved(guid,"tag",removed)
	end
end

local function tagClicked(button)
	if selectedGuid and button.tagValue then
		A.removeShownTag(selectedGuid,button.tagValue)
	end
end

local function templateClicked(button)
	local box=window and window.noteRow and window.noteRow.box
	if selectedGuid and box and button.templateValue then
		A.applyNoteTemplate(box,selectedGuid,button.templateValue)
	end
end

local function suggestClicked(button)
	if not(selectedGuid and button.tagValue)then
		return
	end
	local box=window and window.tagRow and window.tagRow.box
	local typed
	if box then
		local read,held=pcall(box.GetText,box)
		typed=read and held or""
		pcall(box.SetText,box,"")
	end
	local stored,_,why,offender,bound=A.addPlayerTags(selectedGuid,{button.tagValue})
	if not stored then
		if box then
			pcall(box.SetText,box,typed)
		end
		A.sayTagRefusal(why,offender,bound)
	end
end

local function standTagRow(note,pane)
	local tagRows=A.paintTagRow(window.tagRow,note,pane)
	window.dossier:SetHeight(A.notesPaneStack(tagRows))
	return tagRows
end

local function paintTagSuggestions()
	if not(window and window.tagRow and selectedGuid)then
		return false
	end
	local tagRows=standTagRow(A.noteFor(selectedGuid),A.notesPaneSplit())
	pcall(A.trace,"paint",{source="tags",shown=tagRows,format="notes"},"ui")
	return true
end

local function scopedRecord()
	if scopeMatchId==nil then
		return nil
	end
	return A.match(scopeMatchId)
end

local function commitRosterTags()
	local record=scopedRecord()
	if not(window and record)then
		return
	end

	local ok,text=pcall(window.rosterBox.GetText,window.rosterBox)
	if not ok then
		return
	end

	local tags=boxWords(text)
	if#tags==0 then
		return
	end

	local stored,summary,why,offender,bound=A.tagRoster(record,tags)
	if not stored then
		if why=="tag-too-long"then
			A.say(("%q is longer than %d bytes, so nothing was added")
				:format(tostring(offender),tonumber(bound)or A.PLAYER_TAG_MAX))
		elseif why=="empty-roster"then
			A.say("this match's roster is you and its bot rows, so there is nobody to tag")
		else
			A.say(("%s, so the tags could not be stored"):format(A.noteRefusalText(why)))
		end
		return
	end

	A.say(A.rosterWriteLine(summary,true))
	pcall(window.rosterBox.SetText,window.rosterBox,"")
	pcall(window.rosterBox.ClearFocus,window.rosterBox)
end

local function rosterChipClicked(button)
	local record=scopedRecord()
	if not(record and button.tagValue)then
		return
	end

	local ok,summary,why=A.untagRoster(record,{button.tagValue})
	if not ok then
		A.say(("%s, so the tag could not be removed"):format(A.noteRefusalText(why)))
		return
	end
	A.sayRosterRemoved(summary)
end

function A.notesRosterBandHeight()
	return A.metric("paneGap")+A.metric("tagRow")
end

local ROSTER_BAND_SLIVER=1

function A.notesRosterBandHeightFor(present)
	if present then
		return A.notesRosterBandHeight()
	end
	return ROSTER_BAND_SLIVER
end

local function buildRosterBand(frame)
	frame.rosterBand=CreateFrame("Frame",nil,frame)
	frame.rosterBand:SetPoint("TOPLEFT",frame.toolbar,"BOTTOMLEFT",0,0)
	frame.rosterBand:SetPoint("TOPRIGHT",frame.toolbar,"BOTTOMRIGHT",0,0)
	frame.rosterBand:SetHeight(A.notesRosterBandHeightFor(false))
	frame.rosterBand:Hide()

	frame.rosterChips={}
	for i=1,ROSTER_SLOTS do
		local button=A.pill(frame.rosterBand,nil,rosterChipClicked)
		button:SetHeight(A.metric("tagButton"))
		button:Hide()
		frame.rosterChips[i]=button
	end

	frame.rosterMore=frame.rosterBand:CreateFontString(nil,"ARTWORK","GameFontDisableSmall")
	frame.rosterMore:SetJustifyH("LEFT")
	frame.rosterMore:SetWordWrap(false)
	frame.rosterMore:Hide()

	frame.rosterBox=A.entry(frame.rosterBand)
	frame.rosterBox:SetHeight(A.metric("tagButton"))
	A.entryPlaceholder(frame.rosterBox,"tag this whole roster, Enter saves")
	frame.rosterBox:SetScript("OnEnterPressed",commitRosterTags)
	frame.rosterBox:SetScript("OnEscapePressed",function(self)
		pcall(self.SetText,self,"")
		pcall(self.ClearFocus,self)
	end)
end

local function paintRosterBand()
	if not(window and window.rosterBand)then
		return false
	end

	local record=scopedRecord()
	local counts=record and A.rosterTagCounts(record)or{}
	local subjects=record and#A.rosterPlayers(record)or 0

	if not record or subjects==0 then
		for i=1,#window.rosterChips do
			window.rosterChips[i]:Hide()
		end
		window.rosterMore:Hide()
		window.rosterBand:SetHeight(A.notesRosterBandHeightFor(false))
		window.rosterBand:Hide()
		return false
	end

	local available=window.rosterBand:GetWidth()
	if type(available)~="number"or available<120 then
		available=A.notesFrameWidth()-A.metric("margin")*2
	end

	local tagMin,tagPad,tagBoxMin=A.metric("tagMin"),A.metric("tagPad"),A.metric("tagBoxMin")
	local paneGap,pillGap=A.metric("paneGap"),A.metric("pillGap")
	local x,shown=0,0
	local full=false
	for i=1,#window.rosterChips do
		local button=window.rosterChips[i]
		local held=counts[i]
		if held==nil then
			button:Hide()
		else
			button.tagValue=held.tag
			button:SetText(("%s %d  x"):format(held.tag,held.count))
			local width=A.fitControl(button,tagMin,tagPad)
			if full or(x>0 and x+width>available-tagBoxMin)then
				full=true
				button:Hide()
			else
				button:ClearAllPoints()
				button:SetPoint("TOPLEFT",window.rosterBand,"TOPLEFT",x,-paneGap)
				button:Show()
				x=x+width+pillGap
				shown=shown+1
			end
		end
	end

	local missed=#counts-shown
	if missed>0 then
		window.rosterMore:ClearAllPoints()
		window.rosterMore:SetPoint("TOPLEFT",window.rosterBand,"TOPLEFT",x,-paneGap-4)
		local more=("+%d"):format(missed)
		window.rosterMore:SetText(more)
		A.style(window.rosterMore,"note","dimmer")
		window.rosterMore:Show()
		x=x+A.textRoom(window.rosterMore,more)+pillGap
	else
		window.rosterMore:Hide()
	end

	local free=available-x
	if free<tagBoxMin then
		free=tagBoxMin
	end
	window.rosterBox:ClearAllPoints()
	window.rosterBox:SetPoint("TOPRIGHT",window.rosterBand,"TOPRIGHT",0,-paneGap)
	window.rosterBox:SetWidth(free)

	window.rosterBand:SetHeight(A.notesRosterBandHeightFor(true))
	window.rosterBand:Show()
	return true
end

function A.playersStripHeight()
	return A.metric("standPad")*2+A.fontSize("label")+A.fontSize("number")+A.fontSize("note")+8
end

local function stripLabel(scale)
	return"THEIR "..A.scaleLabel(scale)
end

local function legendNeed()
	local legend=0
	local swatch,paneGap=A.metric("repSwatch"),A.metric("paneGap")
	for _,slice in ipairs(A.repSlices())do
		local countFloor=A.headerFloor(slice.rating=="none"and"0,000"or"000")
		legend=legend+swatch+4+countFloor+paneGap+6
	end
	return legend
end

local function stripBlock(parent)
	local block=CreateFrame("Frame",nil,parent)
	block.label=block:CreateFontString(nil,"ARTWORK","GameFontDisableSmall")
	block.label:SetPoint("TOPLEFT",block,"TOPLEFT",0,0)
	block.label:SetPoint("TOPRIGHT",block,"TOPRIGHT",0,0)
	block.label:SetJustifyH("LEFT")
	block.label:SetWordWrap(false)
	block.figure=block:CreateFontString(nil,"ARTWORK","GameFontNormalLarge")
	block.figure:SetPoint("TOPLEFT",block.label,"BOTTOMLEFT",0,-4)
	block.figure:SetPoint("TOPRIGHT",block.label,"BOTTOMRIGHT",0,-4)
	block.figure:SetJustifyH("LEFT")
	block.figure:SetWordWrap(false)
	block.sub=block:CreateFontString(nil,"ARTWORK","GameFontDisableSmall")
	block.sub:SetPoint("TOPLEFT",block.figure,"BOTTOMLEFT",0,-4)
	block.sub:SetPoint("TOPRIGHT",block.figure,"BOTTOMRIGHT",0,-4)
	block.sub:SetJustifyH("LEFT")
	block.sub:SetWordWrap(false)
	block.rule=block:CreateTexture(nil,"ARTWORK")
	block.rule:SetPoint("TOPLEFT",block,"TOPLEFT",-A.metric("paneGap"),0)
	block.rule:SetPoint("BOTTOMLEFT",block,"BOTTOMLEFT",-A.metric("paneGap"),0)
	block.rule:SetWidth(1)
	return block
end

function A.repSlices(strip,scale)
	scale=scale or"skill"
	local steps=type(strip)=="table"and(scale=="attitude"and strip.attitudeSteps or strip.steps)or{}
	local counts={}
	for _,step in ipairs(steps)do
		counts[step.rating]=step.count
	end
	local out={}
	for _,step in ipairs(A.ratingRamp(scale))do
		out[#out+1]={rating=step.rating,label=(A.repLabel(step.rating,scale)),mark=step.mark,
			swatch=step.mark,count=counts[step.rating]or 0}
	end
	local rest=0
	if type(strip)=="table"then
		rest=(scale=="attitude"and strip.attitudeNotRated or strip.notRated)or 0
	end
	out[#out+1]={rating="none",label=(A.repLabel(nil)),mark=A.ratingMark(nil),swatch="dimmer",
		count=rest}
	return out
end

local function buildStrip(frame)
	local pad=A.metric("standPad")
	frame.strip=CreateFrame("Frame",nil,frame)
	frame.strip:SetPoint("TOPLEFT",frame,"TOPLEFT",A.metric("margin"),-A.metric("headerHeight"))
	frame.strip:SetPoint("TOPRIGHT",frame,"TOPRIGHT",-A.metric("margin"),-A.metric("headerHeight"))
	frame.strip:SetHeight(A.playersStripHeight())
	frame.strip.ground=frame.strip:CreateTexture(nil,"BACKGROUND")
	frame.strip.ground:SetAllPoints(frame.strip)
	frame.strip.rule=frame.strip:CreateTexture(nil,"ARTWORK")
	frame.strip.rule:SetPoint("BOTTOMLEFT",frame.strip,"BOTTOMLEFT",0,0)
	frame.strip.rule:SetPoint("BOTTOMRIGHT",frame.strip,"BOTTOMRIGHT",0,0)
	frame.strip.rule:SetHeight(1)

	frame.stripLead=stripBlock(frame.strip)
	frame.stripLead:SetPoint("TOPLEFT",frame.strip,"TOPLEFT",pad,-pad)
	frame.stripLead:SetPoint("BOTTOMLEFT",frame.strip,"BOTTOMLEFT",pad,pad)
	frame.stripLead:SetWidth(A.metric("standLead"))
	frame.stripLead.rule:Hide()

	frame.stripTiles={}
	local x=pad
	local tileWidth,paneGap=A.metric("standTile"),A.metric("paneGap")
	for i=3,1,-1 do
		local tile=stripBlock(frame.strip)
		tile:SetPoint("TOPRIGHT",frame.strip,"TOPRIGHT",-x,-pad)
		tile:SetPoint("BOTTOMRIGHT",frame.strip,"BOTTOMRIGHT",-x,pad)
		tile:SetWidth(tileWidth)
		frame.stripTiles[i]=tile
		x=x+tileWidth+paneGap*2
	end

	frame.stripReps={}
	for _,scale in ipairs(A.SCALES)do
		local rep=CreateFrame("Frame",nil,frame.strip)
		rep.scale=scale
		local after=scale=="skill"and frame.stripLead or frame.stripRep
		rep:SetPoint("TOPLEFT",after,"TOPRIGHT",A.metric("paneGap")*3,0)
		rep:SetPoint("BOTTOMLEFT",after,"BOTTOMRIGHT",A.metric("paneGap")*3,0)
		if scale=="skill"then
			frame.stripRep=rep
		else
			frame.stripAttitude=rep
		end
		frame.stripReps[scale]=rep
		rep.label=rep:CreateFontString(nil,"ARTWORK","GameFontDisableSmall")
		rep.label:SetPoint("TOPLEFT",rep,"TOPLEFT",0,0)
		rep.label:SetJustifyH("LEFT")
		rep.label:SetWordWrap(false)

		rep.bars,rep.legend={},{}
		local barHeight,keyHeight,swatch=A.metric("repBarHeight"),A.fontSize("note")+4,A.metric("repSwatch")
		for i,step in ipairs(A.repSlices(nil,scale))do
			local bar=CreateFrame("Button",nil,rep)
			bar:SetHeight(barHeight)
			bar:RegisterForClicks("LeftButtonUp")
			bar.fill=bar:CreateTexture(nil,"ARTWORK")
			bar.fill:SetAllPoints(bar)
			bar.ratingValue=step.rating
			bar.ratingMark=step.mark
			bar.scale=scale
			bar:SetScript("OnClick",function(self)
				A.toggleNotesScale(self.scale,self.ratingValue)
			end)
			rep.bars[i]=bar

			local key=CreateFrame("Button",nil,rep)
			key:SetHeight(keyHeight)
			key:RegisterForClicks("LeftButtonUp")
			key.swatch=key:CreateTexture(nil,"ARTWORK")
			key.swatch:SetSize(swatch,swatch)
			key.swatch:SetPoint("LEFT",key,"LEFT",0,0)
			key.word=key:CreateFontString(nil,"ARTWORK","GameFontHighlightSmall")
			key.word:SetPoint("LEFT",key.swatch,"RIGHT",4,0)
			key.word:SetWordWrap(false)
			key.count=key:CreateFontString(nil,"ARTWORK","GameFontDisableSmall")
			key.count:SetPoint("LEFT",key.word,"RIGHT",4,0)
			key.count:SetWordWrap(false)
			key.ratingValue=step.rating
			key.ratingMark=step.swatch
			key.scale=scale
			key:SetScript("OnClick",function(self)
				A.toggleNotesScale(self.scale,self.ratingValue)
			end)
			rep.legend[i]=key
		end
	end
end

local function paintStrip(view)
	local strip=view.strip
	window.strip.ground:SetColorTexture(A.color("panelDeep"))
	window.strip.rule:SetColorTexture(A.color("hairline"))

	local lead=window.stripLead
	A.style(lead.label,"label","dim")
	lead.label:SetText("PLAYERS MET")
	A.style(lead.figure,"number","bright")
	lead.figure:SetText(A.groupedCount(strip.players))
	local function fitted(region,room,forms)
		local text,at,measured=A.fittedForm(region,room,forms)
		if text==nil then
			at=measured and#forms or 1
			text=forms[at]
		end
		region:SetText(text)
		return text,at
	end

	A.style(lead.sub,"numberMicro","dim")
	local encounters,matches=A.groupedCount(strip.encounters),A.groupedCount(strip.matches)
	local matchWord=strip.matches==1 and"match"or"matches"
	local leadText
	if view.scopeId~=nil then
		leadText=fitted(lead.sub,A.metric("standLead"),{
			("in match #%s"):format(tostring(view.scopeId)),
		})
	elseif view.tidy then
		leadText=fitted(lead.sub,A.metric("standLead"),{"a tidy would drop","to tidy"})
	else
		local encounterWord=strip.encounters==1 and"encounter"or"encounters"
		local forms={
			("%s %s in %s %s"):format(encounters,encounterWord,matches,matchWord),
			("%s %s, %s %s"):format(encounters,encounterWord,matches,matchWord),
			("%s %s"):format(encounters,encounterWord),
		}
		local unmet=strip.unmet or 0
		if unmet>0 then
			local never=("%s never met"):format(A.groupedCount(unmet))
			if strip.players==0 then
				forms={never}
			else
				forms={
					("%s, %s"):format(forms[1],never),
					("%s, %s"):format(forms[3],never),
					forms[1],forms[2],forms[3],
				}
			end
		end
		leadText=fitted(lead.sub,A.metric("standLead"),forms)
	end

	local total=select(2,pcall(window.strip.GetWidth,window.strip))
	if type(total)~="number"or total<100 then
		total=A.notesFrameWidth()-A.metric("margin")*2
	end
	local roomAll=total-A.metric("standPad")*2-A.metric("standLead")
		-3*(A.metric("standTile")+A.metric("paneGap")*2)-A.metric("paneGap")*3
	local bothGap=A.metric("paneGap")*3
	local skillRoom=math.max(math.floor((roomAll-bothGap)/2),legendNeed())
	local rooms={skill=skillRoom,attitude=math.max(roomAll-bothGap-skillRoom,1)}
	local paintFilter={skill=repFilter,attitude=attitudeFilter}
	local barWidths={}
	for _,scale in ipairs(A.SCALES)do
		local rep=window.stripReps[scale]
		local filter=paintFilter[scale]
		local room=rooms[scale]
		A.style(rep.label,"label","dim")
		rep.label:SetText(stripLabel(scale))
		rep:SetWidth(room)

		local slices=A.repSlices(strip,scale)
		local gap=A.metric("repBarGap")
		local floor=6
		local sum,held=0,0
		for _,slice in ipairs(slices)do
			sum=sum+slice.count
			if slice.count>0 then
				held=held+1
			end
		end
		local spare=room-gap*(held-1)-floor*held
		local x=0
		local barTop=-(A.fontSize("label")+6)
		local widths={}
		barWidths[scale]=widths
		for i,bar in ipairs(rep.bars)do
			local slice=slices[i]
			local width=0
			if i==#slices and(sum==0 or slice.count>0)then
				width=math.max(math.floor(room-x),floor)
			elseif slice.count>0 then
				width=floor+(spare>0 and math.floor(spare*slice.count/sum)or 0)
			end
			widths[i]=width
			bar:ClearAllPoints()
			bar:SetPoint("TOPLEFT",rep,"TOPLEFT",x,barTop)
			bar:SetWidth(math.max(width,1))
			bar:SetShown(width>0)
			bar.fill:SetColorTexture(A.color(bar.ratingMark))
			local dim=filter~=nil and filter~=bar.ratingValue
			bar.fill:SetAlpha(dim and 0.3 or 1)
			if width>0 then
				x=x+width+gap
			end
		end

		local keyTop=barTop-A.metric("repBarHeight")-6
		local keyGap=A.metric("paneGap")+6
		local swatch=A.metric("repSwatch")
		local function keyWidth(key,step,withWord)
			local wide=swatch+4+A.textRoom(key.count,A.groupedCount(step.count))
			if withWord then
				wide=wide+A.textRoom(key.word,step.label)+4
			end
			return wide
		end
		local whole=0
		for i,key in ipairs(rep.legend)do
			A.style(key.word,"note","text")
			A.style(key.count,"numberMicro","dim")
			whole=whole+keyWidth(key,slices[i],true)+(i>1 and keyGap or 0)
		end
		local words=whole<=room
		local narrow=0
		for i,key in ipairs(rep.legend)do
			narrow=narrow+keyWidth(key,slices[i],false)+(i>1 and keyGap or 0)
		end
		local keyed=words or narrow<=room
		x=0
		for i,key in ipairs(rep.legend)do
			local step=slices[i]
			key:SetShown(keyed)
			local chosen=filter==key.ratingValue
			local dim=filter~=nil and not chosen
			key.swatch:SetColorTexture(A.color(key.ratingMark))
			key.swatch:SetAlpha(dim and 0.3 or 1)
			A.style(key.word,"note",chosen and key.ratingMark or(dim and"dimmer"or"text"))
			key.word:SetText(words and step.label or"")
			key.word:SetShown(words)
			key.count:ClearAllPoints()
			if words then
				key.count:SetPoint("LEFT",key.word,"RIGHT",4,0)
			else
				key.count:SetPoint("LEFT",key.swatch,"RIGHT",4,0)
			end
			key.count:SetText(A.groupedCount(step.count))
			local wide=keyWidth(key,step,words)
			key:ClearAllPoints()
			key:SetPoint("TOPLEFT",rep,"TOPLEFT",x,keyTop)
			key:SetWidth(wide)
			x=x+wide+keyGap
		end
	end

	local tiles=window.stripTiles
	local noted=A.groupedCount(strip.noted)
	local playerWord=strip.noted==1 and"player"or"players"
	local before=A.groupedCount(strip.tonightBefore)
	local said={
		{"MET AGAIN",A.groupedCount(strip.metAgain),"bright",
			strip.metAgainShare and{
				("%d%% of players"):format(strip.metAgainShare),
				("%d%%"):format(strip.metAgainShare),
			}or nil},
		{"NOTES",A.groupedCount(strip.notes),"noteWord",
			{("on %s %s"):format(noted,playerWord),("%s %s"):format(noted,playerWord)}},
		{tostring(strip.sessionDay or"Tonight"):upper(),A.groupedCount(strip.tonight),"bright",
			{("%s met before"):format(before),("%s before"):format(before)}},
	}
	local forms={}
	local tileWidth=A.metric("standTile")
	local ruleR,ruleG,ruleB,ruleA=A.color("hairline")
	for i=1,3 do
		local tile=tiles[i]
		tile.rule:SetColorTexture(ruleR,ruleG,ruleB,ruleA)
		A.style(tile.label,"label","dim")
		tile.label:SetText(said[i][1])
		A.style(tile.figure,"number",said[i][3])
		tile.figure:SetText(said[i][2])
		A.style(tile.sub,"numberMicro","dim")
		if said[i][4]then
			local _,at=fitted(tile.sub,tileWidth,said[i][4])
			forms[i]=at
		else
			tile.sub:SetText("")
			forms[i]=0
		end
	end

	return{
		tileForms=table.concat(forms,","),
		lead=leadText,
		repBars=table.concat(barWidths.skill,","),
		attitudeBars=table.concat(barWidths.attitude,","),
	}
end

function A.notesToolbarHeight()
	return A.metric("controlHeight")*2+A.metric("paneGap")
end

local function buildToolbar(frame)
	frame.toolbar=CreateFrame("Frame",nil,frame)
	frame.toolbar:SetPoint("TOPLEFT",frame.strip,"BOTTOMLEFT",0,-A.metric("paneGap"))
	frame.toolbar:SetPoint("TOPRIGHT",frame.strip,"BOTTOMRIGHT",0,-A.metric("paneGap"))
	frame.toolbar:SetHeight(A.notesToolbarHeight())
	local orderTop=-(A.metric("controlHeight")+A.metric("paneGap"))

	frame.searchBox=A.entry(frame.toolbar)
	frame.searchBox:SetHeight(A.metric("controlHeight"))
	frame.searchBox:SetPoint("TOPLEFT",frame.toolbar,"TOPLEFT",0,0)
	frame.searchBox:SetWidth(A.metric("playerSearch"))
	frame.searchBox:SetScript("OnTextChanged",function(self,userInput)
		if not userInput then
			return
		end
		local ok,text=pcall(self.GetText,self)
		searchText=(ok and type(text)=="string"and text~="")and text or nil
		requestedGuid=nil
		A.refreshNotes(true)
	end)
	frame.searchBox:SetScript("OnEscapePressed",function(self)
		pcall(self.ClearFocus,self)
		A.setNotesSearch(nil)
	end)
	A.entryPlaceholder(frame.searchBox,"name, realm, spec, tag or note")

	frame.sortTrack=A.segment(frame.toolbar,A.playerSorts(),function(value)
		A.setNotesSort(value)
	end)
	frame.sortTrack:SetPoint("TOPLEFT",frame.toolbar,"TOPLEFT",0,orderTop)

	frame.formatFilter=A.dropdown(frame.toolbar,A.playerFormatChoices(),function(value)
		A.setNotesFormat(value)
	end)
	frame.formatFilter:SetPoint("LEFT",frame.searchBox,"RIGHT",A.metric("pillGap"),0)
	frame.sideFilter=A.dropdown(frame.toolbar,A.playerSideChoices(),function(value)
		A.setNotesSide(value)
	end)
	frame.sideFilter:SetPoint("LEFT",frame.formatFilter,"RIGHT",A.metric("pillGap"),0)

	frame.repChip=A.pill(frame.toolbar,"",function()
		A.toggleNotesRep(repFilter)
	end)
	A.setControlTone(frame.repChip,"accent")
	frame.repChip:SetPoint("TOPRIGHT",frame.toolbar,"TOPRIGHT",0,orderTop)
	frame.repChip:Hide()
	frame.attitudeChip=A.pill(frame.toolbar,"",function()
		A.toggleNotesScale("attitude",attitudeFilter)
	end)
	A.setControlTone(frame.attitudeChip,"accent")
	frame.attitudeChip:Hide()

	frame.clearScope=A.pill(frame.toolbar,"Show all",function()
		A.clearNotesScope()
	end,A.metric("actionMin"))
	frame.clearScope:Hide()
end

local function paintToolbar()
	A.setSegmentChosen(window.sortTrack,A.playerSortSegment(sortWord)and sortWord or nil)
	local mark=type(A.storeMark)=="function"and A.storeMark()or nil
	local held=window.heldFormatChoices
	if not(held and mark and A.storeMarkSame(held.mark,mark))then
		held={mark=mark,choices=A.playerFormatChoices()}
		window.heldFormatChoices=held
	end
	A.setDropdownChoices(window.formatFilter,held.choices,formatFilter)
	A.setDropdownChoices(window.sideFilter,A.playerSideChoices(),sideFilter)

	window.clearScope:ClearAllPoints()
	local orderTop=-(A.metric("controlHeight")+A.metric("paneGap"))
	local leftmost=nil
	if repFilter~=nil then
		local label=(A.repLabel(repFilter~="none"and repFilter or nil))
		window.repChip:SetText(("%s  x"):format(label))
		A.fitControl(window.repChip,A.metric("tagMin"),A.metric("tagPad"))
		window.repChip:Show()
		leftmost=window.repChip
	else
		window.repChip:Hide()
	end
	if attitudeFilter~=nil then
		local label=(A.repLabel(attitudeFilter~="none"and attitudeFilter or nil,"attitude"))
		window.attitudeChip:SetText(("%s  x"):format(label))
		A.fitControl(window.attitudeChip,A.metric("tagMin"),A.metric("tagPad"))
		window.attitudeChip:ClearAllPoints()
		if leftmost then
			window.attitudeChip:SetPoint("RIGHT",leftmost,"LEFT",-A.metric("paneGap"),0)
		else
			window.attitudeChip:SetPoint("TOPRIGHT",window.toolbar,"TOPRIGHT",0,orderTop)
		end
		window.attitudeChip:Show()
		leftmost=window.attitudeChip
	else
		window.attitudeChip:Hide()
	end
	if leftmost then
		window.clearScope:SetPoint("RIGHT",leftmost,"LEFT",-A.metric("paneGap"),0)
	else
		window.clearScope:SetPoint("TOPRIGHT",window.toolbar,"TOPRIGHT",0,orderTop)
	end
	window.clearScope:SetShown(scopeMatchId~=nil or scopeTidy~=nil)
end

local function buildFaultPanel(frame)
	frame.fault=CreateFrame("Frame",nil,frame)
	frame.fault:SetPoint("TOPLEFT",frame.listHost,"TOPLEFT",0,0)
	frame.fault:SetPoint("BOTTOMRIGHT",frame.detailHost,"BOTTOMRIGHT",0,0)
	frame.fault:Hide()

	frame.fault:SetFrameLevel(frame:GetFrameLevel()+10)

	frame.faultTitle=frame.fault:CreateFontString(nil,"ARTWORK","GameFontDisableSmall")
	frame.faultTitle:SetPoint("TOPLEFT",frame.fault,"TOPLEFT",0,0)
	frame.faultTitle:SetPoint("TOPRIGHT",frame.fault,"TOPRIGHT",0,0)
	frame.faultTitle:SetJustifyH("LEFT")
	frame.faultTitle:SetWordWrap(false)

	frame.faultLine=frame.fault:CreateFontString(nil,"ARTWORK","GameFontHighlightSmall")
	frame.faultLine:SetPoint("TOPLEFT",frame.faultTitle,"BOTTOMLEFT",0,-A.metric("paneGap"))
	frame.faultLine:SetPoint("TOPRIGHT",frame.faultTitle,"BOTTOMRIGHT",0,-A.metric("paneGap"))
	frame.faultLine:SetJustifyH("LEFT")
	frame.faultLine:SetWordWrap(true)

	frame.faultCopy=A.pill(frame.fault,"Copy a report",nil,A.metric("actionMin"))
	frame.faultCopy:SetPoint("TOPLEFT",frame.faultLine,"BOTTOMLEFT",0,-A.metric("paneGap"))

	frame.faultCopyNote=frame.fault:CreateFontString(nil,"ARTWORK","GameFontDisableSmall")
	frame.faultCopyNote:SetPoint("LEFT",frame.faultCopy,"RIGHT",A.metric("paneGap"),0)
	frame.faultCopyNote:SetJustifyH("LEFT")
	frame.faultCopyNote:SetWordWrap(false)

	frame.faultCount=frame.fault:CreateFontString(nil,"ARTWORK","GameFontDisableSmall")
	frame.faultCount:SetPoint("TOPLEFT",frame.faultCopy,"BOTTOMLEFT",0,-A.metric("paneGap"))
	frame.faultCount:SetPoint("TOPRIGHT",frame.faultLine,"BOTTOMRIGHT",0,-A.metric("paneGap"))
	frame.faultCount:SetJustifyH("LEFT")
	frame.faultCount:SetWordWrap(false)
	frame.faultCount:Hide()
end

local function listHeaderHeight()
	return A.fontSize("label")+A.metric("headingPad")*2
end

local function buildListHeader(frame)
	frame.listHeader=CreateFrame("Frame",nil,frame.listHost)
	frame.listHeader:SetPoint("TOPLEFT",frame.listHost,"TOPLEFT",0,0)
	frame.listHeader:SetPoint("TOPRIGHT",frame.listHost,"TOPRIGHT",0,0)
	frame.listHeader:SetHeight(listHeaderHeight())
	frame.listHeader.rule=frame.listHeader:CreateTexture(nil,"ARTWORK")
	frame.listHeader.rule:SetPoint("BOTTOMLEFT",frame.listHeader,"BOTTOMLEFT",0,0)
	frame.listHeader.rule:SetPoint("BOTTOMRIGHT",frame.listHeader,"BOTTOMRIGHT",0,0)
	frame.listHeader.rule:SetHeight(1)
	local labels,names,keys={},{"PLAYER"},{"player"}
	frame.listHeader.labels=labels
	frame.listHeader.names=names
	frame.listHeader.keys=keys
	frame.listHeader.buttons={}
	local name=frame.listHeader:CreateFontString(nil,"ARTWORK","GameFontDisableSmall")
	name:SetPoint("LEFT",frame.listHeader,"LEFT",A.metric("playerLane")+A.metric("playerLaneGap"),0)
	name:SetWordWrap(false)
	labels[1]=name

	local function sortButton(key)
		local button=CreateFrame("Button",nil,frame.listHeader)
		button:SetHeight(listHeaderHeight())
		button:RegisterForClicks("LeftButtonUp")
		button.hover=button:CreateTexture(nil,"HIGHLIGHT")
		button.hover:SetAllPoints(button)
		button.sortKey=key
		button:SetScript("OnClick",function(self)
			A.clickNotesHeader(self.sortKey)
		end)
		frame.listHeader.buttons[#frame.listHeader.buttons+1]=button
		return button
	end

	local edges=figureEdges()
	local columns=figureColumns()
	local player=sortButton("player")
	player:SetPoint("LEFT",frame.listHeader,"LEFT",0,0)
	player:SetPoint("RIGHT",frame.listHeader,"RIGHT",-(edges[1]+columns[1].width),0)
	for i,column in ipairs(columns)do
		local label=frame.listHeader:CreateFontString(nil,"ARTWORK","GameFontDisableSmall")
		label:SetPoint("RIGHT",frame.listHeader,"RIGHT",-edges[i],0)
		label:SetWidth(column.width)
		label:SetJustifyH(column.justify)
		label:SetWordWrap(false)
		labels[#labels+1]=label
		names[#names+1]=column.name
		keys[#keys+1]=column.key
		local button=sortButton(column.key)
		button:SetPoint("RIGHT",frame.listHeader,"RIGHT",-edges[i],0)
		button:SetWidth(column.width)
	end
end

local function buildDossier(frame)
	frame.dossier=CreateFrame("Frame",nil,frame.detailHost)
	frame.dossier:SetPoint("TOPLEFT",frame.detailHost,"TOPLEFT",0,0)
	frame.dossier:SetPoint("TOPRIGHT",frame.detailHost,"TOPRIGHT",0,0)
	frame.dossier:SetHeight(A.notesPaneStack(1))

	frame.dossierEmpty=frame.detailHost:CreateFontString(nil,"ARTWORK","GameFontHighlightSmall")
	frame.dossierEmpty:SetPoint("TOPLEFT",frame.detailHost,"TOPLEFT",0,0)
	frame.dossierEmpty:SetPoint("TOPRIGHT",frame.detailHost,"TOPRIGHT",0,0)
	frame.dossierEmpty:SetJustifyH("LEFT")
	frame.dossierEmpty:SetWordWrap(true)
	frame.dossierEmpty:Hide()

	frame.openWindow=A.pill(frame.dossier,"Open window",function()
		if selectedGuid~=nil and type(A.openPlayer)=="function"then
			A.openPlayer(selectedGuid,false,"players")
		end
	end,A.metric("actionMin"))
	frame.openWindow:SetPoint("TOPRIGHT",frame.dossier,"TOPRIGHT",0,0)
	frame.murlok=A.pill(frame.dossier,"murlok.io",function()
		if frame.murlokText then
			A.showCopyBox(frame,"murlok.io","Ctrl+C copies the address; paste it into a browser.",
				frame.murlokText)
		end
	end,A.metric("actionMin"))
	frame.copyName=A.pill(frame.dossier,"Copy name",function()
		if frame.copyText then
			A.showCopyBox(frame,"Copy name","Ctrl+C copies the name.",frame.copyText)
		end
	end,A.metric("actionMin"))
	frame.undoPill=A.buildUndoPill(frame.dossier)

	frame.dossierIcon=frame.dossier:CreateTexture(nil,"ARTWORK")
	frame.dossierIcon:SetPoint("TOPLEFT",frame.dossier,"TOPLEFT",0,0)
	frame.dossierIcon:Hide()

	frame.dossierName=frame.dossier:CreateFontString(nil,"ARTWORK","GameFontNormalLarge")
	frame.dossierName:SetPoint("TOPLEFT",frame.dossier,"TOPLEFT",
		A.fontSize("dossierName")+A.metric("chipGap"),0)
	frame.dossierName:SetJustifyH("LEFT")
	frame.dossierName:SetWordWrap(false)
	frame.dossierSub=frame.dossier:CreateFontString(nil,"ARTWORK","GameFontDisableSmall")
	frame.dossierSub:SetPoint("TOPLEFT",frame.dossierName,"BOTTOMLEFT",0,-2)
	frame.dossierSub:SetJustifyH("LEFT")
	frame.dossierSub:SetWordWrap(false)

	frame.rep=A.buildRepControl(frame.dossier,repPicked,"skill")
	frame.rep:SetPoint("TOPLEFT",frame.dossierSub,"BOTTOMLEFT",
		-(A.fontSize("dossierName")+A.metric("chipGap")),-A.metric("paneGap"))
	frame.rep:SetPoint("RIGHT",frame.dossier,"RIGHT",0,0)

	frame.attitude=A.buildRepControl(frame.dossier,attitudePicked,"attitude")
	frame.attitude:SetPoint("TOPLEFT",frame.rep,"BOTTOMLEFT",0,-A.metric("paneGap"))
	frame.attitude:SetPoint("RIGHT",frame.dossier,"RIGHT",0,0)

	frame.cards=A.buildSideCards(frame.dossier)
	frame.cards:SetPoint("TOPLEFT",frame.attitude,"BOTTOMLEFT",0,-A.metric("paneGap"))
	frame.cards:SetPoint("RIGHT",frame.dossier,"RIGHT",0,0)

	frame.noteRow=A.buildNoteRow(frame.dossier)
	frame.noteRow:SetPoint("TOPLEFT",frame.cards,"BOTTOMLEFT",0,-A.metric("paneGap"))
	frame.noteRow:SetPoint("RIGHT",frame.dossier,"RIGHT",0,0)
	local box=frame.noteRow.box
	box:SetMaxLetters(A.PLAYER_NOTE_MAX)
	A.entryPlaceholder(box,"note on this player, Enter saves")
	box:SetScript("OnEnterPressed",commitNote)
	box:HookScript("OnTextChanged",function(self)
		local ok,held=pcall(self.GetText,self)
		frame.noteRow.count:SetText(A.noteCountText(ok and held or nil,A.PLAYER_NOTE_MAX)or"")
	end)
	box:SetScript("OnEscapePressed",function(self)
		pcall(self.ClearFocus,self)
		A.discardTypedNote(self,frame)
		A.refreshNotes()
	end)

	frame.tagRow=A.buildTagRow(frame.dossier,tagClicked,suggestClicked,commitTags,templateClicked)
	frame.tagRow:SetPoint("TOPLEFT",frame.noteRow,"BOTTOMLEFT",0,-A.metric("paneGap"))
	frame.tagRow:SetPoint("RIGHT",frame.dossier,"RIGHT",0,0)
	frame.tagRow.box:HookScript("OnTextChanged",function(_,userInput)
		if userInput then
			A.containedPaint("notes/tag-suggestions",paintTagSuggestions)
		end
	end)
end

function A.notesListSplit()
	return A.metric("notesListWidth")
end

function A.notesFrameWidth()
	if window then
		local ok,width=pcall(window.GetWidth,window)
		if ok and type(width)=="number"and width>0 then
			return width
		end
	end
	local authored=type(A.authoredGeometry)=="function"and A.authoredGeometry("players")or nil
	if type(authored)=="number"then
		return authored
	end
	return(A.notesWindowFloor())
end

function A.notesPaneSplit(width)
	if type(width)~="number"or width<=0 then
		width=A.notesFrameWidth()
	end
	return width-A.metric("margin")*2-A.metric("paneRightPad")
		-A.metric("paneSplitGap")-A.notesListSplit()
end

function A.notesPaneFloor()
	local widest=0
	local function take(value)
		if type(value)=="number"and value>widest then
			widest=value
		end
	end
	take(A.repControlFloor())
	take(A.metric("actionMin")*3+A.metric("pillGap")*2+A.metric("paneGap")
		+A.headerFloor("XXXXXXXXXXXX"))
	take(3*(A.headerFloor("AGAINST YOU")+A.metric("sideCardPad")*2+2)+2*A.metric("sideCardGap"))
	take(A.metric("tagMin")+A.metric("pillGap")+A.metric("tagBoxMin"))
	return widest
end

function A.notesPaneStack(tagRows)
	local rows=type(tagRows)=="number"and tagRows or 1
	if rows<1 then
		rows=1
	end
	local gap=A.metric("paneGap")
	return A.fontSize("dossierName")+2+A.fontSize("note")
		+gap+A.metric("controlHeight")
		+gap+A.metric("controlHeight")
		+gap+A.sideCardHeight()
		+gap+A.metric("controlHeight")
		+gap+rows*A.metric("tagRow")
end

local function topFloor()
	local strip=A.metric("standPad")*2+A.metric("standLead")+A.metric("paneGap")*3
		+3*(A.metric("standTile")+A.metric("paneGap")*2)
	local paneGap=A.metric("paneGap")
	strip=strip+legendNeed()+paneGap*3+A.headerFloor(stripLabel("attitude"))
	local search=A.metric("playerSearch")+2*(A.metric("pillGap")+A.metric("dropdownWidth"))
	local sorts=0
	local segmentMin,segmentGap=A.metric("segmentMin"),A.metric("segmentGap")
	for _,sort in ipairs(A.playerSorts())do
		sorts=sorts+math.max(segmentMin,A.headerFloor(sort.label))+segmentGap
	end
	local chip=A.headerFloor(("W"):rep(math.max(A.STEP_WORD_MAX,#"Not rated")).."  x")+A.metric("tagPad")
	local order=sorts+paneGap+A.metric("actionMin")+paneGap+chip+paneGap+chip
	return math.max(strip,search,order)+A.metric("margin")*2
end

function A.notesWindowFloor()
	local above=A.metric("headerHeight")+A.playersStripHeight()+A.metric("paneGap")
		+A.notesToolbarHeight()+A.notesRosterBandHeight()+A.metric("paneGap")

	local rows=listHeaderHeight()+A.metric("playerSection")+A.metric("playerRow")*4
	local stack=A.notesPaneStack(1)
	local height=above+(rows>stack and rows or stack)+A.metric("paneGap")+A.bodyFloor()

	local width=A.metric("margin")*2+A.metric("paneRightPad")+A.metric("paneSplitGap")
		+A.notesListSplit()+A.notesPaneFloor()
	local top=topFloor()
	if top>width then
		width=top
	end
	return width,height
end

local function buildWindow()
	local frame=CreateFrame("Frame",FRAME_NAME,UIParent,"BasicFrameTemplateWithInset")
	local width,height,point,x,y
	if type(A.authoredGeometry)=="function"then
		width,height,point,x,y=A.authoredGeometry("players")
	end
	if type(width)~="number"then
		width,height=A.notesWindowFloor()
		point,x,y="CENTER",0,0
	end
	frame:SetSize(width,height)
	frame:SetPoint(point,UIParent,point,x,y)
	A.standMovableWindow(frame)
	frame:SetScript("OnDragStop",function(self)
		A.stopDrag(self)
		if type(A.rememberWindow)=="function"then
			pcall(A.rememberWindow,"players")
		end
	end)
	frame:Hide()

	A.registerChrome(frame)

	A.placeWindowHeading(frame)

	buildStrip(frame)
	buildToolbar(frame)
	buildRosterBand(frame)

	frame.listHost=CreateFrame("Frame",nil,frame)
	frame.listHost:SetPoint("TOPLEFT",frame.rosterBand,"BOTTOMLEFT",0,-A.metric("paneGap"))
	frame.listHost:SetPoint("BOTTOMLEFT",frame,"BOTTOMLEFT",A.metric("margin"),A.bodyFloor())
	frame.listHost:SetWidth(A.notesListSplit())

	frame.detailHost=CreateFrame("Frame",nil,frame)
	frame.detailHost:SetPoint("TOPLEFT",frame.listHost,"TOPRIGHT",A.metric("paneSplitGap"),0)
	frame.detailHost:SetPoint("BOTTOMRIGHT",frame,"BOTTOMRIGHT",
		-A.metric("margin")-A.metric("paneRightPad"),A.bodyFloor())

	window=frame

	buildListHeader(frame)
	frame.list=A.buildScroller(FRAME_NAME.."List",frame.listHost,"Button",initRow,rowExtent,
		"the player list")
	frame.list.box:SetPoint("TOPLEFT",frame.listHeader,"BOTTOMLEFT",0,0)
	frame.list.box:SetPoint("BOTTOMRIGHT",frame.listHost,"BOTTOMRIGHT",0,0)
	frame.list.bar:SetPoint("TOPLEFT",frame.listHeader,"BOTTOMRIGHT",4,0)
	frame.list.bar:SetPoint("BOTTOMLEFT",frame.listHost,"BOTTOMRIGHT",4,0)

	buildDossier(frame)

	buildFaultPanel(frame)

	frame.footName=frame:CreateFontString(nil,"ARTWORK","GameFontDisableSmall")
	frame.footName:SetPoint("BOTTOMLEFT",frame,"BOTTOMLEFT",A.metric("margin"),A.metric("margin"))
	frame.footName:SetJustifyH("LEFT")
	frame.footName:SetWordWrap(false)
	frame.footState=frame:CreateFontString(nil,"ARTWORK","GameFontDisableSmall")
	frame.footState:SetPoint("BOTTOMRIGHT",frame,"BOTTOMRIGHT",-A.metric("margin"),A.metric("margin"))
	frame.footState:SetJustifyH("RIGHT")
	frame.footState:SetWordWrap(false)

	A.closeOnEscape(FRAME_NAME)

	frame.halfTabs=A.halfTabs(frame,"players")

	frame:HookScript("OnHide",function()
		if type(A.mainWindowHidden)=="function"then
			A.mainWindowHidden("players")
		end
	end)

	if type(A.attachResize)=="function"then
		pcall(A.attachResize,frame,"players",function()
			A.refreshNotes()
		end)
	end

	return frame
end

if type(A.registerWindowKind)=="function"then
	A.registerWindowKind("players",{
		label="players",
		authored=A.notesWindowFloor,
		floor=A.notesWindowFloor,
		shares="matches",
	})
end

local function windowOrNil()
	if window then
		return window
	end
	if not surface()then
		return nil
	end
	local built=A.buildWindowOnce("players",buildWindow)
	if not built then
		window=nil
		return nil
	end
	window=built
	return window
end

local function viewState(index)
	local held=window and window.heldStoreReadings or nil
	local mark=type(A.storeMark)=="function"and A.storeMark()or nil
	if not(held and mark and A.storeMarkSame(held.mark,mark))then
		local sessionIds,session=A.newestSession()
		held={mark=mark,sessionIds=sessionIds,session=session,recorders=A.recorderSet()}
		if window then
			window.heldStoreReadings=held
		end
	end
	return{
		sessionIds=held.sessionIds,
		session=held.session,
		recorders=held.recorders,
		index=index,
		scope=scopeMatchId,
		tidy=scopeTidy,
		text=searchText,
		format=formatFilter,
		side=sideFilter,
		rep=repFilter,
		attitude=attitudeFilter,
		sort=sortWord,
		dir=sortDir,
		now=time(),
	}
end

local function orderValue(sort,row)
	if type(row)~="table"then
		return nil
	end
	if sort=="record"or sort=="with"or sort=="against"then
		local rank=row[sort.."Rank"]
		return rank and rank.diff or"-"
	end
	if sort=="met"then
		return row.met
	end
	if sort=="trend"then
		return row.trend and row.trend.change or"-"
	end
	if sort=="player"then
		local folded=A.foldText(tostring(row.identity and row.identity.bare or""))
		return folded:match("^[%z\1-\127\194-\244][\128-\191]*")
	end
	return nil
end

local function drawnRows(view)
	local rows,selected={},nil
	for s=1,#view.sections do
		local section=view.sections[s]
		rows[#rows+1]={section=section.label,
			count=("%s %s"):format(A.groupedCount(section.count),section.count==1 and"player"or"players")}
		for i=1,#section.rows do
			local item=section.rows[i]
			rows[#rows+1]={row=item,guid=item.guid}
			if item.guid==selectedGuid then
				selected=item
			end
		end
	end
	local shared=A.sharedBareNames(rows,function(data)
		return data.row and data.row.identity and data.row.identity.full or nil
	end)
	for i=1,#rows do
		local identity=rows[i].row and rows[i].row.identity
		rows[i].realmKept=identity~=nil and shared[identity.bare or""]or nil
	end
	return rows,selected
end

local function clearNarrowings()
	local cleared=0
	if searchText~=nil then
		cleared=cleared+1
		searchText=nil
		if window and window.searchBox then
			pcall(window.searchBox.SetText,window.searchBox,"")
		end
	end
	if repFilter~=nil then
		cleared=cleared+1
		repFilter=nil
	end
	if attitudeFilter~=nil then
		cleared=cleared+1
		attitudeFilter=nil
	end
	if formatFilter~=nil then
		cleared=cleared+1
		formatFilter=nil
	end
	if sideFilter~=nil then
		cleared=cleared+1
		sideFilter=nil
	end
	if scopeMatchId~=nil or scopeTidy~=nil then
		cleared=cleared+1
		scopeMatchId=nil
		scopeTidy=nil
	end
	return cleared
end

local function listRows(index)
	local view=A.playersView(viewState(index))
	local rows,selected=drawnRows(view)

	local requested=selectedGuid~=nil and requestedGuid==selectedGuid
	if not selected and requested and pendingReveal==selectedGuid then
		local cleared=clearNarrowings()
		if cleared>0 then
			view=A.playersView(viewState(index))
			rows,selected=drawnRows(view)
		end
		pcall(A.trace,"notesasked",{cleared=cleared,hidden=selected==nil},"ui")
	end

	if not selected then
		local entry,stored=nil,false
		if selectedGuid~=nil then
			entry,stored=A.playerEntry(selectedGuid)
		end
		if entry and(not stored or requested)then
			selected={guid=entry.guid,entry=entry.entry}
		else
			selected=nil
			for i=1,#rows do
				if rows[i].guid~=nil then
					selected=rows[i].row
					break
				end
			end
			setSelected(selected and selected.guid or nil)
		end
	end

	return rows,selected,view
end

local function repPhrase(rep,scale)
	if rep==nil then
		return nil
	end
	if rep=="none"then
		return scale.." not rated"
	end
	return("%s %s"):format(scale,tostring(A.ratingText(rep,scale)))
end

local drawnEmpty=nil

local function anyPlayer()
	local db=A.db()
	if not db then
		return false
	end
	for _,entry in pairs(type(db.players)=="table"and db.players or{})do
		if type(entry)=="table"then
			return true
		end
	end
	for _,note in pairs(type(db.notes)=="table"and db.notes or{})do
		if type(note)=="table"then
			return true
		end
	end
	return false
end

local function emptyText()
	local scoped=scopeMatchId and A.match(scopeMatchId)
	if scopeMatchId and not scoped then
		return("Match #%s is not in your history."):format(tostring(scopeMatchId)),"gone"
	end
	local filters={}
	if repFilter~=nil then
		filters[#filters+1]=repPhrase(repFilter,"skill")
	end
	if attitudeFilter~=nil then
		filters[#filters+1]=repPhrase(attitudeFilter,"attitude")
	end
	if formatFilter~=nil then
		filters[#filters+1]=("met in %s"):format(A.formatLabel(formatFilter))
	end
	if sideFilter~=nil then
		filters[#filters+1]=sideFilter=="with"and"met on your side"or"met against you"
	end
	if searchText then
		filters[#filters+1]=("matches %q"):format(searchText)
	end
	if scopeMatchId then
		local roster=#A.rosterPlayers(scoped)
		if#filters==0 then
			return("No player in match #%s besides you."):format(tostring(scopeMatchId)),"roster"
		end
		return("No player in match #%s %s. %s."):format(tostring(scopeMatchId),
			tostring(A.joinAnd(filters)),roster==1 and"1 player is in it"
			or("%d players are in it"):format(roster)),"scoped"
	end
	if scopeTidy then
		if#filters==0 then
			return"No player met once, over a year ago, with nothing written.","tidy"
		end
		return("No player a tidy would drop %s."):format(tostring(A.joinAnd(filters))),"tidy"
	end
	if not anyPlayer()then
		return"No players yet.","nobody"
	end
	if#filters>0 then
		return("No listed player %s."):format(tostring(A.joinAnd(filters))),"filtered"
	end
	return"No player selected.","unselected"
end

function A.paneFaultText(refused,shown,unreached,noRoom)
	local named=A.joinAnd(refused)
	local silent=A.joinAnd(unreached)
	local cramped={}
	if type(noRoom)=="table"then
		for i=1,#noRoom do
			local subject=type(noRoom[i])=="string"and noRoom[i]:match("^%s*(.-)%s*$")or""
			if subject~=""then
				cramped[#cramped+1]=subject
			end
		end
	end
	if named==nil and silent==nil and#cramped==0 then
		return nil
	end
	local count=nil
	if type(shown)=="number"then
		count=shown==1 and"1 player was being shown"
			or("%d players were being shown"):format(shown)
	end
	local parts,subjects={},{}
	local function say(subject,branch,sentence)
		parts[#parts+1]=sentence
		subjects[#subjects+1]={subject=subject,branch=branch,sentence=sentence}
	end
	if named~=nil then
		say(named,"refused",("Something went wrong drawing %s."):format(named))
	end
	if silent~=nil then
		say(silent,"unreached",
			("Something failed before %s was handed anything."):format(silent))
	end
	for i=1,#cramped do
		say(cramped[i],"no room",
			("%s has no room to draw in."):format((cramped[i]:gsub("^%l",string.upper))))
	end
	parts[#parts+1]="/pvph error"
	return{
		title="PLAYERS DID NOT DRAW",
		lines=parts,
		line=table.concat(parts,"\n"),
		subjects=subjects,
		count=count,
	}
end

local heldFault=nil

local function standFaultPanel(said)
	if not window or not window.fault or type(said)~="table"then
		return false
	end

	A.style(window.faultTitle,"section","fault")
	window.faultTitle:SetText(said.title)

	A.style(window.faultLine,"bodyText")
	local sentences={}
	local subjects=type(said.subjects)=="table"and said.subjects or{}
	for i=1,#subjects do
		sentences[i]=subjects[i].sentence
	end
	window.faultLine:SetText(table.concat(sentences,"\n"))

	A.style(window.faultCopyNote,"note","dim")
	window.faultCopyNote:SetText("/pvph error says the same in chat")
	window.faultCopy:SetScript("OnClick",function()
		local ok,text=pcall(A.faultReport)
		if not ok or type(text)~="string"then
			A.say("the report did not compose, so there is nothing to copy")
			return
		end
		if type(A.showCsvSheet)~="function"
			or not A.showCsvSheet(("Report: %s"):format(tostring(said.title):lower()),
				"Ctrl-C copies. Escape closes.",text)then
			A.say("the report window did not open. /pvph error says the same in chat")
		end
	end)
	window.faultCopy:Show()

	if said.count then
		A.style(window.faultCount,"note","dim")
		window.faultCount:SetText(said.count)
		window.faultCount:Show()
	else
		window.faultCount:Hide()
	end

	window.fault:Show()
	if not window.fault:IsShown()then
		return false
	end

	window.listHost:Hide()
	window.detailHost:Hide()
	heldFault=said
	return true
end

local function lastNotesPaint()
	if type(A.debugEntries)~="function"then
		return nil
	end
	local ok,entries=pcall(A.debugEntries)
	if not ok or type(entries)~="table"then
		return nil
	end
	for i=#entries,1,-1 do
		local held=entries[i]
		if type(held)=="table"and held.cat=="ui"and held.ev=="paint"
			and held.source=="notes"then
			return held
		end
	end
	return nil
end

local function namesFolder(message,folder)
	local from=1
	while true do
		local _,last=message:find(folder,from,true)
		if not last then
			return false
		end
		local after=message:sub(last+1,last+1)
		if after=="/"or after=="\\"or after=="'"then
			return true
		end
		from=last+1
	end
end

local function grabbedError()
	if type(BugGrabber)~="table"or type(BugGrabber.GetDB)~="function"then
		return nil
	end
	local ok,db=pcall(BugGrabber.GetDB,BugGrabber)
	if not ok or type(db)~="table"then
		return nil
	end
	for i=#db,1,-1 do
		local held=db[i]
		local message=type(held)=="table"and type(held.message)=="string"and held.message
		if message and namesFolder(message,"WowPvpHistoryProbe")then
			return message,"probe"
		elseif message and namesFolder(message,"WowPvpHistory")then
			return message,"addon"
		end
	end
	return nil
end

function A.faultReport()
	if type(heldFault)~="table"then
		return nil
	end
	local out={}
	local function line(text)
		out[#out+1]=text
	end

	local version,build
	local okBuild,one,two=pcall(GetBuildInfo)
	if okBuild then
		version,build=one,two
	end
	line(("%s %s on %s at %s"):format(A.displayName(),
		tostring(A.version),
		(version and build)and(version.."."..build)or tostring(build),
		tostring(select(2,pcall(A.stamp)))))

	local ringOn=type(A.debugEnabled)=="function"and A.debugEnabled()
	line("")
	local painted=lastNotesPaint()
	if type(painted)=="table"then
		line(("the last paint: %s players over %s rows, list %s, detail %s, dossier %s, panel %s")
			:format(tostring(painted.n),tostring(painted.rows),tostring(painted.list),
				tostring(painted.met),tostring(painted.dossier),tostring(painted.panel)))
		line(("  the list host: %s wide, %s high, shown %s")
			:format(tostring(painted.listW),tostring(painted.listH),tostring(painted.listUp)))
		line(("  the detail host: %s wide, %s high, shown %s")
			:format(tostring(painted.metW),tostring(painted.metH),tostring(painted.metUp)))
		line(("  the roster band: %s high, shown %s")
			:format(tostring(painted.bandH),tostring(painted.bandUp)))
	elseif not ringOn then
		line("the last paint: the debug ring is off, so no paint was recorded")
	else
		line("the last paint: no paint entry is in the ring, so what the paint saw is unrecorded")
	end

	line("")
	line(tostring(heldFault.title))
	local subjects=type(heldFault.subjects)=="table"and heldFault.subjects or{}
	for i=1,#subjects do
		line(("  %s: %s, %s"):format(tostring(subjects[i].branch),
			tostring(subjects[i].subject),tostring(subjects[i].sentence)))
	end
	if heldFault.count then
		line("  "..tostring(heldFault.count))
	end

	line("")
	local grabbed,whose=grabbedError()
	if grabbed then
		line(("the grabber's last capture, %s:"):format(
			whose=="probe"and"the probe's"or"the addon's"))
		line("  "..grabbed)
	else
		line("the grabber's last capture: none this session naming this addon or the probe")
	end
	local stored=A.savedDB and A.lastErrorLines and A.lastErrorLines(A.savedDB())
	if type(stored)=="table"then
		for i=1,#stored do
			line("  "..tostring(stored[i]))
		end
	else
		line("the addon's own error ring: nothing has thrown, or the last one was cleared")
	end

	line("")
	line("the last ten ui entries, newest last:")
	local held=type(A.debugLines)=="function"and A.debugLines(10,"ui")or{}
	if#held==0 and not ringOn then
		line("  the debug ring is off, so nothing was recorded")
	elseif#held==0 then
		line("  the ui ring is empty")
	end
	for i=1,#held do
		line("  "..tostring(held[i]))
	end

	return table.concat(out,"\n")
end

local function paintFaultPanel(listTook,detailDrew,shown,noRoom)
	if not window or not window.fault then
		return false
	end

	local refused,unreached={},{}
	local listName=listSubject()
	if listTook==false then
		refused[#refused+1]=listName
	elseif listTook==nil then
		unreached[#unreached+1]=listName
	end
	if detailDrew==nil then
		unreached[#unreached+1]=DETAIL_SUBJECT
	end

	local said=A.paneFaultText(refused,shown,unreached,noRoom)
	if not said then
		window.fault:Hide()
		window.listHost:Show()
		window.detailHost:Show()
		heldFault=nil
		return false
	end

	return standFaultPanel(said)
end

function A.stageNotesFault()
	local okShown,shown=pcall(function()
		return window~=nil and window:IsShown()
	end)
	if not(okShown and shown)then
		return false,"the players window is not open. /pvph notes first"
	end
	if stagedFault then
		stagedFault=false
		A.refreshNotes()
		return false,"the staged fault panel is down and the panes are back"
	end

	local said=A.paneFaultText({listSubject()},nil,{DETAIL_SUBJECT},{DETAIL_SUBJECT})
	if not said then
		return false,"the fault panel composed nothing, so it was not staged"
	end
	said.count="Staged by /pvph debug fault. Nothing has failed."

	local ok,stood=pcall(standFaultPanel,said)
	if not ok then
		return false,("the fault panel did not stand: %s"):format(tostring(stood))
	end
	if not stood then
		return false,"the fault panel did not stand, and the panes are where they were"
	end
	stagedFault=true
	return true,"the fault panel is staged over the players window. /pvph debug fault again, or any "
		.."repaint, takes it down"
end

local function hostRead(host,method)
	if not(host and type(host[method])=="function")then
		return nil
	end
	local ok,value=pcall(host[method],host)
	if not ok then
		return nil
	end
	if type(value)=="number"then
		return A.unitFigure(value)
	end
	if type(value)=="boolean"then
		return value
	end
	return nil
end

function A.sideReading(parts)
	local pieces=A.sideShort(parts)
	if not pieces then
		return nil
	end
	local units={}
	for i=1,#parts do
		units[i]=parts[i].unit
	end
	return("%s (%s)"):format(A.sideShortText(pieces),table.concat(units,"+"))
end

local function paintDossier(selected,index)
	drawnEmpty=nil
	if not selected then
		window.dossier:Hide()
		A.style(window.dossierEmpty,"bodyText","dim")
		local empty,word=emptyText()
		window.dossierEmpty:SetText(empty)
		window.dossierEmpty:Show()
		drawnEmpty=word
		window.noteRow.box:SetEnabled(false)
		window.tagRow.box:SetEnabled(false)
		return nil
	end

	window.dossierEmpty:Hide()
	window.dossier:Show()
	window.noteRow.box:SetEnabled(true)
	window.tagRow.box:SetEnabled(true)

	local dossier=A.playerDossier(selected.guid,index)
	if not dossier then
		window.dossier:Hide()
		return nil
	end
	local identity=dossier.identity
	local pane=A.notesPaneSplit()

	window.copyText,window.murlokText=A.playerCopyTexts(selected.guid,dossier.entry)
	local edge=window.openWindow
	local pillGap=A.metric("pillGap")
	for _,pair in ipairs({{window.murlok,window.murlokText},{window.copyName,window.copyText},
		{window.undoPill,A.undoPending(selected.guid)or nil}})do
		local button,text=pair[1],pair[2]
		button:ClearAllPoints()
		if text then
			button:SetPoint("TOPRIGHT",edge,"TOPLEFT",-pillGap,0)
			button:Show()
			edge=button
		else
			button:Hide()
		end
	end
	local paneGap=A.metric("paneGap")
	for _,line in ipairs({window.dossierName,window.dossierSub})do
		line:SetPoint("RIGHT",edge,"LEFT",-paneGap,0)
	end

	local iconKind=A.drawSpec({icon=window.dossierIcon},identity.classToken,identity.spec,nil,
		{size=A.fontSize("dossierName")})
	A.trace("playerhead",{headIcon=iconKind=="icon"and"spec"or iconKind=="square"and"class"or"none"},
		"ui")
	A.style(window.dossierName,"dossierName")
	window.dossierName:SetTextColor(A.classColor(identity.classToken))
	A.fitNameHead(window.dossierName,identity.bare or A.UNKNOWN_PLAYER,identity.realm,"dim")
	A.style(window.dossierSub,"bodyText","dim")
	local sub=dossier.specLine or"no spec recorded"
	if type(A.debugTextEnabled)=="function"and A.debugTextEnabled()then
		sub=sub.."  "..A.colorEscape("faint")..tostring(selected.guid).."|r"
	end
	window.dossierSub:SetText(sub)

	A.paintRepControl(window.rep,dossier.rating,pane,true)
	A.paintRepControl(window.attitude,dossier.attitude,pane,true)
	A.paintSideCards(window.cards,dossier,pane)

	local note=dossier.note
	local shown,typed=A.paintNoteBox(window.noteRow.box,window,selected.guid,note and note.text)
	A.paintNoteRow(window.noteRow,shown)

	standTagRow(note,pane)

	dossier.typed=typed
	return dossier
end

function A.dropNotesIndex()
	if window then
		window.heldIndex=nil
	end
end

local function paintIndex()
	local mark=type(A.storeMark)=="function"and A.storeMark()or nil
	local held=window.heldIndex
	if held and mark and A.storeMarkSame(held.mark,mark)then
		return held.index
	end
	local built,made=pcall(A.encounterIndex)
	local index=built and type(made)=="table"and made or nil
	window.heldIndex=index and mark and{mark=mark,index=index}or nil
	return index
end

function A.refreshNotes(searchOnly)
	local index=nil
	if window then
		index=paintIndex()
	end

	if not searchOnly and type(A.refreshPlayerWindows)=="function"then
		A.containedPaint("notes/player-windows",A.refreshPlayerWindows,index)
	end
	if not window or not(paintingToShow or A.notesWindowShown())then
		return false
	end

	local rows,selected,view=listRows(index)
	lastRows=view.shown

	A.containedPaint("notes/roster-band",paintRosterBand)

	stagedFault=false

	local stripOk,stripErr=pcall(paintStrip,view)
	if not stripOk then
		A.noteError(("the players strip did not paint: %s"):format(tostring(stripErr)),"notes/strip")
	end
	local stripDrew=(stripOk and type(stripErr)=="table")and stripErr or{}
	A.containedPaint("notes/toolbar",paintToolbar)

	local sortColumn=(view.sort=="with"or view.sort=="against")and"record"or view.sort
	A.containedPaint("notes/list-header",function()
		window.listHeader.rule:SetColorTexture(A.color("hairline"))
		for i,label in ipairs(window.listHeader.labels)do
			A.style(label,"label",window.listHeader.keys[i]==sortColumn and"accent"or"dimmer")
			label:SetText(window.listHeader.names[i]or"")
		end
		local hoverR,hoverG,hoverB,hoverA=A.color("hover")
		for _,button in ipairs(window.listHeader.buttons)do
			button.hover:SetColorTexture(hoverR,hoverG,hoverB,hoverA)
		end
	end)

	local order=view.sort..(view.dir and("/"..view.dir)or"")
	if order~=tracedOrder then
		tracedOrder=order
		pcall(A.trace,"notessort",{
			sort=view.sort,
			sortDir=view.dir,
			n=view.shown,
			topValue=orderValue(view.sort,view.rows[1]),
			bottomValue=orderValue(view.sort,view.rows[#view.rows]),
		},"ui")
	end

	local listTook=A.setRows(window.list,rows)

	if pendingReveal~=nil then
		local at=nil
		for i=1,#rows do
			if rows[i].guid==pendingReveal then
				at=i
				break
			end
		end
		pendingReveal=nil
		if at then
			pcall(function()
				window.list.box:ScrollToElementDataIndex(at,0.5)
			end)
		end
	end

	local dossierOk,dossier=pcall(paintDossier,selected,index)
	local detailDrew=dossierOk or nil
	if not dossierOk then
		A.noteError(("the player dossier did not paint: %s"):format(tostring(dossier)),"notes/dossier")
		dossier=nil
	end

	local noRoom={}
	local function cramped(host,took,name,source)
		if took~=true or hostRead(host,"IsShown")~=true then
			return
		end
		local height=hostRead(host,"GetHeight")
		if type(height)=="number"and height<A.metric("rowHeight")then
			noRoom[#noRoom+1]=name
			A.noteError(("%s has no room to draw in: %s wide and %s high"):format(name,
				tostring(hostRead(host,"GetWidth")),tostring(height)),source)
		end
	end
	cramped(window.listHost,listTook,listSubject(),"notes/list")
	cramped(window.detailHost,detailDrew,DETAIL_SUBJECT,"notes/detail")

	local panelOk,panel=pcall(paintFaultPanel,listTook,detailDrew,view.shown,noRoom)
	if not panelOk then
		A.noteError(("the fault panel did not stand: %s"):format(tostring(panel)),"notes/panel")
		panel=false
	end

	local trendRows=0
	for i=1,#view.rows do
		if view.rows[i].trend~=nil then
			trendRows=trendRows+1
		end
	end
	local selectedIds=nil
	if dossier and type(dossier.record)=="table"and type(dossier.record.ids)=="table"then
		local held,ids=dossier.record.ids,{}
		for i=1,#held do
			ids[i]=tostring(held[i])
		end
		selectedIds=table.concat(ids,",")
	end
	pcall(A.trace,"paint",{
		source="notes",
		n=view.shown,
		rows=#rows,
		listTook=listTook,
		met=detailDrew,
		dossier=dossierOk,
		panel=panel,
		sort=sortWord,
		sortDir=sortDir,
		repStep=repFilter~=nil and tostring(repFilter)or nil,
		attitudeStep=attitudeFilter~=nil and tostring(attitudeFilter)or nil,
		fmt=formatFilter,
		sideFilter=sideFilter,
		players=view.strip.players,
		unmet=view.strip.unmet,
		trendRows=trendRows,
		sections=#view.sections,
		tileForms=stripDrew.tileForms,
		lead=stripDrew.lead,
		ratedPlayers=view.strip.rated,
		unratedPlayers=view.strip.notRated,
		attitudeRatedPlayers=view.strip.attitudeRated,
		attitudeUnratedPlayers=view.strip.attitudeNotRated,
		repBars=stripDrew.repBars,
		attitudeBars=stripDrew.attitudeBars,
		search=searchText~=nil or nil,
		empty=view.shown==0 and drawnEmpty or nil,
		with=dossier and A.sideReading(dossier.with)or nil,
		against=dossier and A.sideReading(dossier.against)or nil,
		ids=selectedIds,
		listUp=hostRead(window.listHost,"IsShown"),
		metUp=hostRead(window.detailHost,"IsShown"),
		listW=hostRead(window.listHost,"GetWidth"),
		listH=hostRead(window.listHost,"GetHeight"),
		metW=hostRead(window.detailHost,"GetWidth"),
		metH=hostRead(window.detailHost,"GetHeight"),
		bandH=hostRead(window.rosterBand,"GetHeight"),
		bandUp=hostRead(window.rosterBand,"IsShown"),
		typed=(dossier and dossier.typed==true)or nil,
	},"ui")

	pcall(function()
		A.setWindowTitle(window,A.notesWindowTitle())
		local tagline,credit=A.windowFootLine()
		A.style(window.footName,"rowNote","dimmer")
		A.style(window.footState,"rowNote","dimmer")
		window.footName:SetText(tagline)
		window.footState:SetText(credit)
	end)

	return true
end

function A.showNotes()
	local frame=windowOrNil()
	if not frame then
		return false
	end

	refreshToShow()
	A.takeHalf("players")
	local shown=pcall(frame.Show,frame)
	pcall(frame.Raise,frame)

	A.trace("open",{source="notes",n=lastRows,id=scopeMatchId,
		width=A.unitFigure(A.notesPaneSplit())},"ui")

	return shown
end

function A.hideNotes()
	if not window then
		return false
	end
	return(pcall(window.Hide,window))
end

function A.toggleNotes()
	if window then
		local ok,shown=pcall(window.IsShown,window)
		if ok and shown then
			return A.hideNotes()
		end
	end
	return A.showNotes()
end

function A.setNotesSort(word,dir)
	if not A.playerSortKnown(word)then
		return false
	end
	word=A.playerSortWord(word)
	local first=A.playerSortFirst(word)
	if dir~=nil and(first==nil or(dir~="up"and dir~="down"))then
		return false
	end
	sortWord=word
	sortDir=first~=nil and(dir or first)or nil
	A.refreshNotes()
	return true
end

function A.clickNotesHeader(word)
	local first=A.playerSortFirst(word)
	if first==nil then
		return false
	end
	local dir=first
	if word==sortWord and sortDir~=nil then
		dir=sortDir=="up"and"down"or"up"
	end
	return A.setNotesSort(word,dir)
end

local function storeScaleFilter(scale,value)
	if scale=="attitude"then
		attitudeFilter=value
	else
		repFilter=value
	end
	requestedGuid=nil
	A.refreshNotes()
	return true
end

function A.toggleNotesScale(scale,value)
	local held=scale=="attitude"and attitudeFilter or repFilter
	if value==nil or held==value then
		value=nil
	end
	return storeScaleFilter(scale,value)
end

function A.toggleNotesRep(rep)
	return A.toggleNotesScale("skill",rep)
end

function A.setNotesScale(scale,value)
	if value~=nil and value~="none"and A.ratingText(value,scale)==nil then
		return false
	end
	return storeScaleFilter(scale,value)
end

function A.setNotesRep(rep)
	return A.setNotesScale("skill",rep)
end

function A.setNotesFormat(format)
	if format~=nil and type(format)~="string"then
		return false
	end
	formatFilter=format
	requestedGuid=nil
	A.refreshNotes()
	return true
end

function A.setNotesSide(side)
	if side~=nil and side~="with"and side~="against"then
		return false
	end
	sideFilter=side
	requestedGuid=nil
	A.refreshNotes()
	return true
end

function A.setNotesSearch(text)
	if text~=nil and type(text)~="string"then
		return false
	end
	searchText=(text~=nil and text~="")and text or nil
	requestedGuid=nil
	if window and window.searchBox then
		pcall(window.searchBox.SetText,window.searchBox,searchText or"")
	end
	A.refreshNotes(true)
	return true
end

function A.notesState()
	return{sort=sortWord,dir=sortDir,rep=repFilter,attitude=attitudeFilter,format=formatFilter,
		side=sideFilter,
		text=searchText,scope=scopeMatchId,tidy=scopeTidy~=nil and#scopeTidy or nil}
end

function A.notesScope()
	return scopeMatchId
end

function A.showNotesForMatch(id)
	if(type(id)~="number"and type(id)~="string")or not A.match(id)then
		return false
	end

	scopeMatchId=id
	scopeTidy=nil
	requestedGuid=nil
	return A.showNotes()
end

function A.showNotesForTidy(guids)
	if type(guids)~="table"then
		return false
	end
	local held={}
	for i=1,#guids do
		held[i]=guids[i]
	end
	scopeTidy=held
	scopeMatchId=nil
	requestedGuid=nil
	return A.showNotes()
end

function A.clearNotesScope()
	local held=scopeMatchId or scopeTidy
	scopeMatchId=nil
	scopeTidy=nil
	A.refreshNotes()
	return held~=nil
end

function A.resetNotesPane()
	setSelected(nil)
	scopeMatchId=nil
	scopeTidy=nil
	pendingReveal=nil
	if type(A.clearPlayerListing)=="function"then
		A.clearPlayerListing()
	end
	if type(A.closePlayerWindows)=="function"then
		pcall(A.closePlayerWindows)
	end
	return A.refreshNotes()
end

function A.clickPlayersRow(guid)
	if guid==nil then
		return"refused"
	end
	setSelected(guid)
	requestedGuid=nil
	A.refreshNotes()
	return"selected"
end

function A.notesSelected()
	return selectedGuid
end

function A.notesWindowShown()
	if not window then
		return false
	end
	local ok,shown=pcall(window.IsShown,window)
	return ok and shown==true
end

function A.selectPlayer(guid,forWriting)
	if guid==nil then
		return false
	end
	setSelected(guid)
	requestedGuid=guid
	pendingReveal=guid
	if not windowOrNil()then
		return false
	end
	refreshToShow()
	A.takeHalf("players")
	local shown=pcall(window.Show,window)
	pcall(window.Raise,window)

	if forWriting and shown then
		pcall(function()
			local box=window.noteRow.box
			box:SetFocus()
			box:SetCursorPosition(box:GetNumLetters()or 0)
		end)
	end

	return shown
end
