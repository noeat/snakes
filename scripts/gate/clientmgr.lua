require ("common.class")
local Socket = require("gate.socket")

local Client = class(Socket, function(self, csocket, app)
	self:removeAllListeners("on_message", "on_close")
	self:on("on_message", function(msgname, message)
		self:handle_message(msgname, message)
	end)	
	
	self.auth_timer = CTimer.new(10000, 0, function()
		self.auth_timer:stop()
		self.auth_timer = nil
		self.csocket:close(-1)
		self.app.logger:error("client auth timeout: "..csocket:get_sid())
	end)
	
	self:on("on_close", function()
		if self.auth_timer ~= nil then
			self.auth_timer:stop()
			self.auth_timer = nil
		end

		if self.accountid ~= nil then
			self.app.lobbymgr:client_exit(self.accountid)
			self.app.clientmgr.clients[self.accountid] = nil
		end
	end)
end)

function Client:handle_message(msgname, msgbyte)
	if msgname == "gate.Auth" then
		self:handle_auth(msgbyte)
	else
		self:forward_message(msgname, msgbyte)
	end
end

function Client:handle_auth(msgbyte)
	self.app.logger:trace("handle_auth "..self.csocket:get_sid())
	local message = self.app.pbcodec:decode("gate.Auth", msgbyte)
	print("accid:"..message.accountid)
	self.app.loginmgr:auth(message.accountid, message.sessionkey)
	self.app.clientmgr.clients[message.accountid] = self
	self.accountid = message.accountid
	print("handle_auth:"..message.accountid)
end

function Client:forward_message(msgname, msgbyte)
	print(msgname)
	local types = {}
	string.gsub(msgname, "%w+", function(w) table.insert(types, w) end)
	if types[1] == "login" then
		error("login msg faild.");
		self.app.loginmgr:forward_message(self.accountid, msgname, msgbyte)
	elseif types[1] == "lobby" then
		self.app.lobbymgr:forward_message(self.accountid, msgname, msgbyte)
	else
		error("unknow servertype"..msgname..": "..types[1])
	end
end

local ClientMgr = class(function(self, app)
	self.app = app
	self.clients = {}
		
	self.app:on("client_onconnect", function(csocket)
		local sid = csocket:get_sid()
		local socket = Client(csocket, self.app)
		assert(self.app.sockets[sid] == nil)
		self.app.sockets[sid] = socket
	end)
end)

function ClientMgr:auth_res(accid, errcode)
	print(accid)
	print(errcode)
	if self.clients[accid] ~= nil then
		local client = self.clients[accid]
		if errcode ~= 0 then		
			self.app.logger:error("account: "..accid .. " auth faild " ..errcode)
			client.csocket:close(-2)			
		else
			client.auth_timer:stop()
			client.auth_timer = nil
		end
	end
end

function ClientMgr:get_client(accid)
	local client = self.clients[accid]
	assert(client ~= nil, "client null "..accid)
	return client
end

return ClientMgr