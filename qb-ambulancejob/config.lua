Config = {}

-- Core integrations
Config.InteractResource = 'interact'
Config.Inventory = 'ox_inventory' -- ox_inventory or qb-inventory
Config.Fuel = 'cdn-fuel' -- cdn-fuel, ps-fuel, LegacyFuel, ox_fuel, or none
Config.Dispatch = 'karma-dispatch' -- karma-dispatch, starlight-dispatch, or none


-- interact-sound integration.
-- The sound file must be installed as:
-- interact-sound/client/html/sounds/bandage.ogg
-- IMPORTANT: bandage.ogg must also be listed in interact-sound/fxmanifest.lua.
Config.InteractSound = {
    Enabled = true,
    Resource = 'interact-sound',
    TestCommand = 'testbandagesound', -- Set to false to disable
    Debug = false, -- true = log which bandage item-use route triggered the sound
    Bandage = {
        Enabled = true,
        Name = 'bandage', -- Filename without .ogg
        Volume = 0.35, -- 0.0 to 1.0
        Nearby = true, -- Self-use and EMS treatment are heard by nearby players
        Distance = 5.0,
        StartDelay = 0, -- Milliseconds before the sound starts
        Duration = 4000, -- Safety duration in ms; match ox_inventory's bandage usetime
    },
}

-- Custom self-bandaging animation for the QBCore usable-item route.
-- The matching ox_inventory item definition is included in the installation guide.
-- The custom .ycd animation must be streamed by a separate FiveM resource.
Config.BandageAnimation = {
    Dict = 'items@clear@custom_anim',
    Clip = 'bandage',
    Flag = 49,
    Duration = 4000,
}

