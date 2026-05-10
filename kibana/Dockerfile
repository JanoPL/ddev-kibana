#ddev-generated
ARG KIBANA_VERSION
FROM kibana:$KIBANA_VERSION

USER root

# dynamic instalation dependency
RUN if command -v apt-get > /dev/null; then \
        apt-get update && apt-get install -y jq && rm -rf /var/lib/apt/lists/*; \
    elif command -v microdnf > /dev/null; then \
        microdnf install -y jq && microdnf clean all; \
    elif command -v dnf > /dev/null; then \
        dnf install -y jq && dnf clean all; \
    else \
        echo "No supported package manager found. Attempting to download the jq binary..."; \
        curl -L https://github.com -o /usr/local/bin/jq && chmod +x /usr/local/bin/jq; \
    fi

# Copy healthcheck.sh to container
RUN mkdir -p /tmp
COPY healthcheck.sh /tmp/healthcheck.sh
RUN chmod +x /tmp/healthcheck.sh

USER kibana
