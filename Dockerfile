#update with 20-alpine
FROM node:20-alpine AS front-build
COPY ./front /src
WORKDIR /src
RUN npm ci && npm run build -- --configuration production # switch to npm run build

#update with 8-jdk17-alpine
FROM gradle:8-jdk17-alpine AS back-build 
COPY ./back /src
WORKDIR /src
# update
RUN chmod +x gradlew && ./gradlew build 
# add
RUN ls -l build/libs
RUN cp build/libs/*SNAPSHOT.jar build/libs/app.jar 

FROM alpine:3.19 AS front
COPY --from=front-build /src/dist/microcrm/browser /app/front
COPY misc/docker/Caddyfile /app/Caddyfile
RUN apk add caddy
WORKDIR /app
EXPOSE 80
EXPOSE 443
CMD ["/usr/sbin/caddy", "run"]

FROM alpine:3.19 AS back
# use app.jar name
COPY --from=back-build /src/build/libs/app.jar /app/back/app.jar  
# switch to 17
RUN apk add openjdk17-jre-headless 
WORKDIR /app
# switch 4200 to 8080
EXPOSE 8080 
CMD ["java", "-jar", "/app/back/app.jar"]

FROM alpine:3.19 AS standalone
COPY --from=front / /
COPY --from=back / /
COPY misc/docker/supervisor.ini /app/supervisor.ini
RUN apk add supervisor
WORKDIR /app
CMD ["/usr/bin/supervisord", "-c", "/app/supervisor.ini"]