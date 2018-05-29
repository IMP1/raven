require_relative 'environment'

class GlobalEnvironment < Environment

    def initialize
        super
        @mappings['print']  = lambda { |interpreter, args| print(to_string(args[0])) }
        @mappings['typeof'] = lambda { |interpreter, args| return type_of(args[0]) }
    end

    def to_string(obj)
        return obj.to_s
    end

    def type_of(obj)
        return obj.class.to_s
        return [:int]      if obj.is_a?(Integer)
        return [:real]     if obj.is_a?(Float)
        return [:string]   if obj.is_a?(String)
        return [:bool]     if (obj == true || obj == false)
        return [:rational] if obj.is_a?(Rational)
        return [:func]     if obj.is_a?(Proc)
        if obj.is_a?(Array)
            return array_type(obj)
        end
    end

    def array_type(array)
        return [:type] if array.all? { |value| value.is_a?(Symbol) }

        return [:array, :int]      if array.all? { |value| value.is_a?(Integer) }
        return [:array, :real]     if array.all? { |value| value.is_a?(Float) }
        return [:array, :string]   if array.all? { |value| value.is_a?(String) }
        return [:array, :bool]     if array.all? { |value| (value == true || value == false) }
        return [:array, :rational] if array.all? { |value| value.is_a?(Rational) }
        return [:array, :func]     if array.all? { |value| value.is_a?(Proc) }
    end

end