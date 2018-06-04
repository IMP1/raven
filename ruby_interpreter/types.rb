class Raven_Primitive
    attr_reader :value
    def initialize(value)
        @value = value
    end
    def to_s
        return @value.to_s
    end
    def type
        raise "Raven builtin type implementation missing the 'type' method."
    end
end

class Raven_Any < Raven_Primitive
    def type
        return 'any'
    end
end

class Raven_Integer < Raven_Primitive
    def initialize(value)
        super(value.to_i)
    end
    def type
        return "int"
    end
end

class Raven_Real < Raven_Primitive
    def initialize(value)
        super(value.to_f)
    end
    def type
        return "real"
    end
end

class Raven_Rational < Raven_Primitive
    def initialize(value)
        super(value.to_r)
    end
    def type
        return "rational"
    end
end

class Raven_Boolean < Raven_Primitive
    def initialize(value)
        super(!!value)
    end
    def type
        return "bool"
    end
end

class Raven_String < Raven_Primitive
    def self.escape_string(str)
        return str.to_s.gsub('\\n', "\n")
    end
    def initialize(value)
        super(Raven_String.escape_string(value))
    end
    def type
        return "string"
    end
end

class Raven_Type < Raven_Primitive
    def initialize(type_tree)
        super(type_tree)
    end
    def type
        return "type"
    end
end

class Raven_Function
    attr_reader :parameters
    attr_reader :return_type
    def initialize(block, parameters, return_type)
        @block = block
        @parameters = parameters
        @return_type = return_type
    end
    def type
        params = @parameters.map {|param| param.type }.join(", ")
        result = @return_type
        sig_string = []
        sig_string.push "(#{params})" if !params.empty?
        sig_string.push "#{result}"   if !result.nil?
        return "func<#{sig_string.join(" ")}>"
    end
    def call(interpreter, args)

    end
end

class Raven_Array
    attr_reader :elements
    def initialize(elements, inner_type)
        @elements = elements
        @inner_type = inner_type
    end
    def type
        type_string = "array<#{@inner_type}>"
    end
    def to_s
        return "[#{@elements.join(", ")}]"
    end
end

class Raven_Optional
    attr_reader :element
    def initialize(element, inner_type)
        @element = element
        @inner_type = inner_type
    end
    def type
        return "optional<#{@inner_type}>"
    end
end
