(function() {
  var Controller, Position, Stop, StopCollection, StopListView, StopRowView, StopView, app;
  var __hasProp = Object.prototype.hasOwnProperty, __extends = function(child, parent) {
    for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; }
    function ctor() { this.constructor = child; }
    ctor.prototype = parent.prototype;
    child.prototype = new ctor;
    child.__super__ = parent.prototype;
    return child;
  };
  app = {
    getLocation: function() {
      if (geo_position_js.init()) {
        app.loading(true);
        return geo_position_js.getCurrentPosition(this.geoSuccess, this.geoError);
      } else {
        return app.error('Geolocation unavailable');
      }
    },
    geoSuccess: function(position) {
      app.loading(false);
      app.position.set({
        latitude: position.coords.latitude,
        longitude: position.coords.longitude,
        accuracy: position.coords.accuracy,
        heading: position.coords.heading,
        speed: position.coords.speed
      });
      return window.location.hash = '#stops';
    },
    geoError: function(error) {
      app.loading(false);
      return app.error(error.message);
    },
    search: function() {
      var q;
      q = $('.search input[type=text]').attr('value');
      if (q.trim() === '') {
        app.error('Please enter a search query.');
      } else {
        window.location.hash = "#search/" + q;
      }
      return false;
    },
    loading: function(enable) {
      if (enable) {
        $('#loading-indicator').css('top', document.body.scrollTop + 'px');
        return $('body').addClass('loading');
      } else {
        return $('body').removeClass('loading');
      }
    },
    error: function(message, retry) {
      if (retry == null) {
        retry = false;
      }
      $('#error-flash .message').text(message);
      if (retry) {
        $('#error-flash').addClass('retry');
      }
      $('body').addClass('error');
      if (!retry) {
        return setTimeout(function() {
          return $('body').removeClass('error');
        }, 5000);
      }
    },
    title: function(new_title) {
      if (new_title != null) {
        document.title = "" + new_title + " | Where is my bus?";
      } else {
        document.title = "Where is my bus?";
      }
      return _sf_async_config.title = document.title;
    },
    trackView: function(page) {
      if (typeof _gaq != "undefined" && _gaq !== null) {
        _gaq.push(['_trackPageview', page]);
      }
      if (typeof pSUPERFLY != "undefined" && pSUPERFLY !== null) {
        return pSUPERFLY.virtualPage(page);
      }
    },
    goBack: function() {
      if (app.startedInside) {
        window.location.hash = '';
        app.controller.home();
        return app.startedInside = false;
      } else {
        return window.history.back();
      }
    },
    startedInside: false
  };
  Position = (function() {
    function Position() {
      Position.__super__.constructor.apply(this, arguments);
    }
    __extends(Position, Backbone.Model);
    return Position;
  })();
  Stop = (function() {
    function Stop() {
      Stop.__super__.constructor.apply(this, arguments);
    }
    __extends(Stop, Backbone.Model);
    Stop.prototype.url = function() {
      return "/stop/" + (this.get('id'));
    };
    return Stop;
  })();
  StopView = (function() {
    function StopView() {
      StopView.__super__.constructor.apply(this, arguments);
    }
    __extends(StopView, Backbone.View);
    StopView.prototype.render = function() {
      var stop_name;
      stop_name = this.model.get('stop_name');
      app.title(stop_name);
      $(this.el).html(ich.stop(this.model.toJSON(), true));
      $(this.el).prepend("<div id='header'><h1>" + stop_name + "</h1></div>");
      return this;
    };
    return StopView;
  })();
  StopCollection = (function() {
    function StopCollection() {
      StopCollection.__super__.constructor.apply(this, arguments);
    }
    __extends(StopCollection, Backbone.Collection);
    StopCollection.prototype.model = Stop;
    StopCollection.prototype.comparator = function(stop) {
      return stop.get('distance');
    };
    return StopCollection;
  })();
  StopRowView = (function() {
    function StopRowView() {
      StopRowView.__super__.constructor.apply(this, arguments);
    }
    __extends(StopRowView, Backbone.View);
    StopRowView.prototype.tagName = 'li';
    StopRowView.prototype.className = 'stop';
    StopRowView.prototype.initialize = function() {
      _.bindAll(this, 'render');
      return this.model.bind('change', this.render);
    };
    StopRowView.prototype.render = function() {
      $(this.el).html(ich.stopRow(this.model.toJSON(), true));
      return this;
    };
    return StopRowView;
  })();
  StopListView = (function() {
    function StopListView() {
      StopListView.__super__.constructor.apply(this, arguments);
    }
    __extends(StopListView, Backbone.View);
    StopListView.prototype.render = function() {
      var list;
      app.title('Choose a stop');
      $(this.el).html('<ul />');
      $(this.el).prepend('<div id="header"><h1>Choose a stop</h1></div>');
      list = $(this.el).find('ul');
      this.collection.each(function(stop) {
        stop.view || (stop.view = new StopRowView({
          model: stop
        }));
        return list.append(stop.view.render().el);
      });
      return this;
    };
    return StopListView;
  })();
  Controller = (function() {
    function Controller() {
      Controller.__super__.constructor.apply(this, arguments);
    }
    __extends(Controller, Backbone.Controller);
    Controller.prototype.routes = {
      '': 'home',
      'stops': 'stops',
      'stop/:number': 'stop',
      'stops/:number': 'search',
      'search/:q': 'search'
    };
    Controller.prototype.home = function() {
      app.title();
      $('#home').css('display', 'block');
      Vertebrae.goHome();
      return app.trackView("/");
    };
    Controller.prototype.stops = function() {
      app.loading(true);
      return app.stops.fetch({
        success: function() {
          app.loading(false);
          Vertebrae.push(new StopListView({
            collection: app.stops
          }));
          return app.trackView("/stops");
        },
        error: function() {
          app.loading(false);
          return app.error('Error loading page.', true);
        }
      });
    };
    Controller.prototype.stop = function(id) {
      var stop;
      app.loading(true);
      stop = new Stop({
        id: id
      });
      return stop.fetch({
        success: function() {
          app.loading(false);
          if (!_.isEmpty(stop.get('routes'))) {
            Vertebrae.push(new StopView({
              model: stop
            }));
            return app.trackView("/stop/" + id);
          } else {
            app.goBack();
            return app.error('No upcoming scheduled trips for that stop.');
          }
        },
        error: function() {
          app.loading(false);
          return app.error('Error loading page.', true);
        }
      });
    };
    Controller.prototype.search = function(q) {
      app.loading(true);
      app.stops.url = "/search?q=" + q;
      return app.stops.fetch({
        success: function() {
          app.loading(false);
          if (app.stops.isEmpty()) {
            app.goBack();
            return app.error('Your search returned no results.');
          } else {
            Vertebrae.push(new StopListView({
              collection: app.stops
            }));
            return app.trackView("/search?q=" + q);
          }
        },
        error: function() {
          app.loading(false);
          return app.error('Error loading page.', true);
        }
      });
    };
    return Controller;
  })();
  app.controller = new Controller;
  app.stops = new StopCollection;
  app.position = new Position;
  app.position.bind('change', function(position) {
    return app.stops.url = "/stops?lat=" + (position.get('latitude')) + "&lon=" + (position.get('longitude'));
  });
  $(document).ready(function() {
    setTimeout(scrollTo, 200, 0, 1);
    if (Backbone.history.getFragment() === '') {
      $('#home').css('display', 'block');
    } else {
      $('#home').css('display', 'none');
      app.startedInside = true;
    }
    Backbone.history.start();
    $('button.locate').bind('click', function() {
      return app.getLocation();
    });
    return $('#error-flash.retry').live('click', function() {
      $('body').removeClass('error');
      $('#error-flash').removeClass('retry');
      return Backbone.history.loadUrl();
    });
  });
  this.app = app;
}).call(this);
