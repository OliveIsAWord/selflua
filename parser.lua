local Parser = {}

local Die = (require 'die')('parsing')
local repr = require 'repr'

local function infix_binding_power(op)
    if op == '+' or op == '-' then
        return 17, 18
    elseif op == '*' or op == '/' then
        return 19, 20
    end
end

local function prefix_binding_power(op)
    if op == 'not' or op == '#' or op == '-' or op == '~' then
        return 21
    end
end

function Parser.makeParser(tokens_parameter)
    local parser = { i = 1, tokens = tokens_parameter }
    function parser:skip()
        self.i = self.i + 1
    end

    function parser:eat(literal)
        local token = self.tokens[self.i]
        if (token.type == 'punctuation' or token.type == 'keyword') and token.value == literal then
            parser:skip()
            return token
        end
        return nil
    end

    function parser:number()
        local token = self.tokens[self.i]
        if token.type == 'number' then
            parser:skip()
            return token
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
                lhs = { subtype = 'number', value = number.value }
            end
        end
        if not lhs and self.tokens[self.i] then
            local op = self.tokens[self.i].value
            local lbp = prefix_binding_power(op)
            if lbp then
                self:skip()
                local inner = self:expr_bp(lbp)
                if op == '-' then
                    op='neg'
                elseif op == '~' then
                    op='bitnot'
                end
                lhs = { subtype = op, inner = inner }
            end
        end
        if not lhs then
            if optional then
                return nil
            else
                self:fatal()
            end
        end
        lhs.type = 'expr'
        while true do
            local token = self.tokens[self.i]
            if not token or token.type ~= 'keyword' and token.type ~= 'punctuation' then
                break
            end
            local op = token.value
            local lbp, rbp = infix_binding_power(op)
            if lbp then
                if lbp < min_bp then
                    break
                end
                self:skip()
                local rhs = self:expr_bp(rbp)
                lhs = {
                    type = 'expr',
                    subtype = op,
                    lhs = lhs,
                    rhs = rhs,
                }
            end
        end
        return lhs
    end

    function parser:expr()
        return self:expr_bp(0)
    end

    function parser:block()
        local block = { type = 'block' }
        -- todo: parse statements
        block.statements = {}
        if self:eat('return') then
            block.returns = { self:one(self.expr) }
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
    if tree.type == 'expr' then
        if tree.lhs and tree.rhs then
            return '(' ..
            tree.subtype .. ' ' .. Parser.debugString(tree.lhs) .. ' ' .. Parser.debugString(tree.rhs) .. ')'
        elseif tree.inner then
            return '(' .. tree.subtype .. ' ' .. Parser.debugString(tree.inner) .. ')'
        elseif tree.subtype == 'number' then
            return repr(tree.value)
        else
            error('cannot syntax tree debug print:\n' .. repr(tree))
        end
    else
        error('cannot syntax tree debug print:\n' .. repr(tree))
    end
end

return Parser
