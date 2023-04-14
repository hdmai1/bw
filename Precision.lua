
--[[

    ,------.                     ,--.       ,--.                
    |  .--. ',--.--. ,---.  ,---.`--' ,---. `--' ,---. ,--,--,  
    |  '--' ||  .--'| .-. :| .--',--.(  .-' ,--.| .-. ||      \ 
    |  | --' |  |   \   --.\ `--.|  |.-'  `)|  |' '-' '|  ||  | 
    `--'     `--'    `----' `---'`--'`----' `--' `---' `--''--' 

    Uncle Ark <3

--]]

local Version = 0.11
local Url = "https://raw.githubusercontent.com/Ark223/Bruhwalker/main/"

local function AutoUpdate()
    local result = http:get(Url .. "Precision.version")
    if result and result ~= "" and tonumber(result) > Version then
        http:download_file(Url .. "Precision.lua", "Precision.lua")
        console:log("[Precision] Successfully updated. Please reload!")
        return true
    end
    return false
end

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
local myHero = game.local_player
local EC = require "EvadeCore"
local Line = EC.Line
local Linq = EC.Linq
local Vector = EC.Vector

--------------------------------
------------ Damage ------------

local Damage = Class()

function Damage:__init()
    self.jayce = {
        ['Q'] = function(unit, stance)
            if stance == "Hammer" then
                local level = spellbook:get_spell_slot(SLOT_Q).level
                local base = ({55, 95, 135, 175, 215, 255})[level]
                local amount = base + 1.2 * myHero.bonus_attack_damage
                return self:CalcPhysicalDamage(myHero, unit, amount, 0.5)
            elseif stance == "Cannon" then
                if spellbook:can_cast(SLOT_E) then
                    local level = spellbook:get_spell_slot(SLOT_Q).level
                    local base = ({77, 154, 231, 308, 385, 462})[level]
                    local amount = base + 1.68 * myHero.bonus_attack_damage
                    return self:CalcPhysicalDamage(myHero, unit, amount, 0.2143)
                else
                    local level = spellbook:get_spell_slot(SLOT_Q).level
                    local base = ({55, 110, 165, 220, 275, 330})[level]
                    local amount = base + 1.2 * myHero.bonus_attack_damage
                    return self:CalcPhysicalDamage(myHero, unit, amount, 0.2143)
                end
            end
        end,
        ['W'] = function(unit, stance)
            if stance == "Cannon" then return 0 end
            local level = spellbook:get_spell_slot(SLOT_W).level
            local base = ({25, 40, 55, 70, 85, 100})[level]
            local amount = base + 0.25 * myHero.ability_power
            return self:CalcMagicalDamage(myHero, unit, amount * 4)
        end,
        ['E'] = function(unit, stance)
            if stance == "Cannon" then return 0 end
            local level = spellbook:get_spell_slot(SLOT_E).level
            local base = ({8, 10.4, 12.8, 15.2, 17.6, 20})[level]
            local amount = base * 0.01 * unit.max_health
            amount = amount + myHero.bonus_attack_damage
            return self:CalcMagicalDamage(myHero, unit, amount, 0.25)
        end
    }
    self.karthus = {
        ['Q'] = function(unit)
            local level = spellbook:get_spell_slot(SLOT_Q).level
            local base = ({45, 62.5, 80, 97.5, 115})[level]
            local amount = base + 0.35 * myHero.ability_power
            return self:CalcMagicalDamage(myHero, unit, amount, 1.0)
        end,
        ['R'] = function(unit)
            local level = spellbook:get_spell_slot(SLOT_R).level
            local amount = 50 + 150 * level + 0.75 * myHero.ability_power
            return self:CalcMagicalDamage(myHero, unit, amount, 3.25)
        end
    }
end

function Damage:CalcMagicalDamage(source, unit, amount, time)
    local mr, time = unit.mr or 0, time or 0
    local amount = amount + unit.health_regen * time
    local magicPen = source.percent_magic_penetration
    local flatPen = source.flat_magic_penetration
    local magicRes = mr * magicPen - flatPen
    local value = mr < 0 and 2 - 100 / (100 - mr) or
        magicRes < 0 and 1 or (100 / (100 + magicRes))
    return math.max(0, math.floor(amount * value))
end

function Damage:CalcPhysicalDamage(source, unit, amount, time)
    local armor, time = unit.armor or 0, time or 0
    local amount = amount + unit.health_regen * time
    local armorPen = source.percent_armor_penetration
    local bonusPen = source.percent_bonus_armor_penetration
    local scaling = 0.6 + 0.4 * source.level / 18
    local lethality = source.lethality * scaling
    local bonus = unit.bonus_armor * (1 - bonusPen)
    local armorRes = armor * armorPen - bonus - lethality
    local value = armor < 0 and 2 - 100 / (100 - armor)
        or armorRes < 0 and 1 or 100 / (100 + armorRes)
    return math.max(0, math.floor(amount * value))
end

---------------------------------
------------- Maths -------------

local Maths = Class()

function Maths:__init() end

