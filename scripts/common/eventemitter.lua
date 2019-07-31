require "common.class"

local Event = class(function(self, cb, once)
    self.cb = cb
    self.once = once
end)

local EventEmitter = class(function(self)
    self.events = {}
end)

function EventEmitter:on(event, cb)
    if self.events[event] == nil then
        self.events[event] = {}
    end

    assert(self.events[event] ~= nil)
    local es = self.events[event]
    for i, v in pairs(es) do
        if v.cb == cb then
            v.once = false
            return
        end
    end

    local event = Event(cb, false)
    table.insert(es, event)
end

function EventEmitter:once(event, cb)
    if self.events[event] == nil then
        self.events[event] = {}
    end

    assert(self.events[event] ~= nil)
    local es = self.events[event]
    for i, v in pairs(es) do
        if v.cb == cb then
            v.once = false
            return
        end
    end

    local event = Event(cb, true)
    table.insert(es, event)
end

function EventEmitter:emit(event, ...)
    if self.events[event] ~= nil then
        local arg = {...}
        local es = self.events[event]
		local need_gc = false
        for i, v in pairs(es) do
            assert(v ~= nil or v.cb ~= nil)
            v.cb(table.unpack(arg))
            if v.once then
				self.events[event][i] = nil
				need_gc = true
            end
        end

        if #self.events[event] == 0 then
            self.events[event] = nil
        end
		
		if need_gc then
			collectgarbage("collect")
		end
    end   
end

function EventEmitter:removeListener(event, listener)
    if self.events[event] ~= nil then
        local es = self.events[event]
        for i, v in pairs(es) do
            if v.cb == listener then
                table.remove(es, i)
                break
            end
        end

        if #es == 0 then
            self.events[event] = nil
        end
    end
end

function EventEmitter:removeAllListeners(...)
    for i, v in pairs({...}) do
        self.events[v] = nil
    end
    collectgarbage("collect")
end

function EventEmitter:listeners(event)
    return self.events[event] or {}
end

return EventEmitter