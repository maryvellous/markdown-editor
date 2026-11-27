# Diaspro Markdown

Editor Markdown locale per Windows e Android, pensato per essere rapido da aprire e semplice da usare come lettore ed editor quotidiano. I documenti rimangono normali file, indipendenti dall'applicazione.

**Stato:** versioni pubblicate Windows 0.4.1 e Android 1.1.1; sorgenti in preparazione per Windows 0.4.2 e Android 1.1.2+5. Le build candidate non sono ancora release pubbliche.

## Documentazione

- [Scelte progettuali e UX](docs/product-design.md)
- [Architettura desktop](docs/desktop-architecture.md) · [Architettura Android](docs/android-architecture.md)
- [Versione Android](mobile/README.md) · [Changelog](CHANGELOG.md)
- [Dipendenze e toolchain](docs/dependency-management.md)
- [Release engineering](docs/release-engineering.md) · [Collaudo finale](docs/release-validation.md) · [Firma Android](docs/android-signing-setup.md)

Le funzionalità e la UI descritte qui sotto riguardano in particolare Windows.

## Cosa fa

- apre file `.md` e `.markdown` dal pulsante **Apri** o direttamente da Esplora file;
- modifica Markdown in un editor essenziale con conteggio parole e caratteri;
- mostra l'anteprima Markdown in tempo reale, anche affiancata all'editor;
- renderizza i fenced code block `mermaid` come diagrammi consultabili, con viewer desktop a zoom/pan;
- crea nuovi documenti e usa **Salva** / **Salva con nome**;
- mantiene un elenco degli **8 file aperti più di recente**, riapribili con un click;
- include una **guida rapida Markdown laterale** con le sintassi comuni cliccabili per inserirle nell'editor;
- separa **Recenti** e **Guida** in due pannelli indipendenti richiamabili dalla rail laterale;
- supporta undo/redo con pulsanti dedicati e scorciatoie `Ctrl+Z`, `Ctrl+Y` / `Ctrl+Shift+Z`;
- supporta `Ctrl+N`, `Ctrl+O`, `Ctrl+S` e `Ctrl+Shift+S`;
- registra Diaspro Markdown come applicazione per i file Markdown;
- aggiunge **Documento Markdown** al menu di Windows **Nuovo** tramite `ShellNew`;
- usa la palette e il linguaggio visivo della cartella `diaspro-general-features`;
- usa la stessa icona Diaspro finale della versione mobile, sia nell'interfaccia sia per eseguibile, collegamenti e installer.

## UI

La UI è volutamente spartana. I tre modi di lavoro sono:

- **Scrivi**: solo editor;
- **Affianca**: editor e anteprima;
- **Leggi**: solo anteprima.

Sul bordo sinistro c’è una piccola rail con due strumenti distinti:

- **Recenti**: apre un pannello dedicato che contiene solo la cronologia degli ultimi file;
- **Guida**: apre un pannello separato con le sintassi Markdown cliccabili.

I due pannelli sono mutuamente esclusivi e possono essere richiusi ricliccando lo strumento attivo.

Il rendering Markdown avviene nel backend Rust e l'HTML risultante viene sanitizzato prima di essere mostrato. I fenced code block marcati `mermaid` mantengono solo la classe di linguaggio necessaria e vengono poi renderizzati localmente dal frontend con Mermaid, senza CDN. In modalità **Scrivi**, quando l'anteprima non è visibile, il renderer non viene invocato a ogni battuta: questo riduce ulteriormente il lavoro su CPU meno recenti.

## File recenti

La cronologia contiene al massimo 8 percorsi ed è salvata localmente nel WebView tramite `localStorage`. Non viene usato alcun database.

I percorsi recenti vengono conservati senza copiare il contenuto del documento. Se un percorso non è più accessibile, l'apertura restituisce un errore; la cronologia può essere pulita manualmente.

## Integrazione Windows

L'installer Diaspro (Inno Setup) pubblicato dalla CI registra le associazioni `.md` e `.markdown` per l'utente corrente. Il generatore Inno include il supporto opzionale `ShellNew` per `.md`, creando un file vuoto dal menu **Nuovo → Documento Markdown** se non esiste già una definizione di un altro programma. Non modifica l'editor predefinito se già presente. La visibilità effettiva del menu su Windows e gli aggiornamenti da installer precedenti richiedono il collaudo finale.

Windows può richiedere una scelta esplicita dell'utente per cambiare l'app predefinita se `.md` è già associato a un altro programma. In quel caso basta usare una volta **Apri con → Diaspro Markdown → Sempre**.

## Leggerezza

L'app usa Tauri 2, un frontend HTML/CSS/JavaScript senza framework e il WebView di sistema. Non incorpora una copia completa di Chromium come farebbe una tipica app Electron.

L'obiettivo è funzionare bene anche su hardware non recente. Il requisito pratico più importante è il sistema operativo: su Windows serve un ambiente compatibile con WebView2. La potenza della macchina incide molto meno di quanto inciderebbe in un'app Electron.

## Sviluppo

Prerequisiti: Node.js (versione in `.node-version`), Rust (versione in `rust-toolchain.toml`) e i prerequisiti Windows richiesti da Tauri/WebView2. Usare i lockfile versionati; aggiornare le dipendenze soltanto con un intervento esplicito e verificato.

```bash
npm ci
npm run icons
npm run dev
```

## Build Windows

```bash
npm ci
npm run build -- --locked
```

Il comando locale genera il bundle NSIS in `src-tauri/target/release/bundle/nsis/`. Il workflow GitHub Actions **Build Windows** usa invece l'eseguibile Tauri e il generatore Inno Setup Diaspro, verifica installazione e rimozione in CI e carica installer e checksum SHA-256. Lo stesso workflow pubblica una release solo su tag esplicito `v<versione>`.

Procedura e collaudi: [release engineering](docs/release-engineering.md).

## Struttura

```text
src/                         frontend minimale
src-tauri/                   backend e configurazione Tauri
src-tauri/windows/hooks.nsh  integrazione “Nuovo → Documento Markdown”
src/assets/app_icon.png        sorgente icona desktop + UI
diaspro-general-features/    riferimenti visuali e componenti Diaspro
```
