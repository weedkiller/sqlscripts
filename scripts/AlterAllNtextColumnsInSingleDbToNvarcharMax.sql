/*

	T-SQL script to convert all NTEXT columns in a SQL Server database
	to NVARCHAR(MAX).

	Copyright � 2014 Bart Read
	http://www.bartread.com/

*/

USE _YOUR_DATABASE_NAME_
GO

SET NOCOUNT ON;

-- Set this to 0 to actually run commands, 1 to only print them.
DECLARE @printCommandsOnly BIT = 1;

-- Migrate columns NTEXT -> NVARCHAR(MAX)

DECLARE @object_id INT,
		@columnName SYSNAME,
		@isNullable BIT;

DECLARE @command NVARCHAR(MAX);

DECLARE @ntextColumnInfo TABLE (
	object_id INT,
	ColumnName SYSNAME,
	IsNullable BIT
);

INSERT INTO @ntextColumnInfo ( object_id, ColumnName, IsNullable )
	SELECT  c.object_id, c.name, c.is_nullable
	FROM    sys.columns AS c
	INNER JOIN sys.objects AS o
	ON c.object_id = o.object_id
	WHERE   o.type = 'U' AND c.system_type_id = 99;

DECLARE col_cursor CURSOR FAST_FORWARD FOR
	SELECT object_id, ColumnName, IsNullable FROM @ntextColumnInfo;

OPEN col_cursor;
FETCH NEXT FROM col_cursor INTO @object_id, @columnName, @isNullable;

WHILE @@FETCH_STATUS = 0
BEGIN
	SELECT @command =
		'ALTER TABLE '
		+ QUOTENAME(OBJECT_SCHEMA_NAME(@object_id))
			+ '.' + QUOTENAME(OBJECT_NAME(@object_id))
		+ ' ALTER COLUMN '
		+ QUOTENAME(@columnName)
		+' NVARCHAR(MAX) '
		+ CASE
			WHEN @isNullable = 1 THEN ''
			ELSE 'NOT'
		  END
		+ ' NULL;';
		
	PRINT @command;
	IF @printCommandsOnly = 0
	BEGIN
		EXECUTE sp_executesql @command;
	END

	SELECT @command =
		'UPDATE '
		+ QUOTENAME(OBJECT_SCHEMA_NAME(@object_id))
			+ '.' + QUOTENAME(OBJECT_NAME(@object_id))
		+ ' SET '
		+ QUOTENAME(@columnName)
		+ ' = '
		+ QUOTENAME(@columnName)
		+ ';'

	PRINT @command;
	IF @printCommandsOnly = 0
	BEGIN
		EXECUTE sp_executesql @command;
	END

	FETCH NEXT FROM col_cursor INTO @object_id, @columnName, @isNullable;
END

CLOSE col_cursor;
DEALLOCATE col_cursor;

-- Now refresh the view metadata for all the views in the database
-- (We may not need to do them all but it won't hurt.)

DECLARE @viewObjectIds TABLE (
	object_id INT
);

INSERT INTO @viewObjectIds
	SELECT o.object_id
	FROM sys.objects AS o
	WHERE o.type = 'V';

DECLARE view_cursor CURSOR FAST_FORWARD FOR
	SELECT object_id FROM @viewObjectIds;

OPEN view_cursor;
FETCH NEXT FROM view_cursor INTO @object_id;

WHILE @@FETCH_STATUS = 0
BEGIN
	SELECT @command =
		'EXECUTE sp_refreshview '''
		+ QUOTENAME(OBJECT_SCHEMA_NAME(@object_id)) + '.' + QUOTENAME(OBJECT_NAME(@object_id))
		+ ''';';
		
	PRINT @command;

	IF @printCommandsOnly = 0
	BEGIN
		EXECUTE sp_executesql @command;
	END

	FETCH NEXT FROM view_cursor INTO @object_id;
END

CLOSE view_cursor;
DEALLOCATE view_cursor;
GO