local is_server = true  -- 当前只处理server情况
local is_client = false

local server_packages = {}
local server_requires = {}

function add_packages(...)
    local packages = {...}
    for _, package in ipairs(packages) do
        if type(package) == "string" then
            local found = false
            for _, require_entry in ipairs(server_requires) do
                local require_name = require_entry:match("^(%S+)")
                if require_name == package then
                    table.insert(server_packages, require_entry)
                    found = true
                    break
                end
            end
            if not found then
                table.insert(server_packages, package)
            end
        elseif type(package) == "table" then
            for _, sub_package in ipairs(package) do
                if type(sub_package) == "string" then
                    table.insert(server_packages, sub_package)
                end
            end
        end
    end
end

function add_requires(...)
    local requires = {...}
    for _, require in ipairs(requires) do
        if type(require) == "string" then
            table.insert(server_requires, require)
        elseif type(require) == "table" then
            for _, sub_require in ipairs(require) do
                if type(sub_require) == "string" then
                    table.insert(server_requires, sub_require)
                end
            end
        end
    end
end

function is_config(config_name, config_value)	
    if config_name == "target_type" then
        if config_value == "client" then
            return is_client
        elseif config_value == "server" then
            return is_server
        end
    end
    return true
end
-- TODO:将windows系统的依赖包和Linux的依赖包分别解析并输出
-- 反正现在不需要，TODO就先放这里了QwQ
local global_env = {
    is_server = is_server,
    is_client = is_client,
    add_packages = add_packages,
    add_requires = add_requires,
    is_config = is_config
}

setmetatable(global_env, {	-- 将其余函数的返回值设置为 true
    __index = function(_, name)
        return function(...) return true end
    end
})	-- TODO:用一个更优雅的办法解决xmake的内置函数

local xmake_lua_path = arg[1]
if not xmake_lua_path then
    print("Usage: lua genDeps.lua <path_to_xmake.lua>")
    return
end

local xmake_lua_content = io.open(xmake_lua_path, "r"):read("*a")
local xmake_lua_chunk, err = loadstring(xmake_lua_content)
if not xmake_lua_chunk then
    print("Failed to load xmake.lua: " .. tostring(err))
    return
end

setfenv(xmake_lua_chunk, global_env)
xmake_lua_chunk()
local result = ""
for i, package in ipairs(server_packages) do
    result = result .. package
    if i < #server_packages then
        result = result .. "\n"
    end
end

print(result)