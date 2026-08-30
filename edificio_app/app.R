# ============================================
# GESTIÓN EDIFICIO - Dashboard Shiny
# Proyecto de Portafolio - Jorge Martinez
# PostgreSQL 16 + R/Shiny
# ============================================

# --- LIBRERÍAS ---
library(shiny)
library(shinydashboard)
library(DBI)
library(RPostgres)
library(ggplot2)
library("scales")
library(DT)
library(bslib)

# --- CONEXIÓN BASE DE DATOS ---
# Conexión local a PostgreSQL. En producción usar variables de entorno para la contraseña.
con <- dbConnect(RPostgres::Postgres(),
                 dbname = "edificio_db",
                 host = "localhost",
                 port = 5432,
                 user = "postgres",
                 password = "texto232"
)

# ============================================
# INTERFAZ DE USUARIO (UI)
# Define la estructura visual del dashboard
# ============================================
ui <- dashboardPage(
  
  # --- ENCABEZADO ---
  dashboardHeader(title = "Gestión Edificio"),
  
  # --- MENÚ LATERAL ---
  # Cada menuItem corresponde a una pestaña del dashboard
  dashboardSidebar(
    sidebarMenu(
      menuItem("Resumen",       tabName = "resumen",     icon = icon("home")),
      menuItem("Gastos Comunes",tabName = "gastos",      icon = icon("dollar-sign")),
      menuItem("Mantención",    tabName = "mantencion",  icon = icon("wrench")),
      menuItem("Encomiendas",   tabName = "encomiendas", icon = icon("box"))
    )
  ),
  
  # --- CUERPO DEL DASHBOARD ---
  dashboardBody(
    tabItems(
      
      # ==========================================
      # PESTAÑA 1: RESUMEN GENERAL
      # Muestra KPIs financieros, gráfico mensual
      # y lista de trabajadores activos
      # ==========================================
      tabItem(tabName = "resumen",
              h2("Resumen General"),
              
              # Fila de KPIs: ingresos, egresos y fondo de reserva
              fluidRow(
                valueBoxOutput("total_ingresos"),
                valueBoxOutput("total_egresos"),
                valueBoxOutput("fondo_reserva")
              ),
              
              # Gráfico de barras (8/12 del ancho) + tabla trabajadores (4/12)
              fluidRow(
                column(8, box(width = 12, title = "Ingresos y Egresos",
                              plotOutput("grafico_balance", height = "300px"))),
                column(4, box(width = 12, title = "Trabajadores Activos",
                              tableOutput("trabajadores")))
              )
      ),
      
      # ==========================================
      # PESTAÑA 2: GASTOS COMUNES
      # Permite filtrar por departamento, fecha
      # y estado de pago (pagado/pendiente)
      # ==========================================
      tabItem(tabName = "gastos",
              h2("Gastos Comunes"),
              
              # Filtros: departamento, fecha límite y estado de pago
              fluidRow(
                column(4, selectInput("filtro_depto",   "Departamento:", choices = c("Todos"))),
                column(4, dateInput("filtro_fecha",     "Mes:", value = Sys.Date())),
                column(4, selectInput("filtro_estado",  "Estado:", choices = c("Todos", "Pagados", "Pendientes")))
              ),
              
              # Tabla de resultados (limitada a 12 registros)
              fluidRow(
                box(width = 12, tableOutput("gastos_comunes"))
              )
      ),
      
      # ==========================================
      # PESTAÑA 3: MANTENCIÓN
      # Buscador de trabajos realizados y lista
      # de trabajos pendientes (desde VIEW)
      # ==========================================
      tabItem(tabName = "mantencion",
              h2("Mantención"),
              
              # Buscador por descripción o tipo de mantención
              fluidRow(
                box(width = 12, title = "Buscar Trabajos Realizados",
                    textInput("buscar_trabajo", "Buscar por descripción:"),
                    tableOutput("trabajos_realizados")
                )
              ),
              
              # Lista de trabajos pendientes desde VIEW trabajos_faltante
              fluidRow(
                box(width = 12, title = "Trabajos Pendientes",
                    tableOutput("trabajos_pendientes"))
              )
      ),
      
      # ==========================================
      # PESTAÑA 4: ENCOMIENDAS
      # Buscador de historial y lista de
      # encomiendas pendientes con alerta por días
      # ==========================================
      tabItem(tabName = "encomiendas",
              h2("Encomiendas"),
              
              # Buscador de historial por depto o empresa
              fluidRow(
                box(width = 12, title = "Buscar Historial",
                    textInput("buscar_encomienda", "Buscar por departamento o empresa:"),
                    DTOutput("historial_encomiendas")
                )
              ),
              
              # Encomiendas no entregadas con color por días guardado
              # Blanco: < 3 días | Naranja: 3-7 días | Rojo: > 7 días
              fluidRow(
                box(width = 12, title = "Encomiendas Pendientes",
                    DTOutput("encomiendas_pendientes"))
              )
      )
    )
  )
)

