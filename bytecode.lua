local Bytecode = {}

local Die = require 'die' 'bytecode compilation'
local repr = require 'repr'
local BetterTypes = require 'better_types'

Bytecode.SimpleOp = BetterTypes.SimpleEnum 'SimpleOp' {
    'add', 'sub', 'mul', 'div', 'neg',
    'call', 'ret', 'multi_start', 'multi_end_none', 'multi_end_single', 'multi_end_many',
}

Bytecode.ComplexOp = BetterTypes.Enum 'ComplexOp' {
    push_float = { 'value' },
    push_unit = { 'value' },
    get_local = { 'id' },
    assign_local = { 'id' },
    -- This is just a hack until we actually implement globals.
    push_builtin = { 'name' },
    multi_adjust = { 'count' },
    multi_end_adjust = { 'count' },
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

    function Builder:expr(expr, is_multi)
        local op
        if expr:is('Number') then
            op = Complex.push_float { value = expr.value }
        elseif expr:is('LiteralNil') then
            op = Complex.push_unit { value = 'nil' }
        elseif expr:is('Variable') then
            -- God gives Her most cursed `do` blocks to Her strongest girls.
            repeat
                local id = self:get_local(expr.name)
                if id then
                    op = Complex.get_local { id = id }
                    break
                end
                if expr.name == 'print' then
                    op = Complex.push_builtin { name = expr.name }
                    break
                end
            until error('unknown variable ' .. expr.name)
        elseif expr:is('UnOp') then
            self:expr(expr.inner)
            op = Simple[expr.kind]
        elseif expr:is('BinOp') then
            self:expr(expr.left)
            self:expr(expr.right)
            op = Simple[expr.kind]
        elseif expr:is('Call') then
            self:push(Simple.multi_start)
            self:expr(expr.callee)
            for i, arg in ipairs(expr.args) do
                self:expr(arg, i == #expr.args)
            end
            self:push(Simple.call)
            if not is_multi then
                op = Simple.multi_end_single
            else
                op = Simple.multi_end_many
            end
        else
            Die.fatal('unknown expression ' .. repr(expr))
        end
        self:push(op)
    end

    function Builder:stmt(stmt)
        if stmt:is('Local') then
            self:push(Simple.multi_start)
            for i, init in ipairs(stmt.init_list) do
                self:expr(init, i == #stmt.init_list)
            end
            self:push(Complex.multi_adjust { count = #stmt.variables })
            for _, variable in ipairs(stmt.variables) do
                local id = self:create_local(variable)
                self:push(Complex.assign_local { id = id })
            end
            self:push(Complex.multi_end_adjust { count = #stmt.variables })
        elseif stmt:is('Return') then
            for i, value in ipairs(stmt.values) do
                self:expr(value, i == #stmt.values)
            end
            self:push(Simple.ret)
        elseif stmt:is('Call') then
            self:push(Simple.multi_start)
            self:expr(stmt.callee)
            for i, arg in ipairs(stmt.args) do
                self:expr(arg, i == #stmt.args)
            end
            self:push(Simple.call)
            self:push(Simple.multi_end_none)
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

    function Builder:chunk(chunk)
        self:block(chunk)
        if self.ops[#self.ops] ~= Simple.ret then
            self:push(Simple.ret)
        end
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
    builder:chunk(tree)
    return builder:finish()
end

return Bytecode
