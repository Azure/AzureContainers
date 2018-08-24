#' @export
docker_registry <- R6::R6Class("docker_registry",

public=list(

    server=NULL,
    username=NULL,
    password=NULL,

    initialize=function(server, username, password, login=TRUE)
    {
        self$server <- server
        self$username <- username
        self$password <- password

        if(login)
            self$login()
        else invisible(NULL)
    },

    login=function()
    {
        str <- paste("login --username", self$username, "--password", self$password, self$server)
        call_docker(str)
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


#' @export
is_docker_registry <- function(object)
{
    R6::is.R6(object) && inherits(object, "docker_registry")
}


#' @export
call_docker <- function(str="", ...)
{
    if(.AzureContainers$docker == "")
        stop("docker binary not found", call.=FALSE)
    message("Docker operation: ", str)
    win <- .Platform$OS.type == "windows"
    val <- if(win)
        system2(.AzureContainers$docker, str, ...)
    else system2("sudo", paste(.AzureContainers$docker, str), ...)
    attr(val, "cmdline") <- paste("docker", str)
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


