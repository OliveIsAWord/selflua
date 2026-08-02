@echo off

lua main.lua
nasm -O0 -f elf64 -g -F dwarf out.asm -o out.o
gcc out.o -o out.exe
out.exe
echo done
sleep 999999999
