-- WowPvpHistory 0.75.68
-- Author:  Xenu-Sentinels
-- Project: wow-pvp-history
--          https://github.com/xenulive/wow-pvp-history
-- License: MIT, see LICENSE
local _,A=...

local SIGHT_REPEAT_MINUTES=10

local SIGHT_QUIET_SECONDS=20

local SIGHT_MEMORY=64

local MARK_SIZE=14

local marks={}
local rivalMarks={}

local plateOf={}

local namedAt={}
local namedOrder={}

local lastLine

local reported=false

function A.sightEnabled()
	local db=A.db()
	if not db then
		return false
	end
	return not(type(db.ui)=="table"and db.ui.sight==false)
end

local function hideEach(held)
	for _,mark in pairs(held)do
		pcall(mark.Hide,mark)
	end
end

local function hideAll()
	hideEach(marks)
	hideEach(rivalMarks)
end

function A.hideRivalMarks()
	hideEach(rivalMarks)
end

function A.setSight(enabled)
	local db=A.db()
	if not db then
		return false
	end
	db.ui=db.ui or{}
	if enabled==false then
		db.ui.sight=false
		hideAll()
	else
		db.ui.sight=nil
	end

	if A.notifySightSetting then
		A.notifySightSetting()
	end
	return true
end

local function plateFrame(token)
	local plates=C_NamePlate
	return A.guardedCall(plates and plates.GetNamePlateForUnit,token)
end

local function clock()
	local now=A.guardedCall(GetTime)
	if type(now)=="number"then
		return now
	end
	return A.guardedCall(time)or 0
end

local function markedCount()
	local n=0
	for _,held in ipairs({marks,rivalMarks})do
		for _,mark in pairs(held)do
			local ok,shown=pcall(mark.IsShown,mark)
			if ok and shown then
				n=n+1
			end
		end
	end
	return n
end

local function traceSight(state,reason,source,noted,rival)
	A.trace("sight",{state=state,reason=reason,source=source,n=markedCount(),
		carriesNote=noted,rival=rival})
end

local function contained(fn,...)
	local ok,err=pcall(fn,...)
	if ok then
		return
	end
	A.noteError(err,"sight")
	if not reported then
		reported=true
		A.say("marking people you have written about stopped: "..tostring(err)
			..". /pvph sight off silences it")
	end
end

local function writtenAbout(guid)
	local note=A.noteFor(guid)
	if note and A.writtenAbout(note)then
		return note
	end
	return nil
end

local function carries(note)
	return note~=nil and note.text~=nil
end

local function examine(token,source)
	if not A.sightEnabled()then
		traceSight("refused","switch",source)
		return nil
	end
	if A.inPvpInstance()then
		traceSight("refused","instance",source)
		return nil
	end
	if A.pvpRestricted()then
		traceSight("refused","restricted",source)
		return nil
	end

	local isPlayer=A.guardedCall(UnitIsPlayer,token)
	if not(A.canRead(isPlayer)and isPlayer==true)then
		traceSight("refused","not-player",source)
		return nil
	end

	local guid=A.guardedCall(UnitGUID,token)
	if not(type(guid)=="string"and A.canRead(guid))then
		traceSight("refused","secret",source)
		return nil
	end

	local own=A.guardedCall(UnitGUID,"player")
	if type(own)=="string"and A.canRead(own)and own==guid then
		traceSight("refused","self",source,nil,false)
		return nil
	end

	local note=writtenAbout(guid)
	local rival=A.isRival(nil,guid)
	local marked=rival and A.rivalsEnabled()
	if not(note or marked)then
		traceSight("refused",rival and"rivals-off"or"unwritten",source,nil,rival)
		return nil
	end

	local group=A.groupGuids()
	for i=1,#group do
		if group[i]==guid then
			traceSight("refused","group",source,carries(note),rival)
			return nil
		end
	end

	return guid,note,marked,rival
end

