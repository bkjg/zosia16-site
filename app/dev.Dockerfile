FROM python:3.6

RUN set -x \
    && curl -sL https://deb.nodesource.com/setup_8.x | bash - \
	&& apt-get update \
    && apt-get install --no-install-recommends --no-install-suggests -y nodejs \
    && apt-get autoremove -y \
    && rm -rf /var/lib/apt/lists/* \
    && rm -rf /root/.cache* \
    && rm -rf /tmp/* \
;

RUN npm install -g yarn

ARG DJANGO_ENV=dev
ENV PYTHONUNBUFFERED 1
ENV NODE_PATH=/node_modules
ENV DJANGO_ENV=${DJANGO_ENV}
ENV DJANGO_SETTINGS_MODULE="zosia16.settings.${DJANGO_ENV}"

WORKDIR /app

ADD requirements.txt /app/
RUN pip install -r requirements.txt

ADD package.json /app/
ADD Makefile /app/
ADD webpack.config.js /app/
ADD static /app/static
RUN yarn install
RUN yarn build
RUN cp -R /app/node_modules /node_modules

ADD . /app/

EXPOSE 8000
