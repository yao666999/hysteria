@echo off

echo 开始更改
netsh interface ipv4 set dns "以太网" static 1.1.1.1  primary
netsh interface ipv4 add dns "以太网" 8.8.8.8
echo 更改完成
ipconfig /flushdns
timeout /t 2 /nobreak >nul
del "%~f0"