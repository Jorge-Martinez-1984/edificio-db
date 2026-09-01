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
library(shinyauthr)
library(shinyjs)

# --- CONEXIÓN BASE DE DATOS ---
# Conexión local a PostgreSQL. En producción usar variables de entorno para la contraseña.
con <- dbConnect(RPostgres::Postgres(),
                 dbname = "edificio_db",
                 host = "localhost",
                 port = 5432,
                 user = "postgres",
                 password = "texto232"
)

# --- USUARIOS Y ROLES ---
usuarios <- data.frame(
  user = c("conserje", "admin", "comite"),
  password = c("conserje123", "admin123", "comite123"),
  password_hash = sapply(c("conserje123", "admin123", "comite123"), sodium::password_store),
  rol = c("conserje", "admin", "comite"),
  stringsAsFactors = FALSE
)

# ============================================
# INTERFAZ DE USUARIO (UI)
# Define la estructura visual del dashboard
# ============================================
ui <- dashboardPage(
  dashboardHeader(
    title = "Gestión Edificio",
    tags$li(class = "dropdown", shinyauthr::logoutUI("logout")),
    # En la UI, en el header
    tags$li(class = "dropdown",
            actionButton("logout_btn", "Cerrar Sesión", 
                         style = "margin-top: 8px; margin-right: 10px;")
    ) 
   ),
  dashboardSidebar(
    uiOutput("menu_sidebar")
  ),
  dashboardBody(
    useShinyjs(),
    tags$style(HTML("
      .login-box { background-color: #fff; color: #333; }
      .login-box input { color: #333; background-color: #fff; }
    ")),
    shinyauthr::loginUI("login", title = "Bienvenido a Gestión Edificio"),
    uiOutput("contenido")
  )
)

# ============================================
# SERVIDOR (SERVER)
# Define la lógica y consultas de cada output
# ============================================
server <- function(input, output, session) {
  
  credentials <- shinyauthr::loginServer(
    id = "login",
    data = usuarios,
    user_col = user,
    pwd_col = password_hash,
    sodium_hashed = TRUE
  )
  
  # Menú sidebar según rol
  output$menu_sidebar <- renderUI({
    req(credentials()$user_auth)
    rol <- credentials()$info$rol
    
    if (rol == "conserje") {
      sidebarMenu(
        menuItem("Encomiendas", tabName = "encomiendas", icon = icon("box")),
        menuItem("Mantención",  tabName = "mantencion",  icon = icon("wrench"))
      )
    } else {
      sidebarMenu(
        menuItem("Resumen",        tabName = "resumen",     icon = icon("home")),
        menuItem("Gastos Comunes", tabName = "gastos",      icon = icon("dollar-sign")),
        menuItem("Mantención",     tabName = "mantencion",  icon = icon("wrench")),
        menuItem("Encomiendas",    tabName = "encomiendas", icon = icon("box"))
      )
    }
  })
  
  # Contenido según rol
  output$contenido <- renderUI({
    req(credentials()$user_auth)
    tabItems(
      tabItem(tabName = "resumen",     uiOutput("resumen_ui")),
      tabItem(tabName = "gastos",      uiOutput("gastos_ui")),
      tabItem(tabName = "mantencion",  uiOutput("mantencion_ui")),
      tabItem(tabName = "encomiendas", uiOutput("encomiendas_ui"))
    )
  }) 
  
  output$resumen_ui <- renderUI({
    tagList(
      h2("Resumen General"),
      fluidRow(
        valueBoxOutput("total_ingresos"),
        valueBoxOutput("total_egresos"),
        valueBoxOutput("fondo_reserva")
      ),
      fluidRow(
        column(8, box(width = 12, title = "Ingresos y Egresos",
                      plotOutput("grafico_balance", height = "300px"))),
        column(4, box(width = 12, title = "Trabajadores Activos",
                      tableOutput("trabajadores")))
      )
    )
  })
  output$gastos_ui <- renderUI({
    tagList(
      h2("Gastos Comunes"),
      fluidRow(
        column(4, selectInput("filtro_depto", "Departamento:", choices = c("Todos"))),
        column(4, dateInput("filtro_fecha", "Mes:", value = Sys.Date())),
        column(4, selectInput("filtro_estado", "Estado:", choices = c("Todos", "Pagados", "Pendientes")))
      ),
      fluidRow(box(width = 12, tableOutput("gastos_comunes")))
    )
  })
  
  output$mantencion_ui <- renderUI({
    tagList(
      h2("Mantención"),
      fluidRow(box(width = 12, title = "Buscar Trabajos Realizados",
                   textInput("buscar_trabajo", "Buscar por descripción:"),
                   tableOutput("trabajos_realizados")
      )),
      fluidRow(box(width = 12, title = "Trabajos Pendientes",
                   tableOutput("trabajos_pendientes")))
    )
  })
  
  output$encomiendas_ui <- renderUI({
    tagList(
      h2("Encomiendas"),
      fluidRow(box(width = 12, title = "Buscar Historial",
                   textInput("buscar_encomienda", "Buscar por departamento o empresa:"),
                   DTOutput("historial_encomiendas")
      )),
      fluidRow(box(width = 12, title = "Encomiendas Pendientes",
                   DTOutput("encomiendas_pendientes")))
    )
  })
  
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
  observeEvent(input$logout_btn, {
    session$reload()
  })
  
}

# --- INICIAR APLICACIÓN ---
shinyApp(ui = ui, server = server)