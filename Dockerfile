FROM ubuntu:16.04
LABEL Description="Install php7.0"
RUN apt -y -qq update && apt -y -qq install php7.0-gmp php7.0 php7.0-mbstring
