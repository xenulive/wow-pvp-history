-- WowPvpHistory 0.70.27
-- Author:  Xenu-Sentinels
-- Project: wow-pvp-history
--          https://github.com/xenulive/wow-pvp-history
-- License: MIT, see LICENSE
local _,A=...

local MOST=4

local picked={ids={},held={},format=nil}

local hooked={}

local lastBoxes=nil

local openTab="figures"

function A.compareIds()
	local out={}
	for i=1,#picked.ids do
		out[i]=picked.ids[i]
	end
	return out
end

local function takeOut(id)
	for i=#picked.ids,1,-1 do
		if picked.ids[i]==id then
			table.remove(picked.ids,i)
		end
	end
	picked.held[id]=nil
	if#picked.ids==0 then
		picked.format=nil
		openTab="figures"
	end
end

local function prune()
	local out={}
	local gone={}
	for i=1,#picked.ids do
		local id=picked.ids[i]
		local record=type(A.match)=="function"and A.match(id)or nil
		if record then
			out[#out+1]=record
		else
			gone[#gone+1]=id
		end
	end
	for i=1,#gone do
		takeOut(gone[i])
	end
	if#gone>0 then
		A.trace("compare/drop",{count=#picked.ids,closed=#picked.ids<2 or nil,via="gone"},"ui")
	end
	return out
end

function A.compareCount()
	prune()
	return#picked.ids
end

function A.compareFormat()
	return picked.format
end

function A.comparePicked(id)
	return id~=nil and picked.held[id]==true
end

function A.compareAdmits(record)
	if type(record)~="table"or record.id==nil then
		return false,"unknown"
	end
	local format=record.format
	if type(format)~="string"or format==""or format=="unknown"then
		return false,"unknown"
	end
	if picked.format~=nil and format~=picked.format then
		return false,"format"
	end
	if#picked.ids>=MOST then
		return false,"full"
	end
	return true,nil
end

function A.compareRefusedText(reason)
	if reason=="format"and picked.format~=nil then
		return"Must be the same match type"
	end
	if reason=="full"then
		return"Four is the most"
	end
	return nil
end

local function tracePick(action,id,via,reason)
	A.trace("compare/pick",{
		action=action,reason=reason,via=via,id=id,
		count=#picked.ids,format=picked.format,
	},"ui")
end

local function halvesShown()
	for _,kind in ipairs({"matches","players"})do
		local frame=type(A.windowFrameOf)=="function"and A.windowFrameOf(kind)or nil
		if type(frame)=="table"then
			local ok,shown=pcall(frame.IsShown,frame)
			if ok and shown then
				return true
			end
		end
	end
	return false
end

local function afterHalfHid()
	if#picked.ids==0 or halvesShown()then
		return
	end
	A.compareClear("close")
end

local function hookHalves()
	for _,kind in ipairs({"matches","players"})do
		local frame=type(A.windowFrameOf)=="function"and A.windowFrameOf(kind)or nil
		if type(frame)=="table"and not hooked[frame]then
			local ok=pcall(frame.HookScript,frame,"OnHide",function()
				local after=C_Timer and C_Timer.After
				if type(after)=="function"then
					after(0,afterHalfHid)
				else
					afterHalfHid()
				end
			end)
			if ok then
				hooked[frame]=true
			end
		end
	end
end

local function changed()
	lastBoxes=nil
	local history=type(A.windowFrameOf)=="function"and A.windowFrameOf("matches")or nil
	if type(history)=="table"then
		local ok,shown=pcall(history.IsShown,history)
		if ok and shown and type(A.refreshWindow)=="function"then
			pcall(A.refreshWindow)
		end
	end
	if type(A.compareSetChanged)=="function"then
		pcall(A.compareSetChanged)
	end
end

function A.compareAdd(record,via)
	if type(record)=="table"and A.comparePicked(record.id)then
		return"held",nil
	end
	local ok,reason=A.compareAdmits(record)
	if not ok then
		tracePick("refused",type(record)=="table"and record.id or nil,via,reason)
		return"refused",reason
	end
	picked.ids[#picked.ids+1]=record.id
	picked.held[record.id]=true
	picked.format=record.format
	hookHalves()
	tracePick("add",record.id,via)
	changed()
	return"add",nil
end

function A.compareRemove(id,via)
	if not A.comparePicked(id)then
		return"absent",nil
	end
	takeOut(id)
	tracePick("remove",id,via)
	changed()
	return"remove",nil
end

function A.compareToggle(record,via)
	if type(record)=="table"and A.comparePicked(record.id)then
		return A.compareRemove(record.id,via)
	end
	return A.compareAdd(record,via)
end

function A.compareClear(via)
	local held=#picked.ids>0
	picked.ids,picked.held,picked.format={},{},nil
	openTab="figures"
	A.trace("compare/clear",{via=via,count=0},"ui")
	if type(A.hideCompareWindow)=="function"then
		pcall(A.hideCompareWindow)
	end
	changed()
	return held
end

function A.compareMoveBase(index,via)
	if type(index)~="number"or index<2 or index>#picked.ids then
		return false
	end
	local id=table.remove(picked.ids,index)
	table.insert(picked.ids,1,id)
	A.trace("compare/base",{fromColumn=index,toColumn=1,via=via},"ui")
	changed()
	return true
end

function A.compareColumnOf(id)
	for i=1,#picked.ids do
		if picked.ids[i]==id then
			return i
		end
	end
	return nil
end

function A.compareDrop(id)
	if not A.comparePicked(id)then
		return false
	end
	takeOut(id)
	A.trace("compare/drop",{count=#picked.ids,closed=#picked.ids<2 or nil},"ui")
	changed()
	return true
end

function A.compareRecords()
	return prune()
end

function A.dropCompareSet()
	lastBoxes=nil
	openTab="figures"
	if#picked.ids>0 then
		picked.ids,picked.held,picked.format={},{},nil
		A.trace("compare/clear",{via="replaced",count=0},"ui")
		if type(A.hideCompareWindow)=="function"then
			pcall(A.hideCompareWindow)
		end
	end
end

function A.compareMenuEntry(record)
	if type(record)~="table"or record.id==nil then
		return nil
	end
	if A.comparePicked(record.id)then
		return{key="compare",label="Remove from compare"}
	end
	local ok,reason=A.compareAdmits(record)
	if not ok and reason=="unknown"then
		return nil
	end
	if not ok then
		return{key="compare",label="Compare",disabled=true,tooltip=A.compareRefusedText(reason)}
	end
	return{key="compare",label="Compare"}
end

function A.compareMenuRun(id,record)
	record=type(record)=="table"and record or A.match(id)
	local action,reason=A.compareToggle(record,"menu")
	if action=="add"then
		return"added",nil
	elseif action=="remove"then
		return"removed",nil
	end
	return"refused",reason
end

local function ctrlHeld()
	local ok,down=pcall(function()
		return IsControlKeyDown()
	end)
	return ok and down==true
end

function A.compareCtrlClick(id,record)
	if id==nil or not ctrlHeld()then
		return false
	end
	record=type(record)=="table"and record or A.match(id)
	A.compareToggle(record,"ctrl")
	return true
end

local function boxParts(row)
	if row.compareBox~=nil then
		return row.compareBox
	end
	local box={
		edge=row:CreateTexture(nil,"OVERLAY",nil,1),
		fill=row:CreateTexture(nil,"OVERLAY",nil,2),
		check=row:CreateTexture(nil,"OVERLAY",nil,3),
	}
	pcall(box.check.SetTexture,box.check,"Interface\\Buttons\\UI-CheckBox-Check")
	row.compareBox=box
	return box
end

local function hideBox(row)
	local box=row.compareBox
	if box then
		box.edge:Hide()
		box.fill:Hide()
		box.check:Hide()
	end
end

function A.compareBoxShape(id,record,hovered)
	if id==nil then
		return nil
	end
	if A.comparePicked(id)then
		return"picked"
	end
	if type(record)~="table"then
		return nil
	end
	local ok,reason=A.compareAdmits(record)
	if ok then
		return(#picked.ids>0 or hovered==true)and"empty"or nil
	end
	if reason~="unknown"and#picked.ids>0 then
		return"dimmed"
	end
	return nil
end

function A.compareBoxReason(record)
	if type(record)~="table"or A.compareBoxShape(record.id,record,true)~="dimmed"then
		return nil
	end
	local _,reason=A.compareAdmits(record)
	return A.compareRefusedText(reason)
end

function A.paintCompareBox(row,at)
	if type(row)~="table"then
		return nil
	end
	local listRow=at=="list"and not row.isSeparator and row.entryKind=="match"and row.matchId~=nil
	if not listRow then
		hideBox(row)
		return nil
	end
	local shape=A.compareBoxShape(row.matchId,row.matchRecord,row.compareHover==true)
	if shape==nil then
		hideBox(row)
		return nil
	end
	local box=boxParts(row)
	local side=A.metric("compareBox")
	local drop=math.floor((A.metric("rowListRow")-side)/2)
	box.edge:ClearAllPoints()
	box.edge:SetPoint("TOPLEFT",row,"TOPLEFT",A.metric("compareBoxInset"),-drop)
	box.edge:SetSize(side,side)
	box.fill:ClearAllPoints()
	box.fill:SetPoint("TOPLEFT",box.edge,"TOPLEFT",1,-1)
	box.fill:SetSize(side-2,side-2)
	box.check:ClearAllPoints()
	box.check:SetPoint("CENTER",box.edge,"CENTER",0,0)
	box.check:SetSize(side+4,side+4)
	if shape=="picked"then
		box.edge:SetColorTexture(A.color("accent"))
		box.fill:SetColorTexture(A.color("field"))
		box.check:SetVertexColor(A.color("accent"))
		box.check:Show()
	else
		box.edge:SetColorTexture(A.color(shape=="dimmed"and"faint"or"dim"))
		box.fill:SetColorTexture(A.color("field"))
		box.check:Hide()
	end
	box.edge:Show()
	box.fill:Show()
	return shape
end

function A.tallyCompareBoxes(rows)
	if#picked.ids==0 then
		lastBoxes=nil
		return nil
	end
	local counts={picked=0,open=0,dimmed=0}
	local drawn=0
	for _,data in ipairs(type(rows)=="table"and rows or{})do
		if type(data)=="table"and not data.separator and data.kind=="match"and data.id~=nil then
			local shape=A.compareBoxShape(data.id,data.matchRecord,false)
			if shape~=nil then
				local key=shape=="empty"and"open"or shape
				counts[key]=counts[key]+1
				drawn=drawn+1
			end
		end
	end
	if drawn==0 then
		lastBoxes=nil
		return nil
	end
	lastBoxes=counts
	A.trace("compare/boxes",{picked=counts.picked,open=counts.open,dimmed=counts.dimmed},"ui")
	return counts
end

function A.compareBoxLine()
	if#picked.ids==0 then
		return nil
	end
	if lastBoxes==nil then
		return"compare: no History list paint has drawn a box since the set last changed"
	end
	return("compare: boxes on the last list paint, %d picked, %d open, %d dimmed")
		:format(lastBoxes.picked,lastBoxes.open,lastBoxes.dimmed)
end

local function pointerAcross(row)
	if type(GetCursorPosition)~="function"or type(row.GetEffectiveScale)~="function"
		or type(row.GetLeft)~="function"then
		return nil
	end
	local ok,x=pcall(GetCursorPosition)
	local okScale,scale=pcall(row.GetEffectiveScale,row)
	local okLeft,left=pcall(row.GetLeft,row)
	if not(ok and okScale and okLeft and type(x)=="number"and type(scale)=="number"and scale>0
		and type(left)=="number")then
		return nil
	end
	return A.unitFigure(x/scale-left)
end

function A.comparePointerInLane(row)
	if type(row)~="table"then
		return false
	end
	local right=row.pickLaneRight
	if type(right)~="number"or right<=0 then
		return false
	end
	local across=pointerAcross(row)
	return across~=nil and across>=0 and across<=A.unitFigure(right)
end

local function pressBox(record)
	if type(record)~="table"or A.compareBoxShape(record.id,record,true)==nil then
		return"none",nil
	end
	return A.compareToggle(record,"box")
end

function A.compareLaneClick(row)
	if type(row)~="table"or row.matchId==nil or not A.comparePointerInLane(row)then
		return false
	end
	local record=type(row.matchRecord)=="table"and row.matchRecord or A.match(row.matchId)
	return pressBox(record)~="none"
end

function A.compareLaneTooltip(row)
	if type(row)~="table"or row.matchId==nil or not A.comparePointerInLane(row)then
		return nil
	end
	return A.compareBoxReason(type(row.matchRecord)=="table"and row.matchRecord or A.match(row.matchId))
end

function A.compareBarHeight(listing)
	if listing==false or#picked.ids==0 then
		return 0
	end
	return A.metric("compareBar")
end

function A.compareButtonTooltip()
	if#picked.ids>=MOST then
		return"Four is the most"
	end
	if#picked.ids<2 then
		return("Pick one more of your %s"):format(A.formatPlural(picked.format))
	end
	return"Open the picked matches side by side"
end

local function buildBar(frame)
	local host=frame.listHost
	local bar=CreateFrame("Frame",nil,host)
	bar:SetHeight(A.metric("compareBar"))
	bar:SetPoint("BOTTOMLEFT",host,"BOTTOMLEFT",0,0)
	bar:SetPoint("BOTTOMRIGHT",host,"BOTTOMRIGHT",0,0)
	bar.ground=bar:CreateTexture(nil,"BACKGROUND")
	bar.ground:SetAllPoints(bar)
	bar.rule=bar:CreateTexture(nil,"BORDER")
	bar.rule:SetPoint("TOPLEFT",bar,"TOPLEFT",0,0)
	bar.rule:SetPoint("TOPRIGHT",bar,"TOPRIGHT",0,0)
	bar.rule:SetHeight(1)

	bar.count=bar:CreateFontString(nil,"ARTWORK","GameFontHighlightSmall")
	bar.count:SetPoint("LEFT",bar,"LEFT",A.metric("rowLabelPad"),0)
	bar.count:SetJustifyH("LEFT")
	bar.count:SetWordWrap(false)

	bar.compare=A.pill(bar,"Compare",function()
		if type(A.showCompareWindow)=="function"then
			A.showCompareWindow()
		end
	end,A.metric("actionMin"))
	bar.compare:SetPoint("RIGHT",bar,"RIGHT",-A.metric("rowLabelPad"),0)
	pcall(bar.compare.HookScript,bar.compare,"OnEnter",function(self)
		A.hoverLine(self,A.compareButtonTooltip())
	end)
	pcall(bar.compare.HookScript,bar.compare,"OnLeave",function(self)
		A.hideOwnedTooltip(self)
	end)

	bar.clear=A.pill(bar,"Clear",function()
		A.compareClear("button")
	end,A.metric("actionMin"))
	bar.clear:SetPoint("RIGHT",bar.compare,"LEFT",-A.metric("paneGap"),0)
	bar.count:SetPoint("RIGHT",bar.clear,"LEFT",-A.metric("paneGap"),0)
	bar:Hide()
	frame.compareBar=bar
	return bar
end

function A.compareCountText()
	prune()
	local count=#picked.ids
	if count==0 then
		return nil
	end
	return("%d %s"):format(count,count==1 and A.formatLabel(picked.format)or A.formatPlural(picked.format))
end

function A.comparePickedText()
	local count=A.compareCountText()
	return count and(count.." picked")or nil
end

function A.paintCompareBar(frame,listing)
	if type(frame)~="table"or frame.listHost==nil then
		return nil
	end
	local bar=frame.compareBar or buildBar(frame)
	prune()
	local count=#picked.ids
	if count==0 or listing==false then
		bar:Hide()
		return nil
	end
	bar.ground:SetColorTexture(A.color("pinGround"))
	bar.rule:SetColorTexture(A.color("hairline"))
	bar.count:SetText(A.comparePickedText())
	A.style(bar.count,"bodyText","text")
	bar.compare:SetText(("Compare %d"):format(count))
	A.setControlTone(bar.compare,"accent")
	A.fitControl(bar.compare,A.metric("actionMin"))
	A.fitControl(bar.clear,A.metric("actionMin"))
	pcall(bar.compare.SetEnabled,bar.compare,count>=2)
	bar:Show()
	return count
end

local SHUFFLES={shuffle=true,["shuffle-unrated"]=true}

local BATTLEGROUNDS={bg=true,rbg=true,blitz=true,["blitz-unrated"]=true}

local NO_SCOREBOARD={duel=true,world=true}

local LOBBY_MOST=12

local FOLD_JOIN=" \194\183 "

local function own(record)
	local list=type(record.participants)=="table"and record.participants or nil
	local p=list and type(record.character)=="string"and list[record.character]or nil
	return type(p)=="table"and p or nil
end

local function figure(value)
	if type(value)=="number"and value==value then
		return value
	end
	return nil
end

local function shortFigure(n)
	local text=A.figureText(n)
	if text==nil then
		return nil
	end
	return(text:gsub("%.0([KM])$","%1"))
end

local function diffText(unit,d)
	local sign=d>0 and"+"or"-"
	local size=math.abs(d)
	if unit=="figure"then
		return sign..shortFigure(size)
	end
	if unit=="clock"then
		return sign..A.clockText(size)
	end
	return A.signedText(d)
end

local function openedFrom(record)
	return type(record.openedState)=="string"and record.openedState or"StartUp"
end

local function specGroups(record)
	local out,byKey={},{}
	local list=type(record.participants)=="table"and record.participants or{}
	local guids={}
	for guid in pairs(list)do
		if type(guid)=="string"and guid~=record.character then
			guids[#guids+1]=guid
		end
	end
	table.sort(guids)
	for i=1,#guids do
		local p=list[guids[i]]
		local token=type(p)=="table"and p.classToken or nil
		local spec=type(p)=="table"and p.spec or nil
		if type(token)=="string"and token~=""and type(spec)=="string"and spec~=""then
			local key=token..":"..spec
			local group=byKey[key]
			if not group then
				group={key=key,classToken=token,spec=spec,class=p.class,guids={}}
				byKey[key]=group
				out[#out+1]=group
			end
			group.guids[#group.guids+1]=guids[i]
		end
	end
	return out,byKey
end

local function objectiveValues(record)
	local out={}
	if type(A.objectiveColumns)~="function"then
		return out
	end
	local p=own(record)
	local stats=p and type(p.stats)=="table"and p.stats or nil
	for _,column in ipairs(A.objectiveColumns(record)or{})do
		out[#out+1]={name=column.long,value=stats and figure(stats[column.id])or nil}
	end
	return out
end

local ROWS={
	{key="rounds",label="Rounds won",group="RESULT",kind="number",unit="plain",only=SHUFFLES,
		higher=true},
	{key="ratingChange",label="Rating change",group="RESULT",kind="number",unit="plain",rated=true,
		higher=true},
	{key="ratingAfter",label="Rating after",group="RESULT",kind="number",unit="plain",rated=true,
		tier=true},
	{key="mmr",label="MMR",group="RESULT",kind="number",unit="plain",rated=true},
	{key="length",label="Length",group="RESULT",kind="number",unit="clock"},
	{key="build",label="Build",group="YOU",kind="text"},
	{key="damage",label="Damage",group="YOU",kind="number",unit="figure",skip=NO_SCOREBOARD,
		higher=true},
	{key="healing",label="Healing",group="YOU",kind="number",unit="figure",skip=NO_SCOREBOARD,
		higher=true},
	{key="killingBlows",label="Killing blows",group="YOU",kind="number",unit="plain",
		skip=NO_SCOREBOARD,higher=true},
	{key="objectives",group="YOU",expands=true,only=BATTLEGROUNDS},
}

local function rowApplies(spec,format)
	if(spec.only and not spec.only[format])or(spec.skip and spec.skip[format])
		or(spec.rated and not A.movesRating(format))then
		return false
	end
	return true
end

local function cellFor(spec,record)
	local p=own(record)
	local key=spec.key
	if key=="rounds"then
		local outcome,won,played=A.roundsOutcome(record)
		if outcome==nil then
			return{text="-"}
		end
		return{value=won,text=("%d of %d"):format(won,played),squares={won=won,played=played}}
	elseif key=="ratingChange"then
		local v=p and figure(p.ratingChange)or nil
		return{value=v,text=A.signedText(v)or"-"}
	elseif key=="ratingAfter"then
		local into=p and figure(p.rating)or nil
		local change=p and figure(p.ratingChange)or nil
		local v=(into~=nil and change~=nil)and into+change or nil
		local cell={value=v,text=v~=nil and tostring(v)or"-"}
		if v~=nil then
			local _,_,_,r,g,b=A.ratingColour(record.format,v)
			if type(r)=="number"then
				cell.tier={r,g,b}
			end
		end
		return cell
	elseif key=="mmr"then
		local v=p and figure(p.mmrPost)or nil
		return{value=v,text=v~=nil and tostring(v)or"-"}
	elseif key=="length"then
		local v=figure(record.duration)
		return{value=v,text=A.clockText(v)or"-",opened=openedFrom(record)}
	elseif key=="build"then
		local label=A.talentsLabel(record)
		return{text=label or"-",present=label~=nil}
	elseif key=="damage"or key=="healing"then
		local v=p and figure(p[key])or nil
		return{value=v,text=A.figureText(v)or"-"}
	elseif key=="killingBlows"then
		local v=p and figure(p.killingBlows)or nil
		return{value=v,text=v~=nil and tostring(v)or"-"}
	end
	return{text="-"}
end

local function holds(cell)
	return cell.value~=nil or cell.present==true
end

local function foldable(spec,key,cells)
	if#cells<2 or not(spec.kind=="text"or key=="length")then
		return false
	end
	local text=cells[1].text
	for _,cell in ipairs(cells)do
		if cell.text~=text then
			return false
		end
	end
	return true
end

local function settle(spec,cells)
	if spec.kind~="number"then
		return
	end
	if spec.higher then
		local high,low,values=nil,nil,0
		for _,cell in ipairs(cells)do
			if cell.value~=nil then
				values=values+1
				if high==nil or cell.value>high then
					high=cell.value
				end
				if low==nil or cell.value<low then
					low=cell.value
				end
			end
		end
		for _,cell in ipairs(cells)do
			cell.best=values>=2 and high~=low and cell.value==high or nil
		end
	end
	local base=cells[1]
	for i=2,#cells do
		local cell=cells[i]
		local comparable=base.value~=nil and cell.value~=nil
		if spec.key=="length"and comparable then
			comparable=base.opened==cell.opened
		end
		if comparable then
			if spec.unit=="clock"then
				cell.diff=math.floor(cell.value)-math.floor(base.value)
			else
				cell.diff=cell.value-base.value
			end
		end
		if comparable and cell.diff~=0 then
			local d=cell.diff
			cell.diffText=diffText(spec.unit,d)
			if not spec.higher then
				cell.diffTone="dim"
			else
				cell.diffTone=d>0 and"win"or"loss"
				cell.chip=true
			end
		end
	end
end

function A.compareRows(records)
	local rows,hidden,folded={},{},{}
	if type(records)~="table"or#records==0 then
		return rows,hidden,folded
	end
	local format=records[1].format

	local function finish(spec,label,key,cells)
		local any=false
		for _,cell in ipairs(cells)do
			if holds(cell)then
				any=true
			end
		end
		if not any then
			hidden[#hidden+1]=key
			return
		end
		if foldable(spec,key,cells)then
			folded[#folded+1]={key=key,label=label,text=cells[1].text}
			return
		end
		settle(spec,cells)
		rows[#rows+1]={key=key,label=label,group=spec.group,kind=spec.kind,tier=spec.tier,
			higher=spec.higher,cells=cells}
	end

	for _,spec in ipairs(ROWS)do
		if not rowApplies(spec,format)then
			hidden[#hidden+1]=spec.key
		elseif spec.expands then
			local names,values={},{}
			for c,record in ipairs(records)do
				local byName={}
				values[c]=byName
				for _,column in ipairs(objectiveValues(record))do
					if byName[column.name]==nil then
						byName[column.name]=column
					end
					local known=false
					for _,name in ipairs(names)do
						if name==column.name then
							known=true
						end
					end
					if not known and type(column.name)=="string"then
						names[#names+1]=column.name
					end
				end
			end
			if#names==0 then
				hidden[#hidden+1]=spec.key
			end
			for _,name in ipairs(names)do
				local cells={}
				for c=1,#records do
					local column=values[c][name]
					local v=column and column.value or nil
					cells[c]={value=v,text=v~=nil and tostring(v)or"-"}
				end
				local objective={key="objective",group=spec.group,kind="number",unit="plain",
					higher=true}
				finish(objective,name,"objective:"..name,cells)
			end
		else
			local cells={}
			for c,record in ipairs(records)do
				cells[c]=cellFor(spec,record)
			end
			finish(spec,spec.label,spec.key,cells)
		end
	end
	return rows,hidden,folded
end

function A.compareFoldLabel(n)
	return("SAME IN ALL %d"):format(n)
end

function A.compareFoldText(folded)
	if type(folded)~="table"or#folded==0 then
		return nil
	end
	local parts={}
	for i,item in ipairs(folded)do
		parts[i]=item.label.." "..item.text
	end
	return table.concat(parts,FOLD_JOIN)
end

function A.compareTitle(count,format)
	return("Compare %d %s"):format(count,A.formatPlural(format))
end

local RESULT_WORDS={win="WON",loss="LOST",draw="DRAW"}

function A.compareResultWord(record)
	if type(record)~="table"then
		return nil
	end
	local decided=A.effectiveResult(record)
	local word=decided~=nil and RESULT_WORDS[decided]or nil
	if word==nil then
		local verdict,won,played=A.roundsVerdict(record)
		if verdict=="draw"then
			word=RESULT_WORDS.draw
		elseif verdict=="count"then
			word=won*2>played and RESULT_WORDS.win or RESULT_WORDS.loss
		end
	end
	if word==nil then
		return nil
	end
	return word,A.resultTone(record)or"dim"
end

function A.compareScoreText(record)
	local verdict,won,played=A.roundsVerdict(record)
	if verdict=="count"or verdict=="draw"then
		return("%d-%d"):format(won,played-won)
	end
	return nil
end

function A.compareRatingText(record)
	if type(record)~="table"or not A.movesRating(record.format)then
		return nil
	end
	local text,tone=A.ratingDelta(record)
	if text==nil then
		return nil
	end
	return text,tone or"dim"
end

function A.compareHeadLines(record)
	local map=type(record.map)=="table"and type(record.map.name)=="string"and record.map.name or"-"
	return"#"..A.matchIdText(record.id),map,A.stampWords(record.openedAt)or"-"
end

function A.compareRowLines(records,rows)
	local out={}
	for _,row in ipairs(rows or{})do
		local parts,best={},{}
		for c,cell in ipairs(row.cells)do
			local id=records[c]and A.matchIdText(records[c].id)or"?"
			local text=("#%s %s"):format(id,cell.text)
			if cell.diffText~=nil then
				text=text.." ("..cell.diffText..")"
			elseif cell.diff==0 then
				text=text.." (0)"
			end
			parts[#parts+1]=text
			if cell.best then
				best[#best+1]="#"..id
			end
		end
		out[#out+1]=("%s: %s; best %s"):format(row.label,table.concat(parts,", "),
			#best>0 and table.concat(best,", ")or"none")
	end
	return out
end

function A.compareSameKeys(rows)
	local out,seen={},{}
	for _,row in ipairs(rows or{})do
		local key=row.key:match("^objective:")and"objective"or row.key
		for c=2,#row.cells do
			if row.cells[c].diff==0 and not seen[key]then
				seen[key]=true
				out[#out+1]=key
			end
		end
	end
	return out
end

function A.compareKeysText(keys)
	if type(keys)~="table"or#keys==0 then
		return nil
	end
	return table.concat(keys,",")
end

function A.compareFoldedKeys(folded)
	local out={}
	for i,item in ipairs(folded or{})do
		out[i]=item.key
	end
	return out
end

function A.compareSecondTab(format)
	if type(format)~="string"or format==""or format=="unknown"or NO_SCOREBOARD[format]then
		return nil
	end
	return SHUFFLES[format]and"Rounds and lobby"or"Lobby"
end

function A.compareTab()
	if openTab=="rounds"and A.compareSecondTab(picked.format)~=nil then
		return"rounds"
	end
	return"figures"
end

function A.compareLobbyMost()
	return LOBBY_MOST
end

function A.compareLobby(records)
	local lobby={rows={},swing=false}
	if type(records)~="table"or#records==0 or A.compareSecondTab(records[1].format)==nil then
		return lobby
	end
	local format=records[1].format
	lobby.swing=SHUFFLES[format]==true
	local byKey,groupsOf={},{}
	for c,record in ipairs(records)do
		local swings={}
		if lobby.swing and type(A.lobbyTally)=="function"then
			local ok,tally=pcall(A.lobbyTally,record)
			if ok and type(tally)=="table"then
				for _,entry in ipairs(tally)do
					if type(entry.guid)=="string"then
						swings[entry.guid]=figure(entry.swing)
					end
				end
			end
		end
		local groups,keyed=specGroups(record)
		groupsOf[c]={list=groups,keyed=keyed}
		for _,group in ipairs(groups)do
			local row=byKey[group.key]
			if not row then
				row={key=group.key,classToken=group.classToken,spec=group.spec,class=group.class,
					cells={},met=0}
				byKey[group.key]=row
				lobby.rows[#lobby.rows+1]=row
			end
			row.met=row.met+1
			local cell={count=#group.guids}
			if lobby.swing then
				local each,furthest={},nil
				for i,guid in ipairs(group.guids)do
					local s=swings[guid]
					each[i]=A.signedText(s)or"-"
					if s~=nil and(furthest==nil or math.abs(s)>math.abs(furthest))then
						furthest=s
					end
				end
				cell.value,cell.each=furthest,each
				cell.text=A.signedText(furthest)or"-"
				cell.tone=furthest==nil and"dim"or furthest>0 and"win"or furthest<0 and"loss"or"dim"
				if furthest~=nil then
					row.swung=true
				end
			else
				cell.value=#group.guids
				cell.text=tostring(#group.guids)
				cell.tone="text"
			end
			row.cells[c]=cell
		end
	end
	for _,row in ipairs(lobby.rows)do
		if lobby.swing and not row.swung then
			for _,cell in pairs(row.cells)do
				cell.tone="dim"
			end
		end
		local baseCell=row.cells[1]
		row.baseSwing=lobby.swing and baseCell~=nil and baseCell.value~=nil and math.abs(baseCell.value)or-1
	end
	table.sort(lobby.rows,function(a,b)
		if a.met~=b.met then
			return a.met>b.met
		end
		if a.baseSwing~=b.baseSwing then
			return a.baseSwing>b.baseSwing
		end
		if a.spec~=b.spec then
			return a.spec<b.spec
		end
		return a.classToken<b.classToken
	end)
	if not BATTLEGROUNDS[format]then
		lobby.shared={"base"}
		local baseKeyed=groupsOf[1].keyed
		for c=2,#records do
			local list=groupsOf[c].list
			if#list==0 then
				lobby.shared[c]="-"
			else
				local n=0
				for _,group in ipairs(list)do
					if baseKeyed[group.key]then
						n=n+1
					end
				end
				lobby.shared[c]=("%d of %d"):format(n,#list)
			end
		end
	end
	return lobby
end

function A.compareLobbyTooltip(row,cell)
	if type(row)~="table"or type(cell)~="table"or type(cell.each)~="table"or#cell.each<2 then
		return nil
	end
	return("%s %s: %s"):format(row.spec,row.class or row.classToken,table.concat(cell.each,", "))
end

function A.compareRoundLines(records)
	local lines={}
	if type(records)~="table"or#records==0 or not SHUFFLES[records[1].format]then
		return lines
	end
	for c,record in ipairs(records)do
		local word,tone=A.compareResultWord(record)
		local line={id="#"..A.matchIdText(record.id),word=word,tone=tone,rounds={}}
		local rounds=type(record.rounds)=="table"and record.rounds or{}
		for r=1,#rounds do
			local won=nil
			if type(A.roundResult)=="function"then
				local ok,got=pcall(A.roundResult,record,r)
				if ok and type(got)=="boolean"then
					won=got
				end
			end
			local card={n=r,letter="-",tone="dim",mates={}}
			if won~=nil then
				card.letter,card.tone=won and"W"or"L",won and"win"or"loss"
			end
			local mates=type(A.roundSides)=="function"and A.roundSides(record,rounds[r])or nil
			for _,entry in ipairs(type(mates)=="table"and mates or{})do
				local p=type(entry.p)=="table"and entry.p or{}
				card.mates[#card.mates+1]={classToken=p.classToken,spec=p.spec,class=p.class}
			end
			line.rounds[r]=card
		end
		lines[c]=line
	end
	return lines
end

function A.compareSecondReading(records)
	local lobby=A.compareLobby(records)
	local lines=A.compareRoundLines(records)
	return{lobby=lobby,lines=lines,lobbyRows=#lobby.rows,roundLines=#lines,
		scrolled=#lobby.rows>LOBBY_MOST}
end

function A.compareSetTab(tab,via)
	if tab~="figures"and tab~="rounds"then
		return false,"word"
	end
	if tab=="rounds"and A.compareSecondTab(picked.format)==nil then
		return false,"none"
	end
	openTab=tab
	if type(A.compareSetChanged)=="function"then
		pcall(A.compareSetChanged)
	end
	local reading=A.compareSecondReading(prune())
	A.trace("compare/tab",{
		tab=tab,via=via,lobbyRows=reading.lobbyRows,roundLines=reading.roundLines,
		scrolled=reading.scrolled,
	},"ui")
	return true
end

function A.compareLobbyLines(records,lobby)
	local out={}
	for _,row in ipairs(lobby and lobby.rows or{})do
		local parts={}
		for c,record in ipairs(records)do
			local cell=row.cells[c]
			local text=cell and cell.text or"none"
			if cell and cell.each and#cell.each>1 then
				text=text.." ("..table.concat(cell.each,", ")..")"
			end
			parts[c]=("#%s %s"):format(A.matchIdText(record.id),text)
		end
		out[#out+1]=("lobby %s %s: %s"):format(row.spec,row.class or row.classToken,table.concat(parts,", "))
	end
	if lobby and lobby.shared then
		local parts={}
		for c,record in ipairs(records)do
			parts[c]=("#%s %s"):format(A.matchIdText(record.id),lobby.shared[c]or"-")
		end
		out[#out+1]="shared with base: "..table.concat(parts,", ")
	end
	return out
end

function A.compareRoundTexts(lines)
	local out={}
	for _,line in ipairs(lines or{})do
		local letters,seated={},0
		for r,card in ipairs(line.rounds)do
			letters[r]=card.letter
			if#card.mates>0 then
				seated=seated+1
			end
		end
		out[#out+1]=("rounds %s %s: %s, mates read in %d of %d"):format(line.id,line.word or"-",
			#letters>0 and table.concat(letters," ")or"none",seated,#line.rounds)
	end
	return out
end

local function newestOnTab(n,sameFormat)
	local seen,format=0,nil
	for _,entry in ipairs(A.drawnEntries())do
		if entry.kind=="match"then
			if format==nil then
				format=type(entry.subject)=="table"and entry.subject.format or nil
			end
			if not sameFormat or(type(entry.subject)=="table"and entry.subject.format==format)then
				seen=seen+1
				if seen==n then
					return entry.subject
				end
			end
		end
	end
	if sameFormat then
		A.say(("the list the window shows draws %d matches of its newest one's type, so there is no number %d")
			:format(seen,n))
	else
		A.say(("the list the window shows draws %d matches, so there is no number %d"):format(seen,n))
	end
	return nil
end

local RECORD_USAGE={
	add="/pvph compare add <id|last [n]>: a stored match's id, or last for the newest on the tab",
	box="/pvph compare box <id|last [n]>: a stored match's id, or last n for the nth newest on the tab "
		.."of the newest one's match type",
}

local function typedRecord(word,count,verb)
	verb=verb or"add"
	if word==nil then
		A.say(RECORD_USAGE[verb])
		return nil
	end
	if word:lower()=="last"then
		local n=A.wholeArgument(count or"1")
		if n==nil then
			A.say(("%q is not a count. last 2 is the second newest on the tab"):format(tostring(count)))
			return nil
		end
		return newestOnTab(n,verb=="box")
	end
	local id=A.matchIdFromWord(word)
	if not id then
		A.say(("%q is not a match id. /pvph list to see what is held"):format(word))
		return nil
	end
	local record=A.match(id)
	if not record then
		A.say(("no stored match has id %s"):format(tostring(id)))
		return nil
	end
	return record
end

function A.compareSetLine()
	if#picked.ids==0 then
		return"compare: nothing picked"
	end
	local ids={}
	for i=1,#picked.ids do
		ids[i]="#"..A.matchIdText(picked.ids[i])
	end
	return("compare: %s, base %s; columns %s; tab %s"):format(A.compareCountText(),ids[1],
		table.concat(ids,", "),A.compareTab())
end

local function refusedWhy(reason)
	return reason=="format"and("the set holds %s"):format(A.formatPlural(picked.format))
		or reason=="full"and"the set holds four"
		or"the match has no format to compare on"
end

function A.reportCompare(words)
	local verb=words[2]and words[2]:lower()or nil
	if verb==nil then
		A.say(A.compareSetLine())
		local boxes=A.compareBoxLine()
		if boxes~=nil then
			A.say(boxes)
		end
		return
	end
	if verb=="box"then
		local record=typedRecord(words[3],words[4],"box")
		if not record then
			return
		end
		local action,reason=pressBox(record)
		local id=A.matchIdText(record.id)
		if action=="none"then
			A.say(("compare: #%s draws no box, the match has no format to compare on"):format(id))
		elseif action=="refused"then
			A.say(("compare: box on #%s refused, %s (%s)"):format(id,reason,refusedWhy(reason)))
		elseif action=="remove"then
			A.say(("compare: box on #%s took it out, %d picked"):format(id,#picked.ids))
		else
			A.say(("compare: box on #%s picked it, %d picked"):format(id,#picked.ids))
		end
		return
	end
	if verb=="add"then
		local record=typedRecord(words[3],words[4])
		if not record then
			return
		end
		local action,reason=A.compareAdd(record,"typed")
		local id=A.matchIdText(record.id)
		if action=="refused"then
			A.say(("compare: #%s refused, %s (%s)"):format(id,reason,refusedWhy(reason)))
		elseif action=="held"then
			A.say(("compare: #%s is already picked, %d picked"):format(id,#picked.ids))
		else
			A.say(("compare: added #%s, %d picked"):format(id,#picked.ids))
		end
		return
	end
	if verb=="remove"then
		local id=A.matchIdFromWord(words[3]or"")
		if id==nil then
			A.say("/pvph compare remove <id>: a picked match's id")
			return
		end
		local action=A.compareRemove(id,"typed")
		A.say(action=="remove"and("compare: removed #%s, %d picked"):format(A.matchIdText(id),#picked.ids)
			or("compare: #%s is not picked"):format(A.matchIdText(id)))
		return
	end
	if verb=="clear"then
		A.compareClear("typed")
		A.say("compare: cleared, nothing picked")
		return
	end
	if verb=="open"then
		if#picked.ids<2 then
			A.say(("compare: open needs two matches, %d picked"):format(#picked.ids))
			return
		end
		local opened=type(A.showCompareWindow)=="function"and A.showCompareWindow()
		A.say(opened and A.compareSetLine()or"compare: the window could not be opened")
		return
	end
	if verb=="close"then
		local closed=type(A.hideCompareWindow)=="function"and A.hideCompareWindow()
		A.say(closed and"compare: window closed, the set kept"or"compare: the window is not open")
		return
	end
	if verb=="base"then
		local id=A.matchIdFromWord(words[3]or"")
		local column=id~=nil and A.compareColumnOf(id)or nil
		if column==nil then
			A.say("/pvph compare base <id>: a picked match's id")
			return
		end
		if column==1 then
			A.say(("compare: #%s is already the base"):format(A.matchIdText(id)))
			return
		end
		A.compareMoveBase(column,"typed")
		A.say(A.compareSetLine())
		return
	end
	if verb=="rows"then
		local records=A.compareRecords()
		if#records==0 then
			A.say("compare: nothing picked, so no rows")
			return
		end
		local rows,hidden,folded=A.compareRows(records)
		A.say(("compare: %d rows drawn, left out: %s"):format(#rows,A.compareKeysText(hidden)or"none"))
		for _,line in ipairs(A.compareRowLines(records,rows))do
			A.say(line)
		end
		local same=A.compareFoldText(folded)
		A.say(same and("%s: %s"):format(A.compareFoldLabel(#records),same)or"compare: no row folded")
		if A.compareTab()=="rounds"then
			local reading=A.compareSecondReading(records)
			for _,line in ipairs(A.compareRoundTexts(reading.lines))do
				A.say(line)
			end
			for _,line in ipairs(A.compareLobbyLines(records,reading.lobby))do
				A.say(line)
			end
		end
		return
	end
	if verb=="tab"then
		local word=words[3]and words[3]:lower()or nil
		if word~="figures"and word~="rounds"then
			A.say("/pvph compare tab <figures||rounds>: rounds opens the second tab on any match type that has one")
			return
		end
		if#picked.ids==0 then
			A.say("compare: nothing picked, so no tab")
			return
		end
		local ok=A.compareSetTab(word,"typed")
		A.say(ok and("compare: tab %s"):format(word)
			or("compare: no second tab for %s"):format(A.formatLabel(picked.format)))
		return
	end
	A.say(("/pvph compare takes add, box, remove, clear, open, base, close, rows or tab, and %q is none of them")
		:format(verb))
end
