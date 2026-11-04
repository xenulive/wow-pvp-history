-- WowPvpHistory 0.75.26
-- Author:  Xenu-Sentinels
-- Project: wow-pvp-history
--          https://github.com/xenulive/wow-pvp-history
-- License: MIT, see LICENSE
local _,A=...

local SESSION_GAP_MINUTES=60

local TREND_COUNT=30

function A.sessionGapMinutes()
	return SESSION_GAP_MINUTES
end

function A.standingTrendCount()
	return TREND_COUNT
end

local function endedStamp(subject)
	if subject.reason=="abandoned"then
		return subject.completedAt
	end
	return subject.completedAt or subject.endedAt
end

local function entryLength(subject)
	return type(subject.duration)=="number"and subject.duration
		or type(subject.seconds)=="number"and subject.seconds or 0
end

local function startEpoch(subject)
	if type(subject)~="table"then
		return nil
	end
	local opened=A.stampEpoch(subject.openedAt)
	if opened~=nil then
		return opened
	end
	local ended=A.stampEpoch(endedStamp(subject))
	if ended~=nil then
		return ended-entryLength(subject)
	end
	return nil
end

local function endEpoch(subject)
	if type(subject)~="table"then
		return nil
	end
	local ended=A.stampEpoch(endedStamp(subject))
	if ended~=nil then
		return ended
	end
	local opened=A.stampEpoch(subject.openedAt)
	if opened==nil then
		return nil
	end
	return opened+entryLength(subject)
end

local function entryKey(entry)
	local subject=entry and entry.subject
	if type(subject)~="table"or subject.id==nil then
		return nil
	end
	if entry.kind=="incomplete"then
		return"i"..tostring(subject.id)
	end
	return subject.id
end
A.sessionEntryKey=entryKey

local function ownRow(record)
	local participants=type(record)=="table"and record.participants or nil
	if type(participants)~="table"or record.character==nil then
		return nil
	end
	local row=participants[record.character]
	return type(row)=="table"and row or nil
end

local function onOneLadder(record)
	return type(record)=="table"and A.movesRating(record.format)and A.oneLadder(record.format)
		and record.rated~=false
end

function A.recordLadderPair(record)
	if not onOneLadder(record)then
		return nil
	end
	local row=ownRow(record)
	if row==nil or A.ladderSilent(row)or type(row.rating)~="number"
		or type(row.ratingChange)~="number"then
		return nil
	end
	local change=row.ratingChange
	local out=row.rating+change
	if out<=0 then
		return nil
	end
	return row.rating,out,change
end

function A.recordMmrPair(record)
	if not onOneLadder(record)then
		return nil
	end
	local row=ownRow(record)
	if row==nil or A.ladderSilent(row)then
		return nil
	end
	local pre,post=row.mmrPre,row.mmrPost
	if type(pre)~="number"or type(post)~="number"or pre<=0 or post<=0 then
		return nil
	end
	return pre,post,post-pre
end

local function foldLadder(held,record,pairOf)
	local from,out=(pairOf or A.recordLadderPair)(record)
	if from==nil then
		return held,false
	end
	local made=held==nil
	if held==nil then
		held={to=out,character=record.character}
	end
	if record.character==held.character then
		held.from=from
	end
	return held,made
end

