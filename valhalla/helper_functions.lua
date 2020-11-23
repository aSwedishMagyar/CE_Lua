{$lua}
------------------------------------------------------------------------------------------------------------------------------------
--Auto-Assemble Section
------------------------------------------------------------------------------------------------------------------------------------
infHealthDisable = [[
infHealth:
  db 0F B6 87 39 01 00 00
dealloc(newinfHealth)
]]
infHealthEnable = [[
alloc(newinfHealth,100,infHealth)
label(codeinfHealth)
label(returninfHealth)
newinfHealth:
  cmp [rdi+B8],1
  jne codeinfHealth
  jmp returninfHealth
codeinfHealth:
  movzx eax,byte ptr [rdi+00000139]
  ret
infHealth:
  jmp newinfHealth
  nop 2
returninfHealth:
]]
oneHitKillsDisable = [[
oneHitKills:
  db 83 B9 38 01 00 00 00
dealloc(newoneHitKills)
]]
oneHitKillsEnable = [[
alloc(newoneHitKills,100,oneHitKills)
label(codeoneHitKills)
newoneHitKills:
  test edx,edx
  js  codeoneHitKills
  xor edx,edx
  inc edx
codeoneHitKills:
  cmp dword ptr [rcx+00000138],00
  ret
oneHitKills:
  call newoneHitKills
  nop 2
]]
infStaminaDisable = [[
infStamina+0F:
  db 48 89 5C 24 08
infStaminaDodge+07:
  db 40 53 48 83 EC 30
infStaminaMax+4:
  db 0C
]]
infStaminaEnable = [[
infStamina+0F:
  ret
infStaminaDodge+07:
  ret
infStaminaMax+4:
  db 10
]]
infAdrenalineDisable = [[
adrenalineMax:
  db 41 39 F0
]]
infAdrenalineEnable = [[
adrenalineMax:
  db 44 39 C6
]]
infOxygenDisable = [[
oxygenUse:
  db 48 89 5C 24 10
]]
infOxygenEnable = [[
oxygenUse:
  ret
]]
craftCheckDisable = [[
craftCheck:
  db 41 3B FF 49 8D 4E 58
]]
craftCheckEnable = [[
craftCheck:
  db 39 FF 90
]]
hunterDeliveryDisable = [[
hunterDelivery:
  db 48 8B CB 40 84 F6
dealloc(newhunterDelivery)
]]
hunterDeliveryEnable = [[
alloc(newhunterDelivery,100,hunterDelivery)
label(codehunterDelivery)
newhunterDelivery:
  mov edi,270F
codehunterDelivery:
  mov rcx,rbx
  test sil,sil
  ret
hunterDelivery:
  call newhunterDelivery
  nop
]]
getWaypointDisable = [[
getWaypoint:
  db F3 48 0F 2C C0
unregistersymbol(baseWaypoint)
]]
getWaypointEnable = [[
registersymbol(baseWaypoint)
alloc(newgetWaypoint,100,getWaypoint)
label(codegetWaypoint)
newgetWaypoint:
  mov [baseWaypoint],rdi
codegetWaypoint:
  cvttss2si rax,xmm0
  ret
baseWaypoint:
  dq 0
getWaypoint:
  call newgetWaypoint
]]
getBaseCoordsDisable = [[
getBaseCoords:
  db 41 0F 10 55 50
unregistersymbol(baseCoords)
]]
getBaseCoordsEnable = [[
registersymbol(baseCoords)
alloc(newgetBaseCoords,100,getBaseCoords)
label(codegetBaseCoords)
newgetBaseCoords:
  mov [baseCoords],r13
codegetBaseCoords:
  movups xmm2,[r13+50]
  ret
baseCoords:
  dd 0
getBaseCoords:
  call newgetBaseCoords
]]
------------------------------------------------------------------------------------------------------------------------------------
--Inventory Section
------------------------------------------------------------------------------------------------------------------------------------
inventoryDescList = {}
inventoryAddressList = {}
num_items = 0
topRecName = "Get Inventory"
headerDescriptions = {"--Resources--","--Crafting Materials--","--Consumables--","--Runes--","--Collectables--","--Trade Goods--","--Quest Items--","--Treasure Hoard Maps--"}
function debugger_onBreakpoint()
	local bytes = RIP
    local checkInventory = getAddressSafe('bagOpen')
    local removeItems = getAddressSafe('itemUse')
	if bytes == checkInventory then
        local i = 1
        local duplicate = false
        while i <= num_items do
            if inventoryAddressList[i] == RDX then duplicate = true end
            i = i + 1
        end
        if duplicate ~= true then
            num_items = num_items + 1
            local item = findItem(RDX)
            if item ~= nil then
                inventoryAddressList[num_items] = RDX
                createAddress(RDX,item)
            end
        end
        return 1
    elseif bytes == removeItems then
        local itemId = findItem(RBX)
        if itemId ~= nil then
            local jmpFwd = 0
            local ResourcesCheck = readBytes(getAddressSafe('infResources'),1)
            local CraftingMaterialsCheck = readBytes(getAddressSafe('infCraftingMaterials'),1)
            local consumablesCheck = readBytes(getAddressSafe('infConsumables'),1)
            if ((ResourcesCheck == 1) and (tonumber(inventoryDescList[3][itemId]) == 1)) then jmpFwd = 1
            elseif ((CraftingMaterialsCheck == 1) and (tonumber(inventoryDescList[3][itemId]) == 2)) then jmpFwd = 1
            elseif ((consumablesCheck == 1) and (tonumber(inventoryDescList[3][itemId]) == 3)) then jmpFwd = 1 end
			if jmpFwd == 1 then RIP = RIP + 3 end	--Advance instruction pointer to after subtraction
		end
        return 1
    end
	return 0   --allows you to set normal breakpoints and also gives you an error catch
