BUTTON_CLASS = 'popout-for-youtube__button'
HIDDEN_CLASS = "#{BUTTON_CLASS}--hidden"

class Extension

  @openPopout: (video)->
    chrome.extension.sendMessage
      action:       'openPopout'
      videoId:      video.id
      currentTime:  video.currentTime()
      width:        video.width()
      height:       video.height()
      uniqueId:     @uniqueId()

  @uniqueId: ->
    Math.random() ^ new Date().getTime()

  @notifyVideoViewed: ->
    chrome.extension.sendMessage action: 'videoViewed'

class Node

  constructor: (@node)->

  offset: ->
    el = @node
    left = top = 0
    while true
      left += el.offsetLeft
      top  += el.offsetTop
      break unless (el = el.offsetParent)
    left: left
    top:  top

  width: ->
    parseInt @node.offsetWidth

  height: ->
    parseInt @node.offsetHeight

  topRightCorner: ->
    x: @offset().left + @width()
    y: @offset().top

class Video extends Node

  constructor: (@id)->
    @waitForVideoNode().then => super @node

  pause: ->
    @node.pause()

  play: ->
    @node.play()

  currentTime: ->
    @node.currentTime

  seekTo: (time)->
    @node.currentTime = time

  togglePlayback: ->
    if @node.paused then @node.play() else @node.pause()

  waitForVideoNode: ->
    new Promise (resolve)=>
      setInterval =>
        resolve() if @node = document.querySelector('#player video')
      , 100

class Button extends Node

  constructor: (@video)->
    @styleInterval = null
    button             = document.createElement('button')
    button.title       = 'Pop out'
    button.className   = "#{BUTTON_CLASS} #{HIDDEN_CLASS}"
    super button
    @setClickBehavior()
    @maintainStyle()

  setClickBehavior: ->
    @node.addEventListener 'click', (event)=>
      @video.pause()
      Extension.openPopout @video

  setBottomLeftCorner: (point)->
    @node.style.top  = "#{point.y - @height()}px"
    @node.style.left = "#{point.x}px"

  remove: ->
    clearInterval @styleInterval
    @node.parentNode.removeChild @node

  maintainStyle: ->
    @video.waitForVideoNode().then =>
      @styleInterval = setInterval =>
        @setDisplay()
        @setBottomLeftCorner @video.topRightCorner()

  setDisplay: ->
    if @node.style.top == ''
      @node.classList.add HIDDEN_CLASS
    else
      @node.classList.remove HIDDEN_CLASS

class YouTubeVideoPage

  constructor: ->

    @previousVideoId = null

    @whenVideoChanges =>
      try @button.remove() # Can fail if the button isn't arleady there. Ignore.
      @previousVideoId = @newVideoId
      @newVideoId      = @getVideoId()
      @video           = new Video @newVideoId
      @button          = new Button @video

      document.body.appendChild @button.node

      Extension.notifyVideoViewed()

  whenVideoChanges: (callback)->
    setInterval =>
      callback() if @videoChanged()
    , 100

  videoChanged: ->
    @getVideoId() != @previousVideoId

  getVideoId: ->
    new URLSearchParams(document.location.search.substring(1)).get('v')

new YouTubeVideoPage
