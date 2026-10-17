local PlayerInjuries = {}
local PlayerWeaponWounds = {}
local QBCore = exports['qb-core']:GetCoreObject()
local doctorCount = 0
local doctorCalled = false
local Doctors = {}

local RegisteredStashes = {}
local OccupiedBeds = {}
local TreatmentSessions = {}

local function Notify(src, message, messageType)
    TriggerClientEvent('QBCore:Notify', src, message, messageType or 'primary')
end

local function IsEMS(src, requireDuty)
    local player = QBCore.Functions.GetPlayer(src)
    if not player or player.PlayerData.job.name ~= 'ambulance' then return false end
    return not requireDuty or player.PlayerData.job.onduty == true
end

local function IsPlayerNear(src, targetId, maxDistance)
    src = tonumber(src)
    targetId = tonumber(targetId)
    if not src or not targetId or src == targetId then return false end

    local sourcePed = GetPlayerPed(src)
    local targetPed = GetPlayerPed(targetId)
    if sourcePed == 0 or targetPed == 0 then return false end

    return #(GetEntityCoords(sourcePed) - GetEntityCoords(targetPed)) <= (maxDistance or 5.0)
end

local function GetPlayerInteractionDistance(treatmentType)
    for _, interaction in pairs(Config.Interactions.Players or {}) do
        if interaction.treatmentType == treatmentType then
            return interaction.distance or Config.Interactions.Defaults.playerDistance
        end
    end

    return Config.Interactions.Defaults.playerDistance
end

local function GetTreatmentDistance(treatmentType)
    return GetPlayerInteractionDistance(treatmentType)
end

local function GetMaximumPlayerInteractionDistance()
    local maximum = Config.Interactions.Defaults.playerDistance

    for _, interaction in pairs(Config.Interactions.Players or {}) do
        maximum = math.max(maximum, interaction.distance or maximum)
    end

    return maximum
end

local function IsNearCoords(src, coords, maxDistance)
    local ped = GetPlayerPed(tonumber(src) or 0)
    if ped == 0 or not coords then return false end

    local playerCoords = GetEntityCoords(ped)
    local targetCoords = vector3(coords.x, coords.y, coords.z)
    return #(playerCoords - targetCoords) <= (maxDistance or 5.0)
end

local function IsNearAnyCheckIn(src, maxDistance)
    for _, coords in pairs(Config.Locations.checking) do
        if IsNearCoords(src, coords, maxDistance) then return true end
    end

    return false
end

local function BeginTreatmentSession(src, targetId, treatmentType, duration)
    TreatmentSessions[src] = {
        targetId = targetId,
        treatmentType = treatmentType,
        completesAt = GetGameTimer() + math.max(duration - 750, 250),
    }
end

local function ConsumeTreatmentSession(src, targetId, treatmentType)
    local session = TreatmentSessions[src]
    if not session then return false end

    local valid = session.targetId == tonumber(targetId)
        and session.treatmentType == treatmentType
        and GetGameTimer() >= session.completesAt

    if valid then
        TreatmentSessions[src] = nil
    end

    return valid
end

local function HasItem(src, itemName, amount)
    amount = amount or 1

    if Config.Inventory == 'ox_inventory' and GetResourceState('ox_inventory') == 'started' then
        return (exports.ox_inventory:Search(src, 'count', itemName) or 0) >= amount
    end

    local player = QBCore.Functions.GetPlayer(src)
    local item = player and player.Functions.GetItemByName(itemName)
    return item and item.amount >= amount or false
end

-- Looping bandage audio is sent to the person using the bandage and players
-- within the configured hearing distance. Unlike interact-sound's one-shot
-- event, our resource NUI audio can be stopped on progress completion/cancel.
local activeBandageLoops = {}
local bandageLoopSequence = 0