end
function createHeaders()
    local addList = getAddressList()
	local topRec = addList.getMemoryRecordByDescription(topRecName)
    if topRec == nil then return end
    local i = 1
    local numHeaders = getCount(headerDescriptions)
    while i <= numHeaders do
        local statHeader = addList.createMemoryRecord()
	    statHeader.isGroupHeader = true
	    statHeader.options = '[moHideChildren]'
	    statHeader.setDescription(headerDescriptions[i])
	    statHeader.appendToEntry(topRec)
        i = i + 1
    end
end
function findItem(baseAddr)
    local itemHash = readQword(readQword(baseAddr+0x8)+0x10)
    if itemHash ~= nil then
        local i = 1
        local listCount = getCount(inventoryDescList[1])
        while i <= listCount do
            if  tonumber(inventoryDescList[1][i], 16) == itemHash then return i end
            i = i + 1
        end
    end
    return nil
end
function createAddress(baseAddr,itemId)
    if baseAddr == nil then return end
    local currentItemType = inventoryDescList[3][itemId]
    local currentItemName = inventoryDescList[2][itemId]
    local addList = getAddressList()
    local topRec = addList.getMemoryRecordByDescription(headerDescriptions[tonumber(currentItemType)])
    local newRec = addList.createMemoryRecord()
    newRec.setAddress(baseAddr)
    newRec.setDescription(currentItemName)
    newRec.Type = 2    --Items quantity is integer (dword) type
    newRec.appendToEntry(topRec)
end
function populateList(listName)
	local popList = {}
	local file = io.input(listName)
	local i = 1
	while i < 200 do	--Set an upper limit so it does not infinitely loop
		currentLine = file:read("*line")
		if currentLine == nil then break end
		popList[i] = currentLine
		i = i + 1
	end
    file:close()
	return popList
end
function createHashTable(path)
	local hashList = populateList(path.."list_hash.txt")
	local nameList = populateList(path.."list_name.txt")
	local typeList = populateList(path.."list_type.txt")
	local finalList = {hashList,nameList,typeList}
	if hashList == nil or nameList == nil or typeList == nil then return nil end
	return finalList
end
function setupItemUse()
    unregisterSymbol('infResources')
    unregisterSymbol('infCraftingMaterials')
    unregisterSymbol('infConsumables')
    registerSymbol('infResources',allocateMemory(1))
    registerSymbol('infCraftingMaterials',allocateMemory(1))
    registerSymbol('infConsumables',allocateMemory(1))
