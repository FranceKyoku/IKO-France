use francekyoku;

-- ==============================================================================
-- Fichier d'insertion généré pour le club : RYUKO DOJO
-- Source : Sekai-Kan.pdf
-- ==============================================================================

START TRANSACTION;

-- -----------------------------------------------------------------------------
-- 1. INSERTION DE L'ADRESSE DU CLUB
-- 26 rue de Pontoise, 75005 Paris
-- -----------------------------------------------------------------------------
INSERT INTO Addresses (Street, PostalCode, City, Country, Coordinates)
VALUES ('26 Rue de Pontoise', '75005', 'Paris', 'France', ST_PointFromText('POINT(48.84896 2.35124)', 4326));
SET @ClubAddressId = LAST_INSERT_ID();

-- -----------------------------------------------------------------------------
-- 2. INSERTION DU CLUB
-- -----------------------------------------------------------------------------
SET @ClubId = UUID_TO_BIN(UUID());

INSERT INTO Clubs (Id, Name, Initial, Logo, Image, Presentation, Web, IsActive)
VALUES (@ClubId, 'Sekai Kan', 'SK', NULL, NULL, NULL, 'https://sekai-kan.com', TRUE);

-- -----------------------------------------------------------------------------
-- 3. INSERTION DU CONTACT PRINCIPAL
-- -----------------------------------------------------------------------------
SET @ContactMainId = UUID_TO_BIN(UUID());
INSERT INTO Persons (Id, Address_Id, LastName, FirstName, Birthday, Gender, Email, Phone, Mobile)
VALUES (@ContactMainId, @ClubAddressId, 'Gogonel', 'Lucian', NULL, 'M', 'lucian.gogonel@gmail.com', NULL, '0667969962');

INSERT INTO Members (Club_Id, Person_Id) VALUES (@ClubId, @ContactMainId);
SET @MemberContactId = LAST_INSERT_ID();

INSERT INTO Contacts (Club_Id, Person_Id, Job, Email, Phone, Mobile, IsMain)
VALUES (@ClubId, @ContactMainId, 'Contact/President', 'lucian.gogonel@gmail.com', NULL, '0667969962', TRUE);

-- -----------------------------------------------------------------------------
-- 4. INSERTION DE L'ADRESSE DU PRÉSIDENT
-- -----------------------------------------------------------------------------
INSERT INTO Addresses (Street, PostalCode, City, Country, Coordinates)
VALUES ('10 Allée du Bocage,', '92290', 'Chatenay Malabry', 'France', ST_PointFromText('POINT(48.8566 2.3522)', 4326));
SET @PresidentAddressId = LAST_INSERT_ID();

-- -----------------------------------------------------------------------------
-- 5. INSERTION DES DOJOS
-- -----------------------------------------------------------------------------
INSERT INTO Dojos (Club_Id, Address_Id, Name, IsMain)
VALUES (@ClubId, @ClubAddressId, 'Dojo', TRUE);

-- -----------------------------------------------------------------------------
-- 6. PERSONNES, MEMBRES, INSTRUCTEURS ET CONTACTS
-- -----------------------------------------------------------------------------
-- 6.1 Lucian GOGONEL (Professeur Principal & Président)
INSERT INTO Instructors (Member_Id, Job, IsMain) VALUES (@MemberContactId, 'Instructor', TRUE);

INSERT INTO PersonsLevels (Club_Id, Person_Id, Level_Id) VALUES (@ClubId, @ContactMainId, 14);

-- 6.2 Gogonel ADRIANA (Trésorier)
SET @TreasurerId = UUID_TO_BIN(UUID());
INSERT INTO Persons (Id, Address_Id, LastName, FirstName, Birthday, Gender, Email, Phone, Mobile)
VALUES (@TreasurerId, @ClubAddressId, 'Gogonel', 'Adriana', NULL, 'M', 'adriana.gogonel@gmail.com', NULL, '0668719614');

INSERT INTO Members (Club_Id, Person_Id) VALUES (@ClubId, @TreasurerId);
SET @MemberContactId = LAST_INSERT_ID();

INSERT INTO Contacts (Club_Id, Person_Id, Job, Email, Phone, Mobile)
VALUES (@ClubId, @ContactMainId, 'Treasurer', 'adriana.gogonel@gmail.com', NULL, '0668719614');

COMMIT;
