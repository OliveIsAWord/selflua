default rel
extern printf

section .rodata
    printf_fmt db "%f", 10, 0

section .bss
data_stack_boundary:
    resb 16 * 10000
data_stack:

section .text
global main
main:
    sub rsp, 40 ; cargo cult stack alignment
    mov rbp, data_stack
    finit
    call lua_entry
    lea rcx, [printf_fmt]
    mov rdx, [rbp]
    call printf

    add rsp, 40
    xor eax, eax
    ret

op_push:
    sub rbp, 8
    mov qword [rbp], rdi
    ret

op_add:
    fld qword [rbp+8]
    fld qword [rbp]
    faddp st1, st0
    add rbp, 8
    fstp qword [rbp]
    ret

op_sub:
    fld qword [rbp+8]
    fld qword [rbp]
    fsubp st1, st0
    add rbp, 8
    fstp qword [rbp]
    ret

op_mul:
    fld qword [rbp+8]
    fld qword [rbp]
    fmulp st1, st0
    add rbp, 8
    fstp qword [rbp]
    ret

op_div:
    fld qword [rbp+8]
    fld qword [rbp]
    fdivp st1, st0
    add rbp, 8
    fstp qword [rbp]
    ret

op_neg:
    fld qword [rbp]
    fchs
    fstp qword [rbp]
    ret
