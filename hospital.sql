--
-- PostgreSQL database dump
--

-- Dumped from database version 14.13 (Ubuntu 14.13-0ubuntu0.22.04.1)
-- Dumped by pg_dump version 14.13 (Ubuntu 14.13-0ubuntu0.22.04.1)

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
-- Name: add_appointment(integer, integer, timestamp without time zone, character varying); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.add_appointment(IN a_patient_id integer, IN a_doctor_id integer, IN a_appointment_date timestamp without time zone, IN a_appointment_status character varying)
    LANGUAGE plpgsql
    AS $$
BEGIN
    INSERT INTO appointments (patient_id, doctor_id, appointment_date, appointment_status)
    VALUES (a_patient_id, a_doctor_id, a_appointment_date, a_appointment_status);
END;
$$;


ALTER PROCEDURE public.add_appointment(IN a_patient_id integer, IN a_doctor_id integer, IN a_appointment_date timestamp without time zone, IN a_appointment_status character varying) OWNER TO postgres;

--
-- Name: add_doctor(character varying, character varying, character varying, character varying, integer); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.add_doctor(IN d_full_name character varying, IN d_contact_number character varying, IN d_specialization character varying, IN d_gmail character varying, IN d_work_experience integer)
    LANGUAGE plpgsql
    AS $$
BEGIN
    INSERT INTO doctors (full_name, contact_number, specialization, gmail, work_experience)
    VALUES (d_full_name, d_contact_number, d_specialization, d_gmail, d_work_experience);
END;
$$;


ALTER PROCEDURE public.add_doctor(IN d_full_name character varying, IN d_contact_number character varying, IN d_specialization character varying, IN d_gmail character varying, IN d_work_experience integer) OWNER TO postgres;

--
-- Name: add_medical_record(integer, integer, date, text, text); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.add_medical_record(IN c_patient_id integer, IN c_doctor_id integer, IN c_record_date date, IN c_diagnosis text, IN c_treatment text)
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- Проверка, что встреча завершена и дата соответствует
    IF EXISTS (
        SELECT 1
        FROM appointments
        WHERE patient_id = c_patient_id
          AND doctor_id = c_doctor_id
          AND appointment_status = 'Завершено'
          AND DATE(appointment_date) = c_record_date
    ) THEN
        INSERT INTO medicalrecords (patient_id, doctor_id, record_date, diagnosis, treatment)
        VALUES (c_patient_id, c_doctor_id, c_record_date, c_diagnosis, c_treatment);
    ELSE
        RAISE EXCEPTION 'Невозможно добавить запись: встреча не завершена или дата не соответствует';
    END IF;
END;
$$;


ALTER PROCEDURE public.add_medical_record(IN c_patient_id integer, IN c_doctor_id integer, IN c_record_date date, IN c_diagnosis text, IN c_treatment text) OWNER TO postgres;

--
-- Name: add_patient(character varying, character, date, character varying); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.add_patient(IN p_full_name character varying, IN p_gender character, IN p_date_of_birth date, IN p_contact_number character varying)
    LANGUAGE plpgsql
    AS $$
BEGIN
    INSERT INTO patients (full_name, gender, date_of_birth, contact_number)
    VALUES (p_full_name, p_gender, p_date_of_birth, p_contact_number);
END;
$$;


ALTER PROCEDURE public.add_patient(IN p_full_name character varying, IN p_gender character, IN p_date_of_birth date, IN p_contact_number character varying) OWNER TO postgres;

--
-- Name: add_prescription(integer, integer, integer, date, character varying); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.add_prescription(IN p_patient_id integer, IN p_doctor_id integer, IN p_medicine_id integer, IN p_prescription_date date, IN p_dosage character varying)
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- Проверка, что медицинская запись существует и статус обследования "Завершено"
    IF EXISTS (
        SELECT 1
        FROM medicalrecords mr
        JOIN appointments a ON mr.patient_id = a.patient_id AND mr.doctor_id = a.doctor_id
        WHERE mr.patient_id = p_patient_id
          AND mr.doctor_id = p_doctor_id
          AND mr.record_date = p_prescription_date
          AND a.appointment_status = 'Завершено'
    ) THEN
        INSERT INTO prescriptions (patient_id, doctor_id, medicine_id, prescription_date, dosage)
        VALUES (p_patient_id, p_doctor_id, p_medicine_id, p_prescription_date, p_dosage);
    ELSE
        RAISE EXCEPTION 'Невозможно добавить рецепт: медицинская запись не существует или статус обследования не "Завершено"';
    END IF;
