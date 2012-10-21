# * Recursively walk through directories
# * Emit and execute a given callback function every time a file is found
# * Ignore files with a filter function

# ---

# ### Require Dependencies

# #### Standard Node Modules
# `fs` : [File System](http://nodejs.org/api/fs.html)  
# `path` : [Path](http://nodejs.org/api/path.html)  
# `events` : [Events](http://nodejs.org/api/events.html)  
fs = require('fs')
path = require('path')
EventEmitter = require('events').EventEmitter

# #### Third Party Modules
# `async` by [Caolan McMahon@caolan](https://github.com/caolan/async)  
async = require('async')

# ---

# ## DirWalker Class
module.exports = class DirWalker extends EventEmitter

  # ### Class Properties
  # `@root (String)` : the root path to start walking  
  # `@filter (Function)` : a filter `Function` to test if file should be ignored  
  # `@files (Object)` : a list of found files of each file type  
  # `@readCount (Number)` : a count to keep track of async readdir processes  
  # `@FILE_TYPES (Array)` : possible file types  

  # ### Events
  # `end` : end `@walk()`  
  # `Directory` : found a directory  
  # `File` : found a file  
  # `BlockDevice` : found a block device  
  # `FIFO` : found a FIFO  
  # `Socket` : found a socket  
  # `CharacterDevice` : found a character device  
  # `SymbolicLink` : found a symbolic link
  # 'Unknown' : found a file of unknown type
  # `nofile` : no file exists at the given `@root` path  
  # `not dir` : `@root` is not a directory
  # `read` : finish reading all the files inside a directory

  # #### constructor
  # `@root ()` : see *Class Properties* section  
  constructor:(@root = process.cwd()) ->
    @files = {}
    @stats = {}
    @readCount = 0
    @FILE_TYPES = ['File', 'Directory', 'BlockDevice', 'FIFO', 'Socket', 'CharacterDevice', 'SymbolicLink']

  # ---

  # ### Private Methods
 
  # #### End directory walking operation
  _end: () ->
    flatstats = {}
    #flatten @stats
    for k, v of @stats
      for k2, v2 of v
        flatstats[k2] = v2
    # Emit `end` event
    @emit('end', @files, flatstats)

  # #### When finish reading a directory, check if the whole walking (the other async processes) is done
  _readEnd: (dir) ->
    @emit('read', dir, @stats[dir])
    # -1 for the ended `@readdir()` process
    @readCount -= 1
    # If `@readCount` is `0`, there is no running process left
    if @readCount is 0
      @_end()

  # #### Report a found file
  # `file (String)` : a file found  
  # `stat (Object)` : a stat object for the file 
  _reportFile: (file, type, stat) ->
    @files[type] ?= []
    @files[type]?.push(file)
    @emit(type, file, stat)
    if type is 'Directory'
      # +1 for a new `@readdir()` process to be launched below
      @readCount += 1
      # Recursively read directory
      @_readdir(file)

  # #### Read a directory and emit events when files (including directories) are found
  # `dir (String)` : a directory path to read
  _readdir: (dir) ->
    @stats[dir] = {}
    fs.readdir(dir, (err, files) =>
      if err
        @files = v for v in @files when v isnt dir
        @_readEnd(dir)
      else
        # Asyncronously read directories by keeping `@readCount`
        async.forEach(
          files
          (file, callback) =>
            #The full path to `file`
            filepath = path.join(dir, file)
            # Get `file` stats
            fs.lstat(filepath, (err, stat) =>
                # Check if `filepath` should be ignored
                if err or @filter?(filepath, stat)
                  callback()
                else
                  @stats[dir][filepath] = stat
                  type = @getFileType(stat)
                  if type
                    @_reportFile(filepath, type, stat)
                  else 
                    @emit('Unknown', filepath, stat)
                  callback()
            )
          =>
            # Finish reading `dir`
            @_readEnd(dir)
        )
    )

  # ---

  # ### Public API

  # #### Get a file type
  # `stat (Object)` : a stat object
  getFileType: (stat) ->
    for v in @FILE_TYPES
      if stat["is#{v}"]()
        return v
    return false
  
  # #### Set a filter function
  # `fn (Function)` : a filter `Function`
  setFilter: (fn) ->
    if typeof(fn) is 'function'
      @filter = fn

  # #### Start resursively walking down directories
  walk:() ->
    # Get `@root` file stats
    fs.lstat(@root, (err, stat) =>
      # If `@root` doesn't exist, or should be ignored, abort by emitting `nofile` event
      if err or @filter?(@root, stat)
        @emit('nofile', err)
        @_end()
      # If `@root` isn't a directory, abort by emitting `not dir` event
      else if not stat.isDirectory()
        @emit('not dir', @root, stat)
        @_end()
      # Otherwise `@_reportFile()` and recursively keep walking
      else
        @_reportFile(@root, 'Directory', stat)
    )

