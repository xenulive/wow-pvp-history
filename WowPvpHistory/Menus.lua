-- WowPvpHistory 0.75.26
-- Author:  Xenu-Sentinels
-- Project: wow-pvp-history
--          https://github.com/xenulive/wow-pvp-history
-- License: MIT, see LICENSE
local _,A=...

local TAGS={
	"MENU_UNIT_PLAYER",
	"MENU_UNIT_ENEMY_PLAYER",
	"MENU_UNIT_FRIEND",
	"MENU_UNIT_TARGET",
	"MENU_UNIT_FOCUS",
	"MENU_UNIT_PARTY",
	"MENU_UNIT_RAID",
	"MENU_UNIT_RAID_PLAYER",
}

local TITLE_NOTE_MAX=60

local registered=0

function A.contextMenuEnabled()
	local db=A.db()
	if not db then
		return false
	end
	return not(type(db.ui)=="table"and db.ui.contextMenu==false)
end

function A.setContextMenu(enabled)
	local db=A.db()
	if not db then
		return false
	end
	db.ui=db.ui or{}
	if enabled==false then
		db.ui.contextMenu=false
	else
		db.ui.contextMenu=nil
	end

	if A.notifyContextMenuSetting then
		A.notifyContextMenuSetting()
	end
	return true
end

function A.menuTagsRegistered()
	return registered
end

function A.menuTagCount()
	return#TAGS
end

local function resolve(contextData)
	if type(contextData)~="table"then
		return nil,nil
	end

	local location=contextData.playerLocation
	if type(location)=="table"then
		local guid=A.readableString(location.guid)
		if guid then
			return guid,"location"
		end

		local line=location.chatLineID
		if A.canRead(line)then
			local sender=A.readableString(A.guardedCall(
				C_ChatInfo and C_ChatInfo.GetChatLineSenderGUID,line))
			if sender then
				return sender,"chatline"
			end
		end
	end

	local unit=contextData.unit
	if A.canRead(unit)then
		local guid=A.readableString(A.guardedCall(UnitGUID,unit))
		if guid then
			return guid,"unit"
		end
	end

	return nil,nil
end

function A.clientPlayerName(guid)
	local fn=GetPlayerInfoByGUID
	if type(fn)~="function"then
		return nil
	end

	local ok,_,_,_,_,_,rawName,rawRealm=pcall(fn,guid)
	if not ok then
		return nil
	end

	local name=A.readableString(rawName)
	if not name then
		return nil
	end

	local realm=A.readableString(rawRealm)
	if not realm then
		return name
	end
	return("%s-%s"):format(name,realm)
end

local function playerName(guid)
	local db=A.db()
	local index=db and type(db.players)=="table"and db.players or{}
	local entry=index[guid]
	if type(entry)=="table"and type(entry.names)=="table"
		and type(entry.names[1])=="string"then
		return entry.names[1],true
	end

	local note=A.noteFor(guid)
	if note and type(note.name)=="string"and note.name~=""then
		return note.name,false
	end

	return A.clientPlayerName(guid),false
end

local function noteTitle(guid)
	local note=A.noteFor(guid)
	if not(note and type(note.text)=="string"and note.text~="")then
		return nil
	end

	local text=note.text
	if#text>TITLE_NOTE_MAX then
		text=A.byteCut(text,TITLE_NOTE_MAX).."..."
	end
	return text
end

local function storeName(guid)
	local name=A.clientPlayerName(guid)
	local named=false
	if name then
		named=A.setPlayerName(guid,name)==true
	end
	if named and type(A.refreshNotes)=="function"then
		pcall(A.refreshNotes)
	end
	return named
end

local function writeRating(guid,value,source,scale)
	local field=scale=="attitude"and"attitude"or"rating"
	local set=scale=="attitude"and A.setPlayerAttitude or A.setPlayerRating
	local ok,was,why=set(guid,value)
	if not ok then
		return false,why
	end
	if source=="menu"and value==nil and was~=nil then
		A.sayRemoved(guid,field,was)
	end

	local named=storeName(guid)

	A.trace("note",{
		source=source,
		reason=value==nil and"cleared"or field,
		named=named,
	},"data")
	return true
end

local function known(guid)
	if type(A.playerEntry)~="function"then
		return true
	end
	local ok,_,stored=pcall(A.playerEntry,guid)
	return ok and stored==true
end

