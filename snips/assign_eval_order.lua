do
    local repr = print
    local meta = {
        __index = function(t, k)
            print('get ' .. repr(t) .. ' -> ' .. repr(k))
            return rawget(t, k) or { k }
        end,
        __newindex = function(t, k, v)
            print('set ' .. repr(t) .. ' -> ' .. repr(k) .. ' = ' .. repr(v))
            rawset(t, k, v)
        end
    }
    local function id(v)
        print(repr(v))
        return v
    end
    local t1 = setmetatable({ 't1' }, meta)
    local t2 = setmetatable({ 't2' }, meta)
    local t3 = setmetatable({ 't3' }, meta)
    local t4 = setmetatable({ 't4' }, meta)
    t1.field1 = setmetatable({ 'field1' }, meta)
    t2.field2 = setmetatable({ 'field2' }, meta)
    t3.field3 = setmetatable({ 'field3' }, meta)
    t4.field4 = setmetatable({ 'field4' }, meta)
    print('THE LINE')
    t1.unknown.field1[t3.nonsense] = id(2)
    return
end
