locals {
    datastores = flatten([
        for datacenter_name, environment in var.environment_mapping : [
            for key, datastore_name in environment.datastore_name : {
                datacenter_name  = datacenter_name   
                datastore_name  = datastore_name
            }
        ]
    ])
    clusters = flatten([
        for datacenter_name, environment in var.environment_mapping : [
            for key, cluster_name in environment.cluster_name : {
                datacenter_name  = datacenter_name   
                cluster_name  = cluster_name
            }
        ]
    ])
    pools = flatten([
        for datacenter_name, environment in var.environment_mapping : [
            for key, pool in environment.pool : {
                cluster  = environment.cluster_name[key]   
                pool  = pool
            }
        ]
    ])
    networks = flatten([
        for datacenter_name, environment in var.environment_mapping : [
            for key, network_name in environment.network : {
                datacenter_name  = datacenter_name   
                network_name  = network_name
            }
        ]
    ])
}