http = require('follow-redirects').http
fs = require 'fs'
dispatcher = require('./link_dispatcher')()

filename = process.argv[2]

if filename?
    fs.readFile(filename, 'utf8', (err, data) ->
      urls = data.split('\n')
      
      for url in urls
        dispatcher.get url
    )
else
  console.log "ERROR: please provide a file to read URLs from."
  process.exit(1)