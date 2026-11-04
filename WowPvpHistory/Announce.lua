-- WowPvpHistory 0.75.26
-- Author:  Xenu-Sentinels
-- Project: wow-pvp-history
--          https://github.com/xenulive/wow-pvp-history
-- License: MIT, see LICENSE
local _,A=...

local SCREEN_UNITS=768

local TOP_DROP=SCREEN_UNITS/6

local RISE_SECONDS=0.5
local FALL_SECONDS=0.5

local FIRST_READ=2
local RETRY_EVERY=3
local SETTLE_READS=3
local MAX_ATTEMPTS=20

local firedFor

local reported=false

local banner

local lastShown

local reconsider

function A.announceEnabled()
	local db=A.db()
	if not db then
		return false
	end
	return type(db.ui)~="table"or db.ui.announce~=false
end

function A.setAnnounce(enabled)
	local db=A.db()
	if not db then
		return false
	end
	db.ui=db.ui or{}
	if enabled==false then
		db.ui.announce=false
	else
		db.ui.announce=nil
	end

	if A.notifyAnnounceSetting then
		A.notifyAnnounceSetting()
	end
	reconsider(enabled==false and"off"or"on")
	return true
end

local function readingOn(key)
	local db=A.db()
	if not db then
		return false
	end
	return type(db.ui)~="table"or db.ui[key]~=false
end

local function storeReading(key,enabled,notify)
	local db=A.db()
	if not db then
		return false
	end
	db.ui=db.ui or{}
	if enabled==false then
		db.ui[key]=false
	else
		db.ui[key]=nil
	end
	if type(notify)=="function"then
		notify()
	end
	if A.announcePreviewActive and A.announcePreviewActive()then
		pcall(A.announcePreview)
	end
	return true
end

function A.announceCompEnabled()
	return readingOn("announceComp")
end

function A.setAnnounceComp(enabled)
	return storeReading("announceComp",enabled,A.notifyAnnounceCompSetting)
end

function A.announceRematchEnabled()
	return readingOn("announceRematch")
end

function A.setAnnounceRematch(enabled)
	return storeReading("announceRematch",enabled,A.notifyAnnounceRematchSetting)
end

local TIME_MIN,TIME_MAX,TIME_STEP,TIME_DEFAULT=2,30,1,5

local OLD_TIME_ONE_NAME=5

local SIZE_MIN,SIZE_MAX,SIZE_STEP,SIZE_DEFAULT=75,150,5,100

local OPACITY_MIN,OPACITY_MAX,OPACITY_STEP,OPACITY_DEFAULT=0,100,5,85

local FIT_FLOOR=50

local function percentage(value,min,max,step)
	if type(value)~="number"or value~=value
		or value~=math.floor(value)or value<min or value>max
		or(value-min)%step~=0 then
		return nil
	end
	return value
end

local function rounded(value,min,max,step)
	if type(value)~="number"or value~=value
		or value==math.huge or value==-math.huge
	then
		return nil
	end
	return percentage(math.floor(value+0.5),min,max,step)
end

local function storedFigure(key,min,max,step,default)
	local db=A.db()
	if not db or type(db.ui)~="table"then
		return default
	end
	return percentage(db.ui[key],min,max,step)or default
end

local function storeFigure(key,value,min,max,step,default,notify,redraw)
	local db=A.db()
	if not db then
		return false
	end
	local want=rounded(value,min,max,step)
	if want==nil then
		return false
	end
	db.ui=db.ui or{}
	db.ui[key]=want~=default and want or nil

	if notify then
		notify()
	end
	if redraw and A.announcePreviewActive and A.announcePreviewActive()then
		pcall(A.announcePreview)
	end
	return true
end

function A.announceTime()
	return storedFigure("announceSeconds",TIME_MIN,TIME_MAX,TIME_STEP,TIME_DEFAULT)
end

function A.announceTimeRange()
	return TIME_MIN,TIME_MAX,TIME_STEP,TIME_DEFAULT
end

function A.announceSecondsFromPercent(percent)
	if type(percent)~="number"or percent~=percent or percent==math.huge or percent==-math.huge then
		return nil
	end
	local seconds=math.floor(percent*OLD_TIME_ONE_NAME/100+0.5)
	return math.max(TIME_MIN,math.min(TIME_MAX,seconds))
end

function A.convertAnnounceTime()
	local db=A.db()
	if not db or type(db.ui)~="table"or db.ui.announceTime==nil then
		return false
	end
	local percent=db.ui.announceTime
	db.ui.announceTime=nil
	local seconds=A.announceSecondsFromPercent(percent)
	if seconds and db.ui.announceSeconds==nil then
		db.ui.announceSeconds=seconds~=TIME_DEFAULT and seconds or nil
	end
	A.trace("settings",{
		source="announce-time-converted",
		from=type(percent)=="number"and percent or nil,
		seconds=A.announceTime(),
	},"ui")
	return true
end

A.on("PLAYER_LOGIN",function()
	A.convertAnnounceTime()
end)

function A.setAnnounceTime(value)
	return storeFigure("announceSeconds",value,TIME_MIN,TIME_MAX,TIME_STEP,TIME_DEFAULT,
		A.notifyAnnounceTimeSetting)
end

function A.announceSize()
	return storedFigure("announceSize",SIZE_MIN,SIZE_MAX,SIZE_STEP,SIZE_DEFAULT)
end

function A.announceSizeRange()
	return SIZE_MIN,SIZE_MAX,SIZE_STEP,SIZE_DEFAULT
end

function A.setAnnounceSize(value)
	return storeFigure("announceSize",value,SIZE_MIN,SIZE_MAX,SIZE_STEP,SIZE_DEFAULT,
		A.notifyAnnounceSizeSetting,true)
end

function A.announceOpacity()
	return storedFigure("announceOpacity",OPACITY_MIN,OPACITY_MAX,OPACITY_STEP,OPACITY_DEFAULT)
end

function A.announceOpacityRange()
	return OPACITY_MIN,OPACITY_MAX,OPACITY_STEP,OPACITY_DEFAULT
end

function A.setAnnounceOpacity(value)
	return storeFigure("announceOpacity",value,OPACITY_MIN,OPACITY_MAX,OPACITY_STEP,OPACITY_DEFAULT,
		A.notifyAnnounceOpacitySetting,true)
end

local CROWD_MIN,CROWD_MAX,CROWD_STEP,CROWD_DEFAULT=2,15,1,6

function A.announceCrowd()
	return storedFigure("announceCrowd",CROWD_MIN,CROWD_MAX,CROWD_STEP,CROWD_DEFAULT)
end

function A.announceCrowdRange()
	return CROWD_MIN,CROWD_MAX,CROWD_STEP,CROWD_DEFAULT
end

function A.setAnnounceCrowd(value)
	return storeFigure("announceCrowd",value,CROWD_MIN,CROWD_MAX,CROWD_STEP,CROWD_DEFAULT,
		A.notifyAnnounceCrowdSetting,true)
end

local SHAPES={
	{value="card",label="Card",said="as a card"},
	{value="headline",label="Headline",said="as a headline"},
	{value="split",label="Side by side",said="side by side"},
	{value="stacked",label="One column",said="in one column"},
}

local SHAPE_DEFAULT="card"

local function isShape(value)
	for i=1,#SHAPES do
		if SHAPES[i].value==value then
			return true
		end
	end
	return false
end

local heldShape

function A.announceShape()
	if heldShape~=nil then
		return heldShape
	end
	return A.announceStoredShape()
end

function A.announceStoredShape()
	local db=A.db()
	if not db or type(db.ui)~="table"then
		return SHAPE_DEFAULT
	end
	local held=db.ui.announceShape
	if isShape(held)then
		return held
	end
	return SHAPE_DEFAULT
end

function A.announceShapeChoices()
	local out={}
	for i=1,#SHAPES do
		out[i]={value=SHAPES[i].value,label=SHAPES[i].label,said=SHAPES[i].said}
	end
	return out
end

function A.setAnnounceShape(value)
	local db=A.db()
	if not db or not isShape(value)then
		return false
	end
	db.ui=db.ui or{}
	db.ui.announceShape=value~=SHAPE_DEFAULT and value or nil
	heldShape=nil

	if A.notifyAnnounceShapeSetting then
		A.notifyAnnounceShapeSetting()
	end
	if A.announcePreviewActive and A.announcePreviewActive()then
		pcall(A.announcePreview)
	end
	return true
end

function A.holdAnnounceShape(value)
	if value~=nil and not isShape(value)then
		return false
	end
	heldShape=value
	if A.announcePreviewActive and A.announcePreviewActive()then
		pcall(A.announcePreview)
	end
	A.trace("view",{source="typed-shape",shape=A.announceShape(),state=A.announceStoredShape()},
		"ui")
	return true
end

function A.announceHeldShape()
	return heldShape
end

local heldLocked

function A.announceLocked()
	if heldLocked~=nil then
		return heldLocked
	end
	return A.announceStoredLocked()
end

function A.announceStoredLocked()
	local db=A.db()
	if not db or type(db.ui)~="table"then
		return true
	end
	return db.ui.announceUnlocked~=true
end

function A.setAnnounceLocked(on)
	local db=A.db()
	if not db then
		return false
	end
	db.ui=db.ui or{}
	db.ui.announceUnlocked=(not on)and true or nil
	heldLocked=nil
	if A.notifyAnnounceLockSetting then
		A.notifyAnnounceLockSetting()
	end
	reconsider(on and"locked"or"unlocked")
	return true
end

function A.holdAnnounceLocked(value)
	if value~=nil and type(value)~="boolean"then
		return false
	end
	heldLocked=value
	if type(A.refreshOptionsWindow)=="function"then
		pcall(A.refreshOptionsWindow)
	end
	A.trace("view",{source="typed-lock",unlocked=not A.announceLocked(),held=heldLocked~=nil},
		"ui")
	reconsider(A.announceLocked()and"locked"or"unlocked")
	return true
end

function A.announceHeldLocked()
	return heldLocked
end

function A.announceSeconds()
	return A.announceTime()
end

function A.announceFit(width,room,chosen)
	if type(chosen)~="number"then
		chosen=SIZE_DEFAULT
	end
	if type(width)~="number"or width<=0 or type(room)~="number"or room<=0 then
		return chosen
	end
	local fits=math.floor(room*100/width)
	if fits>=chosen then
		return chosen
	end
	if fits<FIT_FLOOR then
		return FIT_FLOOR
	end
	return fits
end

local DEFAULT_POINT="TOP"
local DEFAULT_X=0
local DEFAULT_Y=-TOP_DROP

function A.announcePosition()
	return A.storedPosition("announcePosition")
end

function A.setAnnouncePosition(geometry)
	return A.storePosition("announcePosition",geometry,function()
		return DEFAULT_POINT,DEFAULT_X,DEFAULT_Y
	end)
end

local function contained(fn,...)
	local ok,err=pcall(fn,...)
	if ok then
		return
	end

	A.noteError(err,"announce")

	if not reported then
		reported=true
		A.say("the roster announcement stopped: "..tostring(err)
			..". /pvph announce off silences it")
	end
end

local SIDES={
	{side="against",label="VS",tone="loss",heading="ENEMIES"},
	{side="with",label="WITH",tone="win",heading="ALLIES"},
}

local UNSIDED_HEADING="KNOWN"

local COMP_HEADING="ENEMY COMP"

local NO_RECORD="-"

local RECORD_BUCKETS={
	against={"against"},
	with={"with"},
	summed={"against","with"},
}

local function recordText(held,side)
	if type(held)~="table"then
		return NO_RECORD
	end
	local wins,decided,draws=0,0,0
	for _,key in ipairs(RECORD_BUCKETS[side]or RECORD_BUCKETS.summed)do
		local bucket=held[key]
		if type(bucket)=="table"then
			wins=wins+(tonumber(bucket.wins)or 0)
			decided=decided+(tonumber(bucket.decided)or 0)
			draws=draws+(tonumber(bucket.draws)or 0)
		end
	end
	if decided<=0 then
		return NO_RECORD
	end
	return A.winRecordText({wins=wins,decided=decided,draws=draws})or NO_RECORD
end

local function worstStep(it)
	if it.rating~=nil and it.attitude~=nil then
		return math.min(it.rating,it.attitude)
	end
	return it.rating or it.attitude
end

local function worstFirst(a,b)
	local ra,rb=worstStep(a),worstStep(b)
	if ra~=rb then
		if ra==nil then
			return false
		end
		if rb==nil then
			return true
		end
		return ra<rb
	end
	if ra==nil then
		local ta,tb=a.text~=nil,b.text~=nil
		if ta~=tb then
			return ta
		end
		local ma,mb=a.met or 0,b.met or 0
		if ma~=mb then
			return ma>mb
		end
	end
	return a.name<b.name
end

local function isNoted(it)
	return type(it.text)=="string"and it.text~=""
end

local function notedFirst(a,b)
	local na,nb=isNoted(a),isNoted(b)
	if na~=nb then
		return na
	end
	return worstFirst(a,b)
end

local function sideOf(selfFaction,faction)
	if selfFaction==nil or faction==nil then
		return nil
	end
	if faction==selfFaction then
		return"with"
	end
	return"against"
end

