local Socket = require "gate.socket"

local LobbyClient = class(Socket, function(self, csocket, app)
	self:removeAllListeners("on_message", "on_close")
	self.server_id = 0
	self:on("on_message", function(msgname, msgbyte)
		self:handle_message(msgname, msgbyte)
	end)	
	
	self:on("on_close", function()
		self.app.lobbymgr.lobby = nil
	end)
end)

function LobbyClient:handle_message(msgname, msgbyte)
	self.app.lobbymgr:handle_message(msgname, msgbyte)
end

local LobbyMgr = class(function(self, app)
	self.app = app
	self.lobby = nil
	self.handlers = {}
	self.app:on("lobby_identity", function(id, csocket)
		local sid = csocket:get_sid()
		local socket = LobbyClient(csocket, self.app)
		assert(self.app.sockets[sid] ~= nil)
		self.app.sockets[sid] = socket
		socket.server_id = id
		self.lobby = socket
		print("xxxxx")
	end)	
end)

function LobbyMgr:forward_message(accid, msgname, msgbyte)
	print("forward_message:"..msgname)
	print(self.lobby)
	assert(accid ~= nil)
	assert(self.lobby ~= nil)
	--local msg = {uid=accid, proto=msgname, data=msgbyte}
	self.app:send(self.lobby.csocket, msgname, msgbyte)	
end

function LobbyMgr:load_handle(...)
	for i, v in pairs({...}) do
		self:load_handle_imp(v)
	end
end

function LobbyMgr:load_handle_impl( path)
	local result = dofile(path)
	assert(result ~= nil and result.handler ~= nil and result.package ~= nil)
	for i, v in pairs(result.handler) do
		self.handlers[result.package..i] = v
	end
end

function LobbyMgr:handle_message(msgname, msgbyte)
	local message = self.app.pbcodec:decode(msgname, msgbyte)
	if message == nil then
		self.app.logger:error("lobbymgr decode msg failed. "..msgname)
		return
	end

	if message.accountid ~= nil then
		local client = self.app.clientmgr:get_client(message.accountid)
		self.app:send_msg(client.csocket, msgname, message)
	end
end

function LobbyMgr:client_exit(accid)
	local msg = {accountid=accid}
	self.app:send_msg(self.lobby.csocket, "common.server.ClientExit", msg)
end

return LobbyMgr