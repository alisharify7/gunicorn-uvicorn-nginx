group "default" {
  targets = ["main", "alpine"]
}

target "common" {
  pull = true
}

target "main" {
  inherits = ["common"]
  context  = "docker/main"
  tags     = ["gunicorn-uvicorn-nginx:main-test"]
}

target "alpine" {
  inherits = ["common"]
  context  = "docker/alpine"
  tags     = ["gunicorn-uvicorn-nginx:alpine-test"]
}
