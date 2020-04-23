#' Azure Kubernetes Service class
#'
#' Class representing an Azure Kubernetes Service (AKS) resource. For working with the cluster endpoint itself, including deploying images, creating services etc, see [kubernetes_cluster].
#'
#' @docType class
#' @section Methods:
#' The following methods are available, in addition to those provided by the [AzureRMR::az_resource] class:
#' - `new(...)`: Initialize a new AKS object.
#' - `get_cluster(config, role)`: Return an object representing the Docker registry endpoint.
#' - `list_cluster_resources()`: Returns a list of all the Azure resources managed by the cluster.
#' - `update_aad_password(name=NULL, duration=NULL, ...)`: Update the password for Azure Active Directory integration, returning the new password invisibly. See 'Updating credentials' below.
#' - `update_service_password(name=NULL, duration=NULL, ...)`: Update the password for the service principal used to manage the cluster resources, returning the new password invisibly.  See 'Updating credentials' below.
#'
#' @section Details:
#' Initializing a new object of this class can either retrieve an existing AKS resource, or create a new resource on the host. Generally, the best way to initialize an object is via the `get_aks`, `create_aks` or `list_aks` methods of the [az_resource_group] class, which handle the details automatically.
#'
#' Note that this class is separate from the Kubernetes cluster itself. This class exposes methods for working with the Azure resource: updating resource tags, updating and deleting the resource (including updating the Kubernetes version), and so on.
#'
#' For working with the cluster, including deploying images, services, etc use the object generated with the `get_cluster` method. This method takes two optional arguments:
#'
#' - `config`: The file in which to store the cluster configuration details. By default, this will be located in the AzureR configuration directory if it exists (see [AzureAuth::AzureR_dir]); otherwise, in the R temporary directory. To use the Kubernetes default `~/.kube/config` file, set this argument to NULL. Any existing file in the given location will be overwritten.
#' - `role`: This can be `"User"` (the default) or `"Admin"`.
#'
#' @section Updating credentials:
#' An AKS cluster requires at least one, and possibly three, service principals. The first service principal is used to manage the resources used by the cluster: the VMs, networking resources, virtual disks, etc. The other two are used for AAD integration. These service principals have secret passwords, which have to be refreshed as they expire.
#'
#' The `update_aad_password()` and `update_service_password()` methods let you refresh the passwords for the cluster's service principals. Their arguments are:
#'
#' - `name`: An optional friendly name for the password.
#' - `duration`: The duration for which the new password is valid. Defaults to 2 years.
#' - `...`: Other arguments passed to `AzureGraph::create_graph_login`. Note that these are used to authenticate with Microsoft Graph, which does the actual work of updating the service principals, not to the cluster itself.
#'
#' @seealso
#' [create_aks], [get_aks], [delete_aks], [list_aks], [AzureAuth::AzureR_dir], [AzureGraph::create_graph_login]
#'
#' [kubernetes_cluster] for interacting with the cluster endpoint
#'
#' [AKS documentation](https://docs.microsoft.com/en-us/azure/aks/) and
#' [API reference](https://docs.microsoft.com/en-us/rest/api/aks/)
#'
#' @examples
#' \dontrun{
#'
#' rg <- AzureRMR::get_azure_login()$
#'     get_subscription("subscription_id")$
#'     get_resource_group("rgname")
#'
#' myaks <- rg$get_aks("mycluster")
#'
#' # sync with Azure: AKS resource creation can take a long time, use this to track status
#' myaks$sync_fields()
#'
#' # get the cluster endpoint
#' kubclus <- myaks$get_cluster()
#'
#' # refresh the service principal password
#' myaks$update_service_password()
#'
#' # refresh the service principal password, using custom credentials to authenticate with MS Graph
#' # arguments here are for Graph, not AKS!
#' myaks$update_service_password(app="app_id", password="app_password")
#'
#' }
#' @aliases az_kubernetes_service
#' @export
aks <- R6::R6Class("az_kubernetes_service", inherit=AzureRMR::az_resource,

public=list(

    get_cluster=function(config=kubeconfig_file(), role=c("User", "Admin"))
    {
        kubeconfig_file <- function()
        {
            az_dir <- AzureR_dir()
            if(!dir.exists(az_dir))
                az_dir <- tempdir()
            file.path(az_dir, paste0("kubeconfig_", self$name))
        }

        role <- match.arg(role)
        profile <- private$res_op(paste0("listCluster", role, "Credential"), http_verb="POST")$kubeconfigs
        profile <- rawToChar(openssl::base64_decode(profile[[1]]$value))

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
        else
        {
            config_dir <- dirname(config)
            if(!dir.exists(config_dir))
                dir.create(config_dir, recursive=TRUE)
            message("Storing cluster information in ", config)
        }

        writeLines(profile, config)
        kubernetes_cluster(config=config)
    },

    list_cluster_resources=function()
    {
        clusrgname <- self$properties$nodeResourceGroup
        clusrg <- az_resource_group$new(self$token, self$subscription, clusrgname)
        clusrg$list_resources()
    },

    update_aad_password=function(name=NULL, duration=NULL, ...)
    {
        prof <- self$properties$aadProfile
        if(is.null(prof))
            stop("No Azure Active Directory profile associated with this cluster", call.=FALSE)

        app <- graph_login(self$token$tenant, ...)$get_app(prof$serverAppID)
        app$add_password(name, duration)
        prof$serverAppSecret <- app$password

        self$do_operation(body=list(properties=list(aadProfile=prof)), encode="json", http_verb="PATCH")
        self$sync_fields()
        invisible(prof$serverAppSecret)
    },

    update_service_password=function(name=NULL, duration=NULL, ...)
    {
        prof <- self$properties$servicePrincipalProfile
        app <- graph_login(self$token$tenant, ...)$get_app(prof$clientId)
        app$add_password(name, duration)
        prof$secret <- app$password

        self$do_operation(body=list(properties=list(servicePrincipalProfile=prof)), encode="json", http_verb="PATCH")
        self$sync_fields()
        invisible(prof$secret)
    }
))


