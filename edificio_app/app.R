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
# Define la estructura visual del dashboard.
# El contenido se carga dinámicamente según el rol.
# ============================================
ui <- dashboardPage(
  
  # --- ENCABEZADO ---
  # Incluye el botón de cierre de sesión
  dashboardHeader(
    title = "Gestión Edificio",
    tags$li(class = "dropdown",
            actionButton("logout_btn", "Cerrar Sesión",
                         style = "margin-top: 8px; margin-right: 10px;")
    )
  ),
  
  # --- MENÚ LATERAL ---
  # Se renderiza dinámicamente según el rol del usuario
  dashboardSidebar(
    id = "tabs",
    uiOutput("menu_sidebar")
  ),
  
  # --- CUERPO DEL DASHBOARD ---
  # Muestra el login al inicio; el contenido se carga tras autenticarse
  dashboardBody(
    useShinyjs(),
    tags$style(HTML("
  .login-box { background-color: #fff; color: #333; }
  .login-box input { color: #333; background-color: #fff; }
  .nav-tabs li:nth-child(1) a { background-color: #5cb85c; color: white; }
  .nav-tabs li:nth-child(2) a { background-color: #d9534f; color: white; }
  .nav-tabs li.active a { font-size: 16px; font-weight: bold; }
")),
    shinyauthr::loginUI("login", title = "Bienvenido a Gestión Edificio"),
    uiOutput("contenido")
  )
)

# ============================================
# SERVIDOR (SERVER)
# Define la lógica, autenticación y consultas
# ============================================
server <- function(input, output, session) {
  
  # --- AUTENTICACIÓN ---
  # Verifica usuario y contraseña contra la tabla USUARIOS
  credentials <- shinyauthr::loginServer(
    id           = "login",
    data         = usuarios,
    user_col     = user,
    pwd_col      = password_hash,
    sodium_hashed = TRUE
  )
  observe({
    req(credentials()$user_auth)
    rol <- credentials()$info$rol
    
    if (rol == "conserje") {
      updateTabItems(session, "tabs", "registro")
    } else {
      updateTabItems(session, "tabs", "resumen")
    }
  })
  
  # Cierra sesión y recarga la app
  observeEvent(input$logout_btn, {
    session$reload()
  })
  
  # ============================================
  # MENÚ Y CONTENIDO SEGÚN ROL
  # ============================================
  
  # Menú lateral: conserje ve solo sus pestañas; admin y comité ven todo
  output$menu_sidebar <- renderUI({
    req(credentials()$user_auth)
    rol <- credentials()$info$rol
    
    if (rol == "conserje") {
      sidebarMenu(
        id = "tabs",
        menuItem("Registro",    tabName = "registro",    icon = icon("book")),
        menuItem("Encomiendas", tabName = "encomiendas", icon = icon("box")),
        menuItem("Mantención",  tabName = "mantencion",  icon = icon("wrench"))
      )
    } else {
      sidebarMenu( 
        id = "tabs",
        menuItem("Resumen",        tabName = "resumen",     icon = icon("home")),
        menuItem("Finanzas",       tabName = "finanzas", icon = icon("chart-line")),
        menuItem("Gastos Comunes", tabName = "gastos",      icon = icon("dollar-sign")),
        menuItem("Mantención",     tabName = "mantencion",  icon = icon("wrench")),
        menuItem("Encomiendas",    tabName = "encomiendas", icon = icon("box")),
        menuItem("Registro",       tabName = "registro",    icon = icon("book")),
        menuItem("Usuarios",       tabName = "usuarios",    icon = icon("users"))
      )
    }
  })
  
  # Contenido: estructura de pestañas disponibles tras login
  output$contenido <- renderUI({
    req(credentials()$user_auth)
    tabItems(
      tabItem(tabName = "resumen",     uiOutput("resumen_ui")),
      tabItem(tabName = "finanzas",    uiOutput("finanzas_ui")),
      tabItem(tabName = "gastos",      uiOutput("gastos_ui")),
      tabItem(tabName = "mantencion",  uiOutput("mantencion_ui")),
      tabItem(tabName = "encomiendas", uiOutput("encomiendas_ui")),
      tabItem(tabName = "registro",    uiOutput("registro_ui")),
      tabItem(tabName = "usuarios",    uiOutput("usuarios_ui"))
    )
  })
  
  # ============================================
  # PESTAÑAS - DEFINICIÓN DE INTERFAZ (renderUI)
  # ============================================
  
  # --- RESUMEN: KPIs + gráfico + trabajadores ---
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
  
  output$finanzas_ui <- renderUI({
    tagList(
      h2("Finanzas"),
      tabsetPanel(
        
        # --- TAB INGRESOS ---
        tabPanel("Ingresos",
                 fluidRow(
                   box(width = 4, title = "Registrar Ingreso",
                       selectInput("ing_tipo", "Tipo:", choices = c()),
                       selectInput("ing_depto", "Departamento:", choices = c("N/A")),
                       numericInput("ing_monto", "Monto ($):", value = 0, min = 0),
                       dateInput("ing_fecha", "Fecha:", value = Sys.Date()),
                       actionButton("guardar_ingreso", "Registrar", class = "btn-primary")
                   ),
                   box(width = 8, title = "Historial de Ingresos",
                       selectInput("filtro_periodo_ing", "Período:",
                                   choices = c("Mes actual", "Semestre", "Año")),
                       tableOutput("tabla_ingresos")
                   )
                 )
        ),
        
        # --- TAB EGRESOS ---
        tabPanel("Egresos",
                 fluidRow(
                   box(width = 4, title = "Registrar Egreso",
                       selectInput("eg_tipo", "Tipo:", choices = c()),
                       numericInput("eg_monto", "Monto ($):", value = 0, min = 0),
                       dateInput("eg_fecha", "Fecha:", value = Sys.Date()),
                       actionButton("guardar_egreso", "Registrar", class = "btn-primary")
                   ),
                   box(width = 8, title = "Historial de Egresos",
                       selectInput("filtro_periodo_eg", "Período:",
                                   choices = c("Mes actual", "Semestre", "Año")),
                       tableOutput("tabla_egresos")
                   )
                 )
        )
      )
    )
  })
  
  # --- FINANZAS: HISTORIAL INGRESOS ---
  output$tabla_ingresos <- renderTable({
    input$guardar_ingreso
    
    periodo <- input$filtro_periodo_ing
    
    if (periodo == "Mes actual") {
      filtro <- "AND DATE_TRUNC('month', fecha) = DATE_TRUNC('month', CURRENT_DATE)"
    } else if (periodo == "Semestre") {
      filtro <- "AND fecha >= CURRENT_DATE - INTERVAL '6 months'"
    } else {
      filtro <- "AND fecha >= CURRENT_DATE - INTERVAL '1 year'"
    }
    
    dbGetQuery(con, paste0(
      "SELECT ti.nombre AS tipo, d.numero_departamento AS departamento,
     TO_CHAR(i.monto, 'FM999G999G999') AS monto,
     TO_CHAR(i.fecha, 'DD-MM-YYYY') AS fecha
     FROM ingresos i
     INNER JOIN tipo_ingreso ti ON ti.id_tipo_ingreso = i.id_tipo_ingreso
     LEFT JOIN departamentos d ON d.id_departamento = i.id_departamento
     WHERE 1=1 ", filtro, " ORDER BY i.fecha DESC"
    ))
  })
  
  # --- FINANZAS: HISTORIAL EGRESOS ---
  output$tabla_egresos <- renderTable({
    input$guardar_egreso
    
    periodo <- input$filtro_periodo_eg
    
    if (periodo == "Mes actual") {
      filtro <- "AND DATE_TRUNC('month', fecha) = DATE_TRUNC('month', CURRENT_DATE)"
    } else if (periodo == "Semestre") {
      filtro <- "AND fecha >= CURRENT_DATE - INTERVAL '6 months'"
    } else {
      filtro <- "AND fecha >= CURRENT_DATE - INTERVAL '1 year'"
    }
    
    dbGetQuery(con, paste0(
      "SELECT te.nombre AS tipo,
     TO_CHAR(e.monto, 'FM999G999G999') AS monto,
     TO_CHAR(e.fecha, 'DD-MM-YYYY') AS fecha
     FROM egresos e
     INNER JOIN tipo_egreso te ON te.id_tipo_egreso = e.id_tipo_egreso
     WHERE 1=1 ", filtro, " ORDER BY e.fecha DESC"
    ))
  })
  
  # --- GASTOS COMUNES: filtros + tabla ---
  output$gastos_ui <- renderUI({
    tagList(
      h2("Gastos Comunes"),
      fluidRow(
        column(4, selectInput("filtro_depto",  "Departamento:", choices = c("Todos"))),
        column(4, dateInput("filtro_fecha",    "Mes:", value = Sys.Date())),
        column(4, selectInput("filtro_estado", "Estado:", choices = c("Todos", "Pagados", "Pendientes")))
      ),
      fluidRow(box(width = 12, tableOutput("gastos_comunes")))
    )
  })
  
  # --- MANTENCIÓN: buscador + trabajos pendientes ---
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
  
  # --- ENCOMIENDAS: historial + pendientes con alerta de color ---
  output$encomiendas_ui <- renderUI({
    tagList(
      h2("Encomiendas"),
      fluidRow(
        box(width = 12, title = "Registrar Encomienda",
            selectInput("enc_depto", "Departamento:", choices = c()),
            textInput("enc_empresa", "Empresa de despacho:"),
            actionButton("guardar_encomienda", "Registrar", class = "btn-primary")
        )
      ),
      fluidRow(box(width = 12, title = "Buscar Historial",
                   textInput("buscar_encomienda", "Buscar por departamento o empresa:"),
                   DTOutput("historial_encomiendas")
      )),
      fluidRow(box(width = 12, title = "Encomiendas Pendientes",
                   DTOutput("encomiendas_pendientes")))
    )
  })
  # --- REGISTRO DE TURNO: formulario + historial de novedades ---
  output$registro_ui <- renderUI({
    tagList(
      h2("Registro de Turno"),
      fluidRow(
        box(width = 12, title = "Nueva Novedad",
            textAreaInput("novedad_texto", "Descripción:", rows = 4, width = "100%"),
            actionButton("guardar_novedad", "Guardar", class = "btn-primary")
        )
      ),
      fluidRow(
        box(width = 12, title = "Novedades Registradas",
            tableOutput("tabla_novedades"))
      )
    )
  })
  
  # --- USUARIOS: solo visible para admin ---
  output$usuarios_ui <- renderUI({
    req(credentials()$info$rol == "admin")
    tagList(
      h2("Administración de Usuarios"),
      fluidRow(
        # Formulario de creación de usuario
        box(width = 6, title = "Nuevo Usuario",
            textInput("nuevo_username", "Usuario:"),
            textInput("nuevo_password", "Contraseña:"),
            selectInput("nuevo_rol", "Rol:", choices = c("conserje", "admin", "comite")),
            # Selector de trabajador solo visible cuando el rol es conserje
            conditionalPanel(
              condition = "input.nuevo_rol == 'conserje'",
              selectInput("nuevo_trabajador", "Trabajador:", choices = c())
            ),
            actionButton("guardar_usuario", "Crear Usuario", class = "btn-primary")
        ),
        # Lista de usuarios registrados
        box(width = 6, title = "Usuarios Registrados",
            tableOutput("tabla_usuarios")
        ),
        # Desactivar usuario existente
        box(width = 12, title = "Desactivar Usuario",
            selectInput("usuario_desactivar", "Seleccionar usuario:", choices = c()),
            actionButton("desactivar_usuario", "Desactivar", class = "btn-danger")
        )
      )
    )
  })
  
  # ============================================
  # LÓGICA DE DATOS (renderTable, renderPlot, etc.)
  # ============================================
  
  # --- RESUMEN: KPIs ---
  
  # Total de ingresos registrados en la tabla INGRESOS
  output$total_ingresos <- renderValueBox({
    resultado <- dbGetQuery(con, "SELECT SUM(monto) AS total FROM ingresos")
    valueBox(
      paste("$", prettyNum(resultado$total, big.mark = ".", scientific = FALSE)),
      "Total Ingresos", icon = icon("arrow-up"), color = "green"
    )
  })
  
  # Total de egresos registrados en la tabla EGRESOS
  output$total_egresos <- renderValueBox({
    resultado <- dbGetQuery(con, "SELECT SUM(monto) AS total FROM egresos")
    valueBox(
      paste("$", prettyNum(resultado$total, big.mark = ".", scientific = FALSE)),
      "Total Egresos", icon = icon("arrow-down"), color = "red"
    )
  })
  
  # Fondo de reserva calculado desde la VIEW vista_balance_real (ingresos - egresos)
  output$fondo_reserva <- renderValueBox({
    resultado <- dbGetQuery(con, "SELECT total FROM vista_balance_real")
    valueBox(
      paste("$", prettyNum(resultado$total, big.mark = ".", scientific = FALSE)),
      "Fondo de Reserva", icon = icon("piggy-bank"), color = "blue"
    )
  })
  
  # --- RESUMEN: GRÁFICO ---
  # Barras agrupadas de ingresos y egresos por mes (últimos 12 meses)
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
  
  # --- RESUMEN: TRABAJADORES ---
  # Lista de trabajadores activos
  output$trabajadores <- renderTable({
    dbGetQuery(con, "SELECT nombre, cargo FROM trabajadores WHERE activo = true")
  })
  
  # --- GASTOS COMUNES ---
  # Carga los departamentos al selector al iniciar
  observe({
    req(credentials()$user_auth)
    req(!is.null(input$filtro_depto))
    deptos <- dbGetQuery(con,
                         "SELECT numero_departamento FROM departamentos ORDER BY numero_departamento")
    updateSelectInput(session, "filtro_depto", choices = c("Todos", deptos$numero_departamento))
  })
  
  # Tabla con filtros dinámicos: departamento, fecha y estado de pago
  output$gastos_comunes <- renderTable({
    query <- "SELECT numero_departamento AS departamento, monto,
              TO_CHAR(fecha_emision,'DD-MM-YYYY') AS emision,
              TO_CHAR(fecha_pago, 'DD-MM-YYYY') AS pago
              FROM gastos_comunes
              INNER JOIN departamentos ON departamentos.id_departamento = gastos_comunes.id_departamento"
    
    # Filtro por departamento y fecha límite
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
  
  # --- MANTENCIÓN ---
  
  # Trabajos pendientes desde la VIEW trabajos_faltante
  output$trabajos_pendientes <- renderTable({
    dbGetQuery(con, "SELECT * FROM trabajos_faltante")
  })
  
  # Buscador: filtra por descripción o tipo (Emergencia/Programada/Servicio)
  # Solo muestra resultados cuando hay texto en el buscador
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
     OR LOWER(CAST(mantencion AS TEXT)) LIKE LOWER('%", input$buscar_trabajo, "%')"
    ))
  })  
  # --- ENCOMIENDAS ---
  
  # Encomiendas no entregadas con alerta visual por días guardado:
  # Blanco < 3 días | Naranja 3-7 días | Rojo > 7 días
  output$encomiendas_pendientes <- renderDT({
    input$guardar_encomienda  # Reactivo para actualizar tras cada guardado
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
                  color           = styleInterval(c(3, 7), c('black', 'black', 'white'))
      )
  })
  # Carga departamentos en el selector de encomiendas
  observe({
    req(credentials()$user_auth)
    input$guardar_encomienda
    deptos <- dbGetQuery(con, "SELECT id_departamento, numero_departamento FROM departamentos ORDER BY numero_departamento")
    choices <- setNames(deptos$id_departamento, deptos$numero_departamento)
    updateSelectInput(session, "enc_depto", choices = choices)
  })
  
  # Guarda la encomienda y su primer estado en el historial
  observeEvent(input$guardar_encomienda, {
    req(input$enc_empresa)
    id_trabajador <- credentials()$info$id_trabajador
    
    # Inserta la encomienda
    dbExecute(con, paste0(
      "INSERT INTO ENCOMIENDA (id_departamento, empresa_despacho) VALUES (",
      input$enc_depto, ", '", input$enc_empresa, "')"
    ))
    
    # Obtiene el ID de la encomienda recién creada
    id_enc <- dbGetQuery(con, "SELECT MAX(id_encomienda) AS id FROM encomienda")$id
    
    # Registra el estado inicial en el historial
    dbExecute(con, paste0(
      "INSERT INTO HISTORIAL_ENCOMIENDA (id_encomienda, id_trabajador, estado, fecha_hora) VALUES (",
      id_enc, ", ", id_trabajador, ", 'Recibido', NOW())"
    ))
    
    showNotification("Encomienda registrada exitosamente", type = "message")
  })
  
  # Buscador de historial por departamento o empresa
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
  
  # --- REGISTRO DE TURNO ---
  
  # Guarda la novedad en la tabla REGISTRO vinculada al trabajador logueado
  observeEvent(input$guardar_novedad, {
    req(input$novedad_texto)
    id_trabajador <- credentials()$info$id_trabajador
    dbExecute(con, paste0(
      "INSERT INTO REGISTRO (ID_trabajador, registro, fecha) VALUES (",
      id_trabajador, ", '", input$novedad_texto, "', NOW())"
    ))
    showNotification("Novedad guardada exitosamente", type = "message")
  })
  
  # Muestra las últimas 20 novedades registradas, ordenadas por fecha descendente
  output$tabla_novedades <- renderTable({
    input$guardar_novedad  # Reactivo para actualizar tras cada guardado
    dbGetQuery(con,
               "SELECT r.registro, TO_CHAR(r.fecha, 'DD-MM-YYYY HH24:MI') AS fecha,
       t.nombre AS trabajador
       FROM registro r
       INNER JOIN trabajadores t ON t.id_trabajador = r.id_trabajador
       ORDER BY r.fecha DESC LIMIT 20")
  })
  
  # --- ADMINISTRACIÓN DE USUARIOS (solo admin) ---
  
  # Carga trabajadores activos en el selector de nuevo usuario
  # Se actualiza al crear un nuevo usuario
  observe({
    req(credentials()$info$rol == "admin")
    input$guardar_usuario
    trabajadores <- dbGetQuery(con,
                               "SELECT id_trabajador, nombre FROM trabajadores WHERE activo = true")
    choices <- setNames(trabajadores$id_trabajador, trabajadores$nombre)
    updateSelectInput(session, "nuevo_trabajador", choices = choices)
  })
  
  # Muestra todos los usuarios registrados (activos e inactivos)
  output$tabla_usuarios <- renderTable({
    input$guardar_usuario
    dbGetQuery(con,
               "SELECT u.username, u.rol, t.nombre AS trabajador
     FROM usuarios u
     LEFT JOIN trabajadores t ON t.id_trabajador = u.id_trabajador
     WHERE u.activo = true")
  })
  
  # Crea un nuevo usuario con contraseña hasheada
  observeEvent(input$guardar_usuario, {
    req(input$nuevo_username, input$nuevo_password)
    hash <- sodium::password_store(input$nuevo_password)
    dbExecute(con, paste0(
      "INSERT INTO USUARIOS (username, password_hash, rol, id_trabajador) VALUES ('",
      input$nuevo_username, "', '", hash, "', '",
      input$nuevo_rol, "', ", input$nuevo_trabajador, ")"
    ))
    showNotification("Usuario creado exitosamente", type = "message")
  })
  
  # Carga los usuarios activos en el selector de desactivación
  # Se actualiza al crear un nuevo usuario
  observe({
    req(credentials()$user_auth)
    req(credentials()$info$rol == "admin")
    input$guardar_usuario
    usuarios_activos <- dbGetQuery(con,
                                   "SELECT username FROM usuarios WHERE activo = true")
    updateSelectInput(session, "usuario_desactivar", choices = usuarios_activos$username)
  })
  
  # Desactiva el usuario seleccionado (activo = false)
  observeEvent(input$desactivar_usuario, {
    dbExecute(con, paste0(
      "UPDATE USUARIOS SET activo = false WHERE username = '",
      input$usuario_desactivar, "'"))
    showNotification("Usuario desactivado", type = "warning")
  })
  
  
# Carga tipos de ingreso y departamentos en los selectores
observe({
  req(credentials()$info$rol == "admin")
  req(!is.null(input$ing_tipo))
  
  tipos_ing <- dbGetQuery(con, "SELECT id_tipo_ingreso, nombre FROM tipo_ingreso ORDER BY nombre")
  updateSelectInput(session, "ing_tipo", 
                    choices = setNames(tipos_ing$id_tipo_ingreso, tipos_ing$nombre))
  
  deptos <- dbGetQuery(con, "SELECT id_departamento, numero_departamento FROM departamentos ORDER BY numero_departamento")
  choices_depto <- c("N/A" = 0, setNames(deptos$id_departamento, deptos$numero_departamento))
  updateSelectInput(session, "ing_depto", choices = choices_depto)
  
  tipos_eg <- dbGetQuery(con, "SELECT id_tipo_egreso, nombre FROM tipo_egreso ORDER BY nombre")
  updateSelectInput(session, "eg_tipo",
                    choices = setNames(tipos_eg$id_tipo_egreso, tipos_eg$nombre))
})

# Guarda nuevo ingreso
observeEvent(input$guardar_ingreso, {
  req(input$ing_monto > 0)
  
  id_depto <- if (input$ing_depto == 0) "NULL" else input$ing_depto
  
  dbExecute(con, paste0(
    "INSERT INTO INGRESOS (id_tipo_ingreso, id_departamento, monto, fecha) VALUES (",
    input$ing_tipo, ", ", id_depto, ", ",
    input$ing_monto, ", '", input$ing_fecha, "')"
  ))
  showNotification("Ingreso registrado exitosamente", type = "message")
})

# Guarda nuevo egreso
observeEvent(input$guardar_egreso, {
  req(input$eg_monto > 0)
  
  dbExecute(con, paste0(
    "INSERT INTO EGRESOS (id_tipo_egreso, monto, fecha) VALUES (",
    input$eg_tipo, ", ", input$eg_monto, ", '", input$eg_fecha, "')"
  ))
  showNotification("Egreso registrado exitosamente", type = "message")
})

}

# --- INICIAR APLICACIÓN ---
shinyApp(ui = ui, server = server)