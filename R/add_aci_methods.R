#' Create Azure Container Instance (ACI)
#'
#' Method for the [AzureRMR::az_resource_group] class.
#'
#' @rdname create_aci
#' @name create_aci
#' @usage
#' create_aci(name, location = self$location,
#'            container_name = name, image_name,
#'            registry_creds = list(),
#'            cores = 1, memory = 8,
#'            os = c("Linux", "Windows"),
#'            command = list(), env_vars = list(),
#'            ports = NULL, dns_name = name, public_ip = TRUE,
#'            restart = c("Always", "OnFailure", "Never"), ...)
#'            
#' @param name The name of the ACI service.
#' @param location The location/region in which to create the ACI service. Defaults to this resource group's location.
#' @param container_name The name of the running container.
#' @param image_name The name of the image to run.
#' @param registry_creds Docker registry authentication credentials, if the image is stored in a private registry. See 'Details'.
#' @param cores The number of CPU cores for the instance.
#' @param memory The memory size in GB for the instance.
#' @param os The operating system to run in the instance.
#' @param command A list of commands to run in the instance.
#' @param env_vars A list of name-value pairs to set as environment variables in the instance.
#' @param ports The network ports to open. See 'Details'.
#' @param dns_name The domain name prefix for the instance. Only takes effect if `public_ip=TRUE`.
#' @param public_ip Whether the instance should be publicly accessible.
#' @param restart Whether to restart the instance should an event occur.
#'
#' @details
#' An ACI resource is a running container hosted in Azure. See the [documentation for the resource](https://docs.microsoft.com/en-us/azure/container-instances/) for more information. Currently ACI only supports a single image in an instance.
#'
#' To supply the registry authentication credentials, the `registry_creds` argument should contain either an [ACI](aci) object, a [docker_registry] object, or the result of a call to the [aci_creds] function.
#'
#' The ports to open should be obtained by calling the [aci_ports] function. This takes a vector of port numbers as well as the protocol (TCP or UDP) for each port.
#'
#' @return
#' An object of class `az_container_instance` representing the instance.
#'
#' @seealso
#' [get_aci], [delete_aci], [list_acis]
#'
#' [az_container_instance]
#'
#' [ACI documentation](https://docs.microsoft.com/en-us/azure/container-instances/) and
#' [API reference](https://docs.microsoft.com/en-us/rest/api/container-instances/)
#'
#' [Docker commandline reference](https://docs.docker.com/engine/reference/commandline/cli/)
NULL


#' Get Azure Container Instance (ACI)
#'
#' Method for the [AzureRMR::az_resource_group] class.
#'
#' @rdname get_aci
#' @name get_aci
#' @aliases list_acis
#'
#' @usage
#' get_aci(name)
#' list_acis()
#'
#' @param name For `get_aci()`, the name of the container instance resource.
#'
#' @details
#' The `AzureRMR::az_resource_group` class has both `get_aci()` and `list_acis()` methods, while the `AzureRMR::az_subscription` class only has the latter.
#'
#' @return
#' For `get_aci()`, an object of class `az_container_instance` representing the instance resource.
#'
#' For `list_acis()`, a list of such objects.
#'
#' @seealso
#' [create_aci], [delete_aci]
#'
#' [az_container_instance]
#'
#' [ACI documentation](https://docs.microsoft.com/en-us/azure/container-instances/) and
#' [API reference](https://docs.microsoft.com/en-us/rest/api/container-instances/)
#'
#' [Docker commandline reference](https://docs.docker.com/engine/reference/commandline/cli/)
NULL


#' Delete an Azure Container Instance (ACI)
#'
#' Method for the [AzureRMR::az_resource_group] class.
#'
#' @rdname delete_aci
#' @name delete_aci
#'
#' @usage
#' delete_aci(name, confirm=TRUE, wait=FALSE)
#'
#' @param name The name of the container instance.
#' @param confirm Whether to ask for confirmation before deleting.
#' @param wait Whether to wait until the deletion is complete.
#'
#' @return
#' NULL on successful deletion.
#'
#' @seealso
#' [create_aci], [get_aci]
#'
#' [az_container_instance]
#'
#' [ACI documentation](https://docs.microsoft.com/en-us/azure/container-instances/) and
#' [API reference](https://docs.microsoft.com/en-us/rest/api/container-instances/)
#'
#' [Docker commandline reference](https://docs.docker.com/engine/reference/commandline/cli/)
NULL


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

