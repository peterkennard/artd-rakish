myDir = File.expand_path(File.dirname(__FILE__));

require 'rake'

include Rake::DSL

module OS
  def OS.windows?
    (/cygwin|mswin|mingw|bccwin|wince|emx/ =~ RUBY_PLATFORM) != nil
  end

  def OS.mac?
   (/darwin/ =~ RUBY_PLATFORM) != nil
  end

  def OS.unix?
    !OS.windows?
  end

  def OS.linux?
    OS.unix? and not OS.mac?
  end
end

# clipped out of rakish
# This will "pre-process" input lines using the ruby escape sequence
# '#{}' for substitutions
#
#  in the binding
#     linePrefix is an optional prefix to prepend to each line.
#
#     setIndent means set a variable "indent" in the environment
#     to be the indent level of the current raw line
#
#   lines = input lines (has to implement each_line)
#   fout  = output file (has to implement puts, print)
#   bnd   = "binding" to context to evaluate substitutions in
def rubyLinePP(lines,fout,bnd,opts={})

    setIndent = eval('defined? indent',bnd)
    linePrefix = opts[:linePrefix];

    rawLine = nil;
    lineNum = 0;
    begin
        lines.each_line do |line|
            ++lineNum;
            rawLine = line;
            fout.print(linePrefix) if linePrefix;
            if(line =~ /\#\{gitDeployHash\}/)  # bit of hack here for this rakefile might have this get a string list !!!
                fout.puts line.gsub(/\#\{[^\#]+\}/) { |m|
                    eval("indent=#{$`.length}",bnd) if setIndent;
                    eval('"'+m+'"',bnd)
                }
            else
                fout.print(line);
            end
        end
    rescue => e
        puts "error processing line #{lineNum}: #{e}\n\"#{rawLine.chomp}\"";
    end
end

# clipped out of Rakish
# This will "preprocess" an entire file using the ruby escape sequence
# '#{}' for substitutions
#
#   ffrom = input file path
#   fto   = output file path
#   bnd   = "binding" to context to evaluate substitutions in
def rubyPP(ffrom,fto,bnd,opts={})

    begin
        mode = opts[:append] ? 'w+' : 'w';
        if(fto.is_a? File)
            File.open(ffrom,'r') do |fin|
                rubyLinePP(fin,fto,bnd)
            end
        else
            File.open(fto,mode) do |fileto|
                File.open(ffrom,'r') do |fin|
                    rubyLinePP(fin,fileto,bnd)
                end
            end
        end
    rescue => e
        puts("error precessing: #{ffrom} #{e}")
        raise e
    end
end

file :binFindUtil => "#{myDir}/src/artd-rakish-find" do |t|
    gitDeployHash = `git rev-parse HEAD`.chomp
    puts("git hash is #{gitDeployHash}" );
    rubyPP("#{myDir}/src/artd-rakish-find", "#{myDir}/bin/artd-rakish-find", binding);
    if(OS.linux?)
        system("chmod +x \""#{myDir}/bin/artd-rakish-find"\"");
    end
end

task :default do
end

task :buildGem => :binFindUtil do |t|
	cd myDir do
	    ENV['RAKISH_UNSIGNED']='0';
		system("gem build rakish.gemspec");
	end
end

task :buildUnsignedGem => :binFindUtil do |t|
	cd myDir do
	    ENV['RAKISH_UNSIGNED']='1';
		system("gem build rakish.gemspec");
end
end

task :pushGem => [:buildGem] do |t|
	cd myDir do
	    ENV['RAKISH_UNSIGNED']='0';
		system("gem push rakish-#{gemspec.version}.gem");
	end
end

task :installGem => [:buildUnsignedGem] do |t|
	cd myDir do

	    ENV['RAKISH_UNSIGNED']='1';
        gemspec = Gem::Specification::load("#{myDir}/rakish.gemspec");

		userstr = OS.windows? ? "" : "--user-install"
		system("gem install --local --pre #{userstr} rakish-#{gemspec.version}.gem");
	end
end

task :cleanAll do |t|
    FileUtils.rm(binFindUtil);
end

# just here to handle being called from exec-rake.bat dealing with quoted empty arguments
task '' do
end