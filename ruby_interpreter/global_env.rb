require_relative 'token'
require_relative 'environment'
require_relative 'system_functions'

class GlobalEnvironment < Environment

    def initialize
        super
        define(Token.new(:SYSTEM_FUNCTION, "p", 0, 0), 
            lambda { |interpreter, args| p args[0] }, 
            [:func, [ [[:any]], [] ]])
        define(Token.new(:SYSTEM_FUNCTION, "print", 0, 0), 
            lambda { |interpreter, args| SystemFunctions.print(args[0]) }, 
            [:func, [ [[:any]], [] ]])
        define(Token.new(:SYSTEM_FUNCTION, "typeof", 0, 0), 
            lambda { |interpreter, args| return SystemFunctions.type_of(args[0]) }, 
            [:func, [ [[:any]], [:type] ]])
    end

end