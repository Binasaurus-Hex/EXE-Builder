package main

import "core:fmt"
import "core:sys/windows"
import "core:mem"
import os "core:os/os2"
import "core:strings"
import "core:io"
import "core:encoding/hex"

IMAGE_DOS_HEADER :: struct {
  e_magic : [2]u8,

  e_cblp: u16,
  e_cp: u16,
  e_crlc: u16,
  e_cparhdr: u16,
  e_minalloc: u16,
  e_maxalloc: u16,
  e_ss: u16,
  e_sp: u16,
  e_csum: u16,
  e_ip: u16,
  e_cs: u16,
  e_lfarlc: u16,
  e_ovno: u16,

  e_res: [4]u16,
  e_oemid, e_oeminfo: u16,
  e_res2: [10]u16,
  e_lfanew: i32,
}

IMAGE_FILE_HEADER :: struct {
  Machine: u16,
  NumberOfSections: u16,
  TimeDateStamp: u32,
  PointerToSymbolTable: u32,
  NumberOfSymbols: u32,
  SizeOfOptionalHeader: u16,
  Characteristics: u16
}

IMAGE_DATA_DIRECTORY :: struct {
  VirtualAddress: u32,
  Size: u32
}

IMAGE_NUMBEROF_DIRECTORY_ENTRIES :: 16

IMAGE_OPTIONAL_HEADER64 :: struct {
  Magic: u16,
  MajorLinkerVersion: u8,
  MinorLinkerVersion: u8,
  SizeOfCode: u32,
  SizeOfInitializedData: u32,
  SizeOfUninitializedData: u32,
  AddressOfEntryPoint: u32,
  BaseOfCode: u32,
  ImageBase: u64,
  SectionAlignment: u32,
  FileAlignment: u32,
  MajorOperatingSystemVersion: u16,
  MinorOperatingSystemVersion: u16,
  MajorImageVersion: u16,
  MinorImageVersion: u16,
  MajorSubsystemVersion: u16,
  MinorSubsystemVersion: u16,
  Win32VersionValue: u32,
  SizeOfImage: u32,
  SizeOfHeaders: u32,
  CheckSum: u32,
  Subsystem: u16,
  DllCharacteristics: u16,
  SizeOfStackReserve: u64,
  SizeOfStackCommit: u64,
  SizeOfHeapReserve: u64,
  SizeOfHeapCommit: u64,
  LoaderFlags: u32,
  NumberOfRvaAndSizes: u32,
  DataDirectory: [IMAGE_NUMBEROF_DIRECTORY_ENTRIES]IMAGE_DATA_DIRECTORY,
}

IMAGE_OPTIONAL_HEADER :: struct {
  //
  // Standard fields.
  //

  Magic: windows.WORD,
  MajorLinkerVersion: windows.BYTE,
  MinorLinkerVersion: windows.BYTE,
  SizeOfCode: windows.DWORD,
  SizeOfInitializedData: windows.DWORD,
  SizeOfUninitializedData: windows.DWORD,
  AddressOfEntryPoint: windows.DWORD,
  BaseOfCode: windows.DWORD,
  BaseOfData: windows.DWORD,

  //
  // NT additional fields.
  //

  ImageBase: windows.DWORD,
  SectionAlignment: windows.DWORD,
  FileAlignment: windows.DWORD,
  MajorOperatingSystemVersion: windows.WORD ,
  MinorOperatingSystemVersion: windows.WORD ,
  MajorImageVersion: windows.WORD ,
  MinorImageVersion: windows.WORD ,
  MajorSubsystemVersion: windows.WORD ,
  MinorSubsystemVersion: windows.WORD ,
  Win32VersionValue: windows.DWORD,
  SizeOfImage: windows.DWORD,
  SizeOfHeaders: windows.DWORD,
  CheckSum: windows.DWORD,
  Subsystem: windows.WORD ,
  DllCharacteristics: windows.WORD ,
  SizeOfStackReserve: windows.DWORD,
  SizeOfStackCommit: windows.DWORD,
  SizeOfHeapReserve: windows.DWORD,
  SizeOfHeapCommit: windows.DWORD,
  LoaderFlags: windows.DWORD,
  NumberOfRvaAndSizes: windows.DWORD,
  DataDirectory: [IMAGE_NUMBEROF_DIRECTORY_ENTRIES]IMAGE_DATA_DIRECTORY,
}

