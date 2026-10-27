-- WowPvpHistory 0.70.33
-- Author:  Xenu-Sentinels
-- Project: wow-pvp-history
--          https://github.com/xenulive/wow-pvp-history
-- License: MIT, see LICENSE
local _,A=...

local BESTS={
	{key="damage",word="damage",head="DAMAGE"},
	{key="healing",word="healing",head="HEALING"},
	{key="rating",word="peak rating",head="PEAK RATING"},
	{key="mmr",word="peak MMR",head="PEAK MMR"},
	{key="fastest",word="fastest win",head="FASTEST WIN"},
}

local NEW_BEST_FLOOR=5

local function ownRow(record)
	local own=record.character and type(record.participants)=="table"
		and record.participants[record.character]or nil
	return type(own)=="table"and own or nil
end

local function botVenue(record)
	if type(record.participants)~="table"then
		return false
	end
	for guid in pairs(record.participants)do
		if A.isBotGuid(guid)then
			return true
		end
	end
	return false
end

local function capturedWin(record)
	local outcome,typed=A.recordVerdict(record)
	return outcome=="win"and not typed
end

function A.bestFigures(record)
	local out={}
	if type(record)~="table"then
		return out
	end
	local own=ownRow(record)
	if own==nil then
		return out
	end
	if type(own.damage)=="number"then
		out.damage=own.damage
	end
	if type(own.healing)=="number"then
		out.healing=own.healing
	end
	if not A.ladderSilent(own)then
		if record.rated==true and type(own.rating)=="number"and type(own.ratingChange)=="number"then
			out.rating=own.rating+own.ratingChange
		end
		if type(own.mmrPost)=="number"and own.mmrPost>0 then
			out.mmr=own.mmrPost
		end
	end
	if capturedWin(record)and type(record.duration)=="number"and record.duration>0 then
		out.fastest=record.duration
	end
	return out
end

local function beats(key,value,held)
	if held==nil then
		return true
	end
	if key=="fastest"then
		return value<held
	end
	return value>held
end

function A.bestText(key,value)
	if type(value)~="number"then
		return nil
	end
	if key=="damage"or key=="healing"then
		return A.figureText(value)
	end
	if key=="fastest"then
		return A.lengthText(math.floor(value))
	end
	return("%d"):format(value)
end

local function openedKey(record)
	return type(record.openedState)=="string"and record.openedState or"none"
end

