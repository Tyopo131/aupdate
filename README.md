# aupdate
## About
This is a small shell script meant for automatically downloading CMake projects from GitHub, running CPack, extracting the .deb, then adding it to a reprepro repository.

The script contacts the GitHub API to find what commit a specific tag is attached to. If it's attached to a different commit than when the script last ran, it will clone the repository, check out the tag, build the package, and add it to reprepro.
The default tag is `auto-update-apt-repo` but can be configured. (see below)
## How to use
### Config
- Edit the top lines of the script for global config.
- Place config files in your config directory. (default: `aupdate.d/`)
- Config files should look like:
```
owner="[REPO OWNER]"
name="[REPO NAME]"
```
- Optionally add a `tag=` line to set a custom tag name. 
- Config files are written in **bash syntax**.
## Planned features
- [ ] Multiple architectures
