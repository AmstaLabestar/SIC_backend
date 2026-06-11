Home Screen Fintech Premium - Flutter Design System

Vision Produit

Créer une expérience fintech premium inspirée de Revolut, Nubank, Monzo et Apple Wallet.
Objectifs :

Inspirer confiance

Réduire la charge cognitive

Mettre l'argent au centre de l'expérience

Créer une sensation de fluidité et de légèreté

Donner une impression haut de gamme sans être ostentatoire

Design Language

Style

Soft UI moderne + Glassmorphism subtil
Ne pas utiliser :

grosses ombres

couleurs saturées

cartes trop contrastées

gradients agressifs

Privilégier :

surfaces lumineuses

ombres diffuses

coins arrondis généreux

animations discrètes

micro interactions

Palette

Couleur principale

Primary Blue
#2455D8
Gradient Principal
Start:
#2455D8
End:
#2CC89D

Couleurs secondaires

Success
#21C87A
Warning
#F4A621
Danger
#E5484D
Background
#F5F7FB
Card
#FFFFFF
Text Primary
#0F172A
Text Secondary
#667085
Border
#E7ECF4

Typographie

Utiliser exclusivement :
Font Family:
Inter
Fallback:
SF Pro Display

Hiérarchie

Balance
FontWeight.w800
48-52
LetterSpacing:
-1.5
Titre section
FontWeight.w700
32
Nom opérateur
FontWeight.w700
22
Montant SIM
FontWeight.w800
38
Texte secondaire
FontWeight.w500
16
Micro labels
FontWeight.w600
13

Structure

SafeArea
CustomScrollView
Sections :

Header

Balance Card

SIM Cards

Quick Actions

Promotional Banner

Bottom Navigation

Header

Contient :

Avatar

Message de bienvenue

Nom utilisateur

Notifications

Aide

Messages

Hauteur :
110
Animation :
Au scroll :

avatar réduit légèrement

titre se compacte

icônes deviennent flottantes

Duration :
250ms
Curve :
easeOutCubic

Balance Card

Pièce maîtresse de l'écran
Hauteur :
240
Radius :
36
Gradient :
Blue → Emerald
Ajouter :

formes floues géantes en arrière-plan

léger effet verre

effet de profondeur

Animation :
Au chargement :
Fade + Slide Up
500ms
Montant principal :
Très grand
Poids visuel dominant
Doit être visible instantanément.
Bouton masquer le solde
Interaction :
Tap :

transition fluide

blur du montant

crossfade

Duration :
200ms

Cartes SIM

Utiliser un Carousel horizontal.
Hauteur :
220
Largeur :
300
Radius :
28
Chaque carte contient :
Logo opérateur
Numéro masqué
Montant
Statut
Actions rapides

Historique

Recharger

Interaction
Swipe :
Scale dynamique
Carte active :
scale 1.0
Carte inactive :
scale 0.93
Ajouter :
Parallax léger
Durée :
300ms

Quick Actions

Utiliser GridView 2 colonnes.
Espacement :
18
Hauteur :
120
Icônes
Fond dégradé subtil
Coins :
24
Interaction
Tap :
Scale :
1 → 0.97 → 1
Durée :
120ms
Ripple très léger

Bannière

Ne jamais utiliser une image statique.
Construire :
Illustration SVG
Icône téléphone
Carte bancaire
Graphique ascendant
Pièces
Animation :
Lottie
Très discrète
Boucle lente
8 secondes

Bottom Navigation

Fond blanc
Radius supérieur :
32
Icône active
Couleur :
Primary Blue
Indicateur actif
Petit point animé
Sous l'icône
Transition entre onglets
FadeThrough
Durée :
250ms

Micro Interactions

Solde

Compteur animé
Utiliser :
TweenAnimationBuilder

Cartes SIM

Hover mobile :
Glow léger

Notifications

Badge animé
Pulse toutes les 12 secondes

Chargement

Skeleton Shimmer
Ne jamais afficher un spinner vide.

Performance

Utiliser :
const widgets
RepaintBoundary
CachedNetworkImage
PageStorageKey
Riverpod
Freezed
GoRouter

Sensation recherchée

L'utilisateur doit ressentir :

sécurité

modernité

fluidité

simplicité

contrôle de son argent

Si un élément attire plus l'attention que le solde principal alors le design est incorrect.
