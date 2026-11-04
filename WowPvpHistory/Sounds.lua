-- WowPvpHistory 0.75.26
-- Author:  Xenu-Sentinels
-- Project: wow-pvp-history
--          https://github.com/xenulive/wow-pvp-history
-- License: MIT, see LICENSE
local _,A=...

local CUES={
	badArrival={kit="RAID_WARNING",setting="soundBad",word="bad",sound="the raid warning",
		label="Somebody at the worst skill or attitude joins or stands at the gates"},
	newBest={kit="UI_EPICLOOT_TOAST",setting="soundBest",word="best",sound="the epic loot toast",
		label="A match beats one of your bests"},
	saved={kit="UI_BNET_TOAST",setting="soundSaved",word="saved",sound="the Battle.net toast",
		label="The match is saved"},
}
local ORDER={"badArrival","newBest","saved"}

local THROTTLE_SECONDS=2

local playedAt={}
local playedFor={}

local SOUND_OFF_CVARS={"Sound_EnableAllSound","Sound_EnableSFX"}

function A.soundKinds()
	local out={}
	for i=1,#ORDER do
		out[i]=ORDER[i]
	end
	return out
end

function A.soundKindFor(word)
	for i=1,#ORDER do
		if CUES[ORDER[i]].word==word then
			return ORDER[i]
		end
	end
	return nil
end

function A.soundKitName(kind)
	local cue=CUES[kind]
	return cue and cue.kit or nil
end

function A.soundCueText(kind)
	local cue=CUES[kind]
	return cue and cue.sound or nil
end

function A.soundLabel(kind)
	local cue=CUES[kind]
	return cue and cue.label or nil
end

function A.soundEnabled(kind)
	local cue=CUES[kind]
	local db=A.db()
	if cue==nil or not db or type(db.ui)~="table"then
		return false
	end
	return db.ui[cue.setting]==true
end

function A.setSound(kind,enabled)
	local cue=CUES[kind]
	local db=A.db()
	if cue==nil or not db then
		return false
	end
	db.ui=db.ui or{}
	db.ui[cue.setting]=enabled==true or nil
	if A.notifySoundSetting then
		A.notifySoundSetting(kind)
	end
	return true
end

local function muted()
	if A.guardedCall(InCinematic)==true then
		return true
	end
	local read=C_CVar and C_CVar.GetCVar
	for i=1,#SOUND_OFF_CVARS do
		if A.guardedCall(read,SOUND_OFF_CVARS[i])=="0"then
			return true
		end
	end
	return false
end

function A.playCue(kind,once,force)
	local cue=CUES[kind]
	local now=A.guardedCall(GetTime)
	local reason
	if cue==nil then
		reason="no-id"
	elseif not force and not A.soundEnabled(kind)then
		reason="off"
	elseif once~=nil and playedFor[kind]==once then
		reason="throttled"
	elseif type(now)=="number"and playedAt[kind]and now-playedAt[kind]<THROTTLE_SECONDS then
		reason="throttled"
	end

	local id=cue and reason==nil and type(SOUNDKIT)=="table"and rawget(SOUNDKIT,cue.kit)or nil
	if reason==nil and type(id)~="number"then
		reason="no-id"
	elseif reason==nil and muted()then
		reason="muted"
	elseif reason==nil then
		local willPlay=A.guardedCall(PlaySound,id,"SFX")
		if willPlay==true then
			reason="none"
			playedAt[kind]=now
			if once~=nil then
				playedFor[kind]=once
			end
		else
			reason=willPlay==false and"muted"or"no-call"
		end
	end

	local played=reason=="none"
	A.trace("sound",{kind=tostring(kind),played=played,reason=reason},"ui")
	return played,reason
end

function A.cueGroupArrival(guids)
	for i=1,#guids do
		local note=A.noteFor(guids[i])
		if type(note)=="table"and(note.rating==-2 or note.attitude==-2)then
			return A.playCue("badArrival")
		end
	end
	return false
end

function A.cueGatesRoster(names,once)
	for i=1,#names do
		if names[i].rating==-2 or names[i].attitude==-2 then
			return A.playCue("badArrival",once)
		end
	end
	return false
end

function A.reportSound(word,value)
	local kind=A.soundKindFor(word)
	if word==nil then
		for i=1,#ORDER do
			local each=ORDER[i]
			A.say(("sound %s: %s, %s"):format(CUES[each].word,A.soundEnabled(each)and"on"or"off",
				CUES[each].sound))
		end
		return
	end
	if kind==nil then
		A.say(("unknown sound %q. bad, best or saved, then on or off; the word alone plays it"):format(word))
		return
	end
	if value=="on"or value=="off"then
		if not A.setSound(kind,value=="on")then
			A.say("no database, so the setting could not be stored")
			return
		end
		A.say(("sound %s %s"):format(word,value))
		return
	end
	if value~=nil then
		A.say(("unknown sound command %q. on or off; the word alone plays it"):format(value))
		return
	end
	local played,reason=A.playCue(kind,nil,true)
	if played then
		A.say(("played %s"):format(CUES[kind].sound))
	elseif reason=="muted"then
		A.say("the game's sound is off or a cutscene is playing, so nothing played")
	elseif reason=="throttled"then
		A.say("that sound just played. Try again in a moment")
	elseif reason=="no-call"then
		A.say("the game did not take the sound, so nothing played")
	else
		A.say("this client has no such sound, so nothing played")
	end
end
