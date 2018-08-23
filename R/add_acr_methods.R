add_acr_methods <- function()
{
    az_resource_group$set("public", "create_acr", overwrite=TRUE,
                          function(name, location, ...)
    {
        acr$new(self$token, self$subscription, self$name, name, location=location, ...)
    })

    az_resource_group$set("public", "get_acr", overwrite=TRUE,
                          function(name)
    {
        acr$new(self$token, self$subscription, self$name, name)
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
