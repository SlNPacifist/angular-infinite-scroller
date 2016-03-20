# ### Code conventions:
#
# * Class members starting with underscore are considered **private** and should not be accessed
# * Other class members are **read-only**
# * All the changes to class should be done using public methods

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
    # [`ScrollerViewport._requestMoreTopItems`](#ScrollerViewport._requestMoreTopItems) and
    # [`ScrollerViewport._requestMoreBottomItems`](#ScrollerViewport._requestMoreBottomItems)
    itemsPerRequest: 10
    # Number of milliseconds between "auto updates". This tracks any changes that cannot be tracked
    # otherwise. See
    # [`ScrollerViewport._changeAutoUpdateInterval`](#ScrollerViewport._changeAutoUpdateInterval).
    autoUpdateInterval: 1000
    # See [`ScrollerViewport._updateState`](#ScrollerViewport._updateState) for details.
    afterScrollWaitTime: 100
    # Number of milliseconds after which viewport will allow re-checking boundary of data. See
    # [`ScrollerViewport._beginOfDataReached`](#ScrollerViewport._beginOfDataReached) and
    # [`ScrollerViewport._endOfDataReached`](#ScrollerViewport._endOfDataReached) for details.
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


# ### Scroller Viewport
#
# `ScrollerViewport` is `angular.js` controller. It solves two problems:
# * makes decisions to render or delete items
# * manages downloads of needed ranges of items
#
# Read [`_updateState`](#ScrollerViewport._updateState) documentation to understand this class state
# flow.
#
class ScrollerViewport
    # `ScrollerViewport` only requires
    # [angular.js scope](https://docs.angularjs.org/api/ng/type/$rootScope.Scope)
    # and bound DOM Node.
    constructor: (@scope, @_element) ->
        # Scope may contain `scrollerSettings` property which structure is similar to default
        # settings.Properties that are not presented in scope.scrollerSettings will be filled with
        # default settings. Settings are watched therefore any changes will be copied over to
        # viewport.
        @_updateSettings()
        @scope.$watch('scrollerSettings', @_updateSettings, true)

        # Scope must contain function `scope.scrollerSource` which is a data source for viewport.
        @_getItems = @scope.scrollerSource.bind(this)

        # Viewport keeps track of currently rendered items in format
        # `{index: int, data: data_received_from_source_function}`
        @_drawnItems = []

        # Buffer contains data received from source function. It is used to store more data than
        # rendered in case user wants to scroll back. However buffer size is limited.
        @_buffer = new Buffer()

        # Current state is tracked by these variables.
        @_requesting_top_items = false
        @_requesting_bottom_items = false

        # First update to start the process. `scroll` event most likely will cause actions to
        # perform. Finally, `_changeAutoUpdateInterval` function sets auto updates for any events
        # we do not track. Better later then never.
        @_updateStateAsync()
        @_element.addEventListener('scroll', @_updateStateAsync)

    # Keeps track of settings changes.
    _updateSettings: =>
        new_settings =
            paddingTop:
                min: @scope.$eval('scrollerSettings.paddingTop.min') ? VIEWPORT_DEFAULT_SETTINGS.paddingTop.min
                max: @scope.$eval('scrollerSettings.paddingTop.max') ? VIEWPORT_DEFAULT_SETTINGS.paddingTop.max
            paddingBottom:
                min: @scope.$eval('scrollerSettings.paddingBottom.min') ? VIEWPORT_DEFAULT_SETTINGS.paddingBottom.min
                max: @scope.$eval('scrollerSettings.paddingBottom.max') ? VIEWPORT_DEFAULT_SETTINGS.paddingBottom.max
            itemsPerRequest: @scope.$eval('scrollerSettings.itemsPerRequest') ? VIEWPORT_DEFAULT_SETTINGS.itemsPerRequest
            autoUpdateInterval: @scope.$eval('scrollerSettings.autoUpdateInterval') ? VIEWPORT_DEFAULT_SETTINGS.autoUpdateInterval
            afterScrollWaitTime: @scope.$eval('scrollerSettings.afterScrollWaitTime') ? VIEWPORT_DEFAULT_SETTINGS.afterScrollWaitTime
            topBoundaryTimeout: @scope.$eval('scrollerSettings.topBoundaryTimeout') ? VIEWPORT_DEFAULT_SETTINGS.topBoundaryTimeout
            bottomBoundaryTimeout: @scope.$eval('scrollerSettings.bottomBoundaryTimeout') ? VIEWPORT_DEFAULT_SETTINGS.bottomBoundaryTimeout
            bufferTopPadding: @scope.$eval('scrollerSettings.bufferTopPadding') ? VIEWPORT_DEFAULT_SETTINGS.bufferTopPadding
            bufferBottomPadding: @scope.$eval('scrollerSettings.bufferBottomPadding') ? VIEWPORT_DEFAULT_SETTINGS.bufferBottomPadding
        if @_settings?.autoUpdateInterval != new_settings.autoUpdateInterval
            @_changeAutoUpdateInterval(new_settings.autoUpdateInterval)
        @_settings = new_settings

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

    # `@_updateState` should not be called directly since it could cause multiple simultaneous
    # updates. `@_updateStateAsync` makes sure only one update is performed per tick.
    _updateStateAsync: =>
        return if @_updatePlanned
        @_updatePlanned = true
        setTimeout =>
            @_updatePlanned = false
            @_updateState()
        , 0

    # Either render existing item or request more items from the top.
    _tryDrawTopItem: =>
        if @_drawnItems.length > 0
            neededIndex = @_drawnItems[0].index - 1
        else
            neededIndex = -1
        if neededIndex of @_buffer
            @_addTopDrawnItem({index: neededIndex, data: @_buffer[neededIndex]})
        else
            @_requestMoreTopItems()

    # Either render existing item or request more items from the bottom.
    _tryDrawBottomItem: =>
        if @_drawnItems.length > 0
            neededIndex = @_drawnItems[@_drawnItems.length - 1].index + 1
        else
            neededIndex = 0
        if neededIndex of @_buffer
            @_addBottomDrawnItem({index: neededIndex, data: @_buffer[neededIndex]})
        else
            @_requestMoreBottomItems()

    # ## <section id='ScrollerViewport._requestMoreTopItems'></section>
    # Only one request of top items may be active at a time. That ensures that multiple actions like
    # "scroll to bottom and back to top" does not make multiple requests. Note that no rendering
    # happens when data arrives. Data is added to the buffer and `@_updateStateAsync` is called.
    # Errors in data source callback are ignored, but the do not fobid furhter requests of top
    # items.
    _requestMoreTopItems: =>
        return if @_requesting_top_items
        return if not @_beginOfDataReached()
        @_requesting_top_items = true
        start = @_buffer.start - @_settings.itemsPerRequest
        end = @_buffer.start
        @_getItems start, @_settings.itemsPerRequest, (err, res) =>
            @_requesting_top_items = false
            return if err
            if res.length == 0
                @_topBoundaryIndex = end
                @_topBoundaryIndexTimestamp = new Date()
            else
                # FIXME: if buffer gets truncated during request we will break data ordering
                @_buffer.addItemsToStart(res)
                if @_buffer.start < @_topBoundaryIndex
                    @_topBoundaryIndex = null
                @_updateStateAsync()

    # ## <section id='ScrollerViewport._beginOfDataReached'></section>
    # This function tracks "begin of data". If we request top items and receive empty result, we
    # assume that we reached "befin of data". We will not do any requests of top items for some
    # (configurable) time. After that time requests for top items will be allowed.
    _beginOfDataReached: =>
        now = new Date()
        return not (@_buffer.start == @_topBoundaryIndex &&
            (now - @_topBoundaryIndexTimestamp < @_settings.topBoundaryTimeout))

    # ## <section id='ScrollerViewport._requestMoreBottomItems'></section>
    # See `@_requestMoreTopItems` for additional comments
    _requestMoreBottomItems: =>
        return if @_requesting_bottom_items
        return if not @_endOfDataReached()
        @_requesting_bottom_items = true
        start = @_buffer.start + @_buffer.length
        @_getItems start, @_settings.itemsPerRequest, (err, res) =>
            @_requesting_bottom_items = false
            return if err
            if res.length == 0
                @_bottomBoundaryIndex = start
                @_bottomBoundaryIndexTimestamp = new Date()
            else
                # FIXME: if buffer gets truncated during request we will break data ordering
                @_buffer.addItemsToEnd(res)
                if @_buffer.start + @_buffer.length > @_bottomBoundaryIndex
                    @_bottomBoundaryIndex = null
                @_updateStateAsync()

    # ## <section id='ScrollerViewport._endOfDataReached'></section>
    # See `@_beginOfDataReached` for additional comments
    _endOfDataReached: =>
        now = new Date()
        return not (@_buffer.start + @_buffer.length == @_bottomBoundaryIndex &&
            (now - @_bottomBoundaryIndexTimestamp < @_settings.bottomBoundaryTimeout))

    # Simply add new item to list of drawn items and send a command to draw this item for all
    # `ScrollerItemList` controllers. Items should be drawn this tick so update on the next tick
    # will see changes and will be able to make new decisions.
    _addTopDrawnItem: (item) =>
        @_drawnItems = [item].concat(@_drawnItems)
        @scope.$broadcast('top-item-rendered', item)
        @_updateStateAsync()

    # See `@_addTopDrawnItem` for additional comments.
    _addBottomDrawnItem: (item) =>
        @_drawnItems.push(item)
        @scope.$broadcast('bottom-item-rendered', item)
        @_updateStateAsync()

    # ## <section id='ScrollerViewport._truncateBuffer'></section>
    # This makes sure buffer does not grow infinitely. Buffer always contains more data than
    # rendered, paddings are configurable.
    _truncateBuffer: =>
        bufferMinStart = @_drawnItems[0].index - @_settings.bufferTopPadding
        bufferMaxEnd = @_drawnItems[@_drawnItems.length - 1].index + @_settings.bufferBottomPadding
        @_buffer.truncateTo(bufferMinStart, bufferMaxEnd)

    _removeTopDrawnItem: =>
        @_drawnItems = @_drawnItems[1..]
        @scope.$broadcast('top-item-removed')
        @_truncateBuffer()
        @_updateStateAsync()

    _removeBottomDrawnItem: =>
        @_drawnItems.pop()
        @scope.$broadcast('bottom-item-removed')
        @_truncateBuffer()
        @_updateStateAsync()

    # Public method is used by `ScrollerItemList` to preserve scroll position when adding or
    # removing items from the top. We assume that any change in height of contents are caused by
    # adding or removing of top items and compensate difference.
    preserveScroll: (action) =>
        heightBefore = @_element.scrollHeight
        action()
        delta = @_element.scrollHeight - heightBefore
        @_element.scrollTop += delta
        @_lastScrollTop = @_element.scrollTop


