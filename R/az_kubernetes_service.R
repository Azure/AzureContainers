#' @export
aks <- R6::R6Class("az_kubernetes_service", inherit=AzureRMR::az_resource,

public=list(

    initialize=function(token, subscription, resource_group, name, location,
        dns_prefix=name, agent_pools=list(), enable_rbac=FALSE, properties=list(), ...)
    {
        if(missing(location) && missing(dns_prefix) && missing(agent_pools) &&
           missing(enable_rbac) && missing(properties))
            super$initialize(token, subscription, resource_group, type="Microsoft.ContainerService/managedClusters",
                             name=name,
                             ...)
        else
        {
            props <- c(
                list(
                    dnsPrefix=dns_prefix,
                    agentPoolProfiles=agent_pools,
                    enableRBAC=enable_rbac
                ),
                properties
            )
            super$initialize(token, subscription, resource_group, type="Microsoft.ContainerService/managedClusters",
                             name=name,
                             location=location,
                             properties=props,
                             ...)
        }
    },

    get_cluster=function(config=tempfile(pattern="kubeconfig"), role=c("User", "Admin"))
    {
        role <- match.arg(role)
        cred_profile <- private$res_op(paste0("accessProfiles/cluster", role))$properties$kubeConfig
        cred_profile <- rawToChar(openssl::base64_decode(cred_profile))

        # provide ability to save to default .kube/config by passing a NULL
        if(is.null(config))
        {
            win <- .Platform$OS.type == "windows"
            config <- if(win)
                file.path(Sys.getenv("HOMEPATH"), ".kube/config")
            else file.path(Sys.getenv("HOME"), ".kube/config")
        }

        if(file.exists(config))
            message("Overwriting existing cluster information in ", config)

        writeLines(cred_profile, config)
        kubernetes_cluster$new(config=config)
    }
))


#' @export
is_aks <- function(object)
{
    R6::is.R6(object) && inherits(object, "az_kubernetes_service")
}

