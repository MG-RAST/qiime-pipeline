# MG-RAST dockerfiles

FROM ubuntu:latest
MAINTAINER The MG-RAST team, help@mg-rast.org

RUN echo 'DEBIAN_FRONTEND=noninteractive' >> /etc/environment
ENV LANG C.UTF-8
ENV LANGUAGE C.UTF-8
ENV LC_ALL C.UTF-8

RUN apt-get -y update && apt-get -y upgrade 
RUN apt-get -y install tzdata

RUN apt-get install -y \
  apt-utils \
	build-essential \
  ea-utils \
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
#RUN pip install --upgrade pip & pip install cwlref-runner qiime 
# Upgrade pip, setuptools and wheel and install cwltool
RUN pip install -U pip setuptools wheel
RUN pip install cwltool qiime


# copy files into image
#COPY mgcmd/* bin/* /usr/local/bin/
