
























local ADDON, A = ...



local tip


local HEADS = { "RATING", "W-L", "WON", "LAST" }


local WIDTHS = { "finderRatingWidth", "finderRecordWidth", "finderRateWidth", "finderSinceWidth" }



local session



local dockSession



local sessionPosition



local dragFrom



local last = { decision = "not-run", rows = {} }









local walked


local finderHooked, panelHooked, showHooked = false, false, false


local pending = false





function A.finderEnabled()
	local db = A.db()
	if not db then
		return false
	end
	return not (type(db.ui) == "table" and db.ui.finder == false)
end

local schedule


function A.setFinder(enabled)
	local db = A.db()
	if not db then
		return false
	end
	db.ui = db.ui or {}
	if enabled == false then
		db.ui.finder = false
	else
		db.ui.finder = nil
	end
	if A.notifyFinderSetting then
		A.notifyFinderSetting()
	end
	schedule("setting")
	return true
end


function A.setFinderSession(state)
	if state ~= "on" and state ~= "off" then
		state = nil
	end
	session = state
	schedule("session")
	return true
end


function A.finderSession()
	return session
end


function A.finderDocked()
	local db = A.db()
	if not db then
		return true
	end
	return not (type(db.ui) == "table" and db.ui.finderDocked == false)
end


function A.setFinderDocked(docked)
	local db = A.db()
	if not db then
		return false
	end
	db.ui = db.ui or {}
	if docked == false then
		db.ui.finderDocked = false
	else
		db.ui.finderDocked = nil
	end
	if A.notifyFinderDockSetting then
		A.notifyFinderDockSetting()
	end
	schedule("setting")
	return true
end


function A.setFinderDockSession(state)
	if state ~= "dock" and state ~= "undock" then
		state = nil
	end
	dockSession = state
	schedule("session")
	return true
end


function A.finderDockState()
	if dockSession ~= nil then
		return dockSession == "dock", "session"
	end
	return A.finderDocked(), "setting"
end


local function whole(value)
	if type(value) ~= "number" or value ~= value then
		return nil
	end
	return math.floor(value + 0.5)
end





function A.finderPosition()
	local db = A.db()
	if not db or type(db.ui) ~= "table" then
		return nil
	end
	local held = db.ui.finderPosition
	if type(held) ~= "table" or type(held.point) ~= "string" then
		return nil
	end
	local x, y = whole(held.x), whole(held.y)
	if x == nil or y == nil then
		return nil
	end
	return { point = held.point, x = x, y = y }
end



local function heldPosition()
	if sessionPosition ~= nil then
		return sessionPosition, "session"
	end
	local stored = A.finderPosition()
	if stored ~= nil then
		return stored, "stored"
	end
	return nil, nil
end



function A.resetFinderPosition()
	local db = A.db()
	if not db then
		return false
	end
	if type(db.ui) == "table" then
		db.ui.finderPosition = nil
	end
	sessionPosition = nil
	schedule("reset")
	return true
end






local function currentSeason()
	local season = A.seasonNewest and A.seasonNewest() or nil
	if season == nil and A.seasonNow then
		season = A.seasonNow()
	end
	return season
end


function A.finderTitle()
	return A.displayName():upper()
end







local function subject()
	if A.sandboxed() then
		return { guid = nil, sandbox = true }
	end
	return { guid = A.ownGuid(), sandbox = false }
end



local function ownName()
	if A.sandboxed() and A.fixtureCharacterName then
		return A.fixtureCharacterName()
	end
	if type(UnitName) == "function" then
		local ok, name = pcall(UnitName, "player")
		if ok and A.canRead(name) and type(name) == "string" and name ~= "" then
			return name
		end
	end
	local db = A.db()
	local guid = A.ownGuid()
	local held = guid and db and type(db.characters) == "table" and db.characters[guid] or nil
	if type(held) == "table" and type(held.name) == "string" and held.name ~= "" then
		return held.name
	end
	return nil
end




function A.finderScope()
	local season = currentSeason()
	local lead = season == nil and "All time" or ("Season %s"):format(tostring(season))
	local name = ownName()
	if name == nil then
		return lead
	end
	return ("%s, %s"):format(lead, name)
end


