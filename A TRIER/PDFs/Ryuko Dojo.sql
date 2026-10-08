use francekyoku;

-- ==============================================================================
-- Fichier d'insertion généré pour le club : RYUKO DOJO
-- Source : Ryuko Dojo.pdf
-- ==============================================================================

START TRANSACTION;

-- -----------------------------------------------------------------------------
-- 1. INSERTION DE L'ADRESSE DU CLUB
-- 860 route de Trévoux, 01600 Saint Didier de Formans
-- -----------------------------------------------------------------------------
INSERT INTO Addresses (Street, PostalCode, City, Country, Coordinates, Complement)
VALUES ('860 route de Trévoux', '01600', 'Saint Didier de Formans', 'France', ST_PointFromText('POINT(45.94946 4.78683)', 4326), '');
SET @ClubAddressId = LAST_INSERT_ID();

-- -----------------------------------------------------------------------------
-- 2. INSERTION DU CLUB
-- -----------------------------------------------------------------------------
SET @ClubId = UUID_TO_BIN(UUID());

INSERT INTO Clubs (Id, Name, Initial, Logo, Image, Presentation, Web, IsActive)
VALUES (@ClubId, 'Ryuko Dojo', 'RD', NULL, NULL, NULL, 'https://www.ryuko-dojo.com/', TRUE);

-- -----------------------------------------------------------------------------
-- 3. INSERTION DU CONTACT PRINCIPAL
-- -----------------------------------------------------------------------------
SET @ContactMainId = UUID_TO_BIN(UUID());
INSERT INTO Persons (Id, Address_Id, LastName, FirstName, Birthday, Gender, Email, Phone, Mobile)
VALUES (@ContactMainId, @ClubAddressId, 'De Koster', 'Joannes', NULL, 'M', 'j.dekoster@ryuko-dojo.com', NULL, '0616244328');

INSERT INTO Members (Club_Id, Person_Id) VALUES (@ClubId, @ContactMainId);
SET @MemberContactId = LAST_INSERT_ID();

INSERT INTO Contacts (Club_Id, Person_Id, Job, Email, Phone, Mobile, IsMain)
VALUES (@ClubId, @ContactMainId, 'Contact', 'j.dekoster@ryuko-dojo.com', NULL, '0616244328', TRUE);

-- -----------------------------------------------------------------------------
-- 4. INSERTION DE L'ADRESSE DU PRÉSIDENT
-- -----------------------------------------------------------------------------
INSERT INTO Addresses (Street, PostalCode, City, Country, Coordinates, Complement)
VALUES ('26 impasse des mirabelles', '34470', 'Pérols', 'France', ST_PointFromText('POINT(43.55999 3.96101)', 4326), '');
SET @PresidentAddressId = LAST_INSERT_ID();

-- -----------------------------------------------------------------------------
-- 5. INSERTION DES DOJOS
-- -----------------------------------------------------------------------------
INSERT INTO Addresses (Street, PostalCode, City, Country, Coordinates, Complement)
VALUES ('909 Avenue des Platanes', '34970', 'Lattes', 'France', ST_PointFromText('POINT(43.588363648332155 3.9155024154564058)', 4326), '');
SET @DojoAddressId = LAST_INSERT_ID();

INSERT INTO Dojos (Club_Id, Address_Id, Name, IsMain)
VALUES (@ClubId, @DojoAddressId, 'Dojo', TRUE);

-- -----------------------------------------------------------------------------
-- 6. PERSONNES, MEMBRES, INSTRUCTEURS ET CONTACTS
-- -----------------------------------------------------------------------------
-- 6.1 Gauthier HADERER (Professeur Principal & Président)
SET @PersonMainId = UUID_TO_BIN(UUID());
INSERT INTO Persons (Id, Address_Id, LastName, FirstName, Birthday, Gender, Email, Phone, Mobile)
VALUES (@PersonMainId, @PresidentAddressId, 'Haderer', 'Gauthier', NULL, 'M', 'gauthier.haderer@gobox.ovh', NULL, '0624576801');

INSERT INTO Members (Club_Id, Person_Id) VALUES (@ClubId, @PersonMainId);
SET @MemberTeacherId = LAST_INSERT_ID();

INSERT INTO Instructors (Member_Id, Job, IsMain) VALUES (@MemberTeacherId, 'Instructor', TRUE);

INSERT INTO Contacts (Club_Id, Person_Id, Job, Email, Phone, Mobile)
VALUES (@ClubId, @PersonMainId, 'President', 'gauthier.haderer@gobox.ovh', NULL, '0624576801');

INSERT INTO PersonsLevels (Club_Id, Person_Id, Level_Id) VALUES (@ClubId, @PersonMainId, 13);

-- 6.2 Joannes DE KOSTER (Trésorier)
INSERT INTO Contacts (Club_Id, Person_Id, Job, Email, Phone, Mobile)
VALUES (@ClubId, @ContactMainId, 'Treasurer', 'j.dekoster@ryuko-dojo.com', NULL, '0616264328');

INSERT INTO PersonsLevels (Club_Id, Person_Id, Level_Id) VALUES (@ClubId, @ContactMainId, 16);

-- 6.3 Mathieu MARTINEZ (Secrétaire)
SET @PersonContact3Id = UUID_TO_BIN(UUID());
INSERT INTO Persons (Id, Address_Id, LastName, FirstName, Birthday, Gender, Email, Phone, Mobile)
VALUES (@PersonContact3Id, null, 'Martinez', 'Mathieu', NULL, 'M', 'martinez.mathieu@hotmail.fr', NULL, '0634168005');

INSERT INTO Members (Club_Id, Person_Id) VALUES (@ClubId, @PersonContact3Id);

INSERT INTO Contacts (Club_Id, Person_Id, Job, Email, Phone, Mobile)
VALUES (@ClubId, @PersonContact3Id, 'Secretary', 'martinez.mathieu@hotmail.fr', NULL, '0634168005');

-- 5.4 David LECOMTE (Secrétaire adjoint)
SET @PersonContact4Id = UUID_TO_BIN(UUID());
INSERT INTO Persons (Id, Address_Id, LastName, FirstName, Birthday, Gender, Email, Phone, Mobile)
VALUES (@PersonContact4Id, null, 'Lecomte', 'David', NULL, 'M', 'david.lecomte34@gmail.com', NULL, '0673033332');

INSERT INTO Members (Club_Id, Person_Id) VALUES (@ClubId, @PersonContact4Id);

INSERT INTO Contacts (Club_Id, Person_Id, Job, Email, Phone, Mobile)
VALUES (@ClubId, @PersonContact4Id, 'AssistantSecretary', 'david.lecomte34@gmail.com', NULL, '0673033332');

COMMIT;
