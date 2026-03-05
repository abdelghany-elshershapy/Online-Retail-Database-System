CREATE DATABASE OnlineRetailDB;
GO

USE OnlineRetailDB;
GO


CREATE TABLE Customers (
    CustomerID INT IDENTITY(1,1) PRIMARY KEY,
    FirstName NVARCHAR(100) NOT NULL,
    LastName NVARCHAR(100) NOT NULL,
    Email NVARCHAR(255) NOT NULL UNIQUE,
    Phone NVARCHAR(20),
    DateOfBirth DATE,
    RegistrationDate DATETIME NOT NULL DEFAULT GETDATE()
);




CREATE TABLE Addresses (
    AddressID INT IDENTITY(1,1) PRIMARY KEY,
    CustomerID INT NOT NULL,
    Street NVARCHAR(255) NOT NULL,
    City NVARCHAR(100) NOT NULL,
    State NVARCHAR(100),
    ZipCode NVARCHAR(20),
    Type NVARCHAR(20) CHECK (Type IN ('Home','Work')),

    CONSTRAINT FK_Addresses_Customers
        FOREIGN KEY (CustomerID)
        REFERENCES Customers(CustomerID)
        ON DELETE CASCADE
);



CREATE TABLE Categories (
    CategoryID INT IDENTITY(1,1) PRIMARY KEY,
    CategoryName NVARCHAR(150) NOT NULL UNIQUE
);


CREATE TABLE Products (
    ProductID INT IDENTITY(1,1) PRIMARY KEY,
    Name NVARCHAR(200) NOT NULL,
    Description NVARCHAR(MAX),
    UnitPrice DECIMAL(10,2) NOT NULL CHECK (UnitPrice > 0),
    StockQuantity INT NOT NULL CHECK (StockQuantity >= 0),
    CategoryID INT NOT NULL,

    CONSTRAINT FK_Products_Categories
        FOREIGN KEY (CategoryID)
        REFERENCES Categories(CategoryID)
);



CREATE TABLE ProductImages (
    ImageID INT IDENTITY(1,1) PRIMARY KEY,
    ProductID INT NOT NULL,
    ImageURL NVARCHAR(500) NOT NULL,

    CONSTRAINT FK_ProductImages_Products
        FOREIGN KEY (ProductID)
        REFERENCES Products(ProductID)
        ON DELETE CASCADE
);




CREATE TABLE Suppliers (
    SupplierID INT IDENTITY(1,1) PRIMARY KEY,
    Name NVARCHAR(200) NOT NULL,
    Phone NVARCHAR(20),
    Email NVARCHAR(255) NOT NULL UNIQUE,
    Address NVARCHAR(300)
);




CREATE TABLE Supplies (
    SupplierID INT NOT NULL,
    ProductID INT NOT NULL,
    SupplyDate DATE NOT NULL,
    SupplyPrice DECIMAL(10,2) NOT NULL CHECK (SupplyPrice > 0),

    PRIMARY KEY (SupplierID, ProductID, SupplyDate),

    CONSTRAINT FK_Supplies_Suppliers
        FOREIGN KEY (SupplierID)
        REFERENCES Suppliers(SupplierID)
        ON DELETE CASCADE,

    CONSTRAINT FK_Supplies_Products
        FOREIGN KEY (ProductID)
        REFERENCES Products(ProductID)
        ON DELETE CASCADE
);


CREATE TABLE Staff (
    StaffID INT IDENTITY(1,1) PRIMARY KEY,
    FirstName NVARCHAR(100) NOT NULL,
    LastName NVARCHAR(100) NOT NULL,
    Role NVARCHAR(100) NOT NULL,
    Salary DECIMAL(10,2) NOT NULL CHECK (Salary > 0),
    HireDate DATE NOT NULL,
    SupervisorID INT NULL,

    CONSTRAINT FK_Staff_Supervisor
        FOREIGN KEY (SupervisorID)
        REFERENCES Staff(StaffID)
);

