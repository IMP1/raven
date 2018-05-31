class Fault < RuntimeError

    attr_reader :message
    attr_reader :token

    def initialize(token, message)
        @token = token
        @message = message
    end

    def location
        return [@token.line, @token.column]
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

class ArgumentFault < RuntimeFault
end

class ScopeFault < RuntimeFault
end

class TestFailure < RuntimeFault
end