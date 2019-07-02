#' Utility functions to test whether an object is of the given class.
#'
#' @param object An R object
#'
#' @details
#' These functions are simple wrappers around `R6::is.R6` and `inherits`.
#'
#' @return
#' TRUE or FALSE depending on whether the object is an R6 object of the specified class.
#' @rdname is
#' @export
is_acr <- function(object)
{
    R6::is.R6(object) && inherits(object, "az_container_registry")
}


#' @rdname is
#' @export
is_aks <- function(object)
{
    R6::is.R6(object) && inherits(object, "az_kubernetes_service")
}


#' @rdname is
#' @export
is_aci <- function(object)
{
    R6::is.R6(object) && inherits(object, "az_container_instance")
}


#' @rdname is
#' @export
is_docker_registry <- function(object)
{
    R6::is.R6(object) && inherits(object, "DockerRegistry")
}


#' @rdname is
#' @export
is_kubernetes_cluster <- function(object)
{
    R6::is.R6(object) && inherits(object, "KubernetesCluster")
}
