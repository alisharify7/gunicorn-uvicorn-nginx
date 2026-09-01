def app(environ, start_response):
    body = b'{"interface":"wsgi","status":"ok"}'
    start_response(
        "200 OK",
        [
            ("Content-Type", "application/json"),
            ("Content-Length", str(len(body))),
        ],
    )
    return [body]
