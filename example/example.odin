package example

import os "core:os/os2"
import "core:fmt"
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

        eb.w(&a, eb.sub_rm64_imm32(eb.rm_reg(.RSP), 8 * 5))

        // printf("hello world!, number is %d", 420)
        eb.lea_string(&a, .RCX, "hello world!, number is %d")
        eb.w(&a, eb.mov_r64_imm64(.RDX, 420))
        eb.call_import(&a, "printf")

        // ExitProcess(0);
        eb.w(&a, eb.mov_r64_imm64(.RCX, 0))
        eb.call_import(&a, "ExitProcess")

    eb.end(&a)

    FILENAME :: "helloworld.exe"

    eb.build(&a, FILENAME)

    state, std_out, std_err, err := os.process_exec({command = {FILENAME}}, context.allocator)
    fmt.println(string(std_out))
    os.exit(state.exit_code)
}