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

# Fix permissions for OpenShift (group 0 needs write access)
RUN chown -R 1001:0 /home/runner && chmod -R g=u /home/runner

USER 1001

ENTRYPOINT ["/entrypoint.sh"]