function A.finderSince(epoch, now)
	if type(epoch) ~= "number" or type(now) ~= "number" then
		return nil
	end
	local gone = now - epoch
	if gone < 60 then
		return "just now"
	elseif gone < 3600 then
		return ("%dm ago"):format(math.floor(gone / 60))
	elseif gone < 86400 then
		return ("%dh ago"):format(math.floor(gone / 3600))
	elseif gone < 14 * 86400 then
		return ("%dd ago"):format(math.floor(gone / 86400))
	end
	return ("%dw ago"):format(math.floor(gone / (7 * 86400)))
end









local function colourRow(row, now)
	local rating, ratingTone = "-", "dimmer"
	if row.group == "unrated" then
		rating, ratingTone = "", "dimmer"
		row.tier, row.tierReason = nil, "no-rating"
	elseif row.rating then
		local tier, escape, reason = A.ratingColour(row.format, row.rating)
		row.tier, row.tierReason = tier, reason
		rating = escape and (escape .. tostring(row.rating) .. "|r") or tostring(row.rating)
		ratingTone = "text"
	else
		row.tier, row.tierReason = nil, "no-rating"
	end
	local rate, rateTone = "-", "dimmer"
	if not A.formatHasOutcome(row.format) then
		rate = ""
	elseif row.rate ~= nil then
		rate, rateTone = A.percentPoints(row.rate) .. "%", A.winRateTone(row.rate) or "dim"
	end
	local since = A.finderSince(row.last, now)
	row.cells = { rating, row.record or "-", rate, since or "-" }
	row.tones = { ratingTone, row.record and "text" or "dimmer", rateTone, since and "dim" or "dimmer" }
	row.text = table.concat(row.cells, "   ")
	return row
end




local function worldTally(season, character)
	local db = A.db()
	if not (db and type(db.matches) == "table") then
		return nil
	end
	local kills, deaths, counted = 0, 0, 0
	for i = 1, #db.matches do
		local record = db.matches[i]
		if type(record) == "table" and record.format == "world"
			and (season == nil or A.recordSeason(record) == season)
			and A.recordedBy(record, character)
			and (type(record.kills) == "number" or type(record.deaths) == "number") then
			counted = counted + 1
			kills = kills + (type(record.kills) == "number" and record.kills or 0)
			deaths = deaths + (type(record.deaths) == "number" and record.deaths or 0)
		end
	end
	if counted == 0 then
		return nil
	end
	return ("%d-%d"):format(kills, deaths)
end
























