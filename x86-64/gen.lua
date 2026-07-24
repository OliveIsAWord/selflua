local Codegen = {}

local repr = require "repr"

local prelude = io.open('x86-64/prelude.asm'):read('a')

function Codegen.codegen(bytecode)
    local assembly = prelude .. '\nlua_entry:\n    BEGIN_FUNCTION '..bytecode.num_locals..'\n'
    for i, op in ipairs(bytecode) do
        local code
        if type(op) == 'string' then
            code = '    call op_' .. op .. '\n'
        elseif op:is('push_unit') then
            code = '    mov rdi, TAG_' .. op.value:upper() .. '\n    call op_push_unit\n'
        elseif op:is('push_number') then
            -- NOTE: We use big endian here regardless of host endianness, because numeric syntax is essentially big endian.
            local raw_value = string.pack('>d', op.value)
            local hex_value = '0x'
            for i = 1, #raw_value do
                hex_value = hex_value .. string.format('%02x', raw_value:byte(i))
            end
            code = '    mov rdi, ~hex_value ; ~value\n    call op_push_number\n'
            code = code:gsub('~([%a_][%a%d_]*)', { hex_value = hex_value, value = op.value })
        elseif op:is('assign_local') then
            code = '    OP_ASSIGN_LOCAL ' .. op.id .. '\n'
        elseif op:is('get_local') then
            code = '    OP_GET_LOCAL ' .. op.id .. '\n'
        elseif op:is('ret') then
            code = '    OP_RET\n'
        else
            error('unknown op ' .. repr(op))
        end
        assembly = assembly .. code
    end
    return assembly .. '\n    ret\n'
end

return Codegen
