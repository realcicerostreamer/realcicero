# Instruções para Compilação e Uso do realCicero

Este documento contém instruções detalhadas para compilar e usar o aplicativo realCicero para streaming com sua câmera COOAU CU-SPC06.

## Requisitos

- Flutter SDK 3.10.6 ou superior
- Android Studio ou VS Code com extensões Flutter
- Dispositivo Android com Android 5.0 (API 21) ou superior
- Conexão à câmera COOAU CU-SPC06 via WiFi

## Compilação

### Opção 1: Compilação Local

1. Clone o repositório ou crie um novo projeto com os arquivos fornecidos
2. Execute `flutter pub get` para instalar as dependências
3. Conecte seu dispositivo Android via USB com depuração USB ativada
4. Execute `flutter build apk` para gerar o APK
5. Instale o APK no seu dispositivo com `flutter install`

### Opção 2: Compilação via GitHub Actions

1. Faça push dos arquivos para um repositório GitHub
2. O workflow configurado em `.github/workflows/build-apk.yaml` irá compilar automaticamente
3. Baixe o APK gerado dos artefatos da action

## Uso do Aplicativo

### Configuração Inicial

1. Conecte seu smartphone à rede WiFi da câmera COOAU CU-SPC06
2. Abra o aplicativo realCicero
3. A URL RTSP padrão `rtsp://192.168.42.1/live` já está configurada para sua câmera
4. Insira suas URLs RTMP para YouTube, Twitch e/ou Kick

### Transmissão

1. Clique em "INICIAR TRANSMISSÃO" para começar a transmitir
2. Use as abas para alternar entre a visualização da câmera e os chats
3. Clique em "PARAR TRANSMISSÃO" para encerrar

### Configurações Técnicas

- Resolução: 1280x720 (HD)
- Taxa de quadros: 30 FPS
- Bitrate: 2500 kbps
- Preset: ultrafast (para baixa latência)
- Áudio: AAC 128 kbps

## Solução de Problemas

- Se o aplicativo não conectar à câmera, verifique se está conectado à rede WiFi correta
- Para problemas de permissão, verifique se concedeu todas as permissões solicitadas
- Se o chat não carregar, verifique sua conexão à internet e as URLs RTMP

## Personalização

Para personalizar o aplicativo:

- Altere o tema no arquivo `main.dart`
- Ajuste os parâmetros de codificação na função `_startStreaming()`
- Modifique as URLs padrão conforme necessário
