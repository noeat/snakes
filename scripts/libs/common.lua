function table.tostring(obj)
    local function serialize(value)
        local lua = ""
        local t = type(value)
        if t == "number" then
            lua = lua .. tostring(value)
        elseif t == "boolean" then
            lua = lua .. tostring(value)
        elseif t == "string" then
            lua = lua .. string.format("%q", value)
        elseif t == "table" then
            lua = lua .. "{\n"
            for k, v in pairs(value) do
                lua = lua .. "[" .. serialize(k) .. "]=" .. serialize(v) .. ",\n"
            end
            lua = lua .. "}"
        elseif t == "nil" then
            return nil
        else
            error("can not serialize a " .. t .. " type.")
        end
        return lua
    end
    return serialize(obj)
end

function table.fromstring(lua)
    local Load = loadstring
    if _VERSION ~= "Lua 5.1" then
        Load = load
    end
    local t = type(lua)
    if t == "nil" or lua == "" then
        return nil
    elseif t == "number" or t == "string" or t == "boolean" then
        lua = tostring(lua)
    else
        error("can not unserialize a " .. t .. " type.")
    end
    lua = "return " .. lua
    local func = Load(lua)
    if func == nil then
        return nil
    end
    return func()
end

function string:split(sep)
    local sep, fields = sep or "\t", {}
    local pattern = string.format("([^%s]+)", sep)
    self:gsub(pattern, function(c) fields[#fields+1] = c end)
    return fields
end