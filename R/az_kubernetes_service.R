#' Azure Kubernetes Service class
#'
#' Class representing an Azure Kubernetes Service (AKS) resource. For working with the cluster endpoint itself, including deploying images, creating services etc, see [kubernetes_cluster].
#'
#' @docType class
#' @section Methods:
#' The following methods are available, in addition to those provided by the [AzureRMR::az_resource] class:
#' - `new(...)`: Initialize a new AKS object.
#' - `get_cluster(config, role)`: Return an object representing the Docker registry endpoint.
#'
#' @section Details:
#' Initializing a new object of this class can either retrieve an existing registry resource, or create a new registry on the host. Generally, the best way to initialize an object is via the `get_aks`, `create_aks` or `list_aks` methods of the [az_resource_group] class, which handle the details automatically.
#'
#' Note that this class is separate from the Kubernetes cluster itself. This class exposes methods for working with the Azure resource: updating resource tags, updating and deleting the resource (including updating the Kubernetes version), and so on.
#'
#' For working with the cluster, including deploying images, services, etc use the object generated with the `get_cluster` method. This method takes two optional arguments:
#'
#' - `config`: The file in which to store the cluster configuration details. By default, this will be located in the R temporary directory. To use the Kubernetes default `~/.kube/config` file, set this argument to NULL. Note that any existing file in the given location will be overwritten.
#' - `role`: This can be `"User"` (the default) or `"Admin`".
#'
#' @seealso
#' [create_aks], [get_aks], [delete_aks], [list_aks]
#'
#' [kubernetes_cluster] for interacting with the cluster endpoint
#'
#' [AKS documentation](https://docs.microsoft.com/en-us/azure/aks/) and
#' [API reference](https://docs.microsoft.com/en-us/rest/api/aks/)
#' @aliases az_kubernetes_service
#' @export
aks <- R6::R6Class("az_kubernetes_service", inherit=AzureRMR::az_resource,

public=list(

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
        else message("Storing cluster information in ", config)

        writeLines(cred_profile, config)
        kubernetes_cluster$new(config=config)
    }
))


#' Utility function for specifying Kubernetes agent pools
#'
#' @param name The name(s) of the pool(s).
#' @param count The number of nodes per pool.
#' @param size The VM type (size) to use for the pool.
#' @param os The operating system to use for the pool. Can be "Linux" or "Windows".
#'
#' @details
#' This is a convenience function to simplify the task of specifying the agent pool for a Kubernetes cluster. To specify multiple pools, provide vectors as input arguments; any scalar inputs will be replicated to match. Note that while Kubernetes in general is capable of having multiple pools per cluster, AKS currently only supports a single pool.
#'
#' @return
#' A list of lists, suitable for passing to the `create_aks` constructor method.
#' @export
aks_pools <- function(name, count, size="Standard_DS2_v2", os="Linux")
{
    count <- as.integer(count)
    pool_df <- data.frame(name=name, count=count, vmSize=size, osType=os, stringsAsFactors=FALSE)
    pool_df$name <- make.unique(pool_df$name, sep="")
    lapply(seq_len(nrow(pool_df)), function(i) unclass(pool_df[i, ]))
}
