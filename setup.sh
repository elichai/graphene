#!/bin/bash

set -e

NUM_THREADS=8
DIR=$PWD

# Get sudo password in the beginning
sudo true

# Install required packages
PACKAGES_TO_INSTALL=""
for PACKAGE in build-essential autoconf gawk python-protobuf python-crypto
do
  dpkg -s $PACKAGE > /dev/null || PACKAGES_TO_INSTALL="$PACKAGES_TO_INSTALL $PACKAGE"
done
[[ -z $PACKAGES_TO_INSTALL ]] || sudo apt install $PACKAGES_TO_INSTALL

# Generate signing key
[[ -f $DIR/Pal/src/host/Linux-SGX/signer/enclave-key.pem ]] || (cd $DIR/Pal/src/host/Linux-SGX/signer && openssl genrsa -3 -out enclave-key.pem 3072)

# Make clean
make clean

# Make with debug symbols and SGX support
make -C Pal SGX=1 DEBUG=1
make -C LibOS -j$NUM_THREADS SGX=1 DEBUG=1
# make -C Runtime -j$NUM_THREADS SGX=1 DEBUG=1

cd $DIR/Pal/src/host/Linux-SGX/sgx-driver
make
sudo ./load.sh

sudo sysctl vm.mmap_min_addr=0

cd $DIR/LibOS/shim/test/native
make SGX=1 && make SGX_RUN=1
( [[ -f ./pal_loader ]] && ./pal_loader SGX helloworld ) || true
( [[ -f ./pal ]] && ./pal helloworld ) || true

cd $DIR/LibOS/shim/test/apps/python
sed -i "s/^target =/#target =/g" Makefile
make SGX=1 && make SGX_RUN=1
./python.manifest.sgx scripts/helloworld.py  
