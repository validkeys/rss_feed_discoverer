module.exports = class PageAnalyzer
  constructor: (url, response, html) ->
    @url = url
    @response = response
    @html = html
    
  process: (callback) ->
    console.log "--> Processing HTML: #{@url}"
    console.log("Not yet implemented.")
    
    properties = {
      url: @url
    }
    
    callback(properties)