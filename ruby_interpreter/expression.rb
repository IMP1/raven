require_relative 'visitor'

class Expression
    include Visitable

    attr_reader :type

    def initialize(type)
        @type = type
    end

end

class BinaryExpression < Expression

    attr_reader :operator
    attr_reader :left
    attr_reader :right

    def initialize(left, operator, right)
        super(left.type)
        @left = left
        @operator = operator
        @right = right
    end

end

class UnaryExpression < Expression

    attr_reader :operator
    attr_reader :right

    def initialize(operator, right)
        super(right.type)
        @operator = operator
        @right = right
    end

end

class GroupingExpression < Expression

    attr_reader :expression

    def initialize(expr)
        super(expr.type)
        @expression = expr
    end

end

class LiteralExpression < Expression

    attr_reader :value

    def initialize(value, type)
        super(type)
        @value = value
    end

end

class ArrayExpression < Expression

    attr_reader :elements

    def initialize(elements, type)
        super(type)
        @elements = elements
    end

end

class ShortCircuitExpression < Expression

    attr_reader :left
    attr_reader :operator
    attr_reader :right

    def intitialize(left, operator, right)
        super(left.type)
        @left = left
        @operator = operator
        @right = right
    end

end

class VariableExpression < Expression

    attr_reader :name

    def initialize(name)
        super(nil)
        @name = name
    end

end

class FunctionExpression < Expression

    attr_reader :parameter_names
    attr_reader :parameter_types
    attr_reader :return_type
    attr_reader :body

    def initialize(parameters, return_type, body)
        @parameter_names = parameters.map {|param| param[:name] }
        @parameter_types = parameters.map {|param| param[:type] }
        @return_type = return_type
        @body = body
    end

end

class CallExpression < Expression

    attr_reader :callee
    attr_reader :token
    attr_reader :arguments

    def initialize(callee, token, arguments)
        super(nil)
        @callee = callee
        @token = token
        @arguments = arguments
    end

end
