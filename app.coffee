exec = require('child_process').exec
fs = require('fs')
LinkDispatcher = require('./link_dispatcher')
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
}).nom()


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
    
    urls = data.split('\n')
    @urlsToProcess = {}
    @urlsInProgress = {}
    @urlResults = {}
    
    for url in urls
      @urlsToProcess[url] = { depth: 0 }
      
    @dispatcher = new LinkDispatcher(@urlsToProcess, @urlsInProgress, @urlResults)
    
    for i in [1..SIMULTANEOUS_PAGE_REQUEST_LIMIT]
      processNextURL()
  )
else
  console.log "ERROR: please provide a file to read URLs from."
  process.exit(2)
  


processNextURL = ->
  urls = Object.keys(@urlsToProcess)
  if urls.length > 0
    url = urls[0]
    @urlsInProgress[url] = { depth: @urlsToProcess[url].depth }
    delete @urlsToProcess[url]
    
    @dispatcher.get(url, @urlsInProgress[url].depth, (properties) =>
      @urlResults[url] = properties
      @urlResults[url].depth = @urlsInProgress[url].depth
      delete @urlsInProgress[url]
    
      try
        processNextURL()
      catch e
        # Sometimes we run into a RangeError if our call stack size is not large enough.
        # To get around this, be sure to specify a larger call stack size when invoking Node.
        # See README.md for details.
        # TODO - I don't recall if this actually catches anything. The error that occurs seems to be uncatchable.
        console.log "Error encountered: #{e}"
        console.log "This might be unrecoverable, so we're just going to call it quits and attempt to save the csv."
        shouldSave = true
    
      if shouldSave? or (Object.keys(@urlsToProcess).length is 0 and Object.keys(@urlsInProgress).length is 0 and not process.saving?)
        saveAsCSV()
    )

saveAsCSV = ->
  process.saving = true

  for properties in Object.keys(@urlResults)
    if Object.keys(@urlResults[properties]).length > 1
      if !csv?
        csv = Object.keys(@urlResults[properties]).join(',') + '\n'

      csv += Object.keys(@urlResults[properties]).map((key) ->
        if typeof @urlResults[properties][key] is "string"
          @urlResults[properties][key].replace(/[,\n]/g, " ")
        else
          @urlResults[properties][key]
      ).join(',') + '\n'
  
  file = "./results/rss_scrape_results_#{new Date().getTime()}.csv"
  fs.writeFile(file, csv, (err) ->
    if err?
      # Write failed, but we've done all our processing so we'll output the CSV data to STDOUT
      # (so we don't have to start over)
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