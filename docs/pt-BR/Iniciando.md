<center>
   <img src="../../.github/assets/logo.png" width="40%" style="margin-bottom:1rem" />

   # Hytale Docker

   Uma configuração de containerização Docker para executar um servidor de Hytale. Este projeto fornece uma configuração completa do Docker Compose com um processo de build automatizado para baixar e executar o servidor Hytale.
</center>

## Visão Geral

Este projeto containeriza o servidor Hytale usando Docker, facilitando o deploy e gerenciamento do servidor com configuração consistente. Inclui:

- Download e instalação automática do servidor Hytale
- Configuração do Docker Compose para orquestração fácil
- Opções de servidor configuráveis através de variáveis de ambiente
- Montagem de volumes para armazenamento persistente de dados
- Funcionalidade de backup automatizado

### Imagem Pré-construída

Uma imagem Docker pré-construída está disponível no GitHub Container Registry:

- **Imagem**: `ghcr.io/machinastudios/hytale-docker`
- **Uso**: Você pode usar esta imagem diretamente sem construir você mesmo

## Pré-requisitos

- Docker Engine (versão 20.10 ou posterior)
- Docker Compose (versão 1.29 ou posterior)

## Início Rápido

### Opção 1: Usando Imagem Pré-construída (Recomendado)

1. Baixe a imagem pré-construída:

```bash
docker pull ghcr.io/machinastudios/hytale-docker
```

2. Crie um arquivo `docker-compose.yml` (veja seção de Configuração) ou use Docker diretamente:

```bash
docker run -d \
  --name hytale \
  -p 5520:5520/udp \
  -v ./backups:/hytale/backups \
  -v ./mods:/hytale/mods \
  -v ./logs:/hytale/logs \
  -v ./universe:/hytale/universe \
  ghcr.io/machinastudios/hytale-docker
```

### Opção 2: Construir a partir do Código Fonte

1. Clone ou baixe este repositório
2. Inicie o servidor:

```bash
docker-compose up -d
```

3. O servidor baixará automaticamente os arquivos do servidor Hytale na primeira construção

### Verificando Logs do Servidor

```bash
# Usando Docker Compose
docker-compose logs -f hytale

# Usando Docker diretamente
docker logs -f hytale
```

## Configuração

### Variáveis de Ambiente

O servidor pode ser configurado usando variáveis de ambiente em `docker-compose.yml`:

#### `SERVER_ASSETS_ZIP`
- **Descrição**: URL ou caminho de arquivo local para um arquivo ZIP contendo assets do servidor
- **Padrão**: Vazio (assets são extraídos automaticamente pelo Hytale se não especificado)
- **Formato**: Pode ser uma URL (ex: `https://example.com/assets.zip`) ou um caminho de arquivo local (ex: `/hytale/assets.zip`)
- **Exemplos**: 
  - URL: `https://example.com/assets.zip`
  - Arquivo local: `/hytale/custom-assets.zip`
- **Uso**: 
  - **Se não definido**: O Hytale extrairá e usará automaticamente os assets padrão (nenhuma ação necessária)
  - **Se definido como caminho de arquivo local** (arquivo existe), o servidor usará diretamente
  - **Se definido como URL**, o servidor baixará o arquivo ZIP de assets antes de usar
- **Nota**: Defina esta variável apenas se precisar usar assets personalizados. Os assets padrão do Hytale são incluídos automaticamente.

#### `SERVER_ACCEPT_EARLY_PLUGINS`
- **Descrição**: Habilita carregamento antecipado de plugins (aceita plugins antes de serem totalmente validados)
- **Padrão**: `true`
- **Uso**: Defina qualquer valor não vazio para habilitar aceitação antecipada de plugins

#### `SERVER_BIND`
- **Descrição**: Endereço e porta de binding do servidor
- **Padrão**: `0.0.0.0:5520`
- **Formato**: `IP:PORTA` ou `0.0.0.0:PORTA`
- **Uso**: Controla em qual interface de rede e porta o servidor escuta

#### `SERVER_BACKUP_DIR`
- **Descrição**: Diretório onde os backups do servidor serão armazenados
- **Padrão**: `/hytale/backups`
- **Uso**: Deve ser definido para que a funcionalidade de backup funcione. O diretório será criado automaticamente

