


local _, A = ...




local REASONS = {
	drawn = true,
	unmeasured = true,
	empty = true,
	cramped = true,
	unnamed = true,
	folded = true,
}




function A.bandVerdict(band)
	if type(band) ~= "table" then
		return false, "empty"
	end

	local contents = type(band.contents) == "number" and band.contents or 0
	local minimum = type(band.minimum) == "number" and band.minimum or 1
	if minimum < 0 then
		minimum = 0
	end


	if band.heading == nil or band.heading == false then
		return true, "unnamed"
	end

	if contents < minimum then
		return false, "empty"
	end


	if band.folded == true then
		return false, "folded"
	end



	local room = band.room
	if type(room) ~= "number" then
		return true, "unmeasured"
	end
	if room <= 0 then
		return false, "cramped"
	end

	local heading = type(band.heading) == "number" and band.heading or 0
	local rowHeight = type(band.rowHeight) == "number" and band.rowHeight or 0
	if heading + minimum * rowHeight > room then
		return false, "cramped"
	end

	return true, "drawn"
end




function A.bandShown(band)
	local shown = A.bandVerdict(band)
	return shown
end



function A.bandSplit(band)
	if type(band) ~= "table" then
		return false
	end
	local extent, contents = band.extentFrom, band.contentsFrom
	if type(extent) ~= "string" or type(contents) ~= "string" then
		return false
	end
	return extent ~= contents
end


function A.bandPass(bands)
	local out = {}
	if type(bands) ~= "table" then
		return out
	end
	for i = 1, #bands do
		local band = bands[i]
		local shown, reason = A.bandVerdict(band)
		out[i] = {
			name = type(band) == "table" and band.name or nil,
			shown = shown,
			reason = reason,
			split = A.bandSplit(band),
		}
	end
	return out
end




function A.bandFaults(bands, where)
	local out = {}
	local pass = A.bandPass(bands)
	local at = type(where) == "string" and where or ""

	for i = 1, #pass do
		local band = pass[i]
		local named = at ~= "" and (at .. " " .. tostring(band.name)) or tostring(band.name)

		if band.reason == "cramped" then
			out[#out + 1] = { what = "region-too-short", where = named,
				why = "the room will not hold the heading and one row of what it names" }
		elseif band.reason == "unmeasured" then

			out[#out + 1] = { what = "band-unmeasured", where = named,
				why = "no room was declared, so the region cannot be found too short" }
		end

		if band.split then
			out[#out + 1] = { what = "extent-split", where = named,
				why = "the extent and the contents are derived from different origins" }
		end
	end

	return out
end


function A.bandReasonKnown(reason)
	return type(reason) == "string" and REASONS[reason] == true
end




local ARRANGEMENTS = {
	["three cards"] = true,
	["a merge of two plus one"] = true,
	["one card of three"] = true,
	["a reading with no qualifier"] = true,
	["no card qualified"] = true,
}




