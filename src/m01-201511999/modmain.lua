modimport("message.lua")
---指令信息
local _CommandList = get_msg("CommandList")
---定时弹幕信息
local _MSG= get_msg("announce")
---超级玩家是否有特权
local GrantSuperPlayer = false
---修改墙、冰箱、晒肉、煮(增强为原来的倍数,1为原值),草果收获次数(绝对值)
local _Adjust={WallEnhance=10,FridgeTime=100,DryTime=2,CookTime=2,GrassPickCycle=100,BerrybushPickCycle=100}
---眼塔攻击力、速度(绝对值);生命、生命(回复倍数,1为原值)
local _EyeTurret={DMG=70,ATTACK_PERIOD=1,HEALTH=10,REGEN=20}
---喂蔬菜得种子数量范围
local _seeds_num ={1,3}
---超级玩家
local _SuperPlayers = {["OU_76561197960623716"] = true,["OU_76561198252289790"] = true}
---------以下代码谨修改
local _G = GLOBAL
local require    = _G.require
local STRINGS    = _G.STRINGS
local TheNet     = _G.TheNet
local TheSim     = _G.TheSim
local AllPlayers = _G.AllPlayers
local ToAddTags  = "Add"        --需添加标签
local ToDelTags  = "Del"        --需移除标签
local IsPrivate  = "M_Private"  --是否私有
local IsShare    = "M_Share"    --是否共享
local IsLeft     = "M_Left"     --失效标识
local IsTown     = "M_Town"     --城镇标签
local IsProtect  = "noattack"   --免
local Desc       = "desc"
local IsSuper    = "issuper"
local OwnerID    = "ownerid_"   --所有者实例前缀
local GrantID    = "grantid_"   --授权实例标前缀
local SaverID    = "saveid_"    --失效实例前缀
local first = 0
local function gethelp(t)
  local str = ""
  for _,v in pairs(t["list"]) do
    str = str .. (v and (tostring(v).." "..tostring(t[v]).."\n") or "")
  end
  return str
end
local HelpInfo = gethelp(_CommandList)
_G.TUNING.PERISH_FRIDGE_MULT=_Adjust.FridgeTime ~= 0 and _G.TUNING.PERISH_FRIDGE_MULT/_Adjust.FridgeTime or 0
_G.TUNING.DRY_FAST=_Adjust.DryTime~=0 and _G.TUNING.DRY_FAST/_Adjust.DryTime or 10
_G.TUNING.DRY_MED=_Adjust.DryTime~=0 and _G.TUNING.DRY_MED/_Adjust.DryTime or 10
_G.TUNING.BASE_COOK_TIME=_Adjust.CookTime~=0 and _G.TUNING.BASE_COOK_TIME/_Adjust.CookTime or 10
_G.TUNING.HAYWALL_HEALTH=_G.TUNING.HAYWALL_HEALTH*_Adjust.WallEnhance
_G.TUNING.WOODWALL_HEALTH=_G.TUNING.WOODWALL_HEALTH*_Adjust.WallEnhance
_G.TUNING.STONEWALL_HEALTH=_G.TUNING.STONEWALL_HEALTH*_Adjust.WallEnhance
_G.TUNING.RUINSWALL_HEALTH=_G.TUNING.RUINSWALL_HEALTH*_Adjust.WallEnhance
_G.TUNING.MOONROCKWALL_HEALTH=_G.TUNING.MOONROCKWALL_HEALTH*_Adjust.WallEnhance
_G.TUNING.EYETURRET_DAMAGE=_EyeTurret.DMG
_G.TUNING.EYETURRET_ATTACK_PERIOD=_EyeTurret.ATTACK_PERIOD
_G.TUNING.EYETURRET_HEALTH=_G.TUNING.EYETURRET_HEALTH*_EyeTurret.HEALTH
_G.TUNING.EYETURRET_REGEN=_G.TUNING.EYETURRET_REGEN*_EyeTurret.REGEN
_G.TUNING.BERRYBUSH_CYCLES=_Adjust.BerrybushPickCycle
-----------------------------------

local function IsSuperPlayer(player)
  return player.userid and _SuperPlayers[player.userid] or false
