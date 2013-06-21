request = require('request')
cheerio = require('cheerio')
URL = require('url')

FeedAnalyzer = require("./feed_analyzer")
PageAnalyzer = require("./page_analyzer")

module.exports = class LinkDispatcher
  constructor: (urlsToProcess, urlsInProgress, urlResults) ->
    @urlsToProcess = urlsToProcess
    @urlsInProgress = urlsInProgress
    @urlResults = urlResults
    
  get: (url, depth, callback) ->
    url = url.trim()
    if url.length > 0 and depth <= process.MAX_DEPTH and not @blocked(url)
      response = null
      options = {
        uri: url
        followRedirect: true
        headers: [
          'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_8_4) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/27.0.1453.110 Safari/537.36'
        ],
        timeout: 30000
      }
    
      console.log "GET #{url} [page or feed]"
      request(options, (err, response, data) =>
        if err?
          console.log "ERROR: #{err}"
          callback({})
        else
          xml = @isXML(url, response, data)
    
          if xml
            new FeedAnalyzer(url, depth, response, data).process(callback)
          else
            new PageAnalyzer(url, depth, response, data, @urlsToProcess, @urlsInProgress, @urlResults).process(callback)
      )
    else
      callback({})
  
  # Guesses whether this document is an RSS/Atom feed or not.
  isXML: (url, res, data) ->
    data = data.toLowerCase()
    $ = cheerio.load(data, {xmlMode: true})
    
    if res.headers['Content-Type'] is "text/xml" then yes
    else if res.headers['Content-Type'] is "application/rss+xml" then yes
    else if $("rss").length > 0 then yes
    else if $("feed").length > 0 then yes
    else if data? and 0 <= data.indexOf("<?xml") <= 10 and data.indexOf("doctype") is -1 and data.indexOf("xhtml") is -1 then yes
    else if url.substring(url.length - 4) is ".xml" then yes
    else if url.substring(url.length - 4) is ".rss" then yes
    else if url.substring(url.length - 5) is ".atom" then yes
    else no
  
  # Prevent common false-positives.
  blocked: (url) ->
    parsedURL = URL.parse(url)
    
    blockedDomains = [
      "feedly.com",
      "feedreader.com",
      "icopyright.net",
      "add.my.yahoo.com",
      "fusion.google.com"
    ]
    
    blockedKeywords = [
      "comments",
      "forum"
    ]
    
    for domain in blockedDomains
      if parsedURL.hostname? and parsedURL.hostname.toLowerCase().indexOf(domain) isnt -1
        return true
    
    for keyword in blockedKeywords
      return true if url.toLowerCase().indexOf(keyword) isnt -1
  
    false