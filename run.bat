@echo off

lua main.lua
nasm -f elf64 out.asm -o out.o
gcc out.o -o out.exe
out.exe
@REM sleep 999999999