END;
$$;


ALTER PROCEDURE public.add_prescription(IN p_patient_id integer, IN p_doctor_id integer, IN p_medicine_id integer, IN p_prescription_date date, IN p_dosage character varying) OWNER TO postgres;

--
-- Name: check_appointment_gender(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.check_appointment_gender() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF NEW.doctor_id = (SELECT doctor_id FROM doctors WHERE specialization = 'Уролог') AND NEW.patient_id = (SELECT patient_id FROM patients WHERE gender = 'Ж') THEN
        RAISE EXCEPTION 'Женщины не могут записываться к урологу';
    ELSIF NEW.doctor_id = (SELECT doctor_id FROM Doctors WHERE specialization = 'Гинеколог') AND NEW.patient_id = (SELECT patient_id FROM patients WHERE gender = 'М') THEN
        RAISE EXCEPTION 'Мужчины не могут записываться к гинекологу';
    END IF;
    RETURN NEW;
END;
$$;


ALTER FUNCTION public.check_appointment_gender() OWNER TO postgres;

--
-- Name: check_appointment_time(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.check_appointment_time() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
    existing_appointment RECORD;
BEGIN
    -- Проверка наличия других записей на это время
    SELECT 1
    INTO existing_appointment
    FROM appointments
    WHERE doctor_id = NEW.doctor_id
      AND appointment_date = NEW.appointment_date
      AND appointment_status != 'Отменено';

    IF FOUND THEN
        RAISE EXCEPTION 'Запись на это время уже существует';
    END IF;

    -- Проверка промежутка в 30 минут между записями
    SELECT 1
    INTO existing_appointment
    FROM appointments
    WHERE doctor_id = NEW.doctor_id
      AND appointment_status != 'Отменено'
      AND (
           (appointment_date BETWEEN NEW.appointment_date - INTERVAL '30 minutes' AND NEW.appointment_date + INTERVAL '30 minutes')
        OR (NEW.appointment_date BETWEEN appointment_date - INTERVAL '30 minutes' AND appointment_date + INTERVAL '30 minutes')
      );

    IF FOUND THEN
        RAISE EXCEPTION 'Запись на это время невозможна, так как существует другая запись в пределах 30 минут';
    END IF;

    RETURN NEW;
END;
$$;


ALTER FUNCTION public.check_appointment_time() OWNER TO postgres;

--
-- Name: generate_random_password(integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.generate_random_password(length integer DEFAULT 20) RETURNS text
    LANGUAGE plpgsql
    AS $_$
DECLARE
    chars TEXT := 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#$%^&*()';
    password TEXT := '';
    i INT;
    random_char CHAR;
BEGIN
    FOR i IN 1..length LOOP
        random_char := substr(chars, (random() * length(chars))::INT + 1, 1);
        password := password || random_char;
    END LOOP;
    RETURN password;
END;
$_$;


ALTER FUNCTION public.generate_random_password(length integer) OWNER TO postgres;

--
-- Name: update_doctor_departments(); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.update_doctor_departments()
    LANGUAGE plpgsql
    AS $$
BEGIN
    UPDATE doctors d
    SET department_id = (
        SELECT department_id
        FROM departments
        WHERE department_name = d.specialization || 'ия'
    );
END;
$$;


ALTER PROCEDURE public.update_doctor_departments() OWNER TO postgres;

--
-- Name: update_patient_age(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.update_patient_age() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    NEW.age := EXTRACT(YEAR FROM AGE(NEW.date_of_birth));
    RETURN NEW;
END;
$$;


ALTER FUNCTION public.update_patient_age() OWNER TO postgres;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: appointments; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.appointments (
    appointment_id integer NOT NULL,
    patient_id integer,
    doctor_id integer,
    appointment_date timestamp without time zone NOT NULL,
    appointment_status character varying(20),
    CONSTRAINT appointments_appointment_status_check CHECK (((appointment_status)::text = ANY ((ARRAY['Запланировано'::character varying, 'Завершено'::character varying, 'Отменено'::character varying])::text[])))
);


ALTER TABLE public.appointments OWNER TO postgres;

--
-- Name: appointments_appointment_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.appointments_appointment_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.appointments_appointment_id_seq OWNER TO postgres;

--
-- Name: appointments_appointment_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.appointments_appointment_id_seq OWNED BY public.appointments.appointment_id;


--
-- Name: departments; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.departments (
    department_id integer NOT NULL,
    department_name character varying(100) NOT NULL
);


ALTER TABLE public.departments OWNER TO postgres;

--
-- Name: departments_department_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.departments_department_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.departments_department_id_seq OWNER TO postgres;

--
-- Name: departments_department_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.departments_department_id_seq OWNED BY public.departments.department_id;


--
-- Name: doctorautor; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.doctorautor (
    doctor_id integer NOT NULL,
    login character varying(100) NOT NULL,
    password character varying(20) NOT NULL
);


ALTER TABLE public.doctorautor OWNER TO postgres;

--
-- Name: doctors; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.doctors (
    doctor_id integer NOT NULL,
    full_name character varying(100) NOT NULL,
    contact_number character varying(15) NOT NULL,
    specialization character varying(50) NOT NULL,
    gmail character varying(100) NOT NULL,
    work_experience integer,
    department_id integer
);


ALTER TABLE public.doctors OWNER TO postgres;

--
-- Name: doctors_doctor_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.doctors_doctor_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.doctors_doctor_id_seq OWNER TO postgres;

--
-- Name: doctors_doctor_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.doctors_doctor_id_seq OWNED BY public.doctors.doctor_id;


--
-- Name: medicalrecords; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.medicalrecords (
    record_id integer NOT NULL,
    patient_id integer,
    doctor_id integer,
    record_date date NOT NULL,
    diagnosis text NOT NULL,
    treatment text NOT NULL
);


ALTER TABLE public.medicalrecords OWNER TO postgres;

--
-- Name: medicalrecords_record_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.medicalrecords_record_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.medicalrecords_record_id_seq OWNER TO postgres;

--
-- Name: medicalrecords_record_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.medicalrecords_record_id_seq OWNED BY public.medicalrecords.record_id;


--
-- Name: medicines; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.medicines (
    medicine_id integer NOT NULL,
    medicine_name character varying(100) NOT NULL,
    manufacturer character varying(100) NOT NULL,
    price numeric(10,2),
    CONSTRAINT medicines_price_check CHECK ((price >= (0)::numeric))
);


ALTER TABLE public.medicines OWNER TO postgres;

--
-- Name: medicines_medicine_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.medicines_medicine_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.medicines_medicine_id_seq OWNER TO postgres;

--
-- Name: medicines_medicine_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.medicines_medicine_id_seq OWNED BY public.medicines.medicine_id;


--
-- Name: patients; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.patients (
    patient_id integer NOT NULL,
    full_name character varying(100) NOT NULL,
    gender character(1),
    date_of_birth date NOT NULL,
    contact_number character varying(15) NOT NULL,
    age integer,
    CONSTRAINT patients_gender_check CHECK ((gender = ANY (ARRAY['М'::bpchar, 'Ж'::bpchar])))
);


ALTER TABLE public.patients OWNER TO postgres;

--
-- Name: patients_patient_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.patients_patient_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.patients_patient_id_seq OWNER TO postgres;

--
-- Name: patients_patient_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.patients_patient_id_seq OWNED BY public.patients.patient_id;


--
-- Name: prescriptions; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.prescriptions (
    prescription_id integer NOT NULL,
    patient_id integer,
    doctor_id integer,
    medicine_id integer,
    prescription_date date NOT NULL,
    dosage character varying(50) NOT NULL
);


ALTER TABLE public.prescriptions OWNER TO postgres;

--
-- Name: prescriptions_prescription_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.prescriptions_prescription_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.prescriptions_prescription_id_seq OWNER TO postgres;

--
-- Name: prescriptions_prescription_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.prescriptions_prescription_id_seq OWNED BY public.prescriptions.prescription_id;


--
-- Name: appointments appointment_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.appointments ALTER COLUMN appointment_id SET DEFAULT nextval('public.appointments_appointment_id_seq'::regclass);


--
-- Name: departments department_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.departments ALTER COLUMN department_id SET DEFAULT nextval('public.departments_department_id_seq'::regclass);


--
-- Name: doctors doctor_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.doctors ALTER COLUMN doctor_id SET DEFAULT nextval('public.doctors_doctor_id_seq'::regclass);


--
-- Name: medicalrecords record_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.medicalrecords ALTER COLUMN record_id SET DEFAULT nextval('public.medicalrecords_record_id_seq'::regclass);


--
-- Name: medicines medicine_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.medicines ALTER COLUMN medicine_id SET DEFAULT nextval('public.medicines_medicine_id_seq'::regclass);


--
-- Name: patients patient_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.patients ALTER COLUMN patient_id SET DEFAULT nextval('public.patients_patient_id_seq'::regclass);


--
-- Name: prescriptions prescription_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.prescriptions ALTER COLUMN prescription_id SET DEFAULT nextval('public.prescriptions_prescription_id_seq'::regclass);


--
-- Data for Name: appointments; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.appointments (appointment_id, patient_id, doctor_id, appointment_date, appointment_status) FROM stdin;
1	1	1	2024-12-18 10:00:00	Запланировано
2	3	4	2024-12-15 11:00:00	Завершено
3	3	5	2024-12-19 08:30:00	Запланировано
4	2	3	2024-12-16 13:30:00	Завершено
5	3	9	2024-12-18 14:00:00	Запланировано
6	4	2	2024-12-15 15:00:00	Завершено
7	7	1	2024-12-18 15:00:00	Запланировано
8	5	7	2024-12-18 17:00:00	Отменено
9	9	10	2024-12-18 09:30:00	Запланировано
10	10	6	2024-12-17 10:00:00	Завершено
11	6	8	2024-12-19 10:00:00	Запланировано
12	11	2	2024-12-17 08:00:00	Завершено
13	13	3	2024-12-18 08:30:00	Запланировано
14	8	4	2024-12-17 13:00:00	Завершено
15	15	2	2024-12-20 08:00:00	Запланировано
17	17	7	2024-12-20 08:00:00	Запланировано
18	18	6	2024-12-17 15:00:00	Завершено
20	20	10	2024-12-16 14:00:00	Завершено
16	15	7	2024-12-17 12:00:00	Завершено
19	18	8	2024-12-19 13:00:00	Запланировано
22	20	2	2024-12-17 12:30:00	Завершено
24	2	1	2024-12-18 17:00:00	Завершено
\.


--
-- Data for Name: departments; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.departments (department_id, department_name) FROM stdin;
1	Терапия
2	Кардиология
3	Педиатрия
4	Хирургия
5	Неврология
6	Офтальмология
7	Гинекология
8	Урология
9	Дерматология
10	Эндокринология
\.


--
-- Data for Name: doctorautor; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.doctorautor (doctor_id, login, password) FROM stdin;
1	suleibat	7vJ6)c1wKXnNH5kdz%6P
2	gusnikolay12	%mU#h0e2QSC3k2A9HQxk
3	tni062	jPPwDfUUl1JFUesHnXQ4
4	shibalin90	qmZZBUDWFNrjTVasZ$D2
5	vladimtatyina	MmPcGUEyGuLo#Rzvun3W
6	yuriy_guriyanov	KpK9oPeXjt1#J$umwP6!
7	ludmilkav121	lZDlx0ANSu1ESWZuCxJt
8	alexkovdoc	e3XGrmEW1fvMyMBbC2%I
9	vash_dermatolog121	m5f1s9N1q&uLNsLo#MPh
10	spaseugenehh11	pAkQmf8jZOzgkycNq#7W
\.


--
-- Data for Name: doctors; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.doctors (doctor_id, full_name, contact_number, specialization, gmail, work_experience, department_id) FROM stdin;
1	Сулейманов Арслан Батырханович	+79202334563	Терапевт	suleibat@gmail.com	10	1
2	Гусятин Николай Сергеевич	+79042555678	Кардиолог	gusnikolay12@gmail.com	15	2
3	Тарабукин Николай Ильич	+79003456775	Педиатр	tni062@gmail.com	8	3
4	Шибалин Тимофей Юрьевич	+79154522890	Хирург	shibalin90@gmail.com	12	4
5	Обухова Татьяна Владимировна	+79255678199	Невролог	vladimtatyina@gmail.com	7	5
6	Гурьянов Юрий Андреевич	+79042789012	Офтальмолог	yuriy_guriyanov@gmail.com	9	6
7	Макаренко Людмила Витальевна	+79147887423	Гинеколог	ludmilkav121@gmail.com	11	7
8	Новиков Алексей Игоревич	+79999331234	Уролог	alexkovdoc@gmail.com	6	8
9	Курбатова Светлана Владимировна	+79059091945	Дерматолог	vash_dermatolog121@gmail.com	14	9
10	Спасов Пётр Евгеньевич	+79206243266	Эндокринолог	spaseugenehh11@gmail.com	13	10
11	Новосёлов Алексей Николаевич	+79122331663	Терапевт	novosalex88@gmail.com	12	1
\.


--
-- Data for Name: medicalrecords; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.medicalrecords (record_id, patient_id, doctor_id, record_date, diagnosis, treatment) FROM stdin;
10	2	3	2024-12-16	Гипертония	Медикаменты и диета
11	3	4	2024-12-15	Аппендицит	Операция
12	4	2	2024-12-15	Анемия	Железосодержащие препараты
13	10	6	2024-12-17	Глаукома	Капли для глаз
14	11	2	2024-12-17	Нарушение ритма и проводимости сердца	Пропафенон
15	8	4	2024-12-17	Панкреатит	Диета и медикаменты
16	18	6	2024-12-17	Близорукость	Подбор очков
17	20	10	2024-12-16	Гастрит	Диета и медикаменты
18	15	7	2024-12-17	Гепатит	Медикаменты + повторный осмотр
19	20	2	2024-12-17	Кардиомиопатии	Отказаться от участия в спортивных соревнованиях и от интенсивных физических нагрузок, а также имплантировать кардиовертер-дефибриллятор
\.


--
-- Data for Name: medicines; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.medicines (medicine_id, medicine_name, manufacturer, price) FROM stdin;
1	Аспирин	ФармаКо	539.00
2	Парацетамол	МедПром	70.00
3	Ибупрофен	ФармаКо	98.00
4	Амоксициллин	МедПром	120.00
5	Азитромицин	ФармаКо	150.00
6	Метформин	МедПром	186.00
7	Омепразол	ФармаКо	90.00
8	Симвастатин	МедПром	110.00
9	Лоратадин	ФармаКо	176.00
10	Цетиризин	МедПром	159.00
11	Диклофенак	ФармаКо	130.00
12	Клопидогрел	МедПром	140.00
13	Левотироксин	ФармаКо	160.00
14	Флуконазол	МедПром	170.00
15	Глибенкламид	ФармаКо	145.00
16	Фенобарбитал	МедПром	3865.00
17	Амлодипин	ФармаКо	47.00
18	Вальпроат натрия	МедПром	695.00
19	Карбамазепин	ФармаКо	162.00
20	Фенитоин	МедПром	92.00
21	Лозартан	ФармаКо	117.00
22	Витамир Феррумтабс	Квадрат-С	148.00
23	Дорзокулин	ФармаКо	294.00
24	Зеффикс	ФармаКо	1694.00
25	Ирифрин	ФармаКо	718.00
\.


--
-- Data for Name: patients; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.patients (patient_id, full_name, gender, date_of_birth, contact_number, age) FROM stdin;
1	Петров Артём Сергеевич	М	2003-07-18	+79101730931	21
3	Сидоров Владимир Сергеевич	М	2001-03-24	+79033456789	23
4	Кузнецова Анна Ивановна	Ж	2004-11-01	+79154567890	20
5	Смирнова Мария Сергеевна	Ж	1988-05-10	+79255678901	36
6	Попов Дмитрий Александрович	М	1995-06-17	+79046789012	29
7	Васильева Елена Владимировна	Ж	2003-07-04	+79377890123	21
8	Михайлов Алексей Игоревич	М	1993-08-18	+79248901234	31
9	Новикова Ольга Петровна	Ж	1997-09-19	+79059012345	27
10	Федоров Андрей Викторович	М	1991-10-11	+79130123456	33
11	Морозова Юлия Александровна	Ж	1984-11-25	+79201234567	40
12	Лебедев Игорь Сергеевич	М	1994-09-21	+79062345678	30
14	Козлов Владимир Петрович	М	2005-02-14	+79224567890	19
15	Егорова Татьяна Сергеевна	Ж	1983-05-15	+79155678901	41
16	Николаев Павел Александрович	М	1997-04-12	+79176789012	27
17	Кузьмина Екатерина Владимировна	Ж	1985-05-03	+79997890123	39
18	Орлов Виктор Игоревич	М	2002-01-18	+79008901234	22
19	Белова Светлана Петровна	Ж	2002-07-11	+79199012345	22
20	Григорьев Максим Викторович	М	1999-07-25	+79290123456	25
2	Петров Андрей Владимирович	М	2008-02-13	+79262345678	16
13	Соколова Наталья Ивановна	Ж	2007-09-10	+79693456789	17
\.


--
-- Data for Name: prescriptions; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.prescriptions (prescription_id, patient_id, doctor_id, medicine_id, prescription_date, dosage) FROM stdin;
1	2	3	21	2024-12-16	1 таблетка 3 раза в день
2	4	2	22	2024-12-15	1 таблетка 1 раз в день
4	11	2	22	2024-12-17	1 таблетка 3 раза в день
5	8	4	2	2024-12-17	1 таблетка 2 раза в день
7	20	10	2	2024-12-16	1 таблетка 3 раза в день
8	15	7	24	2024-12-17	1 таблетка 2 раза в день
9	20	2	22	2024-12-17	1 таблетка 1 раз в день
10	8	4	25	2024-12-17	1 таблетка 2 раза в день
3	10	6	23	2024-12-17	1 капля в каждый глаз 2 раза в день
6	18	6	23	2024-12-17	1 капля в каждый глаз 1 раз в день перед сном
\.


--
-- Name: appointments_appointment_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.appointments_appointment_id_seq', 27, true);


--
-- Name: departments_department_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.departments_department_id_seq', 1, false);


--
-- Name: doctors_doctor_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.doctors_doctor_id_seq', 11, true);


--
-- Name: medicalrecords_record_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.medicalrecords_record_id_seq', 20, true);


--
-- Name: medicines_medicine_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.medicines_medicine_id_seq', 25, true);


--
-- Name: patients_patient_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.patients_patient_id_seq', 20, true);


--
-- Name: prescriptions_prescription_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.prescriptions_prescription_id_seq', 10, true);


--
-- Name: appointments appointments_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.appointments
    ADD CONSTRAINT appointments_pkey PRIMARY KEY (appointment_id);


--
-- Name: departments departments_department_name_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.departments
    ADD CONSTRAINT departments_department_name_key UNIQUE (department_name);


--
-- Name: departments departments_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.departments
    ADD CONSTRAINT departments_pkey PRIMARY KEY (department_id);


--
-- Name: doctorautor doctorautor_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.doctorautor
    ADD CONSTRAINT doctorautor_pkey PRIMARY KEY (doctor_id);


--
-- Name: doctors doctors_contact_number_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.doctors
    ADD CONSTRAINT doctors_contact_number_key UNIQUE (contact_number);


--
-- Name: doctors doctors_gmail_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.doctors
    ADD CONSTRAINT doctors_gmail_key UNIQUE (gmail);


--
-- Name: doctors doctors_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.doctors
    ADD CONSTRAINT doctors_pkey PRIMARY KEY (doctor_id);


--
-- Name: medicalrecords medicalrecords_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.medicalrecords
    ADD CONSTRAINT medicalrecords_pkey PRIMARY KEY (record_id);


--
-- Name: medicines medicines_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.medicines
    ADD CONSTRAINT medicines_pkey PRIMARY KEY (medicine_id);


--
-- Name: patients patients_contact_number_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.patients
    ADD CONSTRAINT patients_contact_number_key UNIQUE (contact_number);


--
-- Name: patients patients_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.patients
    ADD CONSTRAINT patients_pkey PRIMARY KEY (patient_id);


--
-- Name: prescriptions prescriptions_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.prescriptions
    ADD CONSTRAINT prescriptions_pkey PRIMARY KEY (prescription_id);


--
-- Name: idx_appointments_appointment_date; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_appointments_appointment_date ON public.appointments USING btree (appointment_date);


--
-- Name: idx_appointments_doctor_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_appointments_doctor_id ON public.appointments USING btree (doctor_id);


--
-- Name: idx_appointments_patient_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_appointments_patient_id ON public.appointments USING btree (patient_id);


--
-- Name: idx_appointments_stat_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_appointments_stat_id ON public.appointments USING btree (appointment_status);


--
-- Name: idx_doctor_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_doctor_id ON public.doctors USING btree (doctor_id);


--
-- Name: idx_doctors_full_name; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_doctors_full_name ON public.doctors USING btree (full_name);


--
-- Name: idx_doctors_specialization; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_doctors_specialization ON public.doctors USING btree (specialization);


--
-- Name: idx_medicines_name; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_medicines_name ON public.medicines USING btree (medicine_name);


--
-- Name: idx_patient_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_patient_id ON public.patients USING btree (patient_id);


--
-- Name: idx_patients_contact_number; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_patients_contact_number ON public.patients USING btree (contact_number);


--
-- Name: idx_patients_full_name; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_patients_full_name ON public.patients USING btree (full_name);


--
-- Name: appointments check_appointment_gender_trigger; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER check_appointment_gender_trigger BEFORE INSERT OR UPDATE ON public.appointments FOR EACH ROW EXECUTE FUNCTION public.check_appointment_gender();


--
-- Name: appointments check_appointment_time_trigger; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER check_appointment_time_trigger BEFORE INSERT OR UPDATE ON public.appointments FOR EACH ROW EXECUTE FUNCTION public.check_appointment_time();


--
-- Name: patients update_age; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER update_age BEFORE INSERT OR UPDATE ON public.patients FOR EACH ROW EXECUTE FUNCTION public.update_patient_age();


--
-- Name: appointments appointments_doctor_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.appointments
    ADD CONSTRAINT appointments_doctor_id_fkey FOREIGN KEY (doctor_id) REFERENCES public.doctors(doctor_id) ON DELETE CASCADE;


--
-- Name: appointments appointments_patient_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.appointments
    ADD CONSTRAINT appointments_patient_id_fkey FOREIGN KEY (patient_id) REFERENCES public.patients(patient_id) ON DELETE CASCADE;


--
-- Name: doctors doctors_department_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.doctors
    ADD CONSTRAINT doctors_department_id_fkey FOREIGN KEY (department_id) REFERENCES public.departments(department_id) ON DELETE SET NULL;


--
-- Name: medicalrecords medicalrecords_doctor_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.medicalrecords
    ADD CONSTRAINT medicalrecords_doctor_id_fkey FOREIGN KEY (doctor_id) REFERENCES public.doctors(doctor_id) ON DELETE CASCADE;


--
-- Name: medicalrecords medicalrecords_patient_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.medicalrecords
    ADD CONSTRAINT medicalrecords_patient_id_fkey FOREIGN KEY (patient_id) REFERENCES public.patients(patient_id) ON DELETE CASCADE;


--
-- Name: prescriptions prescriptions_doctor_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.prescriptions
    ADD CONSTRAINT prescriptions_doctor_id_fkey FOREIGN KEY (doctor_id) REFERENCES public.doctors(doctor_id) ON DELETE CASCADE;


--
-- Name: prescriptions prescriptions_medicine_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.prescriptions
    ADD CONSTRAINT prescriptions_medicine_id_fkey FOREIGN KEY (medicine_id) REFERENCES public.medicines(medicine_id) ON DELETE CASCADE;


--
-- Name: prescriptions prescriptions_patient_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.prescriptions
    ADD CONSTRAINT prescriptions_patient_id_fkey FOREIGN KEY (patient_id) REFERENCES public.patients(patient_id) ON DELETE CASCADE;


--
-- PostgreSQL database dump complete
--