function Maths:CalcAOEPosition(points, hitbox, star)
    local average, count = Vector:New(), #points
    if count == 1 then return points[1], 1 end
    if count == 0 then return nil, 0 end
    average.x = points:Average("(p) => p.x")
    average.y = points:Average("(p) => p.y")
    local farthest = points:Aggregate(
        function(result, point, index)
        local dist = average:DistanceSquared(point)
        return dist > hitbox * hitbox and (result ~= 0
            and dist > result.dist or result == 0) and
            (star and point ~= star or not star) and
            {index = index, dist = dist} or result end)
    if farthest == 0 then return average, #points end
    table.remove(points, farthest.index)
    return self:CalcAOEPosition(points, hitbox)
end

function Maths:ClosestCollision(units, skillshot, buffer)
    local closest = {pos = nil, time = math.huge}
    for index, unit in ipairs(units) do
        local pos, time = self:PredictCollision(
            unit, skillshot, buffer or 30.0)
        if time and time < closest.time then
            closest.pos, closest.time = pos, time
        end
    end
    return closest.pos
end

function Maths:CollisionTime(p1, p2, v1, v2, ra, rb)
    local len = (ra + rb) * (ra + rb)
    local dp, dv = p1 - p2, v1 - v2
    local a = dv:LengthSquared()
    local b = 2 * dp:DotProduct(dv)
    local c = dp:LengthSquared() - len
    local delta = b * b - 4 * a * c
    if delta < 0 then return nil end
    local delta = math.sqrt(delta)
    local t1 = (-b - delta) / (2 * a)
    local t2 = (-b + delta) / (2 * a)
    return math.min(t1, t2)
end

function Maths:CutPath(path, length)
    local length = length or 0
    if length <= 0 then return path end
    local count, result = #path, {}
    for i = 1, count - 1 do
        local p1, p2 = path[i], path[i + 1]
        local distance = p1:Distance(p2)
        if distance >= length then
            local dir = (p2 - p1):Normalize()
            table.insert(result, p1 + dir * length)
            for j = i + 1, count do
                table.insert(result, path[j])
            end break
        end
        length = length - distance
    end
    return #result > 0 and result or {path[count]}
end

function Maths:PredictOnPath(unit, delay, hitbox)
    local path = Linq(unit.path.current_waypoints)
    local origin = Vector:New(unit.origin)
    if #path <= 1 then return origin end
    local speed = not unit.path.is_dashing and
        unit.move_speed or unit.path.dash_speed
    local threshold = speed * delay - hitbox
    return self:CutPath(path:Select(function(p)
        return Vector:New(p) end), threshold)[1]
end

function Maths:PredictCollision(unit, skillshot, buffer)
    local vela = skillshot.direction * skillshot.speed
    local waypoints = unit.path.current_waypoints
    local lifeTime = skillshot:TotalLifeTime()
    lifeTime = lifeTime - skillshot.preDelay
    local hitbox = unit.bounding_radius or 65
    local speed, total = unit.move_speed, 0
    local delay = speed * skillshot.preDelay
    local pos = skillshot.startPos:Clone()
    local origin = Vector:New(unit.origin)
    local path = Linq(waypoints):Select(
        function(p) return Vector:New(p) end)
    if #path == 0 then path[1] = origin end
    path = self:CutPath(path, delay)
    local startPos = pos:Clone()
    local count = #path
    for id = 1, count do
        local intime = total < lifeTime
        if id < count and intime or id == count then
            local p1, p2 = path[id], path[id + 1]
            if p2 == nil then p2 = p1:Clone() end
            local limit = p1:Distance(p2) / speed
            pos = id == count and startPos or pos
            local velb = (p2 - p1):Normalize() * speed
            if id == count then limit, total = 10, 0 end
            local time = self:CollisionTime(pos, p1, vela,
                velb, skillshot.radius + buffer, hitbox)
            -- validate collision time on a path segment
            local col = pos + vela * math.max(0, time or 0)
            local valid = time ~= nil and time <= limit
            if valid then return col, total + time end
            -- go on to the next segment
            pos = pos + vela * limit
            total = total + limit
        end
    end
    return nil, nil
end

---------------------------------
------------- Utils -------------

local Utils = Class()

function Utils:__init() end

function Utils:IsValid(unit)
    return unit and unit.is_valid and unit.is_visible
        and unit.is_alive and unit.is_targetable
end

function Utils:GetJungleMinions(range, pos)
    local pos = pos or Vector:New(myHero.origin)
    return Linq(game.jungle_minions):Where(function(m)
        return self:IsValid(m) and range * range >=
        Vector:New(m.origin):DistanceSquared(pos) end)
end

function Utils:GetLaneMinions(range, pos)
    local pos = pos or Vector:New(myHero.origin)
    return Linq(game.minions):Where(function(m) return
        self:IsValid(m) and m.is_enemy and Vector:New(
        m.origin):DistanceSquared(pos) <= range * range
        and m.champ_name:find("Minion") ~= nil end)
end

function Utils:GetMinions(range, pos)
    return self:GetJungleMinions(range, pos)
        :Concat(self:GetLaneMinions(range, pos))
end

---------------------------------
------------- Jayce -------------

local Jayce = Class()

