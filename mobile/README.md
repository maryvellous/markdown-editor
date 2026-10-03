# Diaspro Markdown Mobile

Versione Android in Flutter/Dart di Diaspro Markdown, mantenuta nello stesso repository dell'app desktop.

## Funzioni

- crea e modifica file Markdown;
- apre `.md`, `.markdown` e file di testo tramite il selettore documenti Android;
- salva direttamente sul documento scelto tramite Storage Access Framework;
- `Salva con nome` con picker Android;
- riceve documenti tramite **Apri con** e **Condividi**;
- cronologia degli ultimi 8 documenti con snapshot locale di sicurezza;
- modalità **Scrivi** e **Leggi** su telefono;
- modalità **Affianca** automatica disponibile su tablet / finestre larghe;
- guida Markdown inseribile nel punto del cursore;
- rendering Markdown nativo Flutter con `flutter_markdown_plus`;
- palette e identità visuale Diaspro.

## Struttura

Il codice Flutter vive in `mobile/lib`. Il piccolo bridge Android in `mobile/android` gestisce i document URI e i permessi persistenti del Storage Access Framework.

La cartella Gradle/Android standard non è versionata: la CI la genera con la versione stabile di Flutter e poi applica gli override presenti in `mobile/android`. Questo evita di duplicare boilerplate generato e mantiene il progetto mobile piccolo.

## Build locale

Con Flutter 3.47+ installato:

```bash
./mobile/tool/bootstrap-android.sh
cd .mobile-build
flutter pub get
flutter run
```

Per l'APK:

```bash
cd .mobile-build
flutter build apk --release
```

La GitHub Action `Build Android APK` esegue automaticamente bootstrap, analisi e build e pubblica `diaspro-markdown-mobile.apk` nella release `mobile-v0.1.0`.
