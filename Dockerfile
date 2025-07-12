FROM golang:1.24-bullseye

RUN apt-get update && apt-get install -y \
    git \
    curl \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*
    
  # Install Rust (needed for cargo commands)
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
ENV PATH="/root/.cargo/bin:${PATH}"

# Install substreams cli from source
RUN git clone https://github.com/streamingfast/substreams.git /tmp/substreams \
    && cd /tmp/substreams \
    && go install ./cmd/substreams \
    && rm -rf /tmp/substreams

# Install substreams-sink-sql 
RUN git clone https://github.com/streamingfast/substreams-sink-sql.git /tmp/substreams-sink-sql \
    && cd /tmp/substreams-sink-sql \
    && go install ./cmd/substreams-sink-sql \
    && rm -rf /tmp/substreams-sink-sql

WORKDIR /app


# Verify installations
RUN substreams --version && substreams-sink-sql --version


# Clone the teller repository
ENV TELLER_GITHUB_REPO=https://github.com/teller-protocol/teller-protocol-v2.git
RUN git clone ${TELLER_GITHUB_REPO} .

# Clone the teller repository
# ARG TELLER_GITHUB_REPO
# RUN if [ -z "$TELLER_GITHUB_REPO" ]; then echo "TELLER_GITHUB_REPO build arg is required" && exit 1; fi
# RUN git clone ${TELLER_GITHUB_REPO} .




# Create a startup script
RUN echo '#!/bin/bash\n\
set -e\n\
cd teller-protocol-v2/packages/subgraph-substreamed-pool-v1\n\
echo "Running cargo build..."\n\
cargo run --bin exportbuild\n\
echo "Running make commands..."\n\
make && make build && make pack\n\
echo "Setting up substreams-sink-sql..."\n\
substreams-sink-sql setup "$DSN" substreams.yaml\n\
echo "Starting substreams-sink-sql..."\n\
substreams-sink-sql run "$DSN" substreams.yaml' > /app/start.sh

RUN chmod +x /app/start.sh

# Add healthcheck
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD pgrep substreams-sink-sql || exit 1

# Single CMD that runs all commands in sequence
CMD ["/app/start.sh"]

