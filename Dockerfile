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

# skip installing gem documentation
RUN mkdir -p /usr/local/etc \
	&& { \
		echo 'install: --no-document'; \
		echo 'update: --no-document'; \
	} >> /usr/local/etc/gemrc

ENV RUBY_MAJOR 2.6
ENV RUBY_VERSION 2.6.5
ENV RUBY_DOWNLOAD_SHA256 d5d6da717fd48524596f9b78ac5a2eeb9691753da5c06923a6c31190abe01a62

RUN apt-get install -y --no-install-recommends ruby \
	&& rm -rf /var/lib/apt/lists/* \
	&& curl "https://cache.ruby-lang.org/pub/ruby/${RUBY_MAJOR%-rc}/ruby-$RUBY_VERSION.tar.xz" --output ruby.tar.xz \
	&& echo "$RUBY_DOWNLOAD_SHA256 *ruby.tar.xz" | sha256sum -c - \
	\
	&& mkdir -p /usr/src/ruby \
	&& tar -xJf ruby.tar.xz -C /usr/src/ruby --strip-components=1 \
	&& rm ruby.tar.xz \
	\
	&& cd /usr/src/ruby \
	\
# hack in "ENABLE_PATH_CHECK" disabling to suppress:
#   warning: Insecure world writable dir
	&& { \
		echo '#define ENABLE_PATH_CHECK 0'; \
		echo; \
		cat file.c; \
	} > file.c.new \
	&& mv file.c.new file.c \
	\
	&& autoconf \
	&& gnuArch="$(dpkg-architecture --query DEB_BUILD_GNU_TYPE)" \
	&& ./configure \
		--build="$gnuArch" \
		--disable-install-doc \
		--enable-shared \
	&& make -j "$(nproc)" \
	&& make install \
	\
	&& apt-get purge -y --auto-remove ruby \
	&& cd / \
	&& rm -r /usr/src/ruby \
# rough smoke test
	&& ruby --version && gem --version && bundle --version

# install things globally, for great justice
# and don't create ".bundle" in all our apps
ENV GEM_HOME /usr/local/bundle
ENV BUNDLE_PATH="$GEM_HOME" \
	BUNDLE_SILENCE_ROOT_WARNING=1 \
	BUNDLE_APP_CONFIG="$GEM_HOME"
# path recommendation: https://github.com/bundler/bundler/pull/6469#issuecomment-383235438
ENV PATH $GEM_HOME/bin:$BUNDLE_PATH/gems/bin:$PATH
# adjust permissions of a few directories for running "gem install" as an arbitrary user
RUN mkdir -p "$GEM_HOME" && chmod 777 "$GEM_HOME"
# (BUNDLE_PATH = GEM_HOME, no need to mkdir/chown both)


#Install GEM packages
RUN gem install sass && gem install capistrano

CMD ["php", "-v"]
RUN composer --version
RUN node -v
RUN npm -v

USER docker
