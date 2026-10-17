# Improved qb-ambulancejob

A rebuilt QBCore ambulance job configured for **interact**, **ox_inventory**, **qb-menu**, QBCore progress bars/notifications/callbacks, and a configurable fuel resource.

## Main changes

- All hospital world interactions now use `interact`:
  - duty desks
  - personal stashes
  - medical supply shops
  - ambulance garages
  - helicopter pads
  - elevators
  - hospital check-in desks
  - every configured hospital bed
- EMS patient actions are available by targeting the player directly:
  - Examine Patient
  - Treat Wounds
  - Attempt Resuscitation
- Treatment progress is synchronized for both people:
  - the medic sees their treatment action and animation
  - the patient sees a matching progress bar while being examined, treated, or revived
  - hospital nurse treatment also has a full progress bar
- Medical actions validate duty, distance, target, required item, and completed treatment time on the server.
- `ox_inventory` medical shop and unique per-character EMS stashes are registered automatically.
- Garage improvements include spawn-point blocking checks, authorised vehicle checks, safe storage, keys, and configurable fuel support.
- Bed occupancy, doctor counts, disconnect cleanup, and player-target selection are more reliable.
- Removed the old qb-target, PolyZone, DrawText, starlight-textui, and hard-coded starlight-fuel interaction paths.

## Required resources

Start these before this resource:

```cfg
ensure qb-core
ensure oxmysql
ensure ox_inventory
ensure progressbar
ensure qb-menu
ensure interact
ensure interact-sound
ensure qb-ambulancejob
```

Your existing phone, dispatch, death-screen, emote, vehicle-key, police, and HUD resources may still be used by their original integrations.

## Configuration

The new integration settings are at the top of `config.lua`:

```lua
Config.InteractResource = 'interact'
Config.Inventory = 'ox_inventory'
Config.Fuel = 'cdn-fuel'
Config.Dispatch = 'karma-dispatch'
```

Every interaction is now defined in `Config.Interactions`. You can change an
interaction without editing `client/main.lua` or `client/job.lua`:

```lua
Config.Interactions.EMSPoints.Stash = {
    enabled = true,
    location = 'stash', -- Uses Config.Locations.stash
    id = 'ambulance_stash',
    groups = { ambulance = 0 },
    distance = 8.0,
    interactDistance = 1.6,
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
}
```

Interaction sections:

- `Config.Interactions.Hospital` controls check-in desks and beds.
- `Config.Interactions.EMSPoints` controls duty, stash, armory, garages, helipads, and elevators.
- `Config.Interactions.Players` controls examine, treatment, and resuscitation options.
- `Config.Interactions.Defaults` controls fallback world/player distances and player offsets.

Set `enabled = false` to disable an interaction. The supported condition names are
listed in the comments above `Config.Interactions`. Use `args = { '$index' }` for the current
location index and `args = { '$serverId' }` for the selected patient. Coordinates
remain under `Config.Locations`, or a definition can use its own `points = { ... }`
table instead of a `location` reference.

Supported fuel values in the included bridge:

- `cdn-fuel`
- `ps-fuel`
- `LegacyFuel`
- `ox_fuel`
- `none`

Dispatch alerts default to `karma-dispatch`. Set `Config.Dispatch` to `starlight-dispatch` or `none` when needed. The dispatch call is protected, so a missing dispatch resource will not crash the ambulance script.

Treatment timings are configurable in milliseconds:

```lua
Config.Progress = {
    CheckIn = 3000,
    Examine = 4000,
    Treat = 8000,
    Revive = 10000,
}
```

Treatment items are also configurable:

```lua
Config.TreatmentItems = {
    Treat = 'bandage',
    Revive = 'firstaid',
}
```

## ox_inventory items

The default resource expects these existing items:

- `bandage`
- `firstaid`
- `painkillers`
- `ifaks`
- `radio`
- `weapon_flashlight`
- `weapon_fireextinguisher`

The medical shop is built from `Config.Items`. The personal stash size and weight are controlled by `Config.PersonalStash`.

## Hospital locations

Add or edit coordinates under `Config.Locations`. Each configured point is registered with `interact` automatically when the resource starts.

The Sandy Shores check-in point currently uses the first available configured hospital bed if no local bed is within range. Add Sandy bed coordinates under `Config.Locations.beds` to keep treatment entirely at that hospital.

## Notes