end
local function IsSuperUser(player)
  return player.Network ~= nil and player.Network:IsServerAdmin() or (GrantSuperPlayer and IsSuperPlayer(player))
end
local function GetOnlinePlayerById(userid)
  for i,p in pairs(AllPlayers) do
    if p.userid == userid then return p,i end
  end
end
local function HasEntityInRange(x,y,z,radius,musttags,mustoneoftags,notags)
  return table.len(TheSim:FindEntities(x,y,z,radius,musttags,notags,mustoneoftags)) > 0
end
local _InTown = {null = 0,owner = 1,granted = 2,share = 3,protect = 4}
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
local _Privilege = {wild = 0 ,owner = 1,intown = 2,granted = 3,share = 4,null = 5}
local function OwnershipRole(doer,inst)
  if doer and doer.userid and inst:HasTag(IsPrivate) then
    if inst:HasTag(OwnerID..doer.userid) then
      return _Privilege.owner
    elseif InPrivateTown(doer,30) == _InTown.owner and inst.components.container == nil then
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
local _ActionType = {OnBuilt = 10,OnBuiltTown = 11,OnDeloy = 12,OnSuper = 19,OnGrant = 20,OnRevoke = 21,OnShare = 22,OnUnShare = 23,OnExpire = 30}
local function SetInfo(player,actiontype,inst)
  local actiontype = actiontype or _ActionType.OnBuilt
  inst.Info = inst.Info or {}
  inst.Info[ToAddTags] = inst.Info[ToAddTags] or {}
  if player.userid and actiontype ~= _ActionType.OnExpire then
    if actiontype <= _ActionType.OnSuper then
      inst.Info[ToAddTags][IsPrivate] = IsPrivate
      inst.Info[ToAddTags][IsProtect] = IsProtect
      inst.Info[ToAddTags][OwnerID]   = OwnerID..player.userid
      if actiontype == _ActionType.OnSuper then
        inst.Info[IsSuper] = IsSuper
      elseif actiontype == _ActionType.OnBuilt then
        inst.Info[ToAddTags][IsShare]   = inst.components.container and IsShare or nil
        inst.Info[ToAddTags][GrantID]   = {}
        if inst.prefab ~= "homesign" then
          if inst.prefab == "arrowsign_post" or inst.prefab == "arrowsign_panel" then
            inst.Info[Desc] = HelpInfo
          else
            inst.Info[Desc] = "建 造 者: "..(player:GetDisplayName() or "无 名 氏")
          end
        end
      end
      if inst.prefab == "researchlab2" and InPrivateTown(player,60) <= _InTown.owner then
        inst.Info[ToAddTags][IsTown] = IsTown
        inst.Info[Desc] = inst.Info[Desc] and inst.Info[Desc].." （ 私 人 领 地 范 围 3 0 ）" or "建 造 者: 无 名 氏"
      end
    elseif actiontype == _ActionType.OnShare then
      inst.Info[ToAddTags][IsShare] = IsShare
    elseif actiontype == _ActionType.OnUnShare then
      inst.Info[ToAddTags][IsShare] = nil
    elseif actiontype == _ActionType.OnGrant then
      local x,y,z = player.Transform:GetWorldPosition()
      local players = TheSim:FindEntities(x,y,z,15,{"player"})
      inst.Info[ToAddTags][GrantID] = inst.Info[ToAddTags][GrantID] or {}
      for _,v in pairs(players) do
        if v.userid and v.userid ~= player.userid and not table.contains(inst.Info[ToAddTags][GrantID],GrantID..v.userid) then
          table.insert(inst.Info[ToAddTags][GrantID],GrantID..v.userid)
        end
      end
    elseif actiontype == _ActionType.OnRevoke then
      inst.Info[ToAddTags][GrantID] = {}
    end
  elseif actiontype == _ActionType.OnExpire and type(player) == "string" then
    inst.Info[ToAddTags][OwnerID] = nil
    inst.Info[ToAddTags][IsShare] = IsShare
    inst.Info[ToAddTags][IsLeft]  = IsLeft
    inst.Info[ToAddTags][SaverID] = SaverID..player
  end
