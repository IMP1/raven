module SystemFunctions

    # TODO: have formatting options?
    def self.to_string(obj)
        if obj.is_a?(Array) && obj.all? { |t| t.is_a?(Symbol) }
            return type_to_string(obj)
        end
        return obj.to_s
    end

    def self.type_to_string(type_list)
        return type_list.reverse.inject("") { |memo, t| t.to_s + (memo.empty? ? "" : "<#{memo}>") }
    end

end