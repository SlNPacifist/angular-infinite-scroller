# ### Code conventions:
#
# * Class members starting with underscore are **private** and should not be accessed
# * Other class members are **read-only**
# * All the changes to class should be done using public methods
# * Every property of an object should be assigned in constructor, even if its initial value is null
# or undefined. No new properties should be introduced during object lifecycle.

# ### <section id='VIEWPORT_DEFAULT_SETTINGS'>Default settings</section>
# Default settings for viewport. If any setting is not listed in scope, it will be copied from this
# object.
VIEWPORT_DEFAULT_SETTINGS =
    # If "hidden" part of viewport contents is less then `min`, new items will be rendered. If it is
    # more than `max`, rendered items will be destroyed. See
    # [`ScrollerViewport._updateState`](#ScrollerViewport._updateState) to get details on how this
    # is used in code.
    paddingTop:
        min: 100
        max: 150
    paddingBottom:
        min: 100
        max: 150
    # Number of items in every request. See
    # [`ScrollerViewport._tryDrawTopItem`](#ScrollerViewport._tryDrawTopItem) and
    # [`ScrollerViewport._tryDrawBottomItem`](#ScrollerViewport._tryDrawBottomItem)
    itemsPerRequest: 10
    # Number of milliseconds between "auto updates". This tracks any changes that cannot be tracked
    # otherwise. See
    # [`ScrollerViewport._changeAutoUpdateInterval`](#ScrollerViewport._changeAutoUpdateInterval).
    autoUpdateInterval: 1000
    # See [`ScrollerViewport._updateState`](#ScrollerViewport._updateState) for details.
    afterScrollWaitTime: 100
    # Number of milliseconds after which viewport will allow re-checking boundary of data. See
    # [`Buffer.beginOfDataReached`](#Buffer.beginOfDataReached) and
    # [`Buffer.endOfDataReached`](#Buffer.endOfDataReached) for details.
    buffer:
        topBoundaryTimeout: 10000
        bottomBoundaryTimeout: 10000
    # Amount of additional (compared to rendered) items that buffer keeps. I.e. if items 57-69 are
    # rendered then buffer will keep data for items 37-89. See
    # [`ScrollerViewport._truncateBuffer`](#ScrollerViewport._truncateBuffer) for details
    bufferTopPadding: 20
    bufferBottomPadding: 20


insertAfter = (element, target) ->
    parent = target.parentNode
    if target.nextSibling
        next = target.nextSibling
        parent.insertBefore(element, next)
    else
        parent.appendChild(element)


