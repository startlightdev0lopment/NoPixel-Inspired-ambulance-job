local PlayerJob = {}
local onDuty = false
local treatmentBusy = false
local registeredPointInteractions = {}
local registeredPlayerInteractions = {}

-- Helpers

local function RefreshJobState()
    local playerData = QBCore.Functions.GetPlayerData()
    PlayerJob = playerData.job or {}
    onDuty = PlayerJob.name == 'ambulance' and PlayerJob.onduty == true
end

local function IsEMSOnDuty()
    local playerData = QBCore.Functions.GetPlayerData()
    local job = playerData.job
    return job and job.name == 'ambulance' and job.onduty == true
end

local function GetPlayerInteractionDistance(treatmentType)
    for _, interaction in pairs(Config.Interactions.Players or {}) do
        if interaction.treatmentType == treatmentType then
            return interaction.distance or Config.Interactions.Defaults.playerDistance
        end
    end

    return Config.Interactions.Defaults.playerDistance
end

local function HasItem(itemName, amount)
    amount = amount or 1

    if Config.Inventory == 'ox_inventory' and GetResourceState('ox_inventory') == 'started' then
        return (exports.ox_inventory:Search('count', itemName) or 0) >= amount
    end

    return QBCore.Functions.HasItem(itemName, amount)
end

local function SetVehicleFuel(vehicle, amount)
    if Config.Fuel == 'none' then return end

    local ok = pcall(function()
        if Config.Fuel == 'ox_fuel' then
            Entity(vehicle).state.fuel = amount
        else
            exports[Config.Fuel]:SetFuel(vehicle, amount)
        end
    end)

    if not ok then
        SetVehicleFuelLevel(vehicle, amount + 0.0)
    end
end

local function GetClosestPlayer()
    local closestPlayers = QBCore.Functions.GetPlayersFromCoords()
    local closestDistance = -1
    local closestPlayer = -1
    local coords = GetEntityCoords(PlayerPedId())

    for i = 1, #closestPlayers do
        if closestPlayers[i] ~= PlayerId() then
            local pos = GetEntityCoords(GetPlayerPed(closestPlayers[i]))
            local distance = #(pos - coords)

            if closestDistance == -1 or closestDistance > distance then
                closestPlayer = closestPlayers[i]
                closestDistance = distance
            end
        end
    end

    return closestPlayer, closestDistance
end

local function ResolveTarget(targetServerId)
    if targetServerId then
        local player = GetPlayerFromServerId(tonumber(targetServerId))
        if player ~= -1 then
            local distance = #(GetEntityCoords(PlayerPedId()) - GetEntityCoords(GetPlayerPed(player)))
            return player, distance, tonumber(targetServerId)
        end
    end

    local player, distance = GetClosestPlayer()
    if player == -1 then return -1, -1, nil end
    return player, distance, GetPlayerServerId(player)
end

local function IsAuthorizedAmbulance(vehicle)
    if vehicle == 0 or not DoesEntityExist(vehicle) then return false end

    local model = GetEntityModel(vehicle)
    if model == joaat(Config.Helicopter) then return true end

    for _, vehicles in pairs(Config.AuthorizedVehicles) do
        for modelName in pairs(vehicles) do
            if model == joaat(modelName) then
                return true
            end
        end
    end

    return false
end

local function IsSpawnClear(coords, radius)
    return not IsAnyVehicleNearPoint(coords.x, coords.y, coords.z, radius or 3.0)
end

local function StopTreatmentAnimation()
    StopAnimTask(PlayerPedId(), healAnimDict, healAnim, 1.0)
    ClearPedTasks(PlayerPedId())
end

local function BeginPatientProgress(targetId, treatmentType, duration)
    TriggerServerEvent('hospital:server:StartTreatmentProgress', targetId, treatmentType, duration)
end

local function CancelPatientProgress(targetId)
    TriggerServerEvent('hospital:server:CancelTreatmentProgress', targetId)
end

