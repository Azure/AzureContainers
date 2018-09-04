#' Create Azure Container Registry (ACR)
#'
#' Method for the [AzureRMR::az_resource_group] class.
#'
#' @rdname create_acr
#' @name create_acr
#' @usage
#' create_acr(name, location = self$location,
#'            admin_user_enabled = TRUE, sku = "Standard", ...)
#'
#' @param name The name of the container registry.
#' @param location The location/region in which to create the container registry. Defaults to this resource group's location.
#' @param admin_user_enabled Whether to enable the Admin user. Currently this must be TRUE to allow Docker to access the registry.
#' @param sku The SKU.
#' @param ... Other named arguments to pass to the [az_resource] initialization function.
#'
#' @details
#' An ACR resource is a Docker registry hosted in Azure. See the [documentation for the resource](https://docs.microsoft.com/en-us/azure/container-registry/) for more information. To work with the registry (transfer images, retag images, etc) see the [documentation for the registry endpoint](docker_registry).
#'
#' @return
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
NULL


#' Get Azure Container Registry (ACR)
#'
#' Method for the [AzureRMR::az_resource_group] class.
#'
#' @rdname get_acr
#' @name get_acr
#' @aliases list_acrs
#'
#' @usage
#' get_acr(name)
#' list_acrs()
#'
#' @param name For `get_acr()`, the name of the container registry resource.
#'
#' @details
#' The `AzureRMR::az_resource_group` class has both `get_acr()` and `list_acrs()` methods, while the `AzureRMR::az_subscription` class only has the latter.
#'
#' @return
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
NULL


#' Delete an Azure Container Registry (ACR)
#'
#' Method for the [AzureRMR::az_resource_group] class.
#'
#' @rdname delete_acr
#' @name delete_acr
#'
#' @usage
#' delete_acr(name, confirm=TRUE, wait=FALSE)
#'
#' @param name The name of the container registry.
#' @param confirm Whether to ask for confirmation before deleting.
#' @param wait Whether to wait until the deletion is complete.
#'
#' @return
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
NULL


add_acr_methods <- function()
{
    az_resource_group$set("public", "create_acr", overwrite=TRUE,
    function(name, location=self$location,
             admin_user_enabled=TRUE, sku="Standard", ...)
    {
        acr$new(self$token, self$subscription, self$name,
                type="Microsoft.containerRegistry/registries", name=name, location=location,
                properties=list(adminUserEnabled=admin_user_enabled),
                sku=list(name=sku, tier=sku),
                ...)
    })

    az_resource_group$set("public", "get_acr", overwrite=TRUE,
    function(name)
    {
        acr$new(self$token, self$subscription, self$name,
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
            function(parms) aks$new(self$token, self$subscription, deployed_properties=parms))

        # keep going until paging is complete
        while(!is_empty(cont$nextLink))
        {
            cont <- call_azure_url(self$token, cont$nextLink)
            lst <- lapply(cont$value,
                function(parms) acr$new(self$token, self$subscription, deployed_properties=parms))
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
            function(parms) aks$new(self$token, self$id, deployed_properties=parms))

        # keep going until paging is complete
        while(!is_empty(cont$nextLink))
        {
            cont <- call_azure_url(self$token, cont$nextLink)
            lst <- lapply(cont$value,
                function(parms) acr$new(self$token, self$id, deployed_properties=parms))
        }
        named_list(lst)
    })
}


