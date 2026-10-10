














local _, A = ...







local controls = {}


local function isOff(button)
	if button.IsEnabled then
		local ok, enabled = pcall(button.IsEnabled, button)
		if ok then
			return not enabled
		end
	end
	return false
end




local function paintSurface(button, off)
	button.bg:SetColorTexture(A.color("panelDeep"))
	for i = 1, #button.edges do
		button.edges[i]:SetColorTexture(A.color("hairline"))
	end



	button.wash:SetColorTexture(A.color("hover"))
	if off then
		button.wash:Hide()
	end


	if button.controlDown and not off then
		button.bg:SetColorTexture(A.color("field"))
	end


	local selected = button.controlSelected == true and not off
	if selected then
		button.bg:SetColorTexture(A.color("field"))
	end
	if selected and button.foot == nil then
		button.foot = button:CreateTexture(nil, "OVERLAY")
		button.foot:SetPoint("BOTTOMLEFT", button, "BOTTOMLEFT", 0, 0)
		button.foot:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 0, 0)
		button.foot:SetHeight(2)
	end
	if button.foot ~= nil then
		button.foot:SetColorTexture(A.color("accent"))
		button.foot:SetShown(selected)
	end
end


local function paintPill(button)
	local off = isOff(button)

	paintSurface(button, off)

	local label = button.controlLabel
	local tone = off and "dimmer" or (button.controlOver and "bright" or "text")

	if not off and not button.controlOver and button.controlTone then
		tone = button.controlTone
	end


	if not off and button.controlSelected == true then
		tone = "bright"
	end

	A.style(label, button.controlRole or "bodyMedium", tone)
end


local function paintCheck(button)
	local off = isOff(button)

	paintSurface(button, off)


	local on = false
	if button.GetChecked then
		local ok, checked = pcall(button.GetChecked, button)
		on = (ok and checked) and true or false
	end

	button.mark:SetColorTexture(A.color(off and "dimmer" or "accent"))
	button.mark:SetShown(on)
end



local function paintTab(button)
	local chosen = button.tabSelected and true or false

	button.rule:SetColorTexture(A.color("accent"))
	button.rule:SetShown(chosen)

	button.wash:SetColorTexture(A.color("hover"))
	if chosen then
		button.wash:Hide()
	end


	local role = chosen and "bodyMedium" or "bodyText"
	local tone = chosen and "bright" or (button.controlOver and "text" or "dim")

	if button.tabEmpty and not chosen and not button.controlOver then
		tone = "dimmer"
	end
	A.style(button.controlLabel, role, tone)
end



local PANEL_TAB_IDLE = { "Left", "Middle", "Right" }
local PANEL_TAB_ACTIVE = { "LeftActive", "MiddleActive", "RightActive" }
local PANEL_TAB_HOVER = { "LeftHighlight", "MiddleHighlight", "RightHighlight" }

local function showArt(button, keys, shown)
	for i = 1, #keys do
		local region = button[keys[i]]
		if type(region) == "table" and region.SetShown then
			region:SetShown(shown)
		end
	end
end




local function paintPanelTab(button)
	local chosen = button.tabSelected and true or false
	local flat = A.theme() == "flat"

	showArt(button, PANEL_TAB_IDLE, not flat and not chosen)
	showArt(button, PANEL_TAB_ACTIVE, not flat and chosen)
	showArt(button, PANEL_TAB_HOVER, not flat)
	button.Text:SetShown(not flat)
	button.Text:ClearAllPoints()
	button.Text:SetPoint("CENTER", button, "CENTER", 0, chosen and -3 or 2)

	local top = chosen and 0 or -A.metric("panelTabOverlap")
	button.flatBg:ClearAllPoints()
	button.flatBg:SetPoint("TOPLEFT", button, "TOPLEFT", 0, top)
	button.flatBg:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 0, 0)
	button.flatBg:SetColorTexture(A.color(chosen and "panel" or "panelDeep"))
	button.flatBg:SetShown(flat)

	button.flatWash:SetColorTexture(A.color("hover"))
	button.flatWash:SetShown(flat and not chosen and button.controlOver and true or false)


	local e = button.flatEdges
	e[1]:ClearAllPoints()
	e[1]:SetPoint("TOPLEFT", button, "TOPLEFT", 0, top)
	e[1]:SetPoint("BOTTOMLEFT", button, "BOTTOMLEFT", 0, 0)
	e[2]:ClearAllPoints()
	e[2]:SetPoint("TOPRIGHT", button, "TOPRIGHT", 0, top)
	e[2]:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 0, 0)
	for i = 1, #e do
		e[i]:SetColorTexture(A.color("hairline"))
		e[i]:SetShown(flat)
	end

	button.flatLabel:SetShown(flat)
	button.flatLabel:ClearAllPoints()
	button.flatLabel:SetPoint("CENTER", button, "CENTER", 0, top / 2)
	A.style(button.flatLabel, chosen and "bodyMedium" or "bodyText",
		chosen and "bright" or (button.controlOver and "text" or "dim"))
end


local function paintSegmentTrack(track)
	track.bg:SetColorTexture(A.color("panelDeep"))
end


local function paintSegment(button)
	local chosen = button.segmentChosen and true or false


	button.bg:SetColorTexture(A.color("selection"))
	button.bg:SetShown(chosen)



	button.rule:SetColorTexture(A.color("accent"))
	button.rule:SetShown(chosen)

	button.wash:SetColorTexture(A.color("hover"))
	if chosen then
		button.wash:Hide()
	end


	local tone = chosen and "bright" or (button.controlOver and "text" or "dim")
	if button.segmentUnreachable and not chosen then
		tone = "dimmer"
	end
	A.style(button.controlLabel, "label", tone)
