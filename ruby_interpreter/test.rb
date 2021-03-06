require_relative 'log'
require_relative 'compiler'
require_relative 'console_style'

def test_file(filename, root="")
    if !File.file?(filename)
        puts "Couldn't find file '#{filename}'."
        return nil
    end
    local_name = filename[root.length..-1]
    puts ConsoleStyle::BOLD_ON + "Running test #{ConsoleStyle::FG_CYAN}#{local_name}" + ConsoleStyle::RESET
    success = true
    begin
        Compiler.run_file(filename, $log)
    rescue SystemExit => e
        success = false if e.status > 0
    end
    result = {
        test: local_name,
        success: success,
    }
    puts
    puts ConsoleStyle::BOLD_ON + "Completed test #{ConsoleStyle::FG_CYAN}#{local_name}#{ConsoleStyle::RESET} \nResult: " + result_colour(result) + (success ? "success" : "failure") + ConsoleStyle::RESET
    puts
    return result
end

def test_folder(dirname, root=nil)
    results = []
    puts ConsoleStyle::BOLD_ON + "running all tests in #{ConsoleStyle::FG_CYAN}#{dirname}" + ConsoleStyle::RESET
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
    puts
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
        print (i < s.size ? "  * " + result_colour(s[i]) + s[i][:test] + ConsoleStyle::RESET : " ").ljust(max_column_size + (i < s.size ? 9 : 0))
        print "              "
        print i < f.size ?  "  * " + result_colour(f[i]) + f[i][:test] : ""
        print ConsoleStyle::RESET
        print "\n"
    end
    puts
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
$debugging = !!(ARGV.delete("--debug") || ARGV.delete("-d"))
output = $stdout

if ARGV.include?("--output")
    filename = ARGV.delete_at(ARGV.index("--output") + 1)
    output = File.open(filename, 'w')
    ARGV.delete("--output")
end
if ARGV.include?("-o")
    filename = ARGV.delete_at(ARGV.index("-o") + 1)
    output = File.open(filename, 'w')
    ARGV.delete("-o")
end

$log = Log.new("Test")

if verbose
    $log.set_level(Log::TRACE)
end
if silent
    $log.set_level(Log::NONE)
    $stdout = File.open(File::NULL, "w")
end
$log.set_output(output)

if all_tests
    results = test_folder(File.join(*__dir__.split('/')[0...-1], 'tests'))
    print_results(results)
elsif ARGV.length > 0
    results = []
    ARGV.each do |fn| 
        if File.directory?(fn)
            results += test_folder(fn, fn)
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