end
function destroyItemUse()
	deAlloc(getAddressSafe('infResources'))
	deAlloc(getAddressSafe('infCraftingMaterials'))
	deAlloc(getAddressSafe('infConsumables'))
	unregisterSymbol('infResources')
	unregisterSymbol('infCraftingMaterials')
	unregisterSymbol('infConsumables')
end
function debugCheck()
	local debugType = debug_getCurrentDebuggerInterface()  --Just a precaution in case you don't have VEH selected
	if debugType ~= 2 then debugProcess(2) end --Starts debugger using VEH (Thanks Zanzer)
end
------------------------------------------------------------------------------------------------------------------------------------
--Teleport Section
------------------------------------------------------------------------------------------------------------------------------------
highpointsLocations = {
{region="East Anglia",desc="Deor River Highpoint",x=4145.603515625,y=264.48962402344,z=-635.26715087891},
{region="East Anglia",desc="Northwic Highpoint",x=5180.98828125,y=253.05364990234,z=-478.94390869141},
{region="East Anglia",desc="Edmund's Hope Highpoint",x=4771.6586914063,y=280.35406494141,z=-1560.736328125},
{region="Essexe",desc="Colcestre Highpoint",x=4267.2353515625,y=261.17999267578,z=-2688.8251953125},
{region="Essexe",desc="Maeldun Highpoint",x=4878.8491210938,y=287.18978881836,z=-3467.0063476563},
{region="Oxenefordscire",desc="Thaerelea Ruins Highpoint",x=1251.7510986328,y=304.92980957031,z=-1245.3673095703},
{region="Oxenefordscire",desc="Evinghou Tower Highpoint",x=952.42462158203,y=361.71606445313,z=-2288.7983398438},
{region="Ledecestersire",desc="Venonis Highpoint",x=690.40667724609,y=250.70252990723,z=559.88519287109},
{region="East Anglia",desc="Ruined Tower Highpoint",x=5385.2895507813,y=286.19287109375,z=85.487724304199},
{region="Lincolnscire",desc="Cruwland Highpoint",x=2838.1833496094,y=250.85023498535,z=916.40728759766},
{region="Lincolnscire",desc="Lincoln Highpoint",x=2911.4560546875,y=303.91583251953,z=2902.580078125},
{region="Lincolnscire",desc="Wynmere Lake Highpoint",x=2842.0192871094,y=287.63360595703,z=1876.8361816406},
{region="Lincolnscire",desc="Mercian Tower Highpoint",x=4301.3271484375,y=267.91326904297,z=1974.2346191406},
{region="Lincolnscire",desc="Spitalgate Highpoint",x=3344.2248535156,y=286.521484375,z=3981.6413574219},
{region="Lincolnscire",desc="Lacestone Highpoint",x=2294.0346679688,y=263.69259643555,z=4164.6015625},
{region="Ledecestrescire",desc="Ragnarsson Lookout Highpoint",x=1485.6278076172,y=366.92977905273,z=408.33697509766},
{region="Glowecestrescire",desc="Cragstone Watchtower Highpoint",x=-444.16638183594,y=337.59359741211,z=-693.36657714844},
{region="Glowecestrescire",desc="Sabrina's Spring Highpoint",x=-1426.0048828125,y=397.94476318359,z=-1306.4794921875},
{region="Glowecestrescire",desc="Glowecestre Highpoint",x=-1724.81640625,y=257.58462524414,z=-2002.5249023438},
{region="Rygjafylke",desc="Stavanger Highpoint",x=-1757.9622802734,y=297.09997558594,z=-2222.9938964844},
{region="Rygjafylke",desc="Starter Island Highpoint",x=-2468.9497070313,y=295.61376953125,z=-1754.8590087891},
{region="Hordafylk",desc="Plateu Highpoint",x=-1027.7164306641,y=393.0400390625,z=286.38006591797},
{region="Hordafylk",desc="Ulriken Peak Highpoint",x=-37.607830047607,y=430.99572753906,z=497.72387695313},
{region="Rygjafylke",desc="Fornburg Highpoint",x=633.64154052734,y=445.31344604492,z=-2292.5610351563},
{region="Rygjafylke",desc="Fannaraki Summit Highpoint",x=287.44815063477,y=714.37231445313,z=-1130.5841064453}}
userSavedLocations = {}
numSavedLocations = 0
xOffset = 0x50
yOffset = 0x58
zOffset = 0x54
yAdj = 2.5
prevLocation = {}
function createLocationStruct(rg,dc,xCoord,yCoord,zCoord)
	return {region=rg,desc=dsc,x=xCoord,y=yCoord,z=zCoord}
