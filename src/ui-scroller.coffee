insertAfter = (element, target) ->
    parent = target.parentNode
    if target.nextSibling
        next = target.nextSibling
        parent.insertBefore(element, next)
    else
        parent.appendChild(element)

removeRenderedElements = (elements_to_delete) ->
    for _, item of elements_to_delete
        item.node.remove()
        item.scope.$destroy()

updateRenderedElements = (prev_elements, next_elements) ->
    new_rendered_elements = {}
    rendered_elements_to_delete = []
    for data in next_elements
        i = data.index
        if data.index of prev_elements
            new_rendered_elements[i] = prev_elements[i]
            delete prev_elements[i]
        else
            new_rendered_elements[i] = {scope: null, clone: null, data: data}
    new_rendered_elements

updateElementsDOM = (insert_point, rendered_elements, $transclude) ->
    for _, item of rendered_elements
        if item.scope
            insertAfter(item.node, insert_point)
        else
            $transclude (node, scope) ->
                item.scope = scope
                item.node = node[0]
                item.scope.scrData = item.data
                insertAfter(item.node, insert_point)
        insert_point = item.node


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
    constructor: (@_scope, @_element) ->
        @_settings =
            paddingTop:
                min: 20
                max: 100
            paddingBottom:
                min: 20
                max: 100
            itemsPerRequest: 10
        @_requesting_top_items = false
        @_requesting_bottom_items = false
        @_getItems = @_scope.scrollerSource.bind(@)
        @_watchHandler = window.setInterval(@_updateState, 1000)
        @_drawnItems = []
        @_scope.list = @_drawnItems
        @_buffer = new Buffer

    _requestMoreTopItems: =>
        return if @_requesting_top_items
        @_requesting_top_items = true
        start = @_buffer.start - @_settings.itemsPerReqeust
        @_getItems start, @_settings.itemsPerRequest, (err, res) =>
            @_requesting_top_items = false
            if !err
                @_buffer.addItemsToStart(res)

    _requestMoreBottomItems: =>
        return if @_requesting_bottom_items
        @_requesting_bottom_items = true
        start = @_buffer.start + @_buffer.length
        @_getItems start, @_settings.itemsPerRequest, (err, res) =>
            @_requesting_bottom_items = false
            if !err
                @_buffer.addItemsToEnd(res)

    _updateState: =>
        if @_element.scrollTop > @_settings.paddingTop.max
            @_removeTopDrawnItem()
        else if @_element.scrollTop < @_settings.paddingTop.min
            @_tryDrawTopItem()

        paddingBottom = @_element.scrollHeight - @_element.scrollTop - @_element.offsetHeight
        if paddingBottom < @_settings.paddingBottom.min
            @_tryDrawBottomItem()
        else if paddingBottom > @_settings.paddingBottom.max
            @_removeBottomDrawnItem()

    _updateDrawnItems: (@_drawnItems) =>
        @_scope.$apply =>
            @_scope.list = @_drawnItems
            window.setTimeout(@_updateState, 0)

    _addTopDrawnItem: (item) =>
        @_updateDrawnItems([item].concat(@_drawnItems))

    _addBottomDrawnItem: (item) =>
        @_updateDrawnItems(@_drawnItems.concat(item))

    _removeTopDrawnItem: =>
        @_updateDrawnItems(@_drawnItems[1..])

    _removeBottomDrawnItem: =>
        @_updateDrawnItems(@_drawnItems[...-1])

    _tryDrawTopItem: =>
        if @_drawnItems.length > 0
            neededIndex = @_drawnItems[0].index - 1
        else
            neededIndex = -1
        if neededIndex of @_buffer
            @_addTopDrawnItem({index: neededIndex, data: @_buffer[neededIndex]})
        else
            @_requestMoreTopItems()

    _tryDrawBottomItem: =>
        if @_drawnItems.length > 0
            neededIndex = @_drawnItems[@_drawnItems.length - 1].index + 1
        else
            neededIndex = 0
        if neededIndex of @_buffer
            @_addBottomDrawnItem({index: neededIndex, data: @_buffer[neededIndex]})
        else
            @_requestMoreBottomItems()


angular.module('ui.scroller', [])

.directive 'scrollerViewport', ->
    restrict: 'A'
    transclude: true
    scope: {'scrollerSource': '='}
    controller: ['$scope', ($scope) ->
        @$scope = $scope
        return null # Anything returned here will be used instead of controller
    ]
    link: ($scope, $element, $attrs) ->
        port = new ScrollerViewport($scope, $element[0])

.directive 'scrollerItem', ->
    restrict: 'A'
    require: '^^scrollerViewport'
    transclude: 'element'
    scope: {}
    link: ($scope, $element, $attrs, viewportCtrl, $transclude) ->
        rendered_elements = {}
        viewportCtrl.$scope.$watch 'list', (value) ->
            new_rendered_elements = updateRenderedElements(rendered_elements, value)
            removeRenderedElements(rendered_elements)
            rendered_elements = new_rendered_elements
            updateElementsDOM($element[0], rendered_elements, $transclude)
