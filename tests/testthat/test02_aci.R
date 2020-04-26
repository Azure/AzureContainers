context("ACI interface")

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

test_that("ACI works",
{
    acrname <- make_name(10)
    acr <- rg$create_acr(acrname, admin_user_enabled=TRUE)
    reg <- acr$get_docker_registry(as_admin=TRUE)
    expect_true(is_docker_registry(reg))
    expect_false(is.null(reg$username) || is.null(reg$password))

    cmdline <- "build -f ../resources/hello_dockerfile -t hello-world ."
    call_docker(cmdline)

    reg$push("hello-world")

    cmdline <- paste0("image rm ", acrname, ".azurecr.io/hello-world")
    call_docker(cmdline)

    # from local image
    aciname <- make_name(10)
    expect_true(is_aci(rg$create_aci(aciname,
        image="hello-world")))

    aci <- rg$get_aci(aciname)
    expect_true(is_aci(aci))
    expect_true(is_aci(rg$list_acis()[[1]]))

    expect_silent(aci$stop())
    expect_silent(aci$start())
    expect_silent(aci$restart())

    # from Resource Manager object
    aciname2 <- make_name(10)
    aci2 <- rg$create_aci(aciname2,
        image=paste0(reg$server$hostname, "/hello-world"),
        registry_creds=reg)

    expect_true(is_aci(aci2))

    # from Docker registry object
    aciname3 <- make_name(10)
    aci3 <- rg$create_aci(aciname3,
        image=paste0(reg$server$hostname, "/hello-world"),
        registry_creds=aci_creds(reg$server$hostname, app, password))

    expect_true(is_aci(aci3))
})


teardown({
    suppressMessages(rg$delete(confirm=FALSE))
})
