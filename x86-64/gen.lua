local Codegen = {}

local repr = require "repr"

local stamps = {
    -- TODO: do the floating point byte conversion ourselves to avoid the memory read
    push_number = [[
section .data
    double_~uid: dq ~value.0
section .text
    push qword [double_~uid]
]],
    ['-'] = [[
    fld qword [rsp+8]
    fld qword [rsp]
    fsubp st1, st0
    add rsp, 8
    fstp qword [rsp]
]],
    ['*'] = [[
    fld qword [rsp+8]
    fld qword [rsp]
    fmulp st1, st0
    add rsp, 8
    fstp qword [rsp]
]],
}

local prelude = [[
default rel
extern printf

section .rodata
    printf_fmt db "%f", 10, 0

section .text
global main
main:
]]
local postlude = [[

    ; we implicitly assume we're 16-byte aligned since we have a single f64 left on the stack
    lea rcx, [printf_fmt]
    mov rdx, [rsp]
    call printf

    add rsp, 8
    xor eax, eax
    ret
]]

function Codegen.codegen(bytecode)
    local assembly = prelude
    for i, op in ipairs(bytecode) do
        local stamp = stamps[op.op]
        if not stamp then
            error('unknown op ' .. repr(op))
        end
        op.uid = i -- ewww
        local instantiated = stamp:gsub('~([%a_][%a%d_]*)', op)
        assembly = assembly .. '; '.. repr(op) .. '\n' .. instantiated
    end
    return assembly .. postlude
end

return Codegen
