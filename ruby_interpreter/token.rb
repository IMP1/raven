class Token

    attr_reader :name
    attr_reader :lexeme
    attr_reader :line
    attr_reader :literal

    def initialize(name, lexeme, line, literal=nil)
        @name    = name;
        @lexeme  = lexeme;
        @line    = line;
        @literal = literal;
    end

    def to_s
        return @name.to_s + " '" + @lexeme + "' " + (@literal.nil? ? "" : @literal.to_s)
    end

end