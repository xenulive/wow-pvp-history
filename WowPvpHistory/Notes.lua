-- WowPvpHistory 0.75.26
-- Author:  Xenu-Sentinels
-- Project: wow-pvp-history
--          https://github.com/xenulive/wow-pvp-history
-- License: MIT, see LICENSE
local _,A=...

A.PLAYER_NOTE_MAX=200

A.PLAYER_TAG_MAX=24

A.PLAYER_MAX_TAGS=10

A.PLAYER_COMMENT_MAX=200

A.PLAYER_MAX_COMMENTS=50

local function store(create)
	local db=A.db()
	if not db then
		return nil
	end
	if type(db.notes)~="table"then
		if not create then
			return nil
		end
		db.notes={}
	end
	return db.notes
end

function A.noteFor(guid)
	local notes=store(false)
	if not(notes and type(guid)=="string")then
		return nil
	end
	local entry=notes[guid]
	if type(entry)~="table"then
		return nil
	end
	return entry
end

local vocabulary

function A.dropTagVocabulary()
	vocabulary=nil
end

local function touch(entry)
	vocabulary=nil
	local ok,stamp=pcall(A.stamp)
	if ok then
		entry.updatedAt=stamp
	end
	local read,epoch=pcall(time)
	if read and type(epoch)=="number"then
		entry.updatedEpoch=epoch
	end
end

local function traceNote(field,state,reason,text,bound)
	local counted=type(text)=="string"
	A.trace("authored",{
		source=field,state=state,reason=reason,
		bytes=counted and#text or nil,
		letters=counted and A.letterCount(text)or nil,
		bound=counted and bound or nil,
	},"data")
end

function A.letterCount(text)
	if type(text)~="string"then
		return 0
	end
	local _,n=text:gsub("[^\128-\191]","")
	return n
end

