FROM node:8

RUN npm install -g json
WORKDIR /usr/src/app

COPY package.json .
COPY package-lock.json .

RUN npm install

COPY . .
RUN chmod +x docker-setup.sh

EXPOSE 8000
CMD ./docker-setup.sh
