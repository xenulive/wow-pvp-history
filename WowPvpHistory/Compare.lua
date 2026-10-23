-- WowPvpHistory 0.70.7
-- Author:  Xenu-Sentinels
-- Project: wow-pvp-history
--          https://github.com/xenulive/wow-pvp-history
-- License: MIT, see LICENSE
local _,A=...

local MOST=4

local picked={ids={},held={},format=nil}

local hooked={}

function A.compareIds()
	local out={}
	for i=1,#picked.ids do
		out[i]=picked.ids[i]
	end
	return out
end

local function prune()
	local out={}
	local gone={}
	for i=1,#picked.ids do
		local record=type(A.match)=="function"and A.match(picked.ids[i])or nil
		if record then
			out[#out+1]=record
		else
			gone[#gone+1]=picked.ids[i]
		end
	end
	for i=1,#gone do
		for j=#picked.ids,1,-1 do
			if picked.ids[j]==gone[i]then
				table.remove(picked.ids,j)
			end
		end
		picked.held[gone[i]]=nil
	end
	if#picked.ids==0 then
		picked.format=nil
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
		return"Holds "..A.formatPlural(picked.format)
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

local function takeOut(id)
	for i=#picked.ids,1,-1 do
		if picked.ids[i]==id then
			table.remove(picked.ids,i)
		end
	end
	picked.held[id]=nil
	if#picked.ids==0 then
		picked.format=nil
	end
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

function A.paintCompareBox(row,at)
	if type(row)~="table"then
		return nil
	end
	local listRow=at=="list"and not row.isSeparator and row.entryKind=="match"and row.matchId~=nil
	if not listRow then
		hideBox(row)
		return nil
	end
	local shape=nil
	if A.comparePicked(row.matchId)then
		shape="picked"
	elseif row.compareHover==true and type(row.matchRecord)=="table"and A.compareAdmits(row.matchRecord)then
		shape="empty"
	end
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
		box.edge:SetColorTexture(A.color("dim"))
		box.fill:SetColorTexture(A.color("field"))
		box.check:Hide()
	end
	box.edge:Show()
	box.fill:Show()
	return shape
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

local function hoverLine(owner,text)
	if not(GameTooltip and type(text)=="string")then
		return
	end
	pcall(function()
		GameTooltip:SetOwner(owner,"ANCHOR_TOP")
		if type(A.styleTooltip)=="function"then
			A.styleTooltip(GameTooltip)
		end
		local r,g,b=A.color("text")
		GameTooltip:SetText(text,r,g,b,1,true)
		GameTooltip:Show()
	end)
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
		hoverLine(self,A.compareButtonTooltip())
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

local function specsMet(record)
	local out,seen={},{}
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
			if not seen[key]then
				seen[key]=true
				out[#out+1]={key=key,classToken=token,spec=spec,class=p.class}
			end
		end
	end
	return out
end

local function largestSwing(record)
	if type(A.lobbyTally)~="function"then
		return nil
	end
	local ok,rows=pcall(A.lobbyTally,record)
	if not ok or type(rows)~="table"then
		return nil
	end
	local best=nil
	for i=1,#rows do
		local swing=figure(rows[i].swing)
		if swing~=nil and(best==nil or math.abs(swing)>math.abs(best.value))then
			best={value=swing,classToken=rows[i].classToken,spec=rows[i].spec,class=rows[i].class}
		end
	end
	return best
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
	{key="swing",label="Swing",group="YOU",kind="swing",only=SHUFFLES},
	{key="specs",label="Specs met",group="LOBBY",kind="text",skip=NO_SCOREBOARD},
	{key="common",label="In common",group="LOBBY",kind="text",skip=NO_SCOREBOARD},
}

local function rowApplies(spec,format)
	if spec.only and not spec.only[format]then
		return false
	end
	if spec.skip and spec.skip[format]then
		return false
	end
	if spec.rated and not A.movesRating(format)then
		return false
	end
	return true
end

local function cellFor(spec,record,base)
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
	elseif key=="swing"then
		local swing=largestSwing(record)
		if swing==nil then
			return{text="-"}
		end
		return{value=swing.value,text=A.signedText(swing.value),
			icons={{classToken=swing.classToken,spec=swing.spec,class=swing.class}}}
	elseif key=="specs"then
		local specs=specsMet(record)
		if#specs==0 then
			return{text="-"}
		end
		return{text=("%d"):format(#specs),icons=specs,present=true}
	elseif key=="common"then
		if base==nil or record==base then
			return{text="base",base=true}
		end
		local held,shared={},{}
		for _,met in ipairs(specsMet(base))do
			held[met.key]=true
		end
		local mine=specsMet(record)
		if#mine==0 or next(held)==nil then
			return{text="-"}
		end
		for _,met in ipairs(mine)do
			if held[met.key]then
				shared[#shared+1]=met
			end
		end
		return{text=("%d"):format(#shared),icons=shared,present=true}
	end
	return{text="-"}
end

local function holds(cell)
	return cell.value~=nil or cell.present==true
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
			end
		end
	end
end

function A.compareRows(records)
	local rows,hidden={},{}
	if type(records)~="table"or#records==0 then
		return rows,hidden
	end
	local format=records[1].format
	local base=records[1]

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
		settle(spec,cells)
		rows[#rows+1]={key=key,label=label,group=spec.group,kind=spec.kind,tier=spec.tier,
			cells=cells}
	end

	for _,spec in ipairs(ROWS)do
		if not rowApplies(spec,format)then
			hidden[#hidden+1]=spec.key
		elseif spec.expands then
			local names,values={},{}
			for c,record in ipairs(records)do
				values[c]={}
				for _,column in ipairs(objectiveValues(record))do
					if values[c][column.name]==nil then
						values[c][column.name]=column
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
				cells[c]=cellFor(spec,record,base)
			end
			finish(spec,spec.label,spec.key,cells)
		end
	end
	return rows,hidden
end

function A.compareTitle(count,format)
	return("Compare %d %s"):format(count,A.formatPlural(format))
end

function A.compareHeadLines(record)
	local map=type(record.map)=="table"and type(record.map.name)=="string"and record.map.name or"-"
	return"#"..A.matchIdText(record.id),map,A.shortDayText(record.openedAt)or"-"
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

local function newestOnTab(n)
	local seen=0
	for _,entry in ipairs(A.drawnEntries())do
		if entry.kind=="match"then
			seen=seen+1
			if seen==n then
				return entry.subject
			end
		end
	end
	A.say(("the list the window shows draws %d matches, so there is no number %d"):format(seen,n))
	return nil
end

local function typedRecord(word,count)
	if word==nil then
		A.say("/pvph compare add <id|last [n]>: a stored match's id, or last for the newest on the tab")
		return nil
	end
	if word:lower()=="last"then
		local n=A.wholeArgument(count or"1")
		if n==nil then
			A.say(("%q is not a count. last 2 is the second newest on the tab"):format(tostring(count)))
			return nil
		end
		return newestOnTab(n)
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
	return("compare: %s, base %s; columns %s"):format(A.compareCountText(),ids[1],table.concat(ids,", "))
end

function A.reportCompare(words)
	local verb=words[2]and words[2]:lower()or nil
	if verb==nil then
		A.say(A.compareSetLine())
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
			local why=reason=="format"and("the set holds %s"):format(A.formatPlural(picked.format))
				or reason=="full"and"the set holds four"
				or"the match has no format to compare on"
			A.say(("compare: #%s refused, %s (%s)"):format(id,reason,why))
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
		local rows,hidden=A.compareRows(records)
		A.say(("compare: %d rows drawn, left out: %s"):format(#rows,A.compareKeysText(hidden)or"none"))
		for _,line in ipairs(A.compareRowLines(records,rows))do
			A.say(line)
		end
		return
	end
	A.say(("/pvph compare takes add, remove, clear, open, base, close or rows, and %q is none of them"):format(verb))
end
