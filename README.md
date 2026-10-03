# Buddy-Programm

Website für das Buddy-Programm im Stipendium: Erfahrene Stipendiat:innen melden sich als **Buddy** an, neue Stipendiat:innen als **Neue**. Die Website schlägt automatisch die am besten passenden Paare vor. Du als Admin bestätigst sie, und danach sehen beide Personen ihren Buddy, wenn sie sich anmelden.

| Datei | Wofür |
|---|---|
| `index.html` | Die ganze Website (Anmeldung, beide Ansichten, Admin-Ansicht, Matching) |
| `supabase/schema.sql` | Die Datenbank: Tabellen und Zugriffsregeln, einmal in Supabase ausführen |
| `datenschutz.html`, `impressum.html` | Vorlagen für Datenschutzerklärung und Impressum (gelb markierte Stellen ausfüllen) |
| `vendor/` | Schriften und Supabase-Bibliothek lokal, damit beim Aufruf keine Daten an Google oder andere Dritte gehen |
| `prototyp/index.html` | Der erste Prototyp ohne Datenbank (nur zum Anschauen) |

## So funktioniert es

1. **Registrieren:** Eine Person wählt „Ich bin neu“ oder „Ich werde Buddy“ und füllt das Formular aus (Studienort, Hochschule, Fach, Sprachen, Interessen, Kontaktwunsch; Buddys zusätzlich, wie viele Neue sie begleiten möchten).
2. **E-Mail bestätigen:** Sie bekommt einen Link per E-Mail. Erst nach dem Klick wird das Profil gespeichert. Ein Passwort gibt es nicht, die Anmeldung läuft immer über so einen Link.
3. **Matching:** Die Admin-Ansicht berechnet für jede neue Person die passendsten Buddys mit einer Prozentzahl und dem Grund („gleiche Stadt“, „Sprache: Polnisch“ …). Die gelbe **Empfehlung** betrachtet alle gleichzeitig, damit möglichst viele gute Paare entstehen und kein Buddy mehr Personen bekommt, als er oder sie angegeben hat.
4. **Bestätigen:** Du klickst auf „Bestätigen“ (oder auf „Alle Empfehlungen bestätigen“). Mit „E-Mail an beide“ öffnet sich eine fertige E-Mail an das Paar.
5. **Buddy gefunden:** Die neue Person sieht „Du hast einen Buddy: …“, der Buddy sieht „Du begleitest jetzt …“, beide mit E-Mail-Knopf und Gemeinsamkeiten.

Die Punkte fürs Matching stehen oben in `index.html` unter `POINTS` und lassen sich dort ändern. Dasselbe gilt für die Auswahllisten (`CITIES`, `FIELDS`, `INTERESTS`).

---

## Schritt für Schritt einrichten

### Schritt 1: Supabase-Projekt (die Datenbank)

