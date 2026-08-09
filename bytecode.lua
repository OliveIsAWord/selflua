local Bytecode = {}

local Die = require 'die' 'bytecode compilation'
local repr = require 'repr'
local BetterTypes = require 'better_types'

Bytecode.SimpleOp = BetterTypes.SimpleEnum 'SimpleOp' {
    'pop',
    'add', 'sub', 'mul', 'div', 'neg',
    'save_stack_pointer', 'call', 'ret', 'call_end_many',
}

Bytecode.ComplexOp = BetterTypes.Enum 'ComplexOp' {
    push_float = { 'value' },
    push_unit = { 'value' },
    push_function = { 'id' },
    -- This is just a hack until we actually implement globals.
    push_builtin = { 'name' },
    get_local = { 'id' },
    assign_local = { 'id' },
    begin_function = { 'num_parameters' },
    allocate_locals = { 'count' },
    call_end_adjust = { 'count' },
}

local Simple, Complex = Bytecode.SimpleOp, Bytecode.ComplexOp

function Bytecode.makeBuilder()
    local Builder = { chunks = {}, ops = {}, locals = {}, num_locals = 0 }

    function Builder:push(op)
        self.ops[#self.ops + 1] = op
    end

    function Builder:create_local(name)
        local id = self.num_locals
        self.num_locals = self.num_locals + 1
        self.locals[name] = id
        return id
    end

    function Builder:get_local(name)
        return self.locals[name]
    end

    function Builder:expr(expr, adjust_to)
        adjust_to = adjust_to or 1
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
            self:push(Simple.save_stack_pointer)
            self:expr(expr.callee)
            for i, arg in ipairs(expr.args) do
                self:expr(arg, i == #expr.args and 'many')
            end
            self:push(Simple.call)
            if adjust_to == 'many' then
                op = Complex.call_end_many
            else
                op = Complex.call_end_adjust { count = adjust_to }
            end
        elseif expr:is('Function') then
            local chunk_id = self:chunk(expr.body, expr.parameters)
            op = Complex.push_function { id = chunk_id }
        else
            Die.fatal('unknown expression ' .. repr(expr))
        end
        self:push(op)
        if not expr:is('Call') and adjust_to ~= 'many' then
            if adjust_to == 0 then
                self:push(Simple.pop)
            else
                assert(adjust_to > 0)
                for _ = 2, adjust_to do
                    self:push(Complex.push_unit { value = 'nil' })
                end
            end
        end
    end

    function Builder:expr_list(expr_list, values_needed)
        if #expr_list == 0 then
            for _ = 1, values_needed do
                self:push(Complex.push_unit { value = 'nil' })
            end
        else
            for i, init in ipairs(expr_list) do
                if i == #expr_list then
                    self:expr(init, math.max(0, values_needed))
                elseif values_needed == 0 then
                    self:expr(init, 0)
                else
                    self:expr(init)
                    values_needed = values_needed - 1
                end
            end
        end
    end

    function Builder:stmt(stmt)
        if stmt:is('Local') then
            self:expr_list(stmt.init_list, #stmt.variables)
            local ids = {}
            for i, v in ipairs(stmt.variables) do
                ids[i] = self:create_local(v)
            end
            for i = #stmt.variables, 1, -1 do
                self:push(Complex.assign_local { id = ids[i] })
            end
        elseif stmt:is('Return') then
            self:push(Simple.save_stack_pointer)
            for i, value in ipairs(stmt.values) do
                self:expr(value, i == #stmt.values and 'many')
            end
            self:push(Simple.ret)
        elseif stmt:is('Call') then
            self:push(Simple.save_stack_pointer)
            self:expr(stmt.callee)
            for i, arg in ipairs(stmt.args) do
                self:expr(arg, i == #stmt.args and 'many')
            end
            self:push(Simple.call)
            self:push(Complex.call_end_adjust { count = 0 })
        elseif stmt:is('Assign') then
            self:expr_list(stmt.values, #stmt.variables)
            for i = #stmt.variables, 1, -1 do
                local v = stmt.variables[i]
                local id = self:get_local(v.name) or Die.fatal('unknown variable ' .. repr(v))
                self:push(Complex.assign_local { id = id })
            end
        else
            Die.fatal('unknown statement ' .. repr(stmt))
        end
    end

    function Builder:block(block)
        assert(block._type == 'Block', block._type)
        -- For the duration of the block, a fresh variable scope shadows a read-only view into the outer scope.
        local outer_scope = self.locals
        self.locals = setmetatable({}, { __index = outer_scope })
        for _, statement in ipairs(block) do
            self:stmt(statement)
        end
        self.locals = outer_scope
    end

    function Builder:chunk(chunk, parameters)
        local ops, locals, num_locals = self.ops, self.locals, self.num_locals
        self.ops, self.locals, self.num_locals = {}, {}, 0
        local chunk_id = #self.chunks + 1
        self.chunks[chunk_id] = self.ops
        -- adjust parameter list
        self:push(Complex.begin_function { num_parameters = #parameters })
        for _, parameter in ipairs(parameters) do
            self:create_local(parameter)
        end
        local allocate_locals = Complex.allocate_locals { count = -1 }
        self:push(allocate_locals)
        self:block(chunk)
        -- if the last instruction doesn't diverge, add an empty return statement
        -- nothing bad would happen if we were to always emit this, it's just cleaner
        if self.ops[#self.ops] ~= Simple.ret then
            self:push(Simple.save_stack_pointer)
            self:push(Simple.ret)
        end
        allocate_locals.count = self.num_locals - #parameters
        self.ops, self.locals, self.num_locals = ops, locals, num_locals
        return chunk_id
    end

    function Builder:finish()
        return self.chunks
    end

    return Builder
end

function Bytecode.build(tree)
    local builder = Bytecode.makeBuilder()
    builder:chunk(tree, {})
    return builder:finish()
end

return Bytecode
