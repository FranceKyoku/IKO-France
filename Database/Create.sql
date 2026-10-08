USE francekyoku;

-- Table contenant l'ensemble des adresses (Club et Person)
-- Requête d'insertion : 
-- INSERT INTO Addresses (Street, PostalCode, City, Country, Coordinates) VALUES ('123 Main Street', '75001', 'Paris', 'France', ST_PointFromText('POINT(48.8566 2.3522)', 4326)
CREATE TABLE Addresses (
    -- Identifiant de l'adresse
    Id INT AUTO_INCREMENT PRIMARY KEY,
 
    -- Nom de la rue
    Street VARCHAR(255) NOT NULL,
    
    -- Code postal
    PostalCode VARCHAR(20) NOT NULL,
    
    -- Ville
    City VARCHAR(100) NOT NULL,
    
    -- Pays
    Country VARCHAR(100) DEFAULT 'France',
    
    -- Complement
    Complement VARCHAR(255),

    -- Position geographique de l'adresse
    Coordinates POINT NOT NULL SRID 4326,
    SPATIAL INDEX(Coordinates)
) ENGINE=InnoDB;

-- Table contenant l'ensemble des informations de clubs IKO France
CREATE TABLE Clubs (
    -- Identifiant du club auto généré
    Id BINARY(16) PRIMARY KEY DEFAULT (UUID_TO_BIN(UUID())),
    
    -- Nom du club
    Name VARCHAR(100) NOT NULL,

    -- Initial du club
    Initial VARCHAR(20) DEFAULT NULL,

    -- Chemin vers le logo du club
    Logo VARCHAR(255) DEFAULT NULL,
 
    -- Chemin vers l'image du club
    Image VARCHAR(255) DEFAULT NULL,
 
    -- Texte présentant le club
    Presentation TEXT DEFAULT NULL,
 
    -- Site web du club
    Web VARCHAR(255) DEFAULT NULL,

    -- Indique si le club est encore actif ou non
    IsActive BOOLEAN DEFAULT TRUE
) ENGINE=InnoDB;

CREATE TABLE SocialNetworks (
    -- Identifiant
    Id INT AUTO_INCREMENT PRIMARY KEY,

    -- Identifiant du club
    Club_Id BINARY(16) NOT NULL,

    -- Nom du réseau social
    Name VARCHAR(200),

    -- Url du réseau social
    Url VARCHAR(255),

    -- Contraintes de clés étrangères pour garantir l'intégrité des données
    CONSTRAINT FK_SocialNetworks_Club FOREIGN KEY (Club_Id) REFERENCES Clubs(Id) ON DELETE CASCADE
) ENGINE=InnoDB;

-- Table contenant la liste des dojos
CREATE TABLE Dojos (
    -- Identifiant du dojo
    Id INT AUTO_INCREMENT PRIMARY KEY,

    -- Identifiant du club
    Club_Id BINARY(16) NOT NULL,
    
    -- Identifiant de l'adresse
    Address_Id INT NOT NULL,

    -- Nom du dojo
    Name VARCHAR(100),
    
    -- Indique si c'est le dojo principale
    IsMain BOOLEAN DEFAULT FALSE,

    -- Contraintes de clés étrangères pour garantir l'intégrité des données
    CONSTRAINT FK_Dojos_Clubs FOREIGN KEY (Club_Id) REFERENCES Clubs(Id) ON DELETE CASCADE,
    CONSTRAINT FK_Dojos_Addresses FOREIGN KEY (Address_Id) REFERENCES Addresses(Id) ON DELETE CASCADE,

    -- Contrainte d'unicité : un club ne peut pas lier deux fois la même adresse
    UNIQUE KEY UK_Clubs_Addresses (Club_Id, Address_Id)
) ENGINE=InnoDB;

-- Table contenant les jours et horaire des différent dojos
CREATE TABLE Schedules (
    -- Identifiant de la programmation
    Id INT AUTO_INCREMENT PRIMARY KEY,

    -- Idenifiant du dojo
    Dojo_Id INT NOT NULL,

    -- Le jou de la semaine (1 pour Lundi, 7 pour Dimanche selon la norme ISO)
    DayOfWeek TINYINT NOT NULL CHECK (DayOfWeek BETWEEN 1 AND 7),

    -- Horaires
    Start TIME NOT NULL,
    End TIME NOT NULL,

    -- Permet de cibler le public 
    Description VARCHAR(100),

    -- Clé étrangère : supprime le planning si le dojo est supprimé
    CONSTRAINT FK_Schedules_Dojos FOREIGN KEY (Dojo_Id) REFERENCES Dojos(Id) ON DELETE CASCADE,

    -- Empêche d'avoir deux heures d'ouverture identique le même jour pour le même dojo à la même heure
    UNIQUE KEY UK_Dojo_Start (Dojo_Id, DayOfWeek, Start),

    -- Vérifie que l'heure de fermeture est bien après l'heure d'ouverture
    CONSTRAINT Check_Time_Flow CHECK (End > Start)
) ENGINE=InnoDB;

-- Table contenant les jours de fermetures d'un dojo
CREATE TABLE Closures (
    -- Identifiant
    Id INT AUTO_INCREMENT PRIMARY KEY,

    -- Identifiant du dojo
    Dojo_Id INT NOT NULL,

    -- Periode de fermeture
    StartDate DATE NOT NULL,
    EndDate DATE NOT NULL,

    -- Type de la fermeture
    Type ENUM ('Exceptional', 'Holiday') NOT NULL DEFAULT 'Exceptional',

    -- Raison de la fermeture
    Reason VARCHAR(255),

    -- Clé étrangère vers la table Dojos
    CONSTRAINT FK_Closures_Dojos FOREIGN KEY (Dojo_Id) REFERENCES Dojos(Id) ON DELETE CASCADE,

    -- La date de fin doit être égale ou supérieur à la date de début
    CONSTRAINT Check_Closure_Dates CHECK (EndDate >= StartDate)
) ENGINE=InnoDB;

-- Table contenant les informations des personnes
CREATE TABLE Persons (
    -- Identifiant de la personne
    Id BINARY(16) PRIMARY KEY DEFAULT (UUID_TO_BIN(UUID())),

    -- Identifiant de l'adresse de la personne
    Address_Id INT NULL,

    -- Nom de la personne
    LastName VARCHAR(50) NOT NULL,

    -- Prénom de la personne
    FirstName VARCHAR(50) NOT NULL,

    -- Date de naissance de la personne
    Birthday DATE NULL,

    -- Sexe de la personne
    Gender ENUM ('M', 'F', 'X', 'U') NOT NULL,

    -- Email
    Email VARCHAR(255),

    -- Phone
    Phone VARCHAR(20) NULL,

    -- Mobile
    Mobile VARCHAR(20) NULL,

    -- Contraintes de clés étrangères pour garantir l'intégrité des données
    CONSTRAINT FK_Persons_Addresses FOREIGN KEY (Address_Id) REFERENCES Addresses(Id) ON DELETE CASCADE
) ENGINE=InnoDB;

-- Table contenant les différente traduction
CREATE TABLE Translates (
    -- Identifiant
    Code VARCHAR(255) PRIMARY KEY,

    -- Valeur en Français
    Fr VARCHAR(255) NOT NULL,

    -- Valeur en Anglais
    En VARCHAR(255) NOT NULL
) ENGINE=InnoDB;

-- Table contenant les champs customizé
CREATE TABLE CustomFields (
    -- Identifiant
    Id INT AUTO_INCREMENT PRIMARY KEY,

    -- Code (nom) du champs personnalisé
    Name_Code VARCHAR(255) NOT NULL,

    -- Contraintes de clés étrangères pour garantir l'intégrité des données
    CONSTRAINT FK_CustomFields_Translates FOREIGN KEY (Name_Code) REFERENCES Translates(Code) ON DELETE CASCADE
) ENGINE=InnoDB;

-- Table permettant de définir la valeur des champs personnalisé d'une personne
CREATE TABLE PersonsCustomFields (
    -- Identifiant
    Id INT AUTO_INCREMENT PRIMARY KEY,

    -- Identifiant de la personne
    Person_Id BINARY(16) NOT NULL,

    -- Identifiant du champ personnalisé
    CustomField_Id INT NOT NULL,

    -- Valeur du champ personnalisé
    Value VARCHAR(255) NOT NULL,

    -- Contraintes de clés étrangères pour garantir l'intégrité des données
    CONSTRAINT FK_Persons_CustomFields_Person FOREIGN KEY (Person_Id) REFERENCES Persons(Id) ON DELETE CASCADE,
    CONSTRAINT FK_Persons_CustomFields_CustomField FOREIGN KEY (CustomField_Id) REFERENCES CustomFields(Id) ON DELETE CASCADE,

    -- Contrainte d'unicité
    UNIQUE KEY UK_Persons_Custom_Fields (Person_Id, CustomField_Id)
) ENGINE=InnoDB;

-- Table contenant les listes des membres des différents club
CREATE TABLE Members (
    -- Identifiant
    Id INT AUTO_INCREMENT PRIMARY KEY,

    -- Identifiant du club
    Club_Id BINARY(16) NOT NULL,

    -- Identifiant de la personne
    Person_Id BINARY(16) NOT NULL,

    -- Contraintes de clés étrangères pour garantir l'intégrité des données
    CONSTRAINT FK_Members_Club FOREIGN KEY (Club_Id) REFERENCES Clubs(Id) ON DELETE CASCADE,
    CONSTRAINT FK_Members_Person FOREIGN KEY (Person_Id) REFERENCES Persons(Id) ON DELETE CASCADE,

    -- Contrainte d'unicité
    UNIQUE KEY UK_Members (Club_Id, Person_Id)
) ENGINE=InnoDB;

-- Table contenant la liste des instructeurs
CREATE TABLE Instructors (
    -- Identifiant
    Id INT AUTO_INCREMENT PRIMARY KEY,

    -- Identifiant du membres
    Member_Id INT NOT NULL,

    -- Fonction de l'instructeur
    Job VARCHAR(255) NOT NULL,

    -- Indique si c'est l'instructeur principale
    IsMain BOOLEAN DEFAULT FALSE,

    -- Contraintes de clés étrangères pour garantir l'intégrité des données
    CONSTRAINT FK_Instructors_Members FOREIGN KEY (Member_Id) REFERENCES Members(Id) ON DELETE CASCADE
) ENGINE=InnoDB;

-- Table contenant la liste des contacts des différents club
CREATE TABLE Contacts (
    -- Identifiant
    Id INT AUTO_INCREMENT PRIMARY KEY,

    -- Identifiant du club
    Club_Id BINARY(16) NOT NULL,

    -- Identifiant de la personne
    Person_Id BINARY(16) NOT NULL,

    -- Fonction du contact (secretire, président, etc...)
    Job VARCHAR(255) NOT NULL,

    -- Email
    Email VARCHAR(255) NULL,

    -- Phone
    Phone VARCHAR(20) NULL,

    -- Mobile
    Mobile VARCHAR(20) NULL,

    -- Indique si c'est le contact principale
    IsMain BOOLEAN DEFAULT FALSE,

    -- Contraintes de clés étrangères pour garantir l'intégrité des données
    CONSTRAINT FK_Contacts_Club FOREIGN KEY (Club_Id) REFERENCES Clubs(Id) ON DELETE CASCADE,
    CONSTRAINT FK_Contacts_Person FOREIGN KEY (Person_Id) REFERENCES Persons(Id) ON DELETE CASCADE,

    -- Contrainte d'unicité
    UNIQUE KEY UK_Contacts (Club_Id, Person_Id, Job)
) ENGINE=InnoDB;

-- Table contenant la liste des grades
CREATE TABLE Levels (
    -- Identifiant
    Id INT AUTO_INCREMENT PRIMARY KEY,

    -- Position du grade
    Position INT NOT NULL,

    -- Nom du grade (11ème Kyu, 10ème Kyu, etc...)
    Name_Code VARCHAR(255) NOT NULL,

    -- Nom de la ceinture  (Ceinture Blanche, Ceinture Orange, etc...)
    BeltName_Code VARCHAR(255) NOT NULL,

    -- Couleur de la ceinture (RGB en hexa, #FF0051)
    Color VARCHAR(10) NOT NULL,

    -- Couleur de la barette (si il y en a)
    ColorBarrette VARCHAR(10) NULL,

    -- Nombre de barrette
    NbBarrettes INT NOT NULL DEFAULT 0,

    -- Contraintes de clés étrangères pour garantir l'intégrité des données
    CONSTRAINT FK_Levels_Name FOREIGN KEY (Name_Code) REFERENCES Translates(Code) ON DELETE CASCADE,
    CONSTRAINT FK_Levels_BeltName FOREIGN KEY (BeltName_Code) REFERENCES Translates(Code) ON DELETE CASCADE
) ENGINE=InnoDB;

-- Table contenant les grades des différents membres des différent clubs
CREATE TABLE PersonsLevels (
    -- Identifiant
    Id INT AUTO_INCREMENT PRIMARY KEY,

    -- Identifiant du club
    Club_Id BINARY(16) NOT NULL,

    -- Identifiant de la personne
    Person_Id BINARY(16) NOT NULL,

    -- Identifiant du grade
    Level_Id INT NOT NULL,

    -- Contraintes de clés étrangères pour garantir l'intégrité des données
    CONSTRAINT FK_PersonsLevels_Club FOREIGN KEY (Club_Id) REFERENCES Clubs(Id) ON DELETE CASCADE,
    CONSTRAINT FK_PersonsLevels_Person FOREIGN KEY (Person_Id) REFERENCES Persons(Id) ON DELETE CASCADE,
    CONSTRAINT FK_PersonsLevels_Level FOREIGN KEY (Level_Id) REFERENCES Levels(Id) ON DELETE CASCADE,

    -- Contrainte d'unicité
    UNIQUE KEY UK_Contacts (Club_Id, Person_Id)
) ENGINE=InnoDB;

-- Table contenant l'ensemble des modifications de la base
CREATE TABLE Historics (
    -- Identifiant
    Id INT AUTO_INCREMENT PRIMARY KEY,

    -- Nom de la table concernée
    TableName VARCHAR(20) NOT NULL,

    -- Type de l'action
    ActionType ENUM('CREATE', 'UPDATE', 'DELETE') NOT NULL,

    -- Identifiant de l'element concerné
    RecordKey VARCHAR(255) NOT NULL,

    -- Ancienne valeur
    OldValue JSON,

    -- Nouvelle valeur
    NewValue JSON,

    -- Utilisateur ayant fait la modification
    UpdatedBy VARCHAR(100),

    -- Date de la modification
    Updated TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

-- KYU
INSERT INTO Translates (Code, Fr, En) VALUES ('11Kyu', '11ème Kyu', '11th Kyu');
INSERT INTO Translates (Code, Fr, En) VALUES ('10Kyu', '10ème Kyu', '10th Kyu');
INSERT INTO Translates (Code, Fr, En) VALUES ('9Kyu', '9ème Kyu', '9th Kyu');
INSERT INTO Translates (Code, Fr, En) VALUES ('8Kyu', '8ème Kyu', '8th Kyu');
INSERT INTO Translates (Code, Fr, En) VALUES ('7Kyu', '7ème Kyu', '7th Kyu');
INSERT INTO Translates (Code, Fr, En) VALUES ('6Kyu', '6ème Kyu', '6th Kyu');
INSERT INTO Translates (Code, Fr, En) VALUES ('5Kyu', '5ème Kyu', '5th Kyu');
INSERT INTO Translates (Code, Fr, En) VALUES ('4Kyu', '4ème Kyu', '4th Kyu');
INSERT INTO Translates (Code, Fr, En) VALUES ('3Kyu', '3ème Kyu', '3rd Kyu');
INSERT INTO Translates (Code, Fr, En) VALUES ('2Kyu', '2ème Kyu', '2nd Kyu');
INSERT INTO Translates (Code, Fr, En) VALUES ('1Kyu', '1er Kyu', '1st Kyu');
INSERT INTO Translates (Code, Fr, En) VALUES ('Shodan', 'Shodan', 'Shodan');
INSERT INTO Translates (Code, Fr, En) VALUES ('Nidan', 'Nidan', 'Nidan');
INSERT INTO Translates (Code, Fr, En) VALUES ('Sandan', 'Sandan', 'Sandan');
INSERT INTO Translates (Code, Fr, En) VALUES ('Yondan', 'Yondan', 'Yondan');
INSERT INTO Translates (Code, Fr, En) VALUES ('Godan', 'Godan', 'Godan');

-- BELT NAME
INSERT INTO Translates (Code, Fr, En) VALUES ('11KyuName', 'Cainture blanche', 'White belt');
INSERT INTO Translates (Code, Fr, En) VALUES ('10KyuName', 'Ceinture orange', 'Orange belt');
INSERT INTO Translates (Code, Fr, En) VALUES ('9KyuName', 'Ceinture orange barrette', 'Orange barrette belt');
INSERT INTO Translates (Code, Fr, En) VALUES ('8KyuName', 'Ceinture bleue', 'Blue belt');
INSERT INTO Translates (Code, Fr, En) VALUES ('7KyuName', 'Ceinture bleue barrette', 'Blue barrette belt');
INSERT INTO Translates (Code, Fr, En) VALUES ('6KyuName', 'Ceinture jaune', 'Yellow belt');
INSERT INTO Translates (Code, Fr, En) VALUES ('5KyuName', 'Ceinture jaune barrette', 'Yellow barrette belt');
INSERT INTO Translates (Code, Fr, En) VALUES ('4KyuName', 'Ceinture verte', 'Green belt');
INSERT INTO Translates (Code, Fr, En) VALUES ('3KyuName', 'Ceinture verte barrettte', 'Green barrette belt');
INSERT INTO Translates (Code, Fr, En) VALUES ('2KyuName', 'Ceinture marron', 'Brown belt');
INSERT INTO Translates (Code, Fr, En) VALUES ('1KyuName', 'Ceinture marron barrette', 'Brown barrette belt');
INSERT INTO Translates (Code, Fr, En) VALUES ('ShodanName', 'Ceinture noir 1er Dan', 'Black belt 1st Dan');
INSERT INTO Translates (Code, Fr, En) VALUES ('NidanName', 'Ceinture noir 2ème Dan', 'Black belt 2nd Dan');
INSERT INTO Translates (Code, Fr, En) VALUES ('SandanName', 'Ceinture noir 3ème Dan', 'Black belt 3rd Dan');
INSERT INTO Translates (Code, Fr, En) VALUES ('YondanName', 'Ceinture noir 4ème Dan', 'Black belt 4th Dan');
INSERT INTO Translates (Code, Fr, En) VALUES ('GodanName', 'Ceinture noir 5ème Dan', 'Black belt 5th Dan');


INSERT INTO Levels (Position, Name_Code, BeltName_Code, Color, ColorBarrette, NbBarrettes) VALUES (1, '11Kyu', '11KyuName', '#FFFFFF', null, 0);
INSERT INTO Levels (Position, Name_Code, BeltName_Code, Color, ColorBarrette, NbBarrettes) VALUES (2, '10Kyu', '10KyuName', '#ec6618', null, 0);
INSERT INTO Levels (Position, Name_Code, BeltName_Code, Color, ColorBarrette, NbBarrettes) VALUES (3, '9Kyu', '9KyuName', '#ec6618', '#1c4ad2', 1);
INSERT INTO Levels (Position, Name_Code, BeltName_Code, Color, ColorBarrette, NbBarrettes) VALUES (4, '8Kyu', '8KyuName', '#1c4ad2', null, 0);
INSERT INTO Levels (Position, Name_Code, BeltName_Code, Color, ColorBarrette, NbBarrettes) VALUES (5, '7Kyu', '7KyuName', '#1c4ad2', '#ffd556', 1);
INSERT INTO Levels (Position, Name_Code, BeltName_Code, Color, ColorBarrette, NbBarrettes) VALUES (6, '6Kyu', '6KyuName', '#ffd556', null, 0);
INSERT INTO Levels (Position, Name_Code, BeltName_Code, Color, ColorBarrette, NbBarrettes) VALUES (7, '5Kyu', '5KyuName', '#ffd556', '#3a7e12', 1);
INSERT INTO Levels (Position, Name_Code, BeltName_Code, Color, ColorBarrette, NbBarrettes) VALUES (8, '4Kyu', '4KyuName', '#3a7e12', null, 0);
INSERT INTO Levels (Position, Name_Code, BeltName_Code, Color, ColorBarrette, NbBarrettes) VALUES (9, '3Kyu', '3KyuName', '#3a7e12', '#784421', 1);
INSERT INTO Levels (Position, Name_Code, BeltName_Code, Color, ColorBarrette, NbBarrettes) VALUES (10, '2Kyu', '2KyuName', '#784421', null, 0);
INSERT INTO Levels (Position, Name_Code, BeltName_Code, Color, ColorBarrette, NbBarrettes) VALUES (11, '1Kyu', '1KyuName', '#784421', '#000000', 1);
INSERT INTO Levels (Position, Name_Code, BeltName_Code, Color, ColorBarrette, NbBarrettes) VALUES (12, 'Shodan', 'ShodanName', '#000000', '#d4af37', 1);
INSERT INTO Levels (Position, Name_Code, BeltName_Code, Color, ColorBarrette, NbBarrettes) VALUES (13, 'Nidan', 'NidanName', '#000000', '#d4af37', 2);
INSERT INTO Levels (Position, Name_Code, BeltName_Code, Color, ColorBarrette, NbBarrettes) VALUES (14, 'Sandan', 'SandanName', '#000000', '#d4af37', 3);
INSERT INTO Levels (Position, Name_Code, BeltName_Code, Color, ColorBarrette, NbBarrettes) VALUES (15, 'Yondan', 'YondanName', '#000000', '#d4af37', 4);
INSERT INTO Levels (Position, Name_Code, BeltName_Code, Color, ColorBarrette, NbBarrettes) VALUES (16, 'Godan', 'GodanName', '#000000', '#d4af37', 5);