class Fault < RuntimeError

    attr_reader :message
    attr_reader :token

    def initialize(message)
        @message = message
    end

    def location
        return @token.line
    end

    def type
        return self.class.name
    end

end

class SyntaxFault < Fault
end

class ParseFault < Fault
end

class TypeFault < ParseFault
end

class RuntimeFault < Fault
end