-- Every interact entry is configured here.
-- location points to a key inside Config.Locations. Use '$index' in args to pass
-- the current location/bed index into the configured event.
-- World conditions: always, not_in_bed, bed_available, ems_on_duty,
-- ems_on_duty_on_foot, ems_on_duty_in_vehicle.
-- Player condition: ems_on_duty_other_player. Action types: client, server, command.
Config.Interactions = {
    Defaults = {
        distance = 8.0,
        interactDistance = 1.6,
        playerDistance = 4.0,
        playerInteractDistance = 2.0,
        playerOffset = vector3(0.0, 0.0, 0.0),
    },

    Hospital = {
        CheckIn = {
            enabled = true,
            location = 'checking',
            id = 'hospital_checkin',
            interactDistance = 2.0,
            options = {
                {
                    name = 'check_in',
                    label = 'Check In For Treatment',
                    icon = 'fa-solid fa-clipboard-check',
                    type = 'client',
                    event = 'qb-ambulancejob:checkin',
                    canInteract = 'not_in_bed',
                },
            },
        },
        Beds = {
            enabled = true,
            location = 'beds',
            id = 'hospital_bed',
            interactDistance = 2.2,
            options = {
                {
                    name = 'use_bed',
                    label = 'Lie In Hospital Bed',
                    icon = 'fa-solid fa-bed',
                    type = 'client',
                    event = 'qb-ambulancejob:beds',
                    args = { '$index' },
                    canInteract = 'bed_available',
                },
            },
        },
    },

    EMSPoints = {
        Duty = {
            enabled = true,
            location = 'duty',
            id = 'ambulance_duty',
            groups = { ambulance = 0 },
            options = {
                {
                    name = 'toggle_duty',
                    label = 'Toggle EMS Duty',
                    icon = 'fa-solid fa-clipboard-user',
                    type = 'client',
                    event = 'EMSToggle:Duty',
                    canInteract = 'always',
                },
            },
        },
        Stash = {
            enabled = true,
            location = 'stash',
            id = 'ambulance_stash',
            groups = { ambulance = 0 },
            options = {
                {
                    name = 'open_stash',
                    label = 'Open Personal Stash',
                    icon = 'fa-solid fa-box-open',
                    type = 'client',
                    event = 'qb-ambulancejob:stash',
                    canInteract = 'ems_on_duty',
                },
            },
        },
        Armory = {
            enabled = true,
            location = 'armory',
            id = 'ambulance_armory',
            groups = { ambulance = 0 },
            options = {
                {
                    name = 'open_armory',
                    label = 'Open Medical Supplies',
                    icon = 'fa-solid fa-kit-medical',
                    type = 'client',
                    event = 'qb-ambulancejob:armory',
                    canInteract = 'ems_on_duty',
                },
            },
        },
        Garage = {
            enabled = true,
            location = 'vehicle',
            id = 'ambulance_garage',
            groups = { ambulance = 0 },
            interactDistance = 3.0,
            options = {
                {
                    name = 'open_garage',
                    label = 'Open Ambulance Garage',
                    icon = 'fa-solid fa-truck-medical',
                    type = 'client',
                    event = 'ambulance:client:OpenGarage',
                    args = { '$index' },
                    canInteract = 'ems_on_duty_on_foot',
                },
                {
                    name = 'store_ambulance',
                    label = 'Store Ambulance',
                    icon = 'fa-solid fa-warehouse',
                    type = 'client',
                    event = 'ambulance:client:StoreVehicle',
                    args = { 'vehicle' },
                    canInteract = 'ems_on_duty_in_vehicle',
                },
            },
        },
        Helipad = {
            enabled = true,
            location = 'helicopter',
            id = 'ambulance_helipad',
            groups = { ambulance = 0 },
            interactDistance = 4.0,
            skipZeroCoords = true,
            options = {
                {
                    name = 'deploy_helicopter',
                    label = 'Deploy EMS Helicopter',
                    icon = 'fa-solid fa-helicopter',
                    type = 'client',
                    event = 'ambulance:client:SpawnHelicopter',
                    args = { '$index' },
                    canInteract = 'ems_on_duty_on_foot',
                },
                {
                    name = 'store_helicopter',
                    label = 'Store EMS Helicopter',
                    icon = 'fa-solid fa-warehouse',
                    type = 'client',
                    event = 'ambulance:client:StoreVehicle',
                    args = { 'helicopter' },
                    canInteract = 'ems_on_duty_in_vehicle',
                },
            },
        },
        RoofElevator = {
            enabled = true,
            location = 'roof',
            id = 'ambulance_elevator_roof',
            groups = { ambulance = 0 },
            options = {
                {
                    name = 'elevator_down',
                    label = 'Take Elevator Down',
                    icon = 'fa-solid fa-elevator',
                    type = 'client',
                    event = 'qb-ambulancejob:elevator_roof',
                    args = { '$index' },
                    canInteract = 'ems_on_duty',
                },
            },
        },
        MainElevator = {
            enabled = true,
            location = 'main',
            id = 'ambulance_elevator_main',
            groups = { ambulance = 0 },
            options = {
                {
                    name = 'elevator_roof',
                    label = 'Take Elevator To Roof',
                    icon = 'fa-solid fa-elevator',
                    type = 'client',
                    event = 'qb-ambulancejob:elevator_main',
                    args = { '$index' },
                    canInteract = 'ems_on_duty',
                },
            },
        },
    },

    Players = {
        Examine = {
            enabled = true,
            treatmentType = 'examine',
            id = 'ambulance_check_injuries',
            name = 'examine_patient',
            label = 'Examine Patient',
            icon = 'fa-solid fa-stethoscope',
            type = 'client',
            event = 'hospital:client:CheckStatus',
            args = { '$serverId' },
            canInteract = 'ems_on_duty_other_player',
        },
        Treat = {
            enabled = true,
            treatmentType = 'treat',
            id = 'ambulance_treat_wounds',
            name = 'treat_patient',
            label = 'Treat Wounds',
            icon = 'fa-solid fa-bandage',
            type = 'client',
            event = 'hospital:client:TreatWounds',
            args = { '$serverId' },
            canInteract = 'ems_on_duty_other_player',
        },
        Revive = {
            enabled = true,
            treatmentType = 'revive',
            id = 'ambulance_revive_patient',
            name = 'revive_patient',
            label = 'Attempt Resuscitation',
            icon = 'fa-solid fa-heart-pulse',
            type = 'client',
            event = 'hospital:client:RevivePlayer',
            args = { '$serverId' },
            canInteract = 'ems_on_duty_other_player',
        },
    },
}

-- Timings are in milliseconds. The patient sees a matching progress bar while EMS treats them.
Config.Progress = {
    CheckIn = 3000,
    Examine = 4000,
    Treat = 8000,
    Revive = 10000,
}

-- Players leave hospital beds automatically; no separate leave-bed interaction is shown.
Config.AutoLeaveBed = {
    Enabled = true,
    AfterTreatment = 1500, -- Delay after treatment/revival completes, in milliseconds
    ManualBedTime = 15000, -- How long voluntary bed use lasts before standing up automatically
}

Config.PersonalStash = {
    Label = 'EMS Personal Stash',
    Slots = 50,
    Weight = 250000,
}

