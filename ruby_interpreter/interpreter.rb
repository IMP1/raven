require_relative 'fault'
require_relative 'visitor'
require_relative 'compiler'

class Interpreter < Visitor

    def initialize(statements)
        @statements = statements
    end

    def interpret
        begin
            @statements.each do |stmt|
                p evaluate(stmt)
            end 
        rescue RuntimeFault => f
            Compiler.runtime_fault(f)
        end
    end

    #--------------------------
    # Statements
    #--------------------------

    def execute(stmt)
        stmt.accept(self)
    end

    def visit_ExpressionStatement(stmt)
        evaluate(stmt.expression)
    end

    def visit_VariableDeclarationStatement(stmt)

    end

    def visit_WhileStatement(stmt)

    end

    def visit_BlockStatement(stmt)

    end

    def visit_IfStatement(stmt)

    end

    def visit_WithStatement(stmt)

    end

    def visit_FunctionDeclarationStatement(stmt)

    end

    def visit_ReturnStatement(stmt)

    end

    def visit_PrintInspectStatement(stmt)
        p evaluate(stmt.expression)
    end

    #--------------------------
    # Expressions
    #--------------------------

    def evaluate(expr)
        expr.accept(self)
    end

    def truthy?(expr)
        # TODO: if expr is boolean and false, then return false
        return true
    end

    def visit_BinaryExpression(expr)
        left = evaluate(expr.left)
        right = evaluate(expr.right)
        
        # TODO: ensure operator is defined on type
        case expr.operator.type
        when :MINUS
            return left - right
        when :PLUS
            return left + right
        when :ASTERISK
            return left * right
        when :STROKE
            return left / right
        when :CARET
            return left ** right

        when :LESS_EQUAL
            return left <= right
        when :LESS
            return left < right
        when :GREATER_EQUAL
            return left >= right
        when :GREATER
            return left > right

        when :DOUBLE_AMPERSAND
            return left && right
        when :DOUBLE_PIPE
            return left || right

        when :AMPERSAND
            return left & right
        when :PIPE
            return left | right
        when :TILDE
            return left ^ right
        when :DOUBLE_LEFT
            return left << right
        when :DOUBLE_RIGHT
            return left >> right

        when :BEGINS_WITH
            return left & right
        when :ENDS_WITH
            return left | right
        when :CONTAINS
            return left & right

        when :EQUAL
            return left == right
        when :NOT_EQUAL
            return left != right
        end
    end

    def visit_UnaryExpression(expr)
        right = evaluate(expr.right)

        case expr.operator.type
        when :MINUS
            return -right # TODO: ensure operator is defined on type
        when :NOT
            return ~right # TODO: ensure operator is defined on type
        when :EXCLAMATION
            return !truthy?(right)
        end

    end

    def visit_GroupingExpression(expr)
        return evaluate(expr.expression)
    end

    def visit_LiteralExpression(expr)
        return expr.value
    end

    def visit_VariableExpression(expr)

    end

    def visit_CallExpression(expr)

    end

end
