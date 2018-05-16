require_relative 'visitors'

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

    def initialize(value)
        @value = value
    end

end

class VariableExpression < Expression

    attr_reader :name

    def initialize(name)
        @name = name
    end

end

class AssignmentExpression < Expression
    
    attr_reader :name
    attr_reader :value

    def initialize(name, value)
        @name = name
        @value = value
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
