# Selenium Grid scaling with KEDA on AKS

This sample shows how to create an Azure Kubernetes Service optimised to work with [Selenium Grid](https://www.selenium.dev/documentation/grid/) for node autoscaling.
Dedicated browser node pools will scale up from zero instances using KEDA (Kubernetes Event-driven Autoscaling) which monitors the Selenium test queue.

Seperation of the browser node pools isn't strictly essential to this sample, but it does provides;

- Overall faster autoscale out
- Cost visbility through node pool tagging
- The ability to limit specific browser-nodes tests to a lower maximum node pool size
- A showcase for multi-nodepool queue based autoscaling

## Features

This sample shows the following features:

* AKS Configured with multiple node pools, with some `Scaling from Zero`
* Using `Node Selectors` to map AKS node pools to Selenium browser nodes
* Selenium Queue triggered cluster scaling using `Event Driven Autoscaling` with KEDA

## Overview

```mermaid
graph TB
    tst(Build agent run test)--> hub
    style tst fill:#F25022,stroke:#333,stroke-width:4px
    usr(User workstation run test)--> hub
    style usr fill:#F25022,stroke:#333,stroke-width:4px
    subgraph AKS Static User Pool
    hub(selenium hub)-->queue
    queue(selenium queue)
    api(selenium api)-->queue
    end
    subgraph Keda
    trigger-->|Things in the queue? |api
    scale(Scale Logic)
    end
    subgraph AKS
    scale-->sch
    sch(Kubernetes Scheduler)
    end
    subgraph AKS Chrome User Pool
    sch-->|Scale up|cse
    cse(Autoscale triggered)-->cna
    cna(Node Available)-->crt(Run test)
    crt-->csd(Scale back)
    end
    subgraph AKS Firefox User Pool
    sch-->|Scale up|fse
    fse(Autoscale triggered)-->fna
    fna(Node Available)-->frt(Run test)
    frt-->fsd(Scale back)
    end
    subgraph AKS Edge User Pool
    sch-->|Scale up|ese
    ese(Autoscale triggered)-->ena
    ena(Node Available)-->ert(Run test)
    ert-->esd(Scale back)
    end
```

## Getting Started

### Prerequisites

Interaction with Azure is done using the [Azure CLI](https://docs.microsoft.com/cli/azure/), [Helm](https://helm.sh/docs/intro/install/) and [Kubectl](https://kubernetes.io/docs/tasks/tools/#kubectl) are required for accessing Kubernetes packages and installing them to the cluster.

The [Selenium IDE CLI](https://www.selenium.dev/selenium-ide/docs/en/introduction/command-line-runner) (Selenium Side Runner) is used to add tests to the queue. The side runner is provided as a npm package which requires Node & Npm to be installed.

> A dev container and GitHub action are included in this repo to make this easier for users who don't have all these tools set up locally.

### Installation

#### AKS

Using [AKS Construction](https://github.com/Azure/Aks-Construction), we can quickly set up pair of AKS clusters in different virtual networks with connectivity between.
One cluster will run the Selenium Grid, and the other will run a sample application.

```bash
az deployment sub create -u https://github.com/Azure/AKS-Construction/releases/download/0.6.2/sample-peeredvnet-main.json -l WestEurope -p adminPrincipleId=$(az ad signed-in-user show --query objectId --out tsv)
az aks get-credentials -n aks-grid-stest -g rg-stest-selenium --overwrite-existing
```

#### Keda

Install Keda into a new Keda namespace.

```bash
helm repo add kedacore https://kedacore.github.io/charts
helm repo update
kubectl create namespace keda
helm install keda kedacore/keda --namespace keda
```

#### Selenium Grid

Install Selenium Grid in the default Kubernetes namespace.

```bash
git clone https://github.com/seleniumhq/docker-selenium.git

chromeReplicas=0
firefoxReplicas=0
edgeReplicas=0
helm upgrade --install selenium-grid docker-selenium/chart/selenium-grid/. --set hub.serviceType=LoadBalancer,chromeNode.replicas=$chromeReplicas,firefoxNode.replicas=$firefoxReplicas,edgeNode.replicas=$edgeReplicas,chromeNode.nodeSelector.selbrowser=chromepool,firefoxNode.nodeSelector.selbrowser=firefoxpool,edgeNode.nodeSelector.selbrowser=edgepool
```

> Please note; The Selenium Dashboard is publicly exposed for ease of access, in most deployments this would not be public.

#### Keda Triggers

Configures KEDA to look at the Selenium Grid GraphQL endpoint. Note the fqdn includes the service name and namespace of the Selenium-Hub service.

> The URL value from kedaSeleniumTriggers.yml is : http://selenium-hub.default.svc.cluster.local:4444/graphql' If you have deployed Selenium to a different namespace then you will need to change this.

```bash
kubectl apply -f kedaSeleniumTriggers.yml
```

#### Selenium Side Runner CLI

```bash
npm install -g selenium-side-runner
```

### Quickstart

Open the Azure Portal, and check that the 5 node pools are present and correct. Note that 3 of the pools should contain no instances.

![AKS Node Pools](docassets/AKSNodePools.png)

Now that the Cluster is ready, we can load up some tests to the Selenium Grid.

1. Get the Public IP address the Selenium Hub is running on.

```bash
HUBPUBLICIP=$(kubectl get svc -l app=selenium-hub -o=jsonpath='{.items[0].status.loadBalancer.ingress[0].ip}')
echo "Selenium Grid is accessible here: http://$HUBPUBLICIP:4444"
```

2. Use the Selenium Side Runner CLI to send some basic tests to the Grid

```bash
echo Node $(node -v)
echo Npm $(npm -v)
echo Selenium side runner $(selenium-side-runner -V)

GridHubURL="http://$HUBPUBLICIP:4444"
PathToSeleniumTests="testsuites/basic/*"
selenium-side-runner --server $GridHubURL $PathToSeleniumTests --debug
```

## Demo

A demo app is included to show cross network connectivity, and more typical Selenium tests.

1. Install the Azure Voting App sample on the other cluster

```bash
az aks get-credentials -n aks-app-stest -g rg-stest-testapp --overwrite-existing
kubectl apply -f https://raw.githubusercontent.com/Azure-Samples/azure-voting-app-redis/master/azure-vote-all-in-one-redis.yaml
```

2. Grab the application IP

```bash
APPPUBLICIP=$(kubectl get svc azure-vote-front -o=jsonpath='{.status.loadBalancer.ingress[0].ip}')
```

3. Run the application specific tests

```bash
PathToSeleniumTests="testsuites/azurevote/*"
selenium-side-runner --server $GridHubURL $PathToSeleniumTests --base-url http://$APPPUBLICIP --debug
```

## Cleanup

Two new resource groups will have been created in your subscription, these should be deleted.

```azurecli
az group delete -n rg-stest-selenium
az group delete -n rg-stest-testapp
```

## Resources

- https://github.com/seleniumhq/docker-selenium
- https://keda.sh/docs/2.6/scalers/selenium-grid-scaler/
- https://azure.github.io/AKS-Construction/
