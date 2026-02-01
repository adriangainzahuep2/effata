:: Descargar e instalar MT5
powershell -Command "Invoke-WebRequest -Uri 'https://download.mql5.com/cdn/web/metaquotes.software.corp/mt5/mt5setup.exe' -OutFile mt5setup.exe"
start /wait mt5setup.exe /S

:: Copiar EAs y scripts
xcopy "C:\EAs\*" "C:\Users\Administrator\AppData\Roaming\MetaQuotes\Terminal\*\MQL5\Experts\" /E /Y

:: Iniciar terminal en modo silencioso
start "" "C:\Program Files\MetaTrader 5\terminal64.exe" /config:autotrading