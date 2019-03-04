#!/usr/bin/env bash
# Dont change it, IBM use it hardcoded
kubectl create secret docker-registry myregkey --docker-server=${DOCKERREGISTRY} --docker-username=${REGISTRYUSER} --docker-password=${REGISTRYPASSWORD}                                    
# Initialize Helm
helm init --service-account tiller

# Upload Images to Registry
${DOWNLOADPATH}/microservices_connections/hybridcloud/support/setupImages.sh -dr $DOCKERREGISTRY -u $REGISTRYUSER -p $REGISTRYPASSWORD -st customizer,elasticsearch,orientme                                                                         
# Pod Security Policy: Only apply if enabled
#helm install --name=k8s-psp $DOWNLOADPATH/microservices_connections/hybridcloud/helmbuilds/k8s-psp-0.1.0-20190117-045550.tgz,namespace=$NAMESPACE    
                                                  
# Bootstrap
helm install --name=bootstrap $DOWNLOADPATH/microservices_connections/hybridcloud/helmbuilds/bootstrap-0.1.0-20190204-022029.tgz --set image.repository=$DOCKERREGISTRY/connections,env.set_ic_admin_user=$ICADMIN,env.set_ic_admin_password=$ICADMINPW,env.set_ic_internal=$ICCNXHOST,env.set_master_ip=$K8SMASTERIP,env.set_elasticsearch_ca_password=$COMPPASSWORD,env.set_elasticsearch_key_password=$COMPPASSWORD,env.set_redis_secret=$COMPPASSWORD,env.set_search_secret=$COMPPASSWORD,env.set_solr_secret=$COMPPASSWORD,env.set_starter_stack_list="elasticsearch orientme customizer",env.skip_configure_redis=false,namespace=$NAMESPACE

# Connections Env
# Builds configmap: customizer-interservice-port must be set to 4443 (backend websphere port) to avoid endless loops. But orient-cnx-interservice-port and orient-cnx-port should be set to 443
# ToDo: Test parameters (currently manually changed in configmap) -> kubectl edit cm connections-env
helm install $DOWNLOADPATH/microservices_connections/hybridcloud/helmbuilds/connections-env-0.1.40-20190122-110818.tgz --name=connections-env --set onPrem=true,createSecret=false,image.repository=$DOCKERREGISTRY/connections,ic.host=$ICCNXHOST,ic.internal=$ICCNXHOST,ic.interserviceOpengraphPort=443,ic.interserviceConnectionsPort=443,ic.interserviceScheme=https,namespace=$NAMESPACE

# CP Infrastructure: See README for modifications that may be required
helm install --name=infrastructure $DOWNLOADPATH/microservices_connections/hybridcloud/helmbuilds/infrastructure-0.1.0-20190205-020035.tgz --set global.onPrem=true,global.image.repository=$DOCKERREGISTRY/connections,mongodb.createSecret=false,appregistry-service.deploymentType=hybrid_cloud,appregistry-client.namespace=$NAMESPACE,appregistry-service.namespace=$NAMESPACE,haproxy.namespace=$NAMESPACE,mongodb.namespace=$NAMESPACE,redis-sentinel.namespace=$NAMESPACE,redis.namespace=$NAMESPACE,mongodb.volumeClaimTemplates.storageClass=${STORAGECLASS},haproxy.env.k8s_cluster_domain=${CLUSTERNAME},redis-sentinel.env.k8s_cluster_domain=${CLUSTERNAME},redis.env.k8s_cluster_domain=${CLUSTERNAME},mongodb.env.newRelic.enable=true

# Orientme
helm install --name=orientme $DOWNLOADPATH/microservices_connections/hybridcloud/helmbuilds/orientme-0.1.0-20190205-020134.tgz --set global.onPrem=true,global.image.repository=$DOCKERREGISTRY/connections,orient-web-client.service.nodePort=30001,itm-services.service.nodePort=31100,mail-service.service.nodePort=32721,community-suggestions.service.nodePort=32200,community-suggestions.namespace=$NAMESPACE,indexing-service.namespace=$NAMESPACE,itm-services.namespace=$NAMESPACE,mail-service.namespace=$NAMESPACE,middleware-graphql.namespace=$NAMESPACE,orient-web-client.namespace=$NAMESPACE,people-datamigration.namespace=$NAMESPACE,people-idmapping.namespace=$NAMESPACE,people-relationship.namespace=$NAMESPACE,people-scoring.namespace=$NAMESPACE,people-retrieve.namespace=$NAMESPACE,solr-basic.namespace=$NAMESPACE,userprefs-service.namespace=$NAMESPACE,zookeeper.namespace=$NAMESPACE,orient-analysis-service.namespace=$NAMESPACE,orient-retrieval-service.namespace=$NAMESPACE,orient-web-client.namespace=$NAMESPACE,orient-indexing-service.namespace=$NAMESPACE,solr-basic.volumeClaimTemplates.storageClass=${STORAGECLASS},zookeeper.volumeClaimTemplates.storageClass=${STORAGECLASS}

# Ingress
helm install --name=cnx-ingress $DOWNLOADPATH/microservices_connections/hybridcloud/helmbuilds/cnx-ingress-0.1.0-20190204-024025.tgz --set image.repository=$DOCKERREGISTRY/connections,ingress.hosts.domain="${CNXDOMAIN}",namespace=$NAMESPACE

# Elasticsearch
helm install --name=elasticsearch $DOWNLOADPATH/microservices_connections/hybridcloud/helmbuilds/elasticsearch-0.1.0-20190204-020030.tgz --set image.repository=$DOCKERREGISTRY/connections,nodeAffinityRequired=false,namespace=$NAMESPACE,common.storageClass=${STORAGECLASS}

# Customizer
helm install --name=mw-proxy $DOWNLOADPATH/microservices_connections/hybridcloud/helmbuilds/mw-proxy-0.1.0-20190201-020054.tgz --set image.repository=$DOCKERREGISTRY/connections,deploymentType=hybrid_cloud,namespace=$NAMESPACE

# Sanity
helm install --name=sanity $DOWNLOADPATH/microservices_connections/hybridcloud/helmbuilds/sanity-0.1.8-20190201-143401.tgz --set image.repository=$DOCKERREGISTRY/connections,logLevel=info,namespace=$NAMESPACE