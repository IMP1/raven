require_relative 'fault'
require_relative 'visitor'
require_relative 'compiler'
require_relative 'environment'
require_relative 'global_env'

class TypeChecker < Visitor

    GLOBAL_ENV = GlobalEnvironment.new

    def initialize(statements)
        @statements = statements
        @environment = Environment.new(GLOBAL_ENV)
        @function_environment = nil
    end

    def check
        begin
            @statements.each do |stmt|
                check_stmt(stmt)
            end
        rescue RuntimeFault => f
            Compiler.runtime_fault(f)
        end
    end

    def check_stmt(stmt)
        stmt.accept(self)
    end

    def check_block(statements, env)
        previous_env = @environment
        @environment = env
        statements.each { |stmt| check_stmt(stmt) }
        @environment = previous_env
    end

    def check_function(statements, env)
        return_value = nil
        previous_func_env = @function_environment
        begin
            @function_environment = @environment
            execute_block(statements, env)
        rescue Return => r
            return_value = r.value
        end
        previous_env = @environment
        @function_environment.pop_deferred do |stmt, env|
            @environment = env
            execute(stmt.statement)
        end
        @environment = previous_env
        @function_environment = previous_func_env
        return return_value
    end

    def get_expression_type(expr)
        expr.accept(self)
    end

    def assert_type(obj, *types)
        if !types.any? { |t| is_type?(obj, t) }

        end
    end

    def is_type?(obj, type)

    end

    #--------------------------
    # Statements
    #--------------------------

    def visit_ExpressionStatement(stmt)
        get_expression_type(stmt.expression)
    end

    def visit_VariableDeclarationStatement(stmt)
        # TODO: change to care only about /types/
        value = evaluate(stmt.initialiser)
        @environment.define(stmt.name, value)
    end

    def visit_AssignmentStatement(stmt)
        # TODO: check type
        value = evaluate(stmt.expression)
        @environment.assign(stmt.name, value)
    end

    def visit_WhileStatement(stmt)
        get_expression_type(stmt.condition)
        check_stmt(stmt.body)
    end

    def visit_BlockStatement(stmt)
        check_block(stmt.statements, Environment.new(@environment))
    end

    def visit_IfStatement(stmt)
        get_expression_type(stmt.condition)
        check_stmt(stmt.then_branch)
        if !stmt.else_branch.nil?
            check_stmt(stmt.else_branch)
        end
    end

    def visit_DeferStatement(stmt)
        if @function_environment.nil?
            Compiler.runtime_fault(ScopeFault.new(stmt.token, "Can only defer within functions."))
            return
        end
        closure = @environment
        @function_environment.defer(stmt, Environment.new(closure))
    end

    def visit_WithStatement(stmt)
        # TODO: with statements
    end

    def visit_ReturnStatement(stmt)
        value = !stmt.value.nil? ? evaluate(stmt.value) : nil
        raise Return.new(value)
    end

    def visit_TestAssertStatement(stmt)
        assertion = evaluate(stmt.expression)
        if !truthy?(assertion)
            Compiler.runtime_fault(TestFailure.new(stmt.token, "Assertion Failed."))
        end
    end

    #--------------------------
    # Expressions
    #--------------------------

    def visit_BinaryExpression(expr)
        left = get_expression_type(expr.left)
        right = get_expression_type(expr.right)
        
        # TODO: ensure operator is defined on type
        # TODO: check type compatability, don't return the result.
        case expr.operator.type
        when :MINUS
            return left - right
        when :PLUS
            return left + right
        when :ASTERISK
            return left * right
        when :STROKE
            return left.to_r / right
        when :DOUBLE_STROKE
            return (left / right).to_i
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
            return equals(left, right)
        when :NOT_EQUAL
            return left != right
        end
    end

    def visit_UnaryExpression(expr)
        right = get_expression_type(expr.right)
        # TODO: ensure operator is defined on type
        # TODO: check type compatability, don't return the result.

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
        return get_expression_type(expr.expression)
    end

    def visit_ArrayExpression(expr)
        return expr.elements.map { |e| get_expression_type(e) }
    end

    def visit_LiteralExpression(expr)
        # TODO: return /type/ not value
        return expr.value
    end

    def visit_FunctionExpression(expr)
        # TODO: return function signiture? Is that its type? Yeah, I guess.
        func = lambda do |interpreter, args|
            closure = @environment
            env = Environment.new(closure)
            expr.parameter_names.each_with_index { |param, i| env.define(param, args[i]) }
            return interpreter.execute_function(expr.body, env)
        end
        return func
    end

    def visit_ShortCircuitExpression(expr)
        left = get_expression_type(expr.left)

        if truthy?(left) && expr.operator == :DOUBLE_PIPE
            return left
        end
        if !truthy?(left) && expr.operator == :DOUBLE_AMPERSAND
            return left
        end

        return get_expression_type(expr.right)
    end

    def visit_VariableExpression(expr)
        # TODO: return variable's type.
        return @environment[expr.name]
    end

    def visit_CallExpression(expr)
        # TODO: check arg types, and then return function return-type.
        func = evaluate(expr.callee)
        args = expr.arguments.map { |a| evaluate(a) }

        if args.size != expr.arguments.size
            Compiler.runtime_fault(ArgumentFault.new(expr.token, "Expected #{func.arity} args but got #{args.size}."))
        end

        if !func.is_a?(Proc)
            Compiler.runtime_fault(SyntaxFault.new(expr.token, "This object is not callable."))
        end

        func.call(self, args)
    end

end
