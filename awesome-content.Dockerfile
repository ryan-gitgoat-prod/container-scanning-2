FROM node:22.18.0-bullseye

WORKDIR /usr/src/app

RUN npm i aws-sdk@2.1297.0

COPY package.json package-lock.json ./

RUN npm install

RUN echo "Arnica is awesome!!!"

COPY . .

RUN cat /etc/os-release

CMD ["echo", "hello", "Sonk2", "world"]
