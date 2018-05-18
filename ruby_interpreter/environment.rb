require_relative 'fault'

class Environment

    def initialize(parent_environment=nil)
        @parent_environment = parent_environment
        @mappings = {}
        @deffered_statements = []
    end

    def define(token, value)
        if mapped?(token)
            Compiler.runtime_fault(SyntaxFault.new(token, "Duplicate variable '#{token.lexeme}'."))
        end
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

        Compiler.runtime_fault(SyntaxFault.new(token, "Undefined variable '#{token.lexeme}'."))
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

        Compiler.runtime_fault(SyntaxFault.new(token, "Undefined variable '#{token.lexeme}'."))
    end

    def defer(statement)
        @deffered_statements.push(statement)
    end

    def pop_deferred
        @deffered_statements.reverse.each { |stmt| yield stmt } 
        @deffered_statements.clear
    end

end