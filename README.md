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
<img width="319" height="270" alt="Captura de pantalla 2026-09-21 160739" src="https://github.com/user-attachments/assets/6d308a51-5d21-4247-9f92-d4d7fc992147" />

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
<img width="2580" height="3224" alt="20261005_130706" src="https://github.com/user-attachments/assets/2bde62e3-4719-4d2e-b542-27a0a247e080" />

### 3.Implementação do Active Directory e Hierarquia.
Foi implantada a função de **Active Directory Domain Services (AD DS)** e o servidor principal foi configurado como Controlador de Domínio. O cliente Windows 11 foi integrado com sucesso ao ambiente corporativo.
- **Domínio Raiz**: `luminacorp.local`
- **NetBIOS**: `LUMINACORP`
<img width="954" height="698" alt="Captura de pantalla 2026-09-22 173008" src="https://github.com/user-attachments/assets/04f59a75-150c-43fe-9b51-369ab7c1f94b" />

#### Estrutura de Unidades Organizacionais (OUs)
Para garantir uma administração segmentada e preparar a aplicação do Princípio do Privilégio Mínimo, foi projetada a seguinte topologia de OUs, protegidas contra exclusão acidental:
* `LuminaCorp_Departamentos` 
   * `TI`
   * `Finanças`
   * `Vendas`
   * `Recursos Humanos`
<img width="274" height="232" alt="Captura de pantalla 2026-10-05 144509" src="https://github.com/user-attachments/assets/8658a06c-1c84-4591-8887-2bbc1a3fd7f1" />

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
<img width="476" height="347" alt="Captura de pantalla 2026-09-24 144150" src="https://github.com/user-attachments/assets/8f9be417-bfeb-435e-8f83-cef6e46df09b" />

### 6.Auditoria de Segurança (SACL) e Resposta a Incidentes.
Para garantir a rastreabilidade diante de tentativas de acesso não autorizado e cumprir as normativas de proteção de dados, foi implementada uma política de auditoria rigorosa sobre os diretórios departamentais sensíveis.
- **Diretiva de Grupo (GPO)**: A política `GPO_Audit_FSRM` foi implantada na OU de Domain Controllers, habilitando a subcategoria de auditoria avançada `Audit File System` exclusivamente para eventos de falha (Failure).
- **Listas de Controle de Acesso do Sistema (SACL)**: Uma SACL foi configurada no diretório de Finanças para monitorar silenciosamente qualquer tentativa falha de leitura por parte do grupo geral `Domain Users`.
- **Validação Forense (Teste de Intrusão)**: Durante os testes internos, uma identidade não privilegiada (`tsilva` do departamento de TI) tentou acessar o diretório financeiro. O sistema RBAC negou o acesso em nível NTFS corretamente. Simultaneamente, a política de auditoria capturou o incidente gerando o **Event ID 4656** no log de segurança, documentando a identidade do ator, o timestamp e o objeto violado para sua análise forense.
<img width="481" height="305" alt="Captura de pantalla 2026-09-24 150613" src="https://github.com/user-attachments/assets/e06aadab-73c5-4d31-9798-0e9c32b6cbcf" />

### 7.Gerenciamento de Endpoints e Prevenção contra Perda de Dados (DLP).
Foram implementadas diretivas de segurança em nível de máquina e de usuário para fortalecer as estações de trabalho contra vulnerabilidades internas e exfiltração de informações.
- **Bloqueio de Armazenamento Removível (DLP)**: Por meio da política de máquina `GPO_Block_USB`, restringiu-se totalmente a leitura e gravação em dispositivos de armazenamento externo (USB) em todos os computadores do domínio.
<img width="471" height="381" alt="Captura de pantalla 2026-09-30 165032" src="https://github.com/user-attachments/assets/e0a13327-eeae-44d9-bcaf-b05ef4bc3b8b" />

- **Controle de Interface e Padronização**: A política `GPO_Wallpaper_Block` foi implantada para forçar a exibição do papel de parede corporativo, desabilitando simultaneamente o acesso dos usuários ao painel de configurações de personalização do Windows 11.
<img width="480" height="355" alt="Captura de pantalla 2026-09-30 160855" src="https://github.com/user-attachments/assets/44cba559-5af4-41c6-b148-9cd017efec7c" />

### 8.Controle de Acesso Baseado em Tempo (Logon Hours) e Desconexão Forçada da Rede.
Para mitigar o risco de acesso a informações confidenciais fora do horário operacional, foram implementados controles rigorosos de tempo respaldados por diretivas de segurança de rede.
- **Restrição de Horários (Active Directory)**: O atributo `Logon Hours` foi configurado para os colaboradores do departamento de Vendas, permitindo a autenticação exclusivamente de segunda a sexta-feira, entre as 08:00 e as 16:00 horas. Fora desse período, o Controlador de Domínio rejeita qualquer solicitação de Ticket Granting Ticket (TGT) do Kerberos.
- **Enforcement em Nível de Domínio**: A diretiva `Network security: Force logoff when logon hours expire` foi ativada na Default Domain Policy. Isso garante que as sessões de rede SMB sejam encerradas abruptamente caso um usuário permaneça ativo após o seu horário limite, impedindo a evasão da política por meio do uso de sessões prolongadas ou tickets em cache.
<img width="476" height="382" alt="Captura de pantalla 2026-10-05 163222" src="https://github.com/user-attachments/assets/d46c9dca-9fa7-4d8f-902a-fb802fb5c1ac" />

### 9.Políticas de Senhas Granulares (FGPP).
Em conformidade com os princípios de privilégio mínimo e segregação de controles, abandonou-se a dependência exclusiva da Default Domain Policy para o gerenciamento de credenciais, implementando Fine-Grained Password Policies (FGPP) por meio do Active Directory Administrative Center.
- **Segregação de Requisitos (PSO)**: Foi criado o objeto de configuração `FGPP_TI_Estricto` (Precedência: 10) vinculado diretamente ao grupo de segurança global `GG_TI_RW`.
- **Hardening de Identidades Privilegiadas**: Enquanto os usuários padrão mantêm as políticas base do domínio, o departamento de TI é forçado pelo kernel a utilizar senhas com um mínimo de 15 caracteres, rotação obrigatória a cada 60 dias e um histórico de 24 credenciais lembradas para prevenir ataques de reutilização.
- **Validação**: As tentativas de atribuição de senhas com comprimento padrão (ex. 8-12 caracteres) a contas administrativas são bloqueadas automaticamente pelo sistema.
<img width="377" height="265" alt="Captura de pantalla 2026-10-05 170912" src="https://github.com/user-attachments/assets/2ed16eec-9c84-400f-8e9b-8751d88bab0f" />
