modimport("message.lua")
local _G = GLOBAL
local require    = _G.require
local STRINGS    = _G.STRINGS
local TheNet     = _G.TheNet
local TheSim     = _G.TheSim
local AllPlayers = _G.AllPlayers
local _CMD=SetModVariables("command")
local _MSGA=SetModVariables("announce")
local _MSGT=SetModVariables("talkmsg")
local _MAP=SetModVariables("mapsinfo")
local _GNAME=SetModVariables("gitfname")
local _GITEM=SetModVariables("gitfitem")
local _SITEM=SetModVariables("superitem")
local _SP=SetModVariables("superuser")
local _AJ=SetModVariables("adjust")
local _ET=SetModVariables("eyeturret")
local _SN=SetModVariables("seedsrange")
local _InTown=SetModVariables("townstate")
local _Privilege=SetModVariables("privilege")
local _ActionType=SetModVariables("action")
local _BurnTags=SetModVariables("burntags")
local _QuickPickPrefab=SetModVariables("quickpick")
local _ClearPrefabs=SetModVariables("clearprefabs")
local _ComDist=SetModVariables("cmddis")
local _PlayerInfo=SetModVariables("playerinfo")

local GrantSuperPlayer=false ---超级是否有特权
local ToAddTags  = "Add"        --需添加标签
local ToDelTags  = "Del"        --需移除标签
local IsPrivate  = "IsPrivate"  --是否私有
local IsShare    = "IsShare"    --是否共享
local IsLeft     = "IsLeft"     --失效标识
local IsTown     = "IsTown"     --城镇标签
local IsSuper    = "IsSuper"
local IsGift     = "IsGift"
local IsProtect  = "noattack"
local OwnerID    = "OwnerID_"   --所有者实例前缀
local GrantID    = "GrantID_"   --授权实例标前缀
local SaverID    = "SaverID_"   --失效实例前缀
local Desc       = "Desc"
-----------------------------------
_G.TUNING.PERISH_FRIDGE_MULT=_AJ.fridge ~= 0 and _G.TUNING.PERISH_FRIDGE_MULT/_AJ.fridge or 0
_G.TUNING.DRY_FAST=_AJ.dry~=0 and _G.TUNING.DRY_FAST/_AJ.dry or 10
_G.TUNING.DRY_MED=_AJ.dry~=0 and _G.TUNING.DRY_MED/_AJ.dry or 10
_G.TUNING.BASE_COOK_TIME=_AJ.cook~=0 and _G.TUNING.BASE_COOK_TIME/_AJ.cook or 10
_G.TUNING.HAYWALL_HEALTH=_G.TUNING.HAYWALL_HEALTH*_AJ.wallenhance
_G.TUNING.WOODWALL_HEALTH=_G.TUNING.WOODWALL_HEALTH*_AJ.wallenhance
_G.TUNING.STONEWALL_HEALTH=_G.TUNING.STONEWALL_HEALTH*_AJ.wallenhance
_G.TUNING.RUINSWALL_HEALTH=_G.TUNING.RUINSWALL_HEALTH*_AJ.wallenhance
_G.TUNING.MOONROCKWALL_HEALTH=_G.TUNING.MOONROCKWALL_HEALTH*_AJ.wallenhance
_G.TUNING.EYETURRET_DAMAGE=_ET.dmg
_G.TUNING.EYETURRET_ATTACK_PERIOD=_ET.attack_period
_G.TUNING.EYETURRET_HEALTH=_G.TUNING.EYETURRET_HEALTH*_ET.health
_G.TUNING.EYETURRET_REGEN=_G.TUNING.EYETURRET_REGEN*_ET.regen
_G.TUNING.BERRYBUSH_CYCLES=_AJ.berrybush
-----------------------------------
local function IsSuperPlayer(player)
  return player.userid and _SP[player.userid] or false
end
local function IsSuperUser(player)
  return player.Network ~= nil and player.Network:IsServerAdmin() or (GrantSuperPlayer and IsSuperPlayer(player))
end
local function GetOnlinePlayerById(id)
  for i,p in pairs(AllPlayers) do
    if p.userid==id then return p,i end
  end
end
local function GetPlayerLvl(player)
  local lvl = ((player.Info.HisAge + player.components.age:GetAge())/480+1)/(player.Info.Restart > 4 and (player.Info.Restart-3) or 1) - player.Info.Death*2
  return  lvl > 1 and math.floor(lvl) or 1
end
local function getplayerinfo(player)
  if player and player.components and player.Info then
    local curinfo={}
    curinfo.death = player.Info.Death
    curinfo.restart = player.Info.Restart
    curinfo.ageday = math.floor((player.Info.HisAge + player.components.age:GetAge())/480+1)
    curinfo.maxageday = math.floor(math.max(player.Info.HisMaxAge,player.components.age:GetAge())/480+1)
    curinfo.deathageday = math.floor(player.Info.DeathAge/480)
    curinfo.lvl = GetPlayerLvl(player)
    return curinfo
  end
end
local function GetPlayerDesc(player)
  local msg = getplayerinfo(player)
  if msg then
    return player.name.."\n等 级: "..tostring(msg.lvl).." [生存/(重生-3)-死亡*2]".."\n累 计  生 存 天 数 : "..tostring(msg.ageday).."\n最 长  生 存 天 数 : "..tostring(msg.maxageday).."\n累 计  重 生 次 数 : "..tostring(msg.restart).."\n累 计  死 亡 次 数 : "..tostring(msg.death).."\n累 计  死 亡 天 数 : "..tostring(msg.deathageday)
  end
end
local function GiftRemoveChecker(player)
  if player.Info.Item > 0 and GetPlayerLvl(player) < 30 then
    for _,v in pairs(_G.TheSim:FindEntities(0,0,0,10000,{IsPrivate,IsGift,OwnerID..player.userid})) do v:Remove() end
    player.Info.Item = 0
  end
end
local function OnGiftCheck(player)
  local lvl = math.floor((GetPlayerLvl(player)-10)/20)
  local check = lvl < 1 and 0 or (lvl > 5 and 5 or lvl)
  if player.Info.Item ~= check then
    if check == 0 then
      GiftRemoveChecker(player)
    elseif player.Info.Item == 0 then
      DoGiftGive(player)
    elseif player.Info.Item > check then
      DoGiftDesgrade(player,check)
    elseif player.Info.Item < check then
      DoGiftUpgrade(player,check)
    end
  end
