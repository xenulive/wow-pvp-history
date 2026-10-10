







local _, A = ...

local ADDON_PATH = "Interface\\AddOns\\WowPvpHistory\\"





local FLAT = {
	panel       = { 0.090, 0.102, 0.122 },
	panelDeep   = { 0.071, 0.082, 0.102 },


	sessionGround = { 0.102, 0.114, 0.137 },
	titleBar    = { 0.118, 0.133, 0.161 },
	field       = { 0.059, 0.071, 0.086 },
	hairline    = { 1, 1, 1, 0.09 },
	divider     = { 1, 1, 1, 0.05 },

	bright      = { 0.953, 0.961, 0.969 },
	text        = { 0.902, 0.910, 0.925 },
	dim         = { 0.541, 0.573, 0.612 },
	dimmer      = { 0.357, 0.384, 0.420 },
	faint       = { 0.239, 0.263, 0.290 },

	accent      = { 1, 0.820, 0 },
	win         = { 0.310, 0.780, 0.470 },
	loss        = { 0.880, 0.360, 0.340 },


	horde       = { 0.784, 0.180, 0.220 },
	alliance    = { 0.380, 0.600, 0.960 },


	cardMatches = { 0.435, 0.659, 0.863 },

	cardLength  = { 0.659, 0.545, 0.878 },


	caution     = { 0.784, 0.514, 0.306 },



	regard      = { 0.290, 0.678, 0.780 },


	noteWord    = { 0.851, 0.682, 0.235 },


	caveat      = { 1, 0.624, 0.227 },



	savedGround = { 0.047, 0.157, 0.086, 0.88 },



	fault       = { 1, 0.353, 0.353 },
	standing    = { 0.784, 0.643, 0.361 },

	routine     = { 0.541, 0.573, 0.612 },

	event       = { 0.902, 0.910, 0.925 },
	ok          = { 0.373, 0.812, 0.502 },

	selection   = { 1, 0.820, 0, 0.16 },
	hover       = { 1, 1, 1, 0.055 },




	inset       = { 0.071, 0.082, 0.102 },
	insetEdge   = { 1, 1, 1, 0.09 },
	insetDeep   = { 0, 0, 0, 0 },
	listGround  = { 0, 0, 0, 0 },
	listEdge    = { 0, 0, 0, 0 },


	pinGround   = { 0.090, 0.102, 0.122 },

	label       = { 0.541, 0.573, 0.612 },

	labelMuted  = { 0.541, 0.573, 0.612 },
	sessionRule = { 1, 1, 1, 0.09 },
	gridRule    = { 0, 0, 0, 0 },
	sessionOpen = { 0.102, 0.114, 0.137 },


	underText   = { 0.357, 0.384, 0.420 },
	underWin    = { 0.310, 0.780, 0.470, 0.30 },
	underLoss   = { 0.880, 0.360, 0.340, 0.30 },
	barMid      = { 1, 1, 1, 0.25 },


	heatLoss    = { 0.878, 0.361, 0.341 },
	heatMid     = { 0.165, 0.180, 0.208 },
	heatWin     = { 0.310, 0.780, 0.471 },
	heatBlank   = { 1, 1, 1, 0.10 },


	tierBand    = { 1, 1, 1, 0.045 },
	tierRule    = { 1, 1, 1, 0.50 },


	cardGround  = { 0, 0, 0, 0 },



	menuGround  = { 0.071, 0.082, 0.102, 1 },



	cardPanel   = { 0.059, 0.071, 0.086, 0.96 },
	cardBorder  = { 1, 1, 1, 0.14 },
	chipEdge    = { 1, 1, 1, 0.14 },
	chipText    = { 0.765, 0.784, 0.812 },



	chat        = "00ff00",
	link        = "ffd100",
}



local BLIZZARD = {}
for name, value in pairs(FLAT) do
	BLIZZARD[name] = value
end


BLIZZARD.panel     = { 0, 0, 0, 0 }
BLIZZARD.panelDeep = { 0, 0, 0, 0.25 }
BLIZZARD.sessionGround = { 0, 0, 0, 0 }
BLIZZARD.titleBar  = { 0, 0, 0, 0 }
BLIZZARD.field     = { 0, 0, 0, 0.45 }

BLIZZARD.hairline  = { 1, 1, 1, 0.12 }
BLIZZARD.divider   = { 1, 1, 1, 0.07 }
BLIZZARD.selection = { 1, 0.820, 0, 0.20 }
BLIZZARD.hover     = { 1, 1, 1, 0.10 }

BLIZZARD.inset       = { 0, 0, 0, 0.38 }
BLIZZARD.insetEdge   = { 1, 0.820, 0, 0.22 }
BLIZZARD.insetDeep   = { 0, 0, 0, 0.18 }
BLIZZARD.listGround  = { 0, 0, 0, 0.38 }
BLIZZARD.listEdge    = { 1, 0.820, 0, 0.22 }
BLIZZARD.pinGround   = { 0, 0, 0, 0.45 }
BLIZZARD.label       = { 1, 0.820, 0 }
BLIZZARD.labelMuted  = { 0.702, 0.604, 0.180 }
BLIZZARD.sessionRule = { 1, 0.820, 0, 0.10 }
BLIZZARD.gridRule    = { 1, 0.820, 0, 0.10 }
BLIZZARD.sessionOpen = { 1, 0.820, 0, 0.06 }


BLIZZARD.cardGround = { 0.090, 0.102, 0.122, 0.86 }

BLIZZARD.cardPanel  = { 0.031, 0.031, 0.078, 0.92 }
BLIZZARD.cardBorder = { 0.557, 0.557, 0.588, 1 }
BLIZZARD.chipEdge   = { 1, 1, 1, 0.22 }


BLIZZARD.chat      = "00ff00"

local PALETTES = { flat = FLAT, blizzard = BLIZZARD }

local DEFAULT_THEME = "blizzard"






local heldTheme


function A.theme()
	if heldTheme ~= nil then
		return heldTheme
	end
	local db = A.db and A.db()
	local stored = db and db.ui and db.ui.theme
	if type(stored) == "string" and PALETTES[stored] then
		return stored
	end
	return DEFAULT_THEME
end


function A.palette()
	return PALETTES[A.theme()] or BLIZZARD
end


function A.color(name)
	local p = A.palette()
	local c = p[name] or FLAT[name] or FLAT.text
	return c[1], c[2], c[3], c[4]
end


function A.colorHex(r, g, b, a)
	local function byte(value, fallback)
		return math.floor((type(value) == "number" and value or fallback) * 255 + 0.5)
	end
	return ("%02x%02x%02x%02x"):format(byte(r, 0), byte(g, 0), byte(b, 0), byte(a, 1))
end



function A.colorEscape(name)
	local r, g, b = A.color(name)
	return ("|cff%02x%02x%02x"):format(
		math.floor((r or 1) * 255 + 0.5),
		math.floor((g or 1) * 255 + 0.5),
		math.floor((b or 1) * 255 + 0.5))
end








A.REGISTERS = { "fault", "standing", "event", "routine" }


local REGISTER_TEXT = {
	fault = "fault", standing = "standing", event = "event", routine = "routine",
}
local REGISTER_MARK = {
	fault = "fault", standing = "standing", event = "event", routine = "ok",
}



function A.registerEscape(register)
	local name = REGISTER_TEXT[register]
	if not name then
		return nil
	end
	return A.colorEscape(name)
end


function A.registerMark(register)
	return REGISTER_MARK[register]
end



function A.classColor(token)
	local palette = type(RAID_CLASS_COLORS) == "table" and RAID_CLASS_COLORS or nil
	local rc = palette and token and palette[token] or nil
	if type(rc) == "table" and type(rc.r) == "number" then
		return rc.r, rc.g, rc.b, 1
	end
	return A.color("dimmer")
