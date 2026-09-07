# syntax=docker/dockerfile:1.7

ARG PYTHON_IMAGE=python:3.12-slim-bookworm

FROM ${PYTHON_IMAGE} AS builder

ENV PIP_DISABLE_PIP_VERSION_CHECK=1 \
    PIP_NO_CACHE_DIR=1

WORKDIR /build

COPY requirements.txt ./requirements.txt

RUN python -m pip install \
    --prefix=/install \
    --no-cache-dir \
    -r requirements.txt

FROM ${PYTHON_IMAGE} AS runtime

ARG APPLICATION_VERSION=0.0.0-dev
ARG APPLICATION_COMMIT=local

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    APPLICATION_VERSION=${APPLICATION_VERSION} \
    APPLICATION_COMMIT=${APPLICATION_COMMIT}

LABEL org.opencontainers.image.title="datascientest-django" \
      org.opencontainers.image.description="Django/DRF runtime shared by Gunicorn, Celery Worker and Celery Beat" \
      org.opencontainers.image.source="https://github.com/tawounfouet/dst_sprint-17-auomatisation" \
      org.opencontainers.image.version="${APPLICATION_VERSION}" \
      org.opencontainers.image.revision="${APPLICATION_COMMIT}"

RUN groupadd --gid 10001 app \
    && useradd --uid 10001 --gid 10001 --create-home --home-dir /home/app --shell /bin/false app \
    && mkdir -p /app/staticfiles \
    && chown -R app:app /app /home/app

WORKDIR /app

COPY --from=builder /install /usr/local
COPY --chown=root:root docker/entrypoint.sh /usr/local/bin/docker-entrypoint
RUN chmod 0555 /usr/local/bin/docker-entrypoint
COPY --chown=app:app . /app

USER app

EXPOSE 8000
STOPSIGNAL SIGTERM

ENTRYPOINT ["/usr/local/bin/docker-entrypoint"]
CMD ["gunicorn", "config.wsgi:application", "--config", "docker/gunicorn.conf.py"]
