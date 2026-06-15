#Dockerfile

# Stage 1: Build the application
FROM node:22-alpine3.22 AS builder
RUN apk update && apk upgrade --no-cache
WORKDIR /app
#Set the working directory inside the container to /app

COPY package*.json ./
# Copy package files first (better caching — only reinstall if packages change)

RUN npm ci

COPY . .
# Copy the rest of the application code into the container

# Stage 2: Production image
FROM node:22-alpine3.22
WORKDIR /app
# Update OS packages to get latest security patches
RUN apk update && apk upgrade --no-cache
COPY --from=builder /app .
# Copy the built application from the builder stage

CMD [ "npm" , "start" ]
# Command to run the application when the container starts# trigger redeploy
# force rebuild Mon 15 Jun 2026 04:36:55 PM CEST
# rebuild Mon 15 Jun 2026 04:40:50 PM CEST
# db cache fix Mon 15 Jun 2026 04:45:31 PM CEST
# pin trivy version Mon 15 Jun 2026 04:49:14 PM CEST
# pin trivy binary Mon 15 Jun 2026 04:50:37 PM CEST
# version param fix Mon 15 Jun 2026 04:52:26 PM CEST
# debug format Mon 15 Jun 2026 04:54:05 PM CEST
# fix indentation Mon 15 Jun 2026 05:02:35 PM CEST
