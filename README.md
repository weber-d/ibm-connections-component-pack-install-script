# IBM Connections Component Pack (Pink) 6.0.0.7 Install script

IBM released their Component Pack (formerly known as _Pink_) in version 6.0.0.7 for Connections. It contains awesome technology based on modern tools like Docker and Kubernetes. Unfortunately, it's hard to install and doesn't care about restrictions on custom storage providers line nfs. This script should make it consistent and create some documentation, so that we can full automate this using Ansible later.

## Prerequisites

- Since IBM doesn't have a Docker registry nor Helm repo, they only provide a package with exported packed images. See [this documentation](https://docs.docker.com/registry/deploying/)
- [Manually deploy Component Pack archives to this registry](https://www.ibm.com/support/knowledgecenter/en/SSYGQH_6.0.0/admin/install/cp_install_push_docker_images.html)
- Clone this repo to a work/or jumphost that can access all required machines
- Kubernetes cluster: I'm using [Rancher's rke](https://github.com/rancher/rke)

## Installation process

### Fix broken pvc

[IBM outsourced their pvcs to `connections-persistent-storage-nfs-0.1.0.tgz`](https://www.ibm.com/support/knowledgecenter/en/SSYGQH_6.0.0/admin/install/cp_install_push_docker_images.html). _Think about before you do it!_ It's not only unflexible to have everything mounted in `/pv-connections`. It will balso break modern dynamic provisioners like [nfs-client-provisioner](https://github.com/helm/charts/tree/master/stable/nfs-client-provisioner) since [IBM uses incompatible labels](https://github.com/helm/charts/issues/11707).

Since we noticed that all apps automatically allocate their pvcs anyway, we skipped the pvc archive. For `customizer` and `elasticsearch`, this doesn't seem to apply. So I reversed the required pvcs from those archive and commented out all problematic labels. You need to apply them:

```bash
kubectl apply -f pvc/customizer-pvc.yml
kubectl apply -f pvc/elasticsearch-pvc.yml
```

### Set evironment variables

Many valules like the k8s namespace are widely used across all commands. To keep things DRY and flexible, we centralized them using a few variables. Modify and set them according to your setup:

```bash
# Temp docker registry with IBMs images pushed to
DOCKERREGISTRY=registry.example.com
REGISTRYUSER=admin
REGISTRYPASSWORD=xxx
# Path to extracted IC-ComponentPack-6.0.0.7 folder
DOWNLOADPATH=/install/IC-ComponentPack-6.0.0.7
# IBM Connections
CNXDOMAIN=cnx.local
ICADMIN=icadmin
# Important to escape dollar sign since otherwise bash would recognize it as variable - Or use single ticks 'value'
ICADMINPW=yyy
ICCNXHOST=cnx.local
# Host or IP of your kubernetes master node
K8SMASTERIP=k8s.local
CLUSTERNAME=cluster01.internal
STORAGECLASS=nfs-client
NAMESPACE=connections-test
# 'General' password used for redis, solr and in some places of elasticsearch like ca password
COMPPASSWORD=zzz
```

Now you can deploy the packed helm charts using `install.sh`. Since we ran into different issues, I'd recomment not to execute the hole script. Instead, copy/execute them command by command.

You may ask why I generate long, complex `--set` calls on CLI instead of a clean `yaml` file passed to helm. Well, I tried this but gave it up since the IBM charts sometimes have default values set in their charts (or parent chart). Currently it doesn't seem possible to override them, expect using `--set`. A fix is already merged, so I'd expect the release soon.

### Fix for custom-named clusters

**Dont know the name of your cluster?** Well, it's not possible to simply ask the cluster. But when using `rke`, you can see it in the cluster configuration file in `services.kubelet.cluster_domain`. If you haven't change it, skip this paragraph.

Thanks to [stoeps13](https://github.com/stoeps13), IBM got informed that not all people let the default name. So this component pack update let users choose their cluster name. This is important when your k8s cluster is named something other than `cluster.local`. Sadly this wasn't done consistently. The Mongodb Statefulset still contains hardcoded `cluster.local` code, which leads to crashing containers.

To fix this, hacky changes on the yml files are required: Go to `microservices_connections/hybridcloud/helmbuilds` and unpack the `infrastructure` tgz file

    tar xfvz infrastructure-0.1.0-20190205-020035.tgz

Now apply two changes on `infrastructure/charts/mongodb/templates/statefulset.yaml`

#### Set regular cluster domain

[mongo-k8s-sidecar](https://github.com/cvallance/mongo-k8s-sidecar/) provides a `KUBERNETES_CLUSTER_DOMAIN` environment variable, which IBM doesn't forward to the pod. Go to `env` section of `mongo-sidecar` pod and add it:

```yaml
- name: mongo-sidecar
  # ...
  env:
    # ...
    - name: KUBERNETES_CLUSTER_DOMAIN
      value: "customized-cluster.internal"
```

#### Replace in mongo.js file

`/opt/cvallance/mongo-k8s-sidecar/src/lib/mongo.js` must be changed. I don't see any other way than modifying the entrypoint. This way replacing is guaranteered to happen _before_ mongo starts. Search for `name: mongo-sidecar` and modify `command` to `["/bin/bash"]`. Add the following args:

```yml
- name: mongo-sidecar
  command: ["/bin/bash"]
  args:
    [
      "-c",
      "sed -i -e s/cluster.local/customized-cluster.local/g /opt/cvallance/mongo-k8s-sidecar/src/lib/mongo.js; /opt/cvallance/mongo-k8s-sidecar/entrypoint.sh",
    ]
```

#### Re-Pack

Now re-pack the modified `infrastructure` folder:

    tar cvzf infrastructure-0.1.0-20190205-020035.tgz infrastructure

## Disclaimer

I'm not associated to IBM, HZL or any other company behind Connections. This scripts and documentations are provided in the hope that they will be useful to others and spare headaches. I don't provide any warranty. Brands are copyrighted and only used to describe how to get the product up and running. A valid licence is required to run proprietary software legally.
