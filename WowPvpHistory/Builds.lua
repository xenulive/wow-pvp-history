-- WowPvpHistory 0.75.26
-- Author:  Xenu-Sentinels
-- Project: wow-pvp-history
--          https://github.com/xenulive/wow-pvp-history
-- License: MIT, see LICENSE
local _,A=...

local REASON_SECRET="secret"
local REASON_NO_CONFIG="no-config"
local REASON_ERROR="error"

local UNNAMED="No loadout name"

local function ask(fn,...)
	if type(fn)~="function"then
		return"absent"
	end
	local ok,value=pcall(fn,...)
	if not ok then
		return"threw"
	end
	if type(value)=="nil"then
		return"absent"
	end
	if not A.canRead(value)then
		return"secret"
	end
	return"read",value
end

local function activeSpecID()
	local info=C_SpecializationInfo
	if type(info)~="table"then
		return nil
	end
	local got,index=ask(info.GetSpecialization)
	if got~="read"or type(index)~="number"then
		return nil
	end
	local gotID,specID=ask(info.GetSpecializationInfo,index)
	if gotID~="read"or type(specID)~="number"then
		return nil
	end
	return specID
end

local function pvpTalentIDs()
	local info=C_SpecializationInfo
	local got,ids=ask(type(info)=="table"and info.GetAllSelectedPvpTalentIDs or nil)
	if got~="read"or type(ids)~="table"then
		return{}
	end
	if canaccesstable then
		local queried,accessible=pcall(canaccesstable,ids)
		if not(queried and accessible==true)then
			return{}
		end
	end
	local sized,n=pcall(function()return#ids end)
	if not sized or type(n)~="number"then
		return{}
	end
	local out={}
	for i=1,n do
		local indexed,id=pcall(A.index,ids,i)
		if indexed and A.canRead(id)and type(id)=="number"then
			out[#out+1]=id
		end
	end
	return out
end

local function notRead(reason)
	return{reason=reason},{state=reason}
end

function A.readTalents()
	local talents,traits=C_ClassTalents,C_Traits
	if type(talents)~="table"or type(traits)~="table"then
		return notRead(REASON_NO_CONFIG)
	end
	local got,configID=ask(talents.GetActiveConfigID)
	if got=="threw"then
		return notRead(REASON_ERROR)
	end
	if got=="secret"then
		return notRead(REASON_SECRET)
	end
	if got~="read"or type(configID)~="number"then
		return notRead(REASON_NO_CONFIG)
	end

	local gotString,text=ask(traits.GenerateImportString,configID)
	if gotString=="threw"then
		return notRead(REASON_ERROR)
	end
	if gotString=="secret"then
		return notRead(REASON_SECRET)
	end
	if gotString~="read"or type(text)~="string"or text==""then
		return notRead(REASON_NO_CONFIG)
	end

	local block={string=text}

	local specID=activeSpecID()
	if specID~=nil then
		local gotSaved,savedID=ask(talents.GetLastSelectedSavedConfigID,specID)
		if gotSaved=="read"and type(savedID)=="number"then
			local gotInfo,info=ask(traits.GetConfigInfo,savedID)
			if gotInfo=="read"and type(info)=="table"then
				local gotName,name=ask(A.index,info,"name")
				if gotName=="read"and type(name)=="string"and name~=""then
					block.loadout=name
				end
			end
		end
	end

	local gotHero,hero=ask(talents.GetActiveHeroTalentSpec)
	if gotHero=="read"and type(hero)=="number"then
		block.hero=hero
		local gotTree,tree=ask(traits.GetSubTreeInfo,configID,hero)
		if gotTree=="read"and type(tree)=="table"then
			local gotName,name=ask(A.index,tree,"name")
			if gotName=="read"and type(name)=="string"and name~=""then
				block.heroName=name
			end
		end
	end

	block.pvp=pvpTalentIDs()

	return block,{state="read",pvpTalents=#block.pvp,loadoutRead=block.loadout~=nil,
		heroRead=block.hero~=nil}
end

local function ownRow(record)
	return record.character and type(record.participants)=="table"
		and record.participants[record.character]or nil
end

local function ownSpec(record)
	local own=ownRow(record)
	if type(own)~="table"then
		return nil,nil
	end
	return own.spec,own.classToken,own.class
end

local function specWords(record)
	local spec,_,class=ownSpec(record)
	if type(spec)~="string"then
		return nil
	end
	return type(class)=="string"and spec.." "..class or spec
end

function A.talentsLabel(record)
	local block=type(record)=="table"and record.talents or nil
	if type(block)~="table"or type(block.string)~="string"then
		return nil,nil
	end
	local unnamed=type(block.loadout)~="string"
	local parts={unnamed and UNNAMED or block.loadout}
	if type(block.heroName)=="string"then
		parts[#parts+1]=block.heroName
	end
	return table.concat(parts,", "),unnamed
end

function A.pvpTalentInfo(id)
	if type(GetPvpTalentInfoByID)~="function"or type(id)~="number"then
		return nil,nil
	end
	local ok,_,name,icon=pcall(GetPvpTalentInfoByID,id)
	if not ok then
		return nil,nil
	end
	local named=A.canRead(name)and type(name)=="string"
	local drawn=A.canRead(icon)and(type(icon)=="number"or type(icon)=="string")
	return named and name or nil,drawn and icon or nil
end

function A.pvpTalentIcons(ids)
	local icons={}
	for _,id in ipairs(ids or{})do
		local _,icon=A.pvpTalentInfo(id)
		if icon~=nil then
			icons[#icons+1]=icon
		end
	end
	return icons
end

function A.talentsLine(record)
	local block=type(record)=="table"and record.talents or nil
	if type(block)~="table"then
		return nil
	end
	if type(block.string)~="string"then
		return("build: not read (%s)"):format(tostring(block.reason or"unknown"))
	end
	local line="build: "..A.talentsLabel(record)
	local names={}
	for _,id in ipairs(type(block.pvp)=="table"and block.pvp or{})do
		local name=A.pvpTalentInfo(id)
		names[#names+1]=name or("talent "..tostring(id))
	end
	if#names>0 then
		line=line.."; PvP talents "..table.concat(names,", ")
	end
	return line
end

function A.buildHead(record)
	local label,unnamed=A.talentsLabel(record)
	if label==nil then
		return nil
	end
	local pvp,names={},{}
	for _,id in ipairs(type(record.talents.pvp)=="table"and record.talents.pvp or{})do
		local name,icon=A.pvpTalentInfo(id)
		pvp[#pvp+1]={id=id,name=name,icon=icon}
		names[#names+1]=name or("talent "..tostring(id))
	end
	local text="BUILD  "..label
	if#names>0 then
		text=text.."  "..table.concat(names,", ")
	end
	local block=record.talents
	return{kind="build",text=text,label=label,pvp=pvp,id=record.id,unnamed=unnamed or nil,
		loadout=unnamed and UNNAMED or block.loadout,
		hero=type(block.heroName)=="string"and block.heroName or nil,spec=specWords(record)}
end

function A.talentsString(record)
	local block=type(record)=="table"and record.talents or nil
	if type(block)=="table"and type(block.string)=="string"and block.string~=""then
		return block.string
	end
	return nil
end

function A.copyTalents(id)
	local record=type(A.match)=="function"and A.match(id)or nil
	local text=A.talentsString(record)
	if text==nil then
		return false
	end
	if type(A.showCopyBox)~="function"then
		return false
	end
	return A.showCopyBox(nil,("Talents, match #%s"):format(tostring(id)),
		"Ctrl+C copies the string; paste it into the game's talent import box.",text,"talents")==true
end

function A.buildDigest(text)
	if type(text)~="string"then
		return nil
	end
	local hash=5381
	for i=1,#text do
		hash=(hash*33+text:byte(i))%4294967296
	end
	return A.hex8(hash)
end

local function stampOf(record)
	return record.openedAt or record.completedAt or record.endedAt
end

function A.recordPlayedSpec(record,spec,classToken)
	if spec==nil then
		return true
	end
	local ownSpecName,ownClass=ownSpec(record)
	return ownSpecName==spec and ownClass==classToken
end

function A.buildTally(format,season,character,bound,onlySpec,onlyClass)
	local rows,order={},{}
	local considered,before,unread=0,0,0
	local specs,specCount={},0

	local db=A.db()
	if not(db and type(db.matches)=="table")then
		return order,considered,before,unread,specCount
	end

	for i=1,#db.matches do
		local record=db.matches[i]
		local admitted=type(record)=="table"and A.recordInFormat(record,format)
			and A.buildsViewOffered(record.format)
			and(season==nil or A.recordInSeason(record,season))
			and A.recordedBy(record,character)and A.recordSince(record,bound)
			and A.recordPlayedSpec(record,onlySpec,onlyClass)
		if admitted then
			considered=considered+1
			local block=record.talents
			if type(block)~="table"then
				before=before+1
			elseif type(block.string)~="string"or block.string==""then
				unread=unread+1
			else
				local spec,classToken,class=ownSpec(record)
				local specKey=type(spec)=="string"and spec or""
				local key=specKey.."/"..A.buildDigest(block.string)
				local row=rows[key]
				if not row then
					row={key=key,string=block.string,spec=spec,classToken=classToken,class=class,
						played=0,decided=0,wins=0,draws=0,ids={}}
					rows[key]=row
					order[#order+1]=row
					local specClass=specKey.."/"..tostring(classToken or"")
					if not specs[specClass]then
						specs[specClass]=true
						specCount=specCount+1
					end
				end
				row.played=row.played+1
				if record.id~=nil then
					row.ids[#row.ids+1]=record.id
				end
				local stamp=stampOf(record)
				stamp=type(stamp)=="string"and stamp or nil
				local loadout=type(block.loadout)=="string"and block.loadout~=""and block.loadout or nil
				if loadout and(row.named==nil or(stamp~=nil and stamp>=row.named))then
					row.named=stamp or row.named
					row.loadout=loadout
				end
				local own=ownRow(record)
				local change=type(own)=="table"and not A.ladderSilent(own)and own.ratingChange or nil
				if type(change)=="number"then
					row.rating=(row.rating or 0)+change
				end
				if row.newest==nil or(stamp~=nil and stamp>=row.newest)then
					row.newest=stamp or row.newest
					row.newestID=record.id
					row.heroName=type(block.heroName)=="string"and block.heroName or nil
					local pvp={}
					for _,id in ipairs(type(block.pvp)=="table"and block.pvp or{})do
						if type(id)=="number"then
							pvp[#pvp+1]=id
						end
					end
					row.pvp=pvp
				end
				A.tallyVerdict(row,record)
			end
		end
	end

	A.rankByPlayed(order,"key")

	return order,considered,before,unread,specCount
end

function A.buildRowNames(order,mixed)
	local names,numbers={},{}
	local seen,numbered={},0
	for i=1,#order do
		local row=order[i]
		local loadout=row.loadout or UNNAMED
		local specText=type(row.spec)=="string"and A.chipText({spec=row.spec,class=row.class})or nil
		local same=table.concat({loadout,row.heroName or"",mixed and specText or""},"\n")
		seen[same]=(seen[same]or 0)+1
		local number=seen[same]>1 and seen[same]or nil
		if number then
			loadout=("%s %d"):format(loadout,number)
			numbered=numbered+1
		end
		local name=loadout
		if row.heroName then
			name=("%s, %s"):format(name,row.heroName)
		end
		if mixed and specText then
			name=("%s (%s)"):format(name,specText)
		end
		names[i],numbers[i]=name,number
	end
	return names,numbers,numbered
end

function A.buildsNote(before,unread)
	local notes={}
	if(before or 0)>0 then
		notes[#notes+1]=("%d %s from before builds were saved"):format(before,
			before==1 and"match"or"matches")
	end
	if(unread or 0)>0 then
		notes[#notes+1]=("%d %s whose build did not read"):format(unread,unread==1 and"match"or"matches")
	end
	return#notes>0 and table.concat(notes,", ")or nil
end

function A.buildsAnswer(format,season,character,bound)
	local answer={key="builds",title="Builds",columns="askBuilds",opens="PLAYED WITH",
		noun={"build","builds"}}
	local ok,order,considered,before,unread,specCount=pcall(A.buildTally,format,season,character,
		bound)
	if not ok or type(order)~="table"then
		answer.reason,answer.rows,answer.under="this couldn't be read: try /reload",{},{}
		return answer
	end
	local mixed=(specCount or 0)>1
	local rows={}
	local names,numbers,numbered=A.buildRowNames(order,mixed)
	for i=1,#order do
		local row=order[i]
		local wins,losses=A.winRecord(row)
		local name,number=names[i],numbers[i]
		local icons=A.pvpTalentIcons(row.pvp)
		rows[i]={key=row.key,name=name,met=row.played,wins=wins or 0,losses=losses or 0,
			winRate=row.winRate,ids=row.ids,spec=row.spec,number=number,
			unnamed=row.loadout==nil or nil,pvp=row.pvp or{},pvpIcons=icons}
	end
	answer.rows,answer.under=rows,{}
	answer.numbered=numbered
	answer.group=mixed and"YOUR BUILDS, BY SPEC"or"YOUR BUILDS"
	answer.considered=considered
	answer.before=before
	answer.unread=unread
	answer.specs=specCount
	answer.note=A.buildsNote(before,unread)
	if#rows==0 then
		answer.reason=((before or 0)+(unread or 0))>0 and answer.note or"no matches here yet"
	end
	return answer
end

function A.buildIconsForm(room,rows)
	local step=A.metric("rowChip")+A.metric("rowTalentGap")
	local widest,total=0,0
	for i=1,#(rows or{})do
		local icons=type(rows[i].icons)=="number"and rows[i].icons or 0
		local need=(type(rows[i].name)=="number"and rows[i].name or 0)+icons*step
		widest=math.max(widest,need)
		total=total+icons
	end
	if type(room)~="number"or room<=0 or widest>room then
		return"names",widest,0
	end
	return"icons",widest,total
end

function A.buildsViewOffered(format)
	return format~="duel"and format~="world"
end

local LOADOUT_NAME="PvPHistory Build"

local LOAD_WAIT=15

local LOAD_ERROR=0

local pendingLoad

local function importReader()
	if type(ClassTalentImportExportMixin)~="table"and type(C_AddOns)=="table"
		and type(C_AddOns.LoadAddOn)=="function"then
		pcall(C_AddOns.LoadAddOn,"Blizzard_PlayerSpells")
	end
	local mixin=ClassTalentImportExportMixin
	if type(mixin)~="table"or type(ExportUtil)~="table"
		or type(ExportUtil.MakeImportDataStream)~="function"then
		return nil
	end
	return setmetatable({},{__index=mixin})
end

local function readBuild(reader,text,specID,configID)
	local stream=ExportUtil.MakeImportDataStream(text)
	local valid,version,stringSpec,treeHash=reader:ReadLoadoutHeader(stream)
	if not valid then
		return"bad-string"
	end
	if version~=C_Traits.GetLoadoutSerializationVersion()then
		return"old-string"
	end
	if stringSpec~=specID then
		return"wrong-spec"
	end
	local treeID=C_ClassTalents.GetTraitTreeForSpec(specID)
	if type(treeID)~="number"then
		return"no-tree"
	end
	if not reader:IsHashEmpty(treeHash)and not reader:HashEquals(treeHash,C_Traits.GetTreeHash(treeID))then
		return"tree-changed"
	end
	local content=reader:ReadLoadoutContent(stream,treeID)
	return nil,reader:ConvertToImportLoadoutEntryInfo(configID,treeID,content)
end

local function loadSaved(configID,specID)
	local ok,result,changeError=pcall(C_ClassTalents.LoadConfig,configID,true)
	if not ok or result==LOAD_ERROR then
		return false,type(changeError)=="string"and changeError~=""and changeError or"load-failed"
	end
	pcall(C_ClassTalents.UpdateLastSelectedSavedConfigID,specID,configID)
	return true
end

local function importPending()
	local held=pendingLoad
	local ok,success,importError=pcall(C_ClassTalents.ImportLoadout,held.configID,held.entries,
		LOADOUT_NAME,held.text)
	if not ok or success~=true then
		pendingLoad=nil
		local said=ok and type(importError)=="string"and importError~=""and importError or"import failed"
		A.say(("The game didn't take the build: %s."):format(said))
		A.trace("build-load",{id=held.id,path="refused",reason="import-failed"},"ui")
		return"refused","import-failed"
	end
	held.state="importing"
	A.trace("build-load",{id=held.id,path="direct",state="importing",reason="none"},"ui")
	return"direct","none"
end

local function finishPending(configID)
	local held=pendingLoad
	pendingLoad=nil
	local frame=PlayerSpellsFrame
	local framed=type(frame)=="table"and type(frame.IsShown)=="function"and frame:IsShown()==true
	local loaded,said=true,nil
	if not framed then
		loaded,said=loadSaved(configID,held.specID)
	end
	if loaded then
		A.say(("Match #%s's build is the %s loadout now."):format(tostring(held.id),LOADOUT_NAME))
	else
		A.say(("The %s loadout was saved, but the game didn't switch to it: %s."):format(LOADOUT_NAME,said))
	end
	A.trace("build-load",{id=held.id,path="direct",state=framed and"frame"or(loaded and"loaded"or"error"),
		reason=loaded and"none"or"load-failed"},"ui")
end

function A.loadBuild(id)
	local record=type(A.match)=="function"and A.match(id)or nil
	local text=A.talentsString(record)
	local function refuse(reason,line)
		if line then
			A.say(line)
		end
		A.trace("build-load",{id=id,path="refused",reason=reason},"ui")
		return"refused",reason
	end
	if text==nil then
		return refuse("no-build")
	end
	if type(InCombatLockdown)=="function"and InCombatLockdown()then
		return refuse("combat","Builds can't be loaded in combat.")
	end
	if pendingLoad then
		return refuse("busy","A build is still loading.")
	end
	local talents,traits=C_ClassTalents,C_Traits
	local reader=type(talents)=="table"and type(traits)=="table"and importReader()or nil
	local specID=activeSpecID()
	local gotConfig,configID=ask(reader and talents.GetActiveConfigID or nil)
	if reader==nil or specID==nil or gotConfig~="read"or type(configID)~="number"then
		return refuse("no-import","The game's talent import isn't available right now.")
	end
	local read,refusal,entries=pcall(readBuild,reader,text,specID,configID)
	if not read then
		return refuse("bad-string","The game couldn't read this build's talent string.")
	end
	if refusal=="wrong-spec"then
		return refuse(refusal,("This build is for %s. Switch to that spec to load it."):format(
			specWords(record)or"another spec"))
	elseif refusal=="old-string"or refusal=="tree-changed"then
		return refuse(refusal,"The talent trees have changed since this match, so the game won't load its build.")
	elseif refusal~=nil then
		return refuse(refusal,"The game couldn't read this build's talent string.")
	end

	local named
	local gotIDs,ids=ask(talents.GetConfigIDsBySpecID,specID)
	for _,saved in ipairs(gotIDs=="read"and type(ids)=="table"and ids or{})do
		local gotInfo,info=ask(traits.GetConfigInfo,saved)
		local name=gotInfo=="read"and type(info)=="table"and type(info.name)=="string"and info.name or nil
		local gotString,savedText=ask(traits.GenerateImportString,saved)
		if gotString=="read"and savedText==text then
			local loaded,said=loadSaved(saved,specID)
			if not loaded then
				return refuse("load-failed",("The game didn't switch loadouts: %s."):format(said))
			end
			A.say(("Switched to the %s loadout, which holds this build."):format(name or LOADOUT_NAME))
			A.trace("build-load",{id=id,path="switched",state="loaded",reason="none"},"ui")
			return"switched","none"
		end
		if name==LOADOUT_NAME then
			named=saved
		end
	end
	if named==nil then
		local gotRoom,room=ask(talents.CanCreateNewConfig)
		if gotRoom~="read"or room~=true then
			return refuse("no-slot","Every loadout slot is taken. Delete one in the talent window to load this build.")
		end
	end

	local held={id=id,specID=specID,text=text,entries=entries,configID=configID}
	pendingLoad=held
	if C_Timer and C_Timer.After then
		C_Timer.After(LOAD_WAIT,function()
			if pendingLoad==held then
				pendingLoad=nil
				A.trace("build-load",{id=id,path="direct",state="timeout",reason="no-event"},"ui")
			end
		end)
	end
	if named==nil then
		return importPending()
	end
	held.deleting=named
	if not pcall(talents.DeleteConfig,named)then
		pendingLoad=nil
		return refuse("delete-failed",("The game didn't remove the old %s loadout."):format(LOADOUT_NAME))
	end
	A.trace("build-load",{id=id,path="direct",state="deleting",reason="none"},"ui")
	return"direct","none"
end

A.on("TRAIT_CONFIG_DELETED",function(_,configID)
	if pendingLoad and pendingLoad.deleting~=nil and pendingLoad.deleting==configID then
		pendingLoad.deleting=nil
		importPending()
	end
end)

A.on("TRAIT_CONFIG_CREATED",function(_,configInfo)
	local held=pendingLoad
	if held==nil or held.state~="importing"or type(configInfo)~="table"then
		return
	end
	local gotName,name=ask(A.index,configInfo,"name")
	local gotID,configID=ask(A.index,configInfo,"ID")
	if gotName~="read"or name~=LOADOUT_NAME or gotID~="read"or type(configID)~="number"then
		return
	end
	held.created=configID
	local gotFilled,filled=ask(C_ClassTalents.IsConfigPopulated,configID)
	if gotFilled=="read"and filled==true then
		finishPending(configID)
	end
end)

A.on("TRAIT_CONFIG_UPDATED",function(_,configID)
	if pendingLoad and pendingLoad.created~=nil and pendingLoad.created==configID then
		finishPending(configID)
	end
end)
