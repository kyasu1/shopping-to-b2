#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Read version from package.json
echo -e "${YELLOW}Reading version from package.json...${NC}"
VERSION=$(node -p "require('./package.json').version")
REGISTRY="registry.tera.officeiko.co.jp"
IMAGE_NAME="shopping-to-b2"
FULL_IMAGE="${REGISTRY}/${IMAGE_NAME}"

echo -e "${GREEN}Building image: ${FULL_IMAGE}:${VERSION}${NC}"

# Build image
echo -e "${YELLOW}Starting Docker build...${NC}"
docker build -t ${FULL_IMAGE}:${VERSION} .

# Tag with latest
echo -e "${YELLOW}Tagging image as latest...${NC}"
docker tag ${FULL_IMAGE}:${VERSION} ${FULL_IMAGE}:latest

# Push both tags
echo -e "${YELLOW}Pushing ${FULL_IMAGE}:${VERSION}...${NC}"
docker push ${FULL_IMAGE}:${VERSION}

echo -e "${YELLOW}Pushing ${FULL_IMAGE}:latest...${NC}"
docker push ${FULL_IMAGE}:latest

echo -e "${GREEN}✓ Successfully built and pushed:${NC}"
echo -e "  - ${FULL_IMAGE}:${VERSION}"
echo -e "  - ${FULL_IMAGE}:latest"
