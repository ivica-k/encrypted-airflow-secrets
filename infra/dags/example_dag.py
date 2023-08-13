from airflow import DAG
from datetime import datetime, timedelta
from airflow.operators.python_operator import PythonOperator


default_args = {
    "owner": "ivica",
    "start_date": datetime(2019, 8, 14),
    "retry_delay": timedelta(seconds=60 * 60),
}


def print_connection():
    from airflow.hooks.base_hook import BaseHook

    print(BaseHook.get_connection("db").get_uri())


with DAG(
    "print_connection_dag",
    catchup=False,
    default_args=default_args,
    schedule_interval=None,
) as dag:
    task = PythonOperator(
        task_id="print_connection", python_callable=print_connection, dag=dag
    )
