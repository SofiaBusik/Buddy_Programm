# Buddy-Programm

Website für das Buddy-Programm im Stipendium: Erfahrene Stipendiat:innen melden sich als **Buddy** an, neue Stipendiat:innen als **Neue**. Die Website schlägt automatisch die am besten passenden Paare vor. Du als Admin bestätigst sie, und danach sehen beide Personen ihren Buddy, wenn sie sich anmelden.

| Datei | Wofür |
|---|---|
| `index.html` | Die ganze Website (Anmeldung, beide Ansichten, Admin-Ansicht, Matching) |
| `supabase/schema.sql` | Die Datenbank: Tabellen und Zugriffsregeln, einmal in Supabase ausführen |
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

Ohne eigenen Mail-Server verschickt Supabase nur sehr wenige E-Mails pro Stunde und nur an Mitglieder deines Supabase-Teams. Für echte Anmeldungen:

1. Ein kostenloses Konto bei einem Mail-Dienst anlegen, zum Beispiel [Brevo](https://www.brevo.com) oder [Resend](https://resend.com).
2. In Supabase unter **Authentication → Emails → SMTP Settings** die Zugangsdaten des Dienstes eintragen.
3. Optional unter **Authentication → Emails → Templates** die Texte der Login-E-Mail auf Deutsch anpassen.

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
- **Datenschutz und Impressum:** Links bei `DATENSCHUTZ_URL` und `IMPRESSUM_URL` eintragen. Weil Namen und E-Mail-Adressen gespeichert werden, sollte die Datenschutzerklärung vor dem Start mit eurer Stiftung abgesprochen sein.

---

## Mit GitHub arbeiten

- Kleine Änderungen (Farben, Listen, Texte) direkt auf github.com machen: Datei öffnen, auf das Stift-Symbol klicken, ändern, unten „Commit changes“.
- Größere Änderungen auf einem eigenen Branch machen und dann einen Pull Request nach `main` öffnen. So kannst du alles prüfen, bevor es live geht.
- Ideen und Fehler unter **Issues** sammeln, zum Beispiel „Automatische E-Mail, wenn ein Paar bestätigt wird“.

## Mögliche nächste Schritte

- Automatische Benachrichtigung per E-Mail beim Bestätigen eines Paars (Supabase Edge Function oder Database Webhook). Bis dahin übernimmt der Knopf „E-Mail an beide“ das.
- Profil nachträglich bearbeiten können.
- Freitextfeld „Was wünschst du dir von deinem Buddy?“.
