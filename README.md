# TI 1 - Deploying a Monitoring xApp as a WASM instance
[Link to Repo](https://github.com/pedromartinssouza/ti1-final)


---

## Table of Contents

- [Introduction](#introduction)
- [Prerequisites](#prerequisites)
- [Set-up](#set-up)
  - [1. Clone the Repository](#1-clone-the-repository)
  - [2. Create the Cluster using the kind-cluster-template.yaml file](#2-create-the-cluster-using-the-kind-cluster-templateyaml-file)
  - [3. Run chartmuseum](#3-run-chartmuseum)
  - [4. Create namespaces for the RIC and the xApps](#4-create-namespaces-for-the-ric-and-the-xapps)
  - [5. Enable WASM in the cluster through kwasm-operator](#5-enable-wasm-in-the-cluster-through-kwasm-operator)
  - [6. Deploy the Near-RT RIC](#6-deploy-the-near-rt-ric)
  - [7. Deploy the xApps that use Docker](#7-deploy-the-xapps-that-use-docker)
  - [8. Convert the Monitoring xApp to WASM](#8-convert-the-monitoring-xapp-to-wasm)
  - [9. Deploy the WASM xApp](#9-deploy-the-wasm-xapp)
- [Related Repositories](#related-repositories)

---

## Introduction

This repository was created as part of [Pedro Martins de Souza](https://github.com/pedromartinssouza)'s Masters Degree thesis. It contains all the necessary repositories and files to create a Kubernetes cluster, deploy a Near-RT RIC to it, enable xApps in it, and deploy native WASM applications to the Cluster's nodes. The overall process is relatively simple, and will be explained in details below.

## Prerequisites

Before you begin, ensure you have met the following requirements:

- **Operating System**: Linux (tested in Ubuntu 22.04)
- **Software**:
  - [Docker](https://docs.docker.com/get-docker/) installed and running
  - [Chartmuseum](https://chartmuseum.com/) installed and running
  - [Kind](https://kind.sigs.k8s.io/) installed
  - [Helm](https://helm.sh/docs/intro/install/) installed
  - [Python 3](https://www.python.org/downloads/) installed
  - [kubectl](https://kubernetes.io/docs/tasks/tools/) installed and configured
  - [c2w/container2wasm](https://github.com/ktock/container2wasm) installed
  - [wasm-to-oci](https://github.com/engineerd/wasm-to-oci) installed and configured with access to your OCI registry
- **Permissions**:
  - A classic Personal Access Token (PAT) to your GitHub package registry (which will be obtained in step 8)

## Set-up

Configuring the cluster is a relatively easy process, but has some tricky steps.

### 1. Clone the Repository

```bash
git clone https://github.com/pedromartinssouza/ti1-final
cd ti1-final
```

### 2. Create the Cluster using the kind-cluster-template.yaml file

We need a cluster with 3 nodes, one for control-plane and two worker nodes, one of which will be compatible with WASM. The kind-cluster-template.yaml file has the necessary configurations for it.

```bash
kind create cluster --config ./kind-cluster-template.yaml
```

### 3. Run chartmuseum

With chartmuseum installed, we can run it with the following command:

```bash
chartmuseum --debug --port 6873 --storage local --storage-local-rootdir $HOME/helm/chartsmuseum/
```

Keep it open in a dedicated terminal and move on to a new terminal to perform the following steps.

### 4. Create namespaces for the RIC and the xApps

```bash
kubectl create namespace ricplt
kubectl create namespace ricxapp
```

### 5. Enable WASM in the cluster through kwasm-operator

To simplify the set-up of WASM, WASI and WasmEdge (our chosen runtime), we will use the kwasm-operator. It is a Kubernetes operator that manages the installation of the necessary components for WASM in nodes of our choise, through:

```bash
# Navigate to the kwasm-operator directory
cd kwasm-operator
# Add helm repo
helm repo add kwasm http://kwasm.sh/kwasm-operator/
# Install operator
helm install -n kwasm --create-namespace kwasm-operator kwasm/kwasm-operator
# Annotate single node
kubectl annotate node kind-worker2 kwasm.sh/kwasm-node=true
# Return to the root directory
cd ..
```

With this, we have enabled WASM in the cluster and annotated the node kind-worker2 to be the one that will run WASM applications. It's important to remember this, as we will need to specify this node when deploying the WASM applications.

### 6. Deploy the Near-RT RIC

The Near-RT RIC is a Kubernetes-based RIC that is used to manage the xApps. It is a complex system, but we have simplified the deployment process through the use of Helm charts.

There are some custom configurations that need to be made to the Helm charts before deployment happens. These configurations are in the "replacements" directory, and can be applied with:

```bash
cp -rf ./replacements/ric-dep/helm/e2mgr ./ric-plt-ric-dep/helm/e2mgr
cp -rf ./replacements/ric-dep/helm/rtmgt ./ric-plt-ric-dep/helm/rtmgt
cp -rf ./replacements/ric-dep/RECIPE_EXAMPLE ./ric-plt-ric-dep/RECIPE_EXAMPLE
```

Finally, we can deploy the Near-RT RIC with the following commands:

```bash
# Navigate to the ric-plt-ric-dep directory
cd ric-plt-ric-dep
# Install ric-common templates
./install_common_templates_to_helm.sh
# Navigate to the bin directory
cd bin
# Deploy the RIC
./install -f ../RECIPE_EXAMPLE/example_recipe_latest_stable.yaml
# Return to the root directory
cd ../..
```

With this, the basic components for the Near RT RIC are deployed. We can now move on to the xApps.

### 7. Deploy the xApps that use Docker

xApps can now be deployed to the cluster, either running through Docker or WASM. To start, we will deploy a xApp that uses a Docker image.

```bash
# Navigate to the Energy-Saver-Tests/scripts directory
cd Energy-Saver-Tests/scripts
# Deploy the E2 Node simulator 1
helm upgrade --install e2node1 ../helm-charts/e2sim-helm \
    --set image.args.e2term=10.43.0.225 \
    --set image.args.mcc=724 \
    --set image.args.mnc=011 \
    --set image.args.nodebid=1 \
    --set image.args.port=30001 \
    -n ricplt --wait
# Deploy the E2 Node simulator 2
helm upgrade --install e2node2 ../helm-charts/e2sim-helm \
    --set image.args.e2term=10.43.0.225 \
    --set image.args.mcc=724 \
    --set image.args.mnc=011 \
    --set image.args.nodebid=2 \
    --set image.args.port=30001 \
    -n ricplt --wait
# Deploy the E2 Node simulator 3
helm upgrade --install e2node3 ../helm-charts/e2sim-helm \
    --set image.args.e2term=10.43.0.225 \
    --set image.args.mcc=724 \
    --set image.args.mnc=011 \
    --set image.args.nodebid=3 \
    --set image.args.port=30001 \
    -n ricplt --wait
# Deploy the E2 Node simulator 4
helm upgrade --install e2node4 ../helm-charts/e2sim-helm \
    --set image.args.e2term=10.43.0.225 \
    --set image.args.mcc=724 \
    --set image.args.mnc=011 \
    --set image.args.nodebid=4 \
    --set image.args.port=30001 \
    -n ricplt --wait
```

With the E2 Nodes deployed, we can now deploy the xApp instances:

```bash
# Deploy the xApp Monitoring instance 1
helm upgrade --install xappmonitoring1 ../helm-charts/bouncer-xapp \
    --set containers[0].image.name="zanattabruno/bouncer-rc" \
    --set containers[0].image.registry="registry.hub.docker.com" \
    --set containers[0].image.tag="TNSM-24" \
    --set containers[0].name="bouncer-xapp" \
    --set containers[0].command[0]="b_xapp_main" \
    --set containers[0].args[0]="--mcc" \
    --set containers[0].args[1]="724" \
    --set containers[0].args[2]="--mnc" \
    --set containers[0].args[3]="011" \
    --set containers[0].args[4]="--nodebid" \
    --set containers[0].args[5]="1" \
    -n ricxapp --wait

# Deploy the xApp Monitoring instance 2
helm upgrade --install xappmonitoring2 ../helm-charts/bouncer-xapp \
    --set containers[0].image.name="zanattabruno/bouncer-rc" \
    --set containers[0].image.registry="registry.hub.docker.com" \
    --set containers[0].image.tag="TNSM-24" \
    --set containers[0].name="bouncer-xapp" \
    --set containers[0].command[0]="b_xapp_main" \
    --set containers[0].args[0]="--mcc" \
    --set containers[0].args[1]="724" \
    --set containers[0].args[2]="--mnc" \
    --set containers[0].args[3]="011" \
    --set containers[0].args[4]="--nodebid" \
    --set containers[0].args[5]="2" \
    -n ricxapp --wait

# Deploy the xApp Monitoring instance 3
helm upgrade --install xappmonitoring3 ../helm-charts/bouncer-xapp \
    --set containers[0].image.name="zanattabruno/bouncer-rc" \
    --set containers[0].image.registry="registry.hub.docker.com" \
    --set containers[0].image.tag="TNSM-24" \
    --set containers[0].name="bouncer-xapp" \
    --set containers[0].command[0]="b_xapp_main" \
    --set containers[0].args[0]="--mcc" \
    --set containers[0].args[1]="724" \
    --set containers[0].args[2]="--mnc" \
    --set containers[0].args[3]="011" \
    --set containers[0].args[4]="--nodebid" \
    --set containers[0].args[5]="3" \
    -n ricxapp --wait

# Deploy the xApp Monitoring instance 4
helm upgrade --install xappmonitoring4 ../helm-charts/bouncer-xapp \
    --set containers[0].image.name="zanattabruno/bouncer-rc" \
    --set containers[0].image.registry="registry.hub.docker.com" \
    --set containers[0].image.tag="TNSM-24" \
    --set containers[0].name="bouncer-xapp" \
    --set containers[0].command[0]="b_xapp_main" \
    --set containers[0].args[0]="--mcc" \
    --set containers[0].args[1]="724" \
    --set containers[0].args[2]="--mnc" \
    --set containers[0].args[3]="011" \
    --set containers[0].args[4]="--nodebid" \
    --set containers[0].args[5]="4" \
    -n ricxapp --wait
```

Finally, we will deploy the Handover xApp:

```bash
helm upgrade --install handover-xapp ../helm-charts/handover-xapp -n ricxapp --wait
# Return to the root directory
cd ../..
```

At the end, the Monitoring xApps and the Handover xApp can be found in the ricxapp namespace. They may be in CrashLoopBackOff state, but that is expected. Finally, we can proceed with the deployment of the WASM xApp.

### 8. Convert the Monitoring xApp to WASM

The WASM xApp we will deploy is a copy of the Monitoring xApp, converted through a tool called container2wasm. While it won't have the same performance as a native WASM application, it will serve as a proof of concept for the deployment of WASM applications in the Near-RT RIC.

To start, we need to convert the Monitoring xApp into a WASM file (this process may take a while):

```bash
c2w registry.hub.docker.com/zanattabruno/bouncer-rc:TNSM-24
```

This will output a file called out.wasm. We can now convert and publish this file to the OCI registry. In case you are not familiar with it, read the documentation at https://docs.github.com/en/packages/working-with-a-github-packages-registry/working-with-the-container-registry, where you will find information on how to authenticate to the registry using a PAT (Peronal Access Token). After that, you can convert and publish the WASM file with the following commands:

```bash
# Export your credentials to the environment
export NAME="<YOUR_ACCOUNT_NAME>"
export USERNAME="<YOUR_USERNAME>"
export CR_PAT="<YOUR_PAT>"
# Login to the registry
echo $CR_PAT | docker login ghcr.io -u $USERNAME --password-stdin
# Convert the WASM file to OCI
w2oci push ./out.wasm $NAME/ti1-final:v1 --log debug
```

Once this is done, you will need to generate a Secret that will enable your cluster to pull the WASM image. This can be done with the following command:

```bash
chmod +x ./generate_secret_manifest.sh
./generate_secret_manifest.sh $CR_PAT
```

This command will output a file called secret.yaml. You can now apply this file to the cluster with the following command:

```bash
kubectl apply -f secret.yaml -n ricxapp
```

With this, the cluster should be fully set-up and ready to run the WASM xApp.

### 9. Deploy the WASM xApp

Finally, we can deploy the WASM xApp to the cluster. This can be done in a few simple steps:

```bash
# Copy the helm-chart in replacements to the Energy-Saver-Tests directory
cp -rf ./replacements/helm-charts/bouncer-xapp-wasm ./Energy-Saver-Tests/helm-charts/bouncer-xapp-wasm
# Navigate to the Energy-Saver-Tests directory
cd Energy-Saver-Tests
# Deploy the WASM xApp
helm upgrade --install xappmonitoring1wasm ../helm-charts/bouncer-xapp-wasm \
    --set containers[0].image.name="${NAME}/ti1-final" \
    --set containers[0].image.registry="ghcr.io" \
    --set containers[0].image.tag="latest" \
    --set containers[0].name="bouncer-xapp-wasm" \
    --set containers[0].command[0]="b_xapp_main" \
    --set containers[0].args[0]="--mcc" \
    --set containers[0].args[1]="724" \
    --set containers[0].args[2]="--mnc" \
    --set containers[0].args[3]="011" \
    --set containers[0].args[4]="--nodebid" \
    --set containers[0].args[5]="4" \
    -n ricxapp --wait
```

With this, the WASM xApp should be deployed to the cluster. Again, it may be in CrashLoopBackOff state, but that is expected.

## Related Repositories

- [bouncer-rc](https://github.com/alexandre-huff/bouncer-rc)
- [e2interface](https://gerrit.o-ran-sc.org/r/admin/repos/sim/e2-interface,general)
- [ric-plt-ric-dep](https://github.com/o-ran-sc/ric-plt-ric-dep)
- [kwasm-operator](https://github.com/KWasm/kwasm-operator)
- [Energy-Saver-Tests](https://github.com/zanattabruno/Energy-Saver-Tests)

