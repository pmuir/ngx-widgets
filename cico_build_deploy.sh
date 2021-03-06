#!/bin/bash

# Show command before executing
set -x

# Exit on error
set -e

# We need to disable selinux for now, XXX
/usr/sbin/setenforce 0

# Get all the deps in
yum -y install docker make git
sed -i '/OPTIONS=.*/c\OPTIONS="--selinux-enabled --log-driver=journald --insecure-registry registry.ci.centos.org:5000"' /etc/sysconfig/docker
service docker start

# Build builder image
docker build -t ngx-widgets-builder -f Dockerfile.builder .
mkdir -p dist && docker run --detach=true --name=ngx-widgets-builder -e "API_URL=http://demo.api.almighty.io/api/" -t -v $(pwd)/dist:/dist:Z ngx-widgets-builder

# Build almigty-ui
docker exec ngx-widgets-builder npm install

## Exec functional tests
docker exec ngx-widgets-builder ./run_unit_tests.sh

if [ $? -eq 0 ]; then
  echo 'CICO: unit tests OK'
else
  echo 'CICO: unit tests FAIL'
  exit 1
fi

## Exec functional tests
docker exec ngx-widgets-builder ./run_functional_tests.sh

if [ $? -eq 0 ]; then
  echo 'CICO: functional tests OK'
  docker exec ngx-widgets-builder npm run build
  ## All ok, deploy
  if [ $? -eq 0 ]; then
    echo 'CICO: build OK'
    # Publish to npm
    ## TODO ##
    if [ $? -eq 0 ]; then
      echo 'CICO: module pushed to npmjs.com'
      exit 0
    else
      echo 'CICO: module push to npmjs.com failed'
      exit 2
    fi
  else
    echo 'CICO: app tests Failed'
    exit 1
  fi
else
  echo 'CICO: functional tests FAIL'
  exit 1
fi

