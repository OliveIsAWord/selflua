local Codegen = {}

local repr = require "repr"

local prelude = io.open('x86-64/prelude.asm'):read('a')

function Codegen.codegen(bytecode)
    local assembly = prelude .. '\nlua_entry:\n'
    for i, op in ipairs(bytecode) do
        local code
        if op.op == 'push' then
            code = ([[
section .data
    double_~uid: dq ~value.0
section .text
    mov rdi, qword [double_~uid]
    call op_push
]]):gsub('~([%a_][%a%d_]*)', { uid = i, value = op.value })
        else
            code = '    call op_' .. op.op .. '\n'
        end
        assembly = assembly .. code
    end
    return assembly .. '\n    ret\n'
end

return Codegen
