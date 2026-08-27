Profile: OpenehrEvaluationProblemDiagnosisV1
Parent: Condition
Id: openehr-evaluation-problem-diagnosis-v1
Title: "openEHR Problem diagnosis (openEHR-EHR-EVALUATION.problem_diagnosis.v1)"

* category.coding.system = "http://openehr.org/ckm/archetypes"
* category.coding.code = #openEHR-EHR-EVALUATION.problem_diagnosis.v1
* code 0..1
* code only CodeableConcept
* code from http://id.who.int/icd/release/11/mms (required)
* onsetDateTime 0..1
* onsetDateTime only dateTime
* recordedDate 0..1
* recordedDate only dateTime
* abatementDateTime 0..1
* abatementDateTime only dateTime
* verificationStatus 0..1
* verificationStatus only CodeableConcept
