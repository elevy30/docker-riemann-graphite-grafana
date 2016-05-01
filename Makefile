IMAGE=lukess/docker-riemann-graphite-grafana
VERSION=0.1.0

all:

.PHONY: build

.SILENT:

build:
	docker build --rm -t "$(IMAGE):$(VERSION)" .
