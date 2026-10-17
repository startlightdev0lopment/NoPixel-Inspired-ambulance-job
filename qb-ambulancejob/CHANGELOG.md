## v2.2.8 - Continuous bandaging audio
- Loop `bandage.ogg` while self-bandaging or EMS treatment progresses, then stop on completion or cancellation.
- Replace fire-and-forget bandage sound playback with a hidden local NUI audio player referencing the existing interact-sound OGG file.
- Preserve nearby hearing radius, volume and the existing self-use and treatment flows.
- Stop playback for the same audience even if somebody moves away; add automatic safety cleanup if progress callbacks fail.
- `/testbandagesound` now tests the four-second controllable loop.

## v2.2.7 - Custom bandage emote
- Use `items@clear@custom_anim` / `bandage` for QBCore bandage progress animation.
- Keep the sound at item-use start and reuse the same animation for cleanup on completion or cancellation.
- Add `Config.BandageAnimation` so the animation and duration can be adjusted without editing client code.
- Native ox_inventory bandage uses its item-defined animation; see `BANDAGE-ANIMATION-SETUP.txt` for the matching entry.

## 2.2.2 - QBCore-only utility layer

- Removed the obsolete external utility-library dependency.
- Confirmed all progress bars use `QBCore.Functions.Progressbar`.
- Confirmed all notifications and callbacks use QBCore.
- Confirmed all menus use `qb-menu`.
- Updated the installation order to use the QBCore utility stack only.

# Changelog

## 2.2.0 - interact-sound bandaging

- Added configurable `interact-sound` support for bandaging.
- Self-bandaging uses `InteractSound_SV:PlayOnSource`.
- EMS wound treatment uses `InteractSound_SV:PlayWithinDistance`, allowing the medic and nearby patient to hear it.
- Added resource-state protection and a one-time console warning when `interact-sound` is not started.
- Added an install-ready `bandage.ogg` copy alongside the packaged resource.

## 2.1.0

### Config-driven interactions
- Moved every interact ID, label, icon, distance, group, condition, event, and event argument into `Config.Interactions`.
- Added generic interaction registration for hospital points, EMS job points, and player targeting.
- Added per-interaction enable switches and optional direct `points` tables.
- Server treatment distance validation now follows the matching configured player interaction distance.

## 2.0.0

### Interactions
- Converted duty, stash, armory, garage, helicopter, elevator, check-in, and bed points to `interact`.
- Added direct global player interactions for EMS examination, wound treatment, and resuscitation.
- Removed qb-target and PolyZone dependencies.

### Treatment
- Added synchronized medic and patient progress bars.
- Added patient movement locking during active treatment.
- Added hospital nurse treatment progress.
- Added server-side treatment sessions so completion events cannot be fired before the configured action time.
- Added server validation for EMS duty, player distance, required items, patient state, and target identity.

### Inventory and vehicles
- Added automatic ox_inventory medical shop registration.
- Added unique ox_inventory personal EMS stashes.
- Added configurable fuel support with cdn-fuel as the default.
- Added blocked-spawn checks and authorised EMS vehicle validation.

### Reliability
- Fixed duplicate/negative doctor counting and refreshes the live doctor count at check-in.
- Added bed and treatment cleanup on disconnect.
- Added server-owned bed occupancy validation.
- Fixed the Sandy Shores hospital blip variable and label.
- Removes registered interact entries cleanly when the resource stops.
- Removed hard-coded starlight-textui and starlight-fuel usage.
- Added a safe configurable dispatch bridge, defaulting to karma-dispatch.

- Removed the `Leave Hospital Bed` interaction.
- Added automatic bed exit after treatment/revival.
- Added configurable automatic exit timing for voluntary bed use.

## 2.2.1 - interact-sound playback fix

- Self-bandaging now calls `InteractSound_CL:PlayOnOne` directly for compatibility with forks that do not include `InteractSound_SV:PlayOnSource`.
- Added `/testbandagesound` for direct playback testing.
- Added an explicit reminder that `bandage.ogg` must be included in `interact-sound/fxmanifest.lua`.

## 2.2.4 - Bandage item route fix

- Start self-bandage audio from the actual hospital client item-use event.
- Listen for `ox_inventory:usedItem` server event for native ox bandages.
- Remove pre-use `usingItem` hook that could trigger prematurely or be bypassed.
- Add optional `Config.InteractSound.Debug` route logging.
