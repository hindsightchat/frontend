# requires make & zip installed in PATH
build-windows:
	flutter build windows --release
	cd rpc_hyjacker && go build -o rpc.exe main.go
	move rpc_hyjacker\rpc.exe build\windows\x64\runner\Release\rpc.exe
	cd build\windows\x64\runner\Release && zip -r app.zip *
	if exist app.zip del app.zip
	move build\windows\x64\runner\Release\app.zip .\app.zip
# todo rest, need to add auto updater & installer that bundles app.zip soooon
