require_relative 'log'
require_relative 'expression'
require_relative 'statement'
require_relative 'compiler'
require_relative 'fault'
require_relative 'types'

class Parser

    def initialize(tokens)
        @log = Log.new("Parser")
        @tokens = tokens
        @current = 0
        @type_hint = nil
        @allow_no_initialiser = false
        @user_types = {}
    end

    def eof?
        return peek.name == :EOF
    end

    def peek
        return @tokens[@current]
    end

    def peek_next
        return @tokens[@current + 1]
    end

    def previous
        return @tokens[@current - 1]
    end

    def advance
        @current += 1 if !eof?
        return previous
    end

    def revert
        @current -= 1
    end
    
    def check(type)
        return false if eof?
        return peek.name == type
    end

    def check_next(type)
        return false if eof?
        return false if peek_next.name == :EOF
        return peek_next.name == type
    end

    def match_token(*types)
        types.each do |t|
            if check(t)
                advance
                return true
            end
        end
        return false
    end

    def consume_token(type, fault_message)
        return advance if check(type)
        raise fault(peek, fault_message)
    end

    def fault(token, message)
        f = ParseFault.new(token, message)
        Compiler.compile_fault(f)
        return f
    end

    def escape_string(str)
        escaped = str
        escaped = escaped.gsub('\\n', "\n")
        escaped = escaped.gsub('\\t', "\t")
        escaped = escaped.gsub('\\"', "\"")
        return escaped
    end

    def declare_user_type(type_name, type_type)
        @user_types[type_name] = [type_type, [type_name.to_sym]]
    end

    def user_type?(type_name)
        return @user_types.has_key?(type_name)
    end

    def user_type(type_name)
        if user_type?(type_name)
            return @user_types[type_name]
        else
            return nil
        end
    end

    def match_user_type?
        return user_type?(peek.lexeme)
    end

    def synchronise
        # TODO: trace/debug that sychronisation has taken place
        advance

        while !eof?
            return if previous.name == :SEMICOLON

            case peek.name
            when :CLASS, :FUN, :VAR, :FOR, :IF, :WHILE, :PRINT, :RETURN
                return
            end

            advance
        end
    end

    def parse
        statements = []
        while !eof?
            stmt = declaration
            statements.push(stmt) if !stmt.nil?
        end
        return statements
    end

    def infer_type(expr)
        if expr.is_a?(FunctionExpression)
            @log.trace("Inferring type of function expresion")
            @log.trace("FunctionExpression param types are #{expr.parameter_types.inspect}")
            @log.trace("FunctionExpression return type is #{expr.return_type.inspect}")
            return [ :func, [expr.parameter_types, expr.return_type] ]
        end
        return expr.type
    end

    def try_coerce_type(obj_type, type)
        return obj_type if type.nil?

        @log.trace("Object type is #{obj_type.inspect}")
        @log.trace("Coercing to #{type.inspect}")

        # Handle numeric hierarchies
        if type == [:real] && obj_type == [:int]
            @log.trace("Returning #{[:real].inspect} from #{[:int].inspect}")
            return [:real]
        end
        if type == [:rational] && obj_type == [:int]
            @log.trace("Returning #{[:rational].inspect} from #{[:int].inspect}")
            return [:rational]
        end

        # Handle optionals
        if type[0] == :optional && type[1] == obj_type
            @log.trace("Returning #{type.inspect}")
            return type
        end

        # Handle generics
        @log.trace("Returning #{obj_type.each_with_index.map { |el, i| el.nil? ? type[i] : el }.inspect}")
        return obj_type.each_with_index.map { |el, i| el.nil? ? type[i] : el }
    end

    #--------------------------------------------------------------------------#
    # Grammar Functions
    #--------------------------------------------------------------------------#

    def declaration
        @type_hint = nil
        begin
            if match_token(:STRUCT)
                return struct_definition
            end
            if match_token(:DIMENSION)
                return dimension_definiton
            end
            if match_token(:UNIT)
                return unit_definiton
            end
            if match_token(:DEFINITION)
                return variable_definiton
            end
            if check(:TYPE_LITERAL) || match_user_type?
                return variable_declaration
            end
            return statement
        rescue ParseFault => e
            synchronise
            return nil
        end
    end

    def struct_definition
        struct_name = consume_token(:IDENTIFIER, "Expecting struct name.")
        # TOOD: handle inheritence and generic here
        consume_token(:LEFT_BRACE, "Expecting '{' before struct body.")

        fields = []

        declare_user_type(struct_name.lexeme, :struct)

        uninitialised_allowed = @allow_no_initialiser
        @allow_no_initialiser = true
        while !eof? && !check(:RIGHT_BRACE)
            fields.push(declaration)
        end
        @allow_no_initialiser = uninitialised_allowed

        consume_token(:RIGHT_BRACE, "Expecting '}' after struct body.")
        type_fields = {}
        fields.each do |f| 
            type_fields[f.name.lexeme] = f.type 
        end
        return StructDeclarationStatement.new(struct_name, fields)
    end

    def dimension_definiton
        var_name = consume_token(:IDENTIFIER, "Expecting dimension name.")
        relationship = nil
        if match_token(:ASSIGNMENT)
            relationship = nil
        end
        return DimensionDeclarationStatement.new(var_name, relationship)
    end

    def unit_definiton

    end

    def variable_definiton
        var_name = consume_token(:IDENTIFIER, "Expecting object name.")
        value = expression
        var_type = infer_type(value)
        return VariableDeclarationStatement.new(var_name, var_type, value)
    end

    def variable_declaration
        var_type = variable_type
        var_name = consume_token(:IDENTIFIER, "Expect variable name.")
        if match_token(:ASSIGNMENT)
            initial_value = expression
        elsif @allow_no_initialiser
            initial_value = nil
        else
            fault("Expecting an initial value for '#{var_name.lexeme}'.")
        end
        if var_type == [:func] && !initial_value.nil?
            var_type = infer_type(initial_value)
        end
        return VariableDeclarationStatement.new(var_name, var_type, initial_value)
    end

    def variable_type
        if match_token(:TYPE_LITERAL)
            var_type = [previous.literal]
        elsif match_user_type?
            consume_token(:IDENTIFIER, "Expecting a variable type")
            var_type = user_type(previous.lexeme)
            if var_type[0] == :struct
                var_type = var_type[0..1]
            end
        else
            raise fault(peek, "Expecting a variable type.")
        end
            
        if var_type[0] == :func && !check(:LESS)
            # Add nil values for func inferrence later:
            var_type += [[nil, nil]]
        end
        loop do
            if match_token(:LEFT_SQUARE)
                consume_token(:RIGHT_SQUARE, "Expecting ']' after '['.")
                var_type = [:array, var_type]
            elsif match_token(:QUESTION)
                var_type = [:optional, var_type]
            elsif match_token(:LESS)
                if var_type[0] == :func
                    func_param_types = []
                    if match_token(:LEFT_PAREN)
                        while !eof? && !check(:RIGHT_PAREN)
                            func_param_types.push(variable_type)
                            break if !check(:COMMA)
                        end
                        consume_token(:RIGHT_PAREN, "Expecting ')' after function parameter types.")
                    end
                    if check(:TYPE_LITERAL) || match_user_type?
                        func_return_type = variable_type
                    else
                        func_return_type = []
                    end
                    var_type += [[func_param_types, func_return_type]]
                    consume_token(:GREATER, "Expecting '>' after function signature")
                else
                    # TODO: add generics
                end
            else
                break
            end
        end
        @type_hint = var_type
        return var_type
    end

    def statement
        if match_token(:RETURN)
            return return_statement
        end
        if match_token(:DEFER)
            return defer_statement
        end
        if match_token(:FOR)
            return for_statement
        end
        if match_token(:IF)
            return if_statement
        end
        if match_token(:WITH)
            return with_statement
        end
        if match_token(:WHILE)
            return while_statement
        end
        if match_token(:DEBUG_TEST)
            return debug_test_statement
        end
        if match_token(:LEFT_BRACE)
            return BlockStatement.new(previous, block)
        end
        return assignment
    end

    def return_statement
        keyword = previous
        value = nil
        if !check(:RIGHT_BRACE)
            value = expression
        end
        return ReturnStatement.new(keyword, value)
    end

    def defer_statement
        keyword = previous
        deferred = statement
        return DeferStatement.new(keyword, deferred)
    end

    def for_statement
        for_token = previous
        consume_token(:LEFT_PAREN, "Expecting '(' before for loop condition.")
        if match_token(:SEMICOLON)
            initialiser = nil
        else
            initialiser = variable_declaration
            consume_token(:SEMICOLON, "Expect ';' after for loop initialiser.");
        end

        if !check(:SEMICOLON)
            condition = or_shortcircuit
        else
            condition = LiteralExpression.new(previous, true, :bool)
        end
        consume_token(:SEMICOLON, "Expect ';' after for loop condition.");

        if !check(:RIGHT_PAREN)
            increment = statement
        else
            increment = nil
        end
        consume_token(:RIGHT_PAREN, "Expecting ')' after for loop condition.")

        body = statement

        if !increment.nil?
            body = BlockStatement.new(for_token, [body, increment])
        end
        body = WhileStatement.new(for_token, condition, body)
        if !initialiser.nil?
            body = BlockStatement.new(for_token, [initialiser, body])
        end

        return body
    end

    def if_statement
        token = previous
        consume_token(:LEFT_PAREN, "Expecting '(' before if statement condition.")
        condition = or_shortcircuit
        consume_token(:RIGHT_PAREN, "Expecting ')' after if statement condition.")

        then_branch = statement
        else_branch = nil

        if match_token(:ELSE)
            else_branch = statement
        end

        return IfStatement.new(token, condition, then_branch, else_branch)
    end

    def with_statement
        token = previous
        consume_token(:LEFT_PAREN, "Expecting '(' before with statement declaration.")
        declaration = variable_declaration
        consume_token(:RIGHT_PAREN, "Expecting ')' after with statement declaration.")

        then_branch = statement
        else_branch = nil

        if match_token(:ELSE)
            else_branch = statement
        end

        return WithStatement.new(token, declaration, then_branch, else_branch)
    end

    def while_statement
        token = previous
        consume_token(:LEFT_PAREN, "Expecting '(' before while loop condition.")
        condition = or_shortcircuit
        consume_token(:RIGHT_PAREN, "Expecting ')' after while loop condition.")
        body = statement

        return WhileStatement.new(token, condition, body)
    end

    def block
        statements = []

        uninitialised_allowed = @allow_no_initialiser
        @allow_no_initialiser = false
        while !check(:RIGHT_BRACE) && !eof?
            statements.push(declaration)
        end
        @allow_no_initialiser = uninitialised_allowed

        consume_token(:RIGHT_BRACE, "Expect '}' after block.")
        return statements
    end

    def debug_test_statement
        value = expression
        return TestAssertStatement.new(previous, value)
    end

    # def user_type_declaration
    #     puts "User type assignment."
    #     var_type = variable_type
    #     var_name = consume_token(:IDENTIFIER, "Expect variable name.")
    #     consume_token(:ASSIGNMENT, "Expecting an initial value for '#{var_name.lexeme}'.")
    #     initial_value = expression
    #     if var_type == [:func] # Allow for function objects to be declared with just func ident = {}
    #         var_type = infer_type(initial_value)
    #     end
    #     return VariableDeclarationStatement.new(var_name, var_type, initial_value)
    # end

    def assignment
        expr = expression

        if (match_token(:ASSIGNMENT))
            equals = previous
            value = expression # Set to Assignment if you want to chain assignments (yuk)

            if expr.is_a?(VariableExpression)
                token_name = expr.name
                return AssignmentStatement.new(token_name, value)
            elsif expr.is_a?(PropertyExpression)
                return PropertyAssignmentStatement.new(expr.token, expr.object, expr.field, value)
            end

            # TODO: Need to handle statements like a.b = foo
            #       (a PropertyExpression as the LHS)
            #       http://craftinginterpreters.com/classes.html#set-expressions

            @log.error("Invalid assignment LHS: " + expr.inspect)
            @log.error("Invalid assignment RHS: " + value.inspect)

            fault(equals, "Invalid assignment target.");
        end

        return expr
    end

    def expression
        return or_shortcircuit
    end

    def or_shortcircuit
        expr = and_shortcircuit

        while match_token(:DOUBLE_PIPE)
            op = previous
            right = and_shortcircuit
            expr = ShortCircuitExpression.new(expr, op, right)
        end

        return expr
    end

    def and_shortcircuit
        expr = equality

        while match_token(:DOUBLE_AMPERSAND)
            op = previous
            right = equality
            expr = ShortCircuitExpression.new(expr, op, right)
        end

        return expr
    end

    def equality
        expr = comparison
        while match_token(:EQUAL, :NOT_EQUAL)
            op = previous
            right = comparison
            expr = BinaryExpression.new(expr, op, right)
        end
        return expr
    end

    def comparison
        expr = addition
        while match_token(:GREATER, :GREATER_EQUAL, :LESS, :LESS_EQUAL, :BEGINS_WITH, :ENDS_WITH, :CONTAINS)
            operator = previous
            right = addition
            expr = BinaryExpression.new(expr, operator, right)
        end
        return expr
    end

    def addition
        expr = multiplication
        while match_token(:MINUS, :PLUS, :PIPE, :PERCENT)
            operator = previous
            right = multiplication
            expr = BinaryExpression.new(expr, operator, right)
        end
        return expr
    end

    def multiplication
        expr = exponent
        while match_token(:STROKE, :ASTERISK, :AMPERSAND, :DOUBLE_STROKE)
            operator = previous
            right = exponent
            expr = BinaryExpression.new(expr, operator, right)
        end
        return expr
    end

    def exponent
        expr = unary
        while match_token(:CARET)
            operator = previous
            right = unary
            expr = BinaryExpression.new(expr, operator, right)
        end
        return expr
    end

    def unary
        if match_token(:NOT, :MINUS, :EXCLAMATION)
            operator = previous
            right = unary
            return UnaryExpression.new(operator, right)
        end
        return call
    end

    def call
        expr = primary

        loop do
            if match_token(:LEFT_PAREN)
                expr = finish_call(expr)
            elsif match_token(:LEFT_SQUARE)
                key = or_shortcircuit
                expr = index_of(expr, key)
            elsif match_token(:DOT)
                field = consume_token(:IDENTIFIER, "Expecting property name after '.'.")
                expr = PropertyExpression.new(expr, field)
            else
                break
            end
        end

        return expr
    end

    def finish_call(callee)
        args = []
        if !check(:RIGHT_PAREN)
            loop do
                args.push(expression)
                break if !match_token(:COMMA)
            end
        end
        paren = consume_token(:RIGHT_PAREN, "Expecting ')' after arguments.")
        return CallExpression.new(callee, paren, args)
    end

    def index_of(expr, key)
        paren = consume_token(:RIGHT_SQUARE, "Expecting ']' after index.")
        return IndexExpression.new(previous, expr, key)
    end

    def primary
        if match_token(:STRING_LITERAL)
            return primitive_literal(try_coerce_type([:string], @type_hint), previous.literal, previous)
        end
        if match_token(:BOOLEAN_LITERAL)
            return primitive_literal(try_coerce_type([:bool], @type_hint), previous.literal, previous)
        end        
        if match_token(:INTEGER_LITERAL)
            return primitive_literal(try_coerce_type([:int], @type_hint), previous.literal, previous)
        end
        if match_token(:REAL_LITERAL)
            return primitive_literal(try_coerce_type([:real], @type_hint), previous.literal, previous)
        end
        if match_token(:RATIONAL_LITERAL)
            return primitive_literal(try_coerce_type([:rational], @type_hint), previous.literal, previous)
        end
        if match_token(:NULL_LITERAL)
            # TODO: should NULL have its own type? Or is it a special value for the optional type?
            # Should this at least be attempted to coerce?
            return primitive_literal([:optional, nil], previous.literal, previous)
        end

        # Array Literals
        if match_token(:LEFT_SQUARE)
            array = []
            while !eof? && !check(:RIGHT_SQUARE)
                array.push(expression)
                break if !match_token(:COMMA)
            end
            consume_token(:RIGHT_SQUARE, "Expecting ']' after array literal.")
            var_type = [:array, nil]
            if !array.empty?
                var_type = [:array, array.first.type]
            end
            return ArrayExpression.new(previous, array, try_coerce_type(var_type, @type_hint))
        end

        # Type Literals / Function Literals
        if check(:TYPE_LITERAL)
            var_token = peek.literal
            type_value = variable_type
            if match_token(:LEFT_BRACE)
                return subroutine_body(previous, [], type_value)
            else
                if type_value == [:func]
                    # Add nil values for func inferrence later
                    type_value += [[nil, nil]]
                end
                return LiteralExpression.new(var_token, type_value, [:type])
            end
        end

        # Function Literals
        if match_token(:LEFT_PAREN)
            if check(:TYPE_LITERAL) || match_user_type?
                type = variable_type
                if check(:IDENTIFIER)
                    params = []
                    var_name = consume_token(:IDENTIFIER, "Expecting parameter name.")
                    params.push({name: var_name, type: type})
                    while !check(:RIGHT_PAREN) && !eof?
                        break if !check(:COMMA)
                        consume_token(:COMMA, "Expecting ',' in parameter list.")
                        type = variable_type
                        var_name = consume_token(:IDENTIFIER, "Expecting parameter name.")
                        params.push({name: var_name, type: type})
                    end
                    consume_token(:RIGHT_PAREN, "Expecting ')' after parameter list.")
                    return_type = []
                    if check(:TYPE_LITERAL) || (check(:IDENTIFIER) && match_user_type?)
                        return_type = variable_type
                    end
                    func_token = consume_token(:LEFT_BRACE, "Expecting '{' before function body.")
                    body = block
                    return FunctionExpression.new(func_token, params, return_type, body)
                else
                    revert
                    group_token = previous
                    expr = expression
                    consume_token(:RIGHT_PAREN, "Expecting ')' after expression.")
                    return GroupingExpression.new(group_token, expr)
                end
            end
            group_token = previous
            expr = expression
            consume_token(:RIGHT_PAREN, "Expecting ')' after expression.")
            return GroupingExpression.new(group_token, expr)
        end

        if match_token(:LEFT_BRACE)
            return subroutine_body(previous, [], [])
        end

        if match_token(:IDENTIFIER)
            if user_type?(previous.lexeme)
                token = previous
                type = user_type(previous.lexeme)
                case type[0]
                when :struct
                    initialiser = {}
                    if match_token(:LEFT_BRACE)
                        while !eof? && !check(:RIGHT_BRACE)
                            # TODO: Get default values for fields
                            field = assignment
                            initialiser[field.name.lexeme] = field.expression
                        end
                        consume_token(:RIGHT_BRACE, "Expecting '}' after struct initialiser.")
                        @log.trace("New Struct Initialiser" + type.inspect)
                        return StructExpression.new(token, type, initialiser)
                    else
                        return LiteralExpression.new(token, type, [:type])
                    end
                end
            end
            return VariableExpression.new(previous)
        end

        raise fault(peek, "Expecting an expression. Got '#{peek.lexeme}'.")
    end

    def primitive_literal(type, value, token)
        case type
        when [:string]
            return LiteralExpression.new(token, escape_string(value.to_s), type)
        when [:int]
            return LiteralExpression.new(token, value.to_i, type)
        when [:real]
            return LiteralExpression.new(token, value.to_f, type)
        when [:rational]
            return LiteralExpression.new(token, value.to_r, type)
        when [:bool]
            return LiteralExpression.new(token, !!value, type)
        else
            if type[0] == :optional
                return LiteralExpression.new(token, value, type)
            else
                raise "What kind of literal is this?"
            end
        end
    end

    def subroutine_body(token, params, return_type)
        body = block
        return FunctionExpression.new(token, params, return_type, body)
    end

end
