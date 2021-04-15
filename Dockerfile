FROM amazoncorretto:11
VOLUME /tmp
ADD target/app.jar app.jar
EXPOSE 8080/tcp 8081/tcp
ENTRYPOINT [ "sh", "-c", "java -Djava.security.egd=file:/dev/./urandom -jar /app.jar" ]