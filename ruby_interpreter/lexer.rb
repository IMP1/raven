require_relative 'compiler'
require_relative 'token'
require_relative 'fault'

class Lexer

    KEYWORDS = {
        # Control keywords
        'if'        => :IF,
        'defer'     => :DEFER,
        'else'      => :ELSE,
        'with'      => :WITH,
        'as'        => :AS,
        'while'     => :WHILE,
        'for'       => :FOR,
        'def'       => :DEFINITION,
        'return'    => :RETURN,
        'test'      => :DEBUG_TEST,
    }

    VALUE_KEYWORDS = {
        # Types
        'int'      => [:TYPE_LITERAL, :int],
        'real'     => [:TYPE_LITERAL, :real],
        'string'   => [:TYPE_LITERAL, :string],
        'bool'     => [:TYPE_LITERAL, :bool],
        'rational' => [:TYPE_LITERAL, :rational],
        'func'     => [:TYPE_LITERAL, :func],
        'type'     => [:TYPE_LITERAL, :type],
        'any'      => [:TYPE_LITERAL, :any],
        # Values
        'TRUE'   => [:BOOLEAN_LITERAL, true],
        'FALSE'  => [:BOOLEAN_LITERAL, false],
        'NULL'   => [:NULL_LITERAL,    nil],
        'true'   => [:BOOLEAN_LITERAL, true],
        'false'  => [:BOOLEAN_LITERAL, false],
        'null'   => [:NULL_LITERAL,    nil],
    }

    def initialize(source)
        @source = source
        @tokens = []

        @start   = 0
        @current = 0
        @line    = 1
        @column  = 1

        @is_finished = @source.length == 0
    end

    def eof?
        return @current >= @source.length
    end

    def newline
        @line += 1
        @column = 1
    end

    def scan_tokens
        while !eof?
            @start = @current
            scan_token
        end
        # TODO: ADD COLUMN TO LINE AS POSITION OF TOKEN
        @tokens.push(Token.new(:EOF, "", @line, @column))
        return @tokens
    end

    def advance
        @current += 1
        @column += 1
        return @source[@current - 1]
    end

    def add_token(token_type, literal_value=nil)
        lexeme = @source[@start...@current]
        @tokens.push(Token.new(token_type, lexeme, @line, @column, literal_value))
    end

    def advance_if(expected)
        return false if eof?
        return false if @source[@current] != expected

        @current += 1
        @column += 1
        return true
    end

    def previous
        return @source[@current - 1]
    end

    def peek
        return nil if eof?
        return @source[@current]
    end

    def peek_next
        return nil if eof?
        return nil if @current + 1 >= @source.length
        return @source[@current + 1]
    end

    def fault(message)
        t = Token.new(:FAULT, @source[@start...@current], @line, @column)
        f = SyntaxFault.new(t, message)
        Compiler.syntax_fault(f)
        return f
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
            add_token(advance_if('/') ? :DOUBLE_STROKE : :STROKE)
        # TODO: Convenience symbols?
        # when '·'
        #     add_token(:INTERPUNCT)
        # when '×'
        #     add_token(:CROSS)

        when '¬'
            add_token(:NOT)
        when '&'
            add_token(advance_if('&') ? :DOUBLE_AMPERSAND : :AMPERSAND)
        when '|'
            add_token(advance_if('|') ? :DOUBLE_PIPE : :PIPE)
        when '?'
            add_token(:QUESTION)

        when ' ', "\r", "\t"
            # do nothing
        when "\n"
            newline

        when '='
            add_token(advance_if('=') ? :EQUAL : :ASSIGNMENT)
        when '!'
            add_token(advance_if('=') ? :NOT_EQUAL : :EXCLAMATION)
        when '<'
            if advance_if('=')
                add_token(:LESS_EQUAL)
            elsif advance_if('<')
                add_token(:DOUBLE_LEFT)
            else
                add_token(:LESS)
            end
        when '>'
            if advance_if('=')
                add_token(:GREATER_EQUAL)
            elsif advance_if('>')
                add_token(:DOUBLE_RIGHT)
            else
                add_token(:GREATER)
            end
        when '^'
            add_token(advance_if('=') ? :BEGINS_WITH : :CARET)
        when '$'
            add_token(advance_if('=') ? :ENDS_WITH : :DOLLAR)
        when '~'
            add_token(advance_if('=') ? :CONTAINS : :TILDE)

        when '\''
            if advance_if('\'')
                if advance_if('{')
                    puts "BLOCK COMMENT: line #{@line}"
                    # TODO: handle nested block comments.
                    while !eof? && !(previous == '\'' && peek == '\'' && peek_next == '}')
                        c = advance
                        newline if c == "\n"
                    end
                    advance # Ignore second '
                    advance # Ignore }
                    puts "BLOCK COMMENT END: line #{@line}"
                else
                    # A comment goes until the end of the line.
                    while peek != "\n" && !eof?
                        advance
                    end
                end
            else
                add_token(:APOSTROPHE)
            end

        when '"'
            string

        # TODO: Convenience symbols?
        # when 'π'
        #     add_token(:REAL_LITERAL, Math::PI)
        # when 'τ'
        #     add_token(:REAL_LITERAL, 2 * Math::PI)

        when /\d/
            number

        when /[a-zA-Z_]/
            identifier

        else
            fault("Unexpected character '#{@source[@current-1]}'.")
        end
    end

    def string
        while !eof? && peek != '"'
            newline if peek == '\n'
            advance
        end

        if eof?
            fault("Unterminated string.")
            return
        end

        # The closing ".
        advance();
        # Trim the surrounding quotes.
        value = @source[@start + 1...@current - 1]
        add_token(:STRING_LITERAL, value);
    end

    def number
        advance while peek =~ /\d/

        if peek == '.' && peek_next =~ /\d/
            advance
            advance while peek =~ /\d/
            add_token(:REAL_LITERAL, @source[@start...@current].to_f)
        elsif peek == '/' && peek_next =~ /\d/
            advance
            advance while peek =~ /\d/
            add_token(:RATIONAL_LITERAL, @source[@start...@current].to_r)
        else
            add_token(:INTEGER_LITERAL, @source[@start...@current].to_i)
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

        # See if the identifier is a type.
        type = :IDENTIFIER
        type = KEYWORDS[text] if KEYWORDS.has_key?(text)

        add_token(type)
    end

end