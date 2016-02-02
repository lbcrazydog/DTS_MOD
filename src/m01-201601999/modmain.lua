local _G = GLOBAL
local master,main,summer,winter,cave01,cave02,cave03 = "1","101","102","103","201","202","203"
local MapsLink = {
  [master] = {name = "出生界",   portlink = {[1]= main,[2]= main,[3]=cave01,[4]=cave01}},
  [main]   = {name = "固定界",   portlink = {[1]= master,[2]= master,[3]=summer,[4]=summer,[5]=cave01,[6]=cave01,[7]=winter,[8]=winter}},
  [summer] = {name = "永夏界",   portlink = {[1]=cave01,[2]=cave01,[3]=main,[4]=main,[5]=winter,[6]=winter}},
  [winter] = {name = "永冬界",   portlink = {[1]=cave03,[2]=cave03,[5]=summer,[6]=summer,[7]=main,[8]=main}},
  [cave01] = {name = "出生界洞穴", portlink = {[3]=master,[4]=master,[5]=main,[6]=main}},
  [cave02] = {name = "永夏界洞穴", portlink = {[1]=summer,[2]=summer}},
  [cave03] = {name = "永冬界洞穴", portlink = {[1]=winter,[2]=winter}},
}
local function IntPort()
  local ports,num,worldid = {},1,_G.TheShard:GetShardId()
  if MapsLink[worldid] then
    for k,v in pairs(_G.Ents) do if table.contains({"cave_entrance","cave_entrance_open","cave_exit"},v.prefab) then ports[k] = num num = num + 1 end end
    if num > 10 then
      for n,p in pairs(ports) do if MapsLink[worldid].portlink[p] then _G.Ents[n].components.worldmigrator:SetID(p) else _G.Ents[n]:Remove() end end
    end
  end
end
local function ManualLinkPort()
  local worldid = _G.TheShard:GetShardId()
  if MapsLink[worldid] then
    local ports = {}
    for k,v in pairs(_G.Ents) do if table.contains({"cave_entrance","cave_entrance_open","cave_exit"},v.prefab) then ports[k] = v end end
    for n,p in pairs(ports) do
      local pid = p.components.worldmigrator.id
      if pid and MapsLink[worldid].portlink[pid] then
        p.components.worldmigrator:SetDestinationWorld(MapsLink[worldid].portlink[pid],true)
        p.components.worldmigrator:SetReceivedPortal(MapsLink[worldid].portlink[pid],pid)
        print(string.format("--------------------------------------Manual link %s[%d] to %s[%d]",worldid,pid,MapsLink[worldid].portlink[pid],pid))
      end
    end
  end
end
local function SetSeason()
  if _G.TheShard:GetShardId() == summer then
    if not _G.TheWorld.state.issummmer then
      _G.TheWorld:PushEvent("ms_setseason", "summer")
      _G.TheWorld:PushEvent("ms_advanceseason")
      _G.TheWorld:PushEvent("ms_advanceseason")
      _G.TheWorld:PushEvent("ms_setseasonlength", {season = "spring", length = 0})
      _G.TheWorld:PushEvent("ms_setseasonlength", {season = "autumn", length = 0})
      _G.TheWorld:PushEvent("ms_setseasonlength", {season = "winter", length = 0})
      _G.TheWorld:PushEvent("ms_setseasonlength", {season = "summer", length = 20})
    end
    _G.TheWorld:PushEvent("ms_setclocksegs", {day = 14,night = 0,dusk = 2})
  elseif _G.TheShard:GetShardId() == winter then
    if not _G.TheWorld.state.iswinter then
      _G.TheWorld:PushEvent("ms_setseason", "winter")
      _G.TheWorld:PushEvent("ms_advanceseason")
      _G.TheWorld:PushEvent("ms_advanceseason")
      _G.TheWorld:PushEvent("ms_setseasonlength", {season = "spring", length = 0})
      _G.TheWorld:PushEvent("ms_setseasonlength", {season = "autumn", length = 0})
      _G.TheWorld:PushEvent("ms_setseasonlength", {season = "summer", length = 0})
      _G.TheWorld:PushEvent("ms_setseasonlength", {season = "winter", length = 20})
    end
    _G.TheWorld:PushEvent("ms_setclocksegs", {day = 2,night = 14,dusk = 0})
  end
