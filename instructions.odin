package main

import "core:mem"
import sa "core:container/small_array"

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
}

XMM :: proc(n: int) -> RegisterCode {
  return RegisterCode(n)
}

Immediate :: sa.Small_Array(8, u8)

EncodeFlags :: enum {
  ForceREX,
  Mode64,
  CombineReg,
  UseReg,
  UseRM,
}

RM :: struct {
  mode:         RM_Mode,
  scale:        u8,
  index:        RegisterCode,
  base:         RegisterCode,
  displacement: Immediate
}

OP_Code :: sa.Small_Array(3, u8)
LegacyPrefix :: sa.Small_Array(4, u8)

EncodeInput :: struct {
  legacy_prefix: LegacyPrefix,
  flags: bit_set[EncodeFlags],
  op_code_extension: u8,
  op_code: OP_Code,
  reg: RegisterCode,
  rm: RM,
  immediate: Immediate
}

encode :: proc(input: EncodeInput) -> (res: EncodedInstruction) {
  input := input

  sa.append(&res, ..sa.slice(&input.legacy_prefix))

  REX, reg, index, base := REX_compute(input.reg, input.rm.index, input.rm.base, .Mode64 in input.flags)
  if REX != 0x40 || .ForceREX in input.flags { // rex not required
    sa.append(&res, REX)
  }
  sa.append(&res, ..sa.slice(&input.op_code))
  if .CombineReg in input.flags {
    res.data[res.len - 1] |= u8(base)
  }
  else if .UseRM in input.flags {

    mod_rm: ModRM
    mod_rm.mode = input.rm.mode

    mod_rm.reg = reg if .UseReg in input.flags else RegisterCode(input.op_code_extension)

    use_sib: bool

    switch mod_rm.mode {
    case .Memory:
      mod_rm.reg_or_mem = base
    case .Register:
      assert(input.rm.displacement.len == 0)
      mod_rm.reg_or_mem = base
    case .Disp_8:
      unimplemented("disp 8 not supported")
    case .Disp_32:
      assert(input.rm.displacement.len == 4)
      use_sib = true
      mod_rm.reg_or_mem = .RSP
    }

    sa.append(&res, u8(mod_rm))
    if use_sib {
      sib := SIB { scale = input.rm.scale, index = .RSP, base = base }
      sa.append(&res, u8(sib))
    }
    sa.append(&res, ..sa.slice(&input.rm.displacement))
  }

  sa.append(&res, ..sa.slice(&input.immediate))
  return
}

EncodedInstruction :: sa.Small_Array(15, u8)

RM_Mode :: enum u8 {
  Memory,
  Disp_8,
  Disp_32,
  Register,
}

ModRM :: bit_field u8 {
  reg_or_mem :  RegisterCode | 3,
  reg:          RegisterCode | 3,
  mode:         RM_Mode | 2,
}

SIB :: bit_field u8 {
  base:   RegisterCode | 3,
  index:  RegisterCode | 3,
  scale:  u8 | 2,
}

REX :: bit_field u8 {
  b: bool       | 1,
  x: bool       | 1,
  r: bool       | 1,
  mode_64: bool | 1,
  prefix: u8    | 4, // fixed at 0x4
}

REX_compute :: proc(register, index, base_or_rm: RegisterCode, mode_64 := true) -> (u8, RegisterCode, RegisterCode, RegisterCode) {
  register :=   register
  index :=      index
  base_or_rm := base_or_rm

  rex: REX
  rex.prefix = 0x4
  rex.mode_64 = mode_64

  if register >= .R8 {
    rex.r = true
    register -= .R8
  }
  if index >= .R8 {
    rex.x = true
    register -= .R8
  }
  if base_or_rm >= .R8 {
    rex.b = true
    base_or_rm -= .R8
  }
  return u8(rex), register, index, base_or_rm
}

make_op :: proc(values: ..u8) -> (code: OP_Code) {
  sa.append(&code, ..values)
  return
}
make_legacy :: proc(values: ..u8) -> (prefix: LegacyPrefix) {
  sa.append(&prefix, ..values)
  return
}

rm_reg :: proc(reg: RegisterCode) -> RM {
  return RM { mode = .Register, base = reg }
}

rm_RIP :: proc(RIP: i32) -> RM {
  return RM { mode = .Memory, base = .RBP, displacement = make_immediate(RIP) }
}

rm_disp32 :: proc(reg: RegisterCode, disp: i32) -> RM {
  return RM { mode = .Disp_32, base = reg, displacement = make_immediate(disp) }
}

make_immediate :: proc(v: $T) -> (imm: Immediate) {
  imm.len = size_of(T)
  assert(imm.len <= 8)
  (transmute(^T)&imm.data[0]) ^= v
  return
}

// push

push_r64 :: proc(reg: RegisterCode) -> EncodedInstruction {
  return encode({flags = { .CombineReg },
    op_code = make_op(0x50),
    rm = { base = reg },
  })
}

// mov

mov_rm64_r64 :: proc(rm: RM, reg: RegisterCode) -> EncodedInstruction {
  return encode({flags = { .Mode64,  .UseReg, .UseRM },
    op_code = make_op(0x89),
    reg = reg,
    rm = rm
  })
}

