require "common.class"
local EventEmitter = require "common.eventemitter"

local Session = class(function(self, socket)
    self.sid    = socket:get_sid()
    self.socket = socket
    self.auth_timer = nil
end)

local SessionMgr = class(EventEmitter, function(self, app)
    self.app = app
    self.sessions = {}
end)

function SessionMgr:on_connect(socket)
    local sid = socket:get_sid()
    local stype = socket:stype()
    assert(stype == 2) 
    assert(self.sessions[sid] == nil)
    local session = Session(socket)
    session.auth_timer = CTimer.new(10000, 0, function()
        assert(session ~= nil)
        assert(self.sessions[session.sid] ~= nil)
        self.app:error(session.socket, 1, "auth timeout")
        session.socket:close(1)
        self:close(session)
        self.app.logger.system_logger:error("session " ..session.sid.." auth time out")
    end)
    self.sessions[sid] = session
    self.app.logger.system_logger:info("session["..sid ..":"..stype.."] connect:")
end

function SessionMgr:on_close(socket)
    local sid = socket:get_sid()
    self:close(self.sessions[sid])
end

function SessionMgr:close(session)
    assert(session ~= nil, "close session null")
    local sid = session.sid
    assert(self.sessions[sid] ~= nil)
    if session.auth_timer ~= nil then
        session.auth_timer:stop()
        session.auth_timer = nil
    end

    self.sessions[sid] = nil
end

return SessionMgr