local function RunMedicProgress(name, label, duration, targetId, treatmentType, onComplete)
    if treatmentBusy then
        QBCore.Functions.Notify('You are already treating a patient', 'error')
        return
    end

    treatmentBusy = true
    BeginPatientProgress(targetId, treatmentType, duration)

    if treatmentType == 'treat' then
        PlayBandageSound('nearby')
    end

    QBCore.Functions.Progressbar(name, label, duration, false, true, {
        disableMovement = true,
        disableCarMovement = true,
        disableMouse = false,
        disableCombat = true,
    }, {
        animDict = healAnimDict,
        anim = healAnim,
        flags = 33,
    }, {}, {}, function()
        treatmentBusy = false
        if treatmentType == 'treat' then StopBandageSound() end
        StopTreatmentAnimation()
        onComplete()
    end, function()
        treatmentBusy = false
        if treatmentType == 'treat' then StopBandageSound() end
        StopTreatmentAnimation()
        CancelPatientProgress(targetId)
        QBCore.Functions.Notify(Lang:t('error.canceled'), 'error')
    end)
end

-- Vehicle garage

local function TakeOutVehicle(vehicleInfo, garageId)
    local coords = Config.Locations.vehicle[garageId]
    if not coords then return end

    if not IsSpawnClear(coords, 3.0) then
        QBCore.Functions.Notify('The ambulance bay is blocked', 'error')
        return
    end

    QBCore.Functions.TriggerCallback('QBCore:Server:SpawnVehicle', function(netId)
        local vehicle = NetToVeh(netId)
        if vehicle == 0 then
            QBCore.Functions.Notify('The ambulance could not be spawned', 'error')
            return
        end

        SetVehicleNumberPlateText(vehicle, Lang:t('info.amb_plate') .. tostring(math.random(1000, 9999)))
        SetEntityHeading(vehicle, coords.w)
        SetVehicleFuel(vehicle, 100.0)

        if Config.VehicleSettings[vehicleInfo] then
            QBCore.Shared.SetDefaultVehicleExtras(vehicle, Config.VehicleSettings[vehicleInfo].extras)
        end

        TriggerEvent('vehiclekeys:client:SetOwner', QBCore.Functions.GetPlate(vehicle))
        TaskWarpPedIntoVehicle(PlayerPedId(), vehicle, -1)
        SetVehicleEngineOn(vehicle, true, true, false)
    end, vehicleInfo, coords, true)
end

local function OpenGarage(garageId)
    if not IsEMSOnDuty() then
        QBCore.Functions.Notify(Lang:t('error.not_ems'), 'error')
        return
    end

    local playerData = QBCore.Functions.GetPlayerData()
    local grade = playerData.job and playerData.job.grade and playerData.job.grade.level or 0
    local authorizedVehicles = Config.AuthorizedVehicles[grade] or Config.AuthorizedVehicles[0] or {}

    local vehicleMenu = {
        {
            header = Lang:t('menu.amb_vehicles'),
            isMenuHeader = true,
        }
    }

    for vehicle, label in pairs(authorizedVehicles) do
        vehicleMenu[#vehicleMenu + 1] = {
            header = label,
            txt = vehicle,
            params = {
                event = 'ambulance:client:TakeOutVehicle',
                args = {
                    vehicle = vehicle,
                    garage = garageId,
                }
            }
        }
    end

    vehicleMenu[#vehicleMenu + 1] = {
        header = Lang:t('menu.close'),
        params = { event = 'qb-menu:client:closeMenu' }
    }

    exports['qb-menu']:openMenu(vehicleMenu)
end

local function StoreCurrentVehicle(expectedType)
    local ped = PlayerPedId()
    local vehicle = GetVehiclePedIsIn(ped, false)

    if vehicle == 0 or GetPedInVehicleSeat(vehicle, -1) ~= ped then
        QBCore.Functions.Notify('You must be driving the EMS vehicle', 'error')
        return
    end

    if not IsAuthorizedAmbulance(vehicle) then
        QBCore.Functions.Notify('This is not an authorised EMS vehicle', 'error')
        return
    end

    local isHelicopter = IsThisModelAHeli(GetEntityModel(vehicle))
    if expectedType == 'helicopter' and not isHelicopter then
        QBCore.Functions.Notify('Only an EMS helicopter can be stored here', 'error')
        return
    elseif expectedType == 'vehicle' and isHelicopter then
        QBCore.Functions.Notify('Use the helipad to store this helicopter', 'error')
        return
    end

    QBCore.Functions.DeleteVehicle(vehicle)
    QBCore.Functions.Notify('EMS vehicle stored', 'success')
