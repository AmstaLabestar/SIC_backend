#!/bin/sh
# =============================================================================
# SIC - Restauration PostgreSQL depuis un dump
# -----------------------------------------------------------------------------
# DANGER : ecrase TOUTES les donnees de la base cible (drop + recreate du
# schema public). A n'utiliser qu'en connaissance de cause.
#
# Usage (depuis l'hote) :
#   docker compose run --rm -e RESTORE_CONFIRM=yes db-backup \
#       sh /ops/restore.sh /backups/daily/sic_db_AAAAMMJJ_HHMMSS.sql.gz
#
# Garde-fou : ne fait rien sans RESTORE_CONFIRM=yes.
# =============================================================================
set -eu

: "${PGHOST:=db}"
: "${PGPORT:=5432}"
: "${PGDATABASE:=sic_db}"
: "${RESTORE_CONFIRM:=no}"

file="${1:-}"

if [ -z "$file" ] || [ ! -f "$file" ]; then
  echo "Usage: restore.sh <chemin/vers/dump.sql.gz>" >&2
  echo "" >&2
  echo "Dumps disponibles :" >&2
  ls -1t /backups/daily/*.sql.gz /backups/weekly/*.sql.gz /backups/monthly/*.sql.gz 2>/dev/null >&2 \
    || echo "  (aucun)" >&2
  exit 1
fi

if [ "$RESTORE_CONFIRM" != "yes" ]; then
  echo "REFUS : RESTORE_CONFIRM n'est pas 'yes'." >&2
  echo "Cette operation ECRASE la base '$PGDATABASE' sur '$PGHOST'." >&2
  echo "Relancez avec -e RESTORE_CONFIRM=yes pour confirmer." >&2
  exit 2
fi

echo "[restore] cible : $PGDATABASE@$PGHOST"
echo "[restore] source : $file"
echo "[restore] reinitialisation du schema public..."
psql --set ON_ERROR_STOP=on -c "DROP SCHEMA public CASCADE; CREATE SCHEMA public;"

echo "[restore] chargement du dump..."
gunzip -c "$file" | psql --set ON_ERROR_STOP=on

echo "[restore] termine. Pensez a relancer 'manage.py migrate' si besoin."