end
local function ResetCave()
  if (_G.TheShard:GetShardId()==cave02 or _G.TheShard:GetShardId()==cave03) and _G.TheWorld.state.cycles > 140 and math.mod((_G.TheWorld.state.cycles-34),140) < 5 then
    _G.TheWorld:DoTaskInTime(10, function() _G.TheNet:Announce("永夏洞穴及永冬洞穴将于游戏内明天重置,请在洞内的基友在1分钟内离开!!") end)
    _G.TheWorld:DoTaskInTime(70, function() for _,v in pairs(_G.AllPlayers) do _G.TheWorld:PushEvent("ms_playerdespawnandmigrate",{player=v,portalid=1, worldid="1"}) end end)
    _G.TheWorld:DoTaskInTime(80, function() _G.SaveGameIndex:DeleteSlot(_G.SaveGameIndex:GetCurrentSaveSlot(),_G.StartNextInstance({reset_action = _G.RESET_ACTION.LOAD_SLOT, save_slot = _G.SaveGameIndex:GetCurrentSaveSlot()}),true) end)
  end
end
local function OnIntworld(inst)
  if inst.Info.isinit == false then
    SetSeason()
    IntPort()
    ManualLinkPort()
    inst.Info.isinit = true
    print("--------------------------------------OnIntworld(world) has done!!")
  end
end
local _ToReSpawnPrefabs={["beefalo"]=20,["lightninggoat"]=20,["rook"]=10,["bishop"]=10,["knight"]=10,["rook_nightmare"]=10,["bishop_nightmare"]=10,["knight_nightmare"]=10,["wall_ruins"]=1,["ruins_statue_head"]=1,["ruins_statue_mage"]=1,["ruins_statue_mage_nogem"]=1,["rock_flintless"]=1,["rock_flintless_low"]=1,["rock_flintless_med"]=1,["rock1"]=1,["rock2"]=1,["cactus"]=1,["reeds"]=1}
local function SaveReSpawnInfo(world)
  if world.Info.isrespawnsave == false then
    for k,v in pairs(_G.Ents) do
      if v.prefab and _ToReSpawnPrefabs[v.prefab] then
        local X,Y,Z = v.Transform:GetWorldPosition()
        table.insert(world.Info["respawnlist"],{prefab =v.prefab,x=X,z=Z,range=_ToReSpawnPrefabs[v.prefab]})
      end
    end
    world.Info.isrespawnsave = true
    print(" --------------------------------------SaveReSpawnInfo(world) has done!!")
  end
end
local function DoReSpawn()
  if _G.TheWorld.Info and _G.TheWorld.Info["respawnlist"] then
    local torespawn = {}
    for _,v in pairs(_G.TheWorld.Info["respawnlist"]) do
      local should = true
      if table.len(_G.TheSim:FindEntities(v.x,0,v.z,10,{"M_Private"},{"INLIMBO"}))==0 then
        for _,p in pairs(_G.TheSim:FindEntities(v.x,0,v.z,v.range)) do if p.prefab == v.prefab then should = false break end end
        if should then table.insert(torespawn,{prefab =v.prefab,x = v.x,z = v.z}) end
      end
    end
    for _,v in pairs(torespawn) do _G.SpawnPrefab(v.prefab).Transform:SetPosition(v.x,0,v.z) end
    _G.TheNet:Announce(MapsLink[_G.TheShard:GetShardId()].name.."矿石等资源已重生 !! 共计 : "..tostring(#torespawn))
  end
end
local function AutoSpawn()
  if _G.TheWorld.state.iswinter and (_G.TheShard:GetShardId() == cave01 or _G.TheShard:GetShardId() == master) then DoReSpawn() end
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
  inst:ListenForEvent("ms_playerspawn",OnIntworld)
  inst:ListenForEvent("ms_registermigrationportal",SaveReSpawnInfo)
  inst:ListenForEvent("ms_setseason",AutoSpawn)
  inst:ListenForEvent("ms_setseason",ResetCave)
  inst.OnSave_old = inst.OnSave
  inst.OnSave = OnSave
  inst.OnLoad_old = inst.OnLoad
  inst.OnLoad = OnLoad
end)
function _G.WorldInt()
  SetSeason()
  IntPort()
  ManualLinkPort()
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