end
local function SyncInfo(inst,player,event)
  if player and player.components and player.Info then
    inst.Info.players[player.userid] = inst.Info.players[player.userid] or table.copy(_PlayerInfo,true)
    if event == "ms_playerjoined" then
      table.assign(player.Info,inst.Info.players[player.userid])
    elseif event == "ms_playerdespawnanddelete" or event == "ms_playerleft" then
      table.assign(inst.Info.players[player.userid],player.Info)
    elseif event == "ms_becameghost" then
      table.assign(inst.Info.players[player.userid],player.Info,{"DeathOn","Death"})
    elseif event == "ms_respawnedfromghost" then
      table.assign(inst.Info.players[player.userid],player.Info,{"DeathOn","DeathAge"})
    end
  end
end
local function SaveHisInfo(player)
  player.Info.RestartOn = _G.os.time()
  player.Info.Restart = player.Info.Restart + 1
  player.Info.HisAge = player.Info.HisAge + player.components.age:GetAge()
  player.Info.HisMaxAge = math.max(player.Info.HisMaxAge,player.components.age:GetAge())
  player.Info.DeathAge = player.Info.DeathAge + (player.Info.DeathOn == 0 and 0 or (player.components.age:GetAge() - player.Info.DeathOn))
  player.Info.DeathOn = 0
  player.Info.Lvl = (player.Info.HisAge/480+1)/(player.Info.Restart > 3 and (player.Info.Restart-3) or 1) - player.Info.Death*2
  player.Info.Lvl = player.Info.Lvl > 1 and math.floor(player.Info.Lvl) or 1
end
local function Onplayerjoined(inst,player)
  SyncInfo(inst,player,"ms_playerjoined")
end
local function Onplayerdespawnanddelete(inst,player)
  SaveHisInfo(player)
  SyncInfo(inst,player,"ms_playerdespawnanddelete")
end
local function Onplayerleft(inst,player)
  SyncInfo(inst,player,"ms_playerdespawnanddelete")
  GiftRemoveChecker(player)
end
local function Onbecameghost(inst,player)
  player.Info.Death = player.Info.Death + 1
  player.Info.DeathOn = player.components.age:GetAge()
  SyncInfo(inst,player,"ms_becameghost")
end
local function Onrespawnedfromghost(inst,player)
  player.Info.DeathAge = player.Info.DeathAge + player.components.age:GetAge() - player.Info.DeathOn
  player.Info.DeathOn = 0
  SyncInfo(inst,player,"ms_respawnedfromghost")
end
local function SpawnGift(player,prefabs)
  for _,v in pairs(prefabs) do
    local gift = _G.SpawnPrefab(v)
    SetInfo(gift,player,_ActionType.OnGift)
    SetGift(gift)
    gift.Transform:SetPosition(player.Transform:GetWorldPosition())
  end
end
local function SetGift(inst)
  if inst.prefab == "minerhat" then
    inst.components.fueled:InitializeFuelLevel(inst.Info.lvl < 4 and (300+600*inst.Info.lvl) or 36000)
  elseif inst.prefab == "armor_sanity" then
    inst.components.equippable.ontakedamage = nil
    inst.components.equippable.dapperness   = 0
    inst.components.armor:InitCondition(inst.Info.lvl < 4 and (500+500*inst.Info.lvl) or 50000,inst.Info.lvl < 4 and (0.45+0.15*inst.Info.lvl) or 0.95)
  elseif inst.prefab == "cane" then
    if inst.components.tool == nil then inst:AddComponent("tool") end
    inst.components.tool:SetAction(_G.ACTIONS.CHOP,1)
    if inst.Info.lvl == 2 then
      inst.components.tool:SetAction(_G.ACTIONS.MINE,1)
    elseif inst.Info.lvl == 3 then
      inst.components.weapon:SetDamage(50)
      inst.components.weapon:SetRange(1)
    end
  elseif inst.prefab == "piggyback" then
    inst.components.equippable.walkspeedmult = 1
    if inst.components.waterproofer == nil then inst:AddComponent("waterproofer") end
    inst.components.waterproofer:SetEffectiveness(_G.TUNING.WATERPROOFNESS_LARGE)
    inst:AddTag("waterproofer")
    if inst.Info.lvl == 2 then
      inst.components.equippable.dapperness = _G.TUNING.DAPPERNESS_SMALL
    elseif inst.Info.lvl == 3 then
      inst:AddTag("fridge")
    end
  elseif inst.prefab == "orangestaff"  or inst.prefab == "greenamulet" then
    inst.components.finiteuses.Use = function(val) return 0 end
  end
end
-----------------------------------
local function HasEntityInRange(x,y,z,radius,musttags,mustoneoftags,notags)
  return table.len(TheSim:FindEntities(x,y,z,radius,musttags,notags,mustoneoftags)) > 0
end
local function InPrivateTown(inst,radius)
  local x,y,z = inst.Transform:GetWorldPosition()
  if inst.userid  and HasEntityInRange(x,y,z,radius,{IsTown}) then
    if HasEntityInRange(x,y,z,radius,{IsTown,OwnerID..inst.userid}) then
      return _InTown.owner
    elseif HasEntityInRange(x,y,z,radius,{IsTown,GrantID..inst.userid}) then
      return _InTown.granted
    elseif HasEntityInRange(x,y,z,radius,{IsTown,IsShare}) then
      return _InTown.share
    else
      return _InTown.protect
    end
  else
    return _InTown.null
  end
end
local function OwnershipRole(doer,inst)
  if doer and doer.userid and inst:HasTag(IsPrivate) then
    if inst:HasTag(OwnerID..doer.userid) then
      return _Privilege.owner
    elseif InPrivateTown(doer,30)==_InTown.owner and inst.components.container==nil then
      return _Privilege.intown
    elseif inst:HasTag(GrantID..doer.userid) then
      return _Privilege.granted
    elseif inst:HasTag(IsShare) then
      return _Privilege.share
    else
      return _Privilege.null
    end
  else
    return _Privilege.wild
  end