# ### Scroller item list
#
# `ScrollerItemList` is `angular.js` controller. It manages list of items currently rendered in
# viewport.
#
# Class state flow is very simple. Once instantiated, object of this class listens to viewport
# events (commands) using angular.js scope for adding/removing top or bottom items.
class ScrollerItemList
    constructor: (@_$element, @_viewportController, @_$transclude) ->
        @_renderedItems = []
        @_viewportController.scope.$on('top-item-rendered', @_addTopItem)
        @_viewportController.scope.$on('bottom-item-rendered', @_addBottomItem)
        @_viewportController.scope.$on('top-item-removed', @_removeTopItem)
        @_viewportController.scope.$on('bottom-item-removed', @_removeBottomItem)

    _createItem: (data, insert_point) =>
        item = {scope: null, clone: null, data: data}
        @_$transclude (node, scope) ->
            item.scope = scope
            item.clone = node[0]
            insertAfter(item.clone, insert_point)
        # Data should be applied after transclusion, otherwise item won't see changes
        item.scope.$apply ->
            item.scope.scrData = item.data
        item

    _destroyItem: (item) ->
        item.clone.remove()
        item.scope.$destroy()

    _addTopItem: (_, data) =>
        @_viewportController.preserveScroll =>
            @_renderedItems.unshift(@_createItem(data, @_$element[0]))

    _addBottomItem: (_, data) =>
        if @_renderedItems.length > 0
            insert_point = @_renderedItems[@_renderedItems.length - 1].clone
        else
            insert_point = @_$element[0]
        @_renderedItems.push(@_createItem(data, insert_point))

    _removeTopItem: =>
        return if @_renderedItems.length == 0
        @_viewportController.preserveScroll =>
            @_destroyItem(@_renderedItems.shift())

    _removeBottomItem: =>
        return if @_renderedItems.length == 0
        lastItem = @_renderedItems.pop()
        @_destroyItem(lastItem)