local function remember(guid,now)
	for i=#namedOrder,1,-1 do
		if namedOrder[i]==guid then
			table.remove(namedOrder,i)
		end
	end
	namedOrder[#namedOrder+1]=guid
	namedAt[guid]=now
	while#namedOrder>SIGHT_MEMORY do
		local oldest=table.remove(namedOrder,1)
		namedAt[oldest]=nil
	end
end

local function speak(guid,note,marked,rival,source)
	local now=clock()
	local at=namedAt[guid]
	if at~=nil and now-at<SIGHT_REPEAT_MINUTES*60 then
		traceSight("refused","repeat",source,carries(note),rival)
		return
	end
	if lastLine~=nil and now-lastLine<SIGHT_QUIET_SECONDS then
		traceSight("refused","quiet",source,carries(note),rival)
		return
	end

	remember(guid,now)
	lastLine=now
	local line=A.sightLine(guid)
	local clause=marked and A.rivalClause(guid)or nil
	if clause then
		line=line.."  "..clause
	end
	A.say(line)
	traceSight("said",nil,source,carries(note),rival)
end

local function hideMark(frame)
	for _,held in ipairs({marks,rivalMarks})do
		local mark=held[frame]
		if mark then
			pcall(mark.Hide,mark)
		end
	end
end

local function showMark(frame,rival)
	local held=rival and rivalMarks or marks
	local other=(rival and marks or rivalMarks)[frame]
	if other then
		pcall(other.Hide,other)
	end
	local mark=held[frame]
	if not mark then
		local ok,made=pcall(frame.CreateTexture,frame,nil,"OVERLAY")
		if not(ok and type(made)=="table")then
			return false
		end
		made:SetSize(MARK_SIZE,MARK_SIZE)
		made:SetPoint("TOPRIGHT",frame,"TOPRIGHT",0,0)
		made:SetTexture(A.ICON_TEXTURE)
		if rival then
			local r,g,b=A.color("loss")
			made:SetVertexColor(r,g,b)
		end
		held[frame]=made
		mark=made
	end
	mark:Show()
	return true
end

local function onPlateAdded(token)
	local frame=type(token)=="string"and plateFrame(token)or nil
	if frame then
		hideMark(frame)
		plateOf[token]=frame
	end

	local guid,note,marked,rival=examine(token,"plate")
	if not guid then
		return
	end

	if frame and showMark(frame,note==nil)then
		traceSight("marked",nil,"plate",carries(note),rival)
	else
		traceSight("refused","no-plate","plate",carries(note),rival)
	end
	speak(guid,note,marked,rival,"plate")
end

local function onPlateRemoved(token)
	if type(token)~="string"then
		return
	end
	local frame=plateFrame(token)or plateOf[token]
	plateOf[token]=nil
	if frame then
		hideMark(frame)
	end
end

local function onTarget()
	local guid,note,marked,rival=examine("target","target")
	if guid then
		speak(guid,note,marked,rival,"target")
	end
end

A.on("NAME_PLATE_UNIT_ADDED",function(_,token)
	A.trace("sight",{state="event",source="plate-added"})
	contained(onPlateAdded,token)
end)
A.on("NAME_PLATE_UNIT_REMOVED",function(_,token)
	A.trace("sight",{state="event",source="plate-removed"})
	contained(onPlateRemoved,token)
end)
A.on("PLAYER_TARGET_CHANGED",function()
	A.trace("sight",{state="event",source="target"})
	contained(onTarget)
end)

function A.reportSight(word)
	if word=="on"or word=="off"then
		local wanted=word=="on"
		if not A.setSight(wanted)then
			A.say("no database, so the setting could not be stored")
			return
		end
		A.say("marking people you have written about "..(wanted and"on"or"off"))
		return
	end

	if word then
		A.say(("unknown sight command %q. on or off"):format(word))
		return
	end

	local state=A.sightEnabled()and"on"or"off"
	local marked=markedCount()
	A.say(("marking people you have written about %s, %d %s marked")
		:format(state,marked,marked==1 and"plate"or"plates"))
end
