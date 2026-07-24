local Bytecode = {}

local Die = (require 'die')('bytecode compilation')
local repr = require 'repr'
local BetterTypes = require 'better_types'

Bytecode.SimpleOp = BetterTypes.SimpleEnum 'SimpleOp' { 'add', 'sub', 'mul', 'div', 'neg' }

Bytecode.ComplexOp = BetterTypes.Enum 'ComplexOp' {
    push_number = { 'value' },
    push_unit = { 'value' },

}

local Simple, Complex = Bytecode.SimpleOp, Bytecode.ComplexOp

function Bytecode.makeBuilder()
    local Builder = { ops = {} }

    function Builder:push(op)
        self.ops[#self.ops + 1] = op
    end

    function Builder:expr(expr)
        local op
        if expr:is('Number') then
            op = Complex.push_number {value=expr.value}
        elseif expr._variant == 'LiteralNil' then
            op = Complex.push_unit {value='nil'}
        elseif expr:is('UnOp') then
            self:expr(expr.inner)
            op = Simple[expr.kind]
        elseif expr:is('BinOp') then
            self:expr(expr.left)
            self:expr(expr.right)
            op = Simple[expr.kind]
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