SUBSYSTEM :: enum windows.WORD {
  UNKNOWN = 0,
  NATIVE = 1,
  GUI = 2,
  CONSOLE = 3,
  OS2_CONSOLE = 5,
  POSIX_CONSOLE = 7,
  NATIVE_WINDOWS = 8,
  CE_GUI = 9,
  EFI_APPLICATION = 10,
  EFI_BOOT_SERVICE_DRIVER = 11,
  EFI_RUNTIME_DRIVER = 12,
  EFI_ROM = 13,
  XBOX = 14,
  WINDOWS_BOOT_APPLICATION = 16
}

NT_CHARACTERISTICS :: enum u16 {
  RELOCS_STRIPPED,
  EXECUTABLE_IMAGE,
  LINE_NUMS_STRIPPED,
  LOCAL_SYMS_STRIPPED,
  AGGRESSIVE_WS_TRIM,
  LARGE_ADDRESS_AWARE,
  BYTES_REVERSED_LO,
  _32BIT_MACHINE,
  DEBUG_STRIPPED,
  REMOVABLE_RUN_FROM_SWAP,
  NET_RUN_FROM_SWAP,
  SYSTEM,
  DLL,
  UP_SYSTEM_ONLY,
  BYTES_REVERSED_HI
}

IMAGE_NT_HEADERS64 :: struct {
  Signature: [2]u8,
  FileHeader: IMAGE_FILE_HEADER,
  OptionalHeader: IMAGE_OPTIONAL_HEADER64
}

IMAGE_NT_HEADERS :: struct {
  Signature: [2]u8,
  FileHeader: IMAGE_FILE_HEADER,
  OptionalHeader: IMAGE_OPTIONAL_HEADER,
}

IMAGE_SECTION_HEADER :: struct {
  Name: [8]u8,
  VirtualSize: u32,
  VirtualAddress: u32,
  SizeOfRawData: u32,
  PointerToRawData: u32,
  PointerToRelocations: u32,
  PointerToLineNumbers: u32,
  NumberOfRelocations: u16,
  NumberOfLineNumbers: u16,
  Characteristics: u32
}

IMAGE_IMPORT_DESCRIPTOR :: struct {
  OriginalFirstThunk: u32,
  TimeDateStamp: u32,
  ForwarderChain: u32,
  Name: u32,
  FirstThunk: u32
}

BUFFER_SIZE :: 100000
OutputBuffer :: struct {
  buffer: [BUFFER_SIZE]u8,
  index: int
}

allocate :: proc(b: ^OutputBuffer, $T: typeid) -> ^T {
  size := size_of(T)
  ptr := &b.buffer[b.index]
  b.index += size
  return cast(^T)ptr
}

write_string :: proc(location: ^u8, s: cstring){
  mem.copy(location, cast(^u8)s, len(s) + 1)
}

write :: proc(a: ^Assembler, arr: [$S]u8){
  ptr := allocate(a.output_buffer, type_of(arr))
  for i in 0..<len(arr){
    ptr[i] = arr[i]
  }
}

