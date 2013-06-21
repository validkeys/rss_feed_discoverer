cheerio = require('cheerio')
imageInfo = require('imageinfo')
request = require('request')
urlNormalizer = require('./url_normalizer')()
opts = require('nomnom').options({
  open: {
    abbr: 'o',
    flag: true,
    default: false,
    help: 'Opens the CSV when done.'
  },
  'no-images': {
    abbr: 'i',
    flag: true,
    default: false
    help: 'Skips fetching images from feeds.'
  },
  'concurrency': {
    abbr: 'c',
    default: 5,
    help: 'Set the number of pages/feeds we load simultaneously.',
  },
  'depth': {
    abbr: 'd',
    default: 3,
    help: 'Set how deep of a chain (maximum) we follow before giving up.'}
}).nom();


module.exports = class FeedAnalyzer
  constructor: (url, depth, response, xml) ->
    @url = url
    @depth = depth
    @response = response
    @xml = xml
  
  process: (callback) ->
    console.log "--> Processing feed: #{@url}"

    if @response.statusCode >= 400
      # Request resulted in an error page - don't try to process this.
      console.log "#{@response.statusCode}: #{@url}"
      callback({})
    else
      $ = cheerio.load(@xml, {xmlMode: true})
    
      averageCharsPerItem = @averageCharsPerItem $
      charsPerItem = @charsPerItem $
      minCharsPerItem = Math.min.apply(Math, charsPerItem)
      maxCharsPerItem = Math.max.apply(Math, charsPerItem)
      
      title = @titleOf($)
      images = @getImagesOf $
    
      # Stop if this RSS feed has a blacklisted title.
      blockedTitles = [
        "comments"
      ]
    
      for blockedTitle in blockedTitles
        if title.toLowerCase().indexOf(blockedTitle) isnt -1
          callback({})
          return
    
      # Process images.
      @pixelCount images, (totalPixelCount) =>
        averageImageDimension = Math.round(Math.sqrt(totalPixelCount / images.length))
      
        if isNaN(averageImageDimension)
          averageImageDimension = 0
      
        # Figure out the rest of the properties.
        properties = {
          url: @url,
          title: title,
          numberOfItems: @itemNodesOf($).length,
          averageCharsPerItem: averageCharsPerItem,
          minCharsPerItem: minCharsPerItem,
          maxCharsPerItem: maxCharsPerItem,
          maxDiffInCharsPerItem: maxCharsPerItem - minCharsPerItem,
          fullFeed: (averageCharsPerItem > 500),
          imageCount: images.length,
          pixelCount: totalPixelCount,
          averageImageSize: averageImageDimension,
          hasDates: @pubDatesOf($).length > 0,
          youTubeEmbeds: @embedsOf($, 'youtube.com').length > 0,
          vimeoEmbeds: @embedsOf($, 'vimeo.com').length > 0,
          vineEmbeds: @embedsOf($, 'vine.co').length > 0,
          atomOrRSS: @atomOrRSS($),
          firstDate: @date($, false),
          lastDate: @date($, true),
        }
    
        callback(properties)
  
  averageCharsPerItem: ($) ->
    contentNodes = @contentNodesOf $
    Math.round(contentNodes.text().length / contentNodes.length)
  
  charsPerItem: ($) ->
    results = []
    contentNodes = @contentNodesOf $
    contentNodes.each (i, node) ->
      results.push $(node).text().length
    
    console.log JSON.stringify(results)
    results
  
  pixelCount: (images, done) ->
    results = []
    # if there are no images return a pixel count of zero immediately
    if images.length is 0 or opts['images'] is false
      done(0)
    else
      # copy images array
      imagesRemaining = images.concat([])
    
      pushResult = (pixelCount) ->
        results.push pixelCount
        if results.length is images.length
          totalPixelCount = results.reduce (memo, p) ->
            if isNaN(p) then p = 0
            return memo + p
          , 0
          done(totalPixelCount)
    
      processImage = (image) ->
        imageURL = image.attribs.src || image.attribs.url
        if imageURL?
          console.log "GET #{imageURL} [image size]"
        
          request({
            uri: imageURL
            encoding: null
          }, (e, r, data) =>
            try
              if e?
                console.log "REQUEST ERROR: #{e}"
                pushResult 0
              else
                info = imageInfo(data)
                imageSize = (info.width || 1) * (info.height || 1)
                pushResult imageSize
          
            catch e # tried looking up info for something that wasn't an image (or something else crazy happened)
              console.log "EXCEPTION: " + e
              pushResult 0
        
            processImage(imagesRemaining.pop()) if imagesRemaining.length > 0
          )
        else
          pushResult 0
          processImage(imagesRemaining.pop()) if imagesRemaining.length > 0
    
      processImage(imagesRemaining.pop()) if imagesRemaining.length > 0

  titleOf: ($) ->
    titleNodes = $("title")
    if titleNodes?
      return titleNodes.first().text()
    else
      return false
  
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
  
  date: ($, last) ->
    itemNodes = @itemNodesOf($)
    
    if last
      return itemNodes.last().find("pubDate, published, updated").text()
    else
      return itemNodes.first().find("pubDate, published, updated").text()
  
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
    return $("encoded, summary, item > description, entry > description, content")
  
  pubDatesOf: ($) ->
    return $("pubDate, published, updated")  
  
  atomOrRSS: ($) ->
    if $("rss") then "RSS"
    else if $("feed") then "Atom"
    else false