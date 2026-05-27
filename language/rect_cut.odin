package main

Rect :: [4]f32

rect_pad :: proc(rect: Rect, padding: [2]f32) -> Rect {
    rect := rect
    rect.xy += padding
    rect.zw -= padding * 2
    return rect
}

rect_cut_top :: proc(rect: ^Rect, x:f32, spacing: f32) -> Rect {
    eaten, remainder := rect_split_top(rect^, x, spacing)
    rect ^= remainder
    return eaten
}

rect_cut_left :: proc(rect: ^Rect, x: f32, spacing: f32) -> Rect {
    eaten, remainder := rect_split_left(rect^, x, spacing)
    rect ^= remainder
    return eaten
}

rect_split_left :: proc(rect: Rect, x: f32, spacing: f32) -> (eaten: Rect, remainder: Rect){
    eaten = {rect.x, rect.y, x, rect.w }
    remainder = rect
    remainder.x += x + spacing
    remainder.z -= x + spacing
    return
}

rect_split_top :: proc(rect: Rect, y: f32, spacing: f32) -> (eaten: Rect, remainder: Rect){
    eaten = {rect.x, rect.y, rect.z, y }
    remainder = rect
    remainder.y += y + spacing
    remainder.w -= y + spacing
    return
}

rect_split_bottom :: proc(rect: Rect, y: f32, spacing: f32) -> (eaten: Rect, remainder: Rect){
    remainder = rect
    remainder.w -= (y + spacing)
    eaten = { rect.x, rect.y + rect.w - y, rect.z, y }
    return
}

rect_cut_bottom :: proc(rect: ^Rect, y: f32, spacing: f32) -> Rect {
    eaten, remainder := rect_split_bottom(rect^, y, spacing)
    rect ^= remainder
    return eaten
}

rect_split_right :: proc(rect: Rect, x: f32, spacing: f32) -> (eaten: Rect, remainder: Rect){
    remainder = rect
    remainder.z -= (x + spacing)
    eaten = { rect.x + rect.z - x, rect.y, x, rect.w }
    return
}

rect_cut_right :: proc(rect: ^Rect, x: f32, spacing: f32) -> Rect {
    eaten, remainder := rect_split_right(rect^, x, spacing)
    rect ^= remainder
    return eaten
}

rect_middle :: proc(rect: Rect) -> [2]f32 {
    return rect.xy + (rect.zw / 2.)
}

centre_rect :: proc(rect: Rect) -> Rect {
    rect := rect
    rect.xy = rect_middle(rect)
    rect.zw = { 0, 0 }
    return rect
}