end
function updateLocation(baseAddr,newLocation)
	if baseAddr ~= nil and newLocation ~= nil then
		xCoord = readFloat(baseAddr+xOffset)
		yCoord = readFloat(baseAddr+yOffset)+yAdj
		zCoord = readFloat(baseAddr+zOffset)
		local saveLocation = createLocationStruct("Previous Region","Previous Location",xCoord,yCoord,zCoord)
		writeFloat(baseAddr+xOffset,newLocation.x)
		writeFloat(baseAddr+yOffset,newLocation.y)
		writeFloat(baseAddr+zOffset,newLocation.z)
		return saveLocation
	end
	return nil
end
function saveLocationtoFile(path,svLocation)
    local file = io.open(path,"a")
    file:write("{region=\"",svLocation.region,"\"")
    file:write(",desc=\"",svLocation.desc,"\"")
    file:write(",x=",svLocation.x)
    file:write(",y=",svLocation.y)
    file:write(",z=",svLocation.z,"},\n")
    print(svLocation.desc)
    print(svLocation.x)
    print(svLocation.y)
    print(svLocation.z)
    file:close()
end
function addLocation(baseAddr)
	if baseAddr ~= nil then
		local queryregionDescription = inputQuery('Get Region',"Enter Current Region",'')
		local queryDescription = inputQuery('Get Location',"Enter Location Name",'')
		xCoord = readFloat(baseAddr+xOffset)
		yCoord = readFloat(baseAddr+yOffset)+yAdj
		zCoord = readFloat(baseAddr+zOffset)
		local saveLocation = createLocationStruct(queryregionDescription,queryDescription,xCoord,yCoord,zCoord)
        numSavedLocations = numSavedLocations + 1
        userSavedLocations[numSavedLocations] = saveLocation
		return saveLocation
	end
	return nil
end
function createWaypointLocation(baseAddr)
	if baseAddr ~= nil then
		local saveLocation = {region="",desc="Waypoint",x=0,y=0,z=0}
		saveLocation.x = readFloat(baseAddr+xOffset)
		saveLocation.y = readFloat(baseAddr+yOffset)+yAdj
		saveLocation.z = readFloat(baseAddr+zOffset)
		return saveLocation
	end
	return nil
end
function queryLocation(locationListId)
	local queryForm = createForm(false);
	local locationListComboBox = createComboBox(queryForm)
	queryForm.Caption = "Select Location"
	locationListComboBox.ReadOnly = true
	locationListComboBox.Width = 600
	queryForm.Height = locationListComboBox.Height + 1
	queryForm.Width = locationListComboBox.Width + 3
	locationListComboBox.OnSelect = function()
		queryForm.ModalResult = 1
	end
    local returnLocation = nil
    local tempLocations = {}
    if locationListId == 1 then tempLocations = highpointsLocations
    else tempLocations = userSavedLocations end
    if tempLocations[1] == nil then
        locationListComboBox:Destroy()
	    queryForm:Destroy()
        return nil
    end
    local numLocations = getCount(tempLocations)
    local i
    for i=1,numLocations do
        locationListComboBox.Items.Add("Region: "..tempLocations[i]['region']..", Location: "..tempLocations[i]['desc'])
    end
    queryForm.centerScreen()
	queryForm.showModal()
	if locationListComboBox.ItemIndex >= 0 then
	    returnLocation = tempLocations[locationListComboBox.ItemIndex+1]
	end
	locationListComboBox:Destroy()
	queryForm:Destroy()
    return returnLocation
end
function teleportLocation(baseCoords)
	local selectedLocation = queryLocation()
	updateLocation(baseCoords,selectedLocation)
end
function teleportWaypoint(baseCoords,baseWaypoint)
	local tempLocation = createWaypointLocation(baseWaypoint)
	updateLocation(baseCoords,tempLocation)
