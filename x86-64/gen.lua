local Codegen = {}

local repr = require "repr"

local prelude = io.open('x86-64/prelude.asm'):read('a')

function Codegen.codegen(bytecode)
    local assembly = prelude .. '\nlua_entry:\n'
    for i, op in ipairs(bytecode) do
        local code
        if op.op == 'push' then
            -- NOTE: We use big endian here regardless of host endianness, because numeric constants are essentially big endian.
            local raw_value=string.pack('>d', op.value)
            local hex_value='0x'
            for i=1,#raw_value do
                hex_value=hex_value..string.format('%02x', raw_value:byte(i))
            end
            code = ([[
    mov rdi, ~hex_value ; ~value
    call op_push
]]):gsub('~([%a_][%a%d_]*)', { hex_value = hex_value, value = op.value })
        else
            code = '    call op_' .. op.op .. '\n'
        end
        assembly = assembly .. code
    end
    return assembly .. '\n    ret\n'
end

return Codegen
