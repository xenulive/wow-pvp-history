-- WowPvpHistory 0.75.26
-- Author:  Xenu-Sentinels
-- Project: wow-pvp-history
--          https://github.com/xenulive/wow-pvp-history
-- License: MIT, see LICENSE
local _,A=...

local CATEGORY_NAME=A.displayName()

local VARIABLES={}

local function declare(name)
	VARIABLES[#VARIABLES+1]=name
	return name
end

local ALERTS_VARIABLE=declare("WOWPVPHISTORY_ALERTS")
local POST_GAME_VARIABLE=declare("WOWPVPHISTORY_POST_GAME")
local OPEN_AFTER_MATCH_VARIABLE=declare("WOWPVPHISTORY_OPEN_AFTER_MATCH")
local TOAST_VARIABLE=declare("WOWPVPHISTORY_TOAST")
local TOAST_SECONDS_VARIABLE=declare("WOWPVPHISTORY_TOAST_SECONDS")
local LOSS_NUDGE_VARIABLE=declare("WOWPVPHISTORY_LOSS_NUDGE")
local CONTEXT_MENU_VARIABLE=declare("WOWPVPHISTORY_CONTEXT_MENU")
local GROUP_NOTES_VARIABLE=declare("WOWPVPHISTORY_GROUP_NOTES")
local ANNOUNCE_VARIABLE=declare("WOWPVPHISTORY_ANNOUNCE")
local ANNOUNCE_TIME_VARIABLE=declare("WOWPVPHISTORY_ANNOUNCE_TIME")
local ANNOUNCE_SIZE_VARIABLE=declare("WOWPVPHISTORY_ANNOUNCE_SIZE")
local ANNOUNCE_OPACITY_VARIABLE=declare("WOWPVPHISTORY_ANNOUNCE_OPACITY")
local ANNOUNCE_COMP_VARIABLE=declare("WOWPVPHISTORY_ANNOUNCE_COMP")
local ANNOUNCE_REMATCH_VARIABLE=declare("WOWPVPHISTORY_ANNOUNCE_REMATCH")
local WINDOW_SCALE_VARIABLE=declare("WOWPVPHISTORY_WINDOW_SCALE")
local OVERLAY_VARIABLE=declare("WOWPVPHISTORY_OVERLAY")
local TOOLTIP_VARIABLE=declare("WOWPVPHISTORY_TOOLTIP")
local MINIMAP_VARIABLE=declare("WOWPVPHISTORY_MINIMAP_BUTTON")
local DUELS_VARIABLE=declare("WOWPVPHISTORY_DUELS")
local REMEMBER_TAB_VARIABLE=declare("WOWPVPHISTORY_REMEMBER_TAB")
local REMEMBER_FILTERS_VARIABLE=declare("WOWPVPHISTORY_REMEMBER_FILTERS")
local CLOSE_WITH_MAIN_VARIABLE=declare("WOWPVPHISTORY_CLOSE_WITH_MAIN")
local THEME_VARIABLE=declare("WOWPVPHISTORY_THEME")
local RESULT_PAIR_VARIABLE=declare("WOWPVPHISTORY_RESULT_PAIR")
local DRAWING={
	realms={variable=declare("WOWPVPHISTORY_REALMS"),default=true},
	clock={variable=declare("WOWPVPHISTORY_CLOCK"),default="game"},
}
local LOOK_VARIABLES={
	largeText=declare("WOWPVPHISTORY_LARGE_TEXT"),
	denseRows=declare("WOWPVPHISTORY_DENSE_ROWS"),
}
local LOGIN_LINE_VARIABLE=declare("WOWPVPHISTORY_LOGIN_LINE")
local HOLD_VARIABLE=declare("WOWPVPHISTORY_HOLD")
local FINDER_VARIABLE=declare("WOWPVPHISTORY_FINDER")
local FINDER_DOCK_VARIABLE=declare("WOWPVPHISTORY_FINDER_DOCK")
local SIGHT_VARIABLE=declare("WOWPVPHISTORY_SIGHT")
local CHAT_MARK_VARIABLE=declare("WOWPVPHISTORY_CHAT_MARK")
local TALLY_VARIABLE=declare("WOWPVPHISTORY_TALLY")
local WORLD_VARIABLE=declare("WOWPVPHISTORY_WORLD")
local RECORD_CHARACTER_VARIABLE=declare("WOWPVPHISTORY_RECORD_CHARACTER")
local MMR_LINE_VARIABLE=declare("WOWPVPHISTORY_MMR_LINE")
local SOUND_VARIABLES={
	badArrival=declare("WOWPVPHISTORY_SOUND_BAD"),
	newBest=declare("WOWPVPHISTORY_SOUND_BEST"),
	saved=declare("WOWPVPHISTORY_SOUND_SAVED"),
}
local SOUND_DEFAULT=false

local ALERTS_DEFAULT=true
local POST_GAME_DEFAULT=true
local OPEN_AFTER_MATCH_DEFAULT=true
local TOAST_DEFAULT=true
local LOSS_NUDGE_DEFAULT="off"
local CONTEXT_MENU_DEFAULT=true
local GROUP_NOTES_DEFAULT=true
local ANNOUNCE_DEFAULT=true
local ANNOUNCE_COMP_DEFAULT=true
local ANNOUNCE_REMATCH_DEFAULT=true
local OVERLAY_DEFAULT=false
local TOOLTIP_DEFAULT=true
local MINIMAP_DEFAULT=true
local DUELS_DEFAULT=true
local REMEMBER_TAB_DEFAULT=true
local REMEMBER_FILTERS_DEFAULT=true
local CLOSE_WITH_MAIN_DEFAULT=true
local LOGIN_LINE_DEFAULT=true
local HOLD_DEFAULT=true
local FINDER_DEFAULT=true
local FINDER_DOCK_DEFAULT=true
local SIGHT_DEFAULT=true
local CHAT_MARK_DEFAULT=true
local TALLY_DEFAULT=true
local WORLD_DEFAULT=true
local RECORD_CHARACTER_DEFAULT=true
local MMR_LINE_DEFAULT=true

local THEME_DEFAULT="blizzard"
local RESULT_PAIR_DEFAULT="green"
local category
local attempted=false
local registered=false

local function surface()
	if type(Settings)~="table"then
		return nil
	end

	local s=Settings
	if type(s.RegisterVerticalLayoutCategory)~="function"
		or type(s.RegisterProxySetting)~="function"
		or type(s.CreateCheckbox)~="function"
		or type(s.RegisterAddOnCategory)~="function"
		or type(s.VarType)~="table"
		or type(s.VarType.Boolean)~="string"
		or type(s.VarType.String)~="string"then
		return nil
	end

	if type(s.CreateControlTextContainer)~="function"
		or(type(s.CreateDropdown)~="function"and type(s.CreateDropDown)~="function")then
		return nil
	end

	return s
end

local function traceSetting(name,getter)
	local ok,value=pcall(getter)
	A.trace("setting",{
		source=name,
		state=ok and tostring(value)or"unreadable",
	},"data")
end

local function notify(variable)
	if A.refreshOptionsWindow then
		pcall(A.refreshOptionsWindow)
	end

	local fn=type(Settings)=="table"and Settings.NotifyUpdate
	if type(fn)~="function"then
		return false
	end
	return(pcall(fn,variable))
end

local function notifyWindowOnly(name,getter)
	traceSetting(name,getter)
	if A.refreshOptionsWindow then
		pcall(A.refreshOptionsWindow)
	end
	return false
end

function A.notifyAlertsSetting()
	traceSetting("alerts",A.alertsEnabled)
	return notify(ALERTS_VARIABLE)
end

function A.notifyPostGameSetting()
	traceSetting("post-game",A.postGameEnabled)
	return notify(POST_GAME_VARIABLE)
end

function A.notifyOpenAfterMatchSetting()
	traceSetting("after-match",A.openAfterMatchEnabled)
	return notify(OPEN_AFTER_MATCH_VARIABLE)
end

function A.notifyToastSetting()
	traceSetting("toast",A.toastEnabled)
	return notify(TOAST_VARIABLE)
end

function A.notifyToastSecondsSetting()
	traceSetting("toast-seconds",A.toastSeconds)
	return notify(TOAST_SECONDS_VARIABLE)
end

function A.notifyToastLockSetting()
	return notifyWindowOnly("toast-lock",A.toastLocked)
end

function A.notifyLossNudgeSetting()
	traceSetting("loss-nudge",A.lossNudgeChoice)
	return notify(LOSS_NUDGE_VARIABLE)
end

function A.notifySoundSetting(kind)
	traceSetting("sound-"..tostring(kind),function()return A.soundEnabled(kind)end)
	return notify(SOUND_VARIABLES[kind])
end

function A.notifyTooltipSetting()
	traceSetting("tooltip",A.tooltipEnabled)
	return notify(TOOLTIP_VARIABLE)
end

function A.notifySightSetting()
	traceSetting("sight",A.sightEnabled)
	return notify(SIGHT_VARIABLE)
end

function A.notifyChatMarkSetting()
	traceSetting("chat-mark",A.chatMarkEnabled)
	return notify(CHAT_MARK_VARIABLE)
end

function A.notifyGroupNotesSetting()
	traceSetting("group-notes",A.groupNotesEnabled)
	return notify(GROUP_NOTES_VARIABLE)
end

function A.notifyAnnounceSetting()
	traceSetting("announce",A.announceEnabled)
	return notify(ANNOUNCE_VARIABLE)
end

function A.notifyAnnounceCompSetting()
	traceSetting("announce-comp",A.announceCompEnabled)
	return notify(ANNOUNCE_COMP_VARIABLE)
end

function A.notifyAnnounceRematchSetting()
	traceSetting("announce-rematch",A.announceRematchEnabled)
	return notify(ANNOUNCE_REMATCH_VARIABLE)
end

function A.notifyAnnounceTimeSetting()
	traceSetting("announce-time",A.announceTime)
	return notify(ANNOUNCE_TIME_VARIABLE)
end

function A.notifyWindowScaleSetting()
	traceSetting("window-scale",A.windowScale)
	return notify(WINDOW_SCALE_VARIABLE)
end

function A.notifyAnnounceSizeSetting()
	traceSetting("announce-size",A.announceSize)
	return notify(ANNOUNCE_SIZE_VARIABLE)
end

function A.notifyAnnounceOpacitySetting()
	traceSetting("announce-opacity",A.announceOpacity)
	return notify(ANNOUNCE_OPACITY_VARIABLE)
end

function A.notifyAnnounceShapeSetting()
	return notifyWindowOnly("announce-shape",A.announceShape)
end

function A.notifyAnnounceCrowdSetting()
	return notifyWindowOnly("announce-crowd",A.announceCrowd)
end

function A.notifyOverlayCountSetting()
	return notifyWindowOnly("overlay-count",A.overlayCount)
end

function A.notifyGoalSetting()
	return notifyWindowOnly("goal",function()
		local played,won=A.goalSet()
		return("%s/%s"):format(played or"-",won or"-")
	end)
end

function A.notifyOverlayOpacitySetting()
	return notifyWindowOnly("overlay-opacity",A.overlayOpacity)
end

function A.notifyOverlayCombatSetting()
	return notifyWindowOnly("overlay-combat",A.overlayCombat)
end

function A.notifyOverlaySetting()
	traceSetting("overlay",A.overlayEnabled)
	return notify(OVERLAY_VARIABLE)
end

function A.notifyTallySetting()
	traceSetting("tally",A.tallyEnabled)
	return notify(TALLY_VARIABLE)
end

function A.notifyTallyLockSetting()
	return notifyWindowOnly("tally-lock",A.tallyLocked)
end

function A.notifyAnnounceLockSetting()
	return notifyWindowOnly("announce-lock",A.announceLocked)
end

function A.notifyContextMenuSetting()
	traceSetting("context-menu",A.contextMenuEnabled)
	return notify(CONTEXT_MENU_VARIABLE)
end

function A.notifyLoginLineSetting()
	traceSetting("login-line",A.loginLineEnabled)
	return notify(LOGIN_LINE_VARIABLE)
end

function A.notifyMinimapSetting()
	traceSetting("minimap",A.minimapShown)
	return notify(MINIMAP_VARIABLE)
end

function A.notifyHoldSetting()
	traceSetting("hold",A.holdEnabled)
	return notify(HOLD_VARIABLE)
end

function A.notifyMmrLineSetting()
	traceSetting("mmr-line",A.mmrLineEnabled)
	return notify(MMR_LINE_VARIABLE)
end

function A.notifyDuelsSetting()
	traceSetting("duels",A.duelsEnabled)
	return notify(DUELS_VARIABLE)
end

function A.notifyWorldSetting()
	traceSetting("world",A.worldEnabled)
	return notify(WORLD_VARIABLE)
end

function A.notifyCharacterRecordedSetting()
	traceSetting("record-character",function()return A.characterRecorded()end)
	return notify(RECORD_CHARACTER_VARIABLE)
end

function A.notifyPauseSetting()
	return notifyWindowOnly("pause",function()return A.pausedUntil()end)
end

function A.notifyOverlayTwoSetting()
	return notifyWindowOnly("overlay-two",A.overlayTwo)
end

function A.notifyTabSetting()
	traceSetting("remember-tab",A.rememberTab)
	return notify(REMEMBER_TAB_VARIABLE)
end

function A.notifyFiltersSetting()
	traceSetting("remember-filters",A.rememberFilters)
	return notify(REMEMBER_FILTERS_VARIABLE)
end

function A.notifyCloseWithMainSetting()
	traceSetting("close-with",A.closeWithMainEnabled)
	return notify(CLOSE_WITH_MAIN_VARIABLE)
end

function A.notifyFinderSetting()
	traceSetting("finder",A.finderEnabled)
	return notify(FINDER_VARIABLE)
end

function A.notifyFinderDockSetting()
	traceSetting("finder-dock",A.finderDocked)
	return notify(FINDER_DOCK_VARIABLE)
end

function A.notifyThemeSetting()
	traceSetting("theme",A.theme)
	return notify(THEME_VARIABLE)
end

function A.notifyResultPairSetting()
	traceSetting("result-pair",A.resultPair)
	return notify(RESULT_PAIR_VARIABLE)
end

function A.notifyRealmsSetting()
	traceSetting("realms",A.realmsShown)
	return notify(DRAWING.realms.variable)
end

function A.notifyClockSetting()
	traceSetting("clock",A.clockSetting)
	return notify(DRAWING.clock.variable)
end

function A.notifyLargeTextSetting()
	traceSetting("large-text",A.largeText)
	return notify(LOOK_VARIABLES.largeText)
end

function A.notifyDenseRowsSetting()
	traceSetting("dense-rows",A.denseRows)
	return notify(LOOK_VARIABLES.denseRows)
end

function A.notifyEverySetting()
	local fn=type(Settings)=="table"and Settings.NotifyUpdate or nil
	local named=0
	if type(fn)=="function"then
		for i=1,#VARIABLES do
			if pcall(fn,VARIABLES[i])then
				named=named+1
			end
		end
	end
	A.trace("setting",{source="every",state=tostring(named)},"data")
	return named
end

local function addResetButton(layout)
	if type(layout)~="table"or type(layout.AddInitializer)~="function"then
		return false
	end
	if type(CreateSettingsButtonInitializer)~="function"then
		return false
	end

	if type(CreateSettingsListSectionHeaderInitializer)=="function"then
		pcall(function()
			layout:AddInitializer(CreateSettingsListSectionHeaderInitializer("Stored history"))
		end)
	end

	local ok=pcall(function()
		layout:AddInitializer(CreateSettingsButtonInitializer(
			"Erase everything stored",
			"Erase the history",
			function()
				A.openResetConfirm()
			end,
			"Erase every stored match, the player index, the notes and the incomplete entries, "
			.."and return the interface to its defaults. The confirm window says whether a copy "
			.."is pinned first.",
			true))
	end)

	return ok
end

local function slider(s,made,variable,label,getter,setter,tooltip,range,unit)
	if type(s.CreateSlider)~="function"or type(s.CreateSliderOptions)~="function"
		or type(s.VarType.Number)~="string"or type(MinimalSliderWithSteppersMixin)~="table"
		or type(MinimalSliderWithSteppersMixin.Label)~="table"
	then
		return
	end
	local min,max,step,default=range()
	pcall(function()
		local setting=s.RegisterProxySetting(made,variable,s.VarType.Number,
			label,default,getter,setter)
		local options=s.CreateSliderOptions(min,max,step)
		options:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right,function(value)
			return(unit or"%d%%"):format(math.floor((tonumber(value)or default)+0.5))
		end)
		s.CreateSlider(made,setting,options,tooltip)
	end)
