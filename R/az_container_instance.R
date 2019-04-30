#' Azure Container Instance class
#'
#' Class representing an Azure Container Instance (ACI) resource.
#'
#' @docType class
#' @section Methods:
#' The following methods are available, in addition to those provided by the [AzureRMR::az_resource] class:
#' - `new(...)`: Initialize a new ACI object.
#' - `restart()`, `start()`: Start a stopped container. These methods are synonyms for each other.
#' - `stop()`: Stop a container.
#'
#' @section Details:
#' Initializing a new object of this class can either retrieve an existing ACI resource, or create a new resource on the host. Generally, the best way to initialize an object is via the `get_aci`, `create_aci` or `list_acis` methods of the [az_resource_group] class, which handle the details automatically.
#'
#' @seealso
#' [acr], [aks]
#'
#' [ACI documentation](https://docs.microsoft.com/en-us/azure/container-instances/) and
#' [API reference](https://docs.microsoft.com/en-us/rest/api/container-instances/)
#'
#' [Docker commandline reference](https://docs.docker.com/engine/reference/commandline/cli/)
#'
#' @examples
#' \dontrun{
#'
#' # recommended way of retrieving a container: via a resource group object
#' rg <- AzureRMR::az_rm$
#'     new(tenant="myaadtenant.onmicrosoft.com", app="app_id", password="password")$
#'     get_subscription("subscription_id")$
#'     get_resource_group("rgname")
#'
#' myaci <- rg$get_aci("mycontainer")
#'
#' myaci$stop()
#' myaci$restart()
#'
#' }
#' @aliases az_container_instance
#' @export
aci <- R6::R6Class("az_container_instance", inherit=AzureRMR::az_resource,

public=list(

    restart=function()
    {
        private$res_op("restart", http_verb="POST")
    },

    start=function()
    {
        private$res_op("start", http_verb="POST")
    },

    stop=function()
    {
        private$res_op("stop", http_verb="POST")
    }
))


#' Utilities for specifying ACI configuration information
#'
#' @param port,protocol For `aci_ports`, vectors of the port numbers and protocols to open for the instance.
#' @param server,username,password For `aci_creds`, the authentication details for a Docker registry.
#' @param lst for `get_aci_credentials_list`, a list of objects.
#'
#' @details
#' These are helper functions to be used in specifying the configuration for a container instance. Only `aci_ports` and `aci_creds` are meant to be called by the user; `get_aci_credentials_list` is exported to workaround namespacing issues on startup.
#' @rdname aci_utils
#' @export
aci_ports <- function(port=c(80L, 443L), protocol="TCP")
{
    df <- data.frame(port=as.integer(port), protocol=protocol, stringsAsFactors=FALSE)
    lapply(seq_len(nrow(df)), function(i) unclass(df[i,]))
}


#' @rdname aci_utils
#' @export
aci_creds <- function(server, username, password)
{
    obj <- list(server=server, username=username, password=password)
    class(obj) <- "aci_creds"
    obj
}


#' @rdname aci_utils
#' @export
get_aci_credentials_list <- function(lst)
{
    # try to ensure we actually have a list of registries as input
    if(is_acr(lst) || is_docker_registry(lst) || inherits(lst, "aci_creds") || !is.list(lst))
        lst <- list(lst)
    lapply(lst, function(x) extract_creds(x))
}

extract_creds <- function(obj, ...)
{
    UseMethod("extract_creds")
}

extract_creds.az_container_registry <- function(obj, ...)
{
    extract_creds(obj$get_docker_registry())
}

extract_creds.docker_registry <- function(obj, ...)
{
    list(server=obj$server, username=obj$username, password=obj$password)
}

extract_creds.aci_creds <- function(obj, ...)
{
    obj
}
