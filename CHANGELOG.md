# Changelog

Le numerazioni desktop e Android sono indipendenti. Le sezioni in preparazione non rappresentano release già pubblicate.

## Windows 0.4.2 — in preparazione
- Correzione dello stato di salvataggio e preservazione dei terminatori CRLF/LF; file invariati senza conversioni involontarie.
- Protezione delle modifiche durante operazioni asincrone, conferma di chiusura e salvataggi con sostituzione da file temporaneo.
- Checkbox Markdown visibili e non interattive nell'anteprima sanitizzata.
- Separazione delle responsabilità del frontend in moduli; test automatici di regressione.
- Lockfile, controlli di versione, build e installer verificati in CI; checksum SHA-256.
- Diaspro Installer: supporto opt-in al menu Nuovo per .md, associazioni OpenWith e rispetto delle scelte preesistenti.

## Android 1.1.2+5 — in preparazione
- Protezione delle modifiche non salvate quando arrivano documenti tramite intent, salvataggio coerente con lo snapshot inviato, serializzazione delle operazioni.
- Correzione del reset del viewer Mermaid dopo zoom e trascinamento.
- Separazione dei moduli Dart, test di regressione e risoluzione delle dipendenze bloccata.
- Verifica di identità, versione e firma APK; preparazione alla firma permanente e pubblicazione esclusivamente su tag espliciti.
- Nota migrazione: la release 1.1.1 era firmata con certificato Android Debug. Se la chiave originale non è disponibile, la nuova firma richiede una reinstallazione dopo backup; non promettere aggiornamento diretto dalla vecchia versione.

## Versioni precedenti
- Windows 0.4.1: ultima release pubblicata prima del consolidamento.
- Windows 0.4.0: Mermaid, Undo/Redo, icona condivisa e installer aggiornato.
- Android 1.1.1: viewer Mermaid a schermo intero e icona condivisa.
- Android 1.1.0: Mermaid e Undo/Redo.
- Android 1.0.0: prima release stabile Android.

Storico binari e note originali: [GitHub Releases](https://github.com/maryvellous/markdown-editor/releases).
