# PSLIB macOS VPN

Neoficiální nástroj pro připojení macOS ke školní SSTP VPN SPŠSE a VOŠ
Liberec a k síťovým diskům S, X, L a W. SSTP přenáší program `sstpc`;
systémový `pppd` zajišťuje pouze vnitřní PPP vrstvu SSTP spojení.

> Projekt není oficiálním softwarem PSLIB. Používejte jej jen s účtem, ke
> kterému máte oprávnění, a v souladu s pravidly školní sítě.

Projekt zatím není označen jako `v1.0.0`. Před vydáním je nutné dokončit ruční
testy uvedené na konci dokumentu.

## Rychlý start

Po stažení repozitáře spusťte:

```bash
cd pslib-macos-vpn
./install.sh
source ~/.zprofile
pslib-vpn setup
```

Průvodce se zeptá na školní účet, bezpečně uloží VPN heslo do macOS Keychainu
a nabídne disky S, X, L a W. Pro studenta jsou předvolené S a X.

Běžné připojení má jediný příkaz:

```bash
pslib-vpn
```

Terminál nechte otevřený. `Ctrl+C` odpojí svazky připojené tímto během,
odstraní školní trasu a ukončí VPN. Po pádu nebo zavření Terminálu spusťte:

```bash
pslib-vpn disconnect
```

## Požadavky a oprávnění

- macOS se systémovým `/usr/sbin/pppd` a příkazem `security`
- Homebrew
- oprávněný účet PSLIB
- právo použít `sudo`

Instalace Homebrew může na spravovaném Macu vyžadovat pomoc správce. Samotný
Homebrew obvykle balíčky instaluje bez `sudo`, ale každé VPN připojení potřebuje
správcovské oprávnění pro spuštění PPP a změnu routovací tabulky. Bez možnosti
`sudo` tento způsob SSTP připojení nelze použít; správce školy musí nástroj
povolit nebo dodat spravované VPN řešení.

## Instalace

```bash
./install.sh
```

Instalátor:

1. ověří macOS, systémový `pppd` a Keychain,
2. nainstaluje `sstp-client` a `ca-certificates` přes Homebrew,
3. nainstaluje příkaz do `~/.local/bin/pslib-vpn`,
4. případně přidá `~/.local/bin` do `~/.zprofile`.

První nastavení nevyžaduje ruční úpravu souborů:

```bash
pslib-vpn setup
```

Necitlivá lokální konfigurace je v `~/.config/pslib-vpn` s oprávněním pouze
pro vlastníka. Hesla tam nejsou.

## Keychain a VPN heslo

VPN heslo spravují tyto příkazy:

```bash
pslib-vpn credentials
pslib-vpn forget-credentials
```

`credentials` aktualizuje jméno a položku `PSLIB VPN` v uživatelském macOS
Keychainu. Heslo si bezpečně vyžádá přímo systémový příkaz `security`; shell jej
nevypisuje ani nepřidává do historie. `forget-credentials` vyžaduje potvrzení a
pak položku z Keychainu odstraní.

Při připojení se heslo načte příkazem `security find-generic-password -w` a
anonymní rourou se předá jako obsah options souboru na `/dev/stdin` programu
`pppd`. `pppd` je spuštěn s `hide-password` a spouští:

```text
sstpc --nolaunchpppd ... hecate.pslib.cz
```

Heslo proto není v argumentech `security`, `sudo`, `pppd` ani `sstpc`, není v
shellové historii a `sstpc` ho vůbec nezná. Nevzniká ani dočasný soubor s
heslem. Nainstalovaný `sstpc 1.0.20` nabízí pro heslo pouze nebezpečný argument
`--password`; ten projekt nepoužívá. Apple `pppd 2.4.2` umí číst options přes
`file /dev/stdin`, podporuje MS-CHAPv2 a `pty`, což je použitý mechanismus.

Apple `pppd` obsahuje také `userkeychainpassword`, ale při spuštění přes `sudo`
by hledal Keychain uživatele root. Globální `/etc/ppp/chap-secrets` by zase
zapisoval heslo na disk. Ani jedna varianta proto není použita.

## Síťové disky

Výběr disků lze kdykoli změnit opětovným spuštěním:

```bash
pslib-vpn setup
```

| Disk | Účel | SMB cesta |
| --- | --- | --- |
| S | společný školní prostor | `smb://athena.ad.pslib.cz/public` |
| X | osobní adresář | `smb://athena.ad.pslib.cz/doma$/jmeno.prijmeni` |
| L | učitelský disk Bakaláři | `smb://bakalar.ad.pslib.cz/bakalari` |
| W | veřejné webové stránky | `smb://hermes.ad.pslib.cz/homes` |

Jméno adresáře X se odvodí z části školního uživatelského jména před `@` a v
průvodci je lze změnit. Řetězec `doma$` je ve skriptu vždy uzavřen v uvozovkách,
takže `$` shell nerozvine. Uživatelský segment je validován a URL kódován.

Disky se otevírají systémovým příkazem `open` a připojuje je Finder. Je to na
macOS bezpečnější než skládat CLI příkaz s heslem: heslo není v SMB URL ani v
argumentech procesu a macOS zobrazí vlastní přihlašovací dialog. Pokud uživatel
zvolí uložení, přihlašovací údaje spravuje systémový Keychain pro konkrétní SMB
server.

Identita pro VPN, Athenu, Bakaláře a Hermes se automaticky nesjednocuje. Disk L
vyžaduje školní e-mail a síťové heslo; případná uložená položka patří serveru
`bakalar.ad.pslib.cz`. Disk W může server studentovi odmítnout. Selhání jednoho
disku neukončí VPN ani neblokuje ostatní disky.

