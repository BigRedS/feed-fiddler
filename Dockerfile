FROM python:3.12-slim

WORKDIR /app

COPY requirements.txt ./
RUN pip install --no-cache-dir -r requirements.txt

COPY feed-fiddler ./
COPY web/generate.py web/icon.png ./web/

# No ENTRYPOINT/CMD: the k8s CronJob sets `command` to run feed-fiddler then
# web/generate.py in sequence, both writing into the mounted output volume.
