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

    attr_reader :environment
    
    GLOBAL_ENV = GlobalEnvironment.new

    def initialize(statements)
        @statements = statements
        @environment = Environment.new("user", GLOBAL_ENV)
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
        @environment = env
        begin
            statements.each { |stmt| execute(stmt) }
        rescue RuntimeFault => f
            Compiler.runtime_fault(f)
        ensure
            @environment = previous_env
        end
    end

    def execute_function(statements, env)
        previous_func_env = @function_environment
        @function_environment = @environment
        # Function Execution
        begin
            execute_block(statements, env)
            return_value = []
        rescue Return => r
            return_value = r.value
        end
        previous_env = @environment
        # Deferred Execution
        @function_environment.pop_deferred do |stmt, env|
            @environment = env
            begin
                execute(stmt.statement)
            rescue Return => r

                Compiler.runtime_fault(ScopeFault.new(stmt.token, "Cannot return from within a deferred statement."))
            end
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

    def is_valid?(stmt)
        value = evaluate(stmt.initialiser)
        return type_equality(SystemFunctions.type_of(value), stmt.type)
        # TODO: evaluate the setup of a with_statement, but specially somehow. 
        # Things are allowed to fail or being incorrect in a with condition. That's the point of a with statement, no?
        return true
    end

    def is_a_type?(obj)
        return obj.is_a?(Array) && obj.all? { |t| t.is_a?(Symbol) || t.is_a?(Array) || t.nil? }
    end

    def equals(left, right)
        if is_a_type?(left) || is_a_type?(right)
            return type_equality(left, right)
        end
        return left == right
    end

    def type_equality(t1, t2)
        # TODO: add type checking
        # func<(int, int) string>  should equal func
        # right?
        return t1 == t2
    end

    #--------------------------
    # Statements
    #--------------------------

    def visit_ExpressionStatement(stmt)
        # TODO: what /is/ this?
        # puts "ExpressionStatement:"
        # p stmt
        # puts
        # p stmt.expression
        # puts
        evaluate(stmt.expression)
    end

    def visit_VariableDeclarationStatement(stmt)
        value = evaluate(stmt.initialiser)
        @environment.define(stmt.name, value, stmt.type)
    end

    def visit_AssignmentStatement(stmt)
        value = evaluate(stmt.expression)
        @environment.assign(stmt.name, value)
    end

    def visit_StructDeclarationStatement(stmt)
        @environment.define(stmt.token, nil, [:type])
        struct_type_obj = {}
        # TODO: make sure the following works with `def x 4 stuff` inside a struct definition.
        stmt.fields.each do |f|
            type = f.type
            default = evaluate(f.initialiser)
            struct_type_obj[f.name.lexeme] = { type: type, default: default }
        end
        @environment.assign(stmt.token, struct_type_obj)
    end

    def visit_WhileStatement(stmt)
        while truthy?(evaluate(stmt.condition))
            execute(stmt.body)
        end
    end

    def visit_BlockStatement(stmt)
        execute_block(stmt.statements, Environment.new("block", @environment))
    end

    def visit_DeferStatement(stmt)
        if @function_environment.nil?
            Compiler.runtime_fault(ScopeFault.new(stmt.token, "Can only defer within functions."))
            return
        end
        closure = @environment
        @function_environment.defer(stmt, Environment.new("defer closure", closure))
    end

    def visit_IfStatement(stmt)
        cond = evaluate(stmt.condition)
        if truthy?(cond)
            execute(stmt.then_branch)
        elsif !stmt.else_branch.nil?
            execute(stmt.else_branch)
        end
    end

    def visit_WithStatement(stmt)
        if is_valid?(stmt.declaration)
            execute_block([stmt.declaration, stmt.then_branch], Environment.new("with", @environment))
        elsif !stmt.else_branch.nil?
            execute(stmt.else_branch)
        end
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
        left = evaluate(expr.left)
        right = evaluate(expr.right)
        
        # TODO: ensure operator is defined on type
        case expr.operator.name
        when :MINUS
            return left - right
        when :PLUS
            return left + right
        when :ASTERISK
            return left * right
        when :STROKE
            return left.to_r / right if left.is_a?(Integer) && right.is_a?(Integer)
            return left / right
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
            return left.start_with?(right)
        when :ENDS_WITH
            return left.end_with?(right)
        when :CONTAINS
            return left.include?(right)

        when :EQUAL
            return equals(left, right)
        when :NOT_EQUAL
            return left != right
        end
    end

    def visit_UnaryExpression(expr)
        right = evaluate(expr.right)

        case expr.operator.name
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
        closure = @environment
        func = lambda do |interpreter, args|
            env = Environment.new("closure", closure)
            expr.parameter_names.each_with_index { |param, i| env.define(param, args[i], expr.parameter_types[i]) }
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

        # TODO: check arg count.
        #       func.arity will always be 2, because it's |environment, args|. Need the size of the args array, but that's just args. Not params.
        #       :/

        # if args.size != func.arity
            # Compiler.runtime_fault(ArgumentFault.new(expr.token, "Expected #{func.arity} args but got #{args.size}."))
        # end

        if !func.is_a?(Proc)
            Compiler.runtime_fault(SyntaxFault.new(expr.token, "This object is not callable."))
        end

        func.call(self, args)
    end

    def visit_IndexExpression(expr)
        collection = evaluate(expr.collection)
        key = evaluate(expr.key)
        return collection[key]
    end

    def visit_StructExpression(expr)
        struct_type_obj = @environment[expr.token]
        if struct_type_obj.nil?
            # TODO: error
        end
        struct_obj = {}
        expr.initial_values.each do |key, value|
            # TODO: make sure key is a valid key (not a token or a symbol or an expression or something.)
            p key
            p value
            struct_obj[key] = value
        end
        struct_type_obj.each do |key, field|
            if !struct_obj.has_key?(key)
                struct_obj[key] = field[:default]
            end
        end
        return struct_obj
    end

    def visit_PropertyExpression(expr)
        return evaluate(expr.object)[expr.field.lexeme]
    end

end