function A.finderRows(prior)
	local rows = {}
	if type(prior) == "table" then
		local now = time()
		for i = 1, #prior do
			local row = {}
			for key, value in pairs(prior[i]) do
				row[key] = value
			end
			rows[i] = colourRow(row, now)
		end
		return rows
	end
	local who = subject()
	local guid = who.guid
	if guid == nil and not who.sandbox then
		return rows
	end
	local season = currentSeason()
	local now = time()
	local tabs = A.tabList(guid)


	local rated, unrated = {}, {}
	for i = 1, #tabs do
		local format = tabs[i].format
		if format ~= nil then
			local summary = A.summarize(format, season, guid)
			if summary.matches > 0 then
				local row = { format = format, label = A.formatLabel(format),
					group = A.movesRating(format) and "rated" or "unrated" }
				if row.group == "rated" and type(summary.rating) == "number" then
					row.rating = summary.rating
				end


				if summary.decided > 0 then
					row.won, row.lost, row.drawn, row.rate = A.winRecord(summary)
					if row.won ~= nil and row.lost ~= nil and row.won + row.lost > 0 then
						row.record = ("%d-%d"):format(row.won, row.lost)
					end
				end

				if format == "world" then
					row.record = worldTally(season, guid)
				end
				local record = A.lastMatch(format, season, guid)
				row.last = record and A.recordEpoch(record) or nil
				local group = row.group == "rated" and rated or unrated
				group[#group + 1] = colourRow(row, now)
			end
		end
	end
	for i = 1, #rated do
		rows[#rows + 1] = rated[i]
	end
	for i = 1, #unrated do
		rows[#rows + 1] = unrated[i]
	end
	return rows
end





local function shownFrame(value)
	if type(value) ~= "table" or type(value.IsShown) ~= "function" then
		return false
	end
	local ok, shown = pcall(value.IsShown, value)
	return ok and shown == true
end

local function hideTip()
	if tip then
		pcall(tip.Hide, tip)
	end
end


local function text(parent, role, justify)
	local fs = parent:CreateFontString(nil, "OVERLAY")
	A.style(fs, role)
	fs:SetJustifyH(justify or "LEFT")
	fs:SetWordWrap(false)
	return fs
end







local function uiRatio(frame)
	local function scaleOf(f)
		if type(f) ~= "table" or type(f.GetEffectiveScale) ~= "function" then
			return nil
		end
		local ok, scale = pcall(f.GetEffectiveScale, f)
		if not ok or not A.canRead(scale) or type(scale) ~= "number" or scale <= 0 then
			return nil
		end
		return scale
	end
	local own, ui = scaleOf(frame), scaleOf(UIParent)
	if own == nil or ui == nil then
		return nil
	end
	return own / ui
end








local function drop(self, cause)
	local from = dragFrom
	dragFrom = nil
	pcall(self.StopMovingOrSizing, self)
	local read = A.frameGeometry(self)
	local ratio = uiRatio(self)
	local point, x, y
	if read and read.point and ratio then
		point, x, y = read.point, read.x * ratio, read.y * ratio
	end
	local kept = "none"
	if point ~= nil and whole(x) ~= nil and whole(y) ~= nil then
		local held = { point = point, x = whole(x), y = whole(y) }
		if from == "session" then
			sessionPosition = held
			kept = "session"
		else
			local db = A.db()
			if db then
				db.ui = db.ui or {}
				db.ui.finderPosition = held
				sessionPosition = nil
				kept = "stored"
			end
		end
	end
	A.trace("finder", {
		state = "moved",

		point = point,
		x = A.unitFigure(x),
		y = A.unitFigure(y),


		kept = kept,
		dockFrom = from,
		source = cause,
	}, "ui")
	schedule("moved")
end



local function dragStart(self)
	local docked, from = A.finderDockState()
	if docked then
		return
	end
	if not pcall(self.StartMoving, self) then
		A.trace("finder", { state = "moved", kept = "none", move = "refused", dockFrom = from }, "ui")
		return
	end
	dragFrom = from
end





local function tipOrNil()
	if tip then
		return tip
	end
	local ok, made = pcall(function()
		local f = CreateFrame("Frame", ADDON .. "FinderTooltip", PVEFrame)
		f:SetFrameStrata("TOOLTIP")
		f:SetClampedToScreen(true)
		f:Hide()
		f.ground = f:CreateTexture(nil, "BACKGROUND")
		f.ground:SetAllPoints(f)
		f.edges = A.cardEdges(f)

		f.rule = f:CreateTexture(nil, "ARTWORK")
		f.rule:Hide()
		f.title = text(f, "cardHead")
		f.scope = text(f, "bodyText", "RIGHT")
		f.heads = {}
		for i = 1, #HEADS do
			f.heads[i] = text(f, "label", "RIGHT")
		end
		f.rows = {}
		f:EnableMouse(false)
		f:SetMovable(false)
		f:RegisterForDrag("LeftButton")
		f:SetScript("OnDragStart", dragStart)
		f:SetScript("OnDragStop", function(self)
			if dragFrom ~= nil then
				drop(self, "stop")
			end
		end)



		f:SetScript("OnHide", function(self)
			if dragFrom ~= nil then
				drop(self, "hide")
			end
		end)
		return f
	end)
	if ok and type(made) == "table" then
		tip = made
	end
	return tip
end


local function rowStrings(f, index)
	local held = f.rows[index]
	if not held then
		held = { name = text(f, "bodyText"), cells = {} }
		for i = 1, #HEADS do
			held.cells[i] = text(f, "numberSmall", "RIGHT")
		end
		f.rows[index] = held
	end
	return held
end










local function layout(f, rows)
	local padX, padY = A.metric("finderPadX"), A.metric("finderPadY")
	local gap, colGap, rowH = A.metric("finderGap"), A.metric("finderColGap"), A.metric("finderRowHeight")

	f.ground:SetColorTexture(A.color("cardPanel"))
	f.ground:Show()
	A.cardOutline(f.edges, f, A.metric("nameCardEdge"), "cardBorder")

	local title, scope = A.finderTitle(), A.finderScope()
	A.style(f.title, "cardHead", "accent")
	f.title:SetText(title)
	A.style(f.scope, "bodyText", "dim")
	f.scope:SetText(scope)

	local widths = { A.metric("finderFormatWidth") }
	for c = 1, #HEADS do
		widths[c + 1] = math.max(A.metric(WIDTHS[c]), A.headerFloor(HEADS[c]))
		A.style(f.heads[c], "label", "dim")
		f.heads[c]:SetText(HEADS[c])
		widths[c + 1] = math.max(widths[c + 1], A.textRoom(f.heads[c], HEADS[c]))
	end


	for i = 1, #rows do
		local held = rowStrings(f, i)
		A.style(held.name, "bodyText", "text")
		held.name:SetText(rows[i].label)
		widths[1] = math.max(widths[1], A.textRoom(held.name, rows[i].label))
		for c = 1, #HEADS do
			local cell = held.cells[c]
			A.style(cell, "numberSmall", rows[i].tones[c] or "text")
			cell:SetText(rows[i].cells[c])
			widths[c + 1] = math.max(widths[c + 1], A.textRoom(cell, rows[i].cells[c]))
		end
	end

	local inner = 0
	for c = 1, #widths do
		inner = inner + widths[c]
	end
	inner = inner + colGap * (#widths - 1)
	local headNeed = A.textRoom(f.title, title) + colGap + A.textRoom(f.scope, scope)
	if headNeed > inner then

		widths[1] = widths[1] + (headNeed - inner)
		inner = headNeed
	end
	local width = inner + 2 * padX

	local headH = math.max(A.fontSize("cardHead"), A.fontSize("bodyText"))
	f.title:ClearAllPoints()
	f.title:SetPoint("TOPLEFT", f, "TOPLEFT", padX, -padY)
	f.title:Show()
	f.scope:ClearAllPoints()
	f.scope:SetPoint("TOPRIGHT", f, "TOPRIGHT", -padX, -padY)
	f.scope:Show()

	local lefts, x = {}, padX
	for c = 1, #widths do
		lefts[c] = x
		x = x + widths[c] + colGap
	end

	local y = padY + headH + gap
	for c = 1, #HEADS do
		local head = f.heads[c]
		head:SetWidth(widths[c + 1])
		head:ClearAllPoints()
		head:SetPoint("TOPLEFT", f, "TOPLEFT", lefts[c + 1], -y)
		head:Show()
	end
	y = y + A.fontSize("label") + gap


	local ruleAfter = nil
	for i = 2, #rows do
		if rows[i - 1].group == "rated" and rows[i].group ~= "rated" then
			ruleAfter = i - 1
		end
	end
	local groupGap = A.metric("finderGroupGap")

	for i = 1, #rows do
		local held = f.rows[i]
		held.name:SetWidth(widths[1])
		held.name:ClearAllPoints()
		held.name:SetPoint("TOPLEFT", f, "TOPLEFT", lefts[1], -y)
		held.name:Show()
		for c = 1, #HEADS do
			local cell = held.cells[c]
			cell:SetWidth(widths[c + 1])
			cell:ClearAllPoints()
			cell:SetPoint("TOPLEFT", f, "TOPLEFT", lefts[c + 1], -y)
			cell:Show()
		end
		y = y + rowH
		if i == ruleAfter then
			y = y + groupGap
			f.rule:SetColorTexture(A.color("cardBorder"))
			f.rule:ClearAllPoints()
			f.rule:SetPoint("TOPLEFT", f, "TOPLEFT", padX, -y)
			f.rule:SetSize(width - 2 * padX, 1)
			f.rule:Show()
			y = y + 1 + groupGap
		end
	end
	if ruleAfter == nil then
		f.rule:Hide()
	end
	f.ruleDrawn = ruleAfter ~= nil
	for i = #rows + 1, #f.rows do
		f.rows[i].name:Hide()
		for c = 1, #HEADS do
			f.rows[i].cells[c]:Hide()
		end
	end
	local height = y + padY

	f:SetSize(width, height)
	return width, height
end







local function sizeOf(frame, getter)
	if type(frame) ~= "table" or type(frame[getter]) ~= "function" then
		return nil
	end
	local ok, size = pcall(frame[getter], frame)
	if not ok or not A.canRead(size) then
		return nil
	end
	if type(size) == "number" and size > 0 then
		return size
	end
	return nil
end










local function screenEdge(frame, which)
	if type(frame) ~= "table" or type(frame[which]) ~= "function"
		or type(frame.GetEffectiveScale) ~= "function" then
		return nil
	end
	local ok, edge = pcall(frame[which], frame)
	if not ok or not A.canRead(edge) or type(edge) ~= "number" then
		return nil
	end
	local okScale, scale = pcall(frame.GetEffectiveScale, frame)
	if not okScale or not A.canRead(scale) or type(scale) ~= "number" or scale <= 0 then
		return nil
	end
	return A.unitFigure(edge * scale)
end













local function placeDocked(tooltip)
	local anchor, check = "above", "unread"
	tooltip:ClearAllPoints()
	tooltip:SetPoint("BOTTOMRIGHT", PVEFrame, "TOPRIGHT", 0, 0)
	tooltip:Show()

	local bottom = screenEdge(tooltip, "GetBottom")
	local top = screenEdge(PVEFrame, "GetTop")
	if bottom ~= nil and top ~= nil and bottom == top then
		check = "clear"
	elseif bottom ~= nil and top ~= nil then
		check = "clamped"
		anchor = "beside"
		tooltip:ClearAllPoints()
		tooltip:SetPoint("TOPLEFT", PVEFrame, "TOPRIGHT", 0, 0)
		tooltip:Show()
	end
	return anchor, check, bottom, top
end





local function takeMouse(tooltip, on)
	pcall(tooltip.SetMovable, tooltip, on)
	pcall(tooltip.EnableMouse, tooltip, on)
end










local function paint(rows)
	local tooltip = tipOrNil()
	if not tooltip then
		return false
	end
	local anchor, check, bottom, top
	local ok, err = pcall(function()
		layout(tooltip, rows)
		local docked = A.finderDockState()
		if docked then

			if dragFrom ~= nil then
				drop(tooltip, "dock")
			end
			takeMouse(tooltip, false)
			anchor, check, bottom, top = placeDocked(tooltip)
			return
		end
		local position = heldPosition()
		local ratio = position and uiRatio(tooltip) or nil
		if position and ratio then
			tooltip:ClearAllPoints()
			tooltip:SetPoint(position.point, UIParent, position.point, position.x / ratio, position.y / ratio)
			tooltip:Show()
			anchor = "placed"
		else
			check, bottom, top = select(2, placeDocked(tooltip))
			anchor = "start"
		end
		takeMouse(tooltip, true)
	end)
	if not ok then
		A.noteError(err, "finder-paint")
		return false
	end
	return true, anchor, check, bottom, top, sizeOf(tooltip, "GetWidth"), sizeOf(tooltip, "GetHeight")
end


local function pass(reason)
	local decision, anchor, check, bottom, top, width, height, via
	local rows = {}
	local on = session == "on" or (session == nil and A.finderEnabled())
	if not on then
		decision = session == "off" and "session-off" or "setting-off"
	elseif not shownFrame(PVEFrame) then
		decision = "closed"
	elseif PVPUIFrame == nil then
		decision = "unloaded"
	elseif not shownFrame(PVPUIFrame) then
		decision = "other-tab"
	else
		local db = A.db()
		local stamp = {
			guid = subject().guid,
			season = currentSeason(),
			db = db,
			matches = db and type(db.matches) == "table" and db.matches or nil,
			count = db and type(db.matches) == "table" and #db.matches or nil,
		}


		local reuse = reason == "rated" or reason == "moved"
		if reuse and walked ~= nil and walked.guid == stamp.guid
			and walked.season == stamp.season and walked.db == stamp.db
			and walked.matches == stamp.matches and walked.count == stamp.count then
			rows, via = A.finderRows(walked.rows), "kept"
		else
			rows = A.finderRows()
			stamp.rows = rows
			walked = stamp
			via = reuse and "walked" or nil
		end
		if #rows == 0 then
			decision = "no-rows"
		else
			local up
			up, anchor, check, bottom, top, width, height = paint(rows)
			decision = up and "shown" or "unbuilt"
		end
	end
	if decision ~= "shown" then
		hideTip()
	end

	local formats, tiers = {}, {}
	local counts = { rated = 0, unrated = 0 }
	for i = 1, #rows do
		formats[i] = rows[i].format
		tiers[i] = rows[i].format .. ":" .. tostring(rows[i].tier or rows[i].tierReason)
		local group = rows[i].group == "rated" and "rated" or "unrated"
		counts[group] = counts[group] + 1
	end
	local groups = {}
	for _, name in ipairs({ "rated", "unrated" }) do
		if counts[name] > 0 then
			groups[#groups + 1] = ("%s:%d"):format(name, counts[name])
		end
	end
	local rule = (decision == "shown" and tip ~= nil and tip.ruleDrawn) and "drawn" or "none"
	local docked, dockFrom = A.finderDockState()
	local dock = docked and "docked" or "undocked"
	last = { decision = decision, anchor = anchor, check = check, bottom = bottom, top = top,
		rows = rows, reason = reason, width = width, height = height,
		groups = #groups > 0 and table.concat(groups, ",") or nil, rule = rule,
		dock = dock, dockFrom = dockFrom }
	A.trace("finder", {
		state = decision,


		dock = dock,
		dockFrom = dockFrom,




		anchor = anchor,
		check = check,


		bottom = bottom,
		top = top,
		rows = #rows,
		formats = #formats > 0 and table.concat(formats, ",") or nil,



		tiers = #tiers > 0 and table.concat(tiers, ",") or nil,



		groups = last.groups,
		rule = rule,
		source = reason,


		via = via,


		width = A.unitFigure(width),
		height = A.unitFigure(height),
	}, "ui")
	return decision
end


schedule = function(reason)
	if pending then
		return
	end
	if not (C_Timer and type(C_Timer.After) == "function") then
		return
	end
	pending = true
	C_Timer.After(0, function()
		pending = false
		local ok, err = pcall(pass, reason)
		if not ok then
			A.noteError(err, "finder-pass")
		end
	end)
end





A.on("PVP_RATED_STATS_UPDATE", function()
	if shownFrame(tip) then
		schedule("rated")
	end
end)


function A.finderHeardRated()
	return A.ratedHeard()
end



function A.finderRecordStored()
	if shownFrame(PVEFrame) then
		schedule("stored")
	end
end





function A.dropFinderWalk()
	walked = nil
	if shownFrame(PVEFrame) then
		schedule("stored")
	end
end





local function install()
	if not finderHooked and type(PVEFrame) == "table" and type(PVEFrame.HookScript) == "function" then
		finderHooked = true
		PVEFrame:HookScript("OnShow", function() schedule("finder-show") end)
		PVEFrame:HookScript("OnHide", function() schedule("finder-hide") end)
	end
	if not showHooked and type(PVEFrame_ShowFrame) == "function"
		and type(hooksecurefunc) == "function" then
		showHooked = true
		hooksecurefunc("PVEFrame_ShowFrame", function() schedule("tab") end)
	end
	if not panelHooked and type(PVPUIFrame) == "table"
		and type(PVPUIFrame.HookScript) == "function" then
		panelHooked = true
		PVPUIFrame:HookScript("OnShow", function() schedule("panel-show") end)
		PVPUIFrame:HookScript("OnHide", function() schedule("panel-hide") end)
	end
end

A.on("PLAYER_LOGIN", function()
	local ok, err = pcall(install)
	if not ok then
		A.noteError(err, "finder-install")
	end
end)

A.on("ADDON_LOADED", function(_, name)
	if name == "Blizzard_PVPUI" or name == "Blizzard_GroupFinder" then
		local ok, err = pcall(install)
		if not ok then
			A.noteError(err, "finder-install")
		end
	end
end)









function A.finderReadout()
	local lines = {
		("finder: setting %s, session %s, PvP panel %s, tooltip %s"):format(
			A.finderEnabled() and "on" or "off",
			session or "none",
			PVPUIFrame ~= nil and "loaded" or "not loaded",
			shownFrame(tip) and "shown" or "hidden"),
		("last pass: %s, anchor %s%s, %d row(s)%s"):format(
			tostring(last.decision), last.anchor or "none",
			last.check and (" (" .. last.check .. ")") or "", #last.rows,
			last.reason and (", after " .. last.reason) or ""),
	}
	lines[#lines + 1] = ("groups: %s"):format(last.groups or "none")
	lines[#lines + 1] = ("rule: %s"):format(last.rule or "none")


	if last.dock ~= nil then
		lines[#lines + 1] = ("dock: %s (%s)"):format(last.dock, tostring(last.dockFrom))
	else
		lines[#lines + 1] = "dock: none"
	end
	local position, held = heldPosition()
	if position then
		lines[#lines + 1] = ("position: %s %d %d (%s)"):format(position.point, position.x, position.y, held)
	else
		lines[#lines + 1] = "position: none"
	end
	lines[#lines + 1] = ("rated info: %s"):format(A.ratedHeard() and "heard" or "not heard yet")
	for i = 1, #last.rows do
		local row = last.rows[i]
		lines[#lines + 1] = ("  %s, %s   %s   tier %s"):format(row.group, row.label, row.text,
			row.tier ~= nil and tostring(row.tier) or ("none (" .. tostring(row.tierReason) .. ")"))
	end
	return lines
end




function A.finderState()
	return last
end


function A.finderTooltip()
	return tip
end
