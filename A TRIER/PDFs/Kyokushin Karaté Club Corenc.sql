use francekyoku;

-- ==============================================================================
-- Fichier d'insertion généré pour le club : KYOKUSHIN KARATE CLUB CORENC
-- Source : Kyokushin Karaté Club Corenc.pdf
-- ==============================================================================

START TRANSACTION;

-- -----------------------------------------------------------------------------
-- 1. INSERTION DE L'ADRESSE DU CLUB
-- 29 AVENUE DE LA CONDAMINE, 38700 CORENC
-- -----------------------------------------------------------------------------
INSERT INTO Addresses (Street, PostalCode, City, Country, Coordinates)
VALUES ('29 Avenue De La Condamine', '38700', 'Corenc', 'France', ST_PointFromText('POINT(45.21094 5.74974)', 4326));
SET @ClubAddressId = LAST_INSERT_ID();

-- -----------------------------------------------------------------------------
-- 2. INSERTION DU CLUB
-- -----------------------------------------------------------------------------
SET @ClubId = UUID_TO_BIN(UUID());

INSERT INTO Clubs (Id, Name, Initial, Logo, Image, Presentation, Web, IsActive)
VALUES (@ClubId, 'Kyokushin Karaté Club Corenc', 'KKCC', NULL, NULL, NULL, 'https://www.facebook.com/kyokushin38/?locale=fr_FR', TRUE);

-- -----------------------------------------------------------------------------
-- 3. INSERTION DU CONTACT PRINCIPAL
-- -----------------------------------------------------------------------------
SET @ContactMainId = UUID_TO_BIN(UUID());
INSERT INTO Persons (Id, Address_Id, LastName, FirstName, Birthday, Gender, Email, Phone, Mobile)
VALUES (@ContactMainId, @ClubAddressId, 'Arnaud', 'Olivier', NULL, 'M', 'Kyokushinkai38@gmail.com', NULL, '0680011688');

INSERT INTO Members (Club_Id, Person_Id) VALUES (@ClubId, @ContactMainId);
SET @MemberContactId = LAST_INSERT_ID();

INSERT INTO Contacts (Club_Id, Person_Id, Job, Email, Phone, Mobile, IsMain)
VALUES (@ClubId, @ContactMainId, 'Contact', 'Kyokushinkai38@gmail.com', NULL, '0680011688', TRUE);

-- -----------------------------------------------------------------------------
-- 4. INSERTION DE L'ADRESSE DU PRÉSIDENT
-- -----------------------------------------------------------------------------
INSERT INTO Addresses (Street, PostalCode, City, Country, Coordinates)
VALUES ('29 Route Des Montagnes De Lans', '38250', 'Lans En Vercors', 'France', ST_PointFromText('POINT(45.12729 5.59957)', 4326));
SET @PresidentAddressId = LAST_INSERT_ID();

-- -----------------------------------------------------------------------------
-- 5. INSERTION DES DOJOS
-- -----------------------------------------------------------------------------
INSERT INTO Dojos (Club_Id, Address_Id, Name, IsMain)
VALUES (@ClubId, @ClubAddressId, 'Dojo', TRUE);

-- -----------------------------------------------------------------------------
-- 6. PERSONNES, MEMBRES, INSTRUCTEURS ET CONTACTS
-- -----------------------------------------------------------------------------
-- 6.1 Olivier ARNAUD (Professeur Principal & Président)
INSERT INTO Instructors (Member_Id, Job, IsMain) VALUES (@MemberContactId, 'Instructor', TRUE);

INSERT INTO PersonsLevels (Club_Id, Person_Id, Level_Id) VALUES (@ClubId, @ContactMainId, 14);

COMMIT;
