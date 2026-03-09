# EXE Builder

Experimental backend, for building .EXE files from scratch.
Currently has a simple WIP system for declaring instructions.

## Goals
I previously used an assembler as part of my compiler to generate the machine code,
but this has many negatives :

- extra {assembler}.exe dependency in the project (less portable, slower, less reliable)
- working with text strings is slow and imprecise
- many of the features of the assembler are not helpful (macros, labels)
- labels in particular are easier to express as just code offsets, rather than strings when generating code.
- redundant layer of lowering to assembly, so that the assembler can
    re-parse the assembler text
    lower to actual machine code

When compared to other available compiler backends, such as LLVM
the benifits are really just simplicity and (compile) speed.

The eventual goal is *not* to provide an `optimising` backend,
but just a fast, dumb, x64 emit for compile speed.

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

        eb.write(&a, eb.sub_imm8(.RSP, 8 * 5))

        // printf("hello world!, number is %d", 420);
        eb.write(&a, eb.lea(.RCX, 0))
        eb.call_string(&a, "hello world!, number is %d")
        eb.write(&a, eb.movq_imm64(.RDX, 420))
        eb.write(&a, eb.call_relative_32(0))
        eb.call_import(&a, "printf")

        // ExitProcess(0);
        eb.write(&a, eb.movq_imm64(.RCX, 0))
        eb.write(&a, eb.call_relative_32(0))
        eb.call_import(&a, "ExitProcess")

    eb.end(&a)

    eb.build(&a, "helloworld.exe")
}
```