local function compose(found,selfFaction,everyoneWith)
	if#found==0 then
		return nil
	end

	table.sort(found,notedFirst)

	local noted=0
	for i=1,#found do
		if found[i].text~=nil or found[i].rating~=nil or found[i].attitude~=nil then
			noted=noted+1
		end
	end

	local names={}
	local read={against=0,with=0,summed=0}
	for i=1,#found do
		local it=found[i]
		local side=everyoneWith and"with"or sideOf(selfFaction,it.faction)
		read[side or"summed"]=read[side or"summed"]+1
		local hasNote=isNoted(it)
		local _,scale,step=A.noteMark(it)
		names[i]={
			name=it.name,
			classToken=it.classToken,
			rating=it.rating,
			attitude=it.attitude,
			mark=it.mark,
			word=A.ratingText(step,scale),
			side=side,
			record=recordText(it.held,side),
			tags=type(it.tags)=="table"and it.tags or{},
			noted=hasNote,
			note=hasNote and it.text:match("^[^\r\n]*")or nil,
			lastMet=it.lastMet,
		}
	end

	local runs={}
	for s=1,#SIDES+1 do
		local want=SIDES[s]and SIDES[s].side or nil
		local members={}
		for i=1,#names do
			if names[i].side==want then
				members[#members+1]=names[i]
			end
		end
		if#members>0 then
			runs[#runs+1]={
				side=want,
				label=SIDES[s]and SIDES[s].label or nil,
				tone=SIDES[s]and SIDES[s].tone or nil,
				heading=SIDES[s]and SIDES[s].heading or UNSIDED_HEADING,
				names=members,
			}
		end
	end

	local tagLines=0
	for i=1,#names do
		if#names[i].tags>0 then
			tagLines=tagLines+1
		end
	end

	return{
		count=#found,
		noted=noted,
		tagLines=tagLines,
		readAgainst=read.against,
		readWith=read.with,
		readSummed=read.summed,
		names=names,
		runs=runs,
	}
end

local function foundEntry(guid,name,classToken,faction,rating,text,tags,met,held,attitude)
	return{
		guid=guid,
		name=name,
		classToken=classToken,
		faction=faction,
		rating=rating,
		attitude=attitude,
		mark=(A.noteMark({rating=rating,attitude=attitude})),
		text=text,
		tags=tags,
		met=met,
		held=held,
	}
end

local COMP_FLOOR=5

local REMATCH_FLOOR=2

function A.announceCompFloor()
	return COMP_FLOOR
end

function A.announceRematchFloor()
	return REMATCH_FLOOR
end

local RESULT_SAID={win="won",loss="lost",draw="drew"}
local RESULT_TONE={win="win",loss="loss"}

local MINUTE,HOUR,DAY=60,3600,86400

local function dayNumber(epoch)
	local ok,parts=pcall(date,"*t",epoch)
	if not ok or type(parts)~="table"then
		return nil
	end
	local okNoon,noon=pcall(time,{year=parts.year,month=parts.month,day=parts.day,hour=12})
	if not okNoon or type(noon)~="number"then
		return nil
	end
	return math.floor(noon/DAY)
end

function A.announceWhenText(epoch,now)
	if type(epoch)~="number"or type(now)~="number"or epoch>now then
		return nil
	end
	local seconds=now-epoch
	if seconds<MINUTE then
		return"just now"
	end
	if seconds<HOUR then
		return("%d min ago"):format(math.floor(seconds/MINUTE))
	end
	local today,that=dayNumber(now),dayNumber(epoch)
	local days=(today~=nil and that~=nil)and(today-that)or math.floor(seconds/DAY)
	if days<=0 then
		return("%d h ago"):format(math.floor(seconds/HOUR))
	end
	if days==1 then
		return"yesterday"
	end
	if days<14 then
		return("%d d ago"):format(days)
	end
	return("%d wk ago"):format(math.floor(days/7))
end

local function lastMetText(lastMet)
	if type(lastMet)~="table"or type(lastMet.when)~="string"then
		return nil
	end
	local said=RESULT_SAID[lastMet.result]
	return said and(lastMet.when..", "..said)or lastMet.when,RESULT_TONE[lastMet.result]or"dim"
end

local function rematchText(rematch)
	if type(rematch)~="table"or type(rematch.when)~="string"then
		return nil
	end
	local said=RESULT_SAID[rematch.result]
	return"Met this lobby "..rematch.when..(said and(", you "..said)or""),
		RESULT_TONE[rematch.result]or"dim"
end

local function endedAt(record)
	return A.recordEpoch(record)or A.stampEpoch(record.completedAt)or A.stampEpoch(record.openedAt)
end

local function strongMatch(players,key)
	local held=type(key)=="string"and players[key]or nil
	if type(held)~="table"then
		return false
	end
	return type(held.names)~="table"or held.names[1]~=key
end

local function weakName(index,name)
	if index[name]==false then
		return true
	end
	local bare=A.bareName(name)
	return bare~=nil and bare~=name and index[bare]==false
end

local function lastMetFor(found,now,subject)
	local wanted,left={},0
	for i=1,#found do
		local guid=found[i].guid
		if type(guid)=="string"and wanted[guid]==nil then
			wanted[guid]=false
			left=left+1
		end
	end
	local db=A.db()
	local matches=(db and type(db.matches)=="table")and db.matches or{}
	for i=#matches,1,-1 do
		if left==0 then
			break
		end
		local record=matches[i]
		local participants=type(record)=="table"and record~=subject and record.participants or nil
		if type(participants)=="table"then
			for guid,held in pairs(wanted)do
				if held==false and participants[guid]~=nil then
					wanted[guid]=record
					left=left-1
				end
			end
		end
	end
	for i=1,#found do
		local record=wanted[found[i].guid]
		if type(record)=="table"then
			local result=A.effectiveResult(record)
			local when=A.announceWhenText(endedAt(record),now)
			found[i].lastMet=when and{when=when,result=result}or nil
		end
	end
end

local function compReading(enemy,format,character,reading)
	reading.comp="-"
	local reason
	if not A.announceCompEnabled()then
		reason="off"
	elseif enemy.rows==0 then
		reason="no-side"
	elseif#enemy.tokens<enemy.rows then
		reason="secret"
	elseif format~=nil and not A.compFormat(format)then
		reason="no-format"
	end
	if reason then
		reading.compReason=reason
		return nil
	end

	local signature=A.classSignatureFrom(enemy.tokens)
	reading.comp=signature or"-"
	local season=A.seasonNow()
	local held=nil
	local rows=A.classCompTally(format,season,character)
	for i=1,#rows do
		if rows[i].signature==signature then
			held=rows[i]
			break
		end
	end
	if held~=nil then
		reading.compGames=held.decided
		reading.compRecord=("%d-%d"):format(held.wins,held.losses)
	end
	if held==nil or held.decided<COMP_FLOOR then
		reading.compReason="under-floor"
		return nil
	end
	if held.wins>held.losses then
		reading.compReason="winning"
		return nil
	end
	reading.compReason="none"
	return{
		signature=signature,
		games=held.games,
		wins=held.wins,
		losses=held.losses,
		scope=season~=nil and"this season"or"every season",
	}
end

local function rematchReading(enemy,format,now,reading,subject)
	reading.rematchWeak=enemy.weak
	local reason
	if not A.announceRematchEnabled()then
		reason="off"
	elseif enemy.rows==0 then
		reason="no-side"
	elseif enemy.strongCount==0 then
		reason="nobody"
	end
	if reason then
		reading.rematchReason=reason
		return nil
	end

	local db=A.db()
	local matches=(db and type(db.matches)=="table")and db.matches or{}
	local entries={}
	for i=#matches,1,-1 do
		local record=matches[i]
		if type(record)=="table"and record~=subject and record.format~=nil
			and(format==nil or record.format==format)
		then
			entries[#entries+1]={kind="match",subject=record}
		end
	end
	local newest=A.buildSessions(entries)[1]
	if newest==nil or type(now)~="number"then
		reading.rematchReason="no-session"
		return nil
	end

	local met,latest={},nil
	local count=0
	for i=1,#newest.entries do
		local record=newest.entries[i].subject
		local participants=type(record.participants)=="table"and record.participants or{}
		for guid in pairs(enemy.strong)do
			if participants[guid]~=nil then
				latest=latest or record
				if not met[guid]then
					met[guid]=true
					count=count+1
				end
			end
		end
	end
	reading.rematch=count
	if now-newest.endEpoch>A.sessionGapMinutes()*MINUTE then
		reading.rematchReason="earlier"
		return nil
	end
	if count<REMATCH_FLOOR then
		reading.rematchReason="under-two"
		return nil
	end
	local ended=endedAt(latest)
	local when=A.announceWhenText(ended,now)
	if when==nil then
		reading.rematchReason="no-session"
		return nil
	end
	reading.rematchReason="none"
	return{
		count=count,
		minutesAgo=math.floor((now-ended)/MINUTE),
		when=when,
		result=(A.effectiveResult(latest)),
	}
end

function A.announceKnown(rows,selfName,selfQualified,nameIndex,record)
	if type(rows)~="table"or#rows==0 then
		return nil
	end

	local db=A.db()
	local players=(db and type(db.players)=="table")and db.players or{}

	local index=type(nameIndex)=="table"and nameIndex or A.playerNameIndex()
	local found,seen={},{}

	local selfFaction=nil
	for i=1,#rows do
		local row=rows[i]
		local name=type(row)=="table"and row.name or nil
		if name~=nil and(name==selfName or name==selfQualified)then
			selfFaction=row.faction
			break
		end
	end

	local enemy={tokens={},rows=0,strong={},strongCount=0,weak=0}

	for i=1,#rows do
		local row=rows[i]
		local name=type(row)=="table"and row.name or nil
		if type(name)=="string"and name~=""
			and name~=selfName and name~=selfQualified
		then
			local guid=A.playerByName(index,name)
			if sideOf(selfFaction,row.faction)=="against"then
				enemy.rows=enemy.rows+1
				if type(row.classToken)=="string"and row.classToken~=""then
					enemy.tokens[#enemy.tokens+1]=row.classToken
				end
				if strongMatch(players,guid)then
					if not enemy.strong[guid]then
						enemy.strong[guid]=true
						enemy.strongCount=enemy.strongCount+1
					end
				elseif guid~=nil or weakName(index,name)then
					enemy.weak=enemy.weak+1
				end
			end
			if guid and not seen[guid]then
				seen[guid]=true
				local note=A.noteFor(guid)
				local text=type(note)=="table"and note.text or nil
				local rating=type(note)=="table"and note.rating or nil
				local attitude=type(note)=="table"and note.attitude or nil
				local tags=type(note)=="table"and note.tags or nil
				local held=players[guid]
				local met=(type(held)=="table"and type(held.matches)=="number")
					and held.matches or 0
				if text~=nil or rating~=nil or attitude~=nil or met>0 then
					found[#found+1]=foundEntry(guid,name,row.classToken,row.faction,rating,text,tags,
						met,held,attitude)
				end
			end
		end
	end

	if#found==0 then
		return nil
	end
	local now=type(time)=="function"and time()or nil
	lastMetFor(found,now,record)
	local composed=compose(found,selfFaction)
	local format=type(record)=="table"and(record.format or record.liveFormat)or nil
	local character=type(record)=="table"and record.character or nil
	local reading={}
	composed.comp=compReading(enemy,format,character,reading)
	composed.rematch=rematchReading(enemy,format,now,reading,record)
	composed.reading=reading
	return composed
end

local function classFor(guid)
	local fn=GetPlayerInfoByGUID
	if type(fn)~="function"then
		return nil
	end
	local ok,_,token=pcall(fn,guid)
	if ok and type(token)=="string"and A.canRead(token)and token~=""then
		return token
	end
	return nil
end

function A.announceGroup(guids,selfGuid)
	if type(guids)~="table"or#guids==0 then
		return nil,{}
	end

	local db=A.db()
	local players=(db and type(db.players)=="table")and db.players or{}

	local found,seen,qualified={},{},{}
	for i=1,#guids do
		local guid=guids[i]
		if type(guid)=="string"and guid~=""and guid~=selfGuid and not seen[guid]then
			seen[guid]=true
			local held=players[guid]
			if type(held)~="table"then
				held=nil
			end
			local note=A.noteFor(guid)
			local text=type(note)=="table"and note.text or nil
			local rating=type(note)=="table"and note.rating or nil
			local attitude=type(note)=="table"and note.attitude or nil
			local tags=type(note)=="table"and note.tags or nil
			local met=(held and type(held.matches)=="number")and held.matches or 0

			local name=held and type(held.names)=="table"and held.names[1]or nil
			if type(name)~="string"or name==""then
				name=type(note)=="table"and note.name or nil
			end

			if(text~=nil or rating~=nil or attitude~=nil or met>0)and type(name)=="string"and name~=""then
				qualified[#qualified+1]=guid
				found[#found+1]=foundEntry(guid,name,classFor(guid),nil,rating,text,tags,met,held,
					attitude)
			end
		end
	end

	return compose(found,nil,true),qualified
end

local previewUp=false

local plateUp=false

local PLATE_WORD="Announcement"

local FRAME_NAME="WowPvpHistoryAnnounce"

local drawnScale=1

local fadeStarted
local dragFrom

local dragging=false

local NOTHING_READ={}

local drawnPercent

local drawCount=0

local REFIT_AFTER={0,1}

local drawnTall

local ANCHOR_X={
	TOPLEFT="left",LEFT="left",BOTTOMLEFT="left",
	TOPRIGHT="right",RIGHT="right",BOTTOMRIGHT="right",
	TOP="centre",BOTTOM="centre",CENTER="centre",
}

local ANCHOR_Y={
	TOPLEFT="top",TOP="top",TOPRIGHT="top",
	LEFT="middle",CENTER="middle",RIGHT="middle",
	BOTTOMLEFT="bottom",BOTTOM="bottom",BOTTOMRIGHT="bottom",
}

local function screenWidth()
	if type(UIParent)~="table"or type(UIParent.GetWidth)~="function"then
		return nil
	end
	local ok,width=pcall(UIParent.GetWidth,UIParent)
	if not ok or type(width)~="number"or width<=0 then
		return nil
	end
	return width
end

local function screenRoom()
	local width=screenWidth()
	if width==nil then
		return nil
	end
	local stored=A.announcePosition()
	local point=stored and stored.point or DEFAULT_POINT
	local x=stored and stored.x or DEFAULT_X
	local side=ANCHOR_X[point]
	if side==nil then
		return nil
	end

	local centre
	if side=="left"then
		centre=x+SCREEN_UNITS/2
	elseif side=="right"then
		centre=width+x-SCREEN_UNITS/2
	else
		centre=width/2+x
	end

	local near=math.min(centre,width-centre)
	if near<=0 then
		return nil
	end
	return near*2
end

local function screenBelow()
	local stored=A.announcePosition()
	local point=stored and stored.point or DEFAULT_POINT
	local y=stored and stored.y or DEFAULT_Y
	local edge=ANCHOR_Y[point]
	if edge==nil then
		return nil
	end
	local frameHeight=SCREEN_UNITS/6
	local top
	if edge=="top"then
		top=SCREEN_UNITS+y
	elseif edge=="middle"then
		top=SCREEN_UNITS/2+y+frameHeight/2
	else
		top=y+frameHeight
	end
	if top<=0 then
		return nil
	end
	return math.min(top,SCREEN_UNITS)
end

local function placeAt(frame,scale)
	local stored=A.announcePosition()
	local point=stored and stored.point or DEFAULT_POINT
	local x=stored and stored.x or DEFAULT_X
	local y=stored and stored.y or DEFAULT_Y
	pcall(frame.ClearAllPoints,frame)
	pcall(frame.SetPoint,frame,point,UIParent,point,x/scale,y/scale)
end

local function applyScale(frame,percent,tall)
	local scale=percent/100
	drawnScale=scale
	drawnPercent=percent
	drawnTall=type(tall)=="number"and tall or nil
	pcall(frame.SetScale,frame,scale)
	pcall(frame.SetSize,frame,SCREEN_UNITS/scale,(SCREEN_UNITS/6)/scale)
	placeAt(frame,scale)
end

local function escapeList(on,name)
	name=name or FRAME_NAME
	if type(UISpecialFrames)~="table"then
		return
	end
	for i=#UISpecialFrames,1,-1 do
		if UISpecialFrames[i]==name then
			if on then
				return
			end
			table.remove(UISpecialFrames,i)
		end
	end
	if on then
		UISpecialFrames[#UISpecialFrames+1]=name
	end
end

local function release(frame)
	previewUp=false
	plateUp=false
	if type(frame)=="table"and frame.word then
		pcall(frame.word.Hide,frame.word)
	end
	dragFrom=nil
	dragging=false
	escapeList(false)
	if type(A.refreshOptionsWindow)=="function"then
		pcall(A.refreshOptionsWindow)
	end
	if type(frame)~="table"then
		return
	end
	pcall(frame.EnableMouse,frame,false)
	pcall(frame.SetMovable,frame,false)
end

local function hold(frame)
	frame:SetScript("OnUpdate",nil)
	fadeStarted=nil
	dragFrom=nil
	frame:SetMovable(true)
	frame:EnableMouse(true)
	frame:SetAlpha(1)
	previewUp=true
	escapeList(true)
	frame:Show()
	if type(A.refreshOptionsWindow)=="function"then
		pcall(A.refreshOptionsWindow)
	end
end

reconsider=function(cause,deferred)
	local windowUp=type(A.optionsWindowShown)=="function"and A.optionsWindowShown()
	if not plateUp and not windowUp then
		return
	end
	if deferred and type(C_Timer)=="table"and type(C_Timer.After)=="function"then
		C_Timer.After(0,function()
			A.announcePlateRefresh(cause)
		end)
		return
	end
	A.announcePlateRefresh(cause)
end

local GROUND={0.055,0.059,0.071}
local GROUND_EDGE={1,1,1,0.1}

local TAG_EDGE={1,1,1,0.2}
local SIDE_RULE={1,1,1,0.25}

local NOTE_MARK="N"

local function edgeAlpha(opacity)
	return math.min(1,GROUND_EDGE[4]*(opacity/OPACITY_DEFAULT))
end

local function colourEdges(edges,r,g,b,a)
	for i=1,#edges do
		edges[i]:SetColorTexture(r,g,b,a)
	end
end

local function applyOpacity(frame,opacity)
	local rim=edgeAlpha(opacity)
	frame.plate:SetColorTexture(GROUND[1],GROUND[2],GROUND[3],opacity/100)
	colourEdges(frame.edges,GROUND_EDGE[1],GROUND_EDGE[2],GROUND_EDGE[3],rim)
	for i=1,#frame.pills do
		local pill=frame.pills[i]
		pill.ground:SetColorTexture(GROUND[1],GROUND[2],GROUND[3],opacity/100)
		colourEdges(pill.edges,GROUND_EDGE[1],GROUND_EDGE[2],GROUND_EDGE[3],rim)
	end
end

local function fourEdges(frame,layer)
	local out={}
	for i=1,4 do
		out[i]=frame:CreateTexture(nil,layer)
	end
	return out
end

local function box(edges,origin,x,y,w,h)
	local top,bottom,left,right=edges[1],edges[2],edges[3],edges[4]
	for i=1,4 do
		edges[i]:ClearAllPoints()
		edges[i]:Show()
	end
	top:SetPoint("TOPLEFT",origin,"TOPLEFT",x,-y)
	top:SetSize(w,1)
	bottom:SetPoint("TOPLEFT",origin,"TOPLEFT",x,-(y+h-1))
	bottom:SetSize(w,1)
	left:SetPoint("TOPLEFT",origin,"TOPLEFT",x,-y)
	left:SetSize(1,h)
	right:SetPoint("TOPLEFT",origin,"TOPLEFT",x+w-1,-y)
	right:SetSize(1,h)
end

local function hideAll(list)
	for i=1,#list do
		list[i]:Hide()
	end
end

local function text(frame,role,colorName)
	return A.lineText(frame,role,nil,colorName)
end

local attachStrip

local function build()
	if banner then
		return banner
	end
	if type(CreateFrame)~="function"then
		return nil
	end

	local frame=CreateFrame("Frame",FRAME_NAME,UIParent)
	if type(frame)~="table"or type(frame.EnableMouse)~="function"then
		return nil
	end
	frame:EnableMouse(false)
	placeAt(frame,drawnScale)
	frame:SetSize(SCREEN_UNITS,SCREEN_UNITS/6)
	frame:SetScript("OnHide",function(self)
		local was=plateUp and"plate"or(previewUp and"preview"or"banner")
		local readable,stillShown=pcall(self.IsShown,self)
		if readable and stillShown then
			A.trace("view",{source="banner-hide",state="ignored",kind=was},"ui")
			return
		end
		release(self)
		if was~="plate"then
			reconsider(was=="preview"and"preview-ended"or"banner-ended",true)
		end
	end)

	frame:SetClampedToScreen(true)
	frame:SetMovable(false)
	frame:RegisterForDrag("LeftButton")
	frame:SetScript("OnDragStart",function(self)
		if not pcall(self.StartMoving,self)then
			return
		end
		dragging=true
		if fadeStarted~=nil and not previewUp and type(GetTime)=="function"then
			dragFrom=GetTime()
			self:SetAlpha(1)
		end
	end)
	frame:SetScript("OnDragStop",function(self)
		A.stopDrag(self)
		dragging=false
		local paused
		if dragFrom~=nil and fadeStarted~=nil then
			local now=GetTime()
			paused=now-dragFrom
			fadeStarted=now-math.max(dragFrom-fadeStarted,RISE_SECONDS)
		end
		dragFrom=nil
		local read=A.frameGeometry(self)
		if read and read.point then
			read.x=read.x*drawnScale
			read.y=read.y*drawnScale
			A.setAnnouncePosition(read)
		end
		local at=read or NOTHING_READ
		A.trace("announce",{
			reason="moved",
			held=previewUp,
			drag=plateUp and"plate"or(previewUp and"preview"or"banner"),
			point=at.point,
			x=A.unitFigure(at.x),
			y=A.unitFigure(at.y),
			paused=A.unitFigure(paused),
		})
	end)
	frame:Hide()

	attachStrip(frame)

	banner=frame
	return banner
end

attachStrip=function(frame)
	frame.plate=frame:CreateTexture(nil,"BACKGROUND")
	frame.plate:SetPoint("TOP",frame,"TOP",0,0)
	frame.plate:Hide()
	frame.edges=fourEdges(frame,"BORDER")
	frame.edges[1]:SetPoint("TOPLEFT",frame.plate,"TOPLEFT",0,0)
	frame.edges[1]:SetPoint("TOPRIGHT",frame.plate,"TOPRIGHT",0,0)
	frame.edges[1]:SetHeight(1)
	frame.edges[2]:SetPoint("BOTTOMLEFT",frame.plate,"BOTTOMLEFT",0,0)
	frame.edges[2]:SetPoint("BOTTOMRIGHT",frame.plate,"BOTTOMRIGHT",0,0)
	frame.edges[2]:SetHeight(1)
	frame.edges[3]:SetPoint("TOPLEFT",frame.plate,"TOPLEFT",0,0)
	frame.edges[3]:SetPoint("BOTTOMLEFT",frame.plate,"BOTTOMLEFT",0,0)
	frame.edges[3]:SetWidth(1)
	frame.edges[4]:SetPoint("TOPRIGHT",frame.plate,"TOPRIGHT",0,0)
	frame.edges[4]:SetPoint("BOTTOMRIGHT",frame.plate,"BOTTOMRIGHT",0,0)
	frame.edges[4]:SetWidth(1)
	hideAll(frame.edges)

	frame.labels={}
	for i=1,#SIDES do
		local label=text(frame,"announceLabel",SIDES[i].tone)
		label:SetText(SIDES[i].label)
		label:Hide()
		frame.labels[SIDES[i].side]=label
	end

	frame.divider=frame:CreateTexture(nil,"ARTWORK")
	frame.divider:SetColorTexture(SIDE_RULE[1],SIDE_RULE[2],SIDE_RULE[3],SIDE_RULE[4])
	frame.divider:Hide()

	frame.pills={}

	frame.rows={}
	frame.heads={}

	frame.headline=text(frame,"announceName","bright")
	frame.headline:Hide()

	frame.band={
		head=text(frame,"announceLabel","loss"),
		record=text(frame,"announceRecord","loss"),
		classes=text(frame,"announceName","bright"),
		sub=text(frame,"announceTag","dim"),
	}
	frame.band.record:SetJustifyH("RIGHT")
	frame.rematch=text(frame,"announceTag","dim")
	frame.band.head:Hide()
	frame.band.record:Hide()
	frame.band.classes:Hide()
	frame.band.sub:Hide()
	frame.rematch:Hide()

	frame.word=frame:CreateFontString(nil,"OVERLAY")
	A.style(frame.word,"label","text")
	frame.word:SetJustifyH("CENTER")
	frame.word:SetWordWrap(false)
	frame.word:SetPoint("CENTER",frame.plate,"CENTER",0,0)
	frame.word:Hide()
end

local function pillAt(frame,i)
	local pill=frame.pills[i]
	if pill then
		return pill
	end
	pill={chips={}}
	pill.ground=frame:CreateTexture(nil,"BACKGROUND")
	pill.edges=fourEdges(frame,"BORDER")
	pill.bar=frame:CreateTexture(nil,"ARTWORK")
	pill.name=text(frame,"announceName","bright")
	pill.record=text(frame,"announceRecord","dim")
	pill.mark=frame:CreateTexture(nil,"ARTWORK")
	pill.mark:SetColorTexture(A.color("noteWord"))
	pill.markText=text(frame,"announceMark")
	pill.markText:SetJustifyH("CENTER")
	pill.markText:SetText(NOTE_MARK)
	local r,g,b=A.color("panelDeep")
	pill.markText:SetTextColor(r,g,b,1)
	pill.markText:SetPoint("CENTER",pill.mark,"CENTER",0,0)
	frame.pills[i]=pill
	return pill
end

local function chipAt(frame,pill,j)
	local chip=pill.chips[j]
	if chip then
		return chip
	end
	chip={edges=fourEdges(frame,"BORDER"),label=text(frame,"announceTag","chipText")}
	pill.chips[j]=chip
	return chip
end

local function hideChip(chip)
	hideAll(chip.edges)
	chip.label:Hide()
end

local function hidePill(pill)
	pill.ground:Hide()
	hideAll(pill.edges)
	pill.bar:Hide()
	pill.name:Hide()
	pill.record:Hide()
	pill.mark:Hide()
	pill.markText:Hide()
	for j=1,#pill.chips do
		hideChip(pill.chips[j])
	end
end

local function pillName(name)
	return(A.nameParts(name,name))
end

local function paint(frame,composed,shape,cap)
	cap=type(cap)=="number"and cap>0 and cap or A.metric("announceStripWidth")
	local edgeWidth=A.metric("announcePillEdge")
	local padLeft,padRight=A.metric("announcePillPadLeft"),A.metric("announcePillPadRight")
	local padY,lineHeight=A.metric("announcePillPadY"),A.metric("announcePillLine")
	local partGap,rowGap=A.metric("announcePillPartGap"),A.metric("announcePillRowGap")
	local markSide=A.metric("announceNoteMark")
	local tagHeight,tagPad,tagGap=A.metric("announceTagHeight"),A.metric("announceTagPad"),
		A.metric("announceTagGap")
	local pillGap,labelGap=A.metric("announcePillGap"),A.metric("announceLabelGap")
	local stripGap,sideGap=A.metric("announceStripLineGap"),A.metric("announceSideGap")
	local ruleWidth,ruleHeight=A.metric("announceSideRule"),A.metric("announceSideRuleHeight")
	local oneLine=padY*2+lineHeight

	local origin=frame.plate
	local names=composed.names

	local sized,indexOf={},{}
	for i=1,#names do
		local it=names[i]
		indexOf[it]=i
		local pill=pillAt(frame,i)
		local shown=pillName(it.name)
		pill.name:SetText(shown)
		pill.name:SetTextColor(A.classColor(it.classToken))
		pill.record:SetText(it.record)
		local chipWidths,tagsWidth={},0
		for j=1,#it.tags do
			local chip=chipAt(frame,pill,j)
			local word=tostring(it.tags[j])
			chip.label:SetText(word)
			chipWidths[j]=A.textRoom(chip.label,word)+tagPad*2
			tagsWidth=tagsWidth+chipWidths[j]+(j>1 and tagGap or 0)
		end
		local nameWidth=A.textRoom(pill.name,shown)
		local recordWidth=A.textRoom(pill.record,it.record)
		local top=padLeft+nameWidth+partGap+recordWidth+(it.noted and(partGap+markSide)or 0)
			+padRight
		local width=top
		if#it.tags>0 then
			width=math.max(top,padLeft+tagsWidth+padRight)
		end
		sized[i]={
			it=it,
			pill=pill,
			nameWidth=nameWidth,
			recordWidth=recordWidth,
			chipWidths=chipWidths,
			width=width,
			height=oneLine+(#it.tags>0 and(rowGap+tagHeight)or 0),
		}
	end
	for i=#names+1,#frame.pills do
		hidePill(frame.pills[i])
	end

	local groups,bySide={},{}
	for r=1,#(composed.runs or{})do
		local run=composed.runs[r]
		local items={}
		for k=1,#run.names do
			items[k]=sized[indexOf[run.names[k]]]
		end
		local group={side=run.side,label=run.label,items=items}
		groups[#groups+1]=group
		if run.side~=nil then
			bySide[run.side]=group
		end
	end

	local function labelWidth(group)
		if group.label==nil then
			return 0
		end
		return A.textRoom(frame.labels[group.side],group.label)
	end

	local function oneLineWidth(group)
		local width=labelWidth(group)+labelGap
		for k=1,#group.items do
			width=width+group.items[k].width+(k>1 and pillGap or 0)
		end
		return width
	end

	local against,with=bySide.against,bySide.with
	local shared=nil
	if against~=nil and with~=nil then
		shared=shape=="split"
			and oneLineWidth(against)+sideGap*2+ruleWidth+oneLineWidth(with)<=cap
	end

	local cut,marks,nameCut,partCut=0,0,0,0
	local pills={against=0,with=0,unsided=0}
	local lineCounts={against=0,with=0,unsided=0}
	local lines={}

	local function newLine()
		local last=lines[#lines]
		local top=last and(last.top+last.height+stripGap)or 0
		local line={top=top,height=0,right=0}
		lines[#lines+1]=line
		return line
	end

	local function placeLabel(group,x,line)
		local label=frame.labels[group.side]
		label:ClearAllPoints()
		label:SetPoint("LEFT",origin,"TOPLEFT",x,-(line.top+padY+lineHeight/2))
		label:Show()
	end

	local function placePill(item,x,line,room)
		local pill,it=item.pill,item.it
		local width=math.min(item.width,room)
		local top=line.top
		pill.ground:ClearAllPoints()
		pill.ground:SetPoint("TOPLEFT",origin,"TOPLEFT",x,-top)
		pill.ground:SetSize(width,item.height)
		pill.ground:Show()
		box(pill.edges,origin,x,top,width,item.height)
		pill.bar:ClearAllPoints()
		pill.bar:SetPoint("TOPLEFT",origin,"TOPLEFT",x,-top)
		pill.bar:SetSize(edgeWidth,item.height)
		pill.bar:SetColorTexture(A.color(it.mark))
		pill.bar:Show()

		local after=partGap+item.recordWidth+(it.noted and(partGap+markSide)or 0)
		local nameRoom=math.max(width-padLeft-padRight-after,1)
		local nameWidth=math.min(item.nameWidth,nameRoom)
		if nameWidth<item.nameWidth then
			nameCut=nameCut+1
		end
		local middle=-(top+padY+lineHeight/2)
		pill.name:ClearAllPoints()
		pill.name:SetPoint("LEFT",origin,"TOPLEFT",x+padLeft,middle)
		pill.name:SetWidth(nameWidth)
		pill.name:Show()
		local inner=x+width-padRight
		local at=x+padLeft+nameWidth+partGap
		local recordWidth=math.max(math.min(item.recordWidth,inner-at),0)
		pill.record:ClearAllPoints()
		pill.record:SetPoint("LEFT",origin,"TOPLEFT",at,middle)
		if recordWidth<1 then
			pill.record:Hide()
		else
			pill.record:SetWidth(recordWidth<item.recordWidth and recordWidth or 0)
			pill.record:Show()
		end
		if recordWidth<item.recordWidth then
			partCut=partCut+1
		end
		local markAt=at+recordWidth+partGap
		if it.noted and markAt+markSide>inner then
			partCut=partCut+1
			pill.mark:Hide()
			pill.markText:Hide()
		elseif it.noted then
			pill.mark:ClearAllPoints()
			pill.mark:SetPoint("TOPLEFT",origin,"TOPLEFT",markAt,-(top+padY+(lineHeight-markSide)/2))
			pill.mark:SetSize(markSide,markSide)
			pill.mark:Show()
			pill.markText:Show()
			marks=marks+1
		else
			pill.mark:Hide()
			pill.markText:Hide()
		end

		local tagTop=top+oneLine-padY+rowGap
		local tagRoom=width-padLeft-padRight
		local cx,wasCut=0,false
		for j=1,#pill.chips do
			local chip=pill.chips[j]
			local chipWidth=item.chipWidths[j]
			if chipWidth==nil or wasCut then
				hideChip(chip)
			else
				if cx+chipWidth>tagRoom then
					wasCut=true
					chipWidth=tagRoom-cx
				end
				if chipWidth<tagPad*2+1 then
					hideChip(chip)
				else
					local chipX=x+padLeft+cx
					box(chip.edges,origin,chipX,tagTop,chipWidth,tagHeight)
					colourEdges(chip.edges,TAG_EDGE[1],TAG_EDGE[2],TAG_EDGE[3],TAG_EDGE[4])
					chip.label:ClearAllPoints()
					chip.label:SetPoint("LEFT",origin,"TOPLEFT",chipX+tagPad,-(tagTop+tagHeight/2))
					chip.label:SetWidth(wasCut and(chipWidth-tagPad*2)or 0)
					chip.label:Show()
					cx=cx+chipWidth+tagGap
				end
			end
		end
		if wasCut then
			cut=cut+1
		end

		local side=it.side or"unsided"
		pills[side]=pills[side]+1
		line.height=math.max(line.height,item.height)
		line.right=math.max(line.right,x+width)
		return width
	end

	frame.labels.against:Hide()
	frame.labels.with:Hide()
	frame.divider:Hide()

	local flowing=groups
	if shared then
		local line=newLine()
		local x=0
		for _,group in ipairs({against,with})do
			if group==with then
				x=x+sideGap
				frame.divider:ClearAllPoints()
				frame.divider:SetPoint("TOPLEFT",origin,"TOPLEFT",x,-(line.top+(oneLine-ruleHeight)/2))
				frame.divider:SetSize(ruleWidth,ruleHeight)
				frame.divider:Show()
				x=x+ruleWidth+sideGap
			end
			placeLabel(group,x,line)
			x=x+labelWidth(group)+labelGap
			for k=1,#group.items do
				if k>1 then
					x=x+pillGap
				end
				x=x+placePill(group.items[k],x,line,cap)
			end
			lineCounts[group.side]=1
		end
		flowing={}
		for g=1,#groups do
			if groups[g].side==nil then
				flowing[#flowing+1]=groups[g]
			end
		end
	end

	local indent=0
	if not shared then
		for g=1,#groups do
			if groups[g].label~=nil then
				indent=math.max(indent,labelWidth(groups[g])+labelGap)
			end
		end
	end
	local room=math.max(cap-indent,1)
	for g=1,#flowing do
		local group=flowing[g]
		local key=group.side or"unsided"
		local line=newLine()
		lineCounts[key]=lineCounts[key]+1
		if group.label~=nil then
			placeLabel(group,indent-labelGap-labelWidth(group),line)
		end
		local x,first=indent,true
		for k=1,#group.items do
			local item=group.items[k]
			local width=math.min(item.width,room)
			if not first and x+pillGap+width>cap then
				line=newLine()
				lineCounts[key]=lineCounts[key]+1
				x,first=indent,true
			end
			if not first then
				x=x+pillGap
			end
			x=x+placePill(item,x,line,room)
			first=false
		end
	end

	local width,tall=0,0
	for i=1,#lines do
		width=math.max(width,lines[i].right)
		tall=lines[i].top+lines[i].height
	end
	local drawnSides={}
	for g=1,#groups do
		drawnSides[g]=groups[g].side or"unsided"
	end

	origin:SetSize(width,tall)
	origin:Hide()
	hideAll(frame.edges)

	return{
		width=width,
		tall=tall,
		sides=table.concat(drawnSides,","),
		tagCut=cut,
		nameCut=nameCut,
		partCut=partCut,
		noteMarks=marks,
		pillsAgainst=pills.against,
		pillsWith=pills.with,
		pillsUnsided=pills.unsided,
		linesAgainst=lineCounts.against,
		linesWith=lineCounts.with,
		linesUnsided=lineCounts.unsided,
		shared=shared,
		compBand=false,
		rematchLine=false,
		metLines=0,
	}
end

local function rowAt(frame,i)
	local row=frame.rows[i]
	if row then
		return row
	end
	row={}
	row.bar=frame:CreateTexture(nil,"ARTWORK")
	row.name=text(frame,"announceName","bright")
	row.word=text(frame,"announceTag")
	row.word:SetJustifyH("RIGHT")
	row.record=text(frame,"announceRecord","dim")
	row.record:SetJustifyH("RIGHT")
	row.sub=text(frame,"announceTag","chipText")
	row.met=text(frame,"announceTag","dim")
	row.met:SetJustifyH("RIGHT")
	frame.rows[i]=row
	return row
end

local function hideRow(row)
	row.bar:Hide()
	row.name:Hide()
	row.word:Hide()
	row.record:Hide()
	row.sub:Hide()
	row.met:Hide()
end

local function hideBand(frame)
	frame.band.head:Hide()
	frame.band.record:Hide()
	frame.band.classes:Hide()
	frame.band.sub:Hide()
	frame.rematch:Hide()
end

local function headAt(frame,i)
	local head=frame.heads[i]
	if head then
		return head
	end
	head={label=text(frame,"announceLabel"),count=text(frame,"announceRecord","dim")}
	frame.heads[i]=head
	return head
end

local function hideCard(frame)
	for i=1,#frame.rows do
		hideRow(frame.rows[i])
	end
	for i=1,#frame.heads do
		frame.heads[i].label:Hide()
		frame.heads[i].count:Hide()
	end
	frame.headline:Hide()
	hideBand(frame)
end

local function hideStrip(frame)
	for i=1,#frame.pills do
		hidePill(frame.pills[i])
	end
	frame.labels.against:Hide()
	frame.labels.with:Hide()
	frame.divider:Hide()
end

local function showPlate(frame,width,tall)
	frame.plate:ClearAllPoints()
	frame.plate:SetPoint("TOP",frame,"TOP",0,0)
	frame.plate:SetSize(width,tall)
	frame.plate:Show()
	for i=1,#frame.edges do
		frame.edges[i]:Show()
	end
end

local function subLine(it)
	if type(it.note)=="string"and it.note~=""then
		return it.note,"noteWord"
	end
	if#it.tags>0 then
		local words={}
		for j=1,#it.tags do
			words[j]=tostring(it.tags[j])
		end
		return table.concat(words,", "),"chipText"
	end
	return nil
end

local function paintCard(frame,composed,cap)
	cap=math.min(type(cap)=="number"and cap>0 and cap or math.huge,A.metric("announceCardWidth"))
	local pad,barWidth,barGap=A.metric("announceCardPad"),A.metric("announceCardBar"),
		A.metric("announceCardBarGap")
	local lineHeight,partGap=A.metric("announcePillLine"),A.metric("announcePillPartGap")
	local subHeight,subGap=A.metric("announceTagHeight"),A.metric("announceCardSubGap")
	local headHeight,rowGap,runGap=A.metric("announceCardHead"),A.metric("announceCardRowGap"),
		A.metric("announceCardRunGap")
	local origin=frame.plate
	hideStrip(frame)
	frame.headline:Hide()

	local textLeft=pad+barWidth+barGap
	local width=0

	local band=frame.band
	local comp=type(composed.comp)=="table"and composed.comp or nil
	local said,rematchTone=rematchText(composed.rematch)
	local bandWide,rematchWide={},0
	if comp then
		local plain,coloured={},{}
		for _,part in ipairs(A.classSignatureNames(comp.signature)or{})do
			plain[#plain+1]=part.name
			coloured[#coloured+1]=A.channelEscape(A.classColor(part.token))..part.name.."|r"
		end
		local plainClasses=table.concat(plain," + ")
		local recordWords=("%d-%d against you"):format(comp.wins,comp.losses)
		local subWords=comp.scope..", by class"
		band.head:SetText(COMP_HEADING)
		band.record:SetText(recordWords)
		band.classes:SetText(table.concat(coloured," + "))
		band.sub:SetText(subWords)
		bandWide.head=A.textRoom(band.head,COMP_HEADING)
		bandWide.record=A.textRoom(band.record,recordWords)
		bandWide.classes=A.textRoom(band.classes,plainClasses)
		bandWide.sub=A.textRoom(band.sub,subWords)
		width=math.max(width,pad+bandWide.head+partGap+bandWide.record+pad,
			pad+bandWide.classes+pad,pad+bandWide.sub+pad)
	end
	if said then
		frame.rematch:SetText(said)
		frame.rematch:SetTextColor(A.color(rematchTone))
		rematchWide=A.textRoom(frame.rematch,said)
		width=math.max(width,pad+rematchWide+pad)
	end

	local runs,n,drawnSides={},0,{}
	for r=1,#(composed.runs or{})do
		local run=composed.runs[r]
		local head=headAt(frame,r)
		head.label:SetText(run.heading)
		head.label:SetTextColor(A.color(run.tone or"dim"))
		local count=tostring(#run.names)
		head.count:SetText(count)
		width=math.max(width,pad+A.textRoom(head.label,run.heading)+partGap
			+A.textRoom(head.count,count)+pad)
		local items={}
		for k=1,#run.names do
			local it=run.names[k]
			n=n+1
			local row=rowAt(frame,n)
			local shown=pillName(it.name)
			row.name:SetText(shown)
			row.name:SetTextColor(A.classColor(it.classToken))
			row.word:SetText(it.word or"")
			row.word:SetTextColor(A.color(it.mark))
			row.record:SetText(it.record)
			local sub,subColour=subLine(it)
			row.sub:SetText(sub or"")
			if sub then
				row.sub:SetTextColor(A.color(subColour))
			end
			local met,metTone=lastMetText(it.lastMet)
			row.met:SetText(met or"")
			if met then
				row.met:SetTextColor(A.color(metTone))
			end
			local item={
				it=it,
				row=row,
				sub=sub,
				met=met,
				noteLine=subColour=="noteWord",
				nameWidth=A.textRoom(row.name,shown),
				wordWidth=A.textRoom(row.word,it.word),
				recordWidth=A.textRoom(row.record,it.record),
				subWidth=A.textRoom(row.sub,sub),
				metWidth=A.textRoom(row.met,met),
			}
			item.after=(item.wordWidth>0 and(partGap+item.wordWidth)or 0)+partGap+item.recordWidth
			item.metRoom=met and(partGap+item.metWidth)or 0
			width=math.max(width,textLeft+item.nameWidth+item.after+pad,
				(sub or met)and(textLeft+item.subWidth+item.metRoom+pad)or 0)
			items[k]=item
		end
		runs[r]={run=run,head=head,items=items}
		drawnSides[r]=run.side or"unsided"
	end
	for i=n+1,#frame.rows do
		hideRow(frame.rows[i])
	end
	for i=#runs+1,#frame.heads do
		frame.heads[i].label:Hide()
		frame.heads[i].count:Hide()
	end
	width=math.min(width,cap)
	local right=width-pad
	local lineRoom=width-textLeft-pad

	local y,nameCut,tagCut,noteLines,rows,metLines,partCut=pad,0,0,0,0,0,0
	local count={against=0,with=0,unsided=0}
	local bandRoom=width-pad*2

	local function bound(fs,wide,room)
		room=math.max(room,1)
		if wide>room then
			partCut=partCut+1
			fs:SetWidth(room)
		else
			fs:SetWidth(0)
		end
		return math.min(wide,room)
	end

	hideBand(frame)
	if comp then
		band.head:ClearAllPoints()
		band.head:SetPoint("LEFT",origin,"TOPLEFT",pad,-(y+headHeight/2))
		local headDrawn=bound(band.head,bandWide.head,bandRoom)
		band.head:Show()
		band.record:ClearAllPoints()
		band.record:SetPoint("RIGHT",origin,"TOPLEFT",right,-(y+headHeight/2))
		bound(band.record,bandWide.record,bandRoom-headDrawn-partGap)
		band.record:Show()
		y=y+headHeight+rowGap
		band.classes:ClearAllPoints()
		band.classes:SetPoint("LEFT",origin,"TOPLEFT",pad,-(y+lineHeight/2))
		bound(band.classes,bandWide.classes,bandRoom)
		band.classes:Show()
		y=y+lineHeight+subGap
		band.sub:ClearAllPoints()
		band.sub:SetPoint("LEFT",origin,"TOPLEFT",pad,-(y+subHeight/2))
		bound(band.sub,bandWide.sub,bandRoom)
		band.sub:Show()
		y=y+subHeight
	end
	if said then
		y=y+(comp and rowGap or 0)
		frame.rematch:ClearAllPoints()
		frame.rematch:SetPoint("LEFT",origin,"TOPLEFT",pad,-(y+subHeight/2))
		bound(frame.rematch,rematchWide,bandRoom)
		frame.rematch:Show()
		y=y+subHeight
	end
	local opened=comp~=nil or said~=nil
	for r=1,#runs do
		local entry=runs[r]
		if r>1 or opened then
			y=y+runGap
		end
		local middle=-(y+headHeight/2)
		entry.head.label:ClearAllPoints()
		entry.head.label:SetPoint("LEFT",origin,"TOPLEFT",pad,middle)
		entry.head.label:Show()
		entry.head.count:ClearAllPoints()
		entry.head.count:SetPoint("LEFT",entry.head.label,"RIGHT",partGap,0)
		entry.head.count:Show()
		y=y+headHeight
		for k=1,#entry.items do
			local item=entry.items[k]
			local row,it=item.row,item.it
			y=y+rowGap
			local rowHeight=lineHeight+((item.sub or item.met)and(subGap+subHeight)or 0)
			row.bar:ClearAllPoints()
			row.bar:SetPoint("TOPLEFT",origin,"TOPLEFT",pad,-y)
			row.bar:SetSize(barWidth,rowHeight)
			row.bar:SetColorTexture(A.color(it.mark))
			row.bar:Show()

			local nameRoom=math.max(lineRoom-item.after,1)
			local lineMiddle=-(y+lineHeight/2)
			row.name:ClearAllPoints()
			row.name:SetPoint("LEFT",origin,"TOPLEFT",textLeft,lineMiddle)
			if item.nameWidth>nameRoom then
				nameCut=nameCut+1
				row.name:SetWidth(nameRoom)
			else
				row.name:SetWidth(0)
			end
			row.name:Show()
			row.record:ClearAllPoints()
			row.record:SetPoint("RIGHT",origin,"TOPLEFT",right,lineMiddle)
			row.record:Show()
			if item.wordWidth>0 then
				row.word:ClearAllPoints()
				row.word:SetPoint("RIGHT",origin,"TOPLEFT",right-item.recordWidth-partGap,lineMiddle)
				row.word:Show()
			else
				row.word:Hide()
			end
			local subMiddle=-(y+lineHeight+subGap+subHeight/2)
			if item.met then
				row.met:ClearAllPoints()
				row.met:SetPoint("RIGHT",origin,"TOPLEFT",right,subMiddle)
				row.met:Show()
				metLines=metLines+1
			else
				row.met:Hide()
			end
			if item.sub then
				row.sub:ClearAllPoints()
				row.sub:SetPoint("LEFT",origin,"TOPLEFT",textLeft,subMiddle)
				local subRoom=math.max(lineRoom-item.metRoom,1)
				if item.subWidth>subRoom then
					tagCut=tagCut+1
					row.sub:SetWidth(subRoom)
				else
					row.sub:SetWidth(0)
				end
				row.sub:Show()
				if item.noteLine then
					noteLines=noteLines+1
				end
			else
				row.sub:Hide()
			end
			y=y+rowHeight
			rows=rows+1
			local key=it.side or"unsided"
			count[key]=count[key]+1
		end
	end
	local tall=y+pad

	showPlate(frame,width,tall)
	return{
		width=width,
		tall=tall,
		sides=table.concat(drawnSides,","),
		tagCut=tagCut,
		nameCut=nameCut,
		partCut=partCut,
		noteMarks=0,
		noteLines=noteLines,
		rows=rows,
		compBand=comp~=nil,
		rematchLine=said~=nil,
		metLines=metLines,
		pillsAgainst=count.against,
		pillsWith=count.with,
		pillsUnsided=count.unsided,
		linesAgainst=count.against,
		linesWith=count.with,
		linesUnsided=count.unsided,
	}
end

local HEADLINE_NAMES=2

local function paintHeadline(frame,composed,cap)
	cap=type(cap)=="number"and cap>0 and cap or A.metric("announceStripWidth")
	local padX,padY=A.metric("announceHeadlinePadX"),A.metric("announceHeadlinePadY")
	local lineHeight=A.metric("announcePillLine")
	hideStrip(frame)
	hideCard(frame)

	local plain,coloured,drawnSides,listed={},{},{},0
	local reset="|r"
	local count={against=0,with=0,unsided=0}
	local comp=type(composed.comp)=="table"and composed.comp or nil
	local compPart=comp and("comp %d-%d"):format(comp.wins,comp.losses)or nil
	local compAt=nil
	for r=1,#(composed.runs or{})do
		local run=composed.runs[r]
		local shown,said,taken="","",0
		for k=1,math.min(#run.names,HEADLINE_NAMES)do
			local it=run.names[k]
			local name=pillName(it.name)
			local join=k>1 and", "or""
			shown=shown..join..name
			said=said..join..A.channelEscape(A.classColor(it.classToken))..name..reset
			taken=taken+1
		end
		listed=listed+taken
		local more=#run.names-taken
		local tail=more>0 and(" and "..more.." more")or""
		local head=run.heading.." "..#run.names..": "
		plain[#plain+1]=head..shown..tail
		coloured[#coloured+1]=A.colorEscape(run.tone or"dim")..head..reset..said
			..A.colorEscape("dim")..tail..reset
		count[run.side or"unsided"]=#run.names
		drawnSides[r]=run.side or"unsided"
		if comp and run.side=="against"then
			plain[#plain+1]=compPart
			coloured[#coloured+1]=A.colorEscape("loss")..compPart..reset
			compAt=#plain
		end
	end
	if comp and compAt==nil then
		table.insert(plain,1,compPart)
		table.insert(coloured,1,A.colorEscape("loss")..compPart..reset)
		compAt=1
	end
	local plainLine,line="",""
	for r=1,#plain do
		plainLine=plainLine..(r>1 and"  |  "or"")..plain[r]
		line=line..(r>1 and(A.colorEscape("dim").."  ||  "..reset)or"")..coloured[r]
	end
	frame.headline:SetText(line)
	local textWidth=A.textRoom(frame.headline,plainLine)
	local wanted=textWidth+padX*2
	local width=math.min(wanted,cap)
	frame.headline:ClearAllPoints()
	frame.headline:SetPoint("LEFT",frame.plate,"TOPLEFT",padX,-(padY+lineHeight/2))
	frame.headline:SetWidth(math.max(width-padX*2,1))
	frame.headline:Show()
	local tall=padY*2+lineHeight
	showPlate(frame,width,tall)

	return{
		width=width,
		tall=tall,
		sides=table.concat(drawnSides,","),
		tagCut=0,
		nameCut=wanted>cap and 1 or 0,
		noteMarks=0,
		noteLines=0,
		rows=0,
		headlineNames=listed,
		compBand=compAt~=nil,
		rematchLine=false,
		metLines=0,
		pillsAgainst=count.against,
		pillsWith=count.with,
		pillsUnsided=count.unsided,
		linesAgainst=count.against>0 and 1 or 0,
		linesWith=count.with>0 and 1 or 0,
		linesUnsided=count.unsided>0 and 1 or 0,
	}
end

local function formFor(composed,shape,full)
	if shape=="card"and not full and#composed.names>A.announceCrowd()then
		return"headline"
	end
	return shape
end

local function retone(frame)
	for i=1,#SIDES do
		frame.labels[SIDES[i].side]:SetTextColor(A.color(SIDES[i].tone))
	end
	frame.band.head:SetTextColor(A.color("loss"))
	frame.band.record:SetTextColor(A.color("loss"))
	local r,g,b=A.color("panelDeep")
	for i=1,#frame.pills do
		frame.pills[i].mark:SetColorTexture(A.color("noteWord"))
		frame.pills[i].markText:SetTextColor(r,g,b,1)
	end
end

local function paintForm(frame,composed,shape,cap,full)
	retone(frame)
	local form=formFor(composed,shape,full)
	local drew
	if form=="card"then
		drew=paintCard(frame,composed,cap)
	elseif form=="headline"then
		drew=paintHeadline(frame,composed,cap)
	else
		hideCard(frame)
		drew=paint(frame,composed,form,cap)
	end
	drew.form=form
	return drew
end

local function fitTo(width,tall)
	local chosen=A.announceSize()
	local room=screenRoom()
	local below=screenBelow()
	local fitted=math.min(A.announceFit(width,room,chosen),A.announceFit(tall,below,chosen))
	return chosen,room,below,fitted
end

local function fadeAlpha(at,total)
	if at<RISE_SECONDS then
		return at/RISE_SECONDS
	end
	if at<total-FALL_SECONDS then
		return 1
	end
	return(total-at)/FALL_SECONDS
end

local function fade(frame,total)
	fadeStarted=(type(GetTime)=="function")and GetTime()or nil
	dragFrom=nil
	if fadeStarted==nil then
		frame:SetAlpha(1)
		frame:Show()
		return
	end

	frame:SetAlpha(0)
	frame:Show()
	frame:SetScript("OnUpdate",function(self)
		if dragFrom~=nil or fadeStarted==nil then
			return
		end
		local at=GetTime()-fadeStarted
		if at>=total then
			self:SetScript("OnUpdate",nil)
			fadeStarted=nil
			self:SetAlpha(0)
			self:Hide()
			return
		end
		self:SetAlpha(fadeAlpha(at,total))
	end)
end

local function refit(frame,composed,shape,full,serial,last)
	if serial~=drawCount or dragging or not frame:IsShown()then
		return
	end
	local drew=paintForm(frame,composed,shape,nil,full)
	local from=last.width
	local moved=drew.width~=from or drew.tall~=last.tall
	if moved then
		applyScale(frame,select(4,fitTo(drew.width,drew.tall)),drew.tall)
		last.width,last.tall=drew.width,drew.tall
	end
	A.trace("announce-refit",{
		reason=moved and"moved"or"same",
		form=drew.form,
		from=A.unitFigure(from),
		width=A.unitFigure(drew.width),
		tall=A.unitFigure(drew.tall),
		nameCut=drew.nameCut,
		partCut=drew.partCut,
		tagCut=drew.tagCut,
	},"ui")
end

function A.announceShow(composed,held,full)
	if type(composed)~="table"or type(composed.names)~="table"or#composed.names==0 then
		return false
	end
	local frame=build()
	if not frame then
		return false
	end
	local tookPlate=plateUp
	plateUp=false
	if not held then
		release(frame)
	end

	local shape=A.announceShape()
	local drew=paintForm(frame,composed,shape,nil,full)
	frame.word:Hide()
	local chosen,room,below,fitted=fitTo(drew.width,drew.tall)
	applyScale(frame,fitted,drew.tall)
	drawCount=drawCount+1
	if type(C_Timer)=="table"and type(C_Timer.After)=="function"then
		local serial,last=drawCount,{width=drew.width,tall=drew.tall}
		for i=1,#REFIT_AFTER do
			C_Timer.After(REFIT_AFTER[i],function()
				refit(frame,composed,shape,full,serial,last)
			end)
		end
	end
	local opacity=A.announceOpacity()
	applyOpacity(frame,opacity)

	local seconds=A.announceSeconds()
	local unlocked=nil
	if held then
		hold(frame)
	else
		unlocked=not A.announceLocked()
		if unlocked then
			frame:SetMovable(true)
			frame:EnableMouse(true)
		end
		fade(frame,seconds)
	end
	if tookPlate then
		A.trace("view",{source="plate",state="hidden",reason=held and"preview"or"banner"},"ui")
	end
	return true,{
		seconds=seconds,
		scale=chosen,
		fitted=fitted,
		width=drew.width,
		room=room,
		tall=drew.tall,
		below=below,
		shape=shape,
		form=drew.form,
		crowd=A.announceCrowd(),
		rows=drew.rows,
		noteLines=drew.noteLines,
		headlineNames=drew.headlineNames,
		sides=drew.sides,
		shared=drew.shared,
		tagLines=composed.tagLines or 0,
		tagCut=drew.tagCut,
		nameCut=drew.nameCut,
		partCut=drew.partCut,
		noteMarks=drew.noteMarks,
		compBand=drew.compBand,
		rematchLine=drew.rematchLine,
		metLines=drew.metLines,
		pillsAgainst=drew.pillsAgainst,
		pillsWith=drew.pillsWith,
		pillsUnsided=drew.pillsUnsided,
		linesAgainst=drew.linesAgainst,
		linesWith=drew.linesWith,
		linesUnsided=drew.linesUnsided,
		unlocked=unlocked,
		opacity=opacity,
	}
end

local NOTHING_DRAWN={}

function A.announceFrame()
	return banner
end

function A.announceDrawnSize()
	return drawnPercent
end

function A.announceDrawnTall()
	return drawnTall
end

local SAMPLE_SIZE=8

local SAMPLE_FULL=15

local fullSample=false

local SAMPLE_CLASS={"PRIEST","DRUID","WARRIOR","MAGE","ROGUE","HUNTER","PALADIN","WARLOCK"}

local SAMPLE_RECORD={{0,2},{1,1},{1,1},{1,0},{2,0},{3,4},{0,0},{2,1}}
local SAMPLE_WITH={{2,1},{0,3},{2,2},{0,1},{1,1},{1,0},{0,0},{3,0}}

local SAMPLE_TAGS={
	[1]={"healer","duo"},
	[2]={"focus"},
	[3]={"flag carrier","peels","swaps early","calls targets","duo"},
	[4]={"healer","calls targets"},
}
local SAMPLE_NOTED={[1]=true,[2]=true,[5]=true,[6]=true}

local SAMPLE_COMP={signature="MAGE+ROGUE",games=9,wins=2,losses=7,scope="this season"}
local SAMPLE_REMATCH={count=3,minutesAgo=20,when="20 min ago",result="loss"}
local SAMPLE_MET={
	[1]={when="3 d ago",result="loss"},
	[2]={when="yesterday",result="win"},
}

local function sampleHeld(record,with)
	return{
		against={wins=record[1],decided=record[1]+record[2]},
		with={wins=with[1],decided=with[1]+with[2]},
	}
end

function A.announceSample(count)
	local total=type(count)=="number"and count or SAMPLE_SIZE
	if type(A.fixtureNames)~="function"then
		return nil
	end
	local names=A.fixtureNames(total)
	if type(names)~="table"or#names<total then
		return nil
	end

	local rating={-2,-1,0,1,2}
	local found={}
	for i=1,total do
		local record=SAMPLE_RECORD[((i-1)%#SAMPLE_RECORD)+1]
		local with=SAMPLE_WITH[((i-1)%#SAMPLE_WITH)+1]
		found[i]={
			met=record[1]+record[2]+with[1]+with[2]+1,
			name=names[i],
			classToken=SAMPLE_CLASS[((i-1)%#SAMPLE_CLASS)+1],
			faction=(i%2==0)and 1 or 0,
			rating=rating[i],
			mark=A.ratingMark(rating[i]),
			text=SAMPLE_NOTED[i]and"kicks late\nswaps early"or nil,
			tags=SAMPLE_TAGS[i],
			held=sampleHeld(record,with),
			lastMet=SAMPLE_MET[i],
		}
	end

	local composed=compose(found,1)
	if composed==nil then
		return nil
	end
	local reading={comp="-",rematchWeak=0}
	if A.announceCompEnabled()then
		composed.comp=SAMPLE_COMP
		reading.comp=SAMPLE_COMP.signature
		reading.compGames=SAMPLE_COMP.wins+SAMPLE_COMP.losses
		reading.compRecord=("%d-%d"):format(SAMPLE_COMP.wins,SAMPLE_COMP.losses)
		reading.compReason="none"
	else
		reading.compReason="off"
	end
	if A.announceRematchEnabled()then
		composed.rematch=SAMPLE_REMATCH
		reading.rematch=SAMPLE_REMATCH.count
		reading.rematchReason="none"
	else
		reading.rematchReason="off"
	end
	composed.reading=reading
	return composed
end

function A.announcePreviewActive()
	return previewUp
end

function A.announcePreview()
	local composed=A.announceSample(fullSample and SAMPLE_FULL or SAMPLE_SIZE)
	if composed==nil then
		A.trace("announce",{source="preview",reason="no-sample"})
		return false
	end
	local drawn,drawing=A.announceShow(composed,true,not fullSample)
	local did=drawing or NOTHING_DRAWN
	A.trace("announce",{
		source="preview",
		reason=drawn and"previewed"or"no-frame",
		shown=#composed.names,
		seconds=A.unitFigure(did.seconds),
		scale=did.scale,
		fitted=did.fitted,
		width=A.unitFigure(did.width),
		tall=A.unitFigure(did.tall),
		shape=did.shape,
		form=did.form,
		crowd=did.crowd,
		rows=did.rows,
		noteLines=did.noteLines,
		headlineNames=did.headlineNames,
		sides=did.sides,
		shared=did.shared,
		pillsAgainst=did.pillsAgainst,
		pillsWith=did.pillsWith,
		pillsUnsided=did.pillsUnsided,
		linesAgainst=did.linesAgainst,
		linesWith=did.linesWith,
		linesUnsided=did.linesUnsided,
		tagLines=did.tagLines,
		tagCut=did.tagCut,
		nameCut=did.nameCut,
		partCut=did.partCut,
		noteMarks=did.noteMarks,
		readAgainst=composed.readAgainst,
		readWith=composed.readWith,
		readSummed=composed.readSummed,
		comp=composed.reading.comp,
		compGames=composed.reading.compGames,
		compRecord=composed.reading.compRecord,
		compReason=composed.reading.compReason,
		rematch=composed.reading.rematch,
		rematchReason=composed.reading.rematchReason,
		rematchWeak=composed.reading.rematchWeak,
		compBand=did.compBand,
		rematchLine=did.rematchLine,
		metLines=did.metLines,
	})
	return drawn,drawing
end

local CARD_POOL=24
local CARD_RATING={-2,2}

local function cardSample()
	if type(A.fixtureNames)~="function"then
		return nil
	end
	local names=A.fixtureNames(CARD_POOL)
	if type(names)~="table"or#names<#CARD_RATING then
		return nil
	end
	local pool={}
	for i=1,#names do
		pool[i]={name=names[i],at=i,length=#pillName(names[i])}
	end
	table.sort(pool,function(a,b)
		if a.length~=b.length then
			return a.length<b.length
		end
		return a.at<b.at
	end)
	local found={}
	for i=1,#CARD_RATING do
		local record,with=SAMPLE_RECORD[i],SAMPLE_WITH[i]
		found[i]={
			met=record[1]+record[2]+with[1]+with[2]+1,
			name=pool[i].name,
			classToken=SAMPLE_CLASS[((pool[i].at-1)%#SAMPLE_CLASS)+1],
			faction=(i%2==0)and 1 or 0,
			rating=CARD_RATING[i],
			mark=A.ratingMark(CARD_RATING[i]),
			held=sampleHeld(record,with),
		}
	end
	return compose(found,1)
end

function A.announceCardPreview(host)
	if type(host)~="table"or type(host.CreateTexture)~="function"then
		return false
	end
	local strip=host.strip
	if strip==nil then
		strip=CreateFrame("Frame",nil,host)
		if type(strip)~="table"or type(strip.EnableMouse)~="function"then
			return false
		end
		strip:EnableMouse(false)
		strip:SetPoint("CENTER",host,"CENTER",0,0)
		attachStrip(strip)
		host.strip=strip
	end
	local composed=cardSample()
	if composed==nil then
		strip:Hide()
		A.trace("announce",{source="card",reason="no-sample"})
		return false
	end
	local shape=A.announceShape()
	local roomW=host:GetWidth()or 0
	local roomH=host:GetHeight()or 0
	local drew=paintForm(strip,composed,shape,roomW,true)
	strip.word:Hide()
	local chosen=A.announceSize()/100
	local scale=chosen
	if drew.width>0 and roomW>0 then
		scale=math.min(scale,roomW/drew.width)
	end
	if drew.tall>0 and roomH>0 then
		scale=math.min(scale,roomH/drew.tall)
	end
	scale=math.max(scale,0.05)
	local held=scale<chosen
	local lines=drew.linesAgainst+drew.linesWith+drew.linesUnsided
	pcall(strip.SetScale,strip,scale)
	strip:SetSize(math.max(drew.width,1),math.max(drew.tall,1))
	local opacity=A.announceOpacity()
	applyOpacity(strip,opacity)
	strip:Show()
	local percent=A.percentPoints(scale)
	A.trace("announce",{
		source="card",
		shape=shape,
		form=drew.form,
		rows=drew.rows,
		scale=percent,
		opacity=opacity,
		width=A.unitFigure(drew.width),
		tall=A.unitFigure(drew.tall),
		lines=lines,
		held=held,
	})
	return true,{shape=shape,scale=percent,opacity=opacity,width=drew.width,tall=drew.tall,
		lines=lines,held=held,fitted=scale}
end

function A.announcePreviewFull(on)
	fullSample=on==true
	return fullSample
end

function A.announcePreviewFullHeld()
	return fullSample
end

function A.announcePreviewEnd()
	if not previewUp or not banner then
		return false
	end
	pcall(banner.Hide,banner)
	return true
end

function A.announcePreviewToggle()
	if previewUp and banner then
		A.announcePreviewEnd()
		return"ended"
	end
	if A.announcePreview()then
		return"shown"
	end
	return false
end

function A.announcePlateActive()
	return plateUp
end

local function drawPlate()
	local frame=build()
	if not frame then
		return false,"no-frame"
	end
	local composed=A.announceSample(SAMPLE_SIZE)
	if composed==nil then
		return false,"no-sample"
	end
	drawCount=drawCount+1
	local drew=paintForm(frame,composed,A.announceShape(),nil,true)
	hideStrip(frame)
	hideCard(frame)
	showPlate(frame,drew.width,drew.tall)
	local _,_,_,fitted=fitTo(drew.width,drew.tall)
	applyScale(frame,fitted,drew.tall)
	applyOpacity(frame,A.announceOpacity())
	A.style(frame.word,"label","text")
	frame.word:SetText(PLATE_WORD)
	frame.word:Show()

	frame:SetScript("OnUpdate",nil)
	fadeStarted=nil
	dragFrom=nil
	plateUp=true
	frame:SetMovable(true)
	frame:EnableMouse(true)
	frame:SetAlpha(1)
	frame:Show()
	return true
end

function A.announcePlateRefresh(cause)
	local blocked
	if type(A.optionsWindowShown)~="function"or not A.optionsWindowShown()then
		blocked="window"
	elseif not A.announceEnabled()then
		blocked="off"
	elseif A.announceLocked()then
		blocked="locked"
	elseif previewUp then
		blocked="preview"
	elseif banner and not plateUp then
		local ok,shown=pcall(banner.IsShown,banner)
		if ok and shown then
			blocked="banner"
		end
	end

	if blocked then
		if plateUp and banner then
			pcall(banner.Hide,banner)
			A.trace("view",{source="plate",state="hidden",reason=cause,kind=blocked},"ui")
			return false
		end
		A.trace("view",{source="plate",state="absent",reason=cause,kind=blocked},"ui")
		return false
	end

	if plateUp then
		A.trace("view",{source="plate",state="kept",reason=cause},"ui")
		return true
	end
	local drawn,why=drawPlate()
	A.trace("view",{source="plate",state=drawn and"shown"or"failed",reason=cause,kind=why},
		"ui")
	return drawn
end

function A.resetAnnouncePosition()
	local stored=A.setAnnouncePosition(nil)
	if banner then
		pcall(banner.Hide,banner)
		placeAt(banner,drawnScale)
	end
	reconsider("reset")
	return stored
end

local function readRows()
	if type(GetNumBattlefieldScores)~="function"
		or type(C_PvP)~="table"or type(C_PvP.GetScoreInfo)~="function"
	then
		return{}
	end

	local ok,count=pcall(GetNumBattlefieldScores)
	if not ok or not A.canRead(count)or type(count)~="number"or count<1 then
		return{}
	end

	local rows={}
	for i=1,count do
		local gotRow,row=pcall(C_PvP.GetScoreInfo,i)
		if gotRow and type(row)=="table"then
			local gotName,name=pcall(A.index,row,"name")
			if gotName and A.canRead(name)then
				local out={name=name}
				local gotClass,class=pcall(A.index,row,"classToken")
				if gotClass and A.canRead(class)then
					out.classToken=class
				end
				local gotFaction,faction=pcall(A.index,row,"faction")
				if gotFaction and A.canRead(faction)then
					out.faction=faction
				end
				rows[#rows+1]=out
			end
		end
	end
	return rows
end

local function ownNames()
	if type(UnitName)~="function"then
		return nil,nil
	end
	local ok,own,realm=pcall(UnitName,"player")
	if not(ok and type(own)=="string"and A.canRead(own)and own~="")then
		return nil,nil
	end
	if type(realm)=="string"and A.canRead(realm)and realm~=""then
		return own,own.."-"..realm
	end
	return own,nil
end

local function settled(fill)
	if#fill<SETTLE_READS then
		return false
	end
	for i=#fill-SETTLE_READS+2,#fill do
		if fill[i]~=fill[i-1]then
			return false
		end
	end
	return true
end

local function attempt(ladder,n)
	local record=ladder.record
	local db=A.db()
	if db==nil or db.active~=record then
		return
	end

	local rows=readRows()
	if A.requestScores then
		A.requestScores()
	end
	local canWait=C_Timer and C_Timer.After

	if#rows==0 then
		if n>=MAX_ATTEMPTS or not canWait then
			A.trace("announce",{reason="no-rows",attempt=n})
			return
		end
		C_Timer.After(RETRY_EVERY,function()contained(attempt,ladder,n+1)end)
		return
	end

	local fill=ladder.fill
	fill[#fill+1]=#rows
	local state=A.stateName(A.matchState())
	if state=="StartUp"and not settled(fill)and n<MAX_ATTEMPTS and canWait then
		C_Timer.After(RETRY_EVERY,function()contained(attempt,ladder,n+1)end)
		return
	end

	local fillText=table.concat(fill,",")
	local own,qualified=ownNames()

	local nameIndex,yielded=nil,nil
	if ladder.banner or ladder.sound or(type(A.alertsEnabled)=="function"and A.alertsEnabled())then
		local built,made,gave=pcall(A.playerNameIndex)
		nameIndex=built and type(made)=="table"and made or nil
		yielded=nameIndex and type(gave)=="number"and gave or nil
	end

	if A.alertGatesGroup then
		A.alertGatesGroup(rows,own,qualified,nameIndex)
	end
	if not(ladder.banner or ladder.sound)then
		return
	end

	local composed=A.announceKnown(rows,own,qualified,nameIndex,record)
	if composed==nil then
		A.trace("announce",{reason="nobody",n=#rows,attempt=n,state=state,
			fill=fillText,yielded=yielded})
		return
	end

	A.cueGatesRoster(composed.names,record.openedEpoch or record)
	if not ladder.banner then
		return
	end

	local drawn,drawing=A.announceShow(composed)
	if drawn then
		lastShown=composed
	end
	local did=drawing or NOTHING_DRAWN
	A.trace("announce",{
		reason=drawn and"announced"or"no-frame",
		n=#rows,
		found=composed.count,
		noted=composed.noted,
		shown=#composed.names,
		yielded=yielded,
		attempt=n,
		state=state,
		fill=fillText,
		seconds=A.unitFigure(did.seconds),
		scale=did.scale,
		fitted=did.fitted,
		width=A.unitFigure(did.width),
		room=A.unitFigure(did.room),
		tall=A.unitFigure(did.tall),
		below=A.unitFigure(did.below),
		shape=did.shape,
		form=did.form,
		crowd=did.crowd,
		rows=did.rows,
		noteLines=did.noteLines,
		headlineNames=did.headlineNames,
		sides=did.sides,
		shared=did.shared,
		pillsAgainst=did.pillsAgainst,
		pillsWith=did.pillsWith,
		pillsUnsided=did.pillsUnsided,
		linesAgainst=did.linesAgainst,
		linesWith=did.linesWith,
		linesUnsided=did.linesUnsided,
		tagLines=did.tagLines,
		tagCut=did.tagCut,
		nameCut=did.nameCut,
		partCut=did.partCut,
		noteMarks=did.noteMarks,
		readAgainst=composed.readAgainst,
		readWith=composed.readWith,
		readSummed=composed.readSummed,
		unlocked=did.unlocked,
		opacity=did.opacity,
		comp=composed.reading.comp,
		compGames=composed.reading.compGames,
		compRecord=composed.reading.compRecord,
		compReason=composed.reading.compReason,
		rematch=composed.reading.rematch,
		rematchReason=composed.reading.rematchReason,
		rematchWeak=composed.reading.rematchWeak,
		compBand=did.compBand,
		rematchLine=did.rematchLine,
		metLines=did.metLines,
	})
end

local START_STATES={StartUp=true,Engaged=true}

function A.announceRoster(record,state)
	if type(record)~="table"or not START_STATES[state]then
		return false
	end
	if firedFor==record then
		return false
	end
	local bannerOn=A.announceEnabled()
	local soundOn=A.soundEnabled("badArrival")
	if not bannerOn then
		A.trace("announce",{reason="switch"})
		if not(A.alertsEnabled()or soundOn)then
			firedFor=record
			return false
		end
	end

	local noted=A.notedCount()
	local db=A.db()
	local indexed=db and type(db.players)=="table"and next(db.players)~=nil
	if(type(noted)~="number"or noted<1)and not indexed then
		A.trace("announce",{reason="nothing-known",noted=0})
		firedFor=record
		return false
	end

	firedFor=record

	local ladder={record=record,banner=bannerOn,sound=soundOn,fill={}}
	if not(C_Timer and C_Timer.After)then
		contained(attempt,ladder,MAX_ATTEMPTS)
		return true
	end
	C_Timer.After(FIRST_READ,function()contained(attempt,ladder,1)end)
	return true
end

local groupSeen={}

local function groupDecision(guids,selfGuid)
	local composed,qualified=A.announceGroup(guids,selfGuid)
	local now,arrivals={},{}
	for i=1,#qualified do
		now[qualified[i]]=true
		if not groupSeen[qualified[i]]then
			arrivals[#arrivals+1]=qualified[i]
		end
	end
	local arrived=#arrivals>0
	groupSeen=now
	if arrived then
		A.cueGroupArrival(arrivals)
	end

	if composed==nil then
		A.trace("announce",{source="group",reason="nobody",n=#guids})
		return false
	end
	if not arrived then
		A.trace("announce",{source="group",reason="seen",n=#guids,found=composed.count})
		return false
	end
	if not A.announceEnabled()then
		A.trace("announce",{source="group",reason="switch",n=#guids,found=composed.count})
		return false
	end

	local drawn,drawing=A.announceShow(composed)
	if drawn then
		lastShown=composed
	end
	local did=drawing or NOTHING_DRAWN
	A.trace("announce",{
		source="group",
		reason=drawn and"announced"or"no-frame",
		n=#guids,
		found=composed.count,
		noted=composed.noted,
		shown=#composed.names,
		seconds=A.unitFigure(did.seconds),
		scale=did.scale,
		fitted=did.fitted,
		width=A.unitFigure(did.width),
		room=A.unitFigure(did.room),
		tall=A.unitFigure(did.tall),
		below=A.unitFigure(did.below),
		shape=did.shape,
		form=did.form,
		crowd=did.crowd,
		rows=did.rows,
		noteLines=did.noteLines,
		headlineNames=did.headlineNames,
		sides=did.sides,
		shared=did.shared,
		pillsAgainst=did.pillsAgainst,
		pillsWith=did.pillsWith,
		pillsUnsided=did.pillsUnsided,
		linesAgainst=did.linesAgainst,
		linesWith=did.linesWith,
		linesUnsided=did.linesUnsided,
		tagLines=did.tagLines,
		tagCut=did.tagCut,
		nameCut=did.nameCut,
		partCut=did.partCut,
		noteMarks=did.noteMarks,
		readAgainst=composed.readAgainst,
		readWith=composed.readWith,
		readSummed=composed.readSummed,
		unlocked=did.unlocked,
		opacity=did.opacity,
	})
	return drawn
end

function A.announceGroupRoster(guids,selfGuid)
	if type(guids)~="table"or not(A.announceEnabled()or A.soundEnabled("badArrival"))then
		return false
	end
	local drawn=false
	contained(function()
		drawn=groupDecision(guids,selfGuid)
	end)
	return drawn
end

function A.recordRows(record)
	local rows={}
	local participants=type(record)=="table"and record.participants or nil
	if type(participants)~="table"then
		return rows,nil
	end
	local keys={}
	for guid,p in pairs(participants)do
		if type(p)=="table"and type(p.name)=="string"and p.name~=""then
			local row={name=p.name,classToken=p.classToken,faction=p.faction}
			keys[row]=tostring(guid)
			rows[#rows+1]=row
		end
	end
	table.sort(rows,function(a,b)
		if a.name~=b.name then
			return a.name<b.name
		end
		return keys[a]<keys[b]
	end)
	local own=record.character and participants[record.character]
	return rows,type(own)=="table"and own.name or nil
end

function A.announceFromRecord(record)
	local rows,own=A.recordRows(record)
	local composed=A.announceKnown(rows,own,nil,nil,record)
	local switch=A.announceEnabled()and"on"or"off"
	if composed==nil then
		A.trace("announce",{source="sample",reason="nobody",id=record.id,n=#rows,switch=switch})
		return false
	end
	local drawn,drawing=A.announceShow(composed)
	local did=drawing or NOTHING_DRAWN
	A.trace("announce",{
		source="sample",
		reason=drawn and"announced"or"no-frame",
		id=record.id,
		n=#rows,
		found=composed.count,
		noted=composed.noted,
		shown=#composed.names,
		seconds=A.unitFigure(did.seconds),
		width=A.unitFigure(did.width),
		tall=A.unitFigure(did.tall),
		shape=did.shape,
		form=did.form,
		crowd=did.crowd,
		rows=did.rows,
		noteLines=did.noteLines,
		headlineNames=did.headlineNames,
		sides=did.sides,
		shared=did.shared,
		pillsAgainst=did.pillsAgainst,
		pillsWith=did.pillsWith,
		pillsUnsided=did.pillsUnsided,
		linesAgainst=did.linesAgainst,
		linesWith=did.linesWith,
		linesUnsided=did.linesUnsided,
		tagLines=did.tagLines,
		tagCut=did.tagCut,
		nameCut=did.nameCut,
		partCut=did.partCut,
		noteMarks=did.noteMarks,
		switch=switch,
		comp=composed.reading.comp,
		compGames=composed.reading.compGames,
		compRecord=composed.reading.compRecord,
		compReason=composed.reading.compReason,
		rematch=composed.reading.rematch,
		rematchReason=composed.reading.rematchReason,
		rematchWeak=composed.reading.rematchWeak,
		compBand=did.compBand,
		rematchLine=did.rematchLine,
		metLines=did.metLines,
	})
	return drawn
end

function A.announceLast()
	if lastShown==nil then
		A.trace("announce",{source="last",reason="none"})
		return false
	end
	local drawn,drawing=A.announceShow(lastShown,false,true)
	local did=drawing or NOTHING_DRAWN
	A.trace("announce",{
		source="last",
		reason=drawn and"announced"or"no-frame",
		shown=#lastShown.names,
		seconds=A.unitFigure(did.seconds),
		width=A.unitFigure(did.width),
		tall=A.unitFigure(did.tall),
		shape=did.shape,
		form=did.form,
		rows=did.rows,
		noteLines=did.noteLines,
	})
	return drawn
end

function A.announceLastHeld()
	return lastShown~=nil
end

function A.announceGroupLeft()
	groupSeen={}
end

local TOAST_NAME="WowPvpHistoryToast"

local TOAST_TIME={min=2,max=30,step=1,default=5}

local toastGiven

local TOAST_POINT,TOAST_X,TOAST_Y="TOP",0,-TOP_DROP

local TOAST_SIZE={pad=10,stripe=4,gap=3,cellGap=16,minText=160}

local TOAST_CLICK="click to open"
local TOAST_SEPARATOR="  "

local TOAST_STREAK_FLOOR=2

local TOAST_SAMPLE={
	verdict="WON 4 OF 6",tone="win",format="shuffle",ratingIn=1850,change=14,delta="+14",
	deltaTone="win",
	map="Nagrand Arena",duration=252,best="new best: damage 4.2M",streak="W3",
}

local toast
local toastCard
local toastPreviewUp=false

local toastFadeStarted
local toastDragFrom

local toastPending
local toastWaited

function A.toastEnabled()
	local db=A.db()
	if not db then
		return false
	end
	return type(db.ui)~="table"or db.ui.toast~=false
end

function A.setToast(enabled)
	local db=A.db()
	if not db then
		return false
	end
	db.ui=db.ui or{}
	if enabled==false then
		db.ui.toast=false
	else
		db.ui.toast=nil
	end
	if A.notifyToastSetting then
		A.notifyToastSetting()
	end
	if enabled==false and toastPreviewUp and toast then
		pcall(toast.Hide,toast)
		A.trace("toast",{reason="preview-ended",source="switch"},"ui")
	end
	return true
end

function A.toastSeconds()
	return storedFigure("toastSeconds",TOAST_TIME.min,TOAST_TIME.max,TOAST_TIME.step,TOAST_TIME.default)
end

function A.toastSecondsRange()
	return TOAST_TIME.min,TOAST_TIME.max,TOAST_TIME.step,TOAST_TIME.default
end

function A.setToastSeconds(value)
	return storeFigure("toastSeconds",value,TOAST_TIME.min,TOAST_TIME.max,TOAST_TIME.step,
		TOAST_TIME.default,A.notifyToastSecondsSetting)
end

function A.toastLocked()
	local db=A.db()
	if not db or type(db.ui)~="table"then
		return true
	end
	return db.ui.toastUnlocked~=true
end

function A.setToastLocked(on)
	local db=A.db()
	if not db then
		return false
	end
	db.ui=db.ui or{}
	db.ui.toastUnlocked=(not on)and true or nil
	if A.notifyToastLockSetting then
		A.notifyToastLockSetting()
	end
	if toast and not toastPreviewUp then
		pcall(toast.SetMovable,toast,not on)
	end
	return true
end

function A.toastPosition()
	return A.storedPosition("toastPosition")
end

function A.setToastPosition(geometry)
	return A.storePosition("toastPosition",geometry,function()
		return TOAST_POINT,TOAST_X,TOAST_Y
	end)
end

local function placeToast(frame)
	local stored=A.toastPosition()
	local point=stored and stored.point or TOAST_POINT
	pcall(frame.ClearAllPoints,frame)
	pcall(frame.SetPoint,frame,point,UIParent,point,stored and stored.x or TOAST_X,
		stored and stored.y or TOAST_Y)
end

local function cardFor(record,bestsSet)
	if type(record)~="table"or record.format=="duel"or record.format=="world"then
		return nil,"no-result"
	end
	local verdict=A.matchVerdict(record)
	if verdict==nil then
		return nil,"no-result"
	end
	local card={
		id=record.id,verdict=verdict.words,tone=verdict.tone,format=record.format,
		map=type(record.map)=="table"and record.map.name or nil,duration=record.duration,
		best=A.newBestLine(bestsSet),
	}
	local delta,deltaTone=A.ratingDelta(record)
	if delta~=nil then
		local own=record.participants[record.character]
		if type(own.rating)=="number"then
			card.ratingIn,card.change,card.delta,card.deltaTone=own.rating,own.ratingChange,delta,deltaTone
		end
	end
	local streak=A.currentStreak(record.format,record.character)
	if type(streak)=="table"and streak.count>=TOAST_STREAK_FLOOR then
		card.streak=streak.word
	end
	return card
end

local function ratingLine(card)
	if type(card.ratingIn)~="number"or type(card.change)~="number"then
		return nil
	end
	local out=card.ratingIn+card.change
	local delta,tone=card.delta or tostring(card.change),card.deltaTone or"dim"
	return A.tierRatingText(card.format,card.ratingIn,"bright").." "..A.colorEscape(tone)..delta
		.."|r "..A.tierRatingText(card.format,out,"bright"),("%d %s %d"):format(card.ratingIn,delta,out)
end

local function detailLine(card)
	local parts={A.formatLabel(card.format)}
	if type(card.map)=="string"and card.map~=""then
		parts[#parts+1]=card.map
	end
	local length=A.lengthText(card.duration)
	if length~=nil then
		parts[#parts+1]=length
	end
	return table.concat(parts,TOAST_SEPARATOR)
end

local function toastText(frame,role,colorName)
	local fs=A.lineText(frame,role,nil,colorName)
	fs:Hide()
	return fs
end

local function releaseToast(frame)
	toastPreviewUp=false
	toastDragFrom=nil
	escapeList(false,TOAST_NAME)
	pcall(frame.SetMovable,frame,not A.toastLocked())
	if type(A.refreshOptionsWindow)=="function"then
		pcall(A.refreshOptionsWindow)
	end
end

local function buildToast()
	if toast then
		return toast
	end
	if type(CreateFrame)~="function"then
		return nil
	end
	local frame=CreateFrame("Button",TOAST_NAME,UIParent)
	if type(frame)~="table"or type(frame.EnableMouse)~="function"then
		return nil
	end
	frame:SetFrameStrata("HIGH")
	frame:SetClampedToScreen(true)
	frame:EnableMouse(true)
	frame:RegisterForClicks("LeftButtonUp")
	frame:RegisterForDrag("LeftButton")
	frame:SetMovable(not A.toastLocked())
	placeToast(frame)

	frame.plate=frame:CreateTexture(nil,"BACKGROUND")
	frame.plate:SetAllPoints(frame)
	frame.plate:SetColorTexture(GROUND[1],GROUND[2],GROUND[3],OPACITY_DEFAULT/100)
	frame.edges=fourEdges(frame,"BORDER")
	frame.stripe=frame:CreateTexture(nil,"ARTWORK")
	frame.stripe:SetPoint("TOPLEFT",frame,"TOPLEFT",0,0)
	frame.stripe:SetPoint("BOTTOMLEFT",frame,"BOTTOMLEFT",0,0)
	frame.stripe:SetWidth(TOAST_SIZE.stripe)

	frame.verdict=toastText(frame,"headingLarge","win")
	frame.rating=toastText(frame,"cardValue","bright")
	frame.detail=toastText(frame,"bodyText","dim")
	frame.best=toastText(frame,"bodyText","text")
	frame.streak=toastText(frame,"label","text")
	frame.click=toastText(frame,"cardLabel","dim")
	frame.click:SetJustifyH("RIGHT")

	frame:SetScript("OnClick",function(self)
		local id=toastCard and toastCard.id
		A.trace("toast",{reason="clicked",id=id},"ui")
		if type(id)=="number"and type(A.raiseMatchWindow)=="function"then
			A.raiseMatchWindow("match",id,"toast")
			self:Hide()
		end
	end)
	frame:SetScript("OnDragStart",function(self)
		if not pcall(self.StartMoving,self)then
			return
		end
		if toastFadeStarted~=nil and type(GetTime)=="function"then
			toastDragFrom=GetTime()
			self:SetAlpha(1)
		end
	end)
	frame:SetScript("OnDragStop",function(self)
		A.stopDrag(self)
		if toastDragFrom~=nil and toastFadeStarted~=nil then
			local now=GetTime()
			toastFadeStarted=now-math.max(toastDragFrom-toastFadeStarted,RISE_SECONDS)
		end
		toastDragFrom=nil
		local read=A.frameGeometry(self)
		if read and read.point then
			A.setToastPosition(read)
		end
		local at=read or NOTHING_READ
		A.trace("toast",{reason="moved",point=at.point,x=A.unitFigure(at.x),y=A.unitFigure(at.y)},
			"ui")
	end)
	frame:SetScript("OnHide",function(self)
		self:SetScript("OnUpdate",nil)
		toastFadeStarted=nil
		releaseToast(self)
	end)
	frame:Hide()
	toast=frame
	return toast
end

local function paintToast(frame,card)
	local r,g,b=A.color(card.tone or"dim")
	frame.stripe:SetColorTexture(r,g,b,1)
	local rated,ratedPlain=ratingLine(card)
	local detail=detailLine(card)
	local streak=card.streak

	local column=TOAST_SIZE.pad+TOAST_SIZE.stripe+TOAST_SIZE.pad
	local lines={
		{fs=frame.verdict,text=card.verdict,plain=card.verdict,role="headingLarge",
			color=card.tone or"dim"},
		{fs=frame.rating,text=rated,plain=ratedPlain,role="cardValue",color="bright"},
		{fs=frame.detail,text=detail,plain=detail,role="bodyText",color="dim"},
		{fs=frame.best,text=card.best,plain=card.best,role="bodyText",color="text"},
		{fs=frame.streak,text=streak,plain=streak,role="label",color="text"},
	}
	local y,wide=TOAST_SIZE.pad,TOAST_SIZE.minText
	for i=1,#lines do
		local line=lines[i]
		if line.text==nil then
			line.fs:Hide()
		else
			if y>TOAST_SIZE.pad then
				y=y+TOAST_SIZE.gap
			end
			A.style(line.fs,line.role,line.color)
			line.fs:ClearAllPoints()
			line.fs:SetPoint("TOPLEFT",frame,"TOPLEFT",column,-y)
			line.fs:SetText(line.text)
			line.fs:Show()
			wide=math.max(wide,A.textRoom(line.fs,line.plain))
			y=y+A.fontSize(line.role)
		end
	end
	local tall=y+TOAST_SIZE.pad
	A.style(frame.click,"cardLabel","dim")
	frame.click:SetText(TOAST_CLICK)
	local cell=A.textRoom(frame.click,TOAST_CLICK)
	local width=column+wide+TOAST_SIZE.cellGap+cell+TOAST_SIZE.pad
	frame.click:ClearAllPoints()
	frame.click:SetPoint("RIGHT",frame,"RIGHT",-TOAST_SIZE.pad,0)
	frame.click:Show()
	frame:SetSize(width,tall)
	box(frame.edges,frame,0,0,width,tall)
	colourEdges(frame.edges,GROUND_EDGE[1],GROUND_EDGE[2],GROUND_EDGE[3],GROUND_EDGE[4])
	return width,tall
end

local function fadeToast(frame,total)
	toastGiven=total
	toastFadeStarted=(type(GetTime)=="function")and GetTime()or nil
	toastDragFrom=nil
	if toastFadeStarted==nil then
		frame:SetAlpha(1)
		frame:Show()
		return
	end
	frame:SetAlpha(0)
	frame:Show()
	frame:SetScript("OnUpdate",function(self)
		if toastDragFrom~=nil or toastFadeStarted==nil then
			return
		end
		local at=GetTime()-toastFadeStarted
		if at>=total then
			self:SetAlpha(0)
			self:Hide()
			return
		end
		self:SetAlpha(fadeAlpha(at,total))
	end)
end

local function riseToast(card,held)
	local frame=buildToast()
	if not frame then
		return false
	end
	toastCard=card
	paintToast(frame,card)
	placeToast(frame)
	if held then
		frame:SetScript("OnUpdate",nil)
		toastFadeStarted=nil
		toastPreviewUp=true
		escapeList(true,TOAST_NAME)
		frame:SetMovable(true)
		frame:SetAlpha(1)
		frame:Show()
		if type(A.refreshOptionsWindow)=="function"then
			pcall(A.refreshOptionsWindow)
		end
	else
		local endedPreview=toastPreviewUp
		toastPreviewUp=false
		escapeList(false,TOAST_NAME)
		frame:SetMovable(not A.toastLocked())
		fadeToast(frame,A.toastSeconds())
		if endedPreview and type(A.refreshOptionsWindow)=="function"then
			pcall(A.refreshOptionsWindow)
		end
	end
	return true
end

local function traceToast(reason,card,source)
	local drawn=card or NOTHING_DRAWN
	local seconds
	if reason=="none"then
		seconds=toastGiven
	end
	local best
	if card then
		best=card.best~=nil
	end
	A.trace("toast",{
		reason=reason,
		source=source,
		id=drawn.id,
		verdict=drawn.verdict,
		change=drawn.change,
		best=best,
		streak=drawn.streak,
		seconds=seconds,
	},"ui")
end

local TOAST_HELD={instance="in-instance",combat="in-combat",loading="loading"}

local function attemptToast(source)
	local card=toastPending
	if card==nil then
		return nil
	end
	if not A.toastEnabled()then
		toastPending,toastWaited=nil,nil
		traceToast("off",card,source)
		return"off"
	end
	local held=A.afterMatchHeld(source,toastWaited)
	if held then
		if toastWaited~=held then
			toastWaited=held
			traceToast(TOAST_HELD[held],card,source)
		end
		return"waiting"
	end
	toastPending,toastWaited=nil,nil
	if not riseToast(card,false)then
		traceToast("no-frame",card,source)
		return"no-frame"
	end
	traceToast("none",card,source)
	return"none"
end

function A.toastAfterMatch(record,bestsSet)
	if not A.toastEnabled()then
		traceToast("off",nil,"store")
		return"off"
	end
	local card,why=cardFor(record,bestsSet)
	if card==nil then
		traceToast(why,nil,"store")
		return why
	end
	toastPending,toastWaited=card,nil
	return attemptToast("store")
end

function A.toastPendingCard()
	return toastPending
end

function A.dropToast()
	local had=toastPending~=nil
	toastPending,toastWaited=nil,nil
	return had
end

function A.toastFrame()
	return toast,toastCard
end

function A.toastPreviewActive()
	return toastPreviewUp
end

function A.toastPreview()
	if toastPreviewUp and toast then
		pcall(toast.Hide,toast)
		traceToast("preview-ended",nil,"preview")
		return"ended"
	end
	if not riseToast(TOAST_SAMPLE,true)then
		traceToast("no-frame",nil,"preview")
		return false
	end
	traceToast("preview",TOAST_SAMPLE,"preview")
	return"shown"
end

function A.resetToastPosition()
	local stored=A.setToastPosition(nil)
	if toast then
		placeToast(toast)
	end
	return stored
end

local function reportToastSeconds(figure)
	local min,max,step=A.toastSecondsRange()
	local was=A.toastSeconds()
	if figure==nil then
		A.say(("the result card stays up for %d seconds"):format(was))
		return
	end
	local want=A.decimalArgument(figure)
	if want==nil or not A.setToastSeconds(want)then
		A.say(("%s is not one this takes. /pvph toast seconds takes %d to %d in steps of %d")
			:format(tostring(figure),min,max,step))
		return
	end
	A.say(("the result card time is %d seconds, from %d seconds"):format(A.toastSeconds(),was))
end

function A.reportToast(word,figure)
	if word=="seconds"then
		reportToastSeconds(figure)
		return
	end
	if word=="on"or word=="off"then
		if not A.setToast(word=="on")then
			A.say("no database, so the setting could not be stored")
			return
		end
		A.say("the result card after a match "..word)
		return
	end
	if word=="preview"then
		local did=A.toastPreview()
		if did=="ended"then
			A.say("the result card sample is put away")
		elseif did=="shown"then
			A.say("the result card sample is drawn where the card rises. Drag it, and /pvph toast "
				.."preview again puts it away")
		else
			A.say("the result card could not be drawn on this client")
		end
		return
	end
	if word=="lock"or word=="unlock"then
		if not A.setToastLocked(word=="lock")then
			A.say("no database, so the setting could not be stored")
			return
		end
		A.say(word=="lock"and"the result card is fixed where it is"
			or"the result card can be dragged while it is up")
		return
	end
	if word=="reset"then
		if not A.resetToastPosition()then
			A.say("no database, so the position could not be cleared")
			return
		end
		A.say("the result card is back a sixth of the screen down")
		return
	end
	if word then
		A.say(("unknown toast command %q. on, off, seconds, preview, lock, unlock or reset"):format(word))
		return
	end
	local held=A.toastPosition()
	A.say(("the result card after a match is %s and %s, at %s%s"):format(
		A.toastEnabled()and"on"or"off",A.toastLocked()and"locked"or"unlocked",
		held and("%s %d, %d"):format(held.point,held.x,held.y)or"its default place",
		toastPending and(", match #%s waiting"):format(A.matchIdText(toastPending.id))or""))
end

local function onToastLift(event)
	if toastPending==nil then
		return
	end
	local ok,err=pcall(attemptToast,event)
	if not ok then
		A.noteError(err,"toast")
	end
end

A.on("PLAYER_ENTERING_WORLD",onToastLift)
A.on("PLAYER_REGEN_ENABLED",onToastLift)
