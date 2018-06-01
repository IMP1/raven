class Token

    attr_reader :name
    attr_reader :lexeme
    attr_reader :line
    attr_reader :column
    attr_reader :literal

    def initialize(name, lexeme, line, column, literal=nil)
        @name    = name
        @lexeme  = lexeme
        @line    = line
        @column  = column
        @literal = literal
    end

    def to_s
        return @name.to_s + " '" + @lexeme + "' " + (@literal.nil? ? "" : @literal.to_s)
    end

    def self.system(lexeme)
        return Token.new(:SYSTEM_FUNCTION, lexeme, 0, 0)
    end

end