# Monitoring — SIC (Prometheus + Grafana)

Supervision du backend : metriques de requetes, latence, codes HTTP, plus
5 alertes cles.

## Pile

- **django-prometheus** instrumente l'app et expose `GET /metrics`.
- **Prometheus** (`:9090`) scrape `web:8000/metrics` toutes les 15s et evalue
  les regles d'alerte.
- **Grafana** (`:3000`, admin/admin) avec Prometheus pre-provisionne comme
  source de donnees.

## Demarrer

```bash
docker compose up -d --build web        # embarque django-prometheus
docker compose up -d prometheus grafana
```

- Metriques brutes : http://localhost:8000/metrics
- Prometheus :       http://localhost:9090  (Status > Targets, Alerts)
- Grafana :          http://localhost:3000  (admin / admin)

Dans Grafana : importer un dashboard Django (ex. ID **9528** "Django
Prometheus") ou construire ses panels sur les metriques `django_http_*`.

## Alertes ([alerts.yml](alerts.yml))

| Alerte               | Condition                              | Severite |
|----------------------|----------------------------------------|----------|
| AppDown              | scrape de web:8000 KO 1 min            | critical |
| HighServerErrorRate  | >5% de 5xx sur 5 min                    | critical |
| HighRequestLatency   | p95 > 1s sur 5 min                      | warning  |
| HighClientErrorRate  | >30% de 4xx sur 10 min                  | warning  |
| NoTraffic            | 0 requete sur 10 min                    | warning  |

> Les alertes sont **evaluees** par Prometheus (visibles dans l'onglet
> Alerts). Pour les **router** (email, Slack...), ajouter un Alertmanager.

## Production

- **Ne pas exposer `/metrics` publiquement** : le restreindre au reseau
  interne (pas de publication du port, reverse-proxy avec allowlist, ou auth).
- Ajuster `--storage.tsdb.retention.time` (15j par defaut) selon le volume.
- Changer le mot de passe Grafana (`GF_SECURITY_ADMIN_PASSWORD`).

## Pour aller plus loin

- Metriques **base de donnees** : remplacer le moteur par
  `django_prometheus.db.backends.postgresql` (latence requetes SQL).
- Metriques **Celery** : ajouter un exporter dedie (ex. `celery-exporter`)
  pour la profondeur de file et les taches en echec.
