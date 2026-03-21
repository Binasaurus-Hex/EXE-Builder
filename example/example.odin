package example

import os "core:os/os2"
import sa "core:container/small_array"
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
        },
        {
            dll_name = "raylib.dll",
            functions = {
                { name = "InitWindow" },
                { name = "WindowShouldClose" },
                { name = "BeginDrawing" },
                { name = "EndDrawing" },
                { name = "DrawCircleV" },
                { name = "DrawCircle" },
            }
        }
    }

    eb.begin(&a)

        eb.set_subsystem(&a, .GUI)

        // code
        eb.w(&a, eb.push_r64(.RBP))
        eb.w(&a, eb.mov_r64_rm64(.RBP, eb.rm_reg(.RSP)))

        offset: i32 = 8 * 4

        position := eb.make_var(&offset, 8)
        radius := eb.make_var(&offset, 8)

        eb.w(&a, eb.sub_rm64_imm32(eb.rm_reg(.RSP), eb.align(transmute(u32)offset, 16)))

        eb.set_f64(&a, radius, transmute(f64)[2]f32{20, 0})
        eb.set_f64(&a, position, transmute(f64)[2]f32 { 100, 100 })

        // printf("hello world!, number is %d", 420)
        eb.lea_string(&a, .RCX, "hello world!, number is %d")
        eb.w(&a, eb.mov_r64_imm64(.RDX, 420))
        eb.call_import(&a, "printf")

        eb.w(&a, eb.mov_r64_imm64(.RCX, 400))
        eb.w(&a, eb.mov_r64_imm64(.RDX, 300))
        eb.lea_string(&a, .R8, "MyWindow")
        eb.call_import(&a, "InitWindow")

        loop_cond := eb.make_label(&a)
        eb.call_import(&a, "WindowShouldClose")
        eb.w(&a, eb.cmp_rax_imm32(0))
        eb.w(&a, eb.jnz_rel32(0))
        loop_exit := eb.make_label(&a)

        // render loop
        eb.call_import(&a, "BeginDrawing")


        // draw circle
        eb.w(&a, eb.mov_r64_imm64(.RCX, transmute(u64)[2]f32{ 200, 100 }))
        // eb.w(&a, eb.movsd_load(eb.RegisterCode(0), eb.rm_disp32(.RBP, position)))
        eb.w(&a, eb.movsd_load(eb.XMM(1), eb.rm_disp32(.RBP, radius)))
        eb.w(&a, eb.mov_rm64_imm32(eb.rm_reg(.R8), transmute(u32)[4]u8 { 255, 0, 0, 255 }))
        eb.call_import(&a, "DrawCircleV")


        eb.call_import(&a, "EndDrawing")

        eb.w(&a, eb.jmp_rel32(0))
        eb.set_jump_back(&a, loop_cond)
        // exit
        eb.set_jump(&a, loop_exit)

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