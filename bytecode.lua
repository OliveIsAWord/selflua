local Bytecode = {}

local Die = (require 'die')('bytecode compilation')
local repr = require 'repr'

function Bytecode.makeBuilder()
    local Builder = { ops = {} }

    function Builder:push(op)
        self.ops[#self.ops + 1] = op
    end

    function Builder:expr(expr)
        local op
        if expr.subtype == 'number' then
            op = { op = 'push_number', value = expr.value }
        elseif expr.subtype == 'nil' then
            op = { op = 'push_unit', value = expr.subtype }
        elseif expr.inner then
            self:expr(expr.inner)
            op = { op = expr.subtype }
        elseif expr.lhs and expr.rhs then
            self:expr(expr.lhs)
            self:expr(expr.rhs)
            op = { op = expr.subtype }
        else
            Die.fatal('unknown operation ' .. repr(expr))
        end
        self:push(op)
    end

    return Builder
end

function Bytecode.build(tree)
    local builder = Bytecode.makeBuilder()
    builder:expr(tree.returns[1])
    return builder.ops
end

return Bytecode
