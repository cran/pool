#' Use pool with dbplyr
#'
#' Wrappers for key dplyr (and dbplyr) methods so that pool works seemlessly
#' with [dbplyr](https://dbplyr.tidyverse.org/).
#'
#' @inheritParams dplyr::tbl
#' @param src,dest A [dbPool].
#' @param from Name table or [dbplyr::sql()] string.
#' @param vars A character vector of variable names in `src`.
#'   For expert use only.
#' @examples
#' library(dplyr)
#'
#' pool <- dbPool(RSQLite::SQLite())
#' # copy a table into the database
#' copy_to(pool, mtcars, "mtcars", temporary = FALSE)
#'
#' # retrieve a table
#' mtcars_db <- tbl(pool, "mtcars")
#' mtcars_db
#' mtcars_db %>% select(mpg, cyl, disp)
#' mtcars_db %>% filter(cyl == 6) %>% collect()
#'
#' poolClose(pool)
tbl.Pool <- function(src, from, ..., vars = NULL) {
  dbplyr::tbl_sql("Pool", dbplyr::src_dbi(src), from, ..., vars = vars)
}

#' @rdname tbl.Pool
#' @param name Name for remote table. Defaults to the name of `df`, if it's
#'   an identifier, otherwise uses a random name.
#' @inheritParams dbplyr::copy_to.src_sql
copy_to.Pool <- function(dest,
                         df,
                         name = NULL,
                         overwrite = FALSE,
                         temporary = TRUE,
                         ...) {
  stop_if_temporary(temporary)

  if (is.null(name)) {
    name <- substitute(df)
    if (is_symbol(name)) {
      name <- deparse(name)
    } else {
      name <- random_table_name()
    }
  }

  local({
    db_con <- localCheckout(dest)

    dplyr::copy_to(
      dest = db_con,
      df = df,
      name = name,
      overwrite = overwrite,
      temporary = temporary,
      ...
    )
  })

  tbl.Pool(dest, name)
}

random_table_name <- function(prefix = "") {
  vals <- c(letters, LETTERS, 0:9)
  name <- paste0(sample(vals, 10, replace = TRUE), collapse = "")
  paste0(prefix, "pool_", name)
}


# Lazily registered wrapped functions ------------------------------------------

dbplyr_register_methods <- function() {
  s3_register("dplyr::tbl", "Pool")
  s3_register("dplyr::copy_to", "Pool")
  s3_register("dbplyr::dbplyr_edition", "Pool", function(con) 2L)

  # Wrappers inspect formals so can only be executed if dbplyr is available
  on_package_load("dbplyr", {
    check_dbplyr()

    dbplyr_s3_register <- function(fun_name) {
      s3_register(paste0("dbplyr::", fun_name), "Pool", dbplyr_wrap(fun_name))
    }
    dbplyr_s3_register("db_collect")
    dbplyr_s3_register("db_compute")
    dbplyr_s3_register("db_connection_describe")
    dbplyr_s3_register("db_copy_to")
    dbplyr_s3_register("db_col_types")
    dbplyr_s3_register("db_sql_render")
    dbplyr_s3_register("sql_translation")
    dbplyr_s3_register("sql_join_suffix")
    dbplyr_s3_register("sql_query_explain")
    dbplyr_s3_register("sql_query_fields")
  })
}

check_dbplyr <- function() {
  if (packageVersion("dbplyr") < "2.4.0") {
    inform(
      c(
        "!" = "Pool works best with dbplyr 2.4.0 or greater.",
        i = paste0("You have dbplyr ", packageVersion("dbplyr"), "."),
        i = "Please consider upgrading."
      ),
      class = c("packageStartupMessage", "simpleMessage")
    )
  }
}

dbplyr_wrap <- function(fun_name) {
  fun <- utils::getFromNamespace(fun_name, "dbplyr")
  args <- formals(fun)

  if ("temporary" %in% names(args)) {
    temporary <- list(quote(stop_if_temporary(temporary)))
  } else {
    temporary <- list()
  }

  call_args <- syms(set_names(names(args)))
  call_args[[1]] <- quote(db_con)
  ns_fun <- call2("::", quote(dbplyr), sym(fun_name))
  recall <- call2(ns_fun, !!!call_args)

  con <- NULL # quiet R CMD check note
  body <- expr({
    !!!temporary

    db_con <- localCheckout(con)

    !!recall
  })

  new_function(args, body, env = ns_env("pool"))
}

stop_if_temporary <- function(temporary) {
  if (!temporary) {
    return()
  }

  abort(
    c(
      "Can't use temporary tables with Pool objects",
      x = "Temporary tables are local to a connection",
      i = "Either use `temporary = FALSE`, or",
      i = "Check out a local connection with `localCheckout()`"
    ),
    call = NULL
  )
}
