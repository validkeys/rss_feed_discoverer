cheerio = require('cheerio')
URL = require('url')

module.exports = class PageAnalyzer
  constructor: (url, response, html) ->
    @url = url
    @response = response
    @html = html
    
  process: (callback) ->
    console.log "--> Processing HTML: #{@url}"

    $ = cheerio.load(@html)
    
    # Bad URL. Do not proceed.
    if @response.statusCode >= 400
      callback({})
    else
      @checkForLinkTag $
      @queueUpCommonFeedURLs()
      
      callback({})
  
  checkForLinkTag: ($) ->
    tags = $("link[rel='alternate'][type='application/rss+xml'], link[rel='alternate'][type='application/atom+xml']")
    
    for tag in tags
      @processURL(tag.attribs.href)
  
  queueUpCommonFeedURLs: ->
    parsedURL = URL.parse @url
    
    @processURL("#{parsedURL.protocol}//#{parsedURL.host}/rss")
    @processURL("#{parsedURL.protocol}//#{parsedURL.host}/feed")
    
    
  
  # Yuck. I'm just going to leave this atrocity at the very bottom of this file.
  processURL: (urlToProcess) ->
    if process.urlResults[urlToProcess]? or process.urlsInProgress[urlToProcess]?
      console.log "Skipped (already processed or in queue): #{urlToProcess}"
    else
      console.log("Queued: #{urlToProcess}.")
      process.urlsToProcess[urlToProcess] = true