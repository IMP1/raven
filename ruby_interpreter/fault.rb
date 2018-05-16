class Fault < RuntimeError

    attr_reader :message

    def initialize(message)
        @message = message
    end

    def location
    end

    def type
        return self.class.name
    end

end

class SyntaxFault < Fault

    attr_reader :line

    def initialize(line, message)
        super(message)
        @line = line
    end

    def location
        return @line
    end

end

class ParseFault < Fault

    attr_reader :token

    def initialize(token, message)
        super(message)
        @token = token
    end

    def location
        return @token.line
    end

end

class TypeFault < ParseFault
end

class RuntimeFault < Fault
end