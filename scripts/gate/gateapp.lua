require "common.class"
local EventEmitter = require("common.eventemitter")
local Socket = require("gate.socket")

local GateApp = class(EventEmitter, function(self)
	self.type = Server.type()
    self.id   = Server.id()
    self.host = Server.host()
	self.port = Server.port()
	
	self.logger = {}
    local system_log = string.format("%s_%d", self.type, self.id)
    self.logger = CLogger.new(system_log, true, true, 2)
	
	self.pbcodec = require("libs.pbcodec")
    self.pbcodec:reset()
    self.pbcodec:add_pb_path({"./proto"})
    self.pbcodec:load_file("common.proto")
    self.pbcodec:load_file("server_common.proto")	
end)

function GateApp:main()

	self.pbcodec:load_file("gate.proto")
	self.pbcodec:load_file("lobby.proto")
	local ClientMgr = require("gate.clientmgr")
	local LobbyMgr = require("gate.lobbymgr")
	local LoginMgr = require("gate.loginmgr")
	
	self.sockets = {}
	self.clientmgr = ClientMgr(self)
	self.loginmgr = LoginMgr(self)
	self.lobbymgr = LobbyMgr(self)
end

function GateApp:on_connect(csocket)
	local stype = csocket:stype()
	local sid = csocket:get_sid()
	
	if stype == 2 then
		self:emit("client_onconnect", csocket)
	else
		local identity = {name=self.type, id=self.id}
		self:send_msg(csocket, "common.server.Identity", identity)
		assert(stype == 1 or stype == 3)
		assert(self.sockets[sid] == nil)
		self.sockets[sid] = Socket(csocket, self)
	end
	self.logger:info("on_connect:"..sid.." stype:"..stype)
end

function GateApp:on_close(csocket)
	local sid = csocket:get_sid()
	assert(self.sockets[sid] ~= nil)
	local socket = self.sockets[sid]
	socket:emit("on_close")
	self.logger:info("on_close:"..sid.." stype:"..csocket:stype())
end

function GateApp:on_message(csocket, data)
	local sid = csocket:get_sid()
	assert(self.sockets[sid] ~= nil)
	local socket = self.sockets[sid]
	local pbHead = self.pbcodec:decode("common.MsgHead", data)
	if pbHead == nil or pbHead.proto == nil or pbHead.proto == "" then
		self.logger:error("decode message head failed")
		return
    end
	
	socket:emit("on_message", pbHead.proto, pbHead.data)
end

function GateApp:send_msg(csocket, msgname, msg)
    local dataBytes = self.pbcodec:encode(msgname, msg)
	local headBytes = self.pbcodec:encode("common.MsgHead", {proto = msgname, data = dataBytes})
	csocket:send(headBytes)
end

function GateApp:send(csocket, msgname, msgbyte)	
	local headBytes = self.pbcodec:encode("common.MsgHead", {proto = msgname, data = msgbyte})
	csocket:send(headBytes)
end

function GateApp:enum(etype, ev)
	return self.pbcodec.pb.enum(etype, ev)
end

return GateApp