end
local function AddTags(inst,tags)
  if type(tags) == "string" then
    if not inst:HasTag(tags) then inst:AddTag(tags) end
  elseif type(tags) == "table" then
    for _,v in pairs(tags) do
      AddTags(inst,v)
    end
  end
end
local function RemoveTags(inst,tags)
  if type(tags) == "string" then
    if inst:HasTag(tags) then inst:RemoveTag(tags) end
  elseif type(tags) == "table" then
    for _,v in pairs(tags) do
      RemoveTags(inst,v)
    end
  end
end
local function SuperBookTentaclesfn(inst,reader)
  local pos = reader:GetPosition()
  local facingangle = reader.Transform:GetRotation()*_G.DEGREES
  pos.x = pos.x + 10 * math.cos(-facingangle)
  pos.z = pos.z + 10 * math.sin(-facingangle)
  reader.components.sanity:DoDelta(-_G.TUNING.SANITY_LARGE)
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
  if inst.components.fueled and item == "fueled" then
    inst.components.fueled:InitializeFuelLevel(36000)
  elseif item == "armor" and inst.components.armor then
    inst.components.armor:InitCondition(50000,0.95)
    inst.components.equippable.walkspeedmult= 1
    inst.components.equippable.dapperness   = 0
    inst.components.equippable.ontakedamage = nil
  elseif item == "staffEtc" and inst.components.finiteuses then
    inst.components.finiteuses.Use = function(val) return 0 end
  elseif item == "book" and inst.components.finiteuses then
    inst.components.finiteuses:SetMaxUses(100)
    inst.components.finiteuses:SetUses(100)
    if inst.prefab == "book_tentacles" then
      inst.components.book.onread = SuperBookTentaclesfn
    end
  elseif item == "fertilizer" and inst.components.finiteuses then
    inst.components.finiteuses:SetMaxUses(200)
    inst.components.finiteuses:SetUses(200)
  elseif item == "piggyback" then
    if inst.components.inventoryitem then inst.components.inventoryitem.cangoincontainer = true end
    if inst.components.waterproofer == nil then inst:AddComponent("waterproofer") end
    if inst.components.armor == nil then inst:AddComponent("armor") end
    if inst.components.equippable then
      inst.components.equippable.dapperness = _G.TUNING.DAPPERNESS_HUGE
      inst.components.equippable.walkspeedmult = 1.05
    end
    inst.components.waterproofer:SetEffectiveness(_G.TUNING.WATERPROOFNESS_LARGE)
    inst.components.armor:InitCondition(50000,0.80)
    inst:AddTag("waterproofer")
    inst:AddTag("fridge")
  elseif item == "cane" then
    inst:AddComponent("tool")
    inst.components.tool:SetAction(_G.ACTIONS.CHOP,15)
    inst.components.tool:SetAction(_G.ACTIONS.MINE,15)
    inst.components.tool:SetAction(_G.ACTIONS.NET)
    inst.components.weapon:SetDamage(50)
    inst.components.weapon:SetRange(1)
  end
end
local function GetDesc(inst, viewer)
  return not viewer:HasTag("playerghost") and inst.Info[Desc] or nil
end
local function SetDesc(inst)
  if inst.components.inspectable then
    inst.components.inspectable.getspecialdescription = GetDesc
  end
end
local function AddTaskTalk(inst,message,delay)
  if inst and inst.components.talker then
    inst:DoTaskInTime(delay or 0.5,function(inst) inst.components.talker:Say(message or "我 忘 记 了 什 么...") end)
  end
end
local _ComDist = 3
local function OnGrant(inst)
  local x,y,z = inst.Transform:GetWorldPosition()
  local ents = TheSim:FindEntities(x,y,z,_ComDist,{OwnerID..inst.userid},{"INLIMBO"})
  for _,obj in pairs(ents) do
    if obj.components.inventoryitem == nil and obj.components.container and obj.prefab and obj.prefab ~= "cookpot" or (obj.prefab and obj.prefab == "researchlab2") then
      SetInfo(inst,_ActionType.OnGrant,obj)
      AddTags(obj,obj.Info[ToAddTags][GrantID])
      AddTaskTalk(inst,tostring(table.len(obj.Info[ToAddTags][GrantID])).." 个 基  友 可 用 这 " .. (obj.name or " 东 西"))
      return
    end
  end
  AddTaskTalk(inst,"附 近 有 自 己 建 的 东 西 要 分 享 吗 ?") return