end

local function addAnnounceSliders(s,made)
	slider(s,made,ANNOUNCE_TIME_VARIABLE,"Announcement time",
		A.announceTime,A.setAnnounceTime,
		"How long the announcement stays on screen, in seconds.",
		A.announceTimeRange,"%d sec")

	slider(s,made,ANNOUNCE_SIZE_VARIABLE,"Announcement size",
		A.announceSize,A.setAnnounceSize,
		"How large the announcement is drawn. Where its names would run past the edge of the "
		.."screen, it draws smaller to fit.",
		A.announceSizeRange)

	slider(s,made,ANNOUNCE_OPACITY_VARIABLE,"Announcement opacity",
		A.announceOpacity,A.setAnnounceOpacity,
		"How dark the panel behind the announcement's names is. At 0% the names are drawn alone "
		.."over the game world.",
		A.announceOpacityRange)

	slider(s,made,WINDOW_SCALE_VARIABLE,"Window scale",
		A.windowScale,A.setWindowScale,
		"Draws every PvPHistory window larger or smaller, text included. The announcement has its "
		.."own size slider.",
		A.windowScaleRange)
end

function A.addAfterMatchSettings(s,made,booleanType)
	local toastSetting=s.RegisterProxySetting(made,TOAST_VARIABLE,booleanType,
		"Result card after a match",TOAST_DEFAULT,A.toastEnabled,A.setToast)
	s.CreateCheckbox(made,toastSetting,
		"When you leave a match, raise a card with the result, the rating, any new best and the run "
		.."of wins or losses for a few seconds. Click it to open the match.")
	slider(s,made,TOAST_SECONDS_VARIABLE,"Result card time",
		A.toastSeconds,A.setToastSeconds,
		"How long the result card stays on screen, in seconds.",
		A.toastSecondsRange,"%d sec")

	local lossNudge=s.RegisterProxySetting(made,LOSS_NUDGE_VARIABLE,s.VarType.String,
		"Say so after losses in a row",LOSS_NUDGE_DEFAULT,A.lossNudgeChoice,A.setLossNudgeChoice)
	local dropdown=s.CreateDropdown or s.CreateDropDown
	dropdown(made,lossNudge,function()
		local container=s.CreateControlTextContainer()
		container:Add("off","Off")
		local min,max=A.lossNudgeRange()
		for n=min,max do
			container:Add(tostring(n),tostring(n))
		end
		return container:GetData()
	end,"After this many losses in a row in one format, print one more line saying so, once per run.")
