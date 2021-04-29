FROM node:12.16.1 as builder
WORKDIR /web/
COPY ./package.json package.json
COPY ./yarn.lock yarn.lock
RUN yarn config set registry http://registry.npm.taobao.org/
RUN yarn 
COPY ./ . 
RUN yarn build

FROM nginx:alpine
COPY ./docker/nginx/default.conf /etc/nginx/conf.d/my.conf
COPY --from=builder /web/dist /usr/share/nginx/html
RUN cat /etc/nginx/nginx.conf
RUN cat /etc/nginx/conf.d/my.conf
RUN ls -al /usr/share/nginx/html
CMD ls -al /usr/share/nginx/html