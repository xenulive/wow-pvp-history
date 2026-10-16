-- WowPvpHistory 0.68.35
-- Author:  Xenu-Sentinels
-- Project: wow-pvp-history
--          https://github.com/xenulive/wow-pvp-history
-- License: MIT, see LICENSE
local _,A=...
local DEFAULT_ARENA=40
local MIN_ARENA,MAX_ARENA=4,100
local MAX_STORED=300
local FIXTURE_SEASON=2
local COMP_SHARES={0.35,0.30,0.25,0.10}
local function sequence(seed)
local state=seed%2147483647
if state<=0 then
state=1
end
return function(bound)
state=(state*16807)%2147483647
if bound==nil then
return state
end
return(state%bound)+1
end
end
local FIXTURE_REALM="4001"
local REALM="Testrealm"
local DUOS={
{{spec="Assassination",class="Rogue",token="ROGUE"},
{spec="Restoration",class="Druid",token="DRUID",heal=true}},
{{spec="Frost",class="Mage",token="MAGE"},
{spec="Discipline",class="Priest",token="PRIEST",heal=true}},
{{spec="Arms",class="Warrior",token="WARRIOR"},
{spec="Holy",class="Paladin",token="PALADIN",heal=true}},
{{spec="Affliction",class="Warlock",token="WARLOCK"},
{spec="Mistweaver",class="Monk",token="MONK",heal=true}},
}
local TRIOS={
{{spec="Fury",class="Warrior",token="WARRIOR"},
{spec="Marksmanship",class="Hunter",token="HUNTER"},
{spec="Holy",class="Paladin",token="PALADIN",heal=true}},
{{spec="Unholy",class="DeathKnight",token="DEATHKNIGHT"},
{spec="Devastation",class="Evoker",token="EVOKER"},
{spec="Restoration",class="Shaman",token="SHAMAN",heal=true}},
{{spec="Subtlety",class="Rogue",token="ROGUE"},
{spec="Balance",class="Druid",token="DRUID"},
{spec="Discipline",class="Priest",token="PRIEST",heal=true}},
{{spec="Havoc",class="DemonHunter",token="DEMONHUNTER"},
{spec="Elemental",class="Shaman",token="SHAMAN"},
{spec="Mistweaver",class="Monk",token="MONK",heal=true}},
}
local NAMES={
"Fixturea","Fixtureb","Fixturec","Fixtured","Fixturee","Fixturef",
"Fixtureg","Fixtureh","Fixturei","Fixturej","Fixturek","Fixturel",
"Fixturem","Fixturen","Fixtureo","Fixturep","Fixtureq","Fixturer",
"Fixtures","Fixturet","Fixtureu","Fixturev","Fixturew","Fixturex",
"Фикстура","픽스처","夹具",
}
function A.fixtureNames(n)
if type(n)~="number"or n<1 then
return{}
end
local out={}
for i=1,math.floor(n)do
out[i]=NAMES[((i-1)%#NAMES)+1]..i.."-"..REALM
end
return out
end
local BLITZ_ROSTER={
{spec="Fury",class="Warrior",token="WARRIOR"},
{spec="Frost",class="Mage",token="MAGE"},
{spec="Restoration",class="Druid",token="DRUID",heal=true},
{spec="Assassination",class="Rogue",token="ROGUE"},
{spec="Beast Mastery",class="Hunter",token="HUNTER"},
{spec="Devastation",class="Evoker",token="EVOKER"},
{spec="Retribution",class="Paladin",token="PALADIN"},
{spec="Unholy",class="DeathKnight",token="DEATHKNIGHT"},
{spec="Marksmanship",class="Hunter",token="HUNTER"},
{spec="Discipline",class="Priest",token="PRIEST",heal=true},
{spec="Havoc",class="DemonHunter",token="DEMONHUNTER"},
{spec="Elemental",class="Shaman",token="SHAMAN"},
{spec="Affliction",class="Warlock",token="WARLOCK"},
{spec="Windwalker",class="Monk",token="MONK"},
{spec="Balance",class="Druid",token="DRUID"},
}
local SHUFFLE_LOBBIES={
{
healers={
{spec="Restoration",class="Shaman",token="SHAMAN",heal=true},
{spec="Mistweaver",class="Monk",token="MONK",heal=true},
},
damage={
{spec="Arms",class="Warrior",token="WARRIOR"},
{spec="Shadow",class="Priest",token="PRIEST"},
{spec="Subtlety",class="Rogue",token="ROGUE"},
{spec="Havoc",class="DemonHunter",token="DEMONHUNTER"},
},
},
{
healers={
{spec="Restoration",class="Shaman",token="SHAMAN",heal=true},
{spec="Discipline",class="Priest",token="PRIEST",heal=true},
},
damage={
{spec="Arms",class="Warrior",token="WARRIOR"},
{spec="Shadow",class="Priest",token="PRIEST"},
{spec="Subtlety",class="Rogue",token="ROGUE"},
{spec="Frost",class="Mage",token="MAGE"},
},
},
}
local SHUFFLE_COUNT=18
local SHUFFLE_MAPS={
{name="Fixture Colosseum",instanceType="arena",instanceId=9004},
{name="Fixture Ring",instanceType="arena",instanceId=9006},
{name="Fixture Pit",instanceType="arena",instanceId=9007},
}
local DAMAGE_SPLITS={
{{1,2},{3,4}},
{{1,3},{2,4}},
{{1,4},{2,3}},
}
local SHUFFLE_SPLIT_ORDER={
{1,2,3},
{2,3,1},
{3,1,2},
}
local SHUFFLE_LEAD={
{1,2,1},
{2,1,2},
}
local SHUFFLE_MATCHUP_WINS={
{true,true,false,false,true,false},
{true,false,false,false,false,false},
{true,true,false,true,true,true},
{true,true,false,false,true,true},
{true,true,false,false,false,false},
{true,true,true,true,true,true},
}
local function shuffleOthers(lobby,healerSeat,sameSpec)
local function twin(of)
return{spec=of.spec,class=of.class,token=of.token,heal=of.heal}
end
if healerSeat then
local first=lobby.damage[1]
return{lobby.healers[1],first,
sameSpec and twin(first)or lobby.damage[2],lobby.damage[3],lobby.damage[4]}
end
local lead=lobby.healers[1]
return{lead,sameSpec and twin(lead)or lobby.healers[2],
lobby.damage[1],lobby.damage[2],lobby.damage[3]}
end
local function dealShuffle(recordIndex,healerSeat)
local order=SHUFFLE_SPLIT_ORDER[((recordIndex-1)%#SHUFFLE_SPLIT_ORDER)+1]
local lead=SHUFFLE_LEAD[((recordIndex-1)%#SHUFFLE_LEAD)+1]
local out={}
for block=1,#order do
local split=order[block]
local first=lead[block]
for half=1,2 do
local side=(half==1)and first or(3-first)
local mates
if healerSeat then
local pair=DAMAGE_SPLITS[split][side]
mates={2+pair[1],2+pair[2]}
else
local partner=DAMAGE_SPLITS[split][1][2]
mates={2+partner,1+side}
end
out[#out+1]={mates=mates,matchup=(split-1)*2+side}
end
end
return out
end
local SELF={
name="Fixtureself-"..REALM,
class="Paladin",token="PALADIN",spec="Retribution",role=8,
}
local SELF_HEALER={
class="Paladin",token="PALADIN",spec="Holy",role=4,
}
local DAMAGE_SHARES={
1.00,0.72,0.55,0.86,0.31,0.64,0.18,0.47,0.93,0.26,
0.58,0.12,0.79,0.38,0.67,0.21,0.50,0.88,0.15,0.42,
}
local function spread(top,index)
return math.floor(top*DAMAGE_SHARES[((index-1)%#DAMAGE_SHARES)+1])
end
local function roleAndHealing(pick,seat,scale)
if type(pick)=="table"and pick.heal then
return 4,spread(scale,seat)
end
return 8,nil
end
local ROUND_PACING={
{0.20,0.13,0.23,0.10,0.17,0.17},
{0.12,0.24,0.16,0.19,0.14,0.15},
{0.18,0.11,0.21,0.25,0.13,0.12},
{0.15,0.22,0.12,0.16,0.24,0.11},
{0.23,0.14,0.19,0.11,0.20,0.13},
{0.05,0.06,0.07,0.06,0.08,0.68},
}
local CART_COLUMNS={
{id=371,order=1,name="Carts Controlled"},
{id=372,order=2,name="Cart Assaults"},
}
local SHUFFLE_ROUNDS_COLUMN=1012
local function characterGuid(n)
return("Player-%s-%08X"):format(FIXTURE_REALM,0xF1000000+n)
end
local function botGuid(instance,n)
return("Player-%04d-%d-%04d-%08X%08X"):format(4900+instance,1,7000+instance,
0xB0700000,0x0000F000+n)
end
local function participant(fields)
local p={
name=fields.name,
faction=fields.faction,
race="Human",
class=fields.class,
classToken=fields.token,
spec=fields.spec,
role=fields.role or 8,
honorLevel=40+(fields.seat or 1),
killingBlows=fields.kb or 0,
honorableKills=fields.hk or 0,
deaths=fields.deaths or 0,
honor=fields.honor or 0,
damage=fields.damage,
healing=fields.healing,
}
if fields.rating~=nil then
p.rating=fields.rating
p.ratingChange=fields.ratingChange or 0
end
if fields.mmrPre~=nil then
p.mmrPre=fields.mmrPre
p.mmrPost=fields.mmrPost
end
if fields.side~=nil then
p.side=fields.side
end
if fields.seat~=nil then
p.seat=fields.seat
end
if fields.stats~=nil then
p.stats=fields.stats
end
return p
end
local function record(fields)
local r={
[A.FIXTURE_KEY]=true,
format=fields.format,
rated=fields.rated,
openedEpoch=fields.epoch-(fields.duration or 300),
openedAt=A.stampAt(fields.epoch-(fields.duration or 300)),
openedState="StartUp",
completedEpoch=fields.epoch,
completedAt=A.stampAt(fields.epoch),
duration=fields.duration or 300,
map=fields.map,
participants={},
rounds=fields.rounds or{},
}
if fields.bracket~=nil then
r.bracket=fields.bracket
end
if fields.season~=nil then
r.season=fields.season
end
if fields.result~=nil then
r.result=fields.result
end
if fields.winnerFaction~=nil then
r.winnerFaction=fields.winnerFaction
end
if fields.selfFaction~=nil then
r.selfFaction=fields.selfFaction
end
if fields.columns~=nil then
r.columns=fields.columns
end
return r
end
local RECORDERS=2
local RECORDER_BASE=0xE00
local function recorderGuid(index)
return characterGuid(RECORDER_BASE+(index%RECORDERS))
end
function A.fixtureCharacterName()
return(SELF.name:match("^([^-]+)"))or SELF.name
end
local FIXTURE_BUILDS={
{string="CQQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAYMzMjZMjZmZGjxMDzMjZAAAAAAgBAzwMA",
loadout="Arena",hero=31,heroName="Herald of the Sun",pvp={5573,5584,752}},
{string="CQQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAYMzMjZMjZmZGjxMDzMjxAAAAAAgBAzwMA",
loadout="Arena",hero=31,heroName="Herald of the Sun",pvp={5535,5666,753}},
{string="CQQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAMzMjZMDzMzYGjxMDjZmZAAAAAAgBAzwMA",
hero=32,heroName="Templar",pvp={5572,5573,753}},
}
local function fixtureTalents(own)
local damage=type(own)=="table"and type(own.damage)=="number"and own.damage or 0
local pick=FIXTURE_BUILDS[(math.floor(damage/1000)%#FIXTURE_BUILDS)+1]
local pvp={}
for i=1,#pick.pvp do
pvp[i]=pick.pvp[i]
end
return{string=pick.string,loadout=pick.loadout,hero=pick.hero,heroName=pick.heroName,
pvp=pvp}
end
local function close(r,rows)
local n=0
for i=1,#rows do
r.participants[rows[i].guid]=rows[i].p
n=n+1
end
r.participantCount=n
r.character=rows[1]and rows[1].guid or nil
if r.format~="duel"and r.format~="world"then
r.talents=fixtureTalents(rows[1]and rows[1].p or nil)
end
return r
end
local function sandboxExtras(now)
local recorder=recorderGuid(0)
local out={}
local opponents={
{name=NAMES[1].."91-"..REALM,guid=characterGuid(901),class="Rogue",token="ROGUE",
spec="Subtlety"},
{name=NAMES[2].."92-"..REALM,guid=characterGuid(902),class="Mage",token="MAGE",
spec="Frost"},
{name=NAMES[3].."93"},
}
local duels={
{who=1,result="win",outcome="knockout"},
{who=1,result="loss",outcome="knockout"},
{who=1,result="win",outcome="retreat"},
{who=1,result="loss",outcome="retreat"},
{who=2,result="win",outcome="knockout",untimed=true},
{who=3,result="loss",outcome="knockout"},
}
for i,duel in ipairs(duels)do
local opponent=opponents[duel.who]
local r=record({format="duel",rated=false,epoch=now-(#duels-i+4)*600,
duration=30+i*9,map={name="Fixture Plains",instanceType="none"}})
if duel.untimed then
r.openedEpoch,r.openedAt,r.duration=nil,nil,nil
end
r.result=duel.result
r.outcome=duel.outcome
r.opponentName=opponent.name
local against
if opponent.guid then
against={guid=opponent.guid,p=participant({name=opponent.name,class=opponent.class,
token=opponent.token,spec=opponent.spec,side="against"})}
else
against={guid=opponent.name,p={name=opponent.name,side="against"}}
end
out[#out+1]=close(r,{
{guid=recorder,p=participant({name=SELF.name,class=SELF.class,token=SELF.token,
spec=SELF.spec,side="with"})},
against,
})
end
local outings={
{ends=22680,duration=660,zone="Fixture Ridge",kills=4,deaths=1},
{ends=20580,duration=900,zone="Fixture Plains",kills=7,deaths=3},
{ends=14100,duration=480,zone="Fixture Plains",kills=0,deaths=2},
{ends=12360,duration=540,zone="Fixture Ridge",kills=1,deaths=4},
{ends=6240,duration=720,zone="Fixture Ridge",kills=5,deaths=0},
{ends=4740,duration=600,zone="Fixture Plains",kills=2,deaths=2},
{ends=3000,duration=840,zone="Fixture Plains",kills=3,deaths=1},
}
for _,outing in ipairs(outings)do
local world=record({format="world",rated=false,epoch=now-outing.ends,
duration=outing.duration,map={name=outing.zone,instanceType="none"}})
world.rounds=nil
world.openedState=nil
world.warMode=true
world.kills=outing.kills
world.deaths=outing.deaths
out[#out+1]=close(world,{
{guid=recorder,p={name=SELF.name,side="with"}},
})
end
local other=record({format="unknown",epoch=now-300,duration=95,
map={name="Fixture Basin",instanceType="pvp",instanceId=9003}})
out[#out+1]=close(other,{
{guid=recorder,p=participant({name=SELF.name,class=SELF.class,token=SELF.token,
spec=SELF.spec,faction=0})},
})
local left={
{reason="left",openedAt=A.stampAt(now-200),endedAt=A.stampAt(now-80),
seconds=120,character=recorder,map={name="Fixture Basin",instanceType="pvp"}},
{reason="abandoned",openedAt=A.stampAt(now-9000),endedAt=A.stampAt(now-8000),
rated=true,character=recorder,map={name="Fixture Arena",instanceType="arena"}},
}
return out,left
end
local function compCounts(n)
local counts,used={},0
for i=1,#COMP_SHARES do
counts[i]=math.floor(n*COMP_SHARES[i])
used=used+counts[i]
end
counts[1]=counts[1]+(n-used)
return counts
end
function A.fixtureRecords(n,now,options)
n=tonumber(n)or DEFAULT_ARENA
n=math.floor(n)
if n<MIN_ARENA then
n=MIN_ARENA
elseif n>MAX_ARENA then
n=MAX_ARENA
end
now=tonumber(now)or time()
options=type(options)=="table"and options or{}
local healerSeat=options.seat=="healer"
local sameSpec=options.sameSpec and true or false
local rand=sequence(20260826)
local out={}
local person=0
local clock=sequence(20261014)
local lastEnd=0
local blockLeft,sessionLeft=0,0
local function startBlock(count)
blockLeft=count
sessionLeft=0
end
local function nextEpoch(duration)
local opening=sessionLeft<=0
if opening then
local length=math.max(blockLeft,1)
if blockLeft>6 then
length=clock(5)+1
if blockLeft-length==1 then
length=length-1
end
end
sessionLeft=length
end
sessionLeft=sessionLeft-1
blockLeft=blockLeft-1
local gap=opening and(89+clock(91))*60 or(14+clock(11))*60
lastEnd=lastEnd+gap+duration
return lastEnd
end
local function mint(fields)
person=person+1
fields.name=NAMES[((person-1)%#NAMES)+1]..person.."-"..REALM
fields.guid=characterGuid(person)
return fields
end
local function arenaBracket(format,bracket,pool,size,ladder)
local counts=compCounts(n)
startBlock(n)
local written,cleared=0,0
local floor=A.rankFloor and A.rankFloor("comps")or 10
for c=1,#pool do
local enemies={}
for i=1,#pool[c]do
enemies[i]=mint({spec=pool[c][i].spec,class=pool[c][i].class,
token=pool[c][i].token,heal=pool[c][i].heal})
end
local mates={}
for i=1,size-1 do
mates[i]=mint({spec="Frost",class="Mage",token="MAGE"})
end
if counts[c]>0 and counts[c]>=floor then
cleared=cleared+1
end
for g=1,counts[c]do
local won=(rand(10)>4)
local change=won and(12+rand(8))or-(10+rand(8))
local rating=ladder.rating
ladder.rating=ladder.rating+change
local rows={}
rows[1]={guid=recorderGuid(#out),p=participant({
name=SELF.name,faction=0,class=SELF.class,token=SELF.token,
spec=SELF.spec,role=SELF.role,seat=1,
damage=200000+rand(80000),healing=20000+rand(9000),
kb=rand(4)-1,deaths=rand(2)-1,
rating=rating,ratingChange=change,
mmrPre=ladder.mmr,mmrPost=ladder.mmr,
})}
for i=1,#mates do
local role,healing=roleAndHealing(mates[i],i,200000)
rows[#rows+1]={guid=mates[i].guid,p=participant({
name=mates[i].name,faction=0,class=mates[i].class,
token=mates[i].token,spec=mates[i].spec,seat=i+1,
role=role,healing=healing,
damage=180000+rand(70000),
rating=rating,ratingChange=change,
mmrPre=ladder.mmr,mmrPost=ladder.mmr,
})}
end
for i=1,#enemies do
local role,healing=roleAndHealing(enemies[i],i,200000)
rows[#rows+1]={guid=enemies[i].guid,p=participant({
name=enemies[i].name,faction=1,class=enemies[i].class,
token=enemies[i].token,spec=enemies[i].spec,seat=i+4,
role=role,healing=healing,
damage=150000+rand(120000),
})}
end
local duration=180+rand(300)
local r=record({
format=format,rated=true,bracket=bracket,
epoch=nextEpoch(duration),duration=duration,
season=ladder.season,
map={name="Fixture Arena",instanceType="arena",instanceId=9001},
result=won and"win"or"loss",
winnerFaction=won and 0 or 1,
selfFaction=0,
})
out[#out+1]=close(r,rows)
written=written+1
end
end
return written,cleared
end
local arena2,cleared2=arenaBracket("arena2",0,DUOS,2,
{rating=1650,mmr=1700,season=FIXTURE_SEASON})
local arena3,cleared3=arenaBracket("arena3",1,TRIOS,3,
{rating=1480,mmr=nil,season=FIXTURE_SEASON})
startBlock(2)
do
local rows={{guid=recorderGuid(#out),p=participant({
name=SELF.name,faction=0,class=SELF.class,token=SELF.token,
spec=SELF.spec,role=SELF.role,damage=210000,healing=21000,
})}}
local mate=mint({spec="Frost",class="Mage",token="MAGE"})
rows[#rows+1]={guid=mate.guid,p=participant({
name=mate.name,faction=0,class=mate.class,token=mate.token,
spec=mate.spec,damage=190000})}
for i=1,2 do
rows[#rows+1]={guid=botGuid(1,i),p=participant({
name="Fixturebot"..i,faction=1,class="Hunter",token="HUNTER",
spec="Marksmanship",damage=90000+i})}
end
local r=record({
format="arena2",rated=true,bracket=0,epoch=nextEpoch(240),duration=240,
season=FIXTURE_SEASON,map={name="Fixture Training Ground",instanceType="pvp",
instanceId=9002},
result="win",winnerFaction=0,selfFaction=0,
})
out[#out+1]=close(r,rows)
arena2=arena2+1
end
do
local rows={{guid=recorderGuid(#out),p=participant({
name=SELF.name,faction=0,class=SELF.class,token=SELF.token,
spec=SELF.spec,role=SELF.role,damage=205000,healing=19000,
})}}
rows[#rows+1]={guid=botGuid(2,1),p=participant({
name="Fixturebot9",faction=0,class="Warrior",token="WARRIOR",
spec="Arms",damage=88000})}
local pair=DUOS[1]
for i=1,#pair do
local e=mint({spec=pair[i].spec,class=pair[i].class,token=pair[i].token})
local role,healing=roleAndHealing(pair[i],i,200000)
rows[#rows+1]={guid=e.guid,p=participant({
name=e.name,faction=1,class=e.class,token=e.token,spec=e.spec,
role=role,healing=healing,
damage=160000+i})}
end
local r=record({
format="arena2",rated=true,bracket=0,epoch=nextEpoch(260),duration=260,
season=FIXTURE_SEASON,map={name="Fixture Training Ground",instanceType="pvp",
instanceId=9002},
result="loss",winnerFaction=1,selfFaction=0,
})
out[#out+1]=close(r,rows)
arena2=arena2+1
end
local blitz=0
startBlock(5)
for i=1,5 do
local rows={
{guid=recorderGuid(#out),p=participant({
name=SELF.name,faction=0,class=SELF.class,token=SELF.token,
spec=SELF.spec,role=SELF.role,damage=spread(760000,1),healing=30000,
kb=2,hk=12,honor=200,
stats={[371]=3,[372]=2},
rating=1800,ratingChange=0,mmrPre=1800,mmrPost=1800,
})},
}
for seat=1,15 do
local faction=(seat<=7)and 0 or 1
local other=mint({spec=BLITZ_ROSTER[seat].spec,class=BLITZ_ROSTER[seat].class,
token=BLITZ_ROSTER[seat].token})
local role,healing=roleAndHealing(BLITZ_ROSTER[seat],seat,540000)
rows[#rows+1]={guid=other.guid,p=participant({
name=other.name,faction=faction,class=other.class,token=other.token,
spec=other.spec,role=role,
damage=spread(760000,seat+1),
healing=healing,
kb=rand(4)-1,hk=rand(18),deaths=rand(3)-1,honor=120+seat,
stats={[371]=rand(4)-1,[372]=rand(3)-1},
})}
end
local r=record({
format="blitz",rated=true,bracket=8,epoch=nextEpoch(600+i),
duration=600+i,season=FIXTURE_SEASON,
map={name="Fixture Basin",instanceType="pvp",instanceId=9003},
columns=CART_COLUMNS,
result=(i%2==0)and"win"or"loss",
winnerFaction=(i%2==0)and 0 or 1,selfFaction=0,
})
out[#out+1]=close(r,rows)
blitz=blitz+1
end
local shuffle=0
local shuffleLadder,shuffleSeason=nil,nil
startBlock(SHUFFLE_COUNT)
for i=1,SHUFFLE_COUNT do
local season=(i<=3)and FIXTURE_SEASON-1 or FIXTURE_SEASON
if season~=shuffleSeason then
shuffleLadder=(season<FIXTURE_SEASON)and 2115 or 1440
shuffleSeason=season
end
local rating=shuffleLadder
local lobbyIndex=(i%4==2)and 2 or 1
local lobby=SHUFFLE_LOBBIES[lobbyIndex]
local others=shuffleOthers(lobby,healerSeat,sameSpec)
local deal=dealShuffle(i,healerSeat)
local rounds={}
local roundRating=rating
for rnd=1,#deal do
local pattern=SHUFFLE_MATCHUP_WINS[deal[rnd].matchup]
local wonRound=pattern[((i-1)%#pattern)+1]and true or false
roundRating=roundRating+(wonRound and 14 or-11)
rounds[rnd]={
endedEpoch=0,
won=wonRound,
ratingPost=roundRating,
mates={deal[rnd].mates[1],deal[rnd].mates[2]},
}
end
local change=roundRating-rating
shuffleLadder=rating+change
local roundsWon={0,0,0,0,0,0}
for rnd=1,#rounds do
local mine={[1]=true,[rounds[rnd].mates[1]]=true,[rounds[rnd].mates[2]]=true}
for seat=1,6 do
if(mine[seat]==true)==rounds[rnd].won then
roundsWon[seat]=roundsWon[seat]+1
end
end
end
local own=healerSeat and SELF_HEALER or SELF
local rows={{guid=recorderGuid(#out),p=participant({
name=SELF.name,faction=0,class=SELF.class,token=SELF.token,
spec=own.spec,role=own.role,seat=1,
damage=healerSeat and spread(170000,1)or spread(620000,1),
healing=healerSeat and spread(520000,1)or 40000,
rating=rating,ratingChange=change,mmrPre=rating+90,mmrPost=rating+100,
stats={[SHUFFLE_ROUNDS_COLUMN]=roundsWon[1]},
})}}
for s=1,#others do
local pick=others[s]
local other=mint({spec=pick.spec,class=pick.class,token=pick.token})
local role,healing=roleAndHealing(pick,s,480000)
rows[#rows+1]={guid=other.guid,p=participant({
name=other.name,faction=0,class=other.class,token=other.token,
spec=other.spec,seat=s+1,role=role,
damage=spread(620000,s+1),
healing=healing,
stats={[SHUFFLE_ROUNDS_COLUMN]=roundsWon[s+1]}})}
end
local epoch=nextEpoch(900)
local pacing=ROUND_PACING[((i-1)%#ROUND_PACING)+1]
local at=epoch-900
for rnd=1,#rounds do
at=at+math.floor(900*pacing[rnd])
rounds[rnd].endedEpoch=(rnd==#rounds)and epoch or at
end
local r=record({
format="shuffle",rated=true,bracket=6,epoch=epoch,
duration=900,season=season,rounds=rounds,
map=(function(held)
return{name=held.name,instanceType=held.instanceType,instanceId=held.instanceId}
end)(SHUFFLE_MAPS[i<=8 and 1 or(i<=16 and 2 or 3)]),
columns={{id=SHUFFLE_ROUNDS_COLUMN,order=1,name="Rounds Won"}},
selfFaction=0,
})
out[#out+1]=close(r,rows)
shuffle=shuffle+1
end
local skirmish=0
startBlock(4)
for i=1,4 do
local rows={{guid=recorderGuid(#out),p=participant({
name=SELF.name,faction=0,class=SELF.class,token=SELF.token,
spec=SELF.spec,role=SELF.role,damage=spread(260000,1),healing=12000,
})}}
local pair=DUOS[((i-1)%#DUOS)+1]
local ally=DUOS[(i%#DUOS)+1][1]
local mate=mint({spec=ally.spec,class=ally.class,token=ally.token})
local mateRole,mateHealing=roleAndHealing(ally,2,200000)
rows[#rows+1]={guid=mate.guid,p=participant({
name=mate.name,faction=0,class=mate.class,token=mate.token,
spec=mate.spec,role=mateRole,healing=mateHealing,
damage=spread(260000,2)})}
for e=1,#pair do
local other=mint({spec=pair[e].spec,class=pair[e].class,token=pair[e].token})
local role,healing=roleAndHealing(pair[e],e+2,200000)
rows[#rows+1]={guid=other.guid,p=participant({
name=other.name,faction=1,class=other.class,token=other.token,
spec=other.spec,role=role,healing=healing,
damage=spread(260000,e+2)})}
end
local r=record({
format="arena-unrated",rated=false,bracket=4,epoch=nextEpoch(200+i),
duration=200+i,season=FIXTURE_SEASON,
map={name="Fixture Arena",instanceType="arena",instanceId=9001},
result=(i%2==0)and"win"or"loss",
winnerFaction=(i%2==0)and 0 or 1,selfFaction=0,
})
out[#out+1]=close(r,rows)
skirmish=skirmish+1
end
local bg=0
startBlock(1)
do
local rows={{guid=recorderGuid(#out),p=participant({
name=SELF.name,faction=0,class=SELF.class,token=SELF.token,
spec=SELF.spec,role=SELF.role,
damage=spread(680000,1),healing=28000,kb=3,hk=14,deaths=2,honor=240,
stats={[371]=2,[372]=1},
})}}
for i=1,19 do
local faction=(i<=9)and 0 or 1
local pick=BLITZ_ROSTER[((i-1)%#BLITZ_ROSTER)+1]
local other=mint({spec=pick.spec,class=pick.class,token=pick.token})
local role,healing=roleAndHealing(pick,i,520000)
rows[#rows+1]={guid=other.guid,p=participant({
name=other.name,faction=faction,class=other.class,token=other.token,
spec=other.spec,
damage=spread(680000,i+1),
healing=healing,
role=role,
kb=rand(5)-1,hk=rand(20),deaths=rand(4)-1,honor=100+i,
stats={[371]=rand(3)-1,[372]=rand(2)-1},
})}
end
local r=record({
format="bg",rated=false,bracket=3,epoch=nextEpoch(780),duration=780,
season=FIXTURE_SEASON,
map={name="Fixture Mines",instanceType="pvp",instanceId=9005},
columns=CART_COLUMNS,
result="win",winnerFaction=0,selfFaction=0,
})
out[#out+1]=close(r,rows)
bg=bg+1
end
local shift=now-lastEnd
for i=1,#out do
local r=out[i]
r.openedEpoch=r.openedEpoch+shift
r.openedAt=A.stampAt(r.openedEpoch)
r.completedEpoch=r.completedEpoch+shift
r.completedAt=A.stampAt(r.completedEpoch)
for rnd=1,#r.rounds do
r.rounds[rnd].endedEpoch=r.rounds[rnd].endedEpoch+shift
end
end
if options.unrated then
local kept={}
for i=1,#out do
if not A.movesRating(out[i].format)then
kept[#kept+1]=out[i]
end
end
out=kept
arena2,arena3,blitz,shuffle,cleared2,cleared3=0,0,0,0,0,0
end
return out,{
arena2=arena2,arena3=arena3,blitz=blitz,shuffle=shuffle,
["arena-unrated"]=skirmish,bg=bg,
unrated=options.unrated and true or false,
compsCleared=cleared2+cleared3,
floor=A.rankFloor and A.rankFloor("comps")or 10,
asked=n,
seat=healerSeat and"healer"or"damage",
sameSpec=sameSpec,
}
end
function A.fixtureRefusal(adding)
local db=A.db()
if not db then
return"no-database"
end
if db.active~=nil then
return"in-flight"
end
if type(A.pvpRestricted)=="function"then
local suppressed=A.pvpRestricted()
if suppressed then
return"restriction"
end
end
if type(GetInstanceInfo)=="function"then
local ok,_,instanceType=pcall(GetInstanceInfo)
if ok and A.canRead(instanceType)and(instanceType=="pvp"or instanceType=="arena")then
return"in-instance"
end
end
local marked=A.fixtureCount()
if marked+(type(adding)=="number"and adding or 1)>MAX_STORED then
return"too-many"
end
return nil
end
function A.fixtureCeiling()
return MAX_STORED
end
function A.fixtureRefusalText(reason)
if reason=="no-database"then
return"there is no database to write to"
end
if reason=="in-flight"then
return"a match is being recorded, so the history is about to gain a real record"
end
if reason=="restriction"or reason=="in-instance"then
return"this is a PvP match. Leave the instance first: generated records in the middle of "
.."a real history are what nobody can untangle afterwards"
end
if reason=="too-many"then
return("%d generated records already stand in the history, which is the most the fixture "
.."will store. /pvph debug fixture clear removes them"):format(MAX_STORED)
end
return"the fixture cannot be generated right now"
end
function A.fixtureCount(db)
db=type(db)=="table"and db or A.db()
if not(db and type(db.matches)=="table")then
return 0,0
end
local marked,real=0,0
for i=1,#db.matches do
local r=db.matches[i]
if type(r)=="table"and r[A.FIXTURE_KEY]then
marked=marked+1
else
real=real+1
end
end
return marked,real
end
function A.fixtureReadings(records)
local rounded,breaks=0,0
local ordered={}
for i=1,#(records or{})do
local r=records[i]
if type(r)=="table"then
if r.format=="shuffle"and A.roundsVerdict(r)~=nil then
rounded=rounded+1
end
ordered[#ordered+1]=r
end
end
table.sort(ordered,function(a,b)
return(a.completedEpoch or 0)<(b.completedEpoch or 0)
end)
local out={}
for i=1,#ordered do
local r=ordered[i]
local own=type(r.participants)=="table"and r.participants[r.character]or nil
if type(own)=="table"and type(own.rating)=="number"and type(own.ratingChange)=="number"then
local key=("%s/%s"):format(tostring(r.format),tostring(r.season))
if out[key]~=nil and out[key]~=own.rating then
breaks=breaks+1
end
out[key]=own.rating+own.ratingChange
end
end
return rounded,breaks
end
function A.generateFixture(n,options)
local records,report=A.fixtureRecords(n,nil,options)
local sandboxed=type(A.sandboxed)=="function"and A.sandboxed()
local extras,left={},{}
if sandboxed then
extras,left=sandboxExtras(time())
end
local refusal=A.fixtureRefusal(#records+#extras)
if refusal then
A.trace("fixture",{state="refused",reason=refusal},"data")
return nil,refusal
end
local db=A.db()
local before=A.fixtureCount()
local storedBefore=#db.matches
local unfolded,foldError=0,nil
db.nextFixtureId=type(db.nextFixtureId)=="number"and db.nextFixtureId or 1
local function store(r)
r.id=("F%d"):format(db.nextFixtureId)
db.nextFixtureId=db.nextFixtureId+1
db.matches[#db.matches+1]=r
local indexed,why=pcall(A.indexMatch,r)
if not indexed then
unfolded=unfolded+1
foldError=why
end
end
for i=1,#records do
store(records[i])
end
for i=1,#extras do
store(extras[i])
end
if unfolded>0 then
A.noteError(foldError,"fixture-index")
A.say(("the records are stored and the player index was not updated for %d of them: %s. /pvph rebuild")
:format(unfolded,tostring(foldError)))
end
local written=#records+#extras
if sandboxed then
for _,entry in ipairs(left)do
entry.id=db.nextIncompleteId or 1
db.nextIncompleteId=entry.id+1
db.incomplete[#db.incomplete+1]=entry
end
pcall(A.editReason,left[2],"disconnect")
pcall(A.setPlayerRating,characterGuid(1),2)
pcall(A.setPlayerNote,characterGuid(1),"Calls the swap early and peels for the healer")
pcall(A.addPlayerTags,characterGuid(1),{"good comms","calls targets","plays late","duo"})
pcall(A.setPlayerRating,characterGuid(2),-1)
end
local moved=A.orderByCompletion(db.matches)
if moved>0 then
local rebuilt,why=pcall(A.rebuildIndex)
if not rebuilt then
A.noteError(why,"fixture-index")
A.say(("the records are stored and the player index was not rebuilt: %s. /pvph rebuild")
:format(tostring(why)))
end
end
report.moved=moved
pcall(A.notePrune,"fixture",storedBefore)
A.recordStored("fixture")
if A.refreshWindow then
local repainted,err=pcall(A.refreshWindow)
if not repainted then
A.noteError(err,"fixture.window")
end
end
local rounded,breaks=A.fixtureReadings(records)
A.trace("fixture",{
state="written",
n=#records,
stored=before+written,
kept=report.compsCleared,
seat=report.seat,
moved=moved,
rounded=rounded,
breaks=breaks,
},"data")
report.written=written
report.before=before
report.stored=before+written
return report
end
function A.fixturePreview()
local marked,real=A.fixtureCount()
local db=A.db()
local leaving,authored=0,0
if db and type(db.players)=="table"then
for guid,entry in pairs(db.players)do
if type(entry)=="table"and(entry.fixture or 0)>0
and(entry.fixture or 0)>=(entry.matches or 0)then
leaving=leaving+1
if A.noteFor and A.noteFor(guid)~=nil then
authored=authored+1
end
end
end
end
return{marked=marked,real=real,leaving=leaving,authored=authored}
end
function A.clearFixture()
local db=A.db()
if not db then
return nil,"no-database"
end
if db.active~=nil then
A.trace("fixture",{state="refused",reason="in-flight"},"data")
return nil,A.fixtureRefusalText("in-flight")
end
local before=A.fixturePreview()
local storedBefore=#db.matches
local kept={}
for i=1,#db.matches do
local r=db.matches[i]
if not(type(r)=="table"and r[A.FIXTURE_KEY])then
kept[#kept+1]=r
end
end
db.matches=kept
local rebuilt,why=pcall(A.rebuildIndex)
if not rebuilt then
A.noteError(why,"fixture-clear-index")
A.say(("the generated records are gone and the player index was not rebuilt: %s. /pvph rebuild")
:format(tostring(why)))
end
pcall(A.notePrune,"fixture-clear",storedBefore)
A.storeReplaced()
local noted=0
if type(db.notes)=="table"then
for _ in pairs(db.notes)do
noted=noted+1
end
end
A.trace("fixture",{state="cleared",n=before.marked,kept=before.real},"data")
return{removed=before.marked,kept=before.real,
leaving=before.leaving,authored=before.authored,noted=noted}
end