end
local function SetInfo(inst,player,actiontype)
  local actiontype = actiontype or _ActionType.OnBuilt
  inst.Info = inst.Info or {}
  inst.Info[ToAddTags] = inst.Info[ToAddTags] or {}
  if player.userid then
    if actiontype <= _ActionType.OnSuper then
      inst.Info[ToAddTags][IsPrivate] = IsPrivate
      inst.Info[ToAddTags][IsProtect] = IsProtect
      inst.Info[ToAddTags][OwnerID]   = OwnerID..player.userid
      if actiontype==_ActionType.OnSuper then
        inst.Info[IsSuper] = IsSuper
      elseif actiontype==_ActionType.OnBuilt then
        inst.Info[ToAddTags][IsShare]   = inst.components.container and IsShare or nil
        inst.Info[ToAddTags][GrantID]   = {}
        if inst.prefab=="arrowsign_post" or inst.prefab=="arrowsign_panel" then
          inst.Info[Desc] = table.concatn(_CMD,true,_CMD.userlist)
        else
          inst.Info[Desc] = "建 造 者: "..(player:GetDisplayName() or "无 名 氏")
        end
      end
      if inst.prefab=="researchlab2" and InPrivateTown(player,60) <= _InTown.owner then
        inst.Info[ToAddTags][IsTown] = IsTown
        inst.Info[Desc] = inst.Info[Desc] and inst.Info[Desc].." （ 私 人 领 地 范 围 3 0 ）" or "建 造 者: 无 名 氏"
      end
    elseif actiontype==_ActionType.OnShare then
      inst.Info[ToAddTags][IsShare] = IsShare
    elseif actiontype==_ActionType.OnUnShare then
      inst.Info[ToAddTags][IsShare] = nil
    elseif actiontype==_ActionType.OnGrant then
      local x,y,z = player.Transform:GetWorldPosition()
      local players = TheSim:FindEntities(x,y,z,15,{"player"})
      inst.Info[ToAddTags][GrantID] = inst.Info[ToAddTags][GrantID] or {}
      for _,v in pairs(players) do
        if v.userid and v.userid ~= player.userid and not table.contains(inst.Info[ToAddTags][GrantID],GrantID..v.userid) then
          table.insert(inst.Info[ToAddTags][GrantID],GrantID..v.userid)
        end
      end
    elseif actiontype==_ActionType.OnRevoke then
      inst.Info[ToAddTags][GrantID] = {}
    elseif actiontype==_ActionType.OnGet then
      inst.Info[ToAddTags][OwnerID]   = OwnerID..player.userid
      inst.Info[Desc] = inst.Info[Desc] and inst.Info[Desc]..("\n所 有 者: "..(player:GetDisplayName() or "无 名 氏")) or nil
    end
  elseif actiontype==_ActionType.OnExpire and type(player)=="string" then
    inst.Info[ToAddTags][OwnerID] = nil
    inst.Info[ToAddTags][IsShare] = IsShare
    inst.Info[ToAddTags][IsLeft]  = IsLeft
    inst.Info[ToAddTags][SaverID] = SaverID..player
  elseif actiontype==_ActionType.OnGift and type(player)=="string" then
    inst.Info[ToAddTags][IsPrivate] = IsPrivate
    inst.Info[ToAddTags][IsProtect] = IsProtect
    inst.Info[ToAddTags][OwnerID]   = OwnerID..player.userid
    inst.Info[ToAddTags][IsGift]    = IsGift
  end
end
local function AddTags(inst,tags)
  if type(tags)=="string" then
    if not inst:HasTag(tags) then inst:AddTag(tags) end
  elseif type(tags)=="table" then
    for _,v in pairs(tags) do AddTags(inst,v) end
  end
end
local function RemoveTags(inst,tags)
  if type(tags)=="string" then
    if inst:HasTag(tags) then inst:RemoveTag(tags) end
  elseif type(tags)=="table" then
    for _,v in pairs(tags) do RemoveTags(inst,v) end
  end
end
local function RemoveBurnable(inst)
  if inst and inst.components.burnable and not inst:HasTag("campfire") then
    RemoveTags(inst,_BurnTags.light)
    AddTags(inst,{_BurnTags.nolight,_BurnTags.fireimmune})
    inst.Info = inst.Info or {}
    inst.Info[ToDelTags] = inst.Info[ToDelTags] or {}
    inst.Info[ToDelTags][_BurnTags.light] = _BurnTags.light
    inst.Info[ToAddTags] = inst.Info[ToAddTags] or {}
    inst.Info[ToAddTags][_BurnTags.nolight] = _BurnTags.nolight
    inst.Info[ToAddTags][_BurnTags.fireimmune] = _BurnTags.fireimmune
  end
end
local function SuperBookTentaclesfn(inst,reader)
  local pos = reader:GetPosition()
  local facingangle = reader.Transform:GetRotation()*_G.DEGREES
  pos.x = pos.x + 7 * math.cos(-facingangle)
  pos.z = pos.z + 7 * math.sin(-facingangle)
  reader.components.sanity:DoDelta(-_G.TUNING.SANITY_MEDLARGE)
  reader:StartThread(function()
    for i=1,3 do
      local tentacle = _G.SpawnPrefab("tentacle")
      tentacle.Transform:SetPosition(pos.x+i,0,pos.z+i)
      _G.ShakeAllCameras(_G.CAMERASHAKE.FULL,.2,.02,.25,reader, 40)
      _G.SpawnPrefab("splash_ocean").Transform:SetPosition(pos.x+i,0,pos.z+i)
      tentacle.sg:GoToState("attack_pre")
      _G.Sleep(.33)
    end
  end)
  return true
