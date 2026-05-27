package main

import "core:fmt"
import "core:sys/windows"
import "core:mem"
import sa "core:container/small_array"
import "core:os"
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

BUFFER_SIZE :: 1000000
OutputBuffer :: struct {
  buffer: [BUFFER_SIZE]u8,
  index: int
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

align :: proc(offset: $T, alignment: T) -> T {
  return ((offset / alignment) + 1) * alignment
}

SECTION_ALIGNMENT :: 4096
FILE_ALIGNMENT :: 512

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

  a.nt_header.OptionalHeader = {
    Magic = 0x20B,
    AddressOfEntryPoint = SECTION_ALIGNMENT,
    ImageBase = 0x400000,
    SectionAlignment = SECTION_ALIGNMENT,
    FileAlignment = FILE_ALIGNMENT,
    MajorSubsystemVersion = 4,
    SizeOfImage = SECTION_ALIGNMENT * (SECTION_COUNT + 1),
    SizeOfHeaders = 0,
    Subsystem = windows.WORD(SUBSYSTEM.CONSOLE),
    SizeOfStackReserve = 0x1000,
    SizeOfStackCommit = 0x1000,
    SizeOfHeapReserve = 0x10000,
    NumberOfRvaAndSizes = IMAGE_NUMBEROF_DIRECTORY_ENTRIES
  }

  a.text_section = allocate(output_buffer, IMAGE_SECTION_HEADER)
  a.text_section.Characteristics = transmute(u32)bit_set[SectionFlag;u32]{
    .CODE,
    .MEM_READ,
    .MEM_EXECUTE,
  }
  write_cstring(&a.text_section.Name[0], ".text")

  a.data_section = allocate(output_buffer, IMAGE_SECTION_HEADER)
  a.data_section.Characteristics = transmute(u32)bit_set[SectionFlag;u32]{
    .MEM_READ,
    .MEM_WRITE,
    .INITIALIZED_DATA
  }
  write_cstring(&a.data_section.Name[0], ".data")

  a.import_section = allocate(output_buffer, IMAGE_SECTION_HEADER)
  a.import_section.Characteristics = transmute(u32)bit_set[SectionFlag;u32]{
    .MEM_READ,
    .MEM_WRITE,
    .INITIALIZED_DATA
  }
  write_cstring(&a.import_section.Name[0], ".idata")

  buffer_resize(output_buffer, align(buffer_len(output_buffer), FILE_ALIGNMENT))
  a.nt_header.OptionalHeader.SizeOfHeaders = windows.DWORD(buffer_len(output_buffer))
  a.text_section.PointerToRawData = u32(buffer_len(output_buffer))
  a.text_section.VirtualAddress = SECTION_ALIGNMENT
}

end :: proc(a: ^Assembler){
  output_buffer := a.output_buffer
  a.text_section.VirtualSize = u32(buffer_len(output_buffer)) - a.text_section.PointerToRawData
  a.text_section.SizeOfRawData = align(a.text_section.VirtualSize, FILE_ALIGNMENT)


  // data section
  a.data_section.PointerToRawData = a.text_section.PointerToRawData + a.text_section.SizeOfRawData
  a.data_section.VirtualAddress = a.text_section.VirtualAddress + align(a.text_section.VirtualSize, SECTION_ALIGNMENT)

  allocated_strings := make(map[cstring]u32, context.temp_allocator)

  buffer_resize(output_buffer, int(a.data_section.PointerToRawData))
  // data section
  for data_string in a.data_strings {
    string_offset: u32
    if offset, found := allocated_strings[data_string.function_name]; found {
      string_offset = offset
    }
    else {
      string_offset = u32(buffer_len(output_buffer))
      alloc_string(output_buffer, data_string.function_name)
      allocated_strings[data_string.function_name] = string_offset
    }
    string_RVA := string_offset - a.data_section.PointerToRawData + a.data_section.VirtualAddress
    call_RVA := cast(u32)data_string.buffer_index - a.text_section.PointerToRawData + a.text_section.VirtualAddress
    offset :u32 = string_RVA - call_RVA
    ptr := transmute(^u32)&output_buffer.buffer[data_string.buffer_index - size_of(u32)]
    ptr^ = offset
  }
  a.data_section.VirtualSize = u32(buffer_len(output_buffer)) - a.data_section.PointerToRawData
  a.data_section.SizeOfRawData = align(a.data_section.VirtualSize, FILE_ALIGNMENT)

  // import section
  a.import_section.PointerToRawData = a.data_section.PointerToRawData + a.data_section.SizeOfRawData
  a.import_section.VirtualAddress = a.data_section.VirtualAddress + align(a.data_section.VirtualSize, SECTION_ALIGNMENT)

  buffer_resize(output_buffer, int(a.import_section.PointerToRawData))

  IMPORT_RVA := a.import_section.VirtualAddress - u32(buffer_len(output_buffer))

  // Descriptors
  for &import_entry in a.import_entries {
    import_entry.descriptor_RVA = u32(buffer_len(output_buffer)) + IMPORT_RVA
    import_entry.descriptor = allocate(output_buffer, IMAGE_IMPORT_DESCRIPTOR)
  }
  termination_entry := allocate(output_buffer, IMAGE_IMPORT_DESCRIPTOR)

  // Library name strings
  for &import_entry in a.import_entries {
    import_entry.descriptor.Name = u32(buffer_len(output_buffer)) + IMPORT_RVA
    alloc_string(output_buffer, import_entry.dll_name)
  }

  // function name strings / 'Hints'
  for &import_entry in a.import_entries {
    for &function_call in import_entry.functions {
      function_call.name_RVA = u64(u32(buffer_len(output_buffer)) + IMPORT_RVA)
      allocate(output_buffer, [2]u8) // hint
      alloc_string(output_buffer, function_call.name)
    }
  }

  // import table
  for &import_entry in a.import_entries {
    import_entry.descriptor.FirstThunk = u32(buffer_len(output_buffer)) + IMPORT_RVA
    for &function_call in import_entry.functions {
      function_call.rva = u32(buffer_len(output_buffer)) + IMPORT_RVA
      for import_call in a.import_calls {
        if import_call.function_name != function_call.name {
          continue
        }

        virtual_address := (cast(u32)import_call.buffer_index - a.text_section.PointerToRawData) + a.text_section.VirtualAddress
        offset :u32 = function_call.rva - virtual_address
        ptr := transmute(^u32)buffer_ptr(output_buffer, import_call.buffer_index - size_of(u32))
        ptr^ = offset
      }
      rva_entry := allocate(output_buffer, u64)
      rva_entry^ = function_call.name_RVA
    }
    allocate(output_buffer, u64) // termination entry
  }

  a.import_section.VirtualSize = u32(buffer_len(output_buffer)) - a.import_section.PointerToRawData
  a.import_section.SizeOfRawData = align(a.import_section.VirtualSize, FILE_ALIGNMENT)

  a.nt_header.OptionalHeader.DataDirectory[1] = {
    VirtualAddress = a.import_section.VirtualAddress,
    Size = a.import_section.VirtualSize
  }

  // set the buffer to past the import section
  buffer_resize(output_buffer, int(a.import_section.PointerToRawData + a.import_section.SizeOfRawData))
  a.nt_header.OptionalHeader.SizeOfImage = align(a.import_section.VirtualAddress + a.import_section.VirtualSize, SECTION_ALIGNMENT)
}

build :: proc(a: ^Assembler, filename: string){
  file, err := os.open(filename , os.O_CREATE)
  os.write(file, buffer_slice(a.output_buffer))
  os.close(file)
}