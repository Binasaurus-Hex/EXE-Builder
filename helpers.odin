package main

import "core:mem"
import "core:fmt"

// asm

print_register :: proc(a: ^Assembler, format: cstring, r: RegisterCode){

  lea_string(a, .RCX, format)

  w(a, mov_r64_rm64(.RDX, rm_reg(r)))

  call_import(a, "printf")
}

print :: proc(a: ^Assembler, format: cstring){
  print_register(a, format, .NONE)
}

make_var :: proc(offset: ^i32, size: i32) -> i32 {
  start := offset^
  offset^ += size
  return start
}
set_int :: proc(a: ^Assembler, var: i32, value: i64){
  w(a, mov_r64_imm64(.RAX, transmute(u64)value))
  w(a, mov_rm64_r64(rm_disp32(.RBP, var), .RAX))
}
set_f64 :: proc(a: ^Assembler, var: i32, value: f64){
  set_int(a, var, transmute(i64)value)
}

print_int :: proc(a: ^Assembler, var: i32, name: cstring) {
  w(a, mov_r64_imm64(.RAX, 0))
  w(a, mov_r64_rm64(.RAX, rm_disp32(.RBP, var)))
  format := fmt.ctprint(name, " = %d\n")
  print_register(a, format, .RAX)
}
print_float :: proc(a: ^Assembler, var: i32, name: cstring) {
  w(a, mov_r64_imm64(.RAX, 0))
  w(a, mov_r64_rm64(.RAX, rm_disp32(.RBP, var)))
  format := fmt.ctprint(name, " = %f \n")
  print_register(a, format, .RAX)
}

set_jump :: proc(a: ^Assembler, start: int){
  end := buffer_len(a.output_buffer)
  displacement: i32 = i32(end) - i32(start)
  ptr := cast(^i32)buffer_ptr(a.output_buffer, start - size_of(i32))
  ptr^ = displacement
}

lea_string :: proc(a: ^Assembler, reg: RegisterCode, s: cstring){
  w(a, lea_r64_m(reg, 0))
  call_string(a, s)
}

call_string :: proc(a: ^Assembler, s: cstring){
  append(&a.data_strings, ImportCall { s, buffer_len(a.output_buffer) })
}

call_import_raw :: proc(a: ^Assembler, s: cstring){
  append(&a.import_calls, ImportCall { s, buffer_len(a.output_buffer) })
}

call_import :: proc(a: ^Assembler, s: cstring){
  w(a, call_rm64(rm_RIP(0)))
  call_import_raw(a, s)
}

// buffer


buffer_resize :: proc(b: ^OutputBuffer, size: int) {
  b.index = size
}

buffer_ptr :: proc(b: ^OutputBuffer, index: int) -> ^u8 {
  return &b.buffer[index]
}

buffer_len :: proc(b: ^OutputBuffer) -> int {
  return b.index
}

buffer_slice :: proc(b: ^OutputBuffer) -> []u8 {
  return b.buffer[:b.index]
}

buffer_append :: proc(b: ^OutputBuffer, t: $T){
  ptr := allocate(b, T)
  ptr^ = t
}

allocate :: proc(b: ^OutputBuffer, $T: typeid) -> ^T {
  size := size_of(T)
  ptr := &b.buffer[b.index]
  b.index += size
  return cast(^T)ptr
}

write_cstring :: proc(location: ^u8, s: cstring){
    mem.copy(location, cast(^u8)s, len(s) + 1)
}

write_string :: proc(location: ^u8, s: cstring){
  mem.copy(location, cast(^u8)s, len(s) + 1)
}

w :: proc(a: ^Assembler, instruction: EncodedInstruction){
  for i in 0..<instruction.len {
    alloc_u8(a.output_buffer, instruction.data[i])
  }
}

alloc_u8 :: proc(b: ^OutputBuffer, value: u8) -> ^u8 {
  ptr := allocate(b, u8)
  ptr^ = value
  return ptr
}

alloc_string :: proc(b: ^OutputBuffer, value: cstring) -> ^cstring {
  write_string(&b.buffer[b.index], value)
  ptr := cast(^cstring)&b.buffer[b.index]
  b.index += len(value) + 1
  return ptr
}