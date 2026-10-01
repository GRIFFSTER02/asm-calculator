# Assembly Calculator

A simple integer calculator written in x86-64 NASM assembly, with no libc. It supports `+ - * / %` on signed 64-bit integers.

## Requirements

- [NASM](https://www.nasm.us/)
- Linux: `ld` (part of binutils)
- Windows: MSVC build tools **or** MinGW-w64

## Build

### Linux

```bash
nasm -felf64 linux-calc.asm -o linux-calc.o
ld -o linux-calc linux-calc.o
./linux-calc
```

### Windows (MSVC, from a Developer Command Prompt)

```bat
nasm -fwin64 win-calc.asm -o win-calc.obj
link /subsystem:console /entry:start win-calc.obj kernel32.lib
win-calc.exe
```

### Windows (MinGW-w64)

```bash
nasm -fwin64 win-calc.asm -o win-calc.obj
gcc win-calc.obj -o win-calc.exe -nostartfiles -Wl,-e,start -lkernel32
./win-calc.exe
```

## Usage

```
calc> 12 + 30
42
calc> 7 * -6
-42
calc> 100 / 7
14
calc> 100 % 7
2
```

Type `q` to quit (or Ctrl-D on Linux, Ctrl-Z then Enter on Windows).
