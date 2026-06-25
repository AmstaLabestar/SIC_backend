# Sauvegardes PostgreSQL — SIC

Sauvegarde automatisee de la base `sic_db` (soldes, transactions, agents…).
**Sans ce mecanisme, une corruption de la base = perte de l'argent suivi.**

## Comment ca marche

Le service `db-backup` (docker-compose) tourne en continu :

- image `postgres:16-alpine` (meme version majeure que la base → dump compatible) ;
- toutes les `BACKUP_INTERVAL_SECONDS` (24h par defaut), il execute
  [`backup.sh`](backup.sh) : `pg_dump` compresse (gzip), horodate ;
- rotation automatique dans le volume `pg_backups` :
  - `daily/`   → 7 derniers (`KEEP_DAILY`)
  - `weekly/`  → 4 derniers, promus le dimanche (`KEEP_WEEKLY`)
  - `monthly/` → 6 derniers, promus le 1er du mois (`KEEP_MONTHLY`)

Les dumps sont ecrits en `.sql.gz` (SQL en clair, sans owner/privileges) pour
une restauration simple et portable.

## Demarrer le service

```bash
docker compose up -d --build db-backup
docker compose logs -f db-backup
```

## Lancer une sauvegarde manuelle (a la demande)

```bash
docker compose exec db-backup sh /ops/backup.sh
```

## Lister les sauvegardes disponibles

```bash
docker compose exec db-backup ls -lht /backups/daily
```

## Copier un dump hors du conteneur (stockage hors-machine)

```bash
# Copie tout le volume de sauvegardes vers l'hote
docker compose cp db-backup:/backups ./backups-export
```

> ⚠️ **Hors-machine** : le volume `pg_backups` vit sur la meme machine que la
> base. Pour une vraie resilience (panne disque, vol…), synchronisez
> regulierement `./backups-export` (ou directement le volume) vers un stockage
> distant : S3/MinIO, `rclone`, `rsync` vers un autre serveur, etc.

## Restaurer (⚠️ destructif)

La restauration **ecrase toutes les donnees** de la base cible (drop +
recreate du schema `public`). Garde-fou : ne s'execute qu'avec
`RESTORE_CONFIRM=yes`.

```bash
docker compose run --rm -e RESTORE_CONFIRM=yes db-backup \
    sh /ops/restore.sh /backups/daily/sic_db_AAAAMMJJ_HHMMSS.sql.gz
```

Apres restauration, appliquer d'eventuelles migrations en attente :

```bash
docker compose exec web python manage.py migrate
```

## Procedure de restauration testee (a faire au moins une fois)

1. Noter le solde total et le nombre de transactions actuels.
2. Lancer une sauvegarde manuelle.
3. Sur une base de test (ou apres avoir note l'etat), restaurer le dump.
4. Verifier que solde et transactions correspondent a l'etape 1.

> Une sauvegarde n'a de valeur que si la restauration a deja ete verifiee.
