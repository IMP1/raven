class Raven_Primitive
    attr_reader :value
    def initialize(value)
        @value = value
    end
end

class Raven_Integer < Raven_Primitive
end

class Raven_Real < Raven_Primitive
end

class Raven_Rational < Raven_Primitive
end

class Raven_Boolean < Raven_Primitive
end

class Raven_String < Raven_Primitive
end

class Raven_Type < Raven_Primitive
end

class Raven_Function
    attr_reader :parameters
    attr_reader :return_value
    def initialize(block, parameters, return_value)
        
    end
end

class Raven_Array
    attr_reader :elements
    def initialize(elements)
        @elements = elements
    end
end

class Raven_Optional
    attr_reader :element
    def initialize(element)
        @element = element
    end
end