#### `SERVER_BACKUP_INTERVAL`
- **Descrição**: Frequência de backup em minutos
- **Padrão**: `10`
- **Uso**: Usado apenas se `SERVER_BACKUP_DIR` estiver definido. Define com que frequência os backups são criados

#### `SERVER_MIN_RAM`
- **Descrição**: Alocação mínima de RAM para o processo Java
- **Padrão**: Vazio (usa padrão JVM)
- **Formato**: Tamanho de memória com unidade (ex: `2G`, `4096M`, `512M`)
- **Exemplos**: `2G`, `4096M`, `512M`
- **Uso**: Define o tamanho inicial do heap. Isso é convertido para o argumento JVM `-Xms`
- **Nota**: Use isso para configuração fácil de memória ao invés de `JAVA_JVM_ARGS`

#### `SERVER_MAX_RAM`
- **Descrição**: Alocação máxima de RAM para o processo Java
- **Padrão**: Vazio (usa padrão JVM)
- **Formato**: Tamanho de memória com unidade (ex: `4G`, `8192M`, `1024M`)
- **Exemplos**: `4G`, `8192M`, `1024M`
- **Uso**: Define o tamanho máximo do heap. Isso é convertido para o argumento JVM `-Xmx`
- **Nota**: Use isso para configuração fácil de memória ao invés de `JAVA_JVM_ARGS`

#### `JAVA_JVM_ARGS`
- **Descrição**: Argumentos JVM adicionais para passar ao processo Java
- **Padrão**: Vazio (usa configurações padrão JVM)
- **Formato**: Argumentos JVM separados por espaço (ex: `-XX:+UseG1GC -XX:MaxGCPauseMillis=200`)
- **Exemplos**:
  - Ajuste de GC: `-XX:+UseG1GC -XX:MaxGCPauseMillis=200`
  - Opções de debug: `-Xdebug -Xrunjdwp:transport=dt_socket,server=y,suspend=n,address=5005`
- **Uso**: Defina quaisquer argumentos JVM que deseja passar ao processo Java executando o servidor Hytale
- **Nota**: 
  - Esses argumentos são passados após as configurações de memória (`SERVER_MIN_RAM`/`SERVER_MAX_RAM`) e antes da flag `-jar`
  - Para configuração de memória, prefira usar `SERVER_MIN_RAM` e `SERVER_MAX_RAM` para simplicidade

### Configuração do Downloader

O downloader do Hytale pode ser configurado usando variáveis de ambiente. Essas variáveis controlam como o downloader busca e atualiza os arquivos do servidor:

#### `DOWNLOADER_CREDENTIALS_PATH`
- **Descrição**: Caminho para arquivo de credenciais para downloads autenticados
- **Padrão**: Se não definido, o downloader usará o caminho padrão de credenciais (geralmente `/.hytale-downloader-credentials.json` no diretório do downloader)
- **Formato**: Caminho absoluto de arquivo (ex: `/hytale/.hytale-downloader-credentials.json`)
- **Uso**: 
  - **Importante**: Se as credenciais não forem fornecidas via esta variável ou arquivo, o downloader solicitará autorização na primeira execução
  - A URL de autorização e código serão exibidos na saída do console/logs no seguinte formato:
    ```
    Por favor, visite a seguinte URL para autenticar:
    https://oauth.accounts.hytale.com/oauth2/device/verify?user_code=XXXXXX
    Ou visite a seguinte URL e digite o código:
    https://oauth.accounts.hytale.com/oauth2/device/verify
    Código de autorização: XXXXXX
    ```
  - Você deve visitar a URL e inserir o código de autorização, ou visitar a URL com o código como parâmetro
  - Após autorização, as credenciais serão salvas automaticamente
  - Para credenciais persistentes, monte um volume no local do arquivo de credenciais

#### `DOWNLOADER_DOWNLOAD_PATH`
- **Descrição**: Caminho onde o arquivo ZIP do servidor baixado deve ser salvo
- **Padrão**: Se não definido, usa o local padrão do downloader
- **Formato**: Caminho de diretório absoluto (ex: `/hytale/downloads`)
- **Uso**: Personalize onde os arquivos do servidor são baixados antes da extração

