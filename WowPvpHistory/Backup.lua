-- WowPvpHistory 0.70.27
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

local function payload(db)
	local out={}
	for key,value in pairs(db)do
		if not EXCLUDED[key]then
			out[key]=value
		end
	end
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

local function refill(db,value,keep,mergeRegistry)
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

	db.active=nil

	local LOAD_PASSES={
		{"backfillGameSeason","backup-game-season"},
		{"refileArenaMapBattlegrounds","backup-refile"},
		{"supersedeTypedResults","backup-typed-results"},
	}
	for i=1,#LOAD_PASSES do
		local pass=A[LOAD_PASSES[i][1]]
		if type(pass)=="function"then
			local ran,passError=pcall(pass,db)
			if not ran then
				A.noteError(passError,LOAD_PASSES[i][2])
			end
		end
	end

	db.players={}
	db.playerIndexVersion=nil
	local rebuilt,rebuildError=pcall(A.rebuildIndex)
	if not rebuilt then
		A.noteError(rebuildError,"backup-index")
		A.say(("the history is restored and the player index was not rebuilt: %s. /pvph rebuild")
			:format(tostring(rebuildError)))
	end

	pcall(A.noteCanary)
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
	local charsKept,charsTaken,charsBoth,indexRebuilt=refill(db,preview.payload,RESTORE_KEEPS,true)
	local held=A.backupStore()
	local current=held and held.current
	if type(current)=="table"and type(current.matches)=="number"then
		local heldReal,restoredReal=gatePair(current.matches,current.generated,#db.matches,
			generatedCount(db))
		if heldReal>restoredReal then
			held.previous,held.current,held.refused=current,nil,nil
		end
	end
	pcall(A.notePrune,"restore",before)
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

function A.importPreview(text)
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
	local format=tonumber(cleaned:match("^WPH!(%d+)!")or"")
	if format~=nil and format>EXPORT_FORMAT then
		return nil,A.refusalText("newer")..(" (it holds format %s and this addon reads format %s)")
			:format(tostring(format),tostring(EXPORT_FORMAT)),"newer"
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

	local busy,busyToken=busyRefusal()
	if busy then
		return nil,busy,busyToken
	end

	return{payload=checked}
end

local IMPORT_KEEPS={"ui","characters","lastError","lastErrorAt","pruneLog"}

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

	local before=#db.matches
	local _,_,_,indexRebuilt=refill(db,preview.payload,IMPORT_KEEPS)
	if type(db.ui)=="table"then
		db.ui.sessionFolds=nil
	end
	pcall(A.notePrune,"import",before)
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

	local title=A.windowTitle(frame)
	title:SetPoint("TOP",frame,"TOP",0,-6)
	A.style(title,"heading","bright")
	frame.title=title

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
		frame.title:SetText(title)
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

A.on("PLAYER_LOGOUT",function()
	if type(A.closeWorldSession)=="function"then
		local closed,why=pcall(A.closeWorldSession,"logout")
		if not closed then
			A.noteError(why,"backup-world-close")
		end
	end

	local ok,err=pcall(A.takeBackup)
	if not ok then
		A.noteError(err,"backup-logout")
	end
end)
