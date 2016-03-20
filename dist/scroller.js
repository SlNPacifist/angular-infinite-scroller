(function() {
  var Buffer, ScrollerItemList, ScrollerViewport, VIEWPORT_DEFAULT_SETTINGS, insertAfter,
    bind = function(fn, me){ return function(){ return fn.apply(me, arguments); }; };

  VIEWPORT_DEFAULT_SETTINGS = {
    paddingTop: {
      min: 100,
      max: 150
    },
    paddingBottom: {
      min: 100,
      max: 150
    },
    itemsPerRequest: 10,
    autoUpdateInterval: 1000,
    afterScrollWaitTime: 100,
    topBoundaryTimeout: 10000,
    bottomBoundaryTimeout: 10000,
    bufferTopPadding: 20,
    bufferBottomPadding: 20
  };

  insertAfter = function(element, target) {
    var next, parent;
    parent = target.parentNode;
    if (target.nextSibling) {
      next = target.nextSibling;
      return parent.insertBefore(element, next);
    } else {
      return parent.appendChild(element);
    }
  };

  Buffer = (function() {
    function Buffer() {
      this.addItemsToStart = bind(this.addItemsToStart, this);
      this.addItemsToEnd = bind(this.addItemsToEnd, this);
      this.truncateTo = bind(this.truncateTo, this);
      this.start = 0;
      this.length = 0;
    }

    Buffer.prototype.truncateTo = function(start, end) {
      var cur_end, i, j, k, ref, ref1, ref2, ref3;
      if (this.start < start) {
        for (i = j = ref = this.start, ref1 = start; ref <= ref1 ? j < ref1 : j > ref1; i = ref <= ref1 ? ++j : --j) {
          delete this[i];
        }
        this.length = Math.max(0, this.length - (start - this.start));
        this.start = start;
      }
      cur_end = this.start + this.length - 1;
      if (cur_end > end) {
        for (i = k = ref2 = cur_end, ref3 = end; ref2 <= ref3 ? k < ref3 : k > ref3; i = ref2 <= ref3 ? ++k : --k) {
          delete this[i];
        }
        return this.length = Math.max(0, this.length - (cur_end - end));
      }
    };

    Buffer.prototype.addItemsToEnd = function(items) {
      var idx, item, j, len;
      for (idx = j = 0, len = items.length; j < len; idx = ++j) {
        item = items[idx];
        this[this.start + this.length + idx] = item;
      }
      return this.length += items.length;
    };

    Buffer.prototype.addItemsToStart = function(items) {
      var idx, item, j, len;
      this.start -= items.length;
      for (idx = j = 0, len = items.length; j < len; idx = ++j) {
        item = items[idx];
        this[this.start + idx] = item;
      }
      return this.length += items.length;
    };

    return Buffer;

  })();

  ScrollerViewport = (function() {
    function ScrollerViewport(scope1, _element) {
      this.scope = scope1;
      this._element = _element;
      this.preserveScroll = bind(this.preserveScroll, this);
      this._tryDrawBottomItem = bind(this._tryDrawBottomItem, this);
      this._tryDrawTopItem = bind(this._tryDrawTopItem, this);
      this._removeBottomDrawnItem = bind(this._removeBottomDrawnItem, this);
      this._removeTopDrawnItem = bind(this._removeTopDrawnItem, this);
      this._truncateBuffer = bind(this._truncateBuffer, this);
      this._addBottomDrawnItem = bind(this._addBottomDrawnItem, this);
      this._addTopDrawnItem = bind(this._addTopDrawnItem, this);
      this._updateState = bind(this._updateState, this);
      this._updateStateAsync = bind(this._updateStateAsync, this);
      this._requestMoreBottomItems = bind(this._requestMoreBottomItems, this);
      this._canRequestMoreBottomItems = bind(this._canRequestMoreBottomItems, this);
      this._requestMoreTopItems = bind(this._requestMoreTopItems, this);
      this._canRequestMoreTopItems = bind(this._canRequestMoreTopItems, this);
      this._changeAutoUpdateInterval = bind(this._changeAutoUpdateInterval, this);
      this._updateSettings = bind(this._updateSettings, this);
      this._updateSettings();
      this.scope.$watch('scrollerSettings', this._updateSettings, true);
      this._getItems = this.scope.scrollerSource.bind(this);
      this._drawnItems = [];
      this._buffer = new Buffer();
      this._requesting_top_items = false;
      this._requesting_bottom_items = false;
      this._updateStateAsync();
      this._element.addEventListener('scroll', this._updateStateAsync);
    }

    ScrollerViewport.prototype._updateSettings = function() {
      var new_settings, ref, ref1, ref10, ref11, ref2, ref3, ref4, ref5, ref6, ref7, ref8, ref9;
      new_settings = {
        paddingTop: {
          min: (ref = this.scope.$eval('scrollerSettings.paddingTop.min')) != null ? ref : VIEWPORT_DEFAULT_SETTINGS.paddingTop.min,
          max: (ref1 = this.scope.$eval('scrollerSettings.paddingTop.max')) != null ? ref1 : VIEWPORT_DEFAULT_SETTINGS.paddingTop.max
        },
        paddingBottom: {
          min: (ref2 = this.scope.$eval('scrollerSettings.paddingBottom.min')) != null ? ref2 : VIEWPORT_DEFAULT_SETTINGS.paddingBottom.min,
          max: (ref3 = this.scope.$eval('scrollerSettings.paddingBottom.max')) != null ? ref3 : VIEWPORT_DEFAULT_SETTINGS.paddingBottom.max
        },
        itemsPerRequest: (ref4 = this.scope.$eval('scrollerSettings.itemsPerRequest')) != null ? ref4 : VIEWPORT_DEFAULT_SETTINGS.itemsPerRequest,
        autoUpdateInterval: (ref5 = this.scope.$eval('scrollerSettings.autoUpdateInterval')) != null ? ref5 : VIEWPORT_DEFAULT_SETTINGS.autoUpdateInterval,
        afterScrollWaitTime: (ref6 = this.scope.$eval('scrollerSettings.afterScrollWaitTime')) != null ? ref6 : VIEWPORT_DEFAULT_SETTINGS.afterScrollWaitTime,
        topBoundaryTimeout: (ref7 = this.scope.$eval('scrollerSettings.topBoundaryTimeout')) != null ? ref7 : VIEWPORT_DEFAULT_SETTINGS.topBoundaryTimeout,
        bottomBoundaryTimeout: (ref8 = this.scope.$eval('scrollerSettings.bottomBoundaryTimeout')) != null ? ref8 : VIEWPORT_DEFAULT_SETTINGS.bottomBoundaryTimeout,
        bufferTopPadding: (ref9 = this.scope.$eval('scrollerSettings.bufferTopPadding')) != null ? ref9 : VIEWPORT_DEFAULT_SETTINGS.bufferTopPadding,
        bufferBottomPadding: (ref10 = this.scope.$eval('scrollerSettings.bufferBottomPadding')) != null ? ref10 : VIEWPORT_DEFAULT_SETTINGS.bufferBottomPadding
      };
      if (((ref11 = this._settings) != null ? ref11.autoUpdateInterval : void 0) !== new_settings.autoUpdateInterval) {
        this._changeAutoUpdateInterval(new_settings.autoUpdateInterval);
      }
      return this._settings = new_settings;
    };

    ScrollerViewport.prototype._changeAutoUpdateInterval = function(interval) {
      if (this._autoUpdateHandler != null) {
        window.clearInterval(this._autoUpdateHandler);
      }
      return this._autoUpdateHandler = window.setInterval(this._updateStateAsync, interval);
    };

    ScrollerViewport.prototype._canRequestMoreTopItems = function() {
      var now;
      now = new Date();
      return !(this._buffer.start === this._topBoundaryIndex && (now - this._topBoundaryIndexTimestamp < this._settings.topBoundaryTimeout));
    };

    ScrollerViewport.prototype._requestMoreTopItems = function() {
      var end, start;
      if (this._requesting_top_items) {
        return;
      }
      this._requesting_top_items = true;
      start = this._buffer.start - this._settings.itemsPerRequest;
      end = this._buffer.start;
      return this._getItems(start, this._settings.itemsPerRequest, (function(_this) {
        return function(err, res) {
          _this._requesting_top_items = false;
          if (err) {
            return;
          }
          if (res.length === 0) {
            _this._topBoundaryIndex = end;
            return _this._topBoundaryIndexTimestamp = new Date();
          } else {
            _this._buffer.addItemsToStart(res);
            if (_this._buffer.start < _this._topBoundaryIndex) {
              _this._topBoundaryIndex = null;
            }
            return _this._updateStateAsync();
          }
        };
      })(this));
    };

    ScrollerViewport.prototype._canRequestMoreBottomItems = function() {
      var now;
      now = new Date();
      return !(this._buffer.start + this._buffer.length === this._bottomBoundaryIndex && (now - this._bottomBoundaryIndexTimestamp < this._settings.bottomBoundaryTimeout));
    };

    ScrollerViewport.prototype._requestMoreBottomItems = function() {
      var start;
      if (this._requesting_bottom_items) {
        return;
      }
      this._requesting_bottom_items = true;
      start = this._buffer.start + this._buffer.length;
      return this._getItems(start, this._settings.itemsPerRequest, (function(_this) {
        return function(err, res) {
          _this._requesting_bottom_items = false;
          if (err) {
            return;
          }
          if (res.length === 0) {
            _this._bottomBoundaryIndex = start;
            return _this._bottomBoundaryIndexTimestamp = new Date();
          } else {
            _this._buffer.addItemsToEnd(res);
            if (_this._buffer.start + _this._buffer.length > _this._bottomBoundaryIndex) {
              _this._bottomBoundaryIndex = null;
            }
            return _this._updateStateAsync();
          }
        };
      })(this));
    };

    ScrollerViewport.prototype._updateStateAsync = function() {
      if (this._updatePlanned) {
        return;
      }
      this._updatePlanned = true;
      return setTimeout((function(_this) {
        return function() {
          _this._updatePlanned = false;
          return _this._updateState();
        };
      })(this), 0);
    };

    ScrollerViewport.prototype._updateState = function() {
      var now, paddingBottom;
      now = new Date();
      if (this._element.scrollTop === this._lastScrollTop && now - this._lastScrollTopChange > this._settings.afterScrollWaitTime) {
        if (this._element.scrollTop > this._settings.paddingTop.max) {
          this._removeTopDrawnItem();
        } else if (this._element.scrollTop < this._settings.paddingTop.min) {
          this._tryDrawTopItem();
        }
      } else {
        if (this._element.scrollTop !== this._lastScrollTop) {
          this._lastScrollTop = this._element.scrollTop;
          this._lastScrollTopChange = now;
        }
        this._updateStateAsync();
      }
      paddingBottom = this._element.scrollHeight - this._element.scrollTop - this._element.offsetHeight;
      if (paddingBottom < this._settings.paddingBottom.min) {
        return this._tryDrawBottomItem();
      } else if (paddingBottom > this._settings.paddingBottom.max) {
        return this._removeBottomDrawnItem();
      }
    };

    ScrollerViewport.prototype._addTopDrawnItem = function(item) {
      this._drawnItems = [item].concat(this._drawnItems);
      this.scope.$broadcast('top-item-rendered', item);
      return this._updateStateAsync();
    };

    ScrollerViewport.prototype._addBottomDrawnItem = function(item) {
      this._drawnItems.push(item);
      this.scope.$broadcast('bottom-item-rendered', item);
      return this._updateStateAsync();
    };

    ScrollerViewport.prototype._truncateBuffer = function() {
      var bufferMaxEnd, bufferMinStart;
      bufferMinStart = this._drawnItems[0].index - this._settings.bufferTopPadding;
      bufferMaxEnd = this._drawnItems[this._drawnItems.length - 1].index + this._settings.bufferBottomPadding;
      return this._buffer.truncateTo(bufferMinStart, bufferMaxEnd);
    };

    ScrollerViewport.prototype._removeTopDrawnItem = function() {
      this._drawnItems = this._drawnItems.slice(1);
      this.scope.$broadcast('top-item-removed');
      this._truncateBuffer();
      return this._updateStateAsync();
    };

    ScrollerViewport.prototype._removeBottomDrawnItem = function() {
      this._drawnItems.pop();
      this.scope.$broadcast('bottom-item-removed');
      this._truncateBuffer();
      return this._updateStateAsync();
    };

    ScrollerViewport.prototype._tryDrawTopItem = function() {
      var neededIndex;
      if (this._drawnItems.length > 0) {
        neededIndex = this._drawnItems[0].index - 1;
      } else {
        neededIndex = -1;
      }
      if (neededIndex in this._buffer) {
        return this._addTopDrawnItem({
          index: neededIndex,
          data: this._buffer[neededIndex]
        });
      } else if (this._canRequestMoreTopItems()) {
        return this._requestMoreTopItems();
      }
    };

    ScrollerViewport.prototype._tryDrawBottomItem = function() {
      var neededIndex;
      if (this._drawnItems.length > 0) {
        neededIndex = this._drawnItems[this._drawnItems.length - 1].index + 1;
      } else {
        neededIndex = 0;
      }
      if (neededIndex in this._buffer) {
        return this._addBottomDrawnItem({
          index: neededIndex,
          data: this._buffer[neededIndex]
        });
      } else if (this._canRequestMoreBottomItems()) {
        return this._requestMoreBottomItems();
      }
    };

    ScrollerViewport.prototype.preserveScroll = function(action) {
      var delta, heightBefore;
      heightBefore = this._element.scrollHeight;
      action();
      delta = this._element.scrollHeight - heightBefore;
      this._element.scrollTop += delta;
      return this._lastScrollTop = this._element.scrollTop;
    };

    return ScrollerViewport;

  })();

  ScrollerItemList = (function() {
    function ScrollerItemList(_$element, _viewportController, _$transclude) {
      this._$element = _$element;
      this._viewportController = _viewportController;
      this._$transclude = _$transclude;
      this._removeBottomItem = bind(this._removeBottomItem, this);
      this._removeTopItem = bind(this._removeTopItem, this);
      this._addBottomItem = bind(this._addBottomItem, this);
      this._addTopItem = bind(this._addTopItem, this);
      this._createItem = bind(this._createItem, this);
      this._renderedItems = [];
      this._viewportController.scope.$on('top-item-rendered', this._addTopItem);
      this._viewportController.scope.$on('bottom-item-rendered', this._addBottomItem);
      this._viewportController.scope.$on('top-item-removed', this._removeTopItem);
      this._viewportController.scope.$on('bottom-item-removed', this._removeBottomItem);
    }

    ScrollerItemList.prototype._createItem = function(data, insert_point) {
      var item;
      item = {
        scope: null,
        clone: null,
        data: data
      };
      this._$transclude(function(node, scope) {
        item.scope = scope;
        item.clone = node[0];
        return insertAfter(item.clone, insert_point);
      });
      item.scope.$apply(function() {
        return item.scope.scrData = item.data;
      });
      return item;
    };

    ScrollerItemList.prototype._destroyItem = function(item) {
      item.clone.remove();
      return item.scope.$destroy();
    };

    ScrollerItemList.prototype._addTopItem = function(_, data) {
      return this._viewportController.preserveScroll((function(_this) {
        return function() {
          return _this._renderedItems.unshift(_this._createItem(data, _this._$element[0]));
        };
      })(this));
    };

    ScrollerItemList.prototype._addBottomItem = function(_, data) {
      var insert_point;
      if (this._renderedItems.length > 0) {
        insert_point = this._renderedItems[this._renderedItems.length - 1].clone;
      } else {
        insert_point = this._$element[0];
      }
      return this._renderedItems.push(this._createItem(data, insert_point));
    };

    ScrollerItemList.prototype._removeTopItem = function() {
      if (this._renderedItems.length === 0) {
        return;
      }
      return this._viewportController.preserveScroll((function(_this) {
        return function() {
          return _this._destroyItem(_this._renderedItems.shift());
        };
      })(this));
    };

    ScrollerItemList.prototype._removeBottomItem = function() {
      var lastItem, selection;
      if (this._renderedItems.length === 0) {
        return;
      }
      lastItem = this._renderedItems.pop();
      selection = window.getSelection();
      return this._destroyItem(lastItem);
    };

    return ScrollerItemList;

  })();

  angular.module('scroller', []).directive('scrollerViewport', function() {
    return {
      restrict: 'A',
      transclude: true,
      scope: {
        'scrollerSource': '=',
        'scrollerSettings': '='
      },
      controller: function($scope, $element) {
        return new ScrollerViewport($scope, $element[0]);
      }
    };
  }).directive('scrollerItem', function() {
    return {
      restrict: 'A',
      priority: 1000,
      require: '^^scrollerViewport',
      transclude: 'element',
      scope: {},
      link: function($scope, $element, $attrs, viewportCtrl, $transclude) {
        return new ScrollerItemList($element, viewportCtrl, $transclude);
      }
    };
  });

}).call(this);