#### `DOWNLOADER_PATCHLINE`
- **Descrição**: Patchline para baixar (ex: "release", "beta", etc.)
- **Padrão**: `release`
- **Uso**: Selecione qual canal de patchline/versão baixar

#### `DOWNLOADER_SKIP_UPDATE_CHECK`
- **Descrição**: Pular execução do downloader para verificar/atualizar arquivos do servidor
- **Padrão**: O downloader executa por padrão para baixar/atualizar arquivos do servidor
- **Uso**: Defina qualquer valor não vazio para pular a execução do downloader (útil se os arquivos já estiverem presentes)

### Montagem de Volumes

**Configuração Recomendada**: Monte diretórios específicos para melhor organização e controle:

```yaml
volumes:
    - ./backups:/hytale/backups
    - ./mods:/hytale/mods
    - ./logs:/hytale/logs
    - ./universe:/hytale/universe
```

**Mapeamentos de Diretórios**:
- **Backups** (`./backups` → `/hytale/backups`): Arquivos de backup do servidor
- **Mods** (`./mods` → `/hytale/mods`): Mods e plugins do servidor
- **Logs** (`./logs` → `/hytale/logs`): Arquivos de log do servidor
- **Universe** (`./universe` → `/hytale/universe`): Mundos e dados do universo do servidor

**Configuração Alternativa**: Você também pode montar todo o diretório `/hytale`:

- **Caminho no Host**: `./data` (ou `./hytale`)
- **Caminho no Container**: `/hytale`
- **Propósito**: Armazenamento persistente para todos os dados do servidor, configurações, mundos, backups, mods e logs

## Descrição dos Arquivos

### docker-compose.yml

Define a configuração do serviço Docker Compose:

- **Nome do Serviço**: `hytale`
- **Build**: Constrói a partir do Dockerfile local (`.`) ou pode ser configurado para usar a imagem pré-construída `ghcr.io/machinastudios/hytale-docker`
- **Mapeamento de Porta**: `5520:5520/udp` (mapeia porta 5520 do container para porta 5520 do host usando protocolo UDP)
- **Volumes**: Recomendado montar diretórios específicos (`./backups`, `./mods`, `./logs`, `./universe`) ou montar todo o diretório `/hytale`
- **Variáveis de Ambiente**: Configura comportamento e configurações do servidor
- **Otimizações de Sistema**: Inclui otimizações de sistema Linux via `sysctls` e `ulimits`:
  - **Rede**: Aumento de conexões socket (`net.core.somaxconn=65535`), backlog TCP e intervalos de porta para melhor desempenho
  - **Sistema de Arquivos**: Limites aumentados de descritores de arquivo via `ulimits` (`nofile: 1048576`) para lidar com muitos arquivos/inodes
  - **Nota**: Alguns parâmetros globais do sistema como `vm.swappiness`, `vm.max_map_count` e `fs.file-max` não podem ser configurados por container e devem ser definidos no sistema host Docker se necessário

**Nota**: Para usar a imagem pré-construída ao invés de construir a partir do código fonte, substitua `build: .` por:
```yaml
image: ghcr.io/machinastudios/hytale-docker
```

**Otimizações de Sistema**: A configuração inclui parâmetros otimizados do kernel Linux para desempenho de servidor de jogos. Otimizações de rede são aplicadas no nível do container via `sysctls`, enquanto limites de descritores de arquivo são definidos via `ulimits`. Observe que alguns parâmetros como `vm.swappiness`, `vm.max_map_count` e `fs.file-max` são globais do sistema e não podem ser configurados por container - eles devem ser definidos no sistema host Docker se personalização for necessária.

### Dockerimage (Dockerfile)

A definição da imagem Docker que:

1. **Imagem Base**: Usa `openjdk:22-jdk-slim` (OpenJDK 22)
2. **Passos de Configuração**:
   - Cria diretório de trabalho `/hytale`
   - Instala utilitários `unzip` e `wget`
   - Baixa o downloader do Hytale da URL oficial
   - Extrai e executa o downloader para buscar arquivos do servidor
   - Limpa arquivos temporários
