# Based on url_normalizer.js from our chromebot.
module.exports = ->
  getNormalizedURL: (siteURL, urlToNormalize) ->
    result = urlToNormalize
    # Attempt to tidy up the URL to normalize if it appears to not be a full URI
    if urlToNormalize?
      if urlToNormalize.indexOf("http:") isnt 0 and urlToNormalize.indexOf("https:") isnt 0 and urlToNormalize.indexOf("data:") isnt 0
        # Handle feed: and feed:// links.
        if urlToNormalize.indexOf("feed:") is 0
          result = "http://" + urlToNormalize.substring(6)
          result = result.replace("http:////", "http://")
        else if urlToNormalize[0] is "/" and urlToNormalize[1] isnt "/"
          # absolute on server
          result = @pruneURLToBase(siteURL) + urlToNormalize
        else if urlToNormalize[0] is "/" and urlToNormalize[1] is "/"
          # they want us to pick the protocol, so we'll just always pick HTTP.
          result = "http:" + urlToNormalize
        else
          # relative to nearest "path". Chop off "blah.html" if we're at /blah.html, or "ccc" if we're at /aaa/ccc
          result = @pruneURLToNearestPath(siteURL) + "/" + urlToNormalize;
    result

  pruneURLToBase: (url) ->
    # Chop off query parameters and anchors
    normalizedURL = url.split("?")[0].split("#")[0]
    # 3 or more slashes, Chop tokens off until we have the root URL of the site
    tokens = normalizedURL.split("/")
    while tokens.length > 3
      tokens.pop()
      
    return tokens.join("/")

  pruneURLToNearestPath: (url) ->
    # Chop off query parameters and anchors
    normalizedURL = url.split("?")[0].split("#")[0]
    # proto://host/test.html?x=abc#etc
    # 3 or more slashes, chop last token off
    tokens = normalizedURL.split("/")
    if tokens.length > 3
      tokens.pop()
      
    return tokens.join("/")