CREATE TABLE Orders (
    OrderID INT IDENTITY(1,1) PRIMARY KEY,
    CustomerID INT NOT NULL,
    StaffID INT NOT NULL,
    OrderDate DATETIME NOT NULL DEFAULT GETDATE(),
    Status NVARCHAR(50) NOT NULL,
    TotalAmount DECIMAL(12,2) NOT NULL DEFAULT 0,

    CONSTRAINT FK_Orders_Customers
        FOREIGN KEY (CustomerID)
        REFERENCES Customers(CustomerID),

    CONSTRAINT FK_Orders_Staff
        FOREIGN KEY (StaffID)
        REFERENCES Staff(StaffID)
);


CREATE TRIGGER TR_UpdateOrderTotal
ON OrderItems
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    UPDATE o
    SET TotalAmount = ISNULL((
        SELECT SUM(Quantity * UnitPrice)
        FROM OrderItems oi
        WHERE oi.OrderID = o.OrderID
    ),0)
    FROM Orders o
    WHERE o.OrderID IN (
        SELECT DISTINCT OrderID FROM inserted
        UNION
        SELECT DISTINCT OrderID FROM deleted
    );
END;


CREATE TABLE OrderItems (
    OrderID INT NOT NULL,
    ProductID INT NOT NULL,
    Quantity INT NOT NULL CHECK (Quantity > 0),
    UnitPrice DECIMAL(10,2) NOT NULL CHECK (UnitPrice > 0),

    PRIMARY KEY (OrderID, ProductID),

    CONSTRAINT FK_OrderItems_Orders
        FOREIGN KEY (OrderID)
        REFERENCES Orders(OrderID)
        ON DELETE CASCADE,

    CONSTRAINT FK_OrderItems_Products
        FOREIGN KEY (ProductID)
        REFERENCES Products(ProductID)
);




CREATE TABLE Payments (
    PaymentID INT IDENTITY(1,1) PRIMARY KEY,
    OrderID INT NOT NULL,
    PaymentDate DATETIME NOT NULL DEFAULT GETDATE(),
    Amount DECIMAL(10,2) NOT NULL CHECK (Amount > 0),
    PaymentMethod NVARCHAR(50) NOT NULL,

    CONSTRAINT FK_Payments_Orders
        FOREIGN KEY (OrderID)
        REFERENCES Orders(OrderID)
        ON DELETE CASCADE
);



CREATE TABLE Reviews (
    ReviewID INT IDENTITY(1,1) PRIMARY KEY,
    CustomerID INT NOT NULL,
    ProductID INT NOT NULL,
    Rating INT NOT NULL CHECK (Rating BETWEEN 1 AND 5),
    Comment NVARCHAR(MAX),
    ReviewDate DATETIME NOT NULL DEFAULT GETDATE(),

    CONSTRAINT FK_Reviews_Customers
        FOREIGN KEY (CustomerID)
        REFERENCES Customers(CustomerID)
        ON DELETE CASCADE,

    CONSTRAINT FK_Reviews_Products
        FOREIGN KEY (ProductID)
        REFERENCES Products(ProductID)
        ON DELETE CASCADE,

    CONSTRAINT UQ_Review UNIQUE (CustomerID, ProductID)
);


CREATE TRIGGER TR_CheckStock
ON OrderItems
AFTER INSERT
AS
BEGIN
    IF EXISTS (
        SELECT 1
        FROM inserted i
        JOIN Products p ON i.ProductID = p.ProductID
        WHERE p.StockQuantity < i.Quantity
    )
    BEGIN
        RAISERROR ('Insufficient stock.',16,1);
        ROLLBACK TRANSACTION;
        RETURN;
    END

    UPDATE p
    SET p.StockQuantity = p.StockQuantity - i.Quantity
    FROM Products p
    JOIN inserted i ON p.ProductID = i.ProductID;
END;



-------------------------

--Indexes were created on frequently joined and filtered columns to improve query performance.
-- Performance was tested using STATISTICS IO and TIME before and after indexing.
-- Index for searching orders by customer
CREATE NONCLUSTERED INDEX IX_Orders_CustomerID
ON Orders(CustomerID);

-- Index for filtering orders by date
CREATE NONCLUSTERED INDEX IX_Orders_OrderDate
ON Orders(OrderDate);

