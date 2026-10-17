fx_version 'cerulean'
game 'gta5'

name 'qb-ambulancejob'
description 'Improved QBCore ambulance job with interact and ox_inventory support'
version '2.2.8'
lua54 'yes'

shared_scripts {
    '@qb-core/shared/locale.lua',
    'locales/en.lua',
    'locales/*.lua',
    'config.lua'
}

client_scripts {
    'client/sounds.lua',
    'client/main.lua',
    'client/wounding.lua',
    'client/laststand.lua',
    'client/job.lua',
    'client/dead.lua'
}

ui_page 'web/bandage-audio.html'

files {
    'web/bandage-audio.html',
    'web/bandage-audio.js'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua'
}

dependencies {
    'qb-core',
    'interact',
    'interact-sound',
    'qb-menu',
    'progressbar',
    'ox_inventory'
}
