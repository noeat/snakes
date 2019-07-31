require "common.class"
local Socket = require "gate.socket"

local LoginClient = class(Socket, function(self, csocket, app)
	self:removeAllListeners("on_message", "on_close")
	self.server_id = 0
	self:on("on_message", function(msgname, msgbyte)
		self:handle_message(msgname, msgbyte)
	end)	
	
	self:on("on_close", function()
		self.app.loginmgr.login = nil
		self.report_timer:stop()
		self.report_timer = nil
	end)
	
	self.report_timer = CTimer.new(5000, 0, function()
		local msg = {
			serverid = self.app.id,
			onlinenum = #self.app.clientmgr.clients,
			gate_host = self.app.host,
			gate_port = self.app.port}
			
		self.app:send_msg(self.csocket, "common.server.GateInfoNotice", msg)
		return true
	end)
end)

function LoginClient:handle_message(msgname, msgbyte)
	if msgname == "common.server.AuthSessionRep" then
		self:handle_authrep(msgbyte)
	else
		error("login recv unknow msg "..msgname)
	end
end

function LoginClient:handle_authrep(msgbytes)
	self.app.logger:trace("handle_authrep")
	local msg = self.app.pbcodec:decode("common.server.AuthSessionRep", msgbytes)
	self.app.clientmgr:auth_res(msg.accountid, msg.error_code)
end

local LoginMgr = class(function(self, app) 
	self.app = app
	self.login = nil
	
	self.app:on("login_identity", function(id, csocket)
		local sid = csocket:get_sid()
		local socket = LoginClient(csocket, self.app)
		assert(self.app.sockets[sid] ~= nil)
		self.app.sockets[sid] = socket
		socket.server_id = id
		self.login = socket
	end)
end)

function LoginMgr:auth(accid, sesskey)
	assert(self.login ~= nil)
	local msg = 
	{
		sessionkey = sesskey,
		accountid = accid
	}
	
	print("xxx")
	self.app:send_msg(self.login.csocket, "common.server.AuthSession", msg)	
end

return LoginMgr