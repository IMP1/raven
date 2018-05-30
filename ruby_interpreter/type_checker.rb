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
            # TODO: check return value type against function return type
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

    def assert_type(token, obj_type, *types)
        if !types.any? { |t| is_type?(obj_type, t) }
            p token
            Compiler.runtime_fault(TypeFault.new(token, "Invalid type for #{token.lexeme}. Was expecting one of #{types.join(', ')}. Got #{obj_type}"))
        end
    end

    def is_type?(obj_type, type)
        return obj_type == type
    end

    #--------------------------
    # Statements
    #--------------------------

    def visit_ExpressionStatement(stmt)
        get_expression_type(stmt.expression)
    end

    def visit_VariableDeclarationStatement(stmt)
        assert_type(stmt.token, get_expression_type(stmt.initialiser), stmt.type)
        @environment.define(stmt.name, value, stmt.type)
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

        case expr.operator.type
        when :MINUS, :PLUS, :ASTERISK, :STROKE, :DOUBLE_STROKE, :CARET
            assert_type(expr.token, left, [:int], [:real], [:rational])
            assert_type(expr.token, right, [:int], [:real], [:rational])

        when :LESS_EQUAL, :LESS, :GREATER_EQUAL, :GREATER
            assert_type(expr.token, left, right)

        when :DOUBLE_AMPERSAND, :DOUBLE_PIPE
            assert_type(expr.token, left, [:bool])
            assert_type(expr.token, right, [:bool])

        when :AMPERSAND, :PIPE, :TILDE, :DOUBLE_LEFT, :DOUBLE_RIGHT
            assert_type(expr.token, left, [:int]) # TODO: Bitwise operators operate on integers, right?

        when :BEGINS_WITH, :ENDS_WITH, :CONTAINS
            assert_type(expr.token, left, [:string])
            assert_type(expr.token, right, [:string])

        when :EQUAL, :NOT_EQUAL
            # These can be any type.
        end
    end

    def visit_UnaryExpression(expr)
        right = get_expression_type(expr.right)

        # TODO: ensure operator is defined on type

        case expr.operator.type
        when :MINUS
            assert_type(expr.token, left, [:int], [:real], [:rational])
        when :NOT
            assert_type(expr.token, left, [:int]) # TODO: Bitwise operators operate on integers, right?
        when :EXCLAMATION
            assert_type(expr.token, left, [:bool])
        end

    end

    def visit_GroupingExpression(expr)
        return get_expression_type(expr.expression)
    end

    def visit_ArrayExpression(expr)
        return expr.elements.map { |e| get_expression_type(e) }
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
