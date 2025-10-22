return function(asset)
    if not getcustomasset then return end
    if not writefile then return end
    if not delfile then return end

    if isfile(asset) then
        return getcustomasset(asset)
    end

    local name = string.format("asset_%s.txt", tostring(tick()))
    writefile(name, game:HttpGet(asset))

    local data = getcustomasset(name)
    delfile(name)

    return data
end
