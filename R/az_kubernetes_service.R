#' @export
aks <- R6::R6Class("az_kubernetes_service", inherit=AzureRMR::az_resource,

public=list(

    get_cluster=function(config=tempfile(pattern="kubeconfig"), role=c("User", "Admin"))
    {
        role <- match.arg(role)
        cred_profile <- private$res_op(paste0("accessProfiles/cluster", role))$properties$kubeConfig
        cred_profile <- rawToChar(openssl::base64_decode(cred_profile))

        # provide ability to save to default .kube/config by passing a NULL
        if(is.null(config))
        {
            win <- .Platform$OS.type == "windows"
            config <- if(win)
                file.path(Sys.getenv("HOMEPATH"), ".kube/config")
            else file.path(Sys.getenv("HOME"), ".kube/config")
        }

        if(file.exists(config))
            message("Overwriting existing cluster information in ", config)
        else message("Storing cluster information in ", config)

        writeLines(cred_profile, config)
        kubernetes_cluster$new(config=config)
    }
))


#' @export
is_aks <- function(object)
{
    R6::is.R6(object) && inherits(object, "az_kubernetes_service")
}


#' @export
aks_pools <- function(name, count, size, os)
{
    count <- as.integer(count)
    pool_df <- data.frame(name=name, count=count, vmSize=size, osType=os, stringsAsFactors=FALSE)
    pool_df$name <- make.unique(pool_df$name, sep="")
    lapply(seq_len(nrow(pool_df)), function(i) unclass(pool_df[i, ]))
}