Config.TreatmentItems = {
    Treat = 'bandage',
    Revive = 'firstaid',
}
Config.MinimalDoctors = 2 -- How many players with the ambulance job to prevent the hospital check-in system from being used
Config.DocCooldown = 1 -- Cooldown between doctor calls allowed, in minutes
Config.WipeInventoryOnRespawn = false -- Enable or disable removing all the players items when they respawn at the hospital
Config.Helicopter = "EMSSWIFT" -- Helicopter model that players with the ambulance job can use
Config.BillCost = 2000 -- Price that players are charged for using the hospital check-in system
Config.DeathTime = 300 -- How long the timer is for players to bleed out completely and respawn at the hospital
Config.ReviveInterval = 300 -- How long the timer is for players to revive a player in laststand
Config.MinimumRevive = 300 -- How long the timer is for players to revive a player in laststand
Config.PainkillerInterval = 60 -- Set the length of time painkillers last (per one)
Config.HealthDamage = 5 -- Minumum damage done to health before checking for injuries
Config.ArmorDamage = 5 -- Minumum damage done to armor before checking for injuries
Config.ForceInjury = 35 -- Maximum amount of damage a player can take before limb damage & effects are forced to occur
Config.AlwaysBleedChance = 70 -- Set the chance out of 100 that if a player is hit with a weapon, that also has a random chance, it will cause bleeding
Config.MessageTimer = 12 -- How long it will take to display limb/bleed message
Config.AIHealTimer = 20 -- How long it will take to be healed after checking in, in seconds
Config.BleedTickRate = 30 -- How much time, in seconds, between bleed ticks
Config.BleedMovementTick = 10 -- How many seconds is taken away from the bleed tick rate if the player is walking, jogging, or sprinting
Config.BleedMovementAdvance = 3 -- How much time moving while bleeding adds
Config.BleedTickDamage = 8 -- The base damage that is multiplied by bleed level everytime a bleed tick occurs
Config.FadeOutTimer = 2 -- How many bleed ticks occur before fadeout happens
Config.BlackoutTimer = 10 -- How many bleed ticks occur before blacking out
Config.AdvanceBleedTimer = 10 -- How many bleed ticks occur before bleed level increases
Config.HeadInjuryTimer = 30 -- How much time, in seconds, do head injury effects chance occur
Config.ArmInjuryTimer = 30 -- How much time, in seconds, do arm injury effects chance occur
Config.LegInjuryTimer = 15 -- How much time, in seconds, do leg injury effects chance occur
Config.HeadInjuryChance = 25 -- The chance, in percent, that head injury side-effects get applied
Config.LegInjuryChance = { -- The chance, in percent, that leg injury side-effects get applied
    Running = 50,
    Walking = 15
}
Config.MajorArmoredBleedChance = 45 -- The chance, in percent, that a player will get a bleed effect when taking heavy damage while wearing armor
Config.MaxInjuryChanceMulti = 3 -- How many times the HealthDamage value above can divide into damage taken before damage is forced to be applied
Config.DamageMinorToMajor = 35 -- How much damage would have to be applied for a minor weapon to be considered a major damage event. Put this at 100 if you want to disable it
Config.AlertShowInfo = 2 -- How many injuries a player must have before being alerted about them

Config.Locations = { -- Edit the various interaction points for players or create new ones
    ["checking"] = {
        [1] = vector3(307.51, -595.29, 43.12), -- Pillbox
        [2] = vector3(1767.97, 3641.10, 34.70), -- Sandy Shores
    },
    ["duty"] = {
        [1] = vector3(339.77, -571.21, 48.18),
        [2] = vector3(1766.59, 3642.46, 34.76),
    },
    ["vehicle"] = {
        [1] = vector4(280.65, -580.97, 43.15, 77.48),
        [2] = vector3(1776.21, 3633.18, 33.68),
    },
    ["helicopter"] = {
        [1] = vector4(351.13, -588.43, 74.16, 275.13),
        [2] = vector4(0, 0, 0, 0),
    },
    ["armory"] = {
        [1] = vector3(355.79, -577.67, 48.16),
        [2] = vector3(1764.8, 3652.1, 35.66),
    },
    ["roof"] = {
        [1] = vector4(338.52, -583.79, 74.16, 251.90),
    },
    ["main"] = {
        [1] = vector3(315.64, -578.34, 43.28),
    },
    ["stash"] = {
        [1] = vector3(342.70, -581.34, 48.70),
        [2] = vector3(1784.76, 3653.05, 35.03),
    },
    ["beds"] = {
            -- Sandy ward
        [1] =  {coords = vector4(1741.21, 3624.53, 35.69, 304.89), taken = false, model = 835950247},
        [2] =  {coords = vector4(1740.03, 3626.66, 35.69, 299.94), taken = false, model = 835950247},
        [3] =  {coords = vector4(1738.47, 3629.31, 35.69, 300.02), taken = false, model = 835950247},
        [4] = {coords =  vector4(1736.83, 3632.19, 35.69, 301.77), taken = false, model = 835950247},
        [5] = {coords =  vector4(1735.33, 3634.8, 35.69, 299.78),  taken = false, model = 835950247},
            -- Pillbox lower ward
        [6] = {coords = vector4(319.32, -581.06, 44.2, 159.66), taken = false, model = 1631638868},
        [7] = {coords = vector4(313.76, -579.04, 44.2, 162.81), taken = false, model = 1631638868},
        [8] = {coords = vector4(309.17, -577.41, 44.2, 160.0), taken = false, model = 1631638868},
        [9] = {coords = vector4(311.11, -583.16, 44.2, 339.65), taken = false, model = 1631638868},
        [10] = {coords = vector4(314.49, -584.34, 44.2, 338.56), taken = false, model = 1631638868},
        [11] = {coords = vector4(317.74, -585.47, 44.2, 339.25), taken = false, model = 1631638868},
    --- GrandPa
        --[12] = {coords = vector4(1213.51, -495.79, 68.13, 183.38), taken = false, model = 2117668672},
    },
    ["jailbeds"] = {
        [1] = {coords = vector4(1761.99, 2591.56, 46.66, 271.02), taken = false, model = 2117668672},
        [2] = {coords = vector4(1761.96, 2591.51, 45.66, 269.8), taken = false, model = 2117668672},
        [3] = {coords = vector4(1771.8, 2598.02, 45.66, 89.05), taken = false, model = 2117668672},
        [4] = {coords = vector4(1771.85, 2591.85, 45.66, 91.51), taken = false, model = 2117668672},
    },
    ["stations"] = {
        [1] = {label = Lang:t('info.pb_hospital'), coords = vector4(302.59, -588.49, 43.27, 40.43)}
    }
}

