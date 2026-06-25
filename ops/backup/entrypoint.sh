#!/bin/sh
# =============================================================================
# SIC - Boucle du service de sauvegarde PostgreSQL
# -----------------------------------------------------------------------------
# Lance backup.sh a intervalle regulier. Une boucle shell (plutot que cron)
# garde le conteneur simple, lisible et previsible dans Docker.
#
#   BACKUP_INTERVAL_SECONDS  intervalle entre deux cycles (defaut 86400 = 24h)
#   BACKUP_ON_START          "1" pour sauvegarder des le demarrage (defaut 1)
# =============================================================================
set -eu

: "${BACKUP_INTERVAL_SECONDS:=86400}"
: "${BACKUP_ON_START:=1}"

dir="$(dirname "$0")"

echo "[backup] service demarre — intervalle ${BACKUP_INTERVAL_SECONDS}s"

# Laisse a la base le temps d'accepter les connexions au tout premier demarrage.
sleep 10

if [ "$BACKUP_ON_START" != "1" ]; then
  echo "[backup] BACKUP_ON_START=0 -> on attend le premier intervalle"
  sleep "$BACKUP_INTERVAL_SECONDS"
fi

while true; do
  # Un cycle en echec ne doit pas tuer le service : on reessaiera au prochain tour.
  sh "$dir/backup.sh" || echo "[backup] cycle en echec, nouvelle tentative dans ${BACKUP_INTERVAL_SECONDS}s" >&2
  sleep "$BACKUP_INTERVAL_SECONDS"
done
