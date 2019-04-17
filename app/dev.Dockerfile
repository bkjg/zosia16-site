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

WORKDIR /code

ADD requirements.txt /code/
RUN pip install -r requirements.txt

ADD package.json /code/
ADD Makefile /code/
ADD webpack.config.js /code/
ADD static /code/static
RUN yarn install
RUN yarn build
RUN cp -R /code/node_modules /node_modules

ADD . /code/

EXPOSE 8000
