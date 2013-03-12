Feature: view_generator generates view from archetype

  This openEHR ViewGenerator generates rails view and assets
  from archetype definition.

  Scenario Outline: generate view
    Given the archetype is "<archetype>"
    When I generate "<generate>"
    Then The view should be "<view>"

    Scenarios: Blood pressure archetype
      |archetype|generate|view|
      |openEHR-EHR-OBSERVATION-blood_pressure.v1|view_generator|index.html.erb|
      
