# Start with a base image that has curl and jq
FROM alpine:latest AS downloader

# Install necessary tools
RUN apk add --no-cache curl jq

# Set up ARGs for architecture detection
ARG TARGETPLATFORM
ARG BUILDPLATFORM

# Detect architecture and set variables
RUN case "${TARGETPLATFORM}" in \
      "linux/amd64")  ARCH="x64" ;; \
      "linux/arm64")  ARCH="aarch64" ;; \
      *)              ARCH="unknown" ;; \
    esac \
    && echo "ARCH=${ARCH}" > /tmp/arch_env

# Get the latest release tag
RUN LATEST_TAG=$(curl -s https://api.github.com/repos/ltex-plus/ltex-ls-plus/releases/latest | jq -r .tag_name) \
    && echo "LATEST_TAG=${LATEST_TAG}" >> /tmp/arch_env

# Download the correct ltex package
RUN source /tmp/arch_env \
    && if [ "$ARCH" != "unknown" ]; then \
         DOWNLOAD_URL="https://github.com/ltex-plus/ltex-ls-plus/releases/download/${LATEST_TAG}/ltex-ls-plus-${LATEST_TAG}-linux-${ARCH}.tar.gz" \
         && curl -L -o /tmp/ltex.tar.gz ${DOWNLOAD_URL}; \
       else \
         echo "Unsupported architecture: ${ARCH}"; \
         exit 1; \
       fi

FROM mcr.microsoft.com/devcontainers/base:ubuntu-24.04

RUN apt-get update \
    && export DEBIAN_FRONTEND=noninteractive \
    && apt-get -y install --no-install-recommends \
        biber \
        curl \
        default-jdk \
        git \
        git-lfs \
        hunspell \
        hunspell-de-de \
        hunspell-tools \
        latexmk \
        libhunspell-dev \
        lmodern \
        locales \
        make \
        neovim \
        openjdk-21-jdk \
        pandoc \
        procps \
        python3-pip \
        python3-pygments \
        nodejs \
        npm \
        texlive \
        texlive-bibtex-extra \
        texlive-extra-utils \
        texlive-fonts-extra \
        texlive-lang-german \
        texlive-latex-extra \
        texlive-science \
        texlive-xetex \
    && rm -rf /var/lib/apt/lists/*

# ENV JAVA_HOME=/usr/lib/jvm/default-java

# Copy the downloaded package and environment variables
COPY --from=downloader /tmp/ltex.tar.gz /tmp/ltex.tar.gz

# Install necessary tools and ltex
RUN mkdir -p /opt/ltex \
    && tar -xzf /tmp/ltex.tar.gz -C /opt/ltex --strip-components=2 \
    && rm /tmp/ltex.tar.gz

# Set the PATH to include ltex
ENV PATH="/opt/ltex/bin:${PATH}"

# Verify installation
RUN ltex-ls-plus --version
