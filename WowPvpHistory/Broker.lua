-- WowPvpHistory 0.75.26
-- Author:  Xenu-Sentinels
-- Project: wow-pvp-history
--          https://github.com/xenulive/wow-pvp-history
-- License: MIT, see LICENSE
local _,A=...

local OBJECT_NAME="PvPHistory"

local LIBRARY="LibDataBroker-1.1"

local AFTER_COMPLETE=12

local object=nil

local midnightAt=nil

local function refreshContained()
	local ok,err=pcall(A.brokerRefresh)
	if not ok then
		A.noteError(err,"broker")
	end
end

function A.brokerText()
	local _,meta=A.minimapLines()
	if type(meta)~="table"or meta.state=="empty"then
		return A.displayName()
	end
	if meta.ratingFigure~=nil then
		local text=tostring(meta.ratingFigure)
		if meta.today~=nil then
			text=text.." "..tostring(meta.today)
		end
		return text
	end
	return meta.record or A.formatLabel(meta.format)
end

local function armMidnight()
	local after=C_Timer and C_Timer.After
	local delay=type(A.secondsToMidnight)=="function"and A.secondsToMidnight()or nil
	if type(after)~="function"or delay==nil then
		return
	end
	local at=time()+delay
	if midnightAt==at then
		return
	end
	midnightAt=at
	after(delay,function()
		if midnightAt~=at then
			return
		end
		midnightAt=nil
		refreshContained()
	end)
end

function A.brokerRefresh()
	if object==nil then
		return false
	end
	armMidnight()
	local text=A.brokerText()
	if text==object.text then
		return false
	end
	object.text=text
	return true
end

function A.brokerObject()
	return object
end

local function library()
	local stub=rawget(_G,"LibStub")
	if stub==nil then
		return nil,"no-libstub"
	end
	local getter=type(stub)=="table"and stub.GetLibrary or nil
	local found=A.guardedCall(getter,stub,LIBRARY,true)
	if type(found)~="table"or type(found.NewDataObject)~="function"then
		return nil,"no-library"
	end
	return found
end

local function drawTooltip(tooltip)
	if type(tooltip)=="table"and type(tooltip.AddLine)=="function"then
		A.drawTooltipLines(tooltip,(A.minimapLines()))
	end
end

function A.brokerRegister(via)
	if object~=nil then
		return true
	end
	local lib,why=library()
	if lib~=nil then
		local ok,made=pcall(lib.NewDataObject,lib,OBJECT_NAME,{
			type="data source",
			label=A.displayName(),
			icon=A.ICON_TEXTURE,
			text=A.displayName(),
			OnClick=function()
				local clicked,err=pcall(A.toggleWindow)
				if not clicked then
					A.noteError(err,"broker-click")
				end
			end,
			OnTooltipShow=function(tooltip)
				local drawn,err=pcall(drawTooltip,tooltip)
				if not drawn then
					A.noteError(err,"broker-tooltip")
				end
			end,
		})
		if not ok then
			why="threw"
			A.noteError(made,"broker")
		elseif type(made)=="table"then
			object=made
			A.brokerRefresh()
		else
			why="name-taken"
		end
	end
	A.trace("broker",{present=object~=nil,reason=object and"none"or why,via=via},"ui")
	return object~=nil
end

local loggedIn=false

A.on("PLAYER_LOGIN",function()
	loggedIn=true
	A.brokerRegister("login")
end)

A.on("ADDON_LOADED",function()
	if loggedIn and object==nil and rawget(_G,"LibStub")~=nil then
		A.brokerRegister("addon-loaded")
	end
end)

A.on("PLAYER_ENTERING_WORLD",refreshContained)

A.on("PVP_MATCH_COMPLETE",function()
	if object~=nil and C_Timer and C_Timer.After then
		C_Timer.After(AFTER_COMPLETE,refreshContained)
	end
end)
