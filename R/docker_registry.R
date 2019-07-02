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
#' - `username`: The username that Docker will use to authenticate with the registry. This can be either the admin username, if the registry was created with an admin account, or the ID of a registered app that has access to the registry.
#' - `password`: The password that Docker will use to authenticate with the registry.
#' - `login`: Whether to login to the registry immediately; defaults to TRUE.
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
#' rg <- AzureRMR::get_azure_login()$
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
    aad_token=NULL,

    initialize=function(server, ..., domain="azurecr.io", login=TRUE)
    {
        if(!is_url(server))
            server <- sprintf("https://%s.%s", server, domain)
        self$server <- httr::parse_url(server)

        if(login) self$login(...)
    },

    login=function(tenant="common", username=NULL, password=NULL, app=.az_cli_app_id, ..., token=NULL)
    {
        # ways to login:
        # via creds inferred from AAD token
        # if app == NULL, with admin account
        if(is.null(app))
        {
            if(is.null(username) || is.null(password))
                stop("Must supply username and password for admin login", call.=FALSE)

            self$username <- username
            self$password <- password
        }
        else
        {
            # default is to reuse token from any existing AzureRMR login
            if(is.null(token))
                token <- AzureAuth::get_azure_token("https://management.azure.com/",
                    tenant=tenant, app=app, password=password, username=username, ...)

            self$aad_token <- token
            username <- "00000000-0000-0000-0000-000000000000"
            password <- private$get_creds_from_aad()
        }

        cmd <- paste("login --password-stdin --username", username, self$server$hostname)
        call_docker(cmd, input=password)

        invisible(NULL)
    },

    push=function(src_image, dest_image)
    {
        if(missing(dest_image))
        {
            dest_image <- private$paste_server(src_image)
            out1 <- call_docker(sprintf("tag %s %s", src_image, dest_image))
        }
        else
        {
            dest_image <- private$paste_server(dest_image)
            out1 <- call_docker(sprintf("tag %s %s", src_image, dest_image))
        }

        out2 <- call_docker(sprintf("push %s", dest_image))
        invisible(list(out1, out2))
    },

    pull=function(image)
    {
        image <- private$paste_server(image)
        call_docker(sprintf("pull %s", image))
    },

    get_image_manifest=function(image, tag="latest")
    {
        if(grepl(":", image))
        {
            tag <- sub("^[^:]+:", "", image)
            image <- sub(":.+$", "", image)
        }

        op <- file.path(image, "manifests", tag)
        perms <- paste("repository", image, "pull", sep=":")

        cont <- self$call_registry(op, permissions=perms)

        # registry API doesn't set content-type correctly, need to process further
        jsonlite::fromJSON(rawToChar(cont), simplifyVector=FALSE)
    },

    get_image_digest=function(image, tag="latest")
    {
        if(grepl(":", image))
        {
            tag <- sub("^[^:]+:", "", image)
            image <- sub(":.+$", "", image)
        }

        op <- file.path(image, "manifests", tag)
        perms <- paste("repository", image, "pull", sep=":")

        cont <- self$call_registry(op, http_verb="HEAD", permissions=perms, http_status_handler="pass")
        httr::stop_for_status(cont)
        httr::headers(cont)$`docker-content-digest`
    },

    delete_image=function(image, confirm=TRUE)
    {
        if(confirm && interactive())
        {
            yn <- readline(paste0("Do you really want to delete the image '", image, "'? (y/N) "))
            if(tolower(substr(yn, 1, 1)) != "y")
                return(invisible(NULL))
        }

        # get the digest for this image
        digest <- self$get_image_digest(image)
        if(is_empty(digest))
            stop("Unable to find digest info for image", call.=FALSE)

        op <- file.path(image, "manifests", digest)
        perms <- paste("repository", image, "delete", sep=":")
        res <- self$call_registry(op, http_verb="DELETE", permissions=perms)
        invisible(res)
    },

    list_repositories=function()
    {
        res <- self$call_registry("_catalog", permissions="registry:catalog:*")
        unlist(res$repositories)
    },

    call_registry=function(op, ..., encode="form",
                           http_verb=c("GET", "DELETE", "PUT", "POST", "HEAD", "PATCH"),
                           http_status_handler=c("stop", "warn", "message", "pass"),
                           permissions="")
    {
        headers <- if(is.null(self$aad_token))
        {
            auth_str <- openssl::base64_encode(paste(username, password, sep=":"))
            httr::add_headers(
                Accept="application/vnd.docker.distribution.manifest.v2+json",
                Authorization=sprintf("Basic %s", auth_str)
            )
        }
        else
        {
            creds <- private$get_creds_from_aad()
            access_token <- private$get_access_token(creds, permissions)
            httr::add_headers(
                Accept="application/vnd.docker.distribution.manifest.v2+json",
                Authorization=paste("Bearer", access_token)
            )
        }

        uri <- self$server
        uri$path <-  paste0("/v2/", op)

        res <- httr::VERB(match.arg(http_verb), uri, headers, ..., encode=encode)
        process_registry_response(res, match.arg(http_status_handler))
    }
),

private=list(

    paste_server=function(image)
    {
        server <- paste0(self$server$hostname, "/")
        has_server <- substr(image, 1, nchar(server)) == server
        if(!has_server)
            paste0(server, image)
        else image
    },

    get_creds_from_aad=function()
    {
        if(!self$aad_token$validate())
            self$aad_token$refresh()

        uri <- self$server
        uri$path <- "oauth2/exchange"

        tenant <- if(self$aad_token$tenant == "common")
            AzureAuth::decode_jwt(self$aad_token$credentials$access_token)$payload$tid
        else self$aad_token$tenant

        res <- httr::POST(uri,
            body=list(
                grant_type="access_token",
                service=uri$hostname,
                tenant=tenant,
                access_token=self$aad_token$credentials$access_token
            ),
            encode="form"
        )

        httr::stop_for_status(res)
        httr::content(res)$refresh_token
    },

    get_access_token=function(creds, permissions)
    {
        uri <- self$server
        uri$path <- "oauth2/token"

        res <- httr::POST(uri,
            body=list(
                grant_type="refresh_token",
                service=uri$hostname,
                scope=permissions,
                refresh_token=creds
            ),
            encode="form"
        )

        httr::stop_for_status(res)
        httr::content(res)$access_token
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