alloc_u8_array :: proc(b: ^OutputBuffer, array: [$Size]u8) -> ^[Size]u8 {
  ptr := allocate(b, type_of(array))
  for i in 0..<len(array) {
    ptr[i] = array[i]
  }
  return ptr
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

SectionFlag :: enum u32 {
  TYPE_NO_PAD =         3,
  CODE =                5,
  INITIALIZED_DATA =    6,
  UNINITIALIZED_DATA =  7,
  INFO =                9,
  REMOVE =              11,
  COMDAT =              12,
  GPREL =               15,
  NRELOC_OVFL =         24,
  MEM_DISCARDABLE =     25,
  MEM_NOT_CACHED =      26,
  MEM_NOT_PAGED =       27,
  MEM_SHARED =          28,
  MEM_EXECUTE =         29,
  MEM_READ =            30,
  MEM_WRITE =           31,
}

set_jump :: proc(a: ^Assembler, start: int){
  end := a.output_buffer.index
  displacement: i32 = i32(end) - i32(start)
  ptr := transmute(^i32)&a.output_buffer.buffer[start - size_of(i32)]
  ptr^ = displacement
}

call_string :: proc(a: ^Assembler, s: cstring){
  append(&a.data_strings, ImportCall { s, a.output_buffer.index })
}

call_import :: proc(a: ^Assembler, s: cstring){
  append(&a.import_calls, ImportCall { s, a.output_buffer.index })
}

ImportFunctionEntry :: struct {
  name: cstring,
  name_RVA: u64,
  rva: u32
}

ImportEntry :: struct {
  dll_name: cstring,
  functions: []ImportFunctionEntry,

  // filled in later
  descriptor_RVA: u32,
  descriptor: ^IMAGE_IMPORT_DESCRIPTOR
}

ImportCall :: struct {
  function_name: cstring,
  buffer_index: int
}


Assembler :: struct {
  output_buffer:    ^OutputBuffer,
  dos_header:       ^IMAGE_DOS_HEADER,
  nt_header:        ^IMAGE_NT_HEADERS64,
  text_section:     ^IMAGE_SECTION_HEADER,
  data_section:     ^IMAGE_SECTION_HEADER,
  import_section:   ^IMAGE_SECTION_HEADER,
  import_entries:   []ImportEntry,
  data_strings:     [dynamic]ImportCall,
  import_calls:     [dynamic]ImportCall,
}

begin :: proc(a: ^Assembler){
  a.output_buffer = new(OutputBuffer)

  output_buffer := a.output_buffer

  a.dos_header = allocate(output_buffer, IMAGE_DOS_HEADER)
  a.dos_header.e_magic = "MZ"
  a.dos_header.e_lfanew = size_of(IMAGE_DOS_HEADER)

  SECTION_COUNT :: 3

  characteristics := bit_set[NT_CHARACTERISTICS; u16] {
    .EXECUTABLE_IMAGE,
    .RELOCS_STRIPPED,
    .LOCAL_SYMS_STRIPPED,
    .DEBUG_STRIPPED,
    .LINE_NUMS_STRIPPED,
    .LARGE_ADDRESS_AWARE,
  }

  a.nt_header = allocate(output_buffer, IMAGE_NT_HEADERS64)
  a.nt_header.Signature = "PE"
  a.nt_header.FileHeader = {
    Machine = 0x8664,
    NumberOfSections = SECTION_COUNT,
    SizeOfOptionalHeader = size_of(IMAGE_OPTIONAL_HEADER64),
    Characteristics = transmute(u16)characteristics,
  }

  SECTION_ALIGNMENT :: 4096
  FILE_ALIGNMENT :: 512

  a.nt_header.OptionalHeader = {
    Magic = 0x20B,
    AddressOfEntryPoint = SECTION_ALIGNMENT,
    ImageBase = 0x400000,
    SectionAlignment = SECTION_ALIGNMENT,
    FileAlignment = FILE_ALIGNMENT,
    MajorSubsystemVersion = 4,
    SizeOfImage = SECTION_ALIGNMENT * (SECTION_COUNT + 1),
    SizeOfHeaders = FILE_ALIGNMENT,
    Subsystem = windows.WORD(SUBSYSTEM.CONSOLE),
    SizeOfStackReserve = 0x1000,
    SizeOfStackCommit = 0x1000,
    SizeOfHeapReserve = 0x10000,
    NumberOfRvaAndSizes = IMAGE_NUMBEROF_DIRECTORY_ENTRIES
  }

  a.text_section = allocate(output_buffer, IMAGE_SECTION_HEADER)
  a.text_section.VirtualAddress = SECTION_ALIGNMENT
  a.text_section.SizeOfRawData = FILE_ALIGNMENT
  a.text_section.PointerToRawData = FILE_ALIGNMENT
  a.text_section.Characteristics = transmute(u32)bit_set[SectionFlag;u32]{
    .CODE,
    .MEM_READ,
    .MEM_EXECUTE,
  }
  write_string(&a.text_section.Name[0], ".text")

  a.data_section = allocate(output_buffer, IMAGE_SECTION_HEADER)
  a.data_section.VirtualAddress = SECTION_ALIGNMENT * 2
  a.data_section.SizeOfRawData = FILE_ALIGNMENT
  a.data_section.PointerToRawData = FILE_ALIGNMENT * 2
  a.data_section.Characteristics = transmute(u32)bit_set[SectionFlag;u32]{
    .MEM_READ,
    .MEM_WRITE,
    .INITIALIZED_DATA
  }
  write_string(&a.data_section.Name[0], ".data")


  a.import_section = allocate(output_buffer, IMAGE_SECTION_HEADER)
  a.import_section.VirtualAddress = SECTION_ALIGNMENT * 3
  a.import_section.PointerToRawData = FILE_ALIGNMENT * 3
  a.import_section.SizeOfRawData = FILE_ALIGNMENT
  a.import_section.Characteristics = transmute(u32)bit_set[SectionFlag;u32]{
    .MEM_READ,
    .MEM_WRITE,
    .INITIALIZED_DATA
  }
  write_string(&a.import_section.Name[0], ".idata")

  output_buffer.index = int(a.text_section.PointerToRawData)
}

end :: proc(a: ^Assembler){
  output_buffer := a.output_buffer
  a.text_section.VirtualSize = cast(u32)output_buffer.index - a.text_section.PointerToRawData

  output_buffer.index = cast(int)a.data_section.PointerToRawData
  // data section
  for data_string in a.data_strings {
    string_RVA := cast(u32)output_buffer.index - a.data_section.PointerToRawData + a.data_section.VirtualAddress
    call_RVA := cast(u32)data_string.buffer_index - a.text_section.PointerToRawData + a.text_section.VirtualAddress
    offset :u32 = string_RVA - call_RVA
    mem.copy(&output_buffer.buffer[data_string.buffer_index - size_of(u32)], &offset, size_of(u32))
    alloc_string(output_buffer, data_string.function_name)
  }
  a.data_section.VirtualSize = cast(u32)output_buffer.index - a.data_section.PointerToRawData

  output_buffer.index = cast(int)a.import_section.PointerToRawData

  IMPORT_RVA := a.import_section.VirtualAddress - cast(u32)output_buffer.index

  // Descriptors
  for &import_entry in a.import_entries {
    import_entry.descriptor_RVA = cast(u32)output_buffer.index + IMPORT_RVA
    import_entry.descriptor = allocate(output_buffer, IMAGE_IMPORT_DESCRIPTOR)
  }
  termination_entry := allocate(output_buffer, IMAGE_IMPORT_DESCRIPTOR)

  // Library name strings
  for &import_entry in a.import_entries {
    import_entry.descriptor.Name = cast(u32)output_buffer.index + IMPORT_RVA
    alloc_string(output_buffer, import_entry.dll_name)
  }

  // function name strings / 'Hints'
  for &import_entry in a.import_entries {
    for &function_call in import_entry.functions {
      function_call.name_RVA = u64(cast(u32)output_buffer.index + IMPORT_RVA)
      output_buffer.index += 2 // hint
      alloc_string(output_buffer, function_call.name)
    }
  }

  // import table
  for &import_entry in a.import_entries {
    import_entry.descriptor.FirstThunk = cast(u32)output_buffer.index + IMPORT_RVA
    for &function_call in import_entry.functions {
      function_call.rva = cast(u32)output_buffer.index + IMPORT_RVA
      for import_call in a.import_calls {
        if import_call.function_name != function_call.name {
          continue
        }

        virtual_address := (cast(u32)import_call.buffer_index - a.text_section.PointerToRawData) + a.text_section.VirtualAddress
        offset :u32 = function_call.rva - virtual_address
        mem.copy(&(output_buffer.buffer[import_call.buffer_index - size_of(u32)]), &offset, size_of(u32))
      }
      rva_entry := allocate(output_buffer, u64)
      rva_entry^ = function_call.name_RVA
    }
    output_buffer.index += size_of(u64) // termination entry
  }

  a.import_section.VirtualSize = cast(u32)output_buffer.index - a.import_section.PointerToRawData

  a.nt_header.OptionalHeader.DataDirectory[1] = {
    VirtualAddress = a.import_section.VirtualAddress,
    Size = a.import_section.VirtualSize
  }

  // set the buffer to past the import section
  output_buffer.index = int(a.import_section.PointerToRawData + a.import_section.SizeOfRawData)
}

build :: proc(a: ^Assembler, filename: string){
  file, err := os.open(filename , os.O_CREATE)
  os.write(file, a.output_buffer.buffer[: a.output_buffer.index])
  os.close(file)
}


main :: proc(){

  a: Assembler

  a.import_entries = {
    {
      dll_name = "KERNEL32.DLL",
      functions = {
        {name = "ExitProcess"},
      }
    },
    {
      dll_name = "USER32.DLL",
      functions = {
        {name = "MessageBoxA"}
      }
    },
    {
      dll_name = "MSVCRT.DLL",
      functions = {
        {name = "printf"},
      }
    }
  }

  begin(&a)

    output_buffer := a.output_buffer

    write(&a, sub_imm8(.RSP, 8 * 5))

    write(&a, movq_imm32(.R9, 0))
    write(&a, lea(.R8, 0))
    call_string(&a, "whoa cool title m80")

    write(&a, lea(.RDX, 0))
    call_string(&a, "the thing has changed or has it?")

    write(&a, movq_imm32(.RCX, 0))

    write(&a, call_relative_32(0))
    call_import(&a, "MessageBoxA")

    write(&a, movq_imm64(.R9, transmute(i64)f64(1.23)))
    print_register(&a, "printing this %lf\n", .R9)

    write(&a, movq(.RCX, .RAX))


    write(&a, movq_imm64(.RCX, 0))

    write(&a, movq_imm64(.RAX, 2))
    write(&a, movq_imm64(.RBX, 3))

    write(&a, imul64(.RAX, .RBX))


    write(&a, movq_imm64(.RBX, 6))

    // if rax == rbx {
    write(&a, cmp_r64(.RAX, .RBX))
    write(&a, jnz_32(0))
    else_block := a.output_buffer.index

    print(&a, "IF   BLOCK \n")

    write(&a, jump_relative_32(0))
    else_block_end := a.output_buffer.index

    // }
    // else {
    set_jump(&a, else_block)
    print(&a, "ELSE BLOCK \n")
    // }
    set_jump(&a, else_block_end)

    write(&a, movq_imm32(.RCX, 0))
    write(&a, call_relative_32(0))
    call_import(&a, "ExitProcess")

  end(&a)

  build(&a, "test.exe")

  state, std_out, std_err, err := os.process_exec({command = {"test.exe"}}, context.allocator)
  fmt.println(string(std_out))

  os.exit(state.exit_code)
}

print_register :: proc(a: ^Assembler, format: cstring, r: RegisterCode){
  write(a, lea(.RCX, 0))
  call_string(a, format)
  write(a, movq(.RDX, r))
  write(a, call_relative_32(0))
  call_import(a, "printf")
}

print :: proc(a: ^Assembler, format: cstring){
  print_register(a, format, .NONE)
}