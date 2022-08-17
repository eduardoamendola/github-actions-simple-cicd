# -------------------------
# Build stage for Database
# -------------------------
FROM alpine:3.16.2 as database

ENV database_VERSION=db-4.8.30.NC
ENV database_PREFIX=/opt/${database_VERSION}

RUN apk --no-cache add \
      autoconf \
      automake \
      build-base \
      libressl

RUN wget https://download.oracle.com/berkeley-db/${database_VERSION}.tar.gz && \
    tar -xzf ${database_VERSION}.tar.gz && \
    sed s/__atomic_compare_exchange/__atomic_compare_exchange_db/g -i ${database_VERSION}/dbinc/atomic.h && \
    mkdir -p ${database_PREFIX} && \
    rm -rf ${database_VERSION}.tar.gz

WORKDIR /${database_VERSION}/build_unix

RUN ../dist/configure --enable-cxx --disable-shared --with-pic --prefix=${database_PREFIX} --build=aarch64-unknown-linux-gnu && \
    make -j4 && \
    make install && \
    rm -rf ${database_PREFIX}/docs

# -----------------------------
# Build stage for Bitcoin Core
# -----------------------------
FROM alpine:3.16.2 as bitcoin-core

ENV BITCOIN_VERSION=0.21.0
ENV BITCOIN_PREFIX=/opt/bitcoin-${BITCOIN_VERSION}
ENV BITCOIN_URL=https://bitcoin.org/bin/bitcoin-core-${BITCOIN_VERSION}/
ENV BITCOIN_ASC_FILE=SHA256SUMS.asc
ENV BITCOIN_FILE=bitcoin-${BITCOIN_VERSION}.tar.gz

COPY --from=database /opt /opt

RUN apk --no-cache add autoconf
RUN apk --no-cache add automake
RUN apk --no-cache add boost-dev
RUN apk --no-cache add build-base
RUN apk --no-cache add chrpath
RUN apk --no-cache add file
RUN apk --no-cache add gnupg
RUN apk --no-cache add libevent-dev
RUN apk --no-cache add libressl
RUN apk --no-cache add libtool
RUN apk --no-cache add linux-headers
RUN apk --no-cache add zeromq-dev

RUN wget "${BITCOIN_URL}/${BITCOIN_ASC_FILE}" && \
    wget "${BITCOIN_URL}/${BITCOIN_FILE}" && \
    # Verifying checksum
    grep ${BITCOIN_FILE} ${BITCOIN_ASC_FILE} | sha256sum -c - && \
    tar -zxvf ${BITCOIN_FILE} && \
    rm -rf ${BITCOIN_FILE} ${BITCOIN_ASC_FILE} 

WORKDIR /bitcoin-${BITCOIN_VERSION}

RUN sed -i '/AC_PREREQ/a\AR_FLAGS=cr' src/univalue/configure.ac
RUN sed -i '/AX_PROG_CC_FOR_BUILD/a\AR_FLAGS=cr' src/secp256k1/configure.ac
RUN sed -i s:sys/fcntl.h:fcntl.h: src/compat.h
RUN ./autogen.sh
RUN ./configure LDFLAGS=-L`ls -d /opt/db*`/lib/ CPPFLAGS=-I`ls -d /opt/db*`/include/ \
    --build=aarch64-unknown-linux-gnu \
    --prefix=${BITCOIN_PREFIX} \
    --mandir=/usr/share/man \
    --disable-tests \
    --disable-bench \
    --disable-ccache \
    --with-gui=no \
    --with-utils \
    --with-libs \
    --with-daemon
RUN make -j4
RUN make install
RUN strip ${BITCOIN_PREFIX}/bin/bitcoin-cli
RUN strip ${BITCOIN_PREFIX}/bin/bitcoin-tx
RUN strip ${BITCOIN_PREFIX}/bin/bitcoind
RUN strip ${BITCOIN_PREFIX}/lib/libbitcoinconsensus.a
RUN strip ${BITCOIN_PREFIX}/lib/libbitcoinconsensus.so.0.0.0

# ----------------------------------------------------
# Build stage for final image with compiled artifacts
# ----------------------------------------------------
FROM alpine:3.16.2 as final-image

LABEL description="Bitcoin 0.21.0 container"
LABEL version="1.0.0"
LABEL author="Eduardo Amendola <eduardoamendola@gmail.com>"
LABEL reference="Based on https://github.com/ruimarinho/docker-bitcoin-core"

ENV BITCOIN_USER=bitcoin
ENV BITCOIN_GROUP=bitcoin
ENV BITCOIN_HOME=/home/bitcoin/
ENV BITCOIN_DATA=${BITCOIN_HOME}.bitcoin
ENV BITCOIN_VERSION=0.21.0
ENV BITCOIN_PREFIX=/opt/bitcoin-${BITCOIN_VERSION}
ENV PATH=${BITCOIN_PREFIX}/bin:$PATH

RUN apk update && apk upgrade 
RUN apk --no-cache add \
      boost-filesystem \
      boost-system \
      boost-thread \
      libevent \
      libzmq \
      su-exec

COPY --from=bitcoin-core /opt /opt

# Creating a normal user & group 
RUN addgroup -S ${BITCOIN_GROUP} && adduser -S ${BITCOIN_USER} -G ${BITCOIN_GROUP} 
# Changing to non-root privilege
USER ${BITCOIN_USER}

EXPOSE 8332 8333 18332 18333 18444

# Running as daemon and printing output to console
ENTRYPOINT ["bitcoind", "-printtoconsole"]

# Healthcheck to monitor the bitcoind daemon
HEALTHCHECK --interval=1m --timeout=15s \
  CMD bitcoin-cli -getinfo || exit 1
