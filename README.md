# Data Warehouse Code Generation templates
 A collection of patterns to develop Data Warehouse solutions, using various technologies. This patterns in this repository are used to generate data integration logic, as opposed to the documentation patterns available in the [Data Integration Framework](https://github.com/RoelantVos/Data_Integration_Framework) repository.

## Handlebars templates

The Handlebars templating engine load patterns are located in the 'Templates_Handlebars' directory.

No helper methods (plug-ins) in Handlebars were used, all implemented logic uses the standard built-in Handlebars functionality ('helpers' - as per https://handlebarsjs.com/guide/builtin-helpers.html).

### Adding a specific pattern to a pattern definition

The Handlebars load patterns are registered in the *loadPatternCollection* json file. This file contains the collection (array) of all individually defined load patterns.

### Using the patterns in the Virtual Data Warehouse software

The files can be copied into the 'LoadPatterns' directory in the [Virtual Data Warehouse](http://roelantvos.com/blog/articles-and-white-papers/virtualisation-software/) (VDW) application, the example code snippets in the [Data Warehouse Automation interface Github](https://github.com/RoelantVos/Data_Warehouse_Automation_Metadata_Interface) (or any other compatible tool).

## SQL templates

Code can also easily be generated using SQL, and the directory 'Templates_SQL' contains anything to do with using SQL as a pattern to generate ETL.
