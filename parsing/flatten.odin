#+feature using-stmt

package parsing

Scope :: struct {
    procedures: [dynamic]^Procedure,
    structs: [dynamic]^Struct,
    variables: map[string]VariableDecleration
}

flatten_block :: proc(input: [dynamic]^Node, output: [dynamic]^Node, scope: Scope){

}

flatten :: proc(input: [dynamic]^Node, output: [dynamic]^Node, scope: Scope) {
    for node in syntax_tree {
        #partial switch v in node {
            case Procedure:
                flatten_block(v.body)

        }
    }
}