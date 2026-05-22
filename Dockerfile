FROM docker/sandbox-templates:claude-code

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

USER agent

RUN curl https://mise.run | sh

ENV PATH="/home/agent/.local/bin:/home/agent/.local/share/mise/shims:${PATH}"

# Activate mise in interactive shells for UX (e.g. `mise use` reflects immediately).
# Non-interactive shells rely on the shims dir in PATH set above.
# hadolint ignore=SC2016
RUN echo 'eval "$(~/.local/bin/mise activate bash)"' >> ~/.bashrc
