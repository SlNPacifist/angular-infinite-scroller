angular.module('application', ['ui.scroller'])
    .controller 'mainController', [ '$scope', ($scope)->
        $scope.data = [
            'first line'
            'second line'
            'third line'
            'fourth line'
        ]
    ]

angular.bootstrap(document, ["application"])