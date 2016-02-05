modimport("wmessage.lua")
local _G = GLOBAL
local shard=SetModVariables("shard")
local MapsInfo=SetModVariables("mapsinfo")
local _ToReSpawnPrefabs=SetModVariables("respawnprefabs")
local master,main,summer,winter,cave01,cave02,cave03 =shard.master,shard.main,shard.summer,shard.winter,shard.cave01,shard.cave02,shard.cave03
local function TpyePortLink()
  for _,v in pairs(_G.Ents) do if v.components.worldmigrator then print(string.format("%s (%2.2f,%2.2f,%2.2f)",_G.TheShard:GetShardId().."["..tostring(v.components.worldmigrator.id or -1).."] <--- "..(v.components.worldmigrator.auto and "A" or "M").. " ["..tostring(v.components.worldmigrator._status==0 and "OK" or "NO" ).."] ---> "..(v.components.worldmigrator.linkedWorld or "<nil>").."["..tostring(v.components.worldmigrator.receivedPortal or -1).."]  ",v.Transform:GetWorldPosition())) end end
end
local function IntPort()
  local ports,num,worldid = {},1,_G.TheShard:GetShardId()
  if MapsInfo[worldid] then
    for k,v in pairs(_G.Ents) do if table.contains({"cave_entrance","cave_entrance_open","cave_exit"},v.prefab) then ports[k] = num num = num + 1 end end
    if num > 10 then for n,p in pairs(ports) do if MapsInfo[worldid].portlink[p] then _G.Ents[n].components.worldmigrator:SetID(p) else _G.Ents[n]:Remove() end end end
  end
end
local function ManualLinkPort()
  local worldid = _G.TheShard:GetShardId()
  if MapsInfo[worldid] then
    local ports = {}
    for k,v in pairs(_G.Ents) do if table.contains({"cave_entrance","cave_entrance_open","cave_exit"},v.prefab) then ports[k] = v end end
    for n,p in pairs(ports) do
      local pid = p.components.worldmigrator.id
      if pid and MapsInfo[worldid].portlink[pid] then
        p.components.worldmigrator:SetDestinationWorld(MapsInfo[worldid].portlink[pid],true)
        p.components.worldmigrator:SetReceivedPortal(MapsInfo[worldid].portlink[pid],pid)
      end
    end
    TpyePortLink()
  end
end
local function SetSeason()
  local worldid = _G.TheShard:GetShardId()
  if MapsInfo[worldid] and type(MapsInfo[worldid].season)=="table" then
    for _,v in pairs({"spring","autumn","winter","summer"}) do
      if type(MapsInfo[worldid].season[v])=="number" then
        _G.TheWorld:PushEvent("ms_setseasonlength",{season = v, length = MapsInfo[worldid].season[v]})
      end
    end
  end
  if MapsInfo[worldid] and type(MapsInfo[worldid].day)=="table" then
    local set = {}
    table.assign(set,MapsInfo[worldid].day,{"day","night","dusk"})
    _G.TheWorld:PushEvent("ms_setclocksegs", set)
  end
end
local function OnIntworld()
  SetSeason()
  IntPort()
  ManualLinkPort()
end
local function ResetCave()
  print(">>>>>>>>>>>>>>>>>>>>>>>>>>>ResetCave() working!!")
  for k,v in pairs(_G.Ents) do if v.prefab =="minotaur" then return end end
  _G.TheWorld:DoTaskInTime(10, function() _G.TheNet:Announce(_G.TheWorld.Info.name.."将重置,请在洞内的基友在1分钟内离开!!") end)
  _G.TheWorld:DoTaskInTime(70, function() for _,v in pairs(_G.AllPlayers) do _G.TheWorld:PushEvent("ms_playerdespawnandmigrate",{player=v,portalid=1, worldid="1"}) end end)
  _G.TheWorld:DoTaskInTime(80, function() _G.SaveGameIndex:DeleteSlot(_G.SaveGameIndex:GetCurrentSaveSlot(),_G.StartNextInstance({reset_action = _G.RESET_ACTION.LOAD_SLOT, save_slot = _G.SaveGameIndex:GetCurrentSaveSlot()}),true) end)
end
local function SaveReSpawnInfo()
  print(">>>>>>>>>>>>>>>>>>>>>>>>>>>SaveReSpawnInfo() working!!")
  for k,v in pairs(_G.Ents) do
    if v.prefab and _ToReSpawnPrefabs[v.prefab] then
      local X,Y,Z = v.Transform:GetWorldPosition()
      table.insert(_G.TheWorld.Info.respawnlist,{prefab =v.prefab,x=X,z=Z,range=_ToReSpawnPrefabs[v.prefab]})
    end
  end
  print(">>>>>>>>>>>>>>>>>>>>>>>>>>>>SaveReSpawnInfo() has done!!")