function Jayce:__init()
    -- variables
    self.x = 0
    self.y = 0
    self.offsetX = 0
    self.offsetY = 0
    self.blockTimer = 0
    self.burstReqTimer = 0
    self.delayTimer = 0
    self.chargeTimer = 0
    self.comboMode = "Poke"
    self.hypercharged = false
    self.skillshot = nil
    self.damage = Damage:New()
    self.maths = Maths:New()
    self.utils = Utils:New()
    self.data = {['H'] = {}, ['C'] = {}}
    self.drag = {point = nil, process = false}
    self.enemies = Linq(game.players):Where(
        function(unit) return unit.is_enemy end)
    self.icons = os.getenv('APPDATA'):gsub("Roaming",
        "Local\\leaguesense\\spell_sprites\\")
    self.dataQ = {collision = {["Wall"] = true,
        ["Hero"] = false, ["Minion"] = false}, speed = 1450,
        range = 1050, delay = 0.2143, radius = 70,
        width = 140, type = "linear", castRate = "slow"}

    -- menu
    self.menu = menu:add_category_sprite("[Precision] Jayce", self.icons .. "Jayce.png")
    self.label1 = menu:add_label("Main", self.menu)
    self.switchKey = menu:add_keybinder("Combo Switch Key", self.menu, string.byte('A'))
    self.fleeKey = menu:add_keybinder("Flee Mode Key", self.menu, string.byte('Z'))
    self.hopKey = menu:add_keybinder("Wall Hop Key", self.menu, string.byte('C'))
    self.label2 = menu:add_label("Drawings", self.menu)
    self.rangeQ = menu:add_checkbox("Draw Q Range", self.menu, 1)
    self.predDmg = menu:add_checkbox("Draw Spell Damage", self.menu, 1)

    -- spell data and icons
    for _, slot in ipairs({'Q', 'W', 'E', 'R'}) do
        self.data['H'][slot] = {endTime = 0, sprite = nil}
        self.data['C'][slot] = {endTime = 0, sprite = nil}
    end
    self.names = {"JayceToTheSkies.png", "JayceStaticField.png",
        "JayceThunderingBlow.png", "JayceStanceHtG.png", "JayceShockBlast.png",
        "JayceHyperCharge.png", "JayceAccelerationGate.png", "JayceStanceGtH.png"}
    self.data['H']['Q'].sprite = renderer:add_sprite(self.icons .. self.names[1], 32, 32)
    self.data['H']['W'].sprite = renderer:add_sprite(self.icons .. self.names[2], 32, 32)
    self.data['H']['E'].sprite = renderer:add_sprite(self.icons .. self.names[3], 32, 32)
    self.data['H']['R'].sprite = renderer:add_sprite(self.icons .. self.names[4], 32, 32)
    self.data['C']['Q'].sprite = renderer:add_sprite(self.icons .. self.names[5], 32, 32)
    self.data['C']['W'].sprite = renderer:add_sprite(self.icons .. self.names[6], 32, 32)
    self.data['C']['E'].sprite = renderer:add_sprite(self.icons .. self.names[7], 32, 32)
    self.data['C']['R'].sprite = renderer:add_sprite(self.icons .. self.names[8], 32, 32)

    -- events
    _G.orbwalker:on_pre_attack(function(...) self:OnPreAttack(...) end)
    _G.orbwalker:on_post_attack(function(...) self:OnPostAttack(...) end)
    client:set_event_callback("on_tick", function() return self:OnTick() end)
    client:set_event_callback("on_draw", function() return self:OnDraw() end)
    client:set_event_callback("on_wnd_proc", function(...) return self:OnWndProc(...) end)
    client:set_event_callback("on_object_deleted", function(...) return self:OnObjectDeleted(...) end)
    client:set_event_callback("on_process_spell", function(...) return self:OnProcessSpell(...) end)
end

function Jayce:Converter(name)
    return ({
        ["JayceToTheSkies"] = {SLOT_Q, 'H', 'Q', 0},
        ["JayceStaticField"] = {SLOT_W, 'H', 'W', 0},
        ["JayceThunderingBlow"] = {SLOT_E, 'H', 'E', 0.25},
        ["JayceStanceHtG"] = {SLOT_R, 'H', 'R', 0},
        ["JayceShockBlast"] = {SLOT_Q, 'C', 'Q', 0.2143},
        ["JayceHyperCharge"] = {SLOT_W, 'C', 'W', 0},
        ["JayceAccelerationGate"] = {SLOT_E, 'C', 'E', 0},
        ["JayceStanceGtH"] = {SLOT_R, 'C', 'R', 0}
    })[name]
end

function Jayce:BlowLogic(ks)
    local heroPos = Vector:New(myHero.origin)
    local target = orbwalker:get_target(340)
    local eready = spellbook:can_cast(SLOT_E)
    local hammer = self:Stance() == "Hammer"
    if not (target and eready and hammer) then return end
    local pos = Vector:New(target.path.server_pos)
    local trueHealth = target.health + target.shield
    local damage = self.damage.jayce['E'](target, "Hammer")
    local canCast = not ks or ks and trueHealth <= damage
    if heroPos:Distance(pos) > 240 + target.bounding_radius +
        myHero.bounding_radius or not canCast then return end
    spellbook:cast_spell_targetted(SLOT_E, target, 0.25)
end

