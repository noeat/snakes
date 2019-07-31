require "common.class"

local Handler = class(function(self, app)
    self.app = app
    self.handlers = {}
end)

function Handler:load_file(...)
    for i, v in pairs({...}) do
        self:load_file_impl(v)    
    end
end

function Handler:load_file_impl(file)
    local result = dofile(file)
    assert(result.package ~= nil)
    local splits = {}
    string.gsub(result.package, "%w+", function(w) table.insert(splits, w) end)
    local handler = self.handlers
    for i, v in pairs(splits) do
        if handler[v] == nil then
            handler[v] = {}           
        end
        handler = handler[v]
    end

    assert(handler ~= nil)
    for i, v in pairs(result.handler) do
        if type(v) == "function" then
            handler[i] = v
        end
    end   
end

function Handler:handle(socket, msgname, message)
    print("handle msg"..msgname)
    local splits = {}
    string.gsub(msgname, "%w+", function(w) table.insert(splits, w) end)
    local handler = self.handlers
    for i, v in pairs(splits) do
        if handler[v] ~= nil then
            handler = handler[v]
        end
    end

    if type(handler) == "function" then
        handler(socket, message)
    else
        self:forward_handler(socket, msgname, message)
    end
end

function Handler:forward_handler(socket, msgname, message)
    assert(false, "")
end


return Handler