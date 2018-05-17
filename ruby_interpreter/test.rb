require_relative 'compiler'

def test_file(filename, root="")
    if !File.file?(filename)
        puts "Couldn't find file '#{filename}'."
        return nil
    end
    puts "running test '#{filename[root.length+1..-1]}'"
    success = true
    begin
        Compiler.run_file(filename, $verbose)
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

$verbose   = ARGV.delete("--verbose") || ARGV.delete("-v")
all_tests = ARGV.delete("--all") || ARGV.delete("-a")


if all_tests
    s, f = test_folder(File.join(*__dir__.split('/')[0...-1], 'tests'))
    puts "Ran #{s + f} tests"
    puts "    #{s} succeeded"
    puts "    #{f} failed"
elsif ARGV.length > 0
    successes, failures = 0, 0
    ARGV.each do |fn| 
        result = test_file(fn)
        if !result.nil?
            result ? successes += 1 : failures += 1
        end
    end
    puts "Ran #{successes + failures} tests"
    puts "    #{successes} succeeded"
    puts "    #{failures} failed"
else
    puts "You've not specified any tests to run. To run them all, pass the --all flag."
end