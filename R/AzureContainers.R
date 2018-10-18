#' @import AzureRMR
NULL

.AzureContainers <- new.env()

globalVariables("self", "AzureContainers")

.onLoad <- function(libname, pkgname)
{
    # find docker, kubectl and helm binaries
    .AzureContainers$docker <- Sys.which("docker")
    .AzureContainers$kubectl <- Sys.which("kubectl")
    .AzureContainers$helm <- Sys.which("helm")

    if(.AzureContainers$docker != "")
        packageStartupMessage("Using docker binary ", .AzureContainers$docker)
    else warning("docker binary not found", call.=FALSE)

    if(.AzureContainers$kubectl != "")
        packageStartupMessage("Using kubectl binary ", .AzureContainers$kubectl)
    else warning("kubectl binary not found", call.=FALSE)

    if(.AzureContainers$helm != "")
        packageStartupMessage("Using helm binary ", .AzureContainers$helm)
    else warning("helm binary not found", call.=FALSE)

    ## add methods to AzureRMR resource group and subscription classes
    add_acr_methods()
    add_aks_methods()
    add_aci_methods()
}
