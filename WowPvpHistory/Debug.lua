-- WowPvpHistory 0.70.33
-- Author:  Xenu-Sentinels
-- Project: wow-pvp-history
--          https://github.com/xenulive/wow-pvp-history
-- License: MIT, see LICENSE
local _,A=...

local BOUNDS={
	capture=500,
	data=250,
	ui=125,
	error=50,
}

local BOUND_DEFAULT=125

local CATEGORY="capture"

local CATEGORIES={"capture","data","ui","error"}

local CATEGORY_SET={}
for i=1,#CATEGORIES do
	CATEGORY_SET[CATEGORIES[i]]=true
end

local BAD_CATEGORY="unknown-category"

function A.debugCategories()
	local out={}
	for i=1,#CATEGORIES do
		out[i]=CATEGORIES[i]
	end
	return out
end

function A.debugCategory(word)
	return type(word)=="string"and CATEGORY_SET[word]==true
end

local FIELDS={
	"state","restriction","rounds","rows",
	"kept",
	"duplicate",
	"keptIn",
	"skipped",
	"charsKept","charsTaken","charsBoth",
	"attempt","off",
	"format","rated","bracket","source","reason","id","n","build","version",
	"fromId",
	"season","arena",
	"ids",
	"rating","winner",
	"ratingFigure",
	"tint",
	"winnerOdd",
	"out","from","gap","mmr",
	"openedGen","currentGen",
	"noRow","noGuid","secretGuid",
	"left",
	"seg",
	"capped",
	"total","strip","plot",
	"head","tiles","note",
	"tileValues","descForm",
	"reading","lines",
	"noteAt",
	"noted",
	"carriesNote",
	"outcome","mark","carriesRating","chatEvent",
	"art","textureRead","alpha","level","levelAbove","cursorSet",
	"tinted","gripSeat","gripX","gripY",
	"named",
	"players","notes","incomplete","drops","pinned",
	"stored",
	"releaseStored",
	"evicted",
	"shown",
	"tagLines","tagCut","noteMarks",
	"readAgainst","readWith","readSummed",
	"offered",
	"found",
	"repaired",
	"folded",
	"ceiling",
	"tagged","untagged","unchanged","atCap","bots","pruned",
	"handed",
	"seat",
	"selfName",
	"selfClass","healerSeats",
	"gridOpen",
	"roundsLeft","roundsPartial",
	"mmrRead","mmrDash","mmrMulti","mmrFlat",
	"foldList",
	"list",
	"listTook","met","dossier","panel","listUp","metUp","listW","listH","metW","metH",
	"bandH","bandUp",
	"short","bare",
	"room",
	"tones",
	"ground",
	"longest","width",
	"angle",
	"wins","widget","won","refused",
	"seconds","scale","fitted",
	"atlas",
	"anchors","bounds","screen","placed","cursor","step","repaint",
	"placedScreen",
	"rect","given",
	"sizeFrom",
	"windowsReset","records","refusals",
	"windowsOpen",
	"matches",
	"fill",
	"typed","drafts",
	"shape","sides",
	"objectiveRows",
	"rowKind","ended",
	"tall","below",
	"pillsAgainst","pillsWith","pillsUnsided","linesAgainst","linesWith","linesUnsided",
	"shared","timedLines",
	"err",
	"section",
	"column",
	"sortColumn","columnDrawn","sortSlot","sortFirst",
	"viewport","panes","checks",
	"kind",
	"side",
	"placedFrom",
	"pointStored",
	"faction",
	"bytes","letters","bound",
	"theme",
	"loaded","nextId",
	"ringFrom","ringDefault",
	"target","range",
	"held","point","x","y","paused","unlocked",
	"lockdown","sources","matched","unmatched","sourcesSeen","sourcesDispels",
	"unfinished",
	"opacity",
	"regen","storeLockdown","early",
	"drag",
	"entries","text","saved",
	"route","to","via","mode","choices","tally","summary","page","options",
	"windows",
	"frame1","frame2","frame3","summaryCached","windowsSkipped","stylesSkipped","stylesApplied",
	"filters","region","view","foot","size","unbracketed","tallyCached",
	"hero",
	"losses","duels","knockout","fled","resolved","nameOnly","leftEarly","unset","others","token",
	"card","key","opened","bars","per","lost","drawn","anchor","formats",
	"groundShown",
	"check","bottom","top",
	"header","pairs","noteLine","tagLine","lastSeen",
	"terms","excluding","scoped",
	"filter","choice",
	"drew","withdrawn",
	"tiers",
	"tierRows",
	"groups","rule",
	"dock","dockFrom","move",
	"body",
	"moved",
	"roundsDropped",
	"resultDropped","resultSetAside",
	"cellsDropped",
	"fixtureDropped",
	"ladder",
	"unplaced",
	"with","against","matchWith","matchAgainst",
	"marked",
	"sort","repStep","fmt","sections",
	"sortDir","topValue","bottomValue",
	"yoursTop","theirsTop",
	"tileForms","lead","ratedPlayers","unratedPlayers","repBars",
	"search","empty",
	"last","lastFit",
	"rounded","breaks",
	"result","stripRoom",
	"metSide",
	"headRoom","headNeed","headForm",
	"heads",
	"listHead","namesRows",
	"headColor","namesColor",
	"grid","gridFold","line",
	"delta","offset","landed","first","firstAfter","content","extent","snapTo","wheelN",
	"d",
	"tries","cls","tok",
	"measured","drawnWidth","reserved",
	"roundsRoom","roundsNeed","roundsMeasured",
	"cols",
	"height","srcBottom",
	"floor","ranked","under","shownUnder","spec","class","ends",
	"weeks","cells","blank","draws",
	"weekBar","weekStep",
	"weekWidth","rangeWord",
	"viewHeight","contentHeight","contentWidth","scrollable",
	"countHidden",
	"bandSpan","graphFolded",
	"cellTexts",
	"cardDrew","dashFor",
	"heading","spanFrom","spanTo",
	"cardSet","samplesRead","samplesSkipped",
	"soleView",
	"lineScope","boxScope",
	"classColored",
	"labels","widths","rules","rate","centre","shed","edge","trend","inset","barWidth",
	"trendSlot","stripCut",
	"labelsCut","earlierLabels",
	"labelsShort","sessionNeed","sessionWidth",
	"windowScale","scaleFrom","scaled","scaleRefused","anchorsMoved","placesStored",
	"asides","moment",
	"overGap","overGapFrom",
	"chips","need","needShort",
	"rowHeights","nameForm","ratingForm","chart","cell",
	"statsView",
	"selected","pillView",
	"pillOrder",
	"numbered","rowIcons",
	"ratedRows",
	"seasonBreaks","icons","squares",
	"stripSeason",
	"stripFloor","widthFrom",
	"bodyWidth","bodyFloor",
	"record",
	"over1","over5","over10","over50","over100","over500","over1000",
	"drainMean","drainMax","samples",
	"peak","session",
	"window",
	"foldUs","newUs","foldBytes","newBytes","calls","between",
	"cardNote","cardTags","cardTagLines","cardW","cardH",
	"cardMetLast",
	"chipRight","cardRight","chipFrom","nameClass",
	"cardIndex",
	"cardNames",
	"unmet",
	"game",
	"verdict","chip","reached","markFrom","markTo","cards",
	"teamCards","classIcons","blankIcons",
	"default",
	"switch","alerts","groupNotes",
	"today","todayN","tileX","title","ruleWidth",
	"blockMid","squareMid",
	"counts","find","meter","band","slot","columns",
	"meterRoom",
	"pages","inert","word",
	"bests","firstWeek","lastWeek","dropped","undated","chars","segments","copy",
	"fontRole","created","gameFaces","ownFaces",
	"nameCut",
	"baseline",
	"cleared","hidden",
	"field","foundType","position",
	"clientEvent",
	"scopeFrom","chipRoom",
	"whereRoom","whereNeed","whenRoom",
	"honorDelta",
	"mapRead",
	"heldCount",
	"modifiers",
	"tabFrom",
	"sideFilter",
	"yielded",
	"rateClause","rateSign",
	"pvpTalents","loadoutRead","heroRead",
	"earlier","bestsSet",
	"bestCols","leftOutWins",
	"buildSpecs","beforeBuilds","unreadBuilds",
	"copyShown",
	"tabLabel","tabAsked","tabFloor","tabWidth",
	"outings","marks",
	"stripBody","barsShed",
	"chipFill","chipEdge",
	"headIcon",
	"cellOpens",
	"yoursCounted","theirsCounted",
	"selfFaction","mmr0","rating0","ratingNew0","reason0","mmr1","rating1","ratingNew1","reason1",
	"rowsYours","rowsTheirs",
	"action","count","rowKeys","hiddenRows","fromColumn","toColumn","closed",
	"fit","sameRows",
	"tab","tabs","foldedRows","lobbyRows","roundLines","scrolled",
	"picked","open","dimmed",
	"formFrom","written","healerless","pairsRead",
	"pairTally",
	"headRole",
}