function Jayce:Stance()
    local slot = myHero:get_spell_slot(SLOT_W)
    local name = slot.spell_data.spell_name
    local hyper = name == "JayceHyperCharge"
    local caster = myHero.attack_range > 300
    return (hyper or caster) and "Cannon" or "Hammer"
end

function Jayce:OnPreAttack(args)
    if game.game_time - self.burstReqTimer < 0.05 and
        self.hypercharged then args.process = false end
end

function Jayce:OnPostAttack(target)
    if not target or not (target.is_hero
        or target.is_inhib or target.is_nexus
        or target.is_turret) then return end
    if self:Stance() ~= "Cannon" then return end
    if not spellbook:can_cast(SLOT_W) then return end
    client:delay_action(function()
        spellbook:cast_spell(SLOT_W)
        self.chargeTimer = game.game_time
        self.hypercharged = true end, 0)
end

function Jayce:OnWndProc(msg, wparam)
    local chat = game.is_chat_opened
    local shop = game.is_shop_opened
    if chat or shop or game.game_time - 0.25
        - self.delayTimer < 0 then return end
    -- combo mode switch
    local key = menu:get_value(self.switchKey)
    if game:is_key_down(key) and msg == 256 then
        self.comboMode = self.comboMode ==
            "Burst" and "Poke" or "Burst"
        self.delayTimer = game.game_time
    end
    -- drag bar with cooldowns
    local cursor = game.mouse_2d
    if not self.drag.process and
        msg == 513 and wparam == 1 and
        cursor.x >= self.x and cursor.y >=
        self.y and cursor.x <= self.x + 133
        and cursor.y <= self.y + 34 then
        self.drag.point = cursor
        self.drag.process = true
    elseif msg == 514 and wparam == 0 then
        self.drag.process = false
    end
end

function Jayce:OnObjectDeleted(obj)
    if self.skillshot ~= nil and
        obj.object_name:find("Jayce") and
        obj.object_name:find("_Q_range_xp")
        then self.skillshot = nil end
end

function Jayce:OnProcessSpell(unit, args)
    if unit.object_id ~= myHero.object_id or
        args.is_autoattack then return end
    local name = args.spell_name
    local isSpell = name:find("Jayce")
    if not isSpell then return end
    local data = self:Converter(name)
    local spell = myHero:get_spell_slot(data[1])
    client:delay_action(function()
        local cooldown = spell.cooldown - data[4]
        local endTime = game.game_time + cooldown
        local form, slot = data[2], data[3]
        local data = self.data[form][slot]
        data.endTime = endTime
    end, data[4])
end

