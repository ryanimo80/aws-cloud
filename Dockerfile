FROM node:18

WORKDIR /usr/src/app
COPY package*.json .
COPY node-js-app/ .
RUN npm install

EXPOSE 8000

CMD [ "npm", "start" ]
