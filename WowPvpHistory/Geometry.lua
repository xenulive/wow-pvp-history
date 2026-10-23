-- WowPvpHistory 0.70.7
-- Author:  Xenu-Sentinels
-- Project: wow-pvp-history
--          https://github.com/xenulive/wow-pvp-history
-- License: MIT, see LICENSE
local _,A=...

local specs={}
local order={}

local placedWindows={}

local queued={}

local typedSize={}

local SIZE_STEPS=8

local buildFailed={}

function A.buildWindowOnce(kind,build,...)
	if buildFailed[kind]~=nil then
		buildFailed[kind]=buildFailed[kind]+1
		A.trace("build",{kind=kind,state="held",n=buildFailed[kind]},"ui")
		return nil
	end
	local ok,built=pcall(build,...)
	if ok and built then
		return built
	end
	buildFailed[kind]=0
	A.trace("build",{kind=kind,state="failed",err=not ok and built or nil},"ui")
	return nil,not ok and tostring(built)or nil
end

function A.registerWindowKind(kind,spec)
	if type(kind)~="string"or kind==""or type(spec)~="table"then
		return false
	end
	if specs[kind]then
		return false
	end
	if type(spec.authored)~="function"or type(spec.floor)~="function"then
		return false
	end
	specs[kind]={
		label=type(spec.label)=="string"and spec.label or kind,
		authored=spec.authored,
		floor=spec.floor,
		pooled=spec.pooled==true or nil,
		newest=type(spec.newest)=="function"and spec.newest or nil,
		sized=type(spec.sized)=="function"and spec.sized or nil,
		ceiling=type(spec.ceiling)=="function"and spec.ceiling or nil,
		shares=type(spec.shares)=="string"and spec.shares~=kind and spec.shares or nil,
		fits=spec.fits==true or nil,
		point=type(spec.point)=="string"and spec.point or"CENTER",
		x=type(spec.x)=="number"and spec.x or 0,
		y=type(spec.y)=="number"and spec.y or 0,
	}
	order[#order+1]=kind
	return true
end

function A.geometryKinds()
	local out={}
	for i=1,#order do
		out[i]=order[i]
	end
	return out
end

local function ownerOf(kind)
	local spec=specs[kind]
	if spec and spec.shares and specs[spec.shares]then
		return spec.shares
	end
	return kind
end

local function groupOf(kind)
	local owner=ownerOf(kind)
	local out={owner}
	for i=1,#order do
		local other=order[i]
		if other~=owner and ownerOf(other)==owner then
			out[#out+1]=other
		end
	end
	return out
end

function A.windowShares(kind)
	local owner=ownerOf(kind)
	if owner==kind then
		return nil
	end
	return owner
end

function A.windowLabel(kind)
	local spec=specs[kind]
	return spec and spec.label or nil
end

function A.windowFrameOf(kind)
	local spec=specs[kind]
	if not spec then
		return nil
	end
	if spec.pooled then
		if not spec.newest then
			return nil
		end
		local ok,frame=pcall(spec.newest)
		return ok and type(frame)=="table"and frame or nil
	end
	return spec.frame
end

function A.authoredGeometry(kind)
	local spec=specs[kind]
	if not spec then
		return nil
	end
	local owner=ownerOf(kind)
	if owner~=kind then
		return A.authoredGeometry(owner)
	end
	local ok,width,height=pcall(spec.authored)
	if not ok or type(width)~="number"or type(height)~="number"then
		return nil
	end
	return width,height,spec.point,spec.x,spec.y
end

local function ownFloor(kind)
	local ok,width,height=pcall(specs[kind].floor)
	if ok and type(width)=="number"and type(height)=="number"then
		return width,height
	end
	return A.authoredGeometry(kind)
end

function A.windowFloor(kind)
	if not specs[kind]then
		return nil
	end
	local width,height
	local group=groupOf(kind)
	for i=1,#group do
		local w,h=ownFloor(group[i])
		if type(w)=="number"and(width==nil or w>width)then
			width=w
		end
		if type(h)=="number"and(height==nil or h>height)then
			height=h
		end
	end
	if width==nil or height==nil then
		return nil
	end
	return width,height
end

local function ownCeiling(kind)
	local spec=specs[kind]
	if not spec.ceiling then
		return nil
	end
	local ok,width=pcall(spec.ceiling)
	if not(ok and type(width)=="number"and width>0)then
		return nil
	end
	local authored=A.authoredGeometry(kind)
	if type(authored)=="number"and authored>width then
		return authored
	end
	return width
end

function A.windowCeiling(kind)
	if not specs[kind]then
		return nil
	end
	local narrowest
	local group=groupOf(kind)
	for i=1,#group do
		local width=ownCeiling(group[i])
		if type(width)=="number"and(narrowest==nil or width<narrowest)then
			narrowest=width
		end
	end
	return narrowest
end

function A.registerPlacedWindow(frame,point,x,y,onScaled,hooks)
	if type(frame)~="table"or type(point)~="string"or point==""then
		return false
	end
	for i=1,#placedWindows do
		if placedWindows[i].frame==frame then
			return false
		end
	end
	local name
	local okName,given=pcall(frame.GetName,frame)
	if okName and type(given)=="string"and given~=""then
		name=given
	end

	placedWindows[#placedWindows+1]={
		frame=frame,
		point=point,
		x=type(x)=="number"and x or 0,
		y=type(y)=="number"and y or 0,
		name=name,
		place=type(hooks)=="table"and type(hooks.place)=="function"and hooks.place or nil,
		stored=type(hooks)=="table"and type(hooks.stored)=="function"and hooks.stored or nil,
	}
	A.registerScaledWindow(frame,onScaled)
	return true
end

function A.placedWindows()
	local out={}
	for i=1,#placedWindows do
		local held=placedWindows[i]
		local stored=nil
		if held.stored then
			local ok,point,x,y=pcall(held.stored)
			if ok and type(point)=="string"then
				stored={point=point,x=x,y=y}
			end
		end
		out[i]={frame=held.frame,point=held.point,x=held.x,y=held.y,name=held.name,
			stored=stored}
	end
	return out
end

function A.replacePlacedWindows()
	local names,refused={},0
	for i=1,#placedWindows do
		local held=placedWindows[i]
		local point,x,y=held.point,held.x,held.y
		if held.place then
			local okPlace,p,px,py=pcall(held.place)
			if okPlace and type(p)=="string"and type(px)=="number"and type(py)=="number"then
				point,x,y=p,px,py
			end
		end
		local ok=pcall(held.frame.ClearAllPoints,held.frame)
		if ok then
			ok=pcall(held.frame.SetPoint,held.frame,point,UIParent,point,x,y)
		end
		if ok then
			names[#names+1]=held.name or("window "..i)
		else
			refused=refused+1
		end
	end
	return names,refused
end

local function screenSize()
	local width,height
	if type(GetScreenWidth)=="function"then
		local ok,value=pcall(GetScreenWidth)
		if ok and type(value)=="number"and value>0 then
			width=value
		end
	end
	if type(GetScreenHeight)=="function"then
		local ok,value=pcall(GetScreenHeight)
		if ok and type(value)=="number"and value>0 then
			height=value
		end
	end
	return width,height
end

A.screenSize=screenSize

local SCALE_MIN,SCALE_MAX,SCALE_STEP,SCALE_DEFAULT=70,150,5,100

local scaledWindows={}

local sessionScale=nil

local storedPlaces={}

function A.registerStoredPlace(convert)
	if type(convert)~="function"then
		return false
	end
	storedPlaces[#storedPlaces+1]=convert
	return true
end

local function scaleStep(value)
	local number=tonumber(value)
	if number==nil or number~=number or number==math.huge or number==-math.huge then
		return nil
	end
	local stepped=math.floor(number/SCALE_STEP+0.5)*SCALE_STEP
	return math.max(SCALE_MIN,math.min(SCALE_MAX,stepped))
end

function A.windowScale()
	local db=A.db()
	if not db or type(db.ui)~="table"then
		return SCALE_DEFAULT
	end
	return scaleStep(db.ui.windowScale)or SCALE_DEFAULT
end

function A.windowScaleRange()
	return SCALE_MIN,SCALE_MAX,SCALE_STEP,SCALE_DEFAULT
end

function A.windowScaleApplied()
	return sessionScale or A.windowScale()
end

local function scaleFactor()
	return A.windowScaleApplied()/100
end

function A.sessionToStoredRatio()
	if sessionScale==nil then
		return 1
	end
	return sessionScale/A.windowScale()
end

function A.screenSizeFor(frame)
	local width,height=screenSize()
	local scale=nil
	if type(frame)=="table"and type(frame.GetScale)=="function"then
		local ok,read=pcall(frame.GetScale,frame)
		if ok and type(read)=="number"and read>0 then
			scale=read
		end
	end
	scale=scale or scaleFactor()
	return width and width/scale or nil,height and height/scale or nil
end

function A.stopDrag(frame)
	pcall(frame.StopMovingOrSizing,frame)
	pcall(frame.SetUserPlaced,frame,false)
end

function A.registerScaledWindow(frame,onScaled)
	if type(frame)~="table"then
		return false
	end
	for i=1,#scaledWindows do
		if scaledWindows[i].frame==frame then
			return false
		end
	end
	local name
	local okName,given=pcall(frame.GetName,frame)
	if okName and type(given)=="string"and given~=""then
		name=given
	end
	scaledWindows[#scaledWindows+1]={
		frame=frame,
		name=name,
		onScaled=type(onScaled)=="function"and onScaled or nil,
	}
	pcall(frame.SetScale,frame,scaleFactor())
	return true
end

local function convertAnchors(frame,ratio)
	local okCount,count=pcall(frame.GetNumPoints,frame)
	if not okCount or type(count)~="number"or count<1 then
		return false
	end
	local points,onRoot={},false
	for i=1,count do
		local ok,point,relativeTo,relativePoint,x,y=pcall(frame.GetPoint,frame,i)
		if not ok or type(point)~="string"then
			return false
		end
		local root=relativeTo==nil or relativeTo==UIParent
		onRoot=onRoot or root
		points[i]={point,relativeTo,relativePoint or point,
			(type(x)=="number"and x or 0)*(root and ratio or 1),
			(type(y)=="number"and y or 0)*(root and ratio or 1)}
	end
	if not onRoot then
		return false
	end
	pcall(frame.ClearAllPoints,frame)
	for i=1,#points do
		local held=points[i]
		pcall(frame.SetPoint,frame,held[1],held[2]or UIParent,held[3],held[4],held[5])
	end
	return true
end

local boundResize

function A.applyWindowScale(from,stored)
	local new=scaleFactor()
	local scaled,refused,moved=0,0,0
	for i=1,#scaledWindows do
		local held=scaledWindows[i]
		local frame=held.frame
		local okOld,old=pcall(frame.GetScale,frame)
		old=okOld and type(old)=="number"and old>0 and old or 1
		if math.abs(old-new)>0.0001 and convertAnchors(frame,old/new)then
			moved=moved+1
		end
		if pcall(frame.SetScale,frame,new)then
			scaled=scaled+1
		else
			refused=refused+1
		end
		local screenW,screenH=A.screenSizeFor(frame)
		local okW,width=pcall(frame.GetWidth,frame)
		local okH,height=pcall(frame.GetHeight,frame)
		if okW and type(width)=="number"and type(screenW)=="number"and width>screenW then
			pcall(frame.SetWidth,frame,screenW)
		end
		if okH and type(height)=="number"and type(screenH)=="number"and height>screenH then
			pcall(frame.SetHeight,frame,screenH)
		end
		if held.onScaled then
			pcall(held.onScaled,frame,type(stored)=="number"and stored or nil)
		end
	end
	for k=1,#order do
		local kind=order[k]
		local spec=specs[kind]
		if spec and spec.frame then
			pcall(boundResize,spec.frame,kind)
		end
		local entry=spec and ownerOf(kind)==kind and A.storedGeometry(kind)or nil
		if entry and type(stored)=="number"and entry.point then
			entry.x,entry.y=(entry.x or 0)*stored,(entry.y or 0)*stored
			A.setStoredGeometry(kind,entry)
		elseif entry and stored=="restore"and spec.frame then
			typedSize[ownerOf(kind)]=nil
			A.applyStoredGeometry(kind)
		end
	end
	if type(stored)=="number"then
		for i=1,#storedPlaces do
			pcall(storedPlaces[i],stored)
		end
	end
	A.trace("scale",{
		windowScale=A.windowScaleApplied(),
		scaleFrom=from,
		scaled=scaled,
		scaleRefused=refused,
		anchorsMoved=moved,
		placesStored=type(stored)=="number"and"converted"or stored=="restore"and"restored"or"kept",
	},"ui")
	return scaled,refused
end

function A.setWindowScale(value,from)
	local db=A.db()
	if not db then
		return false
	end
	local want=scaleStep(value)
	if want==nil then
		return false
	end
	local before=A.windowScale()
	db.ui=db.ui or{}
	db.ui.windowScale=want~=SCALE_DEFAULT and want or nil
	sessionScale=nil
	if A.notifyWindowScaleSetting then
		pcall(A.notifyWindowScaleSetting)
	end
	A.applyWindowScale(type(from)=="string"and from or"setting",before/want)
	return true
end

function A.windowScaleLines()
	local out={}
	out[1]=("window scale %d%% stored, %s this session, %d%% applied"):format(A.windowScale(),
		sessionScale and(sessionScale.."%")or"none typed",A.windowScaleApplied())
	if#scaledWindows==0 then
		out[2]="no window is built yet, so none has taken the scale"
		return out
	end
	for i=1,#scaledWindows do
		local held=scaledWindows[i]
		local okScale,effective=pcall(held.frame.GetEffectiveScale,held.frame)
		local okShown,shown=pcall(held.frame.IsShown,held.frame)
		local figure=okScale and A.unitFigure(effective)or nil
		out[#out+1]=("  %s  effective %s, %s"):format(held.name or("window "..i),
			figure and("%.2f"):format(figure)or"unread",okShown and(shown and"shown"or"hidden")or"unread")
	end
	return out
end

function A.setSessionWindowScale(value,from)
	local restore=nil
	if value==nil then
		restore=sessionScale~=nil and"restore"or nil
		sessionScale=nil
	else
		local want=scaleStep(value)
		if want==nil then
			return nil
		end
		sessionScale=want
	end
	A.applyWindowScale(from or"command",restore)
	if type(A.refreshOptionsWindow)=="function"then
		pcall(A.refreshOptionsWindow)
	end
	return A.windowScaleApplied()
end

local function fit(value,floor,ceiling)
	if type(value)~="number"then
		value=floor
	end
	if type(ceiling)=="number"and value>ceiling then
		value=ceiling
	end
	if value<floor then
		value=floor
	end
	return value
end

function A.clampGeometry(kind,geometry)
	local floorW,floorH=A.windowFloor(kind)
	if type(floorW)~="number"or type(floorH)~="number"then
		return nil
	end
	if type(geometry)~="table"then
		return nil
	end

	local screenW,screenH=A.screenSizeFor(specs[kind]and specs[kind].frame or nil)
	local maxW=A.windowCeiling(kind)
	if type(screenW)=="number"and(maxW==nil or screenW<maxW)then
		maxW=screenW
	end

	local out={
		width=fit(geometry.width,floorW,maxW),
		height=fit(geometry.height,floorH,screenH),
	}
	if type(geometry.point)=="string"then
		out.point=geometry.point
		out.x=type(geometry.x)=="number"and geometry.x or 0
		out.y=type(geometry.y)=="number"and geometry.y or 0
	end
	return out
end

local function store(create)
	local db=A.db()
	if not db then
		return nil
	end
	if create then
		db.ui=type(db.ui)=="table"and db.ui or{}
		db.ui.geometry=db.ui.geometry or{}
	end
	return type(db.ui)=="table"and db.ui.geometry or nil
end

function A.storedGeometry(kind)
	if not specs[kind]then
		return nil
	end
	local held=store(false)
	local entry=type(held)=="table"and held[ownerOf(kind)]or nil
	if type(entry)~="table"then
		return nil
	end
	if type(entry.width)~="number"or type(entry.height)~="number"then
		return nil
	end

	local out={width=entry.width,height=entry.height}
	if specs[kind].fits then
		if entry.sized~=nil then
			out.sized=entry.sized==true
		else
			local _,authoredH=A.authoredGeometry(kind)
			out.sized=type(authoredH)=="number"and math.abs(entry.height-authoredH)>1
		end
	end
	if type(entry.point)=="string"then
		out.point=entry.point
		out.x=type(entry.x)=="number"and entry.x or 0
		out.y=type(entry.y)=="number"and entry.y or 0
	end
	return out
end

local function isAuthored(kind,geometry)
	local width,height,point,x,y=A.authoredGeometry(kind)
	if type(width)~="number"then
		return false
	end
	if math.abs(geometry.width-width)>1 or math.abs(geometry.height-height)>1 then
		return false
	end
	if geometry.point==nil then
		return true
	end
	return geometry.point==point and math.abs(geometry.x-x)<=1 and math.abs(geometry.y-y)<=1
end

local function sizeState(geometry)
	local width,height=A.unitFigure(geometry.width),A.unitFigure(geometry.height)
	if width==nil or height==nil then
		return nil
	end
	return A.ringNumber(width).."x"..A.ringNumber(height)
end

function A.setStoredGeometry(kind,geometry)
	if not specs[kind]then
		return false
	end
	local db=A.db()
	if not db then
		return false
	end
	local key=ownerOf(kind)

	local fits=specs[key]and specs[key].fits or specs[kind].fits
	local cleared=geometry==nil or(isAuthored(kind,geometry)and not(fits and geometry.sized==true))
	if cleared then
		local held=store(false)
		if type(held)=="table"then
			held[key]=nil
			if next(held)==nil then
				db.ui.geometry=nil
			end
		end
	else
		local held=store(true)
		if type(held)~="table"then
			return false
		end
		held[key]={
			width=geometry.width,
			height=geometry.height,
			point=geometry.point,
			x=geometry.x,
			y=geometry.y,
		}
		if fits then
			held[key].sized=geometry.sized==true
		end
	end

	A.trace("view",{
		source="geometry",
		state=cleared and"cleared"or sizeState(geometry),
		kind=kind,
	},"ui")
	return true
end

function A.retireSharedGeometry()
	local held=store(false)
	if type(held)~="table"then
		return 0
	end
	local removed=0
	for i=1,#order do
		local kind=order[i]
		local entry=held[kind]
		if entry~=nil and ownerOf(kind)~=kind then
			held[kind]=nil
			removed=removed+1
			local size
			if type(entry)=="table"and type(entry.width)=="number"and type(entry.height)=="number"then
				size=sizeState(entry)
			end
			A.trace("window/retire",{kind=kind,state=size or"unsized"},"ui")
		end
	end
	if removed>0 and next(held)==nil then
		local db=A.db()
		if db and db.ui then
			db.ui.geometry=nil
		end
	end
	return removed
end

if type(A.on)=="function"then
	A.on("PLAYER_LOGIN",function()
		pcall(A.retireSharedGeometry)
	end)
end

local ROOM_BRANCHES={
	["absent"]=true,
	["invalid-rect"]=true,
	["no-value"]=true,
	["read"]=true,
}

function A.roomBranchKnown(branch)
	return type(branch)=="string"and ROOM_BRANCHES[branch]==true
end

function A.rectUnresolved(frame)
	if type(frame)~="table"or type(frame.IsRectValid)~="function"then
		return false
	end
	local asked,valid=pcall(frame.IsRectValid,frame)
	return asked and valid==false
end

function A.roomBelow(region,host)
	if type(region)~="table"or type(host)~="table"then
		return nil,"absent"
	end
	for _,frame in ipairs({region,host})do
		if A.rectUnresolved(frame)then
			return nil,"invalid-rect"
		end
	end
	local okR,lower=pcall(region.GetBottom,region)
	local okH,floor=pcall(host.GetBottom,host)
	if not okR or not okH or type(lower)~="number"or type(floor)~="number"then
		return nil,"no-value"
	end
	local room=A.unitFigure(lower-floor)
	if room==nil then
		return nil,"no-value"
	end
	if room<0 then
		room=0
	end
	return room,"read"
end
function A.bandHeight(frame)
	if not frame then
		return nil,"absent"
	end
	if A.rectUnresolved(frame)then
		return nil,"invalid-rect"
	end
	local ok,height=pcall(frame.GetHeight,frame)
	if not ok or type(height)~="number"or height<0 then
		return nil,"no-value"
	end
	return height,"read"
end

function A.roomsAgree(composed,rect)
	if type(composed)~="number"or type(rect)~="number"then
		return false
	end
	local gap=composed-rect
	if gap<0 then
		gap=-gap
	end
	return gap<1
end

local roomReads={}

function A.noteRoomRead(name,branch,room,region,host,less)
	if type(name)~="string"or name==""then
		return false
	end
	roomReads[name]={
		branch=A.roomBranchKnown(branch)and branch or"absent",
		room=type(room)=="number"and room or nil,
		at=select(2,pcall(A.stamp)),
		region=type(region)=="table"and region or nil,
		host=type(host)=="table"and host or nil,
		less=type(less)=="number"and less or 0,
	}
	return true
end

function A.roomReadNow(name)
	local held=type(name)=="string"and roomReads[name]or nil
	if not held or not held.region or not held.host then
		return nil
	end
	for _,frame in ipairs({held.region,held.host})do
		if type(frame.IsVisible)=="function"then
			local ok,up=pcall(frame.IsVisible,frame)
			if ok and up==false then
				return"unshown",nil
			end
		end
	end
	local room,branch=A.roomBelow(held.region,held.host)
	if type(room)=="number"then
		room=room-held.less
		if room<0 then
			room=0
		end
	end
	return branch,room
end

function A.lastRoomRead(name)
	local held=type(name)=="string"and roomReads[name]or nil
	if not held then
		return nil
	end
	return held.branch,held.room,held.at
end

function A.frameGeometry(frame)
	if type(frame)~="table"then
		return nil
	end
	local okW,width=pcall(frame.GetWidth,frame)
	local okH,height=pcall(frame.GetHeight,frame)
	if not okW or not okH or type(width)~="number"or type(height)~="number"then
		return nil
	end

	local out={width=width,height=height}
	local ok,point,relativeTo,_,x,y=pcall(frame.GetPoint,frame,1)
	if ok and type(point)=="string"and(relativeTo==nil or relativeTo==UIParent)then
		out.point=point
		out.x=type(x)=="number"and x or 0
		out.y=type(y)=="number"and y or 0
	end
	return out
end

local function place(frame,geometry)
	local ok=pcall(frame.SetSize,frame,geometry.width,geometry.height)
	if geometry.point then
		pcall(frame.ClearAllPoints,frame)
		pcall(frame.SetPoint,frame,geometry.point,UIParent,geometry.point,geometry.x,geometry.y)
	end
	return ok
end

function A.applyStoredGeometry(kind)
	local spec=specs[kind]
	if not(spec and spec.frame)then
		return false
	end
	local stored=A.storedGeometry(kind)
	if not stored then
		return false
	end
	local clamped=A.clampGeometry(kind,stored)
	if not clamped then
		return false
	end
	return place(spec.frame,clamped)and true or false
end

function A.windowSizeTyped(kind)
	return typedSize[ownerOf(kind)]==true
end

function A.applyWindowGeometry()
	for i=1,#order do
		local kind=order[i]
		local spec=specs[kind]
		if spec and spec.frame then
			local width,height,point,x,y=A.authoredGeometry(kind)
			if type(width)=="number"then
				place(spec.frame,{width=width,height=height,point=point,x=x,y=y})
				typedSize[ownerOf(kind)]=nil
			end
		end
	end
	return true
end

function A.resetWindowGeometry()
	local db=A.db()
	if not db then
		return false
	end
	for i=1,#order do
		if ownerOf(order[i])==order[i]then
			A.setStoredGeometry(order[i],nil)
		end
	end
	A.applyWindowGeometry()
	return true
end

function A.replaceOtherWindows()
	local names,refused=A.replacePlacedWindows()
	if type(A.overlayReplaced)=="function"then
		pcall(A.overlayReplaced)
	end
	local records={}
	if type(A.recascadeMatchWindows)=="function"then
		local ok,moved=pcall(A.recascadeMatchWindows)
		if ok and type(moved)=="table"then
			records=moved
		end
	end

	if type(A.trace)=="function"then
		local anchors,keys={},{}
		for i=1,#records do
			keys[#keys+1]=records[i].key or"?"
			if records[i].frame and type(A.anchorState)=="function"then
				local state=A.anchorState(records[i].frame)
				anchors[#anchors+1]=(records[i].key or"?").."="..(state or"unread")
			end
		end
		A.trace("window/replace",{
			windowsReset=#names>0 and table.concat(names,"+")or nil,
			refusals=refused,
			records=#keys>0 and table.concat(keys,"+")or nil,
			anchors=#anchors>0 and table.concat(anchors," ")or nil,
		},"ui")
	end

	return names,refused,records
end

function A.resetGeometryLines()
	local held,pooled=0,{}
	for i=1,#order do
		local kind=order[i]
		if ownerOf(kind)==kind and A.storedGeometry(kind)~=nil then
			if specs[kind].pooled then
				pooled[#pooled+1]=specs[kind].label
			else
				held=held+1
			end
		end
	end

	if not A.resetWindowGeometry()then
		return{"nothing is stored, so no window geometry could be forgotten"}
	end

	local out={}
	if held==0 and#pooled==0 then
		out[1]="no window geometry was stored, so every window is already at its authored size"
	elseif#pooled==0 then
		out[1]=("%d window%s back at %s authored size and nothing is stored for any window"):format(
			held,held==1 and" is"or"s are",held==1 and"its"or"their")
	else
		local back=held==0 and"no window was put back"
			or("%d window%s back at %s authored size"):format(held,held==1 and" is"or"s are",
				held==1 and"its"or"their")
		out[1]=("%s, the size every %s opens at is forgotten while the ones open keep theirs, and "
			.."nothing is stored for any window"):format(back,table.concat(pooled," and "))
	end

	local names,refused,records=A.replaceOtherWindows()
	local clauses={}
	if#names>0 then
		clauses[#clauses+1]=("%d other window%s put back"):format(#names,#names==1 and""or"s")
	end
	if#records>0 then
		clauses[#clauses+1]=("%d match window%s re-cascaded")
			:format(#records,#records==1 and""or"s")
	end
	if refused>0 then
		clauses[#clauses+1]=("%d refused"):format(refused)
	end

	if#clauses>0 then
		out[#out+1]=table.concat(clauses,", ")
	else
		out[#out+1]="no other window was open, so there was nothing else to put back"
	end
	return out
end

local function anchorPoints(frame)
	local okN,count=pcall(frame.GetNumPoints,frame)
	if not okN or type(count)~="number"then
		return nil,nil
	end
	if count==0 then
		return nil,0
	end
	local names={}
	for i=1,count do
		local ok,point,_,_,x,y=pcall(frame.GetPoint,frame,i)
		if ok and type(point)=="string"then
			local atX,atY=A.unitFigure(x),A.unitFigure(y)
			if atX and atY then
				names[#names+1]=point.."@"..A.ringNumber(atX)..","..A.ringNumber(atY)
			else
				names[#names+1]=point
			end
		else
			names[#names+1]="unread"
		end
	end
	return names,count
end

function A.anchorState(frame)
	local names,count=anchorPoints(frame)
	if not names then
		return nil,count
	end
	return table.concat(names,"+"),count
end

local anchorState=A.anchorState

local function rectState(frame)
	local ok,left,bottom,width,height=pcall(frame.GetRect,frame)
	if not ok then
		return nil
	end
	local atL,atB=A.unitFigure(left),A.unitFigure(bottom)
	local size=sizeState({width=width,height=height})
	if atL==nil or atB==nil or size==nil then
		return nil
	end
	return A.ringNumber(atL)..","..A.ringNumber(atB)..","..size
end

local function givenState(frame)
	local okW,width=pcall(frame.GetWidth,frame,true)
	local okH,height=pcall(frame.GetHeight,frame,true)
	if not okW or not okH then
		return nil
	end
	return sizeState({width=width,height=height})
end

local function boundsState(frame)
	local ok,minW,minH,maxW,maxH=pcall(frame.GetResizeBounds,frame)
	if not ok then
		return nil
	end
	local low=sizeState({width=minW,height=minH})
	local high=sizeState({width=maxW,height=maxH})
	if not(low and high)then
		return nil
	end
	return low.."-"..high
end

local function screenState(frame)
	local width,height=A.screenSizeFor(frame)
	return sizeState({width=width,height=height})
end

local function cursorState()
	if type(GetCursorPosition)~="function"then
		return nil
	end
	local ok,x,y=pcall(GetCursorPosition)
	if not ok then
		return nil
	end
	local scale=1
	if UIParent and type(UIParent.GetEffectiveScale)=="function"then
		local okS,value=pcall(UIParent.GetEffectiveScale,UIParent)
		if okS and type(value)=="number"and value>0 then
			scale=value
		end
	end
	local atX,atY=A.unitFigure(x/scale),A.unitFigure(y/scale)
	if atX==nil or atY==nil then
		return nil
	end
	return A.ringNumber(atX)..","..A.ringNumber(atY)
end

local function placedState(frame)
	if type(frame.IsUserPlaced)~="function"then
		return nil
	end
	local ok,placed=pcall(frame.IsUserPlaced,frame)
	if not ok or type(placed)~="boolean"then
		return nil
	end
	return tostring(placed)
end

local function traceGrip(frame,kind,source,step,total,repaint,stored)
	local live=A.frameGeometry(frame)
	local names,count=anchorState(frame)
	A.trace("view",{
		source=source,
		state=live and sizeState(live)or nil,
		n=count,
		anchors=names,
		rect=rectState(frame),
		given=givenState(frame),
		bounds=boundsState(frame),
		screen=screenState(frame),
		placed=placedState(frame),
		cursor=cursorState(),
		step=step,
		total=total,
		repaint=repaint,
		releaseStored=stored,
		kind=kind,
	},"ui")
end

boundResize=function(frame,kind)
	local floorW,floorH=A.windowFloor(kind)
	if type(floorW)~="number"then
		return false
	end
	local screenW,screenH=A.screenSizeFor(frame)
	local maxW=A.windowCeiling(kind)
	if type(screenW)=="number"and(maxW==nil or screenW<maxW)then
		maxW=screenW
	end
	if type(maxW)=="number"and maxW<floorW then
		maxW=floorW
	end
	local ok=pcall(frame.SetResizable,frame,true)
	if ok then
		pcall(frame.SetResizeBounds,frame,floorW,floorH,maxW,screenH)
	end
	return ok
end

function A.seatGripPoint(grip)
	local frame=type(grip)=="table"and grip.window or nil
	if type(frame)~="table"then
		return nil
	end
	local inset=A.metric("gripInset")
	local panel=rawget(frame,"InsetBg")
	local to,seat=frame,"frame"
	if A.theme()=="blizzard"and type(panel)=="table"then
		to,seat=panel,"inset"
	end
	grip:ClearAllPoints()
	grip:SetPoint("BOTTOMRIGHT",to,"BOTTOMRIGHT",-inset,inset)
	grip.gripSeat=seat
	return seat
end

local function seatGrip(frame,kind,grip)
	frame.grip=grip
	grip.windowKind=kind
	A.seatGripPoint(grip)
	A.raiseGrip(grip)
	pcall(frame.HookScript,frame,"OnShow",function()
		A.raiseGrip(grip)
	end)
end

function A.attachResize(frame,kind,onResize)
	local spec=specs[kind]
	if not(spec and type(frame)=="table")then
		return false
	end
	spec.frame=frame
	A.registerScaledWindow(frame)

	local floorW=A.windowFloor(kind)
	if type(floorW)~="number"then
		return false
	end
	boundResize(frame,kind)

	local pressed,steps,resizedInPress=false,0,false

	local function queueRepaint()
		if queued[kind]then
			return
		end
		queued[kind]=true
		local after=C_Timer and C_Timer.After
		if type(after)~="function"then
			queued[kind]=nil
			if onResize then
				pcall(onResize)
			end
			return
		end
		after(0,function()
			queued[kind]=nil
			if onResize then
				pcall(onResize)
			end
		end)
	end

	frame:SetScript("OnSizeChanged",function()
		if pressed and type(IsMouseButtonDown)=="function"then
			local read,down=pcall(IsMouseButtonDown,"LeftButton")
			if read and down==false then
				pressed=false
			end
		end
		if pressed then
			steps=steps+1
			if steps<=SIZE_STEPS then
				pcall(traceGrip,frame,kind,"grip-size",steps)
			end
			resizedInPress=true
			return
		end
		queueRepaint()
	end)

	local function remember(resized)
		local geometry=A.frameGeometry(frame)
		if not geometry then
			return
		end
		local ratio=A.sessionToStoredRatio()
		local owner=ownerOf(kind)
		if resized then
			typedSize[owner]=nil
		end
		local keepSize=not resized and(ratio~=1 or typedSize[owner]==true)
		if spec.fits then
			local held=A.storedGeometry(kind)
			geometry.sized=resized==true or(held~=nil and held.sized==true)
		end
		if ratio~=1 and geometry.point then
			geometry.x,geometry.y=geometry.x*ratio,geometry.y*ratio
		end
		if keepSize then
			local held=A.storedGeometry(kind)
			local width,height
			if held then
				width,height=held.width,held.height
			else
				width,height=A.authoredGeometry(kind)
			end
			if type(width)=="number"and type(height)=="number"then
				geometry.width,geometry.height=width,height
			end
		end
		A.setStoredGeometry(kind,geometry)
		A.trace("place-stored",{
			kind=kind,
			windowScale=A.windowScaleApplied(),
			placesStored=ratio~=1 and"converted"or"as-read",
			sizeFrom=resized and"drag"or keepSize and(typedSize[owner]and"typed-kept"or"stored")
				or"frame",
		},"ui")
	end
	spec.remember=remember

	if type(A.grip)=="function"then
		local function released()
			pressed=false
			pcall(traceGrip,frame,kind,"grip-release",nil,steps,tostring(resizedInPress))
			remember(resizedInPress)
			if resizedInPress then
				resizedInPress=false
				queueRepaint()
			end
		end
		local function pressedDown()
			steps=0
			resizedInPress=false
			pcall(traceGrip,frame,kind,"grip-press")
			pressed=true
		end
		local function sizingStarted()
			pcall(traceGrip,frame,kind,"grip-started")
		end
		local built,grip=pcall(A.grip,frame,released,pressedDown,sizingStarted)
		if built and grip then
			seatGrip(frame,kind,grip)
		end
	end

	A.applyStoredGeometry(kind)
	return true
end

function A.attachPooledResize(frame,kind,hooks)
	local spec=specs[kind]
	if not(spec and spec.pooled and type(frame)=="table"and type(hooks)=="table")then
		return false
	end
	local floorW,floorH=A.windowFloor(kind)
	if type(floorW)~="number"then
		return false
	end
	A.registerScaledWindow(frame)
	local screenW,screenH=A.screenSizeFor(frame)

	if not pcall(frame.SetResizable,frame,true)then
		return false
	end
	pcall(frame.SetResizeBounds,frame,floorW,floorH,screenW,screenH)

	local pressed,steps,resized,before=false,0,false,nil
	frame:SetScript("OnSizeChanged",function()
		if pressed and type(IsMouseButtonDown)=="function"then
			local read,down=pcall(IsMouseButtonDown,"LeftButton")
			if read and down==false then
				pressed=false
			end
		end
		if not pressed then
			return
		end
		steps=steps+1
		if steps<=SIZE_STEPS then
			pcall(traceGrip,frame,kind,"grip-size",steps)
		end
		resized=true
	end)

	local function repaint()
		if type(hooks.repaint)~="function"then
			return
		end
		local after=C_Timer and C_Timer.After
		if type(after)~="function"then
			pcall(hooks.repaint,frame)
			return
		end
		after(0,function()
			pcall(hooks.repaint,frame)
		end)
	end

	local function released()
		pressed=false
		local stored
		if type(hooks.release)=="function"then
			local ok,held=pcall(hooks.release,frame,before)
			stored=ok and tostring(held==true)or"unread"
		end
		pcall(traceGrip,frame,kind,"grip-release",nil,steps,tostring(resized),stored)
		if resized then
			resized=false
			repaint()
		end
	end
	local function pressedDown()
		steps=0
		resized=false
		before=A.frameGeometry(frame)
		pcall(traceGrip,frame,kind,"grip-press")
		pressed=true
	end
	local function sizingStarted()
		pcall(traceGrip,frame,kind,"grip-started")
	end

	if type(A.grip)~="function"then
		return false
	end
	local built,grip=pcall(A.grip,frame,released,pressedDown,sizingStarted)
	if not(built and grip)then
		return false
	end
	seatGrip(frame,kind,grip)
	return true
end

function A.pooledOpenSize(kind)
	local stored=A.storedGeometry(kind)
	if not stored then
		return nil
	end
	return A.clampGeometry(kind,{width=stored.width,height=stored.height})
end

local function sizeFigure(kind,word,axis,current,frame)
	local number=tonumber(word)
	if number then
		if number~=number or number==math.huge or number==-math.huge then
			return nil
		end
		return number
	end
	local floorW,floorH=A.windowFloor(kind)
	local authoredW,authoredH=A.authoredGeometry(kind)
	if word=="min"then
		return axis=="width"and floorW or floorH
	elseif word=="authored"then
		return axis=="width"and authoredW or authoredH
	elseif word=="same"then
		return current
	elseif word=="max"then
		local screenW,screenH=A.screenSizeFor(frame)
		if axis=="height"then
			return screenH
		end
		return A.windowCeiling(kind)or screenW
	end
	return nil
end

function A.sizeWindow(kind,widthWord,heightWord)
	local spec=specs[kind]
	if not spec then
		return nil,"kind"
	end
	local target=A.windowFrameOf(kind)
	if not target then
		return nil,"not built"
	end
	local live=A.frameGeometry(target)
	if not live then
		return nil,"unread"
	end
	local width=sizeFigure(kind,widthWord,"width",live.width,target)
	if width==nil then
		return nil,"width"
	end
	local height=sizeFigure(kind,heightWord or widthWord,"height",live.height,target)
	if height==nil then
		return nil,"height"
	end
	local clamped=A.clampGeometry(kind,{width=width,height=height})
	if not clamped then
		return nil,"unread"
	end
	if spec.pooled and spec.sized then
		pcall(spec.sized,target,clamped)
	else
		pcall(target.SetSize,target,clamped.width,clamped.height)
		typedSize[ownerOf(kind)]=true
	end
	local applied=A.frameGeometry(target)
	A.trace("view",{
		source="typed-size",
		state=applied and sizeState(applied)or nil,
		kind=kind,
	},"ui")
	return applied
end

function A.rememberWindow(kind)
	local spec=specs[kind]
	if not(spec and spec.remember)then
		return false
	end
	spec.remember()
	return true
end

local HALVES={"matches","players","stats"}
local RIGHT_HALVES={"settings","about"}
local HALF_WORDS={matches="History",stats="Stats",players="Players",settings="Settings",
	about="About"}
local OTHER_HALF={matches="players",players="matches"}

local lastHalf=nil

local switchingHalf=false

function A.closeWithMainEnabled()
	local db=A.db()
	if not db or type(db.ui)~="table"then
		return true
	end
	return db.ui.closeWithMain~=false
end

function A.setCloseWithMain(on)
	local db=A.db()
	if not db then
		return false
	end
	if type(db.ui)~="table"then
		db.ui={}
	end
	if on then
		db.ui.closeWithMain=nil
	else
		db.ui.closeWithMain=false
	end
	if A.notifyCloseWithMainSetting then
		A.notifyCloseWithMainSetting()
	end
	return true
end

function A.mainWindowHidden(half)
	if switchingHalf then
		return nil
	end
	if not A.closeWithMainEnabled()then
		A.trace("close-with",{source=half,state="off"},"ui")
		return nil
	end
	local matches=type(A.closeMatchWindows)=="function"and A.closeMatchWindows()or nil
	local players=type(A.closePlayerWindows)=="function"and A.closePlayerWindows()or nil
	A.trace("close-with",{source=half,state="on",matches=matches,players=players},"ui")
	return matches,players
end

function A.reportCloseAll(word)
	if word=="on"or word=="off"then
		local wanted=word=="on"
		if not A.setCloseWithMain(wanted)then
			A.say("no database, so the setting could not be stored")
			return
		end
		A.say("match and player windows close with the main window "..(wanted and"on"or"off"))
		return
	end

	if word then
		A.say(("unknown closeall command %q. on or off"):format(word))
		return
	end

	local matches=type(A.matchWindowsOpen)=="function"and#A.matchWindowsOpen()or nil
	local players=type(A.playerWindowsOpen)=="function"and#A.playerWindowsOpen()or nil
	A.say(("match and player windows close with the main window %s, %s match %s and %s player %s open")
		:format(A.closeWithMainEnabled()and"on"or"off",
			tostring(matches),matches==1 and"window"or"windows",
			tostring(players),players==1 and"window"or"windows"))
end

function A.shareCorner(from,kind)
	local source,target=A.windowFrameOf(from),A.windowFrameOf(kind)
	if type(source)~="table"or type(target)~="table"or type(UIParent)~="table"then
		return false,false
	end
	local ok,left,bottom,width,height=pcall(source.GetRect,source)
	local _,parentHeight=A.screenSizeFor(target)
	if not ok or type(left)~="number"or type(bottom)~="number"or type(height)~="number"
		or type(parentHeight)~="number"
	then
		return false,false
	end
	local sized=false
	if type(width)=="number"then
		sized=pcall(target.SetSize,target,width,height)
	end
	pcall(target.ClearAllPoints,target)
	pcall(target.SetPoint,target,"TOPLEFT",UIParent,"TOPLEFT",left,bottom+height-parentHeight)
	return true,sized,rectState(source)
end

local function carryHidden(from,kind)
	local source,target=A.windowFrameOf(from),A.windowFrameOf(kind)
	if type(source)~="table"or type(target)~="table"then
		return false
	end
	local geometry=A.frameGeometry(source)
	if not geometry then
		return false
	end
	return place(target,geometry)
end

function A.takeHalf(kind)
	local other=OTHER_HALF[kind]
	local from=other and A.windowFrameOf(other)
	if type(from)~="table"then
		if other then
			lastHalf=kind
		end
		return false
	end
	local ok,shown=pcall(from.IsShown,from)
	if not(ok and shown)then
		if lastHalf==other then
			local carried=carryHidden(other,kind)
			A.trace("half",{source=kind,format=other,state=carried and"carried"or"uncarried"},
				"ui")
		end
		lastHalf=kind
		return false
	end
	local cornered,sized,rect=A.shareCorner(other,kind)
	switchingHalf=true
	pcall(from.Hide,from)
	switchingHalf=false
	local state="unmoved"
	if cornered then
		state=sized and"moved"or"cornered"
	end
	A.trace("half",{source=kind,format=other,state=state,rect=rect},"ui")
	lastHalf=kind
	return true
end

function A.openHalf(kind)
	if kind=="players"then
		return A.showNotes and A.showNotes()or false
	end
	if kind=="settings"then
		local where,why=A.openSettings()
		if not where and type(A.settingsRefused)=="function"then
			A.say(A.settingsRefused(why))
		end
		return where~=nil
	end
	if kind=="about"then
		return A.showAboutBody and A.showAboutBody()or false
	end
	if type(A.showWindowBody)=="function"then
		return A.showWindowBody(kind=="stats"and"stats"or"history")
	end
	return A.showWindow and A.showWindow()or false
end

function A.setHalfTabsChosen(tabs,chosen)
	if type(tabs)~="table"then
		return false
	end
	local held=false
	for i=1,#tabs do
		local tab=tabs[i]
		if type(tab)=="table"then
			A.setPanelTabSelected(tab,tab.halfKind==chosen)
			held=held or tab.halfKind==chosen
		end
	end
	return held
end

function A.halfTabs(frame,chosen)
	local tabs={}
	local function build(kind)
		local tab=A.panelTab(frame,HALF_WORDS[kind],function()
			A.openHalf(kind)
		end)
		tab.halfKind=kind
		A.setPanelTabSelected(tab,kind==chosen)
		tab:Show()
		return tab
	end

	for i=1,#HALVES do
		local tab=build(HALVES[i])
		if i==1 then
			tab:SetPoint("TOPLEFT",frame,"BOTTOMLEFT",A.metric("panelTabInset"),
				A.metric("panelTabOverlap"))
		else
			tab:SetPoint("TOPLEFT",tabs[i-1],"TOPRIGHT",A.metric("panelTabGap"),0)
		end
		tabs[i]=tab
	end

	local right={}
	for i=1,#RIGHT_HALVES do
		local tab=build(RIGHT_HALVES[i])
		if i==1 then
			tab:SetPoint("TOPRIGHT",frame,"BOTTOMRIGHT",-A.metric("panelTabInset"),
				A.metric("panelTabOverlap"))
		else
			tab:SetPoint("TOPRIGHT",right[i-1],"TOPLEFT",-A.metric("panelTabGap"),0)
		end
		right[i]=tab
	end
	for i=#right,1,-1 do
		tabs[#tabs+1]=right[i]
	end
	return tabs
end

local function figure(value)
	local rounded=A.unitFigure(value)
	if not rounded then
		return"unknown"
	end
	return("%.2f"):format(rounded)
end

local function anchorClause(frame)
	local names,count=anchorPoints(frame)
	if type(count)~="number"then
		return"anchors unread"
	end
	if count==0 or not names then
		return"on no point"
	end
	local bare={}
	for i=1,#names do
		bare[i]=names[i]:match("^([^@]+)")or names[i]
	end
	if count==1 then
		return"on one point, "..bare[1]
	end
	return("on %d points, %s"):format(count,table.concat(bare," and "))
end

function A.geometryLines()
	local out={}
	for i=1,#order do
		local kind=order[i]
		local spec=specs[kind]
		local width,height=A.authoredGeometry(kind)
		local floorW,floorH=A.windowFloor(kind)

		local ceiling=A.windowCeiling(kind)
		out[#out+1]=("%s  authored %sx%s, smallest %sx%s, largest %s")
			:format(spec.label,figure(width),figure(height),figure(floorW),figure(floorH),
				ceiling and(figure(ceiling).." wide, the screen tall")or"the screen")

		local ownW=ownFloor(kind)
		local binder
		if type(ownW)=="number"and type(floorW)=="number"and ownW<floorW then
			local group=groupOf(kind)
			for g=1,#group do
				if group[g]~=kind and ownFloor(group[g])==floorW then
					binder=group[g]
					break
				end
			end
		end
		local why=type(A.matchFloorReason)=="function"and kind=="matches"and A.matchFloorReason()
			or nil
		if binder and why then
			out[#out+1]=("    smallest because the %s half needs it; alone this stops at %s because %s")
				:format(A.windowLabel(binder)or binder,figure(ownW),why)
		elseif binder then
			out[#out+1]=("    smallest because the %s half needs it; alone this stops at %s")
				:format(A.windowLabel(binder)or binder,figure(ownW))
		elseif why then
			out[#out+1]="    smallest because "..why
		end

		local shares=A.windowShares(kind)
		if shares then
			out[#out+1]=("    one size and place with the %s, stored under its entry")
				:format(A.windowLabel(shares)or shares)
		end

		local stored=A.storedGeometry(kind)
		if stored then
			local where=stored.point
				and(" at %s %s, %s"):format(stored.point,figure(stored.x),figure(stored.y))
				or", no stored position"
			out[#out+1]=("    stored %sx%s%s"):format(figure(stored.width),figure(stored.height),where)
		else
			out[#out+1]="    stored nothing, so it opens at the authored size"
		end

		local shown=A.windowFrameOf(kind)
		local live=shown and A.frameGeometry(shown)or nil
		if shown and live then
			local okW,givenW=pcall(shown.GetWidth,shown,true)
			local okH,givenH=pcall(shown.GetHeight,shown,true)
			local given=(okW and okH and type(givenW)=="number"and type(givenH)=="number")
				and(", given %sx%s"):format(figure(givenW),figure(givenH))or", given size unread"
			out[#out+1]=("    applied %sx%s %s%s%s"):format(figure(live.width),figure(live.height),
				anchorClause(shown),given,spec.pooled and", on the newest one open"or"")
			if not spec.pooled and A.windowSizeTyped(kind)then
				out[#out+1]="    the applied size was typed this session, so a move stores the stored size beside it"
			end
		elseif spec.pooled then
			out[#out+1]=("    applied nothing, no %s being open"):format(spec.label)
		else
			out[#out+1]="    applied nothing, the window not having been built this session"
		end
	end

	local rows=A.placedWindows()
	if#rows>0 then
		out[#out+1]=("%d window%s %s one authored place")
			:format(#rows,#rows==1 and""or"s",#rows==1 and"carries"or"carry")
		for i=1,#rows do
			local row=rows[i]
			local live=row.frame and A.frameGeometry(row.frame)or nil
			local size=live and("applied %sx%s"):format(figure(live.width),figure(live.height))
				or"size unread"
			local held=row.stored and("stored at %s %s"):format(row.stored.point,
				figure(row.stored.x)..", "..figure(row.stored.y))or"stores nothing"
			out[#out+1]=("    %s  authored at %s %s, %s, %s, %s")
				:format(row.name or("window "..i),row.point,figure(row.x)..", "..figure(row.y),
					held,size,row.frame and anchorClause(row.frame)or"anchors unread")
		end
	else
		out[#out+1]="no window with one authored place has been built this session"
	end
	return out
end