function Jayce:OnTick()
    -- fix hyper charge spell cooldown
    local timer = game.game_time
    local buff = "JayceHyperCharge"
    local charged = myHero:has_buff(buff)
    if not self.hypercharged and charged then
        self.chargeTimer = timer
        self.hypercharged = true
    elseif self.hypercharged and not charged then
        local elapsed = timer - self.chargeTimer
        local endTime = self.data['C']['W'].endTime
        self.data['C']['W'].endTime = endTime + elapsed
        self.hypercharged = false
    end
    -- gather spell states and stance
    if myHero.is_dead then return end
    if evade:is_evading() then return end
    local heroPos = myHero.path.server_pos
    local heroPos = Vector:New(heroPos)
    local qready = spellbook:can_cast(SLOT_Q)
    local wready = spellbook:can_cast(SLOT_W)
    local eready = spellbook:can_cast(SLOT_E)
    local rready = spellbook:can_cast(SLOT_R)
    local stance = self:Stance()
    -- wall hop logic
    local key = menu:get_value(self.hopKey)
    if key and game:is_key_down(key) then
        local mousePos = Vector:New(game.mouse_pos)
        local minion = self.utils:GetJungleMinions(600):First(
            function(m) return math.deg(heroPos:AngleBetween(
            Vector:New(m.origin), mousePos, true)) < 60 end)
        if minion ~= nil and stance == "Hammer" and qready then
            spellbook:cast_spell_targetted(SLOT_Q, minion, 0.25)
        elseif minion == nil and stance == "Cannon" and eready then
            local direction = (mousePos - heroPos):Normalize()
            local pos = heroPos + direction * 100
            if nav_mesh:is_wall(pos.x, 64, pos.y) then
                local pos = heroPos + direction * 650
                spellbook:cast_spell(SLOT_E, 0.25,
                    pos.x, myHero.origin.y, pos.y) end
        elseif rready == true and (minion ~= nil and
            stance == "Cannon" or stance == "Hammer")
            then spellbook:cast_spell(SLOT_R) end
    end
    -- flee logic
    local key = menu:get_value(self.fleeKey)
    if key and game:is_key_down(key) then
        if eready == true then
            if stance == "Hammer" then self:BlowLogic()
            else spellbook:cast_spell(SLOT_E, 0.25,
                heroPos.x, myHero.origin.y, heroPos.y) end
        elseif rready then spellbook:cast_spell(SLOT_R) end
        if qready == true and stance == "Hammer" then
            local minions = self.utils:GetMinions(600)
            if #minions == 0 then return end
            table.sort(minions, function(a, b)
                local p1 = Vector:New(a.origin)
                local p2 = Vector:New(b.origin)
                return heroPos:DistanceSquared(p1) >
                    heroPos:DistanceSquared(p2) end)
            local pos = Vector:New(minions[1].origin)
            local mousePos = Vector:New(game.mouse_pos)
            local d1 = heroPos:DistanceSquared(pos)
            local d2 = mousePos:DistanceSquared(pos)
            if d1 < 90000 or d2 > 62500 then return end
            spellbook:cast_spell_targetted(
                SLOT_Q, minions[1], 0.25)
        end
    end
    -- combo logic
    local mode = combo:get_mode()
    if mode ~= MODE_COMBO then return end
    local attacking = myHero.is_auto_attacking
    if stance == "Cannon" then
        if eready and self.skillshot then
            self.skillshot:Update()
            local pos = self.skillshot.position
            local dir = self.skillshot.direction
            local castPos = pos + dir * 100
            if castPos:Distance(heroPos) <= 650 then
                spellbook:cast_spell(SLOT_E, 0.25, castPos.x,
                    myHero.origin.y or 65, castPos.y) end
        end
        local level = myHero:get_spell_slot(SLOT_Q).level
        local mana = 5 * math.max(1, math.min(6, level)) + 50
        local gated = eready and myHero.mana >= mana + 50
        self.dataQ.range = gated and 1600 or 1050
        local range = self.dataQ.range + 150
        local target = orbwalker:get_target(range)
        local elapsed = timer - self.blockTimer
        if qready and target and elapsed > 0.1 then
            if not gated and attacking then return end
            self.dataQ.speed = gated and 2350 or 1450
            self.dataQ.delay = 0.2143 + (gated and 0.034 or 0)
            local output = DreamPred.GetPrediction(target, self.dataQ, myHero)
            if output and output.castPosition and output.hitChance > 0.5 then
                local destPos = Vector:New(output.castPosition)
                local blastRadius = gated and 250 or 175
                self.skillshot = Line:New({arcStep = 10,
                    extraDuration = 0, preDelay = self.dataQ.delay,
                    radius = self.dataQ.radius, range = self.dataQ.range,
                    speed = self.dataQ.speed, fixedRange = true, hitbox = true,
                    startTime = timer, destPos = destPos, startPos = heroPos})
                local minions = self.utils:GetMinions(self.dataQ.range + 500)
                local col = self.maths:ClosestCollision(minions, self.skillshot)
                if not col or col and destPos:DistSqrToSegment(
                    heroPos, col) <= blastRadius * blastRadius then
                    local castPos = heroPos:Extend(destPos, 500)
                    spellbook:cast_spell(SLOT_Q, 0.25, castPos.x,
                        target.origin.y or 65, castPos.y)
                    self.blockTimer = timer return
                end self.skillshot = nil
            end
        end
        local elapsed = timer - self.blockTimer
        if elapsed <= 0.1025 then return end
        local range = myHero.attack_range + 150
        local target = orbwalker:get_target(range)
        if target and heroPos:Distance(Vector:New(target.origin))
            <= myHero.bounding_radius + target.bounding_radius
            + 125 then spellbook:cast_spell(SLOT_R) return end
        if self.comboMode ~= "Burst" then return end
        self.burstReqTimer = timer
        local target = orbwalker:get_target(600)
        local endTime = self.data['H']['Q'].endTime
        if target and myHero.mana >= 40 and not wready
            and rready and timer >= endTime then
            spellbook:cast_spell(SLOT_R) end
    elseif stance == "Hammer" then
        if attacking == true then return end
        if qready and self.comboMode == "Burst" then
            local target = orbwalker:get_target(600) or nil
            if target then spellbook:cast_spell_targetted(
                SLOT_Q, target, 0.25) return end
        end
        local target = wready and orbwalker:get_target(350)
        if target then spellbook:cast_spell(SLOT_W) end
        if eready == true then self:BlowLogic(true) end
        local target = orbwalker:get_target(125 + 65 + 65)
        if not target and rready then spellbook:cast_spell(SLOT_R) end
    end
end

