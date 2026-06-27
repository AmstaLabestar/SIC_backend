# Paiements & agrégateur — SIC

> Comment SIC encaisse et décaisse de l'argent réel via un agrégateur (CinetPay,
> HUB2 demain), l'abstraction qui rend l'agrégateur interchangeable, l'état du code,
> et ce qui reste pour passer en production.
> Code : `api/services/payment_provider.py`, `api/services/cinetpay_client.py`,
> webhook dans `api/views.py`.

---

## 1. Le rôle d'un agrégateur

Sans agrégateur, accepter Orange Money + Moov + MTN + Wave exige **un contrat
technique par opérateur**. Un agrégateur (CinetPay, HUB2) a déjà ces contrats : SIC
intègre **une seule API**, l'agrégateur parle aux opérateurs en notre nom. SIC a chez
lui un **compte marchand** (portefeuille tampon) qui se crédite/débite.

## 2. Les deux directions de l'argent (à ne jamais confondre)

| Sens | Nom | Mécanique | Usage SIC | API CinetPay |
|---|---|---|---|---|
| **Encaissement** | *checkout / collecte* | prompt sur le tél. du **client** qui valide → débite son wallet, crédite le marchand | le client **paie** (retrait, transfert client) | `https://api-checkout.cinetpay.com/v2` |
| **Décaissement** | *payout / transfert* | SIC **pousse** l'argent depuis le compte marchand vers un wallet (pas de validation du destinataire) | **livrer** au destinataire ; payout compensation agent | `https://client.cinetpay.com/v1` (auth→contact→send) |

➡️ Un transfert client complet = **encaissement (le client paie) + décaissement (on
livre)**. Ce sont **deux produits, deux contrats, parfois deux niveaux d'accès**. Le
décaissement exige en plus une **balance prépayée** à approvisionner et une **IP
publique fixe whitelistée** (d'où le besoin d'un VPS).

## 3. Cycle d'une opération réelle

```
1. Agent/client lance l'opération ─► SIC réserve les fonds (PENDING)   [moteur de compensation]
2. SIC ─► get_payment_provider().initiate_payment / payout ─► Agrégateur   (après commit, hors verrou)
3. Agrégateur ─► opérateur ─► débite/crédite le wallet (client confirme si encaissement)
4. Agrégateur ─── webhook signé HMAC ──► POST /api/transactions/webhook/
5. SIC vérifie (IP, HMAC, montant) puis process_webhook(ref, SUCCESS/FAILED)  [idempotent]
6. SIC ─── WebSocket ──► l'app voit le statut changer en direct
```

Le **webhook est la source de vérité** du règlement ; la réponse HTTP immédiate dit
seulement « en cours ». Si le webhook se perd → **timeout + réconciliation** rattrapent
(cf. [ARCHITECTURE.md §5](ARCHITECTURE.md)).

## 4. L'abstraction `PaymentProvider` (point de bascule unique)

Le moteur ne dépend **jamais** de CinetPay en dur :

```
api/services/payment_provider.py
├── class PaymentProvider(ABC)          # contrat : use_mock, initiate_payment,
│                                        #          payout, check_transaction, refund
└── def get_payment_provider()          # POINT DE BASCULE UNIQUE
        → settings.PAYMENT_PROVIDER (défaut 'cinetpay', import paresseux anti-cycle)

api/services/cinetpay_client.py
└── class CinetPayClient(PaymentProvider)   # 1re implémentation
```

- Le moteur (`_settle_after_commit`) et les tâches (`reconcile`) appellent
  `get_payment_provider()`, jamais `CinetPayClient()` directement.
- **Brancher HUB2** : écrire `Hub2Client(PaymentProvider)`, décommenter la branche
  `hub2` dans `get_payment_provider()`, poser `PAYMENT_PROVIDER=hub2`. **Zéro ligne du
  moteur à modifier.**
- Périmètre abstrait = opérations **sortantes**. La vérif du webhook **entrant** (HMAC,
  champs `cpm_*`) reste dans la vue (fortement spécifique CinetPay) — prochain seam à
  abstraire si on bascule vraiment.

