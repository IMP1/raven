require_relative 'lexer'
require_relative 'parser'
require_relative 'interpreter'

class Compiler

    @@runtime_faults = []
    @@compile_faults = []

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

    def self.report(fault)
        puts("#{fault.type}: #{fault.message}")
        puts("        location: #{fault.location}")
    end

    def self.run(source)
        scanner = Lexer.new(source);
        tokens = scanner.scan_tokens

        puts tokens.map {|t| "<#{t.to_s}>"}.join(", ")

        parser = Parser.new(tokens)
        statements = parser.parse

        puts statements.map {|s| s.to_s}

        exit(65) if (@@compile_faults.size > 0)

        interpreter = Interpreter.new(statements)
        interpreter.interpret

        exit(70) if (@@runtime_faults.size > 0)
    end

    def self.run_file(filename)
        run(File.open(filename, 'r').read);
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