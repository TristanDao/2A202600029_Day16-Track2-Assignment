#!/bin/bash
exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1

echo "Starting setup for TinyLlama on GCP CPU (e2-medium)"

# 1. Install Dependencies
apt-get update
apt-get install -y python3-pip python3-flask curl

# 2. Install Ollama (CPU mode)
curl -fsSL https://ollama.com/install.sh | sh

# 3. Start Ollama and Pull TinyLlama
# Ollama runs as a systemd service by default after installation
systemctl start ollama
sleep 10 # Wait for ollama to start

# Pull TinyLlama
ollama pull tinyllama

# 4. Create a Proxy Script to provide OpenAI-compatible API on port 8000 + Health Check
cat <<'EOF' > /home/ubuntu/proxy_api.py
from flask import Flask, request, Response
import requests
import json

app = Flask(__name__)

OLLAMA_URL = "http://localhost:11434/v1/chat/completions"

@app.route('/v1/chat/completions', methods=['POST'])
def proxy():
    try:
        data = request.get_json()
        data['stream'] = False  # Force disable streaming
        resp = requests.post(OLLAMA_URL, json=data, timeout=120)
        return Response(resp.content, resp.status_code, resp.headers.items())
    except Exception as e:
        return json.dumps({"error": str(e)}), 500

@app.route('/health', methods=['GET'])
def health():
    try:
        requests.get("http://localhost:11434/api/tags")
        return "OK", 200
    except:
        return "Ollama not ready", 503

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8000)
EOF

# Install requests for the proxy
pip3 install requests

# Run the proxy
nohup python3 /home/ubuntu/proxy_api.py > /home/ubuntu/proxy.log 2>&1 &

echo "TinyLlama setup complete and Proxy running on port 8000"
