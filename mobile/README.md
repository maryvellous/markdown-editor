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
- rendering Markdown Flutter con `flutter_markdown_plus`, diagrammi Mermaid e viewer a schermo intero con zoom, trascinamento e reset;
- Annulla/Ripristina e contatori di parole e caratteri;
- avviso prima di uscire o cambiare documento quando ci sono modifiche non salvate;
- icona launcher Diaspro dedicata, con adaptive icon e themed icon sui dispositivi Android compatibili;
- palette e identità visuale Diaspro.

## Struttura

Il codice Flutter vive in `mobile/lib`. Il bridge Android in `mobile/android` gestisce document URI, permessi persistenti del Storage Access Framework e risorse launcher.

La cartella Gradle/Android standard non è versionata: la CI la genera con la versione stabile di Flutter e poi applica gli override presenti in `mobile/android`. Questo evita di duplicare boilerplate generato e mantiene il progetto mobile piccolo.

## Build locale

Con Flutter 3.47.0 (versione fissata in CI) e JDK 17 installati:

```bash
bash ./mobile/tool/bootstrap-android.sh
cd .mobile-build
flutter pub get --enforce-lockfile
flutter run
```

Per l'APK release:

```bash
cd .mobile-build
flutter build apk --release --no-pub
```

## Release Android

La GitHub Action **Build Android APK** esegue bootstrap, analisi, test, build APK, verifica firma e identità del pacchetto, e checksum SHA-256. La versione e il build number derivano da `mobile/pubspec.yaml`.

Le build CI di PR/main sono artefatti di test, non aggiornamenti pubblici. Un tag esplicito `mobile-v<versione>` abilita la firma con una chiave stabile approvata e la pubblicazione solo se la verifica del certificato riesce. Senza configurazione della chiave, la release fallisce intenzionalmente.

Prima della prima release con firma stabile, confrontare il certificato dell'APK già distribuito; un cambio di chiave può impedire aggiornamenti in-place. Vedere [configurazione firma](../docs/android-signing-setup.md), [release engineering](../docs/release-engineering.md) e [collaudo](../docs/release-validation.md). La prossima versione in preparazione è 1.1.2+5; non è ancora pubblicata.
