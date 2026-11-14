# syntax=docker/dockerfile:1
FROM node:24-bookworm-slim@sha256:dc26ae92c9fb15cf6b1d63e20f0944b2efe0f115b20e00be48fb23fceb061c54

ARG CLAUDE_VERSION=2.1.325
ARG CODEX_VERSION=0.169.0
ARG COMMANDCODE_VERSION=1.89.1
ARG HAPPIER_VERSION=0.2.20
ARG PLAYWRIGHT_VERSION=1.65.1
ARG FIRSTMATE_REF=427056c4181c41074ad24f051f79919330df0fa5
ARG GH_AXI_VERSION=0.1.51
ARG CHROME_DEVTOOLS_AXI_VERSION=0.1.46
ARG TASKS_AXI_VERSION=0.2.6
ARG QUOTA_AXI_VERSION=0.1.69
ARG TARGETARCH

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
       bash ca-certificates curl git gh openssh-client python3 python3-venv python3-yaml \
       build-essential pkg-config ripgrep jq tini procps tmux ttyd supervisor nginx unzip sudo \
    && rm -rf /var/lib/apt/lists/*

# Install outside the persistent home, so mounting an empty home hides no tools.
RUN npm install --global --prefix /opt/agents \
       "@anthropic-ai/claude-code@${CLAUDE_VERSION}" \
       "@openai/codex@${CODEX_VERSION}" \
       "command-code@${COMMANDCODE_VERSION}" \
       "@happier-dev/cli@${HAPPIER_VERSION}" \
       "playwright@${PLAYWRIGHT_VERSION}" \
       "gh-axi@${GH_AXI_VERSION}" \
       "chrome-devtools-axi@${CHROME_DEVTOOLS_AXI_VERSION}" \
       "tasks-axi@${TASKS_AXI_VERSION}" \
       "quota-axi@${QUOTA_AXI_VERSION}" \
    && npm cache clean --force

ENV PATH="/home/dobby/.local/bin:/opt/agents/bin:${PATH}" \
    NODE_PATH=/opt/agents/lib/node_modules \
    PLAYWRIGHT_BROWSERS_PATH=/opt/playwright

RUN playwright install --with-deps chromium \
    && chmod -R a+rX /opt/playwright \
    && rm -rf /var/lib/apt/lists/* \
    && claude --version && codex --version && cmd --version && happier --version

# Fetch source only. Do not run upstream bootstrap, hooks or agent sessions at build.
RUN git init /opt/firstmate \
    && git -C /opt/firstmate remote add origin https://github.com/kunchenguid/firstmate.git \
    && git -C /opt/firstmate fetch --depth=1 origin "${FIRSTMATE_REF}" \
    && git -C /opt/firstmate checkout --detach FETCH_HEAD \
    && test "$(git -C /opt/firstmate rev-parse HEAD)" = "${FIRSTMATE_REF}"

COPY --chmod=755 install-firstmate-tools.sh /usr/local/bin/install-firstmate-tools
RUN install-firstmate-tools "${TARGETARCH}" \
    && treehouse --version && no-mistakes --version \
    && gh-axi --version && chrome-devtools-axi --version \
    && tasks-axi --version && quota-axi --version

RUN groupmod --new-name dobby --gid 10000 node \
    && usermod --login dobby --uid 10000 --gid 10000 --home /home/dobby node \
    && mkdir -p /home/dobby /workspace /preview-config \
    && chown 10000:10000 /home/dobby /workspace /preview-config \
    && printf 'dobby ALL=(ALL) NOPASSWD: ALL\n' > /etc/sudoers.d/dobby \
    && chmod 0440 /etc/sudoers.d/dobby \
    && visudo -cf /etc/sudoers.d/dobby

COPY --chmod=755 entrypoint.sh /usr/local/bin/dobby-entrypoint
COPY --chmod=755 happier-start.sh /usr/local/bin/dobby-happier-start
COPY --chmod=755 preview.py /usr/local/bin/dobby-preview
COPY --chmod=755 seed-firstmate.py /usr/local/bin/dobby-seed-firstmate
COPY --chmod=755 firstmate.sh /usr/local/bin/dobby-firstmate
COPY supervisord.conf /etc/dobby-supervisord.conf

ENV HOME=/home/dobby \
    HAPPIER_HOME_DIR=/home/dobby/.happier \
    NPM_CONFIG_PREFIX=/home/dobby/.local \
    TERM=xterm-256color
USER 10000:10000
WORKDIR /workspace
ENTRYPOINT ["/usr/bin/tini", "-g", "--", "/usr/local/bin/dobby-entrypoint"]
