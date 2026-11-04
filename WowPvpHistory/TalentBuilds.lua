-- WowPvpHistory 0.75.26
-- Author:  Xenu-Sentinels
-- Project: wow-pvp-history
--          https://github.com/xenulive/wow-pvp-history
-- License: MIT, see LICENSE
local ADDON,A=...

local TITLE="PvPHistory Builds"
local EMPTY="No recorded matches on this spec yet"

local FRAME_NAME=ADDON.."TalentBuilds"
local LOOK="blizzard"

local RAIDERIO_BUTTON="RaiderIO_TalentBuildsTalentFrameShortcut"
local BUTTON_HEIGHT,BUTTON_MIN_WIDTH,BUTTON_SCALE,BUTTON_TEXT_PAD,BUTTON_RISE=25,160,0.9,10,16

local TITLE_BAND=24

local RECOMMEND_FLOOR=10

local held={format=nil,season="season"}

local last

local toggle,panel,hookedRaider
local installed,waitingCombat=false,false

local function talentsTab()
	local frame=PlayerSpellsFrame
	local tab=type(frame)=="table"and frame.TalentsFrame or nil
	return type(tab)=="table"and tab or nil
end

local function activeSpec()
	local info=C_SpecializationInfo
	if type(info)~="table"or type(info.GetSpecialization)~="function"
		or type(info.GetSpecializationInfo)~="function"or type(UnitClass)~="function"then
		return nil
	end
	local okIndex,index=pcall(info.GetSpecialization)
	if not okIndex or not A.canRead(index)or type(index)~="number"then
		return nil
	end
	local okInfo,_,name=pcall(info.GetSpecializationInfo,index)
	if not okInfo or not A.canRead(name)or type(name)~="string"or name==""then
		return nil
	end
	local okClass,_,token=pcall(UnitClass,"player")
	if not okClass or not A.canRead(token)or type(token)~="string"or token==""then
		return nil
	end
	return name,token
end

local function seasonArg(word)
	if word=="all"then
		return nil
	end
	if type(word)=="number"then
		return word
	end
	local ok,season=pcall(A.seasonNewest)
	return ok and season or nil
end

local function seasonLabel(word)
	if word=="all"then
		return"All time"
	end
	if type(word)=="number"then
		return type(A.scopeLabel)=="function"and A.scopeLabel(("season%d"):format(word))or("Season %d"):format(word)
	end
	return"This season"
end