function Jayce:OnDraw()
    local stance = self:Stance()
    local qready = spellbook:can_cast(SLOT_Q)
    local wready = spellbook:can_cast(SLOT_W)
    local eready = spellbook:can_cast(SLOT_E)
    local heroPos = Vector:New(myHero.origin)
    -- draw damage over enemy hp bar
    if menu:get_value(self.predDmg) == 1 then
        self.enemies:ForEach(function(unit) local amount = 0
            if not self.utils:IsValid(unit) then return end
            if qready == true then amount = amount +
                self.damage.jayce['Q'](unit, stance) end
            if wready == true then amount = amount +
                self.damage.jayce['W'](unit, stance) end
            if eready == true then amount = amount +
                self.damage.jayce['E'](unit, stance) end
            unit:draw_damage_health_bar(amount)
        end)
    end
    -- draw combo mode
    local heroPos = myHero.origin
    local pos = game:world_to_screen(
        heroPos.x, heroPos.y, heroPos.z)
    renderer:draw_text_centered(
        pos.x, pos.y + 25, "Combo Mode: " ..
        self.comboMode, 255, 255, 255, 255)
    -- draw spell range
    if menu:get_value(self.rangeQ) == 1 then
        local r, g, b = 255, 204, 0
        local cannon = stance == "Cannon"
        if cannon then r, g, b = 102, 255, 255 end
        renderer:draw_circle(heroPos.x, heroPos.y,
            heroPos.z, cannon and eready and 1600 or
            cannon and 1050 or 600, r, g, b, 192)
    end
    -- draw spell cooldowns
    if self.drag.process then
        local cursor = game.mouse_2d
        local previous = self.drag.point
        local x = cursor.x - previous.x
        local y = cursor.y - previous.y
        self.drag.point = cursor
        self.offsetX = self.offsetX + x
        self.offsetY = self.offsetY + y
    end
    local offset = 1
    local pos = myHero.health_bar.pos
    self.x = pos.x + self.offsetX - 70
    self.y = pos.y + self.offsetY - 65
    renderer:draw_rect_fill(self.x,
        self.y, self.x + 133, self.y,
        self.x, self.y + 34, self.x + 133,
        self.y + 34, 16, 16, 16, 192)
    local range = myHero.attack_range
    local oppos = range < 300 and 'C' or 'H'
    local data = self.data[oppos] or {}
    local slots = {'Q', 'W', 'E', 'R'}
    for _, slot in ipairs(slots) do
        local endTime = data[slot].endTime
        local sprite = data[slot].sprite
        local cooldown = endTime - game.game_time
        local x, y = self.x + offset, self.y + 1
        sprite:draw(x, y); offset = offset + 33
        if cooldown > 0 then
            renderer:draw_text_centered(x + 16,
                y - 16, string.format("%0.1f",
                cooldown), 255, 255, 255, 224)
        end
    end
end

--------------------------
-------- Karthus ---------

local Karthus = Class()

function Karthus:__init()
    -- variables
    self.blockTimer = 0
    self.delayTimer = 0
    self.farmMode = "Eco"
    self.shouldWait = false
    self.damage = Damage:New()
    self.maths = Maths:New()
    self.utils = Utils:New()
    self.enemies = Linq(game.players):Where(
        function(unit) return unit.is_enemy end)
    self.icons = os.getenv('APPDATA'):gsub("Roaming",
        "Local\\leaguesense\\spell_sprites\\")  
    self.dataQ = {collision = {["Wall"] = false,
        ["Hero"] = false, ["Minion"] = false},
        speed = math.huge, range = 875,
        delay = 1, radius = 200, width = 400,
        type = "circular", castRate = "very slow"}
    self.dataW = {range = 1000, radius = 20}
    self.dataE = {range = 550}

    -- menu
    self.menu = menu:add_category_sprite("[Precision] Karthus", self.icons .. "Karthus.png")
    self.label1 = menu:add_label("Main", self.menu)
    self.fleeKey = menu:add_keybinder("Flee Mode Key", self.menu, string.byte('Z'))
    self.switchKey = menu:add_keybinder("Farm Mode Switch", self.menu, string.byte('A'))
    self.label2 = menu:add_label("Drawings", self.menu)
    self.rangeQ = menu:add_checkbox("Draw Q Range", self.menu, 1)
    self.rangeW = menu:add_checkbox("Draw W Range", self.menu, 1)
    self.rangeE = menu:add_checkbox("Draw E Range", self.menu, 1)
    self.killable = menu:add_checkbox("Draw R Killable", self.menu, 1)
    self.predDmg = menu:add_checkbox("Draw Q & R Damage", self.menu, 1)

    -- events
    _G.orbwalker:on_pre_attack(function(...) self:OnPreAttack(...) end)
    _G.orbwalker:on_unkillable_minion(function(...) self:OnUnkillableMinion(...) end)
    client:set_event_callback("on_tick", function() return self:OnTick() end)
    client:set_event_callback("on_draw", function() return self:OnDraw() end)
    client:set_event_callback("on_new_path", function(...) return self:OnNewPath(...) end)
    client:set_event_callback("on_wnd_proc", function(...) return self:OnWndProc(...) end)
end

function Karthus:ToggleAura()
    if not spellbook:can_cast(SLOT_E) then return end
    local elapsed = game.game_time - self.blockTimer
    if elapsed <= 0.1 then return end
    self.blockTimer = game.game_time
    spellbook:cast_spell(SLOT_E)
end

function Karthus:IsUsingAura()
    return myHero:has_buff("KarthusDefile")
end

function Karthus:OnPreAttack(args)
    local mode = combo:get_mode()
    local book = spellbook:get_spell_slot(0)
    local ready = spellbook:can_cast(SLOT_Q)
    local level = ready and book.level or 1
    local qmana = ({20, 25, 30, 35, 40})[level]
    if myHero.mana < qmana then return end
    if not (mode == MODE_COMBO and args.target or
        mode == MODE_LANECLEAR and self.shouldWait
        and self.farmMode ~= "Eco") then return end
    local elapsed = game.game_time - self.blockTimer
    if elapsed <= 0.1 then return end
    args.process = false
end

