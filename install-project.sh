#!/bin/bash
set -e

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Get the directory where this script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Target directory is the current working directory
TARGET_DIR="$PWD"

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}📦 Claude Code Project Setup${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "Script location: ${YELLOW}$SCRIPT_DIR${NC}"
echo -e "Target directory: ${YELLOW}$TARGET_DIR${NC}"
echo ""

# Create .claude directory
echo -e "${GREEN}✓${NC} Creating .claude directory..."
mkdir -p "$TARGET_DIR/.claude"

# Copy settings.json
echo -e "${GREEN}✓${NC} Copying settings.json..."
cp "$SCRIPT_DIR/templates/project-settings.json" "$TARGET_DIR/.claude/settings.json"

# Copy hooks directory
echo -e "${GREEN}✓${NC} Copying hooks directory..."
cp -r "$SCRIPT_DIR/hooks" "$TARGET_DIR/.claude/"

# Set executable permissions on hooks
echo -e "${GREEN}✓${NC} Setting executable permissions on hooks..."
chmod +x "$TARGET_DIR/.claude/hooks"/*.sh

# Create skills directory and copy skill-rules.json
echo -e "${GREEN}✓${NC} Creating skills directory and copying skill-rules.json..."
mkdir -p "$TARGET_DIR/.claude/skills"
cp "$SCRIPT_DIR/templates/skill-rules.json" "$TARGET_DIR/.claude/skills/skill-rules.json"

echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}✅ Project setup complete!${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "Files created:"
echo "  • .claude/settings.json"
echo "  • .claude/hooks/ (with executable scripts)"
echo "  • .claude/skills/skill-rules.json"
echo ""
echo "Next steps:"
echo "  1. Customize .claude/skills/skill-rules.json for project-specific skills"
echo "  2. Consider adding .claude/ to your project's .gitignore if configs are personal"
echo "  3. Or commit .claude/ to share configs with your team"
echo ""