end

local function SpawnHelicopter(helipadId)
    local coords = Config.Locations.helicopter[helipadId]
    if not coords then return end

    if not IsSpawnClear(coords, 5.0) then
        QBCore.Functions.Notify('The helipad is blocked', 'error')
        return
    end

    QBCore.Functions.TriggerCallback('QBCore:Server:SpawnVehicle', function(netId)
        local vehicle = NetToVeh(netId)
        if vehicle == 0 then return end

        SetVehicleNumberPlateText(vehicle, Lang:t('info.heli_plate') .. tostring(math.random(1000, 9999)))
        SetEntityHeading(vehicle, coords.w)
        SetVehicleLivery(vehicle, 1)
        SetVehicleFuel(vehicle, 100.0)
        TriggerEvent('vehiclekeys:client:SetOwner', QBCore.Functions.GetPlate(vehicle))
        TaskWarpPedIntoVehicle(PlayerPedId(), vehicle, -1)
        SetVehicleEngineOn(vehicle, true, true, false)
    end, Config.Helicopter, coords, true)
end

-- Events

RegisterNetEvent('ambulance:client:TakeOutVehicle', function(data)
    TakeOutVehicle(data.vehicle, data.garage)
end)

RegisterNetEvent('ambulance:client:OpenGarage', function(garageId)
    OpenGarage(garageId)
end)

RegisterNetEvent('ambulance:client:StoreVehicle', function(vehicleType)
    StoreCurrentVehicle(vehicleType)
end)

RegisterNetEvent('ambulance:client:SpawnHelicopter', function(helipadId)
    SpawnHelicopter(helipadId)
end)

RegisterNetEvent('QBCore:Client:OnJobUpdate', function(jobInfo)
    local wasOnDuty = onDuty
    PlayerJob = jobInfo
    onDuty = PlayerJob.name == 'ambulance' and PlayerJob.onduty == true

    if PlayerJob.name == 'ambulance' and onDuty and not wasOnDuty then
        TriggerServerEvent('hospital:server:AddDoctor', 'ambulance')
    elseif wasOnDuty and not onDuty then
        TriggerServerEvent('hospital:server:RemoveDoctor', 'ambulance')
    end
end)

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    exports.spawnmanager:setAutoSpawn(false)

    CreateThread(function()
        Wait(1000)
        RefreshJobState()

        local playerData = QBCore.Functions.GetPlayerData()
        SetPedArmour(PlayerPedId(), playerData.metadata.armor or 0)

        if not playerData.metadata.inlaststand and playerData.metadata.isdead then
            deathTime = Config.ReviveInterval
            OnDeath()
            DeathTimer()
        elseif playerData.metadata.inlaststand and not playerData.metadata.isdead then
            SetLaststand(true)
        else
            TriggerServerEvent('hospital:server:SetDeathStatus', false)
            TriggerServerEvent('hospital:server:SetLaststandStatus', false)
        end

        if onDuty then
            TriggerServerEvent('hospital:server:AddDoctor', 'ambulance')
        end
    end)

    CreateThread(function()
        Wait(5000)
        local ped = PlayerPedId()
        local player = PlayerId()
        SetEntityMaxHealth(ped, 200)
        SetEntityHealth(ped, 200)
        SetPlayerHealthRechargeMultiplier(player, 0.0)
        SetPlayerHealthRechargeLimit(player, 0.0)
    end)
end)

RegisterNetEvent('QBCore:Client:OnPlayerUnload', function()
    if onDuty then
        TriggerServerEvent('hospital:server:RemoveDoctor', 'ambulance')
    end

    PlayerJob = {}
    onDuty = false
end)

RegisterNetEvent('QBCore:Client:SetDuty', function(duty)
    if PlayerJob.name == 'ambulance' and duty ~= onDuty then
        TriggerServerEvent(duty and 'hospital:server:AddDoctor' or 'hospital:server:RemoveDoctor', 'ambulance')
    end

    onDuty = PlayerJob.name == 'ambulance' and duty == true
    PlayerJob.onduty = onDuty
end)

