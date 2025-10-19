-- Copyright (c) 2025 michael-rbx
-- Licensed under the MIT License. See LICENSE file in the project root for details.
-- checkcaller

function error_assert(condition, message)
    if condition then return end
    error(string.format("[MMinHook] [ERROR] %s", message), 2)
end

--- @module MMinHook

--- @class MMinHook
--- @field meta_table table|nil
--- @field name_call { original: any, hooks: table, new: function }
--- @field index { original: any, hooks: table, new: function }
--- @field init function
--- @field unhook function
local library = {
    meta_table = nil,

    name_call = {
        original = nil,
        hooks = {},
    },

    index = {
        original = nil,
        hooks = {},
    },
}

---- sets up everything needed for hooking. must be called for the hooks to work
--- @return void
function library:init()
    self.meta_table = getrawmetatable(game)
    setreadonly(self.meta_table, false)

    self.name_call.original = self.meta_table.__namecall
    self.index.original = self.meta_table.__index

    self.meta_table.__namecall = newcclosure(function(this, ...)
        local this_string = tostring(this)
        local method_string = getnamecallmethod()

        local hook_data = self.name_call.hooks[this_string .. method_string]
        if hook_data and hook_data.active then
            return hook_data.func(this, self.name_call.original, ...)
        end

        return self.name_call.original(this, ...)
    end)

    self.meta_table.__index = newcclosure(function(this, key)
        local ret_value = self.index.original(this, key)

        local hook_data = self.index.hooks[tostring(this) .. key]
        if hook_data and hook_data.active then
            return hook_data.func(this, ret_value)
        end

        return ret_value
    end)
end

---- destroys all hooks and handles clean up
--- @return void
function library:unhook()
    error_assert(self.meta_table, "meta table is nil, did you forget to call init?")
    error_assert(self.index.original, "original __index is nil, did you forget to call init?")
    error_assert(self.name_call.original, "original __namecall is nil, did you forget to call init?")

    self.index.hooks = nil
    self.name_call.hooks = nil

    self.meta_table.__index = self.index.original
    self.meta_table.__namecall = self.name_call.original

    self.index.original = nil
    self.name_call.original = nil
end

---- enables all hooks
--- @return void
function library:enable()
    for _, hook in next, self.index.hooks do
        hook.active = true
    end

    for _, hook in next, self.name_call.hooks do
        hook.active = true
    end
end

---- disables all hooks
--- @return void
function library:disable()
    for _, hook in next, self.index.hooks do
        hook.active = false
    end

    for _, hook in next, self.name_call.hooks do
        hook.active = false
    end
end

--#region index hook setup

--- @class c_index_hook
--- @field instance string
--- @field key string
--- @field func fun(this: any, key: string, original: any): any
--- @field active boolean
--- @field enable function
--- @field disable function
--- @field destroy function
--- @field is_active function
local c_index_hook = {}
c_index_hook.__index = c_index_hook

---- enables the hook
--- @return void
function c_index_hook:enable()
    self.active = true
end

---- disables the hook
--- @return void
function c_index_hook:disable()
    self.active = false
end

---- destroys the hook. the c_index_hook object will still exist even after calling this, nil the object manually
--- @return void
function c_index_hook:destroy()
    library.index.hooks[self.instance .. self.key] = nil
end

---- checks if the hook is active or not. this does not check if the hook has been destroyed
--- @return boolean true if the hook is active, false otherwise
function c_index_hook:is_active()
    return self.active
end

---- creates a new __index hook. this does not allow duplicate hooks.
---- this will hook any instance that shares the same name, even if their path is different.
--- @param instance string the name of an instance
--- @param key string the name of the key to be hooked on the instance
--- @param func fun(this: any, key: string, original: any): any the function/hook to be called when key is accessed
--- @return c_index_hook object
function library.index:new(instance, key, func)
    error_assert(library.meta_table ~= nil, "meta table is nil, have you called init yet?")
    error_assert(self.original ~= nil, "original __index is nil, have you called init yet?")

    local instance_type = typeof(instance)
    error_assert(instance_type == "string", string.format("invalid argument for instance. expected string, got %s", instance_type))

    local key_type = typeof(key)
    error_assert(key_type == "string", string.format("invalid argument for key. expected string, got %s", key_type))

    local func_type = typeof(func)
    error_assert(func_type == "function", string.format("invalid argument for func. expected function, got %s", func_type))

    local hook = self.hooks[instance .. key]
    if hook then return hook end

    local this = setmetatable({}, c_index_hook)
    this.instance = instance
    this.key = key
    this.func = newcclosure(func)
    this.active = false

    self.hooks[instance .. key] = this
    return this
end

---- enables all __index hooks
--- @return void
function library.index:enable()
    for _, hook in next, self.hooks do
        hook.active = true
    end
end

---- disables all __index hooks
--- @return void
function library.index:disable()
    for _, hook in next, self.hooks do
        hook.active = false
    end
end

--#endregion

--#region namecall hook setup

--- @class c_name_call_hook
--- @field instance string
--- @field method string
--- @field func fun(this: any, original: any, args: table): any
--- @field active boolean
--- @field enable function
--- @field disable function
--- @field destroy function
--- @field is_active function
local c_name_call_hook = {}
c_name_call_hook.__index = c_name_call_hook

---- enables the hook
--- @return void
function c_name_call_hook:enable()
    self.active = true
end

---- disables the hook
--- @return void
function c_name_call_hook:disable()
    self.active = false
end

---- destroys the hook. the c_name_call_hook object will still exist even after calling this, nil the object manually
--- @return void
function c_name_call_hook:destroy()
    library.name_call.hooks[self.instance .. self.method] = nil
end

---- checks if the hook is active or not. this does not check if the hook has been destroyed
--- @return boolean true if the hook is active, false otherwise
function c_name_call_hook:is_active()
    return self.active
end

---- creates a new __namecall hook. this does not allow duplicate hooks.
---- this will hook any instance that shares the same name, even if their path is different.
--- @param instance string the name of an instance
--- @param method string the name of the method to be hooked on the instance
--- @param func fun(this: any, original: any, args: table): any the function/hook to be called when method is called
function library.name_call:new(instance, method, func)
    error_assert(library.meta_table ~= nil, "meta table is nil, have you called init yet?")
    error_assert(self.original ~= nil, "original __index is nil, have you called init yet?")

    local instance_type = typeof(instance)
    error_assert(instance_type == "string", string.format("invalid argument for instance. expected string, got %s", instance_type))

    local method_type = typeof(method)
    error_assert(method_type == "string", string.format("invalid argument for method. expected string, got %s", method_type))

    local func_type = typeof(func)
    error_assert(func_type == "function", string.format("invalid argument for func. expected function, got %s", func_type))

    local hook = self.hooks[instance .. method]
    if hook then return hook end

    local this = setmetatable({}, c_name_call_hook)
    this.instance = instance
    this.method = method
    this.func = newcclosure(func)
    this.active = false

    self.hooks[instance .. method] = this
    return this
end

---- enables all __namecall hooks
--- @return void
function library.name_call:enable()
    for _, hook in next, self.hooks do
        hook.active = true
    end
end

---- disables all __namecall hooks
--- @return void
function library.name_call:disable()
    for _, hook in next, self.hooks do
        hook.active = false
    end
end

--#endregion

return library
