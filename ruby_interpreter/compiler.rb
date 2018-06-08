require_relative 'console_style'

require_relative 'log'
require_relative 'lexer'
require_relative 'parser'
require_relative 'interpreter'
require_relative 'type_checker'

class Compiler

    class Exit < RuntimeError
        attr_reader :code
        def initialize(code)
            @code = code
        end
    end

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
        exit(70)
    end

    def self.compile_faults
        return @@compile_faults
    end

    def self.runtime_faults
        return @@runtime_faults
    end

    def self.report(fault)
        message =  "#{fault.type}: #{fault.message}\n"
        message += "      location: #{fault.location}\n\n"
        if File.exists?(fault.token.filename)
            message += ConsoleStyle::ITALICS_ON
            source = File.read(fault.token.filename)
            lines = source.split(/\n/)
            from_line = [fault.token.line-4, 0].max
            to_line   = [fault.token.line+4, lines.size-1].min
            (from_line...to_line).each do |i|
                message += lines[i] + "\n"
            end
            message += ConsoleStyle::BOLD_ON + lines[to_line] + ConsoleStyle::BOLD_OFF + "\n"
            message += ConsoleStyle::RESET + "\n"
        end
        @@log.error(message)
    end

    def self.run(source, filename="", log=nil)
        @@log = log || Log.new("Compiler")
        @@runtime_faults = []
        @@compile_faults = []

        scanner = Lexer.new(source, filename);
        tokens = scanner.scan_tokens

        @@log.trace(tokens.map {|t| "\t<#{t.to_s}>"}.join("\n"))

        @@log.info("Parsing...")
        parser = Parser.new(tokens)
        statements = parser.parse

        @@log.trace(statements.map {|s| s.inspect}.join("\n"))

        @@log.info("Type Checking...")
        log = Log.new("TypeChecker", @@log.get_level, @@log.get_output)
        checker = TypeChecker.new(statements, log)
        checker.check

        exit(65) if @@compile_faults.size > 0

        begin
            @@log.info("Interpreting...")
            interpreter = Interpreter.new(statements)
            interpreter.interpret
        rescue Exit => e
            exit(e.code)
        end

        exit(70) if @@runtime_faults.size > 0
        exit(0)
    end

    def self.run_file(filename, log=nil)
        run(File.open(filename, 'r').read, filename, log);
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
                    run(input, "REPL")
                end
                print "> "
                input = gets.chomp
            end
        rescue Interrupt => e
            puts "\n"
        end
    end

end