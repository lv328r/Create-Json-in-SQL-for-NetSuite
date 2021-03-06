USE [smartshade]
GO
/****** Object:  StoredProcedure [dbo].[web_nsInsertWorkOrderItems]    Script Date: 7/13/2022 9:22:17 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		<Author,,Name>
-- Create date: <Create Date,,>
-- Description:	<Description,,>
-- =============================================
ALTER PROCEDURE [dbo].[web_nsInsertWorkOrderItems]
		 @wizardGUID NVARCHAR(MAX),
		 @unitID int 
AS
BEGIN


--DECLARE @wizardGUID NVARCHAR(MAX) = 'B24B6BDA-5F47-4F53-B160-9DDCB013653D'
--DECLARE @unitID int = 80246

DECLARE @shadeType NVARCHAR(MAX) = (SELECT dbo.getShadeType(@wizardGUID,1))
DECLARE @mappedShadeType NVARCHAR(MAX) = (SELECT assemblyName FROM osaatShadeToNetSuiteAssembly(@shadeType,NULL))
DECLARE @itemCount int = 0
--SELECT @mappedShadeType
IF OBJECT_ID('tempdb..#tempPartsList') IS NOT NULL DROP TABLE #tempPartsList
CREATE TABLE #tempPartsList
(id INT,
swscPN NVARCHAR(MAX),
swscName NVARCHAR(MAX),
partType NVARCHAR(MAX),
formular NVARCHAR(MAX),
nsID int,
deduction DECIMAL(18,3),
qtyRerquired DECIMAL(18,3)
)

--LOOKUP SHADE TYPE AND GET ALL ASSEMBLIE ITEMS
INSERT INTO #tempPartsList
SELECT id,swscPN, itemName, unitstype, formula, nsID, 0.0, 0.0 FROM inventoryMasterPartsList_New 
WHERE id IN (SELECT partID FROM inventoryAssembly_New WHERE assemblyName IN (SELECT assemblyName FROM inventoryShadeMaker_New WHERE shadeType = @mappedShadeType)) ORDER BY itemName

--SELECT * FROM #tempPartsList

IF OBJECT_ID('tempdb..#tempUnitDetails') IS NOT NULL DROP TABLE #tempUnitDetails
CREATE TABLE #tempUnitDetails
(id INT,
wizardID NVARCHAR(MAX),
unitID INT,
unitNumber  INT,
pageName NVARCHAR(MAX),
attributeName NVARCHAR(MAX),
attributeValue NVARCHAR(MAX)
)

INSERT INTO #tempUnitDetails
SELECT * FROM wizardUnitDetails WHERE wizardID = @wizardGUID AND unitID = @unitID

DECLARE @width DECIMAL(18,3) = (SELECT attributeValue FROM #tempUnitDetails WHERE attributeName = 'width')
DECLARE @drop DECIMAL(18,3) = (SELECT attributeValue FROM #tempUnitDetails WHERE attributeName = 'drop')
DECLARE @motorType NVARCHAR(MAX) = (SELECT attributeValue FROM #tempUnitDetails WHERE attributeName = 'motorModel')
DECLARE @motorAssemblyName NVARCHAR(MAX)
DECLARE @handing NVARCHAR(MAX) = (SELECT attributeValue FROM #tempUnitDetails WHERE attributeName = 'handing')
DECLARE @opType NVARCHAR(MAX) = (SELECT attributeValue FROM #tempUnitDetails WHERE attributeName = 'opType')
DECLARE @guideOpt NVARCHAR(MAX) = (SELECT attributeValue FROM #tempUnitDetails WHERE attributeName = 'guideOpt')
DECLARE @fabricName NVARCHAR(MAX) = (SELECT attributeValue FROM #tempUnitDetails WHERE attributeName = 'fabricColor')
DECLARE @fabricNSName NVARCHAR(MAX) = (SELECT nsName FROM inventoryNsFabricLookup WHERE osaatName = @fabricName)

DECLARE @fabricNsID int = (SELECT nsID FROM inventoryMasterPartsList_New WHERE itemName = @fabricNSName)

SET @fabricNsID = CASE WHEN @fabricNsID IS NULL THEN
(CASE WHEN @fabricName LIKE '%Suntex%' THEN
1898
WHEN @fabricName LIKE '%Soltis%' THEN
2042
WHEN @fabricName LIKE '%Awning/Marine%' THEN
2055
WHEN @fabricName LIKE '%Braid%' THEN
2055
WHEN @fabricName LIKE '%Vinyl%' THEN
2089
WHEN @fabricName LIKE '%Textilene%' THEN
2090
END)
ELSE
@fabricNsID
END


--ADD FABRIC AND SET VALUES
INSERT INTO #tempPartsList SELECT id,swscPN, itemName, unitstype, formula, nsID, 0.0, 0.0 FROM inventoryMasterPartsList_New WHERE nsID = @fabricNsID
DECLARE @maxFabricSide DECIMAL(18,3) = (SELECT MAX(attributeValue) FROM #tempUnitDetails WHERE attributeName IN ('width','drop'))



--LOOKUP MOTOR TYPE AND GET ITEMS
SET @motorAssemblyName = CASE WHEN (@motorType IN ('Premium CMO','Economy CMO','Economy','SWSC 20','PREMIUM 25 SENSE') OR @motorType LIKE '%Premium%') AND @opType = 'Motorized' THEN
@mappedShadeType + ' - Gaposa'
WHEN  @motorType IN ('Helios') THEN
@mappedShadeType + ' - Dooya'
WHEN  @motorType NOT IN ('Helios', 'Premium CMO','Economy CMO','Economy','SWSC 20','PREMIUM 25 SENSE') AND @opType = 'Motorized' THEN
@mappedShadeType + ' - Somfy'
END

--ADD MOTOR ASSEMBLY ITEMS TO LIST
INSERT INTO #tempPartsList
SELECT id,swscPN, itemName, unitstype, formula, nsID, 0.0, 0.0 FROM inventoryMasterPartsList_New WHERE id IN (SELECT partID FROM inventoryAssembly_New WHERE assemblyName = @motorAssemblyName) ORDER BY itemName


UPDATE #tempPartsList SET deduction = (CASE WHEN swscName IN ('Box, Bottom, 4.5','Box, hood, 4.5') THEN
(SELECT variableDecimal FROM webExteriorFormulars WHERE shadeType = @shadeType AND variableName = 'BoxCut')
WHEN swscName IN ('Tube, Roller, 70mm, Gal') AND @width < 204.00 THEN
(SELECT variableDecimal FROM webExteriorFormulars WHERE shadeType = @shadeType AND variableName = 'TubeCut')
WHEN swscName IN ('Tube, Roller, 70mm, Gal') AND @width > 204.125 THEN
(SELECT variableDecimal FROM webExteriorFormulars WHERE shadeType = @shadeType AND variableName = 'TubeCut>204.125')
WHEN swscName IN ('Hembar, STD, A') THEN
(SELECT variableDecimal FROM webExteriorFormulars WHERE shadeType = @shadeType AND variableName = 'FRTHemBarCut')
WHEN swscName IN ('Flat Stock, Steel, 3/16 X 1') THEN
(SELECT variableDecimal FROM webExteriorFormulars WHERE shadeType = @shadeType AND variableName = '.5X1SteelSTock')
WHEN swscName IN ('Track, STD, A') THEN
(SELECT variableDecimal FROM webExteriorFormulars WHERE shadeType = @shadeType AND variableName = 'FRTTRACK')
WHEN swscName IN ('Removable, Track') THEN
(SELECT variableDecimal FROM webExteriorFormulars WHERE shadeType = @shadeType AND variableName = 'FRTTRACK')
WHEN swscName IN ('Insert, STD') THEN
(SELECT variableDecimal FROM webExteriorFormulars WHERE shadeType = @shadeType AND variableName = 'FRTVTLTRKCAP')
WHEN swscName IN ('Zipper, #6, Black','Keeder, 8.5mm, Black','Keeder, 6mm, Black') THEN
(SELECT variableDecimal FROM webExteriorFormulars WHERE shadeType = @shadeType AND variableName = 'CutFabricHeight')
WHEN swscName IN ('Angle, 1 X 2.5 X .125 X 240') THEN
(SELECT variableDecimal FROM webExteriorFormulars WHERE shadeType = @shadeType AND variableName = '.5X1SteelSTock')
END)



UPDATE #tempPartsList SET qtyRerquired = (CASE WHEN formular = 'lxw' THEN 
@width + deduction
WHEN formular = 'lxd' THEN 
@drop + deduction
WHEN formular = 'lxdx2' THEN 
(@drop + deduction) * 2
WHEN partType = 'Each' THEN
CAST(formular AS DECIMAL(18,3))
WHEN @handing = 'Left' AND partType = 'EachL' THEN
CAST(formular AS DECIMAL(18,3))
WHEN @handing = 'Right' AND partType = 'EachR' THEN
CAST(formular AS DECIMAL(18,3))
END)

DECLARE @fabricQtyReq DECIMAL(18,3) = CASE WHEN @maxFabricSide < (SELECT formular FROM #tempPartsList WHERE nsID = @fabricNsID) THEN
(SELECT CAST(MAX(attributeValue) AS DECIMAL(18,3)) FROM #tempUnitDetails WHERE attributeName IN ('width','drop')) + 40
ELSE
((SELECT CAST(MIN(attributeValue) AS DECIMAL(18,3)) FROM #tempUnitDetails WHERE attributeName IN ('width','drop')) * 2) + 100
END

UPDATE #tempPartsList SET deduction = 0.0, qtyRerquired = @fabricQtyReq WHERE nsID = @fabricNsID

--SELECT * FROM #tempPartsList
--SELECT * FROM #tempUnitDetails
--SELECT * FROM webExteriorFormulars WHERE shadeType = @shadeType



IF OBJECT_ID('tempdb..#tempItemMain') IS NOT NULL DROP TABLE #tempItemMain
CREATE TABLE #tempItemMain
([count] INT,
hasMore bit
)
INSERT INTO #tempItemMain SELECT COUNT(*),0 FROM #tempPartsList

IF OBJECT_ID('tempdb..#tempNsID') IS NOT NULL DROP TABLE #tempNsID
CREATE TABLE #tempNsID
(nsID INT
)
INSERT INTO #tempNsID SELECT nsID FROM #tempPartsList


--SELECT * FROM #tempPartsList
--SELECT * FROM #tempItemMain
--SELECT * FROM #tempNsID

DECLARE @OriginalJSON NVARCHAR(MAX)
Set @OriginalJSON='{"item":{"count":' + CAST((SELECT [count] FROM #tempItemMain) AS NVARCHAR(MAX)) + ',"hasMore": false, "items": '

--SELECT @OriginalJSON

DECLARE @jsonItems NVARCHAR(MAX)

SET @jsonItems =
(SELECT 
1 as 'assemblyLevel',

	1 AS 'commitInventory.id',
	'Available Qty' AS 'commitInventory.refName',

CAST(0 AS bit) AS 'commitmentFirm',
CAST(0 AS bit) AS 'createWo',
CAST(0 AS bit) AS 'isClosed',

	item.nsID AS 'item.id',
	item.swscName AS 'item.refName',

item.nsID AS 'itemId',

	'STOCK' AS 'itemSource.id',
	'Stock' AS 'itemSource.refName',

'STOCK' AS 'itemSourceList',

	'InvtPart' AS 'itemType.id',
	'InvtPart' AS 'itemType.refName',

'F' AS 'kitHasDropship',
CAST(0 AS bit) AS 'linked',
CAST(0 AS bit) AS 'marginal',
CAST(0 AS bit) AS 'notInvtCommittable',
qtyRerquired AS 'origAssemblyQty',
CAST(0 AS bit) AS 'printItems',
qtyRerquired AS 'quantity',
0.0 AS 'quantityAvailable',
0.0 AS 'quantityCommitted',
0.0 AS 'quantityFulfilled',
0.0 AS 'quantityOnHand',
CAST(0 AS bit) AS 'roundUpAsComponent'




FROM #tempNsID itemID
LEFT JOIN #tempPartsList item
	ON itemID.nsID = item.nsID
FOR JSON PATH)

SELECT @OriginalJSON + @jsonItems + '}}'


END
