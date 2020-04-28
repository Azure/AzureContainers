#' Call the docker commandline tool
#'
#' @param cmd The docker command line to execute.
#' @param echo Whether to echo the output of the command to the console.
#' @param ... Other arguments to pass to [processx::run].
#'
#' @details
#' This function calls the `docker` binary, which must be located in your search path. AzureContainers will search for the binary at package startup, and print a warning if it is not found.

#' @return
#' A list with the following components:
#' - `status`: The exit status of the docker tool. If this is `NA`, then the process was killed and had no exit status.
#' - `stdout`: The standard output of the command, in a character scalar.
#' - `stderr`: The standard error of the command, in a character scalar.
#' - `timeout`: Whether the process was killed because of a timeout.
#' - `cmdline`: The command line.
#'
#' The first four components are from `processx::run`; AzureContainers adds the last to make it easier to construct scripts that can be run outside R.
#'
#' @seealso
#' [processx::run], [call_docker_compose], [call_kubectl] for the equivalent interface to the `kubectl` Kubernetes tool
#'
#' [docker_registry]
#'
#' [Docker command line reference](https://docs.docker.com/engine/reference/commandline/cli/)
#'
#' @examples
#' \dontrun{
#'
#' # without any args, prints the docker help screen
#' call_docker()
#'
#' # build an image
#' call_docker("build -t myimage .")
#'
#' # list running containers
#' call_docker("container ls")
#'
#' # prune unused containers and images
#' call_docker("container prune -f")
#' call_docker("image prune -f")
#'
#' }
#' @export
call_docker <- function(cmd="", ..., echo=getOption("azure_containers_tool_echo", TRUE))
{
    if(.AzureContainers$docker == "")
        stop("docker binary not found", call.=FALSE)
    message("Docker operation: ", cmd)

    win <- .Platform$OS.type == "windows"
    if(!win)
    {
        dockercmd <- "sudo"
        realcmd <- paste(.AzureContainers$docker, cmd)
    }
    else
    {
        dockercmd <- .AzureContainers$docker
        realcmd <- cmd
    }

    echo <- as.logical(echo)
    val <- processx::run(dockercmd, strsplit(realcmd, " ", fixed=TRUE)[[1]], ..., echo=echo)
    val$cmdline <- paste("docker", cmd)
    invisible(val)
}


#' Call the docker-compose commandline tool
#'
#' @param cmd The docker-compose command line to execute.
#' @param echo Whether to echo the output of the command to the console.
#' @param ... Other arguments to pass to [processx::run].
#'
#' @details
#' This function calls the `docker-compose` binary, which must be located in your search path. AzureContainers will search for the binary at package startup, and print a warning if it is not found.

#' @return
#' A list with the following components:
#' - `status`: The exit status of the docker-compose tool. If this is `NA`, then the process was killed and had no exit status.
#' - `stdout`: The standard output of the command, in a character scalar.
#' - `stderr`: The standard error of the command, in a character scalar.
#' - `timeout`: Whether the process was killed because of a timeout.
#' - `cmdline`: The command line.
#'
#' The first four components are from `processx::run`; AzureContainers adds the last to make it easier to construct scripts that can be run outside R.
#'
#' @seealso
#' [processx::run], [call_docker], [call_kubectl] for the equivalent interface to the `kubectl` Kubernetes tool
#'
#' [docker_registry]
#'
#' [Docker-compose command line reference](https://docs.docker.com/compose/)
#' @export
call_docker_compose <- function(cmd="", ..., echo=getOption("azure_containers_tool_echo", TRUE))
{
    if(.AzureContainers$dockercompose == "")
        stop("docker-compose binary not found", call.=FALSE)
    message("Docker-compose operation: ", cmd)

    win <- .Platform$OS.type == "windows"
    if(!win)
    {
        dcmpcmd <- "sudo"
        realcmd <- paste(.AzureContainers$dockercompose, cmd)
    }
    else
    {
        dcmpcmd <- .AzureContainers$dockercompose
        realcmd <- cmd
    }

    echo <- as.logical(echo)
    val <- processx::run(dcmpcmd, strsplit(realcmd, " ", fixed=TRUE)[[1]], ..., echo=echo)
    val$cmdline <- paste("docker-compose", cmd)
    invisible(val)
}


