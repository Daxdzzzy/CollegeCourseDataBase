--
-- PostgreSQL database dump
--

-- Dumped from database version 14.12
-- Dumped by pg_dump version 16.8 (Ubuntu 16.8-0ubuntu0.24.04.1)

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
-- Name: public; Type: SCHEMA; Schema: -; Owner: postgres
--

-- *not* creating schema, since initdb creates it


ALTER SCHEMA public OWNER TO postgres;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: comments; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.comments (
    com_id integer NOT NULL,
    summary text NOT NULL,
    date timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    tid integer,
    uid integer
);


ALTER TABLE public.comments OWNER TO postgres;

--
-- Name: comentarios_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.comentarios_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.comentarios_id_seq OWNER TO postgres;

--
-- Name: comentarios_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.comentarios_id_seq OWNED BY public.comments.com_id;


--
-- Name: tags; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.tags (
    tgid integer NOT NULL,
    tg_name character varying(50) NOT NULL
);


ALTER TABLE public.tags OWNER TO postgres;

--
-- Name: etiquetas_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.etiquetas_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.etiquetas_id_seq OWNER TO postgres;

--
-- Name: etiquetas_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.etiquetas_id_seq OWNED BY public.tags.tgid;


--
-- Name: priorities; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.priorities (
    pid integer NOT NULL,
    p_name character varying(20) NOT NULL
);


ALTER TABLE public.priorities OWNER TO postgres;

--
-- Name: prioridades_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.prioridades_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.prioridades_id_seq OWNER TO postgres;

--
-- Name: prioridades_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.prioridades_id_seq OWNED BY public.priorities.pid;


--
-- Name: tasks; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.tasks (
    tid integer NOT NULL,
    title character varying(255) NOT NULL,
    summary text,
    status character varying(50) DEFAULT 'pendiente'::character varying,
    created_date timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    limit_date date,
    uid integer,
    pid integer
);


ALTER TABLE public.tasks OWNER TO postgres;

--
-- Name: tareas_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.tareas_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.tareas_id_seq OWNER TO postgres;

--
-- Name: tareas_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.tareas_id_seq OWNED BY public.tasks.tid;


--
-- Name: task_tags; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.task_tags (
    tid integer NOT NULL,
    tgid integer NOT NULL
);


ALTER TABLE public.task_tags OWNER TO postgres;

