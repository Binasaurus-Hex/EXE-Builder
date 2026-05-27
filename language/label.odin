package main

Label :: struct($S: int){
    data: [S]u8,
    len: int,
}

string_from_label :: proc(l: ^Label($S)) -> string {
    return string(l.data[:l.len])
}

label_set :: proc(l: ^Label($S), s: string) {
    assert(len(s) <= len(l.data))
    copy(l.data[:len(s)], s[:])
    l.len = len(s)
}

label_append :: proc(l: ^Label($S), s: string){
    space := len(l.data) - l.len
    assert(space >= len(s))
    copy(l.data[l.len:l.len + len(s)], s[:])
}

