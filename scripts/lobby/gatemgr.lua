local EventEmitter = require("common.eventemitter")

local GateClient = class(EventEmitter, function(self, csocket, app)
	self.app = app
	self.csocket = csocket
	
	self:on("on_message", function(msgname, msgbyte)
		self:handle_message(msgname, msgbyte)
	end)
end)

function GateClient:handle_message(msgname, msgbyte)
	self.app.gatemgr:handle_message(self, msgname, msgbyte)
end

local GateMgr = class(function(self, app)
	self.app = app
	self.gates = {}
	self.app:on("gate_identity", function(id, csocket)
		local sid = csocket:get_sid()
		assert(self.app.sockets[sid] ~= nil)
		local socket = GateClient(csocket, self.app)
		socket.id = id
		self.app.sockets[sid] = socket
		self.gates[id] = socket
	end)
	
	self.handlers = {}
	self:load_file("./scripts/lobby/login_handler.lua",
					"./scripts/lobby/commonserver_handler.lua")
end)

function GateMgr:load_file(...)
	for i, v in pairs({...}) do
		self:load_file_impl(v)
	end
end

function GateMgr:load_file_impl(path)
	local result = dofile(path)
	assert(result.package ~= nil)
	if result ~= nil then
		for i, v in pairs(result.handler) do
			if type(v) == "function" then
				self.handlers[result.package.."." ..i] = v
			end
		end
	end
end

function GateMgr:handle_message(client, msgname, msgbyte)
	local message = self.app.pbcodec:decode(msgname, msgbyte)
	if message == nil then
		self.app.logger:error("decode msg failed. msg:"..msgname)
		return
	end
	
	if self.handlers[msgname] == nil then
		self.app.logger:error("msg: "..msgname .. " cant find handle")
		return
	end
	
	self.handlers[msgname](message, client)
end

function GateMgr:get_gate(id)
	return self.gates[id]
end

return GateMgr