end


local function paintEntry(box)
	box.bg:SetColorTexture(A.color("field"))

	local edge = box.controlFocused and "accent" or "hairline"
	for i = 1, #box.edges do
		box.edges[i]:SetColorTexture(A.color(edge))
	end


	A.style(box, "bodyText", "text")


	if box.controlPlaceholder then
		local ok, held = pcall(box.GetText, box)
		local empty = not (ok and type(held) == "string" and held ~= "")
		box.controlPlaceholder:SetShown(empty and not box.controlFocused)
		A.style(box.controlPlaceholder, "bodyText", "dimmer")
	end
end


local function paintChip(button)
	local off = isOff(button)

	paintSurface(button, off)

	local members = button.chipMembers or {}
	for i = 1, #button.chipSwatches do
		if members[i] then
			button.chipSwatches[i]:SetColorTexture(A.classColor(members[i].classToken))
			A.style(button.chipLabels[i], "bodyText", off and "dimmer" or "text")
		end
	end


	A.style(button.chipClear, "label", (off or not button.controlOver) and "dimmer" or "accent")
end




local function paintDropdown(button)
	local off = isOff(button)
	paintSurface(button, off)

	local tone = "text"
	if off then
		tone = "dimmer"
	elseif button.chosenUnreachable then

		tone = "dim"
	elseif button.controlOver then
		tone = "bright"
	end
	A.style(button.label, "bodyText", tone)
	button.caret:SetColorTexture(A.color(off and "dimmer" or "dim"))

	if button.panel then
		button.panel.bg:SetColorTexture(A.color("menuGround"))
		for i = 1, #button.panel.edges do
			button.panel.edges[i]:SetColorTexture(A.color("hairline"))
		end
		for i = 1, #button.rows do
			local row = button.rows[i]
			row.bg:SetColorTexture(A.color("selection"))
			row.wash:SetColorTexture(A.color("hover"))

			local rowTone = "text"
			if row.dropdownChosen then
				rowTone = "bright"
			elseif row.dropdownReason then
				rowTone = "dimmer"
			end
			A.style(row.label, "bodyText", rowTone)
		end
	end
end


local function paintGrip(button)
	local tone = button.gripHot and "text" or "dimmer"
	for i = 1, #button.strokes do
		button.strokes[i]:SetColorTexture(A.color(tone))
	end
end



local function paint(button)
	return pcall(function()
		if button.controlKind == "tab" then
			paintTab(button)
		elseif button.controlKind == "panelTab" then
			paintPanelTab(button)
		elseif button.controlKind == "check" then
			paintCheck(button)
		elseif button.controlKind == "segment" then
			paintSegment(button)
		elseif button.controlKind == "segmentTrack" then
			paintSegmentTrack(button)
		elseif button.controlKind == "entry" then
			paintEntry(button)
		elseif button.controlKind == "chip" then
			paintChip(button)
		elseif button.controlKind == "grip" then
			paintGrip(button)
		elseif button.controlKind == "dropdown" then
			paintDropdown(button)
		else
			paintPill(button)
		end
	end)
end