Config.AuthorizedVehicles = { -- Vehicles players can use based on their ambulance job grade level
	-- Grade 0
	[0] = {
        ["AMBULANCE"] = "MRSA Ambulance Large",
	},
	-- Grade 1
	[1] = {
        ["AMBULANCE2"] = "MRSA Ambulance Small",
        ["AMBULANCE"] = "MRSA Ambulance Large",

	},
	-- Grade 2
	[2] = {
        ["AMBULANCE2"] = "MRSA Ambulance Small",
        ["AMBULANCE"] = "MRSA Ambulance Large",
        ["EMSSTALKER"] = "MRSA Stalker",
	},
	-- Grade 3
	[3] = {
        ["AMBULANCE2"] = "MRSA Ambulance Small",
        ["AMBULANCE"] = "MRSA Ambulance Large",
        ["EMSSTALKER"] = "MRSA Stalker",
        ["EMSCOMET"] = "MRSA Comet",
	},
	-- Grade 4
	[4] = {
        ["AMBULANCE2"] = "MRSA Ambulance Small",
        ["AMBULANCE"] = "MRSA Ambulance Large",
        ["EMSSTALKER"] = "MRSA Stalker",
        ["EMSCOMET"] = "MRSA Comet",
	}
}

Config.Items = { -- Items found in the ambulance shop for players with the ambulance job to purchase
    label = Lang:t('info.safe'),
    slots = 30,
    items = {
        [1] = {
            name = "radio",
            price = 0,
            amount = 50,
            info = {},
            type = "item",
            slot = 1,
        },
        [2] = {
            name = "bandage",
            price = 0,
            amount = 50,
            info = {},
            type = "item",
            slot = 2,
        },
        [3] = {
            name = "painkillers",
            price = 0,
            amount = 50,
            info = {},
            type = "item",
            slot = 3,
        },
        [4] = {
            name = "firstaid",
            price = 0,
            amount = 50,
            info = {},
            type = "item",
            slot = 4,
        },
        [5] = {
            name = "weapon_flashlight",
            price = 0,
            amount = 50,
            info = {},
            type = "item",
            slot = 5,
        },
        [6] = {
            name = "weapon_fireextinguisher",
            price = 0,
            amount = 50,
            info = {},
            type = "item",
            slot = 6,
        },
    }
}

Config.WeaponClasses = { -- Define gta weapon classe numbers
    ['SMALL_CALIBER'] = 1,
    ['MEDIUM_CALIBER'] = 2,
    ['HIGH_CALIBER'] = 3,
    ['SHOTGUN'] = 4,
    ['CUTTING'] = 5,
    ['LIGHT_IMPACT'] = 6,
    ['HEAVY_IMPACT'] = 7,
    ['EXPLOSIVE'] = 8,
    ['FIRE'] = 9,
    ['SUFFOCATING'] = 10,
    ['OTHER'] = 11,
    ['WILDLIFE'] = 12,
    ['NOTHING'] = 13
}

Config.MinorInjurWeapons = { -- Define which weapons cause small injuries
    [Config.WeaponClasses['SMALL_CALIBER']] = true,
    [Config.WeaponClasses['MEDIUM_CALIBER']] = true,
    [Config.WeaponClasses['CUTTING']] = true,
    [Config.WeaponClasses['WILDLIFE']] = true,
    [Config.WeaponClasses['OTHER']] = true,
    [Config.WeaponClasses['LIGHT_IMPACT']] = true,
}

