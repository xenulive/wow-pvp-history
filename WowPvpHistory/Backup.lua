-- WowPvpHistory 0.75.26
-- Author:  Xenu-Sentinels
-- Project: wow-pvp-history
--          https://github.com/xenulive/wow-pvp-history
-- License: MIT, see LICENSE
local _,A=...

local CODEC_FUNCTIONS={
	"SerializeCBOR","DeserializeCBOR",
	"CompressString","DecompressString",
	"EncodeBase64","DecodeBase64",
}

local codec
do
	local util=C_EncodingUtil
	if type(util)=="table"then
		local complete=true
		for i=1,#CODEC_FUNCTIONS do
			if type(util[CODEC_FUNCTIONS[i]])~="function"then
				complete=false
			end
		end
		if complete then
			codec=util
		end
	end
end

function A.backupAvailable()
	return codec~=nil
end

local EXPORT_FORMAT=1
local EXPORT_PREFIX="WPH!"..EXPORT_FORMAT.."!"

local SETTINGS_FORMAT=1
local SETTINGS_PREFIX="WPHS!"..SETTINGS_FORMAT.."!"

local function encode(value)
	local ok,serialized=pcall(codec.SerializeCBOR,value)
	if not(ok and type(serialized)=="string")then
		return nil,"serialize"
	end

	local compressed
	ok,compressed=pcall(codec.CompressString,serialized)
	if not(ok and type(compressed)=="string")then
		return nil,"compress"
	end

	local encoded
	ok,encoded=pcall(codec.EncodeBase64,compressed)
	if not(ok and type(encoded)=="string"and encoded~="")then
		return nil,"base64"
	end

	return encoded
end

local function decode(blob)
	if type(blob)~="string"or blob==""then
		return nil,"empty"
	end

	local ok,compressed=pcall(codec.DecodeBase64,blob)
	if not(ok and type(compressed)=="string")then
		return nil,"base64"
	end

	local serialized
	ok,serialized=pcall(codec.DecompressString,compressed)
	if not(ok and type(serialized)=="string")then
		return nil,"decompress"
	end

	local value
	ok,value=pcall(codec.DeserializeCBOR,serialized)
	if not(ok and type(value)=="table")then
		return nil,"deserialize"
	end

	return value
end

local EXCLUDED={players=true,playerIndexVersion=true,active=true,pruneLog=true}

local function carriedEntries(players)
	local carried
	for guid,entry in pairs(type(players)=="table"and players or{})do
		if type(entry)=="table"and entry.carried==true then
			carried=carried or{}
			carried[guid]=entry
		end
	end
	return carried
end

local function payload(db)
	local out={}
	for key,value in pairs(db)do
		if not EXCLUDED[key]then
			out[key]=value
		end
	end
	out.players=carriedEntries(db.players)
	return out
end

local function validate(value)
	if type(value)~="table"or type(value.matches)~="table"then
		return nil,"shape"
	end
	if type(value.schema)~="number"then
		return nil,"empty"
	end
	if value.schema>A.schema then
		return nil,"newer",value.schema
	end
	return value
end