end
local _SuperItem={["minerhat"]="fueled",["yellowamulet"]="fueled",["armor_sanity"]="armor",["ruinshat"]="armor",["armorruins"]="armor",["cane"]="cane",["piggyback"]="piggyback",["amulet"]="staffEtc",["orangeamulet"]="staffEtc",["greenamulet"]="staffEtc",["orangestaff"]="staffEtc",["greenstaff"]="staffEtc",["icestaff"]="staffEtc",["book_sleep"]="book",["book_gardening"]="book",["book_brimstone"]="book",["book_birds"]="book",["book_tentacles"]="book",["panflute"]="book",["fertilizer"]="fertilizer"}
local function SetSuperItem(inst)
  local item = _SuperItem[inst.prefab]
  if inst.components.fueled and item=="fueled" then
    inst.components.fueled:InitializeFuelLevel(36000)
  elseif item=="armor" and inst.components.armor then
    inst.components.armor:InitCondition(50000,0.95)
    inst.components.equippable.walkspeedmult= 1
    inst.components.equippable.dapperness   = 0
    inst.components.equippable.ontakedamage = nil
  elseif item=="staffEtc" and inst.components.finiteuses then
    inst.components.finiteuses.Use = function(val) return 0 end
  elseif item=="book" and inst.components.finiteuses then
    inst.components.finiteuses:SetMaxUses(100)
    inst.components.finiteuses:SetUses(100)
    if inst.prefab=="book_tentacles" then
      inst.components.book.onread = SuperBookTentaclesfn
    end
  elseif item=="fertilizer" and inst.components.finiteuses then
    inst.components.finiteuses:SetMaxUses(200)
    inst.components.finiteuses:SetUses(200)
  elseif item=="piggyback" then
    if inst.components.inventoryitem then inst.components.inventoryitem.cangoincontainer = true end
    if inst.components.waterproofer==nil then inst:AddComponent("waterproofer") end
    if inst.components.armor==nil then inst:AddComponent("armor") end
    if inst.components.equippable then
      inst.components.equippable.dapperness = _G.TUNING.DAPPERNESS_HUGE
      inst.components.equippable.walkspeedmult = 1.05
    end
    inst.components.waterproofer:SetEffectiveness(_G.TUNING.WATERPROOFNESS_LARGE)
    inst.components.armor:InitCondition(50000,0.80)
    inst:AddTag("waterproofer")
    inst:AddTag("fridge")
  elseif item=="cane" then
    inst:AddComponent("tool")
    inst.components.tool:SetAction(_G.ACTIONS.CHOP,15)
    inst.components.tool:SetAction(_G.ACTIONS.MINE,15)
    inst.components.tool:SetAction(_G.ACTIONS.NET)
    inst.components.weapon:SetDamage(50)
    inst.components.weapon:SetRange(1)
  end
end
local function GetDesc(inst, viewer)
  return not viewer:HasTag("playerghost") and inst.Info.Desc or nil
end
local function SetDesc(inst)
  if inst.components.inspectable and inst.prefab ~= "homesign" then inst.components.inspectable.getspecialdescription = GetDesc end
end
local function AddTaskTalk(inst,message,delay)
  if inst and inst.components.talker then
    inst:DoTaskInTime(delay or 0.5,function(inst) inst.components.talker:Say(message or "无 言 以 对...") end)
  end
end
local function OnGrant(inst)
  local x,y,z = inst.Transform:GetWorldPosition()
  local ents = TheSim:FindEntities(x,y,z,_ComDist,{OwnerID..inst.userid},{"INLIMBO"})
  for _,obj in pairs(ents) do
    if obj.components.inventoryitem==nil and obj.components.container and obj.prefab and obj.prefab ~= "cookpot" or (obj.prefab and obj.prefab=="researchlab2") then
      SetInfo(obj,inst,_ActionType.OnGrant)
      AddTags(obj,obj.Info[ToAddTags][GrantID])
      AddTaskTalk(inst,tostring(table.len(obj.Info[ToAddTags][GrantID])).._MSGT.grant.. (obj.name or " 东 西"))
      return
    end
  end
  AddTaskTalk(inst,_MSGT.grantfail) return
end
local function OnRevoke(inst)
  local x,y,z = inst.Transform:GetWorldPosition()
  local ents = TheSim:FindEntities(x,y,z,_ComDist,{OwnerID..inst.userid},{"INLIMBO"})
  for _,obj in pairs(ents) do
    local list = obj.Info[ToAddTags] and obj.Info[ToAddTags][GrantID] or {}
    if table.len(list) > 0 then
      obj.Info[ToAddTags][GrantID] = nil
      RemoveTags(obj,list)
      AddTaskTalk(inst,tostring(table.len(list)).._MSGT.revoke.. (obj.name or " 东 西"))
      return
    end
  end
  AddTaskTalk(inst,_MSGT.revokefail) return
end
local function OnShare(inst)
  local x,y,z = inst.Transform:GetWorldPosition()
  local ents = TheSim:FindEntities(x,y,z,_ComDist,{OwnerID..inst.userid},{IsShare})
  for _,obj in pairs(ents) do
    if obj.components.inventoryitem==nil and obj.components.container and obj.prefab and obj.prefab ~= "cookpot" or (obj.prefab and obj.prefab=="researchlab2") then
      obj.Info[ToAddTags][IsShare] = IsShare
      obj:AddTag(IsShare)
      obj.AnimState:SetMultColour(1,1,1,1)
      AddTaskTalk(inst,_MSGT.share.. (obj.name or " 东 西"))
      return
    end
  end
  AddTaskTalk(inst,_MSGT.sharefail) return
end
local function OnUnshare(inst)
  local x,y,z = inst.Transform:GetWorldPosition()
  local ents = TheSim:FindEntities(x,y,z,_ComDist,{OwnerID..inst.userid,IsShare})
  if table.len(ents) > 0 and ents[1].prefab and ents[1].prefab ~= "cookpot" then
    ents[1].Info[ToAddTags][IsShare] = nil
    ents[1]:RemoveTag(IsShare)
    ents[1].AnimState:SetMultColour(0.5,0.5,0.5,1)
    AddTaskTalk(inst,_MSGT.unshare.. (ents[1].name or " 东 西"))
    return
  end
  AddTaskTalk(inst,_MSGT.unsharefail) return
