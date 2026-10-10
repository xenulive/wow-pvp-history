









local _, A = ...





local CAP = 10


local TICK = 0.25



local BEAT = 1


local PREVIEW_SECONDS = 6

local SAVING_TEXT = "Saving the match"
local SAVED_TEXT = "Saved"


local overlay



local held




local heldFrom


local savedUntil


local lastText
local savedDrawn = false




local preview
local standIn





function A.holdEnabled()
	local db = A.db()
	if not db then
		return true
	end
	db.ui = db.ui or {}
	return db.ui.hold ~= false
end


function A.setHold(enabled)
	local db = A.db()
	if not db then
		return false
	end
	db.ui = db.ui or {}
	if enabled == false then
		db.ui.hold = false
	else
		db.ui.hold = nil
	end


	if A.notifyHoldSetting then
		A.notifyHoldSetting()
	end
	return true
end





local function leaveButton()
	local results = PVPMatchResults
	if type(results) ~= "table" then
		return nil
	end
	local container = results.buttonContainer
	if type(container) ~= "table" then
		return nil, results
	end
	local button = container.leaveButton
	if type(button) ~= "table" then
		return nil, results, container
	end
	return button, results, container
end







local function build(button, parent)
	if type(CreateFrame) ~= "function" then
		return false
	end

	if not overlay then
		local ok, made = pcall(CreateFrame, "Frame", nil, parent)
		if not ok or type(made) ~= "table" then
			return false
		end
		overlay = made


		pcall(overlay.EnableMouse, overlay, true)

		local texture = overlay.CreateTexture and overlay:CreateTexture(nil, "OVERLAY")
		if type(texture) == "table" then
			pcall(texture.SetAllPoints, texture, overlay)
			overlay.scrim = texture
		end


		local words = overlay.CreateFontString and overlay:CreateFontString(nil, "OVERLAY")
		if type(words) == "table" then
			pcall(words.SetJustifyH, words, "CENTER")
			overlay.label = words
		end
		local seconds = overlay.CreateFontString and overlay:CreateFontString(nil, "OVERLAY")
		if type(seconds) == "table" then
			pcall(seconds.SetJustifyH, seconds, "LEFT")
			overlay.seconds = seconds
		end


		local line = overlay.CreateTexture and overlay:CreateTexture(nil, "OVERLAY", nil, 1)
		if type(line) == "table" then
			pcall(line.SetPoint, line, "BOTTOMLEFT", overlay, "BOTTOMLEFT", 0, 0)
			pcall(line.SetHeight, line, A.metric("holdLine"))
			overlay.line = line
		end
	end

	pcall(overlay.SetParent, overlay, parent)
	pcall(overlay.ClearAllPoints, overlay)
	pcall(overlay.SetAllPoints, overlay, button)
	return true
end


local function lift(button)
	if not (overlay and type(button) == "table") then
		return
	end
	local ok, level = pcall(button.GetFrameLevel, button)
	if ok and type(level) == "number" then
		pcall(overlay.SetFrameLevel, overlay, level + 10)
	end
end


local function countdown(remaining)
	if type(remaining) ~= "number" or remaining < 0 then
		remaining = 0
	end
	return ("%ds"):format(math.ceil(remaining))
end


local function coverWidth()
	if not overlay then
		return nil
	end
	local ok, width = pcall(overlay.GetWidth, overlay)
	if ok and A.canRead(width) and type(width) == "number" and width > 0 then
		return width
	end
	return nil
end


