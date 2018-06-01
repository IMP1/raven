require_relative 'token'
require_relative 'environment'
require_relative 'system_functions'

class GlobalEnvironment < Environment

    def initialize
        super
        define(Token.system("p"), 
            lambda { |interpreter, args| p args[0] }, 
            [:func, [ [[:any]], [] ]])
        define(Token.system("print"), 
            lambda { |interpreter, args| SystemFunctions.print(args[0]) }, 
            [:func, [ [[:any]], [] ]])
        define(Token.system("typeof"), 
            lambda { |interpreter, args| return SystemFunctions.type_of(args[0]) }, 
            [:func, [ [[:any]], [:type] ]])
    end

end