end
local function OnLs(player)
  local x,y,z = player.Transform:GetWorldPosition()
  local ents = TheSim:FindEntities(x,y,z,_ComDist,{IsPrivate},{"INLIMBO"})
  for _,v in pairs(ents) do
    if v.components.inventoryitem==nil and v.components.container and v.prefab ~= "cookpot" then
      local str  = v.Info and v.Info.Desc or "建  造  者 : 无 名 氏"
      local str1 = "授 权 使 用 人 数 :"..(v.Info and v.Info.AddTags and v.Info.AddTags[GrantID] and tostring(table.len(v.Info.AddTags[GrantID])) or "0")
      local str2 = "是 否 开 放 共 享 : "..(v:HasTag(IsShare) and "是" or "否")
      AddTaskTalk(player,str.."\n"..str1.."\n"..str2)
      return
    end
  end
  AddTaskTalk(player,_MSGT.lsfail)
end
local function OnInfo(player)
  if player and player.Info then AddTaskTalk(player,GetPlayerDesc(player)) end
end
local function OnGather(inst)
  if inst.Info and inst.Info.Item > 0 and GetPlayerLvl(inst) >= 30 then
    local x,y,z = inst.Transform:GetWorldPosition()
    local num = 0
    for _,v in pairs(_G.TheSim:FindEntities(x,0,z,10000,{IsGift,OwnerID..inst.userid})) do
      local tx,ty,tz = v.Transform:GetWorldPosition()
      if (x-tx)^2 + (z-tz)^2 > 16 then v.Transform:SetPosition(x,0,z) num = num+1 end
    end
    AddTaskTalk(inst,num > 0 and ("曾经有 "..tostring(num).._MSGT.gather) or _MSGT.gatherfail)
  end
end
local function OnRestart(inst)
  if _G.os.time() > (inst.Info.RestartOn + 30*60) then
    if inst.components and inst.components.inventory then inst.components.inventory:DropEverything(false,false) end
    _G.TheWorld:DoTaskInTime(0.5,function(inst) TheNet:Announce(inst:GetDisplayName().._MSGT.restart) end)
    if inst:IsValid() then _G.TheWorld:PushEvent("ms_playerdespawnanddelete",inst) end
  end
  AddTaskTalk(inst,inst:GetDisplayName().._MSGT.restartfail,1)
end
local function OnSaveKey(inst,pwd)
  if string.IsValidKey(pwd) and inst.userid and _G.TheWorld.Info.players[inst.userid] then
    local isdup = false
    for k,v in pairs(_G.TheWorld.Info.players) do if v.SaveKey==pwd and k~=inst.userid then isdup = true break end end
    if not isdup then
      _G.TheWorld.Info.players[inst.userid].SaveKey = pwd
      AddTaskTalk(inst,_MSGT.savekey..tostring(pwd))
      return
    end
  end
  AddTaskTalk(inst,_MSGT.Infokey)
end
local function OnGetByKey(inst,pwd)
  if string.IsValidKey(pwd) and inst.userid then
    local ownername,owerid = nil,nil
    for k,v in pairs(_G.TheWorld.Info.players) do if v.SaveKey==pwd and k~=inst.userid then ownername =v.name owerid=k break end end
    if owerid ~= nil then
      local num = 0
      for _,s in pairs(TheSim:FindEntities(0,0,0,10000,{IsPrivate,OwnerID..owerid},{IsGift,"INLIMBO"})) do
        SetInfo(s,inst,_ActionType.OnGet)
        s:RemoveTag("ownerid_"..owerid)
        s:AddTag("ownerid_"..inst.userid)
      end
      _G.TheWorld.Info.players[inst.userid].SaveKey = "null"
      AddTaskTalk(inst,"获得"..ownername.."的物权共计"..tostring(num).."处")
    end
  end
end
local function OnSetSuper(inst,num)
  local target = tonumber(num) and AllPlayers[tonumber(num)] or inst
  local set =_SP[target.userid]==nil or not _SP[target.userid]
  _SP[target.userid] = set
  AddTaskTalk(target,set and _MSGT.onsuper or _MSGT.offsuper)
end
local function Onhelp(inst)
  local help = _SP[inst.userid] and table.concatn(_CMD,true,_CMD.adminlist) or table.concatn(_CMD,true,_CMD.userlist)
  AddTaskTalk(inst,help,1)
  AddTaskTalk(inst,help,3)
end
local function OnClearMap(inst)
  local delnum = 0
  local ents = TheSim:FindEntities(0,0,0,10000,nil,{"INLIMBO"})
  for _,v in pairs(ents) do
    local num = v.components.stackable and v.components.stackable:StackSize() or 0
    if v.prefab and _ClearPrefabs[v.prefab] and num <= _ClearPrefabs[v.prefab] or v:HasTag("stump") then
      v:Remove()
      delnum = delnum + 1
    elseif table.contains({"multiplayer_portal","cave_entrance","cave_entrance_open","cave_exit"},v.prefab) then
      local x,y,z = v.Transform:GetWorldPosition()
      local ToRemove = TheSim:FindEntities(x,y,z,20,nil)
      for _,s in pairs(ToRemove) do
        if table.contains({"tentacle","spiderden","lureplant"},s.prefab)  then
          s:Remove()
          delnum = delnum + 1
        end
      end
    end
  end
  if inst and inst:HasTag("player") then
    AddTaskTalk(inst,_MSGT.mapclear..tostring(delnum),0.5)
  else
    _G.TheWorld:DoTaskInTime(5,function() TheNet:Announce(_MAP[TheShard:GetShardId()].name.._MSGT.worldclear..tostring(delnum)) end)
  end
end
local function DoAnnounce(inst,data)
  if _G.TheShard:GetShardId()~="1" then return end
  local num = #_MSGA
  if _G.TheWorld.state.cycles < 20 then
    local inter = math.ceil(7*60/num)
    for i = 1, num do _G.TheWorld:DoTaskInTime(inter*i, function() _G.TheNet:Announce(_MSGA[i]) end) end
  else
    _G.TheWorld:DoTaskInTime(20, function() _G.TheNet:Announce(_MSGA[1]) end)
    for i= 1,4 do _G.TheWorld:DoTaskInTime(90*i, function() _G.TheNet:Announce(_MSGA[math.random(1+i,num)]) end) end
  end
end
local function OnLsplayer(inst)
  local scr = "当前用户:\n"
  for k, v in pairs(AllPlayers) do scr = scr.."["..tostring(k).."] ["..v.userid.."] 名字:"..v.name.."\n" end
  AddTaskTalk(inst,scr)