end
local function OnRevoke(inst)
  local x,y,z = inst.Transform:GetWorldPosition()
  local ents = TheSim:FindEntities(x,y,z,_ComDist,{OwnerID..inst.userid},{"INLIMBO"})
  for _,obj in pairs(ents) do
    local list = obj.Info[ToAddTags] and obj.Info[ToAddTags][GrantID] or {}
    if table.len(list) > 0 then
      obj.Info[ToAddTags][GrantID] = nil
      RemoveTags(obj,list)
      AddTaskTalk(inst,tostring(table.len(list)).." 个 基 友 已 无 权 使 用 这 " .. (obj.name or " 东 西"))
      return
    end
  end
  AddTaskTalk(inst,"附 近 没 什 么 东 西 是 我 分 享 的 !") return
end
local function OnShare(inst)
  local x,y,z = inst.Transform:GetWorldPosition()
  local ents = TheSim:FindEntities(x,y,z,_ComDist,{OwnerID..inst.userid},{IsShare})
  for _,obj in pairs(ents) do
    if obj.components.inventoryitem == nil and obj.components.container and obj.prefab and obj.prefab ~= "cookpot" or (obj.prefab and obj.prefab == "researchlab2") then
      obj.Info[ToAddTags][IsShare] = IsShare
      obj:AddTag(IsShare)
      obj.AnimState:SetMultColour(1,1,1,1)
      AddTaskTalk(inst,"Oh ... YEAH ... 所 有 人 都 可 用 这 " .. (obj.name or " 东 西"))
      return
    end
  end
  AddTaskTalk(inst,"附 近 没 什 么 东 西 可 共 享 的 !") return
end
local function OnUnshare(inst)
  local x,y,z = inst.Transform:GetWorldPosition()
  local ents = TheSim:FindEntities(x,y,z,_ComDist,{OwnerID..inst.userid,IsShare})
  if table.len(ents) > 0 and ents[1].prefab and ents[1].prefab ~= "cookpot" then
    ents[1].Info[ToAddTags][IsShare] = nil
    ents[1]:RemoveTag(IsShare)
    ents[1].AnimState:SetMultColour(0.5,0.5,0.5,1)
    AddTaskTalk(inst,"没 人 能 再 使 用 这" .. (ents[1].name or " 东 西"))
    return
  end
  AddTaskTalk(inst,"附 近 没 什 么 东 西 是 我 共 享 的 !") return
end
local function OnLs(player)
  local x,y,z = player.Transform:GetWorldPosition()
  local ents = TheSim:FindEntities(x,y,z,_ComDist,{IsPrivate},{"INLIMBO"})
  for _,v in pairs(ents) do
    if v.components.inventoryitem == nil and v.components.container and v.prefab ~= "cookpot" then
      local str  = v.Info and v.Info[Desc] or "建  造  者 : 无 名 氏"
      local str1 = "授 权 使 用 人 数 :"..(v.Info and v.Info[ToAddTags] and v.Info[ToAddTags][GrantID] and tostring(table.len(v.Info[ToAddTags][GrantID])) or "0")
      local str2 = "是 否 开 放 共 享 : "..(v:HasTag(IsShare) and "是" or "否")
      AddTaskTalk(player,str.."\n"..str1.."\n"..str2)
      return
    end
  end
  AddTaskTalk(player,"身 边 空 空 如 ...我 能 查 到 ...Ye")
end
local PrivateItem={["minerhat"]="矿 工 帽",["armor_sanity"]="夜魔盔甲",["cane"]="步行手杖",["piggyback"]="猪 皮 包",["orangestaff"]="传送手杖",["greenamulet"]="建造护符"}
local function OnInfo(player)
  if player and player.info then
    AddTaskTalk(player,playerdesc(player))
  end
