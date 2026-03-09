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