end
local function OnKick(inst,num)
  local target = tonumber(num) and AllPlayers[tonumber(num)]
  if target then
    AddTaskTalk(inst,target.name.._MSGT.kick)
    target.components.inventory:DropEverything(false, false)
    TheNet:Kick(target.userid)
  end
end
local function OnBan(inst,num)
  local target = tonumber(num) and AllPlayers[tonumber(num)]
  if target then
    AddTaskTalk(inst,target.name.._MSGT.ban)
    target.components.inventory:DropEverything(false, false)
    TheNet:Ban(target.userid)
  end
end
local old_action_attack = _G.ACTIONS.ATTACK.fn
_G.ACTIONS.ATTACK.fn = function(act)
  if act.target and OwnershipRole(act.doer,act.target) > _Privilege.granted then
    return false
  else
    return old_action_attack(act)
  end
end
local old_action_deploy = _G.ACTIONS.DEPLOY.fn
_G.ACTIONS.DEPLOY.fn = function(act)
  local DeployItems  = {["butterfly"]="flower",["dug_berrybush"]="berrybush",["dug_berrybush2"]= "berrybush2",["dug_grass"]= "grass",["dug_marsh_bush"]= "marsh_bush",["dug_sapling"]= "sapling",["eyeturret_item"]= "eyeturret",["wall_ruins"]= 25,["wall_ruins_item"]= 25,["wall_stone"]= 25,["wall_stone_item"]= 25,["lureplantbulb"] = 50,["spidereggsack"]= 50,}
  if act.invobject.prefab and DeployItems[act.invobject.prefab] and act.doer.userid then
    local x,y,z = act.pos.x,act.pos.y,act.pos.z
    if type(DeployItems[act.invobject.prefab])=="string" and  InPrivateTown(act.doer,40) > _InTown.null then
      if act.invobject.components.deployable:CanDeploy(act.pos) then
        local obj = (act.doer.components.inventory and act.doer.components.inventory:RemoveItem(act.invobject)) or (act.doer.components.container and act.doer.components.container:RemoveItem(act.invobject))
        if obj.components.deployable:Deploy(act.pos,act.doer) then
          for _,v in pairs(TheSim:FindEntities(x,y,z,1,nil,{IsPrivate})) do
            if v and v.prefab==DeployItems[act.invobject.prefab] then
              SetInfo(v,act.doer,_ActionType.OnDeloy)
              AddTags(v,v.Info[ToAddTags])
              RemoveBurnable(v)
              break
            end
          end
          return true
        else
          act.doer.components.inventory:GiveItem(obj)
          return
        end
      end
    elseif type(DeployItems[act.invobject.prefab])=="number" then
      local limitrange = DeployItems[act.invobject.prefab]
      if InPrivateTown(act.doer,limitrange) > _InTown.owner or HasEntityInRange(x,y,z,limitrange,{"multiplayer_portal"}) then return end
    end
  end
  return old_action_deploy(act)
end
local old_haunt_action = _G.ACTIONS.HAUNT.fn
_G.ACTIONS.HAUNT.fn = function(act)
  if _G.TheWorld.ismastersim==false then return old_haunt_action(act) end
  if act.target and act.target.prefab and table.contains({"multiplayer_portal","resurrectionstone","amulet"},act.target.prefab) then
    return old_haunt_action(act)
  else
    return
  end
end
local old_hammer_action = _G.ACTIONS.HAMMER.fn
_G.ACTIONS.HAMMER.fn = function(act)
  if _G.TheWorld.ismastersim==false then return old_hammer_action(act) end
  if IsSuperUser(act.doer) or (act.target and OwnershipRole(act.doer,act.target) < _Privilege.granted) then
    return old_hammer_action(act)
  else
    AddTaskTalk(act.doer,_MSGT.hammer,0.5)
    return
  end
end
local old_dig_action = _G.ACTIONS.DIG.fn
_G.ACTIONS.DIG.fn = function(act)
  if _G.TheWorld.ismastersim==false then return old_dig_action(act) end
  if IsSuperUser(act.doer) or (act.target and (OwnershipRole(act.doer,act.target) < _Privilege.granted or InPrivateTown(act.doer,40) <= _InTown.granted)) then
    return old_dig_action(act)
  else
    AddTaskTalk(act.doer,_MSGT.dig,0.5)
    return
  end
end
local old_terraform_action = _G.ACTIONS.TERRAFORM.fn
_G.ACTIONS.TERRAFORM.fn = function(act)
  local tile = act.doer:GetCurrentTileType()
  if IsSuperUser(act.doer) or not ((tile==_G.GROUND.CARPET or tile==_G.GROUND.CHECKER or tile==_G.GROUND.WOOD or tile==_G.GROUND.SCALE) and InPrivateTown(act.doer,30) > _InTown.granted) then
    return old_terraform_action(act)
  else
    AddTaskTalk(act.doer,_MSGT.terraform,0.5)
    return
  end
end
local old_light_action = _G.ACTIONS.LIGHT.fn
_G.ACTIONS.LIGHT.fn = function(act)
  local canlight = false
  if act.target then
    local x,y,z = act.target.Transform:GetWorldPosition()
    canlight = not HasEntityInRange(x,y,z,20,{IsPrivate,"structure"}) or InPrivateTown(act.doer,20) <= _InTown.granted
  end
  if IsSuperUser(act.doer) or canlight then
    return old_light_action(act)
  elseif OwnershipRole(act.doer,act.target) > _Privilege.intown then
    AddTaskTalk(act.doer,_MSGT.light,0.5)
    return
  end
