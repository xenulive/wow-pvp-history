-- WowPvpHistory 0.70.16
-- Author:  Xenu-Sentinels
-- Project: wow-pvp-history
--          https://github.com/xenulive/wow-pvp-history
-- License: MIT, see LICENSE
local _,A=...

local FRAME_NAME="WowPvpHistoryOptionsFrame"

local window

local restoreSlot="current"
local restoreRead=nil

local DIAGNOSTIC="diagnostic"

local chosenPage="general"

local findText=""

local function findQuery()
	return(findText:match("^%s*(.-)%s*$")or""):lower()
end

local function storageShowing()
	return chosenPage=="data"and findQuery()==""
end

local lastOutcome

local lastOutcomeRegister

function A.minimapOffNote()
	return"With the button off, /pvph show opens the history, as does the key under Key Bindings."
end

function A.restoreSlotName(slot)
	return slot=="pinned"and"Pinned"or"Latest"
end

function A.restoreSlotText(slot)
	local held=A.backupStore()
	local entry=held and held[slot]
	local name=A.restoreSlotName(slot)

	if type(entry)~="table"or type(entry.matches)~="number"then
		if slot=="pinned"then
			return name,"Nothing pinned"
		end
		return name,"No backup has been written on this character yet."
	end

	return("%s (%d)"):format(name,entry.matches),
		("%d %s, written %s."):format(entry.matches,entry.matches==1 and"match"or"matches",
			tostring(entry.at)),
		entry.matches,entry.at
end

local function holdRestoreRead(slot)
	local _,_,matches,at=A.restoreSlotText(slot)
	local held=A.backupStore()
	restoreRead={slot=slot,at=at,matches=matches,entry=held and held[slot]or nil}
end

local function restoreArmedNow()
	local read=restoreRead
	if read==nil or read.slot~=restoreSlot then
		return false
	end
	local _,_,matches,at=A.restoreSlotText(restoreSlot)
	local held=A.backupStore()
	if at==nil or at~=read.at or matches~=read.matches or(held and held[restoreSlot])~=read.entry then
		restoreRead=nil
		return false
	end
	return true
end

local function surface()
	return type(CreateFrame)=="function"
end

local PAGES={
	{value="general",label="General"},
	{value="alerts",label="Alerts"},
	{value="notes",label="Notes and players"},
	{value="recording",label="Recording"},
	{value="data",label="Data and backups"},
}

local ALIASES={
	window="general",
	minimap="general",
	history="recording",
	storage="data",
	all="general",
}

