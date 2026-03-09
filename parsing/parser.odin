#+feature using-stmt

package parsing
import "core:fmt"
import "core:os"
import "core:strings"
import "core:strconv"
import "core:reflect"
import "core:time"

is_whitespace :: proc(token_type: TokenType) -> bool {
    whitespace :[]TokenType : {.SPACE, .NEWLINE, .TAB, .CARRIAGE_RETURN, .LINE_COMMENT}
    for whitespace_token_type in whitespace {
        if whitespace_token_type == token_type {
            return true
        }
    }
    return false
}

is_binary_operator :: proc(token_type: TokenType) -> bool {
    binary_operators :[]TokenType : {.PLUS, .MINUS, .STAR, .FORWARD_SLASH }
    for binary_operator in binary_operators {
        if token_type == binary_operator {
            return true
        }
    }
    return false
}

Parser :: struct {
    program_text: string,
    tokens: []Token,
    token_index: int
}

peek_token :: proc(using parser: ^Parser, steps: int = 1, eat: bool = false) -> Token {
    peek_index: int = token_index
    current_step := 0
    for peek_index < len(tokens){
        current := tokens[peek_index]
        if is_whitespace(current.type) {
            peek_index += 1
            continue
        }
        if eat {
            token_index = peek_index + 1
        }
        current_step += 1
        if current_step == steps{
            return current
        }
        else{
            peek_index += 1
        }
    }

    eof_token : Token
    eof_token.type = .END_OF_FILE
    return eof_token
}

eat_token :: proc(using parser: ^Parser) -> Token {
    return peek_token(parser, eat = true)
}

get_token_text :: proc(using parser: ^Parser, token: Token) -> string {
    return program_text[token.index : token.index + token.length]
}

to_binary_operation :: proc(binary_operator: TokenType) -> Operation {
    #partial switch binary_operator {
        case .PLUS:
            return .ADD
        case .MINUS:
            return .SUBTRACT
        case .STAR:
            return .MULTIPLY
        case .FORWARD_SLASH:
            return .DIVIDE
    }
    return nil
}

parse_variadic :: proc(using parser: ^Parser, item_function: proc(^Parser) -> ^Node, start_type: TokenType, end_type: TokenType, seperator: TokenType) -> [dynamic]^Node {
    nodes: [dynamic]^Node
    start := eat_token(parser)
    assert(start.type == start_type)

    for {
        item := item_function(parser)
        append(&nodes, item)

        next := peek_token(parser)
        if next.type == seperator {
            eat_token(parser)
            next = peek_token(parser)
            if next.type == end_type {
                eat_token(parser)
                break
            }
        }
        else if next.type == end_type {
            eat_token(parser)
            break
        }
    }

    return nodes
}

parse_subexpression :: proc(using parser: ^Parser) -> ^Node {
    start := peek_token(parser)
    base_node := new(Node)
    #partial switch start.type {
        case .OPEN_PARENTHESIS:
            // bracketed expression
            eat_token(parser)
            expression := parse_expression_b(parser)
            closing_parenthesis := eat_token(parser)
            assert(closing_parenthesis.type == .CLOSE_PARENTHESIS)
            return expression
        case .TRUE, .FALSE:
            eat_token(parser)
            bool_literal: Literal = start.type == .TRUE
            base_node^ = bool_literal

        case .STRING:
            eat_token(parser)
            // trim quotations
            start.index += 1
            start.length -= 2
            string_literal: Literal = get_token_text(parser, start)
            base_node^ = string_literal
            return base_node

        case .NUMBER:
            eat_token(parser)
            next := peek_token(parser)
            if next.type == .DOT {
                eat_token(parser)
                float_index : int = start.index
                float_length: int = start.length + 1 // dot
                next = peek_token(parser)
                if next.type == .NUMBER {
                    eat_token(parser)
                    float_length += next.length
                }
                float_string := program_text[float_index: float_index + float_length]
                float_value, ok := strconv.parse_f64(float_string)
                float_literal: Literal = float_value
                base_node^ = float_literal
                return base_node
            }
            else {
                int_string := get_token_text(parser, start)
                int_value, ok := strconv.parse_i64(int_string)
                int_literal: Literal = int_value
                base_node^ = int_literal
                return base_node
            }

        case .IDENTIFIER:
            eat_token(parser)
            next := peek_token(parser)
            #partial switch next.type {
                case .OPEN_PARENTHESIS:
                    base_node^ = ProcedureCall{
                        name = get_token_text(parser, start),
                        arguments = parse_variadic(parser, parse_expression_b, .OPEN_PARENTHESIS, .CLOSE_PARENTHESIS, .COMMA)
                    }
                    return base_node

                case .OPEN_BRACKET:
                    // array index
                case:
                    // variable
                    base_node^= VariableCall {
                        name = get_token_text(parser, start)
                    }
                    return base_node
            }
    }
    return nil
}