end
local old_networking_say = _G.Networking_Say
_G.Networking_Say =  function(guid,userid,name,prefab,message,colour,whisper)
  local oldsayinst = old_networking_say(guid,userid,name,prefab,message,colour,whisper)
  local talker = GetOnlinePlayerById(userid)
  if talker==nil then return oldsayinst end
  if whisper  and talker and talker.userid then
    local execom = {}
    for word in string.gmatch(message,"%S+") do
      local temp = _G.tonumber(word) and _G.tonumber(word) or string.lower(word)
      table.insert(execom,temp)
    end
    if execom[1] and _CMD[execom[1]] and table.len(execom)==1 then
      if     execom[1] =="help" then Onhelp(talker)
      elseif execom[1] =="grant" then OnGrant(talker)
      elseif execom[1] =="revoke" then OnRevoke(talker)
      elseif execom[1] =="share" then OnShare(talker)
      elseif execom[1] =="unshare" then OnUnshare(talker)
      elseif execom[1] =="ls" then OnLs(talker)
      elseif execom[1] =="info" then OnInfo(talker)
      elseif execom[1] =="restart" then OnRestart(talker)
      elseif execom[1] =="gather" then OnGather(talker)
      elseif execom[1] =="clearmap" and _SP[talker.userid] then OnClearMap(talker)
      elseif execom[1] =="lsplayer" and _SP[talker.userid] then OnLsplayer(talker)
      elseif execom[1] =="ban" and _SP[talker.userid] then OnBan(talker,execom[2])
      elseif execom[1] =="kick" and _SP[talker.userid] then OnKick(talker,execom[2])
      elseif execom[1] =="setsuper" and _SP[talker.userid]~=nil then OnSetSuper(talker,execom[2])
      end
    end
  end
  return oldsayinst
end
local function OnBuild_new(doer,prod)
  if prod.components.inventoryitem==nil and doer.userid then
    local x,y,z = doer.Transform:GetWorldPosition()
    SetInfo(prod,doer,_ActionType.OnBuilt)
    AddTags(prod,prod.Info[ToAddTags])
    SetDesc(prod)
    if prod.components.container and not prod:HasTag(IsShare) then prod.AnimState:SetMultColour(0.5,0.5,0.5,1) end
    RemoveBurnable(prod)
  elseif prod.prefab and _SuperItem[prod.prefab] and IsSuperPlayer(doer) then
    SetInfo(prod,doer,_ActionType.OnSuper)
    AddTags(prod,prod.Info[ToAddTags])
    SetSuperItem(prod)
    RemoveBurnable(prod)
  end
  if doer.components.builder.onBuild_old then
    doer.components.builder.onBuild_old(doer,prod)
  end
end
local function OnSave(inst,data)
  if inst.OnSave_old ~= nil then inst.OnSave_old(inst,data) end
  if inst.Info ~= nil then data.Info = inst.Info end
end
local function OnLoad(inst,data)
  if inst.OnLoad_old ~= nil then inst.OnLoad_old(inst,data) end
  if data ~= nil and data.Info ~= nil then
    inst.Info = data.Info
    AddTags(inst,data.Info[ToAddTags] or {})
    RemoveTags(inst,data.Info[ToDelTags] or {})
    if inst.components.container and not inst:HasTag(IsShare) then inst.AnimState:SetMultColour(0.5,0.5,0.5,1) end
    if inst.Info[Desc] then SetDesc(inst) end
    if inst.Info[IsSuper] then SetSuperItem(inst) end
  end
end
AddPrefabPostInit("multiplayer_portal",function(inst) inst:AddTag("multiplayer_portal") end)
AddPlayerPostInit(function(inst)
  inst.Info = inst.Info or table.copy(_PlayerInfo, true)
  if inst.components.builder then
    if inst.components.builder.onBuild then
      inst.components.builder.onBuild_old = inst.components.builder.onBuild
    end
    inst.components.builder.onBuild = OnBuild_new
  end
  if inst.components.inspectable then inst.components.inspectable.getspecialdescription = GetPlayerDesc end
  inst.OnSave_old = inst.OnSave
  inst.OnSave = OnSave
  inst.OnLoad_old = inst.OnLoad
  inst.OnLoad = OnLoad
end)
AddPrefabPostInit("world", function(inst)
  inst.Info = inst.Info or {}
  inst.Info.players = inst.Info.players or {}
  inst:ListenForEvent("ms_cyclecomplete", DoAnnounce)
  inst:ListenForEvent("ms_setseason",OnClearMap)
  inst.OnSave_old = inst.OnSave
  inst.OnSave = OnSave
  inst.OnLoad_old = inst.OnLoad
  inst.OnLoad = OnLoad
end)
AddComponentPostInit("playerspawner",function(PlayerSpawner,inst)
  inst:ListenForEvent("ms_playerjoined",Onplayerjoined)
  inst:ListenForEvent("ms_playerdespawnanddelete",Onplayerdespawnanddelete)
  inst:ListenForEvent("ms_playerleft", Onplayerleft)
  inst:ListenForEvent("ms_becameghost",Onbecameghost)
  inst:ListenForEvent("ms_respawnedfromghost",Onrespawnedfromghost)
  inst:ListenForEvent("ms_cyclecomplete", CheckPlayer)
end)
----回血设置
for _,v in pairs({"knight","bishop","rook", "minotaur", "lightninggoat"}) do
  AddPrefabPostInit(v, function(inst)
    if inst.components.health then
      inst.components.health:StartRegen(1, 1)
    end
  end)
end
for _,v in pairs({"berrybush","grass","sapling"}) do
  AddPrefabPostInit(v,function(inst)
    inst.OnSave_old = inst.OnSave
    inst.OnSave = OnSave
    inst.OnLoad_old = inst.OnLoad
    inst.OnLoad = OnLoad
  end)
end
for k,v in pairs(_G.AllRecipes) do
  local recipename = v.name
  AddPrefabPostInit(recipename,function(inst)
    inst.OnSave_old = inst.OnSave
    inst.OnSave = OnSave
    inst.OnLoad_old = inst.OnLoad
    inst.OnLoad = OnLoad
  end)
end
AddPrefabPostInit("grass",function(inst)
  inst.components.pickable.max_cycles  = _AJ.grass
  inst.components.pickable.cycles_left = _AJ.grass
end)
for _,prefab in pairs(_QuickPickPrefab) do
  AddPrefabPostInit(prefab,function (inst)
    if inst.components.pickable then
      inst.components.pickable.quickpick = true
    end
  end)
