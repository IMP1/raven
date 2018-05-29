require_relative 'log'
require_relative 'compiler'
require_relative 'console_style'

def test_file(filename, root="")
    if !File.file?(filename)
        puts "Couldn't find file '#{filename}'."
        return nil
    end
    local_name = filename[root.length..-1]
    puts "running test '#{local_name}'"
    success = true
    begin
        Compiler.run_file(filename, $log)
    rescue SystemExit
        success = false
    end
    puts "test #{success ? "succeeded" : "failed"}"
    puts
    return {
        test: local_name,
        success: success,
    }
end

def test_folder(dirname, root=nil)
    results = []
    puts "running all tests in '#{dirname}'"
    puts
    Dir[File.join(dirname, '*')].each do |f|
        if File.directory?(f)
            results += test_folder(File.join(f), root || dirname)
        elsif File.file?(f)
            results.push(test_file(File.join(f), root || ""))
        end
    end
    return results
end

def print_results(results)
    $stdout = STDOUT
    s = results.select{ |r| r[:success] }
    f = results.select{ |r| !r[:success] }

    l_title = "#{s.size} succeeded"
    longest_named_test = s.max_by { |t| t[:test].length }
    max_test_name_length = longest_named_test.nil? ? 0 : longest_named_test[:test].length
    max_column_size = [max_test_name_length, l_title.length].max + 4

    print "    "
    print l_title.ljust(max_column_size)
    print "              "
    print "#{f.size} failed"
    print "\n"

    [s.size, f.size].max.times do |i|
        print "    "
        print (i < s.size ? "  * " + result_colour(s[i]) + s[i][:test] : " ").ljust(max_column_size + (i < s.size ? 5 : 0))
        print "              "
        print ConsoleStyle::RESET
        print i < f.size ?  "  * " + result_colour(f[i]) + f[i][:test] : ""
        print "\n"
        print ConsoleStyle::RESET
    end
end

def result_colour(result)
    if result[:success] ^ result[:test].split("/").last.start_with?("fail")
        return ConsoleStyle::FG_GREEN
    else
        return ConsoleStyle::FG_RED
    end
end

verbose  = ARGV.delete("--verbose") || ARGV.delete("-v")
silent   = ARGV.delete("--silent") || ARGV.delete("-s")
all_tests = ARGV.delete("--all") || ARGV.delete("-a")

$log = Log.new("Test")

if verbose
    $log.set_level(Log::TRACE)
end
if silent
    $log.set_output(File.new("/dev/null", 'w'))
end

if all_tests
    results = test_folder(File.join(*__dir__.split('/')[0...-1], 'tests'))
    print_results(results)
elsif ARGV.length > 0
    results = []
    ARGV.each do |fn| 
        if File.directory?(fn)
            results += test_folder(fn)
        elsif File.file?(fn)
            results.push(test_file(fn))
        else
            puts "Invalid command 'fn'."
        end
    end
    print_results(results)
else
    puts "You've not specified any tests to run. To run them all, pass the --all flag."
end