function A.registerControl(button)
	if type(button) ~= "table" or not button.controlKind then
		return false
	end

	for i = 1, #controls do
		if controls[i] == button then
			paint(button)
			return false
		end
	end

	controls[#controls + 1] = button
	paint(button)
	return true
end



function A.applyControls()
	if #controls == 0 then
		return false
	end

	local painted = 0
	for i = 1, #controls do
		if paint(controls[i]) then
			painted = painted + 1
		end
	end
	return painted == #controls
end




local function attachLabel(button)
	local label = button:CreateFontString(nil, "OVERLAY")
	label:SetPoint("CENTER", button, "CENTER", 0, 0)
	label:SetJustifyH("CENTER")
	label:SetWordWrap(false)
	button:SetFontString(label)
	button.controlLabel = label
	return label
end



local function attachSurface(button, plain)
	button.bg = button:CreateTexture(nil, "BACKGROUND")
	button.bg:SetAllPoints(button)

	button.edges = {}
	for i = 1, 4 do
		button.edges[i] = button:CreateTexture(nil, "BORDER")
	end
	local e = button.edges
	e[1]:SetPoint("TOPLEFT")
	e[1]:SetPoint("TOPRIGHT")
	e[1]:SetHeight(1)
	e[2]:SetPoint("BOTTOMLEFT")
	e[2]:SetPoint("BOTTOMRIGHT")
	e[2]:SetHeight(1)
	e[3]:SetPoint("TOPLEFT")
	e[3]:SetPoint("BOTTOMLEFT")
	e[3]:SetWidth(1)
	e[4]:SetPoint("TOPRIGHT")
	e[4]:SetPoint("BOTTOMRIGHT")
	e[4]:SetWidth(1)

	if plain then
		return
	end

	button.wash = button:CreateTexture(nil, "ARTWORK")
	button.wash:SetAllPoints(button)
	button.wash:Hide()
end





local function attachStates(button)
	button:SetScript("OnEnter", function(self)
		self.controlOver = true
		if not isOff(self) then
			self.wash:Show()
		end
		paint(self)
	end)
	button:SetScript("OnLeave", function(self)
		self.controlOver = false
		self.wash:Hide()
		paint(self)
	end)
	button:SetScript("OnMouseDown", function(self)
		self.controlDown = true
		paint(self)
	end)
	button:SetScript("OnMouseUp", function(self)
		self.controlDown = false
		paint(self)
	end)


	button:SetScript("OnEnable", paint)
	button:SetScript("OnDisable", paint)
end


local function stringWidth(fontString)
	if type(fontString) ~= "table" or not fontString.GetStringWidth then
		return 0
	end
	local ok, width = pcall(fontString.GetStringWidth, fontString)
	if not ok or type(width) ~= "number" or width < 0 then
		return 0
	end
	return width
end



function A.fitControl(button, minWidth, padding)
	local pad = padding or A.metric("pillPad")
	local floor = minWidth or A.metric("pillMin")
	local text = 0
	if button.GetTextWidth then
		local ok, width = pcall(button.GetTextWidth, button)
		if ok and type(width) == "number" then
			text = width
		end
	end
	button:SetWidth(math.max(floor, text + pad))
	return button:GetWidth() or floor
end


function A.pill(parent, text, onClick, minWidth)
	local button = CreateFrame("Button", nil, parent)
	button.controlKind = "pill"
	button:SetHeight(A.metric("controlHeight"))

	attachSurface(button)
	attachLabel(button)
	attachStates(button)

	if text then
		button:SetText(text)
	end
	if onClick then
		button:SetScript("OnClick", onClick)
	end


	A.registerControl(button)
	A.fitControl(button, minWidth)
	return button
end


function A.setControlTone(button, tone)
	if type(button) ~= "table" or not button.controlKind then
		return false
	end
	button.controlTone = tone
	paint(button)
	return true
end



function A.setPillSelected(button, selected)
	if type(button) ~= "table" or not button.controlKind then
		return false
	end
	button.controlSelected = selected and true or false
	paint(button)
	return true
end



local function attachCheckedHook(button)
	local base = button.SetChecked
	if type(base) ~= "function" then
		return false
	end

	button.SetChecked = function(self, on)
		base(self, on)
		paint(self)
	end
	return true
end


function A.check(parent)
	local button = CreateFrame("CheckButton", nil, parent)
	button.controlKind = "check"

	button:SetSize(A.metric("controlHeight"), A.metric("controlHeight"))

	attachSurface(button)


	button.mark = button:CreateTexture(nil, "OVERLAY")
	local inset = A.metric("checkMarkInset")
	button.mark:SetPoint("TOPLEFT", button, "TOPLEFT", inset, -inset)
	button.mark:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -inset, inset)
	button.mark:Hide()

	attachStates(button)
	attachCheckedHook(button)

	A.registerControl(button)
	return button
end



function A.entry(parent)
	local box = CreateFrame("EditBox", nil, parent)
	box.controlKind = "entry"

	box:SetAutoFocus(false)

	box:SetTextInsets(A.metric("entryInsetX"), A.metric("entryInsetX"),
		A.metric("entryInsetY"), A.metric("entryInsetY"))

	attachSurface(box, true)

	box:SetScript("OnEditFocusGained", function(self)
		self.controlFocused = true
		paint(self)
	end)
	box:SetScript("OnEditFocusLost", function(self)
		self.controlFocused = false
		paint(self)
	end)

	A.registerControl(box)
	return box
end



function A.entryPlaceholder(box, text)
	if not box or type(text) ~= "string" then
		return false
	end

	box.controlPlaceholder = box.controlPlaceholder
		or box:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
	box.controlPlaceholder:ClearAllPoints()
	box.controlPlaceholder:SetPoint("LEFT", box, "LEFT", A.metric("entryInsetX"), 0)
	box.controlPlaceholder:SetPoint("RIGHT", box, "RIGHT", -A.metric("entryInsetX"), 0)
	box.controlPlaceholder:SetJustifyH("LEFT")
	box.controlPlaceholder:SetWordWrap(false)
	box.controlPlaceholder:SetText(text)

	pcall(box.HookScript, box, "OnTextChanged", function(self)
		paint(self)
	end)
	paint(box)
	return true
end



function A.filterChip(parent, onClear)
	local chip = CreateFrame("Button", nil, parent)
	chip.controlKind = "chip"
	chip:SetHeight(A.metric("controlHeight"))

	attachSurface(chip)
	attachStates(chip)

	chip.chipSwatches, chip.chipLabels = {}, {}
	for i = 1, 3 do
		local swatch = chip:CreateTexture(nil, "ARTWORK")
		swatch:SetSize(A.metric("compSwatch"), A.metric("compSwatch"))
		local label = chip:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
		label:SetJustifyH("LEFT")
		label:SetWordWrap(false)

		if i == 1 then
			swatch:SetPoint("LEFT", chip, "LEFT", A.metric("chipPad"), 0)
		else
			swatch:SetPoint("LEFT", chip.chipLabels[i - 1], "RIGHT", A.metric("compChipGap"), 0)
		end
		label:SetPoint("LEFT", swatch, "RIGHT", 4, 0)

		chip.chipSwatches[i], chip.chipLabels[i] = swatch, label
	end

	chip.chipClear = chip:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	chip.chipClear:SetJustifyH("LEFT")
	chip.chipClear:SetWordWrap(false)
	chip.chipClear:SetText("clear")

	if onClear then
		chip:SetScript("OnClick", onClear)
	end

	A.registerControl(chip)
	return chip
end



