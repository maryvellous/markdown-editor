# Diaspro Markdown

Piccolo editor desktop per file Markdown, pensato per essere rapido da aprire e semplice da usare come lettore ed editor quotidiano su Windows.

## Cosa fa

- apre file `.md` e `.markdown` dal pulsante **Apri** o direttamente da Esplora file;
- modifica Markdown in un editor essenziale con conteggio parole e caratteri;
- mostra l'anteprima Markdown in tempo reale, anche affiancata all'editor;
- crea nuovi documenti e usa **Salva** / **Salva con nome**;
- supporta `Ctrl+N`, `Ctrl+O`, `Ctrl+S` e `Ctrl+Shift+S`;
- registra Diaspro Markdown come applicazione per i file Markdown;
- aggiunge **Documento Markdown** al menu di Windows **Nuovo** tramite `ShellNew`;
- usa la palette e il linguaggio visivo della cartella `diaspro-general-features`;
- usa un'icona Diaspro dedicata: riquadro plum, `m` minuscola e le tre bolle sand/blue/sage.

## UI

La UI è volutamente spartana. I tre modi di lavoro sono:

- **Scrivi**: solo editor;
- **Affianca**: editor e anteprima;
- **Leggi**: solo anteprima.

Il rendering Markdown avviene nel backend Rust e l'HTML risultante viene sanitizzato prima di essere mostrato.

## Integrazione Windows

Il bundle NSIS dichiara l'associazione ai file `.md` e `.markdown`. L'hook dell'installer aggiunge inoltre `ShellNew` per `.md`, così **tasto destro → Nuovo → Documento Markdown** crea il file e Windows può passarlo direttamente a Diaspro Markdown.

Windows può richiedere una scelta esplicita dell'utente per cambiare l'app predefinita se `.md` è già associato a un altro programma. In quel caso basta usare una volta **Apri con → Diaspro Markdown → Sempre**.

## Sviluppo

Prerequisiti: Node.js, Rust e i prerequisiti Windows richiesti da Tauri/WebView2.

```bash
npm install
npm run icons
npm run dev
```

L'app usa un frontend HTML/CSS/JavaScript senza framework e Tauri 2 per il contenitore desktop.

## Build Windows

```bash
npm install
npm run build
```

La build genera l'installer NSIS in `src-tauri/target/release/bundle/nsis/`.

Il workflow GitHub Actions **Build Windows** esegue la stessa build su Windows e pubblica l'installer come artifact scaricabile dalla run.

## Struttura

```text
src/                         frontend minimale
src-tauri/                   backend e configurazione Tauri
src-tauri/windows/hooks.nsh  integrazione “Nuovo → Documento Markdown”
src-tauri/icons/app-icon.svg sorgente dell'icona m Diaspro
diaspro-general-features/    riferimenti visuali e componenti Diaspro
```
