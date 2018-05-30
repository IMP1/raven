require_relative 'environment'
require_relative 'system_functions'

class GlobalEnvironment < Environment

    def initialize
        super
        @mappings['p'] = lambda { |interpreter, args| p args[0] }
        @mappings['print'] = lambda { |interpreter, args| SystemFunctions.print(args[0]) }
        @mappings['typeof'] = lambda { |interpreter, args| return SystemFunctions.type_of(args[0]) }
    end

end