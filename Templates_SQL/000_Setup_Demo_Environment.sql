/* 
	Roelant Vos
	Data Vault ETL generation examples
*/

USE [Sandbox];

GO

IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = 'interface')
BEGIN
  EXEC ('CREATE SCHEMA [interface] AUTHORIZATION dbo');
END

/*
	Remove existing tables, if they indeed exist
*/
PRINT 'Removing tables if they already exist.'
IF OBJECT_ID('interface.INTERFACE_DRIVING_KEY', 'U') IS NOT NULL DROP TABLE [interface].[INTERFACE_DRIVING_KEY]
IF OBJECT_ID('interface.INTERFACE_HUB_LINK_XREF', 'U') IS NOT NULL DROP TABLE [interface].[INTERFACE_HUB_LINK_XREF]
IF OBJECT_ID('interface.INTERFACE_SOURCE_HUB_XREF', 'U') IS NOT NULL DROP TABLE [interface].[INTERFACE_SOURCE_HUB_XREF]
IF OBJECT_ID('interface.INTERFACE_SOURCE_LINK_ATTRIBUTE_XREF', 'U') IS NOT NULL DROP TABLE [interface].[INTERFACE_SOURCE_LINK_ATTRIBUTE_XREF]
IF OBJECT_ID('interface.INTERFACE_SOURCE_LINK_XREF', 'U') IS NOT NULL DROP TABLE [interface].[INTERFACE_SOURCE_LINK_XREF]
IF OBJECT_ID('interface.INTERFACE_SOURCE_SATELLITE_ATTRIBUTE_XREF', 'U') IS NOT NULL DROP TABLE [interface].[INTERFACE_SOURCE_SATELLITE_ATTRIBUTE_XREF]
IF OBJECT_ID('interface.INTERFACE_SOURCE_SATELLITE_XREF', 'U') IS NOT NULL DROP TABLE [interface].[INTERFACE_SOURCE_SATELLITE_XREF]
IF OBJECT_ID('interface.INTERFACE_SOURCE_TO_STAGING', 'U') IS NOT NULL DROP TABLE [interface].[INTERFACE_SOURCE_TO_STAGING]
GO

/* 
	Create tables 
*/

PRINT CHAR(13)+'Creating tables.'

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE TABLE [interface].[INTERFACE_HUB_LINK_XREF](
	[LINK_ID] [int] NOT NULL,
	[LINK_NAME] [varchar](100) NOT NULL,
	[SOURCE_ID] [int] NOT NULL,
	[SOURCE_NAME] [varchar](100) NOT NULL,
	[SOURCE_SCHEMA_NAME] [varchar](100) NULL,
	[HUB_ID] [int] NOT NULL,
	[HUB_NAME] [varchar](100) NOT NULL,
	[HUB_ORDER] [int] NOT NULL,
	[BUSINESS_KEY_DEFINITION] [varchar](4000) NULL
) ON [PRIMARY]
GO

CREATE TABLE [interface].[INTERFACE_SOURCE_HUB_XREF](
	[SOURCE_ID] [int] NOT NULL,
	[SOURCE_SCHEMA_NAME] [varchar](100) NULL,
	[SOURCE_NAME] [varchar](100) NOT NULL,
	[SOURCE_BUSINESS_KEY_DEFINITION] [varchar](4000) NOT NULL,
	[TARGET_ID] [int] NOT NULL,
	[TARGET_SCHEMA_NAME] [varchar](100) NULL,
	[TARGET_NAME] [varchar](100) NOT NULL,
	[TARGET_BUSINESS_KEY_DEFINITION] [varchar](100) NULL,
	[FILTER_CRITERIA] [varchar](4000) NULL,
	[LOAD_VECTOR] [varchar](100) NULL
) ON [PRIMARY]
GO

CREATE TABLE [interface].[INTERFACE_SOURCE_LINK_XREF](
	[SOURCE_ID] [int] NOT NULL,
	[SOURCE_NAME] [varchar](100) NOT NULL,
	[TARGET_ID] [int] NOT NULL,
	[TARGET_NAME] [varchar](100) NOT NULL,
	[SOURCE_BUSINESS_KEY_DEFINITION] [varchar](4000) NOT NULL,
	[SURROGATE_KEY] [varchar](100) NOT NULL,
	[FILTER_CRITERIA] [varchar](4000) NULL,
	[LOAD_VECTOR] [varchar](100) NULL
) ON [PRIMARY]
GO

CREATE TABLE [interface].[INTERFACE_SOURCE_SATELLITE_XREF](
	[SOURCE_ID] [int] NOT NULL,
	[SOURCE_NAME] [varchar](100) NOT NULL,
	[SOURCE_BUSINESS_KEY_DEFINITION] [varchar](4000) NULL,
	[TARGET_BUSINESS_KEY_DEFINITION] [varchar](4000) NULL,
	[FILTER_CRITERIA] [varchar](4000) NULL,
	[TARGET_ID] [int] NOT NULL,
	[TARGET_NAME] [varchar](100) NOT NULL,
	[TARGET_TYPE] [varchar](100) NOT NULL,
	[SURROGATE_KEY] [varchar](100) NOT NULL,
	[HUB_ID] [int] NOT NULL,
	[HUB_NAME] [varchar](100) NOT NULL,
	[LINK_ID] [int] NOT NULL,
	[LINK_NAME] [varchar](100) NOT NULL,
	[LOAD_VECTOR] [varchar](100) NULL
) ON [PRIMARY]
GO

CREATE TABLE [interface].[INTERFACE_SOURCE_SATELLITE_ATTRIBUTE_XREF](
	[SOURCE_ID] [int] NOT NULL,
	[SOURCE_NAME] [varchar](100) NOT NULL,
	[SOURCE_SCHEMA_NAME] [varchar](100) NULL,
	[TARGET_ID] [int] NOT NULL,
	[TARGET_NAME] [varchar](100) NOT NULL,
	[SOURCE_ATTRIBUTE_ID] [int] NOT NULL,
	[SOURCE_ATTRIBUTE_NAME] [varchar](100) NOT NULL,
	[TARGET_ATTRIBUTE_ID] [int] NOT NULL,
	[TARGET_ATTRIBUTE_NAME] [varchar](100) NULL,
	[MULTI_ACTIVE_KEY_INDICATOR] [varchar](100) NOT NULL
) ON [PRIMARY]
GO

