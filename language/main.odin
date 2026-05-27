package main

import rl "vendor:raylib"
import "core:math/linalg"
import hm "core:container/handle_map"
import "core:fmt"
import "core:strings"
import "core:text/edit"
import "core:unicode/utf8"

Entity_Feature :: enum {
    Procedure,
}

Entity :: struct {
    handle: Entity_Handle,
    features: bit_set[Entity_Feature],

    label: int,
    inputs: [dynamic; 10]Entity_Handle,
    outputs: [dynamic; 10]Entity_Handle,
    instructions: [dynamic; 100]Entity_Handle,
}

Entity_Handle :: distinct hm.Handle64

Program :: struct {
    entities: hm.Static_Handle_Map(1000, Entity, Entity_Handle),
    labels: [dynamic; 200]Label(100),
}
program: Program

make_procedure :: proc(name: string) -> Entity_Handle {
    label: Label(100)
    label_set(&label, name)
    index := len(program.labels)
    append(&program.labels, label)

    return hm.add(&program.entities, Entity {
        label = index,
        features = { .Procedure },
    })
}

rect_screen :: proc() -> Rect {
    return { 0, 0, f32(rl.GetRenderWidth()), f32(rl.GetRenderHeight()) }
}

draw_rect :: proc(rect: Rect, color: rl.Color) {
    rl.DrawRectangleRec(transmute(rl.Rectangle)rect, color)
}

FONT_SIZE :: 20

draw_text_v :: proc(text: string, position: [2]f32, color: rl.Color, font_size :i32 = FONT_SIZE) {
    text_c := strings.clone_to_cstring(text, context.temp_allocator)
    rl.DrawText(text_c, i32(position.x), i32(position.y), font_size, color)
}

names := []string {
    "main",
    "vector_add",
    "helloworld"
}

main :: proc(){
    rl.InitWindow(500, 500, "Graph")

    char_width := rl.MeasureText("H", FONT_SIZE)

    edit_state: edit.State
    edit.init(&edit_state, context.allocator, context.allocator)

    builder := strings.builder_make()

    font := rl.GetFontDefault()


    edit.setup_once(&edit_state, &builder)
    for !rl.WindowShouldClose(){
        rl.BeginDrawing()
        rl.ClearBackground(rl.BLACK)

        text_input: [512]byte = ---
        text_input_offset := 0
        for text_input_offset < len(text_input) {
        ch := rl.GetCharPressed()
            if ch == 0 do break
            b, w := utf8.encode_rune(ch)
            copy(text_input[text_input_offset:], b[:w])
            text_input_offset += w
        }
        edit.input_text(&edit_state, string(text_input[:text_input_offset]))

        if rl.IsKeyPressed(.BACKSPACE){
            edit.perform_command(&edit_state, .Backspace)
        }
        if rl.IsKeyPressed(.ENTER){
            edit.perform_command(&edit_state, .New_Line)
        }
        if rl.IsKeyDown(.LEFT_CONTROL) {
            if rl.IsKeyPressed(.LEFT){
                edit.perform_command(&edit_state, .Word_Left)
            }
            if rl.IsKeyPressed(.RIGHT){
                edit.perform_command(&edit_state, .Word_Right)
            }
        }
        if rl.IsKeyDown(.LEFT_SHIFT){
            if rl.IsKeyPressed(.LEFT){
                edit.perform_command(&edit_state, .Select_Left)
            }
            if rl.IsKeyPressed(.RIGHT){
                edit.perform_command(&edit_state, .Select_Right)
            }
            if rl.IsKeyPressed(.DOWN){
                edit.perform_command(&edit_state, .Select_Down)
            }
            if rl.IsKeyPressed(.UP){
                edit.perform_command(&edit_state, .Select_Up)
            }
        }
        else {
            if rl.IsKeyPressed(.UP){
                edit.perform_command(&edit_state, .Up)
            }
            if rl.IsKeyPressed(.DOWN){
                edit.perform_command(&edit_state, .Down)
            }
            if rl.IsKeyPressed(.LEFT){
                edit.perform_command(&edit_state, .Left)
            }
            if rl.IsKeyPressed(.RIGHT){
                edit.perform_command(&edit_state, .Right)
            }
        }

        text := strings.to_string(builder)
        FONT_WIDTH :: 15

        fmt.println(edit_state.selection.x)

        lo, hi := edit.sorted_selection(&edit_state)
        pos: [2]int
        backing: Rect
        CEL_SIZE :: [2]f32 { FONT_WIDTH, FONT_SIZE }
        backing.zw = CEL_SIZE
        drawn_cursor: bool
        for c, i in text {
            backing.xy = linalg.array_cast(pos, f32) * backing.zw

            if i >= lo && i <= hi {
                draw_rect(backing, {100, 170, 220, 100 })
            }
            if i == edit_state.selection.x {
                drawn_cursor = true
                draw_rect(backing, {100, 170, 220, 210 })
            }
            if c == '\n' {
                pos.x = 0
                pos.y += 1
                continue
            }

            color := rl.Color{ 200, 200, 200, 255 }
            if hi == i do color = rl.WHITE
            rl.DrawTextCodepoint(font, c, backing.xy, FONT_SIZE, color)
            pos.x += 1
        }
        if !drawn_cursor {
            backing.xy = linalg.array_cast(pos, f32) * backing.zw
            draw_rect(backing, {100, 170, 220, 210 })
        }


        fullscreen := rect_screen()

        // view procedures

        for it := hm.iterator_make(&program.entities); e, _ in hm.iterate(&it){
            if .Procedure not_in e.features do continue

            proc_rect := rect_cut_top(&fullscreen, 50, 10)
            draw_rect(proc_rect, rl.RAYWHITE)

            text := string_from_label(&program.labels[e.label])
            draw_text_v(text, proc_rect.xy, rl.BLACK)
        }


        if rl.IsKeyPressed(.A) && rl.IsKeyDown(.LEFT_SHIFT){
            index := hm.len(program.entities) % len(names)
            make_procedure(names[index])
        }

        rl.EndDrawing()
    }

}