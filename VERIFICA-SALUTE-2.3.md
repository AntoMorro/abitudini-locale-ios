# Verifica Salute 2.3 (16)

{
  "version": "2.3",
  "build": 16,
  "release_commit": "7cbdcc5ec42fae1d54a833dc0645b4d662925634",
  "release_run": 42792007886,
  "ipa_sha256": "70223d4a3815a04e532dd8d6ffb2a6970e8667f5db1e18c5a0d593670e49fa6e",
  "ipa_bytes": 1630080,
  "core_tests": 76,
  "ui_run": 42790309382,
  "ui_source_commit": "f1e7edb6b70f98885aae4816c1e12daa7f9f68c2",
  "ui_tests": 2,
  "ui_result": "passed; local manual save and all advanced views plus sleep planning",
  "native_widget_compile": "passed; not installed on user's phone",
  "phone_retest_required": [
    "Principale sleep phase",
    "XML from user's Health export",
    "new advanced screens and widget signing if used"
  ],
  "local_delivery": "shell/file tools unresponsive; browser automatic download refused origin check; use GitHub artifact manually"
}

Il pacchetto Base non include le estensioni WidgetKit; le schede interne funzionano senza App Group. La snapshot widget è opt-in e richiede configurazione separata firmata. I test UI hanno usato dati fittizi isolati, non i valori sanitari dell’utente. Gli alias generici e la fase Principale sono coperti dai test del core. Le ultime modifiche successive al commit UI riguardano normalizzazione XML, testo dei metodi, collegamento widget e versione in impostazioni; la compilazione finale e i 76 test core sono riferiti al commit release.
