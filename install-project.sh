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

# Create .claude directory structure
echo -e "${GREEN}✓${NC} Creating .claude directory structure..."
mkdir -p "$TARGET_DIR/.claude"
mkdir -p "$TARGET_DIR/.claude/tasks"

# Create symlink to global agents (optional - can be customized per project)
echo -e "${GREEN}✓${NC} Linking to global agents..."
if [ -d "$HOME/.claude/agents" ]; then
    # Remove existing agents (symlink or directory)
    if [ -L "$TARGET_DIR/.claude/agents" ]; then
        echo -e "   Updating existing symlink..."
        rm "$TARGET_DIR/.claude/agents"
    elif [ -d "$TARGET_DIR/.claude/agents" ]; then
        echo -e "${YELLOW}⚠${NC}  .claude/agents exists as directory, replacing with symlink..."
        rm -rf "$TARGET_DIR/.claude/agents"
    fi
    ln -s "$HOME/.claude/agents" "$TARGET_DIR/.claude/agents"
    echo -e "   ✓ Symlinked to global agents"
else
    echo -e "${YELLOW}⚠${NC}  Global agents directory not found at ~/.claude/agents"
    echo -e "   Run 'stow --target=\$HOME/.claude .' from the claude-configs repo first"
fi

echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}✅ Project setup complete!${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "Directories created:"
echo "  • .claude/agents (symlinked to global agents)"
echo "  • .claude/tasks (for task specifications and plans)"
echo ""
echo "Next steps:"
echo "  1. Use /spec:create <task-name> to create a new task in .claude/tasks/"
echo "  2. Consider adding .claude/ to your project's .gitignore if you want to keep task files local"
echo "  3. Or commit .claude/tasks/ to share task specifications with your team"
echo ""
