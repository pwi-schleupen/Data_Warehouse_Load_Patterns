# Data Warehouse Load Patterns
 A collection of patterns to develop Data Warehouse solutions, using various technologies.

## Handlebars (Virtual Data Warehouse patterns)

The Handlebars templating engine load patterns are located in the 'Templates_VEDW_Handlebars' directory.

The files can be copied into the 'LoadPatterns' directory in the [Virtual Data Warehouse](http://roelantvos.com/blog/articles-and-white-papers/virtualisation-software/) (VEDW) application (or any other compatible tool).

### Defining a load pattern archetype

Each individual pattern is defined the *loadPatternDefinition* json file. This is where the patterns are classified, i.e. what is the name, and description / notes and generally how metadata is retrieved. This file is only really necessary when using VEDW, as this is how this tool interfaces with source-to-target metadata.

### Adding a specific pattern to a pattern definition

The actual load patterns (using the Handlebars templating engine) are registered in the *loadPatternCollection* json file. This file contains the collection (array) of all individually defined load patterns.

The loadPatternType matches the name of the pattern in the loadPatternDefinition. This is how the patterns are matched to the definition.

## SQL templates

Code can also easily be generated using SQL, and the directory 'Templates_SQL' contains anything to do with using SQL as a pattern to generate ETL.

