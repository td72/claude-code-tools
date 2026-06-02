FROM docker/sandbox-templates:claude-code

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

USER root
RUN apt-get update && apt-get install -y --no-install-recommends \
      build-essential \
      pkg-config \
      libssl-dev \
 && apt-get clean \
 && rm -rf /var/lib/apt/lists/*
USER agent

WORKDIR /workspace

RUN curl https://mise.run | sh

ENV PATH="/home/agent/.local/bin:/home/agent/.local/share/mise/shims:${PATH}"

# Host-mounted worktrees have a different owner UID; allow git to operate on them.
# Also activate mise in interactive shells for UX (e.g. `mise use` reflects immediately).
# Non-interactive shells rely on the shims dir in PATH set above.
# hadolint ignore=SC2016
RUN git config --global safe.directory '*' \
 && echo 'eval "$(~/.local/bin/mise activate bash)"' >> ~/.bashrc
