#' Kubernetes cluster class
#'
#' Class representing a [Kubernetes](https://kubernetes.io/docs/home/) cluster. Note that this class can be used to interface with any Docker registry that supports the HTTP V2 API, not just those created via the Azure Container Registry service.
#'
#' @docType class
#' @section Methods:
#' The following methods are available, in addition to those provided by the [AzureRMR::az_resource] class:
#' - `new(...)`: Initialize a new registry object. See 'Initialization' below.
#' - `create_registry_secret(registry, secret_name, email)`: Provide authentication secret for a Docker registry. See 'Secrets' below.
#' - `delete_registry_secret(secret_name)`: Delete a registry authentication secret.
#' - `create(file)`: Creates a deployment or service from a file, using `kubectl create -f`.
#' - `get(type)`: Get information about resources, using `kubectl get`.
#' - `run(name, image)`: Run an image using `kubectl run --image`.
#' - `expose(name, type, file)`: Expose a service using `kubectl expose`. If the `file` argument is provided, read service information from there.
#' - `delete(type, name, file)`: Delete a resource (deployment or service) using `kubectl delete`. If the `file` argument is provided, read resource information from there.
#' - `apply(file)`: Apply a configuration file, using `kubectl apply -f`.
#' - `show_dashboard(port)`: Display the cluster dashboard. By default, use local port 30000.
#' - `kubectl(cmd)`: Run an arbitrary `kubectl` command on this cluster. Called by the other methods above.
#' - `helm(cmd)`: Run a `helm` command on this cluster.
#'
#' @section Initialization:
#' The `new()` method takes one argument: `config`, the name of the file containing the configuration details for the cluster. This should be a yaml or json file in the standard Kubernetes configuration format. Set this to NULL to use the default `~/.kube/config` file.
#'
#' @section Secrets:
#' To allow a cluster to authenticate with a Docker registry, call the `create_registry_secret` method with the following arguments:
#' - `registry`: An object of class either [acr] representing an Azure Container Registry service, or [docker_registry] representing the registry itself.
#' - `secret_name`: The name to give the secret. Defaults to the name of the registry server.
#' - `email`: The email address for the Docker registry.
#'
#' @section Kubectl:
#' The methods for this class call the `kubectl` commandline tool, passing it the `--config` option to specify the configuration information for the cluster. This allows all the features supported by Kubernetes to be available immediately and with a minimum of effort, although it does require that `kubectl` be installed. Any calls to `kubectl` will also contain the full commandline as the `cmdline` attribute of the (invisible) returned value; this allows scripts to be developed that can be run outside R.
#'
#' @seealso
#' [aks], [call_kubectl]
#'
#' [Kubectl commandline reference](https://kubernetes.io/docs/reference/generated/kubectl/kubectl-commands)
#' @export
kubernetes_cluster <- R6::R6Class("kubernetes_cluster",

public=list(

    initialize=function(config=NULL)
    {
        private$config <- config
    },

    create_registry_secret=function(registry, secret_name=registry$server, email)
    {
        if(is_acr(registry))
            registry <- registry$get_docker_registry(registry)

        cmd <- paste0("create secret docker-registry ", secret_name,
                      " --docker-server=", registry$server,
                      " --docker-username=", registry$username,
                      " --docker-password=", registry$password,
                      " --docker-email=", email)

        self$kubectl(cmd)
    },

    delete_registry_secret=function(secret_name)
    {
        cmd <- paste0("delete secret ", secret_name)
        self$kubectl(cmd)
    },

    run=function(name, image, options="")
    {
        cmd <- paste0("run ", name,
                      " --image ", image,
                      " ", options)
        self$kubectl(cmd)
    },

    expose=function(name, type=c("pod", "service", "replicationcontroller", "deployment", "replicaset"),
                    file=NULL, options="")
    {
        if(is.null(file))
        {
            type <- match.arg(type)
            cmd <- paste0("expose ", type,
                          " ", name,
                          " ", options)
        }
        else
        {
            cmd <- paste0("expose -f ", make_file(file, ".yaml"),
                          " ", options)
        }
        self$kubectl(cmd)
    },

    create=function(file, options="")
    {
        cmd <- paste0("create -f ", make_file(file, ".yaml"),
                      " ", options)
        self$kubectl(cmd)
    },

    apply=function(file, options="")
    {
        cmd <- paste0("apply -f ", make_file(file, ".yaml"),
                      " ", options)
        self$kubectl(cmd)
    },

    delete=function(type, name, file=NULL, options="")
    {
        if(is.null(file))
        {
            cmd <- paste0("delete ", type,
                          " ", name,
                          " ", options)
        }
        else
        {
            cmd <- paste0("delete -f ", make_file(file, ".yaml"),
                          " ", options)
        }
        self$kubectl(cmd)
    },

    get=function(type, options="")
    {
        cmd <- paste0("get ", type,
                      " ", options)
        self$kubectl(cmd)
    },

    show_dashboard=function(port=30000, options="")
    {
        cmd <- paste0("proxy --port ", port,
                      " ", options)
        self$kubectl(cmd, wait=FALSE)
        url <- paste0("http://localhost:",
            port,
            "/api/v1/namespaces/kube-system/services/kubernetes-dashboard/proxy/#!/overview")
        message("If the dashboard does not appear, enter the URL '", url, "' in your browser")
        browseURL(url)
    },

    kubectl=function(cmd="", ...)
    {
        if(!is_empty(private$config))
            cmd <- paste0(cmd, " --kubeconfig=", shQuote(private$config))
        call_kubectl(cmd, ...)
    },

    helm=function(cmd="", ...)
    {
        if(!is_empty(private$config))
            cmd <- paste0(cmd, " --kubeconfig=", shQuote(private$config))
        call_helm(cmd, ...)
    }
),

private=list(
    config=NULL
))