end
AddPrefabPostInit("firesuppressor",function(inst)
  inst.components.fueled.rate = 0
  inst.components.firedetector:SetOnFindFireFn(
    function (obj,firePos)
      if table.len(TheSim:FindEntities(firePos.x,firePos.y,firePos.z,0.5,{"campfire"},{ "FX" ,"NOCLICK" })) > 0 then return end
      if obj:IsAsleep() then
        obj:DoTaskInTime(1 + math.random(),obj.components.wateryprotection:SpreadProtectionAtPoint(firePos:Get()),firePos)
      else
        obj:PushEvent("putoutfire",{firePos = firePos })
      end
    end)
end)
AddPrefabPostInit("greenstaff",function(inst)
  if inst.components.spellcaster then
    inst.components.spellcaster.CanCast = function(inst,doer,target)
      if target and doer.userid and not IsSuperUser(doer) and OwnershipRole(doer,target) > _Privilege.owner then
        AddTaskTalk(doer,_MSGT.cast,0.5)
        return false
      else
        return target and target.prefab and _G.AllRecipes[target.prefab]
      end
    end
  end
end)
AddComponentPostInit("container",function(Container,inst)
  Container.Open_old = Container.Open
  function Container:Open(doer)
    if IsSuperUser(doer) or OwnershipRole(doer,inst) < _Privilege.null or (inst.prefab and inst.prefab=="cookpot") then
      return Container:Open_old(doer)
    else
      AddTaskTalk(doer,_MSGT.open,0.5)
      return true
    end
  end
end)
AddComponentPostInit("pickable", function(Pickable, inst)
  Pickable.Pick_old = Pickable.Pick
  function Pickable:Pick(doer)
    if (inst.prefab and inst.prefab ~= "flower") or OwnershipRole(doer,inst) < _Privilege.null or IsSuperUser(doer) then
      return Pickable:Pick_old(doer)
    else
      AddTaskTalk(doer,_MSGT.pick,0.5)
      return true
    end
  end
end)
AddComponentPostInit("occupiable",function(Occupiable,inst)
  Occupiable.Harvest_old = Occupiable.Harvest
  function Occupiable:Harvest(harvester)
    if OwnershipRole(harvester,inst) < _Privilege.null then
      return Occupiable:Harvest_old()
    else
      AddTaskTalk(harvester,_MSGT.occupi,0.5)
      return
    end
  end
end)
AddComponentPostInit("temperature",function(self)
  local GetInsulation_old = self.GetInsulation
  self.GetInsulation = function(self)
    local winterInsulation,summerInsulation = GetInsulation_old(self)
    local tile,data = self.inst:GetCurrentTileType()
    if tile==_G.GROUND.SCALE then
      return 1e+9,1e+9
    end
    return GetInsulation_old(self)
  end
end)
AddComponentPostInit("moisture",function(self)
  local GetMoistureRate_old = self.GetMoistureRate
  self.GetMoistureRate = function(self)
    local tile,data = self.inst:GetCurrentTileType()
    if tile==_G.GROUND.SCALE then
      return 0
    end
    return GetMoistureRate_old(self)
  end
end)
AddComponentPostInit("propagator",function(Propagator,self)
  Propagator.StartUpdating_old = Propagator.StartUpdating
  function Propagator:StartUpdating(source)
    local x,y,z = self.inst.Transform:GetWorldPosition()
    if HasEntityInRange(x,y,z,30,{IsPrivate,"structure"}) then
      self.propagaterange = 0
    end
    Propagator:StartUpdating_old(source)
  end
end)
AddComponentPostInit("explosive",function(Explosive,self)
  Explosive.OnBurnt_old = Explosive.OnBurnt
  function Explosive:OnBurnt()
    local buildingdamage_old = self.buildingdamage or 0
    self.buildingdamage = buildingdamage_old * 0
    self.inst.components.explosive.buildingdamage = buildingdamage_old * 0
    return Explosive:OnBurnt_old(self)
  end
end)
AddPrefabPostInit("resurrectionstone", function(inst)
  inst:ListenForEvent("activateresurrection",function(inst, player)
    local x,y,z = inst.Transform:GetWorldPosition()
    _G.SpawnPrefab("resurrectionstone").Transform:SetPosition(x,y,z)
    if player and player.components.health then
      player.components.health:DeltaPenalty(_G.TUNING.PORTAL_HEALTH_PENALTY)
    end
  end)
end)
AddPrefabPostInit("book_tentacles", function(inst)
  inst.components.book.onread_old = inst.components.book.onread
  inst.components.book.onread = function(inst,reader)
    local stop = false
    local x,y,z  = reader.Transform:GetWorldPosition()
    local ToFind = TheSim:FindEntities(x,y,z,20,nil)
    for _,v in pairs(ToFind) do
      if v:HasTag(IsTown) or table.contains({"multiplayer_portal","cave_entrance","cave_entrance_open","cave_exit"},v.prefab) then
        stop = true
        break
      end
    end
    if stop then
      return
    else
      inst.components.book.onread_old(inst,reader)
    end
  end
end)
AddPrefabPostInit("birdcage",function(inst)
  local function OnGetItemFromPlayer(inst,giver,item)
    if inst.components.sleeper and inst.components.sleeper:IsAsleep() then
      inst.components.sleeper:WakeUp()
    end
    if item.components.edible ~= nil and
      ( item.components.edible.foodtype==_G.FOODTYPE.MEAT or
      item.prefab=="seeds" or
      _G.Prefabs[string.lower(item.prefab.."_seeds")] ~= nil
      ) then
      inst.AnimState:PlayAnimation("peck")
      inst.AnimState:PushAnimation("peck")
      inst.AnimState:PushAnimation("peck")
      inst.AnimState:PushAnimation("hop")
      inst.AnimState:PushAnimation("idle_bird",true)
      inst:DoTaskInTime(60 * _G.FRAMES,function(inst,item)
        if item.components.edible.foodtype==_G.FOODTYPE.MEAT then
          inst.components.lootdropper:SpawnLootPrefab("bird_egg")
        else
          local seed_name = _G.Prefabs[string.lower(item.prefab.."_seeds")] and string.lower(item.prefab.."_seeds") or "seeds"
          local num_seeds = seed_name=="seeds" and 1 or math.random(_SN[1],_SN[2])
          for k = 1,num_seeds do
            inst.components.lootdropper:SpawnLootPrefab(seed_name)
          end
        end
      end,item)
    end
  end
  if inst and inst.components.trader then
    inst.components.trader.onaccept = OnGetItemFromPlayer
  end
end)