mov_r64_rm64 :: proc(reg: RegisterCode, rm: RM) -> EncodedInstruction {
  return encode({flags = { .Mode64,  .UseReg, .UseRM },
    op_code = make_op(0x8B),
    reg = reg,
    rm = rm
  })
}

mov_rm64_imm32 :: proc(rm: RM, imm: u32) -> EncodedInstruction {
  return encode({flags = { .Mode64,  .UseRM },
    op_code = make_op(0xC7),
    op_code_extension = 0x00,
    rm = rm,
    immediate = make_immediate(imm),
  })
}

mov_r64_imm64 :: proc(reg: RegisterCode, imm: u64) -> EncodedInstruction {
  return encode({flags = {.Mode64, .CombineReg },
    op_code = make_op(0xB8),
    rm = RM { base = reg },
    immediate = make_immediate(imm)
  })
}



mov :: proc {
  mov_rm64_r64,
  mov_r64_rm64,
  mov_rm64_imm32,
  mov_r64_imm64,
}

// lea

lea_r64_m :: proc(reg: RegisterCode, offset: i32) -> EncodedInstruction {
  return encode({flags = {.Mode64, .UseReg, .UseRM },
    op_code = make_op(0x8D),
    reg = reg,
    rm = rm_RIP(offset)
  })
}

// add

add_rm64_imm32 :: proc(rm: RM, imm: u32) -> EncodedInstruction {
  return encode({flags = {.Mode64, .UseRM },
    op_code = make_op(0x81),
    op_code_extension = 0x00,
    rm = rm,
    immediate = make_immediate(imm)
  })
}

add_r64_rm64 :: proc(reg: RegisterCode, rm: RM) -> EncodedInstruction {
  return encode({flags = {.Mode64,  .UseReg, .UseRM },
    op_code = make_op(0x03),
    reg = reg,
    rm = rm
  })
}

// sub

sub_rm64_imm32 :: proc(rm: RM, imm: u32) -> EncodedInstruction {
  return encode({flags = {.Mode64, .UseRM},
    op_code = make_op(0x81),
    op_code_extension = 0x05,
    rm = rm,
    immediate = make_immediate(imm)
  })
}

// mul

imul_r64_rm64 :: proc(reg: RegisterCode, rm: RM) -> EncodedInstruction {
  return encode({flags = {.Mode64, .UseReg, .UseRM},
    op_code = make_op(0x0F, 0xAF),
    reg = reg,
    rm = rm,
  })
}

// div

idiv_rm64 :: proc(rm: RM) -> EncodedInstruction {
  return encode({flags = {.Mode64, .UseRM },
    op_code = make_op(0xF7),
    op_code_extension = 0x07,
    rm = rm,
  })
}

// movq

movq_xmm_rm64 :: proc(reg: RegisterCode, rm: RM) -> EncodedInstruction {
  return encode({flags = {.Mode64, .UseReg, .UseRM },
    legacy_prefix = make_legacy(0x66),
    op_code = make_op(0x0F, 0x6E),
    reg = reg,
    rm = rm
  })
}

// movsd

// b can either be xmm or a m64
movsd_load :: proc(a: RegisterCode, b: RM) -> EncodedInstruction {
  return encode({flags = {.UseReg, .UseRM },
    op_code = make_op(0xF2, 0x0F, 0x10),
    reg = a,
    rm = b
  })
}

movsd_store :: proc(a: RM, b: RegisterCode) -> EncodedInstruction {
  return encode({flags = {.UseReg, .UseRM},
    op_code = make_op(0xF2, 0x0F, 0x11),
    rm = a,
    reg = b,
  })
}

subsd :: proc(a: RegisterCode, b: RM) -> EncodedInstruction {
  return encode({flags = {.UseReg, .UseRM},
    op_code = make_op(0xF2, 0x0F, 0x5C),
    reg = a,
    rm = b
  })
}

// call

call_rm64 :: proc(rm: RM) -> EncodedInstruction {
  return encode({flags = {.UseRM},
    op_code = make_op(0xFF),
    op_code_extension = 0x02,
    rm = rm
  })
}

// jump

jmp_rel32 :: proc(offset: i32) -> EncodedInstruction {
  return encode({
    op_code = make_op(0xE9),
    immediate = make_immediate(offset)
  })
}

jnz_rel32 :: proc(offset: i32) -> EncodedInstruction {
  return encode({
    op_code = make_op(0x0F, 0x85),
    immediate = make_immediate(offset),
  })
}

// cmp

cmp_r64_rm64 :: proc(reg: RegisterCode, rm: RM) -> EncodedInstruction {
  return encode({flags = { .Mode64, .UseReg, .UseRM },
    op_code = make_op(0x3B),
    reg = reg,
    rm = rm
  })
}

cmp_rax_imm32 :: proc(imm: u32) -> EncodedInstruction {
  return encode({flags = { .Mode64 },
    op_code = make_op(0x3D),
    immediate = make_immediate(imm)
  })
}