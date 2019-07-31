require "common.class"
local EventEmitter = require("common.eventemitter")

local Socket = class(EventEmitter, function(self, csocket, app) 
	self.app = app
	self.csocket = csocket
	self:on("on_message", function(msgname, msgbyte)
		if msgname == "common.server.Identity" then
			local message = self.app.pbcodec:decode(msgname, msgbyte)
			self.app:emit(message.name.."_identity", message.id, csocket)
			print("xxxx:"..message.name.."_identity")
		else
			error("basesocket cant handle message")
		end
	end)
end)


return Socket