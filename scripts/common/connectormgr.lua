require "common.class"
local EventEmitter = require "common.eventemitter"
local Queue = require "common.queue"

local function bind(f, ...)
    local arg = {...}
    return function()
        f(table.unpack(arg))
    end
end

local Socket = class(EventEmitter, function(self, csocket, app)
    self.app = app
    self.socket = csocket
    self.sid = csocket:get_sid()
    self.stype = csocket:stype()
end)

function Socket:send_msg(msgname, message)
    local dataBytes = self.app.pbcodec:encode(msgname, message)
	local headBytes = self.app.pbcodec:encode("common.MsgHead", {proto = msgname, data = dataBytes})
	self.socket:send(headBytes)
end

local WSSocket = class(Socket, function(self, csocket, app)
    self:on("message", function(msgname, msgbytes)
        local message = self.app.pbcodec:decode(msgname, msgbytes) 
        self:handle_message(msgname, message)
    end)
end)

function WSSocket:handle_message(msgname, message)
    local handler = self.app.handler
    handler:handle(self, msgname, message)
end

local GSocket = class(Socket, function(self, csocket, app)    
    self.identity   = false    
    self.remote_name = nil
    self.remote_id  = 0
    self.call_queue = Queue(100)
    local identity = {name=self.app.type, id=self.app.id}
    self:send_msg("common.server.Identity", identity)
    self:on("message", function(msgname, msgbytes)
        local message = self.app.pbcodec:decode(msgname, msgbytes) 
        self:handle_message(msgname, message)
    end)
end)

function GSocket:handle_message(msgname, message)
    if msgname == "common.server.Identity" then
        self.identity = true
        self.remote_name = message.name
        self.remote_id = message.id
        self.app.server:add_server(self)
    elseif msgname == "common.server.RemoteRep" then
        if self.queue:empty() then
            self.app.logger.system_logger:elog("common.server.RemoteRep queue empty")
            assert(false)
        end

        local cb = self.queue:pop()
        assert(cb ~= nil)
        if message.error_code ~= 0 then
            cb({
                error_code = message.error_code,
                error_msg  = "error remote call",
                op ="rpc"
            }, nil)
        else
            cb(nil, self.app.pbcodec:decode(message.proto, message.data))
        end
    elseif msgname == "common.server.RemoteCall" then

    end
end

function GSocket:remote_call(package, funcname, message, cb)
    local proto_name = package.."."..funcname
    local mdata = self.app.pbcodec:encode(proto_name, message)
    local remote = {proto = proto_name, data = mdata}
    self:send_msg("common.server.RemoteCall", remote)
    self.queue:push(cb)
end

local SocketMgr = class(function(self, app)
    self.app = app
    self.sockets = {}
    self.__name__ = "socketmgr"

    self.app:on("on_connect", function(csocket)
        local sid = csocket:get_sid() 
        local socket = self:create_socket(csocket)
        assert(self.sockets[sid] == nil)
        self.sockets[sid] = socket
    end)

    self.app:on("on_close", function(csocket)
        local sid = csocket:get_sid()
        assert(self.sockets[sid] ~= nil)
        self.sockets[sid] = nil
    end)

    self.app:on("on_message", function(csocket, msgname, message)
        local sid = csocket:get_sid()
        assert(self.sockets[sid] ~= nil)
        local socket = self.sockets[sid]
        socket:emit("message", msgname, message)
    end)
end)

function SocketMgr:create_socket(csocket)
    print(csocket)
    local stype = csocket:stype()
    if stype == 1 or stype == 3 then
        return GSocket(csocket, self.app)
    elseif stype == 2 then
        return WSSocket(csocket, self.app)
    else
        self.app.logger.system_logger("unknow socket type: "..stype)
        assert(false)
    end
    return nil
end

return SocketMgr
