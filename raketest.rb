
module Rakish

	module Util
		def testMethod()
			puts("###### testing")
		end
		
		def Util.staticMethod()
			puts("###### static testing")		
		end
	end

	class Project
		include Util
	
		CONST1 = "a const"
	end


end


RakishProject(
	:name => 'raketest'
) do

	testMethod()
	Rakish::Util.staticMethod()
	
	task :doit do |t|
		testMethod();
	end
	
end

module Constants
	CONSTA = 'xxxx'
end

class MyObj < Module
	include Rakish::PropertyBagMod
	
	CONSTA = 'yyyyy'	
#	BINDIR = 'build dir'

def BINDIR
	'build dir'
end
	
	attr_property :NEWUPPER
	
	def initialize(&b)
		init_PropertyBag()
		super &b
	
	# self.instance_eval(&b)
	end
	
	def putit
		puts("CONST == \"#{CONSTA}\"")
	end
end

def FooObj(&block)
	MyObj.new(&block).putit()
end 

class MyObj
	puts("CONST == \"#{CONSTA}\"")
end

FooObj do 
#	puts("in init BINDIR == \"#{BINDIR}\"")
#	puts("NEWUPPER == \"#{NEWUPPER}\"")
end

module Rakish

config = ProjectConfig.new do |c|
	c.set(:mysym, 121)
end

config2 = ProjectConfig.new(config) do |c|
	puts "### new symbol is #{c.get(:mysym)}"
end

end