3. **Porta Exposta**: 5520 (porta padrão do servidor Hytale)
4. **Entrypoint**: Executa `entrypoint.sh` para iniciar o servidor

### entrypoint.sh

O script entrypoint que executa quando o container inicia:

1. **Execução do Downloader**: Executa o downloader do Hytale com opções configuradas:
   - Suporta configuração do downloader via variáveis de ambiente
   - Baixa/atualiza arquivos do servidor antes de iniciar o servidor (a menos que `DOWNLOADER_SKIP_UPDATE_CHECK` esteja definido)
   - Se as credenciais não forem fornecidas, o downloader exibirá uma URL de autorização e código nos logs na primeira execução
2. **Manipulação de Assets**: 
   - **Se `SERVER_ASSETS_ZIP` não estiver definido**: O Hytale extrai e usa automaticamente assets padrão (nenhuma configuração necessária)
   - **Se `SERVER_ASSETS_ZIP` estiver definido**: 
     - Se for um caminho de arquivo local (arquivo existe), usa diretamente
     - Se for uma URL, baixa o arquivo ZIP de assets antes de usar
3. **Construção de Comando**: Constrói dinamicamente a linha de comando Java baseada em variáveis de ambiente:
   - **Argumentos JVM**: Configurações de memória (`SERVER_MIN_RAM`/`SERVER_MAX_RAM`) e argumentos JVM personalizados (`JAVA_JVM_ARGS`)
   - `--assets`: Inclui ZIP de assets personalizados se fornecido
   - `--accept-early-plugins`: Habilita carregamento antecipado de plugins se configurado
   - `--bind`: Define endereço e porta de binding do servidor
   - `--backup`: Habilita funcionalidade de backup
   - `--backup-dir`: Define localização do diretório de backup
   - `--backup-frequency`: Define intervalo de backup em minutos
4. **Execução do Servidor**: Lança `HytaleServer.jar` com os parâmetros configurados

## Construindo a Imagem

### Usando Imagem Pré-construída

A forma mais fácil é usar a imagem pré-construída do GitHub Container Registry:

```bash
docker pull ghcr.io/machinastudios/hytale-docker
```

### Construindo a partir do Código Fonte

Para construir a imagem Docker manualmente a partir do Dockerfile:

```bash
docker build -f Dockerimage -t hytale-server .
```

Ou marque com o mesmo nome da imagem pré-construída:

```bash
docker build -f Dockerimage -t ghcr.io/machinastudios/hytale-docker .
```

## Executando o Container

### Usando Docker Compose (Recomendado)

#### Opção 1: Usando Imagem Pré-construída

Atualize seu `docker-compose.yml` para usar a imagem pré-construída:

```yaml
services:
    hytale:
        image: ghcr.io/machinastudios/hytale-docker
        ports:
            - "5520:5520/udp"
        volumes:
            - ./backups:/hytale/backups
            - ./mods:/hytale/mods
            - ./logs:/hytale/logs
            - ./universe:/hytale/universe
        environment:
            - SERVER_ACCEPT_EARLY_PLUGINS=true
            - SERVER_BIND=0.0.0.0:5520
            - SERVER_BACKUP_DIR=/hytale/backups
            - SERVER_BACKUP_INTERVAL=10
        sysctls:
            # Otimizações de rede (apenas sysctls de rede podem ser definidos por container)
            net.ipv4.ip_local_port_range: "1024 65535"
            net.ipv4.tcp_tw_reuse: "1"
            net.ipv4.tcp_fin_timeout: "15"
            net.core.somaxconn: "65535"
            net.ipv4.tcp_max_syn_backlog: "16384"
            net.ipv4.tcp_slow_start_after_idle: "0"
        ulimits:
            # Limites de descritores de arquivo/inodes
            nofile:
                soft: 1048576
                hard: 1048576
```

#### Opção 2: Construindo a partir do Código Fonte

O `docker-compose.yml` padrão constrói a partir do Dockerfile local:

```bash
# Iniciar em modo detached
docker-compose up -d

# Iniciar com logs visíveis
docker-compose up
```

