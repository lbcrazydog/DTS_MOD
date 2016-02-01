 function get_msg(name)
  local msg = {}
  msg["CommandList"] = {
    ["list"] = {"help","grant","revoke","share","unshare","info","ls","get","restart"},
    ["help"]= "查看指令,按U(密语)后输入指令",
    ["grant"]= "自建箱子授权给在屏幕内的基友可打开",
    ["revoke"]= "自建箱子取消grant授权",
    ["share"]= "自建箱子无条件给共享任何基友使用",
    ["unshare"]= "自建箱子上锁(取消share共享,grant授权的还可用)",
    ["info"]= "查看个人信息情况",
    ["ls"]= "查看身边箱子信息情况",
    ["get"]= "收回处于所在世界特制道具",
    ["restart"]= "重新选择角色,CD30分钟",
    ["clearmap"]= "管理员清理垃圾专用",
    ["lsplayer"]= "管理员查看专用",
    ["setsuper"]= "管理员授权专用",
    ["ban"]= "管理员ban熊专用",
    ["kick"]= "管理员kick熊专用",
  }
  msg["announce"] ={
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
    [11]="游戏内每隔10天自动清理地上常见垃圾物品(含部分人物MOD专用装备)\n请注意及时收拾掉落物进箱包！",
    [12]="本房为七世界组合而成：新人出生界,浅层洞穴,固定玩家界,永冬永夜界,永夏永昼界,深层洞穴1,深层洞穴2",
    [13]="提示:出生界各有2个洞口进入固定玩家界及洞穴一\n固定玩家界有各2个分别永冬及永夏;永冬与永夏有2个互通洞口\n永夏有2个洞口进入洞穴二,永冬有2个洞口进入洞穴三",
    [14]="玩家生存达一定等级后HOST赠送特制装备\n特制装备他人无法拾取及使用,随等级变化升级或收回",
    [15]="特制装备:矿工灯,步行手杖,猪皮包,夜魔盔甲,永恒瞬移手杖,永恒建造护符,\n每位玩家同时只赠送各一件,永不消失(指令get取回)",
    [16]="特制装备分3个品级,随玩家等级提升自动升级\n玩家等级  = (累计所玩天数/(重生restart次数 - 2) - 累计死亡次数*2)",
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
  return msg[name]
end
function table.len(t)
  local count = 0
  if type(t) == "table" then
    for _ in pairs(t) do count = count + 1 end
  end
  return count
end
function table.copy(from, deepCopy)
  if type(from) == "table" then
    local to = {}
    for k, v in pairs(from) do if deepCopy and type(v) == "table" then to[k] = table.copy(v) else to[k] = v end end
    return to
  end
end
function table.assign(to,from,keys)
  if type(from) == "table" and type(to) == "table" then
    for k,v in pairs(from) do if keys then if table.contains(keys,k) then to[k] = from[k] end else to[k]=from[k] end end
  end
end
function string.IsValidKey(key)
  if type(key) == "string" then
    local len  = string.len(key)
    local _,t1 = string.find(key,"%w+")
    local _,t2 = string.find(key,"%d+")
    local _,t3 = string.find(key,"%a+")
    return len >= 8 and len==t1 and t1~=t2 and t1~=t3
  end
end