1. Auf [supabase.com](https://supabase.com) ein kostenloses Projekt anlegen. Als Region **Frankfurt (eu-central-1)** wählen, wegen des Datenschutzes.
2. **Project Settings → API Keys:** die **Project URL** und den **Publishable key** kopieren und oben in `index.html` bei `SUPABASE_URL` und `SUPABASE_KEY` eintragen. Den **Secret key** nie in eine Datei schreiben.
3. **SQL Editor → New query:** den ganzen Inhalt von `supabase/schema.sql` einfügen und auf **Run** klicken.
   Bricht es mit einem Fehler wie `column "user_id" does not exist` ab, gibt es noch alte Test-Tabellen. Dann zuerst `supabase/reset.sql` ausführen (löscht die alten Buddy-Tabellen) und danach `schema.sql` noch einmal.

> Der Publishable key darf öffentlich auf GitHub stehen. Die Daten schützen die Zugriffsregeln aus `schema.sql`: Jede Person sieht nur sich selbst und ihren Buddy, nur Admins sehen alle. Deshalb muss Schritt 1.3 unbedingt ausgeführt sein, bevor sich jemand anmeldet.

### Schritt 2: Website über GitHub Pages veröffentlichen

1. Auf GitHub im Repository: **Settings → Pages**.
2. Bei **Source** „Deploy from a branch“ wählen, Branch **main** und Ordner **/ (root)**, dann **Save**.
3. Nach ein bis zwei Minuten ist die Seite erreichbar unter
   `https://sofiabusik.github.io/Buddy_Programm/`
   Jede Änderung, die auf `main` landet, wird automatisch veröffentlicht.

### Schritt 3: Supabase die Website-Adresse mitteilen

**Authentication → URL Configuration:**

- **Site URL:** `https://sofiabusik.github.io/Buddy_Programm/`
- **Redirect URLs:** dieselbe Adresse hinzufügen

Sonst führen die Links aus den E-Mails nicht zurück zur Website.

### Schritt 4: E-Mail-Versand einrichten

Ohne eigenen Mail-Dienst verschickt Supabase nur sehr wenige E-Mails pro Stunde und **nur an Mitglieder deines Supabase-Teams**. Andere bekämen keinen Login-Link. So richtest du [Brevo](https://www.brevo.com) ein (kostenlos, 300 E-Mails am Tag, Sitz in der EU):

1. **Brevo-Konto anlegen** auf brevo.com („Sign up free“).
2. **Absender bestätigen:** In Brevo oben rechts auf den Namen klicken, dann **Senders, domains & dedicated IPs → Senders → Add a sender**. Die E-Mail-Adresse eintragen, von der die Login-Links kommen sollen, und den Bestätigungslink in deinem Postfach anklicken.
   Am zuverlässigsten ist eine Adresse mit eigener Domain, zum Beispiel von der Stiftung. Bei Gmail- oder GMX-Adressen landen die E-Mails öfter im Spam.
3. **SMTP-Schlüssel holen:** In Brevo **SMTP & API → Tab „SMTP“ → Generate a new SMTP key**. Den Schlüssel sofort kopieren, er wird nur einmal angezeigt. Auf derselben Seite stehen **SMTP server**, **Port** und **Login**.
4. **In Supabase eintragen:** **Authentication → Emails → SMTP Settings → Enable custom SMTP** einschalten:
   | Feld | Wert |
   |---|---|
   | Sender email | die in Schritt 2 bestätigte Adresse |
   | Sender name | Buddy-Programm |
   | Host | `smtp-relay.brevo.com` |
   | Port | `587` |
   | Username | der **Login** aus Brevo (sieht aus wie `xxxx@smtp-brevo.com`) |
   | Password | der SMTP-Schlüssel aus Schritt 3 |

   Dann **Save**.
5. **Testen** mit einer E-Mail-Adresse, die *nicht* in deinem Supabase-Team ist: auf der Website registrieren und prüfen, ob der Link ankommt (auch im Spam-Ordner).
6. Optional unter **Authentication → Emails → Templates** die Texte der Login-E-Mail auf Deutsch anpassen.

### Schritt 5: Dich als Admin eintragen

1. In Supabase **Authentication → Users → Add user → Create new user**: deine E-Mail-Adresse eintragen, „Auto Confirm User“ anhaken.
2. Im **SQL Editor** ausführen (E-Mail anpassen):
   ```sql
   insert into public.admins (user_id)
     select id from auth.users where email = 'deine@email.de'
     on conflict do nothing;
   ```
3. Auf der Website mit dieser E-Mail anmelden. Du siehst jetzt die Admin-Ansicht „Zuordnung“. Weitere Admins trägst du genauso ein.

### Schritt 6: Testen

1. Mit zwei anderen E-Mail-Adressen registrieren: einmal als Neue:r, einmal als Buddy.
2. Als Admin anmelden, die Empfehlung prüfen und bestätigen.
3. Mit den beiden Test-Adressen anmelden: Beide sollten „Buddy gefunden“ sehen.
4. Testpaar als Admin wieder auflösen. Testpersonen löschst du in Supabase unter **Authentication → Users**.

### Schritt 7: Farben und Rechtliches

- **Farben:** Oben in `index.html` stehen `--blue`, `--blue-deep` und `--yellow`. Dort die genauen Farbcodes des Stipendiums eintragen (zum Beispiel `#1C3F94`). Außerdem kommt Gelb im Logo vor (`fill="#F7C62F"` im `<svg>`).
- **Datenschutz und Impressum:** Die Vorlagen `datenschutz.html` und `impressum.html` öffnen und alle gelb markierten Stellen ausfüllen (auf github.com: Datei öffnen, Stift-Symbol, ändern, „Commit changes“). Danach die Markierung `<mark class="todo">…</mark>` entfernen und nur den Text stehen lassen. Die Vorlagen sind keine Rechtsberatung. Bitte vor dem Start mit eurer Stiftung abstimmen.

---

## Mit GitHub arbeiten

- Kleine Änderungen (Farben, Listen, Texte) direkt auf github.com machen: Datei öffnen, auf das Stift-Symbol klicken, ändern, unten „Commit changes“.
- Größere Änderungen auf einem eigenen Branch machen und dann einen Pull Request nach `main` öffnen. So kannst du alles prüfen, bevor es live geht.
- Ideen und Fehler unter **Issues** sammeln, zum Beispiel „Automatische E-Mail, wenn ein Paar bestätigt wird“.

## Mögliche nächste Schritte

- Automatische Benachrichtigung per E-Mail beim Bestätigen eines Paars (Supabase Edge Function oder Database Webhook). Bis dahin übernimmt der Knopf „E-Mail an beide“ das.
- Profil nachträglich bearbeiten können.
- Freitextfeld „Was wünschst du dir von deinem Buddy?“.
