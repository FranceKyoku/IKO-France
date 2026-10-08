-- ==============================================================================
-- Schéma de Base de Données - Centralisation Spond Club (France Kyokushin)
-- ==============================================================================

-- 1. Création de la table principale
CREATE TABLE IF NOT EXISTS spond_members (
    spond_uid VARCHAR(50) NOT NULL,
    group_id VARCHAR(50) NOT NULL,
    group_name VARCHAR(150),                    -- Nom clair du club (ex: Club Lyon Kyokushinkai)
    group_description TEXT,                     -- Description / présentation du club issue de Spond
    first_name VARCHAR(100),
    last_name VARCHAR(100),
    email VARCHAR(150),
    membership_status VARCHAR(50),              -- Statut ('member' = actif, autre = suspendu/en attente)
    custom_fields JSON,                         -- Champs personnalisés (Ceinture, Licence, Certificat...) au format JSON
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (spond_uid, group_id)           -- Clé composite : un membre peut appartenir à plusieurs clubs
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 2. Script de migration (si la table existait déjà avec l'ancien schéma) :
-- ALTER TABLE spond_members ADD COLUMN group_description TEXT NULL AFTER group_name;
-- ALTER TABLE spond_members ADD COLUMN custom_fields JSON NULL AFTER membership_status;