-- Index for product lookup inside order items
CREATE NONCLUSTERED INDEX IX_OrderItems_ProductID
ON OrderItems(ProductID);

-- Index for filtering reviews by product
CREATE NONCLUSTERED INDEX IX_Reviews_ProductID
ON Reviews(ProductID);

-- Index for category filtering
CREATE NONCLUSTERED INDEX IX_Products_CategoryID
ON Products(CategoryID);

-- Index for fast payment lookup per order
CREATE NONCLUSTERED INDEX IX_Payments_OrderID
ON Payments(OrderID);


--How To Prove It Works (Performance Test)
SET STATISTICS IO ON;
SET STATISTICS TIME ON;

SELECT * 
FROM Orders
WHERE CustomerID = 5;

----STEP 2 — STORED PROCEDURES + TRANSACTIONS
CREATE PROCEDURE CreateOrder
    @CustomerID INT,
    @StaffID INT,
    @Status NVARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        INSERT INTO Orders (CustomerID, StaffID, Status)


        VALUES (@CustomerID, @StaffID, @Status);

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;

        THROW;
    END CATCH
END;




--Add Order Item (Critical Logic)
--This is important because:
--Must check stock
--Must reduce stock
--Must update total
--Must fail safely


CREATE PROCEDURE AddOrderItem
    @OrderID INT,
    @ProductID INT,
    @Quantity INT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @Stock INT;
    DECLARE @UnitPrice DECIMAL(10,2);

    BEGIN TRY
        BEGIN TRANSACTION;

        SELECT @Stock = StockQuantity,
               @UnitPrice = UnitPrice
        FROM Products
        WHERE ProductID = @ProductID;

        IF @Stock < @Quantity
        BEGIN
            RAISERROR('Insufficient stock.',16,1);
            ROLLBACK TRANSACTION;
            RETURN;
        END

        INSERT INTO OrderItems (OrderID, ProductID, Quantity, UnitPrice)
        VALUES (@OrderID, @ProductID, @Quantity, @UnitPrice);

        UPDATE Products
        SET StockQuantity = StockQuantity - @Quantity
        WHERE ProductID = @ProductID;

        UPDATE Orders
        SET TotalAmount = (
            SELECT SUM(Quantity * UnitPrice)
            FROM OrderItems
            WHERE OrderID = @OrderID
        )
        WHERE OrderID = @OrderID;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;

--PROCEDURE 3 — Process Payment
--Add payment and optionally check if fully paid.
CREATE PROCEDURE ProcessPayment
    @OrderID INT,
    @Amount DECIMAL(10,2),
    @PaymentMethod NVARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        INSERT INTO Payments (OrderID, Amount, PaymentMethod)
        VALUES (@OrderID, @Amount, @PaymentMethod);

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;



--STEP 3 — VIEWS (Analytics Layer)
--Why This Matters

--Tables are raw storage.
--Views are business-ready data.

--Companies never let analysts query raw transactional tables directly.

--VIEW 1 — Customer Order Summary

CREATE VIEW CustomerOrderSummary AS
SELECT 
    c.CustomerID,
    c.FirstName,
    c.LastName,
    COUNT(o.OrderID) AS TotalOrders,
    SUM(o.TotalAmount) AS TotalSpent
FROM Customers c
LEFT JOIN Orders o ON c.CustomerID = o.CustomerID
GROUP BY 
    c.CustomerID,
    c.FirstName,
    c.LastName;

--VIEW 2 — Monthly Revenue

CREATE VIEW MonthlyRevenue AS
SELECT 
    FORMAT(OrderDate, 'yyyy-MM') AS OrderMonth,
    SUM(TotalAmount) AS Revenue
FROM Orders
GROUP BY FORMAT(OrderDate, 'yyyy-MM');

--VIEW 3 — Top Selling Products
CREATE VIEW TopSellingProducts AS
SELECT 
    p.ProductID,
    p.Name,
    SUM(oi.Quantity) AS TotalSold
FROM Products p
JOIN OrderItems oi ON p.ProductID = oi.ProductID
GROUP BY 
    p.ProductID,
    p.Name;

