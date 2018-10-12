
docker build -t ubuntu1604:php7 .
docker run -v $(pwd):/app -it --entrypoint /bin/bash ubuntu1604:php7
