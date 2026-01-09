# Stage 1: Build frontend with Node.js
FROM node:20-slim AS frontend-builder

WORKDIR /build

# Copy package files and elm-tooling config
COPY package*.json elm-tooling.json ./

# Install npm dependencies (postinstall will run elm-tooling install)
RUN npm ci

# Copy source files
COPY index.html ./
COPY vite.config.js ./
COPY tailwind.config.js ./
COPY elm.json ./
COPY src/ ./src/
COPY static/ ./static/

# Build frontend
RUN npm run build

# Stage 2: Python runtime
FROM python:3.11-slim

# Set the working directory in the container
WORKDIR /app

# Copy the dependency list
COPY requirements.txt .

# Install any needed packages specified in requirements.txt
RUN pip install --no-cache-dir -r requirements.txt

# Copy the rest of the application's code
COPY . .

# Copy built frontend from builder stage
COPY --from=frontend-builder /build/dist ./dist

# Make port 5001 available to the world outside this container
EXPOSE 5001

# Run app.py when the container launches
CMD ["python", "app.py"]
