angular.module('application', ['ui.scroller'])
    .controller 'mainController', [ '$scope', ($scope)->
        $scope.data = [
            {index: 0, line: 'first line'}
            {index: 1, line: 'second line'}
            {index: 2, line: 'third line'}
            {index: 3, line: 'fourth line'}
        ]

        window.setTimeout ->
            $scope.$apply ->
                $scope.data = [
                    {index: 2, line: 'third line'}
                    {index: 3, line: 'fourth line'}
                    {index: 4, line: 'fifth line'}
                    {index: 5, line: 'sixth line'}
                ]
        , 3000
    ]

angular.bootstrap(document, ["application"])