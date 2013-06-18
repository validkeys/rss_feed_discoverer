http = require('follow-redirects').http
fs = require 'fs'
dispatcher = require('./link_dispatcher')()

filename = process.argv[2]

if filename?
    fs.readFile(filename, 'utf8', (err, data) ->
      # DIRTY HACK: make urls a global map
      urls = data.split('\n')
      process.urls = {}
      
      for url in urls
        process.urls[url] = true
      
      for url in Object.keys process.urls
        dispatcher.get url, (properties) ->
          delete process.urls[properties.url]
          console.log JSON.stringify(properties)
          if Object.keys(process.urls).length is 0
            console.log("All done.")
            # TODO - save results
            process.exit(0)
    )
else
  console.log "ERROR: please provide a file to read URLs from."
  process.exit(1)