end
local function DoReSpawn()
  print(">>>>>>>>>>>>>>>>>>>>>>>>>>>DoReSpawn() working!!")
  if _G.TheWorld:HasTag("cave") then for _,v in pairs(_G.Ents) do if v.prefab =="minotaur" then return end end end
  if _G.TheWorld.Info and _G.TheWorld.Info.respawnlist then
    local torespawn = {}
    for _,v in pairs(_G.TheWorld.Info.respawnlist) do
      local should = true
      if table.len(_G.TheSim:FindEntities(v.x,0,v.z,10,{"M_Private"},{"INLIMBO"}))==0 then
        for _,p in pairs(_G.TheSim:FindEntities(v.x,0,v.z,v.range)) do if p.prefab == v.prefab then should = false break end end
        if should then table.insert(torespawn,{prefab =v.prefab,x = v.x,z = v.z}) end
      end
    end
    for _,v in pairs(torespawn) do _G.SpawnPrefab(v.prefab).Transform:SetPosition(v.x,0,v.z) end
    print(">>>>>>>>>>>>>>>>>>>>>>>>>>>DoReSpawn() has done!!")
    _G.TheNet:Announce(_G.TheWorld.Info.name.."矿石等资源已重生 !! 共计 : "..tostring(#torespawn))
  end
end
local function OnSave(inst,data)
  if inst.OnSave_old ~= nil then inst.OnSave_old(inst,data) end
  if inst.Info ~= nil then data.Info = inst.Info end
end
local function OnLoad(inst,data)
  if inst.OnLoad_old ~= nil then inst.OnLoad_old(inst,data) end
  if data ~= nil and data.Info ~= nil then inst.Info = data.Info end
end
AddPrefabPostInit("world", function(inst)
  inst.Info = inst.Info or {}
  inst.Info.respawnlist = inst.Info.respawnlist or {}
  inst.Info.isinit = inst.Info.isinit or false
  inst.Info.isrespawnsave = inst.Info.isrespawnsave or false
  inst:ListenForEvent("ms_registermigrationportal",SetSeason)
  inst:ListenForEvent("ms_registermigrationportal",function()
    if not _G.TheWorld.Info.isinit then
      _G.TheWorld:DoTaskInTime(2,OnIntworld)
      _G.TheWorld.Info.isinit=true
    end
  end)
  inst:ListenForEvent("ms_registermigrationportal",function()
    if not _G.TheWorld.Info.isrespawnsave then
      _G.TheWorld:DoTaskInTime(3,SaveReSpawnInfo)
      _G.TheWorld.Info.isrespawnsave = true
      _G.TheWorld.Info.name = MapsInfo[_G.TheShard:GetShardId()].name
      _G.TheWorld.Info.respawncycles = MapsInfo[_G.TheShard:GetShardId()].respawncycles or 0
      _G.TheWorld.Info.resetcycles = MapsInfo[_G.TheShard:GetShardId()].resetcycles or 0
    end
  end)
  inst:ListenForEvent("ms_playerspawn",function()
    if not _G.TheWorld.Info.isinit then
      _G.TheWorld:DoTaskInTime(2,OnIntworld)
      _G.TheWorld.Info.isinit=true
    end
  end)
  inst:ListenForEvent("ms_setseason",function()
    if _G.TheWorld.Info.respawncycles > 0 and _G.TheWorld.state.isautumn and _G.TheWorld.state.remainingdaysinseason<2 then
      _G.TheWorld:DoTaskInTime(10,DoReSpawn)
    end
  end)
  inst:ListenForEvent("ms_cyclecomplete",function()
    if _G.TheWorld.Info.resetcycles > 0 and math.mod(_G.TheWorld.state.cycles,_G.TheWorld.Info.resetcycles)==0 and _G.TheWorld.state.cycles > 140 then
      ResetCave()
    end
  end)
  inst.OnSave_old = inst.OnSave
  inst.OnSave = OnSave
  inst.OnLoad_old = inst.OnLoad
  inst.OnLoad = OnLoad
end)
function _G.WorldInt()
  OnIntworld()
end
function _G.WorldPortLinkManual()
  ManualLinkPort()
end
function _G.ResetShardWorld()
  ResetCave()
end
function _G.ReSpawnWorld()
  DoReSpawn()
end
function _G.CheckPortLink()
  TpyePortLink()
end
