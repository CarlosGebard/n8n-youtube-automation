FROM fishaudio/fish-speech:server-cuda

WORKDIR /app

COPY requirements.txt /opt/fish-vast/requirements.txt
RUN pip install --no-cache-dir -r /opt/fish-vast/requirements.txt

COPY contract.py worker.py register_reference.py start.sh /opt/fish-vast/
RUN chmod 0555 /opt/fish-vast/start.sh

ENV FISH_API_PORT=8080 \
    FISH_LOG_FILE=/var/log/fish-speech/server.log

ENTRYPOINT ["/opt/fish-vast/start.sh"]