end
local function OnGet(inst)
  if inst.info and inst.info.Item > 0 and playerlvl(inst) >= 30 then
    local x,y,z = inst.Transform:GetWorldPosition()
    local num = 0
    for _,v in pairs(_G.TheSim:FindEntities(x,0,z,10000,{"M_Private","GiftItem","ownerid_"..inst.userid})) do
      local tx,ty,tz = v.Transform:GetWorldPosition()
      if (x-tx)^2 + (z-tz)^2 > 16 then v.Transform:SetPosition(x,0,z) num = num+1 end
    end
    AddTaskTalk(inst,num > 0 and ("曾经有 "..tostring(num).."件 东西摆在我面前,可是我没有捡起它") or "我们之间的距离是否太遥远或太近??")
  end
end
local _PlayerList = {}
local function OnRestart(inst)
  local checktime = inst.userid and _PlayerList[inst.userid] and _PlayerList[inst.userid].restartT or 0
  if _G.os.time() > checktime then
    if inst.components and inst.components.inventory then inst.components.inventory:DropEverything(false,false) end
    inst:DoTaskInTime(0.5,function(inst) TheNet:Announce(inst:GetDisplayName().." 通 过 申 请 重 生......") end)
    _PlayerList[inst.userid] = _PlayerList[inst.userid] or {}
    _PlayerList[inst.userid].restartT = _G.os.time() + 30*60
    if inst:IsValid() then _G.TheWorld:PushEvent("ms_playerdespawnanddelete",inst) end
    return true
  end
  AddTaskTalk(inst,inst:GetDisplayName()..",重 生 请 求 失 败 ... 30 Min 你 懂 的",1)
  return false
end
local function OnSaveKey(inst,pwd)
  local str = "所有权提取码设置失败!\n长度必须大等于8位\n格式为:字母+数字+字母或数字+字母+数字"
  if string.IsValidKey(pwd) and inst.userid and _G.TheWorld.info["players"][inst.userid] then
    local isdup = false
    for k,v in pairs(_G.TheWorld.info["players"]) do if v.SaveKey==pwd and k~=inst.userid then isdup = true break end end
    if not isdup then
      _G.TheWorld.info["players"][inst.userid].SaveKey = pwd
      str = "记好了!提取码设置为："..tostring(pwd)
    end
  end
  AddTaskTalk(inst,str)
end
--OwnerID = "ownerid_"
local function OnGetByKey(inst,pwd)
  if string.IsValidKey(pwd) and inst.userid then
    local ownername,owerid = nil,nil
    for k,v in pairs(_G.TheWorld.info["players"]) do if v.SaveKey==pwd and k~=inst.userid then ownername =v.name owerid=k break end end
    if owerid ~= nil then
      local num = 0
      for _,s in pairs(TheSim:FindEntities(0,0,0,10000,{"M_Private","ownerid_"..owerid},{"GiftItem","INLIMBO"})) do
        s:RemoveTag("ownerid_"..owerid)
        s:AddTag("ownerid_"..inst.userid)
        s:AddTag("ownerid_"..inst.userid)
        s.Info[ToAddTags][OwnerID] = OwnerID..inst.userid
      end
      _G.TheWorld.info["players"][inst.userid].SaveKey = "null"
      inst.info.SaveKey = "null"
      AddTaskTalk(inst,"获得所有权共计:" ..tostring(num).."处")
    end
  end
end
local function OnSetSuper(inst,num)
  local target = tonumber(num) and AllPlayers[tonumber(num)] or inst
  local set =_SuperPlayers[target.userid] == nil or not _SuperPlayers[target.userid]
  _SuperPlayers[target.userid] = set
  AddTaskTalk(target,set and "OH OH OH 成为超级人物啦!!!" or "NO NO NO 不是超级人物啦!!!")
end
local function Onhelp(inst)
  local help = HelpInfo
  AddTaskTalk(inst,help,1)
  AddTaskTalk(inst,help,3)
