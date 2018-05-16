class Token

    attr_reader :type
    attr_reader :lexeme
    attr_reader :line
    attr_reader :literal

    def initialize(type, lexeme, line, literal=nil)
        @type    = type;
        @lexeme  = lexeme;
        @line    = line;
        @literal = literal;
    end

    def to_s
        return @type.to_s + " " + @lexeme + " " + (@literal.nil? ? "" : @literal.to_s)
    end

end