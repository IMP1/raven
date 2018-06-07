require_relative 'log'
require_relative 'fault'
require_relative 'visitor'
require_relative 'compiler'
require_relative 'environment'
require_relative 'global_env'

# A type is an array. This array may only contain symbols or other arrays (which have the same condition on them).
# These nested arrays are subtypes.
# types with subtypes (arrays, optionals, functions) are followed by an array containing the subtype info.
# void types (eg from functions) are empty arrays
# A placeholder type, to be replaced with generics or type inference is referred to by nil. 
# So a subtype is either an array, or nil. A top-level type cannot be nil.

# An Integer types is represented with   [:int]

# An Array of Strings would be           [:array, [:string]]

# A Function whcih takes a single Boolean parameter and returns an Integer would be as follows 
#                 [:func, [ [[:bool]], [:int] ]]
# function       ----/^
# parameter list ----------/^_______^
# bool param     --------------/^
# Return value   -------------------------/^


class TypeChecker < Visitor

    class Return < RuntimeError
        attr_reader :type
        def initialize(type)
            @type = type
        end
    end

    GLOBAL_ENV = GlobalEnvironment.new

    def initialize(statements, log=nil)
        @log = log || Log.new("TypeChecker")
        @statements = statements
        @environment = Environment.new("user", GLOBAL_ENV)
        @function_environment = nil
    end

    def check
        begin
            @statements.each do |stmt|
                check_stmt(stmt)
            end
        rescue StandardError => e
            raise e
            @log.warn(e)
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

    def check_fields(decls, env, field_list)
        previous_env = @environment
        @environment = env
        decls.each do |d| 
            field_list[d.name.lexeme] = d.type
        end
        decls.each do |d|
            puts "Checking declaration"
            p d
            check_stmt(d)
        end
        @environment = previous_env
    end

    def check_function(statements, env)
        previous_env = @environment
        previous_func_env = @function_environment
        begin
            @function_environment = @environment
            check_block(statements, env)
        rescue Return => r
            return_type = r.type || []
            return return_type
        end
        @function_environment.pop_deferred do |stmt, env|
            @environment = env
            check_stmt(stmt.statement)
        end
        @environment = previous_env
        @function_environment = previous_func_env
        return []
    end

    def get_expression_type(expr)
        expr.accept(self)
    end

    def try_coerce_type(obj_type, type)
        return obj_type.each_with_index.map { |el, i| el.nil? ? type[i] : el }
    end

    def assert_type(token, obj_type, types, message="")
        if obj_type.nil?
            @log.trace("obj_type is nil")
            @log.trace(caller)
            return
        end
        @log.trace("Checking that #{token.lexeme.inspect} #{obj_type.inspect} is one of #{types.inspect}")
        if types.all? { |t| !is_type?(obj_type, t) }
            message = token.lexeme if message.empty?
            # puts caller
            Compiler.runtime_fault(TypeFault.new(token, "Invalid type for #{message}. Was expecting one of the following:\n#{types.map {|t| "\t" + t.inspect.to_s }.join("\n")}\nGot \n\t#{obj_type.inspect}"))
        else
            @log.trace("It is!")
        end
    end

    def is_type?(obj_type, type)
        @log.trace(type.inspect)
        @log.trace(obj_type.inspect)
        @log.trace(type[1].compact.inspect) if type[0] == :func
        # Numeric hierarchies:
        return true if type == [:real] && obj_type == [:int]

        # X is an optional X (eg. an int is an optional int).
        return true if type[0] == :optional && type[1] == obj_type

        return true if type == [:any]
        return true if try_coerce_type(obj_type, type) == type
        return true if type[0] == :func && type[1].compact.empty? and obj_type[0] == :func
        return false
    end

    #--------------------------
    # Statements
    #--------------------------

    def visit_ExpressionStatement(stmt)
        get_expression_type(stmt.expression)
    end

    def visit_VariableDeclarationStatement(stmt)
        # puts "Defining var. Type = " + stmt.type.inspect
        if stmt.type[0] == :optional && stmt.type[1][0] == :struct
            # puts "\n------------------------------\n"
            # puts caller
            # puts "\n------------------------------\n"
        end
        @environment.define(stmt.name, nil, stmt.type)
        if !stmt.initialiser.nil?
            assert_type(stmt.token, get_expression_type(stmt.initialiser), [stmt.type])
        end
    end

    def visit_AssignmentStatement(stmt)
        assert_type(stmt.token, get_expression_type(stmt.expression), [@environment.type(stmt.name)])
    end

    def visit_StructDeclarationStatement(stmt)
        type_fields = {}
        puts "Struct fields' types: " + type_fields.inspect
        @environment.define(stmt.token, type_fields, [:struct, [stmt.name.to_sym]])
        check_fields(stmt.fields, Environment.new("struct", @environment), type_fields)
        puts "Struct fields' types: " + type_fields.inspect
    end

    def visit_WhileStatement(stmt)
        get_expression_type(stmt.condition)
        check_stmt(stmt.body)
    end

    def visit_BlockStatement(stmt)
        check_block(stmt.statements, Environment.new("block", @environment))
    end

    def visit_IfStatement(stmt)
        assert_type(stmt.token, get_expression_type(stmt.condition), [[:bool]])
        check_stmt(stmt.then_branch)
        if !stmt.else_branch.nil?
            check_stmt(stmt.else_branch)
        end
    end

    def visit_DeferStatement(stmt)
        check_stmt(stmt.statement)
    end

    def visit_WithStatement(stmt)
        # TODO: check the condition specially. Somethings are still not valid, right?
        # int? a = NULL
        # with (string b = a) { ... } should fail right? Nahhhhh, not at compile time... ¬_¬
        previous_env = @environment
        @environment = Environment.new("with", @environment)
        @environment.define(stmt.declaration.name, nil, stmt.declaration.type)
        check_stmt(stmt.then_branch)
        if !stmt.else_branch.nil?
            check_stmt(stmt.else_branch)
        end
        @environment = previous_env
        
    end

    def visit_ReturnStatement(stmt)
        type = !stmt.value.nil? ? get_expression_type(stmt.value) : nil
        raise Return.new(type)
    end

    def visit_TestAssertStatement(stmt)
        assert_type(stmt.token, get_expression_type(stmt.expression), [[:bool]])
    end

    #--------------------------
    # Expressions
    #--------------------------

    def visit_BinaryExpression(expr)
        left = get_expression_type(expr.left)
        right = get_expression_type(expr.right)

        # TODO: ensure operator is defined on type

        case expr.operator.name
        when :STROKE
            assert_type(expr.token, left, [[:int], [:real], [:rational]])
            assert_type(expr.token, right, [[:int], [:real], [:rational]])
            if left == [:real] || right == [:real]
                return [:real]
            else
                return [:rational]
            end

        when :DOUBLE_STROKE
            assert_type(expr.token, left, [[:int], [:real], [:rational]])
            assert_type(expr.token, right, [[:int], [:real], [:rational]])
            return [:int]

        when :MINUS, :ASTERISK, :CARET
            assert_type(expr.token, left, [[:int], [:real], [:rational]])
            assert_type(expr.token, right, [[:int], [:real], [:rational]])
            return left

        when :PLUS
            assert_type(expr.token, left, [[:int], [:real], [:rational], [:string]])
            assert_type(expr.token, right, [[:int], [:real], [:rational], [:string]])
            # TODO: ensure both types are same
            return left

        when :LESS_EQUAL, :LESS, :GREATER_EQUAL, :GREATER
            assert_type(expr.token, left, [right])
            return [:bool]

        when :DOUBLE_AMPERSAND, :DOUBLE_PIPE
            assert_type(expr.token, left, [[:bool]])
            assert_type(expr.token, right, [[:bool]])
            return left

        when :AMPERSAND, :PIPE, :TILDE, :DOUBLE_LEFT, :DOUBLE_RIGHT
            assert_type(expr.token, left, [[:int]]) # TODO: Bitwise operators operate on integers, right?
            return left

        when :BEGINS_WITH, :ENDS_WITH, :CONTAINS
            assert_type(expr.token, left, [[:string]])
            assert_type(expr.token, right, [[:string]])
            return [:bool]

        when :EQUAL, :NOT_EQUAL
            return [:bool]
            # Left and right here can be any type.
        end

        raise "WHAT KIND OF BINARY EXPRESSION IS THIS?"
    end

    def visit_UnaryExpression(expr)
        right = get_expression_type(expr.right)

        # TODO: ensure operator is defined on type

        case expr.operator.name
        when :MINUS
            assert_type(expr.token, right, [[:int], [:real], [:rational]])
            return right
        when :NOT
            assert_type(expr.token, right, [[:int]]) # TODO: Bitwise operators operate on integers, right?
            return right
        when :EXCLAMATION
            assert_type(expr.token, right, [[:bool]])
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
        previous_env = @environment
        @environment = Environment.new("function", @environment)
        expr.parameter_names.each_with_index { |param, i| @environment.define(param, nil, expr.parameter_types[i]) }
        return_type = check_function(expr.body, Environment.new("closure", @environment))
        @environment= previous_env
        # p expr
        assert_type(expr.token, return_type, [expr.return_type], "function definition")
        return [:func, [ expr.parameter_types, expr.return_type ]]
    end

    def visit_ShortCircuitExpression(expr)
        return get_expression_type(expr.left)
    end

    def visit_VariableExpression(expr)
        # p @environment.type(expr.name)
        return @environment.type(expr.name)
    end

    def visit_CallExpression(expr) 
        func_sig = get_expression_type(expr.callee)
        param_types = func_sig[1][0]
        @log.trace("Function Call Expression. '#{expr.callee.token.inspect}' Function signature is #{func_sig.inspect}")
        expr.arguments.each_with_index do |arg, i|
            puts arg.class.to_s + "{"
            arg_type = get_expression_type(arg)
            puts "}" + arg.class.to_s
            # TODO: Look into when paramtypes is nil. Can it be made non-nil? 
            #       Is there something that should happen if it's nil?
            if !param_types.nil?
                assert_type(expr.token, arg_type, [param_types[i]])
            end
        end
        return_type = func_sig[1][1]
        @log.trace("Return type #{return_type.inspect}")
        return return_type
    end

    def visit_IndexExpression(expr)
        collection_type = get_expression_type(expr.collection)
        key_type = get_expression_type(expr.key)
        case collection_type[0]
        when :array
            assert_type(expr.key.token, key_type, [[:int]], "array index")

        # TODO: add other collections and check their key types against key_type.

        end
        return collection_type[1]
    end

    def visit_StructExpression(expr)
        puts "Struct type: " + expr.type.inspect
        return expr.type
    end

    def visit_PropertyExpression(expr)
        obj_type = expr.object.type
        obj_type = @environment.type(expr.object.token) if obj_type.nil?
        obj_fields = @environment[expr.object.name]

        # p expr.object
        # puts "Object type is " + obj_type.inspect

        # p obj_type

        # env = @environment
        # while !env.enclosing.nil?
        #     p env.names
        #     env = env.enclosing
        # end

        user_type = @environment.type(expr.object.name)
        obj_fields = @environment[user_type[1][0].to_s]

        puts "==================\n\n"

        puts "Getting #{expr.field.lexeme} from #{expr.object.name.lexeme}"
        p @environment[expr.object.name]
        p obj_fields

        field_type = obj_fields[expr.field.lexeme]

        return field_type
    end

    def visit_PropertyAssignmentStatement(stmt)
        puts "Assigning a property."
        p stmt.object
        p stmt.field

        puts "\n\n"
        obj_type = stmt.object.type

        obj_field = stmt.field
        return obj_field
    end

end
