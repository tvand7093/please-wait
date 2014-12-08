((root, factory) ->
  if typeof exports is "object"
    # CommonJS
    factory exports
  else if typeof define is "function" and define.amd
    # AMD. Register as an anonymous module.
    define ["exports"], factory
  else
    # Browser globals
    factory root
  return
) this, (exports) ->
  getTransitionEvent = ->
    el = document.createElement('fakeelement')
    transitions =
      'WebkitAnimation': 'webkitAnimationEnd',
      'OAnimation': 'oAnimationEnd',
      'msAnimation': 'MSAnimationEnd',
      'MozAnimation': 'mozAnimationEnd'
      'animation' : 'animationend'

    for key, val of transitions
      return val if el.style[key]?

  transitionEvent = getTransitionEvent()

  class PleaseWait
    @_defaultOptions:
      backgroundColor: null
      logo: null
      loadingHtml: null
      template: """
        <div class='pg-loading-inner'>
          <div class='pg-loading-center-outer'>
            <div class='pg-loading-center-middle'>
              <h1 class='pg-loading-logo-header'>
                <img class='pg-loading-logo'></img>
              </h1>
              <div class='pg-loading-html'>
              </div>
            </div>
          </div>
        </div>
      """

    constructor: (options) ->
      defaultOptions = @constructor._defaultOptions
      @options = {}

      # Set initial options, merging given options with the defaults
      for k, v of defaultOptions
        @options[k] = if options[k]? then options[k] else v

      # Create the loading screen element
      @_loadingElem = document.createElement("div")
      # Create an empty array to store the potential list of loading HTML (messages, spinners, etc)
      # we'll be displaying to the screen
      @_loadingHtmlToDisplay = []
      # Add a global class for easy styling
      @_loadingElem.className = "pg-loading-screen"
      # Set the background color of the loading screen, if supplied
      @_loadingElem.style.backgroundColor = @options.backgroundColor if @options.backgroundColor?
      # Initialize the loading screen's HTML with the defined template. The default can be overwritten via options
      @_loadingElem.innerHTML = @options.template
      # Find the element that will contain the loading HTML displayed to the user (typically a spinner/message)
      # This can be changed via updateLoadingHtml
      @_loadingHtmlElem = @_loadingElem.getElementsByClassName("pg-loading-html")[0]
      # Set the initial loading HTML, if supplied
      @_loadingHtmlElem.innerHTML = @options.loadingHtml if @_loadingHtmlElem?
      # Set a flag that lets us know if the transitioning between loading HTML elements is finished.
      # If true, we can transition immediately to a new message/HTML
      @_readyToShowLoadingHtml = false
      # Find the element that displays the loading logo and set the src if supplied
      @_logoElem = @_loadingElem.getElementsByClassName("pg-loading-logo")[0]
      @_logoElem.src = @options.logo if @_logoElem?
      # Add the loading screen to the body
      document.body.appendChild(@_loadingElem)
      # Add the CSS class that will trigger the initial transitions of the logo/loading HTML
      @_loadingElem.className += " pg-loading"

      # Define a listener to look for any new loading HTML that needs to be displayed after the intiial transition finishes
      listener = =>
        @_readyToShowLoadingHtml = true
        if transitionEvent? then @_loadingHtmlElem.removeEventListener(transitionEvent, listener)
        if @_loadingHtmlToDisplay.length > 0 then @_changeLoadingHtml()

      if @_loadingHtmlElem?
        # Detect CSS animation support. If not found, we'll call the listener immediately. Otherwise, we'll wait
        if transitionEvent?
          @_loadingHtmlElem.addEventListener(transitionEvent, listener)
        else
          listener()

        # Define listeners for the transtioning out and in of new loading HTML/messages
        @_loadingHtmlListener = =>
          # New loading HTML has fully transitioned in. We're now ready to show a new message/HTML
          @_readyToShowLoadingHtml = true
          # Remove the CSS class that triggered the fade in animation
          @_loadingHtmlElem.className = @_loadingHtmlElem.className.replace(" pg-loading ", "")
          if transitionEvent? then @_loadingHtmlElem.removeEventListener(transitionEvent, @_loadingHtmlListener)
          # Check if there's still HTML left in the queue to display. If so, let's show it
          if @_loadingHtmlToDisplay.length > 0 then @_changeLoadingHtml()

        @_removingHtmlListener = =>
          # Last loading HTML to display has fully transitioned out. Time to transition the new in
          @_loadingHtmlElem.innerHTML = @_loadingHtmlToDisplay.shift()
          # Add the CSS class to trigger the fade in animation
          @_loadingHtmlElem.className = @_loadingHtmlElem.className.replace(" pg-removing ", " pg-loading ")
          if transitionEvent?
            @_loadingHtmlElem.removeEventListener(transitionEvent, @_removingHtmlListener)
            @_loadingHtmlElem.addEventListener(transitionEvent, @_loadingHtmlListener)
          else
            @_loadingHtmlListener()

    finish: ->
      return unless @_loadingElem?
      # Again, define a listener to run once the loading screen has fully transitioned out
      listener = =>
        # Remove the loading screen from the body
        document.body.removeChild(@_loadingElem)
        # Add a class to the body to signal that the loading screen has finished and the app is ready
        document.body.className += " pg-loaded"
        if transitionEvent? then @_loadingElem.removeEventListener(transitionEvent, listener)
        # Reset the loading screen element since it's no longer attached to the DOM
        @_loadingElem = null

      # Detect CSS animation support. If not found, we'll call the listener immediately. Otherwise, we'll wait
      if transitionEvent?
        # Set a class on the loading screen to trigger a fadeout animation
        @_loadingElem.className += " pg-loaded"
        # When the loading screen is finished fading out, we'll remove it from the DOM
        @_loadingElem.addEventListener(transitionEvent, listener)
      else
        listener()

    updateOption: (option, value) ->
      switch option
        when 'backgroundColor'
          @_loadingElem.style.backgroundColor = value
        when 'logo'
          @_logoElem.src = value
        when 'loadingHtml'
          @updateLoadingHtml(value)
        else
          throw new Error("Unknown option '#{option}'")

    updateLoadingHtml: (loadingHtml, immediately=false) ->
      unless @_loadingHtmlElem? then throw new Error("The loading template does not have an element of class 'pg-loading-html'")
      if immediately
        # Ignore any loading HTML that may be queued up. Show this immediately
        @_loadingHtmlToDisplay = [loadingHtml]
        @_readyToShowLoadingHtml = true
      else
        # Add to an array of HTML to display to the user
        @_loadingHtmlToDisplay.push(loadingHtml)
      # If ready, let's display the new loading HTML
      if @_readyToShowLoadingHtml then @_changeLoadingHtml()

    # Private method to immediately change the loading HTML displayed
    _changeLoadingHtml: ->
      @_readyToShowLoadingHtml = false
      # Remove any old event listeners that may still be attached to the DOM
      @_loadingHtmlElem.removeEventListener(transitionEvent, @_loadingHtmlListener)
      @_loadingHtmlElem.removeEventListener(transitionEvent, @_removingHtmlListener)
      # Remove any old CSS transition classes that may still be on the element
      @_loadingHtmlElem.className = @_loadingHtmlElem.className.replace(" pg-loading ", "").replace( " pg-removing ", "")

      if transitionEvent?
        # Add the CSS class that will cause the HTML to fade out
        @_loadingHtmlElem.className += " pg-removing "
        @_loadingHtmlElem.addEventListener(transitionEvent, @_removingHtmlListener)
      else
        @_removingHtmlListener()

  pleaseWait = (options = {}) ->
    new PleaseWait(options)

  exports.pleaseWait = pleaseWait
  return pleaseWait