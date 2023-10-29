fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'kartik2618 (ByteCode Studios)'
description 'Loan Management System'
version '1.0'

shared_scripts {
	'@ox_lib/init.lua',
	'config.lua'
}

server_scripts {
	'@oxmysql/lib/MySQL.lua',
	'server/utils.lua',
	'server/main.lua',
}

client_scripts {
	'client/utils.lua',
	'client/main.lua',
}

dependencies {
	'oxmysql',
	'ox_lib',
}
