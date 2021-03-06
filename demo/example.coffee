angular.module('application', ['scroller'])
    .controller 'mainController', [ '$scope', ($scope)->
        $scope.data = ("Line number #{i}, text is long enough" for i in [1..100])
        $scope.getData = (index, count, callback) ->
            window.setTimeout ->
                end = index + count
                index = Math.max(index, 0)
                end = Math.max(end, 0)
                callback($scope.data[index...end])
            , 2000
    ]

angular.bootstrap(document, ["application"])