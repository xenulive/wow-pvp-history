-- WowPvpHistory 0.75.26
-- Author:  Xenu-Sentinels
-- Project: wow-pvp-history
--          https://github.com/xenulive/wow-pvp-history
-- License: MIT, see LICENSE
local _,A=...

local COUNT_MIN,COUNT_MAX,COUNT_DEFAULT=4,10,5

local OPACITY_MIN,OPACITY_MAX,OPACITY_STEP,OPACITY_DEFAULT=0,100,10,70

local DEFAULT_POINT,DEFAULT_X,DEFAULT_Y="TOP",0,-72

local PAD,SQUARE,DELTA_GAP,CELL_GAP,BLOCK_GAP=6,30,2,5,10
local LINE_GAP,TODAY_GAP=1,6

local TITLE_TEXT=A.displayName():upper()
local TITLE_GAP,RULE_GAP,RULE_SHORT=2,2,12

local DELTA_FLOOR_TEXT="+999"

local frame
local cells={}
local secondCells={}

local grown=0

local previewUp=false

local previewFormat
local previewOpacity

local hovered

local inCombat=false

local last={state="hidden",ids={}}

local painted

local midnightCall=0

local function clamp(value,min,max)
	local figure=tonumber(value)
	if figure==nil or figure~=figure or figure==math.huge or figure==-math.huge then
		return nil
	end
	if figure<min then
		return min
	end
	if figure>max then
		return max
	end
	return figure
end

local function stepped(figure)
	return math.floor(figure/OPACITY_STEP+0.5)*OPACITY_STEP
end

function A.overlayEnabled()
	local db=A.db()
	if not db or type(db.ui)~="table"then
		return false
	end
	return db.ui.overlayShown==true
end

function A.setOverlay(enabled)
	local db=A.db()
	if not db then
		return false
	end
	db.ui=db.ui or{}
	if enabled==true then
		db.ui.overlayShown=true
	else
		db.ui.overlayShown=nil
	end
	if A.notifyOverlaySetting then
		A.notifyOverlaySetting()
	end
	A.overlayRepaint("setting","shown")
	return true
end

function A.overlayCount()
	local db=A.db()
	if not db or type(db.ui)~="table"then
		return COUNT_DEFAULT
	end
	local figure=clamp(db.ui.overlayCount,COUNT_MIN,COUNT_MAX)
	if figure==nil then
		return COUNT_DEFAULT
	end
	return math.floor(figure)
end

function A.overlayCountRange()
	return COUNT_MIN,COUNT_MAX,1,COUNT_DEFAULT
end

function A.setOverlayCount(value)
	local db=A.db()
	if not db then
		return false
	end
	local figure=clamp(value,COUNT_MIN,COUNT_MAX)
	if figure==nil then
		return false
	end
	local want=math.floor(figure)
	db.ui=db.ui or{}
	db.ui.overlayCount=want~=COUNT_DEFAULT and want or nil
	if type(A.notifyOverlayCountSetting)=="function"then
		A.notifyOverlayCountSetting()
	end
	A.overlayRepaint("setting","count")
	return true
end

function A.overlayOpacity()
	local db=A.db()
	if not db or type(db.ui)~="table"then
		return OPACITY_DEFAULT
	end
	local figure=clamp(db.ui.overlayOpacity,OPACITY_MIN,OPACITY_MAX)
	if figure==nil then
		return OPACITY_DEFAULT
	end
	return stepped(figure)
end

function A.overlayOpacityRange()
	return OPACITY_MIN,OPACITY_MAX,OPACITY_STEP,OPACITY_DEFAULT
end

function A.setOverlayOpacity(value)
	local db=A.db()
	if not db then
		return false
	end
	local figure=clamp(value,OPACITY_MIN,OPACITY_MAX)
	if figure==nil then
		return false
	end
	local want=stepped(figure)
	db.ui=db.ui or{}
	db.ui.overlayOpacity=want~=OPACITY_DEFAULT and want or nil
	if type(A.notifyOverlayOpacitySetting)=="function"then
		A.notifyOverlayOpacitySetting()
	end
	A.overlayRepaint("setting","opacity")
	return true
end

function A.overlayCombat()
	local db=A.db()
	if not db or type(db.ui)~="table"then
		return true
	end
	return db.ui.overlayCombat~=false
end

function A.setOverlayCombat(enabled)
	local db=A.db()
	if not db then
		return false
	end
	db.ui=db.ui or{}
	if enabled==false then
		db.ui.overlayCombat=false
	else
		db.ui.overlayCombat=nil
	end
	if type(A.notifyOverlayCombatSetting)=="function"then
		A.notifyOverlayCombatSetting()
	end
	A.overlayRepaint("setting","combat")
	return true
end

function A.overlayTwo()
	local db=A.db()
	if not db or type(db.ui)~="table"then
		return false
	end
	return db.ui.overlayTwo==true
end

function A.setOverlayTwo(enabled)
	local db=A.db()
	if not db then
		return false
	end
	db.ui=db.ui or{}
	if enabled==true then
		db.ui.overlayTwo=true
	else
		db.ui.overlayTwo=nil
	end
	if type(A.notifyOverlayTwoSetting)=="function"then
		A.notifyOverlayTwoSetting()
	end
	A.overlayRepaint("setting","two")
	return true
