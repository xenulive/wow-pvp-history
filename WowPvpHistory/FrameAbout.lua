








local _, A = ...


local about



local FACT_ROWS, BEST_ROWS, TILE_COUNT, WEEK_BARS, CHARACTER_ROWS = 3, 6, 4, 26, 6



local FORMAT_TONES = { "regard", "caution", "dim", "ok", "cardLength", "loss", "cardMatches", "alliance" }












function A.aboutFacts()
	local credit = type(A.windowCredit) == "function" and A.windowCredit() or nil
	if type(credit) == "string" then
		credit = credit:gsub("^by%s+", "")
	end
	local function read(value)
		return (type(value) == "string" and value ~= "") and value or "-"
	end
	return {
		name = A.displayName(),
		version = read(A.version),
		description = (type(A.description) == "string" and A.description ~= "") and A.description or nil,
		rows = {
			{ key = "BY", value = read(credit) },
			{ key = "LICENCE", value = read(A.license) },
			{ key = "WEBSITE", value = read(A.website) },
		},
	}
end







function A.aboutDescription(room, measure)
	local text = A.aboutFacts().description
	if text == nil then
		return nil, "withdrawn"
	end
	if type(room) ~= "number" or A.textRoom(measure, text) <= room then
		return text, "whole"
	end
	local head = text:match("^(.-),[^,]*%.$")
	if head == nil or head == "" then
		return text, "whole"
	end
	return head .. ".", "shortened"
end


local function epochOf(stamp)
	return type(stamp) == "string" and A.stampEpoch(stamp) or nil
end


local function counted(n, one, many)
	return ("%d %s"):format(n, n == 1 and one or many)
end







local function bestRating()
	local candidates = {}
	for _, tab in ipairs(A.tabList()) do
		if tab.format ~= nil then
			local ok, summary = pcall(A.summarize, tab.format)
			if ok and type(summary) == "table" and type(summary.peak) == "number" then
				local tier = A.ratingTierName(tab.format, summary.peak)
				local peakAt, rankAt
				for _, point in ipairs(summary.series or {}) do
					local at = epochOf(point.at)
					if at ~= nil and point.rating == summary.peak and (peakAt == nil or at < peakAt.epoch) then
						peakAt = { epoch = at, stamp = point.at }
					end
					if at ~= nil and tier ~= nil and A.ratingTierName(tab.format, point.rating) == tier
						and (rankAt == nil or at < rankAt.epoch) then
						rankAt = { epoch = at, stamp = point.at }
					end
				end
				candidates[#candidates + 1] = { format = tab.format, peak = summary.peak, at = peakAt,
					tier = tier, rankAt = rankAt }
			end
		end
	end
	local best
	for _, held in ipairs(candidates) do
		if best == nil or held.peak > best.peak
			or (held.peak == best.peak and (held.at and held.at.epoch or 0) > (best.at and best.at.epoch or 0)) then
			best = held
		end
	end
	if best == nil then
		return nil, "no-rated-match"
	end
	return best
end








