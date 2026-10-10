























local _, A = ...

















local TAGS = {
	"MENU_UNIT_PLAYER",
	"MENU_UNIT_ENEMY_PLAYER",
	"MENU_UNIT_FRIEND",
	"MENU_UNIT_TARGET",
	"MENU_UNIT_FOCUS",
	"MENU_UNIT_PARTY",
	"MENU_UNIT_RAID",
	"MENU_UNIT_RAID_PLAYER",
}







local TITLE_NOTE_MAX = 60



local registered = 0








function A.contextMenuEnabled()
	local db = A.db()
	if not db then
		return false
	end
	db.ui = db.ui or {}
	return db.ui.contextMenu ~= false
end





function A.setContextMenu(enabled)
	local db = A.db()
	if not db then
		return false
	end
	db.ui = db.ui or {}
	if enabled == false then
		db.ui.contextMenu = false
	else
		db.ui.contextMenu = nil
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
	return #TAGS
end








local function guarded(fn, ...)
	if type(fn) ~= "function" then
		return nil
	end
	local ok, res = pcall(fn, ...)
	if not ok then
		return nil
	end
	return res
end





local function readable(value)
	if type(value) ~= "string" then
		return nil
	end
	if not A.canRead(value) then
		return nil
	end
	if value == "" then
		return nil
	end
	return value
end








local function resolve(contextData)
	if type(contextData) ~= "table" then
		return nil, nil
	end

	local location = contextData.playerLocation
	if type(location) == "table" then
		local guid = readable(location.guid)
		if guid then
			return guid, "location"
		end



		local line = location.chatLineID
		if A.canRead(line) then
			local sender = readable(guarded(
				C_ChatInfo and C_ChatInfo.GetChatLineSenderGUID, line))
			if sender then
				return sender, "chatline"
			end
		end
	end

	local unit = contextData.unit
	if A.canRead(unit) then
		local guid = readable(guarded(UnitGUID, unit))
		if guid then
			return guid, "unit"
		end
	end

	return nil, nil
end




















function A.clientPlayerName(guid)
	local fn = GetPlayerInfoByGUID
	if type(fn) ~= "function" then
		return nil
	end

	local ok, _, _, _, _, _, rawName, rawRealm = pcall(fn, guid)
	if not ok then
		return nil
	end




	local name = readable(rawName)
	if not name then
		return nil
	end

	local realm = readable(rawRealm)
	if not realm then
		return name
	end
	return ("%s-%s"):format(name, realm)
end















local function playerName(guid)
	local db = A.db()
	local index = db and type(db.players) == "table" and db.players or {}
	local entry = index[guid]
	if type(entry) == "table" and type(entry.names) == "table"
		and type(entry.names[1]) == "string" then
		return entry.names[1], true
	end

	local note = A.noteFor(guid)
	if note and type(note.name) == "string" and note.name ~= "" then
		return note.name, false
	end

	return A.clientPlayerName(guid), false
end


local function noteTitle(guid)
	local note = A.noteFor(guid)
	if not (note and type(note.text) == "string" and note.text ~= "") then
		return nil
	end

	local text = note.text
	if #text > TITLE_NOTE_MAX then
		text = text:sub(1, TITLE_NOTE_MAX) .. "..."
	end
	return text
end









local function writeRating(guid, value)
	if not A.setPlayerRating(guid, value) then
		return false
	end



	local name = A.clientPlayerName(guid)
	local named = false
	if name then
		named = A.setPlayerName(guid, name) == true
	end



	if named and type(A.refreshNotes) == "function" then
		pcall(A.refreshNotes)
	end








	A.trace("note", {
		source = "menu",
		reason = value == nil and "cleared" or "rating",
		named = named,
	}, "data")
	return true
end





local function known(guid)
	if type(A.playerEntry) ~= "function" then
		return true
	end
	local ok, _, stored = pcall(A.playerEntry, guid)
	return ok and stored == true
end











local function build(root, guid)
	local name = playerName(guid)




	if type(root.CreateDivider) == "function" then
		root:CreateDivider()
	end


	if type(root.CreateTitle) == "function" then
		root:CreateTitle(A.colorEscape("accent") .. A.displayName() .. "|r")
	end







	local record = nil
	if type(A.playerRecordText) == "function" then
		local ok, text = pcall(A.playerRecordText, guid)
		record = (ok and type(text) == "string" and text ~= "") and text or nil
	end








	local said = record or (A.colorEscape("dimmer") .. "no recorded match")



	root:CreateButton(said .. "|r", function()
		if record and type(A.openPlayer) == "function" then
			A.openPlayer(guid, false, "menu")
		end
	end)







	if not (known(guid) or name) then
		return
	end


	local sub = root:CreateButton("Rate and note")

	if name then
		sub:CreateTitle(tostring(name))
	end

	local note = noteTitle(guid)
	if note then
		sub:CreateTitle(note)
	end

	local choices = A.ratingChoices()
	for i = 1, #choices do
		local choice = choices[i]


		local wanted = choice.rating
		local offered = wanted ~= nil
		if not offered then


			local stored = A.noteFor(guid)
			offered = stored ~= nil and stored.rating ~= nil
		end

		if offered then
			sub:CreateRadio(choice.label, function()
				local stored = A.noteFor(guid)
				return (stored and stored.rating or nil) == wanted
			end, function()
				writeRating(guid, wanted)
			end)
		end
	end

	sub:CreateDivider()



	sub:CreateButton("Write a note", function()
		if type(A.openPlayer) == "function" then


			A.openPlayer(guid, true, "menu")
		end
	end)
end
















local function traceTag(tag, outcome)
	A.trace("menu", { source = tag, reason = outcome }, "data")
end


local function modify(tag, root, contextData)
	if not A.contextMenuEnabled() then
		return
	end

	local suppressed, reading = A.pvpRestricted()
	if suppressed then
		A.trace("menu", { source = tag, reason = "restriction", restriction = reading }, "data")
		return
	end

	if type(root) ~= "table" or type(root.CreateButton) ~= "function" then
		return
	end

	local guid, path = resolve(contextData)
	if not guid then


		traceTag(tag, "unresolved")
		return
	end



	if guid == A.ownGuid() then
		traceTag(tag, "self")
		return
	end

	build(root, guid)
	traceTag(tag, path)
end













local function register()
	local menu = Menu
	if type(menu) ~= "table" or type(menu.ModifyMenu) ~= "function" then
		return 0
	end

	local took = 0
	for i = 1, #TAGS do
		local tag = TAGS[i]
		local ok = pcall(menu.ModifyMenu, tag, function(_, root, contextData)
			pcall(modify, tag, root, contextData)
		end)
		if ok then
			took = took + 1
		end
	end
	return took
end

registered = register()