## 5. Modes : mock / sandbox / live

Piloté par `CINETPAY_MODE` (settings, défaut `mock`) :

| Mode | Comportement |
|---|---|
| **mock** (défaut) | **aucun appel réseau**, réponses simulées. Comportement dev inchangé. |
| **sandbox** | vraies requêtes vers l'API de test (mêmes credentials que prod chez CinetPay). |
| **live** | production, vrai argent. |

**Filet de sécurité** : `use_mock()` est vrai en mode `mock` **ou** dès qu'un credential
essentiel manque — on ne tente jamais un appel réel sans credentials, même si `live` est
demandé par erreur.

## 6. État du code

| Capacité | État |
|---|---|
| Mode mock/sandbox/live + `use_mock()` | ✅ |
| Encaissement (`initiate_payment`) branché après commit, hors verrou | ✅ codé |
| Décaissement (`payout`, flux auth→contact→send) | ✅ codé (mock + chemin réel) |
| Webhook durci (HMAC schéma `cpm_*`, vérif montant, allowlist IP, idempotent) | ✅ codé |
| Abstraction `PaymentProvider` + factory | ✅ |
| Réconciliation interroge `check_transaction()` avant rollback en mode réel | ✅ |

> ⚠️ **Codé ≠ validé contre l'API réelle.** Le flux payout réel et **l'ordre exact des
> champs HMAC** du webhook sont écrits mais **jamais testés contre CinetPay** (marqué
> `⚠️` dans le code). À confirmer en **sandbox** avant la prod.

## 7. Ce qui reste pour activer le réel

### A. Administratif (délai externe long — à lancer en premier)
1. **Compte marchand** CinetPay (ou HUB2) → KYB (entité légale, RCCM, pièce dirigeant, RIB).
2. Activer **Checkout (encaissement)** → `API_KEY`, `SITE_ID`, `SECRET_KEY`.
3. Activer **Transfer (décaissement)** (demande souvent séparée) → identifiants Transfer
   + **approvisionner la balance** de décaissement.
4. **Grille de frais** par opérateur (encaissement **et** décaissement) + plafonds +
   délais de settlement → indispensable pour fixer le **barème `fee` client**.
5. Liste **opérateurs/pays** à activer (Orange Money BF+CI, Moov BF+CI, Telecel BF, MTN CI).

### B. Configuration (env)
`CINETPAY_MODE=sandbox` puis `live` · `CINETPAY_API_KEY` · `CINETPAY_SITE_ID` ·
`CINETPAY_SECRET_KEY` · `CINETPAY_TRANSFER_PASSWORD` · `CINETPAY_NOTIFY_URL` (**publique**) ·
`CINETPAY_WEBHOOK_IPS` (allowlist). Et le **VPS avec IP fixe whitelistée**.

### C. Validation sandbox (bout-en-bout)
- Encaissement réel : `initiate_payment` → prompt → webhook SUCCESS.
- Décaissement réel : `payout` → wallet destinataire crédité.
- **Confirmer l'ordre exact des champs HMAC** du webhook (les rejets silencieux viennent
  de là) + vérif montant + idempotence (rejeu).
- `NOTIFY_URL` publique (le webhook ne tombe pas sur localhost).
- Côté app : retour de paiement (deep link ou polling de statut).

## 8. CinetPay vs HUB2 (aide à la décision)

Même principe (les deux flux). Recommandation actuelle : **démarrer sur CinetPay**
(couverture BF+CI sûre sur les 4 opérateurs, acteur établi, **code déjà écrit**), tout
en gardant l'abstraction qui permet de **basculer vers HUB2 sans réécrire le moteur** si
le payout CinetPay déçoit en conditions réelles (latence, taux d'échec, frais en volume,
contrainte IP). HUB2 est plus « API-first » et potentiellement meilleur pour le
décaissement programmatique B2B — à réévaluer après le test de charge payout.

À confirmer auprès des deux avant de signer : liste opérateurs **payout** exacte BF/CI,
frais encaissement **et** décaissement par palier, conditions d'onboarding, plafonds,
contrainte d'IP fixe.
