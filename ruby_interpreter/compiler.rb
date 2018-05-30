require_relative 'log'
require_relative 'lexer'
require_relative 'parser'
require_relative 'interpreter'
require_relative 'type_checker'

class Compiler

    def self.syntax_fault(fault)
        @@compile_faults.push(fault)
        report(fault)
    end

    def self.compile_fault(fault)
        @@compile_faults.push(fault)
        report(fault)
    end

    def self.runtime_fault(fault)
        @@runtime_faults.push(fault)
        report(fault)
    end

    def self.compile_faults
        return @@compile_faults
    end

    def self.runtime_faults
        return @@runtime_faults
    end

    def self.report(fault)
        @@log.error("#{fault.type}: #{fault.message}")
        @@log.error("        line: #{fault.location}")
    end

    def self.run(source, log=nil)
        @@log = log || Log.new("Compiler")
        @@runtime_faults = []
        @@compile_faults = []

        scanner = Lexer.new(source);
        tokens = scanner.scan_tokens

        @@log.trace(tokens.map {|t| "\t<#{t.to_s}>"}.join("\n"))

        parser = Parser.new(tokens)
        statements = parser.parse

        @@log.trace(statements.map {|s| s.inspect}.join("\n"))

        checker = TypeChecker.new(statements)
        checker.check

        exit(65) if @@compile_faults.size > 0

        interpreter = Interpreter.new(statements)
        interpreter.interpret

        exit(70) if @@runtime_faults.size > 0
    end

    def self.run_file(filename, log=nil)
        run(File.open(filename, 'r').read, log);
    end

    def self.run_repl
        begin
            puts "Raven v0.0.0"
            print "> "
            input = gets.chomp
            while input != ":q"
                if input.start_with?(":l")
                    i = input.index(" ") + 1
                    filename = input[i..-1]
                    begin
                        run_file(File.join(Dir::pwd, filename))
                    rescue Errno::ENOENT => e
                        puts "Could not find the file '#{filename}'."
                    end
                else
                    run(input)
                end
                print "> "
                input = gets.chomp
            end
        rescue Interrupt => e
            puts "\n"
        end
    end

end