function A.setChipComp(chip, members)
	if type(chip) ~= "table" or chip.controlKind ~= "chip" then
		return 0
	end

	chip.chipMembers = type(members) == "table" and members or nil
	local held = chip.chipMembers or {}

	local last = nil
	for i = 1, #chip.chipSwatches do
		local m = held[i]
		chip.chipSwatches[i]:SetShown(m ~= nil)
		chip.chipLabels[i]:SetShown(m ~= nil)
		if m ~= nil then

			chip.chipLabels[i]:SetText(A.chipText(m))
			last = chip.chipLabels[i]
		end
	end


	chip.chipClear:ClearAllPoints()
	if last then
		chip.chipClear:SetPoint("LEFT", last, "RIGHT", A.metric("chipGap"), 0)
	else
		chip.chipClear:SetPoint("LEFT", chip, "LEFT", A.metric("chipPad"), 0)
	end
	chip.chipClear:SetShown(last ~= nil)

	paint(chip)


	local width = A.metric("chipPad") * 2
	for i = 1, #chip.chipSwatches do
		if held[i] ~= nil then
			local label = chip.chipLabels[i]
			local okWide, wide = pcall(label.GetUnboundedStringWidth, label)
			width = width + ((okWide and type(wide) == "number") and wide or stringWidth(label))
				+ A.metric("compSwatch") + 4
			if i > 1 then
				width = width + A.metric("compChipGap")
			end
		end
	end
	if last then
		width = width + A.metric("chipGap") + stringWidth(chip.chipClear)
	end

	chip:SetWidth(width)
	return width
end


function A.tab(parent, text, onClick)
	local button = CreateFrame("Button", nil, parent)
	button.controlKind = "tab"
	button:SetHeight(A.metric("filterHeight"))

	button.wash = button:CreateTexture(nil, "BACKGROUND")
	button.wash:SetPoint("TOPLEFT")
	button.wash:SetPoint("TOPRIGHT")
	button.wash:SetPoint("BOTTOM", button, "BOTTOM", 0, A.metric("tabUnderline"))
	button.wash:Hide()

	button.rule = button:CreateTexture(nil, "ARTWORK")
	button.rule:SetPoint("BOTTOMLEFT")
	button.rule:SetPoint("BOTTOMRIGHT")
	button.rule:SetHeight(A.metric("tabUnderline"))
	button.rule:Hide()

	local label = attachLabel(button)

	label:ClearAllPoints()
	label:SetPoint("CENTER", button, "CENTER", 0, A.metric("tabUnderline"))

	attachStates(button)

	if text then
		button:SetText(text)
	end
	if onClick then
		button:SetScript("OnClick", onClick)
	end

	A.registerControl(button)
	A.fitControl(button, A.metric("tabMin"))
	return button
end


function A.setTabSelected(button, selected)
	if type(button) ~= "table" or button.controlKind ~= "tab" then
		return false
	end

	button.tabSelected = selected and true or false
	if button.tabSelected then
		pcall(button.Disable, button)
	else
		pcall(button.Enable, button)
	end
	paint(button)
	return true
end


function A.setTabEmpty(button, empty)
	if type(button) ~= "table" or button.controlKind ~= "tab" then
		return false
	end

	button.tabEmpty = empty and true or false
	paint(button)
	return true
end




function A.fitPanelTab(button)
	local text = stringWidth(button.Text)
	local flat = stringWidth(button.flatLabel)
	button:SetWidth(math.max(text, flat) + A.metric("panelTabPad"))
	return button:GetWidth()
end




function A.panelTab(parent, text, onClick)
	local built, button = pcall(CreateFrame, "Button", nil, parent, "PanelTabButtonTemplate")
	if not built or type(button) ~= "table" then
		button = CreateFrame("Button", nil, parent)
	end
	button.controlKind = "panelTab"
	button:SetHeight(A.metric("panelTabHeight"))

	if type(button.Text) ~= "table" then
		button.Text = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	end
	button.Text:SetText(text)

	button.flatBg = button:CreateTexture(nil, "BACKGROUND")
	button.flatWash = button:CreateTexture(nil, "ARTWORK")
	button.flatWash:SetAllPoints(button.flatBg)
	button.flatEdges = {}
	for i = 1, 3 do
		button.flatEdges[i] = button:CreateTexture(nil, "BORDER")
	end
	button.flatEdges[1]:SetWidth(1)
	button.flatEdges[2]:SetWidth(1)
	button.flatEdges[3]:SetPoint("BOTTOMLEFT")
	button.flatEdges[3]:SetPoint("BOTTOMRIGHT")
	button.flatEdges[3]:SetHeight(1)

	button.flatLabel = button:CreateFontString(nil, "OVERLAY")
	button.flatLabel:SetJustifyH("CENTER")
	button.flatLabel:SetWordWrap(false)

	A.style(button.flatLabel, "bodyText", "dim")
	button.flatLabel:SetText(text)


	local function hook(which, fn)
		if button.HookScript then
			button:HookScript(which, fn)
		else
			button:SetScript(which, fn)
		end
	end
	hook("OnEnter", function(self)
		self.controlOver = true
		paint(self)
	end)
	hook("OnLeave", function(self)
		self.controlOver = false
		paint(self)
	end)
	hook("OnShow", function(self)
		A.fitPanelTab(self)
	end)
	button:SetScript("OnEnable", paint)
	button:SetScript("OnDisable", paint)
	if onClick then
		button:SetScript("OnClick", onClick)
	end

	A.registerControl(button)
	A.fitPanelTab(button)
	return button
end


function A.setPanelTabSelected(button, selected)
	if type(button) ~= "table" or button.controlKind ~= "panelTab" then
		return false
	end

	button.tabSelected = selected and true or false
	if button.tabSelected then
		pcall(button.Disable, button)
	else
		pcall(button.Enable, button)
	end
	paint(button)
	return true
end





