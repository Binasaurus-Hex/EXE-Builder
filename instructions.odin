package main

import "core:mem"

RegisterCode :: enum u8 {
  RAX,
  RCX,
  RDX,
  RBX,
  RSP,
  RBP,
  RSI,
  RDI,

  // extended registers
  R8,
  R9,
  R10,
  R11,
  R12,
  R13,
  R14,
  R15,
  NONE,
}

RM_Prefix :: enum u8 {
  Memory =              0 << 6,
  Memory_Displace_8 =   1 << 6,
  Memory_Displace_32 =  2 << 6,
  Register =            3 << 6,
}

push :: proc(register: RegisterCode) -> u8 {
  assert(register < RegisterCode.R8)
  return 0x50 | cast(u8)register
}

push_extended :: proc(register: RegisterCode) -> [2]u8 {
  assert(register >= RegisterCode.R8)
  return {0x41, 0x50 | cast(u8)register}
}

pop :: proc(register: RegisterCode) -> u8 {
  assert(register < RegisterCode.R8)
  return 0x58 | cast(u8)register
}

pop_extended :: proc(register: RegisterCode) -> [2]u8 {
  assert(register >= RegisterCode.R8)
  return {0x41, 0x58 | cast(u8)register }
}

ret :: proc() -> u8 {
  return 0xC3
}

mod_rm :: proc(prefix: RM_Prefix, reg, regm: u8) -> u8 {

  //         11       000        000
  return u8(prefix) | reg << 3 | regm
}

REX_compute :: proc(register_a: RegisterCode, register_b: RegisterCode, mode_64 := true) -> (u8, RegisterCode, RegisterCode) {
  REX :u8 = 0x40
  if mode_64 do REX |= 0x08

  register_a := register_a
  register_b := register_b
  if register_a >= .R8 && register_a != .NONE{
    REX |= 0x1
    register_a -= .R8
  }
  if register_b >= .R8 && register_b != .NONE {
    REX |= 0x4
    register_b -= .R8
  }
  return REX, register_a, register_b
}

jz_32 :: proc(offset: i32) -> [6]u8 {
  output := [6]u8 { 0x0F, 0x84, 0, 0, 0, 0 }
  imm := transmute(^i32)&output[2]
  imm^ = offset
  return output
}

jnz_32 :: proc(offset: i32) -> [6]u8 {
  output := [6]u8 { 0x0F, 0x85, 0, 0, 0, 0 }
  imm := transmute(^i32)&output[2]
  imm^ = offset
  return output
}

jump_relative_32 :: proc(offset: i32) -> [5]u8 {
  output := [5]u8 { 0xE9, 0, 0, 0, 0 }
  imm := transmute(^i32)&output[1]
  imm^ = offset
  return output
}

call_relative_32 :: proc(relative_offset: u32) -> [6]u8 {
  OP_CODE: u8 = 0xFF
  output: [6]u8 = {OP_CODE, 0x15, 0, 0, 0, 0}
  imm := transmute(^u32)&output[2]
  imm^ = relative_offset
  return output
}

setnz_8 :: proc(reg: RegisterCode) -> [3]u8 {
  return { 0x0F, 0x95, mod_rm(.Register, 0, u8(reg)) }
}

setz_8 :: proc(reg: RegisterCode) -> [4]u8 {
  REX, reg, _ := REX_compute(reg, .NONE)
  return { REX, 0x0F, 0x94, mod_rm(.Register, 0, u8(reg)) }
}

cmp_r64 :: proc(reg_a, reg_b: RegisterCode) -> [3]u8 {
  REX, reg_a, reg_b := REX_compute(reg_a, reg_b)
  OP_CODE :u8 : 0x3B
  return { REX, OP_CODE, mod_rm(.Register, u8(reg_b), u8(reg_a))}
}

movq :: proc(register_a: RegisterCode, register_b: RegisterCode) -> [3]u8 {
  REX, register_a, register_b := REX_compute(register_a, register_b)
  OP_CODE: u8 : 0x89
  return {REX, OP_CODE, mod_rm(.Register, u8(register_b), u8(register_a))}
}

movq_imm64 :: proc(register_a: RegisterCode, value: i64) -> [10]u8 {
  REX, register_a, _ := REX_compute(register_a, RegisterCode.NONE)
  OP_CODE : u8 : 0xB8
  output := [10]u8 { REX, OP_CODE | u8(register_a), 0, 0, 0, 0, 0, 0, 0, 0 }
  imm := transmute(^i64)&output[2]
  imm^ = value
  return output
}

movq_imm32 :: proc(register_a: RegisterCode, immediate_value: i32) -> [7]u8 {
  REX, register_a, _:= REX_compute(register_a, RegisterCode.NONE)
  OP_CODE : u8 : 0xC7
  output: [7]u8 = {REX, OP_CODE, mod_rm(.Register, 0, u8(register_a)), 0, 0, 0, 0}
  imm := transmute(^i32)&output[3]
  imm^ = immediate_value
  return output
}

addq :: proc(reg_a: RegisterCode, reg_b: RegisterCode) -> [3]u8 {
  REX, reg_a, reg_b := REX_compute(reg_a, reg_b)
  OP_CODE : u8 : 0x01
  return {REX, OP_CODE, mod_rm(.Register, u8(reg_b), u8(reg_a)) }
}

sub_imm8 :: proc(register: RegisterCode, value: u8) -> [4]u8 {
  REX, register, _ := REX_compute(register, RegisterCode.NONE)
  return {REX, 0x83, 0xEC, value}
}

imul64 :: proc(reg_a: RegisterCode, reg_b :RegisterCode) -> [4]u8 {
  REX, reg_a, reg_b := REX_compute(reg_a, reg_b)
  OP_CODE: u8 = 0x0F
  return {REX, OP_CODE, 0xAF, mod_rm(.Register, u8(reg_a), u8(reg_b)) }
}

xor64 :: proc(reg_a: RegisterCode, reg_b: RegisterCode) -> [3]u8 {
  REX, reg_a, reg_b := REX_compute(reg_a, reg_b)
  OP_CODE: u8 = 0x31
  return {REX, OP_CODE, mod_rm(.Register, u8(reg_a), u8(reg_b)) }
}

idiv :: proc(register_a: RegisterCode) -> [3]u8{
  REX, reg_a, _ := REX_compute(register_a, .NONE)
  OP_CODE: u8 = 0xF7
  return { REX, OP_CODE, mod_rm(.Register, 0, u8(reg_a)) }
}

lea :: proc(register: RegisterCode, address: u32) -> [7]u8 {
  REX, _, register := REX_compute(RegisterCode.NONE, register)
  result :[7]u8 = {REX, 0x8D, (0x00 | (cast(u8)register << 3)) | 0x05, 0, 0, 0, 0}
  imm := transmute(^u32)&result[3]
  imm^ = address
  return result
}