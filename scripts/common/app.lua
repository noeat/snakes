require "common.class"
local EventEmitter = require ("common.eventemitter")

local App = class(EventEmitter, function(self)
    self.type = Server.type()
    self.id   = Server.id()
    self.host = Server.host()

    self.logger = {}
    local system_log = string.format("%s_%d", self.type, self.id)
    self.logger.system_logger = CLogger.new(system_log, true, true, 2)

    self.pbcodec = require("libs.pbcodec")
    self.pbcodec:reset()
    self.pbcodec:add_pb_path({"./proto"})
    self.pbcodec:load_file("common.proto")
    self.pbcodec:load_file("server_common.proto")

    local ConnectorMgr = require("common.connectormgr")
    self.connectmgr = ConnectorMgr(self)

    local Server = require("common.server")
    self.server = Server(self)

    local Handler = require("common.handler")
    self.handler = Handler(self)
end)


function App:on_connect(csocket)
    print(csocket)
    self:emit("on_connect", csocket)
    self.logger.system_logger:info("on_connect: "..csocket:get_sid() ..":"..csocket:stype())
end

function App:on_close(csocket)
    self:emit("on_close", csocket)
    self.logger.system_logger:info("on_close: "..csocket:get_sid() ..":"..csocket:stype())
end

function App:on_message(csocket, data)
	local pbHead = self.pbcodec:decode("common.MsgHead", data)
	if pbHead == nil or pbHead.proto == nil or pbHead.proto == "" then
		self.logger.system_logger:error("decode message head failed")
		return
    end
    
    local message = self.pbcodec:decode(pbHead.proto, pbHead.data)
    if message == nil then
        self.logger.system_logger:error("decode message: "..pbHead.proto .. " failed")
        return
    end

    self:emit("on_message", csocket, pbHead.proto, pbHead.data)
end

function App:send_msg(socket, msgname, msg)
    local dataBytes = self.pbcodec:encode(msgname, msg)
	local headBytes = self.pbcodec:encode("common.MsgHead", {proto = msgname, data = dataBytes})
	socket:send(headBytes)
end

function App:error(socket, error_code, error_msg, op)
    local opcode = op or "none"
    local errormsg = {error_code = error_code, error_msg=error_msg, op=opcode}
    self:send_msg(socket, "common.Error", errormsg) 
end

return App