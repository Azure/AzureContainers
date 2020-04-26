context("AKS interface with availability set")

tenant <- Sys.getenv("AZ_TEST_TENANT_ID")
app <- Sys.getenv("AZ_TEST_APP_ID")
password <- Sys.getenv("AZ_TEST_PASSWORD")
subscription <- Sys.getenv("AZ_TEST_SUBSCRIPTION")

if(tenant == "" || app == "" || password == "" || subscription == "")
    skip("Tests skipped: ARM credentials not set")

acrname <- Sys.getenv("AZ_TEST_ACR")
if(acrname == "")
    skip("AKS tests skipped: resource names not set")

rgname <- Sys.getenv("AZ_TEST_RG")
rg <- AzureRMR::az_rm$
    new(tenant=tenant, app=app, password=password)$
    get_subscription(subscription)$
    get_resource_group(rgname)

acr <- rg$get_acr(acrname)


test_that("AKS works with availability set",
{
    reg <- acr$get_docker_registry(as_admin=TRUE)
    expect_true(is_docker_registry(reg))
    expect_false(is.null(reg$username) || is.null(reg$password))

    aksname <- paste0(sample(letters, 10, TRUE), collapse="")
    expect_true(is_aks(rg$create_aks(aksname, agent_pools=aks_pools("pool1", 1),
        managed_identity=TRUE, use_scaleset=FALSE)))

    aks <- rg$get_aks(aksname)
    expect_true(is_aks(aks))
})

