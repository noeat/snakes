local handler = {}

function handler.ClientExit(message, client)
	local app = client.app
	app.logger:info("clientexit:"..message.accountid)
	app.playermgr:player_exit(message.accountid)
end


return {
	package = "common.server",
	handler = handler
}