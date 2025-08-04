FROM openjdk:21-jdk-slim

WORKDIR /app

COPY review/.mvn .mvn
COPY review/mvnw .
COPY review/pom.xml .
COPY review/src src

# Copy and build utils project first
COPY utils ./utils
RUN cd utils && ./mvnw clean install

# Now build the main project
RUN ./mvnw clean package


# ADD OTEL Java Agent
ADD https://github.com/open-telemetry/opentelemetry-java-instrumentation/releases/latest/download/opentelemetry-javaagent.jar opentelemetry-javaagent.jar

ENV JAVA_TOOL_OPTIONS="-javaagent:./opentelemetry-javaagent.jar"

RUN mv target/*.jar app.jar

EXPOSE 8080

CMD ["java", "-jar", "app.jar"]