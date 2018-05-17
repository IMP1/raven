require_relative 'environment'

class GlobalEnvironment < Environment

    def initialize(parent_environment=nil)
        @parent_environment = parent_environment
        @mappings = {}
        @mappings['print'] = lambda { |i| print(i) }
        @mappings['typeof']  = lambda { |i| return type_of(i) }
    end

    def type_of(value)
        return :int      if value.is_a?(Integer)
        return :rational if value.is_a?(Rational)
        return :real     if value.is_a?(Float)
        return :string   if value.is_a?(String)
        return :type     if value.is_a?(Symbol)
    end

end