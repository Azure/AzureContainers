#' Create Azure Kubernetes Service (AKS)
#'
#' Method for the [AzureRMR::az_resource_group] class.
#'
#' @rdname create_aks
#' @name create_aks
#' @usage
#' create_aks(name, location = self$location,
#'            dns_prefix = name, kubernetes_version = NULL,
#'            enable_rbac = FALSE, agent_pools = list(),
#'            login_user = "", login_passkey = "",
#'            properties = list(), ...)
#'
#' @param name The name of the Kubernetes service.
#' @param location The location/region in which to create the service. Defaults to this resource group's location.
#' @param dns_prefix The domain name prefix to use for the cluster endpoint. The actual domain name will start with this argument, followed by a string of pseudorandom characters.
#' @param kubernetes_version The Kubernetes version to use. If not specified, defaults to `"1.11.2"`.
#' @param enable_rbac Whether to enable role-based access controls.
#' @param agent_pools A list of pool specifications. See 'Details'.
#' @param login_user,login_passkey Optionally, a login username and public key (on Linux). Specify these if you want to be able to ssh into the cluster nodes.
#' @param properties A named list of further Kubernetes-specific properties to pass to the initialization function.
#' @param ... Other named arguments to pass to the initialization function.
#'
#' @details
#' An AKS resource is a Kubernetes cluster hosted in Azure. See the [documentation for the resource](aks) for more information. To work with the cluster (deploy images, define and start services, etc) see the [documentation for the cluster endpoint](kubernetes_cluster).
#'
#' To specify the agent pools for the cluster, it is easiest to use the [aks_pools] function. This takes as arguments the name(s) of the pools, the number of nodes, the VM size(s) to use, and the operating system (Windows or Linux) to run on the VMs. Note that currently, AKS only supports one agent pool per cluster.
#'
#' @return
#' An object of class `az_kubernetes_service` representing the service.
#'
#' @seealso
#' [get_aks], [delete_aks], [list_aks], [aks_pools]
#'
#' [az_kubernetes_service]
#'
#' [kubernetes_cluster] for the cluster endpoint
#'
#' [AKS documentation](https://docs.microsoft.com/en-us/azure/aks/) and
#' [API reference](https://docs.microsoft.com/en-us/rest/api/aks/)
#'
#' [Kubernetes reference](https://kubernetes.io/docs/reference/)
NULL


#' Get Azure Kubernetes Service (AKS)
#'
#' Method for the [AzureRMR::az_resource_group] class.
#'
#' @rdname get_aks
#' @name get_aks
#' @aliases list_aks
#'
#' @usage
#' get_aks(name)
#' list_aks()
#'
#' @param name For `get_aks()`, the name of the Kubernetes service.
#'
#' @details
#' The `AzureRMR::az_resource_group` class has both `get_aks()` and `list_aks()` methods, while the `AzureRMR::az_subscription` class only has the latter.
#'
#' @return
#' For `get_aks()`, an object of class `az_kubernetes_service` representing the service.
#'
#' For `list_aks()`, a list of such objects.
#'
#' @seealso
#' [create_aks], [delete_aks]
#'
#' [az_kubernetes_service]
#'
#' [kubernetes_cluster] for the cluster endpoint
#'
#' [AKS documentation](https://docs.microsoft.com/en-us/azure/aks/) and
#' [API reference](https://docs.microsoft.com/en-us/rest/api/aks/)
#'
#' [Kubernetes reference](https://kubernetes.io/docs/reference/)
NULL


#' Delete an Azure Kubernetes Service (AKS)
#'
#' Method for the [AzureRMR::az_resource_group] class.
#'
#' @rdname delete_aks
#' @name delete_aks
#'
#' @usage
#' delete_aks(name, confirm=TRUE, wait=FALSE)
#'
#' @param name The name of the Kubernetes service.
#' @param confirm Whether to ask for confirmation before deleting.
#' @param wait Whether to wait until the deletion is complete.
#'
#' @return
#' NULL on successful deletion.
#'
#' @seealso
#' [create_aks], [get_aks]
#'
#' [az_kubernetes_service]
#'
#' [kubernetes_cluster] for the cluster endpoint
#'
#' [AKS documentation](https://docs.microsoft.com/en-us/azure/aks/) and
#' [API reference](https://docs.microsoft.com/en-us/rest/api/aks/)
#'
#' [Kubernetes reference](https://kubernetes.io/docs/reference/)
NULL


add_aks_methods <- function()
{
    az_resource_group$set("public", "create_aks", overwrite=TRUE,
    function(name, location=self$location,
             dns_prefix=name, kubernetes_version=NULL,
             login_user="", login_passkey="",
             enable_rbac=FALSE, agent_pools=list(),
             properties=list(), ...)
    {
        if(is.null(kubernetes_version))
            kubernetes_version <- .AzureContainers$kubever

        props <- c(
            list(
                kubernetesVersion=kubernetes_version,
                dnsPrefix=dns_prefix,
                agentPoolProfiles=agent_pools,
                enableRBAC=enable_rbac
            ),
            properties)

        if(login_user != "" && login_passkey != "")
            props$linuxProfile <- list(
                adminUsername=login_user,
                ssh=list(publicKeys=list(list(Keydata=login_passkey)))
            )

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