--VIEW 4 — Low Stock Alert
CREATE VIEW LowStockProducts AS
SELECT 
    ProductID,
    Name,
    StockQuantity
FROM Products
WHERE StockQuantity < 10;


--VIEW 5 — Staff Performance
CREATE VIEW StaffPerformance AS
SELECT 
    s.StaffID,
    s.FirstName,
    s.LastName,
    COUNT(o.OrderID) AS OrdersProcessed,
    SUM(o.TotalAmount) AS RevenueHandled
FROM Staff s
LEFT JOIN Orders o ON s.StaffID = o.StaffID
GROUP BY 
    s.StaffID,
    s.FirstName,
    s.LastName;

--SECURITY LAYER (ROLES + PERMISSIONS)
    --PART 1 — CREATE DATABASE ROLES
CREATE ROLE AdminRole;
CREATE ROLE StaffRole;
CREATE ROLE AnalystRole;

    --PART 2 — ASSIGN PERMISSIONS
GRANT CONTROL ON DATABASE::OnlineRetailDB TO AdminRole;


----------------------------
GRANT SELECT ON Customers TO StaffRole;
GRANT SELECT ON Products TO StaffRole;
GRANT SELECT ON Orders TO StaffRole;
GRANT SELECT ON OrderItems TO StaffRole;
GRANT SELECT ON Payments TO StaffRole;

GRANT EXECUTE ON CreateOrder TO StaffRole;
GRANT EXECUTE ON AddOrderItem TO StaffRole;
GRANT EXECUTE ON ProcessPayment TO StaffRole;

---------------------
GRANT SELECT ON CustomerOrderSummary TO AnalystRole;
GRANT SELECT ON MonthlyRevenue TO AnalystRole;
GRANT SELECT ON TopSellingProducts TO AnalystRole;
GRANT SELECT ON LowStockProducts TO AnalystRole;
GRANT SELECT ON StaffPerformance TO AnalystRole;


    --PART 3 — CREATE USERS AND ASSIGN ROLES
CREATE LOGIN StaffUser WITH PASSWORD = 'StrongPassword123!';
CREATE USER StaffUser FOR LOGIN StaffUser;
ALTER ROLE StaffRole ADD MEMBER StaffUser;



CREATE LOGIN AnalystUser WITH PASSWORD = 'StrongAnalystPass123!';
GO

CREATE USER AnalystUser FOR LOGIN AnalystUser;
GO

ALTER ROLE AnalystRole ADD MEMBER AnalystUser;
GO




CREATE LOGIN AdminUser WITH PASSWORD = 'StrongAdminPass123!';
GO

CREATE USER AdminUser FOR LOGIN AdminUser;
GO

ALTER ROLE AdminRole ADD MEMBER AdminUser;
GO




--STEP 5 — AUDITING & CHANGE LOGGING SYSTEM

CREATE TABLE AuditLogs (
    AuditID INT IDENTITY(1,1) PRIMARY KEY,
    TableName NVARCHAR(100),
    OperationType NVARCHAR(20),
    RecordID NVARCHAR(100),
    ChangedBy NVARCHAR(100),
    ChangeDate DATETIME DEFAULT GETDATE(),
    OldValue NVARCHAR(MAX),
    NewValue NVARCHAR(MAX)
);
--Now system has centralized logging storage.