function A.segment(parent, choices, onPick)
	local pad = A.metric("segmentTrackPad")

	local track = CreateFrame("Frame", nil, parent)
	track.controlKind = "segmentTrack"
	track:SetHeight(A.metric("segmentHeight") + pad * 2)

	track.bg = track:CreateTexture(nil, "BACKGROUND")
	track.bg:SetAllPoints(track)

	A.registerControl(track)

	track.children = {}
	local x = pad
	for i = 1, #choices do
		local choice = choices[i]

		local chip = CreateFrame("Button", nil, track)
		chip.controlKind = "segment"
		chip.segmentIndex = i
		chip.segmentValue = choice.value
		chip:SetHeight(A.metric("segmentHeight"))


		chip.bg = chip:CreateTexture(nil, "BACKGROUND")
		chip.bg:SetAllPoints(chip)
		chip.bg:Hide()

		chip.wash = chip:CreateTexture(nil, "ARTWORK")
		chip.wash:SetAllPoints(chip)
		chip.wash:Hide()


		chip.rule = chip:CreateTexture(nil, "OVERLAY")
		chip.rule:SetPoint("BOTTOMLEFT", chip, "BOTTOMLEFT", 0, 0)
		chip.rule:SetPoint("BOTTOMRIGHT", chip, "BOTTOMRIGHT", 0, 0)
		chip.rule:SetHeight(A.metric("tabUnderline"))
		chip.rule:Hide()

		attachLabel(chip)
		attachStates(chip)
		chip:SetText(choice.label)


		chip:HookScript("OnEnter", function(self)
			if not (GameTooltip and self.segmentReason) then
				return
			end
			pcall(function()
				GameTooltip:SetOwner(self, "ANCHOR_TOP")
				GameTooltip:SetText(self.segmentReason, 1, 1, 1, 1, true)
				GameTooltip:Show()
			end)
		end)
		chip:HookScript("OnLeave", function()
			if GameTooltip then
				pcall(GameTooltip.Hide, GameTooltip)
			end
		end)

		if onPick then
			chip:SetScript("OnClick", function(self)
				onPick(self.segmentValue, self.segmentIndex)
			end)
		end


		A.registerControl(chip)
		A.fitControl(chip, A.metric("segmentMin"), A.metric("segmentPad"))

		chip:SetPoint("TOPLEFT", track, "TOPLEFT", x, -pad)
		x = x + (chip:GetWidth() or A.metric("segmentMin")) + A.metric("segmentGap")

		track.children[i] = chip
	end


	track:SetWidth(math.max(x - A.metric("segmentGap") + pad, pad * 2))
	return track
end




