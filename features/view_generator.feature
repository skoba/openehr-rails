Feature: view_generator generates view from archetype

  So that view generator generates rails view and assets from arhcetype
  As a developer
  I need generated erb, i18n modules, modified layouts.

  Scenario: Generator generates rails view and assets from archetype
    Given an archetype openEHR-EHR-OBSERVATION.blood_pressure.v1.adl
    When generator runs
    Then '/config/initializers/i18n' is geneated
