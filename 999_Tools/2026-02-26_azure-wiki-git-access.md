# Accessing Azure Wiki via Git Repository

## Overview

Azure DevOps Wikis are backed by git repositories. You can clone, edit, and push to the wiki directly using git commands, avoiding format mismatches and manual line break fixes when copying content in and out.

## Getting the Clone URL

1. **Navigate to your wiki** in Azure DevOps
2. Click **More actions (...)** → **Clone wiki**
3. Copy the clone URL from the dialog

The URL format is typically: `https://dev.azure.com/<Organization>/<ProjectName>/_git/<WikiName>`

**Note**: The wiki repo name is usually `<ProjectName>.wiki` and won't appear in your normal repo list - it's hidden from the standard Repos dropdown.

## Working with the Wiki Locally

Once you have the URL, you can work with it like any git repository:

```bash
# Clone the wiki
git clone <wiki-clone-url>

# The default branch is 'wikiMain' (not 'main')
cd <ProjectName>.wiki

# Edit files with your preferred editor
# All wiki pages are .md (Markdown) files
# Spaces in filenames should be replaced with hyphens

# Commit and push changes
git add .
git commit -m "Update wiki content"
git push origin wikiMain
```

## Key Benefits

- **Direct file editing**: Edit `.md` files locally with proper formatting preserved
- **Line breaks**: Standard markdown line break rules apply (two spaces + newline, or blank line for paragraphs)
- **No formatting issues**: Work directly with source markdown files
- **Version control**: Full git history and branching capabilities
- **Page ordering**: Use `.order` files to control page sequence
- **Immediate updates**: Changes pushed to the repo appear instantly in the wiki

## File Structure

- Each wiki page is a `.md` (Markdown) file
- Spaces in page titles should be replaced with hyphens in filenames
- Use `.order` files in each folder to control the sequence of pages and subpages
- The root branch is named `wikiMain` (not `main`)

## Authentication

Since January 2025, Azure DevOps removed the "Generate Git Credentials" button. You'll need to use:
- Microsoft Entra ID tokens
- Personal Access Tokens (PAT)
- Or other secure authentication methods

## References

- [Clone and Update Wiki Content Offline - Azure DevOps](https://learn.microsoft.com/en-us/azure/devops/project/wiki/wiki-update-offline?view=azure-devops)
- [How to Edit Your Azure DevOps Wiki as a Git Repository](https://www.benday.com/blog/how-to-edit-your-azure-devops-wiki-as-a-git-repository)
- [Wiki Files, Folder Structure, Git Repo Conventions](https://learn.microsoft.com/en-us/azure/devops/project/wiki/wiki-file-structure?view=azure-devops)
- [Working with your Azure Devops Wiki](https://medium.com/@fredrik_erasmus/working-with-your-azure-devops-wiki-ce55a79b6631)
