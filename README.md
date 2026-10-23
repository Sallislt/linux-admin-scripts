# Linux Admin Scripts (Bash)

🇫🇷 Trois scripts Bash pour l’exploitation quotidienne d’un serveur Linux (Debian / Ubuntu) :
sauvegarde, détection des tentatives de connexion SSH et contrôle de santé.

🇬🇧 *Three Bash scripts for day-to-day Linux server operations: backups, failed SSH login report and health check.*

| Script | Rôle |
|---|---|
| `backup.sh` | Archive `.tar.gz` horodatée, empreinte SHA-256 vérifiée, rotation des anciennes sauvegardes |
| `failed-logins.sh` | Rapport des échecs de connexion SSH : IP sources et comptes visés, signalement des attaques par force brute |
| `health-check.sh` | Disque, mémoire, charge, services systemd en échec, mises à jour en attente ; code retour 1 en cas d’alerte |

## Utilisation

```bash
chmod +x *.sh

# Sauvegarde de /var/www, 14 archives conservées
./backup.sh -s /var/www -d /srv/backups -k 14

# Rapport SSH sur le fichier d'exemple fourni
./failed-logins.sh -f samples/auth.log -m 5

# Contrôle de santé, alerte disque à 80 %
./health-check.sh -d 80
```

Exemple de sortie de `failed-logins.sh` sur `samples/auth.log` :

```
== Failed SSH logins: 12 ==

-- Top 10 source IPs --
      8  203.0.113.45  <-- brute force?
      3  198.51.100.7
      1  192.168.10.25

-- Top 10 targeted usernames --
      5  root
      3  admin
      2  test
      ...
```

## Planification (cron)

```cron
30 2 * * *  /opt/scripts/backup.sh -s /var/www -d /srv/backups -k 14 >> /var/log/backup.log 2>&1
0  * * * *  /opt/scripts/health-check.sh -d 85 > /dev/null || logger -t health-check "WARNING on $(hostname)"
```

## Choix techniques

- `set -euo pipefail` et validation des paramètres ;
- sauvegarde écrite d’abord dans un fichier `.part`, puis renommée : jamais d’archive incomplète ;
- vérification de l’empreinte et de la lisibilité de l’archive juste après sa création ;
- `failed-logins.sh` est en lecture seule : le blocage reste le rôle de fail2ban ou du pare-feu ;
- adresses IP d’exemple issues des plages réservées à la documentation (RFC 5737).

---

Développé avec l’aide d’un assistant IA, dans le cadre de ma reconversion vers l’IT. · Licence MIT
