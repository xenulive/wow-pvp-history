-- WowPvpHistory 0.70.27
-- Author:  Xenu-Sentinels
-- Project: wow-pvp-history
--          https://github.com/xenulive/wow-pvp-history
-- License: MIT, see LICENSE
local _,A=...

local QUESTIONS={
	{key="beats",title="What beats me",columns="askBeats",opens="MET IN",
		group="THE SPECS YOU MEET",unit={"round against you","rounds against you"},
		floor="specs",noun={"spec","specs"}},
	{key="worth",title="Best teammate",columns="askWorth",opens="MET IN",
		group="THE SPECS BESIDE YOU",unit={"round alongside you","rounds alongside you"},
		floor="specs",noun={"spec","specs"}},
	{key="comp",title="Worst comp",table="comp",opens="MET IN",
		group="THE COMPS YOU MEET",unit={"round against you","rounds against you"},
		floor="comps",noun={"comp","comps"}},
	{key="where",title="Where I lose",columns="askWhere",opens="PLAYED ON",
		group="WHERE YOU PLAY",unit={"decided","decided"},
		floor="maps",noun={"map","maps"}},
}

function A.askQuestions()
	local out={}
	for i=1,#QUESTIONS do
		local held=QUESTIONS[i]
		out[#out+1]={key=held.key,title=held.title,columns=held.columns,
			group=held.group,unit=held.unit,opens=held.opens,table=held.table,
			floor=held.floor,noun=held.noun}
	end
	return out
end

function A.askQuestion(key)
	if type(key)~="string"then
		return nil
	end
	for i=1,#QUESTIONS do
		if QUESTIONS[i].key==key then
			return QUESTIONS[i]
		end
	end
	return nil
end

local DUEL_CARDS={beats=true,where=true}
local BATTLEGROUND_CARDS={beats=true,worth=true,where=true}
local CARD_SETS={
	world={},
	["shuffle-unrated"]={where=true},
	duel=DUEL_CARDS,
	bg=BATTLEGROUND_CARDS,
	rbg=BATTLEGROUND_CARDS,
	blitz=BATTLEGROUND_CARDS,
	["blitz-unrated"]=BATTLEGROUND_CARDS,
}

function A.askOffered(key,format)
	if A.askQuestion(key)==nil then
		return false
	end
	local set=type(format)=="string"and CARD_SETS[format]or nil
	return set==nil or set[key]==true
end