end

local specIcons = nil
local specIconMissed = {}




local function buildSpecIcons()
	local out = {}
	local count = type(GetNumClasses) == "function" and GetNumClasses() or 0

	local specInfo = type(C_SpecializationInfo) == "table" and C_SpecializationInfo or nil
	local numSpecs = (specInfo and type(specInfo.GetNumSpecializationsForClassID) == "function"
		and specInfo.GetNumSpecializationsForClassID) or nil
	if type(GetClassInfo) ~= "function" or type(GetSpecializationInfoForClassID) ~= "function"
		or numSpecs == nil or type(count) ~= "number" then
		return out
	end
	for classID = 1, count do
		local okClass, _, token = pcall(GetClassInfo, classID)
		local okCount, specs = pcall(numSpecs, classID)
		if okClass and type(token) == "string" and okCount and type(specs) == "number" then
			local byName = out[token] or {}
			out[token] = byName
			for index = 1, specs do
				for _, sex in ipairs({ 2, 3 }) do
					local ok, _, name, _, icon = pcall(GetSpecializationInfoForClassID, classID, index, sex)
					if ok and type(name) == "string" and name ~= "" and icon ~= nil then
						byName[name] = icon
					end
				end
			end
		end
	end
	return out
end



function A.specIcon(classToken, spec)
	if type(classToken) ~= "string" or type(spec) ~= "string" or spec == "" then
		return nil
	end
	if specIcons == nil then
		local ok, built = pcall(buildSpecIcons)
		specIcons = ok and built or {}
	end
	local byName = specIcons[classToken]
	local icon = type(byName) == "table" and byName[spec] or nil
	if icon == nil then
		local missKey = classToken .. "/" .. spec
		if not specIconMissed[missKey] then
			specIconMissed[missKey] = true
			if type(A.trace) == "function" then
				A.trace("specIcon", { spec = spec, class = classToken,
					reason = next(specIcons) == nil and "no-table" or "no-match" }, "ui")
			end
		end
	end
	return icon
end


function A.resetSpecIcons()
	specIcons = nil
	specIconMissed = {}
end


function A.chatColor()
	return A.palette().chat or FLAT.chat
end


function A.linkColor()
	return A.palette().link or FLAT.link
end


function A.displayName()
	return "PvP History"
end



function A.chatPrefix()
	return "|cff" .. A.chatColor() .. "PvPHistory:|r "
end


local function repaintTheme()
	pcall(function()
		if A.applyChrome then
			A.applyChrome()
		end
		if A.applyControls then
			A.applyControls()
		end
		if A.refreshWindow then
			A.refreshWindow()
		end
		if A.notifyThemeSetting then
			A.notifyThemeSetting()
		end
	end)
end


function A.setTheme(name)
	if not PALETTES[name] then
		return false
	end

	local db = A.db and A.db()
	if not (db and db.ui) then
		return false
	end


	local released = heldTheme ~= nil
	heldTheme = nil

	if db.ui.theme == name then
		if released then
			repaintTheme()
		end
		return released
	end


	if name == DEFAULT_THEME then
		db.ui.theme = nil
	else
		db.ui.theme = name
	end

	repaintTheme()
	return true
end



function A.holdTheme(name)
	if name ~= nil and not PALETTES[name] then
		return false
	end
	heldTheme = name
	repaintTheme()
	if type(A.trace) == "function" then
		A.trace("view", { source = "typed-appearance", theme = A.theme(), state = A.storedTheme() },
			"ui")
	end
	return true
end


function A.heldTheme()
	return heldTheme
end


function A.storedTheme()
	local db = A.db and A.db()
	local stored = db and db.ui and db.ui.theme
	if type(stored) == "string" and PALETTES[stored] then
		return stored
	end
	return DEFAULT_THEME
end


function A.themeChoices()
	return {
		{ value = "blizzard", label = "Match the game", tooltip = "Keep the client's frame art and colours." },
		{ value = "flat", label = "Dark panel", tooltip = "The addon's own flat dark window." },
	}
end






local SIZES = {
	huge   = { size = 34, flags = "" },


	bannerName   = { size = 16, flags = "OUTLINE" },
	bannerRecord = { size = 13, flags = "OUTLINE" },
	bannerTag    = { size = 12, flags = "OUTLINE" },
	bannerLabel  = { size = 13, flags = "OUTLINE" },

	bannerMark   = { size = 10, flags = "" },
	dossier = { size = 22, flags = "" },
	cardName  = { size = 18, flags = "" },
	cardText  = { size = 14, flags = "" },
	cardLabel = { size = 13, flags = "" },
	large  = { size = 19, flags = "" },
	medium = { size = 15, flags = "" },
	body   = { size = 12, flags = "" },
	label  = { size = 11, flags = "" },
	tiny   = { size = 10, flags = "OUTLINE" },
	micro  = { size = 9,  flags = "OUTLINE" },

	stripLabel  = { size = 12, flags = "" },
	stripFigure = { size = 26, flags = "" },
	stripChange = { size = 14, flags = "" },
	stripTier   = { size = 13, flags = "" },
}


local ROLES = {
	number      = { file = "IBMPlexMono-SemiBold.ttf",       scale = "large",  fallback = "GameFontNormalLarge" },
	numberHuge  = { file = "IBMPlexMono-SemiBold.ttf",       scale = "huge",   fallback = "GameFontNormalHuge" },
	numberSmall = { file = "IBMPlexMono-Regular.ttf",        scale = "body",   fallback = "GameFontHighlightSmall" },
	numberMicro = { file = "IBMPlexMono-Regular.ttf",        scale = "micro",  fallback = "GameFontDisableSmall" },
	stripLabel  = { file = "BarlowSemiCondensed-SemiBold.ttf", scale = "stripLabel", fallback = "GameFontDisableSmall" },
	stripFigure = { file = "IBMPlexMono-SemiBold.ttf",       scale = "stripFigure", fallback = "GameFontNormalHuge" },
	stripChange = { file = "IBMPlexMono-Regular.ttf",        scale = "stripChange", fallback = "GameFontHighlight" },
	stripTier   = { file = "IBMPlexMono-Regular.ttf",        scale = "stripTier",   fallback = "GameFontHighlightSmall" },
	label       = { file = "IBMPlexMono-SemiBold.ttf",       scale = "label",  fallback = "GameFontDisableSmall" },
	heading     = { file = "BarlowSemiCondensed-SemiBold.ttf", scale = "medium", fallback = "GameFontNormal" },
	headingLarge = { file = "BarlowSemiCondensed-SemiBold.ttf", scale = "large", fallback = "GameFontNormalLarge" },

	announceName   = { file = "BarlowSemiCondensed-SemiBold.ttf", scale = "bannerName",   fallback = "GameFontNormalLargeOutline",
		names = true },
	announceRecord = { file = "IBMPlexMono-Regular.ttf",          scale = "bannerRecord", fallback = "GameFontNormalOutline" },
	announceTag    = { file = "BarlowSemiCondensed-Regular.ttf",  scale = "bannerTag",    fallback = "GameFontNormalOutline" },
	announceLabel  = { file = "BarlowSemiCondensed-SemiBold.ttf", scale = "bannerLabel",  fallback = "GameFontNormalOutline" },
	announceMark   = { file = "BarlowSemiCondensed-SemiBold.ttf", scale = "bannerMark",   fallback = "GameFontNormalOutline" },
	dossierName = { file = "BarlowSemiCondensed-SemiBold.ttf", scale = "dossier", fallback = "GameFontNormalLarge",
		names = true },
	cardHead    = { file = "BarlowSemiCondensed-SemiBold.ttf", scale = "body",      fallback = "GameFontHighlightSmall" },
	cardName    = { file = "BarlowSemiCondensed-SemiBold.ttf", scale = "cardName",  fallback = "GameFontNormalLarge",
		names = true },
	cardText    = { file = "BarlowSemiCondensed-Regular.ttf",  scale = "cardText",  fallback = "GameFontHighlight" },
	cardLabel   = { file = "BarlowSemiCondensed-Regular.ttf",  scale = "cardLabel", fallback = "GameFontHighlightSmall" },
	cardValue   = { file = "IBMPlexMono-Regular.ttf",          scale = "medium",    fallback = "GameFontHighlight" },
	bodyText    = { file = "BarlowSemiCondensed-Regular.ttf",  scale = "body",   fallback = "GameFontHighlightSmall" },
	bodyMedium  = { file = "BarlowSemiCondensed-Medium.ttf",   scale = "body",   fallback = "GameFontHighlight" },
	note        = { file = "BarlowSemiCondensed-Regular.ttf",  scale = "tiny",   fallback = "GameFontDisableSmall" },


	rowClock    = { file = "IBMPlexMono-Regular.ttf",          scale = "micro",  flags = "",
		fallback = "GameFontDisableSmall" },
	rowNote     = { file = "BarlowSemiCondensed-Regular.ttf",  scale = "tiny",   flags = "",
		fallback = "GameFontDisableSmall" },

	nameText    = { file = "BarlowSemiCondensed-Regular.ttf",  scale = "body",   fallback = "GameFontHighlightSmall",
		names = true },
	nameMedium  = { file = "BarlowSemiCondensed-Medium.ttf",   scale = "body",   fallback = "GameFontHighlight",
		names = true },
	nameNote    = { file = "BarlowSemiCondensed-Regular.ttf",  scale = "tiny",   flags = "",
		fallback = "GameFontDisableSmall", names = true },
}



