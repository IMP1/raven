require_relative 'expression'
require_relative 'statement'
require_relative 'compiler'
require_relative 'fault'

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

    def previous
        return @tokens[@current - 1]
    end

    def advance
        @current += 1 if !eof?
        return previous
    end

    def check(type)
        return false if eof?
        return peek.type == type
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

    def synchronize
        puts "[DEBUG] Synchronising"
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
            if match_token(:FUNCTION)
                return function_declaration
            end
            if check(:TYPE)
                return variable_declaration
            end
            return statement
        rescue ParseFault => e
            synchronize
            return nil
        end
    end

    def function_declaration
        func_name = consume_token(:IDENTIFIER, "Expecting function name.")
        params = []
        if match_token(:LEFT_PAREN)
            if !check(:RIGHT_PAREN)
                loop do
                    param_type = consume_token(:TYPE, "Expecting type for function parameter.")
                    param_name = consume_token(:IDENTIFIER, "Expecting name for function parameter.")
                    params.push({type: param_type, name: param_name})
                    break if !match_token(:COMMA)
                end
            end
            consume_token(:RIGHT_PAREN, "Expecting ')' after parameter list.")
        end
        return_type = nil
        if check(:TYPE)
            return_type = consume_token(:TYPE, "Expecting return type of function.")
        end

        consume_token(:LEFT_BRACE, "Expecting '{' to begin function body.")
        body = block
        return FunctionDeclarationStatement.new(func_name, params, return_type, body)
    end

    def variable_declaration
        var_type = consume_token(:TYPE, "Expecting variable type.")
        var_name = consume_token(:IDENTIFIER, "Expect variable name.")

        consume_token(:ASSIGNMENT, "Expecting an initial value for '#{var_name.lexeme}'.")
        initial_value = expression
        return VariableDeclarationStatement.new(var_name, var_type, initial_value);
    end

    def statement
        if match_token(:RETURN)
            return return_statement
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
        if match_token(:DEBUG_PRINT)
            return debug_print_statement
        end
        if match_token(:LEFT_BRACE)
            return BlockStatement.new(block)
        end
        return expression_statement
    end

    def return_statement
        keyword = previous
        value = nil
        if match_token(:LEFT_PAREN)
            value = expression
            consume_token(:RIGHT_PAREN, "Expecting ')' after return value.")
        end
        return ReturnStatement.new(keyword, value)
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

    def debug_print_statement
        value = expression
        return PrintInspectStatement.new(value)
    end

    def expression_statement
        expr = expression
        return ExpressionStatement.new(expr)
    end

    def expression
        return assignment
    end

    def assignment
        expr = equality

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
        while match_token(:STROKE, :ASTERISK, :AMPERSAND, :INTERPUNCT)
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
        if match_token(:NOT, :MINUS)
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

        if match_token(:IDENTIFIER)
            return VariableExpression.new(previous)
        end

        if match_token(:LEFT_PAREN)
            expr = expression
            consume_token(:RIGHT_PAREN, "Expecting ')' after expression.")
            return GroupingExpression.new(expr)
        end

        raise fault(peek, "Expecting an expression. Got '#{peek.lexeme}'.")
    end

end
