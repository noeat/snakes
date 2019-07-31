local _M = {}
_M.pb = require("pb")
_M.pb.option("enum_as_value")

-- reset
function _M:reset()
    _M.pb.clear()
    package.loaded["protoc"] = nil
    _M.protoc = require("libs.protoc")
    _M.protoc.reload()
    _M.protoc.include_imports = true
end

-- add pb path
function _M:add_pb_path(tbl)
    for index, path in pairs(tbl) do
        _M.protoc.paths[index] = path
	end 
end

function _M:SaveToFile()
    local file = io.output("../starve-game/proto_dealer/proto.lua");
    if not file then
        print("produce proto.lua error");
        return ;
    end

    local c = "local starve_proto = {";
    for name in self.pb.types() do
        -- name = .starve.
        local s, e = string.find(name, ".starve.");
        if s and e then
            c = c .. "\n";
            c = c .. "    ";
            local proto = string.sub(name, e+1);
            c = c .. proto .. "=" .. "\"" .. "starve." .. proto .. "\"";
            c = c .. ",";
        end
    end

    -- add tail.
    c = c .. "\n";
    c = c .. "};\n";
    c = c .. "return starve_proto;";

    -- write and close.
    file:write(c);
    file:flush();
    file:close();
end

-- load pb
function _M:load_file(name)
    assert(self.protoc:loadfile(name))
end

-- print hex
function _M:toHex(bytes)
    print(self.pb.tohex(bytes))
end

-- find message
function _M:find_message(message)
    return self.pb.type("." .. message)
end

-- encode message
function _M:encode(message, data)
    if self:find_message(message) == nil then
        assert(false, "not found proto " .. message)
        return ""
    end

    -- encode lua table data into binary format in lua string and return
    local bytes = assert(self.pb.encode(message, data))
    -- print(self.pb.tohex(bytes))

    return bytes
end

-- decode message
function _M:decode(message, bytes)
    if self:find_message(message) == nil then
        assert(false, "not found proto " .. message)
        return {}
    end

    -- decode the binary data back into lua table
    local data = assert(self.pb.decode(message, bytes))

    return data
end

return _M
