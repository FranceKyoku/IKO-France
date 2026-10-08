# Documentation Technique & Fonctionnelle : Centralisation, Synchronisation et Pilotage Multi-Clubs (Spond Club)

Cette documentation rassemble l'architecture organisationnelle, la gestion des accès liés aux cotisations, l'automatisation de la synchronisation MySQL, le déploiement d'un tableau de bord web interactif sécurisé et les solutions d'hébergement gratuit.

---

## 1. Architecture Organisationnelle dans Spond Club

Pour gérer une association comportant plusieurs clubs affiliés, vous devez utiliser la plateforme centralisée **Spond Club** (interface web) et non l'application mobile standard.

```
[ Association Centrale (Spond Club) ]
       ├── Karaté Club Lyon (ID: A1B2... | Stocké avec son Nom)
       │     ├── Section Adultes (Sous-groupe)
       │     └── Section Enfants (Sous-groupe)
       └── Karaté Club Limonest (ID: C3D4... | Stocké avec son Nom)
             ├── Section Adultes (Sous-groupe)
             └── Section Enfants (Sous-groupe)
```

*   **Niveau Central (L'Association) :** Administrateur principal de Spond Club. Il possède une vision globale de la base de données de tous les clubs, gère les intégrations et supervise la comptabilité.
*   **Niveau Local (Les Clubs Affiliés) :** Chaque club est un **Groupe** distinct. Les dirigeants locaux sont nommés administrateurs de leur groupe uniquement.
*   **Niveau Section (Les Cours/Pratiquants) :** À l'intérieur de chaque club, des **Sous-groupes** séparent les adhérents (ex: *Enfants - Débutants*, *Adultes - Ceintures Noires*).

---

## 2. Gérer les Cotisations et le Contrôle des Accès (Anti-Fraude)

Pour bloquer l'accès aux événements et aux messageries (chats) aux membres en retard de paiement, appliquez la procédure de **Suspension**.

### Étape 1 : Création de la campagne de paiement
1. Dans Spond Club, accédez à l'onglet **Paiements**.
2. Créez une **Demande de paiement** intitulée *"Cotisation Annuelle"*.
3. Configurez vos différents tarifs (ex: Enfants, Adultes) et fixez une **date limite de paiement**.

### Étape 2 : Sanction des membres non payants
1. Une fois la date limite dépassée, filtrez les membres dont le statut de paiement est *"En retard"*.
2. Sélectionnez ces membres et modifiez leur statut général en **"Suspendu"**.

### Étape 3 : Conséquences de la suspension
*   **Côté Adhérent :** Le membre est instantanément retiré de tous ses sous-groupes actifs. Sur son application Spond, les clubs et sections disparaissent. Il n'a plus accès au calendrier, aux événements, et ne peut plus lire ni écrire dans les chats.
*   **Réactivation :** Dès que le membre paye, repassez son statut à **"Actif"**. Il réintègre automatiquement tous ses anciens groupes instantanément.

---

## 3. Récupération des IDs de vos Groupes Spond

Pour que le script Python sache quels clubs interroger, vous devez obtenir l'identifiant unique (ID) de chaque groupe. 

### Méthode 1 : Via l'interface Web (La plus simple)
1. Connectez-vous à votre compte sur spond.com depuis un ordinateur.
2. Cliquez sur le **Club Affilié (Groupe)** de votre choix dans le menu de gauche.
3. Regardez l'adresse URL dans la barre de votre navigateur : `https://spond.com/v2/group/A1B2C3D4E5F6`
4. La suite de caractères à la fin (`A1B2C3D4E5F6`) correspond à l'**ID de votre groupe**.

### Méthode 2 : Automatique (Via le script)
Le script extrait automatiquement à la fois l'ID et le **Nom clair** du club (ex: "Karaté Club Limonest") directement depuis votre compte Spond lors de sa boucle d'exécution.

---

## 4. Synchronisation Automatique Multi-Clubs vers MySQL

La synchronisation s'effectue par **Polling** (interrogations régulières) via un script Python qui boucle sur l'ensemble de vos clubs.

### 4.1 Structure de la table MySQL de destination
La table inclut le champ `group_name` pour stocker le nom textuel du club en clair, ainsi que `group_description` pour la présentation du club et `custom_fields` (au format JSON) pour tous les champs personnalisés définis dans Spond (ceinture, licence, certificat, etc.).

Un fichier prêt à l'emploi `schema.sql` est disponible à la racine du projet.

```sql
CREATE TABLE IF NOT EXISTS spond_members (
    spond_uid VARCHAR(50) NOT NULL,
    group_id VARCHAR(50) NOT NULL,
    group_name VARCHAR(150),                    -- Nom réel du club (ex: Club Lyon Kyokushinkai)
    group_description TEXT,                     -- Présentation / description du club
    first_name VARCHAR(100),
    last_name VARCHAR(100),
    email VARCHAR(150),
    membership_status VARCHAR(50),              -- Statut ('member' = actif, autre = suspendu/en attente)
    custom_fields JSON,                         -- Données personnalisées Spond sous forme JSON
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (spond_uid, group_id)           -- Clé composite
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
```

> **Migration si votre table existait déjà :**
> ```sql
> ALTER TABLE spond_members 
> ADD COLUMN group_description TEXT NULL AFTER group_name,
> ADD COLUMN custom_fields JSON NULL AFTER membership_status;
> ```

### 4.2 Script Python Multi-Clubs Sécurisé (main.py)
Ce script utilise des **variables d'environnement** (`os.environ`) ou un fichier local `.env` (`python-dotenv`) au lieu d'écrire les mots de passe en clair dans le code.

Il gère automatiquement :
* La récupération de la **description de chaque club**.
* Le **mapping des champs personnalisés** (`fieldDefs`) pour associer chaque valeur du membre au nom réel du champ (ex: `"Numéro de licence"`, `"Taille kimono"`).
* L'insertion ou mise à jour sans doublon (`ON DUPLICATE KEY UPDATE`) compatible avec MySQL 8+.

```python
from dotenv import load_dotenv
load_dotenv()

import os
import json
import asyncio
import mysql.connector
from mysql.connector import errorcode
from spond import spond

# --- Récupération Sécurisée des Variables d'Environnement ---
SPOND_USERNAME = os.environ.get("SPOND_USERNAME")
SPOND_PASSWORD = os.environ.get("SPOND_PASSWORD")

DB_CONFIG = {
    'user': os.environ.get("DB_USER"),
    'password': os.environ.get("DB_PASSWORD"),
    'host': os.environ.get("DB_HOST"),
    'database': os.environ.get("DB_NAME"),
    'raise_on_warnings': False
}

def sync_to_mysql(group_id, group_name, group_description, field_map, members_data):
    try:
        conn = mysql.connector.connect(**DB_CONFIG)
        cursor = conn.cursor()
        
        query = """
            INSERT INTO spond_members (spond_uid, group_id, group_name, group_description, first_name, last_name, email, membership_status, custom_fields)
            VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s) AS new_row
            ON DUPLICATE KEY UPDATE 
                group_name = new_row.group_name,
                group_description = new_row.group_description,
                first_name = new_row.first_name,
                last_name = new_row.last_name,
                email = new_row.email,
                membership_status = new_row.membership_status,
                custom_fields = new_row.custom_fields;
        """
        
        records_updated = 0
        for m in members_data:
            profile = m.get('profile', {})
            uid = profile.get('id') or m.get('id')
            first_name = profile.get('firstName') or m.get('firstName', '')
            last_name = profile.get('lastName') or m.get('lastName', '')
            email = profile.get('email') or m.get('email', '')
            status = m.get('status', 'active') 
            
            # Extraction et résolution des champs personnalisés
            raw_fields = m.get('fields', {})
            custom_data = {}
            if isinstance(raw_fields, dict):
                for fid, fval in raw_fields.items():
                    label = field_map.get(fid, fid)
                    custom_data[label] = fval.get('value') if isinstance(fval, dict) else fval
            
            custom_fields_json = json.dumps(custom_data, ensure_ascii=False) if custom_data else None
            
            if uid:
                cursor.execute(query, (uid, group_id, group_name, group_description, first_name, last_name, email, status, custom_fields_json))
                records_updated += 1
        
        conn.commit()
        print(f" -> [{group_name}] Synchronisation réussie : {records_updated} membres traités.")
        
    except mysql.connector.Error as err:
        print(f" -> Erreur MySQL pour le groupe {group_name} : {err}")
    finally:
        if 'conn' in locals() and conn.is_connected():
            cursor.close()
            conn.close()

async def main():
    if not SPOND_USERNAME or not SPOND_PASSWORD:
        print("Erreur : Les identifiants Spond ne sont pas configurés dans l'environnement.")
        return

    print("Initialisation de la connexion avec l'API Spond...")
    s = spond.Spond(username=SPOND_USERNAME, password=SPOND_PASSWORD)
    
    try:
        groups = await s.get_groups()
        if not groups:
            print("Aucun groupe trouvé.")
            return
            
        for g in groups:
            group_id = g.get('id')
            group_details = await s.get_group(group_id)
            group_name = group_details.get('name') or g.get('name', 'Nom inconnu')
            group_description = group_details.get('description') or g.get('description') or ''
            
            # Mapping des définitions de champs personnalisés du club
            field_defs = group_details.get('fieldDefs') or []
            field_map = {f['id']: f.get('name', f['id']) for f in field_defs if isinstance(f, dict) and 'id' in f}
            
            print(f"Traitement du Club : '{group_name}' (ID: {group_id})")
            
            members = group_details.get('members', [])
            if members:
                sync_to_mysql(group_id, group_name, group_description, field_map, members)
                
    except Exception as e:
        print(f"Échec critique de l'interrogation de l'API Spond : {e}")
    finally:
        await s.clientsession.close()

if __name__ == "__main__":
    asyncio.run(main())
```

### 4.3 Tester le Script Python en Local (Sur votre ordinateur)

Avant de déployer votre script sur GitHub Actions, il est recommandé de s'assurer de sa bonne exécution localement. Comme le code utilise des variables d'environnement pour des raisons de sécurité, suivez cette procédure pour le lancer.

1. Installez les bibliothèques nécessaires sur votre machine :
   Ouvrez votre terminal (Mac/Linux) ou votre invite de commandes (Windows) et exécutez :
   pip install spond mysql-connector-python

2. Créez les variables d'environnement temporaires :
   Pour éviter de modifier le code, vous devez injecter vos identifiants directement dans votre terminal avant de démarrer le script.

   Sous Windows (Invite de commandes CMD) :
   set SPOND_USERNAME=votre_email@association.com
   set SPOND_PASSWORD=VotreMotDePasseSpond
   set DB_HOST=mysql-votrecompte.alwaysdata.net
   set DB_USER=votre_utilisateur_mysql
   set DB_PASSWORD=votre_mot_de_passe_mysql
   set DB_NAME=nom_de_votre_base_complete

   Sous Windows (PowerShell) :
   $env:SPOND_USERNAME="votre_email@association.com"
   $env:SPOND_PASSWORD="VotreMotDePasseSpond"
   $env:DB_HOST="mysql-votrecompte.alwaysdata.net"
   $env:DB_USER="votre_utilisateur_mysql"
   $env:DB_PASSWORD="votre_mot_de_passe_mysql"
   $env:DB_NAME="nom_de_votre_base_complete"

   Sous Mac ou Linux (Terminal) :
   export SPOND_USERNAME="votre_email@association.com"
   export SPOND_PASSWORD="VotreMotDePasseSpond"
   export DB_HOST="mysql-votrecompte.alwaysdata.net"
   export DB_USER="votre_utilisateur_mysql"
   export DB_PASSWORD="votre_mot_de_passe_mysql"
   export DB_NAME="nom_de_votre_base_complete"

3. Lancez le script :
   Placez-vous dans le dossier de votre fichier `main.py` et exécutez :
   python main.py

   Si le terminal affiche la liste de vos clubs suivie de la mention "Synchronisation réussie", votre configuration est valide. Vous pouvez fermer le terminal : les variables d'environnement de test s'effaceront automatiquement de la mémoire de votre ordinateur.


---

## 5. Tableau de Bord Web Protégé par Mot de Passe (PHP / Tailwind CSS)

Ce code source réunit la **page de connexion sécurisée** et le **tableau de bord interactif** au sein d'un seul fichier `index.php`. L'accès est protégé via le mécanisme natif des sessions PHP.

```php
<?php
// 1. Initialisation de la session de sécurité
session_start();

// --- CONFIGURATION DU COMPTE ADMINISTRATEUR DU DASHBOARD ---
define('ADMIN_USER', 'admin_federation');
define('ADMIN_PASS', 'KaratéClub2026!'); // Modifiez ce mot de passe avant mise en ligne

// Gestion de la déconnexion
if (isset($_GET['action']) && $_GET['action'] === 'logout') {
    session_destroy();
    header('Location: index.php');
    exit;
}

// Traitement du formulaire de connexion
$login_error = '';
if ($_SERVER['REQUEST_METHOD'] === 'POST' && isset($_POST['username'], $_POST['password'])) {
    if ($_POST['username'] === ADMIN_USER && $_POST['password'] === ADMIN_PASS) {
        $_SESSION['authenticated'] = true;
        header('Location: index.php');
        exit;
    } else {
        $login_error = 'Identifiant ou mot de passe incorrect.';
    }
}

// Si l'utilisateur n'est pas connecté, on affiche l'écran de Login
if (!isset($_SESSION['authenticated']) || $_SESSION['authenticated'] !== true):
?>
<!DOCTYPE html>
<html lang="fr">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Connexion - Gestion Karaté</title>
    <script src="https://cdn.tailwindcss.com"></script>
</head>
<body class="bg-gray-900 flex items-center justify-center h-screen">
    <div class="bg-white p-8 rounded-xl shadow-2xl w-full max-w-md border border-gray-200">
        <div class="text-center mb-6">
            <span class="text-4xl">🥋</span>
            <h1 class="text-2xl font-bold text-gray-900 mt-2">Fédération de Karaté</h1>
            <p class="text-sm text-gray-500 mt-1">Accès réservé aux administrateurs</p>
        </div>

        <?php if (!empty($login_error)): ?>
            <div class="bg-red-50 text-red-600 p-3 rounded-lg text-sm font-semibold mb-4 border border-red-200">
                <?= htmlspecialchars($login_error) ?>
            </div>
        <?php endif; ?>

        <form method="POST" action="index.php" class="space-y-4">
            <div>
                <label class="block text-sm font-bold text-gray-700 mb-1">Identifiant</label>
                <input type="text" name="username" required class="w-full border border-gray-300 rounded-lg p-2.5 focus:ring-2 focus:ring-blue-500 focus:border-blue-500 outline-none">
            </div>
            <div>
                <label class="block text-sm font-bold text-gray-700 mb-1">Mot de passe</label>
                <input type="password" name="password" required class="w-full border border-gray-300 rounded-lg p-2.5 focus:ring-2 focus:ring-blue-500 focus:border-blue-500 outline-none">
            </div>
            <button type="submit" class="w-full bg-gray-900 hover:bg-gray-800 text-white font-bold p-3 rounded-lg transition duration-200">
                Se connecter
            </button>
        </form>
    </div>
</body>
</html>
<?php 
exit; // Bloque la suite du script tant que l'authentification n'est pas validée
endif; 

// --- CONNEXION À LA BASE DE DONNÉES (ACCESSIBLE UNIQUEMENT SI CONNECTÉ) ---
$host = '127.0.0.1';
$db   = 'nom_de_votre_base';
$user = 'votre_utilisateur_db';
$pass = 'votre_mot_de_passe_db';
$charset = 'utf8mb4';

$dsn = "mysql:host=$host;dbname=$db;charset=$charset";
try {
     $pdo = new PDO($dsn, $user, $pass, [PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION]);
} catch (\PDOException $e) {
     die("Erreur de connexion à la base de données : " . $e->getMessage());
}

// Récupération des filtres et calculs statistiques
$list_clubs_query = $pdo->query("SELECT DISTINCT group_name FROM spond_members WHERE group_name IS NOT NULL AND group_name != '' ORDER BY group_name ASC");
$all_clubs = $list_clubs_query->fetchAll(PDO::FETCH_COLUMN);

$selected_club = isset($_GET['club']) ? $_GET['club'] : '';

if (!empty($selected_club)) {
    $stmt1 = $pdo->prepare("SELECT COUNT(DISTINCT spond_uid) FROM spond_members WHERE group_name = ?");
    $stmt1->execute([$selected_club]); $total_members = $stmt1->fetchColumn();

    $stmt2 = $pdo->prepare("SELECT COUNT(*) FROM spond_members WHERE membership_status = 'member' AND group_name = ?");
    $stmt2->execute([$selected_club]); $total_active = $stmt2->fetchColumn();

    $stmt3 = $pdo->prepare("SELECT COUNT(*) FROM spond_members WHERE membership_status != 'member' AND group_name = ?");
    $stmt3->execute([$selected_club]); $total_suspended = $stmt3->fetchColumn();

    $stmt_list = $pdo->prepare("SELECT first_name, last_name, email, group_name FROM spond_members WHERE membership_status != 'member' AND group_name = ? ORDER BY last_name ASC");
    $stmt_list->execute([$selected_club]); $suspended_members = $stmt_list->fetchAll(PDO::FETCH_ASSOC);
} else {
    $total_members = $pdo->query("SELECT COUNT(DISTINCT spond_uid) FROM spond_members")->fetchColumn();
    $total_active = $pdo->query("SELECT COUNT(*) FROM spond_members WHERE membership_status = 'member'")->fetchColumn();
    $total_suspended = $pdo->query("SELECT COUNT(*) FROM spond_members WHERE membership_status != 'member'")->fetchColumn();
    $suspended_members = $pdo->query("SELECT first_name, last_name, email, group_name FROM spond_members WHERE membership_status != 'member' ORDER BY group_name ASC, last_name ASC")->fetchAll(PDO::FETCH_ASSOC);
}

$clubs_summary = $pdo->query("SELECT group_name, COUNT(*) as count FROM spond_members GROUP BY group_name ORDER BY group_name ASC")->fetchAll(PDO::FETCH_ASSOC);
?>
<!DOCTYPE html>
<html lang="fr">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Fédération Karaté - Dashboard Spond</title>
    <script src="https://cdn.tailwindcss.com"></script>
</head>
<body class="bg-gray-100 text-gray-800 font-sans">
    <div class="flex h-screen overflow-hidden">
        <!-- Barre latérale -->
        <div class="w-64 bg-gray-900 text-white p-6 flex flex-col justify-between hidden md:flex">
            <div>
                <h1 class="text-xl font-bold border-b border-gray-700 pb-4 mb-6">🥋 Karaté Gestion</h1>
                <nav class="space-y-2">
                    <a href="index.php" class="block py-2.5 px-4 rounded <?= empty($selected_club) ? 'bg-blue-600 font-medium' : 'hover:bg-gray-800 text-gray-400 hover:text-white' ?>">Vue Globale</a>
                    <div class="pt-4">
                        <p class="px-4 text-xs uppercase font-bold text-gray-500 mb-2">Raccourcis Clubs</p>
                        <?php foreach($clubs_summary as $c): ?>
                            <a href="index.php?club=<?= urlencode($c['group_name']) ?>" class="block py-1.5 px-4 text-sm rounded truncate <?= $selected_club === $c['group_name'] ? 'text-blue-400 font-bold bg-gray-800' : 'text-gray-400 hover:bg-gray-800' ?>">
                                <?= htmlspecialchars($c['group_name']) ?>
                            </a>
                        <?php endforeach; ?>
                    </div>
                </nav>
            </div>
            <!-- Bouton Déconnexion -->
            <a href="index.php?action=logout" class="block bg-red-600/20 hover:bg-red-600 text-red-400 hover:text-white text-center font-bold py-2 px-4 rounded-lg transition duration-150">
                Déconnexion
            </a>
        </div>

        <!-- Contenu principal -->
        <div class="flex-1 flex flex-col overflow-y-auto p-8">
            <header class="flex flex-col sm:flex-row justify-between items-start sm:items-center gap-4 mb-8">
                <div>
                    <h2 class="text-3xl font-bold text-gray-900"><?= empty($selected_club) ? "Tableau de Bord Association" : htmlspecialchars($selected_club) ?></h2>
                </div>
                <form method="GET" action="index.php" class="bg-white p-2 rounded-lg shadow-sm border flex items-center gap-2">
                    <select name="club" onchange="this.form.submit()" class="bg-gray-50 border border-gray-300 text-gray-900 text-sm rounded-lg p-2 font-medium">
                        <option value="">Tous les clubs affiliés</option>
                        <?php foreach($all_clubs as $club_name): ?>
                            <option value="<?= htmlspecialchars($club_name) ?>" <?= $selected_club === $club_name ? 'selected' : '' ?>><?= htmlspecialchars($club_name) ?></option>
                        <?php endforeach; ?>
                    </select>
                </form>
            </header>

            <div class="grid grid-cols-1 md:grid-cols-3 gap-6 mb-8">
                <div class="bg-white p-6 rounded-lg shadow-sm border border-gray-200"><p class="text-sm text-gray-500 uppercase font-bold">Pratiquants</p><p class="text-3xl font-bold text-gray-900 mt-1"><?= $total_members ?></p></div>
                <div class="bg-white p-6 rounded-lg shadow-sm border border-gray-200 border-l-4 border-l-green-500"><p class="text-sm text-gray-500 uppercase font-bold">Actifs (À jour)</p><p class="text-3xl font-bold text-green-600 mt-1"><?= $total_active ?></p></div>
                <div class="bg-white p-6 rounded-lg shadow-sm border border-gray-200 border-l-4 border-l-red-500"><p class="text-sm text-gray-500 uppercase font-bold">Suspendus</p><p class="text-3xl font-bold text-red-600 mt-1"><?= $total_suspended ?></p></div>
            </div>

            <div class="grid grid-cols-1 lg:grid-cols-3 gap-8">
                <div class="bg-white p-6 rounded-lg shadow-sm border border-gray-200 lg:col-span-1">
                    <h3 class="text-lg font-bold mb-4 border-b pb-2">Résumé des Structures</h3>
                    <div class="space-y-3">
                        <?php foreach($clubs_summary as $club): ?>
                            <div class="flex justify-between items-center bg-gray-50 p-3 rounded-md <?= $selected_club === $club['group_name'] ? 'ring-2 ring-blue-500' : '' ?>">
                                <span class="font-semibold text-gray-700 text-sm"><?= htmlspecialchars($club['group_name']) ?></span>
                                <span class="bg-blue-100 text-blue-800 text-xs px-2.5 py-1 rounded-full font-bold"><?= $club['count'] ?> membres</span>
                            </div>
                        <?php endforeach; ?>
                    </div>
                </div>

                <div class="bg-white p-6 rounded-lg shadow-sm border border-gray-200 lg:col-span-2">
                    <h3 class="text-lg font-bold mb-4 border-b pb-2 text-red-600">⚠️ Alertes Cotisations Manquantes</h3>
                    <table class="w-full text-left border-collapse text-sm">
                        <thead>
                            <tr class="bg-gray-50 text-gray-500 text-xs border-b"><th class="py-3 px-4">Nom / Prénom</th><th class="py-3 px-4">Email</th><th class="py-3 px-4">Club rattaché</th></tr>
                        </thead>
                        <tbody class="divide-y divide-gray-100">
                            <?php foreach($suspended_members as $member): ?>
                                <tr>
                                    <td class="py-3 px-4 font-semibold"><?= htmlspecialchars($member['last_name'] . ' ' . $member['first_name']) ?></td>
                                    <td class="py-3 px-4"><?= htmlspecialchars($member['email']) ?></td>
                                    <td class="py-3 px-4"><?= htmlspecialchars($member['group_name']) ?></td>
                                </tr>
                            <?php endforeach; ?>
                        </tbody>
                    </table>
                </div>
            </div>
        </div>
    </div>
</body>
</html>
```

---

## 6. Guide d'Hébergement Gratuit et Configuration des Secrets GitHub

### 6.1 Automatisation Gratuite avec GitHub Actions
GitHub Actions permet d'exécuter gratuitement le script Python toutes les 30 minutes. Placez votre workflow dans le fichier `.github/workflows/sync.yml` :

```yaml
name: Spond Sync Automation
on:
  schedule:
    - cron: '*/30 * * * *'
  workflow_dispatch:
jobs:
  run-sync:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with:
          python-version: '3.10'
      - run: pip install spond mysql-connector-python
      - run: python main.py
        env:
          SPOND_USERNAME: ${{ secrets.SPOND_USERNAME }}
          SPOND_PASSWORD: ${{ secrets.SPOND_PASSWORD }}
          DB_HOST: ${{ secrets.DB_HOST }}
          DB_USER: ${{ secrets.DB_USER }}
          DB_PASSWORD: ${{ secrets.DB_PASSWORD }}
          DB_NAME: ${{ secrets.DB_NAME }}
```

### 6.2 Comment configurer les GitHub Secrets (Étape par Étape)
Pour masquer vos accès de façon sécurisée :

1. Ouvrez votre dépôt sur **GitHub** et cliquez sur l'onglet **⚙️ Settings** (Paramètres).
2. Dans la barre latérale gauche, cliquez sur **Secrets and variables** > **Actions**.
3. Cliquez sur le bouton **New repository secret** pour ajouter les 6 secrets requis :

| Nom du Secret (`Name`) | Valeur à renseigner (`Secret`) |
| :--- | :--- |
| `SPOND_USERNAME` | L'adresse email de connexion à votre compte Spond Club. |
| `SPOND_PASSWORD` | Le mot de passe associé à votre compte Spond. |
| `DB_HOST` | L'hôte MySQL (Ex chez Alwaysdata : `mysql-votrecompte.alwaysdata.net`). |
| `DB_USER` | L'identifiant utilisateur de votre base de données MySQL. |
| `DB_PASSWORD` | Le mot de passe de connexion à votre base de données MySQL. |
| `DB_NAME` | Le nom exact de la base de données MySQL créée. |

4. Validez chaque entrée avec **Add secret**. Le robot d'automatisation GitHub dispose désormais des droits requis de manière chiffrée et masquée.

### 6.3 Hébergement Gratuit de la base de données MySQL
Pour stocker vos données de façon sécurisée et sans frais, vous avez besoin d'un service gérant conjointement PHP (pour le tableau de bord) et MySQL (pour le script de synchronisation).

L'option Tout-en-un recommandée : Alwaysdata (Plan Gratuit)
1. Créez un compte gratuitement sur alwaysdata.com. L'offre gratuite octroie 100 Mo d'espace, ce qui est suffisant pour stocker des dizaines de milliers de profils d'adhérents de karaté.
2. Allez dans l'onglet Bases de données > MySQL et créez une nouvelle base. Notez le nom complet généré.
3. Créez un utilisateur MySQL, attribuez-lui un mot de passe fort et donnez-lui tous les privilèges sur votre nouvelle base de données.
4. Récupérez votre Hôte de connexion spécifié dans votre interface (il ressemble généralement à mysql-votrecompte.alwaysdata.net). Renseignez cette valeur dans le secret GitHub DB_HOST.
5. Déposez votre code index.php par FTP ou via l'explorateur web interne de Alwaysdata pour que votre tableau de bord soit accessible en ligne.