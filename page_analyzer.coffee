cheerio = require('cheerio')
URL = require('url')
urlNormalizer = require('./url_normalizer')()

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
      @queueCommonFeedURLs()
      @queuePotentialFeedLinks $
      
      callback({})
  
  # Checks for the RSS HTML tag, like many web browsers do.
  # This is a VERY reliable signal.
  checkForLinkTag: ($) ->
    tags = $("link[rel='alternate'][type='application/rss+xml'], link[rel='alternate'][type='application/atom+xml']")
    
    for tag in tags
      @processURL(tag.attribs.href)
  
  # Queues up feed URLs that are common with WordPress, etc.
  queueCommonFeedURLs: ->
    parsedURL = URL.parse @url
    
    paths = [
      "/rss",
      "/feed"
    ]
    
    for path in paths
      @processURL("#{parsedURL.protocol}//#{parsedURL.host}#{path}")


  # Analyzes the HTML and queues any links that might be either RSS feeds themselves
  # or links to pages that may then link to RSS feeds.
  queuePotentialFeedLinks: ($) ->
    selectors = [
      # Catches URLs ending in .xml and .rss, and potentially many others.
      "a[href*='xml']",
      "a[href*='rss']",
      
      # Catches all FeedBurner URLs in addition to pages containing links to feeds.
      # I've seen FeedBurner use these domains:
      #   feeds.feedburner.com
      #   feeds2.feedburner.com
      #   feedproxy.google.com
      "a[href*='feed']",
    ].join(', ')
    
    $(selectors).each (index, element) =>
      @processURL(urlNormalizer.getNormalizedURL(@url, element.attribs.href))
  
  
  
  # Yuck. I'm just going to leave this atrocity at the very bottom of this file.
  processURL: (urlToProcess) ->
    if process.urlResults[urlToProcess]? or process.urlsInProgress[urlToProcess]?
      console.log "Skipped (already processed or in queue): #{urlToProcess}"
    else
      console.log("Queued: #{urlToProcess}.")
      process.urlsToProcess[urlToProcess] = true