function A.columnShareFaults(columns, room, where)
	local out = {}
	if type(columns) ~= "table" or #columns == 0 then
		return out
	end
	local at = type(where) == "string" and where ~= "" and where or "a column set"

	local spread = false
	for i = 1, #columns do
		if type(columns[i].width) == "number" then
			spread = true
			break
		end
	end
	if not spread then
		return out
	end


	local span = A.metric("rowLabelPad") * 2 + A.metric("rowCellGap") * (#columns - 1)
	for i = 1, #columns do
		local column = columns[i]
		local share = column.width
		local named = tostring(column.name or column.key or i)
		if type(share) ~= "number" then

			out[#out + 1] = { what = "column-share", where = at,
				why = ("%s carries no share where the set beside it does"):format(named) }
			return out
		end
		span = span + share
		local shareAt = A.unitFigure(share)
		if shareAt ~= nil and shareAt < 1 then
			out[#out + 1] = { what = "column-share", where = at,
				why = ("%s is spread to %s, which no value draws in"):format(named, tostring(shareAt)) }
		end


		local head = type(A.headerFloor) == "function" and A.headerFloor(column.name) or 0
		local headAt = A.unitFigure(head)
		if headAt ~= nil and headAt > 0 and shareAt ~= nil and shareAt < headAt then
			out[#out + 1] = { what = "column-share", where = at,
				why = ("%s is spread to %s, under the %s its own header needs"):format(named,
					tostring(shareAt), tostring(headAt)) }
		end
	end

	local spanAt, roomAt = A.unitFigure(span), A.unitFigure(room)
	if roomAt ~= nil and roomAt > 0 and spanAt ~= roomAt then
		out[#out + 1] = { what = "column-share", where = at,
			why = ("the spread spans %s in a room of %s"):format(tostring(spanAt), tostring(roomAt)) }
	end

	return out
end


function A.cardRowArrangementKnown(arrangement)
	return type(arrangement) == "string" and ARRANGEMENTS[arrangement] == true
end






function A.overlapFaults(blocks, where)
	local out = {}
	if type(blocks) ~= "table" then
		return out
	end
	local at = type(where) == "string" and where ~= "" and (where .. " ") or ""



	local placed = {}
	for i = 1, #blocks do
		local block = blocks[i]
		if type(block) == "table" then
			local from, to = A.unitFigure(block.from), A.unitFigure(block.to)
			if from ~= nil and to ~= nil and to > from then
				placed[#placed + 1] = { name = block.name, from = from, to = to }
			end
		end
	end

	for i = 1, #placed do
		for j = i + 1, #placed do
			local one, two = placed[i], placed[j]
			if one.from < two.to and two.from < one.to then
				local first, second = one, two
				if two.from < one.from then
					first, second = two, one
				end
				out[#out + 1] = { what = "blocks-overlap", where = at .. tostring(first.name),
					why = ("%s runs to %s where %s begins at %s"):format(tostring(first.name),
						tostring(first.to), tostring(second.name), tostring(second.from)) }
			end
		end
	end

	return out
end






function A.shortfallFaults(blocks, where)
	local out = {}
	if type(blocks) ~= "table" then
		return out
	end
	local at = type(where) == "string" and where ~= "" and (where .. " ") or ""

	for i = 1, #blocks do
		local block = blocks[i]


		local needs = type(block) == "table" and A.unitFigure(block.needs) or nil
		local room = type(block) == "table" and A.unitFigure(block.room) or nil
		if needs ~= nil and needs > 0 and room ~= nil and room < needs then
			out[#out + 1] = { what = "block-short", where = at .. tostring(block.name),
				why = ("%s units of room against the %s it was promised"):format(
					tostring(room), tostring(needs)) }
		end
	end

	return out
end



local promised = {}



function A.notePromisedRoom(name, needs, room)
	if type(name) ~= "string" or name == "" or type(needs) ~= "number" then
		return false
	end
	promised[name] = {
		name = name,
		needs = needs,
		room = type(room) == "number" and room or nil,
	}
	return true
end


function A.promisedRooms()
	local out = {}
	for _, held in pairs(promised) do
		out[#out + 1] = held
	end
	table.sort(out, function(one, two)
		return tostring(one.name) < tostring(two.name)
	end)
	return out
end







local function unitText(value)
	local whole = math.floor(value)
	if value == whole then
		return ("%d"):format(value)
	end
	local forms = { "%.1f", "%.2f" }
	for i = 1, #forms do
		local text = forms[i]:format(value)
		local read = tonumber(text)
		if read ~= whole and read ~= whole + 1 then
			return text
		end
	end
	return ("just over %d"):format(whole)
end




local UNREAD_WORDS = {
	["absent"] = "the box was not there",
	["invalid-rect"] = "its rect had not resolved",
	["no-value"] = "the height call answered nothing usable",
}




function A.viewportFaults(views, where)
	local out = {}
	if type(views) ~= "table" then
		return out
	end
	local at = type(where) == "string" and where ~= "" and (where .. " ") or ""

	for i = 1, #views do
		local view = views[i]
		if type(view) == "table" and type(view.extent) == "number" and view.extent > 0
			and type(view.room) ~= "number" then

			out[#out + 1] = { what = "viewport-unread", where = at .. tostring(view.name),
				why = ("the height did not read, %s, so whether it ends on a whole row of %s is unestablished")
					:format(UNREAD_WORDS[view.why] or "and no reason was recorded",
						unitText(A.unitFigure(view.extent) or view.extent)) }
		elseif type(view) == "table" and view.composed and type(view.room) == "number"
			and type(view.rectNow) == "number" and not A.roomsAgree(view.room, view.rectNow) then


			out[#out + 1] = { what = "viewport-disagrees", where = at .. tostring(view.name),
				why = ("the room composed for it is %s and its box answers %s now, so the column written out "
					.. "above or below it is not the one the client laid out")
					:format(unitText(A.unitFigure(view.room) or view.room),
						unitText(A.unitFigure(view.rectNow) or view.rectNow)) }
		elseif type(view) == "table" and type(view.room) == "number" and view.room > 0
			and type(view.extent) == "number" and view.extent > 0 then


			local room = A.unitFigure(view.room) or view.room
			local extent = A.unitFigure(view.extent) or view.extent
			local rows, whole = A.viewportRows(room, extent)


			local over = A.unitFigure(room - whole) or 0

			if rows >= 1 and over > 0 and not view.varies then

				out[#out + 1] = { what = "row-cut", where = at .. tostring(view.name),
					why = ("%s units of viewport over %d rows of %s, so %s units of a row draw cut")
						:format(unitText(room), rows, unitText(extent), unitText(over)) }
			end
		end
	end

	return out
end



local viewports = {}






function A.noteViewport(name, room, extent, varies, why, frame, extra)
	if type(name) ~= "string" or name == "" or type(extent) ~= "number" or extent <= 0 then
		return false
	end
	extra = type(extra) == "table" and extra or {}
	viewports[name] = {
		name = name,
		room = type(room) == "number" and room or nil,
		extent = extent,
		varies = varies and true or false,
		why = (type(A.roomBranchKnown) == "function" and A.roomBranchKnown(why)) and why or nil,
		frame = type(frame) == "table" and frame or nil,
		composed = extra.composed == true,
		rect = type(extra.rect) == "number" and extra.rect or nil,
		box = type(extra.box) == "string" and extra.box ~= "" and extra.box or nil,
	}
	return true
end



function A.forgetViewport(name)
	if type(name) ~= "string" or viewports[name] == nil then
		return false
	end
	viewports[name] = nil
	return true
end





local function boxOnScreen(frame)
	if not (frame and type(frame.IsVisible) == "function") then
		return nil
	end
	local ok, up = pcall(frame.IsVisible, frame)
	if not ok or type(up) ~= "boolean" then
		return nil
	end
	return up
end





function A.recordedViewports()
	local out, unshown = {}, {}
	for _, held in pairs(viewports) do

		if held.frame ~= nil and boxOnScreen(held.frame) == false then
			unshown[#unshown + 1] = held
		else
			if held.room == nil and held.frame ~= nil and type(A.bandHeight) == "function" then
				local room, why = A.bandHeight(held.frame)
				if type(room) == "number" then
					held.room = room
				end
				if type(A.roomBranchKnown) == "function" and A.roomBranchKnown(why) then
					held.why = why
				end
			end


			held.rectNow = nil
			if held.composed and held.frame ~= nil and type(A.bandHeight) == "function" then
				local rect = A.bandHeight(held.frame)
				held.rectNow = type(rect) == "number" and rect or nil
			end
			out[#out + 1] = held
		end
	end
	local function byName(one, two)
		return tostring(one.name) < tostring(two.name)
	end
	table.sort(out, byName)
	table.sort(unshown, byName)
	out.unshown = unshown
	return out
end


function A.unshownViewportLine()
	if type(A.recordedViewports) ~= "function" then
		return nil
	end
	local unshown = A.recordedViewports().unshown
	if type(unshown) ~= "table" or #unshown == 0 then
		return nil
	end
	local names = {}
	for i = 1, #unshown do
		names[i] = tostring(unshown[i].name)
	end
	return ("%d viewport%s not showing, unchecked: %s")
		:format(#names, #names == 1 and "" or "s", table.concat(names, ", "))
end



function A.viewportLines()
	local names = {}
	for name in pairs(viewports) do
		names[#names + 1] = name
	end
	table.sort(names)
	local out = {}
	for i = 1, #names do
		local held = viewports[names[i]]
		local room = type(held.room) == "number" and (A.unitFigure(held.room) or held.room) or nil
		local source
		if room == nil then
			source = ("unread in the paint, %s"):format(UNREAD_WORDS[held.why] or "for no recorded reason")
		elseif held.composed then
			source = "by arithmetic"
		else
			source = "read in the paint"
		end

		local now


		local up = nil
		if held.frame ~= nil then
			up = boxOnScreen(held.frame)
		end
		if held.frame == nil then
			now = "no box held to ask"
		elseif up == false then
			now = "not on screen now, so not asked"
		else
			local rect, why = A.bandHeight(held.frame)
			if type(rect) == "number" then
				now = "rect " .. unitText(A.unitFigure(rect) or rect) .. " now"
				if room ~= nil and held.composed then
					now = now .. (A.roomsAgree(held.room, rect) and ", agreeing"
						or ", DISAGREEING with the arithmetic, which is what the paint rounded against")
				end
			else
				now = "rect not answered now, " .. (UNREAD_WORDS[why] or "for no recorded reason")
			end
		end

		local extent = A.unitFigure(held.extent) or held.extent
		local tail
		if room == nil then
			tail = ("rows of %s"):format(unitText(extent))
		else
			local rows, whole = A.viewportRows(room, extent)
			tail = ("%d rows of %s, remainder %s"):format(rows, unitText(extent),
				unitText(A.unitFigure(room - whole) or (room - whole)))
		end
		out[#out + 1] = ("viewport %s  %s  room %s %s, %s, %s%s")
			:format(tostring(held.name), held.box or "no name on the box it scrolls in",
				room and unitText(room) or "none", source, now, tail,
				held.varies and ", its rows varying from that base" or "")
	end
	return out
end





local placed = {}



function A.notePlacedRow(where, blocks)
	if type(where) ~= "string" or where == "" then
		return false
	end
	placed[where] = { where = where, blocks = type(blocks) == "table" and blocks or {} }
	return true
end



function A.notePlacedRows(name, rows)
	if type(name) ~= "string" or name == "" or type(rows) ~= "table" then
		return false
	end
	local count = 0
	for i = 1, #rows do
		A.notePlacedRow(("%s %d"):format(name, i), rows[i])
		count = i
	end
	local i = count + 1
	while placed[("%s %d"):format(name, i)] ~= nil do
		placed[("%s %d"):format(name, i)] = nil
		i = i + 1
	end
	return true
end


function A.placedRows()
	local out = {}
	for _, held in pairs(placed) do
		out[#out + 1] = held
	end
	table.sort(out, function(one, two)
		return tostring(one.where) < tostring(two.where)
	end)
	return out
end
