-- WowPvpHistory 0.68.35
-- Author:  Xenu-Sentinels
-- Project: wow-pvp-history
--          https://github.com/xenulive/wow-pvp-history
-- License: MIT, see LICENSE
local _,A=...
local FRAME_NAME="WowPvpHistoryFrame"
local window
local activeFormat
local lastRows=0
local lastColumns=nil
local selectedId
local selectedKind="match"
local searchText,searchTerms=nil,{}
local searchShown,searchScoped=0,0
local filterBand={result=nil,spec=nil}
local activeBody="history"
local shownSpec
local activeAskRow,activeAskRowKey,activeAskRowFormat,activeAskRowScope
local shownAskRow
local activeCharacter
local characterResolved
local function tabHoldsIncomplete(format)
return format==nil or format=="unknown"
end
local TITLE_CREDIT="by Xenu-Sentinels"
local TITLE_CREDIT_CLASS="WARLOCK"
local TITLE_TAGLINE="Every arena, every battleground, every opponent, remembered."
function A.windowFootLine()
return TITLE_TAGLINE,
("%s %s %s"):format(A.displayName(),tostring(A.version or"unknown"),TITLE_CREDIT)
end
function A.windowCredit()
return TITLE_CREDIT
end
function A.windowCreditClass()
return TITLE_CREDIT_CLASS
end
local repaintEverything
local matchWindowOpenOn
local darkList={PIP_SLOTS=6,GRIDHOVER_TRACES=20,gridHoverN=0}
darkList.ROW_CELL_SLOTS=11
darkList.ROW_MARK_SLOTS=6
local function columnWidths(columns)
local widths={}
for i=1,#columns do
local column=columns[i]
local share=column.width
widths[i]=(type(share)=="number"and share>0)and share or A.metric(column.metric)
end
return widths
end
local function spanOfWidths(widths)
local span=A.metric("rowLabelPad")*2-A.metric("rowCellGap")
for i=1,#widths do
span=span+widths[i]+A.metric("rowCellGap")
end
return span
end
function A.columnSpan(columns)
if type(columns)~="table"or#columns==0 then
return nil
end
return spanOfWidths(columnWidths(columns))
end
local function summaryHeight(headline)
if type(A.summaryHeight)~="function"then
return 0
end
local ok,height=pcall(A.summaryHeight,headline)
if not ok or type(height)~="number"or height<0 then
return 0
end
return height
end
local function lobbyGapBefore(previous,column)
if previous==nil then
if column.lane=="name"then
return A.metric("classEdge")+A.metric("rowNamePad")-A.metric("rowLabelPad")
end
return 0
end
if previous.lane=="round"and column.lane=="round"then
return A.metric("lobbyRoundGap")
end
if previous.lane=="round"then
return A.metric("lobbyRunGap")
end
return A.metric("rowCellGap")
end
function A.lobbyLayout(columns,available)
if type(columns)~="table"or#columns==0 then
return nil
end
local widths,gaps={},{}
for i=1,#columns do
gaps[i]=lobbyGapBefore(columns[i-1],columns[i])
widths[i]=A.metric(columns[i].metric)
end
local first=1
while first<=#columns do
local group,last=columns[first].group,first
while group~=nil and last<#columns and columns[last+1].group==group do
last=last+1
end
if group~=nil then
local span=widths[first]
for i=first+1,last do
span=span+gaps[i]+widths[i]
end
local short=A.headerFloor(group)-span
if short>0 then
local count=last-first+1
local each=math.floor(short/count)
for i=first,last do
widths[i]=widths[i]+each
end
widths[last]=widths[last]+(short-each*count)
end
end
first=last+1
end
local stated,lanes=A.metric("rowLabelPad")*2,0
for i=1,#columns do
stated=stated+gaps[i]+widths[i]
lanes=lanes+widths[i]
end
if type(available)=="number"and available>stated and lanes>0 then
local surplus,spent=available-stated,0
for i=1,#columns do
local share=math.floor(widths[i]*surplus/lanes)
widths[i]=widths[i]+share
spent=spent+share
end
widths[#columns]=widths[#columns]+(surplus-spent)
end
local offsets={}
local at=A.metric("rowLabelPad")
for i=1,#columns do
at=at+gaps[i]
offsets[i]=at
at=at+widths[i]
end
return{widths=widths,offsets=offsets,span=at+A.metric("rowLabelPad")}
end
function A.listHostWidth(paneShown)
if paneShown then
return A.listSplitWidth()
end
if A.duelPanelShown()then
return A.bodyWidth()-A.metric("duelPanel")-A.metric("paneSplitGap")
end
return A.bodyWidth()
end
function A.duelPanelShown()
return activeFormat=="duel"and activeBody=="history"
end
function A.listTableWidth()
return A.listHostWidth(false)
end
function A.listColumnShares(columns,within)
if type(columns)~="table"or#columns==0 then
return columns
end
for i=1,#columns do
if type(columns[i].width)=="number"then
return columns
end
end
local widths=columnWidths(columns)
local total,widest,at=0,0,1
for i=1,#widths do
total=total+widths[i]
if widths[i]>widest then
widest,at=widths[i],i
end
end
local room=within
if type(room)~="number"then
room=A.listTableWidth()
end
if total<=0 or type(room)~="number"or room<=0 then
return columns
end
local available=room-(spanOfWidths(widths)-total)
if available<=0 then
return columns
end
local out,spent={},0
for i=1,#columns do
local share=math.floor(widths[i]*available/total)
local column={}
for key,value in pairs(columns[i])do
column[key]=value
end
column.width=share
out[i]=column
spent=spent+share
end
out[at].width=out[at].width+(available-spent)
return out
end
function A.compPaneWidth()
return A.askPaneWidth()-A.metric("rowNamePad")
end
function A.specPaneWidth()
return A.askPaneWidth()-A.metric("rowNamePad")*2-A.metric("rowLabelPad")
end
function A.specGroupRuns(width)
local spread=A.listColumnShares(A.rowColumns("specpair"),A.bodyWidth(width))
local out,at={},{}
for i=1,(type(spread)=="table"and#spread or 0)do
local label=spread[i].group
if type(label)=="string"then
local run=at[label]
if run==nil then
run={label=label,run=-A.metric("rowCellGap"),need=A.headerFloor(label)}
at[label]=run
out[#out+1]=run
end
run.run=run.run+(spread[i].width or A.metric(spread[i].metric))+A.metric("rowCellGap")
end
end
return out
end
function A.detailPaneWidth()
return A.paneWidth()
end
function A.detailWindowBody(record)
local look=type(A.rosterLook)=="function"and A.rosterLook(record)or nil
local objectives=0
if look=="team"and type(A.objectiveColumns)=="function"then
objectives=math.min(#A.objectiveColumns(record),A.metric("rowObjectiveMax"))
end
local roster=A.rosterRowWidth(look,objectives)
local set=nil
if record~=nil and type(A.lobbyPaneDraws)=="function"and A.lobbyPaneDraws(record)then
set=A.lobbyPaneColumns(record)
end
if set==nil and type(A.rowColumns)=="function"then
set=A.rowColumns("lobby")
end
local layout=A.lobbyLayout(set)
local table_=layout and layout.span or 0
return roster>table_ and roster or table_
end
function A.detailWindowWidth(record)
return A.metric("margin")*2+A.metric("paneRightPad")
+A.detailWindowBody(record)+A.metric("detailTextInset")+A.metric("detailBarInset")
end
function A.detailWindowHeight()
local cards,strip=A.objectiveCardsHeight(),A.objectivesHeight()
return A.metric("headerHeight")+A.metric("margin")
+A.headHeight()+A.headSubHeight()
+(cards>strip and cards or strip)
+(A.metric("rosterHeadRow")+A.metric("rosterHeadGap"))*2
+A.metric("participantRow")*A.metric("detailRows")
+A.metric("paneEditGap")+A.metric("editHeight")+A.metric("margin")
end
function A.detailWindowFloor()
return A.metric("headerHeight")+A.metric("margin")
+A.headHeight()+A.headSubHeight()
+A.metric("rosterHeadRow")+A.metric("rosterHeadGap")
+A.metric("participantRow")
+A.metric("paneEditGap")+A.metric("editHeight")+A.metric("margin")
end
function A.detailWindowBodyAt(width)
return width-A.metric("margin")*2-A.metric("paneRightPad")
-A.metric("detailTextInset")-A.metric("detailBarInset")
end
function A.paceTrackWidth()
return A.detailPaneWidth()-A.metric("detailTextInset")-A.metric("detailBarInset")
-A.metric("objectivesPad")*2-A.metric("paceLabel")-A.metric("paceValue")
-A.metric("objectivesGap")*2
end
local function heightForRows(rows,headline)
local above=A.metric("headerHeight")+A.metric("filterHeight")
+A.metric("summaryGap")+summaryHeight(headline)+A.metric("paneGap")
local list=A.metric("rowHeadRow")+A.metric("rowHeight")*rows
return above+list+A.bodyFloor()
end
function A.matchWindowHeight(headline)
return heightForRows(A.metric("windowRows"),headline)
end
local function setNeedWidth(columns)
if type(columns)~="table"or#columns==0 then
return 0,nil
end
local total,factor,who=0,0,nil
for i=1,#columns do
local stated=A.metric(columns[i].metric)
local head=A.headerFloor(columns[i].name)
total=total+stated
if stated>0 and head/stated>factor then
factor,who=head/stated,columns[i].name
end
end
if total<=0 or factor<=0 then
return 0,nil
end
return math.ceil(total*factor)+A.metric("rowLabelPad")*2
+A.metric("rowCellGap")*(#columns-1),who
end
local function listNeedWidth()
local widest,who,where=0,nil,nil
for _,set in ipairs(A.listColumnSets())do
local need,column=setNeedWidth(set.columns)
if need>widest then
widest,who,where=need,column,set.name
end
end
return widest+A.metric("margin")*2+A.metric("paneRightPad"),who,where
end
local function askNeedRoom()
local questions=A.askQuestions()
local room,last=1,nil
for _=1,4096 do
local held=true
local got={A.askColumnShares(room)}
for q=1,#questions do
local columns=A.rowColumns(questions[q].columns)
for i=1,(type(columns)=="table"and#columns or 0)do
if(got[i]or 0)<A.headerFloor(columns[i].name)then
held,last=false,columns[i].name
break
end
end
if not held then
break
end
end
if held then
return room,last
end
room=room+1
end
return nil,nil
end
local function askNeedWidth()
local room,column=askNeedRoom()
if type(room)~="number"then
return nil,nil
end
for width=1,4096 do
if A.askTableWidth(width)>=room then
return width,column
end
end
return nil,nil
end
local function specsNeedWidth()
local key=A.metric("readingKeyWidth")+A.metric("readingKeyGap")
for width=1,4096 do
local held=A.bodyWidth(width)>=key
if held then
for _,group in ipairs(A.specGroupRuns(width))do
if group.run<group.need then
held=false
break
end
end
end
if held then
return width
end
end
return nil
end
filterBand.SEARCH_COUNT_SAMPLE="000 of 000 matches"
filterBand.SEARCH_BOX_SAMPLE="Name-Realm"
filterBand.SEARCH_PLACEHOLDER="search names, specs, maps"
function A.listSearchBand()
return A.metric("searchHeight")+A.metric("paneGap")
end
function A.listSearchCountWidth()
return A.headerFloor(filterBand.SEARCH_COUNT_SAMPLE)
end
function A.listSearchClearWidth()
return A.headerFloor("clear")+A.metric("entryInsetX")*2
end
function A.listSearchBoxWidth()
return A.metric("entryInsetX")+A.headerFloor(filterBand.SEARCH_PLACEHOLDER)+A.listSearchClearWidth()
end
function A.listSearchBoxFloor()
return A.metric("entryInsetX")*2+A.headerFloor(filterBand.SEARCH_BOX_SAMPLE)+A.listSearchClearWidth()
end
filterBand.RESULT_SAMPLE="All results"
filterBand.SPEC_SAMPLE="Frost Death Knight  000"
function A.listFilterWidth(sample)
local want=A.headerFloor(sample)+A.metric("dropdownPad")*4+A.metric("dropdownCaret")
if want<A.metric("dropdownWidth")then
want=A.metric("dropdownWidth")
end
local most=A.metric("dropdownWidthMax")
if most>0 and want>most then
want=most
end
return want
end
filterBand.ZONE_SAMPLE="Isle of Dorn  000"
filterBand.ZONE_PLACEHOLDER="search zones"
filterBand.SCOPE_SAMPLE="Last 6 months"
function A.listFilterBandWidth()
return A.metric("rowCellGap")+A.listFilterWidth(filterBand.SPEC_SAMPLE)
+A.metric("rowCellGap")+A.listFilterWidth(filterBand.RESULT_SAMPLE)
+A.metric("rowCellGap")+A.listFilterWidth(filterBand.SCOPE_SAMPLE)
end
local function searchNeedWidth()
return A.listSearchBoxFloor()+A.metric("rowCellGap")+A.listSearchCountWidth()
+A.listFilterBandWidth()+A.metric("rowLabelPad")+A.metric("margin")*2+A.metric("paneRightPad")
end
function A.matchWindowFloor()
local width=listNeedWidth()
local ask=askNeedWidth()
if type(ask)=="number"and ask>width then
width=ask
end
local specs=specsNeedWidth()
if type(specs)=="number"and specs>width then
width=specs
end
local search=searchNeedWidth()
if type(search)=="number"and search>width then
width=search
end
if type(width)~="number"or width<=0 then
width=A.metric("frameWidth")
end
return width,heightForRows(A.metric("windowMinRows"))
end
function A.matchFloorReason()
local list,listColumn=listNeedWidth()
local ask,askColumn=askNeedWidth()
local specs=specsNeedWidth()
local search=searchNeedWidth()
local function held(value)
return(type(value)=="number"and value>0)and value or nil
end
list,ask,specs,search=held(list),held(ask),held(specs),held(search)
if list==nil and ask==nil and specs==nil and search==nil then
return nil
end
local terms={
{what=("the match list's %s column"):format(tostring(listColumn or"widest")),
short="the match list's",need=list},
{what=("the Ask answer's %s column"):format(tostring(askColumn or"name")),
short="the Ask answer's",need=ask},
{what="the Specs table's group row",short="the Specs table's",need=specs},
{what="the match list's search box and filters",short="the search band's",need=search},
}
local winner=nil
for i=1,#terms do
if terms[i].need~=nil and(winner==nil or terms[i].need>terms[winner].need)then
winner=i
end
end
local rest={}
for i=1,#terms do
if i~=winner then
rest[#rest+1]=("%s %d"):format(terms[i].short,terms[i].need or 0)
end
end
return("%s at its own header, %d, over %s"):format(terms[winner].what,terms[winner].need,
table.concat(rest," and "))
end
local function paintColumnHead(head,names,rule,columns,sorting,tone)
local widths=columnWidths(columns)
local at=A.metric("rowLabelPad")
for i=1,#names do
local name=names[i]
if columns[i]==nil then
name:Hide()
else
name:ClearAllPoints()
name:SetPoint("LEFT",head,"LEFT",at,0)
name:SetWidth(widths[i])
name:SetJustifyH(columns[i].align=="RIGHT"and"RIGHT"or"LEFT")
A.style(name,"label",
(sorting~=nil and columns[i].sort==sorting)and"accent"or(tone or"dim"))
name:SetText(columns[i].name or"")
name:Show()
at=at+widths[i]+A.metric("rowCellGap")
end
end
local span=spanOfWidths(widths)
if rule~=nil then
rule:SetColorTexture(A.color("hairline"))
rule:ClearAllPoints()
rule:SetPoint("BOTTOMLEFT",head,"BOTTOMLEFT",0,0)
rule:SetWidth(span)
end
return span,widths
end
local function paintGroupHead(head,names,columns,widths,justify)
for i=1,#names do
names[i]:Hide()
if names[i].rule~=nil then
names[i].rule:Hide()
end
end
if type(columns)~="table"or type(widths)~="table"then
return false
end
local drew=false
local at=A.metric("rowLabelPad")
local slot,i=0,1
while i<=#columns do
if widths[i]==nil then
i=i+1
else
local group=columns[i].group
local room,last=widths[i],i
while last<#columns and columns[last+1].group==group
and widths[last+1]~=nil do
last=last+1
room=room+widths[last]+A.metric("rowCellGap")
end
if group~=nil then
slot=slot+1
local name=names[slot]
if name then
name:ClearAllPoints()
name:SetPoint("LEFT",head,"LEFT",at,0)
name:SetWidth(room)
name:SetJustifyH(justify=="CENTER"and"CENTER"or"LEFT")
local tone=columns[i].groupTone
A.style(name,"label",tone or"dim")
name:SetText(group)
name:Show()
if tone~=nil and name.rule~=nil then
name.rule:ClearAllPoints()
name.rule:SetPoint("BOTTOMLEFT",head,"BOTTOMLEFT",at,0)
name.rule:SetSize(room,2)
name.rule:SetColorTexture(A.color(tone))
name.rule:Show()
end
drew=true
end
end
at=at+room+A.metric("rowCellGap")
i=last+1
end
end
return drew
end
local function paintSortButtons(buttons,head,columns,widths)
for i=1,#buttons do
buttons[i]:Hide()
buttons[i].sortKey=nil
end
if type(columns)~="table"or type(widths)~="table"then
return 0
end
local shown=0
local at=A.metric("rowLabelPad")
for i=1,#columns do
if widths[i]~=nil then
local button=buttons[i]
if button and type(columns[i].sort)=="string"then
button.sortKey=columns[i].sort
button:ClearAllPoints()
button:SetPoint("TOPLEFT",head,"TOPLEFT",at,0)
button:SetWidth(widths[i])
button:Show()
shown=shown+1
end
at=at+widths[i]+A.metric("rowCellGap")
end
end
return shown
end
local function hideRowBar(row)
if row.barTrack==nil then
return
end
row.barTrack:Hide()
row.barWin:Hide()
row.barLoss:Hide()
if row.barMid~=nil then
row.barMid:Hide()
end
end
function darkList.hideRow(row)
if row.selfChip==nil then
return
end
local function hideChip(held)
held.ground:Hide()
held.text:Hide()
end
hideChip(row.selfChip)
for i=1,#row.chips do
hideChip(row.chips[i])
end
for i=1,#row.pips do
row.pips[i]:Hide()
end
for i=1,#(row.kdMarks or{})do
row.kdMarks[i]:Hide()
end
row.changeAxis:Hide()
row.changeBar:Hide()
for _,sub in pairs(row.cellSubs or{})do
sub:Hide()
end
if row.reasonMenu~=nil then
row.reasonMenu:Hide()
end
end
local function hideRowSecond(row)
darkList.hideRow(row)
if row.flatGround~=nil then
row.flatGround:Hide()
end
if row.crest~=nil then
row.crest:Hide()
end
if row.rule~=nil then
row.rule:Hide()
end
if row.clock~=nil then
row.clock:Hide()
row.spec:Hide()
row.lobbyNote:Hide()
row.lobbyAgainst:Hide()
for i=1,#row.marks do
row.marks[i]:Hide()
end
end
end
local function layoutRowCrest(row,data,columns,widths,offsets)
if row.crest==nil then
return
end
local side=type(data)=="table"and data.crest or nil
local atlas=side~=nil and type(A.factionCrest)=="function"and A.factionCrest(side)or nil
local index=nil
if atlas~=nil then
for i=1,#columns do
if columns[i].key=="crest"and widths[i]~=nil and type(offsets[i])=="number"then
index=i
break
end
end
end
if index==nil then
row.crest:Hide()
return
end
local inset=A.metric("rowLeadInset")
local size=math.min(A.fontSize("heading"),widths[index]-inset)
if size<=0 then
row.crest:Hide()
return
end
row.crest:ClearAllPoints()
row.crest:SetPoint("TOPLEFT",row,"TOPLEFT",offsets[index]+inset,
-math.max(0,math.floor((A.metric("rowHeight")-size)*0.5)))
row.crest:SetAtlas(atlas,false)
row.crest:SetSize(size,size)
row.crest:Show()
end
local function layoutRowSecond(row,data,columns,widths,offsets,trail)
if row.clock==nil then
return
end
local second=type(data)=="table"and data.second or nil
if second==nil then
hideRowSecond(row)
return
end
local lanes={}
for i=1,#columns do
if columns[i].key~="crest"and widths[i]~=nil and type(offsets[i])=="number"then
lanes[#lanes+1]={at=offsets[i],width=widths[i]}
end
end
if#lanes<3 then
hideRowSecond(row)
return
end
local top=-A.metric("rowHeight")
local function place(region,lane,text)
region:ClearAllPoints()
region:SetPoint("TOPLEFT",row,"TOPLEFT",lane.at,top)
region:SetWidth(lane.width)
region:SetHeight(A.metric("rowSubLine"))
region:SetText(text)
region:Show()
end
A.style(row.clock,"rowClock","dimmer")
A.style(row.spec,"rowNote","dim")
A.style(row.lobbyNote,"rowNote","dimmer")
A.style(row.lobbyAgainst,"rowNote","dimmer")
if type(second.clock)=="string"and second.clock~=""then
place(row.clock,lanes[1],second.clock)
else
row.clock:Hide()
end
if type(second.spec)=="string"and second.spec~=""then
place(row.spec,lanes[2],second.spec)
else
row.spec:Hide()
end
local lobby=second.lobby
local third=lanes[3]
local room=nil
local okWidth,rowWidth=pcall(row.GetWidth,row)
if okWidth and type(rowWidth)=="number"and rowWidth>0 then
room=rowWidth-(type(trail)=="number"and trail or 0)
-A.metric("rowLabelPad")-third.at
end
if lobby==nil then
row.lobbyNote:Hide()
row.lobbyAgainst:Hide()
for i=1,#row.marks do
row.marks[i]:Hide()
end
return
end
if lobby.kind=="count"or lobby.kind=="place"then
row.lobbyAgainst:Hide()
for i=1,#row.marks do
row.marks[i]:Hide()
end
row.lobbyNote:ClearAllPoints()
row.lobbyNote:SetPoint("TOPLEFT",row,"TOPLEFT",third.at,top)
row.lobbyNote:SetWidth(type(room)=="number"and room>0 and room or third.width)
row.lobbyNote:SetHeight(A.metric("rowSubLine"))
row.lobbyNote:SetText(lobby.text or"")
row.lobbyNote:Show()
return
end
row.lobbyNote:Hide()
local size,gap=A.metric("rowMarkSize"),A.metric("rowMarkGap")
local drop=math.max(0,math.floor((A.metric("rowSubLine")-size)*0.5))
local at=third.at
local shown=0
local worded=false
for i=1,#row.marks do
local mark=type(lobby.marks)=="table"and lobby.marks[i]or nil
if mark==nil or(type(room)=="number"and at+size>third.at+room)then
row.marks[i]:Hide()
else
row.marks[i]:ClearAllPoints()
row.marks[i]:SetPoint("TOPLEFT",row,"TOPLEFT",at,top-drop)
row.marks[i]:SetSize(size,size)
row.marks[i]:SetColorTexture(A.classColor(mark.classToken))
row.marks[i]:Show()
shown=shown+1
at=at+size+gap
end
if lobby.split~=nil and shown==lobby.split and mark~=nil
and type(lobby.word)=="string"and lobby.word~=""then
local word=lobby.word
local need=A.labelRoom(word)
row.lobbyAgainst:ClearAllPoints()
row.lobbyAgainst:SetPoint("TOPLEFT",row,"TOPLEFT",at,top)
row.lobbyAgainst:SetWidth(need)
row.lobbyAgainst:SetHeight(A.metric("rowSubLine"))
row.lobbyAgainst:SetText(word)
row.lobbyAgainst:Show()
worded=true
at=at+need+gap
end
end
if not worded then
row.lobbyAgainst:Hide()
end
end
local function layoutRowBar(row,data,columns,widths,offsets)
if row.barTrack==nil then
return
end
local bars=type(data)=="table"and type(data.cellBar)=="table"and data.cellBar or nil
local index,share=nil,nil
if bars~=nil then
for i=1,#columns do
local held=columns[i].key and bars[columns[i].key]or nil
if type(held)=="number"and widths[i]~=nil and type(offsets[i])=="number"then
index,share=i,held
break
end
end
end
if index==nil then
hideRowBar(row)
return
end
local room=widths[index]-A.metric("rowColRecord")-A.metric("rowCellGap")
if room<=0 then
hideRowBar(row)
return
end
row.barTrack:ClearAllPoints()
row.barTrack:SetPoint("LEFT",row,"LEFT",
offsets[index]+A.metric("rowColRecord")+A.metric("rowCellGap"),0)
row.barTrack:SetSize(room,A.metric("barHeight"))
row.barTrack:SetColorTexture(A.color("field"))
row.barTrack:Show()
local faint=type(data)=="table"and data.faint==true
local win,loss=A.barSplit(room,share)
if win~=nil and win>0 then
row.barWin:SetColorTexture(A.color(faint and"underWin"or"win"))
row.barWin:SetWidth(win)
row.barWin:Show()
else
row.barWin:Hide()
end
if loss~=nil and loss>0 then
row.barLoss:SetColorTexture(A.color(faint and"underLoss"or"loss"))
row.barLoss:SetWidth(loss)
row.barLoss:Show()
else
row.barLoss:Hide()
end
if row.barMid~=nil then
row.barMid:ClearAllPoints()
row.barMid:SetPoint("LEFT",row.barTrack,"LEFT",math.floor(room/2),0)
row.barMid:SetSize(1,A.metric("barHeight")+4)
row.barMid:SetColorTexture(A.color("barMid"))
row.barMid:Show()
end
end
function A.layoutRowIcon(row,data,columns,widths,offsets)
if row.specIcon==nil then
return
end
row.specIcon:Hide()
if type(data)~="table"or(data.specKey==nil and data.askKey==nil)then
return
end
local token=data.classToken or(type(data.row)=="table"and data.row.classToken)or nil
if token==nil then
return
end
local spec=type(data.row)=="table"and data.row.spec or nil
for i=1,#columns do
local key=columns[i].key
if(key=="spec"or key=="name")and type(offsets[i])=="number"and widths[i]~=nil then
local size=A.metric("compSwatch")
local icon=data.specIcon
if icon==nil and spec~=nil and type(A.specIcon)=="function"then
icon=A.specIcon(token,spec)
end
if icon~=nil then
row.specIcon:SetVertexColor(1,1,1,data.faint and 0.4 or 1)
row.specIcon:SetTexture(icon)
else
row.specIcon:SetVertexColor(1,1,1,data.faint and 0.4 or 1)
row.specIcon:SetColorTexture(A.classColor(token))
end
row.specIcon:ClearAllPoints()
row.specIcon:SetPoint("LEFT",row,"LEFT",offsets[i],0)
row.specIcon:SetSize(size,size)
row.specIcon:Show()
local cell=row.cells[i]
if cell~=nil then
local shift=size+A.metric("chipGap")
cell:ClearAllPoints()
cell:SetPoint("TOPLEFT",row,"TOPLEFT",offsets[i]+shift,0)
cell:SetWidth(math.max(1,widths[i]-shift))
end
return
end
end
end
function A.layoutRowTalents(row,data,columns,offsets)
row.talentIcons=row.talentIcons or{}
for i=1,#row.talentIcons do
row.talentIcons[i]:Hide()
end
row.talentIconsShown=0
local held=type(data)=="table"and type(data.row)=="table"and data.row or nil
if held==nil or not held.iconsDrawn or type(held.pvpIcons)~="table"then
return 0
end
for c=1,#columns do
local cell=row.cells[c]
if columns[c].key=="name"and cell~=nil and type(offsets[c])=="number"then
local size,gap=A.metric("rowTalentIcon"),A.metric("rowTalentGap")
local x=offsets[c]+A.textRoom(cell,cell:GetText()or"")
local drop=-math.floor((A.metric("rowHeight")-size)/2)
for i=1,#held.pvpIcons do
local icon=row.talentIcons[i]
if icon==nil then
icon=row:CreateTexture(nil,"ARTWORK")
row.talentIcons[i]=icon
end
x=x+gap
icon:ClearAllPoints()
icon:SetPoint("TOPLEFT",row,"TOPLEFT",x,drop)
icon:SetSize(size,size)
icon:SetTexture(held.pvpIcons[i])
icon:Show()
x=x+size
end
row.talentIconsShown=#held.pvpIcons
return row.talentIconsShown
end
end
return 0
end
function darkList.layoutRow(row,data,columns,widths,offsets,top)
darkList.hideRow(row)
if row.selfChip==nil or type(data)~="table"or not data.flat then
return
end
local height=A.metric("rowListRow")
local size=A.metric("rowChip")
local chipTop=-math.max(0,math.floor((height-size)*0.5))
local function placeChip(held,x,chip)
held.ground:ClearAllPoints()
held.ground:SetPoint("TOPLEFT",row,"TOPLEFT",x,chipTop)
held.ground:SetSize(size,size)
held.ground:SetVertexColor(1,1,1,1)
if chip.icon~=nil then
held.ground:SetTexture(chip.icon)
held.text:SetText("")
held.text:Hide()
else
held.ground:SetColorTexture(A.classColor(chip.classToken))
held.text:ClearAllPoints()
held.text:SetPoint("TOPLEFT",row,"TOPLEFT",x,chipTop)
held.text:SetSize(size,size)
A.style(held.text,"rowClock","panelDeep")
held.text:SetText(chip.text or"")
held.text:Show()
end
held.ground:Show()
end
local function shiftCell(i,shift)
local cell=row.cells[i]
if cell==nil or shift<=0 then
return
end
cell:ClearAllPoints()
cell:SetPoint("TOPLEFT",row,"TOPLEFT",offsets[i]+shift,top)
cell:SetWidth(math.max(1,widths[i]-shift))
end
for i=1,#columns do
local key=columns[i].key
local x,width=offsets[i],widths[i]
if type(x)=="number"and type(width)=="number"then
if key=="chip"and type(data.selfChip)=="table"then
placeChip(row.selfChip,x+A.metric("rowLeadInset"),data.selfChip)
elseif(key=="lobby"or key=="against")and type(data.chips)=="table"
and type(data.chips.chips)=="table"then
local at,gap=x,A.metric("rowChipGap")
for n=1,#row.chips do
local chip=data.chips.chips[n]
if chip~=nil and at+size<=x+width then
placeChip(row.chips[n],at,chip)
at=at+size+gap
end
end
elseif key=="rounds"and type(data.rounds)=="table"then
local pip,gap=A.metric("rowPip"),A.metric("rowPipGap")
local pipTop=-math.max(0,math.floor((height-pip)*0.5))
local played=math.min(data.rounds.played or 0,#row.pips)
for n=1,played do
local mark=row.pips[n]
mark:ClearAllPoints()
mark:SetPoint("TOPLEFT",row,"TOPLEFT",x+(n-1)*(pip+gap),pipTop)
mark:SetSize(pip,pip)
mark:SetColorTexture(A.color(n<=(data.rounds.won or 0)and"win"or"faint"))
mark:Show()
end
if played>0 then
shiftCell(i,played*(pip+gap)+A.metric("rowCellGap"))
end
elseif key=="tally"and type(data.tally)=="table"and row.kdMarks~=nil then
local used=darkList.placeMarks(row,row.kdMarks,x,height,data.tally.kills,data.tally.deaths)
if used>0 then
shiftCell(i,used+A.metric("rowCellGap"))
end
elseif key=="result"and data.crest~=nil and row.crest~=nil
and type(A.factionCrest)=="function"then
local atlas=A.factionCrest(data.crest)
local crest=math.min(A.fontSize("heading"),width)
if atlas~=nil and crest>0 then
row.crest:ClearAllPoints()
row.crest:SetPoint("TOPLEFT",row,"TOPLEFT",x,
-math.max(0,math.floor((height-crest)*0.5)))
row.crest:SetAtlas(atlas,false)
row.crest:SetSize(crest,crest)
row.crest:Show()
shiftCell(i,crest+A.metric("headCrestGap"))
end
elseif key=="change"and type(data.change)=="number"then
local half=A.metric("rowChangeHalf")
local bar=A.metric("rowChangeBar")
local barTop=-math.max(0,math.floor((height-bar)*0.5))
local axisX=x+half
row.changeAxis:ClearAllPoints()
row.changeAxis:SetPoint("TOPLEFT",row,"TOPLEFT",axisX,-math.floor(height*0.25))
row.changeAxis:SetSize(1,math.floor(height*0.5))
row.changeAxis:SetColorTexture(A.color("hairline"))
row.changeAxis:Show()
local scale=type(data.changeScale)=="number"and data.changeScale>0 and data.changeScale
or math.abs(data.change)
local reach=(data.change~=0 and scale>0)
and math.max(1,math.floor(half*math.abs(data.change)/scale+0.5))or 0
reach=math.min(reach,half)
if reach>0 then
row.changeBar:ClearAllPoints()
row.changeBar:SetPoint("TOPLEFT",row,"TOPLEFT",
data.change<0 and(axisX-reach)or(axisX+1),barTop)
row.changeBar:SetSize(reach,bar)
row.changeBar:SetColorTexture(A.color(data.change<0 and"loss"or"win"))
row.changeBar:Show()
end
shiftCell(i,half*2+A.metric("rowCellGap"))
end
end
end
darkList.layoutExtras(row,data,columns,widths,offsets)
end
function darkList.markPool(owner)
local pool={}
for i=1,A.kdMarkCap()*2 do
local mark=owner:CreateTexture(nil,"ARTWORK")
mark:Hide()
pool[i]=mark
end
return pool
end
function darkList.placeMarks(owner,pool,x,height,kills,deaths)
for i=1,#pool do
pool[i]:Hide()
end
local killMarks,deathMarks=A.kdMarks(kills,deaths)
local mark,gap,tall=A.metric("kdMark"),A.metric("kdMarkGap"),A.metric("kdMarkHeight")
local top=-math.max(0,math.floor((height-tall)*0.5))
local n,at=0,x
for _,run in ipairs({{killMarks,"win"},{deathMarks,"loss"}})do
for _=1,run[1]do
n=n+1
local texture=pool[n]
if texture~=nil then
texture:ClearAllPoints()
texture:SetPoint("TOPLEFT",owner,"TOPLEFT",at,top)
texture:SetSize(mark,tall)
texture:SetColorTexture(A.color(run[2]))
texture:Show()
at=at+mark+gap
end
end
end
return n>0 and(at-x-gap)or 0,n
end
function darkList.hideGrid(row)
local grid=row.grid
if grid==nil then
return
end
row.dayName:SetWidth(0)
row.gridTicksShown,row.gridTicksHidden=nil,nil
for i=1,#grid.cells do
grid.cells[i]:Hide()
grid.dots[i]:Hide()
grid.hovers[i]:Hide()
grid.hovers[i].lines=nil
end
for i=1,#grid.ticks do
grid.ticks[i]:Hide()
end
grid.more:Hide()
grid.summary:Hide()
grid.summaryHover:Hide()
grid.summaryHover.lines=nil
grid.ratio:Hide()
for i=1,#grid.kdMarks do
grid.kdMarks[i]:Hide()
end
end
function darkList.gridEnter(self)
local lines=self.lines
if not GameTooltip or type(lines)~="table"or#lines==0 then
return
end
local drew=pcall(function()
GameTooltip:SetOwner(self,"ANCHOR_RIGHT")
local r,g,b=A.color("text")
GameTooltip:SetText(lines[1],r,g,b,1,false)
for i=2,#lines do
GameTooltip:AddLine(lines[i],r,g,b,false)
end
GameTooltip:Show()
end)
if not drew or type(A.trace)~="function"then
return
end
darkList.gridHoverN=darkList.gridHoverN+1
if darkList.gridHoverN>darkList.GRIDHOVER_TRACES then
return
end
A.trace("gridhover",{
line=lines[1],lines=#lines,format=self.format,n=darkList.gridHoverN,
capped=darkList.gridHoverN==darkList.GRIDHOVER_TRACES or nil,
},"ui")
end
function darkList.gridLeave(self)
if GameTooltip and GameTooltip.GetOwner and GameTooltip:GetOwner()==self then
GameTooltip:Hide()
end
end
function darkList.gridParts(row)
if row.grid~=nil then
return row.grid
end
local tickCap,columnCap=A.sessionGridCaps()
local grid={cells={},dots={},hovers={},ticks={}}
local function hoverFrame()
local hover=CreateFrame("Frame",nil,row)
hover:EnableMouse(true)
if hover.SetMouseClickEnabled then
hover:SetMouseClickEnabled(false)
end
hover:SetScript("OnEnter",darkList.gridEnter)
hover:SetScript("OnLeave",darkList.gridLeave)
hover:Hide()
return hover
end
for i=1,columnCap do
local cell=row:CreateFontString(nil,"ARTWORK","GameFontHighlightSmall")
cell:SetJustifyH("LEFT")
cell:SetWordWrap(false)
grid.cells[i]=cell
grid.dots[i]=row:CreateTexture(nil,"ARTWORK")
grid.hovers[i]=hoverFrame()
end
for i=1,tickCap do
grid.ticks[i]=row:CreateTexture(nil,"ARTWORK")
end
grid.more=row:CreateFontString(nil,"ARTWORK","GameFontHighlightSmall")
grid.more:SetJustifyH("LEFT")
grid.more:SetWordWrap(false)
grid.summary=row:CreateFontString(nil,"ARTWORK","GameFontHighlightSmall")
grid.summary:SetJustifyH("LEFT")
grid.summary:SetWordWrap(false)
grid.summaryHover=hoverFrame()
grid.ratio=row:CreateFontString(nil,"ARTWORK","GameFontHighlightSmall")
grid.ratio:SetJustifyH("RIGHT")
grid.ratio:SetWordWrap(false)
grid.kdMarks=darkList.markPool(row)
row.grid=grid
return grid
end
local function shownNameColor(names)
if type(names)~="table"then
return nil
end
for i=1,#names do
local name=names[i]
if name and name:IsShown()and name.GetTextColor then
local ok,r,g,b,a=pcall(name.GetTextColor,name)
if ok and type(r)=="number"then
return A.colorHex(r,g,b,a)
end
end
end
return nil
end
function darkList.traceSessions(frame)
local entry=darkList.sessionsEntry
darkList.sessionsEntry=nil
if type(entry)~="table"or not frame then
return
end
if frame.listHead and frame.listHead:IsShown()then
entry.headColor=shownNameColor(frame.listHeadNames)
end
local drawn={}
local box=frame.list and frame.list.box
if box then
pcall(box.ForEachFrame,box,function(element)
local okI,index=pcall(element.GetElementDataIndex,element)
local okD,data=pcall(element.GetElementData,element)
if okI and type(index)=="number"and okD and type(data)=="table"and data.names
and element:IsShown()then
drawn[#drawn+1]={index=index,cells=element.cells}
end
end)
end
table.sort(drawn,function(a,b)
return a.index<b.index
end)
for i=1,#drawn do
entry.namesColor=shownNameColor(drawn[i].cells)
if entry.namesColor~=nil then
break
end
end
local pin=frame.list and frame.list.pin
if entry.namesColor==nil and pin and pin:IsShown()and pin.names and pin.names:IsShown()then
entry.namesColor=shownNameColor(pin.names.cells)
end
A.trace("sessions",{
format=entry.format,
gap=entry.gap,
n=entry.n,
shape=entry.shape,
unplaced=entry.unplaced,
gridOpen=entry.gridOpen,
roundsLeft=entry.roundsLeft,
roundsPartial=entry.roundsPartial,
foldList=entry.foldList,
heads=entry.heads,
listHead=entry.listHead,
namesRows=entry.namesRows,
headColor=entry.headColor,
namesColor=entry.namesColor,
grid=entry.grid,
gridFold=entry.gridFold,
},"ui")
end
function A.askCardLines()
local out={}
local cards=window and window.askCards or{}
for i=1,#cards do
local card=cards[i]
if card:IsShown()then
local title=card.title and card.title:GetText()or tostring(card.askKey)
if card.overGap~=nil then
out[#out+1]=("ask card %s  caption %s, %s clear of the figure over it, off the %s")
:format(tostring(title),tostring(card.overDrawn),tostring(card.overGap),
tostring(card.overGapFrom))
else
out[#out+1]=("ask card %s  caption %s, no gap to state"):format(tostring(title),
tostring(card.overDrawn or"not asked"))
end
end
end
if#out==0 then
out[1]="ask cards  none on screen"
end
return out
end
function darkList.placeHeadMore(frame,gridHead,widths)
local hover=frame.listHeadMore
if hover==nil then
return
end
hover:Hide()
hover.lines=nil
if type(gridHead.rest)~="table"or#gridHead.rest==0 or type(widths)~="table"then
return
end
local x=A.metric("rowLabelPad")
for i,column in ipairs(gridHead.columns)do
if column.key=="more"then
local lines={}
for _,format in ipairs(gridHead.rest)do
lines[#lines+1]=A.sessionGridName(format)
end
hover.lines=lines
hover.format="more"
hover:ClearAllPoints()
hover:SetPoint("TOPLEFT",frame.listHead,"TOPLEFT",x,0)
hover:SetSize(math.max(1,widths[i]or 1),A.metric("rowHeadRow"))
hover:Show()
return
end
x=x+(widths[i]or 0)+A.metric("rowCellGap")
end
end
function darkList.layoutGrid(row,data)
local grid=darkList.gridParts(row)
local columns=data.gridColumns
local height=data.height or A.metric("gridRow")
local pad,gap=A.metric("rowLabelPad"),A.metric("rowCellGap")
local function middle(role)
return-math.max(0,math.floor((height-A.fontSize(role))*0.5))
end
row.dayRule:ClearAllPoints()
row.dayRule:SetPoint("BOTTOMLEFT",row,"BOTTOMLEFT",pad,0)
row.dayRule:SetPoint("BOTTOMRIGHT",row,"BOTTOMRIGHT",-pad,0)
row.dayRule:SetHeight(1)
row.dayRule:SetColorTexture(A.color("gridRule"))
row.dayRule:Show()
A.style(row.sessionCaret,"label","dim")
A.style(row.dayName,"label","accent")
A.style(row.sessionSpan,"rowClock","dim")
A.style(row.dayCount,"rowClock","text")
local labelTop=middle("label")
local spanTop=middle("rowClock")
if data.fold then
local block=A.fontSize("label")+math.floor(A.metric("rowExpandPad")*0.5)+A.fontSize("rowClock")
labelTop=-math.max(0,math.floor((height-block)*0.5))
spanTop=labelTop-A.fontSize("label")-math.floor(A.metric("rowExpandPad")*0.5)
end
local x,slot=pad,0
for _,column in ipairs(type(columns)=="table"and columns or{})do
local width=column.width or 0
if column.key=="session"then
row.sessionCaret:ClearAllPoints()
row.sessionCaret:SetPoint("TOPLEFT",row,"TOPLEFT",x,labelTop)
row.sessionCaret:SetText(data.open and"-"or"+")
row.sessionCaret:Show()
local caretW=A.clientTextWidth(row.sessionCaret,"+")or A.fontSize("label")
local room=width-caretW-gap
row.dayName:ClearAllPoints()
row.dayName:SetPoint("TOPLEFT",row,"TOPLEFT",x+caretW+gap,labelTop)
row.dayName:SetWidth(math.max(1,room))
local forms=type(data.textForms)=="table"and data.textForms or{data.text or""}
row.dayName:SetText(A.fittedForm(row.dayName,room,forms)or forms[#forms]or"")
row.dayName:Show()
if data.fold then
row.sessionSpan:ClearAllPoints()
row.sessionSpan:SetPoint("TOPLEFT",row,"TOPLEFT",x+caretW+gap,spanTop)
row.sessionSpan:SetText(data.span or"")
row.sessionSpan:SetShown(data.span~=nil)
end
elseif column.key=="time"then
row.sessionSpan:ClearAllPoints()
row.sessionSpan:SetPoint("TOPLEFT",row,"TOPLEFT",x,middle("rowClock"))
row.sessionSpan:SetText(data.span or"")
row.sessionSpan:SetShown(data.span~=nil)
elseif column.key=="format"or column.key=="more"then
slot=slot+1
local cell,dot,hover=grid.cells[slot],grid.dots[slot],grid.hovers[slot]
local figure=data.gridCells and data.gridCells[slot]or nil
if cell~=nil then
A.style(cell,"numberSmall","text")
cell:ClearAllPoints()
cell:SetPoint("TOPLEFT",row,"TOPLEFT",x,middle("numberSmall"))
cell:SetWidth(math.max(1,width))
local text=figure and figure.text or nil
cell:SetText(text or"")
cell:SetShown(text~=nil)
if text==nil then
local side=A.metric("gridDot")
dot:ClearAllPoints()
dot:SetPoint("TOPLEFT",row,"TOPLEFT",x+math.floor((width-side)*0.5),
-math.floor((height-side)*0.5))
dot:SetSize(side,side)
dot:SetColorTexture(A.color("dim"))
dot:Show()
end
hover.lines=figure and figure.lines or nil
hover.format=column.format or"more"
hover:ClearAllPoints()
hover:SetPoint("TOPLEFT",row,"TOPLEFT",x,0)
hover:SetSize(math.max(1,width),height)
hover:SetShown(hover.lines~=nil)
end
elseif column.key=="results"then
local tones,over=data.ticks or{},data.ticksOver or 0
local tick,tickGap,tickH=A.metric("gridTick"),A.metric("gridTickGap"),A.metric("gridTickHeight")
local step=tick+tickGap
local fit=math.max(0,math.floor((width+tickGap)/step))
local shown=#tones
if over>0 or shown>fit then
A.style(grid.more,"rowClock","dim")
local moreW=A.clientTextWidth(grid.more,("+%d"):format(over+shown))or(A.fontSize("rowClock")*2)
fit=math.max(0,math.floor((width-moreW-gap+tickGap)/step))
shown=math.min(shown,fit)
end
local first=#tones-shown
local tickTop=-math.floor((height-tickH)*0.5)
for n=1,shown do
local mark=grid.ticks[n]
mark:ClearAllPoints()
mark:SetPoint("TOPLEFT",row,"TOPLEFT",x+(n-1)*step,tickTop)
mark:SetSize(tick,tickH)
mark:SetColorTexture(A.color(tones[first+n]))
mark:Show()
end
local hidden=over+first
if hidden>0 then
A.style(grid.more,"rowClock","dim")
grid.more:ClearAllPoints()
grid.more:SetPoint("TOPLEFT",row,"TOPLEFT",x+shown*step+gap-tickGap,middle("rowClock"))
grid.more:SetText(("+%d"):format(hidden))
grid.more:Show()
end
row.gridTicksShown,row.gridTicksHidden=shown,hidden
elseif column.key=="summary"then
A.style(grid.summary,"numberSmall","text")
grid.summary:ClearAllPoints()
grid.summary:SetPoint("TOPLEFT",row,"TOPLEFT",x,middle("numberSmall"))
grid.summary:SetWidth(math.max(1,width))
grid.summary:SetText(data.gridSummary or"")
grid.summary:SetShown(data.gridSummary~=nil)
local hover=grid.summaryHover
hover.lines=data.gridSummaryLines
hover.format="summary"
hover:ClearAllPoints()
hover:SetPoint("TOPLEFT",row,"TOPLEFT",x,0)
hover:SetSize(math.max(1,width),height)
hover:SetShown(hover.lines~=nil)
elseif column.key=="tally"then
local held=type(data.tally)=="table"and data.tally or nil
local used,drew=0,0
if held then
used,drew=darkList.placeMarks(row,grid.kdMarks,x,height,held.kills,held.deaths)
end
A.style(grid.summary,"numberSmall","text")
grid.summary:ClearAllPoints()
grid.summary:SetPoint("TOPLEFT",row,"TOPLEFT",x+(used>0 and used+gap or 0),middle("numberSmall"))
grid.summary:SetWidth(math.max(1,width-(used>0 and used+gap or 0)))
grid.summary:SetText(A.kdPairText(held and held.kills,held and held.deaths))
grid.summary:Show()
row.gridMarks=drew
elseif column.key=="ratio"then
local held=type(data.tally)=="table"and data.tally or nil
A.style(grid.ratio,"numberSmall",A.kdTone(held and held.kills,held and held.deaths))
grid.ratio:ClearAllPoints()
grid.ratio:SetPoint("TOPLEFT",row,"TOPLEFT",x,middle("numberSmall"))
grid.ratio:SetWidth(math.max(1,width))
grid.ratio:SetText(A.kdText(held and held.kills,held and held.deaths)or"-")
grid.ratio:Show()
elseif column.key=="matches"then
row.dayCount:ClearAllPoints()
row.dayCount:SetPoint("TOPRIGHT",row,"TOPLEFT",x+width,middle("rowClock"))
row.dayCount:SetJustifyH("RIGHT")
row.dayCount:SetText(data.count or"")
row.dayCount:Show()
end
x=x+width+gap
end
end
function darkList.layoutExtras(row,data,columns,widths,offsets)
local height=A.metric("rowListRow")
local line=A.fontSize("bodyText")+2
local subs=type(data.cellSubs)=="table"and data.cellSubs or nil
for i=1,#columns do
local key=columns[i].key
local x,width=offsets[i],widths[i]
local text=subs and key and subs[key]or nil
if type(x)=="number"and type(width)=="number"and type(text)=="string"and text~=""then
local cell=row.cells[i]
local top=-math.max(0,math.floor((height-line*2)*0.5))
if cell~=nil then
cell:ClearAllPoints()
cell:SetPoint("TOPLEFT",row,"TOPLEFT",x,top)
cell:SetHeight(line)
cell:SetWidth(width)
end
row.cellSubs=row.cellSubs or{}
local sub=row.cellSubs[key]
if sub==nil then
sub=row:CreateFontString(nil,"ARTWORK","GameFontDisableSmall")
sub:SetWordWrap(false)
row.cellSubs[key]=sub
end
A.style(sub,"rowNote","dim")
sub:SetJustifyH(columns[i].align=="RIGHT"and"RIGHT"or"LEFT")
sub:ClearAllPoints()
sub:SetPoint("TOPLEFT",row,"TOPLEFT",x,top-line)
sub:SetSize(width,line)
sub:SetText(text)
sub:Show()
elseif key=="why"and type(data.reasonMenu)=="table"and type(x)=="number"
and type(width)=="number"then
if row.reasonMenu==nil then
row.reasonMenu=A.pill(row,"Set a reason",nil,A.metric("resultMin"))
row.reasonMenu:SetScript("OnClick",function(self)
A.openReasonMenu(self,self.entryId,"click")
end)
end
local menu=row.reasonMenu
menu.entryId=data.reasonMenu.id
menu:SetText(data.reasonMenu.label or"Set a reason")
A.fitControl(menu,A.metric("resultMin"))
A.setPillSelected(menu,data.reasonMenu.label~=nil)
menu:ClearAllPoints()
menu:SetPoint("RIGHT",row,"TOPLEFT",x+width,-math.floor(height*0.5))
menu:Show()
end
end
end
local function layoutRowCells(row,data,columns,trail)
local cells=type(data)=="table"and data.cells or nil
local widths=columnWidths(columns)
local spans,swallowed=nil,nil
if type(data)=="table"and type(data.spans)=="table"then
spans,swallowed={},{}
for i=1,#columns do
local wide=columns[i].key and data.spans[columns[i].key]or nil
if type(wide)=="number"and wide>1 then
for n=i+1,math.min(i+wide-1,#columns)do
swallowed[n]=true
end
spans[i]=wide
end
end
end
local offsets={}
local top=0
if type(data)=="table"and data.flat then
top=-math.max(0,math.floor((A.metric("rowListRow")-A.metric("rowHeight"))*0.5))
end
local at=A.metric("rowLabelPad")
for i=1,#row.cells do
local cell=row.cells[i]
offsets[i]=at
if widths[i]==nil or(swallowed and swallowed[i])then
cell:Hide()
if widths[i]~=nil then
at=at+widths[i]+A.metric("rowCellGap")
end
else
local room=widths[i]
local reach=spans and spans[i]or 1
for n=i+1,math.min(i+reach-1,#columns)do
room=room+widths[n]+A.metric("rowCellGap")
end
cell:ClearAllPoints()
cell:SetPoint("TOPLEFT",row,"TOPLEFT",at,top)
cell:SetHeight(A.metric("rowHeight"))
cell:SetWidth(room)
cell:SetJustifyH(columns[i].align=="RIGHT"and"RIGHT"or"LEFT")
local role,tone="bodyText","text"
local styled=type(data)=="table"and type(data.cellStyle)=="table"
and columns[i].key and data.cellStyle[columns[i].key]or nil
if type(styled)=="table"then
role=styled.role or role
tone=styled.tone or tone
end
A.style(cell,role,tone)
local tint=type(data)=="table"and type(data.cellTint)=="table"
and columns[i].key and data.cellTint[columns[i].key]or nil
if type(tint)=="table"and type(tint[1])=="number"and cell.SetTextColor then
cell:SetTextColor(tint[1],tint[2],tint[3],tint[4]or 1)
end
cell:SetText(tostring(cells and cells[i]or"-"))
cell:Show()
at=at+widths[i]+A.metric("rowCellGap")
end
end
layoutRowBar(row,data,columns,widths,offsets)
A.layoutRowIcon(row,data,columns,widths,offsets)
A.layoutRowTalents(row,data,columns,offsets)
layoutRowCrest(row,data,columns,widths,offsets)
layoutRowSecond(row,data,columns,widths,offsets,trail)
darkList.layoutRow(row,data,columns,widths,offsets,top)
darkList.layoutKdCell(row,data,columns,widths,offsets,top)
return true
end
function darkList.layoutKdCell(row,data,columns,widths,offsets,top)
row.kdMarksDrawn=nil
if type(data)~="table"or data.flat or type(data.kdCell)~="table"or row.kdMarks==nil then
return
end
for i=1,#columns do
local x,width=offsets[i],widths[i]
if columns[i].key=="tally"and type(x)=="number"and type(width)=="number"then
local used,drew=darkList.placeMarks(row,row.kdMarks,x,A.metric("rowHeight"),
data.kdCell.kills,data.kdCell.deaths)
row.kdMarksDrawn=drew
local cell=row.cells[i]
if used>0 and cell~=nil then
local shift=used+A.metric("rowCellGap")
cell:ClearAllPoints()
cell:SetPoint("TOPLEFT",row,"TOPLEFT",x+shift,top)
cell:SetWidth(math.max(1,width-shift))
end
end
end
end
local paintLineFace
local rowSurface={TOOLTIP_TRACES=20,tooltipShown=0,tooltipOn=nil,WHEEL_TRACES=30,wheelN=0}
rowSurface.metRowPaint,rowSurface.metRowTraced=0,nil
function rowSurface.traceWheel(scroller,fields)
if type(A.trace)~="function"or scroller~=(window and window.list)then
return
end
if fields.snapTo==nil then
rowSurface.wheelN=rowSurface.wheelN+1
end
if rowSurface.wheelN>rowSurface.WHEEL_TRACES then
return
end
A.trace("wheel",{
delta=fields.delta,offset=fields.offset,target=fields.target,landed=fields.landed,
first=fields.first,firstAfter=fields.firstAfter,content=fields.content,extent=fields.extent,
range=fields.range,snapTo=fields.snapTo,wheelN=rowSurface.wheelN,
capped=rowSurface.wheelN==rowSurface.WHEEL_TRACES or nil,
},"ui")
end
function rowSurface.traceMenu(id,key,state,reason,via,count)
if type(A.trace)~="function"then
return
end
A.trace("row-menu",{id=id,source=key,state=state,reason=reason,via=via,n=count},"ui")
end
function A.rowMenuOpen(id,via)
local outcome="refused"
if type(A.showMatchWindow)=="function"then
local _,got=A.showMatchWindow("match",id,"row-menu")
outcome=got or"refused"
end
rowSurface.traceMenu(id,"open",outcome,nil,via)
return outcome
end
function A.rowMenuNote(id,via)
local frame
if type(A.raiseMatchWindow)=="function"then
frame=A.raiseMatchWindow("match",id,"row-menu")
end
local focused=frame~=nil and frame.editNote~=nil and pcall(function()
frame.editNote:SetFocus()
frame.editNote:SetCursorPosition(frame.editNote:GetNumLetters()or 0)
end)
local outcome=focused and"focused"or"refused"
rowSurface.traceMenu(id,"note",outcome,nil,via)
return outcome
end
function A.rowMenuRoster(id,via)
local opened=type(A.showNotesForMatch)=="function"and A.showNotesForMatch(id)==true
if not opened then
A.say("that match's roster could not be opened. /pvph notes #<id> scopes the players "
.."window to one match and /pvph notes opens the whole index")
end
local outcome=opened and"opened"or"refused"
rowSurface.traceMenu(id,"roster",outcome,nil,via)
return outcome
end
function A.rowMenuPrint(id,via)
local handler=type(SlashCmdList)=="table"and SlashCmdList.WOWPVPHISTORY or nil
local printed=type(handler)=="function"and pcall(handler,A.matchIdText(id))
local outcome=printed and"printed"or"refused"
rowSurface.traceMenu(id,"print",outcome,nil,via)
return outcome
end
function A.rowMenuResult(id,value,via)
local record=A.match(id)
if not record then
rowSurface.traceMenu(id,"result","refused","no-record",via)
return"refused","no-record"
end
if not A.carriesResult(record)then
A.say(("match %s is a %s record, which carries no result. Nothing written")
:format(A.matchIdText(id),A.formatLabel(record.format)))
rowSurface.traceMenu(id,"result","refused","no-result",via)
return"refused","no-result"
end
if not A.resultOfferable(record)then
A.say(("match %s already carries result %s, which the capture recorded. Nothing written")
:format(A.matchIdText(id),tostring(A.capturedResultText(record))))
rowSurface.traceMenu(id,"result","refused","captured",via)
return"refused","captured"
end
local stored,_,why=A.editResult(record,value)
if not stored then
A.say(why=="bad-result"
and("%q is not a result. win, loss or draw"):format(tostring(value))
or"that result could not be written")
rowSurface.traceMenu(id,"result","refused",why or"unwritten",via)
return"refused",why or"unwritten"
end
if type(repaintEverything)=="function"then
repaintEverything()
end
rowSurface.traceMenu(id,"result","stored",nil,via)
return"stored",nil
end
function A.rowMenuTalents(id,via)
local copied=type(A.copyTalents)=="function"and A.copyTalents(id)==true
local outcome=copied and"copied"or"refused"
rowSurface.traceMenu(id,"talents",outcome,nil,via)
return outcome
end
rowSurface.run={
open=A.rowMenuOpen,
note=A.rowMenuNote,
roster=A.rowMenuRoster,
print=A.rowMenuPrint,
talents=A.rowMenuTalents,
}
function A.runRowMenuEntry(key,id,choice,via)
local record=A.match(id)
if not record then
rowSurface.traceMenu(id,tostring(key),"refused","no-record",via)
return"refused","no-record"
end
if key=="result"then
return A.rowMenuResult(id,choice,via)
end
local offered,why=A.matchMenuOffers(record,key,"match")
if not offered or type(rowSurface.run[key])~="function"then
rowSurface.traceMenu(id,tostring(key),"refused",why or"not-offered",via)
return"refused",why or"not-offered"
end
return rowSurface.run[key](id,via)
end
function rowSurface.menuOwner(region)
if not region then
return nil
end
local ok,visible=pcall(region.IsVisible,region)
if not ok or not visible then
return nil
end
return region
end
function rowSurface.openMenu(owner,id,via)
local record=A.match(id)
local entries=record and A.matchMenuEntries(record,"match")or{}
if#entries==0 then
rowSurface.traceMenu(id,"menu","refused","no-entries",via,0)
return false
end
if type(MenuUtil)~="table"or type(MenuUtil.CreateContextMenu)~="function"then
rowSurface.traceMenu(id,"menu","refused","no-menu",via,#entries)
return false
end
local ok,menu=pcall(MenuUtil.CreateContextMenu,rowSurface.menuOwner(owner),function(_,root)
root:CreateTitle(A.matchWindowTitle(record,"match"))
for i=1,#entries do
local entry=entries[i]
if type(entry.choices)=="table"then
local sub=root:CreateButton(entry.label)
for c=1,#entry.choices do
local choice=entry.choices[c]
sub:CreateButton(choice,function()
A.runRowMenuEntry(entry.key,id,choice,"click")
end)
end
else
root:CreateButton(entry.label,function()
A.runRowMenuEntry(entry.key,id,nil,"click")
end)
end
end
end)
local opened=ok and menu~=nil
rowSurface.traceMenu(id,"menu",opened and"opened"or"refused",opened and nil or(ok and"closed"or"threw"),
via,#entries)
return opened
end
function rowSurface.drawnRow(id)
local box=window and window.list and window.list.box or nil
if not box or type(box.ForEachFrame)~="function"then
return nil
end
local found=nil
pcall(box.ForEachFrame,box,function(element)
if found==nil and type(element)=="table"and element.matchId==id
and element.entryKind=="match"and not element.isSeparator then
local okShown,shown=pcall(element.IsShown,element)
if okShown and shown then
found=element
end
end
end)
return found
end
function A.openRowMenuFor(id,via)
local row=rowSurface.drawnRow(id)
local owner=row or(window and window.listHost)or nil
return rowSurface.openMenu(owner,id,via or"word"),row~=nil
end
function rowSurface.shiftHeld()
local ok,down=pcall(function()
return IsShiftKeyDown()
end)
return ok and down==true
end
function rowSurface.paintTooltip(owner,record,via)
if not GameTooltip or type(A.matchTooltipLines)~="function"then
return nil
end
local lines,kinds=A.matchTooltipLines(record)
if type(lines)~="table"or#lines==0 then
return nil
end
local drew=pcall(function()
GameTooltip:SetOwner(owner,"ANCHOR_RIGHT")
for i=1,#lines do
local r,g,b=A.color(lines[i].tone or"text")
if i==1 then
GameTooltip:SetText(lines[i].text,r,g,b,1,false)
else
GameTooltip:AddLine(lines[i].text,r,g,b,false)
end
end
GameTooltip:Show()
end)
if not drew then
return nil
end
rowSurface.tooltipShown=rowSurface.tooltipShown+1
if type(A.trace)=="function"and(via=="word"or rowSurface.tooltipShown<=rowSurface.TOOLTIP_TRACES)then
local drawn={}
for _,kind in ipairs({"objectives","roster","rounds"})do
if(kinds[kind]or 0)>0 then
drawn[#drawn+1]=kind
end
end
A.trace("row-tooltip",{
id=record.id,
via=via,
kind=table.concat(drawn,"+"),
lines=#lines,
rows=kinds.roster,
rounds=kinds.rounds,
objectiveRows=kinds.objectives,
n=rowSurface.tooltipShown,
capped=(via~="word"and rowSurface.tooltipShown==rowSurface.TOOLTIP_TRACES)or nil,
},"ui")
end
return lines
end
function A.hideRowTooltip()
rowSurface.tooltipOn=nil
if type(A.hideTooltip)=="function"then
A.hideTooltip()
end
end
function rowSurface.updateTooltip(row)
local record=nil
if rowSurface.shiftHeld()and not row.isSeparator and row.entryKind=="match"and row.matchId~=nil then
record=row.matchRecord or A.match(row.matchId)
end
if record then
if rowSurface.tooltipOn~=row then
if rowSurface.paintTooltip(row,record,"row")then
rowSurface.tooltipOn=row
end
end
return
end
if rowSurface.tooltipOn==row then
A.hideRowTooltip()
end
end
function A.showRowTooltipFor(id)
local record=A.match(id)
if not record then
return"refused","no-record"
end
local row=rowSurface.drawnRow(id)
if not row then
return"refused","not-drawn"
end
local lines=rowSurface.paintTooltip(row,record,"word")
if not lines then
return"refused","no-lines"
end
rowSurface.tooltipOn=row
return"shown",#lines
end
function A.windowDropdown(which)
if window==nil then
return nil
end
if which=="character"then
return window.character
elseif which=="scope"then
if activeBody=="history"and window.filterScope then
return window.filterScope
end
return window.summary and window.summary.scope or nil
elseif which=="result"then
return window.filterResult
elseif which=="spec"then
return window.filterSpec
end
return nil
end
function A.openWindowDropdown(which)
if which~="character"and which~="scope"and which~="result"and which~="spec"then
return"refused","unknown"
end
if window==nil or not window:IsShown()then
return"refused","closed"
end
local button=A.windowDropdown(which)
if type(button)~="table"or type(button.openDropdown)~="function"or not button.panel then
return"refused","not-drawn"
end
button.openDropdown()
if not button.panel:IsVisible()then
button.closeDropdown()
return"refused","not-drawn"
end
local drawn=0
for i=1,#(button.rows or{})do
if button.rows[i]:IsShown()then
drawn=drawn+1
end
end
return"opened",drawn
end
function A.closeWindowDropdowns()
local closed=0
for _,which in ipairs({"character","scope","result","spec"})do
local button=A.windowDropdown(which)
if type(button)=="table"and button.panel and button.panel:IsShown()
and type(button.closeDropdown)=="function"then
button.closeDropdown()
closed=closed+1
end
end
return closed
end
function A.showTileTooltipFor(label)
if window==nil or not window:IsShown()then
return"refused","closed"
end
local tiles=window.summary and window.summary.tiles or{}
for i=1,#tiles do
local tile=tiles[i]
local text=tile.label and tile.label:GetText()or nil
if text==label and tile:IsVisible()then
if type(tile.tooltipLines)~="table"or type(tile.showTooltip)~="function"then
return"refused","no-hover"
end
if not tile.showTooltip(tile)then
return"refused","no-hover"
end
return"shown",#tile.tooltipLines
end
end
return"refused","not-drawn"
end
local ROW_TABLES={
list={span="listTableSpan"},
pane={span="compPaneSpan"},
ask={span="askTableSpan"},
askband={span="askBandSpan"},
}
local function buildMatchRowRegions(row)
row.cells={}
for i=1,darkList.ROW_CELL_SLOTS do
local cell=row:CreateFontString(nil,"ARTWORK","GameFontHighlightSmall")
cell:SetJustifyH("LEFT")
cell:SetWordWrap(false)
cell:Hide()
row.cells[i]=cell
end
row.barTrack=row:CreateTexture(nil,"ARTWORK")
row.barTrack:Hide()
row.barWin=row:CreateTexture(nil,"OVERLAY")
row.barWin:SetPoint("TOPLEFT",row.barTrack,"TOPLEFT",0,0)
row.barWin:SetPoint("BOTTOMLEFT",row.barTrack,"BOTTOMLEFT",0,0)
row.barWin:Hide()
row.barLoss=row:CreateTexture(nil,"OVERLAY")
row.barLoss:SetPoint("TOPRIGHT",row.barTrack,"TOPRIGHT",0,0)
row.barLoss:SetPoint("BOTTOMRIGHT",row.barTrack,"BOTTOMRIGHT",0,0)
row.barLoss:Hide()
row.barMid=row:CreateTexture(nil,"OVERLAY",nil,2)
row.barMid:Hide()
row.specIcon=row:CreateTexture(nil,"ARTWORK")
row.specIcon:Hide()
row.crest=row:CreateTexture(nil,"ARTWORK")
row.crest:Hide()
row.rule=row:CreateTexture(nil,"ARTWORK")
row.rule:Hide()
row.clock=row:CreateFontString(nil,"ARTWORK","GameFontDisableSmall")
row.clock:SetJustifyH("LEFT")
row.clock:SetWordWrap(false)
row.clock:Hide()
row.spec=row:CreateFontString(nil,"ARTWORK","GameFontDisableSmall")
row.spec:SetJustifyH("LEFT")
row.spec:SetWordWrap(false)
row.spec:Hide()
row.lobbyNote=row:CreateFontString(nil,"ARTWORK","GameFontDisableSmall")
row.lobbyNote:SetJustifyH("LEFT")
row.lobbyNote:SetWordWrap(false)
row.lobbyNote:Hide()
row.lobbyAgainst=row:CreateFontString(nil,"ARTWORK","GameFontDisableSmall")
row.lobbyAgainst:SetJustifyH("LEFT")
row.lobbyAgainst:SetWordWrap(false)
row.lobbyAgainst:Hide()
row.marks={}
for i=1,darkList.ROW_MARK_SLOTS do
local mark=row:CreateTexture(nil,"ARTWORK")
mark:Hide()
row.marks[i]=mark
end
local function chip()
local ground=row:CreateTexture(nil,"ARTWORK")
ground:Hide()
local text=row:CreateFontString(nil,"OVERLAY","GameFontDisableSmall")
text:SetJustifyH("CENTER")
text:SetWordWrap(false)
text:Hide()
return{ground=ground,text=text}
end
row.selfChip=chip()
row.chips={}
for i=1,A.rowChipLimit()do
row.chips[i]=chip()
end
row.pips={}
for i=1,darkList.PIP_SLOTS do
local pip=row:CreateTexture(nil,"ARTWORK")
pip:Hide()
row.pips[i]=pip
end
row.kdMarks=darkList.markPool(row)
row.changeAxis=row:CreateTexture(nil,"ARTWORK")
row.changeAxis:Hide()
row.changeBar=row:CreateTexture(nil,"OVERLAY")
row.changeBar:Hide()
end
local function initRow(row,data,at)
if not row.built then
row.built=true
row:RegisterForClicks("LeftButtonUp","RightButtonUp")
row.selection=row:CreateTexture(nil,"BACKGROUND")
row.selection:Hide()
row.hover=row:CreateTexture(nil,"HIGHLIGHT")
row:SetScript("OnEnter",function(self)
if not pcall(self.RegisterEvent,self,"MODIFIER_STATE_CHANGED")then
A.noteRefusedEvent("MODIFIER_STATE_CHANGED")
end
rowSurface.updateTooltip(self)
end)
row:SetScript("OnLeave",function(self)
pcall(self.UnregisterEvent,self,"MODIFIER_STATE_CHANGED")
if rowSurface.tooltipOn==self then
A.hideRowTooltip()
end
end)
row:SetScript("OnEvent",function(self,event)
if event=="MODIFIER_STATE_CHANGED"then
rowSurface.updateTooltip(self)
end
end)
row.resultMark=row:CreateTexture(nil,"ARTWORK")
row.resultMark:SetPoint("TOPLEFT",row,"TOPLEFT",0,0)
row.resultMark:SetWidth(A.metric("rowResultMark"))
row.resultMark:SetHeight(A.metric("rowHeight"))
row.resultMark:Hide()
row.label=row:CreateFontString(nil,"ARTWORK","GameFontHighlightSmall")
row.label:SetPoint("TOPLEFT",row,"TOPLEFT",A.metric("rowLabelPad"),0)
row.label:SetPoint("TOPRIGHT",row,"TOPRIGHT",-A.metric("rowLabelPad"),0)
row.label:SetHeight(A.metric("rowHeight"))
row.label:SetJustifyH("LEFT")
row.label:SetWordWrap(false)
buildMatchRowRegions(row)
row.dayRule=row:CreateTexture(nil,"ARTWORK")
row.dayRule:SetPoint("TOPLEFT",row,"TOPLEFT",A.metric("rowLabelPad"),0)
row.dayRule:SetPoint("TOPRIGHT",row,"TOPRIGHT",-A.metric("rowLabelPad"),0)
row.dayRule:SetHeight(1)
row.dayRule:Hide()
row.dayName=row:CreateFontString(nil,"ARTWORK","GameFontDisableSmall")
row.dayName:SetPoint("TOPLEFT",row,"TOPLEFT",A.metric("rowLabelPad"),
-A.metric("rowExpandPad"))
row.dayName:SetJustifyH("LEFT")
row.dayName:SetWordWrap(false)
row.dayName:Hide()
row.dayCount=row:CreateFontString(nil,"ARTWORK","GameFontDisableSmall")
row.dayCount:SetPoint("TOPRIGHT",row,"TOPRIGHT",-A.metric("rowLabelPad"),
-A.metric("rowExpandPad"))
row.dayCount:SetJustifyH("RIGHT")
row.dayCount:SetWordWrap(false)
row.dayCount:Hide()
row.sessionCaret=row:CreateFontString(nil,"ARTWORK","GameFontDisableSmall")
row.sessionCaret:SetJustifyH("LEFT")
row.sessionCaret:SetWordWrap(false)
row.sessionCaret:Hide()
row.sessionSpan=row:CreateFontString(nil,"ARTWORK","GameFontDisableSmall")
row.sessionSpan:SetJustifyH("LEFT")
row.sessionSpan:SetWordWrap(false)
row.sessionSpan:Hide()
row.sessionGround=row:CreateTexture(nil,"BACKGROUND")
row.sessionGround:SetAllPoints(row)
row.sessionGround:Hide()
row.expansion=row:CreateFontString(nil,"ARTWORK","GameFontHighlightSmall")
row.expansion:SetJustifyH("LEFT")
row.expansion:SetWordWrap(true)
row.expansion:Hide()
row:SetScript("OnClick",function(self,button)
if button=="RightButton"then
if at=="list"and not self.isSeparator and self.entryKind=="match"
and self.matchId~=nil then
rowSurface.openMenu(self,self.matchId,"click")
end
return
end
if self.sessionKey~=nil then
A.foldSession(self.sessionKey,self.sessionNewest==true,"click")
return
end
if self.isSeparator then
return
end
if self.askRow~=nil then
A.pickAskRow(self.askRow)
return
end
if self.matchStay and self.matchId~=nil then
A.showMatchWindow("match",self.matchId,self.staySource or"ask")
return
end
if self.specKey~=nil then
A.pickSpec(self.specKey)
return
end
A.selectEntry(self.entryKind,self.matchId)
end)
end
if at=="askband"and type(data)=="table"
and((data.kind=="specMet"and type(data.look)=="table")or data.kind=="specMetNames")then
local okWidth,width=pcall(row.GetWidth,row)
local room=okWidth and type(width)=="number"and width>0
and(width-A.metric("rowNamePad")*2-A.metric("rowLabelPad"))or nil
return initRow(row,{detail=data,room=room},at)
end
if type(data)=="table"and type(data.detail)=="table"then
initRow(row,{separator=true},at)
row.dayRule:Hide()
row.dayCount:Hide()
row.dayName:Hide()
row.sessionCaret:Hide()
row.sessionSpan:Hide()
row.sessionGround:Hide()
paintLineFace(row,data.detail,data.room)
return
end
if row.lineFace then
row.lineFace:Hide()
end
A.style(row.label,"bodyText","text")
row.selection:SetColorTexture(A.color("selection"))
row.hover:SetColorTexture(A.color("hover"))
row.matchId=data.id
row.entryKind=data.kind
row.matchRecord=type(data.matchRecord)=="table"and data.matchRecord or nil
row.isSeparator=data.separator==true
row.specKey=data.specKey
row.askRow=data.askRow
row.matchStay=data.stay==true
row.staySource=data.staySource
row.sessionKey=data.session and data.sessionKey or nil
row.sessionNewest=data.session and data.sessionNewest or nil
local okRowWidth,rowWidth=pcall(row.GetWidth,row)
if not(okRowWidth and type(rowWidth)=="number"and rowWidth>0)then
rowWidth=nil
end
local place=ROW_TABLES[at]or ROW_TABLES.list
local trail=0
local span=window and window[place.span]
if rowWidth and type(span)=="number"and span>0 and span<rowWidth then
trail=rowWidth-span
end
for _,ground in ipairs({row.selection,row.hover})do
ground:ClearAllPoints()
ground:SetPoint("TOPLEFT",row,"TOPLEFT",0,0)
ground:SetPoint("BOTTOMRIGHT",row,"BOTTOMRIGHT",-trail,0)
end
row.resultMark:Hide()
darkList.hideGrid(row)
if row.isSeparator then
row:EnableMouse(false)
row.selection:Hide()
row.hover:SetColorTexture(0,0,0,0)
row.label:Hide()
row.expansion:Hide()
for i=1,#row.cells do
row.cells[i]:Hide()
end
hideRowBar(row)
A.layoutRowTalents(row,nil,{},{})
hideRowSecond(row)
if data.names then
row.dayRule:Hide()
row.dayCount:Hide()
row.dayName:Hide()
row.sessionCaret:Hide()
row.sessionSpan:Hide()
row.sessionGround:Hide()
local columns=type(data.columns)=="table"and data.columns or(window and window.listColumns)
if type(columns)=="table"then
paintColumnHead(row,row.cells,nil,columns,nil,"labelMuted")
end
row.rule:ClearAllPoints()
row.rule:SetPoint("BOTTOMLEFT",row,"BOTTOMLEFT",0,0)
row.rule:SetPoint("BOTTOMRIGHT",row,"BOTTOMRIGHT",-trail,0)
row.rule:SetHeight(1)
row.rule:SetColorTexture(A.color("hairline"))
row.rule:Show()
return
end
if data.seasonBreak then
row.dayCount:Hide()
row.sessionCaret:Hide()
row.sessionSpan:Hide()
row.sessionGround:Hide()
row.rule:Hide()
A.style(row.dayName,"label","dim")
row.dayName:ClearAllPoints()
row.dayName:SetPoint("BOTTOMLEFT",row,"BOTTOMLEFT",A.metric("rowLabelPad"),3)
row.dayName:SetText(data.text or"")
row.dayName:Show()
row.dayRule:ClearAllPoints()
row.dayRule:SetPoint("BOTTOMLEFT",row,"BOTTOMLEFT",A.metric("rowLabelPad"),0)
row.dayRule:SetPoint("BOTTOMRIGHT",row,"BOTTOMRIGHT",-(A.metric("rowLabelPad")+trail),0)
row.dayRule:SetHeight(1)
row.dayRule:SetColorTexture(A.color("hairline"))
row.dayRule:Show()
return
end
A.style(row.dayName,"label","accent")
A.style(row.dayCount,"label","dim")
row.dayRule:ClearAllPoints()
row.dayRule:SetPoint("TOPLEFT",row,"TOPLEFT",A.metric("rowLabelPad"),0)
row.dayRule:SetPoint("TOPRIGHT",row,"TOPRIGHT",-(A.metric("rowLabelPad")+trail),0)
row.dayCount:ClearAllPoints()
row.dayCount:SetPoint("TOPRIGHT",row,"TOPRIGHT",
-(A.metric("rowLabelPad")+trail),-A.metric("rowExpandPad"))
row.dayRule:SetColorTexture(A.color("hairline"))
row.dayRule:Show()
row.dayCount:SetText(data.count or"")
row.dayCount:Show()
row.dayName:SetText(data.text or"")
row.dayName:Show()
if not data.session then
row.sessionCaret:Hide()
row.sessionSpan:Hide()
row.sessionGround:Hide()
row.dayName:ClearAllPoints()
row.dayName:SetPoint("TOPLEFT",row,"TOPLEFT",A.metric("rowLabelPad"),-A.metric("rowExpandPad"))
return
end
row:EnableMouse(true)
local gr,gg,gb,ga=A.color(data.open and"sessionOpen"or"sessionGround")
row.sessionGround:SetColorTexture(gr,gg,gb,ga or 1)
row.sessionGround:Show()
row.dayRule:SetColorTexture(A.color("sessionRule"))
if type(A.trace)=="function"then
pcall(A.trace,"sessionground",{ground=A.colorHex(gr,gg,gb,ga),theme=A.theme()},"ui")
end
darkList.layoutGrid(row,data)
return
end
row:EnableMouse(true)
row.dayRule:Hide()
row.dayCount:Hide()
row.dayName:Hide()
row.sessionCaret:Hide()
row.sessionSpan:Hide()
row.sessionGround:Hide()
if row.flatGround==nil then
row.flatGround=row:CreateTexture(nil,"BACKGROUND",nil,-1)
end
row.flatGround:ClearAllPoints()
row.flatGround:SetPoint("TOPLEFT",row,"TOPLEFT",0,0)
row.flatGround:SetPoint("BOTTOMRIGHT",row,"BOTTOMRIGHT",-trail,0)
row.flatGround:SetColorTexture(A.color("insetDeep"))
local columned=data.cells and data.columns and layoutRowCells(row,data,data.columns,trail)
if columned then
row.label:SetText("")
row.label:Hide()
else
row.label:SetText(data.text or"")
row.label:Show()
for i=1,#row.cells do
row.cells[i]:Hide()
end
hideRowBar(row)
A.layoutRowTalents(row,nil,{},{})
hideRowSecond(row)
end
row.flatGround:SetShown(data.flat==true)
if data.flat==true and type(A.trace)=="function"then
local fr,fg,fb,fa=A.color("insetDeep")
pcall(A.trace,"flatground",{ground=A.colorHex(fr,fg,fb,fa),theme=A.theme(),
groundShown=row.flatGround:IsShown()},"ui")
end
if row.rule~=nil and at=="list"then
row.rule:ClearAllPoints()
row.rule:SetPoint("BOTTOMLEFT",row,"BOTTOMLEFT",A.metric("rowLabelPad"),0)
row.rule:SetPoint("BOTTOMRIGHT",row,"BOTTOMRIGHT",-(A.metric("rowLabelPad")+trail),0)
row.rule:SetHeight(1)
row.rule:SetColorTexture(A.color("hairline"))
row.rule:Show()
end
if type(data.resultTone)=="string"then
row.resultMark:ClearAllPoints()
row.resultMark:SetPoint("TOPLEFT",row,"TOPLEFT",0,0)
row.resultMark:SetWidth(A.metric("rowResultMark"))
row.resultMark:SetHeight(data.flat and A.metric("rowListRow")or A.metric("rowHeight"))
row.resultMark:SetColorTexture(A.color(data.resultTone))
row.resultMark:Show()
end
if data.expansion and data.expansion~=""then
A.style(row.expansion,"rowNote","dim")
row.expansion:ClearAllPoints()
row.expansion:SetPoint("TOPLEFT",row,"TOPLEFT",
A.metric("rowLabelPad"),-A.metric("rowListRow"))
row.expansion:SetPoint("TOPRIGHT",row,"TOPRIGHT",
-(A.metric("rowLabelPad")+trail),-A.metric("rowListRow"))
row.expansion:SetText(data.expansion)
row.expansion:Show()
else
row.expansion:SetText("")
row.expansion:Hide()
end
if data.id~=nil and matchWindowOpenOn and matchWindowOpenOn(data.kind or"match",data.id)then
row.selection:Show()
elseif data.specKey~=nil and data.specKey==shownSpec then
row.selection:Show()
elseif data.askRow~=nil and data.askRow==shownAskRow then
row.selection:Show()
else
row.selection:Hide()
end
end
local function initListRow(row,data)
return initRow(row,data,"list")
end
local function initPaneRow(row,data)
return initRow(row,data,"pane")
end
local function initAskRow(row,data)
return initRow(row,data,"ask")
end
local function initAskBandRow(row,data)
return initRow(row,data,"askband")
end
function darkList.metRowLayout(line,data,room)
local names=data.kind=="specMetNames"and data or data.names
names=type(names)=="table"and names or nil
if names~=nil and names.laid~=nil and names.laidPaint==rowSurface.metRowPaint and names.laidRoom==room then
return names.laid
end
local own=type(data.look)=="table"and type(data.look.cells)=="table"and data.look.cells or{}
local wheres=names~=nil and names.wheres or{own.where}
local whens=names~=nil and names.whens or{own.day}
A.style(line.cells[3],"numberSmall","dim")
local roundsNeed=A.clientTextWidth(line.cells[3],"6 of 6")
A.style(line.cells[2],"bodyText","text")
local whereNeed=0
for i=1,#wheres do
whereNeed=math.max(whereNeed,A.textRoom(line.cells[2],wheres[i]))
end
A.style(line.cells[6],"numberSmall","dim")
local whenNeed=nil
for i=1,#whens do
local width=A.clientTextWidth(line.cells[6],whens[i])
if width~=nil and(whenNeed==nil or width>whenNeed)then
whenNeed=width
end
end
local widths=A.metRowWidths(room,roundsNeed,whereNeed,whenNeed)
if rowSurface.metRowTraced~=rowSurface.metRowPaint then
rowSurface.metRowTraced=rowSurface.metRowPaint
A.trace("met-row",{roundsRoom=A.unitFigure(widths.rounds),
roundsNeed=roundsNeed and A.unitFigure(roundsNeed)or nil,
roundsMeasured=roundsNeed~=nil,
whereRoom=A.unitFigure(widths.where),whereNeed=A.unitFigure(whereNeed),
whenRoom=A.unitFigure(widths.when)},"ui")
end
if names~=nil then
names.laid,names.laidPaint,names.laidRoom=widths,rowSurface.metRowPaint,room
end
return widths
end
local function initSpecLine(line,data,room)
if not line.built then
line.built=true
line:RegisterForClicks("LeftButtonUp")
line.hover=line:CreateTexture(nil,"HIGHLIGHT")
line.hover:SetAllPoints(line)
line.edge=line:CreateTexture(nil,"ARTWORK")
line.edge:SetPoint("TOPLEFT",line,"TOPLEFT",0,0)
line.edge:SetPoint("BOTTOMLEFT",line,"BOTTOMLEFT",0,0)
line.edge:SetWidth(1)
line.squares={}
for i=1,6 do
line.squares[i]=line:CreateTexture(nil,"ARTWORK")
end
line.cells={}
for i=1,6 do
local cell=line:CreateFontString(nil,"ARTWORK","GameFontHighlightSmall")
cell:SetWordWrap(false)
line.cells[i]=cell
end
line.side={}
for i=1,3 do
local name=line:CreateFontString(nil,"ARTWORK","GameFontHighlightSmall")
name:SetJustifyH("LEFT")
name:SetWordWrap(false)
line.side[i]={icon=line:CreateTexture(nil,"ARTWORK"),name=name}
end
line.key=line:CreateFontString(nil,"ARTWORK","GameFontDisableSmall")
line.key:SetJustifyH("LEFT")
line.key:SetWordWrap(false)
A.style(line.key,"label","dim")
line.text=line:CreateFontString(nil,"ARTWORK","GameFontHighlightSmall")
line.text:SetJustifyH("LEFT")
A.style(line.text,"bodyText","text")
line.sub=line:CreateFontString(nil,"ARTWORK","GameFontDisableSmall")
line.sub:SetJustifyH("LEFT")
line.sub:SetWordWrap(false)
A.style(line.sub,"note","dim")
line:SetScript("OnClick",function(self)
if self.matchId==nil then
return
end
if self.matchStay then
A.showMatchWindow("match",self.matchId,"ask")
return
end
A.openSpecMatch(self.matchId)
end)
end
local kind=type(data)=="table"and data.kind or nil
line.matchId=kind=="specMet"and data.id or nil
line.matchStay=line.matchId~=nil and data.stay==true
line:EnableMouse(line.matchId~=nil)
line.hover:SetColorTexture(A.color("hover"))
line.hover:SetShown(line.matchId~=nil)
line.key:ClearAllPoints()
line.text:ClearAllPoints()
line.sub:ClearAllPoints()
line.key:Hide()
line.sub:Hide()
line.text:SetWordWrap(false)
line.edge:Hide()
for i=1,#line.squares do
line.squares[i]:Hide()
end
for i=1,#line.cells do
line.cells[i]:ClearAllPoints()
line.cells[i]:Hide()
end
for i=1,#line.side do
line.side[i].icon:ClearAllPoints()
line.side[i].icon:Hide()
line.side[i].name:Hide()
end
line.edgeTone=nil
local function cell(index,text,role,tone,width,justify)
local region=line.cells[index]
A.style(region,role,tone)
region:SetText(text or"")
region:SetWidth(math.max(1,width))
region:SetJustifyH(justify or"LEFT")
region:Show()
return region
end
if kind=="metGridHead"then
local widths=A.metGridWidths(room,data.byRound==true)
local gap=A.metric("rowCellGap")
local match=cell(1,"MATCH","label","dim",widths.match)
match:SetPoint("LEFT",line,"LEFT",widths.lead,0)
local before=match
if data.byRound then
before=cell(2,"ROUND","label","dim",widths.round)
before:SetPoint("LEFT",match,"RIGHT",gap,0)
end
local side=cell(3,"YOUR SIDE","label","dim",widths.side)
side:SetPoint("LEFT",before,"RIGHT",gap,0)
cell(4,"RESULT","label","dim",widths.result):SetPoint("RIGHT",line,"RIGHT",0,0)
line.text:SetText("")
line.text:Hide()
return
elseif kind=="specMet"and type(data.grid)=="table"then
local grid=data.grid
local byRound=grid.round~=nil
local widths=A.metGridWidths(room,byRound)
local gap=A.metric("rowCellGap")
local tone=grid.tone or"dim"
line.edge:SetColorTexture(A.color(tone))
line.edge:Show()
line.edgeTone=tone
local match=cell(1,grid.match,"numberSmall","dim",widths.match)
match:SetPoint("LEFT",line,"LEFT",widths.lead,0)
local before=match
if byRound then
before=cell(2,grid.round,"numberSmall","dim",widths.round)
before:SetPoint("LEFT",match,"RIGHT",gap,0)
end
line.side[1].icon:SetPoint("LEFT",before,"RIGHT",gap,0)
A.drawComp(line.side,grid.side,widths.side,{})
cell(4,grid.result,"numberSmall",tone,widths.result):SetPoint("RIGHT",line,"RIGHT",0,0)
line.text:SetText("")
line.text:Hide()
return
elseif kind=="specMet"and type(data.look)=="table"then
local look=data.look
local tone=look.resultTone
local widths=darkList.metRowLayout(line,data,room)
local at=widths.at
line.edge:SetColorTexture(A.color(tone or"dim"))
line.edge:Show()
line.edgeTone=tone or"dim"
local cells=type(look.cells)=="table"and look.cells or{}
cell(1,look.id,"numberSmall","dim",widths.id):SetPoint("LEFT",line,"LEFT",at.id,0)
cell(6,cells.day or"-","numberSmall","dim",widths.when):SetPoint("LEFT",line,"LEFT",at.when,0)
if widths.where>0 then
cell(2,cells.where or"","bodyText","text",widths.where):SetPoint("LEFT",line,"LEFT",at.where,0)
end
local counted=look.rounds~=nil and cells.rounds or cells.result
cell(3,counted or"-","numberSmall",tone or"dim",widths.rounds):SetPoint("LEFT",line,"LEFT",at.rounds,0)
if look.rounds~=nil then
local pip,pipGap=A.metric("rowPip"),A.metric("rowPipGap")
for n=1,math.min(look.rounds.played or 0,#line.squares)do
local square=line.squares[n]
square:ClearAllPoints()
square:SetPoint("LEFT",line,"LEFT",at.squares+(n-1)*(pip+pipGap),0)
square:SetSize(pip,pip)
square:SetColorTexture(A.color(n<=(look.rounds.won or 0)and"win"or"faint"))
square:Show()
end
end
cell(4,cells.change or"","numberSmall",look.changeTone or"dim",widths.change,"RIGHT")
:SetPoint("LEFT",line,"LEFT",at.change,0)
local rating=cell(5,cells.ratingOut or"-","numberSmall","bright",widths.rating,"RIGHT")
rating:SetPoint("LEFT",line,"LEFT",at.rating,0)
local _,_,_,r,g,b=A.ratingColour(look.format,look.ratingOut)
if r~=nil then
rating:SetTextColor(r,g,b)
elseif look.ratingOut==nil then
A.style(rating,"numberSmall","dimmer")
end
line.text:SetText("")
line.text:Hide()
return
elseif kind=="specMetNames"then
local widths=darkList.metRowLayout(line,data,room)
local at=widths.at
local function head(index,text,x,width,justify)
cell(index,text,"label","labelMuted",width,justify):SetPoint("LEFT",line,"LEFT",x,0)
end
head(1,"MATCH",at.id,widths.id)
head(6,"WHEN",at.when,widths.when)
if widths.where>0 then
head(2,"WHERE",at.where,widths.where)
end
head(3,"ROUNDS",at.squares,widths.squares+A.metric("rowCellGap")+widths.rounds)
head(4,"CHANGE",at.change,widths.change,"RIGHT")
head(5,"RATING",at.rating,widths.rating,"RIGHT")
line.text:SetText("")
line.text:Hide()
return
end
if kind=="specHead"then
A.style(line.text,"bodyMedium","text")
local tint=nil
if type(A.classColor)=="function"then
local read,r,g,b=pcall(A.classColor,data.classToken)
if read and type(r)=="number"then
tint={r,g,b}
end
end
if tint then
line.text:SetTextColor(tint[1],tint[2],tint[3])
end
line.text:SetPoint("TOPLEFT",line,"TOPLEFT",0,0)
line.text:SetPoint("TOPRIGHT",line,"TOPRIGHT",0,0)
line.text:SetText(data.text or"")
if type(data.sub)=="string"and data.sub~=""then
A.style(line.sub,"note","dim")
line.sub:SetPoint("TOPLEFT",line.text,"BOTTOMLEFT",0,-2)
line.sub:SetText(data.sub)
line.sub:Show()
else
line.sub:SetText("")
end
elseif kind=="specSide"or kind=="specMetHead"then
A.style(line.key,"label","dim")
line.key:SetPoint("TOPLEFT",line,"TOPLEFT",0,0)
line.key:SetWidth(A.metric("readingKeyWidth"))
line.key:SetText(data.key or"")
line.key:Show()
local said=data.text
if kind=="specSide"and said==nil then
A.style(line.text,"note","dimmer")
said=data.absent or""
elseif kind=="specMetHead"then
A.style(line.text,"note","dim")
else
A.style(line.text,"numberSmall","text")
end
line.text:SetPoint("TOPLEFT",line,"TOPLEFT",
A.metric("readingKeyWidth")+A.metric("readingKeyGap"),0)
line.text:SetPoint("TOPRIGHT",line,"TOPRIGHT",0,0)
line.text:SetText(said)
elseif kind=="specSay"then
A.style(line.text,"bodyText","text")
line.text:SetWordWrap(true)
line.text:SetPoint("TOPLEFT",line,"TOPLEFT",0,0)
line.text:SetPoint("TOPRIGHT",line,"TOPRIGHT",0,0)
line.text:SetText(data.text or"")
elseif kind=="specNote"then
A.style(line.text,"note","dim")
line.text:SetPoint("TOPLEFT",line,"TOPLEFT",0,0)
line.text:SetPoint("TOPRIGHT",line,"TOPRIGHT",0,0)
line.text:SetText(data.text or"")
else
A.style(line.text,"bodyText","text")
line.text:SetPoint("LEFT",line,"LEFT",A.metric("rowLabelPad"),0)
line.text:SetPoint("RIGHT",line,"RIGHT",-A.metric("rowLabelPad"),0)
line.text:SetText(type(data)=="table"and data.text or"")
end
line.text:Show()
end
paintLineFace=function(row,line,room)
local face=row.lineFace
if not face then
face=CreateFrame("Button",nil,row)
row.lineFace=face
end
face:ClearAllPoints()
face:SetPoint("TOPLEFT",row,"TOPLEFT",A.metric("rowNamePad")*2,0)
face:SetPoint("BOTTOMRIGHT",row,"BOTTOMRIGHT",-A.metric("rowLabelPad"),0)
face:Show()
initSpecLine(face,line,room)
end
darkList.OBJECTIVE_CELLS=4
darkList.PACE_ROWS=8
local function hideAll(regions)
for i=1,#regions do
regions[i]:Hide()
end
end
local function rosterSlots(columns,max,filled)
local swapped=0
if type(columns)=="table"and type(max)=="number"then
swapped=math.min(#columns,max)
end
local function short(index)
local column=columns and columns[index]
return type(column)=="table"and type(column.short)=="string"and column.short or nil
end
local function has(key)
return filled==nil or filled[key]==true
end
return{
swapped=swapped,
spec=has("spec")and"SPEC"or nil,
role=has("role")and"ROLE"or nil,
damage=(swapped>=2 and short(1))or(has("damage")and"DAMAGE")or nil,
heal=(swapped>=1 and short(swapped))or(has("healing")and"HEALING")or nil,
kb=has("kb")and"KB"or nil,
dispels=has("dispels")and"DISP"or nil,
}
end
local function rosterNameText(c)
local name,realm=tostring(c.name),nil
local cut=name:find("-",1,true)
if cut then
name,realm=name:sub(1,cut-1),name:sub(cut)
end
local text=name
if realm then
text=text..A.colorEscape("dim")..realm.."|r"
end
if c.lead then
text=text.."  "..A.colorEscape("dim").."LEAD".."|r"
end
if c.self then
text=text.."  "..A.colorEscape("accent").."YOU".."|r"
end
return text
end
local rowLook={}
function rowLook.place(region,anchor,width)
region:ClearAllPoints()
region:SetPoint("RIGHT",anchor,"LEFT",-A.metric("rowCellGap"),0)
region:SetWidth(width)
end
function rowLook.layout(line,look,count,columns)
local gap=A.metric("rowCellGap")
line.disp:ClearAllPoints()
line.disp:SetPoint("RIGHT",line,"RIGHT",-gap,0)
line.disp:SetWidth(A.metric("rowDispels"))
rowLook.place(line.kb,line.disp,A.metric("rowKb"))
rowLook.place(line.heal,line.kb,A.metric("rowHeal"))
rowLook.place(line.damage,line.heal,A.metric("rowDamageValue"))
line.track:ClearAllPoints()
line.fill:ClearAllPoints()
line.healTrack:ClearAllPoints()
line.healFill:ClearAllPoints()
line.name:ClearAllPoints()
for i=1,#line.objectives do
line.objectives[i]:ClearAllPoints()
end
if look=="team"then
rowLook.place(line.healTrack,line.heal,A.metric("rowHealBar"))
line.healTrack:SetHeight(A.metric("rowIcon"))
line.healFill:SetPoint("LEFT",line.healTrack,"LEFT",0,0)
line.healFill:SetHeight(A.metric("rowIcon"))
rowLook.place(line.damage,line.healTrack,A.metric("rowDamageValue"))
rowLook.place(line.track,line.damage,A.metric("rowDamageBar"))
line.track:SetHeight(A.metric("rowIcon"))
line.fill:SetPoint("LEFT",line.track,"LEFT",0,0)
line.fill:SetHeight(A.metric("rowIcon"))
local left=line.track
for i=math.min(count or 0,#line.objectives),1,-1 do
local column=type(columns)=="table"and columns[i]or nil
rowLook.place(line.objectives[i],left,
A.objectiveCellWidth(type(column)=="table"and column.short or nil))
left=line.objectives[i]
end
rowLook.place(line.role,left,A.metric("rowRole"))
line.icon:ClearAllPoints()
line.icon:SetPoint("LEFT",line,"LEFT",A.metric("classEdge")+A.metric("rowNamePad"),0)
line.icon:SetSize(A.metric("rowIcon"),A.metric("rowIcon"))
line.name:SetPoint("LEFT",line,"LEFT",A.metric("classEdge")+A.metric("rowNamePad")
+A.metric("rowIcon")+A.metric("headCrestGap"),0)
else
line.track:SetPoint("TOPRIGHT",line.damage,"TOPLEFT",0,0)
line.track:SetPoint("BOTTOMRIGHT",line.damage,"BOTTOMLEFT",0,0)
line.track:SetWidth(A.trackBase())
line.fill:SetPoint("TOPLEFT",line.track,"TOPLEFT",0,0)
line.fill:SetPoint("BOTTOMLEFT",line.track,"BOTTOMLEFT",0,0)
line.healTrack:SetPoint("TOPLEFT",line.heal,"TOPLEFT",0,0)
line.healTrack:SetPoint("BOTTOMRIGHT",line.heal,"BOTTOMRIGHT",0,0)
line.healFill:SetPoint("TOPLEFT",line.heal,"TOPLEFT",0,0)
line.healFill:SetPoint("BOTTOMLEFT",line.heal,"BOTTOMLEFT",0,0)
for i=1,#line.objectives do
rowLook.place(line.objectives[i],(i==1)and line.kb or line.heal,
i==1 and A.metric("rowHeal")or A.metric("rowBar"))
end
rowLook.place(line.role,line.track,A.metric("rowRole"))
line.name:SetPoint("LEFT",line,"LEFT",A.metric("classEdge")+A.metric("rowNamePad"),0)
end
rowLook.place(line.spec,line.role,A.metric("rowSpec"))
end
function rowLook.headPlace(label,anchor,width)
label:ClearAllPoints()
label:SetPoint("BOTTOMRIGHT",anchor,"BOTTOMLEFT",-A.metric("rowCellGap"),0)
label:SetWidth(width)
end
function rowLook.headLayout(line,look,count,columns)
local gap,base=A.metric("rowCellGap"),A.metric("rosterHeadGap")
line.rosterTitle:ClearAllPoints()
line.rosterTitle:SetPoint("BOTTOMLEFT",line,"BOTTOMLEFT",A.metric("classEdge")+A.metric("rowNamePad"),base)
line.rosterTitle:SetWidth(A.metric("rowName"))
line.rosterDisp:ClearAllPoints()
line.rosterDisp:SetPoint("BOTTOMRIGHT",line,"BOTTOMRIGHT",-gap,base)
line.rosterDisp:SetWidth(A.metric("rowDispels"))
rowLook.headPlace(line.rosterKb,line.rosterDisp,A.metric("rowKb"))
rowLook.headPlace(line.rosterHeal,line.rosterKb,A.metric("rowHeal"))
for i=1,#line.rosterObjectives do
line.rosterObjectives[i]:ClearAllPoints()
end
local left=line.rosterDamage
if look=="team"then
rowLook.headPlace(line.rosterHeal,line.rosterKb,
A.metric("rowHealBar")+gap+A.metric("rowHeal"))
rowLook.headPlace(line.rosterDamage,line.rosterHeal,
A.metric("rowDamageBar")+gap+A.metric("rowDamageValue"))
for i=math.min(count or 0,#line.rosterObjectives),1,-1 do
local column=type(columns)=="table"and columns[i]or nil
rowLook.headPlace(line.rosterObjectives[i],left,
A.objectiveCellWidth(type(column)=="table"and column.short or nil))
left=line.rosterObjectives[i]
end
else
rowLook.headPlace(line.rosterDamage,line.rosterHeal,A.metric("rowBar"))
end
rowLook.headPlace(line.rosterRole,left,A.metric("rowRole"))
rowLook.headPlace(line.rosterSpec,line.rosterRole,A.metric("rowSpec"))
local pairGap,labelGap=A.metric("headGap"),A.metric("rowMarkGap")
line.teamWord:ClearAllPoints()
line.teamWord:SetPoint("BOTTOMRIGHT",line,"BOTTOMRIGHT",-gap,base)
local chain={{line.teamHealLabel,pairGap},{line.teamHeal,labelGap},
{line.teamDamageLabel,pairGap},{line.teamDamage,labelGap}}
local right=line.teamWord
for i=1,#chain do
local label,space=chain[i][1],chain[i][2]
label:ClearAllPoints()
label:SetPoint("BOTTOMRIGHT",right,"BOTTOMLEFT",-space,0)
right=label
end
end
function rowLook.foot(line,head)
local legend=head.teams and A.paintTeamLegend(line)or 0
local span=type(head.available)=="number"and head.available or A.detailWindowBody()
local text=line.lobbyFootText
text:ClearAllPoints()
text:SetPoint("RIGHT",line,"RIGHT",-A.metric("rowCellGap"),0)
text:SetWidth(math.max(1,span-A.metric("rowCellGap")-legend))
text:SetJustifyH("RIGHT")
A.style(text,"note","dim")
text:SetText(("sorted %s"):format(tostring(head.words or"")))
text:Show()
end
function rowLook.icon(line,c)
local kind,art=A.rosterIcon(c.classToken,c.spec)
local icon=line.icon
icon:SetVertexColor(1,1,1,1)
if kind=="spec"then
local trim=A.metric("rowIconTrim")
icon:SetTexture(art)
icon:SetTexCoord(trim,1-trim,trim,1-trim)
icon:Show()
elseif kind=="class"then
icon:SetAtlas(art,false)
icon:Show()
elseif kind=="square"then
icon:SetTexCoord(0,1,0,1)
icon:SetColorTexture(A.classColor(c.classToken))
icon:Show()
else
icon:Hide()
end
return kind
end
function rowLook.figure(cell,value,text,face)
local zero=type(value)=="number"and value==0
A.style(cell,face or"numberSmall",(text==nil or zero)and"dim"or"text")
cell:SetText(text or"-")
end
function rowLook.bar(track,fill,share,width,drawn,tone)
local r,g,b=A.color(tone or"dim")
track:SetColorTexture(r,g,b,A.metric("rowBarTrack"))
fill:SetColorTexture(r,g,b,A.metric("rowBarFill"))
if type(share)=="number"and drawn then
track:Show()
if share>0 then
fill:SetWidth(math.max(1,math.floor(width*math.min(1,share))))
fill:Show()
else
fill:Hide()
end
else
track:Hide()
fill:Hide()
end
end
function rowLook.wash(track,fill,share,width,drawn,tone)
local r,g,b=A.color(tone or"dim")
track:SetColorTexture(r,g,b,A.metric("rowWashTrack"))
fill:SetColorTexture(r,g,b,A.metric("rowWashFill"))
if type(share)=="number"and share>0 and drawn then
track:Show()
fill:SetWidth(math.max(1,math.floor(width*math.min(1,share))))
fill:Show()
else
track:Hide()
fill:Hide()
end
end
function rowLook.paint(line,c)
local drawn=c.filled
local function column(key)
return drawn==nil or drawn[key]==true
end
local tone=(c.side=="yours"and"win")or(c.side=="theirs"and"loss")or nil
if tone then
line.spine:SetColorTexture(A.color(tone))
else
line.spine:SetColorTexture(A.classColor(c.classToken))
end
if c.self then
line.wash:SetColorTexture(A.color("selection"))
line.wash:Show()
else
line.wash:Hide()
end
if c.bot then
line.icon:Hide()
A.style(line.name,"nameMedium","dim")
else
rowLook.icon(line,c)
A.style(line.name,"nameMedium","text")
line.name:SetTextColor(A.classColor(c.classToken))
end
line.name:SetText((rosterNameText(c)))
A.style(line.role,"bodyText","dim")
line.role:SetText(column("role")and(c.roleWord or"")or"")
A.style(line.spec,"bodyText",c.spec and"text"or"dim")
line.spec:SetText(column("spec")and(c.specLabel or"-")or"")
local values=c.objectiveValues
local count=math.min(type(c.objectiveColumns)=="table"and#c.objectiveColumns or 0,
#line.objectives)
for i=1,#line.objectives do
local cell=line.objectives[i]
if i<=count then
local value=type(values)=="table"and values[i]or nil
rowLook.figure(cell,value,value~=nil and tostring(value)or nil)
cell:Show()
else
cell:SetText("")
cell:Hide()
end
end
rowLook.figure(line.damage,c.damage,A.figureText(c.damage))
line.damage:SetShown(column("damage"))
if not column("damage")then
line.damage:SetText("")
end
rowLook.bar(line.track,line.fill,c.share,A.metric("rowDamageBar"),column("damage"),tone)
rowLook.figure(line.heal,c.healing,A.figureText(c.healing))
line.heal:SetShown(column("healing"))
if not column("healing")then
line.heal:SetText("")
end
rowLook.bar(line.healTrack,line.healFill,c.healShare,A.metric("rowHealBar"),column("healing"),
tone)
rowLook.figure(line.kb,c.kb,c.kb~=nil and tostring(c.kb)or nil,"bodyText")
if not column("kb")then
line.kb:SetText("")
end
rowLook.figure(line.disp,c.dispels,c.dispels~=nil and tostring(c.dispels)or nil)
if not column("dispels")then
line.disp:SetText("")
end
end
local function paintRow(line,c)
local columns=c.objectiveColumns
local team=c.look=="team"
rowLook.layout(line,c.look,team and math.min(type(columns)=="table"and#columns or 0,
#line.objectives)or 0,columns)
if team then
for i=1,#line.rowRegions do
line.rowRegions[i]:Show()
end
rowLook.paint(line,c)
return
end
for i=1,#line.rowRegions do
line.rowRegions[i]:Show()
end
local drawn=c.filled
local function column(key)
return drawn==nil or drawn[key]==true
end
line.spine:SetColorTexture(A.classColor(c.classToken))
A.style(line.name,"nameMedium",c.self and"accent"or"text")
line.name:SetText((rosterNameText(c)))
A.style(line.role,"bodyText","dim")
line.role:SetText(column("role")and(c.roleWord or"")or"")
A.style(line.spec,"bodyText",c.spec and"text"or"dim")
line.spec:SetText(column("spec")and(c.specLabel or"-")or"")
local cells=c.objectiveValues
local slots=rosterSlots(c.objectiveColumns,#line.objectives)
local showing=slots.swapped
for i=1,#line.objectives do
local cell=line.objectives[i]
local index=showing-i+1
local value=index>=1 and cells and cells[index]or nil
if i<=showing then
A.style(cell,"numberSmall",value~=nil and"text"or"dim")
cell:SetText(value~=nil and tostring(value)or"-")
cell:Show()
else
cell:SetText("")
cell:Hide()
end
end
if showing>=1 then
line.heal:SetText("")
line.heal:Hide()
else
local healing=A.figureText(c.healing)
A.style(line.heal,"numberSmall",healing~=nil and"text"or"dim")
line.heal:SetText(column("healing")and(healing or"-")or"")
line.heal:SetShown(column("healing"))
end
local tone=(c.side=="yours"and"win")or(c.side=="theirs"and"loss")or nil
if showing>=1 then
line.healTrack:Hide()
line.healFill:Hide()
else
rowLook.wash(line.healTrack,line.healFill,c.healShare,A.metric("rowHeal"),
column("healing"),tone)
end
if showing>=2 then
line.damage:SetText("")
line.damage:Hide()
line.track:Hide()
line.fill:Hide()
else
local damage=A.figureText(c.damage)
A.style(line.damage,"numberSmall",damage~=nil and"text"or"dim")
line.damage:SetText(column("damage")and(damage or"-")or"")
line.damage:SetShown(column("damage"))
rowLook.wash(line.track,line.fill,c.share,A.trackBase(),column("damage"),tone)
end
A.style(line.kb,"bodyText","text")
line.kb:SetText((column("kb")and c.kb~=nil)and tostring(c.kb)or"")
local pairs_={
{cell=line.disp,key="dispels",value=c.dispels,hover=line.meterHovers[1]},
}
for i=1,#pairs_ do
local slot=pairs_[i]
local headed=column(slot.key)
A.style(slot.cell,"numberSmall",slot.value~=nil and"text"or"dim")
slot.cell:SetText(headed and(slot.value~=nil and tostring(slot.value)or"-")or"")
end
end
local CREST_ATLAS={[0]="questlog-questtypeicon-horde",[1]="questlog-questtypeicon-alliance"}
function A.factionCrest(side)
return CREST_ATLAS[side]
end
local crestRefused=false
local function atlasKnown(atlas)
if type(C_Texture)~="table"or type(C_Texture.GetAtlasInfo)~="function"then
return false
end
local ok,info=pcall(C_Texture.GetAtlasInfo,atlas)
return ok and type(info)=="table"
end
local function paintCrest(line,faction)
local atlas=A.factionCrest(faction)
local known=atlas~=nil and atlasKnown(atlas)
if atlas~=nil and not known and not crestRefused then
crestRefused=true
A.trace("head/crest",{atlas=atlas,reason="unknown-atlas"},"ui")
end
line.headResult:ClearAllPoints()
if not known then
line.headCrest:Hide()
line.headResult:SetPoint("LEFT",line,"LEFT",0,0)
return
end
local size=A.fontSize("heading")
line.headCrest:SetAtlas(atlas,false)
line.headCrest:SetSize(size,size)
line.headCrest:Show()
line.headResult:SetPoint("LEFT",line.headCrest,"RIGHT",A.metric("headCrestGap"),0)
end
local function paintHead(line,h)
A.paintMatchHead(line,h,paintCrest)
end
local function paintObjectives(line,totals)
for i=1,#line.objRegions do
line.objRegions[i]:Show()
end
line.objBg:SetColorTexture(A.color("panelDeep"))
line.objEdge:SetColorTexture(A.color("hairline"))
A.style(line.objTitle,"label","dim")
line.objTitle:SetText("OBJECTIVES")
local sides={{line.objYours,line.objYoursCells,"yours","win",totals.yours or{}},
{line.objTheirs,line.objTheirsCells,"theirs","loss",totals.theirs or{}}}
local drawn=0
for c=1,#line.objYoursCells do
if totals.columns and totals.columns[c]then
drawn=drawn+1
end
end
local okWidth,stripWidth=pcall(line.GetWidth,line)
local cellRoom=(okWidth and type(stripWidth)=="number")
and A.objectiveCellRoom(stripWidth,drawn)or A.metric("objectivesCell")
local valueRoom={}
for c=1,#line.objYoursCells do
local widest=0
for s=1,#sides do
local cell=sides[s][2][c]
local value=sides[s][5][c]
A.style(cell.value,"number",value~=nil and"text"or"dim")
cell.value:SetText(value~=nil and tostring(value)or"-")
local okValue,width=pcall(cell.value.GetStringWidth,cell.value)
if okValue and type(width)=="number"and width>widest then
widest=width
end
end
local share=math.floor(cellRoom*0.5)
if widest<1 then
widest=math.floor(cellRoom*0.4)
end
if widest>share then
widest=share
end
valueRoom[c]=widest
end
for s=1,#sides do
local label,cells,side,tone,values=sides[s][1],sides[s][2],
sides[s][3],sides[s][4],sides[s][5]
A.style(label,"label",tone)
label:SetText(A.sideWord(side):upper())
label:SetWidth(A.metric("objectivesSide"))
for c=1,#cells do
local cell=cells[c]
local column=totals.columns and totals.columns[c]or nil
if column then
local value=values[c]
cell.value:SetText(value~=nil and tostring(value)or"-")
cell.value:SetWidth(valueRoom[c])
A.style(cell.label,"label","dim")
cell.label:SetText(column.short)
cell.label:SetWidth(cellRoom-valueRoom[c]-A.metric("objectivesGap"))
cell.value:Show()
cell.label:Show()
else
cell.value:SetText("")
cell.label:SetText("")
cell.value:Hide()
cell.label:Hide()
end
end
end
end
local function paintPacing(line,pacing)
for i=1,#line.paceRegions do
line.paceRegions[i]:Show()
end
line.paceBg:SetColorTexture(A.color("panelDeep"))
line.paceEdge:SetColorTexture(A.color("hairline"))
A.style(line.paceTitle,"label","dim")
line.paceTitle:SetText("ROUND PACING")
local rounds=pacing.rounds or{}
local longest=pacing.longest
for i=1,#line.paceRows do
local row=line.paceRows[i]
local seconds=rounds[i]
if seconds~=nil then
A.style(row.label,"label","dim")
row.label:SetText(("R%d"):format(i))
A.style(row.value,"numberSmall","text")
row.value:SetText(A.clockText(seconds)or"-")
row.track:SetColorTexture(A.color("field"))
row.fill:SetColorTexture(A.color("dim"))
local share=(type(longest)=="number"and longest>0)
and(seconds/longest)or 0
if share>0 then
row.fill:SetWidth(A.paceTrackWidth()*share)
row.fill:Show()
else
row.fill:Hide()
end
row.label:Show()
row.value:Show()
row.track:Show()
else
row.label:SetText("")
row.value:SetText("")
row.label:Hide()
row.value:Hide()
row.track:Hide()
row.fill:Hide()
end
end
end
local function lobbyLayoutOf(head)
local shared=type(head)=="table"and head.table or nil
local columns={}
if type(shared)=="table"and type(shared.columns)=="table"then
columns=shared.columns
elseif type(head)=="table"and type(head.columns)=="table"then
columns=head.columns
end
local available=type(shared)=="table"and shared.available or nil
return A.lobbyLayout(columns,available),columns
end
local function paintLobbyHead(line,head)
local layout,columns=lobbyLayoutOf(head)
if layout==nil then
return
end
for i=1,#line.lobbyHeadNames do
local name=line.lobbyHeadNames[i]
local column=columns[i]
if column==nil then
name:Hide()
else
name:ClearAllPoints()
name:SetPoint("LEFT",line,"LEFT",layout.offsets[i],0)
name:SetWidth(layout.widths[i])
name:SetJustifyH(column.align=="RIGHT"and"RIGHT"
or(column.align=="CENTER"and"CENTER"or"LEFT"))
A.style(name,"label",(head.sort~=nil and column.sort==head.sort)and"accent"or"dim")
name:SetText(column.name or"")
name:Show()
end
end
line.lobbyHeadRule:SetColorTexture(A.color("hairline"))
line.lobbyHeadRule:ClearAllPoints()
line.lobbyHeadRule:SetPoint("BOTTOMLEFT",line,"BOTTOMLEFT",0,0)
line.lobbyHeadRule:SetWidth(layout.span)
line.lobbyHeadRule:Show()
for i=1,#line.lobbySorts do
local button=line.lobbySorts[i]
local column=columns[i]
if column~=nil and type(column.sort)=="string"then
button.sortKey=column.sort
button:ClearAllPoints()
button:SetPoint("TOPLEFT",line,"TOPLEFT",layout.offsets[i],0)
button:SetWidth(layout.widths[i])
button:Show()
end
end
end
local function paintLobbyGroup(line,head)
local layout,columns=lobbyLayoutOf(head)
for i=1,#line.lobbyGroupNames do
line.lobbyGroupNames[i]:Hide()
end
if layout==nil then
return
end
local slot,i=0,1
while i<=#columns do
local group=columns[i].group
local last=i
while last<#columns and group~=nil and columns[last+1].group==group do
last=last+1
end
if group~=nil then
slot=slot+1
local name=line.lobbyGroupNames[slot]
local span=layout.offsets[last]+layout.widths[last]-layout.offsets[i]
if name then
name:ClearAllPoints()
name:SetPoint("LEFT",line,"LEFT",layout.offsets[i],0)
name:SetWidth(span)
name:SetJustifyH("CENTER")
A.style(name,"label","dim")
name:SetText(group)
name:Show()
end
end
i=last+1
end
end
local function placeLobbyCell(line,cell,layout,i,column,joined)
cell:ClearAllPoints()
cell:SetPoint("LEFT",line,"LEFT",layout.offsets[i],0)
cell:SetWidth(layout.widths[i])
cell:SetJustifyH(column.align=="RIGHT"and"RIGHT"
or(column.align=="CENTER"and"CENTER"or"LEFT"))
if column.lane~="name"then
return
end
local c=type(joined)=="table"and joined.cells or nil
if type(c)~="table"then
A.style(cell,"bodyText","dim")
cell:SetText("-")
cell:Show()
return
end
A.paintNameIcon(line,cell,layout.offsets[i],layout.widths[i],c.classToken,c.spec)
A.style(cell,"nameText","text")
cell:SetTextColor(A.classColor(c.classToken))
cell:SetText((rosterNameText(c)))
cell:Show()
end
local function paintRoundCell(line,parts,cell,layout,i,column,word,result)
placeLobbyCell(line,cell,layout,i,column)
A.paintRoundCellMark(line,parts,cell,layout.offsets[i],layout.widths[i],word,result)
end
local function paintLobbyRow(line,head)
local layout,columns=lobbyLayoutOf(head)
local cells=type(head.row)=="table"and head.row.cells or nil
local results=type(head.table)=="table"and head.table.results or{}
if layout==nil or type(cells)~="table"then
return
end
for i=1,#columns do
local column,cell=columns[i],line.lobbyCells[i]
if cell~=nil then
if column.lane=="round"then
paintRoundCell(line,line.lobbyRounds[column.round],cell,layout,i,column,cells[i],
results[column.round])
local words=type(head.row.meter)=="table"and head.row.meter[column.round]or nil
local hover=line.lobbyRoundHovers[column.round]
if hover and type(words)=="table"then
hover.words=words
hover:ClearAllPoints()
hover:SetPoint("LEFT",line,"LEFT",layout.offsets[i],0)
hover:SetSize(layout.widths[i],A.metric("rowHeight"))
hover:Show()
end
elseif column.lane=="name"then
placeLobbyCell(line,cell,layout,i,column,head.row.joined)
else
placeLobbyCell(line,cell,layout,i,column)
A.style(cell,"bodyText",column.lane=="spec"and"dim"or"text")
cell:SetText(tostring(cells[i]or""))
cell:Show()
end
end
end
end
local function commitRound(button,mouse)
local record=type(A.match)=="function"and A.match(button.recordId)or nil
if record==nil or type(button.round)~="number"then
return
end
local value=nil
if button.state=="open"then
value=mouse=="RightButton"and"loss"or"win"
end
local stored,_,why,held=A.editRound(record,button.round,value)
if not stored then
if why=="captured"then
A.say(("round %d was recorded by the client as %s and stays"):format(button.round,
tostring(held)))
elseif why=="totals"then
A.say(("round %d cannot be %s: the scoreboard's rounds won rule it out. Nothing written")
:format(button.round,value=="win"and"won"or"lost"))
else
A.say("that round could not be written")
end
return
end
repaintEverything()
end
local function paintLobbyYou(line,head)
local layout,columns=lobbyLayoutOf(head)
local you=type(head.row)=="table"and head.row or nil
if layout==nil or you==nil then
return
end
local shared=type(head.table)=="table"and head.table or{}
line.lobbyYouRule:SetColorTexture(A.color("hairline"))
line.lobbyYouRule:ClearAllPoints()
line.lobbyYouRule:SetPoint("TOPLEFT",line,"TOPLEFT",0,0)
line.lobbyYouRule:SetWidth(layout.span)
line.lobbyYouRule:Show()
for i=1,#columns do
local column,cell=columns[i],line.lobbyCells[i]
if cell~=nil then
if column.lane=="round"then
local entry=type(you.rounds)=="table"and you.rounds[i]or nil
paintRoundCell(line,line.lobbyRounds[column.round],cell,layout,i,column,
you.cells[i])
local button=line.lobbyRoundButtons[column.round]
local words=type(entry)=="table"and entry.meter or nil
if button and entry and(entry.state=="open"or entry.state=="typed")then
button.recordId=shared.record
button.round=column.round
button.state=entry.state
button.meterWords=words
button:ClearAllPoints()
button:SetPoint("LEFT",line,"LEFT",layout.offsets[i],0)
button:SetSize(layout.widths[i],A.metric("rowHeight"))
button:Show()
elseif type(words)=="table"then
local hover=line.lobbyRoundHovers[column.round]
if hover then
hover.words=words
hover:ClearAllPoints()
hover:SetPoint("LEFT",line,"LEFT",layout.offsets[i],0)
hover:SetSize(layout.widths[i],A.metric("rowHeight"))
hover:Show()
end
end
elseif column.lane=="name"then
placeLobbyCell(line,cell,layout,i,column,you.joined)
elseif column.lane=="spec"and shared.merged then
placeLobbyCell(line,cell,layout,i,column)
A.style(cell,"bodyText","dim")
cell:SetText(you.cells[i]or"-")
cell:Show()
elseif column.lane=="spec"then
placeLobbyCell(line,cell,layout,i,column)
A.style(cell,"label","accent")
cell:SetText(you.cells[i]or"YOU")
cell:Show()
elseif shared.merged and type(you.cells[i])=="string"and you.cells[i]~=""then
placeLobbyCell(line,cell,layout,i,column)
A.style(cell,"bodyText","text")
cell:SetText(you.cells[i])
cell:Show()
end
end
end
end
local function paintLobbyFoot(line,head)
local layout=lobbyLayoutOf(head)
if layout==nil then
return
end
local legend=A.paintRoundLegend(line)
local text=line.lobbyFootText
text:ClearAllPoints()
text:SetPoint("RIGHT",line,"LEFT",layout.span-A.metric("rowLabelPad"),0)
text:SetWidth(math.max(1,layout.span-A.metric("rowLabelPad")-legend))
text:SetJustifyH("RIGHT")
A.style(text,"note","dim")
text:SetText(("sorted %s"):format(tostring(head.words or"")))
text:Show()
end
local function paintRosterHead(line,h)
for i=1,#line.rosterRegions do
line.rosterRegions[i]:Show()
end
local team=h.look=="team"
local columns=h.columns
local count=team and math.min(type(columns)=="table"and#columns or 0,#line.rosterObjectives)or 0
rowLook.headLayout(line,h.look,count,columns)
local title
local slots=nil
if h.side then
title=("%s %d"):format(A.sideWord(h.side):upper(),h.count or 0)
local bots=h.bots or 0
if bots>0 then
title=title..(bots==(h.count or 0)and"  ALL BOTS"
or("  %d %s"):format(bots,bots==1 and"BOT"or"BOTS"))
end
elseif team then
title=("ROSTER %d"):format(h.count or 0)
local filled=h.filled
local function has(key)
return filled==nil or filled[key]==true
end
slots={swapped=0,spec=has("spec")and"SPEC"or nil,role=has("role")and"ROLE"or nil,
damage=has("damage")and"DAMAGE"or nil,heal=has("healing")and"HEALING"or nil,
kb=has("kb")and"KB"or nil,dispels=has("dispels")and"DISP"or nil,objectives={}}
for i=1,count do
slots.objectives[i]=columns[i].short
end
else
title=("ROSTER %d"):format(h.count or 0)
slots=rosterSlots(h.columns,A.metric("rowObjectiveMax"),h.filled)
end
local targets={}
if slots then
targets[1]={label=line.rosterTitle,key="name"}
if slots.damage then
targets[2]=slots.swapped>=2 and{label=line.rosterDamage,key="objective",index=1}
or{label=line.rosterDamage,key="damage"}
end
if slots.heal then
targets[3]=slots.swapped>=1
and{label=line.rosterHeal,key="objective",index=slots.swapped}
or{label=line.rosterHeal,key="healing"}
end
if slots.kb then
targets[4]={label=line.rosterKb,key="kb"}
end
if slots.dispels then
targets[5]={label=line.rosterDisp,key="dispels"}
end
for i=1,#(slots.objectives or{})do
targets[5+i]={label=line.rosterObjectives[i],key="objective",index=i}
end
end
local lit={}
for i=1,5+#line.rosterObjectives do
local target=targets[i]
if target and h.sortKey~=nil and target.key==h.sortKey
and(target.key~="objective"or target.index==h.sortIndex)then
lit[target.label]=true
end
end
local function tone(label,otherwise)
return lit[label]and"accent"or otherwise
end
local sideTone=h.side and((team and(h.side=="yours"and"win"or"loss"))or"accent")or nil
A.style(line.rosterTitle,"label",sideTone or tone(line.rosterTitle,"dim"))
line.rosterTitle:SetText(title)
A.style(line.rosterSpec,"label","dimmer")
line.rosterSpec:SetText(slots and slots.spec or"")
A.style(line.rosterRole,"label","dimmer")
line.rosterRole:SetText(slots and slots.role or"")
A.style(line.rosterDamage,"label",tone(line.rosterDamage,slots and slots.swapped>=2 and"dim"or"dimmer"))
line.rosterDamage:SetText(slots and slots.damage or"")
A.style(line.rosterHeal,"label",tone(line.rosterHeal,slots and slots.swapped>=1 and"dim"or"dimmer"))
line.rosterHeal:SetText(slots and slots.heal or"")
A.style(line.rosterKb,"label",tone(line.rosterKb,"dimmer"))
line.rosterKb:SetText(slots and slots.kb or"")
A.style(line.rosterDisp,"label",tone(line.rosterDisp,"dimmer"))
line.rosterDisp:SetText(slots and slots.dispels or"")
for i=1,#line.rosterObjectives do
local label=line.rosterObjectives[i]
local name=slots and slots.objectives and slots.objectives[i]or nil
A.style(label,"label",tone(label,"dim"))
label:SetText(name or"")
label:SetShown(name~=nil)
end
local totals=team and h.side~=nil
local function total(figure,label,value,word)
if not totals then
figure:SetText("")
label:SetText("")
figure:Hide()
label:Hide()
return
end
local text=A.figureText(value)
A.style(figure,"numberSmall",text~=nil and"text"or"dim")
figure:SetText(text or"-")
A.style(label,"label","dim")
label:SetText(word)
end
total(line.teamDamage,line.teamDamageLabel,h.damage,"dmg")
total(line.teamHeal,line.teamHealLabel,h.healing,"heal")
if totals and h.word~=nil then
A.style(line.teamWord,"label",h.word=="DRAW"and"dim"or sideTone)
line.teamWord:SetText(h.word)
line.teamWord:Show()
else
line.teamWord:SetText("")
line.teamWord:Hide()
end
line.rosterRule:SetColorTexture(A.color("hairline"))
for i=1,#line.rosterSorts do
local button=line.rosterSorts[i]
local target=targets[i]
if target then
button.sortKey,button.sortIndex=target.key,target.index
button.sortUp=nil
if lit[target.label]and type(h.sortUp)=="boolean"then
button.sortUp=h.sortUp
end
button:Show()
end
end
end
local function initLine(line,data)
if not line.built then
line.built=true
line:RegisterForClicks("LeftButtonUp")
line.hover=line:CreateTexture(nil,"HIGHLIGHT")
line.hover:SetAllPoints(line)
line.label=line:CreateFontString(nil,"ARTWORK","GameFontHighlightSmall")
line.label:SetPoint("TOPLEFT",line,"TOPLEFT",0,0)
line.label:SetPoint("TOPRIGHT",line,"TOPRIGHT",0,0)
line.label:SetJustifyH("LEFT")
line.label:SetWordWrap(true)
line:SetScript("OnClick",function(self)
if self.participantGuid then
local owner=self
for _=1,12 do
local ok,parent=pcall(owner.GetParent,owner)
owner=ok and parent or nil
if owner==nil or owner.recordKind~=nil then
break
end
end
A.clickParticipant(self.participantGuid,
(owner~=nil and owner.recordKind~=nil)and owner or nil,{
shift=type(IsShiftKeyDown)=="function"and IsShiftKeyDown()==true,
ctrl=type(IsControlKeyDown)=="function"and IsControlKeyDown()==true,
alt=type(IsAltKeyDown)=="function"and IsAltKeyDown()==true,
})
end
end)
line.spine=line:CreateTexture(nil,"ARTWORK")
line.spine:SetPoint("TOPLEFT",line,"TOPLEFT",0,0)
line.spine:SetPoint("BOTTOMLEFT",line,"BOTTOMLEFT",0,0)
line.spine:SetWidth(A.metric("classEdge"))
line.disp=line:CreateFontString(nil,"ARTWORK","GameFontHighlightSmall")
line.disp:SetJustifyH("RIGHT")
line.disp:SetWordWrap(false)
line.meterHovers={}
for _,cell in ipairs({line.disp})do
local hover=CreateFrame("Button",nil,line)
hover:SetAllPoints(cell)
hover:SetScript("OnEnter",function(self)
if type(self.words)=="table"then
A.keyedTooltip(self,self.words,"ANCHOR_BOTTOM","meter")
end
end)
hover:SetScript("OnLeave",A.hideTooltip)
hover:Hide()
line.meterHovers[#line.meterHovers+1]=hover
end
line.kb=line:CreateFontString(nil,"ARTWORK","GameFontHighlightSmall")
line.kb:SetJustifyH("RIGHT")
line.heal=line:CreateFontString(nil,"ARTWORK","GameFontHighlightSmall")
line.heal:SetJustifyH("RIGHT")
line.heal:SetWordWrap(false)
line.damage=line:CreateFontString(nil,"ARTWORK","GameFontHighlightSmall")
line.damage:SetJustifyH("RIGHT")
line.damage:SetWordWrap(false)
line.track=line:CreateTexture(nil,"BACKGROUND")
line.objectives={}
for i=1,A.metric("rowObjectiveMax")do
local cell=line:CreateFontString(nil,"ARTWORK","GameFontHighlightSmall")
cell:SetJustifyH("RIGHT")
cell:SetWordWrap(false)
line.objectives[i]=cell
end
line.fill=line:CreateTexture(nil,"OVERLAY")
line.healTrack=line:CreateTexture(nil,"BACKGROUND")
line.healFill=line:CreateTexture(nil,"BORDER")
line.role=line:CreateFontString(nil,"ARTWORK","GameFontHighlightSmall")
line.role:SetJustifyH("LEFT")
line.role:SetWordWrap(false)
line.spec=line:CreateFontString(nil,"ARTWORK","GameFontHighlightSmall")
line.spec:SetJustifyH("LEFT")
line.spec:SetWordWrap(false)
line.name=line:CreateFontString(nil,"ARTWORK","GameFontHighlightSmall")
line.name:SetWidth(A.metric("rowName"))
line.name:SetJustifyH("LEFT")
line.name:SetWordWrap(false)
line.icon=line:CreateTexture(nil,"ARTWORK")
line.wash=line:CreateTexture(nil,"BACKGROUND")
line.wash:SetAllPoints(line)
line.teamRowRegions={line.icon,line.wash}
rowLook.layout(line,nil,0,nil)
line.rowRegions={line.spine,line.disp,line.kb,line.heal,line.damage,line.track,
line.fill,line.healTrack,line.healFill,line.role,line.spec,line.name}
for i=1,#line.objectives do
line.rowRegions[#line.rowRegions+1]=line.objectives[i]
end
line.headDelta=line:CreateFontString(nil,"ARTWORK","GameFontNormalLarge")
line.headDelta:SetPoint("RIGHT",line,"RIGHT",-A.metric("rowCellGap"),0)
line.headDelta:SetJustifyH("RIGHT")
line.headDelta:SetWordWrap(false)
line.headRatings=line:CreateFontString(nil,"ARTWORK","GameFontHighlightSmall")
line.headRatings:SetPoint("RIGHT",line.headDelta,"LEFT",-A.metric("headGap"),0)
line.headRatings:SetJustifyH("RIGHT")
line.headRatings:SetWordWrap(false)
line.headDetails=line:CreateFontString(nil,"ARTWORK","GameFontHighlightSmall")
line.headDetails:SetPoint("RIGHT",line,"RIGHT",-A.metric("rowCellGap"),0)
line.headDetails:SetJustifyH("RIGHT")
line.headDetails:SetWordWrap(false)
line.headCrest=line:CreateTexture(nil,"ARTWORK")
line.headCrest:SetPoint("LEFT",line,"LEFT",0,0)
line.headCrest:Hide()
line.headResult=line:CreateFontString(nil,"ARTWORK","GameFontNormal")
line.headResult:SetPoint("LEFT",line,"LEFT",0,0)
line.headResult:SetJustifyH("LEFT")
line.headResult:SetWordWrap(false)
line.headMark=line:CreateFontString(nil,"ARTWORK","GameFontDisableSmall")
line.headMark:SetPoint("LEFT",line.headResult,"RIGHT",A.metric("headGap"),0)
line.headMark:SetJustifyH("LEFT")
line.headMark:SetWordWrap(false)
line.headDate=line:CreateFontString(nil,"ARTWORK","GameFontHighlightSmall")
line.headDate:SetPoint("LEFT",line.headMark,"RIGHT",A.metric("headGap"),0)
line.headDate:SetJustifyH("LEFT")
line.headDate:SetWordWrap(false)
line.headRegions={line.headCrest,line.headResult,line.headMark,line.headDate,
line.headRatings,line.headDetails,line.headDelta}
line.objBg=line:CreateTexture(nil,"BACKGROUND")
line.objBg:SetAllPoints(line)
line.objEdge=line:CreateTexture(nil,"BORDER")
line.objEdge:SetPoint("TOPLEFT",line,"TOPLEFT",0,0)
line.objEdge:SetPoint("TOPRIGHT",line,"TOPRIGHT",0,0)
line.objEdge:SetHeight(1)
line.objTitle=line:CreateFontString(nil,"ARTWORK","GameFontDisableSmall")
line.objTitle:SetPoint("TOPLEFT",line,"TOPLEFT",
A.metric("objectivesPad"),-A.metric("objectivesPad"))
line.objTitle:SetJustifyH("LEFT")
line.objTitle:SetWordWrap(false)
local function sideRow(above)
local label=line:CreateFontString(nil,"ARTWORK","GameFontDisableSmall")
label:SetPoint("TOPLEFT",above,"BOTTOMLEFT",0,-A.metric("objectivesGap"))
label:SetWidth(A.metric("objectivesSide"))
label:SetJustifyH("LEFT")
label:SetWordWrap(false)
local cells={}
for c=1,darkList.OBJECTIVE_CELLS do
local cell={}
cell.value=line:CreateFontString(nil,"ARTWORK","GameFontNormalLarge")
cell.value:SetJustifyH("RIGHT")
cell.value:SetWordWrap(false)
cell.label=line:CreateFontString(nil,"ARTWORK","GameFontDisableSmall")
cell.label:SetJustifyH("LEFT")
cell.label:SetWordWrap(false)
local left=(c==1)and label or cells[c-1].label
cell.value:SetPoint("LEFT",left,"RIGHT",A.metric("objectivesGap"),0)
cell.value:SetWidth(A.metric("objectivesCell")*0.4)
cell.label:SetPoint("LEFT",cell.value,"RIGHT",4,0)
cell.label:SetWidth(A.metric("objectivesCell")*0.6)
cells[c]=cell
end
return label,cells
end
line.objYours,line.objYoursCells=sideRow(line.objTitle)
line.objTheirs,line.objTheirsCells=sideRow(line.objYours)
line.objRegions={line.objBg,line.objEdge,line.objTitle,
line.objYours,line.objTheirs}
for _,cells in ipairs({line.objYoursCells,line.objTheirsCells})do
for c=1,#cells do
line.objRegions[#line.objRegions+1]=cells[c].value
line.objRegions[#line.objRegions+1]=cells[c].label
end
end
line.paceBg=line:CreateTexture(nil,"BACKGROUND")
line.paceBg:SetAllPoints(line)
line.paceEdge=line:CreateTexture(nil,"BORDER")
line.paceEdge:SetPoint("TOPLEFT",line,"TOPLEFT",0,0)
line.paceEdge:SetPoint("TOPRIGHT",line,"TOPRIGHT",0,0)
line.paceEdge:SetHeight(1)
line.paceTitle=line:CreateFontString(nil,"ARTWORK","GameFontDisableSmall")
line.paceTitle:SetPoint("TOPLEFT",line,"TOPLEFT",
A.metric("objectivesPad"),-A.metric("objectivesPad"))
line.paceTitle:SetJustifyH("LEFT")
line.paceTitle:SetWordWrap(false)
line.paceRows={}
for i=1,darkList.PACE_ROWS do
local row={}
row.label=line:CreateFontString(nil,"ARTWORK","GameFontDisableSmall")
row.label:SetWidth(A.metric("paceLabel"))
row.label:SetJustifyH("LEFT")
row.label:SetWordWrap(false)
local above=(i==1)and line.paceTitle or line.paceRows[i-1].label
row.label:SetPoint("TOPLEFT",above,"BOTTOMLEFT",0,
(i==1)and-A.metric("objectivesGap")or-A.metric("paceGap"))
row.value=line:CreateFontString(nil,"ARTWORK","GameFontHighlightSmall")
row.value:SetPoint("TOPRIGHT",line,"TOPRIGHT",-A.metric("objectivesPad"),0)
row.value:SetPoint("TOP",row.label,"TOP",0,0)
row.value:SetWidth(A.metric("paceValue"))
row.value:SetJustifyH("RIGHT")
row.value:SetWordWrap(false)
row.track=line:CreateTexture(nil,"BACKGROUND")
row.track:SetPoint("LEFT",row.label,"RIGHT",A.metric("objectivesGap"),0)
row.track:SetSize(A.paceTrackWidth(),A.metric("paceRow")-4)
row.fill=line:CreateTexture(nil,"OVERLAY")
row.fill:SetPoint("TOPLEFT",row.track,"TOPLEFT",0,0)
row.fill:SetPoint("BOTTOMLEFT",row.track,"BOTTOMLEFT",0,0)
line.paceRows[i]=row
end
line.paceRegions={line.paceBg,line.paceEdge,line.paceTitle}
for i=1,#line.paceRows do
local row=line.paceRows[i]
line.paceRegions[#line.paceRegions+1]=row.label
line.paceRegions[#line.paceRegions+1]=row.value
line.paceRegions[#line.paceRegions+1]=row.track
line.paceRegions[#line.paceRegions+1]=row.fill
end
local lobbySet=A.rowColumns("lobby")or{}
local paneSet=A.rowColumns("lobbyPane")or{}
local lobbyColumns=math.max(#lobbySet,#paneSet)
line.lobbyHeadNames={}
line.lobbyGroupNames={}
line.lobbyCells={}
for i=1,lobbyColumns do
local name=line:CreateFontString(nil,"ARTWORK","GameFontDisableSmall")
name:SetJustifyH("LEFT")
name:SetWordWrap(false)
line.lobbyHeadNames[i]=name
local group=line:CreateFontString(nil,"ARTWORK","GameFontDisableSmall")
group:SetJustifyH("LEFT")
group:SetWordWrap(false)
line.lobbyGroupNames[i]=group
local cell=line:CreateFontString(nil,"ARTWORK","GameFontHighlightSmall")
cell:SetJustifyH("LEFT")
cell:SetWordWrap(false)
line.lobbyCells[i]=cell
end
line.lobbyRounds={}
line.lobbyRoundButtons={}
for i=1,#lobbySet do
local column=lobbySet[i]
if column.lane=="round"then
local parts={}
parts.ground=line:CreateTexture(nil,"BACKGROUND")
line.lobbyRounds[column.round]=parts
local button=CreateFrame("Button",nil,line)
button:RegisterForClicks("LeftButtonUp","RightButtonUp")
button:SetScript("OnClick",commitRound)
button:SetScript("OnEnter",function(self)
local lines={self.state=="typed"and"Click to clear."or"Left: won. Right: lost."}
if type(self.meterWords)=="table"then
for w=2,#self.meterWords do
lines[#lines+1]=self.meterWords[w]
end
end
A.keyedTooltip(self,lines,"ANCHOR_BOTTOM","round")
end)
button:SetScript("OnLeave",A.hideTooltip)
button:Hide()
line.lobbyRoundButtons[column.round]=button
end
end
line.lobbyRoundHovers={}
for i=1,#lobbySet do
local column=lobbySet[i]
if column.lane=="round"then
local hover=CreateFrame("Button",nil,line)
hover:SetScript("OnEnter",function(self)
if type(self.words)=="table"then
A.keyedTooltip(self,self.words,"ANCHOR_BOTTOM","lobbyround")
end
end)
hover:SetScript("OnLeave",A.hideTooltip)
hover:Hide()
line.lobbyRoundHovers[column.round]=hover
end
end
line.lobbyGroupHovers={}
for i=1,lobbyColumns do
local hover=CreateFrame("Button",nil,line)
hover:SetScript("OnEnter",function(self)
if type(self.words)=="table"then
A.keyedTooltip(self,self.words,"ANCHOR_BOTTOM","lobbygroup")
end
end)
hover:SetScript("OnLeave",A.hideTooltip)
hover:Hide()
line.lobbyGroupHovers[i]=hover
end
line.lobbyHeadRule=line:CreateTexture(nil,"BORDER")
line.lobbyHeadRule:SetHeight(1)
line.lobbyYouRule=line:CreateTexture(nil,"BORDER")
line.lobbyYouRule:SetHeight(1)
line.lobbyFootText=line:CreateFontString(nil,"ARTWORK","GameFontDisableSmall")
line.lobbyFootText:SetWordWrap(false)
line.lobbySorts={}
for i=1,lobbyColumns do
local sort=CreateFrame("Button",nil,line)
sort:SetHeight(A.metric("rosterHeadRow"))
sort:RegisterForClicks("LeftButtonUp")
sort:SetScript("OnClick",function(button)
if type(button.sortKey)=="string"then
A.clickLobbySort(button.sortKey)
end
end)
sort:Hide()
line.lobbySorts[i]=sort
end
line.lobbyRegions={line.lobbyHeadRule,line.lobbyYouRule,line.lobbyFootText}
for i=1,lobbyColumns do
line.lobbyRegions[#line.lobbyRegions+1]=line.lobbyHeadNames[i]
line.lobbyRegions[#line.lobbyRegions+1]=line.lobbyGroupNames[i]
line.lobbyRegions[#line.lobbyRegions+1]=line.lobbyCells[i]
end
for _,parts in pairs(line.lobbyRounds)do
line.lobbyRegions[#line.lobbyRegions+1]=parts.ground
end
local function headLabel(justify)
local label=line:CreateFontString(nil,"ARTWORK","GameFontDisableSmall")
label:SetJustifyH(justify)
label:SetWordWrap(false)
return label
end
line.rosterTitle=headLabel("LEFT")
line.rosterDisp=headLabel("RIGHT")
line.rosterKb=headLabel("RIGHT")
line.rosterHeal=headLabel("RIGHT")
line.rosterDamage=headLabel("LEFT")
line.rosterRole=headLabel("LEFT")
line.rosterSpec=headLabel("LEFT")
line.rosterObjectives={}
for i=1,A.metric("rowObjectiveMax")do
line.rosterObjectives[i]=headLabel("RIGHT")
end
line.teamWord=headLabel("RIGHT")
line.teamHealLabel=headLabel("RIGHT")
line.teamHeal=headLabel("RIGHT")
line.teamDamageLabel=headLabel("RIGHT")
line.teamDamage=headLabel("RIGHT")
line.rosterRule=line:CreateTexture(nil,"ARTWORK")
line.rosterRule:SetPoint("BOTTOMLEFT",line,"BOTTOMLEFT",0,0)
line.rosterRule:SetPoint("BOTTOMRIGHT",line,"BOTTOMRIGHT",0,0)
line.rosterRule:SetHeight(1)
line.rosterRegions={line.rosterTitle,line.rosterSpec,line.rosterRole,
line.rosterDamage,line.rosterHeal,line.rosterKb,line.rosterDisp,
line.rosterRule,line.teamWord,line.teamHealLabel,line.teamHeal,
line.teamDamageLabel,line.teamDamage}
for i=1,#line.rosterObjectives do
line.rosterRegions[#line.rosterRegions+1]=line.rosterObjectives[i]
end
rowLook.headLayout(line,nil,0,nil)
line.rosterSorts={}
local sortable={line.rosterTitle,line.rosterDamage,line.rosterHeal,line.rosterKb,
line.rosterDisp}
for i=1,#line.rosterObjectives do
sortable[#sortable+1]=line.rosterObjectives[i]
end
for _,label in ipairs(sortable)do
local sort=CreateFrame("Button",nil,line)
sort:SetPoint("TOP",line,"TOP",0,0)
sort:SetPoint("BOTTOM",line,"BOTTOM",0,0)
sort:SetPoint("LEFT",label,"LEFT",0,0)
sort:SetPoint("RIGHT",label,"RIGHT",0,0)
sort:RegisterForClicks("LeftButtonUp")
sort:SetScript("OnClick",function(button)
if type(button.sortKey)=="string"then
A.clickScoreSort(button.sortKey,button.sortIndex,button.sortUp)
end
end)
sort:Hide()
line.rosterSorts[#line.rosterSorts+1]=sort
end
A.buildMatchHeadParts(line)
end
A.style(line.label,"bodyText","text")
line.hover:SetColorTexture(A.color("hover"))
local row,head=data.cells,data.head
local totals=head and head.kind=="objectives"and head.totals or nil
local roster=head and head.kind=="roster"and head or nil
local pacing=head and head.kind=="pacing"and head.pacing or nil
local lobbyPaint={
lobbyGroup=paintLobbyGroup,
lobbyHead=paintLobbyHead,
lobbyRow=paintLobbyRow,
lobbyYou=paintLobbyYou,
lobbyFoot=paintLobbyFoot,
rosterFoot=rowLook.foot,
}
local lobby=head and lobbyPaint[head.kind]or nil
for _,regions in ipairs({line.rowRegions,line.headRegions,line.objRegions,
line.rosterRegions,line.paceRegions,line.lobbyRegions,line.teamRowRegions})do
hideAll(regions)
end
for i=1,#line.lobbySorts do
line.lobbySorts[i]:Hide()
line.lobbySorts[i].sortKey=nil
end
for i=1,#line.rosterSorts do
line.rosterSorts[i]:Hide()
line.rosterSorts[i].sortKey,line.rosterSorts[i].sortIndex=nil,nil
line.rosterSorts[i].sortUp=nil
end
for _,button in pairs(line.lobbyRoundButtons)do
button:Hide()
button.recordId,button.round,button.state=nil,nil,nil
end
for i=1,#line.lobbyGroupHovers do
line.lobbyGroupHovers[i]:Hide()
line.lobbyGroupHovers[i].words=nil
end
for i=1,#line.meterHovers do
line.meterHovers[i]:Hide()
line.meterHovers[i].words=nil
end
for _,hover in pairs(line.lobbyRoundHovers)do
hover:Hide()
hover.words=nil
end
for _,button in pairs(line.lobbyRoundButtons)do
button.meterWords=nil
end
if row then
line.label:SetText("")
line.label:Hide()
line.name:SetWidth(type(data.nameWidth)=="number"and data.nameWidth or A.metric("rowName"))
paintRow(line,row)
elseif totals then
line.label:SetText("")
line.label:Hide()
if head.look=="team"then
A.paintTeamCards(line,head)
else
paintObjectives(line,totals)
end
elseif pacing then
line.label:SetText("")
line.label:Hide()
paintPacing(line,pacing)
elseif lobby then
line.label:SetText("")
line.label:Hide()
lobby(line,head)
elseif roster then
line.label:SetText("")
line.label:Hide()
paintRosterHead(line,roster)
elseif head then
line.label:SetText("")
line.label:Hide()
paintHead(line,head)
else
line.label:Show()
if data.stamps then
A.style(line.label,"numberSmall","dimmer")
end
line.label:SetText(data.text)
end
line.participantGuid=data.guid
line:EnableMouse(data.guid~=nil)
if data.guid~=nil then
line.hover:Show()
else
line.hover:Hide()
end
end
local function buildChip(row,index)
local chip={}
chip.share=row:CreateTexture(nil,"BACKGROUND")
chip.swatch=row:CreateTexture(nil,"ARTWORK")
chip.swatch:SetSize(A.metric("compSwatch"),A.metric("compSwatch"))
chip.label=row:CreateFontString(nil,"ARTWORK","GameFontHighlightSmall")
chip.label:SetJustifyH("LEFT")
chip.label:SetWordWrap(false)
if index==1 then
chip.swatch:SetPoint("LEFT",row,"LEFT",A.metric("rowNamePad"),0)
end
chip.label:SetPoint("LEFT",chip.swatch,"RIGHT",4,0)
chip.share:SetPoint("LEFT",chip.swatch,"LEFT",-3,0)
chip.share:SetHeight(A.metric("compRow")-8)
return chip
end
function A.buildFloorLine(parent)
local line=CreateFrame("Button",nil,parent)
line:SetHeight(A.metric("rowHeight"))
line:RegisterForClicks("LeftButtonUp")
line.hover=line:CreateTexture(nil,"HIGHLIGHT")
line.hover:SetAllPoints(line)
line.caret=line:CreateFontString(nil,"ARTWORK","GameFontDisableSmall")
line.caret:SetPoint("LEFT",line,"LEFT",A.metric("rowLabelPad"),0)
line.caret:SetJustifyH("LEFT")
line.caret:SetWordWrap(false)
line.text=line:CreateFontString(nil,"ARTWORK","GameFontDisableSmall")
line.text:SetPoint("LEFT",line.caret,"RIGHT",A.metric("chipGap"),0)
line.text:SetPoint("RIGHT",line,"RIGHT",0,0)
line.text:SetJustifyH("LEFT")
line.text:SetWordWrap(false)
line:SetScript("OnClick",function()
if type(A.clickAskUnder)=="function"then
A.clickAskUnder()
end
end)
line:Hide()
return line
end
function A.paintFloorLine(line,text)
if line==nil then
return false
end
if type(text)~="string"or text==""then
line:Hide()
return false
end
line.caret:SetText(A.askUnderShown()and"-"or"+")
A.style(line.caret,"rowNote","dim")
line.text:SetText(text)
A.style(line.text,"rowNote","dim")
line.hover:SetColorTexture(A.color("hover"))
line:Show()
return true
end
function rowSurface.compChipsNeed(labels)
local need=A.metric("rowNamePad")
for i=1,#(labels or{})do
need=need+A.metric("compSwatch")+A.metric("compChipInner")+(labels[i]or 0)
if i>1 then
need=need+A.metric("compChipGap")
end
end
return need
end
function A.compChipsForm(rowWidth,labels,shortLabels)
if type(rowWidth)~="number"or rowWidth<=0 then
return"unmeasured"
end
local figures=0
for _,column in ipairs(A.compColumns(nil))do
figures=figures+column.width+A.metric("rowCellGap")
end
local bound=rowWidth-figures-A.metric("compChipGap")
local need=rowSurface.compChipsNeed(labels)
local needShort=type(shortLabels)=="table"and rowSurface.compChipsNeed(shortLabels)or nil
local form="icons"
if need<=bound then
form="names"
elseif needShort~=nil and needShort<=bound then
form="short"
end
return form,need,bound,needShort
end
function A.compTableChipsForm(rowWidth,rows,shortRows)
local widest,widestShort,bound=nil,nil,nil
local withShort=type(shortRows)=="table"
for i=1,#(rows or{})do
local short=withShort and(shortRows[i]or rows[i])or nil
local each,need,room,needShort=A.compChipsForm(rowWidth,rows[i],short)
if each=="unmeasured"then
return"unmeasured"
end
bound=room
if widest==nil or need>widest then
widest=need
end
if needShort~=nil and(widestShort==nil or needShort>widestShort)then
widestShort=needShort
end
end
local form="names"
if widest~=nil and bound~=nil and widest>bound then
form=(widestShort~=nil and widestShort<=bound)and"short"or"icons"
end
return form,widest,bound,widestShort
end
function rowSurface.compHoverEnter(self)
local members=self.compMembers
if not GameTooltip or type(members)~="table"or#members==0 then
return
end
local drew=pcall(function()
GameTooltip:SetOwner(self,"ANCHOR_RIGHT")
for i=1,#members do
local r,g,b=A.classColor(members[i].classToken)
local text=A.chipText(members[i])
if i==1 then
GameTooltip:SetText(text,r,g,b,1,false)
else
GameTooltip:AddLine(text,r,g,b,false)
end
end
GameTooltip:Show()
end)
if drew and type(A.trace)=="function"then
A.trace("comp-hover",{n=#members,chips=self.chipsForm},"ui")
end
end
function rowSurface.compHoverLeave(self)
if GameTooltip and GameTooltip.GetOwner and GameTooltip:GetOwner()==self then
GameTooltip:Hide()
end
end
local function initComp(row,data)
if not row.compRegions then
row:RegisterForClicks("LeftButtonUp")
row.selection=row:CreateTexture(nil,"BACKGROUND")
row.selection:SetAllPoints(row)
row.selection:Hide()
row.hover=row:CreateTexture(nil,"HIGHLIGHT")
row.hover:SetAllPoints(row)
row:SetScript("OnClick",function(self)
if self.compKey then
A.pickAskRow(self.compKey)
end
end)
row:SetScript("OnEnter",rowSurface.compHoverEnter)
row:SetScript("OnLeave",rowSurface.compHoverLeave)
local cellFor={games="games",record="record",rate="pct",delta="delta",length="length"}
local columns=A.compColumns(nil)
local anchor,point=row,"RIGHT"
for c=#columns,1,-1 do
local cell=row:CreateFontString(nil,"ARTWORK","GameFontHighlightSmall")
cell:SetPoint("RIGHT",anchor,point,-A.metric("rowCellGap"),0)
cell:SetWidth(columns[c].width)
cell:SetJustifyH("RIGHT")
row[cellFor[columns[c].key]]=cell
anchor,point=cell,"LEFT"
end
row.chips={}
for i=1,3 do
row.chips[i]=buildChip(row,i)
if i>1 then
row.chips[i].swatch:SetPoint("LEFT",row.chips[i-1].label,"RIGHT",
A.metric("compChipGap"),0)
end
end
row.compRegions={row.length,row.delta,row.pct,row.record,row.games}
row.dividerKey=row:CreateFontString(nil,"ARTWORK","GameFontDisableSmall")
row.dividerKey:SetPoint("LEFT",row,"LEFT",A.metric("rowNamePad"),0)
row.dividerKey:SetJustifyH("LEFT")
row.dividerKey:SetWordWrap(false)
row.dividerText=row:CreateFontString(nil,"ARTWORK","GameFontDisableSmall")
row.dividerText:SetPoint("LEFT",row.dividerKey,"RIGHT",A.metric("compChipGap"),0)
row.dividerText:SetJustifyH("LEFT")
row.dividerText:SetWordWrap(false)
row.dividerRule=row:CreateTexture(nil,"BORDER")
row.dividerRule:SetPoint("BOTTOMLEFT",row,"BOTTOMLEFT",0,0)
row.dividerRule:SetPoint("BOTTOMRIGHT",row,"BOTTOMRIGHT",0,0)
row.dividerRule:SetHeight(1)
row.dividerRegions={row.dividerKey,row.dividerText,row.dividerRule}
end
for i=1,#row.dividerRegions do
row.dividerRegions[i]:Hide()
end
if type(data)=="table"and type(data.detail)=="table"then
row.compKey=nil
row.compMembers=nil
row:EnableMouse(false)
row.selection:Hide()
for i=1,#row.compRegions do
row.compRegions[i]:Hide()
end
for i=1,#row.chips do
row.chips[i].swatch:Hide()
row.chips[i].label:Hide()
row.chips[i].share:Hide()
end
paintLineFace(row,data.detail,data.room)
return
end
if row.lineFace then
row.lineFace:Hide()
end
if type(data)=="table"and data.divider then
row.compKey=nil
row.compMembers=nil
row:EnableMouse(false)
row.selection:Hide()
for i=1,#row.compRegions do
row.compRegions[i]:Hide()
end
for i=1,#row.chips do
row.chips[i].swatch:Hide()
row.chips[i].label:Hide()
row.chips[i].share:Hide()
end
local key,clause=A.compDivider(activeFormat)
row.dividerKey:SetText(key)
A.style(row.dividerKey,"label","dim")
row.dividerText:SetText(clause)
A.style(row.dividerText,"note","dim")
row.dividerRule:SetColorTexture(A.color("hairline"))
for i=1,#row.dividerRegions do
row.dividerRegions[i]:Show()
end
return
end
local tally=type(data)=="table"and data.row or nil
if type(tally)~="table"then
row.compKey=nil
row.compMembers=nil
row:EnableMouse(false)
row.selection:Hide()
return
end
row.compKey=tally.key
row.compMembers=tally.members
row:EnableMouse(true)
row.hover:SetColorTexture(A.color("hover"))
row.selection:SetColorTexture(A.color("selection"))
row.selection:SetShown(shownAskRow~=nil and tally.key==shownAskRow)
for i=1,#row.compRegions do
row.compRegions[i]:Show()
end
local form=(data.chips=="icons"or data.chips=="short")and data.chips or"names"
local members=tally.members or{}
for i=1,#row.chips do
local chip=row.chips[i]
local m=members[i]
if m==nil then
chip.swatch:Hide()
chip.label:Hide()
chip.share:Hide()
else
A.drawSpec({icon=chip.swatch,name=chip.label},m.classToken,m.spec,
form=="icons"and 0 or nil,
{faint=data.faint==true,class=m.class,gap=A.metric("compChipInner"),
short=form=="short"})
if type(m.share)=="number"and m.share>0 then
local r,g,b=A.classColor(m.classToken)
chip.share:SetColorTexture(r,g,b,A.metric("compShareAlpha"))
chip.share:SetWidth(math.max(1,
math.floor(A.metric("compShareBar")*math.min(1,m.share))))
chip.share:Show()
else
chip.share:Hide()
end
end
end
row.chipsForm=form
local faint=data.faint==true
row.games:SetText(tostring(tally.games))
A.style(row.games,"bodyText",faint and"underText"or"dim")
row.record:SetText(A.compRecordText(tally)or"-")
A.style(row.record,"bodyText",faint and"underText"or"text")
if tally.winRate then
row.pct:SetText(("%d%%"):format(math.floor(tally.winRate*100+0.5)))
local rateTone="dim"
if faint then
rateTone="underText"
elseif tally.ranked~=false then
rateTone=A.winRateTone(tally.winRate)or"dim"
end
A.style(row.pct,"bodyMedium",rateTone)
else
row.pct:SetText("")
end
local delta=A.signedText(tally.ratingDelta)
row.delta:SetText(delta or"")
A.style(row.delta,"bodyText",faint and"underText"or
((tally.ratingDelta or 0)<0 and"loss"or((tally.ratingDelta or 0)>0 and"win"or"dim")))
row.length:SetText(tally.avgDuration and A.clockText(tally.avgDuration)or"")
A.style(row.length,"bodyText",faint and"underText"or"dim")
end
local function detailTextWidth(frame)
local host=frame and frame.detailHost
if not host then
return nil
end
local width=host:GetWidth()
if type(width)~="number"or width<=20 then
return nil
end
width=width-A.metric("detailTextInset")
local bar=frame.detail and frame.detail.bar
if bar and bar:IsShown()then
width=width-A.metric("detailBarInset")
end
return width
end
local function newlineRows(text)
if type(text)~="string"then
return 1
end
local rows=1
for _ in text:gmatch("\n")do
rows=rows+1
end
return rows
end
local function spanRows(text,mono)
local span=window and(mono and window.spanMono or window.span)
local paneWidth=window and window.measuredWidth
if not span or type(paneWidth)~="number"or paneWidth<=0 then
return 1
end
local total=0
for row in(tostring(text).."\n"):gmatch("([^\n]*)\n")do
local ok,width=pcall(function()
span:SetText(row)
return span:GetStringWidth()
end)
if not ok or type(width)~="number"or width<0 then
return 1
end
total=total+math.max(1,math.ceil(width/paneWidth))
end
return math.max(1,total)
end
local function betweenItems(indent,parts,mono)
local span=window and(mono and window.spanMono or window.span)
local paneWidth=window and window.measuredWidth
if not span or type(paneWidth)~="number"or paneWidth<=0 or type(parts)~="table"then
return nil
end
local rows,current={},nil
for i=1,#parts do
local item=tostring(parts[i])
if current==nil then
current=indent..item
else
local candidate=current.."  "..item
local ok,width=pcall(function()
span:SetText(candidate)
return span:GetStringWidth()
end)
if not ok or type(width)~="number"then
return nil
end
if width<=paneWidth then
current=candidate
else
rows[#rows+1]=current
current=indent..item
end
end
end
if current==nil then
return nil
end
rows[#rows+1]=current
return table.concat(rows,"\n")
end
local function lineHeight(text,mono)
local floor=A.metric("lineHeight")*newlineRows(text)
local measure=window and(mono and window.measureMono or window.measure)
if not measure then
return floor
end
local ok,height=pcall(function()
measure:SetText(text)
return measure:GetStringHeight()
end)
local rows=spanRows(text,mono)
if rows>1 then
floor=math.max(floor,rows*A.fontSize(mono and"numberSmall"or"bodyText"))
end
if not ok or type(height)~="number"or height<floor then
return floor
end
return height+2
end
local function applyMeasureWidth(frame)
if not(window and window.measure)then
return false
end
local width=frame and detailTextWidth(frame)or nil
if width==nil then
width=A.detailWindowBody()
end
if window.measuredWidth==width then
return false
end
window.measure:SetWidth(width)
if window.measureMono then
window.measureMono:SetWidth(width)
end
window.measuredWidth=width
return true
end
local function frameHeightOf(frame)
local ok,height=pcall(frame.GetHeight,frame)
if ok and type(height)=="number"and height>0 then
return height
end
return nil
end
local function statedHeight(frame)
if type(frame)~="table"then
return nil
end
local ok,height=pcall(frame.GetHeight,frame,true)
if ok and type(height)=="number"and height>=0 then
return height
end
return nil
end
local function windowHeightFor(frame)
if type(A.rectUnresolved)=="function"and A.rectUnresolved(frame)then
return statedHeight(frame)
end
return frameHeightOf(frame)
end
local function viewRowHeight()
return A.metric("segmentHeight")+A.metric("segmentTrackPad")*2+A.metric("paneGap")
end
function A.listViewportRoom(parts)
if type(parts)~="table"or type(parts.window)~="number"then
return nil
end
local room=parts.window-A.metric("headerHeight")
-(parts.filter or A.metric("filterHeight"))
-A.metric("paneGap")-(parts.viewRow or 1)-(parts.head or 0)
-A.bodyFloor()-(parts.strip or 0)
if type(parts.summary)=="number"then
room=room-A.metric("summaryGap")-parts.summary
end
if room<0 then
room=0
end
return room
end
local function compHostHeight(frame)
return A.listViewportRoom({
window=windowHeightFor(frame),
filter=statedHeight(frame.filterRow),
summary=frame.summary and statedHeight(frame.summary)or nil,
viewRow=statedHeight(frame.viewRow),
head=0,
strip=0,
})
end
local function compTextHeight(text,role,width)
local measure=window and window.compMeasure
if type(text)~="string"or text==""then
return 0
end
if not measure then
return A.fontSize(role)
end
local ok,height=pcall(function()
measure:SetWidth(type(width)=="number"and width or A.compPaneWidth())
A.style(measure,role)
measure:SetText(text)
return measure:GetStringHeight()
end)
if not ok or type(height)~="number"or height<A.fontSize(role)then
return A.fontSize(role)
end
return height
end
local listSnapQueued=false
local function applyPaneLayout(frame,columns,rowCount)
frame.viewRow:SetHeight(viewRowHeight())
local listing=activeBody~="stats"
frame.listHost:ClearAllPoints()
if listing then
frame.listHost:SetPoint("TOPLEFT",frame.summary or frame.filterRow,"BOTTOMLEFT",0,
-A.metric("paneGap"))
else
frame.listHost:SetPoint("TOPLEFT",frame.viewRow,"BOTTOMLEFT",0,0)
end
frame.listHost:SetPoint("BOTTOMLEFT",frame,"BOTTOMLEFT",
A.metric("margin"),A.bodyFloor())
local hostWidth=A.listHostWidth(false)
frame.listHost:SetWidth(hostWidth)
if frame.listGround~=nil then
frame.listGround:SetColorTexture(A.color("listGround"))
frame.listGround:SetShown(listing)
for _,edge in ipairs(frame.listEdges or{})do
edge:SetColorTexture(A.color("listEdge"))
edge:SetShown(listing)
end
end
if frame.duelPanel then
frame.duelPanel:ClearAllPoints()
frame.duelPanel:SetPoint("TOPLEFT",frame.listHost,"TOPRIGHT",A.metric("paneSplitGap"),0)
frame.duelPanel:SetPoint("BOTTOMLEFT",frame.listHost,"BOTTOMRIGHT",A.metric("paneSplitGap"),0)
frame.duelPanel:SetWidth(A.metric("duelPanel"))
end
frame.viewRow:ClearAllPoints()
frame.viewRow:SetPoint("TOPLEFT",frame.viewRowAnchor or frame.filterRow,"BOTTOMLEFT",0,
-A.metric("paneGap"))
frame.viewRow:SetWidth(hostWidth)
if frame.askHost then
local askLeft=A.askSplitWidth()
frame.askHost:ClearAllPoints()
frame.askHost:SetPoint("TOPLEFT",frame.viewRow,"BOTTOMLEFT",0,0)
frame.askPaneHost:ClearAllPoints()
if A.specsShowing()or A.tableViewShowing()~=nil or A.askAcross()then
askLeft=hostWidth
frame.askHost:SetWidth(hostWidth)
frame.askHost:SetHeight(1)
frame.askPaneHost:SetPoint("TOPLEFT",frame.viewRow,"BOTTOMLEFT",0,0)
else
frame.askHost:SetPoint("BOTTOMLEFT",frame,"BOTTOMLEFT",
A.metric("margin"),A.bodyFloor())
frame.askHost:SetWidth(askLeft)
frame.askPaneHost:SetPoint("TOPLEFT",frame.viewRow,"BOTTOMLEFT",
askLeft+A.metric("paneSplitGap"),0)
end
frame.askPaneHost:SetPoint("BOTTOMRIGHT",frame,"BOTTOMRIGHT",
-A.metric("margin")-A.metric("paneRightPad"),A.bodyFloor())
frame.compHost:ClearAllPoints()
frame.compHost:SetPoint("TOPLEFT",frame.askPaneHost,"TOPLEFT",0,0)
frame.compHost:SetPoint("BOTTOMRIGHT",frame.askPaneHost,"BOTTOMRIGHT",0,0)
frame.askHead:SetWidth(askLeft)
end
local gridHead=darkList.namesInList and darkList.grid or nil
local head=columns~=nil and rowCount>0 and(not darkList.namesInList or gridHead~=nil)
frame.listHead:SetShown(head)
frame.list.box:ClearAllPoints()
if head then
frame.list.box:SetPoint("TOPLEFT",frame.listHead,"BOTTOMLEFT",0,0)
frame.list.box:SetPoint("TOPRIGHT",frame.listHead,"BOTTOMRIGHT",0,0)
else
frame.list.box:SetPoint("TOPLEFT",frame.listHost,"TOPLEFT",0,-A.listSearchBand())
frame.list.box:SetPoint("TOPRIGHT",frame.listHost,"TOPRIGHT",0,-A.listSearchBand())
end
local function anchorList(extra)
frame.list.box:SetPoint("BOTTOMLEFT",frame.listHost,"BOTTOMLEFT",0,extra)
frame.list.box:SetPoint("BOTTOMRIGHT",frame.listHost,"BOTTOMRIGHT",0,extra)
end
local room=A.listViewportRoom({
window=windowHeightFor(frame),
filter=statedHeight(frame.filterRow),
summary=frame.summary and statedHeight(frame.summary)or nil,
viewRow=listing and 0 or viewRowHeight(),
head=(head and A.metric("rowHeadRow")or 0)+A.listSearchBand(),
strip=0,
})
anchorList(0)
frame.listRoom=type(room)=="number"and room or nil
frame.list.cutFoot=true
frame.list.composedExtent=frame.listRoom
if type(A.noteViewport)=="function"then
local rect,why=A.bandHeight(frame.list.box)
A.noteViewport("the match list",frame.listRoom,A.metric("rowListRow"),true,why,frame.list.box,
{composed=true,rect=rect,box=frame.list.name.."ScrollBox"})
end
frame.list.bar:ClearAllPoints()
frame.list.bar:SetPoint("TOPLEFT",frame.listHost,"TOPRIGHT",4,-A.listSearchBand())
frame.list.bar:SetPoint("BOTTOMLEFT",frame.listHost,"BOTTOMRIGHT",4,0)
frame.listTableSpan=nil
if columns==nil or rowCount==0 then
return
end
if gridHead~=nil then
local _,gridWidths=paintColumnHead(frame.listHead,frame.listHeadNames,frame.listHeadRule,
gridHead.columns,nil,"labelMuted")
frame.listTableSpan=spanOfWidths(columnWidths(columns))
darkList.placeHeadMore(frame,gridHead,gridWidths)
elseif head then
frame.listTableSpan=paintColumnHead(frame.listHead,frame.listHeadNames,
frame.listHeadRule,columns,nil,"labelMuted")
else
frame.listTableSpan=spanOfWidths(columnWidths(columns))
end
frame.listHeadRule:SetColorTexture(A.color("insetEdge"))
end
function A.buildScroller(name,parent,frameType,initializer,extent,subject)
local box=CreateFrame("Frame",name.."ScrollBox",parent,"WowScrollBoxList")
local bar=CreateFrame("EventFrame",name.."ScrollBar",parent,"MinimalScrollBar")
local view=CreateScrollBoxListLinearView()
if type(extent)=="function"then
view:SetElementExtentCalculator(extent)
else
view:SetElementExtent(extent)
end
view:SetElementInitializer(frameType,initializer)
ScrollUtil.InitScrollBoxListWithScrollBar(box,bar,view)
pcall(bar.SetHideIfUnscrollable,bar,true)
return{name=name,subject=subject,box=box,bar=bar,view=view}
end
local function paintListPin(scroller,edges)
local pin=scroller and scroller.pin
if not pin then
return false
end
local row=(edges and edges.pinned and type(scroller.rows)=="table")and scroller.rows[edges.pinned]or nil
if type(row)~="table"then
pin:Hide()
return false
end
local box=scroller.box
local okLevel,level=pcall(box.GetFrameLevel,box)
if okLevel and type(level)=="number"then
pcall(pin.SetFrameLevel,pin,level+5)
end
local trail=0
local okWidth,width=pcall(pin.GetWidth,pin)
local span=window and window.listTableSpan
if okWidth and type(width)=="number"and width>0 and type(span)=="number"and span>0
and span<width then
trail=width-span
end
pin.rule:ClearAllPoints()
pin.rule:SetPoint("TOPLEFT",pin,"TOPLEFT",A.metric("rowLabelPad"),0)
pin.rule:SetPoint("TOPRIGHT",pin,"TOPRIGHT",-(A.metric("rowLabelPad")+trail),0)
pin.count:ClearAllPoints()
pin.count:SetPoint("TOPRIGHT",pin,"TOPRIGHT",-(A.metric("rowLabelPad")+trail),
-A.metric("rowExpandPad"))
pin.ground:SetColorTexture(A.color("pinGround"))
pin.rule:SetColorTexture(A.color("sessionRule"))
pin:SetHeight(scroller.pinHeight or A.metric("rowDayRow"))
local line=pin.line
if line~=nil then
darkList.hideGrid(line)
if row.grid then
line:SetHeight(row.height or A.metric("gridRow"))
darkList.layoutGrid(line,row)
line:Show()
else
line:Hide()
end
end
local gridLine=row.grid==true and line~=nil
pin.name:SetShown(not gridLine)
pin.count:SetShown(not gridLine)
A.style(pin.name,"label","accent")
A.style(pin.count,"label","dim")
pin.name:SetText(gridLine and""or(row.text or""))
pin.count:SetText(gridLine and""or(row.count or""))
local names=pin.names
local after=scroller.rows[edges.pinned+1]
if names then
if scroller.pinNames and type(after)=="table"and after.names and type(after.columns)=="table"then
paintColumnHead(names,names.cells,nil,after.columns,nil,"labelMuted")
names.rule:ClearAllPoints()
names.rule:SetPoint("BOTTOMLEFT",names,"BOTTOMLEFT",0,0)
names.rule:SetPoint("BOTTOMRIGHT",names,"BOTTOMRIGHT",-trail,0)
names.rule:SetColorTexture(A.color("hairline"))
names:SetHeight(A.metric("rowHeadRow"))
names:Show()
else
names:Hide()
end
end
pin:Show()
return true
end
local function applyWholeRows(scroller)
local box=scroller and scroller.box
if not box then
return nil
end
local okO,offset=pcall(box.GetDerivedScrollOffset,box)
local okV,visible=pcall(box.GetVisibleExtent,box)
local composed=scroller.composedExtent
if type(composed)=="number"and composed>0 then
visible,okV=composed,true
end
if not(okO and okV and type(offset)=="number"and type(visible)=="number")then
return nil
end
local edges=A.rowEdges(scroller.rows,offset,visible,scroller.wholeBase,scroller.pinHeight,
scroller.cutFoot)
edges.offset=offset
edges.visible=visible
paintListPin(scroller,edges)
local hidden=0
pcall(box.ForEachFrame,box,function(frame)
local okI,index=pcall(frame.GetElementDataIndex,frame)
if okI and type(index)=="number"then
local drawn=edges.first~=nil and index>=edges.first and index<=edges.last
frame:SetShown(drawn)
if not drawn then
hidden=hidden+1
end
end
end)
edges.hidden=hidden
scroller.edges=edges
return edges
end
function A.holdWholeRows(scroller,base,pin)
local box=scroller and scroller.box
if not box or type(box.RegisterCallback)~="function"then
return false
end
scroller.wholeBase=base
scroller.pinHeight=(type(pin)=="number"and pin>0)and pin or nil
local function reapply()
pcall(applyWholeRows,scroller)
end
for _,event in ipairs({"OnScroll","OnLayout","OnDataRangeChanged"})do
pcall(box.RegisterCallback,box,event,reapply,scroller)
end
pcall(box.SetScript,box,"OnMouseWheel",function(self,delta)
local stepped=pcall(function()
if type(self.IsScrollAllowed)=="function"and not self:IsScrollAllowed()then
return
end
local offset=self:GetDerivedScrollOffset()
local visible=scroller.composedExtent
if type(visible)~="number"or visible<=0 then
visible=self:GetVisibleExtent()
end
local wholeBase=scroller.wholeBase or base
local before=A.rowEdges(scroller.rows,offset,visible,wholeBase,scroller.pinHeight)
local target=A.rowStep(scroller.rows,offset,visible,wholeBase,
delta<0 and 2 or-2,scroller.pinHeight)
self:ScrollToOffset(target,true)
local okAfter,landed=pcall(self.GetDerivedScrollOffset,self)
landed=okAfter and landed or nil
scroller.wheelLanded={offset=type(landed)=="number"and landed or target,
sign=delta<0 and 1 or-1,at=type(GetTime)=="function"and GetTime()or nil}
local after=type(landed)=="number"
and A.rowEdges(scroller.rows,landed,visible,wholeBase,scroller.pinHeight)or{}
local okExtent,extent=pcall(self.GetDerivedExtent,self)
rowSurface.traceWheel(scroller,{
delta=delta,offset=A.unitFigure(offset),target=A.unitFigure(target),
landed=A.unitFigure(landed),first=before.first,firstAfter=after.first,
content=A.unitFigure(before.content),extent=okExtent and A.unitFigure(extent)or nil,
range=A.unitFigure(before.range),
})
end)
if not stepped and type(self.OnMouseWheel)=="function"then
pcall(self.OnMouseWheel,self,delta)
end
end)
return true
end
function A.snapWholeRows(scroller)
local box=scroller and scroller.box
if not(box and scroller.wholeBase)then
return false
end
local okUp,up=pcall(box.IsVisible,box)
if not(okUp and up)then
return false
end
local edges=applyWholeRows(scroller)
local landed=scroller.wheelLanded
scroller.wheelLanded=nil
if not edges or edges.range<=0 or edges.atEnd then
return false
end
if math.abs(edges.snap-edges.offset)<=0.5 then
return false
end
if type(landed)=="table"and type(landed.at)=="number"and type(GetTime)=="function"
and GetTime()-landed.at>1 then
landed=nil
end
if type(landed)=="table"and type(landed.offset)=="number"
and((landed.sign>0 and edges.snap<landed.offset-0.5)
or(landed.sign<0 and edges.snap>landed.offset+0.5))then
return false
end
local moved=pcall(box.ScrollToOffset,box,edges.snap,true)
applyWholeRows(scroller)
if type(landed)=="table"then
rowSurface.traceWheel(scroller,{offset=A.unitFigure(edges.offset),snapTo=A.unitFigure(edges.snap)})
end
return moved
end
function A.checkListExpansion()
local scroller=window and window.list
local box=scroller and scroller.box
if not(box and type(scroller.rows)=="table")then
return false
end
local held=nil
pcall(box.ForEachFrame,box,function(element)
local okI,index=pcall(element.GetElementDataIndex,element)
local data=okI and scroller.rows[index]or nil
if type(data)=="table"and type(data.expansion)=="string"and data.expansion~=""
and element.expansion then
held={data=data,frame=element}
end
end)
if not held then
return false
end
local data,text=held.data,held.frame.expansion
local okH,drawn=pcall(text.GetStringHeight,text)
local okW,drawnWidth=pcall(text.GetWidth,text)
if not(okH and type(drawn)=="number"and type(data.height)=="number")then
return false
end
local reserved=data.height-A.metric("rowListRow")-A.metric("rowExpandPad")
local over=A.unitFigure(drawn)-A.unitFigure(reserved)
local corrected=over>0.5
if corrected then
data.height=data.height+over
local grown=window.expansionGrown
local before=(type(grown)=="table"and grown.id==data.id
and grown.width==window.expansionMeasured)and grown.over or 0
window.expansionGrown={id=data.id,width=window.expansionMeasured,over=before+over}
A.setRows(scroller,scroller.rows)
end
if type(A.trace)=="function"then
A.trace("expansion",{
id=data.id,measured=A.unitFigure(window.expansionMeasured),
drawnWidth=okW and A.unitFigure(drawnWidth)or nil,reserved=A.unitFigure(reserved),
drawn=A.unitFigure(drawn),lines=(A.fontSize("note")or 0)>0
and math.floor(drawn/A.fontSize("note")+0.5)or nil,
state=corrected and"grown"or"fits",
},"ui")
end
return corrected
end
function A.listEdgeLines()
local scroller=window and window.list
if not scroller then
return{"match list edges  the window has not been built this session"}
end
local head=window.listHead
local okHead,headShown=false,nil
if head then
okHead,headShown=pcall(head.IsShown,head)
end
local headWhy
if not okHead then
headWhy="unanswered"
elseif headShown then
headWhy="shown"
elseif darkList.namesInList then
headWhy="hidden, the session shape naming the columns under each open session"
else
headWhy="hidden, the list holding no rows or no column set, or History not being up"
end
local headLine=("match list header  %s"):format(headWhy)
local edges=scroller.edges
if type(edges)~="table"then
return{"match list edges  no scroll has been decided in this session, which the suite's client never does",
headLine}
end
local out={("match list edges  offset %s of a range of %s, %s visible, elements %s to %s %s, %d hidden at an edge%s%s")
:format(tostring(A.unitFigure(edges.offset)or edges.offset),tostring(A.unitFigure(edges.range)or edges.range),
tostring(A.unitFigure(edges.visible)or edges.visible),tostring(edges.first or"none"),
tostring(edges.last or"none"),edges.cut and"drawn, an edge cutting what crosses it"or"whole",
edges.hidden or 0,edges.atEnd and", at the end of the list"or"",
edges.pinned and(", the day of element "..tostring(edges.pinned).." pinned at the top edge")
or", no day pinned"),headLine}
local drawnFrames={}
local box=scroller.box
if box then
pcall(box.ForEachFrame,box,function(element)
local okI,index=pcall(element.GetElementDataIndex,element)
local okShown,shown=pcall(element.IsShown,element)
if okI and type(index)=="number"and okShown and shown then
drawnFrames[#drawnFrames+1]={index=index,frame=element}
end
end)
end
table.sort(drawnFrames,function(a,b)
return a.index<b.index
end)
local function figure(object,method)
local ok,value=pcall(object[method],object)
return ok and A.unitFigure(value)or nil
end
local boxTop=box and figure(box,"GetTop")or nil
if#drawnFrames==0 then
out[#out+1]="match list element  no element frame is drawn"
end
for i=1,#drawnFrames do
local held=drawnFrames[i]
local kind,extent="no data",nil
local row=type(scroller.rows)=="table"and scroller.rows[held.index]or nil
if type(row)=="table"then
if row.names then
kind="names row"
elseif row.seasonBreak then
kind="season break"
elseif row.session then
kind="session heading"
elseif row.separator then
kind="day heading"
else
kind="record"
end
extent=A.unitFigure(row.height)
end
local height=figure(held.frame,"GetHeight")
local top=figure(held.frame,"GetTop")
local below=(top~=nil and boxTop~=nil)and A.unitFigure(boxTop-top)or nil
out[#out+1]=("match list element %d  %s, extent %s, height %s, top %s")
:format(held.index,kind,tostring(extent or"unanswered"),tostring(height or"unanswered"),
below~=nil and(tostring(below).." below the box's top")or"unanswered")
end
local at=scroller.selectedAt
if type(at)~="number"then
out[#out+1]="match list selection  no element of this list is selected"
return out
end
local where,units,elements=A.rowGap(scroller.rows,at,edges,scroller.wholeBase)
if where==nil then
out[#out+1]=("match list selection  element %d, which this list does not hold"):format(at)
elseif where=="drawn"then
out[#out+1]=("match list selection  element %d, drawn"):format(at)
else
out[#out+1]=("match list selection  element %d, %s the %s edge by %d element%s, %s units off")
:format(at,where,where=="above"and"top"or"foot",elements,elements==1 and""or"s",
tostring(A.unitFigure(units)or units))
end
return out
end
function A.foldControlLines()
if not window then
return{"fold controls  the window has not been built this session"}
end
local names={}
names[window]="the window"
if window.summary then
names[window.summary]="the summary region"
names[window.summary.plot or false]="the graph"
end
names[window.viewRow or false]="the view row"
names[window.compHost or false]="the comps pane"
local function level(frame)
local ok,value=pcall(frame.GetFrameLevel,frame)
return(ok and type(value)=="number")and value or nil
end
local function said(label,control,under)
if not control then
return("%s  not built"):format(label)
end
local okShown,shown=pcall(control.IsShown,control)
local okUp,up=pcall(control.IsVisible,control)
local okPoint,point,relative=pcall(control.GetPoint,control,1)
local okParent,parent=pcall(control.GetParent,control)
local where=(okPoint and type(point)=="string")
and("at %s of %s"):format(point,names[relative]or"an unnamed frame")or"on no point"
local text=("%s  %s, %s, %s, parent %s, level %s"):format(label,
(okShown and shown)and"shown"or"hidden",
(okUp and up)and"visible"or"not visible",
where,(okParent and names[parent])or"an unnamed frame",tostring(level(control)or"unread"))
if under then
text=text..(", over %s at level %s"):format(under.label,tostring(level(under.frame)or"unread"))
end
return text
end
return{
said("graph control",window.summary and window.summary.graphToggle),
}
end
function A.setRows(scroller,rows)
if not scroller then
return false
end
scroller.rows=type(rows)=="table"and rows or nil
local ok,err=pcall(function()
scroller.box:SetDataProvider(CreateDataProvider(rows),true)
end)
if not ok then
local named=type(scroller.name)=="string"and scroller.name~=""
and scroller.name or"an unnamed scroller"
local subject=type(scroller.subject)=="string"and scroller.subject~=""
and scroller.subject or named
A.noteError(("%s did not draw: %s"):format(subject,tostring(err)),
named,type(rows)=="table"and#rows or nil)
end
return ok
end
function A.keepRowInView(scroller,index)
local box=scroller and scroller.box
if not(box and type(index)=="number"and type(box.ScrollToElementDataIndex)=="function")then
return false
end
scroller.keptIndex=index
pcall(box.ScrollToElementDataIndex,box,index,0.5,true)
if type(C_Timer)=="table"and type(C_Timer.After)=="function"then
C_Timer.After(0,function()
if scroller.keptIndex==index then
pcall(box.ScrollToElementDataIndex,box,index,0.5,true)
end
end)
end
return true
end
local function notifyTabSetting()
if A.notifyTabSetting then
A.notifyTabSetting()
end
end
function A.rememberTab()
local db=A.db()
if not db then
return true
end
if type(db.ui)~="table"then
db.ui={}
end
return db.ui.rememberTab~=false
end
function A.setRememberTab(on)
local db=A.db()
if not db then
return false
end
if type(db.ui)~="table"then
db.ui={}
end
if on then
db.ui.rememberTab=nil
else
db.ui.rememberTab=false
end
notifyTabSetting()
return true
end
local function traceView(key,getter)
local ok,value,format=pcall(getter)
local state="unreadable"
if ok then
if value==nil then
state="cleared"
else
state=tostring(value)
end
end
A.trace("view",{source=key,state=state,format=format},"ui")
end
function A.storedCharacter()
local db=A.db()
if not db or type(db.ui)~="table"then
return nil
end
local guid=db.ui.character
if type(guid)~="string"or guid==""then
return nil
end
return guid
end
function A.setStoredCharacter(guid)
local db=A.db()
if not db then
return false
end
if type(db.ui)~="table"then
db.ui={}
end
if type(guid)=="string"and guid~=""then
db.ui.character=guid
else
db.ui.character=nil
end
traceView("character",A.storedCharacter)
return true
end
function A.resetActiveCharacter()
activeCharacter=nil
characterResolved=false
return true
end
function A.storedTab()
local db=A.db()
if not db then
return nil
end
if type(db.ui)~="table"then
db.ui={}
end
if not A.rememberTab()then
return nil
end
local stored=db.ui.tab
if type(stored)~="string"or stored==""then
return nil
end
if type(A.formatCounts)~="function"then
return nil
end
local counts=A.paintWalk("formatCounts")
if(counts[stored]or 0)==0 then
return nil
end
return stored
end
function A.setStoredTab(format)
local db=A.db()
if not db then
return false
end
if type(db.ui)~="table"then
db.ui={}
end
if type(format)=="string"and format~=""then
db.ui.tab=format
else
db.ui.tab=nil
end
traceView("tab",A.storedTab)
return true
end
local SCOPES={
{value="season",label="This season"},
{value="all",label="All time"},
{value="180d",label="Last 6 months",days=180,phrase="last 6 months"},
{value="90d",label="Last 3 months",days=90,phrase="last 3 months"},
{value="30d",label="Last month",days=30,phrase="last month"},
{value="7d",label="Last week",days=7,phrase="last week"},
{value="3d",label="Last 3 days",days=3,phrase="last 3 days"},
{value="1d",label="Last day",days=1,phrase="last day"},
}
local SCOPE_DAY=86400
local VIEW_CARDS={comps="comp",specs="beats"}
function A.windowBody()
return activeBody
end
function A.windowBodyShown()
if not window then
return nil
end
local ok,shown=pcall(window.IsShown,window)
if not(ok and shown)then
return nil
end
return activeBody
end
local BODY_WORDS={history="History",stats="Stats",settings="Settings",about="About"}
function A.windowBodyLabel(body)
local label=BODY_WORDS[body or activeBody]or"History"
if(body or activeBody)=="stats"then
local question=A.askQuestion(A.askShowing())
if question then
label=label..", "..question.title
end
end
return label
end
local activeAsk=nil
local function resolveComps()
if type(A.compTally)~="function"then
return{},0,0,0,0,0
end
local _,season,bound=A.windowScope()
return A.paintWalk("compTally",activeFormat,season,A.windowCharacter(),bound)
end
function A.pickAsk(key)
if A.askQuestion(key)==nil then
return false
end
return A.timedSwitch("view",A.askShowing(),function()
activeAsk=key
traceView("ask",function()
return activeAsk
end)
A.refreshWindow()
return true
end,function()
return A.askShowing()
end)
end
function A.askAcross()
return activeBody=="stats"and activeFormat==nil
end
function A.mapsShowing()
if activeBody~="stats"or type(A.mapsViewShown)~="function"or not A.mapsViewShown()then
return false
end
return A.windowMapsOffered()
end
function A.tableViewShowing()
if activeBody~="stats"then
return nil
end
if A.mapsShowing()then
return"maps"
end
local held=type(A.tableViewShown)=="function"and A.tableViewShown()or nil
if held=="bests"and type(A.bestsViewOffered)=="function"and A.bestsViewOffered(activeFormat)then
return"bests"
end
if held=="builds"and type(A.buildsViewOffered)=="function"and A.buildsViewOffered(activeFormat)then
return"builds"
end
if activeFormat=="world"then
return"zones"
end
return nil
end
function A.specsShowing()
return activeBody=="stats"and type(A.specsViewShown)=="function"and A.specsViewShown()
and type(A.compRounds)=="function"and A.compRounds(activeFormat)and true or false
end
function A.askShowing()
if A.askQuestion(activeAsk)==nil or not A.askOffered(activeAsk,activeFormat)then
return A.askDefault(activeFormat)
end
return activeAsk
end
local function askRowScope()
local _,season,bound=A.windowScope()
return("%s/%s/%s"):format(tostring(season),tostring(bound),tostring(A.windowCharacter()))
end
function A.pickAskRow(key)
if type(key)~="string"or key==""then
return false
end
local question,format,scope=A.askShowing(),activeFormat,askRowScope()
if activeAskRow==key and activeAskRowKey==question
and activeAskRowFormat==format and activeAskRowScope==scope then
activeAskRow,activeAskRowKey,activeAskRowFormat,activeAskRowScope=nil,nil,nil,nil
else
activeAskRow,activeAskRowKey,activeAskRowFormat,activeAskRowScope=
key,question,format,scope
end
A.trace("view",{source="ask-row",state=activeAskRow or"cleared",card=question,
format=activeAskRow and format or nil},"ui")
A.refreshWindow()
return true
end
function A.askRowShowing()
if activeAskRow==nil then
return nil
end
if activeAskRowKey~=A.askShowing()or activeAskRowFormat~=activeFormat
or activeAskRowScope~=askRowScope()then
activeAskRow,activeAskRowKey,activeAskRowFormat,activeAskRowScope=nil,nil,nil,nil
return nil
end
return activeAskRow
end
function A.pickSpec(key)
return A.pickAskRow(key)
end
function A.openSpecMatch(id)
if id==nil then
return false
end
return A.selectEntry("match",id)
end
local scopeHeld=false
function A.scopeChoices()
return SCOPES
end
local function scopeEntry(word)
for i=1,#SCOPES do
if SCOPES[i].value==word then
return SCOPES[i]
end
end
return nil
end
local function pastSeason(word)
if type(word)~="string"then
return nil
end
local n=tonumber(word:match("^season(%d+)$"))
if n==nil or n<=0 or("season%d"):format(n)~=word then
return nil
end
return n
end
function A.isScopeWord(word)
return scopeEntry(word)~=nil or pastSeason(word)~=nil
end
function A.scopePastSeason(word)
return pastSeason(word)
end
function A.scopeLabel(word)
local entry=scopeEntry(word)
if entry~=nil then
return entry.label
end
local n=pastSeason(word)
if n~=nil then
local boundary=type(A.seasonEntry)=="function"and A.seasonEntry(n)or nil
if type(boundary)=="table"and type(boundary.label)=="string"and boundary.label~=""then
return boundary.label
end
return("Season %d"):format(n)
end
return tostring(word)
end
local function newestSeason()
if type(A.seasonNewest)~="function"then
return nil
end
local ok,season=pcall(A.seasonNewest)
if not ok then
return nil
end
return season
end
local pins={clock=nil,scope=nil}
function A.scopeSeasonsFor(format)
if type(A.movesRating)=="function"and not A.movesRating(format)then
return{}
end
if type(A.recordSeason)~="function"then
return{}
end
local pinned=pins.scope
local key=format==nil and""or format
if pinned~=nil and pinned.seasons~=nil and pinned.seasons[key]~=nil then
return pinned.seasons[key]
end
local function scopeSeasonsWalk()
local current=newestSeason()
local character=A.windowCharacter()
local seen,out={},{}
local function walk(list)
if type(list)~="table"then
return
end
for i=1,#list do
local ok,n=pcall(A.recordSeason,list[i])
if ok and type(n)=="number"and n~=current and not seen[n]then
seen[n]=true
out[#out+1]=n
end
end
end
if type(A.matches)=="function"then
local ok,held=pcall(A.matches,format,character)
if ok then
walk(held)
end
end
if tabHoldsIncomplete(format)and type(A.incompleteList)=="function"then
local ok,held=pcall(A.incompleteList,character)
if ok then
walk(held)
end
end
table.sort(out,function(a,b)
return a>b
end)
return out
end
local out=scopeSeasonsWalk()
if pinned~=nil then
pinned.seasons=pinned.seasons or{}
pinned.seasons[key]=out
end
return out
end
local function tabHoldsSeason(format,season)
local held=A.scopeSeasonsFor(format)
for i=1,#held do
if held[i]==season then
return true
end
end
return false
end
function A.scopeSpan(word)
local entry=scopeEntry(word)
if entry==nil or type(entry.days)~="number"then
return nil
end
return entry.days*SCOPE_DAY
end
function A.scopePhrase(word)
local entry=scopeEntry(word)
return entry and entry.phrase or nil
end
function A.scopeChoicesFor(format)
local ladder=type(A.movesRating)~="function"or A.movesRating(format)
local out={}
for i=1,#SCOPES do
local entry=SCOPES[i]
if entry.value~="season"or ladder then
out[#out+1]={value=entry.value,label=entry.label}
end
if entry.value=="season"then
local seasons=A.scopeSeasonsFor(format)
for s=1,#seasons do
local word=("season%d"):format(seasons[s])
out[#out+1]={value=word,label=A.scopeLabel(word)}
end
end
end
return out
end
local typedScope=nil
function A.summaryScope()
if typedScope~=nil then
return typedScope
end
local db=A.db()
if not db then
return"season"
end
if type(db.ui)~="table"then
db.ui={}
end
local stored=db.ui.seasonScope
if type(stored)=="string"and stored~="season"and A.isScopeWord(stored)then
return stored
end
return"season"
end
function A.scopeNow()
if pins.clock~=nil then
return pins.clock
end
return time()
end
function A.withScopeClock(fn,...)
if pins.clock~=nil then
return fn(...)
end
pins.clock=time()
local ok,first,second=pcall(fn,...)
pins.clock=nil
if not ok then
error(first,0)
end
return first,second
end
local heldFold={}
function A.readingCollapsed()
if heldFold.details~=nil then
return heldFold.details
end
local db=A.db()
if not db then
return false
end
if type(db.ui)~="table"then
db.ui={}
end
return db.ui.readingCollapsed==true
end
function A.setReadingCollapsed(collapsed)
local db=A.db()
if not db then
return false
end
if type(db.ui)~="table"then
db.ui={}
end
db.ui.readingCollapsed=collapsed==true
heldFold.details=nil
return true
end
function A.mmrLineShown()
local db=A.db()
if not db then
return false
end
if type(db.ui)~="table"then
db.ui={}
end
return db.ui.mmrLine==true
end
function A.setMmrLineShown(on)
local db=A.db()
if not db then
return false
end
if type(db.ui)~="table"then
db.ui={}
end
if on==true then
db.ui.mmrLine=true
else
db.ui.mmrLine=nil
end
return true
end
function A.graphFolded()
if heldFold.graph~=nil then
return heldFold.graph
end
local db=A.db()
if not db or type(db.ui)~="table"then
return false
end
return db.ui.graphFolded==true
end
function A.setGraphFolded(folded)
local db=A.db()
if not db then
return false
end
if type(db.ui)~="table"then
db.ui={}
end
db.ui.graphFolded=folded==true and true or nil
heldFold.graph=nil
return true
end
function A.holdFold(which,shut)
if which~="graph"and which~="details"then
return false
end
heldFold[which]=shut==true
A.trace("fold",{source=which,state=shut==true and"shut"or"open"},"ui")
A.refreshWindow()
return true
end
function A.specSort()
if type(A.specsSort)~="function"then
return A.specSortDefault()
end
return A.specsSort()
end
function A.setSpecSort(key,ascending)
if not(type(A.specSortKnown)=="function"and A.specSortKnown(key))then
return false
end
A.setSpecsSort(key,ascending)
return true
end
function A.toggleSpecSort(key)
return A.toggleSpecsSort(key)
end
function A.lobbySort()
local heldKey,heldUp=A.lobbySessionSort()
if heldKey~=nil then
return heldKey,heldUp
end
local db=A.db()
local key,ascending=A.lobbySortDefault()
if not(db and type(db.ui)=="table")then
return key,ascending
end
if type(A.lobbySortKnown)=="function"and A.lobbySortKnown(db.ui.lobbySort)then
return db.ui.lobbySort,db.ui.lobbySortUp==true
end
return key,ascending
end
function A.setLobbySort(key,ascending)
local db=A.db()
if not db then
return false
end
if type(db.ui)~="table"then
db.ui={}
end
if not(type(A.lobbySortKnown)=="function"and A.lobbySortKnown(key))then
return false
end
db.ui.lobbySort=key
db.ui.lobbySortUp=ascending==true
return true
end
function A.toggleLobbySort(key)
if not(type(A.lobbySortKnown)=="function"and A.lobbySortKnown(key))then
return A.lobbySort()
end
local held,ascending=A.lobbySort()
A.setLobbySessionSort(nil)
if held==key then
A.setLobbySort(key,not ascending)
else
A.setLobbySort(key,A.lobbySortOpens(key))
end
A.noteScoreSortChange("lobby")
return A.lobbySort()
end
function A.clickLobbySort(key)
A.toggleLobbySort(key)
if type(A.refreshWindow)=="function"then
pcall(A.refreshWindow)
end
return A.lobbySort()
end
function A.clickScoreSort(key,index,drawnUp)
A.toggleScoreSort(key,index,drawnUp)
if type(A.refreshWindow)=="function"then
pcall(A.refreshWindow)
end
return A.scoreSort()
end
function A.setSummaryScope(scope)
typedScope=nil
local db=A.db()
if not db then
return false
end
if type(db.ui)~="table"then
db.ui={}
end
if type(scope)=="string"and scope~="season"and A.isScopeWord(scope)then
db.ui.seasonScope=scope
else
db.ui.seasonScope=nil
end
A.holdScope(true)
traceView("scope",A.summaryScope)
return true
end
function A.summarySeason()
local word=A.summaryScope()
if word=="all"then
return nil
end
local past=pastSeason(word)
if past~=nil then
return past
end
return newestSeason()
end
local function characterPicked(guid)
if activeCharacter==guid then
return false
end
activeCharacter=guid
characterResolved=true
A.holdScope(false)
A.setStoredCharacter(guid)
A.refreshWindow()
return true
end
function A.characterChoices()
local list,unattributed={},0
if type(A.characterList)=="function"then
list,unattributed=A.characterList()
list=type(list)=="table"and list or{}
unattributed=type(unattributed)=="number"and unattributed or 0
end
local total=unattributed
for i=1,#list do
total=total+list[i].total
end
local out={{value=nil,label=("All Characters  %d"):format(total)}}
for i=1,#list do
local held=list[i]
out[#out+1]={value=held.guid,label=("%s  %d"):format(held.label,held.total)}
end
return out
end
function A.windowScope()
local pinned=pins.scope
if pinned~=nil and pinned.read and pinned.format==activeFormat then
return pinned.choice,pinned.season,pinned.bound
end
local choice,season,_,bound=A.formatScope(activeFormat)
if pinned~=nil then
pinned.read,pinned.format=true,activeFormat
pinned.choice,pinned.season,pinned.bound=choice,season,bound
end
return choice,season,bound
end
function A.windowMapsOffered()
if type(A.mapsViewOffered)~="function"then
return true
end
local pinned=pins.scope
if pinned~=nil and pinned.mapsFormat==activeFormat and pinned.mapsOffered~=nil then
return pinned.mapsOffered
end
local _,season,bound=A.windowScope()
local offered=A.mapsViewOffered(activeFormat,season,bound)and true or false
if pinned~=nil then
pinned.mapsFormat,pinned.mapsOffered=activeFormat,offered
end
return offered
end
function A.withPaintScope(fn,...)
if pins.scope~=nil then
return fn(...)
end
pins.scope={}
local opened=type(A.openPaintMemo)=="function"and A.openPaintMemo()
local done,first,second=pcall(fn,...)
pins.scope=nil
if opened then
A.closePaintMemo()
end
if not done then
error(first,0)
end
return first,second
end
function A.windowFormat()
if window and window:IsShown()then
return activeFormat
end
return A.storedTab()
end
function A.formatScope(format)
local stored=A.summaryScope()
local span=A.scopeSpan(stored)
if span~=nil then
return stored,nil,"range",A.scopeNow()-span
end
if type(A.movesRating)=="function"and not A.movesRating(format)then
return"all",nil,"ladderless"
end
local past=pastSeason(stored)
if past~=nil then
if tabHoldsSeason(format,past)then
return stored,past,"chosen"
end
else
if A.scopeYielded(format)then
return"all",nil,"yielded"
end
if stored~="season"then
return"all",nil,"chosen"
end
end
local season=newestSeason()
if season==nil then
return"season",nil,"undeclared"
end
return"season",season,"chosen"
end
function A.scopeText(format)
local choice,season,why,bound=A.formatScope(format)
if why=="range"then
local text=("%s, since %s"):format(tostring(A.scopePhrase(choice)),
tostring(A.stampAt(bound)or bound))
local undated=0
local character=A.windowCharacter()
if type(A.matches)=="function"then
local ok,held=pcall(A.matches,format,character)
if ok and type(held)=="table"then
for i=1,#held do
if A.recordEpoch(held[i])==nil then
undated=undated+1
end
end
end
end
if tabHoldsIncomplete(format)and type(A.incompleteList)=="function"then
local ok,held=pcall(A.incompleteList,character)
if ok and type(held)=="table"then
for i=1,#held do
if A.recordEpoch(held[i])==nil then
undated=undated+1
end
end
end
end
if undated>0 then
text=text..(", %d undated left out"):format(undated)
end
return text
end
if why=="ladderless"then
return"all time, no ladder on this tab to scope"
end
if why=="yielded"then
return"all time, this tab's season holding nothing"
end
if why=="undeclared"then
return"this season, but no season boundary is declared, so the walk is all time"
end
if season~=nil then
return"season "..tostring(season)
end
return"all time"
end
function A.scopeYielded(format)
if scopeHeld then
return false
end
if A.summaryScope()~="season"then
return false
end
if type(A.movesRating)=="function"and not A.movesRating(format)then
return false
end
local season=A.summarySeason()
if season==nil then
return false
end
local character=A.windowCharacter()
local okScoped,scoped=pcall(A.paintWalk,"summarize",format,season,character)
local okAll,all=pcall(A.paintWalk,"summarize",format,nil,character)
if not(okScoped and okAll and type(scoped)=="table"and type(all)=="table")then
return false
end
return scoped.matches==0 and all.matches>0
end
function A.holdScope(held)
scopeHeld=held and true or false
end
function A.windowCharacter()
local chosen=activeCharacter
if not characterResolved then
chosen=A.storedCharacter()
end
if chosen==nil then
return nil
end
if type(A.characterList)~="function"then
return nil
end
local ok,list=pcall(A.characterList)
if not ok or type(list)~="table"then
return nil
end
for i=1,#list do
if list[i].guid==chosen then
return chosen
end
end
return nil
end
function A.windowCharacterText()
local guid=A.windowCharacter()
if guid==nil then
return"all characters"
end
local ok,list=pcall(A.characterList)
if ok and type(list)=="table"then
for i=1,#list do
if list[i].guid==guid and type(list[i].label)=="string"then
return list[i].label
end
end
end
return guid
end
local function inSeason(record,season)
if season==nil then
return true
end
if type(A.recordSeason)~="function"then
return true
end
local ok,resolved=pcall(A.recordSeason,record)
return ok and resolved==season
end
local function scopePicked(value,body)
if value=="all"and A.summaryScope()=="season"and type(A.movesRating)=="function"
and not A.movesRating(activeFormat)then
A.refreshWindow()
return
end
A.setSummaryScope(value)
local _,season=A.formatScope(activeFormat)
local offered=A.scopeSeasonsFor(activeFormat)
A.trace("view",{
source="scope-pick",
state=value,
season=season,
offered=#offered>0 and table.concat(offered,",")or"none",
format=activeFormat,
body=body,
},"ui")
A.refreshWindow()
end
local function detailsToggled()
A.setReadingCollapsed(not A.readingCollapsed())
A.refreshWindow()
end
local function graphFoldToggled()
A.setGraphFolded(not A.graphFolded())
A.refreshWindow()
end
local function filterClicked(button)
activeFormat=button.filterFormat
A.holdScope(false)
A.setStoredTab(activeFormat)
A.refreshWindow()
end
local function layoutFilters()
local entries=A.tabList(A.windowCharacter())
window.filters=window.filters or{}
local available=window.filterRow:GetWidth()
if type(available)~="number"or available<120 then
available=A.windowWidth()-A.metric("margin")*2
end
local heldCount=0
if type(A.incompleteList)=="function"then
local ok,held=pcall(A.incompleteList,A.windowCharacter())
if ok and type(held)=="table"then
heldCount=#held
end
end
if heldCount>0 then
local named=false
for i=1,#entries do
if entries[i].format=="unknown"then
named=true
break
end
end
if not named then
entries[#entries+1]={
format="unknown",
label=A.formatLabel("unknown"),
matches=0,
}
end
end
local function tabCount(entry)
if entry.format==nil then
return(A.allCount(A.windowCharacter()))
end
local count=entry.matches or 0
if tabHoldsIncomplete(entry.format)then
count=count+heldCount
end
return count
end
local function fitTabs(counted)
local run=0
for i=1,#entries do
local button=window.filters[i]
if not button then
button=A.tab(window.filterRow,nil,filterClicked)
window.filters[i]=button
end
local entry=entries[i]
button.filterFormat=entry.format
if counted then
button:SetText(("%s  %d"):format(entry.label,tabCount(entry)))
else
button:SetText(entry.label)
end
A.fitControl(button,A.metric("tabMin"))
run=run+(button:GetWidth()or A.metric("pillMin"))+(i>1 and A.metric("pillGap")or 0)
end
return run
end
window.tabCountsShown=fitTabs(true)<=available
if not window.tabCountsShown then
fitTabs(false)
end
local x,rows=0,1
local tabRows={}
for i=1,#entries do
local button=window.filters[i]
local entry=entries[i]
local width=button:GetWidth()or A.metric("pillMin")
if x>0 and x+width>available then
x=0
rows=rows+1
end
button:ClearAllPoints()
button:SetPoint("TOPLEFT",window.filterRow,"TOPLEFT",x,
-(rows-1)*(A.metric("filterHeight")+A.metric("tabRowGap")))
button:Show()
tabRows[rows]=tabRows[rows]or{}
tabRows[rows][#tabRows[rows]+1]={name=entry.label,from=x,to=x+width}
A.setTabSelected(button,entry.format==activeFormat)
x=x+width+A.metric("pillGap")
end
for i=#entries+1,#window.filters do
window.filters[i]:Hide()
end
if type(A.notePlacedRow)=="function"then
A.notePlacedRows("tab row",tabRows)
end
local height=rows*A.metric("filterHeight")+(rows-1)*A.metric("tabRowGap")
window.filterRow:SetHeight(height)
return height
end
local RESULTS={"win","loss","draw"}
local function commitNote(box)
local frame=box and box.owner
if not(frame and frame.editing)then
return
end
local ok,text=pcall(box.GetText,box)
if not ok then
return
end
local value=(text~=nil and text~="")and text or nil
local subject=A.currentEditSubject(frame.editing,frame.editingLeft)
local stored
if frame.editingLeft then
stored=A.editIncompleteNote(subject,value)
else
stored=A.editNote(subject,value)
end
if not subject then
A.say("that match is no longer stored, so nothing was written")
repaintEverything()
return
end
if not stored then
A.say(("that note is longer than %d bytes, so nothing was written")
:format(A.MANUAL_NOTE_MAX))
return
end
pcall(box.ClearFocus,box)
repaintEverything()
end
local function commitResult(button)
local frame=button and button.owner
if not(frame and frame.editing)then
return
end
local subject=A.currentEditSubject(frame.editing,false)
local stored,_,why,held=A.editResult(subject,button.resultValue)
if not subject then
A.say("that match is no longer stored, so nothing was written")
repaintEverything()
return
end
if not stored then
A.say(why=="captured"
and("that match already carries result %s, which the capture recorded. Nothing written")
:format(tostring(held))
or"that result could not be written")
return
end
repaintEverything()
end
function A.reasonMenuPick(id,token,via)
local entry=A.incompleteById(id)
local stored,_,why=A.editReason(entry,token)
A.trace("reason-menu",{id=id,token=token or"none",state=stored and"stored"or"refused",
reason=(not stored)and why or nil,via=via},"ui")
if not stored then
A.say(why=="no-entry"and"that match is no longer stored, so nothing was written"
or"that is not a reason this store accepts. Nothing written")
return false
end
repaintEverything()
return true
end
function A.openReasonMenu(owner,id,via)
if type(MenuUtil)~="table"or type(MenuUtil.CreateContextMenu)~="function"or id==nil then
return false
end
local choices=A.reasonChoices()
local ok,menu=pcall(MenuUtil.CreateContextMenu,rowSurface.menuOwner(owner),function(_,root)
for i=1,#choices do
local choice=choices[i]
if choice.reason==nil and i>1 and type(root.CreateDivider)=="function"then
root:CreateDivider()
end
root:CreateButton(choice.label,function()
A.reasonMenuPick(id,choice.reason,via or"click")
end)
end
end)
return ok and menu~=nil
end
local function editLeftRun(frame)
local taken=4
if frame.roster and frame.roster:IsShown()then
taken=taken+(frame.roster:GetWidth()or A.metric("actionMin"))
+6+A.metric("pillGap")
end
return taken
end
local function paintEditCount(frame,text,run)
if not(frame and frame.editCount and frame.editNote)then
return
end
local inset=A.metric("entryInsetX")
local function clear()
frame.editCount:Hide()
pcall(frame.editNote.SetTextInsets,frame.editNote,inset,inset,
A.metric("entryInsetY"),A.metric("entryInsetY"))
end
local counter=A.noteCountText(text,A.MANUAL_NOTE_MAX)
if counter==nil then
clear()
return
end
A.style(frame.editCount,"note","dimmer")
frame.editCount:SetText(counter)
local ok,row=pcall(frame.editRow.GetWidth,frame.editRow)
if not(ok and type(row)=="number"and row>0)then
clear()
return
end
local box=row-editLeftRun(frame)-run-4
if A.fittedForm(frame.editCount,math.floor(box/2),{counter})==nil then
clear()
return
end
frame.editCount:Show()
pcall(frame.editNote.SetTextInsets,frame.editNote,inset,
inset+A.textRoom(frame.editCount,counter)+A.metric("rowCellGap"),
A.metric("entryInsetY"),A.metric("entryInsetY"))
end
local function buildEditStrip(frame)
frame.editRow=CreateFrame("Frame",nil,frame)
frame.editRow:SetHeight(A.metric("editHeight"))
frame.editRow:SetPoint("BOTTOMLEFT",frame.detailHost,"BOTTOMLEFT",0,0)
frame.editRow:SetPoint("BOTTOMRIGHT",frame.detailHost,"BOTTOMRIGHT",0,0)
frame.editNote=A.entry(frame.editRow)
frame.editNote:SetHeight(A.metric("controlHeight"))
frame.editNote:SetPoint("BOTTOMRIGHT",frame.editRow,"BOTTOMRIGHT",-4,2)
frame.editNote:SetMaxLetters(A.MANUAL_NOTE_MAX)
frame.editNote.owner=frame
frame.editNote:SetScript("OnEnterPressed",commitNote)
frame.editNote:SetScript("OnTextChanged",function(self)
local ok,held=pcall(self.GetText,self)
paintEditCount(frame,ok and held or"",frame.editRun or 0)
end)
frame.editNote:SetScript("OnEscapePressed",function(self)
pcall(self.ClearFocus,self)
frame.editNotePaint=frame.editNotePaint or{}
A.discardTypedNote(self,frame.editNotePaint)
repaintEverything()
end)
frame.roster=A.pill(frame.editRow,"Note this roster",nil,A.metric("actionMin"))
frame.roster:SetPoint("BOTTOMLEFT",frame.editRow,"BOTTOMLEFT",6,2)
frame.editNote:SetPoint("BOTTOMLEFT",frame.roster,"BOTTOMRIGHT",A.metric("pillGap"),0)
frame.roster:SetScript("OnClick",function()
local held=frame.recordKind=="match"and frame.recordId and A.match(frame.recordId)or nil
if type(held)=="table"and held.format=="world"then
pcall(function()
frame.editNote:SetFocus()
frame.editNote:SetCursorPosition(frame.editNote:GetNumLetters()or 0)
end)
return
end
if frame.recordKind=="match"and frame.recordId
and A.showNotesForMatch(frame.recordId)then
return
end
A.say("that match's roster could not be opened. /pvph notes #<id> scopes the players "
.."window to one match and /pvph notes opens the whole index")
end)
A.entryPlaceholder(frame.editNote,"Note on this match, then Enter")
frame.editCount=frame.editNote:CreateFontString(nil,"OVERLAY","GameFontDisableSmall")
frame.editCount:SetPoint("RIGHT",frame.editNote,"RIGHT",-A.metric("entryInsetX"),0)
frame.editCount:SetJustifyH("RIGHT")
frame.editCount:SetWordWrap(false)
frame.editCount:Hide()
local function layoutRight(buttons)
local room=frame.editRow:GetWidth()
local taken=editLeftRun(frame)
local x,laid=0,0
for i=1,#buttons do
local button=buttons[i]
local width=button:GetWidth()or A.metric("resultMin")
button:ClearAllPoints()
button:SetPoint("BOTTOMRIGHT",frame.editRow,"BOTTOMRIGHT",-4-x,2)
if type(room)=="number"and room>0 and(x+width+taken)>room then
button:Hide()
elseif button:IsShown()then
laid=x+width+A.metric("pillGap")
end
x=x+width+A.metric("pillGap")
end
return laid
end
frame.resultButtons={}
for i=1,#RESULTS do
local value=RESULTS[#RESULTS-i+1]
local button=A.pill(frame.editRow,value,nil,A.metric("resultMin"))
button.resultValue=value
button.owner=frame
button:SetScript("OnClick",commitResult)
frame.resultButtons[i]=button
end
layoutRight(frame.resultButtons)
frame.layoutEditActions=layoutRight
end
local function paintEditStrip(frame,record,isLeft)
frame.editing=record
frame.editingLeft=(record~=nil)and(isLeft==true)or false
local manual=record and type(record.manual)=="table"and record.manual or nil
frame.editNotePaint=frame.editNotePaint or{}
pcall(A.paintNoteBox,frame.editNote,frame.editNotePaint,record,(manual and manual.note)or"")
pcall(frame.editNote.SetEnabled,frame.editNote,record~=nil)
if frame.roster then
frame.roster:SetShown(record~=nil and not frame.editingLeft)
pcall(frame.roster.SetText,frame.roster,(A.rosterWords(record)))
pcall(A.fitControl,frame.roster,A.metric("actionMin"))
end
local fillable=record~=nil and not frame.editingLeft and A.resultOfferable(record)
for i=1,#frame.resultButtons do
frame.resultButtons[i]:SetShown(fillable)
end
local run=0
if frame.layoutEditActions and fillable then
local laid,held=pcall(frame.layoutEditActions,frame.resultButtons)
if laid and type(held)=="number"and held>0 then
run=held
end
end
local hint=""
if frame.editingLeft then
hint="Note on this entry, then Enter"
elseif record then
hint=select(2,A.rosterWords(record))
end
if frame.editNote.controlPlaceholder then
pcall(frame.editNote.controlPlaceholder.SetText,frame.editNote.controlPlaceholder,hint)
end
frame.editNote:ClearAllPoints()
if frame.roster and frame.roster:IsShown()then
frame.editNote:SetPoint("BOTTOMLEFT",frame.roster,"BOTTOMRIGHT",A.metric("pillGap"),0)
else
frame.editNote:SetPoint("BOTTOMLEFT",frame.editRow,"BOTTOMLEFT",6,2)
end
frame.editNote:SetPoint("BOTTOMRIGHT",frame.editRow,"BOTTOMRIGHT",-4-run,2)
frame.editRun=run
paintEditCount(frame,(manual and manual.note)or"",run)
end
local function authoredSize()
return A.metric("frameWidth"),A.matchWindowHeight()
end
filterBand.RESULT_CHOICES={
{value=nil,label="All results"},
{value="won",label="Won"},
{value="lost",label="Lost"},
{value="even",label="Even"},
}
function filterBand.specChoices()
local out={{value=nil,label="All specs"}}
local _,season,bound=A.windowScope()
local played=A.playedSpecs(activeFormat,A.windowCharacter(),{season=season,bound=bound})
local held=false
for i=1,#played do
local spec=played[i].spec
out[#out+1]={value=spec,label=("%s  %d"):format(spec,played[i].count)}
if spec==filterBand.spec then
held=true
end
end
if filterBand.spec~=nil and not held then
out[#out+1]={value=filterBand.spec,label=("%s  0"):format(filterBand.spec)}
end
return out
end
function filterBand.zoned()
return activeFormat=="world"
end
function filterBand.nouns()
if activeFormat=="world"then
return{"outing","outings"}
end
return{"match","matches"}
end
function filterBand.narrowing()
if#searchTerms>0 then
return true
end
if filterBand.zoned()then
return filterBand.zone~=nil
end
return filterBand.result~=nil or filterBand.spec~=nil
end
function filterBand.passes(entry)
local record=entry.kind~="incomplete"and entry.subject or nil
if not A.searchMatches(entry.subject,searchTerms)then
return false
end
if filterBand.zoned()then
return A.zoneFilterPasses(record,filterBand.zone)
end
return A.resultFilterPasses(record,filterBand.result)and A.specFilterPasses(record,filterBand.spec)
end
function filterBand.worldRecords(season,bound)
local entries=A.listEntries("world",A.windowCharacter(),season,bound)
local out={}
for i=1,#entries do
if entries[i].kind~="incomplete"and filterBand.passes(entries[i])then
out[#out+1]=entries[i].subject
end
end
return out
end
function filterBand.zoneChoices()
local out={{value=nil,label="All zones"}}
local _,season,bound=A.windowScope()
local records={}
for _,entry in ipairs(A.listEntries("world",A.windowCharacter(),season,bound))do
if entry.kind~="incomplete"then
records[#records+1]=entry.subject
end
end
local held=false
for _,row in ipairs(A.recordZones(records))do
out[#out+1]={value=row.zone,label=("%s  %d"):format(row.zone,row.count)}
if row.zone==filterBand.zone then
held=true
end
end
if filterBand.zone~=nil and not held then
out[#out+1]={value=filterBand.zone,label=("%s  0"):format(filterBand.zone)}
end
return out
end
local function buildListSearch(frame)
local host=frame.listHost
local gap=A.metric("rowCellGap")
local middle=-A.metric("searchHeight")/2
local beside
local function chain(control)
if beside then
control:SetPoint("RIGHT",beside,"LEFT",-gap,0)
else
control:SetPoint("RIGHT",host,"TOPRIGHT",-A.metric("rowLabelPad"),middle)
end
beside=control
end
if type(A.dropdown)=="function"then
local okScope,scope=pcall(A.dropdown,host,SCOPES,function(value)
scopePicked(value,"history")
end)
if okScope and scope then
frame.filterScope=scope
chain(scope)
end
local okResult,result=pcall(A.dropdown,host,filterBand.RESULT_CHOICES,function(value)
A.setMatchFilter("result",value,"pick")
end)
if okResult and result then
frame.filterResult=result
chain(result)
end
local ok,spec=pcall(A.dropdown,host,filterBand.specChoices(),function(value)
A.setMatchFilter("spec",value,"pick")
end)
if ok and spec then
frame.filterSpec=spec
chain(spec)
end
local okZone,zone=pcall(A.dropdown,host,filterBand.zoneChoices(),function(value)
A.setMatchFilter("zone",value,"pick")
end)
if okZone and zone then
frame.filterZone=zone
if frame.filterScope then
zone:SetPoint("RIGHT",frame.filterScope,"LEFT",-gap,0)
else
zone:SetPoint("RIGHT",host,"TOPRIGHT",-A.metric("rowLabelPad"),middle)
end
zone:Hide()
end
end
frame.searchBox=A.entry(host)
frame.searchBox:SetHeight(A.metric("searchHeight"))
frame.searchBox:SetPoint("TOPLEFT",host,"TOPLEFT",0,0)
frame.searchBox:SetWidth(A.listSearchBoxWidth())
frame.searchBox:SetTextInsets(A.metric("entryInsetX"),A.listSearchClearWidth(),
A.metric("entryInsetY"),A.metric("entryInsetY"))
frame.searchCount=host:CreateFontString(nil,"ARTWORK","GameFontHighlightSmall")
frame.searchCount:SetPoint("LEFT",frame.searchBox,"RIGHT",gap,0)
frame.searchCount:SetSize(A.listSearchCountWidth(),A.metric("searchHeight"))
frame.searchCount:SetJustifyH("LEFT")
frame.searchCount:SetWordWrap(false)
frame.searchCount:Hide()
A.style(frame.searchCount,"label","dim")
frame.searchBox:SetScript("OnTextChanged",function(self,userInput)
if not userInput then
return
end
local ok,text=pcall(self.GetText,self)
A.setMatchSearch(ok and text or nil,"typed")
end)
A.entryPlaceholder(frame.searchBox,filterBand.SEARCH_PLACEHOLDER)
frame.searchBox:SetScript("OnEnterPressed",function(self)
pcall(self.ClearFocus,self)
end)
frame.searchBox:SetScript("OnEscapePressed",function(self)
pcall(self.ClearFocus,self)
end)
frame.searchClear=A.pill(frame.searchBox,"clear",function()
A.setMatchSearch(nil,"clear")
end)
frame.searchClear:SetPoint("RIGHT",frame.searchBox,"RIGHT",0,0)
frame.searchClear:Hide()
end
local function buildWindow()
local frame=CreateFrame("Frame",FRAME_NAME,UIParent,"BasicFrameTemplateWithInset")
frame:SetSize(authoredSize())
frame:SetPoint("CENTER")
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
if type(A.rememberWindow)=="function"then
pcall(A.rememberWindow,"matches")
end
end)
frame:Hide()
A.registerChrome(frame)
if type(A.dropdown)=="function"then
local ok,picker=pcall(A.dropdown,frame,{},characterPicked)
if ok and picker then
frame.character=picker
if frame.CloseButton then
picker:SetPoint("RIGHT",frame.CloseButton,"LEFT",-A.metric("titleActionGap"),0)
else
picker:SetPoint("TOPRIGHT",frame,"TOPRIGHT",
-A.metric("titleActionFallback"),-A.metric("titleActionDrop"))
end
end
end
frame.filterRow=CreateFrame("Frame",nil,frame)
frame.filterRow:SetHeight(A.metric("filterHeight"))
frame.filterRow:SetPoint("TOPLEFT",frame,"TOPLEFT",A.metric("margin"),-A.metric("headerHeight"))
frame.filterRow:SetPoint("TOPRIGHT",frame,"TOPRIGHT",-A.metric("margin"),-A.metric("headerHeight"))
frame.halfTabs=A.halfTabs(frame,"matches")
frame.pageHosts={}
for _,body in ipairs({"settings","about"})do
local host=CreateFrame("Frame",nil,frame)
host:SetPoint("TOPLEFT",frame,"TOPLEFT",A.metric("margin"),-A.metric("headerHeight"))
host:SetPoint("BOTTOMRIGHT",frame,"BOTTOMRIGHT",-A.metric("margin"),A.bodyFloor())
host:Hide()
frame.pageHosts[body]=host
end
frame.viewRow=CreateFrame("Frame",nil,frame)
frame.viewRow:SetHeight(1)
if type(A.buildSummaryRegion)=="function"then
local ok,region=pcall(A.buildSummaryRegion,frame,frame.viewRow,SCOPES,
function(value)scopePicked(value,"stats")end,detailsToggled,graphFoldToggled)
if ok and region then
frame.summary=region
end
end
local anchor=frame.filterRow
if frame.summary then
frame.summary:SetPoint("TOPLEFT",frame.filterRow,"BOTTOMLEFT",0,-A.metric("summaryGap"))
frame.summary:SetPoint("TOPRIGHT",frame.filterRow,"BOTTOMRIGHT",0,-A.metric("summaryGap"))
anchor=frame.summary
end
frame.viewRowAnchor=anchor
frame.viewRow:SetPoint("TOPLEFT",anchor,"BOTTOMLEFT",0,-A.metric("paneGap"))
frame.viewRow:SetWidth(A.listHostWidth(false))
frame.footName=frame:CreateFontString(nil,"ARTWORK","GameFontDisableSmall")
frame.footName:SetPoint("BOTTOMLEFT",frame,"BOTTOMLEFT",A.metric("margin"),
A.metric("margin"))
frame.footName:SetJustifyH("LEFT")
frame.footName:SetWordWrap(false)
A.style(frame.footName,"rowNote","dimmer")
frame.footState=frame:CreateFontString(nil,"ARTWORK","GameFontDisableSmall")
frame.footState:SetPoint("BOTTOMRIGHT",frame,"BOTTOMRIGHT",-A.metric("margin"),
A.metric("margin"))
frame.footState:SetJustifyH("RIGHT")
frame.footState:SetWordWrap(false)
A.style(frame.footState,"rowNote","dimmer")
frame.footRule=frame:CreateTexture(nil,"ARTWORK")
frame.footRule:SetPoint("BOTTOMLEFT",frame,"BOTTOMLEFT",A.metric("margin"),A.windowFootRuleY())
frame.footRule:SetPoint("BOTTOMRIGHT",frame,"BOTTOMRIGHT",-A.metric("margin"),A.windowFootRuleY())
frame.footRule:SetHeight(1)
frame.listHost=CreateFrame("Frame",nil,frame)
frame.listHost:SetPoint("TOPLEFT",frame.viewRow,"BOTTOMLEFT",0,0)
frame.listHost:SetPoint("BOTTOMLEFT",frame,"BOTTOMLEFT",A.metric("margin"),A.bodyFloor())
frame.listHost:SetWidth(A.listHostWidth(false))
frame.listGround=frame.listHost:CreateTexture(nil,"BACKGROUND",nil,-8)
frame.listGround:SetAllPoints(frame.listHost)
frame.listGround:Hide()
frame.listEdges={}
for _,side in ipairs({{"TOPLEFT","TOPRIGHT"},{"BOTTOMLEFT","BOTTOMRIGHT"},
{"TOPLEFT","BOTTOMLEFT"},{"TOPRIGHT","BOTTOMRIGHT"}})do
local edge=frame.listHost:CreateTexture(nil,"BORDER")
edge:SetPoint(side[1],frame.listHost,side[1],0,0)
edge:SetPoint(side[2],frame.listHost,side[2],0,0)
if side[1]=="TOPLEFT"and side[2]=="TOPRIGHT"or side[1]=="BOTTOMLEFT"then
edge:SetHeight(1)
else
edge:SetWidth(1)
end
edge:Hide()
frame.listEdges[#frame.listEdges+1]=edge
end
if type(A.buildDuelPanel)=="function"then
frame.duelPanel=A.buildDuelPanel(frame)
end
window=frame
frame.measure=frame:CreateFontString(nil,"ARTWORK","GameFontHighlightSmall")
frame.measure:SetJustifyH("LEFT")
frame.measure:SetWordWrap(true)
frame.measure:Hide()
A.style(frame.measure,"bodyText")
frame.measureMono=frame:CreateFontString(nil,"ARTWORK","GameFontHighlightSmall")
frame.measureMono:SetJustifyH("LEFT")
frame.measureMono:SetWordWrap(true)
frame.measureMono:Hide()
A.style(frame.measureMono,"numberSmall")
frame.compMeasure=frame:CreateFontString(nil,"ARTWORK","GameFontDisableSmall")
frame.compMeasure:SetJustifyH("LEFT")
frame.compMeasure:SetWordWrap(true)
frame.compMeasure:Hide()
A.style(frame.compMeasure,"note")
frame.span=frame:CreateFontString(nil,"ARTWORK","GameFontHighlightSmall")
frame.span:SetJustifyH("LEFT")
frame.span:SetWordWrap(false)
frame.span:Hide()
A.style(frame.span,"bodyText")
frame.spanMono=frame:CreateFontString(nil,"ARTWORK","GameFontHighlightSmall")
frame.spanMono:SetJustifyH("LEFT")
frame.spanMono:SetWordWrap(false)
frame.spanMono:Hide()
A.style(frame.spanMono,"numberSmall")
frame.measureRow=frame:CreateFontString(nil,"ARTWORK","GameFontHighlightSmall")
frame.measureRow:SetJustifyH("LEFT")
frame.measureRow:SetWordWrap(true)
frame.measureRow:Hide()
A.style(frame.measureRow,"rowNote")
frame.listHead=CreateFrame("Frame",nil,frame.listHost)
frame.listHead:SetHeight(A.metric("rowHeadRow"))
frame.listHead:SetPoint("TOPLEFT",frame.listHost,"TOPLEFT",0,-A.listSearchBand())
frame.listHead:SetPoint("TOPRIGHT",frame.listHost,"TOPRIGHT",0,-A.listSearchBand())
frame.listHead:Hide()
buildListSearch(frame)
frame.listHeadNames={}
for i=1,darkList.ROW_CELL_SLOTS do
local name=frame.listHead:CreateFontString(nil,"ARTWORK","GameFontDisableSmall")
name:SetJustifyH("LEFT")
name:SetWordWrap(false)
frame.listHeadNames[i]=name
end
frame.listHeadRule=frame.listHead:CreateTexture(nil,"BORDER")
frame.listHeadRule:SetPoint("BOTTOMLEFT",frame.listHead,"BOTTOMLEFT",0,0)
frame.listHeadRule:SetPoint("BOTTOMRIGHT",frame.listHead,"BOTTOMRIGHT",0,0)
frame.listHeadRule:SetHeight(1)
frame.listHeadMore=CreateFrame("Frame",nil,frame.listHead)
frame.listHeadMore:EnableMouse(true)
frame.listHeadMore:SetScript("OnEnter",darkList.gridEnter)
frame.listHeadMore:SetScript("OnLeave",darkList.gridLeave)
frame.listHeadMore:Hide()
local function rowExtent(_,data)
local height=data and data.height
if type(height)~="number"or height<1 then
return A.metric("rowHeight")
end
return height
end
frame.list=A.buildScroller(FRAME_NAME.."List",frame.listHost,"Button",initListRow,
rowExtent,"the match list")
A.holdWholeRows(frame.list,A.metric("rowListRow"),A.metric("rowDayRow"))
frame.list.box:SetAllPoints(frame.listHost)
frame.listEmpty=frame.listHost:CreateFontString(nil,"OVERLAY","GameFontDisableSmall")
frame.listEmpty:SetPoint("TOPLEFT",frame.listHost,"TOPLEFT",A.metric("rowLabelPad"),
-A.listSearchBand()-A.metric("paneGap"))
frame.listEmpty:SetJustifyH("LEFT")
frame.listEmpty:Hide()
frame.listPin=CreateFrame("Frame",FRAME_NAME.."ListPin",frame.listHost)
frame.listPin:SetPoint("TOPLEFT",frame.list.box,"TOPLEFT",0,0)
frame.listPin:SetPoint("TOPRIGHT",frame.list.box,"TOPRIGHT",0,0)
frame.listPin:SetHeight(A.metric("rowDayRow"))
frame.listPin:EnableMouse(false)
frame.listPin.ground=frame.listPin:CreateTexture(nil,"BACKGROUND")
frame.listPin.ground:SetAllPoints(frame.listPin)
frame.listPin.rule=frame.listPin:CreateTexture(nil,"ARTWORK")
frame.listPin.rule:SetPoint("TOPLEFT",frame.listPin,"TOPLEFT",A.metric("rowLabelPad"),0)
frame.listPin.rule:SetHeight(1)
frame.listPin.name=frame.listPin:CreateFontString(nil,"ARTWORK","GameFontDisableSmall")
frame.listPin.name:SetPoint("TOPLEFT",frame.listPin,"TOPLEFT",A.metric("rowLabelPad"),
-A.metric("rowExpandPad"))
frame.listPin.name:SetJustifyH("LEFT")
frame.listPin.name:SetWordWrap(false)
frame.listPin.count=frame.listPin:CreateFontString(nil,"ARTWORK","GameFontDisableSmall")
frame.listPin.count:SetJustifyH("RIGHT")
frame.listPin.count:SetWordWrap(false)
local pinLine=CreateFrame("Frame",nil,frame.listPin)
pinLine:SetPoint("TOPLEFT",frame.listPin,"TOPLEFT",0,0)
pinLine:SetPoint("TOPRIGHT",frame.listPin,"TOPRIGHT",0,0)
pinLine:SetHeight(A.metric("gridRow"))
pinLine.dayRule=pinLine:CreateTexture(nil,"ARTWORK")
pinLine.dayRule:Hide()
for _,key in ipairs({"sessionCaret","dayName","sessionSpan","dayCount"})do
local text=pinLine:CreateFontString(nil,"ARTWORK","GameFontDisableSmall")
text:SetJustifyH("LEFT")
text:SetWordWrap(false)
text:Hide()
pinLine[key]=text
end
pinLine:Hide()
frame.listPin.line=pinLine
frame.listPin.names=CreateFrame("Frame",nil,frame.listPin)
frame.listPin.names:SetPoint("BOTTOMLEFT",frame.listPin,"BOTTOMLEFT",0,0)
frame.listPin.names:SetPoint("BOTTOMRIGHT",frame.listPin,"BOTTOMRIGHT",0,0)
frame.listPin.names:SetHeight(A.metric("rowHeadRow"))
frame.listPin.names.cells={}
for i=1,darkList.ROW_CELL_SLOTS do
local name=frame.listPin.names:CreateFontString(nil,"ARTWORK","GameFontDisableSmall")
name:SetJustifyH("LEFT")
name:SetWordWrap(false)
frame.listPin.names.cells[i]=name
end
frame.listPin.names.rule=frame.listPin.names:CreateTexture(nil,"ARTWORK")
frame.listPin.names.rule:SetHeight(1)
frame.listPin.names:Hide()
frame.listPin:Hide()
frame.list.pin=frame.listPin
frame.list.bar:SetPoint("TOPLEFT",frame.listHost,"TOPRIGHT",4,-A.listSearchBand())
frame.list.bar:SetPoint("BOTTOMLEFT",frame.listHost,"BOTTOMRIGHT",4,0)
frame.compHost=CreateFrame("Frame",nil,frame)
frame.compHost:SetPoint("TOPLEFT",frame.viewRow,"BOTTOMLEFT",0,0)
frame.compHost:SetPoint("BOTTOMRIGHT",frame,"BOTTOMRIGHT",
-A.metric("margin")-A.metric("paneRightPad"),A.bodyFloor())
frame.compHost:Hide()
frame.compHeading=frame.compHost:CreateFontString(nil,"ARTWORK","GameFontDisableSmall")
frame.compHeading:SetPoint("TOPLEFT",frame.compHost,"TOPLEFT",A.metric("rowNamePad"),-2)
frame.compHeading:SetPoint("TOPRIGHT",frame.compHost,"TOPRIGHT",0,-2)
frame.compHeading:SetJustifyH("LEFT")
frame.compHeading:SetWordWrap(false)
frame.compFloor=frame.compHost:CreateFontString(nil,"ARTWORK","GameFontDisableSmall")
frame.compFloor:SetPoint("TOPLEFT",frame.compHeading,"BOTTOMLEFT",0,-3)
frame.compFloor:SetPoint("TOPRIGHT",frame.compHeading,"BOTTOMRIGHT",0,-3)
frame.compFloor:SetJustifyH("LEFT")
frame.compFloor:SetWordWrap(false)
frame.compFloor:Hide()
frame.compHead=CreateFrame("Frame",nil,frame.compHost)
frame.compHead:SetHeight(A.fontSize("label")+6)
frame.compHead:SetPoint("TOPLEFT",frame.compHeading,"BOTTOMLEFT",-A.metric("rowNamePad"),-4)
frame.compHead:SetPoint("TOPRIGHT",frame.compHeading,"BOTTOMRIGHT",0,-4)
frame.compHeadNames={}
local function compHeadName(text,width,justify)
local label=frame.compHead:CreateFontString(nil,"ARTWORK","GameFontDisableSmall")
label:SetText(text)
label:SetJustifyH(justify or"RIGHT")
label:SetWordWrap(false)
if width then
label:SetWidth(width)
end
frame.compHeadNames[#frame.compHeadNames+1]=label
return label
end
local compColumns=A.compColumns(nil)
local headAnchor,headPoint=frame.compHead,"RIGHT"
local sortHeads={}
frame.compHeadByKey={}
for c=#compColumns,1,-1 do
local column=compColumns[c]
local label=compHeadName(column.name,column.width)
label:SetPoint("RIGHT",headAnchor,headPoint,-A.metric("rowCellGap"),0)
frame.compHeadByKey[column.key]=label
if column.sort~=nil then
table.insert(sortHeads,1,{label,column.sort})
end
headAnchor,headPoint=label,"LEFT"
end
frame.compHeadGames=frame.compHeadByKey.games
local headComp=compHeadName("ENEMY COMP",nil,"LEFT")
headComp:SetPoint("LEFT",frame.compHead,"LEFT",A.metric("rowNamePad"),0)
frame.compHeadSorts={}
for _,pair in ipairs(sortHeads)do
local sort=CreateFrame("Button",nil,frame.compHead)
sort:SetAllPoints(pair[1])
sort:RegisterForClicks("LeftButtonUp")
sort.hover=sort:CreateTexture(nil,"HIGHLIGHT")
sort.hover:SetAllPoints(sort)
sort.sortKey=pair[2]
sort.name=pair[1]
sort:SetScript("OnClick",function(self)
if type(A.clickAskSort)=="function"then
A.clickAskSort("comp",self.sortKey)
end
end)
frame.compHeadSorts[#frame.compHeadSorts+1]=sort
end
frame.compHeadRule=frame.compHead:CreateTexture(nil,"BORDER")
frame.compHeadRule:SetPoint("BOTTOMLEFT",frame.compHead,"BOTTOMLEFT",0,0)
frame.compHeadRule:SetPoint("BOTTOMRIGHT",frame.compHead,"BOTTOMRIGHT",0,0)
frame.compHeadRule:SetHeight(1)
frame.compTableBand=CreateFrame("Frame",nil,frame.compHost)
frame.compTableBand:SetPoint("TOPLEFT",frame.compHead,"BOTTOMLEFT",0,-2)
frame.compTableBand:SetPoint("TOPRIGHT",frame.compHead,"BOTTOMRIGHT",0,-2)
frame.compTableBand:SetHeight(A.metric("compRow"))
local function compExtent(_,data)
if type(data)=="table"and type(data.height)=="number"and data.height>=1 then
return data.height
end
return A.metric("compRow")
end
frame.comps=A.buildScroller(FRAME_NAME.."Comps",frame.compTableBand,"Button",initComp,
compExtent,"the comp table")
frame.comps.box:SetAllPoints(frame.compTableBand)
frame.comps.bar:SetPoint("TOPLEFT",frame.compTableBand,"TOPRIGHT",4,0)
frame.comps.bar:SetPoint("BOTTOMLEFT",frame.compTableBand,"BOTTOMRIGHT",4,0)
frame.compNote=frame.compHost:CreateFontString(nil,"ARTWORK","GameFontDisableSmall")
frame.compNote:SetPoint("TOPLEFT",frame.compTableBand,"BOTTOMLEFT",A.metric("rowNamePad"),-6)
frame.compNote:SetPoint("TOPRIGHT",frame.compTableBand,"BOTTOMRIGHT",0,-6)
frame.compNote:SetJustifyH("LEFT")
frame.compNote:SetWordWrap(true)
A.style(frame.compNote,"note","dimmer")
frame.compFloorLine=A.buildFloorLine(frame.compHost)
frame.compMatchTitle=frame.compHost:CreateFontString(nil,"ARTWORK","GameFontDisableSmall")
frame.compMatchTitle:SetPoint("TOPLEFT",frame.compNote,"BOTTOMLEFT",0,-8)
frame.compMatchTitle:SetPoint("TOPRIGHT",frame.compNote,"BOTTOMRIGHT",0,-8)
frame.compMatchTitle:SetJustifyH("LEFT")
frame.compMatchTitle:SetWordWrap(true)
frame.specNote=frame.compHost:CreateFontString(nil,"ARTWORK","GameFontDisableSmall")
frame.specNote:SetPoint("BOTTOMLEFT",frame.compHost,"BOTTOMLEFT",A.metric("rowNamePad"),0)
frame.specNote:SetPoint("BOTTOMRIGHT",frame.compHost,"BOTTOMRIGHT",0,0)
frame.specNote:SetJustifyH("LEFT")
frame.specNote:SetWordWrap(true)
frame.specNote:Hide()
frame.compGroupHead=CreateFrame("Frame",nil,frame.compHost)
frame.compGroupHead:SetHeight(A.fontSize("label")+4)
frame.compGroupHead:SetPoint("TOPLEFT",frame.compHeading,"BOTTOMLEFT",0,-4)
frame.compGroupHead:SetPoint("TOPRIGHT",frame.compHeading,"BOTTOMRIGHT",0,-4)
frame.compGroupHead:Hide()
frame.compGroupNames={}
for i=1,darkList.ROW_CELL_SLOTS do
local name=frame.compGroupHead:CreateFontString(nil,"ARTWORK","GameFontDisableSmall")
name:SetJustifyH("LEFT")
name:SetWordWrap(false)
name:Hide()
name.rule=frame.compGroupHead:CreateTexture(nil,"ARTWORK")
name.rule:Hide()
frame.compGroupNames[i]=name
end
frame.compPaneHead=CreateFrame("Frame",nil,frame.compHost)
frame.compPaneHead:SetHeight(A.metric("rowHeadRow"))
frame.compPaneHead:SetPoint("TOPLEFT",frame.compHeading,"BOTTOMLEFT",0,-4)
frame.compPaneHead:SetPoint("TOPRIGHT",frame.compHeading,"BOTTOMRIGHT",0,-4)
frame.compPaneHead:Hide()
frame.compPaneHeadNames={}
frame.compPaneHeadSorts={}
for i=1,darkList.ROW_CELL_SLOTS do
local name=frame.compPaneHead:CreateFontString(nil,"ARTWORK","GameFontDisableSmall")
name:SetJustifyH("LEFT")
name:SetWordWrap(false)
frame.compPaneHeadNames[i]=name
local sort=CreateFrame("Button",nil,frame.compPaneHead)
sort:SetHeight(A.metric("rowHeadRow"))
sort:RegisterForClicks("LeftButtonUp")
sort.hover=sort:CreateTexture(nil,"HIGHLIGHT")
sort.hover:SetAllPoints(sort)
sort:SetScript("OnClick",function(self)
if type(self.sortKey)~="string"or type(A.toggleSpecSort)~="function"then
return
end
A.toggleSpecSort(self.sortKey)
if type(A.refreshWindow)=="function"then
pcall(A.refreshWindow)
end
end)
sort:Hide()
frame.compPaneHeadSorts[i]=sort
end
frame.compPaneHeadRule=frame.compPaneHead:CreateTexture(nil,"BORDER")
frame.compPaneHeadRule:SetPoint("BOTTOMLEFT",frame.compPaneHead,"BOTTOMLEFT",0,0)
frame.compPaneHeadRule:SetPoint("BOTTOMRIGHT",frame.compPaneHead,"BOTTOMRIGHT",0,0)
frame.compPaneHeadRule:SetHeight(1)
frame.compMatchBand=CreateFrame("Frame",nil,frame.compHost)
frame.compMatchBand:SetPoint("BOTTOM",frame.compHost,"BOTTOM",0,0)
local function paneExtent(_,data)
if type(data)=="table"and type(data.height)=="number"and data.height>=1 then
return data.height
end
return A.metric("rowHeight")
end
frame.compMatches=A.buildScroller(FRAME_NAME.."CompMatches",frame.compMatchBand,
"Button",initPaneRow,paneExtent,"the comp match list")
frame.compMatches.box:SetAllPoints(frame.compMatchBand)
frame.compMatches.bar:SetPoint("TOPLEFT",frame.compMatchBand,"TOPRIGHT",4,0)
frame.compMatches.bar:SetPoint("BOTTOMLEFT",frame.compMatchBand,"BOTTOMRIGHT",4,0)
frame.compColumn=CreateFrame("Frame",nil,frame.compHost)
frame.compColumn:SetPoint("TOPLEFT",frame.compHost,"TOPLEFT",0,0)
frame.compColumn:SetPoint("BOTTOMLEFT",frame.compHost,"BOTTOMLEFT",0,0)
frame.compColumn:SetWidth(A.compPaneWidth())
frame.specEndsRow=CreateFrame("Frame",nil,frame.compHost)
frame.specEndsRow:SetPoint("TOPLEFT",frame.compHost,"TOPLEFT",0,-2)
frame.specEndsRow:SetPoint("TOPRIGHT",frame.compHost,"TOPRIGHT",0,-2)
frame.specEndsRow:SetHeight(A.askCardHeight())
frame.specEndsRow:Hide()
frame.specEnds={}
for i=1,4 do
local card=CreateFrame("Frame",nil,frame.specEndsRow)
card.ground=card:CreateTexture(nil,"BACKGROUND")
card.ground:SetAllPoints(card)
card.title=card:CreateFontString(nil,"ARTWORK","GameFontDisableSmall")
card.title:SetPoint("TOPLEFT",card,"TOPLEFT",A.metric("cardPad"),-A.metric("cardPad"))
card.title:SetJustifyH("LEFT")
card.title:SetWordWrap(false)
card.icon=card:CreateTexture(nil,"ARTWORK")
card.icon:SetPoint("BOTTOMLEFT",card,"BOTTOMLEFT",A.metric("cardPad"),A.metric("cardPad"))
card.icon:SetSize(A.metric("compSwatch"),A.metric("compSwatch"))
card.name=card:CreateFontString(nil,"ARTWORK","GameFontHighlight")
card.name:SetJustifyH("LEFT")
card.name:SetWordWrap(false)
card.rate=card:CreateFontString(nil,"ARTWORK","GameFontHighlightSmall")
card.rate:SetPoint("BOTTOMRIGHT",card,"BOTTOMRIGHT",-A.metric("cardPad"),A.metric("cardPad"))
card.rate:SetJustifyH("RIGHT")
card.rate:SetWordWrap(false)
card.record=card:CreateFontString(nil,"ARTWORK","GameFontDisableSmall")
card.record:SetPoint("TOPRIGHT",card,"TOPRIGHT",-A.metric("cardPad"),-A.metric("cardPad"))
card.record:SetJustifyH("RIGHT")
card.record:SetWordWrap(false)
frame.specEnds[i]=card
end
frame.askHost=CreateFrame("Frame",nil,frame)
frame.askHost:Hide()
frame.askHead=CreateFrame("Frame",nil,frame.viewRow)
frame.askHead:SetPoint("TOPLEFT",frame.viewRow,"TOPLEFT",0,0)
frame.askHead:SetHeight(A.metric("segmentHeight")+A.metric("segmentTrackPad")*2)
frame.askHead:SetWidth(A.askSplitWidth())
frame.askHead:Show()
frame.askOver=frame.askHead:CreateFontString(nil,"ARTWORK","GameFontDisableSmall")
frame.askOver:SetPoint("LEFT",frame.askHead,"LEFT",A.metric("rowLabelPad"),0)
frame.askOver:SetJustifyH("LEFT")
frame.askOver:SetWordWrap(false)
frame.askOver:SetText("OVER")
frame.askFormat=frame.askHead:CreateFontString(nil,"ARTWORK","GameFontHighlightSmall")
frame.askFormat:SetPoint("LEFT",frame.askOver,"RIGHT",A.metric("chipGap"),0)
frame.askFormat:SetJustifyH("LEFT")
frame.askFormat:SetWordWrap(false)
frame.askCount=frame.askHead:CreateFontString(nil,"ARTWORK","GameFontDisableSmall")
frame.askCount:SetPoint("LEFT",frame.askFormat,"RIGHT",A.metric("chipGap"),0)
frame.askCount:SetJustifyH("LEFT")
frame.askCount:SetWordWrap(false)
frame.askCards={}
local questions=A.askQuestions()
local cardPad=A.metric("cardPad")
for i=1,#questions do
local card=CreateFrame("Button",nil,frame.askHost)
card.askKey=questions[i].key
card:SetHeight(A.askCardHeight())
card:RegisterForClicks("LeftButtonUp")
card.ground=card:CreateTexture(nil,"BACKGROUND")
card.ground:SetAllPoints(card)
card.selection=card:CreateTexture(nil,"BACKGROUND",nil,1)
card.selection:SetAllPoints(card)
card.selection:Hide()
card.hover=card:CreateTexture(nil,"HIGHLIGHT")
card.hover:SetAllPoints(card)
card.title=card:CreateFontString(nil,"ARTWORK","GameFontDisableSmall")
card.title:SetPoint("TOPLEFT",card,"TOPLEFT",cardPad,-cardPad)
card.title:SetJustifyH("LEFT")
card.title:SetWordWrap(false)
card.name=card:CreateFontString(nil,"ARTWORK","GameFontHighlight")
card.name:SetPoint("BOTTOMLEFT",card,"BOTTOMLEFT",cardPad,cardPad)
card.name:SetJustifyH("LEFT")
card.name:SetWordWrap(false)
card.icon=card:CreateTexture(nil,"ARTWORK")
card.icon:SetPoint("BOTTOMLEFT",card,"BOTTOMLEFT",cardPad,cardPad)
card.icon:SetSize(A.metric("compSwatch"),A.metric("compSwatch"))
card.icon:Hide()
card.specCells={{icon=card.icon,name=card.name}}
for m=2,3 do
local icon=card:CreateTexture(nil,"ARTWORK")
icon:Hide()
local name=card:CreateFontString(nil,"ARTWORK","GameFontHighlight")
name:SetJustifyH("LEFT")
name:SetWordWrap(false)
name:Hide()
card.specCells[m]={icon=icon,name=name}
end
card.edge=card:CreateTexture(nil,"ARTWORK")
card.edge:SetPoint("TOPLEFT",card,"TOPLEFT",0,0)
card.edge:SetPoint("BOTTOMLEFT",card,"BOTTOMLEFT",0,0)
card.edge:SetWidth(1)
card.edge:Hide()
card.over=card:CreateFontString(nil,"ARTWORK","GameFontDisableSmall")
card.over:SetJustifyH("RIGHT")
card.over:SetWordWrap(false)
card.record=card:CreateFontString(nil,"ARTWORK","GameFontHighlightSmall")
card.record:SetJustifyH("RIGHT")
card.record:SetWordWrap(false)
card.rate=card:CreateFontString(nil,"ARTWORK","GameFontHighlightSmall")
card.rate:SetJustifyH("RIGHT")
card.rate:SetWordWrap(false)
card:SetScript("OnClick",function(self)
if self.askKey~=nil then
A.pickAsk(self.askKey)
end
end)
card:Hide()
frame.askCards[i]=card
end
frame.askEmpty=frame.askHost:CreateFontString(nil,"ARTWORK","GameFontDisableSmall")
frame.askEmpty:SetPoint("TOPLEFT",frame.askHost,"TOPLEFT",A.metric("rowLabelPad"),-2)
frame.askEmpty:SetPoint("TOPRIGHT",frame.askHost,"TOPRIGHT",0,-2)
frame.askEmpty:SetJustifyH("LEFT")
frame.askEmpty:SetWordWrap(true)
frame.askEmpty:Hide()
frame.askPaneHost=CreateFrame("Frame",nil,frame)
frame.askPaneHost:Hide()
if type(A.buildStatsOverview)=="function"then
A.buildStatsOverview(frame,frame.askPaneHost)
end
frame.askPaneHeading=frame.askPaneHost:CreateFontString(nil,"ARTWORK","GameFontDisableSmall")
frame.askPaneHeading:SetPoint("TOPLEFT",frame.askPaneHost,"TOPLEFT",A.metric("rowLabelPad"),-2)
frame.askPaneHeading:SetPoint("TOPRIGHT",frame.askPaneHost,"TOPRIGHT",0,-2)
frame.askPaneHeading:SetJustifyH("LEFT")
frame.askPaneHeading:SetWordWrap(false)
frame.askPaneHead=CreateFrame("Frame",nil,frame.askPaneHost)
frame.askPaneHead:SetHeight(A.metric("rowHeadRow"))
frame.askPaneHead:SetPoint("TOPLEFT",frame.askPaneHeading,"BOTTOMLEFT",0,-4)
frame.askPaneHead:SetPoint("TOPRIGHT",frame.askPaneHeading,"BOTTOMRIGHT",0,-4)
frame.askPaneHead:Hide()
frame.askPaneHeadNames={}
frame.askPaneHeadSorts={}
for i=1,darkList.ROW_CELL_SLOTS do
local name=frame.askPaneHead:CreateFontString(nil,"ARTWORK","GameFontDisableSmall")
name:SetJustifyH("LEFT")
name:SetWordWrap(false)
frame.askPaneHeadNames[i]=name
local sort=CreateFrame("Button",nil,frame.askPaneHead)
sort:SetHeight(A.metric("rowHeadRow"))
sort:RegisterForClicks("LeftButtonUp")
sort.hover=sort:CreateTexture(nil,"HIGHLIGHT")
sort.hover:SetAllPoints(sort)
sort:SetScript("OnClick",function(self)
if type(self.sortKey)~="string"or type(frame.askSortQuestion)~="string"
or type(A.clickAskSort)~="function"then
return
end
A.clickAskSort(frame.askSortQuestion,self.sortKey)
end)
sort:Hide()
frame.askPaneHeadSorts[i]=sort
end
frame.askPaneHeadRule=frame.askPaneHead:CreateTexture(nil,"BORDER")
frame.askPaneHeadRule:SetPoint("BOTTOMLEFT",frame.askPaneHead,"BOTTOMLEFT",0,0)
frame.askPaneHeadRule:SetHeight(1)
frame.askNote=frame.askPaneHost:CreateFontString(nil,"ARTWORK","GameFontDisableSmall")
frame.askNote:SetPoint("BOTTOMLEFT",frame.askPaneHost,"BOTTOMLEFT",A.metric("rowLabelPad"),0)
frame.askNote:SetPoint("BOTTOMRIGHT",frame.askPaneHost,"BOTTOMRIGHT",0,0)
frame.askNote:SetJustifyH("LEFT")
frame.askNote:SetWordWrap(true)
frame.askFloorLine=A.buildFloorLine(frame.askPaneHost)
frame.askPane=A.buildScroller(FRAME_NAME.."AskPane",frame.askPaneHost,"Button",
initAskRow,A.metric("rowHeight"),"the answer table")
frame.askPane.box:SetPoint("TOPLEFT",frame.askPaneHead,"BOTTOMLEFT",0,0)
frame.askPane.box:SetPoint("TOPRIGHT",frame.askPaneHead,"BOTTOMRIGHT",0,0)
frame.askPane.box:SetPoint("BOTTOMLEFT",frame.askNote,"TOPLEFT",0,A.metric("paneGap"))
frame.askPane.box:SetPoint("BOTTOMRIGHT",frame.askNote,"TOPRIGHT",0,A.metric("paneGap"))
frame.askPane.bar:SetPoint("TOPLEFT",frame.askPane.box,"TOPRIGHT",4,0)
frame.askPane.bar:SetPoint("BOTTOMLEFT",frame.askPane.box,"BOTTOMRIGHT",4,0)
frame.askMatchBand=CreateFrame("Frame",nil,frame)
frame.askMatchBand:Hide()
frame.askBandKey=frame.askMatchBand:CreateFontString(nil,"ARTWORK","GameFontDisableSmall")
frame.askBandKey:SetPoint("TOPLEFT",frame.askMatchBand,"TOPLEFT",A.metric("rowLabelPad"),0)
frame.askBandKey:SetWidth(A.metric("readingKeyWidth"))
frame.askBandKey:SetJustifyH("LEFT")
frame.askBandKey:SetWordWrap(false)
frame.askBandCount=frame.askMatchBand:CreateFontString(nil,"ARTWORK","GameFontDisableSmall")
frame.askBandCount:SetPoint("TOPLEFT",frame.askBandKey,"TOPRIGHT",A.metric("readingKeyGap"),0)
frame.askBandCount:SetPoint("RIGHT",frame.askMatchBand,"RIGHT",0,0)
frame.askBandCount:SetJustifyH("LEFT")
frame.askBandCount:SetWordWrap(false)
frame.askBandHead=CreateFrame("Frame",nil,frame.askMatchBand)
frame.askBandHead:SetHeight(A.metric("rowHeadRow"))
frame.askBandHead:SetPoint("TOPLEFT",frame.askMatchBand,"TOPLEFT",0,-A.metric("rowHeight"))
frame.askBandHead:SetPoint("TOPRIGHT",frame.askMatchBand,"TOPRIGHT",0,-A.metric("rowHeight"))
frame.askBandHeadNames={}
for i=1,darkList.ROW_CELL_SLOTS do
local name=frame.askBandHead:CreateFontString(nil,"ARTWORK","GameFontDisableSmall")
name:SetJustifyH("LEFT")
name:SetWordWrap(false)
frame.askBandHeadNames[i]=name
end
frame.askBandHeadRule=frame.askBandHead:CreateTexture(nil,"BORDER")
frame.askBandHeadRule:SetPoint("BOTTOMLEFT",frame.askBandHead,"BOTTOMLEFT",0,0)
frame.askBandHeadRule:SetHeight(1)
frame.askMatches=A.buildScroller(FRAME_NAME.."AskMatches",frame.askMatchBand,"Button",
initAskBandRow,A.metric("rowHeight"),"the answer's matches")
frame.askMatches.box:SetPoint("TOPLEFT",frame.askBandHead,"BOTTOMLEFT",0,0)
frame.askMatches.box:SetPoint("TOPRIGHT",frame.askBandHead,"BOTTOMRIGHT",0,0)
frame.askMatches.box:SetPoint("BOTTOMLEFT",frame.askMatchBand,"BOTTOMLEFT",0,0)
frame.askMatches.box:SetPoint("BOTTOMRIGHT",frame.askMatchBand,"BOTTOMRIGHT",0,0)
frame.askMatches.bar:SetPoint("TOPLEFT",frame.askMatches.box,"TOPRIGHT",4,0)
frame.askMatches.bar:SetPoint("BOTTOMLEFT",frame.askMatches.box,"BOTTOMRIGHT",4,0)
if type(UISpecialFrames)=="table"then
local seen=false
for i=1,#UISpecialFrames do
if UISpecialFrames[i]==FRAME_NAME then
seen=true
break
end
end
if not seen then
UISpecialFrames[#UISpecialFrames+1]=FRAME_NAME
end
end
if type(A.attachResize)=="function"then
pcall(A.attachResize,frame,"matches",A.refreshWindow)
end
return frame
end
if type(A.registerWindowKind)=="function"then
A.registerWindowKind("matches",{
label="match history",
authored=authoredSize,
floor=A.matchWindowFloor,
point="CENTER",
x=0,
y=0,
})
end
local function windowOrNil()
if window then
return window
end
local built=A.buildWindowOnce("matches",buildWindow)
if not built then
window=nil
return nil
end
window=built
return window
end
function A.windowPageHost(body)
local frame=windowOrNil()
return frame and frame.pageHosts and frame.pageHosts[body]or nil
end
local function entryStamp(entry)
local at=entry.openedAt or entry.completedAt or entry.endedAt
return type(at)=="string"and at or""
end
local function emptyBecause(stored,admitted,held)
if admitted>0 or held>0 then
return nil
end
local noun=filterBand.nouns()[2]
if stored==0 then
return("No %s yet."):format(noun)
end
return("No %s."):format(noun)
end
local function rowRoom()
local frame=window
if not(frame and frame.span and frame.listHost)then
return nil
end
local sample="0123456789 abcdefghij ABCDEFGHIJ 0123456789"
local held=frame.span:GetText()
local okText=pcall(frame.span.SetText,frame.span,sample)
local okWidth,width=pcall(frame.span.GetStringWidth,frame.span)
if okText then
pcall(frame.span.SetText,frame.span,held)
end
if not(okText and okWidth)or type(width)~="number"or width<=0 then
return nil
end
local okRow,row=pcall(frame.listHost.GetWidth,frame.listHost)
if not okRow or type(row)~="number"or row<=0 then
return nil
end
local per=width/#sample
local room=math.floor((row-A.metric("rowLabelPad")*2)/per)
if room<1 then
return nil
end
return room
end
local function expansionHeight(text,hostWidth)
local frame=window
local floor=A.fontSize("note")+A.metric("rowExpandPad")
if not(frame and frame.measureRow and frame.listHost)then
return floor
end
local width=hostWidth
if type(width)~="number"or width<=0 then
return floor
end
local room=width-A.metric("rowLabelPad")*2
local span=A.columnSpan(frame.listColumns)
if type(span)=="number"and span>0 and span<width then
room=span-A.metric("rowLabelPad")*2
end
pcall(A.style,frame.measureRow,"rowNote","dim")
pcall(frame.measureRow.SetWidth,frame.measureRow,room)
pcall(frame.measureRow.SetText,frame.measureRow,text)
frame.expansionMeasured=room
local okHeight,height=pcall(frame.measureRow.GetStringHeight,frame.measureRow)
if not okHeight or type(height)~="number"or height<1 then
return floor
end
return height+A.metric("rowExpandPad")
end
function darkList.incompleteFallback(entry)
local parts={}
if type(entry)=="table"then
if type(entry.id)=="number"or type(entry.id)=="string"then
parts[#parts+1]=("#%s"):format(tostring(entry.id))
end
if type(entry.openedAt)=="string"then
parts[#parts+1]=("opened %s"):format(entry.openedAt)
end
end
return table.concat(parts,"  ")
end
function darkList.recordRow(entry,columns,room,scale)
local subject,kind=entry.subject,entry.kind
local text
if kind=="incomplete"then
local ok,line=pcall(A.incompleteRowText,subject)
if ok and type(line)=="string"then
text=line
else
A.noteError(line,"incomplete-row")
text=darkList.incompleteFallback(subject)
end
else
text=table.concat(A.rowCells(subject,room),"  ")
end
local cells=nil
if columns then
local ok,built=pcall(A.flatRowCells,subject,kind,columns)
cells=ok and built or nil
end
local record=kind~="incomplete"
local tone=record and A.resultTone(subject)or nil
local style={id={tone="dim"},day={tone="dim"},opponent={role="nameText"}}
local tint=nil
if tone then
style.result={tone=tone}
style.rounds={tone=tone}
end
local change=nil
if record then
local delta,deltaTone=A.ratingDelta(subject)
if deltaTone then
style.change={tone=deltaTone}
end
local _,out,moved=A.recordLadderPair(subject)
if delta~=nil then
change=moved
end
if out~=nil then
local _,_,reason,r,g,b=A.ratingColour(subject.format,out)
if r~=nil then
tint={ratingOut={r,g,b}}
else
style.ratingOut={tone="bright"}
if reason=="unheard"then
A.ratingAsk()
end
end
else
style.ratingOut={tone="dimmer"}
end
end
local rounds=nil
if record then
local verdict,won,played=A.roundsVerdict(subject)
if verdict~=nil and type(played)=="number"and played>0 then
rounds={won=type(won)=="number"and won or 0,played=played}
end
end
if tone then
style.verdict={tone=tone}
end
local tally=nil
if record and subject.format=="world"then
local kills,deaths=A.worldCounts(subject)
tone=A.worldEdgeTone(subject)
style.ratio={tone=A.kdTone(kills,deaths)}
if not(type(subject.map)=="table"and type(subject.map.name)=="string"and subject.map.name~="")then
style.where={tone="dim"}
end
tally=kills~=nil and{kills=kills,deaths=deaths}or nil
end
style.how={tone="dim"}
style.time={tone="dim"}
style.span={tone="dim"}
for i,column in ipairs(cells and columns or{})do
if column.key=="opponent"and record then
local bare,realm=A.nameParts(subject.opponentName)
local key=A.duelOpponentKey(subject)
local token=key and type(darkList.duelClasses)=="table"and darkList.duelClasses[key]or nil
local name=bare
if token and bare~=""then
local r,g,b=A.classColor(token)
name=("|cff%s%s|r"):format(A.colorHex(r,g,b):sub(1,6),bare)
end
cells[i]=realm and(name.."  "..A.colorEscape("dim")..realm.."|r")or(bare~=""and name or"-")
end
end
local reasonMenu=nil
for _,column in ipairs(cells and columns or{})do
if column.key=="why"and kind=="incomplete"then
local manual=type(subject.manual)=="table"and subject.manual or nil
reasonMenu={id=subject.id,label=A.reasonLabel(manual and manual.reason)}
end
end
return{
id=subject.id,
kind=kind,
matchRecord=kind=="match"and subject or nil,
flat=true,
cellSubs=cells and A.flatRowSubs(subject,kind,columns)or nil,
reasonMenu=reasonMenu,
text=text,
cells=cells,
cellStyle=style,
cellTint=tint,
resultTone=tone,
columns=cells and columns or nil,
crest=record and A.recordFaction(subject)or nil,
selfChip=record and A.rowSelfChip(subject)or nil,
chips=A.rowChips(subject,kind),
rounds=rounds,
tally=tally,
change=change,
changeScale=scale,
height=A.metric("rowListRow"),
}
end
function darkList.rows(entries,sessions,unplaced,flatList,columns,room,rowEntries,lineRecords)
local rows,selected,selectedIsLeft,selectedAt={},nil,false,nil
local namesRows=0
darkList.lastSessions=sessions
darkList.grid=nil
local drawn=nil
if not flatList then
local gridColumns,gridRest,gridFold=A.sessionGrid(entries,A.listTableWidth(),activeFormat)
local world=activeFormat=="world"and A.worldSessionGrid(columns)or nil
if world~=nil then
gridColumns,gridRest,gridFold=world,{},false
end
darkList.grid={columns=gridColumns,rest=gridRest,fold=gridFold}
drawn={}
end
darkList.lastDrawn=drawn
local grid=darkList.grid
local function addNames(noDay)
if columns==nil then
return
end
rows[#rows+1]={
separator=true,
names=true,
noDay=noDay or nil,
columns=columns,
height=A.metric("rowHeadRow"),
}
namesRows=namesRows+1
end
local shown={}
local scale=0
for i=1,#entries do
shown[entries[i]]=true
if entries[i].kind~="incomplete"then
local delta=select(3,A.recordLadderPair(entries[i].subject))
if type(delta)=="number"and math.abs(delta)>scale then
scale=math.abs(delta)
end
end
end
scale=math.min(scale,A.metric("rowChangeScaleCap"))
local function addRecord(entry)
rows[#rows+1]=darkList.recordRow(entry,columns,room,scale)
rowEntries[#rows]=entry
local subject=entry.subject
if subject.id~=nil and subject.id==selectedId and entry.kind==selectedKind then
selected,selectedIsLeft,selectedAt=subject,entry.kind=="incomplete",#rows
end
end
local now=(type(A.scopeNow)=="function"and A.scopeNow())or time()
local placed,folds,heads,gridOpen={},{},{},{}
local roundsLeft,roundsPartial=0,0
local drawing={}
for s=1,#sessions do
for _,entry in ipairs(sessions[s].entries)do
if shown[entry]then
drawing[#drawing+1]=sessions[s]
break
end
end
end
local headFormsOf=A.sessionHeadList(drawing,now)
for s=1,#sessions do
local session=sessions[s]
local listed={}
for _,entry in ipairs(session.entries)do
placed[entry]=true
if shown[entry]then
listed[#listed+1]=entry
end
end
local open,source=A.sessionOpen(session.key,s==1)
if#folds<30 then
local counted=tostring(session.matches or session.count)
if(session.leftEarly or 0)>0 then
counted=counted.."+"..session.leftEarly
end
folds[#folds+1]=("%s:%s:%s:%s"):format(tostring(session.key),counted,
open and"open"or"folded",source)
end
if#listed>0 and grid~=nil then
local headSpan=A.sessionSpanText(session)
local forms=A.sessionGridLabelForms(session.startStamp,now)or headFormsOf[session]or{}
if#heads<30 then
heads[#heads+1]=headSpan and("%s %s"):format(forms[1]or"",headSpan)or(forms[1]or"")
end
local cells={}
local summary,summaryLine=nil,nil
for _,column in ipairs(grid.columns)do
if column.key=="format"then
local cell=A.sessionGridCell(listed,column.format)
local line=A.sessionGridHoverLine(cell)
local text=A.sessionGridCellText(cell)
if text==nil and activeFormat~=nil then
text=A.colorEscape("dim").."-|r"
end
cells[#cells+1]={text=text,lines=line and{line}or nil}
elseif column.key=="summary"then
local summed=A.sessionGridSummary(listed,activeFormat)
roundsLeft=roundsLeft+summed.out
summary=A.sessionGridSummaryText(summed)
summaryLine=A.sessionGridSummaryHover(summed)
if summaryLine~=nil then
roundsPartial=roundsPartial+1
end
elseif column.key=="more"then
local lines,played={},0
for _,format in ipairs(grid.rest)do
local cell=A.sessionGridCell(listed,format)
if cell~=nil then
played=played+1
lines[#lines+1]=A.sessionGridName(format).."  "..A.sessionGridHoverLine(cell)
end
end
cells[#cells+1]={text=played>0 and("+%d"):format(played)or nil,
lines=played>0 and lines or nil}
end
end
local ticks,over=A.sessionTicks(listed)
if drawn then
drawn[#drawn+1]={key=session.key,newest=s==1,listed=#listed,open=open}
end
rows[#rows+1]={
separator=true,
session=true,
grid=true,
sessionKey=session.key,
sessionNewest=s==1,
open=open,
text=forms[1]or"",
textForms=forms,
span=headSpan,
count=tostring(#listed),
gridColumns=grid.columns,
gridCells=cells,
gridSummary=summary,
gridSummaryLines=summaryLine and{summaryLine}or nil,
tally=activeFormat=="world"and A.worldSessionTally(listed)or nil,
ticks=ticks,
ticksOver=over,
fold=grid.fold or nil,
height=grid.fold and A.metric("gridRowFold")or A.metric("gridRow"),
}
if not open and type(lineRecords)=="table"then
local newest,oldest
for _,entry in ipairs(listed)do
if entry.kind~="incomplete"and type(entry.subject)=="table"then
newest=newest or entry.subject
oldest=entry.subject
end
end
if newest~=nil then
lineRecords[#rows]={newest=newest,oldest=oldest}
end
end
if open then
if#gridOpen<30 then
gridOpen[#gridOpen+1]=tostring(session.key)
end
addNames(false)
for _,entry in ipairs(listed)do
addRecord(entry)
end
end
elseif#listed>0 then
for _,entry in ipairs(listed)do
addRecord(entry)
end
end
end
local namedUnplaced=flatList
for i=1,#entries do
if not placed[entries[i]]then
if not namedUnplaced then
addNames(true)
namedUnplaced=true
end
addRecord(entries[i])
rows[#rows].noDay=true
end
end
if activeFormat=="world"and drawn~=nil and activeBody~="stats"then
local outingRows,marks=0,0
for _,line in ipairs(drawn)do
if line.open then
outingRows=outingRows+line.listed
end
end
for i=1,#rows do
local tally=rows[i].grid and rows[i].tally or nil
if type(tally)=="table"then
local killMarks,deathMarks=A.kdMarks(tally.kills,tally.deaths)
marks=marks+killMarks+deathMarks
end
end
A.trace("worldgrid",{n=#drawn,rows=outingRows,outings=#entries,marks=marks},"ui")
end
darkList.sessionsEntry=nil
if activeBody~="stats"then
darkList.sessionsEntry={
format=activeFormat,
gap=A.sessionGapMinutes(),
n=#sessions,
shape=flatList and"flat"or"sessions",
unplaced=unplaced,
gridOpen=#gridOpen>0 and table.concat(gridOpen,",")or nil,
roundsLeft=roundsLeft>0 and roundsLeft or nil,
roundsPartial=roundsPartial>0 and roundsPartial or nil,
foldList=#folds>0 and table.concat(folds,",")or nil,
heads=#heads>0 and table.concat(heads,";")or nil,
listHead=(flatList or grid~=nil)and"fixed"or"hidden",
namesRows=namesRows,
grid=grid and table.concat((function()
local out={}
for _,column in ipairs(grid.columns)do
out[#out+1]=column.name
end
return out
end)(),",")or nil,
gridFold=grid and(grid.fold and"folded"or"column")or nil,
}
end
return rows,selected,selectedIsLeft,selectedAt
end
function A.foldSession(key,newest,via)
local open=A.toggleSession(key,newest)
if type(A.trace)=="function"then
A.trace("fold",{key=tostring(key),state=open and"open"or"folded",via=via},"ui")
end
A.refreshWindow()
return open
end
function A.listSessions()
return darkList.lastSessions
end
function A.listSessionLines()
local sessions=darkList.lastSessions
if type(sessions)~="table"then
return nil,"none"
end
local drawn=darkList.lastDrawn
if type(drawn)~="table"then
return nil,"undrawn"
end
return drawn,"grid"
end
function A.scrollListTop()
if A.windowBodyShown()==nil then
return false,"closed"
end
if A.windowBody()~="history"then
return false,"body"
end
local box=window.list and window.list.box or nil
if type(box)~="table"or type(box.ScrollToBegin)~="function"then
return false,"box"
end
local ok=pcall(box.ScrollToBegin,box)
return ok,not ok and"box"or nil
end
function A.holdListSession(index,open)
local lines,shape=A.listSessionLines()
if lines==nil then
return nil,nil,shape
end
local line=type(index)=="number"and lines[index]or nil
if line==nil then
return nil,#lines,shape
end
A.holdSessionOpen(line.key,open)
if type(A.trace)=="function"then
A.trace("fold",{key=tostring(line.key),state=open and"open"or"folded",via="word"},"ui")
end
A.refreshWindow()
return line.key,#lines,shape
end
function A.listEntries(format,character,season,bound)
local matches=A.matches(format,character)
if season~=nil or bound~=nil then
local kept={}
for i=1,#matches do
if inSeason(matches[i],season)and A.recordSince(matches[i],bound)then
kept[#kept+1]=matches[i]
end
end
matches=kept
end
local entries={}
for i=1,#matches do
entries[#entries+1]={kind="match",subject=matches[i]}
end
local left=0
if tabHoldsIncomplete(format)and type(A.incompleteList)=="function"then
local ok,held=pcall(A.incompleteList,character)
if ok and type(held)=="table"then
for i=1,#held do
if inSeason(held[i],season)and A.recordSince(held[i],bound)then
entries[#entries+1]={kind="incomplete",subject=held[i]}
left=left+1
end
end
end
end
if left>0 then
table.sort(entries,function(a,b)
local as,bs=entryStamp(a.subject),entryStamp(b.subject)
if as~=bs then
return as>bs
end
if a.kind~=b.kind then
return a.kind<b.kind
end
local ak,an=A.matchIdRank(a.subject.id)
local bk,bn=A.matchIdRank(b.subject.id)
if ak~=bk then
return ak>bk
end
return an>bn
end)
end
return entries,#matches,left
end
function A.listColumnSet(format,entries)
local sessions,unplaced=A.buildSessions(entries)
local flatList=A.sessionsFlat(sessions)
return A.listColumnShares(A.flatRowColumns(format,entries,flatList)),sessions,unplaced,flatList
end
local function listRows()
local room=rowRoom()
local db=A.db()
local stored=(db and type(db.matches)=="table")and#db.matches or 0
local _,listSeason,listBound=A.windowScope()
local entries,afterSeason,left=A.listEntries(activeFormat,A.windowCharacter(),listSeason,listBound)
local columns,sessions,unplaced,flatList=A.listColumnSet(activeFormat,entries)
darkList.namesInList=not flatList and columns~=nil
local drawnNames={}
for _,column in ipairs(columns or{})do
drawnNames[#drawnNames+1]=(column.name~=nil and column.name~="")and column.name or column.key
end
lastColumns=table.concat(drawnNames," ")
if window and window.list then
window.list.wholeBase=A.metric("rowListRow")
window.list.pinNames=darkList.namesInList or nil
window.list.pinHeight=A.metric("rowDayRow")
+(darkList.namesInList and A.metric("rowHeadRow")or 0)
end
searchScoped=#entries
local narrowing=filterBand.narrowing()
if narrowing then
local kept,keptLeft={},0
for i=1,#entries do
if filterBand.passes(entries[i])then
kept[#kept+1]=entries[i]
if entries[i].kind=="incomplete"then
keptLeft=keptLeft+1
end
end
end
entries,left=kept,keptLeft
end
searchShown=#entries
local rowEntries={}
local lineRecords={}
local rows,selected,selectedIsLeft,selectedAt=darkList.rows(entries,sessions,unplaced,flatList,
columns,room,rowEntries,lineRecords)
if darkList.grid~=nil and window and window.list then
window.list.pinHeight=(darkList.grid.fold and A.metric("gridRowFold")or A.metric("gridRow"))
+(darkList.namesInList and A.metric("rowHeadRow")or 0)
end
rows,rowEntries,selectedAt=A.withSeasonBreaks(rows,rowEntries,selectedAt,lineRecords)
if window then
local breaks,icons,squares=0,0,0
for i=1,#rows do
local row=rows[i]
if row.seasonBreak then
breaks=breaks+1
end
local chips={row.selfChip}
if type(row.chips)=="table"and type(row.chips.chips)=="table"then
for _,chip in ipairs(row.chips.chips)do
chips[#chips+1]=chip
end
end
for _,chip in pairs(chips)do
if chip.icon~=nil then
icons=icons+1
else
squares=squares+1
end
end
end
window.listShape={seasonBreaks=breaks,icons=icons,squares=squares}
end
if window then
window.listColumns=columns
end
local heldBySearch=narrowing and selectedId~=nil
if not selected and entries[1]and not heldBySearch then
for i=1,#rows do
if not rows[i].separator and rowEntries[i]~=nil then
local entry=rowEntries[i]
selected=entry.subject
selectedIsLeft=entry.kind=="incomplete"
selectedKind=entry.kind
selectedId=selected.id
selectedAt=i
break
end
end
end
local paneShown=A.recordHasTable(selected,selectedKind)
if not paneShown and selected and selectedAt and rows[selectedAt]then
local ok,lines=pcall(A.rowExpansion,selected,selectedKind)
local text=(ok and type(lines)=="table")and table.concat(lines,"  ")or""
if text~=""then
rows[selectedAt].expansion=text
rows[selectedAt].height=A.metric("rowListRow")
+expansionHeight(text,A.listHostWidth(false))
local grown=window and window.expansionGrown
if type(grown)=="table"and grown.id==selected.id and grown.width==window.expansionMeasured then
rows[selectedAt].height=rows[selectedAt].height+grown.over
end
end
end
if window and window.list then
window.list.selectedAt=selectedAt
end
local empty
if#searchTerms>0 then
empty=#entries==0 and("No %s for %s."):format(filterBand.nouns()[2],searchText)or nil
elseif narrowing and filterBand.zoned()then
empty=#entries==0 and("No outings in %s."):format(tostring(filterBand.zone))or nil
elseif narrowing then
empty=#entries==0 and("No %smatches%s."):format(
filterBand.result~=nil and(filterBand.result.." ")or"",
filterBand.spec~=nil and(" as "..filterBand.spec)or"")or nil
else
empty=emptyBecause(stored,afterSeason,left)
end
return rows,selected,#entries,selectedIsLeft,left,empty,
afterSeason,columns
end
local function listHeadShown(columns,rowCount)
return columns~=nil and(not darkList.namesInList or darkList.grid~=nil)and A.bandShown({
name="list header",
heading=A.metric("rowHeadRow"),
rowHeight=A.metric("rowHeight"),
contents=rowCount or 0,
})
end
function A.searchCountLine(shown,scoped)
local nouns=filterBand.nouns()
return("%d of %d %s"):format(shown or 0,scoped or 0,scoped==1 and nouns[1]or nouns[2])
end
function filterBand.heldFits()
local held=filterBand.held
if held==nil or held.format~=activeFormat or held.character~=A.windowCharacter()
or held.spec~=filterBand.spec or held.zone~=filterBand.zone or held.scope~=A.summaryScope()then
return false
end
return type(A.storeMarkSame)=="function"and A.storeMarkSame(held.mark,A.storeMark())
end
function filterBand.paint(frame,reuse)
if type(A.setDropdownChoices)~="function"then
return
end
if frame.filterResult then
A.setDropdownChoices(frame.filterResult,filterBand.RESULT_CHOICES,filterBand.result)
end
local zoned=filterBand.zoned()
if frame.filterResult then
frame.filterResult:SetShown(not zoned)
end
if frame.filterSpec then
frame.filterSpec:SetShown(not zoned)
end
if frame.filterZone then
frame.filterZone:SetShown(zoned)
end
if frame.searchBox and frame.searchBox.controlPlaceholder then
pcall(frame.searchBox.controlPlaceholder.SetText,frame.searchBox.controlPlaceholder,
zoned and filterBand.ZONE_PLACEHOLDER or filterBand.SEARCH_PLACEHOLDER)
end
if not(reuse and filterBand.heldFits())then
filterBand.held=nil
local specChoices=frame.filterSpec and filterBand.specChoices()or nil
local okScope,scopeChoices=false,nil
if frame.filterScope and type(A.scopeChoicesFor)=="function"then
okScope,scopeChoices=pcall(A.scopeChoicesFor,activeFormat)
end
filterBand.held={
format=activeFormat,character=A.windowCharacter(),spec=filterBand.spec,
scope=A.summaryScope(),mark=type(A.storeMark)=="function"and A.storeMark()or nil,
specChoices=specChoices,scopeChoices=okScope and scopeChoices or nil,
zone=filterBand.zone,
zoneChoices=(frame.filterZone and zoned)and filterBand.zoneChoices()or nil,
}
end
local held=filterBand.held
if frame.filterZone and zoned and held.zoneChoices then
A.setDropdownChoices(frame.filterZone,held.zoneChoices,filterBand.zone)
end
if frame.filterSpec and held.specChoices then
A.setDropdownChoices(frame.filterSpec,held.specChoices,filterBand.spec)
end
if frame.filterScope and held.scopeChoices then
pcall(function()
A.setDropdownChoices(frame.filterScope,held.scopeChoices,(A.windowScope()))
end)
end
end
function filterBand.place(frame)
local box=frame and frame.searchBox
if not box then
return nil
end
local gap=A.metric("rowCellGap")
local host=A.listHostWidth(false)
local right=host-A.metric("rowLabelPad")
local filters={}
local controls={
{name="time",control=frame.filterScope,sample=filterBand.SCOPE_SAMPLE},
{name="result",control=frame.filterResult,sample=filterBand.RESULT_SAMPLE},
{name="spec",control=frame.filterSpec,sample=filterBand.SPEC_SAMPLE},
}
if filterBand.zoned()then
controls[2]={name="zone",control=frame.filterZone,sample=filterBand.ZONE_SAMPLE}
controls[3]=nil
end
for i=1,#controls do
local held=controls[i]
if held.control then
local ok,width=pcall(held.control.GetWidth,held.control,true)
if not(ok and type(width)=="number"and width>0)then
width=A.listFilterWidth(held.sample)
end
table.insert(filters,1,{name=held.name,left=right-width,right=right})
right=right-width-gap
end
end
local count=A.listSearchCountWidth()
local need=A.listSearchBoxWidth()
local room=right-count-gap
local width=math.min(need,room)
if width<1 then
width=1
end
box:SetWidth(width)
frame.searchBandLayout={
host=host,need=need,floor=A.listSearchBoxFloor(),room=room,width=width,
countLeft=width+gap,countWidth=count,filters=filters,
}
return frame.searchBandLayout
end
function A.searchBandLines()
if not(window and window.searchBox)then
return{"search band  the window has not been built this session, so the band has no placement to state"}
end
local okShown,shown=pcall(window.IsShown,window)
if not(okShown and shown)then
return{"search band  the window is not open, so the band has no placement to state"}
end
if activeBody=="stats"then
return{"search band  Stats is the body that is up and the band is History's, so it is not drawn"}
end
local layout=window.searchBandLayout
if type(layout)~="table"then
return{"search band  no list paint has placed the band since the window was built"}
end
local function figure(value)
return tostring(A.unitFigure(value)or value)
end
local okDrawn,drawn=pcall(window.searchBox.GetWidth,window.searchBox)
local state
if layout.width>=layout.need then
state="at that width"
else
state=("giving up room to %s against the one-name floor of %s%s"):format(figure(layout.width),
figure(layout.floor),layout.width<layout.floor and", under it"or"")
end
local out={
("search band  host %s wide, edges from its left. The box is drawn %s wide against its placeholder's %s, %s")
:format(figure(layout.host),(okDrawn and type(drawn)=="number")and figure(drawn)or"unanswered",
figure(layout.need),state),
}
local okCount,countShown=pcall(window.searchCount.IsShown,window.searchCount)
out[#out+1]=("search band count  left %s, %s wide, %s"):format(figure(layout.countLeft),
figure(layout.countWidth),(okCount and countShown)and"shown"or"hidden")
if#layout.filters==0 then
out[#out+1]="search band filters  none was built, the control module not having loaded"
end
for i=1,#layout.filters do
local held=layout.filters[i]
out[#out+1]=("search band %s  left %s, right %s"):format(held.name,figure(held.left),figure(held.right))
end
return out
end
local function paintSearchCount(frame,reuse)
if not(frame and frame.searchCount)then
return
end
local active=filterBand.narrowing()
frame.searchCount:SetText(active and A.searchCountLine(searchShown,searchScoped)or"")
frame.searchCount:SetShown(active)
if frame.searchClear then
frame.searchClear:SetShown(searchText~=nil)
end
filterBand.paint(frame,reuse)
filterBand.place(frame)
end
local function paintListFoot(listing,rows,total,leftCount,scopedMatches,emptyWhy)
if listing then
local shown=total-(leftCount or 0)
local matched=scopedMatches or shown
local _,countSeason,countBound=A.windowScope()
local shape=window.listShape or{}
A.trace("listCount",{matched=matched,unfinished=leftCount or 0,shown=shown,
rows=#rows,format=activeFormat,season=countSeason,scopeFrom=countBound,
listHead=window.listHead and window.listHead:IsShown()and"fixed"or"hidden",
seasonBreaks=shape.seasonBreaks,icons=shape.icons,squares=shape.squares},"ui")
end
window.listEmpty:SetText(emptyWhy or"")
A.style(window.listEmpty,"note","dimmer")
window.listEmpty:SetShown(listing and emptyWhy~=nil and#rows==0)
end
function filterBand.paintWorldStrip()
local held=filterBand.strip
if not(window and window.summary and type(held)=="table"and held.format==activeFormat
and held.character==A.windowCharacter()and held.scope==A.summaryScope()
and type(A.storeMarkSame)=="function"and A.storeMarkSame(held.mark,A.storeMark()))then
return false
end
local _,season,bound=A.windowScope()
local okListed,records=pcall(filterBand.worldRecords,season,bound)
if not okListed then
return false
end
local reading={}
for key,value in pairs(held.reading)do
reading[key]=value
end
reading.hero=A.worldReading(records,(type(A.scopeNow)=="function"and A.scopeNow())or time())
return A.paintStandingStrip(window.summary,held.summary,reading)~=nil
end
local function paintSearchedList(reuse)
if not(window and window.list)then
return false
end
if activeFormat=="world"and activeBody~="stats"then
local okStrip,painted=pcall(A.withPaintScope,filterBand.paintWorldStrip)
if not(okStrip and painted)then
A.refreshWindow()
return true
end
end
return A.withPaintScope(function()
local listing=activeBody~="stats"
local rows,_,total,_,leftCount,emptyWhy,scopedMatches,listColumns=listRows()
lastRows=total
pcall(applyPaneLayout,window,listColumns,#rows)
A.setRows(window.list,rows)
window.listHead:SetShown(listing and listHeadShown(listColumns,#rows))
pcall(darkList.traceSessions,window)
pcall(paintListFoot,listing,rows,total,leftCount,scopedMatches,emptyWhy)
paintSearchCount(window,reuse)
return true
end)
end
function filterBand.canonical(text)
local played=A.playedSpecs(nil,nil,nil)
for i=1,#played do
if played[i].spec:lower()==text:lower()then
return played[i].spec,true
end
end
return text,false
end
function filterBand.trace(filter,choice,via)
A.trace("filter",{filter=filter,choice=choice or"all",shown=searchShown,
scoped=searchScoped,via=via},"ui")
end
function A.setMatchFilter(filter,choice,via)
if filter~="result"and filter~="spec"and filter~="zone"then
return nil
end
if type(choice)=="string"then
choice=choice:match("^%s*(.-)%s*$")
if choice==""or choice:lower()=="all"then
choice=nil
end
elseif choice~=nil then
choice=nil
end
local traced
if filter=="result"then
if choice~=nil then
choice=choice:lower()
local known=false
for i=1,#filterBand.RESULT_CHOICES do
if filterBand.RESULT_CHOICES[i].value==choice then
known=true
end
end
if not known then
return nil
end
end
filterBand.result=choice
traced=choice
elseif filter=="zone"then
filterBand.zone=choice
traced=choice~=nil and"zone"or nil
else
if choice~=nil then
local matched
choice,matched=filterBand.canonical(choice)
traced=matched and choice or"typed"
end
filterBand.spec=choice
end
if not paintSearchedList()then
pcall(listRows)
end
pcall(filterBand.trace,filter,traced,via)
return searchShown,searchScoped
end
function A.matchFilter()
if window==nil then
pcall(listRows)
end
return filterBand.result,filterBand.spec,searchShown,searchScoped,filterBand.zone
end
filterBand.SEARCH_SETTLE=0.6
filterBand.searchGeneration=0
local function traceSearch(via)
local excluding=0
for i=1,#searchTerms do
if searchTerms[i].exclude then
excluding=excluding+1
end
end
A.trace("search",{terms=#searchTerms,excluding=excluding,shown=searchShown,
scoped=searchScoped,via=via},"ui")
end
function A.setMatchSearch(text,via)
if type(text)~="string"or text:match("^%s*$")then
text=nil
end
if via=="typed"and text==searchText then
return searchTerms,searchShown,searchScoped
end
searchText=text
searchTerms=A.searchTerms(text)
if via~="typed"and window and window.searchBox then
local ok,shown=pcall(window.searchBox.GetText,window.searchBox)
if not ok or shown~=(text or"")then
pcall(window.searchBox.SetText,window.searchBox,text or"")
end
end
if not paintSearchedList(true)then
pcall(listRows)
end
filterBand.searchGeneration=filterBand.searchGeneration+1
if via=="typed"and type(C_Timer)=="table"and type(C_Timer.After)=="function"then
local generation=filterBand.searchGeneration
C_Timer.After(filterBand.SEARCH_SETTLE,function()
if generation==filterBand.searchGeneration then
pcall(traceSearch,via)
end
end)
else
pcall(traceSearch,via)
end
return searchTerms,searchShown,searchScoped
end
function A.searchAddParticipant(guid,owner,mods,source)
mods=type(mods)=="table"and mods or{}
source=source or"match"
local keys={}
if mods.shift==true then
keys[#keys+1]="shift"
end
if mods.ctrl==true then
keys[#keys+1]="ctrl"
end
if mods.alt==true then
keys[#keys+1]="alt"
end
local held=table.concat(keys,"-")
local kind=mods.ctrl==true and"spec"or"name"
local exclude=mods.alt==true
local function refuse(reason)
A.trace("search-click",{source=source,modifiers=held,kind=kind,state="refused",
reason=reason,terms=#searchTerms},"ui")
return"refused",searchTerms,searchShown,searchScoped
end
local record=type(owner)=="table"and owner.record or nil
if type(record)~="table"and type(owner)=="table"and owner.recordKind=="match"
and owner.recordId~=nil then
record=A.match(owner.recordId)
end
local participant=type(record)=="table"and type(record.participants)=="table"
and type(guid)=="string"and record.participants[guid]or nil
if type(participant)~="table"then
return refuse("noRecord")
end
local term
if kind=="spec"then
local spec=type(participant.spec)=="string"and participant.spec~=""and participant.spec or nil
local class=type(participant.class)=="string"and participant.class~=""and participant.class or nil
if not spec then
A.trace("search-click",{source=source,modifiers=held,kind=kind,state="nospec",
terms=#searchTerms},"ui")
return"nospec",searchTerms,searchShown,searchScoped
end
term=class and("%s %s"):format(spec,class)or spec
else
if type(participant.name)~="string"or participant.name==""then
return refuse("noName")
end
term=participant.name
end
local wanted=A.foldText(term)
local signed=(exclude and"-"or"")..term
local pieces={}
local outcome="added"
if type(searchText)=="string"then
for piece in(searchText..","):gmatch("([^,]*),")do
local trimmed=piece:match("^%s*(.-)%s*$")
if trimmed~=""then
local lead=trimmed:sub(1,1)
local excluding=lead=="-"or lead=="!"
local body=excluding and trimmed:sub(2):match("^%s*(.-)%s*$")or trimmed
if outcome=="added"and A.foldText(body)==wanted then
outcome=excluding==exclude and"duplicate"or"flipped"
pieces[#pieces+1]=outcome=="flipped"and signed or trimmed
else
pieces[#pieces+1]=trimmed
end
end
end
end
if outcome=="added"then
pieces[#pieces+1]=signed
end
local terms,shown,scoped=searchTerms,searchShown,searchScoped
if outcome~="duplicate"then
terms,shown,scoped=A.setMatchSearch(table.concat(pieces,", "),"click")
end
if not(window and window:IsShown())then
pcall(A.showWindow)
end
A.trace("search-click",{source=source,modifiers=held,kind=kind,state=outcome,
terms=#terms},"ui")
return outcome,terms,shown,scoped
end
function A.matchSearch()
return searchText
end
local function detailRows(record,isLeft,available)
if record and isLeft then
local ok,lines=pcall(A.incompleteDetailLines,record)
if not ok or type(lines)~="table"then
A.noteError(lines,"incomplete-detail")
return{{text=darkList.incompleteFallback(record),height=A.metric("lineHeight")}}
end
local rows={}
for i=1,#lines do
rows[i]={text=lines[i],height=lineHeight(lines[i])}
end
return rows
end
if not record then
return{{text="No match selected.",height=A.metric("lineHeight")}}
end
local lines,guids,cells,heads=A.detailLines(record,true)
local needed=A.detailWindowBody(record)
local body=needed
if type(available)=="number"and available>needed then
body=available
end
local nameWidth=A.metric("rowName")+(body-needed)
local rows={}
for i=1,#lines do
local c=cells and cells[i]or nil
local h=heads and heads[i]or nil
if h and type(h.table)=="table"then
h.table.available=body
end
if c then
rows[i]={cells=c,guid=c.guid,height=A.metric("participantRow"),nameWidth=nameWidth}
elseif h and h.kind=="objectives"then
h.available=body
rows[i]={head=h,text=lines[i],
height=h.look=="team"and A.objectiveCardsHeight()or A.objectivesHeight()}
elseif h and h.kind=="rosterFoot"then
h.available=body
rows[i]={head=h,text=lines[i],height=A.metric("rowHeight")}
elseif h and h.kind=="pacing"then
local drawn=#(h.pacing and h.pacing.rounds or{})
if drawn>darkList.PACE_ROWS then
drawn=darkList.PACE_ROWS
end
rows[i]={head=h,text=lines[i],height=A.paceHeight(drawn)}
elseif h and h.kind=="lobbyGroup"then
rows[i]={head=h,text=lines[i],height=A.metric("rosterHeadRow")}
elseif h and h.kind=="lobbyHead"then
rows[i]={head=h,text=lines[i],
height=A.metric("rosterHeadRow")+A.metric("rosterHeadGap")}
elseif h and(h.kind=="lobbyRow"or h.kind=="lobbyYou"or h.kind=="lobbyFoot")then
rows[i]={head=h,text=lines[i],height=A.metric("rowHeight"),
guid=guids and guids[i]or nil}
elseif h and h.kind=="roster"then
rows[i]={head=h,text=lines[i],
height=A.metric("rosterHeadRow")+A.metric("rosterHeadGap")}
elseif h and(h.kind=="heading"or h.kind=="headline")then
h.available=body
local game=A.matchHeadGame()
local height=game and A.headHeight()or A.headSubHeight()
if h.kind=="heading"then
height=game and A.matchBannerHeight()or A.headHeight()
end
rows[i]={head=h,text=lines[i],height=height}
elseif h and h.kind=="build"then
rows[i]={head=h,text=lines[i],height=A.metric("participantRow")}
elseif h and(h.kind=="ladder"or h.kind=="cards"or h.kind=="tally")then
h.available=body
local height=A.roundCardsHeight(h.cards)
if h.kind=="ladder"then
height=A.ladderHeight()
elseif h.kind=="tally"then
height=A.outingCellsHeight()
end
rows[i]={head=h,text=lines[i],height=height}
else
local stamps=(h~=nil and h.kind=="stamps")or nil
local text=lines[i]
if h~=nil and h.parts~=nil then
text=betweenItems("  ",h.parts,stamps)or text
end
rows[i]={text=text,height=lineHeight(text,stamps),
guid=guids and guids[i]or nil,
stamps=stamps}
end
end
return rows
end
local function paintAsk()
if not(window and window.askHost)then
return
end
local key=A.askShowing()
activeAsk=key
local _,season,bound=A.windowScope()
local character=A.windowCharacter()
A.style(window.askOver,"label","dim")
window.askFormat:SetText(activeFormat==nil and"All formats"or A.formatLabel(activeFormat))
A.style(window.askFormat,"bodyText","text")
local matches,_,undated=A.askPopulation(activeFormat,season,character,bound)
local nouns=filterBand.nouns()
local count=("%d %s"):format(matches,matches==1 and nouns[1]or nouns[2])
if(undated or 0)>0 then
count=("%s, %d undated"):format(count,undated)
end
window.askCount:SetText(count)
A.style(window.askCount,"note","dim")
local headBare=A.metric("rowLabelPad")+A.textRoom(window.askOver,"OVER")
+A.metric("chipGap")+A.textRoom(window.askFormat,window.askFormat:GetText()or"")
local headRow=headBare+A.metric("chipGap")+A.textRoom(window.askCount,count)
local headLimit=type(A.viewRowHeadRoom)=="function"and A.viewRowHeadRoom(window.summary)
or A.askSplitWidth()
window.askCountHeld=headRow<=headLimit
window.askCount:SetShown(window.askCountHeld)
window.viewRow.headWidth=window.askCountHeld and headRow or headBare
local tableMode=A.tableViewShowing()
local mapsMode=tableMode~=nil
if A.askAcross()and not mapsMode then
window.askKeptRow=nil
shownAskRow=A.askRowShowing()
local overview=type(A.allOverview)=="function"and A.allOverview(season,character,bound)or nil
A.paintStatsOverview(window,overview,season,bound)
return"overview",nil
end
if A.specsShowing()then
window.askKeptRow=nil
shownAskRow=A.askRowShowing()
return"spec",nil
end
local answers=mapsMode and{}or A.askAnswers(activeFormat,season,character,bound)
local cards=A.askCards(answers)
local function hasRows(answer)
return type(answer)=="table"and((type(answer.rows)=="table"and#answer.rows>0)
or(type(answer.under)=="table"and#answer.under>0))
end
local chosenDraws=false
for i=1,#cards do
if cards[i]and hasRows(answers[i])and cards[i].key==key then
chosenDraws=true
end
end
if not chosenDraws then
for i=1,#cards do
if cards[i]and hasRows(answers[i])then
key=cards[i].key
break
end
end
end
activeAsk=key
local cardPad=A.metric("cardPad")
local cardRoom=A.askSplitWidth()-cardPad*2
local gap=A.metric("cardHeadGap")
window.askCardShare=nil
local ladder={rate=true,record=true,over=false}
local iconRoom=A.metric("compSwatch")+A.metric("chipGap")
local function subjectRoom(region,face)
if type(face.members)=="table"and#face.members>0 then
local need=0
for m=1,#face.members do
local member=face.members[m]
need=need+iconRoom+A.textRoom(region,A.chipText(member))
+(m>1 and A.metric("compChipGap")or 0)
end
return need
end
return A.textRoom(region,face.name)+(face.classToken~=nil and iconRoom or 0)
end
local rowPlan=nil
for i=1,#window.askCards do
local face=cards[i]
if answers[i]~=nil and face and face.name~=nil then
A.style(window.askCards[i].name,"nameMedium","text")
local shares=A.askCardRow({
name=subjectRoom(window.askCards[i].name,face),
rate=A.labelRoom(face.rate),
record=A.labelRoom(face.record),
over=0,
},cardRoom)
shares.over=false
rowPlan=rowPlan or shares
for part in pairs(ladder)do
ladder[part]=ladder[part]and shares[part]==true
end
end
end
window.askLadder=ladder
rowPlan=rowPlan or A.askCardRow({},cardRoom)
local held,drawn,at=nil,0,0
for i=1,#window.askCards do
local card=window.askCards[i]
local answer=answers[i]
local face=cards[i]
if answer==nil or not face then
card:Hide()
else
local chosen=answer.key==key
if chosen then
held=answer
end
card.askKey=answer.key
card.title:SetText(face.title)
local subject=face.name~=nil
local faint=face.faint==true
A.style(card.title,"label",faint and"underText"or(chosen and"accent"or"dim"))
card:EnableMouse(hasRows(answer)==true)
local shares=ladder
local cluster,shown=0,0
for _,part in ipairs({"rate","record"})do
if subject and shares[part]then
cluster=cluster+A.labelRoom(face[part])
shown=shown+1
end
end
if shown>1 then
cluster=cluster+gap
end
local subjectWidth=cardRoom-cluster-(shown>0 and gap or 0)
for m=2,#card.specCells do
card.specCells[m].icon:Hide()
card.specCells[m].name:Hide()
end
card.icon:ClearAllPoints()
card.icon:SetPoint("LEFT",card,"TOPLEFT",cardPad,
-(rowPlan.drop+A.fontSize("nameMedium")/2))
card.name:ClearAllPoints()
if subject and type(face.members)=="table"and#face.members>0 then
A.drawComp(card.specCells,face.members,subjectWidth,{faint=faint,role="nameMedium"})
elseif subject and face.classToken~=nil then
A.drawSpec({icon=card.icon,name=card.name},face.classToken,face.spec,subjectWidth,
{faint=faint,role="nameMedium",class=face.class,fallback=face.name})
else
card.icon:Hide()
card.name:SetPoint("TOPLEFT",card,"TOPLEFT",cardPad,-rowPlan.drop)
card.name:SetText(face.name or(face.empty and(face.emptyText or"none yet"))or"")
A.style(card.name,"nameMedium",(faint and"underText")
or(face.empty and(face.emptyTone or"dimmer"))or"text")
card.name:SetWidth(math.max(1,subjectWidth))
card.name:SetShown(subject or face.empty==true)
end
local edge,edgeOffset=card,-cardPad
local lineFoot=nil
for _,part in ipairs({"record","rate"})do
local region=card[part]
region:ClearAllPoints()
if subject and shares[part]then
if edge==card then
region:SetPoint("TOPRIGHT",card,"TOPRIGHT",edgeOffset,-rowPlan.drop)
lineFoot=region
else
region:SetPoint("BOTTOMRIGHT",edge,"BOTTOMLEFT",edgeOffset,0)
end
edge,edgeOffset=region,-gap
end
region:SetShown(subject and shares[part]==true)
end
card.over:ClearAllPoints()
if lineFoot~=nil then
card.over:SetPoint("TOPRIGHT",lineFoot,"BOTTOMRIGHT",0,-rowPlan.under)
else
card.over:SetPoint("TOPRIGHT",card,"TOPRIGHT",-cardPad,
-(rowPlan.drop+A.fontSize("numberSmall")+rowPlan.under))
end
A.style(card.over,"rowNote",faint and"underText"or"dimmer")
local overRoom=A.askCardOverRoom(cardRoom)
local over=subject and face.over~=nil
and A.fittedForm(card.over,overRoom,face.overForms or{face.over})or nil
card.over:SetWidth(math.max(1,overRoom))
card.over:SetText(over or"")
card.over:SetShown(over~=nil)
card.overDrawn=subject and face.over~=nil and(over or"none")or nil
card.overFrom=lineFoot
local height=A.askCardHeight(over~=nil)
card.record:SetText(face.record or"")
A.style(card.record,"numberSmall",faint and"underText"or"text")
card.rate:SetText(face.rate or"")
local tone=face.tone or"dim"
A.style(card.rate,"numberSmall",tone)
card.edge:SetColorTexture(A.color(tone))
card.edge:Show()
card.edgeTone=tone
card.ground:SetColorTexture(A.color("cardGround"))
card.selection:SetColorTexture(A.color("selection"))
card.selection:SetShown(chosen)
card.hover:SetColorTexture(A.color("hover"))
card:ClearAllPoints()
card:SetPoint("TOPLEFT",window.askHost,"TOPLEFT",0,-(2+at))
card:SetPoint("TOPRIGHT",window.askHost,"TOPRIGHT",0,-(2+at))
at=at+height+A.metric("cardGap")
card:SetHeight(height)
drawn=drawn+1
card:Show()
end
end
window.askEmpty:SetText(drawn>0 and""or"none yet")
A.style(window.askEmpty,"note","dimmer")
window.askEmpty:SetShown(drawn==0 and not mapsMode)
local function captionGap(card)
if not(card and card:IsShown()and card.over:IsShown())then
return nil,nil
end
local target=card.overFrom
if target==nil or not target:IsShown()then
return nil,nil
end
local okB,bottom=pcall(target.GetBottom,target)
local okT,top=pcall(card.over.GetTop,card.over)
if okB and okT and type(bottom)=="number"and type(top)=="number"then
return A.unitFigure(bottom-top),"rect"
end
local point,relative,relativePoint,_,y=card.over:GetPoint(1)
if relative~=target or point~="TOPRIGHT"or relativePoint~="BOTTOMRIGHT"then
return nil,nil
end
return A.unitFigure(-(y or 0)),"anchors"
end
for i=1,#answers do
local answer=answers[i]
if type(answer)=="table"then
local overGap,overGapFrom=captionGap(window.askCards[i])
if window.askCards[i]then
window.askCards[i].overGap,window.askCards[i].overGapFrom=overGap,overGapFrom
end
A.trace("stats-floor",{
card=answer.key,
floor=answer.floor,
ranked=type(answer.rows)=="table"and#answer.rows or 0,
under=type(answer.under)=="table"and#answer.under or 0,
shownUnder=A.askUnderShown(),
asides=window.askCards[i]and window.askCards[i]:IsShown()and window.askCards[i].overDrawn or nil,
overGap=overGap,
overGapFrom=overGapFrom,
cardDrew=cards[i]and((cards[i].noLoss and"noLoss")or(cards[i].empty and"none")
or(cards[i].faint and"fallback")or"lead")or nil,
cardSet=table.concat(A.askKeys(activeFormat),","),
samplesRead=answer.samplesRead,
samplesSkipped=answer.samplesSkipped,
},"ui")
end
end
if held==nil then
for i=1,#answers do
if answers[i]~=nil and answers[i].key==key then
held=answers[i]
end
end
end
if held==nil then
held=answers[1]
end
if tableMode=="bests"then
held=A.bestsAnswer(activeFormat,season,character,bound)
A.trace("stats-bests",{statsView="bests",format=activeFormat,rows=#held.rows,
bestCols=type(held.bestKeys)=="table"and#held.bestKeys or 0,leftOutWins=held.leftOut or 0},"ui")
elseif tableMode=="builds"then
held=A.buildsAnswer(activeFormat,season,character,bound)
if window.buildMeasure==nil then
window.buildMeasure=window:CreateFontString(nil,"ARTWORK","GameFontHighlightSmall")
window.buildMeasure:Hide()
end
A.style(window.buildMeasure,"bodyText","text")
local measured={}
for i=1,#held.rows do
measured[i]={name=A.textRoom(window.buildMeasure,held.rows[i].name),
icons=#(held.rows[i].pvpIcons or{})}
end
local buildColumns=A.rowColumns(held.columns)
local form,_,rowIcons=A.buildIconsForm(
type(buildColumns)=="table"and columnWidths(buildColumns)[1]or nil,measured)
for i=1,#held.rows do
held.rows[i].iconsDrawn=form=="icons"and#(held.rows[i].pvpIcons or{})>0 or nil
end
A.trace("stats-builds",{statsView="builds",format=activeFormat,rows=#held.rows,
buildSpecs=held.specs or 0,beforeBuilds=held.before or 0,unreadBuilds=held.unread or 0,
numbered=held.numbered or 0,rowIcons=rowIcons},"ui")
end
if tableMode=="zones"then
held=A.zonesAnswer(season,character,bound)
A.trace("stats-zones",{statsView="zones",format=activeFormat,rows=#held.rows,
unplaced=held.unplaced or 0,n=held.read or 0},"ui")
end
if tableMode=="maps"then
held=A.mapsAnswer(activeFormat,season,character,bound)
local rateCell,rated=A.askFillers().rate,0
for i=1,#held.rows do
if rateCell(held.rows[i])~="-"then
rated=rated+1
end
end
A.trace("stats-maps",{statsView="maps",format=activeFormat,rows=#held.rows,
ranked=held.ranked or 0,under=held.underCount or 0,floor=held.floor,ratedRows=rated},"ui")
end
if held==nil then
return nil,nil
end
shownAskRow=A.askRowShowing()
local kind=A.askTableKind(held,activeFormat)
if kind~=nil then
window.askKeptRow=nil
return kind,held
end
A.style(window.askPaneHeading,"label","dim")
window.askPaneHeading:SetText(held.group or"")
window.askPaneHeading:Show()
local columns=A.askHeaderColumns(held)
local shown={}
for field,value in pairs(held)do
shown[field]=value
end
shown.rows=A.askSorted(held)
local elements=A.askElements(shown)
local askSortColumn=A.askSort(held.key)
window.askSortQuestion=held.key
local headShown=type(columns)=="table"and#elements>0
local answered=#elements>0
local noteLift=A.fontSize("note")
window.askNote:ClearAllPoints()
if answered then
window.askNote:SetPoint("BOTTOMLEFT",window.askPaneHost,"BOTTOMLEFT",
A.metric("rowLabelPad"),noteLift)
window.askNote:SetPoint("BOTTOMRIGHT",window.askPaneHost,"BOTTOMRIGHT",0,noteLift)
else
window.askNote:SetPoint("TOPLEFT",window.askPaneHeading,"BOTTOMLEFT",0,
-A.metric("paneGap"))
window.askNote:SetPoint("TOPRIGHT",window.askPaneHeading,"BOTTOMRIGHT",0,
-A.metric("paneGap"))
end
window.askPaneHead:SetShown(headShown)
window.askPane.box:ClearAllPoints()
if headShown then
local askWidths
window.askTableSpan,askWidths=paintColumnHead(window.askPaneHead,window.askPaneHeadNames,
window.askPaneHeadRule,columns,askSortColumn)
paintSortButtons(window.askPaneHeadSorts,window.askPaneHead,columns,askWidths)
window.askPane.box:SetPoint("TOPLEFT",window.askPaneHead,"BOTTOMLEFT",0,0)
window.askPane.box:SetPoint("TOPRIGHT",window.askPaneHead,"BOTTOMRIGHT",0,0)
else
window.askTableSpan=nil
for i=1,#window.askPaneHeadNames do
window.askPaneHeadNames[i]:Hide()
end
paintSortButtons(window.askPaneHeadSorts,window.askPaneHead,nil,nil)
if answered then
window.askPane.box:SetPoint("TOPLEFT",window.askPaneHeading,"BOTTOMLEFT",0,-4)
window.askPane.box:SetPoint("TOPRIGHT",window.askPaneHeading,"BOTTOMRIGHT",0,-4)
else
window.askPane.box:SetPoint("TOPLEFT",window.askNote,"BOTTOMLEFT",0,
-A.metric("paneGap"))
window.askPane.box:SetPoint("TOPRIGHT",window.askNote,"BOTTOMRIGHT",0,
-A.metric("paneGap"))
end
end
local noteText=A.askNoteText(held)
local paneHost=A.listViewportRoom({
window=windowHeightFor(window),
filter=statedHeight(window.filterRow),
summary=window.summary and statedHeight(window.summary)or nil,
viewRow=statedHeight(window.viewRow),
head=0,
strip=0,
})
local headRoom=headShown and(statedHeight(window.askPaneHead)or A.metric("rowHeadRow"))or nil
local noteRoom=compTextHeight(noteText,"note",A.askTableWidth())
local bandLines=answered and A.askRowLines(held,shownAskRow)or{}
local metLook=answered and A.askRowOpensKey(held)=="MET IN"
local bandIds={}
for i=1,#bandLines do
if bandLines[i].kind=="specMet"and bandLines[i].id~=nil
and(not metLook or type(bandLines[i].look)=="table")then
bandIds[#bandIds+1]=bandLines[i].id
end
end
local bandHeadRow=metLook and 1 or A.metric("rowHeadRow")
window.askBandHead:SetHeight(bandHeadRow)
local bandTop=A.metric("rowHeight")+bandHeadRow
if noteRoom>0 then
noteRoom=noteRoom+noteLift
end
local bandRoom=0
if#bandIds>0 and type(paneHost)=="number"then
local fits=A.askBandRoom(paneHost-bandTop,{
heading=A.fontSize("label"),
head=headRoom,
note=noteRoom,
wanted=(#bandIds+(metLook and 1 or 0))*A.metric("rowHeight"),
})
bandRoom=fits>0 and(fits+bandTop)or 0
end
local bandBlock=bandRoom>0 and(bandRoom+A.metric("paneGap"))or 0
if answered then
window.askNote:ClearAllPoints()
window.askNote:SetPoint("BOTTOMLEFT",window.askPaneHost,"BOTTOMLEFT",A.metric("rowLabelPad"),noteLift)
window.askNote:SetPoint("BOTTOMRIGHT",window.askPaneHost,"BOTTOMRIGHT",0,noteLift)
end
window.askMatchBand:ClearAllPoints()
window.askMatchBand:SetPoint("BOTTOMLEFT",window.askNote,"TOPLEFT",-A.metric("rowLabelPad"),
A.metric("paneGap"))
window.askMatchBand:SetPoint("BOTTOMRIGHT",window.askNote,"TOPRIGHT",0,A.metric("paneGap"))
window.askMatchBand:SetHeight(bandRoom>0 and bandRoom or 1)
window.askMatchBand:SetShown(bandRoom>0)
local bandColumns=A.playedOnColumns()
local bandRows={}
if bandRoom>0 and metLook then
for i=1,#bandLines do
local line=bandLines[i]
if line.kind=="specMetNames"then
bandRows[#bandRows+1]=line
elseif line.kind=="specMet"and line.id~=nil and type(line.look)=="table"then
bandRows[#bandRows+1]={kind="specMet",id=line.id,look=line.look,text=line.text,
stay=true,names=line.names}
end
end
elseif bandRoom>0 then
for i=1,#bandIds do
local record=type(A.match)=="function"and A.match(bandIds[i])or nil
if type(record)=="table"then
bandRows[#bandRows+1]={
id=bandIds[i],
kind="match",
matchRecord=record,
stay=true,
cells=A.rowColumnCells(record,nil,nil,bandColumns),
columns=bandColumns,
text=A.matchLineText(bandIds[i]),
}
end
end
end
A.style(window.askBandKey,"label","dim")
window.askBandKey:SetText(bandLines[1]and bandLines[1].key or"")
A.style(window.askBandCount,"note","dim")
local picked=nil
for _,rows in ipairs({held.rows or{},held.under or{}})do
for i=1,#rows do
if A.askRowKey(rows[i])==shownAskRow then
picked=rows[i]
end
end
end
window.askBandCount:SetText(bandLines[1]and(bandLines[1].text
..(picked and picked.name and(", "..tostring(picked.name))or""))or"")
if metLook then
for i=1,#window.askBandHeadNames do
window.askBandHeadNames[i]:Hide()
end
window.askBandHeadRule:Hide()
window.askBandSpan=nil
else
window.askBandSpan=bandRoom>0 and paintColumnHead(window.askBandHead,window.askBandHeadNames,
window.askBandHeadRule,bandColumns)or nil
window.askBandHeadRule:SetColorTexture(A.color("hairline"))
window.askBandHeadRule:Show()
end
rowSurface.metRowPaint=rowSurface.metRowPaint+1
A.setRows(window.askMatches,bandRows)
local bandMatchRows=0
for i=1,#bandRows do
if bandRows[i].kind~="specMetNames"then
bandMatchRows=bandMatchRows+1
end
end
A.trace("ask-band",{card=held.key,bandSpan=bandRoom>0 and"half"or"none",rows=bandMatchRows,
graphFolded=A.graphFolded()},"ui")
if bandRoom>0 and type(A.noteViewport)=="function"then
local _,bandWhy=A.bandHeight(window.askMatches.box)
A.noteViewport("the answer's matches",bandRoom-bandTop,A.metric("rowHeight"),false,bandWhy,
window.askMatches.box,
{composed=true,box=window.askMatches.name.."ScrollBox"})
end
local floorText=A.askFloorLine(held)
local floorBlock=floorText~=nil and(A.metric("rowHeight")+A.metric("paneGap"))or 0
local room=A.askPaneRoom({
host=paneHost,
heading=A.fontSize("label"),
head=headRoom,
note=noteRoom,
band=bandBlock+floorBlock,
})
local over=0
if type(room)=="number"then
local rows,whole=A.viewportRows(room,A.metric("rowHeight"))
if rows>=1 then
over=room-whole
end
end
window.askFloorLine:ClearAllPoints()
if answered then
local under=bandRoom>0 and window.askMatchBand or window.askNote
if floorText~=nil then
window.askFloorLine:SetPoint("BOTTOMLEFT",under,"TOPLEFT",
under==window.askNote and-A.metric("rowLabelPad")or 0,A.metric("paneGap"))
window.askFloorLine:SetPoint("BOTTOMRIGHT",under,"TOPRIGHT",0,A.metric("paneGap"))
under=window.askFloorLine
end
window.askPane.box:SetPoint("BOTTOMLEFT",under,"TOPLEFT",0,
A.metric("paneGap")+over)
window.askPane.box:SetPoint("BOTTOMRIGHT",under,"TOPRIGHT",0,
A.metric("paneGap")+over)
else
window.askFloorLine:SetPoint("TOPLEFT",window.askNote,"BOTTOMLEFT",-A.metric("rowLabelPad"),
-A.metric("paneGap"))
window.askFloorLine:SetPoint("TOPRIGHT",window.askNote,"BOTTOMRIGHT",0,-A.metric("paneGap"))
window.askPane.box:SetPoint("BOTTOMLEFT",window.askPaneHost,"BOTTOMLEFT",0,over)
window.askPane.box:SetPoint("BOTTOMRIGHT",window.askPaneHost,"BOTTOMRIGHT",0,over)
end
if type(A.noteViewport)=="function"then
local _,why=A.bandHeight(window.askPane.box)
A.noteViewport("the answer table",room and(room-over)or nil,A.metric("rowHeight"),false,why,
window.askPane.box,{composed=room~=nil,box=window.askPane.name.."ScrollBox"})
end
for i=1,#elements do
elements[i].columns=columns
end
A.setRows(window.askPane,elements)
window.askKeptRow=nil
if shownAskRow~=nil then
for i=1,#elements do
if elements[i].askRow==shownAskRow then
window.askKeptRow=i
A.keepRowInView(window.askPane,i)
break
end
end
end
A.style(window.askNote,"note","dimmer")
window.askNote:SetText(noteText)
window.askNote:Show()
A.paintFloorLine(window.askFloorLine,floorText)
window.askFloorText=floorText
return nil,held
end
local function detailElements(lines,width)
local out={}
rowSurface.metRowPaint=rowSurface.metRowPaint+1
local room=type(width)=="number"
and(width-A.metric("rowNamePad")*2-A.metric("rowLabelPad"))or nil
for i=1,#lines do
local line=lines[i]
local height
if line.kind=="specSay"then
height=compTextHeight(line.text,"bodyText",room)+A.metric("readingPad")*2
elseif line.kind=="specMet"then
height=A.metric("rowHeight")
else
height=A.metric("readingRow")
end
out[#out+1]={detail=line,height=height,room=room}
end
return out
end
function A.paintSpecEnds(frame,merged,elements)
local row=frame and frame.specEndsRow
if row==nil then
return false
end
local ends=A.specEnds(merged)
local count=#frame.specEnds
local gap=A.metric("paneSplitGap")
local share=math.floor((A.listHostWidth(false)-gap*(count-1))/count)
local pad=A.metric("cardPad")
local said={}
for i=1,count do
local card=frame.specEnds[i]
local face=ends[i]or{}
card:ClearAllPoints()
card:SetPoint("TOPLEFT",row,"TOPLEFT",(i-1)*(share+gap),0)
card:SetSize(share,A.askCardHeight())
card.ground:SetColorTexture(A.color("cardGround"))
card.title:SetText(face.title or"")
A.style(card.title,"label","dim")
local subject=face.name~=nil
card.name:ClearAllPoints()
if subject then
local room=share-pad*2-A.textRoom(card.rate,face.rate or"")-A.metric("cardHeadGap")
A.drawSpec({icon=card.icon,name=card.name},face.classToken,face.spec,room,
{role="nameMedium",class=face.class,fallback=face.name})
else
card.icon:Hide()
card.name:SetPoint("BOTTOMLEFT",card,"BOTTOMLEFT",pad,pad)
card.name:SetText("")
card.name:Hide()
end
card.rate:SetText(face.rate or"")
A.style(card.rate,"numberSmall",face.tone or"dim")
card.rate:SetShown(subject)
card.record:SetText(face.record or"")
A.style(card.record,"note","dimmer")
card.record:SetShown(subject)
card:Show()
said[#said+1]=("%s:%s"):format(tostring(face.kind),subject and tostring(face.spec)or"none")
end
row:Show()
local under=0
for i=1,#merged do
for _,side in ipairs({merged[i].against,merged[i].alongside})do
if type(side)=="table"and not A.specSideRanked(side)then
under=under+1
end
end
end
local sort,up=A.specSort()
A.trace("stats-specs",{sort=sort,mode=up and"ascending"or"descending",
n=type(elements)=="table"and#elements or 0,under=under,floor=A.rankFloor("specs"),
ends=table.concat(said,",")},"ui")
return true
end
local function paintViewChoice(_,_,_,columns,rowCount)
local stats=activeBody=="stats"
local listing=not stats
if window.summary then
window.summary:Show()
end
window.viewRow:SetShown(stats)
if type(A.setHalfTabsChosen)=="function"then
A.setHalfTabsChosen(window.halfTabs,stats and"stats"or"matches")
end
window.viewRow:SetHeight(viewRowHeight())
window.listHost:SetShown(listing)
window.listHead:SetShown(listing and listHeadShown(columns,rowCount))
local kind,held=nil,nil
local specsMode=stats and A.specsShowing()
local overviewMode=stats and A.askAcross()and A.tableViewShowing()==nil
local mapsMode=stats and A.tableViewShowing()~=nil
if window.askHost then
window.askHost:SetShown(stats and not specsMode and not overviewMode and not mapsMode)
if stats then
kind,held=paintAsk()
end
window.askPaneHost:SetShown(stats and kind==nil)
if(not stats or kind~=nil)and window.askMatchBand then
window.askMatchBand:Hide()
end
end
window.tableShowing=kind
window.compHost:SetShown(kind=="comp"or kind=="spec")
if kind~="overview"and type(A.hideStatsOverview)=="function"then
A.hideStatsOverview(window)
end
if kind==nil or kind=="overview"then
window.specNote:Hide()
shownSpec=nil
return
end
local compsView,specsView=kind=="comp",kind=="spec"
local openKey=shownAskRow
local elements={}
local openAt=nil
local detailOpen=false
if compsView then
local sorted=A.askSorted(held)
local ranks=#sorted
local under=type(held)=="table"and held.under or nil
if A.askUnderShown()and type(under)=="table"then
for i=1,#under do
sorted[#sorted+1]=under[i]
end
end
if window.compMeasure==nil then
window.compMeasure=window.compHost:CreateFontString(nil,"ARTWORK","GameFontHighlightSmall")
window.compMeasure:Hide()
end
A.style(window.compMeasure,"bodyText","text")
local measured,measuredShort={},{}
for i=1,#sorted do
local labels,shortLabels={},{}
local members=type(sorted[i].tally)=="table"and sorted[i].tally.members or{}
for m=1,math.min(#members,3)do
labels[m]=A.textRoom(window.compMeasure,A.chipText(members[m])or"")
shortLabels[m]=A.textRoom(window.compMeasure,A.chipShortText(members[m])or"")
end
measured[i]=labels
measuredShort[i]=shortLabels
end
local chips,need,bound,needShort=A.compTableChipsForm(A.askPaneWidth(),measured,measuredShort)
A.trace("comp-chips",{chips=chips,n=#sorted,format=activeFormat,
need=need and A.unitFigure(need)or nil,chipRoom=bound and A.unitFigure(bound)or nil,
needShort=needShort and A.unitFigure(needShort)or nil},"ui")
for i=1,#sorted do
if i==ranks+1 then
elements[#elements+1]={divider=true}
end
elements[#elements+1]={row=sorted[i].tally,faint=i>ranks or nil,
chips=(chips=="icons"or chips=="short")and chips or"names"}
if openKey~=nil and sorted[i].key==openKey then
openAt=#elements
local lines=A.compRowLines(sorted[i].tally)
for _,line in ipairs(detailElements(lines,A.askPaneWidth()))do
elements[#elements+1]=line
detailOpen=true
end
end
end
end
A.setRows(window.comps,elements)
if openAt~=nil then
A.keepRowInView(window.comps,openAt)
end
A.style(window.compHeading,"label","dim")
window.compHeading:Show()
if window.compHeadGames then
window.compHeadGames:SetText(A.compCountName(activeFormat))
end
for i=1,#(window.compHeadSorts or{})do
window.compHeadSorts[i]:SetShown(compsView)
end
for i=1,#window.compHeadNames do
local label=window.compHeadNames[i]
A.style(label,"label",(compsView and label==window.compHeadByKey.rate)and"accent"or"dim")
label:Show()
end
window.compHeadRule:SetColorTexture(A.color("hairline"))
window.compHeadRule:Show()
local ranked=compsView and A.bandShown({
name="comp table header",
heading=A.metric("rowHeadRow"),
rowHeight=A.metric("rowHeight"),
contents=#elements,
})or false
window.compHead:SetShown(ranked)
window.compFloor:SetText("")
window.compFloor:SetShown(false)
local bandAnchor,bandLeft,bandDrop=window.compHeading,-A.metric("rowNamePad"),-4
if ranked then
bandAnchor,bandLeft,bandDrop=window.compHead,0,-2
end
window.compTableBand:ClearAllPoints()
window.compTableBand:SetPoint("TOPLEFT",bandAnchor,"BOTTOMLEFT",bandLeft,bandDrop)
window.compTableBand:SetPoint("TOPRIGHT",bandAnchor,"BOTTOMRIGHT",0,bandDrop)
window.compMatchTitle:SetText("")
local titleRole="note"
local hostHeight=compHostHeight(window)
local rowsHeight=0
for i=1,#elements do
rowsHeight=rowsHeight+(elements[i].height or A.metric("compRow"))
end
local compFloorText=compsView and A.askFloorLine(held)or nil
local bandRoom=A.compBandRoom(hostHeight,{table=false})
if compFloorText~=nil then
bandRoom=math.max(A.metric("compRow"),bandRoom-A.metric("rowHeight")-6)
end
if rowsHeight>bandRoom then
if detailOpen then
rowsHeight=bandRoom
else
local _,whole=A.viewportRows(bandRoom,A.metric("compRow"))
rowsHeight=whole
end
end
window.compTableBand:SetHeight(rowsHeight)
if compsView and type(A.noteViewport)=="function"then
local _,why=A.bandHeight(window.comps.box)
A.noteViewport("the comp table",rowsHeight,A.metric("compRow"),detailOpen,why,window.comps.box,
{composed=true,box=window.comps.name.."ScrollBox"})
end
local bandDraws=rowsHeight>0
window.compTableBand:SetShown(bandDraws)
window.compNote:ClearAllPoints()
if bandDraws then
window.compNote:SetPoint("TOPLEFT",window.compTableBand,"BOTTOMLEFT",
A.metric("rowNamePad"),-6)
window.compNote:SetPoint("TOPRIGHT",window.compTableBand,"BOTTOMRIGHT",0,-6)
else
window.compNote:SetPoint("TOPLEFT",bandAnchor,"BOTTOMLEFT",
bandLeft+A.metric("rowNamePad"),bandDrop-6)
window.compNote:SetPoint("TOPRIGHT",bandAnchor,"BOTTOMRIGHT",0,bandDrop-6)
end
window.compNote:SetText("")
window.compNote:SetShown(false)
window.compFloorLine:ClearAllPoints()
if bandDraws then
window.compFloorLine:SetPoint("TOPLEFT",window.compTableBand,"BOTTOMLEFT",0,-6)
window.compFloorLine:SetPoint("TOPRIGHT",window.compTableBand,"BOTTOMRIGHT",0,-6)
else
window.compFloorLine:SetPoint("TOPLEFT",bandAnchor,"BOTTOMLEFT",bandLeft,bandDrop-6)
window.compFloorLine:SetPoint("TOPRIGHT",bandAnchor,"BOTTOMRIGHT",0,bandDrop-6)
end
A.paintFloorLine(window.compFloorLine,compFloorText)
window.compFloorText=compFloorText
local paneColumns,paneElements,paneKind=nil,{},nil
local specSort,specAscending=A.specSort()
local specCount=0
shownSpec=nil
local endsShown=false
if specsView then
local _,specSeason,specBound=A.windowScope()
local paneRows,_,_,merged=
A.specRows(activeFormat,specSeason,A.windowCharacter(),specSort,specAscending,specBound)
paneColumns=#paneRows>0 and A.rowColumns("specpair")or nil
paneKind=#paneRows>0 and"spec"or nil
specCount=#paneRows
endsShown=A.paintSpecEnds(window,type(merged)=="table"and merged or{},paneRows)
if type(paneColumns)=="table"then
local spread=A.listColumnShares(paneColumns,A.askPaneWidth())
for i=1,#paneRows do
if type(paneRows[i])=="table"and paneRows[i].columns~=nil then
paneRows[i].columns=spread
end
end
paneColumns=spread
end
local cards=nil
if#paneRows>0 then
local read,answered=pcall(A.specCards,activeFormat,specSeason,A.windowCharacter(),specBound)
cards=read and type(answered)=="table"and answered or nil
end
for i=1,#paneRows do
paneElements[#paneElements+1]=paneRows[i]
local row=type(merged)=="table"and merged[i]or nil
if openKey~=nil and row~=nil and row.key==openKey then
shownSpec=row.key
openAt=#paneElements
local lines=A.specDetailLines(row,A.specStanding(cards,row.key))
for _,line in ipairs(detailElements(lines,A.askPaneWidth()))do
paneElements[#paneElements+1]=line
detailOpen=true
end
end
end
end
window.compMatchTitle:SetShown(false)
if not endsShown then
window.specEndsRow:Hide()
end
window.compPaneSpan=nil
local groupShown=false
if type(paneColumns)=="table"then
for i=1,#paneColumns do
if paneColumns[i].group~=nil then
groupShown=true
break
end
end
end
local stack=A.compPaneStack({group=groupShown==true,table=true})
local headAnchor=endsShown and window.specEndsRow or window.compHeading
local headRoom,headRead=A.roomBelow(headAnchor,window.compHost)
if type(A.noteRoomRead)=="function"then
A.noteRoomRead("comp pane header",headRead,headRoom,headAnchor,window.compHost)
end
local paneHeadShown=paneColumns~=nil and A.bandShown({
name="comp pane header",
heading=stack.group+stack.paneHead,
rowHeight=A.metric("rowHeight"),
contents=#paneElements,
room=headRoom,
})
window.compPaneHead:SetShown(paneHeadShown)
groupShown=groupShown and paneHeadShown
window.specNote:SetText("")
window.specNote:Hide()
local columnTop,footBand=nil,0
if specsView then
columnTop,footBand=A.specViewStack({
heading=endsShown and(A.askCardHeight()+A.metric("paneGap"))or A.fontSize("label"),
foot=0,
})
end
local rowNamePad=A.metric("rowNamePad")
window.compColumn:ClearAllPoints()
if endsShown then
window.compColumn:SetPoint("TOPLEFT",headAnchor,"BOTTOMLEFT",0,-A.metric("paneGap"))
else
window.compColumn:SetPoint("TOPLEFT",headAnchor,"BOTTOMLEFT",-rowNamePad,0)
end
window.compColumn:SetPoint("BOTTOMLEFT",window.compHost,"BOTTOMLEFT",0,footBand)
window.compColumn:SetWidth(A.askPaneWidth())
local columnDrop=0
if groupShown then
window.compGroupHead:SetHeight(A.fontSize("label")+4)
window.compGroupHead:ClearAllPoints()
window.compGroupHead:SetPoint("TOPLEFT",window.compColumn,"TOPLEFT",0,-(columnDrop+4))
window.compGroupHead:SetPoint("TOPRIGHT",window.compColumn,"TOPRIGHT",0,-(columnDrop+4))
columnDrop=columnDrop+stack.group
else
columnDrop=columnDrop+4
end
window.compGroupHead:SetShown(groupShown)
window.compPaneHead:ClearAllPoints()
window.compPaneHead:SetPoint("TOPLEFT",window.compColumn,"TOPLEFT",0,-columnDrop)
window.compPaneHead:SetPoint("TOPRIGHT",window.compColumn,"TOPRIGHT",0,-columnDrop)
window.compMatchBand:ClearAllPoints()
window.compMatchBand:SetPoint("BOTTOMLEFT",window.compColumn,"BOTTOMLEFT",0,0)
if paneColumns then
local paneWidths
window.compPaneSpan,paneWidths=paintColumnHead(window.compPaneHead,
window.compPaneHeadNames,window.compPaneHeadRule,paneColumns,
paneKind=="spec"and specSort or nil)
if groupShown then
paintGroupHead(window.compGroupHead,window.compGroupNames,paneColumns,paneWidths)
end
paintSortButtons(window.compPaneHeadSorts,window.compPaneHead,
(paneHeadShown and paneKind=="spec")and paneColumns or nil,paneWidths)
if paneHeadShown then
window.compMatchBand:SetPoint("TOPLEFT",window.compPaneHead,"BOTTOMLEFT",0,0)
window.compMatchBand:SetPoint("TOPRIGHT",window.compPaneHead,"BOTTOMRIGHT",0,0)
else
window.compMatchBand:SetPoint("TOPLEFT",window.compColumn,"TOPLEFT",0,-columnDrop)
window.compMatchBand:SetPoint("TOPRIGHT",window.compColumn,"TOPRIGHT",0,-columnDrop)
end
else
paintSortButtons(window.compPaneHeadSorts,window.compPaneHead,nil,nil)
window.compMatchBand:SetPoint("TOPLEFT",window.compColumn,"TOPLEFT",0,-columnDrop)
window.compMatchBand:SetPoint("TOPRIGHT",window.compColumn,"TOPRIGHT",0,-columnDrop)
end
if columnTop==nil then
columnTop=A.compColumnTop({
heading=A.fontSize("label"),
head=ranked and statedHeight(window.compHead)or nil,
band=bandDraws and rowsHeight or 0,
note=0,
title=compTextHeight(window.compMatchTitle:GetText(),titleRole),
})
end
local bandRoomUnder=nil
if type(hostHeight)=="number"then
bandRoomUnder=hostHeight-columnTop-columnDrop-footBand
-(paneHeadShown and(statedHeight(window.compPaneHead)or A.metric("rowHeadRow"))or 0)
if bandRoomUnder<0 then
bandRoomUnder=0
end
end
local bandOver=0
if type(bandRoomUnder)=="number"and not(specsView and detailOpen)then
local rows,whole=A.viewportRows(bandRoomUnder,A.metric("rowHeight"))
if rows>=1 then
bandOver=bandRoomUnder-whole
end
end
if bandOver>0 then
window.compMatchBand:SetPoint("BOTTOMLEFT",window.compColumn,"BOTTOMLEFT",0,bandOver)
end
if type(A.notePromisedRoom)=="function"then
local room=A.bandHeight(window.compMatchBand)
A.notePromisedRoom("the pane below the comp table",A.metric("rowHeight"),room)
end
if type(A.noteViewport)=="function"then
local _,why=A.bandHeight(window.compMatches.box)
A.noteViewport("the spec table",bandRoomUnder and(bandRoomUnder-bandOver)or nil,
A.metric("rowHeight"),specsView and detailOpen,why,window.compMatches.box,
{composed=bandRoomUnder~=nil,box=window.compMatches.name.."ScrollBox"})
end
A.setRows(window.compMatches,paneElements)
if specsView and openAt~=nil then
A.keepRowInView(window.compMatches,openAt)
end
window.compHeading:SetText(type(held)=="table"and held.group or"")
window.compHeading:Show()
window.specCount=specCount
end
local matchWindows={}
local matchOrder={}
local matchPool={}
local function matchKey(kind,id)
return((kind=="incomplete")and"incomplete:"or"match:")..tostring(id)
end
local function traceMatchWindow(state,kind,id,source,frame)
if type(A.trace)~="function"then
return false
end
local open=0
for i=1,#matchOrder do
if matchWindows[matchOrder[i]]then
open=open+1
end
end
local size=frame and A.frameGeometry(frame)or nil
A.trace("match-window",{
state=state,kind=kind,id=id,
source=source or"select",windowsOpen=open,
width=size and A.unitFigure(size.width)or nil,
height=size and A.unitFigure(size.height)or nil,
sizeFrom=frame and frame.sizeFrom or nil,
widthFrom=frame and frame.widthFrom or nil,
},"ui")
return true
end
function A.matchWindowTitle(record,kind)
local id=(type(record)=="table")and record.id or nil
if kind=="incomplete"then
return id and("Unfinished #%s"):format(A.matchIdText(id))or"Unfinished"
end
if id==nil then
return"Match"
end
local noun=record.format=="world"and"Outing"or"Match"
local words={("%s #%s"):format(noun,A.matchIdText(id))}
local label=record.format and A.formatLabel(record.format)or nil
if label~=nil and label~=""then
words[#words+1]=label
end
words[#words+1]=A.matchTitleStamp(record)
return table.concat(words,"  ")
end
function A.matchWindowRoom(height)
if type(height)~="number"or height<=0 then
return nil
end
local room=height-A.metric("headerHeight")-A.metric("margin")
-A.metric("editHeight")-A.metric("paneEditGap")
if room<0 then
room=0
end
return room
end
local function lineExtent(_,data)
if type(data)=="table"and type(data.height)=="number"then
return data.height
end
return A.metric("lineHeight")
end
function A.matchWindowFit(rows,ceiling)
local content=0
for i=1,type(rows)=="table"and#rows or 0 do
local height=type(rows[i])=="table"and rows[i].height or nil
content=content+(type(height)=="number"and height or A.metric("lineHeight"))
end
local fitted=A.metric("headerHeight")+A.metric("margin")
+A.metric("paneEditGap")+A.metric("editHeight")+content
if type(ceiling)~="number"or ceiling<=0 then
ceiling=A.detailWindowHeight()
end
if fitted>=ceiling then
return ceiling,true
end
return fitted,false
end
local function layoutMatchWindow(frame,height,capped)
frame.editRow:ClearAllPoints()
frame.editRow:SetPoint("BOTTOMLEFT",frame.detailHost,"BOTTOMLEFT",0,0)
frame.editRow:SetPoint("BOTTOMRIGHT",frame.detailHost,"BOTTOMRIGHT",0,0)
local function anchorDetail(extra)
frame.detail.box:SetPoint("BOTTOMLEFT",frame.editRow,"TOPLEFT",0,
A.metric("paneEditGap")+extra)
frame.detail.box:SetPoint("BOTTOMRIGHT",frame.editRow,"TOPRIGHT",0,
A.metric("paneEditGap")+extra)
end
anchorDetail(0)
local room=A.matchWindowRoom(height or windowHeightFor(frame))
local over=0
if type(room)=="number"and capped~=false then
local rows,whole=A.viewportRows(room,A.metric("lineHeight"))
if rows>=1 then
over=room-whole
end
end
anchorDetail(over)
frame.detailRoom=type(room)=="number"and(room-over)or nil
if type(A.noteViewport)=="function"then
local rect,why=A.bandHeight(frame.detail.box)
A.noteViewport(frame.viewportName,frame.detailRoom,A.metric("lineHeight"),true,why,
frame.detail.box,{composed=room~=nil,rect=rect,
box=frame.detail.name.."ScrollBox"})
end
end
local function paintMatchWindow(frame)
local isLeft=frame.recordKind=="incomplete"
local record
if isLeft then
record=type(A.incompleteById)=="function"and A.incompleteById(frame.recordId)or nil
else
record=A.match(frame.recordId)
end
frame.record=record
local recordWidth=A.detailWindowWidth(not isLeft and record or nil)
local screenW,screenH
if type(A.screenSize)=="function"then
screenW,screenH=A.screenSize()
end
local width,widthFrom=recordWidth,"record"
if type(frame.wantWidth)=="number"and frame.wantWidth>recordWidth then
width,widthFrom=frame.wantWidth,frame.wantFrom or"stored"
if type(screenW)=="number"and width>screenW then
width=screenW>recordWidth and screenW or recordWidth
end
end
frame.recordWidth=recordWidth
frame.widthFrom=widthFrom
pcall(frame.SetWidth,frame,width)
local body=A.detailWindowBodyAt(width)
pcall(function()
frame.heading:SetText(A.matchWindowTitle(record,frame.recordKind))
end)
pcall(applyMeasureWidth,frame)
local rows=detailRows(record,isLeft,body)
local function fit()
local height,capped=A.matchWindowFit(rows,frame.ceiling)
pcall(frame.SetHeight,frame,height)
pcall(layoutMatchWindow,frame,height,capped)
frame.fittedHeight=height
frame.sizeFrom=capped and(frame.ceilingFrom or"authored")or"fit"
local floor=A.detailWindowFloor()
pcall(frame.SetResizeBounds,frame,recordWidth,height<floor and height or floor,screenW,screenH)
end
fit()
A.setRows(frame.detail,rows)
pcall(function()
if applyMeasureWidth(frame)then
rows=detailRows(record,isLeft,body)
fit()
A.setRows(frame.detail,rows)
end
end)
pcall(paintEditStrip,frame,record,isLeft)
if record and not isLeft then
pcall(A.traceMatchHead,record.id,rows,frame.fittedHeight)
end
return true
end
local function paintMatchWindows()
for i=1,#matchOrder do
local frame=matchWindows[matchOrder[i]]
if frame and frame:IsShown()then
pcall(paintMatchWindow,frame)
end
end
return true
end
local function openMatchWindowCount()
local n=0
for i=1,#matchOrder do
local frame=matchWindows[matchOrder[i]]
local ok,shown=pcall(function()
return frame and frame:IsShown()
end)
if ok and shown then
n=n+1
end
end
return n
end
local switching
local typedDepth=0
local pendingCost,costFrame
local costFrames=0
local slots={}
local function preciseNow()
if type(GetTimePreciseSec)~="function"then
return nil
end
local ok,seconds=pcall(GetTimePreciseSec)
if ok and type(seconds)=="number"then
return seconds
end
return nil
end
local function millis(seconds)
return A.unitFigure(seconds*1000)
end
function A.switchClock()
if not switching then
return nil
end
return preciseNow()
end
function A.switchPhase(name,started)
if not switching or started==nil then
return false
end
local stopped=preciseNow()
if stopped==nil then
return false
end
switching.phases[name]=(switching.phases[name]or 0)+(stopped-started)
return true
end
local function leanSwitch()
return switching~=nil and switching.mode=="lean"
end
local function flushCost()
local entry=pendingCost
pendingCost=nil
costFrames=0
if costFrame then
pcall(costFrame.SetScript,costFrame,"OnUpdate",nil)
pcall(costFrame.Hide,costFrame)
end
if entry then
A.trace("cost",{
route=entry.route,tabFrom=entry.from,to=entry.to,via=entry.via,mode=entry.mode,
choices=entry.choices,tally=entry.tally,summary=entry.summary,list=entry.list,
page=entry.page,options=entry.options,windows=entry.windows,total=entry.total,
frame1=entry.frame1,frame2=entry.frame2,frame3=entry.frame3,
summaryCached=entry.summaryCached,windowsSkipped=entry.windowsSkipped,
stylesSkipped=entry.stylesSkipped,stylesApplied=entry.stylesApplied,
filters=entry.filters,region=entry.region,view=entry.view,foot=entry.foot,
size=entry.size,hero=entry.hero,unbracketed=entry.unbracketed,
tallyCached=entry.tallyCached,
},"ui")
end
end
local function costTick(_,elapsed)
if not pendingCost then
flushCost()
return
end
costFrames=costFrames+1
if type(elapsed)=="number"then
pendingCost["frame"..costFrames]=millis(elapsed)
end
if costFrames>=3 then
flushCost()
end
end
local function armCost(entry)
if pendingCost then
flushCost()
end
if not A.debugEnabled()then
return
end
if not costFrame and type(CreateFrame)=="function"then
local ok,frame=pcall(CreateFrame,"Frame","WowPvpHistoryCostFrame")
costFrame=ok and frame or nil
end
pendingCost=entry
costFrames=0
local armed=costFrame~=nil and pcall(function()
costFrame:SetScript("OnUpdate",costTick)
costFrame:Show()
end)
if not armed then
flushCost()
end
end
function A.beginSwitch(route,from)
if switching then
return false
end
if pendingCost then
flushCost()
end
switching={
route=route,
from=from,
via=typedDepth>0 and"typed"or"click",
mode=A.repaintMode(),
phases={},
}
A.countStyles(true)
switching.started=preciseNow()
return true
end
function A.endSwitch(to)
local held=switching
if not held then
return false
end
local stopped=preciseNow()
switching=nil
local skipped,applied=A.countStyles(false)
local entry={
route=held.route,from=held.from,to=to,via=held.via,mode=held.mode,
summaryCached=held.summaryCached,tallyCached=held.tallyCached,
windowsSkipped=held.windowsSkipped,stylesSkipped=skipped,stylesApplied=applied,
}
for name,seconds in pairs(held.phases)do
entry[name]=millis(seconds)
end
if held.started and stopped then
entry.total=millis(stopped-held.started)
local top={"choices","page","options","filters","tally","summary","region","list",
"view","foot","windows"}
local remainder=stopped-held.started
for i=1,#top do
remainder=remainder-(held.phases[top[i]]or 0)
end
entry.unbracketed=millis(remainder)
end
armCost(entry)
return true
end
function A.timedSwitch(route,from,run,landed)
local began=A.beginSwitch(route,from)
local ok,result=pcall(run)
if began then
A.endSwitch(landed and landed()or nil)
end
if not ok then
error(result,0)
end
return result
end
local function typedReleased(ok,...)
typedDepth=typedDepth-1
if not ok then
error((...),0)
end
return...
end
function A.withTypedSwitch(run)
typedDepth=typedDepth+1
return typedReleased(pcall(run))
end
local function throughSlot(name,walker,format,season,character,bound,compute)
local started=A.switchClock()
local key,values
if leanSwitch()then
local db=A.db()
key=table.concat({tostring(format),tostring(season),tostring(character),tostring(bound),
tostring(db and#db.matches),tostring(db and db.nextMatchId),
tostring(db and type(db.incomplete)=="table"and#db.incomplete or nil)},"\1")
local held=slots[name]
if held and held.key==key then
switching[name.."Cached"]="hit"
values=held.values
if type(A.paintMemoSeed)=="function"then
A.paintMemoSeed(walker,values,format,season,character,bound)
end
end
end
if values==nil then
values=compute()
if key then
switching[name.."Cached"]="miss"
slots[name]={key=key,values=values}
end
end
A.switchPhase(name,started)
return values
end
local function forgetMatchWindow(frame)
local key=frame.recordKey
if key and matchWindows[key]==frame then
matchWindows[key]=nil
for i=#matchOrder,1,-1 do
if matchOrder[i]==key then
table.remove(matchOrder,i)
end
end
end
frame.recordKey=nil
frame.record=nil
frame.editing=nil
if type(A.forgetViewport)=="function"and frame.viewportName then
pcall(A.forgetViewport,frame.viewportName)
end
if window and window:IsShown()and repaintEverything then
pcall(repaintEverything)
end
end
local function buildMatchWindow(index)
local name=FRAME_NAME.."Match"..index
local frame=CreateFrame("Frame",name,UIParent,"BasicFrameTemplateWithInset")
frame:SetSize(A.detailWindowWidth(),A.detailWindowHeight())
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
frame.heading:SetPoint("TOPLEFT",frame,"TOPLEFT",A.metric("titleInset"),
-A.metric("titleTop"))
frame.heading:SetPoint("TOPRIGHT",frame,"TOPRIGHT",-A.metric("titleInset"),
-A.metric("titleTop"))
frame.heading:SetJustifyH("CENTER")
frame.heading:SetWordWrap(false)
A.style(frame.heading,"heading","bright")
frame.detailHost=CreateFrame("Frame",nil,frame)
frame.detailHost:SetPoint("TOPLEFT",frame,"TOPLEFT",A.metric("margin"),
-A.metric("headerHeight"))
frame.detailHost:SetPoint("BOTTOMRIGHT",frame,"BOTTOMRIGHT",
-A.metric("margin")-A.metric("paneRightPad"),A.metric("margin"))
frame.detailHost:Show()
buildEditStrip(frame)
frame.editRow:Show()
frame.detail=A.buildScroller(name.."Detail",frame.detailHost,"Button",initLine,
lineExtent,"the match detail")
if not frame.detail then
return nil
end
frame.detail.box:SetPoint("TOPLEFT",frame.detailHost,"TOPLEFT",0,0)
frame.detail.box:SetPoint("TOPRIGHT",frame.detailHost,"TOPRIGHT",0,0)
frame.detail.box:SetPoint("BOTTOMLEFT",frame.editRow,"TOPLEFT",0,A.metric("paneEditGap"))
frame.detail.box:SetPoint("BOTTOMRIGHT",frame.editRow,"TOPRIGHT",0,A.metric("paneEditGap"))
frame.detail.bar:SetPoint("TOPLEFT",frame.detailHost,"TOPRIGHT",4,0)
frame.detail.bar:SetPoint("BOTTOMLEFT",frame.editRow,"TOPRIGHT",4,4)
frame.viewportName=("the match detail %d"):format(index)
frame.windowName=name
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
forgetMatchWindow(self)
end)
if type(A.attachPooledResize)=="function"then
pcall(A.attachPooledResize,frame,"match",{
release=function(self,before)
local after=A.frameGeometry(self)
if not(after and before)then
return A.storedGeometry("match")~=nil
end
if math.abs(after.width-before.width)>1 then
self.wantWidth,self.wantFrom=after.width,"drag"
end
if math.abs(after.height-before.height)>1 then
self.ceiling,self.ceilingFrom=after.height,"drag"
end
local width=A.detailWindowWidth()
if type(self.wantWidth)=="number"and self.wantWidth>(self.recordWidth or width)+1 then
width=self.wantWidth
end
A.setStoredGeometry("match",{width=width,height=self.ceiling or A.detailWindowHeight()})
return A.storedGeometry("match")~=nil
end,
repaint=function(self)
if self.recordKey then
pcall(paintMatchWindow,self)
end
end,
})
end
return frame
end
local function freeMatchFrame()
for i=1,#matchPool do
if not matchPool[i].recordKey then
return matchPool[i]
end
end
local built=buildMatchWindow(#matchPool+1)
if not built then
return nil
end
matchPool[#matchPool+1]=built
return built
end
local function nextCascadeStep(frame)
local highest=-1
for i=1,#matchOrder do
local open=matchWindows[matchOrder[i]]
if open and open~=frame and type(open.cascadeStep)=="number"
and open.cascadeStep>highest then
highest=open.cascadeStep
end
end
return highest+1
end
local function placeMatchWindow(frame,step)
frame.cascadeStep=type(step)=="number"and step or nextCascadeStep(frame)
frame.undocked=nil
pcall(frame.ClearAllPoints,frame)
local listUp=false
if window then
local ok,shown=pcall(window.IsShown,window)
listUp=ok and shown==true
end
if not listUp then
pcall(frame.SetPoint,frame,"CENTER")
return false
end
local cascade=A.metric("detailCascade")*frame.cascadeStep
pcall(frame.SetPoint,frame,"TOPLEFT",window,"TOPRIGHT",
A.metric("detailGap")+cascade,-cascade)
pcall(frame.SetUserPlaced,frame,false)
return true
end
function A.recascadeMatchWindows()
local moved={}
for i=1,#matchOrder do
local key=matchOrder[i]
local frame=matchWindows[key]
if frame then
placeMatchWindow(frame,#moved)
moved[#moved+1]={key=key,frame=frame,
kind=frame.recordKind,id=frame.recordId}
end
end
return moved
end
local function openMatchWindow(kind,id,source)
if id==nil then
return nil,"refused"
end
kind=(kind=="incomplete")and"incomplete"or"match"
local key=matchKey(kind,id)
local open=matchWindows[key]
if open then
pcall(open.Hide,open)
traceMatchWindow("closed",kind,id,source)
return nil,"closed"
end
local frame=freeMatchFrame()
if not frame then
traceMatchWindow("refused",kind,id,source)
return nil,"refused"
end
frame.recordKey=key
frame.recordKind=kind
frame.recordId=id
matchWindows[key]=frame
matchOrder[#matchOrder+1]=key
local held=type(A.pooledOpenSize)=="function"and A.pooledOpenSize("match")or nil
frame.wantWidth=held and held.width or nil
frame.ceiling=held and held.height or nil
frame.wantFrom=held and"stored"or nil
frame.ceilingFrom=held and"stored"or nil
frame.sizeFrom,frame.widthFrom=nil,nil
pcall(frame.Show,frame)
placeMatchWindow(frame)
pcall(frame.Raise,frame)
return frame,"opened"
end
function A.showMatchWindow(kind,id,source)
local frame,outcome=openMatchWindow(kind,id,source)
if outcome=="opened"and frame then
A.refreshWindow()
traceMatchWindow("opened",frame.recordKind,frame.recordId,source,frame)
end
return frame,outcome
end
function A.raiseMatchWindow(kind,id,source)
if id==nil then
return nil,"refused"
end
kind=(kind=="incomplete")and"incomplete"or"match"
local open=matchWindows[matchKey(kind,id)]
if open then
pcall(open.Show,open)
pcall(open.Raise,open)
traceMatchWindow("raised",kind,id,source)
return open,"raised"
end
return A.showMatchWindow(kind,id,source)
end
matchWindowOpenOn=function(kind,id)
if id==nil then
return false
end
return matchWindows[matchKey(kind,id)]~=nil
end
function A.clickParticipant(guid,owner,mods,source)
if guid==nil or type(A.togglePlayer)~="function"then
return"refused"
end
if type(mods)=="table"and(mods.shift==true or mods.ctrl==true or mods.alt==true)then
return A.searchAddParticipant(guid,owner,mods,source)
end
local _,outcome=A.togglePlayer(guid,"match",owner)
return outcome or"refused"
end
function A.hoverMatchRound(round)
if round==nil then
A.hideTooltip()
return"hidden"
end
local open=A.matchWindowsOpen()
local newest=open[#open]
local box=newest and newest.frame and newest.frame.detail and newest.frame.detail.box or nil
if not box then
return nil,"no-window"
end
if type(box.ForEachFrame)~="function"then
return nil,"not-drawn"
end
local target,kind=nil,nil
pcall(box.ForEachFrame,box,function(element)
if target~=nil or type(element)~="table"then
return
end
for _,pair in ipairs({{element.lobbyRoundHovers,"hover"},{element.lobbyRoundButtons,"button"}})do
local held=type(pair[1])=="table"and pair[1][round]or nil
local okShown,shown=pcall(function()
return held~=nil and held:IsShown()
end)
if target==nil and okShown and shown then
target,kind=held,pair[2]
end
end
end)
if target==nil then
return nil,"not-drawn"
end
local enter=target:GetScript("OnEnter")
if type(enter)~="function"then
return nil,"not-drawn"
end
enter(target)
return"shown",kind
end
function A.matchWindowsOpen()
local out={}
for i=1,#matchOrder do
local key=matchOrder[i]
local frame=matchWindows[key]
if frame then
out[#out+1]={kind=frame.recordKind,id=frame.recordId,
name=frame.windowName,frame=frame,
step=frame.cascadeStep,docked=frame.undocked~=true}
end
end
return out
end
function A.closeMatchWindows()
local held=A.matchWindowsOpen()
for i=#held,1,-1 do
pcall(held[i].frame.Hide,held[i].frame)
end
return#held
end
if type(A.registerWindowKind)=="function"then
A.registerWindowKind("match",{
label="match window",
authored=function()
return A.detailWindowWidth(),A.detailWindowHeight()
end,
floor=function()
return A.detailWindowWidth(),A.detailWindowFloor()
end,
pooled=true,
newest=function()
local open=A.matchWindowsOpen()
return open[#open]and open[#open].frame or nil
end,
sized=function(frame,geometry)
frame.wantWidth,frame.wantFrom=geometry.width,"typed"
frame.ceiling,frame.ceilingFrom=geometry.height,"typed"
paintMatchWindow(frame)
end,
})
end
local MATCH_REGIONS={"filterRow","summary","viewRow","listHost","compHost","askHost",
"askPaneHost","askMatchBand","duelPanel"}
local function paintPage()
local page=(activeBody=="settings"or activeBody=="about")and activeBody or nil
if activeBody~="stats"and type(A.hideStatsOverview)=="function"then
A.hideStatsOverview(window)
end
for body,host in pairs(window.pageHosts or{})do
pcall(host.SetShown,host,body==page)
end
if not page then
pcall(window.filterRow.Show,window.filterRow)
return false
end
for i=1,#MATCH_REGIONS do
local region=window[MATCH_REGIONS[i]]
if region then
pcall(region.Hide,region)
end
end
if type(A.setHalfTabsChosen)=="function"then
A.setHalfTabsChosen(window.halfTabs,page)
end
if type(A.notePlacedRow)=="function"then
pcall(A.notePlacedRow,"view row",{})
end
if type(A.paintPageBody)=="function"then
pcall(A.paintPageBody,page,A.windowWidth(),frameHeightOf(window))
end
pcall(function()
local tagline,credit=A.windowFootLine()
window.footName:SetText(tagline)
window.footState:SetText(credit)
if window.footRule then
window.footRule:SetColorTexture(A.color("hairline"))
end
end)
return true
end
local function refreshWindowPinned()
if not window then
return false
end
local onPage=activeBody=="settings"or activeBody=="about"
if window.character and type(A.characterChoices)=="function"
and not(onPage and A.repaintMode()=="lean"and window.characterFilled)then
local started=A.switchClock()
local filled=pcall(function()
A.setDropdownChoices(window.character,A.characterChoices(),A.windowCharacter())
end)
window.characterFilled=window.characterFilled or filled
A.switchPhase("choices",started)
end
local pageStarted=A.switchClock()
if paintPage()then
A.switchPhase("page",pageStarted)
return true
end
local filtersStarted=A.switchClock()
pcall(layoutFilters)
A.switchPhase("filters",filtersStarted)
local compTally,compSkipped,compConsidered,compRanked={},0,0,0
pcall(function()
local _,season,bound=A.windowScope()
local walked=throughSlot("tally","compTally",activeFormat,season,A.windowCharacter(),bound,
function()
return{resolveComps()}
end)
compTally,compSkipped,compConsidered,compRanked=walked[1],walked[2],walked[4],walked[6]
end)
local regionStarted
darkList.hero,darkList.duelClasses=nil,nil
filterBand.strip=nil
local painted,painting=pcall(function()
if window.summary and type(A.summarize)=="function"then
local scope,season,bound=A.windowScope()
local summary=throughSlot("summary","summarize",activeFormat,season,A.windowCharacter(),
bound,function()
return{A.paintWalk("summarize",activeFormat,season,A.windowCharacter(),bound)}
end)[1]
regionStarted=A.switchClock()
local notRated
if type(A.readingContext)=="function"then
notRated=A.readingContext(activeFormat,season,A.windowCharacter(),bound)
end
local standingReading=nil
local worldStats=activeBody=="stats"and activeFormat=="world"
if(activeBody~="stats"or worldStats)and type(A.standingReading)=="function"then
local heroStarted=A.switchClock()
local listed=nil
if activeFormat=="world"and not worldStats then
local okListed,records=pcall(filterBand.worldRecords,season,bound)
listed=okListed and records or nil
end
local okStanding,held=pcall(A.standingReading,activeFormat,season,A.windowCharacter(),
bound,summary,(type(A.scopeNow)=="function"and A.scopeNow())or time(),listed)
A.switchPhase("hero",heroStarted)
standingReading=okStanding and held or nil
if listed~=nil and standingReading~=nil then
filterBand.strip={format=activeFormat,character=A.windowCharacter(),
scope=A.summaryScope(),mark=type(A.storeMark)=="function"and A.storeMark()or nil,
summary=summary,reading=standingReading}
end
if not okStanding then
A.trace("strip",{format=activeFormat,reason="threw"},"ui")
end
end
local hero=standingReading and standingReading.hero or nil
darkList.hero=hero
darkList.duelClasses=hero and hero.classes or nil
A.paintSummaryRegion(window.summary,summary,scope,
{notRated=notRated,collapsed=A.readingCollapsed(),
standing=standingReading,
frameHeight=frameHeightOf(window),
season=season,bound=bound,
graphFolded=A.graphFolded(),
stripOnly=activeBody~="stats"})
end
end)
A.switchPhase("region",regionStarted)
if not painted and type(A.noteError)=="function"then
A.noteError(("the summary region did not repaint: %s")
:format(painting~=nil and tostring(painting)or"the client gave no message"),
"summary-region")
end
local listStarted=A.switchClock()
local rows,_,total,_,leftCount,emptyWhy,
scopedMatches,listColumns=listRows()
lastRows=total
pcall(applyPaneLayout,window,listColumns,#rows)
A.setRows(window.list,rows)
pcall(function()
local panelRows=A.paintDuelPanel(window.duelPanel,darkList.hero,A.duelPanelShown())
if activeBody=="history"and(activeFormat=="duel"or activeFormat=="unknown")then
local drawn=0
for i=1,#rows do
if not rows[i].separator then
drawn=drawn+1
end
end
A.traceHeroTab(activeFormat,darkList.hero,drawn,panelRows)
end
end)
local listScrolls=type(window.listRoom)=="number"and activeBody~="stats"
and A.rowEdges(rows,0,window.listRoom,A.metric("rowHeight")).range>0
local expanded=false
for i=1,#rows do
if rows[i].expansion and rows[i].expansion~=""then
expanded=true
break
end
end
if(listScrolls or expanded)and not listSnapQueued and type(C_Timer)=="table"
and type(C_Timer.After)=="function"then
listSnapQueued=true
C_Timer.After(0,function()
listSnapQueued=false
if window and window.list then
pcall(A.checkListExpansion)
pcall(A.snapWholeRows,window.list)
end
end)
end
A.switchPhase("list",listStarted)
local viewStarted=A.switchClock()
A.clearSpecDraws()
pcall(paintViewChoice,compTally,compSkipped,compConsidered,
listColumns,#rows,compRanked)
if activeBody=="stats"then
local icons,squares=A.specDrawCounts()
local shown=A.tableViewShowing()or(A.specsShowing()and"specs")
or(A.askAcross()and"overview")or(window.tableShowing=="comp"and"comp")or"cards"
A.trace("specdraw",{icons=icons,squares=squares,statsView=shown},"ui")
end
A.switchPhase("view",viewStarted)
pcall(darkList.traceSessions,window)
local footStarted=A.switchClock()
if activeBody=="stats"and type(A.noteViewRow)=="function"and window.summary then
pcall(A.noteViewRow,window.summary)
elseif type(A.notePlacedRow)=="function"then
pcall(A.notePlacedRow,"view row",{})
end
pcall(function()
local tagline,credit=A.windowFootLine()
window.footName:SetText(tagline)
window.footState:SetText(credit)
if window.footRule then
window.footRule:SetColorTexture(A.color("hairline"))
end
paintListFoot(activeBody~="stats",rows,total,leftCount,scopedMatches,emptyWhy)
paintSearchCount(window)
end)
A.switchPhase("foot",footStarted)
return true
end
function A.refreshWindow()
return A.withWindowWidth(window,function()
return A.withScopeClock(function()
local painted=false
if window==nil or window.opening or window:IsShown()then
painted=A.withPaintScope(refreshWindowPinned)
end
if leanSwitch()then
switching.windowsSkipped=openMatchWindowCount()
else
local started=A.switchClock()
pcall(paintMatchWindows)
A.switchPhase("windows",started)
if switching then
switching.windowsSkipped=0
end
end
if not switching then
slots.summary=nil
slots.tally=nil
end
return painted
end)
end)
end
repaintEverything=A.refreshWindow
A.on("PVP_RATED_STATS_UPDATE",function()
if not A.ratingTakeWaiting()then
return
end
local shown=window~=nil and window:IsShown()
if shown or openMatchWindowCount()>0 then
local ok,err=pcall(A.refreshWindow)
if not ok then
A.noteError(err,"rated-repaint")
end
end
end)
local tabResolved
local function applyStoredTab()
if tabResolved then
return
end
tabResolved=true
activeFormat=A.storedTab()
A.holdScope(false)
if not characterResolved then
characterResolved=true
activeCharacter=A.storedCharacter()
end
end
function A.showIncompleteTab()
if not windowOrNil()then
return false
end
activeFormat="unknown"
A.holdScope(false)
pcall(A.setStoredTab,activeFormat)
tabResolved=true
return A.showWindow()
end
function A.resetActiveTab()
activeFormat=nil
tabResolved=false
A.holdScope(false)
return true
end
function A.showWindow()
local frame=windowOrNil()
if not frame then
return false
end
pcall(applyStoredTab)
frame.opening=true
local painted,err=pcall(A.refreshWindow)
frame.opening=nil
if not painted then
error(err,0)
end
A.takeHalf("matches")
local shown=pcall(frame.Show,frame)
pcall(frame.Raise,frame)
A.trace("open",{source="matches",n=lastRows,format=activeFormat,cols=lastColumns},"ui")
return shown
end
local function setBody(body)
if BODY_WORDS[body]==nil then
return activeBody
end
if body~=activeBody then
A.trace("body",{source=activeBody,state=body,
card=body=="stats"and A.askShowing()or nil},"ui")
activeBody=body
end
return activeBody
end
function A.showWindowBody(body)
return A.timedSwitch("body",activeBody,function()
setBody(body)
return A.showWindow()
end,function()
return activeBody
end)
end
function A.hideWindow()
if not window then
return false
end
return(pcall(window.Hide,window))
end
function A.toggleWindow()
if window then
local ok,shown=pcall(window.IsShown,window)
if ok and shown then
return A.hideWindow()
end
end
return A.showWindow()
end
function A.selectMatch(id)
return A.selectEntry("match",id)
end
function A.showMatchFromPlayers(id)
if id==nil then
return false
end
local record=A.match(id)
if not record then
return false
end
if record.format~=nil then
local onRow=false
for _,tab in ipairs(A.tabList(A.windowCharacter()))do
if tab.format==record.format then
onRow=true
break
end
end
if onRow then
tabResolved=true
activeFormat=record.format
A.holdScope(false)
A.setStoredTab(record.format)
end
end
return A.selectEntry("match",id)
end
local function applyWindowState(want)
want=type(want)=="table"and want or{}
if not windowOrNil()then
return nil
end
pcall(applyStoredTab)
if want.format~=nil then
activeFormat=want.format or nil
A.holdScope(false)
end
if want.body~=nil then
setBody(want.body)
end
local card=want.card
if card==nil and want.view~=nil then
card=VIEW_CARDS[want.view]
end
if want.view~=nil or card~=nil then
setBody("stats")
end
if card~=nil and A.askQuestion(card)~=nil then
activeAsk=card
end
if(want.view~=nil or want.card~=nil)and type(A.setSpecsView)=="function"then
A.setSpecsView(want.view=="specs")
if type(A.setMapsView)=="function"then
A.setMapsView(want.view=="maps")
end
if type(A.setTableView)=="function"then
A.setTableView(want.view)
end
end
if want.scope~=nil and A.isScopeWord(want.scope)then
typedScope=want.scope
A.holdScope(true)
end
A.showWindow()
local scope=A.windowScope()
return{format=activeFormat,body=activeBody,card=A.askShowing(),scope=scope,
stored=A.summaryScope(),table=window and window.tableShowing or nil}
end
function A.paintedScope()
return window and window.summary and window.summary.paintedScope or nil
end
function A.showWindowState(want)
want=type(want)=="table"and want or{}
if want.body==nil and want.view==nil and want.card==nil then
return applyWindowState(want)
end
local asCard=(want.view~=nil or want.card~=nil)and activeBody=="stats"
and(want.body==nil or want.body=="stats")
local function landed()
if asCard then
return A.askShowing()
end
return activeBody
end
return A.withTypedSwitch(function()
return A.timedSwitch(asCard and"view"or"body",landed(),function()
return applyWindowState(want)
end,landed)
end)
end
function A.selectEntry(kind,id)
if id==nil then
return false
end
selectedKind=(kind=="incomplete")and"incomplete"or"match"
selectedId=id
if not windowOrNil()then
return false
end
pcall(applyStoredTab)
local _,opened,outcome=pcall(openMatchWindow,selectedKind,id,"select")
window.opening=true
local painted,err=pcall(A.refreshWindow)
window.opening=nil
if outcome=="opened"and type(opened)=="table"then
traceMatchWindow("opened",opened.recordKind,opened.recordId,"select",opened)
end
if not painted then
error(err,0)
end
local shown=pcall(window.Show,window)
pcall(window.Raise,window)
return shown
end
function WowPvpHistory_Toggle()
A.toggleWindow()
end
function WowPvpHistory_OnAddonCompartmentClick(_,_)
A.toggleWindow()
end
function WowPvpHistory_OnAddonCompartmentEnter(_,button)
if not(button and GameTooltip)then
return
end
pcall(function()
GameTooltip:SetOwner(button,"ANCHOR_LEFT")
GameTooltip:SetText("PvP History",1,0.82,0,1,true)
GameTooltip:AddLine("Click to open the match history.",1,1,1)
GameTooltip:Show()
end)
end
function WowPvpHistory_OnAddonCompartmentLeave(_,button)
A.hideOwnedTooltip(button)
end
BINDING_HEADER_WOWPVPHISTORY="PvP History"
BINDING_NAME_WOWPVPHISTORY_TOGGLE="Open the match history"
