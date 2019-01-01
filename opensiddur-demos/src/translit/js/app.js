/* Transliteration demo application
 * Copyright 2013,2018 Efraim Feinstein, efraim@opensiddur.org
 * Licensed under the GNU Lesser General Public License, version 3 or later
 */
var httpPrefix = "/exist/restxq"; 

/* retrieve an API error return value and return the string */
var getApiError = function(data) {
  return $($.parseXML(data)).find("message").text();
};

var OpenSiddurTranslitDemoApp = 
    angular.module(
            'OpenSiddurTranslitDemoApp', []
    );

OpenSiddurTranslitDemoApp.controller(
        'MainCtrl',
        ['$scope', '$http',
        function ($scope, $http) {
            console.log("Demo app controller.")
          
            $scope.errorMessage = "";
            $scope.tables = [];             // transliteration tables
            $scope.selectedTable = { "demoApi" : undefined, "api" : undefined, "name" : "None" };
            $scope.text = "";
            $scope.transliterated = "";
            $scope.list = function () {
                $http.get(
                    httpPrefix + "/api/data/transliteration",
                    {
                    transformResponse: function(data, headers) {
                        console.log(data);
                        var tables = [];
                        var n = 0;
                        $("a.document", data).each(
                                function () {
                                    var element = $(this);
                                    tables.push({
                                        "name" : element.text(),
                                        "api" : element.attr("href"),
                                        "demoApi" : element.attr("href").replace("/api/data/transliteration/", "/api/utility/translit/")
                                    });
                                    
                                }
                        );
                        return tables;
                    }
                  })
                .success(
                    function(data, status, headers, config) {
                        $scope.errorMessage = "";
                        console.log(data);
                        $scope.tables = data;
                    }
                )
                .error(
                    function(data, status, headers, config) {
                      $scope.errorMessage = getApiError(data)
                    }
                );
              
          };
            $scope.transliterate = function () {
                $http.post(
                    $scope.selectedTable.demoApi,
                    "<transliterate xml:lang='he'>" + $scope.text + "</transliterate>", 
                    {
                    headers : {
                        "Content-Type" : "application/xml"
                    },
                    responseType: "xml"
                    }
                  )
                .success(
                    function(data, status, headers, config) {
                        $scope.errorMessage = "";
                        console.log(data);
                        $scope.transliterated = $(data).html();
                    }
                )
                .error(
                    function(data, status, headers, config) {
                      $scope.errorMessage = getApiError(data)
                    }
                );
              
          };
          
          $scope.list();
        }
        ]
      );
