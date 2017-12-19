DirWalker
=========

A directory tree walker that broadcasts event as files are found.

Installation
------------

    sudo npm install dirwalker
	
Usage
-----

    # a temp directory for this example  
	TMP = "#{__dirname}/tmp"
	
	DirWalker = require('dirwalker')
	
	#instantiate with the root path to start walking from
	dirwalker = new DirWalker(TMP)
	
	# set up some listeners
	dirwalker.on('File', (filepath, stat) ->
	  console.log("File: #{filepath} is found!")
	)
	
	dirwalker.on('Directory', (filepath, stat) ->
	  console.log("Directory: #{filepath} is found!")
	)
	
	# start the walking process
	dirwalker.walk()

File Types
----------

7 file types are supported and DirWalker emits corresponding events.  

Note those event names are capitalized.  

`File` `Directory` `BlockDevice` `FIFO` `Socket` `CharacterDevice` `SymbolicLink`

Other file types will still be found and marked `Unknown`.  

Listener functions will have `filepath` and `stats` from `fs.lstat()`

   	dirwalker.on('File', (filepath, stat) ->
	  console.log("FilePath: #{filepath}")
	  console.log("Stats: #{stats}")	  
	)


Events
------

In addition to the 8 file found events above, DirWalker broadcasts the following events as well.


When the whole walking is done, it emits "end" with an object that contains lists of all the files found under each file type as a key.  
It also gives stats of all the files found during the walking operation.

	dirwalker.on('end', (data, stats) ->
	  # list all the files found
	  console.log(data.File)
	  
	  # list all the symbolic links found
	  console.log(data.SymbolicLink)
	  
	  for filepath, stat of stats
	    console.log("Stats for #{filepath}")
	    console.log(stat)	  
	)

  
When all the files inside a directory are read, it emits "read" with the directory path and an object that contains all the stats of the inside files from fs.lstat.

	dirwalker.on('read', (dir, stats) ->
	  console.log("#{dir} has been read!")
	  for filepath, stat of stats
	    console.log("Stats for #{filepath}")
	    console.log(stat)
	)

  
If the given root directory doesn't exist, the walking operation cannot be initiated.

	dirwalker.on('nofile', (err) ->
	  console.log(err)
	)

  
If the given root is not a directory, the walking operation still cannot be initiated.

	dirwalker.on('not dir', (filepath, stats) ->
	  console.log("#{filepath} is not a directory!")
	  console.log(stats)
	)

Filter Function
---------------

A filter function can be set to ignore files and directories. If a directory is ignored, DirWalker doesn't go into that directory, so the sub contents under the directorey are all ignored, thus unreported.

	dirwalker.setFilter((filepath, stat) ->
	  return filepath is "#{TMP}/ignore.coffee"
	)
    
Running Tests
-------------

Run tests with [mocha](http://mochajs.org/)

    make
	

License
-------
**DirWalker** is released under the **MIT License**. - see [LICENSE](https://raw.github.com/tomoio/dirwalker/master/LICENSE) file
