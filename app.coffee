http = require('follow-redirects').http
exec = require('child_process').exec
fs = require('fs')
dispatcher = require('./link_dispatcher')()
opts = require('nomnom').options({
  open: {
    abbr: 'o',
    flag: true,
    default: false,
    help: 'Opens the CSV when done.'
  },
  'no-images': {
    abbr: 'i',
    flag: true,
    help: 'Skips fetching images from feeds.'
  },
  concurrency: {
    abbr: 'c',
    default: 5,
    help: 'Set the number of pages/feeds we load simultaneously.',
  },
  depth: {
    abbr: 'd',
    default: 3,
    help: 'Set how deep of a chain (maximum) we follow before giving up.'
  }
}).nom();

opts.images = true if !opts.images?

# Simultaneous request limit for pages and feeds.
# At most one image request will occur per feed at once.
SIMULTANEOUS_PAGE_REQUEST_LIMIT = opts.concurrency

# Limit the number of pages we'll pass through before stopping (on each path).
process.MAX_DEPTH = opts.depth

filename = process.argv[2]
csv = null

console.log "---------------------------------------------------------------"
console.log "Starting crawler with URLs from #{filename}..."
console.log "Max depth: #{process.MAX_DEPTH}, concurrency: #{SIMULTANEOUS_PAGE_REQUEST_LIMIT}, fetching images: #{opts.images}."
console.log "---------------------------------------------------------------"

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
      
      try
        processNextURL()
      catch e
        # Sometimes we run into a RangeError if our call stack size is not large enough.
        # To get around this, be sure to specify a larger call stack size when invoking Node.
        # See README.md for details.
        console.log "Error encountered: #{e}"
        console.log "This might be unrecoverable, so we're just going to call it quits and attempt to save the csv."
        shouldSave = true
      
      if shouldSave? or (Object.keys(process.urlsToProcess).length is 0 and Object.keys(process.urlsInProgress).length is 0 and not process.saving?)
        saveAsCSV()
    )

saveAsCSV = ->
  process.saving = true

  for properties in Object.keys(process.urlResults)
    if Object.keys(process.urlResults[properties]).length > 1
      if !csv?
        csv = Object.keys(process.urlResults[properties]).join(',') + '\n'

      csv += Object.keys(process.urlResults[properties]).map((key) ->
        if typeof process.urlResults[properties][key] is "string"
          process.urlResults[properties][key].replace(/[,\n]/g, " ")
        else
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
      if opts.open
        console.log "Opening #{file}..."
        exec("open #{file}")
      process.exit(0)
  )