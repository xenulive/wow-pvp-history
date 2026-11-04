-- WowPvpHistory 0.75.26
-- Author:  Xenu-Sentinels
-- Project: wow-pvp-history
--          https://github.com/xenulive/wow-pvp-history
-- License: MIT, see LICENSE
local _,A=...

local keys={held=nil,combat=false,enabled=false,propagating=nil,listing=false,
	frame=nil,restoreQueued=false,hintForm=nil}

local HANDLED={
	UP="move",DOWN="move",HOME="move",END="move",
	PAGEUP="page",PAGEDOWN="page",
	ENTER="open",LEFT="fold",RIGHT="unfold",
}

local HINT_ARROWS="\226\134\145 \226\134\147 move \194\183 Enter open \194\183 \226\134\144 \226\134\146 session"
	.." \194\183 PgUp PgDn page \194\183 Esc close"
local HINT_WORDS="Up Down move, Enter open, Left Right session, PgUp PgDn page, Esc close"
local HINT_ROLE="rowClock"

local GLOW_GROUND=0.08
local GLOW_DIM=0.4

function A.keyEntryKey(data)
	if type(data)~="table"then
		return nil
	end
	if data.session and data.sessionKey~=nil then
		return"session:"..tostring(data.sessionKey)
	end
	if data.separator or data.detail~=nil or data.id==nil then
		return nil
	end
	return(data.kind=="incomplete"and"incomplete:"or"match:")..tostring(data.id)
end

local function inCombat()
	return keys.combat or(type(InCombatLockdown)=="function"and InCombatLockdown()==true)
end

local function listOf()
	local scroller=keys.frame and keys.frame.list
	if not(scroller and type(scroller.rows)=="table")then
		return nil
	end
	return scroller
end

