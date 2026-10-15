FROM fishaudio/fish-speech:server-cuda

WORKDIR /app

USER root
COPY requirements.txt /opt/fish-vast/requirements.txt
RUN apt-get update \
    && apt-get install --yes --no-install-recommends python3.12-venv \
    && rm -rf /var/lib/apt/lists/* \
    && python3 -m venv /opt/fish-vast/venv \
    && /opt/fish-vast/venv/bin/pip install --no-cache-dir -r /opt/fish-vast/requirements.txt \
    && mkdir -p /var/log/fish-speech

COPY contract.py worker.py register_reference.py start.sh /opt/fish-vast/
RUN chmod 0555 /opt/fish-vast/start.sh \
    && chown -R ubuntu:ubuntu /opt/fish-vast /var/log/fish-speech

ENV FISH_API_PORT=8080 \
    FISH_LOG_FILE=/var/log/fish-speech/server.log \
    PATH=/opt/fish-vast/venv/bin:/app/.venv/bin:${PATH}

USER ubuntu
ENTRYPOINT ["/opt/fish-vast/start.sh"]
