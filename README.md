# Inventário de TI com Elevação de Privilégios

Este repositório contém um script PowerShell (.ps1) e um arquivo Batch (.bat) que, em conjunto, automatizam a coleta de informações detalhadas do sistema para um inventário de TI. O objetivo é facilitar o gerenciamento de ativos, garantindo que o relatório seja gerado com privilégios elevados e com saída em português Brasileiro.

---

## 📋 Resumo

- Script PowerShell (run_as_admin.ps1):  
  Coleta dados do sistema, incluindo:
  - Especificações do Windows: Nome, versão, build, data de instalação e última inicialização;
  - Informações de Hardware: CPU, RAM, discos e tipo de equipamento (Desktop ou Notebook);
  - Rede: Status dos adaptadores de rede ativos, endereços MAC (diferenciando interfaces Wi‑Fi e Ethernet) e IP principal;
  - Software e Atualizações: Lista de softwares instalados (excluindo os da Microsoft) e histórico das 10 últimas atualizações do Windows, classificadas em categorias (atualizações de qualidade, drivers, definições e outras);
  - Outros: Informações sobre BIOS, firmware, monitores e dados do Active Directory, quando disponíveis.

- Arquivo Batch (run_as_admin.bat):  
  Atua como “launcher” para iniciar o script PowerShell com elevação de privilégios (Run as Administrator), garantindo acesso completo às informações do sistema.

---

## 🚀 Como Usar

1. Pré-requisitos: 
   - Sistema operacional Windows 8+ ou superior (incluindo Windows Server 2012 ou versões posteriores) com PowerShell habilitado.
   - Permissões administrativas para a execução dos scripts.
   - Política de execução configurada para permitir o uso do parâmetro Bypass.

2. Passos:
   - Clone o repositório ou faça o download dos arquivos:
         git clone https://github.com/seu-usuario/seu-repositorio.git
        - Execute o arquivo Batch (`run_as_admin.bat`) com um duplo clique.  
     Esse arquivo iniciará o script PowerShell com elevação de privilégios.
   - Geração do Relatório:  
     O relatório será automaticamente criado e salvo na Área de Trabalho do usuário atual com o formato:
         Inventario_ddMMyyyy_HHmmss.txt
          Exemplo:
         C:\Users\SeuUsuario\Desktop\Inventario_04022025_153045.txt
     
---

## 📂 Conteúdo do Relatório

O relatório gerado inclui as seguintes seções:

- Cabeçalho: Título com data/hora da geração.
- [IDENTIFICAÇÃO]: Nome do computador e lista de usuários ativos (excluindo contas padrão e desabilitadas).
- [SISTEMA OPERACIONAL]: Nome, versão e arquitetura do sistema.
- [ESPECIFICAÇÕES DO WINDOWS]: Dados do Windows (produto, edição, build, data de instalação e última inicialização).
- [TIPO DE EQUIPAMENTO]: Identificação se o dispositivo é Desktop ou Notebook.
- [PROCESSADOR]: Modelo, número de núcleos e velocidade máxima.
- [MEMÓRIA RAM]: Lista dos módulos instalados com detalhes (fabricante, capacidade, velocidade e tipo).
- [ARMAZENAMENTO]: Informações dos discos físicos (tipo, serial) e relatório de espaço dos volumes.
- [REDE]: Informações detalhadas dos adaptadores de rede ativos, separando Wi‑Fi e Ethernet, além do IP principal.
- [SOFTWARES INSTALADOS]: Lista de aplicativos instalados (excluindo os da Microsoft).
- [MAC]: Dados do produto (modelo, fabricante, UUID, ID do produto e Service Tag para sistemas Dell).
- [BIOS & FIRMWARE]: Versões da BIOS, data de lançamento e informações do chassi.
- [MONITORES]: Dados dos monitores conectados via WMI, com decodificação de arrays de bytes.
- [ATUALIZAÇÕES DO WINDOWS]: Histórico das 10 últimas atualizações instaladas, classificadas por categorias (atualizações de qualidade, drivers, definições ou outras).
- [ACTIVE DIRECTORY]: Se disponível, coleta o DistinguishedName do computador no AD.

---

## ⚠️ Requisitos

- Sistema Operacional: Windows 8+ ou superior (incluindo Windows Server 2012 ou versões posteriores).
- PowerShell: Versão com suporte à execução de scripts e ao parâmetro -ExecutionPolicy Bypass.
- Permissões Administrativas: Necessárias para acessar todas as informações do sistema.

---

## 🔐 Segurança

Este projeto foi desenvolvido para uso legítimo em ambientes de TI corporativos e pessoais.
