require_relative 'compiler'
require_relative 'token'

class Lexer

    KEYWORDS = {
        # Control keywords
        'if'        => :IF,
        'else'      => :ELSE,
        'with'      => :WITH,
        'while'     => :WHILE,
        'func'      => :FUNC,
        'return'    => :RETURN,
        # Sys functions
        'p'         => :DEBUG_PRINT,
        'print'     => :SYS_PRINT,
        'type'      => :SYS_TYPEOF,
    }

    VALUE_KEYWORDS = {
        # Types
        'int'      => [:TYPE, :INTEGER],
        'real'     => [:TYPE, :REAL],
        'string'   => [:TYPE, :STRING],
        'bool'     => [:TYPE, :BOOLEAN],
        'rational' => [:TYPE, :RATIONAL],
        'func'     => [:TYPE, :FUNCTION],
        # Values
        'TRUE'   => [:BOOLEAN, true],
        'FALSE'  => [:BOOLEAN, false],
    }

    def initialize(source)
        @source = source
        @tokens = []

        @start   = 0
        @current = 0
        @line    = 1

        @is_finished = @source.length == 0
    end

    def eof?
        return @current >= @source.length
    end

    def scan_tokens
        while !eof?
            @start = @current
            scan_token
        end
        @tokens.push(Token.new(:EOF, "", nil, @line))
        return @tokens
    end

    def advance
        @current += 1;
        return @source[@current - 1]
    end

    def add_token(token_type, literal_value=nil)
        lexeme = @source[@start...@current]
        @tokens.push(Token.new(token_type, lexeme, @line, literal_value))
    end

    def advance_if(expected)
        return false if eof?
        return false if @source[@current] != expected

        @current += 1
        return true
    end

    def peek
        return nil if eof?
        return @source[@current]
    end

    def peek_next
        return nil if eof?
        return nil if @current + 1 >= @source.length
        return @source[@current + 1];
    end

    def scan_token
        c = advance
        case c
        when '('
            add_token(:LEFT_PAREN)
        when ')'
            add_token(:RIGHT_PAREN)
        when '{'
            add_token(:LEFT_BRACE)
        when '}'
            add_token(:RIGHT_BRACE)
        when '['
            add_token(:LEFT_SQUARE)
        when ']'
            add_token(:RIGHT_SQUARE)

        when ','
            add_token(:COMMA)
        when '.'
            add_token(:DOT)
        when ':'
            add_token(:COLON)

        when ';'
            add_token(:SEMICOLON)
        when '\\'
            add_token(:BACKSLASH)

        when '-'
            add_token(:MINUS)
        when '+'
            add_token(:PLUS)
        when '*'
            add_token(:ASTERISK)
        when '%'
            add_token(:PERCENT)
        when '/'
            add_token(:STROKE)
        when '·'
            add_token(:INTERPUNCT)
            

        when '¬'
            add_token(:NOT)
        when '&'
            add_token(:AMPERSAND)
        when '|'
            add_token(:PIPE)
        when '?'
            add_token(:QUESTION)

        when ' ', "\r", "\t"
            # do nothing
        when "\n"
            @line += 1

        when '='
            add_token(advance_if('=') ? :EQUAL : :ASSIGNMENT)
        when '!'
            add_token(advance_if('=') ? :NOT_EQUAL : :EXCLAMATION)
        when '<'
            add_token(advance_if('=') ? :LESS_EQUAL : :LESS)
        when '>'
            add_token(advance_if('=') ? :GREATER_EQUAL : :GREATER)
        when '^'
            add_token(advance_if('=') ? :BEGINS_WITH : :CARET)
        when '$'
            add_token(advance_if('=') ? :ENDS_WITH : :DOLLAR)
        when '~'
            add_token(advance_if('=') ? :CONTAINS : :TILDE)

        when '\''
            if advance_if('\'')
                # A comment goes until the end of the line.
                while peek() != '\n' && !eof?
                    advance();
                end
            else
                add_token(:APOSTROPHE);
            end

        when '"'
            string

        when /\d/
            number

        when /[a-zA-Z_]/
            identifier

        else
            Compiler.syntax_fault(@line, "Unexpected character '#{@source[@current-1]}'.")
        end
    end

    def string
        while !eof? && peek != '"'
            @line += 1 if peek == '\n'
            advance
        end

        if eof?
            Compiler.syntax_fault(@line, "Unterminated string.")
            return
        end

        # The closing ".
        advance();
        # Trim the surrounding quotes.
        value = @source[@start + 1...@current - 1]
        add_token(:STRING, value);
    end

    def number
        advance while peek =~ /\d/

        if peek == '.' && peek_next =~ /\d/
            advance
            advance while peek =~ /\d/
            add_token(:REAL, @source[@start...@current].to_f)
        else
            add_token(:INTEGER, @source[@start...@current].to_i)
        end
    end

    def identifier
        advance while peek() =~ /\w/

        # See if the identifier is a reserved word.
        text = @source[@start...@current]

        if VALUE_KEYWORDS.has_key?(text)
            type  = VALUE_KEYWORDS[text][0]
            value = VALUE_KEYWORDS[text][1]
            add_token(type, value)
            return
        end

        if text == "TRUE"
            add_token(:BOOLEAN, true)
            return
        elsif text == "FALSE"
            add_token(:BOOLEAN, false)
            return
        end

        # See if the identifier is a type.
        type = :IDENTIFIER
        type = KEYWORDS[text] if KEYWORDS.has_key?(text)

        add_token(type)
    end

end