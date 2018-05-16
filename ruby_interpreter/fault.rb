class Fault < RuntimeError

end

class ParseFault < Fault

    attr_reader :token
    attr_reader :message

    def initialize(token, message)
        @token   = token
        @message = message
    end

end

class TypeFault < Fault
end

class RuntimeFault < Fault
end