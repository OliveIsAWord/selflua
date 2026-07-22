bits 64
default rel
extern printf
extern ExitProcess

%define TAG_FLOAT 2
%define TAG_NIL 4

section .rodata
    printf_fmt_float: db "%f", 0
    string_nil: db "nil", 0
    string_newline: db 10, 0
    string_error: db "ERROR!", 10, 0

section .bss
data_stack_boundary:
    resb 16 * 10000
data_stack:

%macro CCONV_PRELUDE 0
    push rbp
    mov rbp, rsp
    mov rax, rsp
    and rax, 15
    sub rsp, rax
    sub rsp, 32
%endmacro

%macro CCONV_RETURN 0
    mov rsp, rbp
    pop rbp
    ret
%endmacro

section .text
global main
main:
    push rbp
    mov rbp, rsp
    sub rsp, 32
    
    mov rbx, data_stack
    finit
    call lua_entry
    call op_print_value

    xor rax, rax
    mov rsp, rbp
    pop rbp
    ret

op_push_number:
    sub rbx, 16
    mov qword [rbx], rdi
    mov qword [rbx+8], TAG_FLOAT
    ret

op_push_unit:
    sub rbx, 16
    mov qword [rbx], 0xAAAAAAAA
    mov qword [rbx+8], rdi
    ret
    
%macro ARITHMETIC_BINOP 1
    cmp qword [rbx+24], TAG_FLOAT
    jne error
    cmp qword [rbx+8], TAG_FLOAT
    jne error
    fld qword [rbx+16]
    fld qword [rbx]
    %1 st1, st0
    add rbx, 16
    fstp qword [rbx]
    ; mov qword [rbx+8], TAG_FLOAT ; redundant for now
    ret
%endmacro

%macro ARITHMETIC_UNOP 1
    cmp qword [rbx+8], TAG_FLOAT
    jne error
    fld qword [rbx]
    %1
    fstp qword [rbx]
    ret
%endmacro

op_add:
    ARITHMETIC_BINOP faddp

op_sub:
    ARITHMETIC_BINOP fsubp

op_mul:
    ARITHMETIC_BINOP fmulp

op_div:
    ARITHMETIC_BINOP fdivp

op_neg:
    ARITHMETIC_UNOP fchs

op_print_value:
    CCONV_PRELUDE
    mov al, [rbx+8]
    cmp al, TAG_FLOAT
    je print_float
    cmp al, TAG_NIL
    je print_nil
    ud2
print_float:
    lea rcx, qword [printf_fmt_float]
    mov rdx, qword [rbx]
    movq xmm1, qword [rbx]
    call printf
    jmp print_end
print_nil:
    lea rcx, qword [string_nil]
    call printf
    jmp print_end
print_end:
    add rbx, 16
    lea rcx, [string_newline]
    call printf
    CCONV_RETURN

error:
    CCONV_PRELUDE
    lea rcx, qword [string_error]
    call printf
    mov eax, 1
    call ExitProcess