local function seasonChoices(character)
	local out={{value="season",label=seasonLabel("season")},{value="all",label=seasonLabel("all")}}
	local db=A.db()
	local matches=db and type(db.matches)=="table"and db.matches or{}
	local okNewest,current=pcall(A.seasonNewest)
	current=okNewest and current or nil
	local seen,past={},{}
	for i=1,#matches do
		local record=matches[i]
		if type(record)=="table"and A.recordedBy(record,character)and A.buildsViewOffered(record.format)then
			local ok,n=pcall(A.recordSeason,record)
			if ok and type(n)=="number"and n~=current and not seen[n]then
				seen[n]=true
				past[#past+1]=n
			end
		end
	end
	table.sort(past,function(a,b)return a>b end)
	for i=1,#past do
		out[#out+1]={value=past[i],label=seasonLabel(past[i])}
	end
	return out
end

local function formatCounts(season,character,spec,token)
	local counts,formats,total={},{},0
	local db=A.db()
	local matches=db and type(db.matches)=="table"and db.matches or{}
	for i=1,#matches do
		local record=matches[i]
		if type(record)=="table"and A.buildsViewOffered(record.format)
			and(season==nil or A.recordInSeason(record,season))and A.recordedBy(record,character)
			and A.recordPlayedSpec(record,spec,token)then
			local format=record.format or"unknown"
			if counts[format]==nil then
				counts[format]=0
				formats[#formats+1]=format
			end
			counts[format]=counts[format]+1
			total=total+1
		end
	end
	table.sort(formats,function(a,b)
		if counts[a]~=counts[b]then
			return counts[a]>counts[b]
		end
		return a<b
	end)
	return counts,formats,total
end

local function activeString()
	if type(A.readTalents)~="function"then
		return nil
	end
	local ok,block=pcall(A.readTalents)
	return ok and type(block)=="table"and type(block.string)=="string"and block.string or nil
end

function A.talentBuildsReading(formatWord,seasonWord)
	seasonWord=seasonWord or"season"
	local spec,token=activeSpec()
	local character=A.ownGuid()
	local season=seasonArg(seasonWord)
	local reading={spec=spec,classToken=token,seasonWord=seasonWord,seasonLabel=seasonLabel(seasonWord),
		seasons=seasonChoices(character),rows={},total=0,formatWord="all",formatLabel="All"}
	if seasonWord=="season"and season==nil then
		reading.seasonLabel="This season, no season boundary declared, so all time"
	end
	if spec==nil then
		reading.brackets={{value="all",label="All  0"}}
		reading.empty=EMPTY
		return reading
	end

	local counts,formats,total=formatCounts(season,character,spec,token)
	local brackets={{value="all",label=("All  %d"):format(total)}}
	for i=1,#formats do
		brackets[#brackets+1]={value=formats[i],label=("%s  %d"):format(A.formatLabel(formats[i]),counts[formats[i]])}
	end
	reading.brackets=brackets
	local picked=formatWord
	if picked==nil or(picked~="all"and counts[picked]==nil)then
		picked=formats[1]or"all"
	end
	reading.formatWord=picked
	reading.formatLabel=picked=="all"and"All"or A.formatLabel(picked)

	local format=picked~="all"and picked or nil
	local order,considered,before,unread=A.buildTally(format,season,character,nil,spec,token)
	local names=A.buildRowNames(order,false)
	reading.total=considered

	local best
	for i=1,#order do
		local row=order[i]
		if row.decided>=RECOMMEND_FLOOR and row.winRate~=nil and(best==nil or row.winRate>best.winRate)then
			best=row
		end
	end

	local current=activeString()
	for i=1,#order do
		local row=order[i]
		local wins,losses=A.winRecord(row)
		local icons=A.pvpTalentIcons(row.pvp)
		reading.rows[i]={name=names[i],played=row.played,share=considered>0 and row.played/considered or nil,
			wins=wins or 0,losses=losses or 0,rate=row.winRate,rating=row.rating,icons=icons,id=row.newestID,
			digest=A.buildDigest(row.string),recommended=row==best,
			active=current~=nil and row.string==current}
		if row==best then
			reading.recommended=reading.rows[i].digest
		end
		if reading.rows[i].active then
			reading.active=reading.rows[i].digest
		end
	end
	reading.note=A.buildsNote(before,unread)
	if#order==0 then
		reading.empty=reading.note or EMPTY
	end
	return reading
end

function A.talentBuildsFigures(row)
	return("%s (%d)"):format(A.percentText(row.share)or"-",row.played),A.percentText(row.rate)or"-",
		("%d-%d"):format(row.wins,row.losses),A.signedText(row.rating)or"-"
end

local function marksText(row)
	if row.recommended and row.active then
		return"Recommended, Active"
	end
	return row.recommended and"Recommended"or row.active and"Active"or nil
end

local paint

local function rowRegions(index)
	local pool=panel.rowPool
	local regions=pool[index]
	if regions then
		return regions
	end
	regions={name=A.lineText(panel,"bodyText"),marks=A.lineText(panel,"bodyText","RIGHT"),figures={},icons={}}
	regions.star=panel:CreateTexture(nil,"OVERLAY")
	regions.star:SetTexture(A.STAR_TEXTURE)
	for i=1,4 do
		regions.figures[i]=A.lineText(panel,"numberSmall","RIGHT")
	end
	regions.load=A.pill(panel,"Load",function(self)
		if self.buildID~=nil then
			A.loadBuild(self.buildID)
		end
	end)
	regions.load.themeLock=LOOK
	A.setControlTone(regions.load,nil)
	pool[index]=regions
	return regions
end

local function hideRowsFrom(index)
	for i=index,#panel.rowPool do
		local regions=panel.rowPool[i]
		regions.name:Hide()
		regions.marks:Hide()
		regions.star:Hide()
		regions.load:Hide()
		for f=1,#regions.figures do
			regions.figures[f]:Hide()
		end
		for k=1,#regions.icons do
			regions.icons[k]:Hide()
		end
	end
end

local function layout(reading)
	local padX,padY=A.metric("finderPadX"),A.metric("finderPadY")
	local gap,colGap=A.metric("finderGap"),A.metric("finderColGap")
	local lineH,controlH=A.fontSize("bodyText"),A.metric("controlHeight")
	local starSize,iconSize=A.metric("rowStar"),A.metric("rowTalentIcon")
	local iconStep=iconSize+A.metric("rowTalentGap")

	A.setDropdownChoices(panel.bracket,reading.brackets,reading.formatWord)
	A.setDropdownChoices(panel.season,reading.seasons,reading.seasonWord)

	local rows=reading.rows
	local widths,iconsWide,loadWide,lineWide={0,0,0,0},0,0,0
	for i=1,#rows do
		local row,regions=rows[i],rowRegions(i)
		A.style(regions.name,"bodyText","text")
		regions.name:SetText(row.name)
		local marks=marksText(row)
		A.style(regions.marks,"bodyText",row.recommended and"accent"or"text")
		regions.marks:SetText(marks or"")
		local markWide=marks and A.textRoom(regions.marks,marks)+(row.recommended and starSize+gap or 0)or 0
		lineWide=math.max(lineWide,A.textRoom(regions.name,row.name)+(markWide>0 and colGap+markWide or 0))
		local figures={A.talentBuildsFigures(row)}
		local tones={"dim",A.winRateTone(row.rate)or"dim","text",
			type(row.rating)=="number"and(row.rating>0 and"win"or row.rating<0 and"loss")or"dim"}
		for f=1,4 do
			A.style(regions.figures[f],"numberSmall",tones[f])
			regions.figures[f]:SetText(figures[f])
			widths[f]=math.max(widths[f],A.textRoom(regions.figures[f],figures[f]))
		end
		iconsWide=math.max(iconsWide,#row.icons*iconStep)
		regions.load.buildID=row.id
		loadWide=math.max(loadWide,regions.load:GetWidth()or 0)
	end
	hideRowsFrom(#rows+1)

	local figuresWide=widths[1]+widths[2]+widths[3]+widths[4]+3*colGap
	local inner=math.max(A.textRoom(panel.TitleContainer.TitleText,TITLE),2*A.metric("dropdownWidth")+colGap,lineWide,
		figuresWide+(iconsWide>0 and colGap+iconsWide or 0)+colGap+loadWide)
	local foot=reading.empty or reading.note
	A.style(panel.foot,"bodyText","dim")
	panel.foot:SetText(foot or"")
	if foot then
		inner=math.max(inner,A.textRoom(panel.foot,foot))
	end

	local y=TITLE_BAND+gap
	panel.bracket:ClearAllPoints()
	panel.bracket:SetPoint("TOPLEFT",panel,"TOPLEFT",padX,-y)
	panel.bracket:Show()
	panel.season:ClearAllPoints()
	panel.season:SetPoint("TOPLEFT",panel.bracket,"TOPRIGHT",colGap,0)
	panel.season:Show()
	y=y+controlH+gap

	for i=1,#rows do
		local row,regions=rows[i],panel.rowPool[i]
		regions.name:ClearAllPoints()
		regions.name:SetPoint("TOPLEFT",panel,"TOPLEFT",padX,-y)
		regions.name:Show()
		regions.marks:ClearAllPoints()
		regions.marks:SetPoint("TOPRIGHT",panel,"TOPRIGHT",-padX,-y)
		regions.marks:SetShown(marksText(row)~=nil)
		regions.star:ClearAllPoints()
		regions.star:SetSize(starSize,starSize)
		regions.star:SetPoint("RIGHT",regions.marks,"LEFT",-gap,0)
		regions.star:SetShown(row.recommended)
		y=y+lineH+gap
		local x=padX
		for f=1,4 do
			x=x+widths[f]
			regions.figures[f]:ClearAllPoints()
			regions.figures[f]:SetPoint("TOPRIGHT",panel,"TOPLEFT",x,-y)
			regions.figures[f]:Show()
			x=x+colGap
		end
		for k=1,#row.icons do
			local icon=regions.icons[k]
			if not icon then
				icon=panel:CreateTexture(nil,"OVERLAY")
				regions.icons[k]=icon
			end
			icon:SetTexture(row.icons[k])
			icon:SetSize(iconSize,iconSize)
			icon:ClearAllPoints()
			icon:SetPoint("TOPLEFT",panel,"TOPLEFT",x+(k-1)*iconStep,-y)
			icon:Show()
		end
		for k=#row.icons+1,#regions.icons do
			regions.icons[k]:Hide()
		end
		regions.load:ClearAllPoints()
		regions.load:SetPoint("TOPRIGHT",panel,"TOPRIGHT",-padX,-y)
		regions.load:SetShown(row.id~=nil)
		y=y+math.max(lineH,controlH)+gap
	end

	panel.foot:ClearAllPoints()
	panel.foot:SetPoint("TOPLEFT",panel,"TOPLEFT",padX,-y)
	panel.foot:SetShown(foot~=nil)
	if foot then
		y=y+lineH+gap
	end
	panel:SetSize(inner+2*padX,y-gap+padY)
end

local function screenCentre(frame)
	if type(frame)~="table"or type(frame.GetCenter)~="function"or type(frame.GetEffectiveScale)~="function"then
		return nil
	end
	local ok,x,y=pcall(frame.GetCenter,frame)
	local okScale,scale=pcall(frame.GetEffectiveScale,frame)
	if not(ok and okScale and A.canRead(x)and A.canRead(y)and A.canRead(scale))or type(x)~="number"
		or type(y)~="number"or type(scale)~="number"then
		return nil
	end
	return x*scale,y*scale
end

local schedule=A.nextFrameOnce(function()
	paint()
end,"talent-builds-paint")

local function placeButton(tab)
	local raider=rawget(_G,RAIDERIO_BUTTON)
	if raider~=hookedRaider and type(raider)=="table"and type(raider.HookScript)=="function"then
		hookedRaider=raider
		raider:HookScript("OnShow",schedule)
		raider:HookScript("OnHide",schedule)
	end
	local system=type(tab.LoadSystem)=="table"and tab.LoadSystem or nil
	local dropdown=system and type(system.Dropdown)=="table"and system.Dropdown or system
	local place
	toggle:ClearAllPoints()
	if A.frameShown(raider)then
		toggle:SetPoint("LEFT",raider,"RIGHT",A.metric("finderGap"),0)
		place="beside-raiderio"
	elseif dropdown then
		toggle:SetPoint("BOTTOMLEFT",dropdown,"TOPLEFT",0,BUTTON_RISE)
		place="raiderio-place"
	else
		toggle:SetPoint("BOTTOMLEFT",tab,"BOTTOMLEFT",A.metric("finderPadX"),A.metric("finderPadY"))
		place="tab-corner"
	end
	toggle:Show()
	return place
end

paint=function()
	local tab=talentsTab()
	if panel==nil or not(A.frameShown(PlayerSpellsFrame)and A.frameShown(tab))then
		return
	end
	local place=placeButton(tab)
	local reading=A.talentBuildsReading(held.format,held.season)
	last=reading
	local open=panel:IsShown()
	if open then
		A.withTheme(LOOK,layout,reading)
	end
	local state=open and(#reading.rows==0 and"empty"or"open")or"shut"
	reading.state,reading.anchor=state,place
	A.trace("talent-builds",{spec=reading.spec and("%s/%s"):format(reading.spec,reading.classToken)or"none",
		format=reading.formatWord,season=seasonArg(reading.seasonWord),rows=#reading.rows,
		recommended=reading.recommended or"none",active=reading.active or"none",state=state,
		anchor=place},"ui")
end

local function hidePanel()
	if panel then
		panel:Hide()
	end
end

local function openPanel()
	panel:ClearAllPoints()
	panel:SetPoint("CENTER",PlayerSpellsFrame,"CENTER",0,0)
	panel:Show()
	paint()
	local px,py=screenCentre(panel)
	local tx,ty=screenCentre(PlayerSpellsFrame)
	local dx=px and tx and A.unitFigure(px-tx)or"unread"
	local dy=py and ty and A.unitFigure(py-ty)or"unread"
	A.trace("talent-builds-place",{centered=dx==0 and dy==0,offsetX=dx,offsetY=dy},"ui")
end

local function toggled()
	if panel==nil or not A.frameShown(PlayerSpellsFrame)then
		return
	end
	if panel:IsShown()then
		panel:Hide()
		return
	end
	local ok,err=pcall(openPanel)
	if not ok then
		A.noteError(err,"talent-builds-open")
	end
end

local function propagate(on)
	if type(InCombatLockdown)=="function"and InCombatLockdown()then
		return false
	end
	return(pcall(panel.SetPropagateKeyboardInput,panel,on))
end

local function keyDown(_,key)
	if key~="ESCAPE"then
		return
	end
	local reason
	if type(GetCurrentKeyBoardFocus)=="function"and GetCurrentKeyBoardFocus()~=nil then
		reason="focus"
	elseif not(type(C_Timer)=="table"and type(C_Timer.After)=="function")then
		reason="no-timer"
	elseif propagate(false)then
		reason="closed"
		panel:Hide()
		C_Timer.After(0,function()
			propagate(true)
		end)
	else
		reason="combat"
	end
	A.trace("talent-builds-key",{reason=reason},"ui")
end

local function install()
	local tab=talentsTab()
	if installed or tab==nil or type(tab.HookScript)~="function"then
		return
	end
	if type(InCombatLockdown)=="function"and InCombatLockdown()then
		waitingCombat=true
		return
	end

	toggle=CreateFrame("Button",nil,tab,"UIPanelButtonTemplate")
	toggle:SetText(TITLE)
	toggle:SetScale(BUTTON_SCALE)
	toggle:SetSize(math.max(BUTTON_MIN_WIDTH,toggle:GetTextWidth()+2*BUTTON_TEXT_PAD),BUTTON_HEIGHT)
	toggle:RegisterForClicks("LeftButtonUp")
	toggle:SetScript("OnClick",toggled)

	panel=CreateFrame("Frame",FRAME_NAME,UIParent,"ButtonFrameTemplate")
	ButtonFrameTemplate_HidePortrait(panel)
	panel:SetFrameStrata("HIGH")
	panel:SetToplevel(true)
	panel:SetClampedToScreen(true)
	panel:SetMovable(true)
	panel:EnableMouse(true)
	panel:Hide()
	panel.Inset:Hide()
	panel:SetScript("OnKeyDown",keyDown)
	pcall(panel.EnableKeyboard,panel,true)
	propagate(true)

	local bar=panel.TitleContainer
	bar.TitleText:SetText(TITLE)
	bar:EnableMouse(true)
	bar:RegisterForDrag("LeftButton")
	bar:SetScript("OnDragStart",function()
		panel:StartMoving()
	end)
	bar:SetScript("OnDragStop",function()
		panel:StopMovingOrSizing()
	end)

	panel.foot=A.lineText(panel,"bodyText")
	panel.rowPool={}
	panel.bracket=A.dropdown(panel,{},function(value)
		held.format=value
		schedule()
	end)
	panel.season=A.dropdown(panel,{},function(value)
		held.season=value
		schedule()
	end)
	for _,dropdown in ipairs({panel.bracket,panel.season})do
		dropdown.themeLock=LOOK
		A.setControlTone(dropdown,nil)
	end

	panel:SetScript("OnHide",schedule)
	tab:HookScript("OnShow",schedule)
	tab:HookScript("OnHide",hidePanel)
	if type(PlayerSpellsFrame.HookScript)=="function"then
		PlayerSpellsFrame:HookScript("OnHide",hidePanel)
	end
	placeButton(tab)
	installed=true
	if A.frameShown(tab)then
		schedule()
	end
end

local function tryInstall()
	local ok,err=pcall(install)
	if not ok then
		A.noteError(err,"talent-builds-install")
		for _,built in ipairs({toggle,panel})do
			pcall(built.Hide,built)
		end
		toggle,panel=nil,nil
	end
end

A.on("PLAYER_LOGIN",tryInstall)

A.on("ADDON_LOADED",function(_,name)
	if name=="Blizzard_PlayerSpells"then
		tryInstall()
	end
end)

A.on("PLAYER_REGEN_ENABLED",function()
	if waitingCombat then
		waitingCombat=false
		tryInstall()
	end
end)

local function repaint()
	if installed and A.frameShown(talentsTab())then
		schedule()
	end
end

A.on("ACTIVE_TALENT_GROUP_CHANGED",repaint)
A.on("TRAIT_CONFIG_UPDATED",repaint)

function A.talentBuildsFrames()
	return toggle,panel
end

function A.talentBuildsLines()
	local reading=A.talentBuildsReading(held.format,held.season)
	local state=not installed and"not built"or panel:IsShown()and"open"or"shut"
	local lines={("talent builds: %s, %s, %s: %d %s over %d %s; window %s, button %s"):format(
		reading.spec and("%s %s"):format(reading.spec,reading.classToken)or"no spec read",reading.formatLabel,
		reading.seasonLabel,#reading.rows,#reading.rows==1 and"build"or"builds",reading.total,
		reading.total==1 and"match"or"matches",state,last and last.anchor or"none")}
	for i=1,#reading.rows do
		local row=reading.rows[i]
		local share,rate,record,rating=A.talentBuildsFigures(row)
		local marks=marksText(row)
		lines[#lines+1]=("%d. %s  %s  won %s %s  rating %s%s"):format(i,row.name,share,rate,record,rating,
			marks and"  "..marks or"")
	end
	if reading.empty then
		lines[#lines+1]=reading.empty
	elseif reading.note then
		lines[#lines+1]="note: "..reading.note
	end
	return lines
end
