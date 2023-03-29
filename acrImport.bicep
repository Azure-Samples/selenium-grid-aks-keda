param acrName string 
param location string =  resourceGroup().location

  //'docker.io/springcommunity/spring-petclinic-visits-service:2.5.1'
var seleniumGridImages = [
  'docker.io/selenium/router:latest'
  'docker.io/selenium/distributor:latest'
  'docker.io/selenium/event-bus:latest'
  'docker.io/selenium/sessions:latest'
  'docker.io/selenium/session-queue:latest'
  'docker.io/selenium/hub:latest'
  'docker.io/selenium/node-chrome:latest'
  'docker.io/selenium/node-firefox:latest'
  'docker.io/selenium/node-edge:latest'
]

module acrImport 'br/public:deployment-scripts/import-acr:2.0.1' = {
  name: 'Import-seleniumGrid-Images-${acrName}'
  params: {
    acrName: acrName
    location: location
    images: seleniumGridImages
  }
}
