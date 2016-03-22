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
    function ScrollerViewport(scope1, _element, source, settings) {
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
      this._updateBufferState = bind(this._updateBufferState, this);
      this.updateSource = bind(this.updateSource, this);
      this.updateSettings = bind(this.updateSettings, this);
      this._settings = angular.merge({}, VIEWPORT_DEFAULT_SETTINGS, settings);
      this._drawnItems = [];
      this._buffer = new Buffer(source, this._settings.buffer, this._updateBufferState);
      this._autoUpdateHandler = null;
      this._updatePlanned = false;
      this._lastScrollTop = null;
      this._lastScrollTopChange = null;
      this._updateStateAsync();
      this._element.addEventListener('scroll', this._updateStateAsync);
      this._changeAutoUpdateInterval(this._settings.autoUpdateInterval);
    }

    ScrollerViewport.prototype.updateSettings = function(settings) {
      if (settings == null) {
        settings = {};
      }
      settings = angular.merge({}, VIEWPORT_DEFAULT_SETTINGS, settings);
      if (this._settings.autoUpdateInterval !== settings.autoUpdateInterval) {
        this._changeAutoUpdateInterval(settings.autoUpdateInterval);
      }
      this._settings = settings;
      return this._buffer.updateSettings(this._settings.buffer);
    };

    ScrollerViewport.prototype.updateSource = function(source) {
      this._buffer.destroy();
      this._buffer = new Buffer(source, this._settings.buffer, this._updateBufferState);
      this._drawnItems = [];
      return this.scope.$broadcast('clear');
    };

    ScrollerViewport.prototype._updateBufferState = function() {
      var oldReachedBottom, oldReachedTop;
      oldReachedTop = null;
      oldReachedBottom = null;
      return this.scope.$applyAsync((function(_this) {
        return function() {
          _this.scope.scrLoadingTop = _this._buffer.topIsLoading();
          _this.scope.scrReachedTop = _this._buffer.beginOfDataReached();
          _this.scope.scrLoadingBottom = _this._buffer.bottomIsLoading();
          _this.scope.scrReachedBottom = _this._buffer.endOfDataReached();
          if (oldReachedTop !== _this.scope.scrReachedTop) {
            _this._updateStateAsync();
            oldReachedTop = _this.scope.scrReachedTop;
          }
          if (oldReachedBottom !== _this.scope.scrReachedBottom) {
            _this._updateStateAsync();
            return oldReachedBottom = _this.scope.scrReachedBottom;
          }
        };
      })(this));
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
      this._drawnItems.unshift(item);
      this.scope.$broadcast('render-top-item', item);
      return this._updateStateAsync();
    };

    ScrollerViewport.prototype._addBottomDrawnItem = function(item) {
      this._drawnItems.push(item);
      this.scope.$broadcast('render-bottom-item', item);
      return this._updateStateAsync();
    };

    ScrollerViewport.prototype._truncateBuffer = function() {
      var bufferMaxEnd, bufferMinStart;
      bufferMinStart = this._drawnItems[0].index - this._settings.bufferTopPadding;
      bufferMaxEnd = this._drawnItems[this._drawnItems.length - 1].index + this._settings.bufferBottomPadding;
      return this._buffer.truncateTo(bufferMinStart, bufferMaxEnd);
    };

    ScrollerViewport.prototype._removeTopDrawnItem = function() {
      this._drawnItems.shift();
      this.scope.$broadcast('remove-top-item');
      this._truncateBuffer();
      return this._updateStateAsync();
    };

    ScrollerViewport.prototype._removeBottomDrawnItem = function() {
      this._drawnItems.pop();
      this.scope.$broadcast('remove-bottom-item');
      this._truncateBuffer();
      return this._updateStateAsync();
    };

    ScrollerViewport.prototype.preserveScroll = function(action) {
      var heightBefore, heightDelta, scrollBefore, scrollDelta;
      heightBefore = this._element.scrollHeight;
      scrollBefore = this._element.scrollTop;
      action();
      heightDelta = this._element.scrollHeight - heightBefore;
      scrollDelta = this._element.scrollTop - scrollBefore;
      this._element.scrollTop += heightDelta - scrollDelta;
      return this._lastScrollTop = this._element.scrollTop;
    };

    return ScrollerViewport;

  })();

  ScrollerItemList = (function() {
    function ScrollerItemList(_$element, _viewportController, _$transclude) {
      this._$element = _$element;
      this._viewportController = _viewportController;
      this._$transclude = _$transclude;
      this._clear = bind(this._clear, this);
      this._removeBottomItem = bind(this._removeBottomItem, this);
      this._removeTopItem = bind(this._removeTopItem, this);
      this._addBottomItem = bind(this._addBottomItem, this);
      this._addTopItem = bind(this._addTopItem, this);
      this._createItem = bind(this._createItem, this);
      this._renderedItems = [];
      this._viewportController.scope.$on('render-top-item', (function(_this) {
        return function(_, source) {
          return _this._addTopItem(source);
        };
      })(this));
      this._viewportController.scope.$on('render-bottom-item', (function(_this) {
        return function(_, source) {
          return _this._addBottomItem(source);
        };
      })(this));
      this._viewportController.scope.$on('remove-top-item', this._removeTopItem);
      this._viewportController.scope.$on('remove-bottom-item', this._removeBottomItem);
      this._viewportController.scope.$on('clear', this._clear);
    }

    ScrollerItemList.prototype._createItem = function(source, insert_point) {
      var item;
      item = {
        scope: null,
        clone: null
      };
      this._$transclude(function(node, scope) {
        item.scope = scope;
        item.clone = node[0];
        return insertAfter(item.clone, insert_point);
      });
      item.scope.$apply(function() {
        item.scope.scrIndex = source.index;
        return item.scope.scrData = source.data;
      });
      return item;
    };

    ScrollerItemList.prototype._destroyItem = function(item) {
      item.clone.remove();
      return item.scope.$destroy();
    };

    ScrollerItemList.prototype._addTopItem = function(source) {
      return this._viewportController.preserveScroll((function(_this) {
        return function() {
          return _this._renderedItems.unshift(_this._createItem(source, _this._$element[0]));
        };
      })(this));
    };

    ScrollerItemList.prototype._addBottomItem = function(source) {
      var insert_point;
      if (this._renderedItems.length > 0) {
        insert_point = this._renderedItems[this._renderedItems.length - 1].clone;
      } else {
        insert_point = this._$element[0];
      }
      return this._renderedItems.push(this._createItem(source, insert_point));
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
      if (this._renderedItems.length === 0) {
        return;
      }
      return this._destroyItem(this._renderedItems.pop());
    };

    ScrollerItemList.prototype._clear = function() {
      var item, j, len, ref;
      ref = this._renderedItems;
      for (j = 0, len = ref.length; j < len; j++) {
        item = ref[j];
        this._destroyItem(item);
      }
      return this._renderedItems = [];
    };

    return ScrollerItemList;

  })();

  Buffer = (function() {
    function Buffer(_getItems, _settings, _originalStateChange) {
      this._getItems = _getItems;
      this._settings = _settings;
      this._originalStateChange = _originalStateChange;
      this.destroy = bind(this.destroy, this);
      this.bottomIsLoading = bind(this.bottomIsLoading, this);
      this.topIsLoading = bind(this.topIsLoading, this);
      this.truncateTo = bind(this.truncateTo, this);
      this._addItemsToEnd = bind(this._addItemsToEnd, this);
      this._unmarkBottomBoundary = bind(this._unmarkBottomBoundary, this);
      this._markBottomBoundary = bind(this._markBottomBoundary, this);
      this._stopBottomRequest = bind(this._stopBottomRequest, this);
      this._startBottomRequest = bind(this._startBottomRequest, this);
      this.endOfDataReached = bind(this.endOfDataReached, this);
      this.requestMoreBottomItems = bind(this.requestMoreBottomItems, this);
      this._addItemsToStart = bind(this._addItemsToStart, this);
      this._unmarkTopBoundary = bind(this._unmarkTopBoundary, this);
      this._markTopBoundary = bind(this._markTopBoundary, this);
      this._stopTopRequest = bind(this._stopTopRequest, this);
      this._startTopRequest = bind(this._startTopRequest, this);
      this.beginOfDataReached = bind(this.beginOfDataReached, this);
      this.requestMoreTopItems = bind(this.requestMoreTopItems, this);
      this.updateSettings = bind(this.updateSettings, this);
      this.start = 0;
      this.length = 0;
      this._counter = 0;
      this._topItemsRequestId = null;
      this._bottomItemsRequestId = null;
      this._topBoundaryIndex = null;
      this._topBoundaryIndexTimestamp = null;
      this._bottomBoundaryIndex = null;
      this._bottomBoundaryIndexTimestamp = null;
      this._onStateChange = (function(_this) {
        return function() {
          return _this._originalStateChange();
        };
      })(this);
      this._onStateChange();
    }

    Buffer.prototype.updateSettings = function(settings) {
      var delta;
      this._settings = settings;
      if (this._topBoundaryIndex != null) {
        delta = (this._topBoundaryIndexTimestamp - new Date()) + settings.topBoundaryTimeout;
        setTimeout(this._onStateChange, delta);
      }
      if (this._bottomBoundaryIndex != null) {
        delta = (this._bottomBoundaryIndexTimestamp - new Date()) + settings.bottomBoundaryTimeout;
        return setTimeout(this._onStateChange, delta);
      }
    };

    Buffer.prototype.requestMoreTopItems = function(quantity, callback) {
      var end, request_id, start;
      if (this._topItemsRequestId != null) {
        return;
      }
      if (this.beginOfDataReached()) {
        return;
      }
      this._startTopRequest();
      request_id = this._topItemsRequestId;
      start = this.start - quantity;
      end = this.start;
      return this._getItems(start, quantity, (function(_this) {
        return function(res) {
          if (request_id !== _this._topItemsRequestId) {
            return;
          }
          _this._stopTopRequest();
          if (res.length === 0) {
            return _this._markTopBoundary(end);
          } else {
            _this._addItemsToStart(res);
            if (_this.start < _this._topBoundaryIndex) {
              _this._unmarkTopBoundary();
            }
            return callback();
          }
        };
      })(this));
    };

    Buffer.prototype.beginOfDataReached = function() {
      var now;
      now = new Date();
      return this.start === this._topBoundaryIndex && (now - this._topBoundaryIndexTimestamp < this._settings.topBoundaryTimeout);
    };

    Buffer.prototype._startTopRequest = function() {
      this._topItemsRequestId = this._counter;
      this._counter += 1;
      return this._onStateChange();
    };

    Buffer.prototype._stopTopRequest = function() {
      if (this._topItemsRequestId === null) {
        return;
      }
      this._topItemsRequestId = null;
      return this._onStateChange();
    };

    Buffer.prototype._markTopBoundary = function(topIndex) {
      this._topBoundaryIndex = topIndex;
      this._topBoundaryIndexTimestamp = new Date();
      this._onStateChange();
      return setTimeout(this._onStateChange, this._settings.topBoundaryTimeout);
    };

    Buffer.prototype._unmarkTopBoundary = function() {
      this._topBoundaryIndex = null;
      return this._onStateChange();
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

    Buffer.prototype.requestMoreBottomItems = function(quantity, callback) {
      var request_id, start;
      if (this._bottomItemsRequestId != null) {
        return;
      }
      if (this.endOfDataReached()) {
        return;
      }
      this._startBottomRequest();
      request_id = this._bottomItemsRequestId;
      start = this.start + this.length;
      return this._getItems(start, quantity, (function(_this) {
        return function(res) {
          if (request_id !== _this._bottomItemsRequestId) {
            return;
          }
          _this._stopBottomRequest();
          if (res.length === 0) {
            return _this._markBottomBoundary(start);
          } else {
            _this._addItemsToEnd(res);
            if (_this.start + _this.length > _this._bottomBoundaryIndex) {
              _this._unmarkBottomBoundary();
            }
            return callback();
          }
        };
      })(this));
    };

    Buffer.prototype.endOfDataReached = function() {
      var now;
      now = new Date();
      return this.start + this.length === this._bottomBoundaryIndex && (now - this._bottomBoundaryIndexTimestamp < this._settings.bottomBoundaryTimeout);
    };

    Buffer.prototype._startBottomRequest = function() {
      this._bottomItemsRequestId = this._counter;
      this._counter += 1;
      return this._onStateChange();
    };

    Buffer.prototype._stopBottomRequest = function() {
      if (this._bottomItemsRequestId === null) {
        return;
      }
      this._bottomItemsRequestId = null;
      return this._onStateChange();
    };

    Buffer.prototype._markBottomBoundary = function(bottomIndex) {
      this._bottomBoundaryIndex = bottomIndex;
      this._bottomBoundaryIndexTimestamp = new Date();
      this._onStateChange();
      return setTimeout(this._onStateChange, this._settings.bottomBoundaryTimeout);
    };

    Buffer.prototype._unmarkBottomBoundary = function() {
      this._bottomBoundaryIndex = null;
      return this._onStateChange();
    };

    Buffer.prototype._addItemsToEnd = function(items) {
      var idx, item, j, len;
      for (idx = j = 0, len = items.length; j < len; idx = ++j) {
        item = items[idx];
        this[this.start + this.length + idx] = item;
      }
      return this.length += items.length;
    };

    Buffer.prototype.truncateTo = function(start, end) {
      var cur_end, i, j, k, ref, ref1, ref2, ref3;
      if (this.start < start) {
        for (i = j = ref = this.start, ref1 = start; ref <= ref1 ? j < ref1 : j > ref1; i = ref <= ref1 ? ++j : --j) {
          delete this[i];
        }
        this.length = Math.max(0, this.length - (start - this.start));
        this.start = start;
        this._stopTopRequest();
      }
      cur_end = this.start + this.length - 1;
      if (cur_end > end) {
        for (i = k = ref2 = cur_end, ref3 = end; ref2 <= ref3 ? k < ref3 : k > ref3; i = ref2 <= ref3 ? ++k : --k) {
          delete this[i];
        }
        this.length = Math.max(0, this.length - (cur_end - end));
        return this._stopBottomRequest();
      }
    };

    Buffer.prototype.topIsLoading = function() {
      return this._topItemsRequestId != null;
    };

    Buffer.prototype.bottomIsLoading = function() {
      return this._bottomItemsRequestId != null;
    };

    Buffer.prototype.destroy = function() {
      this._topItemsRequestId = null;
      this._bottomItemsRequestId = null;
      return this._originalStateChange = function() {};
    };

    return Buffer;

  })();

  angular.module('scroller', []).directive('scrollerViewport', function() {
    return {
      restrict: 'A',
      scope: true,
      controller: function($scope, $element, $attrs) {
        var viewportController;
        viewportController = new ScrollerViewport($scope, $element[0], $scope[$attrs.scrollerViewport], $scope[$attrs.scrollerSettings]);
        $scope.$watch($attrs.scrollerSettings, function(newVal) {
          return viewportController.updateSettings(newVal);
        }, true);
        $scope.$watch($attrs.scrollerViewport, function(newVal, oldVal) {
          if (newVal === oldVal) {
            return;
          }
          return viewportController.updateSource(newVal);
        });
        return viewportController;
      }
    };
  }).directive('scrollerItem', function() {
    return {
      restrict: 'A',
      priority: 1000,
      require: '^^scrollerViewport',
      transclude: 'element',
      scope: true,
      link: function($scope, $element, $attrs, viewportCtrl, $transclude) {
        return new ScrollerItemList($element, viewportCtrl, $transclude);
      }
    };
  });

}).call(this);
