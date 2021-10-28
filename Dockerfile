FROM ubuntu:18.04 as builder

RUN apt-get update && apt-get install -y \
    build-essential curl git \
    cmake repo \
    python3 \
    && rm -rf /var/lib/apt/lists/*

RUN mkdir -p /build
WORKDIR /build
RUN curl -O https://godeb.s3.amazonaws.com/godeb-amd64.tar.gz && \
    tar -xvf godeb-amd64.tar.gz && \
    rm godeb-amd64.tar.gz
RUN ./godeb install 1.9.7
RUN git clone https://github.com/couchbase/ns_server.git

RUN update-alternatives --install /usr/bin/python python /usr/bin/python2 1
RUN update-alternatives --install /usr/bin/python python /usr/bin/python3 2
RUN export REPO=$(mktemp /tmp/repo.XXXXXXXXX) && \
    curl -o ${REPO} https://storage.googleapis.com/git-repo-downloads/repo && \
    gpg --keyserver keyserver.ubuntu.com --recv-key 8BB9AD793E8E6153AF0F9A4416530D5E920F5C65 && \
    curl -s https://storage.googleapis.com/git-repo-downloads/repo.asc | gpg --verify - ${REPO} && install -m 755 ${REPO} /usr/local/bin/repo && \
    rm -rf ${REPO}

RUN mkdir -p /source
WORKDIR /source
RUN repo init -u git://github.com/couchbase/manifest -m couchbase-server/mad-hatter/6.6.0.xml
RUN repo sync
ENV GOPATH="/source/ns_server/deps/gocode:/source/godeps"
WORKDIR /source/ns_server/deps/gocode/src
RUN mkdir -p build
RUN for path in gozip vbmap goport godu minify gosecrets; do cd $path && go build && cd .. && mv $path/$path build/; done

FROM couchbase:community-6.6.0

COPY --from=builder /source/ns_server/deps/gocode/src/build/gozip /opt/couchbase/bin/
COPY --from=builder /source/ns_server/deps/gocode/src/build/vbmap /opt/couchbase/bin/
COPY --from=builder /source/ns_server/deps/gocode/src/build/goport /opt/couchbase/bin/
COPY --from=builder /source/ns_server/deps/gocode/src/build/godu /opt/couchbase/bin/priv
COPY --from=builder /source/ns_server/deps/gocode/src/build/minify /opt/couchbase/bin/priv
COPY --from=builder /source/ns_server/deps/gocode/src/build/gosecrets /opt/couchbase/bin/
