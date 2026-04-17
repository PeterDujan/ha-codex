ARG BUILD_FROM
FROM ${BUILD_FROM}

LABEL maintainer="Liquidice"
LABEL org.opencontainers.image.title="HA Codex"
LABEL org.opencontainers.image.description="Codex CLI with web terminal and Home Assistant integration"
LABEL org.opencontainers.image.source="https://github.com/PeterDujan/ha-codex"
LABEL org.opencontainers.image.licenses="MIT"

ENV \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    TERM=xterm-256color \
    CODEX_HOME=/data/ha-codex/.codex \
    CODEX_CLI_VERSION=0.121.0 \
    HASS_MCP_VERSION=0.1.1 \
    PYMODBUS_VERSION=3.13.0 \
    PYSERIAL_VERSION=3.5 \
    MBPOLL_VERSION=v1.5.4 \
    HA_CLI_VERSION=5.0.0

RUN apk add --no-cache \
    bash \
    curl \
    git \
    github-cli \
    jq \
    nodejs \
    npm \
    openssh-client \
    libstdc++ \
    ncurses \
    vim \
    nano \
    tmux \
    coreutils \
    findutils \
    grep \
    sed \
    gawk \
    ca-certificates \
    openssl \
    ripgrep \
    p7zip \
    socat \
    docker-cli \
    bubblewrap \
    && update-ca-certificates

RUN command -v bwrap >/dev/null && bwrap --version

ARG BUILD_ARCH
RUN case "${BUILD_ARCH}" in \
        amd64) TTYD_ARCH="x86_64" ;; \
        aarch64) TTYD_ARCH="aarch64" ;; \
        armv7|armhf) TTYD_ARCH="armhf" ;; \
        i386) TTYD_ARCH="i686" ;; \
        *) TTYD_ARCH="x86_64" ;; \
    esac && \
    curl -fsSL "https://github.com/tsl0922/ttyd/releases/download/1.7.7/ttyd.${TTYD_ARCH}" -o /usr/bin/ttyd && \
    chmod +x /usr/bin/ttyd

RUN npm install -g "@openai/codex@${CODEX_CLI_VERSION}"

RUN pip3 install --no-cache-dir --break-system-packages \
    "hass-mcp==${HASS_MCP_VERSION}" \
    "pymodbus==${PYMODBUS_VERSION}" \
    "pyserial==${PYSERIAL_VERSION}"

RUN apk add --no-cache --virtual .build-deps \
    build-base \
    cmake \
    libmodbus-dev \
    && git clone --branch "${MBPOLL_VERSION}" --depth 1 https://github.com/epsilonrt/mbpoll.git /tmp/mbpoll \
    && cd /tmp/mbpoll \
    && mkdir build \
    && cd build \
    && cmake .. \
    && make \
    && make install \
    && cd / \
    && rm -rf /tmp/mbpoll \
    && apk del .build-deps \
    && apk add --no-cache libmodbus

RUN case "${BUILD_ARCH}" in \
        amd64) HA_ARCH="amd64" ;; \
        aarch64) HA_ARCH="aarch64" ;; \
        armv7|armhf) HA_ARCH="armhf" ;; \
        i386) HA_ARCH="i386" ;; \
        *) HA_ARCH="amd64" ;; \
    esac && \
    curl -fsSL "https://github.com/home-assistant/cli/releases/download/${HA_CLI_VERSION}/ha_${HA_ARCH}" -o /usr/local/bin/ha && \
    chmod +x /usr/local/bin/ha

RUN mkdir -p \
    /homeassistant \
    /root/.config \
    /root/.local/bin \
    /data/ha-codex

RUN cat > /root/.tmux.conf << 'EOF'
set -g history-limit 20000
set -ga terminal-overrides ',xterm*:smcup@:rmcup@'
set -g mouse on
bind -n WheelUpPane if-shell -F -t = "#{mouse_any_flag}" "send-keys -M" "if -Ft= '#{pane_in_mode}' 'send-keys -M' 'select-pane -t=; copy-mode -e; send-keys -M'"
bind -n WheelDownPane select-pane -t= \; send-keys -M
EOF

RUN cat > /root/.bashrc << 'EOF'
export TERM=xterm-256color
export LANG=C.UTF-8
export CODEX_HOME=/data/ha-codex/.codex
export HA_URL=http://supervisor/core
export HA_TOKEN="${SUPERVISOR_TOKEN:-}"
PS1='\[\033[1;36m\]ha-codex\[\033[0m\]:\[\033[1;34m\]\w\[\033[0m\]\$ '

alias ll='ls -la'
alias c='codex'
alias cc='codex resume --last'
alias cr='codex resume'
alias clogin='codex login --device-auth'
alias hinit='/ha-init'
alias ha-config='cd /homeassistant'
alias ha-logs='cat /homeassistant/home-assistant.log 2>/dev/null || echo "Log not found"'
EOF

RUN echo 'source ~/.bashrc' > /root/.profile

ENV PATH="/root/.local/bin:${PATH}"

WORKDIR /homeassistant

COPY run.sh /usr/local/bin/ha-codex-run
RUN chmod +x /usr/local/bin/ha-codex-run

COPY init-profile.sh /usr/local/bin/ha-codex-init
RUN chmod +x /usr/local/bin/ha-codex-init \
    && ln -sf /usr/local/bin/ha-codex-init /init \
    && ln -sf /usr/local/bin/ha-codex-init /ha-init

COPY write-instructions.sh /usr/local/bin/ha-codex-write-instructions
RUN chmod +x /usr/local/bin/ha-codex-write-instructions

HEALTHCHECK --interval=30s --timeout=10s --start-period=10s --retries=3 \
    CMD curl -sf http://localhost:7681/ || exit 1

ENTRYPOINT []
CMD ["/usr/local/bin/ha-codex-run"]
