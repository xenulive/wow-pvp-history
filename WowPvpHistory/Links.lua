-- WowPvpHistory 0.68.47
-- Author:  Xenu-Sentinels
-- Project: wow-pvp-history
--          https://github.com/xenulive/wow-pvp-history
-- License: MIT, see LICENSE
local ADDON,A=...
local LINK_TYPE="addon"
local PREFIX=LINK_TYPE..":"..ADDON..":"
local PLAYER_KIND="player"
local MATCH_KIND="match"
local registered=false
local function carriable(text)
return type(text)=="string"and text~=""and not text:find("[|\r\n]")
end
local function link(kind,payload,text)
if not carriable(text)then
return text
end
if not(registered and carriable(payload))then
return text
end
return("|H%s%s:%s|h|cff%s[%s]|r|h"):format(PREFIX,kind,payload,A.linkColor(),text)
end
function A.playerLink(guid,text)
return link(PLAYER_KIND,guid,text)
end
function A.matchLink(id,text)
if type(id)~="number"then
return text
end
return link(MATCH_KIND,A.matchIdText(id),text)
end
function A.linksAvailable()
return registered
end
local function route(raw)
if not(type(raw)=="string"and A.canRead(raw))then
return false
end
if raw:sub(1,#PREFIX)~=PREFIX then
return false
end
local kind,payload=raw:sub(#PREFIX+1):match("^(%a+):(.+)$")
if not kind then
return false
end
if kind==PLAYER_KIND then
A.trace("open",{source="link",reason=PLAYER_KIND},"ui")
if type(A.openPlayer)=="function"then
A.openPlayer(payload,false,"link")
end
return true
end
if kind==MATCH_KIND then
local id=tonumber(payload)
A.trace("open",{source="link",reason=MATCH_KIND,id=id},"ui")
if id and type(A.raiseMatchWindow)=="function"then
A.raiseMatchWindow("match",id,"link")
end
return true
end
return false
end
local function register()
local registry=EventRegistry
if type(registry)~="table"or type(registry.RegisterCallback)~="function"then
return false
end
local ok=pcall(registry.RegisterCallback,registry,"SetItemRef",function(_,raw)
pcall(route,raw)
end)
return ok
end
registered=register()==true
