FROM ubuntu:14.04
MAINTAINER Joshua Samuel <jsamuel@gmail.com>
ENV DEBIAN_FRONTEND noninteractive
ENV HTS_COMMIT master

# Install repos and packages
RUN apt-get update -qq && apt-get -y upgrade

# Install s6-overlay
ENV s6_overlay_version="1.10.0.3"
ADD https://github.com/just-containers/s6-overlay/releases/download/v${s6_overlay_version}/s6-overlay-amd64.tar.gz /tmp/
RUN tar zxf /tmp/s6-overlay-amd64.tar.gz -C / && $_clean
ENV S6_LOGGING="1"
# ENV S6_KILL_GRACETIME="3000"

# Install pipework
ADD https://github.com/jpetazzo/pipework/archive/master.tar.gz /tmp/pipework-master.tar.gz
RUN tar -zxf /tmp/pipework-master.tar.gz -C /tmp && cp /tmp/pipework-master/pipework /sbin/ && $_clean

# Install software and repos
RUN apt-get install -m -y wget git curl make dkms dpkg-dev \
    debconf-utils software-properties-common \
    build-essential hdhomerun-config libhdhomerun-dev debhelper libswscale-dev \
    libavahi-client-dev libavformat-dev libavcodec-dev liburiparser-dev \
    libssl-dev libiconv-hook1 libiconv-hook-dev python bzip2 zlib1g-dev \
    libavutil-dev libavresample-dev libavahi-client3 

# checkout, build, and install tvheadend
RUN git clone https://github.com/tvheadend/tvheadend.git /srv/tvheadend \
  && cd /srv/tvheadend && git checkout ${HTS_COMMIT} && ./configure --enable-libffmpeg_static && make && make install

# Clean up APT and temporary files
RUN rm -r /srv/tvheadend && apt-get purge -qq build-essential pkg-config git
RUN apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Relocate the timezone file
RUN mkdir -p /config/.etc && mv /etc/timezone /config/.etc/ && ln -s /config/.etc/timezone /etc/

# Relocate the locale files
RUN mkdir -p /config/.var/lib/locales/ /config/.usr/lib/ \
 && mv /var/lib/locales/supported.d /config/.var/lib/locales/ \
 && mv /usr/lib/locale /config/.usr/lib/ \
 && ln -s /config/.var/lib/locales/supported.d /var/lib/locales/ \
 && ln -s /config/.usr/lib/locale /usr/lib/

# add a user to run as non root
RUN adduser --disabled-password --gecos '' hts

# Configure the hts user account and it's folders
RUN groupmod -o -g 9981 hts \
 && usermod -o -u 9981 -a -G video -d /config hts \
 && install -o hts -g hts -d /config /recordings
 
# Launch script
ADD entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

VOLUME /config /recordings
EXPOSE 9981 9982
ENTRYPOINT ["/init","/entrypoint.sh","-u","hts","-g","hts","-c","/config"]
