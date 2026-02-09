fx_version 'cerulean'
game 'gta5'

description 'Advanced Laser Dot Script'
version '1.0.0'

shared_scripts {
    '@ox_lib/init.lua',
    '@qb-core/shared/locale.lua'
}

client_scripts {
    'client.lua'
}

server_scripts {
    'server.lua'
}

exports {
    'useLaserItem'
}

dependencies {
    'ox_inventory',
    'ox_lib',
    'qb-core'
}