VIEWPORT_DEFAULT_SETTINGS =
    paddingTop:
        min: 100
        max: 150
    paddingBottom:
        min: 100
        max: 150
    itemsPerRequest: 10
    autoUpdateInterval: 1000
    afterScrollWaitTime: 100
    topBoundaryTimeout: 10000
    bottomBoundaryTimeout: 10000
    bufferTopPadding: 20
    bufferBottomPadding: 20


insertAfter = (element, target) ->
    parent = target.parentNode
    if target.nextSibling
        next = target.nextSibling
        parent.insertBefore(element, next)
    else
        parent.appendChild(element)


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


class ScrollerViewport
    constructor: (@scope, @_element) ->
        @_updateSettings()
        @scope.$watch('scrollerSettings', @_updateSettings, true)
        @_getItems = @scope.scrollerSource.bind(@)
        @_drawnItems = []
        @_buffer = new Buffer()
        @_requesting_top_items = false
        @_requesting_bottom_items = false
        @_updateStateAsync()
        @_element.addEventListener('scroll', @_updateStateAsync)

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

    _changeAutoUpdateInterval: (interval) =>
        window.clearInterval(@_autoUpdateHandler) if @_autoUpdateHandler?
        @_autoUpdateHandler = window.setInterval(@_updateStateAsync, interval)

    _canRequestMoreTopItems: =>
        now = new Date()
        return not (@_buffer.start == @_topBoundaryIndex &&
            (now - @_topBoundaryIndexTimestamp < @_settings.topBoundaryTimeout))

    _requestMoreTopItems: =>
        return if @_requesting_top_items
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
                @_buffer.addItemsToStart(res)
                if @_buffer.start < @_topBoundaryIndex
                    @_topBoundaryIndex = null
                @_updateStateAsync()

    _canRequestMoreBottomItems: =>
        now = new Date()
        return not (@_buffer.start + @_buffer.length == @_bottomBoundaryIndex &&
            (now - @_bottomBoundaryIndexTimestamp < @_settings.bottomBoundaryTimeout))

    _requestMoreBottomItems: =>
        return if @_requesting_bottom_items
        @_requesting_bottom_items = true
        start = @_buffer.start + @_buffer.length
        @_getItems start, @_settings.itemsPerRequest, (err, res) =>
            @_requesting_bottom_items = false
            return if err
            if res.length == 0
                @_bottomBoundaryIndex = start
                @_bottomBoundaryIndexTimestamp = new Date()
            else
                @_buffer.addItemsToEnd(res)
                if @_buffer.start + @_buffer.length > @_bottomBoundaryIndex
                    @_bottomBoundaryIndex = null
                @_updateStateAsync()

    _updateStateAsync: =>
        return if @_updatePlanned
        @_updatePlanned = true
        setTimeout =>
            @_updatePlanned = false
            @_updateState()
        , 0

    _updateState: =>
        now = new Date()
        if @_element.scrollTop == @_lastScrollTop && now - @_lastScrollTopChange > @_settings.afterScrollWaitTime
            if @_element.scrollTop > @_settings.paddingTop.max
                @_removeTopDrawnItem()
            else if @_element.scrollTop < @_settings.paddingTop.min
                @_tryDrawTopItem()
        else
            if @_element.scrollTop != @_lastScrollTop
                @_lastScrollTop = @_element.scrollTop
                @_lastScrollTopChange = now
            @_updateStateAsync()

        paddingBottom = @_element.scrollHeight - @_element.scrollTop - @_element.offsetHeight
        if paddingBottom < @_settings.paddingBottom.min
            @_tryDrawBottomItem()
        else if paddingBottom > @_settings.paddingBottom.max
            @_removeBottomDrawnItem()

    _addTopDrawnItem: (item) =>
        @_drawnItems = [item].concat(@_drawnItems)
        @scope.$broadcast('top-item-rendered', item)
        @_updateStateAsync()

    _addBottomDrawnItem: (item) =>
        @_drawnItems.push(item)
        @scope.$broadcast('bottom-item-rendered', item)
        @_updateStateAsync()

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

    _tryDrawTopItem: =>
        if @_drawnItems.length > 0
            neededIndex = @_drawnItems[0].index - 1
        else
            neededIndex = -1
        if neededIndex of @_buffer
            @_addTopDrawnItem({index: neededIndex, data: @_buffer[neededIndex]})
        else if @_canRequestMoreTopItems()
            @_requestMoreTopItems()

    _tryDrawBottomItem: =>
        if @_drawnItems.length > 0
            neededIndex = @_drawnItems[@_drawnItems.length - 1].index + 1
        else
            neededIndex = 0
        if neededIndex of @_buffer
            @_addBottomDrawnItem({index: neededIndex, data: @_buffer[neededIndex]})
        else if @_canRequestMoreBottomItems()
            @_requestMoreBottomItems()

    preserveScroll: (action) =>
        heightBefore = @_element.scrollHeight
        action()
        delta = @_element.scrollHeight - heightBefore
        @_element.scrollTop += delta
        @_lastScrollTop = @_element.scrollTop


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

    _destroyItem: (item) =>
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
        selection = window.getSelection()
        @_destroyItem(lastItem)


angular.module('ui.scroller', [])

.directive 'scrollerViewport', ->
    restrict: 'A'
    transclude: true
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
