require_relative 'environment'

class GlobalEnvironment < Environment

    def initialize
        super
        @mappings['print']  = lambda { |interpreter, args| print(args[0]) }
        @mappings['typeof'] = lambda { |interpreter, args| return type_of(args[0]) }
    end

    def type_of(value)
        return :int      if value.is_a?(Integer)
        return :rational if value.is_a?(Rational)
        return :real     if value.is_a?(Float)
        return :string   if value.is_a?(String)
        return :type     if value.is_a?(Symbol)
    end

end