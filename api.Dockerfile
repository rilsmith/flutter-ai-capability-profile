FROM python:3.12-slim

WORKDIR /app

COPY requirements.txt ./
RUN pip install --no-cache-dir -r requirements.txt

COPY server.py init_db.py schema.sql ./

ENV PYTHONUNBUFFERED=1
ENV SERVE_STATIC=false

EXPOSE 5000

CMD ["python3", "server.py"]