CREATE TABLE [interface].[INTERFACE_SOURCE_TO_STAGING](
	[STAGING_AREA_NAME] [sysname] NOT NULL,
	[SCHEMA_NAME] [varchar](128) NOT NULL,
	[SOURCE_TABLE_NAME] [nvarchar](128) NULL,
	[SOURCE_TABLE_SYSTEM_NAME] [nvarchar](128) NULL,
	[CHANGE_DATA_CAPTURE_TYPE] [varchar](100) NULL,
	[CHANGE_DATETIME_DEFINITION] [varchar](4000) NULL,
	[PROCESS_INDICATOR] [varchar](1) NULL
) ON [PRIMARY]
GO

CREATE TABLE [interface].[INTERFACE_DRIVING_KEY](
	[SATELLITE_ID] [int] NOT NULL,
	[SATELLITE_NAME] [varchar](100) NULL,
	[HUB_ID] [int] NOT NULL,
	[HUB_NAME] [varchar](100) NULL
) ON [PRIMARY]
GO

CREATE TABLE [interface].[INTERFACE_SOURCE_LINK_ATTRIBUTE_XREF](
	[SOURCE_ID] [int] NOT NULL,
	[SOURCE_NAME] [varchar](100) NOT NULL,
	[SOURCE_SCHEMA_NAME] [varchar](100) NULL,
	[LINK_ID] [int] NOT NULL,
	[LINK_NAME] [varchar](100) NOT NULL,
	[SOURCE_ATTRIBUTE_ID] [int] NOT NULL,
	[SOURCE_ATTRIBUTE_NAME] [varchar](100) NOT NULL,
	[LINK_ATTRIBUTE_ID] [int] NOT NULL,
	[LINK_ATTRIBUTE_NAME] [varchar](100) NULL
) ON [PRIMARY]
GO


