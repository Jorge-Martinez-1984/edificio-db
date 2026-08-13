--
-- PostgreSQL database dump
--

\restrict T9sqjJC4QgD0oZGLdkwl3Yy86n4b1VRiiZINPUhNuElFV6XFwc7rn7d2VCvpIrO

-- Dumped from database version 16.14
-- Dumped by pg_dump version 16.14

-- Started on 2026-08-13 01:35:46

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- TOC entry 915 (class 1247 OID 16504)
-- Name: estado_encomienda; Type: TYPE; Schema: public; Owner: postgres
--

CREATE TYPE public.estado_encomienda AS ENUM (
    'Recibido',
    'En Bodega',
    'Entregado'
);


ALTER TYPE public.estado_encomienda OWNER TO postgres;

--
-- TOC entry 927 (class 1247 OID 16575)
-- Name: tipo_mantencion; Type: TYPE; Schema: public; Owner: postgres
--

CREATE TYPE public.tipo_mantencion AS ENUM (
    'Emergencia',
    'Programada',
    'Servicio'
);


ALTER TYPE public.tipo_mantencion OWNER TO postgres;

--
-- TOC entry 257 (class 1255 OID 16688)
-- Name: estado_trabajador(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.estado_trabajador() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
UPDATE trabajadores
SET activo = false 
WHERE id_trabajador = NEW.id_trabajador
AND EXISTS (
  SELECT 1 FROM trabajadores_confidencial  
  WHERE id_trabajador = NEW.id_trabajador
  AND fecha_desvinculacion IS NOT NULL
);
  RETURN NEW;
END;
$$;


ALTER FUNCTION public.estado_trabajador() OWNER TO postgres;

--
-- TOC entry 256 (class 1255 OID 16686)
-- Name: morosidad(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.morosidad() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  -- Verificamos si existe AL MENOS UN gasto sin pagar (NULL)
  IF EXISTS (
    SELECT 1 FROM GASTOS_COMUNES 
    WHERE id_departamento = NEW.id_departamento 
    AND fecha_pago IS NULL
  ) THEN
    -- CASO 1: Hay gastos sin pagar (NULL) -> Marcar como Moroso
    UPDATE DEPARTAMENTOS 
    SET morosidad = true 
    WHERE id_departamento = NEW.id_departamento;
  ELSE
    -- CASO 2: NO hay gastos sin pagar (Todos son NOT NULL) -> Marcar como Al día
    UPDATE DEPARTAMENTOS 
    SET morosidad = false 
    WHERE id_departamento = NEW.id_departamento;
  END IF;

  RETURN NEW;
END;
$$;


ALTER FUNCTION public.morosidad() OWNER TO postgres;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- TOC entry 252 (class 1259 OID 16647)
-- Name: balance; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.balance (
    id_balance integer NOT NULL,
    fecha_balance date,
    total_ingreso integer,
    total_egreso integer,
    fondo_reserva integer,
    CONSTRAINT check_total_egreso CHECK ((total_egreso >= 0)),
    CONSTRAINT check_total_ingresos CHECK ((total_ingreso >= 0))
);


ALTER TABLE public.balance OWNER TO postgres;

--
-- TOC entry 251 (class 1259 OID 16646)
-- Name: balance_id_balance_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.balance_id_balance_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.balance_id_balance_seq OWNER TO postgres;

--
-- TOC entry 5121 (class 0 OID 0)
-- Dependencies: 251
-- Name: balance_id_balance_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.balance_id_balance_seq OWNED BY public.balance.id_balance;


--
-- TOC entry 228 (class 1259 OID 16456)
-- Name: departamentos; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.departamentos (
    id_departamento integer NOT NULL,
    id_propietario integer,
    numero_departamento character varying(5),
    estacionamiento character varying(5),
    morosidad boolean
);


ALTER TABLE public.departamentos OWNER TO postgres;

--
-- TOC entry 227 (class 1259 OID 16455)
-- Name: departamentos_id_departamento_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.departamentos_id_departamento_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.departamentos_id_departamento_seq OWNER TO postgres;

--
-- TOC entry 5122 (class 0 OID 0)
-- Dependencies: 227
-- Name: departamentos_id_departamento_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.departamentos_id_departamento_seq OWNED BY public.departamentos.id_departamento;


--
-- TOC entry 255 (class 1259 OID 16682)
-- Name: deptos_morosos; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.deptos_morosos AS
 SELECT numero_departamento
   FROM public.departamentos
  WHERE (morosidad IS TRUE);


ALTER VIEW public.deptos_morosos OWNER TO postgres;

--
-- TOC entry 240 (class 1259 OID 16558)
-- Name: egresos; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.egresos (
    id_egreso integer NOT NULL,
    id_tipo_egreso integer,
    monto integer,
    fecha timestamp without time zone,
    CONSTRAINT check_egreso_monto_positivo CHECK ((monto > 0))
);


ALTER TABLE public.egresos OWNER TO postgres;

--
-- TOC entry 239 (class 1259 OID 16557)
-- Name: egresos_id_egreso_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.egresos_id_egreso_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.egresos_id_egreso_seq OWNER TO postgres;

--
-- TOC entry 5123 (class 0 OID 0)
-- Dependencies: 239
-- Name: egresos_id_egreso_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.egresos_id_egreso_seq OWNED BY public.egresos.id_egreso;


--
-- TOC entry 221 (class 1259 OID 16425)
-- Name: empresas; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.empresas (
    id_empresa integer NOT NULL,
    nombre character varying(50)
);


ALTER TABLE public.empresas OWNER TO postgres;

--
-- TOC entry 220 (class 1259 OID 16424)
-- Name: empresas_id_empresa_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.empresas_id_empresa_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.empresas_id_empresa_seq OWNER TO postgres;

--
-- TOC entry 5124 (class 0 OID 0)
-- Dependencies: 220
-- Name: empresas_id_empresa_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.empresas_id_empresa_seq OWNED BY public.empresas.id_empresa;


--
-- TOC entry 234 (class 1259 OID 16492)
-- Name: encomienda; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.encomienda (
    id_encomienda integer NOT NULL,
    id_departamento integer,
    empresa_despacho character varying(50)
);


ALTER TABLE public.encomienda OWNER TO postgres;

--
-- TOC entry 233 (class 1259 OID 16491)
-- Name: encomienda_id_encomienda_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.encomienda_id_encomienda_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.encomienda_id_encomienda_seq OWNER TO postgres;

--
-- TOC entry 5125 (class 0 OID 0)
-- Dependencies: 233
-- Name: encomienda_id_encomienda_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.encomienda_id_encomienda_seq OWNED BY public.encomienda.id_encomienda;


--
-- TOC entry 244 (class 1259 OID 16596)
-- Name: factura_mantencion; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.factura_mantencion (
    id_factura integer NOT NULL,
    id_mantencion integer,
    costo integer,
    numero_factura character varying(50),
    fecha_pago date,
    CONSTRAINT check_factura_monto_positivo CHECK ((costo > 0))
);


ALTER TABLE public.factura_mantencion OWNER TO postgres;

--
-- TOC entry 243 (class 1259 OID 16595)
-- Name: factura_mantencion_id_factura_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.factura_mantencion_id_factura_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.factura_mantencion_id_factura_seq OWNER TO postgres;

--
-- TOC entry 5126 (class 0 OID 0)
-- Dependencies: 243
-- Name: factura_mantencion_id_factura_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.factura_mantencion_id_factura_seq OWNED BY public.factura_mantencion.id_factura;


--
-- TOC entry 250 (class 1259 OID 16635)
-- Name: gastos_comunes; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.gastos_comunes (
    id_gastos integer NOT NULL,
    id_departamento integer NOT NULL,
    monto integer,
    fecha_emision date NOT NULL,
    fecha_pago date,
    CONSTRAINT check_gastos_monto_positivo CHECK ((monto > 0))
);


ALTER TABLE public.gastos_comunes OWNER TO postgres;

--
-- TOC entry 249 (class 1259 OID 16634)
-- Name: gastos_comunes_id_gastos_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.gastos_comunes_id_gastos_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.gastos_comunes_id_gastos_seq OWNER TO postgres;

--
-- TOC entry 5127 (class 0 OID 0)
-- Dependencies: 249
-- Name: gastos_comunes_id_gastos_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.gastos_comunes_id_gastos_seq OWNED BY public.gastos_comunes.id_gastos;


--
-- TOC entry 236 (class 1259 OID 16512)
-- Name: historial_encomienda; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.historial_encomienda (
    id_historial integer NOT NULL,
    id_encomienda integer,
    id_trabajador integer,
    estado public.estado_encomienda,
    fecha_hora timestamp without time zone
);


ALTER TABLE public.historial_encomienda OWNER TO postgres;

--
-- TOC entry 235 (class 1259 OID 16511)
-- Name: historial_encomienda_id_historial_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.historial_encomienda_id_historial_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.historial_encomienda_id_historial_seq OWNER TO postgres;

--
-- TOC entry 5128 (class 0 OID 0)
-- Dependencies: 235
-- Name: historial_encomienda_id_historial_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.historial_encomienda_id_historial_seq OWNED BY public.historial_encomienda.id_historial;


--
-- TOC entry 238 (class 1259 OID 16541)
-- Name: ingresos; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.ingresos (
    id_ingreso integer NOT NULL,
    id_departamento integer,
    id_tipo_ingreso integer,
    monto integer,
    fecha timestamp without time zone,
    CONSTRAINT check_ingreso_monto_positivo CHECK ((monto > 0))
);


ALTER TABLE public.ingresos OWNER TO postgres;

--
-- TOC entry 237 (class 1259 OID 16540)
-- Name: ingresos_id_ingreso_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.ingresos_id_ingreso_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.ingresos_id_ingreso_seq OWNER TO postgres;

--
-- TOC entry 5129 (class 0 OID 0)
-- Dependencies: 237
-- Name: ingresos_id_ingreso_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.ingresos_id_ingreso_seq OWNED BY public.ingresos.id_ingreso;


--
-- TOC entry 242 (class 1259 OID 16582)
-- Name: mantencion; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.mantencion (
    id_mantencion integer NOT NULL,
    id_empresa integer,
    servicio_prestado character varying(500),
    mantencion public.tipo_mantencion,
    fecha_trabajo timestamp without time zone
);


ALTER TABLE public.mantencion OWNER TO postgres;

--
-- TOC entry 241 (class 1259 OID 16581)
-- Name: mantencion_id_mantencion_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.mantencion_id_mantencion_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.mantencion_id_mantencion_seq OWNER TO postgres;

--
-- TOC entry 5130 (class 0 OID 0)
-- Dependencies: 241
-- Name: mantencion_id_mantencion_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.mantencion_id_mantencion_seq OWNED BY public.mantencion.id_mantencion;


--
-- TOC entry 216 (class 1259 OID 16398)
-- Name: propietarios; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.propietarios (
    id_propietario integer NOT NULL,
    nombre character varying(50) NOT NULL,
    apellido character varying(50)
);


ALTER TABLE public.propietarios OWNER TO postgres;

--
-- TOC entry 226 (class 1259 OID 16445)
-- Name: propietarios_confidencial; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.propietarios_confidencial (
    id_propietario integer NOT NULL,
    rut character varying(10) NOT NULL,
    email character varying(50) NOT NULL,
    celular character varying(9) NOT NULL
);


ALTER TABLE public.propietarios_confidencial OWNER TO postgres;

--
-- TOC entry 215 (class 1259 OID 16397)
-- Name: propietarios_id_propietario_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.propietarios_id_propietario_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.propietarios_id_propietario_seq OWNER TO postgres;

--
-- TOC entry 5131 (class 0 OID 0)
-- Dependencies: 215
-- Name: propietarios_id_propietario_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.propietarios_id_propietario_seq OWNED BY public.propietarios.id_propietario;


--
-- TOC entry 246 (class 1259 OID 16608)
-- Name: registro; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.registro (
    id_registro integer NOT NULL,
    id_trabajador integer,
    registro character varying(1000),
    fecha timestamp without time zone
);


ALTER TABLE public.registro OWNER TO postgres;

--
-- TOC entry 245 (class 1259 OID 16607)
-- Name: registro_id_registro_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.registro_id_registro_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.registro_id_registro_seq OWNER TO postgres;

--
-- TOC entry 5132 (class 0 OID 0)
-- Dependencies: 245
-- Name: registro_id_registro_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.registro_id_registro_seq OWNED BY public.registro.id_registro;


--
-- TOC entry 232 (class 1259 OID 16480)
-- Name: residentes; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.residentes (
    id_residente integer NOT NULL,
    id_titular integer,
    nombre character varying(50),
    apellido character varying(50),
    rut character varying(10) NOT NULL,
    celular character varying(9)
);


ALTER TABLE public.residentes OWNER TO postgres;

--
-- TOC entry 231 (class 1259 OID 16479)
-- Name: residentes_id_residente_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.residentes_id_residente_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.residentes_id_residente_seq OWNER TO postgres;

--
-- TOC entry 5133 (class 0 OID 0)
-- Dependencies: 231
-- Name: residentes_id_residente_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.residentes_id_residente_seq OWNED BY public.residentes.id_residente;


--
-- TOC entry 248 (class 1259 OID 16623)
-- Name: sueldo; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.sueldo (
    id_sueldo integer NOT NULL,
    id_trabajador integer NOT NULL,
    sueldo integer NOT NULL,
    fecha date NOT NULL,
    CONSTRAINT check_sueldo_positivo CHECK ((sueldo > 0))
);


ALTER TABLE public.sueldo OWNER TO postgres;

--
-- TOC entry 247 (class 1259 OID 16622)
-- Name: sueldo_id_sueldo_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.sueldo_id_sueldo_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.sueldo_id_sueldo_seq OWNER TO postgres;

--
-- TOC entry 5134 (class 0 OID 0)
-- Dependencies: 247
-- Name: sueldo_id_sueldo_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.sueldo_id_sueldo_seq OWNED BY public.sueldo.id_sueldo;


--
-- TOC entry 225 (class 1259 OID 16439)
-- Name: tipo_egreso; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.tipo_egreso (
    id_tipo_egreso integer NOT NULL,
    nombre character varying(50)
);


ALTER TABLE public.tipo_egreso OWNER TO postgres;

--
-- TOC entry 224 (class 1259 OID 16438)
-- Name: tipo_egreso_id_tipo_egreso_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.tipo_egreso_id_tipo_egreso_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.tipo_egreso_id_tipo_egreso_seq OWNER TO postgres;

--
-- TOC entry 5135 (class 0 OID 0)
-- Dependencies: 224
-- Name: tipo_egreso_id_tipo_egreso_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.tipo_egreso_id_tipo_egreso_seq OWNED BY public.tipo_egreso.id_tipo_egreso;


--
-- TOC entry 223 (class 1259 OID 16432)
-- Name: tipo_ingreso; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.tipo_ingreso (
    id_tipo_ingreso integer NOT NULL,
    nombre character varying(50)
);


ALTER TABLE public.tipo_ingreso OWNER TO postgres;

--
-- TOC entry 222 (class 1259 OID 16431)
-- Name: tipo_ingreso_id_tipo_ingreso_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.tipo_ingreso_id_tipo_ingreso_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.tipo_ingreso_id_tipo_ingreso_seq OWNER TO postgres;

--
-- TOC entry 5136 (class 0 OID 0)
-- Dependencies: 222
-- Name: tipo_ingreso_id_tipo_ingreso_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.tipo_ingreso_id_tipo_ingreso_seq OWNED BY public.tipo_ingreso.id_tipo_ingreso;


--
-- TOC entry 230 (class 1259 OID 16468)
-- Name: titular; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.titular (
    id_titular integer NOT NULL,
    id_departamento integer,
    nombre character varying(50),
    apellido character varying(50),
    rut character varying(10) NOT NULL,
    celular character varying(9) NOT NULL,
    email character varying(50) NOT NULL,
    es_arrendatario boolean,
    fecha_ingreso date,
    fecha_salida date
);


ALTER TABLE public.titular OWNER TO postgres;

--
-- TOC entry 229 (class 1259 OID 16467)
-- Name: titular_id_titular_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.titular_id_titular_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.titular_id_titular_seq OWNER TO postgres;

--
-- TOC entry 5137 (class 0 OID 0)
-- Dependencies: 229
-- Name: titular_id_titular_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.titular_id_titular_seq OWNED BY public.titular.id_titular;


--
-- TOC entry 218 (class 1259 OID 16407)
-- Name: trabajadores; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.trabajadores (
    id_trabajador integer NOT NULL,
    nombre character varying(50),
    apellido character varying(50),
    cargo character varying(20),
    celular character varying(9),
    activo boolean DEFAULT true
);


ALTER TABLE public.trabajadores OWNER TO postgres;

--
-- TOC entry 219 (class 1259 OID 16414)
-- Name: trabajadores_confidencial; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.trabajadores_confidencial (
    id_trabajador integer NOT NULL,
    sueldo integer,
    email character varying(50) NOT NULL,
    direccion character varying(20),
    fecha_contratacion date,
    fecha_desvinculacion date,
    rut character varying(10) NOT NULL
);


ALTER TABLE public.trabajadores_confidencial OWNER TO postgres;

--
-- TOC entry 217 (class 1259 OID 16406)
-- Name: trabajadores_id_trabajador_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.trabajadores_id_trabajador_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.trabajadores_id_trabajador_seq OWNER TO postgres;

--
-- TOC entry 5138 (class 0 OID 0)
-- Dependencies: 217
-- Name: trabajadores_id_trabajador_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.trabajadores_id_trabajador_seq OWNED BY public.trabajadores.id_trabajador;


--
-- TOC entry 254 (class 1259 OID 16678)
-- Name: trabajos_faltante; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.trabajos_faltante AS
 SELECT servicio_prestado,
    mantencion
   FROM public.mantencion
  WHERE (fecha_trabajo IS NOT NULL);


ALTER VIEW public.trabajos_faltante OWNER TO postgres;

--
-- TOC entry 253 (class 1259 OID 16670)
-- Name: vista_balance_real; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.vista_balance_real AS
 SELECT (sum(monto) - ( SELECT sum(egresos.monto) AS sum
           FROM public.egresos)) AS total
   FROM public.ingresos;


ALTER VIEW public.vista_balance_real OWNER TO postgres;

--
-- TOC entry 4866 (class 2604 OID 16650)
-- Name: balance id_balance; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.balance ALTER COLUMN id_balance SET DEFAULT nextval('public.balance_id_balance_seq'::regclass);


--
-- TOC entry 4854 (class 2604 OID 16459)
-- Name: departamentos id_departamento; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.departamentos ALTER COLUMN id_departamento SET DEFAULT nextval('public.departamentos_id_departamento_seq'::regclass);


--
-- TOC entry 4860 (class 2604 OID 16561)
-- Name: egresos id_egreso; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.egresos ALTER COLUMN id_egreso SET DEFAULT nextval('public.egresos_id_egreso_seq'::regclass);


--
-- TOC entry 4851 (class 2604 OID 16428)
-- Name: empresas id_empresa; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.empresas ALTER COLUMN id_empresa SET DEFAULT nextval('public.empresas_id_empresa_seq'::regclass);


--
-- TOC entry 4857 (class 2604 OID 16495)
-- Name: encomienda id_encomienda; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.encomienda ALTER COLUMN id_encomienda SET DEFAULT nextval('public.encomienda_id_encomienda_seq'::regclass);


--
-- TOC entry 4862 (class 2604 OID 16599)
-- Name: factura_mantencion id_factura; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.factura_mantencion ALTER COLUMN id_factura SET DEFAULT nextval('public.factura_mantencion_id_factura_seq'::regclass);


--
-- TOC entry 4865 (class 2604 OID 16638)
-- Name: gastos_comunes id_gastos; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.gastos_comunes ALTER COLUMN id_gastos SET DEFAULT nextval('public.gastos_comunes_id_gastos_seq'::regclass);


--
-- TOC entry 4858 (class 2604 OID 16515)
-- Name: historial_encomienda id_historial; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.historial_encomienda ALTER COLUMN id_historial SET DEFAULT nextval('public.historial_encomienda_id_historial_seq'::regclass);


--
-- TOC entry 4859 (class 2604 OID 16544)
-- Name: ingresos id_ingreso; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.ingresos ALTER COLUMN id_ingreso SET DEFAULT nextval('public.ingresos_id_ingreso_seq'::regclass);


--
-- TOC entry 4861 (class 2604 OID 16585)
-- Name: mantencion id_mantencion; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.mantencion ALTER COLUMN id_mantencion SET DEFAULT nextval('public.mantencion_id_mantencion_seq'::regclass);


--
-- TOC entry 4848 (class 2604 OID 16401)
-- Name: propietarios id_propietario; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.propietarios ALTER COLUMN id_propietario SET DEFAULT nextval('public.propietarios_id_propietario_seq'::regclass);


--
-- TOC entry 4863 (class 2604 OID 16611)
-- Name: registro id_registro; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.registro ALTER COLUMN id_registro SET DEFAULT nextval('public.registro_id_registro_seq'::regclass);


--
-- TOC entry 4856 (class 2604 OID 16483)
-- Name: residentes id_residente; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.residentes ALTER COLUMN id_residente SET DEFAULT nextval('public.residentes_id_residente_seq'::regclass);


--
-- TOC entry 4864 (class 2604 OID 16626)
-- Name: sueldo id_sueldo; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.sueldo ALTER COLUMN id_sueldo SET DEFAULT nextval('public.sueldo_id_sueldo_seq'::regclass);


--
-- TOC entry 4853 (class 2604 OID 16442)
-- Name: tipo_egreso id_tipo_egreso; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.tipo_egreso ALTER COLUMN id_tipo_egreso SET DEFAULT nextval('public.tipo_egreso_id_tipo_egreso_seq'::regclass);


--
-- TOC entry 4852 (class 2604 OID 16435)
-- Name: tipo_ingreso id_tipo_ingreso; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.tipo_ingreso ALTER COLUMN id_tipo_ingreso SET DEFAULT nextval('public.tipo_ingreso_id_tipo_ingreso_seq'::regclass);


--
-- TOC entry 4855 (class 2604 OID 16471)
-- Name: titular id_titular; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.titular ALTER COLUMN id_titular SET DEFAULT nextval('public.titular_id_titular_seq'::regclass);


--
-- TOC entry 4849 (class 2604 OID 16410)
-- Name: trabajadores id_trabajador; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.trabajadores ALTER COLUMN id_trabajador SET DEFAULT nextval('public.trabajadores_id_trabajador_seq'::regclass);


--
-- TOC entry 5115 (class 0 OID 16647)
-- Dependencies: 252
-- Data for Name: balance; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.balance (id_balance, fecha_balance, total_ingreso, total_egreso, fondo_reserva) FROM stdin;
1	2026-07-01	340000	1360000	-1020000
\.


--
-- TOC entry 5091 (class 0 OID 16456)
-- Dependencies: 228
-- Data for Name: departamentos; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.departamentos (id_departamento, id_propietario, numero_departamento, estacionamiento, morosidad) FROM stdin;
1	1	101	A-12	f
3	3	201	A-15	f
5	5	301	\N	f
7	1	401	C-02	f
8	1	402	\N	f
4	4	202	B-03	t
6	1	302	B-02	t
2	2	102	\N	f
\.


--
-- TOC entry 5103 (class 0 OID 16558)
-- Dependencies: 240
-- Data for Name: egresos; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.egresos (id_egreso, id_tipo_egreso, monto, fecha) FROM stdin;
1	1	650000	2026-07-01 00:00:00
2	2	380000	2026-07-03 00:00:00
3	3	120000	2026-07-07 00:00:00
4	4	210000	2026-07-12 00:00:00
\.


--
-- TOC entry 5084 (class 0 OID 16425)
-- Dependencies: 221
-- Data for Name: empresas; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.empresas (id_empresa, nombre) FROM stdin;
1	Ascensores Chile S.A
2	Secutitas LTDA.
3	Bombas Valpo.
\.


--
-- TOC entry 5097 (class 0 OID 16492)
-- Dependencies: 234
-- Data for Name: encomienda; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.encomienda (id_encomienda, id_departamento, empresa_despacho) FROM stdin;
1	1	Mercado libre
2	6	Chile Post
3	3	Ripley
4	2	Falabella
\.


--
-- TOC entry 5107 (class 0 OID 16596)
-- Dependencies: 244
-- Data for Name: factura_mantencion; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.factura_mantencion (id_factura, id_mantencion, costo, numero_factura, fecha_pago) FROM stdin;
1	1	210000	12540	\N
2	2	85000	9844	\N
3	3	120000	5521	\N
4	4	45000	9910	\N
\.


--
-- TOC entry 5113 (class 0 OID 16635)
-- Dependencies: 250
-- Data for Name: gastos_comunes; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.gastos_comunes (id_gastos, id_departamento, monto, fecha_emision, fecha_pago) FROM stdin;
1	1	85000	2026-06-05	2026-06-06
3	3	88000	2026-06-05	2026-06-15
4	4	88000	2026-06-05	2026-06-07
5	5	85000	2026-06-05	2026-06-28
6	6	95000	2026-06-05	\N
7	7	90000	2026-06-05	2026-06-18
8	8	85000	2026-06-05	2026-06-08
11	4	88000	2026-07-08	2026-07-08
2	2	92000	2026-06-05	2026-08-08
\.


--
-- TOC entry 5099 (class 0 OID 16512)
-- Dependencies: 236
-- Data for Name: historial_encomienda; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.historial_encomienda (id_historial, id_encomienda, id_trabajador, estado, fecha_hora) FROM stdin;
1	1	2	Entregado	2026-07-09 00:00:00
2	2	1	Recibido	2026-07-09 00:00:00
3	3	1	Entregado	2026-07-08 00:00:00
4	4	2	Entregado	2026-07-05 00:00:00
\.


--
-- TOC entry 5101 (class 0 OID 16541)
-- Dependencies: 238
-- Data for Name: ingresos; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.ingresos (id_ingreso, id_departamento, id_tipo_ingreso, monto, fecha) FROM stdin;
1	1	1	85000	2026-07-05 00:00:00
2	2	1	92000	2026-07-06 00:00:00
3	3	2	25000	2026-07-10 00:00:00
4	6	3	50000	2026-07-14 00:00:00
5	4	1	88000	2026-07-15 00:00:00
\.


--
-- TOC entry 5105 (class 0 OID 16582)
-- Dependencies: 242
-- Data for Name: mantencion; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.mantencion (id_mantencion, id_empresa, servicio_prestado, mantencion, fecha_trabajo) FROM stdin;
1	1	Mantención bimensual preventiva y lubricación de rieles en ascensor A y B.	Programada	2026-06-15 00:00:00
2	2	Reparación de cableado y reconfiguración de cámara del pasillo del piso 3 por pérdida de señal.	Emergencia	2026-06-22 00:00:00
3	3	Cambio de sello mecánico de urgencia por filtración de agua en bomba principal de la torre.	Emergencia	2026-07-02 00:00:00
4	2	Prueba del sistema de grabación y limpieza de lentes en domos exteriores.	Programada	2026-07-12 00:00:00
\.


--
-- TOC entry 5079 (class 0 OID 16398)
-- Dependencies: 216
-- Data for Name: propietarios; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.propietarios (id_propietario, nombre, apellido) FROM stdin;
1	Juan	Pérez
2	Mario	Donzáles
3	Carlos	Muñoz
4	Ana	Silva
5	Luis	Contreras
\.


--
-- TOC entry 5089 (class 0 OID 16445)
-- Dependencies: 226
-- Data for Name: propietarios_confidencial; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.propietarios_confidencial (id_propietario, rut, email, celular) FROM stdin;
1	14325678-9	1@email.com	123456789
2	16789432-K	2@email.com	123456788
3	12456789-5	3@email.com	123456777
4	12456789-3	4@email.com	123456666
5	18234567-2	5@email.com	123455555
\.


--
-- TOC entry 5109 (class 0 OID 16608)
-- Dependencies: 246
-- Data for Name: registro; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.registro (id_registro, id_trabajador, registro, fecha) FROM stdin;
1	1	Residente del depto 201 reporta ruidos molestos (música alta) provenientes del depto 302. Se sube a fiscalizar y se solicita bajar el volumen. Residente acata de buena manera.	2026-07-15 23:40:00
2	2	Ingresa técnico de la empresa "Ascensores Chile S.A." a realizar revisión rutinaria del ascensor B.	2026-07-16 10:15:00
\.


--
-- TOC entry 5095 (class 0 OID 16480)
-- Dependencies: 232
-- Data for Name: residentes; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.residentes (id_residente, id_titular, nombre, apellido, rut, celular) FROM stdin;
3	1	Sofía	Pérez	21456789-0	987654321
5	3	Patricia	Muñoz	14876543-2	912345678
7	4	Ignacio	Silva	19876543-k	956781234
8	5	Gabriela	Contreras	20345678-9	945612378
4	2	Lucas	González	24567890-k	\N
6	1	Benjamín	Pérez	23987654-1	\N
\.


--
-- TOC entry 5111 (class 0 OID 16623)
-- Dependencies: 248
-- Data for Name: sueldo; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.sueldo (id_sueldo, id_trabajador, sueldo, fecha) FROM stdin;
1	1	650000	2026-06-30
2	2	650000	2026-06-30
\.


--
-- TOC entry 5088 (class 0 OID 16439)
-- Dependencies: 225
-- Data for Name: tipo_egreso; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.tipo_egreso (id_tipo_egreso, nombre) FROM stdin;
1	Sueldo
2	Pago Luz area comunes
3	Mantención Bombas de Agua
4	Mantención Ascensores
\.


--
-- TOC entry 5086 (class 0 OID 16432)
-- Dependencies: 223
-- Data for Name: tipo_ingreso; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.tipo_ingreso (id_tipo_ingreso, nombre) FROM stdin;
1	Gastos Comunes
2	Arriendo Quincho
3	Multa
\.


--
-- TOC entry 5093 (class 0 OID 16468)
-- Dependencies: 230
-- Data for Name: titular; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.titular (id_titular, id_departamento, nombre, apellido, rut, celular, email, es_arrendatario, fecha_ingreso, fecha_salida) FROM stdin;
1	1	Diego	Morales	17432987-6	34567765	M@email.com	t	2024-01-15	\N
2	2	Camila	Rojas	19543210-7	32555888	C@email.com	t	2023-06-01	2025-06-01
3	3	Jorge	Castro	13876543-4	45345899	J@email.com	t	2025-02-01	\N
5	4	Nicolás	Tapia	16345987-1	98098987	N@mail.com	t	2022-03-15	2024-03-15
4	5	Valentina	Araya	20123456-8	21321321	V@mail.com	t	2024-11-10	\N
\.


--
-- TOC entry 5081 (class 0 OID 16407)
-- Dependencies: 218
-- Data for Name: trabajadores; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.trabajadores (id_trabajador, nombre, apellido, cargo, celular, activo) FROM stdin;
1	Pedro	Soto	Conserje	123456789	t
2	Manuel	Vergara	Conserje	123456788	t
3	Cristian	Olivares	Conserje	123456777	f
5	Carlo	Morales	conserje	123459555	f
4	Jose	Leiva	conserje	123455555	f
\.


--
-- TOC entry 5082 (class 0 OID 16414)
-- Dependencies: 219
-- Data for Name: trabajadores_confidencial; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.trabajadores_confidencial (id_trabajador, sueldo, email, direccion, fecha_contratacion, fecha_desvinculacion, rut) FROM stdin;
1	550000	P@emal.com	mi casa 1	2024-01-15	\N	3465678-4
2	550000	M@email.com	tu casa 3	2020-04-10	\N	10445888-3
3	480000	C@miemail.com	dpto 4	2023-05-15	2025-11-30	19444777-K
5	540000	Conserje	casa6	2025-05-24	3036-06-08	19656728-0
4	540000	Conserje	depto5	2025-05-24	2026-08-12	19656768-k
\.


--
-- TOC entry 5139 (class 0 OID 0)
-- Dependencies: 251
-- Name: balance_id_balance_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.balance_id_balance_seq', 1, true);


--
-- TOC entry 5140 (class 0 OID 0)
-- Dependencies: 227
-- Name: departamentos_id_departamento_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.departamentos_id_departamento_seq', 8, true);


--
-- TOC entry 5141 (class 0 OID 0)
-- Dependencies: 239
-- Name: egresos_id_egreso_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.egresos_id_egreso_seq', 4, true);


--
-- TOC entry 5142 (class 0 OID 0)
-- Dependencies: 220
-- Name: empresas_id_empresa_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.empresas_id_empresa_seq', 3, true);


--
-- TOC entry 5143 (class 0 OID 0)
-- Dependencies: 233
-- Name: encomienda_id_encomienda_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.encomienda_id_encomienda_seq', 4, true);


--
-- TOC entry 5144 (class 0 OID 0)
-- Dependencies: 243
-- Name: factura_mantencion_id_factura_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.factura_mantencion_id_factura_seq', 4, true);


--
-- TOC entry 5145 (class 0 OID 0)
-- Dependencies: 249
-- Name: gastos_comunes_id_gastos_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.gastos_comunes_id_gastos_seq', 13, true);


--
-- TOC entry 5146 (class 0 OID 0)
-- Dependencies: 235
-- Name: historial_encomienda_id_historial_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.historial_encomienda_id_historial_seq', 4, true);


--
-- TOC entry 5147 (class 0 OID 0)
-- Dependencies: 237
-- Name: ingresos_id_ingreso_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.ingresos_id_ingreso_seq', 5, true);


--
-- TOC entry 5148 (class 0 OID 0)
-- Dependencies: 241
-- Name: mantencion_id_mantencion_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.mantencion_id_mantencion_seq', 4, true);


--
-- TOC entry 5149 (class 0 OID 0)
-- Dependencies: 215
-- Name: propietarios_id_propietario_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.propietarios_id_propietario_seq', 5, true);


--
-- TOC entry 5150 (class 0 OID 0)
-- Dependencies: 245
-- Name: registro_id_registro_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.registro_id_registro_seq', 2, true);


--
-- TOC entry 5151 (class 0 OID 0)
-- Dependencies: 231
-- Name: residentes_id_residente_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.residentes_id_residente_seq', 14, true);


--
-- TOC entry 5152 (class 0 OID 0)
-- Dependencies: 247
-- Name: sueldo_id_sueldo_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.sueldo_id_sueldo_seq', 2, true);


--
-- TOC entry 5153 (class 0 OID 0)
-- Dependencies: 224
-- Name: tipo_egreso_id_tipo_egreso_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.tipo_egreso_id_tipo_egreso_seq', 4, true);


--
-- TOC entry 5154 (class 0 OID 0)
-- Dependencies: 222
-- Name: tipo_ingreso_id_tipo_ingreso_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.tipo_ingreso_id_tipo_ingreso_seq', 3, true);


--
-- TOC entry 5155 (class 0 OID 0)
-- Dependencies: 229
-- Name: titular_id_titular_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.titular_id_titular_seq', 5, true);


--
-- TOC entry 5156 (class 0 OID 0)
-- Dependencies: 217
-- Name: trabajadores_id_trabajador_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.trabajadores_id_trabajador_seq', 7, true);


--
-- TOC entry 4913 (class 2606 OID 16652)
-- Name: balance balance_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.balance
    ADD CONSTRAINT balance_pkey PRIMARY KEY (id_balance);


--
-- TOC entry 4889 (class 2606 OID 16461)
-- Name: departamentos departamentos_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.departamentos
    ADD CONSTRAINT departamentos_pkey PRIMARY KEY (id_departamento);


--
-- TOC entry 4901 (class 2606 OID 16563)
-- Name: egresos egresos_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.egresos
    ADD CONSTRAINT egresos_pkey PRIMARY KEY (id_egreso);


--
-- TOC entry 4881 (class 2606 OID 16430)
-- Name: empresas empresas_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.empresas
    ADD CONSTRAINT empresas_pkey PRIMARY KEY (id_empresa);


--
-- TOC entry 4895 (class 2606 OID 16497)
-- Name: encomienda encomienda_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.encomienda
    ADD CONSTRAINT encomienda_pkey PRIMARY KEY (id_encomienda);


--
-- TOC entry 4905 (class 2606 OID 16601)
-- Name: factura_mantencion factura_mantencion_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.factura_mantencion
    ADD CONSTRAINT factura_mantencion_pkey PRIMARY KEY (id_factura);


--
-- TOC entry 4911 (class 2606 OID 16640)
-- Name: gastos_comunes gastos_comunes_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.gastos_comunes
    ADD CONSTRAINT gastos_comunes_pkey PRIMARY KEY (id_gastos);


--
-- TOC entry 4897 (class 2606 OID 16517)
-- Name: historial_encomienda historial_encomienda_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.historial_encomienda
    ADD CONSTRAINT historial_encomienda_pkey PRIMARY KEY (id_historial);


--
-- TOC entry 4899 (class 2606 OID 16546)
-- Name: ingresos ingresos_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.ingresos
    ADD CONSTRAINT ingresos_pkey PRIMARY KEY (id_ingreso);


--
-- TOC entry 4903 (class 2606 OID 16589)
-- Name: mantencion mantencion_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.mantencion
    ADD CONSTRAINT mantencion_pkey PRIMARY KEY (id_mantencion);


--
-- TOC entry 4887 (class 2606 OID 16449)
-- Name: propietarios_confidencial propietarios_confidencial_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.propietarios_confidencial
    ADD CONSTRAINT propietarios_confidencial_pkey PRIMARY KEY (id_propietario);


--
-- TOC entry 4875 (class 2606 OID 16403)
-- Name: propietarios propietarios_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.propietarios
    ADD CONSTRAINT propietarios_pkey PRIMARY KEY (id_propietario);


--
-- TOC entry 4907 (class 2606 OID 16615)
-- Name: registro registro_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.registro
    ADD CONSTRAINT registro_pkey PRIMARY KEY (id_registro);


--
-- TOC entry 4893 (class 2606 OID 16485)
-- Name: residentes residentes_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.residentes
    ADD CONSTRAINT residentes_pkey PRIMARY KEY (id_residente);


--
-- TOC entry 4909 (class 2606 OID 16628)
-- Name: sueldo sueldo_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.sueldo
    ADD CONSTRAINT sueldo_pkey PRIMARY KEY (id_sueldo);


--
-- TOC entry 4885 (class 2606 OID 16444)
-- Name: tipo_egreso tipo_egreso_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.tipo_egreso
    ADD CONSTRAINT tipo_egreso_pkey PRIMARY KEY (id_tipo_egreso);


--
-- TOC entry 4883 (class 2606 OID 16437)
-- Name: tipo_ingreso tipo_ingreso_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.tipo_ingreso
    ADD CONSTRAINT tipo_ingreso_pkey PRIMARY KEY (id_tipo_ingreso);


--
-- TOC entry 4891 (class 2606 OID 16473)
-- Name: titular titular_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.titular
    ADD CONSTRAINT titular_pkey PRIMARY KEY (id_titular);


--
-- TOC entry 4879 (class 2606 OID 16418)
-- Name: trabajadores_confidencial trabajadores_confidencial_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.trabajadores_confidencial
    ADD CONSTRAINT trabajadores_confidencial_pkey PRIMARY KEY (id_trabajador);


--
-- TOC entry 4877 (class 2606 OID 16412)
-- Name: trabajadores trabajadores_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.trabajadores
    ADD CONSTRAINT trabajadores_pkey PRIMARY KEY (id_trabajador);


--
-- TOC entry 4931 (class 2620 OID 16687)
-- Name: gastos_comunes actualizar_morosos; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER actualizar_morosos AFTER INSERT OR UPDATE ON public.gastos_comunes FOR EACH ROW EXECUTE FUNCTION public.morosidad();


--
-- TOC entry 4930 (class 2620 OID 16691)
-- Name: trabajadores_confidencial actualizar_trabajador; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER actualizar_trabajador AFTER UPDATE ON public.trabajadores_confidencial FOR EACH ROW EXECUTE FUNCTION public.estado_trabajador();


--
-- TOC entry 4916 (class 2606 OID 16462)
-- Name: departamentos departamentos_id_propietario_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.departamentos
    ADD CONSTRAINT departamentos_id_propietario_fkey FOREIGN KEY (id_propietario) REFERENCES public.propietarios(id_propietario);


--
-- TOC entry 4924 (class 2606 OID 16569)
-- Name: egresos egresos_id_tipo_egreso_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.egresos
    ADD CONSTRAINT egresos_id_tipo_egreso_fkey FOREIGN KEY (id_tipo_egreso) REFERENCES public.tipo_egreso(id_tipo_egreso);


--
-- TOC entry 4919 (class 2606 OID 16498)
-- Name: encomienda encomienda_id_departamento_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.encomienda
    ADD CONSTRAINT encomienda_id_departamento_fkey FOREIGN KEY (id_departamento) REFERENCES public.departamentos(id_departamento);


--
-- TOC entry 4926 (class 2606 OID 16602)
-- Name: factura_mantencion factura_mantencion_id_mantencion_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.factura_mantencion
    ADD CONSTRAINT factura_mantencion_id_mantencion_fkey FOREIGN KEY (id_mantencion) REFERENCES public.mantencion(id_mantencion);


--
-- TOC entry 4929 (class 2606 OID 16641)
-- Name: gastos_comunes gastos_comunes_id_departamento_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.gastos_comunes
    ADD CONSTRAINT gastos_comunes_id_departamento_fkey FOREIGN KEY (id_departamento) REFERENCES public.departamentos(id_departamento);


--
-- TOC entry 4920 (class 2606 OID 16518)
-- Name: historial_encomienda historial_encomienda_id_encomienda_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.historial_encomienda
    ADD CONSTRAINT historial_encomienda_id_encomienda_fkey FOREIGN KEY (id_encomienda) REFERENCES public.encomienda(id_encomienda);


--
-- TOC entry 4921 (class 2606 OID 16523)
-- Name: historial_encomienda historial_encomienda_id_trabajador_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.historial_encomienda
    ADD CONSTRAINT historial_encomienda_id_trabajador_fkey FOREIGN KEY (id_trabajador) REFERENCES public.trabajadores(id_trabajador);


--
-- TOC entry 4922 (class 2606 OID 16547)
-- Name: ingresos ingresos_id_departamento_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.ingresos
    ADD CONSTRAINT ingresos_id_departamento_fkey FOREIGN KEY (id_departamento) REFERENCES public.departamentos(id_departamento);


--
-- TOC entry 4923 (class 2606 OID 16552)
-- Name: ingresos ingresos_id_tipo_ingreso_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.ingresos
    ADD CONSTRAINT ingresos_id_tipo_ingreso_fkey FOREIGN KEY (id_tipo_ingreso) REFERENCES public.tipo_ingreso(id_tipo_ingreso);


--
-- TOC entry 4925 (class 2606 OID 16590)
-- Name: mantencion mantencion_id_empresa_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.mantencion
    ADD CONSTRAINT mantencion_id_empresa_fkey FOREIGN KEY (id_empresa) REFERENCES public.empresas(id_empresa);


--
-- TOC entry 4915 (class 2606 OID 16450)
-- Name: propietarios_confidencial propietarios_confidencial_id_propietario_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.propietarios_confidencial
    ADD CONSTRAINT propietarios_confidencial_id_propietario_fkey FOREIGN KEY (id_propietario) REFERENCES public.propietarios(id_propietario);


--
-- TOC entry 4927 (class 2606 OID 16616)
-- Name: registro registro_id_trabajador_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.registro
    ADD CONSTRAINT registro_id_trabajador_fkey FOREIGN KEY (id_trabajador) REFERENCES public.trabajadores(id_trabajador);


--
-- TOC entry 4918 (class 2606 OID 16486)
-- Name: residentes residentes_id_titular_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.residentes
    ADD CONSTRAINT residentes_id_titular_fkey FOREIGN KEY (id_titular) REFERENCES public.titular(id_titular);


--
-- TOC entry 4928 (class 2606 OID 16629)
-- Name: sueldo sueldo_id_trabajador_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.sueldo
    ADD CONSTRAINT sueldo_id_trabajador_fkey FOREIGN KEY (id_trabajador) REFERENCES public.trabajadores(id_trabajador);


--
-- TOC entry 4917 (class 2606 OID 16474)
-- Name: titular titular_id_departamento_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.titular
    ADD CONSTRAINT titular_id_departamento_fkey FOREIGN KEY (id_departamento) REFERENCES public.departamentos(id_departamento);


--
-- TOC entry 4914 (class 2606 OID 16419)
-- Name: trabajadores_confidencial trabajadores_confidencial_id_trabajador_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.trabajadores_confidencial
    ADD CONSTRAINT trabajadores_confidencial_id_trabajador_fkey FOREIGN KEY (id_trabajador) REFERENCES public.trabajadores(id_trabajador);


-- Completed on 2026-08-13 01:35:47

--
-- PostgreSQL database dump complete
--

\unrestrict T9sqjJC4QgD0oZGLdkwl3Yy86n4b1VRiiZINPUhNuElFV6XFwc7rn7d2VCvpIrO