function Karthus:OnUnkillableMinion(minion)
    local pos, latency = minion.origin, game.ping / 2000
    if not spellbook:can_cast(SLOT_Q) then return end
    local startTime = orbwalker:get_auto_attack_timer()
    local windup = orbwalker:get_windup_time() + latency
    local cooldown = startTime + windup - game.game_time
    if cooldown > 0 then client:delay_action(function()
        self:OnUnkillableMinion(minion) end, cooldown) end
    local pred = orbwalker:get_health_prediction(minion, 0.78)
    local damage = self.damage.karthus['Q'](minion) - 1.0
    if not pos or pred < 0 or damage < pred then return end
    self.blockTimer = game.game_time + latency + 0.034
    spellbook:cast_spell(SLOT_Q, 0.3, pos.x, pos.y, pos.z)
    orbwalker:exclude_minion(minion)
end

function Karthus:OnTick()
    local mode = combo:get_mode()
    local aura = self:IsUsingAura()
    local latency = game.ping / 1000
    local qrange = self.dataQ.range
    local qready = spellbook:can_cast(SLOT_Q)
    local wready = spellbook:can_cast(SLOT_W)
    local eready = spellbook:can_cast(SLOT_E)
    local rready = spellbook:can_cast(SLOT_R)
    local heroPos = Vector:New(myHero.origin)
    -- turn off aura if no enemies nearby
    local minionsQ = self.utils:GetMinions(qrange)
    local minionsE = minionsQ:Where(function(minion)
        local pos = Vector:New(minion.origin)
        local dist = pos:DistanceSquared(heroPos)
        return dist <= self.dataE.range ^ 2 end)
    local minionsE = self.utils:GetMinions(self.dataE.range)
    local target = orbwalker:get_target(self.dataE.range)
    local nounits = #minionsE == 0 and target == nil
    if aura and nounits then self:ToggleAura() end
    if myHero.is_auto_attacking then return end
    if evade:is_evading() then return end
    -- combo mode
    if mode == MODE_COMBO then
        local toggle = (aura and 1 or 0) ~ (target and 1 or 0)
        if toggle == 1 then self:ToggleAura() end
        local range = self.dataQ.range + 200
        local target = orbwalker:get_target(range)
        if target ~= nil and qready == true then
            local output = DreamPred.GetPrediction(target, self.dataQ, myHero)
            if output and output.castPosition and output.hitChance >= 1 then
                local pos, y = output.castPosition, target.origin.y
                spellbook:cast_spell(SLOT_Q, 0.3, pos.x, y, pos.z)
            end
        end
        local enemy = wready and self.enemies:First(
            function(unit) return self.utils:IsValid(unit)
            and Vector:New(unit.origin):DistanceSquared(
            Vector:New(game.mouse_pos)) <= 100 * 100 end)
        if enemy ~= nil and enemy ~= false then
            local pos, y = Vector:New(enemy.origin), enemy.origin.y
            spellbook:cast_spell(SLOT_W, 0.3, pos.x, y, pos.y)
        end
    end
    -- jungle clear mode
    if mode ~= MODE_LANECLEAR then return end
    if game.game_time - self.blockTimer < 1.2 then return end
    local minions = minionsQ:Where(function(minion) return
        not minion.champ_name:find("Minion") end):Select(
        function(minion) return self.maths:PredictOnPath(minion,
            self.dataQ.delay + 0.25, self.dataQ.radius) end)
    if qready and #minions > 0 then
        local aoe, y = self.maths:CalcAOEPosition(
            minions, self.dataQ.radius), myHero.origin.y
        spellbook:cast_spell(SLOT_Q, 0.3, aoe.x, y, aoe.y)
        self.blockTimer = game.game_time return
    end
    -- lane clear mode
    local eco, y = self.farmMode == "Eco", myHero.origin.y
    if eco or not qready then self.shouldWait = false return end
    local attackDamage = myHero.total_attack_damage
    local minions = minionsQ:Where(function(minion)
        return minion.champ_name:find("Minion") and
        not orbwalker:is_about_to_kill(minion) end):Select(
        function(minion) local damage = self.damage.karthus['Q'](minion)
        local healthPred = orbwalker:get_health_prediction(minion, 0.78)
        local clearPred = orbwalker:get_lane_clear_health_prediction(minion, 2.55)
        return {damage = damage, healthPred = healthPred, clearPred = clearPred,
            minion = minion, pos = self.maths:PredictOnPath(minion, latency + 0.1
            + self.dataQ.delay, self.dataQ.radius), id = minion.object_id} end)
    table.sort(minions, function(a, b) return a.clearPred < b.clearPred end)
    minions:ForEach(function(data) data.damage =
        data.damage * (minions:Any(function(dt) return
        dt ~= data and dt.pos:DistanceSquared(data.pos) <=
        self.dataQ.radius ^ 2 + 10000 end) and 1 or 2) end)
    local targets = minions:Where(function(dt) return
        dt.healthPred > 0 and dt.damage >= dt.healthPred end)
    local starTarget = #targets > 0 and targets[1].pos or nil
    local pos = self.maths:CalcAOEPosition(targets:Select(
        "(dt) => dt.pos"), self.dataQ.radius, starTarget)
    if pos and not eco and minions:Except(targets):Any(
        function(dt) local dist = dt.pos:DistanceSquared(pos)
        return dt.clearPred <= dt.damage + attackDamage and
        dt.pos:DistanceSquared(pos) <= self.dataQ.radius ^ 2
        end) then self.shouldWait = false return end
    self.shouldWait = minions:Any(function(dt) return
        dt.clearPred <= dt.damage and dt.healthPred > 0 end)
    if pos ~= nil then targets:Where(function(dt) return
        dt.pos:DistanceSquared(pos) <= self.dataQ.radius ^ 2 end)
        :ForEach(function(dt) orbwalker:exclude_minion(dt.minion) end)
        spellbook:cast_spell(SLOT_Q, 0.3, pos.x, y, pos.y)
        self.blockTimer = game.game_time return end
    if self.farmMode ~= "Push" or self.shouldWait then return end
    local pos = #minions > 0 and self.maths:CalcAOEPosition(
        minions:Select("(dt) => dt.pos"), self.dataQ.radius)
    if not pos then self.shouldWait = false return end
    spellbook:cast_spell(SLOT_Q, 0.3, pos.x, y, pos.y)
    self.blockTimer, self.shouldWait = game.game_time, true
