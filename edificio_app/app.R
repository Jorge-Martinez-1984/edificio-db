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
library(scales)
library(DT)
library(shinyauthr)
library(shinyjs)
library(sodium)

# --- CONEXIÓN BASE DE DATOS ---
# Conexión local a PostgreSQL.
# En producción usar variables de entorno para la contraseña.
con <- dbConnect(RPostgres::Postgres(),
                 dbname   = "edificio_db",
                 host     = "localhost",
                 port     = 5432,
                 user     = "postgres",
                 password = "texto232"
)

# --- USUARIOS Y ROLES ---
# Se cargan desde la tabla USUARIOS en PostgreSQL.
# Solo usuarios con activo = true pueden iniciar sesión.
usuarios <- dbGetQuery(con,
                       "SELECT username AS user, password_hash, rol, id_trabajador
   FROM usuarios WHERE activo = true")

# ============================================
# INTERFAZ DE USUARIO (UI)
# ============================================
ui <- dashboardPage(
  
  dashboardHeader(
    title = "Gestión Edificio",
    tags$li(class = "dropdown",
            actionButton("logout_btn", "Cerrar Sesión",
                         style = "margin-top: 8px; margin-right: 10px;")
    )
  ),
  
  dashboardSidebar(
    id = "tabs",
    uiOutput("menu_sidebar")
  ),
  
  dashboardBody(
    useShinyjs(),
    tags$style(HTML("
      .login-box { background-color: #fff; color: #333; }
      .login-box input { color: #333; background-color: #fff; }
      .nav-tabs li:nth-child(1) a { background-color: #5cb85c; color: white; }
      .nav-tabs li:nth-child(2) a { background-color: #d9534f; color: white; }
      .nav-tabs li:nth-child(3) a { background-color: #337ab7; color: white; }
      .nav-tabs li.active a { font-size: 16px; font-weight: bold; }
    ")),
    shinyauthr::loginUI("login", title = "Bienvenido a Gestión Edificio"),
    uiOutput("contenido")
  )
)

# ============================================
# SERVIDOR (SERVER)
# ============================================
server <- function(input, output, session) {
  
  # ==========================================
  # AUTENTICACIÓN
  # ==========================================
  credentials <- shinyauthr::loginServer(
    id            = "login",
    data          = usuarios,
    user_col      = user,
    pwd_col       = password_hash,
    sodium_hashed = TRUE
  )
  
  # Redirige a la pestaña inicial según rol
  observe({
    req(credentials()$user_auth)
    if (credentials()$info$rol == "conserje") {
      updateTabItems(session, "tabs", "registro")
    } else {
      updateTabItems(session, "tabs", "resumen")
    }
  })
  
  # Cierra sesión
  observeEvent(input$logout_btn, { session$reload() })
  
  # ==========================================
  # MENÚ LATERAL Y CONTENIDO SEGÚN ROL
  # ==========================================
  output$menu_sidebar <- renderUI({
    req(credentials()$user_auth)
    rol <- credentials()$info$rol
    if (rol == "conserje") {
      sidebarMenu(id = "tabs",
                  menuItem("Registro",       tabName = "registro",       icon = icon("book")),
                  menuItem("Encomiendas",    tabName = "encomiendas",    icon = icon("box")),
                  menuItem("Mantención",     tabName = "mantencion",     icon = icon("wrench")),
                  menuItem("Departamentos",  tabName = "departamentos",  icon = icon("building"))
      )
    } else {
      sidebarMenu(id = "tabs",
                  menuItem("Resumen",        tabName = "resumen",        icon = icon("home")),
                  menuItem("Finanzas",       tabName = "finanzas",       icon = icon("chart-line")),
                  menuItem("Gastos Comunes", tabName = "gastos",         icon = icon("dollar-sign")),
                  menuItem("Mantención",     tabName = "mantencion",     icon = icon("wrench")),
                  menuItem("Encomiendas",    tabName = "encomiendas",    icon = icon("box")),
                  menuItem("Registro",       tabName = "registro",       icon = icon("book")),
                  menuItem("Usuarios",       tabName = "usuarios",       icon = icon("users")),
                  menuItem("Departamentos",  tabName = "departamentos",  icon = icon("building"))
      )
    }
  })
  
  output$contenido <- renderUI({
    req(credentials()$user_auth)
    tabItems(
      tabItem(tabName = "resumen",       uiOutput("resumen_ui")),
      tabItem(tabName = "finanzas",      uiOutput("finanzas_ui")),
      tabItem(tabName = "gastos",        uiOutput("gastos_ui")),
      tabItem(tabName = "mantencion",    uiOutput("mantencion_ui")),
      tabItem(tabName = "encomiendas",   uiOutput("encomiendas_ui")),
      tabItem(tabName = "registro",      uiOutput("registro_ui")),
      tabItem(tabName = "usuarios",      uiOutput("usuarios_ui")),
      tabItem(tabName = "departamentos", uiOutput("departamentos_ui"))
    )
  })
  
  # ==========================================
  # PESTAÑA: RESUMEN
  # ==========================================
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
  
  output$total_ingresos <- renderValueBox({
    r <- dbGetQuery(con, "SELECT SUM(monto) AS total FROM ingresos")
    valueBox(paste("$", prettyNum(r$total, big.mark = ".", scientific = FALSE)),
             "Total Ingresos", icon = icon("arrow-up"), color = "green")
  })
  
  output$total_egresos <- renderValueBox({
    r <- dbGetQuery(con, "SELECT SUM(monto) AS total FROM egresos")
    valueBox(paste("$", prettyNum(r$total, big.mark = ".", scientific = FALSE)),
             "Total Egresos", icon = icon("arrow-down"), color = "red")
  })
  
  output$fondo_reserva <- renderValueBox({
    r <- dbGetQuery(con, "SELECT total FROM vista_balance_real")
    valueBox(paste("$", prettyNum(r$total, big.mark = ".", scientific = FALSE)),
             "Fondo de Reserva", icon = icon("piggy-bank"), color = "blue")
  })
  
  output$grafico_balance <- renderPlot({
    ingresos <- dbGetQuery(con,
                           "SELECT 'Ingresos' AS tipo, DATE_TRUNC('month', fecha) AS mes,
       SUM(monto)::integer AS monto_total
       FROM ingresos GROUP BY mes ORDER BY mes ASC LIMIT 12")
    egresos <- dbGetQuery(con,
                          "SELECT 'Egresos' AS tipo, DATE_TRUNC('month', fecha) AS mes,
       SUM(monto)::integer AS monto_total
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
  
  output$trabajadores <- renderTable({
    input$guardar_trabajador
    input$despedir_trabajador
    dbGetQuery(con,
               "SELECT t.nombre, t.cargo,
       TO_CHAR(tc.sueldo, 'FM999G999G999') AS sueldo_base
       FROM trabajadores t
       INNER JOIN trabajadores_confidencial tc ON tc.id_trabajador = t.id_trabajador
       WHERE t.activo = true")
  })
  
  # ==========================================
  # PESTAÑA: FINANZAS
  # ==========================================
  output$finanzas_ui <- renderUI({
    tagList(
      h2("Finanzas"),
      tabsetPanel(
        tabPanel("Ingresos",
                 fluidRow(
                   box(width = 4, title = "Registrar Ingreso",
                       selectInput("ing_tipo",  "Tipo:",          choices = c()),
                       selectInput("ing_depto", "Departamento:",  choices = c("N/A")),
                       numericInput("ing_monto","Monto ($):",     value = 0, min = 0),
                       dateInput("ing_fecha",   "Fecha:",         value = Sys.Date()),
                       actionButton("guardar_ingreso", "Registrar", class = "btn-primary")
                   ),
                   box(width = 8, title = "Historial de Ingresos",
                       selectInput("filtro_periodo_ing", "Período:",
                                   choices = c("Mes actual", "Semestre", "Año")),
                       tableOutput("tabla_ingresos")
                   )
                 )
        ),
        tabPanel("Egresos",
                 fluidRow(
                   box(width = 4, title = "Registrar Egreso",
                       selectInput("eg_tipo",  "Tipo:",   choices = c()),
                       numericInput("eg_monto","Monto ($):", value = 0, min = 0),
                       dateInput("eg_fecha",   "Fecha:",  value = Sys.Date()),
                       actionButton("guardar_egreso", "Registrar", class = "btn-primary")
                   ),
                   box(width = 8, title = "Historial de Egresos",
                       selectInput("filtro_periodo_eg", "Período:",
                                   choices = c("Mes actual", "Semestre", "Año")),
                       tableOutput("tabla_egresos")
                   )
                 )
        ),
        tabPanel("Sueldos",
                 fluidRow(
                   box(width = 4, title = "Registrar Sueldo",
                       selectInput("sueldo_trabajador", "Trabajador:", choices = c()),
                       numericInput("sueldo_monto", "Monto bruto ($):", value = 0, min = 0),
                       selectInput("sueldo_periodo", "Período pagado:",
                                   choices = c("Enero","Febrero","Marzo","Abril","Mayo","Junio",
                                               "Julio","Agosto","Septiembre","Octubre","Noviembre","Diciembre")),
                       numericInput("sueldo_anio", "Año:",
                                    value = as.numeric(format(Sys.Date(), "%Y")), min = 2020),
                       actionButton("guardar_sueldo", "Registrar", class = "btn-primary")
                   ),
                   box(width = 8, title = "Historial de Sueldos",
                       tableOutput("tabla_sueldos")
                   )
                 )
        )
      )
    )
  })
  
  # Carga selectores de Finanzas
  observe({
    req(credentials()$info$rol == "admin")
    req(!is.null(input$ing_tipo))
    tipos_ing <- dbGetQuery(con, "SELECT id_tipo_ingreso, nombre FROM tipo_ingreso ORDER BY nombre")
    updateSelectInput(session, "ing_tipo",
                      choices = setNames(tipos_ing$id_tipo_ingreso, tipos_ing$nombre))
    deptos <- dbGetQuery(con, "SELECT id_departamento, numero_departamento FROM departamentos ORDER BY numero_departamento")
    updateSelectInput(session, "ing_depto",
                      choices = c("N/A" = 0, setNames(deptos$id_departamento, deptos$numero_departamento)))
    tipos_eg <- dbGetQuery(con, "SELECT id_tipo_egreso, nombre FROM tipo_egreso WHERE nombre != 'Sueldo' ORDER BY nombre")
    updateSelectInput(session, "eg_tipo",
                      choices = setNames(tipos_eg$id_tipo_egreso, tipos_eg$nombre))
  })
  
  observe({
    req(credentials()$info$rol == "admin")
    req(!is.null(input$sueldo_trabajador))
    trabajadores <- dbGetQuery(con, "SELECT id_trabajador, nombre FROM trabajadores WHERE activo = true")
    updateSelectInput(session, "sueldo_trabajador",
                      choices = setNames(trabajadores$id_trabajador, trabajadores$nombre))
  })
  
  output$tabla_ingresos <- renderTable({
    input$guardar_ingreso
    periodo <- input$filtro_periodo_ing
    filtro <- switch(periodo,
                     "Mes actual" = "AND DATE_TRUNC('month', fecha) = DATE_TRUNC('month', CURRENT_DATE)",
                     "Semestre"   = "AND fecha >= CURRENT_DATE - INTERVAL '6 months'",
                     "AND fecha >= CURRENT_DATE - INTERVAL '1 year'")
    dbGetQuery(con, paste0(
      "SELECT ti.nombre AS tipo, d.numero_departamento AS departamento,
       TO_CHAR(i.monto, 'FM999G999G999') AS monto,
       TO_CHAR(i.fecha, 'DD-MM-YYYY') AS fecha
       FROM ingresos i
       INNER JOIN tipo_ingreso ti ON ti.id_tipo_ingreso = i.id_tipo_ingreso
       LEFT JOIN departamentos d ON d.id_departamento = i.id_departamento
       WHERE 1=1 ", filtro, " ORDER BY i.fecha DESC"))
  })
  
  output$tabla_egresos <- renderTable({
    input$guardar_egreso
    input$guardar_sueldo
    periodo <- input$filtro_periodo_eg
    filtro <- switch(periodo,
                     "Mes actual" = "AND DATE_TRUNC('month', fecha) = DATE_TRUNC('month', CURRENT_DATE)",
                     "Semestre"   = "AND fecha >= CURRENT_DATE - INTERVAL '6 months'",
                     "AND fecha >= CURRENT_DATE - INTERVAL '1 year'")
    dbGetQuery(con, paste0(
      "SELECT te.nombre AS tipo,
       TO_CHAR(DATE_TRUNC('month', e.fecha), 'MM-YYYY') AS periodo,
       TO_CHAR(SUM(e.monto), 'FM999G999G999') AS monto
       FROM egresos e
       INNER JOIN tipo_egreso te ON te.id_tipo_egreso = e.id_tipo_egreso
       WHERE 1=1 ", filtro, "
       GROUP BY te.nombre, DATE_TRUNC('month', e.fecha)
       ORDER BY DATE_TRUNC('month', e.fecha) DESC, SUM(e.monto) DESC"))
  })
  
  output$tabla_sueldos <- renderTable({
    input$guardar_sueldo
    dbGetQuery(con,
               "SELECT t.nombre AS trabajador,
       TO_CHAR(e.monto, 'FM999G999G999') AS sueldo,
       TO_CHAR(e.fecha, 'MM-YYYY') AS periodo
       FROM egresos e
       INNER JOIN tipo_egreso te ON te.id_tipo_egreso = e.id_tipo_egreso
       INNER JOIN trabajadores t ON t.id_trabajador = e.id_trabajador
       WHERE te.nombre = 'Sueldo'
       ORDER BY e.fecha DESC LIMIT 20")
  })
  
  observeEvent(input$guardar_ingreso, {
    req(input$ing_monto > 0)
    id_depto <- if (input$ing_depto == 0) "NULL" else input$ing_depto
    dbExecute(con, paste0(
      "INSERT INTO INGRESOS (id_tipo_ingreso, id_departamento, monto, fecha) VALUES (",
      input$ing_tipo, ", ", id_depto, ", ", input$ing_monto, ", '", input$ing_fecha, "')"))
    showNotification("Ingreso registrado exitosamente", type = "message")
  })
  
  observeEvent(input$guardar_egreso, {
    req(input$eg_monto > 0)
    dbExecute(con, paste0(
      "INSERT INTO EGRESOS (id_tipo_egreso, monto, fecha) VALUES (",
      input$eg_tipo, ", ", input$eg_monto, ", '", input$eg_fecha, "')"))
    showNotification("Egreso registrado exitosamente", type = "message")
  })
  
  observeEvent(input$guardar_sueldo, {
    req(input$sueldo_monto > 0)
    fecha_pago <- paste0(input$sueldo_anio, "-",
                         match(input$sueldo_periodo,
                               c("Enero","Febrero","Marzo","Abril","Mayo","Junio",
                                 "Julio","Agosto","Septiembre","Octubre","Noviembre","Diciembre")),
                         "-01")
    id_sueldo <- dbGetQuery(con,
                            "SELECT id_tipo_egreso FROM tipo_egreso WHERE nombre = 'Sueldo'")$id_tipo_egreso
    dbExecute(con, paste0(
      "INSERT INTO EGRESOS (id_tipo_egreso, monto, fecha, id_trabajador) VALUES (",
      id_sueldo, ", ", input$sueldo_monto, ", '", fecha_pago, "', ", input$sueldo_trabajador, ")"))
    showNotification("Sueldo registrado exitosamente", type = "message")
  })
  
  # ==========================================
  # PESTAÑA: GASTOS COMUNES
  # ==========================================
  output$gastos_ui <- renderUI({
    tagList(
      h2("Gastos Comunes"),
      fluidRow(
        column(4, selectInput("filtro_depto",  "Departamento:", choices = c("Todos"))),
        column(4, dateInput("filtro_fecha",    "Mes:",          value = Sys.Date())),
        column(4, selectInput("filtro_estado", "Estado:",
                              choices = c("Todos", "Pagados", "Pendientes")))
      ),
      fluidRow(box(width = 12, tableOutput("gastos_comunes")))
    )
  })
  
  observe({
    req(credentials()$user_auth)
    req(!is.null(input$filtro_depto))
    deptos <- dbGetQuery(con, "SELECT numero_departamento FROM departamentos ORDER BY numero_departamento")
    updateSelectInput(session, "filtro_depto", choices = c("Todos", deptos$numero_departamento))
  })
  
  output$gastos_comunes <- renderTable({
    query <- "SELECT numero_departamento AS departamento, monto,
              TO_CHAR(fecha_emision,'DD-MM-YYYY') AS emision,
              TO_CHAR(fecha_pago, 'DD-MM-YYYY') AS pago
              FROM gastos_comunes
              INNER JOIN departamentos ON departamentos.id_departamento = gastos_comunes.id_departamento"
    if (input$filtro_depto != "Todos") {
      query <- paste(query, "WHERE numero_departamento =", paste0("'", input$filtro_depto, "'"),
                     "AND fecha_emision <=", paste0("'", input$filtro_fecha, "'"))
    } else {
      query <- paste(query, "WHERE fecha_emision <=", paste0("'", input$filtro_fecha, "'"))
    }
    if (input$filtro_estado == "Pagados") {
      query <- paste(query, "AND fecha_pago IS NOT NULL")
    } else if (input$filtro_estado == "Pendientes") {
      query <- paste(query, "AND fecha_pago IS NULL")
    }
    dbGetQuery(con, paste(query, "ORDER BY departamento ASC LIMIT 12"))
  })
  
  # ==========================================
  # PESTAÑA: MANTENCIÓN
  # ==========================================
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
  
  output$trabajos_pendientes <- renderTable({
    dbGetQuery(con, "SELECT * FROM trabajos_faltante")
  })
  
  output$trabajos_realizados <- renderTable({
    req(nchar(input$buscar_trabajo) > 0)
    dbGetQuery(con, paste0(
      "SELECT nombre AS empresa, servicio_prestado,
       CAST(mantencion AS TEXT) AS tipo,
       TO_CHAR(fecha_trabajo, 'DD-MM-YYYY') AS fecha,
       TO_CHAR(f.costo, 'FM999G999G999') AS monto
       FROM mantencion
       INNER JOIN empresas ON empresas.id_empresa = mantencion.id_empresa
       LEFT JOIN factura_mantencion f ON f.id_mantencion = mantencion.id_mantencion
       WHERE LOWER(servicio_prestado) LIKE LOWER('%", input$buscar_trabajo, "%')
       OR LOWER(CAST(mantencion AS TEXT)) LIKE LOWER('%", input$buscar_trabajo, "%')"))
  })
  
  # ==========================================
  # PESTAÑA: ENCOMIENDAS
  # ==========================================
  output$encomiendas_ui <- renderUI({
    tagList(
      h2("Encomiendas"),
      fluidRow(box(width = 12, title = "Buscar Historial",
                   textInput("buscar_encomienda", "Buscar por departamento o empresa:"),
                   DTOutput("historial_encomiendas")
      )),
      fluidRow(box(width = 12, title = "Registrar Encomienda",
                   selectInput("enc_depto",   "Departamento:",     choices = c()),
                   textInput("enc_empresa",   "Empresa de despacho:"),
                   actionButton("guardar_encomienda", "Registrar", class = "btn-primary")
      )),
      fluidRow(box(width = 12, title = "Actualizar Estado",
                   selectInput("enc_id",          "Encomienda:",   choices = c()),
                   selectInput("enc_estado_nuevo", "Nuevo estado:",
                               choices = c("En Bodega", "Entregado")),
                   actionButton("actualizar_enc", "Actualizar", class = "btn-warning")
      )),
      fluidRow(box(width = 12, title = "Encomiendas Pendientes",
                   DTOutput("encomiendas_pendientes")))
    )
  })
  
  observe({
    req(credentials()$user_auth)
    input$guardar_encomienda
    deptos <- dbGetQuery(con,
                         "SELECT id_departamento, numero_departamento FROM departamentos ORDER BY numero_departamento")
    updateSelectInput(session, "enc_depto",
                      choices = setNames(deptos$id_departamento, deptos$numero_departamento))
  })
  
  observe({
    req(credentials()$user_auth)
    req(!is.null(input$enc_id))
    input$actualizar_enc
    input$guardar_encomienda
    enc <- dbGetQuery(con,
                      "SELECT h.id_encomienda,
       e.empresa_despacho || ' - Depto ' || d.numero_departamento AS descripcion
       FROM historial_encomienda h
       INNER JOIN encomienda e ON e.id_encomienda = h.id_encomienda
       INNER JOIN departamentos d ON d.id_departamento = e.id_departamento
       WHERE h.estado != 'Entregado'
       GROUP BY h.id_encomienda, e.empresa_despacho, d.numero_departamento")
    updateSelectInput(session, "enc_id",
                      choices = setNames(enc$id_encomienda, enc$descripcion))
  })
  
  observeEvent(input$guardar_encomienda, {
    req(input$enc_empresa)
    id_trabajador <- credentials()$info$id_trabajador
    dbExecute(con, paste0(
      "INSERT INTO ENCOMIENDA (id_departamento, empresa_despacho) VALUES (",
      input$enc_depto, ", '", input$enc_empresa, "')"))
    id_enc <- dbGetQuery(con, "SELECT MAX(id_encomienda) AS id FROM encomienda")$id
    dbExecute(con, paste0(
      "INSERT INTO HISTORIAL_ENCOMIENDA (id_encomienda, id_trabajador, estado, fecha_hora) VALUES (",
      id_enc, ", ", id_trabajador, ", 'Recibido', NOW())"))
    showNotification("Encomienda registrada exitosamente", type = "message")
  })
  
  observeEvent(input$actualizar_enc, {
    req(input$enc_id)
    id_trabajador <- credentials()$info$id_trabajador
    dbExecute(con, paste0(
      "INSERT INTO HISTORIAL_ENCOMIENDA (id_encomienda, id_trabajador, estado, fecha_hora) VALUES (",
      input$enc_id, ", ", id_trabajador, ", '", input$enc_estado_nuevo, "', NOW())"))
    showNotification("Estado actualizado exitosamente", type = "message")
  })
  
  output$encomiendas_pendientes <- renderDT({
    input$guardar_encomienda
    input$actualizar_enc
    datos <- dbGetQuery(con,
                        "SELECT e.empresa_despacho AS Empresa, d.numero_departamento AS departamento,
       h.estado, TO_CHAR(h.fecha_hora, 'DD-MM-YYYY') AS fecha,
       CURRENT_DATE - h.fecha_hora::date AS dias_guardado
       FROM historial_encomienda h
       INNER JOIN encomienda e ON e.id_encomienda = h.id_encomienda
       INNER JOIN departamentos d ON d.id_departamento = e.id_departamento
       WHERE h.estado != 'Entregado'")
    datatable(datos, options = list(searching = FALSE)) %>%
      formatStyle('dias_guardado',
                  backgroundColor = styleInterval(c(3, 7), c('white', 'orange', 'red')),
                  color           = styleInterval(c(3, 7), c('black', 'black', 'white')))
  })
  
  output$historial_encomiendas <- renderDT({
    req(nchar(input$buscar_encomienda) > 0)
    dbGetQuery(con, paste0(
      "SELECT e.empresa_despacho,
       d.numero_departamento AS depto,
       MAX(CASE WHEN h.estado = 'Recibido' THEN t.nombre END) AS recibe,
       TO_CHAR(MAX(CASE WHEN h.estado = 'Recibido' THEN h.fecha_hora END), 'DD-MM-YYYY') AS fecha_recepcion,
       TO_CHAR(MAX(CASE WHEN h.estado = 'En Bodega' THEN h.fecha_hora END), 'DD-MM-YYYY') AS fecha_bodega,
       MAX(CASE WHEN h.estado = 'Entregado' THEN t.nombre END) AS entrega,
       TO_CHAR(MAX(CASE WHEN h.estado = 'Entregado' THEN h.fecha_hora END), 'DD-MM-YYYY') AS fecha_entrega
       FROM historial_encomienda h
       INNER JOIN encomienda e ON e.id_encomienda = h.id_encomienda
       INNER JOIN departamentos d ON d.id_departamento = e.id_departamento
       INNER JOIN trabajadores t ON t.id_trabajador = h.id_trabajador
       WHERE LOWER(d.numero_departamento) LIKE LOWER('%", input$buscar_encomienda, "%')
       OR LOWER(e.empresa_despacho) LIKE LOWER('%", input$buscar_encomienda, "%')
       GROUP BY e.empresa_despacho, d.numero_departamento"))
  })
  
  # ==========================================
  # PESTAÑA: REGISTRO DE TURNO
  # ==========================================
  output$registro_ui <- renderUI({
    tagList(
      h2("Registro de Turno"),
      fluidRow(box(width = 12, title = "Nueva Novedad",
                   textAreaInput("novedad_texto", "Descripción:", rows = 4, width = "100%"),
                   actionButton("guardar_novedad", "Guardar", class = "btn-primary")
      )),
      fluidRow(box(width = 12, title = "Novedades Registradas",
                   tableOutput("tabla_novedades")))
    )
  })
  
  observeEvent(input$guardar_novedad, {
    req(input$novedad_texto)
    id_trabajador <- credentials()$info$id_trabajador
    dbExecute(con, paste0(
      "INSERT INTO REGISTRO (ID_trabajador, registro, fecha) VALUES (",
      id_trabajador, ", '", input$novedad_texto, "', NOW())"))
    showNotification("Novedad guardada exitosamente", type = "message")
  })
  
  output$tabla_novedades <- renderTable({
    input$guardar_novedad
    dbGetQuery(con,
               "SELECT r.registro, TO_CHAR(r.fecha, 'DD-MM-YYYY HH24:MI') AS fecha,
       t.nombre AS trabajador
       FROM registro r
       INNER JOIN trabajadores t ON t.id_trabajador = r.id_trabajador
       ORDER BY r.fecha DESC LIMIT 20")
  })
  
  # ==========================================
  # PESTAÑA: USUARIOS Y TRABAJADORES
  # ==========================================
  output$usuarios_ui <- renderUI({
    req(credentials()$info$rol == "admin")
    tagList(
      h2("Administración"),
      tabsetPanel(
        tabPanel("Usuarios",
                 fluidRow(
                   box(width = 6, title = "Nuevo Usuario",
                       textInput("nuevo_username", "Usuario:"),
                       textInput("nuevo_password", "Contraseña:"),
                       selectInput("nuevo_rol", "Rol:", choices = c("conserje", "admin", "comite")),
                       conditionalPanel(
                         condition = "input.nuevo_rol == 'conserje'",
                         selectInput("nuevo_trabajador", "Trabajador:", choices = c())
                       ),
                       actionButton("guardar_usuario", "Crear Usuario", class = "btn-primary")
                   ),
                   box(width = 6, title = "Usuarios Registrados",
                       tableOutput("tabla_usuarios")
                   ),
                   box(width = 12, title = "Desactivar Usuario",
                       selectInput("usuario_desactivar", "Seleccionar usuario:", choices = c()),
                       actionButton("desactivar_usuario", "Desactivar", class = "btn-danger")
                   )
                 )
        ),
        tabPanel("Trabajadores",
                 fluidRow(
                   box(width = 6, title = "Nuevo Trabajador",
                       textInput("trab_nombre",   "Nombre:"),
                       textInput("trab_apellido", "Apellido:"),
                       textInput("trab_cargo",    "Cargo:"),
                       textInput("trab_celular",  "Celular:"),
                       textInput("trab_rut",      "RUT:"),
                       textInput("trab_email",    "Email:"),
                       textInput("trab_direccion","Dirección:"),
                       numericInput("trab_sueldo","Sueldo base ($):", value = 0, min = 0),
                       dateInput("trab_fecha_contrato", "Fecha contratación:", value = Sys.Date()),
                       actionButton("guardar_trabajador", "Contratar", class = "btn-success")
                   ),
                   box(width = 6, title = "Trabajadores Activos",
                       tableOutput("tabla_trabajadores"),
                       hr(),
                       selectInput("trab_despedir", "Despedir trabajador:", choices = c()),
                       actionButton("despedir_trabajador", "Despedir", class = "btn-danger")
                   )
                 )
        )
      )
    )
  })
  
  # Selectores de Usuarios
  observe({
    req(credentials()$info$rol == "admin")
    req(!is.null(input$nuevo_trabajador))
    input$guardar_usuario
    trabajadores <- dbGetQuery(con,
                               "SELECT id_trabajador, nombre FROM trabajadores WHERE activo = true")
    updateSelectInput(session, "nuevo_trabajador",
                      choices = setNames(trabajadores$id_trabajador, trabajadores$nombre))
  })
  
  observe({
    req(credentials()$user_auth)
    req(credentials()$info$rol == "admin")
    input$guardar_usuario
    usuarios_activos <- dbGetQuery(con, "SELECT username FROM usuarios WHERE activo = true")
    updateSelectInput(session, "usuario_desactivar", choices = usuarios_activos$username)
  })
  
  output$tabla_usuarios <- renderTable({
    input$guardar_usuario
    input$desactivar_usuario
    dbGetQuery(con,
               "SELECT u.username, u.rol, t.nombre AS trabajador
       FROM usuarios u
       LEFT JOIN trabajadores t ON t.id_trabajador = u.id_trabajador
       WHERE u.activo = true")
  })
  
  observeEvent(input$guardar_usuario, {
    req(input$nuevo_username, input$nuevo_password)
    hash <- sodium::password_store(input$nuevo_password)
    dbExecute(con, paste0(
      "INSERT INTO USUARIOS (username, password_hash, rol, id_trabajador) VALUES ('",
      input$nuevo_username, "', '", hash, "', '",
      input$nuevo_rol, "', ", input$nuevo_trabajador, ")"))
    showNotification("Usuario creado exitosamente", type = "message")
  })
  
  observeEvent(input$desactivar_usuario, {
    dbExecute(con, paste0(
      "UPDATE USUARIOS SET activo = false WHERE username = '",
      input$usuario_desactivar, "'"))
    showNotification("Usuario desactivado", type = "warning")
  })
  
  # Selectores de Trabajadores
  observe({
    req(credentials()$info$rol == "admin")
    req(!is.null(input$trab_despedir))
    input$guardar_trabajador
    input$despedir_trabajador
    trabajadores <- dbGetQuery(con,
                               "SELECT id_trabajador, nombre FROM trabajadores WHERE activo = true")
    updateSelectInput(session, "trab_despedir",
                      choices = setNames(trabajadores$id_trabajador, trabajadores$nombre))
  })
  
  output$tabla_trabajadores <- renderTable({
    input$guardar_trabajador
    input$despedir_trabajador
    dbGetQuery(con, "SELECT nombre, apellido, cargo FROM trabajadores WHERE activo = true")
  })
  
  observeEvent(input$guardar_trabajador, {
    req(input$trab_nombre, input$trab_apellido, input$trab_cargo)
    dbExecute(con, paste0(
      "INSERT INTO TRABAJADORES (nombre, apellido, cargo, celular, activo) VALUES ('",
      input$trab_nombre, "', '", input$trab_apellido, "', '",
      input$trab_cargo,  "', '", input$trab_celular,  "', true)"))
    id_trab <- dbGetQuery(con, "SELECT MAX(id_trabajador) AS id FROM trabajadores")$id
    dbExecute(con, paste0(
      "INSERT INTO TRABAJADORES_CONFIDENCIAL
       (id_trabajador, sueldo, email, rut, fecha_contratacion, direccion) VALUES (",
      id_trab, ", ", input$trab_sueldo, ", '",
      input$trab_email, "', '", input$trab_rut, "', '",
      input$trab_fecha_contrato, "', '", input$trab_direccion, "')"))
    showNotification("Trabajador contratado exitosamente", type = "message")
  })
  
  observeEvent(input$despedir_trabajador, {
    req(input$trab_despedir)
    dbExecute(con, paste0(
      "UPDATE TRABAJADORES SET activo = false WHERE id_trabajador = ", input$trab_despedir))
    dbExecute(con, paste0(
      "UPDATE TRABAJADORES_CONFIDENCIAL SET fecha_desvinculacion = NOW()
       WHERE id_trabajador = ", input$trab_despedir))
    showNotification("Trabajador desvinculado", type = "warning")
  })
  
  # ==========================================
  # PESTAÑA: DEPARTAMENTOS
  # ==========================================
  output$departamentos_ui <- renderUI({
    rol <- credentials()$info$rol
    if (rol == "conserje") {
      tagList(h2("Departamentos"), tableOutput("tabla_deptos"))
    } else {
      tagList(
        h2("Departamentos"),
        tabsetPanel(
          tabPanel("Ver", tableOutput("tabla_deptos")),
          tabPanel("Registrar",
                   fluidRow(box(width = 6, title = "Nuevo Registro",
                                selectInput("dep_tipo", "Tipo:",
                                            choices = c("Propietario", "Arrendatario", "Residente")),
                                textInput("dep_nombre",   "Nombre:"),
                                textInput("dep_apellido", "Apellido:"),
                                textInput("dep_rut",      "RUT:"),
                                textInput("dep_celular",  "Celular:"),
                                textInput("dep_email",    "Email:"),
                                # Depto: para Propietario y Arrendatario
                                conditionalPanel(
                                  condition = "input.dep_tipo != 'Residente'",
                                  selectInput("dep_depto", "Departamento:", choices = c())
                                ),
                                # Estacionamiento y bodega: solo para Propietario
                                conditionalPanel(
                                  condition = "input.dep_tipo == 'Propietario'",
                                  textInput("dep_estacionamiento", "N° Estacionamiento (opcional):"),
                                  textInput("dep_bodega",          "N° Bodega (opcional):")
                                ),
                                # Fecha ingreso: solo para Arrendatario
                                conditionalPanel(
                                  condition = "input.dep_tipo == 'Arrendatario'",
                                  dateInput("dep_fecha_ingreso", "Fecha ingreso:", value = Sys.Date())
                                ),
                                # Titular: solo para Residente
                                conditionalPanel(
                                  condition = "input.dep_tipo == 'Residente'",
                                  selectInput("dep_titular", "Titular:", choices = c())
                                ),
                                actionButton("guardar_dep", "Registrar", class = "btn-primary")
                   ))
          ),
          tabPanel("Desvincular",
                   fluidRow(box(width = 6, title = "Desvincular",
                                selectInput("desv_tipo", "Tipo:", choices = c("Propietario", "Arrendatario")),
                                conditionalPanel(
                                  condition = "input.desv_tipo == 'Propietario'",
                                  selectInput("desv_propietario",  "Propietario:",  choices = c()),
                                  selectInput("desv_depto_prop",   "Departamento:", choices = c())
                                ),
                                conditionalPanel(
                                  condition = "input.desv_tipo == 'Arrendatario'",
                                  selectInput("desv_titular",      "Arrendatario:", choices = c()),
                                  dateInput("desv_fecha_salida",   "Fecha de salida:", value = Sys.Date())
                                ),
                                actionButton("desv_guardar", "Desvincular", class = "btn-danger")
                   ))
          )
        )
      )
    }
  })
  
  # Tabla principal de departamentos
  output$tabla_deptos <- renderTable({
    invalidateLater(5000, session)
    dbGetQuery(con,
               "SELECT d.numero_departamento AS depto,
       p.nombre || ' ' || p.apellido AS propietario,
       pc.celular AS contacto_propietario,
       d.estacionamiento,
       d.bodega,
       t.nombre || ' ' || t.apellido AS arrendatario,
       t.celular AS contacto_arrendatario,
       COALESCE(sub.residentes, 0) +
         CASE WHEN t.id_titular IS NOT NULL THEN 1 ELSE 0 END AS residentes
       FROM departamentos d
       LEFT JOIN historial_propietario hp
         ON hp.id_departamento = d.id_departamento AND hp.fecha_fin IS NULL
       LEFT JOIN propietarios p ON p.id_propietario = hp.id_propietario
       LEFT JOIN propietarios_confidencial pc ON pc.id_propietario = p.id_propietario
       LEFT JOIN titular t
         ON t.id_departamento = d.id_departamento AND t.fecha_salida IS NULL
       LEFT JOIN (
         SELECT id_titular, COUNT(id_residente)::integer AS residentes
         FROM residentes WHERE activo = true
         GROUP BY id_titular
       ) sub ON sub.id_titular = t.id_titular
       ORDER BY d.numero_departamento ASC")
  })
  
  # Selectores del formulario Registrar de departamentos
  observe({
    req(credentials()$info$rol == "admin")
    req(!is.null(input$dep_tipo))
    deptos <- dbGetQuery(con,
                         "SELECT id_departamento, numero_departamento FROM departamentos ORDER BY numero_departamento")
    updateSelectInput(session, "dep_depto",
                      choices = setNames(deptos$id_departamento, deptos$numero_departamento))
    titulares <- dbGetQuery(con,
                            "SELECT id_titular, nombre || ' ' || apellido AS nombre
       FROM titular WHERE fecha_salida IS NULL")
    updateSelectInput(session, "dep_titular",
                      choices = setNames(titulares$id_titular, titulares$nombre))
  })
  
  # Selectores del formulario Desvincular
  observe({
    req(credentials()$info$rol == "admin")
    req(!is.null(input$desv_tipo))
    propietarios <- dbGetQuery(con,
                               "SELECT DISTINCT p.id_propietario, p.nombre || ' ' || p.apellido AS nombre
       FROM propietarios p
       INNER JOIN historial_propietario hp ON hp.id_propietario = p.id_propietario
       WHERE hp.fecha_fin IS NULL")
    updateSelectInput(session, "desv_propietario",
                      choices = setNames(propietarios$id_propietario, propietarios$nombre))
    titulares <- dbGetQuery(con,
                            "SELECT id_titular, nombre || ' ' || apellido AS nombre
       FROM titular WHERE fecha_salida IS NULL")
    updateSelectInput(session, "desv_titular",
                      choices = setNames(titulares$id_titular, titulares$nombre))
  })
  
  observe({
    req(credentials()$info$rol == "admin")
    req(!is.null(input$desv_propietario))
    req(nchar(as.character(input$desv_propietario)) > 0)
    deptos <- dbGetQuery(con, paste0(
      "SELECT d.id_departamento, d.numero_departamento
       FROM departamentos d
       INNER JOIN historial_propietario hp ON hp.id_departamento = d.id_departamento
       WHERE hp.id_propietario = ", input$desv_propietario, " AND hp.fecha_fin IS NULL"))
    updateSelectInput(session, "desv_depto_prop",
                      choices = setNames(deptos$id_departamento, deptos$numero_departamento))
  })
  
  # Guarda nuevo registro de departamento
  observeEvent(input$guardar_dep, {
    req(input$dep_nombre, input$dep_apellido, input$dep_rut)
    
    if (input$dep_tipo == "Propietario") {
      # INSERT propietario
      dbExecute(con, paste0(
        "INSERT INTO PROPIETARIOS (nombre, apellido) VALUES ('",
        input$dep_nombre, "', '", input$dep_apellido, "')"))
      id_prop <- dbGetQuery(con,
                            "SELECT MAX(id_propietario) AS id FROM propietarios")$id
      dbExecute(con, paste0(
        "INSERT INTO PROPIETARIOS_CONFIDENCIAL (id_propietario, rut, email, celular) VALUES (",
        id_prop, ", '", input$dep_rut, "', '", input$dep_email, "', '", input$dep_celular, "')"))
      # Vincula al depto y actualiza estacionamiento/bodega si se ingresaron
      dbExecute(con, paste0(
        "INSERT INTO HISTORIAL_PROPIETARIO (id_propietario, id_departamento, fecha_inicio) VALUES (",
        id_prop, ", ", input$dep_depto, ", CURRENT_DATE)"))
      if (nchar(input$dep_estacionamiento) > 0) {
        dbExecute(con, paste0(
          "UPDATE DEPARTAMENTOS SET estacionamiento = '", input$dep_estacionamiento,
          "' WHERE id_departamento = ", input$dep_depto))
      }
      if (nchar(input$dep_bodega) > 0) {
        dbExecute(con, paste0(
          "UPDATE DEPARTAMENTOS SET bodega = '", input$dep_bodega,
          "' WHERE id_departamento = ", input$dep_depto))
      }
      
    } else if (input$dep_tipo == "Arrendatario") {
      dbExecute(con, paste0(
        "INSERT INTO TITULAR
         (id_departamento, nombre, apellido, rut, celular, email, es_arrendatario, fecha_ingreso)
         VALUES (", input$dep_depto, ", '", input$dep_nombre, "', '", input$dep_apellido, "', '",
        input$dep_rut, "', '", input$dep_celular, "', '", input$dep_email, "', true, '",
        input$dep_fecha_ingreso, "')"))
      
    } else if (input$dep_tipo == "Residente") {
      dbExecute(con, paste0(
        "INSERT INTO RESIDENTES (id_titular, nombre, apellido, rut, celular, activo) VALUES (",
        input$dep_titular, ", '", input$dep_nombre, "', '", input$dep_apellido, "', '",
        input$dep_rut, "', '", input$dep_celular, "', true)"))
    }
    showNotification("Registro guardado exitosamente", type = "message")
  })
  
  # Ejecuta la desvinculación
  observeEvent(input$desv_guardar, {
    if (input$desv_tipo == "Propietario") {
      dbExecute(con, paste0(
        "UPDATE HISTORIAL_PROPIETARIO SET fecha_fin = CURRENT_DATE
         WHERE id_departamento = ", input$desv_depto_prop,
        " AND id_propietario = ", input$desv_propietario,
        " AND fecha_fin IS NULL"))
      showNotification("Propietario desvinculado", type = "warning")
      
    } else if (input$desv_tipo == "Arrendatario") {
      dbExecute(con, paste0(
        "UPDATE TITULAR SET fecha_salida = '", input$desv_fecha_salida,
        "' WHERE id_titular = ", input$desv_titular))
      showNotification(
        "Arrendatario desvinculado — residentes desactivados automáticamente",
        type = "warning")
    }
  })
  
} # fin server

# --- INICIAR APLICACIÓN ---
shinyApp(ui = ui, server = server)
