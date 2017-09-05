# MG-RAST dockerfiles

FROM ubuntu
MAINTAINER The MG-RAST team, help@mg-rast.org

RUN apt-get update && apt-get install -y \
    build-essential \
    python-dev \
    python-tk \
    python-pip

### install CWL runner and QIIME
RUN pip install --upgrade pip & pip install cwlref-runner numpy qiime 

# copy files into image
COPY mgcmd/* bin/* /usr/local/bin/
