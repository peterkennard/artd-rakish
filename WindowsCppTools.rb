
# module Rakish

	puts "loading module #{__FILE__}";
	Thread.current[:loadReturn] = "a return value from the loaded module";

# end