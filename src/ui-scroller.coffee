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
        item.scope.destroy()

updateRenderedElements = (prev_elements, next_elements) ->
    new_rendered_elements = {}
    rendered_elements_to_delete = []
    for data, i in next_elements
        if i of prev_elements
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


angular.module('ui.scroller', [])

.directive 'scrollerViewport', ->
    restrict: 'A'
    transclude: true
    scope: {'scrollerSource': '='}
    controller: ['$scope', ($scope) ->
        $scope.list = []
        @$scope = $scope
        $scope.$watch 'scrollerSource', (value) ->
            $scope.list = ({index: i, line: line} for line, i in value)
        return null # Anything returned here will be used instead of controller
    ]

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
