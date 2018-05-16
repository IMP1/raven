require_relative 'lexer'
require_relative 'parser'
# require_relative 'interpreter'

class Compiler

    @@runtime_faults = []
    @@compile_faults = []

    # @@interpreter = Interpreter.new

    def self.syntax_fault(line, message)
        @@compile_faults.push({
            line: line,
            message: message
        })
        report(line, message, "Syntax")
    end

    def self.compile_fault(fault)
        @@compile_faults.push({
            line: fault.token.line,
            message: fault.message
        })
        report(fault.token.line, fault.message)
    end

    def self.runtime_fault(fault)
        @@runtime_faults.push({
            line: fault.token.line,
            message: fault.message,
        })
        report(fault.token.line, fault.message)
    end

    def self.report(line, message, type="", where="")
        puts("[#{line}] #{type}Fault#{where}: #{message}")
    end

    def self.run(source)
        scanner = Lexer.new(source);
        tokens = scanner.scan_tokens

        puts tokens.map {|t| "<#{t.to_s}>"}.join(", ")

        parser = Parser.new(tokens)
        statements = parser.parse

        puts statements.map {|s| s.to_s}

        exit(65) if (@@compile_faults.size > 0)
        exit(70) if (@@runtime_faults.size > 0)

        # @@interpreter.interpret(statements)
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
                run(input)
                print "> "
                input = gets.chomp
            end
        rescue Interrupt => e
            puts "\n"
        end
    end

end