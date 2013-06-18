http = require('follow-redirects').http
fs = require('fs')
dispatcher = require('./link_dispatcher')()

filename = process.argv[2]

if filename?
    fs.readFile(filename, 'utf8', (err, data) ->
      csv = null
      
      # DIRTY HACK: make urls a global map
      urls = data.split('\n')
      process.urls = {}
      
      for url in urls
        process.urls[url] = true
      
      for url in Object.keys process.urls
        dispatcher.get url, (properties) ->
          delete process.urls[properties.url]
          
          if !csv?
            csv = Object.keys(properties).join(',') + '\n'
          
          csv += Object.keys(properties).map((key) ->
            properties[key]
          ).join(',') + '\n'    
          
          console.log JSON.stringify(properties)
          if Object.keys(process.urls).length is 0
            file = "./results/rss_scrape_results_#{new Date().getTime()}.csv"
            fs.writeFile(file, csv, (err) ->
              if err?
                console.log err
                console.log "Done, but couldn't save CSV. Here's the data we were trying to save:"
                console.log csv
                process.exit(1)
              else
                console.log "All done. The results were saved into #{file}."
                process.exit(0)
            )
    )
else
  console.log "ERROR: please provide a file to read URLs from."
  process.exit(2)