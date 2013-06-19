cheerio = require('cheerio')
imageInfo = require('imageinfo')
request = require('request')
urlNormalizer = require('./url_normalizer')()

module.exports = class FeedAnalyzer
  constructor: (url, depth, response, xml) ->
    @url = url
    @depth = depth
    @response = response
    @xml = xml
  
  process: (callback) ->
    console.log "--> Processing feed: #{@url}"
    $ = cheerio.load(@xml, {xmlMode: true})
    
    averageCharsPerItem = @averageCharsPerItem $
    images = @getImagesOf $
    
    @pixelCount images, (totalPixelCount) =>
      averageImageDimension = Math.round(Math.sqrt(totalPixelCount / images.length))
      
      if isNaN(averageImageDimension)
        averageImageDimension = 0
        
      properties = {
        url: @url,
        numberOfItems: @itemNodesOf($).length,
        averageCharsPerItem: averageCharsPerItem,
        fullFeed: (averageCharsPerItem > 500),
        imageCount: images.length,
        pixelCount: totalPixelCount,
        averageImageSize: averageImageDimension,
        hasDates: @pubDatesOf($).length > 0,
        youTubeEmbeds: @embedsOf($, 'youtube.com').length > 0,
        vimeoEmbeds: @embedsOf($, 'vimeo.com').length > 0,
        vineEmbeds: @embedsOf($, 'vine.co').length > 0,
        atomOrRSS: @atomOrRSS($)
      }
    
      callback(properties)
  
  averageCharsPerItem: ($) ->
    contentNodes = @contentNodesOf $
    Math.round(contentNodes.text().length / contentNodes.length)
  
  pixelCount: (images, done) ->
    results = []
    
    # if there are no images return a pixel count of zero immediately
    if images.length is 0
      done(0)
    
    pushResult = (pixelCount) ->
      results.push pixelCount
      if results.length is images.length
        totalPixelCount = results.reduce (memo, p) ->
          if isNaN(p) then p = 0
          return memo + p
        , 0
        done(totalPixelCount)
    
    for image in images
      request({
        uri: image.attribs.src
        encoding: null
      }, (e, r, data) =>
        try
          info = imageInfo(data)
          imageSize = (info.width || 1) * (info.height || 1)
          console.log "[image size] (#{image.attribs.src}): #{info.width || 1} x #{info.height || 1} = #{imageSize}"
          pushResult imageSize
          
        catch e # tried looking up info for something that wasn't an image (or something else crazy happened)
          console.log "EXCEPTION: " + e
          pushResult 0
      )
  
  embedsOf: ($, domain) ->
    return @findElementsInContent($, "iframe[src*='" + domain + "'], embed[src*='" + domain + "'], script[src*='" + domain + "']")
      
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
  
  pubDatesOf: ($) ->
    return $("pubDate, published, updated")  
  
  atomOrRSS: ($) ->
    if $("rss") then "RSS"
    else if $("feed") then "Atom"
    else false