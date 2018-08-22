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
            dest_image <- self$add_server(src_image)
            out1 <- numeric(0)
        }
        else
        {
            dest_image <- self$add_server(dest_image)
            out1 <- call_docker(sprintf("tag %s %s", src_image, dest_image))
        }
        out2 <- call_docker(sprintf("push %s", dest_image))

        invisible(list(out1, out2))
    },

    pull=function(image)
    {
        image <- self$add_server(image)
        call_docker(sprintf("pull %s", image))
    },

    list_repositories=function()
    {
        call_repo(self$server, self$username, self$password, "_catalog")
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
call_docker <- function(str, ...)
{
    message("Docker operation: ", str)
    win <- .Platform$OS.type == "windows"
    val <- if(win)
        system2("docker", str, ...)
    else system2("sudo", paste("docker", str), ...)
    attr(val, "cmdline") <- paste("docker", str)
    invisible(val)
}


call_repo <- function(server, username, password, ..., http_verb="GET")
{
    auth_str <- openssl::base64_encode(username, password, sep=":")
    url <- paste0("https://", server, "/v2/", ...)
    headers <- httr::add_headers(Authorization=sprintf("Basic %s", auth_str))
    verb <- get(http_verb, getNamespace("httr"))
    verb(url, headers)
}
