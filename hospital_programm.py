import psycopg2
from getpass import getpass
from datetime import date

# Функция для подключения к базе данных
def connect_to_db():
    try:
        connection = psycopg2.connect(
            dbname="Hospital",
            user="postgres",
            password="postgres",
            host="localhost",
            port="5432"
        )
        return connection
    except Exception as e:
        print(f"Ошибка подключения к базе данных: {e}")
        return None

# Функция для аутентификации врача
def authenticate_doctor(connection, login, password):
    try:
        with connection.cursor() as cursor:
            cursor.execute("SELECT doctor_id FROM DoctorLogins WHERE login = %s AND password = %s", (login, password))
            result = cursor.fetchone()
            if result:
                return result[0]
            else:
                return None
    except Exception as e:
        print(f"Ошибка аутентификации: {e}")
        return None

# Функция для получения записей на сегодняшний день
def get_todays_appointments(connection, doctor_id):
    try:
        with connection.cursor() as cursor:
            cursor.execute("""
                SELECT a.appointment_id, a.appointment_date, a.appointment_time, a.appointment_status,
                       p.full_name AS patient_name
                FROM Appointments a
                JOIN Patients p ON a.patient_id = p.patient_id
                WHERE a.doctor_id = %s AND a.appointment_date = %s
            """, (doctor_id, date.today()))
            appointments = cursor.fetchall()
            return appointments
    except Exception as e:
        print(f"Ошибка получения записей: {e}")
        return []

# Основная функция
def main():
    connection = connect_to_db()
    if not connection:
        return

    print("Добро пожаловать в личный кабинет для врачей")
    login = input("Введите логин: ")
    password = getpass("Введите пароль: ")

    doctor_id = authenticate_doctor(connection, login, password)
    if not doctor_id:
        print("Неверный логин или пароль")
        return

    print(f"Добро пожаловать, доктор {doctor_id}!")

    appointments = get_todays_appointments(connection, doctor_id)
    if not appointments:
        print("У вас нет записей на сегодняшний день.")
    else:
        print("Ваши записи на сегодняшний день:")
        for appointment in appointments:
            print(f"ID записи: {appointment[0]}, Дата: {appointment[1]}, Время: {appointment[2]}, Статус: {appointment[3]}, Пациент: {appointment[4]}")

    connection.close()

if __name__ == "__main__":
    main()

