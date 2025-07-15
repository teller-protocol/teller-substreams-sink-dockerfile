 # Build stage
FROM golang:1.24-bullseye AS builder




RUN apt-get update && apt-get install -y \
git \
curl \
ca-certificates \
build-essential \
&& rm -rf /var/lib/apt/lists/*

  # Install Rust (needed for cargo commands)
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
ENV PATH="/root/.cargo/bin:${PATH}"

RUN rustup target add wasm32-unknown-unknown



# Install buf CLI
RUN curl -sSL https://github.com/bufbuild/buf/releases/latest/download/buf-Linux-x86_64 -o /usr/local/bin/buf \
    && chmod +x /usr/local/bin/buf

# Install Go proto tools
RUN go install google.golang.org/protobuf/cmd/protoc-gen-go@latest
RUN go install google.golang.org/grpc/cmd/protoc-gen-go-grpc@latest


# Install substreams cli from source
RUN git clone https://github.com/streamingfast/substreams.git /tmp/substreams \
    && cd /tmp/substreams \
    && go install ./cmd/substreams \
    && rm -rf /tmp/substreams



# Clone the teller repository
WORKDIR /build


    
# Verify installations
RUN substreams --version

ARG DSN
ARG SUBSTREAMS_API_TOKEN
ARG EVM_NETWORK_NAME

# Convert to ENV so they persist at runtime too
ENV DSN=${DSN}
ENV SUBSTREAMS_API_TOKEN=${SUBSTREAMS_API_TOKEN}
ENV EVM_NETWORK_NAME=${EVM_NETWORK_NAME}


 
ENV TELLER_GITHUB_REPO=https://github.com/teller-protocol/teller-protocol-v2.git
RUN git clone ${TELLER_GITHUB_REPO} ./teller-protocol-v2
 

WORKDIR /build/teller-protocol-v2/packages/subgraph-substreamed-pool-v1

RUN cargo run --bin exportbuild
RUN make
RUN make build
RUN substreams info substreams.yaml
RUN substreams pack substreams.yaml
RUN make protogen

 # this is failing due to the proto or buf  stuff... 
RUN make pack    
 

# Runtime stage
FROM golang:1.24-bullseye

RUN apt-get update && apt-get install -y ca-certificates && rm -rf /var/lib/apt/lists/*




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
 

# Verify installations
RUN substreams --version && substreams-sink-sql --version


ARG DSN
ENV DSN=${DSN}

# Copy built artifacts from builder stage
COPY --from=builder /build /app
WORKDIR /app/packages/subgraph-substreamed-pool-v1

CMD ["sh", "-c", "substreams-sink-sql setup \"$DSN\" substreams.yaml && substreams-sink-sql run \"$DSN\" substreams.yaml"]

   

   
