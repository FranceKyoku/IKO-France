use francekyoku;

-- ==============================================================================
-- Fichier d'insertion généré pour le club : KARATE KYOKUSHINKAI ROUEN / HOUPPEVILLE
-- Source : Karaté Kyokushinkai Rouen - Houppeville.pdf
-- ==============================================================================

START TRANSACTION;

-- -----------------------------------------------------------------------------
-- 1. INSERTION DE L'ADRESSE DU CLUB
-- GYMNASE / DOJO RUE ANDRE MARTIN, 76770 HOUPPEVILLE
-- -----------------------------------------------------------------------------
INSERT INTO Addresses (Street, PostalCode, City, Country, Coordinates)
VALUES ('GYMNASE / DOJO RUE ANDRE MARTIN', '76770', 'HOUPPEVILLE', 'France', ST_PointFromText('POINT(49.51107 1.07607)', 4326));
SET @ClubAddressId = LAST_INSERT_ID();

-- -----------------------------------------------------------------------------
-- 2. INSERTION DU CLUB
-- -----------------------------------------------------------------------------
SET @ClubId = UUID_TO_BIN(UUID());

INSERT INTO Clubs (Id, Name, Initial, Logo, Image, Presentation, Web, IsActive)
VALUES (@ClubId, 'Karaté Kyokushinkai Rouen / Houppeville', 'KKRH', NULL, NULL, NULL, NULL, TRUE);

-- -----------------------------------------------------------------------------
-- 3. INSERTION DU CONTACT PRINCIPAL
-- -----------------------------------------------------------------------------
SET @ContactMainId = UUID_TO_BIN(UUID());
INSERT INTO Persons (Id, Address_Id, LastName, FirstName, Birthday, Gender, Email, Phone, Mobile)
VALUES (@ContactMainId, @ClubAddressId, 'Leroux', 'Jerôme', NULL, 'M', 'jerome.leroux24@gmail.com', NULL, '0674904041');

INSERT INTO Members (Club_Id, Person_Id) VALUES (@ClubId, @ContactMainId);
SET @MemberContactId = LAST_INSERT_ID();

INSERT INTO Contacts (Club_Id, Person_Id, Job, Email, Phone, Mobile, IsMain)
VALUES (@ClubId, @ContactMainId, 'Contact/President', 'jerome.leroux24@gmail.com', NULL, '0674904041', TRUE);

-- -----------------------------------------------------------------------------
-- 4. INSERTION DE L'ADRESSE DU PRÉSIDENT
-- -----------------------------------------------------------------------------
INSERT INTO Addresses (Street, PostalCode, City, Country, Coordinates)
VALUES ('228 Rue Louis Pasteur', '76770', 'Houppeville', 'France', ST_PointFromText('POINT(49.50993 1.06922)', 4326));
SET @PresidentAddressId = LAST_INSERT_ID();

-- -----------------------------------------------------------------------------
-- 5. INSERTION DES DOJOS
-- -----------------------------------------------------------------------------
INSERT INTO Dojos (Club_Id, Address_Id, Name, IsMain)
VALUES (@ClubId, @ClubAddressId, 'Dojo', TRUE);

-- -----------------------------------------------------------------------------
-- 6. PERSONNES, MEMBRES, INSTRUCTEURS ET CONTACTS
-- -----------------------------------------------------------------------------
-- 6.1 Hervé SUGANAS (Professeur Principal)
SET @PersonTeacher1Id = UUID_TO_BIN(UUID());
INSERT INTO Persons (Id, Address_Id, LastName, FirstName, Birthday, Gender, Email, Phone, Mobile)
VALUES (@PersonTeacher1Id, @ClubAddressId, 'Suganas', 'Hervé', NULL, 'M', 'herve-suganas@poly-trade.net', NULL, '0614534501');

INSERT INTO Members (Club_Id, Person_Id) VALUES (@ClubId, @PersonTeacher1Id);
SET @MemberTeacher1Id = LAST_INSERT_ID();

INSERT INTO Instructors (Member_Id, Job, IsMain) VALUES (@MemberTeacher1Id, 'Instructor', TRUE);

INSERT INTO PersonsLevels (Club_Id, Person_Id, Level_Id) VALUES (@ClubId, @PersonTeacher1Id, 14);

-- 6.1 Éric SUGANAS (Professeur Principal)
SET @PersonTeacher2Id = UUID_TO_BIN(UUID());
INSERT INTO Persons (Id, Address_Id, LastName, FirstName, Birthday, Gender, Email, Phone, Mobile)
VALUES (@PersonTeacher2Id, @ClubAddressId, 'Suganas', 'Eric', NULL, 'M', '', NULL, '0612571717');

INSERT INTO Members (Club_Id, Person_Id) VALUES (@ClubId, @PersonTeacher2Id);
SET @MemberTeacher2Id = LAST_INSERT_ID();

INSERT INTO Instructors (Member_Id, Job, IsMain) VALUES (@MemberTeacher2Id, 'Instructor', TRUE);

INSERT INTO PersonsLevels (Club_Id, Person_Id, Level_Id) VALUES (@ClubId, @PersonTeacher2Id, 14);

-- 6.3 Herve SUGANAS (SENSEI/SECRETAIRE)
INSERT INTO Contacts (Club_Id, Person_Id, Job, Email, Phone, Mobile)
VALUES (@ClubId, @PersonTeacher1Id, 'Secretary', 'herve-suganas@poly-trade.net', NULL, '0614534501');

-- 5.4 Eric SUGANAS (SENSEI/SECRETAIRE)
INSERT INTO Contacts (Club_Id, Person_Id, Job, Email, Phone, Mobile)
VALUES (@ClubId, @PersonTeacher2Id, 'Secretary', 'eric-suganas@poly-trade.net', NULL, '0612571717');

-- 5.5 Jerôme LEROUX (PRESIDENT)

COMMIT;
