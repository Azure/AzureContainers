context("AKS interface with availability set")

tenant <- Sys.getenv("AZ_TEST_TENANT_ID")
app <- Sys.getenv("AZ_TEST_APP_ID")
password <- Sys.getenv("AZ_TEST_PASSWORD")
subscription <- Sys.getenv("AZ_TEST_SUBSCRIPTION")

if(tenant == "" || app == "" || password == "" || subscription == "")
    skip("Tests skipped: ARM credentials not set")

rgname <- make_name(10)
rg <- AzureRMR::az_rm$
    new(tenant=tenant, app=app, password=password)$
    get_subscription(subscription)$
    create_resource_group(rgname, location="australiaeast")

test_that("AKS works with availability set",
{
    aksname <- make_name(10)
    expect_true(is_aks(rg$create_aks(aksname, agent_pools=aks_pool("pool1", 1, use_scaleset=FALSE),
        managed_identity=TRUE)))

    aks <- rg$get_aks(aksname)
    expect_true(is_aks(aks))

    pool1 <- aks$get_agent_pool("pool1")
    expect_is(pool1, "az_agent_pool")

    pools <- aks$list_agent_pools()
    expect_true(is.list(pools) && length(pools) == 1 && all(sapply(pools, inherits, "az_agent_pool")))

    expect_error(aks$create_agent_pool("pool2", 1, disksize=500, wait=TRUE))

    clus <- aks$get_cluster()
    expect_true(is_kubernetes_cluster(clus))
})


teardown({
    suppressMessages(rg$delete(confirm=FALSE))
})
