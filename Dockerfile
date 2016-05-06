FROM ubuntu:16.04

MAINTAINER lukess <luke.skywalker.sun@gmail.com>

ENV DEBIAN_FRONTEND noninteractive
ENV TERM xterm-256color
ENV GRAPHITE_VERSION 0.9.15

WORKDIR /opt

# requirements
RUN apt-get update
RUN apt-get install -y --no-install-recommends wget bzip2 vim git ca-certificates python python-dev python-django-tagging nginx uwsgi uwsgi-plugin-python python-twisted-core python-cairo-dev

# dumb-init
RUN wget --no-check-certificate https://github.com/Yelp/dumb-init/releases/download/v1.0.1/dumb-init_1.0.1_amd64.deb
RUN dpkg -i dumb-init_1.0.1_amd64.deb && rm dumb-init_1.0.1_amd64.deb

# Java 8
RUN echo "deb http://ppa.launchpad.net/webupd8team/java/ubuntu xenial main" | tee /etc/apt/sources.list.d/webupd8team-java.list
RUN echo "deb-src http://ppa.launchpad.net/webupd8team/java/ubuntu xenial main" | tee -a /etc/apt/sources.list.d/webupd8team-java.list
RUN apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys EEA14886
RUN apt-get update
RUN echo oracle-java8-installer shared/accepted-oracle-license-v1-1 select true | debconf-set-selections && \
  apt-get install -y oracle-java8-installer
RUN rm -rf /var/cache/oracle-jdk8-installer

# Riemann
RUN wget --no-check-certificate https://aphyr.com/riemann/riemann-0.2.11.tar.bz2
RUN tar jxvf riemann-0.2.11.tar.bz2
RUN rm riemann-0.2.11.tar.bz2
RUN ln -s riemann-0.2.11 riemann
#RUN riemann-0.2.11/bin/riemann riemann-0.2.11/etc/riemann.config

# Grafana
RUN wget --no-check-certificate https://grafanarel.s3.amazonaws.com/builds/grafana-3.0.0-beta61461918338.linux-x64.tar.gz
RUN tar zxvf grafana-3.0.0-beta61461918338.linux-x64.tar.gz
RUN rm grafana-3.0.0-beta61461918338.linux-x64.tar.gz
RUN ln -s grafana-3.0.0-beta61461918338 grafana

# Graphite
WORKDIR /root
RUN wget https://pypi.python.org/packages/ad/30/5ab2298c902ac92fdf649cc07d1b7d491a241c5cac8be84dd84464db7d8b/pytz-2016.4.tar.gz#md5=a3316cf3842ed0375ba5931914239d97
RUN tar -zxvf pytz-2016.4.tar.gz
RUN rm pytz-2016.4.tar.gz
WORKDIR /root/pytz-2016.4
RUN python setup.py install

WORKDIR /root
RUN git clone https://github.com/graphite-project/whisper.git /root/whisper
WORKDIR /root/whisper
RUN git checkout ${GRAPHITE_VERSION}
RUN python setup.py install

RUN git clone https://github.com/graphite-project/carbon.git /root/carbon
WORKDIR /root/carbon
RUN git checkout ${GRAPHITE_VERSION}
RUN python setup.py install

RUN git clone https://github.com/graphite-project/graphite-web.git /root/graphite-web
WORKDIR /root/graphite-web
RUN git checkout ${GRAPHITE_VERSION}
RUN python setup.py install

WORKDIR /opt/graphite/webapp/graphite
RUN python manage.py syncdb --noinput
RUN cp /opt/graphite/conf/carbon.conf.example /opt/graphite/conf/carbon.conf
RUN cp /opt/graphite/conf/storage-schemas.conf.example /opt/graphite/conf/storage-schemas.conf

# Nginx and Uwsgi
ADD nginx/graphite /etc/nginx/sites-available/graphite
ADD uwsgi/graphite.ini /etc/uwsgi/apps-available/graphite.ini
RUN ln -s /etc/nginx/sites-available/graphite /etc/nginx/sites-enabled
RUN ln -s /etc/uwsgi/apps-available/graphite.ini /etc/uwsgi/apps-enabled
RUN chown -R www-data:www-data /opt/graphite/storage

# init
WORKDIR /opt
ADD init/init.sh /usr/bin/init.sh
RUN chmod u+x /usr/bin/init.sh

# clean
RUN rm -rf /var/lib/apt/lists/* && apt-get clean

CMD init.sh