end
------------------------------------------------------------------------------------------------------------------------------------
--AOB Section
------------------------------------------------------------------------------------------------------------------------------------
--bytes,symbolName
AOB_List = {
{"8B02488BF189",'bagOpen'},
{"442BC0448903750C418BD7",'itemUse'},
{"0FB68739010000A8010F846219",'infHealth'},
{"83B9380100000041",'oneHitKills'},
{"4139F0410F4EF0",'adrenalineMax'},
{"48895C2410574883EC6080",'oxygenUse'},
{"413BFF498D4E58",'craftCheck'},
{"488BCB4084F67407E834",'hunterDelivery'},
{"8B93B401000085D2746A",'expGain'},
{"C3CCCCCCCCCCCCCCCCCCCCCCCCCCCC48895C2408574883EC408B42",'infStamina'},
{"FFFFC3CCCCCCCC40534883EC30",'infStaminaDodge'},
{"F30F10470CF341",'infStaminaMax'},
{"F3480F2CC03943",'getWaypoint'},
{"410F10555048",'getBaseCoords'}}
function lua_aobscan(bytes,symbolName)
	local baseAddr = getAddress(process)
	local moduleStrSize = getModuleSize(process)
	if moduleStrSize ~= nil then
		local memScanner = createMemScan()
		local memFoundList = createFoundList(memScanner)
		memScanner.firstScan(
		soExactValue,vtByteArray,rtRounded,bytes,nil,
		getAddress(process),(getAddress(process)+moduleStrSize),"",
		fsmNotAligned,"",true,false,false,false)
		memScanner.waitTillDone()
		memFoundList.initialize()
		local returnAddr = nil
		if memFoundList.Count == 1 then
			local foundAdder = memFoundList.Address[0]
			unregisterSymbol(symbolName)
			registerSymbol(symbolName,foundAdder)
			returnAddr = tonumber(foundAdder,16)-baseAddr
		elseif memFoundList.Count > 1 then
			print("Array of Byte not unique: "..bytes)
		else
            print("Array of Byte not found: "..bytes)
        end
		memScanner.destroy()
		memFoundList.destroy()
		return returnAddr
	else
		print("Module "..process.." not found")
		return nil
	end
	return nil
end
------------------------------------------------------------------------------------------------------------------------------------
--Enable/Disable Section
------------------------------------------------------------------------------------------------------------------------------------
function onEnable()
	local aobCount = getCount(AOB_List)
	local i = 1
    local path = getPath()
    path = path.."AOB_Address_List.txt"
    local file = io.input(path)
    local hookAddr = nil
    local AOBCheckList = {}
	for i = 1,aobCount do
		local hookAddr = file:read("*line")
        if hookAddr ~= nil then
            AOBCheckList[i] = true
            unregisterSymbol(AOB_List[i][2])
            registerSymbol(AOB_List[i][2],process.."+"..hookAddr)
        else AOBCheckList[i] = false end
	end
    file:close()
    local redoAOB = false
    for i = 1,aobCount do
		if AOBCheckList[i] == false then redoAOB = true end
	end
    if redoAOB then
		file = io.output(path)
		hookAddr = nil
		for i = 1,aobCount do
			if AOBCheckList[i] ~= true then
				local hookAddr = lua_aobscan(AOB_List[i][1],AOB_List[i][2])
				if hookAddr ~= nil then
					hookAddr = string.upper(string.format("%x", hookAddr))
					file:write(hookAddr,"\n")
				end
			end
		end
		file:close()
    end
end
function onDisable()
	local aobCount = getCount(AOB_List)
	local i = 1
	for i = 1,aobCount do
		unregisterSymbol(AOB_List[i][2])
	end
end
------------------------------------------------------------------------------------------------------------------------------------
--Misc Section
------------------------------------------------------------------------------------------------------------------------------------
function getCount(item)
    if type(item) ~= 'table' then return 1 end
    i = 1
    while item[i] ~= nil do i = i + 1 end
    return i - 1
end
function getPath()
	local path = TrainerOrigin or getMainForm().OpenDialog1.InitialDir
	path = path.."valhalla\\"
	return path
end
[ENABLE]
if process ~= nil then
    onEnable()
    debugCheck()
end
[DISABLE]
onDisable()
