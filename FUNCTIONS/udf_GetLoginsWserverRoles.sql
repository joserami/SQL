SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
GO

-- ==========================================================================================
-- Script Name:	udf_GetLoginsWserverRoles
-- Author:		Jose A. Ramirez
-- Create date:	2015-07-27
-- Description:	Get a list of all Logins with assigned DB Server Roles.  
--				This is a table-value function.
--				May be used for auditing purposes, migration, log-shipping (if you consider 
--																logins as part of your strategy)

/* Usage:		
				select * from [dbo].[udf_GetLoginsWserverRoles]();

========================================================================================= */

/* 
   Change History:  2015-07-27  Created script
*/
-- ==========================================================================================
CREATE FUNCTION [dbo].[udf_GetLoginsWserverRoles] 
(	
)
RETURNS TABLE 
AS
RETURN 
(
    with sqllogins as (
    select sp.name AS [LoginName], sp.type_desc, s.is_policy_checked
	   , [sysadmin] = case when IS_SRVROLEMEMBER('sysadmin', sp.name) = 1 then 'yes' else 'no' end
	   , [serveradmin] = case when IS_SRVROLEMEMBER('serveradmin', sp.name) = 1 then 'yes' else 'no' end
	   , [securityadmin] = case when IS_SRVROLEMEMBER('securityadmin', sp.name) = 1 then 'yes' else 'no' end
	   , [processadmin] = case when IS_SRVROLEMEMBER('processadmin', sp.name) = 1 then 'yes' else 'no' end
	   , [setupadmin] = case when IS_SRVROLEMEMBER('setupadmin', sp.name) = 1 then 'yes' else 'no' end
	   , [bulkadmin] = case when IS_SRVROLEMEMBER('bulkadmin', sp.name) = 1 then 'yes' else 'no' end
	   , [diskadmin] = case when IS_SRVROLEMEMBER('diskadmin', sp.name) = 1 then 'yes' else 'no' end
	   , [dbcreator] = case when IS_SRVROLEMEMBER('dbcreator', sp.name) = 1 then 'yes' else 'no' end
    from master.sys.server_principals sp
    LEFT JOIN master.sys.sql_logins s on s.sid = sp.sid
    where sp.[type] in ('S','U','G')
    and (not sp.name like '##%' and not sp.name in ('sa','NT AUTHORITY\SYSTEM')))
    select * from sqllogins 
    where [sysadmin] = 'yes'
    or [serveradmin]  = 'yes'
    or [securityadmin]  = 'yes'
    or [processadmin]  = 'yes'
    or [setupadmin]  = 'yes'
    or [bulkadmin]  = 'yes'
    or [diskadmin]  = 'yes'
    or [dbcreator]  = 'yes'
)

GO