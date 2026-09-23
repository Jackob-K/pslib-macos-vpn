# PSLIB macOS VPN

Neoficiální pomocný CLI nástroj pro připojení macOS ke školní SSTP VPN SPŠSE a VOŠ Liberec (PSLIB) pomocí open-source `sstp-client`.

> Tento projekt není oficiální software PSLIB. Používejte jej pouze s účtem, ke kterému máte oprávnění, a v souladu s pravidly školní sítě.

## Co řeší

macOS nemá nativní SSTP klient. `pslib-vpn` proto:

1. použije `sstpc` z Homebrew,
2. ověří server pomocí CA bundle z Homebrew,
3. naváže PPP tunel,
4. přidá route `10.10.10.0/24` přes vzniklé PPP rozhraní,
5. volitelně otevře nakonfigurované SMB disky ve Finderu,
6. při ukončení odpojí školní SMB svazky a uklidí route.

PSLIB veřejně dokumentuje lokální úložiště na `athena.ad.pslib.cz`, včetně osobního disku X: a společného disku S:.

## Požadavky

- macOS
- Homebrew
- oprávněný účet PSLIB
- administrátorské oprávnění na Macu (`sudo`)

## Instalace

```bash
git clone <URL-REPOZITARE>
cd pslib-macos-vpn
./install.sh
source ~/.zprofile
```

Instalátor nainstaluje:

```bash
brew install sstp-client ca-certificates
```

a vloží `pslib-vpn` do `~/.local/bin`.

## První nastavení

```bash
pslib-vpn setup
```

Uživatelské jméno se uloží do:

```text
~/.config/pslib-vpn/username
```

Heslo se **neukládá do repozitáře ani do konfiguračního souboru**. Ukládá se do macOS Keychainu jako generic password.

## Připojení

```bash
pslib-vpn
```

nebo explicitně:

```bash
pslib-vpn connect
```

Po úspěšném připojení nástroj zůstane spuštěný v Terminálu. VPN ukončíte pomocí `Ctrl+C`; nástroj se pokusí odpojit školní SMB svazky ze serveru `athena.ad.pslib.cz`, odstranit route a ukončit VPN proces.

Stav lze zkontrolovat:

```bash
pslib-vpn status
```

a případnou jinou běžící relaci ukončit:

```bash
pslib-vpn disconnect
```

## SMB disky

Po `pslib-vpn setup` vznikne:

```text
~/.config/pslib-vpn/mounts
```

Do něj lze přidat jeden SMB URL na řádek. Například společný disk S:

```text
smb://athena.ad.pslib.cz/public
```

PSLIB veřejně uvádí osobní disk X: jako:

```text
\\athena.ad.pslib.cz\doma$\jmeno.prijmeni
```

Na macOS tomu odpovídá například:

```text
smb://athena.ad.pslib.cz/doma$/jmeno.prijmeni
```

Při prvním `setup` se disk S: předvyplní jako aktivní položka. Osobní disk X: se předvyplní jako komentovaný příklad odvozený z uživatelského jména; odkomentujte jej, pokud odpovídá vašemu účtu.

Další interní disky, například L: a W:, nejsou v tomto repozitáři předvyplněny, protože jejich přesné SMB cesty a oprávnění se mohou lišit podle role uživatele. Přidejte je lokálně do souboru `mounts`, pokud jejich cestu znáte a máte k nim oprávnění. Pokud macOS vyžádá autentizaci pro některý disk zvlášť, uložte ji do Keychainu přes systémový dialog Finderu.

Příklad výsledného lokálního souboru:

```text
smb://athena.ad.pslib.cz/public
smb://athena.ad.pslib.cz/doma$/jmeno.prijmeni
# smb://athena.ad.pslib.cz/nejaky-dalsi-share
```

## Bezpečnost

- Heslo není součástí repozitáře.
- Heslo je uloženo v macOS Keychainu.
- Skript používá ověření TLS certifikátu; nepoužívá `--cert-warn`.
- `sstpc` při tomto způsobu připojení vyžaduje uživatelské jméno a heslo jako argumenty příkazové řádky. Heslo se tedy při běhu předává procesu `sstpc`; to je omezení tohoto jednoduchého způsobu použití upstream klienta. Pro prostředí s vyššími požadavky na ochranu lokálního procesu by bylo vhodné přejít na konfiguraci přes `pppd`/peer profil.
- Nikdy necommitujte soubory z `~/.config/pslib-vpn` ani exporty Keychainu.

## Odinstalace

```bash
pslib-vpn forget
rm -f ~/.local/bin/pslib-vpn
rm -rf ~/.config/pslib-vpn
```

Závislosti lze případně odebrat:

```bash
brew uninstall sstp-client
```

## Licence

MIT