--INSERT + UPDATE + DELETE Trigger
CREATE TRIGGER TR_Audit_Products
ON Products
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;

    -- INSERT
    INSERT INTO AuditLogs (TableName, OperationType, RecordID, ChangedBy, NewValue)
    SELECT 
        'Products',
        'INSERT',
        CAST(i.ProductID AS NVARCHAR(100)),
        SUSER_NAME(),
        CONCAT('Name=', i.Name, 
               ', Price=', i.UnitPrice,
               ', Stock=', i.StockQuantity)
    FROM inserted i
    WHERE NOT EXISTS (
        SELECT 1 FROM deleted d WHERE d.ProductID = i.ProductID
    );

    -- UPDATE
    INSERT INTO AuditLogs (TableName, OperationType, RecordID, ChangedBy, OldValue, NewValue)
    SELECT 
        'Products',
        'UPDATE',
        CAST(i.ProductID AS NVARCHAR(100)),
        SUSER_NAME(),
        CONCAT('OldPrice=', d.UnitPrice, 
               ', OldStock=', d.StockQuantity),
        CONCAT('NewPrice=', i.UnitPrice, 
               ', NewStock=', i.StockQuantity)
    FROM inserted i
    JOIN deleted d ON i.ProductID = d.ProductID;

    -- DELETE
    INSERT INTO AuditLogs (TableName, OperationType, RecordID, ChangedBy, OldValue)
    SELECT 
        'Products',
        'DELETE',
        CAST(d.ProductID AS NVARCHAR(100)),
        SUSER_NAME(),
        CONCAT('Name=', d.Name, 
               ', Price=', d.UnitPrice,
               ', Stock=', d.StockQuantity)
    FROM deleted d
    WHERE NOT EXISTS (
        SELECT 1 FROM inserted i WHERE i.ProductID = d.ProductID
    );
END;

--TEST THE AUDIT SYSTEM
INSERT INTO Products (Name, Description, UnitPrice, StockQuantity, CategoryID)
VALUES ('TestProduct', 'Test', 100, 50, 1);


UPDATE Products
SET UnitPrice = 120
WHERE Name = 'TestProduct';

DELETE FROM Products
WHERE Name = 'TestProduct';

SELECT * FROM AuditLogs ORDER BY ChangeDate DESC;


--doing the other triggers 
-- AUDIT TRIGGER — CUSTOMERS
CREATE TRIGGER TR_Audit_Customers
ON Customers
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;

    -- INSERT
    INSERT INTO AuditLogs (TableName, OperationType, RecordID, ChangedBy, NewValue)
    SELECT 
        'Customers',
        'INSERT',
        CAST(i.CustomerID AS NVARCHAR(100)),
        SUSER_NAME(),
        CONCAT('Name=', i.FirstName, ' ', i.LastName,
               ', Email=', i.Email)
    FROM inserted i
    WHERE NOT EXISTS (
        SELECT 1 FROM deleted d WHERE d.CustomerID = i.CustomerID
    );

    -- UPDATE
    INSERT INTO AuditLogs (TableName, OperationType, RecordID, ChangedBy, OldValue, NewValue)
    SELECT 
        'Customers',
        'UPDATE',
        CAST(i.CustomerID AS NVARCHAR(100)),
        SUSER_NAME(),
        CONCAT('OldEmail=', d.Email),
        CONCAT('NewEmail=', i.Email)
    FROM inserted i
    JOIN deleted d ON i.CustomerID = d.CustomerID;

    -- DELETE
    INSERT INTO AuditLogs (TableName, OperationType, RecordID, ChangedBy, OldValue)
    SELECT 
        'Customers',
        'DELETE',
        CAST(d.CustomerID AS NVARCHAR(100)),
        SUSER_NAME(),
        CONCAT('Name=', d.FirstName, ' ', d.LastName,
               ', Email=', d.Email)
    FROM deleted d
    WHERE NOT EXISTS (
        SELECT 1 FROM inserted i WHERE i.CustomerID = d.CustomerID
    );
END;




-- AUDIT TRIGGER — ORDERS
CREATE TRIGGER TR_Audit_Orders
ON Orders
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;

    -- INSERT
    INSERT INTO AuditLogs (TableName, OperationType, RecordID, ChangedBy, NewValue)
    SELECT 
        'Orders',
        'INSERT',
        CAST(i.OrderID AS NVARCHAR(100)),
        SUSER_NAME(),
        CONCAT('CustomerID=', i.CustomerID,
               ', Total=', i.TotalAmount)
    FROM inserted i
    WHERE NOT EXISTS (
        SELECT 1 FROM deleted d WHERE d.OrderID = i.OrderID
    );

    -- UPDATE
    INSERT INTO AuditLogs (TableName, OperationType, RecordID, ChangedBy, OldValue, NewValue)
    SELECT 
        'Orders',
        'UPDATE',
        CAST(i.OrderID AS NVARCHAR(100)),
        SUSER_NAME(),
        CONCAT('OldTotal=', d.TotalAmount),
        CONCAT('NewTotal=', i.TotalAmount)
    FROM inserted i
    JOIN deleted d ON i.OrderID = d.OrderID;

    -- DELETE
    INSERT INTO AuditLogs (TableName, OperationType, RecordID, ChangedBy, OldValue)
    SELECT 
        'Orders',
        'DELETE',
        CAST(d.OrderID AS NVARCHAR(100)),
        SUSER_NAME(),
        CONCAT('CustomerID=', d.CustomerID,
               ', Total=', d.TotalAmount)
    FROM deleted d
    WHERE NOT EXISTS (
        SELECT 1 FROM inserted i WHERE i.OrderID = d.OrderID
    );
