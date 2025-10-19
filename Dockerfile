# =============================================================================
# Multi-stage Dockerfile for Terraform tooling
# =============================================================================

# -----------------------------------------------------------------------------
# Stage 1: Builder - Download and install all tools
# -----------------------------------------------------------------------------
FROM debian:bookworm-slim AS builder

ENV DEBIAN_FRONTEND=noninteractive
ENV TERRAFORM_VERSION=1.13.4
ENV TFLINT_VERSION=0.59.1
ENV TFSEC_VERSION=1.28.14
ENV TRIVY_VERSION=0.66.0
ENV TERRAFORM_DOCS_VERSION=0.20.0
ENV GITLEAKS_VERSION=8.21.2

WORKDIR /tmp

# Install dependencies
RUN apt-get update && apt-get install -y \
    curl \
    wget \
    unzip \
    git \
    ca-certificates \
    gnupg \
    software-properties-common \
    && rm -rf /var/lib/apt/lists/*

# Install Terraform
RUN wget -q https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_amd64.zip \
    && unzip terraform_${TERRAFORM_VERSION}_linux_amd64.zip -d /usr/local/bin/ \
    && chmod +x /usr/local/bin/terraform \
    && rm terraform_${TERRAFORM_VERSION}_linux_amd64.zip

# Install tflint
RUN wget -q https://github.com/terraform-linters/tflint/releases/download/v${TFLINT_VERSION}/tflint_linux_amd64.zip \
    && unzip tflint_linux_amd64.zip -d /usr/local/bin/ \
    && chmod +x /usr/local/bin/tflint \
    && rm tflint_linux_amd64.zip

# Install tfsec
RUN wget -q https://github.com/aquasecurity/tfsec/releases/download/v${TFSEC_VERSION}/tfsec_${TFSEC_VERSION}_linux_amd64.tar.gz \
    && tar -xzf tfsec_${TFSEC_VERSION}_linux_amd64.tar.gz -C /usr/local/bin/ \
    && chmod +x /usr/local/bin/tfsec \
    && rm tfsec_${TFSEC_VERSION}_linux_amd64.tar.gz

# Install trivy
RUN wget -q https://github.com/aquasecurity/trivy/releases/download/v${TRIVY_VERSION}/trivy_${TRIVY_VERSION}_Linux-64bit.tar.gz \
    && tar -xzf trivy_${TRIVY_VERSION}_Linux-64bit.tar.gz -C /usr/local/bin/ \
    && chmod +x /usr/local/bin/trivy \
    && rm trivy_${TRIVY_VERSION}_Linux-64bit.tar.gz

# Install terraform-docs
RUN wget -q https://github.com/terraform-docs/terraform-docs/releases/download/v${TERRAFORM_DOCS_VERSION}/terraform-docs-v${TERRAFORM_DOCS_VERSION}-linux-amd64.tar.gz \
    && tar -xzf terraform-docs-v${TERRAFORM_DOCS_VERSION}-linux-amd64.tar.gz -C /usr/local/bin/ \
    && chmod +x /usr/local/bin/terraform-docs \
    && rm terraform-docs-v${TERRAFORM_DOCS_VERSION}-linux-amd64.tar.gz

# Install gitleaks
RUN wget -q https://github.com/gitleaks/gitleaks/releases/download/v${GITLEAKS_VERSION}/gitleaks_${GITLEAKS_VERSION}_linux_x64.tar.gz \
    && tar -xzf gitleaks_${GITLEAKS_VERSION}_linux_x64.tar.gz -C /usr/local/bin/ \
    && chmod +x /usr/local/bin/gitleaks \
    && rm gitleaks_${GITLEAKS_VERSION}_linux_x64.tar.gz

# -----------------------------------------------------------------------------
# Stage 2: Final image - Copy binaries and install runtime deps
# -----------------------------------------------------------------------------
FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

LABEL maintainer="8am-project"
LABEL description="Terraform tooling container with terraform, tflint, tfsec, trivy, checkov, and more"
LABEL version="1.0"

# Install runtime dependencies
RUN apt-get update && apt-get install -y \
    python3 \
    python3-pip \
    git \
    ca-certificates \
    curl \
    jq \
    make \
    graphviz \
    bash \
    && rm -rf /var/lib/apt/lists/*

# Install Python tools via pip (latest versions)
RUN pip3 install --no-cache-dir --upgrade \
    checkov \
    pre-commit

# Copy binaries from builder
COPY --from=builder /usr/local/bin/terraform /usr/local/bin/
COPY --from=builder /usr/local/bin/tflint /usr/local/bin/
COPY --from=builder /usr/local/bin/tfsec /usr/local/bin/
COPY --from=builder /usr/local/bin/trivy /usr/local/bin/
COPY --from=builder /usr/local/bin/terraform-docs /usr/local/bin/
COPY --from=builder /usr/local/bin/gitleaks /usr/local/bin/

# Create workspace
WORKDIR /workspace

# Verify installations and show versions
RUN echo "========================================" && \
    echo "Tool Versions Installed:" && \
    echo "========================================" && \
    echo "Terraform:       $(terraform version -json | jq -r .terraform_version)" && \
    echo "TFLint:          $(tflint --version | head -n1 | awk '{print $3}')" && \
    echo "TFSec:           $(tfsec --version | head -n1 | awk '{print $2}')" && \
    echo "Trivy:           $(trivy --version | head -n1 | awk '{print $2}')" && \
    echo "Terraform-docs:  $(terraform-docs --version | awk '{print $3}')" && \
    echo "Gitleaks:        $(gitleaks version)" && \
    echo "Checkov:         $(checkov --version)" && \
    echo "Pre-commit:      $(pre-commit --version | awk '{print $2}')" && \
    echo "========================================" && \
    echo "✓ All tools installed successfully!"

# Set default shell
SHELL ["/bin/bash", "-c"]

# Default command
CMD ["/bin/bash"]
