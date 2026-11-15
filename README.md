# Mon planning (APK Android, 100 % gratuit)

Application de planning personnalisable : calendrier, tâches avec heure, rappel visuel des jours chargés, et personnalisation (couleur, thème clair/sombre/auto, police, arrondi des formes, image de fond). Tout est enregistré sur le téléphone.

## Obtenir l'APK sans rien installer sur ton ordinateur

1. Crée un compte gratuit sur github.com.
2. Crée un nouveau dépôt (bouton « New »), nom au choix, en **Public** ou **Private**.
3. Envoie dedans le contenu de ce dossier : `pubspec.yaml`, le dossier `lib/` et le dossier `.github/` (avec `workflows/build.yml` à l'intérieur).
   - Si le dossier caché `.github` ne se glisse pas dans le navigateur : « Add file » > « Create new file », tape `.github/workflows/build.yml` comme nom, et colle le contenu du fichier.
4. Va dans l'onglet **Actions**. La construction démarre toute seule (3 à 6 minutes). Tu peux aussi la relancer avec « Run workflow ».
5. Quand c'est vert, ouvre l'exécution et télécharge **mon-planning-apk** en bas de page (un .zip qui contient `app-release.apk`).

## Installer l'APK sur le téléphone

1. Décompresse le zip et envoie `app-release.apk` sur ton téléphone (Drive, USB, e-mail…).
2. Ouvre le fichier. Si Android le demande, autorise « Installer des applications inconnues » pour l'application que tu utilises.
3. Installe. Si Play Protect affiche un avertissement, c'est normal pour une app hors Play Store.

## Alternative : construire sur ton ordinateur

Avec Flutter installé :

```
flutter create --org com.monplanning --project-name mon_planning --platforms=android .
flutter pub get
flutter build apk --release
```

L'APK est dans `build/app/outputs/flutter-apk/app-release.apk`.

## Prochaines étapes possibles

- Widget d'écran d'accueil (tâches du jour, aux couleurs choisies)
- Notifications de rappel à l'heure de la tâche
- Tâches répétitives, catégories colorées
