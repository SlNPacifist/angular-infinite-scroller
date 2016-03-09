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

class ScrollerViewport
    constructor: (@_scope, @_element) ->
        @_items_requesting = false
        @_getItems = @_scope.scrollerSource.bind(@)
        @_watchHandler = window.setInterval(@_updateState, 1000)
        @_drawnItems = []
        @_scope.list = @_drawnItems
        @_buffer = {
            start: 0
            length: 0
        }

    _requestMoreItems: =>
        return if @_items_requesting
        @_items_requesting = true
        pos = @_buffer.start + @_buffer.length
        @_getItems pos, 10, (err, res) =>
            @_items_requesting = false
            if !err
                @_addBufferItems(pos, res)

    _addBufferItems: (pos, items) =>
        console.log("Adding buffer items")
        if pos == @_buffer.start + @_buffer.length
            # add items to end
            for item, idx in items
                @_buffer[pos + idx] = item
            @_buffer.length += items.length

    _updateState: =>
        bottom = @_element.scrollHeight - @_element.scrollTop
        if bottom <= @_element.offsetHeight
            @_tryDrawBottomItems()

    _pushDrawnItem: (item) =>
        newItems = @_drawnItems[..]
        newItems.push(item)
        @_drawnItems = newItems
        @_scope.$apply =>
            @_scope.list = @_drawnItems
            window.setTimeout(@_updateState, 0)

    _tryDrawBottomItems: =>
        if @_drawnItems.length > 0
            neededIndex = @_drawnItems[@_drawnItems.length - 1].index + 1
        else
            neededIndex = 0
        if neededIndex of @_buffer
            @_pushDrawnItem({index: neededIndex, data: @_buffer[neededIndex]})
        else
            @_requestMoreItems()


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
