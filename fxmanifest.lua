fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'nn_scripts'
description 'Multiplayer Postman delivery job'
version '1.0.0'

ui_page 'web/dist/index.html'

files {
  'web/dist/index.html',
  'web/dist/assets/**/*',
  'web/dist/gta-map.png',
  'web/dist/gta-map.jpg',
  'web/dist/gta-map-dark.png',
  'web/dist/gta-map-dark.jpg',
  'web/dist/vite.svg',
}

dependencies {
    'community_bridge',
    'oxmysql'
}

shared_scripts {
    'shared/config.lua',
}

client_scripts {
  'client/playerinvite.lua',
  'client/main.lua',
  'client/reputation.lua',
}

server_scripts {
  'server/playerinviteserver.lua',
  'server/sv_missions.lua',
  'server/sv_spawning.lua',
  'server/sv_reputation.lua'
}

escrow_ignore {
  'shared/*.lua',
}
