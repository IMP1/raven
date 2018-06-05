require_relative 'visitor'

class Expression
    include Visitable

    attr_reader :type
    attr_reader :token

    def initialize(token, type)
        @token = token
        @type  = type
    end

end

class BinaryExpression < Expression

    attr_reader :operator
    attr_reader :left
    attr_reader :right

    def initialize(left, operator, right)
        super(operator, left.type)
        @left = left
        @operator = operator
        @right = right
    end

end

class UnaryExpression < Expression

    attr_reader :operator
    attr_reader :right

    def initialize(operator, right)
        super(operator, right.type)
        @operator = operator
        @right = right
    end

end

class GroupingExpression < Expression

    attr_reader :expression

    def initialize(token, expr)
        super(token, expr.type)
        @expression = expr
    end

end

class LiteralExpression < Expression

    attr_reader :value

    def initialize(token, value, type)
        super(token, type)
        @value = value
    end

end

class ArrayExpression < Expression

    attr_reader :elements

    def initialize(token, elements, type)
        super(token, type)
        @elements = elements
    end

end

class IndexExpression < Expression

    attr_reader :collection
    attr_reader :key

    def initialize(token, collection, key)
        super(token, collection.type)
        @collection = collection
        @key = key
    end

end

class ShortCircuitExpression < Expression

    attr_reader :left
    attr_reader :operator
    attr_reader :right

    def intitialize(left, operator, right)
        super(operator, left.type)
        @left = left
        @operator = operator
        @right = right
    end

end

class VariableExpression < Expression

    attr_reader :name

    def initialize(name)
        super(name, nil)
        @name = name
    end

end

class FunctionExpression < Expression

    attr_reader :parameter_names
    attr_reader :parameter_types
    attr_reader :return_type
    attr_reader :body

    def initialize(token, parameters, return_type, body)
        # TODO: ca we pass a type here? I think we can, right? We have all we need, no?
        super(token, nil)
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
        super(token, nil)
        @callee = callee
        @token = token
        @arguments = arguments
    end

end

class StructExpression < Expression

    attr_reader :struct_name
    attr_reader :initial_values

    def initialize(token, type, initial_values)
        super(token, [:struct, type])
        @struct_name = type.to_s
        @initial_values = initial_values
    end

end

class PropertyExpression < Expression

    attr_reader :object
    attr_reader :field

    def initialize(object, field)
        super(field, nil)
        @object = object
        @field = field
    end

end