# ### <section id='ScrollerViewport'>Scroller Viewport</section>
#
# `ScrollerViewport` is `angular.js` controller. It tracks current state of bound element and makes
# decisions to ask for new items, render or delete items.
#
# Read [`_updateState`](#ScrollerViewport._updateState) documentation to understand this class state
# flow.
class ScrollerViewport
    # `scope`: [`angular.js scope`](https://docs.angularjs.org/api/ng/type/$rootScope.Scope). Used
    # for communication with [ScrollerItemList](#ScrollerItemList) througe events.
    #
    # `element`: `DOM Node` bound to this viewport
    #
    # `source`: `function(start, count, callback)`. This function is called whenever new data is
    # needed.
    #
    # * `start`: `int`
    # * `count`: `int`
    # * `callback`: `function(res)`. Callback should be called when needed data is ready.
    #  * `res`: `array`. Should contain `count` items in it. If request hit boundary of data, `res`
    #     can contain less then `count` data or even no data at all.
    #
    # `settings`: `object`. Settings object with structure similar to
    # [default settings](#VIEWPORT_DEFAULT_SETTINGS)
    constructor: (@scope, @_element, source, settings={}) ->
        @_settings = angular.merge({}, VIEWPORT_DEFAULT_SETTINGS, settings)

        # Viewport keeps track of currently rendered items in format
        # `{index: int, data: data_received_from_source_function}`
        @_drawnItems = []

        # [`Buffer`](#Buffer) caches data from `source`
        @_buffer = new Buffer(source, @_settings.buffer, @_updateBufferState)

        # Auto update makes sure we do not miss special or untrackable events.
        @_autoUpdateHandler = null

        # See [`_updateStateAsync`](#ScrollerViewport._updateStateAsync) for details.
        @_updatePlanned = false

        # See [`_updateState`](#ScrollerViewport._updateState) for details.
        @_lastScrollTop = null
        @_lastScrollTopChange = null

        # First update to start the process. `scroll` event most likely will cause actions to
        # perform. Finally, `_changeAutoUpdateInterval` function sets auto updates for any events
        # we do not track. Better later then never.
        @_updateStateAsync()
        @_element.addEventListener('scroll', @_updateStateAsync)
        @_changeAutoUpdateInterval(@_settings.autoUpdateInterval)

    updateSettings: (settings={}) =>
        settings = angular.merge({}, VIEWPORT_DEFAULT_SETTINGS, settings)
        if @_settings.autoUpdateInterval != settings.autoUpdateInterval
            @_changeAutoUpdateInterval(settings.autoUpdateInterval)
        @_settings = settings
        @_buffer.updateSettings(@_settings.buffer)

    updateSource: (source) =>
        @_buffer.destroy()
        @_buffer = new Buffer(source, @_settings.buffer, @_updateBufferState)
        @_drawnItems = []
        @scope.$broadcast('clear')

    # Updates buffer-related state (loading top, loading bottom, etc) in scope
    _updateBufferState: =>
        oldReachedTop = null
        oldReachedBottom = null
        @scope.$applyAsync =>
            @scope.scrLoadingTop = @_buffer.topIsLoading()
            @scope.scrReachedTop = @_buffer.beginOfDataReached()
            @scope.scrLoadingBottom = @_buffer.bottomIsLoading()
            @scope.scrReachedBottom = @_buffer.endOfDataReached()
            if oldReachedTop != @scope.scrReachedTop
                @_updateStateAsync()
                oldReachedTop = @scope.scrReachedTop
            if oldReachedBottom != @scope.scrReachedBottom
                @_updateStateAsync()
                oldReachedBottom = @scope.scrReachedBottom

    # ## <section id='ScrollerViewport._changeAutoUpdateInterval'></section>
    # Sets interval for auto updates. Auto update makes sure we do not miss special or untrackable
    # events.
    _changeAutoUpdateInterval: (interval) =>
        clearInterval(@_autoUpdateHandler) if @_autoUpdateHandler?
        @_autoUpdateHandler = setInterval(@_updateStateAsync, interval)

    # ## <section id='ScrollerViewport._updateState'></section>
    # Main function for this class. It performs measurements and makes decision on what to do.
    _updateState: =>
        # Firstly, check size of contents that is hidden on top. However, if you want to change
        # top of rendered items, you have to make sure you won't break current scrolling process.
        # When user scrolls contents of viewport, it is a process stretched in time, scrollTop will
        # be changing gradually for 30-70 ms. If you change scrollTop in the middle of that process
        # any scrolling will be stopped and user will experience very stuttering scrolling. I found
        # no "official" ways to determine if scrolling is going on or not, so the way to overcome
        # this is "wait for some time and make sure scroll did not change".
        #
        # `@_lastScrollTop` remembers last scrollTop measured and `@_lastScrollTopChange` remembers
        # time of measurement.
        now = new Date()
        if @_element.scrollTop == @_lastScrollTop && now - @_lastScrollTopChange > @_settings.afterScrollWaitTime
            # Code here assumes changing `@_element.scrollTop` is safe
            if @_element.scrollTop > @_settings.paddingTop.max
                @_removeTopDrawnItem()
            else if @_element.scrollTop < @_settings.paddingTop.min
                @_tryDrawTopItem()
        else
            # Code here assumes changing `@_element.scrollTop` is not safe
            if @_element.scrollTop != @_lastScrollTop
                @_lastScrollTop = @_element.scrollTop
                @_lastScrollTopChange = now
            # We wanted to updated state but could not do it due to scrolling. Plan update for the
            # next tick.
            @_updateStateAsync()

        # Unlike top, we can change bottom any time we need.
        paddingBottom = @_element.scrollHeight - @_element.scrollTop - @_element.offsetHeight
        if paddingBottom < @_settings.paddingBottom.min
            @_tryDrawBottomItem()
        else if paddingBottom > @_settings.paddingBottom.max
            @_removeBottomDrawnItem()

    # ## <section id='ScrollerViewport._updateStateAsync'></section>
    # `@_updateState` should not be called directly since it could cause multiple simultaneous
    # updates. `@_updateStateAsync` makes sure only one update is performed per tick.
    _updateStateAsync: =>
        return if @_updatePlanned
        @_updatePlanned = true
        setTimeout =>
            @_updatePlanned = false
            @_updateState()
        , 0

    # ## <section id='ScrollerViewport._tryDrawTopItem'></section>
    # Either render existing item or request more items from the top. Note that if no data available
    # then more data is requested, but no rendering will happen when data arrives.
    # `@_updateStateAsync` is called when data arrives.
    _tryDrawTopItem: =>
        if @_drawnItems.length > 0
            neededIndex = @_drawnItems[0].index - 1
        else
            neededIndex = -1
        if neededIndex of @_buffer
            @_addTopDrawnItem({index: neededIndex, data: @_buffer[neededIndex]})
        else
            @_buffer.requestMoreTopItems(@_settings.itemsPerRequest, @_updateStateAsync)

    # ## <section id='ScrollerViewport._tryDrawBottomItem'></section>
    # Either render existing item or request more items from the bottom.
    _tryDrawBottomItem: =>
        if @_drawnItems.length > 0
            neededIndex = @_drawnItems[@_drawnItems.length - 1].index + 1
        else
            neededIndex = 0
        if neededIndex of @_buffer
            @_addBottomDrawnItem({index: neededIndex, data: @_buffer[neededIndex]})
        else
            @_buffer.requestMoreBottomItems(@_settings.itemsPerRequest, @_updateStateAsync)

    # Simply add new item to list of drawn items and send a command to draw this item for all
    # `ScrollerItemList` controllers. Items should be drawn this tick so update on the next tick
    # will see changes and will be able to make new decisions.
    _addTopDrawnItem: (item) =>
        @_drawnItems.unshift(item)
        @scope.$broadcast('render-top-item', item)
        @_updateStateAsync()

    # See `@_addTopDrawnItem` for additional comments.
    _addBottomDrawnItem: (item) =>
        @_drawnItems.push(item)
        @scope.$broadcast('render-bottom-item', item)
        @_updateStateAsync()

    # ## <section id='ScrollerViewport._truncateBuffer'></section>
    # This makes sure buffer does not grow infinitely. Buffer always contains more data than
    # rendered, paddings are configurable.
    _truncateBuffer: =>
        bufferMinStart = @_drawnItems[0].index - @_settings.bufferTopPadding
        bufferMaxEnd = @_drawnItems[@_drawnItems.length - 1].index + @_settings.bufferBottomPadding
        @_buffer.truncateTo(bufferMinStart, bufferMaxEnd)

    _removeTopDrawnItem: =>
        @_drawnItems.shift()
        @scope.$broadcast('remove-top-item')
        @_truncateBuffer()
        @_updateStateAsync()

    _removeBottomDrawnItem: =>
        @_drawnItems.pop()
        @scope.$broadcast('remove-bottom-item')
        @_truncateBuffer()
        @_updateStateAsync()

    # Public method is used by `ScrollerItemList` to preserve scroll position when adding or
    # removing items from the top. We assume that any change in height of contents are caused by
    # adding or removing of top items and compensate difference.
    preserveScroll: (action) =>
        heightBefore = @_element.scrollHeight
        scrollBefore = @_element.scrollTop
        action()
        heightDelta = @_element.scrollHeight - heightBefore
        scrollDelta = @_element.scrollTop - scrollBefore
        @_element.scrollTop += heightDelta - scrollDelta
        @_lastScrollTop = @_element.scrollTop


