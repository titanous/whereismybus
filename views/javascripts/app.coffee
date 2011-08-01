app = 
  getLocation: ->
    if geo_position_js.init()
      app.loading(true)
      geo_position_js.getCurrentPosition(@geoSuccess, @geoError) 
    else
      app.error 'Geolocation unavailable'


  geoSuccess: (position) ->
    app.loading(false)
    app.position.set({
      latitude:  position.coords.latitude
      longitude: position.coords.longitude
      accuracy:  position.coords.accuracy
      heading:   position.coords.heading
      speed:     position.coords.speed
    })
    window.location.hash = '#stops'

  geoError: (error) ->
    app.loading(false)
    app.error(error.message)

  search: ->
    q = $('.search input[type=text]').attr('value')
    if q.trim() == ''
      app.error('Please enter a search query.')
    else
      window.location.hash = "#search/#{q}"
    false

  loading: (enable) ->
    if enable
      $('#loading-indicator').css('top', document.body.scrollTop + 'px')
      $('body').addClass('loading')
    else
      $('body').removeClass('loading')

  error: (message, retry = false) ->
    $('#error-flash .message').text(message)
    $('#error-flash').addClass('retry') if retry
    $('body').addClass('error')
    setTimeout(->
      $('body').removeClass('error')
    , 5000) if !retry

  title: (new_title) ->
    if new_title?
      document.title = "#{new_title} | Where is my bus?"
    else
      document.title = "Where is my bus?"
    _sf_async_config.title = document.title

  trackView: (page) ->
    if _gaq?
      _gaq.push(['_trackPageview', page])
    if pSUPERFLY?
      pSUPERFLY.virtualPage(page)

  goBack: ->
    if app.startedInside
      window.location.hash = ''
      app.controller.home()
      app.startedInside = false
    else
      window.history.back()

  startedInside: false

class Position extends Backbone.Model

class Stop extends Backbone.Model
  url: ->
    "/stop/#{@get('id')}"

class StopView extends Backbone.View
  render: ->
    stop_name = @model.get('stop_name')
    app.title(stop_name)
    $(@el).html ich.stop(@model.toJSON(), true)
    $(@el).prepend("<div id='header'><h1>#{stop_name}</h1></div>")
    return this

class StopCollection extends Backbone.Collection
  model: Stop

  comparator: (stop) ->
    stop.get('distance')

class StopRowView extends Backbone.View
  tagName: 'li'
  className: 'stop'

  initialize: ->
    _.bindAll(this, 'render')
    @model.bind('change', @render)

  render: ->
    $(@el).html ich.stopRow(@model.toJSON(), true)
    return this


class StopListView extends Backbone.View
  render: ->
    app.title('Choose a stop')
    $(@el).html('<ul />')
    $(@el).prepend('<div id="header"><h1>Choose a stop</h1></div>')
    list = $(@el).find('ul')
    @collection.each (stop) ->
      stop.view ||= new StopRowView({ model: stop })
      list.append(stop.view.render().el)
    return this


class Controller extends Backbone.Controller
  routes:
    '': 'home',
    'stops': 'stops'
    'stop/:number': 'stop'
    'stops/:number': 'search'
    'search/:q': 'search'

  home: ->
    app.title()
    $('#home').css('display', 'block')
    Vertebrae.goHome()
    app.trackView("/")

  stops: ->
    app.loading(true)
    app.stops.fetch(
      success: ->
        app.loading(false)
        Vertebrae.push new StopListView({ collection: app.stops })
        app.trackView("/stops")
      error: ->
        app.loading(false)
        app.error('Error loading page.', true)
    )

  stop: (id) ->
    app.loading(true)
    stop = new Stop({ id: id })
    stop.fetch(
      success: ->
        app.loading(false)
        if !_.isEmpty(stop.get('routes'))
          Vertebrae.push new StopView({ model: stop })
          app.trackView("/stop/#{id}")
        else
          app.goBack()
          app.error('No upcoming scheduled trips for that stop.')

      error: ->
        app.loading(false)
        app.error('Error loading page.', true)
    )

  search: (q) ->
    app.loading(true)
    app.stops.url = "/search?q=#{q}"
    app.stops.fetch(
      success: ->
        app.loading(false)
        if app.stops.isEmpty()
          app.goBack()
          app.error('Your search returned no results.')
        else
          Vertebrae.push new StopListView({ collection: app.stops })
          app.trackView("/search?q=#{q}")
      error: ->
        app.loading(false)
        app.error('Error loading page.', true)
    )


app.controller = new Controller

app.stops = new StopCollection

app.position = new Position
app.position.bind 'change', (position) ->
  app.stops.url = "/stops?lat=#{position.get('latitude')}&lon=#{position.get('longitude')}"

$(document).ready ->
  setTimeout(scrollTo, 200, 0, 1)

  if Backbone.history.getFragment() == ''
    $('#home').css('display', 'block')
  else
    $('#home').css('display', 'none')
    app.startedInside = true

  Backbone.history.start()

  $('button.locate').bind 'click', ->
    app.getLocation()

  $('#error-flash.retry').live 'click', ->
    $('body').removeClass('error')
    $('#error-flash').removeClass('retry')
    Backbone.history.loadUrl()

@app = app
