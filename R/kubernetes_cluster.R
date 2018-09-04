#' @export
kubernetes_cluster <- R6::R6Class("kubernetes_cluster",

public=list(

    initialize=function(config=NULL)
    {
        private$config=config
    },

    create_registry_secret=function(registry, secret_name=registry$server, email)
    {
        if(is_acr(registry))
            registry <- registry$get_docker_registry(registry)

        str <- paste0("create secret docker-registry ", secret_name,
                      " --docker-server=", registry$server,
                      " --docker-username=", registry$username,
                      " --docker-password=", registry$password,
                      " --docker-email=", email)

        self$kubectl(str)
    },

    delete_registry_secret=function(secret_name)
    {
        str <- paste0("delete secret ", secret_name)
        self$kubectl(str)
    },

    run=function(name, image, options="")
    {
        str <- paste0("run ", name,
                      " --image ", image,
                      " ", options)
        self$kubectl(str)
    },

    expose=function(name, type=c("pod", "service", "replicationcontroller", "deployment", "replicaset"),
                    file=NULL, options="")
    {
        if(is.null(file))
        {
            type <- match.arg(type)
            str <- paste0("expose ", type,
                          " ", name,
                          " ", options)
        }
        else
        {
            str <- paste0("expose -f ", file,
                          " ", options)
        }
        self$kubectl(str)
    },

    create=function(file, options="")
    {
        str <- paste0("create -f ", file,
                      " ", options)
        self$kubectl(str)
    },

    apply=function(file, options="")
    {
        str <- paste0("apply -f ", file,
                      " ", options)
        self$kubectl(str)
    },

    delete=function(type, name, file=NULL, options="")
    {
        if(is.null(file))
        {
            str <- paste0("delete ", type,
                          " ", name,
                          " ", options)
        }
        else
        {
            str <- paste0("delete -f ", file,
                          " ", options)
        }
        self$kubectl(str)
    },

    get=function(type, options="")
    {
        str <- paste0("get ", type,
                      " ", options)
        self$kubectl(str)
    },

    kubectl=function(str="", ...)
    {
        if(!is_empty(private$config))
            str <- paste0(str, " --kubeconfig=", shQuote(private$config))
        call_kubectl(str)
    }
),

private=list(
    config=NULL
))


#' @export
call_kubectl <- function(str="", ...)
{
    if(.AzureContainers$kubectl == "")
        stop("kubectl binary not found", call.=FALSE)
    message("Kubernetes operation: ", str)
    val <- system2(.AzureContainers$kubectl, str, ...)
    attr(val, "cmdline") <- paste("kubectl", str)
    invisible(val)
}
