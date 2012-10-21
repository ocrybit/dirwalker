fs = require('fs')
path = require('path')

async = require('async')
rimraf = require('rimraf')
mkdirp = require('mkdirp')
chai = require('chai')
should = chai.should()
DirWalker = require('../lib/dirwalker')

describe('DirWalker', ->
  TMP = "#{__dirname}/tmp"
  FILTER = ->
  FOO = "#{TMP}/foo"
  FOO2 = "#{TMP}/foo2"
  HOTCOFFEE = "#{TMP}/hot.coffee"
  BLACKCOFFEE = "#{TMP}/black.coffee"
  ICEDCOFFEE = "#{FOO}/iced.coffee"
  TMP_BASE = path.basename(TMP)
  FOO_BASE = path.basename(FOO)
  FOO2_BASE = path.basename(FOO2)
  HOTCOFFEE_BASE = path.basename(HOTCOFFEE)
  BLACKCOFFEE_BASE = path.basename(BLACKCOFFEE)
  ICEDCOFFEE_BASE = path.basename(ICEDCOFFEE)
  dirwalker = new DirWalker()
  stats = {}

  beforeEach((done) ->
    mkdirp(FOO, (err) ->
      async.forEach(
        [HOTCOFFEE, ICEDCOFFEE],
        (v, callback) ->
          fs.writeFile(v, '', (err) ->
            async.forEach(
              [FOO, HOTCOFFEE,ICEDCOFFEE,BLACKCOFFEE],
              (v, callback2) ->
                fs.stat(v, (err,stat) ->
                  stats[v] = stat
                  callback2()
                )
              ->
                callback()
            )
          )
        ->
          dirwalker = new DirWalker(TMP)
          done()
      )
    )
  )

  afterEach((done) ->
    rimraf(TMP, (err) =>
      dirwalker.removeAllListeners()
      done()
    )
  )

  describe('constructor', () ->
    it('init test', () ->
      DirWalker.should.be.a('function')
    )
    it('should instanciate', () ->
      dirwalker.should.be.a('object')
    )
    it('@root should be cwd when not defined', () ->
      dirwalker = new DirWalker()
      dirwalker.root.should.equal(process.cwd())
    )
  )

  describe('_end', () ->
    it("emit 'end' event", (done) ->
      dirwalker.once('end', (data, filestats) ->
        data.should.be.a('object')
        stats.should.be.a('object')
        done()
      )
      dirwalker._end()
    )
  )

  describe('_readEnd', ()->
    it('substruct 1 from @readCount', ->
      dirwalker.readCount = 2
      dirwalker._readEnd(FOO)
      dirwalker.readCount.should.equal(1)
    )
    it('call @_end when @readCount is 0', (done) ->
      dirwalker.readCount = 1
      dirwalker.once('end', () ->
        dirwalker.readCount.should.equal(0)
        done()
      )
      dirwalker._readEnd(FOO)
    )
    it('emit "read" with dirname and stats', (done) ->
      dirwalker.stats[FOO] = {}
      dirwalker.stats[FOO][ICEDCOFFEE] = stats[ICEDCOFFEE]
      dirwalker.once('read', (dir, filestats) ->
        dir.should.equal(FOO)
        filestats.should.eql(dirwalker.stats[FOO])
        done()
      )
      dirwalker._readEnd(FOO)
    )
  )

  describe('_reportFile', ()->
    it('emit "File" event, returning file and stat', (done) ->
      dirwalker.on('File', (file, stat) ->
        file.should.equal(HOTCOFFEE)
        stat.should.equal(stats[HOTCOFFEE])
        done()
      )
      dirwalker._reportFile(HOTCOFFEE, 'File', stats[HOTCOFFEE])
    )
    it('add file to @files', (done) ->
      dirwalker.on('File', (file, stat) ->
        dirwalker.files.File.should.include(HOTCOFFEE)
        done()
      )
      dirwalker._reportFile(HOTCOFFEE, 'File', stats[HOTCOFFEE])
    )
  )

  describe('_readdir', () ->
    it('read a dir and list up files and dirs found in it', (done) ->
      dirwalker.on('end', (data) ->
        data.Directory.should.eql([FOO])
        data.File.should.eql([HOTCOFFEE])
        done()        
      )
      dirwalker._readdir(TMP)
    )
  )

  describe('setFilter',() ->
    it('set a filter function', () ->
      should.not.exist(dirwalker.filter)
      dirwalker.setFilter(FILTER)
      dirwalker.filter.should.be.a.instanceOf(Function)
    )
  )

  describe('getFileType',() ->
    it.only('get a file type from a stat object', () ->
      dirwalker.getFileType(stats[FOO]).should.equal('Directory')
    )
  )

  describe('walk',() ->
    it('return stats of files inside when a directory reading is done', (done) ->
      dirwalker.once('read', (dir, filestats) ->
        dir.should.equal(TMP)
        should.exist(filestats[FOO])
        should.exist(filestats[HOTCOFFEE])
        done()
      )
      dirwalker.walk()
    )
    it('return a list of files and directories when finish walking', (done) ->
      dirwalker.on('end', (data) ->
        data.Directory.should.eql([TMP, FOO])
        data.File.should.eql([HOTCOFFEE, ICEDCOFFEE])
        done()
      )
      dirwalker.walk()
    )
    it('Directory list should be all directories',(done)->
      dirwalker.on('end', (data) ->
        async.forEach(
          data.Directory,
          (v, callback) ->
            fs.stat(v, (err, stat) ->
              stat.isDirectory.should.be.ok
              callback()
            )
          (v)->
            done()
        )
      )
      dirwalker.walk()
    )
    it('file list should be all files',(done)->
      dirwalker.on('end', (data, filestats) ->
        async.forEach(
          data.File,
          (v,callback)=>
            fs.stat(v,(err,stat)->
              stat.isFile.should.be.ok
              callback()
            )
          (v)->
            done()
        )
      )
      dirwalker.walk()
    )
    it('ignore files when @filter function is set', (done) ->
      dirwalker.setFilter((file, stats) ->
        return file is FOO
      )
      dirwalker.on('end', (data) ->
        data.Directory.should.not.include(FOO)
        done()
      )
      dirwalker.walk()
    )
  )
)
