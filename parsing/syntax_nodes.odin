#+feature using-stmt

package parsing

Literal :: union {
    i64, f64, string, bool
}

Token :: struct {
    type: TokenType,
    index: int,
    length: int
}

VariableCall :: struct {
    name: string
}

VariableDecleration :: struct {
    name: string,
    type: ^Node,
    value: ^Node
}

Operation :: enum { // order dictates precedence
    ADD,
    SUBTRACT,
    DIVIDE,
    MULTIPLY,
}

BinaryOperator :: struct {
    operation: Operation,
    left: ^Node,
    right: ^Node
}

ProcedureCall :: struct {
    name: string,
    arguments: [dynamic]^Node
}

Procedure :: struct {
    name: string,
    arguments: [dynamic]^Node,
    body: [dynamic]^Node
}

Struct :: struct {
    name: string,
    fields: [dynamic]^Node
}

PrimitiveType :: enum {
    INT, BOOL,FLOAT,STRING
}

PointerType :: struct {
    type: ^Node
}

ArrayType :: struct {
    type: ^Node,
    size: int
}

Node :: union {
    Procedure, Struct, Literal, VariableCall, ProcedureCall, BinaryOperator, VariableDecleration, ArrayType, PointerType, PrimitiveType
}