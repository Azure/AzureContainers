#' @import AzureRMR
#' @importFrom utils tail
NULL

.AzureContainers <- new.env()

.az_cli_app_id <- "04b07795-8ddb-461a-bbee-02f9e1bf7b46"

globalVariables("self", "AzureContainers")

.onLoad <- function(libname, pkgname)
{
    # find docker, kubectl and helm binaries
    .AzureContainers$docker <- Sys.which("docker")
    .AzureContainers$dockercompose <- Sys.which("docker-compose")
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
    if(.AzureContainers$dockercompose != "")
        packageStartupMessage("Using docker-compose binary ", .AzureContainers$dockercompose)
    if(.AzureContainers$kubectl != "")
        packageStartupMessage("Using kubectl binary ", .AzureContainers$kubectl)
    if(.AzureContainers$helm != "")
        packageStartupMessage("Using helm binary ", .AzureContainers$helm)

    if(.AzureContainers$docker == "")
        packageStartupMessage("NOTE: docker binary not found")
    if(.AzureContainers$dockercompose == "")
        packageStartupMessage("NOTE: docker-compose binary not found")
    if(.AzureContainers$kubectl == "")
        packageStartupMessage("NOTE: kubectl binary not found")
    if(.AzureContainers$helm == "")
        packageStartupMessage("NOTE: helm binary not found")
    invisible(NULL)
}
