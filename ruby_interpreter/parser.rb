require_relative 'expression'
require_relative 'statement'
require_relative 'compiler'
require_relative 'fault'
require_relative 'types'

class Parser

    def initialize(tokens)
        @tokens = tokens
        @current = 0
    end

    def eof?
        return peek.type == :EOF
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
        return peek.type == type
    end

    def check_next(type)
        return false if eof?
        return false if peek_next.type == :EOF
        return peek_next.type == type
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
            return if previous.type == :SEMICOLON

            case peek.type
            when :CLASS, :FUN, :VAR, :FOR, :IF, :WHILE, :PRINT, :RETURN
                return
            end

            advance
        end
    end

    def parse
        statements = []
        while !eof?
            statements.push(declaration)
        end
        return statements
    end


    #--------------------------------------------------------------------------#
    # Grammar Functions
    #--------------------------------------------------------------------------#

    def declaration
        begin
            if match_token(:DEFINITION)
                return variable_definiton
            end
            if check(:TYPE)
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
        var_type = value.type
        return VariableDeclarationStatement.new(var_name, var_type, value)
    end

    def variable_initialisation
        var_type = variable_type
        var_name = consume_token(:IDENTIFIER, "Expect variable name.")
        consume_token(:ASSIGNMENT, "Expecting an initial value for '#{var_name.lexeme}'.")
        initial_value = expression
        return VariableDeclarationStatement.new(var_name, var_type, initial_value);
    end

    def variable_type
        var_type = [consume_token(:TYPE, "Expecting variable type.").literal]
        loop do
            if match_token(:LEFT_SQUARE)
                consume_token(:RIGHT_SQUARE, "Expecting ']' after '['.")
                var_type = [:array, *var_type]
            elsif match_token(:QUESTION)
                var_type = [:optional, *var_type]
            elsif match_token(:LESS)

            else
                break
            end
        end
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
            return BlockStatement.new(block)
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
            condition = LiteralExpression.new(true, :boolean)
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
            body = BlockStatement.new([body, increment])
        end
        body = WhileStatement.new(condition, body)
        if !initialiser.nil?
            body = BlockStatement.new([initialiser, body])
        end

        return body
    end

    def if_statement
        consume_token(:LEFT_PAREN, "Expecting '(' before if statement condition.")
        condition = expression
        consume_token(:RIGHT_PAREN, "Expecting ')' after if statement condition.")

        then_branch = statement
        else_branch = nil

        if match_token(:ELSE)
            else_branch = statement
        end

        return IfStatement.new(condition, then_branch, else_branch)
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
        return ExpressionStatement.new(expr)
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
        if match_token(:STRING)
            return LiteralExpression.new(escape_string(previous.literal), :STRING)
        end
        if match_token(:BOOLEAN, :INTEGER, :REAL, :RATIONAL)
            return LiteralExpression.new(previous.literal, previous.type)
        end        
        if match_token(:LEFT_SQUARE)
            array = []
            while !eof? && !check(:RIGHT_SQUARE)
                array.push(expression)
                break if !match_token(:COMMA)
            end
            consume_token(:RIGHT_SQUARE, "Expecting ']' after array literal.")
            return ArrayExpression.new(array, previous.type)
        end

        if check(:TYPE)
            var_token = peek.literal
            var_type = variable_type
            if match_token(:LEFT_BRACE)
                return subroutine_body([], var_type)
            else
                return LiteralExpression.new(var_type, :TYPE)
            end
        end

        # Function Literals
        if match_token(:LEFT_PAREN)
            if check(:TYPE)
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
                    return_type = nil
                    if match_token(:TYPE)
                        return_type = previous
                    end
                    consume_token(:LEFT_BRACE, "Expecting '{' before function body.")
                    body = block
                    return FunctionExpression.new(params, return_type, body)
                else
                    revert
                    expr = expression
                    consume_token(:RIGHT_PAREN, "Expecting ')' after expression.")
                    return GroupingExpression.new(expr)
                end
            end
            expr = expression
            consume_token(:RIGHT_PAREN, "Expecting ')' after expression.")
            return GroupingExpression.new(expr)
        end

        if match_token(:LEFT_BRACE)
            return subroutine_body([], nil)
        end        

        if match_token(:IDENTIFIER)
            return VariableExpression.new(previous)
        end

        raise fault(peek, "Expecting an expression. Got '#{peek.lexeme}'.")
    end

    def subroutine_body(params, return_type)
        body = block
        return FunctionExpression.new(params, return_type, body)
    end

end
