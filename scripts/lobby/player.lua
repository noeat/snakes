require "common.class"
local EventEmitter = require("common.eventemitter")
 
local Player = class(EventEmitter, function(self, app)
	self.app = app
	self.roleid = 0
	self.accountid = 0
	self.gateserverid = 0
	self.rolename = ""
	self.profession = 1
	self.mapid = 1
	self.attack = 1
	self.blood = 1
	self.defense = 1
	self.glod = 1
	self.grade = 1
	self.mana = 1
	self.speed = 1
	self.exp = 1
	self.x = 0
	self.y = 0
	self.eye = 3
end)

function Player:exit()
	self.app:emit("leave_"..self.mapid, self)
	self.app.logger:info("player:"..self.rolename..":"..self.roleid.." exit world")
end

function Player:send_msg(msgname, message)
	local gate = self.app.gatemgr:get_gate(self.gateserverid)
	assert(gate ~= nil)
	message.accountid = self.accountid
	self.app:send_msg(gate.csocket, msgname, message)
end

return Player