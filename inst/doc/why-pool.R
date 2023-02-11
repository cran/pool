## ---- include = FALSE---------------------------------------------------------
knitr::opts_chunk$set(
  collapse = TRUE,
  comment = "#>"
)

library(shiny)
onStop <- function(...) {
  shiny::onStop(...)
  invisible()
}

## -----------------------------------------------------------------------------
library(shiny)
library(DBI)

# In a multi-file app, you could create conn at the top of your 
# server.R file or in global.R
conn <- DBI::dbConnect(
  drv = RMySQL::MySQL(),
  dbname = "shinydemo",
  host = "shiny-demo.csa7qlmguqrf.us-east-1.rds.amazonaws.com",
  username = "guest",
  password = "guest"
)
onStop(function() {
  DBI::dbDisconnect(conn)
})

ui <- fluidPage(
  textInput("ID", "Enter your ID:", "5"),
  tableOutput("tbl"),
  numericInput("nrows", "How many cities to show?", 10),
  plotOutput("popPlot")
)

server <- function(input, output, session) {
  output$tbl <- renderTable({
    sql <- "SELECT * FROM City WHERE ID = ?id;"
    query <- sqlInterpolate(conn, sql, id = input$ID)
    dbGetQuery(conn, query)
  })
  output$popPlot <- renderPlot({
    sql <- "SELECT * FROM City LIMIT ?id;"
    query <- sqlInterpolate(conn, sql, id = input$nrows)
    df <- dbGetQuery(conn, query)
    pop <- df$Population
    names(pop) <- df$Name
    barplot(pop)
  })
}

if (interactive())
  shinyApp(ui, server)

## -----------------------------------------------------------------------------
library(shiny)
library(DBI)

connect <- function() {
  DBI::dbConnect(
    drv = RMySQL::MySQL(),
    dbname = "shinydemo",
    host = "shiny-demo.csa7qlmguqrf.us-east-1.rds.amazonaws.com",
    username = "guest",
    password = "guest"
  )
}

ui <- fluidPage(
  textInput("ID", "Enter your ID:", "5"),
  tableOutput("tbl"),
  numericInput("nrows", "How many cities to show?", 10),
  plotOutput("popPlot")
)

server <- function(input, output, session) {
  output$tbl <- renderTable({
    conn <- connect()
    on.exit(DBI::dbDisconnect(conn))

    sql <- "SELECT * FROM City WHERE ID = ?id;"
    query <- sqlInterpolate(conn, sql, id = input$ID)
    dbGetQuery(conn, query)
  })

  output$popPlot <- renderPlot({
    conn <- connect()
    on.exit(DBI::dbDisconnect(conn))

    sql <- "SELECT * FROM City LIMIT ?id;"
    query <- sqlInterpolate(conn, sql, id = input$nrows)
    df <- dbGetQuery(conn, query)
    pop <- df$Population
    names(pop) <- df$Name
    barplot(pop)
  })
}

if (interactive())
  shinyApp(ui, server)

## -----------------------------------------------------------------------------
library(shiny)
library(DBI)

pool <- pool::dbPool(
  drv = RMySQL::MySQL(),
  dbname = "shinydemo",
  host = "shiny-demo.csa7qlmguqrf.us-east-1.rds.amazonaws.com",
  username = "guest",
  password = "guest"
)
onStop(function() {
  pool::poolClose(pool)
})

ui <- fluidPage(
  textInput("ID", "Enter your ID:", "5"),
  tableOutput("tbl"),
  numericInput("nrows", "How many cities to show?", 10),
  plotOutput("popPlot")
)

server <- function(input, output, session) {
  output$tbl <- renderTable({
    sql <- "SELECT * FROM City WHERE ID = ?id;"
    query <- sqlInterpolate(pool, sql, id = input$ID)
    dbGetQuery(pool, query)
  })
  
  output$popPlot <- renderPlot({
    sql <- "SELECT * FROM City LIMIT ?id;"
    query <- sqlInterpolate(conn, sql, id = input$nrows)
    df <- dbGetQuery(pool, query)
    pop <- df$Population
    names(pop) <- df$Name
    barplot(pop)
  })
}

if (interactive())
  shinyApp(ui, server)

