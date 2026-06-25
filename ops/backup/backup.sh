#!/bin/sh
# =============================================================================
# SIC - Sauvegarde PostgreSQL (un cycle)
# -----------------------------------------------------------------------------
# Effectue un pg_dump horodate, compresse (gzip), puis applique la rotation
# quotidien / hebdomadaire / mensuel. Concu pour tourner dans un conteneur
# postgres:16-alpine (meme version majeure que la base, pour un dump compatible).
#
# Variables (avec valeurs par defaut) :
#   PGHOST/PGPORT/PGUSER/PGPASSWORD/PGDATABASE  -> connexion (cf docker-compose)
#   BACKUP_DIR     dossier racine des sauvegardes        (defaut /backups)
#   KEEP_DAILY     nb de dumps quotidiens conserves       (defaut 7)
#   KEEP_WEEKLY    nb de dumps hebdomadaires conserves    (defaut 4)
#   KEEP_MONTHLY   nb de dumps mensuels conserves         (defaut 6)
# =============================================================================
set -eu

: "${PGHOST:=db}"
: "${PGPORT:=5432}"
: "${PGDATABASE:=sic_db}"
: "${BACKUP_DIR:=/backups}"
: "${KEEP_DAILY:=7}"
: "${KEEP_WEEKLY:=4}"
: "${KEEP_MONTHLY:=6}"

ts="$(date +%Y%m%d_%H%M%S)"
daily_dir="$BACKUP_DIR/daily"
weekly_dir="$BACKUP_DIR/weekly"
monthly_dir="$BACKUP_DIR/monthly"
mkdir -p "$daily_dir" "$weekly_dir" "$monthly_dir"

file="$daily_dir/sic_db_${ts}.sql.gz"
tmp="${file}.tmp"

echo "[backup] $(date '+%Y-%m-%d %H:%M:%S') dump $PGDATABASE@$PGHOST -> $file"

# SQL en clair (-Fp via defaut) sans owner/privileges : restauration simple et
# portable. On ecrit dans un fichier .tmp puis on renomme : pas de dump partiel
# considere comme valide si pg_dump echoue en cours de route.
if pg_dump --no-owner --no-privileges | gzip -c > "$tmp"; then
  mv "$tmp" "$file"
  echo "[backup] OK ($(du -h "$file" | cut -f1))"
else
  rm -f "$tmp"
  echo "[backup] ECHEC du pg_dump" >&2
  exit 1
fi

# Promotions : une copie hebdomadaire le dimanche, mensuelle le 1er du mois.
if [ "$(date +%u)" = "7" ]; then
  cp "$file" "$weekly_dir/"
  echo "[backup] copie hebdomadaire creee"
fi
if [ "$(date +%d)" = "01" ]; then
  cp "$file" "$monthly_dir/"
  echo "[backup] copie mensuelle creee"
fi

# Rotation : ne conserver que les N fichiers les plus recents par dossier.
prune() {
  dir="$1"
  keep="$2"
  ls -1t "$dir"/*.sql.gz 2>/dev/null | tail -n +"$((keep + 1))" | while read -r old; do
    echo "[backup] purge $old"
    rm -f "$old"
  done
}
prune "$daily_dir" "$KEEP_DAILY"
prune "$weekly_dir" "$KEEP_WEEKLY"
prune "$monthly_dir" "$KEEP_MONTHLY"

echo "[backup] termine."