END;



--- AUDIT TRIGGER — ORDER ITEMS
CREATE TRIGGER TR_Audit_OrderItems
ON OrderItems
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;

    -- INSERT
    INSERT INTO AuditLogs (TableName, OperationType, RecordID, ChangedBy, NewValue)
    SELECT 
        'OrderItems',
        'INSERT',
        CONCAT(i.OrderID, '-', i.ProductID),
        SUSER_NAME(),
        CONCAT('Qty=', i.Quantity,
               ', Price=', i.UnitPrice)
    FROM inserted i
    WHERE NOT EXISTS (
        SELECT 1 FROM deleted d 
        WHERE d.OrderID = i.OrderID 
        AND d.ProductID = i.ProductID
    );

    -- UPDATE
    INSERT INTO AuditLogs (TableName, OperationType, RecordID, ChangedBy, OldValue, NewValue)
    SELECT 
        'OrderItems',
        'UPDATE',
        CONCAT(i.OrderID, '-', i.ProductID),
        SUSER_NAME(),
        CONCAT('OldQty=', d.Quantity),
        CONCAT('NewQty=', i.Quantity)
    FROM inserted i
    JOIN deleted d 
        ON i.OrderID = d.OrderID 
        AND i.ProductID = d.ProductID;

    -- DELETE
    INSERT INTO AuditLogs (TableName, OperationType, RecordID, ChangedBy, OldValue)
    SELECT 
        'OrderItems',
        'DELETE',
        CONCAT(d.OrderID, '-', d.ProductID),
        SUSER_NAME(),
        CONCAT('Qty=', d.Quantity,
               ', Price=', d.UnitPrice)
    FROM deleted d
    WHERE NOT EXISTS (
        SELECT 1 FROM inserted i 
        WHERE i.OrderID = d.OrderID 
        AND i.ProductID = d.ProductID
    );
END;


-- AUDIT TRIGGER — PAYMENTS

CREATE TRIGGER TR_Audit_Payments
ON Payments
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;

    -- INSERT
    INSERT INTO AuditLogs (TableName, OperationType, RecordID, ChangedBy, NewValue)
    SELECT 
        'Payments',
        'INSERT',
        CAST(i.PaymentID AS NVARCHAR(100)),
        SUSER_NAME(),
        CONCAT('OrderID=', i.OrderID,
               ', Amount=', i.Amount)
    FROM inserted i
    WHERE NOT EXISTS (
        SELECT 1 FROM deleted d WHERE d.PaymentID = i.PaymentID
    );

    -- UPDATE
    INSERT INTO AuditLogs (TableName, OperationType, RecordID, ChangedBy, OldValue, NewValue)
    SELECT 
        'Payments',
        'UPDATE',
        CAST(i.PaymentID AS NVARCHAR(100)),
        SUSER_NAME(),
        CONCAT('OldAmount=', d.Amount),
        CONCAT('NewAmount=', i.Amount)
    FROM inserted i
    JOIN deleted d ON i.PaymentID = d.PaymentID;

    -- DELETE
    INSERT INTO AuditLogs (TableName, OperationType, RecordID, ChangedBy, OldValue)
    SELECT 
        'Payments',
        'DELETE',
        CAST(d.PaymentID AS NVARCHAR(100)),
        SUSER_NAME(),
        CONCAT('OrderID=', d.OrderID,
               ', Amount=', d.Amount)
    FROM deleted d
    WHERE NOT EXISTS (
        SELECT 1 FROM inserted i WHERE i.PaymentID = d.PaymentID
    );