local NAME_ALPHABETS = { "roman", "russian", "korean", "simplifiedchinese", "traditionalchinese" }


local ALPHABET_SOURCE = "GameFontNormal"


local FAMILY_CALL = "CreateFontFamily"


local DEFAULT_FALLBACK = "GameFontHighlightSmall"



local SCRIPT_GATE = {
	ruRU = { "BarlowSemiCondensed" },
	koKR = { "BarlowSemiCondensed", "IBMPlexMono" },
	zhCN = { "BarlowSemiCondensed", "IBMPlexMono" },
	zhTW = { "BarlowSemiCondensed", "IBMPlexMono" },
}


local FAMILIES = { "BarlowSemiCondensed", "IBMPlexMono" }

local fonts = {}
local shipped = nil


local locale = nil


local function clientLocale()
	if locale == nil then
		locale = false
		if type(GetLocale) == "function" then
			local ok, value = pcall(GetLocale)
			if ok and type(value) == "string" and value ~= "" then
				locale = value
			end
		end
	end
	return locale or nil
end


local function gatedFace(spec)
	local here = clientLocale()
	local families = here and SCRIPT_GATE[here] or nil
	if type(families) ~= "table" then
		return false
	end
	for i = 1, #families do
		if spec.file:find(families[i], 1, true) == 1 then
			return true
		end
	end
	return false
end


local function build(role, spec)

	if type(CreateFont) ~= "function" then
		return _G[spec.fallback]
	end

	local object = CreateFont("WowPvpHistoryFont_" .. role)
	if type(object) ~= "table" then
		return _G[spec.fallback]
	end

	local scale = SIZES[spec.scale] or SIZES.body

	local flags = scale.flags
	if spec.flags ~= nil then
		flags = spec.flags
	end
	local ok = pcall(function()
		object:SetFont(ADDON_PATH .. "fonts\\" .. spec.file, scale.size, flags)
	end)

	local path = ok and object.GetFont and object:GetFont() or nil
	if type(path) ~= "string" or path == "" then
		shipped = false
		return _G[spec.fallback]
	end

	if shipped == nil then
		shipped = true
	end
	return object
end

local familyBuilds = {}


local function alphabetFile(alphabet)
	local source = _G[ALPHABET_SOURCE]
	if type(source) ~= "table" or type(source.GetFontObjectForAlphabet) ~= "function" then
		return nil
	end
	local ok, object = pcall(source.GetFontObjectForAlphabet, source, alphabet)
	if not ok or type(object) ~= "table" or type(object.GetFont) ~= "function" then
		return nil
	end
	local read, file = pcall(object.GetFont, object)
	if read and type(file) == "string" and file ~= "" then
		return file
	end
	return nil
end