Config.MajorInjurWeapons = { -- Define which weapons cause large injuries
    [Config.WeaponClasses['HIGH_CALIBER']] = true,
    [Config.WeaponClasses['HEAVY_IMPACT']] = true,
    [Config.WeaponClasses['SHOTGUN']] = true,
    [Config.WeaponClasses['EXPLOSIVE']] = true,
}

Config.AlwaysBleedChanceWeapons = { -- Define which weapons will always cause bleedign
    [Config.WeaponClasses['SMALL_CALIBER']] = true,
    [Config.WeaponClasses['MEDIUM_CALIBER']] = true,
    [Config.WeaponClasses['CUTTING']] = true,
    [Config.WeaponClasses['WILDLIFE']] = false,
}

Config.ForceInjuryWeapons = { -- Define which weapons will always cause injuries
    [Config.WeaponClasses['HIGH_CALIBER']] = true,
    [Config.WeaponClasses['HEAVY_IMPACT']] = true,
    [Config.WeaponClasses['EXPLOSIVE']] = true,
}

Config.CriticalAreas = { -- Define body areas that will always cause bleeding if wearing armor or not
    ['UPPER_BODY'] = { armored = false },
    ['LOWER_BODY'] = { armored = true },
    ['SPINE'] = { armored = true },
}

Config.StaggerAreas = { -- Define body areas that will always cause staggering if wearing armor or not
    ['SPINE'] = { armored = true, major = 60, minor = 30 },
    ['UPPER_BODY'] = { armored = false, major = 60, minor = 30 },
    ['LLEG'] = { armored = true, major = 100, minor = 85 },
    ['RLEG'] = { armored = true, major = 100, minor = 85 },
    ['LFOOT'] = { armored = true, major = 100, minor = 100 },
    ['RFOOT'] = { armored = true, major = 100, minor = 100 },
}

Config.WoundStates = { -- Translate wound alerts
    Lang:t('states.irritated'),
    Lang:t('states.quite_painful'),
    Lang:t('states.painful'),
    Lang:t('states.really_painful'),
}

Config.BleedingStates = { -- Translate bleeding alerts
    [1] = {label = Lang:t('states.little_bleed')},
    [2] = {label = Lang:t('states.bleed')},
    [3] = {label = Lang:t('states.lot_bleed')},
    [4] = {label = Lang:t('states.big_bleed')},
}

Config.MovementRate = { -- Set the player movement rate based on the level of damage they have
    0.98,
    0.96,
    0.94,
    0.92,
}

Config.Bones = { -- Correspond bone hash numbers to their label
    [0]     = 'NONE',
    [31085] = 'HEAD',
    [31086] = 'HEAD',
    [39317] = 'NECK',
    [57597] = 'SPINE',
    [23553] = 'SPINE',
    [24816] = 'SPINE',
    [24817] = 'SPINE',
    [24818] = 'SPINE',
    [10706] = 'UPPER_BODY',
    [64729] = 'UPPER_BODY',
    [11816] = 'LOWER_BODY',
    [45509] = 'LARM',
    [61163] = 'LARM',
    [18905] = 'LHAND',
    [4089] = 'LFINGER',
    [4090] = 'LFINGER',
    [4137] = 'LFINGER',
    [4138] = 'LFINGER',
    [4153] = 'LFINGER',
    [4154] = 'LFINGER',
    [4169] = 'LFINGER',
    [4170] = 'LFINGER',
    [4185] = 'LFINGER',
    [4186] = 'LFINGER',
    [26610] = 'LFINGER',
    [26611] = 'LFINGER',
    [26612] = 'LFINGER',
    [26613] = 'LFINGER',
    [26614] = 'LFINGER',
    [58271] = 'LLEG',
    [63931] = 'LLEG',
    [2108] = 'LFOOT',
    [14201] = 'LFOOT',
    [40269] = 'RARM',
    [28252] = 'RARM',
    [57005] = 'RHAND',
    [58866] = 'RFINGER',
    [58867] = 'RFINGER',
    [58868] = 'RFINGER',
    [58869] = 'RFINGER',
    [58870] = 'RFINGER',
    [64016] = 'RFINGER',
    [64017] = 'RFINGER',
    [64064] = 'RFINGER',
    [64065] = 'RFINGER',
    [64080] = 'RFINGER',
    [64081] = 'RFINGER',
    [64096] = 'RFINGER',
    [64097] = 'RFINGER',
    [64112] = 'RFINGER',
    [64113] = 'RFINGER',
    [36864] = 'RLEG',
    [51826] = 'RLEG',
    [20781] = 'RFOOT',
    [52301] = 'RFOOT',
}

