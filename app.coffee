http = require('follow-redirects').http
fs = require 'fs'
URL = require 'url'

filename = process.argv[2]

if filename?
    fs.readFile(filename, 'utf8', (err, data) ->
      urls = data.split('\n')
      
      for url in urls
        http.request(url, (res) ->
          console.log JSON.stringify(res.headers)
        ).on('error', (e) ->
          console.log e
        ).end()
    )
else
  console.log "ERROR: please provide a file to read URLs from."
  process.exit(1)