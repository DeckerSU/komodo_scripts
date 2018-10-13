#!/usr/bin/env bash

imagename='ubuntu1604:php7'
filename="$1"
docker build -t "${imagename}" .
docker run -v $(pwd):/app -it --rm --name komodoscripts  \
  "${imagename}" /bin/bash -c "php /app/${filename}"