local function buildFamily(role, spec)
	local held = { created = false, game = {}, own = {} }
	familyBuilds[role] = held

	local face
	if gatedFace(spec) then
		face = _G[spec.fallback]
		held.reason = "gated"
	else
		face = build(role, spec) or _G[spec.fallback]
		if face == _G[spec.fallback] then
			held.reason = "face-fallback"
		end
	end

	local createFamily = _G[FAMILY_CALL]
	if held.reason == nil and type(createFamily) ~= "function" then
		held.reason = "no-api"
	end

	local object = face
	if held.reason == nil then
		local scale = SIZES[spec.scale] or SIZES.body
		local flags = scale.flags
		if spec.flags ~= nil then
			flags = spec.flags
		end
		local own = ADDON_PATH .. "fonts\\" .. spec.file

		local members = {}
		for i = 1, #NAME_ALPHABETS do
			local alphabet = NAME_ALPHABETS[i]
			local file = alphabet ~= "roman" and alphabetFile(alphabet) or nil
			if file then
				held.game[#held.game + 1] = alphabet
			else
				file = own
				if alphabet ~= "roman" then
					held.own[#held.own + 1] = alphabet
				end
			end
			members[i] = { alphabet = alphabet, file = file, height = scale.size, flags = flags }
		end

		local ok, family = pcall(createFamily, "WowPvpHistoryFamily_" .. role, members)
		local path = nil
		if ok and type(family) == "table" and type(family.GetFont) == "function" then
			local read, file = pcall(family.GetFont, family)
			path = read and file or nil
		end
		if not ok then
			held.reason = "threw"
		elseif type(path) ~= "string" or path == "" then
			held.reason = "unread"
		else
			held.reason = "built"
			held.created = true
			object = family
		end
	end

	if A.trace then
		A.trace("fontFamily", {
			fontRole = role,
			reason = held.reason,
			created = held.created,
			gameFaces = #held.game > 0 and table.concat(held.game, ",") or nil,
			ownFaces = #held.own > 0 and table.concat(held.own, ",") or nil,
		}, "ui")
	end
	return object
end


function A.font(role)
	local spec = ROLES[role]
	if not spec then
		return _G[DEFAULT_FALLBACK]
	end
	if fonts[role] == nil then
		if spec.names then
			fonts[role] = buildFamily(role, spec) or _G[spec.fallback]
		elseif gatedFace(spec) then
			fonts[role] = _G[spec.fallback]
		else
			fonts[role] = build(role, spec) or _G[spec.fallback]
		end
	end
	return fonts[role]
end


function A.fontFamily(role)
	local held = familyBuilds[role]
	if held == nil then
		return nil
	end
	local game, own = {}, {}
	for i = 1, #held.game do
		game[i] = held.game[i]
	end
	for i = 1, #held.own do
		own[i] = held.own[i]
	end
	return { created = held.created, reason = held.reason, game = game, own = own }
end


function A.fontsLoaded()
	return shipped
end


function A.fontsGated()
	local here = clientLocale()
	local families = here and SCRIPT_GATE[here] or nil
	if type(families) ~= "table" then
		return nil
	end
	return here, #families >= #FAMILIES
end


function A.trackBase()
	return A.metric("rowBar") - A.metric("rowDamageValue")
end



function A.labelRoom(text)
	if type(text) ~= "string" or text == "" then
		return 0
	end
	return math.ceil(#text * A.metric("labelAdvance"))
end


function A.askCardHeight(captioned)
	local height = A.metric("cardPad") * 2 + A.fontSize("label") + A.metric("cardLabelGap")
		+ A.fontSize("bodyText")
	if captioned == true then
		height = height + A.fontSize("note") + A.metric("cardCaptionGap")
	end
	return height
end


function A.askCardOverRoom(room)
	if type(room) ~= "number" then
		return 0
	end
	return math.max(0, math.floor(room))
end



function A.askCardRow(parts, room)
	parts = type(parts) == "table" and parts or {}
	local held = (type(room) == "number" and room > 0) and room or 0
	local function need(key)
		local value = parts[key]
		return (type(value) == "number" and value > 0) and value or 0
	end

	local gap = A.metric("cardHeadGap")
	local out = { rate = need("rate") > 0, record = need("record") > 0, over = need("over") > 0 }
	local function cluster()
		local wide, count = 0, 0
		for _, key in ipairs({ "rate", "record", "over" }) do
			if out[key] then
				wide = wide + need(key)
				count = count + 1
			end
		end
		return wide + (count > 1 and (count - 1) * gap or 0)
	end

	for _, key in ipairs({ "over", "record" }) do
		local wide = cluster()
		if wide == 0 or need("name") + gap + wide <= held then
			break
		end
		out[key] = false
	end

	out.width = cluster()
	return out
end


function A.textRoom(fontString, text)
	if type(text) ~= "string" or text == "" then
		return 0
	end
	return A.clientTextWidth(fontString, text) or A.labelRoom(text)
end



function A.clientTextWidth(fontString, text)
	if fontString == nil or type(text) ~= "string" or text == "" then
		return nil
	end
	local ok, width = pcall(function()
		return fontString:GetUnboundedStringWidthForText(text)
	end)
	if ok and type(width) == "number" and width > 0 then
		return math.ceil(width)
	end
	return nil
end




function A.fittedForm(fontString, room, forms)
	if type(forms) ~= "table" or #forms == 0 then
		return nil, nil, false
	end
	if type(room) ~= "number" or room <= 0 then
		return nil, nil, false
	end
	for i = 1, #forms do
		local text = forms[i]
		if type(text) == "string" and text ~= "" and A.textRoom(fontString, text) <= room then
			return text, i, true
		end
	end
	return nil, nil, true
end


function A.headerFloor(text)
	local room = A.labelRoom(text)
	if room <= 0 then
		return 0
	end
	return math.ceil(room / A.metric("compHeadRoom"))
end


local repaintMode = "lean"


local LEAN_CUTS = { "style", "windows", "choices", "summary", "tally" }


function A.repaintMode()
	return repaintMode
end


function A.leanCuts()
	local cuts = {}
	for i = 1, #LEAN_CUTS do
		cuts[i] = LEAN_CUTS[i]
	end
	return cuts
end


function A.setRepaintMode(mode)
	if mode ~= "lean" and mode ~= "full" then
		return false
	end
	repaintMode = mode
	return true
end


local styleCounts


function A.countStyles(on)
	if on then
		styleCounts = { skipped = 0, applied = 0 }
		return true
	end
	local held = styleCounts
	styleCounts = nil
	if not held then
		return nil, nil
	end
	return held.skipped, held.applied
end



function A.style(fontString, role, colorName)
	if type(fontString) ~= "table" then
		return false
	end
	local object = A.font(role)
	if object and fontString.SetFontObject then
		local same = false
		if repaintMode == "lean" and fontString.GetFontObject then
			local ok, current = pcall(fontString.GetFontObject, fontString)
			same = ok and current == object
		end
		if same then
			if styleCounts then
				styleCounts.skipped = styleCounts.skipped + 1
			end
		else
			pcall(fontString.SetFontObject, fontString, object)
			if styleCounts then
				styleCounts.applied = styleCounts.applied + 1
			end
		end
	end
	if colorName and fontString.SetTextColor then
		fontString:SetTextColor(A.color(colorName))
	end
	return true
end






local METRICS = {

	frameWidth   = 1069,

	listWidth    = 462,
	margin       = 14,
	paneGap      = 8,

	paneSplitGap = 22,
	paneRightPad = 12,


	tabRowDrop   = 18,

	windowMinRows = 12,

	windowRows   = 18,

	dropdownWidth   = 150,


	dropdownWidthMax = 320,
	dropdownRow     = 18,
	dropdownRows    = 8,
	dropdownPad     = 3,
	dropdownCaret   = 6,

	gripSize     = 16,
	gripInset    = 3,
	gripStroke   = 2,
	gripStrokeGap = 4,

	headerHeight = 30,

	filterHeight = 22,

	summaryGap   = 6,

	editHeight   = 24,


	paneEditGap  = 4,



	titleInset   = 56,

	titleTop         = 6,
	headerActionDrop = 4,

	rowHeight    = 16,


	rowMatchRow  = 34,

	rowListRow   = 32,

	rowChip      = 20,
	rowChipGap   = 3,

	rowPip       = 6,
	rowPipGap    = 2,

	rowChangeHalf = 18,
	rowChangeBar  = 6,
	rowChangeScaleCap = 60,

	rowColChip     = 24,
	rowColLobby    = 112,
	rowColRounds   = 92,
	rowColChange   = 80,

	rowSubLine   = 14,

	rowMarkSize  = 9,
	rowMarkGap   = 4,

	participantRow = 22,


	headPad        = 4,
	headGap        = 8,
	headCrestGap   = 6,
	headPipWidth   = 7,
	headPipHeight  = 14,
	headPipGap     = 3,
	headChipPad    = 6,
	bannerPad      = 10,
	ladderPad      = 6,
	ladderBar      = 6,
	ladderGap      = 2,
	ladderMark     = 12,
	roundCellMark  = 10,
	roundCardPad   = 6,
	roundCardGap   = 6,
	roundCardLine  = 2,
	roundCardEdge  = 2,


	classEdge      = 3,

	barHeight      = 5,


	rowKb          = 26,
	rowBar         = 100,
	rowRole        = 34,


	rowDispels     = 33,



	rowDamageValue = 52,


	rowSpec        = 98,


	rowName        = 162,


	labelAdvance   = 7,

	rowShareAlpha  = 0.22,


	rowHeal        = 58,

	rowNamePad     = 8,
	rowCellGap     = 6,

	rowMapMin      = 10,

	plotPanelGap   = 10,



	rowColMatch    = 48,
	rowColLength   = 56,


	rowColRating   = 56,

	rowColCrest    = 16,


	rowColWhere    = 130,
	rowColOpponent = 108,
	rowColPair     = 184,
	rowColKind     = 54,

	rowColWhen     = 70,
	rowColStamp    = 112,
	rowColResult   = 60,

	rowColRecord   = 44,



	rowColFormat   = 136,

	rowColSize     = 40,

	lobbyRoundGap  = 2,
	lobbyRunGap    = 12,
	lobbyRoundPad  = 2,

	lobbyRound     = 31,
	lobbyFigure    = 25,
	lobbySwing     = 42,

	rowResultMark  = 2,

	rowHeadRow     = 18,
	rowExpandPad   = 6,

	rowDayRow      = 26,



	gridSession      = 180,
	gridTime         = 84,
	gridFormat       = 72,
	gridRating       = 72,
	gridRecord       = 72,
	gridMatches      = 52,
	gridResultsFloor = 204,
	gridRow          = 38,
	gridRowFold      = 46,
	gridTick         = 7,
	gridTickHeight   = 12,
	gridTickGap      = 2,
	gridDot          = 3,

	standingStrip  = 84,

	standingPad       = 18,
	standingLineGap   = 4,
	standingRate      = 190,
	standingStat      = 150,
	standingCellFloor = 120,

	standingBar    = 12,
	standingBarGap = 2,
	standingTrendInset = 10,
	standingFigure = 108,
	standingGap    = 18,
	standingSquare = 12,
	duelPanel      = 260,
	duelPanelRow   = 38,



	rowLabelPad    = 4,



	rowObjectiveMax = 2,

	rosterHeadRow  = 16,
	rosterHeadGap  = 3,



	detailTextInset = 8,
	detailBarInset  = 12,

	detailRows     = 10,
	detailCascade  = 26,
	detailGap      = 8,

	objectivesPad  = 8,
	objectivesGap  = 5,

	objectivesSide = 68,

	objectivesCell = 88,

	paceRow        = 12,
	paceGap        = 3,
	paceLabel      = 24,
	paceValue      = 52,

	compRow        = 26,

	compLength     = 52,
	compDelta      = 46,
	compRecord     = 48,


	compGames      = 44,



	compHeadRoom   = 0.85,


	compPct        = 62,

	compSwatch     = 8,
	compChipGap    = 10,



	cardPad        = 6,
	cardLabelGap   = 4,
	cardGap        = 8,

	cardCaptionGap = 3,

	cardHeadGap    = 8,

	playerRow      = 34,
	playerSection  = 22,
	playerLane     = 3,
	playerLaneGap  = 10,
	playerColMet   = 40,
	playerColSide  = 92,

	standPad       = 8,
	repBarHeight   = 10,
	repBarGap      = 2,
	standLead      = 150,
	standTile      = 84,
	repSwatch      = 8,

	playerSearch   = 200,

	repStepGap     = 3,

	sideCardPad    = 6,
	sideCardGap    = 8,

	encRow         = 30,
	encColMatch    = 44,
	encColWhen     = 64,
	encColWhereMin = 72,
	encColSide     = 78,
	encColResult   = 52,
	encColChange   = 50,
	encColWhereWide = 180,
	roundMark      = 10,
	roundMarkHeight = 12,
	roundMarkGap   = 3,

	roundBox       = 40,
	roundBoxHeight = 18,
	roundBoxGap    = 4,

	headingPad     = 4,
	commentPad     = 4,



	announceStripWidth     = 900,
	announcePillEdge       = 4,
	announcePillPadLeft    = 12,
	announcePillPadRight   = 10,
	announcePillPadY       = 5,
	announcePillLine       = 20,
	announcePillPartGap    = 7,
	announcePillRowGap     = 4,
	announceNoteMark       = 14,
	announceTagHeight      = 16,
	announceTagPad         = 5,
	announceTagGap         = 4,
	announcePillGap        = 6,
	announceLabelGap       = 6,
	announceStripLineGap   = 6,
	announceSideGap        = 14,
	announceSideRule       = 1,
	announceSideRuleHeight = 26,

	compShareBar   = 66,
	compShareAlpha = 0.22,


	compListGames  = 2,



	chipPad        = 10,
	chipGap        = 8,



	lineHeight   = 13,

	plotHeight   = 74,
	stripGap     = 10,

	readingRow      = 13,
	readingPad      = 3,
	readingKeyWidth = 92,
	readingKeyGap   = 10,

	readingGap      = 4,

	plotNotePad  = 4,



	titleActionGap      = 4,
	titleActionFallback = 28,
	titleActionDrop     = 6,


	plotLabelDrop = 16,

	plotCurveMin = 20,


	plotPointMin = 3,



	plotGutter   = 34,
	plotLabelPad = 5,
	plotDotSize  = 5,

	plotTickMax  = 4,



	plotMmrAlpha = 0.3,

	plotMmrThickness = 1.2,



	plotMmrShare = 2 / 3,



	tilePad      = 6,



	tooltipMeasure = 480,



	headlineJoin = 6,
	tileGap      = 20,

	tileMinWidth = 44,

	tileAsideGap   = 8,
	tileTrendWidth = 108,
	tileTrendFloor = 44,
	tileAsideFloor = 36,
	tileTrendBar   = 6,
	tileTrendLine  = 1,
	tileDoorMark   = 5,
	tileEdgeLane   = 2,

	opponentRow  = 14,

	headlineGap  = 4,
	stripPad     = 2,

	tileLabelGap = 2,
	tileValueGap = 1,

	notesListWidth  = 400,

	searchHeight    = 20,

	tagBoxMin       = 90,


	tagButton       = 18,
	tagFooterHeight = 30,

	controlHeight       = 20,

	checkMarkInset      = 5,


	entryInsetX         = 6,
	entryInsetY         = 2,

	optionsReadingKey   = 72,

	storeWidth          = 560,

	storeHeight         = 30 + 24 + 4 * 32 + 14 * 2,
	storeRow            = 32,
	storeDot            = 8,
	storeNameInset      = 18,
	storeReadingInset   = 90,

	storeOffsetX        = 120,
	storeOffsetY        = 80,

	optionsRow          = 24,

	cardHead            = 30,
	cardRow             = 36,
	setCardPad          = 12,
	cardIndent          = 16,
	setCardGap          = 14,

	toggleWidth         = 32,
	toggleHeight        = 18,
	toggleKnob          = 14,

	findWidth           = 240,
	paneHeader          = 34,

	meterBar            = 10,
	slotCard            = 62,

	aboutIcon           = 64,
	aboutLeft           = 340,
	aboutPad            = 22,
	aboutGap            = 14,
	aboutKeyColumn      = 76,
	aboutFactRow        = 30,
	aboutBestRow        = 40,
	aboutTile           = 72,
	aboutTileGap        = 10,
	aboutWeekChart      = 140,
	aboutWeekGap        = 8,
	aboutWeekMin        = 36,
	aboutCharRow        = 28,
	aboutCharName       = 150,
	aboutCharCount      = 44,
	aboutCharBar        = 6,
	aboutFormatBar      = 12,

	optionsNote         = 16,



	optionsDot          = 8,
	optionsDotGap       = 6,

	transferWidth       = 560,
	transferHeight      = 140,
	sheetWidth          = 700,
	sheetHeight         = 420,

	transferButton      = 160,
	sheetButton         = 200,

	sectionGap          = 14,
	sectionIndent       = 10,

	pillPad             = 20,
	pillMin             = 48,

	actionMin           = 80,



	pillGap             = 4,



	stepMin             = 26,
	stepFigure          = 44,


	tabUnderline        = 2,



	holdLine            = 3,
	holdGap             = 6,
	holdStandInHeight   = 21,
	holdStandInMargin   = 100,


	tabMin              = 56,



	panelTabHeight      = 32,
	panelTabPad         = 20,
	panelTabInset       = 11,
	panelTabOverlap     = 2,
	panelTabGap         = 1,



	tabRowGap           = 2,

	resultMin           = 56,

	tagMin              = 36,
	tagPad              = 16,



	tagRow              = 22,



	segmentHeight       = 16,
	segmentTrackPad     = 2,
	segmentGap          = 2,

	segmentPad          = 18,
	segmentMin          = 36,


	nameCardWidth           = 300,
	nameCardWidthMax        = 400,
	nameCardPadX            = 12,
	nameCardPadY            = 10,
	nameCardGap             = 8,
	nameCardChipHeight      = 18,
	nameCardChipPad         = 7,
	nameCardChipInset       = 10,
	nameCardTagPad          = 6,
	nameCardTagGap          = 5,
	nameCardNameGap         = 6,
	nameCardRulePad         = 6,
	nameCardTagHeight       = 16,
	nameCardChipEdge        = 1,
	nameCardEdge            = { blizzard = 2, flat = 1 },
	nameCardDash            = 3,
	nameCardDashGap         = 2,

	finderPadX              = 12,
	finderPadY              = 10,
	finderGap               = 6,
	finderColGap            = 12,

	finderRowHeight         = 16,
	finderGroupGap          = 4,
	finderFormatWidth       = 96,
	finderRatingWidth       = 36,
	finderRecordWidth       = 40,
	finderRateWidth         = 32,
	finderSinceWidth        = 52,
}



METRICS.rowLeadInset = METRICS.rowResultMark + METRICS.rowCellGap - METRICS.rowLabelPad
METRICS.rowColChip = METRICS.rowColChip + METRICS.rowLeadInset
METRICS.rowColCrest = METRICS.rowColCrest + METRICS.rowLeadInset



local heldWidth = nil


local widthPinned = false


function A.windowWidth()
	if heldWidth ~= nil then
		return heldWidth
	end
	return METRICS.frameWidth
end



function A.withWindowWidth(frame, fn, ...)
	if type(fn) ~= "function" then
		return nil
	end
	if widthPinned then
		return fn(...)
	end
	if type(frame) == "table" then
		local ok, width = pcall(frame.GetWidth, frame)
		if ok and type(width) == "number" and width > 0 then
			heldWidth = width
		end
	end
	widthPinned = true
	local ok, first, second = pcall(fn, ...)
	widthPinned = false
	if not ok then
		error(first, 0)
	end
	return first, second
end


function A.bodyWidth(width)
	if type(width) ~= "number" or width <= 0 then
		width = A.windowWidth()
	end
	return width - METRICS.margin * 2 - METRICS.paneRightPad
end



function A.listSplitWidth()
	return METRICS.listWidth
end


function A.paneWidth()
	return A.bodyWidth() - METRICS.paneSplitGap - A.listSplitWidth()
end


function A.rosterRowWidth()
	local gap = METRICS.rowCellGap
	local left = METRICS.classEdge + METRICS.rowNamePad + METRICS.rowName
	local right = gap + METRICS.rowDispels
		+ gap + METRICS.rowKb + gap + METRICS.rowHeal + gap + METRICS.rowBar
		+ gap + METRICS.rowRole + gap + METRICS.rowSpec
	return left + gap + right
end


function A.askSplitWidth(width)
	return math.floor((A.bodyWidth(width) - METRICS.paneSplitGap) / 2)
end



function A.askPaneWidth(width)
	if width == nil and ((type(A.askAcross) == "function" and A.askAcross())
		or (type(A.specsShowing) == "function" and A.specsShowing())
		or (type(A.mapsShowing) == "function" and A.mapsShowing())) then
		return A.bodyWidth()
	end
	return A.bodyWidth(width) - METRICS.paneSplitGap - A.askSplitWidth(width)
end


function A.askTableWidth(width)
	return A.askPaneWidth(width) - METRICS.rowLabelPad
end



local function columnFurniture(count)
	if type(count) ~= "number" or count < 1 then
		return 0
	end
	return METRICS.rowLabelPad * 2 + METRICS.rowCellGap * (count - 1)
end



function A.askColumnShares(room)
	if type(room) ~= "number" or room <= 0 then
		room = A.askTableWidth()
	end
	local furniture = columnFurniture(4)
	local met = math.floor(room / 10)
	local record = math.floor(room * 2 / 5)
	local rate = math.floor(room / 9)

	local metFloor, recordFloor, rateFloor = 0, 0, 0
	if type(A.askColumnFloors) == "function" then
		metFloor, recordFloor, rateFloor = A.askColumnFloors()
	end
	met = math.max(met, metFloor)
	record = math.max(record, recordFloor)
	rate = math.max(rate, rateFloor)
	local name = room - furniture - met - record - rate
	return name, met, record, rate, room
end



local ASK_SHARES = { askName = 1, askMet = 2, askRecord = 3, askRate = 4 }



function A.barSplit(bar, share)
	if type(bar) ~= "number" or bar <= 0 or type(share) ~= "number" then
		return nil, nil
	end
	local win = (share <= 0) and 0 or math.max(1, math.floor(bar * share))
	if win >= bar and share < 1 then
		win = bar - 1
	end
	return win, bar - win
end


function A.metric(name)
	local share = ASK_SHARES[name]
	if share ~= nil then
		return (select(share, A.askColumnShares()))
	end
	return A.themeMetric(name, A.theme())
end



function A.themeMetric(name, theme)
	local value = METRICS[name]
	if type(value) == "table" then
		local held = value[theme]
		if type(held) ~= "number" then
			held = value[DEFAULT_THEME]
		end
		value = held
	end
	if type(value) ~= "number" then
		return 0
	end
	return value
end


function A.metricThemed(name)
	return type(METRICS[name]) == "table"
end



function A.fontSize(role)
	local spec = ROLES[role]
	local scale = spec and SIZES[spec.scale]
	if not scale then
		return SIZES.body.size
	end
	return scale.size
end


function A.tileHeight()
	return A.metric("tilePad") * 2
		+ A.fontSize("label") + A.metric("tileLabelGap")
		+ A.fontSize("number")
end


function A.noteRowHeight()
	return A.fontSize("note") + A.metric("plotNotePad")
end


function A.readingHeight(lines, collapsed)
	local count = type(lines) == "number" and lines or 0
	if count < 0 then
		count = 0
	end
	if count == 0 or collapsed == true then
		return 0
	end
	return A.metric("readingPad") * 2 + count * A.metric("readingRow") + A.metric("readingGap")
end



function A.readingReserve()
	return A.readingHeight(4)
end



function A.readingRoom(headline)
	local room = A.summaryHeight(headline) - A.stripHeight(headline) - A.metric("stripGap")
		- A.noteRowHeight()
	if room < 0 then
		room = 0
	end
	return room
end


function A.plotFoot()
	return A.fontSize("note") + 4
end


function A.plotFoldHeight()
	local row = A.metric("plotLabelDrop")
	if A.metric("segmentHeight") > row then
		row = A.metric("segmentHeight")
	end
	return row
end


function A.plotCeiling()
	return A.metric("plotHeight") + A.readingReserve()
end


function A.plotFloor()
	local face = A.fontSize("note")
	local stack = (A.metric("plotTickMax") + 1) * face
	local curve = stack
	if curve < A.metric("plotCurveMin") then
		curve = A.metric("plotCurveMin")
	end
	return A.metric("plotLabelDrop") + curve + A.plotFoot()
end




function A.plotTicks(height)
	if type(height) ~= "number" or height < A.plotFloor() then
		return nil, "floor"
	end
	local most = A.metric("plotTickMax")
	local box = height - A.metric("plotLabelDrop") - A.plotFoot()
	local inner = math.floor(box / A.fontSize("note")) + 1 - 2
	if inner < most then
		return inner, "box"
	end
	return most, nil
end


local COMP_NOTE_LINES = 2



function A.compPaneStack(opts)
	opts = type(opts) == "table" and opts or {}
	local drawsTable = opts.table ~= false

	local out = {}
	out.heading = 2 + A.fontSize("label")
	out.compHead = 4 + A.fontSize("label") + 6
	out.note = 6 + (opts.note == false and 0 or COMP_NOTE_LINES * A.fontSize("note"))

	out.group = (drawsTable and opts.group == true) and (4 + A.fontSize("label") + 4) or 0


	out.paneHead = drawsTable and (A.metric("rowHeadRow") + (opts.group == true and 0 or 4)) or 0
	out.row = drawsTable and A.metric("rowHeight") or 0

	out.above = out.heading + out.compHead + 2
	out.below = out.note + out.group + out.paneHead + out.row
	return out
end



function A.compBandRoom(host, opts)
	opts = type(opts) == "table" and opts or {}
	local stack = A.compPaneStack(opts)
	local floor = A.metric("compRow")
	if type(host) ~= "number" or host <= 0 then
		return floor, stack
	end

	local wanted = (type(opts.wanted) == "number" and opts.wanted > 0) and opts.wanted or nil
	local below = stack.below
	if wanted ~= nil and opts.table ~= false then
		below = below - stack.row + wanted
	end
	local room = host - stack.above - below

	if opts.table ~= false and wanted == nil then
		local share = math.floor(host * 0.5)
		if share < room then
			room = share
		end
	end
	if room < floor then
		room = floor
	end
	return room, stack
end



function A.compColumnTop(parts)
	parts = type(parts) == "table" and parts or {}
	local function held(value)
		return (type(value) == "number" and value > 0) and value or 0
	end
	local band = held(parts.band)

	local noteTop
	local headingFoot = 2 + held(parts.heading)
	local anchorFoot, anchorDrop = headingFoot, 4
	if parts.head ~= nil then
		anchorFoot, anchorDrop = headingFoot + 4 + held(parts.head), 2
	end
	if band > 0 then
		noteTop = anchorFoot + anchorDrop + band + 6
	elseif parts.heading == nil then
		noteTop = 2
	else
		noteTop = anchorFoot + anchorDrop + 6
	end
	local noteFoot = noteTop + held(parts.note)

	return noteFoot + 8 + held(parts.title), noteFoot
end


function A.specViewStack(parts)
	parts = type(parts) == "table" and parts or {}
	local function held(value)
		return (type(value) == "number" and value > 0) and value or 0
	end
	local foot = held(parts.foot)
	return 2 + held(parts.heading), foot > 0 and (foot + A.metric("paneGap")) or 0
end



function A.askPaneRoom(parts)
	parts = type(parts) == "table" and parts or {}
	if type(parts.host) ~= "number" then
		return nil
	end
	local function held(value)
		return (type(value) == "number" and value > 0) and value or 0
	end
	local room = parts.host - 2 - held(parts.heading) - 4 - held(parts.head)
		- METRICS.paneGap - held(parts.note) - held(parts.band)
	if room < 0 then
		room = 0
	end
	return room
end



function A.askBandRoom(host, parts)
	parts = type(parts) == "table" and parts or {}
	local function held(value)
		return (type(value) == "number" and value > 0) and value or 0
	end
	local wanted = held(parts.wanted)
	if type(host) ~= "number" or host <= 0 or wanted <= 0 then
		return 0
	end

	local spare = host - 2 - held(parts.heading) - 4 - held(parts.head)
		- METRICS.paneGap - held(parts.note) - METRICS.paneGap - METRICS.rowHeight
	local room = wanted
	local share = math.floor(host * 0.5)
	if share < room then
		room = share
	end
	if spare < room then
		room = spare
	end

	if type(parts.beside) == "number" and parts.beside > 0 then
		local under = host - parts.beside - METRICS.paneGap - held(parts.note) - METRICS.paneGap
		if under < room then
			room = under
		end
	end
	if room < METRICS.rowHeight then
		return 0
	end
	return room - room % METRICS.rowHeight
end


function A.windowFootBand()
	return METRICS.paneGap + A.fontSize("rowNote")
end


function A.windowFootRuleY()
	return METRICS.margin + A.fontSize("rowNote") + math.floor(METRICS.paneGap / 2)
end


function A.bodyFloor()
	return METRICS.margin + A.windowFootBand()
end



function A.viewportRows(room, extent)
	if type(room) ~= "number" or type(extent) ~= "number" or extent <= 0 or room <= 0 then
		return 0, 0
	end
	local rows = math.floor(room / extent)
	if rows < 0 then
		rows = 0
	end
	return rows, rows * extent
end


function A.linesOver(lines, room)
	if type(lines) ~= "table" or type(room) ~= "number" or room <= 0 then
		return 0
	end
	local held = 0
	for i = 1, #lines do
		local height = type(lines[i]) == "table" and lines[i].height or nil
		if type(height) ~= "number" or height <= 0 then
			break
		end
		if held + height > room then
			if held == 0 then
				return 0
			end
			return room - held
		end
		held = held + height
	end
	return 0
end



local EDGE_SLACK = 0.5


local function rowTops(rows, base)
	local tops, held = {}, 0
	for i = 1, (type(rows) == "table" and #rows or 0) do
		tops[i] = held
		local height = type(rows[i]) == "table" and rows[i].height or nil
		if type(height) ~= "number" or height < 1 then
			height = base
		end
		held = held + height
	end
	return tops, held
end



local function rowDays(rows)
	local days, at = {}, nil
	for i = 1, (type(rows) == "table" and #rows or 0) do
		local row = type(rows[i]) == "table" and rows[i] or {}
		if row.separator and not row.names then
			at = i
			days[i] = i
		elseif row.noDay then
			at = nil
		else
			days[i] = at
		end
	end
	return days
end





function A.rowEdges(rows, offset, visible, base, pin, cut)
	base = (type(base) == "number" and base > 0) and base or 1
	pin = (type(pin) == "number" and pin > 0) and pin or 0
	local tops, content = rowTops(rows, base)
	local days = rowDays(rows)
	local out = { content = content, first = nil, last = nil, snap = 0, range = 0, atEnd = false,
		pinned = nil, pin = pin, cut = cut == true }
	if type(offset) ~= "number" or type(visible) ~= "number" or visible <= 0 then
		return out
	end
	local range = content - visible
	if range < 0 then
		range = 0
	end
	out.range = range
	if offset < 0 then
		offset = 0
	end

	local function target(i)
		if pin > 0 and days[i] ~= nil and days[i] ~= i then

			if type(rows[i]) == "table" and rows[i].names then
				return tops[days[i]]
			end
			local top = tops[i] - pin
			return top > 0 and top or 0
		end
		return tops[i]
	end

	if range > 0 then
		out.atEnd = offset >= range - EDGE_SLACK
		if out.atEnd then
			out.snap = range
		else
			local best, bestGap = 0, math.huge
			for i = 1, #tops do
				if tops[i] > range + pin + EDGE_SLACK then
					break
				end
				local at = target(i)
				if at <= range + EDGE_SLACK then
					local gap = math.abs(at - offset)
					if gap < bestGap then
						best, bestGap = at, gap
					end
				end
			end
			out.snap = best
		end
	end



	local topEdge = offset
	if pin > 0 then
		local at, below = nil, nil
		for i = 1, #tops do
			if at == nil and tops[i] >= offset - EDGE_SLACK then
				at = i
			end
			if below == nil and tops[i] >= offset + pin - EDGE_SLACK then
				below = i
			end
		end
		local atRow = (at and type(rows[at]) == "table") and rows[at] or {}
		local belowRow = (below and type(rows[below]) == "table") and rows[below] or {}
		local flush = below ~= nil and math.abs(tops[below] - (offset + pin)) <= EDGE_SLACK

		if at ~= nil and (not atRow.separator or atRow.names) and flush and not belowRow.separator
			and days[below] ~= nil and days[below] ~= below then
			out.pinned = days[below]
			topEdge = offset + pin
		end
	end

	if out.cut then
		for i = 1, #tops do
			local top = tops[i]
			local foot = (tops[i + 1] or content)
			if foot > topEdge + EDGE_SLACK and top < offset + visible - EDGE_SLACK then
				out.first = out.first or i
				out.last = i
			elseif out.first then
				break
			end
		end
		return out
	end

	for i = 1, #tops do
		local top = tops[i]
		local foot = (tops[i + 1] or content)
		local startsInside = top >= topEdge - EDGE_SLACK
		local endsInside = foot <= offset + visible + EDGE_SLACK
		local tallAtTop = foot - top > (offset + visible - topEdge)
			and math.abs(top - topEdge) <= EDGE_SLACK
		if startsInside and (endsInside or tallAtTop) then
			out.first = out.first or i
			out.last = i
		elseif out.first then
			break
		end
	end


	while out.last ~= nil and out.first ~= nil and out.last >= out.first
		and type(rows[out.last]) == "table" and rows[out.last].separator do
		out.last = out.last - 1
		if out.last < out.first then
			out.first, out.last = nil, nil
		end
	end
	return out
end



function A.rowGap(rows, index, edges, base)
	base = (type(base) == "number" and base > 0) and base or 1
	local tops, content = rowTops(rows, base)
	if type(index) ~= "number" or tops[index] == nil or type(edges) ~= "table" then
		return nil
	end
	if edges.first ~= nil and edges.last ~= nil and index >= edges.first and index <= edges.last then
		return "drawn", 0, 0
	end
	local offset = type(edges.offset) == "number" and edges.offset or 0
	local visible = type(edges.visible) == "number" and edges.visible or 0
	if edges.first ~= nil and index < edges.first then
		local top = offset + (edges.pinned ~= nil and (edges.pin or 0) or 0)
		return "above", top - (tops[index + 1] or content), edges.first - index
	end
	return "below", tops[index] - (offset + visible), edges.last and (index - edges.last) or 0
end




function A.rowStep(rows, offset, visible, base, steps, pin)
	base = (type(base) == "number" and base > 0) and base or 1
	pin = (type(pin) == "number" and pin > 0) and pin or 0
	local tops, content = rowTops(rows, base)
	local days = rowDays(rows)
	if type(offset) ~= "number" or type(visible) ~= "number" or type(steps) ~= "number" then
		return 0
	end
	local range = content - visible
	if range <= 0 or #tops == 0 then
		return 0
	end



	local edges = A.rowEdges(rows, offset, visible, base, pin)
	local from = edges.first
	if from == nil then
		from = A.rowEdges(rows, offset, visible, base, pin, true).first or 1
		if steps < 0 then
			from = from + 1
		end
	end
	if offset < 0 then
		offset = 0
	end

	local function landing(i)
		local row = type(rows[i]) == "table" and rows[i] or {}
		if pin > 0 and days[i] ~= nil and days[i] ~= i then
			if row.names then
				return tops[days[i]]
			end
			local top = tops[i] - pin
			return top > 0 and top or 0
		end
		return tops[i]
	end



	local sign = steps < 0 and -1 or 1
	local index = from + steps
	while true do
		if index < 1 then
			return 0
		end
		if tops[index] == nil then
			return range
		end
		local target = landing(index)
		if target > range then
			target = range
		end
		if (sign > 0 and target > offset + EDGE_SLACK) or (sign < 0 and target < offset - EDGE_SLACK) then
			return target
		end
		index = index + sign
	end
end



function A.unitFigure(value)
	if type(value) ~= "number" then
		return nil
	end

	if value ~= value or value == math.huge or value == -math.huge then
		return nil
	end

	local scaled = value * 100
	if scaled < 0 then
		return -math.floor(-scaled + 0.5) / 100
	end
	return math.floor(scaled + 0.5) / 100
end



function A.stripHeight(headline)
	local tiles = A.tileHeight()
	if headline == false then
		return tiles
	end
	local head = A.fontSize("numberHuge") + A.metric("headlineGap")
		+ A.fontSize("numberSmall") + A.metric("stripPad")
	return head > tiles and head or tiles
end


function A.objectivesHeight()
	return A.metric("objectivesPad") * 2
		+ A.fontSize("label") + A.metric("objectivesGap")
		+ (A.fontSize("numberSmall") + A.metric("objectivesGap")) * 2
end


function A.paceHeight(rounds)
	if type(rounds) ~= "number" or rounds < 1 then
		return 0
	end
	return A.metric("objectivesPad") * 2
		+ A.fontSize("label") + A.metric("objectivesGap")
		+ rounds * A.metric("paceRow") + (rounds - 1) * A.metric("paceGap")
end



function A.objectiveCellRoom(stripWidth, count)
	if type(stripWidth) ~= "number" or type(count) ~= "number" or count < 1 then
		return nil
	end

	local room = stripWidth - A.metric("objectivesPad") * 2 - A.metric("objectivesSide")
		- count * A.metric("objectivesGap")
	local each = math.floor(room / count)
	if each < A.metric("objectivesCell") then
		return A.metric("objectivesCell")
	end
	return each
end



function A.headHeight()
	local tallest = A.fontSize("heading")
	for _, role in ipairs({ "headingLarge", "number" }) do
		if A.fontSize(role) > tallest then
			tallest = A.fontSize(role)
		end
	end
	return tallest + A.metric("headPad") * 2
end


function A.headSubHeight()
	return A.fontSize("heading") + A.metric("headPad") * 2
end





local TEMPLATE_ART = {
	"TopLeftCorner", "TopRightCorner", "TopBorder",
	"BotLeftCorner", "BotRightCorner", "BottomBorder", "LeftBorder", "RightBorder",
	"Bg", "TitleBg", "TopTileStreaks",
	"InsetBg",
	"InsetBorderTopLeft", "InsetBorderTopRight", "InsetBorderBottomLeft", "InsetBorderBottomRight",
	"InsetBorderTop", "InsetBorderBottom", "InsetBorderLeft", "InsetBorderRight",
}


local TITLE_SUBLEVEL = 7



function A.windowTitle(frame)
	local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	title:SetDrawLayer("OVERLAY", TITLE_SUBLEVEL)
	return title
end


local chromed = {}


local function ensureTextures(frame)
	if frame.styleBg then
		return
	end

	frame.styleBg = frame:CreateTexture(nil, "BACKGROUND", nil, -7)
	frame.styleBg:SetAllPoints(frame)

	frame.styleTitle = frame:CreateTexture(nil, "BACKGROUND", nil, -6)
	frame.styleTitle:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
	frame.styleTitle:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
	frame.styleTitle:SetHeight(24)


	frame.styleEdges = {}
	for i = 1, 4 do
		frame.styleEdges[i] = frame:CreateTexture(nil, "BORDER")
	end
	local e = frame.styleEdges
	e[1]:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
	e[1]:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
	e[1]:SetHeight(1)
	e[2]:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
	e[2]:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
	e[2]:SetHeight(1)
	e[3]:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
	e[3]:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
	e[3]:SetWidth(1)
	e[4]:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
	e[4]:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
	e[4]:SetWidth(1)
end



function A.registerChrome(frame)
	if type(frame) ~= "table" then
		return false
	end

	for i = 1, #chromed do
		if chromed[i] == frame then
			A.applyChrome()
			return false
		end
	end

	chromed[#chromed + 1] = frame
	A.applyChrome()
	return true
end



function A.applyChrome()

	if #chromed == 0 then
		return false
	end

	local painted = 0
	for index = 1, #chromed do
		local frame = chromed[index]
		local ok = pcall(function()
			ensureTextures(frame)
			local flat = A.theme() == "flat"

			for i = 1, #TEMPLATE_ART do
				local region = frame[TEMPLATE_ART[i]]
				if type(region) == "table" and region.SetShown then
					region:SetShown(not flat)
				end
			end

			frame.styleBg:SetShown(flat)
			frame.styleTitle:SetShown(flat)
			for i = 1, #frame.styleEdges do
				frame.styleEdges[i]:SetShown(flat)
			end

			if flat then
				frame.styleBg:SetColorTexture(A.color("panel"))
				frame.styleTitle:SetColorTexture(A.color("titleBar"))
				for i = 1, #frame.styleEdges do
					frame.styleEdges[i]:SetColorTexture(A.color("hairline"))
				end
			end
		end)

		if ok then
			painted = painted + 1
		end
	end

	return painted == #chromed
end