end

function A.registerMmrLineSetting(s,made,booleanType)
	local mmrLine=s.RegisterProxySetting(made,MMR_LINE_VARIABLE,booleanType,
		"MMR line on the graph",MMR_LINE_DEFAULT,A.mmrLineEnabled,A.setMmrLine)
	s.CreateCheckbox(made,mmrLine,
		"Draw the gray matchmaking rating line under your rating on the Stats graph, wherever "
		.."enough matches in a row recorded one.")
end

function A.registerLookSettings(s,made,booleanType)
	local largeText=s.RegisterProxySetting(made,LOOK_VARIABLES.largeText,booleanType,
		"Large text",false,A.largeText,function(value)
			A.setLargeText(value,"panel")
		end)
	s.CreateCheckbox(made,largeText,
		"Draw the words and figures in the lists one size larger, with the windows kept the same size.")

	local denseRows=s.RegisterProxySetting(made,LOOK_VARIABLES.denseRows,booleanType,
		"Dense rows",false,A.denseRows,function(value)
			A.setDenseRows(value,"panel")
		end)
	s.CreateCheckbox(made,denseRows,
		"Draw the match list's rows two thirds as tall, so more matches show at once.")
end

function A.registerRecordingSettings(s,made,booleanType)
	local world=s.RegisterProxySetting(made,WORLD_VARIABLE,booleanType,
		"Record World PvP",WORLD_DEFAULT,A.worldEnabled,A.setWorld)
	s.CreateCheckbox(made,world,
		"With War Mode on, keep the kills and deaths of a stretch of open-world PvP as an outing. "
		.."Turning it off ends an outing already open.")

	local recordCharacter=s.RegisterProxySetting(made,RECORD_CHARACTER_VARIABLE,booleanType,
		"Record on this character",RECORD_CHARACTER_DEFAULT,
		function()return A.characterRecorded()end,
		function(on)return A.setCharacterRecorded(on)end)
	s.CreateCheckbox(made,recordCharacter,
		"Record matches, duels and World PvP on the character you are logged in on. Off stops "
		.."recording on this character alone, and what is stored stays shown.")
