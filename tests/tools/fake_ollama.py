#!/usr/bin/env python3
"""A fake Ollama server with made-up models, for screenshots and manual testing.

Usage: fake_ollama.py [port]   (default 18080, loopback only)

It answers /api/ps, /api/tags, /api/version and POST /api/show. Nothing here
comes from a real machine, so it is safe to put in a README screenshot.
"""
import datetime
import json
import sys
from http.server import BaseHTTPRequestHandler, HTTPServer

now = datetime.datetime.now(datetime.timezone.utc)


def ts(**delta):
    return (now + datetime.timedelta(**delta)).isoformat()


PS = {"models": [
    {"name": "llama3.2:3b", "size": 3400000000, "size_vram": 3400000000,
     "expires_at": ts(minutes=4, seconds=12), "context_length": 4096,
     "details": {"parameter_size": "3.2B", "quantization_level": "Q4_K_M"}},
    {"name": "qwen2.5-coder:14b", "size": 11200000000, "size_vram": 7600000000,
     # Ollama reports "never unloads" as a date centuries away.
     "expires_at": ts(days=365 * 300), "context_length": 16384,
     "details": {"parameter_size": "14.8B", "quantization_level": "Q4_K_M"}}]}

TAGS = {"models": [
    {"name": "llama3.2:3b", "size": 2019393189, "modified_at": ts(days=-3),
     "digest": "a80c4f17acd55265feec403c7aef86be0c25983ab279d83f3bcd3abbcb5b8b72",
     "details": {"family": "llama", "parameter_size": "3.2B", "quantization_level": "Q4_K_M"}},
    {"name": "qwen2.5-coder:14b", "size": 8988110000, "modified_at": ts(days=-12),
     "digest": "9ec8897f747ee3f8e7cd3c5b6ba6a8d8e3d6f0c1b2a39f5d4c7e8a1b0f2d3c4e",
     "details": {"family": "qwen2", "parameter_size": "14.8B", "quantization_level": "Q4_K_M"}},
    {"name": "mistral:7b", "size": 4113301824, "modified_at": ts(days=-40),
     "digest": "f974a74358d62a017b37c6f424fcdf2744ca02926c4f952513ddf474b2fa5091",
     "details": {"family": "llama", "parameter_size": "7.2B", "quantization_level": "Q4_0"}},
    {"name": "nomic-embed-text:latest", "size": 274302450, "modified_at": ts(days=-90),
     "digest": "0a109f422b47e3a30ba2b10eca18548e944e8a23073ee3f3e947efcf3c45e59f",
     "details": {"family": "nomic-bert", "parameter_size": "137M", "quantization_level": "F16"}}]}

SHOW = {
    "license": "MIT License\n\nThis is made-up licence text for a fake model.",
    "parameters": "temperature 0.7\ntop_k 40\nstop \"<|end|>\"",
    "template": "{{ .System }}\n{{ .Prompt }}",
    "capabilities": ["completion", "tools"],
    "modified_at": ts(days=-3),
    "details": {"format": "gguf", "family": "llama", "parameter_size": "3.2B",
                "quantization_level": "Q4_K_M"},
    "model_info": {"general.architecture": "llama", "llama.context_length": 131072,
                   "llama.block_count": 28, "llama.embedding_length": 3072},
}


class Handler(BaseHTTPRequestHandler):
    def log_message(self, *args):
        pass

    def reply(self, body):
        self.send_response(200 if body is not None else 404)
        self.send_header("Content-Type", "application/json")
        self.end_headers()
        self.wfile.write(json.dumps(body or {}).encode())

    def do_GET(self):
        self.reply({"/api/ps": PS, "/api/tags": TAGS,
                    "/api/version": {"version": "0.12.3"}}.get(self.path))

    def do_POST(self):
        self.rfile.read(int(self.headers.get("Content-Length", 0)))
        self.reply(SHOW if self.path == "/api/show" else None)


if __name__ == "__main__":
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 18080
    HTTPServer(("127.0.0.1", port), Handler).serve_forever()
