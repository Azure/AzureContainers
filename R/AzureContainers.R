#' @import AzureRMR
#' @importFrom utils tail
NULL

.AzureContainers <- new.env()

globalVariables("self", "AzureContainers")

.onLoad <- function(libname, pkgname)
{
    # find docker, kubectl and helm binaries
    .AzureContainers$docker <- Sys.which("docker")
    .AzureContainers$kubectl <- Sys.which("kubectl")
    .AzureContainers$helm <- Sys.which("helm")

    ## add methods to AzureRMR resource group and subscription classes
    add_acr_methods()
    add_aks_methods()
    add_aci_methods()
    add_vmsize_methods()
}


.onAttach <- function(libname, pkgname)
{
    if(.AzureContainers$docker != "")
        packageStartupMessage("Using docker binary ", .AzureContainers$docker)
    if(.AzureContainers$kubectl != "")
        packageStartupMessage("Using kubectl binary ", .AzureContainers$kubectl)
    if(.AzureContainers$helm != "")
        packageStartupMessage("Using helm binary ", .AzureContainers$helm)

    if(.AzureContainers$docker == "")
        packageStartupMessage("NOTE: docker binary not found")
    if(.AzureContainers$kubectl == "")
        packageStartupMessage("NOTE: kubectl binary not found")
    if(.AzureContainers$helm == "")
        packageStartupMessage("NOTE: helm binary not found")
    invisible(NULL)
}
