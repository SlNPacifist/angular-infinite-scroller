angular.module('application', ['ui.scroller'])
    .controller 'mainController', [ '$scope', ($scope)->
        $scope.data = ("Line #{i}" for i in [1..100])
        $scope.getData = (index, count, callback) ->
            window.setTimeout ->
                callback(null, $scope.data[index...index+count])
            , 0
        $scope.scrollerViewportSettings =
            paddingTop:
                min: 100
                max: 150
            afterScrollWaitTime: 100
    ]

angular.bootstrap(document, ["application"])