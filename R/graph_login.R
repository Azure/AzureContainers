graph_login <- function(tenant, ...)
{
    gr <- try(AzureGraph::get_graph_login(tenant=tenant), silent=TRUE)
    if(inherits(gr, "try-error"))
        gr <- AzureGraph::create_graph_login(tenant=tenant, ...)
    gr
}
