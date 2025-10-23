# pull official base image
FROM python:3.13-slim

# set work directory
WORKDIR /src

# set environment variables
ENV PYTHONDONTWRITEBYTECODE 1
ENV PYTHONUNBUFFERED 1

# copy requirements file
COPY ./requirements.txt /src/requirements.txt

# install dependencies
RUN set -eux \
    && apt-get update \
    && apt-get install -y --no-install-recommends curl \
    && pip install uv \
    && uv pip install --system -r /src/requirements.txt \
    && rm -rf /var/lib/apt/lists/* \
    && rm -rf /root/.cache/pip

# copy project
COPY . /src/
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
