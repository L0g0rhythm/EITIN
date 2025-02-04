# Inventário de TI Automático

Este script PowerShell foi desenvolvido para coletar informações detalhadas do sistema, incluindo especificações do Windows, adaptadores de rede ativos, atualizações recentes, entre outros dados relevantes para a gestão de TI.


## 📋 Funcionalidades

- Coleta de informações do sistema operacional e hardware;
- Listagem de adaptadores de rede ativos com endereços MAC;
- Registro das 10 últimas atualizações do Windows (qualidade, drivers, definições e outras);
- Armazenamento automático dos relatórios na área de trabalho do usuário atual.


## 🚀 Como Usar

1. Clone o repositório ou copie os arquivos para o seu computador:
   ```bash
   git clone https://github.com/seu-usuario/seu-repositorio.git

 2. Execute o arquivo .bat para rodar o script com privilégios de administrador:

run_as_admin.bat


 3. O relatório será gerado automaticamente e salvo na área de trabalho do usuário atual com o nome:

Inventario_ddMMyyyy_HHmmss.txt


📂 Exemplo de Arquivo Gerado

C:\Users\SeuUsuario\Desktop\Inventario_04022025_153045.txt

O arquivo conterá informações como:
 • Nome do computador e usuário;
 • Especificações do Windows (versão, build, data de instalação);
 • Informações de rede (endereços MAC ativos);
 • Histórico das 10 últimas atualizações do Windows.


⚠️ Requisitos
 • Windows com PowerShell habilitado;
 • Permissões de administrador para execução do script.


🔐 Segurança

Este script foi projetado para uso legítimo em ambientes de TI corporativos e pessoais. Não realiza alterações no sistema, apenas coleta informações para fins de inventário.


🤝 Contribuições

Contribuições são bem-vindas! Sinta-se à vontade para abrir issues ou pull requests para melhorias.


📄 Licença

Este projeto está licenciado sob a MIT License.
