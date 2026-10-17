local missingInteractSoundWarning = false

local function GetBandageSoundConfig()
    local integration = Config.InteractSound
    if type(integration) ~= 'table' or integration.Enabled == false then return nil end

    local sound = integration.Bandage
    if type(sound) ~= 'table' or sound.Enabled == false then return nil end

    return integration, sound
end

local function IsInteractSoundStarted(resourceName)
    if GetResourceState(resourceName) == 'started' then
        missingInteractSoundWarning = false
        return true
    end

    if not missingInteractSoundWarning then
        missingInteractSoundWarning = true
        print(('[qb-ambulancejob] Bandage sound skipped because %s is not started.'):format(resourceName))
    end

    return false
end

-- Stop requests are emitted by both QBCore and ox_inventory progress
-- callbacks, including cancellation. The server relays stops to listeners.
function StopBandageSound()
    TriggerServerEvent('hospital:server:StopBandageSound')
end

local function StartLocalBandageLoop(src, token, name, volume, resourceName, duration)
    SendNUIMessage({
        action = 'bandage:start',
        id = tostring(src) .. ':' .. tostring(token),
        name = tostring(name),
        volume = tonumber(volume) or 0.35,
        resource = tostring(resourceName or 'interact-sound'),
        duration = tonumber(duration) or 4000,
    })
end

RegisterNetEvent('hospital:client:StartBandageLoop', function(src, token, name, volume, resourceName, duration)
    local integration, sound = GetBandageSoundConfig()
    if not integration then return end
    if not IsInteractSoundStarted(resourceName or integration.Resource or 'interact-sound') then return end
    StartLocalBandageLoop(src, token, name, volume, resourceName, duration)
end)

RegisterNetEvent('hospital:client:StopBandageLoop', function(src, token)
    SendNUIMessage({
        action = 'bandage:stop',
        id = tostring(src) .. ':' .. tostring(token),
    })
end)

function PlayBandageSound(mode)
    local integration, sound = GetBandageSoundConfig()
    if not integration then return false end
    local resourceName = integration.Resource or 'interact-sound'
    if not IsInteractSoundStarted(resourceName) then return false end

    if mode == 'nearby' then
        TriggerServerEvent('hospital:server:RequestTreatBandageSound')
        return true
    end

    -- Keep /testbandagesound available to verify the new loop directly.
    local duration = tonumber(sound.Duration) or tonumber((Config.BandageAnimation or {}).Duration) or 4000
    local token = ('test-%s'):format(GetGameTimer())
    StartLocalBandageLoop('test', token, tostring(sound.Name or 'bandage'):gsub('%.ogg$', ''),
        math.max(0, math.min(tonumber(sound.Volume) or 0.35, 1)), resourceName, duration)
    SetTimeout(duration, function()
        SendNUIMessage({action = 'bandage:stop', id = 'test:' .. token})
    end)
    return true
end

-- Retained for external integrations that may still use the old one-shot event.
RegisterNetEvent('hospital:client:ReceiveBandageSound', function(soundName, volume)
    local integration = Config.InteractSound
    if type(integration) ~= 'table' or integration.Enabled == false then return end
    if not IsInteractSoundStarted(integration.Resource or 'interact-sound') then return end
    TriggerEvent('InteractSound_CL:PlayOnOne', tostring(soundName),
        math.max(0.0, math.min(tonumber(volume) or 0.35, 1.0)))
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        SendNUIMessage({ action = 'bandage:stopAll' })
    end
end)

local bandageSoundPending = false

RegisterNetEvent('hospital:client:PlayBandageSound', function(mode, delay)
    if bandageSoundPending then return end

    bandageSoundPending = true
    SetTimeout(math.max(0, tonumber(delay) or 250), function()
        PlayBandageSound(mode or 'source')
        bandageSoundPending = false
    end)
end)

CreateThread(function()
    local integration = Config.InteractSound
    local command = type(integration) == 'table' and integration.TestCommand or nil

    if type(command) ~= 'string' or command == '' then return end

    RegisterCommand(command, function()
        if PlayBandageSound('source') then
            print(('[qb-ambulancejob] Testing interact-sound file: %s.ogg'):format(
                Config.InteractSound.Bandage.Name or 'bandage'
            ))
        end
    end, false)
end)
