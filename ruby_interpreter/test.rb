require_relative 'compiler'

def test_file(filename, root="")
    puts "running test '#{filename[root.length+1..-1]}'..."

    begin
        Compiler.run_file(filename)
    rescue SystemExit

    end
    # TODO: make this nicer?
end

def test_folder(dirname, root=nil)
    puts "running all tests in '#{dirname}'..."
    Dir[File.join(dirname, '*')].each do |f|
        if File.directory?(f)
            test_folder(File.join(f), root || dirname)
        elsif File.file?(f)
            test_file(File.join(f), root)
        end
    end
end

if ARGV.length == 1 && (ARGV[0] == "--all" || ARGV[0] == "-a")
    test_folder(File.join(Dir.home, 'prog', 'raven', 'tests'))
elsif ARGV.length > 0
    ARGV.each { |fn| test_file(fn) }
end