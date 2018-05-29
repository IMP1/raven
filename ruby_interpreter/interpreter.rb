require_relative 'fault'
require_relative 'visitor'
require_relative 'compiler'
require_relative 'environment'
require_relative 'global_env'

class Interpreter < Visitor

    class Return < RuntimeError
        attr_reader :value
        def initialize(value)
            @value = value
        end
    end
    
    GLOBAL_ENV = GlobalEnvironment.new

    def initialize(statements)
        @statements = statements
        @environment = Environment.new(GLOBAL_ENV)
        @function_environment = nil
    end

    def interpret
        begin
            @statements.each do |stmt|
                evaluate(stmt)
            end
        rescue RuntimeFault => f
            Compiler.runtime_fault(f)
        end
    end

    def execute(stmt)
        stmt.accept(self)
    end

    def execute_block(statements, env)
        previous_env = @environment
        begin
            @environment = env
            statements.each { |stmt| execute(stmt) }
        rescue RuntimeFault => f
            puts "RuntimeFault in block."
            p f
        end
        @environment = previous_env
    end

    def execute_function(statements, env)
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

    def evaluate(expr)
        expr.accept(self)
    end

    def truthy?(value)
        return false if value == false
        return true
    end

    #--------------------------
    # Statements
    #--------------------------

    def visit_ExpressionStatement(stmt)
        evaluate(stmt.expression)
    end

    def visit_VariableDeclarationStatement(stmt)
        value = evaluate(stmt.initialiser)
        @environment.define(stmt.name, value)
    end

    def visit_AssignmentStatement(stmt)
        value = evaluate(stmt.expression)
        @environment.assign(stmt.name, value)
    end

    def visit_WhileStatement(stmt)
        while truthy?(evaluate(stmt.condition))
            execute(stmt.body)
        end
    end

    def visit_BlockStatement(stmt)
        execute_block(stmt.statements, Environment.new(@environment))
    end

    def visit_IfStatement(stmt)
        cond = evaluate(stmt.condition)
        if truthy?(cond)
            execute(stmt.then_branch)
        elsif !stmt.else_branch.nil?
            execute(stmt.else_branch)
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
        
    end

    # def visit_FunctionDeclarationStatement(stmt)
    #     func = lambda do |interpreter, args|
    #         closure = @environment
    #         env = Environment.new(closure)
    #         stmt.parameter_names.each_with_index { |param, i| env.define(param, args[i]) }
    #         return interpreter.execute_function(stmt.body, env)
    #     end
    #     @environment.define(stmt.name, func)
    # end

    def visit_ReturnStatement(stmt)
        value = !stmt.value.nil? ? evaluate(stmt.value) : nil
        raise Return.new(value)
    end

    def visit_PrintInspectStatement(stmt)
        p evaluate(stmt.expression)
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

    def visit_ArrayExpression(expr)
        return expr.elements.map { |e| evaluate(e) }
    end

    def visit_LiteralExpression(expr)
        return expr.value
    end

    def visit_FunctionExpression(expr)
        func = lambda do |interpreter, args|
            closure = @environment
            env = Environment.new(closure)
            expr.parameter_names.each_with_index { |param, i| env.define(param, args[i]) }
            return interpreter.execute_function(expr.body, env)
        end
        return func
    end

    def visit_ShortCircuitExpression(expr)
        left = evaluate(expr.left)

        if truthy?(left) && expr.operator == :DOUBLE_PIPE
            return left
        end
        if !truthy?(left) && expr.operator == :DOUBLE_AMPERSAND
            return left
        end

        return evaluate(expr.right)
    end

    def visit_VariableExpression(expr)
        return @environment[expr.name]
    end

    def visit_CallExpression(expr)
        func = evaluate(expr.callee)
        args = expr.arguments.map { |a| evaluate(a) }
        # GET TYPES OF ARGS

        if args.size != expr.arguments.size
            Compiler.runtime_fault(ArgumentFault.new(expr.token, "Expected #{func.arity} args but got #{args.size}."))
        end

        if !func.is_a?(Proc)
            Compiler.runtime_fault(SyntaxFault.new(expr.token, "This object is not callable."))
        end

        func.call(self, args)
    end

end