local function build(root,guid)
	local name=playerName(guid)

	if type(root.CreateDivider)=="function"then
		root:CreateDivider()
	end

	if type(root.CreateTitle)=="function"then
		root:CreateTitle(A.colorEscape("accent")..A.displayName().."|r")
	end

	local record=nil
	if type(A.playerRecordText)=="function"then
		local ok,text=pcall(A.playerRecordText,guid)
		record=(ok and type(text)=="string"and text~="")and text or nil
	end

	local said=record or(A.colorEscape("dimmer").."no recorded match")

	root:CreateButton(said.."|r",function()
		if record and type(A.openPlayer)=="function"then
			A.openPlayer(guid,false,"menu")
		end
	end)

	if not(known(guid)or name)then
		return
	end

	local sub=root:CreateButton("Rate and note")
	local titled=type(sub.CreateTitle)=="function"

	if name and titled then
		sub:CreateTitle(tostring(name))
	end

	local note=noteTitle(guid)
	if note and titled then
		sub:CreateTitle(note)
	end

	for _,scale in ipairs(A.SCALES)do
		if titled then
			sub:CreateTitle(A.colorEscape("dim")..A.scaleLabel(scale).."|r")
		end
		local field=scale=="attitude"and"attitude"or"rating"
		local choices=A.ratingChoices(scale)
		for i=1,#choices do
			local choice=choices[i]
			local wanted=choice.rating
			local offered=wanted~=nil
			if not offered then
				local stored=A.noteFor(guid)
				offered=stored~=nil and stored[field]~=nil
			end

			if offered then
				sub:CreateRadio(choice.label,function()
					local stored=A.noteFor(guid)
					return(stored and stored[field]or nil)==wanted
				end,function()
					local ok,why=writeRating(guid,wanted,"menu",scale)
					if not ok then
						A.say(("%s, so the %s could not be stored"):format(A.noteRefusalText(why),scale))
					end
				end)
			end
		end
	end

	if type(sub.CreateDivider)=="function"then
		sub:CreateDivider()
	end

	sub:CreateButton("Write a note",function()
		if type(A.openPlayer)=="function"then
			A.openPlayer(guid,true,"menu")
		end
	end)
end

local function traceTag(tag,outcome)
	A.trace("menu",{source=tag,reason=outcome},"data")
end

local function modify(tag,root,contextData)
	if not A.contextMenuEnabled()then
		return
	end

	local suppressed,reading=A.pvpRestricted()
	if suppressed then
		A.trace("menu",{source=tag,reason="restriction",restriction=reading},"data")
		return
	end

	if type(root)~="table"or type(root.CreateButton)~="function"then
		return
	end

	local guid,path=resolve(contextData)
	if not guid then
		traceTag(tag,"unresolved")
		return
	end

	if A.isOwnCharacter(guid)then
		traceTag(tag,"self")
		return
	end

	build(root,guid)
	traceTag(tag,path)
end

local BINDINGS={
	["rate-bad"]={rating=-2,self="You can't rate yourself"},
	["rate-strong"]={rating=2,self="You can't rate yourself"},
	note={self="You can't write a note about yourself"},
	flag={self="You can't flag yourself"},
}

local REFUSED_LINES={
	["no-target"]="Nothing targeted",
	["not-player"]="That isn't a player",
	secret="The game hides who that is during a match",
}

local function traceBind(binding,action,reason)
	A.trace("bind",{binding=binding,action=action,reason=reason},"ui")
end

local function linkedName(guid)
	local name=playerName(guid)
	if type(name)~="string"or name==""then
		return"Your target"
	end
	return A.playerLink(guid,name)
end

local function press(binding)
	local spec=BINDINGS[binding]
	if not spec then
		traceBind(binding,"refused","unknown-binding")
		return
	end

	local guid,why=A.targetPlayer()
	if not guid then
		A.say(why=="self"and spec.self or REFUSED_LINES[why]or"Nothing targeted")
		traceBind(binding,"refused",why)
		return
	end

	if binding=="note"then
		local _,outcome=A.openPlayer(guid,true,"bind")
		if outcome=="refused"then
			A.say("The player window could not open")
			traceBind(binding,"refused","window")
			return
		end
		traceBind(binding,"note")
		return
	end

	if binding=="flag"then
		local ok,added,reason=A.addPlayerTags(guid,{A.REVIEW_TAG})
		if not ok then
			A.say("Nothing was saved: "..A.noteRefusalText(reason))
			traceBind(binding,"refused",reason)
			return
		end
		storeName(guid)
		local fresh=#added>0
		A.say(linkedName(guid)..(fresh and" flagged for review"or" is already flagged for review"))
		traceBind(binding,"flag",not fresh and"unchanged"or nil)
		return
	end

	local stored=A.noteFor(guid)
	local value=spec.rating
	if stored and stored.rating==value then
		value=nil
	end
	local ok,reason=writeRating(guid,value,"bind")
	if not ok then
		A.say("Nothing was saved: "..A.noteRefusalText(reason))
		traceBind(binding,"refused",reason)
		return
	end
	if value==nil then
		A.say(linkedName(guid).." no longer rated")
		traceBind(binding,"clear")
		return
	end
	local label=A.ratingText(value)
	A.say(("%s skill %s"):format(linkedName(guid),label:sub(1,1):upper()..label:sub(2)))
	traceBind(binding,"rate")
end

function A.pressBinding(binding)
	local ok,err=pcall(press,binding)
	if not ok then
		A.noteError(err,"bind")
	end
	return ok
end

local function register()
	local menu=Menu
	if type(menu)~="table"or type(menu.ModifyMenu)~="function"then
		return 0
	end

	local took=0
	for i=1,#TAGS do
		local tag=TAGS[i]
		local ok=pcall(menu.ModifyMenu,tag,function(_,root,contextData)
			pcall(modify,tag,root,contextData)
		end)
		if ok then
			took=took+1
		end
	end
	return took
end

registered=register()
