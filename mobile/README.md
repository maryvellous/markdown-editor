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
- avviso prima di uscire o cambiare documento quando ci sono modifiche non salvate;
- icona launcher Diaspro dedicata, con adaptive icon e themed icon sui dispositivi Android compatibili;
- palette e identità visuale Diaspro.

## Struttura

Il codice Flutter vive in `mobile/lib`. Il bridge Android in `mobile/android` gestisce document URI, permessi persistenti del Storage Access Framework e risorse launcher.

La cartella Gradle/Android standard non è versionata: la CI la genera con la versione stabile di Flutter e poi applica gli override presenti in `mobile/android`. Questo evita di duplicare boilerplate generato e mantiene il progetto mobile piccolo.

## Build locale

Con Flutter 3.47+ installato:

```bash
bash ./mobile/tool/bootstrap-android.sh
cd .mobile-build
flutter pub get
flutter run
```

Per l'APK release:

```bash
cd .mobile-build
flutter build apk --release
```

## Release Android

La GitHub Action **Build Android APK** esegue bootstrap, `flutter analyze`, build release e checksum SHA-256. La versione viene letta da `mobile/pubspec.yaml`.

Per la release stabile **1.0.0**, la pipeline pubblica:

- `diaspro-markdown-mobile-1.0.0.apk`;
- `diaspro-markdown-mobile-1.0.0.apk.sha256`;
- tag GitHub `mobile-v1.0.0`.

L'APK prodotto dalla pipeline è pensato per installazione diretta/sideload. Per una distribuzione Play Store o per una catena di aggiornamenti firmati con chiave privata stabile va configurato in seguito un keystore di release custodito nei GitHub Secrets.
