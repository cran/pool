test_that("onValidate() caches query", {
  pool <- local_db_pool()
  # reset cache from initial creation + validation
  pool$state$validateQuery <- NULL

  con <- localCheckout(pool)
  onValidate(con)
  expect_equal(pool$state$validateQuery, "SELECT 1")
})