Config.BoneIndexes = { -- Correspond bone labels to their hash number
    ['NONE'] = 0,
    -- ['HEAD'] = 31085,
    ['HEAD'] = 31086,
    ['NECK'] = 39317,
    -- ['SPINE'] = 57597,
    -- ['SPINE'] = 23553,
    -- ['SPINE'] = 24816,
    -- ['SPINE'] = 24817,
    ['SPINE'] = 24818,
    -- ['UPPER_BODY'] = 10706,
    ['UPPER_BODY'] = 64729,
    ['LOWER_BODY'] = 11816,
    -- ['LARM'] = 45509,
    ['LARM'] = 61163,
    ['LHAND'] = 18905,
    -- ['LFINGER'] = 4089,
    -- ['LFINGER'] = 4090,
    -- ['LFINGER'] = 4137,
    -- ['LFINGER'] = 4138,
    -- ['LFINGER'] = 4153,
    -- ['LFINGER'] = 4154,
    -- ['LFINGER'] = 4169,
    -- ['LFINGER'] = 4170,
    -- ['LFINGER'] = 4185,
    -- ['LFINGER'] = 4186,
    -- ['LFINGER'] = 26610,
    -- ['LFINGER'] = 26611,
    -- ['LFINGER'] = 26612,
    -- ['LFINGER'] = 26613,
    ['LFINGER'] = 26614,
    -- ['LLEG'] = 58271,
    ['LLEG'] = 63931,
    -- ['LFOOT'] = 2108,
    ['LFOOT'] = 14201,
    -- ['RARM'] = 40269,
    ['RARM'] = 28252,
    ['RHAND'] = 57005,
    -- ['RFINGER'] = 58866,
    -- ['RFINGER'] = 58867,
    -- ['RFINGER'] = 58868,
    -- ['RFINGER'] = 58869,
    -- ['RFINGER'] = 58870,
    -- ['RFINGER'] = 64016,
    -- ['RFINGER'] = 64017,
    -- ['RFINGER'] = 64064,
    -- ['RFINGER'] = 64065,
    -- ['RFINGER'] = 64080,
    -- ['RFINGER'] = 64081,
    -- ['RFINGER'] = 64096,
    -- ['RFINGER'] = 64097,
    -- ['RFINGER'] = 64112,
    ['RFINGER'] = 64113,
    -- ['RLEG'] = 36864,
    ['RLEG'] = 51826,
    -- ['RFOOT'] = 20781,
    ['RFOOT'] = 52301,
}

