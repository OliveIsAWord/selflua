bits 64
default rel
extern printf
extern ExitProcess

%define TAG_FLOAT 2
%define TAG_NIL 8
%define TAG_FUNCTION 16

section .rodata
    printf_fmt_float: db "%f", 0
    printf_fmt_function: db "function %s %p", 0
    string_nil: db "nil", 0
    string_newline: db 10, 0
    string_error: db "ERROR!", 10, 0

section .bss
data_stack_boundary:
    resb 16 * 10000
data_stack:

scratch: resb 8

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
    call builtin_print

    xor rax, rax
    mov rsp, rbp
    pop rbp
    ret

%macro PUSH 2
    sub rbx, 16
    mov qword [rbx], %2
    mov qword [rbx+8], %1
%endmacro

%macro OP_PUSH_FLOAT 1
    PUSH TAG_FLOAT, %1
%endmacro

%macro OP_PUSH_UNIT 1
    PUSH %1, 0x5555_5555
%endmacro

%macro OP_PUSH_BUILTIN 1
    lea rax, builtin_%1
    PUSH TAG_FUNCTION, rax
%endmacro

%macro BEGIN_FUNCTION 1
    push rbp
    mov rbp, rsp
    sub rsp, %1 * 16
%endmacro

op_ret:
    mov rsp, rbp
    pop rbp
    ret

%macro OP_GET_LOCAL 1
    %assign local_offset (%1 * 16 + 16)
    sub rbx, 16
    mov rax, qword [rbp-local_offset]    
    mov qword [rbx], rax
    mov rax, qword [rbp-local_offset+8]
    mov qword [rbx+8], rax
%endmacro

%macro OP_ASSIGN_LOCAL 1
    %assign local_offset (%1 * 16 + 16)
    mov rax, qword [rbx]
    mov qword [rbp-local_offset], rax
    mov rax, qword [rbx+8]
    mov qword [rbp-local_offset+8], rax
    add rbx, 16
%endmacro

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

%macro DEFINE_BUILTIN 1
section .rodata
    builtin_name_%1: db %str(%1), 0
section .text
    dq builtin_name_%1
builtin_%1:
%endmacro

DEFINE_BUILTIN print
    CCONV_PRELUDE
    mov al, [rbx+8]
    cmp al, TAG_FLOAT
    je print_float
    cmp al, TAG_NIL
    je print_nil
    cmp al, TAG_FUNCTION
    je print_function
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
print_function:
    lea rcx, qword [printf_fmt_function]
    ; function <name> <address>
    ; A pointer to the name string is stored right behind the function.
    mov r8, qword [rbx]
    mov qword [scratch], r8
    movq xmm2, qword [scratch]
    mov rdx, qword [r8-8]
    mov qword [scratch], rdx
    movq xmm1, qword [scratch]
    call printf
    jmp print_end
print_end:
    add rbx, 16
    lea rcx, [string_newline]
    call printf
    OP_PUSH_UNIT TAG_NIL
    CCONV_RETURN

error:
    CCONV_PRELUDE
    lea rcx, qword [string_error]
    call printf
    mov eax, 1
    call ExitProcess
