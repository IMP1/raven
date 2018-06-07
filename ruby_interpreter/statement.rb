require_relative 'visitor'

class Statement
    include Visitable

    attr_reader :token

    def initialize(token)
        @token = token
    end
end

class ExpressionStatement < Statement

    attr_reader :expression

    def initialize(token, expression)
        super(token)
        @expression = expression
    end

end

class VariableDeclarationStatement < Statement

    attr_reader :name
    attr_reader :type
    attr_reader :initialiser

    def initialize(name, type, initialiser)
        super(name)
        @name = name
        @type = type
        @initialiser = initialiser
    end

end

class StructDeclarationStatement < Statement

    attr_reader :name
    attr_reader :fields

    def initialize(token, fields)
        super(token)
        @name = token.lexeme
        @fields = fields
    end

end

class AssignmentStatement < Statement

    attr_reader :name
    attr_reader :expression

    def initialize(name, expression)
        super(name)
        @name = name
        @expression = expression
    end

end

class WhileStatement < Statement

    attr_reader :condition
    attr_reader :body

    def initialize(token, condition, body)
        super(token)
        @condition = condition
        @body = body
    end

end

class BlockStatement < Statement

    attr_reader :statements

    def initialize(token, statements)
        super(token)
        @statements = statements
    end

end

class DeferStatement < Statement

    attr_reader :token
    attr_reader :statement

    def initialize(token, statement)
        super(token)
        @statement = statement
    end

end

class IfStatement < Statement

    attr_reader :token
    attr_reader :condition
    attr_reader :then_branch
    attr_reader :else_branch

    def initialize(token, condition, then_branch, else_branch=nil)
        super(token)
        @condition   = condition
        @then_branch = then_branch
        @else_branch = else_branch
    end

end

class WithStatement < Statement

    attr_reader :declaration
    attr_reader :then_branch
    attr_reader :else_branch

    def initialize(token, declaration, then_branch, else_branch=nil)
        super(token)
        @declaration = declaration
        @then_branch = then_branch
        @else_branch = else_branch
    end

end

class ReturnStatement < Statement

    attr_reader :value

    def initialize(token, value)
        super(token)
        @value = value
    end

end


# TODO: remove this when the language is working as intended.
class TestAssertStatement < Statement

    attr_reader :token
    attr_reader :expression

    def initialize(token, expression)
        super(token)
        @expression = expression
    end

end

class PropertyAssignmentStatement < Statement

    attr_reader :object
    attr_reader :field
    attr_reader :value

    def initialize(token, object, field, value)
        super(token)
        @object = object
        @field = field
        @value = value
    end

end
