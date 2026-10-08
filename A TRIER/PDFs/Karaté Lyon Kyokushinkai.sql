use francekyoku;

-- ==============================================================================
-- Fichier d'insertion généré pour le club : Karaté Lyon Kyokushinkai
-- Source : Karaté Lyon Kyokushinkai.pdf
-- ==============================================================================

START TRANSACTION;

-- -----------------------------------------------------------------------------
-- 1. INSERTION DE L'ADRESSE DU CLUB
-- 68 Av. Marcel Cerdan,, 69100 Villeurbanne
-- -----------------------------------------------------------------------------
INSERT INTO Addresses (Street, PostalCode, City, Country, Coordinates)
VALUES ('68 Avenue Marcel Cerdan,', '69100', 'Villeurbanne', 'France', ST_PointFromText('POINT(45.76615 4.91002)', 4326));
SET @ClubAddressId = LAST_INSERT_ID();

-- -----------------------------------------------------------------------------
-- 2. INSERTION DU CLUB
-- -----------------------------------------------------------------------------
SET @ClubId = UUID_TO_BIN(UUID());

INSERT INTO Clubs (Id, Name, Initial, Logo, Image, Presentation, Web, IsActive)
VALUES (@ClubId, 'Karaté Lyon Kyokushinkai', 'KLK', NULL, NULL, NULL, 'https://karatelyon.tilda.ws', TRUE);

-- -----------------------------------------------------------------------------
-- 3. INSERTION DU CONTACT PRINCIPAL
-- -----------------------------------------------------------------------------
SET @ContactMainId = UUID_TO_BIN(UUID());
INSERT INTO Persons (Id, Address_Id, LastName, FirstName, Birthday, Gender, Email, Phone, Mobile)
VALUES (@ContactMainId, @ClubAddressId, 'Arutyunyan', 'Karlen', NULL, 'M', 'karatelyon@gmail.com', NULL, '0614429890');

INSERT INTO Members (Club_Id, Person_Id) VALUES (@ClubId, @ContactMainId);
SET @MemberContactId = LAST_INSERT_ID();

INSERT INTO Contacts (Club_Id, Person_Id, Job, Email, Phone, Mobile, IsMain)
VALUES (@ClubId, @ContactMainId, 'Contact/President', 'karatelyon@gmail.com', NULL, '0614429890', TRUE);

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
-- 6.1 Karlen ARUTYUNYAN (Professeur Principal & Président)
INSERT INTO Instructors (Member_Id, Job, IsMain) VALUES (@MemberContactId, 'Instructor', TRUE);

INSERT INTO PersonsLevels (Club_Id, Person_Id, Level_Id) VALUES (@ClubId, @ContactMainId, 14);

-- 6.2 Davit ARUTYUNYAN (Trésorier)
SET @PersonContact2Id = UUID_TO_BIN(UUID());
INSERT INTO Persons (Id, Address_Id, LastName, FirstName, Birthday, Gender, Email, Phone, Mobile)
VALUES (@PersonContact2Id, null, 'Arutyunyan', 'Davit', NULL, 'M', 'karatelyon@gmail.com', NULL, '0614429890');

INSERT INTO Members (Club_Id, Person_Id) VALUES (@ClubId, @PersonContact2Id);

INSERT INTO Contacts (Club_Id, Person_Id, Job, Email, Phone, Mobile)
VALUES (@ClubId, @PersonContact2Id, 'Treasurer', 'karatelyon@gmail.com', NULL, '0614429890');

-- 5.3 Keo ALINA (Secrétaire générale)
SET @PersonContact3Id = UUID_TO_BIN(UUID());
INSERT INTO Persons (Id, Address_Id, LastName, FirstName, Birthday, Gender, Email, Phone, Mobile)
VALUES (@PersonContact3Id, null, 'Alina', 'Keo', NULL, 'M', NULL, NULL, '0646794019');

INSERT INTO PersonsLevels (Club_Id, Person_Id, Level_Id) VALUES (@ClubId, @PersonContact3Id, 14);

INSERT INTO Members (Club_Id, Person_Id) VALUES (@ClubId, @PersonContact3Id);

INSERT INTO Contacts (Club_Id, Person_Id, Job, Email, Phone, Mobile)
VALUES (@ClubId, @PersonContact3Id, 'Secretary', NULL, NULL, '0646794019');

COMMIT;
