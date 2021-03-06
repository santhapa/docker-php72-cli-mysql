FROM ubuntu:bionic

# Fixes some weird terminal issues such as broken clear / CTRL+L
ENV TERM=linux

# Ensure apt doesn't ask questions when installing stuff
ENV DEBIAN_FRONTEND=noninteractive

# Install Ondrej repos for Ubuntu Bionic, PHP7.2, composer and selected extensions - better selection than
# the distro's packages
RUN apt-get update \
    && apt-get install -y --no-install-recommends gnupg \
    && echo "deb http://ppa.launchpad.net/ondrej/php/ubuntu bionic main" > /etc/apt/sources.list.d/ondrej-php.list \
    && apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 4F4EA0AAE5267A6C \
    && apt-get update \
    && apt-get -y --no-install-recommends install curl ca-certificates unzip \
        git \
        sudo \
        curl \
        php7.2-cli php7.2-curl php7.2-mysql php-apcu php-apcu-bc \
        php7.2-json php7.2-mbstring php7.2-opcache php7.2-readline php7.2-xml php7.2-zip \
    && curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer

RUN apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* /usr/share/doc/*

CMD ["php", "-v"]
RUN composer --version

# |--------------------------------------------------------------------------
# | User
# |--------------------------------------------------------------------------
# |
# | Define a default user with sudo rights.
# |

RUN useradd -ms /bin/bash docker && adduser docker sudo
# Users in the sudoers group can sudo as root without password.
RUN echo '%sudo ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers

# Installs Prestissimo to improve Composer download performance.
USER docker
RUN composer global require hirak/prestissimo \
    && composer clear-cache \
    && rm -rf ~/.composer/cache

USER root
# |--------------------------------------------------------------------------
# | PATH updating
# |--------------------------------------------------------------------------
# |
# | Let's add ./vendor/bin to the PATH (utility function to use Composer bin easily)
# |
ENV PATH="$PATH:./vendor/bin:~/.composer/vendor/bin"
RUN sed -i 's#/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin#/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:./vendor/bin:~/.composer/vendor/bin#g' /etc/sudoers


# Install node js
RUN curl -sL https://deb.nodesource.com/setup_10.x | bash -
RUN apt-get install -y --no-install-recommends nodejs

# |--------------------------------------------------------------------------
# | NodeJS
# |--------------------------------------------------------------------------
# |
# | NodeJS path registration (if we install NodeJS, this is useful).
# |
ENV PATH="$PATH:./node_modules/.bin"
RUN sed -i 's#/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin#/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:./node_modules/.bin#g' /etc/sudoers

RUN mkdir /.npm && chown -R docker. /.npm && chmod 777 -R /.npm

RUN node -v
RUN npm -v

# Install Sass
RUN npm install -g sass

#Install Ruby and Capistrano
RUN apt-get update \
    && apt install -y ruby \
    && gem install capistrano \
    && gem install capistrano-symfony \
    && gem install capistrano-grunt
        
RUN ruby -v
RUN cap -v

# workspace setup
RUN mkdir -p /usr/src/app && chown docker:docker /usr/src/app
WORKDIR /usr/src/app

USER docker
