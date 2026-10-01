; calc.asm - integer calculator, x86-64 Linux, NASM, no libc
; Build: nasm -felf64 calc.asm && ld -o calc calc.o
; Usage: type "12 + 30", "7 * -6", "100 / 7", "100 % 7"; "q" or Ctrl-D quits

global _start

section .data
prompt:     db "calc> "
prompt_len  equ $ - prompt
err_syn:    db "syntax error", 10
err_syn_len equ $ - err_syn
err_div:    db "division by zero", 10
err_div_len equ $ - err_div

section .bss
buf:        resb 64
out:        resb 24

section .text

_start:
.loop:
    mov     rsi, prompt
    mov     edx, prompt_len
    call    print_str

    xor     eax, eax            ; read(0, buf, 63)
    xor     edi, edi
    mov     rsi, buf
    mov     edx, 63
    syscall
    test    rax, rax
    jle     .exit               ; EOF or error
    mov     byte [buf + rax], 0

    mov     rsi, buf
    call    skip_spaces
    cmp     byte [rsi], 'q'
    je      .exit

    call    parse_int           ; left operand
    jc      .syntax
    mov     r12, rax

    call    skip_spaces
    movzx   r14d, byte [rsi]    ; operator
    inc     rsi

    call    parse_int           ; right operand
    jc      .syntax
    mov     r13, rax

    mov     rax, r12
    cmp     r14b, '+'
    je      .add
    cmp     r14b, '-'
    je      .sub
    cmp     r14b, '*'
    je      .mul
    cmp     r14b, '/'
    je      .div
    cmp     r14b, '%'
    je      .mod
    jmp     .syntax

.add:
    add     rax, r13
    jmp     .show
.sub:
    sub     rax, r13
    jmp     .show
.mul:
    imul    rax, r13
    jmp     .show
.div:
    test    r13, r13
    jz      .divzero
    cqo
    idiv    r13
    jmp     .show
.mod:
    test    r13, r13
    jz      .divzero
    cqo
    idiv    r13
    mov     rax, rdx
.show:
    call    print_int
    jmp     .loop

.syntax:
    mov     rsi, err_syn
    mov     edx, err_syn_len
    call    print_str
    jmp     .loop
.divzero:
    mov     rsi, err_div
    mov     edx, err_div_len
    call    print_str
    jmp     .loop

.exit:
    mov     eax, 60
    xor     edi, edi
    syscall

; ---------------------------------------------------------------
; print_str: rsi = pointer, edx = length
print_str:
    mov     eax, 1
    mov     edi, 1
    syscall
    ret

; skip_spaces: advances rsi past spaces/tabs
skip_spaces:
.l:
    mov     al, [rsi]
    cmp     al, ' '
    je      .n
    cmp     al, 9
    jne     .done
.n:
    inc     rsi
    jmp     .l
.done:
    ret

; parse_int: rsi = text; returns rax = value, rsi advanced, CF set on error
parse_int:
    call    skip_spaces
    xor     r8d, r8d            ; negative flag
    cmp     byte [rsi], '-'
    jne     .digits
    inc     r8d
    inc     rsi
.digits:
    xor     eax, eax
    xor     ecx, ecx            ; digit count
.l:
    movzx   edx, byte [rsi]
    sub     edx, '0'
    cmp     edx, 9
    ja      .done
    imul    rax, rax, 10
    add     rax, rdx
    inc     rsi
    inc     ecx
    jmp     .l
.done:
    test    ecx, ecx
    jz      .bad
    test    r8d, r8d
    jz      .ok
    neg     rax
.ok:
    clc
    ret
.bad:
    stc
    ret

; print_int: rax = signed value, prints it with newline
print_int:
    mov     rdi, out + 23
    mov     byte [rdi], 10
    mov     r8, rax
    test    rax, rax
    jns     .conv
    neg     rax
.conv:
    mov     ecx, 10
.l:
    xor     edx, edx
    div     rcx
    add     dl, '0'
    dec     rdi
    mov     [rdi], dl
    test    rax, rax
    jnz     .l
    test    r8, r8
    jns     .write
    dec     rdi
    mov     byte [rdi], '-'
.write:
    mov     edx, out + 24
    sub     rdx, rdi
    mov     rsi, rdi
    jmp     print_str