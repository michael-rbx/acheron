local library = {
    hooks = {},
    last_idx = 0,
}

local c_hook = {}
c_hook.__index = c_hook

function c_hook:unhook()
    if restorefunction and typeof(restorefunction) == "function" then
        pcall(function()
            restorefunction(self.target)
        end)
    else
        hookfunction(self.target, self.original)
    end

    library.hooks[self.index] = nil
    setmetatable(self, nil)
    table.clear(self)
end

function library.new(target, hook)
    library.last_idx += 1

    local this = setmetatable({
        index = library.last_idx,
        target = target,
        hook = hook,
        original = hookfunction(target, newcclosure(hook)),
    }, c_hook)

    library.hooks[this.index] = this
    return this
end

function library.unhook_all()
    for _, hook in next, library.hooks do
        if not hook then continue end
        hook:unhook()
    end

    table.clear(library.hooks)
end

setmetatable(library, {
	__index = function(_, key)
		error(("[GoodHook] attempt to get library.%s (not a valid member)"):format(tostring(key)), 2)
	end,
    
	__newindex = function(_, key)
		error(("[GoodHook] attempt to set library.%s (not a valid member)"):format(tostring(key)), 2)
	end,
})

return library
