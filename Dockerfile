FROM nousresearch/hermes-agent:latest
# Install gh CLI
RUN apt-get update && apt-get install -y gh