# ### Buffer
#
# `Buffer` is used to store range of items: `{start: int, length: int}` and every stored index is a
# key in this object. Buffer assumes that only integer indexes are stored in it. It is capable of
# extension and truncating.
class Buffer
    constructor: ->
        @start = 0
        @length = 0

    truncateTo: (start, end) =>
        if @start < start
            for i in [@start...start]
                delete @[i]
            @length = Math.max(0, @length - (start - @start))
            @start = start
        cur_end = @start + @length - 1
        if cur_end > end
            for i in [cur_end...end]
                delete @[i]
            @length = Math.max(0, @length - (cur_end - end))

    addItemsToEnd: (items) =>
        for item, idx in items
            @[@start + @length + idx] = item
        @length += items.length

    addItemsToStart: (items) =>
        @start -= items.length
        for item, idx in items
            @[@start + idx] = item
        @length += items.length


angular.module('scroller', [])

.directive 'scrollerViewport', ->
    restrict: 'A'
    scope: {'scrollerSource': '=', 'scrollerSettings': '='}
    controller: ($scope, $element) ->
        new ScrollerViewport($scope, $element[0])

.directive 'scrollerItem', ->
    restrict: 'A'
    priority: 1000
    require: '^^scrollerViewport'
    transclude: 'element'
    scope: {}
    link: ($scope, $element, $attrs, viewportCtrl, $transclude) ->
        new ScrollerItemList($element, viewportCtrl, $transclude)
