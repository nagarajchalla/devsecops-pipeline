"""Minimal Flask app used as the target for the DevSecOps pipeline.

Kept deliberately small: the point of this repo is the pipeline,
not the application. It exposes a health endpoint for the DAST
stage to wait on, and one echo endpoint to give ZAP a parameter
to probe.
"""
import os
from flask import Flask, jsonify, request

app = Flask(__name__)


@app.get("/health")
def health():
    return jsonify(status="ok"), 200


@app.get("/")
def index():
    return jsonify(service="devsecops-demo", version=os.getenv("APP_VERSION", "dev")), 200


@app.get("/echo")
def echo():
    # Values are returned as JSON, never interpolated into HTML,
    # so reflected XSS is not reachable here.
    message = request.args.get("message", "")
    return jsonify(message=message[:200]), 200


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8080)
