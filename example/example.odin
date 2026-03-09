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