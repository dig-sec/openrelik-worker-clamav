FROM ubuntu:24.04

RUN echo 'debconf debconf/frontend select Noninteractive' | debconf-set-selections

RUN apt-get update && apt-get install -y --no-install-recommends \
    clamav \
    clamav-freshclam \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Prime the image with the newest available signatures when build network allows it.
RUN freshclam || true

ARG OPENRELIK_PYDEBUG
ENV OPENRELIK_PYDEBUG=${OPENRELIK_PYDEBUG:-0}
ARG OPENRELIK_PYDEBUG_PORT
ENV OPENRELIK_PYDEBUG_PORT=${OPENRELIK_PYDEBUG_PORT:-5678}

WORKDIR /openrelik

COPY --from=ghcr.io/astral-sh/uv:latest /uv /uvx /bin/
COPY pyproject.toml ./

RUN uv sync --no-install-project --no-dev
COPY . ./
RUN uv sync --no-dev

ENV PATH="/openrelik/.venv/bin:$PATH"

CMD ["celery", "--app=src.app", "worker", "--task-events", "--concurrency=4", "--loglevel=INFO", "-Q", "openrelik-worker-clamav"]