RegisterNetEvent('EMSToggle:Duty', function()
    local playerData = QBCore.Functions.GetPlayerData()
    if not playerData.job or playerData.job.name ~= 'ambulance' then
        QBCore.Functions.Notify(Lang:t('error.not_ems'), 'error')
        return
    end

    TriggerServerEvent('QBCore:ToggleDuty')
    TriggerServerEvent('police:server:UpdateBlips')
end)

local function OpenStatusMenu()
    local statusMenu = {
        {
            header = Lang:t('menu.status'),
            isMenuHeader = true,
        }
    }

    for _, status in ipairs(statusChecks) do
        statusMenu[#statusMenu + 1] = {
            header = status.label,
            txt = status.detail or '',
            isMenuHeader = true,
        }
    end

    statusMenu[#statusMenu + 1] = {
        header = Lang:t('menu.close'),
        params = { event = 'qb-menu:client:closeMenu' }
    }

    exports['qb-menu']:openMenu(statusMenu)
end

RegisterNetEvent('hospital:client:CheckStatus', function(targetServerId)
    if not IsEMSOnDuty() then
        QBCore.Functions.Notify(Lang:t('error.not_ems'), 'error')
        return
    end

    local player, distance, playerId = ResolveTarget(targetServerId)
    if player == -1 or distance > GetPlayerInteractionDistance('examine') then
        QBCore.Functions.Notify(Lang:t('error.no_player'), 'error')
        return
    end

    RunMedicProgress('hospital_examine', Lang:t('progress.examining'), Config.Progress.Examine, playerId, 'examine', function()
        QBCore.Functions.TriggerCallback('hospital:GetPlayerStatus', function(result)
            statusChecks = {}
            local hasInjury = false

            if result then
                for bodyPart, injury in pairs(result) do
                    if bodyPart ~= 'BLEED' and bodyPart ~= 'WEAPONWOUNDS' then
                        hasInjury = true
                        statusChecks[#statusChecks + 1] = {
                            label = injury.label,
                            detail = Config.WoundStates[injury.severity] or 'Unknown injury',
                        }
                    end
                end

                if result.BLEED and result.BLEED > 0 then
                    hasInjury = true
                    local bleedState = Config.BleedingStates[result.BLEED]
                    statusChecks[#statusChecks + 1] = {
                        label = 'Bleeding',
                        detail = bleedState and bleedState.label or 'Unknown severity',
                    }
                end

                for _, weaponHash in pairs(result.WEAPONWOUNDS or {}) do
                    hasInjury = true
                    local weapon = QBCore.Shared.Weapons[weaponHash]
                    statusChecks[#statusChecks + 1] = {
                        label = 'Trauma',
                        detail = weapon and weapon.damagereason or 'Unknown cause',
                    }
                end
            end

            if not hasInjury then
                QBCore.Functions.Notify(Lang:t('success.healthy_player'), 'success')
                return
            end

            isStatusChecking = true
            statusCheckTime = 15
            OpenStatusMenu()
        end, playerId)
    end)
end)

RegisterNetEvent('hospital:client:RevivePlayer', function(targetServerId)
    if not IsEMSOnDuty() then
        QBCore.Functions.Notify(Lang:t('error.not_ems'), 'error')
        return
    end

    local itemName = Config.TreatmentItems.Revive
    if not HasItem(itemName) then
        QBCore.Functions.Notify(Lang:t('error.no_firstaid'), 'error')
        return
    end

    local player, distance, playerId = ResolveTarget(targetServerId)
    if player == -1 or distance > GetPlayerInteractionDistance('revive') then
        QBCore.Functions.Notify(Lang:t('error.no_player'), 'error')
        return
    end

    RunMedicProgress('hospital_revive', Lang:t('progress.revive'), Config.Progress.Revive, playerId, 'revive', function()
        TriggerServerEvent('hospital:server:RevivePlayer', playerId)
    end)
end)

RegisterNetEvent('hospital:client:TreatWounds', function(targetServerId)
    if not IsEMSOnDuty() then
        QBCore.Functions.Notify(Lang:t('error.not_ems'), 'error')
        return
    end

    local itemName = Config.TreatmentItems.Treat
    if not HasItem(itemName) then
        QBCore.Functions.Notify(Lang:t('error.no_bandage'), 'error')
        return
    end

    local player, distance, playerId = ResolveTarget(targetServerId)
    if player == -1 or distance > GetPlayerInteractionDistance('treat') then
        QBCore.Functions.Notify(Lang:t('error.no_player'), 'error')
        return
    end

    RunMedicProgress('hospital_healwounds', Lang:t('progress.healing'), Config.Progress.Treat, playerId, 'treat', function()
        TriggerServerEvent('hospital:server:TreatWounds', playerId)
    end)
end)

