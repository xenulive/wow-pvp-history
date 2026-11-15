-- WowPvpHistory 0.75.68
-- Author:  Xenu-Sentinels
-- Project: wow-pvp-history
--          https://github.com/xenulive/wow-pvp-history
-- License: MIT, see LICENSE
local _,A=...

A.RIVAL_MEETINGS=3

A.RIVALS_NEEDS="The mark and the chat line need A mark on their nameplate, and the tooltip line "
	.."needs Unit tooltip lines, both above."

local READOUT_ROWS=10

function A.rivalsEnabled()
	local db=A.db()
	if not db then
		return false
	end
	return not(type(db.ui)=="table"and db.ui.rivals==false)
end

function A.setRivals(enabled)
	local db=A.db()
	if not db then
		return false
	end
	db.ui=db.ui or{}
	if enabled==false then
		db.ui.rivals=false
		if A.hideRivalMarks then
			A.hideRivalMarks()
		end
	else
		db.ui.rivals=nil
	end
	if A.notifyRivalsSetting then
		A.notifyRivalsSetting()
	end
	return true
end

local function characterKey(guid,entry)
	if not guid:find("^Player%-")then
		return false
	end
	local fields=0
	for _ in guid:gmatch("[^%-]+")do
		fields=fields+1
	end
	if fields<3 then
		return false
	end
	local names=entry.names
	if type(names)=="table"then
		for i=1,#names do
			if names[i]==guid then
				return false
			end
		end
	end
	return true
end

function A.rivalMeetings(guid,entry)
	if type(guid)~="string"then
		return nil
	end
	if type(entry)~="table"then
		local db=A.db()
		entry=db and type(db.players)=="table"and db.players[guid]or nil
	end
	if type(entry)~="table"or type(entry.against)~="table"then
		return nil
	end
	if A.isBotGuid(guid)or not characterKey(guid,entry)or A.isOwnCharacter(guid)then
		return nil
	end
	local count=entry.against.count
	if type(count)~="number"then
		return nil
	end
	local generated=type(entry.fixture)=="number"and entry.fixture or 0
	local meetings=count-generated
	return meetings>0 and meetings or 0,entry
end

function A.isRival(entry,guid)
	local meetings=A.rivalMeetings(guid,entry)
	return meetings~=nil and meetings>=A.RIVAL_MEETINGS
end

function A.againstTally(entry)
	local against=type(entry)=="table"and entry.against or nil
	if type(against)~="table"or type(against.decided)~="number"or against.decided<=0 then
		return nil
	end
	local wins=type(against.wins)=="number"and against.wins or 0
	local draws=type(against.draws)=="number"and against.draws or 0
	return wins,against.decided-wins-draws,draws
end

function A.rivalRecord(entry)
	local wins,losses,draws=A.againstTally(entry)
	if wins==nil then
		return nil
	end
	if draws>0 then
		return("%d-%d-%d"):format(wins,losses,draws)
	end
	return("%d-%d"):format(wins,losses)
end

function A.rivalPhrase(meetings,entry)
	local phrase=("%d %s against you"):format(meetings,meetings==1 and"meeting"or"meetings")
	local record=A.rivalRecord(entry)
	if record then
		phrase=phrase..", "..record
	end
	return phrase
end

function A.rivalClause(guid,entry)
	local meetings,read=A.rivalMeetings(guid,entry)
	if meetings==nil or meetings<A.RIVAL_MEETINGS then
		return nil
	end
	return"rival, "..A.rivalPhrase(meetings,read)
end

local function rivalOrder(a,b)
	if a.rivalMeetings~=b.rivalMeetings then
		return a.rivalMeetings>b.rivalMeetings
	end
	local ae=type(a.lastEpoch)=="number"and a.lastEpoch or 0
	local be=type(b.lastEpoch)=="number"and b.lastEpoch or 0
	if ae~=be then
		return ae>be
	end
	return tostring(a.guid)<tostring(b.guid)
end

function A.rivalList()
	local out={}
	local db=A.db()
	local players=db and type(db.players)=="table"and db.players or nil
	if not players then
		return out
	end
	for guid,entry in pairs(players)do
		local meetings=A.rivalMeetings(guid,entry)
		if meetings~=nil and meetings>=A.RIVAL_MEETINGS then
			out[#out+1]={guid=guid,entry=entry,rivalMeetings=meetings,lastEpoch=entry.lastEpoch}
		end
	end
	table.sort(out,rivalOrder)
	return out
end

function A.rivalRows(rows)
	local out={}
	if type(rows)~="table"then
		return out
	end
	for i=1,#rows do
		local row=rows[i]
		local meetings=type(row)=="table"and A.rivalMeetings(row.guid,row.entry)or nil
		if meetings~=nil and meetings>=A.RIVAL_MEETINGS then
			row.rivalMeetings=meetings
			out[#out+1]=row
		end
	end
	table.sort(out,rivalOrder)
	return out
end

local function gatesOff()
	local clause=""
	if not A.sightEnabled()then
		clause=", but A mark on their nameplate is off, so no mark and no chat line"
	end
	if not A.tooltipEnabled()then
		clause=clause..(clause==""and", but"or", and").." Unit tooltip lines is off, so no tooltip line"
	end
	return clause
end

function A.reportRivals(word)
	if word=="on"or word=="off"then
		local wanted=word=="on"
		if not A.setRivals(wanted)then
			A.say("no database, so the setting could not be stored")
			return
		end
		A.say("marking rivals "..(wanted and"on"or"off")..(wanted and gatesOff()or""))
		return
	end
	if word then
		A.say(("unknown rivals command %q. on or off; bare lists them"):format(word))
		return
	end

	local list=A.rivalList()
	local shown=math.min(#list,READOUT_ROWS)
	local switch=A.rivalsEnabled()and"on"or"off"
	A.say(("%d %s, met %d or more times against you. marking rivals %s%s"):format(#list,
		#list==1 and"rival"or"rivals",A.RIVAL_MEETINGS,switch,A.rivalsEnabled()and gatesOff()or""))
	for i=1,shown do
		local item=list[i]
		local names=item.entry.names
		local name=type(names)=="table"and type(names[1])=="string"and names[1]~=""and names[1]
			or"unnamed"
		A.say("  "..name.."  "..A.rivalPhrase(item.rivalMeetings,item.entry))
	end
	if#list>shown then
		A.say(("  and %d more in the players window's Rivals filter"):format(#list-shown))
	end
	A.trace("rivals",{n=#list,shown=shown,switch=switch},"data")
end
