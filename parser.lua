local Parser = {}

local Die = require 'die' 'parsing'
local repr = require 'repr'
local BetterTypes = require 'better_types'

Parser.Expr = BetterTypes.Enum 'Expr' {
    Number = { 'value' },
    LiteralNil = {},
    Variable = { 'name' },
    UnOp = { 'kind', 'inner' },
    BinOp = { 'kind', 'left', 'right' },
    Call = { 'callee', 'args' },
}
local Expr = Parser.Expr

Parser.Stmt = BetterTypes.Enum 'Stmt' {
    Local = { 'variables', 'init_list' },
    Return = { 'values' },
    Call = { 'callee', 'args' },
}
local Stmt = Parser.Stmt

local function is_var(expr)
    return expr:is('Variable') -- or self:is('Index')
end
local function is_prefix(expr)
    return is_var(expr) or expr:is('Call') -- or self:is('Paren')
end

local infix_binding_power = {
    ['+'] = { 17, 18, 'add' },
    ['-'] = { 17, 18, 'sub' },
    ['*'] = { 19, 20, 'mul' },
    ['/'] = { 19, 20, 'div' },
}

local prefix_binding_power = {
    -- ['not'] = { 21, 'not' },
    -- ['#'] = { 21, 'len' },
    ['-'] = { 21, 'neg' },
    -- ['~'] = { 21, 'bitnot' },
}

function Parser.makeParser(tokens_parameter)
    local parser = { i = 1, tokens = tokens_parameter }
    function parser:skip()
        self.i = self.i + 1
    end

    function parser:eat(literal)
        local token = self.tokens[self.i]
        if token and (token.type == 'punctuation' or token.type == 'keyword') and token.value == literal then
            parser:skip()
            return token
        end
        return nil
    end

    function parser:number()
        local token = self.tokens[self.i]
        if token and token.type == 'number' then
            parser:skip()
            return token
        end
        return nil
    end

    function parser:identifier()
        local token = self.tokens[self.i]
        if token and token.type == 'identifier' then
            parser:skip()
            return token.value
        end
        return nil
    end

    function parser:fatal()
        Die.fatal('parse error at ' .. repr(self.tokens[self.i]))
    end

    function parser:one(f)
        local result = f(self)
        if not result then
            self:fatal()
        end
        return result
    end

    function parser:list(f)
        local result = f(self)
        if not result then
            return {}
        end
        local items = { result }
        while self:eat(',') do
            local result = self:one(f)
            table.insert(items, result)
        end
        return items
    end

    function parser:expr_bp(min_bp)
        local lhs
        if not lhs then
            local number = self:number()
            if number then
                lhs = Expr.Number { value = number.value }
            elseif self:eat('nil') then
                lhs = Expr.LiteralNil {}
            else
                local name = self:identifier()
                if name then
                    lhs = Expr.Variable { name = name }
                end
            end
        end
        if not lhs and self.tokens[self.i] then
            local op = self.tokens[self.i].value
            local lbp, kind = table.unpack(prefix_binding_power[op] or {})
            if lbp then
                self:skip()
                local inner = self:expr_bp(lbp)
                if not inner then
                    self:fatal()
                end
                lhs = Expr.UnOp { kind = kind, inner = inner }
            end
        end
        if not lhs then
            return nil
        end
        while true do
            local token = self.tokens[self.i]
            if not token or token.type ~= 'keyword' and token.type ~= 'punctuation' then
                break
            end
            local op = token.value
            if is_prefix(lhs) then
                if op == '(' then
                    self:skip()
                    local args = self:list(self.expr)
                    if not self:eat(')') then
                        self:fatal()
                    end
                    lhs = Expr.Call { callee = lhs, args = args }
                    goto continue
                end
            end
            local lbp, rbp, kind = table.unpack(infix_binding_power[op] or {})
            if not lbp or lbp < min_bp then
                break
            end
            self:skip()
            local rhs = self:expr_bp(rbp)
            if not rhs then
                self:fatal()
            end
            lhs = Expr.BinOp { kind = kind, left = lhs, right = rhs }
            ::continue::
        end
        return lhs
    end

    function parser:expr()
        return self:expr_bp(0)
    end

    function parser:stmt()
        if self:eat('local') then
            local variables = self:list(self.identifier)
            local init_list = {}
            if self:eat('=') then
                init_list = self:list(self.expr)
            end
            return Stmt.Local { variables = variables, init_list = init_list }
        elseif self:eat('return') then
            local values = self:list(self.expr)
            return Stmt.Return { values = values }
        else
            local saved = self.i
            local call = self:expr()
            if call and call:is('Call') then
                return Stmt.Call(call)
            end
            self.i = saved
            return nil
        end
    end

    function parser:block()
        local block = { _type = 'Block' }
        while true do
            local statement = self:stmt()
            if not statement then
                break
            end
            table.insert(block, statement)
        end
        return block
    end

    function parser:program()
        local block = self:block()
        if self.i ~= #self.tokens + 1 then
            self:fatal()
        end
        return block
    end

    return parser
end

function Parser.parse(tokens)
    return Parser.makeParser(tokens):program()
end

function Parser.debugString(tree)
    local function debugList(items)
        local formatted = {}
        for _, item in ipairs(items) do
            if type(item) == 'string' then
                table.insert(formatted, item)
            else
                table.insert(formatted, Parser.debugString(item))
            end
        end
        return table.concat(formatted, ', ')
    end
    if tree._type == 'Expr' then
        if tree:is('BinOp') then
            return '(' ..
                tree.kind .. ' ' .. Parser.debugString(tree.left) .. ' ' .. Parser.debugString(tree.right) .. ')'
        elseif tree:is('UnOp') then
            return '(' .. tree.kind .. ' ' .. Parser.debugString(tree.inner) .. ')'
        elseif tree:is('Number') then
            return repr(tree.value)
        elseif tree:is('LiteralNil') then
            return 'nil'
        elseif tree:is('Variable') then
            return tree.name
        elseif tree:is('Call') then
            return Parser.debugString(tree.callee) .. '(' .. debugList(tree.args) .. ')'
        else
            error('cannot syntax tree debug print expr ' .. tree._variant .. repr(tree))
        end
    elseif tree._type == 'Stmt' then
        if tree:is('Local') then
            local init = ''
            if #tree.init_list ~= 0 then
                init = ' = ' .. debugList(tree.init_list)
            end
            return 'local ' .. debugList(tree.variables) .. init
        elseif tree:is('Return') then
            return 'return ' .. debugList(tree.values)
        elseif tree:is('Call') then
            return Parser.debugString(Expr.Call(tree))
        else
            error('cannot syntax tree debug print stmt ' .. tree._variant .. repr(tree))
        end
    elseif tree._type == 'Block' then
        local formatted = {}
        for _, statement in ipairs(tree) do
            table.insert(formatted, Parser.debugString(statement))
        end
        return '{ ' .. table.concat(formatted, '; ') .. ' }'
    else
        error('cannot syntax tree debug print ' .. (tree._type or '<unknown>') .. repr(tree))
    end
end

return Parser