RegisterNetEvent('qb-ambulancejob:stash', function()
    if not IsEMSOnDuty() then
        QBCore.Functions.Notify(Lang:t('error.not_ems'), 'error')
        return
    end

    if Config.Inventory == 'ox_inventory' then
        QBCore.Functions.TriggerCallback('hospital:server:GetPersonalStash', function(stashId)
            if stashId then
                exports.ox_inventory:openInventory('stash', stashId)
            end
        end)
    else
        local stashId = 'ambulancestash_' .. QBCore.Functions.GetPlayerData().citizenid
        TriggerServerEvent('inventory:server:OpenInventory', 'stash', stashId)
        TriggerEvent('inventory:client:SetCurrentStash', stashId)
    end
end)

RegisterNetEvent('qb-ambulancejob:armory', function()
    if not IsEMSOnDuty() then
        QBCore.Functions.Notify(Lang:t('error.not_ems'), 'error')
        return
    end

    if Config.Inventory == 'ox_inventory' then
        exports.ox_inventory:openInventory('shop', { type = 'hospital', id = 1 })
    else
        TriggerServerEvent('inventory:server:OpenInventory', 'shop', 'hospital', Config.Items)
    end
end)

RegisterNetEvent('qb-ambulancejob:elevator_roof', function(locationId)
    local coords = Config.Locations.main[locationId or 1]
    if not coords then return end

    DoScreenFadeOut(500)
    while not IsScreenFadedOut() do Wait(10) end
    SetEntityCoords(PlayerPedId(), coords.x, coords.y, coords.z, false, false, false, false)
    if coords.w then SetEntityHeading(PlayerPedId(), coords.w) end
    Wait(100)
    DoScreenFadeIn(1000)
end)

RegisterNetEvent('qb-ambulancejob:elevator_main', function(locationId)
    local coords = Config.Locations.roof[locationId or 1]
    if not coords then return end

    DoScreenFadeOut(500)
    while not IsScreenFadedOut() do Wait(10) end
    SetEntityCoords(PlayerPedId(), coords.x, coords.y, coords.z, false, false, false, false)
    if coords.w then SetEntityHeading(PlayerPedId(), coords.w) end
    Wait(100)
    DoScreenFadeIn(1000)
end)

-- Interact setup

local function ResolveConfiguredArgs(configuredArgs, context)
    local args = {}

    for index, value in ipairs(configuredArgs or {}) do
        if value == '$index' then
            args[index] = context.index
        elseif value == '$entity' then
            args[index] = context.entity
        elseif value == '$serverId' then
            args[index] = context.serverId
        else
            args[index] = value
        end
    end

    return args
end

local function RunConfiguredAction(option, context)
    if not option.event then return end

    local args = ResolveConfiguredArgs(option.args, context)
    local actionType = option.type or 'client'

    if actionType == 'server' then
        TriggerServerEvent(option.event, table.unpack(args))
    elseif actionType == 'command' then
        ExecuteCommand(option.event)
    else
        TriggerEvent(option.event, table.unpack(args))
    end
end

local EMSInteractionConditions = {
    always = function()
        return true
    end,
    ems_on_duty = function()
        return IsEMSOnDuty()
    end,
    ems_on_duty_on_foot = function()
        return IsEMSOnDuty() and not IsPedInAnyVehicle(PlayerPedId(), false)
    end,
    ems_on_duty_in_vehicle = function()
        return IsEMSOnDuty() and IsPedInAnyVehicle(PlayerPedId(), false)
    end,
    ems_on_duty_other_player = function(context)
        return IsEMSOnDuty() and context.entity and context.entity ~= PlayerPedId()
    end,
}

local function CanUseConfiguredOption(option, context)
    local condition = EMSInteractionConditions[option.canInteract or 'always']
    return not condition or condition(context)
end