end
local _ClearPrefabs = {["faroz_gls"]=0,["wheatpouch"]=0,["acehat"]=0,["skeleton_player"]=0,["lavae"]=0,["stinger"]=2,["guano"]=2,["spoiled_food"]=10,["boneshard"]=2,["feather_crow"]=2,["feather_robin"]=2,["feather_robin_winter"]=2,["houndstooth"]=2,["poop"]=2,}
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
    AddTaskTalk(inst,"好 啦 好 啦 ! 世 界 清 静 了! 清 理 数 量 : "..tostring(delnum),0.5)
  else
    local map ={["1"] = 5,["101"] = 6,["102"] = 7,["103"] = 8,["201"] = 9,["202"] = 10,["203"] = 11}
    _G.TheWorld:DoTaskInTime(map[_G.TheShard:GetShardId()] or 5, function() TheNet:Announce(_G.TheShard:GetShardId().."号图清理掉落物数量共计 : "..tostring(delnum)) end)
  end
end
local function clearworld(inst,data)
  if math.mod(_G.TheWorld.state.cycles,10) == 0 and _G.TheWorld.state.cycles > 20 then OnClearMap(inst) end
end
local function DoAnnounce(inst,data)
  if _G.TheShard:GetShardId()~="1" then return end
  if first < 2 then first = first + 1 return end
  local num = #_MSG
  if _G.TheWorld.state.cycles < 10 then
    local inter = math.ceil(7*60/num)
    for i = 1, num do
      _G.TheWorld:DoTaskInTime(inter*i, function() _G.TheNet:Announce(_MSG[i]) end)
    end
  else
    _G.TheWorld:DoTaskInTime(20, function() _G.TheNet:Announce(_MSG[1]) end)
    for i= 1,4 do
      _G.TheWorld:DoTaskInTime(90*i, function() _G.TheNet:Announce(_MSG[math.random(1+i,num)]) end)
    end
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
    AddTaskTalk(inst,target.name.." Kick 他 怎 么 了 ?")
    target.components.inventory:DropEverything(false, false)
    TheNet:Kick(target.userid)
  end
end
local function OnBan(inst,num)
  local target = tonumber(num) and AllPlayers[tonumber(num)]
  if target then
    AddTaskTalk(inst,target.name.." Ban 他 怎 么 了 ?")
    target.components.inventory:DropEverything(false, false)
    TheNet:Ban(target.userid)
  end
end
local _BurnTags = {Light = "canlight",NoLight = "nolight",FireImmune = "fireimmune"}
local function RemoveBurnable(inst)
  if inst and inst.components.burnable and not inst:HasTag("campfire") then
    RemoveTags(inst,_BurnTags.Light)
    AddTags(inst,{_BurnTags.NoLight,_BurnTags.FireImmune,})
    inst.Info = inst.Info or {}
    inst.Info[ToAddTags] = inst.Info[ToAddTags] or {}
    inst.Info[ToDelTags] = inst.Info[ToDelTags] or {}
    inst.Info[ToDelTags][_BurnTags.Light] = _BurnTags.Light
    inst.Info[ToAddTags][_BurnTags.NoLight] = _BurnTags.NoLight
    inst.Info[ToAddTags][_BurnTags.FireImmune] = _BurnTags.FireImmune
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
    if type(DeployItems[act.invobject.prefab]) == "string" and  InPrivateTown(act.doer,40) > _InTown.null then
      if act.invobject.components.deployable:CanDeploy(act.pos) then
        local obj = (act.doer.components.inventory and act.doer.components.inventory:RemoveItem(act.invobject)) or (act.doer.components.container and act.doer.components.container:RemoveItem(act.invobject))
        if obj.components.deployable:Deploy(act.pos,act.doer) then
          for _,v in pairs(TheSim:FindEntities(x,y,z,1,nil,{IsPrivate})) do
            if v and v.prefab == DeployItems[act.invobject.prefab] then
              SetInfo(act.doer,_ActionType.OnDeloy,v)
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
    elseif type(DeployItems[act.invobject.prefab]) == "number" then
      local limitrange = DeployItems[act.invobject.prefab]
      if InPrivateTown(act.doer,limitrange) > _InTown.owner or HasEntityInRange(x,y,z,limitrange,{"multiplayer_portal"}) then return end
    end
  end
  return old_action_deploy(act)
