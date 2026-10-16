-- WowPvpHistory 0.68.35
-- Author:  Xenu-Sentinels
-- Project: wow-pvp-history
--          https://github.com/xenulive/wow-pvp-history
-- License: MIT, see LICENSE
local _,A=...
local TILE_COUNT=6
local OPPONENT_ROWS=4
local READING_ROWS=7
function A.readingRows()
return READING_ROWS
end
function A.statsHeadline(format,summary)
if format=="world"then
return"standing"
end
return type(summary)=="table"and summary.rating~=nil or false
end
function A.summaryHeight(headline)
return A.stripHeight(headline)+A.metric("stripGap")+A.readingReserve()
+A.metric("plotHeight")
end
local PLOT_SHARE=0.25
local lastGrowth=0
function A.summaryGrowth(frameHeight)
if type(frameHeight)~="number"or frameHeight<=0 then
return 0
end
local authored=nil
if type(A.authoredGeometry)=="function"then
local ok,_,height=pcall(A.authoredGeometry,"matches")
if ok and type(height)=="number"then
authored=height
end
end
if authored==nil or frameHeight==authored then
return 0
end
if frameHeight>authored then
return math.floor((frameHeight-authored)*PLOT_SHARE)
end
return-math.floor((authored-frameHeight)*PLOT_SHARE)
end
function A.plotGain(share,reading)
local grow=type(share)=="number"and share or 0
local read=type(reading)=="number"and reading or 0
if read<0 then
read=0
end
local authored=A.readingReserve()+A.metric("plotHeight")-read
if authored<0 then
authored=0
end
local want=authored+grow
local bound=nil
local most=A.plotCeiling()
if grow>0 and want>most then
want=most
if want<authored then
want=authored
end
bound="ceiling"
end
local least=A.plotFloor()
local held="floor"
if least>authored then
least=authored
held="reading"
end
if grow<0 and want<least then
want=least
bound=held
end
return want-authored,bound
end
function A.plotShare()
return PLOT_SHARE
end
function A.lastSummaryGrowth()
return lastGrowth
end
function A.summaryHeightNoPlot(headline,reading,note)
local read=type(reading)=="number"and reading or 0
if read<0 then
read=0
end
local row=note==false and 0 or A.noteRowHeight()
return A.stripHeight(headline)+A.metric("stripGap")+read+row
end
function A.summaryHeightFolded(headline,reading)
local read=type(reading)=="number"and reading or 0
if read<0 then
read=0
end
return A.stripHeight(headline)+A.metric("stripGap")+read+A.plotFoldHeight()
end
function A.summaryHeightFought(rows,note,headline,reading)
local count=type(rows)=="number"and rows or 0
if count<0 then
count=0
end
local read=type(reading)=="number"and reading or 0
if read<0 then
read=0
end
local body=A.noteRowHeight()+A.metric("plotLabelDrop")+count*A.metric("opponentRow")
if note then
body=body+A.noteRowHeight()
end
local plot=A.metric("plotHeight")
local ceiling=plot
local spare=A.readingReserve()+plot-read
if spare<ceiling then
ceiling=spare
end
local floor=A.noteRowHeight()
if ceiling<floor then
ceiling=floor
end
if body>ceiling then
body=ceiling
end
if body<floor then
body=floor
end
return A.stripHeight(headline)+A.metric("stripGap")+read+body
end
function A.plotRoom(headline,reading,grow)
local read=type(reading)=="number"and reading or 0
if read<0 then
read=0
end
local gain=A.plotGain(grow,read)
local room=A.summaryHeight(headline)+gain-A.stripHeight(headline)-A.metric("stripGap")
-read
if room<0 then
room=0
end
return room
end
function A.summaryBands(opts)
opts=type(opts)=="table"and opts or{}
local lines=type(opts.lines)=="number"and opts.lines or 0
local headline=opts.headline
local bands={
{
name="reading region",
heading=A.metric("readingPad")*2,
rowHeight=A.metric("readingRow"),
contents=lines,
folded=opts.collapsed==true,
room=A.readingRoom(headline),
extentFrom="summary region",
contentsFrom="summary region",
},
{
name="details control",
heading=A.metric("segmentHeight"),
rowHeight=A.metric("segmentHeight"),
contents=lines>0 and 1 or 0,
room=A.stripHeight(headline),
extentFrom="summary region",
contentsFrom="summary region",
},
}
if opts.plot then
bands[#bands+1]={
name="plot legend",
heading=A.metric("plotLabelDrop"),
rowHeight=A.metric("plotDotSize"),
contents=type(opts.marks)=="number"and opts.marks or 0,
room=A.plotRoom(headline,opts.reading,opts.grow),
extentFrom="summary region",
contentsFrom="summary region",
}
end
return bands
end
local lastStrip=nil
function A.stripRow(opts)
opts=type(opts)=="table"and opts or{}
local function figure(name,fallback)
local held=opts[name]
return type(held)=="number"and held>=0 and held or fallback
end
local origin=figure("origin",0)
local each=figure("each",A.metric("tileMinWidth"))
local tiles=math.floor(figure("tiles",0))
local gap=A.metric("tileGap")
local blocks={}
if origin>0 then
blocks[#blocks+1]={kind="headline",name="headline",from=0,to=origin}
end
local widths=type(opts.widths)=="table"and opts.widths or nil
local at=origin
for i=1,tiles do
local wide=widths and type(widths[i])=="number"and widths[i]or each
blocks[#blocks+1]={kind="tile",name=("tile %d"):format(i),
from=at,to=at+wide}
at=at+wide+gap
end
if type(opts.where)=="string"and opts.where~=""then
lastStrip={where=opts.where,blocks=blocks}
end
return blocks
end
local VIEW_PILLS={
{"graph","graphToggle","toggle","graph control"},
{"specs","specsToggle","specs","specs control"},
{"maps","mapsToggle","maps","maps control"},
{"builds","buildsToggle","builds","builds control"},
{"bests","bestsToggle","bests","bests control"},
{"details","details","control","details control"},
}
function A.viewRowBlocks(opts)
opts=type(opts)=="table"and opts or{}
local function figure(name)
local held=opts[name]
return type(held)=="number"and held>0 and held or 0
end
local width=A.listHostWidth(false)
local blocks={}
if figure("head")>0 then
blocks[#blocks+1]={kind="head",name="head line",from=0,to=figure("head")}
end
local edge=width
if figure("track")>0 then
blocks[#blocks+1]={kind="track",name="scope track",
from=edge-figure("track"),to=edge}
edge=edge-figure("track")-A.metric("pillGap")
end
for i=#VIEW_PILLS,1,-1 do
local held=figure(VIEW_PILLS[i][3])
if held>0 then
blocks[#blocks+1]={kind="control",name=VIEW_PILLS[i][4],from=edge-held,to=edge}
edge=edge-held-A.metric("pillGap")
end
end
return blocks,A.stripCluster(figure("track"),figure("control"),figure("toggle"),figure("specs"),
figure("maps"),figure("builds"),figure("bests"))
end
function A.lastStripRow()
if type(lastStrip)~="table"then
return nil
end
return lastStrip.blocks,lastStrip.where
end
function A.stripCluster(track,control,toggle,specs,maps,builds,bests)
local widths={}
local function hold(width)
if type(width)=="number"and width>0 then
widths[#widths+1]=width
end
end
hold(track)
hold(control)
hold(toggle)
hold(specs)
hold(maps)
hold(builds)
hold(bests)
if#widths==0 then
return 0
end
local total=0
for i=1,#widths do
total=total+widths[i]
end
return total+(#widths-1)*A.metric("pillGap")+A.metric("tileGap")
end
local function setColor(fontString,name)
fontString:SetTextColor(A.color(name))
end
local function tintRating(fontString,format,rating,fallback)
local _,_,reason,r,g,b=A.ratingColour(format,rating)
if r~=nil then
fontString:SetTextColor(r,g,b)
else
setColor(fontString,fallback)
end
if reason=="unheard"then
A.ratingAsk()
end
end
local function ratingInline(format,rating)
local _,_,reason=A.ratingColour(format,rating)
if reason=="unheard"then
A.ratingAsk()
end
return A.tierRatingText(format,rating)
end
local function percentText(rate)
return A.percentText(rate)
end
local standing={}
standing.TILES=4
standing.FIGURES=3
standing.BESIDE=8
function standing.text(parent,role,tone,justify)
local text=parent:CreateFontString(nil,"ARTWORK","GameFontDisableSmall")
text:SetJustifyH(justify or"LEFT")
text:SetWordWrap(false)
A.style(text,role,tone)
text:Hide()
return text
end
function standing.width(text)
local ok,width=pcall(text.GetStringWidth,text)
if ok and type(width)=="number"and width>0 then
return width
end
return nil
end
function standing.build(region)
local strip=CreateFrame("Frame",nil,region)
strip:SetPoint("TOPLEFT",region,"TOPLEFT",0,0)
strip:SetPoint("TOPRIGHT",region,"TOPRIGHT",0,0)
strip:SetHeight(A.metric("standingStrip"))
strip:Hide()
strip.ground=strip:CreateTexture(nil,"BACKGROUND")
strip.ground:SetAllPoints(strip)
strip.rating=standing.text(strip,"numberHuge","bright")
strip.change=standing.text(strip,"numberSmall","dim")
strip.rule=strip:CreateTexture(nil,"ARTWORK")
strip.rule:Hide()
strip.bars={}
strip.days={}
for i=1,A.standingTrendCount()do
local bar=strip:CreateTexture(nil,"ARTWORK")
bar:Hide()
strip.bars[i]=bar
strip.days[i]=standing.text(strip,"rowClock","dimmer","CENTER")
end
strip.figures={}
for i=1,standing.FIGURES do
strip.figures[i]={
label=standing.text(strip,"label","label"),
value=standing.text(strip,"number","bright"),
sub=standing.text(strip,"note","dim"),
}
end
strip.tiles={}
for i=1,standing.TILES do
strip.tiles[i]={
label=standing.text(strip,"stripLabel","label"),
rating=standing.text(strip,"stripFigure","bright"),
change=standing.text(strip,"stripChange","dim"),
tier=standing.text(strip,"stripTier","dim"),
high=standing.text(strip,"stripTier","dim"),
highValue=standing.text(strip,"stripTier","dim"),
}
end
strip.rate={
label=standing.text(strip,"stripLabel","label"),
value=standing.text(strip,"stripFigure","bright"),
sub=standing.text(strip,"stripTier","dim"),
}
strip.stats={}
for i=1,2 do
strip.stats[i]={
label=standing.text(strip,"stripLabel","label"),
value=standing.text(strip,"stripFigure","bright"),
sub=standing.text(strip,"stripTier","dim"),
}
end
strip.rules={}
for i=1,standing.TILES+1 do
local rule=strip:CreateTexture(nil,"ARTWORK")
rule:Hide()
strip.rules[i]=rule
end
strip.edge=strip:CreateTexture(nil,"BORDER")
strip.edge:SetPoint("BOTTOMLEFT",strip,"BOTTOMLEFT",0,0)
strip.edge:SetPoint("BOTTOMRIGHT",strip,"BOTTOMRIGHT",0,0)
strip.edge:SetHeight(1)
strip.edge:Hide()
standing.buildHero(strip)
return strip
end
function standing.hideAll(strip)
for _,key in ipairs({"rating","change","rule","edge"})do
strip[key]:Hide()
end
for i=1,#strip.rules do
strip.rules[i]:Hide()
end
strip.rate.label:Hide()
strip.rate.value:Hide()
strip.rate.sub:Hide()
for i=1,#strip.stats do
strip.stats[i].label:Hide()
strip.stats[i].value:Hide()
strip.stats[i].sub:Hide()
end
for i=1,#strip.bars do
strip.bars[i]:Hide()
strip.days[i]:Hide()
end
for i=1,#strip.figures do
strip.figures[i].label:Hide()
strip.figures[i].value:Hide()
strip.figures[i].sub:Hide()
end
for i=1,#strip.tiles do
local tile=strip.tiles[i]
tile.label:Hide()
tile.rating:Hide()
tile.tier:Hide()
tile.change:Hide()
tile.high:Hide()
tile.highValue:Hide()
end
for _,region in ipairs(strip.hero and strip.hero.all or{})do
region:Hide()
end
end
function standing.place(strip,text,value,x,y,width)
if value==nil or value==""then
text:Hide()
return
end
text:ClearAllPoints()
text:SetPoint("TOPLEFT",strip,"TOPLEFT",x,y)
if width~=nil then
text:SetWidth(width)
end
text:SetText(value)
text:Show()
end
function standing.figuresAt(strip,figures,width)
local each=A.metric("standingFigure")
local count=math.min(#(figures or{}),#strip.figures)
local left=width-each*count
for i=1,count do
local figure=figures[i]
local held=strip.figures[i]
local x=left+(i-1)*each
standing.place(strip,held.label,figure.label,x,-4,each)
local value=figure.value or"-"
figure.fit=nil
if type(figure.forms)=="table"and#figure.forms>0 then
local fitted,_,measured=A.fittedForm(held.value,each,figure.forms)
value=fitted or figure.forms[#figure.forms]
figure.fit=fitted~=nil or not measured
end
figure.drawn=value
standing.place(strip,held.value,value,x,-4-A.fontSize("label")-3,each)
setColor(held.value,figure.tone or"bright")
standing.place(strip,held.sub,figure.sub,x,
-4-A.fontSize("label")-3-A.fontSize("number")-3,each)
end
return left
end
function standing.trend(strip,bars,from,to)
local height=A.metric("standingStrip")
local mid=math.floor(height*0.5)
local inset=A.metric("standingTrendInset")
local reach=math.min(mid-inset,height-inset-(mid+1))
local widest,gap=A.metric("standingBar"),A.metric("standingBarGap")
local scale=0
for i=1,#bars do
if type(bars[i].change)=="number"and math.abs(bars[i].change)>scale then
scale=math.abs(bars[i].change)
end
end
local count=math.min(#bars,#strip.bars)
local frame=to-from
if count<2 or scale==0 or frame<2+gap then
return 0,nil,nil
end
local bar=math.max(1,math.min(widest,math.floor((frame-gap*(count-1))/count)))
local pitch=(frame-bar)/(count-1)
strip.rule:ClearAllPoints()
strip.rule:SetPoint("TOPLEFT",strip,"TOPLEFT",from,-mid)
strip.rule:SetSize(frame,1)
strip.rule:SetColorTexture(A.color("hairline"))
strip.rule:Show()
local drawn,nearest=0,nil
for i=1,count do
local held=bars[i]
local x=from+math.floor((i-1)*pitch+0.5)
if type(held.change)=="number"and held.change~=0 then
local tall=math.max(1,math.floor(reach*math.abs(held.change)/scale+0.5))
local top=held.change>0 and(mid-tall)or(mid+1)
local texture=strip.bars[i]
texture:ClearAllPoints()
texture:SetPoint("TOPLEFT",strip,"TOPLEFT",x,-top)
texture:SetSize(bar,tall)
local r,g,b=A.color(held.change>0 and"win"or"loss")
texture:SetColorTexture(r,g,b,held.newest and 1 or 0.4)
texture:Show()
drawn=drawn+1
local away=math.min(top,height-(top+tall))
if nearest==nil or away<nearest then
nearest=away
end
end
end
return drawn,nearest,drawn>0 and bar or nil
end
function standing.blocks(strip,bars,from,to)
local count=math.min(#bars,#strip.bars)
if count==0 or to-from<count then
return 0
end
local gap=A.metric("standingBarGap")
local each=math.floor((to-from-gap*(count-1))/count)
each=math.max(1,math.min(each,A.metric("rowChip")))
local top=8
local tall=A.metric("standingStrip")-top-A.fontSize("micro")-10
local lastDay=nil
local labels={}
for i=1,count do
local held=bars[i]
local x=from+(i-1)*(each+gap)
local texture=strip.bars[i]
texture:ClearAllPoints()
texture:SetPoint("TOPLEFT",strip,"TOPLEFT",x,-top)
texture:SetSize(each,tall)
local r,g,b=A.color(held.tone or"faint")
texture:SetColorTexture(r,g,b,held.newest and 1 or 0.55)
texture:Show()
if held.day~=nil and held.day~=lastDay then
labels[#labels+1]={at=i,x=x,text=A.shortDayText(held.day)}
end
lastDay=held.day
end
local fits=#labels>0
for n,label in ipairs(labels)do
local room=(labels[n+1]and labels[n+1].x or to)-label.x
label.room=room
A.style(strip.days[label.at],"rowClock","dimmer")
if label.text==nil or A.textRoom(strip.days[label.at],label.text)>room then
fits=false
end
end
if fits then
for _,label in ipairs(labels)do
strip.days[label.at]:SetJustifyH("LEFT")
standing.place(strip,strip.days[label.at],label.text,label.x,-(top+tall+2),label.room)
end
end
strip.dayLabels=fits and#labels or 0
return count
end
function standing.lineHeight(text,role)
local ok,height=pcall(text.GetStringHeight,text)
if ok and type(height)=="number"and height>0 then
return height
end
return A.fontSize(role)
end
function standing.fill(held,cell)
local beside=standing.BESIDE
local m={label=0,figure=0,change=0,tier=0,high=0,highValue=0}
local figure=cell.figure or"-"
held.label:SetText(cell.label or"")
setColor(held.label,cell.unranked and"dimmer"or"label")
m.label=A.textRoom(held.label,cell.label)
held.rating:SetText(figure)
if cell.unranked then
setColor(held.rating,"dim")
elseif cell.format~=nil then
tintRating(held.rating,cell.format,cell.rating,"bright")
else
setColor(held.rating,cell.figureTone or"bright")
end
m.figure=A.textRoom(held.rating,figure)
if held.change~=nil and cell.change~=nil and cell.change~=""then
held.change:SetText(cell.change)
setColor(held.change,cell.changeTone or"dim")
m.change=A.textRoom(held.change,cell.change)
end
if cell.tier~=nil and cell.tier~=""then
held.tier:SetText(cell.tier)
if cell.unranked then
setColor(held.tier,"dimmer")
elseif cell.format~=nil then
tintRating(held.tier,cell.format,cell.rating,"dim")
else
setColor(held.tier,cell.subTone or"dim")
end
m.tier=A.textRoom(held.tier,cell.tier)
end
if held.high~=nil and cell.high~=nil then
local value=tostring(cell.high)
held.high:SetText("high")
setColor(held.high,cell.unranked and"dimmer"or"dim")
held.highValue:SetText(value)
tintRating(held.highValue,cell.format,cell.high,"dim")
m.high=A.textRoom(held.high,"high")
m.highValue=A.textRoom(held.highValue,value)
end
local tierLine=m.tier
if m.high>0 then
tierLine=(m.tier>0 and m.tier+beside or 0)+m.high+4+m.highValue
end
local figureLine=m.figure+(m.change>0 and beside+m.change or 0)
m.natural=math.ceil(math.max(m.label,figureLine,tierLine)+A.metric("standingPad")*2)
m.labelHeight=standing.lineHeight(held.label,"stripLabel")
m.figureHeight=standing.lineHeight(held.rating,"stripFigure")
m.changeHeight=m.change>0 and standing.lineHeight(held.change,"stripChange")or 0
m.tierHeight=0
if m.tier>0 then
m.tierHeight=standing.lineHeight(held.tier,"stripTier")
elseif m.high>0 then
m.tierHeight=standing.lineHeight(held.high,"stripTier")
end
return m
end
function standing.placeCell(strip,held,cell,m,x,width)
local pad,gap,beside=A.metric("standingPad"),A.metric("standingLineGap"),standing.BESIDE
local height=A.metric("standingStrip")
local block=m.labelHeight+gap+m.figureHeight+(m.tierHeight>0 and gap+m.tierHeight or 0)
local top=math.floor((height-block)/2+0.5)
local left,room=x+pad,math.max(1,width-pad*2)
standing.place(strip,held.label,cell.label,left,-top,room)
local figureTop=top+m.labelHeight+gap
standing.place(strip,held.rating,cell.figure or"-",left,-figureTop,room)
if m.change>0 then
local at=math.min(m.figure,room)+beside
if room-at>=1 then
standing.place(strip,held.change,cell.change,left+at,-(figureTop+m.figureHeight-m.changeHeight),
room-at)
end
end
local tierTop=figureTop+m.figureHeight+gap
local at=0
if m.tier>0 then
standing.place(strip,held.tier,cell.tier,left,-tierTop,room)
at=math.min(m.tier,room)+beside
end
if m.high>0 and room-at>=1 then
standing.place(strip,held.high,"high",left+at,-tierTop,room-at)
at=at+m.high+4
if room-at>=1 then
standing.place(strip,held.highValue,tostring(cell.high),left+at,-tierTop,room-at)
end
end
return(top+block/2)-height/2
end
function standing.ruleAt(strip,index,x)
local rule=strip.rules[index]
rule:ClearAllPoints()
rule:SetPoint("TOPLEFT",strip,"TOPLEFT",x,0)
rule:SetSize(1,A.metric("standingStrip")-1)
rule:SetColorTexture(A.color("insetEdge"))
rule:Show()
end
function standing.fit(cells,naturals,room)
local floor=A.metric("standingCellFloor")
local kept,dropped={},{}
for i=1,#cells do
kept[i]=true
end
local function widthAt(i,shrink)
return math.max(math.min(naturals[i],floor),naturals[i]-shrink)
end
local function total(shrink)
local sum,count=0,0
for i=1,#cells do
if kept[i]then
sum=sum+widthAt(i,shrink)
count=count+1
end
end
return sum+math.max(0,count-1),count
end
local function nextDrop()
local pick=nil
for i=1,#cells do
if kept[i]and cells[i].unranked and(pick==nil or(cells[i].rating or 0)<=(cells[pick].rating or 0))then
pick=i
end
end
if pick~=nil then
return pick
end
for i=#cells,1,-1 do
if kept[i]then
return i
end
end
return nil
end
while true do
local most=0
for i=1,#cells do
if kept[i]and naturals[i]>most then
most=naturals[i]
end
end
local least,count=total(most)
if count==0 then
return{},dropped
end
if least<=room then
local lo,hi=0,most
while lo<hi do
local mid=math.floor((lo+hi)/2)
if total(mid)<=room then
hi=mid
else
lo=mid+1
end
end
local widths={}
for i=1,#cells do
if kept[i]then
widths[i]=widthAt(i,lo)
end
end
return widths,dropped
end
local drop=nextDrop()
if drop==nil then
return{},dropped
end
kept[drop]=false
dropped[#dropped+1]=drop
end
end
function standing.ratedFit(natural,count,hasTrend,room)
local floor,each=A.metric("standingCellFloor"),A.metric("standingStat")+1
local need=hasTrend and floor or 0
local kept=count
while kept>0 and natural+need+each*kept>room do
kept=kept-1
end
local cell=natural
if cell+need>room then
cell=math.max(math.min(natural,floor),room-need)
end
local trend=hasTrend and math.max(0,room-cell-each*kept)or 0
return cell,kept,trend
end
function standing.paintCells(strip,reading,width)
local cells,reason={},nil
if reading.shape=="rated"then
local _,_,why=A.ratingColour(reading.format,reading.rating)
reason=why
local change=reading.sessionChange
cells[1]={
format=reading.format,rating=reading.rating,label=reading.label,
figure=reading.rating~=nil and tostring(reading.rating)or"-",
change=A.signedText(change),
changeTone=(change or 0)>0 and"win"or(change or 0)<0 and"loss"or"dim",
tier=(A.ratingTierName(reading.format,reading.rating)),high=reading.high,
unranked=A.ratingTierEnum(reading.format,reading.rating)==0,
}
else
local tiles=reading.tiles or{}
for i=1,math.min(#tiles,#strip.tiles)do
local tile=tiles[i]
local tierName,why=A.ratingTierName(tile.format,tile.rating)
reason=reason or why
cells[i]={
format=tile.format,rating=tile.rating,label=tile.label,figure=tostring(tile.rating),
change=tile.played and A.signedText(tile.change)or nil,
changeTone=(tile.change or 0)>0 and"win"or(tile.change or 0)<0 and"loss"or"dim",
tier=tierName,faded=not tile.played,
unranked=A.ratingTierEnum(tile.format,tile.rating)==0,
}
end
end
local rateWidth=A.metric("standingRate")
local rateX=width-rateWidth
local naturals,metrics={},{}
for i,cell in ipairs(cells)do
metrics[i]=standing.fill(strip.tiles[i],cell)
naturals[i]=metrics[i].natural
end
local stats,kept,trendRoom={},0,nil
local widths,dropped
if reading.shape=="rated"then
for i=2,#(reading.figures or{})do
if#stats<#strip.stats and type(reading.figures[i])=="table"then
stats[#stats+1]=reading.figures[i]
end
end
local cellWidth
cellWidth,kept,trendRoom=standing.ratedFit(naturals[1],#stats,
#(reading.bars or{})>0,rateX-1)
widths,dropped={cellWidth},{}
else
widths,dropped=standing.fit(cells,naturals,rateX-1)
end
local x,rules,centre=0,0,0
local labels,drawnWidths={},{}
for i,cell in ipairs(cells)do
local held=strip.tiles[i]
if widths[i]~=nil then
if#labels>0 then
rules=rules+1
standing.ruleAt(strip,rules,x)
x=x+1
end
local off=standing.placeCell(strip,held,cell,metrics[i],x,widths[i])
if math.abs(off)>math.abs(centre)then
centre=off
end
local alpha=(cell.faded and not cell.unranked)and 0.5 or 1
for _,key in ipairs({"label","rating","tier","change","high","highValue"})do
pcall(held[key].SetAlpha,held[key],alpha)
end
labels[#labels+1]=cell.label or"?"
drawnWidths[#drawnWidths+1]=tostring(widths[i])
x=x+widths[i]
end
end
local shed={}
for _,i in ipairs(dropped)do
shed[#shed+1]=cells[i].label or"?"
end
local statWidth=A.metric("standingStat")
local trendTo=rateX-1
if reading.shape=="rated"then
trendTo=rateX-1-(statWidth+1)*kept
for k=1,#stats do
local figure=stats[k]
figure.shed=k>kept
if k<=kept then
local ruleX=trendTo+(k-1)*(statWidth+1)
rules=rules+1
standing.ruleAt(strip,rules,ruleX)
local held={label=strip.stats[k].label,rating=strip.stats[k].value,tier=strip.stats[k].sub}
local cell={label=figure.label,figure=figure.value or"-",
figureTone=figure.tone or"bright",tier=figure.sub,subTone=figure.subTone}
local off=standing.placeCell(strip,held,cell,standing.fill(held,cell),ruleX+1,statWidth)
if math.abs(off)>math.abs(centre)then
centre=off
end
figure.drawn=cell.figure
labels[#labels+1]=figure.label or"?"
drawnWidths[#drawnWidths+1]=tostring(statWidth)
end
end
for k=#stats,kept+1,-1 do
shed[#shed+1]=stats[k].label or"?"
end
end
local figure=(reading.figures or{})[1]
local rate=nil
if type(figure)=="table"then
if#labels>0 then
rules=rules+1
standing.ruleAt(strip,rules,rateX-1)
end
local held={label=strip.rate.label,rating=strip.rate.value,tier=strip.rate.sub}
local cell={label=figure.label,figure=figure.value or"-",figureTone=figure.tone or"bright",
tier=figure.sub,subTone=figure.subTone}
local off=standing.placeCell(strip,held,cell,standing.fill(held,cell),rateX,rateWidth)
if math.abs(off)>math.abs(centre)then
centre=off
end
figure.drawn=cell.figure
rate=rateWidth
end
strip.edge:SetColorTexture(A.color("insetEdge"))
strip.edge:Show()
local bars,inset,barWidth=0,nil,nil
if reading.shape=="rated"then
local gap=A.metric("standingGap")
if trendRoom~=nil and trendRoom>0 then
bars,inset,barWidth=standing.trend(strip,reading.bars or{},x+gap,trendTo-gap)
end
end
return bars,reason,{
labels=#labels>0 and table.concat(labels,",")or"none",
widths=#drawnWidths>0 and table.concat(drawnWidths,",")or nil,
rules=rules,
rate=rate,
centre=A.unitFigure(math.abs(centre)),
shed=#shed>0 and table.concat(shed,",")or nil,
edge="strip",
trend=trendRoom,
inset=inset,
barWidth=barWidth,
}
end
function standing.paint(region,reading)
local strip=region.standing
if strip==nil or type(reading)~="table"then
return nil
end
standing.hideAll(strip)
strip:SetHeight(A.metric("standingStrip"))
local r,g,b,a=A.color("inset")
strip.ground:SetColorTexture(r,g,b,a or 1)
strip.ground:Show()
local ground=A.colorHex(r,g,b,a)
strip:Show()
local width=select(2,pcall(strip.GetWidth,strip))
if type(width)~="number"or width<=0 then
width=A.listHostWidth(false)
end
local gap=A.metric("standingGap")
local reason,drawn,layout
if reading.shape=="rated"or reading.shape=="all"then
drawn,reason,layout=standing.paintCells(strip,reading,width)
elseif type(reading.hero)=="table"and reading.hero.kind=="world"and strip.hero then
drawn,layout=standing.paintWorld(strip,strip.hero,reading.hero,width)
elseif type(reading.hero)=="table"then
drawn=standing.paintHero(strip,reading.hero,width)
else
standing.place(strip,strip.rating,reading.record or"-",0,-4)
setColor(strip.rating,"bright")
local recordWidth=standing.width(strip.rating)or(A.fontSize("numberHuge")*3)
standing.place(strip,strip.change,reading.rate,recordWidth+10,-4-6)
setColor(strip.change,reading.rateTone or"dim")
local left=math.max(recordWidth+80,200)
local right=standing.figuresAt(strip,reading.figures,width)
drawn=standing.blocks(strip,reading.bars or{},left+gap,right-gap)
end
local tones={}
local figureCount=type(reading.hero)=="table"and 0 or math.min(#(reading.figures or{}),#strip.figures)
for i=1,figureCount do
local figure=reading.figures[i]
if figure.shed~=true then
tones[#tones+1]=tostring(figure.label).."="..(figure.tone or"bright")
end
end
return{shape=reading.shape,bars=drawn,reason=reason,ground=ground,
tones=#tones>0 and table.concat(tones,",")or nil,
tiles=reading.shape=="all"and math.min(#(reading.tiles or{}),#strip.tiles)or nil,
layout=layout}
end
function standing.traceStrip(summary,reading,drew,height)
if type(A.trace)~="function"or type(drew)~="table"or type(reading)~="table"then
return
end
local lastFigure=nil
for _,figure in ipairs(reading.figures or{})do
if figure.label=="LAST PLAYED"then
lastFigure=figure
end
end
local layout=type(drew.layout)=="table"and drew.layout or{}
pcall(A.trace,"strip",{format=summary.format,shape=drew.shape,bars=drew.bars,
reason=drew.reason,total=height,ground=drew.ground,tones=drew.tones,
last=lastFigure and lastFigure.drawn or nil,
lastFit=lastFigure and lastFigure.fit or nil,
stripSeason=reading.stripSeason,n=drew.tiles,
record=reading.shape=="ladderless"
and(reading.recordKind or(reading.record and"record")or"none")or nil,
labels=layout.labels,widths=layout.widths,rules=layout.rules,rate=layout.rate,
centre=layout.centre,shed=layout.shed,edge=layout.edge,trend=layout.trend,
inset=layout.inset,barWidth=layout.barWidth,
cells=layout.cells,outings=layout.outings},"ui")
end
standing.CHIPS=6
standing.SQUARES=10
function standing.buildHero(strip)
local hero={all={}}
local function text(role,tone,justify)
local made=standing.text(strip,role,tone,justify)
hero.all[#hero.all+1]=made
return made
end
local function texture(layer)
local made=strip:CreateTexture(nil,layer or"ARTWORK")
made:Hide()
hero.all[#hero.all+1]=made
return made
end
hero.record=text("numberHuge","bright")
hero.rate=text("numberSmall","dim")
hero.line=text("bodyText","dim")
hero.squares={}
for i=1,standing.SQUARES do
hero.squares[i]=texture()
end
hero.howLabel=text("label","dim")
hero.how={}
for i=1,2 do
hero.how[i]={word=text("bodyText","text"),pair=text("numberSmall","text","RIGHT"),
track=texture(),win=texture(),loss=texture(),count=text("note","dim")}
end
hero.lastGround=texture("BORDER")
hero.lastLabel=text("label","dim")
hero.lastWhen=text("numberSmall","dim","RIGHT")
hero.lastResult=text("number","bright")
hero.lastName=text("bodyMedium","text")
hero.lastRealm=text("note","dim")
hero.lastHow=text("note","dim")
hero.tiles={}
for i=1,3 do
hero.tiles[i]={label=text("label","dim"),value=text("number","bright"),sub=text("note","dim")}
end
hero.whyLabel=text("label","dim")
hero.chips={}
for i=1,standing.CHIPS do
hero.chips[i]={ground=texture("BORDER"),text=text("bodyText","text")}
end
hero.worldCells={}
for i=1,4 do
hero.worldCells[i]={label=text("stripLabel","label"),rating=text("stripFigure","bright"),
tier=text("stripTier","dim")}
end
hero.worldRules={}
for i=1,4 do
hero.worldRules[i]=texture()
end
hero.worldLine=texture()
hero.killBars,hero.deathBars={},{}
for i=1,standing.WORLD_TREND do
hero.killBars[i]=texture()
hero.deathBars[i]=texture()
end
strip.hero=hero
end
standing.WORLD_TREND=20
function standing.worldRule(strip,held,index,x)
local rule=held.worldRules[index]
rule:ClearAllPoints()
rule:SetPoint("TOPLEFT",strip,"TOPLEFT",x,0)
rule:SetSize(1,A.metric("standingStrip")-1)
rule:SetColorTexture(A.color("insetEdge"))
rule:Show()
end
function standing.worldTrend(strip,held,bars,from,to)
local count=math.min(#bars,#held.killBars)
local frame=to-from
local gap=A.metric("standingBarGap")
local scale=0
for i=1,count do
scale=math.max(scale,bars[i].kills or 0,bars[i].deaths or 0)
end
if count==0 or frame<count then
return 0
end
local height=A.metric("standingStrip")
local mid=math.floor(height*0.5)
local reach=mid-A.metric("standingTrendInset")
local bar=math.max(1,math.min(A.metric("standingBar"),math.floor((frame-gap*(count-1))/count)))
held.worldLine:ClearAllPoints()
held.worldLine:SetPoint("TOPLEFT",strip,"TOPLEFT",from,-mid)
held.worldLine:SetSize(frame,1)
held.worldLine:SetColorTexture(A.color("hairline"))
held.worldLine:Show()
for i=1,count do
local x=from+(i-1)*(bar+gap)
local pair=bars[i]
for _,side in ipairs({{held.killBars[i],pair.kills or 0,"win",true},
{held.deathBars[i],pair.deaths or 0,"loss",false}})do
local texture,figure=side[1],side[2]
if figure>0 and scale>0 then
local tall=math.max(1,math.floor(reach*figure/scale+0.5))
texture:ClearAllPoints()
texture:SetPoint("TOPLEFT",strip,"TOPLEFT",x,side[4]and-(mid-tall)or-(mid+1))
texture:SetSize(bar,tall)
texture:SetColorTexture(A.color(side[3]))
texture:Show()
end
end
end
return count
end
function standing.paintWorld(strip,held,data,width)
local statWidth=A.metric("standingStat")
local tallied=(data.tallied or 0)>0
local outings=data.outings or 0
local cells={
{label="WORLD PVP",figure=tallied and A.kdPairText(data.kills,data.deaths)or"-",
tier=("%d %s"):format(outings,outings==1 and"outing"or"outings")},
{label="KILLS PER DEATH",figure=data.ratio or"-",figureTone=data.ratio and data.ratioTone or"dim",
tier=data.best},
{label="TIME OUT",figure=data.timeOut or"-",figureTone=data.timeOut and"bright"or"dim",
tier=data.average},
{label="LAST OUT",figure=data.lastOut or"-",figureTone=data.lastOut and"bright"or"dim",
tier=data.lastSub},
}
local first=held.worldCells[1]
local m=standing.fill(first,cells[1])
local firstWidth=math.max(m.natural,A.metric("standingCellFloor"))
standing.placeCell(strip,first,cells[1],m,0,firstWidth)
local right=width-statWidth*3-3
local labels={cells[1].label}
local rules=0
for i=2,4 do
local x=right+(i-2)*(statWidth+1)
rules=rules+1
standing.worldRule(strip,held,rules,x)
local cellHeld=held.worldCells[i]
local cell=cells[i]
if cell.label=="LAST OUT"and type(data.lastForms)=="table"and#data.lastForms>0 then
cell.figure=A.fittedForm(cellHeld.rating,statWidth-A.metric("standingPad")*2,data.lastForms)
or data.lastForms[#data.lastForms]
end
standing.placeCell(strip,cellHeld,cell,standing.fill(cellHeld,cell),x+1,statWidth)
labels[#labels+1]=cell.label
end
local gap=A.metric("standingGap")
rules=rules+1
standing.worldRule(strip,held,rules,firstWidth)
local from,to=firstWidth+1+gap,right-gap
local drawn=standing.worldTrend(strip,held,data.bars or{},from,to)
strip.edge:SetColorTexture(A.color("insetEdge"))
strip.edge:Show()
local shownCells=drawn>0 and 1 or 0
for i=1,4 do
if held.worldCells[i].rating:IsShown()then
shownCells=shownCells+1
end
end
return drawn,{
labels=table.concat(labels,","),
rules=rules,
edge="strip",
trend=math.max(0,to-from),
cells=shownCells,
outings=outings,
}
end
function standing.paintOther(strip,held,data,width)
local each=170
local tiles={
{"LEFT EARLY",tostring(data.leftEarly or 0),
(data.unset or 0)>0 and("%d with no reason set"):format(data.unset)or nil},
{"OTHER MATCHES",tostring(data.others or 0),(data.others or 0)>0 and data.record or nil},
{"LAST PLAYED",data.lastPlayed or"-",data.lastSub},
}
local valueTop=-4-A.fontSize("label")-3
for i,tile in ipairs(tiles)do
local region,x=held.tiles[i],(i-1)*each
standing.place(strip,region.label,tile[1],x,-4,each-8)
local value=tile[2]
if i==3 and type(data.lastForms)=="table"and#data.lastForms>0 then
value=A.fittedForm(region.value,each-8,data.lastForms)or data.lastForms[#data.lastForms]
end
standing.place(strip,region.value,value,x,valueTop,each-8)
setColor(region.value,"bright")
standing.place(strip,region.sub,tile[3],x,valueTop-A.fontSize("number")-3,each-8)
end
local x0=3*each
standing.place(strip,held.whyLabel,"WHY YOU LEFT",x0,-4)
local x,top,tall=x0,valueTop,A.fontSize("bodyText")+8
local drawn=0
for i,chip in ipairs(data.reasons or{})do
local region=held.chips[i]
if region==nil then
break
end
standing.place(strip,region.text,("%s  %d"):format(chip.label,chip.count),x+8,top-4)
setColor(region.text,chip.unset and"dim"or"text")
local wide=(standing.width(region.text)or 60)+16
if x+wide>width then
region.text:Hide()
break
end
region.ground:ClearAllPoints()
region.ground:SetPoint("TOPLEFT",strip,"TOPLEFT",x,top)
region.ground:SetSize(wide,tall)
local r,g,b=A.color(chip.unset and"hairline"or"selection")
region.ground:SetColorTexture(r,g,b,chip.unset and 0.5 or 1)
region.ground:Show()
x=x+wide+6
drawn=drawn+1
end
return drawn
end
function standing.paintHero(strip,data,width)
local held=strip.hero
if held==nil then
return 0
end
if data.kind=="other"then
return standing.paintOther(strip,held,data,width)
end
standing.place(strip,held.record,data.record or"0-0",0,-2)
setColor(held.record,"bright")
local recordWidth=standing.width(held.record)or(A.fontSize("numberHuge")*3)
standing.place(strip,held.rate,A.percentText(data.rate),recordWidth+10,-2-14)
setColor(held.rate,A.winRateTone(data.rate)or"dim")
local lineTop=-2-A.fontSize("numberHuge")-2
local duels,players=data.duels or 0,data.players or 0
standing.place(strip,held.line,("%d %s against %d %s"):format(duels,duels==1 and"duel"or"duels",
players,players==1 and"player"or"players"),0,lineTop)
local size,gap=A.metric("standingSquare"),3
local squareTop=lineTop-A.fontSize("bodyText")-4
local drawn=0
for i,tone in ipairs(data.squares or{})do
local square=held.squares[i]
if square then
square:ClearAllPoints()
square:SetPoint("TOPLEFT",strip,"TOPLEFT",(i-1)*(size+gap),squareTop)
square:SetSize(size,size)
local r,g,b=A.color(tone)
square:SetColorTexture(r,g,b,1)
square:Show()
drawn=drawn+1
end
end
local leftWidth=math.max(recordWidth+10+(standing.width(held.rate)or 0),
standing.width(held.line)or 0,standing.SQUARES*(size+gap))
local howX=leftWidth+A.metric("standingGap")*2
standing.place(strip,held.howLabel,"HOW THEY END",howX,-2)
local word,pair,bar=70,44,110
local howEnd=howX
for i,row in ipairs({{"Knockout",data.knockout},{"Fled",data.fled}})do
local region,counts=held.how[i],row[2]or{wins=0,losses=0}
local y=-2-A.fontSize("label")-6-(i-1)*22
standing.place(strip,region.word,row[1],howX,y,word)
standing.place(strip,region.pair,counts.text or"0-0",howX+word,y,pair)
local barX=howX+word+pair+10
local barY=y-math.floor((A.fontSize("bodyText")-6)*0.5)
region.track:ClearAllPoints()
region.track:SetPoint("TOPLEFT",strip,"TOPLEFT",barX,barY)
region.track:SetSize(bar,6)
region.track:SetColorTexture(A.color("hairline"))
region.track:Show()
local total=(counts.wins or 0)+(counts.losses or 0)
local won=total>0 and math.floor(bar*counts.wins/total+0.5)or 0
if won>0 then
region.win:ClearAllPoints()
region.win:SetPoint("TOPLEFT",strip,"TOPLEFT",barX,barY)
region.win:SetSize(won,6)
region.win:SetColorTexture(A.color("win"))
region.win:Show()
end
if total>0 and bar-won>0 then
region.loss:ClearAllPoints()
region.loss:SetPoint("TOPLEFT",strip,"TOPLEFT",barX+won,barY)
region.loss:SetSize(bar-won,6)
region.loss:SetColorTexture(A.color("loss"))
region.loss:Show()
end
standing.place(strip,region.count,("%d %s"):format(total,total==1 and"duel"or"duels"),
barX+bar+10,y)
howEnd=barX+bar+10+(standing.width(region.count)or 50)
end
local last=data.last
local boxWidth=A.metric("duelPanel")
local boxX=width-boxWidth
if type(last)=="table"and boxX>howEnd+A.metric("standingGap")then
local pad=8
held.lastGround:ClearAllPoints()
held.lastGround:SetPoint("TOPLEFT",strip,"TOPLEFT",boxX,-2)
held.lastGround:SetSize(boxWidth,A.metric("standingStrip")-6)
held.lastGround:SetColorTexture(A.color("panel"))
held.lastGround:Show()
standing.place(strip,held.lastLabel,"LAST DUEL",boxX+pad,-2-pad)
standing.place(strip,held.lastWhen,last.when,boxX+boxWidth/2,-2-pad,boxWidth/2-pad)
local resultTop=-2-pad-A.fontSize("label")-4
standing.place(strip,held.lastResult,last.result,boxX+pad,resultTop)
setColor(held.lastResult,last.tone or"bright")
local nameX=boxX+pad+(last.result and((standing.width(held.lastResult)or 30)+8)or 0)
standing.place(strip,held.lastName,last.name,nameX,resultTop+2)
if last.classToken then
held.lastName:SetTextColor(A.classColor(last.classToken))
else
setColor(held.lastName,"text")
end
standing.place(strip,held.lastRealm,last.realm,nameX+(standing.width(held.lastName)or 60)+6,
resultTop+1)
standing.place(strip,held.lastHow,last.how,boxX+pad,resultTop-A.fontSize("number")-4,
boxWidth-pad*2)
end
return drawn
end
function standing.hide(region)
if region and region.standing then
region.standing:Hide()
end
end
local DUEL_PANEL_ROWS=10
local DUEL_RATE_FLOOR=3
function A.duelRateFloor()
return DUEL_RATE_FLOOR
end
function A.duelPanelRate(row)
if type(row)~="table"then
return nil
end
local decided=(row.wins or 0)+(row.losses or 0)
if decided<DUEL_RATE_FLOOR then
return nil
end
local rate=row.wins/decided
return A.percentText(rate),A.winRateTone(rate)
end
function A.duelPanelClick(guid,via)
if type(guid)~="string"or type(A.openPlayer)~="function"then
return"none"
end
local _,outcome=A.openPlayer(guid,false,via or"duel-panel")
return outcome or"refused"
end
function A.buildDuelPanel(parent)
local panel=CreateFrame("Frame",nil,parent)
panel:Hide()
panel.ground=panel:CreateTexture(nil,"BACKGROUND")
panel.ground:SetAllPoints(panel)
panel.rule=panel:CreateTexture(nil,"BORDER")
panel.rule:SetPoint("TOPLEFT",panel,"TOPLEFT",0,0)
panel.rule:SetPoint("BOTTOMLEFT",panel,"BOTTOMLEFT",0,0)
panel.rule:SetWidth(1)
panel.title=standing.text(panel,"label","dim")
panel.title:SetPoint("TOPLEFT",panel,"TOPLEFT",10,-8)
local head=A.metric("rowHeadRow")
local tall=A.metric("duelPanelRow")
local function face(row,role,tone,justify)
local made=row:CreateFontString(nil,"ARTWORK","GameFontHighlightSmall")
made:SetJustifyH(justify or"LEFT")
made:SetWordWrap(false)
A.style(made,role,tone)
return made
end
panel.rows={}
for i=1,DUEL_PANEL_ROWS do
local row=CreateFrame("Button",nil,panel)
row:SetHeight(tall)
row:SetPoint("TOPLEFT",panel,"TOPLEFT",0,-(head+(i-1)*tall))
row:SetPoint("TOPRIGHT",panel,"TOPRIGHT",0,-(head+(i-1)*tall))
row.rate=face(row,"numberSmall","dim","RIGHT")
row.rate:SetPoint("RIGHT",row,"RIGHT",-10,0)
row.rate:SetWidth(40)
row.pair=face(row,"numberSmall","text","RIGHT")
row.pair:SetPoint("RIGHT",row.rate,"LEFT",-6,0)
row.pair:SetWidth(44)
row.met=face(row,"numberSmall","dim","RIGHT")
row.met:SetPoint("RIGHT",row.pair,"LEFT",-6,0)
row.met:SetWidth(30)
row.name=face(row,"bodyMedium","text")
row.name:SetPoint("TOPLEFT",row,"TOPLEFT",10,-4)
row.name:SetPoint("RIGHT",row.met,"LEFT",-6,0)
row.sub=face(row,"note","dim")
row.sub:SetPoint("TOPLEFT",row.name,"BOTTOMLEFT",0,-2)
row.sub:SetPoint("RIGHT",row.met,"LEFT",-6,0)
row:SetScript("OnClick",function(self)
A.duelPanelClick(self.guid,"duel-panel")
end)
row:Hide()
panel.rows[i]=row
end
return panel
end
function A.paintDuelPanel(panel,hero,shown)
if not panel then
return 0
end
if not shown or type(hero)~="table"then
panel:Hide()
return 0
end
panel.ground:SetColorTexture(A.color("inset"))
panel.rule:SetColorTexture(A.color("insetEdge"))
panel.title:SetText("WHO YOU DUEL")
panel.title:Show()
local tally=hero.opponents or{}
local drawn=0
for i,row in ipairs(panel.rows)do
local entry=tally[i]
row.guid=entry and entry.key or nil
if entry then
row.name:SetText(entry.bare or entry.name)
local token=entry.key and type(hero.classes)=="table"and hero.classes[entry.key]or nil
if token then
row.name:SetTextColor(A.classColor(token))
else
A.style(row.name,"bodyMedium","text")
end
local last=entry.lastAt and A.shortDay(entry.lastAt)or nil
local sub={}
sub[#sub+1]=entry.realm
sub[#sub+1]=last and("last "..last)or nil
row.sub:SetText(table.concat(sub,", "))
row.met:SetText("x"..tostring(entry.matches or 0))
row.pair:SetText(("%d-%d"):format(entry.wins or 0,entry.losses or 0))
local rate,tone=A.duelPanelRate(entry)
row.rate:SetText(rate or"")
setColor(row.rate,tone or"dim")
row:EnableMouse(entry.key~=nil)
row:Show()
drawn=drawn+1
else
row:Hide()
end
end
panel:Show()
return drawn
end
function A.traceHeroTab(format,hero,rows,panelRows)
if type(A.trace)~="function"then
return
end
hero=type(hero)=="table"and hero or{}
if format=="duel"then
A.trace("duel-tab",{rows=rows or 0,wins=hero.wins or 0,losses=hero.losses or 0,
duels=hero.duels or 0,players=hero.players or 0,
knockout=hero.knockout and hero.knockout.text or"0-0",
fled=hero.fled and hero.fled.text or"0-0",
resolved=hero.resolved or 0,nameOnly=hero.nameOnly or 0,shown=panelRows or 0},"ui")
elseif format=="unknown"then
A.trace("other-tab",{rows=rows or 0,leftEarly=hero.leftEarly or 0,unset=hero.unset or 0,
others=hero.others or 0,wins=hero.wins or 0,losses=hero.losses or 0},"ui")
end
end
local function buildTile(parent)
local tile=CreateFrame("Frame",nil,parent)
tile:SetSize(96,A.tileHeight())
tile.ground=tile:CreateTexture(nil,"BACKGROUND")
tile.ground:SetAllPoints(tile)
tile.edges={}
for i=1,4 do
tile.edges[i]=tile:CreateTexture(nil,"BORDER")
end
tile.edges[1]:SetPoint("TOPLEFT",tile,"TOPLEFT",0,0)
tile.edges[1]:SetPoint("TOPRIGHT",tile,"TOPRIGHT",0,0)
tile.edges[1]:SetHeight(1)
tile.edges[2]:SetPoint("BOTTOMLEFT",tile,"BOTTOMLEFT",0,0)
tile.edges[2]:SetPoint("BOTTOMRIGHT",tile,"BOTTOMRIGHT",0,0)
tile.edges[2]:SetHeight(1)
tile.edges[3]:SetPoint("TOPLEFT",tile,"TOPLEFT",0,0)
tile.edges[3]:SetPoint("BOTTOMLEFT",tile,"BOTTOMLEFT",0,0)
tile.edges[3]:SetWidth(1)
tile.edges[4]:SetPoint("TOPRIGHT",tile,"TOPRIGHT",0,0)
tile.edges[4]:SetPoint("BOTTOMRIGHT",tile,"BOTTOMRIGHT",0,0)
tile.edges[4]:SetWidth(1)
local pad=A.metric("tilePad")
tile.label=tile:CreateFontString(nil,"ARTWORK","GameFontDisableSmall")
tile.label:SetPoint("TOPLEFT",tile,"TOPLEFT",pad,-pad)
tile.label:SetJustifyH("LEFT")
tile.label:SetWordWrap(false)
A.style(tile.label,"label","dim")
tile.value=tile:CreateFontString(nil,"ARTWORK","GameFontNormal")
tile.value:SetPoint("TOPLEFT",tile.label,"BOTTOMLEFT",0,-A.metric("tileLabelGap"))
tile.value:SetJustifyH("LEFT")
tile.value:SetWordWrap(false)
A.style(tile.value,"number","bright")
tile.note=tile:CreateFontString(nil,"ARTWORK","GameFontDisableSmall")
tile.note:SetPoint("TOPLEFT",tile.value,"BOTTOMLEFT",0,-A.metric("tileValueGap"))
tile.note:SetJustifyH("LEFT")
tile.note:SetWordWrap(false)
A.style(tile.note,"note","dim")
tile.beside=tile:CreateFontString(nil,"ARTWORK","GameFontDisableSmall")
tile.beside:SetPoint("BOTTOMRIGHT",tile,"BOTTOMRIGHT",-pad,pad)
tile.beside:SetJustifyH("RIGHT")
tile.beside:SetWordWrap(false)
A.style(tile.beside,"rowNote","dim")
tile.beside:Hide()
tile.moment=tile:CreateFontString(nil,"ARTWORK","GameFontDisableSmall")
tile.moment:SetPoint("TOPRIGHT",tile,"TOPRIGHT",
-pad-A.metric("tileDoorMark")-pad,-pad)
tile.moment:SetJustifyH("RIGHT")
tile.moment:SetWordWrap(false)
A.style(tile.moment,"label","dimmer")
tile.moment:Hide()
tile.lane=tile:CreateTexture(nil,"OVERLAY")
tile.lane:SetPoint("TOPLEFT",tile,"TOPLEFT",0,0)
tile.lane:SetPoint("BOTTOMLEFT",tile,"BOTTOMLEFT",0,0)
tile.lane:SetWidth(A.metric("tileEdgeLane"))
tile.lane:Hide()
tile.door=tile:CreateTexture(nil,"OVERLAY")
tile.door:SetSize(A.metric("tileDoorMark"),A.metric("tileDoorMark"))
tile.door:SetPoint("TOPRIGHT",tile,"TOPRIGHT",-pad,-pad)
tile.door:Hide()
tile.trend=CreateFrame("Frame",nil,tile)
tile.trend:SetPoint("BOTTOMRIGHT",tile,"BOTTOMRIGHT",-pad,pad)
tile.trend:SetHeight(A.fontSize("number"))
tile.trend:SetWidth(A.metric("tileTrendWidth"))
tile.trend.lines={}
tile.trend.bars={}
tile.trend:Hide()
tile:EnableMouse(true)
tile.showTooltip=function(self)
return A.keyedTooltip(self,self.tooltipLines,"ANCHOR_TOP","tile")
end
tile:SetScript("OnEnter",tile.showTooltip)
tile:SetScript("OnLeave",A.hideTooltip)
tile:SetScript("OnMouseUp",function(self,button)
if button~="LeftButton"or self.opens==nil then
return
end
if type(A.showMatchWindow)=="function"then
pcall(A.showMatchWindow,self.opensKind or"match",self.opens,"card")
end
end)
return tile
end
function A.tileTrendRoom(inner,need)
if type(inner)~="number"or type(need)~="number"then
return 0
end
local room=inner-need-A.metric("tileAsideGap")
if room<A.metric("tileTrendFloor")then
return 0
end
if room>A.metric("tileTrendWidth")then
return A.metric("tileTrendWidth")
end
return math.floor(room)
end
function A.tileAsideRoom(inner,need)
if type(inner)~="number"or type(need)~="number"then
return 0
end
local room=inner-need-A.metric("tileAsideGap")
if room<A.metric("tileAsideFloor")then
return 0
end
return math.floor(room)
end
function A.tileMomentRoom(inner,need)
if type(inner)~="number"or type(need)~="number"then
return 0
end
local room=inner-A.metric("tilePad")-A.metric("tileDoorMark")
-need-A.metric("tileAsideGap")
if room<1 then
return 0
end
return math.floor(room)
end
function A.tileAsideForms(extra)
if type(extra)~="table"then
return{}
end
if type(extra.besideForms)=="table"and#extra.besideForms>0 then
return extra.besideForms
end
return{extra.beside}
end
function A.tileMomentForms(extra)
local forms={}
if type(extra)~="table"then
return forms
end
for _,key in ipairs({"moment","momentAbbr","momentShort"})do
local text=extra[key]
if type(text)=="string"and text~=""and text~=forms[#forms]then
forms[#forms+1]=text
end
end
return forms
end
local function paintTrend(tile,points,shape,width,tone)
local trend=tile.trend
if not trend then
return false
end
if type(points)~="table"or#points<2 or type(width)~="number"or width<=0 then
trend:Hide()
return false
end
trend:SetWidth(width)
local height=A.fontSize("number")
trend:SetHeight(height)
local function hideFrom(pool,first)
for i=first,#pool do
pool[i]:Hide()
end
end
local drawn=0
if shape=="bars"then
hideFrom(trend.lines,1)
local bar=A.metric("tileTrendBar")
for i=1,#points do
local texture=trend.bars[i]
if not texture then
texture=trend:CreateTexture(nil,"ARTWORK")
trend.bars[i]=texture
end
local tall=math.max(1,math.floor(points[i].value*height))
texture:ClearAllPoints()
texture:SetPoint("BOTTOMLEFT",trend,"BOTTOMLEFT",
math.floor(points[i].at*math.max(0,width-bar)),0)
texture:SetSize(bar,tall)
texture:SetColorTexture(A.color(tone or"dim"))
texture:Show()
drawn=i
end
hideFrom(trend.bars,drawn+1)
else
hideFrom(trend.bars,1)
local weight=A.metric("tileTrendLine")
for i=1,#points-1 do
local line=trend.lines[i]
if not line then
line=trend:CreateLine(nil,"ARTWORK")
trend.lines[i]=line
end
line:SetThickness(weight)
line:SetColorTexture(A.color(tone or"dim"))
line:SetStartPoint("BOTTOMLEFT",trend,
points[i].at*width,points[i].value*height)
line:SetEndPoint("BOTTOMLEFT",trend,
points[i+1].at*width,points[i+1].value*height)
line:Show()
drawn=i
end
hideFrom(trend.lines,drawn+1)
end
trend:Show()
return true
end
local function setTile(tile,label,value,note,valueColor,noteColor,width,extra)
if value==nil then
tile:Hide()
return false
end
extra=type(extra)=="table"and extra or{}
tile.label:SetText(label)
tile.value:SetText(value)
setColor(tile.value,valueColor or"bright")
tile.beside:Hide()
tile.moment:Hide()
tile.besideDrawn,tile.momentDrawn=nil,nil
tile.lane:Hide()
tile.door:Hide()
tile.trend:Hide()
if extra.door then
tile.lane:SetColorTexture(A.color(valueColor or"bright"))
tile.lane:Show()
tile.door:SetColorTexture(A.color("dim"))
tile.door:Show()
end
if note then
tile.note:SetText(note)
setColor(tile.note,noteColor or"dim")
tile.note:Show()
else
tile.note:Hide()
end
tile.ground:SetColorTexture(A.color("field"))
local edge="hairline"
if extra.door then
edge=valueColor or"text"
end
for i=1,#tile.edges do
tile.edges[i]:SetColorTexture(A.color(edge))
end
local inner=width-A.metric("tilePad")*2
if inner<1 then
inner=1
end
tile.label:SetWidth(inner)
tile.value:SetWidth(inner)
tile.note:SetWidth(inner)
if type(extra.beside)=="string"and extra.beside~=""then
local room=A.tileAsideRoom(inner,A.textRoom(tile.value,tile.value:GetText()or""))
local fitted=A.fittedForm(tile.beside,room,A.tileAsideForms(extra))
if fitted~=nil then
tile.beside:SetWidth(room)
tile.beside:SetText(fitted)
setColor(tile.beside,extra.besideTone or"dim")
tile.beside:Show()
end
tile.besideDrawn=fitted or"none"
end
if type(extra.moment)=="string"and extra.moment~=""then
local room=A.tileMomentRoom(inner,A.textRoom(tile.label,label or""))
local fitted=A.fittedForm(tile.moment,room,A.tileMomentForms(extra))
if fitted~=nil then
tile.moment:SetWidth(room)
tile.moment:SetText(fitted)
tile.moment:Show()
end
tile.momentDrawn=fitted or"none"
end
if type(extra.trend)=="table"then
paintTrend(tile,extra.trend,extra.trendShape,
A.tileTrendRoom(inner,A.textRoom(tile.value,tile.value:GetText()or"")),
extra.trendTone)
end
tile:SetWidth(width)
tile:SetHeight(A.tileHeight())
tile:Show()
return true
end
local KEY_SWATCH,KEY_GAP=14,5
local POOLS={
ticks="BACKGROUND",
marks="BORDER",
mmr="BORDER",
lines="ARTWORK",
}
local function plotLine(plot,pool,index,thickness)
local lines=plot[pool]
local line=lines[index]
if not line then
line=plot:CreateLine(nil,POOLS[pool])
lines[index]=line
end
line:SetThickness(thickness or 1.5)
line:Show()
return line
end
local function hidePoolFrom(plot,pool,first)
local lines=plot[pool]
for i=first,#lines do
lines[i]:Hide()
end
end
local function hideLinesFrom(plot,first)
for pool in pairs(POOLS)do
hidePoolFrom(plot,pool,first)
end
for i=1,#plot.tickLabels do
plot.tickLabels[i]:Hide()
end
for i=1,#plot.dots do
plot.dots[i]:Hide()
end
plot.peakLabel:Hide()
plot.peakPlan=nil
plot.endLabel:Hide()
plot.startDate:Hide()
plot.endDate:Hide()
if plot.startLabel then
plot.startLabel:Hide()
end
plot.startPlan=nil
for _,pool in ipairs({plot.tierBands or{},plot.tierRules or{}})do
for i=1,#pool do
pool[i]:Hide()
end
end
plot.tierReading=nil
end
local function plotTexture(plot,pool,index)
plot[pool]=plot[pool]or{}
local texture=plot[pool][index]
if not texture then
texture=plot:CreateTexture(nil,"BACKGROUND")
plot[pool][index]=texture
end
texture:Show()
return texture
end
local function tierTone(format,value)
if type(A.ratingColour)=="function"then
local _,_,_,r,g,b=A.ratingColour(format,value)
if type(r)=="number"then
return r,g,b
end
end
local r,g,b=A.color("accent")
return r,g,b
end
local function tickLabel(plot,index)
local label=plot.tickLabels[index]
if not label then
label=plot:CreateFontString(nil,"ARTWORK","GameFontDisableSmall")
label:SetJustifyH("LEFT")
label:SetWordWrap(false)
plot.tickLabels[index]=label
end
A.style(label,"note","dimmer")
label:Show()
return label
end
local function plotDot(plot,index)
local dot=plot.dots[index]
if not dot then
dot=plot:CreateTexture(nil,"OVERLAY")
dot:SetSize(A.metric("plotDotSize"),A.metric("plotDotSize"))
plot.dots[index]=dot
end
dot:Show()
return dot
end
local function drawMarkers(plot,series,place,foot,height,loose,note,width)
plot.peakPlan=nil
local peakIndex,endIndex=nil,#series
for i=1,#series do
if peakIndex==nil or series[i].rating>series[peakIndex].rating then
peakIndex=i
end
end
local used=0
local function marker(index,tone)
local x,y=place(index,series[index].rating)
used=used+1
local dot=plotDot(plot,used)
dot:ClearAllPoints()
dot:SetPoint("CENTER",plot,"BOTTOMLEFT",x,y)
local r,g,b=A.color(tone)
dot:SetColorTexture(r,g,b,1)
return x,y
end
for i=1,#(loose or{})do
marker(loose[i],"dim")
end
local firstX,firstY=nil,nil
if#series>1 and peakIndex~=1 and endIndex~=1 then
local markedLoose=false
for i=1,#(loose or{})do
if loose[i]==1 then
markedLoose=true
end
end
if markedLoose then
firstX,firstY=place(1,series[1].rating)
else
firstX,firstY=marker(1,"text")
end
end
local peakX,peakY=marker(peakIndex,"accent")
local endX,endY=marker(endIndex,"text")
local pad=A.metric("plotLabelPad")
local face=A.fontSize("note")
local function clearOfNote(left,right)
if type(note)~="table"or type(note.room)~="number"or note.room<=0 then
return true
end
if note.at=="TOPRIGHT"then
return right<=(note.width or 0)-note.room
end
return left>=note.room
end
local function labelSide(y,left,right)
if y+pad+face<=foot+height then
return"BOTTOM",pad
end
if y+pad+face<=foot+height+A.metric("plotLabelDrop")and clearOfNote(left,right)then
return"BOTTOM",pad
end
return"TOP",-pad
end
local peakRepeats=series[peakIndex].rating==series[endIndex].rating
local peakText=("PEAK %d"):format(math.floor(series[peakIndex].rating))
local endText=("%d"):format(math.floor(series[endIndex].rating))
local peakRoom=A.textRoom(plot.peakLabel,peakText)
local endRoom=A.textRoom(plot.endLabel,endText)
local peakSide,peakDrop=labelSide(peakY,peakX+pad,peakX+pad+peakRoom)
local endSide,endDrop=labelSide(endY,endX-pad-endRoom,endX-pad)
local function labelBox(left,right,y,side,drop)
local top=side=="TOP"and(y+drop)or(y+drop+face)
return{left=left,right=right,bottom=top-face,top=top}
end
local peakBox=labelBox(peakX+pad,peakX+pad+peakRoom,peakY,peakSide,peakDrop)
local endBox=labelBox(endX-pad-endRoom,endX-pad,endY,endSide,endDrop)
local peakCollides=not peakRepeats
and peakBox.left<endBox.right and endBox.left<peakBox.right
and peakBox.bottom<endBox.top and endBox.bottom<peakBox.top
local inBand=peakSide=="BOTTOM"and peakY+pad+face>foot+height
if peakRepeats or peakCollides then
plot.peakLabel:Hide()
plot.peakPlan={reason=peakRepeats and"repeats"or"meets-end",x=peakX,room=peakRoom}
else
A.style(plot.peakLabel,"note")
tintRating(plot.peakLabel,plot.format,math.floor(series[peakIndex].rating),"accent")
plot.peakLabel:ClearAllPoints()
plot.peakLabel:SetPoint(peakSide.."LEFT",plot,"BOTTOMLEFT",peakX+pad,peakY+peakDrop)
plot.peakLabel:SetText(peakText)
plot.peakLabel:Show()
plot.peakPlan={
reason=inBand and"band"or(peakSide=="TOP"and"below"or"above"),
shown=true,band=inBand,x=peakX,left=peakX+pad,room=peakRoom,
anchor=peakSide.."LEFT",y=peakY+peakDrop,box=peakBox,endBox=endBox,
limit=width,
}
end
A.style(plot.endLabel,"note")
tintRating(plot.endLabel,plot.format,math.floor(series[endIndex].rating),"text")
plot.endLabel:ClearAllPoints()
plot.endLabel:SetPoint(endSide.."RIGHT",plot,"BOTTOMLEFT",endX-pad,endY+endDrop)
plot.endLabel:SetText(endText)
plot.endLabel:Show()
plot.startPlan=nil
if not plot.startLabel then
plot.startLabel=plot:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
plot.startLabel:SetJustifyH("LEFT")
plot.startLabel:SetWordWrap(false)
end
if firstX~=nil then
local firstText=("%d"):format(math.floor(series[1].rating))
local firstRoom=A.textRoom(plot.startLabel,firstText)
local firstSide,firstDrop=labelSide(firstY,firstX+pad,firstX+pad+firstRoom)
local firstBox=labelBox(firstX+pad,firstX+pad+firstRoom,firstY,firstSide,firstDrop)
local function meets(box)
return box~=nil and firstBox.left<box.right and box.left<firstBox.right
and firstBox.bottom<box.top and box.bottom<firstBox.top
end
local peakShown=plot.peakLabel:IsShown()
if meets(endBox)or(peakShown and meets(peakBox))then
plot.startLabel:Hide()
plot.startPlan={shown=false,reason="meets",rating=series[1].rating}
else
A.style(plot.startLabel,"note")
tintRating(plot.startLabel,plot.format,math.floor(series[1].rating),"text")
plot.startLabel:ClearAllPoints()
plot.startLabel:SetPoint(firstSide.."LEFT",plot,"BOTTOMLEFT",firstX+pad,firstY+firstDrop)
plot.startLabel:SetText(firstText)
plot.startLabel:Show()
plot.startPlan={shown=true,rating=series[1].rating}
end
else
plot.startLabel:Hide()
end
for i=used+1,#plot.dots do
plot.dots[i]:Hide()
end
local from=A.dayText(series[1].at)
local to=A.dayText(series[endIndex].at)
A.style(plot.startDate,"note","dimmer")
A.style(plot.endDate,"note","dimmer")
plot.startDate:SetText(from or"")
plot.endDate:SetText(to or"")
plot.startDate:SetShown(from~=nil)
plot.endDate:SetShown(to~=nil)
end
local function seriesRange(series,first,last)
local lo,hi
for i=first or 1,last or#series do
local value=series[i].rating
if type(value)=="number"then
if lo==nil or value<lo then
lo=value
end
if hi==nil or value>hi then
hi=value
end
end
end
return lo,hi
end
local function seriesDrawable(series)
if type(series)~="table"or#series<A.metric("plotPointMin")then
return false
end
local lo,hi=seriesRange(series)
return lo~=nil and hi~=nil and hi~=lo
end
local function barsDrawable(summary)
local held=type(summary)=="table"and summary.format==nil and summary.winLoss or nil
return type(held)=="table"and(held.won or 0)+(held.lost or 0)>0
end
local function plotBranch(fmt,summary,folded)
if type(summary)~="table"then
return"noPlot",{}
end
local tally=type(A.oneLadder)=="function"and A.oneLadder(fmt)
and type(A.opponentTally)=="function"
and A.opponentTally(fmt,A.windowCharacter(),summary.season,summary.bound)or{}
if summary.rating==nil and#tally>0 then
return"fought",tally
end
if barsDrawable(summary)then
return folded and"folded"or"bars",tally
end
if not seriesDrawable(summary.series)then
return"noPlot",tally
end
if folded and summary.rating~=nil then
return"folded",tally
end
return"plot",tally
end
local function seasonPanels(series)
local panels={}
local first=1
for i=2,#series+1 do
if i>#series or series[i].season~=series[i-1].season then
panels[#panels+1]={first=first,last=i-1}
first=i
end
end
return panels
end
function A.seriesSeasons(series)
if type(series)~="table"then
return 0
end
return#seasonPanels(series)
end
function A.seriesPanels(series,width,height,axisLo,axisHi)
if type(series)~="table"or type(width)~="number"or type(height)~="number"then
return{}
end
local panels=seasonPanels(series)
if#panels==0 then
return panels
end
local gap=#panels>1 and A.metric("plotPanelGap")or 0
local drawable=width-gap*(#panels-1)
local at=0
for p=1,#panels do
local panel=panels[p]
local count=panel.last-panel.first+1
panel.points=count
panel.x0=at
panel.x1=at+drawable*count/#series
panel.width=panel.x1-panel.x0
panel.height=height
at=panel.x1+gap
panel.lo,panel.hi=axisLo,axisHi
if#panels>1 then
panel.lo,panel.hi=A.plotExtent(series,panel.first,panel.last)
end
local least=A.metric("plotPointMin")
panel.joined=count>=least
end
return panels
end
function A.panelMmr(series,first,last)
local out={points=0,carried=0,segments=0,same=0,apart=0}
if type(series)~="table"then
return out
end
for i=first or 1,math.min(last or#series,#series)do
local point=series[i]
if type(point)=="table"then
out.points=out.points+1
if type(point.mmr)=="number"then
out.carried=out.carried+1
if point.mmr==point.rating then
out.same=out.same+1
end
local before=series[i-1]
if i>(first or 1)and type(before)=="table"and type(before.mmr)=="number"then
out.segments=out.segments+1
if not(before.mmr==before.rating and point.mmr==point.rating)then
out.apart=out.apart+1
end
end
end
end
end
return out
end
local function drawSeries(plot,series,showMmr,note)
if not seriesDrawable(series)then
hideLinesFrom(plot,1)
return 0,0
end
local width=plot:GetWidth()
local height=plot:GetHeight()
if type(width)~="number"or type(height)~="number"then
hideLinesFrom(plot,1)
return 0,0
end
local foot=A.plotFoot()
width=width-A.metric("plotGutter")
if type(note)=="table"then
note={at=note.at,room=note.room,width=width+A.metric("plotGutter")}
end
height=height-A.metric("plotLabelDrop")-foot
if width<40 or height<A.metric("plotCurveMin")then
hideLinesFrom(plot,1)
return 0,0
end
local extentLo,extentHi=A.plotExtent(series)
local tickBound=A.plotTicks(A.unitFigure(plot:GetHeight()))
local scale=A.plotScale(extentLo,extentHi,tickBound or A.metric("plotTickMax"))
local axisLo,axisHi=extentLo,extentHi
if scale then
axisLo,axisHi=scale.lo,scale.hi
end
local span=axisHi-axisLo
if span<=0 then
hideLinesFrom(plot,1)
return 0,0
end
local panels=A.seriesPanels(series,width,height,axisLo,axisHi)
local gap=#panels>1 and A.metric("plotPanelGap")or 0
local panelOf={}
for p=1,#panels do
local panel=panels[p]
for i=panel.first,panel.last do
panelOf[i]=panel
end
end
local loose={}
for p=1,#panels do
if not panels[p].joined then
for i=panels[p].first,panels[p].last do
loose[#loose+1]=i
end
end
end
local function place(index,value)
local panel=panelOf[index]or panels[1]
local x
if panel.last>panel.first then
x=panel.x0+(index-panel.first)/(panel.last-panel.first)*(panel.x1-panel.x0)
else
x=panel.x0+(panel.x1-panel.x0)*0.5
end
local y
local pspan=(panel.hi or 0)-(panel.lo or 0)
if pspan>0 then
y=foot+(value-panel.lo)/pspan*height
else
y=foot+height*0.5
end
return x,y
end
local ticksUsed=0
if scale and#panels<2 and tickBound~=nil then
for i=1,#scale.ticks do
local value=scale.ticks[i]
local y=foot+(value-axisLo)/span*height
ticksUsed=ticksUsed+1
local label=tickLabel(plot,ticksUsed)
label:ClearAllPoints()
label:SetPoint("BOTTOMLEFT",plot,"BOTTOMLEFT",
width+A.metric("plotLabelPad"),y-A.fontSize("note")*0.5)
label:SetText(tostring(value))
end
end
hidePoolFrom(plot,"ticks",1)
for i=ticksUsed+1,#plot.tickLabels do
plot.tickLabels[i]:Hide()
end
local ladder,ladderReason=nil,nil
if type(A.ratingLadder)=="function"and plot.format~=nil then
ladder,ladderReason=A.ratingLadder(plot.format)
end
local entries={}
if type(ladder)=="table"and type(ladder.tiers)=="table"then
for i=1,#ladder.tiers do
entries[i]=ladder.tiers[i].entry
end
end
local bands,rules=0,0
local _,_,_,bandAlpha=A.color("tierBand")
local _,_,_,ruleAlpha=A.color("tierRule")
for p=1,#panels do
local panel=panels[p]
local pspan=(panel.hi or 0)-(panel.lo or 0)
if pspan>0 and#entries>0 then
for i=1,#entries do
local lo=math.max(entries[i],panel.lo)
local hi=math.min(entries[i+1]or panel.hi,panel.hi)
if hi>lo then
bands=bands+1
local band=plotTexture(plot,"tierBands",bands)
local r,g,b=tierTone(plot.format,entries[i])
band:SetColorTexture(r,g,b,bandAlpha or 0.05)
band:ClearAllPoints()
band:SetPoint("BOTTOMLEFT",plot,"BOTTOMLEFT",panel.x0,foot+(lo-panel.lo)/pspan*height)
band:SetSize(math.max(1,panel.x1-panel.x0),math.max(1,(hi-lo)/pspan*height))
end
if entries[i]>panel.lo and entries[i]<panel.hi then
rules=rules+1
local rule=plotTexture(plot,"tierRules",rules)
local r,g,b=tierTone(plot.format,entries[i])
rule:SetColorTexture(r,g,b,ruleAlpha or 0.5)
rule:ClearAllPoints()
rule:SetPoint("BOTTOMLEFT",plot,"BOTTOMLEFT",panel.x0,
foot+(entries[i]-panel.lo)/pspan*height)
rule:SetSize(math.max(1,panel.x1-panel.x0),1)
end
end
end
end
for i=bands+1,#(plot.tierBands or{})do
plot.tierBands[i]:Hide()
end
for i=rules+1,#(plot.tierRules or{})do
plot.tierRules[i]:Hide()
end
local used=0
local marks=0
local mmrDrawn=0
for i=2,#series do
local from,to=series[i-1],series[i]
if from.season~=to.season then
local left=panelOf[i-1]
local x=left and(left.x1+gap*0.5)or(((i-1)-0.5)/(#series-1)*width)
marks=marks+1
local mark=plotLine(plot,"marks",marks,1)
local r,g,b=A.color("dimmer")
mark:SetColorTexture(r,g,b,1)
mark:SetStartPoint("BOTTOMLEFT",plot,x,foot)
mark:SetEndPoint("BOTTOMLEFT",plot,x,foot+height)
end
if from.season==to.season and(panelOf[i]or panels[1]).joined then
local x1,y1=place(i-1,from.rating)
local x2,y2=place(i,to.rating)
if showMmr and type(from.mmr)=="number"and type(to.mmr)=="number"
and not(from.mmr==from.rating and to.mmr==to.rating)then
local mx1,my1=place(i-1,from.mmr)
local mx2,my2=place(i,to.mmr)
mmrDrawn=mmrDrawn+1
local mmr=plotLine(plot,"mmr",mmrDrawn,A.metric("plotMmrThickness"))
mmr:SetColorTexture(1,1,1,A.metric("plotMmrAlpha"))
mmr:SetStartPoint("BOTTOMLEFT",plot,mx1,my1)
mmr:SetEndPoint("BOTTOMLEFT",plot,mx2,my2)
end
local pieces={{at=0,value=from.rating}}
if#entries>0 and to.rating~=from.rating then
local lo,hi=math.min(from.rating,to.rating),math.max(from.rating,to.rating)
for e=1,#entries do
if entries[e]>lo and entries[e]<hi then
pieces[#pieces+1]={at=(entries[e]-from.rating)/(to.rating-from.rating),
value=entries[e]}
end
end
table.sort(pieces,function(a,b)return a.at<b.at end)
end
pieces[#pieces+1]={at=1,value=to.rating}
for k=1,#pieces-1 do
used=used+1
local line=plotLine(plot,"lines",used)
local r,g,b=tierTone(plot.format,(pieces[k].value+pieces[k+1].value)/2)
line:SetColorTexture(r,g,b,1)
line:SetStartPoint("BOTTOMLEFT",plot,x1+(x2-x1)*pieces[k].at,y1+(y2-y1)*pieces[k].at)
line:SetEndPoint("BOTTOMLEFT",plot,x1+(x2-x1)*pieces[k+1].at,
y1+(y2-y1)*pieces[k+1].at)
end
end
end
hidePoolFrom(plot,"lines",used+1)
hidePoolFrom(plot,"marks",marks+1)
hidePoolFrom(plot,"mmr",mmrDrawn+1)
drawMarkers(plot,series,place,foot,height,loose,note,width)
plot.tierReading={tiers=bands,seg=used,reason=ladder==nil and ladderReason or nil,
from=(plot.startPlan and plot.startPlan.shown)and math.floor(series[1].rating)or nil}
return used,mmrDrawn
end
local function buildOpponentRow(parent,index)
local row=CreateFrame("Frame",nil,parent)
local rowHeight=A.metric("opponentRow")
row:SetHeight(rowHeight)
local drop=A.metric("plotLabelDrop")+(index-1)*rowHeight
row:SetPoint("TOPLEFT",parent,"TOPLEFT",0,-drop)
row:SetPoint("TOPRIGHT",parent,"TOPRIGHT",0,-drop)
row.name=row:CreateFontString(nil,"ARTWORK","GameFontHighlightSmall")
row.name:SetPoint("LEFT",row,"LEFT",0,0)
row.name:SetJustifyH("LEFT")
row.name:SetWordWrap(false)
A.style(row.name,"bodyText","text")
row.record=row:CreateFontString(nil,"ARTWORK","GameFontHighlightSmall")
row.record:SetPoint("LEFT",row,"LEFT",210,0)
row.record:SetJustifyH("LEFT")
A.style(row.record,"numberSmall")
return row
end
local function paintOpponents(region,rows)
local shown=math.min(#rows,OPPONENT_ROWS)
local keys={}
for i=1,shown do
if rows[i].key~=nil then
keys[rows[i].key]=true
end
end
local classes=type(A.classTokens)=="function"and A.classTokens(keys)or{}
local colored=0
for i=1,OPPONENT_ROWS do
local row=region.opponents[i]
local entry=i<=shown and rows[i]or nil
if entry then
local bare,realm=A.nameParts(entry.name)
local token=entry.key~=nil and classes[entry.key]or nil
local name=bare
if token~=nil and bare~=""then
local r,g,b=A.classColor(token)
name=("|cff%s%s|r"):format(A.colorHex(r,g,b):sub(1,6),bare)
colored=colored+1
end
row.name:SetText(realm and(name.."  "..A.colorEscape("dim")..realm.."|r")or name)
setColor(row.name,"text")
local held={wins=entry.wins,decided=entry.wins+entry.losses+(entry.draws or 0),
draws=entry.draws or 0}
row.record:SetText(A.winRecordText(held,"duel")or"-")
setColor(row.record,entry.wins==entry.losses and"dim"
or(entry.wins>entry.losses and"win"or"loss"))
row:Show()
else
row:Hide()
end
end
if type(A.trace)=="function"then
A.trace("fought",{rows=shown,classColored=colored},"ui")
end
return shown
end
function A.buildSummaryRegion(parent,controlHost,scopeChoices,onScopePick,onDetailsToggle,
onGraphFold)
local region=CreateFrame("Frame",nil,parent)
region:SetHeight(A.summaryHeight())
local host=controlHost or region
region.fromValue=region:CreateFontString(nil,"ARTWORK","GameFontNormalLarge")
region.fromValue:SetPoint("TOPLEFT",region,"TOPLEFT",0,-2)
region.fromValue:SetJustifyH("LEFT")
A.style(region.fromValue,"numberHuge","dim")
region.link=region:CreateFontString(nil,"ARTWORK","GameFontNormal")
region.link:SetPoint("LEFT",region.fromValue,"RIGHT",A.metric("headlineJoin"),-1)
A.style(region.link,"bodyMedium","dim")
region.toValue=region:CreateFontString(nil,"ARTWORK","GameFontNormalLarge")
region.toValue:SetPoint("LEFT",region.link,"RIGHT",A.metric("headlineJoin"),1)
region.toValue:SetJustifyH("LEFT")
A.style(region.toValue,"numberHuge","bright")
region.delta=region:CreateFontString(nil,"ARTWORK","GameFontHighlightSmall")
region.delta:SetPoint("TOPLEFT",region.fromValue,"BOTTOMLEFT",0,-4)
region.delta:SetJustifyH("LEFT")
A.style(region.delta,"numberSmall","dim")
region.tiles={}
for i=1,TILE_COUNT do
region.tiles[i]=buildTile(region)
end
if type(A.dropdown)=="function"and type(scopeChoices)=="table"and#scopeChoices>0 then
region.scope=A.dropdown(host,scopeChoices,onScopePick)
region.scope:SetPoint("TOPRIGHT",host,"TOPRIGHT",0,0)
end
if type(A.pill)=="function"then
region.details=A.pill(host,"Details",onDetailsToggle)
region.details:SetHeight(A.metric("segmentHeight"))
region.details.controlRole="label"
A.setControlTone(region.details,"dim")
end
if type(A.pill)=="function"then
region.graphToggle=A.pill(host,"Graph",onGraphFold)
region.graphToggle:SetHeight(A.metric("segmentHeight"))
region.graphToggle.controlRole="label"
A.setControlTone(region.graphToggle,"dim")
end
if type(A.pill)=="function"then
region.specsToggle=A.pill(host,"Specs",function()
if type(A.clickSpecsView)=="function"then
A.clickSpecsView()
end
end)
region.specsToggle:SetHeight(A.metric("segmentHeight"))
region.specsToggle.controlRole="label"
A.setControlTone(region.specsToggle,"dim")
region.specsToggle:Hide()
end
if type(A.pill)=="function"then
region.mapsToggle=A.pill(host,"Maps",function()
if type(A.clickMapsView)=="function"then
A.clickMapsView()
end
end)
region.mapsToggle:SetHeight(A.metric("segmentHeight"))
region.mapsToggle.controlRole="label"
A.setControlTone(region.mapsToggle,"dim")
region.mapsToggle:Hide()
end
if type(A.pill)=="function"then
for _,pair in ipairs({{"bestsToggle","Bests","bests"},{"buildsToggle","Builds","builds"}})do
local view=pair[3]
local pill=A.pill(host,pair[2],function()
if type(A.clickTableView)=="function"then
A.clickTableView(view)
end
end)
pill:SetHeight(A.metric("segmentHeight"))
pill.controlRole="label"
A.setControlTone(pill,"dim")
pill:Hide()
region[pair[1]]=pill
end
end
region.reading=CreateFrame("Frame",nil,region)
region.reading.bg=region.reading:CreateTexture(nil,"BACKGROUND")
region.reading.bg:SetAllPoints(region.reading)
region.reading.rows={}
for i=1,READING_ROWS do
local row=CreateFrame("Frame",nil,region.reading)
row:SetHeight(A.metric("readingRow"))
row.key=row:CreateFontString(nil,"ARTWORK")
row.key:SetPoint("TOPLEFT",row,"TOPLEFT",0,0)
row.key:SetWidth(A.metric("readingKeyWidth"))
row.key:SetJustifyH("LEFT")
row.key:SetWordWrap(false)
A.style(row.key,"label","dim")
row.text=row:CreateFontString(nil,"ARTWORK")
row.text:SetPoint("TOPLEFT",row,"TOPLEFT",
A.metric("readingKeyWidth")+A.metric("readingKeyGap"),0)
row.text:SetPoint("TOPRIGHT",row,"TOPRIGHT",0,0)
row.text:SetJustifyH("LEFT")
row.text:SetWordWrap(false)
A.style(row.text,"note","text")
row:Hide()
region.reading.rows[i]=row
end
region.reading:Hide()
region.plot=CreateFrame("Frame",nil,region)
region.plot:SetHeight(A.metric("plotHeight"))
region.plot:SetPoint("BOTTOMLEFT",region,"BOTTOMLEFT",0,0)
region.plot:SetPoint("BOTTOMRIGHT",region,"BOTTOMRIGHT",0,0)
region.plot.lines={}
region.plot.ticks={}
region.plot.marks={}
region.plot.mmr={}
region.plot.tickLabels={}
region.plot.dots={}
region.plotLabel=region.plot:CreateFontString(nil,"ARTWORK","GameFontDisableSmall")
region.plotLabel:SetPoint("TOPLEFT",region.plot,"TOPLEFT",0,0)
region.plotLabel:SetJustifyH("LEFT")
A.style(region.plotLabel,"label","dim")
region.plot.peakLabel=region.plot:CreateFontString(nil,"ARTWORK","GameFontDisableSmall")
region.plot.peakLabel:SetJustifyH("LEFT")
region.plot.peakLabel:SetWordWrap(false)
region.plot.endLabel=region.plot:CreateFontString(nil,"ARTWORK","GameFontDisableSmall")
region.plot.endLabel:SetJustifyH("RIGHT")
region.plot.endLabel:SetWordWrap(false)
region.plot.startDate=region.plot:CreateFontString(nil,"ARTWORK","GameFontDisableSmall")
region.plot.startDate:SetPoint("BOTTOMLEFT",region.plot,"BOTTOMLEFT",0,0)
region.plot.startDate:SetJustifyH("LEFT")
region.plot.startDate:SetWordWrap(false)
region.plot.endDate=region.plot:CreateFontString(nil,"ARTWORK","GameFontDisableSmall")
region.plot.endDate:SetPoint("BOTTOMRIGHT",region.plot,"BOTTOMRIGHT",
-A.metric("plotGutter"),0)
region.plot.endDate:SetJustifyH("RIGHT")
region.plot.endDate:SetWordWrap(false)
region.plotKeys={}
local function legendKey(after,height,kind,word)
local swatch=region.plot:CreateTexture(nil,"ARTWORK")
swatch:SetSize(KEY_SWATCH,height)
swatch:SetPoint("LEFT",after,"RIGHT",A.metric("headGap"),0)
local label=region.plot:CreateFontString(nil,"ARTWORK","GameFontDisableSmall")
label:SetPoint("LEFT",swatch,"RIGHT",KEY_GAP,0)
label:SetJustifyH("LEFT")
label:SetWordWrap(false)
label:SetText(word)
region.plotKeys[#region.plotKeys+1]={swatch=swatch,label=label,kind=kind}
return label
end
local after=legendKey(region.plotLabel,2,"rating","RATING")
legendKey(after,2,"mmr","MMR")
region.plotNote=region.plot:CreateFontString(nil,"ARTWORK","GameFontDisableSmall")
region.plotNote:SetPoint("TOPRIGHT",region.plot,"TOPRIGHT",0,0)
region.plotNote:SetJustifyH("RIGHT")
A.style(region.plotNote,"note","dimmer")
region.plotSpan=region.plot:CreateFontString(nil,"ARTWORK","GameFontDisableSmall")
region.plotSpan:SetPoint("LEFT",region.plotLabel,"RIGHT",A.metric("headGap"),0)
region.plotSpan:SetJustifyH("LEFT")
region.plotSpan:SetWordWrap(false)
A.style(region.plotSpan,"note","dimmer")
region.plotSpan:Hide()
region.controlHost=host
region.opponents={}
for i=1,OPPONENT_ROWS do
region.opponents[i]=buildOpponentRow(region.plot,i)
end
region.foughtNote=region.plot:CreateFontString(nil,"ARTWORK","GameFontDisableSmall")
region.foughtNote:SetPoint("TOPLEFT",region.opponents[OPPONENT_ROWS],"BOTTOMLEFT",0,-4)
region.foughtNote:SetPoint("TOPRIGHT",region.opponents[OPPONENT_ROWS],"BOTTOMRIGHT",0,-4)
region.foughtNote:SetJustifyH("LEFT")
region.foughtNote:SetWordWrap(true)
region.foughtNote:Hide()
A.style(region.foughtNote,"note","dimmer")
region.standing=standing.build(region)
return region
end
local function paintHeadline(region,summary)
if summary.rating~=nil then
local oneLadder=type(A.seriesSeasons)~="function"
or select(2,pcall(A.seriesSeasons,summary.series))==1
local arc=summary.ratingFrom~=nil and#summary.series>1 and oneLadder
and summary.ratingFromReset~=true
region.fromValue:SetText(arc and tostring(summary.ratingFrom)or"")
if arc then
tintRating(region.fromValue,summary.format,summary.ratingFrom,"dim")
else
setColor(region.fromValue,"dim")
end
region.link:SetText(arc and"to"or"")
setColor(region.link,"dim")
region.toValue:SetText(tostring(summary.rating))
tintRating(region.toValue,summary.format,summary.rating,"bright")
region.fromValue:SetShown(arc)
region.link:SetShown(arc)
region.toValue:ClearAllPoints()
if arc then
region.toValue:SetPoint("LEFT",region.link,"RIGHT",A.metric("headlineJoin"),1)
else
region.toValue:SetPoint("TOPLEFT",region,"TOPLEFT",0,-2)
end
region.toValue:Show()
region.delta:ClearAllPoints()
region.delta:SetPoint("TOPLEFT",arc and region.fromValue or region.toValue,
"BOTTOMLEFT",0,-4)
return
end
region.fromValue:SetText("")
region.link:SetText("")
region.toValue:SetText("")
region.fromValue:Hide()
region.link:Hide()
region.toValue:Hide()
end
local function paintDelta(region,summary)
local parts={}
local delta=A.signedText(summary.ratingChange)
if summary.rating~=nil and delta~=nil then
parts[#parts+1]=delta.." last match"
end
if summary.rating~=nil and summary.peak~=nil and summary.peak~=summary.rating then
parts[#parts+1]="peak "..ratingInline(summary.format,math.floor(summary.peak))
end
if#parts>0 then
region.delta:SetText(table.concat(parts,"   "))
local tone="dim"
if type(summary.ratingChange)=="number"then
if summary.ratingChange>0 then
tone="win"
elseif summary.ratingChange<0 then
tone="loss"
end
end
setColor(region.delta,tone)
region.delta:Show()
return
end
region.delta:Hide()
end
local function widthOf(fontString)
if not(fontString and fontString.IsShown and fontString:IsShown())then
return 0
end
local ok,width=pcall(fontString.GetStringWidth,fontString)
if not ok or type(width)~="number"then
return 0
end
return width
end
local function controlWidth(control)
if not(control and control.IsShown and control:IsShown())then
return 0
end
local ok,width=pcall(control.GetWidth,control)
if not ok or type(width)~="number"or width<=0 then
return 0
end
return width
end
local function tileOrigin(region)
local headline=widthOf(region.fromValue)
local link=widthOf(region.link)
if link>0 then
headline=headline+A.metric("headlineJoin")+link
end
local to=widthOf(region.toValue)
if to>0 then
headline=headline+A.metric("headlineJoin")+to
end
local widest=math.max(headline,widthOf(region.delta))
if widest<=0 then
return 0
end
return widest+A.metric("tileGap")
end
local function tileRoom(region,count)
if type(count)~="number"or count<1 then
return nil
end
local ok,width=pcall(region.GetWidth,region)
if not ok or type(width)~="number"or width<=0 then
return nil
end
local slots=count
return width-tileOrigin(region)-(slots-1)*A.metric("tileGap"),slots
end
function A.tileWidths(room,needs,slots)
local floor=A.metric("tileMinWidth")
local drawing=type(needs)=="table"and#needs or 0
if type(slots)~="number"or slots<drawing then
slots=drawing
end
local all={}
for i=1,slots do
local need=needs and needs[i]
if type(need)~="number"or need<floor then
need=floor
end
all[i]=need
end
local total=0
for i=1,slots do
total=total+all[i]
end
local widths={}
if type(room)~="number"or room<total then
for i=1,drawing do
widths[i]=all[i]
end
return widths,(type(room)=="number")and(total-room)or nil
end
local order={}
for i=1,slots do
order[i]=i
end
table.sort(order,function(a,b)
if all[a]==all[b]then
return a<b
end
return all[a]<all[b]
end)
local rest=total
for k=1,slots do
rest=rest-all[order[k]]
local share=(room-rest)/k
local next=(k<slots)and all[order[k+1]]or math.huge
if share<=next then
for j=1,k do
all[order[j]]=math.floor(share)
end
break
end
end
for i=1,drawing do
widths[i]=all[i]
end
return widths,0
end
local function viewRowNow(region)
local row=region.controlHost
local head=row and type(row.headWidth)=="number"and row.headWidth or 0
return A.viewRowBlocks({
head=head,
track=controlWidth(region.scope),
control=controlWidth(region.details),
toggle=controlWidth(region.graphToggle),
specs=controlWidth(region.specsToggle),
maps=controlWidth(region.mapsToggle),
builds=controlWidth(region.buildsToggle),
bests=controlWidth(region.bestsToggle),
})
end
function A.viewRowHeadRoom(region)
local width=A.listHostWidth(false)
if type(region)~="table"then
return width
end
local _,cluster=A.viewRowBlocks({
track=controlWidth(region.scope),
control=controlWidth(region.details),
toggle=controlWidth(region.graphToggle),
specs=controlWidth(region.specsToggle),
maps=controlWidth(region.mapsToggle),
builds=controlWidth(region.buildsToggle),
bests=controlWidth(region.bestsToggle),
})
return width-(type(cluster)=="number"and cluster or 0)
end
function A.noteViewRow(region)
if type(region)~="table"or type(A.notePlacedRow)~="function"then
return nil
end
local blocks=viewRowNow(region)
A.notePlacedRow("view row",blocks)
return blocks
end
function A.ratedFigures(summary)
if type(summary)~="table"or summary.rating==nil then
return nil
end
local format=summary.format
local tier=type(A.ratingTierName)=="function"and A.ratingTierName(format,summary.rating)or nil
local peakDay=nil
for _,point in ipairs(summary.series or{})do
if summary.peak~=nil and point.rating==summary.peak then
peakDay=A.shortDayText(point.at)
end
end
local cards={
{"RATING",tostring(math.floor(summary.rating)),nil,nil,nil,{beside=tier,rating=summary.rating}},
{"PEAK",summary.peak~=nil and tostring(math.floor(summary.peak))or nil,nil,nil,nil,
{beside=peakDay,rating=summary.peak}},
}
if(summary.roundsPlayed or 0)>0 and summary.roundRate~=nil then
local lost=summary.roundsPlayed-summary.roundsWon
cards[#cards+1]={"ROUNDS WON",percentText(summary.roundRate),nil,A.winRateTone(summary.roundRate),
nil,{beside=("%d-%d"):format(summary.roundsWon,lost)}}
end
local wins,losses,_,matchRate=A.winRecord(summary)
local record=A.winRecordText(summary,format)
local recordForms=nil
if record~=nil then
recordForms={record}
local pair=("%d-%d"):format(wins,losses)
if pair~=record then
recordForms[2]=pair
end
end
cards[#cards+1]={"MATCHES WON",matchRate~=nil and percentText(matchRate)or nil,nil,
A.winRateTone(matchRate),nil,{beside=record,besideForms=recordForms}}
cards[#cards+1]={"MATCHES",type(summary.matches)=="number"and tostring(summary.matches)or nil,
nil,"cardMatches",nil,
{beside=A.wholeAvgDuration(summary)~=nil and("avg %s"):format(A.clockText(summary.avgDuration))or nil}}
local gap,gapForms=A.mmrGapText(summary.mmrGap),nil
if gap~=nil then
gapForms={gap,A.mmrGapText(summary.mmrGap,nil,true)}
end
cards[#cards+1]={"MMR",summary.mmr~=nil and tostring(summary.mmr)or nil,nil,"accent",nil,
{beside=gap,besideForms=gapForms}}
return cards
end
local function paintTiles(region,summary,scopeSeason,scopeBound,stats)
local rate=select(4,A.winRecord(summary))
local winRate=percentText(rate)
local matchValue=type(summary.matches)=="number"and tostring(summary.matches)or nil
local last=type(A.lastMatchCard)=="function"
and A.lastMatchCard(summary.format,scopeSeason,A.windowCharacter(),scopeBound)or nil
local trends,asked=nil,false
local function trendFor(key)
if not asked then
asked=true
if type(A.cardTrend)=="function"then
local ok,all=pcall(A.paintWalk,"cardTrend",nil,summary.format,scopeSeason,
A.windowCharacter(),scopeBound)
trends=ok and type(all)=="table"and all or nil
end
end
return trends and trends[key]or nil
end
local rateTone=A.winRateTone(rate)
local rated=stats and A.ratedFigures(summary)or nil
local cards=rated or{
{"WIN RATE",winRate,nil,rateTone,nil,
{trend=trendFor("winRate"),trendShape="line",trendTone=rateTone}},
{"MATCHES",matchValue,nil,"cardMatches",nil,
{trend=trendFor("matches"),trendShape="bars",trendTone="cardMatches"}},
{"MMR",summary.mmr and tostring(summary.mmr)or nil,nil,"accent"},
{"AVG LENGTH",A.clockText(A.wholeAvgDuration(summary)),nil,"cardLength",nil,
{trend=trendFor("avgLength"),trendShape="line",trendTone="cardLength"}},
{"LAST MATCH",last and last.result or"-",nil,last and last.tone or nil,nil,
last and{door=true,beside=last.place,moment=last.moment,momentAbbr=last.momentAbbr,
momentShort=last.clock,id=last.id,kind=last.kind}or nil},
}
local drawing,needs=0,{}
for i=1,#cards do
if cards[i][2]~=nil then
drawing=drawing+1
needs[drawing]=A.textRoom(region.tiles[i].value,cards[i][2])+A.metric("tilePad")*2
end
end
local room,slots=tileRoom(region,drawing)
local widths,short=A.tileWidths(room,needs,slots)
region.stripRoom=A.unitFigure(room)
local blocks=A.stripRow({
where=type(A.formatLabel)=="function"and A.formatLabel(summary.format)or"this tab",
origin=tileOrigin(region),
tiles=drawing,
widths=widths,
})
local spots={}
for i=1,#blocks do
if blocks[i].kind=="tile"then
spots[#spots+1]=blocks[i]
end
end
local drawn=0
local tones={}
local asides,moment={},nil
for i=1,#cards do
local card=cards[i]
local tile=region.tiles[i]
tile:ClearAllPoints()
if setTile(tile,card[1],card[2],card[3],card[4],card[5],widths[drawn+1],
card[6])then
drawn=drawn+1
if type(card[6])=="table"and type(card[6].rating)=="number"then
tintRating(tile.value,summary.format,math.floor(card[6].rating),card[4]or"bright")
end
local tone=card[1].."="..(card[4]or"bright")
if tile.trend:IsShown()then
tone=tone.."/"..(card[6].trendTone or"dim")
end
tones[#tones+1]=tone
if tile.besideDrawn~=nil then
asides[#asides+1]=card[1].."="..tile.besideDrawn
end
if tile.momentDrawn~=nil then
moment=tile.momentDrawn
end
tile.opens=type(card[6])=="table"and card[6].door and card[6].id or nil
tile.opensKind=type(card[6])=="table"and card[6].kind or nil
local spot=spots[drawn]
tile:SetPoint("TOPLEFT",region,"TOPLEFT",spot and spot.from or 0,0)
tile.tooltipLines=A.tileTooltip(summary,card[1])
else
tile.tooltipLines=nil
tile.opens,tile.opensKind=nil,nil
end
end
for i=#cards+1,#region.tiles do
region.tiles[i]:Hide()
region.tiles[i].tooltipLines=nil
region.tiles[i].opens,region.tiles[i].opensKind=nil,nil
end
region.stripTones=#tones>0 and table.concat(tones,",")or nil
region.stripAsides=#asides>0 and table.concat(asides,";")or nil
region.stripMoment=moment
return short
end
local function setPlotNote(region,text)
region.plotNote:SetText(text or"")
region.plotNote:SetShown(text~=nil)
end
local function foughtNoteText(shown,total)
if total>shown then
return("%d more not shown"):format(total-shown)
end
return nil
end
local function plotNoteAnchor(label,legend)
if legend then
return"TOPRIGHT","RIGHT",false
end
if label then
return"TOPLEFT","LEFT",true
end
return"TOPLEFT","LEFT",false
end
function A.plotShape(branch)
return branch~="noPlot",branch=="plot"or branch=="bars"
end
function A.statsPillView(open)
open=type(open)=="table"and open or{}
for _,word in ipairs({"maps","bests","builds","specs","graph","details"})do
if open[word]then
return word
end
end
return nil
end
local function paintGraphToggle(region,summary,folded)
if not region.graphToggle then
return false
end
local foldable=seriesDrawable(summary.series)and summary.rating~=nil or barsDrawable(summary)
region.graphToggle:SetShown(foldable and true or false)
if not foldable then
return false
end
A.setPillSelected(region.graphToggle,not folded)
return true
end
local function paintDetails(region,lines,headline,collapsed)
local bands=A.summaryBands({lines=lines,headline=headline})
local controlDraws=A.bandShown(bands[1])and A.bandShown(bands[2])
if region.details then
region.details:SetShown(controlDraws and true or false)
if controlDraws then
A.setPillSelected(region.details,not collapsed)
end
end
return controlDraws
end
local function soleView(summary,lines,season,bound,region)
if type(summary)~="table"then
return nil
end
local fmt=summary.format
local offered={}
if type(region)=="table"then
for _,each in ipairs(VIEW_PILLS)do
local pill=region[each[2]]
if pill and pill:IsShown()then
offered[#offered+1]=each[1]
end
end
if#offered==1 and(offered[1]=="graph"or offered[1]=="details")then
return offered[1]
end
return nil
end
if seriesDrawable(summary.series)and summary.rating~=nil or barsDrawable(summary)then
offered[#offered+1]="graph"
end
if type(A.compRounds)=="function"and A.compRounds(fmt)then
offered[#offered+1]="specs"
end
if type(A.mapsViewOffered)=="function"and A.mapsViewOffered(fmt,season,bound)then
offered[#offered+1]="maps"
end
for _,offer in ipairs({A.bestsViewOffered,A.buildsViewOffered})do
if type(offer)=="function"and offer(fmt)then
offered[#offered+1]="table"
end
end
local bands=A.summaryBands({lines=lines,headline=summary.rating~=nil})
if A.bandShown(bands[1])and A.bandShown(bands[2])then
offered[#offered+1]="details"
end
if#offered==1 and(offered[1]=="graph"or offered[1]=="details")then
return offered[1]
end
return nil
end
function A.statsFolds(summary,lines,season,bound,collapsed,graphFolded,region)
local sole=soleView(summary,lines,season,bound,region)
if sole=="details"then
collapsed=false
elseif sole=="graph"then
graphFolded=false
end
return collapsed,graphFolded,sole
end
local function paintReading(region,summary,lines,collapsed)
local shown=#lines
if shown>READING_ROWS then
shown=READING_ROWS
end
local bands=A.summaryBands({
lines=#lines,
headline=summary.rating~=nil,
collapsed=collapsed,
})
local draws=A.bandShown(bands[1])
for i=1,READING_ROWS do
local row=region.reading.rows[i]
if draws and not collapsed and i<=shown then
row:ClearAllPoints()
row:SetPoint("TOPLEFT",region.reading,"TOPLEFT",
0,-A.metric("readingPad")-(i-1)*A.metric("readingRow"))
row:SetPoint("TOPRIGHT",region.reading,"TOPRIGHT",
0,-A.metric("readingPad")-(i-1)*A.metric("readingRow"))
row.key:SetText(lines[i].key)
row.text:SetText(lines[i].text)
A.style(row.key,"label","dim")
A.style(row.text,"note","text")
row:Show()
else
row:Hide()
end
end
region.reading.bg:SetColorTexture(A.color("panelDeep"))
return A.readingHeight(draws and shown or 0,collapsed),#lines
end
local BAR_WIDTH_CAP=12
local function barWidthFor(width,count)
if type(width)~="number"or type(count)~="number"or count<1 or width<=0 then
return nil
end
return math.max(1,math.min(BAR_WIDTH_CAP,math.floor(0.6*(width/count))))
end
local lastBarPlotWidth=nil
local function setRegionPlot(region,branch,height,format,headline,reading,lines,grow,note)
local drawing,legend=A.plotShape(branch)
local noteRow=note==false and 0 or A.noteRowHeight()
local want=type(reading)=="number"and reading or 0
if want<0 then
want=0
end
local ceiling=A.readingRoom(headline)
if want>ceiling then
want=ceiling
end
local gain=legend and A.plotGain(grow,want)or 0
local folded=branch=="folded"
local total=height
or(legend and(A.summaryHeight(headline)+gain)
or(folded and A.summaryHeightFolded(headline,want))
or A.summaryHeightNoPlot(headline,want,note))
local strip=A.stripHeight(headline)
region:SetHeight(total)
local read=want
local most=total-strip-A.metric("stripGap")-noteRow
if most<0 then
most=0
end
if read>most then
read=most
end
local plot=total-strip-A.metric("stripGap")-read
local top=strip+A.metric("stripGap")
local plotTop,readTop=top+read,top
if drawing then
plotTop,readTop=top,top+plot+A.metric("readingGap")
end
region.plot:ClearAllPoints()
region.plot:SetPoint("TOPLEFT",region,"TOPLEFT",0,-plotTop)
region.plot:SetPoint("TOPRIGHT",region,"TOPRIGHT",0,-plotTop)
region.plot:SetHeight(plot)
if read>0 then
region.reading:ClearAllPoints()
region.reading:SetPoint("TOPLEFT",region,"TOPLEFT",0,-readTop)
region.reading:SetPoint("TOPRIGHT",region,"TOPRIGHT",0,-readTop)
region.reading:SetHeight(read-A.metric("readingGap"))
region.reading:Show()
else
region.reading:Hide()
end
region.plotLabel:SetShown(drawing and true or false)
if region.plotSpan then
region.plotSpan:SetShown(folded and true or false)
end
local noteAt,noteJustify,ownLine=plotNoteAnchor(drawing,legend)
region.plotNote:ClearAllPoints()
region.plotNote:SetPoint(noteAt,region.plot,noteAt,0,0)
region.plotNote:SetJustifyH(noteJustify)
if folded then
ownLine=false
end
local drop=ownLine and A.noteRowHeight()or 0
region.plotLabel:ClearAllPoints()
region.plotLabel:SetPoint("TOPLEFT",region.plot,"TOPLEFT",0,-drop)
for i=1,#region.opponents do
local row=region.opponents[i]
local at=drop+A.metric("plotLabelDrop")+(i-1)*A.metric("opponentRow")
row:ClearAllPoints()
row:SetPoint("TOPLEFT",region.plot,"TOPLEFT",0,-at)
row:SetPoint("TOPRIGHT",region.plot,"TOPRIGHT",0,-at)
end
if type(A.trace)=="function"then
pcall(A.trace,"summary/region",{
format=format,
reason=branch,
total=total,
strip=strip,
plot=plot,
reading=read,
lines=type(lines)=="number"and lines or 0,
head=headline~=false and headline~="standing",
tiles=A.tileHeight(),
note=noteRow,
noteAt=noteAt,
short=region.stripShort,
bare=region.stripBare,
room=region.stripRoom,
tones=region.stripTones,
asides=region.stripAsides,
moment=region.stripMoment,
bars=branch=="bars"and region.barReading and region.barReading.bars or nil,
per=branch=="bars"and region.barReading and region.barReading.per or nil,
won=branch=="bars"and region.barReading and region.barReading.won or nil,
lost=branch=="bars"and region.barReading and region.barReading.lost or nil,
drawn=branch=="bars"and region.barReading and region.barReading.drawn or nil,
barWidth=branch=="bars"and region.barReading
and barWidthFor(region.plot:GetWidth(),region.barReading.bars)or nil,
},"ui")
end
end
local function paintPlotKeys(region,shown,accounted)
for i=1,#region.plotKeys do
local key=region.plotKeys[i]
local drawn=shown and(key.kind~="mmr"or accounted)
if drawn then
if key.kind=="mmr"then
key.swatch:SetColorTexture(1,1,1,A.metric("plotMmrAlpha"))
else
local r,g,b=A.color("accent")
key.swatch:SetColorTexture(r,g,b,1)
end
A.style(key.label,"note","dimmer")
end
key.swatch:SetShown(drawn and true or false)
key.label:SetShown(drawn and true or false)
end
end
local function paintBarKeys(region,shown)
if not region.barKeys then
if not shown then
return
end
region.barKeys={}
local after=region.plotLabel
for _,pair in ipairs({{"win","won"},{"loss","lost"}})do
local swatch=region.plot:CreateTexture(nil,"ARTWORK")
swatch:SetSize(KEY_SWATCH,6)
swatch:SetPoint("LEFT",after,"RIGHT",A.metric("headGap"),0)
local label=region.plot:CreateFontString(nil,"ARTWORK","GameFontDisableSmall")
label:SetPoint("LEFT",swatch,"RIGHT",KEY_GAP,0)
label:SetJustifyH("LEFT")
label:SetWordWrap(false)
label:SetText(pair[2])
region.barKeys[#region.barKeys+1]={swatch=swatch,label=label,tone=pair[1]}
after=label
end
end
for i=1,#region.barKeys do
local key=region.barKeys[i]
if shown then
local r,g,b=A.color(key.tone)
key.swatch:SetColorTexture(r,g,b,1)
A.style(key.label,"note","dimmer")
end
key.swatch:SetShown(shown and true or false)
key.label:SetShown(shown and true or false)
end
end
local function hideBars(plot,first)
for i=first or 1,#(plot.bars or{})do
local column=plot.bars[i]
column.up:Hide()
column.down:Hide()
column.hit:Hide()
end
if(first or 1)==1 then
if plot.barAxis then
plot.barAxis:Hide()
end
if plot.barStart then
plot.barStart:Hide()
plot.barEnd:Hide()
end
if plot.barScaleTop then
plot.barScaleTop:Hide()
plot.barScaleBottom:Hide()
end
plot.barPlan=nil
end
end
local function barColumn(plot,index)
plot.bars=plot.bars or{}
local column=plot.bars[index]
if not column then
column={
up=plot:CreateTexture(nil,"ARTWORK"),
down=plot:CreateTexture(nil,"ARTWORK"),
hit=CreateFrame("Frame",nil,plot),
}
column.hit:EnableMouse(true)
column.hit:SetScript("OnEnter",function(self)
local text=A.winLossHoverText(self.column)
if text and type(A.keyedTooltip)=="function"then
A.keyedTooltip(self,{text},"ANCHOR_TOP","winloss")
end
end)
column.hit:SetScript("OnLeave",function()
if type(A.hideTooltip)=="function"then
A.hideTooltip()
end
end)
plot.bars[index]=column
end
return column
end
local function drawBars(region,held)
local plot=region.plot
local columns=type(held)=="table"and held.columns or{}
local width,height=plot:GetWidth(),plot:GetHeight()
if type(width)~="number"or type(height)~="number"or#columns==0 then
hideBars(plot)
return 0
end
local foot=A.plotFoot()
local body=height-A.metric("plotLabelDrop")-foot
local half=math.floor(body/2)
if width<40 or half<2 then
hideBars(plot)
return 0
end
local axis=foot+half
local step=width/#columns
local barWidth=barWidthFor(width,#columns)or 1
local tallest=held.tallest or 0
if not plot.barAxis then
plot.barAxis=plot:CreateTexture(nil,"BORDER")
end
plot.barAxis:ClearAllPoints()
plot.barAxis:SetPoint("BOTTOMLEFT",plot,"BOTTOMLEFT",0,axis)
plot.barAxis:SetPoint("BOTTOMRIGHT",plot,"BOTTOMRIGHT",0,axis)
plot.barAxis:SetHeight(1)
plot.barAxis:SetColorTexture(A.color("hairline"))
plot.barAxis:Show()
local function length(count)
if tallest<=0 or count<=0 then
return 0
end
return math.max(1,math.floor(count/tallest*half+0.5))
end
for i=1,#columns do
local entry=columns[i]
local column=barColumn(plot,i)
local x=(i-1)*step
local inset=x+(step-barWidth)/2
local up,down=length(entry.won),length(entry.lost)
column.up:ClearAllPoints()
column.up:SetPoint("BOTTOMLEFT",plot,"BOTTOMLEFT",inset,axis)
column.up:SetSize(barWidth,math.max(up,1))
column.up:SetColorTexture(A.color("win"))
column.up:SetShown(up>0)
column.down:ClearAllPoints()
column.down:SetPoint("TOPLEFT",plot,"BOTTOMLEFT",inset,axis)
column.down:SetSize(barWidth,math.max(down,1))
column.down:SetColorTexture(A.color("loss"))
column.down:SetShown(down>0)
column.hit.column=entry
column.hit:ClearAllPoints()
column.hit:SetPoint("BOTTOMLEFT",plot,"BOTTOMLEFT",x,foot)
column.hit:SetSize(step,body)
column.hit:Show()
end
hideBars(plot,#columns+1)
if not plot.barScaleTop then
plot.barScaleTop=plot:CreateFontString(nil,"ARTWORK","GameFontDisableSmall")
plot.barScaleBottom=plot:CreateFontString(nil,"ARTWORK","GameFontDisableSmall")
for _,label in ipairs({plot.barScaleTop,plot.barScaleBottom})do
label:SetJustifyH("LEFT")
label:SetWordWrap(false)
end
end
plot.barScaleTop:ClearAllPoints()
plot.barScaleTop:SetPoint("TOPLEFT",plot,"BOTTOMLEFT",0,axis+half)
plot.barScaleBottom:ClearAllPoints()
plot.barScaleBottom:SetPoint("BOTTOMLEFT",plot,"BOTTOMLEFT",0,axis-half)
for _,label in ipairs({plot.barScaleTop,plot.barScaleBottom})do
A.style(label,"note","dimmer")
label:SetText(tostring(tallest))
label:SetShown(tallest>0)
end
if not plot.barStart then
plot.barStart=plot:CreateFontString(nil,"ARTWORK","GameFontDisableSmall")
plot.barStart:SetJustifyH("LEFT")
plot.barStart:SetWordWrap(false)
plot.barEnd=plot:CreateFontString(nil,"ARTWORK","GameFontDisableSmall")
plot.barEnd:SetWordWrap(false)
end
A.style(plot.barStart,"note","dimmer")
A.style(plot.barEnd,"note","dimmer")
local startDay,endDay=A.winLossEnds(held)
local years=date("%Y",startDay)~=date("%Y",endDay)
local startText=A.winLossDayText(startDay,years)
local endText=A.winLossDayText(endDay,years)
plot.barEnd:ClearAllPoints()
local labels
if#columns==1 then
startText,endText=nil,A.winLossDayText(startDay,false)
plot.barEnd:SetPoint("BOTTOM",plot,"BOTTOMLEFT",step/2,0)
plot.barEnd:SetJustifyH("CENTER")
else
plot.barEnd:SetPoint("BOTTOMRIGHT",plot,"BOTTOMRIGHT",0,0)
plot.barEnd:SetJustifyH("RIGHT")
local room=A.textRoom(plot.barStart,startText)+A.metric("headGap")
+A.textRoom(plot.barEnd,endText)
if room>width then
startText=nil
end
end
if startText~=nil then
plot.barStart:ClearAllPoints()
plot.barStart:SetPoint("BOTTOMLEFT",plot,"BOTTOMLEFT",0,0)
plot.barStart:SetText(startText)
plot.barStart:Show()
labels=2
else
plot.barStart:Hide()
labels=1
end
plot.barEnd:SetText(endText or"")
plot.barEnd:Show()
lastBarPlotWidth=width
plot.barPlan={axis=axis,half=half,step=step,width=barWidth,columns=#columns,
labels=labels,startText=startText,endText=endText,scale=tallest}
return#columns
end
local function headingReach(region)
if not region.plotLabel:IsShown()then
return 0
end
local reach=A.textRoom(region.plotLabel,region.plotLabel:GetText()or"")
for i=1,#region.plotKeys do
local key=region.plotKeys[i]
if key.label:IsShown()then
reach=reach+A.metric("headGap")+KEY_SWATCH+KEY_GAP
+A.textRoom(key.label,key.label:GetText()or"")
end
end
return reach
end
local function placePeakLabel(region)
local plot=region.plot
local plan=plot.peakPlan
if type(plan)~="table"then
return
end
local reach=headingReach(region)
local reason,left=plan.reason,plan.left
local gap=A.metric("headGap")
if plan.shown and plan.band and reach>0 and plan.left<reach+gap then
local slid=reach+gap
local box,other=plan.box,plan.endBox
local meetsEnd=slid<other.right and other.left<slid+plan.room
and box.bottom<other.top and other.bottom<box.top
if type(plan.limit)=="number"and slid+plan.room<=plan.limit and not meetsEnd then
plot.peakLabel:ClearAllPoints()
plot.peakLabel:SetPoint(plan.anchor,plot,"BOTTOMLEFT",slid,plan.y)
reason,left="slid",slid
else
plot.peakLabel:Hide()
reason,left="heading",nil
end
end
if type(A.trace)=="function"then
pcall(A.trace,"summary/peak",{
reason=reason,
x=A.unitFigure(plan.x),
left=left and A.unitFigure(left)or nil,
width=A.unitFigure(reach),
room=A.unitFigure(plan.room),
},"ui")
end
end
function A.paintStandingStrip(region,summary,reading)
if not(region and type(summary)=="table"and type(reading)=="table")then
return nil
end
local height=A.metric("standingStrip")
region:SetHeight(height)
local drew=standing.paint(region,reading)
standing.traceStrip(summary,reading,drew,height)
region.standingShape=type(drew)=="table"and drew.shape or nil
return drew
end
function A.paintSummaryRegion(region,summary,scope,reading)
if not(region and type(summary)=="table")then
return false
end
local notRated=type(reading)=="table"and reading.notRated or nil
local collapsed=type(reading)=="table"and reading.collapsed==true or false
local grow=A.summaryGrowth(type(reading)=="table"and reading.frameHeight or nil)
lastGrowth=grow
region.paintedScope=scope
if region.scope then
region.scope:SetShown(true)
if type(A.setDropdownChoices)=="function"and type(A.scopeChoicesFor)=="function"then
pcall(function()
A.setDropdownChoices(region.scope,A.scopeChoicesFor(summary.format),scope)
end)
end
end
paintHeadline(region,summary)
paintDelta(region,summary)
local worldStrip=type(reading)=="table"and reading.stripOnly~=true
and type(reading.standing)=="table"and type(reading.standing.hero)=="table"
and reading.standing.hero.kind=="world"
local headline=worldStrip and"standing"or(summary.rating~=nil)
local lines=A.readingLines(summary,notRated,true)
paintDetails(region,#lines,headline,collapsed)
local graphFolded=type(reading)=="table"and reading.graphFolded==true
and(seriesDrawable(summary.series)and summary.rating~=nil or barsDrawable(summary))or false
paintGraphToggle(region,summary,graphFolded)
local showMmr=A.mmrLineOffered(summary)==true
local clusterHost=region.controlHost or region
if region.specsToggle then
local rounds=type(A.compRounds)=="function"and A.compRounds(summary.format)or false
region.specsToggle:SetShown(rounds and true or false)
end
if region.mapsToggle then
local offered=type(A.mapsViewOffered)=="function"
and A.mapsViewOffered(summary.format,
type(reading)=="table"and reading.season or nil,type(reading)=="table"and reading.bound or nil)
region.mapsToggle:SetShown(offered and true or false)
end
for _,pair in ipairs({{region.bestsToggle,A.bestsViewOffered},{region.buildsToggle,A.buildsViewOffered}})do
if pair[1]then
local offered=type(pair[2])=="function"and pair[2](summary.format)or false
pair[1]:SetShown(offered and true or false)
end
end
local sole
collapsed,graphFolded,sole=A.statsFolds(summary,#lines,nil,nil,collapsed,graphFolded,region)
region.soleView=sole
if sole=="graph"and region.graphToggle then
region.graphToggle:Hide()
elseif sole=="details"and region.details then
region.details:Hide()
end
local outside=region.scope and region.scope:IsShown()and region.scope or nil
local order={}
for i=#VIEW_PILLS,1,-1 do
local pill=region[VIEW_PILLS[i][2]]
if pill and pill:IsShown()then
pill:ClearAllPoints()
if outside~=nil then
pill:SetPoint("RIGHT",outside,"LEFT",-A.metric("pillGap"),0)
else
pill:SetPoint("TOPRIGHT",clusterHost,"TOPRIGHT",0,-A.metric("segmentTrackPad"))
end
outside=pill
table.insert(order,1,VIEW_PILLS[i][1])
end
end
region.pillOrder=#order>0 and table.concat(order,",")or"none"
local tableHeld=type(A.tableViewShown)=="function"and A.tableViewShown()or nil
local view=A.statsPillView({
maps=region.mapsToggle and region.mapsToggle:IsShown()and type(A.mapsViewShown)=="function"
and A.mapsViewShown(),
bests=region.bestsToggle and region.bestsToggle:IsShown()and tableHeld=="bests",
builds=region.buildsToggle and region.buildsToggle:IsShown()and tableHeld=="builds",
specs=region.specsToggle and region.specsToggle:IsShown()and type(A.specsViewShown)=="function"
and A.specsViewShown(),
graph=region.graphToggle and region.graphToggle:IsShown()and not graphFolded,
details=region.details and region.details:IsShown()and not collapsed,
})
local selected={}
for _,each in ipairs(VIEW_PILLS)do
local pill=region[each[2]]
if pill then
A.setPillSelected(pill,each[1]==view)
if pill.controlSelected and pill:IsShown()then
selected[#selected+1]=each[1]
end
end
end
if type(A.trace)=="function"then
A.trace("statspills",{selected=#selected>0 and table.concat(selected,",")or"none",
pillView=view or"none",pillOrder=region.pillOrder,soleView=sole or"none"},"ui")
end
local short=nil
if worldStrip then
for i=1,#region.tiles do
region.tiles[i]:Hide()
region.tiles[i].tooltipLines=nil
region.tiles[i].opens,region.tiles[i].opensKind=nil,nil
end
standing.traceStrip(summary,reading.standing,standing.paint(region,reading.standing),
A.metric("standingStrip"))
else
short=paintTiles(region,summary,
type(reading)=="table"and reading.season or nil,
type(reading)=="table"and reading.bound or nil,
type(reading)=="table"and reading.stripOnly~=true)
end
region.stripShort=short
region.stripBare=nil
if type(reading)=="table"and reading.stripOnly==true and type(reading.standing)=="table"then
region.fromValue:Hide()
region.link:Hide()
region.toValue:Hide()
region.delta:Hide()
for i=1,#region.tiles do
region.tiles[i]:Hide()
region.tiles[i].tooltipLines=nil
region.tiles[i].opens,region.tiles[i].opensKind=nil,nil
end
region.reading:Hide()
region.plot:Hide()
A.paintStandingStrip(region,summary,reading.standing)
return true
end
if worldStrip then
region.standingShape="world"
else
standing.hide(region)
region.standingShape=nil
end
if type(reading)=="table"and reading.stripOnly==true then
local strip=A.stripHeight(headline)
region.reading:Hide()
region.plot:Hide()
region:SetHeight(strip)
if type(A.trace)=="function"then
pcall(A.trace,"summary/region",{
format=summary.format,
reason="strip",
total=strip,
strip=strip,
plot=0,
reading=0,
lines=#lines,
head=headline,
tiles=A.tileHeight(),
note=0,
short=region.stripShort,
bare=region.stripBare,
room=region.stripRoom,
tones=region.stripTones,
asides=region.stripAsides,
moment=region.stripMoment,
},"ui")
end
return true
end
region.plot:Show()
local readingHeight,readingCount=paintReading(region,summary,lines,collapsed)
setPlotNote(region,nil)
local branch,tally=plotBranch(summary.format,summary,graphFolded)
if branch=="fought"then
region.plotLabel:SetText("WHO WAS FOUGHT")
hideLinesFrom(region.plot,1)
hideBars(region.plot)
paintBarKeys(region,false)
region.barReading=nil
paintPlotKeys(region,false)
local shown=paintOpponents(region,tally)
local fought=foughtNoteText(shown,#tally)
region.foughtNote:SetText(fought or"")
region.foughtNote:SetShown(fought~=nil)
region.foughtNote:ClearAllPoints()
local last=region.opponents[math.max(1,math.min(shown,OPPONENT_ROWS))]
region.foughtNote:SetPoint("TOPLEFT",last,"BOTTOMLEFT",0,-4)
region.foughtNote:SetPoint("TOPRIGHT",last,"BOTTOMRIGHT",0,-4)
setRegionPlot(region,"fought",A.summaryHeightFought(shown,fought~=nil,
headline,readingHeight),summary.format,headline,
readingHeight,readingCount)
return true
end
for i=1,#region.opponents do
region.opponents[i]:Hide()
end
region.foughtNote:Hide()
region.barReading=nil
if barsDrawable(summary)then
local held=summary.winLoss
region.plotLabel:SetText("WINS AND LOSSES")
hideLinesFrom(region.plot,1)
paintPlotKeys(region,false)
if branch=="folded"then
hideBars(region.plot)
paintBarKeys(region,false)
if region.plotSpan then
local startDay,endDay=A.winLossEnds(held)
local from,to=date("%Y-%m-%d",startDay),date("%Y-%m-%d",endDay)
region.plotSpan:SetText(from==to and from or(from.." to "..to))
end
setRegionPlot(region,"folded",nil,summary.format,false,readingHeight,readingCount,
grow,false)
return true
end
region.barReading={bars=#held.columns,per=held.per,won=held.won,lost=held.lost,
drawn=held.drawn}
setRegionPlot(region,"bars",nil,summary.format,false,readingHeight,readingCount,grow,false)
drawBars(region,held)
paintBarKeys(region,true)
return true
end
hideBars(region.plot)
paintBarKeys(region,false)
region.plotLabel:SetText("RATING OVER TIME")
if branch=="folded"then
if region.plotSpan then
region.plotSpan:SetText(A.plotSpanText(summary.series)or"")
end
setRegionPlot(region,"folded",nil,summary.format,headline,readingHeight,
readingCount,grow,false)
hideLinesFrom(region.plot,1)
paintPlotKeys(region,false)
setPlotNote(region,nil)
return true
end
setRegionPlot(region,branch,nil,summary.format,
headline,readingHeight,readingCount,grow,false)
region.plot.format=summary.format
local drawn,mmrDrawn=drawSeries(region.plot,summary.series,showMmr,nil)
local tier=region.plot.tierReading
if type(tier)=="table"then
A.trace("stats-header",{format=summary.format,tiers=tier.tiers,seg=tier.seg,
reason=tier.reason,from=tier.from,tones=region.stripTones,
asides=region.stripAsides,moment=region.stripMoment},"ui")
end
local plotBands=A.summaryBands({
lines=type(readingCount)=="number"and readingCount or 0,
headline=headline,
reading=readingHeight,
plot=true,
marks=drawn,
grow=grow,
})
paintPlotKeys(region,A.bandShown(plotBands[#plotBands]),mmrDrawn>0)
placePeakLabel(region)
return true
end
local function regionLinesPinned(format)
local out={}
local shownBody=type(A.windowBodyShown)=="function"and A.windowBodyShown()or nil
local historyUp=shownBody=="history"
local function bodyLine()
if shownBody==nil then
out[#out+1]="body none on screen, so every tab's Stats regions are priced"
else
out[#out+1]=("body %s"):format(type(A.windowBodyLabel)=="function"
and A.windowBodyLabel(shownBody)or tostring(shownBody))
end
end
local function cardLines()
if type(A.askCardLines)~="function"then
return
end
local ok,said=pcall(A.askCardLines)
if ok and type(said)=="table"then
for i=1,#said do
out[#out+1]=said[i]
end
end
end
local function describe(name,fmt)
local rated=type(A.movesRating)~="function"or A.movesRating(fmt)
local oneLadder=type(A.oneLadder)~="function"or A.oneLadder(fmt)
local season,bound=nil,nil
if type(A.formatScope)=="function"then
local got,_,held,_,since=pcall(A.formatScope,fmt)
if got then
season,bound=held,since
end
end
local ok,summary=pcall(A.paintWalk,"summarize",fmt,season,A.windowCharacter(),bound)
local headline=A.statsHeadline(fmt,ok and summary or nil)
local strip=A.stripHeight(headline)
local gap=A.metric("stripGap")
local notRated
if type(A.readingContext)=="function"then
notRated=A.readingContext(fmt,season,A.windowCharacter(),bound)
end
local lines=ok and type(summary)=="table"
and A.readingLines(summary,notRated,true)or{}
local every=ok and type(summary)=="table"
and A.readingLines(summary,notRated)or{}
local collapsed,graphFolded=A.statsFolds(ok and summary or nil,#lines,season,bound,
type(A.readingCollapsed)=="function"and A.readingCollapsed()or false,
type(A.graphFolded)=="function"and A.graphFolded()or false)
local reading=A.readingHeight(#lines,collapsed)
local branch,fought=plotBranch(fmt,ok and summary or nil,graphFolded)
local drawing,legend=A.plotShape(branch)
local noteAt,_,ownLine=plotNoteAnchor(drawing,legend)
local body
local total
local plotBound
local block=(branch=="plot"or branch=="bars")and"plot"or"note"
if branch=="plot"or branch=="bars"then
local gain
gain,plotBound=A.plotGain(A.lastSummaryGrowth(),reading)
total=A.summaryHeight(true)+gain
body=total-strip-gap-reading
elseif branch=="folded"then
total=A.summaryHeightFolded(headline,reading)
body=A.plotFoldHeight()
block="fold"
elseif branch=="fought"then
local rows=#fought
if rows>OPPONENT_ROWS then
rows=OPPONENT_ROWS
end
total=A.summaryHeightFought(rows,true,false,reading)
body=total-strip-gap-reading
block="fought"
else
local noted=false
total=A.summaryHeightNoPlot(headline,reading,noted)
body=noted and A.noteRowHeight()or 0
end
local boundWords=""
if plotBound=="ceiling"then
boundWords=", the tallest the curve is drawn"
elseif plotBound=="floor"then
boundWords=", the shortest its axis reads at"
elseif plotBound=="reading"then
boundWords=", as the reading lines left it"
end
local function figure(value)
return tostring(A.unitFigure(value))
end
local barsWords=""
if branch=="bars"then
local held=summary.winLoss
local barWidth=barWidthFor(lastBarPlotWidth,#held.columns)
barsWords=(" bars=%d per=%s won=%d lost=%d drawn=%d barWidth=%s"):format(#held.columns,held.per,
held.won,held.lost,held.drawn or 0,barWidth and figure(barWidth)or"none")
elseif branch=="fought"then
barsWords=(" opponents=%d"):format(#fought)
end
out[#out+1]=("%s  total %s = strip %s + gap %s + reading %s + %s %s%s%s")
:format(name,figure(total),figure(strip),figure(gap),figure(reading),block,figure(body),
boundWords,barsWords)
out[#out+1]=("    tiles %d, headline %s, strip reserve %d, one ladder %s, season "
.."boundary %s"):format(A.tileHeight(),headline and"drawn"or"none",
strip-A.tileHeight(),oneLadder and"yes"or"no",rated and"yes"or"no")
out[#out+1]=("    note %s, scope %s")
:format(branch=="folded"and"none, the graph is folded"
or("anchors "..noteAt..(ownLine and" on its own line"or"")),
type(A.scopeText)=="function"and A.scopeText(fmt)
or(season~=nil and("season "..tostring(season))or"all time"))
local keys={}
for i=1,#lines do
keys[i]=lines[i].key
end
out[#out+1]=("    reading %d line%s%s, %s: %s")
:format(#lines,#lines==1 and""or"s",
#lines>A.readingRows()
and(" over a pool of "..tostring(A.readingRows()))or"",
collapsed and"folded"or"open",
#keys>0 and table.concat(keys,", ")or"nothing to qualify")
local drawnText={}
for i=1,#lines do
drawnText[lines[i].key.."|"..lines[i].text]=true
end
local left={}
for i=1,#every do
if not drawnText[every[i].key.."|"..every[i].text]then
left[#left+1]=every[i].key.." "..every[i].text
end
end
if#left>0 then
out[#out+1]="    not drawn: "..table.concat(left,"; ")
end
local bands=A.bandPass(A.summaryBands({
lines=#lines,
headline=headline,
collapsed=collapsed,
reading=reading,
plot=branch=="plot"or branch=="bars",
marks=1,
grow=A.lastSummaryGrowth(),
}))
local said={}
for b=1,#bands do
said[b]=("%s %s (%s)"):format(bands[b].name,
bands[b].shown and"draws"or"hidden",bands[b].reason)
end
out[#out+1]=("    details %s%s, bands %s")
:format(collapsed and"collapsed"or"open",branch=="folded"and", graph folded"or"",
table.concat(said,", "))
if type(A.listEntries)=="function"and type(A.listColumnSet)=="function"then
local okEntries,entries=pcall(A.listEntries,fmt,A.windowCharacter(),season,bound)
local okSet,set=pcall(A.listColumnSet,fmt,okEntries and entries or{})
set=okSet and set or nil
if type(set)=="table"and#set>0 then
local named={}
for c=1,#set do
named[c]=set[c].name
end
out[#out+1]=("    columns %d: %s"):format(#set,table.concat(named," "))
else
out[#out+1]="    columns none, this tab draws the joined line"
end
end
if type(A.compRounds)=="function"and A.compRounds(fmt)
and type(A.specSort)=="function"then
local key,ascending=A.specSort()
local read,rows=pcall(A.specMerged,fmt,season,A.windowCharacter(),bound)
local held=(read and type(rows)=="table")and#rows or 0
out[#out+1]=("    comps %d spec%s, sorted by %s %s, which reads %s")
:format(held,held==1 and""or"s",tostring(key),
ascending and"upward"or"downward",A.specSortWords(key,ascending))
end
if branch=="plot"and ok and type(summary)=="table"then
local width=A.windowWidth()-A.metric("margin")*2-A.metric("plotGutter")
local height=body-A.metric("plotLabelDrop")-A.plotFoot()
local lo,hi=A.plotExtent(summary.series)
local tickBound,tickRule=A.plotTicks(body)
local scale=A.plotScale(lo,hi,tickBound or A.metric("plotTickMax"))
local panels=A.seriesPanels(summary.series,width,height,
scale and scale.lo or lo,scale and scale.hi or hi)
local ticks={}
for i=1,scale and#scale.ticks or 0 do
ticks[#ticks+1]=tostring(scale.ticks[i])
end
local tickWords=#ticks>0 and table.concat(ticks," ")or"none"
if tickRule=="floor"then
tickWords="dropped, the box is under the floor"
elseif tickRule=="box"then
tickWords=tickWords..", the most the box reads"
end
out[#out+1]=("    axis %s to %s  step %s  ticks %s")
:format(tostring(scale and scale.lo or lo),tostring(scale and scale.hi or hi),
tostring(scale and scale.step or"none"),tickWords)
for p=1,#panels do
local panel=panels[p]
local mmr=A.panelMmr(summary.series,panel.first,panel.last)
local mmrSaid
if mmr.carried==0 then
mmrSaid=("no matchmaking reading on any of its %d"):format(mmr.points)
else
mmrSaid=("matchmaking on %d of %d, %d segment%s, %d at the rating itself, %d drawn apart")
:format(mmr.carried,mmr.points,mmr.segments,mmr.segments==1 and""or"s",
mmr.same,mmr.apart)
end
out[#out+1]=("    panel %d  season %s  points %d  box %.1f x %.1f  joined %s  %s")
:format(p,tostring(summary.series[panel.first].season),panel.points,
panel.width,panel.height,panel.joined and"yes"or"no",mmrSaid)
end
end
end
local function roomLine()
if type(A.lastRoomRead)~="function"then
return
end
for _,name in ipairs({"comp pane header"})do
local branch,room,at=A.lastRoomRead(name)
if branch==nil then
out[#out+1]=name.." room  no paint has read it in this session"
else
local now="no frame is held to ask again"
if type(A.roomReadNow)=="function"then
local asked,nowBranch,nowRoom=pcall(A.roomReadNow,name)
if asked and nowBranch=="unshown"then
now="not asked again, the view it is in is not on screen"
elseif asked and nowBranch~=nil then
now="asked again now, "..tostring(nowBranch)
..(type(nowRoom)=="number"and(" "..tostring(nowRoom))or"")
end
end
out[#out+1]=(name.." room  %s%s, read at %s, which is what the last paint got "
.."rather than what the rect would answer now; %s")
:format(branch,type(room)=="number"and(" "..tostring(room))or"",
tostring(at or"an unrecorded moment"),now)
end
end
for _,lines in ipairs({"viewportLines","listEdgeLines","foldControlLines"})do
if type(A[lines])=="function"then
local ok,said=pcall(A[lines])
if ok and type(said)=="table"then
for i=1,#said do
out[#out+1]=said[i]
end
end
end
end
end
if historyUp then
bodyLine()
local fmt=type(A.windowFormat)=="function"and A.windowFormat()or nil
local season,bound=nil,nil
if type(A.formatScope)=="function"then
local got,_,held,_,since=pcall(A.formatScope,fmt)
if got then
season,bound=held,since
end
end
local ok,summary=pcall(A.paintWalk,"summarize",fmt,season,A.windowCharacter(),bound)
local headline=ok and type(summary)=="table"and summary.rating~=nil or false
if type(A.standingShape)=="function"then
out[#out+1]=("%s  standing strip %s, %s tall; the reading region, the graph and the "
.."view row are on the Stats body"):format(A.formatLabel(fmt),A.standingShape(fmt),
tostring(A.metric("standingStrip")))
else
out[#out+1]=("%s  strip %s, tiles %d, headline %s; the reading region, the graph and the "
.."view row are on the Stats body"):format(A.formatLabel(fmt),
tostring(A.unitFigure(A.stripHeight(headline))),A.tileHeight(),
headline and"drawn"or"none")
end
out[#out+1]=("list rows %s tall, headings %s tall, theme %s"):format(
tostring(A.metric("rowListRow")),tostring(A.metric("rowDayRow")),A.theme())
roomLine()
return out
end
if format~=nil then
describe(A.formatLabel(format),format)
cardLines()
roomLine()
bodyLine()
return out
end
local tabs=type(A.tabList)=="function"and A.tabList(A.windowCharacter())or{}
for i=1,#tabs do
describe(tabs[i].label,tabs[i].format)
end
cardLines()
roomLine()
bodyLine()
return out
end
function A.regionLines(format)
local held=type(A.windowFrameOf)=="function"and A.windowFrameOf("matches")or nil
if type(A.withScopeClock)=="function"and type(A.withWindowWidth)=="function"then
return(A.withWindowWidth(held,function()
return(A.withScopeClock(regionLinesPinned,format))
end))
end
return regionLinesPinned(format)
end
local PANE_SETS={"round","specpair","lobby"}
local FAULT_FAMILIES={
"no heading over nothing",
"no region too short for its heading and one row",
"no band without a declared room",
"no extent split from its contents",
"no clause past its room",
"no column over an accessor nothing fills",
"no sortable column nothing orders by",
"no column set whose shares miss the room they were spread to",
"no split pane narrower than the key column it draws",
"no reading named by more than one card or by none",
"no two declared blocks overlapping",
"no block given less room than it was promised",
"no viewport ending inside one of its own rows",
"no caption contradicted by the figures under it",
}
function A.faultPaneSets()
local out={}
for i=1,#PANE_SETS do
out[i]=PANE_SETS[i]
end
return out
end
function A.faultFamilies()
local out={}
for i=1,#FAULT_FAMILIES do
out[i]=FAULT_FAMILIES[i]
end
return out
end
local function regionFaultsPinned()
local out={}
local function fault(what,where,why)
out[#out+1]=("%s  %s: %s"):format(what,where,why)
end
local tabs=type(A.tabList)=="function"and A.tabList(A.windowCharacter())or{}
for i=1,#tabs do
local fmt=tabs[i].format
local name=tabs[i].label
local season,bound
if type(A.formatScope)=="function"then
local got,_,held,_,since=pcall(A.formatScope,fmt)
if got then
season,bound=held,since
end
end
local ok,summary=pcall(A.paintWalk,"summarize",fmt,season,A.windowCharacter(),bound)
if ok and type(summary)=="table"then
local notRated
if type(A.readingContext)=="function"then
notRated=A.readingContext(fmt,season,A.windowCharacter(),bound)
end
local lines=A.readingLines(summary,notRated,true)
if#lines>A.readingRows()then
fault("clause-dropped",name,
("%d clauses over a pool of %d"):format(#lines,A.readingRows()))
end
local collapsed,graphFolded=A.statsFolds(summary,#lines,season,bound,
type(A.readingCollapsed)=="function"and A.readingCollapsed()or false,
type(A.graphFolded)=="function"and A.graphFolded()or false)
local reading=A.readingHeight(#lines,collapsed)
local headline=A.statsHeadline(fmt,summary)
local branch=plotBranch(fmt,summary,graphFolded)
for _,said in ipairs(A.bandFaults(A.summaryBands({
lines=#lines,
headline=headline,
collapsed=collapsed,
reading=reading,
plot=branch=="plot"or branch=="bars",
marks=1,
grow=A.lastSummaryGrowth(),
}),name))do
fault(said.what,said.where,said.why)
end
local room=A.windowWidth()-A.metric("margin")*2
-A.metric("readingKeyWidth")-A.metric("readingKeyGap")
for l=1,#lines do
local wide,roomAt=A.unitFigure(A.labelRoom(lines[l].text)),A.unitFigure(room)
if wide~=nil and roomAt~=nil and wide>roomAt then
fault("string-cut",name.." "..lines[l].key,
("%s units of text in %s of room"):format(tostring(wide),tostring(roomAt)))
end
end
end
if type(A.rowColumns)=="function"and type(A.columnFillers)=="function"then
local set=A.rowColumns(fmt)
if type(set)=="table"then
local said=A.columnSetUnfillable(set,A.columnFillers(fmt)or A.columnFillers(nil))
if said then
fault("column-unfilled",name,said)
end
end
end
end
if type(A.lastStripRow)=="function"and type(A.overlapFaults)=="function"then
local blocks,where=A.lastStripRow()
if type(blocks)=="table"then
for _,said in ipairs(A.overlapFaults(blocks,(where or"the").." strip"))do
fault(said.what,said.where,said.why)
end
end
end
if type(A.placedRows)=="function"and type(A.overlapFaults)=="function"then
for _,row in ipairs(A.placedRows())do
for _,said in ipairs(A.overlapFaults(row.blocks,row.where))do
fault(said.what,said.where,said.why)
end
end
end
if type(A.promisedRooms)=="function"and type(A.shortfallFaults)=="function"then
for _,said in ipairs(A.shortfallFaults(A.promisedRooms()))do
fault(said.what,said.where,said.why)
end
end
if type(A.recordedViewports)=="function"and type(A.viewportFaults)=="function"then
for _,said in ipairs(A.viewportFaults(A.recordedViewports()))do
fault(said.what,said.where,said.why)
end
end
if type(A.rowColumns)=="function"and type(A.columnFillers)=="function"then
for _,which in ipairs({"duel","unknown"})do
local set=A.rowColumns(which)
local said=A.columnSetUnfillable(set,A.columnFillers(which))
if said then
fault("column-unfilled",which.." set",said)
end
if type(A.flatRowColumns)=="function"and type(A.flatColumnFillers)=="function"then
local dark=A.columnSetUnfillable(A.flatRowColumns(which,{},false),A.flatColumnFillers())
if dark then
fault("column-unfilled",which.." dark set",dark)
end
end
end
if type(A.flatRowColumns)=="function"and type(A.flatColumnFillers)=="function"then
local dark=A.columnSetUnfillable(A.flatRowColumns("world",{},false),A.flatColumnFillers())
if dark then
fault("column-unfilled","world dark set",dark)
end
end
end
if type(A.rowColumns)=="function"then
for _,which in ipairs(A.faultPaneSets())do
local fillers=(which=="lobby")and A.lobbyFillers or A.paneFillers
if type(fillers)=="function"then
local said=A.columnSetUnfillable(A.rowColumns(which),fillers(which))
if said then
fault("column-unfilled",which.." pane set",said)
end
end
end
end
if type(A.listColumnSets)=="function"and type(A.listColumnShares)=="function"
and type(A.columnShareFaults)=="function"and type(A.listTableWidth)=="function"then
local room=A.listTableWidth()
for _,set in ipairs(A.listColumnSets())do
local spread=A.listColumnShares(set.columns)
for _,said in ipairs(A.columnShareFaults(spread,room,set.name))do
fault(said.what,said.where,said.why)
end
end
end
if type(A.rowColumns)=="function"and type(A.askFillers)=="function"
and type(A.askQuestions)=="function"then
local questions=A.askQuestions()
local room=type(A.askTableWidth)=="function"and A.askTableWidth()or nil
for i=1,#questions do
if questions[i].columns~=nil then
local which=tostring(questions[i].columns)
local columns=A.rowColumns(questions[i].columns)
local said=A.columnSetUnfillable(columns,A.askFillers())
if said then
fault("column-unfilled",which.." answer set",said)
end
local span=type(A.columnSpan)=="function"and A.unitFigure(A.columnSpan(columns))or nil
local roomAt=A.unitFigure(room)
if roomAt~=nil and roomAt>0 and span~=nil and span~=roomAt then
fault("column-share",which.." answer set",
("the four shares span %s in a pane of %s"):format(tostring(span),tostring(roomAt)))
end
for c=1,(type(columns)=="table"and#columns or 0)do
local head=A.unitFigure(A.headerFloor(columns[c].name))
local got=A.unitFigure(A.metric(columns[c].metric))
if head~=nil and head>0 and got~=nil and got<head then
fault("column-share",which.." answer set",
("%s is spread to %s, under the %s its own header needs")
:format(tostring(columns[c].name),tostring(got),tostring(head)))
end
end
end
end
end
if type(A.specGroupRuns)=="function"then
for _,group in ipairs(A.specGroupRuns())do
local run,need=A.unitFigure(group.run),A.unitFigure(group.need)
if run~=nil and need~=nil and run<need then
fault("column-share","the Specs table",
("the %s run is %s, under the %s its group label needs"):format(tostring(group.label),
tostring(run),tostring(need)))
end
end
end
if type(A.specPaneWidth)=="function"then
local pane=A.unitFigure(A.specPaneWidth())
local need=A.unitFigure(A.metric("readingKeyWidth")+A.metric("readingKeyGap"))
if pane~=nil and need~=nil and pane<need then
fault("pane-narrow","an open spec's lines",
("it is %s against the %s its own key column and gap need"):format(tostring(pane),
tostring(need)))
end
end
if type(A.rowColumns)=="function"and type(A.specSortKnown)=="function"then
for _,which in ipairs({"specpair"})do
local set=A.rowColumns(which)
if type(set)=="table"then
for i=1,#set do
if set[i].sort~=nil and not A.specSortKnown(set[i].sort)then
fault("sort-unordered",which.." pane set",
("%s sorts on %s, which nothing orders by"):format(
tostring(set[i].name),tostring(set[i].sort)))
end
end
end
end
end
if type(A.rowColumns)=="function"and type(A.lobbySortKnown)=="function"then
local set=A.rowColumns("lobby")
if type(set)=="table"then
for i=1,#set do
if set[i].sort~=nil and not A.lobbySortKnown(set[i].sort)then
fault("sort-unordered","lobby pane set",
("%s sorts on %s, which nothing orders by"):format(
tostring(set[i].name),tostring(set[i].sort)))
end
end
end
end
if type(A.rowColumns)=="function"and type(A.askSortKnown)=="function"then
for _,which in ipairs({"askBeats","askWhere","askWorth"})do
local set=A.rowColumns(which)
if type(set)=="table"then
for i=1,#set do
if set[i].sort~=nil and not A.askSortKnown(set[i].sort)then
fault("sort-unordered",which.." set",
("%s sorts on %s, which nothing orders by"):format(
tostring(set[i].name),tostring(set[i].sort)))
end
end
end
end
end
if type(A.recordedLobbyClaims)=="function"and type(A.lobbyClaimFaults)=="function"then
for _,held in ipairs(A.recordedLobbyClaims())do
for _,said in ipairs(A.lobbyClaimFaults(held.claim,held.drawn))do
fault(said.what,("match %s, %s"):format(tostring(held.id),said.where),
said.why)
end
end
end
return out
end
function A.regionFaults()
local held=type(A.windowFrameOf)=="function"and A.windowFrameOf("matches")or nil
if type(A.withScopeClock)=="function"and type(A.withWindowWidth)=="function"then
return(A.withWindowWidth(held,function()
return(A.withScopeClock(regionFaultsPinned))
end))
end
return regionFaultsPinned()
end
local OVERVIEW_PLAYED=50
local OVERVIEW_BAR=100
local OVERVIEW_RATE=96
local OVERVIEW_RATING=120
local OVERVIEW_SEASON=140
local OVERVIEW_BLOCK=8
local OVERVIEW_BLOCK_GAP=2
local OVERVIEW_RUN=20
local OVERVIEW_WEEK_MIN=6
local WEEK_BAR_CAP=24
local WEEK_LABEL_GAP=8
local OVERVIEW_CELL_MIN=14
local OVERVIEW_CHART_MIN=20
local OVERVIEW_CHART_MAX=96
local OVERVIEW_CELL_MAX=40
local function overviewText(parent,justify)
local text=parent:CreateFontString(nil,"ARTWORK","GameFontHighlightSmall")
text:SetJustifyH(justify or"LEFT")
text:SetWordWrap(false)
return text
end
local function overviewTexture(parent,layer)
return parent:CreateTexture(nil,layer or"ARTWORK")
end
function A.buildStatsOverview(frame,anchor)
local host=CreateFrame("Frame","WowPvpHistoryFrameStatsOverview",frame)
host:SetAllPoints(anchor)
host:Hide()
host.title=overviewText(host)
host.title:SetPoint("TOPLEFT",host,"TOPLEFT",A.metric("rowLabelPad"),-2)
host.record=overviewText(host)
host.record:SetPoint("TOPLEFT",host.title,"BOTTOMLEFT",0,-3)
host.head={}
for i,word in ipairs({"FORMAT","PLAYED","WON","RATING","SEASON","LAST 20, OLDEST FIRST"})do
host.head[i]=overviewText(host,i==2 and"RIGHT"or"LEFT")
host.head[i].word=word
end
host.rows={}
host.weekTitle=overviewText(host)
host.weekKey=overviewText(host)
host.weeks={}
host.axis=overviewTexture(host)
host.heatTitle=overviewText(host)
host.heatNote=overviewText(host)
host.heatHead={}
host.heatDays={}
host.cells={}
host.legendLoss=overviewText(host)
host.legendWin=overviewText(host)
frame.statsOverview=host
return host
end
local function overviewRow(host,index)
local row=host.rows[index]
if row~=nil then
return row
end
row=CreateFrame("Frame",nil,host)
row.name=overviewText(row)
row.sub=overviewText(row)
row.played=overviewText(row,"RIGHT")
row.track=overviewTexture(row,"BACKGROUND")
row.fill=overviewTexture(row)
row.mid=overviewTexture(row,"OVERLAY")
row.rate=overviewText(row)
row.rating=overviewText(row)
row.season=overviewText(row)
row.rule=overviewTexture(row,"BACKGROUND")
row.blocks={}
host.rows[index]=row
return row
end
local function overviewWeek(host,index)
local week=host.weeks[index]
if week~=nil then
return week
end
week={
up=overviewTexture(host),
down=overviewTexture(host),
won=overviewText(host,"CENTER"),
lost=overviewText(host,"CENTER"),
rate=overviewText(host,"CENTER"),
label=overviewText(host,"CENTER"),
}
host.weeks[index]=week
return week
end
local function overviewCell(host,day,block)
host.cells[day]=host.cells[day]or{}
local cell=host.cells[day][block]
if cell~=nil then
return cell
end
cell=CreateFrame("Frame",nil,host)
cell.ground=overviewTexture(cell,"BACKGROUND")
cell.ground:SetAllPoints(cell)
cell.edges={}
for i=1,4 do
cell.edges[i]=overviewTexture(cell,"BORDER")
end
cell.rate=overviewText(cell,"CENTER")
cell.rate:SetPoint("CENTER",cell,"CENTER",0,5)
cell.record=overviewText(cell,"CENTER")
cell.record:SetPoint("CENTER",cell,"CENTER",0,-6)
host.cells[day][block]=cell
return cell
end
function A.heatColour(rate)
local mr,mg,mb=A.color("heatMid")
if type(rate)~="number"then
return mr,mg,mb
end
local endName=rate>=0.5 and"heatWin"or"heatLoss"
local er,eg,eb=A.color(endName)
local t=math.min(1,math.abs(rate-0.5)*2.4)
return mr+(er-mr)*t,mg+(eg-mg)*t,mb+(eb-mb)*t
end
local function overviewTitle(season,bound)
if bound~=nil then
return"THIS RANGE, EVERY FORMAT"
end
if season~=nil then
return("SEASON %s, EVERY FORMAT"):format(tostring(season))
end
return"ALL TIME, EVERY FORMAT"
end
function A.overviewRecordText(record)
if type(record)~="table"then
return""
end
local parts={("%d %s"):format(record.matches or 0,(record.matches or 0)==1 and"match"or"matches")}
local wins,losses=record.wins or 0,record.losses or 0
local rate=select(4,A.winRecord({wins=wins,decided=wins+losses+(record.draws or 0),
draws=record.draws or 0}))
if rate~=nil then
parts[#parts+1]=("%d-%d decided, %s"):format(wins,losses,A.percentText(rate)or"-")
end
if(record.draws or 0)>0 then
parts[#parts+1]=("%d drawn"):format(record.draws)
end
return table.concat(parts,", ")
end
function A.overviewBlockFloors()
local label,note=A.fontSize("label"),A.fontSize("note")
local week=label+8+OVERVIEW_CHART_MIN+note*2+6
local days=type(A.heatDays)=="function"and#A.heatDays()or 7
local grid=label+6+note+4+days*(OVERVIEW_CELL_MIN+2)+note+6
return week,grid
end
function A.overviewBlocksFit(room)
if type(room)~="number"then
return false,false
end
local week,grid=A.overviewBlockFloors()
return room>=week,room>=grid
end
function A.overviewRatingForms(held)
if type(held)~="table"or held.rating==nil then
return{}
end
local rating=tostring(math.floor(held.rating))
if held.tier~=nil then
return{rating.." "..held.tier,rating}
end
return{rating}
end
function A.overviewRowHeight(hasSub)
local rowHeight=A.metric("rowHeight")+6
if not hasSub then
return rowHeight
end
return math.max(rowHeight,3+A.fontSize("bodyMedium")+1+A.fontSize("note")+4)
end
function A.paintStatsOverview(frame,overview,season,bound,settled)
local host=frame and frame.statsOverview
if host==nil then
return nil
end
host:Show()
if type(overview)~="table"then
overview={record={matches=0,wins=0,losses=0,draws=0},formats={},weeks={},
cells={},floor=A.rankFloor("cells")or 0}
end
local width=A.bodyWidth()
local pad=A.metric("rowLabelPad")
local label=A.fontSize("label")
host.title:SetText(overviewTitle(season,bound))
A.style(host.title,"label","dim")
host.record:SetText(A.overviewRecordText(overview.record))
A.style(host.record,"note","text")
local fixed=OVERVIEW_PLAYED+OVERVIEW_BAR+OVERVIEW_RATE+OVERVIEW_RATING+OVERVIEW_SEASON
local runRoom=OVERVIEW_RUN*(OVERVIEW_BLOCK+OVERVIEW_BLOCK_GAP)
local gap=A.metric("rowCellGap")
local nameWidth=math.max(60,width-pad*2-fixed-runRoom-gap*6)
local at={pad}
at[2]=pad+nameWidth+gap+OVERVIEW_PLAYED
at[3]=at[2]+gap
at[4]=at[3]+OVERVIEW_BAR+OVERVIEW_RATE+gap*2
at[5]=at[4]+OVERVIEW_RATING+gap
at[6]=at[5]+OVERVIEW_SEASON+gap
local headTop=-(2+label+3+A.fontSize("note")+A.metric("paneGap"))
for i=1,#host.head do
local text=host.head[i]
text:ClearAllPoints()
if i==2 then
text:SetPoint("TOPRIGHT",host,"TOPLEFT",at[2],headTop)
else
text:SetPoint("TOPLEFT",host,"TOPLEFT",at[i],headTop)
end
text:SetText(text.word)
A.style(text,"label","dim")
text:Show()
end
local top=headTop-label-4
local formats=overview.formats or{}
local track=OVERVIEW_BAR
local namesFit,tiersFit=true,true
for i=1,#formats do
local held=formats[i]
local row=overviewRow(host,i)
A.style(row.name,"bodyMedium","text")
if A.textRoom(row.name,held.label or tostring(held.format))>nameWidth then
namesFit=false
end
A.style(row.rating,"numberSmall","text")
local forms=A.overviewRatingForms(held)
if#forms>1 and A.textRoom(row.rating,forms[1])>OVERVIEW_RATING then
tiersFit=false
end
end
local rowTop=top
local heights={}
for i=1,#formats do
local held=formats[i]
local row=overviewRow(host,i)
local none=(held.played or 0)==0
local sub=""
if none then
sub=season~=nil and"none this season"or"none in this scope"
elseif(held.draws or 0)>0 then
sub=("%d drawn"):format(held.draws)
end
local rowHeight=A.overviewRowHeight(sub~="")
heights[i]=rowHeight
row:ClearAllPoints()
row:SetPoint("TOPLEFT",host,"TOPLEFT",0,rowTop)
row:SetSize(width,rowHeight)
row:Show()
rowTop=rowTop-rowHeight
row.name:ClearAllPoints()
row.name:SetPoint("TOPLEFT",row,"TOPLEFT",at[1],-3)
row.name:SetWidth(nameWidth)
row.name:SetText(namesFit and(held.label or tostring(held.format))or A.formatShortLabel(held.format))
A.style(row.name,"bodyMedium",none and"underText"or"text")
row.sub:ClearAllPoints()
row.sub:SetPoint("TOPLEFT",row.name,"BOTTOMLEFT",0,-1)
row.sub:SetText(sub)
A.style(row.sub,"note","dimmer")
row.played:ClearAllPoints()
row.played:SetPoint("TOPRIGHT",row,"TOPLEFT",at[2],-5)
row.played:SetText(none and"-"or tostring(held.played))
A.style(row.played,"numberSmall",none and"underText"or"text")
row.track:ClearAllPoints()
row.track:SetPoint("LEFT",row,"LEFT",at[3],0)
row.track:SetSize(track,8)
row.track:SetColorTexture(A.color("hover"))
row.mid:ClearAllPoints()
row.mid:SetPoint("LEFT",row,"LEFT",at[3]+math.floor(track/2),0)
row.mid:SetSize(1,12)
row.mid:SetColorTexture(A.color("barMid"))
local tone=held.rate~=nil and A.winRateTone(held.rate)or"dim"
if held.rate~=nil then
row.fill:ClearAllPoints()
row.fill:SetPoint("LEFT",row,"LEFT",at[3],0)
row.fill:SetSize(math.max(1,math.floor(track*held.rate+0.5)),8)
row.fill:SetColorTexture(A.color(tone))
row.fill:Show()
else
row.fill:Hide()
end
row.track:SetShown(not none)
row.mid:SetShown(not none)
row.rate:ClearAllPoints()
row.rate:SetPoint("LEFT",row,"LEFT",at[3]+track+A.metric("rowCellGap"),0)
row.rate:SetText(held.rate~=nil
and("%s %d-%d"):format(A.percentText(held.rate)or"-",held.wins,held.losses)or"")
A.style(row.rate,"numberSmall",tone)
row.rating:ClearAllPoints()
row.rating:SetPoint("LEFT",row,"LEFT",at[4],0)
row.rating:SetWidth(OVERVIEW_RATING)
A.style(row.rating,"numberSmall","text")
local forms=A.overviewRatingForms(held)
row.rating:SetText((tiersFit and forms[1])or forms[#forms]or"")
if held.rating~=nil then
tintRating(row.rating,held.format,math.floor(held.rating),"text")
end
row.season:ClearAllPoints()
row.season:SetPoint("LEFT",row,"LEFT",at[5],0)
row.season:SetText(A.overviewSeasonText(held))
A.style(row.season,"note","dim")
local marks=held.last or{}
for b=1,math.max(#marks,#row.blocks)do
local block=row.blocks[b]
if block==nil and b<=#marks then
block=overviewTexture(row)
row.blocks[b]=block
end
if block~=nil then
if b<=#marks then
local mark=marks[b]
block:ClearAllPoints()
block:SetPoint("LEFT",row,"LEFT",at[6]+(b-1)*(OVERVIEW_BLOCK+OVERVIEW_BLOCK_GAP),0)
block:SetSize(OVERVIEW_BLOCK,14)
block:SetColorTexture(A.color(mark=="W"and"win"or(mark=="L"and"loss"or"heatMid")))
block.mark=mark
block:Show()
else
block:Hide()
end
end
end
row.rule:ClearAllPoints()
row.rule:SetPoint("BOTTOMLEFT",row,"BOTTOMLEFT",0,0)
row.rule:SetSize(width,1)
row.rule:SetColorTexture(A.color("hover"))
end
for i=#formats+1,#host.rows do
host.rows[i]:Hide()
end
local blocksTop=rowTop-A.metric("paneGap")
local hostHeight=host:GetHeight()
local measured=type(hostHeight)=="number"and hostHeight>0
if not measured then
hostHeight=400
end
local room=hostHeight+blocksTop
local half=math.floor((width-A.metric("paneSplitGap"))/2)
local weekFits,gridFits=A.overviewBlocksFit(room)
local drew,withdrawn={},{}
local roomText=tostring(A.unitFigure and A.unitFigure(room)or math.floor(room))
if weekFits then
drew[#drew+1]="BY WEEK"
else
withdrawn[#withdrawn+1]="BY WEEK:room="..roomText
end
if gridFits then
drew[#drew+1]="WHEN YOU WIN"
else
withdrawn[#withdrawn+1]="WHEN YOU WIN:room="..roomText
end
host.weekTitle:ClearAllPoints()
host.weekTitle:SetPoint("TOPLEFT",host,"TOPLEFT",pad,blocksTop)
host.weekTitle:SetText("BY WEEK")
A.style(host.weekTitle,"label","dim")
host.weekKey:ClearAllPoints()
host.weekKey:SetPoint("TOPRIGHT",host,"TOPLEFT",half,blocksTop)
host.weekKey:SetText("won above, lost below")
A.style(host.weekKey,"note","dimmer")
local weeks=overview.weeks or{}
local tallest=0
for i=1,#weeks do
tallest=math.max(tallest,weeks[i].won,weeks[i].lost)
end
local foot=A.fontSize("note")*2+6
local chart=math.min(OVERVIEW_CHART_MAX,math.max(OVERVIEW_CHART_MIN,room-label-8-foot))
local axisY=blocksTop-label-8-math.floor(chart/2)
local column=#weeks>0 and math.max(OVERVIEW_WEEK_MIN,math.floor((half-pad)/#weeks))or 0
local barWidth=math.max(2,math.min(WEEK_BAR_CAP,math.floor(column*0.7)))
local barInset=math.floor((column-barWidth)/2)
local widestLabel=0
for i=1,#weeks do
local week=overviewWeek(host,i)
A.style(week.label,"note","dimmer")
widestLabel=math.max(widestLabel,A.textRoom(week.label,weeks[i].label))
end
local step=math.max(1,math.ceil((widestLabel+WEEK_LABEL_GAP)/math.max(1,column)))
host.axis:ClearAllPoints()
host.axis:SetPoint("TOPLEFT",host,"TOPLEFT",pad,axisY)
host.axis:SetSize(half-pad,1)
host.axis:SetColorTexture(A.color("dimmer"))
for i=1,#weeks do
local held=weeks[i]
local week=overviewWeek(host,i)
local x=pad+(i-1)*column+barInset
local scale=tallest>0 and(chart/2-2)/tallest or 0
week.up:ClearAllPoints()
week.up:SetPoint("BOTTOMLEFT",host,"TOPLEFT",x,axisY)
week.up:SetSize(barWidth,math.max(1,math.floor(held.won*scale+0.5)))
week.up:SetColorTexture(A.color("win"))
week.up:SetShown(held.won>0)
week.down:ClearAllPoints()
week.down:SetPoint("TOPLEFT",host,"TOPLEFT",x,axisY-1)
week.down:SetSize(barWidth,math.max(1,math.floor(held.lost*scale+0.5)))
week.down:SetColorTexture(A.color("loss"))
week.down:SetShown(held.lost>0)
week.won:Hide()
week.lost:Hide()
week.rate:ClearAllPoints()
week.rate:SetPoint("TOP",host,"TOPLEFT",x+barWidth/2,axisY-math.floor(chart/2)-2)
week.rate:SetText(held.rate~=nil and A.percentText(held.rate)or"")
A.style(week.rate,"note",held.rate~=nil and A.winRateTone(held.rate)or"dimmer")
local labelled=(#weeks-i)%step==0
week.label:ClearAllPoints()
week.label:SetPoint("TOP",week.rate,"BOTTOM",0,-2)
week.label:SetText(labelled and held.label or"")
A.style(week.label,"note","dimmer")
week.rate:SetShown(labelled)
week.label:SetShown(labelled)
end
for i=#weeks+1,#host.weeks do
local week=host.weeks[i]
week.up:Hide()
week.down:Hide()
week.rate:Hide()
week.label:Hide()
week.won:Hide()
week.lost:Hide()
end
local left=half+A.metric("paneSplitGap")
host.heatTitle:ClearAllPoints()
host.heatTitle:SetPoint("TOPLEFT",host,"TOPLEFT",left,blocksTop)
host.heatTitle:SetText("WHEN YOU WIN")
A.style(host.heatTitle,"label","dim")
host.heatNote:ClearAllPoints()
host.heatNote:SetPoint("TOPRIGHT",host,"TOPLEFT",width,blocksTop)
host.heatNote:SetText(("local time, %d decided or more"):format(overview.floor or 0))
A.style(host.heatNote,"note","dimmer")
local blocks=A.heatBlocks()
local days=A.heatDays()
local dayWidth=34
local cellWidth=math.max(OVERVIEW_CELL_MIN,math.floor((width-left-dayWidth)/#blocks)-2)
local gridTop=blocksTop-label-6
local legend=A.fontSize("note")+6
local cellHeight=math.min(OVERVIEW_CELL_MAX,math.max(OVERVIEW_CELL_MIN,
math.floor((room-label-6-A.fontSize("note")-4-legend)/#days)-2))
for b=1,#blocks do
local text=host.heatHead[b]or overviewText(host,"CENTER")
host.heatHead[b]=text
text:ClearAllPoints()
text:SetPoint("TOP",host,"TOPLEFT",left+dayWidth+(b-1)*(cellWidth+2)+cellWidth/2,gridTop)
text:SetText(blocks[b])
A.style(text,"note","dimmer")
text:Show()
end
local drawn,blank=0,0
local rowsTop=gridTop-A.fontSize("note")-4
for d=1,#days do
local dayText=host.heatDays[d]or overviewText(host)
host.heatDays[d]=dayText
dayText:ClearAllPoints()
dayText:SetPoint("LEFT",host,"TOPLEFT",left,rowsTop-(d-1)*(cellHeight+2)-cellHeight/2)
dayText:SetText(days[d])
A.style(dayText,"note","dim")
dayText:Show()
for b=1,#blocks do
local held=overview.cells and overview.cells[d]and overview.cells[d][b]or nil
local cell=overviewCell(host,d,b)
cell:ClearAllPoints()
cell:SetPoint("TOPLEFT",host,"TOPLEFT",left+dayWidth+(b-1)*(cellWidth+2),
rowsTop-(d-1)*(cellHeight+2))
cell:SetSize(cellWidth,cellHeight)
cell:Show()
local rate=type(held)=="table"and held.rate or nil
local won=type(held)=="table"and held.won or 0
local lost=type(held)=="table"and held.lost or 0
local rated=rate~=nil
if rate~=nil then
drawn=drawn+1
cell.ground:SetColorTexture(A.heatColour(rate))
cell.ground:Show()
cell.rate:SetText(A.percentText(rate)or"")
cell.record:SetText(("%d-%d"):format(won,lost))
A.style(cell.rate,"note","text")
A.style(cell.record,"note","dim")
for i=1,4 do
cell.edges[i]:Hide()
end
else
blank=blank+1
cell.ground:Hide()
cell.rate:SetText((type(held)=="table"and held.decided>0)and"."or"")
cell.record:SetText("")
A.style(cell.rate,"note","dimmer")
local edges={
{"TOPLEFT","TOPRIGHT",nil,1},
{"BOTTOMLEFT","BOTTOMRIGHT",nil,1},
{"TOPLEFT","BOTTOMLEFT",1,nil},
{"TOPRIGHT","BOTTOMRIGHT",1,nil},
}
for i=1,4 do
local edge=cell.edges[i]
edge:ClearAllPoints()
edge:SetPoint(edges[i][1],cell,edges[i][1],0,0)
edge:SetPoint(edges[i][2],cell,edges[i][2],0,0)
if edges[i][3]then
edge:SetWidth(edges[i][3])
else
edge:SetHeight(edges[i][4])
end
edge:SetColorTexture(A.color("heatBlank"))
edge:Show()
end
end
cell.rated=rated
end
end
local legendTop=rowsTop-#days*(cellHeight+2)-4
host.legendLoss:ClearAllPoints()
host.legendLoss:SetPoint("TOPLEFT",host,"TOPLEFT",left+dayWidth,legendTop)
host.legendLoss:SetText("lost more")
A.style(host.legendLoss,"note","loss")
host.legendWin:ClearAllPoints()
host.legendWin:SetPoint("TOPRIGHT",host,"TOPLEFT",width,legendTop)
host.legendWin:SetText("won more")
A.style(host.legendWin,"note","win")
if not weekFits then
host.weekTitle:Hide()
host.weekKey:Hide()
host.axis:Hide()
for i=1,#host.weeks do
local week=host.weeks[i]
week.up:Hide()
week.down:Hide()
week.rate:Hide()
week.label:Hide()
end
else
host.weekTitle:Show()
host.weekKey:Show()
host.axis:Show()
end
if not gridFits then
drawn,blank=0,0
host.heatTitle:Hide()
host.heatNote:Hide()
host.legendLoss:Hide()
host.legendWin:Hide()
for b=1,#host.heatHead do
host.heatHead[b]:Hide()
end
for d=1,#host.heatDays do
host.heatDays[d]:Hide()
end
for _,row in pairs(host.cells)do
for _,cell in pairs(row)do
cell:Hide()
end
end
else
host.heatTitle:Show()
host.heatNote:Show()
host.legendLoss:Show()
host.legendWin:Show()
end
local record=overview.record or{}
local heightsText={}
for i=1,#heights do
heightsText[i]=tostring(heights[i])
end
local figures={weeks=weekFits and#weeks or 0,cells=drawn,blank=blank,draws=record.draws or 0,
n=#formats,drew=table.concat(drew,","),withdrawn=table.concat(withdrawn,","),
rowHeights=table.concat(heightsText,","),nameForm=namesFit and"long"or"short",
ratingForm=tiersFit and"tier"or"rating",chart=chart,cell=cellHeight,
weekBar=weekFits and#weeks>0 and barWidth or nil,weekStep=weekFits and#weeks>0 and step or nil}
A.trace("stats-overview",{weeks=figures.weeks,cells=figures.cells,blank=figures.blank,
draws=figures.draws,n=figures.n,drew=figures.drew~=""and figures.drew or"none",
withdrawn=figures.withdrawn~=""and figures.withdrawn or nil,rowHeights=figures.rowHeights,
nameForm=figures.nameForm,ratingForm=figures.ratingForm,chart=chart,cell=cellHeight,
weekBar=figures.weekBar,weekStep=figures.weekStep,
height=measured and A.unitFigure(hostHeight)or nil},"ui")
host.figures=figures
host.paintedHeight=measured and hostHeight or nil
if not settled and type(C_Timer)=="table"and type(C_Timer.After)=="function"then
C_Timer.After(0,function()
local now=host:GetHeight()
if host:IsShown()and type(now)=="number"and now>0 and now~=host.paintedHeight then
A.paintStatsOverview(frame,overview,season,bound,true)
end
end)
end
return figures
end
function A.hideStatsOverview(frame)
if frame and frame.statsOverview then
frame.statsOverview:Hide()
end
end
