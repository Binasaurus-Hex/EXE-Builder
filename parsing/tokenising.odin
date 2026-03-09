#+feature using-stmt
#+feature dynamic-literals

package parsing
import "core:fmt"

TokenType :: enum {
    LINE_COMMENT,
    STRING, IDENTIFIER, NUMBER,
    OPEN_PARENTHESIS, CLOSE_PARENTHESIS,
    OPEN_BRACKET, CLOSE_BRACKET,
    OPEN_BRACE,CLOSE_BRACE,
    PLUS, MINUS, STAR, FORWARD_SLASH, EQUALS,
    FORWARD_ARROW, BACK_ARRROW,
    COMMA, DOT, COLON, SEMI_COLON,

    FOR, WHILE, IF, ELSE, TRUE, FALSE, STRUCT,

    SPACE, NEWLINE, TAB, CARRIAGE_RETURN,
    END_OF_FILE
}

TokenConstants := map[TokenType]string {
    .SPACE = " ", .NEWLINE = "\n", .TAB = "\t", .CARRIAGE_RETURN = "\r" ,
    .BACK_ARRROW = "<-", .FORWARD_ARROW = "->",
    .OPEN_PARENTHESIS = "(", .CLOSE_PARENTHESIS = ")",
    .OPEN_BRACE = "{", .CLOSE_BRACE = "}",
    .PLUS = "+", .MINUS = "-", .STAR = "*", .FORWARD_SLASH = "/", .EQUALS = "=",
    .COMMA = ",", .DOT = ".", .COLON = ":", .SEMI_COLON = ";",
    .OPEN_BRACKET = "[", .CLOSE_BRACKET = "]"
}

Keywords := map[TokenType]string {
    .FOR = "for",
    .WHILE = "while",
    .IF = "if",
    .ELSE = "else",
    .TRUE = "true",
    .FALSE = "false",
    .STRUCT = "struct"
}

matches :: proc(program_text: string, text_index: int, check_string: string) -> bool{
    first := check_string[0]
    for i in 0..<len(check_string) {
        a := program_text[text_index + i]
        b := check_string[i]
        if a != b {
            return false
        }
    }
    return true
}

matches_number :: proc(program_text: string) -> bool {
    for char in program_text {
        if char < '0' || char > '9' {
            return false
        }
    }
    return true
}

print_tokens :: proc(program_text: string, tokens: []Token){

    for token, i in tokens {

        if is_whitespace(token.type) {
            continue
        }

        fmt.print("{")
        fmt.print(token.type)
        if token.type == .IDENTIFIER || token.type == .LINE_COMMENT || token.type == .STRING{
            fmt.print(":")
            identifier_text :string = program_text[token.index : token.index + token.length]
            fmt.print(identifier_text)
        }
        fmt.print("}")
        if i < len(tokens){
            fmt.print(",")
        }

    }
}

parse_continuous_token :: proc(program_text: string, start_index: int, ending_character: u8) -> Token {
    string_token: Token
    string_token.index = start_index
    string_token.length = -1
    for i := start_index + 1; i < len(program_text); i += 1 {
        if program_text[i] == ending_character {
            string_token.length = i + 1 - start_index
            break
        }
    }
    assert(string_token.length != -1)
    return string_token
}

tokenize :: proc(program_text: string) -> []Token {

    parse_identifier :: proc(program_text: string, tokens: ^[dynamic]Token, i: int, end_of_last_token: int){
        identifier := Token{.IDENTIFIER, end_of_last_token, i - end_of_last_token}

        if false || matches_number(program_text[end_of_last_token : i]){
            identifier.type = .NUMBER
        }
        else {
            for keyword_token, keyword_text in Keywords {
                if matches(program_text, end_of_last_token, keyword_text){
                    identifier.type = keyword_token
                    break
                }
            }
        }
        append(tokens, identifier)
    }

    context.allocator = context.temp_allocator
    tokens: [dynamic]Token
    end_of_last_token :int = 0
    for i := 0; i <len(program_text); i += 1 {

        if program_text[i] == '"'{
            string_token: Token = parse_continuous_token(program_text, i, '"')
            string_token.type = .STRING
            i += string_token.length - 1
            end_of_last_token = i + 1
            append(&tokens, string_token)
            continue
        }

        if matches(program_text, i, "//"){
            line_comment: Token = parse_continuous_token(program_text, i, '\n')
            line_comment.type = .LINE_COMMENT
            i += line_comment.length - 1
            end_of_last_token = i + 1
            append(&tokens, line_comment)
            continue
        }

        for token_type, token_value in TokenConstants {
            if matches(program_text, i, token_value){
                if i > end_of_last_token {
                    parse_identifier(program_text, &tokens, i, end_of_last_token)
                }
                append(&tokens, Token{token_type, i, len(token_value)})
                i += len(token_value) - 1
                end_of_last_token = i + 1
                break
            }
        }
    }
    if end_of_last_token < len(program_text) {
        parse_identifier(program_text, &tokens, len(program_text), end_of_last_token)
    }
    return tokens[:]
}