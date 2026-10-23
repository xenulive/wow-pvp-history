-- WowPvpHistory 0.70.7
-- Author:  Xenu-Sentinels
-- Project: wow-pvp-history
--          https://github.com/xenulive/wow-pvp-history
-- License: MIT, see LICENSE
local _,A=...

local canaccesstable=canaccesstable

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

function A.readTalents()
	local talents,traits=C_ClassTalents,C_Traits
	if type(talents)~="table"or type(traits)~="table"then
		return{reason=REASON_NO_CONFIG},{state=REASON_NO_CONFIG}
	end
	local got,configID=ask(talents.GetActiveConfigID)
	if got=="threw"then
		return{reason=REASON_ERROR},{state=REASON_ERROR}
	end
	if got=="secret"then
		return{reason=REASON_SECRET},{state=REASON_SECRET}
	end
	if got~="read"or type(configID)~="number"then
		return{reason=REASON_NO_CONFIG},{state=REASON_NO_CONFIG}
	end

	local gotString,text=ask(traits.GenerateImportString,configID)
	if gotString=="threw"then
		return{reason=REASON_ERROR},{state=REASON_ERROR}
	end
	if gotString=="secret"then
		return{reason=REASON_SECRET},{state=REASON_SECRET}
	end
	if gotString~="read"or type(text)~="string"or text==""then
		return{reason=REASON_NO_CONFIG},{state=REASON_NO_CONFIG}
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
	return{kind="build",text=text,label=label,pvp=pvp,id=record.id,unnamed=unnamed or nil}
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

local function ownSpec(record)
	local own=record.character and type(record.participants)=="table"
		and record.participants[record.character]or nil
	if type(own)~="table"then
		return nil,nil
	end
	return own.spec,own.classToken
end

function A.buildDigest(text)
	if type(text)~="string"then
		return nil
	end
	local hash=5381
	for i=1,#text do
		hash=(hash*33+text:byte(i))%4294967296
	end
	return("%08x"):format(hash)
end

local function stampOf(record)
	return record.openedAt or record.completedAt or record.endedAt
end

function A.buildTally(format,season,character,bound)
	local rows,order={},{}
	local considered,before,unread=0,0,0
	local specs,specCount={},0

	local db=A.db()
	if not(db and type(db.matches)=="table")then
		return order,considered,before,unread,specCount
	end

	for i=1,#db.matches do
		local record=db.matches[i]
		local admitted=type(record)=="table"and(format==nil or record.format==format)
			and A.buildsViewOffered(record.format)
			and(season==nil or A.recordSeason(record)==season)
			and A.recordedBy(record,character)and A.recordSince(record,bound)
		if admitted then
			considered=considered+1
			local block=record.talents
			if type(block)~="table"then
				before=before+1
			elseif type(block.string)~="string"or block.string==""then
				unread=unread+1
			else
				local spec,classToken=ownSpec(record)
				local specKey=type(spec)=="string"and spec or""
				local key=specKey.."/"..A.buildDigest(block.string)
				local row=rows[key]
				if not row then
					row={key=key,string=block.string,spec=spec,classToken=classToken,
						played=0,decided=0,wins=0,draws=0,ids={}}
					rows[key]=row
					order[#order+1]=row
					if not specs[specKey]then
						specs[specKey]=true
						specCount=specCount+1
					end
				end
				row.played=row.played+1
				if record.id~=nil then
					row.ids[#row.ids+1]=record.id
				end
				local stamp=stampOf(record)
				if row.newest==nil or(type(stamp)=="string"and stamp>=row.newest)then
					row.newest=type(stamp)=="string"and stamp or row.newest
					row.loadout=type(block.loadout)=="string"and block.loadout or nil
					row.heroName=type(block.heroName)=="string"and block.heroName or nil
					local pvp={}
					for _,id in ipairs(type(block.pvp)=="table"and block.pvp or{})do
						if type(id)=="number"then
							pvp[#pvp+1]=id
						end
					end
					row.pvp=pvp
				end
				local outcome,_,derived=A.recordVerdict(record)
				if outcome~=nil then
					row.decided=row.decided+1
					if outcome=="win"then
						row.wins=row.wins+1
					elseif A.recordLevel(record,outcome,derived)then
						row.draws=row.draws+1
					end
				end
			end
		end
	end

	for i=1,#order do
		local row=order[i]
		row.winRate=select(4,A.winRecord(row))
	end

	table.sort(order,function(a,b)
		if a.played~=b.played then
			return a.played>b.played
		end
		return a.key<b.key
	end)

	return order,considered,before,unread,specCount
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
	local seen,numbered={},0
	for i=1,#order do
		local row=order[i]
		local wins,losses=A.winRecord(row)
		local loadout=row.loadout or UNNAMED
		local same=table.concat({loadout,row.heroName or"",mixed and tostring(row.spec or"")or""},"\n")
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
		if mixed and type(row.spec)=="string"then
			name=("%s (%s)"):format(name,row.spec)
		end
		local icons={}
		for _,id in ipairs(row.pvp or{})do
			local _,icon=A.pvpTalentInfo(id)
			if icon~=nil then
				icons[#icons+1]=icon
			end
		end
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
	local notes={}
	if(before or 0)>0 then
		notes[#notes+1]=("%d %s from before builds were saved"):format(before,
			before==1 and"match"or"matches")
	end
	if(unread or 0)>0 then
		notes[#notes+1]=("%d %s whose build did not read"):format(unread,unread==1 and"match"or"matches")
	end
	answer.note=#notes>0 and table.concat(notes,", ")or nil
	if#rows==0 then
		answer.reason=(before or 0)>0 and answer.note or"no matches here yet"
	end
	return answer
end

function A.buildIconsForm(room,rows)
	local step=A.metric("rowTalentIcon")+A.metric("rowTalentGap")
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
