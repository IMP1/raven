require_relative 'environment'
require_relative 'system_functions'

class GlobalEnvironment < Environment

    def initialize
        super
        @mappings['print']  = lambda { |interpreter, args| print(SystemFunctions.to_string(args[0])) }
        @mappings['typeof'] = lambda { |interpreter, args| return SystemFunctions.type_of(args[0]) }
    end

end