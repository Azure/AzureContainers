context("ACI interface")

tenant <- Sys.getenv("AZ_TEST_TENANT_ID")
app <- Sys.getenv("AZ_TEST_APP_ID")
password <- Sys.getenv("AZ_TEST_PASSWORD")
subscription <- Sys.getenv("AZ_TEST_SUBSCRIPTION")

if(tenant == "" || app == "" || password == "" || subscription == "")
    skip("Tests skipped: ARM credentials not set")

acrname <- Sys.getenv("AZ_TEST_ACR")
if(acrname == "")
    skip("ACI tests skipped: resource names not set")

test_that("ACI works",
{
    rgname <- Sys.getenv("AZ_TEST_RG")
    rg <- AzureRMR::az_rm$
        new(tenant=tenant, app=app, password=password)$
        get_subscription(subscription)$
        get_resource_group(rgname)

    aciname <- paste0(sample(letters, 10, TRUE), collapse="")
    expect_true(is_aci(rg$create_aci(aciname,
        image="hello-world")))

    aci <- rg$get_aci(aciname)
    expect_true(is_aci(aci))
    expect_true(is_aci(rg$list_acis()[[1]]))

    expect_silent(aci$stop())
    expect_silent(aci$start())
    expect_silent(aci$restart())

    acr <- rg$get_acr(acrname)
    expect_true(is_acr(acr))
    reg <- acr$get_docker_registry()
    expect_true(is_docker_registry(reg))

    aciname2 <- paste0(sample(letters, 10, TRUE), collapse="")
    aci2 <- rg$create_aci(aciname2,
        image=paste0(reg$server, "/hello-world"),
        registry_creds=reg)

    expect_true(is_aci(aci2))
})
