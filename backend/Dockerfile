# TaskInspect backend image (task 8.8).
#
#   docker build -t taskinspect-backend backend
#   docker run -p 8080:8080 -e DB_HOST=... -e DB_PASSWORD=... -e JWT_SECRET=... taskinspect-backend
#
# Settings come from environment variables (see .env.example); the image
# contains no secrets. Health check: GET /actuator/health.

# --- Build: compile and package the application (tests run in CI) ---
FROM eclipse-temurin:25-jdk AS build
WORKDIR /workspace
COPY gradlew settings.gradle.kts build.gradle.kts ./
COPY gradle gradle
# Download Gradle and the dependencies first, so this layer is cached
# until the build files change.
RUN ./gradlew --no-daemon dependencies > /dev/null
COPY config config
COPY src src
RUN ./gradlew --no-daemon bootJar \
    && cp build/libs/*.jar app.jar \
    && java -Djarmode=tools -jar app.jar extract --layers --launcher --destination extracted

# --- Run: a small JRE image with the application in layers ---
FROM eclipse-temurin:25-jre-alpine
RUN addgroup -S taskinspect && adduser -S -G taskinspect taskinspect
WORKDIR /app
# Least changing layers first, so a code change only replaces the last one.
# The files stay owned by root: the application can read but not change them.
COPY --from=build /workspace/extracted/dependencies/ ./
COPY --from=build /workspace/extracted/spring-boot-loader/ ./
COPY --from=build /workspace/extracted/snapshot-dependencies/ ./
COPY --from=build /workspace/extracted/application/ ./
# Evidence files with STORAGE_TYPE=local (the default) go to ./data/evidence;
# mount a volume there to keep them. In production STORAGE_TYPE=s3.
RUN mkdir -p data/evidence && chown -R taskinspect:taskinspect data
VOLUME /app/data
USER taskinspect
ENV SPRING_PROFILES_ACTIVE=prod
EXPOSE 8080
ENTRYPOINT ["java", "-XX:MaxRAMPercentage=75", "org.springframework.boot.loader.launch.JarLauncher"]
