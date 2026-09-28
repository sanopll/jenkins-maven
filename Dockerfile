FROM eclipse-temurin:21-jre
WORKDIR /app
COPY target/*.jar app.jar
EXPOSE 8081
HEALTHCHECK --interval=30s --timeout=5s --start-period=30s --retries=3 CMD ["java","-jar","app.jar"]
ENTRYPOINT ["java","-jar","/app/app.jar"]
