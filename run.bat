@echo off

lua main.lua
nasm -f elf64 -g -F dwarf out.asm -o out.o
gcc out.o -o out.exe
out.exe
echo done
sleep 999999999
