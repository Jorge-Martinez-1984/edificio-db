library(shiny)
library(shinydashboard)
library(DBI)
library(RPostgres)
library(ggplot2)
library("scales")
library(DT)

con <- dbConnect(RPostgres::Postgres(),
                 dbname = "edificio_db",
                 host = "localhost",
                 port = 5432,
                 user = "postgres",
                 password = "texto232"
)

ui <- dashboardPage(
  dashboardHeader(title = "Gestión Edificio"),
  dashboardSidebar(
    sidebarMenu(
      menuItem("Resumen", tabName = "resumen", icon = icon("home")),
      menuItem("Gastos Comunes", tabName = "gastos", icon = icon("dollar-sign")),
      menuItem("Mantención", tabName = "mantencion", icon = icon("wrench")),
      menuItem("Encomiendas", tabName = "encomiendas", icon = icon("box"))
    )
  ),
  dashboardBody(
    tabItems(
      tabItem(tabName = "resumen",
              h2("Resumen General"),
              fluidRow(
                valueBoxOutput("total_ingresos"),
                valueBoxOutput("total_egresos"),
                valueBoxOutput("fondo_reserva")
              ),
              fluidRow(
                box(title = "Trabajadores Activos", tableOutput("trabajadores"))
              ),
              fluidRow(
                box(width = 12, title = "Ingresos y Egresos", plotOutput("grafico_balance"))
              )
      ),
      tabItem(tabName = "gastos",
              h2("Gastos Comunes"),
              fluidRow(
                column(4, selectInput("filtro_depto", "Departamento:", choices = c("Todos"))),
                column(4, dateInput("filtro_fecha", "Mes:", value = Sys.Date()))
              ),
              fluidRow(
                box(width = 12, tableOutput("gastos_comunes"))
              )
      ),

      tabItem(tabName = "mantencion",
              h2("Mantención"),
              fluidRow(
                box(width = 12, title = "Buscar Trabajos Realizados",
                    textInput("buscar_trabajo", "Buscar por descripción:"),
                    tableOutput("trabajos_realizados")
                )
              ),
              fluidRow(
                box(width = 12, title = "Trabajos Pendientes", tableOutput("trabajos_pendientes"))
              ),
                    ),
      tabItem(tabName = "encomiendas",
              h2("Encomiendas"),
              fluidRow(
                box(width = 12, title = "Encomiendas Pendientes", DTOutput("encomiendas_pendientes"))
              ),
              fluidRow(
                box(width = 12, title = "Buscar Historial",
                    textInput("buscar_encomienda", "Buscar por departamento o empresa:"),
                    tableOutput("historial_encomiendas")
                )
              )
      )    )
  )
)

