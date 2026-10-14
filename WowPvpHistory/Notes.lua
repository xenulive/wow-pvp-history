-- WowPvpHistory 0.68.22
-- Author:  Xenu-Sentinels
-- Project: wow-pvp-history
--          https://github.com/xenulive/wow-pvp-history
-- License: MIT, see LICENSE
local _,A=...
A.PLAYER_NOTE_MAX=200
A.PLAYER_TAG_MAX=24
A.PLAYER_MAX_TAGS=10
A.PLAYER_COMMENT_MAX=200
A.PLAYER_MAX_COMMENTS=50
local function store(create)
local db=A.db()
if not db then
return nil
end
if type(db.notes)~="table"then
if not create then
return nil
end
db.notes={}
end
return db.notes
end
function A.noteFor(guid)
local notes=store(false)
if not(notes and type(guid)=="string")then
return nil
end
local entry=notes[guid]
if type(entry)~="table"then
return nil
end
return entry
end
local vocabulary
function A.dropTagVocabulary()
vocabulary=nil
end
local function touch(entry)
vocabulary=nil
local ok,stamp=pcall(A.stamp)
if ok then
entry.updatedAt=stamp
end
local read,epoch=pcall(time)
if read and type(epoch)=="number"then
entry.updatedEpoch=epoch
end
end
local function traceNote(field,state,reason,text,bound)
local counted=type(text)=="string"
A.trace("authored",{
source=field,state=state,reason=reason,
bytes=counted and#text or nil,
letters=counted and A.letterCount(text)or nil,
bound=counted and bound or nil,
},"data")
end
function A.letterCount(text)
if type(text)~="string"then
return 0
end
local _,n=text:gsub("[^\128-\191]","")
return n
end
function A.writtenAbout(note)
if type(note)~="table"then
return false
end
return note.rating~=nil or note.text~=nil
or(type(note.tags)=="table"and#note.tags>0)
or(type(note.comments)=="table"and#note.comments>0)
end
local function prune(notes,guid,entry)
if not A.writtenAbout(entry)
and(type(entry.merged)~="table"or#entry.merged==0)then
notes[guid]=nil
return true
end
return false
end
local function entryFor(guid,create)
local notes=store(create)
if not notes then
return nil,nil
end
local entry=notes[guid]
if type(entry)~="table"then
if not create then
return nil,notes
end
entry={}
notes[guid]=entry
if type(A.clientPlayerName)=="function"then
local ok,name=pcall(A.clientPlayerName,guid)
if ok and name then
A.setPlayerName(guid,name)
end
end
end
return entry,notes
end
function A.setPlayerNote(guid,text)
local usable,why=A.playerKey(guid)
if not usable then
traceNote("note","refused",why)
return false,nil,why
end
if text==nil or text==""then
local entry,notes=entryFor(guid,false)
if not(entry and notes)or entry.text==nil then
traceNote("note","cleared","nothing-stored")
return true,nil
end
local was=entry.text
entry.text=nil
if not prune(notes,guid,entry)then
touch(entry)
end
traceNote("note","cleared")
return true,was
end
if#text>A.PLAYER_NOTE_MAX then
traceNote("note","refused","too-long",text,A.PLAYER_NOTE_MAX)
return false,nil,"too-long",#text,A.PLAYER_NOTE_MAX
end
local entry=entryFor(guid,true)
if not entry then
traceNote("note","refused","no-database")
return false,nil,"no-database"
end
local was=entry.text
if was==text then
traceNote("note","filled","unchanged")
return true,was
end
entry.text=text
touch(entry)
traceNote("note","filled")
return true,was
end
function A.setPlayerName(guid,name)
if type(guid)~="string"or guid==""then
return false
end
if type(name)~="string"or name==""then
return false
end
local db=A.db()
if not db then
return false
end
local index=db.players
if type(index)=="table"and type(index[guid])=="table"then
return false
end
local entry=A.noteFor(guid)
if not entry then
return false
end
entry.name=name
A.trace("authored",{source="name",state="filled",named=true},"data")
return true
end
local RATING_WORDS={
["+2"]=2,["2"]=2,["++"]=2,
["+1"]=1,["1"]=1,["+"]=1,
["0"]=0,
["-1"]=-1,["-"]=-1,
["-2"]=-2,["--"]=-2,
}
function A.ratingValue(word)
if type(word)~="string"then
return nil
end
return RATING_WORDS[word]
end
function A.playerKey(guid)
if type(guid)~="string"or guid==""then
return false,"no-guid"
end
local read,_,stored=pcall(A.playerEntry,guid)
if read and stored then
return true
end
if guid:match("^Player%-%d+%-%x+$")then
return true
end
return false,"not-a-player"
end
function A.setPlayerRating(guid,value)
local usable,why=A.playerKey(guid)
if not usable then
traceNote("rating","refused",why)
return false,nil,why
end
if value==nil then
local entry,notes=entryFor(guid,false)
if not(entry and notes)or entry.rating==nil then
traceNote("rating","cleared","nothing-stored")
return true,nil
end
local was=entry.rating
entry.rating=nil
if not prune(notes,guid,entry)then
touch(entry)
end
traceNote("rating","cleared")
return true,was
end
if A.ratingText(value)==nil then
traceNote("rating","refused","bad-rating")
return false,nil,"bad-rating"
end
local entry=entryFor(guid,true)
if not entry then
traceNote("rating","refused","no-database")
return false,nil,"no-database"
end
local was=entry.rating
if was==value then
traceNote("rating","filled","unchanged")
return true,was
end
entry.rating=value
touch(entry)
traceNote("rating","filled")
return true,was
end
local function normalize(tag)
if type(tag)~="string"then
return nil
end
tag=tag:lower():gsub("^%s+",""):gsub("%s+$","")
if tag==""then
return nil
end
return tag
end
local function wantedTags(tags)
if type(tags)~="table"or#tags==0 then
return nil,"no-tags"
end
local wanted={}
for i=1,#tags do
local tag=normalize(tags[i])
if tag then
if#tag>A.PLAYER_TAG_MAX then
return nil,"tag-too-long",tag,A.PLAYER_TAG_MAX
end
wanted[#wanted+1]=tag
end
end
if#wanted==0 then
return nil,"no-tags"
end
return wanted
end
local function addWanted(guid,wanted)
local entry,notes=entryFor(guid,true)
if not entry then
return false,nil,"no-database"
end
local held=entry.tags or{}
local seen={}
for i=1,#held do
seen[held[i]]=true
end
local added={}
local total=#held
for i=1,#wanted do
local tag=wanted[i]
if not seen[tag]then
seen[tag]=true
total=total+1
if total>A.PLAYER_MAX_TAGS then
prune(notes,guid,entry)
return false,nil,"too-many",tag,A.PLAYER_MAX_TAGS
end
added[#added+1]=tag
end
end
if#added==0 then
return true,{}
end
for i=1,#added do
held[#held+1]=added[i]
end
entry.tags=held
touch(entry)
return true,added
end
function A.addPlayerTags(guid,tags)
local keyed,refusal=A.playerKey(guid)
if not keyed then
traceNote("tag","refused",refusal)
return false,nil,refusal
end
local wanted,why,offender,bound=wantedTags(tags)
if not wanted then
traceNote("tag","refused",why)
return false,nil,why,offender,bound
end
local ok,added,reason,badTag,cap=addWanted(guid,wanted)
if not ok then
traceNote("tag","refused",reason)
return false,nil,reason,badTag,cap
end
traceNote("tag",#added>0 and"filled"or"unchanged")
return true,added
end
local function removeWanted(guid,tags)
local entry,notes=entryFor(guid,false)
if not(entry and notes)then
return{},false,false
end
local held=entry.tags
if type(held)~="table"or#held==0 then
return{},false,false
end
local removed={}
if type(tags)~="table"or#tags==0 then
for i=1,#held do
removed[i]=held[i]
end
entry.tags=nil
else
local drop={}
for i=1,#tags do
local tag=normalize(tags[i])
if tag then
drop[tag]=true
end
end
for i=#held,1,-1 do
if drop[held[i]]then
table.insert(removed,1,held[i])
table.remove(held,i)
end
end
if#held==0 then
entry.tags=nil
end
end
local pruned=false
if#removed>0 then
pruned=prune(notes,guid,entry)
if not pruned then
touch(entry)
end
end
return removed,pruned,true
end
function A.removePlayerTags(guid,tags)
if type(guid)~="string"or guid==""then
traceNote("untag","refused","no-guid")
return false,nil,"no-guid"
end
local removed,_,carried=removeWanted(guid,tags)
if not carried then
traceNote("untag","cleared","nothing-stored")
return true,removed
end
traceNote("untag",#removed>0 and"cleared"or"unchanged")
return true,removed
end
function A.addPlayerComment(guid,text)
local keyed,refusal=A.playerKey(guid)
if not keyed then
traceNote("comment","refused",refusal)
return false,nil,refusal
end
local body=type(text)=="string"and text:gsub("^%s+",""):gsub("%s+$","")or""
if body==""then
traceNote("comment","refused","empty")
return false,nil,"empty"
end
if#body>A.PLAYER_COMMENT_MAX then
traceNote("comment","refused","too-long",body,A.PLAYER_COMMENT_MAX)
return false,nil,"too-long",#body,A.PLAYER_COMMENT_MAX
end
local entry,notes=entryFor(guid,true)
if not entry then
traceNote("comment","refused","no-database")
return false,nil,"no-database"
end
local held=type(entry.comments)=="table"and entry.comments or{}
if#held>=A.PLAYER_MAX_COMMENTS then
prune(notes,guid,entry)
traceNote("comment","refused","too-many")
return false,nil,"too-many",#held,A.PLAYER_MAX_COMMENTS
end
local comment={text=body}
local ok,stamp=pcall(A.stamp)
if ok then
comment.at=stamp
end
local read,epoch=pcall(time)
if read and type(epoch)=="number"then
comment.epoch=epoch
end
held[#held+1]=comment
entry.comments=held
touch(entry)
traceNote("comment","filled")
return true,comment
end
function A.removePlayerComment(guid,index,text)
local keyed,refusal=A.playerKey(guid)
if not keyed then
traceNote("uncomment","refused",refusal)
return false,nil,refusal
end
local entry,notes=entryFor(guid,false)
local held=entry and entry.comments or nil
if type(held)~="table"or type(index)~="number"or held[index]==nil then
traceNote("uncomment","refused","absent")
return false,nil,"absent"
end
if text~=nil and held[index].text~=text then
traceNote("uncomment","refused","moved")
return false,nil,"moved"
end
local removed=table.remove(held,index)
if#held==0 then
entry.comments=nil
end
if not prune(notes,guid,entry)then
touch(entry)
end
traceNote("uncomment","cleared")
return true,removed
end
function A.playerComments(guid)
local out={}
local entry=A.noteFor(guid)
local held=entry and entry.comments or nil
if type(held)~="table"then
return out
end
for i=#held,1,-1 do
local comment=held[i]
if type(comment)=="table"and type(comment.text)=="string"then
out[#out+1]={text=comment.text,at=comment.at,index=i}
end
end
return out
end
local function rosterSubjects(record)
local items=A.matchRoster(record)
local out,bots={},0
for i=1,#items do
if A.isBotGuid(items[i].guid)then
bots=bots+1
else
out[#out+1]=items[i]
end
end
return out,bots
end
local function traceRoster(verb,state,summary,reason)
A.trace("roster",{
source=verb,
state=state,
reason=reason,
n=summary and summary.addressed or nil,
tagged=summary and summary.tagged or nil,
untagged=summary and summary.untagged or nil,
unchanged=summary and summary.unchanged or nil,
atCap=summary and summary.atCap or nil,
bots=summary and summary.bots or nil,
pruned=summary and summary.pruned or nil,
},"data")
end
local function rosterSummary(addressed,bots)
return{
addressed=addressed,bots=bots,
tagged=0,untagged=0,unchanged=0,atCap=0,pruned=0,
}
end
function A.tagRoster(record,tags)
if type(record)~="table"then
traceRoster("tag","refused",nil,"no-record")
return false,nil,"no-record"
end
local wanted,why,offender,bound=wantedTags(tags)
if not wanted then
traceRoster("tag","refused",nil,why)
return false,nil,why,offender,bound
end
local subjects,bots=rosterSubjects(record)
local summary=rosterSummary(#subjects,bots)
if#subjects==0 then
traceRoster("tag","refused",summary,"empty-roster")
return false,summary,"empty-roster"
end
for i=1,#subjects do
local item=subjects[i]
local ok,added,reason=addWanted(item.guid,wanted)
if not ok and reason~="too-many"then
traceRoster("tag","refused",summary,reason)
return false,summary,reason
end
if not ok then
summary.atCap=summary.atCap+1
elseif#added>0 then
summary.tagged=summary.tagged+1
A.setPlayerName(item.guid,item.name)
else
summary.unchanged=summary.unchanged+1
end
end
traceRoster("tag",summary.tagged>0 and"filled"or"unchanged",summary)
return true,summary
end
function A.untagRoster(record,tags)
if type(record)~="table"then
traceRoster("untag","refused",nil,"no-record")
return false,nil,"no-record"
end
local subjects,bots=rosterSubjects(record)
local summary=rosterSummary(#subjects,bots)
if#subjects==0 then
traceRoster("untag","refused",summary,"empty-roster")
return false,summary,"empty-roster"
end
for i=1,#subjects do
local removed,pruned=removeWanted(subjects[i].guid,tags)
if#removed>0 then
summary.untagged=summary.untagged+1
if pruned then
summary.pruned=summary.pruned+1
end
else
summary.unchanged=summary.unchanged+1
end
end
traceRoster("untag",summary.untagged>0 and"cleared"or"unchanged",summary)
return true,summary
end
local function repaintAfter(stored,...)
if stored and type(A.refreshNotes)=="function"then
pcall(A.refreshNotes)
end
return stored,...
end
for _,name in ipairs({"setPlayerNote","setPlayerRating","addPlayerTags","removePlayerTags",
"addPlayerComment","removePlayerComment","tagRoster","untagRoster"})do
local write=A[name]
A[name]=function(...)
return repaintAfter(write(...))
end
end
function A.rosterTagCounts(record)
local out={}
if type(record)~="table"then
return out
end
local subjects=rosterSubjects(record)
local counts={}
for i=1,#subjects do
local entry=A.noteFor(subjects[i].guid)
if entry and type(entry.tags)=="table"then
for j=1,#entry.tags do
local tag=entry.tags[j]
counts[tag]=(counts[tag]or 0)+1
end
end
end
for tag,count in pairs(counts)do
out[#out+1]={tag=tag,count=count}
end
table.sort(out,function(a,b)
if a.count~=b.count then
return a.count>b.count
end
return a.tag<b.tag
end)
return out
end
local function countedTags(notes)
if vocabulary and vocabulary.notes==notes then
return vocabulary.ranked
end
local counts,ranked={},{}
for _,entry in pairs(notes)do
if type(entry)=="table"and type(entry.tags)=="table"then
for i=1,#entry.tags do
local tag=entry.tags[i]
counts[tag]=(counts[tag]or 0)+1
end
end
end
for tag,count in pairs(counts)do
ranked[#ranked+1]={tag=tag,count=count,folded=A.foldText(tostring(tag))}
end
table.sort(ranked,function(a,b)
if a.count~=b.count then
return a.count>b.count
end
return a.tag<b.tag
end)
vocabulary={notes=notes,ranked=ranked}
return ranked
end
function A.tagVocabulary(text)
local notes=store(false)
local out={}
if not notes then
return out
end
local needle=(type(text)=="string"and text~="")and A.foldText(text)or nil
local ranked=countedTags(notes)
for i=1,#ranked do
local item=ranked[i]
if needle==nil or item.folded:find(needle,1,true)then
out[#out+1]={tag=item.tag,count=item.count}
end
end
return out
end
function A.writtenNoteCount()
local notes=store(false)
if not notes then
return 0
end
local n=0
for _,entry in pairs(notes)do
if A.writtenAbout(entry)then
n=n+1
end
end
return n
end
function A.notedCount()
local notes=store(false)
if not notes then
return 0
end
local n=0
for _ in pairs(notes)do
n=n+1
end
return n
end
function A.taggedCount()
local notes=store(false)
local n=0
for _,entry in pairs(notes or{})do
if type(entry)=="table"and type(entry.tags)=="table"and#entry.tags>0 then
n=n+1
end
end
return n
end
local listing
local CHOICE_LIMIT=8
function A.resolvePlayer(text)
if type(text)~="string"or text==""then
return nil,"none"
end
local handle=text:match("^#(%d+)$")
if handle then
if not listing then
return nil,"no-listing"
end
local item=listing[tonumber(handle)]
if not item then
return nil,"range",#listing
end
return item.guid,item.entry
end
local found=A.findPlayers(text)
if#found==0 then
return nil,"none"
end
if#found==1 then
return found[1].guid,found[1].entry
end
local shown={}
for i=1,math.min(#found,CHOICE_LIMIT)do
shown[i]=found[i]
end
listing=shown
return nil,"several",shown,#found
end
function A.playerListing()
return listing
end
function A.clearPlayerListing()
listing=nil
end
