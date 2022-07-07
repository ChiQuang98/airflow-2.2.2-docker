import os
import socket
import requests


def resolve():
    """
    Resolves Airflow external hostname for accessing logs on a worker
    """
    # Use DNS request for finding out what's our external IP:
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    s.connect(('1.1.1.1', 53))
    external_ip = s.getsockname()[0]
    s.close()
    return external_ip
