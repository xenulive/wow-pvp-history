-- WowPvpHistory 0.70.16
-- Author:  Xenu-Sentinels
-- Project: wow-pvp-history
--          https://github.com/xenulive/wow-pvp-history
-- License: MIT, see LICENSE
local _,A=...

local FRAME_NAME="WowPvpHistoryStoreFrame"

local window

local function historyReading(db,census)
	if type(db)~="table"then
		return"the account-wide database did not load, so nothing is stored"
	end

	local matches=#db.matches
	census=census or A.indexCensus(db)
	return("%d %s, %d %s, schema %s"):format(
		matches,matches==1 and"match"or"matches",
		census.players,census.players==1 and"player"or"players",
		tostring(db.schema))
end

local function canaryRegister(state)
	if state.state=="lost"or state.state=="short"then
		return"fault"
	end
	if state.state=="absent"or state.state=="unknown"then
		return"standing"
	end
	return"routine"
end

local function backupRegister()
	local held=A.backupStore()
	if not held or type(held.current)~="table"then
		return"fault"
	end
	if type(held.refused)=="table"or type(held.failed)=="table"then
		return"standing"
	end
	return"routine"
end

local function indexRegister(db)
	if type(db)~="table"then
		return"fault"
	end
	local stamped=db.playerIndexVersion
	if type(stamped)~="number"or stamped<A.indexVersion then
		return"standing"
	end
	return"routine"
end

function A.storeRows()
	local db=A.db()
	local state=A.canaryState()
	local census=type(db)=="table"and A.indexCensus(db)or nil

	return{
		{
			name="History",
			reading=historyReading(db,census),
			register=db and"routine"or"fault",
		},
		{
			name=A.sandboxed()and"Canary (saved store)"or"Canary",
			reading=A.canaryReading(state),
			register=canaryRegister(state),
		},
		{
			name="Backup",
			reading=A.backupReading(),
			register=backupRegister(),
			action={
				label="Back up now",
				run=function()return A.reportBackup()end,
			},
		},
		{
			name="Index",
			reading=A.indexReading(db,census),
			register=indexRegister(db),
			action={
				label="Rebuild the index",
				run=function()return A.reportRebuild()end,
			},
		},
	}
end

local function surface()
	return type(CreateFrame)=="function"
end

function A.storeWindowTitle()
	return("%s: the store"):format(A.displayName())
end

local function buildRow(frame,parent,index)
	local row={}

	row.dot=parent:CreateTexture(nil,"ARTWORK")
	row.dot:SetSize(A.metric("storeDot"),A.metric("storeDot"))

	row.name=parent:CreateFontString(nil,"ARTWORK","GameFontNormalSmall")
	row.name:SetJustifyH("LEFT")
	row.name:SetWordWrap(false)

	row.reading=parent:CreateFontString(nil,"ARTWORK","GameFontHighlightSmall")
	row.reading:SetJustifyH("LEFT")
	row.reading:SetWordWrap(false)

	row.action=A.pill(parent,"",function()
		local rows=A.storeRows()
		local spec=rows[index]and rows[index].action
		if spec then
			spec.run()
		end
		A.refreshStoreWindow()
	end,A.metric("actionMin"))

	local y=A.metric("optionsRow")+(index-1)*A.metric("storeRow")
	row.dot:SetPoint("TOPLEFT",parent,"TOPLEFT",0,
		-(y+(A.metric("storeRow")-A.metric("storeDot"))/2))
	row.name:SetPoint("TOPLEFT",parent,"TOPLEFT",A.metric("storeNameInset"),-y)
	row.action:SetPoint("TOPRIGHT",parent,"TOPRIGHT",0,-y)
	row.reading:SetPoint("TOPLEFT",parent,"TOPLEFT",A.metric("storeReadingInset"),-y)
	row.reading:SetPoint("TOPRIGHT",row.action,"TOPLEFT",-A.metric("paneGap"),0)

	frame.rows[index]=row
	return row
end

