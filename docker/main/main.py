"""Dependency-free ASGI application used to verify the base image."""

RESPONSE_BODY = b'{"message":"gunicorn-uvicorn-nginx is running"}'


async def app(scope, receive, send):
    """Serve the HTTP, WebSocket, and lifespan ASGI protocols."""
    if scope["type"] == "lifespan":
        while True:
            message = await receive()
            if message["type"] == "lifespan.startup":
                await send({"type": "lifespan.startup.complete"})
            elif message["type"] == "lifespan.shutdown":
                await send({"type": "lifespan.shutdown.complete"})
                return

    if scope["type"] == "websocket":
        await receive()
        if scope["path"] != "/ws":
            await send({"type": "websocket.close", "code": 1008})
            return
        await send({"type": "websocket.accept"})
        await send(
            {"type": "websocket.send", "text": "gunicorn-uvicorn-nginx is running"}
        )
        await send({"type": "websocket.close", "code": 1000})
        return

    if scope["type"] != "http":
        return

    if scope["path"] != "/":
        await send({"type": "http.response.start", "status": 404, "headers": []})
        await send({"type": "http.response.body", "body": b"Not Found"})
        return

    await send(
        {
            "type": "http.response.start",
            "status": 200,
            "headers": [
                (b"content-type", b"application/json"),
                (b"content-length", str(len(RESPONSE_BODY)).encode("ascii")),
            ],
        }
    )
    await send({"type": "http.response.body", "body": RESPONSE_BODY})
