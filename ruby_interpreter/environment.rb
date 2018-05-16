require_relative 'fault'

class Environment

    def initialize()
        @mappings = {}
    end

    def define(token, value)
        @mappings[token.lexeme] = value
    end

    def assign(token, value)
        if mapped?(token)
            @mappings[token.lexeme] = value
        else
            raise SyntaxFault.new(token, "Undefined variable '#{token.lexeme}'.")
        end
    end

    def mapped?(token)
        return @mappings.has_key?(token.lexeme)
    end

    def [](token)
        if mapped?(token.lexeme)
            return @mappings[token.lexeme]
        else
            raise SyntaxFault.new(token, "Undefined variable '#{token.lexeme}'.")
        end
    end

end