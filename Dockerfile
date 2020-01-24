FROM phpdockerio/php72-cli

RUN apt-get update && apt-get install php7.2-mysql -y

RUN apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*
