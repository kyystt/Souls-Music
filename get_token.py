import requests
import base64
from dotenv import load_dotenv
import os

load_dotenv()

client_id = os.getenv("CLIENT_ID")
client_secret = os.getenv("CLIENT_SECRET")

url = "https://accounts.spotify.com/api/token"
auth_string = f"{client_id}:{client_secret}"
auth_string_b64 = base64.b64encode(auth_string.encode()).decode()

headers = {
    'Authorization': f'Basic {auth_string_b64}',
    'Content-Type': 'application/x-www-form-urlencoded'
}

data = {
    'grant_type': 'client_credentials'
}

response = requests.post(url, headers=headers, data=data)

if response.status_code == 200:
    token_info = response.json()
    access_token = token_info['access_token']
    print(f"Token: {access_token}")
else:
    print(f"ERRO AO OBTER TOKEN: {response.status_code} - {response.text}")