function A.debugFields()
	local out={}
	for i=1,#FIELDS do
		out[i]=FIELDS[i]
	end
	return out
end

local FIELD_TYPES={}

local function typed(kinds,keys)
	local set={}
	for kind in kinds:gmatch("%a+")do
		set[kind]=true
	end
	for i=1,#keys do
		FIELD_TYPES[keys[i]]=set
	end
end

typed("number",{
	"alpha","level","gripX","gripY",
	"restriction","rounds","rows","kept","duplicate","skipped","charsKept","charsTaken","charsBoth","attempt","off","bracket","n","season",
	"arena","winner","winnerOdd","out","from","gap","mmr","noRow","noGuid","secretGuid",
	"left","seg","total","strip","plot","reading","lines","players","notes","incomplete",
	"drops","stored","shown","tagLines","tagCut","noteMarks","readAgainst","readWith",
	"readSummed","found","repaired","folded","ceiling","tagged","untagged","unchanged",
	"atCap","bots","pruned","handed","roundsLeft","roundsPartial","mmrRead","mmrDash","mmrMulti","mmrFlat","list","listW","listH",
	"metW","metH","bandH","short","room","longest","width","angle","wins","widget","won",
	"seconds","scale","fitted","step","refusals","drafts","tall","below","pillsAgainst",
	"pillsWith","pillsUnsided","linesAgainst","linesWith","linesUnsided","timedLines",
	"viewport","panes","checks","faction","bytes","letters","bound","loaded","nextId",
	"target","range","x","y","paused","sources","matched","unmatched","sourcesSeen","sourcesDispels",
	"unfinished",
	"opacity","regen","choices","tally","summary","page","options","frame1","frame2",
	"frame3","windowsSkipped","stylesSkipped","stylesApplied","filters","region","view","foot",
	"size","unbracketed","hero","losses","duels","resolved","nameOnly","leftEarly","unset",
	"others","bars","lost","bottom","top","pairs","terms","excluding","scoped","tiers",
	"moved","roundsDropped","resultDropped","resultSetAside","cellsDropped","fixtureDropped","unplaced",
	"sections","ratedPlayers","unratedPlayers","rounded","breaks","stripRoom","headRoom","headNeed","namesRows","delta","offset","landed",
	"firstAfter","content","extent","snapTo","wheelN","d","tries","measured","drawnWidth",
	"reserved","roundsRoom","roundsNeed","height","srcBottom","floor","ranked","under",
	"weeks","cells","blank","draws","weekBar","weekStep","rules","rate","centre","trend","inset","barWidth",
	"weekWidth","viewHeight","contentHeight","contentWidth",
	"trendSlot","stripCut","labelsCut","earlierLabels","labelsShort","sessionNeed","sessionWidth",
	"windowScale","scaled","scaleRefused","anchorsMoved",
	"overGap","need","needShort","chart","cell","ratedRows","seasonBreaks","icons","squares",
	"stripSeason","stripFloor","bodyWidth","bodyFloor","over1","over5","over10","over50",
	"over100","over500","over1000","drainMean","drainMax","samples","peak","session","foldUs",
	"newUs","foldBytes","newBytes","calls","between","cardTags","cardTagLines","cardW",
	"cardH","chipRight","cardRight","unmet","game","classIcons","blankIcons","todayN","tileX",
	"ruleWidth","columns","dropped","undated","chars","segments","nameCut","baseline",
	"cleared","position","scopeFrom","chipRoom","whereRoom","whereNeed","whenRoom","honorDelta","heldCount","yielded",
	"tiles","note","column","noted","drawn","ratingFigure","openedGen","currentGen",
	"placedScreen","windowsOpen","matches","windows","objectiveRows","sortSlot","first",
	"pvpTalents","earlier","bestCols","leftOutWins","buildSpecs","beforeBuilds","unreadBuilds",
	"numbered","rowIcons",
	"tabAsked","tabFloor","tabWidth","outings","marks","barsShed","cellOpens",
	"samplesRead","samplesSkipped","classColored",
	"yoursCounted","theirsCounted",
	"selfFaction","mmr0","rating0","ratingNew0","mmr1","rating1","ratingNew1","rowsYours","rowsTheirs",
	"count","fromColumn","toColumn","healerless","pairTally",
	"picked","open","dimmed","blockMid","squareMid",
	"tabs","lobbyRows","roundLines","healerSeats",
})
typed("string",{
	"state","keptIn","format","source","reason","build","version","ids","tint","noteAt",
	"releaseStored","offered","seat","selfName","gridOpen","foldList","tones","ground","refused","atlas",
	"anchors","bounds","placed","cursor","repaint","rect","given","sizeFrom","records",
	"fill","shape","section","kind","side","theme","ringFrom","ringDefault","point","drag",
	"entries","text","route","via","mode","summaryCached","tallyCached","knockout","fled",
	"token","card","key","opened","per","anchor","formats","check","header","filter",
	"choice","drew","withdrawn","tierRows","groups","rule","dock","dockFrom","move","body",
	"ladder","with","against","matchWith","matchAgainst","sort","fmt","sortDir","tileForms",
	"lead","repBars","empty","last","result","heads","listHead","headColor","namesColor",
	"grid","gridFold","line","tok","cols","spec","class","ends","cellTexts","cardDrew","dashFor",
	"heading","spanFrom","spanTo",
	"labels","widths","shed","edge","bandSpan","asides","moment","overGapFrom","chips","rowHeights",
	"nameForm","ratingForm","statsView","selected","pillView","pillOrder","widthFrom","record","window",
	"cardMetLast","chipFrom","nameClass","cardIndex","cardNames","verdict","chip",
	"switch","alerts","groupNotes","today","title","counts","find","meter","band",
	"meterRoom","pages","inert","word","bests","firstWeek","lastWeek","fontRole","gameFaces","ownFaces","field",
	"foundType","clientEvent","modifiers","tabFrom","sideFilter",
	"screen","windowsReset","sides","to","slot","tileValues","descForm","sortColumn",
	"rateSign","bestsSet","tabLabel","rangeWord","countHidden",
	"cardSet","soleView","lineScope","boxScope","scaleFrom","placesStored","stripBody","headIcon",
	"outcome","mark","chatEvent","art","gripSeat",
	"action","rowKeys","hiddenRows","fit","sameRows","tab","foldedRows",
	"reason0","reason1","formFrom","rowKind","chipFill","chipEdge","placedFrom",
	"metSide","headForm","selfClass","headRole",
})
typed("boolean",{
	"pairsRead",
	"rated","capped","head","named","pinned","evicted","listTook","met","dossier","panel",
	"listUp","metUp","bandUp","bare","typed","shared","held","unlocked","lockdown",
	"storeLockdown","saved","groundShown","noteLine","tagLine","lastSeen","marked","search",
	"lastFit","cls","roundsMeasured","shownUnder","graphFolded","cardNote","reached","cards","teamCards",
	"default","copy","created","hidden",
	"rating","carriesNote","columnDrawn","rateClause",
	"loadoutRead","heroRead","copyShown",
	"carriesRating","levelAbove","cursorSet","tinted",
	"closed","written","mapRead","ended","scrolled","scrollable","pointStored",
})
typed("number string",{
	"id","fromId","repStep","topValue","bottomValue","yoursTop","theirsTop","sortFirst",
	"markFrom","markTo",
	"textureRead",
})
typed("boolean string",{
	"early",
})

