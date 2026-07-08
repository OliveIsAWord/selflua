local Codegen = {}

local repr = require "repr"

local prelude = [[
default rel
extern printf

section .rodata
    printf_fmt db "%f", 10, 0

section .bss
data_stack_boundary:
    resb 16 * 10000
data_stack:

section .text
global main
main:
    sub rsp, 40 ; cargo cult stack alignment
    mov rbp, data_stack
    finit
]]

local postlude = [[

    lea rcx, [printf_fmt]
    mov rdx, [rbp]
    call printf

    add rsp, 40
    xor eax, eax
    ret
]]

local function binop (name)
    return [[
    fld qword [rbp+8]
    fld qword [rbp]
    f]]..name..[[p st1, st0
    add rbp, 8
    fstp qword [rbp]
]]
end

local function unop (name)
    return [[
    fld qword [rbp]
    f]]..name..[[; <- load-bearing semicolon
    fstp qword [rbp]
]]
end

local stamps = {
    -- TODO: do the floating point byte conversion ourselves to avoid the memory read
    push_number = [[
section .data
    double_~uid: dq ~value.0
section .text
    mov rdi, qword [double_~uid]
    sub rbp, 8
    mov qword [rbp], rdi
]],
    ['+'] = binop('add'),
    ['-'] = binop('sub'),
    ['*'] = binop('mul'),
    ['/'] = binop('div'),
    ['neg'] = unop('chs'),
}

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
