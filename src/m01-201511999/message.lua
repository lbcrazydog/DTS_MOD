function table.copy(from,deepCopy)
  if type(from)=="table" then
    local to={}
    for k, v in pairs(from) do if deepCopy and type(v)=="table" then to[k]=table.copy(v) else to[k]=v end end
    return to
  end
end
function SetModVariables(name)
  local msg={}
  ---玩家信息
  msg.playerinfo={name="无名氏",SaveKey="null",Restart=0,RestartOn=0,Death=0,CurAge=0,HisAge=0,HisMaxAge=0,DeathAge=0,DeathOn=0,Lvl=1,Left=0,Join=0,Item={minerhat=0,armor_sanity=0,cane=0,piggyback=0,orangestaff=0,greenamulet=0},Online=false}
  ---超级玩家
  msg.superuser={["OU_76561197960623716"]=true,["OU_76561198252289790"]=true}
  ---原参数调整  墙生命(+倍数)、冰箱保鲜时间(+倍数)、晒肉时间(-倍数)、煮时间(-倍数),草及果浆可收获次数(绝对次数),1为原值
  msg.adjust={wallenhance=10,fridge=100,dry=2,cook=2,grass=100,berrybush=100}
  ---眼塔攻击力、速度(绝对值);生命、生命回复(+倍数,1为原值)
  msg.eyeturret={dmg=70,attack_period=1,health=10,regen=20}
  ---喂蔬菜得种子数量范围
  msg.seedsrange ={1,3}
  ---快速拾取
  msg.quickpick={"marsh_bush","reeds","sapling","tumbleweed","tallbirdnest","flower","flower_cave","flower_evil","grass","lichen","cactus","carrot","cave_banana_tree","cave_fern","berrybush","berrybush2","red_mushroom","green_mushroom","blue_mushroom"}
  ---私有化标签
  msg.tags={private="IsPrivate",share="IsShare",town="IsTown",protect="noattack",left="IsLeft",super="IsSuper",gift="IsGift"}
  msg.burntags={light = "canlight",nolight = "nolight",fireimmune = "fireimmune"}
  ---位置常量0不在领地内,1自己领地内,2授权领地内,3共享领地内,4受保护的领地内
  msg.townstate={null=0,owner=1,granted=2,share=3,protect=4}
  ---权力常量0野生的,1自己的,2领地内,3授权的,4共享的,5无权
  msg.privilege={wild=0 ,owner=1,intown=2,granted=3,share=4,null=5}
  ---行为常量建造,建造领地,摆放,赠送,超级物品,授权,取消授权,共享,取消共享,提取,失效
  msg.action={OnBuilt=10,OnBuiltTown=11,OnDeloy=12,OnGift=18,OnSuper=19,OnGrant=20,OnRevoke=21,OnShare=22,OnUnShare=23,OnGet=24,OnExpire=30}
  ---超级物品
  msg.superitem={minerhat="fueled",yellowamulet="fueled",armor_sanity="armor",ruinshat="armor",armorruins="armor",cane="cane",piggyback="piggyback",amulet="staffEtc",orangeamulet="staffEtc",greenamulet="staffEtc",orangestaff="staffEtc",greenstaff="staffEtc",icestaff="staffEtc",book_sleep="book",book_gardening="book",book_brimstone="book",book_birds="book",book_tentacles="book",panflute="book",fertilizer="fertilizer"}
  ---赠送物品
  msg.gitfitem={minerhat=30,armor_sanity=30,cane=30,piggyback=30,orangestaff=110,greenamulet=110}
  msg.gitfname={minerhat="矿 工 帽",armor_sanity="夜魔盔甲",cane="步行手杖",piggyback="猪 皮 包",orangestaff="传送手杖",greenamulet="建造护符"}
  ---指令距离
  msg.cmddis = 3
  ---指令信息
  msg.command={
    userlist ={"help","share","unshare","grant","revoke","info","ls","gather","save","get","restart"},
    adminlist={"help","share","unshare","grant","revoke","info","ls","gather","restart","clearmap","lsplayer","setsuper","ban","kick",},
    help="查看指令,所有指令均按U后输入执行",
    grant="箱子授权给屏幕内基友使用",
    revoke="箱子取消grant授权",
    share="箱子无条件共享",
    unshare="箱子取消share共享",
    info="查看个人信息情况",
    ls="查看身边箱子信息情况",
    gather="收回处于所在世界特制道具",
    save="密码   设置所有权提取密码",
    get="密码    提 取设置密码人的所有权",
    restart="重新选择角色,CD30分钟",
    clearmap="管理员清理垃圾专用",
    lsplayer="管理员查看专用",
    setsuper="管理员授权专用",
    kick="管理员kick熊专用",
    ban="管理员ban熊专用",
  }
  ---定时弹幕信息
  msg.announce={
    [1]="指令一律为按U后输入执行,\"help\"查看游戏指令",
    [2]="箱子建造默认任何基友可用，按U执行\"unshare\"上锁\n建造者需在距箱子3码范围内输入指令",
    [3]="按U执行\"share\"无条件给任何基友使用箱子\n执行\"unshare\"上锁(但已授权的人还可用)",
    [4]="按U执行\"grant\"对在授权屏幕范围内的基友使用箱子\n执行\"revoke\"取消授权",
    [5]="对自建箱子设为完全私有可按U执行\"unshare\"后再次按U执行 \"revoke\"",
    [6]="在箱子边按U执行\"ls\"查看箱子信息",
    [7]="按U执行\"info\"查看自己可制作的私有道具情况",
    [8]="二级科技30码范为私人领地\n建造时需距离他人领地60码以上(约两个屏幕)",
    [9]="私人领地内领主建筑受绝对保护\n领主有拆清领地内所有建筑的权力(除他人所建在保护期内的箱子)",
    [10]="私人领地内作物 地皮防人为破坏保护\n同时他人不能放置敌对生物及建石墙...",
    [11]="游戏内每隔季第一天自动清理地上常见垃圾物品(含部分人物MOD专用装备)\n请注意及时收拾掉落物进箱包！",
    [12]="本房为七世界组合而成：新人出生界,浅层洞穴,固定玩家界,永冬永夜界,永夏永昼界,深层洞穴1,深层洞穴2",
    [13]="提示:出生界各有2个洞口进入固定玩家界及洞穴一\n固定玩家界有各2个分别永冬及永夏;永冬与永夏有2个互通洞口\n永夏有2个洞口进入洞穴二,永冬有2个洞口进入洞穴三",
    [14]="玩家生存达一定等级后HOST赠送特制装备\n特制装备他人无法拾取及使用,随等级变化升级或收回",
    [15]="特制装备:矿工灯,步行手杖,猪皮包,夜魔盔甲,永恒瞬移手杖,永恒建造护符,\n每位玩家同时只赠送各一件,永不消失(指令get取回)",
    [16]="特制装备分3个品级,随玩家等级提升自动升级\n玩家等级=(累计所玩天数/(重生restart次数 - 2) - 累计死亡次数*2)",
    [17]="按U执行\"get\"收回遗落在所处世界的特制装备",
    [18]="特制矿工 灯:品级1 照明时间16分钟,赠送条件:玩家等级30\n品级2照明时间32分钟,升级条件:玩家等级50\n品级3照明时间100分钟,升级条件:玩家等级70",
    [19]="特制步行手杖:品级1 附斧头功能,赠送条件:玩家等级30\n品级2另附镐功,升级条件:玩家等级50\n品级3另附共55点攻击力,升级条件:玩家等级70",
    [20]="特制猪皮包:品级1 附无束及锁功能,赠送条件:玩家等级30\n品级2另附理智及防潮功能,升级条件:玩家等级50\n品级3另附冰箱功能,升级条件:玩家等级70",
    [21]="特制夜魔盔甲:品级1 附永恒及理智功能 防60%,赠送条件:玩家等级30\n品级2防提升为75%,升级条件:玩家等级50\n品级3防提升为90%,升级条件:玩家等级70",
    [22]="特制瞬移手杖:附永恒功能,赠送条件:玩家等级110",
    [23]="特制建造护符:附永恒功能,赠送条件:玩家等级110",
    [24]="按U键输入\"restart\"重新选择角色,CD30分钟",
    [25]="从永夏或永冬进的洞穴每过两个冬天重置一次(140天)!从出生界进的洞穴不重置",
    [26]="本房7*24在线,除平台断线或游戏BUG崩溃!!Q群:399294520",
  }
  ---个性对话框
  msg.talkmsg ={
    cast = "不 是 我 的...要 强 拆 吗 ??",
    hammer="强 拆 和 城 管 是 一 伙 的  吗 ?",
    open = "谁 家 的 ? 小 气 包....",
    pick="谁 家 的 花 ? 强  采 行 不 ...",
    occupi="谁  家  的 鸟 ? 这  么  小...气...摸  一  下  都  不  行",
    light="喂 ! 1 1 9 吗 ? 这 里 有 头 熊...",
    terraform="哇 哇 ... 挖 挖 ...更 健 康 ",
    dig="种 的 光 荣...挖 的 尾 大...",
    get ="获 得 所 有 权 共 计 : ",
    infokey = "所有权提取码设置失败!\n长度必须大等于8位\n格式为:字母+数字+字母或数字+字母+数字",
    savekey = "记 好 了! 提 取 码 设 置 为 ：",
    restartfail = "重 生 请 求 失 败 ... 30 Min 你 懂 的",
    gather = "件 东 西 摆 在 我 面 前 , 可 是 我 没 有 捡 起 它...",
    gatherfail = "我 们 之 间 的 距 离 是 否 太 遥 远 或 太 近 了?",
    unshare = "没 人 能 再 使 用 这 ",
    lsfail = "身 边 空 空 如 ...我 能 查 到 ...Ye",
    unsharefail = "附 近 没 什 么 东 西 是 我 共 享 的 !",
    share = "Oh ... YEAH ... 所 有 人 都 可 用 这 ",
    sharefail = "附 近 没 什 么 东 西 可 共 享 的 !",
    revoke = " 个 基 友 已 无 权 使 用 这 ",
    revokefail = "附 近 没 什 么 是 我 授 权 的!",
    grant = " 个 基  友 可 用 这 ",
    grantfail = "附 近 有 什 么 自 己 建 的 可 授 权 ?",
    kick = " Kick 他 怎 么 了 ?",
    ban =" Ban 他 怎 么 了 ?",
    mapclear = "好 啦 好 啦 ! 世 界 清 静 了! 清 理 数 量 : ",
    onsuper="OH OH OH 成 为 超 人啦 !",
    offsuper="NO NO NO 平 民 百 姓 好 !",
    worldclear = "清理掉落物数量共计: ",
    restart = " (restart) 开 始 重 生......",
  }
  ---多世界设置
  msg.shard={master="1",main="101",summer="102",winter="102",cave01="201",cave02="202",cave03="203"}

  msg.mapsinfo={
    [msg.shard.master]={
      name="出生界",
      respawncycles=70,
      resetcycles=0,
      day="default",
      season="default",
      portlink={[1]=msg.shard.main,[2]=msg.shard.main,[3]=msg.shard.cave01,[4]=msg.shard.cave01}},
    [msg.shard.main]  ={
      name="固定界",
      respawncycles=0,
      resetcycles=0,
      day="default",
      season="default",
      portlink={[1]=msg.shard.master,[2]=msg.shard.master,[3]=msg.shard.summer,[4]=msg.shard.summer,[5]=msg.shard.cave01,[6]=msg.shard.cave01,[7]=msg.shard.winter,[8]=msg.shard.winter}},
    [msg.shard.summer]={
      name="永夏界",
      respawncycles=0,
      resetcycles=0,
      day={day=14,night=0,dusk=2},
      season={spring= 0,autumn=0,winter=0,summer=20},
      portlink={[1]=msg.shard.cave01,[2]=msg.shard.cave01,[3]=msg.shard.main,[4]=msg.shard.main,[5]=msg.shard.winter,[6]=msg.shard.winter}},
    [msg.shard.winter]={
      name="永冬界",
      respawncycles=0,
      resetcycles=0,
      day={day=14,night=0,dusk=2},
      season={spring= 0,autumn=0,winter=0,summer=20},
      portlink={[1]=msg.shard.cave03,[2]=msg.shard.cave03,[5]=msg.shard.summer,[6]=msg.shard.summer,[7]=msg.shard.main,[8]=msg.shard.main}},
    [msg.shard.cave01]={
      name="出生界洞穴",
      respawncycles=70,
      resetcycles=0,
      day="default",
      season="default",
      portlink={[3]=msg.shard.master,[4]=msg.shard.master,[5]=msg.shard.main,[6]=msg.shard.main}},
    [msg.shard.cave02]={
      name="永夏界洞穴",
      respawncycles=0,
      resetcycles=140,
      day="default",
      season="default",
      portlink={[1]=msg.shard.summer,[2]=msg.shard.summer}},
    [msg.shard.cave03]={
      name="永冬界洞穴",
      respawncycles=0,
      resetcycles=140,
      day="default",
      season="default",
      portlink={[1]=msg.shard.winter,[2]=msg.shard.winter}},
  }
  ---重生物品(范围判断)
  msg.respawnprefabs={
    knight=10,rook=10,bishop=10,rock1=1,rock2=1,beefalo=20,lightninggoat=20,cactus=1,reeds=1,
    rook_nightmare=10,bishop_nightmare=10,knight_nightmare=10,
    wall_ruins=1,ruins_statue_head=1,ruins_statue_mage=1,ruins_statue_mage_nogem=1,rock_flintless=1,rock_flintless_low=1,rock_flintless_med=1
  }
  ---清理物品(=0不可叠加,>0为可叠加,数量判断<=时清理)
  msg.clearprefabs={
    ["faroz_gls"]=0,["wheatpouch"]=0,["acehat"]=0,["skeleton_player"]=0,["lavae"]=0,["stinger"]=2,
    ["guano"]=2,["spoiled_food"]=10,["boneshard"]=2,["feather_crow"]=2,["feather_robin"]=2,
    ["feather_robin_winter"]=2,["houndstooth"]=2,["poop"]=2,
  }
  return table.copy(msg[name], true)
