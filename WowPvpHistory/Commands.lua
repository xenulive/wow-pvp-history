-- WowPvpHistory 0.70.33
-- Author:  Xenu-Sentinels
-- Project: wow-pvp-history
--          https://github.com/xenulive/wow-pvp-history
-- License: MIT, see LICENSE
local _,A=...

local WHOLE_CEILING=2147483647
local function wholeArgument(word,first,last)
	first=first or 1
	local text=word~=nil and tostring(word)or nil
	local digits=text~=nil and(text:match("^%d+$")or(first<0 and text:match("^%-%d+$")))or nil
	local n=digits and tonumber(digits)or nil
	if n==nil or n<first or n>(last or WHOLE_CEILING)then
		return nil
	end
	return n
end
A.wholeArgument=wholeArgument

local function decimalArgument(word)
	local text=word~=nil and tostring(word)or nil
	if text==nil or not(text:match("^%-?%d+%.?%d*$")or text:match("^%-?%.%d+$"))then
		return nil
	end
	local n=tonumber(text)
	if n==nil or n==math.huge or n==-math.huge then
		return nil
	end
	return n
end

local SEASON_NOT_WHOLE="a season is a whole number above zero"

local function refuseUnread(word,usage)
	A.say(("%q was not read, so nothing was done. %s"):format(tostring(word),usage))
end

