#' Call the docker commandline tool
#'
#' @param cmd The docker command. This should be a _vector_ of individual docker arguments, but can also be a single commandline string. See below.
#' @param echo Whether to echo the output of the command to the console.
#' @param ... Other arguments to pass to [processx::run].
#'
#' @details
#' This function calls the `docker` binary, which must be located in your search path. AzureContainers will search for the binary at package startup, and print a warning if it is not found.
#'
#' The docker command should be specified as a vector of the individual arguments, which is what `processx::run` expects. If a single string is passed, for convenience and back-compatibility reasons `call_docker` will split it into arguments for you. This is prone to error, for example if you are working with pathnames that contain spaces, so it's strongly recommended to pass a vector of arguments as a general practice.
#'
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
#' # build an image: recommended usage
#' call_docker(c("build", "-t", "myimage", "."))
#'
#' # alternative usage, will be split into individual arguments
#' call_docker("build -t myimage .")
#'
#' # list running containers
#' call_docker(c("container", "ls"))
#'
#' # prune unused containers and images
#' call_docker(c("container", "prune", "-f"))
#' call_docker(c("image", "prune", "-f"))
#'
#' }
#' @export
call_docker <- function(cmd="", ..., echo=getOption("azure_containers_tool_echo", TRUE))
{
    if(.AzureContainers$docker == "")
        stop("docker binary not found", call.=FALSE)

    if(length(cmd) == 1 && grepl(" ", cmd, fixed=TRUE))
        cmd <- strsplit(cmd, "\\s+")[[1]]

    win <- .Platform$OS.type == "windows"
    if(!win)
    {
        dockercmd <- "sudo"
        realcmd <- c(.AzureContainers$docker, cmd)
    }
    else
    {
        dockercmd <- .AzureContainers$docker
        realcmd <- cmd
    }

    echo <- as.logical(echo)
    val <- processx::run(dockercmd, realcmd, ..., echo=echo)
    val$cmdline <- paste("docker", paste(realcmd, collapse=" "))
    invisible(val)
}


#' Call the docker-compose commandline tool
#'
#' @param cmd The docker-compose command line to execute. This should be a _vector_ of individual docker-compose arguments, but can also be a single commandline string. See below.
#' @param echo Whether to echo the output of the command to the console.
#' @param ... Other arguments to pass to [processx::run].
#'
#' @details
#' This function calls the `docker-compose` binary, which must be located in your search path. AzureContainers will search for the binary at package startup, and print a warning if it is not found.
#'
#' The docker-compose command should be specified as a vector of the individual arguments, which is what `processx::run` expects. If a single string is passed, for convenience and back-compatibility reasons `call_docker_compose` will split it into arguments for you. This is prone to error, for example if you are working with pathnames that contain spaces, so it's strongly recommended to pass a vector of arguments as a general practice.
#'
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

    if(length(cmd) == 1 && grepl(" ", cmd, fixed=TRUE))
        cmd <- strsplit(cmd, "\\s+")[[1]]

    win <- .Platform$OS.type == "windows"
    if(!win)
    {
        dcmpcmd <- "sudo"
        realcmd <- c(.AzureContainers$dockercompose, cmd)
    }
    else
    {
        dcmpcmd <- .AzureContainers$dockercompose
        realcmd <- cmd
    }

    echo <- as.logical(echo)
    val <- processx::run(dcmpcmd, realcmd, ..., echo=echo)
    val$cmdline <- paste("docker-compose", paste(realcmd, collapse=" "))
    invisible(val)
}


#' Call the Kubernetes commandline tool, kubectl
#'
#' @param cmd The kubectl command line to execute. This should be a _vector_ of individual kubectl arguments, but can also be a single commandline string. See below.
#' @param echo Whether to echo the output of the command to the console.
#' @param config The pathname of the cluster config file, if required.
#' @param ... Other arguments to pass to [processx::run].
#'
#' @details
#' This function calls the `kubectl` binary, which must be located in your search path. AzureContainers will search for the binary at package startup, and print a warning if it is not found.
#'
#' The kubectl command should be specified as a vector of the individual arguments, which is what `processx::run` expects. If a single string is passed, for convenience and back-compatibility reasons `call_docker_compose` will split it into arguments for you. This is prone to error, for example if you are working with pathnames that contain spaces, so it's strongly recommended to pass a vector of arguments as a general practice.
#'
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
#' call_kubectl(c("create", "--help"))
#'
#' # deploy a service from a yaml file
#' call_kubectl(c("create", "-f", "deployment.yaml"))
#'
#' # get deployment and service status
#' call_kubectl(c("get", "deployment"))
#' call_kubectl(c("get", "service"))
#'
#' }
#' @export
call_kubectl <- function(cmd="", config=NULL, ..., echo=getOption("azure_containers_tool_echo", TRUE))
{
    if(.AzureContainers$kubectl == "")
        stop("kubectl binary not found", call.=FALSE)

    if(!is.null(config))
        config <- paste0("--kubeconfig=", config)

    if(length(cmd) == 1 && grepl(" ", cmd, fixed=TRUE))
        cmd <- strsplit(cmd, "\\s+")[[1]]

    echo <- as.logical(echo)
    val <- processx::run(.AzureContainers$kubectl, c(cmd, config), ..., echo=echo)
    val$cmdline <- paste("kubectl", paste(cmd, collapse=" "), config)
    invisible(val)
}


#' Call the Helm commandline tool
#'
#' @param cmd The Helm command line to execute. This should be a _vector_ of individual helm arguments, but can also be a single commandline string. See below.
#' @param echo Whether to echo the output of the command to the console.
#' @param config The pathname of the cluster config file, if required.
#' @param ... Other arguments to pass to [processx::run].
#'
#' @details
#' This function calls the `helm` binary, which must be located in your search path. AzureContainers will search for the binary at package startup, and print a warning if it is not found.
#'
#' The helm command should be specified as a vector of the individual arguments, which is what `processx::run` expects. If a single string is passed, for convenience and back-compatibility reasons `call_docker_compose` will split it into arguments for you. This is prone to error, for example if you are working with pathnames that contain spaces, so it's strongly recommended to pass a vector of arguments as a general practice.
#'
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

    if(length(cmd) == 1 && grepl(" ", cmd, fixed=TRUE))
        cmd <- strsplit(cmd, "\\s+")[[1]]

    echo <- as.logical(echo)
    val <- processx::run(.AzureContainers$helm, c(cmd, config), ..., echo=echo)
    val$cmdline <- paste("helm", paste(cmd, collapse=" "), config)
    invisible(val)
}

