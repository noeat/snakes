require "common.class"

local function bind(f, ...)
    local arg = {...}
    return function(...)
        f(table.unpack(arg), table.unpack({...}))
    end
end

local Server = class(function(self, app, opt)
    self.app =app
    self.servers = {}
    self.rpc = {}
    self.opt = opt
    self.id_servers = {}
    self.route = function(servertype, socket)
        return 0
    end
end)

function Server:add_server(socket)
    assert(socket.identity == true)
    assert(socket.remote_name ~= nil)
    assert(self.id_servers[socket.remote_id] == nil)
    self.id_servers[socket.remote_id] = socket

    local remote_type = socket.remote_name
    if self.servers[remote_type] == nil then
        self.servers[remote_type] = {}
    end

    table.insert(self.servers[remote_type], socket)
end

function Server:remove_server(socket)
    if socket.identity == true then
        assert(socket.remote_name ~= nil)
        local remote_type = socket.remote_name
        for i, v in pairs(self.servers[remote_type]) do
            if socket == v then
                self.servers[remote_type][i] = nil
            end
        end
        self.id_servers[socket.remote_id] = nil
    end
end

function Server:rpc_stub(...)
    for i, v in pairs({...}) do
        self:rpc_stub_impl(v)
    end
end

function Server:rpc_stub_impl(file)
    local result = dofile(file)
    assert(result.package ~= nil)
    local splits = {}
    string.gsub(result.package, "%w+", function(w) table.insert(splits, w) end)
    local rpc = self.rpc
    for i, v in pairs(splits) do
        if rpc[v] == nil then
            rpc[v] = {}
        end

        rpc = rpc[v]
    end

    for i, v in pairs(result.remote) do
        if type[v] == "function" then
            rpc[i] = bind(Server.remote_call, self, splits[1], result.package, i)
        end
    end
end

function Server:remote_call(servertype, package, funcname, socket, message, cb)
    if self.servers[servertype] == nil then
        self.app.logger.system_logger:error("error servertype "..servertype)
        return
    end

    local route = (self.opt and self.opt.route) or self.route
    local serverid = route(servertype, socket) 
    local ssocket = self.id_servers[serverid] or self.servers[servertype][1]
    assert(ssocket ~= nil)      
    ssocket:remote_call(package, funcname, message, 
    function(err, message)
        if cb ~= nil then
            cb(err, message)
        end
    end)  
end


return Server