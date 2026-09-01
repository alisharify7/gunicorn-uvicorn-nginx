#!/usr/bin/env python3

import base64
import hashlib
import os
import socket
import sys


GUID = "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"


def receive_exact(connection, length):
    chunks = []
    remaining = length
    while remaining:
        chunk = connection.recv(remaining)
        if not chunk:
            raise RuntimeError("WebSocket connection closed unexpectedly")
        chunks.append(chunk)
        remaining -= len(chunk)
    return b"".join(chunks)


def receive_headers(connection):
    response = bytearray()
    while b"\r\n\r\n" not in response:
        chunk = connection.recv(4096)
        if not chunk:
            raise RuntimeError("connection closed before the upgrade response")
        response.extend(chunk)
        if len(response) > 64 * 1024:
            raise RuntimeError("upgrade response headers are unexpectedly large")
    return bytes(response)


def send_frame(connection, opcode, payload):
    if len(payload) >= 126:
        raise ValueError("test payload must fit in a short WebSocket frame")

    mask = os.urandom(4)
    masked = bytes(byte ^ mask[index % 4] for index, byte in enumerate(payload))
    connection.sendall(bytes((0x80 | opcode, 0x80 | len(payload))) + mask + masked)


def send_text(connection, text):
    send_frame(connection, 0x01, text.encode("utf-8"))


def receive_frame(connection):
    first, second = receive_exact(connection, 2)
    if not first & 0x80:
        raise RuntimeError("fragmented frames are outside this smoke test")
    opcode = first & 0x0F
    if second & 0x80:
        raise RuntimeError("server-to-client frames must not be masked")

    length = second & 0x7F
    if length == 126:
        length = int.from_bytes(receive_exact(connection, 2), "big")
    elif length == 127:
        length = int.from_bytes(receive_exact(connection, 8), "big")
    return opcode, receive_exact(connection, length)


def receive_text(connection):
    opcode, payload = receive_frame(connection)
    if opcode != 0x01:
        raise RuntimeError(f"expected a text frame, received opcode {opcode}")
    return payload.decode("utf-8")


def main():
    if len(sys.argv) != 3:
        raise SystemExit(f"usage: {sys.argv[0]} HOST PORT")

    host = sys.argv[1]
    port = int(sys.argv[2])
    key = base64.b64encode(os.urandom(16)).decode("ascii")
    expected_accept = base64.b64encode(
        hashlib.sha1((key + GUID).encode("ascii")).digest()
    ).decode("ascii")

    request = (
        "GET /echo HTTP/1.1\r\n"
        f"Host: {host}:{port}\r\n"
        "Connection: Upgrade\r\n"
        "Upgrade: websocket\r\n"
        "Sec-WebSocket-Version: 13\r\n"
        f"Sec-WebSocket-Key: {key}\r\n"
        "\r\n"
    ).encode("ascii")

    with socket.create_connection((host, port), timeout=5) as connection:
        connection.settimeout(5)
        connection.sendall(request)
        raw_headers = receive_headers(connection).decode("iso-8859-1")
        header_lines = raw_headers.split("\r\n")
        status_parts = header_lines[0].split(" ", 2)
        if len(status_parts) < 2 or status_parts[1] != "101":
            raise RuntimeError(f"upgrade failed: {header_lines[0]}")

        headers = {}
        for line in header_lines[1:]:
            if ":" in line:
                name, value = line.split(":", 1)
                headers[name.strip().lower()] = value.strip()
        if headers.get("sec-websocket-accept") != expected_accept:
            raise RuntimeError("invalid Sec-WebSocket-Accept response")
        if headers.get("upgrade", "").lower() != "websocket":
            raise RuntimeError("upgrade response omitted the WebSocket Upgrade header")
        connection_tokens = {
            value.strip().lower()
            for value in headers.get("connection", "").split(",")
        }
        if "upgrade" not in connection_tokens:
            raise RuntimeError("upgrade response omitted Connection: upgrade")

        message = "nginx-websocket-smoke"
        send_text(connection, message)
        echoed = receive_text(connection)
        if echoed != message:
            raise RuntimeError(f"unexpected echoed payload: {echoed!r}")

        opcode, payload = receive_frame(connection)
        if opcode != 0x08:
            raise RuntimeError(f"expected a close frame, received opcode {opcode}")
        close_code = int.from_bytes(payload[:2], "big") if len(payload) >= 2 else None
        if close_code != 1000:
            raise RuntimeError(f"unexpected WebSocket close code: {close_code!r}")
        send_frame(connection, 0x08, (1000).to_bytes(2, "big"))

    print("PASS: WebSocket upgrade, echo, and normal close")


if __name__ == "__main__":
    main()
