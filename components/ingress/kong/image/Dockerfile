FROM kong:latest
USER root
ENV KONG_DATABASE off

RUN apt-get update && apt-get install -y curl

RUN git clone https://github.com/manoelcampos/xml2lua.git /tmp/xml2lua && \
    cd /tmp/xml2lua && \
    luarocks make && \
    rm -rf /tmp/xml2lua

RUN luarocks install lua-resty-openidc
RUN luarocks install kong-oidc

USER kong