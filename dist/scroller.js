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
    buffer: {
      topBoundaryTimeout: 10000,
      bottomBoundaryTimeout: 10000
    },
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

  ScrollerViewport = (function() {
    function ScrollerViewport(scope1, _element, scrollerSource, settings) {
      this.scope = scope1;
      this._element = _element;
      if (settings == null) {
        settings = {};
      }
      this.preserveScroll = bind(this.preserveScroll, this);
      this._removeBottomDrawnItem = bind(this._removeBottomDrawnItem, this);
      this._removeTopDrawnItem = bind(this._removeTopDrawnItem, this);
      this._truncateBuffer = bind(this._truncateBuffer, this);
      this._addBottomDrawnItem = bind(this._addBottomDrawnItem, this);
      this._addTopDrawnItem = bind(this._addTopDrawnItem, this);
      this._tryDrawBottomItem = bind(this._tryDrawBottomItem, this);
      this._tryDrawTopItem = bind(this._tryDrawTopItem, this);
      this._updateStateAsync = bind(this._updateStateAsync, this);
      this._updateState = bind(this._updateState, this);
      this._changeAutoUpdateInterval = bind(this._changeAutoUpdateInterval, this);
      this.updateSettings = bind(this.updateSettings, this);
      this._settings = angular.merge(settings, VIEWPORT_DEFAULT_SETTINGS);
      this._drawnItems = [];
      this._buffer = new Buffer(scrollerSource, this._settings.buffer);
      this._updateStateAsync();
      this._element.addEventListener('scroll', this._updateStateAsync);
      this._changeAutoUpdateInterval(this._settings.autoUpdateInterval);
    }

    ScrollerViewport.prototype.updateSettings = function(settings) {
      if (settings == null) {
        settings = {};
      }
      angular.merge(settings, VIEWPORT_DEFAULT_SETTINGS);
      if (this._settings.autoUpdateInterval !== settings.autoUpdateInterval) {
        this._changeAutoUpdateInterval(settings.autoUpdateInterval);
      }
      this._settings = settings;
      return this._buffer.updateSettings(this._settings.buffer);
    };

    ScrollerViewport.prototype._changeAutoUpdateInterval = function(interval) {
      if (this._autoUpdateHandler != null) {
        clearInterval(this._autoUpdateHandler);
      }
      return this._autoUpdateHandler = setInterval(this._updateStateAsync, interval);
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
      } else {
        return this._buffer.requestMoreTopItems(this._settings.itemsPerRequest, this._updateStateAsync);
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
      } else {
        return this._buffer.requestMoreBottomItems(this._settings.itemsPerRequest, this._updateStateAsync);
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
      var lastItem;
      if (this._renderedItems.length === 0) {
        return;
      }
      lastItem = this._renderedItems.pop();
      return this._destroyItem(lastItem);
    };

    return ScrollerItemList;

  })();

  Buffer = (function() {
    function Buffer(_getItems, _settings) {
      this._getItems = _getItems;
      this._settings = _settings;
      this.truncateTo = bind(this.truncateTo, this);
      this._endOfDataReached = bind(this._endOfDataReached, this);
      this.requestMoreBottomItems = bind(this.requestMoreBottomItems, this);
      this._beginOfDataReached = bind(this._beginOfDataReached, this);
      this.requestMoreTopItems = bind(this.requestMoreTopItems, this);
      this.updateSettings = bind(this.updateSettings, this);
      this._addItemsToStart = bind(this._addItemsToStart, this);
      this._addItemsToEnd = bind(this._addItemsToEnd, this);
      this.start = 0;
      this.length = 0;
      this._counter = 0;
      this._top_items_request_id = null;
      this._bottom_items_request_id = null;
    }

    Buffer.prototype._addItemsToEnd = function(items) {
      var idx, item, j, len;
      for (idx = j = 0, len = items.length; j < len; idx = ++j) {
        item = items[idx];
        this[this.start + this.length + idx] = item;
      }
      return this.length += items.length;
    };

    Buffer.prototype._addItemsToStart = function(items) {
      var idx, item, j, len;
      this.start -= items.length;
      for (idx = j = 0, len = items.length; j < len; idx = ++j) {
        item = items[idx];
        this[this.start + idx] = item;
      }
      return this.length += items.length;
    };

    Buffer.prototype.updateSettings = function(settings) {
      return this._settings = settings;
    };

    Buffer.prototype.requestMoreTopItems = function(quantity, callback) {
      var end, request_id, start;
      if (this._top_items_request_id != null) {
        return;
      }
      if (this._beginOfDataReached()) {
        return;
      }
      request_id = this._top_items_request_id = this._counter;
      this._counter += 1;
      start = this.start - quantity;
      end = this.start;
      return this._getItems(start, quantity, (function(_this) {
        return function(err, res) {
          if (request_id !== _this._top_items_request_id) {
            return;
          }
          _this._top_items_request_id = null;
          if (err) {
            return;
          }
          if (res.length === 0) {
            _this._topBoundaryIndex = end;
            return _this._topBoundaryIndexTimestamp = new Date();
          } else {
            _this._addItemsToStart(res);
            if (_this.start < _this._topBoundaryIndex) {
              _this._topBoundaryIndex = null;
            }
            return callback();
          }
        };
      })(this));
    };

    Buffer.prototype._beginOfDataReached = function() {
      var now;
      now = new Date();
      return this.start === this._topBoundaryIndex && (now - this._topBoundaryIndexTimestamp < this._settings.topBoundaryTimeout);
    };

    Buffer.prototype.requestMoreBottomItems = function(quantity, callback) {
      var request_id, start;
      if (this._bottom_items_request_id != null) {
        return;
      }
      if (this._endOfDataReached()) {
        return;
      }
      request_id = this._bottom_items_request_id = this._counter;
      this._counter += 1;
      start = this.start + this.length;
      return this._getItems(start, quantity, (function(_this) {
        return function(err, res) {
          if (request_id !== _this._bottom_items_request_id) {
            return;
          }
          _this._bottom_items_request_id = null;
          if (err) {
            return;
          }
          if (res.length === 0) {
            _this._bottomBoundaryIndex = start;
            return _this._bottomBoundaryIndexTimestamp = new Date();
          } else {
            _this._addItemsToEnd(res);
            if (_this.start + _this.length > _this._bottomBoundaryIndex) {
              _this._bottomBoundaryIndex = null;
            }
            return callback();
          }
        };
      })(this));
    };

    Buffer.prototype._endOfDataReached = function() {
      var now;
      now = new Date();
      return this.start + this.length === this._bottomBoundaryIndex && (now - this._bottomBoundaryIndexTimestamp < this._settings.bottomBoundaryTimeout);
    };

    Buffer.prototype.truncateTo = function(start, end) {
      var cur_end, i, j, k, ref, ref1, ref2, ref3;
      if (this.start < start) {
        for (i = j = ref = this.start, ref1 = start; ref <= ref1 ? j < ref1 : j > ref1; i = ref <= ref1 ? ++j : --j) {
          delete this[i];
        }
        this.length = Math.max(0, this.length - (start - this.start));
        this.start = start;
        this._top_items_request_id = null;
      }
      cur_end = this.start + this.length - 1;
      if (cur_end > end) {
        for (i = k = ref2 = cur_end, ref3 = end; ref2 <= ref3 ? k < ref3 : k > ref3; i = ref2 <= ref3 ? ++k : --k) {
          delete this[i];
        }
        this.length = Math.max(0, this.length - (cur_end - end));
        return this._bottom_items_request_id = null;
      }
    };

    return Buffer;

  })();

  angular.module('scroller', []).directive('scrollerViewport', function() {
    return {
      restrict: 'A',
      scope: {
        'scrollerSource': '=',
        'scrollerSettings': '='
      },
      controller: function($scope, $element) {
        var update_settings, viewportController;
        viewportController = new ScrollerViewport($scope, $element[0], $scope.scrollerSource, $scope.scrollerSettings);
        update_settings = function() {
          return viewportController.updateSettings($scope.scrollerSettings);
        };
        $scope.$watch('scrollerSettings', update_settings, true);
        return viewportController;
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
