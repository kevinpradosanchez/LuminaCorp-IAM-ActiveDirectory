# **Projeto LuminaCorp:** Arquitetura IAM e Active Directory

## 🏢 Sobre a Empresa
A LuminaCorp é uma empresa simulada. Este projeto documenta a criação do zero de sua infraestrutura de identidade, utilizando o Windows Server 2022 Standard Evaluation e clientes Windows 11 Enterprise.

## 🎯 Objetivos do Projeto
* Implementação do Active Directory Domain Services (AD DS).
* Implementação de Controle de Acesso Baseado em Funções (RBAC) para 4 departamentos: TI, Finanças, Vendas e Recursos Humanos.
* Aplicação do Princípio do Menor Privilégio (PoLP).
* Automação da criação de usuários.

## 🖥️ Arquitetura do Laboratório
### 1. Troubleshooting e Otimização de Recursos.
Para adequar o laboratório às restrições de hardware do hypervisor físico (8 GB de RAM no total), foi implementada uma estratégia de limitação de recursos, alocando apenas 2 GB de RAM para cada máquina virtual. Visto que o Windows 11 Enterprise exige nativamente um mínimo de 4 GB de RAM e hardware TPM 2.0, aplicou-se um "Bypass" durante o Ambiente de Pré-Instalação do Windows (WinPE):
* Acessou-se o console via **Shift + F10** durante o OOBE.
* Foram injetadas chaves no registro **(HKEY_LOCAL_MACHINE\SYSTEM\Setup\LabConfig)**, criando os valores DWORD **BypassRAMCheck**, **BypassTPMCheck** e **BypassSecureBootCheck** definidos com o valor **1**.
* Resultado: Instalação bem-sucedida e operacional, priorizando os recursos de rede e Active Directory em detrimento do desempenho gráfico do cliente.

### 2. Configuração de Rede e Máquinas Virtuais.
Para garantir um ambiente controlado, foi criada uma rede virtual isolada (Internal Network) denominada `LuminaCorp-Net`. Ambas as máquinas virtuais estão conectadas exclusivamente a este segmento.
**Detalhes dos Nós:**
* **LUMINA-DC01 (Domain Controller)**
  * SO: Windows Server 2022 Standard (Inglês)
  * IP Estático: 192.168.10.10
  * Máscara de Sub-rede: 255.255.255.0
  * DNS Preferencial: 127.0.0.1 (Loopback local)

* **LUMINA-CLI01 (Client Workstation)**
  * SO: Windows 11 Enterprise (Português do Brasil)
  * IP Estático: 192.168.10.20
  * Máscara de Sub-rede: 255.255.255.0
  * DNS Preferencial: 192.168.10.10 (Aponta para o Domain Controller)

### 3.Implementação do Active Directory e Hierarquia.
Foi implantada a função de **Active Directory Domain Services (AD DS)** e o servidor principal foi configurado como Controlador de Domínio. O cliente Windows 11 foi integrado com sucesso ao ambiente corporativo.
- **Domínio Raiz**: `luminacorp.local`
- **NetBIOS**: `LUMINACORP`

#### Estrutura de Unidades Organizacionais (OUs)
Para garantir uma administração segmentada e preparar a aplicação do Princípio do Privilégio Mínimo, foi projetada a seguinte topologia de OUs, protegidas contra exclusão acidental:
* `LuminaCorp_Departamentos` 
   * `TI`
   * `Finanças`
   * `Vendas`
   * `Recursos Humanos`

### 4.Automação de Identidades e RBAC.
Para evitar o trabalho manual e reduzir erros humanos no processo de Joiner, foi utilizado um script em PowerShell (`CriarUsuarios.ps1`) para importar 32 colaboradores distribuídos nos quatro departamentos a partir de um arquivo CSV.

### Controle de Acesso Baseado em Funções (RBAC)
Foram criados Grupos de Segurança Globais dentro de cada Unidade Organizacional para gerenciar as permissões dos usuários nos futuros servidores de arquivos.
- `GG_TI_RW`
- `GG_Financas_RW`
- `GG_Vendas_RW`
- `GG_RH_RW`

As identidades não recebem permissões diretas; o acesso é concedido estritamente por meio de sua associação a esses grupos, em conformidade com os padrões de segurança corporativos.

### 5.Servidor de Arquivos, GPO e Princípio do Privilégio Mínimo.
Foi configurado um servidor de arquivos centralizado, implementando o Princípio do Privilégio Mínimo (PoLP) em nível de permissões NTFS.
- **Compartilhamento de Rede**: O grupo "Everyone" foi removido das permissões de Share, restringindo o acesso exclusivamente a "Domain Users".
- **Permissões NTFS (Isolamento de Dados)**: A herança foi desabilitada nas pastas departamentais. Apenas os membros do grupo de segurança correspondente (ex. GG_Financas_RW) possuem permissões de modificação sobre seu respectivo diretório.
- **Automação da Experiência do Usuário**: Foi criada a Diretiva de Grupo GPO_Unidades_Rede vinculada à OU raiz de departamentos, a qual mapeia automaticamente a unidade de rede S: (\\LUMINA-DC01\LuminaCorp_Dados) no momento do logon de qualquer colaborador.

### 6.Auditoria de Segurança (SACL) e Resposta a Incidentes.
Para garantir a rastreabilidade diante de tentativas de acesso não autorizado e cumprir as normativas de proteção de dados, foi implementada uma política de auditoria rigorosa sobre os diretórios departamentais sensíveis.
- **Diretiva de Grupo (GPO)**: A política `GPO_Audit_FSRM` foi implantada na OU de Domain Controllers, habilitando a subcategoria de auditoria avançada `Audit File System` exclusivamente para eventos de falha (Failure).
- **Listas de Controle de Acesso do Sistema (SACL)**: Uma SACL foi configurada no diretório de Finanças para monitorar silenciosamente qualquer tentativa falha de leitura por parte do grupo geral `Domain Users`.
- **Validação Forense (Teste de Intrusão)**: Durante os testes internos, uma identidade não privilegiada (`tsilva` do departamento de TI) tentou acessar o diretório financeiro. O sistema RBAC negou o acesso em nível NTFS corretamente. Simultaneamente, a política de auditoria capturou o incidente gerando o **Event ID 4656** no log de segurança, documentando a identidade do ator, o timestamp e o objeto violado para sua análise forense.

### 7.Gerenciamento de Endpoints e Restrições de Acesso (GPOs).
Para proteger os dispositivos finais e prevenir a exfiltração de dados, foram aplicados controles em nível de máquina e de usuário:
- **Prevenção contra Perda de Dados (DLP)**: Foi implementada a diretiva `GPO_Block_USB` vinculada aos computadores do domínio, desabilitando completamente o acesso de leitura/gravação a dispositivos de armazenamento removíveis.
- **Padronização de Interface**: Por meio da `GPO_Desktop_Standard`, o papel de parede corporativo foi centralizado, impedindo modificações por parte do usuário.
- **Controle de Acesso Baseado em Tempo**: O horário de logon do departamento de Finanças foi restrito exclusivamente ao horário comercial (`segunda a sexta, das 08:00 às 18:00`), mitigando o risco de acesso a dados sensíveis fora do horário operacional. A equipe de TI mantém acesso `24/7`.
