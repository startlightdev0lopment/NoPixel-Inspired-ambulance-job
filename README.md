# NoPixel-Inspired Ambulance Job

A NoPixel-inspired ambulance job for FiveM, designed for **QBCore** and **ox_inventory**.

Features an advanced EMS system, hospital interactions, medical treatment, death and last-stand handling, and immersive bandage audio.

## Features

- Advanced EMS job interactions using `interact`
- Hospital check-in and bed system
- Patient examination, treatment and resuscitation
- Death and last-stand handling with external death-screen integration
- EMS duty, garages, helicopter access and personal stashes
- Medical shops powered by `ox_inventory`
- Looping bandage sound with nearby-player audio
- Configurable animations, treatment times and locations
- Fuel and dispatch integration options

## Requirements

**Required resources:**
- `qb-core`
- `ox_inventory`
- `ox_lib`
- `oxmysql`
- `interact`
- `interact-sound`
- `qb-menu`
- `progressbar`

**Optional:** A compatible death-screen resource, dispatch and fuel system.

## Installation

1. Download and extract the resource.
2. Place `qb-ambulancejob` inside your server's resources folder.
3. Install all required dependencies.
4. Add the following to `server.cfg`:

```cfg
ensure qb-core
ensure ox_lib
ensure oxmysql
ensure ox_inventory
ensure qb-menu
ensure progressbar
ensure interact
ensure interact-sound
ensure qb-ambulancejob
```

5. Configure `config.lua` for your server.
6. Restart your server.

## Bandage Sound

Add your `bandage.ogg` file to:

`interact-sound/client/html/sounds/bandage.ogg`

Make sure it is included in the `interact-sound` resource manifest.

The sound loops while bandaging and stops when treatment completes or is cancelled.

Use `/testbandagesound` to test the audio.

## Important Notes

- The custom bandage animation `items@clear@custom_anim` requires a separately streamed `.ycd` animation. 

you will need - custom_animations by karma-devlopments from there emotes package 

- The script supports external death-screen events but does not include a standalone death-screen UI.
- Configure your hospital locations, EMS interactions and optional integrations in `config.lua`.

## License

GPL-3.0. See the included `LICENSE` file.

This is a community-made NoPixel-inspired resource and is not officially affiliated with NoPixel.