server <- function(input, output, session) {output$total_ingresos <- renderValueBox({
  resultado <- dbGetQuery(con, "SELECT SUM(monto) AS total FROM ingresos")
  valueBox(paste("$", prettyNum(resultado$total, big.mark = ".", scientific = FALSE)), "Total Ingresos", icon = icon("arrow-up"), color = "green")})


output$total_egresos <- renderValueBox({
  resultado <- dbGetQuery(con, "SELECT SUM(monto) AS total FROM egresos")
  valueBox(paste("$", prettyNum(resultado$total, big.mark = ".", scientific = FALSE)), "Total Egresos", icon = icon("arrow-down"), color = "red")
})

output$fondo_reserva <- renderValueBox({
  resultado <- dbGetQuery(con, "SELECT total FROM vista_balance_real")
  valueBox(paste("$", prettyNum(resultado$total, big.mark = ".", scientific = FALSE)), "Fondo de Reserva", icon = icon("piggy-bank"), color = "blue")
})

output$grafico_balance <- renderPlot({
  
  ingresos <- dbGetQuery(con, "SELECT 'Ingresos' AS tipo, DATE_TRUNC('month', fecha) AS mes, SUM(monto)::integer AS monto_total 
                              FROM ingresos 
                              GROUP BY mes 
                              ORDER BY mes ASC
                              LIMIT 12")
  
  egresos <- dbGetQuery(con, "SELECT 'Egresos' AS tipo, DATE_TRUNC('month', fecha) AS mes, SUM(monto)::integer AS monto_total 
                             FROM egresos 
                             GROUP BY mes 
                             ORDER BY mes ASC
                             LIMIT 12")
  
  
  datos <- rbind(ingresos, egresos)
  datos$tipo <- factor(datos$tipo, levels = c("Ingresos", "Egresos"))
  
  ggplot(datos, aes(x = as.Date(mes), y = monto_total, fill = tipo)) +
    geom_bar(stat = "identity", position = "dodge") +
    scale_fill_manual(values = c("Ingresos" = "steelblue", "Egresos" = "tomato")) +
    labs(x = "Mes", y = "Monto ($)") +
    theme_minimal() +
    scale_y_continuous(
      labels = function(x) format(x, big.mark = ".", scientific = FALSE),
      limits = c(0, max(datos$monto_total) * 1.1))+
    scale_x_date(date_breaks = "1 month", date_labels = "%b %Y")
  
})

output$trabajadores <- renderTable({
  dbGetQuery(con, "SELECT nombre, cargo FROM trabajadores WHERE activo = true")
})
observe({
  deptos <- dbGetQuery(con, "SELECT numero_departamento FROM departamentos ORDER BY numero_departamento")
  updateSelectInput(session, "filtro_depto", choices = c("Todos", deptos$numero_departamento))
})
output$gastos_comunes <- renderTable({
  query <- "SELECT numero_departamento AS departamento, monto, TO_CHAR(fecha_emision,'DD-MM-YYYY') AS emision 
            FROM gastos_comunes 
            INNER JOIN departamentos ON departamentos.id_departamento = gastos_comunes.id_departamento"
  
  if (input$filtro_depto != "Todos") {
    query <- paste(query, "WHERE numero_departamento =", paste0("'", input$filtro_depto, "'"),
                   "AND fecha_emision <=", paste0("'", input$filtro_fecha, "'"))
  } else {
    query <- paste(query, "WHERE fecha_emision <=", paste0("'", input$filtro_fecha, "'"))
  }
  
  query <- paste(query, "ORDER BY departamento ASC LIMIT 12")
  dbGetQuery(con, query)
}) 
output$trabajos_pendientes <- renderTable({
  dbGetQuery(con, "SELECT * FROM trabajos_faltante")
})
output$trabajos_realizados <- renderTable({
  req(nchar(input$buscar_trabajo) > 0)
  dbGetQuery(con, paste0(
    "SELECT nombre AS empresa, servicio_prestado, CAST(mantencion AS TEXT) AS tipo, TO_CHAR(fecha_trabajo, 'DD-MM-YYYY') AS fecha
     FROM mantencion 
     INNER JOIN empresas ON empresas.id_empresa = mantencion.id_empresa
     WHERE LOWER(servicio_prestado) LIKE LOWER('%", input$buscar_trabajo, "%')
     OR LOWER(CAST(mantencion AS TEXT)) LIKE LOWER('%", input$buscar_trabajo, "%')"
  ))
})
output$encomiendas_pendientes <- renderDT({
  datos <- dbGetQuery(con, "SELECT e.empresa_despacho AS Empresa, d.numero_departamento AS departamento, h.estado,
                   TO_CHAR(h.fecha_hora, 'DD-MM-YYYY') AS fecha,
                   CURRENT_DATE - h.fecha_hora::date AS dias_guardado
                   FROM historial_encomienda h
                   INNER JOIN encomienda e ON e.id_encomienda = h.id_encomienda
                   INNER JOIN departamentos d ON d.id_departamento = e.id_departamento
                   WHERE h.estado != 'Entregado'")
  
  datatable(datos, options = list(searching = FALSE)) %>%
    formatStyle('dias_guardado',
                backgroundColor = styleInterval(c(3, 7), c('white', 'orange', 'red')),
                color = styleInterval(c(3, 7), c('black', 'black', 'white'))
    )
})
output$historial_encomiendas <- renderTable({
  req(nchar(input$buscar_encomienda) > 0)
  dbGetQuery(con, paste0(
    "SELECT e.empresa_despacho, d.numero_departamento, h.estado,
     TO_CHAR(h.fecha_hora, 'DD-MM-YYYY') AS fecha
     FROM historial_encomienda h
     INNER JOIN encomienda e ON e.id_encomienda = h.id_encomienda
     INNER JOIN departamentos d ON d.id_departamento = e.id_departamento
     WHERE LOWER(d.numero_departamento) LIKE LOWER('%", input$buscar_encomienda, "%')
     OR LOWER(e.empresa_despacho) LIKE LOWER('%", input$buscar_encomienda, "%')"
  ))
})

}

shinyApp(ui = ui, server = server)