local function reportLast(db)
	local last=db.matches[#db.matches]
	if not last then
		A.say("no match recorded yet")
		return
	end

	local lines=A.lastLines(last)
	for i=1,#lines do
		A.say(lines[i])
	end
end

local function reportActive(db)
	local active=db.active
	if not active then
		A.say("nothing in flight")
		return
	end
	if type(active)~="table"then
		A.say(("in flight: a damaged record (%s), cleared at the next login"):format(type(active)))
		return
	end
	A.say(("in flight: opened %s at %s, state=%s, rounds=%s, harvesting=%s")
		:format(tostring(active.openedAt),tostring(active.openedState),
			tostring(active.state),tostring(A.roundList(active)and#active.rounds or nil),
			tostring(active.harvesting)))
end

local RECENT_DROPS=3

local function reportDropped(db)
	local any=false
	for reason,count in pairs(db.dropped)do
		A.say("dropped "..tostring(count).." x "..tostring(reason))
		any=true
	end
	if not any then
		A.say("nothing dropped")
	end

	local events=db.dropEvents or{}
	for i=math.max(1,#events-RECENT_DROPS+1),#events do
		local e=events[i]
		A.say(("      %s %s: rounds=%s format=%s rows=%s readAt=%s opened=%s")
			:format(tostring(e.at),tostring(e.reason),tostring(e.rounds),tostring(e.format),
				tostring(e.rows),tostring(e.readAt),tostring(e.openedState)))
	end

	local errorState=A.lastErrorState(db)
	if errorState then
		A.say(("last error, %s: %s. %s"):format(A.lastErrorWhen(errorState),errorState.text,
			errorState.fromRing and"/pvph debug clear error forgets it"
				or"/pvph error clear forgets it"))
	end
end

local function reportStatus(db)
	A.say(("v%s, schema %s, %d matches stored, next id %d")
		:format(tostring(A.version or"unknown"),tostring(db.schema),#db.matches,db.nextMatchId))
	reportLast(db)
	reportActive(db)
	reportDropped(db)

	A.say(A.canaryLine(A.canaryState()))
	A.say(A.backupLine())

	A.say(A.fontsLine(A.fontsLoaded(),A.fontsGated()))

	A.say(A.linksLine(A.linksAvailable()))

	A.say(A.menuLine(A.menuTagsRegistered(),A.menuTagCount()))

	A.say(A.tooltipLine(A.tooltipAvailable()))

	local incomplete=A.incompleteNoticeLine()
	if incomplete then
		A.say(incomplete)
	end

	local notice=A.sizeNoticeLine(A.storedSize())
	if notice then
		A.say(notice)
	end
end

local LEFT_LIMIT=15

local function leftOnOtherTab()
	local character=A.windowCharacter()
	local _,season,_,bound=A.formatScope("unknown")
	local out={}
	for _,entry in ipairs((A.listEntries("unknown",character,season,bound)))do
		if entry.kind=="incomplete"then
			out[#out+1]=entry.subject
		end
	end
	return out,("%s, %s"):format(A.windowCharacterText(),A.scopeText("unknown"))
end

local function reportLeft()
	local entries,read=leftOnOtherTab()
	local total=#entries

	if total==0 then
		A.say(("no match has been left or abandoned for %s. Nothing to show"):format(read))
		return
	end

	local counts=A.incompleteCounts(entries)
	A.say(("%d incomplete %s for %s, newest first: %d left, %d abandoned, %d of them rated")
		:format(total,total==1 and"match"or"matches",read,counts.left,counts.abandoned,
			counts.rated))
	A.say("  no roster or format on these: both are unreachable before a match completes")

	local shown=math.min(total,LEFT_LIMIT)
	for i=1,shown do
		A.say("  "..A.incompleteLine(entries[i]))
	end
	if total>shown then
		A.say(("  %d older not shown"):format(total-shown))
	end
end

local function reportIncompleteWindow()
	if A.showIncompleteTab()then
		return
	end

	A.say("the match window could not be opened. /pvph left lists what is held, and "
		.."/pvph edit left #<n> reason writes why one ended")
	reportLeft()
end

local LIST_LIMIT=10

local function reportList(format)
	local matches=A.matches(format)
	local total=#matches

	if total==0 then
		if not format then
			A.say("no match recorded yet")
			return
		end
		local formats=A.formats()
		if#formats>0 then
			A.say(("no stored match has format %q. stored: %s")
				:format(format,table.concat(formats,", ")))
		else
			A.say(("no stored match has format %q, and nothing is stored"):format(format))
		end
		return
	end

	local shown=math.min(total,LIST_LIMIT)

	A.say(("%d stored %s%s, newest first"):format(total,total==1 and"match"or"matches",
		format and(" with format "..format)or""))
	for i=1,shown do
		A.say("  "..A.summaryLine(matches[i]))
	end
	if total>shown then
		A.say(("  %d older not shown. /pvph <id> for one in full"):format(total-shown))
	end
end

local function reportMatch(id)
	local record=A.match(id)
	if not record then
		A.say(("no stored match with id %s. /pvph list to see what is held"):format(tostring(id)))
		return
	end

	local lines=A.detailLines(record)
	for i=1,#lines do
		A.say(lines[i])
	end
	local built,buildLine=pcall(A.talentsLine,record)
	if built and type(buildLine)=="string"then
		A.say(buildLine)
	end
end

local function characterLabel(guid)
	if type(A.characterList)=="function"then
		local ok,list=pcall(A.characterList)
		if ok and type(list)=="table"then
			for i=1,#list do
				if list[i].guid==guid and not list[i].unresolved and type(list[i].label)=="string"then
					return list[i].label
				end
			end
		end
	end
	return"the selected character"
end
A.characterLabel=characterLabel

function A.refuseUnstoredFormat(format,character)
	if format==nil then
		return false
	end
	local counts=A.formatCounts(character)
	if counts[format]~=nil then
		return false
	end
	local formats={}
	for name in pairs(counts)do
		if type(name)=="string"then
			formats[#formats+1]=name
		end
	end
	table.sort(formats)
	local whose=character~=nil
		and(", for %s, the character the window reads"):format(characterLabel(character))or""
	if#formats>0 then
		A.say(("no stored match has format %q. stored: %s%s")
			:format(format,table.concat(formats,", "),whose))
	elseif character~=nil then
		A.say(("no stored match has format %q, and nothing is stored%s"):format(format,whose))
	else
		A.say(("no stored match has format %q, and nothing is stored"):format(format))
	end
	return true
end

function A.reportBests(format)
	if A.refuseUnstoredFormat(format,A.windowCharacter())then
		return
	end
	format=format or A.windowFormat()
	if format~=nil and type(A.bestsViewOffered)=="function"and not A.bestsViewOffered(format)then
		A.say(("%s keeps no bests: its records carry no scoreboard row of yours")
			:format(A.formatLabel(format)))
		return
	end
	local season,bound
	if format~=nil then
		local _,s,_,b=A.formatScope(format)
		season,bound=s,b
	end
	local ok,lines,rows=pcall(A.bestsLines,format,season,A.windowCharacter(),bound)
	if not ok then
		A.say("the bests could not be read: "..tostring(lines))
		return
	end
	A.say(("bests on %s, %s: %d %s"):format(format and A.formatLabel(format)or"every format",
		format and A.scopeText(format)or"all time",rows,rows==1 and"spec"or"specs"))
	for i=1,#lines do
		A.say("  "..lines[i])
	end
end

local PLAYERS_LIMIT=10

local PLAYER_MATCH_LIMIT=5

local function reportPlayers()
	local met,noted=A.playersMet()
	local players={}
	for i=1,#met do
		players[#players+1]=met[i]
	end
	for i=1,#noted do
		players[#players+1]=noted[i]
	end
	local total=#players

	if total==0 then
		A.say("no player indexed yet. /pvph rebuild builds it from the stored matches")
		return
	end

	local shown=math.min(total,PLAYERS_LIMIT)

	local tail=#noted>0 and(", and %d noted and never met in a match"):format(#noted)or""
	A.say(("%d %s met in a match, most matches first%s"):format(#met,#met==1 and"player"or"players",
		tail))
	for i=1,shown do
		A.say("  "..A.playerSummaryLine(players[i].guid,players[i].entry))
	end
	if total>shown then
		A.say(("  %d not shown. /pvph player <text> for one in full"):format(total-shown))
	end
end

local NOTES_CONTROLS={
	sort=function(value)
		local word,dir=(value or""):lower():match("^(%S+)%s*(%S*)%s*$")
		if not A.setNotesSort(word,dir~=""and dir or nil)then
			return nil,"/pvph notes sort <recent||met||rep||player||record||with||against> [up||down]"
		end
		local state=A.notesState()
		return("the players list is sorted %s%s for this session"):format(state.sort,
			state.dir and(" "..state.dir)or"")
	end,
	rep=function(value)
		local word=value and value:lower()or nil
		if word=="off"or word=="all"then
			A.setNotesRep(nil)
			return"the players list shows every rep"
		end
		local rep=A.repFromWord(word)
		if rep==nil or not A.setNotesRep(rep)then
			return nil,"/pvph notes rep <bad||negative||neutral||positive||strong||none||off>"
		end
		return("the players list shows %s only"):format((A.ratingRampLabel(rep~="none"and rep or nil)))
	end,
	format=function(value)
		local word=value and value:lower()or nil
		if word==nil then
			return nil,"/pvph notes format <format||all>"
		end
		if word=="all"then
			A.setNotesFormat(nil)
			return"the players list shows every format"
		end
		local choices=A.playerFormatChoices()
		for _,choice in ipairs(choices)do
			if choice.value~=nil and choice.value==word then
				A.setNotesFormat(word)
				return("the players list shows players met in %s"):format(choice.label)
			end
		end
		local held={}
		for _,choice in ipairs(choices)do
			if choice.value~=nil then
				held[#held+1]=choice.value
			end
		end
		return nil,("no stored match is in format %q. Formats held: %s"):format(tostring(value),
			#held>0 and table.concat(held,", ")or"none")
	end,
	side=function(value)
		local word=value and value:lower()or nil
		if word==nil then
			return nil,"/pvph notes side <with||against||all>"
		end
		if word=="all"then
			A.setNotesSide(nil)
			return"the players list shows either side"
		end
		if not A.setNotesSide(word)then
			return nil,"/pvph notes side <with||against||all>"
		end
		return("the players list shows players met %s"):format(word=="with"and"on your side"
			or"against you")
	end,
	search=function(value)
		A.setNotesSearch(value)
		if value==nil or value==""then
			return"the players list is not searched"
		end
		return("the players list is searched for %q"):format(value)
	end,
}

local SCOREBOARD={
	roster={name=true,damage=true,healing=true,kb=true,dispels=true,objective=true},
	lobby={swing=true,wins=true,damage=true,kb=true,dispels=true},
	usage="/pvph scoreboard sort <name||damage||healing||kb||dispels||objective||swing||wins> [up||down]",
}

function SCOREBOARD.state()
	local key,up,index=A.scoreSort()
	local lobbyKey,lobbyUp=A.lobbySort()
	return("the match roster is sorted %s; the Solo Shuffle table %s"):format(
		A.scoreSortWords(key,up,index),A.lobbySortWords(lobbyKey,lobbyUp))
end

local function reportScoreboard(words)
	local verb=words[2]and words[2]:lower()or nil
	if verb==nil then
		A.say(SCOREBOARD.state())
		return
	end
	local word=words[3]and words[3]:lower()or nil
	local dir=words[4]and words[4]:lower()or nil
	if verb~="sort"or word==nil or words[5]~=nil
		or(dir~=nil and dir~="up"and dir~="down")
		or not(SCOREBOARD.roster[word]or SCOREBOARD.lobby[word])then
		A.say(SCOREBOARD.usage)
		return
	end
	local up=nil
	if dir~=nil then
		up=dir=="up"
	end
	if SCOREBOARD.roster[word]then
		A.setScoreSort(word,up,1)
	end
	if SCOREBOARD.lobby[word]then
		local lobbyUp=up
		if lobbyUp==nil then
			lobbyUp=A.lobbySortOpens(word)
		end
		A.setLobbySessionSort(word,lobbyUp)
	end
	if type(A.refreshWindow)=="function"then
		pcall(A.refreshWindow)
	end
	A.say(SCOREBOARD.state()..", for this session")
end

local function reportNotesWindow(word,rest)
	local control=word and NOTES_CONTROLS[word:lower()]or nil
	if control then
		if not A.showNotes()then
			A.say("the players window could not be opened")
			return
		end
		local said,refusal=control(rest)
		A.say(said or refusal)
		return
	end
	if word==nil then
		if type(A.clearNotesScope)=="function"then
			A.clearNotesScope()
		end
		if A.showNotes()then
			return
		end

		A.say("the players window could not be opened. /pvph players lists the index, /pvph player "
			.."<text> reads one in full, and note, rate, tag and untag write on one")
		reportPlayers()
		return
	end

	if rest~=nil then
		refuseUnread(rest,"/pvph notes last, or /pvph notes #<id>, takes nothing after it")
		return
	end
	local record
	if word:lower()=="last"then
		record=A.matches()[1]
		if not record then
			A.say("no match is recorded yet, so there is no roster to scope to")
			return
		end
	else
		local id=A.matchIdFromWord(word)
		if not id then
			A.say(("unknown notes command %q. /pvph notes opens the index, notes last scopes to the "
				.."newest match and notes #<id> to a named one"):format(word))
			return
		end
		record=A.match(id)
		if not record then
			local db=A.db()
			A.say(("no stored match has id %s. %d recorded, ids run to %d"):format(tostring(id),
				db and#db.matches or 0,db and(db.nextMatchId-1)or 0))
			return
		end
	end

	if A.showNotesForMatch(record.id)then
		return
	end

	A.say(("the players window could not be opened. /pvph %s reads match %s and its roster in chat")
		:format(tostring(record.id),tostring(record.id)))
end

local function reportCard(name)
	if name==nil then
		A.say(A.hideNameCard()and"the name card is hidden"or"no name card is up")
		return
	end
	local said=A.showNameCard(name,nil,"typed")
	if said.kind=="met"then
		A.say(("%s: met %d %s, rep %s"):format(tostring(said.name),said.met or 0,
			(said.met or 0)==1 and"time"or"times",tostring((A.ratingRampLabel(said.rating)))))
	elseif said.kind=="stranger"then
		A.say(("%s: not met before"):format(tostring(said.name)))
	elseif said.kind=="self"then
		A.say(("%s: one of your own characters, so no card"):format(tostring(said.name)))
	else
		A.say(("no card for %q: %s"):format(name,tostring(said.why)))
	end
end

local function reportPlayer(text)
	local found=A.findPlayers(text)
	local total=#found

	if total==0 then
		A.say(("no indexed player has a stored name containing %q. /pvph players to see what is held")
			:format(text))
		return
	end

	local shown=math.min(total,PLAYER_MATCH_LIMIT)

	if total>1 then
		A.say(("%d indexed players match %q"):format(total,text))
	end

	local index=A.encounterIndex()
	for i=1,shown do
		local lines=A.playerDetailLines(found[i].guid,found[i].entry,total>1,
			A.playerDossier(found[i].guid,index))
		for j=1,#lines do
			A.say(lines[j])
		end
	end

	if total>shown then
		A.say(("  %d more match. Narrow the text"):format(total-shown))
	end
end

local function rest(msg,skip)
	local text=tostring(msg or"")
	local pos=1
	for _=1,skip do
		local _,stop=text:find("%S+",pos)
		if not stop then
			return""
		end
		pos=stop+1
	end
	return(text:sub(pos):gsub("^%s+",""):gsub("%s+$",""))
end

local function addressed(who,verb)
	local guid,entry,extra,total=A.resolvePlayer(who)
	if guid then
		return guid,entry
	end

	local why=entry
	if why=="several"then
		local shown=extra
		A.say(("%d indexed players match %q:"):format(total or#shown,who))
		for i=1,#shown do
			A.say("  "..A.playerChoiceLine(i,shown[i].guid,shown[i].entry))
		end
		if(total or#shown)>#shown then
			A.say(("  %d more match, and are not addressable. Narrow the text")
				:format(total-#shown))
		end
		A.say(("nothing written. /pvph %s #1 ... to pick one"):format(verb))
	elseif why=="no-listing"then
		A.say("no listing to pick from. Run the command with a name first")
	elseif why=="range"then
		A.say(("that listing holds %d. Nothing written"):format(tonumber(extra)or 0))
	else
		A.say(("no indexed player has a stored name containing %q. /pvph players to see what is held")
			:format(tostring(who)))
	end
	return nil
end

local function nameOf(guid,entry)
	local names=entry and entry.names
	return tostring((names and names[1])or guid)
end

local function reportNoteCommand(msg,words)
	local who=words[2]
	if not who then
		A.say("/pvph note <who> [text]  writes a note on an indexed player. No text clears it")
		return
	end

	local guid,entry=addressed(who,"note")
	if not guid then
		return
	end

	local body=rest(msg,2)
	local ok,was,reason,got,bound=A.setPlayerNote(guid,body~=""and body or nil)

	if not ok then
		if reason=="too-long"then
			A.say(("that note is %d bytes and the bound is %d bytes. Nothing written")
				:format(got,bound))
		else
			A.say("no database, so the note could not be stored")
		end
		return
	end

	if body==""then
		if was==nil then
			A.say(("%s had no note"):format(nameOf(guid,entry)))
		else
			A.say(("note cleared on %s, was: %s"):format(nameOf(guid,entry),tostring(was)))
		end
		return
	end

	if was==body then
		A.say(("already noted %s: %s"):format(nameOf(guid,entry),tostring(was)))
		return
	end
	A.say(("noted %s%s"):format(nameOf(guid,entry),
		was~=nil and(", replacing: "..tostring(was))or""))
end

local function reportRate(words)
	local who=words[2]
	local usage="/pvph rate <who> +2|+1|0|-1|-2  rates an indexed player. No value clears it"
	if not who then
		A.say(usage)
		return
	end
	if words[4]then
		refuseUnread(words[4],usage)
		return
	end

	local guid,entry=addressed(who,"rate")
	if not guid then
		return
	end

	local word=words[3]
	local value
	if word then
		value=A.ratingValue(word)
		if value==nil then
			A.say(("%q is not a rating. +2, +1, 0, -1 or -2, and + and - are taken as the "
				.."single step either way"):format(word))
			return
		end
	end

	local ok,was=A.setPlayerRating(guid,value)
	if not ok then
		A.say("no database, so the rating could not be stored")
		return
	end

	if value==nil then
		if was==nil then
			A.say(("%s had no rating"):format(nameOf(guid,entry)))
		else
			A.say(("rating cleared on %s, was %s"):format(nameOf(guid,entry),
				tostring(A.ratingText(was))))
		end
		return
	end

	if was==value then
		A.say(("%s is already rated %s"):format(nameOf(guid,entry),tostring(A.ratingText(value))))
		return
	end
	A.say(("%s rated %s"):format(nameOf(guid,entry),tostring(A.ratingText(value))))
end

local function reportTag(words)
	local who=words[2]
	if not who or not words[3]then
		A.say("/pvph tag <who> <tag> [tag ...]  adds tags to an indexed player")
		return
	end

	local guid,entry=addressed(who,"tag")
	if not guid then
		return
	end

	local tags={}
	for i=3,#words do
		tags[#tags+1]=words[i]
	end

	local ok,added,reason,offender,bound=A.addPlayerTags(guid,tags)
	if not ok then
		if reason=="tag-too-long"then
			A.say(("%q is %d bytes and the bound is %d. Nothing written")
				:format(offender,#offender,bound))
		elseif reason=="too-many"then
			A.say(("%s already carries %d tags, which is the bound, so %q was not added. Nothing "
				.."written"):format(nameOf(guid,entry),bound,tostring(offender)))
		else
			A.say("no database, so the tags could not be stored")
		end
		return
	end

	if#added==0 then
		A.say(("%s already carries every one of those"):format(nameOf(guid,entry)))
		return
	end

	A.say(("%s tagged %s"):format(nameOf(guid,entry),table.concat(added,", ")))
end

local function reportUntag(words)
	local who=words[2]
	if not who then
		A.say("/pvph untag <who> [tag ...]  removes tags. With no tag, removes all of them")
		return
	end

	local guid,entry=addressed(who,"untag")
	if not guid then
		return
	end

	local tags={}
	for i=3,#words do
		tags[#tags+1]=words[i]
	end

	local ok,removed=A.removePlayerTags(guid,tags)
	if not ok then
		A.say("no database, so the tags could not be changed")
		return
	end

	if#removed==0 then
		A.say(("nothing removed from %s"):format(nameOf(guid,entry)))
		return
	end

	A.say(("%s untagged %s"):format(nameOf(guid,entry),table.concat(removed,", ")))
end

local function reportRosterUsage(word)
	if word then
		A.say(("unknown roster command %q"):format(word))
	end
	A.say("/pvph roster <id> tag <tag> [tag ...]    tags everyone in that match's roster")
	A.say("/pvph roster <id> untag <tag> [tag ...]  takes those tags back off them")
	A.say("/pvph roster <id> untag confirm          takes every tag off every one of them")
	A.say("  the recording character and any bot rows are left out. /pvph list names the ids")
end

local function reportRoster(words)
	local id=words[2]and A.matchIdFromWord(words[2])or nil
	if not id then
		reportRosterUsage(words[2])
		return
	end

	local record=A.match(id)
	if not record then
		A.say(("no match #%s is stored. /pvph list names the ones that are"):format(tostring(id)))
		return
	end

	local verb=words[3]and words[3]:lower()or nil
	if verb~="tag"and verb~="untag"then
		reportRosterUsage(words[3])
		return
	end

	local tags={}
	for i=4,#words do
		tags[#tags+1]=words[i]
	end

	if verb=="tag"then
		local ok,summary,reason,offender,bound=A.tagRoster(record,tags)
		if not ok then
			if reason=="tag-too-long"then
				A.say(("%q is %d bytes and the bound is %d. Nothing written")
					:format(tostring(offender),#tostring(offender),bound))
			elseif reason=="empty-roster"then
				A.say(("match #%s has nobody to tag: its roster is you and %d bot %s")
					:format(tostring(id),summary.bots,summary.bots==1 and"row"or"rows"))
			elseif reason=="no-tags"then
				reportRosterUsage()
			else
				A.say("no database, so the tags could not be stored")
			end
			return
		end
		A.say(A.rosterWriteLine(summary,true))
		return
	end

	if#tags==0 then
		A.say(("that would take every tag off everyone in match #%s. "
			.."/pvph roster %s untag confirm does it"):format(tostring(id),tostring(words[2])))
		return
	end
	local all=#tags==1 and tags[1]:lower()=="confirm"

	local ok,summary,reason=A.untagRoster(record,all and{}or tags)
	if not ok then
		if reason=="empty-roster"then
			A.say(("match #%s has nobody to untag: its roster is you and %d bot %s")
				:format(tostring(id),summary.bots,summary.bots==1 and"row"or"rows"))
		else
			A.say("no database, so the tags could not be changed")
		end
		return
	end
	A.say(A.rosterWriteLine(summary,false))
end

local function reportTags()
	local lines=A.tagLines()
	if#lines==0 then
		A.say("no tag has been written. /pvph tag <who> <tag> writes one")
		return
	end

	local tagged=A.taggedCount()
	A.say(("%d %s in use across %d tagged %s, most used first")
		:format(#lines,#lines==1 and"tag"or"tags",tagged,tagged==1 and"player"or"players"))
	for i=1,#lines do
		A.say(lines[i])
	end
end

local function reportEditUsage(word)
	if word then
		A.say(("unknown edit command %q"):format(word))
	end
	A.say("/pvph edit <id> note <text>          a note on a stored match. No text clears it")
	A.say("/pvph edit <id> result win|loss|draw fills a result the capture did not record. No value clears it")
	A.say("/pvph edit left #<n> reason <token>  why a match ended without completing. No value clears it")
	A.say("/pvph edit left #<n> note <text>     a note on that entry")
	A.say("/pvph edit <id>                      what is editable there and what is stored")
	A.say("  reason tokens: "..table.concat(A.manualReasons(),", "))
end

local function reportEditState(label,subject,captured,capturedLabel,none)
	local manual=subject.manual
	A.say(("%s:"):format(label))
	if none~=nil then
		A.say(("  %s cannot be filled by hand: %s"):format(capturedLabel,none))
	elseif captured~=nil then
		A.say(("  %s %s, captured, so it cannot be filled by hand")
			:format(capturedLabel,tostring(captured)))
	else
		A.say(("  %s absent, so it can be filled"):format(capturedLabel))
	end
	if type(manual)~="table"then
		A.say("  never edited")
		return
	end
	A.say("  "..tostring(A.editedSummary(subject)))
end

local function reportEditRecord(id,field,value,raw)
	local record=A.match(id)
	if not record then
		A.say(("no stored match with id %s. /pvph list to see what is held"):format(tostring(id)))
		return
	end

	if not field then
		local none=not A.carriesResult(record)
			and("a %s record carries none"):format(A.formatLabel(record.format))or nil
		local held=A.resultCaptured(record)and A.capturedResultText(record)or nil
		reportEditState(("match #%s"):format(tostring(id)),record,held,"result",none)
		return
	end

	if field=="note"then
		local ok,was,_,got,bound=A.editNote(record,raw~=""and raw or nil)
		if not ok then
			A.say(("that note is %d bytes and the bound is %d. Nothing written")
				:format(got or 0,bound or 0))
			return
		end
		if raw==""and was==nil then
			A.say(("match #%s had no note"):format(tostring(id)))
		elseif raw==""then
			A.say(("note cleared on match #%s, was: %s. It stays marked as edited")
				:format(tostring(id),tostring(was)))
		elseif was==raw then
			A.say(("match #%s already noted: %s"):format(tostring(id),tostring(was)))
		else
			A.say(("match #%s noted: %s"):format(tostring(id),tostring(record.manual.note)))
		end
		return
	end

	if field=="result"then
		local ok,was,reason,held=A.editResult(record,value)
		if ok and reason=="rebuild-failed"then
			local written=value==nil
				and("hand-entered result cleared on match #%s, was: %s"):format(tostring(id),tostring(was))
				or("match #%s result %s, entered by hand"):format(tostring(id),tostring(value))
			A.say(("%s. The player index was not rebuilt: %s. /pvph rebuild"):format(written,tostring(held)))
			return
		end
		if not ok then
			if reason=="captured"then
				A.say(("match #%s already carries result %s, which the capture recorded. Nothing "
					.."written"):format(tostring(id),tostring(held)))
			elseif reason=="no-result"then
				A.say(("match #%s is a %s record, which carries no result. Nothing written")
					:format(tostring(id),A.formatLabel(record.format)))
			else
				A.say("a result is win, loss or draw. Nothing written")
			end
			return
		end
		if value==nil and was==nil then
			A.say(("match #%s had no hand-entered result"):format(tostring(id)))
		elseif value==nil then
			A.say(("hand-entered result cleared on match #%s, was: %s. It stays marked as edited")
				:format(tostring(id),tostring(was)))
		elseif was==value then
			A.say(("match #%s already has result %s, entered by hand"):format(tostring(id),tostring(was)))
		else
			A.say(("match #%s result %s, entered by hand. The player index was rebuilt")
				:format(tostring(id),tostring(record.manual.result)))
		end
		return
	end

	reportEditUsage(field)
end

local function reportEditIncomplete(id,field,value,raw)
	local entry=A.incompleteById(id)
	if not entry then
		A.say(("no incomplete match with id #%s. /pvph left to see what is held")
			:format(tostring(id)))
		return
	end

	if not field then
		A.say(("incomplete #%s: %s"):format(tostring(id),A.incompleteLine(entry)))
		if type(entry.manual)~="table"then
			A.say("  never edited")
		else
			A.say("  "..tostring(A.editedSummary(entry)))
		end
		return
	end

	if field=="note"then
		local ok,was,_,got,bound=A.editIncompleteNote(entry,raw~=""and raw or nil)
		if not ok then
			A.say(("that note is %d bytes and the bound is %d. Nothing written")
				:format(got or 0,bound or 0))
			return
		end
		if raw==""and was==nil then
			A.say(("incomplete #%s had no note"):format(tostring(id)))
		elseif raw==""then
			A.say(("note cleared on incomplete #%s, was: %s. It stays marked as edited")
				:format(tostring(id),tostring(was)))
		elseif was==raw then
			A.say(("incomplete #%s already noted: %s"):format(tostring(id),tostring(was)))
		else
			A.say(("incomplete #%s noted: %s"):format(tostring(id),tostring(entry.manual.note)))
		end
		return
	end

	if field=="reason"then
		local ok,was=A.editReason(entry,value)
		if not ok then
			A.say(("%q is not one of the reasons. %s. Nothing written")
				:format(tostring(value),table.concat(A.manualReasons(),", ")))
			return
		end
		if value==nil and was==nil then
			A.say(("incomplete #%s had no reason"):format(tostring(id)))
		elseif value==nil then
			A.say(("reason cleared on incomplete #%s, was: %s. It stays marked as edited")
				:format(tostring(id),tostring(was)))
		elseif was==value then
			A.say(("incomplete #%s already has reason %s"):format(tostring(id),tostring(was)))
		else
			A.say(("incomplete #%s reason %s"):format(tostring(id),tostring(entry.manual.reason)))
		end
		return
	end

	reportEditUsage(field)
end

local function reportEdit(msg,words)
	if not words[2]then
		reportEditUsage(nil)
		return
	end

	if words[2]:lower()=="left"then
		local id=words[3]and wholeArgument(words[3]:match("^#?(%d+)$")or words[3]:match("^[Ll](%d+)$"))
		if not id then
			A.say("/pvph edit left #<n> ...  needs an entry number, #1 or L1. /pvph left lists them")
			return
		end
		local field=words[4]and words[4]:lower()or nil
		if field=="reason"and words[6]then
			refuseUnread(words[6],"/pvph edit left #<n> reason <token>  takes one reason token")
			return
		end
		reportEditIncomplete(id,field,words[5]and words[5]:lower()or nil,rest(msg,4))
		return
	end

	local id=A.matchIdFromWord(words[2])
	if not id then
		reportEditUsage(words[2])
		return
	end

	local field=words[3]and words[3]:lower()or nil
	if field=="result"and words[5]then
		refuseUnread(words[5],"/pvph edit <id> result win|loss|draw  takes one result")
		return
	end
	reportEditRecord(id,field,words[4]and words[4]:lower()or nil,rest(msg,3))
end

local function reportError(clearing)
	local db=A.savedDB()
	if not db then
		A.say(clearing and"no saved database, so there was no stored error to forget"
			or"no saved database, so no stored error can be read")
		return
	end

	if not clearing then
		local lines=A.lastErrorLines(db)
		if not lines then
			A.say("nothing has thrown, or the last one was cleared")
			return
		end
		for i=1,#lines do
			A.say(lines[i])
		end
		return
	end

	local held,at=A.clearError()
	if not held then
		A.say("there was no stored error to forget")
		return
	end
	A.say(("forgot the error %s: %s")
		:format(at and("stored "..tostring(at))or"stored at an unrecorded time",tostring(held)))
end

local function reportCompRow(format,index,scope)
	local rows=A.compTally(format,scope.season,scope.character,scope.bound)
	if#rows==0 then
		local lines=A.compLines(format,scope.season,scope.character,scope.bound)
		if#lines>0 then
			for i=1,#lines do
				A.say(lines[i])
			end
			return
		end
		A.say(("%s ranks no comp, so there is no row to open. /pvph comps %s says why")
			:format(A.formatLabel(format),format))
		return
	end

	local row=rows[index]
	if row==nil then
		A.say(("%s lists %d comp%s, so there is no row %d. /pvph comps %s numbers them")
			:format(A.formatLabel(format),#rows,#rows==1 and""or"s",index,format))
		return
	end

	local matches={}
	for _,record in ipairs(A.matches(format,scope.character))do
		if(scope.season==nil or A.recordInSeason(record,scope.season))
			and A.recordSince(record,scope.bound)then
			matches[#matches+1]=record
		end
	end
	local kept={}
	local comp=A.compText(row.members)or"unknown comp"
	if A.compRounds(format)then
		local rounds=A.compRoundRows(format,row.key,scope.season,scope.character,scope.bound)
		local held={}
		for i=1,#rounds do
			if rounds[i].id~=nil then
				held[rounds[i].id]=true
			end
		end
		for i=1,#matches do
			if held[matches[i].id]then
				kept[#kept+1]=matches[i]
			end
		end
		A.say(("%s against %s: %d round%s in %d of %d matches, newest first"):format(
			A.formatLabel(format),comp,#rounds,#rounds==1 and""or"s",#kept,#matches))
	else
		local counted={}
		for _,id in ipairs(row.ids or{})do
			counted[id]=true
		end
		local undecided=0
		for i=1,#matches do
			if counted[matches[i].id]then
				kept[#kept+1]=matches[i]
			elseif A.compKey(matches[i])==row.key then
				undecided=undecided+1
			end
		end
		local tail=undecided>0
			and(", and %d more against it that decided nothing"):format(undecided)or""
		A.say(("%s against %s: %d of %d, newest first%s"):format(
			A.formatLabel(format),comp,#kept,#matches,tail))
	end

	local shown=math.min(#kept,LIST_LIMIT)
	for i=1,shown do
		A.say("  "..A.summaryLine(kept[i]))
	end
	if#kept>shown then
		A.say(("  %d older not shown. /pvph <id> for one in full"):format(#kept-shown))
	end

	local share=A.compShareText(row)
	if share then
		A.say("  "..share)
	end
end

local function reportCompPairRow(format,index,scope)
	local rows=A.compPairTally(format,scope.season,scope.character,scope.bound)
	local row=rows[index]
	if row==nil then
		A.say(("%s lists %d enemy pair%s, so there is no row %d. /pvph comps pairs %s numbers them")
			:format(A.formatLabel(format),#rows,#rows==1 and""or"s",index,format))
		return
	end
	local unit=A.compRounds(format)and"round"or"match"
	local lines=A.compPairRowLines(row)
	local met={}
	for i=1,#lines do
		if lines[i].kind=="specMet"then
			met[#met+1]=lines[i]
		end
	end
	A.say(("%s against %s: %d %s%s, newest first, each with the enemy team it was met in"):format(
		A.formatLabel(format),A.compText(row.members)or"unknown pair",#met,unit,
		#met==1 and""or(unit=="match"and"es"or"s")))
	local shown=math.min(#met,LIST_LIMIT)
	for i=1,shown do
		A.say("  "..tostring(met[i].text))
	end
	if#met>shown then
		A.say(("  %d older not shown. /pvph <id> for one in full"):format(#met-shown))
	end
end

local function compFormLine(format)
	if type(A.compPairsFormat)~="function"or not A.compPairsFormat(format)then
		return nil
	end
	local on,source=A.compPairsShowing(format)
	return("the window's comps table on %s: %s (%s)"):format(A.formatLabel(format),
		on and"pairs"or"trios",tostring(source))
end

local function reportCompForm(form,format,index)
	if A.refuseUnstoredFormat(format,form=="pairs"and A.windowCharacter()or nil)then
		return
	end
	format=format or A.windowFormat()
	if type(A.compPairsFormat)~="function"or type(format)~="string"or not A.compPairsFormat(format)then
		A.say(("/pvph comps %s: the comps table switches to pairs on Solo Shuffle, Arena, Arena (3v3) "
			.."and Skirmish, and %s is none of them"):format(form,
			type(format)=="string"and A.formatLabel(format)or"All"))
		return
	end
	local changed=A.setCompPairs(format,form=="pairs"or nil,"typed")
	if changed and type(A.refreshWindow)=="function"then
		pcall(A.refreshWindow)
	end
	if form=="trios"then
		A.say(compFormLine(format).."; the session hold is let go and nothing was stored")
		return
	end

	local _,season,_,bound=A.formatScope(format)
	local scope={season=season,character=A.windowCharacter(),bound=bound}
	if index~=nil then
		reportCompPairRow(format,index,scope)
	else
		local lines=A.compPairLines(format,scope.season,scope.character,scope.bound)
		if#lines==0 then
			A.say(("no %s round or match in the window's scope names an enemy pair yet"):format(
				A.formatLabel(format)))
		end
		for i=1,#lines do
			A.say(lines[i])
		end
	end
	A.say(compFormLine(format).." for this session; /pvph comps trios lets go, and nothing was stored")
end

local function reportAsk(format)
	if type(A.askLines)~="function"then
		A.say("the questions did not load")
		return
	end
	if A.refuseUnstoredFormat(format,A.windowCharacter())then
		return
	end

	local named=format or A.windowFormat()
	local _,season,_,bound=A.formatScope(named)
	local character=A.windowCharacter()

	local lines=A.askLines(named,season,character,bound)
	for i=1,#lines do
		A.say(lines[i])
	end
end

local ASK_SORT_WORDS={met="met",won="rate",default="default"}

local SPEC_SORT_WORDS={
	spec="spec",
	["rounds-against"]="againstRounds",["wl-against"]="againstRecord",["won-against"]="againstRate",
	["rounds-with"]="alongRounds",["wl-with"]="alongRecord",["won-with"]="alongRate",
	default="default",
}

local ASK_SORT_USAGE="/pvph ask sort <beats||where||worth||comp> <met||won||default>"
local ASK_SPECS_USAGE="/pvph ask specs <on||off>, or /pvph ask specs sort <spec||rounds-against||wl-against||"
	.."won-against||rounds-with||wl-with||won-with||default>, held for this session"
local ASK_UNDER_USAGE="/pvph ask under <on||off>   shows the rows under the floor for this session"

local function askPopulationNow()
	local named=A.windowFormat()
	local _,season,_,bound=A.formatScope(named)
	return named,season,A.windowCharacter(),bound
end

local function drawnAnswer(answer,key,named,season,character,bound)
	if answer~=nil and key=="comp"and type(A.compPairsShowing)=="function"and A.compPairsShowing(named)then
		return A.compPairAnswer(answer,named,season,character,bound)
	end
	return answer
end

local function reportAskSort(key,word)
	if type(A.askQuestion)~="function"or A.askQuestion(key)==nil or word==nil then
		A.say(ASK_SORT_USAGE)
		return
	end
	local named,season,character,bound=askPopulationNow()
	local answer=drawnAnswer(A.askAnswer(key,named,season,character,bound),key,named,season,
		character,bound)

	local column=ASK_SORT_WORDS[word]
	if column==nil then
		A.say(ASK_SORT_USAGE)
		return
	end
	A.toggleAskSort(key,column)
	if type(A.pickAsk)=="function"then
		pcall(A.pickAsk,key)
	end
	A.say(A.askSortLine(answer)or"the questions did not load")
end

local function reportAskSpecs(word,column)
	if type(A.setSpecsView)~="function"or type(A.toggleSpecsSort)~="function"then
		A.say("the Stats half did not load")
		return
	end
	if word=="on"or word=="off"then
		A.setSpecsView(word=="on")
		if type(A.refreshWindow)=="function"then
			pcall(A.refreshWindow)
		end
		local named=A.windowFormat()
		local drawn=type(A.compRounds)=="function"and A.compRounds(named)
		A.say(word=="off"and"the specs view is off for this session"
			or(drawn and"the specs view is on for this session"
				or"the specs view is on for this session, and draws on a Solo Shuffle tab"))
		return
	end
	local sort=word=="sort"and column~=nil and SPEC_SORT_WORDS[column]or nil
	if sort==nil then
		A.say(ASK_SPECS_USAGE)
		return
	end
	A.toggleSpecsSort(sort)
	A.setSpecsView(true)
	if type(A.refreshWindow)=="function"then
		pcall(A.refreshWindow)
	end
	local named,season,character,bound=askPopulationNow()
	local held,up=A.specsSort()
	local _,_,_,rows=A.specRows(named,season,character,held,up,bound)
	local names={}
	for i=1,math.min(3,#rows)do
		names[#names+1]=A.chipText(rows[i])
	end
	A.say(("the specs view, %s: %s"):format(A.specSortWords(held,up),
		#names>0 and table.concat(names,", ")or"no rows"))
end

local function askStandIn()
	local view=type(A.tableViewShowing)=="function"and A.tableViewShowing()or nil
	if view=="zones"then
		return"Where you fight"
	end
	if view=="maps"then
		return"the Maps view"
	end
	if view=="bests"then
		return"the Bests view"
	end
	if view=="builds"then
		return"the Builds view"
	end
	if type(A.askAcross)=="function"and A.askAcross()then
		return"the every-format overview"
	end
	return nil
end

local function reportAskUnder(word)
	if type(A.setAskUnderShown)~="function"then
		A.say("the Stats half did not load")
		return
	end
	if word~="on"and word~="off"then
		A.say(ASK_UNDER_USAGE)
		return
	end
	local standIn=askStandIn()
	if standIn~=nil then
		A.say(("%s stands in place of the cards, so no card's rows under the floor are on screen; nothing was changed")
			:format(standIn))
		return
	end
	A.setAskUnderShown(word=="on")
	if type(A.refreshWindow)=="function"then
		pcall(A.refreshWindow)
	end
	local named,season,character,bound=askPopulationNow()
	local key=type(A.askShowing)=="function"and A.askShowing()or nil
	local answer=key and drawnAnswer(A.askAnswer(key,named,season,character,bound),key,named,
		season,character,bound)or nil
	local line=answer and A.askFloorLine(answer)or nil
	A.say(("the rows under the floor are %s for this session; %s: %s"):format(
		word=="on"and"shown"or"folded",answer and answer.title or"no card",
		line or"no row is under the floor"))
end

local function reportAskOpen(word)
	if type(A.askShowing)~="function"or type(A.pickAskRow)~="function"then
		A.say("the Stats half did not load")
		return
	end
	if A.windowBodyShown()~="stats"then
		A.say("the Stats half is not on screen. /pvph show <tab> stats opens it")
		return
	end
	local standIn=askStandIn()
	if standIn~=nil then
		A.say(("%s stands in place of the cards, so there is no card row to open or close"):format(standIn))
		return
	end
	local key=A.askShowing()
	local named,season,character,bound=askPopulationNow()
	local answer=A.askAnswer(key,named,season,character,bound)
	if answer==nil then
		A.say(("the lit card %s answers no question, so there is no card row to open or close")
			:format(tostring(key)))
		return
	end
	local kind=type(A.askTableKind)=="function"and A.askTableKind(answer)or nil
	answer=drawnAnswer(answer,key,named,season,character,bound)

	local open=A.askRowShowing()
	if word==nil then
		if open~=nil then
			A.pickAskRow(open)
		end
		A.trace("ask-open",{card=key,key=open,opened="none"},"ui")
		A.say(open~=nil and("%s: the open row is closed"):format(answer.title)
			or("%s: no row was open"):format(answer.title))
		return
	end

	if type(A.specsShowing)=="function"and A.specsShowing()and word~=nil then
		local sort,ascending=A.specSort()
		local read,_,_,_,merged=pcall(A.specRows,named,season,character,sort,ascending,bound)
		local specs=read and type(merged)=="table"and merged or{}
		local n=wholeArgument(word)
		local row=n and specs[n]or nil
		if row==nil then
			A.say(("the specs view: no row %s. The table holds %d"):format(tostring(word),#specs))
			return
		end
		if A.askRowShowing()~=row.key then
			A.pickAskRow(row.key)
		end
		A.trace("ask-open",{card="specs",key=row.key,opened="detail",n=n},"ui")
		A.say(("the specs view: row %d open, %s"):format(n,tostring(A.chipText(row))))
		return
	end

	local rows=A.askSorted(answer)
	if A.askUnderShown()and type(answer.under)=="table"then
		for i=1,#answer.under do
			rows[#rows+1]=answer.under[i]
		end
	end
	local n=wholeArgument(word)
	local row=n and rows[n]or nil
	if row==nil then
		A.say(("%s: no row %s. The table holds %d"):format(answer.title,tostring(word),#rows))
		return
	end
	if kind==nil and not A.askRowOpens(answer)then
		A.say(("%s: its rows open nothing"):format(answer.title))
		return
	end

	local rowKey=kind==nil and A.askRowKey(row)or row.key
	if A.askRowShowing()~=rowKey then
		A.pickAskRow(rowKey)
	end
	local opened=kind=="comp"and"matches"or tostring(A.askRowOpensKey(answer)):lower()
	A.trace("ask-open",{card=key,key=rowKey,opened=opened,n=n},"ui")
	A.say(("%s: row %d open, %s"):format(answer.title,n,tostring(row.name or A.chipText(row))))
end

local function reportComps(format,index,form)
	if form~=nil then
		reportCompForm(form,format,index)
		return
	end
	if A.refuseUnstoredFormat(format,nil)then
		return
	end
	format=format or A.windowFormat()
	if format==nil then
		A.say("comps are per format. /pvph comps arena2 reads the 2v2 history, "
			.."and /pvph list names what is stored")
		return
	end

	local _,season,_,bound=A.formatScope(format)
	local scope={season=season,character=A.windowCharacter(),bound=bound}

	if index~=nil then
		reportCompRow(format,index,scope)
		return
	end

	local lines=A.compLines(format,scope.season,scope.character,scope.bound)
	if#lines==0 then
		if not A.compFormat(format)then
			A.say(("%s has no enemy comp to rank. Comps are an arena and solo shuffle "
				.."reading: a battleground's ten are not a team")
				:format(A.formatLabel(format)))
			return
		end
		local held=#A.matches(format,scope.character)
		if scope.character~=nil and held==0 and#A.matches(format)>0 then
			A.say(("no %s match was recorded by %s, the character the window reads, so there is no "
				.."comp to rank there"):format(A.formatLabel(format),characterLabel(scope.character)))
			return
		end
		if held>0 then
			A.say(("no %s match is in the window's scope, %s, so there is no comp to rank there")
				:format(A.formatLabel(format),A.scopeText(format)))
			return
		end
		A.say(("no %s match is stored, so there is no comp to rank yet"):format(A.formatLabel(format)))
		return
	end

	for i=1,#lines do
		A.say(lines[i])
	end
	local formLine=compFormLine(format)
	if formLine~=nil then
		A.say(formLine)
	end
end

local function reportRegion(format)
	if A.refuseUnstoredFormat(format,A.windowCharacter())then
		return
	end

	if type(A.regionLines)~="function"then
		A.say("the summary region did not load, so it has no figures to state")
		return
	end

	local lines=A.regionLines(format)
	if#lines==0 then
		A.say("nothing is stored, so no tab has a region to measure")
		return
	end
	for i=1,#lines do
		A.say(lines[i])
	end
end

local function reportFaults(word)
	if word~=nil and word~="verbose"then
		A.say(("unknown faults command %q. verbose, or nothing for the short form"):format(word))
		return
	end
	if type(A.regionFaults)~="function"then
		A.say("the summary region did not load, so its invariants cannot be checked")
		return
	end

	local ok,faults=pcall(A.regionFaults)
	if not ok or type(faults)~="table"then
		A.say("the invariant check raised, so nothing was established")
		return
	end

	local tabs=type(A.tabList)=="function"and#A.tabList(A.windowCharacter())or 0
	if tabs==0 then
		A.say("no tab has anything stored, so no region was checked")
		return
	end

	local families=type(A.faultFamilies)=="function"and A.faultFamilies()or{}

	local answers=type(A.askQuestions)=="function"and#A.askQuestions()or 0

	local panes=type(A.faultPaneSets)=="function"and#A.faultPaneSets()or 0

	local lists=type(A.listColumnSets)=="function"and#A.listColumnSets()or 0

	local shownBody=type(A.windowBodyShown)=="function"and A.windowBodyShown()or nil
	local bodyLabel=(shownBody~=nil and type(A.windowBodyLabel)=="function")
		and A.windowBodyLabel(shownBody)or"none"

	local function nameFamilies()
		for i=1,#families do
			A.say("  "..families[i])
		end
	end

	local function nameSkipped()
		local said=type(A.unshownViewportLine)=="function"and A.unshownViewportLine()or nil
		if said then
			A.say("  "..said)
		end
	end

	if#faults==0 then
		A.say(("body %s, %d tab%s, %d list set%s, %d pane set%s, %d answer set%s, %d checks, clean")
			:format(bodyLabel,tabs,tabs==1 and""or"s",lists,lists==1 and""or"s",
				panes,panes==1 and""or"s",
				answers,answers==1 and""or"s",#families))
		if word=="verbose"then
			nameFamilies()
		end
		nameSkipped()
		return
	end

	A.say(("body %s, %d fault%s over %d tab%s, from %d checks:")
		:format(bodyLabel,#faults,#faults==1 and""or"s",tabs,tabs==1 and""or"s",#families))
	for i=1,#faults do
		A.say("  "..faults[i])
	end
	A.say("what was checked:")
	nameFamilies()
	nameSkipped()
end

local WINDOW_ROW_PICKS={
	last={said="the History list draws no match row on this tab, so there is no newest one",
		test=function()return true end},
	draw={said="no match on this tab is drawn as a draw",test=function(record)
		return type(A.roundsVerdict)=="function"and A.roundsVerdict(record)=="draw"
	end},
	typed={said="no match on this tab carries a result entered by hand",test=function(record)
		return type(record.manual)=="table"and record.manual.result~=nil
			and type(A.resultOfferable)=="function"and A.resultOfferable(record)
	end},
	short={said="no match on this tab is a shuffle storing fewer than six rounds",test=function(record)
		local rounds=type(record.rounds)=="table"and#record.rounds or 0
		return rounds>0 and rounds<6
	end},
}

local function windowRowRecord(word,verb)
	if word==nil then
		A.say(("/pvph window %s <id||last>: a stored match's id, or last for the newest match row the "
			.."History list draws"):format(verb))
		return nil
	end
	local wanted=WINDOW_ROW_PICKS[word:lower()]
	if wanted then
		local entries=A.drawnEntries()
		for i=1,#entries do
			local entry=entries[i]
			if entry.kind=="match"and wanted.test(entry.subject)then
				return entry.subject
			end
		end
		A.say(wanted.said)
		return nil
	end
	local id=A.matchIdFromWord(word)
	if not id then
		A.say(("%q is not a match id. /pvph list to see what is held"):format(word))
		return nil
	end
	local record=A.match(id)
	if not record then
		local db=A.db()
		A.say(("no stored match has id %s. %d recorded, ids run to %d"):format(tostring(id),
			db and#db.matches or 0,db and(db.nextMatchId-1)or 0))
		return nil
	end
	return record
end

local MENU_WORDS={open=true,note=true,roster=true,print=true,talents=true,compare=true,
	result=true}

local function reportWindowMenu(words)
	if words[3]and words[3]:lower()=="close"then
		local closed=type(A.closeRowMenus)=="function"and A.closeRowMenus()
		A.say(closed and"menus closed"or"the client's menu manager did not answer, so nothing was closed")
		return
	end
	local record=windowRowRecord(words[3],"menu")
	if not record then
		return
	end
	local id=A.matchIdText(record.id)
	local entryWord=words[4]and words[4]:lower()or nil
	if entryWord==nil then
		if type(A.openRowMenuFor)~="function"then
			A.say("the match window did not load, so the row has no menu to open")
			return
		end
		local opened,onRow=A.openRowMenuFor(record.id,"word")
		if not opened then
			A.say(("match %s: the menu could not be opened"):format(id))
			return
		end
		local labels={}
		for _,entry in ipairs(A.matchMenuEntries(record,"match"))do
			labels[#labels+1]=entry.label
		end
		A.say(("match %s: menu opened %s, %d entries: %s"):format(id,
			onRow and"on its row"or"beside the list, its row not being drawn",#labels,
			table.concat(labels,", ")))
		return
	end
	if not MENU_WORDS[entryWord]then
		A.say(("/pvph window menu %s takes open, note, roster, print, talents, compare or result <win||loss||draw>, and %q is none of them")
			:format(id,entryWord))
		return
	end
	local choice=words[5]and words[5]:lower()or nil
	if entryWord=="result"and choice==nil then
		A.say("result needs win, loss or draw after it")
		return
	end
	if type(A.runRowMenuEntry)~="function"then
		A.say("the match window did not load, so the row has no menu entry to run")
		return
	end
	local outcome,reason=A.runRowMenuEntry(entryWord,record.id,choice,"word")
	A.say(("match %s: %s %s%s"):format(id,entryWord,tostring(outcome),
		reason and(", "..tostring(reason))or""))
end

local function reportWindowHoverLeft()
	local entry=nil
	for _,drawn in ipairs(A.drawnEntries())do
		if drawn.kind=="incomplete"then
			entry=drawn.subject
			break
		end
	end
	if entry==nil then
		A.say("the History list draws no left-early row on this tab, so there is no newest one")
		return
	end
	local id=A.rowIdText(entry,"incomplete")
	if type(A.showRowTooltipFor)~="function"then
		A.say("the match window did not load, so the row has no tooltip to show")
		return
	end
	local outcome,detail=A.showRowTooltipFor(entry.id,"incomplete")
	if outcome=="shown"then
		A.say(("left early %s: tooltip shown, %d lines"):format(id,detail))
	elseif detail=="not-drawn"then
		A.say(("left early %s is not drawn in the list, so there is no row to hover"):format(id))
	else
		A.say(("left early %s: tooltip %s, %s"):format(id,tostring(outcome),tostring(detail)))
	end
end

local function reportWindowHover(words)
	if words[3]==nil then
		if type(A.hideRowTooltip)=="function"then
			A.hideRowTooltip()
		end
		A.say("row tooltip hidden")
		return
	end
	if words[3]:lower()=="left"then
		reportWindowHoverLeft()
		return
	end
	local record=windowRowRecord(words[3],"hover")
	if not record then
		return
	end
	local id=A.matchIdText(record.id)
	if type(A.showRowTooltipFor)~="function"then
		A.say("the match window did not load, so the row has no tooltip to show")
		return
	end
	local outcome,detail=A.showRowTooltipFor(record.id)
	if outcome=="shown"then
		A.say(("match %s: tooltip shown, %d lines"):format(id,detail))
	elseif detail=="not-drawn"then
		A.say(("match %s is not drawn in the list, so there is no row to hover. /pvph show %s lists it")
			:format(id,tostring(record.format or"all")))
	elseif detail=="no-lines"then
		A.say(("match %s is a duel, whose row draws no tooltip"):format(id))
	else
		A.say(("match %s: tooltip %s, %s"):format(id,tostring(outcome),tostring(detail)))
	end
end

local function reportWindowDropdown(words)
	local which=words[3]and words[3]:lower()or nil
	if which==nil then
		local closed=type(A.closeWindowDropdowns)=="function"and A.closeWindowDropdowns()or 0
		A.say(closed>0 and"dropdown closed"or"no dropdown was open")
		return
	end
	if type(A.openWindowDropdown)~="function"then
		A.say("the history window did not load, so it has no dropdown to open")
		return
	end
	local outcome,detail=A.openWindowDropdown(which)
	if outcome=="opened"then
		A.say(("%s dropdown opened, %d rows"):format(which,detail))
	elseif detail=="unknown"then
		A.say(("/pvph window dropdown takes character, scope, result or spec, and %q is none of them")
			:format(which))
	elseif detail=="closed"then
		A.say("the history window is not open. /pvph show opens it")
	else
		A.say(("the %s dropdown is not drawn on this half"):format(which))
	end
end

local TILE_WORDS={rate="WIN RATE",matches="MATCHES",mmr="MMR",length="AVG LENGTH",
	last="LAST MATCH"}

local function reportWindowTile(words)
	local word=words[3]and words[3]:lower()or nil
	if word==nil then
		A.hideTooltip()
		A.say("card hover hidden")
		return
	end
	local label=TILE_WORDS[word]
	if not label then
		A.say(("/pvph window tile takes rate, matches, mmr, length or last, and %q is none of them")
			:format(word))
		return
	end
	if type(A.showTileTooltipFor)~="function"then
		A.say("the history window did not load, so it has no card to hover")
		return
	end
	local outcome,detail=A.showTileTooltipFor(label)
	if word=="rate"and outcome~="shown"and detail=="not-drawn"then
		label="MATCHES WON"
		outcome,detail=A.showTileTooltipFor(label)
	end
	if outcome=="shown"then
		A.say(("%s: hover shown, %d lines"):format(label,detail))
	elseif detail=="closed"then
		A.say("the history window is not open. /pvph show opens it")
	elseif detail=="no-hover"then
		A.say(("%s carries no hover on this tab"):format(label))
	else
		A.say(("%s is not drawn on this tab"):format(label))
	end
end

local function reportWindowSize(words)
	local kept={}
	for i=1,#words do
		if not(i>=3 and words[i]:lower()=="session")then
			kept[#kept+1]=words[i]
		end
	end
	words=kept
	local kind,from="matches",3
	local first=words[3]and words[3]:lower()or nil
	if first=="players"then
		kind,from="players",4
	elseif first=="match"or first=="player"then
		kind,from=first,4
	end
	local widthWord=words[from]and words[from]:lower()or nil
	local heightWord=words[from+1]and words[from+1]:lower()or nil
	if widthWord==nil then
		if kind=="match"or kind=="player"then
			A.say(("/pvph window size %s <width> [height]: a number, min, max, authored or same, and "
				.."one figure sizes both"):format(kind))
		else
			A.say("/pvph window size [players] <width> [height]: a number, min, max, authored or same, and "
				.."one figure sizes both")
		end
		return
	end
	local function sizeWordReads(sizeWord)
		return sizeWord==nil or sizeWord=="min"or sizeWord=="max"or sizeWord=="authored"
			or sizeWord=="same"or decimalArgument(sizeWord)~=nil
	end
	local unreadAxis=(not sizeWordReads(widthWord)and"width")
		or(not sizeWordReads(heightWord)and"height")or nil
	if unreadAxis then
		A.say(("the %s %q is not a number, min, max, authored or same"):format(unreadAxis,
			unreadAxis=="width"and widthWord or heightWord))
		return
	end
	if kind=="players"then
		A.showNotes()
	elseif kind=="matches"then
		A.showWindow()
	end
	local applied,why=A.sizeWindow(kind,widthWord,heightWord)
	if not applied and why=="not built"and(kind=="match"or kind=="player")then
		A.say(("no %s is open, so there is nothing to size"):format(A.windowLabel(kind)or kind))
		return
	end
	if not applied then
		if why=="width"or why=="height"then
			A.say(("the %s %q is not a number, min, max, authored or same"):format(why,
				why=="width"and widthWord or(heightWord or widthWord)))
		else
			A.say(("the %s could not be sized: %s"):format(A.windowLabel(kind)or kind,tostring(why)))
		end
		return
	end
	A.say(("%s sized to %sx%s"):format(A.windowLabel(kind)or kind,
		A.ringNumber(A.unitFigure(applied.width)),A.ringNumber(A.unitFigure(applied.height))))
end

local CLICK_MODIFIERS={
	shift={shift=true},
	ctrl={ctrl=true},
	alt={alt=true},
	["shift-alt"]={shift=true,alt=true},
	["ctrl-alt"]={ctrl=true,alt=true},
}

local function reportWindowClick(words)
	local playersForm=words[3]~=nil and words[3]:lower()=="players"
	local mods=(not playersForm and words[4]~=nil and words[5]==nil)
		and CLICK_MODIFIERS[words[4]:lower()]or nil
	local text=mods and words[3]or table.concat(words," ",playersForm and 4 or 3)

	local function sayClick(name,outcome,terms,shown,scoped)
		A.say(("%s: %s"):format(name,outcome))
		if mods and type(terms)=="table"and#terms>0 and(outcome=="added"
			or outcome=="flipped"or outcome=="duplicate")then
			A.say(A.searchCountLine(shown,scoped))
		end
	end

	if playersForm then
		if words[5]~=nil and words[6]==nil and CLICK_MODIFIERS[words[5]:lower()]~=nil then
			A.say("the players window is not a match window, so /pvph window click players <who> takes no modifier")
			return
		end
		if text==""then
			A.say("/pvph window click players <who>: a name, or part of one, of an indexed player")
			return
		end
		if type(A.notesWindowShown)~="function"or not A.notesWindowShown()then
			A.say("the players window is not open, so it has no row to click. /pvph notes opens it")
			return
		end
		local guid,entry=addressed(text,"window click players")
		if not guid then
			return
		end
		A.say(("%s: %s"):format(nameOf(guid,entry),A.clickPlayersRow(guid)))
		return
	end

	if text==""then
		A.say("/pvph window click <who>: a name, or part of one, on the newest open match window's roster")
		return
	end
	local rows=A.matchWindowsOpen()
	local newest=rows[#rows]
	if not newest then
		A.say("no match window is open, so there is no roster to click. /pvph show <id> opens one")
		return
	end
	local record=newest.frame and newest.frame.record
	if type(record)~="table"and newest.kind=="match"then
		record=A.match(newest.id)
	end
	local digits=text:match("^#(%d+)$")
	if digits then
		local roster=A.matchRoster(record)
		local handle=wholeArgument(digits)
		local row=handle and roster[handle]or nil
		if not row then
			A.say(("match %s's roster holds %d, so there is no #%s. Nothing clicked"):format(
				tostring(newest.id),#roster,digits))
			return
		end
		sayClick(row.name,A.clickParticipant(row.guid,newest.frame,mods,mods and"typed"or nil))
		return
	end
	local found=A.matchRoster(record,text)
	if#found==0 then
		A.say(("nobody on match %s's roster has a stored name containing %q"):format(
			tostring(newest.id),text))
		return
	end
	if#found>1 then
		local place,full={},A.matchRoster(record)
		for i=1,#full do
			place[full[i].guid]=i
		end
		A.say(("%d on match %s's roster match %q:"):format(#found,tostring(newest.id),text))
		for i=1,#found do
			A.say("  "..A.playerChoiceLine(place[found[i].guid],found[i].guid,found[i].entry))
		end
		A.say("nothing clicked. Type more of the name, or /pvph window click #N")
		return
	end
	sayClick(found[1].name,A.clickParticipant(found[1].guid,newest.frame,mods,mods and"typed"or nil))
end

local RECT_SURFACES={
	history=function()return A.windowFrameOf and A.windowFrameOf("matches")or nil end,
	summary=function()
		local frame=A.windowFrameOf and A.windowFrameOf("matches")or nil
		return frame and frame.summary or nil
	end,
	players=function()return A.windowFrameOf and A.windowFrameOf("players")or nil end,
	match=function()
		local open=A.matchWindowsOpen and A.matchWindowsOpen()or{}
		return open[#open]and open[#open].frame or nil
	end,
	table=function()
		local open=A.matchWindowsOpen and A.matchWindowsOpen()or{}
		local frame=open[#open]and open[#open].frame or nil
		return frame and frame.detail and frame.detail.box or nil
	end,
	player=function()
		local open=A.playerWindowsOpen and A.playerWindowsOpen()or{}
		return open[#open]and open[#open].frame or nil
	end,
	banner=function()return A.announceFrame and A.announceFrame()or nil end,
	overlay=function()return A.overlayFrame and A.overlayFrame()or nil end,
	overlaytile=function()
		local held=A.overlayCells and A.overlayCells()or nil
		return held and held[1]or nil
	end,
	tooltip=function()return A.tooltipSampleShown()or GameTooltip end,
	finder=function()return A.finderTooltip and A.finderTooltip()or nil end,
	card=function()return A.nameCardFrame and A.nameCardFrame()or nil end,
	hold=function()return A.holdStandIn and A.holdStandIn()or nil end,
	grip=function()return A.windowFrameOf and A.windowFrameOf("matches")or nil end,
	compare=function()return A.compareFrame and A.compareFrame()or nil end,
	menu=function()return A.rowMenuFrame and A.rowMenuFrame()or nil end,
}
local RECT_ORDER={"history","summary","players","match","table","player","banner","overlay",
	"overlaytile","tooltip","finder","card","hold","grip","compare","menu"}

local RECT_CORNERS={grip=64}

local RECT_DRAWN_TALL={
	banner=function()return A.announceDrawnTall and A.announceDrawnTall()or nil end,
}

function A.screenRect(frame,drawnTall)
	if frame==nil then
		return nil,"not shown"
	end
	local visible=frame.IsVisible or frame.IsShown
	local okShown,shown=pcall(visible,frame)
	if not okShown or shown~=true then
		return nil,"not shown"
	end
	local left,top=A.frameFigure(frame,"GetLeft"),A.frameFigure(frame,"GetTop")
	local width,height=A.frameFigure(frame,"GetWidth"),A.frameFigure(frame,"GetHeight")
	local scale=A.frameFigure(frame,"GetEffectiveScale")
	local physical,across=nil,nil
	if type(GetPhysicalScreenSize)=="function"then
		local ok,w,h=pcall(GetPhysicalScreenSize)
		physical=ok and type(h)=="number"and h>0 and h or nil
		across=ok and type(w)=="number"and w>0 and w or nil
	end
	if not(left and top and width and height and scale and physical)then
		return nil,"no position"
	end
	if type(drawnTall)=="number"and drawnTall>height then
		height=drawnTall
	end
	local unit=scale*physical/768
	local function edge(value)
		return math.floor(value*1000+0.5)/1000
	end
	local x0=math.floor(edge(left*unit))
	local y0=math.floor(edge(physical-top*unit))
	local x1=math.ceil(edge((left+width)*unit))
	local y1=math.ceil(edge(physical-(top-height)*unit))
	x0,y0=math.max(x0,0),math.max(y0,0)
	y1=math.min(y1,math.floor(physical))
	if across then
		x1=math.min(x1,math.floor(across))
	end
	return{left=x0,top=y0,width=x1-x0,height=y1-y0}
end

local function reportWindowRect(words)
	local which=words[3]and words[3]:lower()or nil
	local surface=which and RECT_SURFACES[which]or nil
	if not surface then
		A.say(("/pvph window rect takes %s%s"):format(table.concat(RECT_ORDER,", "),
			which and(", and %q is none of them"):format(which)or""))
		return
	end
	local tall=RECT_DRAWN_TALL[which]and RECT_DRAWN_TALL[which]()or nil
	local rect,why=A.screenRect(surface(),tall)
	if not rect then
		A.say(("%s: %s"):format(which,why))
		return
	end
	local side=RECT_CORNERS[which]
	if side then
		rect={left=rect.left+rect.width-side,top=rect.top+rect.height-side,width=side,
			height=side}
	end
	A.say(("%s: %d,%d,%d,%d (left,top,width,height in screen pixels)"):format(which,rect.left,rect.top,
		rect.width,rect.height))
end

local function reportWindow(word,words)
	if type(A.geometryLines)~="function"then
		A.say("the window geometry did not load, so it has no figures to state")
		return
	end

	if word=="reset"then
		if type(A.resetGeometryLines)~="function"then
			A.say("the window geometry did not load, so nothing could be forgotten")
			return
		end
		local reset=A.resetGeometryLines()
		for i=1,#reset do
			A.say(reset[i])
		end
		return
	end

	if word=="size"then
		reportWindowSize(words)
		return
	end

	if word=="scale"then
		if type(A.windowScaleLines)~="function"then
			A.say("the window geometry did not load, so no window has a scale to state")
			return
		end
		local given=words[3]and words[3]:lower()or nil
		if given=="reset"then
			A.setSessionWindowScale(nil,"reset")
		elseif given~=nil then
			if A.setSessionWindowScale(given,"command")==nil then
				local least,most,step=A.windowScaleRange()
				A.say(("/pvph window scale takes a percentage from %d to %d in steps of %d, or reset, and %q is none")
					:format(least,most,step,given))
				return
			end
		end
		for _,line in ipairs(A.windowScaleLines())do
			A.say(line)
		end
		return
	end

	if word=="scroll"then
		local where=words[3]and words[3]:lower()or nil
		if where=="overview"then
			local to=words[4]and words[4]:lower()or nil
			if to~=nil and to~="top"and to~="bottom"then
				A.say("/pvph window scroll overview [top|bottom]: the All tab's Stats page moved, or where it is")
				return
			end
			if type(A.scrollOverview)~="function"then
				A.say("the match window did not load, so there is no Stats page to scroll")
				return
			end
			local offset,range=A.scrollOverview(to)
			if offset==nil then
				if range=="closed"then
					A.say("the window is closed, so no Stats page is drawn and nothing scrolled")
				elseif range=="body"then
					A.say("the window is not on its Stats body, so no Stats page is drawn and nothing scrolled")
				else
					A.say("the window is not on the All tab's Stats page, so nothing scrolled")
				end
				return
			end
			A.say(("the All tab's Stats page is at offset %s of a range of %s"):format(
				A.unitFigure(offset),A.unitFigure(range)))
			return
		end
		if where~="top"then
			A.say("/pvph window scroll top: the History list back to its top")
			A.say("/pvph window scroll overview [top|bottom]: the All tab's Stats page moved, or where it is")
			return
		end
		if type(A.scrollListTop)~="function"then
			A.say("the match window did not load, so there is no list to scroll")
			return
		end
		local ok,why=A.scrollListTop()
		if ok then
			A.say("the History list is at its top")
		elseif why=="closed"then
			A.say("the window is closed, so no History list is drawn and nothing scrolled")
		elseif why=="body"then
			A.say("the window is not on its History body, so no list is drawn and nothing scrolled")
		else
			A.say("the History list could not be scrolled")
		end
		return
	end

	if word=="store"then
		if not A.showStoreWindow()then
			A.say("the store panel could not be opened")
		end
		return
	end

	if word=="player"then
		local text=table.concat(words," ",3)
		if text==""then
			A.say("/pvph window player <who>: a name, or part of one, of an indexed player")
			return
		end
		local guid=addressed(text,"window player")
		if not guid then
			return
		end
		if not A.openPlayer(guid,false,"typed")then
			A.say("that player's window could not be opened")
		end
		return
	end

	if word=="menu"then
		reportWindowMenu(words)
		return
	end

	if word=="hover"then
		reportWindowHover(words)
		return
	end

	if word=="round"then
		if type(A.hoverMatchRound)~="function"then
			A.say("the match window did not load, so it has no round to hover")
			return
		end
		local round=wholeArgument(words[3],1,6)
		if words[3]~=nil and round==nil then
			A.say(("/pvph window round [n]: a round from 1 to 6, and %q is not one"):format(words[3]))
			return
		end
		local outcome,detail=A.hoverMatchRound(round)
		if outcome=="hidden"then
			A.say("round hover hidden")
		elseif outcome=="shown"then
			A.say(("round %d: %s shown"):format(round,tostring(detail)))
		elseif detail=="no-window"then
			A.say("no match window is open, so there is no round to hover. /pvph window menu last open opens one")
		else
			A.say(("round %d has no hover drawn in the newest match window"):format(round))
		end
		return
	end

	if word=="click"then
		reportWindowClick(words)
		return
	end

	if word=="dropdown"then
		reportWindowDropdown(words)
		return
	end

	if word=="tile"then
		reportWindowTile(words)
		return
	end

	if word=="rect"then
		reportWindowRect(words)
		return
	end

	if word=="grip"then
		local which=words[3]and words[3]:lower()or nil
		if which~=nil and which~="hover"then
			A.say(("/pvph window grip [hover]: the history window's resize grip as a pointer over it, and %q is not hover")
				:format(which))
			return
		end
		local frame=A.windowFrameOf and A.windowFrameOf("matches")or nil
		local grip=frame and frame.grip or nil
		if not grip then
			A.say("the history window has no grip built yet. /pvph show opens it")
			return
		end
		local handler=grip:GetScript(which and"OnEnter"or"OnLeave")
		if type(handler)=="function"then
			pcall(handler,grip)
		end
		A.say(("history window grip: %s"):format(grip.gripDrawn or"unpainted"))
		return
	end

	if word=="close"then
		local matches=type(A.closeMatchWindows)=="function"and A.closeMatchWindows()or 0
		local players=type(A.closePlayerWindows)=="function"and A.closePlayerWindows()or 0
		A.say(("closed %d match %s and %d player %s"):format(matches,matches==1 and"window"or"windows",
			players,players==1 and"window"or"windows"))
		return
	end

	if word~=nil then
		A.say(("/pvph window takes reset, size, scale, scroll, store, player, menu, hover, round, click, dropdown, tile, rect, grip, close or nothing, and %q is none of them")
			:format(word))
		return
	end

	local lines=A.geometryLines()
	if#lines==0 then
		A.say("no window registered a geometry, so there is nothing to state")
		return
	end
	for i=1,#lines do
		A.say(lines[i])
	end
end

local function reportSummary(format,season)
	if A.refuseUnstoredFormat(format,A.windowCharacter())then
		return
	end

	local character=A.windowCharacter()
	local choice,_,why,bound=A.formatScope(format)
	local read={A.windowCharacterText()}
	if why=="range"then
		read[#read+1]=("%s, since %s"):format(tostring(A.scopePhrase(choice)),
			tostring(A.stampAt(bound)or bound))
	else
		bound=nil
	end
	if season~=nil then
		read[#read+1]="season "..tostring(season)
	elseif bound==nil then
		read[#read+1]="all time"
	end
	A.say("for "..table.concat(read,", "))

	local lines=A.figureLines(A.summarize(format,season,character,bound))
	for i=1,#lines do
		A.say(lines[i])
	end

	if format==nil and season==nil then
		local tabs=A.tabList(character)
		for i=2,#tabs do
			A.say(("  %-24s %-16s %d"):format(tabs[i].label,tabs[i].format,tabs[i].matches))
		end
	end
end

local counterRequest=nil

local COUNTER_WAIT=5

local function printCounters()
	local counters={}
	if type(A.ratedFormats)=="function"and type(A.ratedCountersNow)=="function"then
		for _,format in ipairs(A.ratedFormats())do
			counters[format]=A.ratedCountersNow(format)
		end
	end
	local lines=A.seasonCounterLines(counters)
	for i=1,#lines do
		A.say(lines[i])
	end
end

local function requestCounters()
	local db=A.db()
	if db and db.active then
		A.say("rated counters: a match is in flight, so the client and the history differ by it "
			.."until it is stored")
		return
	end
	if counterRequest~=nil then
		return
	end
	if type(RequestRatedInfo)~="function"then
		A.say("rated counters: this client offers no request for them")
		return
	end
	local token={}
	counterRequest=token
	pcall(RequestRatedInfo)
	if C_Timer and type(C_Timer.After)=="function"then
		C_Timer.After(COUNTER_WAIT,function()
			if counterRequest==token then
				counterRequest=nil
				A.say(("rated counters: the client did not answer within %d seconds"):format(COUNTER_WAIT))
			end
		end)
	end
end

A.on("PVP_RATED_STATS_UPDATE",function()
	if counterRequest==nil then
		return
	end
	counterRequest=nil
	local db=A.db()
	if db and db.active then
		A.say("rated counters: a match is in flight, so the client and the history differ by it "
			.."until it is stored")
		A.trace("counters",{state="refused",reason="in-flight"},"ui")
		return
	end
	A.trace("counters",{state="answered"},"ui")
	printCounters()
end)

local function reportSeason(msg,words)
	local word=words[2]and words[2]:lower()or nil

	if word==nil then
		local lines=A.seasonLines()
		for i=1,#lines do
			A.say(lines[i])
		end
		requestCounters()
		return
	end

	if word=="start"then
		local number=wholeArgument(words[3])
		if number==nil then
			if tonumber(words[3])~=nil then
				A.trace("season",{source="typed",reason="bad-number"},"data")
				A.say(SEASON_NOT_WHOLE)
			else
				A.say("/pvph season start <n> [YYYY-MM-DD]. The number is the season being opened")
			end
			return
		end
		local entry,closedOrWhy=A.seasonOpen(number,words[4])
		if not entry then
			A.say(tostring(closedOrWhy))
			return
		end
		A.say(("season %d opens at %s"):format(entry.season,tostring(entry.startedAt)))
		if closedOrWhy~=nil then
			A.say(("  season %d closed at the same moment"):format(closedOrWhy))
		end
		return
	end

	if word=="end"then
		local entry,why=A.seasonClose(words[3])
		if not entry then
			A.say(tostring(why))
			return
		end
		A.say(("season %d ends at %s. Nothing is open, which is an off-season")
			:format(entry.season,tostring(entry.endedAt)))
		return
	end

	if word=="label"then
		local number=wholeArgument(words[3])
		if number==nil then
			A.say(tonumber(words[3])~=nil and SEASON_NOT_WHOLE
				or"/pvph season label <n> <text>. Leave the text out to drop a label")
			return
		end
		local entry,why=A.seasonSetLabel(number,rest(msg,3))
		if not entry then
			A.say(tostring(why))
			return
		end
		if entry.label then
			A.say(("season %d is %s"):format(entry.season,entry.label))
		else
			A.say(("season %d carries no label"):format(entry.season))
		end
		return
	end

	if word=="forget"then
		local number=wholeArgument(words[3])
		if number==nil then
			A.say(tonumber(words[3])~=nil and SEASON_NOT_WHOLE or"/pvph season forget <n>")
			return
		end
		local gone,whyOrEntry=A.seasonForget(number)
		if not gone then
			A.say(tostring(whyOrEntry))
			return
		end
		A.say(("season %d is no longer declared. No record's stored season moved"):format(gone))
		local entry=type(whyOrEntry)=="table"and whyOrEntry or{}
		A.say(("  it was season %d, label %s, started %s, ended %s"):format(gone,
			entry.label and("%q"):format(entry.label)or"none",tostring(entry.startedAt or"unknown"),
			tostring(entry.endedAt or"still open")))
		return
	end

	A.say(("unknown season command %q. start, end, label, forget, or nothing at all"):format(word))
end

local function reportSize()
	local size=A.storedSize()
	local lines=A.sizeLines(size)
	for i=1,#lines do
		A.say(lines[i])
	end

	local noted,notedError=pcall(A.noteCanary,size.constants)
	if not noted then
		A.noteError(notedError,"size-canary")
	end
end

local function reportReset(confirmed)
	local before=A.resetPreview()
	if not before then
		A.say("reset: no database")
		return
	end

	if not confirmed then
		A.say("reset would erase "..A.resetLine(before))
		A.say(("the ids return to 1, from %s and %s, and the interface returns to its defaults")
			:format(tostring(before.nextMatchId),tostring(before.nextIncompleteId)))
		A.say(A.pinLine(before.pin))

		if before.inFlight then
			A.say("a match is being recorded, so the confirm would be refused")
		end
		if before.sandboxed then
			A.say("the sandbox is up, so the confirm would be refused. /reload ends it")
		end
		A.say("nothing has changed. /pvph reset confirm erases it")
		return
	end

	local result,why=A.applyReset()
	if not result then
		A.say("reset: "..tostring(why))
		return
	end

	A.say(("reset: %d %s, %d indexed %s, %d with a note and %d incomplete %s erased")
		:format(result.matches,result.matches==1 and"match"or"matches",
			result.players,result.players==1 and"player"or"players",
			result.noted,
			result.incomplete,result.incomplete==1 and"entry"or"entries"))

	local pin=result.pin
	if pin.ok then
		A.say(("a copy holding %d %s is pinned, %d bytes encoded. /pvph restore pinned brings it "
			.."back"):format(pin.matches,pin.matches==1 and"match"or"matches",pin.bytes))
	elseif pin.reason=="smaller"then
		A.say(("the pin holding %d %s was kept rather than overwritten with %d")
			:format(pin.held,pin.held==1 and"match"or"matches",pin.matches))
	else
		A.say("nothing was pinned: this client provides no encoding surface")
	end
end

local function reportFixture(words)
	local second=words[2]and words[2]:lower()or nil

	if second=="clear"then
		local before=A.fixturePreview()
		local leftEarly=tonumber(before.leftEarly)or 0
		if before.marked==0 and leftEarly==0 then
			A.say("no generated records are stored. /pvph debug fixture writes some")
			return
		end

		local confirmed=words[3]~=nil and words[3]:lower()=="confirm"
		if not confirmed then
			local records=before.marked==1 and"record"or"records"
			local real=before.real==1 and"match"or"matches"
			if leftEarly>0 then
				A.say(("fixture clear would remove %d generated %s and %d generated left-early %s, and keep %d real %s")
					:format(before.marked,records,leftEarly,leftEarly==1 and"entry"or"entries",
						before.real,real))
			else
				A.say(("fixture clear would remove %d generated %s and keep %d real %s")
					:format(before.marked,records,before.real,real))
			end
			if before.leaving>0 then
				local line=("%d indexed %s appear only on generated records and leave the index")
					:format(before.leaving,before.leaving==1 and"player"or"players")
				if before.authored>0 then
					line=line..((". %d of them %s something you wrote, which is kept: a note, a "
						.."rating and tags are stored apart from the index and no rebuild touches them")
						):format(before.authored,before.authored==1 and"carries"or"carry")
				end
				A.say(line)
			end
			A.say("the ids do not go back, so nothing already addressed changes meaning")
			A.say("nothing has changed. /pvph debug fixture clear confirm removes them")
			return
		end

		local result,why=A.clearFixture()
		if not result then
			A.say("fixture clear: "..tostring(why))
			return
		end
		local removedLeft=tonumber(result.leftEarly)or 0
		local records=result.removed==1 and"record"or"records"
		local kept=result.kept==1 and"match"or"matches"
		if removedLeft>0 then
			A.say(("fixture clear: %d generated %s and %d generated left-early %s removed, %d real %s kept")
				:format(result.removed,records,removedLeft,removedLeft==1 and"entry"or"entries",
					result.kept,kept))
		else
			A.say(("fixture clear: %d generated %s removed, %d real %s kept")
				:format(result.removed,records,result.kept,kept))
		end
		A.say(("%s%d %s with something written about them, unchanged")
			:format(result.indexRebuilt and"the player index was rebuilt from what is left. "or"",
				result.noted,result.noted==1 and"player"or"players"))
		return
	end

	local asked,seat,sameSpec,unrated,winning=nil,nil,false,false,false
	for i=2,#words do
		local word=words[i]:lower()
		if word=="healer"or word=="damage"then
			seat=word
		elseif word=="samespec"then
			sameSpec=true
		elseif word=="winning"then
			winning=true
		elseif word=="unrated"then
			unrated=true
		elseif asked==nil and tonumber(word)~=nil then
			asked=wholeArgument(word)
			if asked==nil then
				A.say(("fixture: a count is a whole number from 1, and %q is not one"):format(word))
				return
			end
		end
	end

	local report,refusal=A.generateFixture(asked,{seat=seat,sameSpec=sameSpec,unrated=unrated,
		winning=winning})
	if not report then
		A.say("fixture: "..A.fixtureRefusalText(refusal))
		return
	end

	local parts={}
	for _,name in ipairs({"arena2","arena3","blitz","shuffle","arena-unrated","bg"})do
		local count=report[name]or 0
		if count>0 then
			parts[#parts+1]=("%s %d"):format(A.formatLabel(name),count)
		end
	end
	local extras=type(report.extras)=="table"and report.extras or{}
	local extraParts,named={},{}
	for _,name in ipairs({"duel","world","blitz","arena2","unknown"})do
		named[name]=true
		if(extras[name]or 0)>0 then
			extraParts[#extraParts+1]=("%s %d"):format(A.formatLabel(name),extras[name])
		end
	end
	local others={}
	for name,count in pairs(extras)do
		if not named[name]and count>0 then
			others[#others+1]=name
		end
	end
	table.sort(others)
	for _,name in ipairs(others)do
		extraParts[#extraParts+1]=("%s %d"):format(A.formatLabel(name),extras[name])
	end
	if#extraParts>0 then
		local lead="the sandbox adds "..extraParts[1]
		if#parts>0 then
			parts[#parts]=parts[#parts].."; "..lead
		else
			parts[1]=lead
		end
		for i=2,#extraParts do
			parts[#parts+1]=extraParts[i]
		end
	end
	if(report.before or 0)>0 then
		A.say(("fixture: %d more generated %s, %d in the history now, %s")
			:format(report.written,report.written==1 and"record"or"records",
				report.stored,table.concat(parts,", ")),"routine")
	else
		A.say(("fixture: %d generated %s written, %s"):format(report.written,
			report.written==1 and"record"or"records",table.concat(parts,", ")),"routine")
	end

	if report.compsCleared>0 then
		A.say(("%d enemy %s met at least %d times, so the Comps segment has rows")
			:format(report.compsCleared,report.compsCleared==1 and"comp was"or"comps were",
				report.floor),"routine")
	else
		A.say(("no comp reached %d games at n=%d, so the comp table stays empty. Ask for more")
			:format(report.floor,report.asked),"routine")
	end

	if report.seat=="healer"then
		A.say("the generated shuffles are dealt from a healer seat, so each damage spec is with you "
			.."three times and the other healer is against you in every round","routine")
	else
		A.say("the generated shuffles are dealt from a damage seat, so each other damage spec is "
			.."with you twice and each healer three times","routine")
	end
	if report.sameSpec then
		A.say("two of each shuffle lobby share a spec, so the table draws two rows under one label",
			"routine")
	end
	if report.winning then
		A.say("every generated shuffle round is won, so no shuffle comp has a losing or even record",
			"routine")
	end
	A.say("/pvph debug fixture clear confirm removes every one of them","routine")
end

local function filterText(filter)
	local parts={}
	if filter.format then
		parts[#parts+1]=filter.format
	end
	if filter.since then
		parts[#parts+1]="since "..filter.since
	end
	if filter.last then
		parts[#parts+1]=("the last %d"):format(filter.last)
	end
	if#parts==0 then
		return nil
	end
	return table.concat(parts,", ")
end

local function reportCsvExport(filter,part)
	local format=filter.format
	if A.refuseUnstoredFormat(format,nil)then
		return
	end

	local text,rows,matches,taken,parts,leftOut=A.csvExport(filter,part)
	local leftOutText=A.csvLeftOutText(leftOut)
	if not text then
		A.say("csv export: "..tostring(rows))
		return
	end

	if matches==0 then
		local named=filterText(filter)
		if leftOutText then
			A.say(("there is nothing finished to export: %s"):format(leftOutText))
		elseif named then
			A.say(("no stored match is %s, so there is nothing to export"):format(named))
		else
			A.say("nothing is stored, so there is nothing to export")
		end
		return
	end

	local where=parts>1 and(" part %d of %d"):format(taken,parts)or""
	local named=filterText(filter)
	A.say(("csv export%s is %d characters, %d %s, holding %d %s%s%s")
		:format(where,#text,rows,rows==1 and"row"or"rows",
			matches,matches==1 and"match"or"matches",
			named and(" ("..named..")")or"",
			leftOutText and("; "..leftOutText)or""))

	if parts>1 and taken<parts then
		local words={"/pvph export csv"}
		if format then
			words[#words+1]=format
		end
		if filter.since then
			words[#words+1]="since "..filter.since
		end
		if filter.last then
			words[#words+1]=("last %d"):format(filter.last)
		end
		words[#words+1]=tostring(taken+1)
		A.say(("%s is the next part. Each one is a whole file, importable on its own")
			:format(table.concat(words," ")))
	end

	if not A.showCsvSheet("PvP history CSV export"..where,
			"Ctrl+A then Ctrl+C copies it. Save it outside the game as a .csv file."
				..(leftOutText and(" "..leftOutText..".")or""),
			text,nil,nil)then
		A.say("the copy window could not be opened, so the file cannot be reached from here")
	end
end

local function reportCsvImport(forced)
	local opened=A.showCsvSheet("PvP history CSV import",
		forced
			and"Paste a CSV. Forced: a file that has been altered since export is imported anyway."
			or"Paste a CSV. Matches already stored are skipped and nothing is overwritten.",
		nil,forced and"Import, forced"or"Import",function(text)
			local result,why,token=A.csvImport(text,forced)
			if not result then
				A.say("csv import: "..tostring(why))
				if not forced and token~="in-flight"and token~="sandbox"then
					A.say("/pvph import csv force imports it anyway, marking every record it creates")
				end
				return false
			end

			A.say(("csv import: %d added, %d skipped as already stored, %d %s refused")
				:format(result.added,result.skipped,result.refused,
					result.refused==1 and"row"or"rows"))
			local dropped=tonumber(result.roundsDropped)or 0
			if dropped>0 then
				A.say(("csv import: %d typed round %s left off, because the match's recorded rounds rule %s out")
					:format(dropped,dropped==1 and"result was"or"results were",
						dropped==1 and"it"or"them"))
			end
			local resultSetAside=tonumber(result.resultSetAside)or 0
			if resultSetAside>0 then
				A.say(("csv import: %d typed match %s set aside, because the match's recorded result settles %s")
					:format(resultSetAside,resultSetAside==1 and"result was"or"results were",
						resultSetAside==1 and"it"or"them"))
			end
			local resultDropped=tonumber(result.resultDropped)or 0
			if resultDropped>0 then
				A.say(("csv import: %d typed match %s left off, because the match takes no result")
					:format(resultDropped,resultDropped==1 and"result was"or"results were"))
			end
			local cellsDropped=tonumber(result.cellsDropped)or 0
			if cellsDropped>0 then
				A.say(("csv import: %d %s left empty, because %s not one its column takes")
					:format(cellsDropped,cellsDropped==1 and"cell was"or"cells were",
						cellsDropped==1 and"its value is"or"each value is"))
			end
			local fixtureDropped=tonumber(result.fixtureDropped)or 0
			if fixtureDropped>0 then
				A.say(("csv import: %d generated %s refused, because %d generated records is the most the history holds")
					:format(fixtureDropped,fixtureDropped==1 and"record was"or"records were",
						A.fixtureCeiling()))
			end
			if result.indexRebuilt then
				A.say("the player index was rebuilt. /pvph list reads the records back")
			end
			if result.stopped then
				A.say("csv import: those counts cover the records reached before it stopped; the paste is still in the box")
				return false
			end
			return true
		end)

	if not opened then
		A.say("the paste window could not be opened, so nothing can be imported from here")
	end
end

local VIEW_WORDS={comps=true,specs=true,maps=true,bests=true,builds=true,ask=true}

local CARD_WORDS={beats=true,where=true,worth=true,comp=true}

local BODY_WORDS={
	matches={body="history"},
	stats={body="stats",view="ask"},
}

local function cardTitle(key)
	local question=type(A.askQuestion)=="function"and A.askQuestion(key)or nil
	return question and question.title or tostring(key)
end

local function showWord(word,tabs)
	if BODY_WORDS[word]then
		return"body",word
	end
	if VIEW_WORDS[word]then
		return"view",word
	end
	if CARD_WORDS[word]then
		return"card",word
	end
	if word~="all"and type(A.isScopeWord)=="function"and A.isScopeWord(word)then
		return"scope",word
	end
	if word=="alltime"then
		return"scope","all"
	end
	if word=="all"then
		return"format",false
	end
	for i=1,#tabs do
		if tabs[i].format~=nil and tabs[i].format==word then
			return"format",word
		end
	end
	return nil
end

local function costFigure(value)
	if type(value)~="number"then
		return"absent"
	end
	return("%.2f ms"):format(value)
end

local function reportRepaint(word)
	if word=="full"then
		A.setRepaintMode("full")
		A.say("repaint full: every cut is off until /pvph repaint lean or a reload")
		return
	end
	if word=="lean"then
		A.setRepaintMode("lean")
		local cuts=A.leanCuts()
		A.say(("repaint lean: the %d cuts are on, %s"):format(#cuts,table.concat(cuts,", ")))
		return
	end
	if word~=nil then
		A.say(("unknown repaint word %q: full, lean, or nothing for the newest reading"):format(word))
		return
	end

	local newest
	local entries=type(A.debugEntries)=="function"and A.debugEntries()or{}
	for i=1,#entries do
		local entry=entries[i]
		if entry.cat=="ui"and entry.ev=="cost"
			and(newest==nil or(tonumber(entry.seq)or 0)>(tonumber(newest.seq)or 0))then
			newest=entry
		end
	end
	if not newest then
		A.say(("repaint %s. no switch is on the ring: /pvph debug on records the next one")
			:format(A.repaintMode()))
		return
	end
	A.say(("repaint %s. newest switch: %s to %s, total %s, unbracketed %s, frame1 %s, frame3 %s")
		:format(A.repaintMode(),tostring(newest.route),tostring(newest.to),costFigure(newest.total),
		costFigure(newest.unbracketed),costFigure(newest.frame1),costFigure(newest.frame3)))
end

local function scopeLabel(value)
	if type(A.scopeLabel)=="function"then
		return A.scopeLabel(value)
	end
	return tostring(value)
end

local function reportShowState(words)
	local tabs=type(A.tabList)=="function"
		and A.tabList(type(A.windowCharacter)=="function"and A.windowCharacter()or nil)or{}
	local want,id,unknown,any={},nil,{},false
	for i=2,#words do
		local word=words[i]:lower()
		local kind,value=showWord(word,tabs)
		if kind=="body"then
			want.body=BODY_WORDS[value].body
			want.view=BODY_WORDS[value].view
			any=true
		elseif kind then
			want[kind]=value
			if kind=="view"or kind=="card"then
				want.body="stats"
			end
			any=true
		elseif id==nil and A.matchIdFromWord(words[i])then
			id=A.matchIdFromWord(words[i])
		else
			unknown[#unknown+1]=words[i]
		end
	end
	if not any and#unknown==0 then
		return false
	end

	if#unknown>0 then
		local formats={}
		for i=2,#tabs do
			formats[#formats+1]=tostring(tabs[i].format)
		end
		A.say(("/pvph show: %q is not a match id, a tab, a body, a card or a scope, so nothing was opened")
			:format(unknown[1]))
		A.say("  tabs: all"..(#formats>0 and(", "..table.concat(formats,", "))or""))
		A.say("  bodies: matches, stats. cards: beats, where, worth, comp; comps lights comp, specs opens "
			.."the specs view, maps the Maps view, bests the Bests view and builds the Builds view. "
			.."scopes: season, season<n> for an earlier season, alltime, 180d, 90d, 30d, 7d, 3d, 1d")
		return true
	end

	local shown=type(A.showWindowState)=="function"and A.showWindowState(want)
	if not shown then
		A.say("the window could not be opened. /pvph list reads the stored matches in chat")
		return true
	end

	local viewLabel="History"
	local tableView=shown.body=="stats"and type(A.tableViewShowing)=="function"and A.tableViewShowing()
		or nil
	local maps=tableView~=nil
	local overview=shown.body=="stats"and shown.format==nil and not maps
	local specs=shown.body=="stats"and type(A.specsShowing)=="function"and A.specsShowing()
	if tableView=="zones"then
		viewLabel="Stats, Where you fight"
	elseif tableView=="bests"then
		viewLabel="Stats, the Bests view"
	elseif tableView=="builds"then
		viewLabel="Stats, the Builds view"
	elseif maps then
		viewLabel="Stats, the Maps view"
	elseif overview then
		viewLabel="Stats, every format"
	elseif specs then
		viewLabel="Stats, the specs view"
	elseif shown.body=="stats"then
		viewLabel="Stats, "..cardTitle(shown.card)
	end
	A.say(("showing %s, %s, %s"):format(A.formatLabel(shown.format),viewLabel,scopeLabel(shown.scope)))
	A.trace("scopeline",{format=shown.format,lineScope=tostring(shown.scope),
		boxScope=tostring(type(A.paintedScope)=="function"and A.paintedScope()or nil)},"ui")
	local asked=want.card or(want.view=="comps"and"comp")or nil
	if asked~=nil and shown.body=="stats"and not overview and asked~=shown.card then
		A.say(("%s draws nothing on this tab, so %s is lit"):format(cardTitle(asked),cardTitle(shown.card)))
	end
	if want.scope~=nil and want.scope~=(shown.stored or shown.scope)then
		A.say(("this tab has no ladder, so it reads the season as all time and %s was not stored")
			:format(scopeLabel(want.scope)))
	end
	if want.scope~=nil and type(A.scopePastSeason)=="function"and A.scopePastSeason(want.scope)
		and type(A.formatScope)=="function"and A.formatScope(shown.format)=="season"then
		A.say(("this tab holds no match from %s, so it reads This season"):format(scopeLabel(want.scope)))
	end

	if id then
		if not A.match(id)then
			A.say(("no stored match with id %s. /pvph list to see what is held"):format(tostring(id)))
		else
			A.selectMatch(id)
		end
	end
	return true
end

local function reportShow(db,id)
	if id then
		if not A.match(id)then
			A.say(("no stored match with id %s. /pvph list to see what is held"):format(tostring(id)))
			return
		end
		if not A.selectMatch(id)then
			A.say("the window could not be opened, so the match cannot be shown there. /pvph "
				..tostring(id).." prints it")
		end
		return
	end

	if A.showWindow()then
		return
	end

	A.say("the window could not be opened. /pvph list reads the stored matches in chat")
	reportStatus(db)
end

local APPEARANCE_WORDS={game="blizzard",dark="flat"}

local function appearanceLabel(name)
	local choices=type(A.themeChoices)=="function"and A.themeChoices()or{}
	for i=1,#choices do
		if choices[i].value==name then
			return choices[i].label
		end
	end
	return tostring(name)
end

local function reportAppearance(word)
	if word=="stored"then
		A.holdTheme(nil)
		A.say(("the appearance held for this session is released: %s, as stored")
			:format(appearanceLabel(A.storedTheme())))
		return
	end

	local name=word and APPEARANCE_WORDS[word]
	if name then
		A.holdTheme(name)
		A.say(("appearance held for this session: %s. /pvph appearance stored puts back the stored one")
			:format(appearanceLabel(name)))
		return
	end

	if word then
		A.say(("unknown appearance %q. game, dark or stored"):format(word))
		return
	end

	local held=A.heldTheme()
	if held then
		A.say(("the appearance is %s, held for this session over %s as stored")
			:format(appearanceLabel(held),appearanceLabel(A.storedTheme())))
	else
		A.say(("the appearance is %s, as stored"):format(appearanceLabel(A.theme())))
	end
end

local function reportOptions(word,target,tail)
	if word=="client"then
		local opened,why=A.openOptions()
		if opened then
			return
		end
		if why=="combat"then
			A.say("the client's settings panel cannot be opened in combat. /pvph options opens this "
				.."addon's own settings, which carry the same switches")
			return
		end
		A.say("the client's settings panel could not be opened. /pvph options opens this addon's "
			.."own settings")
		return
	end

	if word=="find"then
		local text=tail or""
		local left=A.optionsFind(text)
		if text==""then
			A.say("the settings find box is cleared")
		elseif left==nil then
			A.say(("the settings find box holds %q; the rows show when the settings open"):format(text))
		else
			A.say(("the settings find box holds %q: %d %s left"):format(text,left,
				left==1 and"row"or"rows"))
		end
		return
	end
	if word=="slot"then
		local slot=target=="latest"and"current"or target
		if A.optionsChooseSlot(slot)then
			A.say(("the restore card reads the %s copy"):format(A.restoreSlotName(slot):lower()))
		else
			A.say("/pvph options slot takes latest or pinned")
		end
		return
	end

	if word=="close"then
		if type(A.optionsWindowShown)=="function"and A.optionsWindowShown()then
			A.hideOptionsWindow()
			A.say("the settings are closed")
		else
			A.say("the settings are not open")
		end
		return
	end

	local sections=type(A.optionsSections)=="function"and A.optionsSections()or{}
	if word~=nil then
		local known=false
		for i=1,#sections do
			if sections[i]==word then
				known=true
			end
		end
		if known then
			if word=="all"and target~=nil and A.optionsPageFor(target,nil)==nil then
				A.say(("unknown page %q: %s"):format(target,table.concat(sections,", ")))
				return
			end
			if not A.withTypedSwitch(function()
				return A.showOptionsSection(word,target)
			end)then
				A.say("the settings could not be opened. /pvph options client opens the "
					.."game's own panel")
			end
			return
		end
		A.say(("unknown options command %q. client opens the game's own panel, and a page opens "
			.."the settings on it: %s"):format(word,table.concat(sections,", ")))
		return
	end

	local where,why=A.withTypedSwitch(A.toggleSettings)
	if where=="window"or where=="closed"then
		return
	end
	if where=="client"then
		A.say("the settings could not be built, so the client's own panel is shown instead")
		return
	end
	if why=="combat"then
		A.say("the settings could not be opened: they would not build and the client's "
			.."settings panel cannot be opened in combat. /pvph alert and /pvph minimap set the "
			.."same switches, and /pvph size reads the storage")
		return
	end
	A.say("the settings could not be opened. /pvph alert and /pvph minimap set the same "
		.."switches, and /pvph size reads the storage")
end

local function minimapPlace(state)
	if state.free then
		return("placed freely at %.2f, %.2f"):format(A.unitFigure(state.free.x)or state.free.x,
			A.unitFigure(state.free.y)or state.free.y)
	end
	return("at %s on the minimap's edge"):format(A.minimapAngleText(state.angle)or tostring(state.angle))
end

local function minimapShownText(state)
	if not state.shown then
		return"hidden"
	end
	return state.built and"shown"or"shown, not built"
end

local function reportMinimap(word)
	local state=A.minimapState()

	if not state.available then
		A.say("no minimap on this client, so the button could not be built. /pvph show opens the "
			.."window")
		return
	end

	if word=="reset"then
		if A.resetMinimap()then
			A.say("minimap button reset to its default position and shown")
		else
			A.say("the minimap button could not be built on this client")
		end
		return
	end

	if word=="show"or word=="hide"then
		local wanted=word=="show"
		if A.setMinimapShown(wanted)then
			A.say("minimap button "..(wanted and"shown"or"hidden"))
		else
			A.say("the minimap button could not be built on this client")
		end
		return
	end

	if word=="where"then
		A.say(("minimap button %s, %s"):format(minimapShownText(state),minimapPlace(state)))
		return
	end

	if word then
		A.say(("unknown minimap command %q. show, hide, reset or where"):format(word))
		return
	end

	local wanted=not state.shown
	if A.setMinimapShown(wanted)then
		local after=A.minimapState()
		A.say(("minimap button %s, %s"):format(minimapShownText(after),minimapPlace(after)))
	else
		A.say("the minimap button could not be built on this client. /pvph show opens the window")
	end
end

local function reportLogin(word)
	if word=="on"or word=="off"then
		local wanted=word=="on"
		if not A.setLoginLine(wanted)then
			A.say("no database, so the setting could not be stored")
			return
		end
		A.say("the line at login "..(wanted and"on"or"off"))
		return
	end

	if word then
		A.say(("unknown login command %q. on or off"):format(word))
		return
	end

	local was=A.loginLineEnabled()
	if not A.setLoginLine(not was)then
		A.say("no database, so the setting could not be stored")
		return
	end
	A.say(("the line at login %s, from %s"):format(was and"off"or"on",was and"on"or"off"))
end

local function reportAlert(word)
	if word=="on"or word=="off"then
		local wanted=word=="on"
		if not A.setAlerts(wanted)then
			A.say("no database, so the setting could not be stored")
			return
		end
		A.say("group and match alerts "..(wanted and"on"or"off"))
		return
	end

	if word then
		A.say(("unknown alert command %q. on or off"):format(word))
		return
	end

	local was=A.alertsEnabled()
	if not A.setAlerts(not was)then
		A.say("no database, so the setting could not be stored")
		return
	end
	A.say(("group and match alerts %s, from %s"):format(was and"off"or"on",
		was and"on"or"off"))
end

local function reportPostGame(word)
	if word=="on"or word=="off"then
		local wanted=word=="on"
		if not A.setPostGame(wanted)then
			A.say("no database, so the setting could not be stored")
			return
		end
		A.say("the chat after a match "..(wanted and"on"or"off"))
		return
	end

	if word then
		A.say(("unknown postgame command %q. on or off"):format(word))
		return
	end

	local was=A.postGameEnabled()
	if not A.setPostGame(not was)then
		A.say("no database, so the setting could not be stored")
		return
	end
	A.say(("the chat after a match %s, from %s"):format(was and"off"or"on",
		was and"on"or"off"))
end

local function reportTooltip(word)
	if word=="on"or word=="off"then
		local wanted=word=="on"
		local was=A.tooltipEnabled()
		if not A.setTooltip(wanted)then
			A.say("no database, so the setting could not be stored")
			return
		end
		A.say(("the unit tooltip lines %s, from %s"):format(wanted and"on"or"off",
			was and"on"or"off"))
		return
	end

	if word then
		A.say(("unknown tooltip command %q. on or off"):format(word))
		return
	end

	local was=A.tooltipEnabled()
	if not A.setTooltip(not was)then
		A.say("no database, so the setting could not be stored")
		return
	end
	A.say(("the unit tooltip lines %s, from %s"):format(was and"off"or"on",
		was and"on"or"off"))
end

local function reportGroupNotes(word)
	local function dependency()
		if not A.groupNotesAvailable()then
			A.say("the group and match alerts are off, so no note line can print. /pvph alert on")
		end
	end

	if word=="on"or word=="off"then
		local wanted=word=="on"
		local was=A.groupNotesEnabled()
		if not A.setGroupNotes(wanted)then
			A.say("no database, so the setting could not be stored")
			return
		end
		A.say(("what was written on who joined %s, from %s"):format(wanted and"on"or"off",
			was and"on"or"off"))
		if wanted then
			dependency()
		end
		return
	end

	if word then
		A.say(("unknown groupnotes command %q. on or off"):format(word))
		return
	end

	local was=A.groupNotesEnabled()
	if not A.setGroupNotes(not was)then
		A.say("no database, so the setting could not be stored")
		return
	end
	A.say(("what was written on who joined %s, from %s"):format(was and"off"or"on",
		was and"on"or"off"))
	if not was then
		dependency()
	end
end

local function reportAnnounceFigure(word,figure)
	local time=word=="time"
	local opacity=word=="opacity"

	local min,max,step,was
	if time then
		min,max,step=A.announceTimeRange()
		was=A.announceTime()
	elseif opacity then
		min,max,step=A.announceOpacityRange()
		was=A.announceOpacity()
	else
		min,max,step=A.announceSizeRange()
		was=A.announceSize()
	end
	local want=decimalArgument(figure)

	if want==nil then
		if figure~=nil then
			A.say(("%q is not a number. /pvph announce %s takes %d to %d in steps of %d")
				:format(tostring(figure),word,min,max,step))
			return
		end

		if time then
			A.say(("the announcement stays up for %s%% of its length, so a full banner lasts %s "
				.."seconds"):format(tostring(was),tostring(A.announceFullSeconds())))
			return
		end

		if opacity then
			A.say(("the announcement plate is drawn at %s%% opacity"):format(tostring(was)))
			return
		end

		local drew=A.announcePreviewActive()and A.announceDrawnSize()or nil
		if drew~=nil and drew<was then
			A.say(("the announcement is drawn at %s%%, and the preview on screen fits at %s%%")
				:format(tostring(was),tostring(drew)))
			return
		end
		A.say(("the announcement is drawn at %s%%"):format(tostring(was)))
		return
	end

	local stored,now
	if time then
		stored=A.setAnnounceTime(want)
		now=A.announceTime()
	elseif opacity then
		stored=A.setAnnounceOpacity(want)
		now=A.announceOpacity()
	else
		stored=A.setAnnounceSize(want)
		now=A.announceSize()
	end
	if not stored then
		A.say(("%s is not one this takes. /pvph announce %s takes %d to %d in steps of %d")
			:format(tostring(figure),word,min,max,step))
		return
	end
	A.say(("the announcement %s is %s%%, from %s%%"):format(word,tostring(now),tostring(was)))
end

local SHAPE_WORDS={side="split",column="stacked"}

local function shapeWords(value)
	local choices=A.announceShapeChoices()
	for i=1,#choices do
		if choices[i].value==value then
			return choices[i].label,choices[i].said
		end
	end
	return tostring(value),tostring(value)
end

local function reportAnnounceShape(word)
	if word=="stored"then
		A.holdAnnounceShape(nil)
		A.say(("the announcement shape held for this session is released: %s, as stored")
			:format((shapeWords(A.announceStoredShape()))))
		return
	end

	local value=word and SHAPE_WORDS[word]
	if value then
		A.holdAnnounceShape(value)
		A.say(("announcement shape held for this session: %s. /pvph announce shape stored puts back "
			.."the stored one"):format((shapeWords(value))))
		return
	end

	if word then
		A.say(("unknown announcement shape %q. side, column or stored"):format(word))
		return
	end

	local _,said=shapeWords(A.announceShape())
	if A.announceHeldShape()then
		A.say(("the announcement draws %s, held for this session over %s as stored")
			:format(said,(shapeWords(A.announceStoredShape()))))
	else
		A.say(("the announcement draws %s, as stored"):format(said))
	end
end

local function reportAnnounceLock(verb,word)
	local function said(locked)
		return locked and"locked"or"unlocked"
	end

	if verb=="lock"and word=="stored"then
		A.holdAnnounceLocked(nil)
		A.say(("the announcement lock held for this session is released: %s, as stored")
			:format(said(A.announceStoredLocked())))
		return
	end

	if word then
		A.say(("unknown announcement lock word %q. /pvph announce lock stored releases a hold")
			:format(word))
		return
	end

	if verb=="unlock"then
		A.holdAnnounceLocked(false)
		A.say("announcement held unlocked for this session: a match banner can be dragged while it is "
			.."up. /pvph announce lock stored puts back the stored setting")
		return
	end

	if A.announceHeldLocked()~=nil or not A.announceStoredLocked()then
		A.holdAnnounceLocked(true)
		A.say(("announcement held locked for this session, over %s as stored. /pvph announce lock "
			.."stored puts back the stored setting"):format(said(A.announceStoredLocked())))
		return
	end

	A.say(("the announcement is %s, as stored"):format(said(A.announceStoredLocked())))
end

local function reportAnnounce(word,figure)
	if word=="lock"or word=="unlock"then
		reportAnnounceLock(word,figure and figure:lower()or nil)
		return
	end

	if word=="time"or word=="size"or word=="opacity"then
		reportAnnounceFigure(word,figure)
		return
	end

	if word=="shape"then
		reportAnnounceShape(figure and figure:lower()or nil)
		return
	end

	if word=="preview"then
		local how=figure and figure:lower()or nil
		if how=="full"then
			A.announcePreviewFull(true)
			if A.announcePreview()then
				A.say("the announcement preview draws fifteen players, eight against and seven with, for this "
					.."session. /pvph announce preview puts back the eight")
			else
				A.say("the preview could not be drawn on this client")
			end
			return
		end
		if how~=nil then
			A.say(("unknown preview word %q. full, or nothing"):format(how))
			return
		end
		if A.announcePreviewFullHeld()then
			A.announcePreviewFull(false)
			if A.announcePreview()then
				A.say("the announcement preview is back to its eight players")
			else
				A.say("the preview could not be drawn on this client")
			end
			return
		end
		local toggled=A.announcePreviewToggle()
		if toggled=="ended"then
			A.say("the preview is put away and the position it was dragged to is kept. "
				.."/pvph announce reset is what puts it back")
		elseif toggled=="shown"then
			A.say("the roster announcement is drawn where it draws. Drag it, and Escape or "
				.."/pvph announce preview puts it away. /pvph announce reset puts it back")
		else
			A.say("the preview could not be drawn on this client")
		end
		return
	end

	if word=="reset"then
		if A.resetAnnouncePosition()then
			A.say("the roster announcement is back a sixth of the screen down")
		else
			A.say("no database, so the position could not be cleared")
		end
		return
	end

	if word=="on"or word=="off"then
		local wanted=word=="on"
		local was=A.announceEnabled()
		if not A.setAnnounce(wanted)then
			A.say("no database, so the setting could not be stored")
			return
		end
		A.say(("the roster announcement %s, from %s"):format(wanted and"on"or"off",
			was and"on"or"off"))
		return
	end

	if word then
		A.say(("unknown announce command %q. on, off, preview, reset, time, size, opacity, shape, "
			.."lock or unlock"):format(word))
		return
	end

	local was=A.announceEnabled()
	if not A.setAnnounce(not was)then
		A.say("no database, so the setting could not be stored")
		return
	end
	A.say(("the roster announcement %s, from %s"):format(was and"off"or"on",
		was and"on"or"off"))
end

local function reportOverlayFigure(word,figure)
	local count=word=="count"
	local min,max,step,was
	if count then
		min,max,step=A.overlayCountRange()
		was=A.overlayCount()
	else
		min,max,step=A.overlayOpacityRange()
		was=A.overlayOpacity()
	end

	if figure==nil then
		if count then
			A.say(("the results overlay shows %d matches. /pvph overlay count takes %d to %d")
				:format(was,min,max))
		else
			A.say(("the results overlay's background is drawn at %d%% opacity. /pvph overlay opacity "
				.."takes %d to %d in steps of %d"):format(was,min,max,step))
		end
		return
	end

	local range=count and""or(" in steps of %d"):format(step)
	local want=decimalArgument(figure)
	if want==nil then
		A.say(("%q is not a number. /pvph overlay %s takes %d to %d%s"):format(tostring(figure),word,
			min,max,range))
		return
	end

	if count then
		want=wholeArgument(figure,-math.huge)
	end
	if want==nil then
		A.say(("%s is not one this takes. /pvph overlay %s takes %d to %d%s"):format(tostring(figure),
			word,min,max,range))
		return
	end

	local stored=count and A.setOverlayCount(want)or(not count and A.setOverlayOpacity(want))
	if not stored then
		A.say("no database, so the setting could not be stored")
		return
	end
	if count then
		A.say(("the results overlay shows %d matches, from %d"):format(A.overlayCount(),was))
	else
		A.say(("the results overlay's background is drawn at %d%% opacity, from %d%%")
			:format(A.overlayOpacity(),was))
	end
end

local function reportOverlay(word,figure,extra)
	if word==nil then
		local lines=A.overlayReadout()
		for i=1,#lines do
			A.say(lines[i])
		end
		return
	end

	if word=="count"or word=="opacity"then
		reportOverlayFigure(word,figure)
		return
	end

	if word=="combat"then
		local second=figure and figure:lower()or nil
		if second=="on"or second=="off"then
			local wanted=second=="on"
			local was=A.overlayCombat()
			if not A.setOverlayCombat(wanted)then
				A.say("no database, so the setting could not be stored")
				return
			end
			A.say(("the results overlay hides in combat: %s, from %s"):format(wanted and"on"or"off",
				was and"on"or"off"))
			return
		end
		if second~=nil then
			A.say(("unknown overlay combat word %q. on or off"):format(second))
			return
		end
		A.say(("the results overlay hides in combat: %s"):format(A.overlayCombat()and"on"or"off"))
		return
	end

	if word=="preview"then
		local second=figure and figure:lower()or nil
		if second=="opacity"then
			local held=A.overlayPreviewOpacity(extra)
			local min,max=A.overlayOpacityRange()
			if held then
				A.say(("the results overlay's background is drawn at %d%% for this session"):format(held))
			elseif extra==nil then
				A.say(("/pvph overlay preview opacity takes a percentage from %d to %d"):format(min,max))
			else
				A.say(("%q is not an opacity. /pvph overlay preview opacity takes %d to %d")
					:format(extra,min,max))
			end
			return
		end
		if second~=nil and second~="off"then
			if A.overlayPreviewFormat(second)then
				A.say(("the results overlay is drawn on %s for this session. /pvph overlay preview off "
					.."puts it away"):format(A.formatLabel(second)))
			else
				A.say(("%q is not a stored format. /pvph overlay preview takes a format such as shuffle, "
					.."arena2 or arena-unrated"):format(second))
			end
			return
		end
		if second=="off"then
			if A.overlayPreview(false)=="ended"then
				A.say("the results overlay preview is put away")
			else
				A.say("no results overlay preview is up")
			end
			return
		end
		local shown=A.overlayPreview(true)
		if shown=="shown"then
			A.say("the results overlay is drawn where it draws, for this session. /pvph overlay preview "
				.."off puts it away")
		elseif shown=="held"then
			A.say("the results overlay preview is already up. /pvph overlay preview off puts it away")
		else
			A.say("the results overlay could not be drawn on this client")
		end
		return
	end

	if word=="on"or word=="off"then
		local wanted=word=="on"
		local was=A.overlayEnabled()
		if not A.setOverlay(wanted)then
			A.say("no database, so the setting could not be stored")
			return
		end
		A.say(("the results overlay %s, from %s"):format(wanted and"on"or"off",
			was and"on"or"off"))
		return
	end

	if word=="hover"then
		local second=figure and figure:lower()or nil
		if second=="off"then
			A.overlayHover(nil)
			A.say("results overlay hover hidden")
			return
		end
		local index=wholeArgument(second)
		if index==nil then
			if figure==nil then
				A.say("/pvph overlay hover takes a tile number from 1, or off")
			else
				A.say(("/pvph overlay hover takes a tile number from 1, or off, and %q is neither"):format(figure))
			end
			return
		end
		local outcome,detail=A.overlayHover(index)
		if outcome=="shown"then
			A.say(("tile %d: #%s hover shown"):format(index,tostring(detail)))
		elseif detail=="no-bar"then
			A.say("the results overlay is not up. /pvph overlay preview holds it up for this session")
		elseif detail=="no-tile"then
			A.say(("the results overlay draws no tile %d"):format(index))
		else
			A.say(("tile %d's match drew no hover"):format(index))
		end
		return
	end

	A.say(("unknown overlay command %q. on, off, count, opacity, combat, preview or hover"):format(word))
end

local function reportContextMenu(word)
	if word=="on"or word=="off"then
		local wanted=word=="on"
		local was=A.contextMenuEnabled()
		if not A.setContextMenu(wanted)then
			A.say("no database, so the setting could not be stored")
			return
		end
		A.say(("the right-click menu entry %s, from %s"):format(wanted and"on"or"off",
			was and"on"or"off"))
		return
	end

	if word then
		A.say(("unknown menu command %q. on or off"):format(word))
		return
	end

	local was=A.contextMenuEnabled()
	if not A.setContextMenu(not was)then
		A.say("no database, so the setting could not be stored")
		return
	end
	A.say(("the right-click menu entry %s, from %s"):format(was and"off"or"on",
		was and"on"or"off"))
end

local function reportDuel(word)
	if word=="on"or word=="off"then
		local wanted=word=="on"
		local was=A.duelsEnabled()
		if not A.setDuels(wanted)then
			A.say("no database, so the setting could not be stored")
			return
		end
		A.say(("duel recording %s, from %s"):format(wanted and"on"or"off",
			was and"on"or"off"))
		return
	end

	if word then
		A.say(("unknown duel command %q. on or off"):format(word))
		return
	end

	local state=A.duelState()
	A.say("duel recording "..(state.enabled and"on"or"off"))
	A.say(A.duelPatternLine(state))
	A.say(("%d system line%s refused as unreadable this session"):format(state.refused,
		state.refused==1 and""or"s"))
	if state.pending then
		A.say("a duel request is open, and its time is what a duration would be measured from")
	end
end

local function reportHold(word,sub,figure)
	if word=="preview"then
		local wanted=type(sub)=="string"and sub:lower()or nil
		local drawn,why=A.holdPreview(wanted,figure)
		local state=A.holdPreviewState()
		if drawn=="off"then
			A.say("hold preview off")
		elseif drawn~=nil and state~=nil then
			A.say(("hold preview: %s, over a stand-in at the center of the screen. Nothing stored")
				:format(state.text or drawn))
		elseif why=="holding"then
			A.say("the exit is held for a match now, so no preview is drawn over it")
		elseif why=="seconds"then
			A.say(("hold preview saving takes seconds from 0 to %d"):format(A.holdCap()))
		elseif why=="no-match"then
			A.say("no stored match, so the saved preview has no number to draw")
		elseif why=="none"then
			A.say("no hold preview is up")
		elseif why=="no-frame"then
			A.say("this client built no frame for the preview")
		elseif why=="missing"then
			A.say("/pvph hold preview takes saving [seconds], saved or off")
		else
			A.say(("unknown hold preview word %q. saving [seconds], saved or off"):format(tostring(sub)))
		end
		return
	end

	if word=="on"or word=="off"then
		local wanted=word=="on"
		local was=A.holdEnabled()
		if not A.setHold(wanted)then
			A.say("no database, so the setting could not be stored")
			return
		end
		A.say(("exit hold %s, from %s"):format(wanted and"on"or"off",was and"on"or"off"))
		return
	end

	if word then
		A.say(("unknown hold command %q. on, off or preview"):format(word))
		return
	end

	A.say("exit hold "..(A.holdEnabled()and"on"or"off"))
	A.say(("the leave button is covered for at most %d seconds after a match ends, and released once "
		.."the record is stored"):format(A.holdCap()))
	local state=A.holdPreviewState()
	A.say(("preview: %s. preview saving [seconds], saved or off draws the cover for this session")
		:format(state and state.text or"none"))
end

local function reportTab(word)
	if word=="remember"or word=="all"then
		local wanted=word=="remember"
		local was=A.rememberTab()
		if not A.setRememberTab(wanted)then
			A.say("no database, so the setting could not be stored")
			return
		end
		A.say(("the selected tab is %s, from %s"):format(wanted and"remembered"or"not remembered",
			was and"remembered"or"not remembered"))
		return
	end

	if word then
		A.say(("unknown tab command %q. remember or all"):format(word))
		return
	end

	A.say("the selected tab is "..(A.rememberTab()and"remembered"or"not remembered"))
	local opens=A.storedTab()
	A.say(("the window opens on %s"):format(opens and A.formatLabel(opens)or"every format"))
end

local DEBUG_SHOW=20

local function sayDebugTextState()
	local on=A.debugTextEnabled()
	A.say(("debug detail on screen is %s. /pvph debug text %s")
		:format(on and"on"or"off",on and"off"or"on"))
end

local function sampleRecord(word,text)
	if text==nil then
		A.say(("debug %s needs a match: last or an id"):format(word))
		return nil
	end
	local record
	if text:lower()=="last"then
		record=A.matches()[1]
	else
		local id=A.matchIdFromWord(text)
		record=id and A.match(id)or nil
	end
	if record==nil then
		A.say(("debug %s: the sandbox holds no match %q. /pvph debug fixture fills it"):format(word,text))
	end
	return record
end

local function sampleGuids(word,names)
	local index=A.playerNameIndex()
	local guids={}
	for i=1,#names do
		local guid=A.playerByName(index,names[i])
		if guid==nil then
			A.say(("debug %s: no player in the sandbox is named %q, so nothing was drawn"):format(word,names[i]))
			return nil
		end
		guids[#guids+1]=guid
	end
	return guids
end

local function onOff(enabled)
	return enabled and"on"or"off"
end

local function reportSample(word,words)
	if not A.sandboxed()then
		A.say(("debug %s draws from generated players only, so it needs the sandbox. /pvph debug sandbox "
			.."first"):format(word))
		return
	end
	local args={}
	for i=3,#(words or{})do
		args[#args+1]=words[i]
	end

	if word=="announce"then
		local record=sampleRecord(word,args[1])
		if record and not A.announceFromRecord(record)then
			A.say(("debug announce: nobody on match %s is in the history, so nothing was drawn")
				:format(tostring(record.id)))
		end
		return
	end

	if word=="tooltip"then
		if args[1]==nil then
			A.say(A.tooltipSampleHide()and"the sample tooltip is hidden"or"no sample tooltip is up")
			return
		end
		local guids=sampleGuids(word,{args[1]})
		if guids then
			local n=A.tooltipSample(guids[1],args[1])
			A.say(n==nil and"debug tooltip: the client has no game tooltip"
				or("debug tooltip: %s, %d %s added"):format(args[1],n,n==1 and"line"or"lines"))
		end
		return
	end

	local alerts,groupNotes=onOff(A.alertsEnabled()),onOff(A.groupNotesEnabled())

	if word=="group"then
		if#args==0 then
			A.say("debug group needs one or more names")
			return
		end
		local guids=sampleGuids(word,args)
		if guids then
			local known,noted=A.sayGroupLines(guids,nil,true)
			A.trace("alert",{source="sample",reason="group",n=#guids,found=known.found,
				noted=noted,alerts=alerts,groupNotes=groupNotes})
		end
		return
	end

	local record=sampleRecord(word,args[1])
	if record==nil then
		return
	end
	local rows,own=A.recordRows(record)
	local known,resolved,noted=A.sayGatesLines(rows,own,nil,nil,true)
	if not known then
		A.say(("debug gates: match %s has no side to read (%s)"):format(tostring(record.id),tostring(resolved)))
		A.trace("alert",{source="sample",reason=resolved,id=record.id,n=#rows,alerts=alerts,
			groupNotes=groupNotes})
		return
	end
	A.trace("alert",{source="sample",reason="gates",id=record.id,n=known.offered,
		found=known.found,noted=noted,alerts=alerts,groupNotes=groupNotes})
end

local function reportDebug(word,one,two,words)
	if word=="show"then
		local extra=words and words[5]
			or(one~=nil and two~=nil and tonumber(one)~=nil and tonumber(two)~=nil and two)or nil
		if extra~=nil then
			refuseUnread(extra,"/pvph debug show [cat] [n]  takes one category and one count")
			return
		end
		local cat,countWord=nil,one
		if one~=nil and tonumber(one)==nil then
			cat,countWord=one:lower(),two
		elseif two~=nil and tonumber(two)==nil then
			cat=two:lower()
		end
		local count=wholeArgument(countWord)
		if countWord~=nil and count==nil then
			A.say(("/pvph debug show [cat] [n]: n is a whole number of entries from 1, and %q is not one")
				:format(tostring(countWord)))
			return
		end

		if cat~=nil and not A.debugCategory(cat)then
			A.say(("unknown debug category %q. %s"):format(cat,
				table.concat(A.debugCategories(),", ")))
			return
		end

		local lines=A.debugLines(count or DEBUG_SHOW,cat)
		if#lines==0 then
			local total=A.debugHeld()
			if cat~=nil and total>0 then
				A.say(("the debug ring holds %d %s and none of them is %s")
					:format(total,total==1 and"entry"or"entries",cat))
			elseif not A.debugEnabled()then
				A.say("the debug ring is off and holds nothing. /pvph debug on starts it")
			else
				A.say("the debug ring is on and holds nothing, which means the login entry did not "
					.."run. /reload and read it again")
			end
			return
		end
		for i=1,#lines do
			A.say(lines[i])
		end
		A.say(("%d of %d %sheld, oldest first%s"):format(#lines,A.debugHeld(cat),
			cat and(cat.." ")or"",
			A.debugEnabled()and""or", and the ring is off"))
		A.say("held per category: "..A.debugCensusLine())
		return
	end

	if word=="clear"then
		local cat=one and one:lower()or nil
		if two~=nil then
			refuseUnread(two,"/pvph debug clear [cat]  takes one category, or none for the whole ring")
			return
		end
		if cat~=nil and not A.debugCategory(cat)then
			A.say(("unknown debug category %q. %s"):format(cat,
				table.concat(A.debugCategories(),", ")))
			return
		end

		local cleared=A.debugClear(cat)
		A.say(("debug ring cleared%s, %d %s dropped. The sequence carries on where it was")
			:format(cat and(" of "..cat)or"",cleared,cleared==1 and"entry"or"entries"))
		return
	end

	if word=="export"then
		A.openDebugExport()
		return
	end

	if word=="on"or word=="off"then
		local wanted=word=="on"
		if not A.setDebug(wanted)then
			A.say("no database, so the setting could not be stored")
			return
		end
		A.say("debug ring "..(wanted and"on"or"off"))
		sayDebugTextState()
		return
	end

	if word=="fault"then
		if not A.debugEnabled()then
			A.say("the debug ring is off, and the staged fault panel is an instrument. /pvph debug on first")
			return
		end
		local _,outcome=A.stageNotesFault()
		A.say(outcome)
		return
	end

	if word=="fixture"then
		if not A.debugEnabled()and not A.sandboxed()then
			A.say("the debug ring is off, and the fixture is an instrument. /pvph debug on first")
			return
		end
		local fixtureWords={}
		for i=2,#(words or{})do
			fixtureWords[#fixtureWords+1]=words[i]
		end
		reportFixture(fixtureWords)
		return
	end

	if word=="sandbox"then
		local refusal=A.fixtureRefusal(0)
		if refusal~=nil and refusal~="too-many"then
			A.trace("sandbox",{state="refused",reason=refusal},"data")
			A.say("sandbox: "..A.fixtureRefusalText(refusal))
			return
		end
		local held=A.startSandbox()
		A.trace("sandbox",{state="started",n=#held.matches},"data")
		A.say(("sandbox: this session reads a store of %d matches, and the saved history is untouched. "
			.."/pvph debug fixture fills it; /reload ends it"):format(#held.matches))
		return
	end

	if word=="text"then
		one=one and one:lower()or nil
		if one~=nil and one~="on"and one~="off"then
			A.say(("unknown debug text command %q. on, off, or nothing to toggle"):format(one))
			return
		end
		local was=A.debugTextEnabled()
		local wanted
		if one=="on"then
			wanted=true
		elseif one=="off"then
			wanted=false
		else
			wanted=not was
		end
		if not A.setDebugText(wanted)then
			A.say("no database, so the setting could not be stored")
			return
		end
		A.say(("debug detail on screen %s, from %s")
			:format(wanted and"on"or"off",was and"on"or"off"))
		return
	end

	if word=="announce"or word=="tooltip"or word=="group"or word=="gates"then
		reportSample(word,words)
		return
	end

	if word then
		A.say(("unknown debug command %q. on, off, text, show, clear, export, fault, fixture or sandbox; "
			.."in the sandbox announce, tooltip, group or gates"):format(word))
		return
	end

	local was=A.debugEnabled()
	if not A.setDebug(not was)then
		A.say("no database, so the setting could not be stored")
		return
	end
	A.say(("debug ring %s, from %s"):format(was and"off"or"on",was and"on"or"off"))
	sayDebugTextState()
end

local USAGE={
	"/pvph                the match history window",
	"/pvph help           this list. commands is the same word",
	"/pvph show [id]      the same window, on one match when an id is given. last is the newest,",
	"                     last <format> the newest of one format, world among them",
	"/pvph show <words>   on a tab, a half, a card and a scope: all or a format, matches stats,",
	"                     beats where worth comp (comps specs maps bests builds ask), season season<n> alltime",
	"                     180d 90d 30d 7d 3d 1d, in any order",
	"/pvph status         what is held: version, counts, the last match, the drops",
	"/pvph options        the settings, and closes them from there. client opens the game's own panel",
	"/pvph options <page> the settings on one page: general, alerts, notes, recording, data or",
	"                     diagnostic. The older words all, window, minimap, history and storage",
	"                     still open the page that holds their rows",
	"/pvph options close  closes the window from the settings, as Escape does",
	"/pvph options find [words]  sets the settings' find box for this session; bare clears it",
	"/pvph options slot <latest||pinned>  the copy the restore card reads, for this session",
	"/pvph about          the window on its About tab: the name, the version and the license",
	"/pvph about copy     the About tab with the website's copy box open",
	"/pvph appearance     which appearance draws. game or dark holds one for this session, stored ends it",
	"/pvph tab            whether the window opens on the tab last selected. remember or all",
	"/pvph minimap        show or hide the minimap button. reset puts it back, where says where it sits",
	"/pvph alert          name who in a group or a finished match is already in the history",
	"/pvph login          name the loaded version at every load. on or off",
	"/pvph groupnotes     show the rating and the note on who joins, under the alerts",
	"/pvph announce       name who you know across the screen when a match's roster resolves",
	"                     preview draws a sample to drag; reset puts it back",
	"                     preview full draws fifteen for this session, so a side wraps",
	"                     time [percent] how long it stays up; size [percent] how large it draws",
	"                     opacity [percent] how dark the ground behind each name is",
	"                     shape side or column holds one for this session, stored ends it",
	"                     lock or unlock holds one for this session, lock stored ends it",
	"/pvph overlay        a bar of the newest results of the format last played. on or off;",
	"                     bare prints the settings and the ids it draws, newest first",
	"                     count <4-10> how many; opacity <0-100> how dark the background is",
	"                     combat on or off hides it in combat; preview holds it up for this",
	"                     session without storing, preview off puts it away",
	"                     preview <format> holds it on that stored format for this session;",
	"                     preview opacity <0-100> draws the background so for this session",
	"                     hover <n> shows tile n's tooltip as a pointer would; hover off hides it",
	"/pvph postgame       the lines after a match or a duel. on or off; a fault still prints",
	"/pvph aftermatch     open the match's window once its instance is left. on or off; bare reads it",
	"/pvph closeall       close every match and player window with the main window. on or off; bare reads it",
	"/pvph sight          mark and name a player you wrote about when they appear. on or off; bare reads it",
	"/pvph chatmark       a bar before the name of a player you wrote about in chat. on, off or sample; bare reads it",
	"/pvph menu           write a note and a rating from the player right-click menu",
	"/pvph tooltip        put the record, the last rating and the note on a unit tooltip",
	"/pvph duel           record completed duels. on or off, and what the readout can see",
	"/pvph hold           hold the exit while the scoreboard is read. on or off;",
	"                     preview saving [seconds], saved or off draws its cover for this session",
	"/pvph debug          record what the addon decides. on or off, show [cat] [n], clear [cat], export, fault",
	"/pvph debug text     show the harvest reading and the decoded columns on a match",
	"/pvph repaint        the newest switch's timing. full or lean sets how a switch repaints",
	"/pvph perf           what the addon takes of each frame, from the client's profiler",
	"/pvph perf trace     what one debug ring write takes; again after a switch counts its writes",
	"/pvph list [format]  the stored matches, newest first",
	"/pvph search <text>  narrow the match list to names, specs or a map; commas join terms, - excludes. No text clears it",
	"/pvph filter result <all||won||lost||even>  narrow the match list by result; all widens it again",
	"/pvph filter spec <spec||all>  narrow it to the spec you played. /pvph filter prints the choices and the count",
	"/pvph filter zone <zone||all>  narrow the World PvP list and its strip to one zone; all widens it again",
	"/pvph summary [fmt]  what a format adds up to: rating, win rate, length, counts, for the window's character and range",
	"/pvph summary <fmt> <n>  the same figures for one season",
	"/pvph comps [fmt] [n]  the enemy comps you have faced, worst first. n opens a row",
	"/pvph comps pairs [fmt] [n] | trios [fmt]  the enemy pairs, and the window on Pairs or back for this session; nothing is stored",
	"/pvph bests [fmt]    your bests per spec on a tab: damage, healing, peak rating and MMR, fastest win",
	"/pvph ask [format]   the cards the Stats half draws on that tab, over the stored scope",
	"/pvph ask sort <card> <met||won||default>  reorder one card's table, as a header click does",
	"/pvph ask open [n]   open row n of the lit card's table; no number closes it; refused under Where you fight, Maps, Bests, Builds or the All overview",
	"/pvph ask under <on||off>  show the rows under the floor after the ranked rows, for this session; refused under Where you fight, Maps, Bests, Builds or the All overview",
	"/pvph ask specs <on||off>  the specs view in place of the cards, for this session",
	"/pvph ask specs sort <column>  reorder the specs view, as a header click does",
	"/pvph fold <graph||details> <open||shut>  fold for this session; nothing is stored",
	"/pvph session [<n> <open||shut>]  each History session's key, count and fold, on All the grid lines drawn; n counts from the newest, held for this session",
	"/pvph finder [on||off||dock||undock||reset]  the group finder's season tooltip; all but reset hold for the session",
	"/pvph tiers          each rated format's PvP tiers and the rating each starts at",
	"/pvph region [fmt]   what the summary strip and graph work out to, block by block",
	"/pvph region list    the match list's edges and where each drawn element stands",
	"/pvph region band    where the History search box, its count and the three filters stand",
	"/pvph faults         checks that against what the models declare, and names what fails",
	"/pvph faults verbose the same, naming every family it checked on a clean run",
	"/pvph window [reset] each window's authored size, its smallest size and what is stored",
	"/pvph window size [players] <w> [h]  both halves' size: a number, min, max, authored or same.",
	"                     never stored; session says so",
	"/pvph window size match|player <w> [h]  the newest match or player window, this session, never stored",
	"/pvph window scale [<percent>||reset]  every window's scale. A percentage holds for this session and stores nothing; reset puts the setting back",
	"/pvph window scroll top  the History list back to its top. Holds nothing and stores nothing",
	"/pvph window scroll overview [top|bottom]  the All tab's Stats page moved to its top or bottom, or where it is. Holds nothing and stores nothing",
	"/pvph window store   the store panel. window player <who> opens that player's window",
	"/pvph window menu <id||last||draw||typed||short> [open||note||roster||print||talents||compare||result <win||loss||draw>]  a match row's menu, or one entry of it. menu close closes an open menu",
	"/pvph window hover [<id||last||left>]  the Shift tooltip on a match row where it is drawn; left takes the newest left-early row. No id hides it",
	"/pvph compare        the matches picked for comparing: count, format, base, each id in column order, and the boxes the last list paint drew",
	"/pvph compare add <id||last [n]>  pick a match; last n is the nth newest on the tab. remove <id> and clear take them out",
	"/pvph compare box <id||last [n]>  press a row's pick box as a click there does; last n is the nth newest of the newest match's type",
	"/pvph compare open   the Compare window over the picked matches. close shuts it and keeps them",
	"/pvph compare tab <figures||rounds>  open the Compare window's Figures tab or its second tab, Rounds and lobby or Lobby",
	"/pvph compare base <id>  make a picked match the base. rows prints each drawn row, its values, the best, each difference, the SAME IN ALL line, and on the second tab the rounds and each lobby row",
	"/pvph window round [n]  the hover over round n's card in the newest match window. No number hides it",
	"/pvph window dropdown [character||scope||result||spec]  open that dropdown's list. No word closes it",
	"/pvph window tile [rate||matches||mmr||length||last]  a summary card's hover. No word hides it",
	"/pvph window rect <history||summary||players||match||table||player||banner||overlay||overlaytile||tooltip||finder||card||hold||grip||compare||menu>  where it sits on screen, in pixels. grip is the history window's 64 pixel corner",
	"/pvph window grip [hover]  the history window's resize grip as a pointer over it. No word puts it back",
	"/pvph window close  close every match window and player window",
	"/pvph window click [players] <who> [shift||ctrl||alt||shift-alt||ctrl-alt]  a click on that name in the newest match window, or in the players window. #N is a roster row; a modifier adds the name or the spec to the search instead",
	"/pvph season        the client's season and rated counters, and what is declared. start, end, label, forget",
	"/pvph left           matches left or abandoned, as the Other tab lists them for the window's character",
	"/pvph incomplete     the same entries in a window, with the reason menu",
	"/pvph <id>           one match in full",
	"/pvph last [format]  the newest match in full, or the newest of one format, the ones show last opens",
	"/pvph meter [id]     the newest match's dispels, or one match's, round by round",
	"/pvph edit <id>      fill a field the capture did not record, marked as hand entered",
	"/pvph notes          the players window: the index, and what you wrote on it",
	"/pvph notes last     that window, scoped to the newest match. notes #<id> for one match",
	"/pvph notes sort <recent||met||rep||player||record||with||against> [up||down]  order the players list for this session",
	"/pvph scoreboard sort <name||damage||healing||kb||dispels||objective||swing||wins> [up||down]  order the match window for this session",
	"/pvph notes rep <bad||negative||neutral||positive||strong||none||off>  narrow the list to one rep",
	"/pvph notes format <format||all>  narrow the list to players met in one format",
	"/pvph notes side <with||against||all>  narrow the list to players met on one side",
	"/pvph notes search [text]  search the players list as the box does. No text clears it",
	"/pvph card [name]    the group finder's name card for one name, none for your own. No name hides it",
	"/pvph players        who has been played with and against, most matches first",
	"/pvph player <text>  one player in full, matched on a stored name, with the player window's figures",
	"/pvph note <who>     what you thought of a player. No text clears it",
	"/pvph rate <who>     rate a player from +2 to -2. No value clears it",
	"/pvph tag <who>      add one or more tags to a player",
	"/pvph untag <who>    remove tags from a player. No tag removes all of them",
	"/pvph tags           every tag in use with a count, most used first",
	"/pvph roster <id>    tag or untag everyone in one match's roster in a single write",
	"/pvph error         what threw last and when. clear forgets it",
	"/pvph rebuild        rebuild the player index from the stored matches",
	"/pvph debug fixture [n]  write generated records, so the empty screens can be seen",
	"/pvph debug fixture healer  deal the generated shuffles from a healer seat rather than a damage one",
	"/pvph debug fixture samespec  put two of a generated shuffle lobby on one spec",
	"/pvph debug fixture winning  win every generated shuffle round",
	"/pvph debug fixture unrated  write only the generated matches that move no rating",
	"/pvph debug fixture clear [confirm]  the bare word lists what would go; confirm removes every generated record, keeping what you wrote",
	"/pvph debug sandbox  this session reads an empty store that generated matches can fill, and your history is untouched. /reload ends it",
	"/pvph debug announce <id||last>  in the sandbox, the announcement for that match's roster, drawn once",
	"/pvph debug tooltip [who]  in the sandbox, the unit tooltip's block for that player. No name hides it",
	"/pvph debug group <who> [who ...]  in the sandbox, the group alert's lines as if they had joined",
	"/pvph debug gates <id||last>  in the sandbox, the gates line for that match's own side",
	"/pvph size           how much is stored, how much is left, and what it is made of",
	"/pvph backup         copy the whole history into this character's own file",
	"/pvph restore        what the backup holds. /pvph restore confirm replaces the history",
	"/pvph restore pinned the copy a reset set aside. confirm after it replaces the history",
	"/pvph reset          what erasing everything would destroy. confirm after it does it",
	"/pvph export         the whole history as one string, to copy out of the game",
	"/pvph import         paste a history string back in",
	"/pvph export csv     the history as a CSV file. [format] [since <date>] [last <n>] [part]",
	"/pvph import csv     paste a CSV back in. Adds what is new, skips what is stored. force overrides",
}

local COMMAND_WORDS=(function()
	local words,seen={},{}
	for i=1,#USAGE do
		local word=USAGE[i]:match("^/pvph (%a+)")
		if word and not seen[word]then
			seen[word]=true
			words[#words+1]=word
		end
	end
	return words
end)()

local KNOWN_WORD={commands=true}
for i=1,#COMMAND_WORDS do
	KNOWN_WORD[COMMAND_WORDS[i]]=true
end

local function commandSource(first)
	if type(first)~="string"then
		return"bare"
	end
	local word=first:lower()
	if KNOWN_WORD[word]then
		return word
	end
	if type(A.matchIdFromWord)=="function"and A.matchIdFromWord(first)then
		return"id"
	end
	return"unknown"
end

local function editDistance(one,two,bound)
	if one==two then
		return 0
	end
	if math.abs(#one-#two)>bound then
		return bound+1
	end

	local previous,current={},{}
	for j=0,#two do
		previous[j]=j
	end
	for i=1,#one do
		current[0]=i
		local best=current[0]
		for j=1,#two do
			local swap=one:sub(i,i)==two:sub(j,j)and 0 or 1
			local step=previous[j]+1
			if current[j-1]+1<step then
				step=current[j-1]+1
			end
			if previous[j-1]+swap<step then
				step=previous[j-1]+swap
			end
			current[j]=step
			if step<best then
				best=step
			end
		end
		if best>bound then
			return bound+1
		end
		for j=0,#two do
			previous[j]=current[j]
		end
	end
	return previous[#two]
end

function A.nearestCommand(word)
	if type(word)~="string"or word==""then
		return nil
	end
	local wanted=word:lower()

	for i=1,#COMMAND_WORDS do
		if#wanted>=2 and COMMAND_WORDS[i]:sub(1,#wanted)==wanted then
			return COMMAND_WORDS[i]
		end
	end

	local bound=#wanted>=5 and 2 or 1
	local best,at=nil,bound+1
	for i=1,#COMMAND_WORDS do
		local far=editDistance(wanted,COMMAND_WORDS[i],bound)
		if far<=bound and far<at then
			best,at=COMMAND_WORDS[i],far
		end
	end
	return best
end

local SAMPLE_LINE={announce=true,tooltip=true,group=true,gates=true}

local function reportUsage()
	local sandboxed=A.sandboxed()
	local instruments=A.debugEnabled()or sandboxed
	for i=1,#USAGE do
		local debugWord=USAGE[i]:match("^/pvph debug (%a+)")
		if(instruments or debugWord~="fixture")and(sandboxed or not SAMPLE_LINE[debugWord])then
			A.say(USAGE[i])
		end
	end
end

local function reportMiss(word)
	local near=A.nearestCommand(word)
	if near then
		A.say(("unknown command %q. did you mean %q? /pvph help lists every command")
			:format(word,near))
		return
	end
	A.say(("unknown command %q. /pvph help lists every command"):format(word))
end

local TAKES_NO_WORD={
	status="/pvph status takes no word after it",
	left="/pvph left takes no word after it. /pvph edit left #<n> reads one entry",
	incomplete="/pvph incomplete takes no word after it",
	tags="/pvph tags takes no word after it. /pvph tag <who> <tag> writes one",
	players="/pvph players takes no word after it. /pvph player <text> reads one player",
	rebuild="/pvph rebuild takes no word after it",
	size="/pvph size takes no word after it",
	backup="/pvph backup takes no word after it",
	tiers="/pvph tiers takes no word after it",
	help="/pvph help takes no word after it",
	commands="/pvph commands takes no word after it",
}

local TAKES_ONE_WORD={about="copy",error="clear"}

local LAST_WORD_READ={
	repaint=2,appearance=2,tab=2,minimap=2,alert=2,login=2,postgame=2,
	tooltip=2,groupnotes=2,menu=2,duel=2,list=2,region=2,faults=2,bests=2,
	perf=2,aftermatch=2,closeall=2,sight=2,chatmark=2,meter=2,finder=2,
	reset=2,summary=3,fold=3,session=3,
	announce={lock=3,unlock=3,time=3,size=3,opacity=3,shape=3,preview=3},
	overlay={count=3,opacity=3,combat=3,hover=3,preview=3},
	hold={preview=4},
	ask={sort=4,open=3,specs=4,under=3},
}

local function lastWordRead(first,words)
	local held=LAST_WORD_READ[first]
	if type(held)~="table"then
		return held
	end
	local second=words[2]and words[2]:lower()or nil
	if first=="overlay"and second=="preview"and words[3]and words[3]:lower()=="opacity"then
		return 4
	end
	return second and held[second]or 2
end

local function unreadWord(first,words)
	local noWord=TAKES_NO_WORD[first]
	if noWord and words[2]then
		return words[2],noWord
	end
	local takes=TAKES_ONE_WORD[first]
	local unread=takes and((words[2]and words[2]:lower()~=takes and words[2])or words[3])or nil
	if unread then
		return unread,("/pvph %s [%s]"):format(first,takes)
	end
	local last=lastWordRead(first,words)
	if last and words[last+1]then
		local read={first}
		for i=2,last-1 do
			read[#read+1]=words[i]:lower()
		end
		return words[last+1],("/pvph %s takes no word after %q"):format(table.concat(read," "),words[last])
	end
	return nil
end

local function commandRefused(first,words)
	local lowered=first and first:lower()or nil
	local unread,usage
	if lowered then
		unread,usage=unreadWord(lowered,words)
	end
	if lowered~="debug"then
		A.trace("command",{source=commandSource(first),n=#words,reason=unread and"unread"or nil},"ui")
	end
	if unread then
		refuseUnread(unread,usage)
		return true
	end
	return false
end

SLASH_WOWPVPHISTORY1="/pvph"
SLASH_WOWPVPHISTORY2="/wowpvphistory"
SLASH_WOWPVPHISTORY3="/pvphistory"

SlashCmdList["WOWPVPHISTORY"]=function(msg)
	local db=A.db()
	if not db then
		A.say("no database. The addon did not finish loading.")
		return
	end

	local words={}
	for word in tostring(msg or""):gmatch("%S+")do
		words[#words+1]=word
	end

	local first=words[1]

	if commandRefused(first,words)then
		return
	end

	if not first then
		reportShow(db,nil)
		return
	end

	first=first:lower()

	if first=="show"then
		if words[2]and words[2]:lower()=="last"and not words[3]then
			local newest=db.matches[#db.matches]
			if not newest then
				A.say("no match is stored yet")
				return
			end
			reportShow(db,newest.id)
			return
		end
		if words[2]and words[2]:lower()=="last"and words[3]and not words[4]then
			local format=words[3]:lower()
			local record=A.newestOfFormat(format)
			if record then
				reportShow(db,record.id)
				return
			end
			A.say(("no %s record is stored, so nothing was opened"):format(format))
			return
		end
		if reportShowState(words)then
			return
		end
		reportShow(db,words[2]and A.matchIdFromWord(words[2])or nil)
		return
	end

	if first=="status"then
		reportStatus(db)
		return
	end

	if first=="options"then
		reportOptions(words[2]and words[2]:lower()or nil,words[3]and words[3]:lower()or nil,
			words[3]and table.concat(words," ",3)or nil)
		return
	end

	if first=="about"then
		if not(type(A.showAboutBody)=="function"and A.withTypedSwitch(A.showAboutBody))then
			A.say("the window could not be opened. /pvph status names the loaded version")
			return
		end
		if words[2]and words[2]:lower()=="copy"then
			if not A.aboutCopyLink()then
				A.say("the copy box did not open: the manifest names no website")
			end
		end
		return
	end

	if first=="perf"then
		A.reportPerf(words[2]and words[2]:lower()or nil)
		return
	end

	if first=="repaint"then
		reportRepaint(words[2]and words[2]:lower()or nil)
		return
	end

	if first=="appearance"then
		reportAppearance(words[2]and words[2]:lower()or nil)
		return
	end

	if first=="tab"then
		reportTab(words[2]and words[2]:lower()or nil)
		return
	end

	if first=="minimap"then
		reportMinimap(words[2]and words[2]:lower()or nil)
		return
	end

	if first=="alert"then
		reportAlert(words[2]and words[2]:lower()or nil)
		return
	end

	if first=="login"then
		reportLogin(words[2]and words[2]:lower()or nil)
		return
	end

	if first=="postgame"then
		reportPostGame(words[2]and words[2]:lower()or nil)
		return
	end

	if first=="aftermatch"then
		A.reportAfterMatch(words[2]and words[2]:lower()or nil)
		return
	end

	if first=="closeall"then
		A.reportCloseAll(words[2]and words[2]:lower()or nil)
		return
	end

	if first=="sight"then
		A.reportSight(words[2]and words[2]:lower()or nil)
		return
	end

	if first=="chatmark"then
		A.reportChatMark(words[2]and words[2]:lower()or nil)
		return
	end

	if first=="tooltip"then
		reportTooltip(words[2]and words[2]:lower()or nil)
		return
	end

	if first=="groupnotes"then
		reportGroupNotes(words[2]and words[2]:lower()or nil)
		return
	end

	if first=="announce"then
		reportAnnounce(words[2]and words[2]:lower()or nil,words[3])
		return
	end

	if first=="overlay"then
		reportOverlay(words[2]and words[2]:lower()or nil,words[3],words[4])
		return
	end

	if first=="menu"then
		reportContextMenu(words[2]and words[2]:lower()or nil)
		return
	end

	if first=="compare"then
		A.reportCompare(words)
		return
	end

	if first=="duel"then
		reportDuel(words[2]and words[2]:lower()or nil)
		return
	end

	if first=="hold"then
		reportHold(words[2]and words[2]:lower()or nil,words[3],words[4])
		return
	end

	if first=="debug"then
		reportDebug(words[2]and words[2]:lower()or nil,words[3],words[4],words)
		return
	end

	if first=="meter"then
		if type(A.meterLines)~="function"then
			A.say("the meter reader did not load")
			return
		end
		local record
		if words[2]then
			local id=A.matchIdFromWord(words[2])
			record=id and A.match(id)or nil
		else
			record=db.matches[#db.matches]
		end
		for _,line in ipairs(A.meterLines(record))do
			A.say(line)
		end
		return
	end

	if first=="list"then
		reportList(words[2]and words[2]:lower()or nil)
		return
	end

	if first=="summary"then
		local season=wholeArgument(words[3])
		if words[3]~=nil and season==nil then
			A.say(tonumber(words[3])~=nil and SEASON_NOT_WHOLE
				or"/pvph summary <fmt> <n>  the same figures for one season")
			return
		end
		reportSummary(words[2]and words[2]:lower()or nil,season)
		return
	end

	if first=="search"then
		local text=rest(msg,1)
		if type(A.setMatchSearch)~="function"then
			A.say("the match list did not load, so there is nothing to search")
			return
		end
		local terms,shown,scoped=A.setMatchSearch(text,"word")
		if#terms==0 then
			A.say("search cleared")
		else
			A.say(A.searchCountLine(shown,scoped))
		end
		return
	end

	if first=="filter"then
		if type(A.setMatchFilter)~="function"or type(A.matchFilter)~="function"then
			A.say("the match list did not load, so there is nothing to filter")
			return
		end
		local which=words[2]and words[2]:lower()or nil
		if which==nil then
			local result,spec,shown,scoped,zone=A.matchFilter()
			A.say(("result %s, spec %s, zone %s"):format(result or"all",spec or"all",zone or"all"))
			A.say(A.searchCountLine(shown,scoped))
			return
		end
		if which=="result"or which=="spec"or which=="zone"then
			local choice=rest(msg,2)
			if choice==""then
				local usage={
					result="result takes all, won, lost or even",
					spec="spec takes a spec as the list spells it, or all",
					zone="zone takes a zone as the World PvP list spells it, or all",
				}
				A.say(usage[which])
				return
			end
			local shown,scoped,counted=A.setMatchFilter(which,choice,"word")
			if counted==false then
				A.say(("filter %s set to %q, and the match list could not be read, so there is no count")
					:format(which,choice))
				return
			end
			if shown==nil and which=="result"then
				A.say(("unknown result word %q: all, won, lost or even"):format(choice))
				return
			elseif shown==nil then
				A.say(("filter %s set to %q, and the match list could not be read, so there is no count")
					:format(which,choice))
				return
			end
			A.say(A.searchCountLine(shown,scoped))
			return
		end
		A.say(("unknown filter word %q. result, spec, zone, or nothing for the choices"):format(which))
		return
	end

	if first=="window"then
		reportWindow(words[2]and words[2]:lower()or nil,words)
		return
	end

	if first=="region"then
		if words[2]and words[2]:lower()=="list"then
			if type(A.listEdgeLines)~="function"then
				A.say("the match window did not load, so the list has no edges to state")
				return
			end
			for _,line in ipairs(A.listEdgeLines())do
				A.say(line)
			end
			return
		end
		if words[2]and words[2]:lower()=="band"then
			if type(A.searchBandLines)~="function"then
				A.say("the match window did not load, so the search band has no placement to state")
				return
			end
			for _,line in ipairs(A.searchBandLines())do
				A.say(line)
			end
			return
		end
		reportRegion(words[2]and words[2]:lower()or nil)
		return
	end

	if first=="faults"then
		reportFaults(words[2]and words[2]:lower()or nil)
		return
	end

	if first=="ask"then
		if words[2]and words[2]:lower()=="sort"then
			reportAskSort(words[3]and words[3]:lower()or nil,words[4]and words[4]:lower()or nil)
			return
		end
		if words[2]and words[2]:lower()=="open"then
			reportAskOpen(words[3])
			return
		end
		if words[2]and words[2]:lower()=="specs"then
			reportAskSpecs(words[3]and words[3]:lower()or nil,words[4]and words[4]:lower()or nil)
			return
		end
		if words[2]and words[2]:lower()=="under"then
			reportAskUnder(words[3]and words[3]:lower()or nil)
			return
		end
		reportAsk(words[2]and words[2]:lower()or nil)
		return
	end

	if first=="fold"then
		local which=words[2]and words[2]:lower()or nil
		local state=words[3]and words[3]:lower()or nil
		if(which~="graph"and which~="details")or(state~="open"and state~="shut")then
			A.say("/pvph fold <graph||details> <open||shut>   folds for this session and stores nothing")
			return
		end
		A.holdFold(which,state=="shut")
		A.say(("the %s is %s for this session; the stored fold returns at the next reload")
			:format(which=="graph"and"graph"or"Details lines",state=="shut"and"folded"or"open"))
		return
	end

	if first=="session"then
		local index=wholeArgument(words[2])
		local state=words[3]and words[3]:lower()or nil
		local usage="/pvph session [<n> <open||shut>]   n counts from the newest line drawn; holds for this session and stores nothing"
		if words[2]~=nil and(index==nil or(state~="open"and state~="shut"))then
			A.say(usage)
			return
		end
		local lines,shape=A.listSessionLines()
		if shape=="none"then
			A.say("no History list has been drawn since this load, so there is no session to name")
			return
		end
		if shape=="undrawn"or lines==nil then
			A.say("the list's last paint drew no session grid, so there is no session line to name")
			return
		end
		if index~=nil then
			local key,count=A.holdListSession(index,state=="open")
			if key==nil then
				A.say(("no session %d in the grid, which draws %s"):format(index,tostring(count)))
				return
			end
			A.say(("session %d (key %s) is %s for this session; nothing is stored")
				:format(index,tostring(key),state=="open"and"open"or"folded"))
			return
		end
		if#lines==0 then
			A.say("the grid draws no session line")
			return
		end
		for i=1,#lines do
			local line=lines[i]
			local open,source=A.sessionOpen(line.key,line.newest)
			local counted=("%d listed"):format(line.listed)
			A.say(("session %d  key %s, %s, %s (%s)"):format(i,tostring(line.key),counted,
				open and"open"or"folded",source))
		end
		return
	end

	if first=="finder"then
		local state=words[2]and words[2]:lower()or nil
		if state=="on"or state=="off"then
			A.setFinderSession(state)
			A.say(("the finder tooltip is %s for this session; the setting is unchanged"):format(state))
			return
		end
		if state=="dock"or state=="undock"then
			A.setFinderDockSession(state)
			A.say(("the season record is %sed for this session; the setting is unchanged"):format(state))
			return
		end
		if state=="reset"then
			if not A.resetFinderPosition()then
				A.say("no database, so the season record's position could not be cleared")
				return
			end
			A.say("the season record's position is cleared; undocked, it starts at its docked spot")
			return
		end
		if state~=nil then
			A.say("/pvph finder [on||off||dock||undock||reset]   all but reset hold for this session and store nothing")
			return
		end
		local lines=A.finderReadout()
		for i=1,#lines do
			A.say(lines[i])
		end
		return
	end

	if first=="tiers"then
		local lines=A.ratingTierLines()
		for i=1,#lines do
			A.say(lines[i])
		end
		return
	end

	if first=="comps"then
		local form=words[2]and words[2]:lower()or nil
		if form=="pairs"or form=="trios"then
			local formFormat=words[3]and words[3]:lower()or nil
			local formRow=words[4]
			if formRow==nil and tonumber(words[3])~=nil then
				formFormat,formRow=nil,words[3]
			end
			local formIndex=wholeArgument(formRow)
			if formRow~=nil and form=="trios"then
				A.say(("/pvph comps trios [fmt]: trios takes no row, so %q was not read; /pvph comps <fmt> %s opens"
					.." a trio row"):format(tostring(formRow),tostring(formRow)))
				return
			end
			if formRow~=nil and formIndex==nil then
				A.say(("/pvph comps pairs [fmt] [n], /pvph comps trios [fmt]: %q is not a row from 1"):format(
					tostring(formRow)))
				return
			end
			reportComps(formFormat,formIndex,form)
			return
		end
		local format=words[2]and words[2]:lower()or nil
		local rowWord=words[3]
		if rowWord==nil and tonumber(words[2])~=nil then
			format,rowWord=nil,words[2]
		end
		local index=wholeArgument(rowWord)
		if rowWord~=nil and index==nil then
			A.say(("/pvph comps [fmt] [n]: n is a row from 1, and %q is not one"):format(tostring(rowWord)))
			return
		end
		reportComps(format,index)
		return
	end

	if first=="bests"then
		A.reportBests(words[2]and words[2]:lower()or nil)
		return
	end

	if first=="season"then
		reportSeason(msg,words)
		return
	end

	if first=="left"then
		reportLeft()
		return
	end

	if first=="incomplete"then
		reportIncompleteWindow()
		return
	end

	if first=="edit"then
		reportEdit(msg,words)
		return
	end

	if first=="note"then
		reportNoteCommand(msg,words)
		return
	end

	if first=="rate"then
		reportRate(words)
		return
	end

	if first=="tag"then
		reportTag(words)
		return
	end

	if first=="untag"then
		reportUntag(words)
		return
	end

	if first=="roster"then
		reportRoster(words)
		return
	end

	if first=="tags"then
		reportTags()
		return
	end

	if first=="players"then
		reportPlayers()
		return
	end

	if first=="scoreboard"then
		reportScoreboard(words)
		return
	end

	if first=="notes"then
		reportNotesWindow(words[2],words[3]and table.concat(words," ",3)or nil)
		return
	end

	if first=="card"then
		reportCard(words[2]and table.concat(words," ",2)or nil)
		return
	end

	if first=="player"then
		local text=table.concat(words," ",2)
		if text==""then
			A.say("/pvph player <text>  needs a name, or part of one, to search for")
			return
		end
		reportPlayer(text)
		return
	end

	if first=="error"then
		reportError(words[2]and words[2]:lower()=="clear")
		return
	end

	if first=="rebuild"then
		A.reportRebuild()
		return
	end

	if first=="size"then
		reportSize()
		return
	end

	if first=="backup"then
		A.reportBackup()
		return
	end

	if first=="restore"then
		local which,confirmed=nil,false
		for i=2,#words do
			local word=words[i]:lower()
			if word=="confirm"then
				confirmed=true
			elseif word=="pinned"then
				which="pinned"
			else
				A.say(("/pvph restore [pinned] [confirm]: %q is neither pinned nor confirm, so nothing was"
					.." restored"):format(words[i]))
				return
			end
		end
		A.openRestore(which,confirmed)
		return
	end

	if first=="reset"then
		reportReset(words[2]~=nil and words[2]:lower()=="confirm")
		return
	end

	if first=="export"then
		if words[2]and words[2]:lower()=="csv"then
			local filter,part={},nil
			local i=3
			while i<=#words do
				local word=words[i]:lower()
				if word=="since"then
					if not words[i+1]then
						A.say("since needs a date after it: /pvph export csv since 2026-09-01")
						return
					end
					filter.since=words[i+1]
					i=i+1
				elseif word=="last"then
					local last=wholeArgument(words[i+1])
					if not last then
						A.say("last needs a count from 1 after it: /pvph export csv last 20")
						return
					end
					filter.last=last
					i=i+1
				elseif tonumber(word)~=nil then
					part=wholeArgument(word)
					if not part then
						A.say(("a part is a whole number from 1, and %q is not one"):format(word))
						return
					end
				elseif filter.format then
					A.say(("one format at a time: %s and %s were both given"):format(filter.format,word))
					return
				else
					filter.format=word
				end
				i=i+1
			end
			reportCsvExport(filter,part)
		else
			A.openExport()
		end
		return
	end

	if first=="import"then
		if words[2]and words[2]:lower()=="csv"then
			reportCsvImport(words[3]~=nil and words[3]:lower()=="force")
		else
			A.openImport()
		end
		return
	end

	if first=="last"then
		if words[3]then
			A.say("/pvph last [format]: the newest match in full, or the newest of one format")
			return
		end
		if not words[2]then
			local newest=db.matches[#db.matches]
			if not newest then
				A.say("no match recorded yet")
				return
			end
			reportMatch(newest.id)
			return
		end
		local format=words[2]:lower()
		local record=A.newestOfFormat(format)
		if record then
			reportMatch(record.id)
			return
		end
		A.say(("no %s record is stored, so nothing was printed"):format(format))
		return
	end

	local id=A.matchIdFromWord(first)
	if id then
		reportMatch(id)
		return
	end

	if first=="help"or first=="commands"then
		reportUsage()
		return
	end

	reportMiss(first)
end

local dispatchSlash=SlashCmdList["WOWPVPHISTORY"]
SlashCmdList["WOWPVPHISTORY"]=function(msg)
	local ok,err=pcall(dispatchSlash,msg)
	if not ok then
		pcall(A.noteError,err,"/pvph")
		A.say("that command failed. /pvph error shows what went wrong")
	end
end
