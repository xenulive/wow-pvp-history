-- WowPvpHistory 0.75.26
-- Author:  Xenu-Sentinels
-- Project: wow-pvp-history
--          https://github.com/xenulive/wow-pvp-history
-- License: MIT, see LICENSE
local _,A=...

local ROUNDS=6

local SHUFFLES={shuffle=true,["shuffle-unrated"]=true}

local MATE_UNITS={"party1","party2"}

local DEFAULT_POINT,DEFAULT_X,DEFAULT_Y="TOP",0,-144

local PAD,GAP,SQUARE,SQUARE_GAP,EDGE=6,8,12,3,1

local PLATE_ALPHA=0.85

local FADE_AFTER,FADE_SECONDS=5,0.5

local WITH_WORD="WITH"
local NO_CLASS="-"

local SAMPLE_ROUNDS={{winsPost=1},{winsPost=2}}
local SAMPLE_MATES={5,1}

local TONE_LETTER={win="W",loss="L",dim="-",progress="o",faint="."}

local frame

local live

local previewUp=false

local plateUp=false

local heldMates={}
local heldReason

local fadeSerial=0

local fading=false
local fadeCut=false

local last={state="hidden"}

local placedKey

local dragging=false

function A.tallyEnabled()
	local db=A.db()
	if not db or type(db.ui)~="table"then
		return true
	end
	return db.ui.tally~=false
end

function A.tallyLocked()
	local db=A.db()
	if not db or type(db.ui)~="table"then
		return true
	end
	return db.ui.tallyUnlocked~=true
end

function A.tallyPosition()
	return A.storedPosition("tallyPosition")
end

local function stripHeight()
	return math.max(A.fontSize("number"),SQUARE+EDGE*2)+PAD*2
end

local function figures(region,method)
	local ok,a,b=pcall(function()
		return region[method](region)
	end)
	if not ok then
		return nil,nil,"not-number"
	end
	if(type(a)~="nil"and not A.canRead(a))or(type(b)~="nil"and not A.canRead(b))then
		return nil,nil,"secret"
	end
	if type(a)~="number"or(type(b)~="nil"and type(b)~="number")then
		return nil,nil,"not-number"
	end
	return a,b,nil
end

local function widgetCenter()
	local container=UIWidgetTopCenterContainerFrame
	if type(container)~="table"then
		return nil,"no-container"
	end
	local held=container.widgetFrames
	local widget=type(held)=="table"and held[A.ROUND_WINS_WIDGET]or nil
	if type(widget)~="table"then
		return nil,"no-frame"
	end
	local okShown,shown=pcall(widget.IsShown,widget)
	if okShown and type(shown)~="nil"and not A.canRead(shown)then
		return nil,"secret"
	end
	if not okShown or shown~=true then
		return nil,"hidden"
	end
	local x,y,whyCenter=figures(widget,"GetCenter")
	local scale,_,whyScale=figures(widget,"GetEffectiveScale")
	local width,_,whyWidth=figures(UIParent,"GetWidth")
	local height,_,whyHeight=figures(UIParent,"GetHeight")
	local parentScale,_,whyParent=figures(UIParent,"GetEffectiveScale")
	local refused=whyCenter or whyScale or whyWidth or whyHeight or whyParent
	if refused then
		return nil,refused
	end
	if y==nil or scale<=0 or parentScale<=0 then
		return nil,"not-number"
	end
	local screenX,screenY=x*scale,y*scale
	return{screenX=screenX,screenY=screenY,
		dx=screenX/parentScale-width/2,dy=screenY/parentScale-height}
end

local function defaultPlace()
	local factor=A.windowScale()/100
	local count,reason=widgetCenter()
	if count then
		return DEFAULT_POINT,count.dx/factor,count.dy/factor+stripHeight()/2,"widget",nil,count
	end
	return DEFAULT_POINT,DEFAULT_X/factor,DEFAULT_Y/factor,"fixed",reason
end

function A.setTallyPosition(geometry)
	return A.storePosition("tallyPosition",geometry,defaultPlace)
end

