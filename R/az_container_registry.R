#' @export
acr <- R6::R6Class("az_container_registry", inherit=AzureRMR::az_resource,

public=list(

    list_credentials=function()
    {
        creds <- private$res_op("listCredentials", http_verb="POST")
        pwds <- sapply(creds$passwords, `[[`, "value")
        names(pwds) <- sapply(creds$passwords, `[[`, "name")
        list(username=creds$username, passwords=pwds)
    },

    list_policies=function()
    {
        private$res_op("listPolicies")
    },

    list_usages=function()
    {
        use <- private$res_op("listUsages")$value
        do.call(rbind, lapply(use, as.data.frame))
    },

    get_docker_registry=function(username=NULL, password=NULL)
    {
        creds <- self$list_credentials()
        if(is.null(username))
            username <- creds$username
        if(is.null(password))
            password <- creds$passwords[1]
        docker_registry$new(self$properties$loginServer, username, password)
    }
))


#' @export
is_acr <- function(object)
{
    R6::is.R6(object) && inherits(object, "az_container_registry")
}
