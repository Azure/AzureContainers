context("Resource group deletion")

tenant <- Sys.getenv("AZ_TEST_TENANT_ID")
app <- Sys.getenv("AZ_TEST_APP_ID")
password <- Sys.getenv("AZ_TEST_PASSWORD")
subscription <- Sys.getenv("AZ_TEST_SUBSCRIPTION")

if(tenant == "" || app == "" || password == "" || subscription == "")
    skip("Tests skipped: ARM credentials not set")

test_that("Resource group deletion succeeds",
{
    sub <- AzureRMR::az_rm$
        new(tenant=tenant, app=app, password=password)$
        get_subscription(subscription)

    rgname <- Sys.getenv("AZ_TEST_RG")

    expect_true(sub$resource_group_exists(rgname))
    sub$delete_resource_group(rgname, confirm=FALSE)
})
