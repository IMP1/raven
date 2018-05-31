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
        return str.gsub('\\n', "\n")
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

    def infer_type(expression)
        if expression.is_a?(FunctionExpression)
            @log.trace("Inferring type of function expresion")
            @log.trace("FunctionExpression param types are #{expression.parameter_types.inspect}")
            @log.trace("FunctionExpression return type is #{expression.return_type.inspect}")
            return [ :func, [expression.parameter_types, expression.return_type] ]
        end
        return expression.type
    end

    def try_coerce_type(obj_type, type)
        return obj_type.each_with_index.map { |el, i| el.nil? ? type[i] : el }
    end

    #--------------------------------------------------------------------------#
    # Grammar Functions
    #--------------------------------------------------------------------------#

    def declaration
        @type_hint = nil
        begin
            if match_token(:DEFINITION)
                return variable_definiton
            end
            if check(:TYPE_LITERAL)
                return variable_initialisation
            end
            return statement
        rescue ParseFault => e
            synchronise
            return nil
        end
    end

    def variable_definiton
        var_name = consume_token(:IDENTIFIER, "Expecting object name.")
        value = expression
        var_type = infer_type(value)
        return VariableDeclarationStatement.new(var_name, var_type, value)
    end

    def variable_initialisation
        var_type = variable_type
        var_name = consume_token(:IDENTIFIER, "Expect variable name.")
        consume_token(:ASSIGNMENT, "Expecting an initial value for '#{var_name.lexeme}'.")
        initial_value = expression
        if var_type == [:func] # Allow for function objects to be declared with just func ident = {}
            var_type = infer_type(initial_value)
        end
        return VariableDeclarationStatement.new(var_name, var_type, initial_value);
    end

    def variable_type
        var_type = [consume_token(:TYPE_LITERAL, "Expecting variable type.").literal]
        if var_type[0] == :func && !check(:LESS)
            # Add nil values for func inferrence later:
            var_type += [[nil, nil]]
        end
        loop do
            if match_token(:LEFT_SQUARE)
                consume_token(:RIGHT_SQUARE, "Expecting ']' after '['.")
                var_type = [:array, [*var_type]]
            elsif match_token(:QUESTION)
                var_type = [:optional, [*var_type]]
            elsif match_token(:LESS)
                # TODO: add function signitures
                # TODO: add generics?
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
        return expression_statement
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
            initialiser = variable_initialisation
            consume_token(:SEMICOLON, "Expect ';' after for loop initialiser.");
        end

        if !check(:SEMICOLON)
            condition = expression
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
        token = consume_token(:LEFT_PAREN, "Expecting '(' before if statement condition.")
        condition = expression
        consume_token(:RIGHT_PAREN, "Expecting ')' after if statement condition.")

        then_branch = statement
        else_branch = nil

        if match_token(:ELSE)
            else_branch = statement
        end

        return IfStatement.new(token, condition, then_branch, else_branch)
    end

    def with_statement
        consume_token(:LEFT_PAREN, "Expecting '(' before with statement condition.")
        condition = expression
        consume_token(:RIGHT_PAREN, "Expecting ')' after with statement condition.")

        then_branch = statement
        else_branch = nil

        if match_token(:ELSE)
            else_branch = statement
        end

        return WithStatement.new(condition, then_branch, else_branch)
    end

    def while_statement
        consume_token(:LEFT_PAREN, "Expecting '(' before while loop condition.")
        condition = expression
        consume_token(:RIGHT_PAREN, "Expecting ')' after while loop condition.")
        body = statement

        return WhileStatement.new(condition, body)
    end

    def block
        statements = []

        while !check(:RIGHT_BRACE) && !eof?
            statements.push(declaration)
        end

        consume_token(:RIGHT_BRACE, "Expect '}' after block.")
        return statements
    end

    def debug_test_statement
        value = expression
        return TestAssertStatement.new(previous, value)
    end

    def expression_statement
        expr = expression
        return ExpressionStatement.new(previous, expr)
    end

    def expression
        return assignment
    end

    def assignment
        expr = or_shortcircuit

        if (match_token(:ASSIGNMENT))
            equals = previous
            value = assignment

            if expr.is_a?(VariableExpression)
                token_name = expr.name;
                return AssignmentStatement.new(token_name, value);
            end

            fault(equals, "Invalid assignment target.");
        end

        return expr
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
        while match_token(:GREATER, :GREATER_EQUAL, :LESS, :LESS_EQUAL)
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
        return expr;
    end

    def multiplication
        expr = exponent
        while match_token(:STROKE, :ASTERISK, :AMPERSAND, :DOUBLE_STROKE)
            operator = previous
            right = exponent
            expr = BinaryExpression.new(expr, operator, right)
        end
        return expr;
    end

    def exponent
        expr = unary
        while match_token(:CARET)
            operator = previous
            right = unary
            expr = BinaryExpression.new(expr, operator, right)
        end
        return expr;
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

    def primary
        if match_token(:STRING_LITERAL)
            return LiteralExpression.new(previous, escape_string(previous.literal), [:string])
        end
        if match_token(:BOOLEAN_LITERAL)
            return LiteralExpression.new(previous, previous.literal, [:bool])
        end        
        if match_token(:INTEGER_LITERAL, :REAL_LITERAL, :RATIONAL_LITERAL)
            return LiteralExpression.new(previous, previous.literal, [:int])
        end
        if match_token(:REAL_LITERAL, :RATIONAL_LITERAL)
            return LiteralExpression.new(previous, previous.literal, [:real])
        end
        if match_token(:RATIONAL_LITERAL)
            return LiteralExpression.new(previous, previous.literal, [:rational])
        end
        if match_token(:NULL_LITERAL)
            return LiteralExpression.new(previous, previous.literal, [:optional]) # TODO: should NULL have its own type? Or is it a special value for the optional type?
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
            if !@type_hint.nil?
                var_type = try_coerce_type(var_type, @type_hint)
            end
            return ArrayExpression.new(previous, array, var_type)
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
            if check(:TYPE_LITERAL)
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
                    if check(:TYPE_LITERAL)
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
            return VariableExpression.new(previous)
        end

        raise fault(peek, "Expecting an expression. Got '#{peek.lexeme}'.")
    end

    def subroutine_body(token, params, return_type)
        body = block
        return FunctionExpression.new(token, params, return_type, body)
    end

end
