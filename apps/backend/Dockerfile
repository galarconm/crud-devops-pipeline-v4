#Dockerfile

# Stage 1: Build the application
FROM node:22-alpine3.22 AS builder

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
COPY --from=builder /app .
# Copy the built application from the builder stage

CMD [ "npm" , "start" ]
# Command to run the application when the container starts# trigger redeploy