local function walkable(rows)
	local out={}
	for i=1,#rows do
		local key=A.keyEntryKey(rows[i])
		if key~=nil then
			out[#out+1]={index=i,key=key,data=rows[i]}
		end
	end
	return out
end

local function placeOf(walk)
	for i=1,#walk do
		if walk[i].key==keys.held then
			return i
		end
	end
	keys.held=nil
	return nil
end

function A.keyHighlight()
	local scroller=listOf()
	if scroller~=nil then
		placeOf(walkable(scroller.rows))
	end
	return keys.held
end

local function buildGlow(row)
	local glow=CreateFrame("Frame",nil,row)
	glow:SetAllPoints(row.selection or row)
	glow.ground=glow:CreateTexture(nil,"BACKGROUND")
	glow.ground:SetAllPoints(glow)
	local function edge(a,b,wide)
		local line=glow:CreateTexture(nil,"BORDER")
		line:SetPoint(a,glow,a,0,0)
		line:SetPoint(b,glow,b,0,0)
		if wide then
			line:SetHeight(1)
		else
			line:SetWidth(1)
		end
		return line
	end
	glow.edges={
		edge("TOPLEFT","TOPRIGHT",true),edge("BOTTOMLEFT","BOTTOMRIGHT",true),
		edge("TOPLEFT","BOTTOMLEFT",false),edge("TOPRIGHT","BOTTOMRIGHT",false),
	}
	glow:Hide()
	row.keyGlow=glow
	return glow
end

function A.paintKeyGlow(row,data)
	local key=A.keyEntryKey(data)
	if not(key~=nil and key==keys.held and keys.listing)then
		if row.keyGlow then
			row.keyGlow:Hide()
		end
		return false
	end
	local glow=row.keyGlow or buildGlow(row)
	local r,g,b=A.color("accent")
	glow.ground:SetColorTexture(r,g,b,GLOW_GROUND)
	for i=1,#glow.edges do
		glow.edges[i]:SetColorTexture(r,g,b,1)
	end
	glow:SetAlpha(inCombat()and GLOW_DIM or 1)
	glow:Show()
	return true
end

local function repaintGlows()
	local scroller=listOf()
	local box=scroller and scroller.box
	if not(scroller and box)then
		return
	end
	local rows=scroller.rows
	pcall(box.ForEachFrame,box,function(element)
		local okI,index=pcall(element.GetElementDataIndex,element)
		A.paintKeyGlow(element,okI and rows[index]or nil)
	end)
end

function A.keyRowClicked(row)
	local key=A.keyEntryKey({session=row.sessionKey~=nil,sessionKey=row.sessionKey,
		separator=row.isSeparator,id=row.matchId,kind=row.entryKind})
	if key~=nil then
		keys.held=key
		repaintGlows()
	end
	return key
end

local function propagate(frame,on)
	if inCombat()then
		return false
	end
	local ok=pcall(frame.SetPropagateKeyboardInput,frame,on)
	if ok then
		keys.propagating=on
	end
	return ok
end

local function traceKeyboard(state,reason)
	A.trace("keyboard",{state=state,reason=reason,hintForm=keys.hintForm},"ui")
end

local function sync(frame,active)
	if inCombat()or frame==nil then
		return
	end
	if active~=keys.enabled and pcall(frame.EnableKeyboard,frame,active)then
		keys.enabled=active
		traceKeyboard(active and"on"or"off",active and"none"or"body")
	end
	if active and keys.propagating~=true then
		propagate(frame,true)
	end
end

local function queueRestore(frame)
	if keys.restoreQueued or type(C_Timer)~="table"or type(C_Timer.After)~="function"then
		return
	end
	keys.restoreQueued=true
	C_Timer.After(0,function()
		keys.restoreQueued=false
		propagate(frame,true)
	end)
end

local function pageSize(rows,from,step)
	local room=keys.frame and keys.frame.listRoom
	if type(room)~="number"then
		return 1
	end
	room=A.unitFigure(room)or room
	local used,count,i=0,0,from+step
	while type(rows[i])=="table"do
		local height=rows[i].height
		used=used+((type(height)=="number"and height>=1)and height or A.metric("rowHeight"))
		if(A.unitFigure(used)or used)>room then
			break
		end
		if A.keyEntryKey(rows[i])~=nil then
			count=count+1
		end
		i=i+step
	end
	return math.max(1,count)
end

local function keepInView(scroller)
	local walk=walkable(scroller.rows)
	local at=placeOf(walk)
	if at~=nil then
		A.keepRowInView(scroller,walk[at].index)
	end
end

local function headingOf(rows,index)
	for i=index,1,-1 do
		if type(rows[i])=="table"and rows[i].session and rows[i].sessionKey~=nil then
			return rows[i]
		end
	end
	return nil
end

local function windowOpenOn(kind,id)
	local open=A.matchWindowsOpen()
	local want=kind=="incomplete"and"incomplete"or"match"
	for i=1,#open do
		if open[i].kind==want and open[i].id==id then
			return true
		end
	end
	return false
end

local function move(scroller,walk,key,at)
	local from=at or 0
	local target
	if key=="DOWN"then
		target=from+1
	elseif key=="UP"then
		target=at and at-1 or 1
	elseif key=="HOME"then
		target=1
	elseif key=="END"then
		target=#walk
	elseif key=="PAGEDOWN"then
		target=from+pageSize(scroller.rows,at and walk[at].index or 0,1)
	else
		target=(at or 1)-pageSize(scroller.rows,at and walk[at].index or(#scroller.rows+1),-1)
	end
	target=math.max(1,math.min(#walk,target))
	if target==at then
		return"edge","none"
	end
	keys.held=walk[target].key
	repaintGlows()
	A.keepRowInView(scroller,walk[target].index)
	return HANDLED[key],"none"
end

local function fold(scroller,entry,opening)
	local heading=headingOf(scroller.rows,entry.index)
	if heading==nil then
		return opening and"unfold"or"fold","no-row"
	end
	if(heading.open==true)==opening then
		return"edge","none"
	end
	keys.held=A.keyEntryKey(heading)
	A.foldSession(heading.sessionKey,heading.sessionNewest==true,"key")
	keepInView(scroller)
	return opening and"unfold"or"fold","none"
end

local function enter(scroller,entry)
	local data=entry.data
	if data.session then
		local open=A.foldSession(data.sessionKey,data.sessionNewest==true,"key")
		keepInView(scroller)
		return open and"unfold"or"fold","none"
	end
	A.selectEntry(data.kind,data.id)
	return windowOpenOn(data.kind,data.id)and"open"or"close","none"
end

local function press(frame,key)
	local action=HANDLED[key]
	if inCombat()then
		return action,"combat"
	end
	if type(GetCurrentKeyBoardFocus)=="function"and GetCurrentKeyBoardFocus()~=nil then
		propagate(frame,true)
		return action,"focus"
	end
	propagate(frame,false)
	queueRestore(frame)
	local scroller=listOf()
	local walk=scroller and walkable(scroller.rows)or{}
	if#walk==0 then
		return action,"no-row"
	end
	local at=placeOf(walk)
	if action=="move"or action=="page"then
		return move(scroller,walk,key,at)
	end
	if at==nil then
		return action,"no-row"
	end
	if action=="open"then
		return enter(scroller,walk[at])
	end
	return fold(scroller,walk[at],action=="unfold")
end

local function onKeyDown(frame,key)
	if HANDLED[key]==nil or not keys.listing then
		if keys.propagating==false then
			propagate(frame,true)
		end
		return
	end
	local ok,action,reason=pcall(press,frame,key)
	if not ok then
		A.noteError(("the list key %s did not run: %s"):format(tostring(key),tostring(action)),"window/key")
		action,reason=HANDLED[key],"threw"
	end
	A.trace("key",{key=key,row=keys.held,action=action,reason=reason,
		propagate=keys.propagating},"ui")
end

function A.keyHintBand()
	return A.metric("rowHeadRow")
end

local function hintText()
	A.font(HINT_ROLE)
	local _,everyFamily=A.fontsGated()
	if A.fontsLoaded()==true and everyFamily~=true then
		return HINT_ARROWS,"arrows"
	end
	return HINT_WORDS,"words"
end

function A.paintKeyHint(frame,listing,under)
	local active=listing~=false and A.windowBody()=="history"
	keys.listing=active
	keys.frame=frame
	if not frame.keysWired then
		frame.keysWired=true
		frame:SetScript("OnKeyDown",onKeyDown)
	end
	local hint=frame.keyHint
	if hint==nil then
		hint=frame.listHost:CreateFontString(nil,"OVERLAY","GameFontDisableSmall")
		hint:SetJustifyH("LEFT")
		hint:SetWordWrap(false)
		frame.keyHint=hint
	end
	if not active then
		hint:Hide()
		sync(frame,false)
		return 0
	end
	local height=A.keyHintBand()
	local pad=A.metric("rowLabelPad")
	hint:ClearAllPoints()
	hint:SetPoint("BOTTOMLEFT",frame.listHost,"BOTTOMLEFT",pad,under or 0)
	hint:SetPoint("BOTTOMRIGHT",frame.listHost,"BOTTOMRIGHT",-pad,under or 0)
	hint:SetHeight(height)
	A.style(hint,HINT_ROLE,"dim")
	local text,form=hintText()
	keys.hintForm=form
	hint:SetText(text)
	hint:SetShown(not inCombat())
	sync(frame,true)
	return height
end

A.on("PLAYER_REGEN_DISABLED",function()
	local frame=keys.frame
	if frame~=nil and keys.enabled then
		pcall(frame.EnableKeyboard,frame,false)
	end
	keys.enabled=false
	keys.combat=true
	if frame~=nil and frame.keyHint then
		frame.keyHint:Hide()
	end
	repaintGlows()
	traceKeyboard("off","combat")
end)

local MATCH_STEPS={PAGEUP="prev",PAGEDOWN="next"}

keys.matchFrames={}

function A.matchKeysHeld()
	return inCombat()
end

local function matchPropagate(frame,on)
	if inCombat()then
		return false
	end
	local ok=pcall(frame.SetPropagateKeyboardInput,frame,on)
	if ok then
		frame.keysPropagating=on
	end
	return ok
end

local function matchKeyDown(frame,key)
	local direction=MATCH_STEPS[key]
	if direction==nil then
		if frame.keysPropagating==false then
			matchPropagate(frame,true)
		end
		return
	end
	if not inCombat()and type(GetCurrentKeyBoardFocus)=="function"and GetCurrentKeyBoardFocus()~=nil then
		matchPropagate(frame,true)
		return
	end
	if matchPropagate(frame,false)and type(C_Timer)=="table"and type(C_Timer.After)=="function"then
		C_Timer.After(0,function()
			matchPropagate(frame,true)
		end)
	end
	local ok,err=pcall(A.stepMatchWindow,frame,direction,"key")
	if not ok then
		A.noteError(("the match window key %s did not run: %s"):format(tostring(key),tostring(err)),"match/key")
	end
end

function A.wireMatchKeys(frame)
	frame:SetScript("OnKeyDown",matchKeyDown)
	keys.matchFrames[#keys.matchFrames+1]=frame
	if not inCombat()then
		pcall(frame.EnableKeyboard,frame,true)
		matchPropagate(frame,true)
	end
	return true
end

A.on("PLAYER_REGEN_DISABLED",function()
	for _,frame in ipairs(keys.matchFrames)do
		pcall(frame.EnableKeyboard,frame,false)
	end
end)

A.on("PLAYER_REGEN_ENABLED",function()
	keys.combat=false
	for _,frame in ipairs(keys.matchFrames)do
		if pcall(frame.EnableKeyboard,frame,true)then
			matchPropagate(frame,true)
		end
	end
end)

A.on("PLAYER_REGEN_ENABLED",function()
	keys.combat=false
	local frame=keys.frame
	if frame~=nil and keys.listing then
		if frame.keyHint then
			frame.keyHint:Show()
		end
		sync(frame,true)
	else
		traceKeyboard("off","body")
	end
	repaintGlows()
end)
