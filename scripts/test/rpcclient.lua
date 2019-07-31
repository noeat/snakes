package.cpath = package.cpath .. ";./luamod/?.dll"
package.cpath = package.cpath .. ";./luamod/?.so"
package.path = "./?.lua;"
package.path = package.path .. "./scripts/?.lua;"
require("libs.common")
local pbcodec = require("libs.pbcodec")
pbcodec:reset()
pbcodec:add_pb_path({"./proto"})
-- ================================= callback ===================================
function on_connect(session)
	print(session:get_sid(), "connect")
end

function on_close(session)
	print(session:get_sid(), "close")
end

function on_message(session, data)
	
end

function on_start()

end

function on_stop()
end

require "common.class"
local EventEmitter = require "common.eventemitter"
local Pool = require "common.pool"

local Socket = class(EventEmitter, function(self, csocket)
	self.socket = csocket
end)

local MailBox = class(EventEmitter, function(self, socket)
	self.socket = socket
	self.call_pool = Pool(10)
	self.socket:on("on_close", function()
	
		
	end)
end)
