require_relative 'compiler'
require_relative 'token'
require_relative 'environment'
require_relative 'system_functions'

class GlobalEnvironment < Environment

    def initialize
        super("system", nil)
        define(Token.system("p"), 
            lambda { |interpreter, args| p args[0] }, 
            [:func, [ [[:any]], [] ]])
        define(Token.system("print"), 
            lambda { |interpreter, args| SystemFunctions.print(args[0]) }, 
            [:func, [ [[:any]], [] ]])
        define(Token.system("typeof"), 
            lambda { |interpreter, args| return SystemFunctions.type_of(args[0]) }, 
            [:func, [ [[:any]], [:type] ]])
        define(Token.system("debug_scope"),
            lambda { |interpreter, args| SystemFunctions.debug_scope(interpreter) },
            [:func, [ [], [] ]])
        define(Token.system("tostring"),
            lambda { |interpreter, args| return SystemFunctions.to_string(args[0]) },
            [:func, [ [[:any]], [:string] ]])
        define(Token.system("exit"),
            lambda { |interpreter, args| raise Compiler::Exit.new(args[0]) },
            [:func, [ [[:int]], [] ]])
        define(Token.system("system"),
            lambda { |interpreter, args| return `#{args[0]}` },
            [:func, [ [[:string]], [:string] ]])
    end

end