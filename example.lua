local many = function()
    return 3, 1, 4, 1, 5
end
local few = function()
    return
end
local a, b, c = 100
print(a, b, c) -- 100 nil nil
a, b, c = 1, 2, 3, 4, 5
print(a, b, c) -- 1 2 3
a, b, c = many()
print(a, b, c) -- 3 1 4
a, b, c = few()
print(a, b, c) -- nil nil nil
a, b, c = 999, many()
print(a, b, c) -- 999 3 1
a, b, c = 6, few(), 7
print(a, b, c) -- 6 nil 7
