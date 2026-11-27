# Collaudo finale — Windows 0.4.2 / Android 1.1.2+5

Stato: da eseguire su build candidate, nessuna release autorizzata. Registrare commit, link alla run, hash SHA-256, versione, dispositivo/OS e risultato (PASS / FAIL / NON ESEGUITO) per ogni caso. Non confondere CI verde con prova fisica. Usare file di test, mai documenti senza backup.

## 0. Prerequisiti
- [ ] CI Windows e Android verdi sul commit candidato; scaricare gli artefatti della run esatta.
- [ ] Verificare checksum degli artefatti; non utilizzare una build precedente con lo stesso nome.
- [ ] Windows: conservare la versione pubblicata 0.4.1 per il test di aggiornamento; backup dei file di prova.
- [ ] Android: completare [firma permanente](android-signing-setup.md), verificare backup offline e certificato; lanciare manualmente Build Android APK su main con sign_candidate=true, senza creare tag.
- [ ] Android: verificare package ID dev.diaspro.diaspro_markdown_mobile, versionName 1.1.2, versionCode 5, certificato approvato. Salvare i documenti esterni e le copie locali recenti che non esistono altrove prima di eventuale disinstallazione.
- [ ] Preparare un .md UTF-8 con accenti, terminatori LF/CRLF, una checklist, una tabella, un diagramma Mermaid valido e uno invalido; conservare hash originali e copie separate.

## 1. Windows — aggiornamento e installazione
- [ ] Dalla versione 0.4.1 con file di prova salvati e recenti, eseguire l'installer candidato sopra l'installazione esistente; verificare versione, percorso, assenza di installazioni duplicate, integrità dei file e recenti.
- [ ] Verificare Start, collegamento Desktop se selezionato, Apri con su .md e .markdown, apertura tramite doppio clic se impostato come predefinito.
- [ ] In una cartella vuota, menu contestuale Nuovo → Documento Markdown: crea un file .md vuoto, nome e icona coerenti. Se un altro programma possiede già ShellNew, non sostituire il template; verificare OpenWith. Annotare il comportamento effettivo di Explorer.
- [ ] Disinstallare solo dopo aver verificato i documenti di prova; verificare che file e associazioni di terzi siano conservati.
- [ ] Ripetere installazione pulita con candidato e verificare avvio senza console indesiderata e controlli finestra (minimizza, massimizza, doppio clic titlebar, chiusura).

## 2. Windows — uso quotidiano
- [ ] Apri file, Scrivi/Affianca/Leggi, Guida e Recenti (indipendenti, richiudibili); contatori e feedback di salvataggio.
- [ ] Aprire file CRLF e LF: risultano salvati. Salvare senza modifiche e confrontare hash; modificare e controllare terminatori. Salva con nome non altera inutilmente il file originale.
- [ ] Annulla/Ripristina via pulsanti e scorciatoie; guida inserisce sintassi nel punto corretto e gestisce selezione.
- [ ] Checkbox selezionate e vuote visibili; tabella e testo UTF-8 corretti. Mermaid valido renderizzato, errore leggibile per quello invalido; zoom, pan, adatta, chiudi.
- [ ] Con modifiche non salvate, Nuovo/Apri/Alt+F4: annullamento preserva il testo, conferma scarta solo quando richiesta. Durante salvataggio/salva con nome non perdere modifiche successive. Provare annullamento del dialogo.
- [ ] File non accessibile o sola lettura: errore comprensibile, contenuto corrente preservato. Verificare visivamente contrasto, dimensioni finestra minima e focus da tastiera.

## 3. Android — migrazione e aggiornamento
- [ ] Confrontare certificato 1.1.1 pubblicato e nuova firma. Se diverso, documentare incompatibilità; non tentare di aggirare la verifica Android. Solo dopo backup verificato e autorizzazione, disinstallare la vecchia app e installare il candidato firmato. Eventuali recenti privati e permessi SAF possono andare persi; riaprire i file esterni.
- [ ] Se la chiave precedente è stata recuperata e corrisponde, testare aggiornamento diretto invece della reinstallazione.
- [ ] Per testare il vero incremento di versione con la nuova chiave, costruire localmente un APK esclusivamente di test con lo stesso package ID, codice candidato e versionCode inferiore a 5 (es. 4), firmarlo con la chiave approvata e installarlo su un dispositivo/profilo di test senza conflitti. Creare recenti e documenti SAF, aggiornare in-place a 1.1.2+5; verificare cronologia, permessi e file. Non pubblicare il baseline, non condividere la chiave. Se il test non è fattibile, registrarlo NON ESEGUITO: non sostituirlo con una semplice reinstallazione dello stesso APK.

## 4. Android — uso quotidiano
- [ ] Avvio, selettore SAF, apertura/Salva/Salva con nome, annullamento picker; provare almeno memoria locale e un provider effettivamente usato.
- [ ] Nuovo, Apri con/Condividi a freddo e ad app aperta; con testo non salvato annullare l'abbandono e verificare che rimanga intatto.
- [ ] Salvataggio durante ulteriori modifiche: lo stato deve riflettere lo snapshot scritto, senza sovrascrivere il testo più recente.
- [ ] Recenti e riapertura; dove riproducibile, revocare il permesso su un file di prova e verificare apertura della copia recente e Salva con nome.
- [ ] Scrivi/Leggi, Guida, contatori, Annulla/Ripristina, tastiera; layout largo/tablet in emulatore o dispositivo. Verificare rotazione e navigazione Indietro con modifiche.
- [ ] Mermaid: diagramma valido e invalido, tocco per apertura, pinch, trascinamento, doppio tap, adatta/ripristina dopo un pan, ritorno al documento.
- [ ] Verificare file sul provider dopo salvataggio. I provider SAF non garantiscono tutti scritture atomiche: annotare esiti, non promettere protezione assoluta.

## 5. Criteri di rilascio
- [ ] Nessun errore bloccante sui file, salvataggi, aggiornamenti o installazione. Ogni test non eseguito ha una decisione esplicita del titolare.
- [ ] Verificare corrispondenza tra versione e commit, aggiornare note di release dal changelog, informare sulla migrazione Android e sul fatto che Windows non dispone di Authenticode.
- [ ] Approvazione esplicita del titolare; solo allora creare tag v0.4.2 e mobile-v1.1.2 sul commit approvato.
- [ ] Verificare run di pubblicazione, asset e checksum finali. Non sovrascrivere release esistenti.
- [ ] Aggiornare README e portfolio con stato pubblicato e prove effettive; nessuna affermazione di benchmark o audit non eseguiti.
