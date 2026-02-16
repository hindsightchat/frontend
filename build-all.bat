@echo on
docker build --target export --output ./output .
make windows-build