local function placeAt(made)
	if dragging then
		return
	end
	local stored=A.tallyPosition()
	local point,x,y,anchor,reason,count
	if stored then
		point,x,y,anchor=stored.point,stored.x,stored.y,"stored"
	else
		point,x,y,anchor,reason,count=defaultPlace()
	end
	pcall(made.ClearAllPoints,made)
	pcall(made.SetPoint,made,point,UIParent,point,x,y)

	local key=("%s %s %s %s %s"):format(anchor,tostring(reason),point,tostring(A.unitFigure(x)),
		tostring(A.unitFigure(y)))
	if key==placedKey then
		return
	end
	placedKey=key
	local stripX,stripY
	if count then
		local cx,cy=figures(made,"GetCenter")
		local scale=figures(made,"GetEffectiveScale")
		if cy~=nil and scale~=nil then
			stripX,stripY=A.unitFigure(cx*scale),A.unitFigure(cy*scale)
		end
	end
	A.trace("tally/place",{
		anchor=anchor,
		reason=reason,
		point=point,
		x=A.unitFigure(x),
		y=A.unitFigure(y),
		widgetX=count and A.unitFigure(count.screenX)or nil,
		widgetY=count and A.unitFigure(count.screenY)or nil,
		stripX=stripX,
		stripY=stripY,
	},"ui")
end

A.registerStoredPlace(function(ratio)
	local held=A.tallyPosition()
	if held~=nil then
		A.setTallyPosition({point=held.point,x=held.x*ratio,y=held.y*ratio})
	end
end)

local function formatOf(record)
	if type(record.format)=="string"then
		return record.format
	end
	if type(record.liveFormat)=="string"then
		return record.liveFormat
	end
	local sample=A.readMatchSurface()
	return sample and sample.format or nil
end

local function readMates()
	local mates,read,refused={},0,false
	local count=A.guardedCall(GetNumGroupMembers)
	if A.canRead(count)and type(count)=="number"and count==A.ROUND_MATES+1 then
		for i=1,#MATE_UNITS do
			local ok,word,token=pcall(UnitClass,MATE_UNITS[i])
			if ok then
				if(type(word)~="nil"and not A.canRead(word))or(type(token)~="nil"and not A.canRead(token))then
					refused=true
				elseif type(word)=="string"and word~=""and type(token)=="string"then
					mates[i]={word=word,token=token}
					read=read+1
				end
			end
		end
	end
	local reason=nil
	if refused then
		reason="secret"
	elseif read==0 then
		reason="none"
	end
	return mates,read,reason
end

local function results(rounds,ended)
	local tones={}
	local stored=ended>0
	local before=0
	local countAt,count=0,0
	for i=1,ended do
		local round=type(rounds[i])=="table"and rounds[i]or{}
		local reading=type(round.winsPost)=="number"and round.winsPost or nil
		local tone="dim"
		if type(round.won)=="boolean"then
			tone=round.won and"win"or"loss"
		else
			stored=false
			if reading~=nil and before~=nil then
				local step=reading-before
				if step==1 then
					tone="win"
				elseif step==0 then
					tone="loss"
				end
			end
		end
		tones[i]=tone
		if reading~=nil and reading>=0 and reading<=i then
			countAt,count=i,reading
		end
		before=reading
	end
	if stored then
		local wins=0
		for i=1,ended do
			if tones[i]=="win"then
				wins=wins+1
			end
		end
		return tones,wins,ended-wins
	end
	return tones,count,countAt-count
end

