local twice = function(f, n)
    return f(f(n))
end

local triple = function(n)
    return n * 3, nil, n * n
end
triple(1)
return triple, triple(8), twice(triple, 7)
