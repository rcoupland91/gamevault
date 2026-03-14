git add .
git commit -m "test: trigger deploy"
git tag -a v1.0.1 -m "Test deploy"
git push origin main
git push origin v1.0.1