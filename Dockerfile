# Stage 1: Build
FROM eclipse-temurin:17-jdk-alpine AS builder

# Set working directory
WORKDIR /build

# InstallMaven
RUN apk add --no-cache maven

# Copy dependency files first for better layer caching
COPY pom.xml .

# Download dependencies
RUN mvn dependency:go-offline -B

# Copy source code
COPY src ./src

# Build application and rename JAR
RUN mvn clean package -DskipTests -B && mv target/*.jar target/app.jar

# Clean Maven cache
RUN rm -rf ~/.m2

# Stage 2: Runtime
FROM eclipse-temurin:17-jre-alpine

# Metadata labels
LABEL version="1.0.0"
LABEL name="Business_Management_Project"
LABEL group="github.IT22056320"
LABEL java.version="17"
LABEL spring.boot.version="3.1.3"

# Install security updates and monitoring tools
RUN apk update && apk upgrade && apk add --no-cache curl tzdata && rm -rf /var/cache/apk/*

# Create non-root user
RUN addgroup -g 1000 springuser && adduser -D -u 1000 -G springuser springuser

# Create application directories
RUN mkdir -p /app/logs /app/tmp

# Set proper permissions
RUN chown -R springuser:springuser /app

# Set working directory
WORKDIR /app

# Copy JAR from builder stage
COPY --from=builder /build/target/app.jar app.jar

# Change ownership of the JAR file
RUN chown springuser:springuser app.jar

# Switch to non-root user
USER springuser

# Environment variables
ENV TZ=UTC
ENV SPRING_MAIN_LAZY_INITIALIZATION=true
ENV JDBC_URL=jdbc:mysql://localhost:3306/businessproject
ENV DB_USERNAME=
ENV DB_PASSWORD=

# JVM optimization options
ENV JAVA_OPTS="-XX:+UseContainerSupport -XX:MaxRAMPercentage=75.0 -XX:+UseG1GC -XX:+UseStringDeduplication -Djava.security.egd=file:/dev/./urandom -Dspring.profiles.active=prod"

# Expose port
EXPOSE 2330

# Volume for logs
VOLUME ["/app/logs"]

# Health check
HEALTHCHECK --interval=30s --timeout=10s --retries=3 --start-period=60s \
  CMD curl -f http://localhost:2330/ || exit 1

# Entry point with proper signal handling
ENTRYPOINT ["sh", "-c", "exec java $JAVA_OPTS -jar app.jar"]