local function pageOrder()
	local out={}
	for i=1,#PAGES do
		out[i]=PAGES[i].value
	end
	out[#out+1]=DIAGNOSTIC
	return out
end

local function pageLabel(value)
	for i=1,#PAGES do
		if PAGES[i].value==value then
			return PAGES[i].label
		end
	end
	if value==DIAGNOSTIC then
		return"Diagnostic"
	end
	return nil
end

function A.optionsPageFor(word,target)
	if type(word)~="string"then
		return nil
	end
	if word=="all"then
		if target==nil or target=="all"then
			return ALIASES.all
		end
		return A.optionsPageFor(target,nil)
	end
	if pageLabel(word)~=nil then
		return word
	end
	return ALIASES[word]
end

local SWITCHES={
	{
		key="overlayShown",
		section="general",
		card="RESULTS ON SCREEN",
		label="Show the newest results",
		tip="Draw a small bar of the newest results of the format last played, one cell per match. "
			.."Drag it where it should sit, and click a cell to open its match.",
		get=function()return A.overlayEnabled()end,
		set=function(on)return A.setOverlay(on)end,
	},
	{
		key="overlayCombat",
		section="general",
		card="RESULTS ON SCREEN",
		parent="overlayShown",
		label="Hide in combat",
		tip="Take the bar down while you are in combat and put it back when combat ends.",
		get=function()return A.overlayCombat()end,
		set=function(on)return A.setOverlayCombat(on)end,
	},
	{
		key="minimap",
		section="general",
		card="MINIMAP AND LOGIN",
		label="Minimap button",
		tip="Show the button that opens the match history window.",
		get=function()return A.minimapShown()end,
		set=function(on)return A.setMinimapShown(on)end,
	},
	{
		key="loginLine",
		section="general",
		card="MINIMAP AND LOGIN",
		label="Name the version at login",
		tip="Print the loaded version and the way in every time the addon loads, and say so when "
			.."the stored history did not load or something threw.",
		get=function()return A.loginLineEnabled()end,
		set=function(on)return A.setLoginLine(on)end,
	},
	{
		key="rememberTab",
		section="general",
		card="WINDOWS",
		label="Remember the selected tab",
		tip="Open the match history on the format tab that was last selected, rather than on all "
			.."formats.",
		get=function()return A.rememberTab()end,
		set=function(on)return A.setRememberTab(on)end,
	},
	{
		key="closeWithMain",
		section="general",
		card="WINDOWS",
		label="Close match and player windows with the main window",
		tip="When you close the main window, close every match window and player window too.",
		get=function()return A.closeWithMainEnabled()end,
		set=function(on)return A.setCloseWithMain(on)end,
	},
	{
		key="alerts",
		section="alerts",
		card="IN A GROUP",
		label="Group and match alerts",
		tip="Print how many of a group's members, and of a finished match's participants, are "
			.."already in the stored history.",
		get=function()return A.alertsEnabled()end,
		set=function(on)return A.setAlerts(on)end,
	},
	{
		key="groupNotes",
		section="alerts",
		card="IN A GROUP",
		parent="alerts",
		label="Show what was written on who joined",
		tip="With the group alert on, print the rating, the tags and the note for each group "
			.."member who carries one.",
		get=function()return A.groupNotesEnabled()end,
		set=function(on)return A.setGroupNotes(on)end,
		needs="Needs Group and match alerts, above.",
	},
	{
		key="announce",
		section="alerts",
		card="AT THE GATES",
		label="Announce who you know",
		tip="When a match's roster resolves or somebody the history holds joins your group, name "
			.."who you have met or written about across the top of the screen.",
		get=function()return A.announceEnabled()end,
		set=function(on)return A.setAnnounce(on)end,
	},
	{
		key="postGame",
		section="alerts",
		card="AFTER A MATCH",
		label="Chat line after a match",
		tip="After a match or a duel, print what was recorded, the rating change, any new personal "
			.."best and a link that opens it. A line reporting a fault prints either way.",
		get=function()return A.postGameEnabled()end,
		set=function(on)return A.setPostGame(on)end,
	},
	{
		key="openAfterMatch",
		section="alerts",
		card="AFTER A MATCH",
		label="Open the match window",
		tip="When you leave a match, open its window. It waits until you are out of combat.",
		get=function()return A.openAfterMatchEnabled()end,
		set=function(on)return A.setOpenAfterMatch(on)end,
	},
	{
		key="tooltip",
		section="notes",
		card="WHERE YOUR NOTES SHOW",
		label="Unit tooltip lines",
		tip="Add the record against a player, the rating they were last seen at and whatever is "
			.."written on them to their unit tooltip.",
		get=function()return A.tooltipEnabled()end,
		set=function(on)return A.setTooltip(on)end,
	},
	{
		key="contextMenu",
		section="notes",
		card="WHERE YOUR NOTES SHOW",
		label="Right-click menu entry",
		tip="Add an entry to the player right-click menu that writes a note and a rating without "
			.."opening a window.",
		get=function()return A.contextMenuEnabled()end,
		set=function(on)return A.setContextMenu(on)end,
	},
	{
		key="chatMark",
		section="notes",
		card="IN CHAT",
		label="A bar before their name",
		find="a bar before their name mark people you have written about in chat",
		tip="Outside a match, a dungeon or a raid, put a bar before the name of a player you rated, "
			.."tagged or wrote about when they talk in chat, colored by your rating.",
		get=function()return A.chatMarkEnabled()end,
		set=function(on)return A.setChatMark(on)end,
	},
	{
		key="sight",
		section="notes",
		card="ON NAMEPLATES",
		label="A mark on their nameplate",
		find="a mark on their nameplate mark people you have written about when they appear",
		tip="Outside a battleground or an arena, put a mark on the nameplate of a player you rated, "
			.."tagged or wrote about, and name them once in chat when they appear.",
		get=function()return A.sightEnabled()end,
		set=function(on)return A.setSight(on)end,
	},
	{
		key="duels",
		section="recording",
		card="WHAT IS RECORDED",
		label="Record duels",
		tip="Keep a completed duel as a record, with its opponent attached to the player index.",
		get=function()return A.duelsEnabled()end,
		set=function(on)return A.setDuels(on)end,
	},
	{
		key="hold",
		section="recording",
		card="WHAT IS RECORDED",
		label="Hold the exit while the scoreboard is read",
		tip="Cover the leave button on the match results frame for a few seconds after a match "
			.."ends, so a match left at the first opportunity is still recorded with its full roster.",
		get=function()return A.holdEnabled()end,
		set=function(on)return A.setHold(on)end,
	},
	{
		key="finder",
		section="recording",
		card="GROUP FINDER",
		label="Season record beside the group finder",
		tip="Show this character's record for the current season beside the group finder while its "
			.."Player vs. Player tab is open.",
		get=function()return A.finderEnabled()end,
		set=function(on)return A.setFinder(on)end,
	},
	{
		key="finderDock",
		section="recording",
		card="GROUP FINDER",
		parent="finder",
		label="Dock it to the group finder",
		tip="When off, drag the season record anywhere on the screen. It shows there each time the "
			.."Player vs. Player tab opens.",
		get=function()return A.finderDocked()end,
		set=function(on)return A.setFinderDocked(on)end,
	},
}

local SWITCH_INDEX,SWITCH_BY_KEY={},{}
for i=1,#SWITCHES do
	SWITCH_INDEX[SWITCHES[i].key]=i
	SWITCH_BY_KEY[SWITCHES[i].key]=SWITCHES[i]
end

local function parentOn(key)
	local spec=SWITCH_BY_KEY[key]
	if spec==nil then
		return true
	end
	local ok,on=pcall(spec.get)
	return ok and on==true
end

local DIAGNOSTIC_SWITCHES={
	{
		key="debug",
		section=DIAGNOSTIC,
		card="DIAGNOSTIC",
		label="Debug ring",
		tip="Record what the addon decided, per character, in a file that outlives the history.",
		get=function()return A.debugEnabled()end,
		set=function(on)return A.setDebug(on)end,
	},
	{
		key="debugText",
		section=DIAGNOSTIC,
		card="DIAGNOSTIC",
		label="Debug detail on screen",
		tip="Show the harvest reading, the decoded columns and the instance id on a match, "
			.."and the byte shares on the storage readout.",
		get=function()return A.debugTextEnabled()end,
		set=function(on)return A.setDebugText(on)end,
	},
}

local function outcome(lines,register,walk)
	if type(lines)=="table"and#lines>0 then
		local said={}
		for i=1,#lines do
			local line=tostring(lines[i])
			if line~=""then
				line=line:sub(1,1):upper()..line:sub(2)
				if not line:match("[%.%?!]$")then
					line=line.."."
				end
				said[#said+1]=line
			end
		end
		lastOutcome=table.concat(said," ")
		lastOutcomeRegister=register
	end
	A.refreshOptionsWindow(walk==true)
end

local BACKUP_SHARE=1.2/2.2

local function tipFor(spec)
	local tip=spec.tip
	if spec.needs then
		tip=tip.." "..spec.needs
	end
	if spec.key=="minimap"then
		tip=tip.." "..A.minimapOffNote()
	end
	return tip
end

function A.optionsSwitchCounts()
	local counts={}
	local all={on=0,total=0}
	local function count(spec)
		local held=counts[spec.section]
		if held==nil then
			held={on=0,total=0}
			counts[spec.section]=held
		end
		held.total=held.total+1
		all.total=all.total+1
		local ok,on=pcall(spec.get)
		if ok and on then
			held.on=held.on+1
			all.on=all.on+1
		end
	end
	for i=1,#SWITCHES do
		count(SWITCHES[i])
	end
	for i=1,#DIAGNOSTIC_SWITCHES do
		count(DIAGNOSTIC_SWITCHES[i])
	end
	counts.all=all
	return counts
end

local function countsText(counts)
	local parts={}
	local order=pageOrder()
	for i=1,#order do
		local held=counts[order[i]]
		if held then
			parts[#parts+1]=("%s %d/%d"):format(order[i],held.on,held.total)
		end
	end
	return table.concat(parts,", ")
end

local function showTip(owner,spec)
	if not GameTooltip then
		return
	end
	pcall(function()
		local r,g,b=A.color("accent")
		GameTooltip:SetOwner(owner,"ANCHOR_RIGHT")
		GameTooltip:SetText(spec.label,r,g,b,1,true)
		local textR,textG,textB=A.color("text")
		GameTooltip:AddLine(tipFor(spec),textR,textG,textB,true)
		GameTooltip:Show()
	end)
end

local function hideTip(owner)
	A.hideOwnedTooltip(owner)
end

local function hoverTip(control,spec)
	pcall(control.HookScript,control,"OnEnter",function(self)
		showTip(self,spec)
	end)
	pcall(control.HookScript,control,"OnLeave",hideTip)
end

local function paintToggle(toggle)
	local on=toggle:GetChecked()and true or false
	local inset=(A.metric("toggleHeight")-A.metric("toggleKnob"))/2
	toggle.track:SetColorTexture(A.color(on and"accent"or"faint"))
	local r,g,b=A.color(on and"panelDeep"or"dim")
	toggle.knob:SetColorTexture(r,g,b,1)
	toggle.knob:ClearAllPoints()
	if on then
		toggle.knob:SetPoint("RIGHT",toggle,"RIGHT",-inset,0)
	else
		toggle.knob:SetPoint("LEFT",toggle,"LEFT",inset,0)
	end
	toggle.word:SetText(on and"On"or"Off")
	A.style(toggle.word,"numberSmall",on and"accent"or"dim")
	toggle:SetAlpha(toggle:IsEnabled()and 1 or 0.4)
end

local function buildToggle(parent)
	local toggle=CreateFrame("CheckButton",nil,parent)
	toggle.controlKind="toggle"
	toggle:SetSize(A.metric("toggleWidth"),A.metric("toggleHeight"))
	toggle.track=toggle:CreateTexture(nil,"ARTWORK")
	toggle.track:SetAllPoints(toggle)
	toggle.knob=toggle:CreateTexture(nil,"OVERLAY")
	toggle.knob:SetSize(A.metric("toggleKnob"),A.metric("toggleKnob"))
	toggle.word=toggle:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
	A.style(toggle.word,"numberSmall","dim")
	local wordRoom=math.max(A.textRoom(toggle.word,"On"),A.textRoom(toggle.word,"Off"))
	toggle.word:SetWidth(wordRoom)
	toggle.word:SetJustifyH("RIGHT")
	toggle.word:SetWordWrap(false)
	toggle.word:SetPoint("RIGHT",toggle,"LEFT",-A.metric("pillGap"),0)
	toggle.wordRoom=wordRoom+A.metric("pillGap")
	for _,method in ipairs({"SetChecked","Enable","Disable"})do
		local base=toggle[method]
		toggle[method]=function(self,...)
			base(self,...)
			paintToggle(self)
		end
	end
	paintToggle(toggle)
	return toggle
end

local function buildCard(frame,pane,title,opts)
	opts=opts or{}
	local card=CreateFrame("Frame",nil,pane)
	card.pane=pane
	card.ground=card:CreateTexture(nil,"BACKGROUND")
	card.ground:SetAllPoints(card)
	card.edges=A.hairlineEdges(card)

	card.heading=card:CreateFontString(nil,"ARTWORK","GameFontNormalSmall")
	card.heading:SetPoint("LEFT",card,"TOPLEFT",A.metric("setCardPad"),-A.metric("cardHead")/2)
	card.heading:SetJustifyH("LEFT")
	card.heading:SetWordWrap(false)
	card.heading:SetText(title)
	A.style(card.heading,"label","cardTitle")

	card.headRule=card:CreateTexture(nil,"BORDER")
	card.headRule:SetPoint("TOPLEFT",card,"TOPLEFT",0,-A.metric("cardHead"))
	card.headRule:SetPoint("TOPRIGHT",card,"TOPRIGHT",0,-A.metric("cardHead"))
	card.headRule:SetHeight(1)

	if opts.link then
		local link=CreateFrame("Button",nil,card)
		link:SetHeight(A.metric("cardHead"))
		link:SetPoint("RIGHT",card,"TOPRIGHT",-A.metric("setCardPad"),-A.metric("cardHead")/2)
		link.label=link:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
		link.label:SetPoint("RIGHT",link,"RIGHT",0,0)
		link.label:SetJustifyH("RIGHT")
		link.label:SetWordWrap(false)
		local linkText=opts.link.text
		link.label:SetText(linkText)
		link.linkText=linkText
		link:SetScript("OnClick",opts.link.onClick)
		link:SetScript("OnEnter",function(self)
			self.over=true
			A.style(self.label,"cardLabel","text")
		end)
		link:SetScript("OnLeave",function(self)
			self.over=false
			A.style(self.label,"cardLabel","dim")
		end)
		A.style(link.label,"cardLabel","dim")
		link:SetWidth(A.textRoom(link.label,linkText))
		card.link=link
	end

	card.rows={}
	frame.cards[#frame.cards+1]=card
	return card
end

local function cardRow(card,label,opts)
	opts=opts or{}
	local row=CreateFrame("Frame",nil,card)
	row.card=card
	row.rowHeight=A.metric("cardRow")
	row:SetHeight(row.rowHeight)
	row.sub=opts.sub and true or false
	row.indent=A.metric("setCardPad")+(row.sub and A.metric("cardIndent")or 0)
	row.key=opts.key
	row.parentKey=opts.parent
	row.rightInset=opts.rightInset or 0
	row.inertControls={}
	row.liveControls={}
	row.inertRegions={}

	row.label=row:CreateFontString(nil,"ARTWORK","GameFontHighlightSmall")
	row.label:SetPoint("LEFT",row,"LEFT",row.indent,0)
	row.label:SetJustifyH("LEFT")
	row.label:SetWordWrap(false)
	row.label:SetText(label or"")
	row.find=(opts.find or label or""):lower()

	if row.sub then
		row.childRule=row:CreateTexture(nil,"ARTWORK")
		row.childRule:SetWidth(2)
		row.childRule:SetPoint("TOPLEFT",row,"TOPLEFT",A.metric("setCardPad"),0)
		row.childRule:SetPoint("BOTTOMLEFT",row,"BOTTOMLEFT",A.metric("setCardPad"),0)
	end

	row.rule=row:CreateTexture(nil,"BORDER")
	row.rule:SetPoint("BOTTOMLEFT",row,"BOTTOMLEFT",0,0)
	row.rule:SetPoint("BOTTOMRIGHT",row,"BOTTOMRIGHT",0,0)
	row.rule:SetHeight(1)

	if opts.tip then
		row.tipSpec={label=label,tip=opts.tip}
		row:EnableMouse(true)
		row:SetScript("OnEnter",function(self)
			showTip(self,self.tipSpec)
		end)
		row:SetScript("OnLeave",hideTip)
	end

	card.rows[#card.rows+1]=row
	return row
end

local function atRight(row,control,beside)
	control:ClearAllPoints()
	if beside then
		control:SetPoint("RIGHT",beside,"LEFT",-A.metric("pillGap"),0)
	else
		control:SetPoint("RIGHT",row,"RIGHT",-A.metric("setCardPad"),0)
	end
	row.rightControls=row.rightControls or{}
	row.rightControls[#row.rightControls+1]=control
end

local function rowNeed(row)
	local need=row.indent+A.labelRoom(row.label:GetText()or"")+(row.rightInset or 0)
	local controls=row.rightControls or{}
	if#controls>0 then
		need=need+A.metric("pillGap")+A.metric("setCardPad")
		for i=1,#controls do
			need=need+(controls[i]:GetWidth()or 0)+(controls[i].wordRoom or 0)
		end
		need=need+A.metric("pillGap")*(#controls-1)
	end
	return need
end

local function anchorPreview(card,kept,rowsEnd)
	local top,bottom
	for i=1,#card.rows do
		local row=card.rows[i]
		if row.sub and kept[row]then
			top=top or row.laidTop
			bottom=row.laidTop+row.rowHeight
		end
	end
	if top==nil then
		top,bottom=rowsEnd,rowsEnd
	end
	local pad=A.metric("setCardPad")
	local need=A.metric("announceCardPreviewH")+pad*2
	if bottom-top<need then
		bottom=top+need
	end
	local center=(top+bottom)/2
	local host=card.previewHost
	host:ClearAllPoints()
	host:SetPoint("RIGHT",card,"TOPRIGHT",-pad,-center)
	card.previewCenter=center
	return bottom
end

local function layoutCard(card,query)
	local y=A.metric("cardHead")
	local kept=0
	local keep={}
	local parents={}
	for i=1,#card.rows do
		local row=card.rows[i]
		local matches=query==""or row.find:find(query,1,true)~=nil
		if row.wanted~=false and matches then
			keep[row]=true
			if row.parentKey then
				parents[row.parentKey]=true
			end
		end
	end
	for i=1,#card.rows do
		local row=card.rows[i]
		if row.key and parents[row.key]and row.wanted~=false then
			keep[row]=true
		end
	end
	for i=1,#card.rows do
		local row=card.rows[i]
		if keep[row]then
			row:ClearAllPoints()
			row:SetPoint("TOPLEFT",card,"TOPLEFT",0,-y)
			row:SetPoint("TOPRIGHT",card,"TOPRIGHT",-(row.rightInset or 0),-y)
			row:Show()
			row.laidTop=y
			y=y+row.rowHeight
			kept=kept+1
		else
			row:Hide()
		end
	end
	if kept==0 then
		card:Hide()
		card.laidHeight=0
		return 0,0
	end
	if card.previewHost then
		y=math.max(y,anchorPreview(card,keep,y))
	end
	card:SetHeight(y)
	card:Show()
	card.laidHeight=y
	return y,kept
end

local function layoutPane(pane,query)
	local y,kept=0,0
	for i=1,#pane.cards do
		local card=pane.cards[i]
		local height,rows=layoutCard(card,query)
		if height>0 then
			if kept>0 then
				y=y+A.metric("setCardGap")
			end
			card:ClearAllPoints()
			card:SetPoint("TOPLEFT",pane,"TOPLEFT",0,-y)
			card:SetPoint("TOPRIGHT",pane,"TOPRIGHT",0,-y)
			y=y+height
			kept=kept+rows
		end
	end
	return y,kept
end

local function buildButton(parent,text,onClick)
	return A.pill(parent,text,onClick,A.metric("actionMin"))
end

local function switchRow(card,spec,opts)
	opts=opts or{}
	opts.key=spec.key
	opts.parent=spec.parent
	local row=cardRow(card,spec.label,opts)
	local toggle=buildToggle(row)
	atRight(row,toggle)
	toggle.spec=spec
	toggle.label=row.label
	toggle.row=row
	row.toggle=toggle
	row.inertControls[#row.inertControls+1]=toggle
	A.style(row.label,"cardText","text")

	toggle:SetScript("OnClick",function(self)
		local wanted=self:GetChecked()and true or false
		if not self.spec.set(wanted)then
			A.say("no database, so the setting could not be stored")
		end
		A.refreshOptionsWindow()
	end)
	toggle:SetScript("OnEnter",function(self)
		showTip(self,self.spec)
	end)
	toggle:SetScript("OnLeave",hideTip)
	row:EnableMouse(true)
	row:SetScript("OnEnter",function(self)
		showTip(self,spec)
	end)
	row:SetScript("OnLeave",hideTip)
	return row,toggle
end

local function buildStepper(frame,row,getter,setter,range,suffix)
	local stepper={row=row,label=row.label,getter=getter,range=range}
	stepper.suffix=suffix
	A.style(row.label,row.sub and"cardLabel"or"cardText",row.sub and"dim"or"text")

	local function step(by)
		if row.inert then
			return
		end
		local min,max,size=range()
		local want=(getter()or 0)+by*size
		if want<min or want>max then
			return
		end
		setter(want)
	end

	stepper.plus=A.pill(row,"+",function()step(1)end,A.metric("stepMin"))
	atRight(row,stepper.plus)

	stepper.figure=row:CreateFontString(nil,"ARTWORK","GameFontNormalSmall")
	stepper.figure:SetWidth(A.metric("stepFigure"))
	stepper.figure:SetJustifyH("CENTER")
	stepper.figure:SetWordWrap(false)
	atRight(row,stepper.figure,stepper.plus)
	A.style(stepper.figure,"numberSmall","text")

	stepper.minus=A.pill(row,"-",function()step(-1)end,A.metric("stepMin"))
	atRight(row,stepper.minus,stepper.figure)

	row.inertControls[#row.inertControls+1]=stepper.minus
	row.inertControls[#row.inertControls+1]=stepper.plus
	row.inertRegions[#row.inertRegions+1]=stepper.figure
	if row.tipSpec then
		hoverTip(stepper.minus,row.tipSpec)
		hoverTip(stepper.plus,row.tipSpec)
	end

	frame.steppers[#frame.steppers+1]=stepper
	return stepper
end

local function paintStepper(stepper)
	local min,max=stepper.range()
	local at=stepper.getter()
	stepper.figure:SetText(("%d%s"):format(at,stepper.suffix or"%"))
	pcall(at<=min and stepper.minus.Disable or stepper.minus.Enable,stepper.minus)
	pcall(at>=max and stepper.plus.Disable or stepper.plus.Enable,stepper.plus)
end

local function segmentRow(card,label,choices,onPick,opts)
	local row=cardRow(card,label,opts)
	A.style(row.label,row.sub and"cardLabel"or"cardText",row.sub and"dim"or"text")
	local track=A.segment(row,choices,onPick)
	atRight(row,track)
	row.segment=track
	for i=1,#track.children do
		row.inertControls[#row.inertControls+1]=track.children[i]
		if row.tipSpec then
			hoverTip(track.children[i],row.tipSpec)
		end
	end
	row.inertRegions[#row.inertRegions+1]=track
	return row,track
end

local function buttonRow(card,label,text,onClick,opts)
	local row=cardRow(card,label,opts)
	row.find=row.find.." "..tostring(text):lower()
	A.style(row.label,row.sub and"cardLabel"or"cardText",row.sub and"dim"or"text")
	local button=buildButton(row,text,onClick)
	atRight(row,button)
	row.button=button
	row.inertControls[#row.inertControls+1]=button
	row.liveControls[#row.liveControls+1]=button
	if row.tipSpec then
		hoverTip(button,row.tipSpec)
	end
	return row,button
end

local ROW_BUILDERS={}

ROW_BUILDERS.theme={
	build=function(frame,card)
		local labels={}
		for _,choice in ipairs(A.themeChoices())do
			labels[choice.value]=choice.label
		end
		local row,track=segmentRow(card,"Look",A.themeChoices(),function(value)
			if A.setTheme(value)then
				outcome({("window appearance set to %s"):format(tostring(labels[value]):lower())})
			end
		end,{
			key="theme",
			find="look appearance theme",
			tip="Match the game keeps the client's frame art and colors. Dark panel is the addon's "
				.."own flat dark window.",
		})
		frame.themeSegment=track
		return row
	end,
}

ROW_BUILDERS.windowScale={
	build=function(frame,card)
		local row=cardRow(card,"Scale",{
			key="windowScale",
			find="scale size zoom",
			tip="Draw every PvPHistory window larger or smaller, text included, from 70% to 150%. "
				.."The announcement keeps its own size.",
		})
		frame.windowScaleStepper=buildStepper(frame,row,A.windowScaleApplied,function(value)
			A.setWindowScale(value,"window")
		end,A.windowScaleRange,"%")
		return row
	end,
}

ROW_BUILDERS.overlayCount={
	parent="overlayShown",
	build=function(frame,card)
		local row=cardRow(card,"Matches shown",{
			sub=true,
			key="overlayCount",
			parent="overlayShown",
			tip="How many of the newest results the bar shows, one cell per match.",
		})
		frame.overlayCount=buildStepper(frame,row,A.overlayCount,A.setOverlayCount,
			A.overlayCountRange,"")
		return row
	end,
}

ROW_BUILDERS.overlayOpacity={
	parent="overlayShown",
	build=function(frame,card)
		local row=cardRow(card,"Background",{
			sub=true,
			key="overlayOpacity",
			parent="overlayShown",
			tip="How dark the bar's ground draws behind its cells.",
		})
		frame.overlayOpacity=buildStepper(frame,row,A.overlayOpacity,A.setOverlayOpacity,
			A.overlayOpacityRange,"%")
		return row
	end,
}

ROW_BUILDERS.minimapPosition={
	parent="minimap",
	build=function(frame,card)
		local row=cardRow(card,"Position",{
			sub=true,
			key="minimapPosition",
			parent="minimap",
			find="position minimap button reset",
			tip="Where the button stands around the minimap, or the point a Shift-drag placed it "
				.."at. Reset puts it back on the edge.",
		})
		A.style(row.label,"cardLabel","dim")
		frame.minimapPositionRow=row
		frame.resetPosition=buildButton(row,"Reset",function()
			if A.resetMinimap()then
				outcome({"minimap button reset to its default position and shown"})
			else
				outcome({"the minimap button could not be built on this client"},"fault")
			end
		end)
		atRight(row,frame.resetPosition)
		row.inertControls[#row.inertControls+1]=frame.resetPosition
		hoverTip(frame.resetPosition,row.tipSpec)
		frame.angle=row:CreateFontString(nil,"ARTWORK","GameFontDisableSmall")
		frame.angle:SetPoint("RIGHT",frame.resetPosition,"LEFT",-A.metric("pillGap")*2,0)
		frame.angle:SetJustifyH("RIGHT")
		frame.angle:SetWordWrap(false)
		A.style(frame.angle,"numberSmall","dim")
		row.inertRegions[#row.inertRegions+1]=frame.angle
		return row
	end,
}

ROW_BUILDERS.geometryReset={
	build=function(frame,card)
		local row,reset=buttonRow(card,"Size and place of every window","Reset all",function()
			if type(A.resetGeometryLines)~="function"then
				outcome({"the window geometry did not load, so nothing could be forgotten"},"fault")
				return
			end
			local lines=A.resetGeometryLines()
			for i=1,#lines do
				A.say(lines[i])
			end
			outcome(lines)
		end,{
			key="geometryReset",
			find="size and place of every window reset",
			tip="Put every PvPHistory window back at its normal size and place, the match windows "
				.."beside the match list, and the results bar where it starts.",
		})
		frame.resetGeometry=reset
		return row
	end,
}

ROW_BUILDERS.announceShape={
	parent="announce",
	build=function(frame,card)
		local choices={}
		for _,choice in ipairs(A.announceShapeChoices())do
			choices[#choices+1]={value=choice.value,label=choice.label,said=choice.said}
		end
		local row,shape=segmentRow(card,"Layout",choices,function(value)
			local said
			for _,choice in ipairs(choices)do
				if choice.value==value then
					said=choice.said
				end
			end
			if A.setAnnounceShape(value)then
				outcome({("the announcement is drawn %s"):format(tostring(said))})
			else
				outcome({"no database, so the shape could not be stored"},"fault")
			end
		end,{
			sub=true,
			key="announceShape",
			parent="announce",
			find="layout shape side by side one column",
			tip="Side by side puts both sides on one line where they fit the screen. One column "
				.."stacks one side under the other.",
		})
		frame.announceShapeSegment=shape
		return row
	end,
}

ROW_BUILDERS.announceTime={
	parent="announce",
	build=function(frame,card)
		local row=cardRow(card,"Shown for",{
			sub=true,
			key="announceTime",
			parent="announce",
			find="shown for time seconds",
			tip="How long the announcement stays on screen, as a share of its usual time.",
		})
		frame.announceTime=buildStepper(frame,row,A.announceTime,A.setAnnounceTime,A.announceTimeRange)
		return row
	end,
}

ROW_BUILDERS.announceSize={
	parent="announce",
	build=function(frame,card)
		local row=cardRow(card,"Size",{
			sub=true,
			key="announceSize",
			parent="announce",
			tip="How large the announcement draws. A crowded one is drawn smaller to fit the screen.",
		})
		frame.announceSize=buildStepper(frame,row,A.announceSize,A.setAnnounceSize,A.announceSizeRange)
		return row
	end,
}

ROW_BUILDERS.announceOpacity={
	parent="announce",
	build=function(frame,card)
		local row=cardRow(card,"Opacity",{
			sub=true,
			key="announceOpacity",
			parent="announce",
			tip="How solid the announcement's pills draw over the world behind them.",
		})
		frame.announceOpacity=buildStepper(frame,row,A.announceOpacity,A.setAnnounceOpacity,
			A.announceOpacityRange)
		return row
	end,
}

ROW_BUILDERS.announcePosition={
	parent="announce",
	build=function(frame,card)
		local position=cardRow(card,"Position",{
			sub=true,
			key="announcePosition",
			parent="announce",
			find="position lock preview reset",
			tip="Lock keeps the announcement where it is. Preview draws it where it draws, so you "
				.."can drag it somewhere else. Reset puts it back.",
		})
		A.style(position.label,"cardLabel","dim")
		frame.announcePosition=position

		frame.announceReset=buildButton(position,"Reset",function()
			if A.resetAnnouncePosition()then
				outcome({"the announcement is back a sixth of the screen down"})
			else
				outcome({"no database, so the position could not be cleared"},"fault")
			end
		end)
		atRight(position,frame.announceReset)

		frame.announcePreview=buildButton(position,"Preview",function()
			local toggled=A.announcePreviewToggle()
			if toggled=="ended"then
				outcome({"the preview is put away and the position it was dragged to is kept"})
			elseif toggled=="shown"then
				outcome({"the announcement is drawn where it draws. Drag it, and Escape or "
					.."this button puts it away"})
			else
				outcome({"the preview could not be drawn on this client"},"fault")
			end
		end)
		atRight(position,frame.announcePreview,frame.announceReset)

		frame.announceLock=buildToggle(position)
		atRight(position,frame.announceLock,frame.announcePreview)
		local lockLabel=position:CreateFontString(nil,"ARTWORK","GameFontHighlightSmall")
		frame.announceLock.label=lockLabel
		lockLabel:SetPoint("RIGHT",frame.announceLock.word,"LEFT",-A.metric("pillGap"),0)
		lockLabel:SetText("Lock")
		A.style(lockLabel,"cardLabel","dim")
		frame.announceLock:SetScript("OnClick",function(self)
			local locked=self:GetChecked()and true or false
			if A.setAnnounceLocked(locked)then
				outcome({locked and"the announcement is fixed where it is"
					or"the announcement can be dragged here, and while a match draws it"})
			else
				outcome({"no database, so the setting could not be stored"},"fault")
			end
			A.refreshOptionsWindow()
		end)
		for _,control in ipairs({frame.announceReset,frame.announcePreview,frame.announceLock})do
			position.inertControls[#position.inertControls+1]=control
			position.liveControls[#position.liveControls+1]=control
		end
		hoverTip(frame.announceReset,position.tipSpec)
		hoverTip(frame.announcePreview,position.tipSpec)
		frame.announceLock:SetScript("OnEnter",function(self)
			showTip(self,position.tipSpec)
		end)
		frame.announceLock:SetScript("OnLeave",hideTip)
		position.inertRegions[#position.inertRegions+1]=lockLabel
		return position
	end,
}

local PAGE_CARDS={
	general={
		{title="APPEARANCE",rows={"theme","windowScale"}},
		{title="RESULTS ON SCREEN",rows={"overlayShown","overlayCount","overlayOpacity","overlayCombat"}},
		{title="MINIMAP AND LOGIN",rows={"minimap","minimapPosition","loginLine"}},
		{title="WINDOWS",rows={"rememberTab","closeWithMain","geometryReset"},link="clientPanel"},
	},
	alerts={
		{title="IN A GROUP",rows={"alerts","groupNotes"}},
		{title="AT THE GATES",rows={"announce","announceShape","announceTime","announceSize",
			"announceOpacity","announcePosition"},preview=true},
		{title="AFTER A MATCH",rows={"postGame","openAfterMatch"}},
	},
	notes={
		{title="WHERE YOUR NOTES SHOW",rows={"tooltip","contextMenu"}},
		{title="IN CHAT",rows={"chatMark"}},
		{title="ON NAMEPLATES",rows={"sight"}},
	},
	recording={
		{title="WHAT IS RECORDED",rows={"duels","hold"}},
		{title="GROUP FINDER",rows={"finder","finderDock"}},
	},
}

local function openClientPanel()
	local opened,why=A.openOptions()
	if opened then
		return
	end
	if why=="combat"then
		outcome({"the client's settings panel cannot be opened in combat. The same switches "
			.."are on the pages at the left"},"fault")
		return
	end
	outcome({"the settings panel could not be opened. The same switches are on the "
		.."pages at the left"},"fault")
end

local function buildGatePreview(frame,card)
	local host=CreateFrame("Frame",nil,card)
	host:SetSize(A.metric("announceCardPreviewW"),A.metric("announceCardPreviewH"))
	host:SetPoint("RIGHT",card,"TOPRIGHT",-A.metric("setCardPad"),
		-(A.metric("cardHead")+A.metric("setCardPad")+A.metric("announceCardPreviewH")/2))
	host:EnableMouse(false)
	card.previewHost=host
	frame.gatePreview=host
	local inset=A.metric("announceCardPreviewW")+A.metric("setCardPad")*2
	for _,row in ipairs(card.rows)do
		if row.sub then
			row.rightInset=inset
		end
	end
end

local function buildPage(frame,pane,page)
	local cards=PAGE_CARDS[page]or{}
	pane.cards={}
	for c=1,#cards do
		local spec=cards[c]
		local opts={}
		if spec.link=="clientPanel"then
			opts.link={text="Game settings panel",onClick=openClientPanel}
		end
		local card=buildCard(frame,pane,spec.title,opts)
		for r=1,#spec.rows do
			local name=spec.rows[r]
			local index=SWITCH_INDEX[name]
			if index then
				local switch=SWITCHES[index]
				local _,toggle=switchRow(card,switch,{sub=switch.parent~=nil,find=switch.find})
				frame.checks[index]=toggle
			elseif ROW_BUILDERS[name]then
				ROW_BUILDERS[name].build(frame,card)
			end
		end
		if spec.preview then
			buildGatePreview(frame,card)
		end
		pane.cards[#pane.cards+1]=card
	end
end

local function buildDiagnosticCard(frame,pane)
	local card=buildCard(frame,pane,"DIAGNOSTIC")
	frame.diagnostics={}

	local _,debugCheck=switchRow(card,DIAGNOSTIC_SWITCHES[1])
	frame.debugCheck=debugCheck
	frame.diagnostics[#frame.diagnostics+1]=debugCheck
	local _,debugTextCheck=switchRow(card,DIAGNOSTIC_SWITCHES[2])
	frame.debugTextCheck=debugTextCheck
	frame.diagnostics[#frame.diagnostics+1]=debugTextCheck

	local ringRow,export=buttonRow(card,"The ring","Copy",function()
		local ok,lines=A.openDebugExport()
		outcome(lines,not ok and"fault"or nil)
	end,{sub=true,find="the ring copy"})
	frame.ringRow=ringRow
	frame.debugExport=export

	local storeRow,store=buttonRow(card,"Read the state of the store","Open",function()
		if not A.toggleStoreWindow()then
			outcome({"the store panel could not be opened on this client"},"fault")
		end
	end,{sub=true})
	frame.storeRow=storeRow
	frame.storePanel=store

	pane.cards={card}
	return card
end

local function layoutDiagnostics(frame)
	local recording=A.debugEnabled()==true
	local holding=A.debugHeld()>0
	frame.debugTextCheck.row.wanted=recording
	frame.ringRow.wanted=recording or holding
	frame.storeRow.wanted=recording
	if not recording and A.storeWindowShown()then
		A.hideStoreWindow()
	end
end

local function buildSlotCard(parent,slot)
	local card=CreateFrame("Button",nil,parent)
	card.slot=slot
	card:SetHeight(A.metric("slotCard"))
	card.ground=card:CreateTexture(nil,"BACKGROUND")
	card.ground:SetAllPoints(card)
	card.edges=A.hairlineEdges(card)
	local pad=A.metric("setCardPad")
	card.name=card:CreateFontString(nil,"ARTWORK","GameFontNormalSmall")
	card.name:SetPoint("TOPLEFT",card,"TOPLEFT",pad,-pad/2-2)
	card.name:SetText(A.restoreSlotName(slot))
	card.dot=card:CreateTexture(nil,"ARTWORK")
	card.dot:SetSize(A.metric("optionsDot"),A.metric("optionsDot"))
	card.dot:SetPoint("TOPRIGHT",card,"TOPRIGHT",-pad,-pad/2-4)
	card.count=card:CreateFontString(nil,"ARTWORK","GameFontHighlightSmall")
	card.count:SetPoint("TOPLEFT",card.name,"BOTTOMLEFT",0,-2)
	card.count:SetPoint("RIGHT",card,"RIGHT",-pad,0)
	card.count:SetJustifyH("LEFT")
	card.count:SetWordWrap(false)
	card.written=card:CreateFontString(nil,"ARTWORK","GameFontDisableSmall")
	card.written:SetPoint("TOPLEFT",card.count,"BOTTOMLEFT",0,-2)
	card.written:SetPoint("RIGHT",card,"RIGHT",-pad,0)
	card.written:SetJustifyH("LEFT")
	card.written:SetWordWrap(false)

	card:SetScript("OnClick",function(self)
		A.optionsChooseSlot(self.slot)
	end)
	return card
end

local function counted(n,one,many)
	return("%d %s"):format(n,n==1 and one or many)
end

local function writtenText(at)
	local day,clock=A.shortDayText(at),A.clockKey(at)
	if day and clock then
		return("%s, %s"):format(day,clock)
	end
	return tostring(at)
end

local function buildStorageSection(frame,pane)
	frame.storageOutcome=pane:CreateFontString(nil,"ARTWORK","GameFontDisableSmall")
	frame.storageOutcome:SetJustifyH("LEFT")
	frame.storageOutcome:SetWordWrap(false)
	frame.storageOutcomeDot=pane:CreateTexture(nil,"ARTWORK")
	frame.storageOutcomeDot:SetSize(A.metric("optionsDot"),A.metric("optionsDot"))
	frame.storageOutcomeDot:Hide()

	local meter=buildCard(frame,pane,"STORED HISTORY")
	frame.meterCard=meter
	frame.meterFigure=meter:CreateFontString(nil,"ARTWORK","GameFontNormalHuge")
	frame.meterFigure:SetJustifyH("LEFT")
	frame.meterWord=meter:CreateFontString(nil,"ARTWORK","GameFontHighlightSmall")
	frame.meterWord:SetText("of the file's room used")
	frame.meterRoom=meter:CreateFontString(nil,"ARTWORK","GameFontHighlightSmall")
	frame.meterRoom:SetJustifyH("RIGHT")
	frame.meterRoom:SetWordWrap(false)
	frame.meterTrack=meter:CreateTexture(nil,"ARTWORK")
	frame.meterTrack:SetHeight(A.metric("meterBar"))
	frame.meterFill=meter:CreateTexture(nil,"OVERLAY")
	frame.meterFill:SetHeight(A.metric("meterBar"))
	frame.meterUsed=meter:CreateFontString(nil,"ARTWORK","GameFontHighlightSmall")
	frame.meterUsed:SetJustifyH("LEFT")
	frame.meterStored=meter:CreateFontString(nil,"ARTWORK","GameFontHighlightSmall")
	frame.meterStored:SetJustifyH("RIGHT")
	frame.byteRows={}
	for i=1,3 do
		local reading={}
		reading.key=meter:CreateFontString(nil,"ARTWORK","GameFontNormalSmall")
		reading.key:SetWidth(A.metric("optionsReadingKey"))
		reading.key:SetJustifyH("LEFT")
		reading.key:SetWordWrap(false)
		reading.clause=meter:CreateFontString(nil,"ARTWORK","GameFontHighlightSmall")
		reading.clause:SetJustifyH("LEFT")
		reading.clause:SetWordWrap(false)
		frame.byteRows[i]=reading
	end

	local backup=buildCard(frame,pane,"BACK UP AND RESTORE")
	frame.backupCard=backup
	frame.lastCopy=backup:CreateFontString(nil,"ARTWORK","GameFontHighlightSmall")
	frame.lastCopy:SetJustifyH("LEFT")
	frame.lastCopy:SetWordWrap(false)
	frame.backup=buildButton(backup,"Back up now",function()
		local result=A.takeBackup()
		if result.ok then
			local line=("backup written: %d %s, %d bytes encoded")
				:format(result.matches,result.matches==1 and"match"or"matches",result.bytes)
			if result.replaced then
				line=line..(", replacing one holding %d"):format(result.replaced)
			end
			A.say(line)
			outcome({line},nil,true)
			return
		end
		local line
		if result.reason=="smaller"then
			line=("backup refused: %d %s stored against %d in the backup, which is not "
				.."overwritten"):format(result.matches,
				result.matches==1 and"match"or"matches",result.held)
		elseif result.reason=="no-codec"then
			line="this client provides no encoding surface, so nothing can be backed up"
		else
			line=("backup did not run: %s"):format(tostring(result.reason))
		end
		A.say(line)
		outcome({line},"fault")
	end)
	frame.slotButtons={}
	for _,slot in ipairs({"current","pinned"})do
		frame.slotButtons[#frame.slotButtons+1]=buildSlotCard(backup,slot)
	end
	frame.readCopy=buildButton(backup,"Read the chosen copy",function()
		local _,lines,readable=A.openRestore(restoreSlot,false)
		restoreRead=nil
		if readable==true then
			holdRestoreRead(restoreSlot)
		end
		outcome(lines,readable~=true and"fault"or nil)
	end)
	frame.restoreCopy=buildButton(backup,"Restore the chosen copy",function()
		if not restoreArmedNow()then
			A.refreshOptionsWindow()
			return
		end
		restoreRead=nil
		local restored,lines=A.openRestore(restoreSlot,true)
		outcome(lines,not restored and"fault"or nil)
	end)

	local transfer=buildCard(frame,pane,"OUT OF THE GAME")
	frame.transferCard=transfer
	local exportLabel="A text copy you can keep or move"
	local _,export=buttonRow(transfer,exportLabel,"Export",function()
		local ok,lines=A.openExport()
		outcome(lines,not ok and"fault"or nil)
	end,{find=exportLabel.." export backup copy text"})
	frame.export=export
	local importLabel="Bring in a text copy"
	local _,import=buttonRow(transfer,importLabel,"Import",function()
		local ok,lines=A.openImport()
		outcome(lines,not ok and"fault"or nil)
	end,{find=importLabel.." import restore bring"})
	frame.import=import
	local rebuildLabel="Rebuild who you met"
	local _,rebuild=buttonRow(transfer,rebuildLabel,"Rebuild the index",function()
		local walked=A.rebuildIndex()
		if not walked then
			outcome({"no database. nothing was rebuilt"},"fault")
			return
		end
		local line=("rebuilt the player index from %d stored %s: %d players, %d encounters")
			:format(walked.matches,walked.matches==1 and"match"or"matches",
				walked.players,walked.encounters)
		A.say(line)
		outcome({line},nil,true)
	end,{find=rebuildLabel.." rebuild index who you met"})
	frame.rebuild=rebuild
	for _,row in ipairs(transfer.rows)do
		A.style(row.label,"cardLabel","dim")
	end

	frame.eraseBox=CreateFrame("Frame",nil,pane)
	frame.eraseBox.ground=frame.eraseBox:CreateTexture(nil,"BACKGROUND")
	frame.eraseBox.ground:SetAllPoints(frame.eraseBox)
	frame.eraseBox.edges=A.hairlineEdges(frame.eraseBox)
	local pad=A.metric("setCardPad")
	frame.eraseHeading=frame.eraseBox:CreateFontString(nil,"ARTWORK","GameFontNormalSmall")
	frame.eraseHeading:SetPoint("TOPLEFT",frame.eraseBox,"TOPLEFT",pad,-pad)
	frame.eraseHeading:SetText("ERASE EVERYTHING STORED")
	frame.eraseLine=frame.eraseBox:CreateFontString(nil,"ARTWORK","GameFontHighlightSmall")
	frame.eraseLine:SetPoint("TOPLEFT",frame.eraseHeading,"BOTTOMLEFT",0,-2)
	frame.eraseLine:SetJustifyH("LEFT")
	frame.eraseLine:SetWordWrap(false)
	frame.erase=buildButton(frame.eraseBox,"Erase",function()
		local opened,lines=A.openResetConfirm()
		outcome(lines,not opened and"fault"or nil)
	end)
	frame.erase:SetPoint("RIGHT",frame.eraseBox,"RIGHT",-pad,0)
	A.setControlTone(frame.erase,"loss")

	pane.cards={meter,backup,transfer}
end

local function eraseHeight()
	return A.metric("setCardPad")*2+A.fontSize("label")+2+A.fontSize("cardLabel")
end

local function layoutStorage(frame)
	local pane=frame.panes.data
	local width=frame.paneWidth or 0
	local pad=A.metric("setCardPad")
	local gap=A.metric("setCardGap")
	local y=0

	local mark=lastOutcomeRegister and A.registerMark(lastOutcomeRegister)or nil
	local left=mark and(A.metric("optionsDot")+A.metric("optionsDotGap"))or 0
	frame.storageOutcome:ClearAllPoints()
	frame.storageOutcome:SetPoint("TOPLEFT",pane,"TOPLEFT",left,-y)
	frame.storageOutcome:SetPoint("TOPRIGHT",pane,"TOPRIGHT",0,-y)
	frame.storageOutcomeDot:ClearAllPoints()
	frame.storageOutcomeDot:SetPoint("TOPRIGHT",frame.storageOutcome,"TOPLEFT",-A.metric("optionsDotGap"),
		-(A.fontSize("rowNote")-A.metric("optionsDot"))/2)
	y=y+A.metric("optionsRow")

	local meter=frame.meterCard
	local inner=A.metric("cardHead")+pad
	local figureH=A.fontSize("numberHuge")
	frame.meterFigure:ClearAllPoints()
	frame.meterFigure:SetPoint("TOPLEFT",meter,"TOPLEFT",pad,-inner)
	frame.meterWord:ClearAllPoints()
	frame.meterWord:SetPoint("BOTTOMLEFT",frame.meterFigure,"BOTTOMRIGHT",pad,0)
	local roomText=frame.meterRoom:GetText()or""
	local roomUnder=false
	frame.meterRoom:ClearAllPoints()
	if roomText~=""then
		local need=A.textRoom(frame.meterFigure,frame.meterFigure:GetText()or"")+pad
			+A.textRoom(frame.meterWord,frame.meterWord:GetText()or"")+pad
			+A.textRoom(frame.meterRoom,roomText)
		roomUnder=need>width-pad*2
		frame.meterRoomPlace=roomUnder and"under"or"row"
	else
		frame.meterRoomPlace=nil
	end
	if not roomUnder then
		frame.meterRoom:SetPoint("BOTTOMRIGHT",meter,"TOPRIGHT",-pad,-(inner+figureH))
	end
	inner=inner+figureH+8
	frame.meterTrack:ClearAllPoints()
	frame.meterTrack:SetPoint("TOPLEFT",meter,"TOPLEFT",pad,-inner)
	frame.meterTrack:SetPoint("TOPRIGHT",meter,"TOPRIGHT",-pad,-inner)
	frame.meterFill:ClearAllPoints()
	frame.meterFill:SetPoint("TOPLEFT",frame.meterTrack,"TOPLEFT",0,0)
	local trackWidth=math.max(width-pad*2,0)
	frame.meterFill:SetWidth(math.max(math.floor(trackWidth*(frame.meterShare or 0)+0.5),1))
	inner=inner+A.metric("meterBar")+8
	frame.meterUsed:ClearAllPoints()
	frame.meterUsed:SetPoint("TOPLEFT",meter,"TOPLEFT",pad,-inner)
	frame.meterStored:ClearAllPoints()
	frame.meterStored:SetPoint("TOPRIGHT",meter,"TOPRIGHT",-pad,-inner)
	inner=inner+A.metric("optionsNote")
	if roomUnder then
		frame.meterRoom:SetPoint("TOPRIGHT",meter,"TOPRIGHT",-pad,-inner)
		inner=inner+A.metric("optionsNote")
	end
	for i=1,#frame.byteRows do
		local reading=frame.byteRows[i]
		if i<=(frame.byteFilled or 0)then
			reading.key:ClearAllPoints()
			reading.key:SetPoint("TOPLEFT",meter,"TOPLEFT",pad,-inner)
			reading.clause:ClearAllPoints()
			reading.clause:SetPoint("TOPLEFT",reading.key,"TOPRIGHT",0,0)
			reading.clause:SetPoint("TOPRIGHT",meter,"TOPRIGHT",-pad,-inner)
			reading.key:Show()
			reading.clause:Show()
			inner=inner+A.metric("optionsNote")
		else
			reading.key:Hide()
			reading.clause:Hide()
		end
	end
	local meterH=inner+pad
	meter:ClearAllPoints()
	meter:SetPoint("TOPLEFT",pane,"TOPLEFT",0,-y)
	meter:SetPoint("TOPRIGHT",pane,"TOPRIGHT",0,-y)
	meter:SetHeight(meterH)
	meter:Show()
	y=y+meterH+gap

	local backupW=math.floor((width-gap)*BACKUP_SHARE)
	local widest=0
	for _,row in ipairs(frame.transferCard.rows)do
		widest=math.max(widest,rowNeed(row))
	end
	local stacked=widest>width-gap-backupW
	if stacked then
		backupW=width
	end
	frame.storageStacked=stacked
	local backup=frame.backupCard
	local slotTop=A.metric("cardHead")+pad+A.metric("controlHeight")+10
	frame.backup:ClearAllPoints()
	frame.backup:SetPoint("TOPRIGHT",backup,"TOPRIGHT",-pad,-(A.metric("cardHead")+pad))
	frame.lastCopy:ClearAllPoints()
	frame.lastCopy:SetPoint("LEFT",backup,"TOPLEFT",pad,
		-(A.metric("cardHead")+pad+A.metric("controlHeight")/2))
	local slotW=math.max(math.floor((backupW-pad*2-10)/2),0)
	for i=1,#frame.slotButtons do
		local card=frame.slotButtons[i]
		card:ClearAllPoints()
		card:SetPoint("TOPLEFT",backup,"TOPLEFT",pad+(i-1)*(slotW+10),-slotTop)
		card:SetWidth(slotW)
	end
	local buttonsTop=slotTop+A.metric("slotCard")+10
	frame.restoreCopy:ClearAllPoints()
	frame.restoreCopy:SetPoint("TOPRIGHT",backup,"TOPRIGHT",-pad,-buttonsTop)
	frame.readCopy:ClearAllPoints()
	frame.readCopy:SetPoint("RIGHT",frame.restoreCopy,"LEFT",-A.metric("pillGap"),0)
	local backupH=buttonsTop+A.metric("controlHeight")+pad
	backup:ClearAllPoints()
	backup:SetPoint("TOPLEFT",pane,"TOPLEFT",0,-y)
	backup:SetWidth(backupW)
	backup:SetHeight(backupH)
	backup:Show()

	local transfer=frame.transferCard
	local transferH=layoutCard(transfer,"")
	if stacked then
		y=y+backupH+gap
	end
	if transferH>0 then
		transfer:ClearAllPoints()
		transfer:SetPoint("TOPLEFT",pane,"TOPLEFT",stacked and 0 or backupW+gap,-y)
		transfer:SetPoint("TOPRIGHT",pane,"TOPRIGHT",0,-y)
	end
	y=y+(stacked and transferH or math.max(backupH,transferH))

	frame.eraseBox:ClearAllPoints()
	frame.eraseBox:SetPoint("BOTTOMLEFT",pane,"BOTTOMLEFT",0,0)
	frame.eraseBox:SetPoint("BOTTOMRIGHT",pane,"BOTTOMRIGHT",0,0)
	frame.eraseBox:SetHeight(eraseHeight())
	frame.eraseBox:Show()

	return y+gap+eraseHeight()
end

local function layoutStorageFind(frame,query)
	local pane=frame.panes.data
	frame.meterCard:Hide()
	frame.backupCard:Hide()
	frame.eraseBox:Hide()
	local transfer=frame.transferCard
	local height,kept=layoutCard(transfer,query)
	if height>0 then
		transfer:ClearAllPoints()
		transfer:SetPoint("TOPLEFT",pane,"TOPLEFT",0,0)
		transfer:SetPoint("TOPRIGHT",pane,"TOPRIGHT",0,0)
	end
	return height,kept
end

local function layoutSections(frame)
	local query=findQuery()
	local gap=A.metric("setCardGap")
	local width=frame.paneWidth or 0
	local rows=0
	local hostHeight=0
	local order=pageOrder()
	local kept={}

	if query~=""then
		local y=0
		for i=1,#order do
			local value=order[i]
			local pane=frame.panes[value]
			pane:ClearAllPoints()
			pane:SetWidth(width)
			local height,left
			if value=="data"then
				height,left=layoutStorageFind(frame,query)
			else
				height,left=layoutPane(pane,query)
			end
			if height>0 then
				if y>0 then
					y=y+gap
				end
				pane:SetPoint("TOPLEFT",frame.paneHost,"TOPLEFT",0,-y)
				pane:SetHeight(height)
				pane:Show()
				y=y+height
				rows=rows+left
				kept[#kept+1]=value
			else
				pane:Hide()
			end
		end
		hostHeight=y
	else
		for i=1,#order do
			local value=order[i]
			local pane=frame.panes[value]
			pane:ClearAllPoints()
			if value==chosenPage then
				pane:SetPoint("TOPLEFT",frame.paneHost,"TOPLEFT",0,0)
				pane:SetWidth(width)
				local height,left
				if value=="data"then
					height=layoutStorage(frame)
					local _,transferRows=layoutCard(frame.transferCard,"")
					left=transferRows
					height=math.max(height,frame.paneRoom or 0)
				else
					height,left=layoutPane(pane,"")
				end
				pane:SetHeight(height)
				pane:Show()
				hostHeight=height
				rows=left
			else
				pane:Hide()
			end
		end
	end

	frame.rowsLeft=rows
	frame.contentHeight=hostHeight
	frame.pagesKept=query~=""and table.concat(kept,",")or nil
	frame.columnRoom=math.max(hostHeight,1)
	frame.paneHost:SetHeight(frame.columnRoom)
	A.setSegmentChosen(frame.sections,query==""and chosenPage or nil)
end

local function paneWidthFor(frame,width)
	local listWidth=frame.sections and frame.sections:GetWidth()or 0
	local body=(type(width)=="number"and width or 0)-A.metric("margin")*2
	return math.max(body-listWidth-A.metric("sectionGap"),0)
end

local function layoutOutcome(frame)
	local mark=lastOutcomeRegister and A.registerMark(lastOutcomeRegister)or nil
	local onStorage=storageShowing()
	local left=mark and(A.metric("optionsDot")+A.metric("optionsDotGap"))or 0

	frame.outcome:ClearAllPoints()
	frame.outcome:SetPoint("BOTTOMLEFT",frame,"BOTTOMLEFT",left,0)
	frame.outcome:SetPoint("BOTTOMRIGHT",frame,"BOTTOMRIGHT",0,0)
	frame.outcome:SetShown(not onStorage)
	frame.storageOutcome:SetShown(onStorage)

	if mark then
		frame.outcomeDot:SetColorTexture(A.color(mark))
		frame.storageOutcomeDot:SetColorTexture(A.color(mark))
	end
	frame.outcomeDot:SetShown(mark~=nil and not onStorage)
	frame.storageOutcomeDot:SetShown(mark~=nil and onStorage)
end

local function paintDiagnosticLink(frame)
	local link=frame.diagnosticLink
	local showing=chosenPage==DIAGNOSTIC and findQuery()==""
	link.showing=showing
	A.style(link.label,"cardLabel",(showing or link.over)and"dim"or"dimmer")
end

local function buildBody(host)
	local frame=CreateFrame("Frame",FRAME_NAME,host)
	frame:SetAllPoints(host)
	frame:Show()

	frame.host=host
	frame.cards={}
	frame.checks={}
	frame.steppers={}
	frame.panes={}

	window=frame

	local function offScreen()
		frame.onScreen=false
		frame.heldErase=nil
	end
	pcall(host.HookScript,host,"OnHide",offScreen)
	local okParent,parent=pcall(host.GetParent,host)
	if okParent and parent and parent.HookScript then
		pcall(parent.HookScript,parent,"OnHide",offScreen)
	end

	local function pickSection(value)
		return A.timedSwitch("section",chosenPage,function()
			chosenPage=value
			findText=""
			if frame.find then
				pcall(frame.find.SetText,frame.find,"")
			end
			if frame.paneScroll then
				pcall(frame.paneScroll.SetVerticalScroll,frame.paneScroll,0)
			end
			local started=A.switchClock()
			A.refreshOptionsWindow(storageShowing())
			A.switchPhase("options",started)
		end,function()
			return chosenPage
		end)
	end
	frame.pickSection=pickSection
	frame.sections=A.sectionList(frame,PAGES,pickSection)
	local listWidth=frame.sections:GetWidth()

	frame.find=A.entry(frame)
	frame.find:SetSize(listWidth,A.metric("controlHeight"))
	frame.find:SetPoint("TOPLEFT",frame,"TOPLEFT",0,0)
	frame.find:SetText(findText)
	frame.find:SetScript("OnTextChanged",function(self)
		local text=self:GetText()or""
		if text~=findText then
			findText=text
			A.refreshOptionsWindow(nil,true)
		end
	end)
	frame.find:SetScript("OnEscapePressed",function(self)
		self:ClearFocus()
	end)
	A.entryPlaceholder(frame.find,"find a setting")
	frame.sections:SetPoint("TOPLEFT",frame.find,"BOTTOMLEFT",0,-A.metric("sectionGap"))

	local link=CreateFrame("Button",nil,frame)
	link:SetSize(listWidth,A.metric("optionsRow"))
	link:SetPoint("BOTTOMLEFT",frame,"BOTTOMLEFT",0,A.windowFootBand())
	link.label=link:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
	link.label:SetPoint("LEFT",link,"LEFT",A.metric("sectionIndent"),0)
	link.label:SetJustifyH("LEFT")
	link.label:SetWordWrap(false)
	link.label:SetText("Diagnostic")
	link.linkValue=DIAGNOSTIC
	link:SetScript("OnClick",function()
		pickSection(DIAGNOSTIC)
	end)
	link:SetScript("OnEnter",function(self)
		self.over=true
		paintDiagnosticLink(frame)
	end)
	link:SetScript("OnLeave",function(self)
		self.over=false
		paintDiagnosticLink(frame)
	end)
	frame.diagnosticLink=link

	local paneWidth=paneWidthFor(frame,A.windowWidth())
	frame.paneWidth=paneWidth

	frame.header=CreateFrame("Frame",nil,frame)
	frame.header:SetPoint("TOPLEFT",frame,"TOPLEFT",listWidth+A.metric("sectionGap"),0)
	frame.header:SetPoint("TOPRIGHT",frame,"TOPRIGHT",0,0)
	frame.header:SetHeight(A.metric("paneHeader"))
	frame.paneTitle=frame.header:CreateFontString(nil,"ARTWORK","GameFontNormalLarge")
	frame.paneTitle:SetPoint("LEFT",frame.header,"LEFT",0,0)
	frame.paneTitle:SetJustifyH("LEFT")
	frame.paneTitle:SetWordWrap(false)

	frame.paneScroll=CreateFrame("ScrollFrame",nil,frame,"ScrollFrameTemplate")
	frame.paneScroll:SetPoint("TOPLEFT",frame.header,"BOTTOMLEFT",0,0)
	frame.paneScroll:SetWidth(paneWidth)

	if type(frame.paneScroll.ScrollBar)=="table"then
		pcall(frame.paneScroll.ScrollBar.SetHideIfUnscrollable,frame.paneScroll.ScrollBar,true)
	end

	local function gone()
		if type(A.announcePlateRefresh)=="function"then
			A.announcePlateRefresh("window-hidden")
		end
	end
	local function came()
		if type(A.announcePlateRefresh)=="function"then
			A.announcePlateRefresh("window-shown")
		end
	end
	host:HookScript("OnHide",gone)
	host:HookScript("OnShow",came)
	local history=host.GetParent and host:GetParent()or nil
	if type(history)=="table"and type(history.HookScript)=="function"then
		history:HookScript("OnHide",gone)
		history:HookScript("OnShow",came)
	end

	frame.paneHost=CreateFrame("Frame",nil,frame.paneScroll)
	frame.paneHost:SetWidth(paneWidth)
	frame.paneHost:SetHeight(paneWidth)
	frame.paneScroll:SetScrollChild(frame.paneHost)

	local order=pageOrder()
	for i=1,#order do
		local value=order[i]
		local pane=CreateFrame("Frame",nil,frame.paneHost)
		pane:SetWidth(paneWidth)
		pane:Hide()
		pane.cards={}
		frame.panes[value]=pane
		if value=="data"then
			buildStorageSection(frame,pane)
		elseif value==DIAGNOSTIC then
			buildDiagnosticCard(frame,pane)
		else
			buildPage(frame,pane,value)
		end
	end

	frame.paneRoom=frame.sections:GetHeight()or 0
	frame.paneScroll:SetHeight(frame.paneRoom)

	frame.outcome=frame:CreateFontString(nil,"ARTWORK","GameFontDisableSmall")
	frame.outcome:SetPoint("BOTTOMLEFT",frame,"BOTTOMLEFT",0,0)
	frame.outcome:SetPoint("BOTTOMRIGHT",frame,"BOTTOMRIGHT",0,0)
	frame.outcome:SetJustifyH("LEFT")
	frame.outcome:SetWordWrap(false)
	A.style(frame.outcome,"rowNote","dimmer")

	frame.outcomeDot=frame:CreateTexture(nil,"ARTWORK")
	frame.outcomeDot:SetSize(A.metric("optionsDot"),A.metric("optionsDot"))
	frame.outcomeDot:SetPoint("TOPRIGHT",frame.outcome,"TOPLEFT",
		-A.metric("optionsDotGap"),
		-(A.fontSize("rowNote")-A.metric("optionsDot"))/2)
	frame.outcomeDot:Hide()

	layoutSections(frame)

	local built=0
	for i=1,#order do
		if frame.panes[order[i]]then
			built=built+1
		end
	end
	A.trace("build",{kind="settings",state="built",panes=built,checks=#frame.checks},"ui")

	return frame
end

local function windowOrNil()
	if window then
		return window
	end
	if not surface()then
		return nil
	end
	local host=type(A.windowPageHost)=="function"and A.windowPageHost("settings")or nil
	if not host then
		return nil
	end
	local built=A.buildWindowOnce("settings",buildBody,host)
	if not built then
		window=nil
		return nil
	end
	window=built
	return window
end

local function paintCard(card)
	card.ground:SetColorTexture(A.color("inset"))
	for i=1,#card.edges do
		card.edges[i]:SetColorTexture(A.color("insetEdge"))
	end
	card.headRule:SetColorTexture(A.color("insetEdge"))
	A.style(card.heading,"label","cardTitle")
	if card.link then
		A.style(card.link.label,"cardLabel",card.link.over and"text"or"dim")
	end
	for i=1,#card.rows do
		local row=card.rows[i]
		row.rule:SetColorTexture(A.color("divider"))
		if row.childRule then
			row.childRule:SetColorTexture(A.color("hairline"))
		end
	end
end

local function paintMeter(frame,size)
	local readings=A.sizeReadings(size)
	local byKey={}
	for i=1,#readings do
		byKey[readings[i].key]=readings[i].clause
	end
	local figure,share=A.sizeShare(size)
	local band=A.sizeBand(size)
	frame.meterShare=share
	frame.meterText,frame.meterBand=figure,band

	frame.meterFigure:SetText(figure)
	A.style(frame.meterFigure,"numberHuge",band)
	A.style(frame.meterWord,"cardLabel","dim")
	frame.meterRoom:SetText(byKey.ROOM or"")
	A.style(frame.meterRoom,"cardLabel","dim")
	frame.meterTrack:SetColorTexture(A.color("divider"))
	frame.meterFill:SetColorTexture(A.color(band))
	frame.meterUsed:SetText(byKey.USED or"")
	A.style(frame.meterUsed,"cardLabel","dim")
	frame.meterStored:SetText(byKey.STORED or"")
	A.style(frame.meterStored,"cardLabel","dim")

	local filled=0
	local drawnAbove={ROOM=true,USED=true,STORED=true}
	for i=1,#readings do
		local row=nil
		if not drawnAbove[readings[i].key]then
			filled=filled+1
			row=frame.byteRows[filled]
		end
		if row then
			row.key:SetText(readings[i].key)
			row.clause:SetText(readings[i].clause)
			A.style(row.key,"label","dim")
			A.style(row.clause,"note","text")
		end
	end
	for i=filled+1,#frame.byteRows do
		frame.byteRows[i].key:SetText("")
		frame.byteRows[i].clause:SetText("")
	end
	frame.byteFilled=filled
end

local function paintBackup(frame)
	local _,_,_,at=A.restoreSlotText("current")
	frame.lastCopy:SetText(at and("Last copy written "..writtenText(at))or"No copy written yet")
	A.style(frame.lastCopy,"cardLabel","dim")

	for i=1,#frame.slotButtons do
		local card=frame.slotButtons[i]
		local _,sentence,matches,written=A.restoreSlotText(card.slot)
		local chosen=card.slot==restoreSlot
		card.chosen=chosen
		A.style(card.name,"cardText","bright")
		if matches then
			card.count:SetText(counted(matches,"match","matches"))
			card.written:SetText("written "..writtenText(written))
		else
			card.count:SetText(sentence)
			card.written:SetText("")
		end
		A.style(card.count,"numberSmall","text")
		A.style(card.written,"cardLabel","dim")
		card.ground:SetColorTexture(A.color(chosen and"selection"or"panelDeep"))
		for e=1,#card.edges do
			card.edges[e]:SetColorTexture(A.color(chosen and"accent"or"hairline"))
		end
		card.dot:SetColorTexture(A.color(chosen and"accent"or"dimmer"))
	end

	if restoreArmedNow()then
		frame.restoreCopy:Enable()
	else
		frame.restoreCopy:Disable()
	end
end

local function paintErase(frame,reuse)
	local preview
	if reuse and frame.heldErase~=nil then
		preview=frame.heldErase.preview
	else
		preview=A.resetPreview()
		frame.heldErase={preview=preview}
	end
	if preview then
		frame.eraseLine:SetText(("%s, %s and %s. Asks twice."):format(
			counted(preview.matches,"match","matches"),
			counted(preview.players,"player","players"),
			counted(preview.noted,"note","notes")))
	else
		frame.eraseLine:SetText("Asks twice.")
	end
	frame.eraseCounts=preview
	A.style(frame.eraseHeading,"label","loss")
	A.style(frame.eraseLine,"cardLabel","dim")
	local r,g,b=A.color("loss")
	frame.eraseBox.ground:SetColorTexture(r,g,b,0.06)
	for i=1,#frame.eraseBox.edges do
		frame.eraseBox.edges[i]:SetColorTexture(r,g,b,0.45)
	end
end

local function paintHeader(frame)
	local label=pageLabel(chosenPage)or"General"
	if findQuery()~=""then
		label="Every page"
	end
	frame.paneTitle:SetText(label)
	A.style(frame.paneTitle,"headingLarge","bright")
end

local function paintChildRows(frame)
	local inert={}
	for i=1,#frame.cards do
		local card=frame.cards[i]
		for r=1,#card.rows do
			local row=card.rows[r]
			if row.parentKey then
				local live=parentOn(row.parentKey)
				row.inert=not live
				for c=1,#row.inertControls do
					local control=row.inertControls[c]
					if not live then
						pcall(control.Disable,control)
					end
				end
				if live then
					for c=1,#row.liveControls do
						pcall(row.liveControls[c].Enable,row.liveControls[c])
					end
				end
				for g=1,#row.inertRegions do
					pcall(row.inertRegions[g].SetAlpha,row.inertRegions[g],live and 1 or 0.4)
				end
				if row.toggle==nil then
					A.style(row.label,row.sub and"cardLabel"or"cardText",live and(row.sub and"dim"or"text")
						or"dimmer")
				end
				if not live then
					inert[#inert+1]=row.key or"?"
				end
			end
		end
		if card.previewHost then
			card.previewHost:SetAlpha(parentOn("announce")and 1 or 0.4)
		end
	end
	return inert
end

local function inertShowing(frame)
	local out={}
	for i=1,#frame.cards do
		local card=frame.cards[i]
		if card.pane and card.pane:IsShown()and card:IsShown()then
			for r=1,#card.rows do
				local row=card.rows[r]
				if row.parentKey and row.inert and row:IsShown()then
					out[#out+1]=row.key or"?"
				end
			end
		end
	end
	if#out==0 then
		return nil
	end
	return table.concat(out,",")
end

function A.refreshOptionsWindow(walk,finding)
	if not window then
		return false
	end
	if not window.showingPaint
		and not(type(A.windowBodyShown)=="function"and A.windowBodyShown()=="settings")then
		return false
	end

	local counts=A.optionsSwitchCounts()

	A.containedPaint("options/diagnostics-layout",layoutDiagnostics,window)

	for i=1,#window.cards do
		A.containedPaint("options/card",paintCard,window.cards[i])
	end

	for i=1,#window.checks do
		local check=window.checks[i]
		A.containedPaint("options/check",function()
			check:SetChecked(check.spec.get()and true or false)
			local available=check.spec.parent==nil or parentOn(check.spec.parent)
			if available then
				check:Enable()
			else
				check:Disable()
			end
			local sub=check.row and check.row.sub
			A.style(check.label,sub and"cardLabel"or"cardText",available and(sub and"dim"or"text")
				or"dimmer")
		end)
	end

	for i=1,#window.diagnostics do
		local check=window.diagnostics[i]
		A.containedPaint("options/diagnostic",function()
			check:SetChecked(check.spec.get()and true or false)
			A.style(check.label,"cardText","text")
		end)
	end

	A.containedPaint("options/header",paintHeader,window)
	A.containedPaint("options/diagnostic-link",paintDiagnosticLink,window)

	A.containedPaint("options/theme",A.setSegmentChosen,window.themeSegment,A.theme())
	A.containedPaint("options/announce-shape",function()
		A.setSegmentChosen(window.announceShapeSegment,A.announceShape())
	end)

	for i=1,#(window.steppers or{})do
		A.containedPaint("options/stepper",paintStepper,window.steppers[i])
	end

	A.containedPaint("options/preview",function()
		window.announcePreview:SetText(A.announcePreviewActive()and"End preview"or"Preview")
		A.fitControl(window.announcePreview,A.metric("actionMin"))
	end)

	A.containedPaint("options/lock",function()
		window.announceLock:SetChecked(A.announceLocked())
		A.style(window.announceLock.label,"cardLabel","dim")
	end)

	A.containedPaint("options/child-rows",paintChildRows,window)

	A.containedPaint("options/minimap",function()
		local state=A.minimapState()
		if not state.available then
			window.angle:SetText("This client has no minimap.")
		elseif state.free then
			window.angle:SetText(("Placed at %.2f, %.2f on the screen.")
				:format(A.unitFigure(state.free.x)or state.free.x,A.unitFigure(state.free.y)or state.free.y))
		else
			window.angle:SetText(A.minimapAngleText(state.angle)or tostring(state.angle))
		end
		A.style(window.angle,"numberSmall",window.minimapPositionRow.inert and"dimmer"or"dim")
		if state.available and not window.minimapPositionRow.inert then
			window.resetPosition:Enable()
		else
			window.resetPosition:Disable()
		end
	end)

	A.containedPaint("options/meter",function()
		if walk or(window.heldSize==nil and window.onScreen and storageShowing())then
			window.heldSize=A.storedSize()
		end
		if window.heldSize~=nil then
			paintMeter(window,window.heldSize)
		end
	end)
	A.containedPaint("options/backup",paintBackup,window)
	if storageShowing()then
		A.containedPaint("options/erase",paintErase,window,finding)
	end

	A.containedPaint("options/gate-preview",function()
		if window.gatePreview and type(A.announceCardPreview)=="function"then
			A.announceCardPreview(window.gatePreview)
		end
	end)

	A.containedPaint("options/find",function()
		if(window.find:GetText()or"")~=findText then
			window.find:SetText(findText)
		end
	end)

	A.containedPaint("options/sections",layoutSections,window)

	A.containedPaint("options/outcome",function()
		A.style(window.outcome,"rowNote","dimmer")
		window.outcome:SetText(lastOutcome or"")
		A.style(window.storageOutcome,"rowNote","dimmer")
		window.storageOutcome:SetText(lastOutcome or"")
		window.sections.rule:SetColorTexture(A.color("divider"))
	end)

	A.containedPaint("options/outcome-layout",layoutOutcome,window)

	local onStorage=storageShowing()
	A.trace("options",{
		section=chosenPage,
		counts=countsText(counts),
		find=findQuery()~=""and"typed"or nil,
		rows=window.rowsLeft,
		pages=window.pagesKept,
		inert=inertShowing(window),
		content=A.unitFigure(window.contentHeight),
		room=A.unitFigure(window.paneRoom),
		meter=onStorage and window.meterText or nil,
		band=onStorage and window.meterBand or nil,
		meterRoom=onStorage and window.meterRoomPlace or nil,
		slot=onStorage and restoreSlot or nil,
	},"ui")

	return true
end

function A.optionsChooseSlot(slot)
	if slot~="current"and slot~="pinned"then
		return false
	end
	if restoreSlot~=slot then
		restoreSlot=slot
		restoreRead=nil
	end
	A.refreshOptionsWindow()
	return true
end

function A.optionsFind(text)
	findText=type(text)=="string"and text or""
	if window and window.find then
		pcall(window.find.SetText,window.find,findText)
	end
	if not A.refreshOptionsWindow(nil,true)then
		return nil
	end
	return window.rowsLeft
end

function A.optionsState()
	return findText,restoreSlot,restoreArmedNow(),chosenPage
end

local function sizeBody(frame,width,height)
	local paneWidth=paneWidthFor(frame,width)
	frame.paneScroll:SetWidth(paneWidth)
	frame.paneHost:SetWidth(paneWidth)
	frame.paneWidth=paneWidth

	if type(height)=="number"and height>0 then
		local viewport=height-A.metric("headerHeight")-A.bodyFloor()-A.windowFootBand()
			-A.metric("paneHeader")
		if viewport>0 then
			frame.paneRoom=viewport
			frame.paneScroll:SetHeight(viewport)
		end
	end
end

function A.paintPageBody(page,width,height)
	if page=="about"then
		return type(A.paintAboutBody)=="function"and A.paintAboutBody(width)or false
	end
	if page~="settings"or not window then
		return false
	end
	pcall(sizeBody,window,width,height)
	local arriving=not window.onScreen
		or window.paintedWidth~=width or window.paintedHeight~=height
	window.onScreen=true
	window.paintedWidth,window.paintedHeight=width,height
	window.showingPaint=true
	local ok,painted=pcall(A.refreshOptionsWindow,arriving and storageShowing())
	window.showingPaint=nil
	return ok and painted or false
end

function A.dropHeldStoredSize()
	if window then
		window.heldSize=nil
		window.heldErase=nil
	end
end

function A.showOptionsWindow(word)
	local frame=windowOrNil()
	if not frame then
		return false
	end

	local shown=type(A.showWindowBody)=="function"and A.showWindowBody("settings")or false

	local db=A.db()
	A.trace("open",{
		source="options",
		n=db and#db.matches or nil,
		section=chosenPage,
		word=word,
		viewport=A.unitFigure(frame.paneRoom),
		column=A.unitFigure(frame.columnRoom),
		theme=A.theme(),
	},"ui")

	return shown
end

function A.settingsRefused(why)
	if why=="combat"then
		return"the settings could not be opened: the settings would not build and the client's "
			.."settings panel cannot be opened in combat. /pvph alert and /pvph minimap set the same "
			.."switches"
	end
	return"the settings could not be opened. /pvph alert and /pvph minimap set the same switches"
end

function A.openSettings()
	if A.showOptionsWindow()then
		return"window"
	end
	if A.openOptions then
		local opened,why=A.openOptions()
		A.trace("fallback",{source="settings",state=opened and"client"or"refused",
			reason=why},"ui")
		if opened then
			return"client"
		end
		return nil,why
	end
	return nil
end

local function windowShown()
	if not window then
		return false
	end
	return type(A.windowBodyShown)=="function"and A.windowBodyShown()=="settings"
end

function A.hideOptionsWindow()
	if not windowShown()then
		return false
	end
	return type(A.hideWindow)=="function"and A.hideWindow()or false
end

function A.optionsWindowShown()
	return windowShown()
end

function A.optionsSections()
	local out=pageOrder()
	for _,word in ipairs({"all","window","minimap","history","storage"})do
		out[#out+1]=word
	end
	return out
end

function A.showOptionsSection(word,target)
	local page=A.optionsPageFor(word,target)
	if page==nil then
		return false
	end
	local typed=word
	if word=="all"and target~=nil then
		typed="all "..tostring(target)
	end
	if windowShown()and window.pickSection then
		window.pickSection(page)
		local db=A.db()
		A.trace("open",{
			source="options",
			n=db and#db.matches or nil,
			section=chosenPage,
			word=typed,
			viewport=A.unitFigure(window.paneRoom),
			column=A.unitFigure(window.columnRoom),
			theme=A.theme(),
		},"ui")
		return true
	end
	chosenPage=page
	findText=""
	local built=windowOrNil()
	if built and built.paneScroll then
		pcall(built.paneScroll.SetVerticalScroll,built.paneScroll,0)
	end
	return A.showOptionsWindow(typed)
end

function A.toggleOptionsWindow()
	if windowShown()then
		return A.hideOptionsWindow()
	end
	return A.showOptionsWindow()
end

function A.toggleSettings()
	if windowShown()then
		A.toggleOptionsWindow()
		return"closed"
	end
	return A.openSettings()
end
