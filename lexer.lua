local Lexer = {}

local Die = (require 'die')('lexing')
local repr = require 'repr'

local keywords = { 'and', 'break', 'do', 'else', 'elseif', 'end', 'false', 'for', 'function', 'global', 'goto', 'if',
    'in', 'local', 'nil', 'not', 'or', 'repeat', 'return', 'then', 'true', 'until', 'while' }

local punctuation = { '...', '<<', '>>', '//', '==', '~=', '<=', '>=', '::', '..', '+', '-', '*', '/', '%', '^', '#', '&',
    '~', '|', '<', '>', '=', '(', ')', '{', '}', '[', ']', ';', ':', ',', '.' }

local lexers = {
    -- whitespace
    { '%s+',           function() return false end },
    -- long comment
    { '%-%-%[(=*)%[', function() Die.fatal('todo: long comments') end },
    -- short comment
    { '%-%-.-\n',     function() return false end },
    -- number
    { '(%d+)(%a*)', function(num, adjacent_letters)
        if #adjacent_letters > 0 then
            Die.fatal(adjacent_letters)
        end
        return { type = 'number', value = tonumber(num) }
    end },
    -- keyword or identifier
    { '([%a_][%a%d_]*)', function(str)
        for _, keyword in ipairs(keywords) do
            if keyword == str then
                return { type = 'keyword', value = keyword }
            end
        end
        return { type = 'identifier', value = str }
    end },
    -- punctuation
    -- { punctuation_pattern, function(str) return { type = 'punctuation', value = str } end }
}

function Lexer.lex(source)
    local tokens = {}
    local offset = 1
    while offset <= #source do
        for _, lexer in ipairs(lexers) do
            local result = { source:match('^' .. lexer[1] .. '()', offset) }
            if result[1] then
                local token, added_offset = (lexer[2])(table.unpack(result))
                if token then
                    table.insert(tokens, token)
                end
                if added_offset then
                    offset = offset + added_offset
                else
                    offset = result[#result]
                end
                goto next_token
            end
        end
        for _, p in ipairs(punctuation) do
            if p == source:sub(offset,offset+#p-1) then
                local token={type='punctuation',value=p}
                table.insert(tokens, token)
                offset = offset + #p
                goto next_token
            end
        end
        Die.fatal('unknown thingy at ' .. offset .. ': ' .. repr(source:sub(offset)):sub(1, 50))
        ::next_token::
    end
    return tokens
end

return Lexer