end
function table.len(t)
  local count=0
  if type(t)=="table" then
    for _ in pairs(t) do count=count + 1 end
  end
  return count
end
function table.assign(to,from,keys)
  if type(from)=="table" and type(to)=="table" then
    for k,v in pairs(from) do if keys then if table.contains(keys,k) then to[k]=from[k] end else to[k]=from[k] end end
  end
end
function table.contains(table, element)
  if type(table) ~= "table" then return false end
  for _, value in pairs(table) do if value == element then return true end end
  return false
end
function table.concatn(t,catkey,keylist)
  if type(t) == "table" then
    local cat=""
    if type(keylist) == "table" then
      for _,v in pairs(keylist) do cat=cat..(t[v] and ((catkey and tostring(v).." " or "")..tostring(t[v]).."\n") or "") end
    else
      for k,v in pairs(t) do cat=cat..(catkey and tostring(k).." " or "") ..tostring(v).."\n" end
    end
    return cat
  else
    return tostring(t)
  end
end
function string.IsValidKey(key)
  if type(key)=="string" then
    local len=string.len(key)
    local _,t1=string.find(key,"%w+")
    local _,t2=string.find(key,"%d+")
    local _,t3=string.find(key,"%a+")
    return len >=8 and len==t1 and t1~=t2 and t1~=t3
  end
end
