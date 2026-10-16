-- WowPvpHistory 0.68.35
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
db.ui=db.ui or{}
return db.ui.loginLine~=false
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
A.trace("character",{source="login",state="refused",reason="secret"})
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
end
A.on("PLAYER_LOGIN",function()
local remembered,err=pcall(A.rememberCharacter)
if not remembered then
A.noteError(err,"login.character")
end
pcall(A.pruneSessionFolds)
announce()
end)
