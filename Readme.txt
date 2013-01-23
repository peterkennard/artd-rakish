This directory is called "Make" mainly for traditional reasons but i am including  
ruby and "rake" files as the overall control system because it is more flexible and 
programmable than make.

configurations for building.

A sample of a configuration type name passed into rakefiles and used
for the names of configurations in generated MSVC projects.

The symbols are separated by dashes in one large "word".

[host]-[compiler]-[linkage type]-[debug type]

ie:

Win32-VC8-MT-Debug
Win64-VC8-MD-Debug
Win32-VC7-MT-Release
Linux32-GCC3-Dynamic-Debug

etc

PK