#' Utility function for specifying Kubernetes agent pools
#'
#' @param name The name(s) of the pool(s).
#' @param count The number of nodes per pool.
#' @param size The VM type (size) to use for the pool. To see a list of available VM sizes, use the [list_vm_sizes] method for the resource group or subscription classes.
#' @param os The operating system to use for the pool. Can be "Linux" or "Windows".
#' @param disksize The OS disk size in gigabytes for each node in the pool. A value of 0 means to use the default disk size for the VM type.
#' @param use_scaleset Whether to use a VM scaleset instead of individual VMs for this pool. A scaleset offers greater flexibility than individual VMs, and is the recommended method of creating an agent pool.
#' @param low_priority If this pool uses a scaleset, whether it should be made up of spot (low-priority) VMs. A spot VM pool is cheaper, but is subject to being deallocated to make room for other, higher-priority workloads. Ignored if `use_scaleset=FALSE`.
#' @param cluster_autoscale The autoscaling parameters for the pool. This can be either `FALSE`, meaning autoscaling is disabled, or a vector of 2 numbers giving the minimum and maximum size of the agent pool. Ignored if `use_scaleset=FALSE`.
#' @param ... Other named arguments, to be used as parameters for the agent pool.
#'
#' @details
#' This is a convenience function to simplify the task of specifying the agent pool for a Kubernetes cluster.
#'
#' @return
#' An object of class `aks_agent_pool`, suitable for passing to the `create_aks` constructor method.
#'
#' @seealso
#' [list_vm_sizes], [agent pool parameters on Microsoft Docs](https://docs.microsoft.com/en-us/rest/api/aks/managedclusters/createorupdate#managedclusteragentpoolprofile)
#'
#' @examples
#' # pool of 5 Linux VMs
#' aks_pools("pool1", 5)
#'
#' # pool of 3 Windows Server VMs, 500GB disk size each
#' aks_pools("pool1", 3, os="Windows", disksize=500)
#'
#' # enable cluster autoscaling, with a minimum of 1 and maximum of 10 nodes
#' aks_pools("pool1", 5, cluster_autoscale=c(1, 10))
#'
#' @export
aks_pools <- function(name, count, size="Standard_DS2_v2", os="Linux", disksize=0,
                      use_scaleset=TRUE, low_priority=FALSE, cluster_autoscale=FALSE, ...)
{
    parms <- list(
        name=name,
        count=as.integer(count),
        vmSize=size,
        osType=os,
        osDiskSizeGB=disksize,
        type=if(use_scaleset) "VirtualMachineScaleSets" else "AvailabilitySet"
    )

    if(use_scaleset)
    {
        if(is.numeric(cluster_autoscale) && length(cluster_autoscale) == 2)
        {
            parms$enableAutoScaling <- TRUE
            parms$minCount <- min(cluster_autoscale)
            parms$maxCount <- max(cluster_autoscale)
        }
        if(low_priority)
            parms$scaleSetPriority <- "spot"
    }

    extras <- list(...)
    if(!is_empty(extras))
        parms <- utils::modifyList(extras, parms)

    structure(parms, class="aks_agent_pool")
}

