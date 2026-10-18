-- WowPvpHistory 0.68.47
-- Author:  Xenu-Sentinels
-- Project: wow-pvp-history
--          https://github.com/xenulive/wow-pvp-history
-- License: MIT, see LICENSE
local _,A=...
local NAME_PREFIX="WowPvpHistoryPlayer"
local MET_ROWS=4
local AUTHORED_COMMENT_ROWS=4
local open,order,pool={},{},{}
function A.playerWindowColumns(surplus)
local widths,used=A.encounterWidths(nil)
for i,column in ipairs(A.encounterColumns())do
if column.key=="where"then
local wide=A.metric("encColWhereWide")
if wide>widths[i]then
used=used+(wide-widths[i])
widths[i]=wide
end
if type(surplus)=="number"and surplus>0 then
widths[i]=widths[i]+surplus
used=used+surplus
end
end
end
return widths,used
end
function A.playerWindowBody(stripFloor)
local _,used=A.playerWindowColumns()
local rep=A.repControlFloor()
local body=used>rep and used or rep
if type(stripFloor)=="number"and stripFloor>body then
body=stripFloor
end
return body
end
function A.playerWindowWidth(stripFloor)
return A.metric("margin")*2+A.metric("paneRightPad")+A.playerWindowBody(stripFloor)
end
function A.playerWindowBodyAt(width,stripFloor)
local floor=A.playerWindowBody(stripFloor)
local body=floor
if type(width)=="number"then
body=width-A.metric("margin")*2-A.metric("paneRightPad")
end
if body<floor then
body=floor
end
return body,floor
end
local function headIndent()
return A.fontSize("dossierName")+A.metric("chipGap")
end
function A.playerStripLeftEnd(rounds)
local lead=A.metric("standPad")+A.metric("standLead")
if type(rounds)~="number"or rounds<1 then
return lead
end
return lead+A.metric("paneGap")*2+rounds*A.metric("roundBox")+(rounds-1)*A.metric("roundBoxGap")
end
function A.playerStripFloor(rounds,withText,againstText,fontString)
local wide=math.max(A.textRoom(fontString,withText),A.textRoom(fontString,againstText))
return A.playerStripLeftEnd(rounds)+A.metric("paneGap")+wide+A.metric("standPad")
end
function A.playerStampWidth()
return A.textRoom(nil,"0000-00-00 00:00")
end
function A.playerCommentRow()
return A.metric("rowHeight")+A.metric("commentPad")*2
end
function A.playerMatchStripHeight()
return A.metric("standPad")*2+A.fontSize("label")+A.fontSize("bodyText")+A.fontSize("note")+4
end
function A.playerWindowStack(metRows,tagRows)
local rows=type(metRows)=="number"and metRows or MET_ROWS
local tags=type(tagRows)=="number"and tagRows or 1
local gap=A.metric("paneGap")
local header=A.fontSize("label")+A.metric("headingPad")
return A.playerMatchStripHeight()
+gap+A.fontSize("dossierName")+2+A.fontSize("note")
+gap+A.metric("controlHeight")
+gap+A.sideCardHeight()
+gap+A.metric("controlHeight")
+gap+tags*A.metric("tagRow")
+gap+header+rows*A.metric("encRow")+A.metric("rowHeight")
+gap+header
end
local function belowComments()
return A.metric("paneGap")+A.metric("controlHeight")+A.bodyFloor()
end
function A.playerWindowHeight()
return A.metric("headerHeight")+A.playerWindowStack()
+AUTHORED_COMMENT_ROWS*A.playerCommentRow()+belowComments()
end
function A.playerWindowFloor()
return A.metric("headerHeight")+A.playerWindowStack()+A.playerCommentRow()+belowComments()
end
local function region()
if type(GetCurrentRegion)~="function"then
return nil
end
local ok,held=pcall(GetCurrentRegion)
return ok and held or nil
end
function A.playerCopyTexts(_,entry)
local identity=A.playerNames(entry)
if identity.name==nil or identity.unnamed then
return nil,nil
end
return identity.name,A.murlokAddress(identity.bare,identity.realm,region())
end
local paintWindow
local function paintTagSuggestions(frame)
if not(frame and frame.guid and frame.tagRow)then
return false
end
local tagRows=A.paintTagRow(frame.tagRow,A.noteFor(frame.guid),
frame.paintBody or A.playerWindowBody(frame.stripFloor))
if type(frame.drawn)=="table"then
frame.drawn.tagRows=tagRows
end
pcall(A.trace,"paint",{source="tags",shown=tagRows,format="player"},"ui")
return true
end
local function written()
if type(A.refreshNotes)=="function"then
pcall(A.refreshNotes)
end
end
local function commitNote(frame)
local box=frame.noteRow.box
local ok,text=pcall(box.GetText,box)
if not ok then
return
end
local stored,_,why,length,bound=
A.setPlayerNote(frame.guid,(text~=nil and text~="")and text or nil)
if not stored then
if why=="too-long"then
A.say(("that note is %d bytes and the bound is %d bytes. Nothing written")
:format(tonumber(length)or 0,tonumber(bound)or A.PLAYER_NOTE_MAX))
else
A.say("no database, so the note could not be stored")
end
return
end
pcall(box.ClearFocus,box)
end
local function repPicked(frame,wanted)
if not(frame and frame.guid)then
return
end
local held=A.noteFor(frame.guid)
if held~=nil and held.rating==wanted then
wanted=nil
end
if not A.setPlayerRating(frame.guid,wanted)then
A.say("no database, so the rating could not be stored")
end
end
local function tagRefusal(why,offender,bound)
if why=="tag-too-long"then
A.say(("%q is longer than %d bytes, so nothing was added")
:format(tostring(offender),tonumber(bound)or A.PLAYER_TAG_MAX))
elseif why=="too-many"then
A.say(("that is past %d tags, so %q and the rest were not added. Nothing written")
:format(tonumber(bound)or A.PLAYER_MAX_TAGS,tostring(offender)))
else
A.say("no database, so the tags could not be stored")
end
end
local function commitTags(frame)
local box=frame.tagRow.box
local ok,text=pcall(box.GetText,box)
if not ok then
return
end
local tags={}
for word in tostring(text or""):gmatch("%S+")do
tags[#tags+1]=word
end
if#tags==0 then
return
end
pcall(box.SetText,box,"")
local stored,added,why,offender,bound=A.addPlayerTags(frame.guid,tags)
if not stored then
pcall(box.SetText,box,text)
tagRefusal(why,offender,bound)
return
end
if type(added)=="table"and#added==0 then
A.say("every one of those tags was already there. Nothing written")
end
pcall(box.ClearFocus,box)
end
local function tagClicked(button)
local frame=button.playerWindow
if not(frame and button.tagValue)then
return
end
if not A.removePlayerTags(frame.guid,{button.tagValue})then
A.say("no database, so the tag could not be removed")
end
end
local function suggestClicked(button)
local frame=button.playerWindow
if not(frame and button.tagValue)then
return
end
local box=frame.tagRow.box
local read,typed=pcall(box.GetText,box)
pcall(box.SetText,box,"")
local stored,_,why,offender,bound=A.addPlayerTags(frame.guid,{button.tagValue})
if not stored then
pcall(box.SetText,box,read and typed or"")
tagRefusal(why,offender,bound)
end
end
local function commitComment(frame)
local ok,text=pcall(frame.commentBox.GetText,frame.commentBox)
if not ok then
return
end
local stored,_,why,length,bound=A.addPlayerComment(frame.guid,text)
if not stored then
if why=="empty"then
return
elseif why=="too-long"then
A.say(("that comment is %d bytes and the bound is %d bytes. Nothing written")
:format(tonumber(length)or 0,tonumber(bound)or A.PLAYER_COMMENT_MAX))
elseif why=="too-many"then
local held=tonumber(length)or A.PLAYER_MAX_COMMENTS
local cap=tonumber(bound)or A.PLAYER_MAX_COMMENTS
A.say(("this player already carries %d comments and the bound is %d. Remove %d to add another")
:format(held,cap,held-cap+1))
else
A.say("no database, so the comment could not be stored")
end
return
end
pcall(frame.commentBox.SetText,frame.commentBox,"")
end
local function commentRemoved(button)
local row=button.commentRow
local frame=row and row.playerWindow
if not(frame and row.commentIndex)then
return
end
local ok,_,why=A.removePlayerComment(frame.guid,row.commentIndex,row.commentText)
if not ok then
if why=="moved"or why=="absent"then
A.say("that comment changed since this window drew it, so nothing was removed")
else
A.say("no database, so the comment could not be removed")
end
written()
end
end
local COPY_NAME="WowPvpHistoryCopyBox"
local copyBox
function A.copyBoxSize()
local width=A.playerWindowWidth()-A.metric("margin")*4
local height=A.metric("headerHeight")+A.fontSize("note")+A.metric("paneGap")
+A.metric("controlHeight")+A.metric("paneGap")+A.metric("controlHeight")+A.metric("margin")
return width,height
end
local function buildCopyBox()
local frame=CreateFrame("Frame",COPY_NAME,UIParent,"BasicFrameTemplateWithInset")
frame:SetSize(A.copyBoxSize())
frame:SetFrameStrata("DIALOG")
frame:SetToplevel(true)
frame:SetClampedToScreen(true)
frame:EnableMouse(true)
frame:Hide()
A.registerChrome(frame)
A.registerScaledWindow(frame)
frame.title=A.windowTitle(frame)
frame.title:SetPoint("TOPLEFT",frame,"TOPLEFT",A.metric("titleInset"),-A.metric("titleTop"))
frame.title:SetPoint("TOPRIGHT",frame,"TOPRIGHT",-A.metric("titleInset"),-A.metric("titleTop"))
frame.title:SetJustifyH("CENTER")
frame.title:SetWordWrap(false)
frame.note=frame:CreateFontString(nil,"ARTWORK","GameFontDisableSmall")
frame.note:SetPoint("TOPLEFT",frame,"TOPLEFT",A.metric("margin"),-A.metric("headerHeight"))
frame.note:SetPoint("TOPRIGHT",frame,"TOPRIGHT",-A.metric("margin"),-A.metric("headerHeight"))
frame.note:SetJustifyH("LEFT")
frame.note:SetWordWrap(false)
frame.field=A.entry(frame)
frame.field:SetHeight(A.metric("controlHeight"))
frame.field:SetPoint("TOPLEFT",frame.note,"BOTTOMLEFT",0,-A.metric("paneGap"))
frame.field:SetPoint("TOPRIGHT",frame.note,"BOTTOMRIGHT",0,-A.metric("paneGap"))
frame.field:SetScript("OnTextChanged",function(self)
local ok,held=pcall(self.GetText,self)
if ok and held~=frame.copyText then
pcall(self.SetText,self,frame.copyText or"")
pcall(self.HighlightText,self)
end
end)
frame.field:SetScript("OnEnterPressed",function()frame:Hide()end)
frame.field:SetScript("OnEscapePressed",function()frame:Hide()end)
frame.close=A.pill(frame,"Close",function()frame:Hide()end,A.metric("actionMin"))
frame.close:SetPoint("BOTTOMRIGHT",frame,"BOTTOMRIGHT",-A.metric("margin"),A.metric("margin"))
if type(UISpecialFrames)=="table"then
UISpecialFrames[#UISpecialFrames+1]=COPY_NAME
end
return frame
end
function A.showCopyBox(over,title,note,text,source)
if type(text)~="string"or text==""then
return false
end
if not copyBox then
local ok,built=pcall(buildCopyBox)
if not(ok and built)then
if not ok then
A.noteError(("the copy box could not be built: %s"):format(tostring(built)),"player/copy")
end
return false
end
copyBox=built
end
local shown=pcall(function()
copyBox.copyText=text
A.style(copyBox.title,"heading","bright")
copyBox.title:SetText(title or"")
A.style(copyBox.note,"note","dim")
copyBox.note:SetText(note or"")
copyBox.field:SetText(text)
copyBox:ClearAllPoints()
if type(over)=="table"then
copyBox:SetPoint("CENTER",over,"CENTER",0,0)
else
copyBox:SetPoint("CENTER")
end
copyBox:Show()
copyBox:Raise()
copyBox.field:SetFocus()
copyBox.field:HighlightText()
end)
pcall(A.trace,"copy-box",{state=shown and"opened"or"refused",
source=source or(title=="murlok.io"and"murlok"or"name"),n=#text},"ui")
return shown
end
local function hang(part,parent,under,drop)
part:SetPoint("TOPLEFT",under,"BOTTOMLEFT",0,-drop)
part:SetPoint("RIGHT",parent,"RIGHT",0,0)
return part
end
local function buildMatchStrip(frame,body)
local strip=CreateFrame("Frame",nil,body)
strip:SetPoint("TOPLEFT",body,"TOPLEFT",0,0)
strip:SetPoint("TOPRIGHT",body,"TOPRIGHT",0,0)
strip:SetHeight(A.playerMatchStripHeight())
strip.ground=strip:CreateTexture(nil,"BACKGROUND")
strip.ground:SetAllPoints(strip)
strip.rule=strip:CreateTexture(nil,"ARTWORK")
strip.rule:SetPoint("BOTTOMLEFT",strip,"BOTTOMLEFT",0,0)
strip.rule:SetPoint("BOTTOMRIGHT",strip,"BOTTOMRIGHT",0,0)
strip.rule:SetHeight(1)
local pad=A.metric("standPad")
local function line(template,anchor,drop)
local text=strip:CreateFontString(nil,"ARTWORK",template)
if anchor then
text:SetPoint("TOPLEFT",anchor,"BOTTOMLEFT",0,-drop)
else
text:SetPoint("TOPLEFT",strip,"TOPLEFT",pad,-pad)
end
text:SetWidth(A.metric("standLead"))
text:SetJustifyH("LEFT")
text:SetWordWrap(false)
return text
end
strip.title=line("GameFontDisableSmall")
strip.map=line("GameFontHighlightSmall",strip.title,2)
strip.result=line("GameFontDisableSmall",strip.map,2)
strip.rounds={}
local x=pad+A.metric("standLead")+A.metric("paneGap")*2
for i=1,6 do
local round=CreateFrame("Frame",nil,strip)
round:SetSize(A.metric("roundBox"),A.metric("roundBoxHeight")+A.fontSize("rowClock")+3)
round:SetPoint("LEFT",strip,"LEFT",x,0)
round.label=round:CreateFontString(nil,"ARTWORK","GameFontDisableSmall")
round.label:SetPoint("TOP",round,"TOP",0,0)
round.mark=A.buildRoundMark(round)
round.mark:SetSize(A.metric("roundBox"),A.metric("roundBoxHeight"))
round.mark:ClearAllPoints()
round.mark:SetPoint("BOTTOM",round,"BOTTOM",0,0)
round.word=round.mark:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
round.word:SetPoint("CENTER",round.mark,"CENTER",0,0)
round.word:SetWordWrap(false)
strip.rounds[i]=round
x=x+A.metric("roundBox")+A.metric("roundBoxGap")
end
strip.with=strip:CreateFontString(nil,"ARTWORK","GameFontHighlightSmall")
strip.with:SetPoint("TOPRIGHT",strip,"TOPRIGHT",-pad,-pad-A.fontSize("label"))
strip.with:SetJustifyH("RIGHT")
strip.with:SetWordWrap(false)
strip.against=strip:CreateFontString(nil,"ARTWORK","GameFontHighlightSmall")
strip.against:SetPoint("TOPRIGHT",strip.with,"BOTTOMRIGHT",0,-2)
strip.against:SetJustifyH("RIGHT")
strip.against:SetWordWrap(false)
frame.matchStrip=strip
end
local function buildHead(frame,body)
frame.headIcon=body:CreateTexture(nil,"ARTWORK")
frame.headIcon:SetPoint("TOPLEFT",frame.matchStrip,"BOTTOMLEFT",0,-A.metric("paneGap"))
frame.headIcon:Hide()
frame.name=body:CreateFontString(nil,"ARTWORK","GameFontNormalLarge")
frame.name:SetPoint("TOPLEFT",frame.matchStrip,"BOTTOMLEFT",headIndent(),-A.metric("paneGap"))
frame.name:SetPoint("RIGHT",body,"RIGHT",0,0)
frame.name:SetJustifyH("LEFT")
frame.name:SetWordWrap(false)
frame.sub=body:CreateFontString(nil,"ARTWORK","GameFontDisableSmall")
frame.sub:SetPoint("TOPLEFT",frame.name,"BOTTOMLEFT",0,-2)
frame.sub:SetPoint("RIGHT",body,"RIGHT",0,0)
frame.sub:SetJustifyH("LEFT")
frame.sub:SetWordWrap(false)
frame.inPlayers=A.pill(body,"In Players",function()
if frame.guid~=nil and type(A.selectPlayer)=="function"then
A.selectPlayer(frame.guid)
end
end,A.metric("actionMin"))
frame.murlok=A.pill(body,"murlok.io",function()
if frame.murlokText then
A.showCopyBox(frame,"murlok.io","Ctrl+C copies the address; paste it into a browser.",
frame.murlokText)
end
end,A.metric("actionMin"))
frame.copyName=A.pill(body,"Copy name",function()
if frame.copyText then
A.showCopyBox(frame,"Copy name","Ctrl+C copies the name.",frame.copyText)
end
end,A.metric("actionMin"))
end
local function buildDetail(frame,body)
frame.rep=A.buildRepControl(body,function(rating)
repPicked(frame,rating)
end)
frame.rep:SetPoint("TOPLEFT",frame.sub,"BOTTOMLEFT",-headIndent(),-A.metric("paneGap"))
frame.rep:SetPoint("RIGHT",body,"RIGHT",0,0)
frame.cards=hang(A.buildSideCards(body),body,frame.rep,A.metric("paneGap"))
frame.noteRow=hang(A.buildNoteRow(body),body,frame.cards,A.metric("paneGap"))
local box=frame.noteRow.box
box:SetMaxLetters(A.PLAYER_NOTE_MAX)
A.entryPlaceholder(box,"a line you will see when you meet them again")
box:SetScript("OnEnterPressed",function()
commitNote(frame)
end)
box:HookScript("OnTextChanged",function(self)
local ok,held=pcall(self.GetText,self)
frame.noteRow.count:SetText(A.noteCountText(ok and held or nil,A.PLAYER_NOTE_MAX)or"")
end)
box:SetScript("OnEscapePressed",function(self)
pcall(self.ClearFocus,self)
A.discardTypedNote(self,frame)
pcall(paintWindow,frame)
end)
frame.tagRow=hang(A.buildTagRow(body,tagClicked,suggestClicked,function()
commitTags(frame)
end),body,frame.noteRow,A.metric("paneGap"))
for _,button in ipairs(frame.tagRow.tagButtons)do
button.playerWindow=frame
end
for _,button in ipairs(frame.tagRow.suggestButtons)do
button.playerWindow=frame
end
frame.tagRow.box:HookScript("OnTextChanged",function(_,userInput)
if userInput then
pcall(paintTagSuggestions,frame)
end
end)
frame.metHeader=hang(A.buildEncounterHeader(body),body,frame.tagRow,A.metric("paneGap"))
frame.metRows={}
local under=frame.metHeader
for i=1,MET_ROWS do
local row=CreateFrame("Button",nil,body)
row:SetPoint("TOPLEFT",under,"BOTTOMLEFT",0,0)
row:SetPoint("TOPRIGHT",under,"BOTTOMRIGHT",0,0)
row:SetHeight(A.metric("encRow"))
row:RegisterForClicks("LeftButtonUp")
A.buildEncounterLine(row)
row:SetScript("OnClick",function(self)
if self.matchId~=nil and type(A.showMatchFromPlayers)=="function"then
A.showMatchFromPlayers(self.matchId)
end
end)
frame.metRows[i]=row
under=row
end
frame.metTail=body:CreateFontString(nil,"ARTWORK","GameFontDisableSmall")
frame.metTail:SetHeight(A.metric("rowHeight"))
frame.metTail:SetJustifyH("LEFT")
frame.metTail:SetWordWrap(false)
end
local function buildComments(frame,body)
local headingHeight=A.fontSize("label")+A.metric("headingPad")
frame.commentHead=CreateFrame("Frame",nil,body)
frame.commentHead:SetPoint("TOPLEFT",frame.metTail,"BOTTOMLEFT",-A.metric("rowLabelPad"),
-A.metric("paneGap"))
frame.commentHead:SetPoint("RIGHT",body,"RIGHT",0,0)
frame.commentHead:SetHeight(headingHeight)
frame.commentHead.rule=frame.commentHead:CreateTexture(nil,"ARTWORK")
frame.commentHead.rule:SetPoint("BOTTOMLEFT",frame.commentHead,"BOTTOMLEFT",0,0)
frame.commentHead.rule:SetPoint("BOTTOMRIGHT",frame.commentHead,"BOTTOMRIGHT",0,0)
frame.commentHead.rule:SetHeight(1)
frame.commentTitle=frame.commentHead:CreateFontString(nil,"ARTWORK","GameFontDisableSmall")
frame.commentTitle:SetPoint("LEFT",frame.commentHead,"LEFT",0,0)
frame.commentTitle:SetJustifyH("LEFT")
frame.commentTitle:SetWordWrap(false)
frame.commentOrder=frame.commentHead:CreateFontString(nil,"ARTWORK","GameFontDisableSmall")
frame.commentOrder:SetPoint("RIGHT",frame.commentHead,"RIGHT",0,0)
frame.commentOrder:SetJustifyH("RIGHT")
frame.commentOrder:SetWordWrap(false)
frame.addComment=A.pill(body,"Add",function()
commitComment(frame)
end,A.metric("tagMin"))
frame.addComment:SetPoint("BOTTOMRIGHT",body,"BOTTOMRIGHT",0,0)
frame.commentBox=A.entry(body)
frame.commentBox:SetHeight(A.metric("controlHeight"))
frame.commentBox:SetPoint("BOTTOMLEFT",body,"BOTTOMLEFT",0,0)
frame.commentBox:SetPoint("RIGHT",frame.addComment,"LEFT",-A.metric("pillGap"),0)
frame.commentBox:SetMaxLetters(A.PLAYER_COMMENT_MAX)
A.entryPlaceholder(frame.commentBox,"add a comment, Enter saves it")
frame.commentBox:SetScript("OnEnterPressed",function()
commitComment(frame)
end)
frame.commentBox:SetScript("OnEscapePressed",function(self)
pcall(self.SetText,self,"")
pcall(self.ClearFocus,self)
end)
frame.commentScroll=CreateFrame("ScrollFrame",frame.windowName.."Comments",body,
"ScrollFrameTemplate")
frame.commentScroll:SetPoint("TOPLEFT",frame.commentHead,"BOTTOMLEFT",0,0)
frame.commentScroll:SetPoint("BOTTOMRIGHT",frame.commentBox,"TOPRIGHT",0,A.metric("paneGap"))
frame.commentScroll:SetPoint("RIGHT",body,"RIGHT",0,0)
if type(frame.commentScroll.ScrollBar)=="table"then
pcall(frame.commentScroll.ScrollBar.SetHideIfUnscrollable,frame.commentScroll.ScrollBar,true)
end
frame.commentList=CreateFrame("Frame",nil,frame.commentScroll)
frame.commentList:SetWidth(A.playerWindowBody())
frame.commentList:SetHeight(1)
frame.commentScroll:SetScrollChild(frame.commentList)
frame.commentRows={}
end
local function commentRow(frame,i)
local row=frame.commentRows[i]
if row then
return row
end
row=CreateFrame("Frame",nil,frame.commentList)
row.playerWindow=frame
row.stamp=row:CreateFontString(nil,"ARTWORK","GameFontDisableSmall")
row.stamp:SetPoint("TOPLEFT",row,"TOPLEFT",0,-A.metric("commentPad"))
row.stamp:SetWidth(A.playerStampWidth())
row.stamp:SetJustifyH("LEFT")
row.stamp:SetWordWrap(false)
row.remove=A.pill(row,"x",commentRemoved,A.metric("tagButton"))
row.remove:SetHeight(A.metric("tagButton"))
row.remove:SetPoint("TOPRIGHT",row,"TOPRIGHT",0,-A.metric("commentPad")+1)
row.remove.commentRow=row
row.text=row:CreateFontString(nil,"ARTWORK","GameFontHighlightSmall")
row.text:SetPoint("TOPLEFT",row.stamp,"TOPRIGHT",A.metric("rowCellGap"),0)
row.text:SetJustifyH("LEFT")
row.text:SetWordWrap(true)
row.rule=row:CreateTexture(nil,"ARTWORK")
row.rule:SetPoint("BOTTOMLEFT",row,"BOTTOMLEFT",0,0)
row.rule:SetPoint("BOTTOMRIGHT",row,"BOTTOMRIGHT",0,0)
row.rule:SetHeight(1)
frame.commentRows[i]=row
return row
end
local forget
local function bound(frame,floorWidth)
local screen=type(A.screenSizeFor)=="function"and A.screenSizeFor(frame)or nil
if type(screen)=="number"and screen<floorWidth then
screen=floorWidth
end
pcall(frame.SetResizeBounds,frame,floorWidth,A.playerWindowFloor(),screen,nil)
end
local function buildWindow(index)
local name=NAME_PREFIX..index
local frame=CreateFrame("Frame",name,UIParent,"BasicFrameTemplateWithInset")
frame.windowName=name
frame:SetSize(A.playerWindowWidth(frame.stripFloor),A.playerWindowHeight())
frame.widthFrom="build"
frame:SetFrameStrata("MEDIUM")
frame:SetToplevel(true)
frame:SetClampedToScreen(true)
frame:SetMovable(true)
frame:EnableMouse(true)
frame:RegisterForDrag("LeftButton")
frame:SetScript("OnDragStart",frame.StartMoving)
frame:SetScript("OnDragStop",function(self)
pcall(self.StopMovingOrSizing,self)
pcall(self.SetUserPlaced,self,false)
self.undocked=true
end)
frame:Hide()
A.registerChrome(frame)
frame.heading=A.windowTitle(frame)
frame.heading:SetPoint("TOPLEFT",frame,"TOPLEFT",A.metric("titleInset"),-A.metric("titleTop"))
frame.heading:SetPoint("TOPRIGHT",frame,"TOPRIGHT",-A.metric("titleInset"),-A.metric("titleTop"))
frame.heading:SetJustifyH("CENTER")
frame.heading:SetWordWrap(false)
A.style(frame.heading,"heading","bright")
frame.body=CreateFrame("Frame",nil,frame)
frame.body:SetPoint("TOPLEFT",frame,"TOPLEFT",A.metric("margin"),-A.metric("headerHeight"))
frame.body:SetPoint("BOTTOMRIGHT",frame,"BOTTOMRIGHT",
-A.metric("margin")-A.metric("paneRightPad"),A.bodyFloor())
frame.body:Show()
buildMatchStrip(frame,frame.body)
buildHead(frame,frame.body)
buildDetail(frame,frame.body)
buildComments(frame,frame.body)
frame.footName=frame:CreateFontString(nil,"ARTWORK","GameFontDisableSmall")
frame.footName:SetPoint("BOTTOMLEFT",frame,"BOTTOMLEFT",A.metric("margin"),A.metric("margin"))
frame.footName:SetJustifyH("LEFT")
frame.footName:SetWordWrap(false)
frame.footState=frame:CreateFontString(nil,"ARTWORK","GameFontDisableSmall")
frame.footState:SetPoint("BOTTOMRIGHT",frame,"BOTTOMRIGHT",-A.metric("margin"),
A.metric("margin"))
frame.footState:SetJustifyH("RIGHT")
frame.footState:SetWordWrap(false)
if type(A.attachPooledResize)=="function"then
pcall(A.attachPooledResize,frame,"player",{
release=function(self,before)
local after=A.frameGeometry(self)
if not(after and before)then
return A.storedGeometry("player")~=nil
end
local widthMoved=math.abs(after.width-before.width)>1
if widthMoved then
self.wantWidth,self.wantFrom=after.width,"drag"
end
if widthMoved or math.abs(after.height-before.height)>1 then
local width=A.playerWindowWidth()
if after.width>A.playerWindowWidth(self.stripFloor)+1 then
width=after.width
end
A.setStoredGeometry("player",{width=width,height=after.height})
end
return A.storedGeometry("player")~=nil
end,
repaint=function(self)
if self.guid then
pcall(paintWindow,self)
end
end,
})
end
bound(frame,A.playerWindowWidth(frame.stripFloor))
if type(UISpecialFrames)=="table"then
local seen=false
for i=1,#UISpecialFrames do
if UISpecialFrames[i]==name then
seen=true
break
end
end
if not seen then
UISpecialFrames[#UISpecialFrames+1]=name
end
end
frame:SetScript("OnHide",function(self)
forget(self)
end)
return frame
end
local function matchResultWords(info)
local result=info.result
local said
if type(info.pips)=="table"then
if result=="-"then
return info.format or""
end
said=("you won %s"):format(result)
elseif result=="won"then
said="you won"
elseif result=="lost"then
said="you lost"
elseif result=="draw"then
said="a draw"
else
said="no result"
end
if info.format then
return("%s, %s"):format(info.format,said)
end
return said
end
local function stripSide(label,parts)
local pieces=A.sideShort(parts)
local text=A.colorEscape("dim")..label.."|r "
if not pieces then
return text..A.colorEscape("dimmer").."-|r"
end
local out={}
for i=1,#pieces do
out[i]=A.colorEscape(pieces[i].tone or"dim")..pieces[i].text.."|r"
end
return text..table.concat(out,", ")
end
local function paintMatchStrip(frame,index)
local strip=frame.matchStrip
local record=frame.fromMatch~=nil and A.match(frame.fromMatch)or nil
local info=record and A.playerInMatch(frame.guid,record,index)or nil
frame.stripFloor,frame.stripRounds,frame.stripResult=nil,nil,nil
if not info then
strip:SetHeight(1)
strip:Hide()
return nil,nil
end
strip:SetHeight(A.playerMatchStripHeight())
strip:Show()
strip.ground:SetColorTexture(A.color("panelDeep"))
strip.rule:SetColorTexture(A.color("hairline"))
A.style(strip.title,"label","dim")
strip.title:SetText(("IN MATCH #%s"):format(tostring(info.id)))
A.style(strip.map,"bodyText","text")
strip.map:SetText(info.map or"-")
A.style(strip.result,"note","dim")
local resultWords=matchResultWords(info)
strip.result:SetText(resultWords)
local pips=type(info.pips)=="table"and info.pips or{}
for i,round in ipairs(strip.rounds)do
local pip=pips[i]
if pip then
A.style(round.label,"rowClock","dimmer")
round.label:SetText(("R%d"):format(i))
A.paintRoundMark(round.mark,pip)
local ink=pip.side=="with"and"menuGround"or(pip.side and pip.tone or"dimmer")
A.style(round.word,"label",ink)
round.word:SetText(pip.side=="with"and"WITH"or(pip.side=="against"and"VS"or"-"))
round:Show()
else
round:Hide()
end
end
A.style(strip.with,"bodyText","text")
local withText=stripSide("With you",info.with)
strip.with:SetText(withText)
A.style(strip.against,"bodyText","text")
local againstText=stripSide("Against you",info.against)
strip.against:SetText(againstText)
frame.stripForms={
with={withText,stripSide("With",info.with)},
against={againstText,stripSide("Vs",info.against)},
}
frame.stripRounds=math.min(#pips,#strip.rounds)
frame.stripFloor=A.playerStripFloor(frame.stripRounds,withText,againstText,strip.with)
frame.stripResult=resultWords
return info.id,info
end
local function fitStripSides(frame,body)
local forms=frame.stripForms
frame.stripForms=nil
if type(forms)~="table"or not frame.matchStrip:IsShown()then
return
end
local strip=frame.matchStrip
local room=math.floor(body-A.playerStripLeftEnd(frame.stripRounds)-A.metric("paneGap")
-A.metric("standPad"))
frame.stripSideRoom=room
for _,side in ipairs({"with","against"})do
local text=A.fittedForm(strip[side],room,forms[side])or forms[side][#forms[side]]
strip[side]:SetWidth(math.max(1,room))
strip[side]:SetText(text)
end
end
local function paintHead(frame,dossier)
local identity=dossier.identity
A.drawSpec({icon=frame.headIcon},identity.classToken,identity.spec,nil,
{size=A.fontSize("dossierName")})
A.style(frame.name,"dossierName")
frame.name:SetTextColor(A.classColor(identity.classToken))
A.style(frame.sub,"bodyText","dim")
frame.sub:SetText(dossier.specLine or"no spec recorded")
frame.copyText,frame.murlokText=A.playerCopyTexts(frame.guid,dossier.entry)
frame.inPlayers:ClearAllPoints()
frame.inPlayers:SetPoint("TOPRIGHT",frame.matchStrip,"BOTTOMRIGHT",0,-A.metric("paneGap"))
local edge=frame.inPlayers
for _,pair in ipairs({{frame.murlok,frame.murlokText},{frame.copyName,frame.copyText}})do
local button,text=pair[1],pair[2]
button:ClearAllPoints()
if text then
button:SetPoint("TOPRIGHT",edge,"TOPLEFT",-A.metric("pillGap"),0)
button:Show()
edge=button
else
button:Hide()
end
end
frame.name:SetPoint("RIGHT",edge,"LEFT",-A.metric("paneGap"),0)
A.fitNameHead(frame.name,identity.bare or A.UNKNOWN_PLAYER,identity.realm,"dim")
end
local function paintMet(frame,dossier,widths)
A.paintEncounterHeader(frame.metHeader,widths)
local encounters=dossier.encounters or{}
local shown={}
for i=1,math.min(#encounters,MET_ROWS)do
shown[i]=encounters[i]
end
if frame.fromMatch~=nil then
local inView=false
for i=1,#shown do
if shown[i].id==frame.fromMatch then
inView=true
end
end
if not inView then
for i=MET_ROWS+1,#encounters do
if encounters[i].id==frame.fromMatch then
shown[math.min(#shown,MET_ROWS)]=encounters[i]
break
end
end
end
end
local drawn,marked=0,false
for i=1,MET_ROWS do
local row=frame.metRows[i]
local encounter=shown[i]
local line=encounter and A.encounterLine(encounter)or nil
if line then
drawn=drawn+1
local here=frame.fromMatch~=nil and encounter.id==frame.fromMatch
marked=marked or here
A.paintEncounterLine(row,line,widths,here)
row:Show()
else
A.paintEncounterLine(row,nil)
row:Hide()
end
end
local tail=""
if drawn==0 then
tail="no match with them"
elseif#encounters>drawn then
local more=#encounters-drawn
tail=("%d more %s"):format(more,more==1 and"encounter"or"encounters")
end
local under=drawn>0 and frame.metRows[drawn]or frame.metHeader
frame.metTail:ClearAllPoints()
frame.metTail:SetPoint("TOPLEFT",under,"BOTTOMLEFT",A.metric("rowLabelPad"),0)
frame.metTail:SetPoint("TOPRIGHT",under,"BOTTOMRIGHT",0,0)
A.style(frame.metTail,"note","dim")
frame.metTail:SetText(tail)
return drawn,marked
end
local function paintComments(frame,width)
local comments=A.playerComments(frame.guid)
A.style(frame.commentTitle,"label","dim")
frame.commentTitle:SetText(("COMMENTS  %s%d|r"):format(A.colorEscape("text"),#comments))
A.style(frame.commentOrder,"note","dimmer")
frame.commentOrder:SetText(#comments>1 and"newest first"or"")
frame.commentHead.rule:SetColorTexture(A.color("hairline"))
local stamp=A.playerStampWidth()
local textWidth=width-stamp-A.metric("rowCellGap")*2-A.metric("tagButton")
local y=0
for i=1,#comments do
local comment=comments[i]
local row=commentRow(frame,i)
row.commentIndex=comment.index
row.commentText=comment.text
A.style(row.stamp,"note","dimmer")
row.stamp:SetText(comment.at and A.minuteStamp(tostring(comment.at))or"-")
A.style(row.text,"bodyText","text")
row.text:SetWidth(textWidth)
row.text:SetText(comment.text)
local ok,high=pcall(row.text.GetStringHeight,row.text)
if not(ok and type(high)=="number"and high>0)then
high=A.metric("rowHeight")
end
if high<A.metric("rowHeight")then
high=A.metric("rowHeight")
end
local height=high+A.metric("commentPad")*2
row.rule:SetColorTexture(A.color("hairline"))
row:ClearAllPoints()
row:SetPoint("TOPLEFT",frame.commentList,"TOPLEFT",0,-y)
row:SetWidth(width)
row:SetHeight(height)
row:Show()
y=y+height
end
for i=#comments+1,#frame.commentRows do
local row=frame.commentRows[i]
row.commentIndex,row.commentText=nil,nil
row:Hide()
end
frame.commentList:SetHeight(y>0 and y or 1)
return#comments
end
local function sideReading(parts)
local pieces=A.sideShort(parts)
if not pieces then
return nil
end
local units={}
for i=1,#parts do
units[i]=parts[i].unit
end
return("%s (%s)"):format(A.sideShortText(pieces),table.concat(units,"+"))
end
paintWindow=function(frame,index)
if not(frame and frame.guid)then
return false
end
index=index or A.encounterIndex()
local dossier=A.playerDossier(frame.guid,index)
if not dossier then
return false
end
frame.heading:SetText(dossier.identity.full)
local stripId,stripInfo=paintMatchStrip(frame,index)
local floorWidth=A.playerWindowWidth(frame.stripFloor)
local width=floorWidth
frame.widthFrom="paint"
if type(frame.wantWidth)=="number"and frame.wantWidth>floorWidth then
width=frame.wantWidth
frame.widthFrom=frame.wantFrom or"paint"
end
pcall(frame.SetWidth,frame,width)
bound(frame,floorWidth)
local body,bodyFloor=A.playerWindowBodyAt(width,frame.stripFloor)
frame.paintBody=body
pcall(frame.commentList.SetWidth,frame.commentList,body)
fitStripSides(frame,body)
paintHead(frame,dossier)
A.paintRepControl(frame.rep,dossier.rating,body,true)
A.paintSideCards(frame.cards,dossier,body)
local note=dossier.note
local shown,typed=A.paintNoteBox(frame.noteRow.box,frame,frame.guid,note and note.text)
A.paintNoteRow(frame.noteRow,shown)
local tagRows=A.paintTagRow(frame.tagRow,note,body)
local widths=A.playerWindowColumns(body-bodyFloor)
local metDrawn,marked=paintMet(frame,dossier,widths)
local comments=paintComments(frame,body)
local tagline,credit=A.windowFootLine()
A.style(frame.footName,"rowNote","dimmer")
A.style(frame.footState,"rowNote","dimmer")
frame.footName:SetText(tagline)
frame.footState:SetText(credit)
local ids={}
for i=1,#(dossier.record.ids or{})do
ids[i]=tostring(dossier.record.ids[i])
end
frame.drawn={met=metDrawn,tagRows=tagRows,comments=comments,strip=stripId,
marked=marked}
pcall(A.trace,"paint",{source="player",rows=metDrawn,n=comments,
shown=tagRows,typed=typed or nil,id=stripId,marked=marked or nil,
with=sideReading(dossier.with),against=sideReading(dossier.against),
ids=table.concat(ids,","),
matchWith=stripInfo and sideReading(stripInfo.with)or nil,
matchAgainst=stripInfo and sideReading(stripInfo.against)or nil,
result=frame.stripResult,
stripRoom=frame.stripFloor and A.unitFigure(body-frame.stripFloor+A.metric("paneGap"))or nil,
bodyWidth=A.unitFigure(body),bodyFloor=A.unitFigure(bodyFloor)},"ui")
return true
end
local function openCount()
local n=0
for i=1,#order do
if open[order[i]]then
n=n+1
end
end
return n
end
local function trace(state,source,reason,drafts,frame,beside)
local placed=state=="opened"and frame or nil
local bottom,height,srcBottom
if placed then
local okRect,_,low,_,tall=pcall(placed.GetRect,placed)
if okRect and type(low)=="number"then
bottom,height=A.unitFigure(low),A.unitFigure(tall)
end
if type(beside)=="table"then
local okSrc,_,srcLow=pcall(beside.GetRect,beside)
if okSrc and type(srcLow)=="number"then
srcBottom=A.unitFigure(srcLow)
end
end
end
pcall(A.trace,"player-window",{state=state,source=source or"select",
windowsOpen=openCount(),reason=reason,drafts=drafts,
side=placed and placed.placedSide or nil,
room=placed and placed.placedRoom and A.unitFigure(placed.placedRoom)or nil,
placedScreen=placed and placed.placedScreen and A.unitFigure(placed.placedScreen)or nil,
id=frame and frame.fromMatch or nil,
bottom=bottom,height=height,srcBottom=srcBottom,
stripFloor=frame and frame.stripFloor and A.unitFigure(frame.stripFloor)or nil,
widthFrom=frame and frame.widthFrom or nil,
sizeFrom=placed and placed.sizeFrom or nil},"ui")
end
forget=function(frame)
local guid=frame.guid
if guid and open[guid]==frame then
open[guid]=nil
for i=#order,1,-1 do
if order[i]==guid then
table.remove(order,i)
end
end
trace("closed",frame.closeSource or"hide")
end
frame.closeSource=nil
frame.guid=nil
end
local function clearDrafts(frame,guid)
if frame.draftsFor==guid then
return nil
end
frame.draftsFor=guid
local held=0
for _,box in ipairs({frame.commentBox,frame.tagRow.box})do
local ok,text=pcall(box.GetText,box)
if ok and type(text)=="string"and text~=""then
held=held+1
pcall(box.SetText,box,"")
end
end
return held>0 and held or nil
end
local function freeFrame()
for i=1,#pool do
if not pool[i].guid then
return pool[i]
end
end
local built,err=A.buildWindowOnce("player",buildWindow,#pool+1)
if not built then
if err then
A.noteError(("a player window could not be built: %s"):format(err),"player/build")
end
return nil
end
pool[#pool+1]=built
return built
end
local function nextStep(frame)
local highest=-1
for i=1,#order do
local held=open[order[i]]
if held and held~=frame and type(held.cascadeStep)=="number"and held.cascadeStep>highest then
highest=held.cascadeStep
end
end
return highest+1
end
function A.playerWindowSide(beside,width)
if type(beside)~="table"or type(width)~="number"then
return nil
end
local okRect,left,_,wide=pcall(beside.GetRect,beside)
if not(okRect and type(left)=="number"and type(wide)=="number")then
return nil
end
local okScreen,screen=pcall(UIParent.GetWidth,UIParent)
if not(okScreen and type(screen)=="number"and screen>0)then
return nil
end
local gap=A.metric("detailGap")
local roomRight=screen-(left+wide)-gap
local roomLeft=left-gap
if roomRight>=width then
return"right",roomRight,screen
end
if roomLeft>roomRight then
return"left",roomLeft,screen
end
return"right",roomRight,screen
end
local function place(frame,beside)
frame.cascadeStep=nextStep(frame)
frame.undocked=nil
pcall(frame.ClearAllPoints,frame)
local cascade=A.metric("detailCascade")*frame.cascadeStep
local gap=A.metric("detailGap")
if type(beside)=="table"then
local okWidth,width=pcall(frame.GetWidth,frame)
if not(okWidth and type(width)=="number"and width>0)then
width=A.playerWindowWidth(frame.stripFloor)
frame.widthFrom="fallback"
end
local side,room,screen=A.playerWindowSide(beside,width)
frame.placedSide,frame.placedRoom,frame.placedScreen=side or"right",room,screen
frame.placedOver=type(room)=="number"and room<width or nil
local top=frame.placedOver and"BOTTOM"or"TOP"
local drop=frame.placedOver and 0 or-cascade
if side=="left"then
pcall(frame.SetPoint,frame,top.."RIGHT",beside,top.."LEFT",-(gap+cascade),drop)
else
pcall(frame.SetPoint,frame,top.."LEFT",beside,top.."RIGHT",gap+cascade,drop)
end
pcall(frame.SetUserPlaced,frame,false)
return frame.placedSide
end
frame.placedRoom,frame.placedScreen=nil,nil
local list=type(A.windowFrameOf)=="function"and A.windowFrameOf("matches")or nil
if not list then
frame.placedSide="screen"
pcall(frame.SetPoint,frame,"CENTER")
return frame.placedSide
end
frame.placedSide="dock"
local across=gap*2+A.detailWindowWidth()
pcall(frame.SetPoint,frame,"TOPLEFT",list,"TOPRIGHT",across+cascade,-cascade)
pcall(frame.SetUserPlaced,frame,false)
return frame.placedSide
end
function A.openPlayer(guid,forWriting,source,beside)
local usable,why=A.playerKey(guid)
if not usable then
trace("refused",source,why)
return nil,"refused"
end
local frame=open[guid]
local outcome="raised"
local drafts
if not frame then
frame=freeFrame()
if not frame then
trace("refused",source,"no-frame")
return nil,"refused"
end
drafts=clearDrafts(frame,guid)
frame.guid=guid
open[guid]=frame
order[#order+1]=guid
outcome="opened"
local held=type(A.pooledOpenSize)=="function"and A.pooledOpenSize("player")or nil
local height=held and held.height or A.playerWindowHeight()
if height<A.playerWindowFloor()then
height=A.playerWindowFloor()
end
pcall(frame.SetHeight,frame,height)
frame.sizeFrom=held and"stored"or"authored"
frame.wantWidth=held and held.width or nil
frame.wantFrom=held and"stored"or nil
pcall(frame.Show,frame)
end
if outcome=="opened"then
frame.fromMatch=nil
end
local record=type(beside)=="table"and beside.record or nil
if type(record)=="table"and record.id~=nil then
frame.fromMatch=record.id
end
local painted,err=pcall(paintWindow,frame)
if not painted then
A.noteError(("a player window did not paint: %s"):format(tostring(err)),"player/paint")
end
if outcome=="opened"then
place(frame,beside)
end
pcall(frame.Show,frame)
pcall(frame.Raise,frame)
if forWriting then
pcall(function()
frame.noteRow.box:SetFocus()
frame.noteRow.box:SetCursorPosition(frame.noteRow.box:GetNumLetters()or 0)
end)
end
trace(outcome,source,nil,drafts,frame,beside)
return frame,outcome
end
function A.togglePlayer(guid,source,beside)
local frame=guid~=nil and open[guid]or nil
if frame then
frame.closeSource=source
pcall(frame.Hide,frame)
frame.closeSource=nil
return nil,"closed"
end
return A.openPlayer(guid,false,source,beside)
end
function A.refreshPlayerWindows(index)
for i=1,#order do
local frame=open[order[i]]
if frame then
if index==nil then
local built,made=pcall(A.encounterIndex)
index=built and made or nil
end
pcall(paintWindow,frame,index)
end
end
return true
end
function A.playerWindowsOpen()
local out={}
for i=1,#order do
local frame=open[order[i]]
if frame then
out[#out+1]={guid=frame.guid,name=frame.windowName,frame=frame,
step=frame.cascadeStep,docked=frame.undocked~=true}
end
end
return out
end
if type(A.registerWindowKind)=="function"then
A.registerWindowKind("player",{
label="player window",
authored=function()
return A.playerWindowWidth(),A.playerWindowHeight()
end,
floor=function()
return A.playerWindowWidth(),A.playerWindowFloor()
end,
pooled=true,
newest=function()
local held=A.playerWindowsOpen()
return held[#held]and held[#held].frame or nil
end,
sized=function(frame,geometry)
frame.wantWidth,frame.wantFrom=geometry.width,"typed"
pcall(frame.SetHeight,frame,geometry.height)
frame.sizeFrom="typed"
pcall(paintWindow,frame)
end,
})
end
function A.closePlayerWindows()
local closed=0
for i=#order,1,-1 do
local frame=open[order[i]]
if frame then
closed=closed+1
pcall(frame.Hide,frame)
end
end
return closed
end