Config.Weapons = { -- Correspond weapon names to their class number
    [`WEAPON_STUNGUN`] = Config.WeaponClasses['NONE'],
    [`WEAPON_STUNGUN_MP`] = Config.WeaponClasses['NONE'],
    --[[ Small Caliber ]] --
    [`WEAPON_PISTOL`] = Config.WeaponClasses['SMALL_CALIBER'],
    [`WEAPON_COMBATPISTOL`] = Config.WeaponClasses['SMALL_CALIBER'],
    [`WEAPON_APPISTOL`] = Config.WeaponClasses['SMALL_CALIBER'],
    [`WEAPON_COMBATPDW`] = Config.WeaponClasses['SMALL_CALIBER'],
    [`WEAPON_MACHINEPISTOL`] = Config.WeaponClasses['SMALL_CALIBER'],
    [`WEAPON_MICROSMG`] = Config.WeaponClasses['SMALL_CALIBER'],
    [`WEAPON_MINISMG`] = Config.WeaponClasses['SMALL_CALIBER'],
    [`WEAPON_PISTOL_MK2`] = Config.WeaponClasses['SMALL_CALIBER'],
    [`WEAPON_SNSPISTOL`] = Config.WeaponClasses['SMALL_CALIBER'],
    [`WEAPON_SNSPISTOL_MK2`] = Config.WeaponClasses['SMALL_CALIBER'],
    [`WEAPON_VINTAGEPISTOL`] = Config.WeaponClasses['SMALL_CALIBER'],

    --[[ Medium Caliber ]] --
    [`WEAPON_ADVANCEDRIFLE`] = Config.WeaponClasses['MEDIUM_CALIBER'],
    [`WEAPON_ASSAULTSMG`] = Config.WeaponClasses['MEDIUM_CALIBER'],
    [`WEAPON_BULLPUPRIFLE`] = Config.WeaponClasses['MEDIUM_CALIBER'],
    [`WEAPON_BULLPUPRIFLE_MK2`] = Config.WeaponClasses['MEDIUM_CALIBER'],
    [`WEAPON_CARBINERIFLE`] = Config.WeaponClasses['MEDIUM_CALIBER'],
    [`WEAPON_CARBINERIFLE_MK2`] = Config.WeaponClasses['MEDIUM_CALIBER'],
    [`WEAPON_COMPACTRIFLE`] = Config.WeaponClasses['MEDIUM_CALIBER'],
    [`WEAPON_DOUBLEACTION`] = Config.WeaponClasses['MEDIUM_CALIBER'],
    [`WEAPON_GUSENBERG`] = Config.WeaponClasses['MEDIUM_CALIBER'],
    [`WEAPON_HEAVYPISTOL`] = Config.WeaponClasses['MEDIUM_CALIBER'],
    [`WEAPON_MARKSMANPISTOL`] = Config.WeaponClasses['MEDIUM_CALIBER'],
    [`WEAPON_PISTOL50`] = Config.WeaponClasses['MEDIUM_CALIBER'],
    [`WEAPON_REVOLVER`] = Config.WeaponClasses['MEDIUM_CALIBER'],
    [`WEAPON_REVOLVER_MK2`] = Config.WeaponClasses['MEDIUM_CALIBER'],
    [`WEAPON_SMG`] = Config.WeaponClasses['MEDIUM_CALIBER'],
    [`WEAPON_SMG_MK2`] = Config.WeaponClasses['MEDIUM_CALIBER'],
    [`WEAPON_SPECIALCARBINE`] = Config.WeaponClasses['MEDIUM_CALIBER'],
    [`WEAPON_SPECIALCARBINE_MK2`] = Config.WeaponClasses['MEDIUM_CALIBER'],

    --[[ High Caliber ]] --
    [`WEAPON_ASSAULTRIFLE`] = Config.WeaponClasses['HIGH_CALIBER'],
    [`WEAPON_ASSAULTRIFLE_MK2`] = Config.WeaponClasses['HIGH_CALIBER'],
    [`WEAPON_COMBATMG`] = Config.WeaponClasses['HIGH_CALIBER'],
    [`WEAPON_COMBATMG_MK2`] = Config.WeaponClasses['HIGH_CALIBER'],
    [`WEAPON_HEAVYSNIPER`] = Config.WeaponClasses['HIGH_CALIBER'],
    [`WEAPON_HEAVYSNIPER_MK2`] = Config.WeaponClasses['HIGH_CALIBER'],
    [`WEAPON_MARKSMANRIFLE`] = Config.WeaponClasses['HIGH_CALIBER'],
    [`WEAPON_MARKSMANRIFLE_MK2`] = Config.WeaponClasses['HIGH_CALIBER'],
    [`WEAPON_MG`] = Config.WeaponClasses['HIGH_CALIBER'],
    [`WEAPON_MINIGUN`] = Config.WeaponClasses['HIGH_CALIBER'],
    [`WEAPON_MUSKET`] = Config.WeaponClasses['HIGH_CALIBER'],
    [`WEAPON_RAILGUN`] = Config.WeaponClasses['HIGH_CALIBER'],
    [`WEAPON_HEAVYRIFLE`] = Config.WeaponClasses['HIGH_CALIBER'],

    --[[ Shotguns ]] --
    [`WEAPON_ASSAULTSHOTGUN`] = Config.WeaponClasses['SHOTGUN'],
    [`WEAPON_BULLUPSHOTGUN`] = Config.WeaponClasses['SHOTGUN'],
    [`WEAPON_DBSHOTGUN`] = Config.WeaponClasses['SHOTGUN'],
    [`WEAPON_HEAVYSHOTGUN`] = Config.WeaponClasses['SHOTGUN'],
    [`WEAPON_PUMPSHOTGUN`] = Config.WeaponClasses['SHOTGUN'],
    [`WEAPON_PUMPSHOTGUN_MK2`] = Config.WeaponClasses['SHOTGUN'],
    [`WEAPON_SAWNOFFSHOTGUN`] = Config.WeaponClasses['SHOTGUN'],
    [`WEAPON_SWEEPERSHOTGUN`] = Config.WeaponClasses['SHOTGUN'],

    --[[ Animals ]]                                            --
    [`WEAPON_ANIMAL`] = Config.WeaponClasses['WILDLIFE'],      -- Animal
    [`WEAPON_COUGAR`] = Config.WeaponClasses['WILDLIFE'],      -- Cougar
    [`WEAPON_BARBED_WIRE`] = Config.WeaponClasses['WILDLIFE'], -- Barbed Wire

    --[[ Cutting Weapons ]]                                    --
    [`WEAPON_BATTLEAXE`] = Config.WeaponClasses['CUTTING'],
    [`WEAPON_BOTTLE`] = Config.WeaponClasses['CUTTING'],
    [`WEAPON_DAGGER`] = Config.WeaponClasses['CUTTING'],
    [`WEAPON_HATCHET`] = Config.WeaponClasses['CUTTING'],
    [`WEAPON_KNIFE`] = Config.WeaponClasses['CUTTING'],
    [`WEAPON_MACHETE`] = Config.WeaponClasses['CUTTING'],
    [`WEAPON_SWITCHBLADE`] = Config.WeaponClasses['CUTTING'],

    --[[ Light Impact ]] --
    [`WEAPON_KNUCKLE`] = Config.WeaponClasses['LIGHT_IMPACT'],

    --[[ Heavy Impact ]] --
    [`WEAPON_BAT`] = Config.WeaponClasses['HEAVY_IMPACT'],
    [`WEAPON_CROWBAR`] = Config.WeaponClasses['HEAVY_IMPACT'],
    [`WEAPON_FIREEXTINGUISHER`] = Config.WeaponClasses['HEAVY_IMPACT'],
    [`WEAPON_FIRWORK`] = Config.WeaponClasses['HEAVY_IMPACT'],
    [`WEAPON_GOLFLCUB`] = Config.WeaponClasses['HEAVY_IMPACT'],
    [`WEAPON_HAMMER`] = Config.WeaponClasses['HEAVY_IMPACT'],
    [`WEAPON_PETROLCAN`] = Config.WeaponClasses['HEAVY_IMPACT'],
    [`WEAPON_POOLCUE`] = Config.WeaponClasses['HEAVY_IMPACT'],
    [`WEAPON_WRENCH`] = Config.WeaponClasses['HEAVY_IMPACT'],
    [`WEAPON_RAMMED_BY_CAR`] = Config.WeaponClasses['HEAVY_IMPACT'],
    [`WEAPON_RUN_OVER_BY_CAR`] = Config.WeaponClasses['HEAVY_IMPACT'],

    --[[ Explosives ]] --
    [`WEAPON_EXPLOSION`] = Config.WeaponClasses['EXPLOSIVE'],
    [`WEAPON_GRENADE`] = Config.WeaponClasses['EXPLOSIVE'],
    [`WEAPON_COMPACTLAUNCHER`] = Config.WeaponClasses['EXPLOSIVE'],
    [`WEAPON_HOMINGLAUNCHER`] = Config.WeaponClasses['EXPLOSIVE'],
    [`WEAPON_PIPEBOMB`] = Config.WeaponClasses['EXPLOSIVE'],
    [`WEAPON_PROXMINE`] = Config.WeaponClasses['EXPLOSIVE'],
    [`WEAPON_RPG`] = Config.WeaponClasses['EXPLOSIVE'],
    [`WEAPON_STICKYBOMB`] = Config.WeaponClasses['EXPLOSIVE'],
    [`WEAPON_HELI_CRASH`] = Config.WeaponClasses['EXPLOSIVE'],
    [`WEAPON_EMPLAUNCHER`] = Config.WeaponClasses['EXPLOSIVE'],

    --[[ Other ]]                                                   --
    [`WEAPON_FALL`] = Config.WeaponClasses['OTHER'],                -- Fall
    [`WEAPON_HIT_BY_WATER_CANNON`] = Config.WeaponClasses['OTHER'], -- Water Cannon

    --[[ Fire ]]                                                    --
    [`WEAPON_ELECTRIC_FENCE`] = Config.WeaponClasses['FIRE'],
    [`WEAPON_FIRE`] = Config.WeaponClasses['FIRE'],
    [`WEAPON_MOLOTOV`] = Config.WeaponClasses['FIRE'],
    [`WEAPON_FLARE`] = Config.WeaponClasses['FIRE'],
    [`WEAPON_FLAREGUN`] = Config.WeaponClasses['FIRE'],

    --[[ Suffocate ]]                                                     --
    [`WEAPON_DROWNING`] = Config.WeaponClasses['SUFFOCATING'],            -- Drowning
    [`WEAPON_DROWNING_IN_VEHICLE`] = Config.WeaponClasses['SUFFOCATING'], -- Drowning Veh
    [`WEAPON_EXHAUSTION`] = Config.WeaponClasses['SUFFOCATING'],          -- Exhaust
    [`WEAPON_BZGAS`] = Config.WeaponClasses['SUFFOCATING'],
    [`WEAPON_SMOKEGRENADE`] = Config.WeaponClasses['SUFFOCATING'],
}

Config.VehicleSettings = { -- Enable or disable vehicle extras when pulling them from the ambulance job vehicle spawner
    ["car1"] = { -- Model name
        ["extras"] = {
            ["1"] = false, -- on/off
            ["2"] = true,
            ["3"] = true,
            ["4"] = true,
            ["5"] = true,
            ["6"] = true,
            ["7"] = true,
            ["8"] = true,
            ["9"] = true,
            ["10"] = true,
            ["11"] = true,
            ["12"] = true,
        }
    },
    ["car2"] = {
        ["extras"] = {
            ["1"] = false,
            ["2"] = true,
            ["3"] = true,
            ["4"] = true,
            ["5"] = true,
            ["6"] = true,
            ["7"] = true,
            ["8"] = true,
            ["9"] = true,
            ["10"] = true,
            ["11"] = true,
            ["12"] = true,
        }
    }
}
