require "common.class"
local EventEmitter = require("common.eventemitter")

local Socket = class(EventEmitter, function(self, csocket, app) 
	self.app = app
	self.csocket = csocket
	local identity = {name=self.app.type, id=self.app.id}
	self.app:send_msg(csocket, "common.server.Identity", identity)
	self:on("on_message", function(msgname, msgbyte)
		if msgname == "common.server.Identity" then
			local message = self.app.pbcodec:decode(msgname, msgbyte)
			self.app:emit(message.name.."_identity", message.id, csocket)
		else
			error("basesocket cant handle message")
		end
	end)
end)


return Socket