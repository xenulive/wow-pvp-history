-- WowPvpHistory 0.75.26
-- Author:  Xenu-Sentinels
-- Project: wow-pvp-history
--          https://github.com/xenulive/wow-pvp-history
-- License: MIT, see LICENSE
local _,A=...

function A.loginLineEnabled()
	local db=A.db()
	if not db then
		return true
	end
	return not(type(db.ui)=="table"and db.ui.loginLine==false)
end

function A.setLoginLine(enabled)
	local db=A.db()
	if not db then
		return false
	end
	db.ui=db.ui or{}
	if enabled==false then
		db.ui.loginLine=false
	else
		db.ui.loginLine=nil
	end

	if A.notifyLoginLineSetting then
		A.notifyLoginLineSetting()
	end
	return true
end

local function canaryAnnouncing()
	if type(A.canaryAnnouncedThisLogin)=="function"and A.canaryAnnouncedThisLogin()==true then
		return true
	end
	return type(A.canaryWillAnnounce)=="function"and A.canaryWillAnnounce()==true
end

function A.loginLines()
	local out={}
	local function add(text,register)
		out[#out+1]={text=text,register=register}
	end

	local db=A.db()
	if not db then
		add("nothing is stored: the account-wide database did not load, so no match "
			.."can be recorded","fault")
	else
		if type(A.lastErrorLines)=="function"then
			local lines=A.lastErrorLines(A.savedDB()or db)
			if type(lines)=="table"then
				for i=1,#lines do
					add(lines[i],"fault")
				end
			end
		end
	end

	if type(A.backupStandingLine)=="function"then
		local standing=A.backupStandingLine()
		if type(standing)=="string"then
			add(standing,"standing")
		end
	end

	if#out==0 and A.loginLineEnabled()and not canaryAnnouncing()then
		add(("v%s loaded. /pvph opens the match history"):format(tostring(A.version)),"routine")
	end

	return out
end

function A.rememberCharacter()
	local db=A.db()
	if not db then
		return false
	end

	local guid=A.ownGuid()
	if type(guid)~="string"or guid==""then
		return false
	end

	if type(UnitName)~="function"then
		return false
	end
	local ok,name=pcall(UnitName,"player")
	local isString=ok and type(name)=="string"
	local readable=isString and A.canRead(name)
	if isString and not readable then
		A.trace("character",{source="login",state="refused",reason="secret"},"data")
		return false
	end
	if not(readable and name~="")then
		return false
	end

	db.characters=db.characters or{}
	local held=db.characters[guid]
	local known=held~=nil
	local realm=A.ownRealm()
	if type(realm)~="string"or realm==""then
		realm=type(held)=="table"and held.realm or nil
	end
	db.characters[guid]={
		name=name,
		realm=realm,
		at=A.stamp(),
	}

	local count=0
	for _ in pairs(db.characters)do
		count=count+1
	end

	A.trace("character",{
		source="login",
		state=known and"known"or"first",
		n=count,
	},"data")
	return true
end

local function announce()
	local lines=A.loginLines()
	for i=1,#lines do
		A.say(lines[i].text,lines[i].register)
	end
	local okPause,paused=pcall(A.pauseLoginLine)
	if not okPause then
		A.noteError(paused,"login.pause")
	elseif type(paused)=="string"then
		A.say(paused,"standing")
	end
	local ok,recap=pcall(A.sessionRecapLogin,time())
	if not ok then
		A.noteError(recap,"login.recap")
	elseif type(recap)=="string"then
		A.say(recap,"routine")
	end
end

A.on("PLAYER_LOGIN",function()
	local remembered,err=pcall(A.rememberCharacter)
	if not remembered then
		A.noteError(err,"login.character")
	end
	pcall(A.pruneSessionFolds)
	announce()
end)

local WELCOME_NAME="WowPvpHistoryWelcome"
local WELCOME_WIDTH,WELCOME_PAD=440,16

local welcome
local welcomeWaiting

function A.welcomeGate()
	local db=A.savedDB()
	if not db then
		return false,"no-database"
	end
	if type(db.ui)=="table"and db.ui.welcomed==true then
		return false,"welcomed"
	end
	if canaryAnnouncing()then
		return false,"lost"
	end
	local matches=type(db.matches)=="table"and#db.matches or 0
	local left=type(db.incomplete)=="table"and#db.incomplete or 0
	if matches+left>0 then
		return false,"has-matches"
	end
	if A.inPvpInstance()then
		return false,"in-instance"
	end
	if A.inCombatLockdown()then
		return false,"in-combat"
	end
	return true,"none"
end

local function markWelcomed()
	local db=A.savedDB()
	if not db then
		return false
	end
	db.ui=type(db.ui)=="table"and db.ui or{}
	db.ui.welcomed=true
	return true
end

local function answered(action)
	if not welcome or welcome.answered then
		return
	end
	welcome.answered=true
	markWelcomed()
	A.trace("welcome",{cardShown=true,reason="none",action=action},"ui")
	pcall(welcome.Hide,welcome)
end

function A.welcomeSample()
	A.startSandbox()
	local report,refusal=A.generateFixture()
	if not report then
		A.say("sample: "..A.fixtureRefusalText(refusal))
		return false
	end
	A.say(("sample: %d made-up matches to look around. Your history is untouched, and /reload or your "
		.."next match ends the sample"):format(report.written or 0))
	local ok,shown=pcall(A.showWindowState,{format=false,body="history"})
	return ok and shown~=nil and shown~=false
end

local function buildWelcome()
	local frame=CreateFrame("Frame",WELCOME_NAME,UIParent,"BasicFrameTemplateWithInset")
	frame:SetFrameStrata("DIALOG")
	frame:SetPoint("CENTER")
	frame:SetClampedToScreen(true)
	frame:EnableMouse(true)
	frame:Hide()

	frame.title=A.windowTitle(frame)
	frame.title:SetText("PvPHistory is recording")

	local inner=WELCOME_WIDTH-WELCOME_PAD*2
	local body=frame:CreateFontString(nil,"ARTWORK","GameFontHighlight")
	body:SetPoint("TOPLEFT",frame,"TOPLEFT",WELCOME_PAD,-34)
	body:SetWidth(inner)
	body:SetJustifyH("LEFT")
	body:SetWordWrap(true)
	A.style(body,"bodyText","text")
	body:SetText("Every match you play from now on is saved, with nothing to set up. Open the history "
		.."with /pvph, the minimap button or a key under PvPHistory in Key Bindings, and right-click a "
		.."player and choose Rate and note to remember them.")
	frame.body=body

	frame.sample=A.pill(frame,"Show me a sample",function()
		answered("sample")
		A.welcomeSample()
	end)
	frame.close=A.pill(frame,"Close",function()
		answered("close")
	end)
	frame.close:SetPoint("TOPRIGHT",body,"BOTTOMRIGHT",0,-12)
	frame.sample:SetPoint("RIGHT",frame.close,"LEFT",-A.metric("pillGap"),0)

	local foot=frame:CreateFontString(nil,"ARTWORK","GameFontDisableSmall")
	foot:SetPoint("TOPLEFT",body,"BOTTOMLEFT",0,-12-A.metric("controlHeight")-8)
	foot:SetWidth(inner)
	foot:SetJustifyH("LEFT")
	foot:SetWordWrap(true)
	A.style(foot,"cardLabel","dim")
	foot:SetText("The sample lasts until a /reload or your next match.")
	frame.foot=foot

	local bodyH=body:GetStringHeight()or 0
	local footH=foot:GetStringHeight()or 0
	frame:SetSize(WELCOME_WIDTH,34+bodyH+12+A.metric("controlHeight")+8+footH+WELCOME_PAD)

	frame:SetScript("OnHide",function()
		answered("escape")
	end)
	if type(UISpecialFrames)=="table"then
		UISpecialFrames[#UISpecialFrames+1]=WELCOME_NAME
	end
	A.registerChrome(frame)
	return frame
end

function A.tryWelcome(source)
	local draws,reason=A.welcomeGate()
	if not draws then
		local waits=reason=="in-instance"or reason=="in-combat"
		if waits and welcomeWaiting==reason then
			return false
		end
		welcomeWaiting=waits and reason or nil
		A.trace("welcome",{cardShown=false,reason=reason,source=source},"ui")
		return false
	end
	welcomeWaiting=nil
	if welcome and welcome:IsShown()then
		return true
	end
	if not welcome then
		local ok,built=pcall(buildWelcome)
		if not ok then
			A.noteError(built,"login.welcome")
			return false
		end
		welcome=built
	end
	welcome.answered=false
	welcome:Show()
	A.trace("welcome",{cardShown=true,reason="none",source=source},"ui")
	return true
end

A.on("PLAYER_LOGIN",function()
	local ok,err=pcall(A.tryWelcome,"login")
	if not ok then
		A.noteError(err,"login.welcome")
	end
end)

local function liftWelcome(event)
	if welcomeWaiting==nil or(welcomeWaiting=="in-instance"and event=="PLAYER_REGEN_ENABLED")then
		return
	end
	local ok,err=pcall(A.tryWelcome,event)
	if not ok then
		A.noteError(err,"login.welcome")
	end
end
A.on("PLAYER_ENTERING_WORLD",liftWelcome)
A.on("PLAYER_REGEN_ENABLED",liftWelcome)
