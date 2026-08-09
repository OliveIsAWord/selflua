; Register Mapping:
; rax - scratch register, clobbered by ops
; rbx - data stack pointer
; rcx - data stack base pointer (points to function object followed by arguments and locals), clobbered by calls
; rdx - ?

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
    string_space: db "/", 10, 0
    string_newline: db 10, 0
    string_error: db "ERROR!", 10, 0

section .bss
data_stack_boundary:
    resb 16 * 10000
data_stack:

scratch: resb 8

section .text

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

op_pop:
    add rbx, 16
    ret

%macro PUSH 2
    sub rbx, 16
    ; value
    mov qword [rbx], %2
    ; tag
    mov qword [rbx+8], %1
%endmacro

%macro OP_PUSH_FLOAT 1
    mov rax, %1
    PUSH TAG_FLOAT, rax
%endmacro

%macro OP_PUSH_FUNCTION 1
    lea rax, chunk_%1
    PUSH TAG_FUNCTION, rax
%endmacro

%macro OP_PUSH_UNIT 1
    PUSH TAG_%1, 0x5555_5555
%endmacro

%macro OP_PUSH_BUILTIN 1
    lea rax, builtin_%1
    PUSH TAG_FUNCTION, rax
%endmacro

op_save_stack_pointer:
    pop rax
    push rbx
    jmp rax

op_call:
    pop r11
    pop rax
    push rcx
    mov rcx, rax
    push r11
    cmp qword [rcx-8], TAG_FUNCTION
    jne error
    jmp qword [rcx-16]
    
%macro OP_BEGIN_FUNCTION 1
    push rbp
    mov rbp, rsp
    mov rax, %1 + 1
    mov r8, rcx
    call raw_multi_adjust
%endmacro

%macro OP_ALLOCATE_LOCALS 1
    %rep %1
        OP_PUSH_UNIT NIL
    %endrep
%endmacro

op_ret:
    pop rax
    pop rax
    mov r8, rcx
ret_loop:
    cmp rax, rbx
    je ret_loop_end
    sub rax, 16
    sub r8, 16
    mov r9, qword [rax]
    mov qword [r8], r9
    mov r9, qword [rax+8]
    mov qword [r8+8], r9
    jmp ret_loop
ret_loop_end:
    mov rbx, r8
    pop rbp
    ret
    
op_call_end_many:
    pop r11
    pop rcx
    jmp r11

%macro OP_CALL_END_ADJUST 1
    mov rax, %1
    mov r8, rcx
    pop rcx
    call raw_multi_adjust
%endmacro
raw_multi_adjust:
    shl rax, 4
    neg rax
    add rax, r8
    cmp rax, rbx
    jb fill_nils
    mov rbx, rax
    ret
fill_nils:
    OP_PUSH_UNIT NIL
    cmp rax, rbx
    jne fill_nils
    ret
    
%macro OP_GET_LOCAL 1
    mov rax, %1
    add rax, 2
    shl rax, 4
    neg rax
    add rax, rcx
    sub rbx, 16
    mov r8, qword [rax]
    mov qword [rbx], r8
    mov r8, qword [rax+8]
    mov qword [rbx+8], r8
%endmacro

%macro OP_ASSIGN_LOCAL 1
    mov rax, %1
    add rax, 2
    shl rax, 4
    neg rax
    add rax, rcx
    mov r8, qword [rbx]
    mov qword [rax], r8
    mov r8, qword [rbx+8]
    mov qword [rax+8], r8
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

%macro DEFINE_CHUNK 2
section .rodata
    chunk_name_%1: db %str(%2), 0
section .text
    dq chunk_name_%1
chunk_%1:
%endmacro

DEFINE_BUILTIN print
    CCONV_PRELUDE
    mov r12, rcx
    ; sub r12, 16
    mov r13, 0
print_loop:
    cmp r13, 0
    je print_no_space
    lea rcx, qword [string_space]
    call printf
print_no_space:
    mov r13, 1
    sub r12, 16
    cmp r12, rbx
    jb print_end
    mov al, [r12+8]
    cmp al, TAG_FLOAT
    je print_float
    cmp al, TAG_NIL
    je print_nil
    cmp al, TAG_FUNCTION
    je print_function
    ud2
print_float:
    lea rcx, qword [printf_fmt_float]
    mov rdx, qword [r12]
    movq xmm1, qword [r12]
    call printf
    jmp print_loop
print_nil:
    lea rcx, qword [string_nil]
    call printf
    jmp print_loop
print_function:
    lea rcx, qword [printf_fmt_function]
    ; function <name> <address>
    ; A pointer to the name string is stored right behind the function.
    mov r8, qword [r12]
    mov qword [scratch], r8
    movq xmm2, qword [scratch]
    mov rdx, qword [r8-8]
    mov qword [scratch], rdx
    movq xmm1, qword [scratch]
    call printf
    jmp print_loop
print_end:
    mov rbx, rdi
    lea rcx, [string_newline]
    call printf
    mov rcx, r12
    mov rbx, r12
    CCONV_RETURN

error:
    CCONV_PRELUDE
    lea rcx, qword [string_error]
    call printf
    mov eax, 1
    call ExitProcess

global main
extern exit
main:
    push rbp
    mov rbp, rsp
    sub rsp, 32
    
    mov rbx, data_stack
    mov rcx, rbx
    OP_PUSH_BUILTIN print
    OP_PUSH_BUILTIN print
    OP_PUSH_BUILTIN print
    finit
    ; execute the main chunk and print its return values
    push rcx
    mov rcx, rbx
    OP_PUSH_FUNCTION 1
    call chunk_1
    pop rcx
    call builtin_print
    xor rax, rax
    mov rsp, rbp
    pop rbp
    ret
