-- Invoke-SqlCriticalErrorLogPollution.sql
--  🐉Danger: Deliberately adding high severity errors to the SQL ERRORLOG for demonstration purposes

-- This script will inject the ERRORLOG with high-severity errors for demonstration purposes.
-- Pollute the ERRORLOG, please.  I like to randomly disconnect queries.  I understand the risks of this potentially dangerous choice.
DECLARE @RandomErrorID INT, @ErrorMessage NVARCHAR(2048), @Severity INT, @LoopCounter INT = 1, @NumberOfLoops INT;

-- Set the number of loops here
SET @NumberOfLoops = CAST(RAND()*(19-11+1) AS INT) + 11 -- random number between 11 and 19

WHILE @LoopCounter <= @NumberOfLoops
BEGIN
    -- Select a high-severity error for demonstration because chaos monkeys 🐒 like high-severity errors
    SELECT TOP 1 @RandomErrorID = message_id, @ErrorMessage = text, @Severity = severity
    
    FROM sys.messages
    WHERE language_id = 1033 -- Assuming English
    AND severity >= 19 -- Adjusted for WITH LOG
    ORDER BY NEWID();

    -- Raise the error with WITH LOG
    -- Ensure the script is executed with an account that has ALTER TRACE permission
    RAISERROR (@ErrorMessage, @Severity, 1) WITH LOG;

    -- Increment the loop counter
    SET @LoopCounter = @LoopCounter + 1;
END