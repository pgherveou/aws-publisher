path   = require 'path'
fs     = require 'fs'
zlib   = require 'zlib'
crypto = require 'crypto'
knox   = require 'knox'
mime   = require 'mime'
async  = require 'async'
moment = require 'moment'
{walk} = require 'findr'

# default expires header set to year + 10
expireDate = moment().add('years', 10).format('ddd, DD MMM YYYY') + " 12:00:00 GMT"

module.exports =

  class Publisher

    constructor: (config) ->
      @client = knox.createClient config

    publishDir: ({origin, dest, filter}, cb)  ->

      # set default filter
      filter or= -> true

      # convert origin folder to absolute
      origin = path.join path.resolve(origin)
      console.log "uploading new files from '#{origin}' to '#{dest}'"

      walk origin, filter, (err, fileItems) =>
        return console.error err if err
        files = (file for file, stat of fileItems when stat.isFile())

        # create a task queue to upload file
        q = async.queue @publish, 2
        q.drain =  ->
          console.log "All files were uploaded"
          cb()

        files.forEach (file) =>
          filename = file.replace origin, dest
          q.push {file, filename}, (err) -> if err then console.error "[Error] uploading #{filename}", err.statusCode

    publish: ({file, filename}, cb) =>

      async.waterfall [

        # readfile
        (cb) -> fs.readFile file, cb

        # zip text files and set headers
        (buf, cb) ->
          if  /\.(css|js)$/.test file
            zlib.gzip buf, (err, zip) ->
              return cb new Error "Error zipping #{file}" if err
              cb null, zip, {'Content-Encoding': 'gzip'}

          else
            cb null, buf, {}

        # put file to s3
        (buf, headers, cb) =>

          # add headers
          headers['Expires']        = expireDate
          headers['Content-Type']   = mime.lookup file
          headers['Content-Length'] = buf.length
          headers['x-amz-acl']      = 'public-read'

          @client.headFile filename, (err, res) =>
            return cb err if err
            md5 = '"' + crypto.createHash('md5').update(buf).digest('hex') + '"'
            if md5 is res.headers.etag
              console.log "[skip]    #{filename}"
              return cb null
            else if res.headers.etag
              console.log "[UPDATE]  #{filename}"
            else
              console.log "[ADD]     #{filename}"

            req  = @client.put filename, headers
            req.on 'response', (res) ->
              return cb() if 199 < res.statusCode < 299
              cb res

            req.end(buf)
      ], cb
