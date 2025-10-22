local library = {
    meta_table = 0,

    name_call = {
        hooks = {},
        last_idx = 0,

        original = nil,
    },

    index = {
        hooks = {},
        last_idx = 0,

        original = nil,
    },
}

-- namecall hook class

local c_name_call_hook = {}
c_name_call_hook.__index = c_name_call_hook

function c_name_call_hook:enable()
    self.enabled = true
end

function c_name_call_hook:disable()
    self.enabled = false
end

function c_name_call_hook:active()
    return self.enabled
end

function c_name_call_hook:destroy()
    library.name_call.hooks[self.instance .. self.method] = nil
    setmetatable(self, nil)
    table.clear(self)
end

-- index hook class

local c_index_hook = {}
c_index_hook.__index = c_index_hook

function c_index_hook:enable()
    self.enabled = true
end

function c_index_hook:disable()
    self.enabled = false
end

function c_index_hook:active()
    return self.enabled
end

function c_index_hook:destroy()
    library.index.hooks[self.instance .. self.key] = nil
    setmetatable(self, nil)
    table.clear(self)
end

-- constructor(s)

function library.name_call.new(instance, method, func)
    local hook = library.name_call.hooks[instance .. method]
    if hook then return hook end

    local this = setmetatable({
        instance = instance,
        method = method,
        func = newcclosure(func),
        enabled = false,
    }, c_name_call_hook)

    library.name_call.hooks[instance .. method] = this
    return this
end

function library.index.new(instance, key, func)
    local hook = library.index.hooks[instance .. key]
    if hook then return hook end

    local this = setmetatable({
        instance = instance,
        key = key,
        func = newcclosure(func),
        enabled = false,
    }, c_index_hook)

    library.index.hooks[instance .. key] = this
    return this
end

-- main funcs

function library.init()
    local meta_table = getrawmetatable(game)
    setreadonly(meta_table, false)

    local name_call_orig = meta_table.__namecall
    local index_orig = meta_table.__index

    meta_table.__namecall = newcclosure(function(this, ...)
        local this_str = tostring(this)
        local method_str = getnamecallmethod()

        local hook = library.name_call.hooks[this_str .. method_str]
        if hook and hook:active() then
            return hook.func(this, name_call_orig, ...)
        end

        return name_call_orig(this, ...)
    end)

    meta_table.__index = newcclosure(function(this, key)
        local value = index_orig(this, key)
        local this_str = tostring(this)
        local key_str = tostring(key)

        local hook = library.index.hooks[this_str .. key_str]
        if hook and hook:active() then
            return hook.func(this, value)
        end

        return value
    end)

    library.meta_table = meta_table
    library.name_call.original = name_call_orig
    library.index.original = index_orig
end

function library.unload()
    if library.meta_table == 0 then return end

    library.meta_table.__namecall = library.name_call.original
    library.meta_table.__index = library.index.original
    setreadonly(library.meta_table, true)

    for _, hook in next, library.name_call.hooks do
        hook:destroy()
    end

    for _, hook in next, library.index.hooks do
        hook:destroy()
    end

    table.clear(library)
end

function library.enable_all()
    for _, hook in next, library.name_call.hooks do
        hook:enable()
    end

    for _, hook in next, library.index.hooks do
        hook:enable()
    end
end

function library.disable_all()
    for _, hook in next, library.name_call.hooks do
        hook:disable()
    end

    for _, hook in next, library.index.hooks do
        hook:disable()
    end
end

setmetatable(library, {
	__index = function(_, key)
		error(("[MMinHook] attempt to get library.%s (not a valid member)"):format(tostring(key)), 2)
	end,
    
	__newindex = function(_, key)
		error(("[MMinHook] attempt to set library.%s (not a valid member)"):format(tostring(key)), 2)
	end,
})

return library