local function buildWindow()
	local frame=CreateFrame("Frame",FRAME_NAME,UIParent,"BasicFrameTemplateWithInset")
	frame:SetSize(A.metric("storeWidth"),A.metric("storeHeight"))
	frame:SetPoint("CENTER",UIParent,"CENTER",
		A.metric("storeOffsetX"),A.metric("storeOffsetY"))
	A.registerPlacedWindow(frame,"CENTER",A.metric("storeOffsetX"),A.metric("storeOffsetY"))
	A.standMovableWindow(frame)
	frame:SetScript("OnDragStop",function(self)
		A.stopDrag(self)
	end)
	frame:Hide()

	A.registerChrome(frame)

	A.placeWindowHeading(frame)
	A.style(frame.heading,"heading","bright")

	frame.body=CreateFrame("Frame",nil,frame)
	frame.body:SetPoint("TOPLEFT",frame,"TOPLEFT",
		A.metric("margin"),-A.metric("headerHeight"))
	frame.body:SetPoint("TOPRIGHT",frame,"TOPRIGHT",
		-A.metric("margin"),-A.metric("headerHeight"))
	frame.body:SetHeight(A.metric("storeHeight")-A.metric("headerHeight")
		-A.metric("margin")*2)

	frame.sectionHeading=frame.body:CreateFontString(nil,"ARTWORK","GameFontNormalSmall")
	frame.sectionHeading:SetPoint("TOPLEFT",frame.body,"TOPLEFT",0,0)
	frame.sectionHeading:SetJustifyH("LEFT")
	frame.sectionHeading:SetWordWrap(false)
	frame.sectionHeading:SetText("THE STORE NOW")
	A.style(frame.sectionHeading,"label","accent")

	frame.rows={}
	for i=1,4 do
		buildRow(frame,frame.body,i)
	end

	A.closeOnEscape(FRAME_NAME)

	return frame
end

local function windowOrNil()
	if window then
		return window
	end
	if not surface()then
		return nil
	end
	local built=A.buildWindowOnce("store",buildWindow)
	if not built then
		window=nil
		return nil
	end
	window=built
	return window
end

function A.refreshStoreWindow()
	if not window then
		return false
	end

	A.containedPaint("store/heading",function()
		window.heading:SetText(A.storeWindowTitle())
		A.style(window.sectionHeading,"label","accent")
	end)

	local ok,rows=A.containedPaint("store/rows",A.storeRows)
	if not ok or type(rows)~="table"then
		return false
	end

	for i=1,#window.rows do
		local widget=window.rows[i]
		local row=rows[i]
		A.containedPaint("store/row",function()
			if not row then
				widget.dot:Hide()
				widget.name:SetText("")
				widget.reading:SetText("")
				widget.action:Hide()
				return
			end

			widget.dot:Show()
			widget.dot:SetColorTexture(A.color(A.registerMark(row.register)))
			widget.name:SetText(row.name)
			widget.reading:SetText(row.reading)
			A.style(widget.name,"bodyText","text")
			A.style(widget.reading,"bodyText",row.register)

			if row.action then
				widget.action:SetText(row.action.label)
				A.fitControl(widget.action,A.metric("actionMin"))
				widget.action:Show()
			else
				widget.action:Hide()
			end
		end)
	end

	return true
end

function A.showStoreWindow()
	local frame=windowOrNil()
	if not frame then
		return false
	end

	A.refreshStoreWindow()
	local shown=pcall(frame.Show,frame)
	pcall(frame.Raise,frame)

	local db=A.db()
	A.trace("open",{source="store",n=db and type(db.matches)=="table"and#db.matches or nil},"ui")

	return shown
end

function A.hideStoreWindow()
	if not window then
		return false
	end
	return(pcall(window.Hide,window))
end

function A.storeWindowShown()
	if not window then
		return false
	end
	local ok,shown=pcall(window.IsShown,window)
	return ok and shown==true
end

function A.toggleStoreWindow()
	if A.storeWindowShown()then
		return A.hideStoreWindow()
	end
	return A.showStoreWindow()
end
