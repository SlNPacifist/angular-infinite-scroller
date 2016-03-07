angular.module('application', ['ui.scroller'])
    .controller 'mainController', [ '$scope', ($scope)->
        $scope.data = [
            'first line'
            'second line'
            'third line'
            'fourth line'
        ]

        window.setTimeout ->
            $scope.$apply ->
                $scope.data = [
                    'first line'
                    'second line'
                    'third line'
                    'fourth line'
                    'fifth line'
                    'sixth line'
                ]
        , 3000
    ]

angular.bootstrap(document, ["application"])