#### Comandos Comuns

```bash
# Parar o servidor
docker-compose down

# Reiniciar o servidor
docker-compose restart

# Ver logs
docker-compose logs -f hytale

# Baixar última imagem (se usando pré-construída)
docker-compose pull
```

### Usando Docker Diretamente

#### Com Imagem Pré-construída (Recomendado)

```bash
# Baixar a imagem (se ainda não baixada)
docker pull ghcr.io/machinastudios/hytale-docker

# Executar o container
docker run -d \
  --name hytale \
  -p 5520:5520/udp \
  -v ./backups:/hytale/backups \
  -v ./mods:/hytale/mods \
  -v ./logs:/hytale/logs \
  -v ./universe:/hytale/universe \
  -e SERVER_ASSETS_ZIP="" \
  -e SERVER_ACCEPT_EARLY_PLUGINS="true" \
  -e SERVER_BIND="0.0.0.0:5520" \
  -e SERVER_BACKUP_DIR="/hytale/backups" \
  -e SERVER_BACKUP_INTERVAL="10" \
  ghcr.io/machinastudios/hytale-docker
```

#### Construindo e Executando a partir do Código Fonte

```bash
# Construir a imagem
docker build -f Dockerimage -t hytale-server .

# Executar o container
docker run -d \
  --name hytale \
  -p 5520:5520/udp \
  -v ./backups:/hytale/backups \
  -v ./mods:/hytale/mods \
  -v ./logs:/hytale/logs \
  -v ./universe:/hytale/universe \
  -e SERVER_ASSETS_ZIP="" \
  -e SERVER_ACCEPT_EARLY_PLUGINS="true" \
  -e SERVER_BIND="0.0.0.0:5520" \
  -e SERVER_BACKUP_DIR="/hytale/backups" \
  -e SERVER_BACKUP_INTERVAL="10" \
  hytale-server
```

## Configuração de Porta

A configuração padrão mapeia a porta 5520 (porta padrão do servidor Hytale) do container para o host. Para alterar a porta:

1. Modifique `docker-compose.yml`:
   ```yaml
   ports:
       - "SUA_PORTA:5520"
   ```
2. Certifique-se de que `SERVER_BIND` corresponda se quiser que o servidor escute em uma interface específica

## Persistência de Dados

Os dados do servidor são armazenados em diretórios separados em sua máquina host (configuração recomendada):

- **Backups** (`./backups`): Backups automatizados (se habilitado)
- **Mods** (`./mods`): Mods e plugins do servidor
- **Logs** (`./logs`): Arquivos de log do servidor
- **Universe** (`./universe`): Mundos e dados do universo do servidor
- **Arquivos de Configuração**: Armazenados dentro do container (podem ser persistidos montando `/hytale` se necessário)

**Importante**: Certifique-se de que todos os diretórios montados tenham permissões adequadas para o container escrever arquivos.

**Alternativa**: Você pode montar todo o diretório `/hytale` como `./data:/hytale` para persistir todos os arquivos do servidor incluindo configurações, mas a abordagem recomendada é usar volumes separados para melhor organização.

## Sistema de Backup

O sistema de backup é configurado automaticamente quando `SERVER_BACKUP_DIR` está definido:

- **Localização dos Backups**: `/hytale/backups` (mapeado para `./backups` no host com configuração recomendada)
- **Intervalo de Backup**: Configurável via `SERVER_BACKUP_INTERVAL` (em minutos)
- **Criação Automática**: Backups são criados automaticamente no intervalo especificado

## Solução de Problemas

### Servidor Não Inicia

1. Verifique os logs do container:
   ```bash
   docker-compose logs hytale
   ```

2. Verifique se o Java está funcionando:
   ```bash
   docker-compose exec hytale java -version
   ```

3. Certifique-se de que o downloader foi concluído com sucesso:
   ```bash
   docker-compose exec hytale ls -la /hytale/
   ```

### Autorização do Downloader Necessária

Na primeira execução, se as credenciais não forem fornecidas, o downloader solicitará autorização:

1. Verifique os logs do container para uma URL de autorização:
   ```bash
   docker-compose logs hytale
   ```

