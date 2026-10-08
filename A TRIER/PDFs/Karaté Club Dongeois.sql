use francekyoku;

-- ==============================================================================
-- Fichier d'insertion généré pour le club : KARATE CLUB DONGEOIS
-- Source : Karaté Club Dongeois.pdf
-- ==============================================================================

START TRANSACTION;

-- -----------------------------------------------------------------------------
-- 1. INSERTION DE L'ADRESSE DU CLUB
-- 6 RUE DES JONCS, 44480 DONGES
-- -----------------------------------------------------------------------------
INSERT INTO Addresses (Street, PostalCode, City, Country, Coordinates)
VALUES ('6 Rue Des Joncs', '44480', 'Donges', 'France', ST_PointFromText('POINT(47.37219 -2.12801)', 4326));
SET @ClubAddressId = LAST_INSERT_ID();

-- -----------------------------------------------------------------------------
-- 2. INSERTION DU CLUB
-- -----------------------------------------------------------------------------
SET @ClubId = UUID_TO_BIN(UUID());

INSERT INTO Clubs (Id, Name, Initial, Logo, Image, Presentation, Web, IsActive)
VALUES (@ClubId, 'Karaté Club Dongeois', 'KCD', NULL, NULL, NULL, 'https://www.facebook.com/karateclubdongeois', TRUE);

-- -----------------------------------------------------------------------------
-- 3. INSERTION DU CONTACT PRINCIPAL
-- -----------------------------------------------------------------------------
SET @ContactMainId = UUID_TO_BIN(UUID());
INSERT INTO Persons (Id, Address_Id, LastName, FirstName, Birthday, Gender, Email, Phone, Mobile)
VALUES (@ContactMainId, @ClubAddressId, 'Boni', 'Cedric', NULL, 'M', 'karateclubdonges@gmail.com', NULL, '0674308612');
SET @ContactId = LAST_INSERT_ID();

INSERT INTO Members (Club_Id, Person_Id) VALUES (@ClubId, @ContactMainId);
SET @MemberContactId = LAST_INSERT_ID();

INSERT INTO Contacts (Club_Id, Person_Id, Job, Email, Phone, Mobile, IsMain)
VALUES (@ClubId, @ContactMainId, 'Contact/President', 'karateclubdonges@gmail.com', NULL, '0674308612', TRUE);

-- -----------------------------------------------------------------------------
-- 4. INSERTION DE L'ADRESSE DU PRÉSIDENT
-- -----------------------------------------------------------------------------

-- -----------------------------------------------------------------------------
-- 5. INSERTION DES DOJOS
-- -----------------------------------------------------------------------------
INSERT INTO Dojos (Club_Id, Address_Id, Name, IsMain)
VALUES (@ClubId, @ClubAddressId, 'Dojo', TRUE);

-- -----------------------------------------------------------------------------
-- 6. PERSONNES, MEMBRES, INSTRUCTEURS ET CONTACTS
-- -----------------------------------------------------------------------------
-- 6.1 Laurent DESSAINT (Professeur Principal)
SET @PersonTeacherId = UUID_TO_BIN(UUID());
INSERT INTO Persons (Id, Address_Id, LastName, FirstName, Birthday, Gender, Email, Phone, Mobile)
VALUES (@PersonTeacherId, null, 'Dessaint', 'Laurent', NULL, 'M', 'laurentdessaint@gmail.com', NULL, NULL);

INSERT INTO Members (Club_Id, Person_Id) VALUES (@ClubId, @PersonTeacherId);
SET @MemberTeacherId = LAST_INSERT_ID();

INSERT INTO Instructors (Member_Id, Job, IsMain) VALUES (@MemberTeacherId, 'Instructor', TRUE);

INSERT INTO PersonsLevels (Club_Id, Person_Id, Level_Id) VALUES (@ClubId, @PersonTeacherId, 14);

-- 5.2 Cédric BONI (Président)

COMMIT;
