http = require('follow-redirects').http
exec = require('child_process').exec
fs = require('fs')
dispatcher = require('./link_dispatcher')()
opts = require('nomnom')
  .option('open', {
    abbr: 'o',
    flag: true,
    help: 'Opens the CSV when done.'
  })
  .option('no-images', {
    abbr: 'i',
    flag: true,
    help: 'Skips fetching images from feeds.'
  }).parse();

# Simultaneous request limit for pages and feeds.
# At most one image request will occur per feed at once.
SIMULTANEOUS_PAGE_REQUEST_LIMIT = 5

# Limit the number of pages we'll pass through before stopping (on each path).
process.MAX_DEPTH = 3

filename = process.argv[2]
csv = null

if filename?
  fs.readFile(filename, 'utf8', (err, data) ->
    csv = null
    
    # DIRTY HACK: use globals to keep track of progress of URL processing
    urls = data.split('\n')
    process.urlsToProcess = {}
    process.urlsInProgress = {}
    process.urlResults = {}
    
    for url in urls
      process.urlsToProcess[url] = { depth: 0 }
    
    for i in [1..SIMULTANEOUS_PAGE_REQUEST_LIMIT]
      processNextURL()
  )
else
  console.log "ERROR: please provide a file to read URLs from."
  process.exit(2)
  
processNextURL = ->
  urls = Object.keys(process.urlsToProcess)
  if urls.length > 0
    url = urls[0]
    process.urlsInProgress[url] = { depth: process.urlsToProcess[url].depth }
    delete process.urlsToProcess[url]
  
    dispatcher.get(url, process.urlsInProgress[url].depth, (properties) =>
      process.urlResults[url] = properties
      process.urlResults[url].depth = process.urlsInProgress[url].depth
      delete process.urlsInProgress[url]
      
      processNextURL()
      
      if Object.keys(process.urlsToProcess).length is 0 and Object.keys(process.urlsInProgress).length is 0 and not process.saving?
        saveAsCSV()
    )

saveAsCSV = ->
  process.saving = true

  for properties in Object.keys(process.urlResults)
    if Object.keys(process.urlResults[properties]).length > 1
      if !csv?
        csv = Object.keys(process.urlResults[properties]).join(',') + '\n'

      csv += Object.keys(process.urlResults[properties]).map((key) ->
        process.urlResults[properties][key]
      ).join(',') + '\n'
  
  file = "./results/rss_scrape_results_#{new Date().getTime()}.csv"
  fs.writeFile(file, csv, (err) ->
    if err?
      console.log err
      console.log "Done, but couldn't save CSV. Here's the data we were trying to save:"
      console.log csv
      process.exit(1)
    else
      console.log "All done. The results were saved into #{file}."
      if opts.open?
        console.log "Opening #{file}..."
        exec("open #{file}")
      process.exit(0)
  )