-- WowPvpHistory 0.70.7
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
local formatFilter
local sideFilter

local stagedFault=false

local scopeMatchId

local pendingReveal

local requestedGuid

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

local MET_ROWS=4

local ROSTER_SLOTS=8

function A.notesWindowTitle()
	return("%s: players and notes (%s)"):format(A.displayName(),tostring(A.version or"unknown"))
end

local function surface()
	if type(CreateFrame)~="function"
		or type(CreateScrollBoxListLinearView)~="function"
		or type(CreateDataProvider)~="function"
		or type(A.buildScroller)~="function"then
		return false
	end
	if type(ScrollUtil)~="table"
		or type(ScrollUtil.InitScrollBoxListWithScrollBar)~="function"then
		return false
	end
	return true
end

local function figureColumns()
	return{
		{key="met",name="MET",width=A.metric("playerColMet")},
		{key="with",name="WITH",width=A.metric("playerColSide")},
		{key="against",name="AGAINST",width=A.metric("playerColSide")},
	}
end

local function figureEdges()
	local columns=figureColumns()
	local edges={}
	local at=A.metric("rowLabelPad")
	for i=#columns,1,-1 do
		edges[i]=at
		at=at+columns[i].width+A.metric("rowCellGap")
	end
	return edges,at
end

local function sideCellText(pieces)
	if type(pieces)~="table"or#pieces==0 then
		return A.colorEscape("dimmer").."-|r"
	end
	local out={}
	for i=1,#pieces do
		out[i]=A.colorEscape(pieces[i].tone or"dim")..pieces[i].text.."|r"
	end
	return table.concat(out,A.colorEscape("dim")..", |r")
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
	local text,_,measured=nil,nil,false
	if ok and type(room)=="number"and room>0 then
		text,_,measured=A.fittedForm(fontString,room,forms)
	end
	if text==nil then
		text=measured and forms[#forms]or forms[1]
		if not measured and retry and#forms>1 and type(C_Timer)=="table"
			and type(C_Timer.After)=="function"then
			C_Timer.After(0,function()
				if fontString.headForms==forms then
					A.refitNameHead(fontString,false)
				end
			end)
		end
	end
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
			cell:SetJustifyH("RIGHT")
			cell:SetWordWrap(false)
			row.figures[i]=cell
		end

		local left=A.metric("playerLane")+A.metric("playerLaneGap")
		row.specIcon=row:CreateTexture(nil,"ARTWORK")
		row.specIcon:SetPoint("TOPLEFT",row,"TOPLEFT",left,-4)
		row.specIcon:Hide()

		row.label=row:CreateFontString(nil,"ARTWORK","GameFontHighlightSmall")
		row.label:SetPoint("TOPLEFT",row,"TOPLEFT",left+A.playersIconSize()+A.metric("chipGap"),-4)
		row.label:SetPoint("RIGHT",row,"RIGHT",-used,0)
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
	end

	row.hover:SetColorTexture(A.color("hover"))
	row.selection:SetColorTexture(A.color("selection"))
	row.rule:SetColorTexture(A.color("divider"))

	if data.section~=nil then
		row.playerGuid=nil
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

	row.lane:SetColorTexture(A.color(A.ratingMark(item.rating)))
	row.lane:Show()

	local identity=item.identity
	A.style(row.label,"bodyMedium")
	row.label:SetTextColor(A.classColor(identity.classToken))
	A.fitNameHead(row.label,identity.bare or A.UNKNOWN_PLAYER,identity.realm,"dimmer",
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

	local met,with,against=row.figures[1],row.figures[2],row.figures[3]
	A.style(met,"numberSmall",item.met>1 and"text"or"dimmer")
	met:SetText(("x%d"):format(item.met))
	A.style(with,"numberSmall","text")
	with:SetText(sideCellText(A.sideShort(item.with)))
	A.style(against,"numberSmall","text")
	against:SetText(sideCellText(A.sideShort(item.against)))
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

local function initMet(line,data)
	if not line.built then
		line.built=true
		A.buildEncounterLine(line)
		line.tail=line:CreateFontString(nil,"ARTWORK","GameFontDisableSmall")
		line.tail:SetPoint("LEFT",line,"LEFT",A.metric("rowLabelPad"),0)
		line.tail:SetPoint("RIGHT",line,"RIGHT",-A.metric("rowLabelPad"),0)
		line.tail:SetJustifyH("LEFT")
		line.tail:SetWordWrap(false)
		line:SetScript("OnMouseUp",function(self)
			if self.matchId~=nil then
				A.showMatchFromPlayers(self.matchId)
			end
		end)
	end

	if data.tail~=nil then
		A.paintEncounterLine(line,nil)
		A.style(line.tail,"note","dim")
		line.tail:SetText(data.tail)
		line.tail:Show()
		line.hover:Hide()
		line:EnableMouse(false)
		return
	end
	line.tail:Hide()
	A.paintEncounterLine(line,data.line,window and window.metWidths or nil,false)
	line.hover:Show()
	line:EnableMouse(data.line~=nil and data.line.matchId~=nil)
end

local function commitNote()
	if not(window and selectedGuid)then
		return
	end

	local ok,text=pcall(window.noteRow.box.GetText,window.noteRow.box)
	if not ok then
		return
	end

	local stored,_,why,length,bound=
		A.setPlayerNote(selectedGuid,(text~=nil and text~="")and text or nil)
	if not stored then
		if why=="too-long"then
			A.say(("that note is %d bytes and the bound is %d bytes. Nothing written")
				:format(tonumber(length)or 0,tonumber(bound)or A.PLAYER_NOTE_MAX))
		else
			A.say("no database, so the note could not be stored")
		end
		return
	end

	pcall(window.noteRow.box.ClearFocus,window.noteRow.box)
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

local function repPicked(wanted)
	if not selectedGuid then
		return
	end
	local held=A.noteFor(selectedGuid)
	if held~=nil and held.rating==wanted then
		wanted=nil
	end
	if not A.setPlayerRating(selectedGuid,wanted)then
		A.say("no database, so the rating could not be stored")
	end
end

local function tagRefusal(why,offender,bound)
	if why=="tag-too-long"then
		A.say(("%q is longer than %d bytes, so nothing was added")
			:format(tostring(offender),tonumber(bound)or A.PLAYER_TAG_MAX))
	elseif why=="too-many"then
		A.say(("that is past %d tags, so %q and the rest were not added. Nothing written")
			:format(tonumber(bound)or A.PLAYER_MAX_TAGS,tostring(offender)))
	else
		A.say("no database, so the tags could not be stored")
	end
end

local function commitTags()
	if not(window and selectedGuid)then
		return
	end
	local box=window.tagRow.box
	local ok,text=pcall(box.GetText,box)
	if not ok then
		return
	end
	local tags={}
	for word in tostring(text or""):gmatch("%S+")do
		tags[#tags+1]=word
	end
	if#tags==0 then
		return
	end
	pcall(box.SetText,box,"")
	local stored,added,why,offender,bound=A.addPlayerTags(selectedGuid,tags)
	if not stored then
		pcall(box.SetText,box,text)
		tagRefusal(why,offender,bound)
		return
	end
	if type(added)=="table"and#added==0 then
		A.say("every one of those tags was already there. Nothing written")
	end
	pcall(box.ClearFocus,box)
end

local function tagClicked(button)
	if not(selectedGuid and button.tagValue)then
		return
	end
	if not A.removePlayerTags(selectedGuid,{button.tagValue})then
		A.say("no database, so the tag could not be removed")
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
		tagRefusal(why,offender,bound)
	end
end

local function standTagRow(note,pane)
	local tagRows=A.paintTagRow(window.tagRow,note,pane)
	window.dossier:SetHeight(A.notesPaneStack(tagRows)-A.metric("encRow")
		-A.fontSize("label")-A.metric("headingPad"))
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

	local tags={}
	for word in tostring(text or""):gmatch("%S+")do
		tags[#tags+1]=word
	end
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
			A.say("no database, so the tags could not be stored")
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

	local ok,summary=A.untagRoster(record,{button.tagValue})
	if not ok then
		A.say("no database, so the tag could not be removed")
		return
	end
	A.say(A.rosterWriteLine(summary,false))
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

	local x,shown=0,0
	for i=1,#window.rosterChips do
		local button=window.rosterChips[i]
		local held=counts[i]
		if held==nil then
			button:Hide()
		else
			button.tagValue=held.tag
			button:SetText(("%s %d  x"):format(held.tag,held.count))
			local width=A.fitControl(button,A.metric("tagMin"),A.metric("tagPad"))
			if x>0 and x+width>available-A.metric("tagBoxMin")then
				button:Hide()
			else
				button:ClearAllPoints()
				button:SetPoint("TOPLEFT",window.rosterBand,"TOPLEFT",x,
					-A.metric("paneGap"))
				button:Show()
				x=x+width+A.metric("pillGap")
				shown=shown+1
			end
		end
	end

	local missed=#counts-shown
	if missed>0 then
		window.rosterMore:ClearAllPoints()
		window.rosterMore:SetPoint("TOPLEFT",window.rosterBand,"TOPLEFT",x,
			-A.metric("paneGap")-4)
		window.rosterMore:SetText(("+%d"):format(missed))
		A.style(window.rosterMore,"note","dimmer")
		window.rosterMore:Show()
		x=x+A.textRoom(window.rosterMore,("+%d"):format(missed))+A.metric("pillGap")
	else
		window.rosterMore:Hide()
	end

	local free=available-x
	if free<A.metric("tagBoxMin")then
		free=A.metric("tagBoxMin")
	end
	window.rosterBox:ClearAllPoints()
	window.rosterBox:SetPoint("TOPRIGHT",window.rosterBand,"TOPRIGHT",0,-A.metric("paneGap"))
	window.rosterBox:SetWidth(free)

	window.rosterBand:SetHeight(A.notesRosterBandHeightFor(true))
	window.rosterBand:Show()
	return true
end

function A.playersStripHeight()
	return A.metric("standPad")*2+A.fontSize("label")+A.fontSize("number")+A.fontSize("note")+8
end

local RATINGS_LABEL="YOUR REP"

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
	for i=3,1,-1 do
		local tile=stripBlock(frame.strip)
		tile:SetPoint("TOPRIGHT",frame.strip,"TOPRIGHT",-x,-pad)
		tile:SetPoint("BOTTOMRIGHT",frame.strip,"BOTTOMRIGHT",-x,pad)
		tile:SetWidth(A.metric("standTile"))
		frame.stripTiles[i]=tile
		x=x+A.metric("standTile")+A.metric("paneGap")*2
	end

	local rep=CreateFrame("Frame",nil,frame.strip)
	rep:SetPoint("TOPLEFT",frame.stripLead,"TOPRIGHT",A.metric("paneGap")*3,0)
	rep:SetPoint("BOTTOMRIGHT",frame.stripTiles[1],"BOTTOMLEFT",-A.metric("paneGap")*2,0)
	frame.stripRep=rep
	rep.label=rep:CreateFontString(nil,"ARTWORK","GameFontDisableSmall")
	rep.label:SetPoint("TOPLEFT",rep,"TOPLEFT",0,0)
	rep.label:SetJustifyH("LEFT")
	rep.label:SetWordWrap(false)
	rep.total=rep:CreateFontString(nil,"ARTWORK","GameFontDisableSmall")
	rep.total:SetPoint("TOPRIGHT",rep,"TOPRIGHT",0,0)
	rep.total:SetJustifyH("RIGHT")
	rep.total:SetWordWrap(false)

	rep.bars,rep.legend={},{}
	for i,step in ipairs(A.ratingRamp())do
		local bar=CreateFrame("Button",nil,rep)
		bar:SetHeight(A.metric("repBarHeight"))
		bar:RegisterForClicks("LeftButtonUp")
		bar.fill=bar:CreateTexture(nil,"ARTWORK")
		bar.fill:SetAllPoints(bar)
		bar.ratingValue=step.rating
		bar.ratingMark=step.mark
		bar:SetScript("OnClick",function(self)
			A.toggleNotesRep(self.ratingValue)
		end)
		rep.bars[i]=bar

		local key=CreateFrame("Button",nil,rep)
		key:SetHeight(A.fontSize("note")+4)
		key:RegisterForClicks("LeftButtonUp")
		key.swatch=key:CreateTexture(nil,"ARTWORK")
		key.swatch:SetSize(A.metric("repSwatch"),A.metric("repSwatch"))
		key.swatch:SetPoint("LEFT",key,"LEFT",0,0)
		key.word=key:CreateFontString(nil,"ARTWORK","GameFontHighlightSmall")
		key.word:SetPoint("LEFT",key.swatch,"RIGHT",4,0)
		key.word:SetWordWrap(false)
		key.count=key:CreateFontString(nil,"ARTWORK","GameFontDisableSmall")
		key.count:SetPoint("LEFT",key.word,"RIGHT",4,0)
		key.count:SetWordWrap(false)
		key.ratingValue=step.rating
		key.ratingMark=step.mark
		key:SetScript("OnClick",function(self)
			A.toggleNotesRep(self.ratingValue)
		end)
		rep.legend[i]=key
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

	local rep=window.stripRep
	A.style(rep.label,"label","dim")
	rep.label:SetText(RATINGS_LABEL)

	local room=select(2,pcall(rep.GetWidth,rep))
	if type(room)~="number"or room<100 then
		room=A.notesFrameWidth()-A.metric("margin")*2-A.metric("standPad")*2
			-A.metric("standLead")-3*(A.metric("standTile")+A.metric("paneGap")*2)
			-A.metric("paneGap")*3
	end
	A.style(rep.total,"numberMicro","dim")
	fitted(rep.total,room-A.textRoom(rep.label,RATINGS_LABEL)-A.metric("paneGap"),{
		("%s rated, %s not rated"):format(A.groupedCount(strip.rated),A.groupedCount(strip.notRated)),
		("%s rated"):format(A.groupedCount(strip.rated)),
	})
	local gap=A.metric("repBarGap")
	local floor=6
	local total,held=0,0
	for _,step in ipairs(strip.steps)do
		total=total+step.count
		if step.count>0 then
			held=held+1
		end
	end
	local drawn=total>0 and held or#strip.steps
	local spare=room-gap*(drawn-1)-floor*drawn
	local x=0
	local barTop=-(A.fontSize("label")+6)
	local widths={}
	for i,bar in ipairs(rep.bars)do
		local step=strip.steps[i]
		local empty=total>0 and step.count==0
		local width=empty and 0
			or floor+((total>0 and spare>0)and math.floor(spare*step.count/total)or 0)
		widths[i]=width
		bar:ClearAllPoints()
		bar:SetPoint("TOPLEFT",rep,"TOPLEFT",x,barTop)
		bar:SetWidth(math.max(width,1))
		bar:SetShown(not empty)
		bar.fill:SetColorTexture(A.color(bar.ratingMark))
		local dim=repFilter~=nil and repFilter~=bar.ratingValue
		bar.fill:SetAlpha(dim and 0.3 or(step.count>0 and 1 or 0.35))
		if not empty then
			x=x+width+gap
		end
	end

	local keyTop=barTop-A.metric("repBarHeight")-6
	local keyGap=A.metric("paneGap")+6
	local function keyWidth(key,step,withWord)
		local wide=A.metric("repSwatch")+4+A.textRoom(key.count,A.groupedCount(step.count))
		if withWord then
			wide=wide+A.textRoom(key.word,step.label)+4
		end
		return wide
	end
	local whole=0
	for i,key in ipairs(rep.legend)do
		A.style(key.word,"note","text")
		A.style(key.count,"numberMicro","dim")
		whole=whole+keyWidth(key,strip.steps[i],true)+(i>1 and keyGap or 0)
	end
	local words=whole<=room
	x=0
	for i,key in ipairs(rep.legend)do
		local step=strip.steps[i]
		local chosen=repFilter==key.ratingValue
		local dim=repFilter~=nil and not chosen
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
	for i=1,3 do
		local tile=tiles[i]
		tile.rule:SetColorTexture(A.color("hairline"))
		A.style(tile.label,"label","dim")
		tile.label:SetText(said[i][1])
		A.style(tile.figure,"number",said[i][3])
		tile.figure:SetText(said[i][2])
		A.style(tile.sub,"numberMicro","dim")
		if said[i][4]then
			local _,at=fitted(tile.sub,A.metric("standTile"),said[i][4])
			forms[i]=at
		else
			tile.sub:SetText("")
			forms[i]=0
		end
	end

	return{
		tileForms=table.concat(forms,","),
		lead=leadText,
		repBars=table.concat(widths,","),
	}
end

local function buildToolbar(frame)
	frame.toolbar=CreateFrame("Frame",nil,frame)
	frame.toolbar:SetPoint("TOPLEFT",frame.strip,"BOTTOMLEFT",0,-A.metric("paneGap"))
	frame.toolbar:SetPoint("TOPRIGHT",frame.strip,"BOTTOMRIGHT",0,-A.metric("paneGap"))
	frame.toolbar:SetHeight(A.metric("controlHeight"))

	frame.searchBox=A.entry(frame.toolbar)
	frame.searchBox:SetHeight(A.metric("controlHeight"))
	frame.searchBox:SetPoint("LEFT",frame.toolbar,"LEFT",0,0)
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
	frame.sortTrack:SetPoint("LEFT",frame.searchBox,"RIGHT",A.metric("paneGap"),0)

	frame.sideFilter=A.dropdown(frame.toolbar,A.playerSideChoices(),function(value)
		A.setNotesSide(value)
	end)
	frame.sideFilter:SetPoint("RIGHT",frame.toolbar,"RIGHT",0,0)
	frame.formatFilter=A.dropdown(frame.toolbar,A.playerFormatChoices(),function(value)
		A.setNotesFormat(value)
	end)
	frame.formatFilter:SetPoint("RIGHT",frame.sideFilter,"LEFT",-A.metric("pillGap"),0)

	frame.repChip=A.pill(frame.toolbar,"",function()
		A.toggleNotesRep(repFilter)
	end)
	A.setControlTone(frame.repChip,"accent")
	frame.repChip:SetPoint("RIGHT",frame.formatFilter,"LEFT",-A.metric("paneGap"),0)
	frame.repChip:Hide()

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

	local anchor=window.formatFilter
	if repFilter~=nil then
		local label=(A.repLabel(repFilter~="none"and repFilter or nil))
		window.repChip:SetText(("%s  x"):format(label))
		A.fitControl(window.repChip,A.metric("tagMin"),A.metric("tagPad"))
		window.repChip:Show()
		anchor=window.repChip
	else
		window.repChip:Hide()
	end
	window.clearScope:ClearAllPoints()
	window.clearScope:SetPoint("RIGHT",anchor,"LEFT",-A.metric("paneGap"),0)
	window.clearScope:SetShown(scopeMatchId~=nil)
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
	frame.listHeader.labels={}
	frame.listHeader.names={"PLAYER"}
	frame.listHeader.keys={"player"}
	frame.listHeader.buttons={}
	local name=frame.listHeader:CreateFontString(nil,"ARTWORK","GameFontDisableSmall")
	name:SetPoint("LEFT",frame.listHeader,"LEFT",A.metric("playerLane")+A.metric("playerLaneGap"),0)
	name:SetWordWrap(false)
	frame.listHeader.labels[1]=name

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
		label:SetJustifyH("RIGHT")
		label:SetWordWrap(false)
		frame.listHeader.labels[#frame.listHeader.labels+1]=label
		frame.listHeader.names[#frame.listHeader.names+1]=column.name
		frame.listHeader.keys[#frame.listHeader.keys+1]=column.key
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

	frame.rep=A.buildRepControl(frame.dossier,repPicked)
	frame.rep:SetPoint("TOPLEFT",frame.dossierSub,"BOTTOMLEFT",
		-(A.fontSize("dossierName")+A.metric("chipGap")),-A.metric("paneGap"))
	frame.rep:SetPoint("RIGHT",frame.dossier,"RIGHT",0,0)

	frame.cards=A.buildSideCards(frame.dossier)
	frame.cards:SetPoint("TOPLEFT",frame.rep,"BOTTOMLEFT",0,-A.metric("paneGap"))
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

	frame.tagRow=A.buildTagRow(frame.dossier,tagClicked,suggestClicked,commitTags)
	frame.tagRow:SetPoint("TOPLEFT",frame.noteRow,"BOTTOMLEFT",0,-A.metric("paneGap"))
	frame.tagRow:SetPoint("RIGHT",frame.dossier,"RIGHT",0,0)
	frame.tagRow.box:HookScript("OnTextChanged",function(_,userInput)
		if userInput then
			pcall(paintTagSuggestions)
		end
	end)

	frame.metHeader=A.buildEncounterHeader(frame.dossier)
	frame.metHeader:SetPoint("TOPLEFT",frame.tagRow,"BOTTOMLEFT",0,-A.metric("paneGap"))
	frame.metHeader:SetPoint("RIGHT",frame.dossier,"RIGHT",0,0)
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
	local widest=A.encounterFloor()
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
		+gap+A.sideCardHeight()
		+gap+A.metric("controlHeight")
		+gap+rows*A.metric("tagRow")
		+gap+A.fontSize("label")+A.metric("headingPad")
		+A.metric("encRow")
end

local function topFloor()
	local strip=A.metric("standPad")*2+A.metric("standLead")+A.metric("paneGap")*3
		+3*(A.metric("standTile")+A.metric("paneGap")*2)
	local legend=0
	for _ in ipairs(A.ratingRamp())do
		legend=legend+A.metric("repSwatch")+4+A.headerFloor("0,000")+A.metric("paneGap")+6
	end
	strip=strip+legend
	local sorts=0
	for _,sort in ipairs(A.playerSorts())do
		sorts=sorts+math.max(A.metric("segmentMin"),A.headerFloor(sort.label))+A.metric("segmentGap")
	end
	local toolbar=A.metric("playerSearch")+A.metric("paneGap")+sorts
		+A.metric("paneGap")+A.headerFloor("Negative  x")+A.metric("tagPad")
		+2*(A.metric("dropdownWidth")+A.metric("pillGap"))
	return math.max(strip,toolbar)+A.metric("margin")*2
end

function A.notesWindowFloor()
	local above=A.metric("headerHeight")+A.playersStripHeight()+A.metric("paneGap")
		+A.metric("controlHeight")+A.notesRosterBandHeight()+A.metric("paneGap")

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
			pcall(A.rememberWindow,"players")
		end
	end)
	frame:Hide()

	A.registerChrome(frame)

	frame.heading=A.windowTitle(frame)
	frame.heading:SetPoint("TOPLEFT",frame,"TOPLEFT",A.metric("titleInset"),
		-A.metric("titleTop"))
	frame.heading:SetPoint("TOPRIGHT",frame,"TOPRIGHT",-A.metric("titleInset"),
		-A.metric("titleTop"))
	frame.heading:SetJustifyH("CENTER")
	frame.heading:SetWordWrap(false)
	A.style(frame.heading,"heading","bright")

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
	frame.list.bar:SetPoint("TOPLEFT",frame.listHost,"TOPRIGHT",4,0)
	frame.list.bar:SetPoint("BOTTOMLEFT",frame.listHost,"BOTTOMRIGHT",4,0)

	buildDossier(frame)

	frame.met=A.buildScroller(FRAME_NAME.."Detail",frame.detailHost,"Button",initMet,
		function(_,data)
			if type(data)=="table"and data.tail==nil then
				return A.metric("encRow")
			end
			return A.metric("rowHeight")
		end,"the player detail pane")
	frame.met.box:SetPoint("TOPLEFT",frame.metHeader,"BOTTOMLEFT",0,0)
	frame.met.box:SetPoint("TOPRIGHT",frame.metHeader,"BOTTOMRIGHT",0,0)
	frame.met.box:SetPoint("BOTTOMLEFT",frame.detailHost,"BOTTOMLEFT",0,0)
	frame.met.box:SetPoint("BOTTOMRIGHT",frame.detailHost,"BOTTOMRIGHT",0,0)
	frame.met.bar:SetPoint("TOPLEFT",frame.detailHost,"TOPRIGHT",4,0)
	frame.met.bar:SetPoint("BOTTOMLEFT",frame.detailHost,"BOTTOMRIGHT",4,0)

	buildFaultPanel(frame)

	frame.footName=frame:CreateFontString(nil,"ARTWORK","GameFontDisableSmall")
	frame.footName:SetPoint("BOTTOMLEFT",frame,"BOTTOMLEFT",A.metric("margin"),A.metric("margin"))
	frame.footName:SetJustifyH("LEFT")
	frame.footName:SetWordWrap(false)
	frame.footState=frame:CreateFontString(nil,"ARTWORK","GameFontDisableSmall")
	frame.footState:SetPoint("BOTTOMRIGHT",frame,"BOTTOMRIGHT",-A.metric("margin"),A.metric("margin"))
	frame.footState:SetJustifyH("RIGHT")
	frame.footState:SetWordWrap(false)

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
		text=searchText,
		format=formatFilter,
		side=sideFilter,
		rep=repFilter,
		sort=sortWord,
		dir=sortDir,
		now=time(),
	}
end

local function orderValue(sort,row)
	if type(row)~="table"then
		return nil
	end
	if sort=="with"or sort=="against"then
		local rank=row[sort.."Rank"]
		return rank and rank.diff or"-"
	end
	if sort=="met"then
		return row.met
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
	if formatFilter~=nil then
		cleared=cleared+1
		formatFilter=nil
	end
	if sideFilter~=nil then
		cleared=cleared+1
		sideFilter=nil
	end
	if scopeMatchId~=nil then
		cleared=cleared+1
		scopeMatchId=nil
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

local function repPhrase(rep)
	if rep==nil then
		return nil
	end
	if rep=="none"then
		return"not rated"
	end
	return("rated %s"):format(tostring(A.ratingText(rep)))
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
	if scopeMatchId and not A.match(scopeMatchId)then
		return("Match #%s is not in your history."):format(tostring(scopeMatchId)),"gone"
	end
	local filters={}
	if repFilter~=nil then
		filters[#filters+1]=repPhrase(repFilter)
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
		local roster=#A.rosterPlayers(A.match(scopeMatchId))
		if#filters==0 then
			return("No player in match #%s besides you."):format(tostring(scopeMatchId)),"roster"
		end
		return("No player in match #%s %s. %s."):format(tostring(scopeMatchId),
			tostring(A.joinAnd(filters)),roster==1 and"1 player is in it"
			or("%d players are in it"):format(roster)),"scoped"
	end
	if not anyPlayer()then
		return"No players yet.","nobody"
	end
	if#filters>0 then
		return("No listed player %s."):format(tostring(A.joinAnd(filters))),"filtered"
	end
	return"No player selected.","unselected"
end

local function metRows(dossier)
	local rows={}
	if not dossier then
		return rows
	end
	local encounters=dossier.encounters or{}
	for i=1,math.min(#encounters,MET_ROWS)do
		rows[#rows+1]={line=A.encounterLine(encounters[i])}
	end
	if#encounters>MET_ROWS then
		local more=#encounters-MET_ROWS
		rows[#rows+1]={tail=("%d more %s"):format(more,more==1 and"encounter"or"encounters")}
	elseif#encounters==0 then
		rows[1]={tail="no match with them"}
	end
	return rows
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

	A.style(window.faultTitle,"label","fault")
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

local function paintFaultPanel(listTook,metTook,shown,noRoom)
	if not window or not window.fault then
		return false
	end

	local refused,unreached={},{}
	local listName=(window.list and window.list.subject)or"the player list"
	local metName=(window.met and window.met.subject)or"the player detail pane"
	if listTook==false then
		refused[#refused+1]=listName
	elseif listTook==nil then
		unreached[#unreached+1]=listName
	end
	if metTook==false then
		refused[#refused+1]=metName
	elseif metTook==nil then
		unreached[#unreached+1]=metName
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

	local listName=(window.list and window.list.subject)or"the player list"
	local metName=(window.met and window.met.subject)or"the player detail pane"
	local said=A.paneFaultText({listName},nil,{metName},{metName})
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

local function sideReading(parts)
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
		window.metHeader:Hide()
		return nil
	end

	window.dossierEmpty:Hide()
	window.dossier:Show()
	window.metHeader:Show()
	window.noteRow.box:SetEnabled(true)
	window.tagRow.box:SetEnabled(true)

	local dossier=A.playerDossier(selected.guid,index)
	if not dossier then
		return nil
	end
	local identity=dossier.identity
	local pane=A.notesPaneSplit()

	window.copyText,window.murlokText=A.playerCopyTexts(selected.guid,dossier.entry)
	local edge=window.openWindow
	for _,pair in ipairs({{window.murlok,window.murlokText},{window.copyName,window.copyText}})do
		local button,text=pair[1],pair[2]
		button:ClearAllPoints()
		if text then
			button:SetPoint("TOPRIGHT",edge,"TOPLEFT",-A.metric("pillGap"),0)
			button:Show()
			edge=button
		else
			button:Hide()
		end
	end
	for _,line in ipairs({window.dossierName,window.dossierSub})do
		line:SetPoint("RIGHT",edge,"LEFT",-A.metric("paneGap"),0)
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
	if type(A.debugTextEnabled)=="function"and A.debugTextEnabled()==true then
		sub=sub.."  "..A.colorEscape("faint")..tostring(selected.guid).."|r"
	end
	window.dossierSub:SetText(sub)

	A.paintRepControl(window.rep,dossier.rating,pane,true)
	A.paintSideCards(window.cards,dossier,pane)

	local note=dossier.note
	local shown,typed=A.paintNoteBox(window.noteRow.box,window,selected.guid,note and note.text)
	A.paintNoteRow(window.noteRow,shown)

	standTagRow(note,pane)

	window.metWidths=A.encounterWidths(pane)
	A.paintEncounterHeader(window.metHeader,window.metWidths)
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
		pcall(A.refreshPlayerWindows,index)
	end
	if not window then
		return false
	end

	local rows,selected,view=listRows(index)
	lastRows=view.shown

	pcall(paintRosterBand)

	stagedFault=false

	local stripOk,stripErr=pcall(paintStrip,view)
	if not stripOk then
		A.noteError(("the players strip did not paint: %s"):format(tostring(stripErr)),"notes/strip")
	end
	local stripDrew=(stripOk and type(stripErr)=="table")and stripErr or{}
	pcall(paintToolbar)

	pcall(function()
		window.listHeader.rule:SetColorTexture(A.color("hairline"))
		for i,label in ipairs(window.listHeader.labels)do
			A.style(label,"label",window.listHeader.keys[i]==view.sort and"accent"or"dimmer")
			label:SetText(window.listHeader.names[i]or"")
		end
		for _,button in ipairs(window.listHeader.buttons)do
			button.hover:SetColorTexture(A.color("hover"))
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
	if not dossierOk then
		A.noteError(("the player dossier did not paint: %s"):format(tostring(dossier)),"notes/dossier")
		dossier=nil
	end

	local metTook=nil
	local metOk,metErr=pcall(function()
		metTook=A.setRows(window.met,metRows(dossier))
	end)
	if not metOk then
		A.noteError(("the player detail pane was never handed its rows: %s"):format(tostring(metErr)),
			"notes/detail")
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
	cramped(window.listHost,listTook,(window.list and window.list.subject)or"the player list",
		"notes/list")
	cramped(window.detailHost,metTook,
		(window.met and window.met.subject)or"the player detail pane","notes/detail")

	local panelOk,panel=pcall(paintFaultPanel,listTook,metTook,view.shown,noRoom)
	if not panelOk then
		A.noteError(("the fault panel did not stand: %s"):format(tostring(panel)),"notes/panel")
		panel=false
	end

	local selectedIds=nil
	if dossier and type(dossier.record)=="table"and type(dossier.record.ids)=="table"then
		local ids={}
		for i=1,#dossier.record.ids do
			ids[i]=tostring(dossier.record.ids[i])
		end
		selectedIds=table.concat(ids,",")
	end
	pcall(A.trace,"paint",{
		source="notes",
		n=view.shown,
		rows=#rows,
		listTook=listTook,
		met=metTook,
		dossier=dossierOk,
		panel=panel,
		sort=sortWord,
		sortDir=sortDir,
		repStep=repFilter~=nil and tostring(repFilter)or nil,
		fmt=formatFilter,
		sideFilter=sideFilter,
		players=view.strip.players,
		unmet=view.strip.unmet,
		sections=#view.sections,
		tileForms=stripDrew.tileForms,
		lead=stripDrew.lead,
		ratedPlayers=view.strip.rated,
		unratedPlayers=view.strip.notRated,
		repBars=stripDrew.repBars,
		search=searchText~=nil or nil,
		empty=view.shown==0 and drawnEmpty or nil,
		with=dossier and sideReading(dossier.with)or nil,
		against=dossier and sideReading(dossier.against)or nil,
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
		window.heading:SetText(A.notesWindowTitle())
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

	A.refreshNotes()
	A.takeHalf("players")
	local shown=pcall(frame.Show,frame)
	pcall(frame.Raise,frame)

	local box=frame.met and frame.met.box or nil
	local okBox,metRoom=false,nil
	if box then
		okBox,metRoom=pcall(box.GetWidth,box)
	end
	A.trace("open",{source="notes",n=lastRows,id=scopeMatchId,
		metW=okBox and A.unitFigure(metRoom)or nil,width=A.unitFigure(A.notesPaneSplit())},"ui")

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

function A.toggleNotesRep(rep)
	if rep==nil then
		repFilter=nil
	elseif repFilter==rep then
		repFilter=nil
	else
		repFilter=rep
	end
	A.refreshNotes()
	return true
end

function A.setNotesRep(rep)
	if rep~=nil and rep~="none"and A.ratingText(rep)==nil then
		return false
	end
	repFilter=rep
	A.refreshNotes()
	return true
end

function A.setNotesFormat(format)
	if format~=nil and type(format)~="string"then
		return false
	end
	formatFilter=format
	A.refreshNotes()
	return true
end

function A.setNotesSide(side)
	if side~=nil and side~="with"and side~="against"then
		return false
	end
	sideFilter=side
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
	return{sort=sortWord,dir=sortDir,rep=repFilter,format=formatFilter,side=sideFilter,
		text=searchText,scope=scopeMatchId}
end

function A.notesScope()
	return scopeMatchId
end

function A.showNotesForMatch(id)
	if(type(id)~="number"and type(id)~="string")or not A.match(id)then
		return false
	end

	scopeMatchId=id
	return A.showNotes()
end

function A.clearNotesScope()
	local held=scopeMatchId
	scopeMatchId=nil
	A.refreshNotes()
	return held~=nil
end

function A.resetNotesPane()
	setSelected(nil)
	scopeMatchId=nil
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
	A.refreshNotes()
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