end
local old_haunt_action = _G.ACTIONS.HAUNT.fn
_G.ACTIONS.HAUNT.fn = function(act)
  if _G.TheWorld.ismastersim == false then return old_haunt_action(act) end
  if act.target and act.target.prefab and table.contains({"multiplayer_portal","resurrectionstone","amulet"},act.target.prefab) then
    return old_haunt_action(act)
  else
    return
  end
end
local old_hammer_action = _G.ACTIONS.HAMMER.fn
_G.ACTIONS.HAMMER.fn = function(act)
  if _G.TheWorld.ismastersim == false then return old_hammer_action(act) end
  if IsSuperUser(act.doer) or (act.target and OwnershipRole(act.doer,act.target) < _Privilege.granted) then
    return old_hammer_action(act)
  else
    AddTaskTalk(act.doer,"强 拆 和 城 管 是 一 伙 的  吗 ?",0.5)
    return
  end
end
local old_dig_action = _G.ACTIONS.DIG.fn
_G.ACTIONS.DIG.fn = function(act)
  if _G.TheWorld.ismastersim == false then return old_dig_action(act) end
  if IsSuperUser(act.doer) or (act.target and (OwnershipRole(act.doer,act.target) < _Privilege.granted or InPrivateTown(act.doer,40) <= _InTown.granted)) then
    return old_dig_action(act)
  else
    AddTaskTalk(act.doer,"种 的 光 荣...挖 的 尾 大...",0.5)
    return
  end
end
local old_terraform_action = _G.ACTIONS.TERRAFORM.fn
_G.ACTIONS.TERRAFORM.fn = function(act)
  local tile = act.doer:GetCurrentTileType()
  if IsSuperUser(act.doer) or not ((tile == _G.GROUND.CARPET or tile == _G.GROUND.CHECKER or tile == _G.GROUND.WOOD or tile == _G.GROUND.SCALE) and InPrivateTown(act.doer,30) > _InTown.granted) then
    return old_terraform_action(act)
  else
    AddTaskTalk(act.doer,"哇 哇 ... 挖 挖 ...更 健 康 ",0.5)
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
    AddTaskTalk(act.doer,"喂 ! 1 1 9 吗 ? 这 里 有 头 熊...",0.5)
    return
  end
end
local old_networking_say = _G.Networking_Say
_G.Networking_Say =  function(guid,userid,name,prefab,message,colour,whisper)
  local oldsayinst = old_networking_say(guid,userid,name,prefab,message,colour,whisper)
  local talker = GetOnlinePlayerById(userid)
  if talker == nil then return oldsayinst end
  if whisper  and talker and talker.userid then
    local execom = {}
    for word in string.gmatch(message,"%S+") do
      local temp = _G.tonumber(word) and _G.tonumber(word) or string.lower(word)
      table.insert(execom,temp)
    end
    if execom[1] and _CommandList[execom[1]] and table.len(execom) == 1 then
      if     execom[1] =="help" then Onhelp(talker)
      elseif execom[1] =="grant" then OnGrant(talker)
      elseif execom[1] =="revoke" then OnRevoke(talker)
      elseif execom[1] =="share" then OnShare(talker)
      elseif execom[1] =="unshare" then OnUnshare(talker)
      elseif execom[1] =="ls" then OnLs(talker)
      elseif execom[1] =="info" then OnInfo(talker)
      elseif execom[1] =="restart" then OnRestart(talker)
      elseif execom[1] =="get" then OnGet(talker)
      elseif execom[1] =="clearmap" and _SuperPlayers[talker.userid] then OnClearMap(talker)
      elseif execom[1] =="lsplayer" and _SuperPlayers[talker.userid] then OnLsplayer(talker)
      elseif execom[1] =="ban" and _SuperPlayers[talker.userid] then OnBan(talker,execom[2])
      elseif execom[1] =="kick" and _SuperPlayers[talker.userid] then OnKick(talker,execom[2])
      elseif execom[1] =="setsuper" and _SuperPlayers[talker.userid]~=nil then OnSetSuper(talker,execom[2])
      end
    end
  end
  return oldsayinst
end

