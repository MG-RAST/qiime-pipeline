# MG-RAST dockerfiles

FROM ubuntu:18.04
MAINTAINER The MG-RAST team, help@mg-rast.org
ENV LANG=en_US.utf8 
ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
    build-essential \
    ea-utils \
    git \
    less \
    python-dev \
    python-tk \
    python-pip

### install CWL runner and QIIME
RUN pip install --upgrade pip
RUN pip install cwlref-runner \
                cwltool \
                html5lib \
                numpy 
RUN pip install qiime 

# change global matplotlib config 
# CWL changes $HOME / change to non interactive
RUN sed -i -s "s/TkAgg/Agg/" /usr/local/lib/python2.7/dist-packages/matplotlib/mpl-data/matplotlibrc
# RUN mkdir -p /root/.config/matplotlib
# RUN echo "backend : Agg" > /root/.config/matplotlib/matplotlibrc

# copy files into image
# COPY mgcmd/* bin/* /usr/local/bin/
