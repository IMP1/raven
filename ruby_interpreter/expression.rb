require_relative 'visitor'

class Expression
    include Visitable
end

class BinaryExpression < Expression

    attr_reader :operator
    attr_reader :left
    attr_reader :right

    def initialize(left, operator, right)
        @left = left
        @operator = operator
        @right = right
    end

end

class UnaryExpression < Expression

    attr_reader :operator
    attr_reader :right

    def initialize(operator, right)
        @operator = operator
        @right = right
    end

end

class GroupingExpression < Expression

    attr_reader :expression

    def initialize(expr)
        @expression = expr
    end

end

class LiteralExpression < Expression

    attr_reader :value
    attr_reader :type

    def initialize(value, type)
        @value = value
        @type  = type
    end

end

class ShortCircuitExpression < Expression

    attr_reader :left
    attr_reader :operator
    attr_reader :right

    def intitialize(left, operator, right)
        @left = left
        @operator = operator
        @right = right
    end

end

class VariableExpression < Expression

    attr_reader :name

    def initialize(name)
        @name = name
    end

end

class CallExpression < Expression

    attr_reader :callee
    attr_reader :token
    attr_reader :arguments

    def initialize(callee, token, arguments)
        @callee = callee
        @token = token
        @arguments = arguments
    end

end
