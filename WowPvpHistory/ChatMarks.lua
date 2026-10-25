-- WowPvpHistory 0.70.27
-- Author:  Xenu-Sentinels
-- Project: wow-pvp-history
--          https://github.com/xenulive/wow-pvp-history
-- License: MIT, see LICENSE
local _,A=...

local GUID_ARGUMENT=14

local marked=0
local passed={}

local registered

local REASONS={"no-store","switch","no-guid","secret-guid","self","unwritten"}

function A.chatMarkEnabled()
	local db=A.db()
	if not db then
		return false
	end
	return not(type(db.ui)=="table"and db.ui.chatMark==false)
end

function A.setChatMark(enabled)
	local db=A.db()
	if not db then
		return false
	end
	db.ui=db.ui or{}
	if enabled==false then
		db.ui.chatMark=false
	else
		db.ui.chatMark=nil
	end

	if A.notifyChatMarkSetting then
		A.notifyChatMarkSetting()
	end
	return true
end

function A.chatMarkBar(note)
	local rating=type(note)=="table"and note.rating or nil
	return A.colorEscape(A.ratingMark(rating)or A.ratingMark(nil)).."|||r "
end

local function traceMark(outcome,reason,mark,rated,event)
	A.trace("chatmark",{
		outcome=outcome,
		reason=reason,
		mark=mark,
		carriesRating=rated,
		chatEvent=event,
	})
end

local function pass(reason,event)
	passed[reason]=(passed[reason]or 0)+1
	traceMark("passed",reason,nil,nil,event)
	return nil
end

local function decorate(event,decoratedPlayerName,...)
	local chatEvent=type(event)=="string"and A.canRead(event)and event or nil
	if not A.db()then
		return pass("no-store",chatEvent)
	end
	if not A.chatMarkEnabled()then
		return pass("switch",chatEvent)
	end

	local guid=select(GUID_ARGUMENT-2,...)
	if type(guid)~="string"then
		return pass("no-guid",chatEvent)
	end
	if not A.canRead(guid)then
		return pass("secret-guid",chatEvent)
	end

	local okOwn,own=pcall(UnitGUID,"player")
	if okOwn and type(own)=="string"and A.canRead(own)and own==guid then
		return pass("self",chatEvent)
	end

	local note=A.noteFor(guid)
	if not(note and A.writtenAbout(note))then
		return pass("unwritten",chatEvent)
	end

	marked=marked+1
	traceMark("marked",nil,A.ratingMark(note.rating)or A.ratingMark(nil),A.ratingText(note.rating)~=nil,
		chatEvent)
	return A.chatMarkBar(note)..decoratedPlayerName
end

local function filter(event,decoratedPlayerName,...)
	local ok,out=pcall(decorate,event,decoratedPlayerName,...)
	if not ok then
		A.noteError(out,"chatmark")
		return nil
	end
	return out
end

local function register()
	if registered~=nil then
		return
	end
	local util=ChatFrameUtil
	local add=type(util)=="table"and util.AddSenderNameFilter or nil
	if type(add)~="function"then
		registered=false
		traceMark("unavailable","no-api")
		return
	end
	registered=pcall(add,filter)
	if not registered then
		traceMark("unavailable","refused")
	end
end

A.on("PLAYER_LOGIN",register)

local SAMPLES={2,1,0,-1,-2,false}

local function sample()
	for i=1,#SAMPLES do
		local rating=SAMPLES[i]or nil
		local note={rating=rating}
		local word=rating and("rated "..A.ratingText(rating))or"written about, no rating"
		A.say(("%sSample: %s, drawn in %s"):format(A.chatMarkBar(note),word,A.ratingMark(rating)))
	end
end

function A.reportChatMark(word)
	if word=="on"or word=="off"then
		local wanted=word=="on"
		if not A.setChatMark(wanted)then
			A.say("no database, so the setting could not be stored")
			return
		end
		A.say("marking people you have written about in chat "..(wanted and"on"or"off"))
		return
	end

	if word=="sample"then
		sample()
		return
	end

	if word then
		A.say(("unknown chatmark command %q. on, off or sample"):format(word))
		return
	end

	local reasons={}
	for i=1,#REASONS do
		local n=passed[REASONS[i]]
		if n then
			reasons[#reasons+1]=("%d %s"):format(n,REASONS[i])
		end
	end
	A.say(("marking people you have written about in chat %s, %d %s marked this session, passed over: %s")
		:format(not A.db()and"unread, no store loaded"or A.chatMarkEnabled()and"on"or"off",marked,marked==1 and"name"or"names",
			#reasons>0 and table.concat(reasons,", ")or"none"))
	if registered==false then
		A.say("this client offers no chat name hook, so no name is marked")
	end
end
