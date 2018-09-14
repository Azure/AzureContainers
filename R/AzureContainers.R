#' @import AzureRMR
NULL

.AzureContainers <- new.env()


.onLoad <- function(pkgname, libname)
{
    # find docker, kubectl and helm binaries
    .AzureContainers$docker <- Sys.which("docker")
    .AzureContainers$kubectl <- Sys.which("kubectl")
    .AzureContainers$helm <- Sys.which("helm")

    # default Kubernetes version
    .AzureContainers$kubever <- "1.11.2"

    if(.AzureContainers$docker != "")
        message("Using docker binary ", .AzureContainers$docker)
    else warning("docker binary not found", call.=FALSE)

    if(.AzureContainers$kubectl != "")
        message("Using kubectl binary ", .AzureContainers$kubectl)
    else warning("kubectl binary not found", call.=FALSE)

    if(.AzureContainers$helm != "")
        message("Using helm binary ", .AzureContainers$kubectl)
    else warning("helm binary not found", call.=FALSE)

    ## add methods to AzureRMR resource group and subscription classes
    add_acr_methods()
    add_aks_methods()
    add_aci_methods()
}