Nástroj před připojením a po něm porovná seznam SMB svazků. Zapíše si pouze
nově vzniklé svazky a při úklidu znovu ověří jejich server a share. Již dříve
připojený svazek označí jako přeskočený a nikdy jej neodpojí. Tím chrání jiné
síťové disky uživatele, včetně disků ze stejného serveru.

## Příkazy

```text
pslib-vpn                    připojí SSTP VPN a vybrané SMB disky
pslib-vpn setup              nastaví účet a výběr disků
pslib-vpn credentials        aktualizuje VPN účet a heslo
pslib-vpn forget-credentials odstraní VPN heslo po potvrzení
pslib-vpn status             zobrazí stav bez citlivých údajů
pslib-vpn disconnect         uklidí disky, VPN a trasu
pslib-vpn doctor             provede bezpečnou diagnostiku
```

## Diagnostika

```bash
pslib-vpn doctor
pslib-vpn status
```

`doctor` bez zobrazení hesla kontroluje systémové nástroje, Homebrew balíčky,
CA certifikáty, konfiguraci, existenci položky v Keychainu, dostupnost VPN
serveru na TCP 443 a připravenost SMB cest. SMB servery mohou být dosažitelné
až po připojení VPN; takový stav je uveden jako informace, ne jako únik hesla.

Časté situace:

- „VPN heslo není v Keychainu“: spusťte `pslib-vpn credentials`.
- Server odmítl přihlášení: zkontrolujte jméno a aktualizujte heslo.
- VPN už běží: použijte `pslib-vpn status`; druhý tunel se nevytvoří.
- Po pádu zůstal stav: spusťte `pslib-vpn disconnect` a potom připojení znovu.
- Disk L otevře dialog: použijte školní e-mail, ne automaticky VPN identitu.
- Disk W selže: účet pravděpodobně nemá oprávnění; VPN zůstane funkční.
- Disk nelze odpojit: zavřete jeho soubory a zopakujte `disconnect`.

## Bezpečnostní omezení

- Uživatelské jméno není heslo a je viditelné v argumentu `pppd user`.
- Heslo krátce existuje v paměti procesů `security`, transformační roury a
  `pppd`; správce systému nebo proces s odpovídajícími právy může paměť procesu
  teoreticky zkoumat.
- Heslo nesmí obsahovat znak nového řádku. Interaktivní Keychain výzva jej
  standardně ani neumožňuje zadat jako součást hesla.
- Nástroj úmyslně nepodporuje `set -x`; na začátku trasování vypíná. Heslo se
  nevypisuje ani v diagnostickém režimu.
- TLS certifikát serveru se ověřuje přes Homebrew CA bundle. Volba
  `--cert-warn` se nepoužívá.
- `kill -9` nelze zachytit. Stav spravovaných disků však zůstane uložený a
  následný `pslib-vpn disconnect` provede úklid.
- Konfiguraci `~/.config/pslib-vpn`, exporty Keychainu a diagnostické soubory s
  osobními údaji nikdy nepřidávejte do Gitu.

## Testy a správci

Automatické testy nepřipojují skutečnou VPN a nepoužívají skutečné heslo:

```bash
./tests/run.sh
bash -n bin/pslib-vpn install.sh uninstall.sh tests/run.sh
git diff --check
```

Harness používá mocky pro `security`, `sstpc`, `pppd`, `mount`, `umount`,
`sudo` a další systémové příkazy. Ověřuje bezpečný stdin kanál, chybějící
Keychain, odmítnutou autentizaci, opakovaný běh, přerušení, selhání SMB,
selektivní odpojení a potvrzení při mazání údajů.

Správce může před nasazením prověřit, že `/usr/sbin/pppd` stále přijímá volby
`file`, `pty`, `user`, `hide-password` a MS-CHAPv2 a že verze `sstpc` podporuje
`--nolaunchpppd`. Změna nebo odstranění systémového `pppd` v budoucí verzi
macOS bude vyžadovat novou implementaci; skript nezkouší neexistující volby.

## Odinstalace

```bash
./uninstall.sh
```

Odinstalátor se nejdřív pokusí odpojit spravované svazky a VPN, nabídne
odstranění hesla z Keychainu a potom odstraní program i neškodnou konfiguraci.
Homebrew balíčky ponechá. Volitelně je lze odstranit:

```bash
brew uninstall sstp-client ca-certificates
```

## Checklist před v1.0.0

- [ ] Instalace na čistém standardním uživatelském účtu macOS.
- [ ] Ověření s účtem, který smí použít potřebné `sudo`, nebo se správcem.
- [ ] `pslib-vpn setup` a kontrola, že heslo je pouze v uživatelském Keychainu.
- [ ] Skutečné připojení k `hecate.pslib.cz` se správnými údaji.
- [ ] Odmítnutí chybného hesla bez jeho výpisu v Terminálu a `ps`.
- [ ] Ověření, že školní route vede přes nově vzniklé PPP rozhraní.
- [ ] Připojení S a X se studentským účtem.
- [ ] Připojení L učitelským účtem a samostatný Keychain záznam pro Bakaláře.
- [ ] Ověření očekávaného povolení nebo odmítnutí W.
- [ ] `Ctrl+C` odpojí jen svazky vytvořené daným během.
- [ ] Násilné zavření Terminálu a následný `pslib-vpn disconnect` vše uklidí.
- [ ] Opakované spuštění nevytvoří druhou VPN ani duplicitní SMB svazky.
- [ ] Kontrola na podporované aktuální verzi macOS a Apple Silicon i Intel Macu.

## Licence

MIT, viz [LICENSE](LICENSE).
