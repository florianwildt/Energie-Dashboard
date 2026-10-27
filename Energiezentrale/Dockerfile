FROM python:3.13-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt && useradd --uid 10001 --create-home energy && mkdir /data && chown energy:energy /data
COPY gateway.py .
USER energy
EXPOSE 8787
CMD ["python", "gateway.py", "--config", "/app/config.json", "--data", "/data", "--host", "0.0.0.0"]
