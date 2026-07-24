local Bytecode = {}

local Die = (require 'die')('bytecode compilation')
local repr = require 'repr'
local BetterTypes = require 'better_types'

Bytecode.SimpleOp = BetterTypes.SimpleEnum 'SimpleOp' {
    'add', 'sub', 'mul', 'div', 'neg',
}

Bytecode.ComplexOp = BetterTypes.Enum 'ComplexOp' {
    push_number = { 'value' },
    push_unit = { 'value' },
    get_local = { 'id' },
    assign_local = { 'id' },
    ret = {},
}

local Simple, Complex = Bytecode.SimpleOp, Bytecode.ComplexOp

function Bytecode.makeBuilder()
    local Builder = { ops = {}, vars = {}, num_locals = 0 }

    function Builder:push(op)
        self.ops[#self.ops + 1] = op
    end

    function Builder:create_local(name)
        local id = self.num_locals
        self.num_locals = self.num_locals + 1
        self.vars[name] = id
        return id
    end

    function Builder:get_local(name)
        return self.vars[name]
    end

    function Builder:expr(expr)
        local op
        if expr:is('Number') then
            op = Complex.push_number { value = expr.value }
        elseif expr:is('LiteralNil') then
            op = Complex.push_unit { value = 'nil' }
        elseif expr:is('Variable') then
            local id = self:get_local(expr.name)
            if not id then
                error(expr.name)
            end
            op = Complex.get_local { id = id }
        elseif expr:is('UnOp') then
            self:expr(expr.inner)
            op = Simple[expr.kind]
        elseif expr:is('BinOp') then
            self:expr(expr.left)
            self:expr(expr.right)
            op = Simple[expr.kind]
        else
            Die.fatal('unknown expression ' .. repr(expr))
        end
        self:push(op)
    end

    function Builder:stmt(stmt)
        if stmt:is('Local') then
            local id = self:create_local(stmt.name)
            if stmt.init[1] then
                self:expr(stmt.init[1])
            else
                self:push(Complex.push_unit { value = 'nil' })
            end
            self:push(Complex.assign_local { id = id })
        elseif stmt:is('Return') then
            self:expr(stmt.value)
            self:push(Complex.ret {})
        else
            Die.fatal('unknown statement ' .. repr(stmt))
        end
    end

    function Builder:block(block)
        assert(block._type == 'Block', block._type)
        -- For the duration of the block, a fresh variable scope shadows a read-only view into the outer scope.
        local outer_scope = self.vars
        self.vars = setmetatable({}, { __index = outer_scope })
        for _, statement in ipairs(block) do
            self:stmt(statement)
        end
        self.vars = outer_scope
    end

    function Builder:finish()
        local bytecode = self.ops
        bytecode.num_locals = self.num_locals
        return bytecode
    end

    return Builder
end

function Bytecode.build(tree)
    local builder = Bytecode.makeBuilder()
    builder:block(tree)
    return builder:finish()
end

return Bytecode