#' Call the Kubernetes commandline tool, kubectl
#'
#' @param cmd The kubectl command line to execute.
#' @param echo Whether to echo the output of the command to the console.
#' @param config The pathname of the cluster config file, if required.
#' @param ... Other arguments to pass to [processx::run].
#'
#' @details
#' This function calls the `kubectl` binary, which must be located in your search path. AzureContainers will search for the binary at package startup, and print a warning if it is not found.

#' @return
#' A list with the following components:
#' - `status`: The exit status of the kubectl tool. If this is `NA`, then the process was killed and had no exit status.
#' - `stdout`: The standard output of the command, in a character scalar.
#' - `stderr`: The standard error of the command, in a character scalar.
#' - `timeout`: Whether the process was killed because of a timeout.
#' - `cmdline`: The command line.
#'
#' The first four components are from `processx::run`; AzureContainers adds the last to make it easier to construct scripts that can be run outside R.
#'
#' @seealso
#' [processx::run], [call_docker], [call_helm]
#'
#' [kubernetes_cluster]
#'
#' [Kubectl command line reference](https://kubernetes.io/docs/reference/kubectl/overview/)
#'
#' @examples
#' \dontrun{
#'
#' # without any args, prints the kubectl help screen
#' call_kubectl()
#'
#' # append "--help" to get help for a command
#' call_kubectl("create --help")
#'
#' # deploy a service from a yaml file
#' call_kubectl("create -f deployment.yaml")
#'
#' # get deployment and service status
#' call_kubectl("get deployment")
#' call_kubectl("get service")
#'
#' }
#' @export
call_kubectl <- function(cmd="", config=NULL, ..., echo=getOption("azure_containers_tool_echo", TRUE))
{
    if(.AzureContainers$kubectl == "")
        stop("kubectl binary not found", call.=FALSE)

    if(!is.null(config))
        config <- paste0("--kubeconfig=", config)
    message("Kubernetes operation: ", cmd, " ", config)

    echo <- as.logical(echo)
    val <- processx::run(.AzureContainers$kubectl, c(strsplit(cmd, " ", fixed=TRUE)[[1]], config), ..., echo=echo)
    val$cmdline <- paste("kubectl", cmd, config)
    invisible(val)
}


#' Call the Helm commandline tool
#'
#' @param cmd The Helm command line to execute.
#' @param echo Whether to echo the output of the command to the console.
#' @param config The pathname of the cluster config file, if required.
#' @param ... Other arguments to pass to [processx::run].
#'
#' @details
#' This function calls the `helm` binary, which must be located in your search path. AzureContainers will search for the binary at package startup, and print a warning if it is not found.

#' @return
#' A list with the following components:
#' - `status`: The exit status of the helm tool. If this is `NA`, then the process was killed and had no exit status.
#' - `stdout`: The standard output of the command, in a character scalar.
#' - `stderr`: The standard error of the command, in a character scalar.
#' - `timeout`: Whether the process was killed because of a timeout.
#' - `cmdline`: The command line.
#'
#' The first four components are from `processx::run`; AzureContainers adds the last to make it easier to construct scripts that can be run outside R.
#'
#' @seealso
#' [processx::run], [call_docker], [call_kubectl]
#'
#' [kubernetes_cluster]
#'
#' [Kubectl command line reference](https://kubernetes.io/docs/reference/kubectl/overview/)
#'
#' @export
call_helm <- function(cmd="", config=NULL, ..., echo=getOption("azure_containers_tool_echo", TRUE))
{
    if(.AzureContainers$helm == "")
        stop("helm binary not found", call.=FALSE)

    if(!is.null(config))
        config <- paste0("--kubeconfig=", config)
    message("Helm operation: ", cmd, " ", config)

    echo <- as.logical(echo)
    val <- processx::run(.AzureContainers$helm, c(strsplit(cmd, " ", fixed=TRUE)[[1]], config), ..., echo=echo)
    val$cmdline <- paste("helm", cmd, config)
    invisible(val)
}

