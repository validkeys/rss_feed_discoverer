http = require("follow-redirects").http
# TODO - handle https links properly too

FeedAnalyzer = require("./feed_analyzer")
PageAnalyzer = require("./page_analyzer")

module.exports = ->
  get: (url, callback) ->
    data = null
    response = null
    http.request(url, (res) ->
      console.log('got response')
      response = res
      res.on('data', (chunk) ->
        console.log('data')
        data += chunk
      )
      
      res.on('end', ->
        xml = true # TODO - actually determine if it's XML or not.
        
        if xml
          new FeedAnalyzer(url, response, data).process(callback)
        else
          new PageAnalyzer(url, response, data).process(callback)
      )
    ).on('error', (e) ->
      console.log e
    ).end()