SET QUOTED_IDENTIFIER OFF;
GO

USE [Inventory];
GO

IF SCHEMA_ID(N'dbo') IS NULL
	EXECUTE (N'CREATE SCHEMA [dbo]');
GO

-- Creating trigger on [JEWELTRANSACTIONS]
CREATE TRIGGER TRIG_JEWELTRANSACTION ON [JEWELTRANSACTIONS]
FOR INSERT, UPDATE
AS
BEGIN
	DECLARE @OLDJEWELTRANID AS INT
	DECLARE @NEWJEWELTRANID AS INT
	DECLARE @JEWELNUMBER AS VARCHAR(20)

	SELECT @JEWELNUMBER = I.JEWELNUMBER
		,@NEWJEWELTRANID = I.JEWELTRANSACTIONID
	FROM INSERTED I

	SELECT TOP (1) @OLDJEWELTRANID = J.JEWELTRANSACTIONID
	FROM [JEWELTRANSACTIONS] J
	WHERE JEWELNUMBER = @JEWELNUMBER
		AND JEWELTRANSACTIONID < @NEWJEWELTRANID
	ORDER BY J.JEWELTRANSACTIONID DESC

	UPDATE [JEWELTRANSACTIONS]
	SET UPDATEDTRANSACTIONBY = @NEWJEWELTRANID
	WHERE JEWELTRANSACTIONID = @OLDJEWELTRANID

	IF EXISTS (
			SELECT SyncCatalogData
			FROM FIRMMASTERS
			)
	BEGIN
		DECLARE @SyncCatalogData AS BIT

		SELECT @SyncCatalogData = SyncCatalogData
		FROM FIRMMASTERS

		IF EXISTS (
				SELECT *
				FROM JewelMasters
				WHERE JewelNo = @JEWELNUMBER
				) AND @SyncCatalogData = 1
		BEGIN
			UPDATE [JewelMasters]
			SET [StyleNo] = i.[DesignCode]
				,[JewelDescription] = i.[JewelType]
				,[MetalColor] = i.[MetalColor]
				,[DiamondPcs] = i.[StonePcs]
				,[DiamondWt] = i.[StoneWeight]
				,[CStoneWeight] = i.[CStoneWeight]
				,[CStonePcs] = i.[CStonePcs]
				,[GrsWt] = i.[TotalWeight]
				,[NetWt] = i.[MetalWeight]
				,[AccessedDate] = i.[AccessedDate]
				,[AccessedBy] = i.[AccessedBy]
				,[Active] = CASE i.TransactionType_Enum
					WHEN 856 -- SALES
						THEN 0
					WHEN 861 -- APPROVAL
						THEN 0
					WHEN 859 -- CANCELLED
						THEN 0
					ELSE 1
					END
			FROM INSERTED i
			JOIN [JewelMasters] j ON i.[JewelNumber] = j.JewelNo
		END
		ELSE IF @SyncCatalogData = 1
		BEGIN
			INSERT INTO [dbo].[JewelMasters] (
				[JewelNo]
				,[StyleNo]
				,[JewelDescription]
				,[MetalColor]
				,[DiamondPcs]
				,[DiamondWt]
				,[CStoneWeight]
				,[CStonePcs]
				,[GrsWt]
				,[NetWt]
				,[AccessedDate]
				,[AccessedBy]
				,[Active]
				)
			SELECT [JewelNumber]
				,[DesignCode]
				,[JewelType]
				,[MetalColor]
				,[StoneWeight]
				,[StonePcs]
				,[CStoneWeight]
				,[CStonePcs]
				,[TotalWeight]
				,[MetalWeight]
				,[AccessedDate]
				,[AccessedBy]
				,1
			FROM INSERTED
		END
	END
END