local function layout(wordsText, wordsTone, secondsText, secondsTone)
	local words, seconds = overlay.label, overlay.seconds
	if type(words) ~= "table" then
		return
	end
	pcall(A.style, words, "note", wordsTone)
	pcall(words.SetText, words, wordsText)
	local wordsWidth = A.textRoom(words, wordsText)
	pcall(words.SetWidth, words, wordsWidth)
	pcall(words.ClearAllPoints, words)
	if type(seconds) ~= "table" or secondsText == nil then
		pcall(words.SetPoint, words, "CENTER", overlay, "CENTER", 0, 0)
		if type(seconds) == "table" then
			pcall(seconds.SetText, seconds, "")
			pcall(seconds.Hide, seconds)
		end
		return
	end
	pcall(A.style, seconds, "numberSmall", secondsTone)
	pcall(seconds.SetText, seconds, secondsText)
	local secondsWidth = A.textRoom(seconds, secondsText)
	pcall(seconds.SetWidth, seconds, secondsWidth)
	local gap = A.metric("holdGap")
	pcall(words.SetPoint, words, "CENTER", overlay, "CENTER", -(gap + secondsWidth) / 2, 0)
	pcall(seconds.ClearAllPoints, seconds)
	pcall(seconds.SetPoint, seconds, "LEFT", words, "RIGHT", gap, 0)
	pcall(seconds.Show, seconds)
end



local function drawSaving(elapsed)
	if not overlay then
		return nil
	end
	if overlay.scrim then

		pcall(overlay.scrim.SetColorTexture, overlay.scrim, 0, 0, 0, 0.72)
	end
	local secondsText = countdown(CAP - (elapsed or 0))
	layout(SAVING_TEXT, "bright", secondsText, "accent")

	local line = overlay.line
	if type(line) == "table" then
		local width = coverWidth()
		local share = math.min(math.max((elapsed or 0) / CAP, 0), 1)


		if width ~= nil and width * share >= 1 then
			local r, g, b = A.color("accent")
			pcall(line.SetColorTexture, line, r, g, b, 1)
			pcall(line.SetWidth, line, width * share)
			pcall(line.Show, line)
		else
			pcall(line.Hide, line)
		end
	end
	lastText = SAVING_TEXT .. " " .. secondsText
	return lastText
end



local function drawSaved(id)
	if not overlay then
		return nil
	end
	if overlay.scrim then
		local r, g, b, a = A.color("savedGround")
		pcall(overlay.scrim.SetColorTexture, overlay.scrim, r, g, b, a)
	end
	local number = id ~= nil and ("#" .. tostring(id)) or nil
	layout(SAVED_TEXT, "win", number, "win")
	if type(overlay.line) == "table" then
		pcall(overlay.line.Hide, overlay.line)
	end
	lastText = number and (SAVED_TEXT .. " " .. number) or SAVED_TEXT
	return lastText
end







local function standInFrame()
	if standIn then
		return standIn
	end
	if type(CreateFrame) ~= "function" or UIParent == nil then
		return nil
	end
	local ok, made = pcall(CreateFrame, "Frame", "WowPvpHistoryHoldStandIn", UIParent)
	if not ok or type(made) ~= "table" then
		return nil
	end
	pcall(made.SetFrameStrata, made, "DIALOG")
	pcall(made.SetPoint, made, "CENTER", UIParent, "CENTER", 0, 0)
	local ground = made.CreateTexture and made:CreateTexture(nil, "BACKGROUND")
	if type(ground) == "table" then
		pcall(ground.SetAllPoints, ground, made)
		local r, g, b = A.color("field")
		pcall(ground.SetColorTexture, ground, r, g, b, 1)
	end

	local okWord, word = pcall(rawget, _G, "PVP_MATCH_LEAVE_BUTTON")
	if not (okWord and type(word) == "string" and word ~= "") then
		word = "Leave Match"
	end
	local width = A.metric("holdStandInMargin")
	local label = made.CreateFontString and made:CreateFontString(nil, "ARTWORK")
	if type(label) == "table" then
		pcall(A.style, label, "label", "text")
		pcall(label.SetPoint, label, "CENTER", made, "CENTER", 0, 0)
		pcall(label.SetText, label, word)
		width = width + A.textRoom(label, word)
	end
	pcall(made.SetSize, made, width, A.metric("holdStandInHeight"))
	standIn = made
	return standIn
end


local function endPreview(why)
	if preview == nil then
		return false
	end
	preview = nil
	if overlay then
		pcall(overlay.Hide, overlay)
	end
	if standIn then
		pcall(standIn.Hide, standIn)
	end
	A.trace("hold/preview", { state = "off", reason = why })
	return true
end




