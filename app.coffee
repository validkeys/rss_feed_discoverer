http = require('follow-redirects').http
fs = require('fs')
dispatcher = require('./link_dispatcher')()

SIMULTANEOUS_REQUEST_LIMIT = 15

filename = process.argv[2]
csv = null
    

if filename?
  fs.readFile(filename, 'utf8', (err, data) ->
    csv = null
    
    # DIRTY HACK: make urls a global map
    urls = data.split('\n')
    process.urlsToProcess = {}
    process.urlsInProgress = {}
    
    for url in urls
      process.urlsToProcess[url] = true
    
    for i in [1..SIMULTANEOUS_REQUEST_LIMIT]
      processNextURL()
  )
else
  console.log "ERROR: please provide a file to read URLs from."
  process.exit(2)
  
processNextURL = ->
  urls = Object.keys(process.urlsToProcess)
  if urls.length > 0
    url = urls[0]
    delete process.urlsToProcess[url]
    process.urlsInProgress[url] = true
  
    dispatcher.get(url, (properties) =>
      delete process.urlsInProgress[url]
      processNextURL()
      
      if Object.keys(properties).length > 0
        if !csv?
          csv = Object.keys(properties).join(',') + '\n'
    
        csv += Object.keys(properties).map((key) ->
          properties[key]
        ).join(',') + '\n'
    
        console.log JSON.stringify(properties)
      
      if Object.keys(process.urlsInProgress).length is 0 and Object.keys(process.urlsToProcess).length is 0
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