END;



--BACKUP, RECOVERY, AND MAINTENANCE STRATEGY
-- full backup
BACKUP DATABASE OnlineRetailDB
TO DISK = 'C:\SQLBackups\OnlineRetailDB_Full.bak'
WITH FORMAT,
INIT,
NAME = 'Full Backup of OnlineRetailDB',
STATS = 10;

--B) DIFFERENTIAL BACKUP
BACKUP DATABASE OnlineRetailDB
TO DISK = 'C:\SQLBackups\OnlineRetailDB_Diff.bak'
WITH DIFFERENTIAL,
NAME = 'Differential Backup',
STATS = 10;

--TRANSACTION LOG BACKUP

--Only works if database is in FULL recovery mode.
--First set recovery mode:
ALTER DATABASE OnlineRetailDB
SET RECOVERY FULL;
  
--Then:
BACKUP LOG OnlineRetailDB
TO DISK = 'C:\SQLBackups\OnlineRetailDB_Log.trn'
WITH STATS = 10;




--RESTORE PROCESS
--This proves disaster recovery.
    RESTORE DATABASE OnlineRetailDB_Test
    FROM DISK = 'C:\SQLBackups\OnlineRetailDB_Full.bak'
    WITH MOVE 'OnlineRetailDB' TO 'C:\SQLData\OnlineRetailDB_Test.mdf',
         MOVE 'OnlineRetailDB_log' TO 'C:\SQLData\OnlineRetailDB_Test.ldf',
         REPLACE;


--INDEX MAINTENANCE
--Indexes degrade over time (fragmentation).
SELECT 
    OBJECT_NAME(i.object_id) AS TableName,
    i.name AS IndexName,
    ps.avg_fragmentation_in_percent
FROM sys.dm_db_index_physical_stats
(DB_ID(), NULL, NULL, NULL, 'LIMITED') ps
JOIN sys.indexes i 
ON ps.object_id = i.object_id 
AND ps.index_id = i.index_id
WHERE ps.avg_fragmentation_in_percent > 10;




-- Add Realistic Sample Data
INSERT INTO Categories (CategoryName) VALUES
('Electronics'),
('Computers'),
('Mobile Phones'),
('Home Appliances'),
('Gaming'),
('Books'),
('Clothing'),
('Sports'),
('Furniture'),
('Accessories');


INSERT INTO Staff (FirstName, LastName, Role, Salary, HireDate, SupervisorID) VALUES
('Ahmed','Hassan','Manager',9000,'2022-01-10',NULL),
('Mona','Ali','Sales',4500,'2023-03-15',1),
('Omar','Mahmoud','Sales',4300,'2023-06-20',1),
('Salma','Khaled','Support',4200,'2023-05-10',1),
('Youssef','Ibrahim','Support',4000,'2024-01-12',1);


INSERT INTO Customers (FirstName, LastName, Email, Phone, DateOfBirth, RegistrationDate) VALUES
('Ali','Nasser','ali1@email.com','0101111111','1995-03-10',GETDATE()),
('Sara','Adel','sara2@email.com','0102222222','1997-07-20',GETDATE()),
('Karim','Mostafa','karim3@email.com','0103333333','1990-05-12',GETDATE()),
('Huda','Samir','huda4@email.com','0104444444','1998-08-21',GETDATE()),
('Mahmoud','Tarek','mahmoud5@email.com','0105555555','1994-11-11',GETDATE()),
('Nour','Ashraf','nour6@email.com','0106666666','1999-02-02',GETDATE()),
('Amr','Fathy','amr7@email.com','0107777777','1993-12-12',GETDATE()),
('Laila','Yassin','laila8@email.com','0108888888','1996-09-15',GETDATE());