function A.askKeys(format)
	local out={}
	for i=1,#QUESTIONS do
		if A.askOffered(QUESTIONS[i].key,format)then
			out[#out+1]=QUESTIONS[i].key
		end
	end
	return out
end

function A.askDefault(format)
	return A.askKeys(format)[1]or QUESTIONS[1].key
end

local ASK_SORT_DEFAULT={
	beats={column="rate",ascending=true},
	where={column="rate",ascending=true},
	worth={column="rate",ascending=false},
	comp={column="rate",ascending=true},
	maps={column="rate",ascending=false},
	builds={column="met",ascending=false},
}

function A.askPopulation(format,season,character,bound)
	if type(A.summarize)~="function"then
		return 0,0,0
	end
	local ok,summary=pcall(A.paintWalk,"summarize",format,season,character,bound)
	if not ok or type(summary)~="table"then
		return 0,0,0
	end
	return summary.matches or 0,summary.decided or 0,summary.undated or 0
end

local NOTHING="none yet"

local DASH="-"

local UNREADABLE="this couldn't be read: try /reload"

local function countsMatches(format)
	return not(type(A.compRounds)=="function"and A.compRounds(format))
		and(format=="duel"or(type(A.specMatchFormat)=="function"and A.specMatchFormat(format)))
end

local function specReadings(format,season,character,bound,comp)
	local rounds=type(A.compRounds)=="function"and A.compRounds(format)
	local matches=type(A.specMatchFormat)=="function"and A.specMatchFormat(format)
	if not rounds and not matches then
		return nil,nil,"this tab keeps no spec readings"
	end
	if type(A.specCards)~="function"then
		return nil,nil,UNREADABLE,nil,"the comp readings did not load"
	end
	local ok,cards,floor,rows,_,_,read=pcall(A.specCards,format,season,character,bound,comp)
	if not ok then
		return nil,nil,UNREADABLE,nil,"the comp readings could not be taken"
	end
	return type(cards)=="table"and cards or{},type(rows)=="table"and rows or{},nil,floor,nil,
		type(read)=="table"and read or nil
end

local function readFigures(answer,read,which)
	local side=type(read)=="table"and read[which]or nil
	if type(side)=="table"then
		answer.samplesRead,answer.samplesSkipped=side.counted,side.skipped
	end
	return answer
end

local function cardFor(cards,kind)
	if type(cards)~="table"then
		return nil
	end
	for i=1,#cards do
		local card=cards[i]
		if card.kind==kind then
			return card
		end
		if card.kind=="collapsed"and type(card.folded)=="table"then
			for f=1,#card.folded do
				if card.folded[f].kind==kind then
					return card.folded[f]
				end
			end
		end
	end
	return nil
end

function A.askRecordFits(key,row)
	if type(row)~="table"then
		return false
	end
	local wins,losses=tonumber(row.wins)or 0,tonumber(row.losses)or 0
	if key=="worth"then
		return wins>losses
	end
	if key=="comp"then
		return wins+losses>0 and losses>=wins
	end
	if key=="beats"or key=="where"then
		return losses>=1 and losses>=wins
	end
	return false
end

local function fittingLead(key,ranked)
	for i=1,#(ranked or{})do
		if A.askRecordFits(key,ranked[i])then
			return ranked[i]
		end
	end
	return nil
end

local function underOrder(a,b)
	if(a.met or 0)~=(b.met or 0)then
		return(a.met or 0)>(b.met or 0)
	end
	return tostring(a.key or a.name)<tostring(b.key or b.name)
end

local function sideRow(row,which)
	local side=row[which]
	if type(side)~="table"or(side.rounds or 0)<=0 then
		return nil
	end
	return{
		key=row.key,
		spec=row.spec,
		class=row.class,
		classToken=row.classToken,
		name=A.chipText(row),
		met=side.rounds,
		wins=side.wins,
		losses=side.losses,
		winRate=side.winRate,
		ids=type(row.matches)=="table"and row.matches or nil,
	}
end

local function specSides(rows,which,sort,ascending)
	local floor=A.rankFloor("specs")
	local ranked,under={},{}
	local sorted=A.specSorted(rows,sort,ascending)
	for i=1,#sorted do
		local row=sideRow(sorted[i],which)
		if row then
			if row.winRate~=nil and row.met>=floor then
				ranked[#ranked+1]=row
			else
				under[#under+1]=row
			end
		end
	end
	table.sort(under,underOrder)
	return ranked,under,floor
end

local function answerDuelBeats(season,character,bound)
	if type(A.duelClassTally)~="function"then
		return{reason=UNREADABLE,fault="the class readings did not load",preview=NOTHING}
	end
	local ok,rows,read=pcall(A.duelClassTally,season,character,bound)
	if not ok or type(rows)~="table"then
		return{reason=UNREADABLE,fault="the class readings could not be taken",preview=NOTHING}
	end
	local ranked,under,floor=specSides(rows,"against","againstRate",true)
	local lead=fittingLead("beats",ranked)
	local answer={rows=ranked,under=under,preview=lead and lead.name or NOTHING,
		lead=lead,floor=floor,samplesRead=read.counted,samplesSkipped=read.skipped}
	if#ranked==0 and#under==0 then
		answer.reason=(read.skipped or 0)>0
			and("no class was found for the opponent in %d %s"):format(read.skipped,
				read.skipped==1 and"duel"or"duels")
			or"no class has been against you yet"
	elseif#ranked==0 then
		answer.reason=("no class has been against you %d times yet"):format(floor)
	elseif lead==nil then
		answer.reason="no class with enough results has beaten you as often as you beat it"
	end
	return answer
end

local function answerBeats(format,season,character,bound,comp)
	if format=="duel"then
		return answerDuelBeats(season,character,bound)
	end
	local _,rows,reason,_,fault,read=specReadings(format,season,character,bound,comp)
	if reason then
		return{reason=reason,fault=fault,preview=NOTHING}
	end

	local ranked,under,floor=specSides(rows,"against","againstRate",true)
	if#ranked==0 and#under==0 then
		return readFigures({reason="no spec has been against you yet",preview=NOTHING},read,"against")
	end
	local lead=fittingLead("beats",ranked)
	return readFigures({
		rows=ranked,
		under=under,
		preview=lead and lead.name or NOTHING,
		lead=lead,
		reason=(#ranked==0 and("no spec has been against you %d times yet"):format(floor))
			or(lead==nil and"no spec with enough results has beaten you as often as you beat it")or nil,
		floor=floor,
	},read,"against")
end

local function answerWorth(format,season,character,bound,comp)
	local cards,rows,reason,_,fault,read=specReadings(format,season,character,bound,comp)
	if reason then
		return{reason=reason,fault=fault,preview=NOTHING}
	end

	local ranked,under,floor=specSides(rows,"alongside","alongRate",false)
	if#ranked==0 and#under==0 then
		return readFigures({reason="no spec has been beside you yet",preview=NOTHING},read,"alongside")
	end
	local swing=cardFor(cards,"swing")
	local lead=fittingLead("worth",ranked)
	return readFigures({
		rows=ranked,
		under=under,
		preview=lead and lead.name or NOTHING,
		lead=lead,
		reason=(#ranked==0 and("no spec has been beside you %d times yet"):format(floor))
			or(lead==nil and"no spec with enough results has a winning record beside you")or nil,
		floor=floor,
		note=(#ranked>0 and swing)and("%s swings %s"):format(swing.name,swing.rate)or nil,
	},read,"alongside")
end

function A.mapEntries(rows)
	local floor=A.rankFloor("maps")
	local ranked,under,rated={},{},false
	for i=1,#(rows or{})do
		local row=rows[i]
		local wins,losses=A.winRecord(row)
		wins,losses=wins or 0,losses or 0
		local entry={key=row.map,name=row.map,met=wins+losses,played=row.played,
			wins=wins,losses=losses,winRate=row.winRate,
			ids=type(row.ids)=="table"and row.ids or nil}
		if row.winRate~=nil then
			rated=true
		end
		if row.winRate~=nil and entry.met>=floor then
			ranked[#ranked+1]=entry
		else
			under[#under+1]=entry
		end
	end
	return ranked,under,rated,floor
end

local function worstFirst(a,b)
	if a.winRate~=b.winRate then
		return a.winRate<b.winRate
	end
	if a.met~=b.met then
		return a.met>b.met
	end
	return tostring(a.name)<tostring(b.name)
end

local function answerWhere(format,season,character,bound,comp)
	if type(A.mapTally)~="function"then
		return{reason=UNREADABLE,fault="the map grouping did not load",
			preview=NOTHING}
	end
	local ok,rows,considered,decided,unplaced=pcall(A.mapTally,format,season,character,bound,comp)
	if not ok or type(rows)~="table"then
		return{reason=UNREADABLE,fault="the map grouping could not be taken",
			preview=NOTHING}
	end

	if#rows==0 then
		local reason=comp~=nil and"no round against this composition here yet"or"no matches here yet"
		if(unplaced or 0)>0 then
			reason=("no map was recorded for %d %s here"):format(unplaced,
				unplaced==1 and"match"or"matches")
		end
		return{reason=reason,preview=NOTHING,considered=considered,unplaced=unplaced}
	end

	local ranked,under,rated,floor=A.mapEntries(rows)
	table.sort(ranked,worstFirst)
	table.sort(under,underOrder)

	local lead=fittingLead("where",ranked)

	local reason=nil
	if lead==nil then
		if not rated then
			reason="none of these matches has a result yet"
		elseif#ranked==0 then
			reason=("no map has %d results here yet"):format(floor)
		else
			reason="no map with enough results is lost at least as often as won"
		end
	end

	return{
		rows=ranked,
		under=under,
		preview=lead and lead.name or NOTHING,
		lead=lead,
		reason=reason,
		floor=floor,
		considered=considered,
		decided=decided,
		unplaced=unplaced,
	}
end

local function compName(members)
	if type(members)~="table"or#members==0 then
		return"?"
	end
	local parts={}
	for i=1,#members do
		parts[i]=type(A.chipText)=="function"and A.chipText(members[i])or tostring(members[i].spec)
	end
	return table.concat(parts," + ")
end

local function answerComp(format,season,character,bound)
	if type(A.compTally)~="function"then
		return{reason=UNREADABLE,fault="the comp readings did not load",preview=NOTHING}
	end
	local ok,rows,_,_,_,_,_,allDrawn=pcall(A.paintWalk,"compTally",format,season,character,bound)
	if not ok or type(rows)~="table"then
		return{reason=UNREADABLE,fault="the comp readings could not be taken",preview=NOTHING}
	end
	allDrawn=tonumber(allDrawn)or 0
	if#rows==0 then
		return{reason="no composition has been met often enough here yet",preview=NOTHING,
			allDrawn=allDrawn,drawnFormat=format}
	end
	local floor=A.rankFloor("comps")
	local ranked,under={},{}
	for i=1,#rows do
		local row=rows[i]
		local entry={key=row.key,name=compName(row.members),met=(row.wins or 0)+(row.losses or 0),
			wins=row.wins,
			losses=row.losses,drawn=row.draws or 0,winRate=row.winRate,ids=row.ids,
			ranked=row.ranked~=false,tally=row}
		if entry.ranked then
			ranked[#ranked+1]=entry
		else
			under[#under+1]=entry
		end
	end
	local lead=fittingLead("comp",ranked)
	return{
		rows=ranked,
		under=under,
		preview=lead and lead.name or NOTHING,
		lead=lead,
		reason=(#ranked==0 and("no composition has been met %d times yet"):format(floor))
			or(lead==nil and"no composition with enough results has a losing or even record")or nil,
		ranked=#ranked,
		floor=floor,
		allDrawn=allDrawn,
		drawnFormat=format,
	}
end

local ANSWERS={
	beats=answerBeats,
	where=answerWhere,
	worth=answerWorth,
	comp=answerComp,
}

function A.askAnswer(key,format,season,character,bound,comp)
	local question=A.askQuestion(key)
	if question==nil then
		return nil
	end
	local answer=ANSWERS[key](format,season,character,bound,comp)
	answer.key=key
	answer.title=question.title
	answer.group=question.group
	answer.columns=question.columns
	answer.noun=question.noun
	answer.floorKind=question.floor
	if answer.floor==nil then
		answer.floor=A.rankFloor(question.floor)
	end
	answer.unit={"round","rounds"}
	answer.floorUnit="rounds"
	if key=="where"and comp==nil then
		answer.unit={"decided","decided"}
		answer.floorUnit="decided matches"
	end
	local specMatches=(key=="beats"or key=="worth")and countsMatches(format)
	if(key=="comp"and not(type(A.compRounds)=="function"and A.compRounds(format)))
		or specMatches then
		answer.unit={"match","matches"}
		answer.floorUnit="decided matches"
	end
	if specMatches then
		answer.headerNames={met="GAMES"}
		if format=="duel"then
			answer.headerNames.name="CLASS"
			answer.noun={"class","classes"}
		end
	end
	if key=="comp"and type(A.compCountName)=="function"then
		answer.countName=A.compCountName(format)
	end
	if key=="beats"and format=="duel"then
		answer.group="THE CLASSES YOU MEET"
	end
	answer.table=question.table
	answer.comp=comp
	if type(answer.lead)=="table"and not A.askRecordFits(key,answer.lead)then
		answer.lead=nil
		answer.preview=NOTHING
	end
	if answer.lead==nil then
		if answer.reason==UNREADABLE then
			answer.dashFor="unreadable"
		elseif type(answer.rows)=="table"and#answer.rows>0 then
			answer.dashFor="no-record"
		else
			answer.dashFor="nothing-ranked"
		end
	end
	return answer
end

function A.askFloorLine(answer)
	if type(answer)~="table"then
		return nil
	end
	local parts={}
	local count=type(answer.under)=="table"and#answer.under or 0
	if count>0 then
		local noun=type(answer.noun)=="table"and answer.noun or{"row","rows"}
		parts[#parts+1]=("%d %s under %d %s"):format(count,
			count==1 and tostring(noun[1])or tostring(noun[2]),
			answer.floor or 0,tostring(answer.floorUnit or"rounds"))
	end
	local allDrawn=tonumber(answer.allDrawn)or 0
	if allDrawn>0 and type(A.compAllDrawnText)=="function"then
		parts[#parts+1]=A.compAllDrawnText(answer.drawnFormat,allDrawn)
	end
	if#parts==0 then
		return nil
	end
	return table.concat(parts,"; ")
end

local askUnderShown=false

function A.askUnderShown()
	return askUnderShown
end

function A.setAskUnderShown(shown)
	if shown==nil then
		askUnderShown=not askUnderShown
	else
		askUnderShown=shown==true
	end
	return askUnderShown
end

function A.clickAskUnder()
	A.setAskUnderShown(nil)
	if type(A.refreshWindow)=="function"then
		pcall(A.refreshWindow)
	end
	return askUnderShown
end

function A.askAnswers(format,season,character,bound,comp)
	local out={}
	local keys=A.askKeys(format)
	for i=1,#keys do
		out[#out+1]=A.askAnswer(keys[i],format,season,character,bound,comp)
	end
	return out
end

function A.askHeaderColumns(answer)
	if type(answer)~="table"or answer.columns==nil or type(A.rowColumns)~="function"then
		return nil
	end
	local columns=A.rowColumns(answer.columns)
	if type(columns)~="table"then
		return columns
	end
	local renamed=type(answer.headerNames)=="table"and answer.headerNames or{}
	local out={}
	for i=1,#columns do
		local copy={}
		for field,value in pairs(columns[i])do
			copy[field]=value
		end
		if renamed[copy.key]~=nil then
			copy.name=renamed[copy.key]
		end
		out[i]=copy
	end
	return out
end

function A.askLines(format,season,character,bound)
	local lines={}
	local matches,decided,undated=A.askPopulation(format,season,character,bound)

	local label=type(A.formatLabel)=="function"and A.formatLabel(format)or tostring(format)
	lines[#lines+1]=("over %s: %d match%s, %d decided"):format(
		format==nil and"all formats"or tostring(label),matches,
		matches==1 and""or"es",decided)
	if(undated or 0)>0 then
		lines[#lines+1]=("  %d record%s carried no date, so a range left %s out"):format(
			undated,undated==1 and""or"s",undated==1 and"it"or"them")
	end

	if format=="world"then
		local zones=A.zonesAnswer(season,character,bound)
		lines[#lines+1]=("Where you fight: %d %s"):format(#zones.rows,#zones.rows==1 and"zone"or"zones")
		if zones.reason then
			lines[#lines+1]="  "..zones.reason
		end
		local function counted(figure,one,many)
			return("%s %s"):format(figure,figure=="1"and one or many)
		end
		for i=1,#zones.rows do
			local row=zones.rows[i]
			lines[#lines+1]=("  %s: %s, %s, %s, K/D %s"):format(row.name,counted(row.outings,"outing","outings"),
				counted(row.kills,"kill","kills"),counted(row.deaths,"death","deaths"),row.kd)
		end
	end

	local answers=A.askAnswers(format,season,character,bound)
	for i=1,#answers do
		local answer=answers[i]
		local groups=type(answer.rows)=="table"and#answer.rows or 0
		lines[#lines+1]=("%s: %d %s, %s"):format(answer.title,groups,
			groups==1 and"row"or"rows",tostring(answer.preview))
		if answer.group then
			lines[#lines+1]="  table "..tostring(answer.group)
		end
		if answer.reason then
			lines[#lines+1]="  "..answer.reason
		end
		if answer.fault then
			lines[#lines+1]="  "..answer.fault
		end
		local card=A.askCard(answer)
		if card==nil then
			lines[#lines+1]="  no card"
		elseif card.empty and card.dashFor=="unreadable"then
			lines[#lines+1]=("  card %s: %s, could not be read (%s)"):format(card.title,card.emptyText,
				tostring(card.dashFor))
		elseif card.empty then
			lines[#lines+1]=("  card %s: %s, nothing qualifies (%s)"):format(card.title,card.emptyText,
				tostring(card.dashFor))
		else
			lines[#lines+1]=("  card %s: %s %s %s%s"):format(card.title,card.name,
				card.rate,card.record,card.over and(" "..card.over)or"")
		end
		lines[#lines+1]=("  floor %s %s, %d ranked, %d under"):format(tostring(answer.floor or"?"),
			tostring(answer.floorUnit or"?"),type(answer.rows)=="table"and#answer.rows or 0,
			type(answer.under)=="table"and#answer.under or 0)

		local opens=A.askRowOpensKey(answer)
		if opens==nil then
			lines[#lines+1]="  rows open nothing"
		else
			local lead=type(answer.lead)=="table"and A.askRowKey(answer.lead)or nil
			local behind=lead and A.askRowLines(answer,lead)or{}
			local listed=0
			for n=1,#behind do
				if behind[n].kind=="specMet"then
					listed=listed+1
				end
			end
			lines[#lines+1]=("  rows open %s; %s lists %d"):format(opens,
				tostring(lead or"no lead row"),listed)
		end
	end

	lines[#lines+1]=A.askSpanLine()

	return lines
end

function A.askSpanLine()
	local room=select(5,A.askColumnShares())
	local parts,disagreeing,unread,sets={},0,0,0
	for i=1,#QUESTIONS do
		local question=QUESTIONS[i]
		local span=nil
		if question.columns==nil then
			span=false
		else
			sets=sets+1
			if type(A.columnSpan)=="function"and type(A.rowColumns)=="function"then
				span=A.columnSpan(A.rowColumns(question.columns))
			end
		end
		if span==false then
			parts[#parts+1]=question.key.." none"
		elseif type(span)~="number"then
			unread=unread+1
			parts[#parts+1]=question.key.." unread"
		else
			parts[#parts+1]=("%s %d"):format(question.key,span)
			if span~=room then
				disagreeing=disagreeing+1
			end
		end
	end

	local verdict
	if unread>0 then
		verdict=("%d span%s could not be read"):format(unread,unread==1 and""or"s")
	elseif disagreeing>0 then
		verdict=("DISAGREEING on %d of %d"):format(disagreeing,sets)
	else
		verdict="agreeing"
	end

	return("answer table: room %d, spans %s, %s"):format(room,table.concat(parts," "),verdict)
end

local ASK_CELL={
	name=function(row)
		return tostring(row.name or"?")
	end,
	met=function(row)
		return tostring(row.met or 0)
	end,
	record=function(row)
		if row.winRate==nil or type(row.wins)~="number"or type(row.losses)~="number"then
			return"-"
		end
		return("%d-%d"):format(row.wins,row.losses)
	end,
	rate=function(row)
		return A.percentText(row.winRate)or"-"
	end,
}

for _,key in ipairs({"damage","healing","rating","mmr","fastest","outings","kills","deaths","kd",
	"tally"})do
	ASK_CELL[key]=function(row)
		return type(row[key])=="string"and row[key]or"-"
	end
end

function A.askElements(answer)
	local out={}
	if type(answer)~="table"or type(answer.rows)~="table"or answer.columns==nil then
		return out
	end

	local columns=A.rowColumns(answer.columns)
	if type(columns)~="table"then
		return out
	end

	local function element(row,faint)
		local cells=A.columnCells(row,columns,ASK_CELL)

		local tint=nil
		if not faint and row.classToken~=nil and type(A.classColor)=="function"then
			local read,r,g,b,alpha=pcall(A.classColor,row.classToken)
			if read and type(r)=="number"then
				tint={name={r,g,b,alpha}}
			end
		end

		local style=nil
		local bar=nil
		if faint then
			style={}
			for c=1,#columns do
				if columns[c].key then
					style[columns[c].key]={role="bodyText",tone="underText"}
				end
			end
		end
		if row.winRate~=nil then
			if not faint then
				style={rate={role="bodyText",tone=A.winRateTone(row.winRate)or"dim"}}
			end
			bar={record=row.winRate}
		end
		if row.unnamed and not faint then
			style=style or{}
			style.name={role="bodyText",tone="dim"}
		end
		if row.kdTone~=nil and not faint then
			style=style or{}
			style.kd={role="bodyText",tone=row.kdTone}
		end

		return{row=row,cells=cells,cellTint=tint,cellStyle=style,
			cellBar=bar,askKey=answer.key,faint=faint or nil,
			kdCell=type(row.kdCounts)=="table"and row.kdCounts or nil,
			cellOpens=not faint and type(row.cellOpens)=="table"and row.cellOpens or nil,
			askRow=(A.askRowOpens(answer)and type(row.ids)=="table"and#row.ids>0)
				and A.askRowKey(row)or nil}
	end

	for i=1,#answer.rows do
		out[#out+1]=element(answer.rows[i],answer.rows[i].ranked==false)
	end
	if A.askUnderShown()and type(answer.under)=="table"and answer.key~="maps"then
		for i=1,#answer.under do
			out[#out+1]=element(answer.under[i],true)
		end
	end

	return out
end

function A.askRowKey(row)
	if type(row)~="table"then
		return nil
	end
	for _,key in ipairs({"key","guid","name"})do
		local held=row[key]
		if type(held)=="string"and held~=""then
			return held
		end
	end
	return nil
end

function A.askRowOpensKey(answer)
	if type(answer)~="table"then
		return nil
	end
	local question=A.askQuestion(answer.key)or answer
	if type(question)~="table"or type(question.opens)~="string"or question.opens==""then
		return nil
	end
	return question.opens
end

function A.askRowOpens(answer)
	return A.askRowOpensKey(answer)~=nil
end

function A.askRowLines(answer,rowKey)
	local out={}
	local opens=A.askRowOpensKey(answer)
	if opens==nil or type(rowKey)~="string"or rowKey==""then
		return out
	end
	local held=nil
	for _,rows in ipairs({answer.rows,answer.under})do
		if type(rows)=="table"then
			for i=1,#rows do
				if A.askRowKey(rows[i])==rowKey then
					held=rows[i]
				end
			end
		end
	end
	if held==nil then
		return out
	end
	return A.idLines(held.ids,opens)
end

function A.idLines(ids,key)
	local out={}
	if type(ids)~="table"then
		return out
	end

	local met={}
	for i=#ids,1,-1 do
		local text=type(A.matchLineText)=="function"and A.matchLineText(ids[i])or nil
		if text then
			met[#met+1]={kind="specMet",id=ids[i],text=text,stay=true,
				look=type(A.matchRowLook)=="function"and A.matchRowLook(ids[i])or nil}
		end
	end
	if#met==0 then
		return out
	end
	local outings=key=="OUTINGS"
	out[1]={kind="specMetHead",key=key,
		text=("%d %s"):format(#met,#met==1 and(outings and"outing"or"match")
			or(outings and"outings"or"matches"))}
	if key=="MET IN"and type(A.metNamesLine)=="function"then
		out[#out+1]=A.metNamesLine(met)
	end
	for i=1,#met do
		out[#out+1]=met[i]
	end
	return out
end

local function sideMembers(entries)
	local out={}
	for i=1,#(entries or{})do
		local p=type(entries[i])=="table"and entries[i].p or nil
		if type(p)=="table"then
			out[#out+1]={spec=p.spec,classToken=p.classToken,class=p.class}
		end
	end
	return out
end

function A.compRowLines(row)
	if type(row)~="table"then
		return{}
	end
	local byRound=type(row.rounds)=="table"
	local met={}
	if byRound then
		for i=#row.rounds,1,-1 do
			local held=row.rounds[i]
			local record=type(A.match)=="function"and A.match(held.id)or nil
			local round=type(record)=="table"and type(record.rounds)=="table"and record.rounds[held.round]
				or nil
			if type(round)=="table"then
				local mates=type(A.roundSides)=="function"and A.roundSides(record,round)or nil
				local won=held.won==true
				local grid={match=("#%s"):format(tostring(held.id)),round=("R%d"):format(held.round),
					side=sideMembers(mates),result=won and"WON"or"LOST",tone=won and"win"or"loss"}
				met[#met+1]={kind="specMet",id=held.id,grid=grid,stay=true,
					text=("%s   %s   %s"):format(grid.match,grid.round,grid.result)}
			end
		end
	else
		local ids=type(row.ids)=="table"and row.ids or{}
		for i=#ids,1,-1 do
			local record=type(A.match)=="function"and A.match(ids[i])or nil
			if type(record)=="table"then
				local split=type(A.rosterSplit)=="function"and A.rosterSplit(record)or nil
				local tone=A.resultTone(record)
				local result=(tone=="win"and"WON")or(tone=="loss"and"LOST")or"-"
				local grid={match=("#%s"):format(tostring(record.id)),
					side=sideMembers(type(split)=="table"and split.own or nil),result=result,
					tone=(tone=="win"or tone=="loss")and tone or nil}
				met[#met+1]={kind="specMet",id=ids[i],grid=grid,stay=true,
					text=("%s   %s"):format(grid.match,grid.result)}
			end
		end
	end
	if#met==0 then
		return{}
	end
	local noun=byRound and{"round","rounds"}or{"match","matches"}
	local out={
		{kind="specMetHead",key="MET IN",text=("%d %s"):format(#met,#met==1 and noun[1]or noun[2])},
		{kind="metGridHead",byRound=byRound or nil},
	}
	for i=1,#met do
		out[#out+1]=met[i]
	end
	return out
end

function A.askCard(answer)
	if type(answer)~="table"then
		return nil
	end
	local title=tostring(answer.title or""):upper()
	local row=type(answer.lead)=="table"and answer.lead or nil
	if row==nil then
		return{key=answer.key,title=title,empty=true,emptyText=DASH,
			dashFor=answer.dashFor or"nothing-ranked",floor=answer.floor,
			tipLines=A.askDashLines(answer)}
	end

	local met=type(row.met)=="number"and row.met or 0
	local unit=type(answer.unit)=="table"and answer.unit or nil
	local over,overForms=nil,nil
	if unit then
		local noun=met==1 and tostring(unit[1])or tostring(unit[2])
		over=("%d %s"):format(met,noun)
		overForms={over}
	end

	return{
		key=answer.key,
		title=title,
		name=ASK_CELL.name(row),
		record=ASK_CELL.record(row),
		rate=ASK_CELL.rate(row),
		over=over,
		overForms=overForms,
		winRate=row.winRate,
		tone=A.winRateTone(row.winRate),
		classToken=row.classToken,
		spec=row.spec,
		class=row.class,
		members=type(row.tally)=="table"and type(row.tally.members)=="table"and row.tally.members
			or nil,
	}
end

function A.askDashLines(answer)
	if type(answer)~="table"then
		return nil
	end
	local noun=type(answer.noun)=="table"and tostring(answer.noun[2])or"rows"
	noun=noun:sub(1,1):upper()..noun:sub(2)
	local verb=answer.key=="where"and"with"or"met in"
	local lines={
		tostring(answer.title or""):upper(),
		("%s %s %d or more %s are ranked"):format(noun,verb,tonumber(answer.floor)or 0,
			tostring(answer.floorUnit or"rounds")),
	}
	if answer.dashFor=="no-record"then
		lines[#lines+1]=answer.key=="worth"and"None of them has a winning record"
			or"None of them has a losing or even record"
	end
	return lines
end

function A.askCards(answers)
	local out={}
	if type(answers)~="table"then
		return out
	end
	for i=1,#answers do
		out[i]=A.askCard(answers[i])or false
	end
	return out
end

function A.askFillers()
	return ASK_CELL
end

local COMP_COLUMNS={
	{key="games",name="RDS",metric="compGames",sort="met",first="descending"},
	{key="record",name="W-L",metric="compRecord"},
	{key="rate",name="WON",metric="compPct",sort="rate",first="ascending"},
	{key="delta",name="RATING",metric="compDelta"},
	{key="length",name="LEN",metric="compLength"},
}

local COMP_SORT_COLUMNS={}
for i=1,#COMP_COLUMNS do
	local column=COMP_COLUMNS[i]
	if column.sort~=nil then
		COMP_SORT_COLUMNS[#COMP_SORT_COLUMNS+1]={sort=column.sort,name=column.name,first=column.first}
	end
end

function A.compColumns(format)
	local out={}
	for i=1,#COMP_COLUMNS do
		local column=COMP_COLUMNS[i]
		local name=column.key=="games"and type(A.compCountName)=="function"and A.compCountName(format)
			or column.name
		out[i]={key=column.key,name=name,metric=column.metric,sort=column.sort,
			width=math.max(A.metric(column.metric),A.headerFloor(name))}
	end
	return out
end

local ASK_SORT_WORDS={
	beats={
		met={descending="most met first",ascending="fewest met first"},
		rate={ascending="hardest first",descending="easiest first"},
	},
	where={
		met={descending="most decided first",ascending="fewest decided first"},
		rate={ascending="worst first",descending="best first"},
	},
	worth={
		met={descending="most beside you first",ascending="fewest beside you first"},
		rate={ascending="worst beside you first",descending="best beside you first"},
	},
	comp={
		met={descending="most met first",ascending="fewest met first"},
		rate={ascending="worst first",descending="best first"},
	},
	maps={
		met={descending="most decided first",ascending="fewest decided first"},
		rate={ascending="worst first",descending="best first"},
	},
	builds={
		met={descending="most played first",ascending="fewest played first"},
		rate={ascending="worst first",descending="best first"},
	},
}

local askSortHeld={}

function A.askSortKnown(column)
	return column=="met"or column=="rate"
end

function A.askSort(key)
	local default=ASK_SORT_DEFAULT[key]
	if default==nil then
		return nil,nil
	end
	local held=askSortHeld[key]
	if held~=nil then
		return held.column,held.ascending
	end
	return default.column,default.ascending
end

local function askSortOpens(key,column)
	local question=A.askQuestion(key)
	local columns=nil
	if key=="comp"then
		columns=COMP_SORT_COLUMNS
	elseif key=="builds"and type(A.rowColumns)=="function"then
		columns=A.rowColumns("askBuilds")
	elseif question and question.columns~=nil and type(A.rowColumns)=="function"then
		columns=A.rowColumns(question.columns)
	end
	if type(columns)=="table"then
		for i=1,#columns do
			if columns[i].sort==column then
				return columns[i].first~="descending"
			end
		end
	end
	return false
end

function A.toggleAskSort(key,column)
	local default=ASK_SORT_DEFAULT[key]
	if default==nil then
		return nil,nil
	end
	if column=="default"then
		askSortHeld[key]=nil
		return A.askSort(key)
	end
	if not A.askSortKnown(column)then
		return A.askSort(key)
	end
	local held,ascending=A.askSort(key)
	local up
	if held==column then
		up=not ascending
	else
		up=askSortOpens(key,column)
	end
	if column==default.column and up==default.ascending then
		askSortHeld[key]=nil
	else
		askSortHeld[key]={column=column,ascending=up}
	end
	return A.askSort(key)
end

function A.clickAskSort(key,column)
	A.toggleAskSort(key,column)
	if type(A.refreshWindow)=="function"then
		pcall(A.refreshWindow)
	end
	return A.askSort(key)
end

function A.askSortWords(key)
	local column,ascending=A.askSort(key)
	local words=ASK_SORT_WORDS[key]and ASK_SORT_WORDS[key][column]
	if words==nil then
		return nil
	end
	return ascending and words.ascending or words.descending
end

function A.askSorted(answer)
	local out={}
	if type(answer)~="table"or type(answer.rows)~="table"then
		return out
	end
	for i=1,#answer.rows do
		out[i]=answer.rows[i]
	end
	if askSortHeld[answer.key]==nil then
		return out
	end

	local column,ascending=A.askSort(answer.key)
	local field=column=="rate"and"winRate"or"met"
	table.sort(out,function(a,b)
		local tierA,tierB=a.ranked~=false,b.ranked~=false
		if tierA~=tierB then
			return tierA
		end
		local valueA,valueB=a[field],b[field]
		if valueA~=valueB then
			if valueA==nil then
				return false
			end
			if valueB==nil then
				return true
			end
			if ascending then
				return valueA<valueB
			end
			return valueA>valueB
		end
		local metA,metB=a.met or 0,b.met or 0
		if metA~=metB then
			return metA>metB
		end
		return tostring(A.askRowKey(a))<tostring(A.askRowKey(b))
	end)
	return out
end

function A.askSortLine(answer)
	if type(answer)~="table"then
		return nil
	end
	local column=A.askSort(answer.key)
	local question=A.askQuestion(answer.key)
	local heading=column
	if question and(question.columns~=nil or answer.key=="comp")then
		local columns=answer.key=="comp"and COMP_SORT_COLUMNS or A.askHeaderColumns(answer)or{}
		for i=1,#columns do
			if columns[i].sort==column then
				heading=columns[i].name
			end
		end
		if answer.key=="comp"and column=="met"and type(answer.countName)=="string"then
			heading=answer.countName
		end
	end
	local rows=A.askSorted(answer)
	local names={}
	for i=1,math.min(3,#rows)do
		names[#names+1]=ASK_CELL.name(rows[i])
	end
	return("%s: %s, %s: %s"):format(tostring(answer.title),tostring(heading),
		tostring(A.askSortWords(answer.key)),#names>0 and table.concat(names,", ")or"no rows")
end

local specsViewShown=false
local specsViewSort=nil

function A.specsViewShown()
	return specsViewShown
end

function A.setSpecsView(shown)
	if shown==nil then
		specsViewShown=not specsViewShown
	else
		specsViewShown=shown==true
	end
	if specsViewShown and type(A.mapsViewShown)=="function"and A.mapsViewShown()then
		A.setMapsView(false)
	end
	if specsViewShown and type(A.setTableView)=="function"then
		A.setTableView(nil)
	end
	return specsViewShown
end

function A.clickSpecsView()
	local mapsWasOpen=A.mapsViewShown()
	A.setSpecsView(nil)
	if specsViewShown and mapsWasOpen then
		A.storeMapsView(false)
	end
	if type(A.refreshWindow)=="function"then
		pcall(A.refreshWindow)
	end
	return specsViewShown
end

local mapsViewHeld=nil

function A.mapsViewShown()
	if mapsViewHeld~=nil then
		return mapsViewHeld
	end
	local db=type(A.db)=="function"and A.db()or nil
	return type(db)=="table"and type(db.ui)=="table"and db.ui.statsView=="maps"or false
end

function A.setMapsView(shown)
	mapsViewHeld=shown==true
	if mapsViewHeld then
		A.setSpecsView(false)
		A.setTableView(nil)
	end
	return mapsViewHeld
end

local tableViewHeld=nil

function A.tableViewShown()
	return tableViewHeld
end

function A.setTableView(view)
	if view~="bests"and view~="builds"then
		tableViewHeld=nil
		return nil
	end
	tableViewHeld=view
	specsViewShown=false
	mapsViewHeld=false
	return tableViewHeld
end

function A.clickTableView(view)
	if tableViewHeld==view then
		A.setTableView(nil)
	else
		local mapsWasOpen=A.mapsViewShown()
		A.setTableView(view)
		if mapsWasOpen then
			A.storeMapsView(false)
		end
	end
	if type(A.refreshWindow)=="function"then
		pcall(A.refreshWindow)
	end
	return tableViewHeld
end

function A.storeMapsView(shown)
	local db=type(A.db)=="function"and A.db()or nil
	if type(db)~="table"or type(db.ui)~="table"then
		return false
	end
	db.ui.statsView=shown and"maps"or nil
	return true
end

function A.clickMapsView()
	local shown=A.setMapsView(not A.mapsViewShown())
	A.storeMapsView(shown)
	if type(A.refreshWindow)=="function"then
		pcall(A.refreshWindow)
	end
	return shown
end

function A.mapsViewOffered(format,season,bound)
	if format=="world"then
		return false
	end
	if format~="duel"and format~="unknown"then
		return true
	end
	if type(A.mapTally)~="function"then
		return false
	end
	local character=type(A.windowCharacter)=="function"and A.windowCharacter()or nil
	local function offered()
		local ok,rows=pcall(A.mapTally,format,season,character,bound)
		return ok and type(rows)=="table"and#rows>=2
	end
	if type(A.paintHeld)=="function"then
		return A.paintHeld("mapsViewOffered",offered,format,season,character,bound)
	end
	return offered()
end

local ZONE_COLUMNS={
	{key="outings",name="OUTINGS"},
	{key="tally",name="KILLS AND DEATHS",metric="rowColTally",align="LEFT"},
	{key="kd",name="K/D"},
}

function A.zoneColumns()
	local room=type(A.askTableWidth)=="function"and A.askTableWidth()or 0
	local furniture=A.metric("rowLabelPad")*2+A.metric("rowCellGap")*#ZONE_COLUMNS
	local columns={{key="name",name="ZONE",metric="askName"}}
	local used=0
	for i=1,#ZONE_COLUMNS do
		local held=ZONE_COLUMNS[i]
		local share=held.metric and A.metric(held.metric)or math.floor(room/8)
		local width=math.max(share,A.headerFloor(held.name))
		columns[#columns+1]={key=held.key,name=held.name,metric="askRate",
			align=held.align or"RIGHT",width=width}
		used=used+width
	end
	columns[1].width=math.max(A.headerFloor("ZONE"),room-furniture-used)
	return columns
end

function A.zonesAnswer(season,character,bound)
	local answer={key="zones",title="Where you fight",group="WHERE YOU FIGHT",opens="OUTINGS",
		noun={"zone","zones"},columns=A.zoneColumns(),rows={},under={}}
	local ok,rows,unplaced,read=pcall(A.zoneTally,season,character,bound)
	if not ok or type(rows)~="table"then
		answer.reason=UNREADABLE
		return answer
	end
	for i=1,#rows do
		local row=rows[i]
		answer.rows[i]={key=row.key,name=row.name,met=row.outings,ids=row.ids,
			outings=tostring(row.outings),
			kills=row.kills~=nil and tostring(row.kills)or"-",
			deaths=row.deaths~=nil and tostring(row.deaths)or"-",
			tally=A.kdPairText(row.kills,row.deaths),
			kdCounts=row.kills~=nil and{kills=row.kills,deaths=row.deaths}or nil,
			kd=A.kdText(row.kills,row.deaths)or"-",kdTone=A.kdTone(row.kills,row.deaths)}
	end
	answer.unplaced,answer.read=unplaced,read
	if#answer.rows==0 then
		answer.reason=(unplaced or 0)>0
			and("no zone was recorded for %d %s"):format(unplaced,unplaced==1 and"outing"or"outings")
			or"no outings here yet"
	end
	return answer
end

local function bestFirst(a,b)
	if a.winRate~=b.winRate then
		return a.winRate>b.winRate
	end
	if a.met~=b.met then
		return a.met>b.met
	end
	return tostring(a.name)<tostring(b.name)
end

function A.mapsAnswer(format,season,character,bound)
	local answer={key="maps",title="Maps",group="EVERY MAP",columns="askWhere",
		noun={"map","maps"},floorKind="maps",floorUnit="decided matches",
		unit={"decided","decided"}}
	if type(A.mapTally)~="function"then
		answer.reason,answer.rows,answer.under=UNREADABLE,{},{}
		return answer
	end
	local ok,rows=pcall(A.mapTally,format,season,character,bound)
	if not ok or type(rows)~="table"then
		answer.reason,answer.rows,answer.under=UNREADABLE,{},{}
		return answer
	end
	local ranked,under,_,floor=A.mapEntries(rows)
	table.sort(ranked,bestFirst)
	table.sort(under,underOrder)
	local all={}
	for i=1,#ranked do
		all[#all+1]=ranked[i]
	end
	for i=1,#under do
		local entry={}
		for field,value in pairs(under[i])do
			entry[field]=value
		end
		entry.ranked=false
		all[#all+1]=entry
	end
	answer.rows=all
	answer.under=under
	answer.floor=floor
	answer.ranked=#ranked
	answer.underCount=#under
	if#all==0 then
		answer.reason="no matches here yet"
	end
	return answer
end

function A.specsSort()
	if specsViewSort~=nil then
		return specsViewSort.key,specsViewSort.ascending
	end
	return A.specSortDefault()
end

function A.setSpecsSort(sort,ascending)
	if not(type(A.specSortKnown)=="function"and A.specSortKnown(sort))then
		specsViewSort=nil
		return A.specsSort()
	end
	local open,up=A.specSortDefault()
	if sort==open and(ascending==true)==up then
		specsViewSort=nil
	else
		specsViewSort={key=sort,ascending=ascending==true}
	end
	return A.specsSort()
end

function A.toggleSpecsSort(sort)
	if sort=="default"then
		return A.setSpecsSort(nil)
	end
	if not(type(A.specSortKnown)=="function"and A.specSortKnown(sort))then
		return A.specsSort()
	end
	local held,ascending=A.specsSort()
	if held==sort then
		return A.setSpecsSort(sort,not ascending)
	end
	local opens=true
	if type(A.specSortOpens)=="function"then
		opens=A.specSortOpens(sort)
	end
	return A.setSpecsSort(sort,opens)
end

function A.askTableKind(answer)
	if type(answer)~="table"then
		return nil
	end
	local rows=(type(answer.rows)=="table"and#answer.rows or 0)
		+(type(answer.under)=="table"and#answer.under or 0)
	if rows==0 then
		return nil
	end
	if answer.table=="comp"then
		return"comp"
	end
	return nil
end

local function sentences(parts)
	local out={}
	for i=1,#parts do
		local text=tostring(parts[i])
		out[i]=text:sub(1,1):upper()..text:sub(2)
	end
	return table.concat(out,". ").."."
end

function A.askNoteText(answer)
	if type(answer)~="table"then
		return""
	end
	if type(answer.rows)~="table"or#answer.rows==0 then
		return answer.reason==UNREADABLE and DASH or NOTHING
	end

	local parts={}
	if type(answer.note)=="string"and answer.note~=""then
		parts[#parts+1]=answer.note
	end
	local words=A.askSortWords(answer.key)
	if words~=nil then
		parts[#parts+1]=words
	end
	if#parts==0 then
		return""
	end
	return sentences(parts)
end
