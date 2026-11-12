FROM python:3.12-slim
ARG APP_VERSION=dev
ENV APP_VERSION=$APP_VERSION
RUN useradd -m appuser
WORKDIR /srv
COPY app.py .
USER appuser
EXPOSE 8080
HEALTHCHECK CMD python -c "import urllib.request;urllib.request.urlopen('http://localhost:8080/health')"
CMD ["python", "app.py"]
