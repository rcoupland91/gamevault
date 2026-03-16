# 1. Make sure all your changes are committed and pushed to main
git add .
git commit -m "feat: description of what you changed"
git push origin main

# 2. Create and push the tag — this triggers the release workflow
git tag -a v1.0.1 -m "v1.0.1"
git push origin v1.0.1
```
---

**Version numbering guide:**
```
v1.0.0  → first stable release
v1.0.1  → bug fix
v1.1.0  → new feature added
v2.0.0  → major change or breaking change