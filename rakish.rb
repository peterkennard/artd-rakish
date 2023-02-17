toAdd = "#{File.dirname(__FILE__)}/lib";
$LOAD_PATH.unshift(toAdd) unless $LOAD_PATH.include?(toAdd);

require("#{toAdd}/rakish');
