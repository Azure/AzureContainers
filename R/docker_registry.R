#' Docker registry class
#'
#' Class representing a [Docker registry](https://docs.docker.com/registry/). Note that this class can be used to interface with any Docker registry that supports the HTTP V2 API, not just those created via the Azure Container Registry service.
#'
#' @docType class
#' @section Methods:
#' The following methods are available, in addition to those provided by the [AzureRMR::az_resource] class:
#' - `new(...)`: Initialize a new registry object. See 'Details'.
#' - `login`: Login to the registry via `docker login`.
#' - `push(src_image, dest_image)`: Push an image to the registry, using `docker tag` and `docker push`.
#' - `pull(image)`: Pulls an image from the registry, using `docker pull`.
#' - `delete_layer(layer, digest, confirm=TRUE)`: Deletes a layer from the registry.
#' - `delete_image(image, digest, confirm=TRUE)`: Deletes an image from the registry.
#' - `list_repositories`: Lists the repositories (images) in the registry.
#'
#' @section Details:
#' The arguments to the `new()` method are:
#' - `server`: The name of the registry server.
#' - `username`: The username that Docker will use to authenticate with the registry.
#' - `password`: The password that Docker will use to authenticate with the registry.
#' - `login`: Whether to login to the registry immediately; defaults to TRUE.
#'
#' Currently this class does not support authentication methods other than a username/password combination.
#'
#' The `login()`, `push()` and `pull()` methods for this class call the `docker` commandline tool under the hood. This allows all the features supported by Docker to be available immediately, with a minimum of effort. Any calls to the `docker` tool will also contain the full commandline as the `cmdline` attribute of the (invisible) returned value; this allows scripts to be developed that can be run outside R.
#'
#' @seealso
#' [acr], [call_docker]
#'
#' [Docker commandline reference](https://docs.docker.com/engine/reference/commandline/cli/)
#'
#' [Docker registry API](https://docs.docker.com/registry/spec/api/)
#'
#' @examples
#' \dontrun{
#'
#' # recommended way of retrieving a registry: via a resource group object
#' rg <- AzureRMR::az_rm$
#'     new(tenant="myaadtenant.onmicrosoft.com", app="app_id", password="password")$
#'     get_subscription("subscription_id")$
#'     get_resource_group("rgname")
#'
#' # get the registry endpoint
#' dockerreg <- rg$get_acr("myregistry")$get_docker_registry()
#'
#' dockerreg$login()
#' dockerreg$list_repositories()
#'
#' # create an image from a Dockerfile in the current directory
#' call_docker("build -t myimage .")
#'
#' # push the image
#' dockerreg$push("myimage")
#'
#' }
#' @export
docker_registry <- R6::R6Class("docker_registry",

public=list(

    server=NULL,
    username=NULL,
    password=NULL,
    app=NULL,

    initialize=function(server, username=NULL, password=NULL, app=NULL, login=TRUE)
    {
        self$server <- server
        self$username <- username
        self$password <- password
        self$app <- app

        if(login)
            self$login(username, password, app)
        else invisible(NULL)
    },

    login=function(username=self$username, password=self$password, app=self$app)
    {
        identity <- if(!is.null(username))
            username
        else if(!is.null(app))
            app
        else stop("No login identity available", call.=FALSE)

        cmd <- if(!is.null(password))
            paste("login --username", identity, "--password", self$password, self$server)
        else paste("login --username", identity, self$server)

        call_docker(cmd)
    },

    push=function(src_image, dest_image)
    {
        if(missing(dest_image))
        {
            dest_image <- private$add_server(src_image)
            out1 <- call_docker(sprintf("tag %s %s", src_image, dest_image))
        }
        else
        {
            dest_image <- private$add_server(dest_image)
            out1 <- call_docker(sprintf("tag %s %s", src_image, dest_image))
        }
        out2 <- call_docker(sprintf("push %s", dest_image))

        invisible(list(out1, out2))
    },

    pull=function(image)
    {
        image <- private$add_server(image)
        call_docker(sprintf("pull %s", image))
    },

    delete_layer=function(layer, digest, confirm=TRUE)
    {
        if(confirm && interactive())
        {
            yn <- readline(paste0("Do you really want to delete the layer '", image, "'? (y/N) "))
            if(tolower(substr(yn, 1, 1)) != "y")
                return(invisible(NULL))
        }

        res <- call_registry(self$server, self$username, self$password, file.path(layer, "blobs", digest),
                             http_verb="DELETE")
        invisible(res)
    },

    delete_image=function(image, digest, confirm=TRUE)
    {
        if(confirm && interactive())
        {
            yn <- readline(paste0("Do you really want to delete the image '", image, "'? (y/N) "))
            if(tolower(substr(yn, 1, 1)) != "y")
                return(invisible(NULL))
        }

        res <- call_registry(self$server, self$username, self$password, file.path(image, "manifests", digest),
                             http_verb="DELETE")
        invisible(res)
    },

    list_repositories=function()
    {
        res <- call_registry(self$server, self$username, self$password, "_catalog")
        unlist(res$repositories)
    }
),

private=list(

    add_server=function(image)
    {
        server <- paste0(self$server, "/")
        has_server <- substr(image, 1, nchar(server)) == server
        if(!has_server)
            paste0(server, image)
        else image
    }
))


#' Call the docker commandline tool
#'
#' @param cmd The docker command line to execute.
#' @param ... Other arguments to pass to [system2].
#'
#' @details
#' This function calls the `docker` binary, which must be located in your search path. AzureContainers will search for the binary at package startup, and print a warning if it is not found.

#' @return
#' By default, the return code from the `docker` binary. The return value will have an added attribute `cmdline` that contains the command line. This makes it easier to construct scripts that can be run outside R.
#'
#' @seealso
#' [system2], [call_kubectl] for the equivalent interface to the `kubectl` Kubernetes tool
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
call_docker <- function(cmd="", ...)
{
    if(.AzureContainers$docker == "")
        stop("docker binary not found", call.=FALSE)
    message("Docker operation: ", cmd)
    win <- .Platform$OS.type == "windows"
    val <- if(win)
        system2(.AzureContainers$docker, cmd, ...)
    else system2("sudo", paste(.AzureContainers$docker, cmd), ...)
    attr(val, "cmdline") <- paste("docker", cmd)
    invisible(val)
}


call_registry <- function(server, username, password, ...,
                          http_verb=c("GET", "DELETE", "PUT", "POST", "HEAD", "PATCH"),
                          http_status_handler=c("stop", "warn", "message", "pass"))
{
    auth_str <- openssl::base64_encode(paste(username, password, sep=":"))
    url <- paste0("https://", server, "/v2/", ...)
    headers <- httr::add_headers(Authorization=sprintf("Basic %s", auth_str))
    http_status_handler <- match.arg(http_status_handler)
    verb <- get(match.arg(http_verb), getNamespace("httr"))

    res <- verb(url, headers)

    process_registry_response(res, http_status_handler)
}


process_registry_response <- function(response, handler)
{
    if(handler != "pass")
    {
        handler <- get(paste0(handler, "_for_status"), getNamespace("httr"))
        handler(response)
        cont <- httr::content(response)
        if(is.null(cont))
            cont <- list()
        attr(cont, "status") <- httr::status_code(response)
        cont
    }
    else response
}