function A.writtenAbout(note)
	if type(note)~="table"then
		return false
	end
	return note.rating~=nil or note.attitude~=nil or note.text~=nil
		or(type(note.tags)=="table"and#note.tags>0)
		or(type(note.comments)=="table"and#note.comments>0)
end

local function prune(notes,guid,entry)
	if not A.writtenAbout(entry)
		and(type(entry.merged)~="table"or#entry.merged==0)then
		notes[guid]=nil
		vocabulary=nil
		return true
	end
	return false
end

local function entryFor(guid,create)
	local notes=store(create)
	if not notes then
		return nil,nil
	end
	local entry=notes[guid]
	if type(entry)~="table"then
		if not create then
			return nil,notes
		end
		entry={}
		notes[guid]=entry
		if type(A.clientPlayerName)=="function"then
			local ok,name=pcall(A.clientPlayerName,guid)
			if ok and name then
				A.setPlayerName(guid,name)
			end
		end
	end
	return entry,notes
end

local REFUSAL_TEXT={
	["no-database"]="no database",
	["no-guid"]="no player named",
	["not-a-player"]="not a player's GUID",
	["not-text"]="not text",
	["too-long"]="longer than the bound",
	["bad-rating"]="not a rating",
	["scale"]="not a scale",
	["slot"]="not a step from 1 to 5",
	["bad-chars"]="a word of letters, digits, spaces and hyphens",
	["taken"]="a word another step holds",
	["reserved"]="a word that means not rated",
	["no-tags"]="no tag named",
	["tag-too-long"]="a tag longer than the bound",
	["too-many"]="at the bound",
	["empty"]="nothing typed",
	["absent"]="no longer stored",
	["moved"]="changed since the window drew it",
	["no-record"]="the match is not stored",
	["empty-roster"]="nobody in the roster to write to",
}

function A.noteRefusalText(why)
	return REFUSAL_TEXT[why]or("refused (%s)"):format(tostring(why or"no reason"))
end

function A.setPlayerNote(guid,text)
	local usable,why=A.playerKey(guid)
	if not usable then
		traceNote("note","refused",why)
		return false,nil,why
	end

	if text~=nil and type(text)~="string"then
		traceNote("note","refused","not-text")
		return false,nil,"not-text"
	end
	if text~=nil then
		text=text:gsub("^%s+",""):gsub("%s+$","")
	end

	if text==nil or text==""then
		local entry,notes=entryFor(guid,false)
		if not(entry and notes)or entry.text==nil then
			traceNote("note","cleared","nothing-stored")
			return true,nil
		end
		local was=entry.text
		entry.text=nil
		if not prune(notes,guid,entry)then
			touch(entry)
		end
		traceNote("note","cleared")
		return true,was
	end

	if#text>A.PLAYER_NOTE_MAX then
		traceNote("note","refused","too-long",text,A.PLAYER_NOTE_MAX)
		return false,nil,"too-long",#text,A.PLAYER_NOTE_MAX
	end

	local entry=entryFor(guid,true)
	if not entry then
		traceNote("note","refused","no-database")
		return false,nil,"no-database"
	end
	local was=entry.text
	if was==text then
		traceNote("note","filled","unchanged")
		return true,was
	end
	entry.text=text
	touch(entry)
	traceNote("note","filled")
	return true,was
end

function A.setPlayerName(guid,name)
	if type(guid)~="string"or guid==""then
		return false
	end
	if type(name)~="string"or name==""then
		return false
	end

	local db=A.db()
	if not db then
		return false
	end

	local index=db.players
	if type(index)=="table"and type(index[guid])=="table"then
		return false
	end

	local entry=A.noteFor(guid)
	if not entry then
		return false
	end

	entry.name=name
	A.trace("authored",{source="name",state="filled",named=true},"data")
	return true
end

local RATING_WORDS={
	["+2"]=2,["2"]=2,["++"]=2,
	["+1"]=1,["1"]=1,["+"]=1,
	["0"]=0,
	["-1"]=-1,["-"]=-1,
	["-2"]=-2,["--"]=-2,
}

function A.ratingValue(word,scale)
	if type(word)~="string"then
		return nil
	end
	if RATING_WORDS[word]~=nil then
		return RATING_WORDS[word]
	end
	scale=scale or"skill"
	local lowered=word:lower()
	for step=-2,2 do
		if A.stepWord(scale,step)==lowered then
			return step
		end
	end
	return A.defaultStepFor(scale,lowered)
end

local PLAYER_GUID="^Player%-%d+%-%x+$"

function A.playerKey(guid)
	if type(guid)~="string"or guid==""then
		return false,"no-guid"
	end
	local read,_,stored=pcall(A.playerEntry,guid)
	if read and stored then
		return true
	end
	if guid:match(PLAYER_GUID)then
		return true
	end
	return false,"not-a-player"
end

function A.targetPlayer()
	local exists=A.guardedCall(UnitExists,"target")
	if not A.canRead(exists)then
		return nil,type(exists)=="nil"and"no-target"or"secret"
	end
	if exists~=true then
		return nil,"no-target"
	end

	local isPlayer=A.guardedCall(UnitIsPlayer,"target")
	if not A.canRead(isPlayer)then
		return nil,"secret"
	end
	if isPlayer~=true then
		return nil,"not-player"
	end

	local guid=A.readableString(A.guardedCall(UnitGUID,"target"))
	if not guid then
		return nil,"secret"
	end
	if not guid:match(PLAYER_GUID)then
		return nil,"not-player"
	end
	if A.isOwnCharacter(guid)then
		return nil,"self"
	end
	return guid,A.clientPlayerName(guid)
end

local function setStep(guid,field,source,scale,value)
	local usable,why=A.playerKey(guid)
	if not usable then
		traceNote(source,"refused",why)
		return false,nil,why
	end

	if value==nil then
		local entry,notes=entryFor(guid,false)
		if not(entry and notes)or entry[field]==nil then
			traceNote(source,"cleared","nothing-stored")
			return true,nil
		end
		local was=entry[field]
		entry[field]=nil
		if not prune(notes,guid,entry)then
			touch(entry)
		end
		traceNote(source,"cleared")
		return true,was
	end
	if A.defaultStepWord(scale,value)==nil then
		traceNote(source,"refused","bad-rating")
		return false,nil,"bad-rating"
	end

	local entry=entryFor(guid,true)
	if not entry then
		traceNote(source,"refused","no-database")
		return false,nil,"no-database"
	end
	local was=entry[field]
	if was==value then
		traceNote(source,"filled","unchanged")
		return true,was
	end
	entry[field]=value
	touch(entry)
	traceNote(source,"filled")
	return true,was
end

function A.setPlayerRating(guid,value)
	return setStep(guid,"rating","rating","skill",value)
end

function A.setPlayerAttitude(guid,value)
	return setStep(guid,"attitude","attitude","attitude",value)
end

local function normalize(tag)
	if type(tag)~="string"then
		return nil
	end
	tag=tag:lower():gsub("^%s+",""):gsub("%s+$","")
	if tag==""then
		return nil
	end
	return tag
end

local function wantedTags(tags)
	if type(tags)~="table"or#tags==0 then
		return nil,"no-tags"
	end

	local wanted={}
	for i=1,#tags do
		local tag=normalize(tags[i])
		if tag then
			if#tag>A.PLAYER_TAG_MAX then
				return nil,"tag-too-long",tag,A.PLAYER_TAG_MAX
			end
			wanted[#wanted+1]=tag
		end
	end
	if#wanted==0 then
		return nil,"no-tags"
	end
	return wanted
end

local function addWanted(guid,wanted)
	local entry,notes=entryFor(guid,true)
	if not entry then
		return false,nil,"no-database"
	end

	local held=entry.tags
	if type(held)~="table"then
		if held~=nil then
			A.trace("repair",{field="notes.tags",foundType=type(held)})
		end
		held={}
	end
	local seen={}
	for i=1,#held do
		seen[held[i]]=true
	end

	local added={}
	local total=#held
	for i=1,#wanted do
		local tag=wanted[i]
		if not seen[tag]then
			seen[tag]=true
			total=total+1
			if total>A.PLAYER_MAX_TAGS then
				prune(notes,guid,entry)
				return false,nil,"too-many",tag,A.PLAYER_MAX_TAGS
			end
			added[#added+1]=tag
		end
	end

	if#added==0 then
		return true,{}
	end

	for i=1,#added do
		held[#held+1]=added[i]
	end
	entry.tags=held
	touch(entry)
	return true,added
end

function A.addPlayerTags(guid,tags)
	local keyed,refusal=A.playerKey(guid)
	if not keyed then
		traceNote("tag","refused",refusal)
		return false,nil,refusal
	end

	local wanted,why,offender,bound=wantedTags(tags)
	if not wanted then
		traceNote("tag","refused",why)
		return false,nil,why,offender,bound
	end

	local ok,added,reason,badTag,cap=addWanted(guid,wanted)
	if not ok then
		traceNote("tag","refused",reason)
		return false,nil,reason,badTag,cap
	end

	traceNote("tag",#added>0 and"filled"or"unchanged")
	return true,added
end

local function removeWanted(guid,tags)
	local entry,notes=entryFor(guid,false)
	if not(entry and notes)then
		return{},false,false
	end

	local held=entry.tags
	if type(held)~="table"or#held==0 then
		return{},false,false
	end

	local removed={}
	if type(tags)~="table"or#tags==0 then
		for i=1,#held do
			removed[i]=held[i]
		end
		entry.tags=nil
	else
		local drop={}
		for i=1,#tags do
			local tag=normalize(tags[i])
			if tag then
				drop[tag]=true
			end
		end
		for i=#held,1,-1 do
			if drop[held[i]]then
				table.insert(removed,1,held[i])
				table.remove(held,i)
			end
		end
		if#held==0 then
			entry.tags=nil
		end
	end

	local pruned=false
	if#removed>0 then
		pruned=prune(notes,guid,entry)
		if not pruned then
			touch(entry)
		end
	end
	return removed,pruned,true
end

function A.removePlayerTags(guid,tags)
	if type(guid)~="string"or guid==""then
		traceNote("untag","refused","no-guid")
		return false,nil,"no-guid"
	end

	local removed,_,carried=removeWanted(guid,tags)
	if not carried then
		traceNote("untag","cleared","nothing-stored")
		return true,removed
	end
	traceNote("untag",#removed>0 and"cleared"or"unchanged")
	return true,removed
end

function A.addPlayerComment(guid,text)
	local keyed,refusal=A.playerKey(guid)
	if not keyed then
		traceNote("comment","refused",refusal)
		return false,nil,refusal
	end
	local body=type(text)=="string"and text:gsub("^%s+",""):gsub("%s+$","")or""
	if body==""then
		traceNote("comment","refused","empty")
		return false,nil,"empty"
	end
	if#body>A.PLAYER_COMMENT_MAX then
		traceNote("comment","refused","too-long",body,A.PLAYER_COMMENT_MAX)
		return false,nil,"too-long",#body,A.PLAYER_COMMENT_MAX
	end

	local entry=entryFor(guid,true)
	if not entry then
		traceNote("comment","refused","no-database")
		return false,nil,"no-database"
	end
	local held=type(entry.comments)=="table"and entry.comments or{}
	if#held>=A.PLAYER_MAX_COMMENTS then
		traceNote("comment","refused","too-many")
		return false,nil,"too-many",#held,A.PLAYER_MAX_COMMENTS
	end

	local comment={text=body}
	local ok,stamp=pcall(A.stamp)
	if ok then
		comment.at=stamp
	end
	local read,epoch=pcall(time)
	if read and type(epoch)=="number"then
		comment.epoch=epoch
	end
	held[#held+1]=comment
	entry.comments=held
	touch(entry)
	traceNote("comment","filled")
	return true,comment
end

function A.removePlayerComment(guid,index,text)
	local keyed,refusal=A.playerKey(guid)
	if not keyed then
		traceNote("uncomment","refused",refusal)
		return false,nil,refusal
	end
	local entry,notes=entryFor(guid,false)
	local held=entry and entry.comments or nil
	if type(held)~="table"or type(index)~="number"or held[index]==nil then
		traceNote("uncomment","refused","absent")
		return false,nil,"absent"
	end
	if text~=nil and(type(held[index])~="table"or held[index].text~=text)then
		traceNote("uncomment","refused","moved")
		return false,nil,"moved"
	end

	local removed=table.remove(held,index)
	if#held==0 then
		entry.comments=nil
	end
	if not prune(notes,guid,entry)then
		touch(entry)
	end
	traceNote("uncomment","cleared")
	return true,removed
end

function A.playerComments(guid)
	local out={}
	local entry=A.noteFor(guid)
	local held=entry and entry.comments or nil
	if type(held)~="table"then
		return out
	end
	for i=#held,1,-1 do
		local comment=held[i]
		if type(comment)=="table"and type(comment.text)=="string"then
			out[#out+1]={text=comment.text,at=comment.at,index=i}
		end
	end
	return out
end

local function rosterSubjects(record)
	local items=A.matchRoster(record)
	local out,bots={},0
	for i=1,#items do
		if A.isBotGuid(items[i].guid)then
			bots=bots+1
		else
			out[#out+1]=items[i]
		end
	end
	return out,bots
end

local function traceRoster(verb,state,summary,reason)
	A.trace("roster",{
		source=verb,
		state=state,
		reason=reason,
		n=summary and summary.addressed or nil,
		tagged=summary and summary.tagged or nil,
		untagged=summary and summary.untagged or nil,
		unchanged=summary and summary.unchanged or nil,
		atCap=summary and summary.atCap or nil,
		bots=summary and summary.bots or nil,
		pruned=summary and summary.pruned or nil,
	},"data")
end

local function rosterSummary(addressed,bots)
	return{
		addressed=addressed,bots=bots,
		tagged=0,untagged=0,unchanged=0,atCap=0,pruned=0,
	}
end

function A.tagRoster(record,tags)
	if type(record)~="table"then
		traceRoster("tag","refused",nil,"no-record")
		return false,nil,"no-record"
	end

	local wanted,why,offender,bound=wantedTags(tags)
	if not wanted then
		traceRoster("tag","refused",nil,why)
		return false,nil,why,offender,bound
	end

	local subjects,bots=rosterSubjects(record)
	local summary=rosterSummary(#subjects,bots)
	if#subjects==0 then
		traceRoster("tag","refused",summary,"empty-roster")
		return false,summary,"empty-roster"
	end

	for i=1,#subjects do
		local item=subjects[i]
		local ok,added,reason=addWanted(item.guid,wanted)
		if not ok and reason~="too-many"then
			traceRoster("tag","refused",summary,reason)
			return false,summary,reason
		end
		if not ok then
			summary.atCap=summary.atCap+1
		elseif#added>0 then
			summary.tagged=summary.tagged+1
			A.setPlayerName(item.guid,item.name)
		else
			summary.unchanged=summary.unchanged+1
		end
	end

	traceRoster("tag",summary.tagged>0 and"filled"or"unchanged",summary)
	return true,summary
end

function A.untagRoster(record,tags)
	if type(record)~="table"then
		traceRoster("untag","refused",nil,"no-record")
		return false,nil,"no-record"
	end

	local subjects,bots=rosterSubjects(record)
	local summary=rosterSummary(#subjects,bots)
	if#subjects==0 then
		traceRoster("untag","refused",summary,"empty-roster")
		return false,summary,"empty-roster"
	end

	local players,taken,seen={},{},{}
	for i=1,#subjects do
		local removed,pruned=removeWanted(subjects[i].guid,tags)
		if#removed>0 then
			summary.untagged=summary.untagged+1
			if pruned then
				summary.pruned=summary.pruned+1
			end
			players[#players+1]={guid=subjects[i].guid,name=subjects[i].name,tags=removed}
			for j=1,#removed do
				if not seen[removed[j]]then
					seen[removed[j]]=true
					taken[#taken+1]=removed[j]
				end
			end
		else
			summary.unchanged=summary.unchanged+1
		end
	end

	traceRoster("untag",summary.untagged>0 and"cleared"or"unchanged",summary)
	if#players>0 then
		summary.undoId,summary.undoReplaced=A.holdUndo(nil,"roster-tag",{tags=taken,players=players})
	end
	return true,summary
end

local function repaintAfter(guid,stored,...)
	if stored and type(A.refreshNotes)=="function"then
		pcall(A.refreshNotes)
	end
	if stored and type(A.repaintMatchWindowsFor)=="function"then
		pcall(A.repaintMatchWindowsFor,guid)
	end
	return stored,...
end

for _,name in ipairs({"setPlayerNote","setPlayerRating","setPlayerAttitude","addPlayerTags",
	"removePlayerTags","addPlayerComment","removePlayerComment"})do
	local write=A[name]
	A[name]=function(guid,...)
		return repaintAfter(guid,write(guid,...))
	end
end

for _,name in ipairs({"tagRoster","untagRoster"})do
	local write=A[name]
	A[name]=function(...)
		return repaintAfter(nil,write(...))
	end
end

A.UNDO_SECONDS=5

local UNDO_KINDS={note=true,rating=true,attitude=true,tag=true,comment=true,
	["roster-tag"]=true}

local undoHeld

local undoSerial=0

local function undoClock()
	if type(GetTime)=="function"then
		local ok,now=pcall(GetTime)
		if ok and type(now)=="number"then
			return now
		end
	end
	return time()
end

local function holdPlayers(kind,value)
	return kind=="roster-tag"and#value.players or nil
end

local function traceUndo(state,kind,reason,players)
	A.trace("undo",{state=state,kind=kind,reason=reason or"none",players=players},"data")
end

local function undoLive(hold)
	return type(hold)=="table"and undoClock()-hold.at<=A.UNDO_SECONDS
end

local function holdable(guid,kind,value)
	if kind=="roster-tag"then
		return type(value)=="table"and type(value.tags)=="table"and type(value.players)=="table"
			and#value.players>0
	end
	if type(guid)~="string"or guid==""or not UNDO_KINDS[kind]or value==nil then
		return false
	end
	if kind=="tag"then
		return type(value)=="table"and#value>0
	elseif kind=="comment"then
		return type(value)=="table"and type(value.text)=="string"
	end
	return true
end

function A.holdUndo(guid,kind,value)
	if not holdable(guid,kind,value)then
		return nil
	end
	local replaced=undoLive(undoHeld)
	undoSerial=undoSerial+1
	local hold={id=undoSerial,guid=guid,kind=kind,value=value,at=undoClock()}
	undoHeld=hold
	traceUndo("held",kind,replaced and"replaced"or nil,holdPlayers(kind,value))
	if type(A.refreshNotes)=="function"then
		pcall(A.refreshNotes)
	end
	if type(C_Timer)=="table"and type(C_Timer.After)=="function"then
		pcall(C_Timer.After,A.UNDO_SECONDS+0.1,function()
			if undoHeld==hold and type(A.refreshNotes)=="function"then
				pcall(A.refreshNotes)
			end
		end)
	end
	return hold.id,replaced
end

function A.undoPending(guid)
	if not undoLive(undoHeld)then
		return false
	end
	if undoHeld.kind~="roster-tag"then
		return undoHeld.guid==guid
	end
	for _,player in ipairs(undoHeld.value.players)do
		if player.guid==guid then
			return true
		end
	end
	return false
end

function A.dropUndoHold()
	local hold=undoHeld
	if hold==nil then
		return false
	end
	undoHeld=nil
	traceUndo("dropped",hold.kind,"store",holdPlayers(hold.kind,hold.value))
	return true
end

local function restoreComment(guid,comment)
	local entry=entryFor(guid,true)
	if not entry then
		return false,"no-database"
	end
	local held=type(entry.comments)=="table"and entry.comments or{}
	if#held>=A.PLAYER_MAX_COMMENTS then
		return false,"too-many"
	end
	local copy={text=comment.text,at=comment.at,epoch=comment.epoch}
	local at=#held+1
	if type(copy.epoch)=="number"then
		for i=1,#held do
			local epoch=type(held[i])=="table"and tonumber(held[i].epoch)or nil
			if epoch~=nil and epoch>copy.epoch then
				at=i
				break
			end
		end
	end
	table.insert(held,at,copy)
	entry.comments=held
	touch(entry)
	traceNote("comment","filled","undo")
	if type(A.refreshNotes)=="function"then
		pcall(A.refreshNotes)
	end
	return true
end

local function restoreRoster(value)
	local restored,capped=0,0
	for _,player in ipairs(value.players)do
		local ok,added,why=addWanted(player.guid,player.tags)
		if ok then
			restored=restored+1
			if#added>0 then
				A.setPlayerName(player.guid,player.name)
			end
		elseif why=="too-many"then
			capped=capped+1
		else
			return false,why
		end
	end
	value.capped=capped
	if type(A.refreshNotes)=="function"then
		pcall(A.refreshNotes)
	end
	if restored==0 then
		return false,"too-many"
	end
	return true
end

local function restoreHold(hold)
	if hold.kind=="roster-tag"then
		return restoreRoster(hold.value)
	elseif hold.kind=="note"then
		local ok,_,why=A.setPlayerNote(hold.guid,hold.value)
		return ok,why
	elseif hold.kind=="rating"then
		local ok,_,why=A.setPlayerRating(hold.guid,hold.value)
		return ok,why
	elseif hold.kind=="attitude"then
		local ok,_,why=A.setPlayerAttitude(hold.guid,hold.value)
		return ok,why
	elseif hold.kind=="tag"then
		local ok,_,why=A.addPlayerTags(hold.guid,hold.value)
		return ok,why
	end
	return restoreComment(hold.guid,hold.value)
end

function A.undoLast(id)
	local hold=undoHeld
	if hold==nil then
		traceUndo("refused",nil,"nothing")
		return false,"nothing"
	end
	if id~=nil and tonumber(id)~=hold.id then
		traceUndo("refused",hold.kind,"replaced")
		return false,"replaced",hold
	end
	if not undoLive(hold)then
		traceUndo("refused",hold.kind,"expired")
		return false,"expired",hold
	end
	undoHeld=nil
	local ok,why=restoreHold(hold)
	local players=holdPlayers(hold.kind,hold.value)
	if not ok then
		traceUndo("refused",hold.kind,why or"refused",players)
		return false,why or"refused",hold
	end
	traceUndo("restored",hold.kind,nil,players)
	return true,nil,hold
end

local function linkedName(guid)
	local read,listed=pcall(A.playerEntry,guid)
	local names=read and type(listed)=="table"and type(listed.entry)=="table"and listed.entry.names or nil
	local name=type(names)=="table"and names[1]or nil
	if type(name)~="string"or name==""then
		return A.UNKNOWN_PLAYER
	end
	return A.playerLink(guid,name)
end

local function holdWho(hold)
	if hold.kind=="roster-tag"then
		local n=#hold.value.players
		return("%d %s"):format(n,n==1 and"player"or"players"),n~=1
	end
	return linkedName(hold.guid),false
end

function A.undoWhat(kind,value)
	if kind=="tag"or kind=="roster-tag"then
		local tags=kind=="tag"and value or value.tags
		return("the %s %s"):format(#tags==1 and"tag"or"tags",table.concat(tags,", "))
	elseif kind=="rating"then
		return("the skill %s"):format(tostring(A.ratingText(value)or value))
	elseif kind=="attitude"then
		return("the attitude %s"):format(tostring(A.ratingText(value,"attitude")or value))
	elseif kind=="comment"then
		return"a comment"
	end
	return"the note"
end

function A.sayRemoved(guid,kind,value)
	local id,replaced=A.holdUndo(guid,kind,value)
	if id==nil then
		return nil
	end
	local line=("removed %s from %s. %s"):format(A.undoWhat(kind,value),linkedName(guid),
		A.undoLink(id,"Undo"))
	if replaced then
		line=line.."  The removal before it can no longer be undone."
	end
	A.say(line)
	return line
end

function A.sayRosterRemoved(summary)
	local line=A.rosterWriteLine(summary,false)
	if line==nil then
		return nil
	end
	if type(summary.undoId)=="number"then
		line=("%s. %s"):format(line,A.undoLink(summary.undoId,"Undo"))
		if summary.undoReplaced then
			line=line.."  The removal before it can no longer be undone."
		end
	end
	A.say(line)
	return line
end

function A.reportUndo(id)
	local ok,why,hold=A.undoLast(id)
	if ok and hold~=nil then
		local line=("put %s back on %s"):format(A.undoWhat(hold.kind,hold.value),(holdWho(hold)))
		local capped=hold.kind=="roster-tag"and hold.value.capped or 0
		if capped>0 then
			line=("%s, %d at the %d-tag bound"):format(line,capped,A.PLAYER_MAX_TAGS)
		end
		A.say(line)
	elseif why=="nothing"then
		A.say("nothing to undo")
	elseif why=="expired"then
		A.say(("that removal was more than %d seconds ago, so it stays removed"):format(A.UNDO_SECONDS))
	elseif why=="replaced"then
		A.say("a later removal replaced that one, so only the latest can be undone")
	elseif why=="too-many"and hold~=nil then
		local who,several=holdWho(hold)
		A.say(("%s %s at the bound, so %s could not be put back"):format(who,several and"are"or"is",
			A.undoWhat(hold.kind,hold.value)))
	else
		A.say(("%s, so nothing could be put back"):format(A.noteRefusalText(why)))
	end
	return ok
end

local function byCountThenTag(a,b)
	if a.count~=b.count then
		return a.count>b.count
	end
	return a.tag<b.tag
end

local function countTags(counts,entry)
	if type(entry)~="table"or type(entry.tags)~="table"then
		return
	end
	for i=1,#entry.tags do
		local tag=entry.tags[i]
		if type(tag)=="string"then
			counts[tag]=(counts[tag]or 0)+1
		end
	end
end

function A.rosterTagCounts(record)
	local out={}
	if type(record)~="table"then
		return out
	end

	local subjects=rosterSubjects(record)
	local counts={}
	for i=1,#subjects do
		countTags(counts,A.noteFor(subjects[i].guid))
	end

	for tag,count in pairs(counts)do
		out[#out+1]={tag=tag,count=count}
	end
	table.sort(out,byCountThenTag)
	return out
end

A.REVIEW_TAG="review"

function A.flaggedCount(record)
	if type(record)~="table"then
		return 0
	end
	local subjects=rosterSubjects(record)
	local n=0
	for i=1,#subjects do
		local entry=A.noteFor(subjects[i].guid)
		local tags=entry and entry.tags
		if type(tags)=="table"then
			for j=1,#tags do
				if tags[j]==A.REVIEW_TAG then
					n=n+1
					break
				end
			end
		end
	end
	return n
end

function A.flaggedLine(record)
	local n=A.flaggedCount(record)
	if n<1 then
		return nil,0
	end
	return A.playersLink(A.REVIEW_TAG,("%d flagged for review"):format(n)),n
end

local function countedTags(notes)
	if vocabulary and vocabulary.notes==notes then
		return vocabulary.ranked
	end
	local counts,ranked={},{}
	for _,entry in pairs(notes)do
		countTags(counts,entry)
	end
	for tag,count in pairs(counts)do
		ranked[#ranked+1]={tag=tag,count=count,folded=A.foldText(tostring(tag))}
	end
	table.sort(ranked,byCountThenTag)
	vocabulary={notes=notes,ranked=ranked}
	return ranked
end

function A.tagVocabulary(text)
	local notes=store(false)
	local out={}
	if not notes then
		return out
	end

	local needle=(type(text)=="string"and text~="")and A.foldText(text)or nil
	local ranked=countedTags(notes)
	for i=1,#ranked do
		local item=ranked[i]
		if needle==nil or item.folded:find(needle,1,true)then
			out[#out+1]={tag=item.tag,count=item.count}
		end
	end
	return out
end

function A.writtenNoteCount()
	local notes=store(false)
	if not notes then
		return 0
	end
	local n=0
	for _,entry in pairs(notes)do
		if A.writtenAbout(entry)then
			n=n+1
		end
	end
	return n
end

function A.notedCount()
	local notes=store(false)
	if not notes then
		return 0
	end
	local n=0
	for _ in pairs(notes)do
		n=n+1
	end
	return n
end

function A.taggedCount()
	local notes=store(false)
	local n=0
	for _,entry in pairs(notes or{})do
		if type(entry)=="table"and type(entry.tags)=="table"and#entry.tags>0 then
			n=n+1
		end
	end
	return n
end

local listing

local CHOICE_LIMIT=8

function A.resolvePlayer(text)
	if type(text)~="string"or text==""then
		return nil,"none"
	end

	local handle=text:match("^#(%d+)$")
	if handle then
		if not listing then
			return nil,"no-listing"
		end
		local item=listing[tonumber(handle)]
		if not item then
			return nil,"range",#listing
		end
		return item.guid,item.entry
	end

	local found=A.findPlayers(text)
	if#found==0 then
		return nil,"none"
	end
	if#found==1 then
		return found[1].guid,found[1].entry
	end

	local shown={}
	for i=1,math.min(#found,CHOICE_LIMIT)do
		shown[i]=found[i]
	end
	listing=shown
	return nil,"several",shown,#found
end

function A.playerListing()
	return listing
end

function A.clearPlayerListing()
	listing=nil
end

A.NOTE_TEMPLATE_SLOTS=5
A.NOTE_TEMPLATE_MAX=40

local function storedCopy(value)
	if value==nil or next(value)==nil then
		return nil
	end
	local copy={}
	for key,held in pairs(value)do
		copy[key]=held
	end
	return copy
end

local function badTemplateSlot(slot)
	return type(slot)~="number"or slot~=math.floor(slot)or slot<1 or slot>A.NOTE_TEMPLATE_SLOTS
end

function A.noteTemplatesValid(value)
	if type(value)~="table"then
		return false
	end
	for slot,text in pairs(value)do
		if badTemplateSlot(slot)then
			return false
		end
		if type(text)~="string"or text==""or#text>A.NOTE_TEMPLATE_MAX
			or text:find("^%s")or text:find("%s$")then
			return false
		end
	end
	return true
end

function A.noteTemplates()
	local db=A.db()
	local held=db and type(db.ui)=="table"and db.ui.noteTemplates or nil
	local out={}
	if A.noteTemplatesValid(held)then
		for slot,text in pairs(held)do
			out[slot]=text
		end
	end
	return out
end

function A.noteTemplateList()
	local held,out=A.noteTemplates(),{}
	for slot=1,A.NOTE_TEMPLATE_SLOTS do
		if held[slot]~=nil then
			out[#out+1]=held[slot]
		end
	end
	return out
end

local function templatesChanged()
	for _,name in ipairs({"refreshOptionsWindow","refreshNotes"})do
		if type(A[name])=="function"then
			pcall(A[name])
		end
	end
	A.trace("setting",{source="note-templates",state=tostring(#A.noteTemplateList())},"data")
end

function A.setNoteTemplate(slot,text)
	if badTemplateSlot(slot)then
		return false,nil,"slot"
	end
	local db=A.db()
	if not db then
		return false,nil,"no-database"
	end
	if text~=nil and type(text)~="string"then
		return false,nil,"not-text"
	end
	if text~=nil then
		text=text:gsub("^%s+",""):gsub("%s+$","")
		if text==""then
			text=nil
		end
	end
	if text~=nil and#text>A.NOTE_TEMPLATE_MAX then
		return false,nil,"too-long",#text,A.NOTE_TEMPLATE_MAX
	end
	local held=A.noteTemplates()
	local was=held[slot]
	if was==text then
		return true,was
	end
	held[slot]=text
	return A.setNoteTemplates(held),was
end

function A.setNoteTemplates(value)
	local db=A.db()
	if not db or(value~=nil and not A.noteTemplatesValid(value))then
		return false
	end
	db.ui=type(db.ui)=="table"and db.ui or{}
	db.ui.noteTemplates=storedCopy(value)
	templatesChanged()
	return true
end

local RESERVED_WORDS={none=true,off=true,["not rated"]=true,unrated=true}

local function effectiveWords(scale,overrides)
	local out={}
	for step=-2,2 do
		out[step]=overrides[step]or A.defaultStepWord(scale,step)
	end
	return out
end

function A.stepWordsValid(scale,value)
	if A.scaleWordsKey(scale)==nil or type(value)~="table"then
		return false
	end
	for step,word in pairs(value)do
		if type(step)~="number"or A.defaultStepWord(scale,step)==nil or not A.stepWordValid(word)
			or RESERVED_WORDS[word]then
			return false
		end
	end
	local seen,words={},effectiveWords(scale,value)
	for step=-2,2 do
		local word=words[step]
		if seen[word]then
			return false
		end
		seen[word]=true
	end
	return true
end

local WORDS_REPAINTS={
	function()return A.refreshOptionsWindow end,
	function()return A.refreshNotes end,
	function()return A.refreshPlayerWindows end,
	function()return A.setRateBindingNames end,
}

local function wordsChanged(scale)
	for i=1,#WORDS_REPAINTS do
		local repaint=WORDS_REPAINTS[i]()
		if type(repaint)=="function"then
			pcall(repaint)
		end
	end
	A.trace("setting",{source=scale.."-words",state=next(A.storedStepWords(scale))and"set"or"default"},"data")
end

function A.setStepWords(scale,value)
	local key=A.scaleWordsKey(scale)
	local db=A.db()
	if not(key and db)or(value~=nil and not A.stepWordsValid(scale,value))then
		return false
	end
	db.ui=type(db.ui)=="table"and db.ui or{}
	db.ui[key]=storedCopy(value)
	wordsChanged(scale)
	return true
end

function A.setStepWord(scale,position,word)
	if A.scaleWordsKey(scale)==nil then
		return false,nil,"scale"
	end
	if type(position)~="number"or position~=math.floor(position)or position<1 or position>5 then
		return false,nil,"slot"
	end
	local db=A.db()
	if not db then
		return false,nil,"no-database"
	end
	if word~=nil and type(word)~="string"then
		return false,nil,"not-text"
	end
	local step=position-3
	if word~=nil then
		word=word:gsub("^%s+",""):gsub("%s+$",""):lower()
		if word==""then
			word=nil
		end
	end
	local was=A.stepWord(scale,step)
	local held=A.storedStepWords(scale)
	if word~=nil then
		if#word>A.STEP_WORD_MAX then
			return false,nil,"too-long",#word,A.STEP_WORD_MAX
		end
		if not A.stepWordValid(word)then
			return false,nil,"bad-chars"
		end
		if RESERVED_WORDS[word]then
			return false,nil,"reserved"
		end
		local words=effectiveWords(scale,held)
		for other=-2,2 do
			if other~=step and words[other]==word then
				return false,nil,"taken",other+3
			end
		end
		if word==A.defaultStepWord(scale,step)then
			word=nil
		end
	end
	if held[step]==word then
		return true,was
	end
	held[step]=word
	return A.setStepWords(scale,held),was
end
