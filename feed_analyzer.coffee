cheerio = require('cheerio')

module.exports = class FeedAnalyzer
  constructor: (url, response, xml) ->
    @url = url
    @response = response
    @xml = xml
  
  process: (callback) ->
    console.log "--> Processing feed: #{@url}"
    $ = cheerio.load(@xml)
    
    averageCharsPerItem = @averageCharsPerItem($)
    
    properties = {
      url: @url,
      numberOfItems: @itemNodesOf($).length,
      averageCharsPerItem: averageCharsPerItem,
      fullFeed: (averageCharsPerItem > 5000),
      imageCount: @imageCount($),
      pixelCount: @pixelCount($),
      averageImageSize: @averageImageSize($),
      youTubeEmbeds: @embeds($, 'youtube.com'),
      vimeoEmbeds: @embeds($, 'vimeo.com'),
      vineEmbeds: @embeds($, 'vine.co')
    }
    
    callback(properties)
  
  averageCharsPerItem: ($) ->
    "Not yet implemented."
    
  imageCount: ($) ->
    "Not yet implemented."
  
  pixelCount: ($) ->
    "Not yet implemented."
  
  averageImageSize: ($) ->
    "Not yet implemented."
    
  embeds: ($, domain) ->
    "Not yet implemented."
  
  
  itemNodesOf: ($) ->
    return $("item, atom\\:entry, entry")
  
  contentNodesOf: ($) ->
    return $("content\\:encoded, atom\\:summary, description, atom\\:content, summary, content")