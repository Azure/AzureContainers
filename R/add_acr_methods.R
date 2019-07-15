#' Create Azure Container Registry (ACR)
#'
#' Method for the [AzureRMR::az_resource_group] class.
#'
#' @rdname create_acr
#' @name create_acr
#' @aliases create_acr
#' @section Usage:
#' ```
#' create_acr(name, location = self$location,
#'            admin_user_enabled = TRUE, sku = "Standard", ...)
#' ```
#' @section Arguments:
#' - `name`: The name of the container registry.
#' - `location`: The location/region in which to create the container registry. Defaults to this resource group's location.
#' - `admin_user_enabled`: Whether to enable the Admin user. Currently this must be TRUE to allow Docker to access the registry.
#' - `sku`: Either "Basic", "Standard" (the default) or "Premium".
#' - `wait`: Whether to wait until the ACR resource provisioning is complete.
#' - `...`: Other named arguments to pass to the [az_resource] initialization function.
#'
#' @section Details:
#' An ACR resource is a Docker registry hosted in Azure. See the [documentation for the resource](https://docs.microsoft.com/en-us/azure/container-registry/) for more information. To work with the registry (transfer images, retag images, etc) see the [documentation for the registry endpoint][docker_registry].
#'
#' @section Value:
#' An object of class `az_container_registry` representing the registry resource.
#'
#' @seealso
#' [get_acr], [delete_acr], [list_acrs]
#'
#' [az_container_registry]
#'
#' [docker_registry] for the registry endpoint
#'
#' [ACR documentation](https://docs.microsoft.com/en-us/azure/container-registry/) and
#' [API reference](https://docs.microsoft.com/en-us/rest/api/containerregistry/registries)
#'
#' [Docker registry API](https://docs.docker.com/registry/spec/api/)
#'
#' @examples
#' \dontrun{
#'
#' rg <- AzureRMR::get_azure_login()$
#'     get_subscription("subscription_id")$
#'     get_resource_group("rgname")
#'
#' rg$create_acr("myregistry")
#'
#' }
NULL


#' Get Azure Container Registry (ACR)
#'
#' Method for the [AzureRMR::az_resource_group] class.
#'
#' @rdname get_acr
#' @name get_acr
#' @aliases get_acr list_acrs
#'
#' @section Usage:
#' ```
#' get_acr(name)
#' list_acrs()
#' ```
#' @section Arguments:
#' - `name`: For `get_acr()`, the name of the container registry resource.
#'
#' @section Details:
#' The `AzureRMR::az_resource_group` class has both `get_acr()` and `list_acrs()` methods, while the `AzureRMR::az_subscription` class only has the latter.
#'
#' @section Value:
#' For `get_acr()`, an object of class `az_container_registry` representing the registry resource.
#'
#' For `list_acrs()`, a list of such objects.
#'
#' @seealso
#' [create_acr], [delete_acr]
#'
#' [az_container_registry]
#'
#' [docker_registry] for the registry endpoint
#'
#' [ACR documentation](https://docs.microsoft.com/en-us/azure/container-registry/) and
#' [API reference](https://docs.microsoft.com/en-us/rest/api/containerregistry/registries)
#'
#' [Docker registry API](https://docs.docker.com/registry/spec/api/)
#'
#' @examples
#' \dontrun{
#'
#' rg <- AzureRMR::get_azure_login()$
#'     get_subscription("subscription_id")$
#'     get_resource_group("rgname")
#'
#' rg$get_acr("myregistry")
#'
#' }
NULL


#' Delete an Azure Container Registry (ACR)
#'
#' Method for the [AzureRMR::az_resource_group] class.
#'
#' @rdname delete_acr
#' @name delete_acr
#' @aliases delete_acr
#'
#' @section Usage:
#' ```
#' delete_acr(name, confirm=TRUE, wait=FALSE)
#' ```
#' @section Arguments:
#' - `name`: The name of the container registry.
#' - `confirm`: Whether to ask for confirmation before deleting.
#' - `wait`: Whether to wait until the deletion is complete.
#'
#' @section Value:
#' NULL on successful deletion.
#'
#' @seealso
#' [create_acr], [get_acr]
#'
#' [az_container_registry]
#'
#' [docker_registry] for the registry endpoint
#'
#' [ACR documentation](https://docs.microsoft.com/en-us/azure/container-registry/) and
#' [API reference](https://docs.microsoft.com/en-us/rest/api/containerregistry/registries)
#'
#' [Docker registry API](https://docs.docker.com/registry/spec/api/)
#'
#' @examples
#' \dontrun{
#'
#' rg <- AzureRMR::get_azure_login()$
#'     get_subscription("subscription_id")$
#'     get_resource_group("rgname")
#'
#' rg$delete_acr("myregistry")
#'
#' }
NULL


add_acr_methods <- function()
{
    az_resource_group$set("public", "create_acr", overwrite=TRUE,
    function(name, location=self$location,
             admin_user_enabled=TRUE, sku="Standard", ..., wait=TRUE)
    {
        AzureContainers::acr$new(self$token, self$subscription, self$name,
            type="Microsoft.containerRegistry/registries", name=name, location=location,
            properties=list(adminUserEnabled=admin_user_enabled),
            sku=list(name=sku, tier=sku),
            ..., wait=wait)
    })

    az_resource_group$set("public", "get_acr", overwrite=TRUE,
    function(name)
    {
        AzureContainers::acr$new(self$token, self$subscription, self$name,
            type="Microsoft.containerRegistry/registries", name=name)
    })

    az_resource_group$set("public", "delete_acr", overwrite=TRUE,
    function(name, confirm=TRUE, wait=FALSE)
    {
        self$get_acr(name)$delete(confirm=confirm, wait=wait)
    })

    az_resource_group$set("public", "list_acrs", overwrite=TRUE,
    function()
    {
        provider <- "Microsoft.ContainerRegistry"
        path <- "registries"
        api_version <- az_subscription$
            new(self$token, self$subscription)$
            get_provider_api_version(provider, path)

        op <- file.path("resourceGroups", self$name, "providers", provider, path)

        cont <- call_azure_rm(self$token, self$subscription, op, api_version=api_version)
        lst <- lapply(cont$value,
            function(parms) AzureContainers::acr$new(self$token, self$subscription, deployed_properties=parms))

        # keep going until paging is complete
        while(!is_empty(cont$nextLink))
        {
            cont <- call_azure_url(self$token, cont$nextLink)
            lst <- lapply(cont$value,
                function(parms) AzureContainers::acr$new(self$token, self$subscription, deployed_properties=parms))
        }
        named_list(lst)
    })

    az_subscription$set("public", "list_acrs", overwrite=TRUE,
    function()
    {
        provider <- "Microsoft.ContainerRegistry"
        path <- "registries"
        api_version <- self$get_provider_api_version(provider, path)

        op <- file.path("providers", provider, path)

        cont <- call_azure_rm(self$token, self$id, op, api_version=api_version)
        lst <- lapply(cont$value,
            function(parms) AzureContainers::acr$new(self$token, self$id, deployed_properties=parms))

        # keep going until paging is complete
        while(!is_empty(cont$nextLink))
        {
            cont <- call_azure_url(self$token, cont$nextLink)
            lst <- lapply(cont$value,
                function(parms) AzureContainers::acr$new(self$token, self$id, deployed_properties=parms))
        }
        named_list(lst)
    })
}


