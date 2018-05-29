class Raven_Primitive
    attr_reader :value
    def initialize(value)
        @value = value
    end
    def to_s
        return @value.to_s
    end
end

class Raven_Integer < Raven_Primitive
    def self.to_s
        return "int"
    end
end

class Raven_Real < Raven_Primitive
end

class Raven_Rational < Raven_Primitive
end

class Raven_Boolean < Raven_Primitive
end

class Raven_String < Raven_Primitive
    def self.escape_string(str)
        return str.gsub('\\n', "\n")
    end

    def initialize(value)
        super(Raven_String.escape_string(value))
    end
end

class Raven_Type < Raven_Primitive
    def initialize(type_tree)
        super(type_tree.size == 1 ? type_tree[0] : type_tree)
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
    def call(interpreter, args)
    end
end

class Raven_Array
    attr_reader :elements
    def initialize(elements)
        @elements = elements
    end
    def self.to_s
        return "array"
    end
    def to_s
        return "[#{@elements.join(", ")}]"
    end
end

class Raven_Optional
    attr_reader :element
    def initialize(element)
        @element = element
    end
end
