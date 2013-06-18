module.exports = class FeedAnalyzer
  constructor: (url, response, xml) ->
    @url = url
    @response = response
    @xml = xml
  
  process: (callback) ->
    console.log("Processing feed!")
    properties = {
      url: @url
    }
    
    callback(properties)