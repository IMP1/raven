require_relative 'compiler'

module SystemFunctions

    def self.print(obj)
        Kernel.print(to_string(obj))
        # TODO: add a io module and make this call out to io.write(io.stdout, message)
    end

    def self.to_string(obj)
        if obj.nil?
            return "NULL"
        end
        if obj == true || obj == false
            return obj.to_s.upcase
        end
        if obj.is_a?(Array) && obj.all? { |t| t.is_a?(Symbol) || t.is_a?(Array) || t.nil? }
            return type_to_string(obj)
        end
        if obj.is_a?(Hash)
            return object_to_string(obj)
        end
        if obj.is_a?(Proc)
            return function_to_string(obj)
        end
        return obj.to_s
    end
    
    def self.type_to_string(type_list)
        return type_list.reverse.inject("") { |memo, t| to_string(t) + (memo.empty? ? "" : "<#{memo}>") }
    end

    def self.object_to_string(obj)
        str = "{"
        obj.each do |field, value| 
            if !field.is_a?(Symbol)
                str += "\n" + to_string(field) + " = " + to_string(value) 
            end
        end
        str.gsub!("\n", "\n\t")
        return str + "\n}"
    end

    def self.function_to_string(func)
        return "func<()>"
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
        if obj.is_a?(Hash)
            return object_type(obj)
        end
        if obj.nil?
            return [:optional, nil]
        end
        puts "COULD NOT DETECT TYPE OF OBJECT!!"
        p obj
        puts 
        return [:any]
    end

    def self.object_type(obj)
        return obj[:__type]
    end

    def self.func_type(func)
        # TODO: return the function signature
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
        raise "Could not get array's type."
    end

    def self.debug_scope(interpreter)
        scopes = [interpreter.environment]
        while !scopes.last.enclosing.nil?
            scopes.push(scopes.last.enclosing)
        end
        scopes.reverse.each_with_index { |s, i| puts ("  " * i) + s.name + ": " + s.names.join(" ") }
    end

end