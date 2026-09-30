# Diaspro Markdown

Piccolo editor desktop per file Markdown, pensato per essere rapido da aprire e semplice da usare come lettore ed editor quotidiano su Windows.

## Cosa fa

- apre file `.md` e `.markdown` dal pulsante **Apri** o direttamente da Esplora file;
- modifica Markdown in un editor essenziale con conteggio parole e caratteri;
- mostra l'anteprima Markdown in tempo reale, anche affiancata all'editor;
- crea nuovi documenti e usa **Salva** / **Salva con nome**;
- mantiene un elenco degli **8 file aperti più di recente**, riapribili con un click;
- include una **guida rapida Markdown laterale** con le sintassi comuni cliccabili per inserirle nell'editor;
- permette di nascondere la barra laterale senza perdere la preferenza;
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

La barra laterale raccoglie i file recenti e una guida alle sintassi Markdown: titoli, grassetto, corsivo, barrato, codice, citazioni, liste, checkbox, link, immagini, separatori, tabelle, note a piè pagina, a-capo forzato ed escape.

Il rendering Markdown avviene nel backend Rust e l'HTML risultante viene sanitizzato prima di essere mostrato. In modalità **Scrivi**, quando l'anteprima non è visibile, il renderer non viene invocato a ogni battuta: questo riduce ulteriormente il lavoro su CPU meno recenti.

## File recenti

La cronologia contiene al massimo 8 percorsi ed è salvata localmente nel WebView tramite `localStorage`. Non viene usato alcun database.

Se un file recente è stato spostato o eliminato, al tentativo di apertura viene rimosso automaticamente dall'elenco.

## Integrazione Windows

Il bundle NSIS dichiara l'associazione ai file `.md` e `.markdown`. L'hook dell'installer aggiunge inoltre `ShellNew` per `.md`, così **tasto destro → Nuovo → Documento Markdown** crea il file e Windows può passarlo direttamente a Diaspro Markdown.

Windows può richiedere una scelta esplicita dell'utente per cambiare l'app predefinita se `.md` è già associato a un altro programma. In quel caso basta usare una volta **Apri con → Diaspro Markdown → Sempre**.

## Leggerezza

L'app usa Tauri 2, un frontend HTML/CSS/JavaScript senza framework e il WebView di sistema. Non incorpora una copia completa di Chromium come farebbe una tipica app Electron.

L'obiettivo è funzionare bene anche su hardware non recente. Il requisito pratico più importante è il sistema operativo: su Windows serve un ambiente compatibile con WebView2. La potenza della macchina incide molto meno di quanto inciderebbe in un'app Electron.

## Sviluppo

Prerequisiti: Node.js, Rust e i prerequisiti Windows richiesti da Tauri/WebView2.

```bash
npm install
npm run icons
npm run dev
```

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
