request = require('request')
cheerio = require('cheerio')
# TODO - handle https links properly too

FeedAnalyzer = require("./feed_analyzer")
PageAnalyzer = require("./page_analyzer")

module.exports = ->
  get: (url, callback) ->
    url = url.trim()
    if url.length > 0
      response = null
      options = {
        uri: url
        followRedirect: true
        headers: [
          'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_8_4) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/27.0.1453.110 Safari/537.36'
        ]
      }
    
      request(options, (err, response, data) =>
        if err?
          console.log "ERROR: #{err}"
          callback({})
        else
          xml = @isXML(url, response, data)
      
          if xml
            new FeedAnalyzer(url, response, data).process(callback)
          else
            new PageAnalyzer(url, response, data).process(callback)
      )
    else
      callback({})
  
  # Guesses whether this document is an RSS/Atom feed or not.
  isXML: (url, res, data) ->
    $ = cheerio.load(data, {xmlMode: true})
    
    if res.headers['Content-Type'] is "text/xml" then yes
    else if res.headers['Content-Type'] is "application/rss+xml" then yes
    else if $("rss").length > 0 then yes
    else if $("feed").length > 0 then yes
    else if data? and 0 <= data.indexOf("<?xml") <= 10 then yes
    else if url.substring(url.length - 4) is ".xml" then yes
    else if url.substring(url.length - 4) is ".rss" then yes
    else if url.substring(url.length - 5) is ".atom" then yes
    else no