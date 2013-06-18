cheerio = require('cheerio')

module.exports = class FeedAnalyzer
  constructor: (url, response, xml) ->
    @url = url
    @response = response
    @xml = xml
  
  process: (callback) ->
    console.log "--> Processing feed: #{@url}"
    $ = cheerio.load(@xml, {xmlMode: true})
    
    averageCharsPerItem = @averageCharsPerItem($)
    
    properties = {
      url: @url,
      numberOfItems: @itemNodesOf($).length,
      averageCharsPerItem: averageCharsPerItem,
      fullFeed: (averageCharsPerItem > 500),
      imageCount: @imageCount($),
      pixelCount: @pixelCount($),
      averageImageSize: @averageImageSize($),
      youTubeEmbeds: @embeds($, 'youtube.com'),
      vimeoEmbeds: @embeds($, 'vimeo.com'),
      vineEmbeds: @embeds($, 'vine.co')
    }
    
    callback(properties)
  
  averageCharsPerItem: ($) ->
    contentNodes = @contentNodesOf $
    Math.round(contentNodes.text().length / contentNodes.length)
    
  imageCount: ($) ->
    "Not yet implemented."
  
  pixelCount: ($) ->
    "Not yet implemented."
  
  averageImageSize: ($) ->
    "Not yet implemented."
    
  embeds: ($, domain) ->
    "Not yet implemented."
    
  
  itemNodesOf: ($) ->
    return $("item, entry")

  contentNodesOf: ($) ->
    return $("encoded, summary, description, content")