http = require("follow-redirects").http
cheerio = require('cheerio')
# TODO - handle https links properly too

FeedAnalyzer = require("./feed_analyzer")
PageAnalyzer = require("./page_analyzer")

module.exports = ->
  get: (url, callback) ->
    data = null
    response = null
    http.request(url, (res) =>
      response = res
      
      res.on('data', (chunk) ->
        data += chunk
      )
      
      res.on('end', =>
        xml = @isXML(url, res, data)
        
        if xml
          new FeedAnalyzer(url, response, data).process(callback)
        else
          new PageAnalyzer(url, response, data).process(callback)
      )
    ).on('error', (e) ->
      console.log e
    ).end()
  
  # Guesses whether this document is an RSS/Atom feed or not.
  isXML: (url, res, data) ->
    $ = cheerio.load(data, {xmlMode: true})
    
    if res.headers['Content-Type'] is "text/xml" then yes
    else if res.headers['Content-Type'] is "application/rss+xml" then yes
    else if $("rss") then yes
    else if $("feed") then yes
    else if data.indexOf("<?xml") <= 10 then yes
    else if url.substring(url.length - 4) is ".xml" then yes
    else if url.substring(url.length - 4) is ".rss" then yes
    else if url.substring(url.length - 5) is ".atom" then yes
    else no