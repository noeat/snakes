-- ================================= load ===================================
package.cpath = package.cpath .. ";./luamod/?.dll"
package.cpath = package.cpath .. ";./luamod/?.so"
package.path = "./?.lua;"
package.path = package.path .. "./scripts/?.lua;"
local LobbyApp = require "lobby.lobbyapp"
app = LobbyApp()

-- ================================= callback ===================================
function on_connect(session)
	app:on_connect(session)
end

function on_close(session)
	app:on_close(session)
end

function on_message(session, data)
	app:on_message(session, data)
end

function on_start()
	app:main()
	app.logger:info(string.format("server:[%s:%d] running.", Server.type(), Server.id()))
end

function on_stop()
	app.logger:info(string.format("server:[%s:%d] stoped.", Server.type(), Server.id()))
end