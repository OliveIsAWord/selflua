local function f()
    print(f)
end
f() -- function: 000002ABFCCA5F00
local g = f
g() -- function: 000002ABFCCA5F00
f=42
g() -- 42
