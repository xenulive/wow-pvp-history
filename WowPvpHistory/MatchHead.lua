-- WowPvpHistory 0.75.26
-- Author:  Xenu-Sentinels
-- Project: wow-pvp-history
--          https://github.com/xenulive/wow-pvp-history
-- License: MIT, see LICENSE
local _,A=...

local LADDER_SLOTS=10
local CARD_SLOTS=6
local CARD_NAMES=6
local TEAM_CARD_PAIRS=4
local YOUR_LINE_CELLS=4

function A.matchRatingParts(format,from,to)
	if type(from)~="number"or type(to)~="number"then
		return nil,"no-rating"
	end
	local ladder,reason=A.ratingLadder(format)
	if ladder==nil then
		return nil,reason
	end
	local tiers=ladder.tiers
	local function tierAt(rating)
		for i=#tiers,1,-1 do
			if tiers[i].entry<=rating then
				return i
			end
		end
		return nil
	end
	local atFrom,atTo=tierAt(from),tierAt(to)
	if atFrom==nil or atTo==nil then
		return nil,"out-of-range"
	end

	local _,_,why,r,g,b=A.ratingColour(format,to)
	if r==nil then
		return nil,why
	end
	local word,wordWhy=A.tierWord(tiers[atTo].enum,tiers[atTo].name)
	if word==nil then
		return nil,wordWhy
	end
	local chip={word=word,r=r,g=g,b=b,reached=atFrom~=atTo and to>from}

	local low=math.max(1,math.min(atFrom,atTo)-1)
	local high=math.min(#tiers,math.max(atFrom,atTo)+1)
	local bars={}
	for i=low,high do
		local tier=tiers[i]
		local upper=tiers[i+1]and tiers[i+1].entry or nil
		if upper==nil then
			local below=tiers[i-1]
			upper=below and(tier.entry+tier.entry-below.entry)or tier.entry
		end
		local _,_,_,tr,tg,tb=A.ratingColour(format,tier.entry)
		bars[#bars+1]={
			word=A.tierWord(tier.enum,tier.name),entry=tier.entry,upper=upper,
			r=tr,g=tg,b=tb,here=i==atTo,
		}
	end
	local span={bars=bars,low=bars[1].entry,high=bars[#bars].upper,from=from,to=to}
	if span.high<=span.low then
		span=nil
	end
	return{chip=chip,ladder=span}
end

function A.matchRoundCards(record)
	local table_=type(A.roundTable)=="function"and A.roundTable(record)or nil
	if type(table_)~="table"or type(table_.rounds)~="table"then
		return nil
	end
	local own=type(record.participants)=="table"and record.character
		and record.participants[record.character]or nil
	local cards={}
	for i=1,#record.rounds do
		local row=table_.rounds[i]or{}
		local mates,foes={},{}
		local cut=0
		local ownHealer=false
		for _,cell in ipairs(row.mates or{})do
			if type(cell)=="table"and cell.self then
				ownHealer=A.healerCell(cell)
			elseif type(cell)=="table"then
				if#mates<CARD_NAMES then
					mates[#mates+1]=cell
				else
					cut=cut+1
				end
			end
		end
		for _,cell in ipairs(row.foes or{})do
			if type(cell)=="table"then
				if#mates+#foes<CARD_NAMES then
					foes[#foes+1]=cell
				else
					cut=cut+1
				end
			end
		end
		local word=row.result or"-"
		if row.byHand==true then
			word=word.."*"
		end
		local state=row.result==nil and"open"or(row.byHand==true and"typed"or"captured")
		local meter=nil
		if type(A.roundMeterLines)=="function"and type(record.character)=="string"then
			meter=A.roundMeterLines(record,record.character,i)
		end
		cards[i]={
			n=i,word=word,tone=row.tone or"dim",state=state,meter=meter,
			classToken=type(own)=="table"and own.classToken or nil,
			spec=type(own)=="table"and own.spec or nil,
			mates=mates,foes=foes,cut=cut,ownHealer=ownHealer,
			mmrYours=row.mmrYours,mmrTheirs=row.mmrTheirs,
		}
	end
	return cards
end

function A.matchTitleStamp(record)
	local stamp=type(record)=="table"and(record.openedAt or record.completedAt)or nil
	if stamp==nil then
		return nil
	end
	local raw=tostring(stamp)
	local text=raw:gsub("^(%d%d%d%d%-%d%d%-%d%d)T","%1 ")
	return A.stampWords(text)or raw
end

local STRIPE_WIDTH=5

function A.rosterStripeWidth()
	return STRIPE_WIDTH
end

function A.rosterStripeMark(guid,isSelf)
	if isSelf==true or type(guid)~="string"or type(A.noteFor)~="function"then
		return nil
	end
	local entry=A.noteFor(guid)
	if type(entry)~="table"or(type(entry.rating)~="number"and type(entry.attitude)~="number")then
		return nil
	end
	return(A.noteMark(entry))
end

function A.healerCell(cell)
	local word=type(cell)=="table"and cell.roleWord or nil
	return type(word)=="string"and(" "..word.." "):find(" HEAL ",1,true)~=nil
end

function A.cardHealers(card)
	if type(card)~="table"then
		return 0
	end
	local count=card.ownHealer==true and 1 or 0
	for _,side in ipairs({card.mates or{},card.foes or{}})do
		for _,cell in ipairs(side)do
			if A.healerCell(cell)then
				count=count+1
			end
		end
	end
	return count
end

local PLACE_SUFFIX={"st","nd","rd"}

local function placeText(place,of)
	if type(place)~="number"or type(of)~="number"then
		return nil
	end
	local tens=place%100
	local suffix=(tens>=11 and tens<=13)and"th"or(PLACE_SUFFIX[place%10]or"th")
	return("%d%s of %d"):format(place,suffix,of)
end

local function rankOf(own,rows,field)
	local mine=type(own)=="table"and own[field]or nil
	if type(mine)~="number"then
		return nil,nil
	end
	local above,held=0,0
	for i=1,#rows do
		local value=rows[i][field]
		if type(value)=="number"then
			held=held+1
			if value>mine then
				above=above+1
			end
		end
	end
	return above+1,held
end

function A.yourLineHead(record)
	if type(record)~="table"or record.format=="duel"or record.format=="world"
		or type(record.participants)~="table"or type(record.character)~="string"then
		return nil
	end
	local participants=record.participants
	local ownRow=participants[record.character]
	if type(ownRow)~="table"then
		return nil
	end
	local own=A.participantCells(record,{guid=record.character,p=ownRow,quiet=true},nil,nil)
	if type(own.damage)~="number"and type(own.healing)~="number"and type(own.kb)~="number"then
		return nil
	end
	local healer=A.healerCell(own)
	local field=healer and"healing"or"damage"

	local lobby={}
	for guid,p in pairs(participants)do
		if type(guid)=="string"and type(p)=="table"and not A.isBotGuid(guid)then
			lobby[#lobby+1]=A.participantCells(record,{guid=guid,p=p,quiet=true},nil,nil)
		end
	end
	local split=A.rosterSplit(record)
	local side=lobby
	if type(split)=="table"then
		side={}
		for _,entry in ipairs(split.own)do
			if not A.isBotGuid(entry.guid)then
				side[#side+1]=A.participantCells(record,{guid=entry.guid,p=entry.p,quiet=true},nil,nil)
			end
		end
	end
	local sum=0
	for i=1,#side do
		local value=side[i][field]
		if type(value)=="number"then
			sum=sum+value
		end
	end
	local mine=own[field]
	local share=(type(mine)=="number"and sum>0)and mine/sum or nil

	local figurePlace,figureOf=rankOf(own,lobby,field)
	local kbPlace,kbOf=rankOf(own,lobby,"kb")
	local cells={
		{key="figure",label=healer and"HEALING"or"DAMAGE",value=A.figureText(mine),
			place=placeText(figurePlace,figureOf)},
		{key="share",label=split and"OF YOUR SIDE"or"OF THE LOBBY",value=A.percentText(share)},
		{key="kb",label="KILLING BLOWS",value=type(own.kb)=="number"and("%d"):format(own.kb)or nil,
			place=placeText(kbPlace,kbOf)},
		{key="honor",label="HONOR LEVEL",
			value=type(own.honorLevel)=="number"and("%d"):format(own.honorLevel)or nil},
	}
	local words,drawn={"YOUR LINE"},0
	for i=1,#cells do
		local cell=cells[i]
		if cell.value~=nil then
			drawn=drawn+1
		end
		words[#words+1]=("%s %s%s"):format(cell.label,cell.value or"-",
			cell.place and(" "..cell.place)or"")
	end
	return{kind="yourLine",id=record.id,cells=cells,drawn=drawn,healer=healer,
		text=table.concat(words,"  ")}
end

function A.yourLineHeight()
	return A.metric("roundCardPad")*2+A.fontSize("label")+A.metric("roundCardLine")+A.fontSize("number")
end

local VERDICT_ROLE="dossierName"

function A.matchBannerLead()
	local chip=A.fontSize("label")+A.metric("headChipPad")
	return math.max(A.fontSize(VERDICT_ROLE),A.fontSize("number"),chip)
end

function A.matchBannerHeight()
	return A.metric("bannerPad")*2+A.matchBannerLead()+A.metric("headPad")+A.fontSize("heading")
end

function A.roundCardVsBand()
	return A.fontSize("note")+A.metric("roundCardLine")*2
end

function A.ladderHeight()
	return A.metric("ladderPad")*2+A.metric("ladderMark")+A.metric("ladderGap")
		+A.fontSize("label")
end

function A.roundCardsHeight(cards)
	local names=1
	for _,card in ipairs(type(cards)=="table"and cards or{})do
		local held=math.min(CARD_NAMES+1,1+#card.mates+#card.foes)
		if held>names then
			names=held
		end
	end
	local line=A.fontSize("note")+A.metric("roundCardLine")
	return A.metric("roundCardPad")*2+A.metric("roundCardEdge")+A.fontSize("label")
		+A.metric("roundCardLine")+names*line+A.roundCardVsBand()
end

local BUILD_ICONS=4

local function outline(line,layer)
	local box={}
	for i=1,4 do
		box[i]=line:CreateTexture(nil,layer or"ARTWORK")
	end
	return box
end

function A.buildMatchHeadParts(line)
	local regions=line.headRegions
	local function keep(region)
		regions[#regions+1]=region
		return region
	end
	local function text(template,justify)
		local fs=keep(line:CreateFontString(nil,"ARTWORK",template or"GameFontHighlightSmall"))
		fs:SetJustifyH(justify or"LEFT")
		fs:SetWordWrap(false)
		return fs
	end

	line.headPips={}
	for i=1,CARD_SLOTS do
		line.headPips[i]=keep(line:CreateTexture(nil,"ARTWORK"))
	end
	line.headChip=outline(line)
	for i=1,4 do
		keep(line.headChip[i])
	end
	line.headChipText=text("GameFontHighlightSmall","CENTER")
	line.headMmr=text("GameFontHighlightSmall","RIGHT")

	line.bannerBg=keep(line:CreateTexture(nil,"BACKGROUND"))
	line.bannerPlace=text("GameFontNormal")
	line.bannerNote=text("GameFontDisableSmall")
	line.bannerVerdict=text("GameFontNormalLarge","RIGHT")

	line.ladderBars,line.ladderWords,line.ladderEntries={},{},{}
	for i=1,LADDER_SLOTS do
		line.ladderBars[i]=keep(line:CreateTexture(nil,"ARTWORK"))
		line.ladderWords[i]=text("GameFontDisableSmall")
		line.ladderEntries[i]=text("GameFontHighlightSmall")
	end
	line.ladderMarks={keep(line:CreateTexture(nil,"OVERLAY")),keep(line:CreateTexture(nil,"OVERLAY"))}

	line.roundCards={}
	for c=1,CARD_SLOTS do
		local card={}
		card.bg=keep(line:CreateTexture(nil,"BACKGROUND"))
		card.edge=keep(line:CreateTexture(nil,"BORDER"))
		card.title=text("GameFontDisableSmall")
		card.word=text("GameFontDisableSmall","RIGHT")
		card.rule=keep(line:CreateTexture(nil,"ARTWORK"))
		card.ruleRight=keep(line:CreateTexture(nil,"ARTWORK"))
		card.vs=text("GameFontDisableSmall","CENTER")
		card.mmrMates=text("GameFontDisableSmall","RIGHT")
		card.mmrFoes=text("GameFontDisableSmall","RIGHT")
		card.mmrMatesLabel=text("GameFontDisableSmall","RIGHT")
		card.mmrFoesLabel=text("GameFontDisableSmall","RIGHT")
		card.names,card.icons,card.crosses={},{},{}
		for n=1,CARD_NAMES+1 do
			card.icons[n]=keep(line:CreateTexture(nil,"ARTWORK"))
			card.names[n]=text("GameFontHighlightSmall")
			card.crosses[n]=text("GameFontHighlightSmall")
		end
		line.roundCards[c]=card
	end

	line.teamCards={}
	for s=1,2 do
		local card={values={},labels={}}
		card.bg=keep(line:CreateTexture(nil,"BACKGROUND"))
		card.edge=keep(line:CreateTexture(nil,"BORDER"))
		card.title=text("GameFontDisableSmall")
		card.word=text("GameFontDisableSmall","RIGHT")
		for c=1,TEAM_CARD_PAIRS do
			card.values[c]=text("GameFontNormalLarge")
			card.labels[c]=text("GameFontDisableSmall")
		end
		card.mmrLabel=text("GameFontDisableSmall","RIGHT")
		card.mmrValue=text("GameFontNormalLarge","RIGHT")
		line.teamCards[s]=card
	end

	line.buildBg=keep(line:CreateTexture(nil,"BACKGROUND"))
	line.buildEdges={}
	for i=1,4 do
		line.buildEdges[i]=keep(line:CreateTexture(nil,"BORDER"))
	end
	line.buildKey=text("GameFontDisableSmall")
	line.buildLoadout=text("GameFontNormal")
	line.buildHero=text("GameFontDisableSmall")
	line.buildIcons={}
	for i=1,BUILD_ICONS do
		local icon=keep(CreateFrame("Frame",nil,line))
		icon.texture=icon:CreateTexture(nil,"ARTWORK")
		icon.texture:SetAllPoints(icon)
		icon:EnableMouse(true)
		icon:SetScript("OnEnter",function(self)
			if not GameTooltip or type(self.talentName)~="string"then
				return
			end
			pcall(function()
				GameTooltip:SetOwner(self,"ANCHOR_RIGHT")
				local r,g,b=A.color("text")
				GameTooltip:SetText(self.talentName,r,g,b,1,false)
				GameTooltip:Show()
			end)
			A.trace("build-hover",{id=self.recordId,n=self.index},"ui")
		end)
		icon:SetScript("OnLeave",function(self)
			A.hideOwnedTooltip(self)
		end)
		icon.index=i
		line.buildIcons[i]=icon
	end
	if type(A.pill)=="function"then
		line.buildCopy=keep(A.pill(line,"Copy talents",function(self)
			if type(A.copyTalents)=="function"then
				A.copyTalents(self.recordId)
			end
		end))
		line.buildLoad=keep(A.pill(line,"Load this build",function(self)
			if type(A.loadBuild)=="function"then
				A.loadBuild(self.recordId)
			end
		end))
		line.buildLoad:HookScript("OnEnter",function(self)
			A.hoverLine(self,self.hoverText)
		end)
		line.buildLoad:HookScript("OnLeave",function(self)
			A.hideOwnedTooltip(self)
		end)
	end

	line.yourBg=keep(line:CreateTexture(nil,"BACKGROUND"))
	line.yourEdges={}
	for i=1,4 do
		line.yourEdges[i]=keep(line:CreateTexture(nil,"BORDER"))
	end
	line.yourKey=text("GameFontDisableSmall")
	line.yourLabels,line.yourValues,line.yourPlaces={},{},{}
	for i=1,YOUR_LINE_CELLS do
		line.yourLabels[i]=text("GameFontDisableSmall")
		line.yourValues[i]=text("GameFontNormalLarge")
		line.yourPlaces[i]=text("GameFontDisableSmall")
	end

	line.lobbyIcon=keep(line:CreateTexture(nil,"ARTWORK"))
	line.legendMarks={
		keep(line:CreateTexture(nil,"ARTWORK")),keep(line:CreateTexture(nil,"ARTWORK")),
	}
	line.legendWords={text("GameFontDisableSmall"),text("GameFontDisableSmall")}
end

function A.matchHeadGame()
	return A.theme()~="flat"
end

local function detailText(h,skipPlace)
	local parts={}
	for _,part in ipairs(h.details or{})do
		if not(skipPlace and part.place)then
			parts[#parts+1]=A.colorEscape(part.tone or"dim")..part.text.."|r"
		end
	end
	return table.concat(parts," "..A.colorEscape("dimmer")..A.HEAD_DOT.."|r ")
end

local function ratingsText(h)
	if h.ratingFrom==nil or h.ratingTo==nil then
		return""
	end
	local function rating(text,fallback)
		local value=tonumber(text)
		if value==nil then
			return A.colorEscape(fallback)..text.."|r"
		end
		local _,_,reason=A.ratingColour(h.format,value)
		if reason=="unheard"then
			A.ratingAsk()
		end
		return A.tierRatingText(h.format,value,fallback)
	end
	return("%s %s%s|r %s"):format(rating(h.ratingFrom,"dim"),A.colorEscape("dimmer"),
		A.HEAD_ARROW,rating(h.ratingTo,"bright"))
end

local function paintChip(line,h,right,game,dy)
	if h.chipWhy=="unheard"then
		A.ratingAsk()
	end
	dy=dy or 0
	if h.mmr then
		local text="mmr "..h.mmr
		A.style(line.headMmr,"numberSmall","dim")
		line.headMmr:SetText(text)
		line.headMmr:ClearAllPoints()
		line.headMmr:SetPoint("RIGHT",line,"LEFT",right,dy)
		line.headMmr:Show()
		right=right-A.textRoom(line.headMmr,text)-A.metric("headGap")
	end
	local chip=h.chip
	if chip then
		local word=chip.word..(chip.reached and" reached"or"")
		if not game then
			word=word:upper()
		end
		local pad=A.metric("headChipPad")
		A.style(line.headChipText,"label","text")
		line.headChipText:SetTextColor(chip.r,chip.g,chip.b,1)
		line.headChipText:SetText(word)
		local room=A.textRoom(line.headChipText,word)
		local w,ht=room+pad*2,A.fontSize("label")+pad
		local x=right-w
		line.headChipText:ClearAllPoints()
		line.headChipText:SetPoint("LEFT",line,"LEFT",x+pad,dy)
		line.headChipText:SetWidth(0)
		line.headChipText:Show()
		local edges={{x,dy+ht/2,w,1},{x,dy-ht/2,w,1},{x,dy,1,ht},
			{x+w-1,dy,1,ht}}
		for i=1,4 do
			local edge,at=line.headChip[i],edges[i]
			edge:ClearAllPoints()
			edge:SetPoint("LEFT",line,"LEFT",at[1],at[2])
			edge:SetSize(at[3],at[4])
			edge:SetColorTexture(chip.r,chip.g,chip.b,1)
			edge:Show()
		end
		right=x-A.metric("headGap")
	end
	return right
end

local function paintPips(line,h,after)
	local pips=h.pips or{}
	local count=type(pips.n)=="number"and pips.n or 0
	local width,height,gap=A.metric("headPipWidth"),A.metric("headPipHeight"),A.metric("headPipGap")
	for i=1,#line.headPips do
		local pip=line.headPips[i]
		if i<=count then
			pip:ClearAllPoints()
			pip:SetPoint("LEFT",after,"RIGHT",A.metric("headGap")+(i-1)*(width+gap),0)
			pip:SetSize(width,height)
			local tone=pips[i]==true and"win"or pips[i]==false and"dimmer"or"dim"
			local r,g,b=A.color(tone)
			pip:SetColorTexture(r,g,b,1)
			pip:Show()
		end
	end
end

function A.matchBannerFit(verdict,ratings,delta,limit)
	local pad,gap=A.metric("bannerPad"),A.metric("headGap")
	local room=limit-pad
	local function after(width)
		return width>0 and gap+width or 0
	end
	local tail=after(delta)
	if verdict+after(ratings)+tail<=room then
		return{verdict=verdict,ratings=ratings>0,fits=true}
	end
	local cut=math.max(1,math.min(verdict,room-tail))
	return{verdict=cut,ratings=false,fits=cut==verdict}
end

local function availableWidth(h)
	return type(h.available)=="number"and h.available or A.detailWindowBody()
end

local function paintBanner(line,h)
	line.headCrest:Hide()
	line.bannerBg:SetAllPoints(line)
	line.bannerBg:SetColorTexture(A.color("panelDeep"))
	line.bannerBg:Show()
	local width=availableWidth(h)
	local pad,gap=A.metric("bannerPad"),A.metric("headGap")
	local lead=A.matchBannerLead()
	local dy=A.matchBannerHeight()/2-pad-lead/2
	local limit=paintChip(line,h,width-pad,true,dy)

	local verdict,tone,place=h.result,h.resultTone or"text",h.place or""
	if verdict==nil then
		verdict,tone,place=place,"bright",""
	end
	A.style(line.bannerVerdict,VERDICT_ROLE,tone)
	line.bannerVerdict:SetJustifyH("LEFT")
	line.bannerVerdict:SetText(verdict)
	local ratings=ratingsText(h)
	A.style(line.headRatings,"numberSmall","dim")
	A.style(line.headDelta,"number",h.deltaTone or"dim")
	local fit=A.matchBannerFit(math.ceil(A.textRoom(line.bannerVerdict,verdict)),
		math.ceil(A.textRoom(line.headRatings,ratings)),math.ceil(A.textRoom(line.headDelta,h.delta or"")),
		limit)
	A.trace("match-banner",{verdict=h.result or"none",room=limit-pad,
		fit=fit.fits and(fit.ratings==(ratings~="")and"whole"or"no-ratings")or"cut"},"ui")
	line.bannerVerdict:ClearAllPoints()
	line.bannerVerdict:SetPoint("LEFT",line,"TOPLEFT",pad,-(pad+lead/2))
	line.bannerVerdict:SetWidth(fit.fits and 0 or fit.verdict)
	line.bannerVerdict:Show()
	local after=line.bannerVerdict
	if fit.ratings then
		line.headRatings:SetText(ratings)
		line.headRatings:ClearAllPoints()
		line.headRatings:SetPoint("LEFT",after,"RIGHT",gap,0)
		line.headRatings:Show()
		after=line.headRatings
	end
	if h.delta~=nil then
		line.headDelta:SetText(h.delta)
		line.headDelta:ClearAllPoints()
		line.headDelta:SetPoint("LEFT",after,"RIGHT",gap,0)
		line.headDelta:Show()
	end

	A.style(line.bannerNote,"note","dim")
	line.bannerNote:SetText(detailText(h,true))
	line.bannerNote:ClearAllPoints()
	if place~=""then
		A.style(line.bannerPlace,"heading","bright")
		line.bannerPlace:SetText(place)
		line.bannerPlace:ClearAllPoints()
		line.bannerPlace:SetPoint("BOTTOMLEFT",line,"BOTTOMLEFT",pad,pad)
		local placeRoom=width-pad*2
		line.bannerPlace:SetWidth(math.ceil(A.textRoom(line.bannerPlace,place))>(A.unitFigure(placeRoom)or placeRoom)
			and math.max(1,placeRoom)or 0)
		line.bannerPlace:Show()
		line.bannerNote:SetPoint("BOTTOMLEFT",line.bannerPlace,"BOTTOMRIGHT",gap,0)
	else
		line.bannerNote:SetPoint("BOTTOMLEFT",line,"BOTTOMLEFT",pad,pad)
	end
	line.bannerNote:SetPoint("RIGHT",line,"RIGHT",-pad,0)
	line.bannerNote:Show()
end

local function paintHeading(line,h,paintCrest,game)
	if game then
		paintBanner(line,h)
		return
	end

	line.headResult:Show()
	paintCrest(line,h.faction)
	A.style(line.headResult,"headingLarge",h.resultTone or"text")
	line.headResult:SetText(h.result or"")
	paintPips(line,h,line.headResult)

	line.headDelta:ClearAllPoints()
	line.headDelta:SetPoint("RIGHT",line,"RIGHT",-A.metric("rowCellGap"),0)
	A.style(line.headDelta,"number",h.deltaTone or"dim")
	line.headDelta:SetText(h.delta or"")
	line.headDelta:Show()
	line.headRatings:ClearAllPoints()
	line.headRatings:SetPoint("RIGHT",line.headDelta,"LEFT",-A.metric("headGap"),0)
	A.style(line.headRatings,"numberSmall","dim")
	line.headRatings:SetText(ratingsText(h))
	line.headRatings:Show()
end

local function paintHeadline(line,h)
	local width=availableWidth(h)
	local left=paintChip(line,h,width-A.metric("rowCellGap"),false)
	A.style(line.headDetails,"bodyText","dim")
	line.headDetails:SetText(detailText(h,false))
	line.headDetails:ClearAllPoints()
	line.headDetails:SetPoint("LEFT",line,"LEFT",0,0)
	line.headDetails:SetWidth(math.max(1,left))
	line.headDetails:SetJustifyH("LEFT")
	line.headDetails:Show()
end

local function ladderX(ladder,rating,width)
	local share=(rating-ladder.low)/(ladder.high-ladder.low)
	if share<0 then
		share=0
	elseif share>1 then
		share=1
	end
	return math.floor(share*width+0.5)
end

local function paintLadder(line,h)
	local ladder=h.ladder
	local width=availableWidth(h)
	local pad,bar,gap=A.metric("ladderPad"),A.metric("ladderBar"),A.metric("ladderGap")
	local markInset=(A.metric("ladderMark")-bar)/2
	local top=-(pad+markInset)
	for i=1,#line.ladderBars do
		local held=ladder.bars[i]
		if held then
			local x=ladderX(ladder,held.entry,width)
			local right=ladderX(ladder,held.upper,width)
			local w=math.max(1,right-x-gap)
			local dr,dg,db=A.color("dim")
			local r,g,b=held.r or dr,held.g or dg,held.b or db
			local barTex=line.ladderBars[i]
			barTex:ClearAllPoints()
			barTex:SetPoint("TOPLEFT",line,"TOPLEFT",x,top)
			barTex:SetSize(w,bar)
			barTex:SetColorTexture(r,g,b,held.here and 1 or 0.35)
			barTex:Show()
			local word,entry=line.ladderWords[i],line.ladderEntries[i]
			A.style(word,"label","text")
			word:SetTextColor(r,g,b,1)
			word:SetAlpha(held.here and 1 or 0.7)
			word:SetText(held.word or"")
			word:ClearAllPoints()
			word:SetPoint("TOPLEFT",line,"TOPLEFT",x,top-bar-gap-markInset)
			word:Show()
			A.style(entry,"numberSmall","dim")
			entry:SetText(tostring(held.entry))
			entry:ClearAllPoints()
			entry:SetPoint("LEFT",word,"RIGHT",A.metric("headCrestGap"),0)
			entry:Show()
		end
	end
	local marks={{ladder.from,"dim"},{ladder.to,"bright"}}
	for i=1,2 do
		local mark=line.ladderMarks[i]
		mark:ClearAllPoints()
		mark:SetPoint("TOPLEFT",line,"TOPLEFT",ladderX(ladder,marks[i][1],width)-1,-pad)
		mark:SetSize(2,A.metric("ladderMark"))
		mark:SetColorTexture(A.color(marks[i][2]))
		mark:Show()
	end
end

local HEALER_CROSS="+"

local function paintCardName(card,n,x,y,width,label,classToken,spec,faint,healer)
	local cross=card.crosses[n]
	local crossRoom=0
	if healer then
		A.style(cross,"label",faint and"loss"or"win")
		cross:SetText(HEALER_CROSS)
		crossRoom=math.ceil(A.textRoom(cross,HEALER_CROSS))+A.metric("rowMarkGap")
	else
		cross:SetText("")
		cross:Hide()
	end
	local size=A.metric("compSwatch")
	local icon,name=card.icons[n],card.names[n]
	local found=type(A.specIcon)=="function"and A.specIcon(classToken,spec)or nil
	icon:ClearAllPoints()
	icon:SetPoint("TOPLEFT",card.bg,"TOPLEFT",x,y-(A.fontSize("note")-size)/2)
	icon:SetSize(size,size)
	if found~=nil then
		icon:SetVertexColor(1,1,1,1)
		icon:SetTexture(found)
	else
		icon:SetColorTexture(A.classColor(classToken))
	end
	icon:SetAlpha(faint and 0.6 or 1)
	icon:Show()
	A.style(name,"note","text")
	name:SetTextColor(A.classColor(classToken))
	name:SetAlpha(faint and 0.6 or 1)
	name:SetText(label)
	name:ClearAllPoints()
	local nameX=x+size+A.metric("headCrestGap")
	local room=math.max(1,width-size-A.metric("headCrestGap")-crossRoom)
	name:SetPoint("TOPLEFT",card.bg,"TOPLEFT",nameX,y)
	name:SetWidth(room)
	name:Show()
	if healer then
		local drawn=math.min(math.ceil(A.textRoom(name,label)),room)
		cross:ClearAllPoints()
		cross:SetPoint("TOPLEFT",card.bg,"TOPLEFT",nameX+drawn+A.metric("rowMarkGap"),y)
		cross:Show()
	end
	return healer==true
end

local function shortName(cell)
	local name=tostring(cell.name or"-")
	return name:match("^([^%-]+)")or name
end

local function placeCardTarget(line,h,held,x,width,height)
	local function place(target)
		target:ClearAllPoints()
		target:SetPoint("TOPLEFT",line,"TOPLEFT",x,0)
		target:SetSize(width,height)
		target:Show()
	end
	local button=type(line.lobbyRoundButtons)=="table"and line.lobbyRoundButtons[held.n]or nil
	if button and(held.state=="open"or held.state=="typed")then
		button.recordId=h.id
		button.round=held.n
		button.state=held.state
		button.meterWords=held.meter
		place(button)
		return
	end
	local hover=type(line.lobbyRoundHovers)=="table"and line.lobbyRoundHovers[held.n]or nil
	if hover and type(held.meter)=="table"then
		hover.words=held.meter
		place(hover)
	end
end

local function paintCardGround(line,card,x,width,height,tone)
	card.bg:ClearAllPoints()
	card.bg:SetPoint("TOPLEFT",line,"TOPLEFT",x,0)
	card.bg:SetSize(width,height)
	card.bg:SetColorTexture(A.color("panelDeep"))
	card.bg:Show()
	card.edge:ClearAllPoints()
	card.edge:SetPoint("TOPLEFT",card.bg,"TOPLEFT",0,0)
	card.edge:SetSize(width,A.metric("roundCardEdge"))
	card.edge:SetColorTexture(A.color(tone))
	card.edge:Show()
end

local function paintCards(line,h)
	local cards=h.cards or{}
	local width=availableWidth(h)
	local gap,pad=A.metric("roundCardGap"),A.metric("roundCardPad")
	local count=math.min(#cards,#line.roundCards)
	local cardWidth=count>0 and math.floor((width-gap*(count-1))/count)or 0
	local step=A.fontSize("note")+A.metric("roundCardLine")
	local height=A.roundCardsHeight(cards)
	for c=1,count do
		local card,held=line.roundCards[c],cards[c]
		local x=(c-1)*(cardWidth+gap)
		paintCardGround(line,card,x,cardWidth,height,held.tone)
		local y=-(A.metric("roundCardEdge")+pad)
		A.style(card.title,"label","dim")
		card.title:SetText(("R%d"):format(held.n))
		card.title:ClearAllPoints()
		card.title:SetPoint("TOPLEFT",card.bg,"TOPLEFT",pad,y)
		card.title:Show()
		A.style(card.word,"label",held.tone)
		card.word:SetText(held.word)
		card.word:ClearAllPoints()
		card.word:SetPoint("TOPRIGHT",card.bg,"TOPRIGHT",-pad,y)
		card.word:Show()
		y=y-A.fontSize("label")-A.metric("roundCardLine")
		local inner=cardWidth-pad*2
		local function figure(fs,label,value,at,centered)
			if type(value)~="number"then
				fs:SetText("")
				fs:Hide()
				label:SetText("")
				label:Hide()
				return 0
			end
			local text=("%d"):format(value)
			A.style(fs,"rowClock","text")
			fs:SetText(text)
			fs:ClearAllPoints()
			fs:SetPoint(centered and"RIGHT"or"TOPRIGHT",card.bg,"TOPRIGHT",-pad,at)
			fs:Show()
			A.style(label,"note","dim")
			label:SetText("avg MMR")
			label:ClearAllPoints()
			label:SetPoint("BOTTOMRIGHT",fs,"BOTTOMLEFT",-A.metric("rowMarkGap"),0)
			label:Show()
			return math.ceil(A.textRoom(fs,text))+math.ceil(A.textRoom(label,"avg MMR"))
				+A.metric("rowMarkGap")*2
		end
		local n=1
		local ownRoom=figure(card.mmrMates,card.mmrMatesLabel,held.mmrYours,y)
		paintCardName(card,n,pad,y,inner-ownRoom,"You",held.classToken,held.spec,false,
			held.ownHealer==true)
		for _,cell in ipairs(held.mates)do
			n,y=n+1,y-step
			paintCardName(card,n,pad,y,inner,shortName(cell),cell.classToken,cell.spec,false,
				A.healerCell(cell))
		end
		y=y-step
		local band=A.roundCardVsBand()
		local sides=#held.mates+#held.foes>0
		local markGap=A.metric("rowMarkGap")
		A.style(card.vs,"note","dim")
		card.vs:SetText("VS")
		local word=math.ceil(A.textRoom(card.vs,"VS"))
		local middle=y-band/2
		local foeRoom=figure(card.mmrFoes,card.mmrFoesLabel,#held.foes>0 and held.mmrTheirs or nil,middle,
			true)
		local span=inner
		local half=math.max(1,math.floor((inner-word)/2)-markGap)
		local rightWidth=math.max(1,half-foeRoom)
		if foeRoom>0 and half-foeRoom<1 then
			span=math.max(word,inner-foeRoom)
			half=math.max(1,math.floor((span-word)/2)-markGap)
			rightWidth=half
		end
		card.vs:ClearAllPoints()
		card.vs:SetPoint("CENTER",card.bg,"TOPLEFT",pad+span/2,middle)
		card.vs:SetShown(sides)
		for r,rule in ipairs({card.rule,card.ruleRight})do
			rule:ClearAllPoints()
			rule:SetPoint("TOPLEFT",card.bg,"TOPLEFT",r==1 and pad or(pad+span-half),middle)
			rule:SetSize(r==1 and half or rightWidth,1)
			rule:SetColorTexture(A.color("hairline"))
			rule:SetShown(sides)
		end
		y=y-band
		for _,cell in ipairs(held.foes)do
			n=n+1
			paintCardName(card,n,pad,y,inner,shortName(cell),cell.classToken,cell.spec,true,
				A.healerCell(cell))
			y=y-step
		end
		placeCardTarget(line,h,held,x,cardWidth,height)
	end
end

local function paintInset(line,bg,edges,width,height)
	bg:ClearAllPoints()
	bg:SetPoint("TOPLEFT",line,"TOPLEFT",0,0)
	bg:SetSize(width,height)
	bg:SetColorTexture(A.color("inset"))
	bg:Show()
	for i=1,4 do
		edges[i]:ClearAllPoints()
		edges[i]:SetColorTexture(A.color("insetEdge"))
		edges[i]:Show()
	end
	edges[1]:SetPoint("TOPLEFT",bg,"TOPLEFT",0,0)
	edges[1]:SetSize(width,1)
	edges[2]:SetPoint("BOTTOMLEFT",bg,"BOTTOMLEFT",0,0)
	edges[2]:SetSize(width,1)
	edges[3]:SetPoint("TOPLEFT",bg,"TOPLEFT",0,0)
	edges[3]:SetSize(1,height)
	edges[4]:SetPoint("TOPRIGHT",bg,"TOPRIGHT",0,0)
	edges[4]:SetSize(1,height)
end

local function paintBuild(line,h)
	if not line.buildKey then
		return
	end
	local width,height=availableWidth(h),A.buildCardHeight()
	local pad,gap=A.metric("roundCardPad"),A.metric("chipGap")
	local size=A.metric("buildIcon")
	paintInset(line,line.buildBg,line.buildEdges,width,height)

	local first=A.fontSize("label")
	local firstMiddle=-(pad+first/2)
	local secondMiddle=-(pad+first+A.metric("roundCardLine")
		+math.max(size,A.fontSize("heading"),A.metric("controlHeight"))/2)

	line.buildKey:ClearAllPoints()
	line.buildKey:SetPoint("LEFT",line.buildBg,"TOPLEFT",pad,firstMiddle)
	A.style(line.buildKey,"label","label")
	line.buildKey:SetText("BUILD")
	line.buildKey:Show()
	local pillRoom=0
	if line.buildCopy then
		line.buildCopy.recordId=h.id
		line.buildCopy:ClearAllPoints()
		line.buildCopy:SetPoint("RIGHT",line.buildBg,"TOPRIGHT",-pad,secondMiddle)
		line.buildCopy:Show()
		pillRoom=math.ceil(line.buildCopy:GetWidth())+gap
	end
	if line.buildLoad then
		line.buildLoad.recordId=h.id
		line.buildLoad.hoverText=type(h.spec)=="string"
			and("Saves this build as a loadout and switches to it. For %s."):format(h.spec)
			or"Saves this build as a loadout and switches to it."
		line.buildLoad:ClearAllPoints()
		line.buildLoad:SetPoint("RIGHT",line.buildCopy,"LEFT",-gap,0)
		line.buildLoad:Show()
		pillRoom=pillRoom+math.ceil(line.buildLoad:GetWidth())+gap
	end

	local talents=type(h.pvp)=="table"and h.pvp or{}
	local drawn=0
	for i=1,#line.buildIcons do
		local talent=talents[i]
		if talent and talent.icon~=nil then
			drawn=drawn+1
		end
	end
	local hero=type(h.hero)=="string"and h.hero or nil
	A.style(line.buildHero,"bodyText","dim")
	local heroRoom=hero and math.ceil(A.textRoom(line.buildHero,hero))+gap or 0
	local loadout=h.loadout or""
	A.style(line.buildLoadout,"heading",h.unnamed and"dim"or"text")
	local room=width-pad*2-heroRoom-drawn*(size+gap)-pillRoom
	line.buildLoadout:ClearAllPoints()
	line.buildLoadout:SetPoint("LEFT",line.buildBg,"TOPLEFT",pad,secondMiddle)
	local nameCut=math.ceil(A.textRoom(line.buildLoadout,loadout))>(A.unitFigure(room)or room)
	line.buildLoadout:SetWidth(nameCut and math.max(1,room)or 0)
	line.buildLoadout:SetText(loadout)
	line.buildLoadout:Show()
	local after=line.buildLoadout
	if hero then
		line.buildHero:ClearAllPoints()
		line.buildHero:SetPoint("LEFT",line.buildLoadout,"RIGHT",gap,0)
		line.buildHero:SetText(hero)
		line.buildHero:Show()
		after=line.buildHero
	else
		line.buildHero:SetText("")
		line.buildHero:Hide()
	end
	for i=1,#line.buildIcons do
		local icon=line.buildIcons[i]
		local talent=talents[i]
		icon.recordId=h.id
		icon.talentName=talent and talent.name or nil
		if talent and talent.icon~=nil then
			icon:ClearAllPoints()
			icon:SetPoint("LEFT",after,"RIGHT",gap,0)
			icon:SetSize(size,size)
			icon.texture:SetTexture(talent.icon)
			icon:Show()
			after=icon
		else
			icon:Hide()
		end
	end
	A.trace("matchbuild",{id=h.id,pvpTalents=type(h.pvp)=="table"and#h.pvp or 0,icons=drawn,
		copyShown=line.buildCopy~=nil,loadShown=line.buildLoad~=nil,pillRoom=pillRoom,
		nameCut=nameCut and 1 or 0},"ui")
end

local function paintYourLine(line,h)
	local width,height=availableWidth(h),A.yourLineHeight()
	local pad,gap=A.metric("roundCardPad"),A.metric("headGap")
	paintInset(line,line.yourBg,line.yourEdges,width,height)

	A.style(line.yourKey,"label","label")
	line.yourKey:SetText("YOUR LINE")
	line.yourKey:ClearAllPoints()
	line.yourKey:SetPoint("TOPLEFT",line.yourBg,"TOPLEFT",pad,-pad)
	line.yourKey:SetWidth(0)
	line.yourKey:Show()
	local lead=pad+math.ceil(A.textRoom(line.yourKey,"YOUR LINE"))+gap
	local cells=type(h.cells)=="table"and h.cells or{}
	local count=math.min(#cells,#line.yourLabels)
	local cellWidth=count>0 and math.floor((width-lead-pad)/count)or 0
	local figureTop=-(pad+A.fontSize("label")+A.metric("roundCardLine"))
	for i=1,count do
		local cell,x=cells[i],lead+(i-1)*cellWidth
		local label,value,place=line.yourLabels[i],line.yourValues[i],line.yourPlaces[i]
		A.style(label,"label","dim")
		label:SetText(cell.label)
		label:ClearAllPoints()
		label:SetPoint("TOPLEFT",line.yourBg,"TOPLEFT",x,-pad)
		label:SetWidth(math.max(1,cellWidth-gap))
		label:Show()
		A.style(value,"number",cell.value~=nil and"text"or"dim")
		value:SetText(cell.value or"-")
		value:ClearAllPoints()
		value:SetPoint("TOPLEFT",line.yourBg,"TOPLEFT",x,figureTop)
		value:Show()
		if cell.place~=nil then
			A.style(place,"note","dim")
			place:SetText(cell.place)
			place:ClearAllPoints()
			place:SetPoint("BOTTOMLEFT",value,"BOTTOMRIGHT",A.metric("rowMarkGap"),0)
			place:Show()
		else
			place:SetText("")
			place:Hide()
		end
	end
end

local function paintTally(line,h)
	local cells=type(h.cells)=="table"and h.cells or{}
	local width=availableWidth(h)
	local gap,pad=A.metric("roundCardGap"),A.metric("roundCardPad")
	local count=math.min(#cells,#line.roundCards)
	local cardWidth=count>0 and math.floor((width-gap*(count-1))/count)or 0
	local height=A.outingCellsHeight()
	for c=1,count do
		local card,held=line.roundCards[c],cells[c]
		paintCardGround(line,card,(c-1)*(cardWidth+gap),cardWidth,height,held.tone or"dim")
		local y=-(A.metric("roundCardEdge")+pad)
		A.style(card.title,"label","dim")
		card.title:SetText(held.label)
		card.title:ClearAllPoints()
		card.title:SetPoint("TOPLEFT",card.bg,"TOPLEFT",pad,y)
		card.title:Show()
		local value=card.names[1]
		A.style(value,"number",held.tone or"dim")
		value:SetText(held.value or"-")
		value:ClearAllPoints()
		value:SetPoint("TOPLEFT",card.bg,"TOPLEFT",pad,y-A.fontSize("label")-A.metric("roundCardLine"))
		value:SetWidth(math.max(1,cardWidth-pad*2))
		value:Show()
	end
end

function A.outingCellsHeight()
	return A.metric("roundCardPad")*2+A.metric("roundCardEdge")+A.fontSize("label")
		+A.metric("roundCardLine")+A.fontSize("number")
end

function A.paintMatchHead(line,h,paintCrest)
	local game=A.matchHeadGame()
	if h.kind=="heading"then
		paintHeading(line,h,paintCrest,game)
	elseif h.kind=="headline"then
		paintHeadline(line,h)
	elseif h.kind=="ladder"and type(h.ladder)=="table"then
		paintLadder(line,h)
	elseif h.kind=="cards"then
		paintCards(line,h)
	elseif h.kind=="tally"then
		paintTally(line,h)
	elseif h.kind=="build"then
		paintBuild(line,h)
	elseif h.kind=="yourLine"then
		paintYourLine(line,h)
	end
end

function A.paintNameIcon(line,cell,x,width,classToken,spec)
	local size=A.metric("compSwatch")
	local icon=type(A.specIcon)=="function"and A.specIcon(classToken,spec)or nil
	line.lobbyIcon:ClearAllPoints()
	line.lobbyIcon:SetPoint("LEFT",line,"LEFT",x,0)
	line.lobbyIcon:SetSize(size,size)
	if icon~=nil then
		line.lobbyIcon:SetVertexColor(1,1,1,1)
		line.lobbyIcon:SetTexture(icon)
	else
		line.lobbyIcon:SetColorTexture(A.classColor(classToken))
	end
	line.lobbyIcon:Show()
	local shift=size+A.metric("headCrestGap")
	cell:ClearAllPoints()
	cell:SetPoint("LEFT",line,"LEFT",x+shift,0)
	cell:SetWidth(math.max(1,width-shift))
	return icon~=nil
end

function A.paintTeamCards(line,h)
	local totals=type(h.totals)=="table"and h.totals or{}
	local columns=type(totals.columns)=="table"and totals.columns or{}
	local words=type(h.words)=="table"and h.words or{}
	local width=availableWidth(h)
	local gap,pad=A.metric("roundCardGap"),A.metric("roundCardPad")
	local cardWidth=math.max(1,math.floor((width-gap)/2))
	local height=A.objectiveCardsHeight()
	local sides={{"yours","win",totals.yours},{"theirs","loss",totals.theirs}}
	for s=1,2 do
		local card=line.teamCards[s]
		local side,tone=sides[s][1],sides[s][2]
		local values=type(sides[s][3])=="table"and sides[s][3]or{}
		paintCardGround(line,card,(s-1)*(cardWidth+gap),cardWidth,height,tone)

		local y=-(A.metric("roundCardEdge")+pad)
		A.style(card.title,"label","dim")
		card.title:SetText(A.sideWord(side):upper())
		card.title:ClearAllPoints()
		card.title:SetPoint("TOPLEFT",card.bg,"TOPLEFT",pad,y)
		card.title:Show()
		local word=words[side]
		if word~=nil then
			A.style(card.word,"label",word=="DRAW"and"dim"or tone)
			card.word:SetText(word)
			card.word:ClearAllPoints()
			card.word:SetPoint("TOPRIGHT",card.bg,"TOPRIGHT",-pad,y)
			card.word:Show()
		else
			card.word:SetText("")
			card.word:Hide()
		end

		y=y-A.fontSize("label")-A.metric("roundCardLine")
		local x=pad
		for c=1,#card.values do
			local value,label,column=card.values[c],card.labels[c],columns[c]
			if type(column)=="table"then
				local figure=values[c]
				local text=figure~=nil and tostring(figure)or"-"
				A.style(value,"number",figure~=nil and"text"or"dim")
				value:SetText(text)
				value:ClearAllPoints()
				value:SetPoint("TOPLEFT",card.bg,"TOPLEFT",x,y)
				value:Show()
				x=x+A.textRoom(value,text)+A.metric("rowMarkGap")
				A.style(label,"label","dim")
				label:SetText(column.short)
				label:ClearAllPoints()
				label:SetPoint("BOTTOMLEFT",value,"BOTTOMRIGHT",A.metric("rowMarkGap"),0)
				label:Show()
				x=x+A.textRoom(label,column.short)+A.metric("headGap")*2
			else
				value:SetText("")
				label:SetText("")
				value:Hide()
				label:Hide()
			end
		end

		local mmr=type(h.mmr)=="table"and h.mmr[side]or nil
		if card.mmrValue and type(mmr)=="number"then
			local text=("%d"):format(mmr)
			A.style(card.mmrValue,"number","text")
			card.mmrValue:SetText(text)
			card.mmrValue:ClearAllPoints()
			card.mmrValue:SetPoint("TOPRIGHT",card.bg,"TOPRIGHT",-pad,y)
			card.mmrValue:Show()
			A.style(card.mmrLabel,"label","dim")
			card.mmrLabel:SetText("MMR")
			card.mmrLabel:ClearAllPoints()
			card.mmrLabel:SetPoint("BOTTOMRIGHT",card.mmrValue,"BOTTOMLEFT",-A.metric("rowMarkGap"),0)
			card.mmrLabel:Show()
		elseif card.mmrValue then
			card.mmrValue:SetText("")
			card.mmrLabel:SetText("")
			card.mmrValue:Hide()
			card.mmrLabel:Hide()
		end
	end
end

local TEAM_LEGEND={"your team","their team"}

function A.paintTeamLegend(line)
	local size=A.metric("roundCellMark")
	local air=A.metric("footAir")
	local top=-(air+math.floor((A.metric("rowHeight")-size)/2))
	local x=0
	for i=1,2 do
		local mark=line.legendMarks[i]
		mark:ClearAllPoints()
		mark:SetPoint("TOPLEFT",line,"TOPLEFT",x,top)
		mark:SetSize(size,size)
		mark:SetColorTexture(A.color(i==1 and"win"or"loss"))
		mark:Show()
		local word=line.legendWords[i]
		A.style(word,"note","dim")
		word:SetText(TEAM_LEGEND[i])
		word:ClearAllPoints()
		word:SetPoint("LEFT",line,"LEFT",x+size+A.metric("headCrestGap"),-air/2)
		word:Show()
		x=x+size+A.metric("headCrestGap")+A.textRoom(word,TEAM_LEGEND[i])+A.metric("headGap")*2
	end
	return x
end

local STEP_SIZE=22
local STEP_ARROWS={
	{direction="prev",label="Previous match",glyph="<"},
	{direction="next",label="Next match",glyph=">"},
}

function A.matchStepSize()
	return STEP_SIZE
end

function A.matchStepPlaces()
	local inset=A.metric("titleInset")
	local gap=math.max(0,math.floor((inset-STEP_SIZE*2)/3))
	return gap,gap*2+STEP_SIZE,gap
end

function A.buildMatchStep(frame,step)
	frame.stepArrows={}
	local size=A.matchStepSize()
	for _,arrow in ipairs(STEP_ARROWS)do
		local direction=arrow.direction
		local button=A.pill(frame,arrow.glyph,function()
			step(frame,direction)
		end,size)
		button:SetSize(size,size)
		button.direction=direction
		button.stepLabel=arrow.label
		button:HookScript("OnEnter",function(self)
			A.hoverLine(self,self.stepLabel)
		end)
		button:HookScript("OnLeave",function(self)
			A.hideOwnedTooltip(self)
		end)
		frame.stepArrows[direction]=button
	end
	A.seatMatchSteps(frame)
end

function A.seatMatchSteps(frame)
	local arrows=type(frame)=="table"and frame.stepArrows or nil
	if arrows==nil then
		return false
	end
	local firstX,secondX=A.matchStepPlaces()
	local size=A.matchStepSize()
	local _,_,middle=A.titleBarSpan()
	local top=math.min(0,-math.floor(middle-size/2))
	for i,direction in ipairs({"prev","next"})do
		local button=arrows[direction]
		if button then
			button:ClearAllPoints()
			button:SetPoint("TOPLEFT",frame,"TOPLEFT",i==1 and firstX or secondX,top)
		end
	end
	return true
end

function A.paintMatchStep(frame,before,after)
	local arrows=type(frame)=="table"and frame.stepArrows or nil
	if arrows==nil then
		return false
	end
	pcall(arrows.prev.SetEnabled,arrows.prev,before~=nil)
	pcall(arrows.next.SetEnabled,arrows.next,after~=nil)
	return true
end

function A.rosterGuids(rows)
	local set={}
	local function take(c)
		if type(c)=="table"and type(c.guid)=="string"then
			set[c.guid]=true
		end
	end
	for _,row in ipairs(type(rows)=="table"and rows or{})do
		local h=type(row)=="table"and row.head or nil
		take(type(row)=="table"and row.cells or nil)
		if type(h)=="table"and(h.kind=="lobbyRow"or h.kind=="lobbyYou")then
			local joined=type(h.row)=="table"and h.row.joined or nil
			take(type(joined)=="table"and joined.cells or nil)
		end
	end
	return set
end

function A.traceMatchHead(id,rows,height,box)
	if type(A.trace)~="function"then
		return false
	end
	local heading,headline,ladder,cards=nil,nil,nil,false
	local team,teamCards=false,false
	local cut=0
	local counts={spec=0,class=0,square=0,blank=0,rows=0,bots=0}
	local lineCells,honor,stripes,healers=nil,0,0,0
	local function player(c)
		if type(c)~="table"then
			return
		end
		if type(c.honorLevel)=="number"then
			honor=honor+1
		end
		if A.rosterStripeMark(c.guid,c.self)~=nil then
			stripes=stripes+1
		end
	end
	for _,row in ipairs(type(rows)=="table"and rows or{})do
		local h=type(row)=="table"and row.head or nil
		local c=type(row)=="table"and row.cells or nil
		player(c)
		if type(h)=="table"and(h.kind=="lobbyRow"or h.kind=="lobbyYou")then
			local joined=type(h.row)=="table"and h.row.joined or nil
			player(type(joined)=="table"and joined.cells or nil)
		elseif type(h)=="table"and h.kind=="yourLine"then
			lineCells=h.drawn or 0
		end
		if type(c)=="table"and c.look=="team"then
			team=true
			if c.bot then
				counts.bots=counts.bots+1
			else
				local kind=A.rosterIcon(c.classToken,c.spec)
				counts[kind]=(counts[kind]or 0)+1
			end
			counts.rows=counts.rows+1
		end
		if type(h)=="table"and h.look=="team"then
			team=true
			teamCards=teamCards or h.kind=="objectives"
		end
		if type(h)=="table"then
			if h.kind=="heading"then
				heading=h
			elseif h.kind=="headline"then
				headline=h
			elseif h.kind=="ladder"then
				ladder=h.ladder
			elseif h.kind=="cards"then
				cards=true
				for _,card in ipairs(type(h.cards)=="table"and h.cards or{})do
					cut=cut+(type(card)=="table"and tonumber(card.cut)or 0)
					healers=healers+A.cardHealers(card)
				end
			end
		end
	end
	local drawn=nil
	if type(box)=="table"and type(box.ForEachFrame)=="function"then
		drawn=0
		pcall(box.ForEachFrame,box,function(element)
			local stripe=type(element)=="table"and element.rateStripe or nil
			if stripe~=nil and stripe:IsShown()then
				drawn=drawn+1
			end
		end)
	end
	local parts=heading or headline or{}
	local chip=parts.chip
	local drewCards=nil
	if team then
		drewCards=teamCards
	end
	A.trace("match-head",{
		id=id,
		verdict=parts.result or"none",
		chip=chip and chip.word or parts.chipWhy or"no-head",
		reached=chip~=nil and chip.reached==true,
		markFrom=ladder and ladder.from or"none",
		markTo=ladder and ladder.to or"none",
		cards=cards,
		dropped=cut>0 and cut or nil,
		height=height,
		teamCards=drewCards,
		rows=team and counts.rows or nil,
		icons=team and counts.spec or nil,
		classIcons=team and(counts.class+counts.square)or nil,
		blankIcons=team and counts.blank or nil,
		bots=team and counts.bots or nil,
		lineCells=lineCells,
		honor=honor,
		stripes=drawn,
		stripesStored=stripes,
		healers=healers,
	},"ui")
	return true
end