local function sessionLadders(entries)
	local order,by={},{}
	for i=1,#entries do
		local entry=entries[i]
		if entry.kind~="incomplete"then
			local record=entry.subject
			local held,made=foldLadder(by[record.format],record)
			if made and held~=nil then
				held.format=record.format
				by[record.format]=held
				order[#order+1]=held
			end
		end
	end
	for i=1,#order do
		order[i].change=order[i].to-order[i].from
	end
	return order
end

function A.buildSessions(entries)
	local sessions,unplaced={},0
	if type(entries)~="table"then
		return sessions,unplaced
	end
	local gap=SESSION_GAP_MINUTES*60
	local current,previousStart=nil,nil
	for i=1,#entries do
		local entry=entries[i]
		local subject=entry and entry.subject
		local started,ended=startEpoch(subject),endEpoch(subject)
		if started==nil or ended==nil then
			unplaced=unplaced+1
			current,previousStart=nil,nil
		else
			if current==nil or previousStart==nil or previousStart-ended>gap then
				current={entries={},endEpoch=ended,endStamp=endedStamp(subject)or A.stampAt(ended)}
				sessions[#sessions+1]=current
			end
			current.entries[#current.entries+1]=entry
			current.startEpoch=started
			current.startStamp=subject.openedAt or endedStamp(subject)
			current.key=entryKey(entry)
			previousStart=started
		end
	end
	for i=1,#sessions do
		local session=sessions[i]
		session.count=#session.entries
		local leftEarly=0
		for _,entry in ipairs(session.entries)do
			if entry.kind=="incomplete"then
				leftEarly=leftEarly+1
			end
		end
		session.leftEarly=leftEarly
		session.matches=session.count-leftEarly
		session.ladders=sessionLadders(session.entries)
	end
	return sessions,unplaced
end

function A.sessionNeighbours(kind,id,format,character)
	if id==nil or type(A.listEntries)~="function"then
		return nil,nil,nil
	end
	local want=kind=="incomplete"and"incomplete"or"match"
	local sessions=A.buildSessions((A.listEntries(format,character)))
	for s=1,#sessions do
		local list=sessions[s].entries
		for i=1,#list do
			local entry=list[i]
			if entry.kind==want and entry.subject.id==id then
				local before,after=nil,nil
				for j=i+1,#list do
					if list[j].kind=="match"then
						before=list[j]
						break
					end
				end
				for j=i-1,1,-1 do
					if list[j].kind=="match"then
						after=list[j]
						break
					end
				end
				return before,after,sessions[s]
			end
		end
	end
	return nil,nil,nil
end

function A.sessionsFlat(sessions)
	if type(sessions)~="table"then
		return true
	end
	for i=1,#sessions do
		if sessions[i].count>1 then
			return false
		end
	end
	return true
end

local function dayKeyNoon(key,shift)
	local y,m,d=tostring(key):match("^(%d+)%-(%d+)%-(%d+)$")
	if y==nil then
		return nil
	end
	local okAt,noon=pcall(time,{year=tonumber(y),month=tonumber(m),day=tonumber(d)+(shift or 0),
		hour=12})
	return okAt and type(noon)=="number"and noon or nil
end

local EVENING_HOUR=17

function A.sessionDayLabel(stamp,now)
	local key=A.dayKey(stamp)
	if key==nil then
		return nil
	end
	if type(now)=="number"then
		local okToday,today=pcall(date,"%Y-%m-%d",now)
		if okToday and today==key then
			local hour=tonumber(tostring(A.clockKey(stamp)):match("^(%d%d):"))
			return(hour~=nil and hour<EVENING_HOUR)and"Today"or"Tonight"
		end
		local okY,y,m,d=pcall(function()
			local text=date("%Y-%m-%d",now)
			return text:match("^(%d+)%-(%d+)%-(%d+)$")
		end)
		if okY and y then
			local okAt,noon=pcall(time,{year=tonumber(y),month=tonumber(m),day=tonumber(d),hour=12})
			if okAt and type(noon)=="number"then
				local okPrev,previous=pcall(date,"%Y-%m-%d",noon-86400)
				if okPrev and previous==key then
					return"Yesterday"
				end
			end
		end
	end
	return A.dayLabel(stamp)or key
end

function A.sessionDayForms(stamp,now)
	local long=A.sessionDayLabel(stamp,now)
	if long==nil then
		return nil
	end
	if long=="Today"or long=="Tonight"or long=="Yesterday"then
		return{long}
	end
	local forms={long}
	local noon=dayKeyNoon(A.dayKey(stamp))
	if noon~=nil then
		local okParts,weekday,day,month=pcall(function()
			return date("%a",noon),tonumber(date("%d",noon)),date("%b",noon)
		end)
		if okParts and type(day)=="number"then
			for _,short in ipairs({("%s %d %s"):format(weekday,day,month),("%d %s"):format(day,month)})do
				if short~=forms[#forms]then
					forms[#forms+1]=short
				end
			end
		end
	end
	return forms
end

local DAY_PARTS={
	{from=5,part="morning"},
	{from=12,part="afternoon"},
	{from=17,part="evening"},
	{from=21,part="night"},
}

function A.sessionDayParts()
	local out={}
	for i=1,#DAY_PARTS do
		out[i]={from=DAY_PARTS[i].from,part=DAY_PARTS[i].part}
	end
	return out
end

local function previousDayKey(key)
	local before=dayKeyNoon(key,-1)
	if before==nil then
		return nil
	end
	local okKey,previous=pcall(date,"%Y-%m-%d",before)
	return okKey and type(previous)=="string"and previous or nil
end

local function sessionDayPart(stamp)
	local key=A.dayKey(stamp)
	local hour=tonumber(tostring(A.clockKey(stamp)):match("^(%d%d):"))
	if key==nil or hour==nil or dayKeyNoon(key)==nil then
		return nil
	end
	if hour<DAY_PARTS[1].from then
		local previous=previousDayKey(key)
		return previous,previous~=nil and"night"or nil
	end
	local part=DAY_PARTS[1].part
	for i=1,#DAY_PARTS do
		if hour>=DAY_PARTS[i].from then
			part=DAY_PARTS[i].part
		end
	end
	return key,part
end

function A.shortDayForms(stamp)
	local day=A.shortDay(stamp)
	if day==nil then
		return nil
	end
	local forms={day}
	local bare=day:match("^%a+ (%d+ %a+)$")
	if bare~=nil then
		forms[2]=bare
	end
	return forms
end

function A.sessionHeadForms(stamp)
	local key=sessionDayPart(stamp)
	if key==nil then
		return nil
	end
	return A.shortDayForms(key)
end

local function gridLabelForms(stamp,earlier)
	local forms=A.sessionHeadForms(stamp)
	if forms==nil then
		return nil
	end
	local _,part=sessionDayPart(stamp)
	local said=(earlier and"earlier "or"")..part
	local out={}
	for i=1,#forms do
		out[i]=forms[i]..", "..said
	end
	return out
end

function A.sessionGridLabelForms(stamp)
	return gridLabelForms(stamp,false)
end

function A.sessionHeadList(sessions)
	local out={}
	for _,session in ipairs(type(sessions)=="table"and sessions or{})do
		out[session]=A.sessionHeadForms(session.startStamp)or{}
	end
	return out
end

function A.sessionGridLabelList(sessions)
	local heads=A.sessionHeadList(sessions)
	local out,seen,earlier={},{},0
	for _,session in ipairs(type(sessions)=="table"and sessions or{})do
		local day,part=sessionDayPart(session.startStamp)
		local key=day~=nil and(day.." "..part)or nil
		local taken=key~=nil and seen[key]==true
		local forms=gridLabelForms(session.startStamp,taken)
		if taken and forms~=nil then
			earlier=earlier+1
		end
		if key~=nil then
			seen[key]=true
		end
		out[session]=forms or heads[session]or{}
	end
	return out,earlier
end

function A.sessionSpanText(session)
	if type(session)~="table"then
		return nil
	end
	local from=A.clockWords(session.startStamp)or A.clockWords(session.startEpoch)
	local to=A.clockWords(session.endEpoch)
	if from==nil then
		return to
	end
	if to==nil or to==from then
		return from
	end
	return from.." - "..to
end

function A.seasonPart(newer,older,crossed)
	if type(newer)~="table"or type(older)~="table"then
		return nil
	end
	if type(newer.gameSeason)=="number"and type(older.gameSeason)=="number"then
		return newer.gameSeason~=older.gameSeason and"season"or nil
	end
	if type(newer.season)=="number"and type(older.season)=="number"then
		if newer.season~=older.season then
			return"season"
		end
		local measured,other=newer,older
		if type(measured.gameSeason)~="number"then
			measured,other=older,newer
		end
		if type(measured.gameSeason)=="number"then
			return A.outsideGameSeason(other,measured.season,measured.gameSeason)and"season"or nil
		end
		return nil
	end
	local newerSeason=type(A.recordSeason)=="function"and A.recordSeason(newer)or nil
	local olderSeason=type(A.recordSeason)=="function"and A.recordSeason(older)or nil
	if newerSeason~=nil and olderSeason~=nil then
		return newerSeason~=olderSeason and"season"or nil
	end
	if not crossed or newer.format~=older.format or newer.character~=older.character then
		return nil
	end
	local newerFrom=A.recordLadderPair(newer)
	local _,olderOut=A.recordLadderPair(older)
	if newerFrom==0 and type(olderOut)=="number"and olderOut>0 then
		return"rating"
	end
	return nil
end

function A.withSeasonBreaks(rows,rowEntries,selectedAt,lineRecords)
	if type(rows)~="table"or type(rowEntries)~="table"then
		return rows,rowEntries,selectedAt
	end
	lineRecords=type(lineRecords)=="table"and lineRecords or{}
	local out,entries,at={},{},nil
	local previous=nil
	local crossed=false
	for i=1,#rows do
		local entry=rowEntries[i]
		local line=lineRecords[i]
		local record=entry~=nil and entry.kind~="incomplete"and entry.subject or nil
		local oldest=record
		if record==nil and type(line)=="table"and type(line.newest)=="table"then
			record,oldest=line.newest,type(line.oldest)=="table"and line.oldest or line.newest
		end
		if type(rows[i])=="table"and rows[i].separator then
			crossed=true
		end
		local newer=previous
		if record~=nil and newer~=nil then
			local part=A.seasonPart(newer.record,record,crossed)
			if part~=nil then
				local text=type(A.seasonText)=="function"and A.seasonText(record,true)or nil
				table.insert(out,newer.index+1,{
					separator=true,
					seasonBreak=true,
					seasonPart=part,
					text=text and text:upper()or"PREVIOUS SEASON",
					height=A.metric("rowHeadRow"),
				})
				for k=#out,newer.index+2,-1 do
					entries[k]=entries[k-1]
				end
				entries[newer.index+1]=nil
				if at~=nil and at>newer.index then
					at=at+1
				end
			end
		end
		out[#out+1]=rows[i]
		entries[#out]=entry
		if selectedAt==i then
			at=#out
		end
		if record~=nil then
			previous={record=oldest,index=#out}
			crossed=false
		end
	end
	return out,entries,at
end

local GRID_FORMATS={"shuffle","blitz","arena2","arena3","rbg"}
local GRID_NAMES={
	shuffle="SOLO SHUFFLE",
	blitz="BLITZ",
	arena2="ARENA (2V2)",
	arena3="ARENA (3V3)",
	rbg="RATED BG",
	arena="ARENA",
}

local MMR_ORDER={}
for i=1,#GRID_FORMATS do
	MMR_ORDER[i]=GRID_FORMATS[i]
end
MMR_ORDER[#MMR_ORDER+1]="arena"

local GRID_COLUMNS_MAX=4

local GRID_TICKS_MAX=20

function A.sessionGridCaps()
	return GRID_TICKS_MAX,GRID_COLUMNS_MAX
end

function A.sessionGridName(format)
	return GRID_NAMES[format]or(A.formatLabel(format)or tostring(format)):upper()
end

local function gridFormatOf(entry)
	if type(entry)~="table"or entry.kind=="incomplete"then
		return nil
	end
	local record=entry.subject
	if type(record)~="table"or record.rated==false or GRID_NAMES[record.format]==nil then
		return nil
	end
	return record.format
end

function A.sessionGridFormats(entries)
	local present={}
	for _,entry in ipairs(type(entries)=="table"and entries or{})do
		local format=gridFormatOf(entry)
		if format~=nil then
			present[format]=true
		end
	end
	local held={}
	for _,format in ipairs(GRID_FORMATS)do
		if present[format]then
			held[#held+1]=format
		end
	end
	if#held<=GRID_COLUMNS_MAX then
		return held,{}
	end
	local shown,rest={},{}
	for i=1,#held do
		if i<GRID_COLUMNS_MAX then
			shown[#shown+1]=held[i]
		else
			rest[#rest+1]=held[i]
		end
	end
	return shown,rest
end

function A.sessionGridCell(listed,format)
	local matches,held=0,nil
	for _,entry in ipairs(type(listed)=="table"and listed or{})do
		if gridFormatOf(entry)==format then
			matches=matches+1
			held=foldLadder(held,entry.subject)
		end
	end
	if matches==0 then
		return nil
	end
	local from,to=held and held.from or nil,held and held.to or nil
	return{format=format,matches=matches,from=from,to=to,
		change=(to~=nil and from~=nil)and(to-from)or nil}
end

function A.sessionGridCellText(cell)
	if type(cell)~="table"then
		return nil
	end
	if cell.to==nil then
		return A.colorEscape("dim").."-|r"
	end
	local rating=A.tierRatingText(cell.format,cell.to,"bright")
	if cell.change==nil or cell.change==0 then
		return rating
	end
	local tone=cell.change>0 and"win"or"loss"
	return("%s %s%s|r"):format(rating,A.colorEscape(tone),A.signedText(cell.change))
end

function A.sessionGridHoverLine(cell)
	if type(cell)~="table"then
		return nil
	end
	local count=("%d %s"):format(cell.matches,cell.matches==1 and"match"or"matches")
	if cell.to==nil then
		return count
	end
	return("%d to %d %s, %s"):format(cell.from,cell.to,A.signedText(cell.change)or"0",count)
end

function A.sessionMmrCell(listed,format)
	local by,any={},false
	for _,entry in ipairs(type(listed)=="table"and listed or{})do
		local played=gridFormatOf(entry)
		if played~=nil and(format==nil or played==format)then
			local cell=by[played]or{format=played,matches=0}
			cell.matches=cell.matches+1
			cell.held=foldLadder(cell.held,entry.subject,A.recordMmrPair)
			by[played],any=cell,true
		end
	end
	if not any then
		return nil
	end
	local out={format=format,formats={},read=0}
	for _,played in ipairs(MMR_ORDER)do
		local cell=by[played]
		if cell~=nil then
			local held=cell.held
			local from,to=held and held.from or nil,held and held.to or nil
			local change=(from~=nil and to~=nil)and(to-from)or nil
			out.formats[#out.formats+1]={format=played,matches=cell.matches,from=from,to=to,
				change=change}
			if change~=nil then
				out.read=out.read+1
				out.to,out.change=to,change
			end
		end
	end
	if out.read~=1 then
		out.to,out.change=nil,nil
	end
	return out
end

function A.sessionMmrCellText(cell)
	if type(cell)~="table"then
		return nil
	end
	if(cell.read or 0)>1 then
		return("%s%d formats|r"):format(A.colorEscape("dim"),cell.read)
	end
	if cell.to==nil or cell.change==nil then
		return A.colorEscape("dim").."-|r"
	end
	if cell.change==0 then
		return("%d"):format(cell.to)
	end
	local tone=cell.change>0 and"win"or"loss"
	return("%d %s%s|r"):format(cell.to,A.colorEscape(tone),A.signedText(cell.change))
end

function A.sessionMmrHoverLines(cell)
	if type(cell)~="table"then
		return nil
	end
	if(cell.read or 0)==0 then
		return{"no MMR read"}
	end
	local lines={}
	for _,held in ipairs(cell.formats)do
		local line=A.sessionGridHoverLine(held)
		lines[#lines+1]=cell.format~=nil and line or(A.sessionGridName(held.format).."  "..line)
	end
	return lines
end

function A.sessionMmrHeadLines()
	return{"MMR at the end of the session, and how far it moved"}
end

function A.sessionTickTone(entry)
	if type(entry)~="table"then
		return"dim"
	end
	if entry.kind=="incomplete"then
		return"caveat"
	end
	return A.resultTone(entry.subject)or"dim"
end

function A.sessionTicks(listed)
	local tones={}
	listed=type(listed)=="table"and listed or{}
	for i=#listed,1,-1 do
		tones[#tones+1]=A.sessionTickTone(listed[i])
	end
	local over=math.max(0,#tones-GRID_TICKS_MAX)
	if over==0 then
		return tones,0
	end
	local kept={}
	for i=over+1,#tones do
		kept[#kept+1]=tones[i]
	end
	return kept,over
end

function A.sessionGridSummaryName(format)
	if format==nil then
		return nil
	end
	return format=="shuffle"and"ROUNDS"or"RECORD"
end

function A.sessionGridSummary(listed,format)
	local out={kind="matches",won=0,lost=0,any=false,out=0,counted=0,shuffles=0}
	if format=="shuffle"then
		out.kind="rounds"
	elseif format=="world"then
		out.kind="kills"
	end
	for _,entry in ipairs(type(listed)=="table"and listed or{})do
		local record=entry.kind~="incomplete"and entry.subject or nil
		if type(record)=="table"then
			if out.kind=="rounds"then
				local verdict,won,played=A.roundsVerdict(record)
				out.shuffles=out.shuffles+1
				if verdict==nil or verdict=="unsummed"then
					out.out=out.out+1
				else
					out.won,out.lost,out.any=out.won+won,out.lost+(played-won),true
					out.counted=out.counted+1
				end
			elseif out.kind=="kills"then
				local kills,deaths=A.worldCounts(record)
				if kills~=nil and deaths~=nil then
					out.won,out.lost,out.any=out.won+kills,out.lost+deaths,true
				end
			else
				local tone=A.resultTone(record)
				if tone=="win"then
					out.won,out.any=out.won+1,true
				elseif tone=="loss"then
					out.lost,out.any=out.lost+1,true
				end
			end
		end
	end
	if out.kind=="matches"and not out.any then
		for _,entry in ipairs(type(listed)=="table"and listed or{})do
			if entry.kind~="incomplete"then
				out.any=true
				break
			end
		end
	end
	return out
end

function A.sessionGridSummaryPartial(summary)
	return type(summary)=="table"and summary.kind=="rounds"and summary.any==true
		and(summary.out or 0)>0 and(summary.counted or 0)>0
end

function A.sessionGridSummaryHover(summary)
	if not A.sessionGridSummaryPartial(summary)then
		return nil
	end
	return("%d-%d over %d of %d matches"):format(summary.won,summary.lost,summary.counted,
		summary.shuffles)
end

function A.sessionGridSummaryText(summary)
	if type(summary)~="table"or not summary.any then
		return A.colorEscape("dim").."-|r"
	end
	local tone=summary.won>summary.lost and"win"or summary.won<summary.lost and"loss"or"dim"
	if A.sessionGridSummaryPartial(summary)then
		tone="dim"
	end
	local text=("%s%d-%d|r"):format(A.colorEscape(tone),summary.won,summary.lost)
	if summary.kind=="rounds"then
		text=text..A.colorEscape("dim").." rds|r"
	end
	return text
end

function A.sessionColumnNeed(labelNeed,caretWidth)
	if type(labelNeed)~="number"or labelNeed<=0 then
		return nil
	end
	local caret=type(caretWidth)=="number"and caretWidth or A.fontSize("label")
	return math.ceil(labelNeed+caret+A.metric("rowCellGap")+2)
end

local function sessionFigureText(column,listed,rest,format)
	if column.key=="format"then
		local text=A.sessionGridCellText(A.sessionGridCell(listed,column.format))
		if text==nil and format~=nil then
			return A.colorEscape("dim").."-|r"
		end
		return text
	elseif column.key=="summary"then
		return A.sessionGridSummaryText(A.sessionGridSummary(listed,format))
	elseif column.key=="mmr"then
		return A.sessionMmrCellText(A.sessionMmrCell(listed,format))
	elseif column.key=="more"then
		local played=0
		for _,other in ipairs(rest)do
			if A.sessionGridCell(listed,other)~=nil then
				played=played+1
			end
		end
		return played>0 and("+%d"):format(played)or nil
	end
	return nil
end

function A.sessionFigureNeeds(columns,rest,sessions,format,face)
	local needs={}
	for _,column in ipairs(columns)do
		local id
		if column.key=="format"then
			id="format:"..tostring(column.format)
		elseif column.key=="more"or column.key=="summary"or column.key=="mmr"then
			id=column.key
		end
		if id~=nil then
			for _,listed in ipairs(sessions)do
				local text=sessionFigureText(column,listed,rest or{},format)
				if type(text)=="string"then
					text=text:gsub("|c%x%x%x%x%x%x%x%x",""):gsub("|r","")
					local width=A.clientTextWidth(face,text)
					if width~=nil and(needs[id]==nil or width>needs[id])then
						needs[id]=width
					end
				end
			end
		end
	end
	return needs
end

function A.sessionGrid(entries,room,format,sessionWidth,needs)
	local shown,rest={},{}
	if format==nil then
		shown,rest=A.sessionGridFormats(entries)
	end
	local summaryName=A.sessionGridSummaryName(format)
	local rated=format~=nil and A.movesRating(format)
	needs=type(needs)=="table"and needs or{}
	local function fixed(metric,name,need)
		return math.max(A.metric(metric),A.headerFloor(name),need or 0)
	end
	local function build(fold)
		local columns={{key="session",name="SESSION",
			width=math.max(fixed("gridSession","SESSION"),sessionWidth or 0)}}
		if not fold then
			columns[#columns+1]={key="time",name="TIME",
				width=fixed("gridTime","TIME")+2*A.clockExtra()}
		end
		for _,played in ipairs(shown)do
			local name=A.sessionGridName(played)
			columns[#columns+1]={key="format",format=played,name=name,
				width=fixed("gridFormat",name,needs["format:"..played])}
		end
		if#rest>0 then
			local name=("+%d"):format(#rest)
			columns[#columns+1]={key="more",name=name,width=fixed("gridFormat",name,needs.more)}
		end
		if rated then
			columns[#columns+1]={key="format",format=format,name="RATING",
				width=fixed("gridRating","RATING",needs["format:"..format])}
		end
		columns[#columns+1]={key="results",name="RESULTS",width=0}
		if summaryName~=nil then
			columns[#columns+1]={key="summary",name=summaryName,
				width=fixed("gridRecord",summaryName,needs.summary)}
		end
		if#shown>0 or#rest>0 or rated then
			columns[#columns+1]={key="mmr",name="MMR",width=fixed("gridMmr","MMR",needs.mmr)}
		end
		columns[#columns+1]={key="matches",name="MATCHES",align="RIGHT",
			width=fixed("gridMatches","MATCHES")}
		local used=A.metric("rowLabelPad")*2+A.metric("rowCellGap")*(#columns-1)
		for i=1,#columns do
			used=used+columns[i].width
		end
		local floor=fixed("gridResultsFloor","RESULTS")
		local left=type(room)=="number"and(room-used)or floor
		for i=1,#columns do
			if columns[i].key=="results"then
				columns[i].width=math.max(0,math.floor(left))
			end
		end
		return columns,left>=floor
	end
	local columns,fits=build(false)
	if fits then
		return columns,rest,false
	end
	columns=build(true)
	return columns,rest,true
end

function A.worldSessionGrid(columns,sessionWidth)
	if type(columns)~="table"then
		return nil
	end
	local widthOf={}
	for _,column in ipairs(columns)do
		if column.key~=nil then
			widthOf[column.key]=(type(column.width)=="number"and column.width>0)and column.width
				or A.metric(column.metric)
		end
	end
	for _,key in ipairs({"id","time","where","tally","ratio","span"})do
		if widthOf[key]==nil then
			return nil
		end
	end
	local outing=widthOf.id
	if widthOf.pick~=nil then
		outing=outing+widthOf.pick+A.metric("rowCellGap")
	end
	local shared=widthOf.time+A.metric("rowCellGap")+widthOf.where
	local session=math.min(math.max(A.metric("gridSession"),outing,sessionWidth or 0),
		outing+shared-1)
	local time=shared-(session-outing)
	return{
		{key="session",name="SESSION",width=session},
		{key="time",name="TIME",width=time},
		{key="tally",name="KILLS AND DEATHS",width=widthOf.tally},
		{key="ratio",name="K/D",width=widthOf.ratio,align="RIGHT"},
		{key="matches",name="OUTINGS",width=widthOf.span,align="RIGHT"},
	}
end

function A.worldSessionTally(listed)
	local out={kills=0,deaths=0,tallied=0}
	for _,entry in ipairs(type(listed)=="table"and listed or{})do
		local kills,deaths=A.worldCounts(entry.kind~="incomplete"and entry.subject or nil)
		if kills~=nil and deaths~=nil then
			out.kills,out.deaths,out.tallied=out.kills+kills,out.deaths+deaths,out.tallied+1
		end
	end
	return out.tallied>0 and out or nil
end

local function storedFolds()
	local db=A.db and A.db()
	local folds=db and db.ui and db.ui.sessionFolds
	return type(folds)=="table"and folds or nil
end

local heldFolds={}

function A.holdSessionOpen(key,open)
	if key~=nil then
		heldFolds[key]=open==true
	end
end

function A.dropHeldSessionFolds()
	heldFolds={}
end

function A.sessionOpen(key,newest)
	if key~=nil and type(heldFolds[key])=="boolean"then
		return heldFolds[key],"held"
	end
	local folds=storedFolds()
	local held=nil
	if folds~=nil and key~=nil then
		held=folds[key]
	end
	if type(held)=="boolean"then
		return held,"stored"
	end
	return newest==true,"default"
end

function A.setSessionOpen(key,open,newest)
	if key==nil then
		return nil
	end
	local db=A.db and A.db()
	if not(db and db.ui)then
		return nil
	end
	heldFolds[key]=nil
	open=open==true
	local default=newest==true
	local ui=db.ui
	if open==default then
		local folds=ui.sessionFolds
		if type(folds)=="table"then
			folds[key]=nil
			if next(folds)==nil then
				ui.sessionFolds=nil
			end
		end
	else
		ui.sessionFolds=type(ui.sessionFolds)=="table"and ui.sessionFolds or{}
		ui.sessionFolds[key]=open
	end
	return open
end

function A.toggleSession(key,newest)
	local open=A.sessionOpen(key,newest)
	return A.setSessionOpen(key,not open,newest)
end

function A.pruneSessionFolds()
	local db=A.db and A.db()
	local folds=db and db.ui and db.ui.sessionFolds
	if type(folds)~="table"then
		return 0
	end
	local matches,unfinished={},{}
	for _,record in ipairs(type(db.matches)=="table"and db.matches or{})do
		if type(record)=="table"and record.id~=nil then
			matches[record.id]=true
		end
	end
	for _,entry in ipairs(type(db.incomplete)=="table"and db.incomplete or{})do
		if type(entry)=="table"and entry.id~=nil then
			unfinished["i"..tostring(entry.id)]=true
		end
	end
	local gone={}
	for key in pairs(folds)do
		local held=matches[key]or(type(key)=="string"and unfinished[key])
		if not held then
			gone[#gone+1]=key
		end
	end
	for i=1,#gone do
		folds[gone[i]]=nil
	end
	if next(folds)==nil then
		db.ui.sessionFolds=nil
	end
	return#gone
end

local heldScoped={}

local function seasonHolds(subject,season,where)
	if season==nil then
		return true
	end
	local ok,inSeason=pcall(A.recordInSeason,subject,season)
	if not ok then
		A.noteError(inSeason,where)
	end
	return ok and inSeason
end

local function walkScoped(format,season,character,bound)
	local out={}
	local list=A.matches(format,character)
	for i=1,#list do
		local record=list[i]
		if seasonHolds(record,season,"season-walk")and A.recordSince(record,bound)then
			out[#out+1]=record
		end
	end
	return out
end

local function scopedRecords(format,season,character,bound)
	local mark=A.storeMark()
	local seasons=mark.db and mark.db.seasons
	local declared=type(seasons)=="table"and#seasons or 0
	local generation=type(A.seasonGeneration)=="function"and A.seasonGeneration()or 0
	if not(A.storeMarkSame(heldScoped.mark,mark)and heldScoped.seasons==seasons
		and heldScoped.declared==declared and heldScoped.generation==generation)then
		heldScoped={mark=mark,seasons=seasons,declared=declared,generation=generation,lists={}}
	end
	local key=table.concat({tostring(format),tostring(season),tostring(character),tostring(bound)},"|")
	local list=heldScoped.lists[key]
	if list==nil then
		list=walkScoped(format,season,character,bound)
		heldScoped.lists[key]=list
	end
	local out={}
	for i=1,#list do
		out[i]=list[i]
	end
	return out
end

function A.standingShape(format)
	if format==nil then
		return"all"
	end
	if A.movesRating(format)and A.oneLadder(format)then
		return"rated"
	end
	return"ladderless"
end

local DUEL_SQUARES=10

local function pairText(wins,losses)
	return("%d-%d"):format(wins or 0,losses or 0)
end

function A.duelReading(records,character,season,bound)
	local hero={wins=0,losses=0,duels=#records,
		knockout={wins=0,losses=0},fled={wins=0,losses=0},squares={}}
	for i=1,#records do
		local record=records[i]
		local verdict=A.recordVerdict(record)
		local row=record.outcome=="knockout"and hero.knockout
			or record.outcome=="retreat"and hero.fled or nil
		if verdict=="win"then
			hero.wins=hero.wins+1
			if row then
				row.wins=row.wins+1
			end
		elseif verdict=="loss"then
			hero.losses=hero.losses+1
			if row then
				row.losses=row.losses+1
			end
		end
	end
	local decided=hero.wins+hero.losses
	hero.rate=decided>0 and hero.wins/decided or nil
	hero.record=pairText(hero.wins,hero.losses)
	hero.knockout.text=pairText(hero.knockout.wins,hero.knockout.losses)
	hero.fled.text=pairText(hero.fled.wins,hero.fled.losses)
	for i=1,#records do
		if#hero.squares>=DUEL_SQUARES then
			break
		end
		local tone=A.resultTone(records[i])
		if tone~=nil then
			table.insert(hero.squares,1,tone)
		end
	end

	local tally=A.opponentTally("duel",character,season,bound)
	hero.opponents=tally
	hero.players=#tally
	local keys={}
	hero.resolved,hero.nameOnly=0,0
	for _,row in ipairs(tally)do
		if row.key~=nil then
			keys[row.key]=true
			hero.resolved=hero.resolved+1
		else
			hero.nameOnly=hero.nameOnly+1
		end
	end
	hero.classes=A.classTokens(keys)

	local last=records[1]
	if last then
		local bare,realm=A.nameParts(last.opponentName)
		local key=A.duelOpponentKey(last)
		local stamp=last.completedAt or last.openedAt
		local verdict=A.recordVerdict(last)
		local how,parts={},{A.duelHow(last),last.map and last.map.name or nil,A.lengthText(last.duration)}
		for i=1,3 do
			if type(parts[i])=="string"and parts[i]~=""then
				how[#how+1]=parts[i]
			end
		end
		local day=A.shortDay(stamp)
		local clock=day and A.clockWords(stamp)
		hero.last={
			result=verdict=="win"and"won"or verdict=="loss"and"lost"or nil,
			tone=A.resultTone(last),
			name=bare~=""and bare or nil,
			realm=A.realmDrawn(realm),
			classToken=key and hero.classes[key]or nil,
			how=#how>0 and table.concat(how,", ")or nil,
			when=(day and clock)and(day.." "..clock)or nil,
		}
	end
	return hero
end

function A.otherReading(records,entries)
	local hero={others=#records,wins=0,losses=0,leftEarly=#entries,unset=0,reasons={}}
	for i=1,#records do
		local verdict=A.recordVerdict(records[i])
		if verdict=="win"then
			hero.wins=hero.wins+1
		elseif verdict=="loss"then
			hero.losses=hero.losses+1
		end
	end
	hero.record=pairText(hero.wins,hero.losses)
	local counts={}
	local newest,newestMap=nil,nil
	local function consider(stamp,map)
		if type(stamp)=="string"and(newest==nil or stamp>newest)then
			newest,newestMap=stamp,map
		end
	end
	for i=1,#entries do
		local entry=entries[i]
		local token=type(entry.manual)=="table"and entry.manual.reason or nil
		if token==nil then
			hero.unset=hero.unset+1
		else
			counts[token]=(counts[token]or 0)+1
		end
		consider(entry.openedAt or entry.endedAt,entry.map and entry.map.name)
	end
	for i=1,#records do
		consider(records[i].openedAt or records[i].completedAt,records[i].map and records[i].map.name)
	end
	for _,token in ipairs(A.manualReasons())do
		if counts[token]then
			hero.reasons[#hero.reasons+1]={label=A.reasonLabel(token),count=counts[token]}
		end
	end
	if hero.unset>0 then
		hero.reasons[#hero.reasons+1]={label="Not set",count=hero.unset,unset=true}
	end
	if newest then
		hero.lastForms=A.shortDayForms(newest)
		hero.lastPlayed=hero.lastForms and hero.lastForms[1]or nil
		local clock=A.clockWords(newest)
		hero.lastSub=clock and newestMap and(clock..", "..newestMap)or clock
	end
	return hero
end

local WORLD_TREND=20

function A.worldReading(records)
	records=type(records)=="table"and records or{}
	local hero={kind="world",outings=#records,kills=0,deaths=0,tallied=0,bars={},
		seconds=0,timed=0}
	local best=nil
	for i=1,#records do
		local record=records[i]
		local kills,deaths=A.worldCounts(record)
		if kills~=nil and deaths~=nil then
			hero.kills,hero.deaths,hero.tallied=hero.kills+kills,hero.deaths+deaths,hero.tallied+1
			local margin=kills-deaths
			if best==nil or margin>best.margin or(margin==best.margin and kills>best.kills)then
				best={margin=margin,kills=kills,deaths=deaths,zone=A.recordZone(record)}
			end
		end
		local seconds=A.recordSeconds(record)
		if seconds~=nil then
			hero.seconds,hero.timed=hero.seconds+seconds,hero.timed+1
		end
	end
	for i=1,#records do
		if#hero.bars>=WORLD_TREND then
			break
		end
		local kills,deaths=A.worldCounts(records[i])
		if kills~=nil and deaths~=nil then
			table.insert(hero.bars,1,{kills=kills,deaths=deaths})
		end
	end
	hero.ratio=hero.tallied>0 and A.kdText(hero.kills,hero.deaths)or nil
	hero.ratioTone=hero.tallied>0 and A.kdTone(hero.kills,hero.deaths)or"dim"
	if best~=nil then
		hero.best=("best %d-%d"):format(best.kills,best.deaths)
		if best.zone~=nil then
			hero.best=hero.best..", "..best.zone
		end
	end
	hero.timeOut=hero.timed>0 and A.totalTimeText(hero.seconds)or nil
	hero.average=hero.timed>0 and("avg "..A.lengthText(math.floor(hero.seconds/hero.timed+0.5)))or nil
	local last=records[1]
	local stamp=last and(last.openedAt or last.completedAt)or nil
	if stamp~=nil then
		hero.lastForms=A.shortDayForms(stamp)
		hero.lastOut=hero.lastForms and hero.lastForms[1]or nil
		local parts={}
		local zone=A.recordZone(last)
		if zone~=nil then
			parts[#parts+1]=zone
		end
		if type(last.duration)=="number"then
			parts[#parts+1]=A.lengthText(last.duration)
		end
		hero.lastSub=#parts>0 and table.concat(parts,", ")or nil
	end
	return hero
end

function A.seasonHigh(format,season,character)
	local high=nil
	for _,record in ipairs(scopedRecords(format,season,character,nil))do
		local from,out=A.recordLadderPair(record)
		if from~=nil then
			local top=math.max(from,out)
			if high==nil or top>high then
				high=top
			end
		end
	end
	return high
end

local function trendBars(records,newestKeys)
	local bars={}
	local first=math.min(#records,TREND_COUNT)
	for i=first,1,-1 do
		local record=records[i]
		local _,_,change=A.recordLadderPair(record)
		bars[#bars+1]={
			id=record.id,
			change=change,
			tone=A.resultTone(record),
			day=A.dayKey(record.openedAt or record.completedAt),
			newest=newestKeys[record.id]==true,
		}
	end
	return bars
end

function A.standingReading(format,season,character,bound,summary,_,listed)
	summary=type(summary)=="table"and summary or A.summarize(format,season,character,bound)
	local shape=A.standingShape(format)
	local records=scopedRecords(format,season,character,bound)
	local entries={}
	for i=1,#records do
		entries[i]={kind="match",subject=records[i]}
	end
	local sessions=A.buildSessions(entries)
	local newestKeys={}
	if sessions[1]then
		for _,entry in ipairs(sessions[1].entries)do
			if entry.subject.id~=nil then
				newestKeys[entry.subject.id]=true
			end
		end
	end
	local reading={shape=shape,format=format,season=season,matches=#records}

	local stripSeason=season
	for i=1,#records do
		if stripSeason~=nil then
			break
		end
		local ok,resolved=pcall(A.recordSeason,records[i])
		stripSeason=ok and resolved or nil
	end
	reading.stripSeason=stripSeason
	local avg=A.wholeAvgDuration(summary)
	local avgText=avg and("avg "..A.clockText(avg))or nil

	if shape=="rated"then
		reading.label=A.formatLabel(format):upper()
		if stripSeason~=nil then
			reading.label=reading.label.."  "..("Season %d"):format(stripSeason):upper()
		end
		reading.rating=summary.rating
		local ladder=sessions[1]and sessions[1].ladders and sessions[1].ladders[1]or nil
		reading.sessionChange=ladder and ladder.change or nil
		local highCharacter=character
		if highCharacter==nil then
			for i=1,#records do
				if A.recordLadderPair(records[i])~=nil then
					highCharacter=records[i].character
					break
				end
			end
		end
		reading.high=A.seasonHigh(format,stripSeason,highCharacter)
		local bars,moved=trendBars(records,newestKeys),0
		for i=1,#bars do
			if bars[i].change~=nil then
				moved=moved+1
			end
		end
		reading.bars=moved>=2 and bars or{}
		local wins,losses,_,rate=A.winRecord(summary)
		local peak=type(summary.peak)=="number"and math.floor(summary.peak)or nil
		if peak~=nil and(reading.high==nil or peak>reading.high)then
			reading.peak=peak
		end
		if format=="shuffle"then
			local parts={}
			if summary.roundsPlayed and summary.roundsPlayed>0 then
				parts[#parts+1]=("%d-%d rounds"):format(summary.roundsWon,summary.roundsPlayed-summary.roundsWon)
			end
			if wins~=nil then
				parts[#parts+1]=("%d-%d matches"):format(wins,losses)
			end
			reading.figures={
				{label="ROUNDS WON",value=A.percentText(summary.roundRate),
					sub=#parts>0 and table.concat(parts,", ")or nil,
					tone=A.winRateTone(summary.roundRate)},
			}
		else
			reading.figures={
				{label="WIN RATE",value=A.percentText(rate),sub=A.winRecordText(summary,format),
					tone=A.winRateTone(rate)},
			}
		end
		local gap=summary.mmrGap
		local gapTone="dim"
		if type(gap)=="number"and gap>0 then
			gapTone="win"
		elseif type(gap)=="number"and gap<0 then
			gapTone="loss"
		end
		reading.figures[2]={label="MATCHES",value=tostring(summary.matches or 0),sub=avgText,
			tone="text"}
		if summary.mmr==nil then
			reading.figures[3]={label="MMR GAP",value="-",sub="no MMR read",tone="dimmer",
				subTone="dimmer"}
		else
			reading.figures[3]={label="MMR GAP",value=A.signedText(gap),
				sub="MMR "..tostring(summary.mmr),tone=gapTone}
		end
	elseif shape=="all"then
		local tiles={}
		local formats=type(A.ratedFormats)=="function"and A.ratedFormats()or{}
		local seasonRecords=scopedRecords(nil,stripSeason,character,nil)
		local newestFormats={}
		local newestLadders={}
		if sessions[1]then
			for _,ladder in ipairs(sessions[1].ladders or{})do
				newestFormats[ladder.format]=true
				newestLadders[ladder.format]=ladder.change
			end
		end
		for _,rated in ipairs(formats)do
			local newest=nil
			for _,record in ipairs(seasonRecords)do
				if record.format==rated then
					local _,out=A.recordLadderPair(record)
					if out~=nil then
						newest=out
						break
					end
				end
			end
			if newest~=nil then
				tiles[#tiles+1]={
					format=rated,
					label=A.formatLabel(rated):upper(),
					rating=newest,
					change=newestLadders[rated],
					played=newestFormats[rated]==true,
				}
			end
		end
		reading.tiles=tiles
		local wins,losses,draws,rate=A.winRecord(summary)
		local sub={}
		local record=A.winRecordText(summary,format)
		if record~=nil then
			sub[#sub+1]=record
		end
		local count=type(summary.matches)=="number"and summary.matches or nil
		if count~=nil and count>0 and(wins==nil or wins+losses+draws~=count)then
			sub[#sub+1]=("%d %s"):format(count,count==1 and"match"or"matches")
		end
		if avgText~=nil then
			sub[#sub+1]=avgText
		end
		reading.figures={
			{label="WIN RATE",value=A.percentText(rate),sub=#sub>0 and table.concat(sub,", ")or nil,
				tone=A.winRateTone(rate)},
		}
	else
		local rate=select(4,A.winRecord(summary))
		reading.record=A.winRecordText(summary,format)
		if reading.record==nil and#records>0 then
			reading.record=("%d %s"):format(#records,#records==1 and"match"or"matches")
			reading.recordKind="matches"
		end
		reading.rate=A.percentText(rate)
		reading.rateTone=A.winRateTone(rate)
		local bars={}
		for _,bar in ipairs(trendBars(records,newestKeys))do
			if bar.tone~=nil then
				bars[#bars+1]=bar
			end
		end
		reading.bars=bars
		local last=records[1]
		local lastStamp=last and(last.openedAt or last.completedAt)or nil
		local lastForms=lastStamp and A.shortDayForms(lastStamp)or nil
		local matchesSub=avgText
		if summary.mmr~=nil then
			matchesSub=(avgText and(avgText..", ")or"").."MMR "..tostring(summary.mmr)
		end
		reading.figures={
			{label="MATCHES",value=tostring(summary.matches or 0),
				sub=matchesSub},
			{label="LAST PLAYED",value=lastForms and lastForms[1]or"-",forms=lastForms,
				sub=lastStamp and A.clockWords(lastStamp)or nil},
		}
		if format=="world"then
			reading.hero=A.worldReading(type(listed)=="table"and listed or records)
		elseif format=="duel"then
			reading.hero=A.duelReading(records,character,season,bound)
			reading.hero.kind="duel"
		elseif format=="unknown"then
			local left={}
			local ok,held=pcall(A.incompleteList,character)
			for _,entry in ipairs(ok and type(held)=="table"and held or{})do
				if seasonHolds(entry,season,"season-left-early")and A.recordSince(entry,bound)then
					left[#left+1]=entry
				end
			end
			reading.hero=A.otherReading(records,left)
			reading.hero.kind="other"
		end
	end
	return reading
end

local RECAP_CELLS={
	{key="record",label="RECORD"},
	{key="rating",label="RATING"},
	{key="best",label="BEST WIN"},
	{key="worst",label="WORST COMP MET"},
	{key="with",label="PLAYED MOST WITH"},
}

function A.sessionRecapLabels()
	local out={}
	for i=1,#RECAP_CELLS do
		out[i]=RECAP_CELLS[i].label
	end
	return out
end

local function recapCompText(members)
	if type(members)~="table"or#members==0 then
		return nil
	end
	local parts={}
	for i=1,#members do
		parts[i]=tostring(members[i].spec)
	end
	return table.concat(parts,"/")
end

local function countComp(tally,order,key,members,won)
	local row=tally[key]
	if row==nil then
		row={key=key,members=members,wins=0,losses=0,draws=0,games=0}
		tally[key]=row
		order[#order+1]=row
	end
	row.games=row.games+1
	if won==true then
		row.wins=row.wins+1
	elseif won==false then
		row.losses=row.losses+1
	else
		row.draws=row.draws+1
	end
end

local function countRecordComps(record,tally,order)
	if A.compRounds(record.format)then
		local rounds=type(record.rounds)=="table"and record.rounds or{}
		local ok,outcomes=pcall(A.roundOutcomes,record)
		outcomes=(ok and type(outcomes)=="table")and outcomes or{}
		for i=1,#rounds do
			local key,members=nil,nil
			if type(rounds[i])=="table"then
				key,members=A.roundCompKey(record,rounds[i])
			end
			local won=nil
			if type(outcomes[i])=="table"then
				won=outcomes[i].won
			end
			if key~=nil and type(won)=="boolean"then
				countComp(tally,order,key,members,won)
			end
		end
		return
	end
	local key,members=A.compKey(record)
	if key==nil then
		return
	end
	local tone=A.resultTone(record)
	if tone=="win"or tone=="loss"then
		countComp(tally,order,key,members,tone=="win")
	elseif A.effectiveResult(record)=="draw"then
		countComp(tally,order,key,members,nil)
	end
end

local function recordMates(record)
	local out={}
	local rounds=type(record.rounds)=="table"and record.rounds or nil
	if A.compRounds(record.format)then
		for i=1,rounds and#rounds or 0 do
			local mates=A.roundSides(record,rounds[i])
			for _,entry in ipairs(type(mates)=="table"and mates or{})do
				if entry.guid~=record.character then
					out[entry.guid]=entry.p
				end
			end
		end
	elseif type(record.participants)=="table"then
		for guid,row in pairs(record.participants)do
			if guid~=record.character and A.matchSide(record,guid)=="with"then
				out[guid]=row
			end
		end
	end
	return out
end

local function countResult(held,record)
	local tone=A.resultTone(record)
	if tone=="win"then
		held.wins=held.wins+1
	elseif tone=="loss"then
		held.losses=held.losses+1
	elseif A.effectiveResult(record)=="draw"then
		held.draws=held.draws+1
	end
end

function A.recapReads(format)
	return format~="world"and format~="unknown"
end

function A.sessionRecap(session,format,character)
	if type(session)~="table"or type(session.entries)~="table"then
		return nil
	end
	local entries,records={},{}
	for _,entry in ipairs(session.entries)do
		local record=type(entry)=="table"and entry.kind~="incomplete"and entry.subject or nil
		if type(record)=="table"and record.format~="world"and A.recordInFormat(record,format)
			and A.recordedBy(record,character)then
			entries[#entries+1]=entry
			records[#records+1]=record
		end
	end
	if#records<2 then
		return nil
	end
	local out={key=session.key,matches=#records,
		record={wins=0,losses=0,draws=0,matches=#records}}
	local tally,order,mates={},{},{}
	local best,mmr=0,nil
	for i=1,#records do
		local record=records[i]
		countResult(out.record,record)
		local _,_,change=A.recordLadderPair(record)
		if type(change)=="number"and change>best then
			best=change
			local comp,members=A.compKey(record)
			out.bestWin={id=record.id,change=change,comp=comp,compText=recapCompText(members),
				members=members}
		end
		local pre,post=A.recordMmrPair(record)
		if pre~=nil then
			if mmr==nil then
				mmr={format=record.format,character=record.character,from=pre,to=post}
			elseif record.format==mmr.format and record.character==mmr.character then
				mmr.from=pre
			end
		end
		countRecordComps(record,tally,order)
		for guid,row in pairs(recordMates(record))do
			local held=mates[guid]
			if held==nil then
				held={guid=guid,name=row.name,wins=0,losses=0,draws=0,matches=0}
				mates[guid]=held
			end
			held.matches=held.matches+1
			countResult(held,record)
		end
	end

	out.rating={}
	for _,ladder in ipairs(sessionLadders(entries))do
		out.rating[#out.rating+1]={format=ladder.format,from=ladder.from,to=ladder.to,
			change=ladder.change}
	end
	if#out.rating==1 then
		out.change=out.rating[1].change
	end
	if mmr~=nil then
		out.mmr={format=mmr.format,from=mmr.from,to=mmr.to,change=mmr.to-mmr.from}
	end

	for _,row in ipairs(order)do
		local rate=row.wins/row.games
		local held=out.worstComp
		local heldRate=held and held.wins/held.games or nil
		if row.games>=2 and(held==nil or rate<heldRate
			or(rate==heldRate and(row.games>held.games
				or(row.games==held.games and row.key<held.key))))then
			out.worstComp={key=row.key,compText=recapCompText(row.members),members=row.members,
				wins=row.wins,
				losses=row.losses,draws=row.draws,games=row.games}
		end
	end

	for _,held in pairs(mates)do
		local top=out.mostWith
		if held.matches>=2 and(top==nil or held.matches>top.matches
			or(held.matches==top.matches and(held.wins-held.losses>top.wins-top.losses
				or(held.wins-held.losses==top.wins-top.losses and held.guid<top.guid))))then
			out.mostWith=held
		end
	end
	return out
end

local function recapRecordText(held)
	local text=("%d-%d"):format(held.wins,held.losses)
	if(held.draws or 0)>0 then
		text=text..("-%d"):format(held.draws)
	end
	return text
end
A.sessionRecapRecordText=recapRecordText

local function pairTone(won,lost)
	return won>lost and"win"or won<lost and"loss"or"dim"
end

function A.sessionRecapCells(recap)
	local out={}
	if type(recap)~="table"then
		return out
	end
	local values={}
	local record=recap.record
	values.record={text=recapRecordText(record),tone=pairTone(record.wins,record.losses)}

	local ladders=type(recap.rating)=="table"and recap.rating or{}
	if#ladders==1 then
		local ladder=ladders[1]
		local text=ladder.change==0 and("%d"):format(ladder.to)
			or("%d %s"):format(ladder.to,A.signedText(ladder.change))
		values.rating={text=text,tone=pairTone(ladder.change,0)}
	elseif#ladders>1 then
		local parts={}
		for i=1,#ladders do
			parts[i]=("%s %s"):format(A.signedText(ladders[i].change),A.formatShortLabel(ladders[i].format))
		end
		values.rating={text=table.concat(parts,", "),tone="dim"}
	end

	local bestWin=recap.bestWin
	if bestWin~=nil then
		local lead=A.signedText(bestWin.change)
		local compText=recapCompText(bestWin.members)
		values.best={text=compText and lead.." vs"or lead,tone="win",members=bestWin.members,
			readout=compText and("%s vs %s"):format(lead,compText)or lead,match=bestWin.id}
	end

	local worst=recap.worstComp
	if worst~=nil then
		local lead=recapRecordText(worst)
		values.worst={text=lead,tone=pairTone(worst.wins,worst.losses),members=worst.members,
			readout=("%s %s"):format(recapCompText(worst.members)or"?",lead)}
	end

	local with=recap.mostWith
	if with~=nil then
		values.with={text=("%s %s"):format(A.bareName(with.name)or"Unknown",recapRecordText(with)),
			tone=pairTone(with.wins,with.losses),role="nameMedium"}
	end

	for i=1,#RECAP_CELLS do
		local cell=RECAP_CELLS[i]
		local value=values[cell.key]
		out[i]={key=cell.key,label=cell.label,text=value and value.text or"-",
			tone=value and value.tone or"dim",read=value~=nil,members=value and value.members or nil,
			readout=value and value.readout or nil,match=value and value.match or nil,
			role=value and value.role or nil}
	end
	return out
end

function A.sessionRecapHeading(session,now)
	local label=type(session)=="table"and A.sessionDayLabel(session.endStamp,now)or nil
	return label and label:upper()or nil
end

local function closedNewest(now,db)
	local _,session=A.newestSession(db)
	if type(session)~="table"or type(session.endEpoch)~="number"or type(now)~="number"
		or now-session.endEpoch<=SESSION_GAP_MINUTES*60 then
		return nil
	end
	return session
end

function A.sessionRecapLoginText(recap,session)
	local parts={recapRecordText(recap.record)}
	for _,ladder in ipairs(recap.rating or{})do
		parts[#parts+1]=("%s %s"):format(A.signedText(ladder.change),A.formatLabel(ladder.format))
	end
	local key,part=sessionDayPart(type(session)=="table"and session.startStamp or nil)
	local noon=key~=nil and dayKeyNoon(key)or nil
	if noon~=nil then
		local ok,day=pcall(date,"%a",noon)
		if ok and type(day)=="string"then
			parts[#parts+1]=day.." "..part
		end
	end
	return"Last session: "..table.concat(parts,", ")
end

function A.sessionRecapLogin(now)
	local db=A.db and A.db()
	if not db then
		return nil,"no-store"
	end
	if type(A.postGameEnabled)=="function"and not A.postGameEnabled()then
		return nil,"off"
	end
	local session=closedNewest(now)
	if session==nil then
		return nil,"open"
	end
	local seen=type(db.ui)=="table"and db.ui.recapSeenEpoch or nil
	if type(seen)=="number"and session.endEpoch<=seen then
		return nil,"seen"
	end
	local recap=A.sessionRecap(session)
	if recap==nil then
		return nil,"one-match"
	end
	db.ui=type(db.ui)=="table"and db.ui or{}
	db.ui.recapSeenEpoch=session.endEpoch
	A.trace("recap",{key=tostring(recap.key),matches=recap.matches,
		record=recapRecordText(recap.record),change=recap.change,reason="login"},"ui")
	return A.sessionRecapLoginText(recap,session)
end

function A.sessionRecapLogout(now)
	local db=A.savedDB()
	local session=db and closedNewest(now,db)or nil
	if session==nil then
		return false
	end
	local seen=type(db.ui)=="table"and db.ui.recapSeenEpoch or nil
	if type(seen)=="number"and seen>=session.endEpoch then
		return false
	end
	db.ui=type(db.ui)=="table"and db.ui or{}
	db.ui.recapSeenEpoch=session.endEpoch
	return true
end

A.on("PLAYER_LOGOUT",function()
	local ok,err=pcall(A.sessionRecapLogout,time())
	if not ok then
		A.noteError(err,"recap-logout")
	end
end)

function A.recapSessionFor(format,character)
	local entries={}
	for _,record in ipairs(A.matches(format,character))do
		entries[#entries+1]={kind="match",subject=record}
	end
	local sessions=A.buildSessions(entries)
	return sessions[1]
end

function A.sessionRecapReadout(format,character,now)
	local name=A.formatLabel(format)
	if not A.recapReads(format)then
		return{("%s has no session recap: it counts no matches a recap reads"):format(name)}
	end
	local session=A.recapSessionFor(format,character)
	if session==nil then
		return{("no %s session is stored"):format(name)}
	end
	local recap=A.sessionRecap(session,format,character)
	if recap==nil then
		return{("the newest %s session holds one match, so it has no recap"):format(name)}
	end
	local lines={("%s, %s %s, %d matches"):format(name,A.sessionDayLabel(session.endStamp,now)or"?",
		A.sessionSpanText(session)or"",recap.matches)}
	for _,cell in ipairs(A.sessionRecapCells(recap))do
		lines[#lines+1]=("%s  %s"):format(cell.label,cell.readout or cell.text)
	end
	local mmr=recap.mmr
	if mmr~=nil then
		lines[#lines+1]=("MMR  %d to %d %s"):format(mmr.from,mmr.to,A.signedText(mmr.change))
	end
	return lines
end
