; calc_win.asm - integer calculator, x86-64 Windows, NASM, kernel32 only
;
; Build (MSVC tools, from a Developer Command Prompt):
;   nasm -fwin64 calc_win.asm -o calc_win.obj
;   link /subsystem:console /entry:start calc_win.obj kernel32.lib
;
; Build (MinGW-w64):
;   nasm -fwin64 calc_win.asm -o calc_win.obj
;   gcc calc_win.obj -o calc_win.exe -nostartfiles -Wl,-e,start -lkernel32
;
; Usage: type "12 + 30", "7 * -6", "100 / 7", "100 % 7"; "q" or Ctrl-Z quits

default rel
bits 64

global start

extern GetStdHandle
extern ReadFile
extern WriteFile
extern ExitProcess

section .data
prompt:     db "calc> "
prompt_len  equ $ - prompt
err_syn:    db "syntax error", 13, 10
err_syn_len equ $ - err_syn
err_div:    db "division by zero", 13, 10
err_div_len equ $ - err_div

section .bss
hIn:        resq 1
hOut:       resq 1
nbytes:     resd 1
buf:        resb 64
out:        resb 24

section .text

start:
    sub     rsp, 40             ; 32 shadow space + 8 for 5th arg; aligns stack

    mov     ecx, -10            ; STD_INPUT_HANDLE
    call    GetStdHandle
    mov     [hIn], rax
    mov     ecx, -11            ; STD_OUTPUT_HANDLE
    call    GetStdHandle
    mov     [hOut], rax

.loop:
    lea     rsi, [prompt]
    mov     edx, prompt_len
    call    print_str

    mov     rcx, [hIn]          ; ReadFile(hIn, buf, 63, &nbytes, NULL)
    lea     rdx, [buf]
    mov     r8d, 63
    lea     r9, [nbytes]
    mov     qword [rsp + 32], 0
    call    ReadFile
    test    eax, eax
    jz      .exit
    mov     eax, [nbytes]
    test    eax, eax
    jz      .exit               ; EOF
    lea     rsi, [buf]
    mov     byte [rsi + rax], 0

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
    lea     rsi, [err_syn]
    mov     edx, err_syn_len
    call    print_str
    jmp     .loop
.divzero:
    lea     rsi, [err_div]
    mov     edx, err_div_len
    call    print_str
    jmp     .loop

.exit:
    xor     ecx, ecx
    call    ExitProcess

; ---------------------------------------------------------------
; print_str: rsi = pointer, edx = length
print_str:
    sub     rsp, 40
    mov     r8d, edx            ; bytes to write
    mov     rdx, rsi            ; buffer
    mov     rcx, [hOut]
    lea     r9, [nbytes]
    mov     qword [rsp + 32], 0
    call    WriteFile
    add     rsp, 40
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

; print_int: rax = signed value, prints it followed by CRLF
print_int:
    lea     rdi, [out + 22]
    mov     byte [rdi], 13
    mov     byte [rdi + 1], 10
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
    lea     rdx, [out + 24]
    sub     rdx, rdi
    mov     rsi, rdi
    jmp     print_str           ; tail call; edx = length