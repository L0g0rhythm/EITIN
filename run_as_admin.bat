@echo off
:: Desativa a exibição dos comandos no prompt para tornar a execução mais limpa.
cd /d "%~dp0"
:: Muda o diretório atual para o diretório onde o script está localizado.
:: A opção /d permite que a mudança ocorra entre diferentes unidades, se necessário.
powershell -NoProfile -ExecutionPolicy Bypass -Command "Start-Process PowerShell -ArgumentList '-NoProfile -ExecutionPolicy Bypass -File ""%~dpn0.ps1""' -Verb RunAs"
:: Inicia uma instância do PowerShell com as seguintes opções:
::   -NoProfile: Não carrega o perfil do usuário, garantindo um ambiente limpo.
::   -ExecutionPolicy Bypass: Ignora as restrições de política de execução, permitindo que o script seja executado.
:: O parâmetro -Command executa o comando dentro das aspas.
:: Dentro desse comando, é utilizado o Start-Process para abrir uma nova instância do PowerShell.
::   -ArgumentList: Define os argumentos passados para o novo processo do PowerShell:
::      '-NoProfile -ExecutionPolicy Bypass -File ""%~dpn0.ps1""'
::      Aqui, "%~dpn0.ps1" representa um script PowerShell com o mesmo nome e no mesmo diretório do arquivo batch.
::   -Verb RunAs: Solicita a elevação de privilégios (executa como administrador).
