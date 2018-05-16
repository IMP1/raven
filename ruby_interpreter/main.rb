require_relative 'compiler'

if ARGV.length > 0
    Compiler.run_file(ARGV[0])
else
    Compiler.run_repl
end