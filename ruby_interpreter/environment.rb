require_relative 'fault'

class Environment

    attr_reader :name

    def enclosing
        return @parent_environment
    end

    def initialize(name, parent_environment=nil)
        @name = name
        @parent_environment = parent_environment
        @mappings = {}
        @types = {}
        @deffered_statements = []
    end

    def define(token, value, type)
        if mapped?(token)
            Compiler.runtime_fault(SyntaxFault.new(token, "Duplicate variable '#{token.lexeme}'."))
        end
        @mappings[token.lexeme] = value
        @types[token.lexeme] = type
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
        return @mappings.has_key?(token.lexeme)
    end

    def type(token)
        if mapped?(token)
            return @types[token.lexeme]
        end
        if !@parent_environment.nil?
            return @parent_environment.type(token)
        end
        Compiler.runtime_fault(SyntaxFault.new(token, "Undefined variable '#{token.lexeme}'."))
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

    def defer(stmt, env)
        @deffered_statements.push({statement: stmt, environment: env})
    end

    def pop_deferred
        @deffered_statements.reverse.each { |stmt| yield stmt[:statement], stmt[:environment] } 
        @deffered_statements.clear
    end

end