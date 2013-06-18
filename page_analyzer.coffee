cheerio = require('cheerio')

module.exports = class PageAnalyzer
  constructor: (url, response, html) ->
    @url = url
    @response = response
    @html = html
    
  process: (callback) ->
    console.log "--> Processing HTML: #{@url}"
    console.log("Not yet implemented.")
    
    $ = cheerio.load(@html)
    
    @checkForLinkTag $
    
    callback({})
  
  checkForLinkTag: ($) ->
    tags = $("link[rel='alternate'][type='application/rss+xml'], link[rel='alternate'][type='application/atom+xml']")
    
    for tag in tags
      console.log("Queuing up #{tag.attribs.href}.")
      @processURL(tag.attribs.href)
  
  
  
  # Yuck. I'm just going to leave this atrocity at the very bottom of this file.
  processURL: (urlToProcess) ->
    process.urls[urlToProcess] = true
  
  