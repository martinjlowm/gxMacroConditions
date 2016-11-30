gxMacroConditions = DongleStub('Dongle-1.0'):New("gxMacroConditions")

function gxMacroConditions:Initialize()
    self.casting = nil
    self.channeling = nil

    self:RegisterEvent('SPELLCAST_START')
    self:RegisterEvent('SPELLCAST_CHANNEL_START')
    self:RegisterEvent('SPELLCAST_STOP')
    self:RegisterEvent('SPELLCAST_CHANNEL_STOP')
end

function gxMacroConditions:SPELLCAST_START()
    self.casting = arg1
end

function gxMacroConditions:SPELLCAST_CHANNEL_START()
    self.channeling = arg1
end

function gxMacroConditions:SPELLCAST_STOP()
    self.casting = false
end

function gxMacroConditions:SPELLCAST_CHANNEL_STOP()
    self.channeling = false
end

local conditions_map, casting, existence, hostility
do
    local function IsChanneling(dependency)
        return dependency and dependency == gxMacroConditions.channeling or gxMacroConditions.channeling
    end

    local function IsCasting(dependency)
        return dependency and dependency == gxMacroConditions.casting or gxMacroConditions.casting
    end

    local function IsMouseOverUnit()
        local is_mouseover = false

        is_mouseover = UnitName('mouseover') and 'mouseover'

        local frame = GetMouseFocus()
        is_mouseover = is_mouseover or frame and frame.unit

        return is_mouseover
    end

    casting = {
        ['channeling'] = IsChanneling,
        ['nochanneling'] = function(dependency)
            return not IsChanneling(dependency)
        end,
        ['casting'] = IsCasting,
        ['nocasting'] = function(dependency)
            return not IsCasting(dependency)
        end,
    }

    existence = {
        ['exists'] = UnitExists,
        ['noexists'] = function(unit)
            return not UnitExists(unit)
        end,
        ['dead'] = UnitIsDead,
        ['nodead'] = function(unit)
            return not UnitIsDead(unit)
        end,
    }


    hostility = {
        ['harm'] = UnitIsEnemy,
        ['nohelp'] = UnitIsEnemy,
        ['help'] = UnitIsFriend,
        ['noharm'] = UnitIsFriend
    }


    conditions_map = {
        -- Targets
        ['mouseover'] = IsMouseOverUnit,

        ['pet'] = HasPetUI,
        ['nopet'] = function() return not HasPetUI() end,

        ['party'] = UnitInParty,
        ['raid'] = UnitInRaid,

        ['combat'] = UnitAffectingCombat,

        -- ['mounted'] = IsMounted,
        -- ['indoors'] = IsIndoors,
        -- ['outdoors'] = IsOutdoors,
        -- ['stealth'] = IsStealthed,
        -- ['swimming'] = IsSwimming,

        -- Modifiers
        ['shift'] = IsShiftKeyDown,
        ['ctrl'] = IsControlKeyDown,
        ['alt'] = IsAltKeyDown
    }

    for k, v in next, casting do conditions_map[k] = v end
    for k, v in next, existence do conditions_map[k] = v end
    for k, v in next, hostility do conditions_map[k] = v end
