use francekyoku;

-- ==============================================================================
-- Fichier d'insertion généré pour le club : CLUB LYON KYOKUSHIN
-- Source : Club Lyon Kyokushinkai.pdf
-- ==============================================================================

START TRANSACTION;

-- -----------------------------------------------------------------------------
-- 1. INSERTION DE L'ADRESSE DU CLUB
-- 66 RUE SMITH, 69002 69002
-- -----------------------------------------------------------------------------
INSERT INTO Addresses (Street, PostalCode, City, Country, Coordinates, Complement)
VALUES ('66 Rue Smith', '69002', 'Lyon', 'France', ST_PointFromText('POINT(45.74132 4.8211)', 4326), 'Halle aux Fleurs');
SET @ClubAddressId = LAST_INSERT_ID();

-- -----------------------------------------------------------------------------
-- 2. INSERTION DU CLUB
-- -----------------------------------------------------------------------------
SET @ClubId = UUID_TO_BIN(UUID());

INSERT INTO Clubs (Id, Name, Initial, Logo, Image, Presentation, Web, IsActive)
VALUES (@ClubId, 'Club Lyon Kyokushinkai', 'CLK', NULL, NULL, NULL, 'https://club-lyon-kyokushin.fr/', TRUE);

-- -----------------------------------------------------------------------------
-- 3. INSERTION DU CONTACT PRINCIPAL
-- -----------------------------------------------------------------------------
SET @ContactMainId = UUID_TO_BIN(UUID());
INSERT INTO Persons (Id, Address_Id, LastName, FirstName, Birthday, Gender, Email, Phone, Mobile)
VALUES (@ContactMainId, @ClubAddressId, 'Bergel', 'Nicolas', NULL, 'M', 'nicolas.bergel@gmail.com', NULL, '0678220968');

INSERT INTO Members (Club_Id, Person_Id) VALUES (@ClubId, @ContactMainId);
SET @MemberContactId = LAST_INSERT_ID();

INSERT INTO Contacts (Club_Id, Person_Id, Job, Email, Phone, Mobile, IsMain)
VALUES (@ClubId, @ContactMainId, 'Contact', 'nicolas.bergel@gmail.com', NULL, '0678220968', TRUE);

-- -----------------------------------------------------------------------------
-- 4. INSERTION DE L'ADRESSE DU PRÉSIDENT
-- -----------------------------------------------------------------------------
INSERT INTO Addresses (Street, PostalCode, City, Country, Coordinates)
VALUES ('50 Chemin de la Fouillouse', '69260', 'Dardilly', 'France', ST_PointFromText('POINT(45.81847 4.74154)', 4326));
SET @PresidentAddressId = LAST_INSERT_ID();

-- -----------------------------------------------------------------------------
-- 5. INSERTION DES DOJOS
-- -----------------------------------------------------------------------------
INSERT INTO Dojos (Club_Id, Address_Id, Name, IsMain)
VALUES (@ClubId, @ClubAddressId, 'Halle aux Fleurs', TRUE);

INSERT INTO Addresses (Street, PostalCode, City, Country, Coordinates, Complement)
VALUES ('32 Cours Bayard', '69002', 'Lyon', 'France', ST_PointFromText('POINT(45.74241989389823 4.824239956697269)', 4326), '');
SET @Dojo2AddressId = LAST_INSERT_ID();

INSERT INTO Dojos (Club_Id, Address_Id, Name, IsMain)
VALUES (@ClubId, @Dojo2AddressId, 'Cours Bayard', FALSE);

-- -----------------------------------------------------------------------------
-- 6. PERSONNES, MEMBRES, INSTRUCTEURS ET CONTACTS
-- -----------------------------------------------------------------------------
-- 6.1 Nicolas BERGEL (Professeur Principal)
INSERT INTO Instructors (Member_Id, Job, IsMain) VALUES (@MemberContactId, 'Instructor', TRUE);

INSERT INTO PersonsLevels (Club_Id, Person_Id, Level_Id) VALUES (@ClubId, @ContactMainId, 16);

-- 6.2 Yann BERGEL (Président)
SET @PersonPresidentId = UUID_TO_BIN(UUID());
INSERT INTO Persons (Id, Address_Id, LastName, FirstName, Birthday, Gender, Email, Phone, Mobile)
VALUES (@PersonPresidentId, @PresidentAddressId, 'Bergel', 'Yann', NULL, 'M', 'yannbergel@me.com', NULL, '0676732515');

INSERT INTO Members (Club_Id, Person_Id) VALUES (@ClubId, @PersonPresidentId);

INSERT INTO Contacts (Club_Id, Person_Id, Job, Email, Phone, Mobile)
VALUES (@ClubId, @PersonPresidentId, 'President', 'yannbergel@me.com', NULL, '0676732515');

-- 6.3  BERGELNICOLAS (créateur)
INSERT INTO Contacts (Club_Id, Person_Id, Job, Email, Phone, Mobile)
VALUES (@ClubId, @ContactMainId, 'Creator', 'nicolas.bergel@gmail.com', NULL, '0678220968');

-- 6.4 Johanna BOISSINOT (Instructeur)
SET @PersonContact4Id = UUID_TO_BIN(UUID());
INSERT INTO Persons (Id, Address_Id, LastName, FirstName, Birthday, Gender, Email, Phone, Mobile)
VALUES (@PersonContact4Id, null, 'Boissinot', 'Johanna', NULL, 'M', 'j.boissinot@free.fr', NULL, '0651633490');

INSERT INTO Members (Club_Id, Person_Id) VALUES (@ClubId, @PersonContact4Id);
SET @MemberInstructorId = LAST_INSERT_ID();

INSERT INTO Instructors (Member_Id, Job) VALUES (@MemberInstructorId, 'Instructor');

COMMIT;