local function longestStreak()
	local db = A.db()
	if not (db and type(db.matches) == "table") then
		return nil, "no-store"
	end
	local items = {}
	for i = 1, #db.matches do
		local record = db.matches[i]
		if type(record) == "table" and record.format ~= nil then
			local at = A.recordEpoch(record)
			if at ~= nil then
				items[#items + 1] = { at = at, record = record, order = i }
			end
		end
	end
	for i, entry in ipairs(A.incompleteList()) do
		local at = A.recordEpoch(entry)
		if at ~= nil then
			items[#items + 1] = { at = at, entry = entry, order = #db.matches + i }
		end
	end

	table.sort(items, function(a, b)
		if a.at ~= b.at then
			return a.at < b.at
		end
		return a.order < b.order
	end)

	local open, best = {}, nil
	local function close(format)
		local run = open[format]
		open[format] = nil
		if run and (best == nil or run.count > best.count or (run.count == best.count and run.at >= best.at)) then
			best = run
		end
	end
	for _, item in ipairs(items) do
		if item.record then
			local format = item.record.format
			if A.recordVerdict(item.record) == "win" then
				local run = open[format] or { format = format, count = 0 }
				run.count = run.count + 1
				run.at = item.at
				run.stamp = item.record.openedAt or item.record.completedAt
				open[format] = run
			else
				close(format)
			end
		elseif item.entry.surfaceFormat ~= nil then
			close(item.entry.surfaceFormat)
		else
			local formats = {}
			for format in pairs(open) do
				formats[#formats + 1] = format
			end
			for _, format in ipairs(formats) do
				close(format)
			end
		end
	end
	local still = {}
	for format in pairs(open) do
		still[#still + 1] = format
	end
	for _, format in ipairs(still) do
		close(format)
	end
	if best == nil then
		return nil, "no-win"
	end
	return best
end




local function mostPlayedMap()
	local rows = A.mapTally(nil)
	if type(rows) ~= "table" or #rows == 0 then
		return nil, "no-map"
	end
	local db = A.db()
	local byId = {}
	for _, record in ipairs((db and db.matches) or {}) do
		if type(record) == "table" and record.id ~= nil then
			byId[record.id] = record
		end
	end
	local function newest(row)
		local at = 0
		for _, id in ipairs(row.ids or {}) do
			local epoch = A.recordEpoch(byId[id])
			if epoch ~= nil and epoch > at then
				at = epoch
			end
		end
		return at
	end
	local best, bestAt
	for _, row in ipairs(rows) do
		local at = newest(row)
		if best == nil or row.played > best.played
			or (row.played == best.played and (at > bestAt or (at == bestAt and row.map < best.map))) then
			best, bestAt = row, at
		end
	end
	return best
end




local function longestMatch()
	local ok, summary = pcall(A.summarize, nil)
	if not (ok and type(summary) == "table" and type(summary.longest) == "number") then
		return nil, "no-duration"
	end
	local db = A.db()
	local held, heldAt
	for _, record in ipairs((db and db.matches) or {}) do
		if type(record) == "table" and record.duration == summary.longest then
			local at = A.recordEpoch(record) or 0
			if held == nil or at >= heldAt then
				held, heldAt = record, at
			end
		end
	end
	if held == nil then
		return nil, "no-duration"
	end
	return held
end


local function shortDay(stamp)
	return type(stamp) == "string" and A.shortDayText(stamp) or nil
end


local function formatDay(format, stamp, word)
	local day = shortDay(stamp)
	local label = A.formatLabel(format)
	if day == nil then
		return label
	end
	return word and ("%s, %s %s"):format(label, word, day) or ("%s, %s"):format(label, day)
end







function A.aboutBests()
	local rows = {}
	local function put(key, label, build)
		local ok, value, why = pcall(build)
		local row = { key = key, label = label }
		if not ok then
			row.withdrawn = "failed"
		elseif type(value) ~= "table" then
			row.withdrawn = why or "none"
		else
			for k, v in pairs(value) do
				row[k] = v
			end
		end
		rows[#rows + 1] = row
	end

	local rating, why = nil, nil
	local okRating = pcall(function()
		rating, why = bestRating()
	end)
	if not okRating then
		why = "failed"
	end

	put("rating", "Highest rating", function()
		if rating == nil then
			return nil, why
		end
		local _, _, _, r, g, b = A.ratingColour(rating.format, rating.peak)
		return { value = tostring(math.floor(rating.peak)), sub = formatDay(rating.format, rating.at and rating.at.stamp),
			rgb = r and { r, g, b } or nil, tone = r == nil and "bright" or nil, format = rating.format }
	end)
	put("rank", "Highest rank", function()
		if rating == nil then
			return nil, why
		end
		if rating.tier == nil then
			return nil, "no-tier"
		end
		local _, _, _, r, g, b = A.ratingColour(rating.format, rating.peak)
		return { value = rating.tier, sub = formatDay(rating.format, rating.rankAt and rating.rankAt.stamp, "reached"),
			rgb = r and { r, g, b } or nil, tone = r == nil and "bright" or nil, word = true }
	end)
	put("streak", "Longest win streak", function()
		local run, reason = longestStreak()
		if run == nil then
			return nil, reason
		end
		return { value = tostring(run.count), sub = formatDay(run.format, run.stamp), tone = "bright" }
	end)
	put("met", "Most met", function()
		local view = A.playersView({ sort = "met" })
		local row = view and view.rows and view.rows[1]
		if row == nil or (row.met or 0) < 1 then
			return nil, "no-player-met"
		end

		return { value = tostring(row.identity.bare), sub = counted(row.met, "time", "times"),
			traced = row.met, classToken = row.identity.classToken, word = true }
	end)
	put("map", "Most played map", function()
		local row, reason = mostPlayedMap()
		if row == nil then
			return nil, reason
		end
		return { value = row.map, sub = counted(row.played, "match", "matches"), tone = "bright", word = true }
	end)
	put("length", "Longest match", function()
		local record, reason = longestMatch()
		if record == nil then
			return nil, reason
		end
		local map = type(record.map) == "table" and record.map.name or nil
		local day = shortDay(record.openedAt or record.completedAt)
		local sub = (map and day) and ("%s, %s"):format(map, day) or map or day
		return { value = A.lengthText(record.duration), sub = sub, tone = "bright" }
	end)
	return rows
end



function A.aboutSinceLine(stamp, now)
	local at = epochOf(stamp)
	if at == nil then
		return nil
	end
	now = type(now) == "number" and now or time()
	local okDate, text = pcall(function()
		local y, m, d = stamp:match("^(%d+)%-(%d+)%-(%d+)")
		local noon = time({ year = tonumber(y), month = tonumber(m), day = tonumber(d), hour = 12 })
		local today = date("*t", now)
		local todayNoon = time({ year = today.year, month = today.month, day = today.day, hour = 12 })
		local days = math.floor((todayNoon - noon) / 86400 + 0.5)
		return ("since %s %d %s, %s"):format(date("%A", noon), tonumber(date("%d", noon)), date("%B", noon),
			counted(days, "day", "days"))
	end)
	return okDate and text or nil
end









function A.aboutWeeks(now, room)
	now = type(now) == "number" and now or time()
	local db = A.db()
	if not (db and type(db.matches) == "table") then
		return nil, "no-store"
	end
	local counts, first, undated, seen = {}, nil, 0, 0
	local function add(item)
		seen = seen + 1
		local at = A.recordEpoch(item)
		local monday = at and A.weekOpening(at) or nil
		if monday == nil then
			undated = undated + 1
			return
		end
		counts[monday] = (counts[monday] or 0) + 1
		if first == nil or monday < first then
			first = monday
		end
	end
	for i = 1, #db.matches do
		local record = db.matches[i]
		if type(record) == "table" and record.format ~= nil then
			add(record)
		end
	end
	for _, entry in ipairs(A.incompleteList()) do
		add(entry)
	end
	if seen == 0 then
		return nil, "no-match", 0
	end
	if first == nil then
		return nil, "no-dated-match", undated
	end

	local current = A.weekOpening(now)
	local bars = {}
	local monday = first


	while monday ~= nil and monday <= current and #bars < 600 do
		bars[#bars + 1] = { monday = monday, count = counts[monday] or 0, current = monday == current,
			label = A.weekDayLabel(monday) }
		monday = A.weekOpening(monday + 7 * 86400 + 43200)
	end
	local dropped = 0
	room = type(room) == "number" and math.max(math.floor(room), 1) or #bars
	while #bars > room do
		table.remove(bars, 1)
		dropped = dropped + 1
	end
	return bars, dropped, undated
end


function A.weekDayLabel(monday)
	if type(monday) ~= "number" then
		return nil
	end
	return ("%d %s"):format(tonumber(date("%d", monday)), date("%b", monday))
end




function A.aboutCharacters()
	local db = A.db()
	local rows = {}
	for _, held in ipairs(A.characterList()) do
		local classToken, newest = nil, nil
		for _, record in ipairs((db and db.matches) or {}) do
			local row = type(record) == "table" and record.character == held.guid
				and type(record.participants) == "table" and record.participants[held.guid] or nil
			if type(row) == "table" and type(row.classToken) == "string" then
				local at = A.recordEpoch(record) or 0
				if newest == nil or at >= newest then
					classToken, newest = row.classToken, at
				end
			end
		end
		local spec
		local okSpec, specs = pcall(A.playedSpecs, nil, held.guid)
		if okSpec and type(specs) == "table" and specs[1] then
			spec = specs[1].spec
		end
		rows[#rows + 1] = { name = held.unresolved and held.label or held.name, classToken = classToken,
			spec = spec, total = held.total }
	end
	return rows
end




function A.aboutFormats()
	local segments, other = {}, nil
	local left = #A.incompleteList()
	for _, tab in ipairs(A.tabList()) do
		if tab.format == "unknown" then
			other = { format = "unknown", label = tab.label, count = tab.matches + left }
		elseif tab.format ~= nil then
			segments[#segments + 1] = { format = tab.format, label = tab.label, count = tab.matches }
		end
	end
	if other == nil and left > 0 then
		other = { format = "unknown", label = A.formatLabel("unknown"), count = left }
	end

	table.sort(segments, function(a, b)
		if a.count ~= b.count then
			return a.count > b.count
		end
		return a.label < b.label
	end)
	for i, segment in ipairs(segments) do
		segment.tone = FORMAT_TONES[(i - 1) % #FORMAT_TONES + 1]
	end
	if other then
		other.tone = "dimmer"
		segments[#segments + 1] = other
	end
	return segments
end





local function text(parent, justify)
	local held = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	held:SetJustifyH(justify or "LEFT")
	held:SetWordWrap(false)
	return held
end


local function texture(parent, layer)
	return parent:CreateTexture(nil, layer or "ARTWORK")
end


local function addSegment(half)
	local i = #half.segments + 1
	half.segments[i] = texture(half)
	half.segments[i]:SetHeight(A.metric("aboutFormatBar"))
	local entry = {}
	entry.swatch = texture(half)
	entry.swatch:SetSize(10, 10)
	entry.label = text(half)
	entry.count = text(half)
	half.legend[i] = entry
end



local function buildLeft(frame)
	local half = CreateFrame("Frame", nil, frame)
	half:Show()
	half.ground = texture(half, "BACKGROUND")
	half.ground:SetAllPoints(half)
	half.rule = texture(half, "BORDER")
	half.rule:SetPoint("TOPRIGHT", half, "TOPRIGHT", 0, 0)
	half.rule:SetPoint("BOTTOMRIGHT", half, "BOTTOMRIGHT", 0, 0)
	half.rule:SetWidth(1)

	half.icon = texture(half)
	half.icon:SetSize(A.metric("aboutIcon"), A.metric("aboutIcon"))
	half.icon:SetTexture(A.ICON_TEXTURE)
	half.name = text(half)
	half.version = text(half)
	half.description = text(half)

	half.rows = {}
	for i = 1, FACT_ROWS do
		local row = {}
		row.key = text(half)
		row.value = text(half)
		row.realm = text(half)
		row.rule = texture(half, "BORDER")
		row.rule:SetHeight(1)
		half.rows[i] = row
	end
	half.copy = A.pill(half, "Copy link", function()
		A.aboutCopyLink()
	end, A.metric("pillMin"))

	half.bestsHeading = text(half)
	half.bestsHeading:SetText("YOUR BESTS")
	half.bests = {}
	for i = 1, BEST_ROWS do
		local row = {}
		row.label = text(half)
		row.sub = text(half)
		row.value = text(half, "RIGHT")
		row.rule = texture(half, "BORDER")
		row.rule:SetHeight(1)
		half.bests[i] = row
	end
	frame.left = half
	return half
end



local function buildRight(frame)
	local half = CreateFrame("Frame", nil, frame)
	half:Show()
	half.heading = text(half)
	half.heading:SetText("YOUR HISTORY")
	half.since = text(half, "RIGHT")

	half.tiles = {}
	for i = 1, TILE_COUNT do
		local tile = CreateFrame("Frame", nil, half)
		tile.ground = texture(tile, "BACKGROUND")
		tile.ground:SetAllPoints(tile)
		tile.edges = {}
		for _, side in ipairs({ "TOP", "BOTTOM" }) do
			local edge = texture(tile, "BORDER")
			edge:SetPoint(side .. "LEFT", tile, side .. "LEFT", 0, 0)
			edge:SetPoint(side .. "RIGHT", tile, side .. "RIGHT", 0, 0)
			edge:SetHeight(1)
			tile.edges[#tile.edges + 1] = edge
		end
		for _, side in ipairs({ "LEFT", "RIGHT" }) do
			local edge = texture(tile, "BORDER")
			edge:SetPoint("TOP" .. side, tile, "TOP" .. side, 0, 0)
			edge:SetPoint("BOTTOM" .. side, tile, "BOTTOM" .. side, 0, 0)
			edge:SetWidth(1)
			tile.edges[#tile.edges + 1] = edge
		end
		tile.key = text(tile)
		tile.figure = text(tile)
		tile.sub = text(tile)
		half.tiles[i] = tile
	end

	half.weekHeading = text(half)
	half.weekHeading:SetText("MATCHES BY WEEK")
	half.weekNote = text(half, "RIGHT")
	half.weekNote:SetText("weeks starting Monday")
	half.weeks = {}
	for i = 1, WEEK_BARS do
		local bar = {}
		bar.count = text(half, "CENTER")
		bar.fill = texture(half)
		bar.label = text(half, "CENTER")
		half.weeks[i] = bar
	end

	half.characterHeading = text(half)
	half.characterHeading:SetText("BY CHARACTER")
	half.characters = {}
	for i = 1, CHARACTER_ROWS do
		local row = {}
		row.name = text(half)
		row.spec = text(half)
		row.track = texture(half)
		row.track:SetHeight(A.metric("aboutCharBar"))
		row.fill = texture(half, "OVERLAY")
		row.fill:SetHeight(A.metric("aboutCharBar"))
		row.count = text(half, "RIGHT")
		half.characters[i] = row
	end

	half.formatHeading = text(half)
	half.formatHeading:SetText("BY FORMAT")


	half.segments, half.legend = {}, {}
	for _ = 1, #A.formatLabelList() do
		addSegment(half)
	end

	half.sizeKey = text(half)
	half.sizeKey:SetText("SIZE")
	half.sizeValue = text(half)
	frame.right = half
	return half
end



local function buildAbout(host)
	local frame = CreateFrame("Frame", "WowPvpHistoryAboutFrame", host)
	frame:SetAllPoints(host)

	frame:Show()
	local builtLeft = pcall(buildLeft, frame)
	local builtRight = pcall(buildRight, frame)
	frame.built = { left = builtLeft, right = builtRight }
	return frame
end


local function aboutOrNil()
	if about then
		return about
	end
	if type(CreateFrame) ~= "function" then
		return nil
	end
	local host = type(A.windowPageHost) == "function" and A.windowPageHost("about") or nil
	if not host then
		return nil
	end
	about = A.buildWindowOnce("about", buildAbout, host)
	return about
end


local function at(widget, half, x, y)
	widget:ClearAllPoints()
	widget:SetPoint("TOPLEFT", half, "TOPLEFT", x, -y)
end


local function paintLeft(half, width)
	local facts = A.aboutFacts()
	local pad = A.metric("aboutPad")
	local inner = width - pad * 2
	half:ClearAllPoints()
	half:SetPoint("TOPLEFT", about, "TOPLEFT", 0, 0)
	half:SetPoint("BOTTOMLEFT", about, "BOTTOMLEFT", 0, 0)
	half:SetWidth(width)
	half.ground:SetColorTexture(A.color("panelDeep"))
	half.rule:SetColorTexture(A.color("hairline"))

	local y = pad
	at(half.icon, half, pad, y)
	half.icon:Show()
	local nameX = pad + A.metric("aboutIcon") + A.metric("aboutGap")
	A.style(half.name, "dossierName", "accent")
	half.name:SetText(facts.name)
	at(half.name, half, nameX, y + 10)
	A.style(half.version, "numberSmall", "dim")
	half.version:SetText(facts.version)
	at(half.version, half, nameX, y + 10 + A.fontSize("dossierName") + 2)
	y = y + A.metric("aboutIcon") + A.metric("aboutGap")

	A.style(half.description, "bodyText", "text")
	local line, how = A.aboutDescription(inner, half.description)
	if line then
		half.description:SetText(line)
		at(half.description, half, pad, y)
		half.description:SetWidth(inner)
		half.description:Show()
		y = y + A.fontSize("bodyText") + A.metric("aboutGap")
	else
		half.description:SetText("")
		half.description:Hide()
	end

	local keyWidth = A.metric("aboutKeyColumn")
	local rowH = A.metric("aboutFactRow")
	for i, row in ipairs(half.rows) do
		local held = facts.rows[i]
		A.style(row.key, "label", "dim")
		row.key:SetText(held and held.key or "")
		at(row.key, half, pad, y + (rowH - A.fontSize("label")) / 2)
		A.style(row.value, "bodyText", "text")
		row.realm:SetText("")
		local value = held and held.value or ""
		if held and held.key == "BY" then

			local name, realm = value:match("^([^%-]+)(%-.+)$")
			row.value:SetText(name or value)
			row.value:SetTextColor(A.classColor(type(A.windowCreditClass) == "function" and A.windowCreditClass() or nil))
			A.style(row.realm, "bodyText", "dim")
			row.realm:SetText(realm or "")
			row.realm:ClearAllPoints()
			row.realm:SetPoint("LEFT", row.value, "RIGHT", 0, 0)
		else
			row.value:SetText(value)
		end
		at(row.value, half, pad + keyWidth, y + (rowH - A.fontSize("bodyText")) / 2)
		row.rule:SetColorTexture(A.color("divider"))
		row.rule:ClearAllPoints()
		row.rule:SetPoint("TOPLEFT", half, "TOPLEFT", pad, -(y + rowH))
		row.rule:SetPoint("TOPRIGHT", half, "TOPRIGHT", -pad, -(y + rowH))
		if held and held.key == "WEBSITE" then
			half.copy:ClearAllPoints()
			half.copy:SetPoint("RIGHT", half, "TOPRIGHT", -pad, -(y + rowH / 2))
			if value ~= "-" then
				half.copy:Enable()
			else
				half.copy:Disable()
			end
			half.websiteRow = row
		end
		y = y + rowH
	end

	y = y + A.metric("aboutGap")
	A.style(half.bestsHeading, "label", "dim")
	at(half.bestsHeading, half, pad, y)
	y = y + A.fontSize("label") + 8


	local bests = A.aboutBests()
	local shown = {}
	for _, held in ipairs(bests) do
		if held.value ~= nil then
			shown[#shown + 1] = held
		end
	end
	local drawn = 0
	local bestH = A.metric("aboutBestRow")
	for i, row in ipairs(half.bests) do
		local held = shown[i]
		if held and held.value ~= nil then
			A.style(row.label, "cardLabel", "dim")
			row.label:SetText(held.label)
			at(row.label, half, pad, y + 4)
			A.style(row.sub, "rowNote", "dimmer")
			row.sub:SetText(held.sub or "")
			at(row.sub, half, pad, y + 4 + A.fontSize("cardLabel") + 2)
			A.style(row.value, held.word and "cardName" or "number", held.tone or "bright")
			if held.rgb then
				row.value:SetTextColor(held.rgb[1], held.rgb[2], held.rgb[3])
			elseif held.classToken then
				row.value:SetTextColor(A.classColor(held.classToken))
			end
			row.value:SetText(held.value)
			row.value:ClearAllPoints()
			row.value:SetPoint("RIGHT", half, "TOPRIGHT", -pad, -(y + bestH / 2))
			row.rule:SetColorTexture(A.color("divider"))
			row.rule:ClearAllPoints()
			row.rule:SetPoint("TOPLEFT", half, "TOPLEFT", pad, -(y + bestH))
			row.rule:SetPoint("TOPRIGHT", half, "TOPRIGHT", -pad, -(y + bestH))
			for _, part in ipairs({ row.label, row.sub, row.value, row.rule }) do
				part:Show()
			end
			drawn = drawn + 1
			y = y + bestH
		else
			for _, part in ipairs({ row.label, row.sub, row.value, row.rule }) do
				part:Hide()
			end
			row.label:SetText("")
			row.value:SetText("")
		end
	end
	half.bestsHeading:SetShown(drawn > 0)
	return how, bests
end


local function paintRight(half, x, width)
	local pad = A.metric("aboutPad")
	local inner = width - pad * 2
	local gap = A.metric("aboutGap")
	local drew = {}
	half:ClearAllPoints()
	half:SetPoint("TOPLEFT", about, "TOPLEFT", x, 0)
	half:SetPoint("BOTTOMRIGHT", about, "BOTTOMRIGHT", 0, 0)

	local figures = A.historyFigures()
	local by = {}
	for _, row in ipairs(figures) do
		by[row.key] = row
	end
	drew.figures = figures

	local y = pad
	A.style(half.heading, "label", "dim")
	at(half.heading, half, pad, y)
	local first = by["FIRST MATCH"]
	local since = first and first.stamp and A.aboutSinceLine(first.stamp) or nil
	A.style(half.since, "cardLabel", "dim")
	half.since:SetText(since or "")
	half.since:ClearAllPoints()
	half.since:SetPoint("TOPRIGHT", half, "TOPRIGHT", -pad, -y)
	y = y + A.fontSize("label") + gap


	local tileGap = A.metric("aboutTileGap")
	local tileW = math.floor((inner - tileGap * (TILE_COUNT - 1)) / TILE_COUNT)
	local tileH = A.metric("aboutTile")
	local keys = { "MATCHES", "PLAYERS MET", "NOTES WRITTEN", "CHARACTERS" }
	local tiles = {}
	for i, tile in ipairs(half.tiles) do
		local held = by[keys[i]]
		tile:ClearAllPoints()
		tile:SetPoint("TOPLEFT", half, "TOPLEFT", pad + (i - 1) * (tileW + tileGap), -y)
		tile:SetSize(tileW, tileH)
		tile.ground:SetColorTexture(A.color("panelDeep"))
		for _, edge in ipairs(tile.edges) do
			edge:SetColorTexture(A.color("hairline"))
		end
		A.style(tile.key, "label", "dim")
		tile.key:SetText(keys[i])
		at(tile.key, tile, 12, 10)
		A.style(tile.figure, "numberHuge", keys[i] == "NOTES WRITTEN" and "noteWord" or "text")
		A.style(tile.sub, "cardLabel", "dim")
		if held and held.value ~= nil then
			tile.figure:SetText(held.value)
			tile.sub:SetText(held.sub or "")
			tile:Show()
			tiles[#tiles + 1] = ("%s=%s"):format(keys[i]:lower():gsub(" ", "_"), held.value)
		else
			tile.figure:SetText("")
			tile.sub:SetText("")
			tile:Hide()
		end
		at(tile.figure, tile, 12, 10 + A.fontSize("label") + 2)
		at(tile.sub, tile, 12, 10 + A.fontSize("label") + 2 + A.fontSize("numberHuge") + 2)
	end
	drew.tiles = table.concat(tiles, " ")
	y = y + tileH + gap


	A.style(half.weekHeading, "label", "dim")
	at(half.weekHeading, half, pad, y)
	A.style(half.weekNote, "rowNote", "dim")
	half.weekNote:ClearAllPoints()
	half.weekNote:SetPoint("TOPRIGHT", half, "TOPRIGHT", -pad, -y)
	y = y + A.fontSize("label") + 8
	local barGap = A.metric("aboutWeekGap")
	local room = math.max(math.floor((inner + barGap) / (A.metric("aboutWeekMin") + barGap)), 1)
	room = math.min(room, WEEK_BARS)
	local bars, dropped, undated = A.aboutWeeks(nil, room)
	local chart = A.metric("aboutWeekChart")
	local labelH = A.fontSize("rowNote")
	local countH = A.fontSize("numberMicro")
	local track = chart - labelH - countH - 8
	if type(bars) == "table" then
		local most = 1
		for _, bar in ipairs(bars) do
			most = math.max(most, bar.count)
		end
		local barW = math.floor((inner - barGap * (#bars - 1)) / #bars)
		for i, slot in ipairs(half.weeks) do
			local bar = bars[i]
			if bar then
				local bx = pad + (i - 1) * (barW + barGap)
				local h = bar.count > 0 and math.max(math.floor(track * bar.count / most + 0.5), 1) or 0
				local foot = y + chart - labelH - 4
				A.style(slot.label, "rowNote", "dim")
				slot.label:SetText(bar.label or "")
				slot.label:SetWidth(barW)
				at(slot.label, half, bx, foot + 4)
				A.style(slot.count, "numberMicro", "dim")
				slot.count:SetText(tostring(bar.count))
				slot.count:SetWidth(barW)
				at(slot.count, half, bx, foot - h - countH - 2)
				if h > 0 then
					local r, g, b = A.color("accent")
					slot.fill:SetColorTexture(r, g, b, bar.current and 1 or 0.45)
					slot.fill:SetSize(barW, h)
					at(slot.fill, half, bx, foot - h)
					slot.fill:Show()
				else
					slot.fill:Hide()
				end
				slot.label:Show()
				slot.count:Show()
				slot.monday = bar.monday
				slot.current = bar.current
			else
				slot.fill:Hide()
				slot.label:Hide()
				slot.count:Hide()
				slot.label:SetText("")
				slot.count:SetText("")
				slot.monday, slot.current = nil, nil
			end
		end
		drew.weeks = #bars
		drew.firstWeek = bars[1] and bars[1].label or nil
		drew.lastWeek = bars[#bars] and bars[#bars].label or nil
		drew.dropped = dropped
		drew.undated = undated
		half.weekHeading:Show()
		half.weekNote:Show()
		y = y + chart + gap
	else
		for _, slot in ipairs(half.weeks) do
			slot.fill:Hide()
			slot.label:Hide()
			slot.count:Hide()
		end
		drew.weeks = 0
		drew.weeksWithdrawn = dropped
		drew.undated = undated
		half.weekHeading:Hide()
		half.weekNote:Hide()
	end



	local characters = A.aboutCharacters()
	local largest = 1
	for _, held in ipairs(characters) do
		largest = math.max(largest, held.total)
	end
	local nameW = A.metric("aboutCharName")
	local countW = A.metric("aboutCharCount")
	local barX = pad + nameW + 10
	local barW = math.max(inner - nameW - countW - 20, 1)
	local charH = A.metric("aboutCharRow")
	half.characterHeading:SetShown(#characters > 0)
	if #characters > 0 then
		A.style(half.characterHeading, "label", "dim")
		at(half.characterHeading, half, pad, y)
		y = y + A.fontSize("label") + 6
	end
	local charDrawn = 0
	for i, row in ipairs(half.characters) do
		local held = characters[i]
		if held then
			A.style(row.name, "cardText", "text")
			row.name:SetTextColor(A.classColor(held.classToken))
			row.name:SetText(held.name or "")
			at(row.name, half, pad, y + (charH - A.fontSize("cardText")) / 2)
			A.style(row.spec, "rowNote", "dim")
			row.spec:SetText(held.spec or "")
			row.spec:ClearAllPoints()
			row.spec:SetPoint("BOTTOMLEFT", row.name, "BOTTOMRIGHT", 6, 0)
			row.track:SetColorTexture(A.color("divider"))
			row.track:SetWidth(barW)
			at(row.track, half, barX, y + (charH - A.metric("aboutCharBar")) / 2)
			local r, g, b = A.classColor(held.classToken)
			row.fill:SetColorTexture(r, g, b, 0.8)
			row.fill:SetWidth(math.max(math.floor(barW * held.total / largest + 0.5), 1))
			at(row.fill, half, barX, y + (charH - A.metric("aboutCharBar")) / 2)
			A.style(row.count, "numberSmall", "text")
			row.count:SetText(tostring(held.total))
			row.count:ClearAllPoints()
			row.count:SetPoint("RIGHT", half, "TOPRIGHT", -pad, -(y + charH / 2))
			for _, part in ipairs({ row.name, row.spec, row.track, row.fill, row.count }) do
				part:Show()
			end
			charDrawn = charDrawn + 1
			y = y + charH
		else
			for _, part in ipairs({ row.name, row.spec, row.track, row.fill, row.count }) do
				part:Hide()
			end
			row.name:SetText("")
			row.count:SetText("")
		end
	end
	drew.chars = charDrawn
	if charDrawn > 0 then
		y = y + gap
	end


	local segments = A.aboutFormats()
	local total, handed = 0, 0
	for _, segment in ipairs(segments) do
		total = total + segment.count
		if segment.count > 0 then
			handed = handed + 1
		end
	end
	for _ = #half.segments + 1, #segments do
		addSegment(half)
	end
	half.formatHeading:SetShown(total > 0)
	local segDrawn = 0
	if total > 0 then
		A.style(half.formatHeading, "label", "dim")
		at(half.formatHeading, half, pad, y)
		y = y + A.fontSize("label") + 8
	end
	local sx = pad
	local legendX, legendY = pad, y + A.metric("aboutFormatBar") + 8
	for i, part in ipairs(half.segments) do
		local segment = segments[i]
		local entry = half.legend[i]
		if segment and total > 0 and segment.count > 0 then
			local w = math.max(math.floor(inner * segment.count / total + 0.5) - 2, 1)
			part:SetColorTexture(A.color(segment.tone))
			part:SetWidth(w)
			at(part, half, sx, y)
			part:Show()
			sx = sx + w + 2
			entry.swatch:SetColorTexture(A.color(segment.tone))
			A.style(entry.label, "cardLabel", "text")
			entry.label:SetText(segment.label)
			A.style(entry.count, "numberMicro", "dim")
			entry.count:SetText(tostring(segment.count))
			local need = 16 + A.textRoom(entry.label, segment.label) + 6 + A.textRoom(entry.count, tostring(segment.count))
			if legendX > pad and legendX + need > pad + inner then
				legendX, legendY = pad, legendY + A.fontSize("cardLabel") + 6
			end
			at(entry.swatch, half, legendX, legendY + 2)
			at(entry.label, half, legendX + 16, legendY)
			entry.count:ClearAllPoints()
			entry.count:SetPoint("LEFT", entry.label, "RIGHT", 6, 0)
			for _, piece in ipairs({ entry.swatch, entry.label, entry.count }) do
				piece:Show()
			end
			legendX = legendX + need + 16
			segDrawn = segDrawn + 1
			part.format, part.count, part.tone = segment.format, segment.count, segment.tone
		else
			part:Hide()
			for _, piece in ipairs({ entry.swatch, entry.label, entry.count }) do
				piece:Hide()
			end
			entry.label:SetText("")
			part.format, part.count, part.tone = nil, nil, nil
		end
	end
	drew.segments = segDrawn
	drew.handed = handed
	if segDrawn > 0 then
		y = legendY + A.fontSize("cardLabel") + gap
	end


	local size = by.SIZE
	if size and size.value ~= nil then
		A.style(half.sizeKey, "label", "dim")
		at(half.sizeKey, half, pad, y)
		A.style(half.sizeValue, "bodyText", "text")
		half.sizeValue:SetText(size.value)
		at(half.sizeValue, half, pad + A.metric("aboutKeyColumn"), y)
		half.sizeKey:Show()
		half.sizeValue:Show()
	else
		half.sizeValue:SetText("")
		half.sizeKey:Hide()
		half.sizeValue:Hide()
	end
	return drew
end








function A.paintAboutBody(width)
	if not about then
		return false
	end
	width = type(width) == "number" and width or (type(A.windowWidth) == "function" and A.windowWidth()) or 900
	local body = width - A.metric("margin") * 2
	local leftW = math.min(A.metric("aboutLeft"), math.floor(body / 2))
	about.bodyWidth = body

	local leftOk, how, bests = false, nil, nil
	if about.left then
		leftOk, how, bests = pcall(paintLeft, about.left, leftW)
	end
	local rightOk, drew = false, nil
	if about.right then
		rightOk, drew = pcall(paintRight, about.right, leftW, body - leftW)
	end

	local bestWords = {}
	if leftOk and type(bests) == "table" then
		for _, row in ipairs(bests) do
			if row.value ~= nil then
				local shown = row.traced
				if shown == nil then
					shown = row.value
				end
				bestWords[#bestWords + 1] = ("%s=%s"):format(row.key, tostring(shown))
			else
				bestWords[#bestWords + 1] = ("%s:%s"):format(row.key, tostring(row.withdrawn))
			end
		end
	end
	local withdrawn = {}
	if rightOk and type(drew) == "table" then
		for _, held in ipairs(drew.figures or {}) do
			if held.value == nil then
				withdrawn[#withdrawn + 1] = ("%s:%s"):format(held.key:gsub(" ", "_"), tostring(held.withdrawn))
			end
		end
		if drew.weeks == 0 then
			withdrawn[#withdrawn + 1] = "WEEKS:" .. tostring(drew.weeksWithdrawn)
		end
	end
	drew = rightOk and drew or {}
	A.trace("about", {
		state = (leftOk and rightOk) and "painted" or (leftOk and "right-failed")
			or (rightOk and "left-failed") or "failed",
		bests = table.concat(bestWords, " "),
		tiles = drew.tiles,
		weeks = drew.weeks,
		firstWeek = drew.firstWeek,
		lastWeek = drew.lastWeek,
		dropped = drew.dropped,
		undated = drew.undated,
		chars = drew.chars,
		segments = drew.segments,

		handed = drew.handed,
		withdrawn = table.concat(withdrawn, " "),
		note = leftOk and how or nil,
	}, "ui")
	return leftOk or rightOk
end




function A.aboutCopyLink()
	local site = A.aboutFacts().rows[3].value
	local opened = site ~= "-" and A.showCopyBox(about, "Website", "Ctrl+C copies the address; paste it into a browser.",
		site) or false
	A.trace("about", { state = "copy", copy = opened and true or false }, "ui")
	return opened
end



function A.showAboutBody()
	if not aboutOrNil() then
		return false
	end
	return type(A.showWindowBody) == "function" and A.showWindowBody("about") or false
end
