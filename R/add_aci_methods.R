add_aci_methods <- function()
{
    az_resource_group$set("public", "create_aci", overwrite=TRUE,
    function(name, location=self$location,
             container_name=name,
             image_name,
             registry_creds=list(),
             cores=1,
             memory=8,
             os=c("Linux", "Windows"),
             command=list(),
             env_vars=list(),
             ports=NULL,
             dns_name=name,
             public_ip=TRUE,
             restart=c("Always", "OnFailure", "Never"),
             ...)
    {
        containers <- list(
            name=container_name,
            properties=list(
                image=image_name,
                command=command,
                environmentVariables=env_vars,
                resources=list(requests=list(cpu=cores, memoryInGB=memory)),
                ports=ports
            ))

        props <- list(
            containers=list(containers),
            restartPolicy=match.arg(restart),
            osType=match.arg(os))

        if(!is_empty(registry_creds))
            props$imageRegistryCredentials <- get_aci_credentials_list(registry_creds)
        if(public_ip)
            props$ipAddress <- list(type="public", dnsNameLabel=dns_name, ports=ports)

        aci$new(self$token, self$subscription, self$name,
                type="Microsoft.containerInstance/containerGroups", name=name, location=location,
                properties=props,
                ...)
    })

    az_resource_group$set("public", "get_aci", overwrite=TRUE,
    function(name)
    {
        aci$new(self$token, self$subscription, self$name,
                type="Microsoft.containerInstance/containerGroups", name=name)
    })

    az_resource_group$set("public", "delete_aci", overwrite=TRUE,
    function(name, confirm=TRUE, wait=FALSE)
    {
        self$get_aci(name)$delete(confirm=confirm, wait=wait)
    })

    az_resource_group$set("public", "list_acis", overwrite=TRUE,
    function()
    {
        provider <- "Microsoft.ContainerInstance"
        path <- "containerGroups"
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

    az_subscription$set("public", "list_acis", overwrite=TRUE,
    function()
    {
        provider <- "Microsoft.ContainerInstance"
        path <- "containerGroups"
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

