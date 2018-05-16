require_relative 'visitor'

class Statement
    include Visitable
end

class ExpressionStatement < Statement

    attr_reader :expression

    def initialize(expression)
        @expression = expression
    end

end

class VariableDeclarationStatement < Statement

    attr_reader :name
    attr_reader :type
    attr_reader :initialiser

    def initialize(name, type, initialiser)
        @name = name
        @type = type
        @initialiser = initialiser
    end

end

class WhileStatement < Statement

    attr_reader :condition
    attr_reader :body

    def initialize(condition, body)
        @condition = condition
        @body = body
    end

end

class BlockStatement < Statement

    attr_reader :statements

    def initialize(statements)
        @statements = statements
    end

end

class IfStatement < Statement

    attr_reader :condition
    attr_reader :then_branch
    attr_reader :else_branch

    def initialize(condition, then_branch, else_branch=nil)
        @condition   = condition
        @then_branch = then_branch
        @else_branch = else_branch
    end

end

class WithStatement < Statement

    attr_reader :condition
    attr_reader :then_branch
    attr_reader :else_branch

    def initialize(condition, then_branch, else_branch=nil)
        @condition   = condition
        @then_branch = then_branch
        @else_branch = else_branch
    end

end

class FunctionDeclarationStatement < Statement

    attr_reader :name
    attr_reader :parameter_names
    attr_reader :parameter_types
    attr_reader :return_type
    attr_reader :body

    def initialize(name, parameters, return_type, body)
        @name = name
        @parameter_names = parameters.map {|param| param[:name] }
        @parameter_types = parameters.map {|param| param[:type] }
        @return_type = return_type
        @body = body
    end

end

class ReturnStatement < Statement

    attr_reader :token
    attr_reader :value

    def initialize(token, value)
        @token = token
        @value = value
    end

end

# TODO: remove this when printing is implemented as a gloabl language function.
class PrintInspectStatement < Statement

    attr_reader :expression

    def initialize(expression)
        @expression = expression
    end

end