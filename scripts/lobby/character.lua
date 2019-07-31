require "common.class"
local EventEmitter = require "common.eventemitter"
local Character = class(EventEmitter, function(self, app, id)
	self.app = app
	self.id = 0	
end)

return Character