end

function A.overlayPosition()
	return A.storedPosition("overlayPosition")
end

local function defaultPlace()
	local factor=(type(A.windowScale)=="function"and A.windowScale()or 100)/100
	return DEFAULT_POINT,DEFAULT_X/factor,DEFAULT_Y/factor
end

function A.setOverlayPosition(geometry)
	return A.storePosition("overlayPosition",geometry,defaultPlace)
end

local function growthShift(point,extra)
	if extra==0 or type(point)~="string"or point:find("TOP",1,true)then
		return 0
	end
	if point:find("BOTTOM",1,true)then
		return extra
	end
	return extra/2
end

local function placeAt(made,extra)
	local stored=A.overlayPosition()
	local _,defaultX,defaultY=defaultPlace()
	local point=stored and stored.point or DEFAULT_POINT
	local x=stored and stored.x or defaultX
	local y=(stored and stored.y or defaultY)-growthShift(point,extra or 0)
	pcall(made.ClearAllPoints,made)
	pcall(made.SetPoint,made,point,UIParent,point,x,y)
end

if type(A.registerStoredPlace)=="function"then
	A.registerStoredPlace(function(ratio)
		local held=A.overlayPosition()
		if held==nil then
			return
		end
		A.setOverlayPosition({point=held.point,x=held.x*ratio,y=held.y*ratio})
	end)
end

local function recordById(id)
	local db=A.db()
	if id==nil or not(db and type(db.matches)=="table")then
		return nil
	end
	for i=#db.matches,1,-1 do
		local record=db.matches[i]
		if type(record)=="table"and record.id==id then
			return record
		end
	end
	return nil
end

local SANDBOX_READER="the sandbox's generated character"

function A.barCharacter()
	if A.sandboxed()then
		return SANDBOX_READER
	end
	return A.ownGuid()
end

function A.barRecorder(character)
	if character==SANDBOX_READER then
		return nil
	end
	return character
end