# ### <section id='ScrollerItemList'>Scroller item list</section>
#
# `ScrollerItemList` is `angular.js` controller. It manages list of items currently rendered in
# viewport.
#
# Class state flow is very simple. Once instantiated, object of this class listens to viewport
# events (commands) using angular.js scope for adding/removing top or bottom items.
# Adds new properties to scope:
#
# * scrIndex: global index of rendered item
# * scrData: data received from source function
class ScrollerItemList
    constructor: (@_$element, @_viewportController, @_$transclude) ->
        @_renderedItems = []
        @_viewportController.scope.$on('render-top-item', (_, source) => @_addTopItem(source))
        @_viewportController.scope.$on('render-bottom-item', (_, source) => @_addBottomItem(source))
        @_viewportController.scope.$on('remove-top-item', @_removeTopItem)
        @_viewportController.scope.$on('remove-bottom-item', @_removeBottomItem)
        @_viewportController.scope.$on('clear', @_clear)

    _createItem: (source, insert_point) =>
        item = {scope: null, clone: null}
        @_$transclude (node, scope) ->
            item.scope = scope
            item.clone = node[0]
            insertAfter(item.clone, insert_point)
        # Data should be applied after transclusion, otherwise item won't see changes
        item.scope.$apply ->
            item.scope.scrIndex = source.index
            item.scope.scrData = source.data
        item

    _destroyItem: (item) ->
        item.clone.remove()
        item.scope.$destroy()

    _addTopItem: (source) =>
        @_viewportController.preserveScroll =>
            @_renderedItems.unshift(@_createItem(source, @_$element[0]))

    _addBottomItem: (source) =>
        if @_renderedItems.length > 0
            insert_point = @_renderedItems[@_renderedItems.length - 1].clone
        else
            insert_point = @_$element[0]
        @_renderedItems.push(@_createItem(source, insert_point))

    _removeTopItem: =>
        return if @_renderedItems.length == 0
        @_viewportController.preserveScroll =>
            @_destroyItem(@_renderedItems.shift())

    _removeBottomItem: =>
        return if @_renderedItems.length == 0
        @_destroyItem(@_renderedItems.pop())

    _clear: =>
        @_destroyItem(item) for item in @_renderedItems
        @_renderedItems = []


