require_relative 'compiler'

module SystemFunctions

    def self.print(obj)
        Kernel.print(to_string(obj))
        # TODO: add a io module and make this call out to io.write(io.stdout, message)
    end

    def self.to_string(obj)
        if obj.is_a?(Array) && obj.all? { |t| t.is_a?(Symbol) }
            return type_to_string(obj)
        end
        return obj.to_s
    end

    def self.type_to_string(type_list)
        return type_list.reverse.inject("") { |memo, t| t.to_s + (memo.empty? ? "" : "<#{memo}>") }
    end

    def self.type_of(obj)
        return [:int]      if obj.is_a?(Integer)
        return [:real]     if obj.is_a?(Float)
        return [:string]   if obj.is_a?(String)
        return [:bool]     if (obj == true || obj == false)
        return [:rational] if obj.is_a?(Rational)
        if obj.is_a?(Proc)
            return func_type(obj)
        end
        if obj.is_a?(Array)
            return array_type(obj)
        end
        puts "COULD NOT DETECT TYPE OF OBJECT!!"
        p obj
        puts 
        return [:any]
    end

    def self.func_type(func)
        # TODO: return the function signiture
        return [:func, [nil, nil]]
    end

    def self.array_type(array)
        return [:type] if array.all? { |value| value.is_a?(Symbol) || value.is_a?(Array) }
        return [:array, [:int]]      if array.all? { |value| value.is_a?(Integer) }
        return [:array, [:real]]     if array.all? { |value| value.is_a?(Float) }
        return [:array, [:string]]   if array.all? { |value| value.is_a?(String) }
        return [:array, [:bool]]     if array.all? { |value| (value == true || value == false) }
        return [:array, [:rational]] if array.all? { |value| value.is_a?(Rational) }
        return [:array, [:func]]     if array.all? { |value| value.is_a?(Proc) }
    end

end