local function newestOf(format,character,count)
	local rows={}
	local db=A.db()
	if not(db and type(db.matches)=="table")then
		return rows
	end
	local recorder=A.barRecorder(character)
	for i=1,#db.matches do
		local record=db.matches[i]
		if type(record)=="table"and A.recordInFormat(record,format)
			and A.recordedBy(record,recorder)and A.recordEpoch(record)~=nil then
			rows[#rows+1]=record
		end
	end
	table.sort(rows,function(a,b)
		local at,bt=A.recordEpoch(a),A.recordEpoch(b)
		if at~=bt then
			return at>bt
		end
		return A.newerMatchId(a.id,b.id)
	end)
	for i=#rows,count+1,-1 do
		rows[i]=nil
	end
	return rows
end

local function dayOf(record)
	return A.dayKey(record.openedAt or record.completedAt or record.endedAt)
end

local function secondOf(format,character)
	local today=A.dayKey(A.stamp())
	if format==nil or today==nil then
		return nil
	end
	local held=A.lastMatch(nil,nil,A.barRecorder(character),nil,true,format)
	if held==nil or dayOf(held)~=today then
		return nil
	end
	local second=held.format or"unknown"
	local rows=newestOf(second,character,A.overlayCount())
	if#rows==0 then
		return nil
	end
	return{format=second,rows=rows}
end

local function secondWanted()
	return previewUp or A.overlayTwo()
end

local function subject()
	local character=A.barCharacter()
	if character==nil then
		return nil,nil,{},nil
	end
	local format,rows
	if previewFormat~=nil then
		rows=newestOf(previewFormat,character,A.overlayCount())
		if#rows==0 then
			return character,nil,rows,nil
		end
		format=previewFormat
	else
		local newest=A.lastMatch(nil,nil,A.barRecorder(character),nil,true)
		if newest==nil then
			return character,nil,{},nil
		end
		format=newest.format or"unknown"
		rows=newestOf(format,character,A.overlayCount())
	end
	local second=secondWanted()and secondOf(format,character)or nil
	return character,format,rows,second
end

local function todaysMatches(format,character)
	local out={}
	local db=A.db()
	local today=A.dayKey(A.stamp())
	if today==nil or not(db and type(db.matches)=="table")then
		return out
	end
	local recorder=A.barRecorder(character)
	for i=1,#db.matches do
		local record=db.matches[i]
		if type(record)=="table"and A.recordInFormat(record,format)and A.recordedBy(record,recorder)
			and dayOf(record)==today then
			out[#out+1]=record
		end
	end
	return out
end

local heldToday={}
local computeTodayFigures

function A.todayFigures(format,character)
	if format==nil or character==nil then
		return nil
	end
	local db=A.db()
	local matches=db and type(db.matches)=="table"and db.matches or nil
	local count=matches and#matches or 0
	local newest=matches and matches[count]or nil
	local key={
		db=db,matches=matches,count=count,day=A.dayKey(A.stamp()),format=format,
		recorder=A.barRecorder(character),newestId=type(newest)=="table"and newest.id or nil,
	}
	local held=heldToday[format]
	if held==nil or held.key.db~=key.db or held.key.matches~=key.matches
		or held.key.count~=key.count or held.key.day~=key.day or held.key.format~=key.format
		or held.key.recorder~=key.recorder or held.key.newestId~=key.newestId
	then
		held={key=key,figures=computeTodayFigures(format,character)}
		heldToday[format]=held
	end
	local out={}
	for field,value in pairs(held.figures)do
		out[field]=value
	end
	return out
end

computeTodayFigures=function(format,character)
	local list=todaysMatches(format,character)
	local figures={n=#list,changeN=0,decided=0}

	if A.movesRating(format)then
		local summary=A.summarize(format,nil,A.barRecorder(character))
		local rating=type(summary)=="table"and tonumber(summary.rating)or nil
		if rating~=nil then
			figures.rating=math.floor(rating)
		end
		local sum=0
		for i=1,#list do
			local record=list[i]
			if A.ratingDelta(record)~=nil then
				local own=record.participants[record.character]
				sum=sum+own.ratingChange
				figures.changeN=figures.changeN+1
			end
		end
		if#list==0 or figures.changeN>0 then
			if sum>0 then
				figures.change,figures.changeTone=("%+d"):format(sum),"win"
			elseif sum<0 then
				figures.change,figures.changeTone=("%+d"):format(sum),"loss"
			else
				figures.change,figures.changeTone="0","dim"
			end
		end
	end

	local tally={wins=0,decided=0,draws=0}
	for i=1,#list do
		local record=list[i]
		local outcome,_,derived=A.recordVerdict(record)
		if outcome~=nil then
			tally.decided=tally.decided+1
			if A.recordLevel(record,outcome,derived)then
				tally.draws=tally.draws+1
			end
			if outcome=="win"then
				tally.wins=tally.wins+1
			end
		end
	end
	figures.decided=tally.decided
	figures.record=A.winRecordText(tally,format)
	if figures.record~=nil then
		local _,_,_,rate=A.winRecord(tally)
		figures.recordTone=A.winRateTone(rate)or"dim"
	end
	return figures
end

function A.ratingTint(format,rating)
	local _,_,reason,r,g,b=A.ratingColour(format,rating)
	if reason=="unheard"then
		A.ratingAsk()
	end
	if r~=nil then
		return r,g,b,"tier"
	end
	local br,bg,bb=A.color("bright")
	return br,bg,bb,reason
end

local function secondLine(format,character)
	local figures=A.todayFigures(format,character)
	if figures==nil then
		return nil
	end
	if A.movesRating(format)then
		local change=figures.change~="0"and figures.change or nil
		local line={todayN=figures.changeN,rating=figures.rating,today=change,
			todayTone=change and figures.changeTone or nil}
		if figures.rating~=nil then
			line.primary=tostring(figures.rating)
		end
		if line.primary==nil and line.today==nil then
			return nil
		end
		return line
	end
	if figures.record==nil then
		return nil
	end
	return{primary=figures.record,primaryTone="text",today=figures.record,todayN=figures.decided}
end

local function columnWidth()
	return math.max(SQUARE,A.headerFloor(DELTA_FLOOR_TEXT))
end

local function tileHeight()
	return SQUARE+DELTA_GAP+A.fontSize("numberSmall")
end

local function blockHeight(withLine)
	local height=A.fontSize("label")+TITLE_GAP+1+RULE_GAP+A.fontSize("label")
	if withLine then
		height=height+LINE_GAP+A.fontSize("number")
	end
	return height
end

local function middleLine()
	return PAD+math.ceil(math.max(blockHeight(true),SQUARE)/2)
end

local function onLine(own)
	return middleLine()-own/2
end

local function barHeight()
	local full=blockHeight(true)
	return math.ceil(math.max(onLine(full)+full,onLine(SQUARE)+tileHeight())+PAD)
end

local function centredTop(own)
	return math.floor((barHeight()-own)/2)
end

local function ratingLine(record,head)
	if type(head)~="table"or head.ratingFrom==nil or head.ratingTo==nil then
		return nil
	end
	local from,to=tonumber(head.ratingFrom),tonumber(head.ratingTo)
	local _,_,reason=A.ratingColour(record.format,to)
	if reason=="unheard"then
		A.ratingAsk()
	end
	local line=A.tierRatingText(record.format,from,"bright").." "..A.colorEscape("dim").."to|r "
		..A.tierRatingText(record.format,to,"bright")
	if head.delta~=nil then
		line=line.." "..A.colorEscape(head.deltaTone or"dim")..head.delta.."|r"
	end
	return line
end

local function whenLine(record)
	local parts={}
	local day=A.stampWords(record.openedAt)or A.stampWords(record.completedAt)
	if day~=nil then
		parts[#parts+1]=day
	end
	local length=A.lengthText(record.duration)
	if length~=nil then
		parts[#parts+1]=length
	end
	local season=A.seasonText(record,true)
	if season~=nil then
		parts[#parts+1]=season
	end
	if#parts==0 then
		return nil
	end
	return table.concat(parts,"  ")
end

local function hoverAnchor(cell)
	return{
		point="TOP",relativeTo=cell.delta,relativePoint="BOTTOM",x=0,y=-DELTA_GAP,
		name="change",
		flip={point="BOTTOM",relativeTo=cell.square,relativePoint="TOP",x=0,y=DELTA_GAP,
			name="square"},
	}
end

local function hover(cell)
	hovered={id=cell.matchId,text=cell.letterText}
	local record=cell.record
	if type(record)~="table"or record.id~=cell.matchId then
		record=recordById(cell.matchId)
	end
	if record==nil then
		return false
	end
	local ok,lines,_,_,heads=pcall(A.detailLines,record)
	if not ok or type(lines)~="table"or type(heads)~="table"then
		return false
	end
	local out={}
	local headline
	for i=1,#lines do
		local head=heads[i]
		if type(head)=="table"and head.kind=="headline"and type(lines[i])=="string"then
			out[#out+1]=(lines[i]:gsub("^%s+",""))
			headline=head
			break
		end
	end
	if#out==0 then
		return false
	end
	local when=whenLine(record)
	if when~=nil then
		out[#out+1]=when
	end
	local rated=ratingLine(record,headline)
	if rated~=nil then
		out[#out+1]=rated
	end
	return A.keyedTooltip(cell,out,hoverAnchor(cell),"overlay")
end

local function cellAt(i,pool)
	pool=pool or cells
	local held=pool[i]
	if held then
		return held
	end
	held=CreateFrame("Button",nil,frame)
	held:SetSize(columnWidth(),tileHeight())

	held.square=held:CreateTexture(nil,"ARTWORK")
	held.square:SetSize(SQUARE,SQUARE)
	held.square:SetPoint("TOP",held,"TOP",0,0)

	held.letter=held:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
	held.letter:SetPoint("CENTER",held.square,"CENTER",0,0)
	held.letter:SetJustifyH("CENTER")
	held.letter:SetWordWrap(false)

	held.delta=held:CreateFontString(nil,"ARTWORK","GameFontNormalSmall")
	held.delta:SetPoint("TOP",held.square,"BOTTOM",0,-DELTA_GAP)
	held.delta:SetWidth(columnWidth())
	held.delta:SetJustifyH("CENTER")
	held.delta:SetWordWrap(false)

	held:SetScript("OnClick",function(self)
		if self.matchId~=nil then
			A.showMatchWindow("match",self.matchId,"overlay")
		end
	end)
	held:SetScript("OnEnter",function(self)
		hover(self)
	end)
	held:SetScript("OnLeave",function()
		A.hideTooltip()
	end)
	held:Hide()
	pool[i]=held
	return held
end

local function build()
	if frame then
		return frame
	end
	if type(CreateFrame)~="function"or UIParent==nil then
		return nil
	end
	local made=CreateFrame("Frame","WowPvpHistoryOverlay",UIParent)
	made:SetFrameStrata("MEDIUM")
	made:SetClampedToScreen(true)
	made:SetMovable(true)
	made:EnableMouse(true)
	made:RegisterForDrag("LeftButton")
	made:SetSize(columnWidth(),barHeight())
	made:SetPoint(DEFAULT_POINT,UIParent,DEFAULT_POINT,DEFAULT_X,DEFAULT_Y)
	A.registerPlacedWindow(made,DEFAULT_POINT,DEFAULT_X,DEFAULT_Y,nil,{
		announcement=true,
		place=defaultPlace,
		stored=function()
			local held=A.overlayPosition()
			if held then
				return held.point,held.x,held.y
			end
			return nil
		end,
	})
	made:Hide()

	made.ground=made:CreateTexture(nil,"BACKGROUND")
	made.ground:SetAllPoints(made)

	made.title=made:CreateFontString(nil,"ARTWORK","GameFontNormalSmall")
	made.title:SetJustifyH("LEFT")
	made.title:SetWordWrap(false)
	made.rule=made:CreateTexture(nil,"ARTWORK")

	made.label=made:CreateFontString(nil,"ARTWORK","GameFontNormalSmall")
	made.label:SetJustifyH("LEFT")
	made.label:SetWordWrap(false)

	made.rating=made:CreateFontString(nil,"ARTWORK","GameFontNormalSmall")
	made.rating:SetJustifyH("LEFT")
	made.rating:SetWordWrap(false)
	made.today=made:CreateFontString(nil,"ARTWORK","GameFontNormalSmall")
	made.today:SetJustifyH("LEFT")
	made.today:SetWordWrap(false)

	made.divider=made:CreateTexture(nil,"ARTWORK")

	made.split=made:CreateTexture(nil,"ARTWORK")
	made.label2=made:CreateFontString(nil,"ARTWORK","GameFontNormalSmall")
	made.label2:SetJustifyH("LEFT")
	made.label2:SetWordWrap(false)
	made.rating2=made:CreateFontString(nil,"ARTWORK","GameFontNormalSmall")
	made.rating2:SetJustifyH("LEFT")
	made.rating2:SetWordWrap(false)
	made.today2=made:CreateFontString(nil,"ARTWORK","GameFontNormalSmall")
	made.today2:SetJustifyH("LEFT")
	made.today2:SetWordWrap(false)
	made.divider2=made:CreateTexture(nil,"ARTWORK")
	made.split:Hide()
	made.label2:Hide()
	made.rating2:Hide()
	made.today2:Hide()
	made.divider2:Hide()

	made:SetScript("OnDragStart",function(self)
		pcall(self.StartMoving,self)
	end)
	made:SetScript("OnDragStop",function(self)
		A.stopDrag(self)
		local read=A.frameGeometry(self)
		if read and read.point then
			local ratio=A.sessionToStoredRatio()
			local y=read.y+growthShift(read.point,grown)
			A.setOverlayPosition({point=read.point,x=read.x*ratio,y=y*ratio})
		end
		local stored=A.overlayPosition()
		A.trace("overlay/move",{
			point=read and read.point or nil,
			x=read and A.wholeOffset(read.x)or nil,
			y=read and A.wholeOffset(read.y)or nil,
			state=stored~=nil and"stored"or"default",
		},"ui")
	end)

	frame=made
	placeAt(made)
	return made
end

local function drawnOpacity()
	if previewOpacity~=nil then
		return previewOpacity
	end
	return A.overlayOpacity()
end

local function tintRating(fontString,format,rating)
	local r,g,b,tint=A.ratingTint(format,rating)
	fontString:SetTextColor(r,g,b)
	return tint
end

local function nameFloor()
	local widest=0
	local names=type(A.formatLabelList)=="function"and A.formatLabelList()or{}
	for i=1,#names do
		local need=A.headerFloor(names[i])
		local drawn=A.textRoom(frame.label,names[i])
		if drawn>need then
			need=drawn
		end
		if need>widest then
			widest=need
		end
	end
	return widest
end

local function paintFigures(label,rating,today,format,line)
	if line==nil then
		rating:SetText("")
		rating:Hide()
		today:SetText("")
		today:Hide()
		return 0,nil
	end

	local lineWidth,tint=0,nil
	rating:ClearAllPoints()
	rating:SetPoint("TOPLEFT",label,"BOTTOMLEFT",0,-LINE_GAP)
	if line.primary~=nil then
		rating:SetText(line.primary)
		A.style(rating,"number",line.primaryTone or"bright")
		if line.rating~=nil then
			tint=tintRating(rating,format,line.rating)
		end
		local width=A.textRoom(rating,line.primary)
		rating:SetWidth(width)
		rating:Show()
		lineWidth=width
	else
		rating:SetText("")
		rating:SetWidth(0)
		rating:Hide()
	end

	local todayText
	if line.today~=nil then
		if line.primary~=nil and line.rating==nil then
			todayText="today"
		else
			todayText=line.today.." today"
		end
	end
	today:ClearAllPoints()
	if todayText then
		today:SetText(todayText)
		A.style(today,"numberSmall",line.rating~=nil and line.todayTone or"dim")
		local width=A.textRoom(today,todayText)
		today:SetWidth(width)
		if lineWidth>0 then
			today:SetPoint("BOTTOMLEFT",rating,"BOTTOMRIGHT",TODAY_GAP,0)
			lineWidth=lineWidth+TODAY_GAP+width
		else
			today:SetPoint("TOPLEFT",label,"BOTTOMLEFT",0,-LINE_GAP)
			lineWidth=width
		end
		today:Show()
	else
		today:SetText("")
		today:Hide()
	end
	return lineWidth,tint
end

local function finishRule(blockWidth)
	local ruleWidth=blockWidth+BLOCK_GAP-RULE_SHORT
	frame.rule:SetSize(ruleWidth,1)
	return blockWidth,ruleWidth
end

local function paintBlock(text,tone,format,line,floored)
	frame.title:SetText(TITLE_TEXT)
	A.style(frame.title,"label","accent")
	local titleWidth=A.headerFloor(TITLE_TEXT)
	frame.title:SetWidth(titleWidth)
	frame.title:ClearAllPoints()
	local own=blockHeight(line~=nil)
	frame.title:SetPoint("TOPLEFT",frame,"TOPLEFT",PAD,-(floored and onLine(own)or centredTop(own)))
	frame.title:Show()

	frame.rule:ClearAllPoints()
	frame.rule:SetPoint("TOPLEFT",frame.title,"BOTTOMLEFT",0,-TITLE_GAP)
	frame.rule:SetColorTexture(A.color("accent"))
	frame.rule:Show()

	frame.label:SetText(text)
	A.style(frame.label,"label",tone)
	local labelWidth=A.headerFloor(text)
	frame.label:SetWidth(labelWidth)
	frame.label:ClearAllPoints()
	frame.label:SetPoint("TOPLEFT",frame.rule,"BOTTOMLEFT",0,-RULE_GAP)
	if floored then
		local floor=nameFloor()
		if floor>labelWidth then
			labelWidth=floor
		end
	end
	if titleWidth>labelWidth then
		labelWidth=titleWidth
	end

	local lineWidth,tint=paintFigures(frame.label,frame.rating,frame.today,format,line)
	local blockWidth,ruleWidth=finishRule(lineWidth>labelWidth and lineWidth or labelWidth)
	return blockWidth,ruleWidth,tint
end

local function secondBlockHeight()
	return A.fontSize("label")+LINE_GAP+A.fontSize("number")
end

local function secondMiddle()
	return barHeight()+1+PAD+math.ceil(math.max(secondBlockHeight(),SQUARE)/2)
end

local function twoRowHeight()
	local middle=secondMiddle()
	local block=secondBlockHeight()
	return math.ceil(math.max(middle-block/2+block,middle-SQUARE/2+tileHeight())+PAD)
end

local function paintSecondBlock(format,line)
	local text=A.formatLabel(format)
	frame.label2:SetText(text)
	A.style(frame.label2,"label","text")
	local labelWidth=A.headerFloor(text)
	frame.label2:SetWidth(labelWidth)
	frame.label2:ClearAllPoints()
	local own=line~=nil and secondBlockHeight()or A.fontSize("label")
	frame.label2:SetPoint("TOPLEFT",frame,"TOPLEFT",PAD,-(secondMiddle()-own/2))
	frame.label2:Show()
	local lineWidth,tint=paintFigures(frame.label2,frame.rating2,frame.today2,format,line)
	return lineWidth>labelWidth and lineWidth or labelWidth,tint
end

local function middles(withLine,drawn)
	local _,_,_,_,titleY=frame.title:GetPoint(1)
	local blockMid=type(titleY)=="number"and A.unitFigure(-titleY+blockHeight(withLine)/2)or nil
	if not drawn then
		return blockMid,nil
	end
	local cell=cells[1]
	local _,_,_,_,cellY=cell:GetPoint(1)
	local _,_,_,_,squareY=cell.square:GetPoint(1)
	if type(cellY)~="number"or type(squareY)~="number"then
		return blockMid,nil
	end
	return blockMid,A.unitFigure(-cellY-squareY+SQUARE/2)
end

local function paintCells(pool,rows,x,tileTop,divider)
	local column=columnWidth()
	local ids,texts={},{}
	if#rows>0 then
		divider:ClearAllPoints()
		divider:SetPoint("TOPLEFT",frame,"TOPLEFT",x+BLOCK_GAP,-tileTop)
		divider:SetSize(1,SQUARE)
		divider:SetColorTexture(A.color("hairline"))
		divider:Show()
		x=x+BLOCK_GAP+1+BLOCK_GAP
	else
		divider:Hide()
	end
	local ink={A.color("panelDeep")}
	for i=1,#rows do
		local record=rows[i]
		local cell=cellAt(i,pool)
		cell.matchId=record.id
		cell.record=record
		ids[i]=record.id
		cell:ClearAllPoints()
		cell:SetPoint("TOPLEFT",frame,"TOPLEFT",x,-tileTop)
		local resultTone=A.resultTone(record)
		local r,g,b=A.color(resultTone or"dim")
		cell.square:SetColorTexture(r,g,b,1)
		local letter=A.resultLetter(record)
		cell.letterText=letter
		texts[i]=letter
		cell.letter:SetText(letter)
		A.style(cell.letter,"number")
		cell.letter:SetTextColor(ink[1],ink[2],ink[3],1)
		local delta,deltaTone=A.ratingDelta(record)
		cell.delta:SetText(delta or"")
		A.style(cell.delta,"numberSmall",deltaTone or"dim")
		cell:Show()
		x=x+column+CELL_GAP
	end
	for i=#rows+1,#pool do
		local cell=pool[i]
		cell.matchId=nil
		cell.record=nil
		cell.letterText=nil
		cell:Hide()
	end
	return ids,texts,x
end

local function hideSecond()
	frame.split:Hide()
	frame.label2:Hide()
	paintFigures(frame.label2,frame.rating2,frame.today2,nil,nil)
	paintCells(secondCells,{},0,0,frame.divider2)
end

local function paint(character,format,rows,second)
	local text="No matches yet."
	local tone="dim"
	if character~=nil and format~=nil then
		text=A.formatLabel(format)
		tone="text"
	end
	local line=(#rows>0)and secondLine(format,character)or nil
	local blockWidth,ruleWidth,tint=paintBlock(text,tone,format,line,#rows>0)
	if#rows==0 then
		second=nil
	end

	local drawnSecond
	if second~=nil then
		local secondLineRead=secondLine(second.format,character)
		local secondWidth,secondTint=paintSecondBlock(second.format,secondLineRead)
		if secondWidth>blockWidth then
			blockWidth,ruleWidth=finishRule(secondWidth)
		end
		drawnSecond={format=second.format,line=secondLineRead,tint=secondTint}
	else
		hideSecond()
	end

	local height=barHeight()
	local tileX=#rows>0 and PAD+blockWidth+BLOCK_GAP+1+BLOCK_GAP or nil
	local ids,texts,x=paintCells(cells,rows,PAD+blockWidth,onLine(SQUARE),frame.divider)

	local width
	if#rows>0 then
		width=x-CELL_GAP+PAD
	else
		width=PAD+blockWidth+PAD
	end
	if drawnSecond~=nil then
		local secondIds,secondTexts,secondX=paintCells(secondCells,second.rows,PAD+blockWidth,
			secondMiddle()-SQUARE/2,frame.divider2)
		drawnSecond.ids,drawnSecond.texts=secondIds,secondTexts
		if secondX-CELL_GAP+PAD>width then
			width=secondX-CELL_GAP+PAD
		end
		height=twoRowHeight()
		frame.split:ClearAllPoints()
		frame.split:SetPoint("TOPLEFT",frame,"TOPLEFT",PAD,-barHeight())
		frame.split:SetSize(width-PAD*2,1)
		frame.split:SetColorTexture(A.color("hairline"))
		frame.split:Show()
	end
	frame:SetSize(width,height)
	local extra=height-barHeight()
	if extra~=grown then
		grown=extra
		placeAt(frame,extra)
	end

	local r,g,b=A.color("panel")
	frame.ground:SetColorTexture(r,g,b,drawnOpacity()/100)
	local blockMid,squareMid=middles(line~=nil,#rows>0)
	return ids,line,texts,tileX,ruleWidth,height,tint,blockMid,squareMid,drawnSecond
end

function A.secondsToMidnight()
	local ok,parts=pcall(date,"*t")
	if not ok or type(parts)~="table"then
		return nil
	end
	local okNext,nextDay=pcall(time,{year=parts.year,month=parts.month,day=parts.day+1,
		hour=0,min=0,sec=0})
	local now=time()
	if not okNext or type(nextDay)~="number"or type(now)~="number"or nextDay<=now then
		return nil
	end
	return nextDay-now+1
end

local function armMidnight(wanted)
	midnightCall=midnightCall+1
	if not wanted then
		return
	end
	local after=C_Timer and C_Timer.After
	local delay=A.secondsToMidnight()
	if type(after)~="function"or delay==nil then
		return
	end
	local call=midnightCall
	pcall(after,delay,function()
		if call==midnightCall then
			A.overlayRepaint("day")
		end
	end)
end

function A.overlayRepaint(source,via)
	if source~="combat"then
		heldToday={}
	end
	local ok,err=pcall(function()
		local wanted=A.overlayEnabled()or previewUp
		local reason
		if not wanted then
			reason=source=="preview"and"preview"or"off"
		elseif inCombat and A.overlayCombat()then
			reason="combat"
		end

		local format,ids=nil,{}
		local line,texts,tileX=nil,{},nil
		local ruleWidth,height,tint,blockMid,squareMid
		local kept
		local second
		if reason==nil then
			local db=A.db()
			local matches=db and type(db.matches)=="table"and db.matches or nil
			local count=matches and#matches or nil
			local character=A.barCharacter()
			local day=A.dayKey(A.stamp())
			if source=="combat"and frame~=nil and painted~=nil and painted.db==db
				and painted.matches==matches and painted.count==count
				and painted.character==character and painted.day==day then
				kept="kept"
				ids,format=painted.ids,painted.format
				line,texts,tileX=painted.line,painted.texts,painted.tileX
				ruleWidth,height,tint=painted.ruleWidth,painted.height,painted.tint
				blockMid,squareMid=painted.blockMid,painted.squareMid
				second=painted.second
			else
				if source=="combat"then
					kept="drawn"
				end
				local held,rows,wanted2
				character,held,rows,wanted2=subject()
				if build()==nil then
					return
				end
				ids,line,texts,tileX,ruleWidth,height,tint,blockMid,squareMid,second=
					paint(character,held,rows,wanted2)
				format=held
				painted={character=character,db=db,matches=matches,count=count,day=day,
					format=format,ids=ids,line=line,texts=texts,tileX=tileX,
					ruleWidth=ruleWidth,height=height,tint=tint,blockMid=blockMid,squareMid=squareMid,
					second=second}
				armMidnight(line~=nil or second~=nil)
			end
			if#ids==0 then
				reason="empty"
			end
			frame:Show()
		else
			if source~="combat"then
				painted=nil
			end
			if not wanted then
				armMidnight(false)
			end
			if frame then
				frame:Hide()
			end
		end

		local state=(reason==nil or reason=="empty")and"shown"or"hidden"
		local pairsDrawn={}
		for i=1,#ids do
			pairsDrawn[i]=tostring(ids[i])..":"..tostring(texts[i])
		end
		local title=ruleWidth~=nil and TITLE_TEXT or nil
		local rowsDrawn=second~=nil and 2 or(#ids>0 and 1 or 0)
		local secondFormat,secondIds
		if state=="shown"and second~=nil then
			secondFormat=second.format
			if type(second.ids)=="table"and#second.ids>0 then
				secondIds=table.concat(second.ids,"+")
			end
		end
		last={state=state,reason=reason,source=source,format=format,ids=ids,
			line=line,texts=texts,tileX=tileX,title=title,ruleWidth=ruleWidth,height=height,
			tint=tint,blockMid=blockMid,squareMid=squareMid,rows=rowsDrawn,second=second}
		A.trace("overlay",{
			source=source,
			via=via or kept,
			state=state,
			reason=reason,
			format=format,
			rows=state=="shown"and rowsDrawn or nil,
			records=#ids>0 and table.concat(ids,"+")or nil,
			secondFormat=secondFormat,
			secondRecords=secondIds,
			n=#ids,
			ratingFigure=line and line.rating or nil,
			tint=tint,
			today=line and line.today or nil,
			todayN=line and line.todayN or nil,
			cellTexts=#pairsDrawn>0 and table.concat(pairsDrawn,"+")or nil,
			tileX=tileX,
			title=title,
			ruleWidth=ruleWidth,
			height=height,
			blockMid=blockMid,
			squareMid=squareMid,
		},"ui")
	end)
	if not ok then
		A.noteError(err,"overlay")
	end
end

function A.overlayRecordStored()
	A.overlayRepaint("stored")
end

function A.resetOverlayPosition()
	local stored=A.setOverlayPosition(nil)
	if frame then
		placeAt(frame,grown)
	end
	return stored
end

function A.overlayPreview(on)
	if on==false then
		if not previewUp then
			return false
		end
		previewUp=false
		previewFormat=nil
		previewOpacity=nil
		A.overlayRepaint("preview")
		return"ended"
	end
	if previewUp then
		return"held"
	end
	previewUp=true
	A.overlayRepaint("preview")
	return"shown"
end

function A.overlayPreviewActive()
	return previewUp
end

function A.overlayPreviewFormat(format)
	if type(format)~="string"or format==""or A.formatShortLabel(format)==format then
		return false
	end
	previewFormat=format
	previewUp=true
	A.overlayRepaint("preview","format")
	return true
end

function A.overlayPreviewOpacity(value)
	local figure=tonumber(value)
	if figure==nil or figure~=figure or figure<OPACITY_MIN or figure>OPACITY_MAX then
		return false
	end
	previewOpacity=stepped(figure)
	A.overlayRepaint("preview","opacity")
	return previewOpacity
end

function A.overlayPreviewHeld()
	return previewFormat,previewOpacity
end

function A.overlayHover(index)
	if index==nil then
		A.hideTooltip()
		return"hidden"
	end
	if frame==nil or not frame:IsShown()then
		return false,"no-bar"
	end
	local firstRow=type(last.ids)=="table"and#last.ids or 0
	local cell
	if index>firstRow and last.second~=nil then
		cell=secondCells[index-firstRow]
	else
		cell=cells[index]
	end
	if cell==nil or not cell:IsShown()or cell.matchId==nil then
		return false,"no-tile"
	end
	if not hover(cell)then
		return false,"no-hover"
	end
	return"shown",cell.matchId
end

function A.overlayReadout()
	local lines={
		("overlay: %s, %d matches, opacity %d%%, hide in combat %s, second format %s, preview %s"):format(
			A.overlayEnabled()and"on"or"off",A.overlayCount(),A.overlayOpacity(),
			A.overlayCombat()and"on"or"off",A.overlayTwo()and"on"or"off",previewUp and"shown"or"none"),
	}
	local character,format,rows,second=subject()
	local who=(character==nil or character==SANDBOX_READER)and character or A.characterLabel(character)
	if character==nil then
		lines[#lines+1]="no readable character, so nothing to draw"
	elseif format==nil then
		lines[#lines+1]=("no stored match for %s, so the bar reads No matches yet."):format(who)
	else
		local ids={}
		for i=1,#rows do
			ids[i]=tostring(rows[i].id)
		end
		lines[#lines+1]=("%s for %s, newest first: %s"):format(A.formatLabel(format),who,
			table.concat(ids,", "))
		if second~=nil then
			local secondIds={}
			for i=1,#second.rows do
				secondIds[i]=tostring(second.rows[i].id)
			end
			lines[#lines+1]=("second row, %s, newest first: %s"):format(A.formatLabel(second.format),
				table.concat(secondIds,", "))
		elseif secondWanted()then
			lines[#lines+1]="second row: no other format played today"
		end
	end
	lines[#lines+1]=("drawn: %s%s"):format(last.state,
		last.reason and(", "..last.reason)or"")
	if last.title~=nil then
		local header=("header: %s, rule %d wide, bar %d high, block middle %s"):format(last.title,
			last.ruleWidth,last.height,tostring(last.blockMid))
		if last.squareMid~=nil then
			header=header..", squares middle "..tostring(last.squareMid)
		end
		lines[#lines+1]=header
	end
	if previewFormat~=nil or previewOpacity~=nil then
		lines[#lines+1]=("held for this session: format %s, opacity %s"):format(
			previewFormat or"none",previewOpacity and(previewOpacity.."%")or"none")
	end
	if hovered~=nil and hovered.id~=nil then
		lines[#lines+1]=("hovered: #%s, %s"):format(tostring(hovered.id),tostring(hovered.text))
	else
		lines[#lines+1]="hovered: none"
	end
	return lines
end

function A.overlayFrame()
	return frame
end

function A.overlayCells()
	return cells,secondCells
end

function A.overlayState()
	return last
end

A.on("PLAYER_LOGIN",function()
	inCombat=A.inCombatLockdown()
	A.overlayRepaint("login")
end)

A.on("PLAYER_REGEN_DISABLED",function()
	inCombat=true
	A.overlayRepaint("combat")
end)

A.on("PLAYER_REGEN_ENABLED",function()
	inCombat=false
	A.overlayRepaint("combat")
end)

A.on("PVP_RATED_STATS_UPDATE",function()
	if painted==nil or painted.tint~="unheard"then
		return
	end
	A.overlayRepaint("rated")
end)