INSERT INTO Addresses (CustomerID, Street, City, State, ZipCode, Type) VALUES
(1,'10 Nile St','Cairo','Cairo','11511','Home'),
(2,'22 Garden St','Giza','Giza','12611','Home'),
(3,'15 City Center','Alex','Alex','21511','Home'),
(4,'7 Sea St','Alex','Alex','21511','Home'),
(5,'3 Tahrir St','Cairo','Cairo','11511','Home'),
(6,'8 Stadium St','Cairo','Cairo','11511','Home'),
(7,'12 University St','Mansoura','Dakahlia','35511','Home'),
(8,'45 Corniche','Alex','Alex','21511','Home');


INSERT INTO Suppliers (Name, Phone, Email, Address) VALUES
('TechSource','02211111','supplier1@tech.com','Cairo'),
('DigitalWorld','02222222','supplier2@tech.com','Giza'),
('SmartDevices','02233333','supplier3@tech.com','Alex'),
('MegaSupply','02244444','supplier4@tech.com','Cairo'),
('FutureElectronics','02255555','supplier5@tech.com','Giza');


INSERT INTO Products (Name, Description, UnitPrice, StockQuantity, CategoryID) VALUES
('Laptop Dell XPS','High performance laptop',25000,50,2),
('iPhone 15','Apple smartphone',40000,40,3),
('Samsung TV 55','Smart TV',18000,25,4),
('PlayStation 5','Gaming console',22000,30,5),
('Gaming Mouse','RGB mouse',800,200,10),
('Office Chair','Comfort chair',3500,60,9),
('Running Shoes','Sport shoes',1500,120,8),
('Bluetooth Headphones','Wireless audio',1200,150,1),
('Gaming Keyboard','Mechanical keyboard',1600,80,5),
('Programming Book','Learn coding',300,90,6);



INSERT INTO ProductImages (ProductID, ImageURL) VALUES
(1,'img/laptop1.jpg'),
(1,'img/laptop2.jpg'),
(2,'img/iphone1.jpg'),
(3,'img/tv1.jpg'),
(4,'img/ps5.jpg'),
(5,'img/mouse.jpg'),
(6,'img/chair.jpg'),
(7,'img/shoes.jpg'),
(8,'img/headphones.jpg'),
(9,'img/keyboard.jpg'),
(10,'img/book.jpg');



INSERT INTO Supplies (SupplierID, ProductID, SupplyDate, SupplyPrice) VALUES
(1,12,'2025-01-10',20000),
(1,13,'2025-01-11',35000),
(2,11,'2025-01-12',15000),
(3,4,'2025-01-13',19000),
(2,5,'2025-01-14',500),
(4,6,'2025-01-15',2800),
(5,7,'2025-01-16',1000),
(3,8,'2025-01-17',900),
(1,9,'2025-01-18',1200),
(2,10,'2025-01-19',200);



INSERT INTO Orders (CustomerID, StaffID, OrderDate, Status, TotalAmount) VALUES
(1,2,GETDATE(),'Completed',0),
(2,3,GETDATE(),'Completed',0),
(3,2,GETDATE(),'Pending',0),
(4,4,GETDATE(),'Completed',0),
(5,3,GETDATE(),'Completed',0);



INSERT INTO OrderItems (OrderID, ProductID, Quantity, UnitPrice) VALUES
(1,4,1,25000),
(1,5,2,800),
(2,6,1,40000),
(2,8,1,1200),
(3,9,1,22000),
(4,10,2,1500),
(4,11,1,1600),
(5,12,1,18000);



INSERT INTO Payments (OrderID, PaymentDate, Amount, PaymentMethod) VALUES
(1,GETDATE(),26600,'Credit Card'),
(2,GETDATE(),41200,'Credit Card'),
(3,GETDATE(),22000,'Cash'),
(4,GETDATE(),4600,'Cash'),
(5,GETDATE(),18000,'Credit Card');


INSERT INTO Reviews (CustomerID, ProductID, Rating, Comment, ReviewDate) VALUES
(1,4,5,'Excellent laptop',GETDATE()),
(2,5,4,'Great phone',GETDATE()),
(3,6,5,'Amazing console',GETDATE()),
(4,7,4,'Comfortable shoes',GETDATE()),
(5,8,3,'Good TV',GETDATE()),
(6,9,4,'Nice headphones',GETDATE()),
(7,12,5,'Perfect mouse',GETDATE());