2. Os logs exibirão algo similar a:
   ```
   Por favor, visite a seguinte URL para autenticar:
   https://oauth.accounts.hytale.com/oauth2/device/verify?user_code=XXXXXX
   Ou visite a seguinte URL e digite o código:
   https://oauth.accounts.hytale.com/oauth2/device/verify
   Código de autorização: XXXXXX
   ```

3. Visite a URL (ou a URL completa com o código, ou a URL base e insira o código manualmente) e complete o processo de autorização

4. Após autorização, o downloader salvará as credenciais automaticamente

5. **Para credenciais persistentes**: Monte um volume no local do arquivo de credenciais:
   ```yaml
   volumes:
       - ./backups:/hytale/backups
       - ./mods:/hytale/mods
       - ./logs:/hytale/logs
       - ./universe:/hytale/universe
       - ./credentials:/hytale/.hytale-downloader-credentials.json
   ```
   Então defina `DOWNLOADER_CREDENTIALS_PATH=/hytale/.hytale-downloader-credentials.json`
   
   Alternativamente, se usar montagem completa de `/hytale`:
   ```yaml
   volumes:
       - ./data:/hytale
   ```
   As credenciais serão automaticamente persistidas em `./data/.hytale-downloader-credentials.json`

### Porta Já em Uso

Se a porta 5520 já estiver em uso:

1. Altere o mapeamento de porta em `docker-compose.yml`
2. Atualize regras de firewall se necessário
3. Certifique-se de que nenhum outro servidor Hytale está em execução

### Problemas de Permissão

Se o servidor não conseguir escrever nos diretórios montados:

```bash
# No Linux/macOS - definir permissões para todos os diretórios recomendados
chmod -R 777 ./backups ./mods ./logs ./universe

# Ou definir propriedade para o usuário Docker
sudo chown -R 1000:1000 ./backups ./mods ./logs ./universe
```

Se usar a abordagem alternativa de montagem completa:

```bash
# No Linux/macOS
chmod -R 777 ./data

# Ou definir propriedade para o usuário Docker
sudo chown -R 1000:1000 ./data
```

### Servidor Não Atualizando

O script entrypoint executa a verificação de atualização do downloader a cada início do container. Se as atualizações não estiverem sendo aplicadas:

1. Reconstrua a imagem para obter o downloader mais recente:
   ```bash
   docker-compose build --no-cache
   docker-compose up -d
   ```

2. Verifique manualmente atualizações dentro do container:
   ```bash
   docker-compose exec hytale /bin/hytale-downloader -check-update
   ```

## Manutenção

### Atualizando o Servidor

O servidor verifica automaticamente atualizações na inicialização. Para forçar uma reconstrução:

```bash
docker-compose down
docker-compose build --no-cache
docker-compose up -d
```

### Limpeza

Para remover todos os containers, volumes e dados (**AVISO**: Isso deleta dados do servidor):

```bash
docker-compose down -v

# Se usando volumes separados recomendados
rm -rf ./backups ./mods ./logs ./universe

# Se usando montagem completa alternativa
rm -rf ./data
```

Para manter dados mas remover containers:

```bash
docker-compose down
```

## Notas

- O servidor Hytale requer Java 22 (fornecido pela imagem base OpenJDK)
- A URL do downloader é: `https://downloader.hytale.com/hytale-downloader.zip`
- Os arquivos do servidor são armazenados em `/hytale` dentro do container
- O script entrypoint lida com toda a configuração do servidor dinamicamente
- Todas as variáveis de ambiente são opcionais; o servidor usará padrões se não definidas

## Licença

Este projeto é uma configuração Docker para o servidor Hytale. Por favor, consulte os termos de serviço e licenciamento oficiais do Hytale para uso do servidor.

## Suporte

Para questões relacionadas a:
- **Configuração Docker**: Verifique as issues deste repositório
- **Servidor Hytale**: Consulte documentação e canais de suporte oficiais do Hytale
- **Configuração do servidor**: Revise o [Manual do Servidor Hytale](https://support.hytale.com/hc/en-us/articles/45326769420827-Hytale-Server-Manual) para opções disponíveis
