#!/bin/bash
# GameCredits/Chips build script for Ubuntu & Debian 9 v.3 (c) Decker

# Step 1: Build BDB 4.8
COINDAEMON_ROOT=$(pwd)
COINDAEMON_PREFIX="${COINDAEMON_ROOT}/db4"
mkdir -p $COINDAEMON_PREFIX
wget -N 'http://download.oracle.com/berkeley-db/db-4.8.30.NC.tar.gz'
echo '12edc0df75bf9abd7f82f821795bcee50f42cb2e5f76a6a281b85732798364ef db-4.8.30.NC.tar.gz' | sha256sum -c
tar -xzvf db-4.8.30.NC.tar.gz
cd db-4.8.30.NC/build_unix/

../dist/configure -enable-cxx -disable-shared -with-pic -prefix=$COINDAEMON_PREFIX

make -j$(nproc)
make install
cd $COINDAEMON_ROOT

# Step 2: Build OpenSSL (libssl-dev) 1.0.x
version=1.0.2o
mkdir -p openssl_build
wget -qO- http://www.openssl.org/source/openssl-$version.tar.gz | tar xzv
cd openssl-$version
export CFLAGS=-fPIC
./config no-shared --prefix=$COINDAEMON_ROOT/openssl_build
make -j$(nproc)
make install
cd ..

export PKG_CONFIG_PATH="$COINDAEMON_ROOT/openssl_build/pkgconfig"
export CXXFLAGS+=" -I$COINDAEMON_ROOT/openssl_build/include/ -I${COINDAEMON_PREFIX}/include/"
export LDFLAGS+=" -L$COINDAEMON_ROOT/openssl_build/lib -L${COINDAEMON_PREFIX}/lib/ -static"
export LIBS+="-ldl"

# p.s. for Debian added -ldl in LDFLAGS it's enough, but on Ubuntu linker doesn't recognize it, so,
# we moved -ldl to LIBS and added -static to LDFLAGS, because linker on Ubuntu doesn't understan that
# it should link librypto.a statically.
#
# Or we can build OpenSSL 1.0.x as shared (instead of no-shared) and use:
# export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/home/$USER/$COINDAEMON/openssl_build/lib before
# starting coind.

# Step 3: Build Coin daemon
./autogen.sh
./configure --with-gui=no --disable-tests --disable-bench --without-miniupnpc --enable-experimental-asm --enable-static --disable-shared
make -j$(nproc)
