local cloneref = cloneref or function(x)
    return x
end

local library = {
    icons = {
        warning = "rbxasset://textures/DevConsole/Warning.png",
        error = "rbxasset://textures/DevConsole/Error.png",
        bug = "rbxassetid://10709782845",
    },
}

local queue = {}
local queue_head = 1
local queue_tail = 0

local registry = {}

local core_gui = cloneref(game:GetService("CoreGui"))
local connection = nil

local function push_queue(item)
    queue_tail += 1
    queue[queue_tail] = item
end

local function pop_queue()
    if queue_head > queue_tail then return end

    local item = queue[queue_head]
    queue[queue_head] = nil
    queue_head += 1

    return item
end

function library.init()
    if connection then return end
    if not core_gui then return end

    local console = core_gui:WaitForChild("DevConsoleMaster")
    if not console then return end

    connection = console.DescendantAdded:Connect(function(desc)
        if not desc:IsA("Frame") then return end
        if desc.Parent.Name ~= "ClientLog" then return end
        if not tonumber(desc.Name) then return end

        local msg = desc:WaitForChild("msg")
        local img = desc:WaitForChild("image")

        if not msg.Text:match("customprint9324587") then return end

        local data = registry[desc.Name]
        if not data then
            data = pop_queue()
            if not data then return end

            registry[desc.Name] = table.clone(data)
        end

        if data.no_timestamp then
            msg.Text = data.text
        else
            msg.Text = msg.Text:gsub("customprint9324587", data.text)
        end

        if data.prefix then
            msg.Text = string.format("%s %s", data.prefix, msg.Text)
        end

        if data.color then
            msg.TextColor3 = data.color
        end

        if data.icon then
            img.Image = data.icon

            if data.icon_color then
                img.ImageColor3 = data.icon_color
            end
        end
    end)
end

function library.unload()
    table.clear(registry)
    table.clear(queue)

    queue_head = 1
    queue_tail = 0

    if not connection then return end

    connection:Disconnect()
    connection = nil
end

function library.print(args)
    push_queue(args)
    print("customprint9324587")
end

function library.test()
    library.init()

    for i = 1, 100 do
        library.print({
            text = "test, idx: " .. tostring(i),
            color = Color3.fromRGB(math.random(0, 255), math.random(0, 255), math.random(0, 255)),
            icon = library.icons.warning,
            icon_color = Color3.fromRGB(math.random(0, 255), math.random(0, 255), math.random(0, 255)),
            prefix = "[BetterConsole]",
            no_timestamp = true,
        })
    end
end

setmetatable(library, {
    __index = function(_, key)
        error(("[BetterConsole] attempt to get library.%s (not a valid member)"):format(tostring(key)), 2)
    end,

    __newindex = function(_, key)
        error(("[BetterConsole] attempt to set library.%s (not a valid member)"):format(tostring(key)), 2)
    end,
})

return library
