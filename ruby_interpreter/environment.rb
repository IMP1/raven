require_relative 'fault'

class Environment

    def initialize(parent_environment=nil)
        @parent_environment = parent_environment
        @mappings = {}
    end

    def define(token, value)
        @mappings[token.lexeme] = value
    end

    def assign(token, value)
        if mapped?(token)
            @mappings[token.lexeme] = value
            return
        end

        if !@parent_environment.nil?
            @parent_environment.assign(token, value)
            return
        end

        raise SyntaxFault.new(token, "Undefined variable '#{token.lexeme}'.")
    end

    def mapped?(token)
        if @mappings.has_key?(token.lexeme)
            return true
        end

        return false
    end

    def [](token)
        if mapped?(token)
            return @mappings[token.lexeme]
        end

        if !@parent_environment.nil?
            return @parent_environment[token]
        end

        raise SyntaxFault.new(token, "Undefined variable '#{token.lexeme}'.")
    end

end