local function viewOf(record,rounds,complete)
	local ended=math.min(#rounds,ROUNDS)
	local tones,wins,losses=results(rounds,ended)
	local current=nil
	if not complete and ended<ROUNDS then
		current=ended+1
		tones[current]="progress"
	end
	for i=1,ROUNDS do
		tones[i]=tones[i]or"faint"
	end
	return{format=record and formatOf(record)or"shuffle",current=current,tones=tones,
		wins=wins,losses=losses,ended=ended}
end

local function sampleMates()
	local mates={}
	for i=1,#SAMPLE_MATES do
		local ok,word,token=pcall(GetClassInfo,SAMPLE_MATES[i])
		if ok and type(word)=="string"and A.canRead(word)and word~=""and type(token)=="string"then
			mates[i]={word=word,token=token}
		end
	end
	return mates
end

local function build()
	if frame then
		return frame
	end
	if type(CreateFrame)~="function"or UIParent==nil then
		return nil
	end
	local made=CreateFrame("Frame","WowPvpHistoryTally",UIParent)
	made:SetFrameStrata("MEDIUM")
	made:SetClampedToScreen(true)
	made:SetMovable(false)
	made:EnableMouse(false)
	made:RegisterForDrag("LeftButton")
	made:SetSize(PAD*2,PAD*2)
	made:SetPoint(DEFAULT_POINT,UIParent,DEFAULT_POINT,DEFAULT_X,DEFAULT_Y)
	A.registerPlacedWindow(made,DEFAULT_POINT,DEFAULT_X,DEFAULT_Y,nil,{
		announcement=true,
		place=defaultPlace,
		stored=function()
			local held=A.tallyPosition()
			if held then
				return held.point,held.x,held.y
			end
			return nil
		end,
	})
	made:Hide()

	made.ground=made:CreateTexture(nil,"BACKGROUND")
	made.ground:SetAllPoints(made)

	local function text()
		local held=made:CreateFontString(nil,"ARTWORK","GameFontNormalSmall")
		held:SetJustifyH("LEFT")
		held:SetWordWrap(false)
		return held
	end
	made.format=text()
	made.round=text()
	made.record=text()
	made.with=text()
	made.mates={text(),text()}

	made.squares={}
	for i=1,ROUNDS do
		local edge=made:CreateTexture(nil,"BORDER")
		edge:SetSize(SQUARE+EDGE*2,SQUARE+EDGE*2)
		local fill=made:CreateTexture(nil,"ARTWORK")
		fill:SetSize(SQUARE,SQUARE)
		edge:SetPoint("CENTER",fill,"CENTER",0,0)
		made.squares[i]={fill=fill,edge=edge}
	end

	made:SetScript("OnDragStart",function(self)
		dragging=true
		pcall(self.StartMoving,self)
	end)
	made:SetScript("OnHide",function()
		dragging=false
	end)
	made:SetScript("OnDragStop",function(self)
		dragging=false
		A.stopDrag(self)
		local read=A.frameGeometry(self)
		if read and read.point then
			local ratio=A.sessionToStoredRatio()
			A.setTallyPosition({point=read.point,x=read.x*ratio,y=read.y*ratio})
		end
		A.trace("tally/move",{
			point=read and read.point or nil,
			x=read and A.wholeOffset(read.x)or nil,
			y=read and A.wholeOffset(read.y)or nil,
			state=A.tallyPosition()~=nil and"stored"or"default",
		},"ui")
	end)

	frame=made
	placeAt(made)
	return made
end

local function place(fontString,said,role,colorName,x)
	A.style(fontString,role,colorName)
	fontString:SetText(said)
	local width=A.textRoom(fontString,said)
	fontString:SetWidth(width)
	fontString:ClearAllPoints()
	fontString:SetPoint("LEFT",frame,"LEFT",x,0)
	fontString:Show()
	return x+width
end

local function paint(view,mates)
	local x=place(frame.format,A.formatLabel(view.format),"label","text",PAD)
	if view.current~=nil then
		x=place(frame.round,("R%d"):format(view.current),"number","bright",x+GAP)
	else
		frame.round:SetText("")
		frame.round:Hide()
	end

	x=x+GAP
	for i=1,ROUNDS do
		local square=frame.squares[i]
		local tone=view.tones[i]
		square.fill:ClearAllPoints()
		square.fill:SetPoint("LEFT",frame,"LEFT",x,0)
		local r,g,b=A.color(tone=="progress"and"faint"or tone)
		square.fill:SetColorTexture(r,g,b,1)
		square.fill:Show()
		if tone=="progress"then
			local er,eg,eb=A.color("accent")
			square.edge:SetColorTexture(er,eg,eb,1)
			square.edge:Show()
		else
			square.edge:Hide()
		end
		x=x+SQUARE+(i<ROUNDS and SQUARE_GAP or 0)
	end

	x=place(frame.record,("%d-%d"):format(view.wins,view.losses),"number","bright",x+GAP)
	x=place(frame.with,WITH_WORD,"label","dim",x+GAP)
	for i=1,#MATE_UNITS do
		local mate=mates[i]
		local fontString=frame.mates[i]
		x=place(fontString,mate and mate.word or NO_CLASS,"label","dim",x+GAP/2)
		if mate then
			fontString:SetTextColor(A.classColor(mate.token))
		end
	end

	frame:SetSize(x+PAD,stripHeight())
	local r,g,b=A.color("panel")
	frame.ground:SetColorTexture(r,g,b,PLATE_ALPHA)
end

local function liveShown()
	if live==nil or frame==nil then
		return false
	end
	local ok,shown=pcall(frame.IsShown,frame)
	return ok and shown==true and not previewUp and not last.sample
end

local function stopFade()
	if fading then
		fading,fadeCut=false,true
	end
	frame:SetScript("OnUpdate",nil)
end

local armFade

local function raise(draggable)
	stopFade()
	frame:SetMovable(draggable)
	frame:EnableMouse(draggable)
	frame:SetAlpha(1)
	frame:Show()
end

local function update(source)
	local view,mates,reason,format,sample
	if previewUp or(plateUp and live==nil)then
		sample=true
		view=viewOf(nil,SAMPLE_ROUNDS,false)
		mates=sampleMates()
		reason="preview"
	elseif live~=nil then
		local record=live.record
		format=formatOf(record)
		if not A.tallyEnabled()then
			reason="off"
		elseif not SHUFFLES[format]then
			reason="no-format"
		else
			view=viewOf(record,A.roundList(record)or{},live.complete)
			if source~="stored"and source~="fade"then
				local read,_,why=readMates()
				heldMates,heldReason=read,why
			end
			mates,reason=heldMates,heldReason
		end
		if view==nil and plateUp then
			sample=true
			view=viewOf(nil,SAMPLE_ROUNDS,false)
			mates=sampleMates()
		end
	end

	local drawn=view~=nil and build()~=nil
	if drawn then
		paint(view,mates)
		if A.tallyPosition()==nil then
			placeAt(frame)
		end
		raise(sample==true or not A.tallyLocked())
		if fadeCut and sample~=true and live~=nil and live.complete then
			fadeCut=false
			armFade()
		end
	elseif frame then
		stopFade()
		frame:Hide()
	end

	local read=0
	local letters={}
	if view then
		for i=1,#MATE_UNITS do
			if mates[i]then
				read=read+1
			end
		end
		for i=1,ROUNDS do
			letters[i]=TONE_LETTER[view.tones[i]]
		end
	end
	last={
		state=drawn and"shown"or"hidden",
		sample=sample,
		source=source,
		reason=reason,
		format=view and view.format or format,
		round=view and view.current or nil,
		rounds=view and view.ended or nil,
		wins=view and view.wins or nil,
		losses=view and view.losses or nil,
		mates=view and read or nil,
		tones=view and table.concat(letters)or nil,
	}
	A.trace("tally",{
		source=source,
		state=last.state,
		reason=reason,
		format=last.format,
		round=last.round,
		rounds=last.rounds,
		wins=last.wins,
		losses=last.losses,
		mates=last.mates,
		tones=last.tones,
	},"ui")
	return drawn
end

local function contained(source)
	local ok,err=pcall(update,source)
	if not ok then
		A.noteError(err,"tally")
		return false
	end
	return err
end

local function fadeOut()
	local started=A.guardedCall(GetTime)
	if not frame or type(started)~="number"then
		live,fadeCut=nil,false
		contained("fade")
		return
	end
	fading=true
	frame:SetScript("OnUpdate",function(self)
		local now=A.guardedCall(GetTime)
		local at=type(now)=="number"and now-started or FADE_SECONDS
		if at<FADE_SECONDS then
			self:SetAlpha(1-at/FADE_SECONDS)
			return
		end
		self:SetScript("OnUpdate",nil)
		fading,fadeCut=false,false
		live=nil
		contained("fade")
	end)
end

armFade=function()
	fadeSerial=fadeSerial+1
	local serial=fadeSerial
	if type(C_Timer)~="table"or type(C_Timer.After)~="function"then
		return
	end
	C_Timer.After(FADE_AFTER,function()
		if serial~=fadeSerial or live==nil then
			return
		end
		if last.sample then
			fadeCut=true
			return
		end
		fadeOut()
	end)
end

local STATE_SOURCE={StartUp="startup",Engaged="engaged",PostRound="postround",Complete="complete"}

function A.tallyMatchState(record,state)
	if state=="Inactive"then
		if live~=nil and not live.complete then
			live,fading,fadeCut=nil,false,false
			fadeSerial=fadeSerial+1
			contained("inactive")
		end
		return
	end
	local source=STATE_SOURCE[state]
	if type(record)~="table"or source==nil then
		return
	end
	if live==nil or live.record~=record then
		live={record=record}
		fadeSerial=fadeSerial+1
		fading,fadeCut=false,false
	end
	if state=="Complete"then
		live.complete=true
	end
	if contained(source)and live.complete then
		armFade()
	end
end

A.on("UPDATE_UI_WIDGET",function(_,info)
	if frame==nil or type(info)~="table"then
		return
	end
	local ok,id=pcall(A.index,info,"widgetID")
	if not ok or not A.canRead(id)or id~=A.ROUND_WINS_WIDGET or A.tallyPosition()~=nil then
		return
	end
	placeAt(frame)
end)

function A.tallyWins(record)
	if live~=nil and live.record==record and not live.complete then
		contained("wins")
	end
end

function A.tallyRecordStored()
	if live~=nil and live.complete and liveShown()then
		if contained("stored")then
			armFade()
		end
	end
end

function A.tallyPreview()
	local ending=previewUp
	previewUp=not ending
	local drawn=contained("preview")
	if type(A.refreshOptionsWindow)=="function"then
		pcall(A.refreshOptionsWindow)
	end
	if ending then
		return"ended"
	end
	if not drawn then
		previewUp=false
		return false
	end
	return"shown"
end

function A.tallyPreviewActive()
	return previewUp
end

function A.tallyPlateRefresh(cause)
	local wanted=type(A.optionsWindowShown)=="function"and A.optionsWindowShown()==true
		and A.tallyEnabled()and not A.tallyLocked()
	if wanted==plateUp then
		if cause=="palette"and frame~=nil and frame:IsShown()then
			contained(cause)
		end
		return plateUp
	end
	plateUp=wanted
	contained(cause or"plate")
	return plateUp
end

function A.setTally(enabled)
	local db=A.db()
	if not db then
		return false
	end
	db.ui=db.ui or{}
	if enabled==false then
		db.ui.tally=false
	else
		db.ui.tally=nil
	end
	local endedPreview=enabled==false and previewUp
	if endedPreview then
		previewUp=false
	end
	if type(A.notifyTallySetting)=="function"then
		A.notifyTallySetting()
	end
	A.tallyPlateRefresh("switch")
	if live~=nil or endedPreview then
		contained("switch")
	end
	if endedPreview and type(A.refreshOptionsWindow)=="function"then
		pcall(A.refreshOptionsWindow)
	end
	return true
end

function A.setTallyLocked(on)
	local db=A.db()
	if not db then
		return false
	end
	db.ui=db.ui or{}
	if on==false then
		db.ui.tallyUnlocked=true
	else
		db.ui.tallyUnlocked=nil
	end
	if type(A.notifyTallyLockSetting)=="function"then
		A.notifyTallyLockSetting()
	end
	if not A.tallyPlateRefresh("lock")and frame~=nil and(live~=nil or previewUp)then
		contained("lock")
	end
	return true
end

function A.resetTallyPosition()
	local stored=A.setTallyPosition(nil)
	dragging,placedKey=false,nil
	if frame then
		placeAt(frame)
	end
	return stored
end

function A.tallyFrame()
	return frame
end

function A.tallyState()
	return last
end

function A.tallyReadout()
	local held=A.tallyPosition()
	local where
	if held then
		where=("%s %d, %d"):format(held.point,held.x,held.y)
	else
		local _,_,_,anchor,reason=defaultPlace()
		where=anchor=="widget"and"its default place, over the client's round count"
			or("its default place, the fixed point (%s)"):format(tostring(reason))
	end
	local lines={
		("the round tally in Solo Shuffle is %s and %s, at %s"):format(A.tallyEnabled()and"on"or"off",
			A.tallyLocked()and"locked"or"unlocked",where),
	}
	local said={("last update: %s, %s"):format(tostring(last.source or"none"),last.state)}
	for _,key in ipairs({"reason","format","round","rounds","wins","losses","mates","tones"})do
		if last[key]~=nil then
			said[#said+1]=("%s=%s"):format(key,tostring(last[key]))
		end
	end
	lines[2]=table.concat(said," ")
	return lines
end
