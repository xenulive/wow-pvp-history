-- WowPvpHistory 0.70.16
-- Author:  Xenu-Sentinels
-- Project: wow-pvp-history
--          https://github.com/xenulive/wow-pvp-history
-- License: MIT, see LICENSE
local _,A=...

local function count(subject)
	if type(subject)~="table"then
		return 0
	end
	local n=0
	for _ in pairs(subject)do
		n=n+1
	end
	return n
end

local function drops(db)
	local total=0
	for _,n in pairs(db.dropped or{})do
		if type(n)=="number"then
			total=total+n
		end
	end
	return total
end

local function pinPlan(db)
	if not A.backupAvailable()then
		return{state="none",reason="no-codec"}
	end

	local held=A.backupStore()
	local pinned=held and held.pinned
	local heldReal,offeredReal=A.pinGate(db)
	if heldReal~=nil and heldReal>offeredReal then
		return{state="keep",held=heldReal,matches=offeredReal,at=pinned.at}
	end

	return{state="write",matches=#db.matches,
		replaced=type(pinned)=="table"and pinned.matches or nil}
end

function A.resetPreview()
	local db=A.db()
	if not db then
		return nil
	end

	local noted=0
	if type(A.notedCount)=="function"then
		noted=A.notedCount()or 0
	end

	return{
		matches=#db.matches,
		players=count(db.players),
		noted=noted,
		incomplete=#(db.incomplete or{}),
		drops=drops(db),
		nextMatchId=db.nextMatchId,
		nextIncompleteId=db.nextIncompleteId,
		inFlight=db.active~=nil,
		sandboxed=A.sandboxed(),
		pin=pinPlan(db),
	}
end

function A.resetLine(before)
	before=before or A.resetPreview()
	if not before then
		return nil
	end

	return("%d %s, %d indexed %s, %d with a note, %d incomplete %s and %d counted %s"):format(
		before.matches,before.matches==1 and"match"or"matches",
		before.players,before.players==1 and"player"or"players",
		before.noted,
		before.incomplete,before.incomplete==1 and"entry"or"entries",
		before.drops,before.drops==1 and"drop"or"drops")
end

local function factory(db,schema)
	local pruneLog=db.pruneLog
	local characters=db.characters
	for key in pairs(db)do
		db[key]=nil
	end
	db.pruneLog=pruneLog
	db.characters=characters

	db.schema=type(schema)=="number"and schema or A.schema
	db.matches={}
	db.nextMatchId=1
	db.nextFixtureId=1
	db.dropped={}
	db.dropEvents={}
	db.incomplete={}
	db.nextIncompleteId=1
	db.players={}
	db.ui={}
	db.arenaMapRefiled=true
end

local function redrive()
	local function attempt(fn)
		if type(fn)=="function"then
			pcall(fn)
		end
	end

	attempt(A.resetActiveTab)
	attempt(A.resetActiveCharacter)
	attempt(A.applyMinimapState)
	attempt(function()
		A.setSessionWindowScale(nil,"store")
	end)
	attempt(A.applyWindowGeometry)
	attempt(A.replaceOtherWindows)
	attempt(A.applyChrome)
	attempt(A.storeReplaced)

	attempt(A.notifyEverySetting)

	if type(A.refreshOptionsWindow)=="function"then
		pcall(A.refreshOptionsWindow)
	end
end

function A.applyReset()
	local db=A.db()
	if not db then
		return nil,"no database","no-database"
	end

	if db.active~=nil then
		A.trace("reset",{state="refused",reason="in-flight"},"data")
		return nil,A.refusalText("in-flight"),"in-flight"
	end

	if A.sandboxed()then
		A.trace("reset",{state="refused",reason="sandbox"},"data")
		return nil,A.refusalText("sandbox"),"sandbox"
	end

	local before=A.resetPreview()
	if not before then
		A.trace("reset",{state="refused",reason="no-database"},"data")
		return nil,"no database","no-database"
	end

	local pin=A.pinBackup()

	if not pin.ok and pin.reason~="no-codec"and pin.reason~="smaller"then
		A.trace("reset",{state="refused",reason="pin-failed"},"data")
		return nil,A.refusalText("pin-failed"),"pin-failed"
	end

	A.clearBackupGenerations()

	local why
	if not pin.ok then
		why=pin.reason
	end

	A.trace("reset",{
		state="applied",
		n=before.matches,
		players=before.players,
		notes=before.noted,
		incomplete=before.incomplete,
		drops=before.drops,
		pinned=pin.ok==true,
		reason=why,
	},"data")

	local storedBefore=#db.matches
	factory(db,db.schema)

	pcall(A.notePrune,"reset",storedBefore)

	redrive()

	before.pin=pin
	return before
end

function A.pinLine(pin)
	if pin.state=="write"then
		local line=("a copy of all of it is pinned first, and /pvph restore pinned brings it "
			.."back")
		if pin.replaced then
			line=line..(". It replaces a pin holding %d"):format(pin.replaced)
		end
		return line
	end

	if pin.state=="keep"then
		return("the pin already holds %d %s from %s and is larger, so it is kept rather than "
			.."overwritten"):format(pin.held,pin.held==1 and"match"or"matches",
			tostring(pin.at))
	end

	return"NOTHING IS PINNED: this client provides no encoding surface, so none of this comes back"
end

local resetArmed=false

function A.openResetConfirm()
	local said,say=A.chatCollector()

	local before=A.resetPreview()
	if not before then
		say("reset: no database")
		return false,said
	end

	if before.inFlight then
		say(A.refusalText("in-flight"))
		return false,said
	end
	if before.sandboxed then
		say(A.refusalText("sandbox"))
		return false,said
	end

	resetArmed=false

	local note
	if before.pin.state~="none"then
		local line=A.pinLine(before.pin)
		note="This cannot be undone from the interface. "..line:sub(1,1):upper()..line:sub(2)
			..". Click twice."
	else
		note="NOTHING WILL BE PINNED: this client provides no encoding surface, so none of this "
			.."comes back. Click twice."
	end

	local opened=A.showTransfer("Erase the PvP history",note,A.resetLine(before),
		"Erase all of it",function()
			if not resetArmed then
				resetArmed=true
				A.transferConfirmText("Click again to erase")
				return false
			end

			resetArmed=false
			local result,why=A.applyReset()
			if not result then
				A.say("reset: "..tostring(why))
				return false
			end

			A.say(("reset: %d %s erased"):format(result.matches,
				result.matches==1 and"match"or"matches"))
			if result.pin.ok then
				A.say("a copy is pinned. /pvph restore pinned brings it back")
			elseif result.pin.reason=="smaller"then
				A.say("the larger pin already held was kept rather than overwritten")
			end
			return true
		end)

	if not opened then
		say("the confirm window could not be opened, so nothing was erased. /pvph reset")
	end

	return opened,said
end
