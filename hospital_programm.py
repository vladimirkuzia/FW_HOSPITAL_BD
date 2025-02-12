import psycopg2
from getpass import getpass
from datetime import date

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
    
def add_appointment(connection, doctor_id):
    patient_id = int(input("Введите ID пациента: "))
    appointment_date = input("Введите дату записи (YYYY-MM-DD + HH:MM:SS): ")
    print("фзз_вфеу = %s ", appointment_date)
    appointment_status = input("Введите статус записи: ")
    try:
        with connection.cursor() as cursor:
            cursor.execute("CALL add_appointment(%s, %s, %s::TIMESTAMP, %s::TEXT)",
                            (patient_id, doctor_id[0], appointment_date, appointment_status))
            connection.commit()
            print("Запись успешно добавлена.")
    except Exception as e:
        print(f"Ошибка добавления записи: {e}")
    
def authenticate_doctor(connection, login, password):
    try:
        with connection.cursor() as cursor:
            cursor.execute("SELECT da.doctor_id, d.full_name FROM doctorautor da JOIN doctors d ON d.doctor_id = da.doctor_id WHERE login = %s AND password = %s", (login, password))
            result = cursor.fetchall()
            if result:
                return result
            else:
                return None
    except Exception as e:
        print(f"Ошибка аутентификации: {e}")
        return None

def get_todays_appointments(connection, doctor_id):
    try:
        with connection.cursor() as cursor:
            cursor.execute("""
                SELECT a.appointment_id, a.appointment_date, a.appointment_status,
                       p.full_name AS patient_name
                FROM appointments a
                JOIN patients p ON a.patient_id = p.patient_id
                WHERE a.doctor_id = %s AND a.appointment_status = %s
            """, (doctor_id[0], "Запланировано"))
            appointments = cursor.fetchall()
            return appointments
    except Exception as e:
        print(f"Ошибка получения записей: {e}")
        return []  
    
def add_medical_record(connection, doctor_id):
    patient_id = int(input("Введите ID пациента: "))
    record_date = input("Введите дату записи (YYYY-MM-DD): ")
    diagnosis = input("Введите диагноз: ")
    treatment = input("Введите лечение: ")
    try:
        with connection.cursor() as cursor:
            cursor.execute("CALL add_medical_record(%s, %s, %s, %s, %s)",
                            (patient_id, doctor_id[0], record_date, diagnosis, treatment))
            connection.commit()
            print("Медицинская запись успешно добавлена.")
    except Exception as e:
        print(f"Ошибка добавления медицинской записи: {e}")

def add_prescription(connection, doctor_id):
    patient_id = int(input("Введите ID пациента: "))
    medicine_id = int(input("Введите ID лекарства: "))
    prescription_date = input("Введите дату рецепта (YYYY-MM-DD): ")
    dosage = input("Введите дозировку: ")
    try:
        with connection.cursor() as cursor:
            cursor.execute("CALL add_prescription(%s, %s, %s, %s, %s)",
                            (doctor_id, patient_id[0], medicine_id, prescription_date, dosage))
            connection.commit()
            print("Рецепт успешно добавлен.")
    except Exception as e:
        print(f"Ошибка добавления рецепта: {e}")

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
    
    for doctor in doctor_id:
        print(f"Добро пожаловать, ID доктора: {doctor[0]}, Полное_имя: {doctor[1]}")

    while True:
        print("\nМеню:")
        print("1. Просмотреть записи на сегодняшний день")
        print("2. Добавить медицинскую запись")
        print("3. Добавить рецепт")
        print("4. Добавить запись пациента")
        print("5. Выйти")
        choice = input("Выберите опцию: ")

        if choice == '1':
            appointments = get_todays_appointments(connection, doctor_id[0])
            if not appointments:
                print("У вас нет записей на сегодняшний день.")
            else:
                print("Ваши записи на сегодняшний день:")
                for appointment in appointments:
                    print(f"ID записи: {appointment[0]}, Дата: {appointment[1]}, Статус: {appointment[2]}, Пациент: {appointment[3]}")
        elif choice == '2':
            add_medical_record(connection, doctor_id[0])
        elif choice == '3':
            add_prescription(connection, doctor_id[0])
        elif choice == '4':
            add_appointment(connection, doctor_id[0])
        elif choice == '5':
            break
        else:
            print("Неверный выбор. Пожалуйста, попробуйте снова.")

    connection.close()

if __name__ == "__main__":
    main()
