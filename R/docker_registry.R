#' Docker registry class
#'
#' Class representing a [Docker registry](https://docs.docker.com/registry/). Note that this class can be used to interface with any Docker registry that supports the HTTP V2 API, not just those created via the Azure Container Registry service. Use the [docker_registry] function to instantiate new objects of this class.
#'
#' @docType class
#' @section Methods:
#' The following methods are available, in addition to those provided by the [AzureRMR::az_resource] class:
#' - `login(...)`: Do a local login to the registry via `docker login`; necessary if you want to push and pull images. By default, instantiating a new object of this class will also log you in. See 'Details' below.
#' - `push(src_image, dest_image)`: Push an image to the registry, using `docker tag` and `docker push`.
#' - `pull(image)`: Pull an image from the registry, using `docker pull`.
#' - `get_image_manifest(image, tag="latest")`: Gets the manifest for an image.
#' - `get_image_digest(image, tag="latest")`: Gets the digest (SHA hash) for an image.
#' - `delete_image(image, digest, confirm=TRUE)`: Deletes an image from the registry.
#' - `list_repositories()`: Lists the repositories (images) in the registry.
#'
#' @section Details:
#' The arguments to the `login()` method are:
#' - `tenant`: The Azure Active Directory (AAD) tenant for the registry.
#' - `username`: The username that Docker will use to authenticate with the registry. This can be either the admin username, if the registry was created with an admin account, or the ID of a registered app that has access to the registry.
#' - `password`: The password that Docker will use to authenticate with the registry.
#' - `app`: The app ID to use to authenticate with the registry. Set this to NULL to authenticate with a username and password, rather than via AAD.
#' - `...`: Further arguments passed to [AzureAuth::get_azure_token].
#' - `token`: An Azure token object. If supplied, all authentication details will be inferred from this.
#'
#' The `login()`, `push()` and `pull()` methods for this class call the `docker` commandline tool under the hood. This allows all the features supported by Docker to be available immediately, with a minimum of effort. Any calls to the `docker` tool will also contain the full commandline as the `cmdline` attribute of the (invisible) returned value; this allows scripts to be developed that can be run outside R.
#'
#' @seealso
#' [acr], [docker_registry], [call_docker]
#'
#' [Docker commandline reference](https://docs.docker.com/engine/reference/commandline/cli/)
#'
#' [Docker registry API](https://docs.docker.com/registry/spec/api/)
#'
#' @examples
#' \dontrun{
#'
#' reg <- docker_registry("myregistry")
#'
#' reg$list_repositories()
#'
#' # create an image from a Dockerfile in the current directory
#' call_docker("build -t myimage .")
#'
#' # push the image
#' reg$push("myimage")
#'
#' reg$get_image_manifest("myimage")
#' reg$get_image_digest("myimage")
#'
#' }
#' @export
DockerRegistry <- R6::R6Class("DockerRegistry",

public=list(

    server=NULL,
    username=NULL,
    password=NULL,
    aad_token=NULL,

    initialize=function(server, ..., login=TRUE)
    {
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

        # special-casing Docker Hub
        cmd <- if(self$server$hostname == "hub.docker.com")
            paste("login --password-stdin --username", username)
        else paste("login --password-stdin --username", username, self$server$hostname)

        call_docker(cmd, input=password)
        invisible(NULL)
    },

    push=function(src_image, dest_image)
    {
        out1 <- if(missing(dest_image))
        {
            dest_image <- private$paste_server(src_image)
            call_docker(sprintf("tag %s %s", src_image, dest_image))
        }
        else
        {
            dest_image <- private$paste_server(dest_image)
            call_docker(sprintf("tag %s %s", src_image, dest_image))
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
        auth <- if(is.null(self$aad_token))
        {
            userpass <- openssl::base64_encode(paste(self$username, self$password, sep=":"))
            paste("Basic", userpass)
        }
        else
        {
            creds <- private$get_creds_from_aad()
            access_token <- private$get_access_token(creds, permissions)
            paste("Bearer", access_token)
        }

        headers <- httr::add_headers(
            Accept="application/vnd.docker.distribution.manifest.v2+json",
            Authorization=auth
        )
        uri <- self$server
        uri$path <-  paste0("/v2/", op)

        res <- httr::VERB(match.arg(http_verb), uri, headers, ..., encode=encode)
        process_registry_response(res, match.arg(http_status_handler))
    }
),

private=list(

    paste_server=function(image)
    {
        # special-casing Docker Hub
        server <- if(self$server$hostname == "hub.docker.com")
            self$username
        else self$server$hostname

        server <- paste0(server, "/")
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


#' Create a new Docker registry object
#'
#' @param server The registry server. This can be a URL ("https://myregistry.azurecr.io") or a domain name label ("myregistry"); if the latter, the value of the `domain` argument is appended to obtain the full hostname.
#' @param tenant,username,password,app,... Authentication arguments to [AzureAuth::get_azure_token]. See 'Details' below.
#' @param domain The default domain for the registry server.
#' @param token An OAuth token, of class [AzureAuth::AzureToken]. If supplied, the authentication details for the registry will be inferred from this.
#' @param login Whether to perform a local login (requires that you have Docker installed). This is necessary if you want to push or pull images.
#'
#' @details
#' There are two ways to authenticate with an Azure Docker registry: via Azure Active Directory (AAD), or with a username and password. The latter is simpler, while the former is more complex but also more flexible and secure.
#'
#' The default method of authenticating is via AAD. Without any arguments, `docker_registry` will authenticate using the AAD credentials of the currently logged-in user. You can change this by supplying the appropriate arguments to `docker_registry`, which will be passed to `AzureAuth::get_azure_token`; alternatively, you can provide an existing token object.
#'
#' To authenticate via the admin user account, set `app=NULL` and supply the admin username and password in the corresponding arguments. Note that for this to work, the registry must have been created with the admin account enabled.
#'
#' Authenticating with a service principal can be done either indirectly via AAD, or via a username and password. See the examples below. The latter method is recommended, as it is both faster and allows easier interoperability with [KubernetesCluster] objects.
#'
#' @return
#' An R6 object of class `DockerRegistry`.
#'
#' @seealso
#' [DockerRegistry] for methods available for interacting with the registry, [call_docker]
#'
#' [kubernetes_cluster] for the corresponding function to create a Kubernetes cluster object
#'
#' @examples
#' \dontrun{
#'
#' # connect to the Docker registry 'myregistry.azurecr.io', authenticating as the current user
#' docker_registry("myregistry")
#'
#' # same, but providing a full URL
#' docker_registry("https://myregistry.azurecr.io")
#'
#' # authenticating via the admin account
#' docker_registry("myregistry", username="admin", password="password", app=NULL)
#'
#' # authenticating with a service principal, method 1: recommended
#' docker_registry("myregistry", username="app_id", password="client_creds", app=NULL)
#'
#' # authenticating with a service principal, method 2
#' docker_registry("myregistry", app="app_id", password="client_creds")
#'
#' # authenticating from a managed service identity (MSI)
#' token <- AzureAuth::get_managed_token("https://management.azure.com/")
#' docker_registry("myregistry", token=token)
#'
#' # you can also interact with a registry outside Azure
#' # note that some registry methods, and AAD authentication, may not work in this case
#' docker_registry("https://hub.docker.com", username="mydockerid", password="password", app=NULL)
#'
#' }
#' @export
docker_registry <- function(server, tenant="common", username=NULL, password=NULL, app=.az_cli_app_id, ...,
                            domain="azurecr.io", token=NULL, login=TRUE)
{
    if(!is_url(server))
        server <- sprintf("https://%s.%s", server, domain)

    DockerRegistry$new(server, tenant=tenant, username=username, password=password, app=app, ...,
                       token=token, login=login)
}


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