end

function Karthus:OnDraw()
    local pos = myHero.origin
    local qready = spellbook:can_cast(SLOT_Q)
    local rready = spellbook:can_cast(SLOT_R)
    -- draw damage over enemy hp bar and
    -- draw lines on killable targets
    self.enemies:ForEach(function(unit)
        local valid = self.utils:IsValid(unit)
        if not valid then return end
        local rdmg, shield = not rready and 0
            or self.damage.karthus['R'](unit),
            unit.magic_shield + unit.shield
        if menu:get_value(self.predDmg) == 1 then
            local qdmg, amount = not qready and 0
                or self.damage.karthus['Q'](unit), 0
            if qready then amount = amount + qdmg end
            if rready then amount = amount + rdmg end
            unit:draw_damage_health_bar(amount)
        end
        if menu:get_value(self.killable) == 1 and
            rready and rdmg >= unit.health + shield then
            local origin, y = unit.origin, unit.origin.y
            local a = game:world_to_screen_2(pos.x, y, pos.z)
            local b = game:world_to_screen_2(origin.x, y, origin.z)
            renderer:draw_line(a.x, a.y, b.x, b.y, 10, 153, 255, 255, 128)
        end
    end)
    -- draw spell range
    if menu:get_value(self.rangeQ) == 1 then
        renderer:draw_circle(pos.x, pos.y, pos.z,
            self.dataQ.range, 102, 255, 204, 192)
    end
    if menu:get_value(self.rangeW) == 1 then
        renderer:draw_circle(pos.x, pos.y, pos.z,
            self.dataW.range, 102, 255, 255, 192)
    end
    if menu:get_value(self.rangeE) == 1 then
        renderer:draw_circle(pos.x, pos.y, pos.z,
            self.dataE.range, 51, 204, 204, 192)
    end
    -- draw farm mode
    local screen = game:world_to_screen(pos.x, pos.y, pos.z)
    renderer:draw_text_centered(screen.x, screen.y + 25,
        "Farm Mode: " .. self.farmMode, 255, 255, 255, 255)
end

function Karthus:OnNewPath(unit, path)
    local y = unit.origin.y or 100
    if not unit.is_enemy then return end
    if evade:is_evading() then return end
    local dashing = unit.path.is_dashing
    local heroPos = Vector:New(myHero.origin)
    local wready = spellbook:can_cast(SLOT_W)
    if dashing and wready == true then
        local pos = Vector:New(path[#path])
        local dist = heroPos:DistanceSquared(pos)
        if dist > self.dataW.range ^ 2 then return end
        spellbook:cast_spell(SLOT_W, 0.2, pos.x, y, pos.y)
        self.blockTimer = game.game_time return
    end
    local range = self.dataQ.range + 200
    local qready = spellbook:can_cast(SLOT_Q)
    local combo = combo:get_mode() == MODE_COMBO
    if not qready or not combo then return end
    local target = orbwalker:get_target(range)
    if target ~= unit then return end
    local delay = self.dataQ.delay
    local latency = game.ping / 1000 + 0.07
    local pos = self.maths:PredictOnPath(unit,
        delay + latency, self.dataQ.radius)
    local range = heroPos:DistanceSquared(pos)
    if range > self.dataQ.range ^ 2 then return end
    spellbook:cast_spell(SLOT_Q, 0.2, pos.x, y, pos.y)
end

function Karthus:OnWndProc(msg, wparam)
    -- farm mode switch
    local chat = game.is_chat_opened
    local shop = game.is_shop_opened
    if chat or shop or game.game_time - 0.25
        - self.delayTimer < 0 then return end
    local key = menu:get_value(self.switchKey)
    if game:is_key_down(key) and msg == 256 then
        local nextMode = ({["Eco"] = "Balanced",
            ["Balanced"] = "Push", ["Push"] = "Eco"})
        self.farmMode = nextMode[self.farmMode]
        self.delayTimer = game.game_time
    end
end

local update = AutoUpdate()
if update == true then return end

local charName = myHero.champ_name
if charName == "Jayce" then Jayce:New() end
if charName == "Karthus" then Karthus:New() end
