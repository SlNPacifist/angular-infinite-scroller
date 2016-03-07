getInsertAfterFunction = (element) ->
    parent = element.parentNode
    if element.nextSibling
        target = element.nextSibling
        (el) ->
            parent.insertBefore(el, target)
    else
        (el) ->
            parent.appendChild(el)

removeRenderedElements = (elements_to_delete) ->
    for _, item of elements_to_delete
        item.node.remove()
        item.scope.destroy()

updateRenderedElements = (prev_elements, next_elements) ->
    new_rendered_elements = {}
    rendered_elements_to_delete = []
    for item, i in next_elements
        if i of prev_elements
            new_rendered_elements[i] = item
            delete prev_elements[i]
        else
            new_rendered_elements[i] = {scope: null, clone: null, value: item}
    new_rendered_elements

updateElementsDOM = (start, rendered_elements, $transclude) ->
    insert = getInsertAfterFunction(start)
    for _, item of rendered_elements
        if item.scope
            insert(item.node)
        else
            $transclude (node, scope) ->
                item.scope = scope
                item.node = node[0]
                item.scope.value = item.value
                insert(item.node)


angular.module('ui.scroller', [])

.directive 'scrollerViewport', ->
    restrict: 'A'
    transclude: true
    scope: {'scrollerSource': '='}
    controller: ['$scope', ($scope) ->
        $scope.list = []
        @$scope = $scope
        $scope.$watch 'scrollerSource', (value) ->
            $scope.list = ({line: line} for line in value)
            console.log("Setting new source", value, $scope.list)
        return null # Anything returned here will be used instead of controller
    ]

.directive 'scrollerItem', ->
    restrict: 'A'
    require: '^^scrollerViewport'
    transclude: true
    scope: {}
    link: ($scope, $element, $attrs, viewportCtrl, $transclude) ->
        rendered_elements = {}
        viewportCtrl.$scope.$watch 'list', (value) ->
            new_rendered_elements = updateRenderedElements(rendered_elements, value)
            removeRenderedElements(rendered_elements)
            rendered_elements = new_rendered_elements
            updateElementsDOM($element[0], rendered_elements, $transclude)
