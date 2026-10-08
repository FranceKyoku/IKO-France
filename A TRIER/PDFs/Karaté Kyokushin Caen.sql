use francekyoku;

-- ==============================================================================
-- Fichier d'insertion généré pour le club : Karaté Kyokushin Caen
-- Source : Karaté Kyokushin Caen.pdf
-- ==============================================================================

START TRANSACTION;

-- -----------------------------------------------------------------------------
-- 1. INSERTION DE L'ADRESSE DU CLUB
-- 07 Rue Des Muriers, 14940 14940
-- -----------------------------------------------------------------------------
INSERT INTO Addresses (Street, PostalCode, City, Country, Coordinates)
VALUES ('07 Rue Des Muriers', '14940', '14940', 'France', ST_PointFromText('POINT(49.17917 -0.23092)', 4326));
SET @ClubAddressId = LAST_INSERT_ID();

-- -----------------------------------------------------------------------------
-- 2. INSERTION DU CLUB
-- -----------------------------------------------------------------------------
SET @ClubId = UUID_TO_BIN(UUID());

INSERT INTO Clubs (Id, Name, Initial, Logo, Image, Presentation, Web, IsActive)
VALUES (@ClubId, 'Karaté Kyokushin Caen', 'KKC', NULL, NULL, NULL, NULL, TRUE);

-- -----------------------------------------------------------------------------
-- 3. INSERTION DU CONTACT PRINCIPAL
-- -----------------------------------------------------------------------------
SET @ContactMainId = UUID_TO_BIN(UUID());
INSERT INTO Persons (Id, Address_Id, LastName, FirstName, Birthday, Gender, Email, Phone, Mobile)
VALUES (@ContactMainId, @ClubAddressId, 'Demeautis', 'Sebastien', NULL, 'M', 'Sebastien.demeautis@gmail.com', NULL, '0610020016');

INSERT INTO Members (Club_Id, Person_Id) VALUES (@ClubId, @ContactMainId);
SET @MemberContactId = LAST_INSERT_ID();

INSERT INTO Contacts (Club_Id, Person_Id, Job, Email, Phone, Mobile, IsMain)
VALUES (@ClubId, @ContactMainId, 'Contact/President', '', NULL, '0610020016', TRUE);

-- -----------------------------------------------------------------------------
-- 4. INSERTION DE L'ADRESSE DU PRÉSIDENT
-- -----------------------------------------------------------------------------
INSERT INTO Addresses (Street, PostalCode, City, Country, Coordinates)
VALUES ('07 Rue Des Muriers,', '14940', 'Sannerville', 'France', ST_PointFromText('POINT(49.17917 -0.23092)', 4326));
SET @PresidentAddressId = LAST_INSERT_ID();

-- -----------------------------------------------------------------------------
-- 5. INSERTION DES DOJOS
-- -----------------------------------------------------------------------------
INSERT INTO Dojos (Club_Id, Address_Id, Name, IsMain)
VALUES (@ClubId, @ClubAddressId, 'Dojo', TRUE);

-- -----------------------------------------------------------------------------
-- 6. PERSONNES, MEMBRES, INSTRUCTEURS ET CONTACTS
-- -----------------------------------------------------------------------------
-- 6.1 Sebastien DEMEAUTIS (Professeur Principal & Président)
INSERT INTO Instructors (Member_Id, Job, IsMain) VALUES (@MemberContactId, 'Instructor', TRUE);

INSERT INTO PersonsLevels (Club_Id, Person_Id, Level_Id) VALUES (@ClubId, @ContactMainId, 13);

-- 6.2  LIBOIS (Secrétaire)
SET @PersonContact2Id = UUID_TO_BIN(UUID());
INSERT INTO Persons (Id, Address_Id, LastName, FirstName, Birthday, Gender, Email, Phone, Mobile)
VALUES (@PersonContact2Id, null, 'Libois', '', NULL, 'M', NULL, NULL, '0621070770');

INSERT INTO Members (Club_Id, Person_Id) VALUES (@ClubId, @PersonContact2Id);

INSERT INTO Contacts (Club_Id, Person_Id, Job, Email, Phone, Mobile)
VALUES (@ClubId, @PersonContact2Id, 'Secretary', '', NULL, '0621070770');

COMMIT;