local function teamKeys(record)
	local teams=type(record)=="table"and record.teams
	if type(teams)~="table"then
		return nil
	end
	local keys={}
	for key in pairs(teams)do
		keys[#keys+1]=tostring(key)
	end
	table.sort(keys)
	return table.concat(keys,",")
end

local function teamsMismatch(stored,decoded)
	for i=1,#stored do
		if teamKeys(stored[i])~=teamKeys(decoded[i])then
			return i
		end
	end
	return nil
end

local REFUSAL={
	["no-codec"]="this client provides no encoding surface, so a history string cannot be read",
	["nothing"]="nothing was pasted",
	["not-ours"]="this text did not come from "..A.displayName(),
	["unreadable"]="this text came from "..A.displayName().." and could not be read. It may have been "
		.."truncated or edited in transit",
	["shape"]="there is no history in this text",
	["empty"]="there is no history in this text",
	["newer"]="this was saved by a newer version of the addon. Update, then import it",
	["in-flight"]="a match is being recorded. Finish it or leave it, then try again",
	["pin-failed"]="the copy that would be kept could not be written, so nothing was erased",
	["sandbox"]="the sandbox is up and holds generated matches only. /reload ends it, then try again",
	["settings-string"]="this is a settings string. Paste it with Paste beside Your settings alone, "
		.."on the Data and backups page, or /pvph import settings",
	["history-string"]="this is a history string. Bring it in with Import, on the Data and backups "
		.."page, or /pvph import",
}

function A.refusalText(token)
	return REFUSAL[token]or"this text could not be imported"
end

local function store()
	local held=WowPvpHistoryBackupDB
	if type(held)~="table"then
		held={}
		WowPvpHistoryBackupDB=held
	end
	return held
end

function A.backupStore()
	local held=WowPvpHistoryBackupDB
	if type(held)~="table"then
		return nil
	end
	return held
end

local function stamp()
	local ok,at=pcall(A.stamp)
	if ok then
		return at
	end
	return nil
end

local function generatedCount(db)
	if type(A.fixtureCount)~="function"or type(db)~="table"then
		return nil
	end
	local ok,marked=pcall(A.fixtureCount,db)
	if not ok or type(marked)~="number"then
		return nil
	end
	return marked
end

local function realCount(matches,generated)
	local real=matches-generated
	if real<0 then
		return 0
	end
	return real
end

local function gatePair(held,heldGenerated,offered,offeredGenerated)
	if type(heldGenerated)~="number"or type(offeredGenerated)~="number"then
		return held,offered
	end
	return realCount(held,heldGenerated),realCount(offered,offeredGenerated)
end

local function traceBackup(ev,state,reason,n,check)
	A.trace(ev,{state=state,reason=reason,n=n,check=check},"data")
end

function A.takeBackup()
	local db=A.savedDB()
	if not db then
		traceBackup("backup","refused","no-database")
		return{ok=false,reason="no-database"}
	end
	if not codec then
		traceBackup("backup","refused","no-codec")
		return{ok=false,reason="no-codec"}
	end

	local held=store()
	local current=held.current
	local matches=#db.matches
	local generated=generatedCount(db)

	if type(current)=="table"and type(current.matches)=="number"then
		local heldReal,offeredReal=gatePair(current.matches,current.generated,matches,generated)
		if heldReal>offeredReal then
			local previous=held.refused
			local now=stamp()
			held.refused={
				at=now,
				held=heldReal,
				offered=offeredReal,
				heldRaw=(current.matches~=heldReal)and current.matches or nil,
				offeredRaw=(matches~=offeredReal)and matches or nil,
				firstAt=(type(previous)=="table"and previous.firstAt)or now,
				n=((type(previous)=="table"and type(previous.n)=="number")
					and previous.n or 0)+1,
			}
			traceBackup("backup","refused","smaller",offeredReal)
			return{
				ok=false,
				reason="smaller",
				held=heldReal,
				matches=offeredReal,
				heldRaw=held.refused.heldRaw,
				offeredRaw=held.refused.offeredRaw,
			}
		end
	end

	local started=A.precise()

	local blob,step=encode(payload(db))
	if not blob then
		held.failed={at=stamp(),step=step}
		traceBackup("backup","refused","encode",nil,step)
		return{ok=false,reason="encode",step=step}
	end

	local decoded,why=decode(blob)
	if not decoded then
		held.failed={at=stamp(),step=why}
		traceBackup("backup","refused","roundtrip",nil,why)
		return{ok=false,reason="roundtrip",step=why}
	end

	local checked
	checked,why=validate(decoded)
	if not checked then
		held.failed={at=stamp(),step=why}
		traceBackup("backup","refused","roundtrip",nil,why)
		return{ok=false,reason="roundtrip",step=why}
	end

	if#checked.matches~=matches then
		held.failed={at=stamp(),step=("%d matches back from %d"):format(
			#checked.matches,matches)}
		traceBackup("backup","refused","roundtrip",#checked.matches,"match count")
		return{ok=false,reason="roundtrip",step="match count"}
	end
	if checked.nextMatchId~=db.nextMatchId then
		held.failed={at=stamp(),step="nextMatchId"}
		traceBackup("backup","refused","roundtrip",nil,"nextMatchId")
		return{ok=false,reason="roundtrip",step="nextMatchId"}
	end
	local lost=teamsMismatch(db.matches,checked.matches)
	if lost then
		held.failed={at=stamp(),step="teams"}
		traceBackup("backup","refused","roundtrip",lost,"teams")
		return{ok=false,reason="roundtrip",step="teams"}
	end

	local finished=A.precise()
	local seconds
	if started and finished then
		seconds=finished-started
	end

	local entry={
		at=stamp(),
		addon=A.version,
		schema=db.schema,
		matches=matches,
		generated=generated,
		nextMatchId=db.nextMatchId,
		bytes=#blob,
		seconds=seconds,
		blob=blob,
	}

	local replaced=current
	held.previous=current or held.previous
	held.current=entry
	held.failed=nil
	held.refused=nil

	traceBackup("backup","stored",nil,matches)

	return{
		ok=true,
		matches=matches,
		bytes=#blob,
		seconds=seconds,
		replaced=replaced and replaced.matches or nil,
	}
end

function A.pinGate(db)
	local held=A.backupStore()
	local pinned=held and held.pinned
	if type(pinned)~="table"or type(pinned.matches)~="number"then
		return nil
	end
	return gatePair(pinned.matches,pinned.generated,#db.matches,generatedCount(db))
end

function A.pinBackup()
	local db=A.db()
	if not db then
		return{ok=false,reason="no-database"}
	end
	if not codec then
		return{ok=false,reason="no-codec"}
	end

	local held=store()
	local pinned=held.pinned
	local matches=#db.matches
	local generated=generatedCount(db)

	local heldReal,offeredReal=A.pinGate(db)
	if heldReal~=nil and heldReal>offeredReal then
		return{ok=false,reason="smaller",held=heldReal,matches=offeredReal}
	end

	local blob,step=encode(payload(db))
	if not blob then
		return{ok=false,reason="encode",step=step}
	end

	local decoded,why=decode(blob)
	if not decoded then
		return{ok=false,reason="roundtrip",step=why}
	end

	local checked
	checked,why=validate(decoded)
	if not checked then
		return{ok=false,reason="roundtrip",step=why}
	end
	if#checked.matches~=matches then
		return{ok=false,reason="roundtrip",step="match count"}
	end
	if checked.nextMatchId~=db.nextMatchId then
		return{ok=false,reason="roundtrip",step="nextMatchId"}
	end
	if teamsMismatch(db.matches,checked.matches)then
		return{ok=false,reason="roundtrip",step="teams"}
	end

	local replaced=pinned
	held.pinned={
		at=stamp(),
		addon=A.version,
		schema=db.schema,
		matches=matches,
		generated=generated,
		nextMatchId=db.nextMatchId,
		bytes=#blob,
		blob=blob,
	}

	return{
		ok=true,
		matches=matches,
		bytes=#blob,
		replaced=replaced and replaced.matches or nil,
	}
end

function A.largerRotationCopy()
	local held=A.backupStore()
	local pinned=held and held.pinned
	if type(held)~="table"or type(pinned)~="table"or type(pinned.matches)~="number"then
		return nil
	end

	local best,bestSlot,bestReal
	for _,slot in ipairs({"current","previous"})do
		local copy=held[slot]
		if type(copy)=="table"and type(copy.matches)=="number"and type(copy.blob)=="string"then
			local heldReal,copyReal=gatePair(pinned.matches,pinned.generated,copy.matches,
				copy.generated)
			if copyReal>heldReal and(bestReal==nil or copyReal>bestReal)then
				best,bestSlot,bestReal=copy,slot,copyReal
			end
		end
	end
	return best,bestSlot
end

function A.pinLargerRotationCopy()
	local copy=A.largerRotationCopy()
	if not copy then
		return nil
	end

	local held=store()
	local pinned={}
	for key,value in pairs(copy)do
		pinned[key]=value
	end
	held.pinned=pinned
	return pinned.matches
end

function A.clearBackupGenerations()
	local held=A.backupStore()
	if not held then
		return false
	end

	held.current=nil
	held.previous=nil
	held.refused=nil
	held.failed=nil
	return true
end

local RESTORE_SLOTS={current=true,pinned=true}

local RESTORE_KEEPS={"pruneLog"}

local function backupEntryWins(live,backup)
	if type(backup)~="table"then
		return false
	end
	if type(live)~="table"then
		return true
	end
	local liveStamped,backupStamped=type(live.at)=="string",type(backup.at)=="string"
	if liveStamped and backupStamped then
		return backup.at>live.at
	end
	return backupStamped and not liveStamped
end

local function mergeCharacters(live,backup)
	live=type(live)=="table"and live or nil
	backup=type(backup)=="table"and backup or nil
	if live==nil and backup==nil then
		return nil,0,0,0
	end

	local merged,kept,taken,both={},0,0,0
	for guid,entry in pairs(live or{})do
		local other=backup and backup[guid]
		if other==nil then
			merged[guid]=entry
			kept=kept+1
		else
			merged[guid]=backupEntryWins(entry,other)and other or entry
			both=both+1
		end
	end
	for guid,entry in pairs(backup or{})do
		if merged[guid]==nil then
			merged[guid]=entry
			taken=taken+1
		end
	end
	return merged,kept,taken,both
end

local LOAD_PASSES={
	{"backfillGameSeason","backup-game-season"},
	{"refileArenaMapBattlegrounds","backup-refile"},
	{"supersedeTypedResults","backup-typed-results"},
}

local function refill(db,value,keep,mergeRegistry,source)
	local repairs=A.repairStore(value)
	A.traceRepairs(repairs)
	local kept={}
	for _,key in ipairs(keep or{})do
		kept[key]=db[key]
	end
	local liveCharacters=mergeRegistry and db.characters or nil
	for key in pairs(db)do
		db[key]=nil
	end
	for key,held in pairs(value)do
		db[key]=held
	end
	for _,key in ipairs(keep or{})do
		db[key]=kept[key]
	end
	local charsKept,charsTaken,charsBoth
	if mergeRegistry then
		db.characters,charsKept,charsTaken,charsBoth=mergeCharacters(liveCharacters,db.characters)
	end

	if type(db.schema)~="number"or db.schema<A.schema then
		db.schema=A.schema
	end
	db.matches=db.matches or{}
	local DERIVED={nextMatchId="next-id",nextFixtureId="next-fixture-id",
		nextIncompleteId="next-incomplete-id"}
	for i=1,#repairs do
		local repair=repairs[i]
		local field=repair.field
		if DERIVED[field]and repair.position==nil then
			traceBackup("refill","derived",DERIVED[field],db[field])
		end
	end
	db.nextFixtureId=type(db.nextFixtureId)=="number"and db.nextFixtureId or 1
	db.dropped=db.dropped or{}
	db.dropEvents=db.dropEvents or{}
	db.incomplete=db.incomplete or{}
	if db.nextIncompleteId==nil then
		db.nextIncompleteId=A.assignIncompleteIds(db.incomplete)
	end
	db.ui=db.ui or{}
	A.dropRetiredUiKeys(db.ui)
	A.convertAnnounceTime()

	db.active=nil

	for i=1,#LOAD_PASSES do
		local pass=A[LOAD_PASSES[i][1]]
		if type(pass)=="function"then
			local ran,passError=pcall(pass,db)
			if not ran then
				A.noteError(passError,LOAD_PASSES[i][2])
			end
		end
	end

	local settled,settleError=pcall(A.settleWorldRecords,db,source)
	if not settled then
		A.noteError(settleError,"backup-world")
	end

	db.players=carriedEntries(db.players)or{}
	db.playerIndexVersion=nil
	local rebuilt,rebuildError=pcall(A.rebuildIndex)
	if not rebuilt then
		A.noteError(rebuildError,"backup-index")
		A.say(("the history is restored and the player index was not rebuilt: %s. /pvph rebuild")
			:format(tostring(rebuildError)))
	end

	local noted,notedError=pcall(A.noteCanary)
	if not noted then
		A.noteError(notedError,"restore-canary")
	end
	return charsKept,charsTaken,charsBoth,rebuilt
end

local function busyRefusal()
	if A.sandboxed()then
		return A.refusalText("sandbox"),"sandbox"
	end
	if A.matchInFlight(A.db())then
		return A.refusalText("in-flight"),"in-flight"
	end
	return nil
end

function A.restorePreview(which)
	if not codec then
		return nil,"the client provides no encoding surface","no-codec"
	end

	local slot=which or"current"
	if not RESTORE_SLOTS[slot]then
		return nil,("there is no backup called %q"):format(tostring(which)),"nothing"
	end

	local held=A.backupStore()
	local current=held and held[slot]
	if type(current)~="table"or type(current.blob)~="string"then
		if slot=="pinned"then
			return nil,"no copy was pinned on this character. /pvph reset pins one","nothing"
		end
		return nil,"no backup on this character","nothing"
	end

	local value=decode(current.blob)
	if not value then
		return nil,"this character's backup could not be read","unreadable"
	end

	local checked,why=validate(value)
	if not checked then
		return nil,("this character's backup holds no restorable history (%s)")
			:format(A.refusalText(why)),why
	end

	local busy,busyToken=busyRefusal()
	if busy then
		return nil,busy,busyToken
	end

	return{payload=checked,entry=current}
end

function A.applyRestore(which)
	local preview,why,token=A.restorePreview(which)
	if not preview then
		traceBackup("restore","refused",token)
		return nil,why
	end

	local db=A.db()
	if not db then
		traceBackup("restore","refused","no-database")
		return nil,"no database"
	end

	local before=#db.matches
	local charsKept,charsTaken,charsBoth,indexRebuilt=refill(db,preview.payload,RESTORE_KEEPS,true,"restore")
	local held=A.backupStore()
	local current=held and held.current
	if type(current)=="table"and type(current.matches)=="number"then
		local heldReal,restoredReal=gatePair(current.matches,current.generated,#db.matches,
			generatedCount(db))
		if heldReal>restoredReal then
			held.previous,held.current,held.refused=current,nil,nil
		end
	end
	local pruned,pruneError=pcall(A.notePrune,"restore",before)
	if not pruned then
		A.noteError(pruneError,"restore-prune")
	end
	A.storeReplaced()

	A.trace("restore",{
		state="applied",
		n=#db.matches,
		charsKept=charsKept,
		charsTaken=charsTaken,
		charsBoth=charsBoth,
	},"data")

	return{matches=#db.matches,replaced=before,at=preview.entry.at,indexRebuilt=indexRebuilt}
end

function A.exportString()
	if not codec then
		return nil,"the client provides no encoding surface"
	end
	if A.sandboxed()then
		traceBackup("export","refused","sandbox")
		return nil,A.refusalText("sandbox")
	end

	local db=A.db()
	if not db then
		return nil,"no database"
	end

	local blob,step=encode(payload(db))
	if not blob then
		return nil,"the export did not encode: "..tostring(step)
	end

	return EXPORT_PREFIX..blob,nil,#db.matches
end

local function cleanedPaste(text)
	if not codec then
		return nil,A.refusalText("no-codec"),"no-codec"
	end
	if type(text)~="string"then
		return nil,A.refusalText("nothing"),"nothing"
	end
	local cleaned=text:gsub("%s+","")
	if cleaned==""then
		return nil,A.refusalText("nothing"),"nothing"
	end
	return cleaned
end

function A.importPreview(text)
	local cleaned,sentence,token=cleanedPaste(text)
	if not cleaned then
		return nil,sentence,token
	end
	local format=tonumber(cleaned:match("^WPH!(%d+)!")or"")
	if format~=nil and format>EXPORT_FORMAT then
		return nil,A.refusalText("newer")..(" (it holds format %s and this addon reads format %s)")
			:format(tostring(format),tostring(EXPORT_FORMAT)),"newer"
	end
	if cleaned:match("^WPHS!")then
		return nil,A.refusalText("settings-string"),"settings-string"
	end
	if cleaned:sub(1,#EXPORT_PREFIX)~=EXPORT_PREFIX then
		return nil,A.refusalText("not-ours"),"not-ours"
	end

	local value=decode(cleaned:sub(#EXPORT_PREFIX+1))
	if not value then
		return nil,A.refusalText("unreadable"),"unreadable"
	end

	local checked,why,found=validate(value)
	if not checked then
		local text_=A.refusalText(why)
		if why=="newer"and found~=nil then
			text_=text_..(" (it holds schema %s and this addon reads %s)")
				:format(tostring(found),tostring(A.schema))
		end
		return nil,text_,why
	end

	local partial=checked.partial==true

	local busy,busyToken=busyRefusal()
	if busy and partial and busyToken=="sandbox"then
		busy,busyToken=nil,nil
		if A.matchInFlight(A.db())then
			busy,busyToken=A.refusalText("in-flight"),"in-flight"
		end
	end
	if busy then
		return nil,busy,busyToken
	end

	return{payload=checked,partial=partial}
end

local IMPORT_KEEPS={"ui","characters","lastError","lastErrorAt","pruneLog"}

local STAMP_FIELDS={"openedEpoch","openedAt","completedEpoch","endedAt"}

local function stampKey(entry)
	local parts,any={},false
	for i=1,#STAMP_FIELDS do
		local held=entry[STAMP_FIELDS[i]]
		any=any or held~=nil
		parts[i]=tostring(held)
	end
	return any and table.concat(parts,"|")or nil
end

local function idStampKey(entry)
	return type(entry.id)..":"..tostring(entry.id).."#"..tostring(stampKey(entry))
end

local function planList(stored,offered)
	local held,ids,stamps={},{},{}
	local function hold(entry)
		local stamped=stampKey(entry)
		if entry.id~=nil and entry.id==entry.id then
			held[idStampKey(entry)]=true
			ids[entry.id]=true
		end
		if stamped then
			stamps[stamped]=true
		end
	end
	for i=1,#stored do
		if type(stored[i])=="table"then
			hold(stored[i])
		end
	end
	local add,renumber,skipped={},{},0
	for i=1,#offered do
		local entry=offered[i]
		local stamped=type(entry)=="table"and stampKey(entry)or nil
		if type(entry)~="table"or(entry.id~=nil and held[idStampKey(entry)])
			or((entry.id==nil or ids[entry.id])and stamped~=nil and stamps[stamped])then
			skipped=skipped+1
		else
			add[#add+1]=entry
			if entry.id~=nil and ids[entry.id]then
				renumber[entry]=true
				if stamped then
					stamps[stamped]=true
				end
			else
				hold(entry)
			end
		end
	end
	return add,renumber,skipped
end

local function planPartial(db,partial)
	local matches={planList(type(db.matches)=="table"and db.matches or{},
		type(partial.matches)=="table"and partial.matches or{})}
	local left={planList(type(db.incomplete)=="table"and db.incomplete or{},
		type(partial.incomplete)=="table"and partial.incomplete or{})}
	return matches,left
end

local function addPartial(db,partial)
	local before=#db.matches
	local matchPlan,leftPlan=planPartial(db,partial)
	local list,renumber,skipped=matchPlan[1],matchPlan[2],matchPlan[3]
	local fresh={}
	for i=1,#list do
		local record=list[i]
		if renumber[record]then
			fresh[#fresh+1]={record=record,generated=type(record.id)=="string"}
			record.id=nil
		end
		db.matches[#db.matches+1]=record
	end
	local added=#list

	db.incomplete=type(db.incomplete)=="table"and db.incomplete or{}
	local left,leftRenumber=leftPlan[1],leftPlan[2]
	local leftFresh=0
	for i=1,#left do
		local entry=left[i]
		if leftRenumber[entry]then
			entry.id=nil
			leftFresh=leftFresh+1
		end
		db.incomplete[#db.incomplete+1]=entry
	end
	local leftAdded=#left
	A.traceRepairs(A.repairStore(db))
	for i=1,#fresh do
		local item=fresh[i]
		local record=item.record
		if item.generated then
			record.id=("F%d"):format(db.nextFixtureId or 1)
			db.nextFixtureId=(db.nextFixtureId or 1)+1
		else
			record.id=db.nextMatchId or 1
			db.nextMatchId=record.id+1
		end
	end
	for i=1,#db.incomplete do
		local entry=db.incomplete[i]
		if type(entry)=="table"and entry.id==nil then
			entry.id=db.nextIncompleteId or 1
			db.nextIncompleteId=entry.id+1
		end
	end
	local renumbered=#fresh+leftFresh

	A.orderByCompletion(db.matches)
	local rebuilt,rebuildError=pcall(A.rebuildIndex)
	if not rebuilt then
		A.noteError(rebuildError,"import-add-index")
	end
	local pruned,pruneError=pcall(A.notePrune,"import-add",before)
	if not pruned then
		A.noteError(pruneError,"import-add-prune")
	end
	A.storeReplaced()
	A.trace("import",{state="added",reason="partial",n=added,skipped=skipped,
		leftEarly=leftAdded,renumbered=renumbered},"data")
	return{matches=#db.matches,added=added,skipped=skipped,leftEarly=leftAdded,
		renumbered=renumbered,replaced=before,indexRebuilt=rebuilt,partial=true}
end

function A.partialPlan(db,partial)
	local matchPlan,leftPlan=planPartial(db,partial)
	local fresh=0
	for _ in pairs(matchPlan[2])do
		fresh=fresh+1
	end
	for _ in pairs(leftPlan[2])do
		fresh=fresh+1
	end
	return{added=#matchPlan[1],skipped=matchPlan[3],renumbered=fresh}
end

function A.applyImport(text)
	local preview,why,token=A.importPreview(text)
	if not preview then
		traceBackup("import","refused",token)
		return nil,why
	end

	local db=A.db()
	if not db then
		traceBackup("import","refused","no-database")
		return nil,"no database"
	end
	if preview.partial then
		return addPartial(db,preview.payload)
	end

	local before=#db.matches
	local _,_,_,indexRebuilt=refill(db,preview.payload,IMPORT_KEEPS,nil,"import")
	if type(db.ui)=="table"then
		db.ui.sessionFolds=nil
	end
	local pruned,pruneError=pcall(A.notePrune,"import",before)
	if not pruned then
		A.noteError(pruneError,"import-prune")
	end
	A.storeReplaced()

	traceBackup("import","applied",nil,#db.matches)

	return{matches=#db.matches,replaced=before,indexRebuilt=indexRebuilt}
end

local function hasPin(held)
	local pinned=held and held.pinned
	return type(pinned)=="table"and type(pinned.blob)=="string"
end

local function pinClause(held)
	if not hasPin(held)then
		return""
	end
	local pinned=held.pinned
	return(". A pinned copy holds %d %s from %s"):format(
		pinned.matches or 0,pinned.matches==1 and"match"or"matches",tostring(pinned.at))
end

local function generationClause(held,heldRaw,offered,offeredRaw)
	local parts={}
	if type(heldRaw)=="number"and type(held)=="number"then
		parts[#parts+1]=("the held copy counting %d generated"):format(heldRaw-held)
	end
	if type(offeredRaw)=="number"and type(offered)=="number"then
		parts[#parts+1]=("this history counting %d generated"):format(offeredRaw-offered)
	end
	if#parts==0 then
		return""
	end
	return", "..table.concat(parts," and ")
end

local function backupText()
	if not codec then
		return"this client provides no encoding surface, so nothing is backed up"
	end

	local held=A.backupStore()
	if not held or type(held.current)~="table"then
		if held and type(held.failed)=="table"then
			return("none held. The last write failed at %s"):format(
				tostring(held.failed.step))..pinClause(held)
		end
		return"none on this character yet"..pinClause(held),true
	end

	local current=held.current
	local text=("%d %s from %s, %s"):format(current.matches or 0,
		current.matches==1 and"match"or"matches",tostring(current.at),
		A.bytesText(current.bytes or 0))

	local refused=held.refused
	if type(refused)=="table"then
		local n=type(refused.n)=="number"and refused.n or 1
		text=text..(". No write has taken since, across %d %s%s")
			:format(n,n==1 and"logout"or"logouts",
				generationClause(refused.held,refused.heldRaw,refused.offered,refused.offeredRaw))
		return text..pinClause(held)
	end

	local failed=held.failed
	if type(failed)=="table"then
		text=text..(". THE LAST WRITE FAILED at %s, so this is older than it looks")
			:format(tostring(failed.step))
	end

	return text..pinClause(held)
end

function A.backupReading()
	local text,none=backupText()
	return text,none,hasPin(A.backupStore())
end

function A.backupLine()
	local reading,none,pinned=A.backupReading()
	if none then
		reading=reading..". /pvph backup takes one"
	end
	if pinned then
		reading=reading..". /pvph restore pinned brings the pin back"
	end
	return"backup: "..reading
end

function A.reportBackup()
	local said,say=A.chatCollector()

	local result=A.takeBackup()

	if result.ok then
		local line=("backup written: %d %s, %d bytes encoded")
			:format(result.matches,result.matches==1 and"match"or"matches",result.bytes)
		if result.replaced then
			line=line..(", replacing one holding %d"):format(result.replaced)
		end
		if result.seconds then
			line=line..(", in %.3f s"):format(result.seconds)
		end
		say(line)
		return said
	end

	if result.reason=="no-codec"then
		say("this client provides no encoding surface, so nothing can be backed up")
	elseif result.reason=="smaller"then
		say(("backup refused: %d %s stored against %d in the backup, which is not overwritten%s")
			:format(result.matches,result.matches==1 and"match"or"matches",result.held,
				generationClause(result.held,result.heldRaw,result.matches,result.offeredRaw)))
		say("/pvph restore reads what the backup holds")
	elseif result.reason=="roundtrip"then
		say(("backup refused: what was encoded did not decode back (%s). The previous one is kept")
			:format(tostring(result.step)))
	elseif result.reason=="encode"then
		say(("backup failed to encode at %s. The previous one is kept")
			:format(tostring(result.step)))
	else
		say("backup did not run: "..tostring(result.reason))
	end

	return said
end

function A.backupStandingLine()
	if not codec then
		return nil
	end

	local held=A.backupStore()
	local refused=held and held.refused
	if type(refused)~="table"then
		return nil
	end

	local since=refused.firstAt or refused.at
	local n=type(refused.n)=="number"and refused.n or 1

	return("the backup has not written since %s, so the copy it holds is %d %s old. "
		.."/pvph backup tries again"):format(tostring(since),n,n==1 and"logout"or"logouts")
end

function A.backupLossLine()
	if not codec then
		return nil
	end

	local held=A.backupStore()
	local current=held and held.current
	if type(current)~="table"or type(current.blob)~="string"then
		return nil
	end

	return("a backup on this character holds %d %s from %s. /pvph restore")
		:format(current.matches or 0,current.matches==1 and"match"or"matches",
			tostring(current.at))
end

local transfer

function A.buildCopyWindow(name,widthKey,heightKey)
	local frame=CreateFrame("Frame",name,UIParent,"BasicFrameTemplateWithInset")
	frame:SetSize(A.metric(widthKey),A.metric(heightKey))
	frame:SetPoint("CENTER")
	A.registerPlacedWindow(frame,"CENTER",0,0)
	frame:SetFrameStrata("DIALOG")
	frame:SetClampedToScreen(true)
	frame:SetMovable(true)
	frame:EnableMouse(true)
	frame:RegisterForDrag("LeftButton")
	frame:SetScript("OnDragStart",frame.StartMoving)
	frame:SetScript("OnDragStop",function(self)
		A.stopDrag(self)
	end)
	frame:Hide()

	frame.title=A.windowTitle(frame)

	local note=frame:CreateFontString(nil,"ARTWORK","GameFontHighlightSmall")
	note:SetPoint("TOPLEFT",frame,"TOPLEFT",16,-34)
	note:SetPoint("TOPRIGHT",frame,"TOPRIGHT",-16,-34)
	note:SetJustifyH("LEFT")
	A.style(note,"bodyText","text")
	frame.note=note
	return frame,note
end

function A.showCopyWindow(frame,buttonKey,failText,title,note,text,confirmText,onConfirm)
	local ok=pcall(function()
		A.setWindowTitle(frame,title)
		frame.note:SetText(note)
		frame.box:SetText(text or"")

		if onConfirm then
			frame.confirm:SetText(confirmText)
			A.fitControl(frame.confirm,A.metric(buttonKey))
			frame.confirm:SetScript("OnClick",function()
				local clicked,done=pcall(onConfirm,frame.box:GetText())
				if not clicked then
					A.say(failText..tostring(done))
					return
				end
				if done then
					frame:Hide()
				end
			end)
			frame.confirm:Show()
		else
			frame.confirm:Hide()
		end

		frame:Show()
		frame.box:SetFocus()
		if text then
			frame.box:HighlightText()
		end
	end)

	return ok
end

local function buildFrame()
	local frame,note=A.buildCopyWindow("WowPvpHistoryTransferFrame","transferWidth","transferHeight")

	local box=A.entry(frame)
	box:SetPoint("TOPLEFT",note,"BOTTOMLEFT",6,-12)
	box:SetPoint("TOPRIGHT",note,"BOTTOMRIGHT",-6,-12)
	box:SetHeight(28)
	box:SetMaxLetters(0)
	box:SetScript("OnEscapePressed",function()frame:Hide()end)
	frame.box=box

	local confirm=A.pill(frame,nil,nil,A.metric("transferButton"))
	confirm:SetPoint("BOTTOMRIGHT",frame,"BOTTOMRIGHT",-16,14)
	frame.confirm=confirm

	A.registerChrome(frame)

	return frame
end

local function frameOrNil()
	if transfer then
		return transfer
	end
	local ok,built=pcall(buildFrame)
	if not ok or not built then
		return nil
	end
	transfer=built
	return transfer
end

function A.showTransfer(title,note,text,confirmText,onConfirm)
	local frame=frameOrNil()
	if not frame then
		return false
	end

	return A.showCopyWindow(frame,"transferButton","the transfer window failed: ",title,note,text,
		confirmText,onConfirm)
end

function A.transferConfirmText(text)
	if not transfer then
		return false
	end
	return(pcall(function()
		transfer.confirm:SetText(text)
		A.fitControl(transfer.confirm,A.metric("transferButton"))
	end))
end

function A.openRestore(which,confirmed)
	local said,say=A.chatCollector()
	local named=which and(which.." ")or""

	if not confirmed then
		local preview,why=A.restorePreview(which)
		if not preview then
			say("restore: "..tostring(why))
			return false,said,false
		end

		local db=A.db()
		if not db then
			say("restore: no database")
			return false,said,false
		end
		say(("restore would replace %d stored %s with %d from the %scopy taken %s")
			:format(#db.matches,#db.matches==1 and"match"or"matches",
				#preview.payload.matches,named,tostring(preview.entry.at)))
		say(("nothing has changed. /pvph restore %sconfirm replaces the history"):format(named))
		return false,said,true
	end

	local result,why=A.applyRestore(which)
	if not result then
		say("restore: "..tostring(why))
		return false,said,false
	end

	say(("restored %d %s from the %scopy taken %s, replacing %d")
		:format(result.matches,result.matches==1 and"match"or"matches",
			named,tostring(result.at),result.replaced))
	if result.indexRebuilt then
		say("the player index was rebuilt. /pvph list reads the records back")
	end
	return true,said,true
end

function A.openExport()
	local said,say=A.chatCollector()

	local text,why,matches=A.exportString()
	if not text then
		say("export: "..tostring(why))
		return false,said
	end

	say(("export string is %d characters, holding %d %s")
		:format(#text,matches,matches==1 and"match"or"matches"))

	if not A.showTransfer("PvP history export",
			"Ctrl+C copies it. Paste it somewhere outside the game.",text,nil,nil)then
		say("the copy window could not be opened, so the string cannot be reached from here")
		return false,said
	end

	return true,said
end

local importPending

function A.openImport()
	local said,say=A.chatCollector()

	if not A.backupAvailable()then
		say("this client provides no encoding surface, so nothing can be imported")
		return false,said
	end

	importPending=nil

	local opened=A.showTransfer("PvP history import",
		"Paste a history string. The first click reads it, the second replaces the history.",nil,
		"Read the paste",function(text)
			local preview,why=A.importPreview(text)
			if not preview then
				A.say("import: "..tostring(why))
				return false
			end

			local db=A.db()
			if not db then
				A.say("import: no database")
				return false
			end
			local held=#preview.payload.matches
			if importPending~=text then
				importPending=text
				if preview.partial then
					local plan=A.partialPlan(db,preview.payload)
					A.say(("import holds %d older %s: %d to add beside the %d stored, %d already stored. "
						.."Click again to add them"):format(held,held==1 and"match"or"matches",plan.added,
						#db.matches,plan.skipped))
					A.transferConfirmText(("Add %d"):format(plan.added))
					return false
				end
				A.say(("import holds %d %s against %d stored. Click again to replace them")
					:format(held,held==1 and"match"or"matches",#db.matches))
				A.transferConfirmText(("Replace %d with %d"):format(#db.matches,held))
				return false
			end

			importPending=nil
			local result
			result,why=A.applyImport(text)
			if not result then
				A.say("import: "..tostring(why))
				return false
			end
			if result.partial then
				A.say(("added %d %s beside the stored ones, %d already stored and left as they were, %d "
					.."given a new number because theirs was in use. %d stored now"):format(result.added,
					result.added==1 and"match"or"matches",result.skipped,result.renumbered,
					result.matches))
				if A.refreshOptionsWindow then
					pcall(A.refreshOptionsWindow,true)
				end
				return true
			end
			A.say(("imported %d %s, replacing %d%s")
				:format(result.matches,result.matches==1 and"match"or"matches",
					result.replaced,result.indexRebuilt and". The player index was rebuilt"or""))
			if A.refreshOptionsWindow then
				pcall(A.refreshOptionsWindow)
			end
			return true
		end)

	if not opened then
		say("the paste window could not be opened, so nothing can be imported from here")
		return false,said
	end

	return true,said
end

local function idsKey(list)
	local ids={}
	for i=1,#list do
		ids[i]=tostring(type(list[i])=="table"and list[i].id or"?")
	end
	return table.concat(ids,",")
end

local function traceRoom(state,fields)
	fields=fields or{}
	A.trace("room",{state=state,reason=fields.reason or"none",keep=fields.keep,n=fields.n,
		leftEarly=fields.leftEarly,bytes=fields.bytes,matched=fields.matched,kept=fields.kept,
		carried=fields.carried,pinned=fields.pinned},"data")
end

function A.exportRoomString(keep)
	if not codec then
		traceRoom("export",{reason="no-codec",keep=keep})
		return nil,A.refusalText("no-codec"),"no-codec"
	end
	local db=A.db()
	if not db then
		return nil,"no database","no-database"
	end
	local selection,why=A.roomSelection(db,keep)
	if not selection then
		traceRoom("export",{reason=why,keep=keep})
		return nil,"no stored match carries a season, so nothing says which seasons are older",why
	end
	if#selection.gone+#selection.goneLeft==0 then
		traceRoom("export",{reason="nothing",keep=keep})
		return nil,("nothing is older than the newest %d %s"):format(keep,keep==1 and"season"or"seasons"),
			"nothing"
	end
	local blob,step=encode({schema=db.schema,partial=true,matches=selection.gone,
		incomplete=selection.goneLeft})
	if not blob then
		traceRoom("export",{reason="encode",keep=keep})
		return nil,"the copy did not encode: "..tostring(step),"encode"
	end
	local text=EXPORT_PREFIX..blob
	traceRoom("export",{keep=keep,n=#selection.gone,leftEarly=#selection.goneLeft,bytes=#text})
	return text,nil,selection
end

function A.roomReadBack(text)
	local preview,why,token=A.importPreview(text)
	if not preview then
		return nil,why,token
	end
	if not preview.partial then
		return nil,"this is a whole history string, not the copy of the older seasons","whole"
	end
	local copy=preview.payload
	return#copy.matches,type(copy.incomplete)=="table"and#copy.incomplete or 0,idsKey(copy.matches)
end

function A.applyRoom(pending)
	local db=A.db()
	if not db then
		traceRoom("removed",{reason="no-database"})
		return nil,"no database","no-database"
	end
	if type(pending)~="table"or pending.read~=true then
		traceRoom("removed",{reason="unread"})
		return nil,"the copy has not been read back yet, so nothing was removed","unread"
	end
	if A.matchInFlight(db)then
		traceRoom("removed",{reason="in-flight",keep=pending.keep})
		return nil,A.refusalText("in-flight"),"in-flight"
	end
	local selection=A.roomSelection(db,pending.keep)
	if not selection or#selection.gone~=pending.n or#selection.goneLeft~=pending.left
		or idsKey(selection.gone)~=pending.ids then
		traceRoom("removed",{reason="changed",keep=pending.keep})
		return nil,"the history changed since the copy was made, so nothing was removed. Make the copy "
			.."again","changed"
	end

	local pinned=false
	if not A.sandboxed()then
		local pin=A.pinBackup()
		if not pin.ok and pin.reason~="no-codec"and pin.reason~="smaller"then
			traceRoom("removed",{reason="pin-failed",keep=pending.keep})
			return nil,A.refusalText("pin-failed"),"pin-failed"
		end
		if pin.reason=="smaller"then
			A.pinLargerRotationCopy()
		end
		pinned=pin.ok==true or pin.reason=="smaller"
	end

	local before=#db.matches
	local oldPlayers=type(db.players)=="table"and db.players or{}
	db.matches=selection.kept
	if type(db.incomplete)=="table"then
		db.incomplete=selection.keptLeft
	end
	local rebuilt,rebuildError=pcall(A.rebuildIndex)
	if not rebuilt then
		A.noteError(rebuildError,"room-index")
	end
	local carried=0
	if type(db.players)=="table"then
		for guid,entry in pairs(oldPlayers)do
			if db.players[guid]==nil then
				if type(entry)=="table"then
					entry.carried=true
				end
				db.players[guid]=entry
				carried=carried+1
			end
		end
	end

	local held=A.backupStore()
	local current=held and held.current
	if not A.sandboxed()and type(current)=="table"and type(current.matches)=="number"
		and current.matches>#db.matches then
		held.previous,held.current,held.refused=current,nil,nil
	end

	local pruned,pruneError=pcall(A.notePrune,"room",before)
	if not pruned then
		A.noteError(pruneError,"room-prune")
	end
	A.storeReplaced()
	traceRoom("removed",{keep=pending.keep,n=#selection.gone,leftEarly=#selection.goneLeft,
		kept=#db.matches,carried=carried,pinned=pinned})
	return{removed=#selection.gone,leftEarly=#selection.goneLeft,kept=#db.matches,
		carried=carried,pinned=pinned,indexRebuilt=rebuilt}
end

local roomPending

function A.roomPending()
	return roomPending
end

function A.openRoomMove(keep)
	local said,say=A.chatCollector()
	roomPending=nil
	keep=tonumber(keep)
	if keep==nil or keep<1 or keep~=math.floor(keep)then
		say("make room: name how many seasons to keep, 1 or more")
		return false,said
	end

	local text,why,selection=A.exportRoomString(keep)
	if not text then
		say("make room: "..tostring(why))
		return false,said
	end
	local n,left=#selection.gone,#selection.goneLeft
	roomPending={keep=keep,n=n,left=left,ids=idsKey(selection.gone),text=text,
		emptied=false,read=false}
	say(("make room: %d %s older than the newest %d %s, in a string of %d characters. Copy it out, "
		.."then paste it back to check it"):format(n,n==1 and"match"or"matches",keep,
		keep==1 and"season"or"seasons",#text))

	local opened=A.showTransfer(("Keep %d %s"):format(keep,keep==1 and"season"or"seasons"),
		("Ctrl+C copies the %d older %s. Keep it outside the game, then paste it back here."):format(n,
			n==1 and"match"or"matches"),text,"Read the copy back",function(box)
			local pending=roomPending
			if not pending then
				return true
			end
			if not pending.read then
				local cleaned=type(box)=="string"and box:gsub("%s+","")or""
				if not pending.emptied and cleaned==pending.text then
					pending.emptied=true
					pcall(function()transfer.box:SetText("")end)
					traceRoom("read-back",{reason="unpasted",keep=pending.keep})
					A.say("make room: paste the copy you kept into the box, then click Read the copy back")
					return false
				end
				local got,gotLeft,third=A.roomReadBack(box)
				if got==nil then
					traceRoom("read-back",{reason=tostring(third or"unreadable"),keep=pending.keep})
					A.say("make room: "..tostring(gotLeft)..". Nothing was removed")
					return false
				end
				if got~=pending.n or gotLeft~=pending.left then
					traceRoom("read-back",{reason="short",keep=pending.keep,matched=got,n=pending.n})
					A.say(("make room: the paste holds %d %s and the copy holds %d. Nothing was removed")
						:format(got,got==1 and"match"or"matches",pending.n))
					return false
				end
				if third~=pending.ids then
					traceRoom("read-back",{reason="other",keep=pending.keep,matched=got,n=pending.n})
					A.say("make room: the paste holds other matches than the copy made here. Nothing was removed")
					return false
				end
				pending.read=true
				traceRoom("read-back",{keep=pending.keep,matched=got,n=pending.n})
				A.say(("make room: the copy reads back whole, %d %s. Remove %d %s takes them out of the "
					.."history"):format(got,got==1 and"match"or"matches",got,
					got==1 and"match"or"matches"))
				A.transferConfirmText(("Remove %d %s"):format(got,got==1 and"match"or"matches"))
				return false
			end

			roomPending=nil
			local result,refusal=A.applyRoom(pending)
			if not result then
				A.say("make room: "..tostring(refusal))
				return true
			end
			A.say(("made room: %d %s removed, %d kept. Notes and ratings are unchanged, a player met only "
				.."in the removed seasons keeps their counts, and a player also met in a kept season is "
				.."counted from the matches that stay%s")
				:format(result.removed,result.removed==1 and"match"or"matches",result.kept,
					result.pinned and". A pinned copy holds the history as it was"or""))
			if A.refreshOptionsWindow then
				pcall(A.refreshOptionsWindow,true)
			end
			return true
		end)

	if not opened then
		roomPending=nil
		say("the copy window could not be opened, so nothing can be moved from here")
		return false,said
	end
	return true,said
end

local SETTINGS_KEYS={
	alerts="on",announce="on",announceComp="on",announceRematch="on",chatMark="on",
	closeWithMain="on",contextMenu="on",duels="on",finder="on",finderDocked="on",
	groupNotes="on",hold="on",loginLine="on",minimapShown="on",mmrLine="on",
	openAfterMatch="on",overlayCombat="on",postGame="on",realms="on",rememberFilters="on",
	rememberTab="on",sight="on",tally="on",toast="on",tooltip="on",world="on",

	overlayShown="off",overlayTwo="off",soundBad="off",soundBest="off",soundSaved="off",
	figuresFollow="off",largeText="off",denseRows="off",

	announceCrowd="value",announceOpacity="value",announceShape="value",announceSize="value",
	overlayCount="value",overlayOpacity="value",windowScale="value",
	lossNudge="value",goalPlayed="value",goalWon="value",noteTemplates="list",
	skillWords={kind="words",default="skill"},
	attitudeWords={kind="words",default="attitude"},
	clock={kind="value",default="game"},
	theme={kind="value",default="blizzard"},
	resultPair={kind="value",default="green"},
	announceSeconds={kind="value",default=5},
	toastSeconds={kind="value",default=5},

	geometry="machine",tab="machine",character="machine",sessionFolds="machine",
	announcePosition="machine",overlayPosition="machine",tallyPosition="machine",
	finderPosition="machine",toastPosition="machine",minimapAngle="machine",
	minimapFree="machine",announceUnlocked="machine",tallyUnlocked="machine",
	toastUnlocked="machine",welcomed="machine",mute="machine",pausedUntil="machine",
	recapSeenEpoch="machine",matchFiltersAt="machine",matchSearch="machine",
	matchResult="machine",matchSpec="machine",matchZone="machine",compPairs="machine",
	compFilter="machine",graphFolded="machine",readingCollapsed="machine",
	cardsFolded="machine",lobbySort="machine",lobbySortUp="machine",seasonScope="machine",
	statsView="machine",debug="machine",debugText="machine",

	announceTime="machine",
}

local SETTING_SETTERS={
	alerts={"setAlerts"},announce={"setAnnounce"},announceComp={"setAnnounceComp"},
	announceRematch={"setAnnounceRematch"},chatMark={"setChatMark"},
	closeWithMain={"setCloseWithMain"},contextMenu={"setContextMenu"},duels={"setDuels"},
	finder={"setFinder"},finderDocked={"setFinderDocked"},groupNotes={"setGroupNotes"},
	hold={"setHold"},loginLine={"setLoginLine"},minimapShown={"setMinimapShown"},
	mmrLine={"setMmrLine"},openAfterMatch={"setOpenAfterMatch"},
	overlayCombat={"setOverlayCombat"},postGame={"setPostGame"},realms={"setRealms"},
	rememberFilters={"setRememberFilters"},rememberTab={"setRememberTab"},sight={"setSight"},
	tally={"setTally"},toast={"setToast"},tooltip={"setTooltip"},world={"setWorld"},

	overlayShown={"setOverlay"},overlayTwo={"setOverlayTwo"},
	soundBad={"setSound","badArrival"},soundBest={"setSound","newBest"},
	soundSaved={"setSound","saved"},figuresFollow={"setFiguresFollow"},
	largeText={"setLargeText"},denseRows={"setDenseRows"},

	announceCrowd={"setAnnounceCrowd"},announceOpacity={"setAnnounceOpacity"},
	announceShape={"setAnnounceShape"},announceSize={"setAnnounceSize"},
	announceSeconds={"setAnnounceTime"},toastSeconds={"setToastSeconds"},overlayCount={"setOverlayCount"},
	overlayOpacity={"setOverlayOpacity"},windowScale={"setWindowScale"},
	lossNudge={"setLossNudge"},noteTemplates={"setNoteTemplates"},goalPlayed={"setGoal","played"},goalWon={"setGoal","won"},
	clock={"setClock"},theme={"setTheme"},resultPair={"setResultPair"},
	skillWords={"setStepWords","skill"},attitudeWords={"setStepWords","attitude"},
}

function A.settingSetter(key)
	local entry=SETTING_SETTERS[key]
	if entry then
		return entry[1],entry[2]
	end
	return nil
end

function A.settingsKeyKind(key)
	local entry=SETTINGS_KEYS[key]
	if type(entry)=="table"then
		return entry.kind,entry.default
	end
	return entry,nil
end

function A.settingsKeys()
	local out={}
	for key in pairs(SETTINGS_KEYS)do
		out[#out+1]=key
	end
	table.sort(out)
	return out
end

local function travels(key,value)
	local kind,default=A.settingsKeyKind(key)
	if kind=="list"then
		return type(value)=="table"and next(value)~=nil and A.noteTemplatesValid(value)
	end
	if kind=="words"then
		return type(value)=="table"and next(value)~=nil and A.stepWordsValid(default,value)
	end
	local scalar=type(value)=="string"or type(value)=="number"or type(value)=="boolean"
	if kind==nil or kind=="machine"or not scalar then
		return false
	end
	if kind=="on"then
		return value==false
	end
	if kind=="off"then
		return value==true
	end
	return value~=default
end

function A.exportSettingsString()
	if not codec then
		A.trace("settings-string",{state="export",reason="no-codec"},"data")
		return nil,A.refusalText("no-codec")
	end
	local db=A.db()
	if not db then
		return nil,"no database"
	end
	local ui=type(db.ui)=="table"and db.ui or{}
	local out,keys,unknown={},0,0
	for key,value in pairs(ui)do
		if travels(key,value)then
			out[key]=value
			keys=keys+1
		elseif A.settingsKeyKind(key)==nil then
			unknown=unknown+1
		end
	end
	local blob,step=encode({settings=out})
	if not blob then
		A.trace("settings-string",{state="export",reason="encode"},"data")
		return nil,"the settings did not encode: "..tostring(step)
	end
	A.trace("settings-string",{state="export",reason="none",keys=keys,unknown=unknown},"data")
	return SETTINGS_PREFIX..blob,nil,keys
end

function A.settingsPreview(text)
	local cleaned,sentence,token=cleanedPaste(text)
	if not cleaned then
		return nil,sentence,token
	end
	if cleaned:match("^WPH!")then
		return nil,A.refusalText("history-string"),"history-string"
	end
	local format=tonumber(cleaned:match("^WPHS!(%d+)!")or"")
	if format~=nil and format>SETTINGS_FORMAT then
		return nil,A.refusalText("newer"),"newer"
	end
	if cleaned:sub(1,#SETTINGS_PREFIX)~=SETTINGS_PREFIX then
		return nil,A.refusalText("not-ours"),"not-ours"
	end
	local value=decode(cleaned:sub(#SETTINGS_PREFIX+1))
	if not value or type(value.settings)~="table"then
		return nil,A.refusalText("unreadable"),"unreadable"
	end
	if A.sandboxed()then
		return nil,A.refusalText("sandbox"),"sandbox"
	end

	local write,names,unknown,dropped={},{},{},{}
	for key,held in pairs(value.settings)do
		local carried=key
		if key=="announceTime"and value.settings.announceSeconds==nil then
			key,held="announceSeconds",A.announceSecondsFromPercent(held)
		end
		local name=tostring(held~=nil and key or carried)
		local kind=type(key)=="string"and A.settingsKeyKind(key)or nil
		if kind==nil or kind=="machine"then
			unknown[#unknown+1]=name
		elseif travels(key,held)then
			write[key]=held
			names[#names+1]=name
		elseif type(held)=="string"or type(held)=="number"or type(held)=="boolean"then
			dropped[#dropped+1]=name
		else
			unknown[#unknown+1]=name
		end
	end
	table.sort(names)
	table.sort(unknown)
	table.sort(dropped)
	return{write=write,keys=#names,names=names,unknown=unknown,dropped=dropped}
end

local function sameSetting(held,value)
	if type(held)~="table"or type(value)~="table"then
		return held==value
	end
	for slot,text in pairs(value)do
		if held[slot]~=text then
			return false
		end
	end
	for slot in pairs(held)do
		if value[slot]==nil then
			return false
		end
	end
	return true
end

function A.importSettingsString(text)
	local preview,why,token=A.settingsPreview(text)
	if not preview then
		A.trace("settings-string",{state="import",reason=token},"data")
		return nil,why
	end
	local db=A.db()
	if not db then
		A.trace("settings-string",{state="import",reason="no-database"},"data")
		return nil,"no database"
	end
	db.ui=type(db.ui)=="table"and db.ui or{}
	local order={}
	for key in pairs(preview.write)do
		order[#order+1]=key
	end
	table.sort(order)
	local refused=0
	for _,key in ipairs(order)do
		local value=preview.write[key]
		local name,lead=A.settingSetter(key)
		local setter=name and A[name]
		if type(setter)=="function"then
			local ran,err
			if lead~=nil then
				ran,err=pcall(setter,lead,value)
			else
				ran,err=pcall(setter,value)
			end
			if not ran then
				A.noteError(err,"settings-import")
			end
			if not sameSetting(db.ui[key],value)then
				refused=refused+1
			end
		else
			db.ui[key]=value
		end
	end
	if type(A.notifyEverySetting)=="function"then
		pcall(A.notifyEverySetting)
	end
	if type(A.refreshOptionsWindow)=="function"then
		pcall(A.refreshOptionsWindow)
	end
	if type(A.refreshWindow)=="function"then
		pcall(A.refreshWindow)
	end
	A.trace("settings-string",{state="import",reason="none",keys=preview.keys,
		unknown=#preview.unknown,dropped=#preview.dropped,refusals=refused},"data")
	preview.refusals=refused
	return preview
end

function A.openSettingsExport()
	local said,say=A.chatCollector()
	local text,why,keys=A.exportSettingsString()
	if not text then
		say("settings export: "..tostring(why))
		return false,said
	end
	say(("settings string is %d characters, holding %d %s that differ from the defaults")
		:format(#text,keys,keys==1 and"setting"or"settings"))
	if not A.showTransfer("PvP history settings export",
			"Ctrl+C copies your settings alone. Positions and window sizes stay on this computer.",text,
			nil,nil)then
		say("the copy window could not be opened, so the string cannot be reached from here")
		return false,said
	end
	return true,said
end

local settingsPending

function A.openSettingsImport()
	local said,say=A.chatCollector()
	if not A.backupAvailable()then
		say("this client provides no encoding surface, so nothing can be imported")
		return false,said
	end
	settingsPending=nil
	local opened=A.showTransfer("PvP history settings import",
		"Paste a settings string. The first click reads it, the second writes the settings.",nil,
		"Read the paste",function(text)
			local preview,why,token=A.settingsPreview(text)
			if not preview then
				A.trace("settings-string",{state="preview",reason=token},"data")
				A.say("settings import: "..tostring(why))
				return false
			end
			if settingsPending~=text then
				settingsPending=text
				A.trace("settings-string",{state="preview",reason="none",keys=preview.keys,
					unknown=#preview.unknown,dropped=#preview.dropped},"data")
				A.say(("settings import holds %d %s: %s. Click again to write them")
					:format(preview.keys,preview.keys==1 and"setting"or"settings",
						preview.keys>0 and table.concat(preview.names,", ")or"none"))
				if#preview.unknown>0 then
					A.say(("these are not settings this version knows, and are left out: %s")
						:format(table.concat(preview.unknown,", ")))
				end
				A.transferConfirmText(("Write %d %s"):format(preview.keys,
					preview.keys==1 and"setting"or"settings"))
				return false
			end
			settingsPending=nil
			local written,refusal=A.importSettingsString(text)
			if not written then
				A.say("settings import: "..tostring(refusal))
				return false
			end
			A.say(("wrote %d %s. /reload draws every one of them")
				:format(written.keys-written.refusals,written.keys-written.refusals==1 and"setting"
					or"settings"))
			if written.refusals>0 then
				A.say(("%d %s not taken, holding a value this version refuses")
					:format(written.refusals,written.refusals==1 and"setting was"or"settings were"))
			end
			return true
		end)
	if not opened then
		say("the paste window could not be opened, so nothing can be imported from here")
		return false,said
	end
	return true,said
end

A.on("PLAYER_LOGOUT",function()
	local worldState="unavailable"
	if type(A.closeWorldSession)=="function"then
		local ran,result=pcall(A.closeWorldSession,"logout")
		if not ran then
			worldState="threw"
			A.noteError(result,"backup-world-close")
		else
			worldState=result and"closed"or"none-open"
		end
	end
	A.trace("logout",{state="reached",source="backup",reason=worldState})

	local ok,err=pcall(A.takeBackup)
	if not ok then
		A.noteError(err,"backup-logout")
	end
end)