# ### <section id='ScrollerItemList'>Buffer</section>
#
# `Buffer` manages items given by source function. It stores range of items in the form of
# array-like object: `{start: int, length: int}` and every stored index is a key in this object.
# Buffer assumes that only integer indexes are stored in it. It is capable of extension and
# truncating stored items.
class Buffer
    # `getItems`: `function(start, count, callback)`. See [`ScrollerViewport`](#ScrollerViewport)
    # constructor for details.
    #
    # `settings`: `object`
    # * `topBoundaryTimeout`: amount of time (ms) when hitting top boundary is considered valid.
    # After that time requests for top items will be allowed.
    # * `bottomBoundaryTimeout`: same as top `bottomBoundaryTimeout`, but for bottom boundary.
    #
    # `originalStateChange`: `function()`. Called when buffer state (top boundary hit, loading top,
    # bottom boundary hit, loading bottom) could be changed. Called in constructor. Not called in
    # destructor.
    constructor: (@_getItems, @_settings, @_originalStateChange) ->
        @start = 0
        @length = 0
        @_counter = 0
        @_topItemsRequestId = null
        @_bottomItemsRequestId = null
        @_topBoundaryIndex = null
        @_topBoundaryIndexTimestamp = null
        @_bottomBoundaryIndex = null
        @_bottomBoundaryIndexTimestamp = null
        # If buffer gets destroyed, noop will be called instead of function that we got in
        # constructor. We cannot change _onStateChange in destructor because functions passed to
        # setTimeout will still be unchanged.
        @_onStateChange = =>
            @_originalStateChange()
        @_onStateChange()

    updateSettings: (settings) =>
        @_settings = settings
        # make sure changes in settings change our state properly
        @_onStateChange()
        if @_topBoundaryIndex?
            delta = (@_topBoundaryIndexTimestamp - new Date()) + settings.topBoundaryTimeout
            setTimeout(@_onStateChange, delta)
        if @_bottomBoundaryIndex?
            delta = (@_bottomBoundaryIndexTimestamp - new Date()) + settings.bottomBoundaryTimeout
            setTimeout(@_onStateChange, delta)

    # ## <section id='Buffer.requestMoreTopItems'></section>
    # Only one request of top items may be active at a time. That ensures that multiple actions like
    # "scroll to bottom and back to top" does not make multiple requests.
    requestMoreTopItems: (quantity, callback) =>
        return if @_topItemsRequestId?
        return if @beginOfDataReached()
        @_startTopRequest()
        request_id = @_topItemsRequestId
        start = @start - quantity
        end = @start
        @_getItems start, quantity, (res) =>
            # Request has been canceled
            return if request_id != @_topItemsRequestId
            @_stopTopRequest()
            if res.length == 0
                @_markTopBoundary(end)
            else
                @_addItemsToStart(res)
                if @start < @_topBoundaryIndex
                    @_unmarkTopBoundary()
                callback()

    # ## <section id='Buffer.beginOfDataReached'></section>
    # This function tracks "begin of data". If we request top items and receive empty result, we
    # assume that we reached "begin of data". We will not do any requests of top items for some
    # (configurable) time. After that time requests for top items will be allowed.
    beginOfDataReached: =>
        now = new Date()
        return @start == @_topBoundaryIndex &&
            (now - @_topBoundaryIndexTimestamp < @_settings.topBoundaryTimeout)

    # Allocate new request id and make everyone know we're changing state
    _startTopRequest: =>
        @_topItemsRequestId = @_counter
        @_counter += 1
        @_onStateChange()

    _stopTopRequest: =>
        return if @_topItemsRequestId is null
        @_topItemsRequestId = null
        @_onStateChange()

    _markTopBoundary: (topIndex) =>
        @_topBoundaryIndex = topIndex
        @_topBoundaryIndexTimestamp = new Date()
        @_onStateChange()
        setTimeout(@_onStateChange, @_settings.topBoundaryTimeout)

    _unmarkTopBoundary: =>
        @_topBoundaryIndex = null
        @_onStateChange()

    _addItemsToStart: (items) =>
        @start -= items.length
        for item, idx in items
            this[@start + idx] = item
        @length += items.length

    # ## <section id='Buffer.requestMoreBottomItems'></section>
    # See [`@requestMoreTopItems`](#Buffer.requestMoreTopItems) for additional comments
    requestMoreBottomItems: (quantity, callback) =>
        return if @_bottomItemsRequestId?
        return if @endOfDataReached()
        @_startBottomRequest()
        request_id = @_bottomItemsRequestId
        start = @start + @length
        @_getItems start, quantity, (res) =>
            # Request has been canceled
            return if request_id != @_bottomItemsRequestId
            @_stopBottomRequest()
            if res.length == 0
                @_markBottomBoundary(start)
            else
                @_addItemsToEnd(res)
                if @start + @length > @_bottomBoundaryIndex
                    @_unmarkBottomBoundary()
                callback()

    # ## <section id='Buffer.endOfDataReached'></section>
    # See [`@beginOfDataReached`](#Buffer.beginOfDataReached) for additional comments
    endOfDataReached: =>
        now = new Date()
        return @start + @length == @_bottomBoundaryIndex &&
            (now - @_bottomBoundaryIndexTimestamp < @_settings.bottomBoundaryTimeout)

    # Allocate new request id and make everyone know we're changing state
    _startBottomRequest: =>
        @_bottomItemsRequestId = @_counter
        @_counter += 1
        @_onStateChange()

    _stopBottomRequest: =>
        return if @_bottomItemsRequestId is null
        @_bottomItemsRequestId = null
        @_onStateChange()

    _markBottomBoundary: (bottomIndex) =>
        @_bottomBoundaryIndex = bottomIndex
        @_bottomBoundaryIndexTimestamp = new Date()
        @_onStateChange()
        setTimeout(@_onStateChange, @_settings.bottomBoundaryTimeout)

    _unmarkBottomBoundary: =>
        @_bottomBoundaryIndex = null
        @_onStateChange()

    _addItemsToEnd: (items) =>
        for item, idx in items
            this[@start + @length + idx] = item
        @length += items.length

    truncateTo: (start, end) =>
        if @start < start
            for i in [@start...start]
                delete @[i]
            @length = Math.max(0, @length - (start - @start))
            @start = start
            # Cancel current top items request because we created a gap between items in this
            # request and start of buffer
            @_stopTopRequest()
        cur_end = @start + @length - 1
        if cur_end > end
            for i in [cur_end...end]
                delete this[i]
            @length = Math.max(0, @length - (cur_end - end))
            # Cancel current bottom items request because we created a gap between items in this
            # request and end of buffer
            @_stopBottomRequest()

    topIsLoading: => @_topItemsRequestId?

    bottomIsLoading: => @_bottomItemsRequestId?

    # Called when data source changes
    destroy: =>
        @_topItemsRequestId = null
        @_bottomItemsRequestId = null
        # `@_onStateChange` could be called in future because it was passed to `setTimeout`.
        # Changing `@_originalStateChange` to noop ensures that `@_onStateChange` will not change
        # anything.
        @_originalStateChange = ->


angular.module('scroller', [])

.directive 'scrollerViewport', ->
    restrict: 'A'
    scope: true
    controller: ($scope, $element, $attrs) ->
        viewportController = new ScrollerViewport(
            $scope, $element[0], $scope[$attrs.scrollerViewport], $scope[$attrs.scrollerSettings])

        $scope.$watch $attrs.scrollerSettings, (newVal) ->
            viewportController.updateSettings(newVal)
        , true

        $scope.$watch $attrs.scrollerViewport, (newVal, oldVal)->
            return if newVal == oldVal
            viewportController.updateSource(newVal)
        return viewportController

.directive 'scrollerItem', ->
    restrict: 'A'
    priority: 1000
    require: '^^scrollerViewport'
    transclude: 'element'
    scope: true
    link: ($scope, $element, $attrs, viewportCtrl, $transclude) ->
        new ScrollerItemList($element, viewportCtrl, $transclude)
