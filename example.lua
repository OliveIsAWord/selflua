-- return 69

local twice = function(f, n)
    return f(f(n))
end

local triple = function(n)
    return n * 3, nil, n * n
end
-- return triple(triple(8))
return twice(triple, 7)
