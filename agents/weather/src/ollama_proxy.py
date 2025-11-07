"""
HTTP proxy server to intercept and log Ollama API requests.

This proxy sits between LangChain and Ollama, logging all HTTP traffic
to see exactly what's being sent to the LLM.

Usage:
    python src/ollama_proxy.py

Then configure ChatOllama to use: base_url="http://localhost:11435"
"""

import json
import os
from datetime import datetime
from pathlib import Path

import httpx
from fastapi import FastAPI, Request, Response
from fastapi.responses import StreamingResponse

app = FastAPI()

# Ollama backend - respect OLLAMA_HOST environment variable
OLLAMA_HOST = os.getenv("OLLAMA_HOST", "http://localhost:11434")
OLLAMA_BASE_URL = OLLAMA_HOST if OLLAMA_HOST.startswith("http") else f"http://{OLLAMA_HOST}"

# Log directory
LOG_DIR = Path("logs")
LOG_DIR.mkdir(exist_ok=True)


def get_log_file_path() -> Path:
    """Generate log file path with date-based naming."""
    date_str = datetime.now().strftime("%Y-%m-%d")
    return LOG_DIR / f"ollama_proxy_{date_str}.jsonl"


async def log_request_response(
    method: str, path: str, request_body: dict, response_body: dict, status_code: int
):
    """Log the complete request and response."""
    log_entry = {
        "timestamp": datetime.now().isoformat(),
        "method": method,
        "path": path,
        "request": request_body,
        "response": response_body,
        "status_code": status_code,
    }

    log_file = get_log_file_path()
    with open(log_file, "a") as f:
        f.write(json.dumps(log_entry, indent=2, default=str) + "\n")
        f.write("-" * 80 + "\n")  # Separator for readability


@app.api_route("/{path:path}", methods=["GET", "POST", "PUT", "DELETE", "PATCH"])
async def proxy(request: Request, path: str):
    """Proxy all requests to Ollama and log them."""

    # Read request body
    request_body = await request.body()
    request_json = None
    if request_body:
        try:
            request_json = json.loads(request_body)
        except json.JSONDecodeError:
            request_json = {"_raw": request_body.decode(errors="replace")}

    # Print to console for immediate feedback
    print(f"\n{'='*80}")
    print(f"[{datetime.now().isoformat()}] {request.method} /{path}")
    print(f"{'='*80}")
    if request_json:
        print(json.dumps(request_json, indent=2))
    print(f"{'='*80}\n")

    # Forward request to Ollama
    url = f"{OLLAMA_BASE_URL}/{path}"

    async with httpx.AsyncClient(timeout=300.0) as client:
        try:
            response = await client.request(
                method=request.method,
                url=url,
                content=request_body,
                headers={
                    k: v
                    for k, v in request.headers.items()
                    if k.lower() not in ["host", "content-length"]
                },
            )

            # Parse response - handle streaming JSONL format
            response_json = None
            response_content = response.content
            if response_content:
                try:
                    response_json = json.loads(response_content)
                except json.JSONDecodeError:
                    # Try parsing as JSONL (streaming format - one JSON per line)
                    response_text = response_content.decode(errors="replace")
                    if "\n" in response_text and response_text.strip():
                        streaming_chunks = []
                        for line in response_text.strip().split("\n"):
                            if line.strip():
                                try:
                                    streaming_chunks.append(json.loads(line))
                                except json.JSONDecodeError:
                                    streaming_chunks.append({"_parse_error": line})
                        response_json = {
                            "_streaming": True,
                            "chunks": streaming_chunks,
                            "chunk_count": len(streaming_chunks),
                        }
                    else:
                        response_json = {"_raw": response_text}

            # Print response to console
            print(f"\n{'='*80}")
            print(f"RESPONSE: {response.status_code}")
            print(f"{'='*80}")
            if response_json:
                print(json.dumps(response_json, indent=2))
            print(f"{'='*80}\n")

            # Log to file
            await log_request_response(
                method=request.method,
                path=path,
                request_body=request_json,
                response_body=response_json,
                status_code=response.status_code,
            )

            # Return response to client
            return Response(
                content=response_content,
                status_code=response.status_code,
                headers=dict(response.headers),
            )

        except Exception as e:
            error_response = {"error": str(e), "type": type(e).__name__}
            print(f"ERROR: {error_response}")

            await log_request_response(
                method=request.method,
                path=path,
                request_body=request_json,
                response_body=error_response,
                status_code=500,
            )

            return Response(
                content=json.dumps(error_response),
                status_code=500,
            )


if __name__ == "__main__":
    import uvicorn

    print("="*80)
    print("Ollama Proxy Server Starting")
    print("="*80)
    print(f"Proxy listening on: http://localhost:11435")
    print(f"Forwarding to: {OLLAMA_BASE_URL}")
    print(f"Logs will be written to: {LOG_DIR}")
    print("="*80)
    print("\nConfigure ChatOllama with: base_url='http://localhost:11435'")
    print("="*80 + "\n")

    uvicorn.run(app, host="0.0.0.0", port=11435, log_level="warning")