function A.debugFieldType(key)
	local set=FIELD_TYPES[key]
	if set==nil then
		return nil
	end
	local kinds={}
	for kind in pairs(set)do
		kinds[#kinds+1]=kind
	end
	table.sort(kinds)
	return table.concat(kinds," ")
end

local MISTYPED="mistyped"

local REFUSED="refused"

local reported=false

local tracing=false

local SIGNATURE_ALLOWANCE=1

function A.debugAllowance()
	return SIGNATURE_ALLOWANCE
end

local CENSUS_SHARE=0.5

function A.debugCensusShare()
	return CENSUS_SHARE
end

local memo={}

local calls={}

function A.debugCalls(cat)
	return calls[cat or CATEGORY]or 0
end

local function forget(category)
	if category==nil then
		memo={}
		return
	end
	memo[category]=nil
end

local function signature(entry)
	local parts={tostring(entry.ev)}
	for i=1,#FIELDS do
		local key=FIELDS[i]
		local value=entry[key]
		if value~=nil then
			parts[#parts+1]=key.."\1"..type(value).."\1"..tostring(value)
		end
	end
	return table.concat(parts,"\2")
end

local function refreshSettingsWindow()
	if A.refreshOptionsWindow then
		pcall(A.refreshOptionsWindow)
	end
end

local function uiState(create)
	local db=A.db()
	if not db then
		return nil
	end
	if type(db.ui)~="table"then
		if not create then
			return nil
		end
		db.ui={}
	end
	return db.ui
end

function A.debugEnabled()
	if not A.db()then
		return false
	end
	local ui=uiState(false)
	if ui~=nil and(ui.debug==true or ui.debug==false)then
		return ui.debug
	end
	return A.debugDefault==true
end

function A.debugTextEnabled()
	local ui=uiState(false)
	return ui~=nil and ui.debugText==true
end

function A.setDebug(enabled)
	local ui=uiState(true)
	if not ui then
		return false
	end
	ui.debug=enabled==true
	refreshSettingsWindow()
	if not ui.debug and type(A.storeWindowShown)=="function"and A.storeWindowShown()
		and type(A.hideStoreWindow)=="function"then
		pcall(A.hideStoreWindow)
	end
	return true
end

function A.setDebugText(enabled)
	local ui=uiState(true)
	if not ui then
		return false
	end
	if enabled==true then
		ui.debugText=true
	else
		ui.debugText=nil
	end
	A.trace("setting",{
		source="debug-text",
		state=tostring(A.debugTextEnabled()),
	},"data")
	refreshSettingsWindow()
	if type(A.refreshNotes)=="function"then
		pcall(A.refreshNotes)
	end
	if type(A.refreshWindow)=="function"then
		pcall(A.refreshWindow)
	end
	return true
end

local function store()
	local held=WowPvpHistoryDebugDB
	if type(held)~="table"then
		held={}
		WowPvpHistoryDebugDB=held
	end
	if type(held.rings)~="table"then
		held.rings={}
	end
	return held
end

local function ringFor(held,category)
	local ring=held.rings[category]
	if type(ring)~="table"then
		ring={}
		held.rings[category]=ring
	end
	if type(ring.current)~="table"then
		ring.current={}
		forget(category)
	end
	return ring
end

function A.debugStore()
	local held=WowPvpHistoryDebugDB
	if type(held)~="table"then
		return nil
	end
	return held
end

function A.debugEntries()
	local held=A.debugStore()
	if not held then
		return{}
	end

	local out={}
	local function gather(list)
		if type(list)~="table"then
			return
		end
		for i=1,#list do
			if type(list[i])=="table"then
				out[#out+1]=list[i]
			end
		end
	end

	gather(held.previous)
	gather(held.current)

	if type(held.rings)=="table"then
		for i=1,#CATEGORIES do
			local ring=held.rings[CATEGORIES[i]]
			if type(ring)=="table"then
				gather(ring.previous)
				gather(ring.current)
			end
		end
		local marked=held.rings[BAD_CATEGORY]
		if type(marked)=="table"then
			gather(marked.previous)
			gather(marked.current)
		end
	end

	table.sort(out,function(a,b)
		return(tonumber(a.seq)or 0)<(tonumber(b.seq)or 0)
	end)
	return out
end

local function latestStamp(entry)
	local latest=entry.at
	local function later(stamp)
		if type(stamp)=="string"and(type(latest)~="string"or stamp>latest)then
			latest=stamp
		end
	end
	later(entry.lastAt)
	later(entry.againAt)
	return latest
end

function A.lastRingError()
	local entries=A.debugEntries()
	local best,bestAt=nil,nil
	for i=1,#entries do
		local entry=entries[i]
		if type(entry)=="table"and entry.ev=="error"and entry.err~=nil then
			local closedAt=latestStamp(entry)
			if best==nil or(type(closedAt)=="string"and(type(bestAt)~="string"
				or closedAt>=bestAt))or(closedAt==nil and bestAt==nil)then
				best,bestAt=entry,closedAt
			end
		end
	end
	if best==nil then
		return nil
	end
	local rep=(type(best.rep)=="number"and best.rep or 1)
		+(type(best.again)=="number"and best.again or 0)
	return{
		err=best.err,
		source=best.source,
		at=best.at,
		rep=rep,
		closedAt=bestAt,
	}
end

local NAME_OPEN="[%u\192-\255]"
local NAME_BODY="[%w'\128-\255]"
local NAME_END="[%w\128-\255]"

local function identityShaped(text)
	return text:match("^%a+%-%d")~=nil or text:match("^"..NAME_OPEN..NAME_BODY.."*%-"..NAME_OPEN)~=nil
end

local ERROR_MAX=240

local ERROR_NAME="<name>"

local ERROR_GUID="<guid>"

local function scrubbed(text)
	text=text:gsub("[Pp]layer%-%d+%-%w+",ERROR_GUID)

	local part="("..NAME_OPEN..NAME_BODY.."*"..NAME_END..")"
	text=text:gsub(part.."%-"..part,ERROR_NAME)
	return text
end

local function errorText(value)
	local text=tostring(value)

	text=text:gsub("^Interface[\\/]+AddOns[\\/]+","")
	text=scrubbed(text)

	if#text>ERROR_MAX then
		text=A.byteCut(text,ERROR_MAX).."..."
	end
	return text
end

local function same(last,entry)
	if last.ev~=entry.ev then
		return false
	end
	for i=1,#FIELDS do
		local key=FIELDS[i]
		if last[key]~=entry[key]then
			return false
		end
	end
	return true
end

local function scalar(value)
	local kind=type(value)
	if kind=="number"or kind=="boolean"then
		return value
	end
	if kind~="string"then
		return nil
	end
	if identityShaped(value)then
		return REFUSED
	end
	return(scrubbed(value))
end

function A.trace(ev,fields,cat)
	if not A.debugEnabled()or tracing then
		return
	end
	tracing=true
	local counted=cat or CATEGORY
	calls[counted]=(calls[counted]or 0)+1

	local ok,err=pcall(function()
		local held=store()

		local category=CATEGORY
		if cat~=nil then
			category=A.debugCategory(cat)and cat or BAD_CATEGORY
		end

		held.seq=(tonumber(held.seq)or 0)+1
		local entry={seq=held.seq,cat=category,ev=tostring(ev)}

		local stamped,at=pcall(A.stamp)
		if stamped then
			entry.at=at
		end

		if type(fields)=="table"then
			for i=1,#FIELDS do
				local key=FIELDS[i]
				local kept
				if key=="err"then
					if fields.err~=nil then
						kept=errorText(fields.err)
					end
				else
					local value=fields[key]
					local kind=type(value)
					local kinds=FIELD_TYPES[key]
					if kinds~=nil and(kind=="number"or kind=="boolean"or kind=="string")
						and not kinds[kind]then
						kept=MISTYPED
					else
						kept=scalar(value)
					end
				end
				if kept~=nil then
					entry[key]=kept
				end
			end
		end

		local ring=ringFor(held,category)
		local list=ring.current

		local last=list[#list]
		if type(last)=="table"and same(last,entry)then
			held.seq=held.seq-1
			last.rep=(tonumber(last.rep)or 1)+1
			last.lastAt=entry.at
			return
		end

		local seen=memo[category]
		if seen==nil then
			seen={}
			memo[category]=seen
		end

		local key=signature(entry)
		local stands=seen[key]
		if stands and list[stands.index]~=stands.entry then
			stands=nil
		end

		if stands and stands.written>=SIGNATURE_ALLOWANCE then
			held.seq=held.seq-1
			stands.entry.again=(stands.entry.again or 0)+1
			if entry.at~=nil then
				stands.entry.againAt=entry.at
			end
			return
		end

		list[#list+1]=entry
		seen[key]={
			index=#list,
			entry=entry,
			written=((stands and stands.written)or 0)+1,
		}

		if#list>=(BOUNDS[category]or BOUND_DEFAULT)then
			ring.previous=list
			ring.current={}
			forget(category)
		end
	end)

	if ok then
		tracing=false
		return
	end

	pcall(function()
		A.noteError(err,"debug-ring")

		if not reported then
			reported=true
			A.say("the debug ring stopped recording: "..tostring(err)
				..". /pvph debug off silences it")
		end
	end)

	tracing=false
end

function A.traceRepairs(repairs)
	for i=1,#repairs do
		local repair=repairs[i]
		A.trace("repair",{
			field=repair.field,
			foundType=repair.foundType,
			position=repair.position,
		})
	end
end

function A.debugClear(cat)
	local held=A.debugStore()
	if not held then
		return 0
	end

	local cleared=A.debugHeld(cat)

	local marker={seq=tonumber(held.seq)or 0}
	local stamped,at=pcall(A.stamp)
	if stamped then
		marker.at=at
	end

	local function empty(ring)
		if type(ring)=="table"then
			ring.previous=nil
			ring.current={}
			ring.cleared={seq=marker.seq,at=marker.at}
		end
	end

	forget(cat)

	if cat~=nil then
		if type(held.rings)=="table"then
			empty(held.rings[cat])
		end
		local function drain(list)
			if type(list)~="table"then
				return list
			end
			local kept={}
			for i=1,#list do
				local entry=list[i]
				if type(entry)=="table"and entry.cat~=cat then
					kept[#kept+1]=entry
				end
			end
			return kept
		end
		held.previous=held.previous and drain(held.previous)or nil
		held.current=drain(held.current)
		return cleared
	end

	held.previous=nil
	held.current={}
	if type(held.rings)=="table"then
		for i=1,#CATEGORIES do
			empty(held.rings[CATEGORIES[i]])
		end
		empty(held.rings[BAD_CATEGORY])
	end
	return cleared
end

function A.debugIsolated(fn)
	local held,keptMemo,keptCalls=WowPvpHistoryDebugDB,memo,calls
	local aside={rings={}}
	WowPvpHistoryDebugDB=aside
	memo={}
	calls={}
	local ok,a,b=pcall(fn)
	WowPvpHistoryDebugDB,memo,calls=held,keptMemo,keptCalls
	if not ok then
		error(a,0)
	end
	return aside,a,b
end

local function number(value)
	if value%1==0 then
		return("%d"):format(value)
	end
	local text=("%.6f"):format(value):gsub("0+$","")
	if text:sub(-1)=="."then
		return text.."0"
	end
	return text
end
A.ringNumber=number

function A.debugLine(entry)
	local parts={}
	for i=1,#FIELDS do
		local key=FIELDS[i]
		local value=entry[key]
		if value~=nil then
			if type(value)=="number"then
				value=number(value)
			else
				value=tostring(value)
			end
			parts[#parts+1]=key.."="..value
		end
	end

	local line=("#%s %s %s/%s"):format(tostring(entry.seq),tostring(entry.at),
		tostring(entry.cat),tostring(entry.ev))

	if type(entry.rep)=="number"and entry.rep>1 then
		line=line..(" x%d"):format(entry.rep)
		if entry.lastAt~=nil then
			line=line.." to "..tostring(entry.lastAt)
		end
	end

	if type(entry.again)=="number"and entry.again>0 then
		line=line..(" again%d"):format(entry.again)
		if entry.againAt~=nil then
			line=line.." last "..tostring(entry.againAt)
		end
	end

	if#parts>0 then
		line=line.." "..table.concat(parts," ")
	end
	return line
end

local function filtered(cat)
	local entries=A.debugEntries()
	if cat==nil then
		return entries
	end

	local kept={}
	for i=1,#entries do
		if entries[i].cat==cat then
			kept[#kept+1]=entries[i]
		end
	end
	return kept
end

function A.debugHeld(cat)
	return#filtered(cat)
end

function A.debugCensus()
	local out={}
	for i=1,#CATEGORIES do
		local name=CATEGORIES[i]
		local entries=filtered(name)

		local counts,top={},nil
		for j=1,#entries do
			local ev=tostring(entries[j].ev)
			counts[ev]=(counts[ev]or 0)+1
			if top==nil or counts[ev]>counts[top]then
				top=ev
			end
		end

		out[i]={
			cat=name,
			held=#entries,
			bound=(BOUNDS[name]or BOUND_DEFAULT)*2,
			top=top,
			topHeld=top and counts[top]or 0,
			names=top~=nil and#entries>0 and(counts[top]/#entries)>CENSUS_SHARE or false,
		}
	end
	return out
end

function A.debugCensusLine()
	local census=A.debugCensus()
	local parts={}
	for i=1,#census do
		local row=census[i]
		parts[i]=("%s %d/%d"):format(row.cat,row.held,row.bound)
		if row.names then
			parts[i]=parts[i]..(" %s %d"):format(row.top,row.topHeld)
		end
	end
	return table.concat(parts,", ")
end

function A.debugLines(limit,cat)
	local entries=filtered(cat)

	if type(limit)=="number"then
		limit=math.floor(limit)
	end
	local from=1
	if type(limit)=="number"and limit>0 and#entries>limit then
		from=#entries-limit+1
	end

	local lines={}
	for i=from,#entries do
		lines[#lines+1]=A.debugLine(entries[i])
	end
	return lines
end

local EXPORT_PREFIX="WPHD!1!"

function A.debugExport()
	local lines=A.debugLines()
	if#lines==0 then
		return nil,"the debug ring holds nothing"
	end
	return EXPORT_PREFIX..table.concat(lines," | "),nil,#lines
end

function A.openDebugExport()
	local said,say=A.chatCollector()

	local text,why,entries=A.debugExport()
	if not text then
		say("debug export: "..tostring(why))
		return false,said
	end

	say(("debug export is %d characters, holding %d %s")
		:format(#text,entries,entries==1 and"entry"or"entries"))

	if not A.showTransfer("PvP history debug ring",
			"Ctrl+C copies it. There is no import: this describes one character's sessions.",
			text,nil,nil)then
		say("the copy window could not be opened, so the ring cannot be reached from here")
		return false,said
	end

	return true,said
end

A.on("PLAYER_LOGIN",function()
	local version,build
	local ok,one,two=pcall(GetBuildInfo)
	if ok then
		version,build=one,two
	end

	local db=A.db()
	local held=db and type(db.matches)=="table"and#db.matches or nil

	local ui=uiState(false)
	local stored=ui~=nil and(ui.debug==true or ui.debug==false)

	A.trace("session",{
		version=A.version,
		build=(version and build)and(version.."."..build)or build,
		loaded=held,
		nextId=db and db.nextMatchId or nil,
		ringFrom=stored and"stored"or"default",
		ringDefault=A.debugDefault and"on"or"off",
	})

	if type(A.traceRefusedEvents)=="function"then
		A.traceRefusedEvents()
	end

	local repairs=type(A.loadRepairs)=="function"and A.loadRepairs()or{}
	A.traceRepairs(repairs)
end)
