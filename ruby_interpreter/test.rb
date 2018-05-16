require_relative 'compiler'

def test_file(filename, root="")
    puts "running test '#{filename[root.length+1..-1]}'"
    success = true
    begin
        Compiler.run_file(filename)
    rescue SystemExit
        success = false
    end
    puts "test #{success ? "succeeded" : "failed"}"
    puts
    return success
    # TODO: make this nicer?
end

def test_folder(dirname, root=nil)
    successes = 0
    failures = 0
    puts "running all tests in '#{dirname}'"
    Dir[File.join(dirname, '*')].each do |f|
        if File.directory?(f)
            s, f = test_folder(File.join(f), root || dirname)
            successes += s
            failures += f
        elsif File.file?(f)
            test_file(File.join(f), root) ? successes += 1 : failures += 1
        end
    end
    return successes, failures
end

if ARGV.length == 1 && (ARGV[0] == "--all" || ARGV[0] == "-a")
    s, f = test_folder(File.join(Dir.home, 'prog', 'raven', 'tests'))
    puts "Ran #{s + f} tests"
    puts "    #{s} succeeded"
    puts "    #{f} failed"
elsif ARGV.length > 0
    ARGV.each { |fn| test_file(fn) }
end