local Codegen = {}

local repr = require "repr"

local prelude = io.open('x86-64/prelude.asm'):read('a')

function Codegen.codegen_chunk(chunk)
    local function complex_op(op, args)
        local arg_string = table.concat(args, ', ')
        return 'OP_' .. op._variant:upper() .. ' ' .. arg_string
    end
    local assembly = ''
    for _, op in ipairs(chunk) do
        local code
        if type(op) == 'string' then
            code = 'call op_' .. op
        elseif op:is('push_unit') then
            code = complex_op(op, { op.value:upper() })
        elseif op:is('push_float') then
            -- NOTE: We use big endian here regardless of host endianness, because numeric syntax is essentially big endian.
            local raw_value = string.pack('>d', op.value)
            local hex_value = '0x'
            for i = 1, #raw_value do
                hex_value = hex_value .. string.format('%02x', raw_value:byte(i))
            end
            code = complex_op(op, { hex_value .. ' ; ' .. op.value })
        else
            local args = {}
            for _, v in pairs(op) do
                table.insert(args, v)
            end
            code = complex_op(op, args)
        end
        assembly = assembly .. '    ' .. code .. '\n'
    end
    return assembly
end

function Codegen.codegen(bytecode)
    local chunks = {}
    for i, chunk in ipairs(bytecode) do
        table.insert(chunks, 'DEFINE_CHUNK ' .. i .. ', Michael' .. i)
        table.insert(chunks, Codegen.codegen_chunk(chunk))
    end
    return prelude .. '\n' .. table.concat(chunks, '\n')
end

return Codegen
