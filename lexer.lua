local Lexer = {}

local Die = require 'die' 'lexing'
local repr = require 'repr'

local string_escapes = {
    ['a'] = '\a',
    ['b'] = '\b',
    ['f'] = '\f',
    ['n'] = '\n',
    ['r'] = '\r',
    ['t'] = '\t',
    ['v'] = '\v',
    ['\\'] = '\\',
    ['"'] = '"',
    ['\''] = '\'',
}

local keywords = { 'and', 'break', 'do', 'else', 'elseif', 'end', 'false', 'for', 'function', 'global', 'goto', 'if',
    'in', 'local', 'nil', 'not', 'or', 'repeat', 'return', 'then', 'true', 'until', 'while' }

local punctuation = { '...', '<<', '>>', '//', '==', '~=', '<=', '>=', '::', '..', '+', '-', '*', '/', '%', '^', '#', '&',
    '~', '|', '<', '>', '=', '(', ')', '{', '}', '[', ']', ';', ':', ',', '.' }

function Lexer.lex(source)
    local tokens = {}
    local offset = 1
    while offset <= #source do
        -- skip whitespace
        local new_offset = source:match('^%s+()', offset)
        if new_offset then
            offset = new_offset
            goto continue
        end
        -- skip long comments
        local equals_count
        new_offset = source:match('^%-%-%[(=*)%[()', offset) -- pattern syntax makes this look ugly
        if new_offset then
            new_offset = source:match('^%]' .. string.rep('=', #equals_count) .. '%]()', new_offset)
            if not new_offset then
                Die.fatal('unclosed long comment')
            end
            offset = new_offset
            goto continue
        end
        -- skip line comments
        new_offset = source:match('^%-%-.-\n()', offset) -- note the non-greedy pattern `.-` so we get the first newline
        if new_offset then
            offset = new_offset
            goto continue
        end
        -- keyword or identifier
        local str, new_offset = source:match('^([%a_][%a%d_]*)()', offset)
        if new_offset then
            local type = 'identifier'
            for _, keyword in ipairs(keywords) do
                if keyword == str then
                    type = 'keyword'
                    str = keyword -- i doubt this line really does anything performance-wise
                    break
                end
            end
            table.insert(tokens, { type = type, value = str })
            offset = new_offset
            goto continue
        end
        -- string
        if source:match('^["\']', offset) then
            local is_double = source:sub(offset, offset) == '"'
            local chars = {}
            while true do
                offset = offset + 1
                local c = source:sub(offset, offset)
                if c == '"' and is_double then
                    break
                elseif c == '\'' and not is_double then
                    break
                elseif c == '\\' then
                    Die.fatal('todo: string escapes')
                elseif c == '\n' or c == '\r' or c == '' then
                    Die.fatal('unclosed string literal')
                else
                    table.insert(chars, c)
                end
            end
        end
        -- numerals
        local num, adjacent_letters, new_offset = source:match('^(%d+)(%a*)()', offset)
        if new_offset then
            if #adjacent_letters > 0 then
                Die.fatal(adjacent_letters)
            end
            table.insert(tokens, { type = 'number', value = tonumber(num) })
            offset = new_offset
            goto continue
        end
        -- punctuation
        for _, p in ipairs(punctuation) do
            if p == source:sub(offset, offset + #p - 1) then
                local token = { type = 'punctuation', value = p }
                table.insert(tokens, token)
                offset = offset + #p
                goto continue
            end
        end
        Die.fatal('unknown thingy at ' .. offset .. ': ' .. repr(source:sub(offset)):sub(1, 50))
        ::continue::
    end
    return tokens
end

return Lexer
