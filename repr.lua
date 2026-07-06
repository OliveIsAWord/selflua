local function repr(value)
    if type(value) == "table" then
        local i = 1
        local fields = {}
        while true do
            local field = rawget(value, i)
            if field == nil then
                break
            end
            table.insert(fields, repr(field))
            i = i + 1
        end
        for k, v in pairs(value) do
            if type(k) ~= "number" or k < 1 or k >= i or k ~= math.floor(k) then
                local formatted_key
                if type(k) == "string" and k:match("^[%a_][%a%d_]*$") then
                    formatted_key = k
                else
                    formatted_key = '[' .. repr(k) .. ']'
                end
                table.insert(fields, formatted_key .. " = " .. repr(v))
            end
        end
        return '{ ' .. table.concat(fields, ', ') .. ' }'
    elseif type(value) == 'nil' or type(value) == 'number' or type(value) == 'boolean' then
        return tostring(value)
    elseif type(value) == 'string' then
        local escaped = "'"
        for i = 1, #value do
            local c = value:byte(i)
            if c == 0x5c then
                c = '\\\''
            elseif c == 0x27 then
                c = '\\\\'
            elseif 0x20 <= c and c < 0x7f then
                c = string.char(c)
            else
                c = string.format('\\x%02x', c)
            end
            escaped = escaped .. c
        end
        return escaped.."'"
    else
        return '(' .. tostring(value) .. ')'
    end
end

return repr