local function StopBandageLoop(src)
    src = tonumber(src)
    if not src then return end
    local session = activeBandageLoops[src]
    if not session then return end
    activeBandageLoops[src] = nil

    -- Stop on EXACTLY the clients that heard this session, including anyone
    -- who moved away while bandaging was in progress.
    for targetId in pairs(session.listeners) do
        TriggerClientEvent('hospital:client:StopBandageLoop', targetId, src, session.token)
    end
end

local function StartBandageLoop(src, route)
    src = tonumber(src)
    if not src or activeBandageLoops[src] then return end
    local integration = Config.InteractSound
    if type(integration) ~= 'table' or integration.Enabled == false then return end
    local sound = integration.Bandage
    if type(sound) ~= 'table' or sound.Enabled == false then return end

    local resourceName = integration.Resource or 'interact-sound'
    if GetResourceState(resourceName) ~= 'started' then return end

    local sourcePed = GetPlayerPed(src)
    if sourcePed == 0 then return end

    local radius = math.max(0.5, math.min(tonumber(sound.Distance) or 5.0, 50.0))
    local volume = math.max(0.0, math.min(tonumber(sound.Volume) or 0.35, 1.0))
    local soundName = tostring(sound.Name or 'bandage'):gsub('%.ogg$', '')
    local duration = math.max(500, math.min(tonumber(sound.Duration) or
        (Config.BandageAnimation and tonumber(Config.BandageAnimation.Duration)) or 4000, 30000))
    local delay = math.max(0, math.min(tonumber(sound.StartDelay) or 0, 2000))

    bandageLoopSequence = bandageLoopSequence + 1
    local token = ('%s:%s'):format(src, bandageLoopSequence)
    local session = { token = token, listeners = {} }
    activeBandageLoops[src] = session

    if integration.Debug then
        print(('[qb-ambulancejob] Bandage loop start: player %d, route %s, %dms'):
            format(src, route or 'unknown', duration))
    end

    local function BroadcastStart()
        if activeBandageLoops[src] ~= session then return end
        local ped = GetPlayerPed(src)
        if ped == 0 then
            StopBandageLoop(src)
            return
        end
        local origin = GetEntityCoords(ped)
        for _, playerId in ipairs(GetPlayers()) do
            local targetId = tonumber(playerId)
            local targetPed = targetId and GetPlayerPed(targetId) or 0
            if targetPed ~= 0 and (targetId == src or
                (sound.Nearby ~= false and #(GetEntityCoords(targetPed) - origin) <= radius)) then
                session.listeners[targetId] = true
                TriggerClientEvent('hospital:client:StartBandageLoop', targetId,
                    src, session.token, soundName, volume, resourceName, duration)
            end
        end
    end

    if delay == 0 then
        BroadcastStart()
    else
        SetTimeout(delay, BroadcastStart)
    end

    -- Failsafe: if a progress callback fails (disconnect, broken animation,
    -- external progress bar, etc.), nobody hears an endless loop.
    SetTimeout(duration + delay + 2500, function()
        if activeBandageLoops[src] == session then
            StopBandageLoop(src)
        end
    end)
end

-- QBCore/ox_inventory bridge entrypoint; validate that the item exists.
RegisterNetEvent('hospital:server:RequestSelfBandageSound', function()
    local src = source
    if not HasItem(src, 'bandage', 1) then return end
    StartBandageLoop(src, 'self-use')
end)

-- Only on-duty EMS players can trigger treatment bandage audio.
RegisterNetEvent('hospital:server:RequestTreatBandageSound', function()
    local src = source
    if not IsEMS(src, true) or not HasItem(src, Config.TreatmentItems.Treat, 1) then return end
    StartBandageLoop(src, 'ems-treat')
end)

-- Ownership is implicit: source comes from the server event, never the client.
RegisterNetEvent('hospital:server:StopBandageSound', function()
    StopBandageLoop(source)
end)

AddEventHandler('playerDropped', function()
    StopBandageLoop(source)
end)

local function RemoveItem(src, itemName, amount)
    amount = amount or 1

    if Config.Inventory == 'ox_inventory' and GetResourceState('ox_inventory') == 'started' then
        return exports.ox_inventory:RemoveItem(src, itemName, amount)
    end

    local player = QBCore.Functions.GetPlayer(src)
    return player and player.Functions.RemoveItem(itemName, amount) or false
end

local function ClearPlayerInventory(src, player)
    if Config.Inventory == 'ox_inventory' and GetResourceState('ox_inventory') == 'started' then
        exports.ox_inventory:ClearInventory(src)
        return
    end

    player.Functions.ClearInventory()
    MySQL.update('UPDATE players SET inventory = ? WHERE citizenid = ?', { json.encode({}), player.PlayerData.citizenid })
end

local function RegisterHospitalShop()
    if Config.Inventory ~= 'ox_inventory' or GetResourceState('ox_inventory') ~= 'started' then return end

    local inventory = {}
    for _, item in pairs(Config.Items.items) do
        inventory[#inventory + 1] = {
            name = item.name,
            price = item.price or 0,
            count = item.amount or 50,
            metadata = item.info,
        }
    end

    pcall(function()
        exports.ox_inventory:RegisterShop('hospital', {
            name = Config.Items.label or 'Medical Supplies',
            inventory = inventory,
            groups = { ambulance = 0 },
        })
    end)
end

CreateThread(function()
    Wait(1000)
    RegisterHospitalShop()
end)

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName == 'ox_inventory' then
        Wait(1000)
        RegisterHospitalShop()
    end
end)


-- Events

-- Compatibility with txAdmin Menu's heal options.
-- This is an admin only server side event that will pass the target player id or -1.
AddEventHandler('txAdmin:events:healedPlayer', function(eventData)
	if GetInvokingResource() ~= "monitor" or type(eventData) ~= "table" or type(eventData.id) ~= "number" then
		return
	end

	TriggerClientEvent('hospital:client:Revive', eventData.id)
	TriggerClientEvent("hospital:client:HealInjuries", eventData.id, "full")
end)

RegisterNetEvent('hospital:server:SendToBed', function(bedId, isRevive)
    local src = source
    local player = QBCore.Functions.GetPlayer(src)
    bedId = tonumber(bedId)

    if not player or not bedId or not Config.Locations.beds[bedId] or OccupiedBeds[src] then return end

    local isTreatment = isRevive == true
    local isAtValidLocation = isTreatment
        and IsNearAnyCheckIn(src, 12.0)
        or IsNearCoords(src, Config.Locations.beds[bedId].coords, 5.0)

    if not isAtValidLocation then return end

    if Config.Locations.beds[bedId].taken then
        Notify(src, Lang:t('error.beds_taken'), 'error')
        return
    end

    Config.Locations.beds[bedId].taken = true
    OccupiedBeds[src] = { type = 'beds', id = bedId }
    TriggerClientEvent('hospital:client:SendToBed', src, bedId, Config.Locations.beds[bedId], isRevive == true)
    TriggerClientEvent('hospital:client:SetBed', -1, bedId, true)

    if isRevive == true then
        player.Functions.RemoveMoney('bank', Config.BillCost, 'hospital-treatment')
        TriggerClientEvent('hospital:client:SendBillEmail', src, Config.BillCost)
    end
end)

RegisterNetEvent('hospital:server:RespawnAtHospital', function()
    local src = source
    local player = QBCore.Functions.GetPlayer(src)
    if not player then return end

    local inJail = (player.PlayerData.metadata.injail or 0) > 0
    local bedType = inJail and 'jailbeds' or 'beds'
    local beds = Config.Locations[bedType]
    local bedId

    for id, bed in pairs(beds) do
        if not bed.taken then
            bedId = id
            break
        end
    end

    bedId = bedId or 1
    local bed = beds[bedId]
    if not bed then return end

    bed.taken = true
    OccupiedBeds[src] = { type = bedType, id = bedId }
    TriggerClientEvent('hospital:client:SendToBed', src, bedId, bed, true)
    TriggerClientEvent(inJail and 'hospital:client:SetBed2' or 'hospital:client:SetBed', -1, bedId, true)

    if Config.WipeInventoryOnRespawn then
        ClearPlayerInventory(src, player)
        Notify(src, Lang:t('error.possessions_taken'), 'error')
    end

    player.Functions.RemoveMoney('bank', Config.BillCost, 'respawned-at-hospital')
    TriggerClientEvent('hospital:client:SendBillEmail', src, Config.BillCost)
end)

RegisterNetEvent('hospital:server:ambulanceAlert', function(text)
    local src = source
    local ped = GetPlayerPed(src)
    local coords = GetEntityCoords(ped)
    local players = QBCore.Functions.GetQBPlayers()
    for _, v in pairs(players) do
        if v.PlayerData.job.name == 'ambulance' and v.PlayerData.job.onduty then
            TriggerClientEvent('hospital:client:ambulanceAlert', v.PlayerData.source, coords, text)
        end
    end
end)

RegisterNetEvent('hospital:server:LeaveBed', function()
    local src = source
    local occupied = OccupiedBeds[src]
    if not occupied then return end

    local beds = Config.Locations[occupied.type]
    if beds and beds[occupied.id] then
        beds[occupied.id].taken = false
        TriggerClientEvent(occupied.type == 'jailbeds' and 'hospital:client:SetBed2' or 'hospital:client:SetBed', -1, occupied.id, false)
    end

    OccupiedBeds[src] = nil
end)

RegisterNetEvent('hospital:server:SyncInjuries', function(data)
    local src = source
    PlayerInjuries[src] = data
end)

RegisterNetEvent('hospital:server:SetWeaponDamage', function(data)
	local src = source
	local Player = QBCore.Functions.GetPlayer(src)
	if Player then
		PlayerWeaponWounds[Player.PlayerData.source] = data
	end
end)

RegisterNetEvent('hospital:server:RestoreWeaponDamage', function()
	local src = source
	local Player = QBCore.Functions.GetPlayer(src)
	if Player then
		PlayerWeaponWounds[Player.PlayerData.source] = nil
	end
end)

RegisterNetEvent('hospital:server:SetDeathStatus', function(isDead)
	local src = source
	local Player = QBCore.Functions.GetPlayer(src)
	if Player then
		Player.Functions.SetMetaData("isdead", isDead)
	end
end)

RegisterNetEvent('hospital:server:SetLaststandStatus', function(bool)
	local src = source
	local Player = QBCore.Functions.GetPlayer(src)
	if Player then
		Player.Functions.SetMetaData("inlaststand", bool)
	end
end)

RegisterNetEvent('hospital:server:SetArmor', function(amount)
	local src = source
	local Player = QBCore.Functions.GetPlayer(src)
	if Player then
		Player.Functions.SetMetaData("armor", amount)
	end
end)

RegisterNetEvent('hospital:server:TreatWounds', function(playerId)
    local src = source
    playerId = tonumber(playerId)

    if not IsEMS(src, true) then
        Notify(src, Lang:t('error.not_ems'), 'error')
        return
    end

    if not playerId or not QBCore.Functions.GetPlayer(playerId) or not IsPlayerNear(src, playerId, GetPlayerInteractionDistance('treat') + 1.0) then
        Notify(src, Lang:t('error.no_player'), 'error')
        return
    end

    if not ConsumeTreatmentSession(src, playerId, 'treat') then return end

    local itemName = Config.TreatmentItems.Treat
    if not HasItem(src, itemName, 1) then
        Notify(src, Lang:t('error.no_bandage'), 'error')
        return
    end

    if not RemoveItem(src, itemName, 1) then return end
    TriggerClientEvent('hospital:client:HealInjuries', playerId, 'full')
    Notify(src, Lang:t('success.helped_player'), 'success')
end)

RegisterNetEvent('hospital:server:AddDoctor', function(job)
    local src = source
    if job ~= 'ambulance' or not IsEMS(src, true) or Doctors[src] then return end

    Doctors[src] = true
    doctorCount = doctorCount + 1
    TriggerClientEvent('hospital:client:SetDoctorCount', -1, doctorCount)
end)

RegisterNetEvent('hospital:server:RemoveDoctor', function(job)
    local src = source
    if job ~= 'ambulance' or not Doctors[src] then return end

    Doctors[src] = nil
    doctorCount = math.max(0, doctorCount - 1)
    TriggerClientEvent('hospital:client:SetDoctorCount', -1, doctorCount)
end)

AddEventHandler('playerDropped', function()
    local src = source

    if Doctors[src] then
        doctorCount = math.max(0, doctorCount - 1)
        TriggerClientEvent('hospital:client:SetDoctorCount', -1, doctorCount)
        Doctors[src] = nil
    end

    local occupied = OccupiedBeds[src]
    if occupied and Config.Locations[occupied.type] and Config.Locations[occupied.type][occupied.id] then
        Config.Locations[occupied.type][occupied.id].taken = false
        TriggerClientEvent(occupied.type == 'jailbeds' and 'hospital:client:SetBed2' or 'hospital:client:SetBed', -1, occupied.id, false)
    end

    OccupiedBeds[src] = nil
    TreatmentSessions[src] = nil
    for helperId, session in pairs(TreatmentSessions) do
        if session.targetId == src then
            TreatmentSessions[helperId] = nil
        end
    end

    PlayerInjuries[src] = nil
    PlayerWeaponWounds[src] = nil
end)

RegisterNetEvent('hospital:server:RevivePlayer', function(playerId, isOldMan)
    local src = source
    playerId = tonumber(playerId)
    local helper = QBCore.Functions.GetPlayer(src)
    local patient = playerId and QBCore.Functions.GetPlayer(playerId)

    if not helper or not patient or not IsPlayerNear(src, playerId, GetPlayerInteractionDistance('revive') + 1.0) then
        Notify(src, Lang:t('error.no_player'), 'error')
        return
    end

    local itemName = Config.TreatmentItems.Revive
    local authorised = IsEMS(src, true) or HasItem(src, itemName, 1)
    if not authorised then
        Notify(src, Lang:t('error.no_firstaid'), 'error')
        return
    end

    if not ConsumeTreatmentSession(src, playerId, 'revive') then return end

    local metadata = patient.PlayerData.metadata or {}
    local targetPed = GetPlayerPed(playerId)
    local needsRevive = metadata.isdead == true or metadata.inlaststand == true or (targetPed ~= 0 and GetEntityHealth(targetPed) <= 101)
    if not needsRevive then
        Notify(src, Lang:t('error.patient_not_down'), 'error')
        return
    end

    if isOldMan and not helper.Functions.RemoveMoney('cash', 5000, 'revived-player') then
        Notify(src, Lang:t('error.not_enough_money'), 'error')
        return
    end

    if not RemoveItem(src, itemName, 1) then
        Notify(src, Lang:t('error.no_firstaid'), 'error')
        return
    end

    TriggerClientEvent('hospital:client:Revive', playerId)
    Notify(src, Lang:t('success.revived'), 'success')
end)

RegisterNetEvent('hospital:server:StartTreatmentProgress', function(targetId, treatmentType, requestedDuration)
    local src = source
    targetId = tonumber(targetId)

    local allowedTypes = { examine = true, treat = true, revive = true }
    if not allowedTypes[treatmentType] then return end

    local emsAuthorised = IsEMS(src, true)
    local authorised = emsAuthorised
    if treatmentType == 'revive' then
        authorised = authorised or HasItem(src, Config.TreatmentItems.Revive, 1)
    end

    if not authorised or not targetId or not IsPlayerNear(src, targetId, GetTreatmentDistance(treatmentType) + 1.0) then return end

    local configuredDuration = {
        examine = Config.Progress.Examine,
        treat = Config.Progress.Treat,
        revive = Config.Progress.Revive,
    }

    local duration
    if emsAuthorised then
        duration = configuredDuration[treatmentType]
    else
        duration = math.min(math.max(tonumber(requestedDuration) or 30000, 30000), 60000)
    end

    BeginTreatmentSession(src, targetId, treatmentType, duration)
    TriggerClientEvent('hospital:client:TreatmentProgress', targetId, treatmentType, duration)
end)

RegisterNetEvent('hospital:server:CancelTreatmentProgress', function(targetId)
    local src = source
    targetId = tonumber(targetId)

    TreatmentSessions[src] = nil

    local authorised = IsEMS(src, true) or HasItem(src, Config.TreatmentItems.Revive, 1)
    if not authorised or not targetId or not IsPlayerNear(src, targetId, GetMaximumPlayerInteractionDistance() + 2.0) then return end

    TriggerClientEvent('hospital:client:CancelTreatmentProgress', targetId)
end)

RegisterNetEvent('hospital:server:SendDoctorAlert', function()
    local src = source
    if not doctorCalled then
        doctorCalled = true
        local players = QBCore.Functions.GetQBPlayers()
        for _, v in pairs(players) do
            if v.PlayerData.job.name == 'ambulance' and v.PlayerData.job.onduty then
                TriggerClientEvent('QBCore:Notify', v.PlayerData.source, Lang:t('info.dr_needed'), 'ambulance')
            end
        end
        SetTimeout(Config.DocCooldown * 60000, function()
            doctorCalled = false
        end)
    else
        TriggerClientEvent('QBCore:Notify', src, 'Doctor has already been notified', 'error')
    end
end)

RegisterNetEvent('hospital:server:UseFirstAid', function(targetId)
    local src = source
    targetId = tonumber(targetId)

    if not targetId or not HasItem(src, Config.TreatmentItems.Revive, 1) or not IsPlayerNear(src, targetId, 2.5) then
        Notify(src, Lang:t('error.no_firstaid'), 'error')
        return
    end

    if QBCore.Functions.GetPlayer(targetId) then
        TriggerClientEvent('hospital:client:CanHelp', targetId, src)
    end
end)

RegisterNetEvent('hospital:server:CanHelp', function(helperId, canHelp)
    local src = source
    helperId = tonumber(helperId)

    if not helperId or not IsPlayerNear(src, helperId, 3.0) or not HasItem(helperId, Config.TreatmentItems.Revive, 1) then return end

    if canHelp then
        TriggerClientEvent('hospital:client:HelpPerson', helperId, src)
    else
        TriggerClientEvent('QBCore:Notify', helperId, Lang:t('error.cant_help'), 'error')
    end
end)

RegisterNetEvent('hospital:server:removeBandage', function()
    RemoveItem(source, 'bandage', 1)
end)

RegisterNetEvent('hospital:server:removeIfaks', function()
    RemoveItem(source, 'ifaks', 1)
end)

RegisterNetEvent('hospital:server:removePainkillers', function()
    RemoveItem(source, 'painkillers', 1)
end)

RegisterNetEvent('hospital:server:resetHungerThirst', function()
	local Player = QBCore.Functions.GetPlayer(source)

	if not Player then return end

	Player.Functions.SetMetaData('hunger', 100)
	Player.Functions.SetMetaData('thirst', 100)

	TriggerClientEvent('hud:client:UpdateNeeds', source, 100, 100)
end)

-- Callbacks

QBCore.Functions.CreateCallback('hospital:server:GetPersonalStash', function(source, cb)
    local player = QBCore.Functions.GetPlayer(source)
    if not player or not IsEMS(source, true) then
        cb(nil)
        return
    end

    local stashId = ('ambulancestash_%s'):format(player.PlayerData.citizenid)
    if Config.Inventory == 'ox_inventory' and not RegisteredStashes[stashId] then
        local registered = pcall(function()
            exports.ox_inventory:RegisterStash(
                stashId,
                Config.PersonalStash.Label,
                Config.PersonalStash.Slots,
                Config.PersonalStash.Weight,
                false,
                { ambulance = 0 }
            )
        end)
        RegisteredStashes[stashId] = registered
    end

    cb(stashId)
end)

QBCore.Functions.CreateCallback('hospital:GetDoctors', function(_, cb)
	local amount = 0
    local players = QBCore.Functions.GetQBPlayers()
    for _, v in pairs(players) do
        if v.PlayerData.job.name == 'ambulance' and v.PlayerData.job.onduty then
			amount = amount + 1
		end
	end
	cb(amount)
end)

QBCore.Functions.CreateCallback('hospital:GetPlayerStatus', function(source, cb, playerId)
    if not IsEMS(source, true)
        or not IsPlayerNear(source, playerId, GetPlayerInteractionDistance('examine') + 1.0)
        or not ConsumeTreatmentSession(source, playerId, 'examine') then
        cb({ WEAPONWOUNDS = {} })
        return
    end

	local Player = QBCore.Functions.GetPlayer(playerId)
	local injuries = {}
	injuries["WEAPONWOUNDS"] = {}
	if Player then
		if PlayerInjuries[Player.PlayerData.source] then
			if (PlayerInjuries[Player.PlayerData.source].isBleeding > 0) then
				injuries["BLEED"] = PlayerInjuries[Player.PlayerData.source].isBleeding
			end
			for k, _ in pairs(PlayerInjuries[Player.PlayerData.source].limbs) do
				if PlayerInjuries[Player.PlayerData.source].limbs[k].isDamaged then
					injuries[k] = PlayerInjuries[Player.PlayerData.source].limbs[k]
				end
			end
		end
		if PlayerWeaponWounds[Player.PlayerData.source] then
			for k, v in pairs(PlayerWeaponWounds[Player.PlayerData.source]) do
				injuries["WEAPONWOUNDS"][k] = v
			end
		end
	end
    cb(injuries)
end)

QBCore.Functions.CreateCallback('hospital:GetPlayerBleeding', function(source, cb)
	local src = source
	if PlayerInjuries[src] and PlayerInjuries[src].isBleeding then
		cb(PlayerInjuries[src].isBleeding)
	else
		cb(nil)
	end
end)

-- Commands

QBCore.Commands.Add("heal", Lang:t('info.heal_player'), {}, false, function(source, _)
	local src = source
	local Player = QBCore.Functions.GetPlayer(src)
	if Player.PlayerData.job.name == "ambulance" then
		TriggerClientEvent("hospital:client:TreatWounds", src)
	else
		TriggerClientEvent('QBCore:Notify', src, Lang:t('error.not_ems'), "error")
	end
end)

QBCore.Commands.Add("revive", Lang:t('info.revive_player_a'), {{name = "id", help = Lang:t('info.player_id')}}, false, function(source, args)
	local src = source
	if args[1] then
		local Player = QBCore.Functions.GetPlayer(tonumber(args[1]))
		if Player then
			TriggerClientEvent('hospital:client:Revive', Player.PlayerData.source)
		else
			TriggerClientEvent('QBCore:Notify', src, Lang:t('error.not_online'), "error")
		end
	else
		TriggerClientEvent('hospital:client:Revive', src)
	end
end, "admin")

QBCore.Commands.Add("setpain", Lang:t('info.pain_level'), {{name = "id", help = Lang:t('info.player_id')}}, false, function(source, args)
	local src = source
	if args[1] then
		local Player = QBCore.Functions.GetPlayer(tonumber(args[1]))
		if Player then
			TriggerClientEvent('hospital:client:SetPain', Player.PlayerData.source)
		else
			TriggerClientEvent('QBCore:Notify', src, Lang:t('error.not_online'), "error")
		end
	else
		TriggerClientEvent('hospital:client:SetPain', src)
	end
end, "admin")

QBCore.Commands.Add("kill", Lang:t('info.kill'), {{name = "id", help = Lang:t('info.player_id')}}, false, function(source, args)
	local src = source
	if args[1] then
		local Player = QBCore.Functions.GetPlayer(tonumber(args[1]))
		if Player then
			TriggerClientEvent('hospital:client:KillPlayer', Player.PlayerData.source)
		else
			TriggerClientEvent('QBCore:Notify', src, Lang:t('error.not_online'), "error")
		end
	else
		TriggerClientEvent('hospital:client:KillPlayer', src)
	end
end, "admin")

QBCore.Commands.Add('aheal', Lang:t('info.heal_player_a'), {{name = 'id', help = Lang:t('info.player_id')}}, false, function(source, args)
	local src = source
	if args[1] then
		local Player = QBCore.Functions.GetPlayer(tonumber(args[1]))
		if Player then
			TriggerClientEvent('hospital:client:adminHeal', Player.PlayerData.source)
		else
			TriggerClientEvent('QBCore:Notify', src, Lang:t('error.not_online'), "error")
		end
	else
		TriggerClientEvent('hospital:client:adminHeal', src)
	end
end, 'admin')

-- Items

QBCore.Functions.CreateUseableItem("ifaks", function(source, item)
	local src = source
	if HasItem(src, item.name, 1) then
		TriggerClientEvent("hospital:client:UseIfaks", src)
	end
end)

QBCore.Functions.CreateUseableItem("bandage", function(source, item)
    local src = source
    if item and HasItem(src, 'bandage', 1) then
        -- A QBCore/ox_inventory bridge may bypass ox_inventory's usingItem
        -- hook. Fire at the usable-item callback BEFORE the client animation.
        StartBandageLoop(src, 'QBCore usable item (start)')
        TriggerClientEvent("hospital:client:UseBandage", src)
    end
end)

-- Native ox_inventory items can use their own progress animation instead of
-- hospital:client:UseBandage. The usingItem hook fires before that animation;
-- the usedItem completion event must NOT be used for audio.
local bandageUsingHookId = nil

local function RegisterBandageUsingHook()
    if Config.Inventory ~= 'ox_inventory' or bandageUsingHookId then return end
    if GetResourceState('ox_inventory') ~= 'started' then return end

    local ok, hookId = pcall(function()
        return exports.ox_inventory:registerHook('usingItem', function(payload)
            if type(payload) ~= 'table' or type(payload.item) ~= 'table'
                or payload.item.name ~= 'bandage' then
                return
            end

            local src = tonumber(payload.source)
            if not src or not QBCore.Functions.GetPlayer(src) then return end

            StartBandageLoop(src, 'ox_inventory:usingItem (start)')
        end, {
            itemFilter = { bandage = true }
        })
    end)

    if ok and hookId then
        bandageUsingHookId = hookId
        if Config.InteractSound and Config.InteractSound.Debug then
            print('[qb-ambulancejob] ox_inventory bandage start hook registered.')
        end
    else
        print(('[qb-ambulancejob] Could not register ox_inventory bandage start hook: %s'):format(tostring(hookId)))
    end
end

CreateThread(function()
    Wait(1000)
    RegisterBandageUsingHook()
end)

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName ~= 'ox_inventory' then return end
    CreateThread(function()
        Wait(1000)
        RegisterBandageUsingHook()
    end)
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= 'ox_inventory' then return end
    bandageUsingHookId = nil
end)

-- Do not play audio from ox_inventory:usedItem: it runs only after the progress
-- finishes and caused the delayed sound reported by the user. The proper
-- start paths are QBCore's usable-item callback, ox_inventory's usingItem
-- hook, and the optional ox_inventory client export below.

QBCore.Functions.CreateUseableItem("painkillers", function(source, item)
	local src = source
	if HasItem(src, item.name, 1) then
		TriggerClientEvent("hospital:client:UsePainkillers", src)
	end
end)

QBCore.Functions.CreateUseableItem("firstaid", function(source, item)
	local src = source
	if HasItem(src, item.name, 1) then
		TriggerClientEvent("hospital:client:UseFirstAid", src)
	end
end)

exports('GetDoctorCount', function() return doctorCount end)
