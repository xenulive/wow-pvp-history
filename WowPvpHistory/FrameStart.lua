-- WowPvpHistory 0.75.68
-- Author:  Xenu-Sentinels
-- Project: wow-pvp-history
--          https://github.com/xenulive/wow-pvp-history
-- License: MIT, see LICENSE
local _,A=...

local function tileHeight()
	return A.metric("startTilePad")*2+A.fontSize("stripLabel")+A.metric("startTileLine")
		+A.fontSize("number")
end

local function buildTile(parent)
	local tile=CreateFrame("Frame",nil,parent)
	tile.ground=tile:CreateTexture(nil,"BACKGROUND")
	tile.ground:SetAllPoints(tile)
	tile.edges=A.hairlineEdges(tile)
	tile.label=A.lineText(tile,"stripLabel","LEFT","dim")
	tile.label:SetPoint("TOPLEFT",tile,"TOPLEFT",A.metric("startTilePad"),-A.metric("startTilePad"))
	tile.figure=A.lineText(tile,"number","LEFT","bright")
	tile.figure:SetPoint("TOPLEFT",tile.label,"BOTTOMLEFT",0,-A.metric("startTileLine"))
	tile.figure:SetText("0")
	tile.unit=A.lineText(tile,"cardLabel","LEFT","dim")
	tile.unit:SetPoint("BOTTOMLEFT",tile.figure,"BOTTOMRIGHT",A.metric("startTileLine"),0)
	return tile
end

local function pressSample(panel)
	local ok,opened,refusal=pcall(A.welcomeSample)
	if not ok then
		A.noteError(opened,"window/start")
	end
	local outcome=(ok and opened)and"filled"or refusal or"not-opened"
	A.trace("startPanel",{state=panel.drawn and"shown"or"hidden",tileKeys=panel.keys,
		tileSet=panel.tileSet,outcome=outcome,hostRoom=panel.hostRoom,top=panel.top},"ui")
end

local function buildPanel(frame)
	local panel=CreateFrame("Frame",nil,frame.listHost)
	panel:SetFrameLevel(frame.listHost:GetFrameLevel()+A.metric("startPanelLevel"))
	panel.heading=A.lineText(panel,"headingLarge","CENTER","bright")
	panel.heading:SetText("No matches yet.")
	panel.next=A.lineText(panel,"cardText","CENTER","dim")
	panel.next:SetText("Your next match appears here.")
	panel.tiles={}
	panel.pill=A.pill(panel,A.SAMPLE_PROMPT,function()
		pressSample(panel)
	end)
	A.setControlTone(panel.pill,"accent")
	panel.term=A.lineText(panel,"cardLabel","CENTER","dim")
	panel.term:SetText(A.SAMPLE_TERM)
	panel:Hide()
	frame.startPanel=panel
	return panel
end

local function paintTile(tile,set)
	A.style(tile.label,"stripLabel","dim")
	A.style(tile.figure,"number","bright")
	A.style(tile.unit,"cardLabel","dim")
	tile.label:SetText(A.formatLabel(set.format):upper())
	tile.unit:SetText(set.unit)
	local filled=A.theme()=="flat"
	if filled then
		tile.ground:SetColorTexture(A.color("panelDeep"))
	else
		tile.ground:SetColorTexture(0,0,0,0)
	end
	tile.ground:SetShown(filled)
	for _,edge in ipairs(tile.edges)do
		edge:SetColorTexture(A.color("hairline"))
	end
end

local function tileWidth(panel,count)
	local pad=A.metric("startTilePad")*2
	local need=A.metric("startTileWidth")
	for i=1,count do
		local tile=panel.tiles[i]
		local figure=A.textRoom(tile.figure,"0")+A.metric("startTileLine")
			+A.textRoom(tile.unit,tile.unit:GetText())
		need=math.max(need,math.ceil(math.max(A.textRoom(tile.label,tile.label:GetText()),figure))+pad)
	end
	return need
end

local function columnsFor(wanted,width,room)
	local gap=A.metric("startTileGap")
	local columns=wanted
	while columns>1 and columns*width+(columns-1)*gap>room do
		columns=columns-1
	end
	return columns
end

local function layOut(frame,panel,set)
	local count=#set
	local host=frame.listHost
	local room=host:GetWidth()or 0
	local width=tileWidth(panel,count)
	local gap=A.metric("startTileGap")
	local columns=columnsFor(set.columns,width,room)
	local rows=math.ceil(count/columns)
	local tileH=tileHeight()
	local gridH=rows*tileH+(rows-1)*gap
	local gridW=columns*width+(columns-1)*gap

	local group=A.metric("startGroupGap")
	local line=A.metric("startLineGap")
	local head=A.fontSize("headingLarge")+line+A.fontSize("cardText")
	local foot=A.metric("controlHeight")
	local term=line+A.fontSize("cardLabel")
	local band=A.listSearchBand()
	local tall=A.unitFigure(frame.listRoom)or 0
	local top=head+group
	local body=top+gridH+group+foot
	local keepTerm=tall<=0 or body+term<=tall
	local total=body+(keepTerm and term or 0)
	local offset=band+math.max(0,math.floor((tall-total)/2))

	panel:ClearAllPoints()
	panel:SetPoint("TOPLEFT",host,"TOPLEFT",0,-offset)
	panel:SetSize(room,total)
	panel.hostRoom,panel.top=tall,offset

	panel.heading:ClearAllPoints()
	panel.heading:SetPoint("TOP",panel,"TOP",0,0)
	panel.next:ClearAllPoints()
	panel.next:SetPoint("TOP",panel.heading,"BOTTOM",0,-line)

	local left=math.floor((room-gridW)/2)
	for i=1,count do
		local tile=panel.tiles[i]
		local column,row=(i-1)%columns,math.floor((i-1)/columns)
		tile:ClearAllPoints()
		tile:SetPoint("TOPLEFT",panel,"TOPLEFT",left+column*(width+gap),-(top+row*(tileH+gap)))
		tile:SetSize(width,tileH)
		tile:Show()
	end
	for i=count+1,#panel.tiles do
		panel.tiles[i]:Hide()
	end

	panel.pill:ClearAllPoints()
	panel.pill:SetPoint("TOP",panel,"TOP",0,-(top+gridH+group))
	panel.term:ClearAllPoints()
	panel.term:SetPoint("TOP",panel.pill,"BOTTOM",0,-line)
	panel.term:SetShown(keepTerm)
	panel.columns=columns
end

function A.paintStartPanel(frame,due)
	local panel=frame.startPanel
	if not due then
		if panel then
			panel:Hide()
			if panel.drawn then
				panel.drawn=false
				A.trace("startPanel",{state="hidden",tileKeys=panel.keys,tileSet=panel.tileSet},"ui")
			end
		end
		return false
	end
	panel=panel or buildPanel(frame)
	local set,name=A.startTiles()
	local keys={}
	for i,entry in ipairs(set)do
		panel.tiles[i]=panel.tiles[i]or buildTile(panel)
		paintTile(panel.tiles[i],entry)
		keys[i]=entry.format
	end
	panel.keys=table.concat(keys,",")
	panel.tileSet=name
	A.style(panel.heading,"headingLarge","bright")
	A.style(panel.next,"cardText","dim")
	A.style(panel.term,"cardLabel","dim")
	layOut(frame,panel,set)
	panel:Show()
	if not panel.drawn then
		panel.drawn=true
		A.trace("startPanel",{state="shown",tileKeys=panel.keys,tileSet=panel.tileSet,
			hostRoom=panel.hostRoom,top=panel.top},"ui")
	end
	return true
end
