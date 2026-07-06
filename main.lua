-- setmetatable(_G, {
--     __newindex = function(_, k, _)
--         error('write to undeclared var ' .. tostring(k), 2)
--     end,
--     __index = function(_, k)
--         error('read to undeclared var ' .. tostring(k), 2)
--     end,
-- })

local repr = require 'repr'
local Lexer = require 'lexer'
local Parser = require 'parser'
local Bytecode = require 'bytecode'
local Codegen = require 'x86-64.gen'

local source = io.open('example.lua'):read('a')
local tokens = Lexer.lex(source)
local syntax_tree = Parser.parse(tokens)
print(Parser.debugString(syntax_tree.returns[1]))
local bytecode=Bytecode.build(syntax_tree)
print(repr(bytecode))
local assembly=Codegen.codegen(bytecode)
print(assembly)
io.open('out.asm', "w+"):write(assembly)
