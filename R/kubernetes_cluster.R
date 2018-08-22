#' @export
kubernetes_cluster <- R6::R6Class("kubernetes_cluster",

public=list(

    initialize=function(config=NULL)
    {
        private$config=config
    },

    create_registry_secret=function(registry, secret_name=registry$server, email_address=NULL)
    {
        if(is_acr(registry))
            registry <- registry$get_docker_registry(registry)

        str <- paste0("create secret docker-registry ", secret_name,
                  " --docker-server=", registry$server,
                  " --docker-username=", registry$username,
                  " --docker-password=", registry$password,
                  if(!is.null(email_address)) paste0(" --docker-email=", email_addr))

        private$kubectl(str)
    },

    delete_registry_secret=function(secret_name)
    {
        str <- paste0("delete secret ", secret_name)
        private$kubectl(str)
    },

    run=function(name, image, options="")
    {
        str <- paste0("run ", name,
                      " --image ", image,
                      " ", options)
        private$kubectl(str)
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
        private$kubectl(str)
    },

    create=function(file, options="")
    {
        str <- paste0("create -f ", file,
                      " ", options)
        private$kubectl(str)
    },

    apply=function(file, options="")
    {
        str <- paste0("apply -f ", file,
                      " ", options)
        private$kubectl(str)
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
        private$kubectl(str)
    }
),

private=list(
    config=NULL,

    kubectl=function(str, ...)
    {
        if(!is_empty(private$config))
            str <- paste0(str, " --kubeconfig=", shQuote(private$config))
        call_kubectl(str)
    }
))


#' @export
is_kubernetes_cluster <- function(object)
{
    R6::is.R6(object) && inherits(object, "kubernetes_cluster")
}


#' @export
call_kubectl <- function(str, ...)
{
    message("Kubernetes operation: ", str)
    val <- system2("kubectl", str, ...)
    attr(val, "cmdline") <- paste("kubectl", str)
    invisible(val)
}
