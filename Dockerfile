FROM ubuntu:22.04

ARG RUNNER_VERSION=2.333.1
ARG OC_VERSION=4.14

ENV DEBIAN_FRONTEND=noninteractive

# Install dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    ca-certificates \
    jq \
    git \
    tar \
    gzip \
    python3 \
    python3-pip \
    python3-venv \
    nodejs \
    npm \
    build-essential \
    cmake \
    && rm -rf /var/lib/apt/lists/*

# Create non-root runner user (UID 1001 for OpenShift SCC compatibility)
RUN useradd -m -u 1001 -g 0 -s /bin/bash runner

# Install GitHub Actions Runner
WORKDIR /home/runner
RUN curl -fsSL -o runner.tar.gz \
    "https://github.com/actions/runner/releases/download/v${RUNNER_VERSION}/actions-runner-linux-x64-${RUNNER_VERSION}.tar.gz" \
    && tar xzf runner.tar.gz \
    && rm runner.tar.gz \
    && ./bin/installdependencies.sh \
    && rm -rf /var/lib/apt/lists/*

# Install OpenShift oc CLI
RUN curl -fsSL -o oc.tar.gz \
    "https://mirror.openshift.com/pub/openshift-v4/clients/ocp/stable-${OC_VERSION}/openshift-client-linux.tar.gz" \
    && tar xzf oc.tar.gz -C /usr/local/bin oc kubectl \
    && rm oc.tar.gz \
    && chmod +x /usr/local/bin/oc /usr/local/bin/kubectl

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Pre-populate Python 3.11 in the actions tool cache so setup-python finds it locally
ARG PYTHON_VERSION=3.11.15
RUN mkdir -p /home/runner/_work/_tool/Python/${PYTHON_VERSION}/x64 \
    && curl -fsSL -o /tmp/python.tar.gz \
       "https://github.com/actions/python-versions/releases/download/${PYTHON_VERSION}-22631496413/python-${PYTHON_VERSION}-linux-22.04-x64.tar.gz" \
    && tar xzf /tmp/python.tar.gz -C /home/runner/_work/_tool/Python/${PYTHON_VERSION}/x64 --strip-components=1 \
    && rm /tmp/python.tar.gz \
    && touch /home/runner/_work/_tool/Python/${PYTHON_VERSION}/x64.complete

# Install pipx via pip, then install poetry via pipx
ENV PATH="/home/runner/.local/bin:${PATH}"
RUN python3 -m pip install --no-cache-dir pipx \
    && pipx install poetry

# Fix permissions for OpenShift (group 0 needs write access)
RUN chown -R 1001:0 /home/runner && chmod -R g=u /home/runner

USER 1001

ENTRYPOINT ["/entrypoint.sh"]
