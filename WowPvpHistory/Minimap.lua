-- WowPvpHistory 0.75.26
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

local function uiState(create)
	local db=A.db()
	if not db then
		return nil
	end
	if create then
		db.ui=type(db.ui)=="table"and db.ui or{}
	end
	return type(db.ui)=="table"and db.ui or nil
end

local function finite(value)
	return type(value)=="number"and value==value and value~=math.huge and value~=-math.huge
end

local function storedAngle()
	local ui=uiState(false)
	local angle=ui and tonumber(ui.minimapAngle)
	if not finite(angle)then
		return DEFAULT_ANGLE
	end
	return angle%360
end

local DEGREE_SIGN="\194\176"

function A.minimapAngleText(angle)
	if not finite(angle)then
		return nil
	end
	return("%d%s"):format(math.floor(angle+0.5)%360,DEGREE_SIGN)
end

local function storedFree()
	local ui=uiState(false)
	local held=ui and ui.minimapFree
	if type(held)~="table"then
		return nil
	end
	local x,y=tonumber(held.x),tonumber(held.y)
	if not(finite(x)and finite(y))then
		return nil
	end
	return x,y
end

local function storedShown()
	local ui=uiState(false)
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

		local ui=uiState(true)
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

		local ui=uiState(true)
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
	local ok,menu=pcall(MenuUtil.CreateContextMenu,A.shownRegion(owner),function(_,root)
		built,players=buildRows(root)
	end)

	if ok and menu~=nil then
		return true,nil,built,players
	end
	return false,"no-menu",built,players
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

local heldNewest=nil

local function newestMatch(character)
	local recorder=A.barRecorder(character)
	local mark=A.storeMark()
	local held=heldNewest
	if held and held.recorder==recorder and A.storeMarkSame(held.mark,mark)then
		return held.record
	end
	local record=A.lastMatch(nil,nil,recorder,nil,true)
	heldNewest={mark=mark,recorder=recorder,record=record}
	return record
end

local MAX_LINES=9

local SLOT_FLOOR=20

local SLOT_WORDS={"morning","afternoon","early evening","evening","late evening","late night"}

local heldSlot=nil

local heldSession=nil

local heldFigures={}

local function heldFigure(name,compute,a,b)
	local db=A.db()
	local mark=A.storeMark()
	local left=db and type(db.incomplete)=="table"and#db.incomplete or 0
	local day=A.dayKey(A.stamp())
	local since=A.weekStartEpoch()
	local key=name.."|"..tostring(a).."|"..tostring(b)
	local held=heldFigures[key]
	if held and A.storeMarkSame(held.mark,mark)and held.left==left and held.day==day
		and held.since==since then
		return held.value
	end
	local value=compute(a,b)
	heldFigures[key]={mark=mark,left=left,day=day,since=since,value=value}
	return value
end

local function newestSession()
	if type(A.newestSession)~="function"then
		return nil
	end
	local mark=A.storeMark()
	local held=heldSession
	if held and A.storeMarkSame(held.mark,mark)then
		return held.session
	end
	local _,session=A.newestSession()
	heldSession={mark=mark,session=session}
	return session
end

local function bestSlot(recorder)
	local mark=A.storeMark()
	local held=heldSlot
	if held and held.recorder==recorder and A.storeMarkSame(held.mark,mark)then
		return held.slot
	end
	local cells={}
	for i=1,#SLOT_WORDS do
		cells[i]={won=0,decided=0}
	end
	for _,record in ipairs(mark.matches or{})do
		if type(record)=="table"and A.recordedBy(record,recorder)then
			local outcome,_,derived=A.recordVerdict(record)
			local _,block=A.heatCell(A.recordEpoch(record))
			if outcome~=nil and block~=nil and cells[block]then
				local cell=cells[block]
				cell.decided=cell.decided+1
				if outcome=="win"and not A.recordLevel(record,outcome,derived)then
					cell.won=cell.won+1
				end
			end
		end
	end
	local slot=nil
	for i,cell in ipairs(cells)do
		if cell.decided>=SLOT_FLOOR then
			local rate=cell.won/cell.decided
			if slot==nil or rate>slot.rate then
				slot={word=SLOT_WORDS[i],rate=rate,decided=cell.decided}
			end
		end
	end
	heldSlot={mark=mark,recorder=recorder,slot=slot}
	return slot