- Replace the old resource folder rather than running both versions.
- Restart `qb-ambulancejob` after changing interaction coordinates or shop configuration.
- The death-screen help and respawn controls remain keyboard controls because they are part of the incapacitated-player UI, not a world interaction.

## License

This resource remains under the original GNU General Public License included in `LICENSE`.

### Automatic bed exit

The leave-bed interaction has been removed. Patients automatically stand up after AI treatment, and voluntary bed use ends after `Config.AutoLeaveBed.ManualBedTime`. Both delays can be changed in `config.lua`.

## Bandage sound (`interact-sound`)

This version uses `interact-sound`; it does not load audio from the ambulance resource itself.

1. Copy `bandage.ogg` to:

   `interact-sound/client/html/sounds/bandage.ogg`

2. Start resources in this order:

   ```cfg
   ensure interact-sound
   ensure qb-ambulancejob
   ```

3. Change the sound settings under `Config.InteractSound` in `config.lua`.

Self-bandaging and EMS wound treatment play for the player and everyone within the configured radius.



## Bandage audio (v2.2.3)

The `bandage` item now plays an audio cue for **the player using it and nearby players**
(default 5 metres). This works when the bandage is used through the normal QBCore
usable-item callback **or** through a native `ox_inventory` item-use action.
EMS treating a patient also plays the same sound. Duplicate events are throttled.

This resource **does not include the audio recording**. Put your existing
`bandage.ogg` file at:

```text
interact-sound/client/html/sounds/bandage.ogg
```

Verify that your `interact-sound/fxmanifest.lua` includes that file in its
`files` list. Ensure `interact-sound` starts before `qb-ambulancejob`. If your
`interact-sound` fork uses a different sounds folder, follow that fork's layout.

Use `/testbandagesound` in-game to confirm the audio file loads locally before
testing a real bandage with two nearby players. Change `Volume`, `Distance`,
`Nearby` and `StartDelay` under `Config.InteractSound.Bandage` in `config.lua`.
`Nearby = false` makes bandage audio audible only to the player using it.

## Bandage sound trigger fix (v2.2.4)

- Self-use through `hospital:client:UseBandage` now requests the sound at the
  beginning of the action, before the progressbar starts.
- Self-use through a **native ox_inventory bandage** is caught by the server's
  `ox_inventory:usedItem` event, after the item is successfully used.
- Version 2.2.4 used only the after-use handler for native inventory items.
  Version 2.2.5 reintroduces a pre-use hook to play the sound immediately.
  Repeated requests within 2.5 seconds are suppressed.
- The original EMS treatment sound and `/testbandagesound` remain available.
- To diagnose routing, set `Config.InteractSound.Debug = true`, restart the
  ambulance resource and use a bandage. Server console should show which
  route triggered the audio. Turn Debug back off after testing.

**Important:** The F8 JavaScript error `Cannot destructure property 'action' of
'r.data' as it is null` originates from `ox_lib`'s UI. It is not an
interact-sound playback error. If it continues, investigate the `ox_lib`
NUI message producer / version separately; this patch does not replace ox_lib.


## Bandage timing fix (v2.2.5)

- Native `ox_inventory` bandage use now plays the audio at the **start** using the `usingItem` hook (before the inventory progress bar), rather than at the end via `usedItem`.
- `StartDelay = 0` by default. There is no additional timer at the start of the bandage animation.
- The `usedItem` event is retained as a fallback if a custom inventory build does not support the hook, without repeating the sound on normal completed uses.
- Client QBCore self-bandage and EMS treatment continue to work, with server-side nearby playback, 5-metre default radius, and cooldown.
- Audio intentionally starts even if the player cancels their bandage afterward (the same way the bandage animation starts before completion).

### ox_lib console error (separate issue)

If F8 shows `Cannot destructure property 'action' of 'r.data' as it is null`, the `ox_lib` browser UI received a null message. This ambulance resource does not send NUI messages directly, so the specific message producer must be identified in your **installed `ox_lib`**, its NUI page or another interacting resource. This sound patch does not modify ox_lib, and will not reliably remove that error by itself. Please provide your `ox_lib` folder/ZIP to investigate the exact UI handler and fix the null payload safely. Avoid replacing a minified JavaScript bundle based only on its hashed filename.

To diagnose timing, set `Config.InteractSound.Debug = true` and watch for `ox_inventory:usingItem (start)` in the server console. If only `usedItem (fallback)` appears, your inventory build is not invoking the start hook.
