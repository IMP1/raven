require_relative 'lexer'
require_relative 'parser'
require_relative 'interpreter'

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
        # TODO: have this output to a log, instead of just printing (even if the log then just prints)
        puts("#{fault.type}: #{fault.message}")
        puts("        line: #{fault.location}")
    end

    def self.run(source, verbose=false)
        @@runtime_faults = []
        @@compile_faults = []

        scanner = Lexer.new(source);
        tokens = scanner.scan_tokens

        # TODO: trace/debug 
        if verbose
            puts tokens.map {|t| "\t<#{t.to_s}>"}.join("\n")
        end

        parser = Parser.new(tokens)
        statements = parser.parse

        # TODO: trace/debug 
        if verbose
            puts statements.map {|s| s.inspect}
        end

        exit(65) if @@compile_faults.size > 0

        interpreter = Interpreter.new(statements)
        interpreter.interpret

        exit(70) if @@runtime_faults.size > 0
    end

    def self.run_file(filename, verbose=false)
        run(File.open(filename, 'r').read, verbose);
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