end
-- button, btn - If you clicked a particular button to cast the spell (button:#, where #=1-5, LeftButton, RightButton, MiddleButton, Button4, or Button5).
-- WORKS(?): channeling - If you are channeling a spell. You may optionally specify a specific spell using spell:spellname.
-- WORKS: combat - If you are in combat.
-- WORKS: dead - If the target is dead.
-- equipped, worn - If you are currently equipping a specific item, item of a particular class or subclass, or have an item in a particular slot. (ex. equipped:item, see below for details).
-- WORKS: exists - If the target exists (case insensitive).
-- NOT_AVAIL: flyable - If you are in an area where flying is allowed.
-- NOT_AVAIL: flying - If you are flying.
-- group - If you are in a group. You may optionally specify group:party or group:raid.
-- WORKS: harm, nohelp - If target is hostile.
-- WORKS: help, noharm - If target is friendly.
-- TODO: indoors - If your are indoors (anywhere you cannot mount is considered indoors).
-- modifier, mod - If the click is modified with shift, ctrl, or alt. You may optionally specify which one by using modifier:key (key=shift, ctrl, or alt). -- "key=..." doesn't seem to work; use "mod" keyword for ctrl and alt. When using shift, the change actionbar function overrides this for numbers 1-6.
-- TODO: mounted - If you are mounted.
-- TODO: outdoors - You are outdoors (anywhere you can mount is considered outdoors).
-- party - If the target is in your party.
-- WORKS PARTLY: pet - If your pet exists. You may optionally specify a type of pet (pet:type, where type=cat,boar,ravager,etc...)
-- WORKS PARTLY: raid - If the target is in your raid.
-- stance, form - If you are in a particular stance. May also use stance:# to specify a particular stance (#=stance number).
-- spec - If you are using the specified talent specialization (spec:1 or spec:2).
-- talent<row>/<col> - If you are using the specified talent (talent:1/1 to talent:6/3).
-- WORKS: stealth - If you are stealthed.
-- WORKS: swimming - If you are swimming.
-- WORKS: target=UnitId, @UnitId - Casts on a specific target without changing your current target (see table below).
-- NOT_AVAIL: unithasvehicleui - If the target of the macro has a vehicle UI.
-- NOT_AVAIL: vehicleui - If the player has a vehicle UI.

function gxMacroConditions:CastSpellByName(action, target)
    if target then
        local has_target = UnitName('target')

        TargetUnit(target)
        CastSpellByName(action)
        if has_target then
            TargetLastTarget()
        else
            ClearTarget()
        end
    else
        CastSpellByName(action)
    end
end

function gxMacroConditions:ParseCommand(command, input)
    -- /action [conditions]
    local action, conditions

    -- Accumulating condition
    local acc_condition

    -- Condition-mapped function and dependency argument
    local func, dependency

    -- [@target]
    local target, is_cond_target

    if not string.find(input, ';') then
        input = input .. ' ;'
    end

    -- Iterate condition cases
    for _, cases in { string.split(';', input) } do
        conditions, action = string.match(cases, '%[([^%]]+)%]%s*(.+)')

        -- Does the action have any conditions?
        if conditions then
            conditions = { string.split(',', conditions) }
            acc_condition = false
            target = nil
            for _, cond in conditions do
                cond, dependency = string.split(':', string.trim(cond))

                -- Is the current condition a target command? Usually the first
                -- condition is
                is_cond_target =
                    string.match(cond, '@(.*)') or
                    string.match(cond, 'target=(.*)')

                -- Mouseover has a special condition, since unitframes don't
                -- utilise the mouseover unit, in which case it's mapped to
                -- player, target, partyN etc.
                func = conditions_map[is_cond_target or cond]

                if is_cond_target then
                    target = func and func() or is_cond_target
                else
                    local res

                    if hostility[cond] then
                        res = func and func('player', target or 'target')
                    elseif existence[cond] then
                        res = func and func(target or 'target')
                    elseif cond == 'combat' then
                        res = func and func('player')
                    elseif casting[cond] then
                        res = func and func(dependency)
                    else
                        res = func and func()
                    end

                    acc_condition = acc_condition or res
                end
            end

            -- Are all conditions met? Then perform that action
            if acc_condition then
                self:PerformAction(command, string.trim(action), target)
                return
            end
        else
            local cases = string.trim(cases)
            -- Fall back to an unconditional action
            self:PerformAction(command, cases)
            return
        end
    end
end

function gxMacroConditions:PerformAction(command, ...)
    if command == 'cast' then
        local action, target = unpack(arg)
        if target then
            self:CastSpellByName(action, target)
        else
            self:CastSpellByName(action)
        end
    elseif command == 'use' then
        local action = unpack(arg)
        local bag_id, bag_slot = string.split(' ', action)

        if not bag_slot then
            UseInventoryItem(tonumber(bag_id))
        else
            UseContainerItem(tonumber(bag_id), tonumber(bag_slot), true)
        end
    elseif command == 'cleartarget' then
        ClearTarget()
    elseif command == 'mount' then
        local func = SlashCmdList["MOUNT"]
        if func then
            func()
        end
    end
end

local CastFunction = SlashCmdList["CAST"]
SlashCmdList["CAST"] = function(input)
    gxMacroConditions:ParseCommand('cast', input)
end

SLASH_USE1 = '/use'
SlashCmdList["USE"] = function(input)
    gxMacroConditions:ParseCommand('use', input)
end

SLASH_CLEARTARGET1 = '/cleartarget'
SlashCmdList["CLEARTARGET"] = function(input)
    gxMacroConditions:ParseCommand('cleartarget', input)
end

SLASH_TARGETENEMY1 = '/targetenemy'
SlashCmdList["TARGETENEMY"] = function(input)
    gxMacroConditions:ParseCommand('targetenemy', input)
end
