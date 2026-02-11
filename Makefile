
build-windows:
	flutter build windows --release
	cd rpc_hyjacker && go build -o rpc.exe main.go
	mv rpc_hyjacker/rpc.exe  build/windows/x64/runner/Release/
# todo rest, need to add auto updater & installer that bundles app.zip soooon