parse_increasing_precedence :: proc(parser: ^Parser, left: ^Node, min_precedence: int) -> ^Node {

    operator := peek_token(parser)
    if !is_binary_operator(operator.type) {
        return left
    }
    eat_token(parser)

    operation := to_binary_operation(operator.type)
    current_precedence := cast(int)operation
    if current_precedence <= min_precedence {
        return left
    }
    right := parse_expression_a(parser, current_precedence)

    base_node := new(Node)
    base_node^ = BinaryOperator {
        operation = operation,
        left = left,
        right = right
    }
    return base_node
}

parse_expression_a :: proc(parser: ^Parser, min_precedence: int) -> ^Node {
    left := parse_subexpression(parser)
    for {
        right := parse_increasing_precedence(parser, left, min_precedence)
        if left == right {
            break
        }
        left = right
    }
    return left
}

parse_expression_b :: proc(parser: ^Parser) -> ^Node {
    return parse_expression_a(parser, -10000)
}

parse_type :: proc(using parser: ^Parser) -> ^Node {
    base_node := new(Node)
    next_token := peek_token(parser)

    #partial switch next_token.type {
        case .IDENTIFIER:
            eat_token(parser)
            token_text := get_token_text(parser, next_token)
            primitive_types :[]string : {"int", "bool", "float", "string"}
            for primitive_type, i in primitive_types {
                if token_text == primitive_type {
                    base_node^ = cast(PrimitiveType)i
                    return base_node
                }
            }
        case .STAR:
            eat_token(parser)
            pointer_type: PointerType
            pointer_type.type = parse_type(parser)

            base_node^ = pointer_type
            return base_node
    }
    return nil
}

parse_statement :: proc(using parser: ^Parser) -> ^Node {
    name_or_keyword := peek_token(parser)
    base_node: ^Node = new(Node)
    #partial switch name_or_keyword.type {
        case .IDENTIFIER:
            next := peek_token(parser, steps = 2)
            #partial switch next.type {
                case .COLON: // decleration
                    eat_token(parser)
                    eat_token(parser)
                    type : ^Node = parse_type(parser)

                    decleration_name: string = get_token_text(parser, name_or_keyword)

                    next = peek_token(parser)
                    #partial switch next.type {
                        case .COLON: // CONSTANT
                            eat_token(parser)
                            next = peek_token(parser)
                            #partial switch next.type {
                                case .STRUCT:
                                    eat_token(parser)
                                    base_node^ = Struct {
                                        name = decleration_name,
                                        fields = parse_variadic(parser, parse_statement, .OPEN_BRACE, .CLOSE_BRACE, .COMMA)
                                    }
                                    return base_node

                                case .OPEN_PARENTHESIS:
                                    base_node^ = Procedure{
                                        name = decleration_name,
                                        arguments = parse_variadic(parser, parse_statement, .OPEN_PARENTHESIS, .CLOSE_PARENTHESIS, .COMMA),
                                        body = parse_variadic(parser, parse_statement, .OPEN_BRACE, .CLOSE_BRACE, .SEMI_COLON)
                                    }
                                    return base_node
                            }
                        case:
                            value :^Node = nil
                            if next.type == .EQUALS {
                                eat_token(parser)
                                value = parse_expression_b(parser)
                            }
                            base_node^ = VariableDecleration {
                                name = decleration_name,
                                type = type,
                                value = value
                            }
                            return base_node

                    }

                case :
                    return parse_expression_b(parser)

            }

    }
    return nil
}

parse_program :: proc(using parser: ^Parser) -> [dynamic]^Node {
    context.allocator = context.temp_allocator

    nodes: [dynamic]^Node

    for peek_token(parser).type != .END_OF_FILE {
        append(&nodes, parse_statement(parser))
    }
    return nodes
}


parse :: proc(){

    file_bytes, ok : = os.read_entire_file_from_filename("main.graph")
    if !ok {
        fmt.println("cant find file")
        return
    }

    program_text := transmute(string)file_bytes
    tokens :[]Token = tokenize(program_text)
    print_tokens(program_text, tokens[:])

    parser: Parser
    parser.program_text = program_text
    parser.tokens = tokens
    syntax_tree := parse_program(&parser)
    flattened := flatten(syntax_tree)
}