PRINT CHAR(13)+'Creating sample metadata records.'
--
-- Source / Hub relationship
INSERT [interface].[INTERFACE_SOURCE_HUB_XREF] ([SOURCE_ID], [SOURCE_SCHEMA_NAME], [SOURCE_NAME], [SOURCE_BUSINESS_KEY_DEFINITION], [TARGET_ID], [TARGET_SCHEMA_NAME], [TARGET_NAME], [TARGET_BUSINESS_KEY_DEFINITION], [FILTER_CRITERIA]) VALUES (2, N'dbo', N'STG_PROFILER_OFFER', N'OfferID', 2, N'dbo', N'HUB_INCENTIVE_OFFER', N'OFFER_ID', N'3=3')
INSERT [interface].[INTERFACE_SOURCE_HUB_XREF] ([SOURCE_ID], [SOURCE_SCHEMA_NAME], [SOURCE_NAME], [SOURCE_BUSINESS_KEY_DEFINITION], [TARGET_ID], [TARGET_SCHEMA_NAME], [TARGET_NAME], [TARGET_BUSINESS_KEY_DEFINITION], [FILTER_CRITERIA]) VALUES (3, N'dbo', N'STG_PROFILER_CUSTOMER_PERSONAL', N'CustomerID', 3, N'dbo', N'HUB_CUSTOMER', N'CUSTOMER_ID', N'1=1')
INSERT [interface].[INTERFACE_SOURCE_HUB_XREF] ([SOURCE_ID], [SOURCE_SCHEMA_NAME], [SOURCE_NAME], [SOURCE_BUSINESS_KEY_DEFINITION], [TARGET_ID], [TARGET_SCHEMA_NAME], [TARGET_NAME], [TARGET_BUSINESS_KEY_DEFINITION], [FILTER_CRITERIA]) VALUES (4, N'dbo', N'STG_PROFILER_PLAN', N'COMPOSITE(Plan_Code;RECORD_SOURCE)', 4, N'dbo', N'HUB_MEMBERSHIP_PLAN', N'PLAN_CODE,PLAN_SUFFIX', N'10=10')
INSERT [interface].[INTERFACE_SOURCE_HUB_XREF] ([SOURCE_ID], [SOURCE_SCHEMA_NAME], [SOURCE_NAME], [SOURCE_BUSINESS_KEY_DEFINITION], [TARGET_ID], [TARGET_SCHEMA_NAME], [TARGET_NAME], [TARGET_BUSINESS_KEY_DEFINITION], [FILTER_CRITERIA]) VALUES (5, N'dbo', N'STG_PROFILER_PERSONALISED_COSTING', N'Member', 3, N'dbo', N'HUB_CUSTOMER', N'CUSTOMER_ID', N'')
INSERT [interface].[INTERFACE_SOURCE_HUB_XREF] ([SOURCE_ID], [SOURCE_SCHEMA_NAME], [SOURCE_NAME], [SOURCE_BUSINESS_KEY_DEFINITION], [TARGET_ID], [TARGET_SCHEMA_NAME], [TARGET_NAME], [TARGET_BUSINESS_KEY_DEFINITION], [FILTER_CRITERIA]) VALUES (5, N'dbo', N'STG_PROFILER_PERSONALISED_COSTING', N'COMPOSITE(Plan_Code;RECORD_SOURCE)', 4, N'dbo', N'HUB_MEMBERSHIP_PLAN', N'PLAN_CODE,PLAN_SUFFIX', N'18=18')
INSERT [interface].[INTERFACE_SOURCE_HUB_XREF] ([SOURCE_ID], [SOURCE_SCHEMA_NAME], [SOURCE_NAME], [SOURCE_BUSINESS_KEY_DEFINITION], [TARGET_ID], [TARGET_SCHEMA_NAME], [TARGET_NAME], [TARGET_BUSINESS_KEY_DEFINITION], [FILTER_CRITERIA]) VALUES (5, N'dbo', N'STG_PROFILER_PERSONALISED_COSTING', N'CONCATENATE(Segment;RECORD_SOURCE)', 5, N'dbo', N'HUB_SEGMENT', N'SEGMENT_CODE', N'')
INSERT [interface].[INTERFACE_SOURCE_HUB_XREF] ([SOURCE_ID], [SOURCE_SCHEMA_NAME], [SOURCE_NAME], [SOURCE_BUSINESS_KEY_DEFINITION], [TARGET_ID], [TARGET_SCHEMA_NAME], [TARGET_NAME], [TARGET_BUSINESS_KEY_DEFINITION], [FILTER_CRITERIA]) VALUES (6, N'dbo', N'STG_PROFILER_ESTIMATED_WORTH', N'COMPOSITE(Plan_Code;RECORD_SOURCE)', 4, N'dbo', N'HUB_MEMBERSHIP_PLAN', N'PLAN_CODE,PLAN_SUFFIX', N'12=12')
INSERT [interface].[INTERFACE_SOURCE_HUB_XREF] ([SOURCE_ID], [SOURCE_SCHEMA_NAME], [SOURCE_NAME], [SOURCE_BUSINESS_KEY_DEFINITION], [TARGET_ID], [TARGET_SCHEMA_NAME], [TARGET_NAME], [TARGET_BUSINESS_KEY_DEFINITION], [FILTER_CRITERIA]) VALUES (7, N'dbo', N'STG_PROFILER_CUST_MEMBERSHIP', N'CustomerID', 3, N'dbo', N'HUB_CUSTOMER', N'CUSTOMER_ID', N'15=15')
INSERT [interface].[INTERFACE_SOURCE_HUB_XREF] ([SOURCE_ID], [SOURCE_SCHEMA_NAME], [SOURCE_NAME], [SOURCE_BUSINESS_KEY_DEFINITION], [TARGET_ID], [TARGET_SCHEMA_NAME], [TARGET_NAME], [TARGET_BUSINESS_KEY_DEFINITION], [FILTER_CRITERIA]) VALUES (7, N'dbo', N'STG_PROFILER_CUST_MEMBERSHIP', N'COMPOSITE(Plan_Code;RECORD_SOURCE)', 4, N'dbo', N'HUB_MEMBERSHIP_PLAN', N'PLAN_CODE,PLAN_SUFFIX', N'14=14')
INSERT [interface].[INTERFACE_SOURCE_HUB_XREF] ([SOURCE_ID], [SOURCE_SCHEMA_NAME], [SOURCE_NAME], [SOURCE_BUSINESS_KEY_DEFINITION], [TARGET_ID], [TARGET_SCHEMA_NAME], [TARGET_NAME], [TARGET_BUSINESS_KEY_DEFINITION], [FILTER_CRITERIA]) VALUES (9, N'dbo', N'STG_PROFILER_CUSTOMER_OFFER', N'OfferID', 2, N'dbo', N'HUB_INCENTIVE_OFFER', N'OFFER_ID', N'6=6')
INSERT [interface].[INTERFACE_SOURCE_HUB_XREF] ([SOURCE_ID], [SOURCE_SCHEMA_NAME], [SOURCE_NAME], [SOURCE_BUSINESS_KEY_DEFINITION], [TARGET_ID], [TARGET_SCHEMA_NAME], [TARGET_NAME], [TARGET_BUSINESS_KEY_DEFINITION], [FILTER_CRITERIA]) VALUES (9, N'dbo', N'STG_PROFILER_CUSTOMER_OFFER', N'CustomerID', 3, N'dbo', N'HUB_CUSTOMER', N'CUSTOMER_ID', N'5=5')
-- Hub / Link relationship
INSERT [interface].[INTERFACE_HUB_LINK_XREF] ([LINK_ID], [LINK_NAME], [SOURCE_ID], [SOURCE_NAME], [SOURCE_SCHEMA_NAME], [HUB_ID], [HUB_NAME], [HUB_ORDER], [BUSINESS_KEY_DEFINITION]) VALUES (2, N'LNK_CUSTOMER_COSTING', 5, N'STG_PROFILER_PERSONALISED_COSTING', N'dbo', 3, N'HUB_CUSTOMER', 2, N'Member')
INSERT [interface].[INTERFACE_HUB_LINK_XREF] ([LINK_ID], [LINK_NAME], [SOURCE_ID], [SOURCE_NAME], [SOURCE_SCHEMA_NAME], [HUB_ID], [HUB_NAME], [HUB_ORDER], [BUSINESS_KEY_DEFINITION]) VALUES (2, N'LNK_CUSTOMER_COSTING', 5, N'STG_PROFILER_PERSONALISED_COSTING', N'dbo', 4, N'HUB_MEMBERSHIP_PLAN', 1, N'COMPOSITE(Plan_Code;RECORD_SOURCE)')
INSERT [interface].[INTERFACE_HUB_LINK_XREF] ([LINK_ID], [LINK_NAME], [SOURCE_ID], [SOURCE_NAME], [SOURCE_SCHEMA_NAME], [HUB_ID], [HUB_NAME], [HUB_ORDER], [BUSINESS_KEY_DEFINITION]) VALUES (2, N'LNK_CUSTOMER_COSTING', 5, N'STG_PROFILER_PERSONALISED_COSTING', N'dbo', 5, N'HUB_SEGMENT', 3, N'CONCATENATE(Segment;RECORD_SOURCE)')
INSERT [interface].[INTERFACE_HUB_LINK_XREF] ([LINK_ID], [LINK_NAME], [SOURCE_ID], [SOURCE_NAME], [SOURCE_SCHEMA_NAME], [HUB_ID], [HUB_NAME], [HUB_ORDER], [BUSINESS_KEY_DEFINITION]) VALUES (4, N'LNK_MEMBERSHIP', 7, N'STG_PROFILER_CUST_MEMBERSHIP', N'dbo', 3, N'HUB_CUSTOMER', 1, N'CustomerID')
INSERT [interface].[INTERFACE_HUB_LINK_XREF] ([LINK_ID], [LINK_NAME], [SOURCE_ID], [SOURCE_NAME], [SOURCE_SCHEMA_NAME], [HUB_ID], [HUB_NAME], [HUB_ORDER], [BUSINESS_KEY_DEFINITION]) VALUES (4, N'LNK_MEMBERSHIP', 7, N'STG_PROFILER_CUST_MEMBERSHIP', N'dbo', 4, N'HUB_MEMBERSHIP_PLAN', 2, N'COMPOSITE(Plan_Code;RECORD_SOURCE)')
INSERT [interface].[INTERFACE_HUB_LINK_XREF] ([LINK_ID], [LINK_NAME], [SOURCE_ID], [SOURCE_NAME], [SOURCE_SCHEMA_NAME], [HUB_ID], [HUB_NAME], [HUB_ORDER], [BUSINESS_KEY_DEFINITION]) VALUES (3, N'LNK_CUSTOMER_OFFER', 9, N'STG_PROFILER_CUSTOMER_OFFER', N'dbo', 2, N'HUB_INCENTIVE_OFFER', 2, N'OfferID')
INSERT [interface].[INTERFACE_HUB_LINK_XREF] ([LINK_ID], [LINK_NAME], [SOURCE_ID], [SOURCE_NAME], [SOURCE_SCHEMA_NAME], [HUB_ID], [HUB_NAME], [HUB_ORDER], [BUSINESS_KEY_DEFINITION]) VALUES (3, N'LNK_CUSTOMER_OFFER', 9, N'STG_PROFILER_CUSTOMER_OFFER', N'dbo', 3, N'HUB_CUSTOMER', 1, N'CustomerID')
INSERT [interface].[INTERFACE_HUB_LINK_XREF] ([LINK_ID], [LINK_NAME], [SOURCE_ID], [SOURCE_NAME], [SOURCE_SCHEMA_NAME], [HUB_ID], [HUB_NAME], [HUB_ORDER], [BUSINESS_KEY_DEFINITION]) VALUES (5, N'LNK_RENEWAL_MEMBERSHIP', 4, N'STG_PROFILER_PLAN', N'dbo', 4, N'HUB_MEMBERSHIP_PLAN', 1, N'COMPOSITE(Plan_Code;RECORD_SOURCE)')
INSERT [interface].[INTERFACE_HUB_LINK_XREF] ([LINK_ID], [LINK_NAME], [SOURCE_ID], [SOURCE_NAME], [SOURCE_SCHEMA_NAME], [HUB_ID], [HUB_NAME], [HUB_ORDER], [BUSINESS_KEY_DEFINITION]) VALUES (5, N'LNK_RENEWAL_MEMBERSHIP', 4, N'STG_PROFILER_PLAN', N'dbo', 4, N'HUB_MEMBERSHIP_PLAN', 2, N'COMPOSITE(Renewal_Plan_Code;RECORD_SOURCE)')
-- Source / Link relationship
INSERT [interface].[INTERFACE_SOURCE_LINK_XREF] ([SOURCE_ID], [SOURCE_NAME], [TARGET_ID], [TARGET_NAME], [SURROGATE_KEY], [SOURCE_BUSINESS_KEY_DEFINITION], [FILTER_CRITERIA]) VALUES (5, N'STG_PROFILER_PERSONALISED_COSTING', 2, N'LNK_CUSTOMER_COSTING', 'CUSTOMER_COSTING_SK', 'COMPOSITE(Plan_Code;''XYZ''), Member, CONCATENATE(Segment;''TEST'')', N'')
INSERT [interface].[INTERFACE_SOURCE_LINK_XREF] ([SOURCE_ID], [SOURCE_NAME], [TARGET_ID], [TARGET_NAME], [SURROGATE_KEY], [SOURCE_BUSINESS_KEY_DEFINITION], [FILTER_CRITERIA]) VALUES (7, N'STG_PROFILER_CUST_MEMBERSHIP', 4, N'LNK_MEMBERSHIP', 'MEMBERSHIP_SK', 'CustomerID, COMPOSITE(Plan_Code;''XYZ'')', N'16=16')
INSERT [interface].[INTERFACE_SOURCE_LINK_XREF] ([SOURCE_ID], [SOURCE_NAME], [TARGET_ID], [TARGET_NAME], [SURROGATE_KEY], [SOURCE_BUSINESS_KEY_DEFINITION], [FILTER_CRITERIA]) VALUES (9, N'STG_PROFILER_CUSTOMER_OFFER', 3, N'LNK_CUSTOMER_OFFER', 'CUSTOMER_OFFER_SK', 'CustomerID, OfferID', N'7=7')
-- Source / Satellite relationship
INSERT [interface].[INTERFACE_SOURCE_SATELLITE_XREF] ([SOURCE_ID], [SOURCE_NAME], [SOURCE_BUSINESS_KEY_DEFINITION], [TARGET_BUSINESS_KEY_DEFINITION], [FILTER_CRITERIA], [TARGET_ID], [TARGET_NAME], [TARGET_TYPE], [SURROGATE_KEY], [HUB_ID], [HUB_NAME], [LINK_ID], [LINK_NAME]) VALUES (3, N'STG_PROFILER_CUSTOMER_PERSONAL', N'CustomerID', 'CUSTOMER_ID', N'2=2', 1, N'SAT_CUSTOMER', N'Normal', 'CUSTOMER_SK', 3, N'HUB_CUSTOMER', 1, N'Not applicable')
INSERT [interface].[INTERFACE_SOURCE_SATELLITE_XREF] ([SOURCE_ID], [SOURCE_NAME], [SOURCE_BUSINESS_KEY_DEFINITION], [TARGET_BUSINESS_KEY_DEFINITION], [FILTER_CRITERIA], [TARGET_ID], [TARGET_NAME], [TARGET_TYPE], [SURROGATE_KEY], [HUB_ID], [HUB_NAME], [LINK_ID], [LINK_NAME]) VALUES (3, N'STG_PROFILER_CUSTOMER_PERSONAL', N'CustomerID', 'CUSTOMER_ID', N'', 2, N'SAT_CUSTOMER_ADDITIONAL_DETAILS', N'Normal', 'CUSTOMER_SK', 3, N'HUB_CUSTOMER', 1, N'Not applicable')
INSERT [interface].[INTERFACE_SOURCE_SATELLITE_XREF] ([SOURCE_ID], [SOURCE_NAME], [SOURCE_BUSINESS_KEY_DEFINITION], [TARGET_BUSINESS_KEY_DEFINITION], [FILTER_CRITERIA], [TARGET_ID], [TARGET_NAME], [TARGET_TYPE], [SURROGATE_KEY], [HUB_ID], [HUB_NAME], [LINK_ID], [LINK_NAME]) VALUES (2, N'STG_PROFILER_OFFER', N'OfferID', 'OFFER_ID', N'4=4', 3, N'SAT_INCENTIVE_OFFER', N'Normal', 'INCENTIVE_OFFER_SK', 2, N'HUB_INCENTIVE_OFFER', 1, N'Not applicable')
INSERT [interface].[INTERFACE_SOURCE_SATELLITE_XREF] ([SOURCE_ID], [SOURCE_NAME], [SOURCE_BUSINESS_KEY_DEFINITION], [TARGET_BUSINESS_KEY_DEFINITION], [FILTER_CRITERIA], [TARGET_ID], [TARGET_NAME], [TARGET_TYPE], [SURROGATE_KEY], [HUB_ID], [HUB_NAME], [LINK_ID], [LINK_NAME]) VALUES (4, N'STG_PROFILER_PLAN', N'COMPOSITE(Plan_Code;RECORD_SOURCE)', 'PLAN_CODE,PLAN_SUFFIX', N'11=11', 4, N'SAT_MEMBERSHIP_PLAN_DETAIL', N'Normal', 'MEMBERSHIP_PLAN_SK', 4, N'HUB_MEMBERSHIP_PLAN', 1, N'Not applicable')
INSERT [interface].[INTERFACE_SOURCE_SATELLITE_XREF] ([SOURCE_ID], [SOURCE_NAME], [SOURCE_BUSINESS_KEY_DEFINITION], [TARGET_BUSINESS_KEY_DEFINITION], [FILTER_CRITERIA], [TARGET_ID], [TARGET_NAME], [TARGET_TYPE], [SURROGATE_KEY], [HUB_ID], [HUB_NAME], [LINK_ID], [LINK_NAME]) VALUES (6, N'STG_PROFILER_ESTIMATED_WORTH', N'COMPOSITE(Plan_Code;RECORD_SOURCE)', 'PLAN_CODE,PLAN_SUFFIX', N'13=13', 5, N'SAT_MEMBERSHIP_PLAN_VALUATION', N'Normal', 'MEMBERSHIP_PLAN_SK', 4, N'HUB_MEMBERSHIP_PLAN', 1, N'Not applicable')
INSERT [interface].[INTERFACE_SOURCE_SATELLITE_XREF] ([SOURCE_ID], [SOURCE_NAME], [SOURCE_BUSINESS_KEY_DEFINITION], [TARGET_BUSINESS_KEY_DEFINITION], [FILTER_CRITERIA], [TARGET_ID], [TARGET_NAME], [TARGET_TYPE], [SURROGATE_KEY], [HUB_ID], [HUB_NAME], [LINK_ID], [LINK_NAME]) VALUES (8, N'STG_USERMANAGED_SEGMENT', N'CONCATENATE(Demographic_Segment_Code;RECORD_SOURCE)', 'SEGMENT_CODE', N'9=9', 6, N'SAT_SEGMENT', N'Normal', 'SEGMENT_SK', 5, N'HUB_SEGMENT', 1, N'Not applicable')
INSERT [interface].[INTERFACE_SOURCE_SATELLITE_XREF] ([SOURCE_ID], [SOURCE_NAME], [SOURCE_BUSINESS_KEY_DEFINITION], [TARGET_BUSINESS_KEY_DEFINITION], [FILTER_CRITERIA], [TARGET_ID], [TARGET_NAME], [TARGET_TYPE], [SURROGATE_KEY], [HUB_ID], [HUB_NAME], [LINK_ID], [LINK_NAME]) VALUES (5, N'STG_PROFILER_PERSONALISED_COSTING', NULL, NULL,  N'', 7, N'LSAT_CUSTOMER_COSTING', N'Link Satellite', 'CUSTOMER_COSTING_SK', 1, N'Not applicable', 2, N'LNK_CUSTOMER_COSTING')
INSERT [interface].[INTERFACE_SOURCE_SATELLITE_XREF] ([SOURCE_ID], [SOURCE_NAME], [SOURCE_BUSINESS_KEY_DEFINITION], [TARGET_BUSINESS_KEY_DEFINITION], [FILTER_CRITERIA], [TARGET_ID], [TARGET_NAME], [TARGET_TYPE], [SURROGATE_KEY], [HUB_ID], [HUB_NAME], [LINK_ID], [LINK_NAME]) VALUES (9, N'STG_PROFILER_CUSTOMER_OFFER', NULL, NULL, N'7=7', 8, N'LSAT_CUSTOMER_OFFER', N'Link Satellite', 'CUSTOMER_OFFER_SK', 1, N'Not applicable', 3, N'LNK_CUSTOMER_OFFER')
INSERT [interface].[INTERFACE_SOURCE_SATELLITE_XREF] ([SOURCE_ID], [SOURCE_NAME], [SOURCE_BUSINESS_KEY_DEFINITION], [TARGET_BUSINESS_KEY_DEFINITION], [FILTER_CRITERIA], [TARGET_ID], [TARGET_NAME], [TARGET_TYPE], [SURROGATE_KEY], [HUB_ID], [HUB_NAME], [LINK_ID], [LINK_NAME]) VALUES (7, N'STG_PROFILER_CUST_MEMBERSHIP', NULL, NULL, N'17=17', 9, N'LSAT_MEMBERSHIP', N'Link Satellite', 'MEMBERSHIP_SK', 1, N'Not applicable', 4, N'LNK_MEMBERSHIP')
-- Source / Satellite attribute relationship
INSERT [interface].[INTERFACE_SOURCE_SATELLITE_ATTRIBUTE_XREF] ([SOURCE_ID], [SOURCE_NAME], [SOURCE_SCHEMA_NAME], [TARGET_ID], [TARGET_NAME], [SOURCE_ATTRIBUTE_ID], [SOURCE_ATTRIBUTE_NAME], [TARGET_ATTRIBUTE_ID], [TARGET_ATTRIBUTE_NAME], [MULTI_ACTIVE_KEY_INDICATOR]) VALUES (2, N'STG_PROFILER_OFFER', N'dbo', 3, N'SAT_INCENTIVE_OFFER', 32, N'Offer_Long_Description', 30, N'OFFER_DESCRIPTION', N'N')
INSERT [interface].[INTERFACE_SOURCE_SATELLITE_ATTRIBUTE_XREF] ([SOURCE_ID], [SOURCE_NAME], [SOURCE_SCHEMA_NAME], [TARGET_ID], [TARGET_NAME], [SOURCE_ATTRIBUTE_ID], [SOURCE_ATTRIBUTE_NAME], [TARGET_ATTRIBUTE_ID], [TARGET_ATTRIBUTE_NAME], [MULTI_ACTIVE_KEY_INDICATOR]) VALUES (3, N'STG_PROFILER_CUSTOMER_PERSONAL', N'dbo', 1, N'SAT_CUSTOMER', 5, N'COUNTRY', 5, N'COUNTRY', N'N')
INSERT [interface].[INTERFACE_SOURCE_SATELLITE_ATTRIBUTE_XREF] ([SOURCE_ID], [SOURCE_NAME], [SOURCE_SCHEMA_NAME], [TARGET_ID], [TARGET_NAME], [SOURCE_ATTRIBUTE_ID], [SOURCE_ATTRIBUTE_NAME], [TARGET_ATTRIBUTE_ID], [TARGET_ATTRIBUTE_NAME], [MULTI_ACTIVE_KEY_INDICATOR]) VALUES (3, N'STG_PROFILER_CUSTOMER_PERSONAL', N'dbo', 1, N'SAT_CUSTOMER', 15, N'DOB', 12, N'DATE_OF_BIRTH', N'N')
INSERT [interface].[INTERFACE_SOURCE_SATELLITE_ATTRIBUTE_XREF] ([SOURCE_ID], [SOURCE_NAME], [SOURCE_SCHEMA_NAME], [TARGET_ID], [TARGET_NAME], [SOURCE_ATTRIBUTE_ID], [SOURCE_ATTRIBUTE_NAME], [TARGET_ATTRIBUTE_ID], [TARGET_ATTRIBUTE_NAME], [MULTI_ACTIVE_KEY_INDICATOR]) VALUES (3, N'STG_PROFILER_CUSTOMER_PERSONAL', N'dbo', 1, N'SAT_CUSTOMER', 18, N'GENDER', 18, N'GENDER', N'N')
INSERT [interface].[INTERFACE_SOURCE_SATELLITE_ATTRIBUTE_XREF] ([SOURCE_ID], [SOURCE_NAME], [SOURCE_SCHEMA_NAME], [TARGET_ID], [TARGET_NAME], [SOURCE_ATTRIBUTE_ID], [SOURCE_ATTRIBUTE_NAME], [TARGET_ATTRIBUTE_ID], [TARGET_ATTRIBUTE_NAME], [MULTI_ACTIVE_KEY_INDICATOR]) VALUES (3, N'STG_PROFILER_CUSTOMER_PERSONAL', N'dbo', 1, N'SAT_CUSTOMER', 19, N'Given', 20, N'GIVEN_NAME', N'N')
INSERT [interface].[INTERFACE_SOURCE_SATELLITE_ATTRIBUTE_XREF] ([SOURCE_ID], [SOURCE_NAME], [SOURCE_SCHEMA_NAME], [TARGET_ID], [TARGET_NAME], [SOURCE_ATTRIBUTE_ID], [SOURCE_ATTRIBUTE_NAME], [TARGET_ATTRIBUTE_ID], [TARGET_ATTRIBUTE_NAME], [MULTI_ACTIVE_KEY_INDICATOR]) VALUES (3, N'STG_PROFILER_CUSTOMER_PERSONAL', N'dbo', 1, N'SAT_CUSTOMER', 41, N'POSTCODE', 41, N'POSTCODE', N'N')
INSERT [interface].[INTERFACE_SOURCE_SATELLITE_ATTRIBUTE_XREF] ([SOURCE_ID], [SOURCE_NAME], [SOURCE_SCHEMA_NAME], [TARGET_ID], [TARGET_NAME], [SOURCE_ATTRIBUTE_ID], [SOURCE_ATTRIBUTE_NAME], [TARGET_ATTRIBUTE_ID], [TARGET_ATTRIBUTE_NAME], [MULTI_ACTIVE_KEY_INDICATOR]) VALUES (3, N'STG_PROFILER_CUSTOMER_PERSONAL', N'dbo', 1, N'SAT_CUSTOMER', 42, N'Referee_Offer_Made', 43, N'REFERRAL_OFFER_MADE_INDICATOR', N'N')
INSERT [interface].[INTERFACE_SOURCE_SATELLITE_ATTRIBUTE_XREF] ([SOURCE_ID], [SOURCE_NAME], [SOURCE_SCHEMA_NAME], [TARGET_ID], [TARGET_NAME], [SOURCE_ATTRIBUTE_ID], [SOURCE_ATTRIBUTE_NAME], [TARGET_ATTRIBUTE_ID], [TARGET_ATTRIBUTE_NAME], [MULTI_ACTIVE_KEY_INDICATOR]) VALUES (3, N'STG_PROFILER_CUSTOMER_PERSONAL', N'dbo', 1, N'SAT_CUSTOMER', 55, N'Suburb', 55, N'SUBURB', N'N')
INSERT [interface].[INTERFACE_SOURCE_SATELLITE_ATTRIBUTE_XREF] ([SOURCE_ID], [SOURCE_NAME], [SOURCE_SCHEMA_NAME], [TARGET_ID], [TARGET_NAME], [SOURCE_ATTRIBUTE_ID], [SOURCE_ATTRIBUTE_NAME], [TARGET_ATTRIBUTE_ID], [TARGET_ATTRIBUTE_NAME], [MULTI_ACTIVE_KEY_INDICATOR]) VALUES (3, N'STG_PROFILER_CUSTOMER_PERSONAL', N'dbo', 1, N'SAT_CUSTOMER', 56, N'SURNAME', 56, N'SURNAME', N'N')
INSERT [interface].[INTERFACE_SOURCE_SATELLITE_ATTRIBUTE_XREF] ([SOURCE_ID], [SOURCE_NAME], [SOURCE_SCHEMA_NAME], [TARGET_ID], [TARGET_NAME], [SOURCE_ATTRIBUTE_ID], [SOURCE_ATTRIBUTE_NAME], [TARGET_ATTRIBUTE_ID], [TARGET_ATTRIBUTE_NAME], [MULTI_ACTIVE_KEY_INDICATOR]) VALUES (3, N'STG_PROFILER_CUSTOMER_PERSONAL', N'dbo', 2, N'SAT_CUSTOMER_ADDITIONAL_DETAILS', 3, N'Contact_Number', 3, N'CONTACT_NUMBER', N'N')
INSERT [interface].[INTERFACE_SOURCE_SATELLITE_ATTRIBUTE_XREF] ([SOURCE_ID], [SOURCE_NAME], [SOURCE_SCHEMA_NAME], [TARGET_ID], [TARGET_NAME], [SOURCE_ATTRIBUTE_ID], [SOURCE_ATTRIBUTE_NAME], [TARGET_ATTRIBUTE_ID], [TARGET_ATTRIBUTE_NAME], [MULTI_ACTIVE_KEY_INDICATOR]) VALUES (3, N'STG_PROFILER_CUSTOMER_PERSONAL', N'dbo', 2, N'SAT_CUSTOMER_ADDITIONAL_DETAILS', 53, N'State', 53, N'STATE', N'N')
INSERT [interface].[INTERFACE_SOURCE_SATELLITE_ATTRIBUTE_XREF] ([SOURCE_ID], [SOURCE_NAME], [SOURCE_SCHEMA_NAME], [TARGET_ID], [TARGET_NAME], [SOURCE_ATTRIBUTE_ID], [SOURCE_ATTRIBUTE_NAME], [TARGET_ATTRIBUTE_ID], [TARGET_ATTRIBUTE_NAME], [MULTI_ACTIVE_KEY_INDICATOR]) VALUES (4, N'STG_PROFILER_PLAN', N'dbo', 4, N'SAT_MEMBERSHIP_PLAN_DETAIL', 36, N'Plan_Desc', 37, N'PLAN_DESCRIPTION', N'N')
INSERT [interface].[INTERFACE_SOURCE_SATELLITE_ATTRIBUTE_XREF] ([SOURCE_ID], [SOURCE_NAME], [SOURCE_SCHEMA_NAME], [TARGET_ID], [TARGET_NAME], [SOURCE_ATTRIBUTE_ID], [SOURCE_ATTRIBUTE_NAME], [TARGET_ATTRIBUTE_ID], [TARGET_ATTRIBUTE_NAME], [MULTI_ACTIVE_KEY_INDICATOR]) VALUES (5, N'STG_PROFILER_PERSONALISED_COSTING', N'dbo', 7, N'LSAT_CUSTOMER_COSTING', 11, N'Date_effective', 4, N'COSTING_EFFECTIVE_DATE', N'Y')
INSERT [interface].[INTERFACE_SOURCE_SATELLITE_ATTRIBUTE_XREF] ([SOURCE_ID], [SOURCE_NAME], [SOURCE_SCHEMA_NAME], [TARGET_ID], [TARGET_NAME], [SOURCE_ATTRIBUTE_ID], [SOURCE_ATTRIBUTE_NAME], [TARGET_ATTRIBUTE_ID], [TARGET_ATTRIBUTE_NAME], [MULTI_ACTIVE_KEY_INDICATOR]) VALUES (5, N'STG_PROFILER_PERSONALISED_COSTING', N'dbo', 7, N'LSAT_CUSTOMER_COSTING', 29, N'Monthly_Cost', 34, N'PERSONAL_MONTHLY_COST', N'N')
INSERT [interface].[INTERFACE_SOURCE_SATELLITE_ATTRIBUTE_XREF] ([SOURCE_ID], [SOURCE_NAME], [SOURCE_SCHEMA_NAME], [TARGET_ID], [TARGET_NAME], [SOURCE_ATTRIBUTE_ID], [SOURCE_ATTRIBUTE_NAME], [TARGET_ATTRIBUTE_ID], [TARGET_ATTRIBUTE_NAME], [MULTI_ACTIVE_KEY_INDICATOR]) VALUES (6, N'STG_PROFILER_ESTIMATED_WORTH', N'dbo', 5, N'SAT_MEMBERSHIP_PLAN_VALUATION', 11, N'Date_effective', 40, N'PLAN_VALUATION_DATE', N'Y')
INSERT [interface].[INTERFACE_SOURCE_SATELLITE_ATTRIBUTE_XREF] ([SOURCE_ID], [SOURCE_NAME], [SOURCE_SCHEMA_NAME], [TARGET_ID], [TARGET_NAME], [SOURCE_ATTRIBUTE_ID], [SOURCE_ATTRIBUTE_NAME], [TARGET_ATTRIBUTE_ID], [TARGET_ATTRIBUTE_NAME], [MULTI_ACTIVE_KEY_INDICATOR]) VALUES (6, N'STG_PROFILER_ESTIMATED_WORTH', N'dbo', 5, N'SAT_MEMBERSHIP_PLAN_VALUATION', 57, N'Value_Amount', 39, N'PLAN_VALUATION_AMOUNT', N'N')
INSERT [interface].[INTERFACE_SOURCE_SATELLITE_ATTRIBUTE_XREF] ([SOURCE_ID], [SOURCE_NAME], [SOURCE_SCHEMA_NAME], [TARGET_ID], [TARGET_NAME], [SOURCE_ATTRIBUTE_ID], [SOURCE_ATTRIBUTE_NAME], [TARGET_ATTRIBUTE_ID], [TARGET_ATTRIBUTE_NAME], [MULTI_ACTIVE_KEY_INDICATOR]) VALUES (7, N'STG_PROFILER_CUST_MEMBERSHIP', N'dbo', 9, N'LSAT_MEMBERSHIP', 16, N'End_Date', 24, N'MEMBERSHIP_END_DATE', N'N')
INSERT [interface].[INTERFACE_SOURCE_SATELLITE_ATTRIBUTE_XREF] ([SOURCE_ID], [SOURCE_NAME], [SOURCE_SCHEMA_NAME], [TARGET_ID], [TARGET_NAME], [SOURCE_ATTRIBUTE_ID], [SOURCE_ATTRIBUTE_NAME], [TARGET_ATTRIBUTE_ID], [TARGET_ATTRIBUTE_NAME], [MULTI_ACTIVE_KEY_INDICATOR]) VALUES (7, N'STG_PROFILER_CUST_MEMBERSHIP', N'dbo', 9, N'LSAT_MEMBERSHIP', 52, N'Start_Date', 27, N'MEMBERSHIP_START_DATE', N'N')
INSERT [interface].[INTERFACE_SOURCE_SATELLITE_ATTRIBUTE_XREF] ([SOURCE_ID], [SOURCE_NAME], [SOURCE_SCHEMA_NAME], [TARGET_ID], [TARGET_NAME], [SOURCE_ATTRIBUTE_ID], [SOURCE_ATTRIBUTE_NAME], [TARGET_ATTRIBUTE_ID], [TARGET_ATTRIBUTE_NAME], [MULTI_ACTIVE_KEY_INDICATOR]) VALUES (7, N'STG_PROFILER_CUST_MEMBERSHIP', N'dbo', 9, N'LSAT_MEMBERSHIP', 54, N'Status', 28, N'MEMBERSHIP_STATUS', N'N')
INSERT [interface].[INTERFACE_SOURCE_SATELLITE_ATTRIBUTE_XREF] ([SOURCE_ID], [SOURCE_NAME], [SOURCE_SCHEMA_NAME], [TARGET_ID], [TARGET_NAME], [SOURCE_ATTRIBUTE_ID], [SOURCE_ATTRIBUTE_NAME], [TARGET_ATTRIBUTE_ID], [TARGET_ATTRIBUTE_NAME], [MULTI_ACTIVE_KEY_INDICATOR]) VALUES (8, N'STG_USERMANAGED_SEGMENT', N'dbo', 6, N'SAT_SEGMENT', 14, N'Demographic_Segment_Description', 50, N'SEGMENT_DESCRIPTION', N'N')
-- Source / Staging relationship
INSERT [interface].[INTERFACE_SOURCE_TO_STAGING] ([STAGING_AREA_NAME], [SCHEMA_NAME], [SOURCE_TABLE_NAME], [SOURCE_TABLE_SYSTEM_NAME], [CHANGE_DATA_CAPTURE_TYPE], [CHANGE_DATETIME_DEFINITION], [PROCESS_INDICATOR]) VALUES (N'STG_PROFILER_CUST_MEMBERSHIP', N'[interface]', N'CUST_MEMBERSHIP', N'PROFILER', N'SQL Server Full Outer Join', N'OMD_EVENT_DATETIME', N'Y')
INSERT [interface].[INTERFACE_SOURCE_TO_STAGING] ([STAGING_AREA_NAME], [SCHEMA_NAME], [SOURCE_TABLE_NAME], [SOURCE_TABLE_SYSTEM_NAME], [CHANGE_DATA_CAPTURE_TYPE], [CHANGE_DATETIME_DEFINITION], [PROCESS_INDICATOR]) VALUES (N'STG_PROFILER_CUSTOMER_OFFER', N'[interface]', N'CUSTOMER_OFFER', N'PROFILER', N'SQL Server Full Outer Join', N'OMD_EVENT_DATETIME', N'Y')
INSERT [interface].[INTERFACE_SOURCE_TO_STAGING] ([STAGING_AREA_NAME], [SCHEMA_NAME], [SOURCE_TABLE_NAME], [SOURCE_TABLE_SYSTEM_NAME], [CHANGE_DATA_CAPTURE_TYPE], [CHANGE_DATETIME_DEFINITION], [PROCESS_INDICATOR]) VALUES (N'STG_PROFILER_CUSTOMER_PERSONAL', N'[interface]', N'CUSTOMER_PERSONAL', N'PROFILER', N'SQL Server Full Outer Join', N'OMD_EVENT_DATETIME', N'Y')
INSERT [interface].[INTERFACE_SOURCE_TO_STAGING] ([STAGING_AREA_NAME], [SCHEMA_NAME], [SOURCE_TABLE_NAME], [SOURCE_TABLE_SYSTEM_NAME], [CHANGE_DATA_CAPTURE_TYPE], [CHANGE_DATETIME_DEFINITION], [PROCESS_INDICATOR]) VALUES (N'STG_PROFILER_ESTIMATED_WORTH', N'[interface]', N'ESTIMATED_WORTH', N'PROFILER', N'SQL Server Full Outer Join', N'OMD_EVENT_DATETIME', N'Y')
INSERT [interface].[INTERFACE_SOURCE_TO_STAGING] ([STAGING_AREA_NAME], [SCHEMA_NAME], [SOURCE_TABLE_NAME], [SOURCE_TABLE_SYSTEM_NAME], [CHANGE_DATA_CAPTURE_TYPE], [CHANGE_DATETIME_DEFINITION], [PROCESS_INDICATOR]) VALUES (N'STG_PROFILER_OFFER', N'[interface]', N'OFFER', N'PROFILER', N'SQL Server Full Outer Join', N'OMD_EVENT_DATETIME', N'Y')
INSERT [interface].[INTERFACE_SOURCE_TO_STAGING] ([STAGING_AREA_NAME], [SCHEMA_NAME], [SOURCE_TABLE_NAME], [SOURCE_TABLE_SYSTEM_NAME], [CHANGE_DATA_CAPTURE_TYPE], [CHANGE_DATETIME_DEFINITION], [PROCESS_INDICATOR]) VALUES (N'STG_PROFILER_PERSONALISED_COSTING', N'[interface]', N'PERSONALISED_COSTING', N'PROFILER', N'SQL Server Full Outer Join', N'OMD_EVENT_DATETIME', N'Y')
INSERT [interface].[INTERFACE_SOURCE_TO_STAGING] ([STAGING_AREA_NAME], [SCHEMA_NAME], [SOURCE_TABLE_NAME], [SOURCE_TABLE_SYSTEM_NAME], [CHANGE_DATA_CAPTURE_TYPE], [CHANGE_DATETIME_DEFINITION], [PROCESS_INDICATOR]) VALUES (N'STG_PROFILER_PLAN', N'[interface]', N'PLAN', N'PROFILER', N'SQL Server Full Outer Join', N'OMD_EVENT_DATETIME', N'Y')
-- Driving Key example
INSERT [interface].[INTERFACE_DRIVING_KEY] ([SATELLITE_ID], [SATELLITE_NAME], [HUB_ID], [HUB_NAME]) VALUES (8, N'LSAT_CUSTOMER_OFFER', 3, N'HUB_CUSTOMER')
-- Degenerate attribute example
INSERT [interface].[INTERFACE_SOURCE_LINK_ATTRIBUTE_XREF] ([SOURCE_ID], [SOURCE_NAME], [SOURCE_SCHEMA_NAME], [LINK_ID], [LINK_NAME], [SOURCE_ATTRIBUTE_ID], [SOURCE_ATTRIBUTE_NAME], [LINK_ATTRIBUTE_ID], [LINK_ATTRIBUTE_NAME]) VALUES (7, N'STG_PROFILER_CUST_MEMBERSHIP', N'dbo', 4, N'LNK_MEMBERSHIP', 54, N'Status', 47, N'SALES_CHANNEL')