local Parser = {}

local Die = (require 'die')('parsing')
local repr = require 'repr'
local BetterTypes = require 'better_types'

Parser.Expr = BetterTypes.Enum 'Expr' {
    Number = { 'value' },
    LiteralNil = {},
    Variable = { 'name' },
    UnOp = { 'kind', 'inner' },
    BinOp = { 'kind', 'left', 'right' },
}
local Expr = Parser.Expr

Parser.Stmt = BetterTypes.Enum 'Stmt' {
    Local = { 'name', 'init' },
    Return = { 'value' },
}
local Stmt = Parser.Stmt

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

    function parser:expr_bp(min_bp, optional)
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
                lhs = Expr.UnOp { kind = kind, inner = inner }
            end
        end
        if not lhs then
            if optional then
                return nil
            else
                self:fatal()
            end
        end
        while true do
            local token = self.tokens[self.i]
            if not token or token.type ~= 'keyword' and token.type ~= 'punctuation' then
                break
            end
            local op = token.value
            local lbp, rbp, kind = table.unpack(infix_binding_power[op] or {})
            if not lbp or lbp < min_bp then
                break
            end
            self:skip()
            local rhs = self:expr_bp(rbp)
            lhs = Expr.BinOp { kind = kind, left = lhs, right = rhs }
        end
        return lhs
    end

    function parser:expr()
        return self:expr_bp(0)
    end

    function parser:stmt()
        if self:eat('local') then
            local variable = self:one(self.identifier)
            local init_expr = {}
            if self:eat('=') then
                init_expr[#init_expr + 1] = self:one(self.expr)
            end
            return Stmt.Local { name = variable, init = init_expr }
        elseif self:eat('return') then
            local value = self:one(self.expr)
            return Stmt.Return { value = value }
        else
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
        else
            error('cannot syntax tree debug print expr ' .. tree._variant .. repr(tree))
        end
    elseif tree._type == 'Stmt' then
        if tree:is('Local') then
            local init = ''
            if tree.init[1] then
                init = ' = ' .. Parser.debugString(tree.init[1])
            end
            return 'local ' .. tree.name .. init
        elseif tree:is('Return') then
            return 'return ' .. Parser.debugString(tree.value)
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
        error('cannot syntax tree debug print ' .. tree._type .. repr(tree))
    end
end

return Parser