#' Call the Kubernetes commandline tool, kubectl
#'
#' @param cmd The kubectl command line to execute.
#' @param ... Other arguments to pass to [system2].
#'
#' @details
#' This function calls the `kubectl` binary, which must be located in your search path. AzureContainers will search for the binary at package startup, and print a warning if it is not found.

#' @return
#' By default, the return code from the `kubectl` binary. The return value will have an added attribute `cmdline` that contains the command line. This makes it easier to construct scripts that can be run outside R.
#'
#' @seealso
#' [system2], [call_docker], [call_helm]
#'
#' [kubernetes_cluster]
#'
#' [Kubectl command line reference](https://kubernetes.io/docs/reference/kubectl/overview/)
#'
#' @export
call_kubectl <- function(cmd="", ...)
{
    if(.AzureContainers$kubectl == "")
        stop("kubectl binary not found", call.=FALSE)
    message("Kubernetes operation: ", cmd)
    val <- system2(.AzureContainers$kubectl, cmd, ...)
    attr(val, "cmdline") <- paste("kubectl", cmd)
    invisible(val)
}


#' Call the Helm commandline tool
#'
#' @param cmd The Helm command line to execute.
#' @param ... Other arguments to pass to [system2].
#'
#' @details
#' This function calls the `helm` binary, which must be located in your search path. AzureContainers will search for the binary at package startup, and print a warning if it is not found.

#' @return
#' By default, the return code from the `helm` binary. The return value will have an added attribute `cmdline` that contains the command line. This makes it easier to construct scripts that can be run outside R.
#'
#' @seealso
#' [system2], [call_docker], [call_kubectl]
#'
#' [kubernetes_cluster]
#'
#' [Kubectl command line reference](https://kubernetes.io/docs/reference/kubectl/overview/)
#'
#' @export
call_helm <- function(cmd="", ...)
{
    if(.AzureContainers$helm == "")
        stop("helm binary not found", call.=FALSE)
    message("Helm operation: ", cmd)
    val <- system2(.AzureContainers$helm, cmd, ...)
    attr(val, "cmdline") <- paste("helm", cmd)
    invisible(val)
}


# generate a file from a character vector to be passed to kubectl
make_file <- function(file, ext="")
{
    if(length(file) == 1 && file.exists(file))
        return(file)

    out <- tempfile(fileext=ext)
    writeLines(file, out)
    out
}