end

local function register()
	local s=surface()
	if not s then
		return false
	end

	local made,layout=s.RegisterVerticalLayoutCategory(CATEGORY_NAME)
	if type(made)~="table"then
		return false
	end

	local booleanType=s.VarType.Boolean
	local stringType=s.VarType.String
	local alerts=s.RegisterProxySetting(made,ALERTS_VARIABLE,booleanType,
		"Group and match alerts",ALERTS_DEFAULT,A.alertsEnabled,A.setAlerts)
	s.CreateCheckbox(made,alerts,
		"Print how many of a group's members, and of a finished match's participants, are "
		.."already in the stored history.")

	local postGame=s.RegisterProxySetting(made,POST_GAME_VARIABLE,booleanType,
		"Chat after a match",POST_GAME_DEFAULT,A.postGameEnabled,A.setPostGame)
	s.CreateCheckbox(made,postGame,
		"After a match or a duel, print what was recorded, the rating change, any new personal "
		.."best and a link that opens it. A line reporting a fault prints either way.")

	local openAfterMatch=s.RegisterProxySetting(made,OPEN_AFTER_MATCH_VARIABLE,booleanType,
		"Open the match after it ends",OPEN_AFTER_MATCH_DEFAULT,
		A.openAfterMatchEnabled,A.setOpenAfterMatch)
	s.CreateCheckbox(made,openAfterMatch,
		"When you leave a match, open its window. It waits until you are out of combat.")

	A.addAfterMatchSettings(s,made,booleanType)

	for _,kind in ipairs(A.soundKinds())do
		local sound=s.RegisterProxySetting(made,SOUND_VARIABLES[kind],booleanType,A.soundLabel(kind),
			SOUND_DEFAULT,function()return A.soundEnabled(kind)end,
			function(on)return A.setSound(kind,on)end)
		s.CreateCheckbox(made,sound,("Play %s sound on the game's sound effects channel.")
			:format(A.soundCueText(kind)))
	end

	local groupNotes=s.RegisterProxySetting(made,GROUP_NOTES_VARIABLE,booleanType,
		"Show what was written on who joined",GROUP_NOTES_DEFAULT,
		A.groupNotesEnabled,A.setGroupNotes)
	s.CreateCheckbox(made,groupNotes,
		"With the group alert on, print the rating, the tags and the note for each group member "
		.."who carries one.")

	local sight=s.RegisterProxySetting(made,SIGHT_VARIABLE,booleanType,
		"Mark people you have written about when they appear",SIGHT_DEFAULT,
		A.sightEnabled,A.setSight)
	s.CreateCheckbox(made,sight,
		"Outside a battleground or an arena, put a mark on the nameplate of a player you rated, "
		.."tagged or wrote about, and name them once in chat when they appear.")

	local chatMark=s.RegisterProxySetting(made,CHAT_MARK_VARIABLE,booleanType,
		"Mark people you have written about in chat",CHAT_MARK_DEFAULT,
		A.chatMarkEnabled,A.setChatMark)
	s.CreateCheckbox(made,chatMark,
		"Outside a match, a dungeon or a raid, put a bar before the name of a player you rated, "
		.."tagged or wrote about when they talk in chat, colored by their skill or attitude step.")

	local announce=s.RegisterProxySetting(made,ANNOUNCE_VARIABLE,booleanType,
		"Announce who you know at the gates",ANNOUNCE_DEFAULT,
		A.announceEnabled,A.setAnnounce)
	s.CreateCheckbox(made,announce,
		"When a match's roster resolves or somebody the history holds joins your group, name who "
		.."you have met or written about across the top of the screen.")

	local announceComp=s.RegisterProxySetting(made,ANNOUNCE_COMP_VARIABLE,booleanType,
		"Warn on a comp you lose to",ANNOUNCE_COMP_DEFAULT,
		A.announceCompEnabled,A.setAnnounceComp)
	s.CreateCheckbox(made,announceComp,
		"At the gates, name the other team's classes and your record against them when you have lost "
		.."at least as many games against those classes as you won, over five or more this season.")
	local announceRematch=s.RegisterProxySetting(made,ANNOUNCE_REMATCH_VARIABLE,booleanType,
		"Say when the other team played you earlier this sitting",ANNOUNCE_REMATCH_DEFAULT,
		A.announceRematchEnabled,A.setAnnounceRematch)
	s.CreateCheckbox(made,announceRematch,
		"At the gates, say how long ago and how it went when two or more of the other team played "
		.."you earlier in this sitting.")

	local tally=s.RegisterProxySetting(made,TALLY_VARIABLE,booleanType,
		"Round tally in Solo Shuffle",TALLY_DEFAULT,A.tallyEnabled,A.setTally)
	s.CreateCheckbox(made,tally,
		"During a Solo Shuffle, draw a strip at the top of the screen with the round, each round won "
		.."or lost, your record and the classes with you this round.")

	if type(CreateSettingsButtonInitializer)=="function"
		and type(layout)=="table"and type(layout.AddInitializer)=="function"then
		layout:AddInitializer(CreateSettingsButtonInitializer(
			"Announcement preview",
			"Preview",
			function()
				A.announcePreviewToggle()
			end,
			"Draw an invented announcement at its widest and hold it there. Drag it to choose "
			.."where the real one appears, and press this again or Escape to put it away; the "
			.."position it was dragged to is kept.",
			true))
		layout:AddInitializer(CreateSettingsButtonInitializer(
			"Announcement position",
			"Reset position",
			function()
				A.resetAnnouncePosition()
			end,
			"Put the announcement back a sixth of the screen down.",
			true))
	end

	addAnnounceSliders(s,made)

	local overlay=s.RegisterProxySetting(made,OVERLAY_VARIABLE,booleanType,
		"Show the newest results on screen",OVERLAY_DEFAULT,A.overlayEnabled,A.setOverlay)
	s.CreateCheckbox(made,overlay,
		"Draw a small bar of the newest results of the format last played, one cell per match. "
		.."Drag it where it should sit, and click a cell to open its match.")

	local tooltip=s.RegisterProxySetting(made,TOOLTIP_VARIABLE,booleanType,
		"Unit tooltip lines",TOOLTIP_DEFAULT,A.tooltipEnabled,A.setTooltip)
	s.CreateCheckbox(made,tooltip,
		"Add the record against a player, the rating they were last seen at and whatever is "
		.."written on them to their unit tooltip.")

	local contextMenu=s.RegisterProxySetting(made,CONTEXT_MENU_VARIABLE,booleanType,
		"Right-click menu entry",CONTEXT_MENU_DEFAULT,A.contextMenuEnabled,A.setContextMenu)
	s.CreateCheckbox(made,contextMenu,
		"Add an entry to the player right-click menu that writes a note and a rating without "
		.."opening a window.")

	local duels=s.RegisterProxySetting(made,DUELS_VARIABLE,booleanType,
		"Record duels",DUELS_DEFAULT,A.duelsEnabled,A.setDuels)
	s.CreateCheckbox(made,duels,
		"Keep a completed duel as a record, with its opponent attached to the player index.")

	A.registerRecordingSettings(s,made,booleanType)

	local hold=s.RegisterProxySetting(made,HOLD_VARIABLE,booleanType,
		"Hold the exit while the scoreboard is read",HOLD_DEFAULT,A.holdEnabled,A.setHold)
	s.CreateCheckbox(made,hold,
		"Cover the leave button on the match results frame for a few seconds after a match ends, so a "
		.."match left at the first opportunity is still recorded with its full roster.")

	local rememberTab=s.RegisterProxySetting(made,REMEMBER_TAB_VARIABLE,booleanType,
		"Remember the selected tab",REMEMBER_TAB_DEFAULT,A.rememberTab,A.setRememberTab)
	s.CreateCheckbox(made,rememberTab,
		"Open the match history on the format tab that was last selected, rather than on all "
		.."formats.")

	local rememberFilters=s.RegisterProxySetting(made,REMEMBER_FILTERS_VARIABLE,booleanType,
		"Remember the search and filters",REMEMBER_FILTERS_DEFAULT,A.rememberFilters,A.setRememberFilters)
	s.CreateCheckbox(made,rememberFilters,
		"Keep what you typed in the match list's search box and the spec, result and zone you "
		.."picked when you log out or reload.")

	A.registerMmrLineSetting(s,made,booleanType)

	local closeWithMain=s.RegisterProxySetting(made,CLOSE_WITH_MAIN_VARIABLE,booleanType,
		"Close match and player windows with the main window",CLOSE_WITH_MAIN_DEFAULT,
		A.closeWithMainEnabled,A.setCloseWithMain)
	s.CreateCheckbox(made,closeWithMain,
		"When you close the main window, close every match window and player window too.")

	local finder=s.RegisterProxySetting(made,FINDER_VARIABLE,booleanType,
		"Season record beside the group finder",FINDER_DEFAULT,A.finderEnabled,A.setFinder)
	s.CreateCheckbox(made,finder,
		"Show this character's record for the current season beside the group finder while its "
		.."Player vs. Player tab is open.")

	local finderDock=s.RegisterProxySetting(made,FINDER_DOCK_VARIABLE,booleanType,
		"Dock the season record to the group finder",FINDER_DOCK_DEFAULT,A.finderDocked,
		A.setFinderDocked)
	s.CreateCheckbox(made,finderDock,
		"When off, drag the season record anywhere on the screen. It shows there each time the Player "
		.."vs. Player tab opens.")

	local loginLine=s.RegisterProxySetting(made,LOGIN_LINE_VARIABLE,booleanType,
		"Name the version at login",LOGIN_LINE_DEFAULT,A.loginLineEnabled,A.setLoginLine)
	s.CreateCheckbox(made,loginLine,
		"Print the loaded version and the way in every time the addon loads, and say so when the "
		.."stored history did not load or something threw.")

	local minimap=s.RegisterProxySetting(made,MINIMAP_VARIABLE,booleanType,
		"Minimap button",MINIMAP_DEFAULT,A.minimapShown,A.setMinimapShown)
	s.CreateCheckbox(made,minimap,"Show the button that opens the match history window.")

	local theme=s.RegisterProxySetting(made,THEME_VARIABLE,stringType,
		"Window appearance",THEME_DEFAULT,A.theme,A.setTheme)

	local dropdown=s.CreateDropdown or s.CreateDropDown
	dropdown(made,theme,function()
		local container=s.CreateControlTextContainer()
		for _,choice in ipairs(A.themeChoices())do
			container:Add(choice.value,choice.label,choice.tooltip)
		end
		return container:GetData()
	end,"Whether the history window keeps the client's frame or draws its own dark panel.")

	local resultPair=s.RegisterProxySetting(made,RESULT_PAIR_VARIABLE,stringType,
		"Win and loss colors",RESULT_PAIR_DEFAULT,A.resultPair,function(value)
			A.setResultPair(value,"panel")
		end)
	dropdown(made,resultPair,function()
		local container=s.CreateControlTextContainer()
		for _,choice in ipairs(A.resultPairChoices())do
			container:Add(choice.value,choice.label,choice.tooltip)
		end
		return container:GetData()
	end,"The two colors every win and loss draws in: green and red, blue and orange, or white and gray.")

	local realms=s.RegisterProxySetting(made,DRAWING.realms.variable,booleanType,
		"Realm names",DRAWING.realms.default,A.realmsShown,function(value)
			A.setRealms(value,"panel")
		end)
	s.CreateCheckbox(made,realms,
		"Draw each player's realm beside the name in lists and chat lines. Off, a realm shows when you "
		.."rest the pointer on the name, and in the player's own window.")

	local clock=s.RegisterProxySetting(made,DRAWING.clock.variable,stringType,
		"Clock",DRAWING.clock.default,A.clockSetting,function(value)
			A.setClock(value,"panel")
		end)
	dropdown(made,clock,function()
		local container=s.CreateControlTextContainer()
		for _,choice in ipairs(A.clockChoices())do
			container:Add(choice.value,choice.label,choice.tooltip)
		end
		return container:GetData()
	end,"How every time of day draws: as the game's own clock, 24-hour or 12-hour.")

	A.registerLookSettings(s,made,booleanType)

	if type(CreateSettingsButtonInitializer)=="function"
		and type(layout)=="table"and type(layout.AddInitializer)=="function"then
		layout:AddInitializer(CreateSettingsButtonInitializer(
			"Minimap button position",
			"Reset position",
			function()
				A.resetMinimap()
			end,
			"Put the minimap button back at its default angle and show it.",
			true))
	end

	addResetButton(layout)

	s.RegisterAddOnCategory(made)

	category=made
	return true
end

function A.registerOptions()
	if attempted then
		return registered
	end
	attempted=true

	local ok,built=pcall(register)
	registered=(ok and built)==true
	return registered
end

function A.optionsAvailable()
	return registered
end

function A.openOptions()
	if not registered or type(category)~="table"then
		return false
	end

	local open=type(Settings)=="table"and Settings.OpenToCategory
	if type(open)~="function"then
		return false
	end

	if A.inCombatLockdown()then
		A.trace("open",{source="options",reason="combat"},"ui")
		return false,"combat"
	end

	local ok,opened=pcall(function()
		if type(category.GetID)~="function"then
			return false
		end
		local id=category:GetID()
		if id==nil then
			return false
		end
		open(id)
		return true
	end)

	return(ok and opened)==true
end

A.on("PLAYER_LOGIN",function()
	if not A.registerOptions()then
		A.trace("options",{state="refused",reason="login"},"ui")
	end
end)
