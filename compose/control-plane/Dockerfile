ARG BASE_IMAGE=ghcr.io/omnigent-ai/omnigent-server@sha256:b211b81fb739a7be9b326603d54511cc1f1e2f91f311b85ac2ea144c85129d56
FROM ${BASE_IMAGE}

COPY requirements-vault.txt /tmp/requirements-vault.txt

# The official server image keeps its runtime in /opt/venv. Install only the
# optional Vault client; requests is already a pinned Omnigent dependency.
RUN /opt/venv/bin/pip install \
      --no-cache-dir \
      --no-deps \
      --require-hashes \
      -r /tmp/requirements-vault.txt \
    && /opt/venv/bin/python -c "import hvac; assert hvac.Client" \
    && rm -f /tmp/requirements-vault.txt

# The upstream server image currently runs as root. The derived image needs
# write access only to its mounted /data paths, which Ansible assigns to this
# stable host/container identity.
RUN groupadd --gid 10001 omnigent \
    && useradd --uid 10001 --gid 10001 --create-home --shell /usr/sbin/nologin omnigent \
    && chown -R 10001:10001 /app /data

USER 10001:10001
