cheerio = require('cheerio')
urlNormalizer = require('./url_normalizer')()

module.exports = class FeedAnalyzer
  constructor: (url, response, xml) ->
    @url = url
    @response = response
    @xml = xml
  
  process: (callback) ->
    console.log "--> Processing feed: #{@url}"
    $ = cheerio.load(@xml, {xmlMode: true})
    
    averageCharsPerItem = @averageCharsPerItem $
    images = @getImagesOf $
    
    properties = {
      url: @url,
      numberOfItems: @itemNodesOf($).length,
      averageCharsPerItem: averageCharsPerItem,
      fullFeed: (averageCharsPerItem > 500),
      imageCount: images.length,
      pixelCount: @pixelCount $,
      averageImageSize: @averageImageSize($),
      youTubeEmbeds: @embeds($, 'youtube.com'),
      vimeoEmbeds: @embeds($, 'vimeo.com'),
      vineEmbeds: @embeds($, 'vine.co')
    }
    
    callback(properties)
  
  averageCharsPerItem: ($) ->
    contentNodes = @contentNodesOf $
    Math.round(contentNodes.text().length / contentNodes.length)
  
  pixelCount: ($) ->
    "Not yet implemented."
  
  averageImageSize: ($) ->
    "Not yet implemented."
    
  embeds: ($, domain) ->
    "Not yet implemented."
    
  getImagesOf: ($) ->
    imagesInItems = @findElementsInContent($, "img")
    
    for i in imagesInItems
      normalized = urlNormalizer.getNormalizedURL(@url, i.attribs.src)
      i.attribs.src = normalized
      
    enclosureSelectors = [
      "enclosure[type^='image']",
      "enclosure[url$='.jpg']",
      "enclosure[url$='.JPG']",
      "enclosure[url$='.jpeg']",
      "enclosure[url$='.JPEG']",
      "enclosure[url$='.gif']",
      "enclosure[url$='.GIF']",
      "enclosure[url$='.png']",
      "enclosure[url$='.PNG']"
    ].join(", ")

    enclosures = $(enclosureSelectors).toArray()
    
    for i in enclosures
      normalized = urlNormalizer.getNormalizedURL(@url, $(enclosures[i]).attr("url"));
      $(enclosures[i]).attr("url", normalized)

    return imagesInItems.concat(enclosures)
  
  findElementsInContent: ($, selector) ->
    return @contentNodesOf($).toArray().map((contentNode) ->
      html = $(contentNode).text()
      return cheerio.load("<wrapper>" + html + "</wrapper>")(selector).toArray()
    ).reduce((memo, elements) ->
      return memo.concat(elements)
    , [])
  
  itemNodesOf: ($) ->
    return $("item, entry")

  contentNodesOf: ($) ->
    return $("encoded, summary, description, content")