--
-- Name: users; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.users (
    uid integer NOT NULL,
    name character varying(100) NOT NULL,
    email character varying(100) NOT NULL,
    register_date timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.users OWNER TO postgres;

--
-- Name: usuarios_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.usuarios_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.usuarios_id_seq OWNER TO postgres;

--
-- Name: usuarios_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.usuarios_id_seq OWNED BY public.users.uid;


--
-- Name: comments com_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.comments ALTER COLUMN com_id SET DEFAULT nextval('public.comentarios_id_seq'::regclass);


--
-- Name: priorities pid; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.priorities ALTER COLUMN pid SET DEFAULT nextval('public.prioridades_id_seq'::regclass);


--
-- Name: tags tgid; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.tags ALTER COLUMN tgid SET DEFAULT nextval('public.etiquetas_id_seq'::regclass);


--
-- Name: tasks tid; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.tasks ALTER COLUMN tid SET DEFAULT nextval('public.tareas_id_seq'::regclass);


--
-- Name: users uid; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.users ALTER COLUMN uid SET DEFAULT nextval('public.usuarios_id_seq'::regclass);


--
-- Data for Name: comments; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.comments (com_id, summary, date, tid, uid) FROM stdin;
1	Revisar cifras antes del viernes.	2025-05-14 12:16:07.710234	6	2
2	Problemas encontrados en la validación del token.	2025-05-14 12:16:07.710234	7	3
3	Agregar nuevos estilos CSS.	2025-05-14 12:16:07.710234	8	4
4	Cliente confirmó la hora.	2025-05-14 12:16:07.710234	9	2
\.


--
-- Data for Name: priorities; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.priorities (pid, p_name) FROM stdin;
1	baja
2	media
3	alta
\.


--
-- Data for Name: tags; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.tags (tgid, tg_name) FROM stdin;
1	urgente
2	personal
3	trabajo
4	revisión
\.


--
-- Data for Name: task_tags; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.task_tags (tid, tgid) FROM stdin;
6	3
6	4
7	1
7	3
8	2
9	1
9	3
\.


--
-- Data for Name: tasks; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.tasks (tid, title, summary, status, created_date, limit_date, uid, pid) FROM stdin;
6	Redactar informe mensual	Preparar informe de desempeño del mes.	pendiente	2025-06-01 00:00:00	\N	2	2
7	Revisar código fuente	Auditar módulo de autenticación.	en progreso	2025-05-25 00:00:00	\N	3	3
8	Actualizar sitio web	Cambiar banner de portada y corregir errores.	pendiente	2025-06-10 00:00:00	\N	4	1
9	Planificar reunión	Organizar la reunión con el cliente.	completada	2025-05-10 00:00:00	\N	2	2
\.


--
-- Data for Name: users; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.users (uid, name, email, register_date) FROM stdin;
2	Ana Torres	ana@example.com	2025-05-14 12:12:52.864112
3	Luis Pérez	luis@example.com	2025-05-14 12:12:52.864112
4	María López	maria@example.com	2025-05-14 12:12:52.864112
\.


--
-- Name: comentarios_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.comentarios_id_seq', 4, true);


--
-- Name: etiquetas_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.etiquetas_id_seq', 4, true);


--
-- Name: prioridades_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.prioridades_id_seq', 6, true);


--
-- Name: tareas_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.tareas_id_seq', 9, true);


--
-- Name: usuarios_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.usuarios_id_seq', 4, true);


--
-- Name: comments comentarios_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.comments
    ADD CONSTRAINT comentarios_pkey PRIMARY KEY (com_id);


--
-- Name: tags etiquetas_nombre_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.tags
    ADD CONSTRAINT etiquetas_nombre_key UNIQUE (tg_name);


--
-- Name: tags etiquetas_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.tags
    ADD CONSTRAINT etiquetas_pkey PRIMARY KEY (tgid);


--
-- Name: priorities prioridades_nombre_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.priorities
    ADD CONSTRAINT prioridades_nombre_key UNIQUE (p_name);


--
-- Name: priorities prioridades_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.priorities
    ADD CONSTRAINT prioridades_pkey PRIMARY KEY (pid);


--
-- Name: task_tags tareas_etiquetas_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.task_tags
    ADD CONSTRAINT tareas_etiquetas_pkey PRIMARY KEY (tid, tgid);


--
-- Name: tasks tareas_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.tasks
    ADD CONSTRAINT tareas_pkey PRIMARY KEY (tid);


--
-- Name: users usuarios_email_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT usuarios_email_key UNIQUE (email);


--
-- Name: users usuarios_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT usuarios_pkey PRIMARY KEY (uid);


--
-- Name: comments comentarios_tarea_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.comments
    ADD CONSTRAINT comentarios_tarea_id_fkey FOREIGN KEY (tid) REFERENCES public.tasks(tid) ON DELETE CASCADE;


--
-- Name: comments comentarios_usuario_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.comments
    ADD CONSTRAINT comentarios_usuario_id_fkey FOREIGN KEY (uid) REFERENCES public.users(uid) ON DELETE SET NULL;


--
-- Name: task_tags tareas_etiquetas_etiqueta_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.task_tags
    ADD CONSTRAINT tareas_etiquetas_etiqueta_id_fkey FOREIGN KEY (tgid) REFERENCES public.tags(tgid) ON DELETE CASCADE;


--
-- Name: task_tags tareas_etiquetas_tarea_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.task_tags
    ADD CONSTRAINT tareas_etiquetas_tarea_id_fkey FOREIGN KEY (tid) REFERENCES public.tasks(tid) ON DELETE CASCADE;


--
-- Name: tasks tareas_prioridad_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.tasks
    ADD CONSTRAINT tareas_prioridad_id_fkey FOREIGN KEY (pid) REFERENCES public.priorities(pid);


--
-- Name: tasks tareas_usuario_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.tasks
    ADD CONSTRAINT tareas_usuario_id_fkey FOREIGN KEY (uid) REFERENCES public.users(uid) ON DELETE CASCADE;


--
-- Name: SCHEMA public; Type: ACL; Schema: -; Owner: postgres
--

REVOKE USAGE ON SCHEMA public FROM PUBLIC;
GRANT ALL ON SCHEMA public TO PUBLIC;


--
-- PostgreSQL database dump complete
--

