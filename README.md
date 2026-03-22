# EXE Builder

Library for building .EXE files from scratch without a linker.
(WARNING) project is very early in development

## Features
- functions for outputting x64 instructions
- declarative imports for DLLs and their functions
- Immediate mode (begin/end) api for building your EXE

## Goals
- provide a fast, minimal way to build EXE's without external dependencies
- provide a basic, *non-optimised* code generation backend for compilers

## Printf Example
```odin
package example

import eb ".."

main :: proc(){
    a: eb.Assembler

    a.import_entries = {
        {
            dll_name = "KERNEL32.DLL",
            functions = {
                { name = "ExitProcess" }
            }
        },
        {
            dll_name = "MSVCRT.DLL",
            functions = {
                { name = "printf" }
            }
        }
    }

    eb.begin(&a)

        eb.set_subsystem(&a, .CONSOLE)

        // stack frame init
        eb.w(&a, eb.push_r64(.RBP))
        eb.w(&a, eb.mov_r64_rm64(.RBP, eb.rm_reg(.RSP)))
        eb.w(&a, eb.sub_rm64_imm32(eb.rm_reg(.RSP), 8 * 4))

        // printf("hello world!, number is %d", 420)
        eb.lea_string(&a, .RCX, "hello world!, number is %d")
        eb.w(&a, eb.mov_r64_imm64(.RDX, 420))
        eb.call_import(&a, "printf")

        // ExitProcess(0);
        eb.w(&a, eb.mov_r64_imm64(.RCX, 0))
        eb.call_import(&a, "ExitProcess")

    eb.end(&a)

    eb.build(&a, "helloworld.exe")
}
```
