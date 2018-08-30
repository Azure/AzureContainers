#' @import AzureRMR
NULL

.AzureContainers <- new.env()


.onLoad <- function(pkgname, libname)
{
    # find docker and kubectl binaries
    .AzureContainers$docker <- Sys.which("docker")
    .AzureContainers$kubectl <- Sys.which("kubectl")

    if(.AzureContainers$docker != "")
        message("Using docker binary ", .AzureContainers$docker)
    else warning("docker binary not found", call.=FALSE)

    if(.AzureContainers$kubectl != "")
        message("Using kubectl binary ", .AzureContainers$kubectl)
    else warning("kubectl binary not found", call.=FALSE)

    ## add methods to AzureRMR resource group and subscription classes

    # ACR methods
    az_resource_group$set("public", "create_acr", overwrite=TRUE,
                          function(name, location, admin_user_enabled=TRUE, sku="Standard", ...)
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

    # AKS methods
    az_resource_group$set("public", "create_aks", overwrite=TRUE,
                          function(name, location,
                                   dns_prefix=name, kubernetes_version="1.11.2",
                                   enable_rbac=FALSE, agent_pools=list(),
                                   properties=list(), ...)

    {
        props <- c(
            list(
                kubernetesVersion=kubernetes_version,
                dnsPrefix=dns_prefix,
                agentPoolProfiles=agent_pools,
                enableRBAC=enable_rbac
            ),
            properties)

        if(is.null(props$servicePrincipalProfile))
            props$servicePrincipalProfile <- list(clientId=self$token$app$key, secret=self$token$app$secret)

        message("Creating Kubernetes cluster '", name, "'. Call the sync_fields() method to check progress.")
        aks$new(self$token, self$subscription, self$name,
                type="Microsoft.ContainerService/managedClusters", name=name, location=location,
                properties=props, ...)
    })

    az_resource_group$set("public", "get_aks", overwrite=TRUE,
                          function(name)
    {
        aks$new(self$token, self$subscription, self$name,
                type="Microsoft.ContainerService/managedClusters", name=name)
    })

    az_resource_group$set("public", "delete_aks", overwrite=TRUE,
                          function(name, confirm=TRUE, wait=FALSE)
    {
        self$get_aks(name)$delete(confirm=confirm, wait=wait)
    })

    az_resource_group$set("public", "list_aks", overwrite=TRUE,
                          function()
    {
        provider <- "Microsoft.ContainerService"
        path <- "managedClusters"
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
                function(parms) aks$new(self$token, self$subscription, deployed_properties=parms))
        }
        named_list(lst)
    })

    az_subscription$set("public", "list_aks", overwrite=TRUE,
                        function()
    {
        provider <- "Microsoft.ContainerService"
        path <- "managedClusters"
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
                function(parms) aks$new(self$token, self$id, deployed_properties=parms))
        }
        named_list(lst)
    })
}