end

local function pair(left,right,leftColor,rightColor)
	return{left=left,right=right,leftColor=leftColor,rightColor=rightColor}
end

local function tone(name)
	local r,g,b=A.color(name)
	return{r,g,b}
end

function A.minimapLines()
	local accent,dim,dimmer,text=tone("accent"),tone("dim"),tone("dimmer"),tone("text")
	local hint=pair("Click: match history "..A.HEAD_DOT.." Right click: menu",nil,dimmer)
	local lines={}

	local character=A.barCharacter()
	local newest=character~=nil and newestMatch(character)or nil
	if newest==nil or newest.format==nil then
		lines[1]=pair(A.displayName(),nil,accent)
		lines[2]=hint
		return lines,{state="empty"}
	end
	local recorder=A.barRecorder(character)

	local format=newest.format
	local meta={format=format,id=newest.id}
	lines[#lines+1]=pair(A.displayName(),A.formatLabel(format),accent,dim)

	local figures=A.todayFigures(format,character)or{}
	if figures.rating~=nil or figures.change~=nil then
		local parts={}
		if figures.rating~=nil then
			local rr,rg,rb=A.ratingTint(format,figures.rating)
			parts[#parts+1]=A.channelEscape(rr,rg,rb)..tostring(figures.rating).."|r"
			meta.ratingFigure=figures.rating
		end
		if figures.change~=nil then
			parts[#parts+1]=A.colorEscape(figures.changeTone or"dim")..figures.change.." today|r"
			meta.today=figures.change
		end
		lines[#lines+1]=pair("Rating",table.concat(parts," "),dim,text)
	end

	if figures.record~=nil then
		lines[#lines+1]=pair("Today",figures.record,dim,tone(figures.recordTone or"dim"))
		meta.record=figures.record
	end

	do
		local session=newestSession()
		local recap=session and type(A.sessionRecap)=="function"and A.sessionRecap(session,nil,recorder)or nil
		local held=recap and recap.record or nil
		if held==nil and session then
			local row={decided=0,wins=0,draws=0}
			for _,entry in ipairs(session.entries or{})do
				local record=entry.kind~="incomplete"and entry.subject or nil
				if type(record)=="table"and A.recordedBy(record,recorder)then
					A.tallyVerdict(row,record)
				end
			end
			held={wins=row.wins,losses=row.decided-row.wins-row.draws,draws=row.draws}
		end
		if session and held and held.wins+held.losses+held.draws>0 then
			local words=A.sessionRecapRecordText and A.sessionRecapRecordText(held)
				or("%d-%d"):format(held.wins,held.losses)
			local start=session.startEpoch or session.startStamp
			local clock=start and A.clockWords(start)or nil
			if clock then
				words=words..A.colorEscape("dim").." since "..clock.."|r"
			end
			local tint=held.wins>held.losses and"win"or held.wins<held.losses and"loss"or"text"
			lines[#lines+1]=pair("Tonight",words,dim,tone(tint))
			meta.tonight=("%d-%d-%d"):format(held.wins,held.losses,held.draws)
		end
	end

	if type(A.currentStreak)=="function"then
		local run=heldFigure("streak",A.currentStreak,format,recorder)
		if run then
			lines[#lines+1]=pair("Streak",run.word,dim,tone(run.result))
			meta.streak=run.word
		end
	end

	if type(A.tierDistance)=="function"and figures.rating~=nil then
		local distance,why=A.tierDistance(format,figures.rating)
		if distance then
			lines[#lines+1]=pair("Next tier",("%d below %s"):format(distance.points,distance.tier),dim,accent)
			meta.nextTier=distance.points
		else
			meta.nextTier=why
		end
	end

	if type(A.goalProgress)=="function"and type(A.weekGoal)=="function"then
		local goal=A.goalProgress(recorder,heldFigure("weekGoal",A.weekGoal,recorder))
		if goal then
			local parts,met={},true
			for _,held in ipairs(goal.lines)do
				parts[#parts+1]=held.text
				met=met and held.met
			end
			lines[#lines+1]=pair("Week",table.concat(parts,", "),dim,tone(met and"win"or"accent"))
			meta.goal=goal.ring
		end
	end

	local block={pair(" ")}
	local clock=A.clockWords(newest.openedAt or newest.completedAt)
	if clock~=nil then
		block[#block+1]=pair("Last match",clock,dim,dim)
	else
		block[#block+1]=pair("Last match",nil,dim)
	end

	local head=headlineOf(newest)
	local result,side=nil,nil
	if head~=nil then
		local shown=A.matchVerdict(newest)
		local verdict=shown and shown.words or nil
		if verdict~=nil and head.mark~=nil then
			verdict=verdict.." "..A.colorEscape("dim")..head.mark.."|r"
		end
		local resultColor,deltaColor=tone(head.resultTone or"text"),tone(head.deltaTone or"text")
		if verdict~=nil then
			result=pair(verdict,head.delta,resultColor,deltaColor)
		elseif head.delta~=nil then
			result=pair(head.delta,nil,deltaColor)
		end

		local word=A.factionWord(head.faction)
		if word~=nil then
			side=pair(word,head.place,tone(A.factionTone(head.faction)),text)
			side.faction=head.faction
		elseif head.place~=nil then
			side=pair(head.place,nil,text)
		end
	end

	local tail={}
	tail[#tail+1]=result
	tail[#tail+1]=side
	local room=MAX_LINES-(#lines+1)
	for i=1,math.min(#tail,math.max(0,room))do
		block[#block+1]=tail[i]
		meta.faction=tail[i].faction or meta.faction
	end
	for _,held in ipairs(block)do
		lines[#lines+1]=held
	end

	lines[#lines+1]=pair(" ")
	lines[#lines+1]=hint
	local slot=bestSlot(recorder)
	if slot then
		lines[#lines+1]=pair(("You win %d%% of %s matches"):format(A.percentPoints(slot.rate),slot.word),nil,dimmer)
		meta.slot=slot.word
	end
	return lines,meta
end

function A.drawTooltipLines(tooltip,lines)
	local drawn=0
	for _,held in ipairs(lines or{})do
		local l=held.leftColor or{1,1,1}
		if held.right~=nil then
			local r=held.rightColor or l
			tooltip:AddDoubleLine(held.left,held.right,l[1],l[2],l[3],r[1],r[2],r[3])
		else
			tooltip:AddLine(held.left,l[1],l[2],l[3])
		end
		drawn=drawn+1
	end
	return drawn
end

local function showTooltip(owner)
	GameTooltip:SetOwner(owner,"ANCHOR_LEFT")
	if type(GameTooltip.ClearLines)=="function"then
		GameTooltip:ClearLines()
	end
	local lines,meta=A.minimapLines()
	local drawn=A.drawTooltipLines(GameTooltip,lines)
	GameTooltip:Show()
	if meta.state=="empty"then
		A.trace("minimap/tooltip",{state="empty"},"ui")
		return
	end

	A.trace("minimap/tooltip",{
		format=meta.format,
		ratingFigure=meta.ratingFigure,
		today=meta.today,
		record=meta.record,
		id=meta.id,
		faction=meta.faction,
		lines=drawn,
		streak=meta.streak,
		nextTier=meta.nextTier,
		goal=meta.goal,
		tonight=meta.tonight,
		slot=meta.slot,
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

local function showPlaced()
	if not buttonOrNil()then
		return false
	end
	place()
	return(pcall(button.Show,button))
end

function A.setMinimapShown(shown)
	local ui=uiState(not shown)
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

	return showPlaced()
end

function A.minimapShown()
	return storedShown()
end

function A.resetMinimap()
	local ui=uiState(false)
	if ui then
		ui.minimapAngle=nil
		ui.minimapFree=nil
		ui.minimapShown=nil
	end
	notifySetting()
	return showPlaced()
end

function A.applyMinimapState()
	if not storedShown()then
		if button then
			return(pcall(button.Hide,button))
		end
		return true
	end

	return showPlaced()
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