# ============================================
# SERVIDOR (SERVER)
# Define la lógica y consultas de cada output
# ============================================
server <- function(input, output, session) {
  
  # --- PESTAÑA RESUMEN: KPIs ---
  
  # Total de ingresos registrados
  output$total_ingresos <- renderValueBox({
    resultado <- dbGetQuery(con, "SELECT SUM(monto) AS total FROM ingresos")
    valueBox(
      paste("$", prettyNum(resultado$total, big.mark = ".", scientific = FALSE)),
      "Total Ingresos", icon = icon("arrow-up"), color = "green"
    )
  })
  
  # Total de egresos registrados
  output$total_egresos <- renderValueBox({
    resultado <- dbGetQuery(con, "SELECT SUM(monto) AS total FROM egresos")
    valueBox(
      paste("$", prettyNum(resultado$total, big.mark = ".", scientific = FALSE)),
      "Total Egresos", icon = icon("arrow-down"), color = "red"
    )
  })
  
  # Fondo de reserva calculado desde la VIEW vista_balance_real
  output$fondo_reserva <- renderValueBox({
    resultado <- dbGetQuery(con, "SELECT total FROM vista_balance_real")
    valueBox(
      paste("$", prettyNum(resultado$total, big.mark = ".", scientific = FALSE)),
      "Fondo de Reserva", icon = icon("piggy-bank"), color = "blue"
    )
  })
  
  # --- PESTAÑA RESUMEN: GRÁFICO ---
  # Gráfico de barras agrupadas: ingresos y egresos por mes (últimos 12)
  output$grafico_balance <- renderPlot({
    
    ingresos <- dbGetQuery(con, "SELECT 'Ingresos' AS tipo, DATE_TRUNC('month', fecha) AS mes, SUM(monto)::integer AS monto_total 
                                FROM ingresos GROUP BY mes ORDER BY mes ASC LIMIT 12")
    
    egresos  <- dbGetQuery(con, "SELECT 'Egresos' AS tipo, DATE_TRUNC('month', fecha) AS mes, SUM(monto)::integer AS monto_total 
                                FROM egresos GROUP BY mes ORDER BY mes ASC LIMIT 12")
    
    datos <- rbind(ingresos, egresos)
    datos$tipo <- factor(datos$tipo, levels = c("Ingresos", "Egresos"))
    
    ggplot(datos, aes(x = as.Date(mes), y = monto_total, fill = tipo)) +
      geom_bar(stat = "identity", position = "dodge") +
      scale_fill_manual(values = c("Ingresos" = "steelblue", "Egresos" = "tomato")) +
      labs(x = "Mes", y = "Monto ($)") +
      theme_minimal() +
      scale_y_continuous(
        labels = function(x) format(x, big.mark = ".", scientific = FALSE),
        limits = c(0, max(datos$monto_total) * 1.1)
      ) +
      scale_x_date(date_breaks = "1 month", date_labels = "%b %Y")
    
  }, height = function() { session$clientData$output_grafico_balance_width * 0.5 })
  
  # --- PESTAÑA RESUMEN: TRABAJADORES ---
  # Lista de trabajadores con activo = true
  output$trabajadores <- renderTable({
    dbGetQuery(con, "SELECT nombre, cargo FROM trabajadores WHERE activo = true")
  })
  
  # --- PESTAÑA GASTOS: FILTROS ---
  # Carga los departamentos reales al selector al iniciar la app
  observe({
    deptos <- dbGetQuery(con, "SELECT numero_departamento FROM departamentos ORDER BY numero_departamento")
    updateSelectInput(session, "filtro_depto", choices = c("Todos", deptos$numero_departamento))
  })
  
  # Tabla de gastos comunes con filtros dinámicos
  # La consulta SQL se construye según los filtros seleccionados
  output$gastos_comunes <- renderTable({
    
    query <- "SELECT numero_departamento AS departamento, monto, 
              TO_CHAR(fecha_emision,'DD-MM-YYYY') AS emision, 
              TO_CHAR(fecha_pago, 'DD-MM-YYYY') AS pago 
              FROM gastos_comunes 
              INNER JOIN departamentos ON departamentos.id_departamento = gastos_comunes.id_departamento"
    
    # Filtro por departamento y fecha
    if (input$filtro_depto != "Todos") {
      query <- paste(query, "WHERE numero_departamento =", paste0("'", input$filtro_depto, "'"),
                     "AND fecha_emision <=", paste0("'", input$filtro_fecha, "'"))
    } else {
      query <- paste(query, "WHERE fecha_emision <=", paste0("'", input$filtro_fecha, "'"))
    }
    
    # Filtro por estado de pago
    if (input$filtro_estado == "Pagados") {
      query <- paste(query, "AND fecha_pago IS NOT NULL")
    } else if (input$filtro_estado == "Pendientes") {
      query <- paste(query, "AND fecha_pago IS NULL")
    }
    
    query <- paste(query, "ORDER BY departamento ASC LIMIT 12")
    dbGetQuery(con, query)
  })
  
  # --- PESTAÑA MANTENCIÓN ---
  
  # Trabajos pendientes desde la VIEW trabajos_faltante
  output$trabajos_pendientes <- renderTable({
    dbGetQuery(con, "SELECT * FROM trabajos_faltante")
  })
  
  # Buscador de trabajos: filtra por descripción o tipo (Emergencia/Programada)
  # Solo muestra resultados cuando hay texto en el buscador
  output$trabajos_realizados <- renderTable({
    req(nchar(input$buscar_trabajo) > 0)
    dbGetQuery(con, paste0(
      "SELECT nombre AS empresa, servicio_prestado, CAST(mantencion AS TEXT) AS tipo, 
       TO_CHAR(fecha_trabajo, 'DD-MM-YYYY') AS fecha
       FROM mantencion 
       INNER JOIN empresas ON empresas.id_empresa = mantencion.id_empresa
       WHERE LOWER(servicio_prestado) LIKE LOWER('%", input$buscar_trabajo, "%')
       OR LOWER(CAST(mantencion AS TEXT)) LIKE LOWER('%", input$buscar_trabajo, "%')"
    ))
  })
  
  # --- PESTAÑA ENCOMIENDAS ---
  
  # Encomiendas no entregadas con alerta visual por días guardado
  # Color: blanco < 3 días | naranja 3-7 días | rojo > 7 días
  output$encomiendas_pendientes <- renderDT({
    datos <- dbGetQuery(con, "SELECT e.empresa_despacho AS Empresa, d.numero_departamento AS departamento, 
                              h.estado, TO_CHAR(h.fecha_hora, 'DD-MM-YYYY') AS fecha,
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
  
  # Buscador de historial de encomiendas por depto o empresa
  # Solo muestra resultados cuando hay texto en el buscador
  output$historial_encomiendas <- renderDT({
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

# --- INICIAR APLICACIÓN ---
shinyApp(ui = ui, server = server)