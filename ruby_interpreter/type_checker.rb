require_relative 'fault'
require_relative 'visitor'
require_relative 'compiler'
require_relative 'environment'
require_relative 'global_env'

class TypeChecker < Visitor

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

    def check
        begin
            @statements.each do |stmt|
                check_stmt(stmt)
            end
        rescue RuntimeError => r
            p r
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
            return r.type
        end
        previous_env = @environment
        @function_environment.pop_deferred do |stmt, env|
            @environment = env
            execute(stmt.statement)
        end
        @environment = previous_env
        @function_environment = previous_func_env
        return nil
    end

    def get_expression_type(expr)
        expr.accept(self)
    end

    def try_coerce_type(obj_type, type)
        return obj_type.each_with_index.map { |el, i| el.nil? ? type[i] : el }
    end

    def assert_type(token, obj_type, *types)
        if obj_type.nil?
            puts "obj_type is nil"
            puts caller 
            return
        end
        puts "Checking that #{token.lexeme.inspect} #{obj_type.inspect} is one of #{types.inspect}"
        if types.all? { |t| !is_type?(obj_type.flatten, t) }
            Compiler.runtime_fault(TypeFault.new(token, "Invalid type for #{token.lexeme}. Was expecting one of #{types.inspect}. Got '#{obj_type.inspect}'"))
        else
            puts "It is!"
        end
    end

    def is_type?(obj_type, type)
        return true if type == [:any]
        return try_coerce_type(obj_type, type) == type
    end

    #--------------------------
    # Statements
    #--------------------------

    def visit_ExpressionStatement(stmt)
        get_expression_type(stmt.expression)
    end

    def visit_VariableDeclarationStatement(stmt)
        assert_type(stmt.token, get_expression_type(stmt.initialiser), stmt.type)
        @environment.define(stmt.name, nil, stmt.type)
    end

    def visit_AssignmentStatement(stmt)
        assert_type(stmt.token, get_expression_type(stmt.expression), @environment.type(stmt.name))
    end

    def visit_WhileStatement(stmt)
        get_expression_type(stmt.condition)
        check_stmt(stmt.body)
    end

    def visit_BlockStatement(stmt)
        check_block(stmt.statements, Environment.new(@environment))
    end

    def visit_IfStatement(stmt)
        assert_type(stmt.token, get_expression_type(stmt.condition), [:bool])
        check_stmt(stmt.then_branch)
        if !stmt.else_branch.nil?
            check_stmt(stmt.else_branch)
        end
    end

    def visit_DeferStatement(stmt)
        check_stmt(stmt.statement)
    end

    def visit_WithStatement(stmt)
        # TODO: with statements
    end

    def visit_ReturnStatement(stmt)
        type = !stmt.value.nil? ? get_expression_type(stmt.value) : nil
        raise Return.new(type)
    end

    def visit_TestAssertStatement(stmt)
        assert_type(stmt.token, get_expression_type(stmt.expression), [:bool])
    end

    #--------------------------
    # Expressions
    #--------------------------

    def visit_BinaryExpression(expr)
        left = get_expression_type(expr.left)
        right = get_expression_type(expr.right)

        assert_type(expr.token, left, right)
        
        # TODO: ensure operator is defined on type

        case expr.operator.name
        when :MINUS, :PLUS, :ASTERISK, :STROKE, :DOUBLE_STROKE, :CARET
            assert_type(expr.token, left, [:int], [:real], [:rational])
            assert_type(expr.token, right, [:int], [:real], [:rational])
            return left

        when :LESS_EQUAL, :LESS, :GREATER_EQUAL, :GREATER
            assert_type(expr.token, left, right)
            return [:bool]

        when :DOUBLE_AMPERSAND, :DOUBLE_PIPE
            assert_type(expr.token, left, [:bool])
            assert_type(expr.token, right, [:bool])
            return left

        when :AMPERSAND, :PIPE, :TILDE, :DOUBLE_LEFT, :DOUBLE_RIGHT
            assert_type(expr.token, left, [:int]) # TODO: Bitwise operators operate on integers, right?
            return left

        when :BEGINS_WITH, :ENDS_WITH, :CONTAINS
            assert_type(expr.token, left, [:string])
            assert_type(expr.token, right, [:string])
            return left

        when :EQUAL, :NOT_EQUAL
            return [:bool]
            # These can be any type.
        end

        raise "WHAT KIND OF BINARY EXPRESSION IS THIS?"
    end

    def visit_UnaryExpression(expr)
        right = get_expression_type(expr.right)

        # TODO: ensure operator is defined on type

        case expr.operator.name
        when :MINUS
            assert_type(expr.token, right, [:int], [:real], [:rational])
            return right
        when :NOT
            assert_type(expr.token, right, [:int]) # TODO: Bitwise operators operate on integers, right?
            return right
        when :EXCLAMATION
            assert_type(expr.token, right, [:bool])
            return right
        end

        raise "WHAT KIND OF UNARY EXPRESSION IS THIS?"
    end

    def visit_GroupingExpression(expr)
        return get_expression_type(expr.expression)
    end

    def visit_ArrayExpression(expr)
        if expr.elements.any? {|e| get_expression_type(e) != get_expression_type(expr.elements[0]) }
            Compiler.compile_fault(TypeFault.new(expr.token, "This array contains elements with differing types."))
            return [:array]
        end
        if expr.elements.empty?
            return [:array, nil]
        end
        return [:array, get_expression_type(expr.elements.first)]
    end

    def visit_LiteralExpression(expr)
        return expr.type
    end

    def visit_FunctionExpression(expr)
        return [:func]
        # TODO: return function signiture? Is that its type? Yeah, I guess.
        func = lambda do |interpreter, args|
            closure = @environment
            env = Environment.new(closure)
            expr.parameter_names.each_with_index { |param, i| env.define(param, args[i]) }
            return interpreter.execute_function(expr.body, env)
        end
    end

    def visit_ShortCircuitExpression(expr)
        return get_expression_type(expr.left)
    end

    def visit_VariableExpression(expr)
        # TODO: return variable's type.
        return @environment.type(expr.name)
    end

    def visit_CallExpression(expr)
        # TODO: check arg types, and then return function return-type.
        # func = evaluate(expr.callee)
        # args = expr.arguments.map { |a| evaluate(a) }
        return [:any]
    end

end
