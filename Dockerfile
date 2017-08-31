# MG-RAST dockerfiles

FROM	debian
MAINTAINER The MG-RAST team, help@mg-rast.org

ENV DEBIAN_FRONTEND noninteractive
RUN apt-get update -qq && apt-get install -y locales -qq && locale-gen en_US.UTF-8 en_us && dpkg-reconfigure locales && dpkg-reconfigure locales && locale-gen C.UTF-8 && /usr/sbin/update-locale LANG=C.UTF-8
ENV LANG C.UTF-8
ENV LANGUAGE C.UTF-8
ENV LC_ALL C.UTF-8

RUN echo 'DEBIAN_FRONTEND=noninteractive' >> /etc/environment

RUN apt-get update && apt-get install -y \
	make 		\
	python-biopython \
	python-dev \
	python-leveldb \
	perl-modules \
  python-numpy \
	python-pika \
  python-pip \
  python-tk \
	python-scipy \
	python-sphinx \
	unzip \
	wget \
	curl


### install CWL runner and QIIME
RUN pip install --upgrade pip & pip install cwlref-runner qiime 

# copy files into image
COPY mgcmd/* bin/* /usr/local/bin/
