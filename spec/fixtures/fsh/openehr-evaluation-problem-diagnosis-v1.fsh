Profile: OpenehrEvaluationProblemDiagnosisV1
Parent: Condition
Id: openehr-evaluation-problem-diagnosis-v1
Title: "openEHR Problem diagnosis (openEHR-EHR-EVALUATION.problem_diagnosis.v1)"

* category ^slicing.discriminator.type = #pattern
* category ^slicing.discriminator.path = "$this"
* category ^slicing.rules = #open
* category contains ckm 1..1
* category[ckm] = http://openehr.org/ckm/archetypes#openEHR-EHR-EVALUATION.problem_diagnosis.v1
* code 0..1
* code only CodeableConcept
* code from http://id.who.int/icd/release/11/mms (required)
* onsetDateTime 0..1
* onsetDateTime only dateTime
* recordedDate 0..1
* recordedDate only dateTime
* recordedDate ^comment = "Approximation: openEHR at0003 (Date/time clinically recognised) has no exact counterpart in FHIR R5 Condition; recordedDate is when this Condition record was created in the system. See docs/design/multi-leaf-non-observation-plan.md section 8.1."
* abatementDateTime 0..1
* abatementDateTime only dateTime
* verificationStatus 0..1
* verificationStatus only CodeableConcept