local function OnBuild_new(doer,prod)
  if prod.components.inventoryitem == nil and doer.userid then
    local x,y,z = doer.Transform:GetWorldPosition()
    SetInfo(doer,_ActionType.OnBuilt,prod)
    AddTags(prod,prod.Info[ToAddTags])
    SetDesc(prod)
    if prod.components.container and not prod:HasTag(IsShare) then prod.AnimState:SetMultColour(0.5,0.5,0.5,1) end
    RemoveBurnable(prod)
  elseif prod.prefab and _SuperItem[prod.prefab] and IsSuperPlayer(doer) then
    SetInfo(doer,_ActionType.OnSuper,prod)
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
AddPlayerPostInit(function(inst)
  if inst.components.builder then
    if inst.components.builder.onBuild then
      inst.components.builder.onBuild_old = inst.components.builder.onBuild
    end
    inst.components.builder.onBuild = OnBuild_new
  end
end)
AddPrefabPostInit("multiplayer_portal",function(inst) inst:AddTag("multiplayer_portal") end)
AddPrefabPostInit("world", function(inst)
  inst:ListenForEvent("cycleschanged", DoAnnounce)
  inst:ListenForEvent("cycleschanged", clearworld)
end)
AddPrefabPostInit("grass",function(inst)
  inst.components.pickable.max_cycles  = _Adjust.GrassPickCycle
  inst.components.pickable.cycles_left = _Adjust.GrassPickCycle
end)
for _,prefab in pairs({"marsh_bush","reeds","sapling","tumbleweed","tallbirdnest","flower","flower_cave","flower_evil","grass","lichen","cactus","carrot","cave_banana_tree","cave_fern","berrybush","berrybush2","red_mushroom","green_mushroom","blue_mushroom",}) do
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
        AddTaskTalk(doer,"不 是 我 的...要 强 拆 吗 ??",0.5)
        return false
      else
        return target and target.prefab and _G.AllRecipes[target.prefab]
      end
    end
  end
end)
AddComponentPostInit("temperature",function(self)
  local GetInsulation_old = self.GetInsulation
  self.GetInsulation = function(self)
    local winterInsulation,summerInsulation = GetInsulation_old(self)
    local tile,data = self.inst:GetCurrentTileType()
    if tile == _G.GROUND.SCALE then
      return 1e+9,1e+9
    end
    return GetInsulation_old(self)
  end
end)
AddComponentPostInit("moisture",function(self)
  local GetMoistureRate_old = self.GetMoistureRate
  self.GetMoistureRate = function(self)
    local tile,data = self.inst:GetCurrentTileType()
    if tile == _G.GROUND.SCALE then
      return 0
    end
    return GetMoistureRate_old(self)
  end
end)
AddComponentPostInit("container",function(Container,inst)
  Container.Open_old = Container.Open
  function Container:Open(doer)
    if IsSuperUser(doer) or OwnershipRole(doer,inst) < _Privilege.null or (inst.prefab and inst.prefab == "cookpot") then
      return Container:Open_old(doer)
    else
      AddTaskTalk(doer,"谁 家 的 ? 小 气 包....",0.5)
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
      AddTaskTalk(doer,"谁 家 的 花 ? 强  采 行 不 ...",0.5)
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
      AddTaskTalk(harvester,"谁  家  的 鸟 ? 这  么  小...气...摸  一  下  都  不  行",0.5)
      return
    end
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
      ( item.components.edible.foodtype == _G.FOODTYPE.MEAT or
      item.prefab == "seeds" or
      _G.Prefabs[string.lower(item.prefab.."_seeds")] ~= nil
      ) then
      inst.AnimState:PlayAnimation("peck")
      inst.AnimState:PushAnimation("peck")
      inst.AnimState:PushAnimation("peck")
      inst.AnimState:PushAnimation("hop")
      inst.AnimState:PushAnimation("idle_bird",true)
      inst:DoTaskInTime(60 * _G.FRAMES,function(inst,item)
        if item.components.edible.foodtype == _G.FOODTYPE.MEAT then
          inst.components.lootdropper:SpawnLootPrefab("bird_egg")
        else
          local seed_name = _G.Prefabs[string.lower(item.prefab.."_seeds")] and string.lower(item.prefab.."_seeds") or "seeds"
          local num_seeds = seed_name == "seeds" and 1 or math.random(_seeds_num[1],_seeds_num[2])
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
