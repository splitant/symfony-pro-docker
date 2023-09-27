FROM nginx:1.23

ARG NGINX_SYMFONY_SERVER_NAME

RUN mkdir -p /etc/nginx/templates

COPY conf/nginx.conf /etc/nginx/
COPY templates/* /etc/nginx/templates/
COPY certs/* /etc/nginx/certs/

RUN rm /etc/nginx/conf.d/default.conf

EXPOSE 80
EXPOSE 443

CMD ["nginx", "-g", "daemon off;"]