function A.bestsTally(format,season,character,bound)
	local rows,order={},{}
	local db=A.db()
	if not(db and type(db.matches)=="table")then
		return order,nil,0,false,false
	end

	local admitted,states={},{}
	for i=1,#db.matches do
		local record=db.matches[i]
		if type(record)=="table"and(format==nil or record.format==format)
			and A.bestsViewOffered(record.format)
			and(season==nil or A.recordInSeason(record,season))
			and A.recordedBy(record,character)and A.recordSince(record,bound)
			and ownRow(record)~=nil and not botVenue(record)then
			admitted[#admitted+1]=record
			local key=openedKey(record)
			states[key]=(states[key]or 0)+1
		end
	end
	local opened,openedCount=nil,0
	for key,count in pairs(states)do
		if count>openedCount or(count==openedCount and key<opened)then
			opened,openedCount=key,count
		end
	end

	local leftOut,anyRating,anyMmr=0,false,false
	for i=1,#admitted do
		local record=admitted[i]
		local own=ownRow(record)or{}
		local spec=type(own.spec)=="string"and own.spec or"?"
		local classToken=type(own.classToken)=="string"and own.classToken or nil
		local key=classToken and(spec.." "..classToken)or spec
		local row=rows[key]
		if not row then
			row={key=key,name=A.chipText({spec=spec,class=own.class}),
				spec=spec,classToken=classToken,class=own.class,matches=0,bests={}}
			rows[key]=row
			order[#order+1]=row
		end
		row.matches=row.matches+1
		local figures=A.bestFigures(record)
		if figures.fastest~=nil and openedKey(record)~=opened then
			figures.fastest=nil
			leftOut=leftOut+1
			row.leftOut=(row.leftOut or 0)+1
		end
		for _,best in ipairs(BESTS)do
			local value=figures[best.key]
			local held=row.bests[best.key]
			if value~=nil and beats(best.key,value,held and held.value)then
				row.bests[best.key]={value=value,id=record.id,
					stamp=record.openedAt or record.completedAt or record.endedAt,
					map=type(record.map)=="table"and record.map.name or nil}
			end
		end
		anyRating=anyRating or figures.rating~=nil
		anyMmr=anyMmr or figures.mmr~=nil
	end

	for i=1,#order do
		local row=order[i]
		local ids,seen={},{}
		for _,best in ipairs(BESTS)do
			local held=row.bests[best.key]
			if held and held.id~=nil and not seen[held.id]then
				seen[held.id]=true
				ids[#ids+1]=held.id
			end
		end
		table.sort(ids,function(a,b)
			if type(a)~=type(b)then
				return type(a)=="number"
			end
			return a<b
		end)
		row.ids=ids
	end

	table.sort(order,function(a,b)
		return a.key<b.key
	end)
	return order,opened,leftOut,anyRating,anyMmr
end

function A.bestsColumns(anyRating,anyMmr)
	local figures={}
	for _,best in ipairs(BESTS)do
		if(best.key~="rating"or anyRating)and(best.key~="mmr"or anyMmr)then
			figures[#figures+1]=best
		end
	end
	return figures
end

local MEASURE_MARGIN=2

function A.bestsColumnSet(figures,needs)
	needs=type(needs)=="table"and needs or{}
	local function width(key,head)
		local need=type(needs[key])=="number"and needs[key]>0 and(math.ceil(needs[key])+MEASURE_MARGIN)or 0
		return math.max(A.headerFloor(head),need)
	end
	local columns={{key="name",name="SPEC",metric="askName",width=width("name","SPEC")}}
	for i=1,#figures do
		columns[#columns+1]={key=figures[i].key,name=figures[i].head,metric="askRate",
			align="RIGHT",width=width(figures[i].key,figures[i].head)}
	end
	return columns
end

local function cellText(row,key)
	local held=row.bests and row.bests[key]or nil
	return held and A.bestText(key,held.value)or"-"
end

function A.bestsAnswer(format,season,character,bound,measure)
	measure=type(measure)=="function"and measure or A.labelRoom
	local answer={key="bests",title="Bests",opens="BESTS SET IN",noun={"spec","specs"}}
	local ok,order,opened,leftOut,anyRating,anyMmr=pcall(A.bestsTally,format,season,character,bound)
	if not ok or type(order)~="table"then
		answer.reason,answer.rows,answer.under="this couldn't be read: try /reload",{},{}
		answer.columns=A.bestsColumnSet({})
		return answer
	end
	local figures=A.bestsColumns(anyRating,anyMmr)
	answer.bestKeys={}
	for i=1,#figures do
		answer.bestKeys[i]=figures[i].key
	end
	local rows={}
	local needs={}
	local function widen(key,wide)
		if type(wide)=="number"and wide>(needs[key]or 0)then
			needs[key]=wide
		end
	end
	for i=1,#order do
		local row=order[i]
		local out={key=row.key,name=row.name,spec=row.spec,classToken=row.classToken,
			class=row.class,met=row.matches,ids=row.ids,bests=row.bests,leftOut=row.leftOut}
		widen("name",measure(tostring(row.name))
			+(row.classToken~=nil and(A.metric("compSwatch")+A.metric("chipGap"))or 0))
		out.cellOpens={}
		for _,best in ipairs(BESTS)do
			out[best.key]=cellText(row,best.key)
			local held=row.bests[best.key]
			if held~=nil and held.id~=nil then
				out.cellOpens[best.key]=held.id
			end
		end
		for _,best in ipairs(figures)do
			widen(best.key,measure(out[best.key]))
		end
		rows[i]=out
	end
	answer.columns=A.bestsColumnSet(figures,needs)
	answer.rows,answer.under=rows,{}
	answer.group="YOUR BESTS, BY SPEC"
	answer.opened=opened
	answer.leftOut=leftOut
	if#rows==0 then
		answer.reason="no matches here yet"
	end
	return answer
end

function A.bestsLines(format,season,character,bound)
	local lines={}
	local order,opened,leftOut,anyRating,anyMmr=A.bestsTally(format,season,character,bound)
	local figures=A.bestsColumns(anyRating,anyMmr)
	for _,row in ipairs(order)do
		local parts={}
		for _,best in ipairs(figures)do
			local held=row.bests[best.key]
			if held then
				local where={}
				where[#where+1]=A.stampWords(held.stamp)
				where[#where+1]=held.map
				where[#where+1]=held.id~=nil and("#"..tostring(held.id))or nil
				parts[#parts+1]=("%s %s (%s)"):format(best.word,A.bestText(best.key,held.value),
					table.concat(where,", "))
			else
				parts[#parts+1]=best.word.." -"
			end
		end
		lines[#lines+1]=("%s, %d %s: %s"):format(row.name,row.matches,
			row.matches==1 and"match"or"matches",table.concat(parts,", "))
	end
	if(leftOut or 0)>0 then
		lines[#lines+1]=("fastest win reads matches opened in %s; %d %s opened elsewhere left out")
			:format(tostring(opened),leftOut,leftOut==1 and"win"or"wins")
	end
	return lines,#order
end

function A.bestsViewOffered(format)
	return format~="duel"and format~="world"
end

function A.newBests(record)
	local own=type(record)=="table"and ownRow(record)or nil
	if own==nil or botVenue(record)then
		return{},0,"unranked"
	end
	local spec=own.spec
	local db=A.db()
	if not(db and type(db.matches)=="table")then
		return{},0,"unranked"
	end
	local mine=A.bestFigures(record)
	local _,opened=A.bestsTally(record.format,nil,record.character,nil)
	if openedKey(record)~=opened then
		mine.fastest=nil
	end
	local held,earlier={},0
	for i=1,#db.matches do
		local other=db.matches[i]
		if type(other)=="table"and other~=record and other.format==record.format
			and A.recordedBy(other,record.character)and not botVenue(other)then
			local otherOwn=ownRow(other)
			if otherOwn~=nil and otherOwn.spec==spec then
				earlier=earlier+1
				local figures=A.bestFigures(other)
				if figures.fastest~=nil and openedKey(other)~=opened then
					figures.fastest=nil
				end
				for _,best in ipairs(BESTS)do
					local value=figures[best.key]
					if value~=nil and beats(best.key,value,held[best.key])then
						held[best.key]=value
					end
				end
			end
		end
	end
	if earlier<NEW_BEST_FLOOR then
		return{},earlier,"early"
	end
	local set={}
	for _,best in ipairs(BESTS)do
		local value=mine[best.key]
		if value~=nil and held[best.key]~=nil and beats(best.key,value,held[best.key])then
			set[#set+1]={key=best.key,word=best.word,text=A.bestText(best.key,value)}
		end
	end
	return set,earlier,#set>0 and"set"or"none"
end

function A.newBestLine(set)
	if type(set)~="table"or#set==0 then
		return nil
	end
	local parts={}
	for i=1,#set do
		parts[i]=("%s %s"):format(set[i].word,tostring(set[i].text))
	end
	return"new best: "..table.concat(parts,", ")
end
