async def app(scope, receive, send):
    if scope["type"] == "lifespan":
        while True:
            message = await receive()
            if message["type"] == "lifespan.startup":
                await send({"type": "lifespan.startup.complete"})
            elif message["type"] == "lifespan.shutdown":
                await send({"type": "lifespan.shutdown.complete"})
                return

    if scope["type"] == "http":
        body = b'{"status":"websocket fixture ready"}'
        await send(
            {
                "type": "http.response.start",
                "status": 200,
                "headers": [
                    (b"content-type", b"application/json"),
                    (b"content-length", str(len(body)).encode("ascii")),
                ],
            }
        )
        await send({"type": "http.response.body", "body": body})
        return

    if scope["type"] == "websocket":
        message = await receive()
        if message["type"] != "websocket.connect":
            return

        await send({"type": "websocket.accept"})
        message = await receive()
        if message["type"] == "websocket.receive":
            text = message.get("text")
            if text is not None:
                await send({"type": "websocket.send", "text": text})
        await send({"type": "websocket.close", "code": 1000})
