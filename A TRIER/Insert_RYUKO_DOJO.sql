-- ==============================================================================
-- Fichier d'insertion généré pour le club : RYUKO DOJO
-- Source : Ryuko_Dojo.pdf
-- ==============================================================================

START TRANSACTION;

-- -----------------------------------------------------------------------------
-- 0. INITIALISATION DES CHAMPS PERSONNALISÉS (Translates & CustomFields)
-- -----------------------------------------------------------------------------
INSERT INTO Translates (Code, Fr, En)
VALUES 
    ('GRADE', 'Grade / Dan', 'Grade / Dan'),
    ('SENIORITY', 'Ancienneté au club', 'Club Seniority'),
    ('WEBSITE', 'Site web', 'Website')
ON DUPLICATE KEY UPDATE Fr = VALUES(Fr), En = VALUES(En);

INSERT INTO CustomFields (Name_Code)
SELECT 'GRADE' FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM CustomFields WHERE Name_Code = 'GRADE');
SET @FieldGradeId = (SELECT Id FROM CustomFields WHERE Name_Code = 'GRADE' LIMIT 1);

INSERT INTO CustomFields (Name_Code)
SELECT 'SENIORITY' FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM CustomFields WHERE Name_Code = 'SENIORITY');
SET @FieldSeniorityId = (SELECT Id FROM CustomFields WHERE Name_Code = 'SENIORITY' LIMIT 1);

INSERT INTO CustomFields (Name_Code)
SELECT 'WEBSITE' FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM CustomFields WHERE Name_Code = 'WEBSITE');
SET @FieldWebsiteId = (SELECT Id FROM CustomFields WHERE Name_Code = 'WEBSITE' LIMIT 1);

-- -----------------------------------------------------------------------------
-- 1. INSERTION DU CLUB
-- -----------------------------------------------------------------------------
SET @ClubId = UUID_TO_BIN(UUID());

INSERT INTO Clubs (Id, Initial, Logo, Image, Presentation, Web, IsActive)
VALUES (@ClubId, 'RD', NULL, NULL, NULL, 'https://www.ryuko-dojo.com/', TRUE);

-- -----------------------------------------------------------------------------
-- 2. INSERTION DE L'ADRESSE DU DOJO PRINCIPAL
-- 860 route de Trévoux, 01600 Saint Didier de Formans
-- -----------------------------------------------------------------------------
INSERT INTO Addresses (Street, PostalCode, City, Country, Coordinates)
VALUES ('860 route de Trévoux', '01600', 'Saint Didier de Formans', 'France', ST_PointFromText('POINT(45.94946 4.78683)', 4326));
SET @DojoAddressId = LAST_INSERT_ID();

-- -----------------------------------------------------------------------------
-- 3. INSERTION DU DOJO PRINCIPAL
-- -----------------------------------------------------------------------------
INSERT INTO Dojos (Club_Id, Address_Id, Name, IsMain)
VALUES (@ClubId, @DojoAddressId, 'RYUKO DOJO', TRUE);
SET @DojoId = LAST_INSERT_ID();

-- -----------------------------------------------------------------------------
-- 4. INSERTION DE L'ADRESSE DU PRÉSIDENT
-- 26 impasse des mirabelles, 34470 Pérols
-- -----------------------------------------------------------------------------
INSERT INTO Addresses (Street, PostalCode, City, Country, Coordinates)
VALUES ('26 impasse des mirabelles', '34470', 'Pérols', 'France', ST_PointFromText('POINT(43.55999 3.96101)', 4326));
SET @PresidentAddressId = LAST_INSERT_ID();

-- -----------------------------------------------------------------------------
-- 5. PERSONNES, MEMBRES, INSTRUCTEURS ET CONTACTS
-- -----------------------------------------------------------------------------
-- 5.1 Gauthier HADERER (Professeur Principal & Président)
SET @PersonMainId = UUID_TO_BIN(UUID());
INSERT INTO Persons (Id, Address_Id, LastName, FirstName, Birthday, Gender, Email, Phone, Mobile)
VALUES (@PersonMainId, @PresidentAddressId, 'HADERER', 'Gauthier', NULL, 'M', 'gauthier.haderer@gobox.ovh', NULL, '06 24 57 68 01');

INSERT INTO Members (Club_Id, Person_Id) VALUES (@ClubId, @PersonMainId);
SET @MemberTeacherId = LAST_INSERT_ID();

INSERT INTO Instructors (Member_Id, Job) VALUES (@MemberTeacherId, 'Professeur Principal');

INSERT INTO Contacts (Club_Id, Person_Id, Job, Email, Phone, Mobile)
VALUES (@ClubId, @PersonMainId, 'Président', 'gauthier.haderer@gobox.ovh', NULL, '06 24 57 68 01');

INSERT INTO PersonsCustomFields (Person_Id, CustomField_Id, Value) VALUES
    (@PersonMainId, @FieldGradeId, '2e Dan'),
    (@PersonMainId, @FieldSeniorityId, '20 ans');

-- 5.2 Joannes DE KOSTER (Trésorier)
SET @PersonContact2Id = UUID_TO_BIN(UUID());
INSERT INTO Persons (Id, Address_Id, LastName, FirstName, Birthday, Gender, Email, Phone, Mobile)
VALUES (@PersonContact2Id, @DojoAddressId, 'DE KOSTER', 'Joannes', NULL, 'M', 'j.dekoster@ryuko-dojo.com', NULL, '06 16 26 43 28');

INSERT INTO Members (Club_Id, Person_Id) VALUES (@ClubId, @PersonContact2Id);

INSERT INTO Contacts (Club_Id, Person_Id, Job, Email, Phone, Mobile)
VALUES (@ClubId, @PersonContact2Id, 'Trésorier', 'j.dekoster@ryuko-dojo.com', NULL, '06 16 26 43 28');

-- 5.3 Mathieu MARTINEZ (Secrétaire)
SET @PersonContact3Id = UUID_TO_BIN(UUID());
INSERT INTO Persons (Id, Address_Id, LastName, FirstName, Birthday, Gender, Email, Phone, Mobile)
VALUES (@PersonContact3Id, @DojoAddressId, 'MARTINEZ', 'Mathieu', NULL, 'M', 'martinez.mathieu@hotmail.fr', NULL, '06 34 16 80 05');

INSERT INTO Members (Club_Id, Person_Id) VALUES (@ClubId, @PersonContact3Id);

INSERT INTO Contacts (Club_Id, Person_Id, Job, Email, Phone, Mobile)
VALUES (@ClubId, @PersonContact3Id, 'Secrétaire', 'martinez.mathieu@hotmail.fr', NULL, '06 34 16 80 05');

-- 5.4 David LECOMTE (Secrétaire adjoint)
SET @PersonContact4Id = UUID_TO_BIN(UUID());
INSERT INTO Persons (Id, Address_Id, LastName, FirstName, Birthday, Gender, Email, Phone, Mobile)
VALUES (@PersonContact4Id, @DojoAddressId, 'LECOMTE', 'David', NULL, 'M', 'david.lecomte34@gmail.com', NULL, '06 73 03 33 32');

INSERT INTO Members (Club_Id, Person_Id) VALUES (@ClubId, @PersonContact4Id);

INSERT INTO Contacts (Club_Id, Person_Id, Job, Email, Phone, Mobile)
VALUES (@ClubId, @PersonContact4Id, 'Secrétaire adjoint', 'david.lecomte34@gmail.com', NULL, '06 73 03 33 32');

COMMIT;
