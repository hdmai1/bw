
local Version, DisplayVersion, Geometry = 1.66, "1.66"
local Url = "https://raw.githubusercontent.com/Ark223/Bruhwalker/main/"


local Class = function(...)
    local cls = {}
    cls.__index = cls
    function cls:New(...)
        local instance = setmetatable({}, cls)
        cls.__init(instance, ...)
        return instance
    end
    cls.__call = function(_, ...) return cls:New(...) end
    return setmetatable(cls, {__call = cls.__call})
end

require "DreamPred"
local load = loadstring or load
local myHero = game.local_player

local Logo = os.getenv('APPDATA'):gsub("Roaming",
    "Local\\leaguesense\\scripts\\Orbwalker.png")
if not file_manager:file_exists(Logo) then
    local name = Url .. "Orbwalker.png"
    http:download_file(name, "Orbwalker.png")
end

--------------------------------------
-- Language INtegrated Query (LINQ) --

local function ParseFunc(func)
    if func == nil then return function(x) return x end end
    if type(func) == "function" then return func end
    local index = string.find(func, "=>")
    local arg = string.sub(func, 1, index - 1)
    local func = string.sub(func, index + 2, #func)
    return load(string.format("return function"
        .. " %s return %s end", arg, func))()
end

local function Linq(tab)
    return setmetatable(tab or {}, {__index = table})
end

function table.Aggregate(source, func, seed)
    local result = seed or 0
    local func = ParseFunc(func)
    for index, value in ipairs(source) do
        result = func(result, value, index)
    end
    return result
end

function table.All(source, func)
    local func = ParseFunc(func)
    for index, value in ipairs(source) do
        if not func(value, index) then
            return false
        end
    end
    return true
end

function table.Any(source, func)
    local func = ParseFunc(func)
    for index, value in ipairs(source) do
        if func(value, index) then
            return true
        end
    end
    return false
end

function table.Concat(first, second)
    local result, index = Linq(), 0
    for _, value in ipairs(first) do
        index = index + 1
        result[index] = value
    end
    for _, value in ipairs(second) do
        index = index + 1
        result[index] = value
    end
    return result
end

function table.Contains(source, element)
    for _, value in ipairs(source) do 
        if value == element then
            return true
        end
    end
    return false
end

function table.Distinct(source)
    local result = Linq()
    local hash, index = {}, 0
    for _, value in ipairs(source) do
        if hash[value] == nil then
            index = index + 1
            result[index] = value
            hash[value] = true
        end
    end
    return result
end

function table.Except(first, second)
    return first:Where(function(value)
        return not second:Contains(value) end)
end

function table.First(source, func)
    local func = ParseFunc(func)
    for index, value in ipairs(source) do
        if func(value, index) then
            return value
        end
    end
    return nil
end

function table.ForEach(source, func)
    for index, value in pairs(source) do
        func(value, index)
    end
end

function table.Last(source, func)
    local func = ParseFunc(func)
    for index = #source, 1, -1 do
        local value = source[index]
        if func(value, index) then
            return value
        end
    end
    return nil
end

function table.Max(source, func)
    local result = -math.huge
    local func = ParseFunc(func)
    for index, value in ipairs(source) do
        local num = func(value, index)
        if type(num) == "number" and num >
            result then result = num end
    end
    return result
end

function table.Min(source, func)
    local result = math.huge
    local func = ParseFunc(func)
    for index, value in ipairs(source) do
        local num = func(value, index)
        if type(num) == "number" and num <
            result then result = num end
    end
    return result
end

function table.Select(source, func)
    local result = Linq()
    local func = ParseFunc(func)
    for index, value in ipairs(source) do
        result[index] = func(value, index)
    end
    return result
end

function table.RemoveWhere(source, func)
    local size = #source
    local func = ParseFunc(func)
    for index = size, 1, -1 do
        local value = source[index]
        if func(value, index) then
            source:remove(index)
        end
    end
    return size ~= #source
end

function table.SelectMany(source, selector, collector)
    local result = Linq()
    local selector = ParseFunc(selector)
    local collector = ParseFunc(collector)
    for index, value in ipairs(source) do
        local position = #result
        local values = selector(value, index)
        for iteration, element in ipairs(values) do
            local index = position + iteration
            result[index] = collector(value, element)
        end
    end
    return result
end

function table.Where(source, func)
    local result, iteration = Linq(), 0
    local func = ParseFunc(func)
    for index, value in ipairs(source) do
        if func(value, index) then
            iteration = iteration + 1
            result[iteration] = value
        end
    end
    return result
end

------------------
-- Damage class --

local Damage = Class()

function Damage:__init()
    self.heroPassives = {
        ["Aatrox"] = function(args) local source = args.source -- 12.20
            if not source:has_buff("aatroxpassiveready") then return end
            args.rawPhysical = args.rawPhysical + (4.59 + 0.41
                * source.level) * 0.01 * args.unit.max_health
        end,
        ["Akali"] = function(args) local source = args.source -- 12.20
            if not source:has_buff("akalishadowstate") then return end
            local mod = ({35, 38, 41, 44, 47, 50, 53, 62, 71, 80,
                89, 98, 107, 122, 137, 152, 167, 182})[source.level]
            args.rawMagical = args.rawMagical + mod + 0.55 *
                source.ability_power + 0.6 * source.bonus_attack_damage
        end,
        ["Akshan"] = function(args) local source = args.source -- 12.20
            local buff = args.unit:get_buff("AkshanPassiveDebuff")
            if not buff or buff.count ~= 2 then return end
            local mod = ({10, 15, 20, 25, 30, 35, 40, 45, 55, 65,
                75, 85, 95, 105, 120, 135, 150, 165})[source.level]
            args.rawMagical = args.rawMagical + mod
        end,
        ["Ashe"] = function(args) local source = args.source -- 12.20
            local totalDmg = source.total_attack_damage
            local slowed = args.unit:has_buff("ashepassiveslow")
            local mod = 0.0075 + (source:has_item(3031) and 0.0035 or 0)
            local percent = slowed and 0.1 + source.crit_chance * mod or 0
            args.rawPhysical = args.rawPhysical + percent * totalDmg
            if not source:has_buff("AsheQAttack") then return end
            local lvl = spellbook:get_spell_slot(SLOT_Q).level
            args.rawPhysical = args.rawPhysical * (1 + 0.05 * lvl)
        end,
        ["Bard"] = function(args) local source = args.source -- 12.20
            if not source:has_buff("bardpspiritammocount") then return end
            local chimes = source:get_buff("bardpdisplaychimecount")
            if not chimes or chimes.count <= 0 then return end
            args.rawMagical = args.rawMagical + (14 * math.floor(
                chimes.count / 5)) + 35 + 0.3 * source.ability_power
        end,
        ["Blitzcrank"] = function(args) local source = args.source -- 12.20
            if not source:has_buff("PowerFist") then return end
            args.rawPhysical = args.rawPhysical + 1.5 *
                source.ability_power + 2.5 * source.total_attack_damage
        end,
        ["Braum"] = function(args) local source = args.source -- 12.20
            local buff = args.unit:get_buff("BraumMark")
            if not buff or buff.count ~= 3 then return end
            args.rawMagical = args.rawMagical + 16 + 10 * source.level
        end,
        ["Caitlyn"] = function(args) local source = args.source -- 12.20
            if not source:has_buff("caitlynpassivedriver") then return end
            local bonus = 1.3125 + (source:has_item(3031) and 0.2625 or 0)
            local mod = ({1.1, 1.1, 1.1, 1.1, 1.1, 1.1, 1.15, 1.15, 1.15,
                1.15, 1.15, 1.15, 1.2, 1.2, 1.2, 1.2, 1.2, 1.2})[source.level]
            args.rawPhysical = args.rawPhysical + (mod + (bonus * 0.01 *
                source.crit_chance)) * source.total_attack_damage
        end,
        ["Camille"] = function(args) local source = args.source -- 12.20
            local lvl = spellbook:get_spell_slot(SLOT_Q).level
            if source:has_buff("CamilleQ") then
                args.rawPhysical = args.rawPhysical + (0.15 +
                    0.05 * lvl) * source.total_attack_damage
            elseif source:has_buff("CamilleQ2") then
                args.trueDamage = args.trueDamage + math.min(
                    0.36 + 0.04 * source.level, 1) * (0.3 +
                    0.1 * lvl) * source.total_attack_damage
            end
        end,
        ["Chogath"] = function(args) local source = args.source -- 12.20
            if not source:has_buff("VorpalSpikes") then return end
            local lvl = spellbook:get_spell_slot(SLOT_E).level
            args.rawMagical = args.rawMagical + 10 + 12 * lvl + 0.3 *
                source.ability_power + 0.03 * args.unit.max_health
        end,
        ["Darius"] = function(args) local source = args.source -- 12.20
            if not source:has_buff("DariusNoxianTacticsONH") then return end
            local lvl = spellbook:get_spell_slot(SLOT_W).level
            args.rawPhysical = args.rawPhysical + (0.35 +
                0.05 * lvl) * source.total_attack_damage
        end,
        ["Diana"] = function(args) local source = args.source -- 12.20
            local buff = source:get_buff("dianapassivemarker")
            if not buff or buff.count ~= 2 then return end
            local mod = ({20, 25, 30, 35, 40, 45, 55, 65, 75,
                85, 95, 110, 125, 140, 155, 170, 195, 220})[source.level]
            args.rawMagical = args.rawMagical + mod + 0.5 * source.ability_power
        end,
        ["Draven"] = function(args) local source = args.source -- 12.20
            if not source:has_buff("DravenSpinningAttack") then return end
            local lvl = spellbook:get_spell_slot(SLOT_Q).level
            args.rawPhysical = args.rawPhysical + 35 + 5 * lvl +
                (0.65 + 0.1 * lvl) * source.bonus_attack_damage
        end,
        ["DrMundo"] = function(args) local source = args.source
            if not source:has_buff("DrMundoE") then return end
            --[[ local lvl = spellbook:get_spell_slot(SLOT_E).level
            local bonusHealth = source.max_health - (494 + source.level * 89)
            args.rawPhysical = args.rawPhysical + (0.14 * bonusHealth - 10
                + 20 * lvl) * (1 + 1.5 * math.min((source.max_health
                - source.health) / source.max_health, 0.4)) --]]
        end,
        ["Ekko"] = function(args) local source = args.source -- 12.20
            local buff = args.unit:get_buff("ekkostacks")
            if buff ~= nil and buff.count == 2 then
                local mod = ({30, 40, 50, 60, 70, 80, 85, 90, 95, 100,
                    105, 110, 115, 120, 125, 130, 135, 140})[source.level]
                args.rawMagical = args.rawMagical + mod + 0.9 * source.ability_power
            end
            if source:has_buff("ekkoeattackbuff") then
                local lvl = spellbook:get_spell_slot(SLOT_E).level
                args.rawMagical = args.rawMagical + 25 +
                    25 * lvl + 0.4 * source.ability_power
            end
        end,
        ["Fizz"] = function(args) local source = args.source -- 12.20
            if not source:has_buff("FizzW") then return end
            local lvl = spellbook:get_spell_slot(SLOT_W).level
            args.rawMagical = args.rawMagical + 30 +
                20 * lvl + 0.5 * source.ability_power
        end,
        ["Galio"] = function(args) local source = args.source
            if not source:has_buff("galiopassivebuff") then return end
            --[[ local bonusResist = source.mr - (30.75 + 1.25 * source.level)
            args.rawMagical, args.rawPhysical = args.rawMagical + 4.12 +
                10.88 * source.level + source.total_attack_damage +
                0.5 * source.ability_power + 0.6 * bonusResist, 0 --]]
        end,
        ["Garen"] = function(args) local source = args.source -- 12.20
            if not source:has_buff("GarenQ") then return end
            local lvl = spellbook:get_spell_slot(SLOT_Q).level
            args.rawPhysical = args.rawPhysical + 30 *
                lvl + 0.5 * source.total_attack_damage
        end,
        ["Gnar"] = function(args) local source = args.source -- 12.20
            local buff = args.unit:get_buff("gnarwproc")
            if not buff or buff.count ~= 2 then return end
            local lvl = spellbook:get_spell_slot(SLOT_W).level
            args.rawMagical = args.rawMagical - 10 + 10 * lvl + (0.04 +
                0.02 * lvl) * args.unit.max_health + source.ability_power
        end,
        ["Gragas"] = function(args) local source = args.source -- 12.20
            if not source:has_buff("gragaswattackbuff") then return end
            local lvl = spellbook:get_spell_slot(SLOT_W).level
            args.rawMagical = args.rawMagical - 10 + 30 * lvl + 0.07
                * args.unit.max_health + 0.7 * source.ability_power
        end,
        ["Gwen"] = function(args) local source = args.source -- 12.20
            args.rawMagical = args.rawMagical + (0.01 + 0.008 *
                0.01 * source.ability_power) * args.unit.max_health
            if args.unit.health / args.unit.max_health <= 0.4 then
                args.rawMagical = args.rawMagical + 6.71 + 1.29 * source.level
            end
        end,
        ["Illaoi"] = function(args) local source = args.source -- 12.20
            if not source:has_buff("IllaoiW") then return end
            local lvl = spellbook:get_spell_slot(SLOT_W).level
            local damage = math.min(300, math.max(10 + 10 * lvl,
                args.unit.max_health * (0.025 + 0.005 * lvl
                + 0.0004 * source.total_attack_damage)))
            args.rawPhysical = args.rawPhysical + damage
        end,
        ["Irelia"] = function(args) local source = args.source -- 12.20
            local buff = source:get_buff("ireliapassivestacks")
            if not buff or buff.count ~= 4 then return end
            args.rawMagical = args.rawMagical + 7 + 3 *
                source.level + 0.2 * source.bonus_attack_damage
        end,
        ["JarvanIV"] = function(args) local source = args.source -- 12.20
            if not args.unit:has_buff("jarvanivmartialcadencecheck") then return end
            local damage = math.min(400, math.max(20, 0.08 * args.unit.health))
            args.rawPhysical = args.rawPhysical + damage
        end,
        ["Jax"] = function(args) local source = args.source -- 12.20
            if source:has_buff("JaxEmpowerTwo") then
                local lvl = spellbook:get_spell_slot(SLOT_W).level
                args.rawMagical = args.rawMagical + 15 +
                    35 * lvl + 0.6 * source.ability_power
            end
            if source:has_buff("JaxRelentlessAssault") then
                local lvl = spellbook:get_spell_slot(SLOT_R).level
                args.rawMagical = args.rawMagical + 60 +
                    40 * lvl + 0.7 * source.ability_power
            end
        end,
        ["Jayce"] = function(args) local source = args.source -- 12.20
            if source:has_buff("JaycePassiveMeleeAttack") then
                local mod = ({25, 25, 25, 25, 25, 65,
                    65, 65, 65, 65, 105, 105, 105, 105,
                    105, 145, 145, 145})[source.level]
                args.rawMagical = args.rawMagical + mod
                    + 0.25 * source.bonus_attack_damage
            end
            if source:has_buff("HyperChargeBuff") then
                local lvl = spellbook:get_spell_slot(SLOT_W).level
                local mod = ({0.7, 0.78, 0.86, 0.94, 1.02, 1.1})[lvl]
                arga.rawPhysical = mod * source.total_attack_damage
            end
        end,
        ["Jhin"] = function(args) local source = args.source -- 12.20
            if not source:has_buff("jhinpassiveattackbuff") then return end
            local missingHealth, mod = args.unit.max_health - args.unit.health,
                source.level < 6 and 0.15 or source.level < 11 and 0.2 or 0.25
            args.rawPhysical = args.rawPhysical + mod * missingHealth
        end,
        ["Jinx"] = function(args) local source = args.source -- 12.20
            if not source:has_buff("JinxQ") then return end
            args.rawPhysical = args.rawPhysical
                + source.total_attack_damage * 0.1
        end,
        ["Kaisa"] = function(args) local source = args.source -- 12.20
            local buff = args.unit:get_buff("kaisapassivemarker")
            local count = buff ~= nil and buff.count or 0
            local damage = ({5, 5, 8, 8, 8, 11, 11, 11, 14, 14,
                17, 17, 17, 20, 20, 20, 23, 23})[source.level] +
                ({1, 1, 1, 3.75, 3.75, 3.75, 3.75, 6.5, 6.5, 6.5, 6.5,
                9.25, 9.25, 9.25, 9.25, 12, 12, 12})[source.level] * count
                + (0.125 + 0.025 * (count + 1)) * source.ability_power
            if count == 4 then damage = damage +
                (0.15 + (0.06 * source.ability_power / 100)) *
                (args.unit.max_health - args.unit.health) end
            args.rawMagical = args.rawMagical + damage
        end,
        ["Kassadin"] = function(args) local source = args.source -- 12.20
            local lvl = spellbook:get_spell_slot(SLOT_W).level
            if source:has_buff("NetherBlade") then
                args.rawMagical = args.rawMagical + 25 +
                    25 * lvl + 0.8 * source.ability_power
            elseif lvl > 0 then
                args.rawMagical = args.rawMagical +
                    20 + 0.1 * source.ability_power
            end
        end,
        ["Kayle"] = function(args) local source = args.source -- 12.20
            local lvl = spellbook:get_spell_slot(SLOT_E).level
            if lvl > 0 then args.rawMagical = args.rawMagical
                + 10 + 5 * lvl + 0.2 * source.ability_power
                + 0.1 * source.bonus_attack_damage end
            if source:has_buff("JudicatorRighteousFury") then
                args.rawMagical = args.rawMagical + (7.5 + 0.5 * lvl
                    + source.ability_power * 0.01 * 1.5) * 0.01 *
                    (args.unit.max_health - args.unit.health)
            end
        end,
        ["Kennen"] = function(args) local source = args.source -- 12.20
            if not source:has_buff("kennendoublestrikelive") then return end
            local lvl = spellbook:get_spell_slot(SLOT_W).level
            args.rawMagical = args.rawMagical + 25 + 10 * lvl + (0.7 + 0.1 *
                lvl) * source.bonus_attack_damage + 0.35 * source.ability_power
        end,
        ["KogMaw"] = function(args) local source = args.source -- 12.20
            if not source:has_buff("KogMawBioArcaneBarrage") then return end
            local lvl = spellbook:get_spell_slot(SLOT_W).level
            args.rawMagical = args.rawMagical + math.min(100, (0.0275 + 0.0075
                * lvl + 0.0001 * source.ability_power) * args.unit.max_health)
        end,
        ["Leona"] = function(args) local source = args.source -- 12.20
            if not source:has_buff("LeonaSolarFlare") then return end
            local lvl = spellbook:get_spell_slot(SLOT_Q).level
            args.rawMagical = args.rawMagical - 15 +
                25 * lvl + 0.3 * source.ability_power
        end,
        ["Lux"] = function(args) local source = args.source -- 12.20
            if not args.unit:has_buff("LuxIlluminatingFraulein") then return end
            args.rawMagical = args.rawMagical + 10 + 10 *
                source.level + 0.2 * source.ability_power
        end,
        ["Malphite"] = function(args) local source = args.source -- 12.20
            if not source:has_buff("MalphiteCleave") then return end
            local lvl = spellbook:get_spell_slot(SLOT_W).level
            args.rawPhysical = args.rawPhysical + 15 + 15 * lvl
                + 0.2 * source.ability_power + 0.1 * source.armor
        end,
        ["MasterYi"] = function(args) local source = args.source -- 12.20
            if not source:has_buff("wujustylesuperchargedvisual") then return end
            local lvl = spellbook:get_spell_slot(SLOT_E).level
            args.trueDamage = args.trueDamage + 25 + 5 *
                lvl + 0.3 * source.bonus_attack_damage
        end,
        -- MissFortune - can't detect buff ??
        ["Mordekaiser"] = function(args) local source = args.source -- 12.20
            args.rawMagical = args.rawMagical + 0.4 * source.ability_power
        end,
        ["Nami"] = function(args) local source = args.source -- 12.20
            if not source:has_buff("NamiE") then return end
            local lvl = spellbook:get_spell_slot(SLOT_E).level
            args.rawMagical = args.rawMagical + 10 +
                15 * lvl + 0.2 * source.ability_power
        end,
        ["Nasus"] = function(args) local source = args.source -- 12.20
            if not source:has_buff("NasusQ") then return end
            local buff = source:get_buff("NasusQStacks")
            local stacks = buff ~= nil and buff.count or 0
            local lvl = spellbook:get_spell_slot(SLOT_Q).level
            args.rawPhysical = args.rawPhysical + 10 + 20 * lvl + stacks
        end,
        ["Nautilus"] = function(args) local source = args.source -- 12.20
            if args.unit:has_buff("nautiluspassivecheck") then return end
            args.rawPhysical = args.rawPhysical + 2 + 6 * source.level
        end,
        ["Nidalee"] = function(args) local source = args.source -- 12.20
            if not source:has_buff("Takedown") then return end
            local lvl = spellbook:get_spell_slot(SLOT_Q).level
            args.rawMagical = args.rawMagical + (-20 + 25 *
                lvl + 0.75 * source.total_attack_damage + 0.4 *
                source.ability_power) * ((args.unit.max_health -
                args.unit.health) / args.unit.max_health + 1)
            if args.unit:has_buff("NidaleePassiveHunted") then
                args.rawMagical = args.rawMagical * 1.4 end
            args.rawPhysical = 0
        end,
        ["Neeko"] = function(args) local source = args.source -- 12.20
            if not source:has_buff("neekowpassiveready") then return end
            local lvl = spellbook:get_spell_slot(SLOT_W).level
            args.rawMagical = args.rawMagical + 20 +
                30 * lvl + 0.6 * source.ability_power
        end,
        ["Nocturne"] = function(args) local source = args.source -- 12.20
            if not source:has_buff("nocturneumbrablades") then return end
            args.rawPhysical = args.rawPhysical + 0.2 * source.total_attack_damage
        end,
        ["Orianna"] = function(args) local source = args.source -- 12.20
            args.rawMagical = args.rawMagical + 2 + math.ceil(
                source.level / 3) * 8 + 0.15 * source.ability_power
            local buff = source:get_buff("orianapowerdaggerdisplay")
            if not buff or buff.count == 0 then return end
            args.rawMagical = raw.rawMagical * (1 + 0.2 * buff.count)
        end,
        ["Poppy"] = function(args) local source = args.source -- 12.20
            if not source:has_buff("poppypassivebuff") then return end
            args.rawMagical = args.rawMagical + 10.59 + 9.41 * source.level
        end,
        ["Quinn"] = function(args) local source = args.source -- 12.20
            if not args.unit:has_buff("QuinnW") then return end
            args.rawPhysical = args.rawPhysical + 5 + 5 * source.level +
                (0.14 + 0.02 * source.level) * source.total_attack_damage
        end,
        ["RekSai"] = function(args) local source = args.source -- 12.20
            if not source:has_buff("RekSaiQ") then return end
            local lvl = spellbook:get_spell_slot(SLOT_Q).level
            args.rawPhysical = args.rawPhysical + 15 + 6 *
                lvl + 0.5 * source.bonus_attack_damage
        end,
        ["Rell"] = function(args) local source = args.source -- 12.20
            args.rawMagical = args.rawMagical + 7.53 + 0.47 * source.level
            if not source:has_buff("RellWEmpoweredAttack") then return end
            local lvl = spellbook:get_spell_slot(SLOT_W).level
            args.rawMagical = args.rawMagical - 5 +
                15 * lvl + 0.4 * source.ability_power
        end,
        ["Rengar"] = function(args) local source = args.source -- 12.20
            local lvl = spellbook:get_spell_slot(SLOT_Q).level
            if source:has_buff("RengarQ") then
                args.rawPhysical = args.rawPhysical + 30 * lvl +
                    (-0.05 + 0.05 * lvl) * source.total_attack_damage
            elseif source:has_buff("RengarQEmp") then
                local mod = ({30, 45, 60, 75, 90, 105,
                    120, 135, 145, 155, 165, 175, 185,
                    195, 205, 215, 225, 235})[source.level]
                args.rawPhysical = args.rawPhysical +
                    mod + 0.4 * source.total_attack_damage
            end
        end,
        ["Riven"] = function(args) local source = args.source -- 12.20
            if not source:has_buff("RivenPassiveAABoost") then return end
            args.rawPhysical = args.rawPhysical + (source.level >= 6 and 0.36 + 0.06 *
                math.floor((source.level - 6) / 3) or 0.3) * source.total_attack_damage
        end,
        ["Rumble"] = function(args) local source = args.source -- 12.20
            if not source:has_buff("RumbleOverheat") then return end
            args.rawMagical = args.rawMagical + 2.94 + 2.06 * source.level
                + 0.25 * source.ability_power + 0.06 * args.unit.max_health
        end,
        ["Sett"] = function(args) local source = args.source -- 12.20
            if not source:has_buff("SettQ") then return end
            local lvl = spellbook:get_spell_slot(SLOT_Q).level
            args.rawPhysical = args.rawPhysical +
                10 * lvl + (0.01 + (0.005 + 0.005 * lvl) * 0.01 *
                source.total_attack_damage) * args.unit.max_health
        end,
        ["Shaco"] = function(args) local source = args.source -- 12.20
            local turned = not Geometry:IsFacing(args.unit, source)
            if turned then args.rawPhysical = args.rawPhysical + 19.12 +
                0.88 * source.level + 0.15 * source.bonus_attack_damage end
            if not source:has_buff("Deceive") then return end
            local lvl = spellbook:get_spell_slot(SLOT_Q).level
            args.rawPhysical = args.rawPhysical + 15 +
                10 * lvl + 0.5 * source.bonus_attack_damage
            local mod = 0.3 + (source:has_item(3031) and 0.35 or 0)
            if turned then args.rawPhysical = args.rawPhysical
                + mod * source.total_attack_damage end
        end,
        -- Seraphine
        ["Shen"] = function(args) local source = args.source -- 12.20
            local lvl = spellbook:get_spell_slot(SLOT_Q).level
            if source:has_buff("shenqbuffweak") then
                args.rawMagical = args.rawMagical + 4 + 6 * math.ceil(
                    source.level / 3) + (0.015 + 0.005 * lvl + 0.015 *
                    source.ability_power / 100) * args.unit.max_health
            elseif source:has_buff("shenqbuffstrong") then
                args.rawMagical = args.rawMagical + 4 + 6 * math.ceil(
                    source.level / 3) + (0.035 + 0.005 * lvl + 0.02 *
                    source.ability_power / 100) * args.unit.max_health
            end
        end,
        ["Shyvana"] = function(args) local source = args.source -- 12.20
            local lvl = spellbook:get_spell_slot(SLOT_E).level
            if source:has_buff("ShyvanaDoubleAttack") then
                args.rawPhysical = args.rawPhysical + (0.05 + 0.15 * lvl) *
                    source.total_attack_damage + 0.25 * source.ability_power
            end
            if args.unit:has_buff("ShyvanaFireballMissile") then
                args.rawMagical = args.rawMagical + 0.035 * args.unit.max_health
            end
        end,
        ["Skarner"] = function(args) local source = args.source -- 12.20
            if not source:has_buff("skarnerpassivebuff") then return end
            local lvl = spellbook:get_spell_slot(SLOT_E).level
            args.rawPhysical = args.rawPhysical + 10 + 20 * lvl
        end,
        ["Sona"] = function(args) local source = args.source -- 12.20
            if source:has_buff("SonaQProcAttacker") then
                local lvl = spellbook:get_spell_slot(SLOT_Q).level
                args.rawMagical = args.rawMagical + 5 +
                    5 * lvl + 0.2 * source.ability_power
            end -- SonaPassiveReady
        end,
        ["Sylas"] = function(args) local source = args.source -- 12.20
            if not source:has_buff("SylasPassiveAttack") then return end
            args.rawMagical, args.rawPhysical = source.ability_power
                * 0.25 + source.total_attack_damage * 1.3, 0
        end,
        ["TahmKench"] = function(args) local source = args.source -- 12.20
            args.rawMagical = args.rawMagical + 4.94 + 3.06 * source.level
                + 0.03 * (source.max_health - (640 + 109 * source.level))
        end,
        ["Taric"] = function(args) local source = args.source -- 12.20
            if not source:has_buff("taricgemcraftbuff") then return end
            args.rawMagical = args.rawMagical + 21 + 4 *
                source.level + 0.15 * source.bonus_armor
        end,
        ["Teemo"] = function(args) local source = args.source -- 12.20
            local lvl = spellbook:get_spell_slot(SLOT_E).level
            if lvl == 0 then return end
            args.rawMagical = args.rawMagical + 3 +
                11 * lvl + 0.3 * source.ability_power
        end,
        ["Trundle"] = function(args) local source = args.source -- 12.20
            if not source:has_buff("TrundleTrollSmash") then return end
            local lvl = spellbook:get_spell_slot(SLOT_Q).level
            args.rawPhysical = args.rawPhysical + 20 * lvl +
                (0.05 + 0.1 * lvl) * source.total_attack_damage
        end,
        ["TwistedFate"] = function(args) local source = args.source -- 12.20
            local lvl = spellbook:get_spell_slot(SLOT_W).level
            if source:has_buff("BlueCardPreAttack") then
                args.rawMagical = args.rawMagical + 20 + 20 * lvl +
                    source.total_attack_damage + 0.9 * source.ability_power
            elseif source:has_buff("RedCardPreAttack") then
                args.rawMagical = args.rawMagical + 15 + 15 * lvl +
                    source.total_attack_damage + 0.6 * source.ability_power
            elseif source:has_buff("GoldCardPreAttack") then
                args.rawMagical = args.rawMagical + 7.5 + 7.5 * lvl +
                    source.total_attack_damage + 0.5 * source.ability_power
            end
            if args.rawMagical > 0 then args.rawPhysical = 0 end
            if source:has_buff("cardmasterstackparticle") then
                local lvl = spellbook:get_spell_slot(SLOT_E).level
                args.rawMagical = args.rawMagical + 40 +
                    25 * lvl + 0.5 * source.ability_power
            end
        end,
        ["Varus"] = function(args) local source = args.source -- 12.20
            local lvl = spellbook:get_spell_slot(SLOT_W).level
            if lvl > 0 then args.rawMagical = args.rawMagical +
                2 + 5 * lvl + 0.3 * source.ability_power end
        end,
        ["Vayne"] = function(args) local source = args.source -- 12.20
            if source:has_buff("vaynetumblebonus") then
                local lvl = spellbook:get_spell_slot(SLOT_Q).level
                local mod = (1.55 + 0.05 * lvl) * source.bonus_attack_damage
                args.rawPhysical = args.rawPhysical + mod
            end
            local buff = args.unit:get_buff("VayneSilveredDebuff")
            if not buff or buff.count ~= 2 then return end
            local lvl = spellbook:get_spell_slot(SLOT_W).level
            args.trueDamage = args.trueDamage + math.max((0.02 +
                0.02 * lvl) * args.unit.max_health, 35 + 15 * lvl)
        end,
        -- Vex
        ["Vi"] = function(args) local source = args.source -- 12.20
            if source:has_buff("ViE") then
                local lvl = spellbook:get_spell_slot(SLOT_E).level
                --[[ args.rawPhysical = 20 * lvl - 10 + source.ability_power
                    * 0.9 + 1.1 * source.total_attack_damage --]]
            end
            local buff = args.unit:get_buff("viwproc")
            if not buff or buff.count ~= 2 then return end
            local lvl = spellbook:get_spell_slot(SLOT_W).level
            args.rawPhysical = args.rawPhysical + (0.025 + 0.015 * lvl + 0.01
                * source.bonus_attack_damage / 35) * args.unit.max_health
        end,
        ["Viego"] = function(args) local source = args.source
            --[[ local lvl = spellbook:get_spell_slot(SLOT_Q).level
            if lvl > 0 then args.rawPhysical = args.rawPhysical + math.max(
                5 + 5 * lvl, (0.01 + 0.01 * lvl) * args.unit.health) end --]]
        end,
        ["Viktor"] = function(args) local source = args.source -- 12.20
            if not source:has_buff("ViktorPowerTransferReturn") then return end
            local lvl = spellbook:get_spell_slot(SLOT_Q).level
            args.rawMagical, args.rawPhysical = args.rawMagical - 5 + 25 * lvl
                + source.total_attack_damage + 0.6 * source.ability_power, 0
        end,
        ["Volibear"] = function(args) local source = args.source -- 12.20
            if not source:has_buff("volibearpapplicator") then return end
            local mod = ({11, 12, 13, 15, 17, 19, 22, 25,
                28, 31, 34, 37, 40, 44, 48, 52, 56, 60})[source.level]
            args.rawMagical = args.rawMagical + mod + 0.4 * source.ability_power
        end,
        ["Warwick"] = function(args) local source = args.source -- 12.20
            args.rawMagical = args.rawMagical + 10 + 2 * source.level + 0.15
                * source.bonus_attack_damage + 0.1 * source.ability_power
        end,
        ["MonkeyKing"] = function(args) local source = args.source -- 12.20
            if not source:has_buff("MonkeyKingDoubleAttack") then return end
            local lvl = spellbook:get_spell_slot(SLOT_Q).level
            args.rawPhysical = args.rawPhysical - 5 +
                25 * lvl + 0.45 * source.bonus_attack_damage
        end,
        ["XinZhao"] = function(args) local source = args.source -- 12.20
            if not source:has_buff("XinZhaoQ") then return end
            local lvl = spellbook:get_spell_slot(SLOT_Q).level
            args.rawPhysical = args.rawPhysical + 7 +
                9 * lvl + 0.4 * source.bonus_attack_damage
        end,
        -- Yone
        ["Yorick"] = function(args) local source = args.source -- 12.20
            if not source:has_buff("yorickqbuff") then return end
            local lvl = spellbook:get_spell_slot(SLOT_Q).level
            args.rawPhysical = args.rawPhysical + 5 +
                25 * lvl + 0.4 * source.total_attack_damage
        end,
        ["Zed"] = function(args) local source = args.source -- 12.20
            local level, maxHealth = source.level, args.unit.max_health
            if args.unit.health / maxHealth >= 0.5 then return end
            args.rawMagical = args.rawMagical + (level < 7 and
                0.06 or level < 17 and 0.08 or 0.1) * maxHealth
        end,
        ["Zeri"] = function(args) local source = args.source -- 12.20
            if not spellbook:can_cast(SLOT_Q) then return end
            local lvl = spellbook:get_spell_slot(SLOT_Q).level
            args.rawPhysical = 5 + 3 * lvl + (0.995 +
                0.05 * lvl) * myHero.total_attack_damage
        end,
        ["Ziggs"] = function(args) local source = args.source -- 12.20
            if not source:has_buff("ZiggsShortFuse") then return end
            local mod = ({20, 24, 28, 32, 36, 40, 48, 56, 64,
                72, 80, 88, 100, 112, 124, 136, 148, 160})[source.level]
            args.rawMagical = args.rawMagical + mod + 0.5 * source.ability_power
        end,
        ["Zoe"] = function(args) local source = args.source -- 12.20
            if not source:has_buff("zoepassivesheenbuff") then return end
            local mod = ({16, 20, 24, 28, 32, 36, 42, 48, 54,
                60, 66, 74, 82, 90, 100, 110, 120, 130})[source.level]
            args.rawMagical = args.rawMagical + mod + 0.2 * source.ability_power
        end
    }
    self.itemPassives = {
        [3504] = function(args) local source = args.source -- Ardent Censer - 12.20
            if not source:has_buff("3504Buff") then return end
            args.rawMagical = args.rawMagical + 4.12 + 0.88 * args.unit.level
        end,
        [3153] = function(args) local source = args.source -- Blade of the Ruined King - 12.20
            local mod = source.is_melee and 0.12 or 0.08
            args.rawPhysical = args.rawPhysical + math.min(
                60, math.max(15, mod * args.unit.health))
        end,
        [3742] = function(args) local source = args.source -- Dead Man's Plate - 12.20
            local stacks = math.min(100, source:get_item(3742).count2)
            args.rawPhysical = args.rawPhysical + 0.4 * stacks
                + 0.01 * stacks * source.base_attack_damage
        end,
        [6632] = function(args) local source = args.source -- Divine Sunderer - 12.20
            if not source:has_buff("6632buff") then return end
            args.rawPhysical = args.rawPhysical + 1.25 *
                source.base_attack_damage + (source.is_melee
                and 0.06 or 0.03) * args.unit.max_health
        end,
        [1056] = function(args) -- Doran's Ring - 12.20
            args.rawPhysical = args.rawPhysical + 5
        end,
        [1054] = function(args) -- Doran's Shield - 12.20
            args.rawPhysical = args.rawPhysical + 5
        end,
        [3508] = function(args) local source = args.source -- Essence Reaver - 12.20
            if not source:has_buff("3508buff") then return end
            args.rawPhysical = args.rawPhysical + 0.4 *
                source.bonus_attack_damage + source.base_attack_damage
        end,
        [3124] = function(args) local source = args.source -- Guinsoo's Rageblade - 12.20
            args.rawPhysical = args.rawPhysical +
                math.min(200, source.crit_chance * 200)
        end,
        [2015] = function(args) local source = args.source -- Kircheis Shard - 12.20
            local buff = source:get_buff("itemstatikshankcharge")
            local damage = buff and buff.stacks2 == 100 and 80 or 0
            args.rawMagical = args.rawMagical + damage
        end,
        [6672] = function(args) local source = args.source -- Kraken Slayer - 12.20
            local buff = source:get_buff("6672buff")
            if not buff or buff.stacks2 ~= 2 then return end
            args.trueDamage = args.trueDamage + 50 +
                0.4 * source.bonus_attack_damage
        end,
        [3100] = function(args) local source = args.source -- Lich Bane - 12.20
            if not source:has_buff("lichbane") then return end
            args.rawMagical = args.rawMagical + 0.75 *
                source.base_attack_damage + 0.5 * source.ability_power
        end,
        [3004] = function(args) -- Manamune - 12.20
            args.rawPhysical = args.rawPhysical
                + args.source.max_mana * 0.025
        end,
        [3042] = function(args) -- Muramana - 12.20
            args.rawPhysical = args.rawPhysical
                + args.source.max_mana * 0.025
        end,
        [3115] = function(args) -- Nashor's Tooth - 12.20
            args.rawMagical = args.rawMagical + 15
                + 0.2 * args.source.ability_power
        end,
        [6670] = function(args) -- Noonquiver - 12.20
            args.rawPhysical = args.rawPhysical + 20
        end,
        [6677] = function(args) local source = args.source -- Rageknife - 12.20
            args.rawPhysical = args.rawPhysical +
                math.min(175, 175 * source.crit_chance)
        end,
        [3094] = function(args) local source = args.source -- Rapid Firecannon - 12.20
            local buff = source:get_buff("itemstatikshankcharge")
            local damage = buff and buff.stacks2 == 100 and 120 or 0
            args.rawMagical = args.rawMagical + damage
        end,
        [1043] = function(args) -- Recurve Bow - 12.20
            args.rawPhysical = args.rawPhysical + 15
        end,
        [3057] = function(args) local source = args.source -- Sheen - 12.20
            if not source:has_buff("sheen") then return end
            args.rawPhysical = args.rawPhysical + source.base_attack_damage
        end,
        [3095] = function(args) local source = args.source -- Stormrazor - 12.20
            local buff = source:get_buff("itemstatikshankcharge")
            local damage = buff and buff.stacks2 == 100 and 120 or 0
            args.rawMagical = args.rawMagical + damage
        end,
        [3070] = function(args) -- Tear of the Goddess - 12.20
            args.rawPhysical = args.rawPhysical + 5
        end,
        [3748] = function(args) local source = args.source -- Titanic Hydra - 12.20
            local mod = args.source.is_melee and {4, 0.015} or {3, 0.01125}
            local damage = mod[1] + mod[2] * args.source.max_health
            args.rawPhysical = args.rawPhysical + damage
        end,
        [3078] = function(args) local source = args.source -- Trinity Force - 12.20
            if not source:has_buff("3078trinityforce") then return end
            args.rawPhysical = args.rawPhysical + 2 * source.base_attack_damage
        end,
        [6664] = function(args) local source = args.source -- Turbo Chemtank - 12.20
            local buff = source:get_buff("item6664counter")
            if not buff or buff.stacks2 ~= 100 then return end
            local damage = 35.29 + 4.71 * source.level + 0.01 *
                source.max_health + 0.03 * source.move_speed
            args.rawMagical = args.rawMagical + damage * 1.3
        end,
        [3091] = function(args) local source = args.source -- Wit's End - 12.20
            local damage = ({15, 15, 15, 15, 15, 15, 15, 15, 25, 35,
                45, 55, 65, 75, 76.25, 77.5, 78.75, 80})[source.level]
            args.rawMagical = args.rawMagical + damage
        end
    }
end

function Damage:CalcAutoAttackDamage(source, target)
    local name = source.champ_name
    local physical = source.total_attack_damage
    if name == "Corki" and physical > 0 then return
        self:CalcMixedDamage(source, target, physical) end
    local args = {rawMagical = 0, rawPhysical = physical,
        trueDamage = 0, source = source, unit = target}
    local ids = Linq(source.items):Where("(i) => i ~= nil")
        :Select("(i) => i.item_id"):Distinct():ForEach(function(i)
        if self.itemPassives[i] then self.itemPassives[i](args) end end)
    if self.heroPassives[name] then self.heroPassives[name](args) end
    local magical = self:CalcMagicalDamage(source, target, args.rawMagical)
    local physical = self:CalcPhysicalDamage(source, target, args.rawPhysical)
    return magical + physical + args.trueDamage
end

function Damage:CalcEffectiveDamage(source, target, amount)
    return source.ability_power > source.total_attack_damage
        and self:CalcMagicalDamage(source, target, amount)
        or self:CalcPhysicalDamage(source, target, amount)
end

function Damage:CalcMagicalDamage(source, target, amount)
    local amount = amount or source.ability_power
    local magicRes = target.mr
    if magicRes < 0 then
        local mod = 2 - 100 / (100 - magicRes)
        return math.floor(amount * mod)
    end
    local magicPen = source.percent_magic_penetration
    local flatPen = source.flat_magic_penetration
    local res = magicRes * magicPen - flatPen
    local mod = res < 0 and 1 or 100 / (100 + res)
    return math.floor(amount * mod)
end

function Damage:CalcMixedDamage(source, target, amount)
    return self:CalcMagicalDamage(source, target, amount * 0.8)
        + self:CalcPhysicalDamage(source, target, amount * 0.2)
end

function Damage:CalcPhysicalDamage(source, target, amount)
    local amount = amount or source.total_attack_damage
    local kalista = source.champ_name == "Kalista"
    if kalista then amount = amount * 0.9 end
    local armor = target.armor
    if armor < 0 then
        local mod = 2 - 100 / (100 - armor)
        return math.floor(amount * mod)
    end
    local bonusArmor = target.bonus_armor
    local armorPen = source.percent_armor_penetration
    local bonusPen = source.percent_bonus_armor_penetration
    local lethality = source.lethality * (0.6 + 0.4 * source.level / 18)
    local res = armor * armorPen - (bonusArmor * (1 - bonusPen)) - lethality
    local reduction = target.flat_damage_reduction_from_barracks_minion_mod
    if not target.is_minion then reduction = 0 end
    local mod = res < 0 and 1 or 100 / (100 + res)
    return math.floor(amount * mod - reduction)
end

----------------
-- Data class --

local Data = Class()

function Data:__init()
    self.hybridRange = {"Elise", "Gnar", "Jayce", "Kayle", "Nidalee", "Zeri"}
    self.lethalTempoBuff = "ASSETS/Perks/Styles/Precision/LethalTempo/LethalTempoEmpowered.lua"
    self.lethalTempoCooldown = "ASSETS/Perks/Styles/Precision/LethalTempo/LethalTempoCooldown.lua"
    self.baseAttackSpeeds = {
        ["Aatrox"] = 0.651, ["Ahri"] = 0.668, ["Akali"] = 0.625, ["Akshan"] = 0.638, ["Alistar"] = 0.625,
        ["Amumu"] = 0.736, ["Anivia"] = 0.625, ["Annie"] = 0.579, ["Aphelios"] = 0.64, ["Ashe"] = 0.658,
        ["AurelionSol"] = 0.625, ["Azir"] = 0.625, ["Bard"] = 0.625, ["Belveth"] = 0.85, ["Blitzcrank"] = 0.65,
        ["Brand"] = 0.625, ["Braum"] = 0.644, ["Caitlyn"] = 0.681, ["Camille"] = 0.644, ["Cassiopeia"] = 0.647,
        ["Chogath"] = 0.625, ["Corki"] = 0.638, ["Darius"] = 0.625, ["Diana"] = 0.625, ["DrMundo"] = 0.72,
        ["Draven"] = 0.679, ["Ekko"] = 0.688, ["Elise"] = 0.625, ["Evelynn"] = 0.667, ["Ezreal"] = 0.625,
        ["FiddleSticks"] = 0.625, ["Fiora"] = 0.69, ["Fizz"] = 0.658, ["Galio"] = 0.625, ["Gangplank"] = 0.658,
        ["Garen"] = 0.625, ["Gnar"] = 0.625, ["Gragas"] = 0.675, ["Graves"] = 0.475, ["Gwen"] = 0.69,
        ["Hecarim"] = 0.67, ["Heimerdinger"] = 0.625, ["Illaoi"] = 0.625, ["Irelia"] = 0.656, ["Ivern"] = 0.644,
        ["Janna"] = 0.625, ["JarvanIV"] = 0.658, ["Jax"] = 0.638, ["Jayce"] = 0.658, ["Jhin"] = 0.625,
        ["Jinx"] = 0.625, ["Kaisa"] = 0.644, ["Kalista"] = 0.694, ["Karma"] = 0.625, ["Karthus"] = 0.625,
        ["Kassadin"] = 0.64, ["Katarina"] = 0.658, ["Kayle"] = 0.625, ["Kayn"] = 0.669, ["Kennen"] = 0.625,
        ["Khazix"] = 0.668, ["Kindred"] = 0.625, ["Kled"] = 0.625, ["KogMaw"] = 0.665, ["Leblanc"] = 0.625,
        ["LeeSin"] = 0.651, ["Leona"] = 0.625, ["Lillia"] = 0.625, ["Lissandra"] = 0.656, ["Lucian"] = 0.638,
        ["Lulu"] = 0.625, ["Lux"] = 0.669, ["Malphite"] = 0.736, ["Malzahar"] = 0.625, ["Maokai"] = 0.8,
        ["MasterYi"] = 0.679, ["MissFortune"] = 0.656, ["MonkeyKing"] = 0.69, ["Mordekaiser"] = 0.625,
        ["Morgana"] = 0.625, ["Nami"] = 0.644, ["Nasus"] = 0.638, ["Nautilus"] = 0.706, ["Neeko"] = 0.625,
        ["Nidalee"] = 0.638, ["Nilah"] = 0.697, ["Nocturne"] = 0.721, ["Nunu"] = 0.625, ["Olaf"] = 0.694,
        ["Orianna"] = 0.658, ["Ornn"] = 0.625, ["Pantheon"] = 0.644, ["Poppy"] = 0.625, ["Pyke"] = 0.667,
        ["Qiyana"] = 0.688, ["Quinn"] = 0.668, ["Rakan"] = 0.635, ["Rammus"] = 0.656, ["RekSai"] = 0.667,
        ["Rell"] = 0.55, ["Renata"] = 0.625, ["Renekton"] = 0.665, ["Rengar"] = 0.667, ["Riven"] = 0.625,
        ["Rumble"] = 0.644, ["Ryze"] = 0.625, ["Samira"] = 0.658, ["Sejuani"] = 0.688, ["Senna"] = 0.625,
        ["Seraphine"] = 0.669, ["Sett"] = 0.625, ["Shaco"] = 0.694, ["Shen"] = 0.751, ["Shyvana"] = 0.658,
        ["Singed"] = 0.613, ["Sion"] = 0.679, ["Sivir"] = 0.625, ["Skarner"] = 0.625, ["Sona"] = 0.644,
        ["Soraka"] = 0.625, ["Swain"] = 0.625, ["Sylas"] = 0.645, ["Syndra"] = 0.625, ["TahmKench"] = 0.658,
        ["Taliyah"] = 0.625, ["Talon"] = 0.625, ["Taric"] = 0.625, ["Teemo"] = 0.69, ["Thresh"] = 0.625,
        ["Tristana"] = 0.656, ["Trundle"] = 0.67, ["Tryndamere"] = 0.67, ["TwistedFate"] = 0.651,
        ["Twitch"] = 0.679, ["Udyr"] = 0.65, ["Urgot"] = 0.625, ["Varus"] = 0.658, ["Vayne"] = 0.658,
        ["Veigar"] = 0.625, ["Velkoz"] = 0.625, ["Vex"] = 0.669, ["Vi"] = 0.644, ["Viego"] = 0.658,
        ["Viktor"] = 0.658, ["Vladimir"] = 0.658, ["Volibear"] = 0.625, ["Warwick"] = 0.638,
        ["Xayah"] = 0.625, ["Xerath"] = 0.625, ["Xinzhao"] = 0.645, ["Yasuo"] = 0.697, ["Yone"] = 0.625,
        ["Yorick"] = 0.625, ["Yuumi"] = 0.625, ["Zac"] = 0.736, ["Zed"] = 0.651, ["Zeri"] = 0.658,
        ["Ziggs"] = 0.656, ["Zilean"] = 0.625, ["Zoe"] = 0.625, ["Zyra"] = 0.625
    }    
    self.blockAttackBuffs = {
        ["Akshan"] = {"AkshanR"}, ["Darius"] = {"dariusqcast"}, ["Galio"] = {"GalioW"},
        ["Garen"] = {"GarenE"}, ["Gragas"] = {"gragaswself"}, ["Jhin"] = {"JhinPassiveReload"},
        ["Kaisa"] = {"KaisaE"}, ["Kennen"] = {"KennenLightningRush"}, ["KogMaw"] = {"KogMawIcathianSurprise"},
        ["Lillia"] = {"LilliaQ"}, ["Lucian"] = {"LucianR"}, ["Pyke"] = {"PykeQ"}, ["Samira"] = {"samirarreadybuff"},
        ["Sion"] = {"SionR"}, ["Urgot"] = {"UrgotW"}, ["Varus"] = {"VarusQ"}, ["Vi"] = {"ViQ"},
        ["Vladimir"] = {"VladimirSanguinePool", "VladimirE"}, ["Xerath"] = {"XerathArcanopulseChargeUp"}
    }
    self.blockOrbBuffs = {
        ["AurelionSol"] = {"AurelionSolQ"}, ["Caitlyn"] = {"CaitlynAceintheHole"},
        ["FiddleSticks"] = {"Drain", "Crowstorm"}, ["Galio"] = {"GalioR"},
        ["Gwen"] = {"gwenz_lockfacing"}, ["Irelia"] = {"ireliawdefense"}, ["Janna"] = {"ReapTheWhirlwind"},
        ["Karthus"] = {"KarthusDeathDefiedBuff", "karthusfallenonecastsound"}, ["Katarina"] = {"katarinarsound"},
        ["Malzahar"] = {"MalzaharRSound"}, ["MasterYi"] = {"Meditate"}, ["MissFortune"] = {"missfortunebulletsound"},
        ["Pantheon"] = {"PantheonRJump"}, ["Shen"] = {"shenstandunitedlock"}, ["Sion"] = {"SionQ"},
        ["Taliyah"] = {"TaliyahR"}, ["TwistedFate"] = {"Gate"}, ["Velkoz"] = {"VelkozR"},
        ["Warwick"] = {"WarwickRSound"}, ["Xerath"] = {"XerathLocusOfPower2"}, ["Zac"] = {"ZacE"}
    }
    self.buffStackNames = {
        ["Akshan"] = "AkshanPassiveDebuff", ["Braum"] = "BraumMark", ["Darius"] = "DariusHemo",
        ["Ekko"] = "ekkostacks", ["Gnar"] = "gnarwproc", ["Kaisa"] = "kaisapassivemarker",
        ["Kalista"] = "KalistaExpungeMarker", ["Kennen"] = "kennenmarkofstorm",
        ["Kindred"] = "kindredecharge", ["Tristana"] = "tristanaechargesound",
        ["Twitch"] = "TwitchDeadlyVenom", ["Vayne"] = "VayneSilveredDebuff", ["Vi"] = "viwproc",
    }
    self.monsterNames = {
        ["SRU_Baron"] = true, ["SRU_Blue"] = true, ["Sru_Crab"] = true, ["SRU_Dragon_Air"] = true,
        ["SRU_Dragon_Chemtech"] = true, ["SRU_Dragon_Earth"] = true, ["SRU_Dragon_Elder"] = true,
        ["SRU_Dragon_Fire"] = true, ["SRU_Dragon_Hextech"] = true, ["SRU_Dragon_Water"] = true,
        ["SRU_Gromp"] = true, ["SRU_Krug"] = true, ["SRU_KrugMini"] = true,
        ["SRU_KrugMiniMini"] = true, ["SRU_Murkwolf"] = true, ["SRU_MurkwolfMini"] = true,
        ["SRU_Plant_Vision"] = true, ["SRU_Razorbeak"] = true, ["SRU_RazorbeakMini"] = true,
        ["SRU_Red"] = true, ["SRU_RiftHerald"] = true
    }
    self.petNames = {
        ["AniviaEgg"] = true, ["AnnieTibbers"] = true, ["ApheliosTurret"] = true,
        ["BlueTrinket"] = true, ["EliseSpiderling"] = true, ["GangplankBarrel"] = true,
        ["HeimerTBlue"] = true, ["HeimerTYellow"] = true, ["IllaoiMinion"] = true,
        ["IvernMinion"] = true, ["JammerDevice"] = true, ["JhinTrap"] = true,
        ["KalistaSpawn"] = true, ["MalzaharVoidling"] = true, ["NidaleeSpear"] = true,
        ["SennaSoul"] = true, ["ShacoBox"] = true, ["SightWard"] = true,
        ["TeemoMushroom"] = true, ["VoidGate"] = true, ["VoidSpawn"] = true,
        ["YellowTrinket"] = true, ["YorickBigGhoul"] = true, ["YorickGhoulMelee"] = true,
        ["YorickWGhoul"] = true, ["YorickWInvisible"] = true, ["ZacRebirthBloblet"] = true,
        ["ZyraGraspingPlant"] = true, ["ZyraThornPlant"] = true
    }
    self.resetAttackNames = {
        ["AatroxE"] = true, ["AkshanBasicAttack"] = true, ["AkshanCritAttack"] = true,
        ["AsheQ"] = true, ["BelvethQ"] = true, ["PowerFist"] = true, ["CamilleQ"] = true,
        ["CamilleQ2"] = true, ["VorpalSpikes"] = true, ["DariusNoxianTacticsONH"] = true,
        ["DrMundoE"] = true, ["EkkoE"] = true, ["EliseSpiderW"] = true, ["FioraE"] = true,
        ["FizzW"] = true, ["GarenQ"] = true, ["GravesMove"] = true,
        ["GravesAutoAttackRecoilCastEDummy"] = true, ["GwenE"] = true, ["HecarimRamp"] = true,
        ["IllaoiW"] = true, ["JaxEmpowerTwo"] = true, ["JayceHyperCharge"] = true,
        ["KaisaR"] = true, ["NetherBlade"] = true, ["KatarinaEWrapper"] = true,
        ["KayleE"] = true, ["KindredQ"] = true, ["LeonaShieldOfDaybreak"] = true,
        ["LucianE"] = true, ["Obduracy"] = true, ["Meditate"] = true, ["NasusQ"] = true,
        ["NautilusPiercingGaze"] = true, ["NilahE"] = true, ["Takedown"] = true,
        ["RekSaiQ"] = true, ["RenektonPreExecute"] = true, ["RengarQ"] = true,
        ["RengarQEmp"] = true, ["RivenTriCleave"] = true, ["SejuaniE"] = true, ["SettQ"] = true,
        ["ShyvanaDoubleAttack"] = true, ["SivirW"] = true, ["SonaQPassiveAttack"] = true,
        ["SonaWPassiveAttack"] = true, ["SonaEPassiveAttack"] = true, ["TalonQ"] = true,
        ["VayneTumble"] = true, ["TrundleTrollSmash"] = true, ["ViE"] = true,
        ["ViegoW"] = true, ["VolibearQ"] = true, ["MonkeyKingDoubleAttack"] = true,
        ["XinZhaoQ"] = true, ["YorickQ"] = true, ["ZacQ"] = true, ["ZeriE"] = true
    }
    self.apheliosProjectileSpeeds = Linq({
        [1] = {buff = "ApheliosCalibrumManager", speed = 2500},
        [2] = {buff = "ApheliosCrescendumManager", speed = 5000},
        [3] = {buff = "ApheliosInfernumManager", speed = 1500},
        [4] = {buff = "ApheliosGravitumManager", speed = 1500},
        [5] = {buff = "ApheliosSeverumManager", speed = math.huge}
    })
    self.specialProjectileSpeeds = {
        ["Viktor"] = {buff = "ViktorPowerTransferReturn", speed = math.huge},
        ["Zoe"] = {buff = "zoepassivesheenbuff", speed = math.huge},
        ["Caitlyn"] = {buff = "caitlynpassivedriver", speed = 3000},
        ["Jhin"] = {buff = "jhinpassiveattackbuff", speed = 3000},
        ["Jinx"] = {buff = "JinxQ", speed = 2000},
        ["Kayle"] = {buff = "KayleE", speed = 1750},
        ["Neeko"] = {buff = "neekowpassiveready", speed = 3500},
        ["Poppy"] = {buff = "poppypassivebuff", speed = 1600}
    }
    self.undyingBuffs = {
        ["aatroxpassivedeath"] = true, ["FioraW"] = true,
        ["JaxCounterStrike"] = true, ["JudicatorIntervention"] = true,
        ["KarthusDeathDefiedBuff"] = true, ["kindredrnodeathbuff"] = false,
        ["KogMawIcathianSurprise"] = true, ["SamiraW"] = true, ["ShenWBuff"] = true,
        ["TaricR"] = true, ["UndyingRage"] = false, ["VladimirSanguinePool"] = true,
        ["ChronoShift"] = false, ["chronorevive"] = true, ["zhonyasringshield"] = true
    }
end

function Data:CanAttack()
    local name = myHero.champ_name
    local buffs = self.blockAttackBuffs[name]
    if not buffs then return true end
    if myHero:has_buff("gragaswattackbuff") and
        name == "Gragas" then return true end
    return not Linq(buffs):Any(function(b)
        return myHero:has_buff(b) end)
end

function Data:CanOrbwalk()
    if myHero.is_dead then return false end
    local name = myHero.champ_name
    local buffs = self.blockOrbBuffs[name]
    if not buffs then return true end
    return not Linq(buffs):Any(function(b)
        return myHero:has_buff(b) end)
end

function Data:GetAutoAttackRange(unit)
    local unit = unit or myHero
    return unit.attack_range + unit.bounding_radius
end

function Data:GetProjectileSpeed()
    local ranged = not self:IsMelee(myHero)
    local name = myHero.champ_name
    if name == "Aphelios" then
        local data = self.apheliosProjectileSpeeds:First(
            function(a) return myHero:has_buff(a.buff) end)
        if data ~= nil then return data.speed end
    elseif name == "Azir" or name == "Senna" or
        name == "Thresh" or name == "Velkoz" or
        name:find("Melee") then return math.huge
    elseif name == "Kayle" then
        local data = spellbook:get_spell_slot(SLOT_R)
        if data and data.level > 0 then return 5000 end
    elseif name == "Jayce" and ranged then return 2000
    elseif name == "Seraphine" then return 1800
    elseif name == "Zeri" and ranged == true and
        spellbook:can_cast(SLOT_Q) then return 2600 end
    local data = self.specialProjectileSpeeds[name]
    local buff = data and myHero:has_buff(data.buff)
    if buff then return data.speed end
    local data = myHero:get_basic_attack_data()
    local speed = data.missile_speed
    return ranged and speed ~= nil and
        speed > 0 and speed or math.huge
end

function Data:GetSpecialWindup()
    local name = myHero.champ_name
    if name ~= "Jayce" and name ~=
        "TwistedFate" then return nil end
    return Linq(myHero.buffs):Any(function(b) return
        b.is_valid and b.duration > 0 and b.count > 0
        and (b.name == "JayceHyperCharge" or b.name
        :find("CardPreAttack")) end) and 0.125 or nil
end

function Data:IsImmortal(unit)
    return Linq(unit.buffs):Any(function(b)
        if not b.is_valid or b.duration <= 0 or
            b.count <= 0 then return false end
        local buff = self.undyingBuffs[b.name]
        if buff == nil then return false end
        return buff == false and unit.health /
            unit.max_health < 0.05 or buff == true
    end) or unit.is_immortal
end

function Data:IsMelee(unit)
    return unit.is_melee or unit.attack_range < 300
        and self.hybridRange[unit.champ_name] ~= nil
end

function Data:IsValid(unit)
    return unit and unit.is_valid and unit.is_visible
        and unit.is_alive and unit.is_targetable
end

function Data:Latency()
    return (game.ping / 1000) * 1.5 + 0.05
end

--------------------
-- Geometry class --

Geometry = Class()

function Geometry:__init() end

function Geometry:AngleBetween(p1, p2, p3)
    local angle = math.deg(
        math.atan(p3.z - p1.z, p3.x - p1.x) -
        math.atan(p2.z - p1.z, p2.x - p1.x))
    if angle < 0 then angle = angle + 360 end
    return angle > 180 and 360 - angle or angle
end

function Geometry:CircleToPolygon(center, radius, steps, offset)
    local result = {}
    for i = 0, steps - 1 do
        local phi = 2 * math.pi / steps * (i + 0.5)
        local cx = center.x + radius * math.cos(phi + offset)
        local cy = center.z + radius * math.sin(phi + offset)
        table.insert(result, vec3.new(cx, center.y, cy))
    end
    return result
end

function Geometry:DrawPolygon(polygon, color, width)
    local size, c, w = #polygon, color, width
    if size < 3 then return end
    for i = 1, size do
        local p1, p2 = polygon[i], polygon[i % size + 1]
        local a = game:world_to_screen_2(p1.x, p1.y, p1.z)
        local b = game:world_to_screen_2(p2.x, p2.y, p2.z)
        renderer:draw_line(a.x, a.y, b.x, b.y, w, c.r, c.g, c.b, c.a)
    end
end

function Geometry:Distance(p1, p2)
    return math.sqrt(self:DistanceSqr(p1, p2))
end

function Geometry:DistanceSqr(p1, p2)
    local dx, dy = p2.x - p1.x, p2.z - p1.z
    return dx * dx + dy * dy
end

function Geometry:IsFacing(source, unit)
    local dir = source.direction
    local p1, p2 = source.origin, unit.origin
    local p3 = {x = p1.x + dir.x * 2, z = p1.z + dir.z * 2}
    return self:AngleBetween(p1, p2, p3) < 80
end

function Geometry:IsInAutoAttackRange(unit, raw)
    local range = Data:GetAutoAttackRange()
    local hitbox = unit.bounding_radius
    if myHero.champ_name == "Aphelios"
        and unit.is_hero and unit:has_buff(
        "aphelioscalibrumbonusrangedebuff")
        then range, hitbox = 1800, 0
    elseif myHero.champ_name == "Caitlyn"
        and (unit:has_buff("caitlynwsight")
        or unit:has_buff("CaitlynEMissile"))
        then range = range + 650
    elseif self.b_zeri ~= nil and
        spellbook:can_cast(SLOT_Q) and
        menu:get_value(self.b_zeri) == 1
        then range, hitbox = 825, 0 end
    local ranged = not myHero.is_melee
    local p1 = myHero.path.server_pos
    local p2 = unit.path ~= nil and
        unit.path.server_pos or unit.origin
    if raw and ranged then hitbox = 0 end
    local dist = self:DistanceSqr(p1, p2)
    return dist <= (range + hitbox) ^ 2
end

--------------------------
-- Object Manager class --

local ObjectManager = Class()

function ObjectManager:__init() end

function ObjectManager:GetAllyHeroes(range)
    local pos = myHero.path.server_pos
    return Linq(game.players):Where(function(u)
        return Data:IsValid(u) and not u.is_enemy and
            u.object_id ~= myHero.object_id and range >=
            Geometry:Distance(pos, u.path.server_pos)
    end)
end

function ObjectManager:GetAllyMinions(range)
    local pos = myHero.path.server_pos
    return Linq(game.minions):Where(function(u)
        return Data:IsValid(u) and not u.is_enemy and
            Geometry:Distance(pos, u.origin) <= range
    end)
end

function ObjectManager:GetClosestAllyTurret()
    local turrets = Linq(game.turrets):Where(function(t)
        return Data:IsValid(t) and not t.is_enemy end)
    if #turrets == 0 then return nil end
    local pos = myHero.path.server_pos
    table.sort(turrets, function(a, b) return
        Geometry:DistanceSqr(pos, a.origin) <
        Geometry:DistanceSqr(pos, b.origin) end)
    return turrets[1]
end

function ObjectManager:GetEnemyHeroes(range)
    local pos = myHero.path.server_pos
    return Linq(game.players):Where(function(u)
        return Data:IsValid(u) and u.is_enemy
            and (range and Geometry:Distance(
            pos, u.path.server_pos) <= range
            or Geometry:IsInAutoAttackRange(u))
    end)
end

function ObjectManager:GetEnemyMinions()
    return Linq(game.minions):Where(function(u)
        return Data:IsValid(u) and u.is_enemy and
            Geometry:IsInAutoAttackRange(u, true)
    end)
end

function ObjectManager:GetEnemyMonsters()
    return Linq(game.jungle_minions):Where(function(u)
        return Data:IsValid(u) and u.is_enemy
            and Geometry:IsInAutoAttackRange(u)
    end)
end

function ObjectManager:GetEnemyPets()
    return Linq(game.pets):Where(function(u)
        return Data:IsValid(u) and u.is_enemy
            and Geometry:IsInAutoAttackRange(u)
    end)
end

function ObjectManager:GetEnemyStructure()
    return Linq(game.nexus):Concat(
        game.inhibs):First(function(t)
        return Data:IsValid(t) and t.is_enemy
            and Geometry:IsInAutoAttackRange(t)
    end)
end

function ObjectManager:GetEnemyTurret()
    return Linq(game.turrets):First(function(t)
        return Data:IsValid(t) and t.is_enemy
            and Geometry:IsInAutoAttackRange(t)
    end)
end

function ObjectManager:GetEnemyWard()
    return Linq(game.wards):First(function(w)
        return Data:IsValid(w) and w.is_enemy
            and Geometry:IsInAutoAttackRange(w)
    end)
end

----------------------
-- Prediction class --

local Prediction = Class()

function Prediction:__init()
    self.update = 0
    self.attacks = Linq()
    self.threats = Linq()
    self.turretMinion = nil
    self.damage = Damage:New()
    self.geometry = Geometry:New()
    self.manager = ObjectManager:New()
    client:set_event_callback("on_tick",
        function(...) self:OnTick(...) end)
    client:set_event_callback("on_stop_cast",
        function(...) self:OnStopCast(...) end)
    client:set_event_callback("on_process_spell",
        function(...) self:OnProcessSpell(...) end)
end

function Prediction:GetDamage(source, target)
    if source.is_turret then
        local health = target.max_health
        local name = target.champ_name
        if name:find("Siege") then
            local percent = name:find("1") and 0.14
                or name:find("2") and 0.11 or 0.08
            return math.floor(health * percent)
        elseif name:find("Ranged") then
            return math.floor(health * 0.7)
        elseif name:find("Melee") then
            return math.floor(health * 0.45)
        elseif name:find("Super") then
            return math.floor(health * 0.05)
        end
    elseif source.is_minion then
        local damage = source.total_attack_damage
        local resistance = target.armor >= 0 and (100 / (100 +
            target.armor)) or (2 - 100 / (100 - target.armor))
        local bonus_mod = source.percent_damage_to_barracks_minion_mod
        local reduction = target.flat_damage_reduction_from_barracks_minion_mod
        return math.floor(damage * resistance * (1 + bonus_mod) - reduction)
    end
    return self.damage:CalcAutoAttackDamage(source, target)
end

function Prediction:GetHealthPrediction(unit, time, delay)
    if time <= 0 then return unit.health end
    local health, delay = unit.health, delay or 0
    for _, attack in ipairs(self.attacks) do
        if unit.object_id == attack.target.object_id
            and attack.processed == false then
            local landTime = delay + self.geometry:Distance(
                attack.source.origin, attack.target.origin) /
                attack.speed + attack.timer + attack.windup
            if landTime <= game.game_time + time then
                health = health - attack.damage
            end
        end
    end
    return health
end

function Prediction:GetLaneClearHealthPrediction(unit, time, active)
    if time <= 0 then return unit.health end
    if not active then self:UpdateThreats() end
    local health, threats = unit.health, not active and self.threats
    for _, attack in ipairs(self.attacks:Concat(threats or {})) do
        if game.game_time - attack.timer <= attack.animation + 0.1
            and unit.object_id == attack.target.object_id then
            local startTimer = attack.timer
            while startTimer <= game.game_time + time do
                local landTime = self.geometry:Distance(
                    attack.source.origin, attack.target.origin) /
                    attack.speed + startTimer + attack.windup
                if landTime <= game.game_time + time then
                    health = health - attack.damage end
                startTimer = startTimer + attack.animation
            end
        end
    end
    return health
end

function Prediction:UpdateThreats()
    -- collect future threats for lane clear prediction
    if self.update == game.game_time then return end
    local allies = self.manager:GetAllyMinions(1000)
    local enemies = self.manager:GetEnemyMinions()
    self.threats = allies:Where(function(unit)
        return not self.attacks:Any(function(attack) return
        unit.object_id == attack.source.object_id and game.game_time
        <= attack.timer + attack.animation end) end):SelectMany(
        function() return enemies end, function(ally, enemy)
        local speed = ally:get_basic_attack_data().missile_speed
        if ally.is_melee or speed == 0 then speed = math.huge end
        local windup, animation = ally.attack_cast_delay, ally.attack_delay
        local distance = self.geometry:Distance(ally.origin, enemy.origin)
        local delay = math.max((-ally.attack_range - ally.bounding_radius
            - enemy.bounding_radius + distance) / ally.move_speed, 0)
        return {source = ally, target = enemy, timer = game.game_time + delay,
            speed = speed, animation = animation, windup = windup,
            processed = false, damage = self:GetDamage(ally, enemy)}
    end) self.update = game.game_time
end

function Prediction:HasTurretAggro(unit)
    return self.attacks:Any(function(attack)
        local delay = attack.animation + 0.07
        return attack.source.is_turret == true and
        game.game_time - attack.timer <= delay and
        unit.object_id == attack.target.object_id end)
end

function Prediction:MaxAggroDamage(unit)
    return self.attacks:Where(function(attack) return
        unit.object_id == attack.target.object_id end)
        :Max(function(attack) return attack.damage end)
end

function Prediction:TotalAggroDamage(unit)
    return self.attacks:Where(function(attack) return
        not attack.processed and attack.damage > 0 and
        unit.object_id == attack.target.object_id end)
        :Select(function(attack) return attack.damage end)
        :Aggregate(function(res, dmg) return res + dmg end)
end

function Prediction:TurretAggroStartTime(turret)
    local attack = self.attacks:First(function(attack) return
        turret.object_id == attack.source.object_id end)
    return attack ~= nil and attack.timer or 0
end

function Prediction:OnTick()
    local timer = game.game_time
    -- clear obsolete attack data
    self.attacks:RemoveWhere(function(attack)
        return timer - attack.timer > 3 end)
    -- mark completed attacks as processed
    self.attacks:ForEach(function(attack)
        if attack.processed then return end
        local distance = self.geometry:Distance(
            attack.source.origin, attack.target.origin)
        if not attack.target.is_valid or attack.timer +
            distance / attack.speed + attack.windup <=
            timer then attack.processed = true end
    end)
end

function Prediction:OnStopCast(unit, args)
    if unit.is_enemy or not unit.is_minion
        or not args.stop_animation or not
        args.destroy_missile then return end
    local timer = game.game_time - 0.2
    self.attacks:RemoveWhere(function(attack) return
        unit.object_id == attack.source.object_id and
        timer - attack.timer <= attack.windup end)
end

function Prediction:OnProcessSpell(unit, args)
    if unit.object_id == myHero.object_id or not
        args.target or not args.target.is_valid
        or not args.is_autoattack or not
        args.target.is_minion or not
        args.target.is_enemy then return end
    if self.geometry:DistanceSqr(myHero.origin,
        unit.origin) > 2250000 then return end
    if self.attacks:Any(function(attack) return
        unit.object_id == attack.source.object_id
        and game.game_time - 0.2 - attack.timer
        <= attack.windup end) then return end
    local latency = game.ping / 2000
    local timer = args.cast_time - latency
    local data = unit:get_basic_attack_data()
    local delay = unit.attack_delay
    local target = args.target
    local turret = unit.is_turret
    local speed = data.missile_speed
    local windup = args.cast_delay
    local melee = unit.is_melee or speed == 0
    if melee == true then speed = math.huge end
    if turret then self.turretMinion = target end
    self.attacks[#self.attacks + 1] = {
        source = unit, target = target, timer =
        timer, speed = speed, processed = false,
        animation = delay - (turret and 0.07 or 0),
        windup = windup + (turret and 0.07 or 0),
        damage = self:GetDamage(unit, target)}
end

---------------------------
-- Target Selector class --

local TargetSelector = Class()

function TargetSelector:__init(data)
    self.data = data
    self.priorityList = {
        ["Aatrox"] = 3, ["Ahri"] = 4, ["Akali"] = 4, ["Akshan"] = 5, ["Alistar"] = 1,
        ["Amumu"] = 1, ["Anivia"] = 4, ["Annie"] = 4, ["Aphelios"] = 5, ["Ashe"] = 5,
        ["AurelionSol"] = 4, ["Azir"] = 4, ["Bard"] = 3, ["Belveth"] = 3, ["Blitzcrank"] = 1,
        ["Brand"] = 4, ["Braum"] = 1, ["Caitlyn"] = 5, ["Camille"] = 4, ["Cassiopeia"] = 4,
        ["Chogath"] = 1, ["Corki"] = 5, ["Darius"] = 2, ["Diana"] = 4, ["DrMundo"] = 1,
        ["Draven"] = 5, ["Ekko"] = 4, ["Elise"] = 3, ["Evelynn"] = 4, ["Ezreal"] = 5,
        ["FiddleSticks"] = 3, ["Fiora"] = 4, ["Fizz"] = 4, ["Galio"] = 1, ["Gangplank"] = 4,
        ["Garen"] = 1, ["Gnar"] = 1, ["Gragas"] = 2, ["Graves"] = 4, ["Gwen"] = 3,
        ["Hecarim"] = 2, ["Heimerdinger"] = 3, ["Illaoi"] = 3, ["Irelia"] = 3,
        ["Ivern"] = 1, ["Janna"] = 2, ["JarvanIV"] = 3, ["Jax"] = 3, ["Jayce"] = 4,
        ["Jhin"] = 5, ["Jinx"] = 5, ["Kaisa"] = 5, ["Kalista"] = 5, ["Karma"] = 4,
        ["Karthus"] = 4, ["Kassadin"] = 4, ["Katarina"] = 4, ["Kayle"] = 4, ["Kayn"] = 4,
        ["Kennen"] = 4, ["Khazix"] = 4, ["Kindred"] = 4, ["Kled"] = 2, ["KogMaw"] = 5,
        ["Leblanc"] = 4, ["LeeSin"] = 3, ["Leona"] = 1, ["Lillia"] = 4, ["Lissandra"] = 4,
        ["Lucian"] = 5, ["Lulu"] = 3, ["Lux"] = 4, ["Malphite"] = 1, ["Malzahar"] = 3,
        ["Maokai"] = 2, ["MasterYi"] = 5, ["MissFortune"] = 5, ["MonkeyKing"] = 3,
        ["Mordekaiser"] = 4, ["Morgana"] = 3, ["Nami"] = 3, ["Nasus"] = 2, ["Nautilus"] = 1,
        ["Neeko"] = 4, ["Nidalee"] = 4, ["Nilah"] = 5, ["Nocturne"] = 4, ["Nunu"] = 2,
        ["Olaf"] = 2, ["Orianna"] = 4, ["Ornn"] = 2, ["Pantheon"] = 3, ["Poppy"] = 2,
        ["Pyke"] = 4, ["Qiyana"] = 4, ["Quinn"] = 5, ["Rakan"] = 3, ["Rammus"] = 1,
        ["RekSai"] = 2, ["Rell"] = 5, ["Renata"] = 3, ["Renekton"] = 2, ["Rengar"] = 4,
        ["Riven"] = 4, ["Rumble"] = 4, ["Ryze"] = 4, ["Samira"] = 5, ["Sejuani"] = 2,
        ["Senna"] = 5, ["Seraphine"] = 4, ["Sett"] = 2, ["Shaco"] = 4, ["Shen"] = 1,
        ["Shyvana"] = 2, ["Singed"] = 1, ["Sion"] = 1, ["Sivir"] = 5, ["Skarner"] = 2,
        ["Sona"] = 3, ["Soraka"] = 4, ["Swain"] = 3, ["Sylas"] = 4, ["Syndra"] = 4,
        ["TahmKench"] = 1, ["Taliyah"] = 4, ["Talon"] = 4, ["Taric"] = 1, ["Teemo"] = 4,
        ["Thresh"] = 1, ["Tristana"] = 5, ["Trundle"] = 2, ["Tryndamere"] = 4,
        ["TwistedFate"] = 4, ["Twitch"] = 5, ["Udyr"] = 2, ["Urgot"] = 2, ["Varus"] = 5,
        ["Vayne"] = 5, ["Veigar"] = 4, ["Velkoz"] = 4, ["Vex"] = 4, ["Vi"] = 2,
        ["Viego"] = 4, ["Viktor"] = 4, ["Vladimir"] = 3, ["Volibear"] = 2, ["Warwick"] = 2,
        ["Xayah"] = 5, ["Xerath"] = 4, ["Xinzhao"] = 3, ["Yasuo"] = 4, ["Yone"] = 4,
        ["Yorick"] = 2, ["Yuumi"] = 2, ["Zac"] = 1, ["Zed"] = 4, ["Zeri"] = 5,
        ["Ziggs"] = 4, ["Zilean"] = 3, ["Zoe"] = 4, ["Zyra"] = 3
    }
    self.sortingModes = {
        [1] = function(a, b) -- AUTO_PRIORITY
            local a_dmg = Damage:CalcEffectiveDamage(myHero, a, 100)
            local b_dmg = Damage:CalcEffectiveDamage(myHero, b, 100)
            return a_dmg / (1 + a.health) * self:GetPriority(a)
                > b_dmg / (1 + b.health) * self:GetPriority(b)
        end,
        [2] = function(a, b) -- LESS_ATTACK
            local a_dmg = Damage:CalcPhysicalDamage(myHero, a, 100)
            local b_dmg = Damage:CalcPhysicalDamage(myHero, b, 100)
            return a_dmg / (1 + a.health) * self:GetPriority(a)
                > b_dmg / (1 + b.health) * self:GetPriority(b)
        end,
        [3] = function(a, b) -- LESS_CAST
            local a_dmg = Damage:CalcMagicalDamage(myHero, a, 100)
            local b_dmg = Damage:CalcMagicalDamage(myHero, b, 100)
            return a_dmg / (1 + a.health) * self:GetPriority(a)
                > b_dmg / (1 + b.health) * self:GetPriority(b)
        end,
        [4] = function(a, b) -- MOST_AD
            return Damage:CalcPhysicalDamage(myHero, a)
                > Damage:CalcPhysicalDamage(myHero, b)
        end,
        [5] = function(a, b) -- MOST_AP
            return Damage:CalcMagicalDamage(myHero, a)
                > Damage:CalcMagicalDamage(myHero, b)
        end,
        [6] = function(a, b) -- LOW_HEALTH
            return a.health < b.health
        end,
        [7] = function(a, b) -- CLOSEST
            local pos = myHero.origin
            return Geometry:DistanceSqr(pos, b.origin)
                < Geometry:DistanceSqr(pos, a.origin)
        end,
        [8] = function(a, b) -- NEAR_MOUSE
            local pos = game.mouse_pos
            return Geometry:DistanceSqr(pos, b.origin)
                < Geometry:DistanceSqr(pos, a.origin)
        end
    }
end

function TargetSelector:GetPriority(unit)
    local name = unit.champ_name
    local mod = {1, 1.5, 1.75, 2, 2.5}
    return mod[self.priorityList[name] or 3]
end

function TargetSelector:GetTarget(range, mode)
    local enemies = ObjectManager:GetEnemyHeroes(range):Where(
        function(e) return not self.data:IsImmortal(e) end)
    if #enemies <= 1 then return enemies[1] or nil end
    table.sort(enemies, self.sortingModes[mode or 1])
    return enemies[1]
end

---------------------
-- Orbwalker class --

local Orbwalker = Class()

function Orbwalker:__init()
    self.attackDelay = 0
    self.attackTimer = 0
    self.attackWindup = 0
    self.baseAttackSpeed = 0
    self.baseWindupTime = 0
    self.castEndTimer = 0
    self.dashTimer = 0
    self.moveTimer = 0
    self.orbwalkMode = 0
    self.orderTimer = 0
    self.waitTimer = 0
    self.forcedPos = nil
    self.forcedTarget = nil
    self.lastTarget = nil
    self.attacksEnabled = true
    self.canFirePostEvent = true
    self.canMove = true
    self.isMouseButtonDown = false
    self.movementEnabled = true
    self.waitForEvent = false
    self.onBasicAttack = {}
    self.onPostAttack = {}
    self.onPreAttack = {}
    self.onPreMovement = {}
    self.onUnkillable = {}
    self.excluded = {}
    self.handled = {}
    self.monsters = Linq()
    self.pets = Linq()
    self.waveMinions = Linq()
    self.damage = Damage:New()
    self.data = Data:New()
    self.geometry = Geometry:New()
    self.prediction = Prediction:New()
    self.objectManager = ObjectManager:New()
    self.targetSelector = TargetSelector:New(self.data)
    self.gravesDelay = function(delay) return 1.8 * delay - 2.0 end
    self.menu = menu:add_category_sprite("Orbwalker [Lua]", Logo)
    self.main = menu:add_subcategory("Main Settings", self.menu)
    self.b_orbon = menu:add_checkbox("Enable Orbwalking", self.main, 1)
    self.b_reset = menu:add_checkbox("Reset Attacks", self.main, 1, "Resets auto-attack timer when hero casts a specific spell.")
    self.b_support = menu:add_checkbox("Support Mode", self.main, 0, "Turns off last-hits and helps your ally to laneclear faster.")
    self.b_wall = menu:add_checkbox("Windwall Check", self.main, 0, "Blocks auto-attack if it would collide with windwall.")
    if myHero.champ_name == "Akshan" then self.b_akshan = menu:add_toggle("Use Passive On Hero", 1, self.main, string.byte("N"), true) end
    if myHero.champ_name == "Zeri" then self.b_zeri = menu:add_checkbox("Use Burst Fire [Q]", self.main, 1) end
    self.s_delay = menu:add_slider("Extra Attack Delay", self.main, -100, 100, 0)
    self.s_hradius = menu:add_slider("Hold Radius", self.main, 50, 150, 75)
    self.farm = menu:add_subcategory("Farm Settings", self.menu)
    self.b_stack = menu:add_checkbox("Focus Most Stacked", self.farm, 0, "Attacks minions containing applied stacks as first.")
    self.b_priocn = menu:add_checkbox("Prioritize Cannon Minions", self.farm, 1, "Last-hits a cannon minion first without any condition check.")
    self.b_priolh = menu:add_checkbox("Prioritize Last Hits", self.farm, 0, "Harass mode will focus on last-hit instead of enemy hero.")
    self.s_farm = menu:add_slider("Extra Farm Delay", self.farm, 0, 100, 0, "Defines a delay for last-hit execution.")
    self.keys = menu:add_subcategory("Key Settings", self.menu)
    self.k_combo = menu:add_keybinder("Combo Key", self.keys, string.byte(' '))
    self.k_harass = menu:add_keybinder("Harass Key", self.keys, string.byte('C'))
    self.k_laneclear = menu:add_keybinder("Lane Clear Key", self.keys, string.byte('V'))
    self.k_lasthit = menu:add_keybinder("Last Hit Key", self.keys, string.byte('X'))
    self.k_freeze = menu:add_keybinder("Freeze Key", self.keys, string.byte('A'))
    self.k_flee = menu:add_keybinder("Flee Key", self.keys, string.byte('Z'))
    self.selector = menu:add_subcategory("Selector Settings", self.menu)
    self.b_focus = menu:add_checkbox("Focus Left-Clicked", self.selector, 1)
    self.c_mode = menu:add_combobox("Target Selector Mode", self.selector, {"Auto", "Less Attack",
        "Less Cast", "Most AD", "Most AP", "Low Health", "Closest", "Near Mouse"}, 0)
    self.drawings = menu:add_subcategory("Drawing Settings", self.menu)
    self.b_drawon = menu:add_checkbox("Enable Drawings", self.drawings, 1)
    self.b_indicator = menu:add_checkbox("Draw Damage Indicator", self.drawings, 1, "Draws predicted damage to lane minions.")
    self.b_range = menu:add_checkbox("Draw Player Attack Range", self.drawings, 1, "Draws auto-attack range around your hero.")
    self.color_p = menu:add_subcategory("Player Range Color", self.drawings)
    self.r1 = menu:add_slider("Red Value", self.color_p, 0, 255, 255)
    self.g1 = menu:add_slider("Green Value", self.color_p, 0, 255, 255)
    self.b1 = menu:add_slider("Blue Value", self.color_p, 0, 255, 255)
    self.b_enemy = menu:add_checkbox("Draw Enemy Attack Range", self.drawings, 1, "Draws auto-attack range around enemy.")
    self.color_e = menu:add_subcategory("Enemy Range Color", self.drawings)
    self.r2 = menu:add_slider("Red Value", self.color_e, 0, 255, 255)
    self.g2 = menu:add_slider("Green Value", self.color_e, 0, 255, 255)
    self.b2 = menu:add_slider("Blue Value", self.color_e, 0, 255, 255)
    self.b_markmin = menu:add_checkbox("Mark Lane Minions", self.drawings, 1)
    self.b_marktrg = menu:add_checkbox("Mark Forced Target", self.drawings, 1)
    self.humanizer = menu:add_subcategory("Humanizer Settings", self.menu)
    self.b_humanon = menu:add_checkbox("Enable Humanizer", self.humanizer, 1)
    self.s_min = menu:add_slider("Min Move Delay", self.humanizer, 75, 200, 125)
    self.s_max = menu:add_slider("Max Move Delay", self.humanizer, 75, 200, 175)
    self.creator = menu:add_label("Creator: Uncle Ark", self.menu)
    self.version = menu:add_label("Version: " .. DisplayVersion, self.menu)
    client:set_event_callback("on_tick", function() self:OnTick() end)
    client:set_event_callback("on_draw", function() self:OnDraw() end)
    client:set_event_callback("on_process_spell", function(...) self:OnProcessSpell(...) end)
    client:set_event_callback("on_cast_done", function(...) self:OnCastDone(...) end)
    client:set_event_callback("on_stop_cast", function(...) self:OnStopCast(...) end)
    client:set_event_callback("on_wnd_proc", function(...) self:OnWndProc(...) end)
end

function Orbwalker:AttackUnit(unit)
    if self:HasAttacked() then return end
    if self.forcedPos then return end
    if self.b_zeri and spellbook:can_cast(SLOT_Q)
        and menu:get_value(self.b_zeri) == 1 then
        local pred = DreamPred.GetPrediction(unit,
            {type = "linear", speed = 2600, range = 825,
            delay = 0, radius = 40, width = 80}, myHero)
        local valid = output and output.castPosition and
            output.targetPosition and output.hitChance > 0
        if not valid and unit.is_hero then return end
        local position = valid and output.targetPosition
        if not position then position = unit.origin end
        spellbook:cast_spell(SLOT_Q, 0.1, position.x,
            position.y, position.z) return end
    local args = {target = unit, process = true}
    self:FireOnPreAttack(args)
    if not args.process then return end
    issueorder:attack_unit(unit)
    self.attackWindup = self:GetWindupTime()
    self.attackTimer, self.canMove = game.game_time, false
    self.castEndTimer = self.attackTimer + self.attackWindup
    self.lastTarget, self.waitForEvent = unit, true
    self.orderTimer = self.attackTimer
end

function Orbwalker:CanAttack(delay)
    if self:HasAttacked() then return false end
    if evade:is_evading() then return false end
    local sight = not myHero:has_buff_type(26)
    local zeri = myHero.champ_name == "Zeri"
    local kalista = myHero.champ_name == "Kalista"
    if not (zeri or kalista or sight) then return false end
    if not self.data:CanOrbwalk() then return false end
    if not self.data:CanAttack() then return false end
    local graves = myHero.champ_name == "Graves"
    local dashElapsed = game.game_time - self.dashTimer
    local dashing = dashElapsed < (graves and 0.2 or 0.034)
    if not kalista and dashing == true then return false end
    if graves and not myHero:has_buff("gravesbasicattackammo1") or
        not graves and myHero.is_winding_up then return false end
    local loading = zeri and myHero.passive_count < 100
    if zeri and menu:get_value(self.b_zeri) == 1 and
        spellbook:can_cast(SLOT_Q) then return true end
    if loading and self.orbwalkMode == 1 then return false end
    local extraDelay = menu:get_value(self.s_delay) * 0.001
    local endTime = self.attackTimer + self:GetAnimationTime()
    return game.game_time >= endTime + extraDelay + delay
end

function Orbwalker:CanMove(delay)
    if self:HasAttacked() then return false end
    if evade:is_evading() then return false end
    if not self.data:CanOrbwalk() then return false end
    local kalista = myHero.champ_name == "Kalista"
    local kaisa = myHero.champ_name == "Kaisa"
    if kaisa == true and myHero:has_buff("KaisaE")
        or kalista == true then return true end
    local graves = myHero.champ_name == "Graves"
    local dashElapsed = game.game_time - self.dashTimer
    local dashing = dashElapsed < (graves and 0.2 or 0.034)
    if not kalista and dashing == true then return false end
    if not graves and myHero.is_winding_up then return false end
    return not self:IsAutoAttacking(delay)
end

function Orbwalker:ExcludeMinion(minion)
    local id = minion.object_id or 0
    self.excluded[id] = game.game_time + 5
end

function Orbwalker:GetAnimationTime()
    local speed = myHero.attack_speed
    local delay = myHero.attack_delay
    if self.attackTimer > 0 and speed and delay then
        self.baseAttackSpeed = 1 / (delay * speed) end
    if self.baseAttackSpeed == 0 then return delay end
    return 1 / (speed * self.baseAttackSpeed)
end

function Orbwalker:GetTarget(range, mode)
    local target = self.forcedTarget
    if target and self.data:IsValid(target) then
        local heroPos = myHero.path.server_pos
        local targetPos = target.path.server_pos
        if range and self.geometry:DistanceSqr(
            heroPos, targetPos) <= range * range
            or self.geometry:IsInAutoAttackRange(
            target) then return target end
    end
    local mode = mode or (menu:get_value(self.c_mode) + 1)
    return self.targetSelector:GetTarget(range, mode)
end

function Orbwalker:GetWindupTime()
    local windup = self.data:GetSpecialWindup()
    if windup ~= nil then return windup end
    local speed = myHero.attack_speed
    local windup = self.attackWindup
    if self.attackTimer > 0 and windup ~= 0 then
        self.baseWindupTime = 1 / (windup * speed) end
    if self.baseWindupTime == 0 then return windup end
    return math.max(windup, 1 / (speed * self.baseWindupTime))
end

function Orbwalker:HasAttacked()
    local timer = self.attackTimer
    local fast = myHero.attack_speed > 2.5
    timer = timer - (fast and 0.025 or 0)
    local elapsed = game.game_time - timer
    return self.waitForEvent and elapsed <=
        math.max(0.1, self.data:Latency())
end

function Orbwalker:IsAutoAttacking(delay)
    local extra = menu:get_value(self.s_delay) * 0.001 + delay
    local canMove = game.game_time >= self.castEndTimer + extra
    if not self.canMove and canMove then self.canMove = true end
    return not self.canMove
end

function Orbwalker:IsCollidingWindwall(target)
    local speed = self.data:GetProjectileSpeed()
    if speed == math.huge then return false end
    local range = self.geometry:Distance(
        myHero.origin, target.origin)
    local windup = self:GetWindupTime()
    local pred = DreamPred.GetFakePrediction(
        {type = "linear", speed = speed or 2000,
        range = range, delay = windup, radius = 1,
        width = 1, collision = {["Wall"] = true,
        ["Hero"] = false, ["Minion"] = false}},
        target.origin, myHero, target)
    if not pred then return false end
    return pred:IsWindWallCollision()
end

function Orbwalker:IsAboutToKill(minion)
    return self.handled[minion.object_id] ~= nil
end

function Orbwalker:MoveTo()
    if game.game_time < self.moveTimer then return end
    local position = self.forcedPos or game.mouse_pos
    local radius = menu:get_value(self.s_hradius)
    if not self.forcedPos and self.geometry:Distance(
        myHero.origin, position) <= radius then
        issueorder:stop(myHero.origin) return end
    local tmin = menu:get_value(self.s_min)
    local tmax = menu:get_value(self.s_max)
    local delay = menu:get_value(self.b_humanon) == 1
        and math.random(tmin, tmax) * 0.001 or 0.034
    local args = {position = position, process = true}
    self:FireOnPreMovement(args)
    if not args.process then return end
    issueorder:move_fast(position)
    self.moveTimer = game.game_time + delay
    if self.forcedPos then self.forcedPos = nil end
end

function Orbwalker:ShouldWait(mod)
    if support == 1 then return false end
    local wait = self.waveMinions:Any(function(m)
        return m.clearPred - m.damage <= 0 end)
    if wait then self.waitTimer = game.game_time end
    return game.game_time - self.waitTimer <= 1.5
end

function Orbwalker:GetOrbwalkerTarget(mode)
    if not mode or mode == 0 then return nil end
    if mode <= 2 or mode == 3 and self.forcedTarget then
        -- attack the enemy hero or forced target
        local target = self:GetTarget()
        if target ~= nil and (mode >= 1 and mode <= 2
            and target.is_hero or mode == 3 and not
            target.is_hero) then return target end
    end
    local support = menu:get_value(self.b_support)
    if #self.objectManager:GetAllyHeroes(1500) == 0
        and support == 1 then support = 0 end
    if mode >= 2 and mode <= 5 then
        -- sometimes we last hit too early - we have to fix it :/    
        self.waveMinions:ForEach(function(m) local obj = m.gameObject
            local total = self.prediction:TotalAggroDamage(obj)
            if obj.health > m.damage and m.healthPred > total
            and not m.inTurret then m.killable = false end end)
        -- wait for cannon minion to last hit
        local prioCannon = menu:get_value(self.b_priocn) == 1
        local waitCannon = self.waveMinions:Any(function(m)
            return m.gameObject.champ_name:find("Siege")
            and m.truePred <= m.damage and m.truePred ~=
            m.gameObject.health and not m.killable end)
        if prioCannon and waitCannon then return nil end
        -- find a wave minion to last hit
        local minions = self.waveMinions:Where(
            function(m) return m.killable end)
        if mode == 5 and #minions > 0 and minions:All(
            function(m) return m.healthPred >= 50 and
            m.freezePred > 0 end) then return nil end
        if #minions > 0 and support == 0 then
            -- prioritize cannon minions
            local cannons = minions:Where(function(m) return
                m.gameObject.champ_name:find("Siege") end)
            if prioCannon == true and #cannons > 0 then
                local cannon = cannons[1].gameObject
                local id = cannon.object_id or 0
                self.handled[id] = game.game_time + 3
                return cannon end
            -- there is a minion with high aggro, wait for lasthit
            if minions:All(function(m) return m.healthPred > 0 end)
                and self.waveMinions:Except(minions):Any(function(m)
                return m.truePred <= 0 end) then return nil end
            -- last hit a minion
            local minion = minions[1].gameObject
            local id = minion.object_id or 0
            self.handled[id] = game.game_time + 3
            return minion
        end
        local fast = self.isMouseButtonDown
        -- attack a pet for ex. Annie's Tibbers
        if #self.pets > 0 then return self.pets[1] end
        local turret = self.objectManager:GetClosestAllyTurret()
        if not fast and turret and self.geometry:DistanceSqr(
            myHero.origin, turret.origin) <= 1000 * 1000 then
            -- under-turret logic
            local turretTarget, unkillable = nil, nil
            local data = self.waveMinions:First(function(m) return
                self.prediction:HasTurretAggro(m.gameObject) end)
            local minion = data ~= nil and data.gameObject or nil
            if minion ~= nil then
                local timer, hpLeft, hpBeforeDie, count = game.game_time, 0, 0, 0
                local delay, latency = turret.attack_delay, self.data:Latency()
                local startTime = self.prediction:TurretAggroStartTime(turret)
                local speed = turret:get_basic_attack_data().missile_speed + 70
                local dist = self.geometry:Distance(minion.origin, turret.origin)
                local landTime = startTime + turret.attack_cast_delay + dist / speed
                -- calculate the predicted health before trying to balance it
                for step = 0.05, 5 * delay + 0.05, delay do
                    local time = math.max(0, landTime + step - timer + latency)
                    local health = self.prediction:GetLaneClearHealthPrediction(minion, time, true)
                    if health > 0 then hpLeft, count = health, count + 1
                    else hpBeforeDie = hpLeft; hpLeft = 0; break end
                end
                -- calculate the hits
                if hpLeft == 0 and count ~= 0 and hpBeforeDie ~= 0 then
                    local hits = hpBeforeDie / data.damage
                    local timeBeforeDie = landTime + (count + 1) * delay - timer
                    local timeUntilReady = self.attackTimer + self.attackDelay
                        > (timer + latency + 0.025) and self.attackTimer +
                        self.attackDelay - (timer + latency + 0.025) or 0
                    if hits >= 1 and hits * self.attackDelay + timeUntilReady +
                        data.timeToHit <= timeBeforeDie then turretTarget = minion
                    elseif hits >= 1 and hits * self.attackDelay + timeUntilReady +
                        data.timeToHit > timeBeforeDie then unkillable = minion end
                elseif hpLeft == 0 and count == 0 and hpBeforeDie == 0 then
                    unkillable = minion
                end
                -- check if we should wait before attacking minion
                if self.waveMinions:Any(function(m) return (unkillable ~= nil and
                    unkillable.object_id ~= m.gameObject.object_id or not unkillable)
                    and m.truePred - m.damage <= 0 end) then return nil end
                if turretTarget ~= nil then return turretTarget end
            end
            -- balance minions
            local candidates = self.waveMinions:Where(function(data)
                local obj = data.gameObject; local waypoints = obj.path.waypoints
                local pos = #waypoints == 0 and obj.origin or waypoints[#waypoints]
                return self.geometry:DistanceSqr(pos, turret.origin) <= 739600 and
                    (minion and minion.object_id ~= obj.object_id or not minion) end)
            for _, data in ipairs(candidates) do
                local candidate, damageP = data.gameObject, data.damage
                local damageT = self.prediction:GetDamage(turret, candidate)
                if candidate.health % damageT >= damageP then return candidate end
            end
            if minion ~= nil or #candidates > 0 then return nil end
        end
        if mode ~= 3 then return end
        local shouldWait = self:ShouldWait(support)
        if not fast and shouldWait then return nil end
        -- attack the closest turret
        local turret = self.objectManager:GetEnemyTurret()
        if turret ~= nil then return turret end
        -- attack the closest inhibitor or nexus
        local struct = self.objectManager:GetEnemyStructure()
        if struct ~= nil then return struct end
        -- attack the closest ward
        local ward = self.objectManager:GetEnemyWard()
        if ward ~= nil then return ward end
        -- lane clear the wave minions
        local mod = fast and 0 or support == 0 and 1 or 3
        local minions = self.waveMinions:Where(function(m)
            return m.clearPred > m.damage * mod end)
        if #minions > 0 then
            -- decide which minion we should attack
            local minion = #self.waveMinions == #minions
                and minions[1] or minions[#minions]
            local stack = self.data.buffStackNames[myHero.champ_name]
            if stack and menu:get_value(self.b_stack) == 1 then
                -- choose the most stacked minion
                local stacked = minions:First(function(m)
                    return m.gameObject:has_buff(stack) end)
                if stacked ~= nil then minion = stacked end
            end
            if minion then return minion.gameObject end
        end
        -- attack a monster with the lowest hp
        return self.monsters[1] or nil
    end
    return nil
end

function Orbwalker:UpdateMinionData()
    local minions = self.objectManager:GetEnemyMinions()
    local monsters = self.objectManager:GetEnemyMonsters()
    local turret = self.objectManager:GetClosestAllyTurret()
    local pets = self.objectManager:GetEnemyPets()
    self.monsters = monsters:Where(function(m) return
        self.data.monsterNames[m.champ_name] ~= nil end)
    self.pets = pets:Where(function(p) return
        self.data.petNames[p.champ_name] ~= nil end)
    table.sort(self.monsters, function(a, b)
        return (a.health or 0) > (b.health or 0) end)
    local waveMinions = minions:Where(function(m)
        return m.champ_name:find("Minion") and
        not self.excluded[m.object_id] end)
    if #waveMinions == 0 then
        self.waveMinions = Linq() return end
    local canMove = self:CanMove(0.05)
    local canAttack = self:CanAttack(0)
    local pos = myHero.path.server_pos
    local windup = self:GetWindupTime()
    local anim = self:GetAnimationTime()
    local latency = self.data:Latency()
    local endTimer = self.attackTimer + anim
    local speed = self.data:GetProjectileSpeed()
    local delay = menu:get_value(self.s_farm) * 0.001
    local cooldown = endTimer - game.game_time + latency
    self.waveMinions = waveMinions:Select(function(m)
        local timeToHit = self.geometry:Distance(pos, m.origin) / speed + windup
        local damage, id = self.damage:CalcAutoAttackDamage(myHero, m), m.object_id
        local inTurret = turret and self.geometry:DistanceSqr(m.origin, turret.origin) <= 739600
        local truePred = self.prediction:GetLaneClearHealthPrediction(m, timeToHit + anim, true)
        local clearPred = self.prediction:GetLaneClearHealthPrediction(m, timeToHit + anim + 0.25)
        local killPred = self.prediction:GetHealthPrediction(m, timeToHit + math.max(0, cooldown))
        local freezePred = self.prediction:GetHealthPrediction(m, timeToHit + latency + 1.0)
        local healthPred = self.prediction:GetHealthPrediction(m, timeToHit, delay)
        if killPred <= 0 and not self.handled[id] then self:FireOnUnkillable(m) end
        return {damage = damage, gameObject = m, inTurret = inTurret, killable =
            damage >= healthPred, timeToHit = timeToHit, clearPred = clearPred,
            freezePred = freezePred, healthPred = healthPred, truePred = truePred}
    end)
    local aggro_id = self.prediction.turretMinion and
        self.prediction.turretMinion.object_id or -1
    table.sort(self.waveMinions, function(a, b)
        local a_obj, b_obj = a.gameObject, b.gameObject
        local a_turret = a_obj.object_id == aggro_id
        local b_turret = b_obj.object_id == aggro_id
        local a_siege = a_obj.champ_name:find("Siege")
        local b_siege = b_obj.champ_name:find("Siege")
        local a_health, b_health = a.truePred, b.truePred
        return a_turret and not b_turret or (a_turret == b_turret
            and (not a_siege and b_siege or (a_siege == b_siege
            and (a_health < b_health or a_health == b_health
            and a_obj.max_health > b_obj.max_health))))
    end)
end

-- Delegates

function Orbwalker:FireOnBasicAttack(target)
    for i = 1, #self.onBasicAttack do
        self.onBasicAttack[i](target) end
end

function Orbwalker:FireOnPostAttack(target)
    for i = 1, #self.onPostAttack do
        self.onPostAttack[i](target) end
end

function Orbwalker:FireOnPreAttack(args)
    for i = 1, #self.onPreAttack do
        self.onPreAttack[i](args) end
end

function Orbwalker:FireOnPreMovement(args)
    for i = 1, #self.onPreMovement do
        self.onPreMovement[i](args) end
end

function Orbwalker:FireOnUnkillable(minion)
    local id = minion.object_id or 0
    self.handled[id] = game.game_time + 3
    for i = 1, #self.onUnkillable do
        self.onUnkillable[i](minion) end
end

function Orbwalker:OnBasicAttack(func)
    table.insert(self.onBasicAttack, func)
end

function Orbwalker:OnPostAttack(func)
    table.insert(self.onPostAttack, func)
end

function Orbwalker:OnPreAttack(func)
    table.insert(self.onPreAttack, func)
end

function Orbwalker:OnPreMovement(func)
    table.insert(self.onPreMovement, func)
end

function Orbwalker:OnUnkillableMinion(func)
    table.insert(self.onUnkillable, func)
end

-- Events

function Orbwalker:OnTick()
    self:UpdateMinionData()
    for id, timer in pairs(self.excluded) do
        if game.game_time >= timer then
        self.excluded[id] = nil end end
    for id, timer in pairs(self.handled) do
        if game.game_time >= timer then
        self.handled[id] = nil end end
    if myHero.path.is_dashing then
        self.dashTimer = game.game_time end
    if self.canFirePostEvent and game.game_time >=
        self.attackTimer + self:GetWindupTime() then
        self:FireOnPostAttack(self.lastTarget)
        self.canFirePostEvent = false end
    if self.forcedTarget ~= nil and not
        self.data:IsValid(self.forcedTarget)
        then self.forcedTarget = nil end
    selector:set_focus_target(self.forcedTarget
        and self.forcedTarget.object_id or 0)
    if menu:get_value(self.b_orbon) == 0 then return end
    local combo = menu:get_value(self.k_combo)
    local harass = menu:get_value(self.k_harass)
    local laneClear = menu:get_value(self.k_laneclear)
    local lastHit = menu:get_value(self.k_lasthit)
    local freeze = menu:get_value(self.k_freeze)
    local flee = menu:get_value(self.k_flee)
    local mode = game:is_key_down(combo) and 1
        or game:is_key_down(harass) and 2
        or game:is_key_down(laneClear) and 3
        or game:is_key_down(lastHit) and 4
        or game:is_key_down(freeze) and 5
        or game:is_key_down(flee) and 6 or nil
    self.orbwalkMode = mode or 0
    client:set_mode(self.orbwalkMode)
    if self.attacksEnabled and self:CanAttack(0) then
        local target = self:GetOrbwalkerTarget(mode)
        if target and not (menu:get_value(self.b_wall) == 1
            and self:IsCollidingWindwall(target)) then
            self.waitTimer = 0; self:AttackUnit(target)
        end
    end
    if mode and self.movementEnabled and
        self:CanMove(0) then self:MoveTo() end
end

function Orbwalker:OnDraw()
    if menu:get_value(self.b_drawon) == 0 then return end
    if menu:get_value(self.b_range) == 1 then
        local range = self.data:GetAutoAttackRange()
        local pos, r = myHero.origin, menu:get_value(self.r1)
        local g, b = menu:get_value(self.g1), menu:get_value(self.b1)
        renderer:draw_circle(pos.x, pos.y, pos.z, range, r, g, b, 128)
    end
    if menu:get_value(self.b_enemy) == 1 then
        Linq(game.players):Where(function(u) return u.is_enemy
            and self.data:IsValid(u) end):ForEach(function(u)
            local range = self.data:GetAutoAttackRange(u)
            local pos, r = u.origin, menu:get_value(self.r2)
            local g, b = menu:get_value(self.g2), menu:get_value(self.b2)
            renderer:draw_circle(pos.x, pos.y, pos.z, range, r, g, b, 128)
        end)
    end
    local forced = Linq({self.forcedTarget})
    self.waveMinions:Concat(forced):ForEach(function(data)
        local obj = data and data.gameObject or data
        local bar = obj and obj.health_bar or nil
        if not (bar and bar.is_on_screen) then return end
        -- animated drawings <3
        local minion, hero = obj.is_minion, obj.is_hero
        if minion and menu:get_value(self.b_markmin) == 1 or
            hero and menu:get_value(self.b_marktrg) == 1 then
            local elapsed = math.rad((game.game_time % 5) * 72)
            local points = self.geometry:CircleToPolygon(
                obj.origin, obj.bounding_radius + 50, 5, elapsed)
            local color = {r = 255, g = 235, b = 140, a = 128}
            if minion and data.damage and data.healthPred then
                color = data.damage >= data.healthPred and
                {r = 255, g = 85, b = 85, a = 128} or
                data.clearPred - data.damage <= 0 and
                {r = 255, g = 215, b = 0, a = 128} or
                {r = 255, g = 255, b = 255, a = 128} end
            self.geometry:DrawPolygon(points, color, 2)
        end
        -- HP bar total damage split overlay
        local draw = menu:get_value(self.b_indicator) == 1
        if not draw or not data.healthPred then return end
        local pos = {x = bar.pos.x - 31, y = bar.pos.y - 6}
        local isSuper = obj.champ_name:find("Super")
        if isSuper then pos.x = pos.x - 15 end
        local origin = {x = pos.x, y = pos.y}
        local width = isSuper and 90 or 60
        local maxHealth = obj.max_health
        local health = math.max(0, obj.health)
        local ratio = width * data.damage / maxHealth
        local start = pos.x + width * health / maxHealth
        for step = 1, math.floor(health / data.damage) do
            pos.x = math.floor(start - ratio * step + 0.5)
            if pos.x > origin.x and pos.x < origin.x + width then
                renderer:draw_line(pos.x, pos.y, pos.x,
                    pos.y + 4, 2, 16, 16, 16, 255)
            end
        end
    end)
end

function Orbwalker:OnProcessSpell(unit, args)
    if unit.object_id ~= myHero.object_id then return end
    local reset = self.data.resetAttackNames[args.spell_name]
    local canReset = menu:get_value(self.b_reset) == 1
    local buff = unit:get_buff("AkshanPassiveDebuff")
    local isAkshan = myHero.champ_name == "Akshan"
    if reset ~= nil and canReset and (isAkshan
        and menu:get_toggle_state(self.b_akshan) and
        self.lastTarget and self.lastTarget.is_hero and
        not (buff and buff.is_valid and buff.count == 2) or
        not isAkshan) then self.attackTimer = 0 return end
    if not args.is_autoattack then return end
    local speed = myHero.attack_speed or 1.0
    local attackTimer = game.game_time - self.data:Latency()
    self.attackDelay, self.canMove = myHero.attack_delay, false
    self.attackWindup = args.cast_delay or myHero.attack_cast_delay
    self.attackTimer = attackTimer - (speed > 2.5 and 0.025 or 0)
    self.castEndTimer = self.attackTimer + self.attackWindup
    self.canFirePostEvent, self.waitForEvent = true, false
    if not args.target then return end
    self.lastTarget = args.target
    self:FireOnBasicAttack(self.lastTarget)
end

function Orbwalker:OnCastDone(args)
    if args.is_autoattack then
        self.canMove = true
    end
end

function Orbwalker:OnStopCast(unit, args)
    if unit.object_id ~= myHero.object_id
        or not args.stop_animation or not
        args.destroy_missile then return end
    issueorder:stop(myHero.path.server_pos)
    client:delay_action(function()
        self.attackTimer = 0 end, 0.05)
end

function Orbwalker:OnWndProc(msg, wparam)
    if msg == 513 and wparam == 1 then
        self.isMouseButtonDown = true
    elseif msg == 514 and wparam == 0 then
        self.isMouseButtonDown = false
    end
    if menu:get_value(self.b_focus) == 0
        or msg ~= 514 or wparam ~= 0 or
        game.is_shop_opened then return end
    local mousePos = game.mouse_pos
    local target = Linq(game.players):First(
        function(u) return self.data:IsValid(u) and
        u.is_enemy and self.geometry:DistanceSqr(
        game.mouse_pos, u.origin) <= 10000 end)
    self.forcedTarget = target or nil
end

local orb = Orbwalker:New()
console:log("[Orbwalker] Successfully loaded!")

_G.orbwalker = {
    attack_target = function(self, unit) orb:AttackUnit(unit) end,
    can_attack = function(self, delay) return orb:CanAttack(delay or 0) end,
    can_move = function(self, delay) return orb:CanMove(delay or 0) end,
    disable_auto_attacks = function(self) orb.attacksEnabled = false end,
    disable_move = function(self) orb.movementEnabled = false end,
    enable_auto_attacks = function(self) orb.attacksEnabled = true end,
    enable_move = function(self) orb.movementEnabled = true end,
    exclude_minion = function(self, minion) orb:ExcludeMinion(minion) end,
    force_target = function(self, target) orb.forcedTarget = target end,
    get_animation_time = function(self) return orb:GetAnimationTime() end,
    get_auto_attack_timer = function(self) return orb.attackTimer end,
    get_auto_attack_range = function(self, unit) return orb.data:GetAutoAttackRange(unit) end,
    get_health_prediction = function(self, unit, time, delay) return
        orb.prediction:GetHealthPrediction(unit, time, delay) end,
    get_lane_clear_health_prediction = function(self, unit, time, active) return
        orb.prediction:GetLaneClearHealthPrediction(unit, time, active) end,
    get_orbwalker_target = function(self) return orb.lastTarget end,
    get_projectile_speed = function(self) return orb.data:GetProjectileSpeed() end,
    get_target = function(self, range) return orb:GetTarget(range, mode) end,
    get_windup_time = function(self) return orb:GetWindupTime() end,
    is_about_to_kill = function(self, minion) return orb:IsAboutToKill(minion) end,
    is_auto_attacking = function(self) return not orb:IsAutoAttacking(0) end,
    is_auto_attack_enabled = function(self) return orb.attacksEnabled end,
    is_movement_enabled = function(self) return orb.movementEnabled end,
    move_to = function(self, x, y, z) orb.forcedPos = x and y
        and z and vec3.new(x, y, z) or game.mouse_pos end,
    on_basic_attack = function(self, func) orb:OnBasicAttack(func) end,
    on_post_attack = function(self, func) orb:OnPostAttack(func) end,
    on_pre_attack = function(self, func) orb:OnPreAttack(func) end,
    on_pre_movement = function(self, func) orb:OnPreMovement(func) end,
    on_unkillable_minion = function(self, func) orb:OnUnkillableMinion(func) end,
    reset_aa = function(self) orb.attackTimer = 0 end
}

_G.combo = {
    get_mode = function(self)
        return ({[0] = MODE_NONE, [1] = MODE_COMBO,
            [2] = MODE_HARASS, [3] = MODE_LANECLEAR,
            [4] = MODE_LASTHIT, [5] = MODE_FREEZE,
            [6] = MODE_FLEE})[orb.orbwalkMode]
    end
}

