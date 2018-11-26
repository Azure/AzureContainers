#' List available VM sizes
#'
#' Method for the [AzureRMR::az_subscription] and [AzureRMR::az_resource_group] classes.
#'
#' @section Usage:
#' ```
#' ## R6 method for class 'az_subscription'
#' list_vm_sizes(location, name_only = FALSE)
#'
#' ## R6 method for class 'az_resource_group'
#' list_vm_sizes(name_only = FALSE)
#' ```
#' @section Arguments:
#' - `location`: For the subscription class method, the location/region for which to obtain available VM sizes.
#' - `name_only`: Whether to return only a vector of names, or all information on each VM size.
#'
#' @section Value:
#' If `name_only` is TRUE, a character vector of names. If FALSE, a data frame containing the following information for each VM size: the name, number of cores, OS disk size, resource disk size, memory, and maximum data disks.
#'
#' @examples
#' \dontrun{
#'
#' sub <- AzureRMR::az_rm$
#'     new(tenant="myaadtenant.onmicrosoft.com", app="app_id", password="password")$
#'     get_subscription("subscription_id")
#'
#' sub$list_vm_sizes("australiaeast")
#'
#' # same output as above
#' rg <- sub$create_resource_group("rgname", location="australiaeast")
#' rg$list_vm_sizes()
#'
#' }
#' @rdname list_vm_sizes
#' @aliases list_vm_sizes
#' @name list_vm_sizes
NULL


# extend subscription methods
add_vmsize_methods <- function()
{
    az_subscription$set("public", "list_vm_sizes", overwrite=TRUE,
    function(location, name_only=FALSE)
    {
        provider <- "Microsoft.Compute"
        path <- "locations"
        api_version <- self$get_provider_api_version(provider, path)

        op <- file.path("providers", provider, path, location, "vmSizes")
        res <- call_azure_rm(self$token, self$id, op, api_version=api_version)

        if(!name_only)
            do.call(rbind, lapply(res$value, data.frame, stringsAsFactors=FALSE))
        else sapply(res$value, `[[`, "name")
    })

    az_resource_group$set("public", "list_vm_sizes", overwrite=TRUE,
    function(name_only=FALSE)
    {
        az_subscription$
            new(self$token, self$subscription)$
            list_vm_sizes(self$location, name_only=name_only)
    })
}
