local BetterTypes = {}

function BetterTypes.Enum(name)
    return function(variants)
        local ty = {}
        for variant, all_fields in pairs(variants) do
            if ty[variant] then
                error('duplicate variant ' .. name .. '.' .. variant, 2)
            end
            local field_index = {}
            local num_fields = 0
            for _, field in ipairs(all_fields) do
                num_fields = num_fields + 1
                field_index[field] = num_fields
            end
            local function is(self, key)
                local variant = self._variant
                if not variants[key] then
                    error('checked ' .. self._type .. '.' .. variant .. ' against unknown variant ' .. key, 2)
                end
                return variant == key
            end
            local function iter(self, key)
                local i = 1
                if key then
                    i = field_index[key] + 1
                end
                local next_key = all_fields[i]
                if next_key then
                    return next_key, self[next_key]
                end
                -- return nil, nil
            end
            local variant_metatable = {
                __index = setmetatable({ _type = name, _variant = variant, is = is }, {
                    __index =
                        function(_, k)
                            error('get unknown field ' .. name .. '.' .. variant .. '.' .. k, 2)
                        end
                }),
                __newindex = function(_, k, _)
                    error('set unknown field ' .. name .. '.' .. variant .. '.' .. k, 2)
                end,
                __name = variant,
                __pairs = function(t)
                    return iter, t, nil
                end
            }
            ty[variant] = function(fields)
                local value = {}
                local i = 0
                for k, v in pairs(fields) do
                    if not field_index[k] then
                        error('unknown field ' .. name .. '.' .. variant .. '.' .. k, 2)
                    end
                    value[k] = v
                    i = i + 1
                end
                if i ~= num_fields then
                    local missing = {}
                    for _, field in ipairs(all_fields) do
                        if value[field] == nil then
                            table.insert(missing, field)
                        end
                    end
                    error('missing fields when constructing ' .. name .. '.' ..
                        variant .. ': ' .. table.concat(missing, ', '), 2)
                end
                return setmetatable(value, variant_metatable)
            end
        end
        return setmetatable(ty, {
            __index = function(_, k)
                error('get unknown variant ' .. name .. '.' .. k, 2)
            end,
            __newindex = function(_, k, _)
                error('set unknown variant ' .. name .. '.' .. k, 2)
            end,
            __name = name,
        })
    end
end

function BetterTypes.SimpleEnum(name)
    return function(variants)
        local ty = {}
        for _, key in ipairs(variants) do
            ty[key] = key
        end
        return setmetatable(ty, {
            __index = function(_, k)
                error('get unknown variant ' .. name .. '.' .. k, 2)
            end,
            __newindex = function(_, k, _)
                error('set unknown variant ' .. name .. '.' .. k, 2)
            end,
            __name = name,
        })
    end
end

return BetterTypes
