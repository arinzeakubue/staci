#! /bin/bash

function getVirtualBoxFlags(){
  # Get information from property file
  local memory=$(getVirtualBoxProperty "virtualbox_memory")
  local cpu_count=$(getVirtualBoxProperty "virtualbox_cpu_count")
  local disk_size=$(getVirtualBoxProperty "virtualbox_disk_size")
  local flags=" \
        --virtualbox-memory $memory \
        --virtualbox-cpu-count $cpu_count \
        --virtualbox-disk-size $disk_size \
  "

  echo $flags
}

function getVmwareVsphereFlags(){
  local ip_hostname=$(getVmwareVsphereProperty "vmwarevsphere_vcenter")
  local username=$(getVmwareVsphereProperty "vmwarevsphere_username")
  local password=$(getVmwareVsphereProperty "vmwarevsphere_password")

  local flags=" \
        --vmwarevsphere-vcenter $ip_hostname \
        --vmwarevsphere-username $username \
        --vmwarevsphere-password $password \
  "
  echo $flags
}

function getOpenStackFlags(){
  # Get information from propertyfile
  local username=$(getOpenStackProperty "openstack_OS_USERNAME")
  local password=$(getOpenStackProperty "openstack_OS_PASSWORD")
  local domain_name=$(getOpenStackProperty "openstack_OS_DOMAIN_NAME")
  local auth_url=$(getOpenStackProperty "openstack_OS_AUTH_URL")
  local tenant_name=$(getOpenStackProperty "openstack_OS_TENANT_NAME")
  local tenant_id=$(getOpenStackProperty "openstack_OS_TENANT_ID")
  local sec_groups=$(getOpenStackProperty "openstack_sec_groups")
  local ssh_user=$(getOpenStackProperty "openstack_ssh_user")
  local floating_ip_pool=$(getOpenStackProperty "openstack_floating_ip_pool")
  local flavor_id=$(getOpenStackProperty "openstack_flavor_id")
  local net_id=$(getOpenStackProperty "openstack_net_id")
  local image_id=$(getOpenStackProperty "openstack_image_id")

  local dmflags=" \
        --openstack-username $username \
        --openstack-password $password \
        --openstack-domain-name $domain_name \
        --openstack-tenant-id $tenant_id \
        --openstack-auth-url $auth_url \
        --openstack-flavor-id $flavor_id \
        --openstack-image-id $image_id  \
        --openstack-net-id $net_id \
        --openstack-floatingip-pool $floating_ip_pool \
        --openstack-ssh-user $ssh_user \
        --openstack-sec-groups $sec_groups \
  "
  echo $dmflags
}

function getDMFlags(){

    local provider=$1
    if [ "$provider" == "none" ];then
        echo "local"
    elif [ "$provider" == "openstack" ];then
        getOpenStackFlags
    elif [ "$provider" == "virtualbox" ];then
        getVirtualBoxFlags
    elif [ "$provider" == "vmwarevsphere" ];then
        getVmwareVsphereFlags
    fi
}

function createSingleHost(){
    local provider=$(getProperty "provider_type")
    local dmflags=$(getDMFlags $provider)
    local node_prefix=$(getProperty "clusterNodePrefix")

    createDMInstance "$provider" "$dmflags" "0" "0" "$node_prefix" "Atlassian"

}

function createSwarm(){
    local provider=$(getProperty "provider_type")
    echo " - Using $provider as provider..."
    # local provider=$1
    local dmflags=$(getDMFlags $provider)

    # Find out what to start
    local start_mysql=$(getProperty "start_mysql")
    local start_jira=$(getProperty "start_jira")
    local start_confluence=$(getProperty "start_confluence")
    local start_bamboo=$(getProperty "start_bamboo")
    local start_crowd=$(getProperty "start_crowd")
    local start_bitbucket=$(getProperty "start_bitbucket")
    local start_crucible=$(getProperty "start_crucible")
    local start_jenkins=$(getProperty "start_jenkins")

    # Get the node prefix
    local node_prefix=$(getProperty "clusterNodePrefix")

    createDMInstance "$provider" "$dmflags" "0" "0" "$node_prefix" "keystore"

    docker $(docker-machine config $node_prefix-keystore) pull progrium/consul:latest > $STACI_HOME/logs/consult.pull.log

    docker $(docker-machine config $node_prefix-keystore) run -d \
        -p "8500:8500" \
        -h "consul" \
        progrium/consul -server -bootstrap > $STACI_HOME/logs/consul.run.log


    if [ "$start_mysql" == "1" ];then
        createDMInstance "$provider" "$dmflags" "2" "1" "$node_prefix" "mysql"
    fi
    if [ "$start_jira" == "1" ];then
       createDMInstance "$provider" "$dmflags" "1" "1" "$node_prefix" "jira"
    fi
    if [ "$start_confluence" == "1" ];then
        createDMInstance "$provider" "$dmflags" "1" "1" "$node_prefix" "confluence"
    fi
    if [ "$start_bamboo" == "1" ];then
        createDMInstance "$provider" "$dmflags" "1" "1" "$node_prefix" "bamboo"
    fi
    if [ "$start_crowd" == "1" ];then
        createDMInstance "$provider" "$dmflags" "1" "1" "$node_prefix" "crowd"
    fi
    if [ "$start_bitbucket" == "1" ];then
        createDMInstance "$provider" "$dmflags" "1" "1" "$node_prefix" "bitbucket"
    fi
    if [ "$start_crucible" == "1" ];then
        createDMInstance "$provider" "$dmflags" "1" "1" "$node_prefix" "crucible"
    fi
    if [ "$start_jenkins" == "1" ];then
        createDMInstance "$provider" "$dmflags" "1" "1" "$node_prefix" "jenkins"
    fi
}

function createDMInstance(){
    local dmprovider=$1
    local dmflags=$2
    local swarmtype=$3
    local clusteropts=$4
    local node_prefix=$5
    local instance_name=$6
    local dmname="$node_prefix-$instance_name"

    local swarm=""
    local cluster=""

    if [ $clusteropts == "0" ];then
        cluster=""
    elif [ $clusteropts == "1" ];then
        discoveryservice="consul://$(docker-machine ip $node_prefix-keystore):8500"
        cluster="--engine-opt=""cluster-store=$discoveryservice"" --engine-opt=""cluster-advertise=eth1:2376"""
    fi

    if [ $swarmtype == "0" ];then
       swarm=""
    elif [ $swarmtype == "1" ];then
       swarm="--swarm --swarm-discovery=$discoveryservice"
    elif [ $swarmtype == "2" ];then
       swarm="--swarm --swarm-master --swarm-discovery=$discoveryservice"
    fi

    echo "  - Creating instance $dmname via $provider - tail -f $STACI_HOME/logs/$provider.$dmname.log"
    docker-machine --debug create -d $dmprovider $dmflags $swarm $cluster $dmname  > $STACI_HOME/logs/$provider.$dmname.log 2>&1
}
