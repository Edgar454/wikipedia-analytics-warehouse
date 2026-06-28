FROM python:3.13-slim

WORKDIR /app

RUN pip install uv

COPY telemetry/pyproject.toml telemetry/uv.lock ./
ENV UV_PROJECT_ENVIRONMENT="/usr/local/"
RUN uv sync --locked --no-dev

COPY dbt/ dbt/
COPY telemetry/ telemetry/
COPY powerbi_api/ powerbi_api/
COPY scripts/run.sh ./run.sh

RUN chmod +x run.sh

ENTRYPOINT ["./run.sh"]