function A.sectionList(parent, choices, onPick)
	local list = CreateFrame("Frame", nil, parent)


	list.controlKind = "sectionList"
	local row = A.metric("optionsRow")
	local indent = A.metric("sectionIndent")


	local widest = 0
	for i = 1, #choices do
		local room = A.labelRoom(choices[i].label)
		if room > widest then
			widest = room
		end
	end
	list:SetWidth(widest + indent * 2)
	list:SetHeight(row * #choices)


	list.rule = list:CreateTexture(nil, "ARTWORK")
	list.rule:SetPoint("TOPRIGHT", list, "TOPRIGHT", 0, 0)
	list.rule:SetPoint("BOTTOMRIGHT", list, "BOTTOMRIGHT", 0, 0)
	list.rule:SetWidth(1)

	list.children = {}
	for i = 1, #choices do
		local choice = choices[i]

		local button = CreateFrame("Button", nil, list)
		button.controlKind = "segment"
		button.segmentIndex = i
		button.segmentValue = choice.value
		button:SetHeight(row)
		button:SetPoint("TOPLEFT", list, "TOPLEFT", 0, -(i - 1) * row)
		button:SetPoint("TOPRIGHT", list, "TOPRIGHT", 0, -(i - 1) * row)


		button.bg = button:CreateTexture(nil, "BACKGROUND")
		button.bg:SetAllPoints(button)
		button.bg:Hide()

		button.wash = button:CreateTexture(nil, "ARTWORK")
		button.wash:SetAllPoints(button)
		button.wash:Hide()

		button.rule = button:CreateTexture(nil, "OVERLAY")
		button.rule:SetPoint("TOPLEFT", button, "TOPLEFT", 0, 0)
		button.rule:SetPoint("BOTTOMLEFT", button, "BOTTOMLEFT", 0, 0)
		button.rule:SetWidth(A.metric("tabUnderline"))
		button.rule:Hide()

		attachLabel(button)
		attachStates(button)
		button:SetText(choice.label)

		button.controlLabel:ClearAllPoints()
		button.controlLabel:SetPoint("LEFT", button, "LEFT", indent, 0)
		button.controlLabel:SetJustifyH("LEFT")

		if onPick then
			button:SetScript("OnClick", function(self)
				onPick(self.segmentValue, self.segmentIndex)
			end)
		end

		A.registerControl(button)
		list.children[i] = button
	end

	return list
end


local openDropdown = nil




function A.dropdown(parent, choices, onPick)
	local width = A.metric("dropdownWidth")
	local rowHeight = A.metric("dropdownRow")
	local pad = A.metric("dropdownPad")

	local button = CreateFrame("Button", nil, parent)
	button.controlKind = "dropdown"
	button:SetSize(width, A.metric("controlHeight"))
	attachSurface(button)
	attachStates(button)


	button.label = button:CreateFontString(nil, "OVERLAY")
	button.label:SetPoint("LEFT", button, "LEFT", pad * 2, 0)
	button.label:SetPoint("RIGHT", button, "RIGHT", -pad * 2 - A.metric("dropdownCaret"), 0)
	button.label:SetJustifyH("LEFT")
	button.label:SetWordWrap(false)


	button.caret = button:CreateTexture(nil, "OVERLAY")
	button.caret:SetSize(A.metric("dropdownCaret"), A.metric("dropdownCaret"))
	button.caret:SetPoint("RIGHT", button, "RIGHT", -pad * 2, 0)

	local panel = CreateFrame("Frame", nil, parent)
	panel:SetWidth(width)
	panel:SetFrameStrata("DIALOG")
	panel:SetPoint("TOPLEFT", button, "BOTTOMLEFT", 0, -1)
	panel:EnableMouse(true)
	panel:EnableMouseWheel(true)
	panel:Hide()
	attachSurface(panel, true)
	button.panel = panel

	button.choices = choices or {}
	button.offset = 0
	button.rows = {}

	local function close()
		panel:Hide()
		if openDropdown == button then
			openDropdown = nil
		end
	end
	button.closeDropdown = close



	local function sizeToChoices()
		local widest = 0
		for i = 1, #button.choices do
			local room = A.textRoom(button.label, tostring(button.choices[i].label or ""))
			if type(room) == "number" and room > widest then
				widest = room
			end
		end

		local want = widest + pad * 4 + A.metric("dropdownCaret")
		if want < width then
			want = width
		end
		local most = A.metric("dropdownWidthMax")
		if most > 0 and want > most then
			want = most
		end

		button:SetWidth(want)
		panel:SetWidth(want)
	end


	local function fill()
		local visible = math.min(#button.choices, A.metric("dropdownRows"))
		panel:SetHeight(math.max(visible * rowHeight + pad * 2, rowHeight))
		sizeToChoices()


		local most = math.max(#button.choices - visible, 0)
		if button.offset > most then
			button.offset = most
		end
		if button.offset < 0 then
			button.offset = 0
		end

		for i = 1, visible do
			local row = button.rows[i]
			if not row then
				row = CreateFrame("Button", nil, panel)
				row:SetHeight(rowHeight)
				row:SetPoint("TOPLEFT", panel, "TOPLEFT", pad, -pad - (i - 1) * rowHeight)
				row:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -pad, -pad - (i - 1) * rowHeight)

				row.bg = row:CreateTexture(nil, "BACKGROUND")
				row.bg:SetAllPoints(row)
				row.bg:Hide()
				row.wash = row:CreateTexture(nil, "ARTWORK")
				row.wash:SetAllPoints(row)
				row.wash:Hide()

				row.label = row:CreateFontString(nil, "OVERLAY")
				row.label:SetPoint("LEFT", row, "LEFT", pad, 0)
				row.label:SetPoint("RIGHT", row, "RIGHT", -pad, 0)
				row.label:SetJustifyH("LEFT")
				row.label:SetWordWrap(false)


				A.style(row.label, "bodyText", "text")


				row:SetScript("OnEnter", function(self)
					self.wash:Show()
					if GameTooltip and self.dropdownReason then
						pcall(function()
							GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
							GameTooltip:SetText(self.dropdownReason, 1, 1, 1, 1, true)
							GameTooltip:Show()
						end)
					end
				end)
				row:SetScript("OnLeave", function(self)
					self.wash:Hide()
					if GameTooltip and self.dropdownReason then
						pcall(GameTooltip.Hide, GameTooltip)
					end
				end)


				row:SetScript("OnClick", function(self)
					close()
					if onPick and self.dropdownFilled then
						onPick(self.dropdownValue, self.dropdownIndex)
					end
				end)
				button.rows[i] = row
			end

			local choice = button.choices[i + button.offset]
			if choice then
				row.dropdownValue = choice.value
				row.dropdownIndex = i + button.offset

				row.dropdownFilled = true
				row.dropdownChosen = choice.value == button.chosen
				row.dropdownReason = type(choice.unreachable) == "string" and choice.unreachable or nil
				row.label:SetText(tostring(choice.label or ""))
				row.bg:SetShown(row.dropdownChosen)
				row:Show()
			else
				row.dropdownFilled = false
				row.dropdownReason = nil
				row:Hide()
			end
		end
		for i = visible + 1, #button.rows do
			button.rows[i].dropdownFilled = false
			button.rows[i].dropdownReason = nil
			button.rows[i]:Hide()
		end
		paint(button)
	end
	button.fillDropdown = fill

	panel:SetScript("OnMouseWheel", function(_, delta)
		button.offset = button.offset - (type(delta) == "number" and delta or 0)
		fill()
	end)


	local function open()
		if openDropdown ~= nil and openDropdown ~= button and openDropdown.closeDropdown then
			openDropdown.closeDropdown()
		end
		fill()
		panel:Show()
		openDropdown = button
	end
	button.openDropdown = open

	button:SetScript("OnClick", function()
		if panel:IsShown() then
			close()
			return
		end
		open()
	end)

	A.registerControl(button)
	fill()
	return button
end



function A.setDropdownChoices(button, choices, chosen)
	if type(button) ~= "table" or button.controlKind ~= "dropdown" then
		return false
	end

	button.choices = type(choices) == "table" and choices or {}
	button.chosen = chosen

	local found, label, unreachable = false, nil, false
	for i = 1, #button.choices do
		if button.choices[i].value == chosen then
			found = true
			label = button.choices[i].label
			unreachable = type(button.choices[i].unreachable) == "string"
		end
	end
	button.chosenUnreachable = unreachable
	if not found and #button.choices > 0 then
		label = button.choices[1].label
	end
	button.label:SetText(tostring(label or ""))

	if button.fillDropdown then
		button.fillDropdown()
	end
	return found
end




function A.grip(parent, onStop, onPress, onStarted)
	local size = A.metric("gripSize")

	local grip = CreateFrame("Frame", nil, parent)
	grip.controlKind = "grip"
	grip:SetSize(size, size)
	grip:EnableMouse(true)


	grip.strokes = {}
	local inset, stroke, step = A.metric("gripInset"), A.metric("gripStroke"), A.metric("gripStrokeGap")
	for i = 1, 3 do
		local mark = grip:CreateTexture(nil, "ARTWORK")
		mark:SetSize(stroke, stroke)
		mark:SetPoint("BOTTOMRIGHT", grip, "BOTTOMRIGHT", -inset - (i - 1) * step, inset)
		grip.strokes[i] = mark
	end

	grip:SetScript("OnEnter", function(self)
		self.gripHot = true
		paint(self)
	end)
	grip:SetScript("OnLeave", function(self)
		self.gripHot = false
		paint(self)
	end)

	grip:SetScript("OnMouseDown", function(self)
		if onPress then
			pcall(onPress)
		end


		local alwaysStartFromMouse = true
		pcall(parent.StartSizing, parent, "BOTTOMRIGHT", alwaysStartFromMouse)

		if onStarted then
			pcall(onStarted)
		end
	end)
	grip:SetScript("OnMouseUp", function(self)
		pcall(parent.StopMovingOrSizing, parent)


		pcall(parent.SetUserPlaced, parent, false)
		if onStop then
			onStop()
		end
	end)

	A.registerControl(grip)
	return grip
end





function A.setSegmentChosen(track, value)
	if type(track) ~= "table"
		or (track.controlKind ~= "segmentTrack" and track.controlKind ~= "sectionList") then
		return false
	end
	if type(track.children) ~= "table" then
		return false
	end

	local found = false
	for i = 1, #track.children do
		local chip = track.children[i]
		local chosen = chip.segmentValue == value
		chip.segmentChosen = chosen
		found = found or chosen

		if chosen then
			pcall(chip.Disable, chip)
		else
			pcall(chip.Enable, chip)
		end
		paint(chip)
	end
	return found
end




function A.setSegmentUnreachable(track, marks, reason)
	if type(track) ~= "table" or track.controlKind ~= "segmentTrack" then
		return false
	end
	if type(track.children) ~= "table" then
		return false
	end



	local reasons = {}
	if type(marks) == "table" then
		for value, why in pairs(marks) do
			if type(why) == "string" then
				reasons[value] = why
			end
		end
	elseif marks ~= nil and type(reason) == "string" then
		reasons[marks] = reason
	end

	local found = false
	for i = 1, #track.children do
		local chip = track.children[i]
		local why = chip.segmentValue ~= nil and reasons[chip.segmentValue] or nil
		chip.segmentUnreachable = why ~= nil
		chip.segmentReason = why
		found = found or why ~= nil
		paint(chip)
	end
	return found
end



function A.setSegmentWithdrawn(track, values)
	if type(track) ~= "table" or track.controlKind ~= "segmentTrack" then
		return nil
	end
	if type(track.children) ~= "table" then
		return nil
	end
	local gone = type(values) == "table" and values or {}
	local pad = A.metric("segmentTrackPad")
	local gap = A.metric("segmentGap")
	local x, withdrawn = pad, 0
	for i = 1, #track.children do
		local chip = track.children[i]
		local out = chip.segmentValue ~= nil and gone[chip.segmentValue] == true
		chip.segmentWithdrawn = out
		chip:SetShown(not out)
		if out then
			withdrawn = withdrawn + 1
		else
			chip:ClearAllPoints()
			chip:SetPoint("TOPLEFT", track, "TOPLEFT", x, -pad)
			x = x + (chip:GetWidth() or A.metric("segmentMin")) + gap
		end
	end

	track:SetWidth(math.max(x - gap + pad, pad * 2))
	return withdrawn
end





local grounds = {}


local tooltipMeasured = false




local function releaseTooltip()
	local ground = GameTooltip and grounds[GameTooltip]
	if ground then
		pcall(ground.Hide, ground)
	end
	if tooltipMeasured and GameTooltip and type(GameTooltip.SetMinimumWidth) == "function" then
		tooltipMeasured = false
		pcall(GameTooltip.SetMinimumWidth, GameTooltip, 0)
	end
end



local function tooltipGroundFor(tooltip)
	if tooltip == nil then
		return nil
	end
	local held = grounds[tooltip]
	if held ~= nil then
		return held or nil
	end
	grounds[tooltip] = false
	local ok, made = pcall(function()
		if type(tooltip.CreateTexture) ~= "function" then
			return nil
		end
		local ground = tooltip:CreateTexture(nil, "BACKGROUND", nil, -8)
		ground:SetPoint("TOPLEFT", tooltip, "TOPLEFT", 4, -4)
		ground:SetPoint("BOTTOMRIGHT", tooltip, "BOTTOMRIGHT", -4, 4)
		ground:Hide()

		if tooltip == GameTooltip and type(tooltip.HookScript) == "function" then
			tooltip:HookScript("OnHide", releaseTooltip)
		end
		return ground
	end)
	if ok and type(made) == "table" then
		grounds[tooltip] = made
		return made
	end
	return nil
end



local function tooltipGroundColour()
	local held = rawget(_G, "TOOLTIP_DEFAULT_BACKGROUND_COLOR")
	if type(held) == "table" and type(held.GetRGB) == "function" then
		local ok, r, g, b = pcall(held.GetRGB, held)
		if ok and type(r) == "number" and type(g) == "number" and type(b) == "number" then
			return r, g, b
		end
	end
	return 0.09, 0.09, 0.19
end


function A.groundTooltip(tooltip)
	local ground = tooltip ~= nil and tooltipGroundFor(tooltip) or nil
	if not ground then
		return false
	end
	local r, g, b = tooltipGroundColour()
	ground:SetColorTexture(r, g, b, 1)
	ground:Show()
	return true
end



function A.styleTooltip(tooltip)
	if tooltip == nil then
		return false
	end
	local measured = false
	if type(tooltip.SetMinimumWidth) == "function" then
		tooltip:SetMinimumWidth(A.metric("tooltipMeasure"))
		measured = true
	end
	A.groundTooltip(tooltip)
	return measured
end









function A.keyedTooltip(owner, lines, anchor)
	if not (GameTooltip and type(lines) == "table" and #lines > 0) then
		return false
	end
	local pointed = type(anchor) == "table" and type(anchor.point) == "string" and anchor.relativeTo ~= nil
	return (pcall(function()
		if pointed then
			GameTooltip:SetOwner(owner, "ANCHOR_NONE")
			GameTooltip:ClearAllPoints()
			GameTooltip:SetPoint(anchor.point, anchor.relativeTo, anchor.relativePoint or anchor.point,
				anchor.x or 0, anchor.y or 0)
		else
			GameTooltip:SetOwner(owner, type(anchor) == "string" and anchor or "ANCHOR_BOTTOM")
		end
		if A.styleTooltip(GameTooltip) then
			tooltipMeasured = true
		end
		GameTooltip:SetText(lines[1], 1, 0.82, 0, 1, true)

		local longest = #tostring(lines[1])
		for i = 2, #lines do
			local held = lines[i]
			if type(held) == "table" and held.gap then

				GameTooltip:AddLine(" ")
			elseif type(held) == "table" and held.key then


				local text = held.key .. "  " .. tostring(held.text)
				local escape = A.colorEscape(type(held.tone) == "string" and held.tone or "dim")
				GameTooltip:AddLine(escape .. held.key .. "|r  " .. tostring(held.text), 1, 1, 1, true)
				if #text > longest then
					longest = #text
				end
			elseif type(held) == "string" then
				GameTooltip:AddLine(held, 1, 1, 1, true)
				if #held > longest then
					longest = #held
				end
			end
		end
		GameTooltip:Show()



		local used, check = type(anchor) == "string" and anchor or "ANCHOR_BOTTOM", nil
		if pointed then
			used = type(anchor.name) == "string" and anchor.name or "point"
			local flip = anchor.flip
			if type(flip) == "table" and type(flip.point) == "string" and flip.relativeTo ~= nil then
				check = A.tooltipRoomBelow(GameTooltip, anchor)
				if check == "flipped" then
					GameTooltip:ClearAllPoints()
					GameTooltip:SetPoint(flip.point, flip.relativeTo, flip.relativePoint or flip.point,
						flip.x or 0, flip.y or 0)
					used = type(flip.name) == "string" and flip.name or "flip"
				end
			end
		end


		local okWidth, width = pcall(GameTooltip.GetWidth, GameTooltip)
		A.trace("tooltip", {
			source = lines[1],
			lines = #lines,
			longest = longest,
			anchor = used,
			check = check,
			width = okWidth and A.unitFigure(width) or nil,
		}, "ui")
	end))
end





function A.tooltipRoomBelow(tooltip, anchor)
	local relative = type(anchor) == "table" and anchor.relativeTo or nil
	if tooltip == nil or relative == nil then
		return "unread"
	end
	local function figure(frame, getter)
		local fn = frame[getter]
		if type(fn) ~= "function" then
			return nil
		end
		local ok, value = pcall(fn, frame)
		if not ok or (issecretvalue and issecretvalue(value)) or type(value) ~= "number" then
			return nil
		end
		return value
	end
	local bottom, relScale = figure(relative, "GetBottom"), figure(relative, "GetEffectiveScale")
	local height, tipScale = figure(tooltip, "GetHeight"), figure(tooltip, "GetEffectiveScale")
	if not (bottom and relScale and height and tipScale) or height <= 0 then
		return "unread"
	end
	local drop = -(tonumber(anchor.y) or 0)
	if bottom * relScale - (height + drop) * tipScale < 0 then
		return "flipped"
	end
	return "clear"
end


function A.hideTooltip()
	releaseTooltip()
	if GameTooltip then
		pcall(GameTooltip.Hide, GameTooltip)
	end
end





function A.setPillUnreachable(button, reason)
	if type(button) ~= "table" or button.controlKind ~= "pill" then
		return false
	end

	local marked = type(reason) == "string" and reason ~= ""
	button.pillUnreachable = marked or nil
	button.pillReason = marked and reason or nil


	if type(button.Enable) == "function" and type(button.Disable) == "function" then
		pcall(marked and button.Disable or button.Enable, button)
	end
	paint(button)
	return marked
end


function A.attachPillReason(button)
	if type(button) ~= "table" or button.controlKind ~= "pill" then
		return false
	end
	button:HookScript("OnEnter", function(self)
		if not self.pillReason then
			return
		end

		local title = ""
		if type(self.GetText) == "function" then
			local ok, text = pcall(self.GetText, self)
			title = (ok and type(text) == "string") and text or ""
		end
		A.keyedTooltip(self, { title, self.pillReason }, "ANCHOR_TOP")
	end)
	button:HookScript("OnLeave", A.hideTooltip)
	return true
end
