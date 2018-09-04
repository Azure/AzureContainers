#' @export
aci <- R6::R6Class("az_container_instance", inherit=AzureRMR::az_resource,

public=list(

    restart=function()
    {
        private$res_op("restart", http_verb="POST")
    },

    # synonym for restart
    start=function()
    {
        private$res_op("restart", http_verb="POST")
    },

    stop=function()
    {
        private$res_op("stop", http_verb="POST")
    }
))


#' @export
aci_ports <- function(port=80L, protocol="TCP")
{
    df <- data.frame(port=as.integer(port), protocol=protocol, stringsAsFactors=FALSE)
    lapply(seq_len(nrow(df)), function(i) unclass(df[i,]))
}


#' @export
aci_creds <- function(server, username, password)
{
    obj <- list(server=server, username=username, password=password)
    class(obj) <- "aci_creds"
    obj
}


get_aci_credentials_list <- function(lst)
{
    # try to ensure we actually have a list of registries as input
    if(is_acr(lst) || is_docker_registry(lst) || inherits(lst, "aci_creds") || !is.list(lst))
        lst <- list(lst)
    lapply(lst, extract_creds)
}

extract_creds <- function(obj, ...)
{
    UseMethod("extract_creds")
}

extract_creds.az_container_registry <- function(obj, ...)
{
    extract_creds(obj$get_docker_registry())
}

extract_creds.docker_registry <- function(obj, ...)
{
    list(server=obj$server, username=obj$username, password=obj$password)
}

extract_creds.aci_creds <- function(obj, ...)
{
    obj
}
