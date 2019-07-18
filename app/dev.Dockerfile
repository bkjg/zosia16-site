FROM node:alpine AS node-builder

WORKDIR /code

ADD package.json /code/
ADD webpack.config.js /code/
ADD static /code/static

RUN yarn install
RUN yarn build

# Main image
FROM python:3.6-buster

RUN set -x \
	&& apt-get update \
    && apt-get install --no-install-recommends --no-install-suggests -y gettext \
    && apt-get autoremove -y \
    && rm -rf /var/lib/apt/lists/* \
    && rm -rf /root/.cache* \
    && rm -rf /tmp/* \
;

ARG DJANGO_ENV=dev
ENV PYTHONUNBUFFERED 1
ENV DJANGO_ENV=${DJANGO_ENV}
ENV DJANGO_SETTINGS_MODULE="zosia16.settings.${DJANGO_ENV}"

WORKDIR /app

ADD requirements.txt /app/
RUN pip install -r requirements.txt

COPY --from=node-builder /code/static /code/static

ADD . /app/

EXPOSE 8000
