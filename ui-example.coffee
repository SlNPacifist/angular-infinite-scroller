angular.module('application', ['ui.scroller'])
    .controller 'mainController', [ '$scope', ($scope)->
        $scope.data = ("Line #{i}" for i in [1..100])
        $scope.getData = (index, count, callback) ->
            window.setTimeout ->
                end = index + count
                index = Math.max(index, 0)
                end = Math.max(end, 0)
                callback(null, $scope.data[index...end])
            , 0
        $scope.scrollerViewportSettings =
            paddingTop:
                min: 100
                max: 150
            afterScrollWaitTime: 100
    ]

angular.bootstrap(document, ["application"])