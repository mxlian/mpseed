#!/usr/bin/env bash

PACKAGES='apache2 git vim'

apt-get update && apt-get install -y $PACKAGES
#if ! [ -L /var/www ]; then
  #rm -rf /var/www
  #ln -fs /vagrant /var/www
#fi