function A.holdPreview(word, seconds)
	if word == "off" then
		if endPreview("off") then
			return "off"
		end
		return nil, "none"
	end
	if word ~= "saving" and word ~= "saved" then
		return nil, "word"
	end

	if held then
		return nil, "holding"
	end

	local left
	local id
	if word == "saving" then
		left = seconds == nil and PREVIEW_SECONDS or tonumber(seconds)
		if left == nil or left ~= left or left < 0 or left > CAP then
			return nil, "seconds"
		end
	else
		local newest = A.lastMatch()
		if newest == nil or newest.id == nil then
			return nil, "no-match"
		end
		id = newest.id
	end

	local frame = standInFrame()
	if not frame or not build(frame, frame) then
		return nil, "no-frame"
	end
	pcall(frame.Show, frame)
	lift(frame)

	local text
	if word == "saving" then
		text = drawSaving(CAP - left)
	else
		text = drawSaved(id)
	end
	preview = { state = word, text = text }
	pcall(overlay.Show, overlay)
	A.trace("hold/preview", { state = word, text = text })
	return word
end


function A.holdPreviewState()
	return preview
end


function A.holdStandIn()
	return standIn
end





local function since(from)
	local now = A.precise and A.precise()
	if type(now) == "number" and type(from) == "number" then
		return now - from
	end
	return nil
end



local function release(why)
	if not held then
		return false
	end
	local from = heldFrom
	local text, saved = lastText, savedDrawn
	held, heldFrom, savedUntil = nil, nil, nil
	lastText, savedDrawn = nil, false

	if overlay then
		pcall(overlay.Hide, overlay)
	end

	A.trace("hold/release", { source = why, off = since(from), text = text, saved = saved })
	return true
end


local function schedule(record, check)
	if C_Timer and C_Timer.After then
		C_Timer.After(TICK, function()
			check(record)
		end)
	end
end



local function tick(record)
	if held ~= record then
		return
	end
	local elapsed = since(heldFrom)
	local button = leaveButton()

	if savedUntil ~= nil then
		if type(elapsed) ~= "number" or elapsed >= savedUntil then
			release("stored")
			return
		end
		lift(button)
		schedule(record, tick)
		return
	end

	local db = A.db()
	if not db or db.active ~= record then
		if record.id ~= nil and type(elapsed) == "number" and CAP - elapsed >= BEAT then
			savedUntil = elapsed + BEAT
			savedDrawn = true
			drawSaved(record.id)
			lift(button)
			schedule(record, tick)
			return
		end
		release(record.id and "stored" or "dropped")
		return
	end

	if type(elapsed) ~= "number" or elapsed >= CAP then
		release("cap")
		return
	end

	lift(button)
	drawSaving(elapsed)
	schedule(record, tick)
end




function A.armHold(record)
	if type(record) ~= "table" then
		return "no-record"
	end
	if not A.holdEnabled() then
		return "off"
	end
	if not (C_Timer and C_Timer.After) then

		return "no-timer"
	end

	local db = A.db()
	if not db or db.active ~= record or record.id ~= nil then
		return "not-in-flight"
	end


	if held == record then
		return "already-held"
	end


	local from = record.completedPrecise
	if type(since(from)) ~= "number" then
		return "no-clock"
	end

	local button, results, container = leaveButton()
	if not button then
		return (results and (container and "no-button" or "no-container")) or "no-results"
	end


	endPreview("arm")

	if not build(button, container) then
		return "no-frame"
	end


	if held and held ~= record then
		release("superseded")
	end

	held, heldFrom = record, from
	savedUntil, savedDrawn = nil, false
	lift(button)

	drawSaving(since(from) or 0)
	pcall(overlay.Show, overlay)

	schedule(record, tick)

	return "armed"
end




function A.holdAtTransition(record)
	local ok, why = pcall(A.armHold, record)
	if not ok then
		A.noteError(why, "hold-arm")
		why = "threw"
	end

	A.trace("hold/arm", { source = why, ceiling = CAP })
	return why
end


function A.holdCap()
	return CAP
end



A.holdCountdown = countdown

function A.holdOverlay()
	return overlay
end


function A.holdRecord()
	return held
end