local function CreatePointOption(definition, option, optionIndex, pointIndex)
    return {
        name = option.name or ('option_%s'):format(optionIndex),
        label = option.label,
        icon = option.icon,
        canInteract = function(entity, distance, coords, name)
            return CanUseConfiguredOption(option, {
                definition = definition,
                index = pointIndex,
                entity = entity,
                distance = distance,
                coords = coords,
                name = name,
            })
        end,
        action = function(entity, distance, coords, name)
            RunConfiguredAction(option, {
                definition = definition,
                index = pointIndex,
                entity = entity,
                distance = distance,
                coords = coords,
                name = name,
            })
        end,
    }
end

local function AddConfiguredPointInteraction(definition, pointIndex, point)
    local coords = point.coords or point
    if not coords then return end

    if definition.skipZeroCoords and coords.x == 0.0 and coords.y == 0.0 and coords.z == 0.0 then
        return
    end

    local interactionId = ('%s_%s'):format(definition.id, pointIndex)
    local options = {}

    for optionIndex, option in ipairs(definition.options or {}) do
        options[#options + 1] = CreatePointOption(definition, option, optionIndex, pointIndex)
    end

    if #options == 0 then return end

    exports[Config.InteractResource]:AddInteraction({
        coords = vector3(coords.x, coords.y, coords.z),
        distance = definition.distance or Config.Interactions.Defaults.distance,
        interactDst = definition.interactDistance or Config.Interactions.Defaults.interactDistance,
        id = interactionId,
        name = interactionId,
        groups = definition.groups,
        options = options,
    })

    registeredPointInteractions[#registeredPointInteractions + 1] = interactionId
end

local function ResolvePlayerServerId(entity, suppliedServerId)
    local serverId = tonumber(suppliedServerId)
    if serverId then return serverId end
    if not entity or entity == 0 or not IsPedAPlayer(entity) then return nil end

    local player = NetworkGetPlayerIndexFromPed(entity)
    if player == -1 then return nil end
    return GetPlayerServerId(player)
end

local function AddConfiguredPlayerInteraction(definition)
    if definition.enabled == false then return end

    local interactionId = definition.id
    if not interactionId then return end

    exports[Config.InteractResource]:addGlobalPlayerInteraction({
        distance = definition.distance or Config.Interactions.Defaults.playerDistance,
        interactDst = definition.interactDistance or Config.Interactions.Defaults.playerInteractDistance,
        offset = definition.offset or Config.Interactions.Defaults.playerOffset,
        id = interactionId,
        groups = definition.groups,
        options = {
            name = definition.name or interactionId,
            label = definition.label,
            icon = definition.icon,
            canInteract = function(entity, distance, coords, name)
                return CanUseConfiguredOption(definition, {
                    definition = definition,
                    entity = entity,
                    distance = distance,
                    coords = coords,
                    name = name,
                    serverId = ResolvePlayerServerId(entity),
                })
            end,
            action = function(entity, distance, coords, suppliedServerId)
                local serverId = ResolvePlayerServerId(entity, suppliedServerId)
                if not serverId then return end

                RunConfiguredAction(definition, {
                    definition = definition,
                    entity = entity,
                    distance = distance,
                    coords = coords,
                    serverId = serverId,
                })
            end,
        }
    })

    registeredPlayerInteractions[#registeredPlayerInteractions + 1] = interactionId
end

CreateThread(function()
    Wait(1000)
    RefreshJobState()

    if onDuty then
        TriggerServerEvent('hospital:server:AddDoctor', 'ambulance')
    end

    for _, definition in pairs(Config.Interactions.EMSPoints or {}) do
        if definition.enabled ~= false then
            local points = definition.points or Config.Locations[definition.location] or {}

            for pointIndex, point in pairs(points) do
                AddConfiguredPointInteraction(definition, pointIndex, point)
            end
        end
    end

    for _, definition in pairs(Config.Interactions.Players or {}) do
        AddConfiguredPlayerInteraction(definition)
    end
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() or GetResourceState(Config.InteractResource) ~= 'started' then return end

    for _, id in ipairs(registeredPointInteractions) do
        pcall(function() exports[Config.InteractResource]:RemoveInteraction(id) end)
    end

    for _, id in ipairs(registeredPlayerInteractions) do
        pcall(function() exports[Config.InteractResource]:RemoveGlobalPlayerInteraction(id) end)
    end
end)
